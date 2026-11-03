--!strict
--[[
    Garages privés : rangement, exposition et sortie des exemplaires (§4.2,
    lot 0.4 §8), règles PURES.

    États d'un exemplaire (exclusifs) :
    - Stored    : rangé dans la collection (aucune limite de nombre) ;
    - Displayed : exposé sur une place d'une propriété (capacité bornée) ;
    - Out       : matérialisé et conduisible dans le monde par UNE session
      serveur. Un exemplaire « Out » ne peut être ni exposé ni ressorti : il
      n'existe jamais deux exemplaires physiques exploitables.
    Au chargement d'un profil (verrou détenu : l'ancienne session a disparu),
    un exemplaire resté « Out » revient à son état précédent.
    Toute opération est refusée sur un exemplaire réservé (course, vente, prêt).
]]

local Persistence = script.Parent.Parent.Persistence
local ProfileSchema = require(Persistence.ProfileSchema)
local VehicleOwnership = require(script.Parent.VehicleOwnership)
local PropertyRules = require(script.Parent.PropertyRules)

local GarageRules = {}

-- Un seul exemplaire personnel matérialisé à la fois par joueur.
GarageRules.MaxOut = 1

local function usable(profile: ProfileSchema.Profile, vehicleId: any, now: number): (ProfileSchema.Vehicle?, string?)
    local vehicle = VehicleOwnership.get(profile, vehicleId)
    if vehicle == nil then
        return nil, "VehicleNotOwned"
    end
    if VehicleOwnership.reserved(vehicle, now) then
        return nil, "VehicleReserved"
    end
    return vehicle, nil
end

function GarageRules.occupant(profile: ProfileSchema.Profile, propertyId: string, slot: number): string?
    for id, vehicle in profile.Vehicles do
        local storage = vehicle.Storage
        if storage.State == "Displayed" and storage.PropertyId == propertyId and storage.Slot == slot then
            return id
        end
    end
    return nil
end

-- Exposer un exemplaire sur une place libre d'une propriété possédée.
function GarageRules.display(
    profile: ProfileSchema.Profile,
    vehicleId: any,
    propertyId: any,
    slot: any,
    now: number
): (boolean, any)
    local vehicle, problem = usable(profile, vehicleId, now)
    if vehicle == nil then
        return false, problem
    end
    if vehicle.Storage.State == "Out" then
        return false, "VehicleOut"
    end
    local property = if type(propertyId) == "string" then profile.Properties[propertyId] else nil
    if property == nil then
        return false, "PropertyNotOwned"
    end
    if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > PropertyRules.capacity(property) then
        return false, "SlotOutOfRange"
    end
    local occupant = GarageRules.occupant(profile, property.Id, slot)
    if occupant ~= nil and occupant ~= vehicle.Id then
        return false, "SlotOccupied"
    end
    vehicle.Storage = { State = "Displayed", PropertyId = property.Id, Slot = slot }
    vehicle.UpdatedAt = now
    return true, { VehicleId = vehicle.Id, PropertyId = property.Id, Slot = slot }
end

-- Ranger un exemplaire (retire l'exposition).
function GarageRules.store(profile: ProfileSchema.Profile, vehicleId: any, now: number): (boolean, any)
    local vehicle, problem = usable(profile, vehicleId, now)
    if vehicle == nil then
        return false, problem
    end
    if vehicle.Storage.State == "Out" then
        return false, "VehicleOut"
    end
    vehicle.Storage = { State = "Stored" }
    vehicle.UpdatedAt = now
    return true, { VehicleId = vehicle.Id }
end

function GarageRules.outCount(profile: ProfileSchema.Profile): number
    local count = 0
    for _, vehicle in profile.Vehicles do
        if vehicle.Storage.State == "Out" then
            count += 1
        end
    end
    return count
end

--[[
    Sortie d'un exemplaire par la session serveur `session` : l'exemplaire
    quitte son exposition (sa place lui est gardée pour le retour si elle est
    toujours libre).
]]
function GarageRules.takeOut(
    profile: ProfileSchema.Profile,
    vehicleId: any,
    session: string,
    now: number
): (boolean, any)
    local vehicle, problem = usable(profile, vehicleId, now)
    if vehicle == nil then
        return false, problem
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

-- Retour au garage : place d'exposition d'origine si elle est libre, sinon rangement.
function GarageRules.bringBack(profile: ProfileSchema.Profile, vehicleId: any, now: number): (boolean, any)
    local vehicle = VehicleOwnership.get(profile, vehicleId)
    if vehicle == nil then
        return false, "VehicleNotOwned"
    end
    if vehicle.Storage.State ~= "Out" then
        return false, "VehicleNotOut"
    end
    local propertyId, slot = vehicle.Storage.ReturnProperty, vehicle.Storage.ReturnSlot
    local property = if propertyId then profile.Properties[propertyId] else nil
    if
        property
        and slot
        and slot <= PropertyRules.capacity(property)
        and GarageRules.occupant(profile, property.Id, slot) == nil
    then
        vehicle.Storage = { State = "Displayed", PropertyId = property.Id, Slot = slot }
    else
        vehicle.Storage = { State = "Stored" }
    end
    vehicle.UpdatedAt = now
    return true, { VehicleId = vehicle.Id, State = vehicle.Storage.State }
end

--[[
    Normalisation au chargement (verrou détenu) : exemplaires restés sortis
    par une session disparue, réservations expirées, expositions au-delà de
    la capacité. Rien n'est supprimé. Renvoie vrai si le profil a changé.
]]
function GarageRules.normalize(profile: ProfileSchema.Profile, now: number): boolean
    local changed = false
    for id, vehicle in profile.Vehicles do
        if vehicle.Storage.State == "Out" then
            GarageRules.bringBack(profile, id, now)
            changed = true
        end
        if vehicle.Reservation and vehicle.Reservation.ExpiresAt <= now then
            vehicle.Reservation = nil
            changed = true
        end
        local storage = vehicle.Storage
        if storage.State == "Displayed" then
            local property = profile.Properties[storage.PropertyId or ""]
            if property == nil or (storage.Slot or 0) > PropertyRules.capacity(property) then
                vehicle.Storage = { State = "Stored" }
                changed = true
            end
        end
    end
    return changed
end

return table.freeze(GarageRules)
