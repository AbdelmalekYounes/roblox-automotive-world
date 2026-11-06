--!strict
-- Lot ANIM-03 : gestes d'entrée et de sortie du véhicule. Contrôles hors Studio : minutage des phases, porte et main
-- synchronisées, trajet continu du corps (aucune téléportation), poses (jambes l'une après l'autre), verrouillage de la
-- conduite et de la caméra, codage de la séquence, câblage serveur et client.
-- Le rendu réel (avatars, autres joueurs, caméra) relève de l'essai du propriétaire (rapport du lot).

local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3

return function(T: any, H: any)
    local SHARED = "ReplicatedStorage.Shared."
    local Motion = H.require(SHARED .. "Vehicles.BoardingMotion")
    local Doors = H.require(SHARED .. "Vehicles.Doors")
    local Data = H.require(SHARED .. "Vehicles.MeshKitData")
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

    local KITS = { Brio = Data.Kits.wk_brio, Comete = Data.Kits.wk_comete }
    local STEP = 1 / 120

    -- Cas réalistes : HumanoidRootPart assis 1,6 st au-dessus du centre du siège ; debout 1,2 st plus haut.
    local function cases()
        local list = {}
        for name, kit in KITS do
            for _, role in Doors.Roles do
                local spec = kit.Doors[role]
                local seatPos = if role == "Driver" then kit.SeatDriver else kit.SeatPassenger
                local seated = seatPos + Vector3.new(0, 1.6, 0)
                local stand = Motion.standPoint(spec, kit.SideHalf)
                table.insert(list, {
                    Name = name .. " " .. role,
                    Kit = kit,
                    Spec = spec,
                    Seated = seated,
                    Origin = Vector3.new(stand.X, seated.Y + 1.2, stand.Z),
                    Exit = Motion.exitPoint(spec.Side, kit.SideHalf, seatPos.Z) + Vector3.new(0, seated.Y + 1.2, 0),
                })
            end
        end
        return list
    end

    T.suite("ANIM-03 : gestes d'entrée et de sortie")

    T.test("1. minutage : entrée 2,5 s, sortie 2,2 s, phases dans l'ordre ; porte ouverte puis refermée", function()
        local e, x = Motion.Entry, Motion.Exit
        T.near(e.Total, 2.5, 1e-9, "entrée ≈ 2,5 s (décision du propriétaire)")
        T.near(x.Total, 2.2, 1e-9, "sortie un peu plus courte")
        local entryOrder = { 0, e.Reach, e.OpenEnd, e.Turn, e.LegIn, e.Sit, e.SecondLeg, e.CloseEnd }
        for i = 2, #entryOrder do
            T.truthy(entryOrder[i] > entryOrder[i - 1], "entrée : phase " .. i .. " après la précédente")
        end
        local exitOrder = { 0, x.InnerReach, x.OpenEnd, x.FirstFoot, x.SecondFoot, x.Rise, x.Stand, x.CloseEnd }
        for i = 2, #exitOrder do
            T.truthy(exitOrder[i] > exitOrder[i - 1], "sortie : phase " .. i .. " après la précédente")
        end
        T.truthy(e.CloseEnd <= e.Total and x.CloseEnd <= x.Total, "porte refermée avant la fin")
        for _, kind in { "In", "Out" } do
            local p = if kind == "In" then e else x
            T.near(Motion.doorFraction(kind, 0), 0, 1e-9, kind .. " : porte fermée au départ")
            T.near(Motion.doorFraction(kind, p.OpenStart), 0, 1e-9)
            T.near(Motion.doorFraction(kind, (p.OpenEnd + p.CloseStart) / 2), 1, 1e-9, kind .. " : ouverte")
            T.near(Motion.doorFraction(kind, p.CloseEnd), 0, 1e-9, kind .. " : refermée")
            local previous = 0
            for t = p.OpenStart, p.OpenEnd, STEP do
                local f = Motion.doorFraction(kind, t)
                T.truthy(f >= previous - 1e-9, kind .. " : ouverture sans retour en arrière")
                previous = f
            end
        end
    end)

    T.test("2. main et porte synchronisées : la main tient la poignée quand la porte bouge", function()
        for _, case in cases() do
            local spec = case.Spec
            local e, x = Motion.Entry, Motion.Exit
            -- Entrée : main sur la poignée extérieure AVANT que la porte ne bouge, lâchée après le début de l'ouverture.
            local atOpen = Motion.grip("In", spec.Side, e.OpenStart)
            T.truthy(atOpen ~= nil and not atOpen.Inner and atOpen.Weight > 0.99, case.Name .. " : main à la poignée")
            local hold = Motion.grip("In", spec.Side, (e.OpenStart + e.HandleRelease) / 2)
            T.truthy(hold ~= nil and hold.Weight > 0.99, case.Name .. " : main tenue pendant l'ouverture")
            -- Fermeture en entrant : poignée intérieure tenue pendant toute la fermeture.
            for t = e.CloseStart, e.CloseEnd, 0.05 do
                local g = Motion.grip("In", spec.Side, t)
                T.truthy(g ~= nil and g.Inner and g.Weight > 0.99, case.Name .. " : porte tirée jusqu'au bout")
            end
            -- Sortie : poignée intérieure pendant l'ouverture, poignée extérieure pendant la fermeture.
            local exitOpen = Motion.grip("Out", spec.Side, x.OpenStart)
            T.truthy(exitOpen ~= nil and exitOpen.Inner and exitOpen.Weight > 0.99, case.Name .. " : porte poussée")
            local exitClose = Motion.grip("Out", spec.Side, x.CloseStart)
            T.truthy(exitClose ~= nil and not exitClose.Inner and exitClose.Weight > 0.99, case.Name .. " : refermée")
            -- La cible de la main EST la poignée de la porte à son angle : même distance à la charnière à tout instant.
            local radius = (spec.Handle - spec.Hinge):Cross(spec.Axis).Magnitude
            for t = 0, e.Total, 0.1 do
                local f = Motion.doorFraction("In", t)
                local p = Motion.handlePoint(spec, false, f)
                T.near(
                    (p - spec.Hinge):Cross(spec.Axis).Magnitude,
                    radius,
                    1e-3,
                    case.Name .. " : poignée sur la porte"
                )
                T.near(
                    (p - Doors.rotatePoint(spec, spec.Handle, Doors.angle(spec, f))).Magnitude,
                    0,
                    1e-5,
                    "même rotation que la porte"
                )
            end
            -- Main du bon côté : face à la caisse, la poignée (à l'arrière de la porte) est du côté de la main choisie.
            local arm = atOpen.Arm
            T.equal(arm, if spec.Side < 0 then "Right" else "Left", case.Name .. " : main côté poignée")
            local seated = Motion.grip("In", spec.Side, e.CloseStart)
            T.equal(seated.Arm, if spec.Side < 0 then "Left" else "Right", case.Name .. " : main côté porte, assis")
        end
    end)

    T.test(
        "3. trajet continu : aucune téléportation, départ debout réel, arrivée au siège (et l'inverse)",
        function()
            for _, case in cases() do
                for _, kind in { "In", "Out" } do
                    local sequence = {
                        Kind = kind,
                        Seat = "Driver",
                        Door = "Driver",
                        T = 0,
                        Point = if kind == "In" then case.Origin else case.Exit,
                        Yaw = if kind == "In" then Motion.yawOf(Vector3.new(-case.Spec.Side, 0, 0)) else Motion.ExitYaw,
                    }
                    local keys = Motion.keys(sequence, case.Spec, case.Seated, case.Kit.SideHalf)
                    local total = Motion.total(kind)
                    local p0, y0 = Motion.bodyAt(keys, 0)
                    local p1 = Motion.bodyAt(keys, total)
                    local start = if kind == "In" then case.Origin else case.Seated
                    local finish = if kind == "In" then case.Seated else case.Exit
                    T.near((p0 - start).Magnitude, 0, 1e-4, case.Name .. " " .. kind .. " : départ")
                    T.near((p1 - finish).Magnitude, 0, 1e-4, case.Name .. " " .. kind .. " : arrivée")
                    T.near(y0, sequence.Yaw * (if kind == "In" then 1 else 0), 1e-6)
                    local prevP, prevY = p0, y0
                    local maxStep, maxTurn = 0, 0
                    for t = STEP, total, STEP do
                        local p, y = Motion.bodyAt(keys, t)
                        maxStep = math.max(maxStep, (p - prevP).Magnitude)
                        local dy = math.abs(((y - prevY + math.pi) % (2 * math.pi)) - math.pi)
                        maxTurn = math.max(maxTurn, dy)
                        prevP, prevY = p, y
                    end
                    -- 0,1 st par 1/120 s = 12 st/s au plus (pas rapide) ; 0,06 rad par image = 410°/s au plus.
                    T.truthy(maxStep < 0.1, string.format("%s %s : pas max %.3f st", case.Name, kind, maxStep))
                    T.truthy(maxTurn < 0.06, string.format("%s %s : rotation max %.3f rad", case.Name, kind, maxTurn))
                end
            end
        end
    )

    T.test("4. poses : debout puis assis, une jambe après l'autre, tête baissée sous le pavillon", function()
        for name, kit in KITS do
            local duck = kit.Doors.Driver.Duck
            local entry = Motion.poseKeys("In", duck)
            local e = Motion.Entry
            local start = Motion.poseAt(entry, 0)
            for joint, angles in start do
                T.near(angles.Magnitude, 0, 1e-9, name .. " : debout au départ (" .. joint .. ")")
            end
            local legIn = Motion.poseAt(entry, e.LegIn)
            T.truthy(legIn.FirstHip.X > math.rad(60), name .. " : première jambe engagée")
            T.truthy(legIn.SecondHip.X < math.rad(40), name .. " : seconde jambe encore dehors")
            T.truthy(legIn.Waist.X <= -math.rad(duck) + 1e-6, name .. " : buste penché")
            T.truthy(legIn.Neck.X < 0, name .. " : tête baissée")
            local seated = Motion.poseAt(entry, e.Total)
            T.near(math.deg(seated.FirstHip.X), 88, 1e-6, name .. " : assis")
            T.near(math.deg(seated.SecondKnee.X), -88, 1e-6)
            local exit = Motion.poseKeys("Out", duck)
            local x = Motion.Exit
            local firstFoot = Motion.poseAt(exit, x.FirstFoot)
            T.truthy(firstFoot.FirstHip.X < firstFoot.SecondHip.X, name .. " : un pied sort avant l'autre")
            local stood = Motion.poseAt(exit, x.Total)
            for joint, angles in stood do
                T.near(angles.Magnitude, 0, 1e-9, name .. " : debout à la fin (" .. joint .. ")")
            end
        end
        -- Porte gauche : on entre la jambe droite (côté habitacle) d'abord, on sort la jambe gauche d'abord.
        T.equal(Motion.jointName("FirstHip", "In", -1), "RightHip")
        T.equal(Motion.jointName("FirstHip", "Out", -1), "LeftHip")
        T.equal(Motion.jointName("FirstKnee", "In", 1), "LeftKnee")
        T.equal(Motion.jointName("Waist", "In", 1), "Waist")
        T.truthy(KITS.Comete.Doors.Driver.Duck > KITS.Brio.Doors.Driver.Duck, "Comète plus basse : buste plus penché")
    end)

    T.test("5. séquence : codage, verrouillage de la conduite, caméra, fondu, fin", function()
        local sequence = {
            Kind = "In",
            Seat = "Passenger",
            Door = "Driver",
            T = 1762400000.125,
            Point = Vector3.new(-4.4, 1.2, 2.5),
            Yaw = -1.5708,
        }
        local back = Motion.decode(Motion.encode(sequence))
        T.truthy(back ~= nil and back.Kind == "In" and back.Seat == "Passenger" and back.Door == "Driver", "décodage")
        T.near(back.T, sequence.T, 1e-3, "temps du serveur gardé")
        T.near((back.Point - sequence.Point).Magnitude, 0, 1e-3)
        T.near(back.Yaw, sequence.Yaw, 1e-4)
        T.equal(Motion.decode("In;Driver;Driver;1;2;3"), nil, "champs manquants refusés")
        T.equal(Motion.decode("Jump;Driver;Driver;1;2;3;4;5"), nil, "genre inconnu refusé")
        T.equal(Motion.decode("In;Pilote;Driver;1;2;3;4;5"), nil, "place inconnue refusée")
        T.equal(Motion.decode("In;Driver;Driver;nan;2;3;4;5"), nil, "nombre invalide refusé")
        local t0 = sequence.T
        T.truthy(Motion.locked(back, t0 + 0.1) and Motion.locked(back, t0 + 2.4), "conduite bloquée pendant l'entrée")
        T.truthy(not Motion.locked(back, t0 + 2.51), "conduite rendue à la fin")
        T.truthy(Motion.cameraHeld(back, t0 + 1), "entrée : caméra à la 3e personne")
        T.truthy(not Motion.cameraHeld(back, t0 + 2.6), "puis vue de conduite")
        local out = table.clone(back)
        out.Kind = "Out"
        T.truthy(not Motion.cameraHeld(out, t0 + 0.1), "sortie : vue de conduite jusqu'à l'ouverture")
        T.truthy(Motion.cameraHeld(out, t0 + Motion.Exit.OpenStart + 0.01), "puis 3e personne")
        T.near(Motion.weight(back, t0 + 1), 1, 1e-9, "entrée : gestes à plein")
        T.near(Motion.weight(back, t0 + 2.5 + Motion.BlendS), 0, 1e-9, "puis pose assise (mains au volant)")
        T.near(Motion.weight(out, t0), 0, 1e-9, "sortie : part de la pose assise")
        T.near(Motion.weight(out, t0 + 1), 1, 1e-9)
        T.truthy(not Motion.finished(back, t0 + 2.6) and Motion.finished(back, t0 + 2.81), "fin après le fondu")
    end)

    T.test(
        "6. câblage : serveur autoritaire, interruption, conduite et caméra, téléphone, aucune animation importée",
        function()
            local doorService = source("ServerScriptService.AutomotiveWorldServer.Vehicles.DoorService")
            T.truthy(has(doorService, "BoardingMotion.Attribute"), "séquence publiée par le serveur")
            T.truthy(
                has(doorService, "model.Parent ~= nil and character.Parent ~= nil"),
                "interruption : véhicule, joueur"
            )
            T.truthy(has(doorService, "BoardingMotion.DepartureAttribute"), "départ bloqué (passager)")
            T.truthy(
                has(doorService, "args.Valid()") and has(doorService, "args.Sit()"),
                "règles revalidées avant de s'asseoir"
            )
            local client = "StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.Vehicles."
            local controller = source(client .. "VehicleController")
            T.truthy(has(controller, "BoardingLock.filterInput("), "commandes neutres pendant les gestes")
            T.truthy(has(controller, "BoardingLock.holdCamera("), "caméra à la 3e personne")
            local visuals = source(client .. "DoorVisuals")
            T.truthy(has(visuals, 'UIManager.close("Phone")'), "téléphone rangé (PHONE-01)")
            T.truthy(has(visuals, "BoardingMotion.doorFraction("), "porte suivant la séquence")
            T.truthy(has(visuals, "camera.CameraSubject = head"), "caméra sur le corps visible")
            local animator = source(client .. "BoardingAnimator")
            T.truthy(
                has(animator, "ArmIk.solve(") and has(animator, "BoardingMotion.handlePoint("),
                "main sur la poignée"
            )
            T.truthy(
                not has(animator, "rbxassetid") and not has(animator, "KeyframeSequence"),
                "aucune animation importée"
            )
            local pose = source(client .. "SeatPoseController")
            T.truthy(has(pose, "current.Written:Lerp(over, boarding.Weight)"), "raccord avec la pose assise")
            local service = source("ServerScriptService.AutomotiveWorldServer.Vehicles.VehicleService")
            T.truthy(has(service, "exitPivotOverride[character] = pivot"), "dépôt au point où le corps est arrivé")
        end
    )
end
