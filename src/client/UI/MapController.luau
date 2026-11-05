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
local Components = require(script.Parent.Components)
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
local destinationTitle: TextLabel
local destinationInfo: TextLabel
local clearButton: TextButton
local scaleLabel: TextLabel
local scaleBar: Frame
local filterButtons: { [string]: TextButton } = {}
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
    local size = Components.logicalSize(canvas)
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
    destinationTitle.Text = status
    local progress = gps.Progress
    destinationInfo.Text = if progress
        then Localization.t("gps.remaining", {
            distance = Localization.distance(progress.RemainingM),
            minutes = math.max(1, math.ceil(progress.RemainingS / 60)),
        })
        else ""
    clearButton.Visible = gps.Destination ~= nil
    -- Échelle : barre de 60 px et distance correspondante.
    scaleBar.Size = UDim2.fromOffset(60, 3)
    scaleLabel.Text = Localization.distance(spanM / math.max(size.X, 1) * 60)
end

-- Catégories filtrables (panneau latéral) : identifiants des repères du répertoire.
local FILTERS = { "PublicGarage", "Dealership", "FuelStation", "ChargingHub", "CarWash", "RaceStart", "Property" }
local LEGEND = {
    "PublicGarage",
    "Dealership",
    "FuelStation",
    "ChargingHub",
    "CarWash",
    "RaceStart",
    "Property",
    "Destination",
}

local function corner(item: Instance, radius: number)
    UITheme.make("UICorner", { CornerRadius = UDim.new(0, radius) }, item)
end

local function stroke(item: Instance, color: Color3?, thickness: number?)
    UITheme.make("UIStroke", { Color = color or Tokens.color("Line"), Thickness = thickness or 1 }, item)
end

-- Bouton V1.2 (secondaire ou principal).
local function action(parent: Instance, text: string, primary: boolean, fn: () -> (), name: string?): TextButton
    local item = UITheme.button(text, {
        Name = name or text,
        Size = UDim2.fromOffset(0, Tokens.PrimaryButtonHeight),
        AutomaticSize = Enum.AutomaticSize.X,
    }, parent, fn)
    UITheme.make("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, item)
    if primary then
        item.BackgroundColor3 = Tokens.color("Amber")
        item.TextColor3 = Tokens.color("TextOnAmber")
        item.FontFace = Font.new(UITheme.face("Button").Family, Enum.FontWeight.Bold)
        local edge = item:FindFirstChildOfClass("UIStroke")
        if edge then
            edge.Color = Tokens.color("Amber")
        end
    end
    return item
end

-- Bouton rond posé sur la carte (zoom, recentrage).
local function roundButton(parent: Instance, text: string, fn: () -> (), name: string): TextButton
    local item = UITheme.button(text, { Name = name, Size = UDim2.fromOffset(44, 44) }, parent, fn)
    item.BackgroundColor3 = Tokens.color("BgBase")
    item.TextSize = UITheme.text(20)
    item.FontFace = Font.new(UITheme.face("Button").Family, Enum.FontWeight.Bold)
    local round = item:FindFirstChildOfClass("UICorner")
    if round then
        round.CornerRadius = UDim.new(1, 0)
    end
    return item
end

local function paintFilters()
    for kind, item in filterButtons do
        local on = not hidden[kind]
        item.BackgroundColor3 = if on then Tokens.color("AmberSoft") else Tokens.color("Surface2")
        item.TextColor3 = if on then Tokens.color("AmberSoftText") else Tokens.color("TextMuted")
        local edge = item:FindFirstChildOfClass("UIStroke")
        if edge then
            edge.Color = if on then Tokens.color("Amber") else Tokens.color("Line")
        end
        item:SetAttribute("AWSelected", on)
    end
end

local function build()
    gui = UITheme.make(
        "ScreenGui",
        { Name = "AWMap", ResetOnSpawn = false, DisplayOrder = 10, Enabled = false },
        Players.LocalPlayer:WaitForChild("PlayerGui")
    )
    -- Grande fenêtre V1.2 (proposition, pas de maquette dédiée) : barre haute, carte des instruments à gauche,
    -- panneau latéral à droite, barre d'aide. Pas en plein écran : la carte reste consultable en roulant.
    local frame = UITheme.make("Frame", {
        Name = "Fenetre",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.94, 0.9),
        BackgroundTransparency = 1,
    }, gui)
    window = Components.logicalRoot(frame)
    window.BackgroundColor3 = Tokens.color("BgBase")
    window.BackgroundTransparency = 0
    corner(window, Tokens.Radius.Card)
    stroke(window)
    -- Barre haute.
    local top = UITheme.make("Frame", {
        Name = "BarreHaute",
        Size = UDim2.new(1, 0, 0, 56),
        BackgroundColor3 = Tokens.color("BgChrome"),
        BorderSizePixel = 0,
    }, window)
    corner(top, Tokens.Radius.Card)
    UITheme.make("Frame", {
        BackgroundColor3 = Tokens.color("Line"),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 55),
        Size = UDim2.new(1, 0, 0, 1),
    }, window)
    titleLabel = UITheme.label("", 22, {
        Name = "Titre",
        Position = UDim2.fromOffset(20, 12),
        Size = UDim2.fromOffset(120, 32),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, top)
    titleLabel.FontFace = UITheme.face("H1")
    statusLabel = UITheme.label("", 14, {
        Name = "Destination",
        Position = UDim2.fromOffset(140, 16),
        Size = UDim2.new(1, -420, 0, 24),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextColor3 = Tokens.color("GpsCyan"),
    }, top)
    local profile = action(top, Localization.t("gps.profile.AllTerrain"), false, function()
        local current = GPSController.state().Profile
        GPSController.setProfile(if current == "Road" then "AllTerrain" else "Road")
    end, "gps.profile.AllTerrain")
    profile.AnchorPoint = Vector2.new(1, 0.5)
    profile.Position = UDim2.new(1, -16, 0.5, 0)
    profile.Size = UDim2.fromOffset(0, 36)

    -- Carte (zone des instruments) avec ses commandes posées dessus.
    local SIDE = 380
    canvas = UITheme.make("Frame", {
        Name = "Carte",
        Position = UDim2.fromOffset(16, 72),
        Size = UDim2.new(1, -(SIDE + 48), 1, -(72 + 56)),
        BackgroundColor3 = Color3.fromRGB(15, 18, 20),
        BorderSizePixel = 0,
        Active = true,
        ClipsDescendants = true,
    }, window)
    corner(canvas, Tokens.Radius.Card)
    stroke(canvas, Color3.fromRGB(42, 74, 80), 2)
    renderer = MapRenderer.new(canvas, 1800, function(marker)
        setDestination(marker)
    end)
    -- Réticule central (« Définir ici ») : deux traits fins dessinés.
    for _, horizontal in { true, false } do
        UITheme.make("Frame", {
            Name = "Reticule",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = if horizontal then UDim2.fromOffset(22, 2) else UDim2.fromOffset(2, 22),
            BackgroundColor3 = Tokens.color("Text"),
            BackgroundTransparency = 0.35,
            BorderSizePixel = 0,
            ZIndex = 8,
        }, canvas)
    end
    -- Zoom et recentrage (en haut à droite de la carte).
    local controls = UITheme.make("Frame", {
        Name = "Commandes",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 12),
        Size = UDim2.fromOffset(44, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex = 9,
    }, canvas)
    UITheme.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, controls)
    roundButton(controls, "+", function()
        spanM = math.max(300, spanM / 1.6)
    end, "map.zoomIn").LayoutOrder =
        1
    roundButton(controls, "-", function()
        spanM = math.min(14000, spanM * 1.6)
    end, "map.zoomOut").LayoutOrder =
        2
    local recenter = roundButton(controls, "", function()
        local x, z = playerPosition()
        center = { X = x, Z = z }
    end, "map.center")
    recenter.LayoutOrder = 3
    -- Pictogramme de recentrage dessiné : anneau et point.
    local ring = UITheme.make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(16, 16),
        BackgroundTransparency = 1,
        ZIndex = 10,
    }, recenter)
    corner(ring, 8)
    stroke(ring, Tokens.color("Text"), 2)
    local dot = UITheme.make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(6, 6),
        BackgroundColor3 = Tokens.color("Text"),
        BorderSizePixel = 0,
        ZIndex = 10,
    }, recenter)
    corner(dot, 3)
    -- Échelle (en bas à droite de la carte).
    local scale = UITheme.make("Frame", {
        Name = "Echelle",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -12, 1, -12),
        Size = UDim2.fromOffset(120, 30),
        BackgroundColor3 = Tokens.color("BgBase"),
        BackgroundTransparency = 0.15,
        ZIndex = 9,
    }, canvas)
    corner(scale, 4)
    scaleBar = UITheme.make("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 10, 1, -7),
        Size = UDim2.fromOffset(60, 3),
        BackgroundColor3 = Tokens.color("Text"),
        BorderSizePixel = 0,
        ZIndex = 10,
    }, scale)
    scaleLabel = UITheme.label("", 11, {
        Position = UDim2.fromOffset(10, 2),
        Size = UDim2.new(1, -20, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Tokens.color("TextMuted"),
        ZIndex = 10,
    }, scale)
    scaleLabel.FontFace = UITheme.face("Value")
    -- Légende (en bas à gauche de la carte) : repères dessinés et leur nom.
    local legend = UITheme.make("Frame", {
        Name = "Legende",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 12, 1, -12),
        Size = UDim2.fromOffset(200, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Tokens.color("BgBase"),
        BackgroundTransparency = 0.12,
        ZIndex = 9,
    }, canvas)
    corner(legend, Tokens.Radius.Card)
    stroke(legend)
    UITheme.make("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        PaddingTop = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 8),
    }, legend)
    UITheme.make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, legend)
    for index, kind in LEGEND do
        local row = UITheme.make("Frame", {
            Name = "Ligne_" .. kind,
            Size = UDim2.new(1, 0, 0, 20),
            BackgroundTransparency = 1,
            LayoutOrder = index,
            ZIndex = 10,
        }, legend)
        local sample = MapRenderer.sample(row, kind)
        sample.ZIndex = 10
        UITheme.label(Localization.t("poi." .. kind), 12, {
            Position = UDim2.fromOffset(28, 0),
            Size = UDim2.new(1, -28, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextColor3 = Tokens.color("TextMuted"),
            ZIndex = 10,
        }, row)
    end

    -- Panneau latéral : destination, filtres, lieux proches.
    local side = UITheme.make("Frame", {
        Name = "PanneauLateral",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -16, 0, 72),
        Size = UDim2.new(0, SIDE, 1, -(72 + 56)),
        BackgroundTransparency = 1,
    }, window)
    UITheme.make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, side)
    local destination = UITheme.make("Frame", {
        Name = "CarteDestination",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Tokens.color("Surface1"),
        BorderSizePixel = 0,
        LayoutOrder = 1,
        ClipsDescendants = true,
    }, side)
    corner(destination, Tokens.Radius.Card)
    stroke(destination)
    UITheme.make("Frame", {
        Name = "Filet",
        BackgroundColor3 = Tokens.color("GpsCyan"),
        BorderSizePixel = 0,
        Size = UDim2.new(0, Tokens.StatusRail, 1, 0),
    }, destination)
    local destinationBody = UITheme.make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, destination)
    UITheme.make("UIPadding", {
        PaddingLeft = UDim.new(0, 16),
        PaddingRight = UDim.new(0, 14),
        PaddingTop = UDim.new(0, 12),
        PaddingBottom = UDim.new(0, 12),
    }, destinationBody)
    UITheme.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, destinationBody)
    local destinationHead = UITheme.label(Tokens.upper(Localization.t("phone.h.route")), 12, {
        Size = UDim2.new(1, 0, 0, 16),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Tokens.color("TextMuted"),
        LayoutOrder = 1,
    }, destinationBody)
    destinationHead.FontFace = UITheme.face("Label")
    destinationTitle = UITheme.label("", 17, {
        Name = "Titre",
        Size = UDim2.new(1, 0, 0, 22),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 2,
    }, destinationBody)
    destinationTitle.FontFace = UITheme.face("Button")
    destinationInfo = UITheme.label("", 13, {
        Name = "Reste",
        Size = UDim2.new(1, 0, 0, 18),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Tokens.color("TextMuted"),
        LayoutOrder = 3,
    }, destinationBody)
    destinationInfo.FontFace = UITheme.face("Value")
    local destinationActions = UITheme.make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 4,
    }, destinationBody)
    local actionsLayout = UITheme.make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, destinationActions);
    (actionsLayout :: any).Wraps = true
    local setHere = action(destinationActions, Localization.t("gps.setDestination"), true, function()
        GPSController.setDestination(center.X, center.Z, Localization.t("poi.Destination"), "Player")
    end, "gps.setDestination")
    setHere.LayoutOrder = 1
    clearButton = action(destinationActions, Localization.t("gps.clear"), false, function()
        GPSController.clear()
    end, "gps.clear")
    clearButton.LayoutOrder = 2
    clearButton.TextColor3 = Tokens.color("DangerText")
    -- Filtres par catégorie (puces).
    local filterHead = UITheme.label(Tokens.upper(Localization.t("map.filters")), 12, {
        Size = UDim2.new(1, 0, 0, 16),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Tokens.color("TextMuted"),
        LayoutOrder = 2,
    }, side)
    filterHead.FontFace = UITheme.face("Label")
    local filters = UITheme.make("Frame", {
        Name = "Filtres",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 3,
    }, side)
    local filterLayout = UITheme.make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, filters);
    (filterLayout :: any).Wraps = true
    for index, kind in FILTERS do
        local chip = UITheme.button(
            Localization.t("poi." .. kind),
            {
                Name = "Filtre_" .. kind,
                Size = UDim2.fromOffset(0, 32),
                AutomaticSize = Enum.AutomaticSize.X,
                LayoutOrder = index,
            },
            filters,
            function()
                hidden[kind] = not hidden[kind]
                paintFilters()
                rebuildList()
            end
        )
        chip.TextSize = UITheme.text(13)
        UITheme.make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, chip)
        filterButtons[kind] = chip
    end
    paintFilters()
    local listHead = UITheme.label(Tokens.upper(Localization.t("map.search")), 12, {
        Size = UDim2.new(1, 0, 0, 16),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Tokens.color("TextMuted"),
        LayoutOrder = 4,
    }, side)
    listHead.FontFace = UITheme.face("Label")
    listFrame = UITheme.make("ScrollingFrame", {
        Name = "Lieux",
        Size = UDim2.new(1, 0, 1, -330),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Tokens.color("Line"),
        LayoutOrder = 5,
    }, side)
    UITheme.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, listFrame)
    -- La liste prend la hauteur restante du panneau.
    local function fitList()
        local used = 0
        for _, child in side:GetChildren() do
            if child:IsA("GuiObject") and child ~= listFrame then
                used += Components.logicalSize(child).Y + 10
            end
        end
        listFrame.Size = UDim2.new(1, 0, 1, -math.floor(used))
    end
    destination:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitList)
    filters:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitList)
    task.defer(fitList)

    -- Barre d'aide (touches, Fermer).
    local help = UITheme.make("Frame", {
        Name = "BarreAide",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = Tokens.color("BgChrome"),
        BorderSizePixel = 0,
    }, window)
    corner(help, Tokens.Radius.Card)
    local hints = UITheme.label(Localization.t("map.hints"), 13, {
        Position = UDim2.fromOffset(20, 0),
        Size = UDim2.new(1, -200, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Tokens.color("TextMuted"),
    }, help)
    hints.FontFace = UITheme.face("Body")
    local close = action(help, Localization.t("ui.close"), false, function()
        UIManager.close("Map")
    end, "ui.close")
    close.AnchorPoint = Vector2.new(1, 0.5)
    close.Position = UDim2.new(1, -12, 0.5, 0)
    close.Size = UDim2.fromOffset(0, 32)
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
            local metersPerPixel = spanM / math.max(canvas.AbsoluteSize.X, 1) -- pointeur en pixels d'écran
            center = { X = center.X - delta.X * metersPerPixel, Z = center.Z - delta.Y * metersPerPixel }
        end
    end)
    -- Manette : stick droit pour déplacer la vue (la carte capture la conduite).
    RunService.RenderStepped:Connect(function(dt)
        if not opened or not UserInputService:GetGamepadConnected(Enum.UserInputType.Gamepad1) then
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
