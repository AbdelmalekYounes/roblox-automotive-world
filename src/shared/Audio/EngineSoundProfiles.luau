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

-- Aucun profil tant que les enregistrements ne sont pas traités (étape 3 du plan).
EngineSoundProfiles.Profiles = table.freeze({}) :: { [string]: EngineAudioModel.Profile }

-- Événements ponctuels possibles (ressources `<Prefix><Nom>`).
EngineSoundProfiles.EventNames = table.freeze({ "Start", "Stop", "Stall", "Shift", "Limiter", "Pops", "BlowOff" })

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
