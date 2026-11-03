--!strict
-- Météo et horloge du monde ouvert (lot 0.3), décidées par le serveur SEUL et
-- publiées en attributs de Workspace (répliqués) :
--   AWClockEpoch   instant serveur (GetServerTimeNow) où l'horloge valait StartHour ;
--   AWWeather      état courant (Clear, Rain, Fog, Storm) ;
--   AWWeatherSince instant serveur du début de l'épisode ;
--   AWRoadWetness  humidité de chaussée 0–1, lue par la physique des véhicules.
-- Chaque client calcule l'heure et l'ambiance localement à partir de ces
-- valeurs : aucun message continu, tous les joueurs voient le même ciel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeatherModel = require(Shared:WaitForChild("World"):WaitForChild("WeatherModel"))
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))

local WeatherService = {}

local UPDATE_INTERVAL_S = 1
-- Écart minimal avant de republier l'humidité (évite une réplication inutile).
local WETNESS_PUBLISH_STEP = 0.01

local started = false
local random = Random.new()
local state: WeatherModel.State = "Clear"
local episodeEnd = 0
local wetness = 0
local published = -1

local function publish(force: boolean?)
    if force or math.abs(wetness - published) >= WETNESS_PUBLISH_STEP or (wetness == 0 and published ~= 0) then
        published = wetness
        Workspace:SetAttribute(Constants.RoadWetnessAttribute, math.floor(wetness * 1000 + 0.5) / 1000)
    end
end

local function setState(newState: WeatherModel.State, now: number)
    state = newState
    episodeEnd = now + WeatherModel.duration(newState, random:NextNumber())
    Workspace:SetAttribute("AWWeather", newState)
    Workspace:SetAttribute("AWWeatherSince", now)
end

-- Force un état (outils de test en Studio, futures épreuves standardisées).
function WeatherService.force(newState: WeatherModel.State, roadWetness: number?)
    local now = Workspace:GetServerTimeNow()
    setState(newState, now)
    if roadWetness then
        wetness = math.clamp(roadWetness, 0, 1)
        publish(true)
    end
end

function WeatherService.start()
    assert(not started, "WeatherService déjà démarré")
    started = true
    local now = Workspace:GetServerTimeNow()
    Workspace:SetAttribute("AWClockEpoch", now)
    setState("Clear", now)
    publish(true)

    local accumulator = 0
    RunService.Heartbeat:Connect(function(dt)
        accumulator += dt
        if accumulator < UPDATE_INTERVAL_S then
            return
        end
        local step = accumulator
        accumulator = 0
        local time = Workspace:GetServerTimeNow()
        if time >= episodeEnd then
            setState(WeatherModel.nextState(state, random:NextNumber()), time)
        end
        wetness = WeatherModel.stepWetness(wetness, state, step)
        publish()
    end)
end

return table.freeze(WeatherService)
