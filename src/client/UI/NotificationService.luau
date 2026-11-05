--!strict
--[[
    Notifications centralisées (lot 0.7, AUD-ACCESS-01) ; règles pures :
    Shared/UI/NotificationQueue.

    - Information, avertissement, critique ; en conduite : informations
      différées (résumé à l'arrêt), avertissements compacts en haut de
      l'écran (la route reste dégagée), critiques toujours affichées.
    - Critique MULTIMODALE : texte, icône, cadre clignotant (aide visuelle
      alternative au son) ; signal sonore : aucun son original n'existe encore
      dans le projet (lot 0.8), il n'est donc pas joué (limite documentée).
    - Sources : notices du véhicule (VehicleController via DevHud), réponses
      des panneaux, groupes, état de la sauvegarde du profil (attribut
      AWProfileState), énergie et dégâts (HUD).
    - Historique consultable dans le téléphone.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NotificationQueue = require(Shared:WaitForChild("UI"):WaitForChild("NotificationQueue"))
local Localization = require(Shared.UI.Localization)

local UIState = require(script.Parent.UIState)
local UITheme = require(script.Parent.UITheme)

local NotificationService = {}

local queue = NotificationQueue.new()
local gui: ScreenGui
local list: Frame
local banner: Frame
local bannerText: TextLabel
local listeners: { () -> () } = {}

local ICONS = { Info = "ⓘ", Warning = "⚠", Critical = "⛔" }

-- Niveau des notices du véhicule (clés serveur ou client des lots 0.1–0.2).
local VEHICLE_LEVELS: { [string]: NotificationQueue.Level } = {
    EnergyEmpty = "Critical",
    DamageMechanical = "Warning",
    EngineStalled = "Warning",
    ExitTooFast = "Warning",
    VehicleUnavailable = "Warning",
    MovementCorrected = "Warning",
    GamepadDisconnected = "Warning",
    DriveRevokedStop = "Warning",
}

local function context(): NotificationQueue.Context
    local prefs = UIState.prefs()
    return {
        Driving = UIState.mode() == "Moving",
        ReduceSecondary = prefs.Access.ReduceSecondary,
        Enabled = { Info = prefs.Notifications.Info, Warning = prefs.Notifications.Warning },
    }
end

local function textOf(item: NotificationQueue.Item): string
    -- Notices des lots 0.1–0.2 : format « % » avec une valeur unique.
    local params = item.Params
    local text = if params and params.value ~= nil
        then Localization.format(item.Key, params.value)
        else Localization.t(item.Key, params)
    if item.Count > 1 then
        text ..= string.format(" (×%d)", item.Count)
    end
    return text
end

local function colorOf(level: NotificationQueue.Level): Color3
    return if level == "Critical"
        then UITheme.color("Danger")
        elseif level == "Warning" then UITheme.color("Warn")
        else UITheme.color("Accent")
end

local function showToast(item: NotificationQueue.Item, compact: boolean)
    local frame = UITheme.panel({
        Size = UDim2.new(1, 0, 0, if compact then 30 else 42),
        LayoutOrder = -item.Id,
    }, list)
    UITheme.make("UIStroke", { Color = colorOf(item.Level), Thickness = 2 }, frame)
    UITheme.label(ICONS[item.Level] .. "  " .. textOf(item), if compact then 14 else 16, {
        Size = UDim2.new(1, -16, 1, 0),
        Position = UDim2.fromOffset(8, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
    }, frame)
    task.delay(if item.Level == "Critical" then 8 elseif compact then 3 else 5, function()
        frame:Destroy()
    end)
end

-- Alerte critique : bandeau et cadre clignotant (aide visuelle renforcée).
local function showCritical(item: NotificationQueue.Item)
    bannerText.Text = ICONS.Critical .. "  " .. textOf(item)
    banner.Visible = true
    local flashes = if UIState.prefs().Access.VisualAlerts then 6 else 1
    task.spawn(function()
        for i = 1, flashes do
            banner.BackgroundColor3 = if i % 2 == 1 then UITheme.color("Danger") else UITheme.color("Panel")
            task.wait(if UIState.prefs().Access.ReduceMotion then 0.6 else 0.3)
        end
        banner.BackgroundColor3 = UITheme.color("Danger")
        task.wait(6)
        banner.Visible = false
    end)
end

--[[
    Publie une notification (clé de traduction et paramètres). `group`
    regroupe les répétitions d'une même alerte.
]]
-- Lot 0.8 : signal sonore par niveau (AudioController) ; l'alerte reste toujours
-- VISUELLE, même son coupé ou ressource non téléversée.
local soundSink: (string) -> () = function(_level: string) end

function NotificationService.setSoundSink(sink: (string) -> ())
    soundSink = sink
end

function NotificationService.notify(
    key: string,
    level: NotificationQueue.Level?,
    params: { [string]: any }?,
    group: string?
)
    if (gui :: any) == nil then
        return
    end
    local item, display =
        NotificationQueue.push(queue, key, (level or "Info") :: any, os.clock(), context(), params, group)
    if display == "Show" or display == "Compact" then
        if item.Level == "Critical" then
            showCritical(item)
        end
        showToast(item, display == "Compact")
        soundSink(string.lower(item.Level))
    end
    for _, listener in listeners do
        task.spawn(listener)
    end
end

-- Notice du véhicule (lots 0.1–0.2) : niveau selon la clé.
function NotificationService.vehicleNotice(key: string, value: any)
    local level = VEHICLE_LEVELS[key] or "Info"
    -- Texte au format « % » des notices : paramètre transmis tel quel.
    NotificationService.notify(key, level :: any, if value ~= nil then { value = value } else nil, key)
end

function NotificationService.history(count: number): { NotificationQueue.Item }
    return NotificationQueue.recent(queue, count)
end

function NotificationService.text(item: NotificationQueue.Item): string
    return textOf(item)
end

function NotificationService.unread(): number
    return NotificationQueue.unread(queue)
end

function NotificationService.markRead()
    NotificationQueue.markAllRead(queue)
end

function NotificationService.clear()
    NotificationQueue.clear(queue)
end

function NotificationService.onChanged(listener: () -> ())
    table.insert(listeners, listener)
end

function NotificationService.start()
    local player = Players.LocalPlayer
    gui = UITheme.make(
        "ScreenGui",
        { Name = "AWNotifications", ResetOnSpawn = false, DisplayOrder = 20 },
        player:WaitForChild("PlayerGui")
    )
    -- Coin supérieur gauche : la route, le guidage et la mission restent dégagés.
    list = UITheme.make("Frame", {
        AnchorPoint = Vector2.new(0, 0),
        Position = UDim2.new(0, 16, 0, 64),
        Size = UDim2.fromOffset(400, 220),
        BackgroundTransparency = 1,
    }, gui)
    UITheme.make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)
    banner = UITheme.make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 270),
        Size = UDim2.fromOffset(560, 48),
        BackgroundColor3 = Color3.fromRGB(200, 40, 40),
        Visible = false,
    }, gui)
    UITheme.make("UICorner", { CornerRadius = UDim.new(0, 8) }, banner)
    bannerText = UITheme.label("", 18, {
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.fromOffset(10, 0),
        Font = UITheme.FontBold,
        TextWrapped = true,
    }, banner)
    -- À l'arrêt : résumé des informations différées pendant la conduite.
    UIState.onMode(function(mode)
        if mode ~= "Moving" then
            local deferred = NotificationQueue.flushDeferred(queue)
            if #deferred > 0 then
                local item = deferred[#deferred]
                showToast(item, false)
            end
        end
    end)
    -- État de la sauvegarde du profil (attribut publié par le serveur).
    local function profileState()
        local stateName = player:GetAttribute("AWProfileState")
        if stateName == "Lost" then
            NotificationService.notify("notif.sessionLost", "Critical", nil, "profile")
        elseif stateName == "SaveDelayed" then
            NotificationService.notify("notif.saveUncertain", "Critical", nil, "profile")
        end
    end
    player:GetAttributeChangedSignal("AWProfileState"):Connect(profileState)
end

return NotificationService
