--!strict
-- Lot 0.9.1 — campagne QA interactive autonome : non-régression des défauts trouvés
-- par les vrais clics et les captures inspectées dans la VM (règles PURES et
-- contrôles statiques). Les parcours eux-mêmes sont dans les sessions VM « ui… »
-- (docs/lot-0.9/TESTS_INTERACTIFS_AUTONOMES.md).

local roblox = require("@lune/roblox")
local Color3 = roblox.Color3

local SERVER = "ServerScriptService.AutomotiveWorldServer."
local SHARED = "ReplicatedStorage.Shared."
local STUDS_PER_METER = 1 / 0.28

return function(T: any, H: any)
    local CockpitGeometry = H.require(SHARED .. "Vehicles.CockpitGeometry")
    local BodyKits = H.require(SERVER .. "Vehicles.BodyKits")
    local VehicleDynamics = H.require(SHARED .. "Vehicles.Physics.VehicleDynamics")
    local Definitions = H.require(SHARED .. "Vehicles.VehicleDefinitions")

    local function source(path: string): string
        local node = H.game()
        for segment in string.gmatch(path, "[^%.]+") do
            node = node:FindFirstChild(segment)
        end
        return node.Source
    end
    local function studs(meters: number): number
        return meters * STUDS_PER_METER
    end

    T.suite("Lot 0.9.1 — défauts trouvés par la campagne interactive")

    T.test("QA-F15 : yeux du cockpit relevés au-dessus du volant, sous le pavillon", function()
        -- Volant bas : hauteur d'assise habituelle conservée.
        T.equal(CockpitGeometry.eyeY(0, 1, 2.5, nil), CockpitGeometry.EyeAboveSeat)
        -- Volant à hauteur des yeux (cas des prototypes) : yeux relevés, 10° de marge.
        local eye = CockpitGeometry.eyeY(0, 2.6, 2.5, nil)
        T.truthy(eye > CockpitGeometry.EyeAboveSeat, "relevés")
        T.truthy(math.abs(CockpitGeometry.wheelDropDeg(eye, 2.6, 2.5) - CockpitGeometry.MinWheelDropDeg) < 1e-6)
        -- Pavillon bas : plafonné sous le toit.
        T.equal(CockpitGeometry.eyeY(0, 2.6, 2.5, 3), 3 - CockpitGeometry.RoofClearance)
    end)

    T.test("QA-F15 : tous les modèles carrossés voient la route par-dessus le volant", function()
        local worst, worstId = math.huge, ""
        local worstBefore, worstBeforeId = math.huge, ""
        local checked = 0
        for _, definition in Definitions.all() do
            local style = definition.Appearance and definition.Appearance.BodyStyle
            if style and BodyKits.has(style) then
                -- Mêmes entrées que VehicleFactory.build (repère du centre de gravité).
                local chassis, tire = definition.Chassis, definition.Tires
                local layout = VehicleDynamics.wheelLayout(definition)
                local groundY = -studs(chassis.CgHeightM)
                local kit = BodyKits.build(
                    style,
                    {
                        GroundY = groundY,
                        HubY = groundY + studs(tire.RadiusM),
                        FrontAxleZ = -studs(layout[1].Longitudinal),
                        RearAxleZ = -studs(layout[3].Longitudinal),
                        TireRadius = studs(tire.RadiusM),
                        TireWidth = studs(tire.WidthM),
                        Width = studs(chassis.WidthM),
                        Length = studs(chassis.LengthM),
                        Height = studs(chassis.HeightM),
                    },
                    {
                        Body = Color3.new(1, 1, 1),
                        Accent = Color3.new(1, 1, 1),
                        Trim = Color3.new(0, 0, 0),
                    },
                    studs,
                    function(_props: any): any
                        return nil
                    end
                )
                local seatY, seatZ = kit.SeatOffset.Position.Y, kit.SeatOffset.Position.Z
                local wheelTop = kit.DashY + 0.25 + 0.2 + 0.55
                local distance = (seatZ - 0.35) - (kit.DashZ + 0.75)
                local eye = CockpitGeometry.eyeY(seatY, wheelTop, distance, kit.RoofY)
                local drop = CockpitGeometry.wheelDropDeg(eye, wheelTop, distance)
                -- Plafonné par le pavillon : la marge peut être moindre, jamais négative.
                local capped = kit.RoofY ~= nil and eye >= kit.RoofY - CockpitGeometry.RoofClearance - 1e-6
                T.truthy(
                    drop >= CockpitGeometry.MinWheelDropDeg - 1e-6 or (capped and drop > 0),
                    string.format("%s : %.1f° (yeux %.2f, pavillon %s)", definition.Id, drop, eye, tostring(kit.RoofY))
                )
                if drop < worst then
                    worst, worstId = drop, definition.Id
                end
                -- Avant la correction : yeux à hauteur fixe (assise + 2,45).
                local before = CockpitGeometry.wheelDropDeg(seatY + CockpitGeometry.EyeAboveSeat, wheelTop, distance)
                if before < worstBefore then
                    worstBefore, worstBeforeId = before, definition.Id
                end
                checked += 1
            end
        end
        T.truthy(checked >= 10, "modèles carrossés contrôlés : " .. checked)
        print(
            string.format(
                "    marge minimale %.1f° (%s), %d modèles ; à hauteur fixe : %.1f° (%s)",
                worst,
                worstId,
                checked,
                worstBefore,
                worstBeforeId
            )
        )
    end)

    T.test("QA-F15 : la fabrique place la caméra cockpit par CockpitGeometry", function()
        local factory = source(SERVER .. "Vehicles.VehicleFactory")
        T.truthy(string.find(factory, "CockpitGeometry.eyeY(", 1, true) ~= nil, "hauteur des yeux calculée")
        T.truthy(
            string.find(factory, "seatOffset.Y + 2.45", 1, true) == nil,
            "plus de hauteur fixe qui ignore le volant"
        )
    end)

    T.test("QA-F14 : aucun signe absent de la police dans les interfaces (⤢ ✕ ✓)", function()
        local ui = H.game():FindFirstChild("StarterPlayer")
        local found = {}
        for _, item in ui:GetDescendants() do
            if item.ClassName == "ModuleScript" or item.ClassName == "LocalScript" then
                local code = string.gsub(item.Source, "%-%-[^\n]*", "")
                for _, glyph in { "⤢", "✕", "✓" } do
                    if string.find(code, glyph, 1, true) then
                        table.insert(found, item.Name .. " " .. glyph)
                    end
                end
            end
        end
        T.equal(#found, 0, table.concat(found, ", "))
    end)

    T.test("QA-F16 : les opérations sensibles du panneau économique portent un identifiant", function()
        local EconomyProtocol = H.require(SHARED .. "Economy.EconomyProtocol")
        local panel = source("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.UI.EconomyPanel")
        local first, last = string.find(panel, "local function simple%(")
        local body = if first then string.sub(panel, first, (string.find(panel, "\nend", last, true) or #panel)) else ""
        local covered = string.find(body, "EconomyProtocol.Sensitive[action]", 1, true) ~= nil
            and string.find(body, "RequestId", 1, true) ~= nil
        local viaSimple = {}
        for action in string.gmatch(panel, 'simple%("(%w+)"') do
            if EconomyProtocol.Sensitive[action] then
                table.insert(viaSimple, action)
            end
        end
        T.truthy(#viaSimple == 0 or covered, "sensibles sans identifiant : " .. table.concat(viaSimple, ", "))
    end)

    T.test("QA-F17 : technologie d'éclairage explicite (Voxel), jamais « Compatibility »", function()
        -- Sans réglage, la place était en « Compatibility » (retirée par Roblox) : Studio
        -- affichait une fenêtre de migration modale par-dessus le jeu (tâche 20261103-203235).
        local lighting = H.game():FindFirstChild("Lighting")
        T.equal(tostring(lighting.Technology), "Enum.Technology.Voxel", "place de développement")
        local fs = require("@lune/fs")
        local serde = require("@lune/serde")
        local openWorld = serde.decode("json", fs.readFile("openworld.project.json"))
        local props = openWorld.tree.Lighting and openWorld.tree.Lighting["$properties"]
        T.equal(props and props.Technology, "Voxel", "place monde ouvert")
    end)

    T.test("QA-F18 : menu modal ouvert à l'arrêt → frein à main serré, relâché à la fermeture", function()
        local InputArbiter = H.require("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.Vehicles.InputArbiter")
        local arbiter = InputArbiter.newState()
        local idle = InputArbiter.NeutralKeyboard
        local pad = InputArbiter.DisconnectedGamepad
        local open = { Typing = false, WindowFocused = true, UiCaptured = true }
        local closed = { Typing = false, WindowFocused = true, UiCaptured = false }
        local held = InputArbiter.step(arbiter, idle, pad, open, 0.1)
        T.truthy(held.Handbrake == true, "frein à main serré, menu ouvert")
        T.equal(held.Throttle, 0, "accélérateur neutralisé")
        local released = InputArbiter.step(arbiter, idle, pad, closed, 0.1)
        T.truthy(not released.Handbrake, "relâché à la fermeture du menu")
    end)

    T.test("QA-F19 : passager du taxi assis dans l'habitacle (tête à hauteur des yeux)", function()
        local MissionCargo = H.require(SERVER .. "Economy.MissionCargo")
        local eyeM = CockpitGeometry.EyeAboveSeat * 0.28
        T.truthy(math.abs(MissionCargo.Passenger.HeadM - eyeM) < 0.1, "tête " .. MissionCargo.Passenger.HeadM .. " m")
        T.truthy(MissionCargo.Passenger.BustM < MissionCargo.Passenger.HeadM - 0.3, "buste sous la tête")
        local service = source(SERVER .. "Economy.MissionService")
        T.truthy(string.find(service, "MissionCargo.Passenger.HeadM", 1, true) ~= nil, "hauteurs utilisées")
    end)

    T.test("QA-F20 : destination au milieu d'une longue route acceptée, guidage le long de la route", function()
        local RoadGraph = H.require(SHARED .. "World.RoadGraph")
        local MapIndex = H.require(SHARED .. "Navigation.MapIndex")
        local RouteGuide = H.require(SHARED .. "Navigation.RouteGuide")
        local WorldLayout = H.require(SHARED .. "World.WorldLayout")
        local graph = RoadGraph.get()
        local index = MapIndex.build(graph.Layout)
        local start = graph.Layout.Network.NodeById["O"]
        local checked, refused = 0, {}
        for _, edge in graph.Layout.Edges do
            -- Milieu à plus de 600 m des deux carrefours : refusé avant la correction.
            if edge.LengthM > 1300 and RouteGuide.allowsClass("Road", edge.Class) then
                local mid = WorldLayout.sampleAt(edge.Polyline, 0.5)
                local plan, err = RouteGuide.plan(graph, index, start.X + 5, start.Z + 5, mid.X, mid.Z, "Road")
                checked += 1
                if plan == nil then
                    table.insert(refused, edge.Id .. " " .. tostring(err))
                else
                    -- Avant-dernier point sur la route, près de la destination (pas de ligne droite
                    -- à travers le relief depuis un carrefour lointain).
                    local before = plan.Points[#plan.Points - 1]
                    local gap = math.sqrt((before.X - mid.X) ^ 2 + (before.Z - mid.Z) ^ 2)
                    if gap > 150 then
                        table.insert(refused, string.format("%s : dernier segment %.0f m", edge.Id, gap))
                    end
                end
            end
        end
        T.truthy(checked >= 5, "longues routes contrôlées : " .. checked)
        T.equal(#refused, 0, table.concat(refused, " ; "))
        print(string.format("    %d longues routes : destination au milieu acceptée", checked))
    end)

    T.test("QA-A08 : valeurs non finies neutralisées, jamais d'erreur ni de force non finie", function()
        local Dynamics = H.require(SHARED .. "Vehicles.Physics.VehicleDynamics")
        local TireModel = H.require(SHARED .. "Vehicles.Physics.TireModel")
        local P01 = H.require(SHARED .. "Vehicles.Definitions.PrototypeP01")
        T.equal(TireModel.stopClamp(100, 50, 0 / 0, 1 / 60), 0, "limite NaN")
        T.equal(TireModel.stopClamp(100, -5, 1, 1 / 60), 0, "limite négative")
        local state = Dynamics.createState(P01)
        Dynamics.startEngine(state, P01)
        state.Wheels[1].AngularVelocity = 0 / 0
        state.Wheels[2].AngularVelocity = math.huge
        local before = Dynamics.numericResets()
        local contacts = {}
        for i = 1, 4 do
            contacts[i] = {
                Grounded = true,
                Compression = 0.1,
                CompressionVelocity = 0,
                LongitudinalVelocity = if i == 3 then 0 / 0 else 0,
                LateralVelocity = 0,
                SurfaceFriction = 1,
                Wet = false,
            }
        end
        local ok, forces = pcall(function()
            return Dynamics.step(
                state,
                P01,
                { Throttle = 1, Brake = 0, Steer = 0, Handbrake = false, Clutch = 0 },
                contacts,
                { Forward = 0, Lateral = 0, YawRate = 0 },
                1 / 60
            )
        end)
        T.truthy(ok, "pas d'erreur : " .. tostring(forces))
        for index, force in forces do
            for key, value in force do
                if type(value) == "number" then
                    T.truthy(
                        value == value and math.abs(value) < math.huge,
                        string.format("roue %d %s fini", index, key)
                    )
                end
            end
        end
        T.truthy(Dynamics.numericResets() > before, "neutralisation comptée")
        T.truthy(
            contacts[3].LongitudinalVelocity ~= contacts[3].LongitudinalVelocity,
            "contacts de l'appelant inchangés"
        )
    end)

    T.test("QA-F13 : confirmation du premier véhicule amenée dans la vue", function()
        local onboarding = source("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.UI.OnboardingController")
        T.truthy(string.find(onboarding, "revealConfirmation()", 1, true) ~= nil, "défilement vers la confirmation")
        T.truthy(string.find(onboarding, 'footer.Text = ""', 1, true) ~= nil, "pied périmé effacé")
        local economy = source("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.UI.EconomyPanel")
        local quoteAt = string.find(economy, "InputRouter.armConfirm()", 1, true)
        T.truthy(
            quoteAt ~= nil
                and string.find(string.sub(economy, quoteAt, quoteAt + 300), 'footer.Text = ""', 1, true) ~= nil,
            "économie : pied effacé à la confirmation"
        )
    end)
end
