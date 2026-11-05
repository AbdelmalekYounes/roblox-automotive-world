--!strict
local Fixtures = require("../fixtures/Fixtures")
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

    -- QA-F15 sur les carrosseries provisoires : retiré avec elles (lot BASE-01) ; la vue cockpit de la Comète est
    -- contrôlée par Veh3d01Comete (repères mesurés sur son volant réel).

    T.test("QA-A08 : valeurs non finies neutralisées, jamais d'erreur ni de force non finie", function()
        local Dynamics = H.require(SHARED .. "Vehicles.Physics.VehicleDynamics")
        local TireModel = H.require(SHARED .. "Vehicles.Physics.TireModel")
        local P01 = Fixtures.get("proto_p01")
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
        -- Lot UI-04 : le pied de l'économie est devenu le bandeau d'état du serveur (PanelKit) ; même règle.
        T.truthy(
            quoteAt ~= nil
                and string.find(string.sub(economy, quoteAt, quoteAt + 300), 'shell:setStatus(nil, "")', 1, true)
                    ~= nil,
            "économie : état périmé effacé à la confirmation"
        )
    end)
end
