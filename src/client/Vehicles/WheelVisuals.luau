--!strict
-- Animation locale des roues (suspension, braquage, rotation) pour TOUS les
-- véhicules visibles par ce client. Purement visuel : Motor6D.Transform n'est
-- pas répliqué et n'a aucun effet sur la physique.
-- - Véhicule piloté localement : valeurs exactes de la simulation.
-- - Autres véhicules : estimation locale (rayons, vitesse répliquée, attribut
--   de braquage fourni par le serveur).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local VehiclesShared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Vehicles")
local Types = require(VehiclesShared:WaitForChild("VehicleTypes"))
local Constants = require(VehiclesShared:WaitForChild("VehicleConstants"))
local VehicleDefinitions = require(VehiclesShared:WaitForChild("VehicleDefinitions"))
local VehicleDynamics = require(VehiclesShared:WaitForChild("Physics"):WaitForChild("VehicleDynamics"))

local WheelVisuals = {}

local METERS_PER_STUD = Constants.MetersPerStud
local STUDS_PER_METER = 1 / METERS_PER_STUD
local MAX_DISTANCE_STUDS = 350

type WheelCache = {
    Joint: Motor6D,
    Origin: Attachment,
    IsFront: boolean,
    StaticCompression: number,
    RayLength: number,
    Spin: number,
}

type VehicleCache = {
    Definition: Types.VehicleDefinition,
    Root: BasePart,
    Wheels: { WheelCache },
}

-- Table à clés faibles : un véhicule détruit libère son entrée.
local caches: { [Model]: VehicleCache } = setmetatable({}, { __mode = "k" }) :: any

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true

local function buildCache(model: Model): VehicleCache?
    local root = model.PrimaryPart
    local definitionId = model:GetAttribute(Constants.Attributes.DefinitionId)
    local definition = if type(definitionId) == "string" then VehicleDefinitions.get(definitionId) else nil
    if root == nil or definition == nil then
        return nil
    end
    local layout = VehicleDynamics.wheelLayout(definition)
    local wheels: { WheelCache } = {}
    for index, name in Constants.WheelNames do
        local wheel = model:FindFirstChild("Wheel" .. name)
        local joint = if wheel then wheel:FindFirstChild("Joint") else nil
        local origin = root:FindFirstChild("Suspension" .. name)
        if not (joint and joint:IsA("Motor6D") and origin and origin:IsA("Attachment")) then
            return nil
        end
        local isFront = layout[index].IsFront
        local axle = if isFront then definition.Suspension.Front else definition.Suspension.Rear
        wheels[index] = {
            Joint = joint,
            Origin = origin,
            IsFront = isFront,
            StaticCompression = VehicleDynamics.staticCompression(definition, isFront),
            RayLength = (axle.RestLengthM + definition.Tires.RadiusM) * STUDS_PER_METER,
            Spin = 0,
        }
    end
    return { Definition = definition, Root = root, Wheels = wheels }
end

local function getCache(model: Model): VehicleCache?
    local cached: VehicleCache? = caches[model]
    if cached then
        return cached
    end
    -- Nouvelle tentative à chaque image tant que le véhicule est incomplet
    -- (réplication en cours) : coût négligeable.
    local built = buildCache(model)
    if built then
        caches[model] = built
    end
    return built
end

local function applyTransform(wheel: WheelCache, compression: number, steer: number, spin: number)
    local offset = (compression - wheel.StaticCompression) * STUDS_PER_METER
    -- Rotation négative autour de X = roulement vers l'avant (-Z).
    wheel.Joint.Transform = CFrame.new(0, offset, 0) * CFrame.Angles(0, -steer, 0) * CFrame.Angles(-spin, 0, 0)
end

--[[
    Met à jour les roues de tous les véhicules proches.
    `localModel` / `localState` : véhicule simulé par ce client (peut être nil).
]]
function WheelVisuals.update(
    dt: number,
    cameraPosition: Vector3,
    localModel: Model?,
    localState: Types.VehicleRuntimeState?
)
    for _, instance in CollectionService:GetTagged(Constants.VehicleTag) do
        if not instance:IsA("Model") then
            continue
        end
        local model = instance :: Model
        local cache = getCache(model)
        if cache == nil or cache.Root.Parent == nil then
            continue
        end
        local root = cache.Root
        if (root.Position - cameraPosition).Magnitude > MAX_DISTANCE_STUDS then
            continue
        end

        if model == localModel and localState then
            for index, wheel in cache.Wheels do
                local runtime = localState.Wheels[index]
                applyTransform(wheel, runtime.Compression, runtime.SteerAngle, runtime.SpinAngle)
            end
        else
            local definition = cache.Definition
            local cframe = root.CFrame
            local forwardSpeed = root.AssemblyLinearVelocity:Dot(cframe.LookVector) * METERS_PER_STUD
            local visualSteer = model:GetAttribute(Constants.Attributes.VisualSteer)
            local steerInput = if type(visualSteer) == "number" then math.clamp(visualSteer, -1, 1) else 0
            local steerAngle = steerInput * VehicleDynamics.maxSteerAngle(definition, forwardSpeed)
            params.FilterDescendantsInstances = { model }
            for _, wheel in cache.Wheels do
                local result = Workspace:Raycast(wheel.Origin.WorldPosition, -cframe.UpVector * wheel.RayLength, params)
                local compression = if result
                    then math.max(0, (wheel.RayLength - result.Distance) * METERS_PER_STUD)
                    else 0
                wheel.Spin = (wheel.Spin + forwardSpeed / definition.Tires.RadiusM * dt) % (2 * math.pi)
                applyTransform(wheel, compression, if wheel.IsFront then steerAngle else 0, wheel.Spin)
            end
        end
    end
end

return WheelVisuals
