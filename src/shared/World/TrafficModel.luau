--!strict
--[[
    Trafic PNJ PUR (cahier des charges §2.4) : simulation des véhicules
    non joueurs le long du graphe routier, sans aucune instance Roblox. Le
    serveur (TrafficService) en est le seul exécutant ; il ne fait que
    matérialiser, près des joueurs, les agents calculés ici.

    - Circulation à droite : chaque agent suit une voie (RoadGraph.lanePolyline)
      de son tronçon ; au bout, il choisit au hasard (tirage fourni) un tronçon
      suivant ouvert au trafic, sans demi-tour sauf impasse.
    - Accélérations et freinages progressifs : modèle IDM (Intelligent Driver
      Model, Treiber 2000) vers la vitesse réglementaire de la classe de route.
    - Distance de sécurité : l'IDM suit le meneur de la même voie (y compris sur
      le tronçon suivant) et tout obstacle fourni (véhicules des joueurs).
    - Carrefours : feux déterministes (World/Signals) ; ailleurs, réservation du
      carrefour (un seul flux à la fois, les approches de rang inférieur cèdent
      le passage aux approches de rang supérieur proches).
    - Pas de changement de voie ni de dépassement dans ce lot (limite connue).

    Unités : mètres, secondes, m/s ; positions horizontales X/Z, altitude Y.
]]

local Geometry = require(script.Parent.Geometry)
local WorldConfig = require(script.Parent.WorldConfig)
local RoadGraph = require(script.Parent.RoadGraph)
local Signals = require(script.Parent.Signals)

local TrafficModel = {}

-- Paramètres IDM : accélération confortable, freinage confortable, temps
-- inter-véhicules, distance minimale à l'arrêt, exposant.
TrafficModel.Idm = table.freeze({
    A = 1.6, -- m/s²
    B = 2.8, -- m/s²
    T = 1.4, -- s
    S0 = 2.5, -- m
    Delta = 4,
    MaxBrake = 8, -- m/s², freinage d'urgence plafonné
})

TrafficModel.VehicleLengthM = 4.6
TrafficModel.VehicleWidthM = 1.9
-- Rayon de décision avant la ligne d'arrêt d'un carrefour sans feux (m).
TrafficModel.YieldLookaheadM = 35
-- Durée maximale d'une réservation de carrefour (s) : évite tout blocage.
TrafficModel.ReservationTimeoutS = 8

export type Path = {
    Points: { Geometry.Point3 },
    Cum: { number }, -- abscisse curviligne de chaque point (m)
    Length: number,
}

export type Agent = {
    Id: number,
    EdgeId: string,
    Forward: boolean,
    Lane: number,
    Path: Path,
    S: number, -- abscisse sur Path (m)
    Speed: number, -- m/s
    Desired: number, -- vitesse désirée (m/s) sur le tronçon courant
    Factor: number, -- tempérament du conducteur (× vitesse réglementaire)
    EndNode: string, -- carrefour au bout du tronçon
    Next: RoadGraph.Link?, -- tronçon suivant déjà choisi
    StopS: number, -- abscisse de la ligne d'arrêt (m)
    HasReservation: boolean,
    Holding: number, -- temps restant d'arrêt imposé (incident), s
    Rank: number,
}

export type Obstacle = {
    X: number,
    Z: number,
    Speed: number, -- vitesse le long de la direction de l'agent (approximative)
    Radius: number, -- demi-longueur (m)
}

export type Reservation = { Agent: number, Approach: string, Until: number }

export type World = {
    Graph: RoadGraph.Graph,
    Agents: { Agent },
    NextId: number,
    Reservations: { [string]: Reservation },
    -- Groupe de feux de chaque approche : clé "<nœud>|<tronçon>|<sens>".
    SignalGroups: { [string]: number },
    StopDistance: { [string]: number },
    Degree: { [string]: number },
    Lanes: { [string]: Path },
}

local function trafficEdge(edge: any): boolean
    return WorldConfig.RoadClasses[edge.Class].Traffic
end
TrafficModel.trafficEdge = trafficEdge

-- Chemin (abscisses cumulées) d'une suite de points.
function TrafficModel.path(points: { Geometry.Point3 }): Path
    local cum = { 0 }
    for i = 2, #points do
        cum[i] = cum[i - 1] + Geometry.distance(points[i - 1], points[i])
    end
    return { Points = points, Cum = cum, Length = cum[#cum] }
end

-- Position (Point3) et direction horizontale unitaire à l'abscisse `s`.
function TrafficModel.sample(path: Path, s: number): (Geometry.Point3, Geometry.Point)
    local points, cum = path.Points, path.Cum
    local target = math.clamp(s, 0, path.Length)
    -- Recherche dichotomique du segment.
    local lo, hi = 1, #points
    while hi - lo > 1 do
        local mid = (lo + hi) // 2
        if cum[mid] <= target then
            lo = mid
        else
            hi = mid
        end
    end
    local a, b = points[lo], points[hi]
    local d = cum[hi] - cum[lo]
    local f = if d > 0 then (target - cum[lo]) / d else 0
    local dx, dz = b.X - a.X, b.Z - a.Z
    local length = math.sqrt(dx * dx + dz * dz)
    local direction = if length > 1e-6 then { X = dx / length, Z = dz / length } else { X = 0, Z = -1 }
    return { X = a.X + dx * f, Z = a.Z + dz * f, Y = a.Y + (b.Y - a.Y) * f }, direction
end

--[[
    Accélération IDM (m/s²). `gap` = distance libre au meneur (m, math.huge si
    aucun), `closing` = vitesse de rapprochement (m/s, positive si l'on se
    rapproche).
]]
function TrafficModel.idm(speed: number, desired: number, gap: number, closing: number): number
    local p = TrafficModel.Idm
    local free = 1 - (speed / math.max(desired, 0.1)) ^ p.Delta
    local interaction = 0
    if gap < math.huge then
        local wanted = p.S0 + math.max(0, speed * p.T + speed * closing / (2 * math.sqrt(p.A * p.B)))
        interaction = (wanted / math.max(gap, 0.1)) ^ 2
    end
    return math.max(p.A * (free - interaction), -p.MaxBrake)
end

local function approachKey(nodeId: string, edgeId: string, forward: boolean): string
    return nodeId .. "|" .. edgeId .. "|" .. (if forward then "1" else "0")
end

local function laneKey(edgeId: string, forward: boolean, lane: number): string
    return edgeId .. "|" .. (if forward then "1" else "0") .. "|" .. lane
end

function TrafficModel.newWorld(graph: RoadGraph.Graph): World
    local layout = graph.Layout
    local degree: { [string]: number } = {}
    for _, edge in layout.Edges do
        if trafficEdge(edge) then
            degree[edge.From] = (degree[edge.From] or 0) + 1
            degree[edge.To] = (degree[edge.To] or 0) + 1
        end
    end
    local groups: { [string]: number } = {}
    local stops: { [string]: number } = {}
    for _, node in layout.Network.Nodes do
        if (degree[node.Id] or 0) >= 3 then
            for _, approach in Signals.approaches(layout, node.Id) do
                local key = approachKey(node.Id, approach.EdgeId, approach.Forward)
                groups[key] = approach.Group
                stops[node.Id] = Geometry.distance(approach.StopPoint, node)
            end
        end
    end
    return {
        Graph = graph,
        Agents = {},
        NextId = 1,
        Reservations = {},
        SignalGroups = groups,
        StopDistance = stops,
        Degree = degree,
        Lanes = {},
    }
end

local function lanePath(world: World, edge: any, forward: boolean, lane: number): Path
    local key = laneKey(edge.Id, forward, lane)
    local cached = world.Lanes[key]
    if cached then
        return cached
    end
    local path = TrafficModel.path(RoadGraph.lanePolyline(edge, forward, lane))
    world.Lanes[key] = path
    return path
end

-- Choix du tronçon suivant au carrefour `nodeId` (tirage `roll` dans [0 ; 1[).
function TrafficModel.chooseNext(world: World, nodeId: string, fromEdge: string, roll: number): RoadGraph.Link?
    local options: { RoadGraph.Link } = {}
    local uturn: RoadGraph.Link? = nil
    local links: { RoadGraph.Link } = world.Graph.Adjacency[nodeId] or {}
    for _, link in links do
        if trafficEdge(link.Edge) then
            if link.Edge.Id == fromEdge then
                uturn = link
            else
                table.insert(options, link)
            end
        end
    end
    if #options == 0 then
        return uturn
    end
    return options[math.clamp(math.floor(roll * #options) + 1, 1, #options)]
end

local function enterEdge(world: World, agent: Agent, link: RoadGraph.Link, lane: number, carry: number, previous: Path?)
    local edge = link.Edge
    local lanes = RoadGraph.laneCount(edge)
    local chosen = math.clamp(lane, 1, lanes)
    local base = lanePath(world, edge, link.Forward, chosen)
    local path = base
    if previous then
        -- Raccord droit entre la fin de la voie précédente et le début de la
        -- nouvelle (évite tout saut de position au carrefour).
        local last = previous.Points[#previous.Points]
        local points = { last }
        for _, p in base.Points do
            table.insert(points, p)
        end
        path = TrafficModel.path(points)
    end
    local class = WorldConfig.RoadClasses[edge.Class]
    agent.EdgeId = edge.Id
    agent.Forward = link.Forward
    agent.Lane = chosen
    agent.Path = path
    agent.S = carry
    agent.EndNode = link.To
    agent.Next = nil
    agent.HasReservation = false
    agent.Rank = class.Rank
    agent.Desired = class.SpeedKmh / 3.6 * agent.Factor
    local stop = world.StopDistance[link.To]
    agent.StopS = if stop then math.max(path.Length - stop, path.Length * 0.5) else path.Length
end

--[[
    Ajoute un agent sur le tronçon `link` (voie `lane`), à la fraction
    `fraction` de sa longueur. `factor` module la vitesse désirée (0,85 à 1,05 :
    tous les conducteurs ne roulent pas pareil).
]]
function TrafficModel.spawn(world: World, link: RoadGraph.Link, lane: number, fraction: number, factor: number): Agent
    local agent: Agent = {
        Id = world.NextId,
        EdgeId = link.Edge.Id,
        Forward = link.Forward,
        Lane = lane,
        Path = TrafficModel.path({ { X = 0, Z = 0, Y = 0 }, { X = 0, Z = 1, Y = 0 } }),
        S = 0,
        Speed = 0,
        Desired = 1,
        Factor = factor,
        EndNode = link.To,
        Next = nil,
        StopS = 0,
        HasReservation = false,
        Holding = 0,
        Rank = 0,
    }
    world.NextId += 1
    enterEdge(world, agent, link, lane, 0, nil)
    agent.S = math.clamp(fraction, 0, 1) * agent.Path.Length
    agent.Speed = agent.Desired * 0.6
    table.insert(world.Agents, agent)
    return agent
end

export type SpawnChoice = { Link: RoadGraph.Link, Weight: number }

--[[
    Sens de circulation ouverts au trafic, pondérés par longueur × nombre de
    voies × densité de trafic de la zone (WorldConfig.ZoneDensity) : les PNJ
    se répartissent selon la carte, pas uniformément.
]]
function TrafficModel.spawnChoices(world: World): ({ SpawnChoice }, number)
    local choices: { SpawnChoice } = {}
    local total = 0
    for _, links in world.Graph.Adjacency do
        for _, link in links do
            local edge = link.Edge
            local density = (WorldConfig.ZoneDensity :: any)[edge.Zone]
            if trafficEdge(edge) and density and density.Traffic > 0 then
                local weight = edge.LengthM * RoadGraph.laneCount(edge) * density.Traffic
                table.insert(choices, { Link = link, Weight = weight })
                total += weight
            end
        end
    end
    -- Ordre stable (l'itération d'un dictionnaire ne l'est pas).
    table.sort(choices, function(a, b)
        if a.Link.Edge.Id ~= b.Link.Edge.Id then
            return a.Link.Edge.Id < b.Link.Edge.Id
        end
        return a.Link.Forward and not b.Link.Forward
    end)
    return choices, total
end

-- Tirage d'un sens de circulation selon les poids (roll dans [0 ; 1[).
function TrafficModel.pick(choices: { SpawnChoice }, total: number, roll: number): RoadGraph.Link
    local target = roll * total
    for _, choice in choices do
        target -= choice.Weight
        if target < 0 then
            return choice.Link
        end
    end
    return choices[#choices].Link
end

function TrafficModel.remove(world: World, agent: Agent)
    for key, reservation in world.Reservations do
        if reservation.Agent == agent.Id then
            world.Reservations[key] = nil
        end
    end
    local index = table.find(world.Agents, agent)
    if index then
        table.remove(world.Agents, index)
    end
end

function TrafficModel.position(agent: Agent): (Geometry.Point3, Geometry.Point)
    return TrafficModel.sample(agent.Path, agent.S)
end

-- Le carrefour au bout du tronçon impose-t-il un arrêt maintenant ?
local function mustStop(world: World, agent: Agent, serverTime: number, distanceToStop: number): boolean
    local node = agent.EndNode
    if (world.Degree[node] or 0) < 3 then
        return false
    end
    local data = world.Graph.Layout.Network.NodeById[node]
    local key = approachKey(node, agent.EdgeId, agent.Forward)
    if data.Control == "Signals" then
        local group = world.SignalGroups[key] or 1
        local state = Signals.state(node, group, serverTime)
        if state == "Red" then
            return true
        elseif state == "Amber" then
            -- À l'orange, on s'arrête seulement si c'est confortablement possible.
            return agent.Speed * agent.Speed / (2 * TrafficModel.Idm.B) < distanceToStop
        end
        return false
    end
    if agent.HasReservation then
        return false
    end
    local reservation = world.Reservations[node]
    if reservation and reservation.Until > serverTime and reservation.Approach ~= key then
        return true
    end
    -- Cédez-le-passage : une approche prioritaire occupée et proche bloque.
    for _, other in world.Agents do
        if
            other ~= agent
            and other.EndNode == node
            and other.Rank > agent.Rank
            and other.StopS - other.S < TrafficModel.YieldLookaheadM
            and other.Speed > 1
        then
            return true
        end
    end
    world.Reservations[node] =
        { Agent = agent.Id, Approach = key, Until = serverTime + TrafficModel.ReservationTimeoutS }
    agent.HasReservation = true
    return false
end

--[[
    Un pas de simulation. `obstacles` : véhicules des joueurs (positions en m).
    `roll()` : tirage uniforme [0 ; 1[ fourni par l'appelant (déterminisme des
    tests, Random du serveur en jeu).
]]
function TrafficModel.step(world: World, dt: number, serverTime: number, obstacles: { Obstacle }, roll: () -> number)
    -- Agents par voie, triés par abscisse : meneur = suivant dans la liste.
    local byLane: { [string]: { Agent } } = {}
    for _, agent in world.Agents do
        local key = laneKey(agent.EdgeId, agent.Forward, agent.Lane)
        local list = byLane[key]
        if list == nil then
            list = {}
            byLane[key] = list
        end
        table.insert(list, agent)
    end
    for _, list in byLane do
        table.sort(list, function(a, b)
            return a.S < b.S
        end)
    end

    local length = TrafficModel.VehicleLengthM
    -- Agents entrés sur une voie pendant ce pas (abscisse la plus basse).
    local enteredTail: { [string]: number } = {}
    for _, agent in world.Agents do
        if agent.Next == nil then
            agent.Next = TrafficModel.chooseNext(world, agent.EndNode, agent.EdgeId, roll())
        end
        local gap, closing = math.huge, 0

        -- Meneur sur la même voie, sinon premier agent de la voie suivante.
        local list = byLane[laneKey(agent.EdgeId, agent.Forward, agent.Lane)]
        local index = table.find(list, agent) :: number
        local leader = list[index + 1]
        if leader then
            gap = leader.S - agent.S - length
            closing = agent.Speed - leader.Speed
        elseif agent.Next then
            local nextLink = agent.Next :: RoadGraph.Link
            local lanes = RoadGraph.laneCount(nextLink.Edge)
            local nextList = byLane[laneKey(nextLink.Edge.Id, nextLink.Forward, math.clamp(agent.Lane, 1, lanes))]
            if nextList and nextList[1] then
                gap = agent.Path.Length - agent.S + nextList[1].S - length
                closing = agent.Speed - nextList[1].Speed
            end
        end

        -- Ligne d'arrêt (feu rouge, carrefour réservé, cédez-le-passage).
        local toStop = agent.StopS - agent.S
        if toStop > -1 and toStop < 80 and mustStop(world, agent, serverTime, toStop) then
            local stopGap = math.max(toStop - 1, 0)
            if stopGap < gap then
                gap, closing = stopGap, agent.Speed
            end
        end
        -- Impasse sans suite : arrêt en bout de tronçon.
        if agent.Next == nil then
            local endGap = math.max(agent.Path.Length - agent.S - 2, 0)
            if endGap < gap then
                gap, closing = endGap, agent.Speed
            end
        end

        -- Véhicules des joueurs devant l'agent, dans son couloir.
        local here, direction = TrafficModel.sample(agent.Path, agent.S)
        for _, obstacle in obstacles do
            local dx, dz = obstacle.X - here.X, obstacle.Z - here.Z
            local ahead = dx * direction.X + dz * direction.Z
            local side = math.abs(-dx * direction.Z + dz * direction.X)
            if ahead > 0 and ahead < 60 and side < TrafficModel.VehicleWidthM + 0.8 then
                local free = ahead - length / 2 - obstacle.Radius
                if free < gap then
                    gap, closing = math.max(free, 0), agent.Speed - obstacle.Speed
                end
            end
        end

        -- Anticipation d'une route plus lente : on ralentit AVANT d'y entrer, au
        -- freinage confortable (pas de dépassement de la vitesse réglementaire).
        local desired = agent.Desired
        if agent.Next then
            local nextLink = agent.Next :: RoadGraph.Link
            local nextDesired = WorldConfig.RoadClasses[nextLink.Edge.Class].SpeedKmh / 3.6 * agent.Factor
            if nextDesired < desired then
                -- Distance restante au pas suivant (le pas est discret).
                local remaining = math.max(agent.Path.Length - agent.S - agent.Speed * dt, 0)
                local allowed = math.sqrt(nextDesired * nextDesired + 2 * TrafficModel.Idm.B * remaining)
                desired = math.min(desired, math.max(allowed, nextDesired))
            end
        end
        local accel = TrafficModel.idm(agent.Speed, desired, gap, closing)
        -- Au-dessus de la vitesse voulue, le terme libre de l'IDM freine trop
        -- mollement : freinage confortable explicite, sans aller sous la cible.
        if agent.Speed > desired then
            accel = math.min(accel, math.max(-TrafficModel.Idm.B, (desired - agent.Speed) / dt))
        end
        if agent.Holding > 0 then
            agent.Holding = math.max(agent.Holding - dt, 0)
            accel = -TrafficModel.Idm.MaxBrake
        end
        agent.Speed = math.max(agent.Speed + accel * dt, 0)
        -- Jamais au-delà du meneur ou de la ligne d'arrêt (pas discret).
        agent.S += math.min(agent.Speed * dt, math.max(gap, 0))

        -- Passage au tronçon suivant (le reste du pas est reporté).
        if agent.S > agent.Path.Length then
            local carry = agent.S - agent.Path.Length
            local nextLink = agent.Next
            -- Entrée de la voie suivante occupée (autre agent venu d'une autre
            -- approche) : on attend au bout de la voie actuelle, sans chevaucher.
            local entryKey = ""
            local blocked = false
            if nextLink then
                local lanes = RoadGraph.laneCount(nextLink.Edge)
                entryKey = laneKey(nextLink.Edge.Id, nextLink.Forward, math.clamp(agent.Lane, 1, lanes))
                local occupants: { Agent } = byLane[entryKey] or {}
                for _, other in occupants do
                    if other ~= agent and other.S < carry + length + TrafficModel.Idm.S0 then
                        blocked = true
                        agent.Speed = math.min(agent.Speed, other.Speed)
                    end
                end
                local entered = enteredTail[entryKey]
                if entered and entered < carry + length + TrafficModel.Idm.S0 then
                    blocked = true
                    agent.Speed = 0
                end
            end
            if nextLink and not blocked then
                local previous = agent.Path
                local node = agent.EndNode
                local held = world.Reservations[node]
                enterEdge(world, agent, nextLink, agent.Lane, carry, previous)
                enteredTail[entryKey] = math.min(enteredTail[entryKey] or math.huge, agent.S)
                -- La réservation expire peu après, le temps de dégager la plateforme.
                if held and held.Agent == agent.Id then
                    held.Until = math.min(held.Until, serverTime + 2)
                end
            elseif blocked then
                agent.S = agent.Path.Length
            else
                agent.S = agent.Path.Length
                agent.Speed = 0
            end
        end
    end
end

return table.freeze(TrafficModel)
