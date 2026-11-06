--!strict
--[[
    Volants qui tournent (lot ANIM-01), pour TOUS les véhicules visibles par ce client. Purement visuel :
    `Motor6D.Transform` n'est pas répliqué et le volant n'a ni masse ni collision.

    Angle du volant = angle des roues avant × rapport du modèle (`Shared.Vehicles.SteeringWheel`) :
    - véhicule piloté par ce client : position de crémaillère de la simulation locale (`SteerPosition`), exacte ;
    - autres véhicules : consigne répliquée par le serveur (`VisualSteer`), lissée à la vitesse de la crémaillère.
    L'angle des roues dépend de la vitesse (`VehicleDynamics.maxSteerAngle`), comme pour l'affichage des roues.

    Appelé par `SeatPoseController` au début de chaque pas (PreSimulation), juste avant les mains du conducteur :
    volant et mains utilisent le même angle dans la même image. `angleFor` rend 0 tant que la pièce du volant n'est
    pas articulée (gabarit sans volant séparé) : les mains restent alors à 9 h 15 sur un volant fixe.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehiclesShared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Vehicles")
local Constants = require(VehiclesShared:WaitForChild("VehicleConstants"))
local Types = require(VehiclesShared:WaitForChild("VehicleTypes"))
local VehicleDefinitions = require(VehiclesShared:WaitForChild("VehicleDefinitions"))
local VehicleDynamics = require(VehiclesShared:WaitForChild("Physics"):WaitForChild("VehicleDynamics"))
local MeshKitData = require(VehiclesShared:WaitForChild("MeshKitData"))
local SteeringWheel = require(VehiclesShared:WaitForChild("SteeringWheel"))

local SteeringWheelVisuals = {}

local METERS_PER_STUD = Constants.MetersPerStud

type Cache = {
    Definition: Types.VehicleDefinition,
    Spec: SteeringWheel.Spec,
    Root: BasePart,
    Joint: Motor6D?,
    Steer: number, -- consigne lissée (−1 à 1), autres véhicules
    Angle: number, -- angle courant du volant (radians, positif à droite)
}

-- Tables à clés faibles : un véhicule détruit libère son entrée.
local caches: { [Model]: Cache } = setmetatable({}, { __mode = "k" }) :: any
local localModel: Model? = nil
local localState: Types.VehicleRuntimeState? = nil

local function buildCache(model: Model): Cache?
    local root = model.PrimaryPart
    local definitionId = model:GetAttribute(Constants.Attributes.DefinitionId)
    if root == nil or type(definitionId) ~= "string" then
        return nil
    end
    local definition = VehicleDefinitions.get(definitionId)
    local kit = MeshKitData.Kits[definitionId]
    local spec = kit and kit.SteeringWheel
    if definition == nil or spec == nil then
        return nil
    end
    return { Definition = definition, Spec = spec, Root = root, Joint = nil, Steer = 0, Angle = 0 }
end

-- Articulation du volant (posée par le serveur), recherchée tant qu'elle n'est pas répliquée.
local function findJoint(model: Model, cache: Cache): Motor6D?
    local joint = cache.Joint
    if joint and joint.Parent then
        return joint
    end
    local part = model:FindFirstChild(cache.Spec.Part, true)
    local found = if part then part:FindFirstChild(SteeringWheel.JointName) else nil
    cache.Joint = if found and found:IsA("Motor6D") then found else nil
    return cache.Joint
end

-- Véhicule simulé par ce client (nil en fin de conduite) : son état est relu à chaque pas (référence vivante).
function SteeringWheelVisuals.setLocal(model: Model?, state: Types.VehicleRuntimeState?)
    localModel = model
    localState = state
end

function SteeringWheelVisuals.update(dt: number)
    for _, instance in CollectionService:GetTagged(Constants.VehicleTag) do
        if not instance:IsA("Model") then
            continue
        end
        local model = instance :: Model
        local cache: Cache? = caches[model]
        if cache == nil then
            -- Nouvelle tentative à chaque pas tant que le véhicule est incomplet (réplication en cours).
            local built = buildCache(model)
            if built == nil then
                continue
            end
            caches[model] = built
            cache = built
        end
        local current = cache :: Cache
        local joint = findJoint(model, current)
        if joint == nil then
            current.Angle = 0
            continue
        end
        local root = current.Root
        local definition = current.Definition
        local forwardSpeed = root.AssemblyLinearVelocity:Dot(root.CFrame.LookVector) * METERS_PER_STUD
        local steer: number
        if model == localModel and localState then
            steer = localState.SteerPosition
            current.Steer = steer
        else
            local visual = model:GetAttribute(Constants.Attributes.VisualSteer)
            local target = if type(visual) == "number" then math.clamp(visual, -1, 1) else 0
            -- Vitesse de la crémaillère, en fraction de course par seconde.
            local rate = definition.Steering.RackSpeedDegPerS / definition.Steering.MaxAngleDeg
            current.Steer = SteeringWheel.approach(current.Steer, target, rate, dt)
            steer = current.Steer
        end
        local road = steer * VehicleDynamics.maxSteerAngle(definition, forwardSpeed)
        current.Angle = SteeringWheel.wheelAngle(road, current.Spec.Ratio)
        joint.Transform = SteeringWheel.jointTransform(current.Angle)
    end
end

-- Angle courant du volant d'un véhicule (radians, positif à droite) ; 0 si son volant n'est pas articulé.
function SteeringWheelVisuals.angleFor(model: Model): number
    local cache = caches[model]
    return if cache then cache.Angle else 0
end

return SteeringWheelVisuals
