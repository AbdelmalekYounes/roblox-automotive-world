--!strict
--[[
    Personnalisation esthétique, préparation mécanique, pièces et
    configurations d'un exemplaire (lot 0.4 §9 à §11, AUD-ECO-02, SCN-04),
    règles PURES.

    - Chaque action exige une CAPACITÉ du lieu (GarageModules), fournie par
      l'appelant après vérification serveur de la position du joueur.
    - Réglages : validés contre les plages du modèle et des pièces installées
      (TuningRules) ; une valeur hors plage est refusée.
    - Pièces : un exemplaire de pièce est soit détaché, soit installé sur UN
      véhicule. Poser une pièce consomme une pièce détachée possédée ;
      déposer la rend détachée. Rien n'est créé.
    - Configurations (5 au plus) : jeux de réglages, de choix de pièces et
      d'esthétique. Les appliquer ne crée aucune pièce : chaque pièce requise
      doit être déjà installée ou disponible (détachée) et compatible.
    - Exemplaire sorti (« Out ») ou réservé : aucune modification.
]]

local Persistence = script.Parent.Parent.Persistence
local ProfileSchema = require(Persistence.ProfileSchema)
local ProfileMigration = require(Persistence.ProfileMigration)
local VehicleOwnership = require(script.Parent.VehicleOwnership)

local Shared = script.Parent.Parent.Parent.Parent.ReplicatedStorage.Shared
local TuningRules = require(Shared.Garage.TuningRules)
local CosmeticCatalog = require(Shared.Garage.CosmeticCatalog)
local PartCatalog = require(Shared.Garage.PartCatalog)

local Customization = {}

Customization.MaxNameLength = 24

type Capabilities = { [string]: boolean }

local function editable(profile: ProfileSchema.Profile, vehicleId: any, now: number): (ProfileSchema.Vehicle?, string?)
    local vehicle = VehicleOwnership.get(profile, vehicleId)
    if vehicle == nil then
        return nil, "VehicleNotOwned"
    end
    if VehicleOwnership.reserved(vehicle, now) then
        return nil, "VehicleReserved"
    end
    if vehicle.Storage.State == "Out" then
        return nil, "VehicleOut"
    end
    return vehicle, nil
end

-- Pièces du catalogue installées sur un exemplaire (emplacement → pièce du catalogue).
function Customization.catalogParts(
    profile: ProfileSchema.Profile,
    vehicle: ProfileSchema.Vehicle
): { [string]: string }
    local result: { [string]: string } = {}
    for slot, itemId in vehicle.InstalledParts do
        local item = profile.Parts[itemId]
        if item then
            result[slot] = item.PartId
        end
    end
    return result
end

local function sanitizeTuning(value: any): { [string]: number }?
    if type(value) ~= "table" then
        return nil
    end
    local result: { [string]: number } = {}
    for key, entry in value do
        if type(key) ~= "string" or type(entry) ~= "number" then
            return nil
        end
        result[key] = entry
    end
    return result
end

function Customization.setTuning(
    profile: ProfileSchema.Profile,
    vehicleId: any,
    tuning: any,
    definition: any,
    capabilities: Capabilities,
    now: number
): (boolean, any)
    if not capabilities.EditTuning then
        return false, "CapabilityMissing:EditTuning"
    end
    local vehicle, problem = editable(profile, vehicleId, now)
    if vehicle == nil then
        return false, problem
    end
    local clean = sanitizeTuning(tuning)
    if clean == nil then
        return false, "TuningInvalid"
    end
    local ok, errors = TuningRules.validate(definition, clean, Customization.catalogParts(profile, vehicle))
    if not ok then
        return false, errors[1]
    end
    vehicle.Tuning = clean
    vehicle.UpdatedAt = now
    return true, { VehicleId = vehicle.Id }
end

function Customization.setCosmetics(
    profile: ProfileSchema.Profile,
    vehicleId: any,
    cosmetics: any,
    capabilities: Capabilities,
    now: number
): (boolean, any)
    if not capabilities.EditCosmetics then
        return false, "CapabilityMissing:EditCosmetics"
    end
    local vehicle, problem = editable(profile, vehicleId, now)
    if vehicle == nil then
        return false, problem
    end
    local ok, errors = CosmeticCatalog.validate(cosmetics)
    if not ok then
        return false, errors[1]
    end
    vehicle.Cosmetics = ProfileMigration.deepCopy(cosmetics)
    vehicle.UpdatedAt = now
    return true, { VehicleId = vehicle.Id }
end

-- Pièce détachée possédée d'un type donné (la plus ancienne, ordre stable).
local function detachedOf(profile: ProfileSchema.Profile, partId: string): ProfileSchema.PartItem?
    local best: ProfileSchema.PartItem? = nil
    for _, item in profile.Parts do
        if item.PartId == partId and item.InstalledOn == nil then
            if best == nil or item.Id < (best :: ProfileSchema.PartItem).Id then
                best = item
            end
        end
    end
    return best
end

local function uninstall(profile: ProfileSchema.Profile, vehicle: ProfileSchema.Vehicle, slot: string)
    local itemId = vehicle.InstalledParts[slot]
    if itemId then
        local item = profile.Parts[itemId]
        if item then
            item.InstalledOn = nil
        end
        vehicle.InstalledParts[slot] = nil
    end
end

-- Retire les réglages devenus irréalisables après un changement de pièces.
local function pruneTuning(profile: ProfileSchema.Profile, vehicle: ProfileSchema.Vehicle, definition: any)
    local ranges = TuningRules.ranges(definition, Customization.catalogParts(profile, vehicle))
    for key, value in vehicle.Tuning do
        local range = ranges[key]
        if range == nil or value < range.Min or value > range.Max then
            vehicle.Tuning[key] = nil
        end
    end
end

-- Pose (partId = pièce du catalogue) ou dépose (partId = nil) dans un emplacement.
function Customization.setPart(
    profile: ProfileSchema.Profile,
    vehicleId: any,
    slot: any,
    partId: any,
    definition: any,
    capabilities: Capabilities,
    now: number
): (boolean, any)
    if not capabilities.SwapParts then
        return false, "CapabilityMissing:SwapParts"
    end
    local vehicle, problem = editable(profile, vehicleId, now)
    if vehicle == nil then
        return false, problem
    end
    if type(slot) ~= "string" or table.find(PartCatalog.Slots, slot :: any) == nil then
        return false, "PartSlotUnknown"
    end
    if partId == nil then
        uninstall(profile, vehicle, slot)
    else
        local part = if type(partId) == "string" then PartCatalog.get(partId) else nil
        if part == nil or part.Slot ~= slot then
            return false, "PartUnknown"
        end
        if not PartCatalog.compatible(part, definition) then
            return false, "PartIncompatible"
        end
        local current = vehicle.InstalledParts[slot]
        if current and profile.Parts[current] and profile.Parts[current].PartId == part.Id then
            return true, { VehicleId = vehicle.Id, Unchanged = true }
        end
        local item = detachedOf(profile, part.Id)
        if item == nil then
            return false, "PartNotOwned"
        end
        uninstall(profile, vehicle, slot)
        item.InstalledOn = vehicle.Id
        vehicle.InstalledParts[slot] = item.Id
    end
    pruneTuning(profile, vehicle, definition)
    vehicle.UpdatedAt = now
    return true, { VehicleId = vehicle.Id }
end

-- Enregistre l'état courant dans la configuration `index` (1 à 5).
function Customization.saveConfiguration(
    profile: ProfileSchema.Profile,
    vehicleId: any,
    index: any,
    name: any,
    now: number
): (boolean, any)
    local vehicle = VehicleOwnership.get(profile, vehicleId)
    if vehicle == nil then
        return false, "VehicleNotOwned"
    end
    if
        type(index) ~= "number"
        or index ~= math.floor(index)
        or index < 1
        or index > ProfileSchema.MaxConfigurations
    then
        return false, "ConfigIndex"
    end
    if index > #vehicle.Configurations + 1 then
        return false, "ConfigIndex"
    end
    if type(name) ~= "string" or #name == 0 or #name > Customization.MaxNameLength then
        return false, "ConfigName"
    end
    vehicle.Configurations[index] = {
        Name = name,
        UpdatedAt = now,
        Tuning = ProfileMigration.deepCopy(vehicle.Tuning),
        Parts = Customization.catalogParts(profile, vehicle),
        Cosmetics = ProfileMigration.deepCopy(vehicle.Cosmetics),
    }
    return true, { VehicleId = vehicle.Id, Index = index }
end

function Customization.deleteConfiguration(profile: ProfileSchema.Profile, vehicleId: any, index: any): (boolean, any)
    local vehicle = VehicleOwnership.get(profile, vehicleId)
    if vehicle == nil then
        return false, "VehicleNotOwned"
    end
    if type(index) ~= "number" or vehicle.Configurations[index] == nil then
        return false, "ConfigIndex"
    end
    table.remove(vehicle.Configurations, index)
    return true, { VehicleId = vehicle.Id }
end

--[[
    Application d'une configuration. Les pièces requises doivent exister
    (installées ou détachées) et être compatibles ; un échange de pièces exige
    la capacité SwapParts (garage public). Tout ou rien.
]]
function Customization.applyConfiguration(
    profile: ProfileSchema.Profile,
    vehicleId: any,
    index: any,
    definition: any,
    capabilities: Capabilities,
    now: number
): (boolean, any)
    if not capabilities.ApplyConfiguration then
        return false, "CapabilityMissing:ApplyConfiguration"
    end
    local vehicle, problem = editable(profile, vehicleId, now)
    if vehicle == nil then
        return false, problem
    end
    local configuration = if type(index) == "number" then vehicle.Configurations[index] else nil
    if configuration == nil then
        return false, "ConfigIndex"
    end
    local current = Customization.catalogParts(profile, vehicle)
    local swaps = false
    for _, slot in PartCatalog.Slots do
        if current[slot] ~= configuration.Parts[slot] then
            swaps = true
        end
    end
    if swaps then
        if not capabilities.SwapParts then
            return false, "ConfigNeedsPartSwap"
        end
        for slot, partId in configuration.Parts do
            if current[slot] ~= partId then
                local part = PartCatalog.get(partId)
                if part == nil or not PartCatalog.compatible(part, definition) then
                    return false, "ConfigPartIncompatible"
                end
                if detachedOf(profile, partId) == nil then
                    return false, "ConfigPartsMissing"
                end
            end
        end
        for _, slot in PartCatalog.Slots do
            if current[slot] ~= configuration.Parts[slot] then
                local ok, err = Customization.setPart(
                    profile,
                    vehicle.Id,
                    slot,
                    configuration.Parts[slot],
                    definition,
                    capabilities,
                    now
                )
                if not ok then
                    return false, err
                end
            end
        end
    end
    local tuningOk =
        TuningRules.validate(definition, configuration.Tuning, Customization.catalogParts(profile, vehicle))
    if not tuningOk then
        return false, "ConfigTuningInvalid"
    end
    local cosmeticsOk = CosmeticCatalog.validate(configuration.Cosmetics)
    if not cosmeticsOk then
        return false, "ConfigCosmeticsInvalid"
    end
    vehicle.Tuning = ProfileMigration.deepCopy(configuration.Tuning)
    vehicle.Cosmetics = ProfileMigration.deepCopy(configuration.Cosmetics)
    vehicle.UpdatedAt = now
    return true, { VehicleId = vehicle.Id, Index = index, Swapped = swaps }
end

return table.freeze(Customization)
