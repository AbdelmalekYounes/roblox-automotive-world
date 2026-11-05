--!strict
--[[
    Occupation des pompes et des bornes (lot 0.9), règle PURE.

    Un lieu de service a un nombre de pompes (carburant) et de bornes (recharge)
    déclaré par la carte (lot 0.3) ; une station sans nombre déclaré (zone
    d'essai) en compte deux de chaque. Un plein ou une recharge occupe une place
    du type adapté pendant toute sa session ; au-delà de la capacité, la demande
    est refusée (« StationFull ») au lieu de servir plus de véhicules qu'il n'y a
    d'équipements. Aucune file d'attente : le joueur réessaie quand une place se
    libère (fin d'une session : plein terminé, départ, 180 s au plus).
]]

local StationRules = {}

StationRules.DefaultSlots = 2

export type Place = { Id: string, Pumps: number?, Chargers: number? }
export type Active = { PlaceId: string, Electric: boolean }

-- Nombre de places pour une énergie (électrique : bornes ; sinon : pompes).
function StationRules.capacity(place: Place, electric: boolean): number
    local declared = if electric then place.Chargers else place.Pumps
    if type(declared) ~= "number" then
        return StationRules.DefaultSlots
    end
    return math.max(0, math.floor(declared))
end

-- Une session de plus peut-elle commencer à ce lieu ? Renvoie (accepté, raison).
function StationRules.canStart(sessions: { Active }, place: Place, electric: boolean): (boolean, string?)
    local capacity = StationRules.capacity(place, electric)
    if capacity <= 0 then
        return false, if electric then "NoCharger" else "NoPump"
    end
    local used = 0
    for _, session in sessions do
        if session.PlaceId == place.Id and session.Electric == electric then
            used += 1
        end
    end
    if used >= capacity then
        return false, "StationFull"
    end
    return true, nil
end

return table.freeze(StationRules)
