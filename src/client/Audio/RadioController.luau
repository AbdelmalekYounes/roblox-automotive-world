--!strict
--[[
    Radio côté client (lot 0.8, AUD-RADIO-01). Le conducteur demande un
    changement de station au serveur (AWRadio) ; chaque occupant écoute la
    station commune (attribut AWRadioStation du véhicule) à SON volume, ou la
    coupe (préférences Audio.Radio / Audio.RadioMuted). Le son est joué en 2D,
    localement, pour les seuls occupants : aucune diffusion extérieure.
    Stations indisponibles tant que leurs pistes ne sont pas téléversées
    (AssetManifest) : aucune musique n'est jouée aujourd'hui.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RadioRules = require(Shared:WaitForChild("Audio"):WaitForChild("RadioRules"))
local AssetManifest = require(Shared:WaitForChild("Assets"):WaitForChild("AssetManifest"))
local UIState = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIState"))

local RadioController = {}

export type StationView = { Id: string, Theme: string, Available: boolean }

local remote: RemoteEvent? = nil
local player: Sound? = nil
local playingTrack: string? = nil
local refusedListener: ((string) -> ())? = nil

-- Place occupée par le joueur local et véhicule correspondant.
local function seatOf(): (RadioRules.Seat, Model?)
    local character = Players.LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local seat = humanoid and humanoid.SeatPart
    if seat == nil then
        return "None" :: RadioRules.Seat, nil
    end
    local model = seat.Parent
    if not (model and model:IsA("Model")) then
        return "None" :: RadioRules.Seat, nil
    end
    if seat.Name == "DriverSeat" then
        return "Driver" :: RadioRules.Seat, model
    elseif seat.Name == "PassengerSeat" then
        return "Passenger" :: RadioRules.Seat, model
    end
    return "None" :: RadioRules.Seat, nil
end

RadioController.seat = seatOf

function RadioController.current(): string
    local _, model = seatOf()
    local value = if model then model:GetAttribute("AWRadioStation") else nil
    return if type(value) == "string" then value else RadioRules.Off
end

function RadioController.stations(): { StationView }
    local out = {}
    for _, station in RadioRules.Stations do
        table.insert(out, {
            Id = station.Id,
            Theme = station.Theme,
            Available = RadioRules.available(station, AssetManifest.playable),
        })
    end
    return out
end

-- Demande du conducteur (le serveur revalide la place et la disponibilité).
function RadioController.setStation(id: string): (boolean, string?)
    local seat: RadioRules.Seat = seatOf()
    local ok, reason = RadioRules.setStation(seat, id, AssetManifest.playable)
    if ok and remote then
        (remote :: RemoteEvent):FireServer(id)
    end
    return ok, reason
end

function RadioController.onRefused(listener: (string) -> ())
    refusedListener = listener
end

local function update()
    local seat: RadioRules.Seat = seatOf()
    local stationId = RadioController.current()
    local audio = UIState.prefs().Audio
    local volume = RadioRules.listenVolume(seat, stationId, audio.RadioMuted, 100)
    local station = RadioRules.station(stationId)
    local track = if station and volume > 0 then station.Tracks[1] else nil
    local content = if track then AssetManifest.contentId(track) else nil
    if content == nil then
        if player then
            (player :: Sound):Stop()
        end
        playingTrack = nil
        return
    end
    local sound = player
    if sound == nil then
        local created = Instance.new("Sound")
        created.Name = "RadioLocale"
        created.Looped = true
        local group = SoundService:FindFirstChild("AWRadio")
        if group and group:IsA("SoundGroup") then
            -- Le volume personnel (et la coupure) passe par le SoundGroup Radio.
            created.SoundGroup = group
        end
        created.Parent = SoundService
        player = created
        sound = created
    end
    local radio = sound :: Sound
    if playingTrack ~= track then
        radio.SoundId = content :: string
        radio:Play()
        playingTrack = track
    end
    radio.Volume = volume
end

function RadioController.start()
    task.spawn(function()
        local found = ReplicatedStorage:WaitForChild("AWRadio", 30)
        if found and found:IsA("RemoteEvent") then
            remote = found
            found.OnClientEvent:Connect(function(kind: any, reason: any)
                if kind == "Refused" and refusedListener and type(reason) == "string" then
                    (refusedListener :: (string) -> ())(reason)
                end
            end)
        end
    end)
    local timer = 0
    RunService.Heartbeat:Connect(function(dt)
        timer += dt
        if timer >= 0.25 then
            timer = 0
            update()
        end
    end)
end

return table.freeze(RadioController)
