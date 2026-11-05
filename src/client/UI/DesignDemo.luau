--!strict
--[[
    Page de démonstration du système de conception V1.2 (lot UI-01), réservée aux essais DANS STUDIO : construite
    seulement si `RunService:IsStudio()` et si le serveur de test pose l'attribut `AWDesignDemo` sur ReplicatedStorage.
    Absente du jeu publié. Montre chaque composant de la maquette « Design System V1.2 » pour les captures et les
    contrôles (polices chargées, focus, désactivé expliqué, états, confirmation protégée, échelle de l'écran).

    Les textes d'exemple reprennent la maquette (outil de développement, jamais montré à un joueur).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Tokens = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("DesignTokens"))
local UITheme = require(script.Parent.UITheme)
local Components = require(script.Parent.Components)

local DesignDemo = {}

local gui: ScreenGui? = nil

local function column(parent: Instance, order: number, width: number): Frame
    local frame = UITheme.make("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, width, 1, 0),
        LayoutOrder = order,
    }, parent) :: Frame
    UITheme.make(
        "UIListLayout",
        { Padding = UDim.new(0, Tokens.Space[3]), SortOrder = Enum.SortOrder.LayoutOrder },
        frame
    )
    return frame
end

local function build(): ScreenGui
    local player = Players.LocalPlayer :: Player
    local screen = UITheme.make("ScreenGui", {
        Name = "AWDesignDemo",
        IgnoreGuiInset = false, -- comme les écrans du jeu (repère des clics réels des essais)
        -- Ordre d'affichage par parent : la fenêtre de confirmation s'affiche au-dessus de son voile.
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false,
        DisplayOrder = 9000, -- au-dessus des écrans du jeu (fenêtre d'arrivée), sous le calque d'étalonnage des essais
    }, nil) :: ScreenGui
    local root = UITheme.make("Frame", {
        Name = "Racine",
        BackgroundColor3 = UITheme.color("Panel"),
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
    }, screen)
    UITheme.make("UIPadding", {
        PaddingLeft = UDim.new(0, Tokens.PanelPaddingCompact),
        PaddingRight = UDim.new(0, Tokens.PanelPaddingCompact),
        PaddingTop = UDim.new(0, Tokens.PanelPaddingCompact),
        PaddingBottom = UDim.new(0, Tokens.PanelPaddingCompact),
    }, root)
    UITheme.make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, Tokens.Space[6]),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, root)

    -- Colonne 1 : typographie et boutons.
    -- Largeurs des colonnes : 1080 p, ou disposition compacte (sous 1400 px logiques, maquette §3).
    local camera = workspace.CurrentCamera :: Camera
    local compact = Tokens.layout(camera.ViewportSize.X, camera.ViewportSize.Y).Compact
    local widths = if compact then { 330, 450, 380 } else { 420, 560, 460 }
    local a = column(root, 1, widths[1])
    Components.text(a, "Rafale", "Display", { Name = "Display", LayoutOrder = 1 })
    Components.text(a, "Collection", "H1", { Name = "H1", LayoutOrder = 2 })
    Components.text(a, "Garage", "H2", { Name = "H2", LayoutOrder = 3 })
    Components.text(a, "Traction vive à double embrayage et différentiel autobloquant.", "Body", {
        Name = "Corps",
        LayoutOrder = 4,
    })
    Components.text(
        a,
        "Réglages",
        "Label",
        { Name = "Libelle", TextColor3 = UITheme.color("TextDim"), LayoutOrder = 5 }
    )
    Components.text(a, "84", "Speed", { Name = "Vitesse", LayoutOrder = 6 })
    local buttons =
        UITheme.make("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 7 }, a)
    UITheme.make(
        "UIListLayout",
        { Padding = UDim.new(0, Tokens.Space[2]), SortOrder = Enum.SortOrder.LayoutOrder },
        buttons
    )
    local clicks = 0
    local primary = Components.button(buttons, "Appliquer les réglages", "Primary", {
        LayoutOrder = 1,
        OnActivated = function()
            clicks += 1
            screen:SetAttribute("AWPrimaryClicks", clicks)
        end,
    })
    primary.Name = "BoutonPrincipal"
    Components.button(buttons, "Annuler", "Secondary", { LayoutOrder = 2 }).Name = "BoutonSecondaire"
    local disabledClicks = 0
    local disabled = Components.button(buttons, "Sortir", "Secondary", {
        LayoutOrder = 3,
        Disabled = true,
        Reason = "Disponible à l'arrêt",
        OnActivated = function()
            disabledClicks += 1
            screen:SetAttribute("AWDisabledClicks", disabledClicks)
        end,
    })
    disabled.Name = "BoutonDesactive"
    Components.button(buttons, "Révoquer", "Revoke", { LayoutOrder = 4 }).Name = "BoutonRevoquer"

    -- Colonne 2 : onglets, segments, réglage, puces, nuancier.
    local b = column(root, 2, widths[2])
    Components.tabs(b, { "Véhicule", "Préparation", "Configurations" }, 1).LayoutOrder = 1
    Components.segmented(b, { "3/4", "Avant", "Arrière", "Profil", "Intérieur" }, 1).LayoutOrder = 2
    local row = Components.tuningRow(b, {
        Label = "Rapport de pont",
        Value = 1.08,
        Origin = 1.0,
        Min = 0.92, -- plage d'EXEMPLE (le garage la lira dans TuningRules.ranges)
        Max = 1.08,
        Step = 0.01,
        Format = "%.2f×",
    })
    row.Name = "LigneReglage"
    row.LayoutOrder = 3
    local chips =
        UITheme.make("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 4 }, b)
    UITheme.make(
        "UIListLayout",
        { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, Tokens.Space[2]) },
        chips
    )
    Components.chip(chips, "Série", false)
    Components.chip(chips, "Pneus sport", true)
    Components.chip(chips, "Cartographie moteur sport", false, "Incompatible avec ce moteur")
    local swatches =
        UITheme.make("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 5 }, b)
    UITheme.make(
        "UIListLayout",
        { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, Tokens.Space[2]) },
        swatches
    )
    for index, rgb in { { 74, 80, 89 }, { 236, 236, 232 }, { 176, 28, 34 }, { 28, 58, 120 } } do
        Components.swatch(swatches, Color3.fromRGB(rgb[1], rgb[2], rgb[3]), index == 2)
    end
    local stageHolder =
        UITheme.make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 160), LayoutOrder = 6 }, b)
    Components.stage(stageHolder)
    Components.text(stageHolder, "Aster", "H1", { Position = UDim2.fromOffset(12, 8) })

    -- Colonne 3 : cartes, avertissements, états, course, confirmation.
    local c = column(root, 3, widths[3])
    Components.card(c, "Concession Métropole", "3,2 km · 6 min", "Gps").LayoutOrder = 1
    Components.card(c, "Préparation envoyée", "En attente du serveur", "Pending").LayoutOrder = 2
    Components.notice(c, "Warn", "Mode photo disponible à l'arrêt ou à pied.").LayoutOrder = 4
    local states = UITheme.make("Frame", {
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0),
        LayoutOrder = 5,
    }, c)
    UITheme.make(
        "UIListLayout",
        { Padding = UDim.new(0, Tokens.Space[1]), SortOrder = Enum.SortOrder.LayoutOrder },
        states
    )
    for index, state in Tokens.SaveStates do
        Components.stateBadge(states, state, if state == "Rejected" then "Solde insuffisant" else nil).LayoutOrder =
            index
    end
    local race =
        UITheme.make("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 3 }, c)
    UITheme.make(
        "UIListLayout",
        { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, Tokens.Space[2]) },
        race
    )
    Components.raceCell(race, "POS", "3/8", "Amber")
    Components.raceCell(race, "TEMPS", "1:42.6", "RaceRed")
    -- Confirmation protégée : fenêtre modale centrée, ouverte à la demande (attribut AWShowConfirm de la page),
    -- pour que la garde de 0,25 s parte de son affichage réel.
    local confirmed = 0
    local overlay: Frame? = nil
    screen:GetAttributeChangedSignal("AWShowConfirm"):Connect(function()
        if screen:GetAttribute("AWShowConfirm") ~= true or overlay then
            return
        end
        local dim = UITheme.make("Frame", {
            Name = "Voile",
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.4,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 10,
        }, screen) :: Frame
        overlay = dim
        local panel = Components.confirm(dim, {
            Question = "Transférer Rafale à Joueur_Lina ?",
            OnConfirm = function()
                confirmed += 1
                screen:SetAttribute("AWConfirmations", confirmed)
            end,
            OnCancel = function()
                dim:Destroy()
                overlay = nil
            end,
        })
        if panel then
            panel.AnchorPoint = Vector2.new(0.5, 0.5)
            panel.Position = UDim2.fromScale(0.5, 0.5)
        end
    end)

    Components.applyLayout(screen)
    screen.Parent = player:WaitForChild("PlayerGui")
    return screen
end

function DesignDemo.start()
    if not RunService:IsStudio() then
        return
    end
    local function sync()
        local wanted = ReplicatedStorage:GetAttribute("AWDesignDemo") == true
        if wanted and gui == nil then
            gui = build()
        elseif not wanted and gui then
            (gui :: ScreenGui):Destroy()
            gui = nil
        end
    end
    ReplicatedStorage:GetAttributeChangedSignal("AWDesignDemo"):Connect(sync)
    sync()
end

return DesignDemo
