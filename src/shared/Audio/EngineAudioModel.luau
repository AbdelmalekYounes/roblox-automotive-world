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

return table.freeze(EngineAudioModel)
