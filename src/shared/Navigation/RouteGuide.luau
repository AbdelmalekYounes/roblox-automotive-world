--!strict
--[[
    GPS : itinéraire routier et guidage virage par virage (lot 0.7), PUR.

    Réutilise le graphe routier du lot 0.3 (RoadGraph, A* en temps sur les
    vitesses réglementaires des classes) avec des PROFILS de véhicule :
    - Road : routes ouvertes aux voitures (ni chemins, ni pistes) ;
    - AllTerrain : routes et chemins (exploration, rallye) ;
    - Track : tout, pistes comprises (complexe motorsport).
    Départ : tronçon le plus proche de la position, les deux extrémités sont
    essayées (pas de demi-tour inutile) ; arrivée : carrefour accessible le
    plus proche de la destination, puis dernier tronçon direct.

    Guidage : manœuvres aux carrefours où il existe un choix ou un virage
    marqué (gauche, droite, serrer, tout droit, demi-tour) avec le nom de la
    route suivante ; suivi de la progression (distance restante, durée
    estimée, prochaine manœuvre), détection de sortie d'itinéraire et
    politique de recalcul limitée (pas de recalcul à chaque image).
]]

local World = script.Parent.Parent.World
local RoadGraph = require(World.RoadGraph)
local WorldConfig = require(World.WorldConfig)
local MapIndex = require(script.Parent.MapIndex)

local RouteGuide = {}

RouteGuide.OffRouteM = 35
RouteGuide.OffRouteHoldS = 3
RouteGuide.MinRecalcS = 5
RouteGuide.ArriveM = 25
RouteGuide.StartSearchM = 400
RouteGuide.MaxDestinationOffM = 600

export type Profile = "Road" | "AllTerrain" | "Track"

local EXCLUDED: { [Profile]: { [string]: boolean } } = {
    Road = { Chemin = true, Piste = true },
    AllTerrain = { Piste = true },
    Track = {},
}

function RouteGuide.allowsClass(profile: Profile, class: string): boolean
    return not EXCLUDED[profile][class]
end

export type Maneuver = {
    Kind: "Left" | "Right" | "SlightLeft" | "SlightRight" | "Straight" | "UTurn" | "Arrive",
    Along: number, -- distance depuis le départ (m)
    X: number,
    Z: number,
    Road: string?,
}

export type Plan = {
    Points: { { X: number, Z: number } },
    Along: { number },
    Time: { number }, -- temps cumulé (s) à chaque point
    LengthM: number,
    TimeS: number,
    Maneuvers: { Maneuver },
    Destination: { X: number, Z: number },
    Profile: Profile,
}

local function heading(dx: number, dz: number): number
    return math.atan2(dx, -dz)
end

local function turnDeg(h1: number, h2: number): number
    return math.deg(((h2 - h1 + math.pi) % (2 * math.pi)) - math.pi)
end

function RouteGuide.classify(angle: number): "Left" | "Right" | "SlightLeft" | "SlightRight" | "Straight" | "UTurn"
    local a = math.abs(angle)
    if a < 20 then
        return "Straight"
    elseif a > 150 then
        return "UTurn"
    elseif a < 45 then
        return if angle > 0 then "SlightRight" else "SlightLeft"
    end
    return if angle > 0 then "Right" else "Left"
end

local function valid(x: any, z: any): boolean
    return type(x) == "number"
        and type(z) == "number"
        and x == x
        and z == z
        and math.abs(x) <= WorldConfig.HalfExtentM * 1.2
        and math.abs(z) <= WorldConfig.HalfExtentM * 1.2
end

local function linkPoints(link: any): { any }
    local polyline = link.Edge.Polyline
    local out = {}
    local count = #polyline
    for i = 1, count do
        out[i] = polyline[if link.Forward then i else count - i + 1]
    end
    return out
end

local function speedOf(class: string): number
    return WorldConfig.RoadClasses[class].SpeedKmh / 3.6
end

--[[
    Calcule un itinéraire. Renvoie (plan) ou (nil, "Invalid" | "NoRoute").
]]
function RouteGuide.plan(
    graph: any,
    index: MapIndex.Index,
    fromX: number,
    fromZ: number,
    toX: number,
    toZ: number,
    profile: Profile
): (Plan?, string?)
    if not valid(fromX, fromZ) or not valid(toX, toZ) then
        return nil, "Invalid"
    end
    local layout = graph.Layout
    local function allowEdge(edge: any): boolean
        return RouteGuide.allowsClass(profile, edge.Class)
    end
    local function nodeAllowed(id: string): boolean
        for _, link in graph.Adjacency[id] or {} do
            if allowEdge(link.Edge) then
                return true
            end
        end
        return false
    end
    local goal = RoadGraph.nearestNode(graph, toX, toZ, nodeAllowed)
    if goal == nil then
        return nil, "NoRoute"
    end
    local goalNode = layout.Network.NodeById[goal]
    if math.sqrt((goalNode.X - toX) ^ 2 + (goalNode.Z - toZ) ^ 2) > RouteGuide.MaxDestinationOffM then
        return nil, "Invalid"
    end
    -- Départ : extrémités du tronçon le plus proche (accepté par le profil).
    local edgeId, _, projected = MapIndex.nearestEdge(index, fromX, fromZ, RouteGuide.StartSearchM, function(class)
        return RouteGuide.allowsClass(profile, class)
    end)
    local candidates: { { Node: string, Lead: number } } = {}
    if edgeId and projected then
        local edge = index.Edges[edgeId]
        for _, id in { edge.From, edge.To } do
            local node = layout.Network.NodeById[id]
            table.insert(candidates, {
                Node = id,
                Lead = math.sqrt((node.X - projected.X) ^ 2 + (node.Z - projected.Z) ^ 2),
            })
        end
    else
        local nearest = RoadGraph.nearestNode(graph, fromX, fromZ, nodeAllowed)
        if nearest then
            local node = layout.Network.NodeById[nearest]
            table.insert(candidates, { Node = nearest, Lead = math.sqrt((node.X - fromX) ^ 2 + (node.Z - fromZ) ^ 2) })
        end
    end
    local best: any = nil
    local bestCost = math.huge
    for _, candidate in candidates do
        local route = if candidate.Node == goal
            then { Nodes = { goal }, Links = {}, LengthM = 0, TimeS = 0 }
            else RoadGraph.route(graph, candidate.Node, goal, "Time", allowEdge)
        if route then
            local cost = route.TimeS + candidate.Lead / 10
            if cost < bestCost then
                best, bestCost = { Route = route, Start = candidate.Node }, cost
            end
        end
    end
    if best == nil then
        return nil, "NoRoute"
    end
    -- Polyligne : position → premier carrefour → tronçons → destination.
    local points: { { X: number, Z: number } } = { { X = fromX, Z = fromZ } }
    local speeds: { number } = { 0 }
    local function push(x: number, z: number, speed: number)
        local last = points[#points]
        if math.abs(last.X - x) > 0.5 or math.abs(last.Z - z) > 0.5 then
            table.insert(points, { X = x, Z = z })
            table.insert(speeds, speed)
        end
    end
    local startNode = layout.Network.NodeById[best.Start]
    push(startNode.X, startNode.Z, 10)
    local turns: { { Index: number, Link: any } } = {}
    for i, link in best.Route.Links do
        local speed = speedOf(link.Edge.Class)
        if i > 1 then
            table.insert(turns, { Index = #points, Link = link })
        end
        for _, p in linkPoints(link) do
            push(p.X, p.Z, speed)
        end
    end
    push(toX, toZ, 8)
    local along, time = { 0 }, { 0 }
    for i = 2, #points do
        local d = math.sqrt((points[i].X - points[i - 1].X) ^ 2 + (points[i].Z - points[i - 1].Z) ^ 2)
        along[i] = along[i - 1] + d
        time[i] = time[i - 1] + d / math.max(speeds[i], 1)
    end
    -- Manœuvres aux carrefours avec choix ou virage marqué.
    local maneuvers: { Maneuver } = {}
    for _, turn in turns do
        local i = turn.Index
        if i <= 1 or i >= #points then
            continue
        end
        local a, b, c = points[i - 1], points[i], points[i + 1]
        local angle = turnDeg(heading(b.X - a.X, b.Z - a.Z), heading(c.X - b.X, c.Z - b.Z))
        -- Carrefour de la manœuvre : origine du tronçon suivant.
        local nodeId = if turn.Link.Forward then turn.Link.Edge.From else turn.Link.Edge.To
        local degree = #(graph.Adjacency[nodeId] or {})
        local kind = RouteGuide.classify(angle)
        if kind ~= "Straight" or degree > 2 then
            table.insert(
                maneuvers,
                { Kind = kind :: any, Along = along[i], X = b.X, Z = b.Z, Road = turn.Link.Edge.Name }
            )
        end
    end
    -- Les « tout droit » consécutifs sans changement de route ne sont pas annoncés.
    local filtered: { Maneuver } = {}
    for position, maneuver in maneuvers do
        local previous = filtered[#filtered]
        if maneuver.Kind == "Straight" and previous and previous.Road == maneuver.Road and position > 1 then
            continue
        end
        table.insert(filtered, maneuver)
    end
    table.insert(filtered, { Kind = "Arrive", Along = along[#along], X = toX, Z = toZ, Road = nil })
    return {
        Points = points,
        Along = along,
        Time = time,
        LengthM = along[#along],
        TimeS = time[#time],
        Maneuvers = filtered,
        Destination = { X = toX, Z = toZ },
        Profile = profile,
    },
        nil
end

-- Guidage direct (zone d'essai sans graphe routier) : une ligne droite.
function RouteGuide.direct(fromX: number, fromZ: number, toX: number, toZ: number): (Plan?, string?)
    if not valid(fromX, fromZ) or not valid(toX, toZ) then
        return nil, "Invalid"
    end
    local d = math.sqrt((toX - fromX) ^ 2 + (toZ - fromZ) ^ 2)
    return {
        Points = { { X = fromX, Z = fromZ }, { X = toX, Z = toZ } },
        Along = { 0, d },
        Time = { 0, d / 10 },
        LengthM = d,
        TimeS = d / 10,
        Maneuvers = { { Kind = "Arrive", Along = d, X = toX, Z = toZ, Road = nil } },
        Destination = { X = toX, Z = toZ },
        Profile = "Road",
    },
        nil
end

export type Progress = {
    AlongM: number,
    RemainingM: number,
    RemainingS: number,
    OffRouteM: number,
    Next: Maneuver?,
    ToNextM: number,
    Arrived: boolean,
    Hint: number,
}

-- Position projetée sur l'itinéraire (recherche locale autour de `hint`).
function RouteGuide.track(plan: Plan, x: number, z: number, hint: number?): Progress
    local points = plan.Points
    local bestD, bestAlong, bestIndex, bestT = math.huge, 0, 2, 0
    local center = hint or 2
    local function scan(from: number, to: number)
        for i = math.max(2, from), math.min(#points, to) do
            local a, b = points[i - 1], points[i]
            local abx, abz = b.X - a.X, b.Z - a.Z
            local len2 = abx * abx + abz * abz
            local t = if len2 > 0 then math.clamp(((x - a.X) * abx + (z - a.Z) * abz) / len2, 0, 1) else 0
            local d = math.sqrt((x - (a.X + abx * t)) ^ 2 + (z - (a.Z + abz * t)) ^ 2)
            if d < bestD then
                bestD, bestIndex, bestT = d, i, t
                bestAlong = plan.Along[i - 1] + (plan.Along[i] - plan.Along[i - 1]) * t
            end
        end
    end
    scan(center - 40, center + 80)
    if bestD > RouteGuide.OffRouteM then
        scan(2, #points)
    end
    local timeAt = plan.Time[bestIndex - 1] + (plan.Time[bestIndex] - plan.Time[bestIndex - 1]) * bestT
    local nextManeuver: Maneuver? = nil
    for _, maneuver in plan.Maneuvers do
        if maneuver.Along > bestAlong + 2 then
            nextManeuver = maneuver
            break
        end
    end
    local remaining = math.max(plan.LengthM - bestAlong, 0)
    local toDestination = math.sqrt((plan.Destination.X - x) ^ 2 + (plan.Destination.Z - z) ^ 2)
    return {
        AlongM = bestAlong,
        RemainingM = remaining,
        RemainingS = math.max(plan.TimeS - timeAt, 0),
        OffRouteM = bestD,
        Next = nextManeuver,
        ToNextM = if nextManeuver then nextManeuver.Along - bestAlong else 0,
        Arrived = toDestination <= RouteGuide.ArriveM,
        Hint = bestIndex,
    }
end

export type RecalcState = { OffSince: number?, LastRecalc: number }

function RouteGuide.newRecalcState(now: number): RecalcState
    return { OffSince = nil, LastRecalc = now }
end

-- Faut-il recalculer ? (hors itinéraire assez longtemps, et pas trop souvent).
function RouteGuide.shouldRecalc(state: RecalcState, progress: Progress, now: number): boolean
    if progress.OffRouteM <= RouteGuide.OffRouteM then
        state.OffSince = nil
        return false
    end
    state.OffSince = state.OffSince or now
    if
        now - (state.OffSince :: number) >= RouteGuide.OffRouteHoldS
        and now - state.LastRecalc >= RouteGuide.MinRecalcS
    then
        state.LastRecalc = now
        state.OffSince = nil
        return true
    end
    return false
end

return table.freeze(RouteGuide)
