--!strict
-- Feux tricolores PURS et DÉTERMINISTES : l'état d'un feu dépend seulement du
-- carrefour, de son groupe d'approches et de l'heure du serveur. Le serveur
-- (trafic PNJ) et les clients (couleur des lampes) calculent donc le même état
-- sans aucun échange réseau.
--
-- Deux groupes par carrefour : les approches à peu près alignées (à 45° près,
-- dans un sens ou l'autre) partagent le même vert.

local Geometry = require(script.Parent.Geometry)

local Signals = {}

Signals.GreenS = 18
Signals.AmberS = 3
Signals.AllRedS = 1.5
Signals.CycleS = 2 * (Signals.GreenS + Signals.AmberS + Signals.AllRedS)

export type Approach = {
    EdgeId: string,
    -- Sens de parcours du tronçon pour ARRIVER au carrefour.
    Forward: boolean,
    -- Point d'arrêt (m) sur l'axe, avant la plateforme du carrefour.
    StopPoint: Geometry.Point,
    Direction: Geometry.Point, -- direction d'arrivée (unitaire)
    Right: Geometry.Point, -- droite du sens d'arrivée
    HalfWidth: number,
    Group: number,
}

export type State = "Green" | "Amber" | "Red"

-- Décalage de phase propre à chaque carrefour (hachage stable de l'identifiant).
function Signals.offset(nodeId: string): number
    local hash = 0
    for i = 1, #nodeId do
        hash = (hash * 31 + string.byte(nodeId, i)) % 1000003
    end
    return hash % math.floor(Signals.CycleS * 10) / 10
end

function Signals.state(nodeId: string, group: number, serverTime: number): State
    local t = (serverTime + Signals.offset(nodeId)) % Signals.CycleS
    local phase = Signals.GreenS + Signals.AmberS + Signals.AllRedS
    -- Groupe 1 : début du cycle ; groupe 2 : seconde moitié.
    local local_ = if group == 1 then t else (t - phase) % Signals.CycleS
    if local_ < Signals.GreenS then
        return "Green"
    elseif local_ < Signals.GreenS + Signals.AmberS then
        return "Amber"
    end
    return "Red"
end

--[[
    Approches d'un carrefour : un tronçon incident = une approche. `layout` est
    une mise en page World/WorldLayout (type laissé ouvert pour rester pur).
]]
function Signals.approaches(layout: any, nodeId: string): { Approach }
    local node = layout.Network.NodeById[nodeId]
    local incident = {}
    local radius = 0
    for _, edge in layout.Edges do
        if edge.From == nodeId or edge.To == nodeId then
            table.insert(incident, edge)
            radius = math.max(radius, edge.WidthM / 2)
        end
    end
    local result: { Approach } = {}
    for _, edge in incident do
        local polyline = edge.Polyline
        -- Le tronçon arrive au carrefour par sa fin (To) ou par son début (From).
        local arriving = edge.To == nodeId
        local near = if arriving then polyline[#polyline - 1] else polyline[2]
        local dx, dz = node.X - near.X, node.Z - near.Z
        local length = math.sqrt(dx * dx + dz * dz)
        if length < 1e-6 then
            continue
        end
        local direction = { X = dx / length, Z = dz / length }
        local stopDistance = radius + 2
        table.insert(result, {
            EdgeId = edge.Id,
            Forward = arriving,
            StopPoint = { X = node.X - direction.X * stopDistance, Z = node.Z - direction.Z * stopDistance },
            Direction = direction,
            Right = { X = -direction.Z, Z = direction.X },
            HalfWidth = edge.WidthM / 2,
            Group = 1,
        })
    end
    -- Groupes : alignées avec la première approche (à 45° près) → groupe 1.
    if #result > 0 then
        local reference = result[1].Direction
        for _, approach in result do
            local cosine = math.abs(approach.Direction.X * reference.X + approach.Direction.Z * reference.Z)
            approach.Group = if cosine >= math.cos(math.rad(45)) then 1 else 2
        end
    end
    return result
end

return table.freeze(Signals)
