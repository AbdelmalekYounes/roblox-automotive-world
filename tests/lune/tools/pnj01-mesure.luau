--!strict
-- Outil de mesure en lecture seule (lot PNJ-01) : état des lieux et comparaison du trafic PNJ et des piétons,
-- hors Roblox. Les valeurs sont des sorties du modèle pur (TrafficModel / PedestrianModel), pas des mesures en jeu.
-- Usage : lune run tests/lune/tools/pnj01-mesure.luau build/AutomotiveWorld.rbxlx
local process = require("@lune/process")
local Harness = require("../Harness")
Harness.loadPlace(process.args[1])
local RoadGraph = Harness.require("ReplicatedStorage.Shared.World.RoadGraph")
local TrafficModel = Harness.require("ReplicatedStorage.Shared.World.TrafficModel")
local PedestrianModel = Harness.require("ReplicatedStorage.Shared.World.PedestrianModel")
local WorldConfig = Harness.require("ReplicatedStorage.Shared.World.WorldConfig")

local graph = RoadGraph.get()
local layout = graph.Layout

-- 1. Réseau routier.
local trafficEdges, trafficLength = 0, 0
local controls: { [string]: number } = {}
local world = TrafficModel.newWorld(graph)
for _, edge in layout.Edges do
    if WorldConfig.RoadClasses[edge.Class].Traffic then
        trafficEdges += 1
        trafficLength += edge.LengthM
    end
end
for _, node in layout.Network.Nodes do
    if (world.Degree[node.Id] or 0) >= 3 then
        controls[node.Control] = (controls[node.Control] or 0) + 1
    end
end
print(string.format("Réseau : %d tronçons ouverts au trafic, %.1f km", trafficEdges, trafficLength / 1000))
for control, n in controls do
    print(string.format("  carrefours (degré ≥ 3) %-10s : %d", control, n))
end

-- 2. Piétons.
local walkers, sidewalks = 0, 0
for _, edge in layout.Edges do
    for _, sidewalk in PedestrianModel.sidewalks(edge) do
        sidewalks += 1
        walkers += sidewalk.Count
    end
end
print(string.format("Piétons : %d trottoirs, %d piétons théoriques", sidewalks, walkers))

-- 3. Trafic : 150 agents pendant 300 s simulés au pas serveur (0,2 s).
local choices, total = TrafficModel.spawnChoices(world)
local seed = 4242
local function roll(): number
    seed = (seed * 16807) % 2147483647
    return seed / 2147483647
end
local AGENTS = tonumber(process.args[2]) or 150
while #world.Agents < AGENTS do
    local link = TrafficModel.pick(choices, total, roll())
    local lanes = RoadGraph.laneCount(link.Edge)
    local agent = TrafficModel.spawn(world, link, 1 + math.floor(roll() * lanes), roll(), 0.9 + roll() * 0.15)
    for _, other in world.Agents do
        if
            other ~= agent
            and other.EdgeId == agent.EdgeId
            and other.Forward == agent.Forward
            and other.Lane == agent.Lane
            and math.abs(other.S - agent.S) < 20
        then
            TrafficModel.remove(world, agent)
            break
        end
    end
end

local dt = 0.2
local steps = 1500
local lastSpeed: { [number]: number } = {}
local lastAccel: { [number]: number } = {}
local lastHeading: { [number]: number } = {}
local samples, hardBrake, emergency, bigJerk, lateral4, lateral8, stopped = 0, 0, 0, 0, 0, 0, 0
local maxLateral, maxJerk, maxDecel = 0, 0, 0
local headingJumps = 0
local clock = os.clock()
local stepTimes: { number } = {}
for step = 1, steps do
    local t0 = os.clock()
    TrafficModel.step(world, dt, step * dt, {}, roll)
    table.insert(stepTimes, os.clock() - t0)
    for _, agent in world.Agents do
        local _, direction = TrafficModel.position(agent)
        local heading = math.atan2(direction.Z, direction.X)
        local previous = lastSpeed[agent.Id]
        if previous then
            samples += 1
            local accel = (agent.Speed - previous) / dt
            maxDecel = math.max(maxDecel, -accel)
            if accel < -4 then
                hardBrake += 1
            end
            if accel < -7 then
                emergency += 1
            end
            local jerk = math.abs(accel - (lastAccel[agent.Id] or 0)) / dt
            maxJerk = math.max(maxJerk, jerk)
            if jerk > 10 then
                bigJerk += 1
            end
            lastAccel[agent.Id] = accel
            local dh = heading - (lastHeading[agent.Id] :: number)
            dh = (dh + math.pi) % (2 * math.pi) - math.pi
            -- Accélération latérale ≈ v × dθ/dt.
            local lat = math.abs(dh) / dt * agent.Speed
            if math.abs(dh) > math.rad(30) then
                headingJumps += 1
            end
            maxLateral = math.max(maxLateral, lat)
            if lat > 4 then
                lateral4 += 1
            end
            if lat > 8 then
                lateral8 += 1
            end
            if agent.Speed < 0.2 then
                stopped += 1
            end
        end
        lastSpeed[agent.Id] = agent.Speed
        lastHeading[agent.Id] = heading
    end
end
local elapsed = os.clock() - clock
table.sort(stepTimes)
print(string.format("Trafic : %d agents × %d s simulés (%d échantillons)", #world.Agents, steps * dt, samples))
print(
    string.format(
        "  coût du pas modèle : moyenne %.2f ms, P95 %.2f ms, max %.2f ms (Lune, poste de dev)",
        elapsed / steps * 1000,
        stepTimes[math.floor(steps * 0.95)] * 1000,
        stepTimes[steps] * 1000
    )
)
print(
    string.format(
        "  décélération max %.1f m/s² ; freinages > 4 m/s² : %.2f %% ; > 7 m/s² : %.2f %%",
        maxDecel,
        hardBrake / samples * 100,
        emergency / samples * 100
    )
)
print(string.format("  à-coups (|jerk| > 10 m/s³) : %.2f %% ; jerk max %.0f m/s³", bigJerk / samples * 100, maxJerk))
print(
    string.format(
        "  accélération latérale max %.1f m/s² ; > 4 m/s² : %.2f %% ; > 8 m/s² : %.2f %%",
        maxLateral,
        lateral4 / samples * 100,
        lateral8 / samples * 100
    )
)
print(string.format("  changements de cap > 30° en un pas (0,2 s) : %d", headingJumps))
print(string.format("  temps à l'arrêt : %.1f %% des échantillons", stopped / samples * 100))

-- 4. Vitesse au passage des carrefours selon l'angle de virage (sur un nouveau run de 120 s).
local lastEdge: { [number]: string } = {}
local lastDir: { [number]: number } = {}
local turnStats = { { 0, 0 }, { 0, 0 }, { 0, 0 } } -- {somme vitesses, nombre} : < 20°, 20–60°, > 60°
for step = 1, 600 do
    TrafficModel.step(world, dt, 300 + step * dt, {}, roll)
    for _, agent in world.Agents do
        local _, direction = TrafficModel.sample(agent.Path, agent.Path.Length)
        local endHeading = math.atan2(direction.Z, direction.X)
        if lastEdge[agent.Id] and lastEdge[agent.Id] ~= agent.EdgeId then
            local _, startDir = TrafficModel.sample(agent.Path, agent.Path.Cum[2] + 0.5)
            local h = math.atan2(startDir.Z, startDir.X)
            local turn = math.abs((h - lastDir[agent.Id] + math.pi) % (2 * math.pi) - math.pi)
            local bucket = if turn < math.rad(20) then 1 elseif turn < math.rad(60) then 2 else 3
            turnStats[bucket][1] += agent.Speed * 3.6
            turnStats[bucket][2] += 1
        end
        lastEdge[agent.Id] = agent.EdgeId
        lastDir[agent.Id] = endHeading
    end
end
for i, label in { "tout droit (< 20°)", "virage 20–60°", "virage > 60°" } do
    local s = turnStats[i]
    print(
        string.format(
            "  carrefours %-18s : %d passages, vitesse moyenne %.1f km/h",
            label,
            s[2],
            s[1] / math.max(s[2], 1)
        )
    )
end

-- 5. Piétons : chevauchements (deux piétons à moins de 0,5 m l'un de l'autre) à un instant donné.
local overlaps, counted = 0, 0
for _, edge in layout.Edges do
    for _, sidewalk in PedestrianModel.sidewalks(edge) do
        local list = PedestrianModel.walkers(sidewalk, 777)
        counted += #list
        for i = 1, #list do
            for j = i + 1, #list do
                local a, b = list[i].Position, list[j].Position
                if (a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2 < 0.25 then
                    overlaps += 1
                end
            end
        end
    end
end
print(string.format("Piétons : %d paires superposées (< 0,5 m) sur %d à t = 777 s", overlaps, counted))
