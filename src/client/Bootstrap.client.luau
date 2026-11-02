-- Point d'entrée client : attend le serveur et affiche une bannière de développement.
-- Cette bannière n'est pas le HUD automobile définitif.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Settings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ProjectSettings"))

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
statusLabel.Size = UDim2.fromOffset(430, 44)
statusLabel.BackgroundColor3 = Color3.fromRGB(18, 24, 33)
statusLabel.BackgroundTransparency = 0.12
statusLabel.TextColor3 = Color3.fromRGB(235, 242, 249)
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 16
statusLabel.TextWrapped = true
statusLabel.Text = string.format(
    "Socle technique chargé • DEV %s • CdC %s",
    Settings.DevelopmentVersion,
    Settings.RequirementsVersion
)
statusLabel.Parent = screenGui

screenGui.Parent = playerGui
print("[AutomotiveWorld] Client de développement initialisé")
