-- Point d'entrée client : attend le serveur, affiche une bannière de
-- développement puis démarre le contrôleur de conduite du lot 0.1.
-- Cette bannière n'est pas le HUD automobile définitif.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Settings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProjectSettings"))
local VehicleController = require(script.Parent:WaitForChild("Vehicles"):WaitForChild("VehicleController"))
local PlaceConfig = require(ReplicatedStorage:WaitForChild("PlaceConfig")) :: { Mode: string }
local openWorld = PlaceConfig.Mode == "OpenWorld"

-- Attente événementielle : pas de boucle active consommatrice de ressources.
while ReplicatedStorage:GetAttribute("AutomotiveWorldReady") ~= true do
    ReplicatedStorage:GetAttributeChangedSignal("AutomotiveWorldReady"):Wait()
end

-- Création d'une interface strictement locale et sans action économique.
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutomotiveWorldDevelopmentStatus"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.AnchorPoint = Vector2.new(0.5, 0)
statusLabel.Position = UDim2.fromScale(0.5, 0.02)
statusLabel.Size = UDim2.fromOffset(520, 44)
statusLabel.BackgroundColor3 = Color3.fromRGB(18, 24, 33)
statusLabel.BackgroundTransparency = 0.12
statusLabel.TextColor3 = Color3.fromRGB(235, 242, 249)
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 16
statusLabel.TextWrapped = true
statusLabel.Text = string.format(
    "%s • DEV %s • CdC %s • approchez un véhicule et maintenez E",
    if openWorld then "Monde ouvert (maquette lot 0.3)" else "Zone d'essai véhicule",
    Settings.DevelopmentVersion,
    Settings.RequirementsVersion
)
statusLabel.Parent = screenGui

screenGui.Parent = playerGui

VehicleController.start()
-- Phase 1 de l'Aster (D3) : pose assise du jeu, appliquée seulement aux sièges marqués AWSeatPose.
require(script.Parent:WaitForChild("Vehicles"):WaitForChild("SeatPoseController")).start()

-- Lot 0.7 : interface commune (gestionnaire d'écrans, raccourcis, notifications,
-- HUD, GPS, carte, téléphone, groupes, paramètres). Les panneaux des lots 0.4 à
-- 0.6 s'y inscrivent ; leurs règles serveur sont inchangées.
local UI = script.Parent:WaitForChild("UI")
local UIManager = require(UI:WaitForChild("UIManager"))
local InputRouter = require(UI:WaitForChild("InputRouter"))
local NotificationService = require(UI:WaitForChild("NotificationService"))
local SettingsController = require(UI:WaitForChild("SettingsController"))
local GPSController = require(UI:WaitForChild("GPSController"))
local SocialController = require(UI:WaitForChild("SocialController"))
local MapController = require(UI:WaitForChild("MapController"))
local HUDController = require(UI:WaitForChild("HUDController"))
local PhoneController = require(UI:WaitForChild("PhoneController"))
local DevHud = require(UI:WaitForChild("DevHud"))
local UIState = require(UI:WaitForChild("UIState"))
local GaragePanel = require(UI:WaitForChild("GaragePanel"))
local EconomyPanel = require(UI:WaitForChild("EconomyPanel"))
local RacePanel = require(UI:WaitForChild("RacePanel"))
local OnboardingController = require(UI:WaitForChild("OnboardingController"))
local PhotoMode = require(UI:WaitForChild("PhotoMode"))

NotificationService.start()
local function notify(key: string, level: string, params: any?)
    NotificationService.notify(key, level :: any, params)
end
UIManager.setNotifier(notify)
GPSController.setNotifier(notify)
SocialController.setNotifier(notify)
DevHud.setNoticeSink(NotificationService.vehicleNotice)
UIManager.start()
SettingsController.start()
InputRouter.start()
GPSController.start()
SocialController.start()
MapController.start()
HUDController.setRacingCheck(RacePanel.racing)
HUDController.setMarkerSource(MapController.markers)
HUDController.start()
PhoneController.start()
-- Lots 0.4 à 0.6 : panneaux provisoires (P, J, K), désormais ouverts par UIManager.
GaragePanel.start()
EconomyPanel.start()
RacePanel.start()
-- Lot 0.8 : parcours d'arrivée (passable) et exercices de formation.
task.spawn(OnboardingController.start)
PhotoMode.setRacingCheck(RacePanel.racing)
PhotoMode.start()

InputRouter.on("Phone", function()
    UIManager.toggle("Phone")
end)
InputRouter.on("Map", function()
    UIManager.toggle("Map")
end)
InputRouter.on("Garage", function()
    UIManager.toggle("Garage")
end)
InputRouter.on("Economy", function()
    UIManager.toggle("Economy")
end)
InputRouter.on("Photo", PhotoMode.request)
InputRouter.on("Races", function()
    UIManager.toggle("Races")
end)
InputRouter.on("HudLevel", function()
    SettingsController.update(function(prefs)
        local levels = { "Minimal", "Standard", "Full" }
        local index = table.find(levels, prefs.Hud.Level) or 1
        prefs.Hud.Level = levels[index % #levels + 1] :: any
    end)
    NotificationService.notify("settings.hudLevel", "Info", { level = UIState.prefs().Hud.Level }, "hudLevel")
end)
InputRouter.on("ClearRoute", function()
    GPSController.clear()
end)
SocialController.onRaceSuggested(function(courseId: string)
    for _, point in MapController.points() do
        if point.Id == "R:" .. courseId then
            GPSController.setDestination(point.X, point.Z, point.Name, "Race")
        end
    end
end)
-- Lot 0.8 : niveau de détail, éclairage de nuit, audio et radio (les deux modes).
do
    local WorldFolder = script.Parent:WaitForChild("World")
    require(WorldFolder:WaitForChild("DetailLod")).start()
    require(WorldFolder:WaitForChild("VehicleLights")).start()
    local AudioFolder = script.Parent:WaitForChild("Audio")
    local AudioController = require(AudioFolder:WaitForChild("AudioController"))
    AudioController.start()
    NotificationService.setSoundSink(AudioController.playUi)
    local RadioController = require(AudioFolder:WaitForChild("RadioController"))
    RadioController.start()
    RadioController.onRefused(function(reason: string)
        NotificationService.notify(reason, "Warning")
    end)
    if openWorld then
        -- Zone sous la caméra (ambiances) : mise en page déjà calculée pour le GPS.
        task.defer(function()
            local WorldLayout =
                require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("World"):WaitForChild("WorldLayout"))
            AudioController.setZoneLookup(WorldLayout.get().ZoneOf)
        end)
    end
end
if openWorld then
    local WorldClient = script.Parent:WaitForChild("World")
    require(WorldClient:WaitForChild("Environment")).start()
    require(WorldClient:WaitForChild("TrafficLights")).start()
    require(WorldClient:WaitForChild("StreamAhead")).start()
    -- L'index des trottoirs se calcule une fois, sans retarder la conduite.
    task.defer(function()
        require(WorldClient:WaitForChild("Pedestrians")).start()
    end)
end
print("[AutomotiveWorld] Client de développement initialisé")
