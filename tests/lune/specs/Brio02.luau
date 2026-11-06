--!strict
-- Lot BRIO-02 : boîte automatique de la Brio (plus de palier au rupteur, QA-S04) et assise (têtes sous le pavillon).
-- Contrôles hors Studio : dynamique pure sur le banc planaire (valeurs du banc, PAS des performances mesurées dans
-- Roblox) et cohérence des données mesurées de l'habitacle. La pose et le rendu en jeu sont vérifiés par le
-- propriétaire (liste de docs/lot-brio-02/RAPPORT_BRIO_02.md).
local Fixtures = require("../fixtures/Fixtures")
local PlanarSim = require("../PlanarSim")

local DT = 1 / 240

return function(T: any, H: any)
    local SHARED = "ReplicatedStorage.Shared."
    local Definitions = H.require(SHARED .. "Vehicles.VehicleDefinitions")
    local Dynamics = H.require(SHARED .. "Vehicles.Physics.VehicleDynamics")
    local Transmission = H.require(SHARED .. "Vehicles.Physics.Transmission")
    local Data = H.require(SHARED .. "Vehicles.MeshKitData")
    local SeatPose = H.require(SHARED .. "Vehicles.SeatPose")

    -- Accélérateur constant depuis l'arrêt : palier le plus long au rupteur, passages (montées et descentes).
    local function constantThrottle(definition: any, throttle: number, duration: number): (number, { any }, number)
        local limiter = definition.Powertrain.Engine.LimiterRpm
        local plateau, longest, last, shifts, downs = 0, 0, 0, {}, 0
        PlanarSim.run(Dynamics, definition, {
            Dt = DT,
            Duration = duration,
            Input = function(t: number, snapshot: any, state: any)
                if state.Gear ~= last then
                    if state.Gear < last and state.Gear > 0 then
                        downs += 1
                    end
                    table.insert(shifts, { From = last, To = state.Gear, Kmh = snapshot.Forward * 3.6 })
                    last = state.Gear
                end
                if state.EngineRpm >= limiter - 50 then
                    plateau += DT
                    longest = math.max(longest, plateau)
                else
                    plateau = 0
                end
                return {
                    Throttle = if t > 0.5 then throttle else 0,
                    Brake = 0,
                    Steer = 0,
                    Handbrake = false,
                    Clutch = 0,
                }
            end,
            Stop = function()
                return false
            end,
        })
        return longest, shifts, downs
    end

    T.suite("BRIO-02 — boîte automatique (rupteur) et assise de la Brio")

    T.test("1. pied au plancher : plus aucun palier au rupteur > 0,1 s, montées 1→2→3→4 dans l'ordre", function()
        local brio = Definitions.get("wk_brio")
        local longest, shifts, downs = constantThrottle(brio, 1, 25)
        T.truthy(longest <= 0.1, string.format("palier au rupteur %.3f s", longest))
        T.equal(downs, 0, "aucun rétrogradage à accélérateur constant")
        local gears = {}
        for _, shift in shifts do
            table.insert(gears, shift.To)
        end
        T.equal(table.concat(gears, ","), "1,2,3,4", "suite des rapports")
        for i = 3, #shifts do
            T.truthy(shifts[i].Kmh > shifts[i - 1].Kmh, "montées à vitesse croissante")
        end
    end)

    T.test("2. accélérateur partiel constant : ni pompage ni rupteur (0,3 à 0,85)", function()
        local brio = Definitions.get("wk_brio")
        for _, throttle in { 0.3, 0.5, 0.7, 0.85 } do
            local longest, _, downs = constantThrottle(brio, throttle, 30)
            T.equal(downs, 0, string.format("gaz %.2f : aucun rétrogradage", throttle))
            T.truthy(longest == 0, string.format("gaz %.2f : rupteur jamais atteint (%.3f s)", throttle, longest))
        end
    end)

    T.test("3. montée sur le régime moteur réservée à l'automatique ; garde anti-pompage", function()
        local brio = Definitions.get("wk_brio")
        local transmission = brio.Powertrain.Transmission
        local input = { Throttle = 1, Brake = 0, Steer = 0, Handbrake = false, Clutch = 0 }
        local overall = transmission.ForwardRatios[1] * transmission.FinalDrive
        local function state(gear: number, engineRpm: number): any
            local s = Dynamics.createState(brio)
            s.Gear, s.ShiftTimer, s.EngineOmega = gear, 0, engineRpm * math.pi / 30
            return s
        end
        local function wheelOmega(turbineRpm: number): number
            return turbineRpm * math.pi / 30 / overall
        end
        -- Turbine à 6 000 (sous 6 800), moteur à 6 900 : montée.
        local s = state(1, 6900)
        Transmission.update(s, brio.Powertrain, input, 10, wheelOmega(6000), DT)
        T.equal(s.Gear, 2, "moteur au-dessus du seuil : montée")
        -- Moteur sous le seuil : pas de montée.
        s = state(1, 6700)
        Transmission.update(s, brio.Powertrain, input, 10, wheelOmega(6000), DT)
        T.equal(s.Gear, 1, "moteur sous le seuil : pas de montée")
        -- Garde : régime côté roues trop bas pour le rapport suivant (moteur emballé, roues lentes) → pas de montée.
        local low = transmission.ShiftDownRpm
            * Transmission.EngineUpshiftDownMargin
            / (transmission.ForwardRatios[2] / transmission.ForwardRatios[1])
        s = state(1, 7000)
        Transmission.update(s, brio.Powertrain, input, 5, wheelOmega(low * 0.95), DT)
        T.equal(s.Gear, 1, "garde anti-pompage")
        -- Double embrayage (jeu d'essai) : la règle sur le régime moteur ne s'applique pas.
        local dct = Fixtures.get("proto_p01_dct")
        local d = Dynamics.createState(dct)
        d.Gear, d.ShiftTimer, d.EngineOmega = 1, 0, 7000 * math.pi / 30
        local dctOverall = dct.Powertrain.Transmission.ForwardRatios[1] * dct.Powertrain.Transmission.FinalDrive
        Transmission.update(d, dct.Powertrain, input, 10, 5000 * math.pi / 30 / dctOverall, DT)
        T.equal(d.Gear, 1, "double embrayage : décision sur le régime côté roues seulement")
    end)

    T.test("4. Brio : définition inchangée et valide (hystérésis garantie par la validation)", function()
        local brio = Definitions.get("wk_brio")
        local ok, errors = Definitions.validate(brio)
        T.truthy(ok, table.concat(errors, " ; "))
        T.equal(brio.Powertrain.Transmission.ShiftUpRpm, 6800)
        T.equal(brio.Powertrain.Transmission.ShiftDownRpm, 2856)
    end)

    T.test("5. assise posée sur le coussin mesuré, pieds et têtes dans l'habitacle mesuré", function()
        local kit = Data.Kits.wk_brio
        -- Dessus d'assise = centre du Seat + 0,2 (relevé Blender du 2026-11-06 en z 0,75).
        T.near(kit.SeatDriver.Y + 0.2, -0.353, 0.005, "coussin conducteur")
        T.near(kit.SeatPassenger.Y + 0.2, -0.368, 0.005, "coussin passager")
        T.equal(kit.SeatDriver.Z, kit.SeatPassenger.Z)
        T.equal(kit.SeatDriver.X, -kit.SeatPassenger.X)
        for _, seat in { kit.SeatDriver, kit.SeatPassenger } do
            local top = seat.Y + 0.2
            -- Plancher des pieds 0,5 st sous l'assise ; pavillon au moins 3,4 st au-dessus (Comète : 3,34).
            T.truthy(top - kit.Footwell.FloorY > 0.45 and top - kit.Footwell.FloorY < 0.6, "plancher sous l'assise")
            T.truthy(
                kit.RoofUnderside - top >= 3.4,
                string.format("hauteur sous pavillon %.2f", kit.RoofUnderside - top)
            )
        end
        T.truthy(kit.Footwell.FrontZ < kit.Footwell.RearZ and kit.Footwell.RearZ < kit.SeatDriver.Z, "pieds devant")
        -- Vue cockpit inchangée (décision du propriétaire), toujours sous le pavillon.
        T.truthy(kit.CameraCockpit.Y < kit.RoofUnderside - 0.5, "yeux de la vue cockpit sous le pavillon")
    end)

    T.test("6. pose Citadine : dérivée de la pose Sportive mesurée, bassin plus bas, genoux moins tendus", function()
        local kit = Data.Kits.wk_brio
        T.equal(kit.SeatPoses.Driver, "Citadine")
        T.equal(kit.SeatPoses.Passenger, "CitadinePassager")
        local drive, ride = SeatPose.poseFor("Citadine"), SeatPose.poseFor("CitadinePassager")
        local sport = SeatPose.poseFor("Sportive")
        T.truthy(drive ~= nil and ride ~= nil and sport ~= nil, "poses présentes")
        T.truthy((drive :: any).LeftShoulder ~= nil, "conducteur : bras vers le volant")
        T.truthy((ride :: any).LeftShoulder == nil, "passager : bras libres")
        T.truthy((drive :: any).Root.Down > (sport :: any).Root.Down, "bassin plus enfoncé")
        T.truthy((drive :: any).LeftKnee.Pitch < (sport :: any).LeftKnee.Pitch, "genoux moins tendus")
        T.equal((drive :: any).Waist.Pitch, (sport :: any).Waist.Pitch, "buste mesuré conservé")
        T.equal((drive :: any).LeftKnee.Pitch, (drive :: any).RightKnee.Pitch, "symétrie")
        -- La Comète garde sa pose (aucun effet de bord).
        T.equal(Data.Kits.wk_comete.SeatPoses.Driver, "Sportive")
    end)
end
