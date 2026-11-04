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
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SeatPose = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Vehicles"):WaitForChild("SeatPose"))

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
}

-- Motor6D ou AnimationConstraint : tous deux exposent `Transform` (typage commun minimal).
type Joint = { Transform: CFrame, Parent: Instance? }
type Entry = { Alpha: number, Written: CFrame, Offset: CFrame, Pose: SeatPose.Pose? }

local entries: { [any]: Entry } = {}
local started = false

local function sameFrame(a: CFrame, b: CFrame): boolean
    return (a.Position - b.Position).Magnitude < 1e-5
        and a.LookVector:Dot(b.LookVector) > 1 - 1e-7
        and a.UpVector:Dot(b.UpVector) > 1 - 1e-7
end

local function jointOf(character: Model, name: string): Joint?
    local part = character:FindFirstChild(JOINT_PARTS[name])
    local joint = part and part:FindFirstChild(name)
    if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
        return joint :: any
    end
    return nil
end

local function update(dt: number)
    for _, player in Players:GetPlayers() do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if character == nil or humanoid == nil then
            continue
        end
        local seat = humanoid.SeatPart
        local pose = if seat then SeatPose.poseFor(seat:GetAttribute(SeatPose.Attribute)) else nil
        local phoneUp = character:GetAttribute(PHONE_RAISED_ATTRIBUTE) == true
        for name in JOINT_PARTS do
            local joint = jointOf(character, name)
            if joint == nil then
                continue
            end
            local entry = entries[joint]
            local wanted = if pose and not (phoneUp and SeatPose.ArmJoints[name]) then pose[name] else nil
            if entry == nil and wanted == nil then
                continue
            end
            local current: Entry = entry
                or { Alpha = 0, Written = joint.Transform, Offset = CFrame.identity, Pose = pose }
            local base = joint.Transform
            if entry and sameFrame(base, entry.Written) then
                base = entry.Offset:Inverse() * base
            end
            current.Alpha = math.clamp(current.Alpha + (if wanted then dt else -dt) / SeatPose.BlendS, 0, 1)
            -- Décalage gardé pendant le retrait (siège quitté) pour revenir progressivement.
            local target = wanted or (current.Pose and current.Pose[name])
            if wanted then
                current.Pose = pose
            end
            local pitch, down = 0, 0
            if target then
                pitch, down = SeatPose.offset(target, current.Alpha)
            end
            current.Offset = CFrame.new(0, -down, 0) * CFrame.Angles(pitch, 0, 0)
            current.Written = current.Offset * base
            joint.Transform = current.Written
            if current.Alpha > 0 or wanted then
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
