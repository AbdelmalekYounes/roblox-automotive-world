--!strict
--[[
    Garage V1.2 (lot UI-03) : recomposition complète selon la maquette « Garage.dc.html » du propriétaire.

    Disposition : barre haute 56 (titre, lieu, brouillon), onglets 48, contenu, barre d'aide 40 (touches, Fermer).
    - Collection : pleine largeur, grille de cartes (vignette 3D 16:9 en vue 3/4, rangement, catégorie, motorisation,
      étiquettes) ; véhicule de départ et pages.
    - Autres onglets : zone 3D à gauche (ViewportFrame, VehiclePreview : vues, rotation, zoom, nom, catégorie, statut
      de la gamme ; barre d'actions sur l'onglet Véhicule) et panneau latéral à droite à la largeur de l'onglet.
    - Bandeau d'état du serveur : en attente, confirmé, refusé, hors ligne (jamais de réussite avant la réponse).

    Règles (inchangées depuis le lot 0.4) :
    - aucune réussite affichée avant la réponse du serveur ; « en attente » tant que la sauvegarde n'est pas confirmée ;
    - chaque demande sensible porte un identifiant unique ; une seule demande à la fois (anti double clic) ;
    - menu inutilisable en mouvement (UIManager ; le serveur refuse aussi, AUD-UI-01) ;
    - choix définitifs ou destructifs (véhicule de départ, revente, suppression d'une configuration) confirmés.
    Seules les données réelles sont affichées (instantané du serveur, définitions, VehicleCatalog, TuningRules,
    PartCatalog, CosmeticCatalog) ; règles de mise en forme dans le module pur Shared/UI/GarageView.
    Touches : P (manette : par le téléphone, application Véhicules) ; [ ] ou PageUp / PageDown et LB / RB pour les onglets ; Retour arrière et B
    reviennent d'un niveau ; flèches gauche / droite tournent le véhicule.
    Textes joueur : le français sert de clé, l'anglais vient de PanelTexts (Localization.tr).
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GarageShared = Shared:WaitForChild("Garage")
local ProgressionProtocol = require(GarageShared:WaitForChild("ProgressionProtocol"))
local TuningRules = require(GarageShared:WaitForChild("TuningRules"))
local CosmeticCatalog = require(GarageShared:WaitForChild("CosmeticCatalog"))
local PartCatalog = require(GarageShared:WaitForChild("PartCatalog"))
local PropertyCatalog = require(GarageShared:WaitForChild("PropertyCatalog"))
local VehicleDefinitions = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleDefinitions"))
local VehicleCatalog = require(Shared:WaitForChild("Economy"):WaitForChild("VehicleCatalog"))
local Localization = require(Shared:WaitForChild("UI"):WaitForChild("Localization"))
local GarageView = require(Shared:WaitForChild("UI"):WaitForChild("GarageView"))
local Tokens = require(Shared:WaitForChild("UI"):WaitForChild("DesignTokens"))

local Text = require(script.Parent.ProgressionMessages)
local UIManager = require(script.Parent.UIManager)
local UITheme = require(script.Parent.UITheme)
local Components = require(script.Parent.Components)
local VehiclePreview = require(script.Parent.VehiclePreview)
local UIState = require(script.Parent.UIState)
local PanelKit = require(script.Parent.PanelKit)

local GaragePanel = {}

local tr = Localization.tr
local player = Players.LocalPlayer
local TABS = GarageView.Tabs
local SLOT_LABELS = {
    Tires = "Pneus",
    Brakes = "Freins",
    Suspension = "Suspension",
    RearDifferential = "Différentiel AR",
    FrontDifferential = "Différentiel AV",
    EngineMap = "Cartographie",
}
local KIT_SLOTS = { { "Front", "Avant" }, { "Rear", "Arrière" }, { "Sides", "Côtés" } }
local KIT_LABELS = { Stock = "Origine", Lip = "Lame", Spoiler = "Becquet", Wing = "Aileron", Skirts = "Bas de caisse" }
local EFFECT_LABELS = {
    PeakFriction = "adhérence",
    WetGrip = "pluie",
    BrakeTorque = "couple de freinage",
    Torque = "couple moteur",
    PreloadNm = "précharge (N·m)",
    PowerLockRatio = "blocage en charge",
    CoastLockRatio = "blocage au lever",
}
-- Hauteur de la zone d'informations des cartes (nom, catégorie et motorisation sur deux lignes, étiquettes).
local CARD_INFO = 112
local STATE_KEYS = {
    Pending = "ui.state.pending",
    Confirmed = "ui.state.confirmed",
    Rejected = "ui.state.rejected",
    Offline = "ui.state.offline",
}

local request: RemoteFunction
local gui: ScreenGui
local panel: Frame
local badge: TextLabel
local contextLabel: TextLabel
local draftBadge: TextLabel
local tabButtons: { [string]: TextButton } = {}
local content: Frame
local collectionView: ScrollingFrame
local stage: Frame
local stageName: TextLabel
local stageCategory: TextLabel
local stageAvailability: TextLabel
local viewButtons: { [string]: TextButton } = {}
local camLabel: TextLabel
local actionBar: Frame
local side: Frame
local sideTop: Frame
local body: ScrollingFrame
local prepFooter: Frame
local statusBox: Frame
local statusCode: TextLabel
local statusText: TextLabel
local hintsRow: Frame
local closeButton: TextButton? = nil
local state: any = nil -- dernier instantané reçu du serveur
local tab = "Collection"
local prepSub = "Réglages"
local selected: string? = nil -- exemplaire sélectionné
local draftTuning: { [string]: number } = {}
local draftCosmetics: any = nil
local entranceOffer: any = nil
local busy = false
local status: { Kind: string?, Text: string } = { Kind = nil, Text = "" }
local configName = ""
local modal: Frame? = nil
local lastRendered = { Tab = "", Sub = "" }

local function make(className: string, props: { [string]: any }, parent: Instance?): any
    local item = Instance.new(className)
    for key, value in props do
        (item :: any)[key] = value
    end
    -- Lot UI-03 : repères Gotham convertis en Titillium Web (système de conception V1.2), même graisse.
    if props.Font and (item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox")) then
        UITheme.applyFont(item :: any, props.Font)
    end
    item.Parent = parent
    return item
end

-- Couleur d'un jeton V1.2, avec le réglage « contraste renforcé » du joueur.
local function color(name: string): Color3
    return Tokens.color(name, UIState.prefs().Access.HighContrast)
end

-- Nombre décimal à la française (virgule) ou à l'anglaise (point), selon la langue choisie.
local function decimal(value: number, digits: number): string
    local text = string.format("%." .. digits .. "f", value or 0)
    return if Localization.language() == "fr" then (string.gsub(text, "%.", ",")) else text
end

local function percent(value: number): string
    return string.format("%d %%", math.floor((value or 0) * 100 + 0.5))
end

local function compact(): boolean
    return UIState.layout().Compact
end

local function vehicleById(id: string?): any
    if state == nil or id == nil then
        return nil
    end
    for _, vehicle in state.Vehicles or {} do
        if vehicle.Id == id then
            return vehicle
        end
    end
    return nil
end

local function propertyById(id: string?): any
    for _, property in (state and state.Properties) or {} do
        if property.Id == id then
            return property
        end
    end
    return nil
end

-- Exemplaire affiché : celui sélectionné, sinon le premier de la collection.
local function current(): any
    local vehicle = vehicleById(selected)
    if vehicle == nil and state and state.Vehicles then
        vehicle = state.Vehicles[1]
        if vehicle then
            selected = vehicle.Id
        end
    end
    return vehicle
end

local function capabilities(): { [string]: boolean }
    return (state and state.Context and state.Context.Capabilities) or {}
end

local function contextProperty(): any
    local context = (state and state.Context) or {}
    return if context.Kind == "Property" then propertyById(context.PropertyId) else nil
end

local render: () -> ()
local layoutPanels: () -> ()

-- ======================== État du serveur ========================

local function refreshStatus()
    if (statusBox :: Frame?) == nil then
        return
    end
    local kind = status.Kind
    statusBox.Visible = status.Text ~= ""
    local bg, fg = GarageView.statusTokens((kind or "Info") :: any)
    statusBox.BackgroundColor3 = color(bg)
    statusText.TextColor3 = color(fg)
    statusCode.TextColor3 = color(fg)
    statusCode.Text = if kind and STATE_KEYS[kind] then Tokens.upper(Localization.t(STATE_KEYS[kind])) else ""
    statusText.Text = status.Text
    panel:SetAttribute("AWStatusKind", kind)
    layoutPanels()
end

local function setStatus(kind: string?, text: string)
    local entry = { Kind = kind, Text = text }
    status = entry
    refreshStatus()
    if kind == "Confirmed" or kind == "Info" then
        task.delay(6, function()
            if status == entry then
                status = { Kind = nil, Text = "" }
                refreshStatus()
            end
        end)
    end
end

-- Envoie une demande ; affiche le statut RÉEL renvoyé par le serveur. Une seule demande à la fois.
local function send(action: string, payload: any?, quiet: boolean?)
    if busy then
        return
    end
    busy = true
    panel:SetAttribute("AWBusy", true)
    local data = payload or {}
    if ProgressionProtocol.Sensitive[action] then
        data.RequestId = HttpService:GenerateGUID(false)
    end
    if not quiet then
        setStatus("Pending", tr("Demande envoyée…"))
    end
    -- Compteur des demandes réellement envoyées (lu par les essais : un double clic n'en envoie qu'une).
    PanelKit.countSent(panel)
    local ok, response = PanelKit.invoke(request, action, data)
    busy = false
    panel:SetAttribute("AWBusy", false)
    if not ok or type(response) ~= "table" then
        setStatus("Offline", tr("Serveur injoignable : rien n'est confirmé."))
        return
    end
    if response.Snapshot then
        state = response.Snapshot
    end
    local kind = GarageView.statusKind(response.Status)
    if not quiet or kind == "Rejected" or kind == "Offline" then
        setStatus(kind, if response.Status == "Rejected" then Text.text(response.Error) else Text.text(response.Status))
    end
    if response.Status ~= "Rejected" then
        if action == "SetTuning" or action == "ApplyConfig" then
            draftTuning = {}
        end
        if action == "SetCosmetics" or action == "ApplyConfig" then
            draftCosmetics = nil
        end
    end
    render()
end

-- Confirmation protégée (choix définitif ou destructif) : fenêtre modale au-dessus du garage.
local function confirmThen(question: string, onConfirm: () -> ())
    if modal then
        modal:Destroy()
    end
    local veil = make("Frame", {
        Name = "VoileConfirmation",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = color("BgBase"),
        -- Voile léger (retour du propriétaire : l'écran devenait trop sombre, contenu illisible).
        BackgroundTransparency = 0.6,
        BorderSizePixel = 0,
        ZIndex = 50,
        Active = true,
    }, gui)
    modal = veil
    local box = Components.confirm(veil, {
        Question = question,
        Width = math.min(480, (workspace.CurrentCamera :: Camera).ViewportSize.X - 40),
        OnConfirm = function()
            veil:Destroy()
            modal = nil
            onConfirm()
        end,
        OnCancel = function()
            veil:Destroy()
            modal = nil
        end,
    })
    if box then
        box.AnchorPoint = Vector2.new(0.5, 0.5)
        box.Position = UDim2.fromScale(0.5, 0.5)
    end
end

-- ======================== Éléments ========================

local order = 0
local function nextOrder(): number
    order += 1
    return order
end

local function clearChildren(holder: Instance)
    for _, child in holder:GetChildren() do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UIGridLayout") then
            child:Destroy()
        end
    end
end

local function textLine(parent: Instance, text: string, style: string?, tokenName: string?): TextLabel
    return Components.text(parent, text, style or "Body", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = color(tokenName or "Text"),
        LayoutOrder = nextOrder(),
    })
end

local function vlist(frame: Instance, gap: number)
    make("UIListLayout", { Padding = UDim.new(0, gap), SortOrder = Enum.SortOrder.LayoutOrder }, frame)
end

local function padding(frame: Instance, x: number, y: number)
    make("UIPadding", {
        PaddingLeft = UDim.new(0, x),
        PaddingRight = UDim.new(0, x),
        PaddingTop = UDim.new(0, y),
        PaddingBottom = UDim.new(0, y),
    }, frame)
end

local function stroke(frame: Instance, tokenName: string?)
    make("UIStroke", {
        Color = color(tokenName or "Line"),
        Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, frame)
end

local function corner(frame: Instance, radius: number)
    make("UICorner", { CornerRadius = UDim.new(0, radius) }, frame)
end

-- Carte de la maquette : surface 1, filet, coins de 4 à 6 px, contenu empilé.
local function card(parent: Instance, gap: number?, name: string?): Frame
    local frame = make("Frame", {
        Name = name or "Carte",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = color("Surface1"),
        BorderSizePixel = 0,
        LayoutOrder = nextOrder(),
    }, parent)
    corner(frame, Tokens.Radius.Button)
    stroke(frame)
    padding(frame, Tokens.Space[3], Tokens.Space[3] - 2)
    vlist(frame, gap or Tokens.Space[2])
    return frame
end

-- Encadré d'avertissement ou de refus (maquette : ambre sombre, rouge sombre, neutre en pointillés).
local function notice(parent: Instance, kind: string, text: string)
    local bg, line, fg = "WarnBg", "WarnLine", "WarnText"
    if kind == "Danger" then
        bg, line, fg = "DangerBg", "RaceRed", "DangerText"
    elseif kind == "Neutral" then
        bg, line, fg = "BgBase", "Line", "TextMuted"
    end
    local frame = make("Frame", {
        Name = "Encadre" .. kind,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = color(bg),
        BorderSizePixel = 0,
        LayoutOrder = nextOrder(),
    }, parent)
    corner(frame, Tokens.Radius.Button)
    stroke(frame, line)
    padding(frame, Tokens.Space[3], Tokens.Space[2] + 2)
    local label = Components.text(frame, text, "Body", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = color(fg),
    })
    label.Name = "Texte"
end

-- Rangée qui passe à la ligne (boutons, puces) : rien ne déborde en disposition compacte.
local function wrapRow(parent: Instance, gap: number?): Frame
    local frame = make("Frame", {
        Name = "Rangee",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = nextOrder(),
    }, parent)
    local layout = make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, gap or Tokens.Space[2] - 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
    }, frame);
    (layout :: any).Wraps = true
    return frame
end

export type ButtonKind = "Primary" | "Secondary" | "Revoke" | "Chip"

-- Bouton de la maquette ; désactivé : opacité 0,45, non sélectionnable, raison dans AWReason.
local function button(
    parent: Instance,
    text: string,
    kind: ButtonKind,
    callback: (() -> ())?,
    enabled: boolean?,
    reason: string?,
    height: number?,
    name: string?
): TextButton
    local active = enabled ~= false
    local item = UITheme.button(text, {
        Name = name or "Bouton",
        Size = UDim2.fromOffset(0, height or Tokens.MinTargetPartChip),
        AutomaticSize = Enum.AutomaticSize.X,
        LayoutOrder = nextOrder(),
    }, parent)
    make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, item)
    local edge = item:FindFirstChildOfClass("UIStroke") :: UIStroke
    if kind == "Primary" then
        item.BackgroundColor3 = color("Amber")
        item.TextColor3 = color("TextOnAmber")
        edge.Color = color("Amber")
        item.FontFace = Font.new(UITheme.face("Button").Family, Enum.FontWeight.Bold)
    elseif kind == "Revoke" then
        item.BackgroundTransparency = 1
        item.TextColor3 = color("DangerText")
        edge.Color = color("RaceRed")
    end
    item.FontFace = if kind == "Primary" then item.FontFace else UITheme.face("Button")
    item.TextSize = UITheme.text(if (height or 36) >= 44 then 15 else 13)
    if active then
        if callback then
            item.Activated:Connect(callback)
        end
    else
        item.Active = false
        item.Selectable = false
        item.BackgroundTransparency = if kind == "Revoke" then 1 else Tokens.DisabledTransparency
        item.TextTransparency = Tokens.DisabledTransparency
        edge.Transparency = Tokens.DisabledTransparency
        item:SetAttribute("AWDisabled", true)
        if reason then
            item:SetAttribute("AWReason", reason)
        end
    end
    return item
end

-- Puce sélectionnable (pièces, finition, jantes…) : sélectionnée en ambre doux.
local function chip(
    parent: Instance,
    text: string,
    selectedChip: boolean,
    callback: (() -> ())?,
    enabled: boolean?,
    reason: string?
): TextButton
    local item = button(parent, text, "Chip", callback, enabled, reason, Tokens.MinTarget, "Puce")
    if selectedChip then
        item.BackgroundColor3 = color("AmberSoft")
        item.TextColor3 = color("AmberSoftText")
        local edge = item:FindFirstChildOfClass("UIStroke") :: UIStroke
        edge.Color = color("Amber")
        item:SetAttribute("AWSelected", true)
    end
    return item
end

-- Chevron dessiné (aucun caractère Unicode en guise d'icône) : deux traits de 2 px.
local function chevron(parent: Instance, pointsLeft: boolean, size: number)
    local holder = make("Frame", {
        Name = "Chevron",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(size, size),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        ZIndex = 6,
    }, parent)
    for _, sign in { -1, 1 } do
        make("Frame", {
            BackgroundColor3 = color("Text"),
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, if pointsLeft then -1 else 1, 0.5, sign * size * 0.22),
            Size = UDim2.fromOffset(2, math.floor(size * 0.62)),
            Rotation = if pointsLeft then sign * -45 + 0 else sign * 45,
            ZIndex = 6,
        }, holder)
    end
end

-- Pastille d'étiquette (incessible, essai synthétique…) : capitales, 10 px.
local function tag(parent: Instance, text: string)
    local label = Components.text(parent, Tokens.upper(text), "Label", {
        Name = "Etiquette",
        BackgroundTransparency = 0,
        TextColor3 = color("Text"),
        LayoutOrder = nextOrder(),
    })
    label.BackgroundColor3 = Color3.fromRGB(34, 37, 42)
    label.TextSize = UITheme.text(11)
    corner(label, 2)
    make("UIPadding", {
        PaddingLeft = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 6),
        PaddingTop = UDim.new(0, 1),
        PaddingBottom = UDim.new(0, 1),
    }, label)
end

-- Ligne clé / valeur de la fiche technique (valeur en Roboto Mono, filet bas).
local function specRow(parent: Instance, key: string, value: string)
    local frame = make("Frame", {
        Name = "Fiche",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = nextOrder(),
    }, parent)
    make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, frame)
    Components.text(frame, key, "Body", {
        Size = UDim2.new(0.4, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = color("TextMuted"),
    })
    Components.text(frame, value, "Value", {
        Name = "Valeur",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0.6, -8, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Right,
    }).TextSize =
        UITheme.text(13)
    make("Frame", {
        BackgroundColor3 = Color3.fromRGB(31, 34, 38),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 1),
    }, frame)
end

-- ======================== Collection ========================

local function cardFor(parent: Instance, vehicle: any, cardWidth: number, thumbHeight: number)
    local definition = VehicleDefinitions.get(vehicle.ModelId)
    local entry = VehicleCatalog.forDefinition(vehicle.ModelId)
    local isSelected = vehicle.Id == selected
    local item = make("TextButton", {
        Name = "Carte_" .. tostring(vehicle.Id),
        Text = "",
        AutoButtonColor = false,
        BackgroundColor3 = color("Surface1"),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(cardWidth, thumbHeight + CARD_INFO),
        LayoutOrder = nextOrder(),
        Selectable = true,
        ClipsDescendants = true,
    }, parent)
    corner(item, Tokens.Radius.Card)
    local edge = make("UIStroke", {
        Color = if isSelected then color("Amber") else color("Line"),
        Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, item)
    item.SelectionGained:Connect(function()
        edge.Color = color("Amber")
        edge.Thickness = Tokens.FocusStroke
    end)
    item.SelectionLost:Connect(function()
        edge.Color = if vehicle.Id == selected then color("Amber") else color("Line")
        edge.Thickness = 1
    end)
    item.SelectionImageObject = make("Frame", { BackgroundTransparency = 1 }, nil)
    -- Vignette 16:9 : dégradé de la maquette et ViewportFrame fixe en vue 3/4.
    local thumb = make("Frame", {
        Name = "Vignette",
        Size = UDim2.new(1, 0, 0, thumbHeight),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 2,
    }, item)
    make("UIGradient", {
        Color = ColorSequence.new(Color3.fromRGB(38, 42, 48), Color3.fromRGB(21, 23, 26)),
        Rotation = 90,
    }, thumb)
    VehiclePreview.thumbnail(thumb, vehicle.ModelId, vehicle.Cosmetics)
    local storage = (vehicle.Storage or {}).State or "Stored"
    local storageLabel = Components.text(thumb, Tokens.upper(tr(GarageView.StorageLabels[storage] or "?")), "Label", {
        Name = "Rangement",
        Position = UDim2.fromOffset(10, 10),
        BackgroundTransparency = 0.2,
        TextColor3 = color(GarageView.StorageTokens[storage] or "TextMuted"),
        ZIndex = 4,
    })
    storageLabel.BackgroundColor3 = color("BgBase")
    storageLabel.TextSize = UITheme.text(11)
    make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, storageLabel)
    corner(storageLabel, 2)
    local info = make("Frame", {
        Name = "Infos",
        Position = UDim2.fromOffset(0, thumbHeight),
        Size = UDim2.new(1, 0, 0, CARD_INFO),
        BackgroundTransparency = 1,
    }, item)
    padding(info, 14, 10)
    vlist(info, 3)
    local nameLabel = Components.text(info, vehicle.DisplayName, "H1", {
        Name = "Nom",
        Size = UDim2.new(1, 0, 0, 28),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 1,
    })
    nameLabel.TextSize = UITheme.text(22)
    local drive = if definition then GarageView.driveLine(definition) else nil
    local line = Components.text(
        info,
        if drive
            then string.format(
                "%s · %s · %s · %s",
                tr(GarageView.category(definition, entry)),
                tr(drive[1]),
                tr(drive[2]),
                tr(drive[3])
            )
            else tr(GarageView.category(definition, entry)),
        "Body",
        {
            Name = "Motorisation",
            Size = UDim2.new(1, 0, 0, 34),
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextColor3 = Color3.fromRGB(201, 198, 191),
            LayoutOrder = 2,
        }
    )
    line.TextSize = UITheme.text(13)
    local tags = make("Frame", {
        Name = "Etiquettes",
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        LayoutOrder = 3,
    }, info)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, tags)
    if vehicle.Untransferable then
        tag(tags, tr("incessible"))
    end
    if vehicle.Synthetic then
        tag(tags, tr("essai synthétique"))
    end
    if vehicle.Reserved then
        tag(tags, tr("réservé"))
    end
    item.Activated:Connect(function()
        selected = vehicle.Id
        draftTuning = {}
        draftCosmetics = nil
        tab = "Véhicule"
        VehiclePreview.reset()
        render()
    end)
end

local function renderCollection()
    local view = collectionView
    clearChildren(view)
    order = 0
    local width = Components.logicalSize(view).X - 2 * 28
    local head = make("Frame", {
        Name = "Entete",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = nextOrder(),
    }, view)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 12),
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, head)
    Components.text(head, tr("Collection"), "H1", { LayoutOrder = 1 })
    Components.text(head, tr("%d véhicule(s)", state.TotalVehicles or 0), "Body", {
        LayoutOrder = 2,
        TextColor3 = color("TextMuted"),
    })

    local starter = state.Starter or {}
    if starter.Available and starter.State ~= "Chosen" then
        local box = card(view, Tokens.Space[2], "VehiculeDeDepart")
        textLine(box, tr("Véhicule de départ"), "Label", "TextMuted")
        textLine(box, tr("Choix DÉFINITIF : un seul exemplaire gratuit, incessible."), "Body")
        local choices = wrapRow(box)
        for _, modelId in starter.Candidates or {} do
            local definition = VehicleDefinitions.get(modelId)
            local label = if definition then definition.DisplayName else modelId
            button(choices, label, "Secondary", function()
                confirmThen(tr("Choisir %s comme véhicule de départ ? Ce choix est définitif.", label), function()
                    send("ChooseStarter", { ModelId = modelId })
                end)
            end, nil, nil, Tokens.PrimaryButtonHeight, "Depart_" .. modelId)
        end
    elseif starter.State == "Chosen" then
        textLine(view, tr("Choisi : %s (exemplaire incessible).", tostring(starter.ModelId)), "Body", "TextMuted")
    end

    local gap = 16
    local columns, cardWidth = GarageView.cardColumns(math.max(width, 240), compact(), gap)
    local thumbHeight = math.floor(cardWidth * 9 / 16)
    local grid = make("Frame", {
        Name = "Grille",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = nextOrder(),
    }, view)
    make("UIGridLayout", {
        CellSize = UDim2.fromOffset(cardWidth, thumbHeight + CARD_INFO),
        CellPadding = UDim2.fromOffset(gap, gap),
        SortOrder = Enum.SortOrder.LayoutOrder,
        FillDirectionMaxCells = columns,
    }, grid)
    grid:SetAttribute("AWColumns", columns)
    for _, vehicle in state.Vehicles or {} do
        cardFor(grid, vehicle, cardWidth, thumbHeight)
    end
    if #(state.Vehicles or {}) == 0 then
        notice(view, "Neutral", tr("Aucun véhicule dans la collection."))
    end
    if (state.Pages or 1) > 1 then
        local pages = wrapRow(view)
        button(pages, tr("Page précédente"), "Secondary", function()
            send("CollectionPage", { Page = (state.Page or 1) - 1 }, true)
        end, (state.Page or 1) > 1, nil, nil, "PagePrecedente")
        Components.text(pages, tr("Page %d / %d", state.Page or 1, state.Pages), "Value", {
            LayoutOrder = nextOrder(),
            TextColor3 = color("TextMuted"),
        })
        button(pages, tr("Page suivante"), "Secondary", function()
            send("CollectionPage", { Page = (state.Page or 1) + 1 }, true)
        end, (state.Page or 1) < state.Pages, nil, nil, "PageSuivante")
    end
end

-- ======================== Panneau latéral ========================

local function blockedNotice()
    if not GarageView.inGarage(state.Context) then
        notice(
            body,
            "Warn",
            tr(
                "Consultation seule : préparation, enregistrement et sortie exigent d'être dans une propriété ou un garage public."
            )
        )
    end
end

local function stateCell(parent: Instance, key: string, value: string)
    local cell = make("Frame", {
        Name = "Etat",
        BackgroundColor3 = color("Surface1"),
        BorderSizePixel = 0,
    }, parent)
    corner(cell, Tokens.Radius.Button)
    stroke(cell)
    padding(cell, 12, 8)
    vlist(cell, 2)
    Components.text(cell, Tokens.upper(key), "Label", { TextColor3 = color("TextMuted"), LayoutOrder = 1 })
    local valueLabel = Components.text(cell, value, "Value", { Name = "Valeur", LayoutOrder = 2 })
    valueLabel.TextSize = UITheme.text(18)
end

local function renderVehicle()
    local vehicle = current()
    if vehicle == nil then
        textLine(body, tr("Sélectionnez un véhicule dans la collection."))
        return
    end
    blockedNotice()
    local definition = VehicleDefinitions.get(vehicle.ModelId)
    local entry = VehicleCatalog.forDefinition(vehicle.ModelId)
    local storage = vehicle.Storage or {}
    local cells = make("Frame", {
        Name = "EtatVehicule",
        Size = UDim2.new(1, 0, 0, 2 * 58 + 8),
        BackgroundTransparency = 1,
        LayoutOrder = nextOrder(),
    }, body)
    make("UIGridLayout", {
        CellSize = UDim2.new(0.5, -4, 0, 58),
        CellPadding = UDim2.fromOffset(8, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, cells)
    stateCell(cells, tr("État"), tr(GarageView.StorageLabels[storage.State] or "?"))
    stateCell(cells, tr("Kilométrage"), decimal(vehicle.OdometerKm or 0, 1) .. " km")
    stateCell(cells, tr("Dégâts"), percent(vehicle.DamageLevel))
    stateCell(cells, tr("Réserve"), percent(vehicle.Energy))
    textLine(
        body,
        tr(
            "Origine : %s%s%s",
            tostring(vehicle.Origin),
            if vehicle.Untransferable then tr(" • incessible") else "",
            if vehicle.Synthetic then tr(" • donnée synthétique de développement") else ""
        ),
        "Body",
        "TextMuted"
    )
    textLine(body, tr("Moteur : %s", percent(vehicle.Engine)), "Body", "TextMuted")
    if definition then
        local sheet = make("Frame", {
            Name = "FicheTechnique",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = nextOrder(),
        }, body)
        vlist(sheet, 0)
        for _, spec in GarageView.specs(definition, entry) do
            specRow(sheet, tr(spec.Key), if spec.Unit == "tr" then tr(spec.Value) else spec.Value)
        end
    end
    local parts = {}
    for slot, partId in vehicle.Parts or {} do
        local part = PartCatalog.get(partId)
        table.insert(parts, tr("%s : %s", tr(SLOT_LABELS[slot] or slot), if part then tr(part.Label) else partId))
    end
    textLine(
        body,
        tr("Pièces installées : %s", if #parts > 0 then table.concat(parts, ", ") else tr("série")),
        "Body",
        "Text"
    )
    -- Places d'exposition de la propriété (choix de la place).
    local property = contextProperty()
    if property and storage.State ~= "Out" then
        textLine(body, tr("Places d'exposition"), "Label", "TextMuted")
        local slots = wrapRow(body)
        for slot = 1, property.Capacity or 0 do
            local occupant = (property.Slots or {})[tostring(slot)]
            chip(slots, tr("Place %d", slot), occupant == vehicle.Id, function()
                send("Display", { VehicleId = vehicle.Id, PropertyId = property.Id, Slot = slot })
            end, occupant == nil, if occupant then tr("Place occupée") else nil)
        end
    end
    local _, note = GarageView.availability(definition, entry)
    if note then
        notice(body, "Warn", tr(note))
    end
    -- Raisons des actions indisponibles (la manette n'a pas d'infobulle).
    local actions = GarageView.vehicleActions(vehicle, state, property)
    local reasons = {}
    for _, spec in { { "TakeOut", "Sortir" }, { "Display", "Exposer" }, { "Store", "Ranger" } } do
        local action = actions[spec[1]]
        if not action.Enabled and action.Reason then
            table.insert(reasons, tr("%s : %s", tr(spec[2]), tr(action.Reason)))
        end
    end
    if #reasons > 0 then
        textLine(body, table.concat(reasons, "\n"), "Body", "TextMuted").Name = "RaisonsActions"
    end
end

local function renderProperties()
    local properties = state.Properties or {}
    textLine(body, tr("Propriétés (%d / %d)", #properties, PropertyCatalog.MaxOwned), "H2")
    if #properties == 0 then
        notice(body, "Neutral", tr("Aucune propriété."))
    end
    for _, property in properties do
        local used = 0
        for _ in property.Slots or {} do
            used += 1
        end
        local box = card(body, Tokens.Space[1] + 2, "Propriete_" .. tostring(property.Id))
        local title = textLine(box, property.Label, "H1")
        title.TextSize = UITheme.text(18)
        local category = PropertyCatalog.Categories[property.Category]
        textLine(
            box,
            tr("%s · %s", if category then tr(category.Label) else tostring(property.Category), tr(property.Zone)),
            "Body",
            "TextMuted"
        )
        textLine(
            box,
            tr("%d / %d place(s) exposée(s) · entrée : %s", used, property.Capacity, property.EntranceLabel)
        )
        local flags = wrapRow(box, 4)
        if not property.Sellable then
            tag(flags, tr("invendable"))
        end
        if property.Synthetic then
            tag(flags, tr("synthétique"))
        end
        local actions = wrapRow(box)
        button(actions, tr("Agrandir le garage"), "Secondary", function()
            send("UpgradeGarage", { PropertyId = property.Id })
        end, nil, nil, nil, "Agrandir")
        button(actions, tr("Revendre"), "Revoke", function()
            confirmThen(tr("Revendre %s ? L'opération est définitive.", property.Label), function()
                send("SellProperty", { PropertyId = property.Id })
            end)
        end, property.Sellable, tr("Propriété invendable"), nil, "Revendre")
    end
    local context = state.Context or {}
    if context.Kind == "Property" or context.Kind == "Visit" then
        local exit = wrapRow(body)
        button(exit, tr("Quitter la propriété"), "Secondary", function()
            send("Exit", {})
        end, nil, nil, Tokens.PrimaryButtonHeight, "Quitter")
    end
    if entranceOffer then
        textLine(body, tr("Entrée : propriétés accessibles ici"), "Label", "TextMuted")
        if #entranceOffer.Options == 0 then
            notice(body, "Neutral", tr("Aucune propriété accessible à cette entrée."))
        end
        for _, option in entranceOffer.Options do
            local box = card(body, Tokens.Space[2], "Entree")
            textLine(box, tr("%s (%s)", option.Label, option.OwnerName), "Body")
            local row = wrapRow(box)
            button(row, tr("Entrer"), "Primary", function()
                send("Enter", { OwnerUserId = option.OwnerUserId, PropertyId = option.PropertyId })
                entranceOffer = nil
            end, nil, nil, nil, "Entrer")
        end
    end
end

local function rangeRow(parent: Instance, key: string, range: any, saved: number, editable: boolean, refresh: () -> ())
    local value = draftTuning[key] or saved
    local frame = make("Frame", {
        Name = "Reglage_" .. key,
        Size = UDim2.new(1, 0, 0, 78),
        BackgroundTransparency = 1,
        LayoutOrder = nextOrder(),
    }, parent)
    Components.text(frame, tr(range.Label), "Body", {
        Size = UDim2.new(1, -110, 0, 22),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }).TextSize =
        UITheme.text(15)
    local valueLabel = Components.text(frame, "", "Value", {
        Name = "Valeur",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.fromOffset(110, 22),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    -- Glissière : piste, remplissage ambre, curseur ; − et + pour la manette et le clavier.
    local track = make("TextButton", {
        Name = "Piste",
        Text = "",
        AutoButtonColor = false,
        Selectable = false, -- pointeur seulement : la manette et le clavier passent par − et +
        Position = UDim2.fromOffset(40, 34),
        Size = UDim2.new(1, -80, 0, 20),
        BackgroundTransparency = 1,
    }, frame)
    track:SetAttribute("AWPointerOnly", true)
    local rail = make("Frame", {
        BackgroundColor3 = Color3.fromRGB(34, 37, 42),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.new(1, 0, 0, 6),
    }, track)
    corner(rail, 3)
    local fill = make("Frame", {
        Name = "Remplissage",
        BackgroundColor3 = color("Amber"),
        BorderSizePixel = 0,
        Size = UDim2.fromScale(0, 1),
    }, rail)
    corner(fill, 3)
    local knob = make("Frame", {
        Name = "Curseur",
        BackgroundColor3 = color("Text"),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(14, 14),
    }, track)
    corner(knob, 7)
    local labels = make("Frame", {
        Position = UDim2.fromOffset(0, 58),
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
    }, frame)
    local marks: { { Text: string, Align: Enum.TextXAlignment } } = {
        { Text = GarageView.formatTuning(range, range.Min), Align = Enum.TextXAlignment.Left },
        {
            Text = tr("origine %s", GarageView.formatTuning(range, range.Default)),
            Align = Enum.TextXAlignment.Center,
        },
        { Text = GarageView.formatTuning(range, range.Max), Align = Enum.TextXAlignment.Right },
    }
    for index, mark in marks do
        local label = Components.text(labels, mark.Text, "Value", {
            Size = UDim2.fromScale(1, 1),
            TextXAlignment = mark.Align,
            TextColor3 = Color3.fromRGB(142, 140, 134),
            Name = "Repere" .. index,
        })
        label.TextSize = UITheme.text(11)
    end
    make("Frame", {
        BackgroundColor3 = Color3.fromRGB(31, 34, 38),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 1),
    }, frame)
    local function show()
        local ratio = if range.Max > range.Min then (value - range.Min) / (range.Max - range.Min) else 0
        fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
        knob.Position = UDim2.fromScale(math.clamp(ratio, 0, 1), 0.5)
        valueLabel.Text = GarageView.formatTuning(range, value)
        valueLabel.TextColor3 = if math.abs(value - saved) > 1e-9 then color("Amber") else color("Text")
        frame:SetAttribute("AWValue", value)
    end
    local function set(newValue: number)
        value = GarageView.snap(range, newValue)
        if math.abs(value - saved) > 1e-9 then
            draftTuning[key] = value
        else
            draftTuning[key] = nil
        end
        show()
        refresh()
    end
    for index, delta in { -1, 1 } do
        local nudge = button(
            frame,
            if delta < 0 then "-" else "+",
            "Secondary",
            function()
                set(value + delta * GarageView.tuningStep(range))
            end,
            editable,
            if editable then nil else tr("Exige une propriété ou un garage public"),
            Tokens.MinTarget,
            if delta < 0 then "Moins" else "Plus"
        )
        nudge.AutomaticSize = Enum.AutomaticSize.None
        nudge.Size = UDim2.fromOffset(32, 32)
        nudge.AnchorPoint = Vector2.new(if index == 1 then 0 else 1, 0)
        nudge.Position = if index == 1 then UDim2.fromOffset(0, 28) else UDim2.new(1, 0, 0, 28)
        local pad = nudge:FindFirstChildOfClass("UIPadding")
        if pad then
            pad:Destroy()
        end
    end
    if editable then
        local dragging = false
        local function fromX(x: number)
            local ratio = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
            set(range.Min + ratio * (range.Max - range.Min))
        end
        track.InputBegan:Connect(function(input: InputObject)
            if
                input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                dragging = true
                fromX(input.Position.X)
            end
        end)
        track.InputChanged:Connect(function(input: InputObject)
            if
                dragging
                and (
                    input.UserInputType == Enum.UserInputType.MouseMovement
                    or input.UserInputType == Enum.UserInputType.Touch
                )
            then
                fromX(input.Position.X)
            end
        end)
        track.InputEnded:Connect(function(input: InputObject)
            if
                input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                dragging = false
            end
        end)
    end
    show()
end

local function refreshDraft()
    local vehicle = current()
    local has = GarageView.hasDraft(vehicle, draftTuning, draftCosmetics)
    draftBadge.Visible = has
    panel:SetAttribute("AWDraft", has)
    if prepFooter then
        for _, child in prepFooter:GetDescendants() do
            if child:IsA("TextButton") then
                local caps = capabilities()
                local allowed = has and (child.Name ~= "AppliquerBrouillon" or (caps.EditTuning or caps.EditCosmetics))
                child.Active = allowed == true
                child.AutoButtonColor = false
                child.BackgroundTransparency = if allowed
                    then (if child.Name == "AnnulerBrouillon" then 1 else 0)
                    else Tokens.DisabledTransparency
                child.TextTransparency = if allowed then 0 else Tokens.DisabledTransparency
            end
        end
    end
end

local function renderSettings(vehicle: any, base: any)
    local caps = capabilities()
    local ranges = TuningRules.ranges(base, vehicle.Parts or {})
    local keys = {}
    for key in ranges do
        table.insert(keys, key)
    end
    table.sort(keys, function(a, b)
        return tr(ranges[a].Label) < tr(ranges[b].Label)
    end)
    local warning: Frame? = nil
    local function check()
        refreshDraft()
        -- Combinaison vérifiée par les VRAIES règles (le serveur revalide) : refus affiché avant l'envoi.
        local merged = table.clone(vehicle.Tuning or {})
        for key, value in draftTuning do
            merged[key] = value
        end
        local ok, errors = TuningRules.validate(base, merged, vehicle.Parts or {})
        if warning then
            warning:Destroy()
            warning = nil
        end
        if not ok then
            local texts = {}
            for _, err in errors do
                table.insert(texts, Text.text(err))
            end
            notice(body, "Danger", tr("Combinaison refusée par les règles du jeu : %s", table.concat(texts, " ; ")))
            warning = body:FindFirstChild("EncadreDanger") :: Frame?
        end
    end
    for _, key in keys do
        local range = ranges[key]
        local saved = (vehicle.Tuning or {})[key] or range.Default
        rangeRow(body, key, range, saved, caps.EditTuning == true, check)
    end
    check()
end

local function partEffects(part: any): string
    local list = {}
    local keys = {}
    for key in part.Effects or {} do
        table.insert(keys, key)
    end
    table.sort(keys)
    for _, key in keys do
        local value = part.Effects[key]
        local label = tr(EFFECT_LABELS[key] or key)
        if key == "PreloadNm" then
            table.insert(list, string.format("%s %d", label, value))
        else
            table.insert(list, string.format("%s ×%s", label, (string.gsub(string.format("%.2f", value), "%.", ","))))
        end
    end
    return table.concat(list, " · ")
end

local function renderParts(vehicle: any, base: any)
    local caps = capabilities()
    for _, slot in PartCatalog.Slots do
        local installed = (vehicle.Parts or {})[slot]
        local box = make("Frame", {
            Name = "Emplacement_" .. slot,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = nextOrder(),
        }, body)
        padding(box, 0, 8)
        vlist(box, 6)
        textLine(box, tr(SLOT_LABELS[slot] or slot), "Label", "TextMuted")
        local row = wrapRow(box)
        local swapReason = if caps.SwapParts == true then nil else tr("Exige un garage public")
        chip(row, tr("Série"), installed == nil, function()
            send("SetPart", { VehicleId = vehicle.Id, Slot = slot, PartId = nil })
        end, caps.SwapParts == true and installed ~= nil, swapReason)
        local compatibleCount = 0
        for _, part in PartCatalog.Parts do
            if part.Slot == slot then
                local compatible = PartCatalog.compatible(part, base)
                local owned = (state.Parts or {})[part.Id]
                local available = owned ~= nil and owned.Detached > 0
                if compatible then
                    compatibleCount += 1
                end
                local reason = if not compatible
                    then tr("Incompatible avec ce modèle")
                    elseif installed == part.Id then nil
                    elseif not available then tr("Pièce non possédée")
                    else swapReason
                chip(
                    row,
                    string.format("%s (%d)", tr(part.Label), if owned then owned.Detached else 0),
                    installed == part.Id,
                    function()
                        send("SetPart", { VehicleId = vehicle.Id, Slot = slot, PartId = part.Id })
                    end,
                    compatible and installed ~= part.Id and available and caps.SwapParts == true,
                    reason
                )
            end
        end
        local installedPart = if installed then PartCatalog.get(installed) else nil
        if installedPart then
            textLine(box, partEffects(installedPart), "Body", "TextMuted")
        elseif compatibleCount == 0 then
            textLine(box, tr("Incompatible avec ce modèle"), "Body", "TextMuted")
        end
    end
    textLine(
        body,
        tr(
            "Pièce d'origine = emplacement vide. Une pièce est posée ou retirée dès la demande (le serveur confirme)."
        ),
        "Body",
        "TextMuted"
    )
end

local function renderLook(vehicle: any, base: any)
    local caps = capabilities()
    local editable = caps.EditCosmetics == true
    local reason = if editable then nil else tr("Exige une propriété ou un garage public")
    local cosmetics = draftCosmetics or table.clone(vehicle.Cosmetics or CosmeticCatalog.defaults(base))
    cosmetics.BodyKit = table.clone(cosmetics.BodyKit or {})
    cosmetics.Accessories = table.clone(cosmetics.Accessories or {})
    local function change(fn: (any) -> ())
        local copy = table.clone(cosmetics)
        copy.BodyKit = table.clone(cosmetics.BodyKit)
        copy.Accessories = table.clone(cosmetics.Accessories)
        fn(copy)
        draftCosmetics = copy
        render()
    end
    local palettes: { { Key: string, Label: string, Size: number } } = {
        { Key = "BodyColor", Label = "Caisse", Size = 36 },
        { Key = "AccentColor", Label = "Accent", Size = 28 },
    }
    for _, palette in palettes do
        local swatch = CosmeticCatalog.color(cosmetics[palette.Key])
        textLine(
            body,
            tr("%s · %s", tr(palette.Label), if swatch then tr(swatch.Label) else tostring(cosmetics[palette.Key])),
            "Body",
            "TextMuted"
        )
        local row = wrapRow(body, 6)
        for _, item in CosmeticCatalog.Colors do
            local on = cosmetics[palette.Key] == item.Id
            local sw = make("TextButton", {
                Name = "Teinte_" .. palette.Key .. "_" .. item.Id,
                Text = "",
                AutoButtonColor = false,
                BackgroundColor3 = Color3.fromRGB(item.Rgb[1], item.Rgb[2], item.Rgb[3]),
                Size = UDim2.fromOffset(palette.Size, palette.Size),
                LayoutOrder = nextOrder(),
                Active = editable,
                Selectable = editable,
            }, row)
            corner(sw, Tokens.Radius.Chip)
            make("UIStroke", {
                Color = if on then color("Amber") else Color3.fromRGB(0, 0, 0),
                Transparency = if on then 0 else 1,
                Thickness = 2,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }, sw)
            if on then
                sw:SetAttribute("AWSelected", true)
            end
            if editable then
                sw.Activated:Connect(function()
                    change(function(c)
                        c[palette.Key] = item.Id
                    end)
                end)
            end
        end
    end
    local function optionRow(title: string, options: { { string } }, isOn: (string) -> boolean, pick: (string) -> ())
        local frame = make("Frame", {
            Name = "Option",
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = nextOrder(),
        }, body)
        padding(frame, 0, 4)
        vlist(frame, 4)
        textLine(frame, title, "Body", "TextMuted")
        local row = wrapRow(frame)
        for _, option in options do
            chip(row, option[2], isOn(option[1]), function()
                pick(option[1])
            end, editable, reason)
        end
    end
    local finishes = {}
    for id, entry in CosmeticCatalog.Finishes :: { [string]: any } do
        table.insert(finishes, { id, tr(entry.Label) })
    end
    table.sort(finishes, function(a, b)
        return a[2] < b[2]
    end)
    optionRow(tr("Finition"), finishes, function(id)
        return cosmetics.Finish == id
    end, function(id)
        change(function(c)
            c.Finish = id
        end)
    end)
    local wheels = {}
    for id, label in CosmeticCatalog.Wheels :: { [string]: string } do
        table.insert(wheels, { id, tr(label) })
    end
    table.sort(wheels, function(a, b)
        return a[2] < b[2]
    end)
    optionRow(tr("Jantes"), wheels, function(id)
        return cosmetics.Wheels == id
    end, function(id)
        change(function(c)
            c.Wheels = id
        end)
    end)
    for _, slotSpec in KIT_SLOTS do
        local options = {}
        for _, id in (CosmeticCatalog.BodyKitSlots :: any)[slotSpec[1]] or {} do
            table.insert(options, { id, tr(KIT_LABELS[id] or id) })
        end
        optionRow(tr(slotSpec[2]), options, function(id)
            return (cosmetics.BodyKit[slotSpec[1]] or "Stock") == id
        end, function(id)
            change(function(c)
                c.BodyKit[slotSpec[1]] = id
            end)
        end)
    end
    local accessories = {}
    for id, label in CosmeticCatalog.Accessories :: { [string]: string } do
        table.insert(accessories, { id, tr(label) })
    end
    table.sort(accessories, function(a, b)
        return a[2] < b[2]
    end)
    optionRow(tr("Accessoires (2 au plus)"), accessories, function(id)
        return table.find(cosmetics.Accessories, id) ~= nil
    end, function(id)
        change(function(c)
            c.Accessories = GarageView.toggleAccessory(c.Accessories, id, CosmeticCatalog.MaxAccessories)
        end)
    end)
    optionRow(tr("Inscription"), { { "on", tr("Affichée") }, { "off", tr("Masquée") } }, function(id)
        return (id == "on") == (cosmetics.ShowLabel == true)
    end, function(id)
        change(function(c)
            c.ShowLabel = id == "on"
        end)
    end)
    textLine(
        body,
        tr("Aucune incidence physique. Rien n'est enregistré avant « Appliquer le brouillon »."),
        "Body",
        "TextMuted"
    )
end

local function renderPreparation()
    local vehicle = current()
    if vehicle == nil then
        textLine(body, tr("Sélectionnez un véhicule dans la collection."))
        return
    end
    local base = VehicleDefinitions.get(vehicle.ModelId)
    if base == nil then
        return
    end
    blockedNotice()
    if prepSub == "Réglages" then
        renderSettings(vehicle, base)
    elseif prepSub == "Pièces" then
        renderParts(vehicle, base)
    else
        renderLook(vehicle, base)
    end
end

-- Envoi du brouillon : réglages puis esthétique, chacun confirmé ou refusé par le serveur.
local function applyDraft()
    local vehicle = current()
    if vehicle == nil or busy then
        return
    end
    local caps = capabilities()
    if next(draftTuning) ~= nil and caps.EditTuning then
        local tuning = table.clone(vehicle.Tuning or {})
        for key, value in draftTuning do
            tuning[key] = value
        end
        send("SetTuning", { VehicleId = vehicle.Id, Tuning = tuning })
        if status.Kind == "Rejected" or status.Kind == "Offline" then
            return
        end
    end
    vehicle = current()
    if draftCosmetics and caps.EditCosmetics and vehicle then
        send("SetCosmetics", { VehicleId = vehicle.Id, Cosmetics = draftCosmetics })
    end
end

local function renderConfigurations()
    local vehicle = current()
    if vehicle == nil then
        textLine(body, tr("Sélectionnez un véhicule dans la collection."))
        return
    end
    blockedNotice()
    local caps = capabilities()
    local inGarage = GarageView.inGarage(state.Context)
    textLine(
        body,
        tr("Une configuration est un jeu de réglages : elle ne crée aucune pièce. 5 au plus par exemplaire."),
        "Body",
        "TextMuted"
    )
    local box = make("TextBox", {
        Name = "NomConfiguration",
        Size = UDim2.new(1, 0, 0, Tokens.PrimaryButtonHeight),
        BackgroundColor3 = color("Surface2"),
        TextColor3 = color("Text"),
        PlaceholderText = tr("Nom de la configuration (24 caractères)"),
        PlaceholderColor3 = color("TextMuted"),
        Text = configName,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = nextOrder(),
    }, body)
    box.FontFace = UITheme.face("Body")
    box.TextSize = UITheme.text(15)
    corner(box, Tokens.Radius.Button)
    stroke(box)
    make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, box)
    box:GetPropertyChangedSignal("Text"):Connect(function()
        if #box.Text > 24 then
            box.Text = string.sub(box.Text, 1, 24)
        end
        configName = box.Text
    end)
    local configurations = vehicle.Configurations or {}
    for index = 1, GarageView.MaxConfigurations do
        local configuration = configurations[index]
        local item = card(body, Tokens.Space[2], "Configuration" .. index)
        textLine(
            item,
            if configuration
                then string.format(
                    "%d. %s%s",
                    index,
                    configuration.Name,
                    if configuration.Realizable then "" else tr(" (pièces à échanger)")
                )
                else tr("%d. (vide)", index),
            "Body",
            if configuration then "Text" else "TextMuted"
        ).TextSize =
            UITheme.text(15)
        local actions = GarageView.configActions(index, configurations, inGarage, caps)
        local row = wrapRow(item)
        button(row, tr("Enregistrer ici"), "Secondary", function()
            local name = if configName ~= "" then configName else tr("Configuration %d", index)
            send("SaveConfig", { VehicleId = vehicle.Id, Index = index, Name = string.sub(name, 1, 24) })
        end, actions.Save.Enabled, if actions.Save.Reason then tr(actions.Save.Reason) else nil, nil, "Enregistrer")
        button(row, tr("Appliquer"), "Secondary", function()
            send("ApplyConfig", { VehicleId = vehicle.Id, Index = index })
        end, actions.Apply.Enabled, if actions.Apply.Reason then tr(actions.Apply.Reason) else nil, nil, "Appliquer")
        button(row, tr("Supprimer"), "Revoke", function()
            confirmThen(tr("Supprimer la configuration %d ?", index), function()
                send("DeleteConfig", { VehicleId = vehicle.Id, Index = index })
            end)
        end, actions.Delete.Enabled, if actions.Delete.Reason then tr(actions.Delete.Reason) else nil, nil, "Supprimer")
    end
end

local function renderInvitations()
    textLine(
        body,
        tr(
            "Invitations séparées : visite de la propriété, ou visite avec droit de conduire. Révocables à tout moment."
        ),
        "Body",
        "TextMuted"
    )
    local properties = state.Properties or {}
    local target = properties[1]
    if target == nil then
        notice(body, "Neutral", tr("Aucune propriété : aucune invitation possible."))
    else
        textLine(body, tr("Inviter un joueur présent sur ce serveur"), "Label", "TextMuted")
        textLine(
            body,
            tr("Propriété : %s · durée : 1 h · aucune modification permise aux visiteurs", target.Label),
            "Body",
            "TextMuted"
        )
        local others = 0
        for _, other in Players:GetPlayers() do
            if other ~= player then
                others += 1
                local item = card(body, Tokens.Space[2], "Inviter_" .. other.UserId)
                textLine(item, other.DisplayName, "Body").FontFace = UITheme.face("Button")
                local row = wrapRow(item)
                local function invite(drive: boolean)
                    send("Invite", {
                        PropertyId = target.Id,
                        GuestUserId = other.UserId,
                        Visit = true,
                        Drive = drive,
                        DurationS = 3600,
                    })
                end
                button(row, tr("Visite"), "Secondary", function()
                    invite(false)
                end, nil, nil, nil, "InviterVisite")
                button(row, tr("Visite + conduite"), "Secondary", function()
                    invite(true)
                end, nil, nil, nil, "InviterConduite")
            end
        end
        if others == 0 then
            notice(body, "Neutral", tr("Aucun autre joueur sur ce serveur."))
        end
    end
    textLine(body, tr("Invitations actives"), "Label", "TextMuted")
    local any = false
    for _, invitation in state.Invitations or {} do
        any = true
        local item = card(body, Tokens.Space[1], "Invitation_" .. tostring(invitation.Id))
        local who = textLine(item, invitation.GuestName or tr("joueur %s", tostring(invitation.GuestUserId)), "Body")
        who.FontFace = UITheme.face("Button")
        who.TextSize = UITheme.text(15)
        textLine(
            item,
            string.format(
                "%s · %s",
                if invitation.Drive then tr("Visite + droit de conduire") else tr("Visite de la propriété"),
                if invitation.Active
                    then tr("expire dans %d min", math.max(0, (invitation.ExpiresAt - (state.Now or 0)) // 60))
                    else tr("inactive")
            ),
            "Body",
            "TextMuted"
        )
        local row = wrapRow(item)
        button(row, tr("Révoquer"), "Revoke", function()
            send("RevokeInvite", { InvitationId = invitation.Id })
        end, invitation.Active, tr("Invitation inactive"), nil, "Revoquer")
    end
    if not any then
        notice(body, "Neutral", tr("Aucune invitation active."))
    end
end

-- ======================== Zone 3D ========================

local function updateCamLabel()
    if camLabel then
        camLabel.Text = tr(
            "Caméra orbitale · %d° · zoom %s",
            math.floor(VehiclePreview.angle() + 0.5) % 360,
            (string.gsub(string.format("%.1f", VehiclePreview.zoom()), "%.", ","))
        )
    end
end

local function renderStage()
    local vehicle = current()
    local definition = if vehicle then VehicleDefinitions.get(vehicle.ModelId) else nil
    local entry = if vehicle then VehicleCatalog.forDefinition(vehicle.ModelId) else nil
    stageName.Text = if vehicle then vehicle.DisplayName else ""
    local stageWidth = Components.logicalSize(stage).X
    stageName.TextSize = UITheme.text(if stageWidth < 700 then 28 elseif compact() then 40 else 56)
    local views = stage:FindFirstChild("Vues") :: Frame?
    local camRow = stage:FindFirstChild("Camera") :: Frame?
    if views then
        -- Étroite : vues sous le nom (colonne de gauche) ; large : en haut à droite (maquette).
        local identity = stage:FindFirstChild("Identite")
        local narrow = stageWidth < 560
        views.Parent = if narrow and identity then identity else stage
        views.AnchorPoint = if narrow then Vector2.zero else Vector2.new(1, 0)
        views.Position = if narrow then UDim2.new() else UDim2.new(1, -20, 0, 20)
        views.LayoutOrder = 103
    end
    if camRow then
        camRow.Visible = stageWidth >= 420
    end
    stageCategory.Text = if vehicle then tr(GarageView.category(definition, entry)) else ""
    local badgeText = GarageView.availability(definition, entry)
    stageAvailability.Visible = badgeText ~= nil
    stageAvailability.Text = if badgeText then Tokens.upper(tr(badgeText)) else ""
    -- Barre d'actions (onglet Véhicule) : Sortir, Exposer, Ranger, Préparer.
    clearChildren(actionBar)
    actionBar.Visible = tab == "Véhicule" and vehicle ~= nil
    if vehicle and tab == "Véhicule" then
        local property = contextProperty()
        local actions = GarageView.vehicleActions(vehicle, state, property)
        button(
            actionBar,
            tr("Sortir"),
            "Secondary",
            function()
                send("TakeOut", { VehicleId = vehicle.Id })
            end,
            actions.TakeOut.Enabled,
            if actions.TakeOut.Reason then tr(actions.TakeOut.Reason) else nil,
            Tokens.PrimaryButtonHeight,
            "Sortir"
        )
        button(
            actionBar,
            tr("Exposer"),
            "Secondary",
            function()
                send("Display", { VehicleId = vehicle.Id, PropertyId = property.Id, Slot = actions.Display.Slot })
            end,
            actions.Display.Enabled,
            if actions.Display.Reason then tr(actions.Display.Reason) else nil,
            Tokens.PrimaryButtonHeight,
            "Exposer"
        )
        button(
            actionBar,
            tr("Ranger"),
            "Secondary",
            function()
                if actions.Store.Kind == "Return" then
                    send("Return", {})
                else
                    send("Store", { VehicleId = vehicle.Id })
                end
            end,
            actions.Store.Enabled,
            if actions.Store.Reason then tr(actions.Store.Reason) else nil,
            Tokens.PrimaryButtonHeight,
            "Ranger"
        )
        button(actionBar, tr("Préparer"), "Primary", function()
            tab = "Préparation"
            render()
        end, nil, nil, Tokens.PrimaryButtonHeight, "Preparer")
    end
    for _, view in GarageView.Views do
        local item = viewButtons[view.Id]
        if item then
            local on = not VehiclePreview.spinning()
                and math.abs(((VehiclePreview.angle() - view.Angle + 180) % 360) - 180) < 0.5
            item.BackgroundColor3 = if on then color("Amber") else color("BgBase")
            item.BackgroundTransparency = if on then 0 else 1
            item.TextColor3 = if on then color("TextOnAmber") else color("Text")
        end
    end
    updateCamLabel()
end

-- ======================== Disposition ========================

local function placeStatus()
    if (statusBox :: Frame?) == nil then
        return
    end
    if tab == "Collection" then
        statusBox.Parent = content
        statusBox.AnchorPoint = Vector2.new(0, 1)
        statusBox.Position = UDim2.fromScale(0, 1)
        statusBox.Size = UDim2.new(1, 0, 0, 0)
    else
        statusBox.Parent = side
        statusBox.AnchorPoint = Vector2.new(0, 1)
        statusBox.Position = UDim2.fromScale(0, 1)
        statusBox.Size = UDim2.new(1, 0, 0, 0)
    end
end

-- Panneau latéral à la largeur de l'onglet (maquette §3), zone 3D sur la largeur restante ; disposition compacte sous
-- 1400 px logiques. Collection : pleine largeur.
function layoutPanels()
    if (side :: Frame?) == nil then
        return
    end
    local isCollection = tab == "Collection"
    local sizes = Tokens.Garage.SidePanel
    local pair = if tab == "Véhicule"
        then sizes.Vehicle
        elseif tab == "Préparation" then sizes.Preparation
        else sizes.Other
    local width = if compact() then pair[2] else pair[1]
    collectionView.Visible = isCollection
    stage.Visible = not isCollection
    side.Visible = not isCollection
    side.Size = UDim2.new(0, width, 1, 0)
    stage.Size = UDim2.new(1, -width, 1, 0)
    placeStatus()
    if not isCollection and stageName then
        task.defer(renderStage)
    end
    local statusHeight = if statusBox.Visible then statusBox.AbsoluteSize.Y else 0
    local topHeight = if sideTop.Visible then sideTop.AbsoluteSize.Y else 0
    local footHeight = if prepFooter.Visible then prepFooter.AbsoluteSize.Y else 0
    body.Position = UDim2.fromOffset(0, topHeight)
    body.Size = UDim2.new(1, 0, 1, -(topHeight + footHeight + statusHeight))
    prepFooter.Position = UDim2.new(0, 0, 1, -statusHeight)
    collectionView.Size = UDim2.new(1, 0, 1, -(if isCollection then statusHeight else 0))
    panel:SetAttribute("AWSidePanelWidth", if isCollection then 0 else width)
    -- Zone 3D : exemplaire affiché ; teinte du brouillon en Préparation.
    local vehicle = current()
    local cosmetics = if vehicle
            and tab == "Préparation"
            and draftCosmetics
        then draftCosmetics
        elseif vehicle then vehicle.Cosmetics
        else nil
    VehiclePreview.show(if vehicle then vehicle.ModelId else nil, cosmetics)
end

-- Barre d'aide : touches de la maquette selon le dernier périphérique utilisé.
local function renderHints()
    if (hintsRow :: Frame?) == nil then
        return
    end
    clearChildren(hintsRow)
    local pad = string.sub(UserInputService:GetLastInputType().Name, 1, 7) == "Gamepad"
    local list: { { string } } = if pad
        then {
            { tr("Stick droit"), tr("Tourner") },
            { "LB / RB", tr("Onglets") },
            { "A", tr("Valider") },
            { "B", tr("Retour") },
        }
        else {
            { tr("Glisser"), tr("Tourner") },
            { "[ ]", tr("Onglets") },
            { tr("Retour arrière"), tr("Retour") },
            { "P", tr("Fermer") },
        }
    for index, hint in list do
        local holder = make("Frame", {
            Name = "Touche" .. index,
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.XY,
            LayoutOrder = index,
        }, hintsRow)
        make("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 6),
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, holder)
        local key = Components.text(holder, hint[1], "Value", { Name = "Touche", LayoutOrder = 1 })
        key.TextSize = UITheme.text(11)
        make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, key)
        corner(key, 3)
        stroke(key)
        Components.text(holder, hint[2], "Body", {
            Name = "Action",
            LayoutOrder = 2,
            TextColor3 = color("TextMuted"),
        }).TextSize =
            UITheme.text(13)
    end
end

function render()
    if not panel then
        return
    end
    for name, item in tabButtons do
        local on = name == tab
        item.TextColor3 = if on then color("Text") else color("TextMuted")
        local rail = item:FindFirstChild("Filet") :: Frame?
        if rail then
            rail.Visible = on
        end
    end
    contextLabel.Text = tr(GarageView.contextLabel(state and state.Context))
    local keepScroll = if tab == lastRendered.Tab and prepSub == lastRendered.Sub
        then body.CanvasPosition
        else Vector2.zero
    local keepCollection = if tab == lastRendered.Tab then collectionView.CanvasPosition else Vector2.zero
    lastRendered = { Tab = tab, Sub = prepSub }
    clearChildren(body)
    clearChildren(sideTop)
    order = 0
    sideTop.Visible = tab == "Préparation"
    prepFooter.Visible = tab == "Préparation"
    if state == nil or state.Vehicles == nil then
        collectionView.Visible = true
        clearChildren(collectionView)
        textLine(collectionView, Text.text((state and state.State) or "Loading"), "Body", "TextMuted")
        stage.Visible = false
        side.Visible = false
        return
    end
    if tab == "Collection" then
        renderCollection()
    else
        if tab == "Préparation" then
            for _, sub in GarageView.PrepTabs do
                local on = sub == prepSub
                local item = button(sideTop, tr(sub), "Secondary", function()
                    prepSub = sub
                    render()
                end, nil, nil, 40, "SousOnglet_" .. sub)
                item.AutomaticSize = Enum.AutomaticSize.None
                item.Size = UDim2.new(1 / 3, -2, 0, 40)
                item.BackgroundColor3 = if on then color("Surface1") else color("BgBase")
                item.TextColor3 = if on then color("Text") else color("TextMuted")
                item:SetAttribute("AWSelected", on)
            end
        end
        order = 0
        if tab == "Véhicule" then
            renderVehicle()
        elseif tab == "Propriétés" then
            renderProperties()
        elseif tab == "Préparation" then
            renderPreparation()
        elseif tab == "Configurations" then
            renderConfigurations()
        else
            renderInvitations()
        end
        if (state.Pending or 0) > 0 then
            textLine(
                body,
                tr("%d opération(s) en attente de confirmation de sauvegarde.", state.Pending),
                "Body",
                "AmberSoftText"
            )
        end
        renderStage()
    end
    refreshDraft()
    layoutPanels()
    task.defer(function()
        body.CanvasPosition = keepScroll
        collectionView.CanvasPosition = keepCollection
    end)
    panel:SetAttribute("AWTab", tab)
    panel:SetAttribute("AWPrepSub", prepSub)
end

-- ======================== Ouverture, navigation ========================

local function show()
    panel.Visible = true
    VehiclePreview.setActive(true)
    renderHints()
    send("Snapshot", nil, true)
end

local function hide()
    panel.Visible = false
    VehiclePreview.setActive(false)
    if modal then
        modal:Destroy()
        modal = nil
    end
end

local function open(which: string?)
    if which then
        tab = which
    end
    if UIManager.isOpen("Garage") then
        render()
    else
        UIManager.open("Garage")
    end
end

local function toggle()
    UIManager.toggle("Garage")
end

local function goTab(name: string)
    tab = name
    render()
end

-- Retour d'un niveau (Retour arrière, B) ; faux depuis la Collection : le gestionnaire ferme alors le garage.
local function back(): boolean
    if modal then
        modal:Destroy()
        modal = nil
        return true
    end
    local target = GarageView.backTab(tab)
    if target == nil then
        return false
    end
    goTab(target)
    return true
end

local function updateBadge()
    local value = player:GetAttribute("AWProfileState")
    badge.Text = Text.text(if type(value) == "string" then value else "Loading")
end

function GaragePanel.start()
    local folder = ReplicatedStorage:WaitForChild(ProgressionProtocol.FolderName)
    request = folder:WaitForChild(ProgressionProtocol.Request) :: RemoteFunction
    local pushEvent = folder:WaitForChild(ProgressionProtocol.Push) :: RemoteEvent

    gui = make("ScreenGui", {
        Name = "AWProgression",
        ResetOnSpawn = false,
        IgnoreGuiInset = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        -- Écran plein : au-dessus du HUD (la mini-carte recouvrait le panneau latéral, VM 20261105-034506).
        DisplayOrder = 20,
    }, player:WaitForChild("PlayerGui"))
    badge = make("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 64),
        Size = UDim2.fromOffset(360, 26),
        BackgroundColor3 = UITheme.color("PanelChrome"),
        BackgroundTransparency = 0.1,
        TextColor3 = UITheme.color("Text"),
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        Text = "",
    }, gui)
    make("UICorner", { CornerRadius = UDim.new(0, Tokens.Radius.Button) }, badge)
    -- Disposition de la maquette « Garage » : barre haute 56, onglets 48, contenu, barre d'aide 40.
    panel = make("Frame", {
        Name = "Garage",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = color("BgBase"),
        BorderSizePixel = 0,
        Visible = false,
    }, gui)
    -- Racine logique (1440 p : disposition 1080 p à l'échelle 1,333 ; compacte sous 1400 px logiques).
    local logical = Components.logicalRoot(panel)
    local top = make("Frame", {
        Name = "BarreHaute",
        Size = UDim2.new(1, 0, 0, Tokens.Garage.TopBar),
        BackgroundColor3 = color("BgChrome"),
        BorderSizePixel = 0,
    }, logical)
    make("UIPadding", { PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20) }, top)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 14),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, top)
    local title = Components.text(top, Tokens.upper(tr("Garage")), "H1", { Name = "Titre", LayoutOrder = 1 })
    title.TextSize = UITheme.text(22)
    contextLabel = Components.text(top, "", "Body", {
        Name = "Lieu",
        LayoutOrder = 2,
        TextColor3 = color("TextMuted"),
    })
    contextLabel.TextSize = UITheme.text(13)
    draftBadge = Components.text(top, Tokens.upper(Localization.t("ui.state.draft")), "Label", {
        Name = "Brouillon",
        LayoutOrder = 3,
        TextColor3 = color("Amber"),
    })
    make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, draftBadge)
    make("UIStroke", {
        Color = color("Amber"),
        Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, draftBadge)
    corner(draftBadge, 3)
    draftBadge.Visible = false
    -- Filet sous la barre haute : posé sur le panneau, hors de la liste horizontale de la barre (il en repoussait le
    -- titre et le lieu hors de l'écran, VM 20261105-121324).
    make("Frame", {
        Name = "FiletBarreHaute",
        BackgroundColor3 = color("Line"),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, Tokens.Garage.TopBar - 1),
        Size = UDim2.new(1, 0, 0, 1),
        ZIndex = 2,
    }, logical)
    local tabs = make("Frame", {
        Name = "Onglets",
        Position = UDim2.fromOffset(0, Tokens.Garage.TopBar),
        Size = UDim2.new(1, 0, 0, Tokens.Garage.Tabs),
        BackgroundColor3 = color("BgBase"),
        BorderSizePixel = 0,
    }, logical)
    make("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, tabs)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, tabs)
    for index, name in TABS do
        local item = make("TextButton", {
            Name = "Onglet" .. index,
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Text = tr(name),
            LayoutOrder = index,
        }, tabs)
        make("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, item)
        item.FontFace = UITheme.face("Button")
        item.TextSize = UITheme.text(15)
        item.TextColor3 = color("TextMuted")
        make("Frame", {
            Name = "Filet",
            BackgroundColor3 = color("Amber"),
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, -16, 1, 0),
            Size = UDim2.new(1, 32, 0, Tokens.StatusRail),
            Visible = false,
        }, item)
        item.Activated:Connect(function()
            goTab(name)
        end)
        tabButtons[name] = item
    end
    content = make("Frame", {
        Name = "Contenu",
        Position = UDim2.fromOffset(0, Tokens.Garage.TopBar + Tokens.Garage.Tabs),
        Size = UDim2.new(1, 0, 1, -(Tokens.Garage.TopBar + Tokens.Garage.Tabs + Tokens.Garage.HelpBar)),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
    }, logical)
    make("Frame", {
        BackgroundColor3 = color("Line"),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 1),
        ZIndex = 10,
    }, content)

    -- Collection (pleine largeur).
    collectionView = make("ScrollingFrame", {
        Name = "Collection",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = color("Line"),
    }, content)
    make("UIPadding", {
        PaddingLeft = UDim.new(0, 28),
        PaddingRight = UDim.new(0, 28),
        PaddingTop = UDim.new(0, 24),
        PaddingBottom = UDim.new(0, 24),
    }, collectionView)
    vlist(collectionView, 16)
    local lastWidth = 0
    collectionView:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        -- Nombre de colonnes recalculé quand la largeur change (redimensionnement, changement de résolution).
        local logicalWidth = Components.logicalSize(collectionView).X
        if math.abs(logicalWidth - lastWidth) > 8 and tab == "Collection" and panel.Visible then
            lastWidth = logicalWidth
            render()
        end
    end)

    -- Zone 3D.
    stage = make("Frame", {
        Name = "Scene",
        BackgroundTransparency = 1,
        ClipsDescendants = true,
    }, content)
    Components.stage(stage)
    VehiclePreview.attach(stage)
    local info = make("Frame", {
        Name = "Identite",
        Position = UDim2.fromOffset(28, 20),
        Size = UDim2.new(0.55, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex = 3,
    }, stage)
    vlist(info, 6)
    local backButton = button(info, tr("Collection"), "Secondary", function()
        goTab("Collection")
    end, nil, nil, 32, "RetourCollection")
    backButton.ZIndex = 4
    backButton.BackgroundColor3 = color("BgBase")
    backButton.BackgroundTransparency = 0.2
    local backPad = backButton:FindFirstChildOfClass("UIPadding") :: UIPadding
    backPad.PaddingLeft = UDim.new(0, 24)
    local backChevron = make("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(20, 32),
        Position = UDim2.fromOffset(-20, 0),
        ZIndex = 5,
    }, backButton)
    chevron(backChevron, true, 10)
    stageName = Components.text(info, "", "Display", {
        Name = "NomVehicule",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        ZIndex = 4,
        LayoutOrder = 100,
    })
    stageCategory = Components.text(info, "", "Body", {
        Name = "Categorie",
        TextColor3 = Color3.fromRGB(201, 198, 191),
        ZIndex = 4,
        LayoutOrder = 101,
    })
    stageCategory.TextSize = UITheme.text(16)
    stageAvailability = Components.text(info, "", "Label", {
        Name = "StatutGamme",
        BackgroundTransparency = 0,
        TextColor3 = color("AmberSoftText"),
        ZIndex = 4,
        LayoutOrder = 102,
    })
    stageAvailability.BackgroundColor3 = color("AmberSoft")
    stageAvailability.TextSize = UITheme.text(11)
    make("UIPadding", {
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
        PaddingTop = UDim.new(0, 3),
        PaddingBottom = UDim.new(0, 3),
    }, stageAvailability)
    corner(stageAvailability, 3)
    -- Vues de la caméra (en haut à droite).
    local views = make("Frame", {
        Name = "Vues",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -20, 0, 20),
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundColor3 = color("BgBase"),
        BackgroundTransparency = 0.2,
        ZIndex = 3,
    }, stage)
    corner(views, 5)
    stroke(views)
    padding(views, 3, 3)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, views)
    for index, view in GarageView.Views do
        local item = make("TextButton", {
            Name = "Vue_" .. view.Id,
            Text = tr(view.Label),
            AutoButtonColor = false,
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(0, 34),
            AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = index,
            ZIndex = 4,
        }, views)
        item.FontFace = UITheme.face("Button")
        item.TextSize = UITheme.text(13)
        item.TextColor3 = color("Text")
        corner(item, 3)
        make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, item)
        item.Activated:Connect(function()
            VehiclePreview.setView(view.Angle)
            renderStage()
        end)
        viewButtons[view.Id] = item
    end
    -- Caméra : libellé et réinitialisation (en bas à gauche).
    local cam = make("Frame", {
        Name = "Camera",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 28, 1, -20),
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundTransparency = 1,
        ZIndex = 3,
    }, stage)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 10),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, cam)
    camLabel = Components.text(
        cam,
        "",
        "Value",
        { Name = "Libelle", TextColor3 = color("TextMuted"), LayoutOrder = 1, ZIndex = 4 }
    )
    camLabel.TextSize = UITheme.text(12)
    local reset = button(cam, tr("Réinitialiser"), "Secondary", function()
        VehiclePreview.reset()
        renderStage()
    end, nil, nil, 28, "Reinitialiser")
    reset.ZIndex = 4
    reset.LayoutOrder = 2
    -- Case à cocher « Rotation automatique » (demande du propriétaire) : dessinée (carré à filet, coche ambre).
    local autoBox = make("TextButton", {
        Name = "RotationAuto",
        Text = "",
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(0, 28),
        AutomaticSize = Enum.AutomaticSize.X,
        LayoutOrder = 3,
        ZIndex = 4,
    }, cam)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 8),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, autoBox)
    local square = make("Frame", {
        Name = "Case",
        Size = UDim2.fromOffset(18, 18),
        BackgroundColor3 = color("BgBase"),
        BackgroundTransparency = 0.2,
        LayoutOrder = 1,
        ZIndex = 5,
    }, autoBox)
    corner(square, 3)
    local squareEdge = make("UIStroke", { Color = color("Line"), Thickness = 1.5 }, square)
    local tick = make("Frame", {
        Name = "Coche",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(10, 10),
        BackgroundColor3 = color("Amber"),
        BorderSizePixel = 0,
        ZIndex = 6,
    }, square)
    corner(tick, 2)
    local autoLabel = Components.text(autoBox, tr("Rotation automatique"), "Body", {
        Name = "Libelle",
        LayoutOrder = 2,
        ZIndex = 5,
    })
    autoLabel.TextSize = UITheme.text(13)
    local function paintAuto()
        local on = VehiclePreview.spinning()
        tick.Visible = on
        squareEdge.Color = if on then color("Amber") else color("Line")
        autoBox:SetAttribute("AWChecked", on)
    end
    autoBox.Activated:Connect(function()
        VehiclePreview.setAutoRotate(not VehiclePreview.spinning())
        paintAuto()
        renderStage()
    end)
    paintAuto()
    VehiclePreview.onChange(function()
        updateCamLabel()
        paintAuto()
    end)
    -- Barre d'actions (en bas au centre, onglet Véhicule).
    actionBar = make("Frame", {
        Name = "Actions",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -64),
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundColor3 = color("BgBase"),
        BackgroundTransparency = 0.1,
        ZIndex = 3,
    }, stage)
    corner(actionBar, Tokens.Radius.Card)
    stroke(actionBar)
    padding(actionBar, 6, 6)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, actionBar)

    -- Panneau latéral.
    side = make("Frame", {
        Name = "PanneauLateral",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        BackgroundColor3 = Color3.fromRGB(17, 19, 21),
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, content)
    make("Frame", {
        BackgroundColor3 = color("Line"),
        BorderSizePixel = 0,
        Size = UDim2.new(0, 1, 1, 0),
        ZIndex = 5,
    }, side)
    sideTop = make("Frame", {
        Name = "SousOnglets",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, side)
    make(
        "UIPadding",
        { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), PaddingTop = UDim.new(0, 12) },
        sideTop
    )
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, sideTop)
    body = make("ScrollingFrame", {
        Name = "Corps",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = color("Line"),
    }, side)
    padding(body, 20, 18)
    vlist(body, 12)
    prepFooter = make("Frame", {
        Name = "PiedPreparation",
        AnchorPoint = Vector2.new(0, 1),
        Size = UDim2.new(1, 0, 0, 68),
        BackgroundColor3 = color("BgChrome"),
        BorderSizePixel = 0,
    }, side)
    padding(prepFooter, 16, 12)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, prepFooter)
    local discard = button(prepFooter, tr("Annuler le brouillon"), "Secondary", function()
        draftTuning = {}
        draftCosmetics = nil
        render()
    end, nil, nil, Tokens.PrimaryButtonHeight, "AnnulerBrouillon")
    discard.AutomaticSize = Enum.AutomaticSize.None
    discard.Size = UDim2.new(0.42, -4, 0, Tokens.PrimaryButtonHeight)
    discard.BackgroundTransparency = 1
    local applyButton = button(
        prepFooter,
        tr("Appliquer le brouillon"),
        "Primary",
        applyDraft,
        nil,
        nil,
        Tokens.PrimaryButtonHeight,
        "AppliquerBrouillon"
    )
    applyButton.AutomaticSize = Enum.AutomaticSize.None
    applyButton.Size = UDim2.new(0.58, -4, 0, Tokens.PrimaryButtonHeight)

    -- Bandeau d'état du serveur (bas du panneau latéral, ou bas de la collection).
    statusBox = make("Frame", {
        Name = "EtatServeur",
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = color("Surface1"),
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 6,
    }, side)
    padding(statusBox, 16, 10)
    vlist(statusBox, 2)
    statusCode = Components.text(statusBox, "", "Value", { Name = "Code", LayoutOrder = 1, ZIndex = 7 })
    statusCode.TextSize = UITheme.text(11)
    statusText = Components.text(statusBox, "", "Body", {
        Name = "Message",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 2,
        ZIndex = 7,
    })
    statusText.TextSize = UITheme.text(13)
    statusBox:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if panel.Visible then
            layoutPanels()
        end
    end)

    -- Barre d'aide (40 px) : touches et Fermer.
    local help = make("Frame", {
        Name = "BarreAide",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, Tokens.Garage.HelpBar),
        BackgroundColor3 = color("BgChrome"),
        BorderSizePixel = 0,
    }, logical)
    make("Frame", {
        BackgroundColor3 = color("Line"),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 1),
    }, help)
    hintsRow = make("Frame", {
        Name = "Touches",
        Position = UDim2.fromOffset(20, 0),
        Size = UDim2.new(1, -200, 1, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
    }, help)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 18),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, hintsRow)
    -- « Fermer » dans la barre d'aide, en bas à droite : en haut à droite, il passait sous le cartouche du joueur
    -- affiché par Roblox (clic perdu, VM 20261105-034506). Écart à la maquette (bouton dans la barre haute).
    local close = UITheme.button(tr("Fermer"), {
        Name = "Fermer",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -Tokens.PanelPadding, 0.5, 0),
        Size = UDim2.fromOffset(0, Tokens.MinTarget),
        AutomaticSize = Enum.AutomaticSize.X,
    }, help)
    make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, close)
    close.Activated:Connect(toggle)
    closeButton = close

    player:GetAttributeChangedSignal("AWProfileState"):Connect(updateBadge)
    updateBadge()
    -- Badge de sauvegarde masqué quand un écran est ouvert (il recouvrait les onglets et l'en-tête du téléphone,
    -- VM 20261105-125026) ; chaque écran affiche alors son propre état du serveur.
    task.spawn(function()
        while true do
            badge.Visible = not UIManager.anyOpen()
            task.wait(0.25)
        end
    end)

    -- Changement de langue à chaud : textes des onglets, badge et contenu redessinés.
    Localization.changed(function()
        for name, item in tabButtons do
            item.Text = tr(name)
        end
        if closeButton then
            closeButton.Text = tr("Fermer")
        end
        title.Text = Tokens.upper(tr("Garage"))
        backButton.Text = tr("Collection")
        reset.Text = tr("Réinitialiser")
        autoLabel.Text = tr("Rotation automatique")
        for _, view in GarageView.Views do
            local item = viewButtons[view.Id]
            if item then
                item.Text = tr(view.Label)
            end
        end
        updateBadge()
        renderHints()
        render()
    end)

    pushEvent.OnClientEvent:Connect(function(kind: any, data: any)
        if kind == "Snapshot" and type(data) == "table" then
            state = data
            render()
        elseif kind == "Confirmed" and type(data) == "table" then
            state = data.Snapshot or state
            setStatus("Confirmed", Text.text("Confirmed"))
            render()
        elseif kind == "EntranceOffer" and type(data) == "table" then
            entranceOffer = data
            open("Propriétés")
        elseif kind == "Open" and type(data) == "table" then
            open(if data.Tab == "Garage" then "Préparation" else nil)
        elseif kind == "Notice" and type(data) == "string" then
            setStatus("Info", Text.text(data))
            badge.Text = Text.text(data)
        end
    end)

    -- Onglets au clavier ([ ] et PageUp / PageDown) et à la manette (LB / RB) ; flèches : rotation.
    UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
        if not panel.Visible or modal ~= nil or UserInputService:GetFocusedTextBox() ~= nil then
            return
        end
        local key = input.KeyCode
        if key == Enum.KeyCode.RightBracket or key == Enum.KeyCode.PageDown or key == Enum.KeyCode.ButtonR1 then
            goTab(GarageView.cycleTab(tab, 1))
        elseif key == Enum.KeyCode.LeftBracket or key == Enum.KeyCode.PageUp or key == Enum.KeyCode.ButtonL1 then
            goTab(GarageView.cycleTab(tab, -1))
        elseif not processed and tab ~= "Collection" and (key == Enum.KeyCode.Left or key == Enum.KeyCode.Right) then
            VehiclePreview.rotate(if key == Enum.KeyCode.Left then -15 else 15)
            renderStage()
        end
    end)
    UserInputService.LastInputTypeChanged:Connect(function()
        if panel.Visible then
            renderHints()
        end
    end)

    -- Raccourci P (manette : Select) : InputRouter, lot 0.7. Retour : un niveau d'onglet avant de fermer.
    UIManager.register({
        Name = "Garage",
        Kind = "Modal",
        Full = true,
        Open = show,
        Close = hide,
        Back = back,
        Focus = function()
            return tabButtons[tab]
        end,
    })
end

return table.freeze(GaragePanel)
