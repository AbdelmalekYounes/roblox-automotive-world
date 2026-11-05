--!strict
-- Sources de couple PURES (aucune API Roblox) : moteur thermique (essence,
-- diesel) et moteur électrique, avec leur consommation instantanée.
--
-- Le moteur est un corps en rotation (inertie propre) ; le couple calculé ici
-- est appliqué par `Driveline`, qui le couple aux roues selon la boîte.
-- Les différences essence / diesel viennent UNIQUEMENT des valeurs des
-- définitions (courbe de couple, régimes, consommation spécifique) : un diesel
-- a plus de couple à bas régime, une plage plus étroite et un meilleur rendement.

local Types = require(script.Parent.Parent.VehicleTypes)

local Engine = {}

local RPM_PER_RAD_S = 60 / (2 * math.pi)
-- Densités des carburants (kg/L), valeurs usuelles.
local FUEL_DENSITY: { [string]: number } = {
    Petrol = 0.745,
    Diesel = 0.835,
}
-- Plage de la régulation de ralenti (fraction du régime de ralenti).
local IDLE_CONTROL_BAND = 0.08
-- Le moteur électrique ne récupère plus d'énergie en dessous de cette vitesse
-- de rotation des roues (rad/s au moteur) : arrêt doux, pas de marche arrière.
local REGEN_FADE_RAD_S = 60

function Engine.rpm(omega: number): number
    return omega * RPM_PER_RAD_S
end

function Engine.omega(rpm: number): number
    return rpm / RPM_PER_RAD_S
end

-- Masse volumique du carburant (kg/L).
function Engine.fuelDensity(kind: Types.EnergyKind): number
    return FUEL_DENSITY[kind] or FUEL_DENSITY.Petrol
end

-- Interpolation linéaire de la courbe de couple (bornée aux extrémités).
function Engine.sampleTorque(curve: { Types.TorquePoint }, rpm: number): number
    local count = #curve
    if count == 0 then
        return 0
    end
    if rpm <= curve[1].Rpm then
        return curve[1].TorqueNm
    end
    for i = 2, count do
        local high = curve[i]
        if rpm <= high.Rpm then
            local low = curve[i - 1]
            local t = (rpm - low.Rpm) / (high.Rpm - low.Rpm)
            return low.TorqueNm + (high.TorqueNm - low.TorqueNm) * t
        end
    end
    return curve[count].TorqueNm
end

-- Couple de frottement et de pompage (négatif), papillon fermé.
function Engine.dragTorque(engine: Types.CombustionEngineDefinition, rpm: number): number
    return -engine.EngineBrakeTorqueNm * math.max(rpm, 0) / engine.RedlineRpm
end

--[[
    Couple net du moteur thermique (N·m) à la vitesse `omega` (rad/s).
    - `throttle` 0..1 mélange le couple de pleine charge et le frottement ;
    - rupteur : injection coupée au-delà de LimiterRpm ;
    - régulation de ralenti : couple ajouté sous le ralenti, papillon fermé
      (fonction normale d'un moteur, pas une aide) ;
    - moteur arrêté (calé, panne sèche) : frottement seulement.
    `powerFactor` (dégâts) réduit le couple de combustion, jamais le frottement.
]]
function Engine.combustionTorque(
    engine: Types.CombustionEngineDefinition,
    omega: number,
    throttle: number,
    running: boolean,
    powerFactor: number
): number
    local rpm = omega * RPM_PER_RAD_S
    local drag = Engine.dragTorque(engine, rpm)
    if not running or rpm >= engine.LimiterRpm then
        return drag
    end
    local full = Engine.sampleTorque(engine.TorqueCurve, rpm) * powerFactor
    local torque = throttle * full + (1 - throttle) * drag
    local idleTarget = engine.IdleRpm * 1.02
    if rpm < idleTarget then
        local demand = (idleTarget - rpm) / (engine.IdleRpm * IDLE_CONTROL_BAND)
        torque += engine.IdleControlTorqueNm * math.clamp(demand, 0, 1) * (1 - throttle)
    end
    return torque
end

-- Couple maximal de pleine charge disponible à un régime (charge relative).
function Engine.fullLoadTorque(engine: Types.CombustionEngineDefinition, rpm: number): number
    return Engine.sampleTorque(engine.TorqueCurve, math.max(rpm, engine.IdleRpm))
end

--[[
    Débit de carburant (L/s) d'un moteur thermique.
    - arrêté : 0 ;
    - coupure en décélération (papillon fermé au-dessus de 1,3 × ralenti) et
      au rupteur : 0 (comportement des injections modernes) ;
    - sinon : part liée au régime (frottements, pompage : débit de ralenti
      proportionnel au régime) + part liée à la puissance produite, avec une
      consommation spécifique qui se dégrade à faible charge.
]]
function Engine.fuelFlowLps(
    engine: Types.CombustionEngineDefinition,
    kind: Types.EnergyKind,
    omega: number,
    torque: number,
    throttle: number,
    running: boolean
): number
    if not running then
        return 0
    end
    local rpm = omega * RPM_PER_RAD_S
    if rpm >= engine.LimiterRpm or (throttle < 0.02 and rpm > engine.IdleRpm * 1.3) then
        return 0
    end
    local density = FUEL_DENSITY[kind] or FUEL_DENSITY.Petrol
    local base = engine.IdleFuelLph / 3600 * math.max(rpm, engine.IdleRpm * 0.5) / engine.IdleRpm
    local powerKw = math.max(torque, 0) * math.max(omega, 0) / 1000
    if powerKw <= 0 then
        return base
    end
    local load = math.clamp(torque / math.max(Engine.fullLoadTorque(engine, rpm), 1), 0, 1)
    local bsfc = engine.BsfcGPerKWh * (1 + engine.PartLoadPenalty * (1 - load))
    return base + powerKw * bsfc / 3600 / 1000 / density
end

-- Couple maximal du moteur électrique à la vitesse `omega` (rad/s, valeur absolue).
function Engine.motorMaxTorque(motor: Types.ElectricMotorDefinition, omega: number): number
    local w = math.abs(omega)
    if w * RPM_PER_RAD_S >= motor.MaxRpm then
        return 0
    end
    local powerLimited = motor.MaxPowerKw * 1000 / math.max(w, 1e-3)
    return math.min(motor.MaxTorqueNm, powerLimited)
end

-- Couple maximal de récupération (positif, s'oppose à la rotation).
function Engine.motorRegenTorque(motor: Types.ElectricMotorDefinition, omega: number): number
    local w = math.abs(omega)
    local capacity = math.min(motor.RegenMaxTorqueNm, motor.RegenMaxPowerKw * 1000 / math.max(w, 1e-3))
    return capacity * math.clamp(w / REGEN_FADE_RAD_S, 0, 1)
end

--[[
    Couple du moteur électrique (N·m, signé dans le sens de marche du rapport) :
    - `throttle` > 0 : traction, réduite au voisinage de la vitesse limitée ;
    - accélérateur relâché : récupération au niveau `regenFraction` ;
    - réserve vide : aucun couple (ni traction, ni récupération).
    `speedRatio` = vitesse du véhicule / vitesse limitée.
]]
function Engine.motorTorque(
    motor: Types.ElectricMotorDefinition,
    omega: number,
    throttle: number,
    regenFraction: number,
    speedRatio: number,
    available: boolean,
    powerFactor: number
): number
    if not available then
        return 0
    end
    if throttle > 0.02 then
        -- Limitation de vitesse : couple retiré entre 97 % et 100 % de la vitesse limitée.
        local limiter = math.clamp((1 - speedRatio) / 0.03, 0, 1)
        return throttle * Engine.motorMaxTorque(motor, omega) * limiter * powerFactor
    end
    if regenFraction <= 0 then
        return 0
    end
    return -math.sign(omega) * Engine.motorRegenTorque(motor, omega) * regenFraction
end

--[[
    Puissance prélevée sur la batterie (kW, négative en récupération) pour une
    puissance mécanique `mechanicalKw` (positive en traction).
]]
function Engine.batteryPowerKw(motor: Types.ElectricMotorDefinition, mechanicalKw: number, driving: boolean): number
    local aux = if driving then motor.AuxPowerKw else 0
    if mechanicalKw >= 0 then
        return mechanicalKw / motor.DriveEfficiency + aux
    end
    return mechanicalKw * motor.RegenEfficiency + aux
end

return table.freeze(Engine)
