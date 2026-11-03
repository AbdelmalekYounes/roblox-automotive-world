--!strict
--[[
    Direction visuelle PROVISOIRE (lot 0.7, §7, finition au lot 0.8) : sobre,
    automobile, lisible. Couleurs, typographies, tailles et réglages
    d'accessibilité (taille des textes, contraste renforcé, opacité des
    panneaux, animations réduites) au même endroit ; chaque interface crée ses
    éléments par ces fonctions pour que les réglages s'appliquent partout.
]]

local TweenService = game:GetService("TweenService")

local UIState = require(script.Parent.UIState)

local UITheme = {}

local NORMAL = {
    Panel = Color3.fromRGB(18, 21, 27),
    PanelRaised = Color3.fromRGB(30, 35, 44),
    Accent = Color3.fromRGB(232, 178, 64), -- ambre automobile
    Text = Color3.fromRGB(232, 236, 242),
    TextDim = Color3.fromRGB(160, 168, 180),
    Good = Color3.fromRGB(90, 200, 120),
    Warn = Color3.fromRGB(240, 170, 50),
    Danger = Color3.fromRGB(230, 70, 60),
    Focus = Color3.fromRGB(120, 190, 255),
    Road = Color3.fromRGB(150, 156, 168),
    RoadMajor = Color3.fromRGB(220, 196, 120),
    Route = Color3.fromRGB(70, 200, 255),
}
local CONTRAST = {
    Panel = Color3.fromRGB(0, 0, 0),
    PanelRaised = Color3.fromRGB(28, 28, 28),
    Accent = Color3.fromRGB(255, 210, 0),
    Text = Color3.fromRGB(255, 255, 255),
    TextDim = Color3.fromRGB(225, 225, 225),
    Good = Color3.fromRGB(0, 255, 120),
    Warn = Color3.fromRGB(255, 200, 0),
    Danger = Color3.fromRGB(255, 60, 60),
    Focus = Color3.fromRGB(0, 220, 255),
    Road = Color3.fromRGB(230, 230, 230),
    RoadMajor = Color3.fromRGB(255, 220, 90),
    Route = Color3.fromRGB(0, 230, 255),
}

UITheme.Font = Enum.Font.Gotham
UITheme.FontBold = Enum.Font.GothamBold
UITheme.FontMedium = Enum.Font.GothamMedium

function UITheme.color(name: string): Color3
    local palette = if UIState.prefs().Access.HighContrast then CONTRAST else NORMAL
    return (palette :: any)[name] or NORMAL.Text
end

-- Taille de texte selon le réglage d'accessibilité (bornée, jamais trop petite).
function UITheme.text(size: number): number
    return math.max(12, math.floor(size * UIState.prefs().Access.TextScale / 100 + 0.5))
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
    UITheme.make("UICorner", { CornerRadius = UDim.new(0, 10) }, frame)
    return frame
end

function UITheme.label(text: string, size: number, props: { [string]: any }, parent: Instance?): TextLabel
    local label = UITheme.make("TextLabel", props, parent)
    label.BackgroundTransparency = 1
    label.Font = props.Font or UITheme.Font
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
    button.Font = UITheme.FontMedium
    button.TextSize = UITheme.text(15)
    button.Text = text
    button.AutoButtonColor = true
    button.Selectable = true
    UITheme.make("UICorner", { CornerRadius = UDim.new(0, 8) }, button)
    local stroke = UITheme.make("UIStroke", {
        Color = UITheme.color("Focus"),
        Thickness = 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, button)
    button.SelectionGained:Connect(function()
        stroke.Thickness = 3
    end)
    button.SelectionLost:Connect(function()
        stroke.Thickness = 0
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
