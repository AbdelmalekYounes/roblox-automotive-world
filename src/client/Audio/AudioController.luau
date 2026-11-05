--!strict
--[[
    Audio côté client (lot 0.8) : moteur du véhicule conduit et des véhicules
    proches, ambiances de zone et sons d'interface.

    CONTRÔLEURS SEULEMENT : les valeurs (couches, volumes, vitesses) sont
    calculées par EngineAudioModel et AmbienceModel, mais un son n'est créé
    que si sa ressource a un identifiant Roblox réel (AssetManifest). Aucun
    son n'est téléversé aujourd'hui : rien n'est joué, et AudioController.status()
    le dit. La signature sonore n'est donc PAS livrée en jeu.

    Chaque son est rangé dans le SoundGroup de sa catégorie (Moteur,
    Environnement, Interface, Effets) dont SettingsController règle le volume.
    Véhicules observés : régime estimé depuis la vitesse (seul le véhicule
    conduit connaît son régime réel).
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetManifest = require(Shared:WaitForChild("Assets"):WaitForChild("AssetManifest"))
local EngineAudioModel = require(Shared:WaitForChild("Audio"):WaitForChild("EngineAudioModel"))
local EngineSoundProfiles = require(Shared.Audio:WaitForChild("EngineSoundProfiles"))
local AmbienceModel = require(Shared.Audio.AmbienceModel)
local WeatherModel = require(Shared:WaitForChild("World"):WaitForChild("WeatherModel"))
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))
local VehicleDefinitions = require(Shared.Vehicles.VehicleDefinitions)
local UIState = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIState"))
local DevHud = require(script.Parent.Parent.UI.DevHud)

local AudioController = {}

local S = 1 / Constants.MetersPerStud
local UPDATE_S = 0.1
-- Véhicules observés sonorisés selon la qualité (le véhicule conduit en plus).
local OBSERVED = { Low = 0, Medium = 3, High = 6 }
local HEARING_M = 80

local sounds: { [Instance]: { [string]: Sound } } = {}
local zoneOf: ((number, number) -> string?)? = nil

-- Son d'une ressource sous `parent`, créé à la première demande ; nil si la ressource n'est pas téléversée.
local function soundFor(parent: Instance, assetId: string, looped: boolean): Sound?
    local content = AssetManifest.contentId(assetId)
    if content == nil then
        return nil
    end
    local set = sounds[parent]
    if set == nil then
        set = {}
        sounds[parent] = set
        parent.Destroying:Connect(function()
            sounds[parent] = nil
        end)
    end
    local existing = (set :: { [string]: Sound })[assetId]
    if existing then
        return existing
    end
    local sound = Instance.new("Sound")
    sound.Name = assetId
    sound.SoundId = content
    sound.Looped = looped
    sound.Volume = 0
    sound.RollOffMaxDistance = HEARING_M * S
    local category = AmbienceModel.categoryOf(assetId)
    local group = if category then SoundService:FindFirstChild("AW" .. category) else nil
    if group and group:IsA("SoundGroup") then
        sound.SoundGroup = group
    end
    sound.Parent = parent
    if looped then
        sound:Play()
    end
    (set :: { [string]: Sound })[assetId] = sound
    return sound
end

-- `pitch` (Doppler, lot AUDIO-01) multiplie la vitesse de lecture de toutes les couches.
local function applyLayers(parent: Instance, layers: { EngineAudioModel.Layer }, pitch: number?)
    for _, layer in layers do
        local sound = soundFor(parent, layer.Id, true)
        if sound then
            sound.Volume = layer.Volume
            sound.PlaybackSpeed = layer.Speed * (pitch or 1)
        end
    end
end

-- ======================== Lot AUDIO-01 : profils enregistrés ========================

-- État sonore précédent de chaque véhicule (détection des événements) et dernier déclenchement par événement.
local previousState: { [Model]: EngineAudioModel.State } = {}
local lastEvent: { [Model]: { [string]: number } } = {}
-- Délai minimal entre deux occurrences d'un même événement (s) : évite les rafales (rupteur, pétarades).
local EVENT_COOLDOWN_S = { Limiter = 0.15, Pops = 0.8, BlowOff = 1.2, Shift = 0.3 }

-- État moteur d'un véhicule : réel pour le véhicule conduit, publié par le serveur pour les autres (nil : silence,
-- véhicule sans conducteur).
local function engineState(model: Model, data: any?): EngineAudioModel.State?
    if data then
        return {
            Rpm = data.EngineRpm,
            Load = data.Throttle,
            Running = data.EngineRunning ~= false and data.Stalled ~= true,
            Stalled = data.Stalled == true,
            Gear = data.Gear,
        }
    end
    if model:GetAttribute(Constants.Attributes.DriverUserId) == 0 then
        return nil
    end
    local rpm = model:GetAttribute(Constants.Attributes.AudioRpm)
    if type(rpm) ~= "number" then
        return nil
    end
    local load = model:GetAttribute(Constants.Attributes.AudioLoad)
    return {
        Rpm = rpm,
        Load = if type(load) == "number" then load else 0,
        Running = rpm > 0,
        Stalled = false,
        Gear = nil,
    }
end

-- Événements ponctuels (démarrage, rapport, rupteur, pétarades…) joués à la position du véhicule.
local function playEvents(model: Model, part: BasePart, profile: EngineAudioModel.Profile, now: EngineAudioModel.State)
    local before = previousState[model]
    previousState[model] = now
    if before == nil then
        return
    end
    local clock = os.clock()
    local fired = lastEvent[model]
    if fired == nil then
        fired = {}
        lastEvent[model] = fired
        model.Destroying:Connect(function()
            previousState[model] = nil
            lastEvent[model] = nil
        end)
    end
    for _, name in EngineAudioModel.events(profile, before, now) do
        local last = (fired :: { [string]: number })[name]
        if last == nil or clock - last >= ((EVENT_COOLDOWN_S :: any)[name] or 0) then
            (fired :: { [string]: number })[name] = clock
            local sound = soundFor(part, profile.Prefix .. string.lower(name), false)
            if sound then
                sound.Volume = profile.Gain
                sound:Play()
            end
        end
    end
end

-- Écoute depuis l'habitacle : égaliseur posé sur le groupe « Engine » (tous les moteurs entendus de la cabine).
local function applyListening(cockpit: boolean)
    local group = SoundService:FindFirstChild("AWEngine")
    if group == nil or not group:IsA("SoundGroup") then
        return
    end
    local eq = group:FindFirstChild("AWHabitacle") :: EqualizerSoundEffect?
    if eq == nil then
        local created = Instance.new("EqualizerSoundEffect")
        created.Name = "AWHabitacle"
        created.Parent = group
        eq = created
    end
    local settings = EngineAudioModel.listening(cockpit)
    local effect = eq :: EqualizerSoundEffect
    effect.LowGain = settings.LowGain
    effect.MidGain = settings.MidGain
    effect.HighGain = settings.HighGain
    effect.Enabled = cockpit
end

-- Facteur Doppler d'un véhicule observé : vitesse d'approche vers la caméra (m/s).
local function dopplerFor(part: BasePart, eye: Vector3): number
    local offset = eye - part.Position
    local distance = offset.Magnitude
    if distance < 1e-3 then
        return 1
    end
    local approach = part.AssemblyLinearVelocity:Dot(offset / distance) * Constants.MetersPerStud
    return EngineAudioModel.doppler(approach)
end

local function vehicleLayers(model: Model, data: any?, quality: string): { EngineAudioModel.Layer }?
    local definitionId = model:GetAttribute(Constants.Attributes.DefinitionId)
    local definition = VehicleDefinitions.get(definitionId :: any)
    if definition == nil then
        return nil
    end
    -- Lot AUDIO-01 : profil enregistré du modèle, s'il existe ; sinon modèle générique du lot 0.8.
    local profile = EngineSoundProfiles.Profiles[definitionId :: any]
    if profile then
        local state = engineState(model, data)
        local part = model.PrimaryPart
        if state == nil or part == nil then
            previousState[model] = nil
            return nil
        end
        playEvents(model, part, profile, state)
        return EngineAudioModel.profileLayers(profile, state, quality)
    end
    -- Véhicule observé sans conducteur : silence (plus de ralenti pour les voitures garées).
    if data == nil and model:GetAttribute(Constants.Attributes.DriverUserId) == 0 then
        return nil
    end
    local energy = definition.Powertrain.Energy.Kind
    local root = model.PrimaryPart
    local speedKmh = if data then data.SpeedKmh elseif root then root.AssemblyLinearVelocity.Magnitude / S * 3.6 else 0
    if energy == "Electric" then
        local motor = definition.Powertrain.Motor
        local top = if motor then motor.TopSpeedKmh else 200
        return EngineAudioModel.electric(speedKmh / math.max(top, 1), if data then data.Throttle else 0.3, quality)
    end
    local engine = definition.Powertrain.Engine
    if engine == nil then
        return nil
    end
    local rpm = if data
        then data.EngineRpm
        else EngineAudioModel.estimateRpm(
            speedKmh,
            engine.IdleRpm,
            engine.RedlineRpm,
            definition.Limits.MaxPlausibleSpeedKmh / 1.25
        )
    return EngineAudioModel.combustion(
        energy,
        rpm,
        if data then data.Throttle else 0.3,
        data ~= nil and data.Stalled == true,
        quality
    )
end

local ambienceHolder: Folder? = nil

local function update()
    local camera = Workspace.CurrentCamera
    if camera == nil then
        return
    end
    local quality = UIState.prefs().Graphics.Quality
    local data = DevHud.latest()
    local driven: Model? = if data then data.Model else nil
    local eye = camera.CFrame.Position

    -- Habitacle (vue cockpit) : moteurs étouffés et plus graves (lot AUDIO-01).
    applyListening(data ~= nil and data.CameraName == "Cockpit")

    -- Véhicule conduit : régime réel.
    if driven and driven.PrimaryPart then
        local layers = vehicleLayers(driven, data, quality)
        if layers then
            applyLayers(driven.PrimaryPart :: Instance, layers)
        end
    end
    -- Véhicules observés les plus proches : régime publié par le serveur (profil) ou estimé (modèle générique).
    local nearby: { { Model: Model, Distance: number } } = {}
    for _, item in CollectionService:GetTagged(Constants.VehicleTag) do
        if item:IsA("Model") and item ~= driven and item.PrimaryPart then
            local distance = (item:GetPivot().Position - eye).Magnitude / S
            if distance < HEARING_M then
                table.insert(nearby, { Model = item, Distance = distance })
            end
        end
    end
    table.sort(nearby, function(a, b)
        return a.Distance < b.Distance
    end)
    for index, entry in nearby do
        local layers = vehicleLayers(entry.Model, nil, quality)
        if layers then
            if index > (OBSERVED[quality] or 0) then
                for _, layer in layers do
                    layer.Volume = 0
                end
            end
            local part = entry.Model.PrimaryPart
            if part then
                -- Effet Doppler des véhicules observés (lot AUDIO-01).
                applyLayers(part, layers, dopplerFor(part, eye))
            end
        end
    end

    -- Ambiances : boucles locales (2D) fondues selon la zone, la météo et la vitesse.
    local holder = ambienceHolder
    if holder then
        local preset = WeatherModel.Presets[Workspace:GetAttribute("AWWeather") or "Clear"]
            or WeatherModel.Presets.Clear
        local zone = if zoneOf then (zoneOf :: (number, number) -> string?)(eye.X / S, eye.Z / S) else nil
        local mix = AmbienceModel.mix(zone, preset.RainRate, Lighting.ClockTime, if data then data.SpeedKmh else 0)
        for id, volume in mix do
            local sound = soundFor(holder, id, true)
            if sound then
                sound.Volume = volume
            end
        end
    end
end

-- Son d'interface ponctuel (notifications) ; rien si la ressource n'est pas téléversée.
function AudioController.playUi(kind: string)
    local holder = ambienceHolder
    if holder == nil then
        return
    end
    local sound = soundFor(holder, "audio.ui." .. kind, false)
    if sound then
        sound:Play()
    end
end

-- État honnête : nombre de ressources audio réellement jouables.
function AudioController.status(): { Playable: number, Declared: number }
    local playable, declared = 0, 0
    for _, asset in AssetManifest.Assets do
        if asset.Category == "Audio" then
            declared += 1
            if asset.RobloxAssetId ~= nil then
                playable += 1
            end
        end
    end
    return { Playable = playable, Declared = declared }
end

function AudioController.setZoneLookup(lookup: (number, number) -> string?)
    zoneOf = lookup
end

function AudioController.start()
    local holder = Instance.new("Folder")
    holder.Name = "AWAmbiance"
    holder.Parent = SoundService
    ambienceHolder = holder
    local timer = 0
    RunService.Heartbeat:Connect(function(dt)
        timer += dt
        if timer >= UPDATE_S then
            timer = 0
            update()
        end
    end)
end

return table.freeze(AudioController)
