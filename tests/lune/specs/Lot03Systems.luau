--!strict
local Fixtures = require("../fixtures/Fixtures")
-- Lot 0.3 — systèmes du monde ouvert testables hors Studio : météo et horloge,
-- humidité de chaussée appliquée UNE seule fois, feux déterministes, trafic PNJ
-- (modèle pur) et piétons. Ce sont des sorties de modèles, pas des essais en
-- jeu : le comportement réel en Studio reste à vérifier (docs/QA_BACKLOG.md).

local PlanarSim = require("../PlanarSim")

local DT = 1 / 60

local function input(throttle: number, brake: number, steer: number)
    return { Throttle = throttle, Brake = brake, Steer = steer, Handbrake = false, Clutch = 0 }
end

return function(T: any, H: any)
    local WeatherModel = H.require("ReplicatedStorage.Shared.World.WeatherModel")
    local Signals = H.require("ReplicatedStorage.Shared.World.Signals")
    local TrafficModel = H.require("ReplicatedStorage.Shared.World.TrafficModel")
    local PedestrianModel = H.require("ReplicatedStorage.Shared.World.PedestrianModel")
    local RoadGraph = H.require("ReplicatedStorage.Shared.World.RoadGraph")
    local WorldConfig = H.require("ReplicatedStorage.Shared.World.WorldConfig")
    local Dynamics = H.require("ReplicatedStorage.Shared.Vehicles.Physics.VehicleDynamics")
    local Definitions = H.require("ReplicatedStorage.Shared.Vehicles.VehicleDefinitions")
    local P02 = Fixtures.get("proto_p02")

    T.suite("Lot 0.3 — météo et cycle jour/nuit")

    T.test("cycle de 30 minutes synchronisé sur l'heure du serveur", function()
        T.equal(WeatherModel.DayLengthS, 1800)
        local epoch = 1000
        T.near(WeatherModel.clockTime(epoch, epoch), WeatherModel.StartHour, 1e-9)
        -- Un cycle complet ramène la même heure ; un demi-cycle avance de 12 h.
        T.near(WeatherModel.clockTime(epoch + 1800, epoch), WeatherModel.StartHour, 1e-6)
        T.near(WeatherModel.clockTime(epoch + 900, epoch), (WeatherModel.StartHour + 12) % 24, 1e-6)
    end)

    T.test("quatre états, enchaînements valides et durées bornées", function()
        T.equal(#WeatherModel.States, 4)
        for _, state in WeatherModel.States do
            for i = 0, 99 do
                local nextState = WeatherModel.nextState(state, i / 100)
                T.truthy(table.find(WeatherModel.States, nextState) ~= nil, nextState)
            end
            local range = WeatherModel.Presets[state].DurationS
            T.between(WeatherModel.duration(state, 0), range[1], range[2])
            T.between(WeatherModel.duration(state, 0.999), range[1], range[2])
        end
        -- Un orage n'enchaîne jamais sur un orage (poids nul).
        for i = 0, 99 do
            T.truthy(WeatherModel.nextState("Storm", i / 100) ~= "Storm", "orage → orage")
        end
    end)

    T.test("chaussée : mouillée sous la pluie, sèche ensuite, bornée à [0 ; 1]", function()
        local wet = 0
        for _ = 1, 600 do
            wet = WeatherModel.stepWetness(wet, "Rain", 1)
        end
        T.near(wet, 1, 1e-9, "détrempée après 10 min de pluie")
        local half = WeatherModel.stepWetness(1, "Clear", 150)
        T.between(half, 0.4, 0.6, "à moitié sèche après 2 min 30")
        for _ = 1, 600 do
            wet = WeatherModel.stepWetness(wet, "Clear", 1)
        end
        T.near(wet, 0, 1e-9, "sèche après 10 min de beau temps")
    end)

    T.test("AUD-WEATHER-01 : conditions standardisées définies (sec, ciel dégagé)", function()
        T.equal(WeatherModel.Standard.State, "Clear")
        T.equal(WeatherModel.Standard.Wetness, 0)
        T.between(WeatherModel.Standard.ClockTime, 0, 24)
    end)

    T.suite("Lot 0.3 — adhérence sous la pluie (réduction appliquée une fois)")

    local function brakingDistance(wet: boolean?, wetness: number?): number
        local snaps = PlanarSim.run(Dynamics, P02, {
            Dt = DT,
            Duration = 15,
            InitialForward = 80 / 3.6,
            Wet = wet,
            Wetness = wetness,
            Input = function()
                return input(0, 1, 0)
            end,
            Stop = function(s)
                return s.Forward < 0.2
            end,
        })
        return snaps[#snaps].Distance
    end

    T.test("humidité météo 1 ≡ surface mouillée ; les deux ensemble ne cumulent pas", function()
        local dry = brakingDistance(false, 0)
        local surface = brakingDistance(true, 0)
        local weather = brakingDistance(false, 1)
        local both = brakingDistance(true, 1)
        local half = brakingDistance(false, 0.5)
        T.near(weather, surface, 0.01, "météo seule = surface mouillée seule")
        T.near(both, surface, 0.01, "météo + surface = une seule réduction")
        T.truthy(half > dry and half < weather, string.format("%.1f entre %.1f et %.1f m", half, dry, weather))
        T.note(
            string.format(
                "P-02 80–0 km/h : sec %.1f m, humidité 0,5 %.1f m, mouillé %.1f m, mouillé + pluie %.1f m",
                dry,
                half,
                weather,
                both
            )
        )
    end)

    T.suite("Lot 0.3 — feux tricolores")

    T.test("cycle déterministe : jamais deux groupes au vert en même temps", function()
        for _, node in { "O", "C_N", "B05", "Q:Q-NE:A3:2" } do
            local greens = { 0, 0 }
            for step = 0, math.floor(Signals.CycleS * 4) - 1 do
                local t = step / 4
                local a, b = Signals.state(node, 1, t), Signals.state(node, 2, t)
                T.truthy(not (a ~= "Red" and b ~= "Red"), string.format("%s à %.2f s : %s / %s", node, t, a, b))
                greens[1] += if a == "Green" then 1 else 0
                greens[2] += if b == "Green" then 1 else 0
                -- Même entrée → même sortie (aucun état caché).
                T.equal(Signals.state(node, 1, t), a)
            end
            T.truthy(greens[1] > 0 and greens[2] > 0, node .. " : chaque groupe a son vert")
        end
    end)

    T.suite("Lot 0.3 — trafic PNJ (modèle pur)")

    local graph = RoadGraph.get()
    local layout = graph.Layout

    T.test("IDM : accélère librement, freine derrière un obstacle, jamais au-delà du freinage maximal", function()
        T.truthy(TrafficModel.idm(0, 14, math.huge, 0) > 1, "départ arrêté")
        T.near(TrafficModel.idm(14, 14, math.huge, 0), 0, 1e-6, "vitesse désirée atteinte")
        T.truthy(TrafficModel.idm(14, 14, 10, 14) < -2, "obstacle arrêté à 10 m")
        T.truthy(TrafficModel.idm(30, 36, 0.1, 30) >= -TrafficModel.Idm.MaxBrake, "freinage plafonné")
    end)

    T.test("pondération : uniquement des routes ouvertes au trafic, densité selon la zone", function()
        local world = TrafficModel.newWorld(graph)
        local choices, total = TrafficModel.spawnChoices(world)
        T.truthy(#choices > 100 and total > 0, #choices .. " sens de circulation")
        local byZone: { [string]: number } = {}
        for _, choice in choices do
            T.truthy(WorldConfig.RoadClasses[choice.Link.Edge.Class].Traffic, choice.Link.Edge.Id)
            byZone[choice.Link.Edge.Zone] = (byZone[choice.Link.Edge.Zone] or 0) + choice.Weight
        end
        T.truthy((byZone.Metropole or 0) > (byZone.Montagnes or 0), "métropole plus dense que les montagnes")
    end)

    T.test("150 agents pendant 5 min : aucune collision entre PNJ, vitesses légales, arrêt au rouge", function()
        local world = TrafficModel.newWorld(graph)
        local choices, total = TrafficModel.spawnChoices(world)
        local seed = 12345
        local function roll(): number
            seed = (seed * 16807) % 2147483647
            return seed / 2147483647
        end
        local spawned = 0
        while spawned < 150 do
            local link = TrafficModel.pick(choices, total, roll())
            local lanes = RoadGraph.laneCount(link.Edge)
            local agent = TrafficModel.spawn(world, link, 1 + math.floor(roll() * lanes), roll(), 0.9 + roll() * 0.15)
            -- Pas d'apparition collée à un autre agent de la même voie.
            local ok = true
            for _, other in world.Agents do
                if
                    other ~= agent
                    and other.EdgeId == agent.EdgeId
                    and other.Forward == agent.Forward
                    and other.Lane == agent.Lane
                    and math.abs(other.S - agent.S) < 20
                then
                    ok = false
                end
            end
            if ok then
                spawned += 1
            else
                TrafficModel.remove(world, agent)
            end
        end

        local dt = 0.2
        local overlaps, overspeed, redRuns, moved = 0, 0, 0, 0
        local startS: { [number]: string } = {}
        for _, agent in world.Agents do
            startS[agent.Id] = agent.EdgeId .. ":" .. agent.S
        end
        for step = 1, 1500 do
            local now = step * dt
            -- Avant le pas : agents à l'arrêt devant un feu rouge.
            local before: { [number]: { Edge: string, S: number, Red: boolean } } = {}
            for _, agent in world.Agents do
                local node = layout.Network.NodeById[agent.EndNode]
                local red = false
                if node.Control == "Signals" and (world.Degree[agent.EndNode] or 0) >= 3 then
                    local group = world.SignalGroups[agent.EndNode .. "|" .. agent.EdgeId .. "|" .. (if agent.Forward
                        then "1"
                        else "0")] or 1
                    red = Signals.state(agent.EndNode, group, now) == "Red"
                end
                before[agent.Id] = { Edge = agent.EdgeId, S = agent.S, Red = red and agent.S < agent.StopS - 1 }
            end
            TrafficModel.step(world, dt, now, {}, roll)
            -- Même voie : jamais d'interpénétration (longueur d'un véhicule).
            local lanes: { [string]: { any } } = {}
            for _, agent in world.Agents do
                local key = agent.EdgeId .. "|" .. tostring(agent.Forward) .. "|" .. agent.Lane
                lanes[key] = lanes[key] or {}
                table.insert(lanes[key], agent)
                if agent.Speed > agent.Desired + 0.5 then
                    overspeed += 1
                end
                local prior = before[agent.Id]
                if prior.Red and prior.Edge == agent.EdgeId and agent.S > agent.StopS + 0.5 then
                    redRuns += 1
                end
            end
            for _, list in lanes do
                table.sort(list, function(a, b)
                    return a.S < b.S
                end)
                for i = 2, #list do
                    if list[i].S - list[i - 1].S < TrafficModel.VehicleLengthM - 0.5 then
                        overlaps += 1
                    end
                end
            end
        end
        for _, agent in world.Agents do
            if startS[agent.Id] ~= agent.EdgeId .. ":" .. agent.S then
                moved += 1
            end
        end
        T.equal(overlaps, 0, "interpénétrations sur une même voie")
        T.equal(overspeed, 0, "dépassements de la vitesse désirée")
        T.equal(redRuns, 0, "franchissements de feu rouge")
        T.truthy(moved > 140, moved .. " agents ont circulé sur 150")
        T.note(string.format("Trafic : 150 agents × 300 s simulés, %d ont circulé", moved))
    end)

    T.test("un véhicule de joueur arrêté sur la voie fait s'arrêter le PNJ avant contact", function()
        local world = TrafficModel.newWorld(graph)
        -- Tronçon droit et long ouvert au trafic.
        local link: any = nil
        for _, edge in layout.Edges do
            if edge.Class == "Departementale" and edge.LengthM > 600 then
                link = { Edge = edge, To = edge.To, Forward = true }
                break
            end
        end
        T.truthy(link ~= nil, "tronçon de départementale trouvé")
        local agent = TrafficModel.spawn(world, link, 1, 0, 1)
        agent.Speed = agent.Desired
        local obstaclePoint = TrafficModel.sample(agent.Path, 250)
        local obstacle = { X = obstaclePoint.X, Z = obstaclePoint.Z, Speed = 0, Radius = 2.3 }
        local function roll(): number
            return 0.5
        end
        for step = 1, 600 do
            TrafficModel.step(world, 0.1, step * 0.1, { obstacle }, roll)
        end
        T.truthy(
            agent.S < 250 - TrafficModel.VehicleLengthM / 2 - 2.3,
            string.format("arrêté à %.1f m (obstacle à 250 m)", agent.S)
        )
        T.truthy(agent.Speed < 0.2, "à l'arrêt")
    end)

    T.suite("Lot 0.3 — piétons")

    T.test("déterministes, sur les trottoirs des zones animées seulement", function()
        local count, metro, mountains = 0, 0, 0
        for _, edge in layout.Edges do
            for _, sidewalk in PedestrianModel.sidewalks(edge) do
                T.truthy(WorldConfig.RoadClasses[edge.Class].Pedestrians, edge.Id)
                local a = PedestrianModel.walkers(sidewalk, 1234.5)
                local b = PedestrianModel.walkers(sidewalk, 1234.5)
                for i, walker in a do
                    T.equal(walker.Position.X, b[i].Position.X)
                end
                count += #a
                if edge.Zone == "Metropole" then
                    metro += #a
                elseif edge.Zone == "Montagnes" then
                    mountains += #a
                end
            end
        end
        T.truthy(metro > 100, metro .. " piétons en métropole")
        T.equal(mountains, 0, "aucun piéton en montagne")
        T.note(
            string.format("Piétons théoriques sur toute la carte : %d (rendus seulement près de la caméra)", count)
        )
    end)
end
