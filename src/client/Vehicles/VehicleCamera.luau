--!strict
-- Caméra de poursuite du véhicule piloté : deux distances (proche / lointaine).
-- Les caméras cockpit, capot, pare-chocs et le mode photo (cahier des charges
-- §3.4 et §9.3) ne sont PAS implémentés dans le lot 0.1.

local Workspace = game:GetService("Workspace")

local VehicleCamera = {}
VehicleCamera.__index = VehicleCamera

export type Preset = {
    Name: string,
    Distance: number,
    Height: number,
    FocusHeight: number,
    LookAhead: number,
}

local PRESETS: { Preset } = {
    { Name = "Proche", Distance = 13, Height = 4.2, FocusHeight = 2.2, LookAhead = 6 },
    { Name = "Lointaine", Distance = 22, Height = 7, FocusHeight = 2.5, LookAhead = 8 },
}

local BASE_FOV = 70
local HEADING_SMOOTHING = 5
local POSITION_SMOOTHING = 14

type CameraFields = {
    Camera: Camera,
    Model: Model?,
    Root: BasePart?,
    PresetIndex: number,
    Heading: Vector3,
    Position: Vector3?,
    Params: RaycastParams,
    PreviousType: Enum.CameraType,
    PreviousFov: number,
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
            PresetIndex = 1,
            Heading = Vector3.new(0, 0, -1),
            Position = nil,
            Params = params,
            PreviousType = camera.CameraType,
            PreviousFov = camera.FieldOfView,
        } :: CameraFields,
        VehicleCamera
    )
end

function VehicleCamera.start(self: VehicleCamera, model: Model, character: Model?)
    local root = model.PrimaryPart
    if root == nil then
        return
    end
    self.Camera = Workspace.CurrentCamera :: Camera
    self.Model = model
    self.Root = root
    self.PreviousType = self.Camera.CameraType
    self.PreviousFov = self.Camera.FieldOfView
    local look = root.CFrame.LookVector
    self.Heading = Vector3.new(look.X, 0, look.Z).Unit
    self.Position = nil
    self.Params.FilterDescendantsInstances = if character then { model, character } else { model }
    self.Camera.CameraType = Enum.CameraType.Scriptable
end

function VehicleCamera.stop(self: VehicleCamera, humanoid: Humanoid?)
    if self.Model == nil then
        return
    end
    self.Model = nil
    self.Root = nil
    self.Camera.CameraType = Enum.CameraType.Custom
    self.Camera.FieldOfView = self.PreviousFov
    if humanoid then
        self.Camera.CameraSubject = humanoid
    end
end

function VehicleCamera.togglePreset(self: VehicleCamera): string
    self.PresetIndex = self.PresetIndex % #PRESETS + 1
    return PRESETS[self.PresetIndex].Name
end

function VehicleCamera.update(self: VehicleCamera, dt: number)
    local root = self.Root
    if root == nil or root.Parent == nil then
        return
    end
    local preset = PRESETS[self.PresetIndex]
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
    self.Camera.FieldOfView = BASE_FOV + math.min(speed * 0.06, 12)
    self.Camera.CFrame = CFrame.lookAt(position, focus + self.Heading * preset.LookAhead)
end

return VehicleCamera
