--!strict
-- Météo et cycle jour/nuit PURS (cahier des charges §2.3).
--
-- - Horloge : cycle complet de 30 minutes, synchronisé par l'heure du serveur
--   (chaque client calcule la même heure sans échange continu).
-- - Météo : ciel dégagé, pluie, brouillard, orage ; durées et enchaînements
--   tirés par le serveur (seul décideur), publiés en attributs.
-- - Chaussée : humidité de 0 à 1 qui monte sous la pluie et sèche ensuite ;
--   c'est la SEULE grandeur transmise à la physique, qui l'applique une seule
--   fois par pneu (VehicleDynamics), en la combinant par maximum avec une zone
--   déjà mouillée (attribut AWWet) : jamais deux réductions d'adhérence.
-- - AUD-WEATHER-01 : conditions standardisées pour les futures épreuves
--   classées et records officiels (non utilisées avant le lot des courses).

local WeatherModel = {}

WeatherModel.DayLengthS = 30 * 60
WeatherModel.StartHour = 9

export type State = "Clear" | "Rain" | "Fog" | "Storm"

export type Preset = {
    WetTarget: number, -- humidité visée de la chaussée
    WetRate: number, -- variation maximale par seconde vers la cible
    DurationS: { number }, -- durée min / max d'un épisode
    FogDensity: number, -- Atmosphere.Density visée
    Haze: number,
    Brightness: number, -- multiplicateur de luminosité
    RainRate: number, -- particules de pluie (0 = aucune)
    Lightning: boolean,
}

local STATES: { State } = { "Clear", "Rain", "Fog", "Storm" }
WeatherModel.States = table.freeze(STATES)

WeatherModel.Presets = table.freeze({
    Clear = table.freeze({
        WetTarget = 0,
        WetRate = 1 / 300, -- sèche en environ 5 minutes
        DurationS = { 360, 720 },
        FogDensity = 0.3,
        Haze = 0.6,
        Brightness = 1,
        RainRate = 0,
        Lightning = false,
    }),
    Rain = table.freeze({
        WetTarget = 1,
        WetRate = 1 / 120, -- détrempée en environ 2 minutes
        DurationS = { 240, 480 },
        FogDensity = 0.42,
        Haze = 1.8,
        Brightness = 0.7,
        RainRate = 400,
        Lightning = false,
    }),
    Fog = table.freeze({
        WetTarget = 0.2,
        WetRate = 1 / 400,
        DurationS = { 180, 360 },
        FogDensity = 0.62,
        Haze = 3.5,
        Brightness = 0.8,
        RainRate = 0,
        Lightning = false,
    }),
    Storm = table.freeze({
        WetTarget = 1,
        WetRate = 1 / 60,
        DurationS = { 150, 300 },
        FogDensity = 0.5,
        Haze = 2.5,
        Brightness = 0.5,
        RainRate = 900,
        Lightning = true,
    }),
}) :: { [string]: Preset }

-- Poids des enchaînements (état courant → suivant).
WeatherModel.Transitions = table.freeze({
    Clear = { Clear = 0.35, Rain = 0.3, Fog = 0.2, Storm = 0.15 },
    Rain = { Clear = 0.5, Rain = 0.15, Fog = 0.15, Storm = 0.2 },
    Fog = { Clear = 0.6, Rain = 0.25, Fog = 0.1, Storm = 0.05 },
    Storm = { Clear = 0.35, Rain = 0.55, Fog = 0.1, Storm = 0 },
}) :: { [string]: { [string]: number } }

-- AUD-WEATHER-01 : conditions de référence des épreuves classées.
WeatherModel.Standard = table.freeze({
    State = "Clear" :: State,
    Wetness = 0,
    ClockTime = 13,
    Label = "Conditions standardisées (AUD-WEATHER-01)",
})

-- Heure (0–24) à l'instant `serverTime`, `epoch` = instant de StartHour.
function WeatherModel.clockTime(serverTime: number, epoch: number): number
    local cycles = (serverTime - epoch) / WeatherModel.DayLengthS
    return (WeatherModel.StartHour + 24 * cycles) % 24
end

-- Épisode suivant, à partir d'un tirage uniforme `roll` dans [0 ; 1[.
function WeatherModel.nextState(current: State, roll: number): State
    local weights = WeatherModel.Transitions[current]
    local total = 0
    for _, state in STATES do
        total += weights[state] or 0
    end
    local target = roll * total
    for _, state in STATES do
        target -= weights[state] or 0
        if target < 0 then
            return state :: State
        end
    end
    return "Clear"
end

-- Durée d'un épisode à partir d'un tirage `roll` dans [0 ; 1[.
function WeatherModel.duration(state: State, roll: number): number
    local range = WeatherModel.Presets[state].DurationS
    return range[1] + (range[2] - range[1]) * roll
end

-- Évolution de l'humidité de la chaussée pendant `dt` secondes.
function WeatherModel.stepWetness(wetness: number, state: State, dt: number): number
    local preset = WeatherModel.Presets[state]
    local delta = preset.WetTarget - wetness
    local stepMax = preset.WetRate * dt
    return math.clamp(wetness + math.clamp(delta, -stepMax, stepMax), 0, 1)
end

--[[
    Humidité vue par un pneu : maximum entre la chaussée (météo) et une
    surface déjà mouillée par conception (zone d'essai mouillée). Jamais une
    somme : la réduction d'adhérence n'est appliquée qu'une fois.
]]
function WeatherModel.contactWetness(roadWetness: number, surfaceWet: boolean): number
    return math.max(math.clamp(roadWetness, 0, 1), if surfaceWet then 1 else 0)
end

return table.freeze(WeatherModel)
