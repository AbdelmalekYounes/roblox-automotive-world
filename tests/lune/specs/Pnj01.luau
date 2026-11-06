--!strict
-- Lot PNJ-01 (partie modèles) : contrat des modèles 3D des voitures PNJ et des piétons, allure des piétons animée par
-- le code, feux stop et clignotants des voitures PNJ. Contrôles hors Studio ; le rendu réel (silhouettes, roues, feux,
-- animation) relève de l'essai du propriétaire (docs/lot-pnj-01/RAPPORT_PNJ_01.md).

local roblox = require("@lune/roblox")
local CFrame = roblox.CFrame

return function(T: any, H: any)
    local SHARED = "ReplicatedStorage.Shared."
    local PnjKits = H.require(SHARED .. "World.PnjKits")
    local Gait = H.require(SHARED .. "World.PedestrianGait")
    local Cues = H.require(SHARED .. "World.TrafficCues")
    local PedestrianModel = H.require(SHARED .. "World.PedestrianModel")
    local TrafficModel = H.require(SHARED .. "World.TrafficModel")
    local RoadGraph = H.require(SHARED .. "World.RoadGraph")
    local game = H.game()

    local function source(path: string): string
        local node = game
        for segment in string.gmatch(path, "[^%.]+") do
            node = node:FindFirstChild(segment)
            assert(node, path)
        end
        return node.Source
    end
    local function has(text: string, needle: string): boolean
        return string.find(text, needle, 1, true) ~= nil
    end

    T.suite("PNJ-01 : contrat des modèles 3D")

    T.test("10 variantes de voitures aux cotes mesurées cohérentes, tirage pondéré", function()
        T.equal(#PnjKits.Cars, 10, "variantes")
        local total = 0
        for _, car in PnjKits.Cars do
            total += car.Weight
            T.truthy(car.LengthM > 3.0 and car.LengthM < 5.6, car.Id .. " longueur")
            T.truthy(car.WidthM > 1.6 and car.WidthM < 2.1, car.Id .. " largeur")
            T.truthy(car.WheelbaseM + 2 * car.WheelRadiusM < car.LengthM, car.Id .. " roues dans la longueur")
            T.near(car.AvantM + car.ArriereM, car.LengthM, 0.01, car.Id .. " porte-à-faux = longueur")
            T.truthy(car.TrackM + car.WheelWidthM <= car.WidthM, car.Id .. " roues dans la largeur")
            T.truthy(PnjKits.ClearanceM + car.BoxHeightM < car.HeightM, car.Id .. " boîte sous le toit")
            T.truthy(car.WheelRadiusM * 2 > PnjKits.ClearanceM, car.Id .. " roues touchent le sol sous la boîte")
            T.equal(car.Template, "PNJ_" .. car.Id, car.Id .. " gabarit")
            local front = PnjKits.wheelCenter(car, "Roue_AVG")
            local rear = PnjKits.wheelCenter(car, "Roue_ARD")
            T.truthy(front.X < 0 and front.Z < 0, "avant gauche : −X, −Z")
            T.truthy(rear.X > 0 and rear.Z > 0, "arrière droite : +X, +Z")
            T.near(front.Y, car.WheelRadiusM, 1e-6, "roue posée au sol")
        end
        T.near(total, 1, 1e-6, "somme des parts")
        local counts: { [string]: number } = {}
        for i = 0, 999 do
            local id = PnjKits.pickCar((i + 0.5) / 1000).Id
            counts[id] = (counts[id] or 0) + 1
        end
        T.equal(counts.Berline, 180, "berlines")
        T.equal(counts.Coupe, 20, "coupés (rares)")
        T.equal(counts.Sportive, 20, "sportives (rares)")
        T.truthy(PnjKits.car("SUV") ~= nil and PnjKits.car("Inconnue") == nil, "recherche par identifiant")
    end)

    T.test("gabarit 3D : jantes soudées à leur roue, couleurs unies par type de pièce", function()
        local wheel, isWheel = PnjKits.wheelOf("Roue_AVG")
        T.truthy(wheel == "Roue_AVG" and isWheel, "roue")
        wheel, isWheel = PnjKits.wheelOf("Roue_ARD_Jante")
        T.truthy(wheel == "Roue_ARD" and not isWheel, "jante portée par sa roue")
        T.equal(PnjKits.wheelOf("Garniture"), nil, "pièce de caisse")
        T.equal((PnjKits.partStyle("Roue_AVG_Jante") :: any).Pattern, "_Jante", "jante avant pneu")
        T.equal((PnjKits.partStyle("Roue_AVG") :: any).Pattern, "Roue_", "pneu")
        T.equal((PnjKits.partStyle("Feu_Stop_G") :: any).Pattern, "Feu_Stop", "feu stop")
        T.equal(PnjKits.partStyle("Peinture_Caisse"), nil, "peinture tirée à part")
    end)

    T.test("gabarit des voitures importé : 10 modèles complets, maillages au manifeste, cotes conformes", function()
        local AssetManifest = H.require(SHARED .. "Assets.AssetManifest")
        local folder = game.ReplicatedStorage:FindFirstChild(PnjKits.FolderName)
        T.truthy(folder ~= nil, "ReplicatedStorage." .. PnjKits.FolderName)
        local entry = AssetManifest.get(PnjKits.CarManifestId)
        local allowed: { [number]: boolean } = {}
        for _, id in entry.RobloxAssetIds do
            allowed[id] = true
        end
        local found = 0
        for _, car in PnjKits.Cars do
            local model = folder:FindFirstChild(car.Template)
            T.truthy(model ~= nil, car.Template)
            local names: { [string]: boolean } = {}
            for _, part in model:GetChildren() do
                T.equal(part.ClassName, "MeshPart", part.Name)
                names[part.Name] = true
                local id = tonumber(string.match(tostring(part.MeshContent), "rbxassetid://(%d+)"))
                T.truthy(id ~= nil and allowed[id], car.Id .. "." .. part.Name .. " au manifeste")
                found += 1
            end
            T.equal(#PnjKits.missingCarParts(names), 0, car.Id .. " : 4 roues")
            -- Cotes : empattement et voie mesurés entre les roues importées (studs → m).
            local function center(name: string): any
                return (model:FindFirstChild(name) :: any).CFrame.Position
            end
            local front = (center("Roue_AVG") + center("Roue_AVD")) / 2
            local rear = (center("Roue_ARG") + center("Roue_ARD")) / 2
            local wheelbase = (front - rear).Magnitude * 0.28
            local track = (center("Roue_AVG") - center("Roue_AVD")).Magnitude * 0.28
            T.near(wheelbase, car.WheelbaseM, 0.05, car.Id .. " empattement")
            T.near(track, car.TrackM, 0.05, car.Id .. " voie")
            -- Gauche (G) à gauche du sens de marche : (avant − arrière) × (G − D) vertical positif.
            local forward = front - rear
            local left = center("Roue_AVG") - center("Roue_AVD")
            T.truthy(forward:Cross(left).Y > 0, car.Id .. " roue gauche à gauche")
        end
        T.equal(found, #entry.RobloxAssetIds, "manifeste = exactement les maillages du gabarit")
    end)

    T.test("piétons : squelette complet, apparence stable et variée, contrôle des gabarits", function()
        for _, segment in PnjKits.Segments do
            T.truthy(PnjKits.joint(segment.Joint) ~= nil, segment.Name .. " → " .. segment.Joint)
        end
        for _, joint in PnjKits.Joints do
            if joint.Parent then
                T.truthy(PnjKits.joint(joint.Parent) ~= nil, joint.Name .. " parent")
            end
        end
        T.equal(#PnjKits.Segments, 11, "pièces rigides")
        local a, b = PnjKits.look("E1|1|3"), PnjKits.look("E1|1|3")
        T.truthy(a.Top == b.Top and a.Morphology.Id == b.Morphology.Id, "même clé, même apparence")
        local tops, morphs = {}, {}
        for k = 1, 200 do
            local look = PnjKits.look("Q:centre:r" .. k .. "|-1|" .. k)
            tops[tostring(look.Top)] = true
            morphs[look.Morphology.Id] = true
        end
        local distinct = 0
        for _ in tops do
            distinct += 1
        end
        T.truthy(distinct >= 6, distinct .. " couleurs de haut sur 200 piétons")
        T.truthy(morphs.H and morphs.F, "deux morphologies")
        local missing = PnjKits.missingPedestrianParts({ Tete = true, Buste = true })
        T.equal(#missing, 9, "pièces manquantes signalées")
        T.equal(#PnjKits.missingCarParts({ Roue_AVG = true, Roue_AVD = true, Roue_ARG = true }), 1, "roue manquante")
    end)

    T.suite("PNJ-01 : allure des piétons (animation par le code)")

    local function ankle(frames: any, side: string, scale: number): any
        -- Cheville ≈ 0,47 m sous le genou (repos), dans le repère de la jambe basse.
        local knee = frames["Genou" .. side]
        return (knee * CFrame.new(0, -0.47 * scale, 0)).Position
    end

    T.test("pose de repos : articulations à leur place, pièces à leur centre", function()
        local pose = { Root = CFrame.identity, Rotations = {} }
        local frames = Gait.jointFrames(pose, 1)
        for _, joint in PnjKits.Joints do
            T.truthy((frames[joint.Name].Position - joint.Rest).Magnitude < 1e-4, joint.Name)
        end
        for _, segment in PnjKits.Segments do
            local frame = Gait.segmentFrame(frames, segment.Joint, CFrame.new(segment.Center), 1)
            T.truthy((frame.Position - segment.Center).Magnitude < 1e-4, segment.Name)
        end
    end)

    T.test("marche : jambes et bras alternés, genou jamais en hyperextension, pieds au sol", function()
        local speed = 1.4
        local f0 = Gait.jointFrames(Gait.pose("Walk", 0, speed, 0), 1)
        local f5 = Gait.jointFrames(Gait.pose("Walk", 0.5, speed, 0), 1)
        T.truthy(ankle(f0, "G", 1).Z < ankle(f0, "D", 1).Z - 0.3, "phase 0 : pied gauche devant")
        T.truthy(ankle(f5, "D", 1).Z < ankle(f5, "G", 1).Z - 0.3, "phase 0,5 : pied droit devant")
        -- Bras opposé : main gauche derrière quand le pied gauche est devant.
        local handG = (f0.CoudeG * CFrame.new(0, -0.3, 0)).Position
        local handD = (f0.CoudeD * CFrame.new(0, -0.3, 0)).Position
        T.truthy(handG.Z > handD.Z, "bras gauche en arrière à la phase 0")
        local lowest, highest = math.huge, -math.huge
        for i = 0, 99 do
            local pose = Gait.pose("Walk", i / 100, speed, 0)
            for _, side in { "G", "D" } do
                local x = pose.Rotations["Genou" .. side]:ToEulerAnglesXYZ()
                T.truthy(x <= 1e-6, "genou plié vers l'arrière seulement")
            end
            local frames = Gait.jointFrames(pose, 1)
            local y = math.min(ankle(frames, "G", 1).Y, ankle(frames, "D", 1).Y)
            lowest = math.min(lowest, y)
            highest = math.max(highest, y)
        end
        -- Cheville au repos à 0,04 m : le pied d'appui reste près du sol (ni enfoncé ni en l'air).
        T.truthy(lowest > -0.06, string.format("cheville la plus basse %.3f m", lowest))
        T.truthy(highest < 0.12, string.format("cheville d'appui la plus haute %.3f m", highest))
    end)

    T.test("marche : la phase suit la distance — le pied d'appui glisse peu", function()
        for _, speed in { 1.0, 1.3, 1.6 } do
            local stride = Gait.strideLength(speed, "Walk", 1)
            -- Pied gauche en appui de la phase 0,05 à 0,45 : déplacement au sol = recul du pied − avancée du corps.
            local p1, p2 = 0.05, 0.45
            local z1 = ankle(Gait.jointFrames(Gait.pose("Walk", p1, speed, 0), 1), "G", 1).Z
            local z2 = ankle(Gait.jointFrames(Gait.pose("Walk", p2, speed, 0), 1), "G", 1).Z
            local body = (p2 - p1) * stride
            local slip = math.abs(body - (z2 - z1)) / body
            T.truthy(slip < 0.3, string.format("%.1f m/s : glissement %.0f %%", speed, slip * 100))
        end
        T.truthy(Gait.strideLength(1.6, "Walk") > Gait.strideLength(1.0, "Walk"), "foulée plus longue plus vite")
        T.equal(Gait.kindFor(0), "Idle")
        T.equal(Gait.kindFor(1.4), "Walk")
        T.equal(Gait.kindFor(3.2), "Run")
    end)

    T.test("course et attente : coudes pliés en course, attente sans pas", function()
        local run = Gait.pose("Run", 0.25, 3.2, 0)
        local elbow = run.Rotations.CoudeG:ToEulerAnglesXYZ()
        T.truthy(math.deg(elbow) > 70, string.format("coude en course %.0f°", math.deg(elbow)))
        local idle1 = Gait.jointFrames(Gait.pose("Idle", 0, 0, 10, 5), 1)
        local idle2 = Gait.jointFrames(Gait.pose("Idle", 0, 0, 12.5, 5), 1)
        T.truthy((ankle(idle1, "G", 1) - ankle(idle2, "G", 1)).Magnitude < 0.06, "pieds immobiles à l'attente")
        T.truthy((idle1.Cou.Position - idle2.Cou.Position).Magnitude > 1e-4, "le corps bouge un peu (respiration)")
    end)

    T.test("piétons : calcul isolé identique au calcul par trottoir, distance parcourue continue", function()
        local layout = RoadGraph.get().Layout
        local checked = 0
        for _, edge in layout.Edges do
            for _, sidewalk in PedestrianModel.sidewalks(edge) do
                local list = PedestrianModel.walkers(sidewalk, 500)
                for k, walker in list do
                    local single = PedestrianModel.walker(sidewalk, k, 500) :: any
                    T.equal(single.Key, walker.Key)
                    T.equal(single.Position.X, walker.Position.X)
                    local later = PedestrianModel.walker(sidewalk, k, 501) :: any
                    T.near(later.Travel - walker.Travel, walker.Speed, 1e-6, "Travel avance de Speed par seconde")
                    checked += 1
                end
                if checked > 200 then
                    break
                end
            end
            if checked > 200 then
                break
            end
        end
        T.truthy(checked > 200, checked .. " piétons comparés")
    end)

    T.suite("PNJ-01 : feux stop et clignotants")

    T.test("feux stop : décélération franche ou arrêt, pas en croisière", function()
        T.truthy(Cues.braking(10, 10.5, 0.2), "−2,5 m/s²")
        T.truthy(not Cues.braking(14, 14.05, 0.2), "croisière")
        T.truthy(not Cues.braking(5, 4.8, 0.2), "accélération")
        T.truthy(Cues.braking(0, 0, 0.2), "arrêté : pied sur le frein")
    end)

    T.test("clignotant : côté du virage (droite du sens de marche = (−dz, dx))", function()
        T.equal(Cues.turnSide(1, 0, 0, 1), "D", "est → sud (+Z) : à droite")
        T.equal(Cues.turnSide(1, 0, 0, -1), "G", "est → nord (−Z) : à gauche")
        T.equal(Cues.turnSide(1, 0, 0.98, 0.2), nil, "quasi tout droit : éteint")
    end)

    T.test("clignotant sur le réseau : allumé avant un virage, éteint loin du carrefour", function()
        local graph = RoadGraph.get()
        local world = TrafficModel.newWorld(graph)
        local found, far = 0, 0
        for _, edge in graph.Layout.Edges do
            if not TrafficModel.trafficEdge(edge) or edge.LengthM < 120 then
                continue
            end
            local link = { Edge = edge, To = edge.To, Forward = true }
            for _, nextLink in graph.Adjacency[edge.To] do
                if nextLink.Edge.Id ~= edge.Id and TrafficModel.trafficEdge(nextLink.Edge) then
                    local agent = TrafficModel.spawn(world, link :: any, 1, 0.5, 1)
                    agent.Next = nextLink
                    if Cues.indicator(agent) ~= nil then
                        far += 1
                    end
                    agent.S = agent.Path.Length - 20
                    local _, arrival = TrafficModel.sample(agent.Path, agent.Path.Length)
                    local points = nextLink.Edge.Polyline
                    local a = if nextLink.Forward then points[1] else points[#points]
                    local b = if nextLink.Forward then points[2] else points[#points - 1]
                    local dx, dz = b.X - a.X, b.Z - a.Z
                    local l = math.sqrt(dx * dx + dz * dz)
                    local expected = Cues.turnSide(arrival.X, arrival.Z, dx / l, dz / l)
                    T.equal(Cues.indicator(agent), expected, edge.Id .. " → " .. nextLink.Edge.Id)
                    if expected ~= nil then
                        found += 1
                    end
                    TrafficModel.remove(world, agent)
                end
            end
            if found > 40 then
                break
            end
        end
        T.truthy(found > 40, found .. " virages signalés")
        T.equal(far, 0, "aucun clignotant au milieu d'un tronçon long")
    end)

    T.test("câblage : corps 3D ou repli côté serveur, animation locale côté client", function()
        local service = source("ServerScriptService.AutomotiveWorldServer.World.TrafficService")
        T.truthy(has(service, "TrafficBodies.build("), "le service construit les corps par TrafficBodies")
        T.truthy(has(service, "TrafficBodies.publish("), "feux publiés au changement")
        local bodies = source("ServerScriptService.AutomotiveWorldServer.World.TrafficBodies")
        T.truthy(has(bodies, "AssetManifest.get(PnjKits.CarManifestId)"), "gabarit soumis au manifeste")
        T.truthy(has(bodies, "part.CanCollide = false"), "pièces visuelles sans collision")
        T.truthy(has(bodies, "item.Massless = true"), "visuel 3D sans masse")
        local bootstrap = source("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.Bootstrap")
        T.truthy(has(bootstrap, '"TrafficVisuals"'), "client : TrafficVisuals démarré")
        local pedestrians = source("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.World.Pedestrians")
        T.truthy(has(pedestrians, "PedestrianGait.pose("), "piétons animés par l'allure")
        T.truthy(has(pedestrians, "part.CanCollide = false"), "piétons non solides")
        T.truthy(
            has(pedestrians, "AssetManifest.get(PnjKits.PedestrianManifestId)"),
            "gabarit piéton soumis au manifeste"
        )
    end)
end
