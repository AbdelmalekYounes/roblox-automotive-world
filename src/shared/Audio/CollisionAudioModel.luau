--!strict
--[[
    Bruits de collision (lot AUDIO-04), règles PURES, testées par Lune hors Studio.

    - Chocs : un Δv horizontal qu'aucun pneu ne peut produire, avec un obstacle au contact (même principe que
      DamageService, AUD-COLL-01). Trois familles (décision Q1 du propriétaire, 2026-11-06) : décor dur, objet léger,
      autre véhicule. Variante légère ou lourde et volume selon le Δv, hauteur variée de ±5 %.
    - Bris de verre : une optique cassée par le serveur (AWLightBroken).
    - Raclement (boucle) : carrosserie au contact d'un obstacle en glissant ; volume et hauteur selon la vitesse.

    Aucune lecture ici : AudioController joue ces sons, et seulement si leurs ressources ont un identifiant Roblox réel
    (AssetManifest). Catégorie « Effets » par le préfixe audio.effect. (décision Q4). Unités : m/s, kg.
]]

local CollisionAudioModel = {}

export type Kind = "Hard" | "Object" | "Vehicle"
export type Shot = { Id: string, Volume: number, Speed: number }

CollisionAudioModel.Ids = table.freeze({
    HardLight = "audio.effect.collision.hard.light",
    HardHeavy = "audio.effect.collision.hard.heavy",
    Object = "audio.effect.collision.object",
    VehicleLight = "audio.effect.collision.vehicle.light",
    VehicleHeavy = "audio.effect.collision.vehicle.heavy",
    Glass = "audio.effect.collision.glass",
    Scrape = "audio.effect.collision.scrape",
})

-- Réglages de conception (à ajuster à l'écoute du propriétaire).
-- Décélération maximale qu'un pneu peut produire, marge comprise (mêmes valeurs que DamageService), et tolérance.
-- Côté client, la vitesse simulée localement est lisse : la tolérance peut être plus basse que celle du serveur
-- (0,8 m/s), pour entendre aussi les petits chocs.
CollisionAudioModel.TireLimitMs2 = 1.3 * 1.25 * 9.81
CollisionAudioModel.ToleranceMs = 0.5
CollisionAudioModel.MinImpactMs = 1 -- Δv en excès en dessous duquel aucun choc n'est joué
CollisionAudioModel.HeavyImpactMs = 4 -- au-delà : variante lourde
CollisionAudioModel.FullImpactMs = 14 -- volume plein
CollisionAudioModel.ImpactCooldownS = 0.4 -- entre deux chocs d'un même véhicule
-- Objet « léger » : pièce non ancrée de moins de 200 kg (cône, barrière mobile, poubelle).
CollisionAudioModel.ObjectMaxMassKg = 200
-- Raclement : plein vers 15 m/s de glissement, inaudible sous 1,5 m/s.
CollisionAudioModel.ScrapeMinSpeed = 1.5
CollisionAudioModel.ScrapeFullSpeed = 15

local function ramp(value: number, low: number, high: number): number
    return math.clamp((value - low) / (high - low), 0, 1)
end

-- Famille d'un obstacle : autre véhicule, objet mobile et léger, ou décor dur (tout le reste).
function CollisionAudioModel.classify(isVehicle: boolean, anchored: boolean, massKg: number): Kind
    if isVehicle then
        return "Vehicle"
    end
    if not anchored and massKg < CollisionAudioModel.ObjectMaxMassKg then
        return "Object"
    end
    return "Hard"
end

--[[
    Δv horizontal en excès (m/s) : plus forte variation entre la vitesse actuelle et un relevé récent, moins ce que
    les pneus peuvent produire sur cet intervalle. `history` : relevés { Time, X, Z } (vitesse horizontale, m/s).
]]
function CollisionAudioModel.excess(
    history: { { Time: number, X: number, Z: number } },
    now: number,
    vx: number,
    vz: number
): number
    local worst = 0
    for _, sample in history do
        local dx, dz = vx - sample.X, vz - sample.Z
        local delta = math.sqrt(dx * dx + dz * dz)
        local excess = delta
            - (CollisionAudioModel.TireLimitMs2 * (now - sample.Time) + CollisionAudioModel.ToleranceMs)
        worst = math.max(worst, excess)
    end
    return worst
end

--[[
    Son d'un choc : ressource, volume (0 à 1) et vitesse de lecture. `random01` : tirage dans [0, 1] pour varier la
    hauteur (±5 %) ; nil sous le seuil. `kind` : « Vehicle », « Object », sinon décor dur.
]]
function CollisionAudioModel.impact(kind: string, deltaV: number, random01: number?): Shot?
    if not (deltaV >= CollisionAudioModel.MinImpactMs) then
        return nil
    end
    local ids = CollisionAudioModel.Ids
    local heavy = deltaV >= CollisionAudioModel.HeavyImpactMs
    local id = if kind == "Vehicle"
        then (if heavy then ids.VehicleHeavy else ids.VehicleLight)
        elseif kind == "Object" then ids.Object
        else (if heavy then ids.HardHeavy else ids.HardLight)
    local level = ramp(deltaV, CollisionAudioModel.MinImpactMs, CollisionAudioModel.FullImpactMs)
    -- Un petit choc reste audible (0,25), un choc violent sature à 1 ; courbe douce (racine).
    local volume = 0.25 + 0.75 * math.sqrt(level)
    if kind == "Object" then
        volume *= 0.8
    end
    -- Plus violent = un peu plus grave ; plus une variation aléatoire de ±5 %.
    local speed = (1.05 - 0.1 * level) * (0.95 + 0.1 * math.clamp(random01 or 0.5, 0, 1))
    return { Id = id, Volume = math.clamp(volume, 0, 1), Speed = speed }
end

-- Bris de verre d'une optique (un éclat par optique cassée).
function CollisionAudioModel.glass(random01: number?): Shot
    return {
        Id = CollisionAudioModel.Ids.Glass,
        Volume = 0.7,
        Speed = 0.95 + 0.1 * math.clamp(random01 or 0.5, 0, 1),
    }
end

-- Raclement : `contact` = carrosserie au contact d'un obstacle ; `slideSpeed` = vitesse du véhicule (m/s).
function CollisionAudioModel.scrape(contact: boolean, slideSpeed: number): Shot
    local level = if contact
        then ramp(slideSpeed, CollisionAudioModel.ScrapeMinSpeed, CollisionAudioModel.ScrapeFullSpeed)
        else 0
    return {
        Id = CollisionAudioModel.Ids.Scrape,
        Volume = if level > 0 then 0.2 + 0.7 * level else 0,
        Speed = 0.85 + 0.35 * level,
    }
end

return table.freeze(CollisionAudioModel)
