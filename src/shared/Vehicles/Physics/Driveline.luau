--!strict
-- Répartition PURE du couple de la boîte vers les quatre roues : différentiel
-- central (transmission intégrale) puis différentiels d'essieu.
--
-- - Différentiel ouvert : couples ÉGAUX à gauche et à droite, quelle que soit
--   l'adhérence ; une roue délestée patine et le couple transmissible est
--   limité par elle (perte de motricité caractéristique).
-- - Autobloquant à friction : un couple de blocage (précharge + fraction du
--   couple d'entrée, différente en traction et en retenue) transfère du couple
--   de la roue la plus rapide vers la plus lente, sans dépasser cette capacité.
-- Le transfert est proportionnel à l'écart de vitesse dans une petite bande
-- (comportement d'un embrayage à friction qui colle), largeur choisie pour
-- rester stable au pas d'intégration utilisé.
-- Ordre des roues : 1 avant gauche, 2 avant droite, 3 arrière gauche, 4 arrière droite.

local Types = require(script.Parent.Parent.VehicleTypes)

local Driveline = {}

local MIN_BAND = 0.5 -- rad/s

-- Part du couple de boîte reçue par chaque roue avec des différentiels ouverts.
function Driveline.wheelDriveShares(drivetrain: Types.DrivetrainDefinition): { number }
    local front = math.clamp(drivetrain.FrontTorqueShare, 0, 1)
    local rear = 1 - front
    return { front / 2, front / 2, rear / 2, rear / 2 }
end

-- Couple de blocage disponible (N·m) pour un couple d'entrée signé.
function Driveline.lockingTorque(differential: Types.DifferentialDefinition, inputTorque: number): number
    if differential.Kind == "Open" then
        return 0
    end
    local ratio = if inputTorque >= 0 then differential.PowerLockRatio else differential.CoastLockRatio
    return differential.PreloadNm + ratio * math.abs(inputTorque)
end

--[[
    Couple transféré de la sortie A vers la sortie B (N·m, signé) : positif
    quand A tourne plus vite que B. `inertia` = plus petite inertie concernée ;
    la bande garantit h × raideur / inertie ≤ 0,5.
]]
local function transfer(capacity: number, omegaA: number, omegaB: number, inertia: number, h: number): number
    if capacity <= 0 then
        return 0
    end
    local band = math.max(MIN_BAND, 2 * capacity * h / math.max(inertia, 1e-3))
    return capacity * math.clamp((omegaA - omegaB) / band, -1, 1)
end

--[[
    Répartit `inputTorque` (N·m au niveau des roues, après rapport et rendement)
    et écrit le couple de chaque roue dans `out`.
    `omegas` et `inertias` : vitesse angulaire et inertie vue par chaque roue.
]]
function Driveline.distribute(
    drivetrain: Types.DrivetrainDefinition,
    inputTorque: number,
    omegas: { number },
    inertias: { number },
    h: number,
    out: { number }
)
    local frontShare = math.clamp(drivetrain.FrontTorqueShare, 0, 1)
    local frontTorque = inputTorque * frontShare
    local rearTorque = inputTorque - frontTorque

    local center = drivetrain.CenterDifferential
    if center and frontShare > 0 and frontShare < 1 then
        local capacity = Driveline.lockingTorque(center, inputTorque)
        local frontOmega = (omegas[1] + omegas[2]) / 2
        local rearOmega = (omegas[3] + omegas[4]) / 2
        local axleInertia = math.min(inertias[1] + inertias[2], inertias[3] + inertias[4])
        local moved = transfer(capacity, frontOmega, rearOmega, axleInertia, h)
        frontTorque -= moved
        rearTorque += moved
    end

    for _, axle in
        {
            { Left = 1, Right = 2, Torque = frontTorque, Differential = drivetrain.FrontDifferential },
            { Left = 3, Right = 4, Torque = rearTorque, Differential = drivetrain.RearDifferential },
        }
    do
        local half = axle.Torque / 2
        local capacity = Driveline.lockingTorque(axle.Differential, axle.Torque)
        local moved = transfer(
            capacity,
            omegas[axle.Left],
            omegas[axle.Right],
            math.min(inertias[axle.Left], inertias[axle.Right]),
            h
        )
        out[axle.Left] = half - moved / 2
        out[axle.Right] = half + moved / 2
    end
end

return table.freeze(Driveline)
