--!strict
--[[
    Lot PNJ-01 : signaux visibles des voitures PNJ (module PUR, testé par Lune) — feux stop et clignotants déduits de
    l'état de l'agent (World/TrafficModel). Le serveur ne publie qu'un CHANGEMENT d'état (attributs du modèle) ; le
    clignotement et l'allumage sont faits par chaque client (World/TrafficVisuals).

    Règles :
    - feux stop : décélération franche (> BrakeDecelMs2) ou véhicule arrêté (le conducteur garde le pied sur le frein) ;
    - clignotant : à l'approche du carrefour (< IndicatorLeadM de la fin du tronçon) quand le tronçon suivant tourne
      de plus de IndicatorAngleDeg ; il reste allumé pendant le virage, jusqu'au début de la voie suivante.
]]

local TrafficModel = require(script.Parent.TrafficModel)

local TrafficCues = {}

TrafficCues.BrakeDecelMs2 = 0.8
TrafficCues.StoppedMs = 0.3
TrafficCues.IndicatorLeadM = 45
TrafficCues.IndicatorAngleDeg = 25
-- Début de la voie suivante (m) pendant lequel le clignotant reste allumé (fin du virage).
TrafficCues.IndicatorTailM = 8

export type Indicator = "G" | "D"

function TrafficCues.braking(speed: number, previousSpeed: number, dt: number): boolean
    if speed < TrafficCues.StoppedMs then
        return true
    end
    return (previousSpeed - speed) / math.max(dt, 1e-3) > TrafficCues.BrakeDecelMs2
end

-- Direction horizontale unitaire du début d'un tronçon parcouru dans le sens `forward`.
local function startDirection(edge: any, forward: boolean): (number?, number?)
    local points = edge.Polyline
    local count = #points
    if count < 2 then
        return nil, nil
    end
    local a = if forward then points[1] else points[count]
    local b = if forward then points[2] else points[count - 1]
    local dx, dz = b.X - a.X, b.Z - a.Z
    local length = math.sqrt(dx * dx + dz * dz)
    if length < 1e-6 then
        return nil, nil
    end
    return dx / length, dz / length
end

--[[
    Côté du virage (« G » / « D ») de `fromX, fromZ` (direction d'arrivée unitaire) vers `toX, toZ`, ou nil si
    l'angle est inférieur au seuil. Droite du sens de marche : (−dz, dx) (convention de RoadGraph).
]]
function TrafficCues.turnSide(fromX: number, fromZ: number, toX: number, toZ: number): Indicator?
    local cosine = math.clamp(fromX * toX + fromZ * toZ, -1, 1)
    if math.deg(math.acos(cosine)) < TrafficCues.IndicatorAngleDeg then
        return nil
    end
    local right = -fromZ * toX + fromX * toZ
    return if right > 0 then "D" else "G"
end

-- Clignotant voulu pour un agent (nil = éteint).
function TrafficCues.indicator(agent: TrafficModel.Agent): Indicator?
    local path = agent.Path
    local remaining = path.Length - agent.S
    local nextLink = agent.Next
    if nextLink and remaining < TrafficCues.IndicatorLeadM then
        local _, arrival = TrafficModel.sample(path, path.Length)
        local toX, toZ = startDirection(nextLink.Edge, nextLink.Forward)
        if toX and toZ then
            return TrafficCues.turnSide(arrival.X, arrival.Z, toX, toZ)
        end
        return nil
    end
    -- Début de voie : fin du virage commencé au carrefour (raccord = premier segment du chemin).
    if agent.S < TrafficCues.IndicatorTailM and #path.Points >= 3 then
        local a, b, c = path.Points[1], path.Points[2], path.Points[3]
        local ax, az = b.X - a.X, b.Z - a.Z
        local bx, bz = c.X - b.X, c.Z - b.Z
        local la, lb = math.sqrt(ax * ax + az * az), math.sqrt(bx * bx + bz * bz)
        if la > 1e-6 and lb > 1e-6 then
            return TrafficCues.turnSide(ax / la, az / la, bx / lb, bz / lb)
        end
    end
    return nil
end

return table.freeze(TrafficCues)
