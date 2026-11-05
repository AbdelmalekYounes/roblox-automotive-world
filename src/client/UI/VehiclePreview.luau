--!strict
--[[
    Aperçu 3D du véhicule dans la zone gauche du garage (lot UI-03 ; ViewportFrame choisi par le propriétaire le
    2026-11-05, maquette « Garage » §4).

    - La copie visuelle vient du serveur (VehiclePreviewService : une copie inerte par modèle, dans
      ReplicatedStorage) ; elle est clonée dans le ViewportFrame, jamais dans le monde.
    - Teinte : celle de l'exemplaire, ou le brouillon de l'onglet Préparation, appliquée aux pièces marquées
      AWPaintRole par le serveur (aucune autre pièce n'est modifiée).
    - Caméra : cadrage automatique (PreviewFraming), rotation lente, glisser à la souris ou au doigt, stick droit de la
      manette ; rotation automatique coupée par « réduire les animations ».
    Limite connue du ViewportFrame : éclairage simplifié (une lumière, pas d'ombres, pas de reflets du décor).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PreviewFraming = require(Shared:WaitForChild("UI"):WaitForChild("PreviewFraming"))
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
local radius = 1
local angle = 210 -- trois quarts avant gauche à l'ouverture (degrés)
local dragging = false
local dragPixels = 0
local stepConnection: RBXScriptConnection? = nil

local function rgb(values: { number }): Color3
    return Color3.fromRGB(values[1], values[2], values[3])
end

local function placeCamera()
    local view = viewport
    local cam = camera
    if view == nil or cam == nil or current == nil then
        return
    end
    local size = view.AbsoluteSize
    local aspect = if size.Y > 0 then size.X / size.Y else 1
    local distance = PreviewFraming.distance(radius, PreviewFraming.Fov, aspect)
    cam.CFrame = CFrame.new(center)
        * CFrame.Angles(0, math.rad(angle), 0)
        * CFrame.Angles(math.rad(-PreviewFraming.Pitch), 0, 0)
        * CFrame.new(0, 0, distance)
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
    local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 10)
    if folder == nil then
        return
    end
    local request = folder:FindFirstChild("Request") :: RemoteFunction?
    local models = folder:FindFirstChild("Modeles")
    if request == nil or models == nil then
        return
    end
    local name: string? = nil
    for _ = 1, RETRIES do
        local ok, result = pcall(function()
            return request:InvokeServer(modelId)
        end)
        if ticket ~= token then
            return
        end
        if ok and type(result) == "string" then
            name = result
            break
        end
        task.wait(PreviewFraming.RequestInterval)
    end
    if name == nil then
        -- Refus ou panne : rien n'est mémorisé, une prochaine demande du même modèle réessaiera.
        if ticket == token then
            currentId = nil
        end
        return
    end
    local source = models:WaitForChild(name, 10)
    if ticket ~= token or source == nil or not source:IsA("Model") or viewport == nil then
        return
    end
    clearModel()
    local copy = source:Clone()
    paint(copy, modelId, cosmetics)
    local box, size = copy:GetBoundingBox()
    center = box.Position
    radius = size.Magnitude / 2
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
    placeCamera()
end

-- Crée le ViewportFrame dans la zone 3D (sous les textes de la zone).
function VehiclePreview.attach(parent: GuiObject): ViewportFrame
    local view = Instance.new("ViewportFrame")
    view.Name = "Apercu3D"
    view.Size = UDim2.fromScale(1, 1)
    view.BackgroundTransparency = 1
    view.ZIndex = 2 -- au-dessus du dégradé de la zone, sous le nom du véhicule (3)
    -- Éclairage du ViewportFrame : lumière principale chaude venant de l'avant-haut, ambiance neutre assez forte
    -- pour lire les flancs à l'ombre (le ViewportFrame n'a ni ciel ni reflets).
    view.Ambient = Color3.fromRGB(150, 152, 158)
    view.LightColor = Color3.fromRGB(255, 248, 236)
    view.LightDirection = Vector3.new(-0.6, -1, -0.8)
    local cam = Instance.new("Camera")
    cam.FieldOfView = PreviewFraming.Fov
    cam.Parent = view
    view.CurrentCamera = cam
    view.Parent = parent
    viewport = view
    camera = cam
    view:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeCamera)
    view.InputBegan:Connect(function(input: InputObject)
        if
            input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            dragging = true
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
            local auto = not dragging and not UIState.prefs().Access.ReduceMotion
            angle = PreviewFraming.step(angle, dt, auto, dragPixels, stickX)
            dragPixels = 0
            placeCamera()
        end)
    elseif not on and stepConnection then
        stepConnection:Disconnect()
        stepConnection = nil
        dragging = false
    end
end

-- Lu par les essais : angle courant (degrés).
function VehiclePreview.angle(): number
    return angle
end

return table.freeze(VehiclePreview)
