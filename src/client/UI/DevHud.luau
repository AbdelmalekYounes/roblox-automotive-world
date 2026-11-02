--!strict
-- HUD de DÉVELOPPEMENT du lot 0.1 (ce n'est pas le HUD définitif du chapitre 7).
-- Affiche vitesse, rapport, régime, commandes effectives, aides présentes,
-- mesures locales (0–100 km/h, 100–0 km/h) et l'aide des touches adaptée au
-- dernier périphérique utilisé (AUD-INPUT-01).

local Players = game:GetService("Players")

local Messages = require(script.Parent.Messages)

local DevHud = {}

type Bar = { Frame: Frame, Fill: Frame }

local gui: ScreenGui? = nil
local panel: Frame? = nil
local speedLabel: TextLabel? = nil
local gearLabel: TextLabel? = nil
local detailLabel: TextLabel? = nil
local measureLabel: TextLabel? = nil
local helpLabel: TextLabel? = nil
local noticeLabel: TextLabel? = nil
local bars: { [string]: Bar } = {}
local noticeToken = 0
local usingGamepad = false

local KEYBOARD_HELP = "Z/W accélérer • S freiner/reculer (maintenir à l'arrêt) • Q/A D diriger • Espace frein à main"
    .. "\nV caméra • R remettre sur roues • F sortir"
local GAMEPAD_HELP = "RT accélérer • LT freiner/reculer (maintenir à l'arrêt) • Stick gauche diriger • A frein à main"
    .. "\nCroix haut caméra • Croix bas remettre sur roues • Y sortir"

local function makeLabel(parent: Instance, name: string, position: UDim2, size: UDim2, textSize: number): TextLabel
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Position = position
    label.Size = size
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(235, 242, 249)
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
    frame.Size = UDim2.new(1, -32, 0, 8)
    frame.BackgroundColor3 = Color3.fromRGB(45, 52, 62)
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
    frame.Size = UDim2.fromOffset(340, 262)
    frame.BackgroundColor3 = Color3.fromRGB(18, 24, 33)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.Parent = screen

    speedLabel = makeLabel(frame, "Vitesse", UDim2.fromOffset(16, 10), UDim2.new(1, -110, 0, 44), 38)
    gearLabel = makeLabel(frame, "Rapport", UDim2.new(1, -90, 0, 10), UDim2.fromOffset(74, 44), 38)
    detailLabel = makeLabel(frame, "Details", UDim2.fromOffset(16, 58), UDim2.new(1, -32, 0, 34), 14)
    bars.Rpm = makeBar(frame, "BarreRegime", 96, Color3.fromRGB(255, 122, 26))
    bars.Throttle = makeBar(frame, "BarreAccelerateur", 110, Color3.fromRGB(80, 200, 120))
    bars.Brake = makeBar(frame, "BarreFrein", 124, Color3.fromRGB(230, 70, 70))
    bars.Steer = makeBar(frame, "BarreDirection", 138, Color3.fromRGB(90, 160, 240))
    measureLabel = makeLabel(frame, "Mesures", UDim2.fromOffset(16, 154), UDim2.new(1, -32, 0, 48), 14)
    local help = makeLabel(frame, "Aide", UDim2.fromOffset(16, 204), UDim2.new(1, -32, 0, 52), 12)
    help.TextColor3 = Color3.fromRGB(170, 182, 196)
    helpLabel = help

    local notice = Instance.new("TextLabel")
    notice.Name = "Message"
    notice.AnchorPoint = Vector2.new(0.5, 0)
    notice.Position = UDim2.new(0.5, 0, 0, 72)
    notice.Size = UDim2.fromOffset(520, 40)
    notice.BackgroundColor3 = Color3.fromRGB(18, 24, 33)
    notice.BackgroundTransparency = 0.1
    notice.TextColor3 = Color3.fromRGB(255, 214, 160)
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

function DevHud.show(vehicleName: string, aidsText: string)
    ensureGui()
    if panel then
        panel.Visible = true
    end
    if detailLabel then
        detailLabel.Text = vehicleName .. "\n" .. aidsText
    end
    refreshHelp()
end

function DevHud.hide()
    if panel then
        panel.Visible = false
    end
end

function DevHud.setInputMode(isGamepad: boolean)
    if usingGamepad ~= isGamepad then
        usingGamepad = isGamepad
        refreshHelp()
    end
end

export type HudData = {
    SpeedKmh: number,
    Gear: number,
    EngineRpm: number,
    RedlineRpm: number,
    Throttle: number,
    Brake: number,
    Steer: number,
    LastLaunchSeconds: number?,
    BestLaunchSeconds: number?,
    LastBrakeDistanceM: number?,
}

local function formatOptional(value: number?, pattern: string): string
    if value == nil then
        return "—"
    end
    return (string.gsub(string.format(pattern, value), "%.", ","))
end

function DevHud.update(data: HudData)
    if speedLabel then
        speedLabel.Text = string.format("%d km/h", math.floor(data.SpeedKmh + 0.5))
    end
    if gearLabel then
        gearLabel.Text = if data.Gear < 0 then "R" elseif data.Gear == 0 then "N" else tostring(data.Gear)
    end
    setBar("Rpm", data.EngineRpm / data.RedlineRpm)
    setBar("Throttle", data.Throttle)
    setBar("Brake", data.Brake)
    setBar("Steer", data.Steer, true)
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

return DevHud
