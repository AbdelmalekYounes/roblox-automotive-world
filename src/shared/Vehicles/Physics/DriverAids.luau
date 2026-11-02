--!strict
-- Aides électroniques PURES : ABS, antipatinage, contrôle de stabilité (ESP).
--
-- Règles (cahier des charges §1.2) :
-- - une aide n'agit que si le modèle en est équipé (`definition.Aids`) ET si le
--   conducteur l'a activée (`state.Aids`, tout à false au début de la session) ;
-- - une aide ne crée JAMAIS d'adhérence : elle ne fait que réduire un couple
--   de freinage (ABS), réduire le couple moteur (antipatinage) ou freiner une
--   roue choisie (ESP). Les limites du pneu restent celles de TireModel ;
-- - le filtre de braquage A1 n'est pas une aide : il reste dans VehicleDynamics,
--   indépendant de ce module, et ne lit ni lacet ni glissement.
-- Les décisions s'appuient sur l'état de la fin du pas précédent (glissements,
-- lacet), comme le ferait un calculateur échantillonné.

local Types = require(script.Parent.Parent.VehicleTypes)

local DriverAids = {}

-- ABS : seuils relatifs au glissement du pic d'adhérence du pneu.
local ABS_RELEASE = 1.3
local ABS_REAPPLY = 0.7
local ABS_RELEASE_RATE = 10 -- fraction de pression retirée par seconde
local ABS_APPLY_RATE = 4
local ABS_MIN_FACTOR = 0.1
local ABS_MIN_SPEED = 2 -- m/s

-- Antipatinage.
local TC_SLIP = 1.5
local TC_RECOVER_SLIP = 1.0
local TC_CUT_RATE = 6
local TC_RECOVER_RATE = 2.5
local TC_MIN_FACTOR = 0.05

-- ESP : modèle de référence « bicyclette » et gains.
local ESC_MIN_SPEED = 15 / 3.6
local ESC_UNDERSTEER_GRADIENT = 0.0025 -- s²/m
local ESC_DEADBAND = 0.05 -- rad/s
local ESC_SLIP_ANGLE = 0.1 -- rad de dérive du châssis
local ESC_GAIN = 2800 -- N·m par rad/s d'écart
local ESC_FRONT_SHARE = 0.6
local ESC_REAR_SHARE = 0.5

local function enabled(
    definition: Types.VehicleDefinition,
    state: Types.VehicleRuntimeState,
    aid: Types.AidName
): boolean
    return (definition.Aids :: any)[aid] == true and (state.Aids :: any)[aid] == true
end
DriverAids.isEnabled = enabled

--[[
    ABS : module la pression de chaque roue d'après son glissement. Quand le
    glissement dépasse le pic (roue qui se bloque), la pression baisse ; quand
    la roue a ré-accroché, elle remonte. Aucun effet sans freinage.
]]
function DriverAids.updateAbs(
    state: Types.VehicleRuntimeState,
    definition: Types.VehicleDefinition,
    braking: boolean,
    forwardSpeed: number,
    dt: number
)
    local active = false
    local on = enabled(definition, state, "Abs") and braking and math.abs(forwardSpeed) > ABS_MIN_SPEED
    local peak = definition.Tires.PeakSlipRatio
    for _, wheel in state.Wheels do
        if not on then
            wheel.AbsFactor = 1
            continue
        end
        -- Glissement de freinage : négatif en marche avant, positif en marche arrière.
        local slip = wheel.SlipRatio * (if forwardSpeed >= 0 then 1 else -1)
        if slip < -peak * ABS_RELEASE then
            wheel.AbsFactor = math.max(ABS_MIN_FACTOR, wheel.AbsFactor - ABS_RELEASE_RATE * dt)
        elseif slip > -peak * ABS_REAPPLY then
            wheel.AbsFactor = math.min(1, wheel.AbsFactor + ABS_APPLY_RATE * dt)
        end
        if wheel.AbsFactor < 0.98 then
            active = true
        end
    end
    state.AidActivity.Abs = active
end

--[[
    Antipatinage : réduit le couple moteur tant qu'une roue motrice patine
    au-delà du pic d'adhérence, puis le rend progressivement.
]]
function DriverAids.updateTraction(state: Types.VehicleRuntimeState, definition: Types.VehicleDefinition, dt: number)
    if not enabled(definition, state, "TractionControl") then
        state.TractionFactor = 1
        state.AidActivity.TractionControl = false
        return
    end
    local peak = definition.Tires.PeakSlipRatio
    local worst = 0
    for _, wheel in state.Wheels do
        if wheel.DriveShare > 0 then
            -- Patinage en traction : glissement dans le sens du couple moteur.
            worst = math.max(worst, wheel.SlipRatio * (if state.Gear < 0 then -1 else 1))
        end
    end
    if worst > peak * TC_SLIP then
        state.TractionFactor = math.max(TC_MIN_FACTOR, state.TractionFactor - TC_CUT_RATE * dt)
    elseif worst < peak * TC_RECOVER_SLIP then
        state.TractionFactor = math.min(1, state.TractionFactor + TC_RECOVER_RATE * dt)
    end
    state.AidActivity.TractionControl = state.TractionFactor < 0.98
end

-- Lacet de référence (rad/s) d'après le braquage et la vitesse, borné par l'adhérence.
function DriverAids.referenceYawRate(definition: Types.VehicleDefinition, steerAngle: number, forward: number): number
    local wheelbase = definition.Chassis.WheelbaseM
    local reference = forward * steerAngle / (wheelbase + ESC_UNDERSTEER_GRADIENT * forward * forward)
    local mu = math.max(definition.Tires.PeakFrictionLateral, 0.1)
    local bound = 0.85 * mu * 9.81 / math.max(math.abs(forward), 1)
    return math.clamp(reference, -bound, bound)
end

--[[
    ESP : compare le lacet mesuré au lacet de référence.
    - Survirage (lacet excessif ou dérive du châssis) : freine la roue AVANT
      EXTÉRIEURE, ce qui crée un moment qui redresse le véhicule.
    - Sous-virage (lacet insuffisant) : freine la roue ARRIÈRE INTÉRIEURE et
      réduit le couple moteur.
    Les couples ajoutés sont écrits dans `wheel.EscBrakeTorque`.
]]
function DriverAids.updateStability(
    state: Types.VehicleRuntimeState,
    definition: Types.VehicleDefinition,
    motion: Types.ChassisMotion,
    handbrake: boolean
)
    for _, wheel in state.Wheels do
        wheel.EscBrakeTorque = 0
    end
    state.AidActivity.StabilityControl = false
    local forward = motion.Forward
    if not enabled(definition, state, "StabilityControl") or forward < ESC_MIN_SPEED then
        return
    end
    local steer = (state.Wheels[1].SteerAngle + state.Wheels[2].SteerAngle) / 2
    local reference = DriverAids.referenceYawRate(definition, steer, forward)
    local yaw = motion.YawRate
    local slipAngle = math.atan2(motion.Lateral, forward)
    local brakes = definition.Brakes

    -- Sens du virage effectif : celui du lacet mesuré, sinon de la référence.
    local turning = if math.abs(yaw) > 0.02 then math.sign(yaw) else math.sign(reference)
    if turning == 0 then
        return
    end
    local excess = math.abs(yaw) - math.abs(reference)
    local oversteer = (excess > ESC_DEADBAND and math.sign(yaw) == math.sign(reference))
        or (math.sign(yaw) ~= math.sign(reference) and math.abs(yaw - reference) > ESC_DEADBAND * 2)
        -- Dérive : l'arrière glisse vers l'extérieur (vitesse latérale vers l'intérieur du virage).
        or (math.abs(slipAngle) > ESC_SLIP_ANGLE and math.sign(slipAngle) ~= turning)
    if oversteer then
        local magnitude = math.max(math.abs(yaw - reference) - ESC_DEADBAND, math.abs(slipAngle) - ESC_SLIP_ANGLE * 0.5)
        -- Roue avant extérieure : à gauche (1) pour un virage à droite.
        local outer = if turning > 0 then 1 else 2
        state.Wheels[outer].EscBrakeTorque =
            math.clamp(ESC_GAIN * magnitude, 0, brakes.MaxTorqueFrontNm * ESC_FRONT_SHARE)
        state.AidActivity.StabilityControl = true
        return
    end
    -- Sous-virage : seulement si l'arrière tient (dérive faible) et sans frein à
    -- main. Mesuré dans Studio : freiner la roue arrière intérieure pendant un
    -- décrochage provoqué ajoutait de la rotation (dérive 13° au lieu de 5°).
    local deficit = math.abs(reference) - math.abs(yaw)
    if
        deficit > ESC_DEADBAND * 1.6
        and math.abs(reference) > 0.05
        and math.abs(slipAngle) < ESC_SLIP_ANGLE * 0.4
        and not handbrake
    then
        -- Roue arrière intérieure : à droite (4) pour un virage à droite.
        local inner = if turning > 0 then 4 else 3
        state.Wheels[inner].EscBrakeTorque =
            math.clamp(ESC_GAIN * (deficit - ESC_DEADBAND), 0, brakes.MaxTorqueRearNm * ESC_REAR_SHARE)
        state.TractionFactor = math.min(state.TractionFactor, 0.6)
        state.AidActivity.StabilityControl = true
    end
end

return table.freeze(DriverAids)
