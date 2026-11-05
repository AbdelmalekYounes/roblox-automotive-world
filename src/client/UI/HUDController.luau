--!strict
--[[
    HUD de conduite CONTEXTUEL (lot 0.7, §7.1) : remplace le HUD de
    développement pour le joueur (celui-ci reste disponible dans les
    paramètres).

    Niveaux :
    - Minimal : vitesse, rapport, navigation essentielle, alertes ;
    - Standard : + régime (barre), énergie, boîte, aides, mini-carte, mission ;
    - Complet : + régime chiffré, état mécanique détaillé, aides détaillées.
    Contextes : vue cockpit → tableau réduit (l'habitacle porte déjà les
    informations) ; course → position, temps, tour, point, pénalités, drift
    (affichage de course du lot 0.6), mission et navigation masquées ; à
    pied → aucune donnée automobile (mini-carte et navigation restent).
    Réglages : niveau, taille, coin d'écran, mini-carte (zoom, orientation),
    informations en conduite. Alertes énergie et mécanique : toujours
    perceptibles (service de notifications).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared:WaitForChild("UI"):WaitForChild("Localization"))
local MapProjection = require(Shared:WaitForChild("Navigation"):WaitForChild("MapProjection"))
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))

local UIState = require(script.Parent.UIState)
local UITheme = require(script.Parent.UITheme)
local DevHud = require(script.Parent.DevHud)
local GPSController = require(script.Parent.GPSController)
local MapRenderer = require(script.Parent.MapRenderer)
local NotificationService = require(script.Parent.NotificationService)
local SocialController = require(script.Parent.SocialController)

local HUDController = {}

local S = 1 / Constants.MetersPerStud
local MINIMAP_SIZE = 190
local ZOOM_SPANS = { 260, 520, 1100, 2400 } -- mètres couverts par la mini-carte

local gui: ScreenGui
local cluster: Frame
local scale: UIScale
local speedLabel: TextLabel
local gearLabel: TextLabel
local subLabel: TextLabel
local rpmBar: Frame
local rpmFill: Frame
local energyBar: Frame
local energyFill: Frame
local infoLabel: TextLabel
local alertLabel: TextLabel
local minimapFrame: Frame
local renderer: MapRenderer.Renderer
local turnFrame: Frame
local turnLabel: TextLabel
local remainingLabel: TextLabel
local racingCheck: () -> boolean = function()
    return false
end
local poiSource: () -> { MapRenderer.Marker } = function()
    return {}
end
local alerted: { [string]: boolean } = {}

function HUDController.setRacingCheck(fn: () -> boolean)
    racingCheck = fn
end

function HUDController.setMarkerSource(fn: () -> { MapRenderer.Marker })
    poiSource = fn
end

local function bar(parent: Instance, y: number, color: Color3): (Frame, Frame)
    local frame = UITheme.make("Frame", {
        Position = UDim2.fromOffset(14, y),
        Size = UDim2.new(1, -28, 0, 6),
        BackgroundColor3 = UITheme.color("PanelRaised"),
        BorderSizePixel = 0,
    }, parent)
    local fill =
        UITheme.make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color, BorderSizePixel = 0 }, frame)
    return frame, fill
end

local function build()
    local player = Players.LocalPlayer
    gui = UITheme.make(
        "ScreenGui",
        { Name = "AWHud", ResetOnSpawn = false, DisplayOrder = 5 },
        player:WaitForChild("PlayerGui")
    )
    cluster = UITheme.panel({ Name = "Tableau", Size = UDim2.fromOffset(260, 132), Visible = false }, gui)
    scale = UITheme.make("UIScale", {}, cluster)
    speedLabel = UITheme.label("0", 40, {
        Position = UDim2.fromOffset(14, 6),
        Size = UDim2.fromOffset(150, 46),
        Font = UITheme.FontBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, cluster)
    gearLabel = UITheme.label("N", 36, {
        Position = UDim2.new(1, -74, 0, 6),
        Size = UDim2.fromOffset(60, 46),
        Font = UITheme.FontBold,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextColor3 = UITheme.color("Accent"),
    }, cluster)
    subLabel = UITheme.label("", 13, {
        Position = UDim2.fromOffset(14, 50),
        Size = UDim2.new(1, -28, 0, 16),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = UITheme.color("TextDim"),
    }, cluster)
    rpmBar, rpmFill = bar(cluster, 70, UITheme.color("Warn"))
    energyBar, energyFill = bar(cluster, 82, UITheme.color("Good"))
    infoLabel = UITheme.label("", 12, {
        Position = UDim2.fromOffset(14, 92),
        Size = UDim2.new(1, -28, 0, 18),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = UITheme.color("TextDim"),
        TextWrapped = true,
    }, cluster)
    alertLabel = UITheme.label("", 13, {
        Position = UDim2.fromOffset(14, 110),
        Size = UDim2.new(1, -28, 0, 18),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = UITheme.color("Danger"),
        Font = UITheme.FontMedium,
    }, cluster)
    minimapFrame = UITheme.panel({ Name = "MiniCarte", Size = UDim2.fromOffset(MINIMAP_SIZE, MINIMAP_SIZE) }, gui)
    renderer = MapRenderer.new(minimapFrame, 450, nil)
    turnFrame = UITheme.panel({
        Name = "Guidage",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 100),
        Size = UDim2.fromOffset(380, 54),
        Visible = false,
    }, gui)
    turnLabel = UITheme.label("", 18, {
        Position = UDim2.fromOffset(12, 4),
        Size = UDim2.new(1, -24, 0, 26),
        Font = UITheme.FontBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, turnFrame)
    remainingLabel = UITheme.label("", 13, {
        Position = UDim2.fromOffset(12, 30),
        Size = UDim2.new(1, -24, 0, 18),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = UITheme.color("TextDim"),
    }, turnFrame)
end

-- Placement selon les préférences (coin, taille).
local function layout()
    local prefs = UIState.prefs()
    scale.Scale = prefs.Hud.Scale / 100
    local left = prefs.Hud.Corner == "BottomLeft"
    cluster.AnchorPoint = Vector2.new(if left then 0 else 1, 1)
    cluster.Position = if left then UDim2.new(0, 16, 1, -16) else UDim2.new(1, -16, 1, -16)
    minimapFrame.AnchorPoint = Vector2.new(if left then 0 else 1, 1)
    local lift = math.floor(132 * scale.Scale) + 26
    minimapFrame.Position = if left then UDim2.new(0, 16, 1, -lift) else UDim2.new(1, -16, 1, -lift)
    cluster.BackgroundTransparency = UITheme.panelTransparency()
    minimapFrame.BackgroundTransparency = UITheme.panelTransparency()
end

local function gearText(data: any): string
    return data.GearLabel or (if data.Gear < 0 then "R" elseif data.Gear == 0 then "N" else tostring(data.Gear))
end

local function aidsText(data: any, detailed: boolean): string
    local parts = {}
    for _, aid in data.Aids do
        if aid.Status ~= "Absente" then
            if detailed then
                table.insert(
                    parts,
                    string.format(
                        "%s %s",
                        aid.Label,
                        -- QA-F14 : « ✕ » / « ✓ » absents de la police : signes rendus partout.
                        if aid.Status == "Off" then "×" elseif aid.Status == "Active" then "!" else "●"
                    )
                )
            elseif aid.Status == "Active" then
                table.insert(parts, aid.Label .. " !")
            end
        end
    end
    return table.concat(parts, "  ")
end

-- Alertes énergie et mécanique : franchissements de seuils notifiés une fois.
local function alerts(data: any): string
    local lines = {}
    local percent = math.floor(data.EnergyFraction * 100 + 0.5)
    local function once(key: string, condition: boolean, level: any, params: any?)
        if condition and not alerted[key] then
            alerted[key] = true
            NotificationService.notify(key, level, params, key)
        elseif not condition then
            alerted[key] = nil
        end
    end
    once(
        if data.Electric then "notif.lowBattery" else "notif.lowFuel",
        percent <= 15 and percent > 0,
        "Warning",
        { percent = percent }
    )
    local model = data.Model :: Model?
    local engine = if model then model:GetAttribute("DmgEngine") else nil
    local steering = if model then model:GetAttribute("DmgSteering") else nil
    local engineHealth = if type(engine) == "number" then engine else 1
    local steeringHealth = if type(steering) == "number" then steering else 1
    once("notif.heavyDamage", engineHealth < 0.5 or steeringHealth < 0.5, "Warning")
    once("notif.mechanicalFailure", engineHealth < 0.2 or steeringHealth < 0.25, "Critical")
    if engineHealth < 0.5 then
        table.insert(lines, Localization.t("hud.engineDamaged"))
    end
    if steeringHealth < 0.5 then
        table.insert(lines, Localization.t("hud.steeringDamaged"))
    end
    if data.Stalled then
        table.insert(lines, Localization.t("hud.stalled"))
    end
    return table.concat(lines, " • ")
end

local function updateCluster()
    local data = DevHud.latest()
    local prefs = UIState.prefs()
    if data == nil then
        cluster.Visible = false
        alerted = {}
        return
    end
    cluster.Visible = true
    local level = prefs.Hud.Level
    local racing = racingCheck()
    local cockpit = data.CameraName == "Cockpit"
    speedLabel.Text = string.format("%d %s", math.floor(data.SpeedKmh + 0.5), Localization.t("hud.kmh"))
    gearLabel.Text = gearText(data)
    local standard = level ~= "Minimal" and not cockpit
    local full = level == "Full" and not cockpit
    rpmBar.Visible = standard
    energyBar.Visible = standard
    rpmFill.Size = UDim2.fromScale(math.clamp(data.EngineRpm / math.max(data.RedlineRpm, 1), 0, 1), 1)
    rpmFill.BackgroundColor3 = if data.EngineRpm >= data.RedlineRpm * 0.92
        then UITheme.color("Danger")
        else UITheme.color("Warn")
    energyFill.Size = UDim2.fromScale(math.clamp(data.EnergyFraction, 0, 1), 1)
    energyFill.BackgroundColor3 = if data.EnergyFraction < 0.15 then UITheme.color("Danger") else UITheme.color("Good")
    local transmission = if data.TransmissionKind
        then Localization.t("hud.transmission." .. data.TransmissionKind)
        else ""
    if full then
        subLabel.Text = string.format(
            "%s • %d %s • %s %d %%",
            transmission,
            math.floor(data.EngineRpm),
            Localization.t("hud.rpm"),
            Localization.t(if data.Electric then "hud.battery" else "hud.fuel"),
            math.floor(data.EnergyFraction * 100 + 0.5)
        )
    elseif standard then
        subLabel.Text = string.format(
            "%s • %s %d %%",
            transmission,
            Localization.t(if data.Electric then "hud.battery" else "hud.fuel"),
            math.floor(data.EnergyFraction * 100 + 0.5)
        )
    else
        subLabel.Text = ""
    end
    infoLabel.Text = if standard and not racing then aidsText(data, full) else ""
    if full and not racing then
        infoLabel.Text ..= (if infoLabel.Text ~= "" then " • " else "") .. data.EngineText
    end
    -- Alertes critiques toujours visibles, quel que soit le niveau.
    alertLabel.Text = alerts(data)
end

local function updateGuidance()
    local gps = GPSController.state()
    local prefs = UIState.prefs()
    local progress = gps.Progress
    local show = gps.Status ~= "Idle" and not racingCheck() and (prefs.Hud.DrivingInfo or UIState.mode() ~= "Moving")
    turnFrame.Visible = show
    if not show then
        return
    end
    if gps.Status == "Computing" then
        turnLabel.Text = Localization.t("gps.computing")
        remainingLabel.Text = if gps.Destination then gps.Destination.Label else ""
        return
    elseif gps.Status == "NoRoute" or gps.Status == "Invalid" then
        turnLabel.Text = Localization.t(if gps.Status == "Invalid" then "gps.invalid" else "gps.noRoute")
        remainingLabel.Text = ""
        return
    elseif gps.Status == "Arrived" then
        turnLabel.Text = Localization.t("gps.arrived")
        remainingLabel.Text = if gps.Destination then gps.Destination.Label else ""
        return
    end
    if progress == nil then
        return
    end
    local nextManeuver = progress.Next
    if nextManeuver then
        local action = Localization.t("gps.turn." .. nextManeuver.Kind)
        if nextManeuver.Road and nextManeuver.Kind ~= "Arrive" then
            action = Localization.t("gps.onto", { action = action, road = nextManeuver.Road })
        end
        turnLabel.Text =
            Localization.t("gps.in", { distance = Localization.distance(progress.ToNextM), action = action })
    end
    remainingLabel.Text = string.format(
        "%s — %s",
        if gps.Destination then gps.Destination.Label else "",
        Localization.t("gps.remaining", {
            distance = Localization.distance(progress.RemainingM),
            minutes = math.max(1, math.ceil(progress.RemainingS / 60)),
        })
    )
end

local function updateMinimap()
    local prefs = UIState.prefs()
    minimapFrame.Visible = prefs.Hud.ShowMinimap
        and (prefs.Hud.Level ~= "Minimal" or GPSController.state().Status ~= "Idle")
    if not minimapFrame.Visible then
        return
    end
    local character = Players.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root == nil or not root:IsA("BasePart") then
        return
    end
    local x, z = root.Position.X / S, root.Position.Z / S
    local look = root.CFrame.LookVector
    local heading = math.atan2(look.X, -look.Z)
    local span = ZOOM_SPANS[prefs.Hud.MinimapZoom] or ZOOM_SPANS[2]
    local view = MapProjection.view(
        x,
        z,
        MINIMAP_SIZE / span,
        if prefs.Hud.MinimapRotate then heading else 0,
        MINIMAP_SIZE,
        MINIMAP_SIZE
    )
    local markers = table.clone(poiSource())
    local gps = GPSController.state()
    if gps.Destination then
        table.insert(markers, {
            X = gps.Destination.X,
            Z = gps.Destination.Z,
            Kind = if gps.Destination.Source == "Mission" then "MissionTarget" else "Destination",
        })
    end
    if prefs.Social.ShowSharedMembers then
        for _, member in SocialController.positions() do
            table.insert(markers, { X = member.X, Z = member.Z, Kind = "GroupMember", Name = member.Name })
        end
    end
    renderer:draw({
        View = view,
        Index = GPSController.mapIndex(),
        Route = if gps.Plan then gps.Plan.Points else nil,
        Markers = markers,
        PlayerHeading = heading,
        PlayerX = x,
        PlayerZ = z,
        ClampMarkers = true,
    })
end

function HUDController.start()
    build()
    layout()
    UIState.onPrefs(layout)
    RunService.RenderStepped:Connect(updateCluster)
    local timer = 0
    RunService.Heartbeat:Connect(function(dt)
        timer += dt
        if timer >= 0.2 then
            timer = 0
            updateGuidance()
            updateMinimap()
        end
    end)
end

return HUDController
