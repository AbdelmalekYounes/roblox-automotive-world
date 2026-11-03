--!strict
--[[
    Ambiances sonores (lot 0.8), règles PURES : d'après la zone, la météo,
    l'heure et la vitesse, renvoie le volume de chaque boucle d'ambiance
    (catégorie « Environnement »). Le client fond les boucles entre elles ;
    aucune n'est jouée sans identifiant Roblox réel (AssetManifest).
    Les catégories de volume du joueur (Moteur, Environnement, Interface,
    Effets, Radio, Voix) sont appliquées par SoundGroup, pas ici.
]]

local AmbienceModel = {}

AmbienceModel.ZoneLoops = table.freeze({
    Metropole = "audio.ambience.city",
    Banlieues = "audio.ambience.suburb",
    Docks = "audio.ambience.harbour",
    Montagnes = "audio.ambience.mountain",
    Campagne = "audio.ambience.countryside",
    Motorsport = "audio.ambience.circuit",
    Littoral = "audio.ambience.coast",
} :: { [string]: string })

AmbienceModel.Categories = table.freeze({ "Engine", "Environment", "Interface", "Effects", "Radio", "Voice" })

-- Catégorie de volume de chaque famille d'identifiants du manifeste.
function AmbienceModel.categoryOf(assetId: string): string?
    if string.sub(assetId, 1, 13) == "audio.engine." then
        return "Engine"
    elseif string.sub(assetId, 1, 15) == "audio.ambience." then
        return "Environment"
    elseif string.sub(assetId, 1, 9) == "audio.ui." then
        return "Interface"
    elseif string.sub(assetId, 1, 13) == "audio.effect." then
        return "Effects"
    elseif string.sub(assetId, 1, 12) == "audio.radio." then
        return "Radio"
    end
    return nil
end

--[[
    Volumes des boucles (0–1) : `zone` (nom de zone ou nil), `rainRate`
    (particules/s de la météo), `clockTime` (h), `speedKmh` (vitesse de la
    caméra ou du véhicule : l'ambiance s'efface derrière le vent).
]]
function AmbienceModel.mix(zone: string?, rainRate: number, clockTime: number, speedKmh: number): { [string]: number }
    local out: { [string]: number } = {}
    for _, id in AmbienceModel.ZoneLoops do
        out[id] = 0
    end
    local night = clockTime < 6.5 or clockTime >= 21
    local masking = 1 - math.clamp((speedKmh - 30) / 120, 0, 0.7)
    local loop = if zone then AmbienceModel.ZoneLoops[zone] else nil
    if loop then
        -- Ville et circuit plus calmes la nuit.
        local nightGain = if night and (zone == "Metropole" or zone == "Motorsport") then 0.5 else 1
        out[loop] = 0.8 * nightGain * masking
    end
    local rain = math.clamp(rainRate / 900, 0, 1)
    out["audio.ambience.rain"] = rain * 0.9
    if loop and rain > 0 then
        out[loop] *= 1 - 0.5 * rain
    end
    out["audio.effect.wind"] = math.clamp((speedKmh - 40) / 160, 0, 1) * 0.7
    return out
end

return table.freeze(AmbienceModel)
