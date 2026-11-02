--!strict
-- Adaptateur Roblox de la dynamique pure.
--
-- Il est exécuté UNIQUEMENT par le propriétaire réseau du véhicule :
-- - le client du conducteur pendant la conduite (réactivité immédiate) ;
-- - le serveur pour un véhicule stationné ou en cours de correction.
-- Chaque instance ne manipule que SON véhicule : plusieurs véhicules
-- coexistent sans partager d'état.
--
-- À chaque pas : sondes de suspension (rayon ou balayage de sphère) → contacts
-- (en mètres) → `VehicleDynamics.step` → forces appliquées via des VectorForce
-- aux points de contact. Le moteur physique Roblox intègre masse et inertie.
-- L'état fixé par le serveur (aides activées, récupération, dégâts) est lu dans
-- les attributs du modèle : le client ne le décide jamais seul.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Types = require(script.Parent.VehicleTypes)
local Constants = require(script.Parent.VehicleConstants)
local VehicleDynamics = require(script.Parent.Physics.VehicleDynamics)
local SurfaceFriction = require(script.Parent.Physics.SurfaceFriction)
local DamageModel = require(script.Parent.Physics.DamageModel)
local PerfStats = require(script.Parent.PerfStats)

local METERS_PER_STUD = Constants.MetersPerStud
local STUDS_PER_METER = 1 / METERS_PER_STUD
local FILTER_REFRESH_S = 1
local SERVER_STATE_REFRESH_S = 0.1
local MAX_STEP_S = 1 / 20
local PERF_WINDOW = 600

export type WheelRig = {
    Name: string,
    Origin: Attachment,
    Contact: Attachment,
    Force: VectorForce,
}

export type Telemetry = {
    SpeedKmh: number,
    ForwardSpeedMs: number,
    Gear: number,
    EngineRpm: number,
    DriveThrottle: number,
    BrakePedal: number,
    SteerPosition: number,
    GroundedWheels: number,
    ClutchPedal: number,
    EngineRunning: boolean,
    EngineStalled: boolean,
    PowerKw: number,
    YawRate: number,
    WetWheels: number,
}

export type Options = {
    -- Côté serveur : n'écrire une propriété que si elle change sensiblement,
    -- pour limiter la réplication réseau des véhicules stationnés.
    ReplicationFriendly: boolean?,
}

-- Coût de la simulation de CE véhicule (secondes) et des requêtes physiques.
export type PerfReport = {
    Step: PerfStats.Summary,
    Queries: PerfStats.Summary,
    QueriesPerStep: number,
    Probe: Types.ContactProbe,
    SphereFallbacks: number,
}

local VehicleSimulator = {}
VehicleSimulator.__index = VehicleSimulator

type SimulatorFields = {
    Model: Model,
    Root: BasePart,
    Definition: Types.VehicleDefinition,
    State: Types.VehicleRuntimeState,
    Rigs: { WheelRig },
    BodyForce: VectorForce,
    RaycastParams: RaycastParams,
    FilterTimer: number,
    ServerStateTimer: number,
    ReplicationFriendly: boolean,
    Contacts: { Types.WheelContact },
    Motion: Types.ChassisMotion,
    Telemetry: Telemetry,
    Probe: Types.ContactProbe,
    StepTimes: PerfStats.Window,
    QueryTimes: PerfStats.Window,
    QueriesLastStep: number,
    SphereFallbacks: number,
}

export type VehicleSimulator = typeof(setmetatable({} :: SimulatorFields, VehicleSimulator))

local function requireChild<T>(parent: Instance, name: string, className: string): T
    local child = parent:FindFirstChild(name)
    assert(child and child:IsA(className), "Élément de véhicule manquant : " .. name .. " (" .. className .. ")")
    return (child :: any) :: T
end

function VehicleSimulator.new(model: Model, definition: Types.VehicleDefinition, options: Options?): VehicleSimulator
    local root = model.PrimaryPart
    assert(root, "Le véhicule doit avoir un PrimaryPart (châssis)")

    local rigs: { WheelRig } = {}
    local contacts: { Types.WheelContact } = {}
    for index, name in Constants.WheelNames do
        rigs[index] = {
            Name = name,
            Origin = requireChild(root, "Suspension" .. name, "Attachment"),
            Contact = requireChild(root, "Contact" .. name, "Attachment"),
            Force = requireChild(root, "TireForce" .. name, "VectorForce"),
        }
        contacts[index] = {
            Grounded = false,
            Compression = 0,
            CompressionVelocity = 0,
            LongitudinalVelocity = 0,
            LateralVelocity = 0,
            SurfaceFriction = 1,
            Wet = false,
        }
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.RespectCanCollide = true
    params.IgnoreWater = true

    local self: SimulatorFields = {
        Model = model,
        Root = root,
        Definition = definition,
        State = VehicleDynamics.createState(definition),
        Rigs = rigs,
        BodyForce = requireChild(root, "BodyForce", "VectorForce"),
        RaycastParams = params,
        FilterTimer = 0,
        ServerStateTimer = math.huge,
        ReplicationFriendly = options ~= nil and options.ReplicationFriendly == true,
        Contacts = contacts,
        Motion = { Forward = 0, Lateral = 0, YawRate = 0 },
        Telemetry = {
            SpeedKmh = 0,
            ForwardSpeedMs = 0,
            Gear = 0,
            EngineRpm = 0,
            DriveThrottle = 0,
            BrakePedal = 0,
            SteerPosition = 0,
            GroundedWheels = 0,
            ClutchPedal = 0,
            EngineRunning = false,
            EngineStalled = false,
            PowerKw = 0,
            YawRate = 0,
            WetWheels = 0,
        },
        Probe = definition.Suspension.ContactProbe,
        StepTimes = PerfStats.new(PERF_WINDOW),
        QueryTimes = PerfStats.new(PERF_WINDOW),
        QueriesLastStep = 0,
        SphereFallbacks = 0,
    }
    local simulator = setmetatable(self, VehicleSimulator)
    simulator:refreshFilter()
    simulator:refreshServerState()
    return simulator
end

-- Les sondes ignorent le véhicule lui-même et les personnages
-- (un piéton ne doit pas servir de « sol » à une roue).
function VehicleSimulator.refreshFilter(self: VehicleSimulator)
    local excluded: { Instance } = { self.Model }
    for _, player in Players:GetPlayers() do
        local character = player.Character
        if character then
            table.insert(excluded, character)
        end
    end
    self.RaycastParams.FilterDescendantsInstances = excluded
end

--[[
    Relit l'état fixé par le serveur dans les attributs du modèle : aides
    activées (seulement si le modèle en est équipé), niveau de récupération,
    conséquences mécaniques des dégâts. Une valeur absente vaut « désactivé »
    ou « intact ».
]]
function VehicleSimulator.refreshServerState(self: VehicleSimulator)
    local model = self.Model
    local state = self.State
    local aids = self.Definition.Aids
    state.Aids.Abs = aids.Abs and model:GetAttribute(Constants.Attributes.AidAbs) == true
    state.Aids.TractionControl = aids.TractionControl
        and model:GetAttribute(Constants.Attributes.AidTractionControl) == true
    state.Aids.StabilityControl = aids.StabilityControl
        and model:GetAttribute(Constants.Attributes.AidStabilityControl) == true
    local regen = model:GetAttribute(Constants.Attributes.RegenLevel)
    local motor = self.Definition.Powertrain.Motor
    if motor and type(regen) == "number" then
        state.RegenLevel = math.clamp(math.floor(regen), 1, #motor.RegenLevels)
    end
    state.Condition = DamageModel.condition(DamageModel.fromAttributes(function(name)
        return model:GetAttribute(name)
    end))
    -- Sonde forcée par les essais comparatifs (Studio uniquement).
    if RunService:IsStudio() then
        local forced = model:GetAttribute("AWTestProbe")
        self.Probe = if forced == "Sphere" or forced == "Ray" then forced else self.Definition.Suspension.ContactProbe
    end
end

local function writeForce(force: VectorForce, value: Vector3, threshold: number)
    if threshold <= 0 or (force.Force - value).Magnitude > threshold then
        force.Force = value
    end
end

local function writePosition(attachment: Attachment, value: Vector3, threshold: number)
    if threshold <= 0 or (attachment.Position - value).Magnitude > threshold then
        attachment.Position = value
    end
end

local function isWet(part: Instance): boolean
    return part:GetAttribute(Constants.WetSurfaceAttribute) == true
end

-- Mise en marche (le conducteur est à bord). Voir VehicleDynamics.startEngine.
function VehicleSimulator.startEngine(self: VehicleSimulator): boolean
    return VehicleDynamics.startEngine(self.State, self.Definition)
end

-- Demande de passage du conducteur (boîtes à sélecteur).
function VehicleSimulator.requestShift(self: VehicleSimulator, direction: number): string
    return VehicleDynamics.requestShift(self.State, self.Definition, direction, self.Motion.Forward)
end

function VehicleSimulator.step(self: VehicleSimulator, input: Types.DriverInput, rawDt: number)
    local started = os.clock()
    -- Un pas trop long (saccade) est borné pour éviter toute divergence.
    local dt = math.clamp(rawDt, 1 / 1000, MAX_STEP_S)
    local root = self.Root
    local definition = self.Definition
    local state = self.State

    self.FilterTimer += dt
    if self.FilterTimer >= FILTER_REFRESH_S then
        self.FilterTimer = 0
        self:refreshFilter()
    end
    self.ServerStateTimer += dt
    if self.ServerStateTimer >= SERVER_STATE_REFRESH_S then
        self.ServerStateTimer = 0
        self:refreshServerState()
    end

    local cframe = root.CFrame
    local up = cframe.UpVector
    local look = cframe.LookVector
    local right = cframe.RightVector
    local linearVelocity = root.AssemblyLinearVelocity
    local forwardSpeed = linearVelocity:Dot(look) * METERS_PER_STUD
    local motion = self.Motion
    motion.Forward = forwardSpeed
    motion.Lateral = linearVelocity:Dot(right) * METERS_PER_STUD
    -- Vitesse angulaire autour du haut : positive vers la gauche dans Roblox.
    motion.YawRate = -root.AssemblyAngularVelocity:Dot(up)

    -- Conversion newtons → force Roblox. On rapporte l'accélération réelle
    -- (F / masse en kg) à la masse Roblox de l'ensemble, en studs/s².
    local assemblyMass = root.AssemblyMass
    local forceScale = assemblyMass / (definition.Chassis.MassKg * METERS_PER_STUD)
    local forceThreshold = if self.ReplicationFriendly then assemblyMass * 0.35 else 0
    local positionThreshold = if self.ReplicationFriendly then 0.05 else 0

    VehicleDynamics.updateSteering(state, definition, input.Steer, forwardSpeed, dt)

    local contactPositions: { Vector3 } = table.create(4)
    local contactAxes: { { Vector3 } } = table.create(4)
    local grounded, wetWheels, queries = 0, 0, 0
    local queryTime = 0
    local tireRadius = definition.Tires.RadiusM
    local useSphere = self.Probe == "Sphere"

    for index, rig in self.Rigs do
        local wheel = state.Wheels[index]
        local axle = if wheel.IsFront then definition.Suspension.Front else definition.Suspension.Rear
        local rayLength = (axle.RestLengthM + tireRadius) * STUDS_PER_METER
        local origin = rig.Origin.WorldPosition
        local contact = self.Contacts[index]

        -- Sonde : la sphère (rayon du pneu) épouse bordures et arêtes avant que
        -- l'axe de la roue ne les atteigne ; elle ne voit pas un obstacle déjà
        -- au contact au départ du balayage (talonnage) : on retombe alors sur le rayon.
        local queryStart = os.clock()
        local result: RaycastResult? = nil
        local distance = 0
        if useSphere then
            queries += 1
            local sweep = axle.RestLengthM * STUDS_PER_METER
            local hit = Workspace:Spherecast(origin, tireRadius * STUDS_PER_METER, -up * sweep, self.RaycastParams)
            if hit then
                result = hit
                distance = hit.Distance + tireRadius * STUDS_PER_METER
            end
        end
        if result == nil then
            queries += 1
            local hit = Workspace:Raycast(origin, -up * rayLength, self.RaycastParams)
            if hit then
                result = hit
                distance = hit.Distance
                if useSphere then
                    self.SphereFallbacks += 1
                end
            end
        end
        queryTime += os.clock() - queryStart

        if result then
            grounded += 1
            local hitPosition = result.Position
            local normal = result.Normal
            local pointVelocity = root:GetVelocityAtPosition(hitPosition)
            local hitPart = result.Instance
            if hitPart:IsA("BasePart") and not hitPart.Anchored then
                pointVelocity -= hitPart:GetVelocityAtPosition(hitPosition)
            end

            -- Axe de la roue braquée, projeté sur le plan du sol.
            local steer = wheel.SteerAngle
            local heading = look * math.cos(steer) + right * math.sin(steer)
            local forwardOnGround = heading - normal * heading:Dot(normal)
            if forwardOnGround.Magnitude < 1e-3 then
                forwardOnGround = look
            end
            forwardOnGround = forwardOnGround.Unit
            local sideOnGround = forwardOnGround:Cross(normal).Unit

            local maxCompression = axle.TravelM * 1.2
            contact.Grounded = true
            contact.Compression = math.clamp((rayLength - distance) * METERS_PER_STUD, 0, maxCompression)
            contact.CompressionVelocity = -pointVelocity:Dot(up) * METERS_PER_STUD
            contact.LongitudinalVelocity = pointVelocity:Dot(forwardOnGround) * METERS_PER_STUD
            contact.LateralVelocity = pointVelocity:Dot(sideOnGround) * METERS_PER_STUD
            contact.SurfaceFriction = SurfaceFriction.forMaterialName(result.Material.Name)
            contact.Wet = isWet(hitPart)
            if contact.Wet then
                wetWheels += 1
            end

            contactPositions[index] = hitPosition
            contactAxes[index] = { forwardOnGround, sideOnGround }
        else
            contact.Grounded = false
            contact.Compression = 0
            contact.CompressionVelocity = 0
            contact.LongitudinalVelocity = 0
            contact.LateralVelocity = 0
            contact.SurfaceFriction = 1
            contact.Wet = false
        end
    end

    local forces = VehicleDynamics.step(state, definition, input, self.Contacts, motion, dt)

    for index, rig in self.Rigs do
        local wheelForces = forces[index]
        local position = contactPositions[index]
        if self.Contacts[index].Grounded and position then
            local axes = contactAxes[index]
            local worldNewtons = up * wheelForces.Normal
                + axes[1] * wheelForces.Longitudinal
                + axes[2] * wheelForces.Lateral
            writePosition(rig.Contact, cframe:PointToObjectSpace(position), positionThreshold)
            writeForce(rig.Force, worldNewtons * forceScale, forceThreshold)
        else
            writeForce(rig.Force, Vector3.zero, forceThreshold)
        end
    end

    -- Traînée aérodynamique (N) et compensation de gravité : le véhicule
    -- subit 9,81 m/s² réels quelle que soit la valeur de Workspace.Gravity.
    local velocityMs = linearVelocity * METERS_PER_STUD
    local speedMs = velocityMs.Magnitude
    local drag = -velocityMs * (0.5 * Constants.AirDensity * definition.Chassis.DragAreaM2 * speedMs)
    local targetGravity = Constants.StandardGravity * STUDS_PER_METER
    local gravityCompensation = Vector3.yAxis * (assemblyMass * (Workspace.Gravity - targetGravity))
    writeForce(self.BodyForce, drag * forceScale + gravityCompensation, forceThreshold)

    local telemetry = self.Telemetry
    telemetry.SpeedKmh = speedMs * 3.6
    telemetry.ForwardSpeedMs = forwardSpeed
    telemetry.Gear = state.Gear
    telemetry.EngineRpm = state.EngineRpm
    telemetry.DriveThrottle = state.DriveThrottle
    telemetry.BrakePedal = state.BrakePedal
    telemetry.SteerPosition = state.SteerPosition
    telemetry.GroundedWheels = grounded
    telemetry.ClutchPedal = state.ClutchPedal
    telemetry.EngineRunning = state.EngineRunning
    telemetry.EngineStalled = state.EngineStalled
    telemetry.PowerKw = state.PowerKw
    telemetry.YawRate = motion.YawRate
    telemetry.WetWheels = wetWheels

    self.QueriesLastStep = queries
    PerfStats.add(self.QueryTimes, queryTime)
    PerfStats.add(self.StepTimes, os.clock() - started)
end

-- Annule localement toutes les forces (fin de conduite côté client).
function VehicleSimulator.release(self: VehicleSimulator)
    for _, rig in self.Rigs do
        rig.Force.Force = Vector3.zero
    end
    self.BodyForce.Force = Vector3.zero
end

function VehicleSimulator.getTelemetry(self: VehicleSimulator): Telemetry
    return self.Telemetry
end

function VehicleSimulator.getPerf(self: VehicleSimulator): PerfReport
    return {
        Step = PerfStats.summary(self.StepTimes),
        Queries = PerfStats.summary(self.QueryTimes),
        QueriesPerStep = self.QueriesLastStep,
        Probe = self.Probe,
        SphereFallbacks = self.SphereFallbacks,
    }
end

function VehicleSimulator.resetPerf(self: VehicleSimulator)
    PerfStats.reset(self.StepTimes)
    PerfStats.reset(self.QueryTimes)
    self.SphereFallbacks = 0
end

return VehicleSimulator
