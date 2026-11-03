--!strict
--[[
    Radio des véhicules (lot 0.8, §9.2, AUD-RADIO-01, SCN-19), règles PURES.

    - Stations thématiques FICTIVES ; leurs pistes sont des compositions
      originales (tools/audio/synth.py) ou, plus tard, des licences
      compatibles. Une station n'est DISPONIBLE que si toutes ses pistes ont
      un identifiant Roblox réel (AssetManifest) : aujourd'hui, aucune.
    - Seul le CONDUCTEUR choisit la station commune du véhicule (le serveur
      revalide). Chaque occupant règle son volume et peut couper l'écoute
      (préférences locales : Audio.Radio, Audio.RadioMuted) ; personne n'est
      obligé d'écouter.
    - Aucune diffusion extérieure par défaut : le son n'est joué que pour les
      occupants, localement (jamais un son 3D audible hors du véhicule).
]]

local RadioRules = {}

export type Station = { Id: string, Theme: string, Tracks: { string } }

RadioRules.Off = "Off"

RadioRules.Stations = table.freeze({
    table.freeze({ Id = "ville", Theme = "Pop urbaine", Tracks = table.freeze({ "audio.radio.ville" }) }),
    table.freeze({ Id = "route", Theme = "Rock de route", Tracks = table.freeze({ "audio.radio.route" }) }),
    table.freeze({ Id = "nuit", Theme = "Électro de nuit", Tracks = table.freeze({ "audio.radio.nuit" }) }),
} :: { Station })

-- Diffusion à l'extérieur du véhicule : désactivée par défaut (aucun réglage ne l'active ici).
RadioRules.ExteriorBroadcast = false

function RadioRules.station(id: any): Station?
    for _, station in RadioRules.Stations do
        if station.Id == id then
            return station
        end
    end
    return nil
end

-- Disponible si chaque piste est jouable (identifiant réel ; `playable` vient du manifeste).
function RadioRules.available(station: Station, playable: (string) -> boolean): boolean
    if #station.Tracks == 0 then
        return false
    end
    for _, track in station.Tracks do
        if not playable(track) then
            return false
        end
    end
    return true
end

export type Seat = "Driver" | "Passenger" | "None"

--[[
    Demande de changement de station : seul le conducteur, vers « Off » ou
    une station disponible. Renvoie (accepté, raison).
]]
function RadioRules.setStation(seat: Seat, id: any, playable: (string) -> boolean): (boolean, string?)
    if seat ~= "Driver" then
        return false, "RadioDriverOnly"
    end
    if id == RadioRules.Off then
        return true, nil
    end
    local station = RadioRules.station(id)
    if station == nil then
        return false, "RadioStationUnknown"
    end
    if not RadioRules.available(station, playable) then
        return false, "RadioStationUnavailable"
    end
    return true, nil
end

--[[
    Volume d'écoute d'un occupant (0–1) : rien hors du véhicule, rien si
    l'occupant a coupé la radio ou si la station n'est pas jouée.
]]
function RadioRules.listenVolume(seat: Seat, stationId: any, muted: boolean, volumePercent: number): number
    if seat == "None" or muted or stationId == nil or stationId == RadioRules.Off then
        return 0
    end
    return math.clamp(volumePercent / 100, 0, 1)
end

return table.freeze(RadioRules)
