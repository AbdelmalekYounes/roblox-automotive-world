--!strict
--[[
    Sons des pneus (lot AUDIO-03), règles PURES, testées par Lune hors Studio.

    À partir de l'état des quatre roues (glissements calculés par VehicleDynamics, vitesse du contact, revêtement,
    humidité), calcule le volume et la vitesse de lecture de chaque boucle :
    - roulement : sec (revêtement dur), meuble (gravier, terre, herbe, sable, neige) et mouillé (chuintement d'eau) ;
    - crissement : dérive au-delà du pic (virage, dérapage), blocage au freinage, patinage au départ ;
    - frottement de glissade : glissade franche, grave et large, sous le crissement ;
    - glissade sur revêtement meuble : remplace le crissement hors du dur.

    Une seule source par véhicule (résumé des quatre roues), émise à la position du véhicule. Aucune lecture ici :
    AudioController applique ces valeurs aux sons du manifeste, et seulement si ces sons ont un identifiant Roblox réel.
    Décisions du propriétaire (2026-11-06, docs/lot-audio-03/PLAN_AUDIO_03.md §4) : revêtements sec, mouillé et
    meuble ; glissement transmis pour les autres joueurs ; tous les véhicules ; catégorie de volume « Effets ».

    Unités : vitesses en m/s, angles en radians, masses en kg. Volumes 0 à 1 (avant le réglage du joueur).
]]

local TireAudioModel = {}

export type Layer = { Id: string, Volume: number, Speed: number }

-- Familles de revêtement, dans l'ordre de leur code réseau (0 = Hard, 1 = Loose, 2 = Soft, 3 = Ice).
export type Surface = "Hard" | "Loose" | "Soft" | "Ice"
TireAudioModel.Surfaces = table.freeze({ "Hard", "Loose", "Soft", "Ice" } :: { Surface })

-- Famille sonore de chaque matériau Roblox (mêmes noms que Physics/SurfaceFriction). Dur par défaut : la plupart
-- des pièces de la carte sont en plastique ou en béton.
local SURFACE_OF: { [string]: Surface } = {
    Gravel = "Loose",
    Pebble = "Loose",
    Ground = "Loose",
    Sand = "Loose",
    Grass = "Soft",
    LeafyGrass = "Soft",
    Mud = "Soft",
    Snow = "Soft",
    Water = "Soft",
    Ice = "Ice",
    Glacier = "Ice",
}

function TireAudioModel.surfaceOf(materialName: string?): Surface
    return if materialName then SURFACE_OF[materialName] or "Hard" else "Hard"
end

-- Code réseau d'une famille (0 à 3) et décodage défensif (toute autre valeur : dur).
function TireAudioModel.surfaceCode(surface: Surface): number
    return (table.find(TireAudioModel.Surfaces, surface) or 1) - 1
end

local function surfaceFromCode(code: any): Surface
    if type(code) ~= "number" or code ~= code then
        return "Hard"
    end
    -- Correspondance écrite en clair (même ordre que Surfaces) : le typage strict garde ainsi les valeurs exactes.
    local index = math.clamp(math.round(code), 0, 3)
    if index == 1 then
        return "Loose"
    elseif index == 2 then
        return "Soft"
    elseif index == 3 then
        return "Ice"
    end
    return "Hard"
end
TireAudioModel.surfaceFromCode = surfaceFromCode

-- Ressources du manifeste (catégorie « Effets » par le préfixe audio.effect.).
TireAudioModel.Ids = table.freeze({
    RollDry = "audio.effect.tire.roll.dry",
    RollLoose = "audio.effect.tire.roll.loose",
    RollWet = "audio.effect.tire.roll.wet",
    Squeal = "audio.effect.tire.squeal",
    Scrub = "audio.effect.tire.scrub",
    SlideLoose = "audio.effect.tire.slide.loose",
})

-- État d'une roue vu par le son (copié de WheelRuntime et WheelContact par le contrôleur).
export type WheelSample = {
    Grounded: boolean,
    SlipRatio: number, -- glissement longitudinal (négatif au freinage), sans unité
    SlipAngle: number, -- angle de dérive (rad)
    ContactVx: number, -- vitesse du point de contact selon l'axe de la roue (m/s)
    ContactVy: number, -- vitesse latérale du point de contact (m/s)
    RollingSpeed: number, -- vitesse périphérique de la roue, ω × rayon (m/s)
    Surface: Surface,
    Wetness: number, -- 0 = sec, 1 = détrempé
}

-- Résumé sonore d'un véhicule : c'est aussi ce qui est transmis aux autres joueurs (glissement et revêtement).
export type Summary = {
    Speed: number, -- vitesse moyenne des contacts au sol (m/s)
    Grounded: number, -- fraction des roues au sol (0 à 1)
    Squeal: number, -- intensité de glissement sonore (0 à 1)
    Scrub: number, -- glissade franche (0 à 1)
    SlipSpeed: number, -- vitesse de glissement la plus forte (m/s), règle la hauteur du crissement
    Surface: Surface, -- famille majoritaire sous les roues au sol
    Wetness: number, -- humidité moyenne sous les roues au sol
    Abs: boolean, -- ABS en action (grondement pulsé)
}

-- Réglages de conception (provisoires, à ajuster à l'écoute du propriétaire).
-- Le crissement commence un peu AVANT le pic d'adhérence (pneu « à la limite ») et sature bien au-delà.
TireAudioModel.SquealOnsetFraction = 0.7 -- fraction du pic où le crissement commence
TireAudioModel.SquealFullAngleFactor = 2.5 -- dérive (× pic) où le crissement latéral est plein
TireAudioModel.SquealFullRatioFactor = 4 -- glissement longitudinal (× pic) où le crissement est plein
TireAudioModel.SlipSpeedGate = 0.4 -- m/s : en dessous, la gomme ne glisse pas assez vite pour crisser
TireAudioModel.SlipSpeedFull = 2.5 -- m/s : vitesse de glissement donnant le plein crissement
TireAudioModel.RollReferenceSpeed = 33 -- m/s (~120 km/h) : roulement plein
TireAudioModel.RollFadeInSpeed = 1 -- m/s : roulement inaudible en dessous
TireAudioModel.ReferenceMassKg = 1200
TireAudioModel.WetSquealFactor = 0.35 -- un pneu mouillé crisse peu : il chuinte
TireAudioModel.AbsPulseHz = 9 -- grondement de l'ABS (cycle de relâchement et de serrage)
TireAudioModel.SquealDeadband = 0.02 -- crissement résumé en dessous duquel on garde le silence
-- ABS en action : la dynamique maintient le glissement sous le pic, donc presque sans crissement calculé (banc planaire,
-- Brio, 80 → 0 km/h : crissement moyen 0,02). Une vraie voiture fait pourtant entendre un grondement saccadé : plancher
-- sonore, au-dessus de 3 m/s, ensuite pulsé par `layers` (véhicule conduit). Réglage à juger à l'écoute.
TireAudioModel.AbsSquealFloor = 0.35
TireAudioModel.AbsFloorMinSpeed = 3 -- m/s

local LAYER_LIMIT = { Low = 2, Medium = 4, High = 99 }

local function ramp(value: number, low: number, high: number): number
    if high <= low then
        return if value >= high then 1 else 0
    end
    return math.clamp((value - low) / (high - low), 0, 1)
end

--[[
    Résumé des roues. `peakSlipRatio` et `peakSlipAngleRad` : pics d'adhérence du pneu du modèle (définition).
    `absActive` : AidActivity.Abs de la dynamique.
]]
function TireAudioModel.summarize(
    wheels: { WheelSample },
    peakSlipRatio: number,
    peakSlipAngleRad: number,
    absActive: boolean?
): Summary
    local grounded, speedSum, wetSum, squealPower, scrubPower, slipSpeedMax = 0, 0, 0, 0, 0, 0
    local counts: { [string]: number } = { Hard = 0, Loose = 0, Soft = 0, Ice = 0 }
    local onsetAngle = peakSlipAngleRad * TireAudioModel.SquealOnsetFraction
    local fullAngle = peakSlipAngleRad * TireAudioModel.SquealFullAngleFactor
    local onsetRatio = peakSlipRatio * TireAudioModel.SquealOnsetFraction
    local fullRatio = peakSlipRatio * TireAudioModel.SquealFullRatioFactor
    for _, wheel in wheels do
        if not wheel.Grounded then
            continue
        end
        grounded += 1
        speedSum += math.sqrt(wheel.ContactVx * wheel.ContactVx + wheel.ContactVy * wheel.ContactVy)
        wetSum += math.clamp(wheel.Wetness, 0, 1)
        counts[wheel.Surface] += 1
        -- Vitesse de glissement de la gomme sur le sol : écart longitudinal (roue bloquée ou qui patine) et latéral.
        local dx = wheel.RollingSpeed - wheel.ContactVx
        local slipSpeed = math.sqrt(dx * dx + wheel.ContactVy * wheel.ContactVy)
        slipSpeedMax = math.max(slipSpeedMax, slipSpeed)
        local gate = ramp(slipSpeed, TireAudioModel.SlipSpeedGate, TireAudioModel.SlipSpeedFull)
        local lateral = ramp(math.abs(wheel.SlipAngle), onsetAngle, fullAngle)
        local longitudinal = ramp(math.abs(wheel.SlipRatio), onsetRatio, fullRatio)
        local squeal = math.max(lateral, longitudinal) * gate
        squealPower += squeal * squeal
        -- Glissade franche : au-delà de la moitié de la plage de crissement (roue bloquée, large dérapage).
        local scrub = ramp(math.max(lateral, longitudinal), 0.5, 1) * gate
        scrubPower += scrub * scrub
    end
    local surface: Surface = "Hard"
    local best = 0
    for _, name in TireAudioModel.Surfaces do
        if counts[name] > best then
            best = counts[name]
            surface = name :: Surface
        end
    end
    -- Somme en puissance : une roue pleinement en glisse ≈ 0,7, deux roues ou plus = plein crissement. Seuil de 0,02 :
    -- les micro-glissements transitoires (frein moteur, reprise d'adhérence) ne donnent pas un souffle permanent.
    local squeal = math.clamp(math.sqrt(squealPower) / 1.4, 0, 1)
    local speed = if grounded > 0 then speedSum / grounded else 0
    if absActive == true and grounded > 0 and speed > TireAudioModel.AbsFloorMinSpeed then
        squeal = math.max(squeal, TireAudioModel.AbsSquealFloor)
    end
    return {
        Speed = speed,
        Grounded = grounded / math.max(#wheels, 1),
        Squeal = if squeal < TireAudioModel.SquealDeadband then 0 else squeal,
        Scrub = math.clamp(math.sqrt(scrubPower) / 1.4, 0, 1),
        SlipSpeed = slipSpeedMax,
        Surface = surface,
        Wetness = if grounded > 0 then wetSum / grounded else 0,
        Abs = absActive == true,
    }
end

-- Résumé d'un véhicule observé : glissement et code de revêtement déclarés par son conducteur (bornés par le serveur,
-- attributs lus tels quels : toute valeur invalide donne « dur »), vitesse et humidité connues localement. La glissade
-- franche et la vitesse de glissement sont déduites du glissement.
function TireAudioModel.observed(squeal: number, surfaceCode: any, speedMs: number, wetness: number): Summary
    local level = math.clamp(squeal, 0, 1)
    local surface: Surface = surfaceFromCode(surfaceCode)
    return {
        Speed = math.max(speedMs, 0),
        Grounded = 1,
        Squeal = level,
        Scrub = ramp(level, 0.5, 1),
        SlipSpeed = TireAudioModel.SlipSpeedFull * level + 0.1 * math.max(speedMs, 0) * level,
        Surface = surface,
        Wetness = math.clamp(wetness, 0, 1),
        Abs = false,
    }
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
    Couches d'un véhicule. `massKg` : masse du modèle (un véhicule lourd roule plus fort et plus grave). `time` (s) :
    horloge pour la pulsation de l'ABS, seulement pour le véhicule conduit, mis à jour à chaque image (une mise à
    jour toutes les 0,1 s ne peut pas rendre une pulsation de 9 Hz).
]]
function TireAudioModel.layers(summary: Summary, massKg: number, quality: string?, time: number?): { Layer }
    local ids = TireAudioModel.Ids
    local speed = summary.Speed
    local massRatio = math.max(massKg, 100) / TireAudioModel.ReferenceMassKg
    local massGain = math.clamp(massRatio ^ 0.3, 0.8, 1.3)
    local massPitch = math.clamp(massRatio ^ -0.1, 0.9, 1.1)
    local wet = summary.Wetness
    local surface = summary.Surface

    -- Roulement : le bruit pneu-chaussée croît d'environ 30 dB par décade de vitesse (amplitude ∝ v^1,5).
    local roll = math.clamp((speed / TireAudioModel.RollReferenceSpeed) ^ 1.5, 0, 1)
        * ramp(speed, TireAudioModel.RollFadeInSpeed * 0.5, TireAudioModel.RollFadeInSpeed * 3)
        * summary.Grounded
        * massGain
    local rollPitch = (0.85 + 0.35 * math.clamp(speed / 40, 0, 1)) * massPitch
    local dry = if surface == "Hard" then roll * (1 - 0.4 * wet) elseif surface == "Ice" then roll * 0.4 else 0
    local loose = if surface == "Loose" then roll elseif surface == "Soft" then roll * 0.6 else 0
    local wetRoll = if surface == "Hard" or surface == "Ice" then roll * wet else 0

    -- Glissement : crissement sur le dur, glissade de gravier sur le meuble, presque rien sur la glace.
    local squeal = summary.Squeal * summary.Grounded
    if summary.Abs and time then
        -- ABS : la roue ne bloque pas ; grondement pulsé plutôt qu'un crissement continu.
        squeal *= 0.55 + 0.45 * math.max(0, math.sin(2 * math.pi * TireAudioModel.AbsPulseHz * time))
    end
    local hardSquealFactor = if surface == "Hard"
        then 1 - (1 - TireAudioModel.WetSquealFactor) * wet
        elseif surface == "Ice" then 0.1
        else 0
    local squealPitch = math.clamp(0.9 + 0.25 * ramp(summary.SlipSpeed, 1, 12), 0.85, 1.2) * massPitch
    local scrub = summary.Scrub * summary.Grounded * hardSquealFactor
    local slideLoose = if surface == "Loose" then squeal elseif surface == "Soft" then squeal * 0.6 else 0

    local layers: { Layer } = {
        { Id = ids.RollDry, Volume = dry * 0.6, Speed = rollPitch },
        { Id = ids.RollLoose, Volume = loose * 0.7, Speed = rollPitch * (if surface == "Soft" then 0.85 else 1) },
        { Id = ids.RollWet, Volume = wetRoll * 0.6, Speed = rollPitch },
        { Id = ids.Squeal, Volume = squeal * hardSquealFactor * 0.8 * massGain, Speed = squealPitch },
        { Id = ids.Scrub, Volume = scrub * 0.5 * massGain, Speed = rollPitch },
        { Id = ids.SlideLoose, Volume = slideLoose * 0.7 * massGain, Speed = rollPitch },
    }
    for _, layer in layers do
        layer.Volume = math.clamp(layer.Volume, 0, 1)
    end
    return keepLoudest(layers, quality)
end

return table.freeze(TireAudioModel)
