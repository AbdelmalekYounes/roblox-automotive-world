--!strict
--[[
    Service économique (lot 0.5) : point d'entrée UNIQUE des opérations
    financières des joueurs (canal AWEconomy).

    Chaque demande est revalidée par le serveur : identité, profil actif,
    blocage en mouvement (AUD-UI-01), lieu PHYSIQUE (concession, entrée de la
    propriété, garage public, station), montants du barème serveur. Les
    opérations mono-profil sont des transactions idempotentes du profil ; le
    marché utilise le protocole multiprofil (Economy/Market). La réponse donne
    l'état RÉEL : jamais de réussite affichée avant confirmation.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyShared = Shared:WaitForChild("Economy")
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))
local VehicleDefinitions = require(Shared.Vehicles.VehicleDefinitions)
local EconomyProtocol = require(EconomyShared:WaitForChild("EconomyProtocol"))
local EconomyCatalog = require(EconomyShared:WaitForChild("EconomyCatalog"))
local VehicleCatalog = require(EconomyShared:WaitForChild("VehicleCatalog"))
local Jobs = require(EconomyShared:WaitForChild("Jobs"))
local Reputation = require(EconomyShared:WaitForChild("Reputation"))
local PropertyCatalog = require(Shared:WaitForChild("Garage"):WaitForChild("PropertyCatalog"))
local GarageModules = require(Shared.Garage.GarageModules)
local PartCatalog = require(Shared.Garage.PartCatalog)
local EconomyContracts = require(Shared.Garage.EconomyContracts)

local Persistence = script.Parent.Parent.Persistence
local ProfileService = require(Persistence.ProfileService)
local ProfileSchema = require(Persistence.ProfileSchema)
local ProfileMigration = require(Persistence.ProfileMigration)
local TransactionService = require(Persistence.TransactionService)
local RateLimiter = require(script.Parent.Parent.Security.RateLimiter)
local VehicleService = require(script.Parent.Parent.Vehicles.VehicleService)
local Progression = script.Parent.Parent.Progression
local ProgressionService = require(Progression.ProgressionService)
local Locations = require(Progression.Locations)
local PropertyInteriors = require(Progression.PropertyInteriors)
local Commerce = require(script.Parent.Commerce)
local StationRules = require(script.Parent.StationRules)
local Wallet = require(script.Parent.Wallet)
local Market = require(script.Parent.Market)
local MissionService = require(script.Parent.MissionService)

local EconomyService = {}

local MENU_MAX_SPEED_MS = 1
local ENERGY_TICK_S = 0.5
local ENERGY_MAX_S = 180 -- au-delà, la borne est libérée (aucun blocage abusif)
local INBOX_INTERVAL_S = 30
local SWEEP_INTERVAL_S = 120

type Response = { Status: string, Error: string?, Result: any?, Snapshot: any? }

type EnergySession = {
    Id: string,
    VehicleId: string,
    Model: Model,
    Kind: string,
    MaxUnits: number,
    Delivered: number,
    StartedAt: number,
    Place: Locations.Place,
    Settling: boolean,
}

local started = false
local push: RemoteEvent
local limiters: { [Player]: RateLimiter.Bucket } = {}
local energySessions: { [Player]: EnergySession } = {}

local function now(): number
    return os.time()
end

local function marketContext(): Market.Context
    return {
        Repository = ProfileService.repository(),
        Profiles = ProfileService.access(),
        Clock = os.time,
        Log = ProfileService.Log,
    }
end

local function rootOf(player: Player): BasePart?
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return if root and root:IsA("BasePart") then root else nil
end

local function moving(player: Player): boolean
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local seat = humanoid and humanoid.SeatPart
    return seat ~= nil and seat.AssemblyLinearVelocity.Magnitude * Constants.MetersPerStud > MENU_MAX_SPEED_MS
end

local function activeSession(player: Player): any
    local session = ProfileService.get(player)
    if session == nil or session.State ~= "Active" or session.Data == nil then
        return nil
    end
    return session
end

local function rejected(key: string): Response
    return { Status = "Rejected", Error = key }
end

-- ============================== Instantané ==============================

local cachedListings: { any } = {}
local listingsAt = -math.huge

local function listings(): { any }
    if os.clock() - listingsAt > 10 then
        listingsAt = os.clock()
        local ok, result = pcall(Market.search, marketContext(), 30)
        cachedListings = if ok then result else {}
    end
    return cachedListings
end

local function snapshot(player: Player): any
    local session = ProfileService.get(player)
    local result: any = { State = if session then session.State else "Loading" }
    if session == nil or session.Data == nil then
        return result
    end
    local profile = session.Data :: ProfileSchema.Profile
    local time = now()
    local environment = ProfileService.environment().Name
    local level = Reputation.level(profile.Reputation.Points)
    result.Wallet = {
        Balance = profile.Wallet.Balance,
        Reserved = profile.Wallet.Reserved,
        Earned = profile.Wallet.Earned,
        Spent = profile.Wallet.Spent,
    }
    result.Reputation = {
        Points = profile.Reputation.Points,
        Level = level.Index,
        Name = level.Name,
        Progress = Reputation.progress(profile.Reputation.Points),
    }
    result.Jobs = {}
    for _, job in Jobs.List do
        local progress = profile.Jobs[job.Id]
        table.insert(result.Jobs, {
            Id = job.Id,
            Label = job.Label,
            Description = job.Description,
            Vehicle = job.Vehicle,
            Completed = if progress then progress.Completed else 0,
            Failed = if progress then progress.Failed else 0,
        })
    end
    result.Ledger = {}
    for i = #profile.Ledger, math.max(1, #profile.Ledger - 19), -1 do
        table.insert(result.Ledger, profile.Ledger[i])
    end
    result.Catalog = {}
    for _, entry in VehicleCatalog.Entries do
        table.insert(result.Catalog, {
            Id = entry.Id,
            Name = entry.Name,
            Category = entry.Category,
            Price = entry.Price,
            Availability = entry.Availability,
            Purchasable = VehicleCatalog.purchasable(entry, environment),
            Dealers = entry.Dealers,
            DefinitionId = entry.DefinitionId,
        })
    end
    result.Vehicles = {}
    for id, vehicle in profile.Vehicles do
        local ok, quote = Commerce.tradeInQuote(profile, id, time)
        local definition = VehicleDefinitions.get(vehicle.ModelId)
        table.insert(result.Vehicles, {
            Id = id,
            Name = if definition then definition.DisplayName else vehicle.ModelId,
            TradeIn = if ok then quote.Amount else nil,
            TradeInBlocked = if ok then nil else quote,
            Listed = vehicle.Reservation ~= nil and vehicle.Reservation.Kind == "Listing",
            Dirt = vehicle.Dirt,
            Repair = EconomyCatalog.repairQuote(vehicle.Damage),
            Storage = vehicle.Storage.State,
        })
    end
    result.Properties = {}
    for id, property in profile.Properties do
        local ok, quote = Commerce.propertyQuote(profile, id)
        local offer = PropertyCatalog.offer(property.OfferId)
        table.insert(result.Properties, {
            Id = id,
            Label = if offer then offer.Label else property.OfferId,
            Category = property.Category,
            Resale = if ok then quote.Amount else nil,
            Sellable = property.Sellable,
            GarageLevel = property.GarageLevel,
            MaxLevel = PropertyCatalog.maxGarageLevel(property.Category :: any),
            UpgradePrice = EconomyCatalog.GarageLevelPrice[property.Category],
            Modules = property.Modules,
        })
    end
    result.Offers = {}
    for _, offer in PropertyCatalog.Offers do
        if not offer.Starter then
            table.insert(result.Offers, {
                Id = offer.Id,
                Label = offer.Label,
                Category = offer.Category,
                Price = EconomyCatalog.PropertyPrice[offer.Category],
                Entrance = offer.Entrance,
            })
        end
    end
    result.Modules = {}
    for _, module in GarageModules.Modules do
        table.insert(result.Modules, {
            Id = module.Id,
            Label = module.Label,
            Price = EconomyCatalog.ModulePrice[module.Id],
            Proposal = module.Proposal,
        })
    end
    result.Parts = {}
    for _, part in PartCatalog.Parts do
        table.insert(result.Parts, { Id = part.Id, Label = part.Label, Price = EconomyCatalog.PartPrice[part.Id] })
    end
    result.OwnedParts = {}
    for id, item in profile.Parts do
        table.insert(result.OwnedParts, {
            Id = id,
            PartId = item.PartId,
            Installed = item.InstalledOn ~= nil,
            Resale = EconomyContracts.detachedPartResale(
                item.PaidPrice or 0,
                (item.PaidPrice or 0) > 0 and not item.Synthetic
            ),
        })
    end
    result.Listings = {}
    for _, listing in listings() do
        local definition = VehicleDefinitions.get(listing.Summary.ModelId)
        local seller = Players:GetPlayerByUserId(listing.Seller)
        table.insert(result.Listings, {
            Id = listing.Id,
            Price = listing.Price,
            Fee = math.floor(listing.Price * EconomyContracts.Ratios.PlayerMarketCommission + 0.5),
            Model = if definition then definition.DisplayName else listing.Summary.ModelId,
            OdometerKm = listing.Summary.OdometerKm,
            Condition = listing.Summary.Condition,
            Parts = listing.Summary.Parts,
            Mine = listing.Seller == player.UserId,
            SellerName = if seller then seller.DisplayName else nil,
            ExpiresAt = listing.ExpiresAt,
        })
    end
    local transfers = 0
    for _, entry in profile.Transfers do
        if entry.Role == "Buyer" and entry.State == "Reserved" then
            transfers += 1
        end
    end
    result.PendingTransfers = transfers
    result.Mission = MissionService.snapshot(player)
    local energy = energySessions[player]
    result.Energy = if energy
        then { Kind = energy.Kind, Delivered = energy.Delivered, MaxUnits = energy.MaxUnits }
        else nil
    local root = rootOf(player)
    local context: any = { Kind = "None" }
    if root then
        local dealer = Locations.near(root.Position, "Dealership")
        local service = Locations.nearService(root.Position)
        local garage = Locations.near(root.Position, "PublicGarage")
        if dealer then
            context = { Kind = "Dealership", Place = dealer.Id, Label = dealer.Label }
        elseif garage then
            context = { Kind = "PublicGarage", Place = garage.Id, Label = garage.Label }
        elseif service then
            context =
                { Kind = "Service", Place = service.Id, Label = service.Label, Services = Locations.services(service) }
        end
    end
    result.Context = context
    result.Environment = environment
    result.Now = time
    return result
end

local function reply(player: Player, status: string, result: any, err: string?): Response
    return { Status = status, Result = result, Error = err, Snapshot = snapshot(player) }
end

local function fromCommit(player: Player, commit: any): Response
    return reply(player, commit.Status, commit.Result, commit.Error)
end

-- ============================== Lieux ==============================

local function atDealer(player: Player, dealers: { string }?): Locations.Place?
    local root = rootOf(player)
    if root == nil then
        return nil
    end
    local place = Locations.near(root.Position, "Dealership")
    if place == nil then
        return nil
    end
    if dealers then
        for _, id in dealers do
            if Locations.resolve(id) == place.Id then
                return place
            end
        end
        return nil
    end
    return place
end

local function atPublicGarage(player: Player): boolean
    local root = rootOf(player)
    return root ~= nil and Locations.near(root.Position, "PublicGarage") ~= nil
end

-- Véhicule sorti du joueur, immobile, à un lieu donné.
local function outVehicleAt(player: Player, place: Locations.Place?): (Model?, string?, string?)
    local model, vehicleId = ProgressionService.outVehicle(player)
    if model == nil then
        return nil, nil, "VehicleNotOut"
    end
    if place == nil or not Locations.within(place, model:GetPivot().Position) then
        return nil, nil, "VehicleNotHere"
    end
    local _, speed = VehicleService.personalDriver(model)
    if speed > 1.5 then
        return nil, nil, "VehicleMoving"
    end
    return model, vehicleId, nil
end

-- ============================== Opérations ==============================

type Handler = (player: Player, payload: any, txId: string?) -> Response
local handlers: { [string]: Handler } = {}

handlers.Snapshot = function(player)
    return { Status = "Ok", Snapshot = snapshot(player) }
end

handlers.BuyVehicle = function(player, payload, txId)
    local session = activeSession(player)
    if session == nil then
        return { Status = "Unavailable", Error = "ProfileUnavailable" }
    end
    local entry = VehicleCatalog.get(if type(payload) == "table" then payload.CatalogId else "")
    if entry == nil then
        return rejected("CatalogUnknown")
    end
    if atDealer(player, entry.Dealers) == nil then
        return rejected("NotAtDealer")
    end
    local definition = if entry.DefinitionId then VehicleDefinitions.get(entry.DefinitionId) else nil
    local environment = ProfileService.environment().Name
    return fromCommit(
        player,
        session:commit(txId :: string, "BuyVehicle", function(profile)
            return Commerce.buyVehicle(profile, entry.Id, environment, definition, now())
        end)
    )
end

handlers.TradeIn = function(player, payload, txId)
    local session = activeSession(player)
    if session == nil then
        return { Status = "Unavailable", Error = "ProfileUnavailable" }
    end
    if atDealer(player, nil) == nil then
        return rejected("NotAtDealer")
    end
    local vehicleId = if type(payload) == "table" then payload.VehicleId else nil
    return fromCommit(
        player,
        session:commit(txId :: string, "TradeIn", function(profile)
            return Commerce.tradeIn(profile, vehicleId, now())
        end)
    )
end

handlers.BuyProperty = function(player, payload, txId)
    local session = activeSession(player)
    if session == nil then
        return { Status = "Unavailable", Error = "ProfileUnavailable" }
    end
    local offer = PropertyCatalog.offer(if type(payload) == "table" then payload.OfferId else "")
    local root = rootOf(player)
    local entrance = if offer then Locations.get(offer.Entrance) else nil
    if offer == nil or entrance == nil then
        return rejected("PropertyUnknownOffer")
    end
    -- Achat sur place, à l'entrée du bien (pas à distance).
    if root == nil or not Locations.within(entrance, root.Position) then
        return rejected("NotAtProperty")
    end
    return fromCommit(
        player,
        session:commit(txId :: string, "BuyProperty", function(profile)
            return Commerce.buyProperty(profile, offer.Id, now())
        end)
    )
end

handlers.SellProperty = function(player, payload, txId)
    local session = activeSession(player)
    if session == nil then
        return { Status = "Unavailable", Error = "ProfileUnavailable" }
    end
    local propertyId = if type(payload) == "table" then payload.PropertyId else nil
    if type(propertyId) == "string" then
        local interior = PropertyInteriors.get(player.UserId, propertyId)
        if interior and next(interior.Occupants) ~= nil then
            return rejected("PropertyOccupied")
        end
    end
    return fromCommit(
        player,
        session:commit(txId :: string, "SellProperty", function(profile)
            return Commerce.sellProperty(profile, propertyId, now())
        end)
    )
end

local function insideProperty(player: Player, propertyId: any): boolean
    local context = ProgressionService.context(player)
    return context.Kind == "Property" and context.PropertyId == propertyId
end

handlers.UpgradeGarage = function(player, payload, txId)
    local session = activeSession(player)
    if session == nil then
        return { Status = "Unavailable", Error = "ProfileUnavailable" }
    end
    local propertyId = if type(payload) == "table" then payload.PropertyId else nil
    if not insideProperty(player, propertyId) then
        return rejected("NotInOwnProperty")
    end
    return fromCommit(
        player,
        session:commit(txId :: string, "UpgradeGarage", function(profile)
            return Commerce.upgradeGarage(profile, propertyId, now())
        end)
    )
end

handlers.BuyModule = function(player, payload, txId)
    local session = activeSession(player)
    if session == nil then
        return { Status = "Unavailable", Error = "ProfileUnavailable" }
    end
    local propertyId = if type(payload) == "table" then payload.PropertyId else nil
    if not insideProperty(player, propertyId) then
        return rejected("NotInOwnProperty")
    end
    local environment = ProfileService.environment().Name
    return fromCommit(
        player,
        session:commit(txId :: string, "BuyModule", function(profile)
            return Commerce.buyModule(profile, propertyId, payload.ModuleId, environment, now())
        end)
    )
end

handlers.BuyPart = function(player, payload, txId)
    local session = activeSession(player)
    if session == nil then
        return { Status = "Unavailable", Error = "ProfileUnavailable" }
    end
    if not atPublicGarage(player) then
        return rejected("NotInGarage")
    end
    local partId = if type(payload) == "table" then payload.PartId else nil
    return fromCommit(
        player,
        session:commit(txId :: string, "BuyPart", function(profile)
            return Commerce.buyPart(profile, partId, now())
        end)
    )
end

handlers.SellPart = function(player, payload, txId)
    local session = activeSession(player)
    if session == nil then
        return { Status = "Unavailable", Error = "ProfileUnavailable" }
    end
    if not atPublicGarage(player) then
        return rejected("NotInGarage")
    end
    local itemId = if type(payload) == "table" then payload.PartItemId else nil
    return fromCommit(
        player,
        session:commit(txId :: string, "SellPart", function(profile)
            return Commerce.sellPart(profile, itemId, now())
        end)
    )
end

handlers.Repair = function(player, _payload, txId)
    local session = activeSession(player)
    if session == nil then
        return { Status = "Unavailable", Error = "ProfileUnavailable" }
    end
    local root = rootOf(player)
    local garage = if root then Locations.near(root.Position, "PublicGarage") else nil
    local model, vehicleId, problem = outVehicleAt(player, garage)
    if model == nil then
        return rejected(problem :: string)
    end
    -- Dégâts subis jusqu'ici rendus durables avant le devis (jamais de réparation gratuite).
    ProgressionService.syncDurable(player)
    local commit = session:commit(txId :: string, "Repair", function(profile)
        return Commerce.repair(profile, vehicleId, now())
    end)
    if (commit.Status == "Confirmed" or commit.Status == "Pending") and not commit.Replayed then
        VehicleService.restorePersonalDamage(model, ProfileSchema.pristineDamage())
    end
    return fromCommit(player, commit)
end

handlers.Wash = function(player, _payload, txId)
    local session = activeSession(player)
    if session == nil then
        return { Status = "Unavailable", Error = "ProfileUnavailable" }
    end
    local root = rootOf(player)
    local place = if root then Locations.nearService(root.Position) else nil
    if place == nil or not Locations.services(place).Wash then
        return rejected("NotAtCarWash")
    end
    local _, vehicleId, problem = outVehicleAt(player, place)
    if vehicleId == nil then
        return rejected(problem :: string)
    end
    ProgressionService.syncDurable(player)
    return fromCommit(
        player,
        session:commit(txId :: string, "Wash", function(profile)
            return Commerce.wash(profile, vehicleId, now())
        end)
    )
end

-- Énergie : ouverture (fonds réservés), livraison progressive, règlement au réel.
local function settleEnergy(player: Player, energy: EnergySession)
    if energy.Settling then
        return
    end
    energy.Settling = true
    local session = ProfileService.get(player)
    local capacity = select(2, VehicleService.personalEnergy(energy.Model))
    local result: any = nil
    if session then
        result = session:commit("Energy:" .. energy.Id .. ":settle", "EnergySettle", function(profile)
            return Commerce.settleEnergy(profile, energy.Id, energy.Delivered, capacity, now())
        end)
    end
    energySessions[player] = nil
    push:FireClient(player, "EnergyEnded", {
        Delivered = energy.Delivered,
        Status = if result then result.Status else "Unavailable",
        Cost = if result and result.Result then result.Result.Cost else nil,
    })
end

handlers.StartEnergy = function(player, _payload, txId)
    local session = activeSession(player)
    if session == nil then
        return { Status = "Unavailable", Error = "ProfileUnavailable" }
    end
    if energySessions[player] then
        return rejected("ServiceBusy")
    end
    local root = rootOf(player)
    local place = if root then Locations.nearService(root.Position) else nil
    if place == nil then
        return rejected("NotAtStation")
    end
    local model, vehicleId, problem = outVehicleAt(player, place)
    if model == nil then
        return rejected(problem :: string)
    end
    local vehicle = session.Data.Vehicles[vehicleId]
    local definition = VehicleDefinitions.get(vehicle.ModelId)
    if definition == nil then
        return rejected("VehicleModelMissing")
    end
    local kind = definition.Powertrain.Energy.Kind
    local services = Locations.services(place)
    if (kind == "Electric" and not services.Charge) or (kind ~= "Electric" and not services.Fuel) then
        return rejected(if kind == "Electric" then "NoCharger" else "NoPump")
    end
    -- Lot 0.9 : une place (pompe ou borne) par session, dans la limite du lieu.
    local occupied: { StationRules.Active } = {}
    for _, other in energySessions do
        table.insert(occupied, { PlaceId = other.Place.Id, Electric = other.Kind == "Electric" })
    end
    local free, full = StationRules.canStart(occupied, place, kind == "Electric")
    if not free then
        return rejected(full :: string)
    end
    local level, capacity = VehicleService.personalEnergy(model)
    local maxUnits = math.floor((capacity - level) * 10) / 10
    if maxUnits < 0.5 then
        return rejected("EnergyNotNeeded")
    end
    local sessionId = "ES-" .. HttpService:GenerateGUID(false)
    local commit = session:commit(txId :: string, "EnergyStart", function(profile)
        return Commerce.startEnergy(profile, sessionId, vehicleId, kind, maxUnits, now())
    end)
    if (commit.Status == "Confirmed" or commit.Status == "Pending") and not commit.Replayed then
        energySessions[player] = {
            Id = sessionId,
            VehicleId = vehicleId :: string,
            Model = model,
            Kind = kind,
            MaxUnits = maxUnits,
            Delivered = 0,
            StartedAt = os.clock(),
            Place = place,
            Settling = false,
        }
    end
    return fromCommit(player, commit)
end

handlers.StopEnergy = function(player)
    local energy = energySessions[player]
    if energy == nil then
        return rejected("NoService")
    end
    settleEnergy(player, energy)
    return reply(player, "Ok", nil, nil)
end

-- Marché.
handlers.ListVehicle = function(player, payload, txId)
    if activeSession(player) == nil then
        return { Status = "Unavailable", Error = "ProfileUnavailable" }
    end
    if type(payload) ~= "table" then
        return rejected("PayloadInvalid")
    end
    local status, result = Market.createListing(
        marketContext(),
        player.UserId,
        payload.VehicleId,
        payload.Price,
        string.sub(txId :: string, 3)
    )
    listingsAt = -math.huge
    if status == "Rejected" then
        return reply(player, status, nil, result)
    end
    return reply(player, status, result, nil)
end

handlers.CancelListing = function(player, payload)
    if activeSession(player) == nil then
        return { Status = "Unavailable", Error = "ProfileUnavailable" }
    end
    local listingId = if type(payload) == "table" then payload.ListingId else nil
    if type(listingId) ~= "string" then
        return rejected("ListingUnknown")
    end
    local status, result = Market.cancelListing(marketContext(), player.UserId, listingId)
    listingsAt = -math.huge
    if status == "Rejected" then
        return reply(player, status, nil, result)
    end
    return reply(player, status, result, nil)
end

handlers.BuyListing = function(player, payload, txId)
    if activeSession(player) == nil then
        return { Status = "Unavailable", Error = "ProfileUnavailable" }
    end
    local listingId = if type(payload) == "table" then payload.ListingId else nil
    local state, result = Market.purchase(marketContext(), player.UserId, listingId, string.sub(txId :: string, 3))
    listingsAt = -math.huge
    -- État réel du transfert : terminé, récupérable (en cours) ou refusé.
    if state == "Committed" then
        return reply(player, "Confirmed", result, nil)
    elseif state == "Aborted" or state == "Compensated" then
        return reply(player, "Rejected", result, "Purchase" .. state)
    elseif state == "Rejected" then
        return reply(player, "Rejected", nil, result)
    end
    return reply(player, "Pending", result, "TransferRecoverable")
end

-- Missions.
handlers.StartMission = function(player, payload)
    local status, result = MissionService.start(player, if type(payload) == "table" then payload.Job else nil)
    if status == "Ok" then
        return reply(player, "Ok", result, nil)
    end
    return reply(player, status, nil, result)
end

handlers.AbandonMission = function(player)
    local status, result = MissionService.abandon(player)
    return reply(player, status, nil, if status == "Ok" then nil else result)
end

--[[
    Devis : calcul sur une COPIE du profil (rien n'est modifié ni écrit).
    Opérations : BuyVehicle, TradeIn, BuyProperty, SellProperty, UpgradeGarage,
    BuyModule, BuyPart, SellPart, Repair, Wash, BuyListing, ListVehicle.
]]
handlers.Quote = function(player, payload)
    local session = activeSession(player)
    if session == nil or type(payload) ~= "table" then
        return { Status = "Unavailable", Error = "ProfileUnavailable" }
    end
    local copy = ProfileMigration.deepCopy(session.Data)
    local operation, args = payload.Operation, if type(payload.Args) == "table" then payload.Args else {}
    local time = now()
    local environment = ProfileService.environment().Name
    local ok, result: any = false, "QuoteUnknown"
    if operation == "BuyVehicle" then
        local entry = VehicleCatalog.get(args.CatalogId or "")
        local definition = if entry and entry.DefinitionId then VehicleDefinitions.get(entry.DefinitionId) else nil
        ok, result = Commerce.buyVehicle(copy, args.CatalogId, environment, definition, time)
        if ok then
            result = { Debit = result.Price }
        end
    elseif operation == "TradeIn" then
        ok, result = Commerce.tradeInQuote(copy, args.VehicleId, time)
        if ok then
            result = { Credit = result.Amount, Condition = result.Condition }
        end
    elseif operation == "BuyProperty" then
        ok, result = Commerce.buyProperty(copy, args.OfferId, time)
        if ok then
            result = { Debit = result.Price }
        end
    elseif operation == "SellProperty" then
        ok, result = Commerce.propertyQuote(copy, args.PropertyId)
        if ok then
            result = { Credit = result.Amount }
        end
    elseif operation == "UpgradeGarage" then
        ok, result = Commerce.upgradeGarage(copy, args.PropertyId, time)
        if ok then
            result = { Debit = result.Price, Capacity = result.Capacity }
        end
    elseif operation == "BuyModule" then
        ok, result = Commerce.buyModule(copy, args.PropertyId, args.ModuleId, environment, time)
        if ok then
            result = { Debit = result.Price }
        end
    elseif operation == "BuyPart" then
        ok, result = Commerce.buyPart(copy, args.PartId, time)
        if ok then
            result = { Debit = result.Price }
        end
    elseif operation == "SellPart" then
        ok, result = Commerce.sellPart(copy, args.PartItemId, time)
        if ok then
            result = { Credit = result.Amount }
        end
    elseif operation == "Repair" then
        local _, vehicleId = ProgressionService.outVehicle(player)
        ok, result = Commerce.repairQuote(copy, vehicleId or args.VehicleId)
        if ok then
            result = { Debit = result.Amount }
        end
    elseif operation == "Wash" then
        ok, result = true, { Debit = EconomyCatalog.WashPrice }
    elseif operation == "BuyListing" then
        for _, listing in listings() do
            if listing.Id == args.ListingId then
                ok, result = true, { Debit = listing.Price }
            end
        end
    elseif operation == "ListVehicle" and Wallet.validAmount(args.Price) then
        local fee = math.floor(args.Price * EconomyContracts.Ratios.PlayerMarketCommission + 0.5)
        ok, result = true, { Price = args.Price, Fee = fee, Net = args.Price - fee }
    end
    if not ok then
        return { Status = "Rejected", Error = tostring(result) }
    end
    return { Status = "Ok", Result = result }
end

local function handle(player: Player, action: any, payload: any): Response
    if type(action) ~= "string" or handlers[action] == nil then
        return rejected("ActionUnknown")
    end
    local bucket = limiters[player]
    if bucket == nil then
        bucket = RateLimiter.new(6, 2, os.clock())
        limiters[player] = bucket
    end
    if not RateLimiter.consume(bucket, os.clock()) then
        return rejected("RateLimited")
    end
    if EconomyProtocol.Sensitive[action] and moving(player) then
        return rejected("MenuWhileMoving")
    end
    local txId: string? = nil
    if EconomyProtocol.Sensitive[action] then
        txId = TransactionService.clientTxId(if type(payload) == "table" then payload.RequestId else nil)
        if txId == nil then
            return rejected("RequestIdInvalid")
        end
    end
    local ok, response = pcall(handlers[action], player, payload, txId)
    if not ok then
        ProfileService.Log:write("Error", "EconomyHandlerFailed", { Action = action, Error = tostring(response) })
        return rejected("ServerError")
    end
    return response
end

-- ============================== Battements ==============================

local function tickEnergy(dt: number)
    for player, energy in energySessions do
        if energy.Settling then
            continue
        end
        local model = energy.Model
        local present = model.Parent ~= nil
        local position = if present then model:GetPivot().Position else Vector3.zero
        local _, speed = VehicleService.personalDriver(model)
        local stop = not present
            or not Locations.within(energy.Place, position)
            or speed > 1.5
            or os.clock() - energy.StartedAt > ENERGY_MAX_S
            or energy.Delivered >= energy.MaxUnits - 1e-6
        if not stop then
            local rate = EconomyCatalog.DeliveryRate[energy.Kind] or 1
            local wanted = math.min(rate * dt, energy.MaxUnits - energy.Delivered)
            energy.Delivered += VehicleService.addEnergy(model, wanted)
            stop = energy.Delivered >= energy.MaxUnits - 1e-6
        end
        if stop then
            task.spawn(settleEnergy, player, energy)
        end
    end
end

-- Invites des lieux économiques : ouvrent le panneau sur l'onglet adapté.
local function installPrompts(map: Instance?, devZone: any)
    local function attach(part: BasePart, tab: string, label: string)
        local prompt = Instance.new("ProximityPrompt")
        prompt.Name = "AWEconomyPrompt"
        prompt.ActionText = "Ouvrir"
        prompt.ObjectText = label
        prompt.HoldDuration = 0.2
        prompt.MaxActivationDistance = 20
        prompt.RequiresLineOfSight = false
        prompt.Parent = part
        prompt.Triggered:Connect(function(player)
            push:FireClient(player, "Open", { Tab = tab })
        end)
    end
    if devZone then
        attach(devZone.Dealer, "Concession", "Concession")
        attach(devZone.Station, "Services", "Station-service")
        return
    end
    if map == nil then
        return
    end
    for _, place in Locations.all() do
        local tab = if place.Kind == "Dealership"
            then "Concession"
            elseif place.Kind == "FuelStation" or place.Kind == "ChargingHub" or place.Kind == "CarWash" then "Services"
            else nil
        if tab then
            local model = map:FindFirstChild(place.Id, true)
            local slab = if model and model:IsA("Model") then model.PrimaryPart else nil
            if slab then
                attach(slab, tab, place.Label)
            end
        end
    end
end

function EconomyService.start(openWorld: boolean, map: Instance?, devZone: any)
    assert(not started, "EconomyService déjà démarré")
    started = true
    local existing = ReplicatedStorage:FindFirstChild(EconomyProtocol.FolderName)
    if existing then
        existing:Destroy()
    end
    local folder = Instance.new("Folder")
    folder.Name = EconomyProtocol.FolderName
    local request = Instance.new("RemoteFunction")
    request.Name = EconomyProtocol.Request
    request.Parent = folder
    push = Instance.new("RemoteEvent")
    push.Name = EconomyProtocol.Push
    push.Parent = folder
    folder.Parent = ReplicatedStorage
    request.OnServerInvoke = function(player: Player, action: any, payload: any): any
        return handle(player, action, payload)
    end
    installPrompts(map, devZone)

    MissionService.start_(openWorld, function(player, kind, data)
        push:FireClient(player, kind, data)
        push:FireClient(player, "Snapshot", snapshot(player))
    end)

    -- Reprise des transferts : à l'arrivée du joueur et périodiquement.
    ProfileService.onLoaded(function(player)
        pcall(Market.processInbox, marketContext(), player.UserId)
        push:FireClient(player, "Snapshot", snapshot(player))
    end)
    -- Départ : service d'énergie réglé au réel avant la sauvegarde finale.
    ProfileService.onReleasing(function(player)
        local energy = energySessions[player]
        if energy then
            settleEnergy(player, energy)
        end
        limiters[player] = nil
    end)

    local energyTimer, inboxTimer, sweepTimer = 0, 0, 0
    RunService.Heartbeat:Connect(function(dt)
        energyTimer += dt
        inboxTimer += dt
        sweepTimer += dt
        if energyTimer >= ENERGY_TICK_S then
            tickEnergy(energyTimer)
            energyTimer = 0
        end
        if inboxTimer >= INBOX_INTERVAL_S then
            inboxTimer = 0
            for _, player in Players:GetPlayers() do
                task.spawn(function()
                    pcall(Market.processInbox, marketContext(), player.UserId)
                end)
            end
        end
        if sweepTimer >= SWEEP_INTERVAL_S then
            sweepTimer = 0
            task.spawn(function()
                pcall(Market.sweep, marketContext(), 20)
            end)
        end
    end)
end

EconomyService.snapshot = snapshot

return table.freeze(EconomyService)
