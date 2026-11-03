--!strict
--[[
    Réservation exclusive de l'exemplaire engagé en course (lot 0.6,
    AUD-RACE-02, §6.4), mutations PURES d'un profil (une seule clé : atomique
    avec le reste de l'opération, idempotente par l'identifiant de transaction).

    reserve : l'exemplaire doit être possédé, physiquement sorti (conduit), et
    libre (aucune réservation : vente, annonce, autre course). Pose
      Vehicle.Reservation = { Kind = "Race", TxId = <engagement>, ExpiresAt }
    et Racing.Active (course, mode, véhicule). En mode PROTÉGÉ, l'état durable
    initial (énergie, dégâts — y compris ceux déjà présents —, kilométrage,
    salissure) est copié dans Racing.Active.Snapshot.
    Toutes les opérations existantes refusent un exemplaire réservé : vente,
    reprise, annonce, transfert, préparation, pièces, réglages, rangement
    (GarageRules, Customization, Commerce, Market) ; services de
    l'exemplaire (réparation, lavage, énergie) refusés pendant la course.

    release : à la fin EFFECTIVE de l'engagement. Mode protégé : l'état initial
    est restauré EXACTEMENT (les dégâts antérieurs ne sont pas effacés, ceux
    de la course disparaissent) ; mode réaliste : l'état mesuré reste.

    Expiration : ExpiresAt couvre l'inscription, la course la plus longue et
    la fenêtre de reconnexion ; seule la récupération (RaceRecovery) la traite,
    en appliquant la même libération (jamais une simple suppression).
]]

local Shared = script.Parent.Parent.Parent.Parent.ReplicatedStorage.Shared
local RaceDefinitions = require(Shared.Racing.RaceDefinitions)
local Persistence = script.Parent.Parent.Persistence
local ProfileSchema = require(Persistence.ProfileSchema)
local ProfileMigration = require(Persistence.ProfileMigration)
local Progression = script.Parent.Parent.Progression
local VehicleOwnership = require(Progression.VehicleOwnership)
local GarageRules = require(Progression.GarageRules)

local VehicleRaceReservation = {}

-- Durée de la réservation : inscription + épreuve maximale + reconnexion + marge.
local timing = RaceDefinitions.Timing
VehicleRaceReservation.DurationS = timing.LobbyMaxS + timing.MaxRaceS + timing.ReconnectWindowS + 120

export type Args = {
    EntryId: string,
    RaceId: string,
    CourseId: string,
    Discipline: string,
    Kind: string,
    Mode: string,
    VehicleId: string,
}

-- Exemplaire engagé dans une course en cours ?
function VehicleRaceReservation.inRace(vehicle: ProfileSchema.Vehicle, now: number): boolean
    local reservation = vehicle.Reservation
    return reservation ~= nil and reservation.Kind == "Race" and reservation.ExpiresAt > now
end

function VehicleRaceReservation.reserve(profile: ProfileSchema.Profile, args: Args, now: number): (boolean, any)
    local racing = profile.Racing
    local active = racing.Active
    if active ~= nil then
        if active.EntryId == args.EntryId then
            return true, { EntryId = args.EntryId, Already = true }
        end
        return false, "RaceAlreadyEngaged"
    end
    local vehicle = VehicleOwnership.get(profile, args.VehicleId)
    if vehicle == nil then
        return false, "VehicleNotOwned"
    end
    if VehicleOwnership.reserved(vehicle, now) then
        local kind = (vehicle.Reservation :: ProfileSchema.Reservation).Kind
        return false, if kind == "Listing" then "VehicleListed" else "VehicleReserved"
    end
    if vehicle.Storage.State ~= "Out" then
        return false, "VehicleNotOut"
    end
    if not RaceDefinitions.validMode(args.Mode) then
        return false, "RaceModeNotAllowed"
    end
    local ok, err =
        VehicleOwnership.reserve(profile, vehicle.Id, "Race", args.EntryId, now, VehicleRaceReservation.DurationS)
    if not ok then
        return false, err
    end
    local snapshot: ProfileSchema.RaceSnapshot? = nil
    if args.Mode == "Protected" then
        snapshot = {
            Energy = vehicle.Energy,
            Damage = ProfileMigration.deepCopy(vehicle.Damage),
            OdometerKm = vehicle.OdometerKm,
            Dirt = vehicle.Dirt,
        }
    end
    racing.Active = {
        EntryId = args.EntryId,
        RaceId = args.RaceId,
        CourseId = args.CourseId,
        Discipline = args.Discipline,
        Kind = args.Kind,
        Mode = args.Mode,
        VehicleId = vehicle.Id,
        Snapshot = snapshot,
        Since = now,
        ExpiresAt = now + VehicleRaceReservation.DurationS,
    }
    return true, { EntryId = args.EntryId, Mode = args.Mode, Snapshot = snapshot ~= nil }
end

--[[
    Libère l'engagement `entryId`. Idempotente : sans engagement
    correspondant, renvoie (true, { AlreadyReleased = true }). Renvoie l'état
    restauré (mode protégé) pour l'appliquer aussi au véhicule matérialisé.
]]
function VehicleRaceReservation.release(profile: ProfileSchema.Profile, entryId: string, now: number): (boolean, any)
    local racing = profile.Racing
    local active = racing.Active
    if active == nil or active.EntryId ~= entryId then
        return true, { AlreadyReleased = true }
    end
    local vehicle = profile.Vehicles[active.VehicleId]
    local restored: ProfileSchema.RaceSnapshot? = nil
    if vehicle then
        if active.Mode == "Protected" and active.Snapshot then
            local snapshot = active.Snapshot :: ProfileSchema.RaceSnapshot
            vehicle.Energy = snapshot.Energy
            vehicle.Damage = ProfileMigration.deepCopy(snapshot.Damage)
            vehicle.OdometerKm = snapshot.OdometerKm
            vehicle.Dirt = snapshot.Dirt
            vehicle.UpdatedAt = now
            restored = ProfileMigration.deepCopy(snapshot)
        end
        VehicleOwnership.clearReservation(profile, vehicle.Id, entryId)
    end
    racing.Active = nil
    return true, { VehicleId = active.VehicleId, Mode = active.Mode, Restored = restored }
end

--[[
    Reprise après reconnexion (même épreuve) : l'exemplaire, revenu au garage
    au départ du joueur, est de nouveau matérialisé. Seule exception à
    « réservé = aucune sortie » : la réservation doit être CELLE de cet
    engagement. Aucun second exemplaire physique (une seule sortie).
]]
function VehicleRaceReservation.resumeTakeOut(
    profile: ProfileSchema.Profile,
    entryId: string,
    session: string,
    now: number
): (boolean, any)
    local active = profile.Racing.Active
    if active == nil or active.EntryId ~= entryId then
        return false, "RaceNotEngaged"
    end
    local vehicle = profile.Vehicles[active.VehicleId]
    if vehicle == nil then
        return false, "VehicleNotOwned"
    end
    local reservation = vehicle.Reservation
    if reservation == nil or reservation.Kind ~= "Race" or reservation.TxId ~= entryId then
        return false, "VehicleReserved"
    end
    if vehicle.Storage.State == "Out" then
        return false, "VehicleOut"
    end
    if GarageRules.outCount(profile) >= GarageRules.MaxOut then
        return false, "AnotherVehicleOut"
    end
    local previous = vehicle.Storage
    vehicle.Storage = {
        State = "Out",
        Session = session,
        ReturnProperty = if previous.State == "Displayed" then previous.PropertyId else nil,
        ReturnSlot = if previous.State == "Displayed" then previous.Slot else nil,
    }
    vehicle.UpdatedAt = now
    return true, { VehicleId = vehicle.Id }
end

return table.freeze(VehicleRaceReservation)
