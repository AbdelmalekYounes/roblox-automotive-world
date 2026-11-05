--!strict
-- Groupe motopropulseur PUR : moteur thermique, boîte automatique simplifiée
-- et répartition du couple. Aucune API Roblox.
--
-- Implémenté dans le lot 0.1 :
-- - courbe de couple interpolée, ralenti, rupteur, frein moteur ;
-- - embrayage/convertisseur simplifié qui glisse au démarrage ;
-- - boîte automatique (passages selon régime et charge, marche arrière
--   enclenchée à l'arrêt en maintenant « freiner ») ;
-- - répartition fixe avant/arrière, différentiels ouverts (50/50 par essieu).
-- NON implémenté : moteur électrique, boîtes manuelle/double embrayage/
-- séquentielle/CVT, différentiels autobloquants, aides électroniques.
-- `VehicleDefinitions.validate` refuse explicitement ces configurations.

local Types = require(script.Parent.Parent.VehicleTypes)

local Powertrain = {}

local TWO_PI = 2 * math.pi
-- En dessous de cette vitesse (m/s), le véhicule est considéré à l'arrêt
-- pour les changements de sens de marche.
Powertrain.StopSpeed = 0.8
-- Durée de maintien (s) de la commande opposée avant inversion du sens.
Powertrain.DirectionHoldS = 0.3

-- Interpolation linéaire de la courbe de couple (bornée aux extrémités).
function Powertrain.sampleTorque(curve: { Types.TorquePoint }, rpm: number): number
    local count = #curve
    if count == 0 then
        return 0
    end
    if rpm <= curve[1].Rpm then
        return curve[1].TorqueNm
    end
    for i = 2, count do
        local high = curve[i]
        if rpm <= high.Rpm then
            local low = curve[i - 1]
            local t = (rpm - low.Rpm) / (high.Rpm - low.Rpm)
            return low.TorqueNm + (high.TorqueNm - low.TorqueNm) * t
        end
    end
    return curve[count].TorqueNm
end

-- Rapport de boîte signé : négatif en marche arrière, 0 au neutre.
function Powertrain.gearRatio(transmission: Types.TransmissionDefinition, gear: number): number
    if gear == 0 then
        return 0
    elseif gear < 0 then
        return -transmission.ReverseRatio
    end
    return transmission.ForwardRatios[gear] or 0
end

function Powertrain.overallRatio(transmission: Types.TransmissionDefinition, gear: number): number
    return Powertrain.gearRatio(transmission, gear) * transmission.FinalDrive
end

function Powertrain.rpmFromWheel(omega: number, overallRatio: number): number
    return math.abs(omega * overallRatio) * 60 / TWO_PI
end

--[[
    Logique de sélection de la boîte automatique pour le sens de marche.
    Retourne (accélérateur effectif, pédale de frein effective) :
    en marche arrière, la commande « freiner » devient l'accélérateur et
    « accélérer » devient le frein (convention habituelle des jeux de conduite).
]]
function Powertrain.updateAutomatic(
    state: Types.VehicleRuntimeState,
    _powertrain: Types.PowertrainDefinition,
    input: Types.DriverInput,
    forwardSpeed: number,
    dt: number
): (number, number)
    local throttle = input.Throttle
    local brake = input.Brake
    local stopped = math.abs(forwardSpeed) < Powertrain.StopSpeed

    if state.ShiftTimer > 0 then
        state.ShiftTimer = math.max(0, state.ShiftTimer - dt)
    end

    if state.Gear >= 0 then
        if state.Gear == 0 and throttle > 0.05 then
            state.Gear = 1
        end
        if stopped and brake > 0.1 and throttle < 0.05 then
            state.DirectionRequestTimer += dt
            if state.DirectionRequestTimer >= Powertrain.DirectionHoldS then
                state.Gear = -1
                state.DirectionRequestTimer = 0
                state.ShiftTimer = 0
            end
        else
            state.DirectionRequestTimer = 0
        end
    else
        if stopped and throttle > 0.1 and brake < 0.05 then
            state.DirectionRequestTimer += dt
            if state.DirectionRequestTimer >= Powertrain.DirectionHoldS * 0.5 then
                state.Gear = 1
                state.DirectionRequestTimer = 0
                state.ShiftTimer = 0
            end
        else
            state.DirectionRequestTimer = 0
        end
    end

    if state.Gear < 0 then
        return brake, throttle
    end
    return throttle, brake
end

--[[
    Calcule le couple total aux roues motrices (N·m, signé selon le rapport)
    et gère les passages de rapports automatiques.
    `drivenOmega` = vitesse angulaire moyenne pondérée des roues motrices.
    Retourne (couple total aux roues, rapport global courant).
]]
function Powertrain.computeWheelTorque(
    state: Types.VehicleRuntimeState,
    powertrain: Types.PowertrainDefinition,
    driveThrottle: number,
    drivenOmega: number,
    dt: number
): (number, number)
    local engine = powertrain.Engine
    local transmission = powertrain.Transmission
    local gear = state.Gear

    if gear == 0 then
        -- Neutre : moteur découplé, régime libre lissé.
        local target = engine.IdleRpm + driveThrottle * (engine.RedlineRpm - engine.IdleRpm)
        state.EngineRpm += (target - state.EngineRpm) * math.min(1, dt * 4)
        return 0, 0
    end

    local overall = Powertrain.overallRatio(transmission, gear)
    local rpmWheels = Powertrain.rpmFromWheel(drivenOmega, overall)
    local turningWithGear = drivenOmega * overall > 0

    -- Passages automatiques (rapports avant uniquement). Les seuils baissent
    -- à faible charge, avec une hystérésis supérieure à l'écart entre rapports.
    if gear >= 1 and state.ShiftTimer <= 0 and turningWithGear then
        local factor = 0.55 + 0.45 * driveThrottle
        if rpmWheels > transmission.ShiftUpRpm * factor and gear < #transmission.ForwardRatios then
            gear += 1
            state.ShiftTimer = transmission.ShiftDurationS
        elseif rpmWheels < transmission.ShiftDownRpm * factor and gear > 1 then
            gear -= 1
            state.ShiftTimer = transmission.ShiftDurationS * 0.6
        end
        if gear ~= state.Gear then
            state.Gear = gear
            overall = Powertrain.overallRatio(transmission, gear)
            rpmWheels = Powertrain.rpmFromWheel(drivenOmega, overall)
        end
    end

    -- Embrayage/convertisseur simplifié : à bas régime, il glisse et laisse
    -- le moteur monter jusqu'à un régime de démarrage dépendant de l'accélérateur.
    local launchRpm = engine.IdleRpm + driveThrottle * (engine.ClutchLaunchRpm - engine.IdleRpm)
    local rpm = math.min(math.max(rpmWheels, launchRpm), engine.LimiterRpm)
    state.EngineRpm = rpm

    if state.ShiftTimer > 0 then
        -- Couple coupé pendant le passage de rapport.
        return 0, overall
    end

    local engineTorque = 0
    if rpmWheels >= engine.LimiterRpm then
        engineTorque = 0 -- rupteur
    elseif driveThrottle > 0.02 then
        engineTorque = Powertrain.sampleTorque(engine.TorqueCurve, rpm) * driveThrottle
    elseif turningWithGear and rpmWheels > engine.IdleRpm then
        -- Frein moteur proportionnel au régime, uniquement quand les roues
        -- entraînent le moteur dans le sens du rapport engagé.
        engineTorque = -engine.EngineBrakeTorqueNm * (rpmWheels / engine.RedlineRpm)
    end

    return engineTorque * overall * transmission.Efficiency, overall
end

-- Part du couple reçue par chaque roue (ordre FL, FR, RL, RR) :
-- répartition fixe avant/arrière puis différentiel ouvert 50/50 par essieu.
function Powertrain.wheelDriveShares(drivetrain: Types.DrivetrainDefinition): { number }
    local front = math.clamp(drivetrain.FrontTorqueShare, 0, 1)
    local rear = 1 - front
    return { front / 2, front / 2, rear / 2, rear / 2 }
end

return table.freeze(Powertrain)
