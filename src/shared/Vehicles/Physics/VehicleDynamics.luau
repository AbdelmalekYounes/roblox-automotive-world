--!strict
-- Dynamique automobile PURE (aucune API Roblox), testable hors Studio.
--
-- Rôle : à partir de l'intention du conducteur, du contact de chaque roue et du
-- mouvement du châssis (fournis par l'adaptateur Roblox), calculer les efforts
-- de chaque pneu et faire évoluer l'état interne : moteur (corps en rotation),
-- boîte, embrayage ou convertisseur, différentiels, roues, aides, énergie.
-- Le châssis lui-même (masse, inertie, intégration du mouvement) est simulé
-- par le moteur physique de Roblox : il n'y a donc AUCUNE vitesse imposée.
--
-- Ordre des roues : 1 avant gauche, 2 avant droite, 3 arrière gauche, 4 arrière droite.

local Types = require(script.Parent.Parent.VehicleTypes)
local TireModel = require(script.Parent.TireModel)
local Suspension = require(script.Parent.Suspension)
local Engine = require(script.Parent.Engine)
local Transmission = require(script.Parent.Transmission)
local Driveline = require(script.Parent.Driveline)
local DriverAids = require(script.Parent.DriverAids)

local VehicleDynamics = {}

local GRAVITY = 9.81
local SUBSTEPS = 4
-- Écart de vitesse (rad/s, côté moteur) sous lequel un embrayage qui patine se ferme.
local CLUTCH_LOCK_EPS = 2
local TWO_PI = 2 * math.pi

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

function VehicleDynamics.intactCondition(): Types.VehicleCondition
    return {
        EnginePower = 1,
        SteeringRange = 1,
        SteeringPullRad = 0,
        CornerGrip = { 1, 1, 1, 1 },
        CornerToeRad = { 0, 0, 0, 0 },
    }
end

function VehicleDynamics.createState(definition: Types.VehicleDefinition): Types.VehicleRuntimeState
    local shares = Driveline.wheelDriveShares(definition.Powertrain.Drivetrain)
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
            SlipAngle = 0,
            StickLongitudinal = 0,
            StickLateral = 0,
            LateralForce = 0,
            BrakeTorque = 0,
            AbsFactor = 1,
            EscBrakeTorque = 0,
        }
    end
    local transmission = definition.Powertrain.Transmission
    return {
        Wheels = wheels,
        Gear = 0,
        EngineOmega = 0,
        EngineRpm = 0,
        EngineRunning = false,
        EngineStalled = false,
        StarterTimer = 0,
        Coupled = false,
        ClutchCapacityNm = 0,
        ClutchPedal = 0,
        CvtRatio = transmission.ForwardRatios[1],
        ShiftTimer = 0,
        ManualHoldTimer = 0,
        DirectionRequestTimer = 0,
        SteerPosition = 0,
        DriveThrottle = 0,
        BrakePedal = 0,
        TractionFactor = 1,
        Aids = { Abs = false, TractionControl = false, StabilityControl = false },
        AidActivity = { Abs = false, TractionControl = false, StabilityControl = false },
        RegenLevel = 1,
        EnergyAvailable = true,
        EnergyUsed = 0,
        EnergyRecovered = 0,
        PowerKw = 0,
        EnginePowerKw = 0,
        Condition = VehicleDynamics.intactCondition(),
    }
end

--[[
    Mise en marche (contact) : moteur thermique au ralenti, ou moteur électrique
    prêt. Refusée sans énergie. Un véhicule stationné (simulé par le serveur)
    reste moteur arrêté : il ne consomme rien.
]]
function VehicleDynamics.startEngine(state: Types.VehicleRuntimeState, definition: Types.VehicleDefinition): boolean
    if not state.EnergyAvailable then
        return false
    end
    state.EngineRunning = true
    state.EngineStalled = false
    state.StarterTimer = 0
    local engine = definition.Powertrain.Engine
    if engine and state.EngineOmega < Engine.omega(engine.IdleRpm) then
        state.EngineOmega = Engine.omega(engine.IdleRpm)
    end
    state.EngineRpm = Engine.rpm(state.EngineOmega)
    return true
end

function VehicleDynamics.stopEngine(state: Types.VehicleRuntimeState)
    state.EngineRunning = false
    state.StarterTimer = 0
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
-- Arbitrage A1 : fonction LINÉAIRE de la seule vitesse ; filtre de commande,
-- indépendant des aides (aucune lecture du lacet ni du glissement).
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
    local condition = state.Condition
    local target = math.clamp(steerInput, -1, 1)
    local maxDelta = steering.RackSpeedDegPerS / steering.MaxAngleDeg * dt
    state.SteerPosition += math.clamp(target - state.SteerPosition, -maxDelta, maxDelta)

    -- Dégâts de direction : course réduite et tirage d'un côté (conséquence
    -- mécanique, pas une correction).
    local center = state.SteerPosition
            * VehicleDynamics.maxSteerAngle(definition, forwardSpeed)
            * condition.SteeringRange
        + condition.SteeringPullRad
    local inner, outer =
        VehicleDynamics.ackermann(center, definition.Chassis.WheelbaseM, definition.Chassis.TrackFrontM)
    for index, wheel in state.Wheels do
        local base = 0
        if wheel.IsFront then
            -- Virage à droite (center > 0) : la roue intérieure est la droite.
            local isInner = (center >= 0) == (wheel.Side > 0)
            base = if isInner then inner else outer
        end
        wheel.SteerAngle = base + condition.CornerToeRad[index]
    end
end

-- Vitesse angulaire moyenne des roues motrices, pondérée par leur part de couple.
local function drivenOmega(state: Types.VehicleRuntimeState): number
    local sum, shares = 0, 0
    for _, wheel in state.Wheels do
        if wheel.DriveShare > 0 then
            sum += wheel.AngularVelocity * wheel.DriveShare
            shares += wheel.DriveShare
        end
    end
    return if shares > 0 then sum / shares else 0
end
VehicleDynamics.drivenOmega = drivenOmega

-- Demande de passage du conducteur (boîtes à sélecteur), voir Transmission.requestShift.
function VehicleDynamics.requestShift(
    state: Types.VehicleRuntimeState,
    definition: Types.VehicleDefinition,
    direction: number,
    forwardSpeed: number
): Transmission.ShiftResult
    return Transmission.requestShift(state, definition.Powertrain, direction, forwardSpeed, drivenOmega(state))
end

-- Démarreur et calage du moteur thermique, panne d'énergie.
local function updateEngineState(state: Types.VehicleRuntimeState, powertrain: Types.PowertrainDefinition, dt: number)
    if not state.EnergyAvailable then
        -- Panne sèche ou batterie vide : plus de propulsion, aucune relance possible.
        state.EngineRunning = false
        state.StarterTimer = 0
        return
    end
    local engine = powertrain.Engine
    if engine == nil or not state.EngineStalled then
        return
    end
    -- Relance d'un moteur calé : démarreur quand l'embrayage est enfoncé ou au
    -- neutre (simplification : pas de clé), ou démarrage « à la poussette » si
    -- les roues entraînent le moteur au-dessus de 80 % du ralenti.
    local free = state.Gear == 0 or state.ClutchPedal >= 0.9
    if free then
        state.StarterTimer += dt
        if state.StarterTimer >= Transmission.StarterDurationS then
            state.EngineRunning = true
            state.EngineStalled = false
            state.StarterTimer = 0
            state.EngineOmega = math.max(state.EngineOmega, Engine.omega(engine.IdleRpm))
        end
    else
        state.StarterTimer = 0
        if state.Coupled and Engine.rpm(state.EngineOmega) > engine.IdleRpm * 0.8 then
            state.EngineRunning = true
            state.EngineStalled = false
        end
    end
end

-- Couple de la source (moteur thermique ou électrique) à la vitesse `omega`.
local function sourceTorque(
    state: Types.VehicleRuntimeState,
    definition: Types.VehicleDefinition,
    omega: number,
    throttle: number,
    regenFraction: number,
    speedRatio: number
): number
    local powertrain = definition.Powertrain
    local engine = powertrain.Engine
    if engine then
        local torque =
            Engine.combustionTorque(engine, omega, throttle, state.EngineRunning, state.Condition.EnginePower)
        if torque > 0 then
            torque *= state.TractionFactor
        end
        return torque
    end
    local motor = powertrain.Motor :: Types.ElectricMotorDefinition
    local torque = Engine.motorTorque(
        motor,
        omega,
        throttle,
        regenFraction,
        speedRatio,
        state.EnergyAvailable and state.EngineRunning,
        state.Condition.EnginePower
    )
    if torque > 0 then
        torque *= state.TractionFactor
    end
    return torque
end

--[[
    Pas de simulation des efforts pneumatiques.
    `contacts` : 4 contacts dans l'ordre canonique ; `motion` : vitesses du
    châssis dans son repère. Retourne les efforts par roue, dans le repère de
    contact de chaque roue.
]]
-- Lot 0.9.1 (QA-A08) : valeurs non finies (NaN, infini) dans l'état ou les contacts.
-- Constat VM (tâche 20261103-224247) : véhicule endommagé, plaqué contre un obstacle,
-- marche avant et arrière alternées ; 2 372 erreurs « clamp » en 43 s
-- (TireModel.stopClamp) et simulation figée. Cause première NON ÉTABLIE : l'état est
-- neutralisé (roue, moteur à l'arrêt ; contact ignoré pour ce pas) et compté ; rien ne
-- change tant que les valeurs restent finies.
local function finite(x: number): boolean
    return x == x and x > -math.huge and x < math.huge
end
local numericResets = 0
local lastResetWarn = -math.huge

function VehicleDynamics.numericResets(): number
    return numericResets
end

-- Lot 0.9.2 : nombre de sous-pas où la borne de stabilité du convertisseur a agi (QA-A08).
local converterLimits = 0
-- Borne : après un sous-pas, l'écart pompe/turbine peut changer de signe (dépassement que le
-- schéma explicite faisait déjà) mais son amplitude ne peut pas croître (facteur < 2).
VehicleDynamics.ConverterStabilityFactor = 1.8
function VehicleDynamics.converterLimits(): number
    return converterLimits
end

local function sanitize(state: Types.VehicleRuntimeState, contacts: { Types.WheelContact }): { Types.WheelContact }
    local reset = false
    for _, wheel in state.Wheels do
        if not finite(wheel.AngularVelocity) then
            wheel.AngularVelocity = 0
            reset = true
        end
        if not finite(wheel.LateralForce) then
            wheel.LateralForce = 0
            reset = true
        end
    end
    if not finite(state.EngineOmega) then
        state.EngineOmega = 0
        reset = true
    end
    local out = contacts
    for index, contact in contacts do
        if
            contact.Grounded
            and not (
                finite(contact.LongitudinalVelocity)
                and finite(contact.LateralVelocity)
                and finite(contact.Compression)
                and finite(contact.CompressionVelocity)
            )
        then
            if out == contacts then
                out = table.clone(contacts)
            end
            local ignored = table.clone(contact)
            ignored.Grounded = false
            out[index] = ignored
            reset = true
        end
    end
    if reset then
        numericResets += 1
        local now = os.clock()
        if now - lastResetWarn > 10 then
            lastResetWarn = now
            warn("[AutomotiveWorld] Valeur non finie dans la simulation du véhicule : état neutralisé (QA-A08)")
        end
    end
    return out
end

function VehicleDynamics.step(
    state: Types.VehicleRuntimeState,
    definition: Types.VehicleDefinition,
    input: Types.DriverInput,
    contacts: { Types.WheelContact },
    motion: Types.ChassisMotion,
    dt: number
): { Types.WheelForces }
    contacts = sanitize(state, contacts)
    local powertrain = definition.Powertrain
    local transmission = powertrain.Transmission
    local engine = powertrain.Engine
    local motor = powertrain.Motor
    local tire = definition.Tires
    local brakes = definition.Brakes
    local condition = state.Condition
    local forwardSpeed = motion.Forward
    local h = dt / SUBSTEPS

    -- 1. Boîte (sélection, passages, variateur) et pédales effectives.
    local wheelOmega0 = drivenOmega(state)
    local driveThrottle, brakePedal = Transmission.update(state, powertrain, input, forwardSpeed, wheelOmega0, dt)
    state.DriveThrottle = driveThrottle
    state.BrakePedal = brakePedal
    updateEngineState(state, powertrain, dt)
    -- Couple coupé pendant un passage (allumage coupé, embrayages qui se relaient).
    local torqueThrottle = if state.ShiftTimer > 0 then 0 else driveThrottle

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

    -- 3. Limites d'adhérence de chaque pneu (charge, revêtement, mouillé, dégâts).
    local peakX, peakY, sliding = table.create(4, 0), table.create(4, 0), table.create(4, 0)
    for index, wheel in state.Wheels do
        local contact = contacts[index]
        local normal = normals[index]
        if contact.Grounded and normal > 0 then
            local nominal = VehicleDynamics.nominalCornerLoad(definition, wheel.IsFront)
            local surface = contact.SurfaceFriction * condition.CornerGrip[index]
            -- Humidité effective : maximum (jamais produit) entre la surface
            -- mouillée par conception et la chaussée mouillée par la météo, pour
            -- n'appliquer la réduction d'adhérence qu'une seule fois.
            local wetness = math.max(if contact.Wet then 1 else 0, math.clamp(contact.Wetness or 0, 0, 1))
            surface *= 1 + (tire.WetGripRatio - 1) * wetness
            peakX[index] = TireModel.loadAdjustedFriction(
                tire.PeakFrictionLongitudinal,
                normal,
                nominal,
                tire.LoadSensitivity
            ) * surface * normal
            peakY[index] = TireModel.loadAdjustedFriction(
                tire.PeakFrictionLateral,
                normal,
                nominal,
                tire.LoadSensitivity
            ) * surface * normal
            sliding[index] = tire.SlidingFrictionRatio
                + (tire.WetSlidingFrictionRatio - tire.SlidingFrictionRatio) * wetness
        end
    end

    -- 4. Aides électroniques (décisions sur l'état du pas précédent).
    DriverAids.updateAbs(state, definition, brakePedal > 0.05, forwardSpeed, dt)
    DriverAids.updateTraction(state, definition, dt)
    DriverAids.updateStability(state, definition, motion, input.Handbrake)

    -- 5. Couples de freinage demandés (pédale modulée par l'ABS, frein à main, ESP).
    local requested = table.create(4, 0)
    for index, wheel in state.Wheels do
        local maxTorque = if wheel.IsFront then brakes.MaxTorqueFrontNm else brakes.MaxTorqueRearNm
        requested[index] = brakePedal * maxTorque * wheel.AbsFactor
    end

    -- 6. Récupération électrique : au lâcher (niveau choisi) et au freinage
    --    (freinage combiné : le moteur remplace une part du frein des roues motrices).
    local regenFraction = 0
    local brakeRegenMotorTorque = 0
    local speedRatio = 0
    if motor then
        local levels = motor.RegenLevels
        regenFraction = if state.Gear ~= 0 then levels[math.clamp(state.RegenLevel, 1, #levels)] else 0
        speedRatio = math.abs(forwardSpeed) * 3.6 / motor.TopSpeedKmh
        local overall = math.abs(Transmission.overallRatio(state, transmission))
        if
            overall > 0
            and brakePedal > 0.05
            and not state.AidActivity.Abs
            and state.EnergyAvailable
            and state.EngineRunning
        then
            local wanted = 0
            for index, wheel in state.Wheels do
                if wheel.DriveShare > 0 then
                    wanted += requested[index]
                end
            end
            local motorOmega = math.abs(wheelOmega0 * overall)
            local capacity = Engine.motorRegenTorque(motor, motorOmega) * (1 - regenFraction)
            brakeRegenMotorTorque = math.min(wanted / (overall * transmission.Efficiency), capacity)
            -- Le frein à friction des roues motrices est réduit d'autant.
            local supplied = brakeRegenMotorTorque * overall * transmission.Efficiency
            for index, wheel in state.Wheels do
                if wheel.DriveShare > 0 then
                    requested[index] = math.max(0, requested[index] - supplied * wheel.DriveShare)
                end
            end
        end
    end
    local brakeTorques = table.create(4, 0)
    for index, wheel in state.Wheels do
        local torque = requested[index] + wheel.EscBrakeTorque
        if input.Handbrake and not wheel.IsFront then
            torque += brakes.HandbrakeTorqueNm
        end
        brakeTorques[index] = torque
        wheel.BrakeTorque = torque
    end

    -- 7. Sous-pas couplés : moteur ↔ embrayage/convertisseur ↔ différentiels ↔ roues.
    local mode, capacity = Transmission.coupling(state, powertrain, state.EngineOmega, torqueThrottle)
    state.ClutchCapacityNm = if mode == "Clutch" then capacity else 0
    local converter = transmission.Converter
    if mode == "Converter" and converter then
        local turbineRpm = Engine.rpm(math.abs(wheelOmega0 * Transmission.overallRatio(state, transmission)))
        local idle = if engine then engine.IdleRpm else 0
        if state.Gear < converter.LockupGear or state.ShiftTimer > 0 or turbineRpm < idle * 1.3 then
            state.Coupled = false
        elseif not state.Coupled and state.EngineOmega > 0 then
            local speedRatio2 = Engine.omega(turbineRpm) / state.EngineOmega
            if speedRatio2 > 0.92 and speedRatio2 < 1.08 then
                state.Coupled = true
            end
        end
    elseif mode == "Open" then
        state.Coupled = false
    elseif mode == "Rigid" then
        state.Coupled = true
    end
    local stallTorque = if engine and converter
        then Engine.fullLoadTorque(engine, converter.StallRpm) * condition.EnginePower
        else 0
    local engineInertia = if engine then engine.InertiaKgM2 else (motor :: Types.ElectricMotorDefinition).InertiaKgM2

    local omegas, inertias, wheelTorques = table.create(4, 0), table.create(4, 0), table.create(4, 0)
    local fxSum = table.create(4, 0)
    local slips = table.create(4, 0)
    local sourcePowerSum = 0
    local fuelSum = 0

    for _ = 1, SUBSTEPS do
        local overall = Transmission.overallRatio(state, transmission)
        local inputOmega = drivenOmega(state) * overall
        local rigid = state.Coupled and mode ~= "Open"
        local omegaE = if rigid then math.max(inputOmega, 0) else state.EngineOmega
        if rigid and motor then
            omegaE = inputOmega
        end
        local torque = sourceTorque(state, definition, omegaE, torqueThrottle, regenFraction, speedRatio)
        if brakeRegenMotorTorque > 0 then
            torque -= math.sign(omegaE) * brakeRegenMotorTorque
        end

        -- Embrayage fermé dont la capacité ne suffit plus : il se remet à patiner.
        if rigid and mode == "Clutch" and math.abs(torque) > capacity then
            rigid = false
            state.Coupled = false
        end

        local shaftTorque = 0 -- couple transmis à l'entrée de boîte (côté moteur)
        if mode == "Open" or overall == 0 then
            state.EngineOmega = math.max(0, omegaE + h * torque / engineInertia)
        elseif rigid then
            shaftTorque = torque
            state.EngineOmega = omegaE
        elseif mode == "Clutch" then
            local slip = omegaE - inputOmega
            local clutchTorque = capacity * math.clamp(slip / CLUTCH_LOCK_EPS, -1, 1)
            local nextOmega = math.max(0, omegaE + h * (torque - clutchTorque) / engineInertia)
            shaftTorque = clutchTorque
            state.EngineOmega = nextOmega
            local nextSlip = nextOmega - inputOmega
            if
                capacity > 0
                and math.abs(torque) <= capacity
                and (math.abs(nextSlip) < CLUTCH_LOCK_EPS or math.sign(nextSlip) ~= math.sign(slip))
            then
                state.Coupled = true
            end
        elseif mode == "Converter" and converter then
            local pump, turbine = Transmission.converterTorques(converter, stallTorque, omegaE, inputOmega)
            -- Lot 0.9.2 (QA-A08, cause) : le couple hydraulique croît comme le carré des
            -- vitesses ; intégré explicitement, il pouvait, en un sous-pas, dépasser
            -- l'écart pompe/turbine qu'il réduit et l'inverser en l'amplifiant (roues
            -- motrices lancées, véhicule plaqué, moteur qui cale : 10³ → 10⁶⁶ rad/s → NaN).
            -- Borne de stabilité : le couple ne peut qu'annuler l'écart dans le sous-pas
            -- (inertie du moteur d'un côté, des roues motrices ramenée par le rapport de
            -- l'autre). Inactive en fonctionnement normal (le pas explicite y reste stable).
            local slip = omegaE - inputOmega
            if pump ~= 0 and overall ~= 0 then
                local drivenInertia = 0
                for _, wheel in state.Wheels do
                    if wheel.DriveShare > 0 then
                        drivenInertia += tire.WheelInertiaKgM2
                    end
                end
                local ratio = math.max(turbine / pump, 1)
                local inverseInertia = 1 / engineInertia
                    + overall * overall * transmission.Efficiency * ratio / math.max(drivenInertia, 1e-3)
                local limit = VehicleDynamics.ConverterStabilityFactor * math.abs(slip) / (h * inverseInertia)
                if math.abs(pump) > limit then
                    local scale = limit / math.abs(pump)
                    pump *= scale
                    turbine *= scale
                    converterLimits += 1
                end
            end
            state.EngineOmega = math.max(0, omegaE + h * (torque - pump) / engineInertia)
            shaftTorque = turbine
        end

        -- Couple aux roues (rendement de la transmission) puis différentiels.
        local wheelSideTorque = shaftTorque * overall * transmission.Efficiency
        for index, wheel in state.Wheels do
            omegas[index] = wheel.AngularVelocity
            local inertia = tire.WheelInertiaKgM2
            if state.Coupled and mode ~= "Open" and wheel.DriveShare > 0 then
                -- Inertie du moteur ramenée à la roue par le rapport engagé.
                inertia += engineInertia * overall * overall * wheel.DriveShare
            end
            inertias[index] = inertia
        end
        Driveline.distribute(powertrain.Drivetrain, wheelSideTorque, omegas, inertias, h, wheelTorques)

        for index, wheel in state.Wheels do
            local contact = contacts[index]
            local driveTorque = wheelTorques[index]
            if contact.Grounded and normals[index] > 0 then
                local omega, fx, slip = TireModel.integrateWheel(
                    wheel.AngularVelocity,
                    driveTorque,
                    brakeTorques[index],
                    inertias[index],
                    tire.RadiusM,
                    contact.LongitudinalVelocity,
                    peakX[index],
                    tire.PeakSlipRatio,
                    sliding[index],
                    h,
                    1
                )
                wheel.AngularVelocity = omega
                fxSum[index] += fx
                slips[index] = slip
            else
                wheel.AngularVelocity = TireModel.integrateFreeWheel(
                    wheel.AngularVelocity,
                    driveTorque,
                    brakeTorques[index],
                    inertias[index],
                    h
                )
                slips[index] = 0
            end
        end

        if state.Coupled and mode ~= "Open" then
            -- Moteur solidaire des roues : son régime suit la transmission.
            local newInput = drivenOmega(state) * overall
            state.EngineOmega = if motor then newInput else math.max(newInput, 0)
        end

        -- Calage : moteur entraîné sous son régime de calage.
        if engine and state.EngineRunning and Engine.rpm(state.EngineOmega) < engine.StallRpm then
            state.EngineRunning = false
            state.EngineStalled = true
        end

        sourcePowerSum += torque * state.EngineOmega
        if engine then
            fuelSum += Engine.fuelFlowLps(
                engine,
                powertrain.Energy.Kind,
                state.EngineOmega,
                torque,
                torqueThrottle,
                state.EngineRunning
            )
        end
    end
    state.EngineRpm = Engine.rpm(math.abs(state.EngineOmega))

    -- 8. Efforts au contact : longitudinal (moyenne des sous-pas), latéral,
    --    frottement statique à l'arrêt, ellipse d'adhérence.
    local forces: { Types.WheelForces } = table.create(4)
    for index, wheel in state.Wheels do
        local contact = contacts[index]
        local normal = normals[index]
        local fx, fy = 0, 0
        wheel.SlipRatio = slips[index]
        if contact.Grounded and normal > 0 then
            local vx = contact.LongitudinalVelocity
            local vy = contact.LateralVelocity
            local effectiveMass = normal / GRAVITY
            local fxTire = TireModel.stopClamp(
                fxSum[index] / SUBSTEPS,
                effectiveMass,
                wheel.AngularVelocity * tire.RadiusM - vx,
                dt
            )
            local rolling = TireModel.stopClamp(-math.sign(vx) * tire.RollingResistance * normal, effectiveMass, vx, dt)
            fxTire += rolling

            local slipAngleRef = math.rad(tire.PeakSlipAngleDeg)
            local lateral = TireModel.lateralForce(vy, vx, peakY[index], slipAngleRef, sliding[index])
            wheel.SlipAngle = math.atan2(vy, math.max(math.abs(vx), TireModel.LowSpeedReference))
            -- Glissement combiné : une roue bloquée ou qui patine perd sa force latérale.
            local kx, ky = TireModel.combinedFactors(
                wheel.SlipRatio,
                tire.PeakSlipRatio,
                wheel.SlipAngle,
                slipAngleRef,
                sliding[index]
            )
            fxTire *= kx
            lateral *= ky
            lateral = TireModel.relax(wheel.LateralForce, lateral, vx, tire.RelaxationLengthM, dt)
            wheel.LateralForce = lateral
            lateral = TireModel.stopClamp(lateral, effectiveMass, vy, dt)

            -- Frottement statique : roue retenue par le frein (longitudinal) et
            -- contact quasi immobile (latéral). Il remplace la force de glissement
            -- tant qu'il ne dépasse pas l'adhérence.
            local slow = math.abs(vx) < TireModel.StickSpeed
            local held = math.abs(wheel.AngularVelocity) < 1e-3 and brakeTorques[index] > 0
            if slow and held then
                local force, x = TireModel.stiction(wheel.StickLongitudinal, vx, peakX[index], effectiveMass, dt)
                wheel.StickLongitudinal = x
                if force then
                    fxTire = force
                end
            else
                wheel.StickLongitudinal = 0
            end
            if slow and math.abs(vy) < TireModel.StickSpeed then
                local force, y = TireModel.stiction(wheel.StickLateral, vy, peakY[index], effectiveMass, dt)
                wheel.StickLateral = y
                if force then
                    lateral = force
                    wheel.LateralForce = force
                end
            else
                wheel.StickLateral = 0
            end

            fx, fy = TireModel.combine(fxTire, lateral, peakX[index], peakY[index])
        else
            wheel.StickLongitudinal = 0
            wheel.StickLateral = 0
            wheel.LateralForce = 0
            wheel.SlipAngle = 0
        end
        wheel.SpinAngle = (wheel.SpinAngle + wheel.AngularVelocity * dt) % TWO_PI
        forces[index] = { Normal = normal, Longitudinal = fx, Lateral = fy }
    end

    -- 9. Énergie de la session (estimation locale ; le serveur fait foi).
    local mechanicalKw = sourcePowerSum / SUBSTEPS / 1000
    state.EnginePowerKw = mechanicalKw
    if engine then
        local flow = fuelSum / SUBSTEPS
        state.EnergyUsed += flow * dt
        state.PowerKw = math.max(mechanicalKw, 0)
    elseif motor then
        local batteryKw = Engine.batteryPowerKw(motor, mechanicalKw, state.EngineRunning)
        state.PowerKw = batteryKw
        if batteryKw >= 0 then
            state.EnergyUsed += batteryKw * dt / 3600
        else
            state.EnergyRecovered += -batteryKw * dt / 3600
        end
    end

    return forces
end

return table.freeze(VehicleDynamics)
