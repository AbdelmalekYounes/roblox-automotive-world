--!strict
-- Lot 0.2 — aides électroniques, énergie (autorité serveur) et dégâts.
-- Modules purs ; banc planaire hors Roblox (sorties du modèle, pas des mesures en jeu).

local PlanarSim = require("../PlanarSim")

local DT = 1 / 60

local function input(throttle: number, brake: number, steer: number, handbrake: boolean?)
    return { Throttle = throttle, Brake = brake, Steer = steer, Handbrake = handbrake == true, Clutch = 0 }
end

return function(T: any, H: any)
    local Dynamics = H.require("ReplicatedStorage.Shared.Vehicles.Physics.VehicleDynamics")
    local DriverAids = H.require("ReplicatedStorage.Shared.Vehicles.Physics.DriverAids")
    local EnergyModel = H.require("ReplicatedStorage.Shared.Vehicles.Physics.EnergyModel")
    local DamageModel = H.require("ReplicatedStorage.Shared.Vehicles.Physics.DamageModel")
    local InputCodec = H.require("ReplicatedStorage.Shared.Vehicles.InputCodec")
    local Definitions = H.require("ReplicatedStorage.Shared.Vehicles.VehicleDefinitions")
    local P01 = Definitions.get("proto_p01")
    local P02 = Definitions.get("proto_p02")
    local P03 = Definitions.get("proto_p03")

    T.suite("Lot 0.2 — aides électroniques")

    T.test("aides désactivées par défaut, quel que soit l'équipement", function()
        for _, definition in Definitions.all() do
            local state = Dynamics.createState(definition)
            T.equal(state.Aids.Abs, false, definition.Id)
            T.equal(state.Aids.TractionControl, false, definition.Id)
            T.equal(state.Aids.StabilityControl, false, definition.Id)
        end
    end)

    T.test("une aide absente du modèle n'agit jamais, même « activée »", function()
        local state = Dynamics.createState(P01)
        state.Aids.Abs = true
        state.Aids.TractionControl = true
        state.Aids.StabilityControl = true
        T.equal(DriverAids.isEnabled(P01, state, "Abs"), false)
        T.equal(DriverAids.isEnabled(P01, state, "TractionControl"), false)
        T.equal(DriverAids.isEnabled(P01, state, "StabilityControl"), false)
        T.equal(DriverAids.isEnabled(P02, state, "StabilityControl"), false, "P-02 sans ESP")
    end)

    local function brakeTest(definition: any, abs: boolean, steer: number): (number, number, number)
        local lockedFrames, frames, heading = 0, 0, 0
        local snaps = PlanarSim.run(Dynamics, definition, {
            Dt = DT,
            Duration = 12,
            InitialForward = 100 / 3.6,
            -- Revêtement moyen (μ 0,6) : au sec, les freins avant du P-02 restent
            -- juste sous la limite d'adhérence et ne bloquent pas.
            Surface = 0.6,
            Prepare = function(state)
                state.Aids.Abs = abs
                state.Gear = 4
            end,
            Input = function(_, s, state)
                if s.Forward > 3 then
                    frames += 1
                    if state.Wheels[1].SlipRatio < -0.5 then
                        lockedFrames += 1
                    end
                end
                heading = s.Heading
                return input(0, 1, steer)
            end,
            Stop = function(s)
                return s.Forward < 0.3
            end,
        })
        return snaps[#snaps].Distance, lockedFrames / math.max(frames, 1), heading
    end

    T.test("ABS : roues avant non bloquées et véhicule dirigeable au freinage, sans adhérence ajoutée", function()
        local distOff, lockOff, headingOff = brakeTest(P02, false, 0.5)
        local distOn, lockOn, headingOn = brakeTest(P02, true, 0.5)
        T.truthy(lockOff > 0.5, string.format("sans ABS : roue avant bloquée %.0f %% du temps", lockOff * 100))
        T.truthy(lockOn < 0.1, string.format("avec ABS : %.0f %%", lockOn * 100))
        T.truthy(math.abs(headingOn) > math.abs(headingOff) + 0.2, "le véhicule tourne en freinant avec l'ABS")
        -- Pas d'adhérence créée : jamais mieux que le pic d'adhérence du pneu.
        local muPeak = P02.Tires.PeakFrictionLongitudinal * 0.6
        local bestPossible = (100 / 3.6) ^ 2 / (2 * muPeak * 1.25 * 9.81)
        T.truthy(distOn > bestPossible, string.format("%.1f m > borne physique %.1f m", distOn, bestPossible))
        T.note(
            string.format(
                "P-02, 100–0 km/h en braquant : sans ABS %.1f m (cap %.0f°), avec ABS %.1f m (cap %.0f°)",
                distOff,
                math.deg(headingOff),
                distOn,
                math.deg(headingOn)
            )
        )
    end)

    T.test("antipatinage : patinage limité sur faible adhérence, accélération bornée par l'adhérence", function()
        local function launch(tc: boolean): (number, number)
            local peakSlip, slipSum, count = 0, 0, 0
            local snaps = PlanarSim.run(Dynamics, P02, {
                Dt = DT,
                Duration = 6,
                Surface = 0.3,
                Prepare = function(state)
                    state.Aids.TractionControl = tc
                    state.ClutchPedal = 1
                    Dynamics.requestShift(state, P02, 1, 0)
                end,
                Input = function(t, _, state)
                    if t > 1.5 then
                        peakSlip = math.max(peakSlip, state.Wheels[1].SlipRatio)
                        slipSum += state.Wheels[1].SlipRatio
                        count += 1
                    end
                    -- Embrayage relâché sur 0,6 s.
                    return {
                        Throttle = 1,
                        Brake = 0,
                        Steer = 0,
                        Handbrake = false,
                        Clutch = math.max(0, 1 - t / 0.6),
                    }
                end,
            })
            return slipSum / math.max(count, 1), snaps[#snaps].Forward
        end
        local slipOff, speedOff = launch(false)
        local slipOn, speedOn = launch(true)
        T.truthy(slipOn < slipOff * 0.6, string.format("glissement moyen %.2f < 0,6 × %.2f", slipOn, slipOff))
        T.truthy(speedOn <= 0.3 * 1.25 * 9.81 * 6, "accélération bornée par l'adhérence")
        T.note(
            string.format(
                "P-02 sur μ 0,3, pleine charge : glissement moyen AV %.2f (sans) / %.2f (avec antipatinage), vitesse à 6 s %.1f / %.1f km/h",
                slipOff,
                slipOn,
                speedOff * 3.6,
                speedOn * 3.6
            )
        )
    end)

    T.test("ESP : réduit la dérive en survirage provoqué", function()
        local function slide(esc: boolean): number
            local peakBeta = 0
            PlanarSim.run(Dynamics, P03, {
                Dt = DT,
                Duration = 5,
                InitialForward = 90 / 3.6,
                Surface = 0.6,
                Prepare = function(state)
                    state.Aids.StabilityControl = esc
                end,
                Input = function(t, s)
                    peakBeta = math.max(peakBeta, math.abs(math.atan2(s.Lateral, math.max(s.Forward, 1))))
                    -- Coup de volant avec frein à main bref : l'arrière décroche.
                    if t < 0.6 then
                        return input(0.3, 0, 0.8, t > 0.2 and t < 0.5)
                    end
                    return input(0.2, 0, 0.3)
                end,
            })
            return peakBeta
        end
        local off, on = slide(false), slide(true)
        T.truthy(on < off * 0.8, string.format("dérive max %.1f° < 0,8 × %.1f°", math.deg(on), math.deg(off)))
        T.note(
            string.format(
                "P-03, survirage provoqué à 90 km/h (μ 0,6) : dérive max %.1f° sans ESP, %.1f° avec",
                math.deg(off),
                math.deg(on)
            )
        )
    end)

    T.test("ESP : pas de freinage « sous-virage » quand l'arrière glisse ou au frein à main", function()
        local state = Dynamics.createState(P03)
        state.Aids.StabilityControl = true
        -- Braquage fort à droite, lacet insuffisant : sous-virage franc.
        state.Wheels[1].SteerAngle = math.rad(10)
        state.Wheels[2].SteerAngle = math.rad(10)
        local understeer = { Forward = 20, Lateral = 0, YawRate = 0.1 }
        DriverAids.updateStability(state, P03, understeer, false)
        T.truthy(state.Wheels[4].EscBrakeTorque > 0, "roue arrière intérieure freinée")
        DriverAids.updateStability(state, P03, understeer, true)
        T.equal(state.Wheels[4].EscBrakeTorque, 0, "frein à main : pas d'intervention de sous-virage")
        local sliding = { Forward = 20, Lateral = 0.9, YawRate = 0.1 }
        DriverAids.updateStability(state, P03, sliding, false)
        T.equal(state.Wheels[4].EscBrakeTorque, 0, "arrière qui dérive : pas de freinage arrière intérieur")
    end)

    T.test("ESP : changement de file à 80 km/h sur mouillé, dérive nettement réduite", function()
        local function laneChange(esc: boolean): number
            local peak = 0
            PlanarSim.run(Dynamics, P03, {
                Dt = DT,
                Duration = 4,
                InitialForward = 80 / 3.6,
                Wet = true,
                Prepare = function(state)
                    state.Aids.StabilityControl = esc
                end,
                Input = function(t, s)
                    peak = math.max(peak, math.abs(math.atan2(s.Lateral, math.max(s.Forward, 1))))
                    local steer = if t < 0.5 then 0.8 elseif t < 1 then -0.8 else 0
                    return input(0.3, 0, steer)
                end,
            })
            return peak
        end
        local off, on = laneChange(false), laneChange(true)
        T.truthy(on < off * 0.5, string.format("%.1f° < 0,5 × %.1f°", math.deg(on), math.deg(off)))
        T.note(
            string.format(
                "P-03, changement de file à 80 km/h sur mouillé : dérive max %.1f° sans ESP, %.1f° avec",
                math.deg(off),
                math.deg(on)
            )
        )
    end)

    T.test("le filtre de braquage A1 reste indépendant des aides", function()
        local state = Dynamics.createState(P03)
        state.Aids.StabilityControl = true
        local before = Dynamics.maxSteerAngle(P03, 20)
        T.near(before, Dynamics.maxSteerAngle(P03, 20), 0, "fonction de la seule vitesse")
    end)

    T.suite("Lot 0.2 — énergie (autorité serveur)")

    T.test(
        "plancher physique : accélérer et monter coûtent, rouler en roue libre ne coûte rien (thermique)",
        function()
            local used = EnergyModel.physicsFloor(P01, 0, 20, 0, 4)
            T.truthy(used > 0, "accélération")
            local climb = EnergyModel.physicsFloor(P01, 15, 15, 1.5, 4)
            local flat = EnergyModel.physicsFloor(P01, 15, 15, 0, 4)
            T.truthy(climb > flat, "pente")
            local coast, recovered = EnergyModel.physicsFloor(P01, 20, 15, 0, 1)
            T.equal(coast, 0)
            T.equal(recovered, 0, "un moteur thermique ne récupère rien")
        end
    )

    T.test("récupération électrique bornée par l'énergie cinétique perdue et la puissance du moteur", function()
        local _, recovered = EnergyModel.physicsFloor(P03, 25, 20, 0, 1)
        local kinetic = 0.5 * P03.Chassis.MassKg * (25 ^ 2 - 20 ^ 2) / 3.6e6
        T.truthy(recovered > 0 and recovered < kinetic, "moins que l'énergie cinétique perdue")
        T.truthy(recovered <= P03.Powertrain.Motor.RegenMaxPowerKw / 3600 + 1e-9, "puissance de récupération")
    end)

    T.test("règlement : jamais sous le plancher, déclaration client bornée, aucune énergie créée", function()
        local account = EnergyModel.newAccount(P01)
        local start = account.Level
        -- Client qui ne déclare rien : le plancher s'applique.
        EnergyModel.settle(account, P01, 0.01, 0, 0, 0.2)
        T.near(account.Level, start - 0.01, 1e-9)
        -- Client honnête au-dessus du plancher, à un débit plausible (1 s) : accepté.
        EnergyModel.settle(account, P01, 0.001, 0, 0.03, 1)
        T.near(account.Level, start - 0.03, 1e-9)
        -- Saut absurde : limité au débit maximal plausible.
        local before = account.Level
        EnergyModel.settle(account, P01, 0, 0, 500, 0.2)
        T.truthy(before - account.Level <= EnergyModel.maxRate(P01) * 0.2 + 1e-9, "débit borné")
        -- Cumul qui recule (ou NaN) : ignoré, rien n'est rendu.
        local level = account.Level
        EnergyModel.settle(account, P01, 0, 0, 0, 0.2)
        EnergyModel.settle(account, P01, 0, 0, 0 / 0, 0.2)
        T.truthy(account.Level <= level, "aucun gain")
    end)

    T.test("réserve vide : verrouillée, aucune récupération, rien n'est rechargé", function()
        local account = EnergyModel.newAccount(P03, 0.001)
        EnergyModel.settle(account, P03, 0.01, 0, nil, 0.2)
        T.equal(account.Level, 0)
        T.equal(account.Empty, true)
        EnergyModel.settle(account, P03, 0, 0.5, nil, 0.2)
        T.equal(account.Level, 0, "pas de recharge par récupération batterie vide")
        local fresh = EnergyModel.newAccount(P03)
        EnergyModel.settle(fresh, P03, 0, 1000, nil, 0.2)
        T.truthy(fresh.Level <= fresh.Capacity, "jamais au-delà de la capacité")
    end)

    T.test("panne : sans énergie, le moteur s'arrête et ne propulse plus", function()
        local snaps, state = PlanarSim.run(Dynamics, P01, {
            Dt = DT,
            Duration = 4,
            InitialForward = 50 / 3.6,
            Prepare = function(state)
                state.Gear = 3
            end,
            Input = function(t, _, state)
                if t > 1 then
                    state.EnergyAvailable = false
                end
                return input(1, 0, 0)
            end,
        })
        T.equal(state.EngineRunning, false)
        T.truthy(snaps[#snaps].Forward < snaps[60].Forward, "décélère malgré l'accélérateur")
        T.equal(Dynamics.startEngine(state, P01), false, "relance impossible")
    end)

    T.test("consommation selon le véhicule et l'usage (croisière 90 km/h vs pleine charge)", function()
        local function cruise(definition: any, gear: number, throttle: number?): number
            local _, state = PlanarSim.run(Dynamics, definition, {
                Dt = DT,
                Duration = 20,
                InitialForward = 90 / 3.6,
                Prepare = function(state)
                    state.Gear = gear
                    state.Coupled = true
                end,
                Input = function(_, s)
                    -- Régulateur simple autour de 90 km/h.
                    local t = throttle or math.clamp(0.25 + (90 / 3.6 - s.Forward) * 0.3, 0, 1)
                    return input(t, 0, 0)
                end,
            })
            -- Litres (ou kWh) aux 100 km.
            return state.EnergyUsed / (90 / 3.6 * 20 / 1000) * 100
        end
        local petrol = cruise(P01, 6)
        local diesel = cruise(P02, 6)
        local electric = cruise(P03, 1)
        T.truthy(diesel < petrol, string.format("diesel %.1f < essence %.1f L/100 km", diesel, petrol))
        T.between(petrol, 3, 15, "essence, croisière")
        T.between(electric, 8, 30, "électrique, kWh/100 km")
        T.note(
            string.format(
                "Croisière 90 km/h (modèle) : P-01 essence %.1f L/100 km, P-02 diesel %.1f L/100 km, P-03 %.1f kWh/100 km",
                petrol,
                diesel,
                electric
            )
        )
    end)

    T.test("codec : cumul d'énergie transmis, invalide ignoré sans rejeter la commande", function()
        local command = { Throttle = 0.5, Brake = 0, Steer = 0, Handbrake = false, Clutch = 0 }
        local decoded, energy = InputCodec.decode(InputCodec.encode(command, 1.234567))
        T.truthy(decoded ~= nil)
        T.near(energy :: number, 1.23457, 1e-9)
        local _, bad = InputCodec.decode({ 0.5, 0, 0, 0, 0 / 0 })
        T.equal(bad, nil)
        local _, negative = InputCodec.decode({ 0.5, 0, 0, 0, -5 })
        T.equal(negative, 0, "jamais négatif")
        local legacy, none = InputCodec.decode({ 0.5, 0, 0, 0 })
        T.truthy(legacy ~= nil and none == nil, "ancien format accepté, sans cumul")
    end)

    T.suite("Lot 0.2 — dégâts")

    T.test("seuils : rien sous 1,5 m/s, rayures, dégâts localisés, dégâts importants", function()
        local state = DamageModel.new()
        T.equal(DamageModel.applyImpact(state, "Front", 1, 1.0), nil)
        local scratch = DamageModel.applyImpact(DamageModel.new(), "Front", 1, 2.2)
        T.equal(scratch.Level, 1)
        T.equal(scratch.Mechanical, false)
        local localized = DamageModel.applyImpact(DamageModel.new(), "Front", 1, 5)
        T.equal(localized.Level, 2)
        T.equal(localized.Mechanical, true)
        local major = DamageModel.applyImpact(DamageModel.new(), "Front", 1, 9)
        T.equal(major.Level, 3)
    end)

    T.test("conséquences mécaniques graduelles et cumulatives", function()
        local state = DamageModel.new()
        local previous = DamageModel.condition(state).EnginePower
        T.equal(previous, 1)
        for _ = 1, 4 do
            DamageModel.applyImpact(state, "Front", 2, 7)
            local power = DamageModel.condition(state).EnginePower
            T.truthy(power < previous, "puissance en baisse")
            previous = power
        end
        T.truthy(previous >= 0.35, "jamais sous 35 % (pas de destruction totale dans ce lot)")
        local side = DamageModel.new()
        DamageModel.applyImpact(side, "Left", 1, 8)
        local condition = DamageModel.condition(side)
        T.truthy(condition.CornerGrip[1] < 1 and condition.CornerGrip[4] == 1, "roue touchée seulement")
        T.truthy(condition.SteeringPullRad < 0, "direction qui tire du côté touché (gauche)")
    end)

    T.test("zone et roue déduites du point de contact", function()
        T.equal(DamageModel.locate(0, -2, 1, 2), "Front")
        T.equal(DamageModel.locate(0, 2, 1, 2), "Rear")
        local zone, corner = DamageModel.locate(-0.9, -0.5, 1, 2)
        T.equal(zone, "Left")
        T.equal(corner, 1)
        local _, rearRight = DamageModel.locate(0.9, 1.5, 1, 2)
        T.equal(rearRight, 4)
    end)

    T.test("sérialisation en attributs : aller-retour, valeurs invalides → intact", function()
        local state = DamageModel.new()
        DamageModel.applyImpact(state, "Right", 2, 8)
        local attributes = DamageModel.toAttributes(state)
        local copy = DamageModel.fromAttributes(function(name)
            return attributes[name]
        end)
        T.near(copy.Zones.Right, state.Zones.Right, 1e-12)
        T.near(copy.Suspension[2], state.Suspension[2], 1e-12)
        T.equal(copy.Impacts, 1)
        T.equal(attributes.DmgVersion, DamageModel.Version)
        local garbage = DamageModel.fromAttributes(function()
            return 0 / 0
        end)
        T.equal(garbage.Engine, 1)
    end)

    T.test("dégâts appliqués à la dynamique : moins de puissance, direction qui tire", function()
        local function run(prepare: (any) -> ()): { any }
            return PlanarSim.run(Dynamics, P01, {
                Dt = DT,
                Duration = 6,
                Prepare = prepare,
                Input = function()
                    return input(1, 0, 0)
                end,
            })
        end
        local intact = run(function() end)
        local damaged = run(function(state)
            local damage = DamageModel.new()
            for _ = 1, 3 do
                DamageModel.applyImpact(damage, "Front", 1, 9)
            end
            state.Condition = DamageModel.condition(damage)
        end)
        T.truthy(damaged[#damaged].Forward < intact[#intact].Forward * 0.95, "accélération réduite")
        T.truthy(math.abs(damaged[#damaged].Heading) > math.abs(intact[#intact].Heading) + 0.01, "trajectoire déviée")
    end)
end
