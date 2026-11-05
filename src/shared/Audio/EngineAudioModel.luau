--!strict
--[[
    Audio moteur MODULAIRE (lot 0.8), règles PURES : à partir du régime, de la
    charge (accélérateur) et de la motorisation, calcule le volume et la vitesse
    de lecture de chaque couche sonore. Aucune lecture ici : le client
    (VehicleAudio) applique ces valeurs aux sons du manifeste (AssetManifest),
    et seulement si ces sons ont un identifiant Roblox réel.

    - Thermique (essence, diesel) : quatre couches (ralenti, bas, milieu, haut)
      enregistrées à un régime de référence (tools/audio/synth.py). Fondu
      croisé selon le régime ; vitesse de lecture = régime / référence (bornée).
      La charge renforce les couches hautes (moteur « sous charge »).
    - Électrique : DISTINCT, aucun bruit de combustion ; ronflement (hum),
      sifflement du moteur (whine) et de l'onduleur (inverter), fonction de la
      vitesse et du couple demandé.
    - Qualité : Low = 2 couches, Medium = 3, High = toutes (les plus fortes).
]]

local EngineAudioModel = {}

export type Layer = { Id: string, Volume: number, Speed: number }

-- Régimes de référence (tr/min) des couches thermiques ; identiques à synth.py.
EngineAudioModel.CombustionLayers = table.freeze({
    { Name = "idle", Rpm = 850 },
    { Name = "low", Rpm = 2000 },
    { Name = "mid", Rpm = 3500 },
    { Name = "high", Rpm = 5500 },
})

EngineAudioModel.ElectricLayers = table.freeze({ "hum", "whine", "inverter" })

EngineAudioModel.MinSpeed = 0.5
EngineAudioModel.MaxSpeed = 2

local LAYER_LIMIT = { Low = 2, Medium = 3, High = 99 }

-- Poids triangulaire de la couche i autour de son régime (fondu croisé).
local function weight(rpm: number, index: number): number
    local layers = EngineAudioModel.CombustionLayers
    local here = layers[index].Rpm
    local below = if index > 1 then layers[index - 1].Rpm else nil
    local above = if index < #layers then layers[index + 1].Rpm else nil
    if rpm <= here then
        if below == nil then
            return 1
        end
        return math.clamp((rpm - below) / (here - below), 0, 1)
    end
    if above == nil then
        return 1
    end
    return math.clamp((above - rpm) / (above - here), 0, 1)
end

local function keepLoudest(layers: { Layer }, quality: string?): { Layer }
    local limit = LAYER_LIMIT[quality or "Medium"] or LAYER_LIMIT.Medium
    local sorted = table.clone(layers)
    table.sort(sorted, function(a, b)
        return a.Volume > b.Volume
    end)
    for index, layer in sorted do
        if index > limit then
            layer.Volume = 0
        end
    end
    return layers
end

--[[
    Couches d'un moteur thermique. `energy` : "Petrol" ou "Diesel" ; `throttle`
    0–1 ; `stalled` : moteur calé (silence).
]]
function EngineAudioModel.combustion(
    energy: string,
    rpm: number,
    throttle: number,
    stalled: boolean,
    quality: string?
): { Layer }
    local prefix = if energy == "Diesel" then "audio.engine.diesel." else "audio.engine.petrol."
    local load = math.clamp(throttle, 0, 1)
    local out: { Layer } = {}
    for index, layer in EngineAudioModel.CombustionLayers do
        local w = if stalled then 0 else weight(rpm, index)
        -- Sous charge, les couches au-dessus du ralenti sont plus présentes.
        local gain = if index == 1 then 1 - 0.3 * load else 0.65 + 0.35 * load
        table.insert(out, {
            Id = prefix .. layer.Name,
            Volume = math.clamp(w * gain, 0, 1),
            Speed = math.clamp(rpm / layer.Rpm, EngineAudioModel.MinSpeed, EngineAudioModel.MaxSpeed),
        })
    end
    return keepLoudest(out, quality)
end

--[[
    Couches d'un moteur électrique : `speedFraction` = régime / régime maximal
    du moteur (0–1), `torqueFraction` = couple demandé (accélérateur ou
    récupération, 0–1).
]]
function EngineAudioModel.electric(speedFraction: number, torqueFraction: number, quality: string?): { Layer }
    local s = math.clamp(speedFraction, 0, 1)
    local q = math.clamp(torqueFraction, 0, 1)
    local out: { Layer } = {
        { Id = "audio.engine.electric.hum", Volume = 0.25 + 0.35 * q, Speed = 0.8 + 0.6 * s },
        {
            Id = "audio.engine.electric.whine",
            Volume = math.clamp(s * 1.2, 0, 1) * (0.5 + 0.5 * q),
            Speed = 0.5 + 1.5 * s,
        },
        { Id = "audio.engine.electric.inverter", Volume = 0.35 * q * (1 - s * 0.5), Speed = 0.9 + 0.3 * q },
    }
    for _, layer in out do
        layer.Speed = math.clamp(layer.Speed, EngineAudioModel.MinSpeed, EngineAudioModel.MaxSpeed)
    end
    return keepLoudest(out, quality)
end

--[[
    Régime approché d'un véhicule observé (autre joueur, trafic) : seul le
    véhicule conduit connaît son régime réel ; pour les autres, on l'estime à
    partir de la vitesse (approximation sonore, aucune conséquence de jeu).
]]
function EngineAudioModel.estimateRpm(speedKmh: number, idleRpm: number, redlineRpm: number, topKmh: number): number
    local fraction = math.clamp(speedKmh / math.max(topKmh, 1), 0, 1)
    -- Profil en dents de scie atténué : montée dans chaque rapport (5 rapports).
    local inGear = (fraction * 5) % 1
    return idleRpm + (redlineRpm * 0.85 - idleRpm) * (0.35 + 0.5 * inGear) * math.min(1, fraction * 6)
end

-- ======================== Lot AUDIO-01 : profils enregistrés par véhicule ========================

--[[
    Profil sonore d'un véhicule (Shared.Audio.EngineSoundProfiles) : boucles tirées d'ENREGISTREMENTS, chacune à un
    régime de référence, en CHARGE (accélérateur) et en DÉCHARGE (lever de pied, frein moteur). Ressources du
    manifeste : `<Prefix>on.<Rpm>` et `<Prefix>off.<Rpm>` ; événements ponctuels : `<Prefix><Nom>`.
]]
export type Profile = {
    Prefix: string, -- ex. "audio.engine.brio."
    Points: { number }, -- régimes de référence des boucles (tr/min), croissants
    IdleRpm: number,
    LimiterRpm: number,
    Turbo: boolean, -- couche de sifflement « turbo » et décharge (blow-off)
    Pops: boolean, -- pétarades au lever de pied à haut régime
    Gain: number, -- niveau général du profil (0–1)
}

export type State = { Rpm: number, Load: number, Running: boolean, Stalled: boolean, Gear: number? }

-- Écart de transposition toléré autour d'une boucle : au-delà, le timbre devient artificiel.
EngineAudioModel.ProfileMinSpeed = 0.7
EngineAudioModel.ProfileMaxSpeed = 1.45
-- Seuil de charge : la boucle « en charge » domine au-dessus, la boucle « en décharge » en dessous.
EngineAudioModel.LoadKnee = 0.25

local function smoothstep(x: number): number
    local t = math.clamp(x, 0, 1)
    return t * t * (3 - 2 * t)
end

-- Poids triangulaire d'un point de profil (fondu croisé entre deux boucles voisines).
local function pointWeight(points: { number }, index: number, rpm: number): number
    local here = points[index]
    local below, above = points[index - 1], points[index + 1]
    if rpm <= here then
        return if below == nil then 1 else math.clamp((rpm - below) / (here - below), 0, 1)
    end
    return if above == nil then 1 else math.clamp((above - rpm) / (above - here), 0, 1)
end

--[[
    Couches d'un profil enregistré. `Load` 0–1 (accélérateur) ; moteur arrêté ou calé : silence. Fondu croisé selon le
    régime (deux boucles voisines au plus) et selon la charge (en charge / en décharge, transition douce autour de
    LoadKnee). Vitesse de lecture = régime / régime de la boucle, bornée.
]]
function EngineAudioModel.profileLayers(profile: Profile, state: State, quality: string?): { Layer }
    local out: { Layer } = {}
    local silent = not state.Running or state.Stalled
    local rpm = math.clamp(state.Rpm, 0, profile.LimiterRpm * 1.05)
    local on = smoothstep((state.Load - EngineAudioModel.LoadKnee * 0.4) / EngineAudioModel.LoadKnee)
    -- Au ralenti, la boucle « en décharge » garde la moitié du son même pied posé (pas de vraie charge à l'arrêt).
    if rpm < profile.IdleRpm * 1.15 then
        on *= 0.5
    end
    for index, ref in profile.Points do
        local w = if silent then 0 else pointWeight(profile.Points, index, rpm)
        local speed = math.clamp(rpm / ref, EngineAudioModel.ProfileMinSpeed, EngineAudioModel.ProfileMaxSpeed)
        local id = tostring(ref)
        table.insert(out, { Id = profile.Prefix .. "on." .. id, Volume = w * on * profile.Gain, Speed = speed })
        table.insert(out, { Id = profile.Prefix .. "off." .. id, Volume = w * (1 - on) * profile.Gain, Speed = speed })
    end
    if profile.Turbo then
        -- Sifflement du turbo : monte avec la charge et le régime (pression de suralimentation), jamais au ralenti.
        local boost = if silent then 0 else smoothstep(state.Load) * smoothstep((rpm - 2500) / 3500)
        table.insert(
            out,
            { Id = profile.Prefix .. "turbo", Volume = 0.35 * boost * profile.Gain, Speed = 0.8 + 0.5 * boost }
        )
    end
    return keepLoudest(out, quality)
end

-- Seuils de détection des événements : chute de régime relative, fraction du rupteur pour les pétarades.
EngineAudioModel.ShiftDropFraction = 0.12
EngineAudioModel.PopsRpmFraction = 0.55

--[[
    Événements ponctuels entre deux relevés successifs (environ 0,1 s) : « Start », « Stop », « Stall », « Shift »
    (rapport changé, ou chute brutale du régime sous charge quand le rapport est inconnu), « Limiter » (rupteur),
    « Pops » (lever de pied brutal à haut régime, si le profil en a), « BlowOff » (décharge du turbo).
]]
function EngineAudioModel.events(profile: Profile, before: State, now: State): { string }
    local out: { string } = {}
    if now.Stalled and not before.Stalled then
        table.insert(out, "Stall")
        return out
    end
    if now.Running and not before.Running then
        table.insert(out, "Start")
        return out
    end
    if before.Running and not now.Running then
        if not now.Stalled then
            table.insert(out, "Stop")
        end
        return out
    end
    if not now.Running then
        return out
    end
    local gearChanged = now.Gear ~= nil and before.Gear ~= nil and now.Gear ~= before.Gear and now.Gear > 0
    local dropped = before.Rpm > 0 and (before.Rpm - now.Rpm) / before.Rpm >= EngineAudioModel.ShiftDropFraction
    if gearChanged or (now.Gear == nil and dropped and before.Load > 0.5) then
        table.insert(out, "Shift")
    end
    if now.Rpm >= profile.LimiterRpm * 0.98 and now.Load > 0.5 then
        table.insert(out, "Limiter")
    end
    local lifted = before.Load >= 0.6 and now.Load <= 0.15
    if lifted and profile.Pops and now.Rpm >= profile.LimiterRpm * EngineAudioModel.PopsRpmFraction then
        table.insert(out, "Pops")
    end
    if lifted and profile.Turbo and now.Rpm >= 3000 then
        table.insert(out, "BlowOff")
    end
    return out
end

--[[
    Écoute depuis l'habitacle (vue cockpit) ou de l'extérieur : réglages d'égaliseur (dB, EqualizerSoundEffect) et
    gain. Dans l'habitacle, la caisse filtre les aigus de l'échappement et renforce les graves (résonance).
]]
function EngineAudioModel.listening(
    cockpit: boolean
): { LowGain: number, MidGain: number, HighGain: number, Gain: number }
    if cockpit then
        return { LowGain = 4, MidGain = -3, HighGain = -14, Gain = 0.8 }
    end
    return { LowGain = 0, MidGain = 0, HighGain = 0, Gain = 1 }
end

-- Vitesse du son (m/s) et bornes de l'effet Doppler appliqué aux véhicules observés.
EngineAudioModel.SoundSpeedMs = 343
EngineAudioModel.DopplerMin = 0.8
EngineAudioModel.DopplerMax = 1.25

--[[
    Facteur Doppler (multiplie la vitesse de lecture) d'une source qui s'approche de l'auditeur à `approachMs` m/s
    (négatif : elle s'éloigne). Source mobile, auditeur supposé immobile : c / (c − v), borné.
]]
function EngineAudioModel.doppler(approachMs: number): number
    local c = EngineAudioModel.SoundSpeedMs
    local v = math.clamp(approachMs, -0.5 * c, 0.5 * c)
    return math.clamp(c / (c - v), EngineAudioModel.DopplerMin, EngineAudioModel.DopplerMax)
end

return table.freeze(EngineAudioModel)
