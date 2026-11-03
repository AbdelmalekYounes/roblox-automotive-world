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
        UITheme.button(
            string.format(
                "%s %s — %s",
                MapRenderer.Icons[marker.Kind] or "•",
                marker.Name or "",
                Localization.distance(distance)
            ),
            { Size = UDim2.new(1, -8, 0, 30), LayoutOrder = index, TextXAlignment = Enum.TextXAlignment.Left },
            listFrame,
            function()
                center = { X = marker.X, Z = marker.Z }
                setDestination(marker)
            end
        )
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
    titleLabel.Text = Localization.t("ui.panel.map") .. " — " .. status
end

local function build()
    gui = UITheme.make(
        "ScreenGui",
        { Name = "AWMap", ResetOnSpawn = false, DisplayOrder = 10, Enabled = false },
        Players.LocalPlayer:WaitForChild("PlayerGui")
    )
    window = UITheme.panel({
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.82, 0.8),
    }, gui)
    titleLabel = UITheme.label("", 18, {
        Position = UDim2.fromOffset(14, 8),
        Size = UDim2.new(1, -28, 0, 26),
        Font = UITheme.FontBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, window)
    canvas = UITheme.make("Frame", {
        Position = UDim2.fromOffset(12, 44),
        Size = UDim2.new(0.7, -18, 1, -100),
        BackgroundColor3 = Color3.fromRGB(12, 14, 18),
        BorderSizePixel = 0,
        Active = true,
    }, window)
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
        Position = UDim2.new(0.7, 0, 0, 44),
        Size = UDim2.new(0.3, -12, 1, -100),
        BackgroundTransparency = 1,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 6,
    }, window)
    UITheme.make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, listFrame)
    local bar = UITheme.make(
        "Frame",
        { Position = UDim2.new(0, 12, 1, -48), Size = UDim2.new(1, -24, 0, 38), BackgroundTransparency = 1 },
        window
    )
    UITheme.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, bar)
    local function button(key: string, width: number, fn: () -> ())
        UITheme.button(Localization.t(key), { Size = UDim2.fromOffset(width, 34) }, bar, fn)
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
