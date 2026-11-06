--!strict
-- Lot ANIM-02 : portières et animations d'entrée et de sortie. Contrôles hors Studio : données des portes (miroir,
-- sens d'ouverture comparé aux aperçus Blender), état répliqué des portes, glissé des personnages, calendrier des
-- séquences et règles d'interruption, câblage serveur et client, pièces des portes dans les gabarits.
-- Le rendu réel (portes ouvertes, glissé, autres joueurs, interruptions) relève de l'essai du propriétaire (rapport).

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame

return function(T: any, H: any)
    local SHARED = "ReplicatedStorage.Shared."
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

    local function v(t: { number }): any
        return Vector3.new(t[1], t[2], t[3])
    end

    local KITS = { Brio = Data.Kits.wk_brio, Comete = Data.Kits.wk_comete }

    T.suite("ANIM-02 : portières, entrée et sortie")

    T.test("1. deux portes par véhicule ; porte droite miroir de la gauche (charnière, axe, pièces)", function()
        for name, kit in KITS do
            local doors = kit.Doors
            T.truthy(doors ~= nil, name .. " : portes")
            local left, right = doors.Driver, doors.Passenger
            T.equal(left.Side, -1)
            T.equal(right.Side, 1)
            T.near(right.Hinge.X, -left.Hinge.X, 1e-6, name .. " : charnière miroir")
            T.near(right.Hinge.Y, left.Hinge.Y, 1e-6)
            T.near(right.Hinge.Z, left.Hinge.Z, 1e-6)
            T.near(right.Axis.X, left.Axis.X, 1e-6, name .. " : axe miroir (a.x, −a.y, −a.z)")
            T.near(right.Axis.Y, -left.Axis.Y, 1e-6)
            T.near(right.Axis.Z, -left.Axis.Z, 1e-6)
            T.near(left.Axis.Magnitude, 1, 1e-5, "axe unitaire")
            T.equal(#left.Parts, #right.Parts, name .. " : autant de pièces des deux côtés")
            T.equal(right.OpenAngle, left.OpenAngle)
        end
        T.equal(KITS.Brio.Doors.Driver.OpenAngle, 65, "Brio 65°")
        T.equal(KITS.Comete.Doors.Driver.OpenAngle, 75, "Comète 75°")
        T.truthy(table.find(KITS.Brio.Doors.Driver.Parts, "BRIO_Vitrage_Conducteur") ~= nil, "vitre solidaire (Brio)")
        T.truthy(table.find(KITS.Comete.Doors.Driver.Parts, "COMETE_PorteG_glass") ~= nil, "vitre solidaire (Comète)")
    end)

    -- Aperçus du dépôt d'art (`portieres_apercu.py`, 2026-11-06) : centre des sommets de la porte, fermée puis ouverte
    -- (Brio 65°, Comète 75°), relevé dans le repère du jeu. Le jeu doit ouvrir la porte au même endroit.
    T.test(
        "2. ouverture : même mouvement que les aperçus Blender (porte qui s'écarte ; élytre qui monte)",
        function()
            local cases = {
                { KITS.Brio.Doors.Driver, { -2.729, 0.84, 0.253 }, { -4.703, 0.84, -0.914 } },
                { KITS.Brio.Doors.Passenger, { 2.749, 0.828, 0.228 }, { 4.689, 0.828, -0.943 } },
                { KITS.Comete.Doors.Driver, { -2.617, 1.271, -2.024 }, { -3.089, 2.757, -2.673 } },
                { KITS.Comete.Doors.Passenger, { 2.618, 1.274, -2.02 }, { 3.088, 2.761, -2.673 } },
            }
            for i, case in cases do
                local spec, closed, opened = case[1], v(case[2]), v(case[3])
                local moved = Doors.rotatePoint(spec, closed, math.rad(spec.OpenAngle))
                T.near((moved - opened).Magnitude, 0, 0.01, "cas " .. i .. " : centre ouvert")
                T.truthy(
                    math.abs(moved.X) > math.abs(closed.X) + 0.4,
                    "cas " .. i .. " : la porte s'écarte de la caisse"
                )
                T.near((Doors.rotatePoint(spec, closed, 0) - closed).Magnitude, 0, 1e-5, "fermée : aucun déplacement")
            end
            -- Articulation : repère dont Z est l'axe ; la rotation de `Transform` est celle de `rotatePoint`.
            for _, kit in KITS do
                for _, role in Doors.Roles do
                    local spec = kit.Doors[role]
                    local frame = Doors.jointFrame(spec)
                    T.near((frame.ZVector - spec.Axis).Magnitude, 0, 1e-5, "Z = axe de la charnière")
                    T.near((frame.Position - spec.Hinge).Magnitude, 0, 1e-5, "origine sur la charnière")
                    local p = spec.Hinge + Vector3.new(0.3, -0.2, 2.0)
                    local a = math.rad(40)
                    local viaJoint = (frame * Doors.jointTransform(a) * frame:Inverse()) * p
                    local rodrigues = CFrame.new(spec.Hinge)
                        * CFrame.fromAxisAngle(spec.Axis, a)
                        * CFrame.new(-spec.Hinge)
                    T.near((viaJoint - rodrigues * p).Magnitude, 0, 1e-4, "rotation autour de l'axe")
                end
            end
        end
    )

    T.test("3. état répliqué : fraction, inversion en cours de course, codage texte (temps du serveur)", function()
        local t0 = 1762400000.25
        local opening = Doors.transition(nil, t0, 1, Doors.OpenS)
        T.near(Doors.fraction(opening, t0), 0, 1e-5, "part fermée")
        T.near(Doors.fraction(opening, t0 + Doors.OpenS / 2), 0.5, 1e-5)
        T.near(Doors.fraction(opening, t0 + 10), 1, 1e-5, "reste ouverte")
        -- Refermée à mi-course : repart de 0,5, en la moitié de la durée de fermeture.
        local closing = Doors.transition(opening, t0 + Doors.OpenS / 2, 0, Doors.CloseS)
        T.near(closing.From, 0.5, 1e-5)
        T.near(closing.Duration, Doors.CloseS / 2, 1e-5)
        T.near(Doors.fraction(closing, closing.T + closing.Duration), 0, 1e-5)
        local decoded = Doors.decode(Doors.encode(closing))
        T.truthy(decoded ~= nil, "décodage")
        T.near(decoded.T, closing.T, 1e-3, "temps du serveur gardé au millième")
        T.near(decoded.From, 0.5, 1e-3)
        T.near(decoded.Duration, closing.Duration, 1e-3)
        T.equal(Doors.decode("ouverte"), nil, "texte invalide refusé")
        T.equal(Doors.decode(12), nil)
        T.equal(Doors.fraction(nil, t0), 0, "sans état : fermée")
        T.near(Doors.angle(KITS.Brio.Doors.Driver, 1), math.rad(65), 1e-5)
        T.near(Doors.eased(0.5), 0.5, 1e-5)
        T.near(Doors.eased(2), 1, 1e-5)
    end)

    T.test("4. glissé : codage, poids d'entrée et de sortie, décalage du corps, garde-fou", function()
        local t0 = 1762400000
        local glide = { Kind = "In", Role = "Passenger", T = t0, Point = Vector3.new(4.5, 1.2, 0.75) }
        local back = Doors.decodeGlide(Doors.encodeGlide(glide))
        T.truthy(back ~= nil and back.Kind == "In" and back.Role == "Passenger", "décodage")
        T.near((back.Point - glide.Point).Magnitude, 0, 1e-3)
        T.equal(Doors.decodeGlide("Jump;Driver;1;2;3;4"), nil, "genre inconnu refusé")
        T.equal(Doors.decodeGlide("In;Pilote;1;2;3;4"), nil, "rôle inconnu refusé")
        T.near(Doors.glideWeight(glide, t0), 1, 1e-5, "entrée : corps à la porte au départ")
        T.near(Doors.glideWeight(glide, t0 + Doors.GlideInS), 0, 1e-5, "puis au siège")
        local out = { Kind = "Out", Role = "Driver", T = t0, Point = Vector3.new(-5, 1, 0.75) }
        T.near(Doors.glideWeight(out, t0), 0, 1e-5, "sortie : corps au siège au départ")
        T.near(Doors.glideWeight(out, t0 + Doors.GlideOutS), 1, 1e-5, "puis au point de dépôt")
        T.near(Doors.glideWeight(out, t0 + 5), 1, 1e-5, "maintenu jusqu'à la libération")
        local chassis = CFrame.new(10, 2, 3)
        local seated = chassis:PointToWorldSpace(Vector3.new(-1.2, 0.5, 0.75))
        local offset = Doors.glideOffset(out, t0 + Doors.GlideOutS, chassis, seated)
        T.near((seated + offset - chassis:PointToWorldSpace(out.Point)).Magnitude, 0, 1e-4, "corps au point")
        T.equal(Doors.glideOffset(glide, t0 + 1, chassis, seated), nil, "glissé fini : aucun décalage")
        local far = { Kind = "In", Role = "Driver", T = t0, Point = Vector3.new(-40, 0, 0) }
        T.equal(Doors.glideOffset(far, t0, chassis, seated), nil, "point aberrant : aucun glissé")
    end)

    T.test("5. calendrier (≈ 1 s / 0,8 s), interruption, porte de sortie, point d'arrivée", function()
        T.near(Doors.OpenS + Doors.GlideInS, 0.85, 1e-5, "entrée sans marche : assis puis glissé en 0,85 s")
        local quick = Doors.entryPlan(0.1)
        T.near(quick.SitAt, Doors.OpenS, 1e-5, "assis quand la porte est ouverte")
        T.near(quick.CloseAt, Doors.OpenS + Doors.GlideInS, 1e-5, "fermeture à la fin du glissé")
        T.near(Doors.entryPlan(0.8).SitAt, 0.8, 1e-5, "après la marche")
        T.near(Doors.entryPlan(9).SitAt, Doors.WalkMaxS, 1e-5, "marche bornée à 1 s")
        local exit = Doors.exitPlan()
        T.near(exit.ReleaseAt, 0.8, 1e-5, "sortie : libéré à 0,8 s")
        T.near(exit.DoneAt, 0.8 + Doors.CloseS, 1e-5)
        T.truthy(not Doors.shouldInterrupt(0.5, 3, 3), "à l'arrêt, sans choc")
        T.truthy(Doors.shouldInterrupt(Doors.InterruptSpeed + 0.1, 3, 3), "véhicule qui part")
        T.truthy(Doors.shouldInterrupt(0, 3, 4), "nouveau choc")
        T.truthy(not Doors.shouldInterrupt(0, nil, 4), "compteur absent au départ : pas de faux choc")
        local half = KITS.Brio.SideHalf
        T.equal(Doors.roleForExit(Vector3.new(-(half + 3), 1.5, 0), half), "Driver")
        T.equal(Doors.roleForExit(Vector3.new(half + 3, 1.5, 0), half), "Passenger", "autre porte si côté bloqué")
        T.equal(Doors.roleForExit(Vector3.new(0, 8, 0), half), nil, "au-dessus : sans animation")
        local stand = Doors.standPoint(-1, half, KITS.Brio.SeatDriver)
        T.near(stand.X, -(half + Doors.StandOut), 1e-5, "à l'extérieur de la caisse")
        T.near(stand.Z, KITS.Brio.SeatDriver.Z, 1e-5, "au droit du siège")
    end)

    T.test("6. câblage : charnières serveur, séquences, rotation et glissé clients, saut du passager", function()
        local meshKits = source("ServerScriptService.AutomotiveWorldServer.Vehicles.MeshKits")
        T.truthy(has(meshKits, "Doors.jointFrame(spec)") and has(meshKits, "Doors.JointName"), "Motor6D de charnière")
        T.truthy(has(meshKits, "weld(hinge, item)"), "pièces soudées à la charnière")
        T.truthy(has(meshKits, "complete = false"), "porte articulée seulement si toutes ses pièces sont là")
        local service = source("ServerScriptService.AutomotiveWorldServer.Vehicles.VehicleService")
        T.truthy(has(service, 'boardOrSit(record, "Driver"'), "conducteur : séquence")
        T.truthy(has(service, 'boardOrSit(record, "Passenger"'), "passager : séquence")
        T.truthy(has(service, 'alightOrRelease(record, "Driver"'), "sortie conducteur")
        T.truthy(has(service, 'alightOrRelease(record, "Passenger"'), "sortie passager")
        T.truthy(has(service, "DoorService.reserved(record.Model"), "place réservée pendant la marche")
        T.truthy(has(service, "DoorService.start(remotesFolder)"), "demande de sortie des passagers")
        local doorService = source("ServerScriptService.AutomotiveWorldServer.Vehicles.DoorService")
        T.truthy(has(doorService, "args.Valid()"), "règles revalidées pendant la marche")
        T.truthy(has(doorService, "interrupted(root, model, impactsAtStart)"), "interruption")
        T.truthy(has(doorService, "args.MayRelease()"), "sortie interrompue : libérée ou annulée selon la vitesse")
        local damage = source("ServerScriptService.AutomotiveWorldServer.Vehicles.DamageService")
        T.truthy(not has(damage, "Doors"), "DamageService non modifié")
        local client = "StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.Vehicles."
        local visuals = source(client .. "DoorVisuals")
        T.truthy(has(visuals, "Workspace:GetServerTimeNow()"), "temps du serveur : même image pour tous")
        T.truthy(has(visuals, "Enum.KeyCode.Space") and has(visuals, "Enum.ContextActionResult.Sink"), "saut capté")
        T.truthy(has(visuals, "humanoid:MoveTo(approach)"), "marche jusqu'à la porte")
        local pose = source(client .. "SeatPoseController")
        T.truthy(has(pose, "DoorVisuals.update(dt)"), "portes à chaque pas")
        T.truthy(has(pose, 'name == "Root" and glide'), "glissé par l'articulation Root")
    end)

    -- Pièces des portes dans les gabarits (importées et envoyées par le propriétaire le 2026-11-06) : présentes, centrées comme dans
    -- l'export réduit du dépôt d'art, une seule fois.
    T.test("7. gabarits : pièces des portes présentes et placées comme l'export", function()
        local expected = {
            Brio = {
                File = "assets/meshkits/Brio.rbxm",
                Reference = "BRIO_Caisse_Peinture",
                Centers = {
                    BRIO_PorteG_Peinture = { -2.671, 0.31, 0.432 },
                    BRIO_PorteD_Peinture = { 2.684, 0.293, 0.432 },
                    BRIO_PorteG_Habitacle = { -2.468, 0.36, 0.408 },
                    BRIO_PorteD_Habitacle = { 2.48, 0.36, 0.404 },
                    BRIO_PorteG_Soubassement = { -2.934, 0.706, 0.507 },
                    BRIO_PorteD_Soubassement = { 2.962, 0.67, 0.507 },
                    BRIO_Caisse_Peinture = { 0.006, 1.364, 2.813 },
                    BRIO_Habitacle = { 0.014, 1.132, 2.288 },
                    BRIO_Soubassement = { 0.006, 0.84, 0.76 },
                    BRIO_Vitrage_Conducteur = { -2.241, 2.08, 0.777 },
                    BRIO_Vitrage_Passager = { 2.275, 2.052, 0.777 },
                },
            },
            Comete = {
                File = "assets/meshkits/Comete720s.rbxm",
                Reference = "COMETE_Caisse_body",
                Centers = {
                    COMETE_PorteG_body = { -2.947, 0.431, -2.085 },
                    COMETE_PorteD_body = { 2.947, 0.431, -2.085 },
                    COMETE_PorteG_carbon_fibre = { -2.789, 0.366, -0.357 },
                    COMETE_PorteD_carbon_fibre = { 2.789, 0.366, -0.357 },
                    COMETE_PorteG_black_metallic = { -2.083, 0.988, -2.085 },
                    COMETE_PorteD_black_metallic = { 2.083, 0.988, -2.085 },
                    COMETE_PorteG_interior = { -1.832, 1.309, -1.75 },
                    COMETE_PorteD_interior = { 1.833, 1.309, -1.75 },
                    COMETE_PorteG_glass = { -2.315, 1.916, -1.835 },
                    COMETE_PorteD_glass = { 2.315, 1.916, -1.835 },
                    COMETE_PorteG_Retro_body = { -3.611, 1.407, -3.574 },
                    COMETE_PorteD_Retro_body = { 3.611, 1.407, -3.574 },
                    COMETE_PorteG_Retro_carbon_fibre = { -3.551, 1.546, -3.557 },
                    COMETE_PorteD_Retro_carbon_fibre = { 3.551, 1.546, -3.557 },
                    COMETE_PorteG_Retro_mirror = { -3.548, 1.741, -3.226 },
                    COMETE_PorteD_Retro_mirror = { 3.548, 1.741, -3.226 },
                    COMETE_Caisse_body = { 0.0, 0.354, -1.214 },
                    COMETE_Vitrage_glass = { 0.0, 2.078, -1.146 },
                },
            },
        }
        for name, case in expected do
            local kit = KITS[name]
            local template = roblox.deserializeModel(fs.readFile(case.File))[1]
            local first = template:FindFirstChild(kit.Doors.Driver.Parts[1], true)
            T.truthy(first ~= nil, name .. " : pièces des portes intégrées au gabarit (import du 2026-11-06)")
            local reference = template:FindFirstChild(case.Reference, true)
            local shift = reference.CFrame.Position - kit.ReferenceCenter -- (Lune : Position non sérialisée)
            for part, center in case.Centers do
                local found = {}
                for _, item in template:GetDescendants() do
                    if item.ClassName == "MeshPart" and item.Name == part then
                        table.insert(found, item)
                    end
                end
                T.equal(#found, 1, name .. " : " .. part .. " une fois")
                if found[1] then
                    T.near(
                        (found[1].CFrame.Position - shift - v(center)).Magnitude,
                        0,
                        0.01,
                        part .. " au centre de l'export"
                    )
                end
            end
            for _, role in Doors.Roles do
                for _, part in kit.Doors[role].Parts do
                    T.truthy(template:FindFirstChild(part, true) ~= nil, name .. " : " .. part)
                end
            end
        end
    end)
end
