--!strict
--[[
    Profils sonores des moteurs (lot AUDIO-01), par définition de véhicule. Module PUR.

    Chaque profil décrit des boucles tirées d'ENREGISTREMENTS libres (docs/lot-audio-01/PLAN_AUDIO_01.md), produites
    par l'outil de découpe du lot : un régime de référence par point, une boucle en charge et une en décharge.
    Un profil n'est inscrit ici qu'une fois ses boucles produites ; le contrôleur ne joue un son que si sa ressource
    a un identifiant Roblox réel (AssetManifest). Sans profil, l'ancien modèle générique du lot 0.8 s'applique.
]]

local EngineAudioModel = require(script.Parent.EngineAudioModel)

local EngineSoundProfiles = {}

-- Brio (lot AUDIO-01, 2026-11-05) : pack « The Dyno Sessions: 190E » (Chippy569, CC0), 4 cylindres 16 soupapes au
-- banc, micro d'échappement. Boucles produites par `tools/audio/engine_loops.py brio` (registre docs/audio/SONS_TIERS.md).
-- Régimes de référence espacés d'un facteur ~1,45 ; ni turbo ni pétarades (citadine atmosphérique).
local BRIO: EngineAudioModel.Profile = {
    Prefix = "audio.engine.brio.",
    Points = { 1000, 1450, 2100, 3000, 4300, 6200 },
    IdleRpm = 850,
    LimiterRpm = 7200,
    Turbo = false,
    Pops = false,
    Gain = 0.9,
}

EngineSoundProfiles.Profiles = table.freeze({ wk_brio = table.freeze(BRIO) }) :: { [string]: EngineAudioModel.Profile }

-- Événements ponctuels possibles (ressources `<Prefix><nom en minuscules>`).
EngineSoundProfiles.EventNames = table.freeze({ "Start", "Stop", "Stall", "Shift", "Limiter", "Pops", "BlowOff" })

-- Ressources sonores d'un profil (identifiants du manifeste) : boucles en charge et en décharge de chaque régime,
-- démarrage, arrêt, calage ; turbo et décharge du turbo, pétarades selon le profil.
function EngineSoundProfiles.assetIds(profile: EngineAudioModel.Profile): { string }
    local ids = {}
    for _, rpm in profile.Points do
        table.insert(ids, profile.Prefix .. "on." .. tostring(rpm))
        table.insert(ids, profile.Prefix .. "off." .. tostring(rpm))
    end
    for _, name in { "start", "stop", "stall" } do
        table.insert(ids, profile.Prefix .. name)
    end
    if profile.Turbo then
        table.insert(ids, profile.Prefix .. "turbo")
        table.insert(ids, profile.Prefix .. "blowoff")
    end
    if profile.Pops then
        table.insert(ids, profile.Prefix .. "pops")
    end
    return ids
end

-- Contrôle d'un profil (tests) : liste des erreurs.
function EngineSoundProfiles.validate(profile: EngineAudioModel.Profile): { string }
    local errors = {}
    if not string.match(profile.Prefix, "^audio%.engine%.[a-z0-9_]+%.$") then
        table.insert(errors, "préfixe invalide : " .. profile.Prefix)
    end
    if #profile.Points < 2 then
        table.insert(errors, "au moins deux régimes de référence")
    end
    local maxRatio = EngineAudioModel.ProfileMaxSpeed / EngineAudioModel.ProfileMinSpeed
    for index = 2, #profile.Points do
        local ratio = profile.Points[index] / profile.Points[index - 1]
        if ratio <= 1 then
            table.insert(errors, "régimes non croissants")
        elseif ratio > maxRatio then
            table.insert(
                errors,
                "écart trop grand entre " .. profile.Points[index - 1] .. " et " .. profile.Points[index]
            )
        end
    end
    if #profile.Points > 0 and profile.Points[1] > profile.IdleRpm * 1.2 then
        table.insert(errors, "aucune boucle près du ralenti")
    end
    if
        #profile.Points > 0
        and profile.Points[#profile.Points] * EngineAudioModel.ProfileMaxSpeed < profile.LimiterRpm
    then
        table.insert(errors, "rupteur hors de portée de la dernière boucle")
    end
    if not (profile.Gain > 0 and profile.Gain <= 1) then
        table.insert(errors, "gain hors de ]0 ; 1]")
    end
    return errors
end

return table.freeze(EngineSoundProfiles)
