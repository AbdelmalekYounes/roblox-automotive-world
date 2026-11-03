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
--   │   ├─ CameraCockpit / CameraHood / CameraBumper : vues embarquées (lot 0.2)
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
local BodyKits = require(script.Parent.BodyKits)

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
    -- Lot 0.8 (carrosseries) : forme, détail masquable au loin, feu du véhicule.
    Shape: string?, -- "Wedge" | "Cylinder"
    Detail: boolean?,
    Light: string?, -- "Head" (projecteur) | "Tail" (feu arrière)
}

-- Pièce visuelle soudée au châssis, sans masse (n'affecte pas la dynamique).
local function addVisual(root: BasePart, parent: Instance, props: VisualProps): BasePart
    local part: BasePart
    if props.Shape == "Wedge" then
        part = Instance.new("WedgePart")
    else
        local block = Instance.new("Part")
        if props.Shape == "Cylinder" then
            block.Shape = Enum.PartType.Cylinder
        end
        part = block
    end
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
    part.CastShadow = props.Detail ~= true
    part.Anchored = false
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = root
    weld.Part1 = part
    weld.Parent = part
    if props.Light then
        -- Éclairage du véhicule : éteint par défaut, allumé la nuit par le client
        -- (nombre limité de véhicules proches, réglage de qualité).
        local light: any = if props.Light == "Head" then Instance.new("SpotLight") else Instance.new("PointLight")
        light.Name = "Lumiere"
        light.Enabled = false
        light.Brightness = if props.Light == "Head" then 3 else 1
        light.Range = if props.Light == "Head" then 40 else 8
        light.Color = if props.Light == "Head" then Color3.fromRGB(255, 244, 214) else Color3.fromRGB(255, 40, 30)
        if light:IsA("SpotLight") then
            light.Face = Enum.NormalId.Front
            light.Angle = 60
        end
        light.Parent = part
        part:SetAttribute("AWLight", props.Light)
    end
    if props.Detail then
        local details: Instance? = parent:FindFirstChild("Details")
        if details == nil then
            local created = Instance.new("Folder")
            created.Name = "Details"
            created.Parent = parent
            details = created
        end
        part.Parent = details
    else
        part.Parent = parent
    end
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
    -- Monde ouvert (StreamingEnabled) : le véhicule arrive entier chez chaque
    -- client, jamais à moitié (le simulateur exige toutes ses pièces).
    model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

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

    -- Carrosserie : silhouette propre au modèle (lot 0.8) ou carrosserie de
    -- prototype technique (lots 0.1–0.2). Les deux exposent les mêmes repères.
    local body = Instance.new("Folder")
    body.Name = "Carrosserie"
    body.Parent = model
    local bodyColor = rgb(appearance.BodyRgb)
    local accent = rgb(appearance.AccentRgb)
    local trim = rgb(appearance.TrimRgb)
    local styleName = appearance.BodyStyle
    local seatOffset: CFrame
    local passengerOffset: CFrame?
    local cabinZ: number, dashZ: number, dashTop: number, sideHalf: number
    local cameraHoodY: number, cameraBumperY: number, frontEnd: number
    if styleName and BodyKits.has(styleName) then
        local kit = BodyKits.build(
            styleName :: string,
            {
                GroundY = groundY,
                HubY = hubY,
                FrontAxleZ = frontZ,
                RearAxleZ = rearZ,
                TireRadius = studs(tire.RadiusM),
                TireWidth = tireWidth,
                Width = studs(chassis.WidthM),
                Length = studs(chassis.LengthM),
                Height = studs(chassis.HeightM),
            },
            { Body = bodyColor, Accent = accent, Trim = trim },
            studs,
            function(props: any): BasePart
                return addVisual(root, body, props)
            end
        )
        seatOffset = kit.SeatOffset
        passengerOffset = kit.PassengerOffset
        cabinZ, dashZ, dashTop = kit.CabinZ, kit.DashZ, kit.DashY + 0.25
        sideHalf = kit.BodyWidth / 2
        cameraHoodY = kit.HoodY + 0.8
        cameraBumperY = kit.FloorY + 0.2
        frontEnd = kit.FrontEnd
        addVisual(root, body, {
            Name = "Volant",
            Size = Vector3.new(0.15, 1.1, 1.1),
            Offset = CFrame.new(seatOffset.X, dashTop + 0.2, dashZ + 0.75)
                * CFrame.Angles(math.rad(-25), math.pi / 2, 0),
            Color = trim,
            Shape = "Cylinder",
        })
        addSideLabel(body:FindFirstChild("Coque") :: BasePart, Enum.NormalId.Left, appearance.Label, accent)
    else
        -- Carrosserie de prototype : coque centrale étroite, ailes au-dessus des
        -- roues apparentes, habitacle vitré et arceau. Silhouette originale.
        frontEnd = frontZ - studs(0.85)
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
                Offset = CFrame.new(
                    studs(place.Lateral),
                    hubY + studs(tire.RadiusM) + 0.45,
                    -studs(place.Longitudinal)
                ),
                Color = bodyColor,
            })
        end

        -- Habitacle : vitrage collisionnable (les piétons ne traversent pas le toit).
        local cabinBottom = tubTop
        local cabinTop = groundY + studs(chassis.HeightM)
        local cabinLength = studs(1.9)
        cabinZ = tubCenterZ + studs(0.15)
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

        seatOffset = CFrame.new(-tubWidth / 4, tubBottom + 0.15, cabinZ + 0.6)
        dashZ = cabinZ - cabinLength / 2 + 0.35
        dashTop = tubTop + 0.2
        sideHalf = tubWidth / 2
        cameraHoodY = tubTop + 0.8
        cameraBumperY = tubBottom + 0.35
        addVisual(root, body, {
            Name = "PlancheDeBord",
            Size = Vector3.new(tubWidth - 0.8, 0.5, 0.7),
            Offset = CFrame.new(0, tubTop + 0.2, dashZ),
            Color = trim,
        })
        addVisual(root, body, {
            Name = "Volant",
            Size = Vector3.new(0.15, 1.1, 1.1),
            Offset = CFrame.new(seatOffset.X, tubTop + 0.45, dashZ + 0.75)
                * CFrame.Angles(math.rad(-25), math.pi / 2, 0),
            Color = trim,
            Shape = "Cylinder",
        })
    end

    -- Siège conducteur (conduite à gauche). Il ne s'active pas au simple
    -- contact (CanTouch = false) : l'embarquement passe par le serveur.
    local seat = Instance.new("Seat")
    seat.Name = "DriverSeat"
    seat.Size = Vector3.new(1.8, 0.4, 1.8)
    seat.CFrame = root.CFrame * seatOffset
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
    -- Lot 0.8 : place passager (radio, photo) ; l'embarquement est revalidé par le serveur.
    if passengerOffset then
        local passenger = Instance.new("Seat")
        passenger.Name = "PassengerSeat"
        passenger.Size = Vector3.new(1.8, 0.4, 1.8)
        passenger.CFrame = root.CFrame * (passengerOffset :: CFrame)
        passenger.Color = trim
        passenger.Massless = true
        passenger.CanCollide = false
        passenger.CanTouch = false
        passenger.Anchored = false
        local passengerWeld = Instance.new("WeldConstraint")
        passengerWeld.Part0 = root
        passengerWeld.Part1 = passenger
        passengerWeld.Parent = passenger
        passenger.Parent = model
    end

    -- Points de vue embarqués (orientés vers l'avant, -Z) : yeux du conducteur
    -- assis, avant du capot, bouclier avant. Dérivés de la géométrie du modèle.
    addAttachment(root, "CameraCockpit", Vector3.new(seatOffset.X, seatOffset.Y + 2.45, seatOffset.Z - 0.35))
    addAttachment(root, "CameraHood", Vector3.new(0, cameraHoodY, frontZ + studs(0.45)))
    addAttachment(root, "CameraBumper", Vector3.new(0, cameraBumperY, frontEnd - 0.65))

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
    local door = addAttachment(root, "DriverDoor", Vector3.new(-sideHalf - 1, 0, cabinZ))
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
    if passengerOffset then
        -- Lot 0.8 : invite passager côté droit (PassengerRules, revalidée par le serveur).
        local passengerDoor = addAttachment(root, "PassengerDoor", Vector3.new(sideHalf + 1, 0, cabinZ))
        local passengerPrompt = Instance.new("ProximityPrompt")
        passengerPrompt.Name = "PassengerPrompt"
        passengerPrompt.ActionText = "Monter (passager)"
        passengerPrompt.ObjectText = definition.DisplayName
        passengerPrompt.HoldDuration = 0.3
        passengerPrompt.MaxActivationDistance = 10
        passengerPrompt.RequiresLineOfSight = false
        passengerPrompt.KeyboardKeyCode = Enum.KeyCode.E
        passengerPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
        passengerPrompt.Parent = passengerDoor
    end

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
    -- Orientation : axe long du plot, à plat (le véhicule regarde vers -Z local).
    local look = pad.CFrame.LookVector * Vector3.new(1, 0, 1)
    if look.Magnitude < 1e-3 then
        look = Vector3.new(0, 0, -1)
    end
    local position = Vector3.new(pad.Position.X, groundTop + height, pad.Position.Z)
    return CFrame.lookAt(position, position + look.Unit)
end

return VehicleFactory
