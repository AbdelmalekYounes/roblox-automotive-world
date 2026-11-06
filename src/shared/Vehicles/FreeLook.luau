--!strict
--[[
    Caméra libre en conduite (lot CAMERA-01), module PUR testé hors Studio
    (tests/lune/specs/Camera01FreeLook.luau).

    Le joueur peut regarder autour de lui en conduisant, dans toutes les vues :
    - vues embarquées (cockpit, capot, pare-chocs) : rotation de la « tête »
      sur place, bornée de façon réaliste ;
    - vues de poursuite : orbite autour du véhicule, sur 360° en lacet.
    Ce module ne lit aucun périphérique : il reçoit des déplacements déjà
    mesurés (pixels de souris ou de doigt, position du stick) et tient l'état
    du regard (lacet, tangage) avec ses limites et son retour au centre.

    Conventions (les deux modes) :
    - Yaw (lacet, radians) : positif = regard vers la DROITE du véhicule ;
    - Pitch (tangage, radians) : positif = regard vers le HAUT. En orbite,
      regarder vers le haut abaisse la caméra (comme la caméra Roblox à pied).

    Décisions du propriétaire (2026-11-06) :
    - limites « réalistes » : vues embarquées ±120° en lacet, −40° à +30° en
      tangage ; poursuite : 360° en lacet, la caméra monte jusqu'à 60° au-dessus
      de sa hauteur de base et descend de 10° au plus (tangage +10° à −60°) ;
    - retour au centre : la vue reste 1,5 s après le relâchement puis revient
      en ≈ 0,7 s ; dès 15 km/h, elle revient après 0,4 s, en ≈ 0,4 s.
]]

local FreeLook = {}

export type Limits = {
    YawMax: number, -- borne symétrique du lacet (rad)
    PitchMin: number, -- tangage minimal (rad, négatif = regard vers le bas)
    PitchMax: number,
    Wrap: boolean, -- vrai : lacet circulaire sur ]−π ; π] (orbite complète)
}

export type State = {
    Yaw: number,
    Pitch: number,
    -- Temps écoulé depuis la dernière sollicitation (s) : déclenche le retour au centre.
    IdleS: number,
    Holding: boolean,
}

FreeLook.Limits = table.freeze({
    Mounted = table.freeze({
        YawMax = math.rad(120),
        PitchMin = math.rad(-40),
        PitchMax = math.rad(30),
        Wrap = false,
    } :: Limits),
    Orbit = table.freeze({
        YawMax = math.pi,
        PitchMin = math.rad(-60),
        PitchMax = math.rad(10),
        Wrap = true,
    } :: Limits),
})

-- Retour au centre (décision du propriétaire).
FreeLook.RecenterDelayS = 1.5
FreeLook.RecenterDelayMovingS = 0.4
-- Décroissance exponentielle : e^(−4,3 × 0,7) ≈ 0,05, soit 95 % du chemin en 0,7 s.
FreeLook.RecenterRate = 4.3
-- e^(−7,5 × 0,4) ≈ 0,05 : 95 % du chemin en 0,4 s.
FreeLook.RecenterRateMoving = 7.5
FreeLook.MovingKmh = 15
-- Sous ce seuil, le regard est remis exactement à zéro (pas de traîne infinie).
FreeLook.SettleRad = math.rad(0.05)

-- Sensibilité réglable par le joueur (niveaux 1 à 5, défaut 3 = facteur 1).
FreeLook.SensitivityLevels = table.freeze({ 0.5, 0.75, 1, 1.4, 2 })
FreeLook.DefaultSensitivity = 3
-- Gains de base (sensibilité 3) : souris 0,25° par pixel, doigt 0,35° par
-- pixel (écrans tactiles plus petits), stick 150°/s à fond.
FreeLook.MouseRadPerPixel = math.rad(0.25)
FreeLook.TouchRadPerPixel = math.rad(0.35)
FreeLook.StickRadPerS = math.rad(150)
FreeLook.StickDeadzone = 0.15

-- Fondu d'une visée imposée (interface de la 2e vague : téléphone tenu en main).
FreeLook.DefaultBlendS = 0.35

function FreeLook.newState(): State
    return { Yaw = 0, Pitch = 0, IdleS = 0, Holding = false }
end

-- Regard remis droit devant, immédiatement (changement de vue, début de conduite).
function FreeLook.reset(state: State)
    state.Yaw = 0
    state.Pitch = 0
    state.IdleS = 0
    state.Holding = false
end

-- Angle ramené sur ]−π ; π].
function FreeLook.wrapAngle(angle: number): number
    local wrapped = (angle + math.pi) % (2 * math.pi) - math.pi
    if wrapped <= -math.pi then
        wrapped += 2 * math.pi
    end
    return wrapped
end

local function finite(value: number): boolean
    return value == value and value ~= math.huge and value ~= -math.huge
end

-- Applique les limites du mode (changement de vue : orbite → embarquée par exemple).
function FreeLook.clamp(state: State, limits: Limits)
    if limits.Wrap then
        state.Yaw = FreeLook.wrapAngle(state.Yaw)
    else
        state.Yaw = math.clamp(state.Yaw, -limits.YawMax, limits.YawMax)
    end
    state.Pitch = math.clamp(state.Pitch, limits.PitchMin, limits.PitchMax)
end

-- Ajoute un déplacement du regard (radians) et le borne. Une valeur non finie
-- (périphérique défaillant) est ignorée : jamais de caméra « perdue ».
function FreeLook.applyDelta(state: State, dYaw: number, dPitch: number, limits: Limits)
    if not finite(dYaw) or not finite(dPitch) then
        return
    end
    if dYaw ~= 0 or dPitch ~= 0 then
        state.IdleS = 0
    end
    state.Yaw += dYaw
    state.Pitch += dPitch
    FreeLook.clamp(state, limits)
end

-- Facteur de sensibilité d'un niveau (borné, arrondi ; valeur invalide → défaut).
function FreeLook.sensitivity(level: number?): number
    local index = if type(level) == "number" and level == level
        then math.clamp(math.floor(level + 0.5), 1, #FreeLook.SensitivityLevels)
        else FreeLook.DefaultSensitivity
    return FreeLook.SensitivityLevels[index]
end

-- Déplacement d'un pointeur (souris ou doigt) en pixels d'écran → (dYaw, dPitch).
-- dx > 0 : vers la droite ; dy > 0 : vers le BAS de l'écran (convention Roblox).
function FreeLook.pointerDelta(
    dx: number,
    dy: number,
    radPerPixel: number,
    sensitivityLevel: number?,
    invertY: boolean?
): (number, number)
    local gain = radPerPixel * FreeLook.sensitivity(sensitivityLevel)
    local pitch = -dy * gain
    return dx * gain, if invertY then -pitch else pitch
end

-- Stick (x, y dans [−1 ; 1], y > 0 = poussé vers le haut) pendant dt → (dYaw, dPitch).
-- Zone morte radiale puis courbe quadratique : précision au centre, vitesse à fond.
function FreeLook.stickDelta(
    x: number,
    y: number,
    dt: number,
    sensitivityLevel: number?,
    invertY: boolean?
): (number, number)
    if not finite(x) or not finite(y) then
        return 0, 0
    end
    local magnitude = math.sqrt(x * x + y * y)
    if magnitude <= FreeLook.StickDeadzone then
        return 0, 0
    end
    local scaled = math.min((magnitude - FreeLook.StickDeadzone) / (1 - FreeLook.StickDeadzone), 1)
    local speed = scaled * scaled * FreeLook.StickRadPerS * FreeLook.sensitivity(sensitivityLevel) * dt
    local pitch = y / magnitude * speed
    return x / magnitude * speed, if invertY then -pitch else pitch
end

-- Vrai si le stick est sollicité (hors zone morte) : le joueur « tient » le regard.
function FreeLook.stickHeld(x: number, y: number): boolean
    return finite(x) and finite(y) and math.sqrt(x * x + y * y) > FreeLook.StickDeadzone
end

-- Un pas de temps : `holding` = le joueur tient le regard (clic droit, doigt
-- posé, stick hors zone morte) ; `speedKmh` = vitesse du véhicule.
function FreeLook.step(state: State, dt: number, holding: boolean, speedKmh: number)
    if holding then
        state.Holding = true
        state.IdleS = 0
        return
    end
    state.Holding = false
    if state.Yaw == 0 and state.Pitch == 0 then
        return
    end
    state.IdleS += math.max(dt, 0)
    local moving = finite(speedKmh) and speedKmh >= FreeLook.MovingKmh
    local delay = if moving then FreeLook.RecenterDelayMovingS else FreeLook.RecenterDelayS
    if state.IdleS < delay then
        return
    end
    local rate = if moving then FreeLook.RecenterRateMoving else FreeLook.RecenterRate
    -- Lissage exponentiel indépendant de la cadence d'image : seule la part de
    -- l'image écoulée après le délai compte. Le lacet étant sur ]−π ; π], le
    -- retour prend toujours le chemin le plus court.
    local effective = math.clamp(state.IdleS - delay, 0, math.max(dt, 0))
    local keep = math.exp(-rate * effective)
    state.Yaw *= keep
    state.Pitch *= keep
    if math.abs(state.Yaw) < FreeLook.SettleRad and math.abs(state.Pitch) < FreeLook.SettleRad then
        state.Yaw = 0
        state.Pitch = 0
    end
end

function FreeLook.isCentered(state: State): boolean
    return state.Yaw == 0 and state.Pitch == 0
end

-- Progression linéaire (0 → 1 ou 1 → 0) du fondu vers une visée imposée.
function FreeLook.stepBlend(alpha: number, active: boolean, dt: number, blendS: number?): number
    local duration = if type(blendS) == "number" and blendS > 0 then blendS else FreeLook.DefaultBlendS
    local delta = math.max(dt, 0) / duration
    return math.clamp(if active then alpha + delta else alpha - delta, 0, 1)
end

-- Adoucissement du fondu (départ et arrivée sans à-coup).
function FreeLook.ease(alpha: number): number
    local a = math.clamp(alpha, 0, 1)
    return a * a * (3 - 2 * a)
end

return table.freeze(FreeLook)
