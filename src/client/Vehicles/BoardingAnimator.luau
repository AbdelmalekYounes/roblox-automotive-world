--!strict
--[[
    Gestes d'entrée et de sortie du véhicule (lot ANIM-03), côté client. Calcule, pour un personnage engagé dans une
    séquence (attribut `AWEmbarquement` publié par le serveur), la pose de chaque articulation à l'image courante :
    - corps : l'articulation `Root` place le corps visible le long du trajet continu de `Shared.Vehicles.BoardingMotion`
      (le HumanoidRootPart reste soudé au siège) ;
    - buste, cou, hanches et genoux : poses clés adoucies (gestes : se pencher, baisser la tête, engager une jambe puis
      l'autre) ;
    - bras : au repos, sauf la main qui tient une poignée (cinématique inverse `ArmIk`, cible sur la porte qui tourne :
      la porte et la main avancent ensemble).
    Chaque client calcule la même chose à partir du même horodatage : les autres joueurs voient les mêmes gestes.

    Le résultat est appliqué par `SeatPoseController` PAR-DESSUS la pose assise (fondu de `BoardingMotion.weight`) :
    à la fin de l'entrée, la pose assise et les mains au volant (lots ANIM-01, BRIO-02) reprennent progressivement.
    Poses originales, écrites dans ce dépôt : aucune animation importée.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local VehiclesShared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Vehicles")
local Constants = require(VehiclesShared:WaitForChild("VehicleConstants"))
local MeshKitData = require(VehiclesShared:WaitForChild("MeshKitData"))
local Doors = require(VehiclesShared:WaitForChild("Doors"))
local BoardingMotion = require(VehiclesShared:WaitForChild("BoardingMotion"))
local ArmIk = require(VehiclesShared:WaitForChild("ArmIk"))

local BoardingAnimator = {}

-- Articulations prises en charge (les poignets et les chevilles gardent l'animation).
BoardingAnimator.Joints = table.freeze({
    "Root",
    "Waist",
    "Neck",
    "LeftHip",
    "RightHip",
    "LeftKnee",
    "RightKnee",
    "LeftShoulder",
    "RightShoulder",
    "LeftElbow",
    "RightElbow",
    "LeftWrist",
    "RightWrist",
})

-- Accès aux articulations, fournis par `SeatPoseController` (mêmes règles : Motor6D ou AnimationConstraint).
export type Helpers = {
    Joint: (character: Model, name: string) -> Instance?,
    Frames: (joint: Instance) -> (CFrame?, CFrame?),
    Chain: (character: Model, side: string) -> ArmIk.Chain?,
}

export type Override = {
    Weight: number, -- part de la chorégraphie sur la pose assise (0 à 1)
    Joints: { [string]: CFrame }, -- `Transform` voulu par articulation
}

-- Distance du poignet à la paume (studs) : le poignet vise un peu en deçà de la poignée.
local HAND_REACH = 0.35

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

-- Spécification de la porte d'une séquence (nil : véhicule sans portière articulée connue).
function BoardingAnimator.doorSpec(model: Model, role: Doors.Role): (Doors.Spec?, number)
    local definitionId = model:GetAttribute(Constants.Attributes.DefinitionId)
    local kit = if type(definitionId) == "string" then MeshKitData.Kits[definitionId] else nil
    local doors = kit and kit.Doors
    if kit == nil or doors == nil then
        return nil, 0
    end
    return (if role == "Driver" then doors.Driver else doors.Passenger), kit.SideHalf
end

-- Séquence en cours d'un personnage (nil sinon).
function BoardingAnimator.sequenceOf(character: Model): BoardingMotion.Sequence?
    return BoardingMotion.decode(character:GetAttribute(BoardingMotion.Attribute))
end

--[[
    Pose voulue pour un personnage assis sur `seat`, ou nil (aucune séquence, ou fondu terminé). Le repère du corps est
    celui du HumanoidRootPart : `Root.Transform = C0⁻¹ · (HRP⁻¹ · voulu) · C0` place le bas du buste comme si le
    HumanoidRootPart était à la position voulue.
]]
function BoardingAnimator.compute(character: Model, seat: BasePart, helpers: Helpers): Override?
    local sequence = BoardingAnimator.sequenceOf(character)
    if sequence == nil then
        return nil
    end
    local now = Workspace:GetServerTimeNow()
    local weight = BoardingMotion.weight(sequence, now)
    if weight <= 0 then
        return nil
    end
    local model = vehicleOf(seat)
    local root = model and model.PrimaryPart
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if model == nil or root == nil or not (hrp and hrp:IsA("BasePart")) then
        return nil
    end
    local spec, sideHalf = BoardingAnimator.doorSpec(model, sequence.Door)
    if spec == nil then
        return nil
    end
    local rootJoint = helpers.Joint(character, "Root")
    local rootC0 = if rootJoint then helpers.Frames(rootJoint) else nil
    if rootJoint == nil or rootC0 == nil then
        return nil
    end
    local t = now - sequence.T
    local chassis = root.CFrame
    local seated = chassis:PointToObjectSpace(hrp.Position)
    local position, yaw = BoardingMotion.bodyAt(BoardingMotion.keys(sequence, spec, seated, sideHalf), t)
    local wanted = chassis * CFrame.new(position) * CFrame.Angles(0, yaw, 0)

    local joints: { [string]: CFrame } = {}
    joints.Root = rootC0:Inverse() * (hrp.CFrame:Inverse() * wanted) * rootC0
    -- Toutes les articulations prises en charge partent du repos (debout) : l'animation « assis » du moteur, qui joue
    -- dès que le personnage est sur le siège, ne doit transparaître sur aucune d'elles (retour du propriétaire
    -- 2026-11-06 : personnage assis par terre devant la porte, puis debout, puis de nouveau assis).
    for _, name in BoardingAnimator.Joints do
        if name ~= "Root" then
            joints[name] = CFrame.identity
        end
    end
    for generic, angles in BoardingMotion.poseAt(BoardingMotion.poseKeys(sequence.Kind, spec.Duck), t) do
        local name = BoardingMotion.jointName(generic, sequence.Kind, spec.Side)
        if name then
            joints[name] = CFrame.Angles(angles.X, angles.Y, angles.Z)
        end
    end

    -- Main sur une poignée : cible sur la porte à son angle de l'image (même horloge que la porte).
    local grip = BoardingMotion.grip(sequence.Kind, spec.Side, t)
    if grip then
        local chain = helpers.Chain(character, grip.Arm)
        local waist = helpers.Joint(character, "Waist")
        local waistC0: CFrame?, waistC1: CFrame? = nil, nil
        if waist then
            waistC0, waistC1 = helpers.Frames(waist)
        end
        local _, rootC1 = helpers.Frames(rootJoint)
        if chain and waistC0 and waistC1 and rootC1 then
            -- Haut du buste à l'image : HRP voulu → bas du buste → articulation de la taille (pose de cette image).
            local lower = wanted * rootC0 * rootC1:Inverse()
            local upper = lower * waistC0 * (joints.Waist or CFrame.identity) * waistC1:Inverse()
            local fraction = BoardingMotion.doorFraction(sequence.Kind, t)
            local handle = chassis:PointToWorldSpace(BoardingMotion.handlePoint(spec, grip.Inner, fraction))
            local target = upper:PointToObjectSpace(handle)
            local shoulder = chain.ShoulderC0.Position
            local toward = target - shoulder
            if toward.Magnitude > HAND_REACH then
                target -= toward.Unit * HAND_REACH
            end
            local sign = if grip.Arm == "Left" then -1 else 1
            local s, e = ArmIk.solve(chain, target, Vector3.new(sign * 0.6, -1, 0.2))
            local shoulderName, elbowName = grip.Arm .. "Shoulder", grip.Arm .. "Elbow"
            joints[shoulderName] = (joints[shoulderName] or CFrame.identity):Lerp(s, grip.Weight)
            joints[elbowName] = (joints[elbowName] or CFrame.identity):Lerp(e, grip.Weight)
        end
    end
    return { Weight = weight, Joints = joints }
end

return BoardingAnimator
