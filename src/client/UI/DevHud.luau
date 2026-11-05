--!strict
-- HUD de DÉVELOPPEMENT (ce n'est pas le HUD définitif du chapitre 7).
-- Affiche vitesse, rapport, régime, commandes effectives, mesures locales,
-- énergie, état des aides (absente / désactivée / activée / en action),
-- récupération, embrayage, dégâts, caméra, et l'aide des touches adaptée au
-- dernier périphérique utilisé (AUD-INPUT-01). Toute aide ou tout filtre qui
-- modifie la commande du joueur y est affiché : rien n'est caché.

local Players = game:GetService("Players")

local Messages = require(script.Parent.Messages)
local UITheme = require(script.Parent.UITheme)

local DevHud = {}

type Bar = { Frame: Frame, Fill: Frame }

local gui: ScreenGui? = nil
local panel: Frame? = nil
local speedLabel: TextLabel? = nil
local gearLabel: TextLabel? = nil
local detailLabel: TextLabel? = nil
local systemsLabel: TextLabel? = nil
local measureLabel: TextLabel? = nil
local helpLabel: TextLabel? = nil
local noticeLabel: TextLabel? = nil
local bars: { [string]: Bar } = {}
local noticeToken = 0
local usingGamepad = false
-- Lot 0.7 : le HUD de conduite est HUDController ; ce panneau de diagnostic
-- n'est affiché que si le joueur l'active (paramètres), et les notices passent
-- par le service de notifications central.
local enabled = false
local shown = false
local latestData: HudData? = nil
local noticeSink: ((string, any) -> ())? = nil

local KEYBOARD_HELP = "Z/W accélérer • S freiner/reculer (maintenir à l'arrêt : marche arrière en boîte auto) • Q/A D diriger • Espace frein à main"
    .. "\nMaj gauche / Ctrl gauche rapport + / − • C embrayage • 1 ABS • 2 antipatinage • 3 ESP • G récupération"
    .. "\nV caméra • R remettre sur roues • F sortir"
local GAMEPAD_HELP = "RT accélérer • LT freiner/reculer • Stick gauche diriger • A frein à main"
    .. "\nRB / LB rapport + / − • B embrayage • Croix gauche choisir un réglage, croix droite le changer"
    .. "\nCroix haut caméra • Croix bas remettre sur roues • Y sortir"

local function makeLabel(parent: Instance, name: string, position: UDim2, size: UDim2, textSize: number): TextLabel
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Position = position
    label.Size = size
    label.BackgroundTransparency = 1
    label.TextColor3 = UITheme.color("Text")
    label.Font = Enum.Font.GothamMedium
    label.TextSize = textSize
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.TextWrapped = true
    label.Text = ""
    label.Parent = parent
    return label
end

local function makeBar(parent: Instance, name: string, y: number, color: Color3): Bar
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.Position = UDim2.new(0, 16, 0, y)
    frame.Size = UDim2.new(1, -32, 0, 7)
    frame.BackgroundColor3 = UITheme.color("PanelRaised")
    frame.BorderSizePixel = 0
    frame.Parent = parent
    local fill = Instance.new("Frame")
    fill.Name = "Remplissage"
    fill.Size = UDim2.fromScale(0, 1)
    fill.BackgroundColor3 = color
    fill.BorderSizePixel = 0
    fill.Parent = frame
    return { Frame = frame, Fill = fill }
end

local function ensureGui(): ScreenGui
    local existing = gui
    if existing then
        return existing
    end
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    local screen = Instance.new("ScreenGui")
    screen.Name = "AutomotiveWorldDevHud"
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = false

    local frame = Instance.new("Frame")
    frame.Name = "Panneau"
    frame.AnchorPoint = Vector2.new(1, 1)
    frame.Position = UDim2.new(1, -16, 1, -16)
    frame.Size = UDim2.fromOffset(380, 404)
    frame.BackgroundColor3 = UITheme.color("PanelChrome")
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.Parent = screen

    speedLabel = makeLabel(frame, "Vitesse", UDim2.fromOffset(16, 8), UDim2.new(1, -110, 0, 42), 36)
    gearLabel = makeLabel(frame, "Rapport", UDim2.new(1, -96, 0, 8), UDim2.fromOffset(84, 42), 36)
    detailLabel = makeLabel(frame, "Details", UDim2.fromOffset(16, 52), UDim2.new(1, -32, 0, 30), 13)
    bars.Rpm = makeBar(frame, "BarreRegime", 86, Color3.fromRGB(255, 122, 26))
    bars.Throttle = makeBar(frame, "BarreAccelerateur", 98, Color3.fromRGB(80, 200, 120))
    bars.Brake = makeBar(frame, "BarreFrein", 110, Color3.fromRGB(230, 70, 70))
    bars.Clutch = makeBar(frame, "BarreEmbrayage", 122, Color3.fromRGB(200, 170, 255))
    bars.Steer = makeBar(frame, "BarreDirection", 134, Color3.fromRGB(90, 160, 240))
    bars.Energy = makeBar(frame, "BarreEnergie", 146, Color3.fromRGB(240, 210, 60))
    systemsLabel = makeLabel(frame, "Systemes", UDim2.fromOffset(16, 158), UDim2.new(1, -32, 0, 96), 13)
    measureLabel = makeLabel(frame, "Mesures", UDim2.fromOffset(16, 256), UDim2.new(1, -32, 0, 44), 13)
    local help = makeLabel(frame, "Aide", UDim2.fromOffset(16, 302), UDim2.new(1, -32, 0, 98), 11)
    help.TextColor3 = UITheme.color("TextDim")
    helpLabel = help

    local notice = Instance.new("TextLabel")
    notice.Name = "Message"
    notice.AnchorPoint = Vector2.new(0.5, 0)
    notice.Position = UDim2.new(0.5, 0, 0, 72)
    notice.Size = UDim2.fromOffset(560, 40)
    notice.BackgroundColor3 = UITheme.color("PanelChrome")
    notice.BackgroundTransparency = 0.1
    notice.TextColor3 = UITheme.color("AccentSoftText")
    notice.Font = Enum.Font.GothamMedium
    notice.TextSize = 16
    notice.TextWrapped = true
    notice.Visible = false
    notice.Parent = screen
    noticeLabel = notice

    screen.Parent = playerGui
    gui = screen
    panel = frame
    return screen
end

local function setBar(name: string, value: number, centered: boolean?)
    local bar = bars[name]
    if bar == nil then
        return
    end
    if centered then
        -- Barre centrée pour la direction (-1 gauche … +1 droite).
        local v = math.clamp(value, -1, 1)
        bar.Fill.Position = UDim2.fromScale(if v < 0 then 0.5 + v / 2 else 0.5, 0)
        bar.Fill.Size = UDim2.fromScale(math.abs(v) / 2, 1)
    else
        bar.Fill.Position = UDim2.fromScale(0, 0)
        bar.Fill.Size = UDim2.fromScale(math.clamp(value, 0, 1), 1)
    end
end

local function refreshHelp()
    if helpLabel then
        helpLabel.Text = if usingGamepad then GAMEPAD_HELP else KEYBOARD_HELP
    end
end

function DevHud.show(vehicleName: string, description: string)
    ensureGui()
    shown = true
    if panel then
        panel.Visible = enabled
    end
    if detailLabel then
        detailLabel.Text = vehicleName .. "\n" .. description
    end
    refreshHelp()
end

function DevHud.hide()
    shown = false
    latestData = nil
    if panel then
        panel.Visible = false
    end
end

function DevHud.setEnabled(on: boolean)
    enabled = on
    if panel then
        panel.Visible = on and shown
    end
end

-- Dernières données de conduite (lues par HUDController), nil à pied.
function DevHud.latest(): HudData?
    return if shown then latestData else nil
end

function DevHud.setNoticeSink(sink: (string, any) -> ())
    noticeSink = sink
end

function DevHud.setInputMode(isGamepad: boolean)
    if usingGamepad ~= isGamepad then
        usingGamepad = isGamepad
        refreshHelp()
    end
end

export type AidLine = {
    Label: string,
    -- "Absente" (modèle non équipé), "Off", "On", "Active" (intervient).
    Status: "Absente" | "Off" | "On" | "Active",
    Selected: boolean,
}

export type HudData = {
    SpeedKmh: number,
    Gear: number,
    GearLabel: string?,
    EngineRpm: number,
    RedlineRpm: number,
    Throttle: number,
    Brake: number,
    Clutch: number,
    ShowClutch: boolean,
    Steer: number,
    EnergyFraction: number,
    EnergyText: string,
    Aids: { AidLine },
    RegenText: string?,
    EngineText: string,
    DamageText: string,
    CameraName: string,
    LastLaunchSeconds: number?,
    BestLaunchSeconds: number?,
    LastBrakeDistanceM: number?,
    -- Lot 0.7 (HUD) : type de boîte, motorisation, état du moteur, modèle conduit.
    TransmissionKind: string?,
    Electric: boolean?,
    Stalled: boolean?,
    Model: Model?,
}

local function formatOptional(value: number?, pattern: string): string
    if value == nil then
        return "—"
    end
    return (string.gsub(string.format(pattern, value), "%.", ","))
end

local STATUS_TEXT = {
    Absente = "absent",
    Off = "désactivé",
    On = "activé",
    Active = "ACTIVÉ · en action",
}

function DevHud.update(data: HudData)
    latestData = data
    if speedLabel then
        speedLabel.Text = string.format("%d km/h", math.floor(data.SpeedKmh + 0.5))
    end
    if gearLabel then
        gearLabel.Text = data.GearLabel
            or (if data.Gear < 0 then "R" elseif data.Gear == 0 then "N" else tostring(data.Gear))
    end
    setBar("Rpm", data.EngineRpm / math.max(data.RedlineRpm, 1))
    setBar("Throttle", data.Throttle)
    setBar("Brake", data.Brake)
    setBar("Clutch", if data.ShowClutch then data.Clutch else 0)
    setBar("Steer", data.Steer, true)
    setBar("Energy", data.EnergyFraction)
    if systemsLabel then
        local aids = {}
        for _, aid in data.Aids do
            table.insert(
                aids,
                string.format("%s%s : %s", if aid.Selected then "▶ " else "", aid.Label, STATUS_TEXT[aid.Status])
            )
        end
        local lines = {
            data.EngineText .. " • " .. data.EnergyText,
            table.concat(aids, " • "),
        }
        if data.RegenText then
            table.insert(lines, data.RegenText)
        end
        table.insert(lines, "Dégâts : " .. data.DamageText)
        table.insert(lines, "Caméra : " .. data.CameraName)
        systemsLabel.Text = table.concat(lines, "\n")
    end
    if measureLabel then
        measureLabel.Text = string.format(
            "Régime : %d tr/min\n0–100 km/h : %s s (meilleur %s s) • 100–0 km/h : %s m",
            math.floor(data.EngineRpm),
            formatOptional(data.LastLaunchSeconds, "%.2f"),
            formatOptional(data.BestLaunchSeconds, "%.2f"),
            formatOptional(data.LastBrakeDistanceM, "%.1f")
        )
    end
end

function DevHud.showNotice(key: string, value: any)
    local sink = noticeSink
    if sink then
        sink(key, value)
        return
    end
    ensureGui()
    local label = noticeLabel
    if label == nil then
        return
    end
    label.Text = Messages.format(key, value)
    label.Visible = true
    noticeToken += 1
    local token = noticeToken
    task.delay(4, function()
        if token == noticeToken and label then
            label.Visible = false
        end
    end)
end

-- Texte actuellement affiché (tests Studio : vérification de l'état des aides).
function DevHud.systemsText(): string
    return if systemsLabel then systemsLabel.Text else ""
end

return DevHud
