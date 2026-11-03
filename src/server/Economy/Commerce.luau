--!strict
--[[
    Commerce MONO-PROFIL (lot 0.5), règles PURES : achat de véhicule neuf,
    reprise concession, immobilier, agrandissements, modules, pièces,
    réparation, lavage et services d'énergie.

    Chaque fonction est une mutation complète d'UN profil (paiement ET
    acquisition dans la même écriture) : exécutée par ProfileSession.commit,
    elle est atomique (une seule clé), idempotente (identifiant de transaction)
    et confirmée par écriture durable. Les montants viennent du barème serveur
    (EconomyCatalog, VehicleCatalog), jamais du client.
]]

local Persistence = script.Parent.Parent.Persistence
local ProfileSchema = require(Persistence.ProfileSchema)
local Progression = script.Parent.Parent.Progression
local VehicleOwnership = require(Progression.VehicleOwnership)
local PropertyRules = require(Progression.PropertyRules)
local Wallet = require(script.Parent.Wallet)

local Shared = script.Parent.Parent.Parent.Parent.ReplicatedStorage.Shared
local EconomyCatalog = require(Shared.Economy.EconomyCatalog)
local VehicleCatalog = require(Shared.Economy.VehicleCatalog)
local EconomyContracts = require(Shared.Garage.EconomyContracts)
local PropertyCatalog = require(Shared.Garage.PropertyCatalog)
local GarageModules = require(Shared.Garage.GarageModules)
local PartCatalog = require(Shared.Garage.PartCatalog)
local CosmeticCatalog = require(Shared.Garage.CosmeticCatalog)

local Commerce = {}

local function fail(key: string): (boolean, any)
    return false, key
end

-- ============================== Véhicules ==============================

function Commerce.buyVehicle(
    profile: ProfileSchema.Profile,
    catalogId: any,
    environment: string,
    definition: any,
    now: number
): (boolean, any)
    local entry = if type(catalogId) == "string" then VehicleCatalog.get(catalogId) else nil
    if entry == nil then
        return fail("CatalogUnknown")
    end
    if not VehicleCatalog.purchasable(entry, environment) then
        return fail("CatalogNotPurchasable")
    end
    if definition == nil or definition.Id ~= entry.DefinitionId then
        return fail("CatalogDefinitionMissing")
    end
    local ok, err = Wallet.debit(profile, entry.Price, "BuyVehicle", entry.Id, now)
    if not ok then
        return fail(err :: string)
    end
    local vehicleId = VehicleOwnership.add(profile, {
        ModelId = definition.Id,
        Origin = "Purchase",
        Untransferable = false,
        Synthetic = false,
        EnergyFraction = definition.Powertrain.Energy.InitialFraction,
        Cosmetics = CosmeticCatalog.defaults(definition),
        PaidPrice = entry.Price,
    }, now)
    return true, { VehicleId = vehicleId, Price = entry.Price }
end

-- État 0..1 d'un exemplaire (1 = neuf) : carrosserie, mécanique, kilométrage.
function Commerce.condition(vehicle: ProfileSchema.Vehicle): number
    local damage = vehicle.Damage
    local wear, zones = 0, 0
    for _, value in damage.Zones do
        wear += value
        zones += 1
    end
    wear = if zones > 0 then wear / zones else 0
    local suspension, wheels = 0, 0
    for _, health in damage.Suspension do
        suspension += 1 - health
        wheels += 1
    end
    local mechanical = ((1 - damage.Engine) + (1 - damage.Steering) + (if wheels > 0 then suspension / wheels else 0))
        / 3
    local mileage = math.min(vehicle.OdometerKm / 150_000, 1)
    return math.clamp(1 - 0.5 * wear - 0.4 * mechanical - 0.3 * mileage, 0, 1)
end

-- Exemplaire cessible (reprise, marché) ?
function Commerce.transferable(vehicle: ProfileSchema.Vehicle, now: number): string?
    if vehicle.Untransferable then
        return "VehicleUntransferable"
    elseif vehicle.Synthetic then
        return "VehicleSynthetic"
    elseif VehicleOwnership.reserved(vehicle, now) then
        return "VehicleReserved"
    elseif vehicle.Storage.State == "Out" then
        return "VehicleOut"
    end
    return nil
end

-- Devis de reprise : ≈ 60 % du prix neuf du catalogue, ajusté à l'état.
function Commerce.tradeInQuote(profile: ProfileSchema.Profile, vehicleId: any, now: number): (boolean, any)
    local vehicle = VehicleOwnership.get(profile, vehicleId)
    if vehicle == nil then
        return fail("VehicleNotOwned")
    end
    local problem = Commerce.transferable(vehicle, now)
    if problem then
        return fail(problem)
    end
    local entry = VehicleCatalog.forDefinition(vehicle.ModelId)
    if entry == nil or entry.Price <= 0 then
        return fail("TradeInNoReference")
    end
    local condition = Commerce.condition(vehicle)
    return true,
        {
            Amount = EconomyContracts.dealerTradeIn(entry.Price, condition),
            Condition = condition,
            NewPrice = entry.Price,
        }
end

-- Retire un exemplaire et ses pièces INSTALLÉES (elles suivent le véhicule).
local function removeVehicle(profile: ProfileSchema.Profile, vehicle: ProfileSchema.Vehicle)
    for _, partId in vehicle.InstalledParts do
        profile.Parts[partId] = nil
    end
    profile.Vehicles[vehicle.Id] = nil
end
Commerce.removeVehicle = removeVehicle

-- Reprise : un seul versement ; aucune somme séparée pour les pièces installées.
function Commerce.tradeIn(profile: ProfileSchema.Profile, vehicleId: any, now: number): (boolean, any)
    local ok, quote = Commerce.tradeInQuote(profile, vehicleId, now)
    if not ok then
        return false, quote
    end
    local vehicle = profile.Vehicles[vehicleId]
    removeVehicle(profile, vehicle)
    if quote.Amount > 0 then
        local credited, err = Wallet.credit(profile, quote.Amount, "TradeIn", vehicle.Id, now)
        if not credited then
            return fail(err :: string)
        end
    end
    return true, { VehicleId = vehicle.Id, Amount = quote.Amount }
end

-- ============================== Immobilier ==============================

function Commerce.buyProperty(profile: ProfileSchema.Profile, offerId: any, now: number): (boolean, any)
    local offer = if type(offerId) == "string" then PropertyCatalog.offer(offerId) else nil
    if offer == nil then
        return fail("PropertyUnknownOffer")
    end
    if offer.Starter then
        return fail("PropertyStarterOfferNotForSale")
    end
    local price = EconomyCatalog.PropertyPrice[offer.Category]
    local ok, err = Wallet.debit(profile, price, "BuyProperty", offer.Id, now)
    if not ok then
        return fail(err :: string)
    end
    local acquired, result = PropertyRules.acquire(profile, offer.Id, "Purchase", false, now)
    if not acquired then
        return fail(result)
    end
    profile.Properties[result].PaidPrice = price
    return true, { PropertyId = result, Price = price }
end

-- Revente : 70 % du prix payé, 40 % des agrandissements, 60 % des modules payés.
function Commerce.propertyQuote(profile: ProfileSchema.Profile, propertyId: any): (boolean, any)
    local property = if type(propertyId) == "string" then profile.Properties[propertyId] else nil
    if property == nil then
        return fail("PropertyNotOwned")
    end
    if not property.Sellable then
        return fail("PropertyNotSellable")
    end
    return true,
        {
            Amount = EconomyContracts.propertyResale(property.PaidPrice, property.PaidExtensions, property.PaidModules),
        }
end

function Commerce.sellProperty(profile: ProfileSchema.Profile, propertyId: any, now: number): (boolean, any)
    local ok, quote = Commerce.propertyQuote(profile, propertyId)
    if not ok then
        return false, quote
    end
    local released, result = PropertyRules.release(profile, propertyId)
    if not released then
        return fail(result)
    end
    if quote.Amount > 0 then
        local credited, err = Wallet.credit(profile, quote.Amount, "SellProperty", propertyId, now)
        if not credited then
            return fail(err :: string)
        end
    end
    return true, { PropertyId = propertyId, Amount = quote.Amount, Moved = result.Moved }
end

function Commerce.upgradeGarage(profile: ProfileSchema.Profile, propertyId: any, now: number): (boolean, any)
    local property = if type(propertyId) == "string" then profile.Properties[propertyId] else nil
    if property == nil then
        return fail("PropertyNotOwned")
    end
    local price = EconomyCatalog.GarageLevelPrice[property.Category]
    local ok, err = Wallet.debit(profile, price, "UpgradeGarage", property.Id, now)
    if not ok then
        return fail(err :: string)
    end
    local upgraded, result = PropertyRules.upgradeGarage(profile, property.Id)
    if not upgraded then
        return fail(result)
    end
    property.PaidExtensions += price
    return true, { PropertyId = property.Id, Price = price, Level = result.Level, Capacity = result.Capacity }
end

--[[
    Module privé : les huit catégories restent des PROPOSITIONS à arbitrer ;
    leur achat n'est donc ouvert qu'en environnement de développement.
]]
function Commerce.buyModule(
    profile: ProfileSchema.Profile,
    propertyId: any,
    moduleId: any,
    environment: string,
    now: number
): (boolean, any)
    local property = if type(propertyId) == "string" then profile.Properties[propertyId] else nil
    if property == nil then
        return fail("PropertyNotOwned")
    end
    local module = if type(moduleId) == "string" then GarageModules.get(moduleId) else nil
    if module == nil then
        return fail("ModuleUnknown")
    end
    if module.Proposal and environment ~= "Dev" then
        return fail("ModuleAwaitingDecision")
    end
    if property.Modules[module.Id] ~= nil then
        return fail("ModuleAlreadyInstalled")
    end
    local price = EconomyCatalog.ModulePrice[module.Id]
    local ok, err = Wallet.debit(profile, price, "BuyModule", module.Id, now)
    if not ok then
        return fail(err :: string)
    end
    property.Modules[module.Id] = { InstalledAt = now, PaidPrice = price }
    property.PaidModules += price
    return true, { PropertyId = property.Id, ModuleId = module.Id, Price = price }
end

-- ============================== Pièces ==============================

function Commerce.buyPart(profile: ProfileSchema.Profile, partId: any, now: number): (boolean, any)
    local part = if type(partId) == "string" then PartCatalog.get(partId) else nil
    if part == nil then
        return fail("PartUnknown")
    end
    local price = EconomyCatalog.PartPrice[part.Id]
    local ok, err = Wallet.debit(profile, price, "BuyPart", part.Id, now)
    if not ok then
        return fail(err :: string)
    end
    local id = ProfileSchema.nextId(profile, "Part", "PT")
    profile.Parts[id] = {
        Id = id,
        PartId = part.Id,
        AcquiredAt = now,
        Origin = "Purchase",
        PaidPrice = price,
        Synthetic = false,
    }
    return true, { PartItemId = id, Price = price }
end

-- Revente d'une pièce DÉTACHÉE payée : 75 % du prix réellement payé.
function Commerce.sellPart(profile: ProfileSchema.Profile, partItemId: any, now: number): (boolean, any)
    local item = if type(partItemId) == "string" then profile.Parts[partItemId] else nil
    if item == nil then
        return fail("PartNotOwned")
    end
    if item.InstalledOn ~= nil then
        return fail("PartInstalled")
    end
    local paid = item.PaidPrice or 0
    local amount = EconomyContracts.detachedPartResale(paid, paid > 0 and not item.Synthetic)
    if amount <= 0 then
        return fail("PartNotEligible")
    end
    profile.Parts[item.Id] = nil
    local ok, err = Wallet.credit(profile, amount, "SellPart", item.Id, now)
    if not ok then
        return fail(err :: string)
    end
    return true, { PartItemId = item.Id, Amount = amount }
end

-- Main-d'œuvre facturée dans la même mutation que l'intervention.
function Commerce.chargeLabor(
    profile: ProfileSchema.Profile,
    amount: number,
    kind: string,
    ref: string,
    now: number
): (boolean, any)
    if amount <= 0 then
        return true, nil
    end
    return Wallet.debit(profile, amount, kind, ref, now)
end

-- ============================== Entretien ==============================

function Commerce.repairQuote(profile: ProfileSchema.Profile, vehicleId: any): (boolean, any)
    local vehicle = VehicleOwnership.get(profile, vehicleId)
    if vehicle == nil then
        return fail("VehicleNotOwned")
    end
    return true, { Amount = EconomyCatalog.repairQuote(vehicle.Damage) }
end

-- Réparation payée : remet l'état durable à neuf, une seule fois.
function Commerce.repair(profile: ProfileSchema.Profile, vehicleId: any, now: number): (boolean, any)
    local ok, quote = Commerce.repairQuote(profile, vehicleId)
    if not ok then
        return false, quote
    end
    if quote.Amount <= 0 then
        return fail("RepairNotNeeded")
    end
    local vehicle = profile.Vehicles[vehicleId]
    local paid, err = Wallet.debit(profile, quote.Amount, "Repair", vehicle.Id, now)
    if not paid then
        return fail(err :: string)
    end
    vehicle.Damage = ProfileSchema.pristineDamage()
    vehicle.UpdatedAt = now
    return true, { VehicleId = vehicle.Id, Amount = quote.Amount }
end

-- Lavage : salissure à zéro, aucun effet mécanique ni sur les dégâts.
function Commerce.wash(profile: ProfileSchema.Profile, vehicleId: any, now: number): (boolean, any)
    local vehicle = VehicleOwnership.get(profile, vehicleId)
    if vehicle == nil then
        return fail("VehicleNotOwned")
    end
    if vehicle.Dirt < 0.05 then
        return fail("WashNotNeeded")
    end
    local ok, err = Wallet.debit(profile, EconomyCatalog.WashPrice, "Wash", vehicle.Id, now)
    if not ok then
        return fail(err :: string)
    end
    vehicle.Dirt = 0
    vehicle.UpdatedAt = now
    return true, { VehicleId = vehicle.Id, Amount = EconomyCatalog.WashPrice }
end

-- ============================== Énergie (livraison progressive) ==============================

--[[
    Ouverture d'un service d'énergie : les fonds de la quantité MAXIMALE
    livrable (réserve vide → pleine) sont réservés ; rien n'est encore livré.
]]
function Commerce.startEnergy(
    profile: ProfileSchema.Profile,
    sessionId: string,
    vehicleId: any,
    kind: string,
    maxUnits: number,
    now: number
): (boolean, any)
    local vehicle = VehicleOwnership.get(profile, vehicleId)
    if vehicle == nil then
        return fail("VehicleNotOwned")
    end
    if profile.Services[sessionId] ~= nil then
        return fail("ServiceExists")
    end
    for _, entry in profile.Services do
        if entry.VehicleId == vehicle.Id then
            return fail("ServiceBusy")
        end
    end
    local unitPrice = EconomyCatalog.EnergyPrice[kind]
    if unitPrice == nil or maxUnits <= 0 then
        return fail("EnergyNotNeeded")
    end
    local reserve = math.ceil(maxUnits * unitPrice)
    local ok, err = Wallet.reserve(profile, reserve, "EnergyReserve", sessionId, now)
    if not ok then
        return fail(err :: string)
    end
    profile.Services[sessionId] =
        { Kind = kind, VehicleId = vehicle.Id, Reserved = reserve, UnitPrice = unitPrice, At = now }
    return true, { SessionId = sessionId, Reserved = reserve, UnitPrice = unitPrice }
end

--[[
    Règlement : paiement de la quantité RÉELLEMENT livrée (mesurée par le
    serveur), restitution du reste, et réserve durable augmentée d'autant.
]]
function Commerce.settleEnergy(
    profile: ProfileSchema.Profile,
    sessionId: string,
    deliveredUnits: number,
    capacity: number,
    now: number
): (boolean, any)
    local entry = profile.Services[sessionId]
    if entry == nil then
        return fail("ServiceUnknown")
    end
    local vehicle = profile.Vehicles[entry.VehicleId]
    local delivered = math.max(0, deliveredUnits)
    local cost = math.min(math.ceil(delivered * entry.UnitPrice), entry.Reserved)
    -- Quantité facturable plafonnée par la réservation (jamais de livraison gratuite).
    delivered = math.min(delivered, cost / entry.UnitPrice)
    local consumed, err = Wallet.consume(profile, cost, "Energy", sessionId, now)
    if not consumed then
        return fail(err :: string)
    end
    local released, err2 = Wallet.release(profile, entry.Reserved - cost, "EnergyRelease", sessionId, now)
    if not released then
        return fail(err2 :: string)
    end
    profile.Services[sessionId] = nil
    if vehicle and capacity > 0 then
        vehicle.Energy = math.clamp(vehicle.Energy + delivered / capacity, 0, 1)
        vehicle.UpdatedAt = now
    end
    return true, { SessionId = sessionId, Delivered = delivered, Cost = cost }
end

--[[
    Au chargement d'un profil (verrou détenu : l'ancienne session a disparu) :
    les services interrompus sont annulés, fonds restitués. L'énergie livrée
    sans règlement n'avait pas été rendue durable : rien de gratuit, rien perdu.
]]
function Commerce.recoverServices(profile: ProfileSchema.Profile, now: number): boolean
    local changed = false
    for sessionId, entry in profile.Services do
        Wallet.release(profile, entry.Reserved, "EnergyRecovered", sessionId, now)
        profile.Services[sessionId] = nil
        changed = true
    end
    return changed
end

return table.freeze(Commerce)
