--!strict
--[[
    Jetons du système de conception UI PREMIUM V1.2 (lot UI-01), module PUR (aucun service) : testé par Lune.

    Source : maquettes du propriétaire « Automotive World — Design System V1.2 » (direction « Automotive Premium »,
    fournie le 2026-11-05, archive Automotive_World_Design_v1.2_Handoff_COMPLET.zip ; copie du texte et du guide dans
    docs/ui/handoff-v1.2/). Seules les valeurs RETENUES y figurent ; les maquettes illustrent le comportement, elles ne
    sont pas du code.

    Règles de la direction : base anthracite et ambre ; deux couleurs fonctionnelles seulement (cyan pour le GPS et les
    instruments, rouge pour le chrono de course et les refus) ; aucune autre teinte dans l'interface. Tailles en pixels
    à la référence 1080 p ; aucun texte sous 11 px.
]]

local DesignTokens = {}

local function rgb(r: number, g: number, b: number): Color3
    return Color3.fromRGB(r, g, b)
end

-- 1. Couleurs (§1). `Contrast` : variantes du réglage « contraste renforcé ».
DesignTokens.Colors = table.freeze({
    BgBase = rgb(14, 15, 17), -- #0E0F11 fond des panneaux
    BgChrome = rgb(18, 20, 22), -- #121416 barres, panneau latéral
    Surface1 = rgb(22, 24, 27), -- #16181B cartes, lignes
    Surface2 = rgb(30, 33, 37), -- #1E2125 boutons, champs
    Surface2Hover = rgb(38, 42, 47), -- #262A2F survol souris
    Line = rgb(51, 54, 60), -- #33363C
    Text = rgb(236, 234, 230), -- #ECEAE6
    TextMuted = rgb(163, 162, 156), -- #A3A29C
    TextOnAmber = rgb(21, 18, 11), -- #15120B
    Amber = rgb(232, 163, 61), -- #E8A33D sélection, focus, action principale
    AmberSoft = rgb(42, 36, 22), -- #2A2416 fond sélectionné / en attente
    AmberSoftText = rgb(244, 190, 106), -- #F4BE6A
    GpsCyan = rgb(92, 200, 214), -- #5CC8D6 GPS, mini-carte, instruments
    RaceRed = rgb(229, 83, 75), -- #E5534B chrono, refus
    Ok = rgb(127, 207, 156), -- #7FCF9C réussite
    WarnBg = rgb(30, 26, 16), -- #1E1A10
    WarnLine = rgb(107, 90, 46), -- #6B5A2E
    WarnText = rgb(241, 227, 196), -- #F1E3C4
    DangerBg = rgb(42, 23, 21), -- #2A1715
    DangerText = rgb(242, 201, 197), -- #F2C9C5
    OkBg = rgb(19, 34, 25), -- #132219
    OkText = rgb(191, 230, 204), -- #BFE6CC
    Stage3D = rgb(42, 46, 52), -- #2A2E34 centre du dégradé de la zone 3D (vers BgBase)
    AppTile = rgb(26, 29, 33), -- #1A1D21 fond des tuiles d'application (planche « Icônes du téléphone »)
} :: { [string]: Color3 })

DesignTokens.Contrast = table.freeze({
    Line = rgb(107, 111, 119), -- #6B6F77
    TextMuted = rgb(217, 215, 210), -- #D9D7D2
} :: { [string]: Color3 })

-- Couleur d'un jeton, avec ou sans contraste renforcé.
function DesignTokens.color(name: string, highContrast: boolean?): Color3
    if highContrast then
        local strong = (DesignTokens.Contrast :: { [string]: Color3? })[name]
        if strong then
            return strong
        end
    end
    local value = (DesignTokens.Colors :: { [string]: Color3? })[name]
    assert(value ~= nil, "Jeton de couleur inconnu : " .. name)
    return value :: Color3
end

-- 2. Typographie (§2). Familles intégrées à Roblox, chargées par `Font.fromName` (à vérifier dans Studio : VM).
export type TextStyle = { Size: number, Family: string, Weight: string, Italic: boolean?, Caps: boolean? }
DesignTokens.Families = table.freeze({ Text = "TitilliumWeb", Mono = "RobotoMono" })
DesignTokens.Type = table.freeze({
    Display = { Size = 56, Family = "TitilliumWeb", Weight = "Bold" },
    H1 = { Size = 28, Family = "TitilliumWeb", Weight = "Bold" },
    H2 = { Size = 22, Family = "TitilliumWeb", Weight = "Bold", Caps = true },
    Button = { Size = 15, Family = "TitilliumWeb", Weight = "SemiBold" },
    Body = { Size = 14, Family = "TitilliumWeb", Weight = "Regular" },
    Label = { Size = 12, Family = "TitilliumWeb", Weight = "SemiBold", Caps = true },
    Speed = { Size = 64, Family = "RobotoMono", Weight = "Bold" },
    Race = { Size = 28, Family = "RobotoMono", Weight = "Bold", Italic = true },
    Value = { Size = 15, Family = "RobotoMono", Weight = "Regular" },
} :: { [string]: TextStyle })
DesignTokens.MinTextSize = 11

-- Capitales des libellés (maquette : « capitales ») : `string.upper` ne traite que l'ASCII et laissait « RéGLAGES ».
local ACCENTS: { [string]: string } = {
    ["à"] = "À",
    ["â"] = "Â",
    ["ä"] = "Ä",
    ["ç"] = "Ç",
    ["é"] = "É",
    ["è"] = "È",
    ["ê"] = "Ê",
    ["ë"] = "Ë",
    ["î"] = "Î",
    ["ï"] = "Ï",
    ["ô"] = "Ô",
    ["ö"] = "Ö",
    ["ù"] = "Ù",
    ["û"] = "Û",
    ["ü"] = "Ü",
    ["ÿ"] = "Ÿ",
    ["œ"] = "Œ",
    ["æ"] = "Æ",
}
function DesignTokens.upper(text: string): string
    local out = string.upper(text)
    for lower, upperCase in ACCENTS do
        out = string.gsub(out, lower, upperCase)
    end
    return out
end

-- Taille affichée d'un style au réglage « taille du texte » (80 à 150 %), jamais sous le minimum.
function DesignTokens.textSize(style: string, textScalePercent: number?): number
    local entry = (DesignTokens.Type :: { [string]: TextStyle? })[style]
    assert(entry ~= nil, "Style de texte inconnu : " .. style)
    local scale = math.clamp(textScalePercent or 100, 80, 150) / 100
    return math.max(DesignTokens.MinTextSize, math.floor(entry.Size * scale + 0.5))
end

-- 3. Mesures (§3).
DesignTokens.Space = table.freeze({ 4, 8, 12, 16, 20, 24, 28 })
DesignTokens.PanelPadding = 20
DesignTokens.PanelPaddingCompact = 16
DesignTokens.Radius = table.freeze({ Chip = 3, Button = 4, Card = 6, AppTile = 14, PhoneFrame = 34, PhoneScreen = 26 })
DesignTokens.PrimaryButtonHeight = 44
DesignTokens.MinTarget = 32
DesignTokens.MinTargetPartChip = 36
DesignTokens.StatusRail = 3 -- filet gauche des cartes, filet des onglets actifs et des cellules de course
DesignTokens.FocusStroke = 2 -- contour ambre du focus (manette, clavier)
DesignTokens.DisabledTransparency = 0.55 -- opacité 0,45

-- Résolutions (§3) : 1080 p de référence ; 1440 p = disposition 1080 p avec UIScale 1,333 ; compacte sous 1400 px de
-- largeur LOGIQUE (après UIScale), UIScale 1.
DesignTokens.ReferenceHeight = 1080
DesignTokens.CompactBelowLogicalWidth = 1400

export type Layout = { Scale: number, Compact: boolean, LogicalWidth: number, LogicalHeight: number }
function DesignTokens.layout(viewportWidth: number, viewportHeight: number): Layout
    local scale = math.max(1, viewportHeight / DesignTokens.ReferenceHeight)
    scale = math.floor(scale * 1000 + 0.5) / 1000
    local logicalWidth = viewportWidth / scale
    return {
        Scale = scale,
        Compact = logicalWidth < DesignTokens.CompactBelowLogicalWidth,
        LogicalWidth = logicalWidth,
        LogicalHeight = viewportHeight / scale,
    }
end

-- Garage (1080 p / compact) et téléphone : cotes des maquettes, utilisées par les lots UI-02 et UI-03.
DesignTokens.Garage = table.freeze({
    TopBar = 56,
    Tabs = 48,
    HelpBar = 40,
    SidePanel = table.freeze({
        Vehicle = { 420, 340 },
        Preparation = { 680, 540 },
        Other = { 560, 460 },
    }),
})
DesignTokens.Phone = table.freeze({
    Normal = Vector2.new(380, 780),
    Enlarged = Vector2.new(460, 940),
    CompactNormal = Vector2.new(330, 600),
    CompactEnlarged = Vector2.new(380, 660),
    Margin = 40,
    MarginCompact = 20,
    AppTile = 56,
    AppIcon = 28,
})

-- 7. Animations (§7) : durées en secondes, style et sens d'interpolation par leur nom (Enum.EasingStyle / Direction).
export type Motion = { Seconds: number, Style: string, Direction: string }
DesignTokens.Motion = table.freeze({
    PanelOpen = { Seconds = 0.16, Style = "Quad", Direction = "Out" },
    PanelClose = { Seconds = 0.16, Style = "Quad", Direction = "In" },
    Present = { Seconds = 0.22, Style = "Quad", Direction = "Out" },
    CameraView = { Seconds = 0.4, Style = "Sine", Direction = "InOut" },
    RotateStep = { Seconds = 0.18, Style = "Quad", Direction = "Out" },
    Tab = { Seconds = 0.12, Style = "Linear", Direction = "Out" },
    EffectBar = { Seconds = 0.25, Style = "Quad", Direction = "Out" },
    PhoneResize = { Seconds = 0.2, Style = "Quad", Direction = "Out" },
    Notification = { Seconds = 0.18, Style = "Quad", Direction = "Out" },
} :: { [string]: Motion })
DesignTokens.PanelSlide = 12 -- décalage en px du fondu d'ouverture
DesignTokens.NotificationShowS = 3.75 -- affichage 3,5 à 4 s

-- Durée effective : 0 si « réduire les animations » (seules les couleurs changent).
function DesignTokens.duration(motion: string, reduceMotion: boolean?): number
    local entry = (DesignTokens.Motion :: { [string]: Motion? })[motion]
    assert(entry ~= nil, "Animation inconnue : " .. motion)
    return if reduceMotion then 0 else entry.Seconds
end

-- 6. États de chargement et de sauvegarde (§6) : « Confirmed » seulement à réception de l'évènement du serveur.
DesignTokens.SaveStates = table.freeze({ "Loading", "Draft", "Pending", "Confirmed", "Rejected", "Offline" })

-- Filet de statut des cartes (§4) : cyan = GPS, ambre = en attente, vert = réussi.
DesignTokens.StatusRailColor = table.freeze({ Gps = "GpsCyan", Pending = "Amber", Done = "Ok" })

-- 8. Accessibilité : rapport de contraste WCAG entre deux couleurs (luminance relative sRGB).
local function channel(c: number): number
    return if c <= 0.03928 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
end
function DesignTokens.luminance(color: Color3): number
    return 0.2126 * channel(color.R) + 0.7152 * channel(color.G) + 0.0722 * channel(color.B)
end
function DesignTokens.contrast(a: Color3, b: Color3): number
    local la, lb = DesignTokens.luminance(a), DesignTokens.luminance(b)
    local hi, lo = math.max(la, lb), math.min(la, lb)
    return (hi + 0.05) / (lo + 0.05)
end
DesignTokens.MinContrast = 4.5

return table.freeze(DesignTokens)
