--!strict
--[[
    Direction artistique (lot 0.8), valeurs PURES partagées par le client et
    les tests. Document : docs/lot-0.8/DIRECTION_ARTISTIQUE.md.

    - Profils de qualité graphique (Low / Medium / High) : distances de
      visibilité de l'habillage et des détails de carrosserie, nombre de
      sources de lumière, effets de post-traitement.
    - Étalonnage selon l'heure (ambiances, teinte, contraste) : visuel
      seulement ; l'adhérence ne dépend QUE de l'humidité de chaussée
      (AWRoadWetness, lot 0.3), jamais de l'éclairage ni de cet étalonnage.
    - Règle d'allumage des feux des véhicules (nuit, aube, brouillard).
]]

local ArtDirection = {}

export type Quality = "Low" | "Medium" | "High"

export type Profile = {
    DecorDistanceM: number, -- 0 : habillage masqué
    DetailDistanceM: number, -- 0 : détails de carrosserie masqués
    VehicleLightSources: number, -- véhicules aux feux « éclairants » (SpotLight)
    StreetLightSources: number, -- lampadaires allumés (sources réelles)
    Bloom: boolean,
    SunRays: boolean,
    ColorGrading: boolean,
}

ArtDirection.Qualities = table.freeze({ "Low", "Medium", "High" } :: { Quality })

ArtDirection.Profiles = table.freeze({
    Low = table.freeze({
        DecorDistanceM = 0,
        DetailDistanceM = 0,
        VehicleLightSources = 0,
        StreetLightSources = 0,
        Bloom = false,
        SunRays = false,
        ColorGrading = false,
    }),
    Medium = table.freeze({
        DecorDistanceM = 180,
        DetailDistanceM = 120,
        VehicleLightSources = 4,
        StreetLightSources = 12,
        Bloom = true,
        SunRays = false,
        ColorGrading = true,
    }),
    High = table.freeze({
        DecorDistanceM = 350,
        DetailDistanceM = 250,
        VehicleLightSources = 8,
        StreetLightSources = 24,
        Bloom = true,
        SunRays = true,
        ColorGrading = true,
    }),
} :: { [string]: Profile })

function ArtDirection.profile(quality: any): Profile
    return ArtDirection.Profiles[if type(quality) == "string" then quality else "Medium"]
        or ArtDirection.Profiles.Medium
end

-- Palette de référence par zone (couleurs dominantes, en RVB 0–255).
ArtDirection.ZonePalettes = table.freeze({
    Metropole = { { 120, 118, 112 }, { 70, 74, 80 }, { 240, 236, 220 } },
    Banlieues = { { 70, 120, 60 }, { 200, 190, 60 }, { 230, 225, 200 } },
    Docks = { { 170, 60, 45 }, { 40, 90, 150 }, { 200, 150, 40 } },
    Montagnes = { { 40, 85, 55 }, { 120, 118, 115 }, { 220, 50, 40 } },
    Campagne = { { 215, 185, 105 }, { 95, 145, 70 }, { 120, 95, 65 } },
    Motorsport = { { 30, 30, 32 }, { 230, 230, 235 }, { 220, 60, 50 } },
    Littoral = { { 70, 140, 60 }, { 230, 90, 70 }, { 60, 140, 200 } },
})

export type Grade = {
    Ambient: { number }, -- RVB 0–255
    OutdoorAmbient: { number },
    Tint: { number }, -- teinte de la correction colorimétrique
    Contrast: number,
    Saturation: number,
    ExposureCompensation: number,
}

-- Images clés de la journée (heure → étalonnage), interpolées linéairement.
local KEYS: { { number | Grade } } = {
    {
        0,
        {
            Ambient = { 30, 34, 52 },
            OutdoorAmbient = { 38, 44, 70 },
            Tint = { 205, 215, 255 },
            Contrast = 0.08,
            Saturation = -0.15,
            ExposureCompensation = 0.3,
        },
    },
    {
        6,
        {
            Ambient = { 90, 80, 85 },
            OutdoorAmbient = { 120, 105, 110 },
            Tint = { 255, 225, 205 },
            Contrast = 0.05,
            Saturation = 0.05,
            ExposureCompensation = 0.1,
        },
    },
    {
        9,
        {
            Ambient = { 110, 112, 118 },
            OutdoorAmbient = { 135, 138, 145 },
            Tint = { 255, 250, 242 },
            Contrast = 0.04,
            Saturation = 0.08,
            ExposureCompensation = 0,
        },
    },
    {
        13,
        {
            Ambient = { 118, 120, 125 },
            OutdoorAmbient = { 140, 142, 148 },
            Tint = { 255, 255, 255 },
            Contrast = 0.03,
            Saturation = 0.06,
            ExposureCompensation = 0,
        },
    },
    {
        18,
        {
            Ambient = { 115, 95, 85 },
            OutdoorAmbient = { 140, 115, 100 },
            Tint = { 255, 220, 190 },
            Contrast = 0.06,
            Saturation = 0.1,
            ExposureCompensation = 0.05,
        },
    },
    {
        20.5,
        {
            Ambient = { 55, 52, 75 },
            OutdoorAmbient = { 70, 66, 98 },
            Tint = { 225, 215, 255 },
            Contrast = 0.07,
            Saturation = -0.05,
            ExposureCompensation = 0.2,
        },
    },
    {
        24,
        {
            Ambient = { 30, 34, 52 },
            OutdoorAmbient = { 38, 44, 70 },
            Tint = { 205, 215, 255 },
            Contrast = 0.08,
            Saturation = -0.15,
            ExposureCompensation = 0.3,
        },
    },
}

local function mix(a: number, b: number, t: number): number
    return a + (b - a) * t
end

local function mixColor(a: { number }, b: { number }, t: number): { number }
    return { mix(a[1], b[1], t), mix(a[2], b[2], t), mix(a[3], b[3], t) }
end

function ArtDirection.grade(clockTime: number): Grade
    local hour = clockTime % 24
    for index = 2, #KEYS do
        local previous, nextKey = KEYS[index - 1], KEYS[index]
        local h0, h1 = previous[1] :: number, nextKey[1] :: number
        if hour <= h1 then
            local t = if h1 > h0 then (hour - h0) / (h1 - h0) else 0
            local a, b = previous[2] :: Grade, nextKey[2] :: Grade
            return {
                Ambient = mixColor(a.Ambient, b.Ambient, t),
                OutdoorAmbient = mixColor(a.OutdoorAmbient, b.OutdoorAmbient, t),
                Tint = mixColor(a.Tint, b.Tint, t),
                Contrast = mix(a.Contrast, b.Contrast, t),
                Saturation = mix(a.Saturation, b.Saturation, t),
                ExposureCompensation = mix(a.ExposureCompensation, b.ExposureCompensation, t),
            }
        end
    end
    return KEYS[1][2] :: Grade
end

-- Feux allumés : de 19 h 30 à 6 h 45, ou par brouillard dense / forte pluie.
ArtDirection.LightsOnAfter = 19.5
ArtDirection.LightsOffAfter = 6.75
ArtDirection.FogLightsDensity = 0.4

function ArtDirection.lightsOn(clockTime: number, fogDensity: number, rainRate: number?): boolean
    local hour = clockTime % 24
    local dark = hour >= ArtDirection.LightsOnAfter or hour < ArtDirection.LightsOffAfter
    return dark or fogDensity >= ArtDirection.FogLightsDensity or (rainRate or 0) >= 400
end

return table.freeze(ArtDirection)
