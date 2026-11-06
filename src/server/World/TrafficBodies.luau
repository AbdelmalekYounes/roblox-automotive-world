--!strict
--[[
    Lot PNJ-01 : corps physiques des voitures PNJ (construits par le serveur pour World/TrafficService).

    - La COLLISION reste une boîte simple (une pièce, « Caisse ») aux cotes de la silhouette (World/PnjKits) : coût
      physique inchangé, contact cohérent avec DamageService (obstacle non ancré de masse connue) ;
    - le VISUEL vient du gabarit 3D de la silhouette (ReplicatedStorage.AutomotiveWorldPnjKits) s'il est présent ET si
      chacun de ses maillages est inscrit au manifeste d'actifs (aucun identifiant inconnu) ; sinon un REPLI en pièces
      simples portant les mêmes noms (roues, feux stop, clignotants, phares, habitacle) ;
    - toutes les pièces visuelles sont sans masse, sans collision, sans requête ni contact : elles ne perturbent ni
      la physique ni les lancers de rayon des suspensions des joueurs ;
    - roues reliées par Motor6D : chaque client les fait tourner et braquer localement (World/TrafficVisuals), sans
      aucun échange réseau.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PnjKits = require(Shared:WaitForChild("World"):WaitForChild("PnjKits"))
local AssetManifest = require(Shared:WaitForChild("Assets"):WaitForChild("AssetManifest"))
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))

local TrafficBodies = {}

local S = 1 / Constants.MetersPerStud -- studs par mètre
-- Densité de la caisse : masse du même ordre que celle des véhicules des joueurs (inchangée depuis le lot 0.3).
local BODY_DENSITY = 8

export type Body = {
    Model: Model,
    Root: BasePart,
    Align: AlignPosition,
    Orient: AlignOrientation,
    Car: PnjKits.CarSilhouette,
    -- Dernier état publié (attributs) : seuls les changements sont envoyés.
    Brake: boolean,
    Indicator: string?,
}

-- Gabarits validés (nil = repli), mis en cache par silhouette ; la raison est consultable pour le rapport.
local templates: { [string]: Model } = {}
-- Repère d'origine du contrat dans chaque gabarit (au sol, centre de l'empattement, avant vers −Z), déduit des roues :
-- le pivot d'un modèle importé dans Studio n'est pas fiable.
local origins: { [string]: CFrame } = {}
local refused: { [string]: boolean } = {}
TrafficBodies.TemplateStatus = {} :: { [string]: string }

local function assetNumber(content: string): number?
    local digits = string.match(content, "(%d+)%s*$")
    return if digits then tonumber(digits) else nil
end

local function template(car: PnjKits.CarSilhouette): Model?
    if refused[car.Id] then
        return nil
    end
    local cached = templates[car.Id]
    if cached then
        return cached
    end
    local function refuse(reason: string): Model?
        refused[car.Id] = true
        TrafficBodies.TemplateStatus[car.Id] = reason
        return nil
    end
    local folder = ReplicatedStorage:FindFirstChild(PnjKits.FolderName)
    local model = folder and folder:FindFirstChild(car.Template)
    if model == nil or not model:IsA("Model") then
        return refuse("GabaritAbsent")
    end
    local allowed: { [number]: boolean } = {}
    local entry = AssetManifest.get(PnjKits.CarManifestId)
    if entry and entry.RobloxAssetIds then
        for _, id in entry.RobloxAssetIds do
            allowed[id] = true
        end
    end
    local names: { [string]: boolean } = {}
    for _, item in model:GetDescendants() do
        if item:IsA("BasePart") then
            names[item.Name] = true
        end
        if item:IsA("MeshPart") then
            local id = assetNumber(item.MeshId)
            if id == nil or not allowed[id] then
                return refuse("MaillageNonAutorise")
            end
        end
    end
    if #PnjKits.missingCarParts(names) > 0 then
        return refuse("GabaritIncomplet")
    end
    local centers: { [string]: Vector3 } = {}
    local radius = 0
    for _, name in PnjKits.Wheels do
        local wheel = model:FindFirstChild(name, true) :: BasePart
        centers[name] = wheel.Position
        radius += math.max(wheel.Size.Y, wheel.Size.Z) / 8
    end
    local front = (centers.Roue_AVG + centers.Roue_AVD) / 2
    local rear = (centers.Roue_ARG + centers.Roue_ARD) / 2
    local forward = Vector3.new(front.X - rear.X, 0, front.Z - rear.Z)
    if forward.Magnitude < 1e-3 then
        return refuse("RouesIncoherentes")
    end
    local base = (front + rear) / 2 - Vector3.new(0, radius, 0)
    origins[car.Id] = CFrame.lookAt(base, base + forward.Unit)
    templates[car.Id] = model
    TrafficBodies.TemplateStatus[car.Id] = "Gabarit3D"
    return model
end

local function visualPart(model: Model, name: string, size: Vector3, color: Color3, material: Enum.Material): Part
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.Color = color
    part.Material = material
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Massless = true
    part.CastShadow = false
    part.Parent = model
    return part
end

local function weld(root: BasePart, part: BasePart)
    local w = Instance.new("WeldConstraint")
    w.Part0 = root
    w.Part1 = part
    w.Parent = part
end

-- Roue reliée par Motor6D (axe = X de la voiture) : le client règle Transform (rotation, braquage).
local function wheelJoint(root: BasePart, wheel: BasePart, center: Vector3)
    local pivot = CFrame.new(center) * root.CFrame.Rotation
    local motor = Instance.new("Motor6D")
    motor.Name = "Axe"
    motor.Part0 = root
    motor.Part1 = wheel
    motor.C0 = root.CFrame:ToObjectSpace(pivot)
    motor.C1 = wheel.CFrame:ToObjectSpace(pivot)
    motor.Parent = wheel
end

-- Repli en pièces simples (mêmes noms que le gabarit). `origin` = repère voiture au sol (studs).
local function buildFallback(model: Model, root: BasePart, car: PnjKits.CarSilhouette, origin: CFrame, color: Color3)
    local function at(x: number, y: number, z: number): CFrame
        return origin * CFrame.new(x * S, y * S, z * S)
    end
    -- Le dessus de la boîte de collision porte l'habitacle vitré.
    local top = PnjKits.ClearanceM + car.BoxHeightM
    local cabinHeight = car.HeightM - top
    local cabin = visualPart(
        model,
        "Vitrage",
        Vector3.new(car.WidthM - 0.14, cabinHeight, car.CabinLengthM) * S,
        Color3.fromRGB(30, 35, 45),
        Enum.Material.Glass
    )
    cabin.Transparency = 0.2
    cabin.CFrame = at(0, top + cabinHeight / 2, car.CabinOffsetM)
    weld(root, cabin)
    local roof = visualPart(
        model,
        "Peinture_Toit",
        Vector3.new(car.WidthM - 0.22, 0.05, car.CabinLengthM - 0.25) * S,
        color,
        Enum.Material.SmoothPlastic
    )
    roof.CFrame = at(0, car.HeightM - 0.02, car.CabinOffsetM)
    weld(root, roof)

    for _, name in PnjKits.Wheels do
        local center = PnjKits.wheelCenter(car, name)
        local wheel = visualPart(
            model,
            name,
            Vector3.new(car.WheelWidthM, car.WheelRadiusM * 2, car.WheelRadiusM * 2) * S,
            Color3.fromRGB(25, 25, 28),
            Enum.Material.SmoothPlastic
        )
        wheel.Shape = Enum.PartType.Cylinder
        wheel.CFrame = at(center.X, center.Y, center.Z)
        -- Enjoliveur décalé : rend la rotation visible sur un cylindre uniforme.
        local side = if center.X < 0 then -1 else 1
        local hub = visualPart(
            model,
            "Jante",
            Vector3.new(0.02, car.WheelRadiusM * 0.45, car.WheelRadiusM * 1.1) * S,
            Color3.fromRGB(170, 170, 175),
            Enum.Material.Metal
        )
        hub.CFrame = wheel.CFrame * CFrame.new(side * (car.WheelWidthM / 2 + 0.005) * S, 0, 0)
        weld(wheel, hub)
        wheelJoint(root, wheel, wheel.Position)
    end

    local halfW = car.WidthM / 2
    local lampY = PnjKits.ClearanceM + car.BoxHeightM * 0.7
    local function lamp(name: string, x: number, z: number, size: Vector3, tint: Color3)
        local part = visualPart(model, name, size * S, tint, Enum.Material.SmoothPlastic)
        part.CFrame = at(x, lampY, z)
        weld(root, part)
    end
    local back, front = car.ArriereM + 0.01, -(car.AvantM + 0.01)
    lamp("Feu_Stop_G", -(halfW - 0.2), back, Vector3.new(0.3, 0.15, 0.04), Color3.fromRGB(110, 15, 15))
    lamp("Feu_Stop_D", halfW - 0.2, back, Vector3.new(0.3, 0.15, 0.04), Color3.fromRGB(110, 15, 15))
    lamp("Clignotant_ARG", -(halfW - 0.05), back, Vector3.new(0.1, 0.12, 0.04), Color3.fromRGB(120, 75, 20))
    lamp("Clignotant_ARD", halfW - 0.05, back, Vector3.new(0.1, 0.12, 0.04), Color3.fromRGB(120, 75, 20))
    lamp("Phare_G", -(halfW - 0.3), front, Vector3.new(0.34, 0.14, 0.04), Color3.fromRGB(190, 190, 180))
    lamp("Phare_D", halfW - 0.3, front, Vector3.new(0.34, 0.14, 0.04), Color3.fromRGB(190, 190, 180))
    lamp("Clignotant_AVG", -(halfW - 0.06), front, Vector3.new(0.1, 0.1, 0.04), Color3.fromRGB(120, 75, 20))
    lamp("Clignotant_AVD", halfW - 0.06, front, Vector3.new(0.1, 0.1, 0.04), Color3.fromRGB(120, 75, 20))
end

-- Visuel 3D cloné du gabarit, posé sur le repère voiture `origin` ; couleurs unies réappliquées (PnjKits.PartStyles),
-- peinture teintée ; roues en Motor6D, jantes soudées à leur roue, le reste soudé à la caisse.
local function buildFromTemplate(
    model: Model,
    root: BasePart,
    source: Model,
    sourceOrigin: CFrame,
    origin: CFrame,
    color: Color3
)
    local clone = source:Clone()
    clone:PivotTo(origin * sourceOrigin:Inverse() * source:GetPivot())
    local parts: { BasePart } = {}
    for _, item in clone:GetDescendants() do
        if item:IsA("BasePart") then
            item.Anchored = false
            item.CanCollide = false
            item.CanQuery = false
            item.CanTouch = false
            item.Massless = true
            if string.find(item.Name, PnjKits.PaintPattern, 1, true) then
                item.Color = color
                item.Material = Enum.Material.SmoothPlastic
            else
                local style = PnjKits.partStyle(item.Name)
                if style then
                    item.Color = style.Color
                    item.Material = style.Material
                    item.Transparency = style.Transparency
                end
            end
            item.Parent = model
            table.insert(parts, item)
        end
    end
    clone:Destroy()
    local wheels: { [string]: BasePart } = {}
    for _, part in parts do
        local wheel, isWheel = PnjKits.wheelOf(part.Name)
        if wheel and isWheel then
            wheels[wheel] = part
            wheelJoint(root, part, part.Position)
        end
    end
    for _, part in parts do
        local wheel, isWheel = PnjKits.wheelOf(part.Name)
        if wheel and not isWheel and wheels[wheel] then
            weld(wheels[wheel], part)
        elseif wheel == nil then
            weld(root, part)
        end
    end
end

--[[
    Construit le corps d'un agent : boîte de collision au repère `frame` (centre de la boîte, studs), visuel 3D ou
    repli, guidage AlignPosition / AlignOrientation à force limitée (inchangé depuis le lot 0.3).
]]
function TrafficBodies.build(
    agentId: number,
    car: PnjKits.CarSilhouette,
    frame: CFrame,
    color: Color3,
    parent: Instance
): Body
    local model = Instance.new("Model")
    model.Name = "PNJ_" .. agentId
    model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
    local root = Instance.new("Part")
    root.Name = "Caisse"
    root.Size = Vector3.new(car.WidthM, car.BoxHeightM, car.LengthM) * S
    root.Color = color
    root.Material = Enum.Material.SmoothPlastic
    root.TopSurface = Enum.SurfaceType.Smooth
    root.BottomSurface = Enum.SurfaceType.Smooth
    root.CustomPhysicalProperties = PhysicalProperties.new(BODY_DENSITY, 0.4, 0.1, 1, 1)
    root.CFrame = frame
    root.Parent = model
    model.PrimaryPart = root

    local origin = frame * CFrame.new(-PnjKits.boxCenter(car) * S)
    local source = template(car)
    if source then
        -- La boîte devient invisible : seul le maillage se voit.
        root.Transparency = 1
        buildFromTemplate(model, root, source, origins[car.Id], origin, color)
    else
        buildFallback(model, root, car, origin, color)
    end

    local attachment = Instance.new("Attachment")
    attachment.Name = "Guidage"
    attachment.Parent = root
    local align = Instance.new("AlignPosition")
    align.Mode = Enum.PositionAlignmentMode.OneAttachment
    align.Attachment0 = attachment
    align.ApplyAtCenterOfMass = true
    align.Responsiveness = 35
    align.Position = frame.Position
    align.Parent = root
    local orient = Instance.new("AlignOrientation")
    orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
    orient.Attachment0 = attachment
    orient.Responsiveness = 25
    orient.CFrame = frame.Rotation
    orient.Parent = root

    model:SetAttribute("AgentId", agentId)
    model:SetAttribute(PnjKits.Attributes.Silhouette, car.Id)
    model:AddTag("AWTrafficVehicle")
    model.Parent = parent
    -- Masse de l'assemblage connue une fois dans Workspace. Force limitée : suffisante pour porter et guider la
    -- caisse, pas pour résister à un choc (le PNJ cède, puis reprend sa trajectoire).
    align.MaxForce = root.AssemblyMass * Workspace.Gravity * 3
    orient.MaxTorque = root.AssemblyMass * 4000
    root:SetNetworkOwner(nil)
    return {
        Model = model,
        Root = root,
        Align = align,
        Orient = orient,
        Car = car,
        Brake = false,
        Indicator = nil,
    }
end

-- Publie l'état des feux (attributs) seulement s'il a changé.
function TrafficBodies.publish(body: Body, brake: boolean, indicator: string?)
    if body.Brake ~= brake then
        body.Brake = brake
        body.Model:SetAttribute(PnjKits.Attributes.Brake, brake)
    end
    if body.Indicator ~= indicator then
        body.Indicator = indicator
        body.Model:SetAttribute(PnjKits.Attributes.Indicator, indicator)
    end
end

return table.freeze(TrafficBodies)
