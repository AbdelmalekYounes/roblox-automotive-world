--!strict
-- Dynamique automobile PURE (aucune API Roblox), testable hors Studio.
--
-- Rôle : à partir de l'intention du conducteur et du contact de chaque roue
-- (fourni par l'adaptateur Roblox), calculer les efforts de chaque pneu et
-- faire évoluer l'état interne (rotation des roues, rapport, régime).
-- Le châssis lui-même (masse, inertie, intégration du mouvement) est simulé
-- par le moteur physique de Roblox : il n'y a donc AUCUNE vitesse imposée.
--
-- Ordre des roues : 1 avant gauche, 2 avant droite, 3 arrière gauche, 4 arrière droite.

local Types = require(script.Parent.Parent.VehicleTypes)
local TireModel = require(script.Parent.TireModel)
local Powertrain = require(script.Parent.Powertrain)
local Suspension = require(script.Parent.Suspension)

local VehicleDynamics = {}

local GRAVITY = 9.81
local WHEEL_SUBSTEPS = 4

-- Position des roues par rapport au centre de gravité (m) :
-- Longitudinal positif vers l'avant, Lateral positif vers la droite.
export type WheelLayout = {
    Longitudinal: number,
    Lateral: number,
    IsFront: boolean,
    Side: number,
}

function VehicleDynamics.wheelLayout(definition: Types.VehicleDefinition): { WheelLayout }
    local chassis = definition.Chassis
    local front = chassis.WheelbaseM * (1 - chassis.FrontWeightFraction)
    local rear = -chassis.WheelbaseM * chassis.FrontWeightFraction
    return {
        { Longitudinal = front, Lateral = -chassis.TrackFrontM / 2, IsFront = true, Side = -1 },
        { Longitudinal = front, Lateral = chassis.TrackFrontM / 2, IsFront = true, Side = 1 },
        { Longitudinal = rear, Lateral = -chassis.TrackRearM / 2, IsFront = false, Side = -1 },
        { Longitudinal = rear, Lateral = chassis.TrackRearM / 2, IsFront = false, Side = 1 },
    }
end

-- Charge statique par roue (N) à l'arrêt sur sol plat.
function VehicleDynamics.nominalCornerLoad(definition: Types.VehicleDefinition, isFront: boolean): number
    local chassis = definition.Chassis
    local fraction = if isFront then chassis.FrontWeightFraction else 1 - chassis.FrontWeightFraction
    return chassis.MassKg * GRAVITY * fraction / 2
end

-- Compression statique (m) de la suspension sous la charge nominale.
function VehicleDynamics.staticCompression(definition: Types.VehicleDefinition, isFront: boolean): number
    local axle = if isFront then definition.Suspension.Front else definition.Suspension.Rear
    return VehicleDynamics.nominalCornerLoad(definition, isFront) / axle.SpringRateNpm
end

function VehicleDynamics.createState(definition: Types.VehicleDefinition): Types.VehicleRuntimeState
    local shares = Powertrain.wheelDriveShares(definition.Powertrain.Drivetrain)
    local layout = VehicleDynamics.wheelLayout(definition)
    local wheels: { Types.WheelRuntime } = {}
    for index, place in layout do
        wheels[index] = {
            Index = index,
            IsFront = place.IsFront,
            Side = place.Side,
            DriveShare = shares[index],
            AngularVelocity = 0,
            SpinAngle = 0,
            SteerAngle = 0,
            Compression = VehicleDynamics.staticCompression(definition, place.IsFront),
            SlipRatio = 0,
        }
    end
    return {
        Wheels = wheels,
        Gear = 0,
        EngineRpm = definition.Powertrain.Engine.IdleRpm,
        ShiftTimer = 0,
        DirectionRequestTimer = 0,
        SteerPosition = 0,
        DriveThrottle = 0,
        BrakePedal = 0,
    }
end

-- Géométrie d'Ackermann : la roue intérieure braque davantage que l'extérieure.
-- Retourne (angle intérieur, angle extérieur), du même signe que `center`.
function VehicleDynamics.ackermann(center: number, wheelbase: number, track: number): (number, number)
    local magnitude = math.abs(center)
    if magnitude < 1e-4 then
        return center, center
    end
    local radius = wheelbase / math.tan(magnitude)
    local innerRadius = math.max(radius - track / 2, track * 0.25)
    local inner = math.atan(wheelbase / innerRadius)
    local outer = math.atan(wheelbase / (radius + track / 2))
    local sign = math.sign(center)
    return inner * sign, outer * sign
end

-- Angle de braquage maximal commandable à la vitesse donnée (rad).
function VehicleDynamics.maxSteerAngle(definition: Types.VehicleDefinition, forwardSpeed: number): number
    local steering = definition.Steering
    local blend = math.clamp(math.abs(forwardSpeed) * 3.6 / steering.HighSpeedReferenceKmh, 0, 1)
    return math.rad(steering.MaxAngleDeg + (steering.HighSpeedAngleDeg - steering.MaxAngleDeg) * blend)
end

-- Met à jour la position de crémaillère (vitesse limitée) et les angles des roues.
function VehicleDynamics.updateSteering(
    state: Types.VehicleRuntimeState,
    definition: Types.VehicleDefinition,
    steerInput: number,
    forwardSpeed: number,
    dt: number
)
    local steering = definition.Steering
    local target = math.clamp(steerInput, -1, 1)
    local maxDelta = steering.RackSpeedDegPerS / steering.MaxAngleDeg * dt
    state.SteerPosition += math.clamp(target - state.SteerPosition, -maxDelta, maxDelta)

    local center = state.SteerPosition * VehicleDynamics.maxSteerAngle(definition, forwardSpeed)
    local inner, outer =
        VehicleDynamics.ackermann(center, definition.Chassis.WheelbaseM, definition.Chassis.TrackFrontM)
    for _, wheel in state.Wheels do
        if wheel.IsFront then
            -- Virage à droite (center > 0) : la roue intérieure est la droite.
            local isInner = (center >= 0) == (wheel.Side > 0)
            wheel.SteerAngle = if isInner then inner else outer
        else
            wheel.SteerAngle = 0
        end
    end
end

--[[
    Pas de simulation des efforts pneumatiques.
    `contacts` doit contenir 4 contacts dans l'ordre canonique.
    `forwardSpeed` = vitesse longitudinale du châssis (m/s, positive en avant).
    Retourne les efforts par roue, dans le repère de contact de chaque roue.
]]
function VehicleDynamics.step(
    state: Types.VehicleRuntimeState,
    definition: Types.VehicleDefinition,
    input: Types.DriverInput,
    contacts: { Types.WheelContact },
    forwardSpeed: number,
    dt: number
): { Types.WheelForces }
    local powertrain = definition.Powertrain
    local tire = definition.Tires
    local brakes = definition.Brakes

    -- 1. Boîte automatique et pédales effectives.
    local driveThrottle, brakePedal = Powertrain.updateAutomatic(state, powertrain, input, forwardSpeed, dt)
    state.DriveThrottle = driveThrottle
    state.BrakePedal = brakePedal

    -- 2. Charges normales : ressorts, amortisseurs, butées et antiroulis.
    local normals = table.create(4, 0)
    for index, wheel in state.Wheels do
        local contact = contacts[index]
        local axle = if wheel.IsFront then definition.Suspension.Front else definition.Suspension.Rear
        normals[index] = Suspension.normalForce(axle, contact)
        wheel.Compression = if contact.Grounded then contact.Compression else 0
    end
    Suspension.applyAntiRoll(definition.Suspension.Front.AntiRollNpm, contacts[1], contacts[2], normals, 1, 2)
    Suspension.applyAntiRoll(definition.Suspension.Rear.AntiRollNpm, contacts[3], contacts[4], normals, 3, 4)

    -- 3. Couple moteur transmis aux roues motrices.
    local drivenOmega, shareSum = 0, 0
    for _, wheel in state.Wheels do
        if wheel.DriveShare > 0 then
            drivenOmega += wheel.AngularVelocity * wheel.DriveShare
            shareSum += wheel.DriveShare
        end
    end
    if shareSum > 0 then
        drivenOmega /= shareSum
    end
    local totalTorque, overallRatio = Powertrain.computeWheelTorque(state, powertrain, driveThrottle, drivenOmega, dt)

    -- 4. Efforts de chaque pneu.
    local forces: { Types.WheelForces } = table.create(4)
    for index, wheel in state.Wheels do
        local contact = contacts[index]
        local normal = normals[index]

        local brakeTorque = brakePedal * (if wheel.IsFront then brakes.MaxTorqueFrontNm else brakes.MaxTorqueRearNm)
        if input.Handbrake and not wheel.IsFront then
            brakeTorque += brakes.HandbrakeTorqueNm
        end
        local driveTorque = totalTorque * wheel.DriveShare

        -- Inertie vue par la roue : jante/pneu + part de l'inertie moteur
        -- ramenée par le rapport engagé (fort en 1re, faible en 6e).
        local inertia = tire.WheelInertiaKgM2
        if wheel.DriveShare > 0 and overallRatio ~= 0 then
            inertia += powertrain.Engine.InertiaKgM2 * overallRatio * overallRatio * wheel.DriveShare
        end

        local fx, fy = 0, 0
        if contact.Grounded and normal > 0 then
            local nominal = VehicleDynamics.nominalCornerLoad(definition, wheel.IsFront)
            local surface = contact.SurfaceFriction
            local peakX = TireModel.loadAdjustedFriction(
                tire.PeakFrictionLongitudinal,
                normal,
                nominal,
                tire.LoadSensitivity
            ) * surface * normal
            local peakY = TireModel.loadAdjustedFriction(
                tire.PeakFrictionLateral,
                normal,
                nominal,
                tire.LoadSensitivity
            ) * surface * normal
            local vx = contact.LongitudinalVelocity
            local vy = contact.LateralVelocity
            local effectiveMass = normal / GRAVITY

            local omega, fxTire, slip = TireModel.integrateWheel(
                wheel.AngularVelocity,
                driveTorque,
                brakeTorque,
                inertia,
                tire.RadiusM,
                vx,
                peakX,
                tire.PeakSlipRatio,
                tire.SlidingFrictionRatio,
                dt,
                WHEEL_SUBSTEPS
            )
            wheel.AngularVelocity = omega
            wheel.SlipRatio = slip
            fxTire = TireModel.stopClamp(fxTire, effectiveMass, omega * tire.RadiusM - vx, dt)

            local rolling = TireModel.stopClamp(-math.sign(vx) * tire.RollingResistance * normal, effectiveMass, vx, dt)

            local lateral =
                TireModel.lateralForce(vy, vx, peakY, math.rad(tire.PeakSlipAngleDeg), tire.SlidingFrictionRatio)
            lateral = TireModel.stopClamp(lateral, effectiveMass, vy, dt)

            fx, fy = TireModel.combine(fxTire + rolling, lateral, peakX, peakY)
        else
            wheel.AngularVelocity =
                TireModel.integrateFreeWheel(wheel.AngularVelocity, driveTorque, brakeTorque, inertia, dt)
            wheel.SlipRatio = 0
        end

        wheel.SpinAngle = (wheel.SpinAngle + wheel.AngularVelocity * dt) % (2 * math.pi)
        forces[index] = { Normal = normal, Longitudinal = fx, Lateral = fy }
    end

    return forces
end

return table.freeze(VehicleDynamics)
