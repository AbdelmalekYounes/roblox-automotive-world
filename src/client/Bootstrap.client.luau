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
