--!strict
-- Modèle de pneumatique simplifié, PUR (aucune API Roblox) et testable hors Studio.
--
-- Principe : la force transmise dépend du glissement (taux de glissement en
-- longitudinal, angle de dérive en latéral). Elle croît jusqu'à un pic
-- d'adhérence puis décroît vers une valeur de glissement franc. Les deux
-- directions partagent l'adhérence disponible via une ellipse de friction.
-- Ce n'est PAS un modèle Pacejka complet : c'est une base paramétrable,
-- destinée à être affinée (lot 0.2).

local TireModel = {}

-- Vitesse de référence minimale (m/s) pour le calcul des glissements :
-- évite la division par zéro et l'instabilité numérique à très basse vitesse.
-- 4 m/s garde la raideur du pneu sous le seuil de stabilité de l'intégration
-- explicite du châssis (Roblox applique une force constante pendant l'image).
-- Limite connue : sans modèle de frottement statique, un véhicule freiné sur
-- une pente glisse très lentement (quelques cm/s) ; à traiter au lot 0.2.
TireModel.LowSpeedReference = 4.0

local ANGULAR_EPSILON = 1e-4

--[[
    Courbe normalisée d'adhérence.
    `ratio` = glissement / glissement au pic.
    - 0 → 0 ; 1 → 1 (pic, pente nulle) ;
    - au-delà, décroissance linéaire vers `slidingRatio`, atteinte à ratio = 3.
    La pente à l'origine vaut 2 (utilisée par l'intégration implicite).
]]
function TireModel.curve(ratio: number, slidingRatio: number): number
    local s = math.abs(ratio)
    if s <= 1 then
        return s * (2 - s)
    end
    local fade = math.min((s - 1) / 2, 1)
    return 1 - (1 - slidingRatio) * fade
end

-- Sensibilité à la charge : un pneu plus chargé offre un coefficient
-- d'adhérence légèrement plus faible (comportement réel des pneumatiques).
function TireModel.loadAdjustedFriction(
    baseFriction: number,
    normalForce: number,
    nominalLoad: number,
    loadSensitivity: number
): number
    if nominalLoad <= 0 then
        return baseFriction
    end
    local factor = 1 - loadSensitivity * (normalForce / nominalLoad - 1)
    return baseFriction * math.clamp(factor, 0.6, 1.25)
end

-- Ellipse de friction : la somme normalisée des efforts ne dépasse pas 1.
function TireModel.combine(fx: number, fy: number, maxLongitudinal: number, maxLateral: number): (number, number)
    if maxLongitudinal <= 0 or maxLateral <= 0 then
        return 0, 0
    end
    local nx = fx / maxLongitudinal
    local ny = fy / maxLateral
    local n = math.sqrt(nx * nx + ny * ny)
    if n > 1 then
        return fx / n, fy / n
    end
    return fx, fy
end

--[[
    Limite anti-dépassement : une force de frottement ne doit jamais inverser,
    en une seule image, la vitesse relative qu'elle combat. Sans cette limite,
    l'intégration explicite de Roblox (force constante pendant l'image)
    ferait osciller le véhicule à l'arrêt.
]]
function TireModel.stopClamp(force: number, effectiveMass: number, relativeVelocity: number, dt: number): number
    if dt <= 0 then
        return force
    end
    local limit = effectiveMass * math.abs(relativeVelocity) / dt
    return math.clamp(force, -limit, limit)
end

local function longitudinalForce(
    omega: number,
    radius: number,
    vx: number,
    vref: number,
    peakForce: number,
    peakSlip: number,
    slidingRatio: number
): (number, number)
    local slip = (omega * radius - vx) / vref
    return math.sign(slip) * peakForce * TireModel.curve(slip / peakSlip, slidingRatio), slip
end

-- Pente de la courbe normalisée (dérivée par rapport au ratio), nulle au-delà du pic.
local function curveSlope(ratio: number): number
    local s = math.abs(ratio)
    if s < 1 then
        return 2 - 2 * s
    end
    return 0
end

--[[
    Intègre la rotation d'une roue au sol pendant `dt`, en `substeps` sous-pas.
    - Avant le pic d'adhérence : Euler semi-implicite, avec la force du pneu
      linéarisée autour du glissement courant (stable malgré la raideur du pneu,
      et cohérent avec la force réellement transmise au châssis).
    - Au-delà du pic : pente nulle, intégration explicite (patinage/blocage).
    - Le frein s'oppose à la rotation sans jamais l'inverser ; une roue
      immobile reste bloquée tant que le frein peut retenir le couple net.
    Retourne la nouvelle vitesse angulaire, la force longitudinale moyenne (N)
    et le dernier taux de glissement.
]]
function TireModel.integrateWheel(
    omega: number,
    driveTorque: number,
    brakeTorque: number,
    inertia: number,
    radius: number,
    vx: number,
    peakForce: number,
    peakSlip: number,
    slidingRatio: number,
    dt: number,
    substeps: number
): (number, number, number)
    local vref = math.max(math.abs(vx), TireModel.LowSpeedReference)
    local h = dt / substeps
    local fxSum = 0
    local slip = 0

    for _ = 1, substeps do
        local direction = if omega > ANGULAR_EPSILON then 1 elseif omega < -ANGULAR_EPSILON then -1 else 0
        local fx: number
        local stepDone = false

        if direction == 0 then
            -- Roue immobile : le frein agit comme un couple de maintien statique.
            local fx0, slip0 = longitudinalForce(0, radius, vx, vref, peakForce, peakSlip, slidingRatio)
            local net = driveTorque - fx0 * radius
            if math.abs(net) <= brakeTorque then
                omega = 0
                fx = fx0
                slip = slip0
                stepDone = true
            else
                direction = if net > 0 then 1 else -1
                omega = 0
            end
        end

        if not stepDone then
            local torque = driveTorque - brakeTorque * direction
            local fxNow, slipNow = longitudinalForce(omega, radius, vx, vref, peakForce, peakSlip, slidingRatio)
            -- dFx/dω (N·s/rad) au point courant ; ≥ 0 avant le pic, 0 après.
            local stiffness = peakForce * curveSlope(slipNow / peakSlip) / peakSlip * radius / vref
            local w = omega + h / inertia * (torque - fxNow * radius) / (1 + h * radius * stiffness / inertia)
            if brakeTorque > 0 and w * direction < 0 then
                -- Le frein ne peut pas inverser le sens de rotation : blocage.
                w = 0
            end
            omega = w
            fx, slip = longitudinalForce(omega, radius, vx, vref, peakForce, peakSlip, slidingRatio)
        end

        fxSum += fx
    end

    return omega, fxSum / substeps, slip
end

-- Roue en l'air : aucune force de contact, seuls moteur et frein agissent.
function TireModel.integrateFreeWheel(
    omega: number,
    driveTorque: number,
    brakeTorque: number,
    inertia: number,
    dt: number
): number
    local w = omega + dt / inertia * driveTorque
    local brakeDelta = brakeTorque * dt / inertia
    if math.abs(w) <= brakeDelta then
        return 0
    end
    return w - math.sign(w) * brakeDelta
end

-- Force latérale (N, positive vers la droite de la roue) selon l'angle de dérive.
function TireModel.lateralForce(
    lateralVelocity: number,
    longitudinalVelocity: number,
    peakForce: number,
    peakSlipAngleRad: number,
    slidingRatio: number
): number
    local vref = math.max(math.abs(longitudinalVelocity), TireModel.LowSpeedReference)
    local alpha = math.atan2(lateralVelocity, vref)
    return -math.sign(alpha) * peakForce * TireModel.curve(alpha / peakSlipAngleRad, slidingRatio)
end

return table.freeze(TireModel)
