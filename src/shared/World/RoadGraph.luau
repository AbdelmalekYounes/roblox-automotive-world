--!strict
-- Graphe routier PUR exploitable par le futur GPS, les missions et les PNJ :
-- voisinage orienté, plus court chemin (A*) en distance ou en temps, carrefour
-- le plus proche, voies de circulation (circulation à droite).

local Geometry = require(script.Parent.Geometry)
local WorldConfig = require(script.Parent.WorldConfig)
local WorldLayout = require(script.Parent.WorldLayout)

local RoadGraph = {}

export type Link = {
    Edge: WorldLayout.EdgeLayout,
    To: string,
    Forward: boolean, -- vrai si parcouru dans le sens From → To du tronçon
}

export type Graph = {
    Layout: WorldLayout.Layout,
    Adjacency: { [string]: { Link } },
}

export type Route = {
    Nodes: { string },
    Links: { Link },
    LengthM: number,
    TimeS: number,
}

local cached: Graph? = nil

function RoadGraph.get(): Graph
    if cached then
        return cached
    end
    local layout = WorldLayout.get()
    local adjacency: { [string]: { Link } } = {}
    for _, node in layout.Network.Nodes do
        adjacency[node.Id] = {}
    end
    for _, edge in layout.Edges do
        table.insert(adjacency[edge.From], { Edge = edge, To = edge.To, Forward = true })
        table.insert(adjacency[edge.To], { Edge = edge, To = edge.From, Forward = false })
    end
    local graph: Graph = { Layout = layout, Adjacency = adjacency }
    cached = graph
    return graph
end

local function speedMs(edge: WorldLayout.EdgeLayout): number
    return WorldConfig.RoadClasses[edge.Class].SpeedKmh / 3.6
end

--[[
    Plus court chemin (A*) entre deux carrefours. `mode` = "Distance" ou
    "Time" (vitesse réglementaire de chaque classe). `allow(edge)` peut exclure
    des tronçons (ex. pistes et chemins pour le trafic).
]]
function RoadGraph.route(
    graph: Graph,
    from: string,
    to: string,
    mode: ("Distance" | "Time")?,
    allow: ((WorldLayout.EdgeLayout) -> boolean)?
): Route?
    local nodes = graph.Layout.Network.NodeById
    local goal = nodes[to]
    if nodes[from] == nil or goal == nil then
        return nil
    end
    local byTime = mode == "Time"
    local maxSpeed = 130 / 3.6
    local function heuristic(id: string): number
        local n = nodes[id]
        local d = math.sqrt((n.X - goal.X) ^ 2 + (n.Z - goal.Z) ^ 2)
        return if byTime then d / maxSpeed else d
    end
    local open: { string } = { from }
    local inOpen: { [string]: boolean } = { [from] = true }
    local cost: { [string]: number } = { [from] = 0 }
    local score: { [string]: number } = { [from] = heuristic(from) }
    local came: { [string]: Link } = {}
    local cameFrom: { [string]: string } = {}
    while #open > 0 do
        -- File de priorité simple (graphe de quelques milliers de nœuds).
        local bestIndex, best = 1, open[1]
        for i = 2, #open do
            if score[open[i]] < score[best] then
                bestIndex, best = i, open[i]
            end
        end
        if best == to then
            local route: Route = { Nodes = { to }, Links = {}, LengthM = 0, TimeS = 0 }
            local current = to
            while current ~= from do
                local link = came[current]
                table.insert(route.Links, 1, link)
                current = cameFrom[current]
                table.insert(route.Nodes, 1, current)
                route.LengthM += link.Edge.LengthM
                route.TimeS += link.Edge.LengthM / speedMs(link.Edge)
            end
            return route
        end
        table.remove(open, bestIndex)
        inOpen[best] = nil
        for _, link in graph.Adjacency[best] do
            if allow and not allow(link.Edge) then
                continue
            end
            local step = if byTime then link.Edge.LengthM / speedMs(link.Edge) else link.Edge.LengthM
            local candidate = cost[best] + step
            if cost[link.To] == nil or candidate < cost[link.To] then
                cost[link.To] = candidate
                score[link.To] = candidate + heuristic(link.To)
                came[link.To] = link
                cameFrom[link.To] = best
                if not inOpen[link.To] then
                    inOpen[link.To] = true
                    table.insert(open, link.To)
                end
            end
        end
    end
    return nil
end

-- Carrefour le plus proche d'une position (m), éventuellement filtré.
function RoadGraph.nearestNode(graph: Graph, x: number, z: number, accept: ((string) -> boolean)?): string?
    local best, bestDistance = nil, math.huge
    for _, node in graph.Layout.Network.Nodes do
        if accept == nil or accept(node.Id) then
            local d = (node.X - x) ^ 2 + (node.Z - z) ^ 2
            if d < bestDistance then
                best, bestDistance = node.Id, d
            end
        end
    end
    return best
end

--[[
    Décalage latéral (m) du centre de la voie `lane` vers la DROITE du sens de
    marche (circulation à droite) : voie 1 = la plus proche de l'axe (voie
    rapide), voie N = la plus à droite.
]]
function RoadGraph.laneOffset(edge: WorldLayout.EdgeLayout, lane: number): number
    local roadClass = WorldConfig.RoadClasses[edge.Class]
    return roadClass.MedianM / 2 + (lane - 0.5) * roadClass.LaneWidthM
end

function RoadGraph.laneCount(edge: WorldLayout.EdgeLayout): number
    return WorldConfig.RoadClasses[edge.Class].LanesPerDirection
end

-- Polyligne d'une voie dans le sens demandé (décalée vers la droite).
function RoadGraph.lanePolyline(edge: WorldLayout.EdgeLayout, forward: boolean, lane: number): { Geometry.Point3 }
    local source = edge.Polyline
    local count = #source
    local ordered: { Geometry.Point3 } = {}
    for i = 1, count do
        ordered[i] = source[if forward then i else count - i + 1]
    end
    local offset = RoadGraph.laneOffset(edge, lane)
    local points: { Geometry.Point3 } = {}
    for i = 1, count do
        local a, b = ordered[math.max(i - 1, 1)], ordered[math.min(i + 1, count)]
        local dx, dz = b.X - a.X, b.Z - a.Z
        local length = math.sqrt(dx * dx + dz * dz)
        if length < 1e-6 then
            dx, dz, length = 0, -1, 1
        end
        local p = ordered[i]
        -- Droite du sens de marche : (-dz, dx).
        table.insert(points, { X = p.X - dz / length * offset, Z = p.Z + dx / length * offset, Y = p.Y })
    end
    return points
end

-- Longueur totale (m) et temps (s) d'une suite de tronçons dessinés à vitesse donnée.
function RoadGraph.tripMinutes(lengthM: number, speedKmh: number): number
    return lengthM / (speedKmh / 3.6) / 60
end

return table.freeze(RoadGraph)
