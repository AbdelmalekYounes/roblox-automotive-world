--!strict
-- Ambiance locale du monde ouvert (lot 0.3) : heure du jour, brume, luminosité,
-- pluie, éclairs et reflets de chaussée mouillée, calculés par CHAQUE client à
-- partir des attributs publiés par le serveur (WeatherService). Ces réglages
-- sont strictement visuels et locaux : la seule grandeur qui agit sur la
-- conduite (AWRoadWetness) est lue directement par le simulateur du véhicule.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeatherModel = require(Shared:WaitForChild("World"):WaitForChild("WeatherModel"))
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))

local Environment = {}

local UPDATE_INTERVAL_S = 0.2
-- Transition d'ambiance entre deux épisodes (s).
local BLEND_S = 12
local BASE_BRIGHTNESS = 2
local RAIN_HEIGHT_STUDS = 45

local function presetOf(value: any): WeatherModel.Preset
    return WeatherModel.Presets[if type(value) == "string" then value else "Clear"] or WeatherModel.Presets.Clear
end

function Environment.start()
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if atmosphere == nil then
        local created = Instance.new("Atmosphere")
        created.Parent = Lighting
        atmosphere = created
    end
    local air = atmosphere :: Atmosphere

    -- Pluie : émetteur local qui suit la caméra (aucune pièce répliquée).
    local rainPart = Instance.new("Part")
    rainPart.Name = "PluieLocale"
    rainPart.Anchored = true
    rainPart.CanCollide = false
    rainPart.CanQuery = false
    rainPart.CanTouch = false
    rainPart.Transparency = 1
    rainPart.Size = Vector3.new(160, 1, 160)
    local rain = Instance.new("ParticleEmitter")
    rain.Rate = 0
    rain.Lifetime = NumberRange.new(0.8, 1.1)
    rain.Speed = NumberRange.new(140, 160)
    rain.EmissionDirection = Enum.NormalId.Bottom
    rain.Orientation = Enum.ParticleOrientation.VelocityParallel
    rain.Size = NumberSequence.new(0.12)
    rain.Squash = NumberSequence.new(-3)
    rain.Transparency = NumberSequence.new(0.45)
    rain.Color = ColorSequence.new(Color3.fromRGB(200, 210, 225))
    rain.LightInfluence = 1
    rain.Parent = rainPart
    rainPart.Parent = Workspace.CurrentCamera

    local fog, haze, brightness, rainRate = air.Density, air.Haze, 1, 0
    local flashUntil, nextFlash = 0, 0
    local random = Random.new()
    local accumulator = 0

    RunService.RenderStepped:Connect(function(dt)
        local camera = Workspace.CurrentCamera
        if camera then
            rainPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, RAIN_HEIGHT_STUDS, 0))
        end
        accumulator += dt
        if accumulator < UPDATE_INTERVAL_S then
            return
        end
        local step = accumulator
        accumulator = 0

        local now = Workspace:GetServerTimeNow()
        local epoch = Workspace:GetAttribute("AWClockEpoch")
        if type(epoch) == "number" then
            Lighting.ClockTime = WeatherModel.clockTime(now, epoch)
        end

        local preset = presetOf(Workspace:GetAttribute("AWWeather"))
        local blend = math.clamp(step / BLEND_S, 0, 1)
        fog += (preset.FogDensity - fog) * blend
        haze += (preset.Haze - haze) * blend
        brightness += (preset.Brightness - brightness) * blend
        rainRate += (preset.RainRate - rainRate) * blend
        air.Density = fog
        air.Haze = haze
        rain.Rate = rainRate

        -- Éclairs d'orage : brefs flashs locaux, à intervalle aléatoire.
        local flash = 0
        if preset.Lightning then
            if now >= nextFlash then
                flashUntil = now + 0.12
                nextFlash = now + random:NextNumber(7, 20)
            end
            if now < flashUntil then
                flash = 3
            end
        end
        Lighting.Brightness = BASE_BRIGHTNESS * brightness + flash

        -- Chaussée mouillée : reflets plus marqués (visuel seulement).
        local wet = Workspace:GetAttribute(Constants.RoadWetnessAttribute)
        local wetness = if type(wet) == "number" then wet else 0
        Lighting.EnvironmentSpecularScale = 0.4 + 0.6 * wetness
    end)
end

return table.freeze(Environment)
