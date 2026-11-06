--!strict
--[[
    Pose assise du jeu appliquée localement à chaque personnage assis sur un siège marqué
    `AWSeatPose` (`Shared.Vehicles.SeatPose`). Chaque client l'applique à tous les joueurs :
    tout le monde voit la même pose, sans réplication par image.

    Après l'animation du moteur (`RunService.PreSimulation`), le décalage de chaque
    articulation est multiplié dans `Transform` (Motor6D ou AnimationConstraint du nouveau
    squelette R15) ; si l'animation n'a pas réécrit `Transform` depuis notre dernière
    écriture, l'ancien décalage est retiré d'abord (pas de cumul), comme pour le bras du
    téléphone (QA-A10). Les bras ne sont pas modifiés quand le téléphone est sorti.

    Lot ANIM-01 (volants et mains) : à chaque pas, les volants tournent d'abord
    (`SteeringWheelVisuals`), puis, pour le CONDUCTEUR d'un véhicule dont le volant est connu
    (`MeshKitData.SteeringWheel`), les épaules et les coudes sont calculés par cinématique
    inverse (`Shared.Vehicles.ArmIk`) pour poser les mains sur la jante à 9 h 15, qui suivent sa
    rotation jusqu'à ±100° puis glissent. Ces rotations remplacent l'animation des bras (fondu
    `SeatPose.BlendS`). Passager, sièges sans volant connu : pose statique inchangée. Téléphone
    sorti : bras rendus à l'animation (règle QA-A10 ; le lot PHONE-01 gère le bras du téléphone).
    Vue cockpit du joueur local : avant-bras et mains gardés visibles (décision du propriétaire).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VehiclesShared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Vehicles")
local SeatPose = require(VehiclesShared:WaitForChild("SeatPose"))
local ArmIk = require(VehiclesShared:WaitForChild("ArmIk"))
local SteeringWheel = require(VehiclesShared:WaitForChild("SteeringWheel"))
local MeshKitData = require(VehiclesShared:WaitForChild("MeshKitData"))
local Constants = require(VehiclesShared:WaitForChild("VehicleConstants"))
local SteeringWheelVisuals = require(script.Parent.SteeringWheelVisuals)
local VehicleController = require(script.Parent.VehicleController)

local SeatPoseController = {}

local PHONE_RAISED_ATTRIBUTE = "AWPhoneRaised"

-- Pièce qui porte chaque articulation du R15.
local JOINT_PARTS: { [string]: string } = {
    Root = "LowerTorso",
    Waist = "UpperTorso",
    Neck = "Head",
    LeftShoulder = "LeftUpperArm",
    RightShoulder = "RightUpperArm",
    LeftElbow = "LeftLowerArm",
    RightElbow = "RightLowerArm",
    LeftKnee = "LeftLowerLeg",
    RightKnee = "RightLowerLeg",
    LeftHip = "LeftUpperLeg",
    RightHip = "RightUpperLeg",
}

-- Lot ANIM-01 : pièces gardées visibles en vue cockpit (décision du propriétaire : avant-bras et mains ; les bras
-- restent masqués pour ne pas boucher la vue ni traverser la caméra).
local FOREARMS: { [string]: boolean } = {
    LeftLowerArm = true,
    RightLowerArm = true,
    LeftHand = true,
    RightHand = true,
}

-- Direction du coude (repère du buste : X à droite, Y en haut, Z vers l'arrière) : vers le bas, l'extérieur et un
-- peu l'arrière, comme un conducteur les mains à 9 h 15.
local POLE_DOWN, POLE_OUT, POLE_BACK = -1, 0.6, 0.2

-- Motor6D ou AnimationConstraint : tous deux exposent `Transform` (typage commun minimal).
type Joint = { Transform: CFrame, Parent: Instance? }
-- Ik : dernière rotation calculée par la cinématique inverse (bras du conducteur), gardée pour le retrait.
type Entry = { Alpha: number, Written: CFrame, Offset: CFrame, Pose: SeatPose.Pose?, Ik: CFrame? }

local entries: { [any]: Entry } = {}
local started = false
-- Filtre de visibilité des avant-bras posé sur la caméra du véhicule (joueur local).
local forearmsShown = false

local function sameFrame(a: CFrame, b: CFrame): boolean
    return (a.Position - b.Position).Magnitude < 1e-5
        and a.LookVector:Dot(b.LookVector) > 1 - 1e-7
        and a.UpVector:Dot(b.UpVector) > 1 - 1e-7
end

local function jointIn(part: Instance?, name: string): Instance?
    local joint = if part then part:FindFirstChild(name) else nil
    if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
        return joint
    end
    return nil
end

local function jointOf(character: Model, name: string): Joint?
    return jointIn(character:FindFirstChild(JOINT_PARTS[name]), name) :: any
end

-- Repères C0 et C1 d'une articulation (Motor6D, ou attaches d'une AnimationConstraint).
local function frames(joint: Instance): (CFrame?, CFrame?)
    if joint:IsA("Motor6D") then
        return joint.C0, joint.C1
    elseif joint:IsA("AnimationConstraint") then
        local a0, a1 = joint.Attachment0, joint.Attachment1
        if a0 and a1 then
            return a0.CFrame, a1.CFrame
        end
    end
    return nil, nil
end

-- Chaîne d'un bras (« Left » ou « Right ») lue sur le personnage : adaptée à ses proportions.
local function armChain(character: Model, side: string): ArmIk.Chain?
    local hand = character:FindFirstChild(side .. "Hand")
    local shoulder = jointIn(character:FindFirstChild(side .. "UpperArm"), side .. "Shoulder")
    local elbow = jointIn(character:FindFirstChild(side .. "LowerArm"), side .. "Elbow")
    local wrist = jointIn(hand, side .. "Wrist")
    if shoulder == nil or elbow == nil or wrist == nil then
        return nil
    end
    local s0, s1 = frames(shoulder)
    local e0, e1 = frames(elbow)
    local w0, w1 = frames(wrist)
    if s0 == nil or s1 == nil or e0 == nil or e1 == nil or w0 == nil or w1 == nil then
        return nil
    end
    local gripAttachment = (hand :: Instance):FindFirstChild(side .. "GripAttachment")
    local grip = if gripAttachment and gripAttachment:IsA("Attachment") then gripAttachment.Position else Vector3.zero
    return {
        ShoulderC0 = s0,
        ShoulderC1 = s1,
        ElbowC0 = e0,
        ElbowC1 = e1,
        WristC0 = w0,
        WristC1 = w1,
        Grip = grip,
    }
end

-- Véhicule d'un siège : premier ancêtre portant l'identifiant de définition.
local function vehicleOf(seat: Instance): Model?
    local node = seat.Parent
    while node and node ~= workspace do
        if node:IsA("Model") and node:GetAttribute(Constants.Attributes.DefinitionId) ~= nil then
            return node
        end
        node = node.Parent
    end
    return nil
end

--[[
    Rotations des épaules et des coudes qui posent les mains sur le volant (nil si ce siège n'est pas celui d'un
    conducteur devant un volant connu, ou si le squelette n'est pas un R15 complet).
]]
local function handsOnWheel(character: Model, seat: BasePart, pose: SeatPose.Pose): { [string]: CFrame }?
    if pose.LeftShoulder == nil then
        return nil -- pose sans bras : passager
    end
    local model = vehicleOf(seat)
    local definitionId = if model then model:GetAttribute(Constants.Attributes.DefinitionId) else nil
    local kit = if type(definitionId) == "string" then MeshKitData.Kits[definitionId] else nil
    local spec = kit and kit.SteeringWheel
    local root = model and model.PrimaryPart
    local torso = character:FindFirstChild("UpperTorso")
    if model == nil or spec == nil or root == nil or torso == nil or not torso:IsA("BasePart") then
        return nil
    end
    local left, right = SteeringWheel.grips(spec, SteeringWheelVisuals.angleFor(model))
    local result: { [string]: CFrame } = {}
    for _, side in { "Left", "Right" } do
        local chain = armChain(character, side)
        if chain == nil then
            return nil
        end
        local world = root.CFrame * (if side == "Left" then left else right)
        local target = torso.CFrame:PointToObjectSpace(world)
        local out = if side == "Left" then -POLE_OUT else POLE_OUT
        local shoulder, elbow = ArmIk.solve(chain, target, Vector3.new(out, POLE_DOWN, POLE_BACK))
        result[side .. "Shoulder"] = shoulder
        result[side .. "Elbow"] = elbow
    end
    return result
end

-- Vue cockpit du joueur local : avant-bras et mains visibles tant que ses mains sont sur le volant.
local function updateCockpitForearms(character: Model?, active: boolean, phoneUp: boolean)
    local camera = VehicleController.getCamera()
    if active and character then
        if not forearmsShown then
            forearmsShown = true
            camera:setCharacterVisibilityFilter(function(part: Instance): boolean
                return FOREARMS[part.Name] == true and part.Parent == character
            end)
        end
        -- Réappliqué à chaque pas en cockpit : protège contre une autre écriture de la transparence locale
        -- (contrôleur de transparence du PlayerModule ; RAPPORT_CAMERA_01 §4).
        if camera:isCockpit() then
            for name in FOREARMS do
                local part = character:FindFirstChild(name)
                if part and part:IsA("BasePart") then
                    part.LocalTransparencyModifier = 0
                end
            end
        end
    elseif forearmsShown then
        forearmsShown = false
        -- Téléphone sorti : la visibilité en cockpit revient au lot PHONE-01 (filtre laissé tel quel).
        if not phoneUp then
            camera:setCharacterVisibilityFilter(nil)
        end
    end
end

local function update(dt: number)
    SteeringWheelVisuals.update(dt)
    local localPlayer = Players.LocalPlayer
    for _, player in Players:GetPlayers() do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if character == nil or humanoid == nil then
            if player == localPlayer then
                updateCockpitForearms(nil, false, false)
            end
            continue
        end
        local seat = humanoid.SeatPart
        local pose = if seat then SeatPose.poseFor(seat:GetAttribute(SeatPose.Attribute)) else nil
        local phoneUp = character:GetAttribute(PHONE_RAISED_ATTRIBUTE) == true
        local ik = if seat and pose and not phoneUp then handsOnWheel(character, seat, pose) else nil
        if player == localPlayer then
            updateCockpitForearms(character, ik ~= nil, phoneUp)
        end
        for name in JOINT_PARTS do
            local joint = jointOf(character, name)
            if joint == nil then
                continue
            end
            local entry = entries[joint]
            local ikWanted = if ik then ik[name] else nil
            local wanted = if pose and not (phoneUp and SeatPose.ArmJoints[name]) then pose[name] else nil
            if entry == nil and wanted == nil and not ikWanted then
                continue
            end
            local current: Entry = entry
                or { Alpha = 0, Written = joint.Transform, Offset = CFrame.identity, Pose = pose, Ik = nil }
            local base = joint.Transform
            if entry and sameFrame(base, entry.Written) then
                base = entry.Offset:Inverse() * base
            end
            local active = if ikWanted then true else wanted ~= nil
            current.Alpha = math.clamp(current.Alpha + (if active then dt else -dt) / SeatPose.BlendS, 0, 1)
            if ikWanted then
                current.Ik = ikWanted
            elseif wanted then
                current.Ik = nil -- pose statique (siège sans volant connu)
            end
            if wanted then
                current.Pose = pose
            end
            if current.Ik then
                -- Bras du conducteur : rotation calculée, en fondu depuis l'animation (et retour au retrait).
                current.Written = base:Lerp(current.Ik, current.Alpha)
                current.Offset = current.Written * base:Inverse()
            else
                -- Décalage gardé pendant le retrait (siège quitté) pour revenir progressivement.
                local target = wanted or (current.Pose and current.Pose[name])
                local pitch, yaw, down = 0, 0, 0
                if target then
                    pitch, yaw, down = SeatPose.offset(target, current.Alpha)
                end
                current.Offset = CFrame.new(0, -down, 0) * CFrame.Angles(pitch, yaw, 0)
                current.Written = current.Offset * base
            end
            joint.Transform = current.Written
            if current.Alpha > 0 or active then
                entries[joint] = current
            else
                entries[joint] = nil
            end
        end
    end
    for joint in entries do
        if joint.Parent == nil then
            entries[joint] = nil
        end
    end
end

function SeatPoseController.start()
    if started then
        return
    end
    started = true
    RunService.PreSimulation:Connect(update)
end

return SeatPoseController
