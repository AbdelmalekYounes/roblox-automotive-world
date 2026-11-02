--!strict
-- Comptabilité PURE de l'énergie (essence, diesel, électricité) d'un véhicule
-- pendant une session technique. Aucune persistance (lot 0.4), aucun achat,
-- aucune recharge : le niveau ne fait que baisser, sauf récupération électrique
-- physiquement possible.
--
-- Autorité serveur (AUD-PHYS-01) : le client simule la consommation détaillée
-- (régime, charge) et la déclare sous forme de CUMUL ; le serveur :
-- 1. calcule lui-même un PLANCHER physique à partir du mouvement qu'il observe
--    (énergie minimale pour produire l'accélération, vaincre l'air, le roulement
--    et la pente, au meilleur rendement du moteur) ;
-- 2. n'accepte la déclaration du client qu'à un débit plausible, et seulement
--    pour AUGMENTER la consommation au-delà du plancher ;
-- 3. calcule seul la récupération électrique, bornée par l'énergie cinétique
--    perdue et la capacité du moteur, et la refuse batterie vide.
-- Un client ne peut donc ni réduire sa consommation sous le plancher, ni créer
-- de l'énergie.

local Types = require(script.Parent.Parent.VehicleTypes)
local Engine = require(script.Parent.Engine)

local EnergyModel = {}

local GRAVITY = 9.81
local AIR_DENSITY = 1.225
-- Marge appliquée au débit maximal plausible déclaré par un client.
local CLIENT_RATE_MARGIN = 1.5

export type Account = {
    Kind: Types.EnergyKind,
    Capacity: number,
    Level: number,
    -- Réserve vide : verrouillée jusqu'à une recharge légitime (lots futurs).
    Empty: boolean,
    -- Cumuls de la session de conduite en cours (remis à zéro à chaque embarquement).
    FloorUsed: number,
    ClientAccepted: number,
    Withdrawn: number,
    -- Cumuls de session technique (diagnostic).
    TotalWithdrawn: number,
    TotalRecovered: number,
}

function EnergyModel.isElectric(definition: Types.VehicleDefinition): boolean
    return definition.Powertrain.Energy.Kind == "Electric"
end

-- Unité d'affichage de la réserve.
function EnergyModel.unit(definition: Types.VehicleDefinition): string
    return if EnergyModel.isElectric(definition) then "kWh" else "L"
end

function EnergyModel.newAccount(definition: Types.VehicleDefinition, level: number?): Account
    local store = definition.Powertrain.Energy
    local initial = math.clamp(level or store.Capacity * store.InitialFraction, 0, store.Capacity)
    return {
        Kind = store.Kind,
        Capacity = store.Capacity,
        Level = initial,
        Empty = initial <= 0,
        FloorUsed = 0,
        ClientAccepted = 0,
        Withdrawn = 0,
        TotalWithdrawn = 0,
        TotalRecovered = 0,
    }
end

-- Début d'une session de conduite : les cumuls déclarés repartent de zéro.
function EnergyModel.beginDriving(account: Account)
    account.FloorUsed = 0
    account.ClientAccepted = 0
    account.Withdrawn = 0
end

-- Débit maximal plausible (unités de réserve par seconde) d'un véhicule.
function EnergyModel.maxRate(definition: Types.VehicleDefinition): number
    local powertrain = definition.Powertrain
    local motor = powertrain.Motor
    if motor then
        return (motor.MaxPowerKw / motor.DriveEfficiency + motor.AuxPowerKw) / 3600 * CLIENT_RATE_MARGIN
    end
    local engine = powertrain.Engine :: Types.CombustionEngineDefinition
    local peakKw = 0
    for _, point in engine.TorqueCurve do
        peakKw = math.max(peakKw, point.TorqueNm * Engine.omega(point.Rpm) / 1000)
    end
    local bsfc = engine.BsfcGPerKWh * (1 + engine.PartLoadPenalty)
    local fuel = peakKw * bsfc / 3600 / 1000 / Engine.fuelDensity(powertrain.Energy.Kind)
    local idle = engine.IdleFuelLph / 3600 * engine.LimiterRpm / engine.IdleRpm
    return (fuel + idle) * CLIENT_RATE_MARGIN
end

--[[
    Plancher physique sur un intervalle observé par le serveur.
    `speedMs` / `previousSpeedMs` : vitesses (m/s) en fin et début d'intervalle ;
    `climbMs` : vitesse verticale moyenne (m/s, positive en montée).
    Retourne (énergie consommée, énergie récupérable), en unités de réserve.
]]
function EnergyModel.physicsFloor(
    definition: Types.VehicleDefinition,
    previousSpeedMs: number,
    speedMs: number,
    climbMs: number,
    dt: number
): (number, number)
    if dt <= 0 then
        return 0, 0
    end
    local chassis = definition.Chassis
    local powertrain = definition.Powertrain
    local mass = chassis.MassKg
    local v = (speedMs + previousSpeedMs) / 2
    local kinetic = 0.5 * mass * (speedMs * speedMs - previousSpeedMs * previousSpeedMs)
    local potential = mass * GRAVITY * climbMs * dt
    local drag = 0.5 * AIR_DENSITY * chassis.DragAreaM2 * v * v * v * dt
    local rolling = definition.Tires.RollingResistance * mass * GRAVITY * v * dt
    local wheelJoules = kinetic + potential + drag + rolling
    local efficiency = powertrain.Transmission.Efficiency
    local motor = powertrain.Motor
    if wheelJoules >= 0 then
        local shaftKWh = wheelJoules / efficiency / 3.6e6
        if motor then
            return shaftKWh / motor.DriveEfficiency, 0
        end
        local engine = powertrain.Engine :: Types.CombustionEngineDefinition
        -- Meilleur rendement possible : consommation spécifique minimale.
        return shaftKWh * engine.BsfcGPerKWh / 1000 / Engine.fuelDensity(powertrain.Energy.Kind), 0
    end
    if motor == nil then
        return 0, 0
    end
    -- Récupération : au plus l'énergie perdue (hors air et roulement), bornée
    -- par la puissance de récupération du moteur et les rendements.
    local available = math.min(-wheelJoules, motor.RegenMaxPowerKw * 1000 * dt)
    return 0, available * efficiency * motor.RegenEfficiency / 3.6e6
end

--[[
    Règle un intervalle : `floorUsed` et `recovered` viennent du plancher
    physique ; `clientCumulative` est le dernier cumul déclaré (ou nil).
    `dt` borne la part acceptée du client. Retourne l'énergie retirée.
]]
function EnergyModel.settle(
    account: Account,
    definition: Types.VehicleDefinition,
    floorUsed: number,
    recovered: number,
    clientCumulative: number?,
    dt: number
): number
    account.FloorUsed += math.max(floorUsed, 0)
    if clientCumulative and clientCumulative == clientCumulative and clientCumulative > account.ClientAccepted then
        local bound = account.ClientAccepted + EnergyModel.maxRate(definition) * dt
        account.ClientAccepted = math.min(clientCumulative, bound)
    end
    local withdrawn = math.max(account.FloorUsed, account.ClientAccepted)
    local delta = math.max(withdrawn - account.Withdrawn, 0)
    account.Withdrawn = withdrawn
    account.TotalWithdrawn += delta
    account.Level -= delta
    if not account.Empty and recovered > 0 and account.Kind == "Electric" then
        local gained = math.min(recovered, account.Capacity - account.Level)
        account.Level += gained
        account.TotalRecovered += gained
    end
    if account.Level <= 0 then
        account.Level = 0
        account.Empty = true
    end
    return delta
end

-- Prédiction locale du client : niveau serveur moins ce qu'il a consommé depuis.
function EnergyModel.predictLevel(serverLevel: number, usedSinceServerUpdate: number): number
    return serverLevel - math.max(usedSinceServerUpdate, 0)
end

return table.freeze(EnergyModel)
