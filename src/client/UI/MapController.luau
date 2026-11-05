--!strict
--[[
    Carte complète interactive (lot 0.7) et annuaire des points d'intérêt.

    - Annuaire : reçu du serveur (InterfaceService.Directory), issu des
      registres existants ; actualisé toutes les 30 s (propriétés, mission).
    - Carte : routes simplifiées selon le zoom, itinéraire, points d'intérêt
      (filtrables), membres qui partagent, joueur ; déplacement à la souris
      (glisser, molette) ou aux boutons ; liste des lieux navigable à la
      manette ; « Définir ici » prend le centre de la vue comme destination.
    - Interface complète (consultation du GPS autorisée en roulant : la carte
      a un mode rapide sans saisie, aucune action sensible).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared:WaitForChild("UI"):WaitForChild("Localization"))
local MapProjection = require(Shared:WaitForChild("Navigation"):WaitForChild("MapProjection"))
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))

local UITheme = require(script.Parent.UITheme)
local Tokens = require(Shared:WaitForChild("UI"):WaitForChild("DesignTokens"))
local UIManager = require(script.Parent.UIManager)
local GPSController = require(script.Parent.GPSController)
local MapRenderer = require(script.Parent.MapRenderer)
local SocialController = require(script.Parent.SocialController)
local SettingsController = require(script.Parent.SettingsController)

local MapController = {}

local S = 1 / Constants.MetersPerStud

local points: { any } = {}
local hidden: { [string]: boolean } = { PropertyOffer = true, PlayerSpawn = true }
local gui: ScreenGui
local window: Frame
local canvas: Frame
local listFrame: ScrollingFrame
local titleLabel: TextLabel
local statusLabel: TextLabel
local renderer: MapRenderer.Renderer
local center = { X = 0, Z = 0 }
local spanM = 3000
local opened = false
local dragging: Vector3? = nil

function MapController.points(): { any }
    return points
end

-- Marqueurs visibles (mini-carte et carte), selon les filtres.
function MapController.markers(): { MapRenderer.Marker }
    local list: { MapRenderer.Marker } = {}
    for _, point in points do
        if not hidden[point.Kind] then
            table.insert(list, { X = point.X, Z = point.Z, Kind = point.Kind, Name = point.Name, Id = point.Id })
        end
    end
    return list
end

function MapController.refresh()
    local response = SettingsController.request("Directory")
    if response.Status == "Ok" and type(response.Result) == "table" then
        points = response.Result
    end
end

local function playerPosition(): (number, number, number)
    local character = Players.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        local look = root.CFrame.LookVector
        return root.Position.X / S, root.Position.Z / S, math.atan2(look.X, -look.Z)
    end
    return 0, 0, 0
end

local function setDestination(point: any)
    GPSController.setDestination(point.X, point.Z, point.Name or Localization.t("poi." .. point.Kind), "Poi")
end

local function rebuildList()
    for _, child in listFrame:GetChildren() do
        if child:IsA("GuiButton") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    local x, z = playerPosition()
    local sorted = MapController.markers()
    table.sort(sorted, function(a, b)
        return (a.X - x) ^ 2 + (a.Z - z) ^ 2 < (b.X - x) ^ 2 + (b.Z - z) ^ 2
    end)
    for index, marker in sorted do
        if index > 40 then
            break
        end
        local distance = math.sqrt((marker.X - x) ^ 2 + (marker.Z - z) ^ 2)
        local item = UITheme.button(
            "",
            {
                Name = "Lieu",
                Size = UDim2.new(1, -8, 0, 52),
                LayoutOrder = index,
            },
            listFrame,
            function()
                center = { X = marker.X, Z = marker.Z }
                setDestination(marker)
            end
        )
        local nameLabel = UITheme.label(marker.Name or Localization.t("poi." .. marker.Kind), 14, {
            Name = "Nom",
            Position = UDim2.fromOffset(12, 7),
            Size = UDim2.new(1, -100, 0, 20),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, item)
        nameLabel.FontFace = UITheme.face("Button")
        UITheme.label(Localization.t("poi." .. marker.Kind), 12, {
            Name = "Categorie",
            Position = UDim2.fromOffset(12, 27),
            Size = UDim2.new(1, -100, 0, 18),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextColor3 = Tokens.color("TextMuted"),
        }, item)
        local value = UITheme.make("TextLabel", {
            Name = "Valeur",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.fromOffset(80, 20),
            BackgroundTransparency = 1,
            Text = Localization.distance(distance),
            TextXAlignment = Enum.TextXAlignment.Right,
            TextColor3 = Tokens.color("TextMuted"),
        }, item)
        value.FontFace = UITheme.face("Value")
        value.TextSize = UITheme.text(12)
    end
end

local function draw()
    if not opened then
        return
    end
    local px, pz, heading = playerPosition()
    local size = canvas.AbsoluteSize
    if size.X < 10 then
        return
    end
    local view = MapProjection.view(center.X, center.Z, size.X / spanM, 0, size.X, size.Y)
    local markers = MapController.markers()
    local gps = GPSController.state()
    if gps.Destination then
        table.insert(
            markers,
            { X = gps.Destination.X, Z = gps.Destination.Z, Kind = "Destination", Name = gps.Destination.Label }
        )
    end
    for _, member in SocialController.positions() do
        table.insert(markers, { X = member.X, Z = member.Z, Kind = "GroupMember", Name = member.Name })
    end
    renderer:draw({
        View = view,
        Index = GPSController.mapIndex(),
        Route = if gps.Plan then gps.Plan.Points else nil,
        Markers = markers,
        PlayerHeading = heading,
        PlayerX = px,
        PlayerZ = pz,
        ClampMarkers = false,
    })
    local status = if gps.Destination then gps.Destination.Label else Localization.t("gps.noDestination")
    titleLabel.Text = Tokens.upper(Localization.t("ui.panel.map"))
    statusLabel.Text = status
end

local function build()
    gui = UITheme.make(
        "ScreenGui",
        { Name = "AWMap", ResetOnSpawn = false, DisplayOrder = 10, Enabled = false },
        Players.LocalPlayer:WaitForChild("PlayerGui")
    )
    -- Système de conception V1.2 : fenêtre sombre à filet, barre de titre (titre en capitales, destination en
    -- cyan), fond de carte des instruments (#0F1214, liseré #2A4A50), liste des lieux à droite, barre d'outils.
    window = UITheme.panel({
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.86, 0.84),
    }, gui)
    window.BackgroundColor3 = Tokens.color("BgBase")
    UITheme.make("UIStroke", { Color = Tokens.color("Line"), Thickness = 1 }, window)
    titleLabel = UITheme.label("", 22, {
        Name = "Titre",
        Position = UDim2.fromOffset(20, 14),
        Size = UDim2.fromOffset(160, 28),
        Font = UITheme.FontBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, window)
    titleLabel.FontFace = UITheme.face("H1")
    statusLabel = UITheme.label("", 14, {
        Name = "Destination",
        Position = UDim2.fromOffset(180, 16),
        Size = UDim2.new(1, -200, 0, 24),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextColor3 = Tokens.color("GpsCyan"),
    }, window)
    UITheme.make("Frame", {
        Name = "Filet",
        BackgroundColor3 = Tokens.color("Line"),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 55),
        Size = UDim2.new(1, 0, 0, 1),
    }, window)
    canvas = UITheme.make("Frame", {
        Name = "Carte",
        Position = UDim2.fromOffset(16, 72),
        Size = UDim2.new(0.7, -24, 1, -140),
        BackgroundColor3 = Color3.fromRGB(15, 18, 20),
        BorderSizePixel = 0,
        Active = true,
    }, window)
    UITheme.make("UICorner", { CornerRadius = UDim.new(0, Tokens.Radius.Card) }, canvas)
    UITheme.make("UIStroke", { Color = Color3.fromRGB(42, 74, 80), Thickness = 2 }, canvas)
    renderer = MapRenderer.new(canvas, 1800, function(marker)
        setDestination(marker)
    end)
    -- Réticule central : « Définir ici ».
    UITheme.label("+", 22, {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(20, 20),
        ZIndex = 6,
    }, canvas)
    listFrame = UITheme.make("ScrollingFrame", {
        Name = "Lieux",
        Position = UDim2.new(0.7, 0, 0, 72),
        Size = UDim2.new(0.3, -16, 1, -140),
        BackgroundTransparency = 1,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 6,
    }, window)
    UITheme.make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, listFrame)
    local bar = UITheme.make("Frame", {
        Name = "Outils",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 16, 1, -12),
        Size = UDim2.new(1, -32, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, window)
    -- Carte et liste au-dessus de la barre d'outils, quelle que soit sa hauteur (une ou deux rangées).
    local function fitBody()
        local reserved = 72 + bar.AbsoluteSize.Y + 24
        canvas.Size = UDim2.new(0.7, -24, 1, -reserved)
        listFrame.Size = UDim2.new(0.3, -16, 1, -reserved)
    end
    bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBody)
    local barLayout = UITheme.make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        VerticalAlignment = Enum.VerticalAlignment.Center,
    }, bar);
    (barLayout :: any).Wraps = true
    local function button(key: string, _width: number, fn: () -> ())
        local item = UITheme.button(Localization.t(key), {
            Name = key,
            Size = UDim2.fromOffset(0, 36),
            AutomaticSize = Enum.AutomaticSize.X,
        }, bar, fn)
        UITheme.make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, item)
        -- « Définir ici » : action principale (ambre).
        if key == "gps.setDestination" then
            item.BackgroundColor3 = Tokens.color("Amber")
            item.TextColor3 = Tokens.color("TextOnAmber")
            local edge = item:FindFirstChildOfClass("UIStroke")
            if edge then
                edge.Color = Tokens.color("Amber")
            end
        end
    end
    button("map.zoomIn", 90, function()
        spanM = math.max(300, spanM / 1.6)
    end)
    button("map.zoomOut", 90, function()
        spanM = math.min(14000, spanM * 1.6)
    end)
    button("map.center", 110, function()
        local x, z = playerPosition()
        center = { X = x, Z = z }
    end)
    button("gps.setDestination", 200, function()
        GPSController.setDestination(center.X, center.Z, Localization.t("poi.Destination"), "Player")
    end)
    button("gps.clear", 170, function()
        GPSController.clear()
    end)
    button("gps.profile." .. "AllTerrain", 190, function()
        local current = GPSController.state().Profile
        GPSController.setProfile(if current == "Road" then "AllTerrain" else "Road")
    end)
    button("ui.close", 100, function()
        UIManager.close("Map")
    end)
    -- Glisser et molette sur la carte.
    canvas.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = input.Position
        end
    end)
    canvas.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = nil
        end
    end)
    canvas.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            spanM = math.clamp(spanM * (if input.Position.Z > 0 then 1 / 1.25 else 1.25), 300, 14000)
        elseif input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
            local delta = input.Position - (dragging :: Vector3)
            dragging = input.Position
            local metersPerPixel = spanM / math.max(canvas.AbsoluteSize.X, 1)
            center = { X = center.X - delta.X * metersPerPixel, Z = center.Z - delta.Y * metersPerPixel }
        end
    end)
    -- Manette : stick droit pour déplacer la vue (la carte capture la conduite).
    RunService.RenderStepped:Connect(function(dt)
        if not opened then
            return
        end
        for _, state in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
            if state.KeyCode == Enum.KeyCode.Thumbstick2 and state.Position.Magnitude > 0.2 then
                local speed = spanM * 0.6 * dt
                center = { X = center.X + state.Position.X * speed, Z = center.Z - state.Position.Y * speed }
            end
        end
    end)
end

function MapController.start()
    build()
    UIManager.register({
        Name = "Map",
        Kind = "Modal",
        Full = false,
        Open = function()
            local x, z = playerPosition()
            center = { X = x, Z = z }
            opened = true
            gui.Enabled = true
            rebuildList()
        end,
        Close = function()
            opened = false
            gui.Enabled = false
        end,
        Focus = function()
            return listFrame:FindFirstChildWhichIsA("GuiButton")
        end,
    })
    task.spawn(function()
        while true do
            MapController.refresh()
            task.wait(30)
        end
    end)
    local timer = 0
    RunService.Heartbeat:Connect(function(dt)
        timer += dt
        if timer >= 0.15 then
            timer = 0
            draw()
        end
    end)
end

-- Filtre d'une catégorie de lieux.
function MapController.setHidden(kind: string, hide: boolean)
    hidden[kind] = hide
end

return MapController
