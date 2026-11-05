--!strict
-- Chargement anticipé des secteurs (lot 0.3). Les routes et leurs collisions
-- sont persistantes (toujours présentes chez le client) ; le décor et le
-- relief arrivent par secteur. Pour un véhicule rapide, on demande au moteur
-- de charger en avance la zone où il sera dans LOOKAHEAD_S secondes
-- (Player:RequestStreamAroundAsync), sans jamais bloquer la conduite.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants =
    require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))

local StreamAhead = {}

local INTERVAL_S = 1
local LOOKAHEAD_S = 4
local MIN_SPEED_MS = 15
local REQUEST_TIMEOUT_S = 2

function StreamAhead.start()
    if not Workspace.StreamingEnabled then
        return
    end
    local player = Players.LocalPlayer
    local pending = false
    local accumulator = 0
    RunService.Heartbeat:Connect(function(dt)
        accumulator += dt
        if accumulator < INTERVAL_S or pending then
            return
        end
        accumulator = 0
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local seat = humanoid and humanoid.SeatPart
        if seat == nil then
            return
        end
        local velocity = seat.AssemblyLinearVelocity
        if velocity.Magnitude * Constants.MetersPerStud < MIN_SPEED_MS then
            return
        end
        local target = seat.Position + velocity * LOOKAHEAD_S
        pending = true
        task.spawn(function()
            -- Échec possible (limite de requêtes) : sans conséquence, on réessaiera.
            pcall(player.RequestStreamAroundAsync, player, target, REQUEST_TIMEOUT_S)
            pending = false
        end)
    end)
end

return table.freeze(StreamAhead)
