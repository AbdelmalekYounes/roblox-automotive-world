--!strict
-- Caméras du véhicule piloté (cahier des charges §3.4) :
-- - poursuite proche et lointaine (lot 0.1) ;
-- - cockpit, capot et pare-chocs (lot 0.2) : vues solidaires du véhicule,
--   placées sur des attachements que VehicleFactory dérive de la géométrie de
--   chaque modèle (tête du conducteur, avant du capot, bouclier avant).
-- Changer de vue ne touche ni aux commandes ni à la simulation. Le mode photo
-- (§9.3) n'est pas dans ce lot.

local Workspace = game:GetService("Workspace")

local VehicleCamera = {}
VehicleCamera.__index = VehicleCamera

export type Preset = {
    Name: string,
    Kind: "Chase" | "Mounted",
    -- Poursuite.
    Distance: number,
    Height: number,
    FocusHeight: number,
    LookAhead: number,
    -- Vue embarquée : attachement du châssis et champ de vision.
    Attachment: string?,
    Fov: number,
}

local PRESETS: { Preset } = {
    { Name = "Proche", Kind = "Chase", Distance = 13, Height = 4.2, FocusHeight = 2.2, LookAhead = 6, Fov = 70 },
    { Name = "Lointaine", Kind = "Chase", Distance = 22, Height = 7, FocusHeight = 2.5, LookAhead = 8, Fov = 70 },
    {
        Name = "Cockpit",
        Kind = "Mounted",
        Distance = 0,
        Height = 0,
        FocusHeight = 0,
        LookAhead = 0,
        Attachment = "CameraCockpit",
        Fov = 75,
    },
    {
        Name = "Capot",
        Kind = "Mounted",
        Distance = 0,
        Height = 0,
        FocusHeight = 0,
        LookAhead = 0,
        Attachment = "CameraHood",
        Fov = 72,
    },
    {
        Name = "Pare-chocs",
        Kind = "Mounted",
        Distance = 0,
        Height = 0,
        FocusHeight = 0,
        LookAhead = 0,
        Attachment = "CameraBumper",
        Fov = 72,
    },
}

local HEADING_SMOOTHING = 5
local POSITION_SMOOTHING = 14
-- Vue embarquée : léger lissage de l'orientation seulement (pas de retard de position).
local MOUNT_ROTATION_SMOOTHING = 25

type CameraFields = {
    Camera: Camera,
    Model: Model?,
    Root: BasePart?,
    Character: Model?,
    PresetIndex: number,
    Heading: Vector3,
    Position: Vector3?,
    MountRotation: CFrame?,
    Params: RaycastParams,
    PreviousType: Enum.CameraType,
    PreviousFov: number,
    CharacterHidden: boolean,
}

export type VehicleCamera = typeof(setmetatable({} :: CameraFields, VehicleCamera))

function VehicleCamera.new(): VehicleCamera
    local camera = Workspace.CurrentCamera :: Camera
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.RespectCanCollide = true
    return setmetatable(
        {
            Camera = camera,
            Model = nil,
            Root = nil,
            Character = nil,
            PresetIndex = 1,
            Heading = Vector3.new(0, 0, -1),
            Position = nil,
            MountRotation = nil,
            Params = params,
            PreviousType = camera.CameraType,
            PreviousFov = camera.FieldOfView,
            CharacterHidden = false,
        } :: CameraFields,
        VehicleCamera
    )
end

-- En cockpit, le personnage du conducteur masquerait la vue : il est rendu
-- invisible LOCALEMENT (les autres joueurs le voient toujours).
local function setCharacterHidden(self: VehicleCamera, hidden: boolean)
    if self.CharacterHidden == hidden then
        return
    end
    self.CharacterHidden = hidden
    local character = self.Character
    if character == nil then
        return
    end
    for _, descendant in character:GetDescendants() do
        if descendant:IsA("BasePart") or descendant:IsA("Decal") then
            (descendant :: any).LocalTransparencyModifier = if hidden then 1 else 0
        end
    end
end

function VehicleCamera.start(self: VehicleCamera, model: Model, character: Model?)
    local root = model.PrimaryPart
    if root == nil then
        return
    end
    self.Camera = Workspace.CurrentCamera :: Camera
    self.Model = model
    self.Root = root
    self.Character = character
    self.PreviousType = self.Camera.CameraType
    self.PreviousFov = self.Camera.FieldOfView
    local look = root.CFrame.LookVector
    self.Heading = Vector3.new(look.X, 0, look.Z).Unit
    self.Position = nil
    self.MountRotation = nil
    self.CharacterHidden = false
    self.Params.FilterDescendantsInstances = if character then { model, character } else { model }
    self.Camera.CameraType = Enum.CameraType.Scriptable
end

function VehicleCamera.stop(self: VehicleCamera, humanoid: Humanoid?)
    if self.Model == nil then
        return
    end
    setCharacterHidden(self, false)
    self.Model = nil
    self.Root = nil
    self.Character = nil
    self.Camera.CameraType = Enum.CameraType.Custom
    self.Camera.FieldOfView = self.PreviousFov
    if humanoid then
        self.Camera.CameraSubject = humanoid
    end
end

-- Vue suivante ; retourne son nom (affiché par le HUD).
function VehicleCamera.togglePreset(self: VehicleCamera): string
    self.PresetIndex = self.PresetIndex % #PRESETS + 1
    self.Position = nil
    self.MountRotation = nil
    return PRESETS[self.PresetIndex].Name
end

function VehicleCamera.presetName(self: VehicleCamera): string
    return PRESETS[self.PresetIndex].Name
end

function VehicleCamera.presetNames(): { string }
    local names = {}
    for _, preset in PRESETS do
        table.insert(names, preset.Name)
    end
    return names
end

local function updateMounted(self: VehicleCamera, root: BasePart, preset: Preset, dt: number): boolean
    local attachment = root:FindFirstChild(preset.Attachment :: string)
    if attachment == nil or not attachment:IsA("Attachment") then
        return false
    end
    local target = attachment.WorldCFrame
    local rotation = target.Rotation
    local previous = self.MountRotation
    if previous then
        rotation = previous:Lerp(rotation, 1 - math.exp(-MOUNT_ROTATION_SMOOTHING * dt))
    end
    self.MountRotation = rotation
    self.Camera.FieldOfView = preset.Fov
    self.Camera.CFrame = CFrame.new(target.Position) * rotation
    setCharacterHidden(self, preset.Attachment == "CameraCockpit")
    return true
end

function VehicleCamera.update(self: VehicleCamera, dt: number)
    local root = self.Root
    if root == nil or root.Parent == nil then
        return
    end
    local preset = PRESETS[self.PresetIndex]
    if preset.Kind == "Mounted" and updateMounted(self, root, preset, dt) then
        return
    end
    setCharacterHidden(self, false)
    local cframe = root.CFrame
    local flatLook = Vector3.new(cframe.LookVector.X, 0, cframe.LookVector.Z)
    if flatLook.Magnitude > 0.2 then
        -- Lissage exponentiel indépendant de la cadence d'image.
        local alpha = 1 - math.exp(-HEADING_SMOOTHING * dt)
        local blended = self.Heading:Lerp(flatLook.Unit, alpha)
        if blended.Magnitude > 1e-3 then
            self.Heading = blended.Unit
        end
    end

    local focus = root.Position + Vector3.new(0, preset.FocusHeight, 0)
    local desired = focus - self.Heading * preset.Distance + Vector3.new(0, preset.Height, 0)

    -- Évite que la caméra traverse murs et décors.
    local offset = desired - focus
    local hit = Workspace:Raycast(focus, offset, self.Params)
    if hit then
        desired = hit.Position - offset.Unit * 0.5
    end

    local previous = self.Position
    local position = if previous then previous:Lerp(desired, 1 - math.exp(-POSITION_SMOOTHING * dt)) else desired
    self.Position = position

    local speed = root.AssemblyLinearVelocity.Magnitude
    self.Camera.FieldOfView = preset.Fov + math.min(speed * 0.06, 12)
    self.Camera.CFrame = CFrame.lookAt(position, focus + self.Heading * preset.LookAhead)
end

return VehicleCamera
