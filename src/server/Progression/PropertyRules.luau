--!strict
--[[
    Propriétés privées (§4.1, §4.2, SCN-07), règles PURES.

    - Propriété gratuite : attribuée UNE fois (attribution « FreeProperty »
      inscrite dans Grants, transaction d'identifiant fixe), invendable, compte
      dans le plafond de cinq.
    - Plafond : cinq propriétés possédées simultanément, gratuite comprise ;
      une sixième acquisition est refusée.
    - Revente (lot 0.5) : seules les propriétés payantes ; à la cession, les
      véhicules exposés retournent au rangement : la collection ne dépend
      jamais des places d'exposition.
    - Agrandissement du garage : niveau borné par la catégorie.
]]

local Persistence = script.Parent.Parent.Persistence
local ProfileSchema = require(Persistence.ProfileSchema)
-- Modules partagés atteints par l'arborescence (aucun accès à `game` : module pur).
local Shared = script.Parent.Parent.Parent.Parent.ReplicatedStorage.Shared
local PropertyCatalog = require(Shared.Garage.PropertyCatalog)

local PropertyRules = {}

PropertyRules.FreeGrantTxId = "Grant:FreeProperty"

function PropertyRules.count(profile: ProfileSchema.Profile): number
    local count = 0
    for _ in profile.Properties do
        count += 1
    end
    return count
end

function PropertyRules.capacity(property: ProfileSchema.Property): number
    return PropertyCatalog.capacity(property.Category :: any, property.GarageLevel)
end

local function add(
    profile: ProfileSchema.Profile,
    offerId: string,
    origin: string,
    sellable: boolean,
    synthetic: boolean,
    now: number
): (boolean, any)
    local offer = PropertyCatalog.offer(offerId)
    if offer == nil then
        return false, "PropertyUnknownOffer"
    end
    if PropertyRules.count(profile) >= PropertyCatalog.MaxOwned then
        return false, "PropertyLimit"
    end
    local id = ProfileSchema.nextId(profile, "Property", "P")
    profile.Properties[id] = {
        Id = id,
        OfferId = offer.Id,
        Category = offer.Category,
        AcquiredAt = now,
        Origin = origin,
        Sellable = sellable,
        GarageLevel = 0,
        Modules = {},
        Synthetic = synthetic,
    }
    return true, id
end

-- Attribution unique de la propriété gratuite (idempotente par état ET par transaction).
function PropertyRules.grantFree(profile: ProfileSchema.Profile, now: number): (boolean, any)
    if profile.Grants.FreeProperty ~= nil then
        return false, "FreePropertyAlreadyGranted"
    end
    local ok, result = add(profile, PropertyCatalog.StarterOfferId, "FreeStarter", false, false, now)
    if not ok then
        return false, result
    end
    profile.Grants.FreeProperty = { At = now, Ref = result }
    return true, { PropertyId = result }
end

--[[
    Acquisition d'une propriété (contrat du lot 0.5 : appelée seulement après
    un paiement confirmé, ou pour des données synthétiques de développement).
]]
function PropertyRules.acquire(
    profile: ProfileSchema.Profile,
    offerId: string,
    origin: string,
    synthetic: boolean,
    now: number
): (boolean, any)
    local offer = PropertyCatalog.offer(offerId)
    if offer and offer.Starter then
        return false, "PropertyStarterOfferNotForSale"
    end
    return add(profile, offerId, origin, true, synthetic, now)
end

-- Cession (contrat du lot 0.5) : véhicules exposés rangés, rien n'est perdu.
function PropertyRules.release(profile: ProfileSchema.Profile, propertyId: string): (boolean, any)
    local property = profile.Properties[propertyId]
    if property == nil then
        return false, "PropertyNotOwned"
    end
    if not property.Sellable then
        return false, "PropertyNotSellable"
    end
    local moved = 0
    for _, vehicle in profile.Vehicles do
        local storage = vehicle.Storage
        if storage.PropertyId == propertyId or storage.ReturnProperty == propertyId then
            if storage.State == "Displayed" then
                vehicle.Storage = { State = "Stored" }
                moved += 1
            else
                storage.ReturnProperty = nil
                storage.ReturnSlot = nil
            end
        end
    end
    for id, invitation in profile.Invitations do
        if invitation.PropertyId == propertyId then
            profile.Invitations[id] = nil
        end
    end
    profile.Properties[propertyId] = nil
    return true, { Moved = moved }
end

-- Agrandissement d'un niveau (contrat du lot 0.5).
function PropertyRules.upgradeGarage(profile: ProfileSchema.Profile, propertyId: string): (boolean, any)
    local property = profile.Properties[propertyId]
    if property == nil then
        return false, "PropertyNotOwned"
    end
    if property.GarageLevel >= PropertyCatalog.maxGarageLevel(property.Category :: any) then
        return false, "GarageMaxLevel"
    end
    property.GarageLevel += 1
    return true, { Level = property.GarageLevel, Capacity = PropertyRules.capacity(property) }
end

return table.freeze(PropertyRules)
