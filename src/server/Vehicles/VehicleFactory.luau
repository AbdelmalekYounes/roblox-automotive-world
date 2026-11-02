--!strict
-- Fabrique du véhicule d'essai : construit par code une géométrie TEMPORAIRE
-- et originale (blocs et cylindres primitifs) à partir de la définition.
-- Aucun maillage, modèle ni actif externe n'est utilisé.
--
-- Structure produite :
--   Model (PrimaryPart = Chassis, étiquette AWVehicle, attributs d'identité)
--   ├─ Chassis        : bloc invisible porteur de la masse et des collisions basses
--   │   ├─ Suspension<FL..RR> / Contact<FL..RR> : attachements des rayons et forces
--   │   ├─ TireForce<FL..RR> : VectorForce (repère monde) par roue
--   │   ├─ CenterOfMass + BodyForce : traînée et compensation de gravité
--   │   └─ DriverDoor (ProximityPrompt « Conduire »)
--   ├─ Carrosserie    : pièces visuelles sans masse (soudées)
--   ├─ DriverSeat     : siège conducteur (Seat)
--   └─ Wheel<FL..RR>  : roues visuelles, animées localement via Motor6D.Transform

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehiclesShared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Vehicles")
local Types = require(VehiclesShared:WaitForChild("VehicleTypes"))
local Constants = require(VehiclesShared:WaitForChild("VehicleConstants"))
local VehicleDynamics = require(VehiclesShared:WaitForChild("Physics"):WaitForChild("VehicleDynamics"))

local VehicleFactory = {}

local STUDS_PER_METER = 1 / Constants.MetersPerStud
-- Densité du bloc châssis : seule la répartition compte, la dynamique
-- étant normalisée par la masse réelle de la définition.
local CHASSIS_DENSITY = 10

local function studs(meters: number): number
    return meters * STUDS_PER_METER
end

local function rgb(values: { number }): Color3
    return Color3.fromRGB(values[1], values[2], values[3])
end

type VisualProps = {
    Name: string,
    Size: Vector3,
    Offset: CFrame,
    Color: Color3,
    Material: Enum.Material?,
    Transparency: number?,
    CanCollide: boolean?,
}

-- Pièce visuelle soudée au châssis, sans masse (n'affecte pas la dynamique).
local function addVisual(root: BasePart, parent: Instance, props: VisualProps): Part
    local part = Instance.new("Part")
    part.Name = props.Name
    part.Size = props.Size
    part.CFrame = root.CFrame * props.Offset
    part.Color = props.Color
    part.Material = props.Material or Enum.Material.SmoothPlastic
    part.Transparency = props.Transparency or 0
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Massless = true
    part.CanCollide = props.CanCollide == true
    part.CanQuery = props.CanCollide == true
    part.CanTouch = false
    part.Anchored = false
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = root
    weld.Part1 = part
    weld.Parent = part
    part.Parent = parent
    return part
end

local function addAttachment(parent: Instance, name: string, position: Vector3): Attachment
    local attachment = Instance.new("Attachment")
    attachment.Name = name
    attachment.Position = position
    attachment.Parent = parent
    return attachment
end

local function addSideLabel(part: BasePart, face: Enum.NormalId, text: string, color: Color3)
    local gui = Instance.new("SurfaceGui")
    gui.Face = face
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 30
    gui.LightInfluence = 1
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextScaled = true
    label.Font = Enum.Font.GothamBlack
    label.TextColor3 = color
    label.Parent = gui
    gui.Parent = part
end

--[[
    Crée un véhicule d'essai à l'emplacement donné.
    `pivot` : CFrame du centre de gravité (orientation = sens de marche -Z).
    Le véhicule n'appartient à personne : identifiant de session non persistant.
]]
function VehicleFactory.create(definition: Types.VehicleDefinition, pivot: CFrame, padIndex: number): Model
    local chassis = definition.Chassis
    local tire = definition.Tires
    local appearance = definition.Appearance
    local layout = VehicleDynamics.wheelLayout(definition)

    local model = Instance.new("Model")
    model.Name = "VehiculeEssai_" .. padIndex

    -- Hauteurs exprimées par rapport au centre de gravité (Y = 0 local).
    local groundY = -studs(chassis.CgHeightM)
    local hubY = groundY + studs(tire.RadiusM)
    local frontZ = -studs(layout[1].Longitudinal) -- l'avant est vers -Z
    local rearZ = -studs(layout[3].Longitudinal)
    local trackFront = studs(chassis.TrackFrontM)
    local tireWidth = studs(tire.WidthM)

    -- Bloc châssis : centré exactement sur le centre de gravité. Ses dimensions
    -- suivent la longueur et la largeur du véhicule pour que les inerties de
    -- lacet et de tangage calculées par Roblox restent proches d'une voiture
    -- réelle (la dynamique pure normalise les forces par la masse ; l'inertie,
    -- elle, dépend de la forme de ce bloc). Hauteur limitée pour garder une
    -- garde au sol d'environ 0,22 m.
    local rootHeight = 2
    local root = Instance.new("Part")
    root.Name = "Chassis"
    root.Size = Vector3.new(studs(chassis.WidthM) - 0.4, rootHeight, studs(chassis.LengthM) - 0.4)
    root.CFrame = pivot
    root.Transparency = 1
    root.CanCollide = true
    root.CanTouch = false
    root.CustomPhysicalProperties = PhysicalProperties.new(CHASSIS_DENSITY, 0.3, 0, 1, 1)
    root.Anchored = false
    root.Parent = model
    model.PrimaryPart = root

    -- Points de suspension et forces de contact.
    for index, name in Constants.WheelNames do
        local place = layout[index]
        local axle = if place.IsFront then definition.Suspension.Front else definition.Suspension.Rear
        local staticCompression = VehicleDynamics.staticCompression(definition, place.IsFront)
        local x = studs(place.Lateral)
        local z = -studs(place.Longitudinal)
        local originY = hubY + studs(axle.RestLengthM - staticCompression)
        addAttachment(root, "Suspension" .. name, Vector3.new(x, originY, z))
        local contact = addAttachment(root, "Contact" .. name, Vector3.new(x, groundY, z))
        local force = Instance.new("VectorForce")
        force.Name = "TireForce" .. name
        force.Attachment0 = contact
        force.RelativeTo = Enum.ActuatorRelativeTo.World
        force.ApplyAtCenterOfMass = false
        force.Force = Vector3.zero
        force.Parent = root
    end
    local centerAttachment = addAttachment(root, "CenterOfMass", Vector3.zero)
    local bodyForce = Instance.new("VectorForce")
    bodyForce.Name = "BodyForce"
    bodyForce.Attachment0 = centerAttachment
    bodyForce.RelativeTo = Enum.ActuatorRelativeTo.World
    bodyForce.ApplyAtCenterOfMass = true
    bodyForce.Force = Vector3.zero
    bodyForce.Parent = root

    -- Carrosserie de prototype : coque centrale étroite, ailes au-dessus des
    -- roues apparentes, habitacle vitré et arceau. Silhouette originale.
    local body = Instance.new("Folder")
    body.Name = "Carrosserie"
    body.Parent = model
    local bodyColor = rgb(appearance.BodyRgb)
    local accent = rgb(appearance.AccentRgb)
    local trim = rgb(appearance.TrimRgb)
    local frontEnd = frontZ - studs(0.85)
    local rearEnd = rearZ + studs(0.9)
    local tubLength = rearEnd - frontEnd
    local tubCenterZ = (frontEnd + rearEnd) / 2
    local tubBottom = groundY + studs(0.32)
    local tubTop = groundY + studs(0.85)
    local tubWidth = trackFront - tireWidth - 0.3

    local tub = addVisual(root, body, {
        Name = "Coque",
        Size = Vector3.new(tubWidth, tubTop - tubBottom, tubLength),
        Offset = CFrame.new(0, (tubTop + tubBottom) / 2, tubCenterZ),
        Color = bodyColor,
        CanCollide = true,
    })
    addSideLabel(tub, Enum.NormalId.Left, appearance.Label, accent)
    addSideLabel(tub, Enum.NormalId.Right, appearance.Label, accent)

    addVisual(root, body, {
        Name = "BandeAvant",
        Size = Vector3.new(tubWidth + 0.02, 0.25, studs(0.5)),
        Offset = CFrame.new(0, tubTop - 0.1, frontEnd + studs(0.25)),
        Color = accent,
    })
    addVisual(root, body, {
        Name = "BouclierAvant",
        Size = Vector3.new(studs(chassis.WidthM) - 0.4, 0.8, 0.6),
        Offset = CFrame.new(0, tubBottom + 0.4, frontEnd - 0.2),
        Color = trim,
        CanCollide = true,
    })
    addVisual(root, body, {
        Name = "BouclierArriere",
        Size = Vector3.new(studs(chassis.WidthM) - 0.4, 0.8, 0.6),
        Offset = CFrame.new(0, tubBottom + 0.4, rearEnd + 0.2),
        Color = trim,
        CanCollide = true,
    })
    for _, side in { -1, 1 } do
        addVisual(root, body, {
            Name = "Phare" .. (if side < 0 then "Gauche" else "Droit"),
            Size = Vector3.new(1, 0.4, 0.2),
            Offset = CFrame.new(side * (tubWidth / 2 - 0.7), tubTop - 0.45, frontEnd - 0.05),
            Color = Color3.fromRGB(255, 250, 225),
            Material = Enum.Material.Neon,
        })
        addVisual(root, body, {
            Name = "Feu" .. (if side < 0 then "Gauche" else "Droit"),
            Size = Vector3.new(1, 0.4, 0.2),
            Offset = CFrame.new(side * (tubWidth / 2 - 0.7), tubTop - 0.45, rearEnd + 0.05),
            Color = Color3.fromRGB(200, 20, 20),
            Material = Enum.Material.Neon,
        })
    end

    -- Ailes au-dessus de chaque roue.
    for index in Constants.WheelNames do
        local place = layout[index]
        addVisual(root, body, {
            Name = "Aile" .. Constants.WheelNames[index],
            Size = Vector3.new(tireWidth + 0.5, 0.25, studs(tire.RadiusM) * 2 + 0.8),
            Offset = CFrame.new(studs(place.Lateral), hubY + studs(tire.RadiusM) + 0.45, -studs(place.Longitudinal)),
            Color = bodyColor,
        })
    end

    -- Habitacle : vitrage collisionnable (les piétons ne traversent pas le toit).
    local cabinBottom = tubTop
    local cabinTop = groundY + studs(chassis.HeightM)
    local cabinLength = studs(1.9)
    local cabinZ = tubCenterZ + studs(0.15)
    addVisual(root, body, {
        Name = "Habitacle",
        Size = Vector3.new(tubWidth - 0.6, cabinTop - cabinBottom, cabinLength),
        Offset = CFrame.new(0, (cabinTop + cabinBottom) / 2, cabinZ),
        Color = Color3.fromRGB(150, 190, 220),
        Material = Enum.Material.Glass,
        Transparency = 0.55,
        CanCollide = true,
    })
    addVisual(root, body, {
        Name = "Toit",
        Size = Vector3.new(tubWidth - 0.5, 0.2, cabinLength - 0.4),
        Offset = CFrame.new(0, cabinTop + 0.1, cabinZ + 0.2),
        Color = accent,
    })

    -- Siège conducteur (conduite à gauche). Il ne s'active pas au simple
    -- contact (CanTouch = false) : l'embarquement passe par le serveur.
    local seat = Instance.new("Seat")
    seat.Name = "DriverSeat"
    seat.Size = Vector3.new(1.8, 0.4, 1.8)
    seat.CFrame = root.CFrame * CFrame.new(-tubWidth / 4, tubBottom + 0.6, cabinZ + 0.6)
    seat.Color = trim
    seat.Massless = true
    seat.CanCollide = false
    seat.CanTouch = false
    seat.Anchored = false
    local seatWeld = Instance.new("WeldConstraint")
    seatWeld.Part0 = root
    seatWeld.Part1 = seat
    seatWeld.Parent = seat
    seat.Parent = model

    -- Roues : purement visuelles (sans masse, sans collision, ignorées des rayons).
    for index, name in Constants.WheelNames do
        local place = layout[index]
        local hubOffset = CFrame.new(studs(place.Lateral), hubY, -studs(place.Longitudinal))
        local wheel = Instance.new("Part")
        wheel.Name = "Wheel" .. name
        wheel.Shape = Enum.PartType.Cylinder -- axe du cylindre = X (essieu)
        wheel.Size = Vector3.new(tireWidth, studs(tire.RadiusM) * 2, studs(tire.RadiusM) * 2)
        wheel.CFrame = root.CFrame * hubOffset
        wheel.Color = Color3.fromRGB(25, 25, 27)
        wheel.Material = Enum.Material.Rubber
        wheel.Massless = true
        wheel.CanCollide = false
        wheel.CanQuery = false
        wheel.CanTouch = false
        wheel.Anchored = false

        -- Jante et rayon contrasté pour rendre la rotation visible.
        local rim = Instance.new("Part")
        rim.Name = "Jante"
        rim.Shape = Enum.PartType.Cylinder
        rim.Size = Vector3.new(tireWidth + 0.04, studs(tire.RadiusM) * 1.2, studs(tire.RadiusM) * 1.2)
        rim.CFrame = wheel.CFrame
        rim.Color = Color3.fromRGB(170, 172, 176)
        rim.Material = Enum.Material.Metal
        local spoke = Instance.new("Part")
        spoke.Name = "Rayon"
        spoke.Size = Vector3.new(tireWidth + 0.08, studs(tire.RadiusM) * 1.1, 0.25)
        spoke.CFrame = wheel.CFrame
        spoke.Color = accent
        for _, part in { rim, spoke } do
            part.Massless = true
            part.CanCollide = false
            part.CanQuery = false
            part.CanTouch = false
            part.Anchored = false
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = wheel
            weld.Part1 = part
            weld.Parent = part
            part.Parent = wheel
        end

        local joint = Instance.new("Motor6D")
        joint.Name = "Joint"
        joint.Part0 = root
        joint.Part1 = wheel
        joint.C0 = hubOffset
        joint.C1 = CFrame.identity
        joint.Parent = wheel
        wheel.Parent = model
    end

    -- Invite d'embarquement côté conducteur (gauche). Le serveur revalide tout.
    local door = addAttachment(root, "DriverDoor", Vector3.new(-tubWidth / 2 - 1, 0, cabinZ))
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "EnterPrompt"
    prompt.ActionText = "Conduire"
    prompt.ObjectText = definition.DisplayName
    prompt.HoldDuration = 0.3
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
    prompt.Parent = door

    -- Identité de session (non persistante, aucune possession).
    model:SetAttribute(Constants.Attributes.VehicleId, "essai-" .. HttpService:GenerateGUID(false))
    model:SetAttribute(Constants.Attributes.DefinitionId, definition.Id)
    model:SetAttribute(Constants.Attributes.DriverUserId, 0)
    model:SetAttribute(Constants.Attributes.VisualSteer, 0)
    model:SetAttribute(Constants.Attributes.IsTestVehicle, true)
    model:SetAttribute(Constants.Attributes.PadIndex, padIndex)
    CollectionService:AddTag(model, Constants.VehicleTag)

    return model
end

-- CFrame du centre de gravité pour poser le véhicule sur un plot.
function VehicleFactory.spawnPivotForPad(definition: Types.VehicleDefinition, pad: BasePart): CFrame
    local groundTop = pad.Position.Y + pad.Size.Y / 2
    local height = studs(definition.Chassis.CgHeightM) + 0.3
    return CFrame.new(pad.Position.X, groundTop + height, pad.Position.Z)
end

return VehicleFactory
