--!strict
local Fixtures = require("../fixtures/Fixtures")
-- Lot 0.2 — motorisations et boîtes de vitesses (modules purs, banc planaire).
-- Les chiffres notés sont des sorties du modèle hors Roblox, PAS des mesures en jeu.

local PlanarSim = require("../PlanarSim")

local DT = 1 / 60

local function input(throttle: number, brake: number, steer: number, handbrake: boolean?, clutch: number?)
    return { Throttle = throttle, Brake = brake, Steer = steer, Handbrake = handbrake == true, Clutch = clutch or 0 }
end

return function(T: any, H: any)
    local Dynamics = H.require("ReplicatedStorage.Shared.Vehicles.Physics.VehicleDynamics")
    local Engine = H.require("ReplicatedStorage.Shared.Vehicles.Physics.Engine")
    local Transmission = H.require("ReplicatedStorage.Shared.Vehicles.Physics.Transmission")
    local Definitions = H.require("ReplicatedStorage.Shared.Vehicles.VehicleDefinitions")
    local P01 = Fixtures.get("proto_p01")
    local P02 = Fixtures.get("proto_p02")
    local P03 = Fixtures.get("proto_p03")
    local DCT = Fixtures.get("proto_p01_dct")
    local SEQ = Fixtures.get("proto_p01_seq")
    local CVT = Fixtures.get("proto_p01_cvt")

    -- Pilote « conducteur » des boîtes à sélecteur : passe au rapport supérieur
    -- au régime donné ; pour la manuelle, embrayage enfoncé puis relâché en 0,6 s.
    local function shifter(definition: any, upRpm: number)
        local clutch, pending = 0, false
        local manual = definition.Powertrain.Transmission.Kind == "Manual"
        local top = #definition.Powertrain.Transmission.ForwardRatios
        return function(throttle: number, s: any, state: any): any
            local wantUp = state.Gear == 0 or (state.EngineRpm > upRpm and state.Gear < top)
            if not manual then
                -- Double embrayage : laissé en mode automatique (« accélérer » engage le 1er).
                if wantUp and definition.Powertrain.Transmission.Kind == "Sequential" then
                    Dynamics.requestShift(state, definition, 1, s.Forward)
                end
                return input(throttle, 0, 0)
            end
            if wantUp and clutch <= 0 and not pending then
                clutch = 0.01
            end
            if clutch > 0 and not pending and state.ClutchPedal >= 0.8 then
                T.equal(Dynamics.requestShift(state, definition, 1, s.Forward), "Ok", "passage embrayage enfoncé")
                pending = true
            end
            if pending then
                clutch = math.max(0, clutch - DT / 0.6)
                if clutch <= 0 then
                    pending = false
                end
            elseif clutch > 0 then
                clutch = math.min(1, clutch + DT / 0.1)
            end
            return input(throttle, 0, 0, false, clutch)
        end
    end

    local function launch(definition: any, upRpm: number, duration: number?): (number?, { any }, any)
        local drive = shifter(definition, upRpm)
        local reached: number? = nil
        local snaps, state = PlanarSim.run(Dynamics, definition, {
            Dt = DT,
            Duration = duration or 30,
            Input = function(_, s, state)
                return drive(1, s, state)
            end,
            Stop = function(s)
                if reached == nil and s.Forward * 3.6 >= 100 then
                    reached = s.Time
                    return duration == nil
                end
                return false
            end,
        })
        return reached, snaps, state
    end

    T.suite("Lot 0.2 — moteurs thermiques")

    T.test("ralenti régulé au neutre, sans dérive", function()
        local snaps = PlanarSim.run(Dynamics, P01, {
            Dt = DT,
            Duration = 4,
            Input = function()
                return input(0, 0, 0, true)
            end,
        })
        T.between(
            snaps[#snaps].Rpm,
            P01.Powertrain.Engine.IdleRpm * 0.95,
            P01.Powertrain.Engine.IdleRpm * 1.06,
            "régime de ralenti"
        )
    end)

    T.test("rupteur : au neutre, pleine charge, le régime plafonne au rupteur", function()
        local state = Dynamics.createState(P02)
        Dynamics.startEngine(state, P02)
        local peak = 0
        for _ = 1, 240 do
            local contacts = {}
            for i = 1, 4 do
                contacts[i] = {
                    Grounded = true,
                    Compression = 0.1,
                    CompressionVelocity = 0,
                    LongitudinalVelocity = 0,
                    LateralVelocity = 0,
                    SurfaceFriction = 1,
                    Wet = false,
                }
            end
            Dynamics.step(state, P02, input(1, 0, 0, true), contacts, { Forward = 0, Lateral = 0, YawRate = 0 }, DT)
            peak = math.max(peak, state.EngineRpm)
        end
        T.truthy(peak <= P02.Powertrain.Engine.LimiterRpm * 1.03, string.format("régime max %.0f", peak))
        T.truthy(peak >= P02.Powertrain.Engine.RedlineRpm, "atteint la zone rouge")
    end)

    T.test("diesel : plus de couple à bas régime, plage plus courte, consommation spécifique plus faible", function()
        local petrol, diesel = P01.Powertrain.Engine, P02.Powertrain.Engine
        T.truthy(Engine.sampleTorque(diesel.TorqueCurve, 1500) > 1.5 * Engine.sampleTorque(petrol.TorqueCurve, 1500))
        T.truthy(diesel.RedlineRpm < petrol.RedlineRpm * 0.7)
        -- Même puissance mécanique (40 kW) à charge comparable : moins de litres pour le diesel.
        local omegaP, omegaD = Engine.omega(4000), Engine.omega(2500)
        local petrolFlow = Engine.fuelFlowLps(petrol, "Petrol", omegaP, 40000 / omegaP, 0.6, true)
        local dieselFlow = Engine.fuelFlowLps(diesel, "Diesel", omegaD, 40000 / omegaD, 0.6, true)
        T.truthy(dieselFlow < petrolFlow, string.format("%.2f L/h < %.2f L/h", dieselFlow * 3600, petrolFlow * 3600))
        T.note(
            string.format(
                "Débit à 40 kW : essence (P-01, 4000 tr/min) %.1f L/h ; diesel (P-02, 2500 tr/min) %.1f L/h",
                petrolFlow * 3600,
                dieselFlow * 3600
            )
        )
    end)

    T.test("consommation : ralenti, charge et régime ; coupure en décélération", function()
        local engine = P01.Powertrain.Engine
        -- Au ralenti stabilisé, le couple net est nul (la régulation compense les frottements).
        local idle = Engine.fuelFlowLps(engine, "Petrol", Engine.omega(engine.IdleRpm), 0, 0, true)
        T.near(idle * 3600, engine.IdleFuelLph, 0.05, "débit de ralenti")
        local light = Engine.fuelFlowLps(engine, "Petrol", Engine.omega(3000), 60, 0.3, true)
        local heavy = Engine.fuelFlowLps(engine, "Petrol", Engine.omega(3000), 180, 0.9, true)
        local revving = Engine.fuelFlowLps(engine, "Petrol", Engine.omega(6000), 60, 0.3, true)
        T.truthy(heavy > light, "plus de charge → plus de carburant")
        T.truthy(revving > light, "plus de régime → plus de carburant")
        T.equal(Engine.fuelFlowLps(engine, "Petrol", Engine.omega(3000), -30, 0, true), 0, "coupure en décélération")
        T.equal(Engine.fuelFlowLps(engine, "Petrol", Engine.omega(3000), 100, 0.5, false), 0, "moteur arrêté")
        -- Consommation spécifique dégradée à faible charge.
        local lowLoad = (light - Engine.fuelFlowLps(engine, "Petrol", Engine.omega(3000), 0.01, 0.3, true))
            / (60 * Engine.omega(3000) / 1000)
        local highLoad = (heavy - Engine.fuelFlowLps(engine, "Petrol", Engine.omega(3000), 0.01, 0.9, true))
            / (180 * Engine.omega(3000) / 1000)
        T.truthy(lowLoad > highLoad, "rendement meilleur à forte charge")
    end)

    T.test("frein moteur : en roue libre embrayée, ralentit plus qu'au neutre", function()
        local function coast(neutral: boolean): number
            local snaps = PlanarSim.run(Dynamics, P02, {
                Dt = DT,
                Duration = 5,
                InitialForward = 60 / 3.6,
                Prepare = function(state)
                    state.Gear = if neutral then 0 else 3
                    state.Coupled = not neutral
                    state.EngineOmega = Engine.omega(2500)
                end,
                Input = function()
                    return input(0, 0, 0)
                end,
            })
            return snaps[#snaps].Forward
        end
        local inGear, inNeutral = coast(false), coast(true)
        T.truthy(inGear < inNeutral - 0.5, string.format("%.1f < %.1f m/s", inGear, inNeutral))
    end)

    T.suite("Lot 0.2 — moteur électrique")

    T.test("couple constant puis puissance constante, nul au régime maximal", function()
        local motor = P03.Powertrain.Motor
        T.near(Engine.motorMaxTorque(motor, Engine.omega(1000)), motor.MaxTorqueNm, 1e-9)
        local high = Engine.omega(10000)
        T.near(Engine.motorMaxTorque(motor, high) * high, motor.MaxPowerKw * 1000, 1, "puissance plafonnée")
        T.equal(Engine.motorMaxTorque(motor, Engine.omega(motor.MaxRpm)), 0)
    end)

    T.test("vitesse limitée électroniquement, accélération vive", function()
        local reached, snaps = launch(P03, 0, 60)
        local top = 0
        for _, s in snaps do
            top = math.max(top, s.Forward * 3.6)
        end
        T.truthy(reached ~= nil and (reached :: number) < 7.5, "0–100 km/h en moins de 7,5 s")
        T.truthy(top <= P03.Powertrain.Motor.TopSpeedKmh + 1.5, string.format("vitesse max %.1f km/h", top))
        T.truthy(top >= P03.Powertrain.Motor.TopSpeedKmh - 8, "proche de la limitation")
        T.note(
            string.format(
                "P-03 : 0–100 km/h %.2f s ; vitesse max %.0f km/h (limitée à %d)",
                reached or -1,
                top,
                P03.Powertrain.Motor.TopSpeedKmh
            )
        )
    end)

    local function coastFrom100(level: number): (number, any)
        local snaps, state = PlanarSim.run(Dynamics, P03, {
            Dt = DT,
            Duration = 6,
            InitialForward = 100 / 3.6,
            Prepare = function(state)
                state.RegenLevel = level
            end,
            Input = function()
                return input(0, 0, 0)
            end,
        })
        return snaps[#snaps].Forward * 3.6, state
    end

    T.test("récupération au lâcher configurable : niveau fort, modéré, nul", function()
        local levels = P03.Powertrain.Motor.RegenLevels
        local strongest, weakest = 1, 1
        for index, value in levels do
            if value > levels[strongest] then
                strongest = index
            end
            if value < levels[weakest] then
                weakest = index
            end
        end
        local vStrong, sStrong = coastFrom100(strongest)
        local vDefault, sDefault = coastFrom100(1)
        local vNone, sNone = coastFrom100(weakest)
        T.truthy(
            vStrong < vDefault and vDefault < vNone,
            string.format("%.1f < %.1f < %.1f km/h", vStrong, vDefault, vNone)
        )
        T.truthy(sStrong.EnergyRecovered > sDefault.EnergyRecovered, "plus d'énergie récupérée au niveau fort")
        T.equal(sNone.EnergyRecovered, 0, "aucune récupération au niveau nul")
        T.note(
            string.format(
                "P-03 lâcher 6 s depuis 100 km/h : %.0f / %.0f / %.0f km/h (fort / défaut / nul), récupéré %.3f kWh au niveau fort",
                vStrong,
                vDefault,
                vNone,
                sStrong.EnergyRecovered
            )
        )
    end)

    T.test("freinage combiné : récupère de l'énergie sans allonger le freinage", function()
        local function brake(regen: boolean): (number, any)
            local snaps, state = PlanarSim.run(Dynamics, P03, {
                Dt = DT,
                Duration = 10,
                InitialForward = 100 / 3.6,
                Prepare = function(state)
                    if not regen then
                        state.EnergyAvailable = false
                    end
                end,
                Input = function()
                    return input(0, 0.5, 0)
                end,
                Stop = function(s)
                    return s.Forward < 0.3
                end,
            })
            return snaps[#snaps].Distance, state
        end
        local withRegen, state = brake(true)
        local friction = brake(false)
        T.truthy(state.EnergyRecovered > 0.02, string.format("%.3f kWh récupérés", state.EnergyRecovered))
        T.truthy(withRegen <= friction * 1.1, string.format("%.1f m ≤ 1,1 × %.1f m", withRegen, friction))
    end)

    T.test("batterie vide : ni traction ni récupération", function()
        local snaps, state = PlanarSim.run(Dynamics, P03, {
            Dt = DT,
            Duration = 3,
            Prepare = function(state)
                state.EnergyAvailable = false
            end,
            Input = function()
                return input(1, 0, 0)
            end,
        })
        T.near(snaps[#snaps].Forward, 0, 1e-6, "immobile malgré l'accélérateur")
        T.equal(state.EnergyRecovered, 0)
        T.equal(state.EngineRunning, false)
    end)

    T.suite("Lot 0.2 — boîtes de vitesses")

    T.test("automatique : convertisseur (calage, rampement) puis pontage", function()
        -- Calage : pleine charge, frein et frein à main serrés, véhicule immobile.
        local stallSnaps, stallState = PlanarSim.run(Dynamics, P01, {
            Dt = DT,
            Duration = 3,
            Prepare = function(state)
                state.Gear = 1
            end,
            Input = function()
                return input(1, 1, 0, true)
            end,
        })
        T.near(stallSnaps[#stallSnaps].Distance, 0, 0.05, "véhicule retenu")
        local stallRpm = P01.Powertrain.Transmission.Converter.StallRpm
        T.between(stallState.EngineRpm, stallRpm * 0.85, stallRpm * 1.15, "régime de calage du convertisseur")
        -- Rampement en D, frein relâché.
        local creep = PlanarSim.run(Dynamics, P01, {
            Dt = DT,
            Duration = 6,
            Prepare = function(state)
                state.Gear = 1
            end,
            Input = function()
                return input(0, 0, 0)
            end,
        })
        local creepKmh = creep[#creep].Forward * 3.6
        T.between(creepKmh, 1, 12, "rampement")
        -- Pontage à vitesse stabilisée sur un rapport long.
        local _, cruise = PlanarSim.run(Dynamics, P01, {
            Dt = DT,
            Duration = 8,
            InitialForward = 90 / 3.6,
            Prepare = function(state)
                state.Gear = 4
                state.EngineOmega = Engine.omega(2700)
            end,
            Input = function()
                return input(0.25, 0, 0)
            end,
        })
        T.truthy(cruise.Coupled, "pontage fermé à 90 km/h")
        T.truthy(cruise.Gear >= P01.Powertrain.Transmission.Converter.LockupGear)
        T.note(
            string.format(
                "P-01 : calage du convertisseur %.0f tr/min ; rampement %.1f km/h",
                stallState.EngineRpm,
                creepKmh
            )
        )
    end)

    T.test("automatique : passages montants jusqu'au rapport le plus long", function()
        local _, snaps = launch(P01, 0, 40)
        local maxGear = 0
        for _, s in snaps do
            maxGear = math.max(maxGear, s.Gear)
        end
        T.truthy(maxGear >= 5, "rapport " .. maxGear)
    end)

    T.test("manuelle : passage refusé sans embrayage, accepté embrayage enfoncé", function()
        local state = Dynamics.createState(P02)
        Dynamics.startEngine(state, P02)
        T.equal(Dynamics.requestShift(state, P02, 1, 0), "ClutchRequired")
        T.equal(state.Gear, 0)
        state.ClutchPedal = 1
        T.equal(Dynamics.requestShift(state, P02, 1, 0), "Ok")
        T.equal(state.Gear, 1)
    end)

    T.test(
        "manuelle : le moteur cale si l'on lâche l'embrayage sans accélérer, relance embrayage enfoncé",
        function()
            local clutch = 1
            local stalledAt: number? = nil
            local _, state = PlanarSim.run(Dynamics, P02, {
                Dt = DT,
                Duration = 4,
                Prepare = function(state)
                    state.ClutchPedal = 1
                    Dynamics.requestShift(state, P02, 1, 0)
                end,
                Input = function(t, _, state)
                    if state.EngineStalled and stalledAt == nil then
                        stalledAt = t
                    end
                    -- Pédale lâchée d'un coup à 0,5 s, puis renfoncée 1 s après le calage.
                    clutch = if t < 0.5 then 1 elseif stalledAt and t > (stalledAt :: number) + 1 then 1 else 0
                    return input(0, 0, 0, false, clutch)
                end,
            })
            T.truthy(stalledAt ~= nil, "moteur calé")
            T.truthy(state.EngineRunning and not state.EngineStalled, "relancé au démarreur, embrayage enfoncé")
        end
    )

    T.test("manuelle : démarrage progressif sans caler, puis montée des six rapports", function()
        local reached, snaps, state = launch(P02, 4000, 40)
        local maxGear = 0
        for _, s in snaps do
            maxGear = math.max(maxGear, s.Gear)
        end
        T.truthy(not state.EngineStalled, "pas de calage")
        T.equal(maxGear, 6)
        T.truthy(reached ~= nil, "100 km/h atteints")
        T.note(
            string.format("P-02 (diesel, manuelle, traction) : 0–100 km/h %.2f s (conducteur simulé)", reached or -1)
        )
    end)

    T.test("marche arrière par sélecteur : à l'arrêt seulement, depuis le neutre (A3)", function()
        for _, definition in { P02, DCT, SEQ } do
            local state = Dynamics.createState(definition)
            Dynamics.startEngine(state, definition)
            state.ClutchPedal = 1
            T.equal(Dynamics.requestShift(state, definition, -1, 5), "StopRequired", definition.Id .. " en roulant")
            T.equal(Dynamics.requestShift(state, definition, -1, 0), "Ok", definition.Id .. " à l'arrêt")
            T.equal(state.Gear, -1)
            T.equal(Dynamics.requestShift(state, definition, -1, 0), "Limit")
        end
        -- Recul effectif à l'accélérateur en marche arrière (séquentielle).
        local snaps = PlanarSim.run(Dynamics, SEQ, {
            Dt = DT,
            Duration = 3,
            Prepare = function(state)
                state.Gear = -1
            end,
            Input = function()
                return input(0.4, 0, 0)
            end,
        })
        T.truthy(snaps[#snaps].Forward < -1, "recule")
    end)

    T.test("double embrayage : passages automatiques rapides et palettes protégées du surrégime", function()
        local reached, snaps = launch(DCT, 99999, 40)
        local maxGear, gearChanges, previous = 0, 0, 0
        for _, s in snaps do
            maxGear = math.max(maxGear, s.Gear)
            if s.Gear ~= previous then
                gearChanges += 1
                previous = s.Gear
            end
        end
        T.truthy(maxGear >= 6, "rapport " .. maxGear)
        T.truthy(
            reached ~= nil and (reached :: number) < (launch(P01, 0) :: number),
            "plus rapide que l'automatique à convertisseur"
        )
        -- Rétrogradation demandée à 150 km/h vers le 1er : refusée (rupteur).
        local state = Dynamics.createState(DCT)
        state.Gear = 2
        for _, wheel in state.Wheels do
            wheel.AngularVelocity = 150 / 3.6 / DCT.Tires.RadiusM
        end
        T.equal(Dynamics.requestShift(state, DCT, -1, 150 / 3.6), "OverRev")
        T.equal(state.Gear, 2)
        -- Une palette suspend la logique automatique pendant quelques secondes.
        state.Gear = 3
        T.equal(Dynamics.requestShift(state, DCT, 1, 150 / 3.6), "Ok")
        T.truthy(state.ManualHoldTimer > 0, "priorité au conducteur")
        T.equal(state.ShiftTimer, DCT.Powertrain.Transmission.ShiftDurationS, "coupure brève")
        T.note(string.format("P-01 DCT : 0–100 km/h %.2f s", reached or -1))
    end)

    T.test("séquentielle : aucun passage automatique, rapport par rapport", function()
        local snaps = PlanarSim.run(Dynamics, SEQ, {
            Dt = DT,
            Duration = 8,
            Prepare = function(state)
                Dynamics.requestShift(state, SEQ, 1, 0)
            end,
            Input = function()
                return input(1, 0, 0)
            end,
        })
        for _, s in snaps do
            T.equal(s.Gear, 1, "reste en 1re au rupteur")
        end
        T.truthy(snaps[#snaps].Rpm <= SEQ.Powertrain.Engine.LimiterRpm * 1.03, "plafonne au rupteur")
        local reached = launch(SEQ, 6800)
        T.truthy(reached ~= nil, "100 km/h atteints en montant les rapports")
    end)

    T.test("CVT : rapport continu, régime moteur maintenu près de la puissance à pleine charge", function()
        local ratios, rpms = {}, {}
        local snaps, state = PlanarSim.run(Dynamics, CVT, {
            Dt = DT,
            Duration = 14,
            Input = function(t, _, state)
                if t > 3 then
                    table.insert(ratios, state.CvtRatio)
                    table.insert(rpms, state.EngineRpm)
                end
                return input(1, 0, 0)
            end,
        })
        local distinct, minRpm, maxRpm = {}, math.huge, 0
        for i, ratio in ratios do
            distinct[math.floor(ratio * 100)] = true
            minRpm = math.min(minRpm, rpms[i])
            maxRpm = math.max(maxRpm, rpms[i])
        end
        local count = 0
        for _ in distinct do
            count += 1
        end
        local transmission = CVT.Powertrain.Transmission
        T.truthy(count > 20, "rapport qui varie continûment (" .. count .. " valeurs)")
        T.truthy(state.CvtRatio < transmission.ForwardRatios[1] and state.CvtRatio >= transmission.ForwardRatios[2])
        T.between(
            minRpm,
            transmission.Cvt.PowerRpm * 0.85,
            transmission.Cvt.PowerRpm * 1.15,
            "régime mini à pleine charge"
        )
        T.between(maxRpm, transmission.Cvt.PowerRpm * 0.85, CVT.Powertrain.Engine.LimiterRpm, "régime maxi")
        T.truthy(snaps[#snaps].Forward * 3.6 > 120, "accélère")
    end)

    T.test("rapport unique : un seul rapport, marche arrière par maintien du frein (A3)", function()
        local state = Dynamics.createState(P03)
        T.equal(Transmission.forwardGearCount(P03.Powertrain.Transmission), 1)
        T.equal(Dynamics.requestShift(state, P03, 1, 0), "NotAvailable")
        local snaps = PlanarSim.run(Dynamics, P03, {
            Dt = DT,
            Duration = 3,
            Input = function()
                return input(0, 1, 0)
            end,
        })
        T.truthy(snaps[#snaps].Forward < -0.5, "recule après maintien de « freiner »")
    end)

    T.test("les six boîtes atteignent 100 km/h sans valeur non finie", function()
        local summary = {}
        for _, case in
            {
                { P01, 0 },
                { P02, 4000 },
                { P03, 0 },
                { DCT, 99999 },
                { SEQ, 6800 },
                { CVT, 0 },
            }
        do
            local definition, upRpm = case[1], case[2]
            local reached, snaps = launch(definition, upRpm)
            T.truthy(reached ~= nil, definition.Id)
            for _, s in snaps do
                T.truthy(s.Forward == s.Forward and s.Rpm == s.Rpm, "valeurs finies " .. definition.Id)
            end
            table.insert(summary, string.format("%s %.2f s", definition.Powertrain.Transmission.Kind, reached or -1))
        end
        T.note("0–100 km/h par boîte (modèle) : " .. table.concat(summary, " ; "))
    end)
end
