--!strict
--[[
    Smartphone virtuel (lot 0.7, §7.2, AUD-UI-01). Touche T (manette : X).

    - Tenu physiquement : le serveur place un modèle provisoire original dans
      la main du personnage (écran générique vu des autres) ; l'interface des
      applications s'affiche chez le joueur, en taille normale ou agrandie.
    - Applications : accueil, carte, véhicules, propriétés, missions, courses,
      marché, social, paramètres, notifications. Elles LISENT les services
      existants (progression, économie, courses, groupes) et ouvrent leurs
      panneaux pour agir : aucune seconde logique d'achat, de vente ou de
      récompense ; chaque action sensible reste validée par son service
      (lieu, vitesse, propriété).
    - En roulant : mode rapide seulement (itinéraire, prochaine direction,
      réglages rapides, alertes en lecture), sans sélection manette ; l'écran
      complet revient à l'arrêt avec son contenu. Jamais de freinage ni de
      pause.
    - Lot PHONE-01 : affichage « en main » (réglage Auto / En main / Classique) :
      la caméra zoome sur le téléphone 3D tenu par le personnage et la même
      interface est dessinée exactement sur son écran (PhoneHoldController) ;
      « + » rapproche l'écran. Affichage classique (coin de l'écran) en repli :
      réglage, disposition compacte en Auto, modèle du serveur absent.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared:WaitForChild("UI"):WaitForChild("Localization"))
local InputMap = require(Shared.UI.InputMap)
local Attributions = require(Shared:WaitForChild("Assets"):WaitForChild("Attributions"))
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))

local UIState = require(script.Parent.UIState)
local UITheme = require(script.Parent.UITheme)
local Components = require(script.Parent.Components)
local Tokens = require(Shared:WaitForChild("UI"):WaitForChild("DesignTokens"))
local PhoneIcons = require(Shared:WaitForChild("UI"):WaitForChild("PhoneIcons"))
local GarageView = require(Shared:WaitForChild("UI"):WaitForChild("GarageView"))
local VehicleCatalog = require(Shared:WaitForChild("Economy"):WaitForChild("VehicleCatalog"))
local VehicleDefinitions = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleDefinitions"))
local UIManager = require(script.Parent.UIManager)
local GPSController = require(script.Parent.GPSController)
local NotificationService = require(script.Parent.NotificationService)
local SocialController = require(script.Parent.SocialController)
local SettingsController = require(script.Parent.SettingsController)
local MapController = require(script.Parent.MapController)
local OnboardingController = require(script.Parent.OnboardingController)
local PhotoMode = require(script.Parent.PhotoMode)
local BodyChoice = require(script.Parent.BodyChoice)
local RadioController = require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("RadioController"))
-- Lot PHONE-01 : téléphone tenu en main (bras, zoom, rectangle de l'écran 3D).
local PhoneHold = require(Shared:WaitForChild("UI"):WaitForChild("PhoneHold"))
local Preferences = require(Shared:WaitForChild("UI"):WaitForChild("Preferences"))
local PhoneHoldController = require(script.Parent.PhoneHoldController)

local PhoneController = {}

local APPS = {
    "Map",
    "Vehicles",
    "Properties",
    "Missions",
    "Races",
    "Market",
    "Social",
    "Radio",
    "Photo",
    "Guide",
    "Settings",
    "Notifications",
}
local gui: ScreenGui
local device: Frame
local header: TextLabel
local body: ScrollingFrame
local quickBar: Frame
local dock: Frame
local backButton: TextButton
local quickTag: TextLabel
local clockLabel: TextLabel
local app = "Home"
local enlarged = false
local quick = false
local order = 0
local cache: { [string]: any } = {}
local settingsPage = "Interface"
local rebinding: string? = nil
local isOpen = false
-- Lot PHONE-01 : affichage de l'ouverture en cours (en main = interface sur l'écran du téléphone 3D).
local handMode = false
local handParts: { GuiObject } = {} -- coque, bord et touches dessinés (masqués en main : le modèle 3D les montre)
local screenFrame: Frame
local screenCorner: UICorner
local openCount = 0

local function remote(folder: string): RemoteFunction?
    local f = ReplicatedStorage:FindFirstChild(folder)
    local r = f and f:FindFirstChild("Request")
    return if r and r:IsA("RemoteFunction") then r else nil
end

local function ask(folder: string, action: string, payload: any?): any
    local r = remote(folder)
    if r == nil then
        return nil
    end
    local ok, response = pcall(function()
        return (r :: RemoteFunction):InvokeServer(action, payload or {})
    end)
    return if ok and type(response) == "table" then response else nil
end

local render: () -> ()

-- ======================== Éléments ========================

local function clear()
    for _, child in body:GetChildren() do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
    order = 0
end

-- Lignes de la maquette (§ téléphone) : titre en capitales (libellé), ligne de texte, note discrète.
local function line(text: string, bold: boolean?, dim: boolean?)
    order += 1
    local style = if bold then "Label" else "Body"
    Components.text(body, text, style, {
        Size = UDim2.new(1, -8, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = if bold or dim then UITheme.color("TextDim") else UITheme.color("Text"),
        LayoutOrder = order,
    })
end

-- Bouton de ligne (44 px, maquette) : libellé à gauche, valeur à droite en Roboto Mono (raccourci, état, distance) ;
-- principal en ambre ; inactif : opacité 0,45, aucune action (la raison est donnée par la ligne qui suit).
local function button(
    text: string,
    fn: () -> (),
    enabled: boolean?,
    value: string?,
    primary: boolean?,
    name: string?
): TextButton
    order += 1
    local b = UITheme.button(text, {
        Name = name or "Bouton",
        Size = UDim2.new(1, -8, 0, Tokens.PrimaryButtonHeight),
        LayoutOrder = order,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, body, if enabled == false then nil else fn)
    UITheme.make("UIPadding", {
        PaddingLeft = UDim.new(0, Tokens.Space[3]),
        PaddingRight = UDim.new(0, if value then 96 else Tokens.Space[3]),
    }, b)
    b.TextSize = UITheme.text(14)
    -- Ligne d'un smartphone moderne : coins de 12 px, fond légèrement translucide, sans bordure.
    local rounded = b:FindFirstChildOfClass("UICorner")
    if rounded then
        rounded.CornerRadius = UDim.new(0, 12)
    end
    b.BackgroundColor3 = Color3.fromRGB(32, 35, 40)
    b.BackgroundTransparency = 0.08
    local outline = b:FindFirstChildOfClass("UIStroke")
    if outline then
        outline.Transparency = 1
    end
    if primary then
        b.BackgroundColor3 = Tokens.color("Amber")
        b.TextColor3 = Tokens.color("TextOnAmber")
        b.FontFace = Font.new(UITheme.face("Button").Family, Enum.FontWeight.Bold)
        local edge = b:FindFirstChildOfClass("UIStroke")
        if edge then
            edge.Color = Tokens.color("Amber")
        end
    end
    if value then
        local label = Components.text(b, value, "Value", {
            Name = "Valeur",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 84, 0.5, 0),
            Size = UDim2.fromOffset(84, 20),
            TextXAlignment = Enum.TextXAlignment.Right,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextColor3 = if primary then Tokens.color("TextOnAmber") else UITheme.color("TextDim"),
        })
        label.TextSize = UITheme.text(12)
    end
    if enabled == false then
        b.Active = false
        b.Selectable = false
        b.BackgroundTransparency = Tokens.DisabledTransparency
        b.TextTransparency = Tokens.DisabledTransparency
    end
    return b
end

-- « Libellé : valeur » (textes existants des réglages) découpé pour le bouton à valeur de la maquette.
local function pair(text: string): (string, string?)
    local label, value = string.match(text, "^(.-)%s?:%s+(.+)$")
    if label and value and #label > 0 then
        return label, value
    end
    return text, nil
end

local function pairButton(text: string, fn: () -> (), enabled: boolean?, name: string?): TextButton
    local label, value = pair(text)
    return button(label, fn, enabled, value, nil, name)
end

-- Titre de section (capitales, discret).
local function heading(text: string)
    line(text, true)
end

-- Note discrète (12 px).
local function note(text: string)
    order += 1
    local label = Components.text(body, text, "Body", {
        Name = "Note",
        Size = UDim2.new(1, -8, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Color3.fromRGB(142, 140, 134),
        LayoutOrder = order,
    })
    label.TextSize = UITheme.text(12)
end

-- Avertissement (fond ambre sombre) : action indisponible, service injoignable.
local function warn(text: string)
    order += 1
    local box = UITheme.make("Frame", {
        Name = "Avertissement",
        Size = UDim2.new(1, -8, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Tokens.color("WarnBg"),
        BorderSizePixel = 0,
        LayoutOrder = order,
    }, body)
    UITheme.make("UICorner", { CornerRadius = UDim.new(0, Tokens.Radius.Button) }, box)
    UITheme.make("UIStroke", { Color = Tokens.color("WarnLine"), Thickness = 1 }, box)
    UITheme.make("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        PaddingTop = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 8),
    }, box)
    Components.text(box, text, "Body", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Tokens.color("WarnText"),
    }).TextSize =
        UITheme.text(13)
end

-- Carte de la maquette : surface 1, filet gauche de 3 px (couleur d'état), titre 15 px, sous-titre 12 px discret.
-- Le filet est posé sur le cadre extérieur, hors de la liste du contenu (dans la liste, sa hauteur relative étirait
-- la carte sans fin : capture VM 20261105-123345).
local function card(title: string, subtitle: string?, accent: string?, name: string?): Frame
    order += 1
    local box = UITheme.make("Frame", {
        Name = name or "Carte",
        Size = UDim2.new(1, -8, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Tokens.color("Surface1"),
        BorderSizePixel = 0,
        LayoutOrder = order,
        ClipsDescendants = true,
    }, body)
    UITheme.make("UICorner", { CornerRadius = UDim.new(0, 14) }, box)
    box.BackgroundColor3 = Color3.fromRGB(28, 31, 35)
    box.BackgroundTransparency = 0.05
    UITheme.make("Frame", {
        Name = "Filet",
        BackgroundColor3 = Tokens.color(accent or "Line"),
        BorderSizePixel = 0,
        Size = UDim2.new(0, Tokens.StatusRail, 1, 0),
    }, box)
    local inner = UITheme.make("Frame", {
        Name = "CarteCorps",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, box)
    UITheme.make("UIPadding", {
        PaddingLeft = UDim.new(0, 12 + Tokens.StatusRail),
        PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 10),
    }, inner)
    UITheme.make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, inner)
    local titleLabel = Components.text(inner, title, "Body", {
        Name = "Titre",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
    })
    titleLabel.FontFace = UITheme.face("Button")
    titleLabel.TextSize = UITheme.text(15)
    if subtitle and subtitle ~= "" then
        Components.text(inner, subtitle, "Body", {
            Name = "SousTitre",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = UITheme.color("TextDim"),
            LayoutOrder = 2,
        }).TextSize =
            UITheme.text(12)
    end
    return box
end

local function onoff(value: boolean): string
    return Localization.t(if value then "ui.on" else "ui.off")
end

local function openPanel(name: string)
    UIManager.close("Phone")
    UIManager.open(name)
end

local function goTo(x: number, z: number, label: string, source: string?)
    GPSController.setDestination(x, z, label, source or "Poi")
    NotificationService.notify("gps.computing", "Info", nil, "gps")
end

local function poiById(id: string): any?
    for _, point in MapController.points() do
        if point.Id == id then
            return point
        end
    end
    return nil
end

-- ======================== Applications ========================

-- Taille des icônes de l'accueil (style smartphone moderne : grandes icônes arrondies, nom dessous).
local ICON_SIZE = 60

local function appTile(parent: Instance, name: string, index: number, withCaption: boolean?): TextButton
    local tile = UITheme.make("TextButton", {
        Name = "App" .. name,
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        Size = UDim2.fromOffset(76, 88),
        LayoutOrder = index,
        Selectable = true,
    }, parent) :: TextButton
    -- Icône « squircle » : coins de 16 px, dégradé sombre, liseré discret.
    local square = UITheme.make("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromScale(0.5, 0),
        Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
    }, tile)
    UITheme.make("UIGradient", {
        Color = ColorSequence.new(Color3.fromRGB(46, 50, 57), Color3.fromRGB(22, 24, 27)),
        Rotation = 90,
    }, square)
    UITheme.make("UICorner", { CornerRadius = UDim.new(0, 16) }, square)
    local stroke = UITheme.make("UIStroke", { Color = Color3.fromRGB(60, 64, 71), Thickness = 1 }, square)
    local image = PhoneIcons.image(name)
    if image then
        UITheme.make("ImageLabel", {
            Name = "Icone",
            BackgroundTransparency = 1,
            Image = image,
            ImageColor3 = Tokens.color(PhoneIcons.tint(name)),
            ScaleType = Enum.ScaleType.Fit, -- planche « Icônes du téléphone » : version 128 px (affichée en 32 px)
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(32, 32),
        }, square)
    else
        -- Image pas encore envoyée sur Roblox : cadre vide à la place (aucun caractère de remplacement).
        local slot = UITheme.make("Frame", {
            Name = "IconeAEnvoyer",
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(Tokens.Phone.AppIcon, Tokens.Phone.AppIcon),
        }, square)
        UITheme.make("UICorner", { CornerRadius = UDim.new(0, 6) }, slot)
        UITheme.make(
            "UIStroke",
            { Color = Tokens.color(PhoneIcons.tint(name)), Thickness = 1.5, Transparency = 0.3 },
            slot
        )
    end
    -- Nom de l'application en casse normale, 12 px (maquette) ; absent dans le dock.
    local caption = Components.text(tile, Localization.t("phone.app." .. name), "Body", {
        Name = "Nom",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.fromScale(0.5, 1),
        Size = UDim2.new(1, 0, 0, 16),
        AutomaticSize = Enum.AutomaticSize.None,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextColor3 = UITheme.color("Text"),
    })
    caption.TextSize = UITheme.text(12)
    caption.Visible = withCaption ~= false
    local unread = if name == "Notifications" then NotificationService.unread() else 0
    if unread > 0 then
        local badge = UITheme.make("TextLabel", {
            Name = "Pastille",
            BackgroundColor3 = UITheme.color("Accent"),
            Text = tostring(unread),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, ICON_SIZE / 2 - 2, 0, 4),
            Size = UDim2.fromOffset(20, 20), -- pastille ambre, chiffres Roboto Mono (planche des icônes)
        }, tile) :: TextLabel
        badge.FontFace = UITheme.face("Value")
        badge.TextSize = UITheme.text(12)
        badge.TextColor3 = UITheme.color("OnAccent")
        UITheme.make("UICorner", { CornerRadius = UDim.new(1, 0) }, badge)
    end
    tile.SelectionGained:Connect(function()
        stroke.Color = UITheme.color("Focus")
        stroke.Thickness = Tokens.FocusStroke
    end)
    tile.SelectionLost:Connect(function()
        stroke.Color = UITheme.color("Line")
        stroke.Thickness = 1
    end)
    tile.Activated:Connect(function()
        -- Carte : ouverture directe de la grande carte (demande du propriétaire : naviguer en grand).
        if name == "Map" then
            UIManager.close("Phone")
            UIManager.open("Map")
            return
        end
        app = name
        render()
    end)
    return tile
end

-- Applications du dock (bas de l'écran d'accueil) ; les 8 autres sont dans la grille.
local DOCK = { "Map", "Vehicles", "Notifications", "Settings" }

local function renderHome()
    local unread = NotificationService.unread()
    if unread > 0 then
        order += 1
        Components.card(body, Localization.t("phone.unread", { count = unread }), nil, "Pending").LayoutOrder = order
    end
    order += 1
    local grid = UITheme.make("Frame", {
        Name = "Grille",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -8, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = order,
    }, body)
    -- 4 colonnes calculées sur la largeur disponible (pixels logiques).
    local columnWidth = math.max(64, math.floor((Components.logicalSize(body).X - 8 - 3 * 4) / 4))
    UITheme.make("UIGridLayout", {
        CellSize = UDim2.fromOffset(columnWidth, 84),
        CellPadding = UDim2.fromOffset(4, Tokens.Space[3]),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, grid)
    local index = 0
    for _, name in APPS do
        if not table.find(DOCK, name) then
            index += 1
            appTile(grid, name, index)
        end
    end
    -- Dock : panneau translucide arrondi, 4 favoris sans nom.
    for _, child in dock:GetChildren() do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    for position, name in DOCK do
        local tile = appTile(dock, name, position, false)
        tile.Size = UDim2.fromOffset(ICON_SIZE + 8, ICON_SIZE + 8)
    end
end

local function renderMap()
    heading(Localization.t("phone.h.route"))
    local gps = GPSController.state()
    if gps.Destination then
        local progress = gps.Progress
        card(
            gps.Destination.Label,
            if progress
                then Localization.t("gps.remaining", {
                    distance = Localization.distance(progress.RemainingM),
                    minutes = math.max(1, math.ceil(progress.RemainingS / 60)),
                })
                else nil,
            "GpsCyan",
            "Destination"
        )
        button(Localization.t("gps.clear"), function()
            GPSController.clear()
            render()
        end, nil, "X", nil, "EffacerItineraire")
    else
        line(Localization.t("gps.noDestination"), false, true)
    end
    button(Localization.t("phone.map.full"), function()
        UIManager.close("Phone")
        UIManager.open("Map")
    end, nil, "M", nil, "CarteComplete")
    heading(Localization.t("map.search"))
    local character = Players.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local x, z = 0, 0
    if root and root:IsA("BasePart") then
        x, z = root.Position.X * Constants.MetersPerStud, root.Position.Z * Constants.MetersPerStud
    end
    local list = table.clone(MapController.markers())
    table.sort(list, function(a, b)
        return (a.X - x) ^ 2 + (a.Z - z) ^ 2 < (b.X - x) ^ 2 + (b.Z - z) ^ 2
    end)
    for index, marker in list do
        if index > 25 then
            break
        end
        local d = math.sqrt((marker.X - x) ^ 2 + (marker.Z - z) ^ 2)
        button(string.format("%s · %s", Localization.t("poi." .. marker.Kind), marker.Name or ""), function()
            goTo(marker.X, marker.Z, marker.Name or "")
        end, nil, Localization.distance(d), nil, "PointInteret")
    end
end

local function progressionSnapshot(): any
    local response = ask("AWProgression", "Snapshot")
    return if response and response.Status ~= "Rejected"
        then (response.Snapshot or response.Result or response)
        else nil
end

local STORAGE_ACCENT = { Stored = "Line", Displayed = "Amber", Out = "GpsCyan" }

local function renderVehicles()
    local snap = cache.Progression
    if snap == nil or snap.Vehicles == nil then
        if cache.ProgressionFailed then
            warn(Localization.t("phone.serviceDown"))
        else
            line(Localization.t("ui.loading"))
        end
        return
    end
    if #snap.Vehicles == 0 then
        line(Localization.t("phone.vehicles.empty"))
        note(Localization.t("phone.vehicles.emptyNote"))
    else
        heading(Localization.t("phone.h.collection", { count = snap.TotalVehicles or #snap.Vehicles }))
    end
    for _, vehicle in snap.Vehicles do
        local storage = vehicle.Storage and vehicle.Storage.State or "Stored"
        local definition = VehicleDefinitions.get(vehicle.ModelId)
        local entry = VehicleCatalog.forDefinition(vehicle.ModelId)
        local parts = {
            Localization.tr(GarageView.category(definition, entry)),
            Localization.t("phone.vehicle." .. storage),
        }
        if vehicle.Untransferable then
            table.insert(parts, Localization.tr("incessible"))
        end
        if vehicle.Reserved then
            table.insert(parts, Localization.tr("réservé"))
        end
        table.insert(
            parts,
            Localization.t("phone.vehicle.energy", {
                energy = math.floor((vehicle.Energy or 0) * 100 + 0.5),
            })
        )
        card(
            vehicle.DisplayName,
            table.concat(parts, " · "),
            STORAGE_ACCENT[storage] or "Line",
            "Vehicule_" .. tostring(vehicle.Id)
        )
        if storage == "Displayed" and vehicle.Storage.PropertyId then
            local point = poiById("P:" .. vehicle.Storage.PropertyId)
            if point then
                button(Localization.t("phone.property.navigate"), function()
                    goTo(point.X, point.Z, point.Name)
                end, nil, "GPS", nil, "AllerVehicule")
            end
        end
    end
    button(Localization.t("ui.panel.garage"), function()
        openPanel("Garage")
    end, nil, "P", true, "OuvrirGarage")
    note(Localization.t("phone.vehicles.garageNote"))
end

-- Lot 0.8 : radio (AUD-RADIO-01). Le conducteur choisit ; chacun règle ou coupe son écoute.
local function renderRadio()
    local seat = RadioController.seat()
    local current = RadioController.current()
    heading(Localization.t("radio.seat." .. seat))
    line(Localization.t("radio.current", { station = Localization.t("radio.station." .. current) }))
    local unavailable = {}
    for _, station in RadioController.stations() do
        local label = Localization.t("radio.station." .. station.Id)
        if not station.Available then
            table.insert(unavailable, label)
        elseif seat == "Driver" then
            button(label, function()
                RadioController.setStation(station.Id)
                render()
            end, nil, if station.Id == current then Localization.t("ui.on") else nil, nil, "Station")
        else
            line(label)
        end
    end
    if #unavailable > 0 then
        warn(Localization.t("radio.unavailableList", { stations = table.concat(unavailable, ", ") }))
    end
    if seat == "Driver" and current ~= "Off" then
        button(Localization.t("radio.station.Off"), function()
            RadioController.setStation("Off")
            render()
        end, nil, nil, nil, "Arreter")
    end
    local audio = UIState.prefs().Audio
    pairButton(Localization.t("radio.mute", { state = onoff(audio.RadioMuted) }), function()
        SettingsController.update(function(p)
            p.Audio.RadioMuted = not p.Audio.RadioMuted
        end)
        render()
    end, nil, "Couper")
    pairButton(
        Localization.t("settings.volume", { category = Localization.t("settings.volume.Radio"), value = audio.Radio }),
        function()
            SettingsController.update(function(p)
                p.Audio.Radio = if p.Audio.Radio >= 100 then 0 else p.Audio.Radio + 10
            end)
            render()
        end,
        nil,
        "Volume"
    )
    note(Localization.t("radio.note"))
end

-- Lot 0.8 : introduction consultable à tout moment et exercices de formation.
local function renderGuide()
    heading(Localization.t("phone.h.intro"))
    for index, step in { "Welcome", "World", "Controls", "Phone" } do
        card(Localization.t("onb.title." .. step), Localization.t("onb.text." .. step), nil, "Etape" .. index)
    end
    button(Localization.t("onb.training"), function()
        UIManager.close("Phone")
        OnboardingController.openTraining()
    end, nil, nil, true, "Formation")
end

local function renderProperties()
    local snap = cache.Progression
    if snap == nil or snap.Properties == nil then
        if cache.ProgressionFailed then
            warn(Localization.t("phone.serviceDown"))
        else
            line(Localization.t("ui.loading"))
        end
        return
    end
    heading(Localization.t("phone.h.properties"))
    if #snap.Properties == 0 then
        line(Localization.tr("Aucune propriété."), false, true)
    end
    for _, property in snap.Properties do
        local used = 0
        for _ in property.Slots or {} do
            used += 1
        end
        card(
            property.Label,
            Localization.t("phone.property.sub", {
                level = property.GarageLevel or 1,
                used = used,
                capacity = property.Capacity or 0,
            }),
            "Amber",
            "Propriete"
        )
        local point = poiById("P:" .. property.Id)
        if point then
            button(Localization.t("phone.property.navigate"), function()
                goTo(point.X, point.Z, point.Name)
            end, nil, "GPS", nil, "AllerPropriete")
        end
    end
    if snap.Invitations and #snap.Invitations > 0 then
        heading(Localization.t("social.invite"))
        for _, invitation in snap.Invitations do
            card(
                invitation.GuestName or tostring(invitation.GuestUserId),
                string.format(
                    "%s%s",
                    if invitation.Visit then Localization.t("social.tag.visit") else "",
                    if invitation.Drive then " · " .. Localization.t("social.tag.drive") else ""
                ),
                if invitation.Active then "GpsCyan" else "Line",
                "Invitation"
            )
        end
    end
    note(Localization.t("social.privacy"))
    button(Localization.t("ui.panel.garage"), function()
        openPanel("Garage")
    end, nil, "P", nil, "OuvrirGarage")
end

local function renderMissions()
    local snap = cache.Economy
    if snap == nil or snap.Jobs == nil then
        if cache.EconomyFailed then
            warn(Localization.t("phone.serviceDown"))
        else
            line(Localization.t("ui.loading"))
        end
        return
    end
    if snap.Mission then
        heading(Localization.t("phone.h.mission"))
        card(snap.Mission.Job or "", snap.Mission.Label, "GpsCyan", "MissionEnCours")
        if snap.Mission.Point then
            button(Localization.t("phone.property.navigate"), function()
                GPSController.missionTarget(snap.Mission.Point, snap.Mission.Label)
            end, nil, "GPS", nil, "GuiderMission")
        end
    end
    heading(Localization.t("phone.h.jobs"))
    for _, job in snap.Jobs do
        card(job.Label, Localization.t("phone.job.sub", { completed = job.Completed }), nil, "Metier")
        button(Localization.t("phone.mission.start"), function()
            local response = ask("AWEconomy", "StartMission", { Job = job.Id })
            if response and response.Status ~= "Ok" then
                NotificationService.notify(response.Error or "ServerError", "Warning")
            end
        end, snap.Mission == nil, nil, nil, "Demarrer")
    end
    if snap.Mission then
        note(Localization.t("phone.mission.busy"))
    end
    button(Localization.t("ui.panel.economy"), function()
        openPanel("Economy")
    end, nil, "J", nil, "OuvrirEconomie")
end

local function renderRaces()
    local catalog = cache.Races
    if catalog == nil then
        if cache.RacesFailed then
            warn(Localization.t("phone.serviceDown"))
        else
            line(Localization.t("ui.loading"))
        end
        return
    end
    heading(Localization.t("phone.race.season", { index = catalog.Season.Index }))
    local profile = catalog.Profile
    if profile then
        for _, ladder in { "Race", "Drift" } do
            local data = profile.Ladders[ladder]
            card(
                ladder,
                Localization.t("phone.rank.sub", { rank = data.Rank, points = data.Points }),
                "Amber",
                "Classement"
            )
        end
    end
    heading(Localization.t("phone.h.events"))
    for index, course in catalog.Courses do
        if index > 10 then
            break
        end
        card(
            course.Name,
            Localization.t("phone.race.sub", {
                discipline = course.DisciplineLabel,
                distance = Localization.distance(course.DistanceM),
            }),
            "RaceRed",
            "Epreuve"
        )
        button(Localization.t("phone.property.navigate"), function()
            goTo(course.Registration.X, course.Registration.Z, course.Name, "Race")
        end, nil, "GPS", nil, "AllerEpreuve")
        if SocialController.view() and SocialController.view().Group and SocialController.view().Group.IsLeader then
            button(Localization.t("social.suggestRace"), function()
                SocialController.send("SuggestRace", { CourseId = course.Id })
            end, nil, nil, nil, "Proposer")
        end
    end
    button(Localization.t("ui.panel.races"), function()
        openPanel("Races")
    end, nil, "K", nil, "OuvrirCourses")
end

local function renderMarket()
    local snap = cache.Economy
    if snap == nil then
        if cache.EconomyFailed then
            warn(Localization.t("phone.serviceDown"))
        else
            line(Localization.t("ui.loading"))
        end
        return
    end
    local mine = 0
    heading(Localization.t("phone.h.listings"))
    for _, listing in snap.Listings or {} do
        if listing.Mine then
            mine += 1
        end
        card(
            listing.Model,
            Localization.t("phone.credits", { amount = Localization.amount(listing.Price) })
                .. (if listing.Mine then " · " .. Localization.t("phone.market.mineTag") else ""),
            if listing.Mine then "Amber" else nil,
            "Annonce"
        )
    end
    if #(snap.Listings or {}) == 0 then
        line(Localization.t("phone.market.empty"), false, true)
    end
    line(Localization.t("phone.market.mine", { count = mine }), true)
    note(Localization.t("phone.market.note"))
    button(Localization.t("ui.panel.economy"), function()
        openPanel("Economy")
    end, nil, "J", nil, "OuvrirEconomie")
end

local function renderSocial()
    local view = SocialController.view()
    if view == nil then
        line(Localization.t("ui.loading"))
        SocialController.send("Snapshot")
        return
    end
    for _, invite in view.Incoming or {} do
        line(Localization.t("social.invited", { name = invite.From.Name }), true)
        button(Localization.t("social.accept"), function()
            SocialController.send("Accept", { InviteId = invite.Id })
        end)
        button(Localization.t("social.decline"), function()
            SocialController.send("Decline", { InviteId = invite.Id })
        end)
    end
    local group = view.Group
    if group then
        heading(Localization.t("social.members", { count = #group.Members }))
        for _, member in group.Members do
            local tags = {}
            if member.Leader then
                table.insert(tags, Localization.t("social.leader"))
            end
            if not member.Online then
                table.insert(tags, Localization.t("social.offline"))
            end
            if member.Sharing then
                table.insert(tags, Localization.t("social.tag.sharing"))
            end
            card(member.Name, table.concat(tags, " · "), if member.Sharing then "GpsCyan" else nil, "Membre")
            if group.IsLeader and member.UserId ~= Players.LocalPlayer.UserId then
                button(Localization.t("social.promote") .. " : " .. member.Name, function()
                    SocialController.send("Promote", { UserId = member.UserId })
                end)
                button(Localization.t("social.kick") .. " : " .. member.Name, function()
                    SocialController.send("Kick", { UserId = member.UserId })
                end)
            end
        end
        button(Localization.t("social.shareLocation"), function()
            SocialController.send("SetSharing", { On = not group.Sharing })
        end, nil, onoff(group.Sharing), nil, "PartagePosition")
        local prefs = UIState.prefs()
        button(Localization.t("social.showMembers"), function()
            SettingsController.update(function(p)
                p.Social.ShowSharedMembers = not p.Social.ShowSharedMembers
            end)
            render()
        end, nil, onoff(prefs.Social.ShowSharedMembers), nil, "AfficherMembres")
        button(Localization.t("social.leave"), function()
            SocialController.send("Leave")
        end)
        if group.IsLeader then
            button(Localization.t("social.dissolve"), function()
                SocialController.send("Dissolve")
            end)
        end
    else
        line(Localization.t("social.noGroup"))
        button(Localization.t("social.create"), function()
            SocialController.send("CreateGroup")
        end)
    end
    heading(Localization.t("social.players"))
    for _, other in view.Players or {} do
        card(other.Name, if other.Friend then Localization.t("social.friend") else nil, nil, "Joueur")
        if not other.InGroup and (group == nil or group.IsLeader) then
            button(Localization.t("social.invite") .. " : " .. other.Name, function()
                local response = SocialController.send("Invite", { UserId = other.UserId })
                if response.Status == "Ok" then
                    NotificationService.notify("social.inviteSent", "Info", { name = other.Name })
                end
            end)
        end
    end
    line(Localization.t("social.channels"), true)
    local channels = view.Channels or {}
    line(Localization.t("social.channel.Group") .. " : " .. onoff(channels.Group == true), false, true)
    line(Localization.t("social.channel.Proximity") .. " : " .. onoff(channels.Proximity == true), false, true)
    line(Localization.t("social.channel.Voice"), false, true)
    if not channels.Chat then
        line(Localization.t("social.channel.restricted"), false, true)
    end
    line(Localization.t("social.privacy"), false, true)
end

local function cycle(list: { any }, value: any): any
    local index = table.find(list, value) or 0
    return list[index % #list + 1]
end

local function step(value: number, delta: number, low: number, high: number): number
    local nextValue = value + delta
    if nextValue > high then
        return low
    end
    return nextValue
end

local function renderSettings()
    local prefs = UIState.prefs()
    -- Lot ADMIN-01 : accès au menu d'administration sans clavier (le serveur revérifie chaque demande).
    if Players.LocalPlayer:GetAttribute("AWAdmin") == true then
        button(Localization.t("phone.admin"), function()
            UIManager.close("Phone")
            UIManager.open("Admin")
        end, nil, "F8 · F2", true, "MenuAdmin")
    end
    for _, page in { "Interface", "Controls", "Accessibility", "Notifications", "Audio", "Graphics", "Credits" } do
        local b = button(
            Localization.t("settings." .. string.lower(string.sub(page, 1, 1)) .. string.sub(page, 2)),
            function()
                settingsPage = page
                render()
            end,
            nil,
            nil,
            nil,
            "Page_" .. page
        )
        if page == settingsPage then
            b.BackgroundColor3 = Tokens.color("AmberSoft")
            b.TextColor3 = Tokens.color("AmberSoftText")
            local edge = b:FindFirstChildOfClass("UIStroke")
            if edge then
                edge.Color = Tokens.color("Amber")
            end
            b:SetAttribute("AWSelected", true)
        end
    end
    line(
        Localization.t("settings." .. string.lower(string.sub(settingsPage, 1, 1)) .. string.sub(settingsPage, 2)),
        true
    )
    local function set(text: string, mutate: (any) -> ())
        pairButton(text, function()
            SettingsController.update(mutate)
            render()
        end, nil, "Reglage")
    end
    if settingsPage == "Interface" then
        set(
            Localization.t("settings.language", { language = Localization.t("settings.language." .. prefs.Language) }),
            function(p)
                p.Language = cycle({ "fr", "en" }, p.Language)
            end
        )
        set(
            Localization.t("settings.hudLevel", { level = Localization.t("hud.level." .. prefs.Hud.Level) }),
            function(p)
                p.Hud.Level = cycle({ "Minimal", "Standard", "Full" }, p.Hud.Level)
            end
        )
        set(Localization.t("settings.hudScale", { value = prefs.Hud.Scale }), function(p)
            p.Hud.Scale = step(p.Hud.Scale, 10, 70, 140)
        end)
        set(
            Localization.t("settings.hudCorner", { value = Localization.t("settings.corner." .. prefs.Hud.Corner) }),
            function(p)
                p.Hud.Corner = cycle({ "BottomRight", "BottomLeft" }, p.Hud.Corner)
            end
        )
        set(Localization.t("settings.minimap", { state = onoff(prefs.Hud.ShowMinimap) }), function(p)
            p.Hud.ShowMinimap = not p.Hud.ShowMinimap
        end)
        set(Localization.t("settings.minimapZoom", { value = prefs.Hud.MinimapZoom }), function(p)
            p.Hud.MinimapZoom = step(p.Hud.MinimapZoom, 1, 1, 4)
        end)
        set(Localization.t("settings.minimapRotate", { state = onoff(prefs.Hud.MinimapRotate) }), function(p)
            p.Hud.MinimapRotate = not p.Hud.MinimapRotate
        end)
        set(Localization.t("settings.drivingInfo", { state = onoff(prefs.Hud.DrivingInfo) }), function(p)
            p.Hud.DrivingInfo = not p.Hud.DrivingInfo
        end)
        set(Localization.t("settings.devHud", { state = onoff(prefs.Hud.DevHud) }), function(p)
            p.Hud.DevHud = not p.Hud.DevHud
        end)
        -- Lot PHONE-01 : téléphone en main (zoom sur l'écran tenu) ou classique (coin de l'écran).
        set(
            Localization.t(
                "settings.phoneDisplay",
                { value = Localization.t("settings.phoneDisplay." .. prefs.Phone.Display) }
            ),
            function(p)
                p.Phone.Display = cycle(Preferences.PhoneDisplays :: any, p.Phone.Display)
            end
        )
        note(Localization.t("settings.phoneDisplay.note"))
        -- Silhouette (avatars humains) : état tenu par le serveur, pas une préférence.
        local worn = BodyChoice.current()
        pairButton(
            Localization.t(
                "settings.avatarBody",
                { body = if worn then Localization.t("avatar.body." .. worn) else "…" }
            ),
            function()
                task.spawn(function()
                    BodyChoice.choose(BodyChoice.next())
                    render()
                end)
            end
        )
    elseif settingsPage == "Credits" then
        -- Lot VEH3D-01 : attributions CC BY 4.0 (titre et lien affichés seulement sur décision du propriétaire).
        line(Localization.t("credits.intro"))
        for _, entry in Attributions.List do
            line(Localization.t("credits.entry", {
                usage = Localization.t(entry.UsageKey),
                creator = entry.Creator,
                source = entry.Source,
                licence = entry.Licence,
                changes = Localization.t(entry.ChangesKey),
            }))
            if entry.ShowTitle then
                line(Localization.t("credits.title", { title = entry.Title }))
            end
            if entry.ShowUrl then
                line(Localization.t("credits.url", { url = entry.Url }))
            end
            line(Localization.t("credits.licence", { licence = entry.Licence, url = entry.LicenceUrl }))
        end
    elseif settingsPage == "Controls" then
        for _, binding in InputMap.Defaults do
            if binding.Rebindable then
                local key = InputMap.keyFor(binding.Action, prefs.Bindings) or "—"
                pairButton(
                    Localization.t(
                        "settings.rebind",
                        { action = Localization.t("action." .. binding.Action), key = key }
                    ),
                    function()
                        rebinding = binding.Action
                        NotificationService.notify("settings.rebindPrompt", "Info", nil, "rebind")
                    end
                )
            end
        end
        set(Localization.t("settings.reset"), function(p)
            p.Bindings = {}
        end)
        -- Lot CAMERA-01 : regard libre en conduite (clic droit maintenu, stick droit, doigt).
        line(Localization.t("settings.cameraSection"), true)
        set(Localization.t("settings.cameraSensitivity", { value = prefs.Camera.Sensitivity }), function(p)
            p.Camera.Sensitivity = step(p.Camera.Sensitivity, 1, 1, 5)
        end)
        set(Localization.t("settings.cameraInvertY", { state = onoff(prefs.Camera.InvertY) }), function(p)
            p.Camera.InvertY = not p.Camera.InvertY
        end)
    elseif settingsPage == "Accessibility" then
        local a = prefs.Access
        set(Localization.t("settings.textScale", { value = a.TextScale }), function(p)
            p.Access.TextScale = step(p.Access.TextScale, 10, 80, 150)
        end)
        set(Localization.t("settings.contrast", { state = onoff(a.HighContrast) }), function(p)
            p.Access.HighContrast = not p.Access.HighContrast
        end)
        set(Localization.t("settings.reduceMotion", { state = onoff(a.ReduceMotion) }), function(p)
            p.Access.ReduceMotion = not p.Access.ReduceMotion
        end)
        set(Localization.t("settings.panelOpacity", { value = a.PanelOpacity }), function(p)
            p.Access.PanelOpacity = step(p.Access.PanelOpacity, 10, 50, 100)
        end)
        set(Localization.t("settings.navSensitivity", { value = a.NavSensitivity }), function(p)
            p.Access.NavSensitivity = step(p.Access.NavSensitivity, 1, 1, 5)
        end)
        set(Localization.t("settings.visualAlerts", { state = onoff(a.VisualAlerts) }), function(p)
            p.Access.VisualAlerts = not p.Access.VisualAlerts
        end)
    elseif settingsPage == "Notifications" then
        set(Localization.t("settings.reduceSecondary", { state = onoff(prefs.Access.ReduceSecondary) }), function(p)
            p.Access.ReduceSecondary = not p.Access.ReduceSecondary
        end)
        set(Localization.t("notif.level.Info") .. " : " .. onoff(prefs.Notifications.Info), function(p)
            p.Notifications.Info = not p.Notifications.Info
        end)
        set(Localization.t("notif.level.Warning") .. " : " .. onoff(prefs.Notifications.Warning), function(p)
            p.Notifications.Warning = not p.Notifications.Warning
        end)
        button(Localization.t("notif.level.Critical"), function() end, false, Localization.t("ui.on"), nil, "Critiques")
    elseif settingsPage == "Graphics" then
        -- Lot 0.8 : qualité (habillage, détails, lumières, effets ; ArtDirection.Profiles).
        set(
            Localization.t("settings.quality", { value = Localization.t("quality." .. prefs.Graphics.Quality) }),
            function(p)
                local qualities = { "Low", "Medium", "High" }
                p.Graphics.Quality = qualities[(table.find(qualities, p.Graphics.Quality) or 2) % 3 + 1]
            end
        )
        note(Localization.t("settings.quality.note"))
    else
        set(Localization.t("radio.mute", { state = onoff(prefs.Audio.RadioMuted) }), function(p)
            p.Audio.RadioMuted = not p.Audio.RadioMuted
        end)
        for _, category in { "Master", "Engine", "Environment", "Interface", "Effects", "Radio", "Voice" } do
            set(
                Localization.t("settings.volume", {
                    category = Localization.t("settings.volume." .. category),
                    value = (prefs.Audio :: any)[category],
                }),
                function(p)
                    (p.Audio :: any)[category] = step((p.Audio :: any)[category], 10, 0, 100)
                end
            )
        end
    end
end

local NOTIF_ACCENT = { Critical = "RaceRed", Warning = "Amber", Info = "GpsCyan" }

local function renderNotifications()
    local items = NotificationService.history(30)
    if #items == 0 then
        line(Localization.t("phone.notif.empty"), false, true)
    end
    for _, item in items do
        card(
            NotificationService.text(item),
            Localization.t("notif.level." .. item.Level),
            NOTIF_ACCENT[item.Level] or "Line",
            "Notification"
        )
    end
    button(Localization.t("notif.clear"), function()
        NotificationService.clear()
        render()
    end, #items > 0, nil, nil, "ToutEffacer")
    note(Localization.t("phone.notif.note"))
    NotificationService.markRead()
end

-- Mode rapide (conduite) : lecture et réglages rapides, aucune saisie.
local function renderQuick()
    heading(Localization.t("phone.quickMode"))
    local gps = GPSController.state()
    if gps.Destination then
        local progress = gps.Progress
        card(
            gps.Destination.Label,
            if progress
                then Localization.t("gps.remaining", {
                    distance = Localization.distance(progress.RemainingM),
                    minutes = math.max(1, math.ceil(progress.RemainingS / 60)),
                })
                else nil,
            "GpsCyan",
            "Destination"
        )
    else
        line(Localization.t("gps.noDestination"), false, true)
    end
    for _, item in NotificationService.history(3) do
        note(NotificationService.text(item))
    end
    warn(Localization.t("phone.fullOnlyStopped"))
end

render = function()
    if not isOpen then
        return
    end
    clear()
    header.Text = if quick
        then Localization.t("ui.panel.phone")
        else Localization.t(if app == "Home" then "phone.home" else "phone.app." .. app)
    clockLabel.Text = os.date("%H:%M") :: string
    quickBar.Visible = quick
    quickTag.Visible = quick
    header.Size = UDim2.new(1, if quick then -(Components.logicalSize(quickTag).X + 40) else -32, 0, 34)
    backButton.Visible = not quick and app ~= "Home"
    -- Accueil : pas de grand titre, grille plus haute et dock visible ; applications : grand titre.
    dock.Visible = not quick and app == "Home"
    header.Visible = quick or app ~= "Home"
    -- Accueil : grille sous les boutons ronds (y 50 à 94) et au-dessus du dock ; applications : sous le grand titre.
    -- Retour du propriétaire (2026-11-05) : la première rangée d'icônes passait sous « + » et « × ».
    body.Position = UDim2.fromOffset(14, if not quick and app == "Home" then 104 else 136)
    body.Size = UDim2.new(1, -28, 1, if not quick and app == "Home" then -236 else -172)
    if quick then
        renderQuick()
        return
    end
    if app == "Home" then
        renderHome()
    elseif app == "Map" then
        renderMap()
    elseif app == "Vehicles" then
        renderVehicles()
    elseif app == "Properties" then
        renderProperties()
    elseif app == "Missions" then
        renderMissions()
    elseif app == "Races" then
        renderRaces()
    elseif app == "Market" then
        renderMarket()
    elseif app == "Social" then
        renderSocial()
    elseif app == "Guide" then
        renderGuide()
    elseif app == "Radio" then
        renderRadio()
    elseif app == "Photo" then
        line(Localization.t("photo.rules"))
        button(Localization.t("photo.open"), function()
            UIManager.close("Phone")
            PhotoMode.request()
        end, nil, nil, true, "ModePhoto")
        note(Localization.t("photo.note"))
    elseif app == "Settings" then
        renderSettings()
    else
        renderNotifications()
    end
end

-- Données des applications (lecture seule), chargées à l'ouverture.
local function load()
    task.spawn(function()
        -- Lecture seule ; un service injoignable est signalé (« informations non à jour »), jamais simulé.
        cache.Progression = progressionSnapshot()
        cache.ProgressionFailed = cache.Progression == nil
        local economy = ask("AWEconomy", "Snapshot")
        cache.Economy = if economy then (economy.Snapshot or economy.Result) else nil
        cache.EconomyFailed = cache.Economy == nil
        local races = ask("AWRacing", "Catalog")
        cache.Races = if races then races.Result else nil
        cache.RacesFailed = cache.Races == nil
        render()
    end)
end

-- Lot PHONE-01 : affichage voulu pour l'ouverture en cours.
local function wantsHand(): boolean
    return PhoneHold.display(UIState.prefs().Phone.Display, UIState.layout().Compact) == "InHand"
        and not PhoneHoldController.failed()
end

-- En main : seule la dalle est dessinée (360 × 760 px logiques, rapport de l'écran 3D), centrée sur le point
-- donné à chaque image ; la coque, le bord et les touches sont ceux du modèle 3D.
local function handLayout()
    local deviceScale = device:FindFirstChildOfClass("UIScale") or UITheme.make("UIScale", {}, device)
    gui.ScreenInsets = Enum.ScreenInsets.None
    gui.IgnoreGuiInset = true
    device.BackgroundTransparency = 1
    for _, item in handParts do
        item.Visible = false
    end
    screenFrame.Position = UDim2.fromOffset(0, 0)
    screenFrame.Size = UDim2.fromScale(1, 1)
    screenCorner.CornerRadius = UDim.new(0, 40)
    device.AnchorPoint = Vector2.new(0.5, 0.5)
    device.Size = UDim2.fromOffset(PhoneHold.ScreenPixels.X, PhoneHold.ScreenPixels.Y)
    -- Visibilité et position : placeOverlay, à chaque image (masqué tant que le zoom n'est pas arrivé).
    deviceScale.Scale = 1
    gui:SetAttribute("AWPhoneSize", nil)
    gui:SetAttribute("AWPhoneDisplay", "InHand")
end

local function layout()
    if handMode then
        handLayout()
        return
    end
    gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
    gui.IgnoreGuiInset = false
    device.BackgroundTransparency = 0
    device.Visible = true
    for _, item in handParts do
        item.Visible = true
    end
    screenFrame.Position = UDim2.fromOffset(10, 10)
    screenFrame.Size = UDim2.new(1, -20, 1, -20)
    screenCorner.CornerRadius = UDim.new(0, 44)
    gui:SetAttribute("AWPhoneDisplay", "Classic")
    local camera = workspace.CurrentCamera :: Camera
    local view = UIState.layout()
    local compact = view.Compact
    local deviceScale = device:FindFirstChildOfClass("UIScale") or UITheme.make("UIScale", {}, device)
    -- 1440 p : la coque garde ses cotes 1080 p et s'agrandit de 1,333 (maquette §3).
    deviceScale.Scale = view.Scale
    local big = enlarged and not quick
    local phone = Tokens.Phone
    local size = if compact
        then (if big then phone.CompactEnlarged else phone.CompactNormal)
        else (if big then phone.Enlarged else phone.Normal)
    local margin = if compact then phone.MarginCompact else phone.Margin
    -- Jamais plus haut que la vue (barre de Roblox comprise) : le haut du téléphone restait coupé dans une petite
    -- fenêtre (VM 1250 × 593, tâche 20261105-033732).
    local inset = game:GetService("GuiService"):GetGuiInset().Y
    local viewHeight = if camera then UIState.viewport().Y else 1080
    local height = math.min(size.Y, math.floor((viewHeight - inset) / view.Scale) - 2 * margin)
    device.AnchorPoint = Vector2.new(1, 1)
    device.Position = UDim2.new(1, -math.floor(margin * view.Scale), 1, -math.floor(margin * view.Scale))
    UITheme.motion(device, { Size = UDim2.fromOffset(size.X, height) }, "PhoneResize")
    gui:SetAttribute("AWPhoneSize", string.format("%dx%d", size.X, height))
end

local function build()
    gui = UITheme.make("ScreenGui", {
        Name = "AWPhone",
        ResetOnSpawn = false,
        DisplayOrder = 12,
        Enabled = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, Players.LocalPlayer:WaitForChild("PlayerGui"))
    -- Smartphone moderne (demande du propriétaire, création originale sans logo ni marque) : coque fine en métal
    -- sombre aux angles très arrondis, boutons latéraux, écran bord à bord en dégradé, pastille noire en haut, barre
    -- d'état dessinée (heure, réseau, batterie), barre d'accueil en bas.
    device = UITheme.make("Frame", {
        Name = "Coque",
        BackgroundColor3 = Color3.fromRGB(40, 43, 48),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(Tokens.Phone.Normal.X, Tokens.Phone.Normal.Y),
    }, gui) :: Frame
    UITheme.make("UICorner", { CornerRadius = UDim.new(0, 54) }, device)
    UITheme.make("UIGradient", {
        Color = ColorSequence.new(Color3.fromRGB(86, 90, 97), Color3.fromRGB(34, 36, 40)),
        Rotation = 35,
    }, device)
    -- Boutons latéraux (volume à gauche, marche à droite), posés hors de la coque.
    for _, spec in { { 0, 120, 52 }, { 0, 184, 52 }, { 1, 150, 78 } } do
        local key = UITheme.make("Frame", {
            Name = "BoutonLateral",
            AnchorPoint = Vector2.new(if spec[1] == 0 then 1 else 0, 0),
            Position = UDim2.new(spec[1], 0, 0, spec[2]),
            Size = UDim2.fromOffset(3, spec[3]),
            BackgroundColor3 = Color3.fromRGB(70, 74, 80),
            BorderSizePixel = 0,
        }, device)
        UITheme.make("UICorner", { CornerRadius = UDim.new(0, 2) }, key)
        table.insert(handParts, key)
    end
    -- Bord noir intérieur puis écran.
    local bezel = UITheme.make("Frame", {
        Name = "Bord",
        BackgroundColor3 = Color3.fromRGB(6, 7, 8),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(4, 4),
        Size = UDim2.new(1, -8, 1, -8),
    }, device)
    UITheme.make("UICorner", { CornerRadius = UDim.new(0, 50) }, bezel)
    table.insert(handParts, bezel)
    local screen = UITheme.make("Frame", {
        Name = "Ecran",
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, 10),
        Size = UDim2.new(1, -20, 1, -20),
        ClipsDescendants = true,
    }, device)
    screenCorner = UITheme.make("UICorner", { CornerRadius = UDim.new(0, 44) }, screen) :: UICorner
    screenFrame = screen :: Frame
    -- Fond d'écran : dégradé bleu nuit vers noir, lueur ambre discrète en bas.
    UITheme.make("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 37, 49)),
            ColorSequenceKeypoint.new(0.7, Color3.fromRGB(14, 15, 18)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(34, 26, 16)),
        }),
        Rotation = 90,
    }, screen)
    -- Pastille noire en haut de l'écran (caméra et capteurs).
    local island = UITheme.make("Frame", {
        Name = "Pastille",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 11),
        Size = UDim2.fromOffset(108, 30),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0,
        ZIndex = 5,
    }, screen)
    UITheme.make("UICorner", { CornerRadius = UDim.new(1, 0) }, island)
    -- Barre d'état : heure à gauche, réseau et batterie dessinés à droite.
    clockLabel = Components.text(screen, "", "Body", {
        Name = "Heure",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromOffset(34, 26),
        TextColor3 = Color3.new(1, 1, 1),
    })
    clockLabel.FontFace = Font.new(UITheme.face("Button").Family, Enum.FontWeight.Bold)
    clockLabel.TextSize = UITheme.text(15)
    local status = UITheme.make("Frame", {
        Name = "Etat",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -30, 0, 26),
        Size = UDim2.fromOffset(52, 14),
        BackgroundTransparency = 1,
    }, screen)
    for bar = 1, 4 do
        UITheme.make("Frame", {
            Name = "Reseau" .. bar,
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, (bar - 1) * 4, 1, 0),
            Size = UDim2.fromOffset(3, 3 + bar * 2.5),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
        }, status)
    end
    local battery = UITheme.make("Frame", {
        Name = "Batterie",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -3, 0.5, 0),
        Size = UDim2.fromOffset(24, 12),
        BackgroundTransparency = 1,
    }, status)
    UITheme.make("UICorner", { CornerRadius = UDim.new(0, 3) }, battery)
    UITheme.make("UIStroke", { Color = Color3.fromRGB(200, 200, 200), Thickness = 1 }, battery)
    local level = UITheme.make("Frame", {
        Position = UDim2.fromOffset(2, 2),
        Size = UDim2.new(0.78, -4, 1, -4),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
    }, battery)
    UITheme.make("UICorner", { CornerRadius = UDim.new(0, 2) }, level)
    UITheme.make("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(1, 1, 0.5, 0),
        Size = UDim2.fromOffset(2, 5),
        BackgroundColor3 = Color3.fromRGB(200, 200, 200),
        BorderSizePixel = 0,
    }, battery)
    -- Barre d'accueil (bas de l'écran) : un clic ramène à l'accueil.
    local homeBar = UITheme.make("TextButton", {
        Name = "BarreAccueil",
        Text = "",
        AutoButtonColor = false,
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -8),
        Size = UDim2.fromOffset(150, 18),
        BackgroundTransparency = 1,
        Selectable = false,
        ZIndex = 6,
    }, screen)
    local pill = UITheme.make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(128, 5),
        BackgroundColor3 = Color3.fromRGB(235, 235, 235),
        BorderSizePixel = 0,
        ZIndex = 7,
    }, homeBar)
    UITheme.make("UICorner", { CornerRadius = UDim.new(1, 0) }, pill)
    homeBar.Activated:Connect(function()
        if not quick then
            app = "Home"
            render()
        end
    end)
    -- Dock de l'accueil : panneau translucide arrondi en bas.
    dock = UITheme.make("Frame", {
        Name = "Dock",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -30),
        Size = UDim2.new(1, -24, 0, 88),
        BackgroundColor3 = Color3.fromRGB(58, 62, 70),
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        Visible = false,
    }, screen)
    UITheme.make("UICorner", { CornerRadius = UDim.new(0, 32) }, dock)
    UITheme.make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, dock)
    -- En-tête : retour, titre, étiquette « mode rapide », agrandir et fermer.
    backButton = UITheme.button(
        Localization.t("phone.home"),
        {
            Name = "Retour",
            Position = UDim2.fromOffset(12, 48),
            Size = UDim2.fromOffset(0, Tokens.MinTarget),
            AutomaticSize = Enum.AutomaticSize.X,
        },
        screen,
        function()
            app = "Home"
            render()
        end
    )
    -- Retour à la manière d'un smartphone moderne : texte ambre sans fond, chevron dessiné à gauche.
    backButton.BackgroundTransparency = 1
    backButton.TextColor3 = Tokens.color("Amber")
    local backOutline = backButton:FindFirstChildOfClass("UIStroke")
    if backOutline then
        backOutline.Transparency = 1
    end
    UITheme.make("UIPadding", { PaddingLeft = UDim.new(0, 22), PaddingRight = UDim.new(0, 6) }, backButton)
    for _, sign in { -1, 1 } do
        UITheme.make("Frame", {
            BackgroundColor3 = Tokens.color("Amber"),
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            -- Le UIPadding décale aussi les enfants : -12 replace le chevron dans la marge gauche (10 px du bord).
            Position = UDim2.new(0, -12, 0.5, sign * 3),
            Size = UDim2.fromOffset(2.5, 10),
            Rotation = -sign * 45,
        }, backButton)
    end
    header = Components.text(screen, "", "H1", {
        Name = "Titre",
        Position = UDim2.fromOffset(20, 96),
        Size = UDim2.new(1, -32, 0, 34),
        AutomaticSize = Enum.AutomaticSize.None,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    quickTag = Components.text(screen, Tokens.upper(Localization.t("phone.quickTag")), "Label", {
        Name = "ModeRapide",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -20, 0, 104),
        BackgroundTransparency = 0,
        TextColor3 = UITheme.color("AccentSoftText"),
        Visible = false,
    })
    quickTag.BackgroundColor3 = Tokens.color("AmberSoft")
    UITheme.make("UICorner", { CornerRadius = UDim.new(0, 3) }, quickTag)
    UITheme.make("UIPadding", {
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
        PaddingTop = UDim.new(0, 3),
        PaddingBottom = UDim.new(0, 3),
    }, quickTag)
    -- Lot 0.9.1 (QA-F14) : signes latins, toujours rendus par la police.
    UITheme.button(
        "+",
        {
            Name = "Agrandir",
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -60, 0, 50),
            Size = UDim2.fromOffset(Tokens.MinTarget, Tokens.MinTarget),
        },
        screen,
        function()
            enlarged = not enlarged
            -- En main : « + » rapproche l'écran dans la vue (zoom), au lieu d'agrandir la coque dessinée.
            PhoneHoldController.setCloser(enlarged)
            layout()
        end
    )
    UITheme.button(
        "×",
        {
            Name = "Fermer",
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -18, 0, 50),
            Size = UDim2.fromOffset(Tokens.MinTarget, Tokens.MinTarget),
        },
        screen,
        function()
            UIManager.close("Phone")
        end
    )
    -- Boutons ronds translucides (agrandir, fermer) : à la manière des commandes d'un smartphone.
    for _, name in { "Agrandir", "Fermer" } do
        local item = screen:FindFirstChild(name) :: TextButton?
        if item then
            item.BackgroundColor3 = Color3.fromRGB(58, 62, 70)
            item.BackgroundTransparency = 0.35
            local rounded = item:FindFirstChildOfClass("UICorner")
            if rounded then
                rounded.CornerRadius = UDim.new(1, 0)
            end
            local outline = item:FindFirstChildOfClass("UIStroke")
            if outline then
                outline.Transparency = 1
            end
        end
    end
    body = UITheme.make("ScrollingFrame", {
        Name = "Contenu",
        Position = UDim2.fromOffset(14, 136),
        Size = UDim2.new(1, -28, 1, -172),
        BackgroundTransparency = 1,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = UITheme.color("Line"),
    }, screen)
    UITheme.make(
        "UIListLayout",
        { Padding = UDim.new(0, Tokens.Space[2]), SortOrder = Enum.SortOrder.LayoutOrder },
        body
    )
    -- Réglages rapides autorisés en roulant (souris ou raccourcis, jamais une sélection manette).
    quickBar = UITheme.make(
        "Frame",
        { Position = UDim2.new(0, 14, 1, -82), Size = UDim2.new(1, -28, 0, 44), BackgroundTransparency = 1 },
        screen
    )
    UITheme.make(
        "UIListLayout",
        { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, Tokens.Space[2]) },
        quickBar
    )
    local function quickButton(text: string, fn: () -> ())
        local b = UITheme.button(
            text,
            { Size = UDim2.fromOffset(0, Tokens.PrimaryButtonHeight), AutomaticSize = Enum.AutomaticSize.X },
            quickBar,
            fn
        )
        UITheme.make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, b)
        b.Selectable = false
    end
    quickButton("HUD", function()
        SettingsController.update(function(p)
            p.Hud.Level = cycle({ "Minimal", "Standard", "Full" }, p.Hud.Level)
        end)
    end)
    quickButton(Localization.t("phone.quick.zoom"), function()
        SettingsController.update(function(p)
            p.Hud.MinimapZoom = step(p.Hud.MinimapZoom, 1, 1, 4)
        end)
    end)
    quickButton(Localization.t("phone.quick.clearGps"), function()
        GPSController.clear()
        render()
    end)
    layout()
    -- Taille de la vue changée (fenêtre, 1440 p, surcharge d'essai) : coque et grille recalculées.
    UIState.onViewport(function()
        layout()
        render()
    end)
end

-- Saisie d'une nouvelle touche (paramètres des commandes).
local function captureRebind(input: InputObject)
    local action = rebinding
    if action == nil or input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end
    rebinding = nil
    if input.KeyCode == Enum.KeyCode.Escape then
        return
    end
    local key = input.KeyCode.Name
    local custom = table.clone(UIState.prefs().Bindings)
    local ok, err = InputMap.validate(custom, action, key)
    if not ok then
        local conflict = if err then string.match(err, "^Conflict:(.+)$") else nil
        if conflict then
            NotificationService.notify(
                "settings.rebindConflict",
                "Warning",
                { action = Localization.t("action." .. conflict) }
            )
        else
            NotificationService.notify("settings.rebindReserved", "Warning")
        end
        return
    end
    SettingsController.update(function(p)
        p.Bindings[action] = key
    end)
    NotificationService.notify("settings.saved", "Info")
    render()
end

-- ======================== Téléphone tenu en main (lot PHONE-01) ========================

-- Bras levé et zoom : PhoneHoldController (l'ancien réglage de l'épaule du lot 0.9.2 y est repris pour
-- l'épaule ET le coude). Ici : choix de l'affichage et placement de l'interface sur l'écran 3D.

local function server(out: boolean)
    local r = remote("AWInterface")
    if r == nil then
        return
    end
    task.spawn(function()
        pcall(function()
            (r :: RemoteFunction):InvokeServer("Phone", { Out = out })
        end)
    end)
end

-- Réglage ou disposition changés pendant l'usage : bascule en main / classique sans ranger le téléphone.
local function refreshDisplay()
    if not isOpen then
        return
    end
    local wanted = wantsHand()
    if wanted ~= handMode then
        handMode = wanted
        PhoneHoldController.setInHand(wanted)
        layout()
        render()
    end
end

-- À chaque image, après la caméra : l'interface recouvre exactement l'écran du téléphone 3D (rectangle centré
-- donné par PhoneHoldController quand le zoom est arrivé) ; masquée pendant le zoom aller et retour.
local function placeOverlay()
    if not (isOpen and handMode) then
        return
    end
    if PhoneHoldController.failed() then
        -- Modèle du serveur jamais arrivé : affichage classique pour cette ouverture.
        refreshDisplay()
        return
    end
    local center, size = PhoneHoldController.overlay()
    if center == nil or size == nil then
        device.Visible = false
        return
    end
    local deviceScale = device:FindFirstChildOfClass("UIScale")
    if deviceScale then
        deviceScale.Scale = size.Y / PhoneHold.ScreenPixels.Y
    end
    device.Position = UDim2.fromOffset(math.floor(center.X + 0.5), math.floor(center.Y + 0.5))
    if not device.Visible then
        device.Visible = true
        -- Manette : focus posé à l'apparition (l'ouverture l'avait demandé pendant le zoom, interface masquée).
        local GuiService = game:GetService("GuiService")
        local lastInput = game:GetService("UserInputService"):GetLastInputType().Name
        if
            string.sub(lastInput, 1, 7) == "Gamepad"
            and UIState.mode() ~= "Moving"
            and (GuiService.SelectedObject == nil or not GuiService.SelectedObject:IsDescendantOf(device))
        then
            GuiService.SelectedObject = body:FindFirstChildWhichIsA("GuiButton", true)
        end
    end
end

function PhoneController.start()
    build()
    PhoneHoldController.start()
    RunService:BindToRenderStep("AWPhoneOverlay", Enum.RenderPriority.Camera.Value + 2, placeOverlay)
    UIManager.register({
        Name = "Phone",
        Kind = "Modal",
        Full = true,
        Open = function()
            isOpen = true
            openCount += 1
            -- Réglage et disposition seulement (un échec de l'ouverture précédente ne compte plus).
            handMode = PhoneHold.display(UIState.prefs().Phone.Display, UIState.layout().Compact) == "InHand"
            PhoneHoldController.open(handMode)
            PhoneHoldController.setCloser(enlarged)
            layout()
            gui.Enabled = true
            server(true)
            load()
            render()
        end,
        Close = function()
            isOpen = false
            gui.Enabled = false
            rebinding = nil
            PhoneHoldController.close()
            -- Rangement fluide : le téléphone reste en main le temps du retour de la caméra, puis le serveur le
            -- range (sauf réouverture entre-temps).
            local count = openCount
            task.delay(if handMode then PhoneHoldController.returnS() else 0, function()
                if not isOpen and count == openCount then
                    server(false)
                end
            end)
        end,
        Quick = function(on: boolean)
            quick = on
            layout() -- pas de téléphone agrandi en mode rapide
            render()
        end,
        Focus = function()
            -- Tuiles de l'accueil comprises (dans la grille) : recherche dans toute la descendance.
            return body:FindFirstChildWhichIsA("GuiButton", true)
        end,
    })
    UIState.onPrefs(function()
        refreshDisplay()
        render()
    end)
    UIState.onViewport(refreshDisplay)
    Localization.changed(function()
        render()
    end)
    SocialController.onChanged(function()
        if isOpen and app == "Social" then
            render()
        end
    end)
    game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
        if not processed then
            captureRebind(input)
        end
    end)
end

return PhoneController
