--!strict
--[[
    Portières et glissé d'entrée / de sortie (lot ANIM-02), côté client. Purement visuel : `Motor6D.Transform` n'est pas
    répliqué et les portes n'ont ni masse ni collision.

    Pour TOUS les véhicules visibles par ce client : angle de chaque porte articulée déduit de l'état répliqué par le
    serveur (attribut texte du modèle, temps du serveur), adouci (`Shared.Vehicles.Doors`). Tous les joueurs voient donc
    la même porte au même moment, sans réplication par image.

    Glissé des personnages : `SeatPoseController` demande à chaque pas le décalage du corps d'un personnage assis
    (`glideOffset`) et l'applique à son articulation `Root` (le HumanoidRootPart reste soudé au siège).

    Joueur local :
    - marche jusqu'à la porte quand le serveur la demande (attribut `ApproachAttribute` de son personnage) ;
    - passager d'un véhicule à portières : la touche de saut (Espace, bouton A) est interceptée et devient une demande de
      sortie au serveur, qui joue la séquence (le saut du moteur libérait le siège sur-le-champ, sans porte) ; le bouton
      de saut tactile n'est pas intercepté (sortie immédiate, porte entrouverte par le serveur) ;
    - fin de sortie : dès que le siège est libéré, le personnage est posé au point de dépôt (celui où son corps a
      glissé), sans attendre le placement du serveur, qui vérifie ensuite le même point.

    Appelé par `SeatPoseController` au début de chaque pas (PreSimulation).
]]

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local VehiclesShared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Vehicles")
local Constants = require(VehiclesShared:WaitForChild("VehicleConstants"))
local MeshKitData = require(VehiclesShared:WaitForChild("MeshKitData"))
local Doors = require(VehiclesShared:WaitForChild("Doors"))

local DoorVisuals = {}

local EXIT_ACTION = "AWPortiereSortie"
-- Fin de sortie : poids du glissé à partir duquel le corps est considéré au point de dépôt.
local OUT_DONE_WEIGHT = 0.95

-- Raw/State : dernier état lu (texte) et son décodage, relu seulement quand le texte change.
type DoorCache = { Spec: Doors.Spec, Joint: Motor6D?, Raw: string?, State: Doors.State? }

-- Tables à clés faibles : un véhicule détruit libère son entrée.
local caches: { [Model]: { [string]: DoorCache } } = setmetatable({}, { __mode = "k" }) :: any

local exitBound = false
local lastSeat: BasePart? = nil
local approachTarget: Vector3? = nil

local function serverNow(): number
    return Workspace:GetServerTimeNow()
end

-- Véhicule d'une pièce : premier ancêtre portant l'identifiant de définition.
local function vehicleOf(part: Instance): Model?
    local node = part.Parent
    while node and node ~= Workspace do
        if node:IsA("Model") and node:GetAttribute(Constants.Attributes.DefinitionId) ~= nil then
            return node
        end
        node = node.Parent
    end
    return nil
end

local function doorsOf(model: Model): { [string]: DoorCache }?
    local existing = caches[model]
    if existing then
        return existing
    end
    local definitionId = model:GetAttribute(Constants.Attributes.DefinitionId)
    local kit = if type(definitionId) == "string" then MeshKitData.Kits[definitionId] else nil
    local pair = kit and kit.Doors
    if pair == nil then
        return nil
    end
    local built: { [string]: DoorCache } = {}
    for _, item in Doors.Roles do
        -- Rôle relu en type singleton (le gel générique du module l'élargit en `string`).
        local role: Doors.Role = if item == "Driver" then "Driver" else "Passenger"
        built[role] = { Spec = pair[role], Joint = nil, Raw = nil, State = nil }
    end
    caches[model] = built
    return built
end

-- Articulation de la porte (posée par le serveur), recherchée tant qu'elle n'est pas répliquée.
local function findJoint(model: Model, role: Doors.Role, cache: DoorCache): Motor6D?
    local joint = cache.Joint
    if joint and joint.Parent then
        return joint
    end
    local hinge = model:FindFirstChild(Doors.HingeName[role], true)
    local found = if hinge then hinge:FindFirstChild(Doors.JointName) else nil
    cache.Joint = if found and found:IsA("Motor6D") then found else nil
    return cache.Joint
end

local function updateDoors(now: number)
    for _, instance in CollectionService:GetTagged(Constants.VehicleTag) do
        if not instance:IsA("Model") then
            continue
        end
        local model = instance :: Model
        local doors = doorsOf(model)
        if doors == nil then
            continue
        end
        for _, item in Doors.Roles do
            -- Rôle relu en type singleton (le gel générique du module l'élargit en `string`).
            local role: Doors.Role = if item == "Driver" then "Driver" else "Passenger"
            local cache = doors[role]
            local joint = findJoint(model, role, cache)
            if joint == nil then
                continue
            end
            local raw = model:GetAttribute(Doors.DoorAttribute[role])
            local text = if type(raw) == "string" then raw else nil
            if text ~= cache.Raw then
                cache.Raw = text
                cache.State = Doors.decode(text)
            end
            -- Réécrit à chaque pas, comme les roues et les volants.
            joint.Transform = Doors.jointTransform(Doors.angle(cache.Spec, Doors.fraction(cache.State, now)))
        end
    end
end

-- Décalage (monde) du corps d'un personnage assis sur `seat`, ou nil : glissé d'entrée ou de sortie en cours.
function DoorVisuals.glideOffset(character: Model, seat: BasePart): Vector3?
    local glide = Doors.decodeGlide(character:GetAttribute(Doors.GlideAttribute))
    if glide == nil then
        return nil
    end
    local model = vehicleOf(seat)
    local root = model and model.PrimaryPart
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if root == nil or hrp == nil or not hrp:IsA("BasePart") then
        return nil
    end
    return Doors.glideOffset(glide, serverNow(), root.CFrame, hrp.Position)
end

local function exitRemote(): RemoteEvent?
    local folder = ReplicatedStorage:FindFirstChild(Constants.RemotesFolderName)
    local remote = folder and folder:FindFirstChild(Doors.RemoteName)
    return if remote and remote:IsA("RemoteEvent") then remote else nil
end

local function onExitAction(_name: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
    if state == Enum.UserInputState.Begin then
        local remote = exitRemote()
        if remote then
            remote:FireServer(Doors.ExitRequest)
        end
    end
    return Enum.ContextActionResult.Sink
end

local function setExitBinding(wanted: boolean)
    if wanted == exitBound then
        return
    end
    exitBound = wanted
    if wanted then
        ContextActionService:BindActionAtPriority(
            EXIT_ACTION,
            onExitAction,
            false,
            Enum.ContextActionPriority.High.Value,
            Enum.KeyCode.Space,
            Enum.KeyCode.ButtonA
        )
    else
        ContextActionService:UnbindAction(EXIT_ACTION)
    end
end

local function hasAnyDoor(model: Model): boolean
    for _, item in Doors.Roles do
        -- Rôle relu en type singleton (le gel générique du module l'élargit en `string`).
        local role: Doors.Role = if item == "Driver" then "Driver" else "Passenger"
        if model:FindFirstChild(Doors.HingeName[role], true) then
            return true
        end
    end
    return false
end

local function updateLocal()
    local character = Players.LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if character == nil or humanoid == nil then
        setExitBinding(false)
        lastSeat = nil
        approachTarget = nil
        return
    end
    -- Marche jusqu'à la porte demandée par le serveur (une fois par demande).
    local approach = character:GetAttribute(Doors.ApproachAttribute)
    if typeof(approach) == "Vector3" then
        if approachTarget ~= approach then
            approachTarget = approach
            humanoid:MoveTo(approach)
        end
    else
        approachTarget = nil
    end
    local seat = humanoid.SeatPart
    -- Siège libéré pendant un glissé de sortie : posé au point de dépôt (pas de retour d'une image dans le siège).
    if seat == nil and lastSeat ~= nil then
        local glide = Doors.decodeGlide(character:GetAttribute(Doors.GlideAttribute))
        local model = vehicleOf(lastSeat)
        local root = model and model.PrimaryPart
        if glide and glide.Kind == "Out" and root and Doors.glideWeight(glide, serverNow()) >= OUT_DONE_WEIGHT then
            local point = root.CFrame:PointToWorldSpace(glide.Point)
            local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
            if look.Magnitude < 0.1 then
                look = Vector3.new(0, 0, -1)
            end
            character:PivotTo(CFrame.lookAt(point, point + look.Unit))
        end
    end
    lastSeat = seat
    -- Passager d'un véhicule à portières : la touche de saut devient une demande de sortie.
    local model = if seat then vehicleOf(seat) else nil
    setExitBinding(seat ~= nil and seat.Name == "PassengerSeat" and model ~= nil and hasAnyDoor(model))
end

function DoorVisuals.update(_dt: number)
    updateDoors(serverNow())
    updateLocal()
end

return DoorVisuals
