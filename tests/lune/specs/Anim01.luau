--!strict
-- Lot ANIM-01 : volants qui tournent et mains du conducteur sur le volant. Contrôles hors Studio : rapport et sens de
-- rotation, prises à 9 h 15 qui suivent puis glissent, cinématique inverse des bras (atteinte, coude vers le pôle,
-- cible hors d'atteinte), données mesurées des volants et présence du câblage (serveur, client, règle du téléphone).
-- Le rendu réel (avatars, vue cockpit, autres joueurs) relève de l'essai du propriétaire (rapport du lot).

local roblox = require("@lune/roblox")
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

-- Les types de valeur de Lune sont en simple précision (32 bits) : tolérance des comparaisons géométriques.
local EPS = 1e-5

return function(T: any, H: any)
    local SHARED = "ReplicatedStorage.Shared."
    local SteeringWheel = H.require(SHARED .. "Vehicles.SteeringWheel")
    local ArmIk = H.require(SHARED .. "Vehicles.ArmIk")
    local Data = H.require(SHARED .. "Vehicles.MeshKitData")
    local Definitions = H.require(SHARED .. "Vehicles.VehicleDefinitions")
    local SeatPose = H.require(SHARED .. "Vehicles.SeatPose")
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

    local BRIO = Data.Kits.wk_brio.SteeringWheel
    local COMETE = Data.Kits.wk_comete.SteeringWheel

    T.suite("ANIM-01 : volants et mains")

    T.test("1. rapport réaliste : angle du volant = angle des roues × rapport (Brio 14:1, Comète 12:1)", function()
        T.truthy(BRIO ~= nil and COMETE ~= nil, "volants des deux kits")
        T.equal(BRIO.Ratio, 14)
        T.equal(COMETE.Ratio, 12)
        local brio = Definitions.get("wk_brio").Steering
        local comete = Definitions.get("wk_comete").Steering
        -- À fond en manœuvre, puis à la vitesse de référence (angle des roues réduit par la vitesse).
        T.near(math.deg(SteeringWheel.wheelAngle(math.rad(brio.MaxAngleDeg), BRIO.Ratio)), 490, 1e-9, "Brio ±490°")
        T.near(
            math.deg(SteeringWheel.wheelAngle(math.rad(comete.MaxAngleDeg), COMETE.Ratio)),
            360,
            1e-9,
            "Comète ±360°"
        )
        T.near(math.deg(SteeringWheel.wheelAngle(math.rad(brio.HighSpeedAngleDeg), BRIO.Ratio)), 126, 1e-9)
        T.near(math.deg(SteeringWheel.wheelAngle(math.rad(comete.HighSpeedAngleDeg), COMETE.Ratio)), 108, 1e-9)
        T.near(SteeringWheel.wheelAngle(-0.1, 14), -1.4, 1e-12, "symétrique")
    end)

    T.test("2. lissage de la consigne répliquée à la vitesse de la crémaillère", function()
        T.near(SteeringWheel.approach(0, 1, 2, 0.1), 0.2, 1e-12, "pas borné")
        T.near(SteeringWheel.approach(0.95, 1, 2, 0.1), 1, 1e-12, "atteint sans dépasser")
        T.near(SteeringWheel.approach(0, -1, 2, 0.1), -0.2, 1e-12, "vers la gauche")
        T.near(SteeringWheel.approach(0.3, 0.3, 2, 0.1), 0.3, 1e-12, "immobile")
    end)

    T.test(
        "3. sens : braquage à droite = sens horaire vu du conducteur ; articulation le long de la colonne",
        function()
            for _, spec in { BRIO, COMETE } do
                local axis = spec.Axis
                T.near(axis.Magnitude, 1, EPS, "axe unitaire")
                T.truthy(axis.Z > 0.9 and axis.Y > 0, "axe vers le conducteur (arrière) et vers le haut")
                local frame = SteeringWheel.jointFrame(spec)
                T.near(frame.ZVector:Dot(axis), 1, EPS, "Z de l'articulation = colonne")
                T.near((frame.Position - spec.Hub).Magnitude, 0, EPS, "pivot au centre de la jante")
                -- Haut de la jante, puis rotation de 30° à droite : il part vers la droite (+X) et descend.
                local vertical = Vector3.new(0, 1, 0)
                local up = (vertical - axis * vertical:Dot(axis)).Unit * spec.GripRadius
                local turned = SteeringWheel.rotation(spec, math.rad(30)):VectorToWorldSpace(up)
                T.truthy(turned.X > 0 and turned.Y < up.Y, "haut de la jante vers la droite")
                -- L'articulation donne la même rotation que la formule (même point de la jante).
                local viaJoint = frame * SteeringWheel.jointTransform(math.rad(30)) * frame:Inverse()
                local point = spec.Hub + up
                local direct = spec.Hub + turned
                T.near((viaJoint * point - direct).Magnitude, 0, EPS, "articulation cohérente")
            end
        end
    )

    T.test("4. prises à 9 h 15 sur la jante, suivies jusqu'à ±100° puis glissantes", function()
        for _, spec in { BRIO, COMETE } do
            local left, right = SteeringWheel.grips(spec, 0)
            for _, grip in { left, right } do
                local offset = grip - spec.Hub
                T.near(offset.Magnitude, spec.GripRadius, EPS, "sur le rayon de prise")
                T.near(offset:Dot(spec.Axis), 0, EPS, "dans le plan de la jante")
                T.near(grip.Y, spec.Hub.Y, EPS, "à l'horizontale (9 h 15)")
            end
            T.truthy(left.X < spec.Hub.X and right.X > spec.Hub.X, "gauche à gauche, droite à droite")
            -- Virage à droite : main droite qui descend, main gauche qui monte.
            local l30, r30 = SteeringWheel.grips(spec, math.rad(30))
            T.truthy(r30.Y < spec.Hub.Y and l30.Y > spec.Hub.Y, "mains qui suivent la rotation")
            -- Au-delà de 100° : les mains restent à 100° (elles glissent sur la jante).
            local l100, r100 = SteeringWheel.grips(spec, math.rad(100))
            local l300, r300 = SteeringWheel.grips(spec, math.rad(300))
            T.near((l300 - l100).Magnitude + (r300 - r100).Magnitude, 0, EPS, "glissement au-delà de 100°")
            local lm, rm = SteeringWheel.grips(spec, math.rad(-490))
            local lr, rr = SteeringWheel.grips(spec, math.rad(-100))
            T.near((lm - lr).Magnitude + (rm - rr).Magnitude, 0, EPS, "idem à gauche")
            T.near(math.deg(SteeringWheel.handAngle(math.rad(60))), 60, EPS, "suivi exact sous la limite")
        end
    end)

    -- Chaîne R15 de synthèse (ordres de grandeur d'un bras R15 standard ; les avatars réels donnent leurs propres
    -- repères, lus en jeu sur leurs articulations).
    local function chain(side: number): any
        return {
            ShoulderC0 = CFrame.new(side * 1, 0.563, 0),
            ShoulderC1 = CFrame.new(side * -0.5, 0.42, 0),
            ElbowC0 = CFrame.new(0, -0.334, 0),
            ElbowC1 = CFrame.new(0, 0.262, 0),
            WristC0 = CFrame.new(0, -0.501, 0),
            WristC1 = CFrame.new(0, 0.125, 0),
            Grip = Vector3.new(0, -0.15, 0),
        }
    end

    T.test("5. cinématique inverse : la prise atteint la cible, coude plié vers l'avant et vers le pôle", function()
        local c = chain(1)
        local upper, lower = ArmIk.lengths(c)
        T.truthy(upper > 0.5 and lower > 0.5, "longueurs lues sur les repères")
        local minReach, maxReach = ArmIk.reach(c)
        T.truthy(maxReach <= upper + lower + EPS and minReach < 0.6 * maxReach, "allonge permise par la charnière")
        local shoulderPivot = c.ShoulderC0.Position
        local pole = Vector3.new(0.6, -1, 0.2)
        local worst = 0
        local count = 0
        -- Cibles devant le buste, à portée (60 à 95 % de l'allonge), dans plusieurs directions.
        for _, dir in
            {
                Vector3.new(0, -0.3, -1),
                Vector3.new(-0.4, -0.2, -1),
                Vector3.new(0.3, 0.2, -1),
                Vector3.new(-0.2, -0.6, -0.8),
                Vector3.new(0.5, -0.4, -0.7),
            }
        do
            for _, reach in { 0.6, 0.75, 0.95 } do
                local target = shoulderPivot + dir.Unit * maxReach * reach
                local s, e, reached = ArmIk.solve(c, target, pole)
                T.truthy(reached, "à portée")
                local got = ArmIk.forward(c, s, e)
                worst = math.max(worst, (got - target).Magnitude)
                count += 1
                -- Coude : charnière autour de X, pli positif borné.
                local bend = math.atan2(e.LookVector.Y, -e.LookVector.Z)
                T.between(bend, -1e-6, ArmIk.MaxElbow + 1e-6, "pli du coude dans [0, 150°]")
                -- Coude du côté du pôle par rapport à la ligne épaule → cible.
                local line = (target - shoulderPivot).Unit
                local elbowAt = ArmIk.elbowPosition(c, s) - shoulderPivot
                local side = elbowAt - line * elbowAt:Dot(line)
                local wanted = pole - line * pole:Dot(line)
                T.truthy(side:Dot(wanted) > 0, "coude orienté vers le pôle")
            end
        end
        T.truthy(worst < 1e-3, string.format("écart maximal %.2e st sur %d cibles", worst, count))
    end)

    T.test("6. cible hors d'atteinte : bras tendu vers elle ; cible trop proche : pli maximal sans erreur", function()
        local c = chain(-1)
        local _, maxReach = ArmIk.reach(c)
        local pivot = c.ShoulderC0.Position
        local direction = Vector3.new(0.2, -0.3, -1).Unit
        -- Juste hors d'allonge (0,2 st) : rattrapé par l'avancée de l'épaule, prise exacte.
        local near = pivot + direction * (maxReach + 0.2)
        local s1, e1, reached1 = ArmIk.solve(c, near, Vector3.new(-0.6, -1, 0.2))
        T.truthy(reached1, "rattrapé par l'épaule")
        T.near((ArmIk.forward(c, s1, e1) - near).Magnitude, 0, 1e-3, "prise exacte")
        T.near(s1.Position.Magnitude, 0.2, 1e-3, "épaule avancée de 0,2 st")
        -- Sans avancée permise : bras tendu, signalé hors d'atteinte.
        local s0, _, reached0 = ArmIk.solve(c, near, Vector3.new(-0.6, -1, 0.2), 0)
        T.truthy(not reached0 and s0.Position.Magnitude < 1e-6, "aucune avancée si interdite")
        -- Loin (1,5 fois l'allonge) : épaule avancée au maximum, bras tendu vers la cible.
        local s, e, reached = ArmIk.solve(c, pivot + direction * maxReach * 1.5, Vector3.new(-0.6, -1, 0.2))
        T.truthy(not reached, "signalée hors d'atteinte")
        local got = ArmIk.forward(c, s, e) - pivot
        T.truthy(got.Unit:Dot(direction) > 0.999, "bras dirigé vers la cible")
        T.near(got.Magnitude, maxReach + ArmIk.MaxShoulderShift, 0.01, "bras tendu, épaule avancée au maximum")
        local s2, e2 = ArmIk.solve(c, pivot + direction * 0.01, Vector3.new(-0.6, -1, 0.2))
        T.finite(ArmIk.forward(c, s2, e2).Magnitude, "résultat fini")
    end)

    T.test(
        "7. volants mesurés : centre de la jante dans la pièce du volant (Brio), rayons et inclinaisons",
        function()
            T.equal(BRIO.Part, "BRIO_Volant")
            T.equal(COMETE.Part, "COMETE_Volant")
            T.between(BRIO.GripRadius, 0.54, 0.65, "Brio : rayon dans le boudin mesuré")
            T.between(COMETE.GripRadius, 0.53, 0.65, "Comète : rayon dans le boudin mesuré")
            T.near(math.deg(math.asin(BRIO.Axis.Y)), 20.2, 0.1, "Brio : jante inclinée de 20°")
            T.near(math.deg(math.asin(COMETE.Axis.Y)), 12.1, 0.1, "Comète : jante inclinée de 12°")
            -- Volants devant la place du conducteur, du côté gauche.
            for _, id in { "wk_brio", "wk_comete" } do
                local kit = Data.Kits[id]
                local spec = kit.SteeringWheel
                T.near(spec.Hub.X, kit.SeatDriver.X, 0.1, id .. " : volant dans l'axe du siège")
                T.truthy(spec.Hub.Z < kit.SeatDriver.Z, id .. " : volant devant le siège")
                T.truthy(spec.Hub.Y > kit.SeatDriver.Y and spec.Hub.Y < kit.CameraCockpit.Y, id .. " : sous la caméra")
            end
            -- Gabarit de la Brio : la pièce existe et son centre de boîte est à 0,01 st du centre de la jante.
            local kit = Data.Kits.wk_brio
            local template = game.ServerStorage.AutomotiveWorldMeshKits:FindFirstChild(kit.Template)
            local reference = template:FindFirstChild(kit.Reference, true)
            local part = template:FindFirstChild(BRIO.Part, true)
            T.truthy(part ~= nil and part.ClassName == "MeshPart", "BRIO_Volant dans le gabarit")
            local shift = reference.CFrame.Position - kit.ReferenceCenter
            T.near(
                (part.CFrame.Position - shift - BRIO.Hub).Magnitude,
                0,
                0.01,
                "pivot du volant au centre de la jante"
            )
        end
    )

    T.test("8. câblage : articulation serveur, rotation client, mains et règle du téléphone (QA-A10)", function()
        local meshKits = source("ServerScriptService.AutomotiveWorldServer.Vehicles.MeshKits")
        T.truthy(has(meshKits, 'Instance.new("Motor6D")') and has(meshKits, "SteeringWheel.JointName"), "Motor6D")
        T.truthy(has(meshKits, "SteeringWheel.jointFrame(spec)"), "repère le long de la colonne")
        local visuals = source("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.Vehicles.SteeringWheelVisuals")
        T.truthy(has(visuals, "Constants.Attributes.VisualSteer"), "autres joueurs : consigne répliquée")
        T.truthy(has(visuals, "localState.SteerPosition"), "conducteur : crémaillère locale")
        T.truthy(has(visuals, "VehicleDynamics.maxSteerAngle"), "angle des roues selon la vitesse")
        local controller = source("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.Vehicles.VehicleController")
        T.truthy(has(controller, "SteeringWheelVisuals.setLocal("), "état local transmis")
        local pose = source("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.Vehicles.SeatPoseController")
        T.truthy(has(pose, "not (phoneUp and SeatPose.ArmJoints[name])"), "pose : bras libres téléphone sorti")
        T.truthy(has(pose, "if seat and pose and not phoneUp then handsOnWheel"), "mains : rien téléphone sorti")
        T.truthy(has(pose, "SteeringWheelVisuals.update(dt)"), "volant puis mains, même pas")
        T.truthy(has(pose, "setCharacterVisibilityFilter"), "avant-bras visibles en cockpit")
        -- Les bras restent ceux de la règle QA-A10 (aucun ajout).
        local count = 0
        for _ in SeatPose.ArmJoints do
            count += 1
        end
        T.equal(count, 4, "4 articulations des bras")
    end)
end
