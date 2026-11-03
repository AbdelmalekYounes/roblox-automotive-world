--!strict
-- Couleur des feux tricolores, calculée localement par chaque client avec la
-- même règle déterministe que le trafic PNJ du serveur (World/Signals) : aucun
-- message réseau, et les PNJ s'arrêtent exactement quand le feu est rouge.
-- Seules les lampes reçues (streaming) et proches de la caméra sont mises à jour.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signals = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("World"):WaitForChild("Signals"))

local TrafficLights = {}

local UPDATE_INTERVAL_S = 0.25
local VISIBLE_STUDS = 1500
local COLORS = table.freeze({
    Green = Color3.fromRGB(40, 220, 90),
    Amber = Color3.fromRGB(255, 170, 30),
    Red = Color3.fromRGB(230, 40, 40),
})

function TrafficLights.start()
    local accumulator = 0
    RunService.Heartbeat:Connect(function(dt)
        accumulator += dt
        if accumulator < UPDATE_INTERVAL_S then
            return
        end
        accumulator = 0
        local camera = Workspace.CurrentCamera
        if camera == nil then
            return
        end
        local origin = camera.CFrame.Position
        local now = Workspace:GetServerTimeNow()
        for _, lamp in CollectionService:GetTagged("AWTrafficLight") do
            if lamp:IsA("BasePart") and (lamp.Position - origin).Magnitude < VISIBLE_STUDS then
                local node = lamp:GetAttribute("NodeId")
                local group = lamp:GetAttribute("Group")
                if type(node) == "string" and type(group) == "number" then
                    local color = COLORS[Signals.state(node, group, now)]
                    if lamp.Color ~= color then
                        lamp.Color = color
                    end
                end
            end
        end
    end)
end

return table.freeze(TrafficLights)
