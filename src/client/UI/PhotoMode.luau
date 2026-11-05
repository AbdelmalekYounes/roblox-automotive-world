--!strict
--[[
    Mode photo (lot 0.8, AUD-PHOTO-01) côté client. Règles : PhotoRules.

    - Ouverture à pied ou conducteur/passager à l'arrêt, jamais en course ;
      fermeture automatique si le contexte cesse d'être autorisé.
    - Caméra scriptée BORNÉE autour du sujet (rayon, hauteur) et tronquée au
      premier obstacle (rayon lancé depuis le sujet) : pas de traversée des
      murs ni des propriétés.
    - Réglages LOCAUX : zoom, exposition, profondeur de champ, filtres ;
      effets créés dans la caméra et détruits à la sortie. Aucune pause,
      aucune météo modifiée, rien de répliqué.
    - Masquage de l'interface (ScreenGui du joueur et interface Roblox),
      restaurée À L'IDENTIQUE à la sortie, comme la caméra (type, sujet,
      position, champ de vision).
    - Capture : CaptureService de Roblox (capture puis enregistrement dans la
      galerie Roblox ou partage, proposés au joueur : rien n'est envoyé sans
      son accord). Si l'API n'est pas disponible, le joueur est invité à
      utiliser la capture d'écran de Roblox. Aucune galerie propre au jeu.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PhotoRules = require(Shared:WaitForChild("Photo"):WaitForChild("PhotoRules"))
local Localization = require(Shared:WaitForChild("UI"):WaitForChild("Localization"))
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))

local UITheme = require(script.Parent.UITheme)
local Tokens =
    require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("DesignTokens"))
local UIState = require(script.Parent.UIState)
local UIManager = require(script.Parent.UIManager)
local NotificationService = require(script.Parent.NotificationService)

local PhotoMode = {}

local S = 1 / Constants.MetersPerStud
local MOVE_MS = 4 -- vitesse de déplacement de la caméra (m/s)
local TURN_RAD_S = 1.6
local ACTION = "AWPhotoControls"
local MOVE_KEYS = {
    Enum.KeyCode.W,
    Enum.KeyCode.A,
    Enum.KeyCode.S,
    Enum.KeyCode.D,
    Enum.KeyCode.Q,
    Enum.KeyCode.E,
    Enum.KeyCode.Up,
    Enum.KeyCode.Down,
    Enum.KeyCode.Left,
    Enum.KeyCode.Right,
    Enum.KeyCode.Space,
    Enum.KeyCode.I,
    Enum.KeyCode.Thumbstick1,
    Enum.KeyCode.Thumbstick2,
}

local racingCheck: () -> boolean = function()
    return false
end

local gui: ScreenGui
local panel: Frame
local statusLabel: TextLabel
local active = false
local interfaceHidden = false

type Saved = {
    CameraType: Enum.CameraType,
    Subject: Instance?,
    CFrame: CFrame,
    Fov: number,
    Guis: { [ScreenGui]: boolean },
    Core: { [Enum.CoreGuiType]: boolean },
}
local saved: Saved? = nil
local state = {
    Yaw = 0,
    Pitch = 0,
    Position = Vector3.zero,
    Fov = PhotoRules.Fov.Default,
    Exposure = 0,
    Dof = false,
    Focus = 10,
    Filter = 1,
}
local grading: ColorCorrectionEffect? = nil
local dof: DepthOfFieldEffect? = nil
local stick1, stick2 = Vector3.zero, Vector3.zero
local renderConnection: RBXScriptConnection? = nil

local function context(): PhotoRules.Context
    local character = Players.LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local seat = humanoid and humanoid.SeatPart
    local speed = if seat then seat.AssemblyLinearVelocity.Magnitude / S * 3.6 else 0
    return {
        OnFoot = humanoid ~= nil and seat == nil,
        Seat = if seat == nil then "None" elseif seat.Name == "DriverSeat" then "Driver" else "Passenger",
        SpeedKmh = speed,
        Racing = racingCheck(),
    }
end

-- Sujet de la photo : le véhicule occupé, sinon le personnage.
local function subject(): (Vector3?, { Instance })
    local character = Players.LocalPlayer.Character
    if character == nil then
        return nil, {}
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local seat = humanoid and humanoid.SeatPart
    local vehicle = if seat then seat:FindFirstAncestorOfClass("Model") else nil
    local ignore: { Instance } = { character }
    if vehicle then
        table.insert(ignore, vehicle)
        return vehicle:GetPivot().Position, ignore
    end
    local root = character:FindFirstChild("HumanoidRootPart")
    return if root and root:IsA("BasePart") then root.Position else nil, ignore
end

local function applyEffects()
    local camera = Workspace.CurrentCamera
    if camera == nil then
        return
    end
    camera.FieldOfView = state.Fov
    local filter = PhotoRules.filter(PhotoRules.Filters[state.Filter])
    if grading then
        local g = grading :: ColorCorrectionEffect
        g.Brightness = state.Exposure * 0.3
        g.TintColor = Color3.fromRGB(filter.Tint[1], filter.Tint[2], filter.Tint[3])
        g.Saturation = filter.Saturation
        g.Contrast = filter.Contrast
    end
    if dof then
        local d = dof :: DepthOfFieldEffect
        d.Enabled = state.Dof
        d.FocusDistance = state.Focus * S
        d.InFocusRadius = 4 * S
        d.FarIntensity = 0.6
        d.NearIntensity = 0.3
    end
    statusLabel.Text = Localization.t("photo.status", {
        fov = state.Fov,
        exposure = string.format("%+.1f", state.Exposure),
        dof = Localization.t(if state.Dof then "ui.on" else "ui.off"),
        focus = state.Focus,
        filter = Localization.t("photo.filter." .. PhotoRules.Filters[state.Filter]),
    })
end

local function setInterfaceHidden(hide: boolean)
    interfaceHidden = hide
    local record = saved
    if record == nil then
        return
    end
    for screen, enabled in record.Guis do
        if screen.Parent then
            screen.Enabled = if hide then false else enabled
        end
    end
    panel.Visible = not hide
    for coreType, enabled in record.Core do
        pcall(function()
            StarterGui:SetCoreGuiEnabled(coreType, if hide then false else enabled)
        end)
    end
end

local function step(dt: number)
    local camera = Workspace.CurrentCamera
    local center, ignore = subject()
    if camera == nil or center == nil then
        return
    end
    local allowed, reason = PhotoRules.allowed(context())
    if not allowed then
        NotificationService.notify(reason or "PhotoUnavailable", "Warning")
        UIManager.close("Photo")
        return
    end
    local function down(key: Enum.KeyCode): number
        return if UserInputService:IsKeyDown(key) then 1 else 0
    end
    local yawInput = down(Enum.KeyCode.Left) - down(Enum.KeyCode.Right) - stick2.X
    local pitchInput = down(Enum.KeyCode.Up) - down(Enum.KeyCode.Down) + stick2.Y
    state.Yaw += yawInput * TURN_RAD_S * dt
    state.Pitch = math.clamp(state.Pitch + pitchInput * TURN_RAD_S * dt, -1.3, 1.3)
    local look = CFrame.fromOrientation(state.Pitch, state.Yaw, 0)
    local forward = down(Enum.KeyCode.W) - down(Enum.KeyCode.S) + stick1.Y
    local right = down(Enum.KeyCode.D) - down(Enum.KeyCode.A) + stick1.X
    local up = down(Enum.KeyCode.E) - down(Enum.KeyCode.Q)
    local move = look.LookVector * forward + look.RightVector * right + Vector3.yAxis * up
    local desired = state.Position + move * MOVE_MS * S * dt
    -- Bornes : rayon autour du sujet, hauteur, premier obstacle.
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore
    local offset = desired - center
    local hit = if offset.Magnitude > 0.01 then Workspace:Raycast(center, offset, params) else nil
    local bounded = PhotoRules.clamp(
        { X = center.X / S, Y = center.Y / S, Z = center.Z / S },
        { X = desired.X / S, Y = desired.Y / S, Z = desired.Z / S },
        if hit then (hit.Position - center).Magnitude / S else nil
    )
    state.Position = Vector3.new(bounded.X * S, bounded.Y * S, bounded.Z * S)
    camera.CFrame = CFrame.new(state.Position) * look
end

local function enter()
    local camera = Workspace.CurrentCamera
    local center = subject()
    if camera == nil or center == nil then
        return
    end
    local guis: { [ScreenGui]: boolean } = {}
    for _, item in Players.LocalPlayer:WaitForChild("PlayerGui"):GetChildren() do
        if item:IsA("ScreenGui") and item ~= gui then
            guis[item] = item.Enabled
        end
    end
    local core: { [Enum.CoreGuiType]: boolean } = {}
    for _, coreType in Enum.CoreGuiType:GetEnumItems() do
        if coreType ~= Enum.CoreGuiType.All then
            local ok, enabled = pcall(function()
                return StarterGui:GetCoreGuiEnabled(coreType)
            end)
            if ok then
                core[coreType] = enabled
            end
        end
    end
    saved = {
        CameraType = camera.CameraType,
        Subject = camera.CameraSubject,
        CFrame = camera.CFrame,
        Fov = camera.FieldOfView,
        Guis = guis,
        Core = core,
    }
    local _, yaw, _ = camera.CFrame:ToOrientation()
    state.Yaw, state.Pitch = yaw, -0.15
    state.Position = camera.CFrame.Position
    state.Fov = math.clamp(camera.FieldOfView, PhotoRules.Fov.Min, PhotoRules.Fov.Max)
    camera.CameraType = Enum.CameraType.Scriptable
    local g = Instance.new("ColorCorrectionEffect")
    g.Name = "AWPhotoEtalonnage"
    g.Parent = camera
    grading = g
    local d = Instance.new("DepthOfFieldEffect")
    d.Name = "AWPhotoProfondeur"
    d.Enabled = false
    d.Parent = camera
    dof = d
    -- Les commandes de déplacement servent à la caméra (le personnage ne bouge pas).
    ContextActionService:BindActionAtPriority(ACTION, function(_, inputState, input)
        if input.KeyCode == Enum.KeyCode.Thumbstick1 then
            stick1 = if inputState == Enum.UserInputState.End then Vector3.zero else input.Position
        elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
            stick2 = if inputState == Enum.UserInputState.End then Vector3.zero else input.Position
        elseif input.KeyCode == Enum.KeyCode.I and inputState == Enum.UserInputState.Begin then
            setInterfaceHidden(not interfaceHidden)
        end
        return Enum.ContextActionResult.Sink
    end, false, Enum.ContextActionPriority.High.Value + 10, table.unpack(MOVE_KEYS))
    active = true
    gui.Enabled = true
    applyEffects()
    renderConnection = RunService.RenderStepped:Connect(step)
end

-- Sortie : tout est restauré à l'identique (caméra, interface, effets).
local function leave()
    if not active then
        return
    end
    active = false
    if renderConnection then
        (renderConnection :: RBXScriptConnection):Disconnect()
        renderConnection = nil
    end
    ContextActionService:UnbindAction(ACTION)
    stick1, stick2 = Vector3.zero, Vector3.zero
    setInterfaceHidden(false)
    local camera = Workspace.CurrentCamera
    local record = saved
    if camera and record then
        camera.CameraType = record.CameraType
        camera.CameraSubject = record.Subject
        camera.CFrame = record.CFrame
        camera.FieldOfView = record.Fov
    end
    if grading then
        (grading :: ColorCorrectionEffect):Destroy()
        grading = nil
    end
    if dof then
        (dof :: DepthOfFieldEffect):Destroy()
        dof = nil
    end
    saved = nil
    gui.Enabled = false
end

local function capture()
    setInterfaceHidden(true)
    task.wait(0.1)
    local ok = pcall(function()
        local service: any = game:GetService("CaptureService" :: any)
        service:CaptureScreenshot(function(content: any)
            setInterfaceHidden(false)
            -- Enregistrement dans la galerie Roblox : proposé, jamais imposé.
            pcall(function()
                service:PromptSaveCapturesToGallery({ content }, function() end)
            end)
        end)
    end)
    if not ok then
        setInterfaceHidden(false)
        NotificationService.notify("photo.captureUnavailable", "Info")
    end
end

-- Demande d'ouverture (raccourci ou téléphone) : contrôle des règles d'abord.
function PhotoMode.request()
    if active then
        UIManager.close("Photo")
        return
    end
    local allowed, reason = PhotoRules.allowed(context())
    if not allowed then
        NotificationService.notify(reason or "PhotoUnavailable", "Warning")
        return
    end
    UIManager.open("Photo")
end

function PhotoMode.setRacingCheck(check: () -> boolean)
    racingCheck = check
end

function PhotoMode.active(): boolean
    return active
end

function PhotoMode.start()
    gui = UITheme.make(
        "ScreenGui",
        { Name = "AWPhoto", ResetOnSpawn = false, DisplayOrder = 30, Enabled = false },
        Players.LocalPlayer:WaitForChild("PlayerGui")
    )
    -- Barre du mode photo V1.2 : carte sombre à filet, état en tête, commandes de 36 px ; échelle 1440 p.
    panel = UITheme.panel({
        Name = "BarrePhoto",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -16),
        Size = UDim2.fromOffset(760, 140),
    }, gui)
    panel.BackgroundColor3 = Tokens.color("BgBase")
    UITheme.make("UIStroke", { Color = Tokens.color("Line"), Thickness = 1 }, panel)
    local panelScale = UITheme.make("UIScale", {}, panel)
    local function rescale()
        panelScale.Scale = UIState.layout().Scale
    end
    rescale()
    UIState.onViewport(rescale)
    statusLabel = UITheme.label("", 14, {
        Position = UDim2.fromOffset(12, 6),
        Size = UDim2.new(1, -24, 0, 22),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, panel)
    local help = UITheme.label(Localization.t("photo.help"), 13, {
        Name = "Aide",
        Position = UDim2.fromOffset(12, 28),
        Size = UDim2.new(1, -24, 0, 20),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = UITheme.color("TextDim"),
    }, panel)
    Localization.changed(function()
        help.Text = Localization.t("photo.help")
    end)
    local row = UITheme.make("Frame", {
        Position = UDim2.fromOffset(12, 54),
        Size = UDim2.new(1, -24, 0, 78),
        BackgroundTransparency = 1,
    }, panel)
    UITheme.make("UIGridLayout", { CellSize = UDim2.fromOffset(140, 36), CellPadding = UDim2.fromOffset(6, 6) }, row)
    local function control(key: string, fn: () -> ())
        UITheme.button(Localization.t(key), { Name = key }, row, function()
            fn()
            applyEffects()
        end)
    end
    control("photo.zoomIn", function()
        state.Fov = PhotoRules.step(state.Fov, -PhotoRules.Fov.Step, PhotoRules.Fov)
    end)
    control("photo.zoomOut", function()
        state.Fov = PhotoRules.step(state.Fov, PhotoRules.Fov.Step, PhotoRules.Fov)
    end)
    control("photo.exposureUp", function()
        state.Exposure = PhotoRules.step(state.Exposure, PhotoRules.Exposure.Step, PhotoRules.Exposure)
    end)
    control("photo.exposureDown", function()
        state.Exposure = PhotoRules.step(state.Exposure, -PhotoRules.Exposure.Step, PhotoRules.Exposure)
    end)
    control("photo.dof", function()
        state.Dof = not state.Dof
    end)
    control("photo.focus", function()
        state.Focus = if state.Focus >= PhotoRules.Focus.Max
            then PhotoRules.Focus.Min
            else PhotoRules.step(state.Focus, PhotoRules.Focus.Step, PhotoRules.Focus)
    end)
    control("photo.filter", function()
        state.Filter = state.Filter % #PhotoRules.Filters + 1
    end)
    control("photo.hide", function()
        setInterfaceHidden(true)
    end)
    control("photo.capture", function()
        task.spawn(capture)
    end)
    control("photo.exit", function()
        UIManager.close("Photo")
    end)
    UIManager.register({
        Name = "Photo",
        Kind = "Modal",
        Full = true,
        Open = enter,
        Close = leave,
        Focus = function()
            return row:FindFirstChildWhichIsA("GuiButton")
        end,
    })
end

return PhotoMode
