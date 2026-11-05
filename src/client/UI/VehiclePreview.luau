--!strict
--[[
    Aperçu 3D du véhicule dans la zone gauche du garage (lot UI-03 ; ViewportFrame choisi par le propriétaire le
    2026-11-05, maquette « Garage » §4).

    - La copie visuelle vient du serveur (VehiclePreviewService : une copie inerte par modèle, dans
      ReplicatedStorage) ; elle est clonée dans le ViewportFrame, jamais dans le monde.
    - Teinte : celle de l'exemplaire, ou le brouillon de l'onglet Préparation, appliquée aux pièces marquées
      AWPaintRole par le serveur (aucune autre pièce n'est modifiée).
    - Caméra orbitale (maquette) : vues 3/4, avant, arrière, profil ; boutons de rotation de 15° ; glisser à la souris
      ou au doigt ; molette pour zoomer (0,8 à 1,4) ; stick droit de la manette ; « Réinitialiser » revient en 3/4
      avec la rotation lente. Choisir une vue ou tourner à la main arrête la rotation lente ; elle est aussi coupée par
      « réduire les animations ». Cadrage automatique (PreviewFraming) : jamais coupé, quelle que soit l'orientation.
    - Vignettes des cartes de la collection : ViewportFrame 16:9 fixe en vue 3/4 (maquette), sans calcul par image.
    Angles : degrés, 0 = face avant du véhicule (l'avant des modèles est vers -Z).
    Limite connue du ViewportFrame : éclairage simplifié (une lumière, pas d'ombres, pas de reflets du décor).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PreviewFraming = require(Shared:WaitForChild("UI"):WaitForChild("PreviewFraming"))
local GarageView = require(Shared:WaitForChild("UI"):WaitForChild("GarageView"))
local CosmeticCatalog = require(Shared:WaitForChild("Garage"):WaitForChild("CosmeticCatalog"))
local VehicleDefinitions = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleDefinitions"))
local UIState = require(script.Parent.UIState)

local VehiclePreview = {}

local FOLDER_NAME = "AWVehiclePreview"
-- Nouvelles tentatives quand le serveur refuse une demande trop rapprochée (changement rapide de véhicule).
local RETRIES = 4

local viewport: ViewportFrame? = nil
local camera: Camera? = nil
local current: Model? = nil
local currentId: string? = nil
local colorKey = ""
local token = 0
local center = Vector3.zero
local half = Vector3.one -- demi-dimensions de la boîte du véhicule (studs)
local angle = GarageView.DefaultAngle
local zoom = 1
local auto = true -- rotation lente (coupée par une vue choisie ou une rotation à la main)
local dragging = false
local dragPixels = 0
local stepConnection: RBXScriptConnection? = nil
local listeners: { () -> () } = {}
-- Demandes au serveur une par une, espacées du délai minimal (vignettes de la collection chargées en série).
local requestBusy = false
local lastRequestAt = -math.huge
local lastNotified = -1

local function rgb(values: { number }): Color3
    return Color3.fromRGB(values[1], values[2], values[3])
end

local function notify()
    for _, fn in listeners do
        task.spawn(fn)
    end
end

-- Distance de cadrage, recalculée seulement au chargement d'un modèle et au redimensionnement de la zone
-- (576 coins examinés : jamais par image).
local distance = 10

local function fit(view: ViewportFrame, halfSize: Vector3): number
    local size = view.AbsoluteSize
    local aspect = if size.Y > 0 then size.X / size.Y else 1
    return PreviewFraming.fitDistance(
        halfSize.X,
        halfSize.Y,
        halfSize.Z,
        PreviewFraming.Fov,
        aspect,
        PreviewFraming.Pitch
    )
end

local function refit()
    if viewport then
        distance = fit(viewport, half)
    end
end

-- Repère de la caméra : orbite autour du centre, angle 0 = devant le véhicule (avant vers -Z), plongée fixe.
local function orbit(target: Vector3, degrees: number, away: number): CFrame
    return CFrame.new(target)
        * CFrame.Angles(0, math.rad(degrees + 180), 0)
        * CFrame.Angles(math.rad(-PreviewFraming.Pitch), 0, 0)
        * CFrame.new(0, 0, away)
end

local function placeCamera()
    local cam = camera
    if viewport == nil or cam == nil or current == nil then
        return
    end
    cam.CFrame = orbit(center, angle, distance / zoom)
    local rounded = math.floor(angle + 0.5) % 360
    if rounded ~= lastNotified then
        lastNotified = rounded
        notify()
    end
end

local function paint(model: Model, modelId: string, cosmetics: any)
    local definition = VehicleDefinitions.get(modelId)
    if definition == nil then
        return
    end
    local appearance = if type(cosmetics) == "table"
        then CosmeticCatalog.appearance(definition.Appearance, cosmetics)
        else definition.Appearance
    local colors = { Body = rgb(appearance.BodyRgb), Accent = rgb(appearance.AccentRgb) }
    for _, item in model:GetDescendants() do
        if item:IsA("BasePart") then
            local role = item:GetAttribute("AWPaintRole")
            local color = if type(role) == "string" then (colors :: any)[role] else nil
            if color then
                local surface = item:FindFirstChildOfClass("SurfaceAppearance")
                if surface then
                    surface.Color = color
                else
                    item.Color = color
                end
            end
        end
    end
end

local function keyOf(cosmetics: any): string
    if type(cosmetics) ~= "table" then
        return ""
    end
    return tostring(cosmetics.BodyColor) .. "/" .. tostring(cosmetics.AccentColor)
end

-- Copie inerte d'un modèle (demande au serveur au besoin) ; nil si refusée ou introuvable. Peut céder la main.
local function fetch(modelId: string, still: () -> boolean): Model?
    local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 10)
    if folder == nil then
        return nil
    end
    local request = folder:FindFirstChild("Request") :: RemoteFunction?
    local models = folder:FindFirstChild("Modeles")
    if request == nil or models == nil then
        return nil
    end
    local ready = models:FindFirstChild(modelId)
    if ready and ready:IsA("Model") then
        return ready
    end
    local name: string? = nil
    for _ = 1, RETRIES do
        while requestBusy or os.clock() - lastRequestAt < PreviewFraming.RequestInterval + 0.02 do
            task.wait(0.05)
        end
        if not still() then
            return nil
        end
        local already = models:FindFirstChild(modelId)
        if already and already:IsA("Model") then
            return already
        end
        requestBusy = true
        lastRequestAt = os.clock()
        local ok, result = pcall(function()
            return request:InvokeServer(modelId)
        end)
        requestBusy = false
        if not still() then
            return nil
        end
        if ok and type(result) == "string" then
            name = result
            break
        end
        task.wait(PreviewFraming.RequestInterval)
    end
    if name == nil then
        return nil
    end
    local source = models:WaitForChild(name, 10)
    if source == nil or not source:IsA("Model") or not still() then
        return nil
    end
    return source
end

local function clearModel()
    if current then
        current:Destroy()
    end
    current = nil
    if viewport then
        viewport:SetAttribute("AWPreviewModel", nil)
        viewport:SetAttribute("AWPreviewParts", nil)
    end
end

local function load(modelId: string, cosmetics: any, ticket: number)
    local source = fetch(modelId, function()
        return ticket == token
    end)
    if source == nil or viewport == nil then
        -- Refus ou panne : rien n'est mémorisé, une prochaine demande du même modèle réessaiera.
        if ticket == token then
            currentId = nil
        end
        return
    end
    clearModel()
    local copy = source:Clone()
    paint(copy, modelId, cosmetics)
    local box, size = copy:GetBoundingBox()
    center = box.Position
    half = size / 2
    copy.Parent = viewport
    current = copy
    local parts = 0
    for _, item in copy:GetDescendants() do
        if item:IsA("BasePart") then
            parts += 1
        end
    end
    local view = viewport :: ViewportFrame
    view:SetAttribute("AWPreviewModel", modelId)
    view:SetAttribute("AWPreviewParts", parts)
    refit()
    placeCamera()
end

local function lighting(view: ViewportFrame)
    -- Éclairage du ViewportFrame : lumière principale chaude venant de l'avant-haut, ambiance neutre assez forte
    -- pour lire les flancs à l'ombre (le ViewportFrame n'a ni ciel ni reflets).
    view.Ambient = Color3.fromRGB(150, 152, 158)
    view.LightColor = Color3.fromRGB(255, 248, 236)
    view.LightDirection = Vector3.new(-0.6, -1, -0.8)
end

-- Crée le ViewportFrame dans la zone 3D (sous les textes et commandes de la zone).
function VehiclePreview.attach(parent: GuiObject): ViewportFrame
    local view = Instance.new("ViewportFrame")
    view.Name = "Apercu3D"
    view.Size = UDim2.fromScale(1, 1)
    view.BackgroundTransparency = 1
    view.ZIndex = 2 -- au-dessus du dégradé de la zone, sous les textes et boutons (3 et plus)
    lighting(view)
    local cam = Instance.new("Camera")
    cam.FieldOfView = PreviewFraming.Fov
    cam.Parent = view
    view.CurrentCamera = cam
    view.Parent = parent
    viewport = view
    camera = cam
    view:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        refit()
        placeCamera()
    end)
    view.InputBegan:Connect(function(input: InputObject)
        if
            input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            dragging = true
        end
    end)
    -- Molette au-dessus de la zone : zoom (vers le haut = plus près).
    view.InputChanged:Connect(function(input: InputObject)
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            VehiclePreview.setZoom(zoom + 0.1 * input.Position.Z)
        end
    end)
    UserInputService.InputChanged:Connect(function(input: InputObject)
        if
            dragging
            and (
                input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch
            )
        then
            dragPixels += input.Delta.X
            if math.abs(input.Delta.X) > 0 then
                auto = false
            end
        end
    end)
    UserInputService.InputEnded:Connect(function(input: InputObject)
        if
            input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            dragging = false
        end
    end)
    return view
end

-- Affiche un modèle (nil : zone vide). Même modèle : seule la teinte change, sans nouvelle demande.
function VehiclePreview.show(modelId: string?, cosmetics: any)
    if modelId == nil then
        token += 1
        currentId = nil
        clearModel()
        return
    end
    local key = keyOf(cosmetics)
    if modelId == currentId then
        if key ~= colorKey and current then
            paint(current, modelId, cosmetics)
        end
        colorKey = key
        return
    end
    currentId = modelId
    colorKey = key
    token += 1
    local ticket = token
    task.spawn(load, modelId, cosmetics, ticket)
end

-- Vue choisie (degrés, 0 = avant) : arrête la rotation lente.
function VehiclePreview.setView(degrees: number)
    angle = degrees % 360
    auto = false
    placeCamera()
end

-- Rotation à la main (boutons, flèches) : arrête la rotation lente.
function VehiclePreview.rotate(delta: number)
    VehiclePreview.setView(angle + delta)
end

function VehiclePreview.setZoom(value: number)
    zoom = math.clamp(math.floor(value * 10 + 0.5) / 10, GarageView.ZoomMin, GarageView.ZoomMax)
    placeCamera()
    notify()
end

-- « Réinitialiser » : vue 3/4, zoom 1, rotation lente.
function VehiclePreview.reset()
    angle = GarageView.DefaultAngle
    zoom = 1
    auto = true
    placeCamera()
    notify()
end

-- Rotation active seulement garage ouvert (aucun calcul par image sinon).
function VehiclePreview.setActive(on: boolean)
    if on and stepConnection == nil then
        stepConnection = RunService.RenderStepped:Connect(function(dt: number)
            if current == nil then
                return
            end
            local stickX = 0
            if UserInputService:GetGamepadConnected(Enum.UserInputType.Gamepad1) then
                for _, state in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
                    if state.KeyCode == Enum.KeyCode.Thumbstick2 then
                        stickX = state.Position.X
                    end
                end
            end
            if math.abs(stickX) > PreviewFraming.StickDeadZone then
                auto = false
            end
            local spinning = auto and not dragging and not UIState.prefs().Access.ReduceMotion
            angle = PreviewFraming.step(angle, dt, spinning, dragPixels, stickX)
            dragPixels = 0
            placeCamera()
        end)
    elseif not on and stepConnection then
        stepConnection:Disconnect()
        stepConnection = nil
        dragging = false
    end
end

-- Appelé quand l'angle (au degré près) ou le zoom change : libellé de la caméra.
function VehiclePreview.onChange(fn: () -> ())
    table.insert(listeners, fn)
end

-- Lus par l'interface et les essais.
function VehiclePreview.angle(): number
    return angle
end

function VehiclePreview.zoom(): number
    return zoom
end

function VehiclePreview.spinning(): boolean
    return auto
end

-- Vignette fixe d'une carte de la collection (16:9, vue 3/4) : aucune rotation, aucun calcul par image.
function VehiclePreview.thumbnail(parent: GuiObject, modelId: string, cosmetics: any): ViewportFrame
    local view = Instance.new("ViewportFrame")
    view.Name = "Vignette3D"
    view.Size = UDim2.fromScale(1, 1)
    view.BackgroundTransparency = 1
    view.ZIndex = parent.ZIndex + 1
    lighting(view)
    local cam = Instance.new("Camera")
    cam.FieldOfView = PreviewFraming.Fov
    cam.Parent = view
    view.CurrentCamera = cam
    view.Parent = parent
    task.spawn(function()
        local source = fetch(modelId, function()
            return view.Parent ~= nil
        end)
        if source == nil or view.Parent == nil then
            return
        end
        local copy = source:Clone()
        paint(copy, modelId, cosmetics)
        local box, size = copy:GetBoundingBox()
        copy.Parent = view
        local function frame()
            cam.CFrame = orbit(box.Position, GarageView.DefaultAngle, fit(view, size / 2))
        end
        frame()
        view:GetPropertyChangedSignal("AbsoluteSize"):Connect(frame)
        view:SetAttribute("AWThumbModel", modelId)
    end)
    return view
end

return table.freeze(VehiclePreview)
