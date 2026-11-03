--!strict
--[[
    Radio des véhicules (lot 0.8, AUD-RADIO-01), autorité serveur : seul le
    conducteur ASSIS sur le siège conducteur peut changer la station commune
    (attribut répliqué AWRadioStation du véhicule). La station doit être
    disponible (pistes téléversées, AssetManifest) ; aujourd'hui aucune ne
    l'est, donc seule « Off » est acceptée. Le volume et la coupure sont
    personnels et restent côté client (préférences).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RadioRules = require(Shared:WaitForChild("Audio"):WaitForChild("RadioRules"))
local AssetManifest = require(Shared:WaitForChild("Assets"):WaitForChild("AssetManifest"))
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))
local RateLimiter = require(script.Parent.Parent.Security.RateLimiter)

local RadioService = {}

RadioService.Attribute = "AWRadioStation"

local limiters: { [Player]: RateLimiter.Bucket } = {}

-- Véhicule dont le joueur occupe le siège conducteur (nil sinon).
local function drivenVehicle(player: Player): Model?
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local seat = humanoid and humanoid.SeatPart
    if seat == nil or seat.Name ~= "DriverSeat" then
        return nil
    end
    local model = seat.Parent
    if model and model:IsA("Model") and CollectionService:HasTag(model, Constants.VehicleTag) then
        return model
    end
    return nil
end

function RadioService.start()
    local existing = ReplicatedStorage:FindFirstChild("AWRadio")
    if existing then
        existing:Destroy()
    end
    local remote = Instance.new("RemoteEvent")
    remote.Name = "AWRadio"
    remote.Parent = ReplicatedStorage
    remote.OnServerEvent:Connect(function(player: Player, stationId: any)
        local bucket = limiters[player]
        if bucket == nil then
            bucket = RateLimiter.new(4, 1, os.clock())
            limiters[player] = bucket
        end
        if not RateLimiter.consume(bucket, os.clock()) then
            return
        end
        local vehicle = drivenVehicle(player)
        local ok, reason =
            RadioRules.setStation(if vehicle then "Driver" else "None", stationId, AssetManifest.playable)
        if ok and vehicle then
            vehicle:SetAttribute(RadioService.Attribute, stationId)
        else
            remote:FireClient(player, "Refused", reason)
        end
    end)
    Players.PlayerRemoving:Connect(function(player)
        limiters[player] = nil
    end)
end

return table.freeze(RadioService)
