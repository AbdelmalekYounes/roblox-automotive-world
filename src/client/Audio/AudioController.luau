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
local TireAudioModel = require(Shared.Audio:WaitForChild("TireAudioModel"))
local CollisionAudioModel = require(Shared.Audio:WaitForChild("CollisionAudioModel"))
local Players = game:GetService("Players")
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
-- Charge lissée du véhicule conduit : suit la charge RÉELLE du moteur (nulle pendant un passage de rapport) avec une
-- constante de temps courte, pour un creux net mais sans claquement à chaque passage.
local LOAD_SMOOTHING_S = 0.06
local drivenLoad = 0
-- Rétrogradage (demande du propriétaire : rendre les descentes de rapport audibles) : en décélération, la charge est
-- déjà nulle et le convertisseur garde le régime presque constant ; un bref coup de gaz SONORE (aucun effet physique),
-- comme l'égalisation de régime de nombreuses boîtes, signale le passage.
local DOWNSHIFT_BLIP_LOAD = 0.35
local DOWNSHIFT_BLIP_S = 0.15
local lastGear: number? = nil
local blipUntil = 0

local function engineState(model: Model, data: any?): EngineAudioModel.State?
    if data then
        return {
            Rpm = data.EngineRpm,
            Load = drivenLoad,
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
-- Les événements comparent deux relevés espacés d'au moins 0,1 s : le véhicule conduit est mis à jour à chaque image,
-- et une chute de régime ou un lever de pied ne se voit pas d'une image à la suivante.
local EVENT_SPACING_S = 0.1
local lastEvaluation: { [Model]: number } = {}

local function playEvents(model: Model, part: BasePart, profile: EngineAudioModel.Profile, now: EngineAudioModel.State)
    local clock = os.clock()
    if previousState[model] ~= nil and clock - (lastEvaluation[model] or 0) < EVENT_SPACING_S then
        return
    end
    lastEvaluation[model] = clock
    local before = previousState[model]
    previousState[model] = now
    if before == nil then
        return
    end
    local fired = lastEvent[model]
    if fired == nil then
        fired = {}
        lastEvent[model] = fired
        model.Destroying:Connect(function()
            previousState[model] = nil
            lastEvent[model] = nil
            lastEvaluation[model] = nil
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

-- Écoute depuis l'habitacle : égaliseur posé sur le groupe « Engine » (tous les moteurs entendus de la cabine) et,
-- depuis le lot AUDIO-03, sur le groupe « Effects » (pneus, vent : décision Q4 du propriétaire).
local function equalizeGroup(groupName: string, cockpit: boolean)
    local group = SoundService:FindFirstChild(groupName)
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

local function applyListening(cockpit: boolean)
    equalizeGroup("AWEngine", cockpit)
    equalizeGroup("AWEffects", cockpit)
end

-- ======================== Lot AUDIO-03 : sons des pneus ========================
-- Masse du modèle (kg) : un véhicule lourd roule plus fort et plus grave (TireAudioModel.layers).
local function massOf(model: Model): number
    local definition = VehicleDefinitions.get(model:GetAttribute(Constants.Attributes.DefinitionId) :: any)
    return if definition then definition.Chassis.MassKg else TireAudioModel.ReferenceMassKg
end

-- Humidité de la chaussée due à la météo (même attribut que la physique, VehicleSimulator).
local function roadWetness(): number
    local value = Workspace:GetAttribute(Constants.RoadWetnessAttribute)
    return if type(value) == "number" then math.clamp(value, 0, 1) else 0
end

-- Véhicule observé : glissement et revêtement publiés par le serveur (déclaration bornée du conducteur), vitesse
-- répliquée, humidité locale. Sans conducteur : roulement seul, d'après la vitesse (véhicule poussé ou en roue libre).
local function observedTireLayers(model: Model, part: BasePart, quality: string): { TireAudioModel.Layer }
    local slip = model:GetAttribute(Constants.Attributes.AudioTireSlip)
    local surface = model:GetAttribute(Constants.Attributes.AudioTireSurface)
    local speedMs = part.AssemblyLinearVelocity.Magnitude * Constants.MetersPerStud
    local summary = TireAudioModel.observed(if type(slip) == "number" then slip else 0, surface, speedMs, roadWetness())
    return TireAudioModel.layers(summary, massOf(model), quality)
end

-- Applique les couches des pneus sans créer de son tant qu'une couche est muette : six boucles par véhicule, la
-- plupart silencieuses (revêtement absent, aucun glissement) ; un son créé reste en place et suit son volume.
local function applyTireLayers(parent: Instance, layers: { TireAudioModel.Layer }, pitch: number?)
    local existing = sounds[parent]
    local audible: { TireAudioModel.Layer } = {}
    for _, layer in layers do
        if layer.Volume > 0 or (existing and existing[layer.Id]) then
            table.insert(audible, layer)
        end
    end
    applyLayers(parent, audible, pitch)
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

-- ======================== Lot AUDIO-04 : bruits de collision ========================
local METERS_PER_STUD = Constants.MetersPerStud
local HISTORY_S = 0.35
local SCRAPE_MARGIN_STUDS = 0.4
local IMPACT_MARGIN_STUDS = 1.2
-- Un choc entre deux véhicules n'est joué qu'une fois : la diffusion du serveur est ignorée si le véhicule conduit
-- vient d'entendre son propre choc contre un véhicule.
local VEHICLE_DEDUP_S = 0.6
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.RespectCanCollide = true
local drivenHistory: { { Time: number, X: number, Z: number } } = {}
local drivenHistoryModel: Model? = nil
local impactCooldownUntil = 0
local lastLocalVehicleImpact = -math.huge
local scrapeTimer = 0
local SCRAPE_DRIVEN_S = 0.05

local function isVehicle(part: BasePart): boolean
    local model = part:FindFirstAncestorOfClass("Model")
    while model do
        if CollectionService:HasTag(model, Constants.VehicleTag) then
            return true
        end
        model = model:FindFirstAncestorOfClass("Model")
    end
    return false
end

-- Pièces au contact de la carrosserie (au-dessus des roues ; le sol et les bordures basses ne comptent pas), comme
-- DamageService. `margin` : marge autour de la caisse (studs).
local function contactParts(model: Model, root: BasePart, margin: number): { BasePart }
    local definition = VehicleDefinitions.get(model:GetAttribute(Constants.Attributes.DefinitionId) :: any)
    if definition == nil then
        return {}
    end
    local chassis = definition.Chassis
    local cg = chassis.CgHeightM * S
    local bottom, top = -0.5, chassis.HeightM * S - cg
    local size = Vector3.new(chassis.WidthM * S + 2 * margin, top - bottom, chassis.LengthM * S + 2 * margin)
    local excluded: { Instance } = { model }
    for _, player in Players:GetPlayers() do
        if player.Character then
            table.insert(excluded, player.Character)
        end
    end
    overlap.FilterDescendantsInstances = excluded
    return Workspace:GetPartBoundsInBox(root.CFrame * CFrame.new(0, (top + bottom) / 2, 0), size, overlap)
end

local function playShot(parent: Instance, shot: CollisionAudioModel.Shot)
    local sound = soundFor(parent, shot.Id, false)
    if sound then
        sound.Volume = shot.Volume
        sound.PlaybackSpeed = shot.Speed
        sound:Play()
    end
end

-- Véhicule conduit : choc détecté LOCALEMENT, sans attendre le serveur (vitesse simulée ici, obstacle au contact du
-- côté opposé à la poussée). Purement sonore.
local function detectDrivenImpact(model: Model, root: BasePart)
    if drivenHistoryModel ~= model then
        drivenHistoryModel = model
        table.clear(drivenHistory)
    end
    local now = os.clock()
    local velocity = root.AssemblyLinearVelocity * METERS_PER_STUD
    local excess = CollisionAudioModel.excess(drivenHistory, now, velocity.X, velocity.Z)
    -- Poussée : variation depuis le relevé le plus ancien (sens du choc).
    local oldest = drivenHistory[1]
    table.insert(drivenHistory, { Time = now, X = velocity.X, Z = velocity.Z })
    while #drivenHistory > 0 and now - drivenHistory[1].Time > HISTORY_S do
        table.remove(drivenHistory, 1)
    end
    if excess < CollisionAudioModel.MinImpactMs or now < impactCooldownUntil or oldest == nil then
        return
    end
    local push = Vector3.new(velocity.X - oldest.X, 0, velocity.Z - oldest.Z)
    if push.Magnitude < 1e-3 then
        return
    end
    push = push.Unit
    local best: BasePart? = nil
    local bestScore = -math.huge
    for _, part in contactParts(model, root, IMPACT_MARGIN_STUDS) do
        local offset = part.Position - root.Position
        offset = Vector3.new(offset.X, 0, offset.Z)
        local score = if offset.Magnitude > 1e-3 then offset.Unit:Dot(-push) else 0
        if score > bestScore then
            bestScore = score
            best = part
        end
    end
    if best == nil or bestScore <= -0.2 then
        return -- variation de vitesse sans obstacle (saut, réapparition) : pas de choc
    end
    local obstacle = best :: BasePart
    local vehicleHit = isVehicle(obstacle)
    local kind =
        CollisionAudioModel.classify(vehicleHit, obstacle.Anchored, obstacle.AssemblyMass * 1000 * METERS_PER_STUD ^ 3)
    local shot = CollisionAudioModel.impact(kind, excess, math.random())
    if shot then
        impactCooldownUntil = now + CollisionAudioModel.ImpactCooldownS
        if vehicleHit then
            lastLocalVehicleImpact = now
        end
        playShot(root, shot)
    end
end

-- Raclement : boucle sur la caisse, selon le contact et la vitesse horizontale.
local function updateScrape(model: Model, root: BasePart, pitch: number?)
    local velocity = root.AssemblyLinearVelocity
    local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude * METERS_PER_STUD
    local contact = speed > CollisionAudioModel.ScrapeMinSpeed and #contactParts(model, root, SCRAPE_MARGIN_STUDS) > 0
    local shot = CollisionAudioModel.scrape(contact, speed)
    local existing = sounds[root]
    if shot.Volume <= 0 and not (existing and existing[shot.Id]) then
        return -- aucun son créé tant qu'il n'y a jamais eu de raclement
    end
    local sound = soundFor(root, shot.Id, true)
    if sound then
        sound.Volume = shot.Volume
        sound.PlaybackSpeed = shot.Speed * (pitch or 1)
    end
end

-- Diffusion du serveur (autres joueurs, bris d'optique) : véhicule, famille, intensité, position.
local function onImpactSound(model: any, kind: any, intensity: any, position: any)
    if typeof(model) ~= "Instance" or not model:IsA("Model") or type(kind) ~= "string" then
        return
    end
    if type(intensity) ~= "number" or intensity ~= intensity or typeof(position) ~= "Vector3" then
        return
    end
    local root = (model :: Model).PrimaryPart
    local camera = Workspace.CurrentCamera
    if root == nil or camera == nil or (position - camera.CFrame.Position).Magnitude / S > HEARING_M then
        return
    end
    local data = DevHud.latest()
    local driven = if data then data.Model else nil
    if kind == "Glass" then
        playShot(root, CollisionAudioModel.glass(math.random()))
        return
    end
    if model == driven then
        return -- déjà joué localement, sans délai
    end
    if kind == "Vehicle" and driven and os.clock() - lastLocalVehicleImpact < VEHICLE_DEDUP_S then
        return -- même choc entre deux véhicules, déjà entendu par le conducteur
    end
    if kind ~= "Hard" and kind ~= "Object" and kind ~= "Vehicle" then
        return
    end
    local shot = CollisionAudioModel.impact(kind :: any, math.clamp(intensity, 0, 60), math.random())
    if shot then
        playShot(root, shot)
    end
end

-- Véhicule conduit : régime réel, recalculé À CHAQUE IMAGE (lot AUDIO-01, retour d'écoute du propriétaire : une
-- mise à jour toutes les 0,1 s faisait entendre des marches de volume et de hauteur). Habitacle en vue cockpit.
local lastCockpit: boolean? = nil
local function updateDriven(dt: number)
    local data = DevHud.latest()
    local target = if data then (data.EngineLoad or data.Throttle) else 0
    local gear = if data then data.Gear else nil
    if gear and lastGear and gear >= 1 and gear < lastGear then
        blipUntil = os.clock() + DOWNSHIFT_BLIP_S
    end
    lastGear = gear
    if os.clock() < blipUntil then
        target = math.max(target, DOWNSHIFT_BLIP_LOAD)
    end
    drivenLoad += (target - drivenLoad) * (1 - math.exp(-dt / LOAD_SMOOTHING_S))
    local cockpit = data ~= nil and data.CameraName == "Cockpit"
    if cockpit ~= lastCockpit then
        lastCockpit = cockpit
        applyListening(cockpit)
    end
    local driven: Model? = if data then data.Model else nil
    if driven and driven.PrimaryPart then
        local quality = UIState.prefs().Graphics.Quality
        local layers = vehicleLayers(driven, data, quality)
        if layers then
            applyLayers(driven.PrimaryPart :: Instance, layers)
        end
        -- Lot AUDIO-03 : pneus du véhicule conduit, d'après la vraie dynamique (pulsation de l'ABS à chaque image).
        local tires = data and data.TireAudio
        if tires then
            applyTireLayers(
                driven.PrimaryPart :: Instance,
                TireAudioModel.layers(tires, massOf(driven), quality, os.clock())
            )
        end
        -- Lot AUDIO-04 : chocs détectés localement à chaque image ; raclement toutes les 0,05 s.
        local root = driven.PrimaryPart :: BasePart
        detectDrivenImpact(driven, root)
        scrapeTimer += dt
        if scrapeTimer >= SCRAPE_DRIVEN_S then
            scrapeTimer = 0
            updateScrape(driven, root)
        end
    end
end

local function update()
    local camera = Workspace.CurrentCamera
    if camera == nil then
        return
    end
    local quality = UIState.prefs().Graphics.Quality
    local data = DevHud.latest()
    local driven: Model? = if data then data.Model else nil
    local eye = camera.CFrame.Position
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
        -- Lot AUDIO-03 : pneus des véhicules observés, même limite de nombre et même Doppler que le moteur.
        local tirePart = entry.Model.PrimaryPart
        if tirePart then
            local tireLayers = observedTireLayers(entry.Model, tirePart, quality)
            if index > (OBSERVED[quality] or 0) then
                for _, layer in tireLayers do
                    layer.Volume = 0
                end
            end
            applyTireLayers(tirePart, tireLayers, dopplerFor(tirePart, eye))
            -- Lot AUDIO-04 : raclement des véhicules observés proches (contact détecté localement).
            if index <= (OBSERVED[quality] or 0) then
                updateScrape(entry.Model, tirePart, dopplerFor(tirePart, eye))
            end
        end
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
    -- Lot AUDIO-04 : chocs et bris d'optique diffusés par le serveur.
    task.spawn(function()
        local folder = ReplicatedStorage:WaitForChild(Constants.RemotesFolderName)
        local remote = folder:WaitForChild(Constants.Remotes.ImpactSound)
        if remote:IsA("UnreliableRemoteEvent") then
            remote.OnClientEvent:Connect(onImpactSound)
        end
    end)
    local timer = 0
    RunService.Heartbeat:Connect(function(dt)
        updateDriven(dt)
        timer += dt
        if timer >= UPDATE_S then
            timer = 0
            update()
        end
    end)
end

return table.freeze(AudioController)
