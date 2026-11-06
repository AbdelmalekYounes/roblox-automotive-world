--!strict
--[[
    Portières et gestes du joueur local pendant l'entrée et la sortie (lots ANIM-02 et ANIM-03), côté client. Purement
    visuel : `Motor6D.Transform` n'est pas répliqué et les portes n'ont ni masse ni collision.

    Pour TOUS les véhicules visibles par ce client : angle de chaque porte articulée. Pendant une séquence d'entrée ou de
    sortie (attribut `AWEmbarquement` d'un personnage assis dans ce véhicule), l'angle vient de la séquence elle-même
    (`Shared.Vehicles.BoardingMotion`, même horloge que la main sur la poignée : la porte suit la main) ; sinon, de
    l'état répliqué par le serveur (attribut texte du modèle, temps du serveur). Tout le monde voit la même porte.

    Joueur local :
    - marche jusqu'à la porte quand le serveur la demande (attribut `ApproachAttribute` de son personnage) ;
    - passager d'un véhicule à portières : la touche de saut (Espace, bouton A) est interceptée et devient une demande de
      sortie au serveur, qui joue la séquence ; elle est aussi interceptée pendant toute séquence du joueur (aucun saut
      au milieu d'un geste). Le bouton de saut tactile n'est pas intercepté (sortie immédiate, porte entrouverte) ;
    - téléphone rangé au début d'une séquence (lot PHONE-01, par `UIManager`) ;
    - caméra à la 3e personne (décision du propriétaire) : pendant la séquence, la caméra par défaut suit la TÊTE (le
      corps visible), pas le HumanoidRootPart resté soudé au siège ;
    - fin de sortie : dès que le siège est libéré, le personnage est posé au point de dépôt (là où son corps est
      arrivé), sans attendre le placement du serveur, qui vérifie ensuite le même point.

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
local BoardingMotion = require(VehiclesShared:WaitForChild("BoardingMotion"))
local UIManager = require(script.Parent.Parent.UI.UIManager)

local DoorVisuals = {}

local EXIT_ACTION = "AWPortiereSortie"
-- Fin de sortie : le corps est au point de dépôt dans les derniers instants de la séquence.
local OUT_DONE_MARGIN_S = 0.3

-- Raw/State : dernier état lu (texte) et son décodage, relu seulement quand le texte change.
type DoorCache = { Spec: Doors.Spec, Joint: Motor6D?, Raw: string?, State: Doors.State? }

-- Tables à clés faibles : un véhicule détruit libère son entrée.
local caches: { [Model]: { [string]: DoorCache } } = setmetatable({}, { __mode = "k" }) :: any

local exitBound = false
local lastSeat: BasePart? = nil
local lastSequence: BoardingMotion.Sequence? = nil
local approachTarget: Vector3? = nil
local subjectHeld = false

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

-- Séquences en cours, par véhicule et par porte (personnages assis dans ce véhicule).
local function sequencesByDoor(): { [Model]: { [string]: BoardingMotion.Sequence } }
    local result: { [Model]: { [string]: BoardingMotion.Sequence } } = {}
    for _, player in Players:GetPlayers() do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local seat = humanoid and humanoid.SeatPart
        local sequence = if character
            then BoardingMotion.decode(character:GetAttribute(BoardingMotion.Attribute))
            else nil
        local model = if seat and sequence then vehicleOf(seat) else nil
        if model and sequence then
            local byDoor = result[model] or {}
            byDoor[sequence.Door] = sequence
            result[model] = byDoor
        end
    end
    return result
end

local function updateDoors(now: number)
    local active = sequencesByDoor()
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
            local byDoor = active[model]
            local sequence = byDoor and byDoor[role]
            local fraction = if sequence
                then BoardingMotion.doorFraction(sequence.Kind, now - sequence.T)
                else Doors.fraction(cache.State, now)
            -- Réécrit à chaque pas, comme les roues et les volants.
            joint.Transform = Doors.jointTransform(Doors.angle(cache.Spec, fraction))
        end
    end
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

-- Caméra par défaut sur la tête (corps visible) pendant une séquence ; rendue au personnage ensuite.
local function holdSubject(character: Model, humanoid: Humanoid, wanted: boolean)
    local camera = Workspace.CurrentCamera
    if camera == nil then
        return
    end
    if wanted then
        local head = character:FindFirstChild("Head")
        if head and head:IsA("BasePart") and camera.CameraType == Enum.CameraType.Custom then
            camera.CameraSubject = head
            subjectHeld = true
        end
    elseif subjectHeld then
        subjectHeld = false
        if camera.CameraType == Enum.CameraType.Custom then
            camera.CameraSubject = humanoid
        end
    end
end

local function updateLocal()
    local character = Players.LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if character == nil or humanoid == nil then
        setExitBinding(false)
        lastSeat = nil
        lastSequence = nil
        approachTarget = nil
        subjectHeld = false
        return
    end
    local now = serverNow()
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
    local sequence = BoardingMotion.decode(character:GetAttribute(BoardingMotion.Attribute))
    -- Nouvelle séquence : téléphone rangé (lot PHONE-01).
    if sequence and (lastSequence == nil or lastSequence.T ~= sequence.T) and UIManager.isOpen("Phone") then
        UIManager.close("Phone")
    end
    local seat = humanoid.SeatPart
    -- Siège libéré à la fin d'une sortie : posé au point de dépôt (pas de retour d'une image dans le siège).
    local ending = sequence or lastSequence
    if seat == nil and lastSeat ~= nil and ending and ending.Kind == "Out" then
        local model = vehicleOf(lastSeat)
        local root = model and model.PrimaryPart
        if root and now >= ending.T + BoardingMotion.Exit.Total - OUT_DONE_MARGIN_S then
            character:PivotTo(root.CFrame * CFrame.new(ending.Point) * CFrame.Angles(0, ending.Yaw, 0))
        end
    end
    holdSubject(character, humanoid, sequence ~= nil and seat ~= nil and BoardingMotion.cameraHeld(sequence, now))
    lastSeat = seat
    lastSequence = sequence
    -- Passager d'un véhicule à portières, ou séquence en cours : la touche de saut devient une demande de sortie (le
    -- serveur l'ignore pendant une séquence).
    local model = if seat then vehicleOf(seat) else nil
    local passenger = seat ~= nil and seat.Name == "PassengerSeat" and model ~= nil and hasAnyDoor(model)
    setExitBinding(passenger or (sequence ~= nil and seat ~= nil))
end

function DoorVisuals.update(_dt: number)
    updateDoors(serverNow())
    updateLocal()
end

return DoorVisuals
