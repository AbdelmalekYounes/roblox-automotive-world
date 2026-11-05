--!strict
--[[
    Collection automobile (lot 0.4 §5) : exemplaires possédés, à identifiant
    unique permanent, PURS (opèrent sur un profil, sans service Roblox).

    - Aucune limite globale arbitraire du nombre d'exemplaires : seule la
      limite TECHNIQUE de taille d'enregistrement (ProfileSchema) peut refuser
      une acquisition, explicitement.
    - Réservation : une opération sensible future (course, vente, prêt) pose
      une réservation ; tant qu'elle court, les opérations incompatibles sont
      refusées (AUD-RACE-02). Une réservation expirée est levée au
      chargement.
    - Transfert futur (lot 0.5) : seule une copie TRANSFÉRABLE est produite :
      pièces installées incluses, configurations réalisables seulement,
      jamais un exemplaire incessible (AUD-ECO-02).
]]

local Persistence = script.Parent.Parent.Persistence
local ProfileSchema = require(Persistence.ProfileSchema)
local ProfileMigration = require(Persistence.ProfileMigration)

local VehicleOwnership = {}

export type Acquisition = {
    ModelId: string,
    Origin: string,
    Untransferable: boolean,
    Synthetic: boolean,
    EnergyFraction: number, -- réserve à la livraison (fraction du modèle)
    Cosmetics: { [string]: any },
}

-- Ajoute un exemplaire à la collection ; renvoie son identifiant.
function VehicleOwnership.add(profile: ProfileSchema.Profile, acquisition: Acquisition, now: number): string
    local id = ProfileSchema.nextId(profile, "Vehicle", "V")
    profile.Vehicles[id] = {
        Schema = ProfileSchema.Version,
        Id = id,
        ModelId = acquisition.ModelId,
        OwnerUserId = profile.UserId,
        AcquiredAt = now,
        Origin = acquisition.Origin,
        Untransferable = acquisition.Untransferable,
        Synthetic = acquisition.Synthetic,
        OdometerKm = 0,
        Energy = math.clamp(acquisition.EnergyFraction, 0, 1),
        Damage = ProfileSchema.pristineDamage(),
        InstalledParts = {},
        Tuning = {},
        Cosmetics = acquisition.Cosmetics,
        Configurations = {},
        Storage = { State = "Stored" },
        Reservation = nil,
        UpdatedAt = now,
    }
    return id
end

function VehicleOwnership.get(profile: ProfileSchema.Profile, vehicleId: any): ProfileSchema.Vehicle?
    if type(vehicleId) ~= "string" then
        return nil
    end
    return profile.Vehicles[vehicleId]
end

function VehicleOwnership.reserved(vehicle: ProfileSchema.Vehicle, now: number): boolean
    local reservation = vehicle.Reservation
    return reservation ~= nil and reservation.ExpiresAt > now
end

-- Pose une réservation exclusive (opérations futures : course, vente, prêt).
function VehicleOwnership.reserve(
    profile: ProfileSchema.Profile,
    vehicleId: string,
    kind: string,
    txId: string,
    now: number,
    duration: number
): (boolean, string?)
    local vehicle = profile.Vehicles[vehicleId]
    if vehicle == nil then
        return false, "VehicleNotOwned"
    end
    if VehicleOwnership.reserved(vehicle, now) then
        return false, "VehicleReserved"
    end
    vehicle.Reservation = { Kind = kind, TxId = txId, Since = now, ExpiresAt = now + duration }
    return true, nil
end

function VehicleOwnership.clearReservation(profile: ProfileSchema.Profile, vehicleId: string, txId: string): boolean
    local vehicle = profile.Vehicles[vehicleId]
    if vehicle and vehicle.Reservation and vehicle.Reservation.TxId == txId then
        vehicle.Reservation = nil
        return true
    end
    return false
end

-- Une configuration est réalisable si toutes ses pièces sont installées sur le véhicule.
function VehicleOwnership.realizable(
    profile: ProfileSchema.Profile,
    vehicle: ProfileSchema.Vehicle,
    configuration: ProfileSchema.Configuration
): boolean
    for slot, partId in configuration.Parts do
        local installedItem = vehicle.InstalledParts[slot]
        local part = if installedItem then profile.Parts[installedItem] else nil
        if part == nil or part.PartId ~= partId then
            return false
        end
    end
    return true
end

--[[
    Copie transférable d'un exemplaire (préparation des ventes du lot 0.5) :
    le véhicule, ses pièces INSTALLÉES et ses seules configurations
    réalisables ; les pièces détachées restent au vendeur. Refusé pour un
    exemplaire incessible, synthétique ou réservé.
]]
function VehicleOwnership.transferableCopy(
    profile: ProfileSchema.Profile,
    vehicleId: string,
    now: number
): (boolean, any)
    local vehicle = profile.Vehicles[vehicleId]
    if vehicle == nil then
        return false, "VehicleNotOwned"
    end
    if vehicle.Untransferable then
        return false, "VehicleUntransferable"
    end
    if vehicle.Synthetic then
        return false, "VehicleSynthetic"
    end
    if VehicleOwnership.reserved(vehicle, now) then
        return false, "VehicleReserved"
    end
    local copy = ProfileMigration.deepCopy(vehicle)
    copy.Configurations = {}
    for _, configuration in vehicle.Configurations do
        if VehicleOwnership.realizable(profile, vehicle, configuration) then
            table.insert(copy.Configurations, ProfileMigration.deepCopy(configuration))
        end
    end
    local parts = {}
    for slot, partId in vehicle.InstalledParts do
        parts[slot] = ProfileMigration.deepCopy(profile.Parts[partId])
    end
    copy.Storage = { State = "Stored" }
    copy.Reservation = nil
    return true, { Vehicle = copy, Parts = parts }
end

--[[
    Page de la collection (tri par date d'acquisition puis identifiant) :
    l'interface ne reçoit jamais toute une grande collection d'un coup.
]]
function VehicleOwnership.page(
    profile: ProfileSchema.Profile,
    page: number,
    pageSize: number
): ({ ProfileSchema.Vehicle }, number)
    local all: { ProfileSchema.Vehicle } = {}
    for _, vehicle in profile.Vehicles do
        table.insert(all, vehicle)
    end
    table.sort(all, function(a, b)
        if a.AcquiredAt ~= b.AcquiredAt then
            return a.AcquiredAt < b.AcquiredAt
        end
        return a.Id < b.Id
    end)
    local size = math.clamp(math.floor(pageSize), 1, 50)
    local pages = math.max(1, math.ceil(#all / size))
    local index = math.clamp(math.floor(page), 1, pages)
    local result: { ProfileSchema.Vehicle } = {}
    for i = (index - 1) * size + 1, math.min(index * size, #all) do
        table.insert(result, all[i])
    end
    return result, pages
end

return table.freeze(VehicleOwnership)
