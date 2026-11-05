--!strict
--[[
    Thème de l'interface : couleurs, typographies, tailles et réglages d'accessibilité (taille des textes, contraste
    renforcé, opacité des panneaux, animations réduites) au même endroit ; chaque interface crée ses éléments par ces
    fonctions pour que les réglages s'appliquent partout.

    Lot UI-01 (UI PREMIUM V1.2) : valeurs reprises des jetons du système de conception (`Shared.UI.DesignTokens`,
    direction « Automotive Premium » du propriétaire). Les noms historiques (Panel, Accent, TextDim…) sont conservés :
    les écrans existants passent à la palette V1.2 sans être réécrits ; ils seront refaits lot par lot.
    Contraste renforcé (maquette §8) : bordures #6B6F77 et texte secondaire #D9D7D2, le reste inchangé.
]]

local TweenService = game:GetService("TweenService")

local UIState = require(script.Parent.UIState)
local Tokens =
    require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("DesignTokens"))

local UITheme = {}

-- Noms historiques → jetons V1.2. Route et instruments en cyan (seul usage autorisé) ; refus en rouge.
local ALIASES: { [string]: string } = {
    Panel = "BgBase",
    PanelChrome = "BgChrome",
    PanelRaised = "Surface2",
    Surface = "Surface1",
    Hover = "Surface2Hover",
    Line = "Line",
    Accent = "Amber",
    AccentSoft = "AmberSoft",
    AccentSoftText = "AmberSoftText",
    OnAccent = "TextOnAmber",
    Text = "Text",
    TextDim = "TextMuted",
    Good = "Ok",
    Warn = "AmberSoftText",
    Danger = "RaceRed",
    Focus = "Amber",
    Route = "GpsCyan",
    Gps = "GpsCyan",
}
-- Fond de la carte (routes) : hors palette d'interface, valeurs du lot 0.7 gardées.
local MAP: { [string]: Color3 } = {
    Road = Color3.fromRGB(150, 156, 168),
    RoadMajor = Color3.fromRGB(220, 196, 120),
}

-- Repères historiques (Enum.Font) : convertis en Titillium Web par `UITheme.applyFont` (graisse correspondante).
UITheme.Font = Enum.Font.Gotham
UITheme.FontBold = Enum.Font.GothamBold
UITheme.FontMedium = Enum.Font.GothamMedium

function UITheme.color(name: string): Color3
    local map = MAP[name]
    if map then
        return map
    end
    local token = ALIASES[name] or name
    if (Tokens.Colors :: { [string]: Color3? })[token] == nil then
        return Tokens.Colors.Text
    end
    return Tokens.color(token, UIState.prefs().Access.HighContrast)
end

-- Police d'un style de la maquette (Display, H1, H2, Button, Body, Label, Speed, Race, Value).
function UITheme.face(style: string): Font
    local entry = Tokens.Type[style] or Tokens.Type.Body
    local weight = (Enum.FontWeight :: any)[entry.Weight] or Enum.FontWeight.Regular
    return Font.fromName(entry.Family, weight, if entry.Italic then Enum.FontStyle.Italic else Enum.FontStyle.Normal)
end

local WEIGHT_OF: { [Enum.Font]: Enum.FontWeight } = {
    [Enum.Font.Gotham] = Enum.FontWeight.Regular,
    [Enum.Font.GothamMedium] = Enum.FontWeight.SemiBold,
    [Enum.Font.GothamBold] = Enum.FontWeight.Bold,
}
-- Remplace un repère historique (Gotham) par Titillium Web de même graisse.
function UITheme.applyFont(item: TextLabel | TextButton | TextBox, legacy: Enum.Font?)
    local weight = WEIGHT_OF[legacy or Enum.Font.Gotham] or Enum.FontWeight.Regular
    local target = item :: any
    target.FontFace = Font.fromName(Tokens.Families.Text, weight)
end

-- Taille de texte selon le réglage d'accessibilité (bornée, jamais sous 11 px : maquette §2).
function UITheme.text(size: number): number
    return math.max(Tokens.MinTextSize, math.floor(size * UIState.prefs().Access.TextScale / 100 + 0.5))
end

function UITheme.panelTransparency(): number
    return 1 - UIState.prefs().Access.PanelOpacity / 100
end

-- Animation courte (aucune si « réduire les animations »).
function UITheme.tween(instance: Instance, props: { [string]: any }, seconds: number?)
    if UIState.prefs().Access.ReduceMotion then
        for key, value in props do
            (instance :: any)[key] = value
        end
        return
    end
    TweenService:Create(instance, TweenInfo.new(seconds or 0.15, Enum.EasingStyle.Quad), props):Play()
end

-- Animation nommée de la maquette (§7) ; durée 0 si « réduire les animations ».
function UITheme.motion(instance: Instance, props: { [string]: any }, motion: string)
    local entry = Tokens.Motion[motion]
    if entry == nil or UIState.prefs().Access.ReduceMotion then
        for key, value in props do
            (instance :: any)[key] = value
        end
        return
    end
    local info = TweenInfo.new(
        entry.Seconds,
        (Enum.EasingStyle :: any)[entry.Style] or Enum.EasingStyle.Quad,
        (Enum.EasingDirection :: any)[entry.Direction] or Enum.EasingDirection.Out
    )
    TweenService:Create(instance, info, props):Play()
end

function UITheme.make(className: string, props: { [string]: any }, parent: Instance?): any
    local item = Instance.new(className)
    for key, value in props do
        (item :: any)[key] = value
    end
    item.Parent = parent
    return item
end

-- Panneau standard (coins arrondis, opacité réglable).
function UITheme.panel(props: { [string]: any }, parent: Instance?): Frame
    local frame = UITheme.make("Frame", props, parent)
    frame.BackgroundColor3 = UITheme.color("Panel")
    frame.BackgroundTransparency = UITheme.panelTransparency()
    frame.BorderSizePixel = 0
    UITheme.make("UICorner", { CornerRadius = UDim.new(0, Tokens.Radius.Card) }, frame)
    return frame
end

function UITheme.label(text: string, size: number, props: { [string]: any }, parent: Instance?): TextLabel
    local label = UITheme.make("TextLabel", props, parent)
    label.BackgroundTransparency = 1
    UITheme.applyFont(label, props.Font)
    label.TextSize = UITheme.text(size)
    label.TextColor3 = props.TextColor3 or UITheme.color("Text")
    label.Text = text
    return label
end

-- Bouton navigable (clavier, souris, manette) avec focus clairement visible.
function UITheme.button(text: string, props: { [string]: any }, parent: Instance?, callback: (() -> ())?): TextButton
    local button = UITheme.make("TextButton", props, parent)
    button.BackgroundColor3 = UITheme.color("PanelRaised")
    button.TextColor3 = UITheme.color("Text")
    UITheme.applyFont(button, Enum.Font.GothamMedium)
    button.TextSize = UITheme.text(Tokens.Type.Button.Size)
    button.Text = text
    -- Survol de la maquette (surface.2 → #262A2F) au lieu de l'assombrissement automatique de Roblox.
    button.AutoButtonColor = false
    button.Selectable = true
    UITheme.make("UICorner", { CornerRadius = UDim.new(0, Tokens.Radius.Button) }, button)
    local stroke = UITheme.make("UIStroke", {
        Color = UITheme.color("Line"),
        Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, button)
    local base = button.BackgroundColor3
    button.MouseEnter:Connect(function()
        if button.Active then
            button.BackgroundColor3 = UITheme.color("Hover")
        end
    end)
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = base
    end)
    -- Focus manette et clavier : contour ambre de 2 px (maquette §8).
    button.SelectionGained:Connect(function()
        stroke.Color = UITheme.color("Focus")
        stroke.Thickness = Tokens.FocusStroke
    end)
    button.SelectionLost:Connect(function()
        stroke.Color = UITheme.color("Line")
        stroke.Thickness = 1
    end)
    -- Le sélecteur manette par défaut est remplacé par un contour net.
    local selection = UITheme.make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, nil)
    button.SelectionImageObject = selection
    if callback then
        button.Activated:Connect(callback)
    end
    return button
end

return UITheme
