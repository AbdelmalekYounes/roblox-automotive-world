--!strict
-- Boîtes de vitesses PURES (aucune API Roblox) : choix du rapport, commandes
-- du conducteur et loi de couplage moteur ↔ roues de chaque famille.
--
-- - Automatique : convertisseur de couple (glissement, multiplication de couple
--   au démarrage) + pontage sur les rapports longs ; passages selon le régime
--   de turbine et la charge ; marche arrière par maintien de « freiner » (A3).
-- - Manuelle : embrayage commandé par le conducteur ; un passage exige la
--   pédale enfoncée ; le moteur peut caler ; marche arrière par sélecteur (A3).
-- - Double embrayage : passages automatiques très rapides, palettes du
--   conducteur prioritaires pendant 4 s ; embrayage de démarrage automatisé.
-- - Séquentielle : passages par le conducteur uniquement, rapport par rapport,
--   coupure d'allumage brève ; embrayage de démarrage automatisé.
-- - CVT : rapport continu choisi pour viser un régime moteur dépendant de la
--   charge ; embrayage de démarrage automatisé.
-- - Rapport unique (électrique) : couplage permanent, marche arrière par
--   inversion du moteur (maintien de « freiner », A3).
-- Les protections mécaniques (pas de marche arrière en roulant, pas de
-- rétrogradation au-delà du rupteur pour les boîtes pilotées) sont ici.

local Types = require(script.Parent.Parent.VehicleTypes)
local Engine = require(script.Parent.Engine)

local Transmission = {}

-- En dessous de cette vitesse (m/s), le véhicule est considéré à l'arrêt.
Transmission.StopSpeed = 0.8
-- Durée de maintien (s) de la commande opposée avant inversion du sens (A3).
Transmission.DirectionHoldS = 0.3
-- Pédale d'embrayage enfoncée au moins à ce point pour changer de rapport.
Transmission.ClutchShiftThreshold = 0.8
-- Double embrayage : durée de priorité d'une demande du conducteur (palettes).
Transmission.ManualHoldS = 4
-- Démarreur : délai de relance d'un moteur calé.
Transmission.StarterDurationS = 0.6

export type ShiftResult = "Ok" | "NotAvailable" | "ClutchRequired" | "StopRequired" | "OverRev" | "Limit"
export type CouplingMode = "Open" | "Rigid" | "Clutch" | "Converter"

-- Vrai si la boîte accepte les commandes de montée/descente du conducteur.
function Transmission.hasSelector(kind: string): boolean
    return kind == "Manual" or kind == "DualClutch" or kind == "Sequential"
end

-- Rapport de boîte signé : négatif en marche arrière, 0 au neutre.
function Transmission.gearRatio(state: Types.VehicleRuntimeState, transmission: Types.TransmissionDefinition): number
    local gear = state.Gear
    if gear == 0 then
        return 0
    elseif gear < 0 then
        return -transmission.ReverseRatio
    end
    if transmission.Kind == "CVT" then
        return state.CvtRatio
    end
    return transmission.ForwardRatios[gear] or 0
end

function Transmission.overallRatio(state: Types.VehicleRuntimeState, transmission: Types.TransmissionDefinition): number
    return Transmission.gearRatio(state, transmission) * transmission.FinalDrive
end

-- Rapport global d'un rapport donné (rapports fixes), signé.
function Transmission.fixedOverallRatio(transmission: Types.TransmissionDefinition, gear: number): number
    if gear == 0 then
        return 0
    elseif gear < 0 then
        return -transmission.ReverseRatio * transmission.FinalDrive
    end
    return (transmission.ForwardRatios[gear] or 0) * transmission.FinalDrive
end

-- Nombre de rapports avant sélectionnables (CVT et rapport unique : 1).
function Transmission.forwardGearCount(transmission: Types.TransmissionDefinition): number
    if transmission.Kind == "CVT" or transmission.Kind == "SingleSpeed" then
        return 1
    end
    return #transmission.ForwardRatios
end

-- Régime maximal sûr du moteur (rupteur thermique ou régime maximal électrique).
local function limitRpm(powertrain: Types.PowertrainDefinition): number
    if powertrain.Engine then
        return powertrain.Engine.LimiterRpm
    end
    return (powertrain.Motor :: Types.ElectricMotorDefinition).MaxRpm
end

local function idleRpm(powertrain: Types.PowertrainDefinition): number
    return if powertrain.Engine then powertrain.Engine.IdleRpm else 0
end

-- Sélection « maintien de freiner » (automatique, CVT, rapport unique), arbitrage A3.
-- Retourne (accélérateur effectif, pédale de frein effective) : en marche
-- arrière, « freiner » devient l'accélérateur et « accélérer » le frein.
local function updateHoldBrakeSelection(
    state: Types.VehicleRuntimeState,
    input: Types.DriverInput,
    forwardSpeed: number,
    dt: number
): (number, number)
    local throttle = input.Throttle
    local brake = input.Brake
    local stopped = math.abs(forwardSpeed) < Transmission.StopSpeed

    if state.Gear >= 0 then
        if state.Gear == 0 and throttle > 0.05 then
            state.Gear = 1
        end
        if stopped and brake > 0.1 and throttle < 0.05 then
            state.DirectionRequestTimer += dt
            if state.DirectionRequestTimer >= Transmission.DirectionHoldS then
                state.Gear = -1
                state.DirectionRequestTimer = 0
                state.ShiftTimer = 0
            end
        else
            state.DirectionRequestTimer = 0
        end
    else
        if stopped and throttle > 0.1 and brake < 0.05 then
            state.DirectionRequestTimer += dt
            if state.DirectionRequestTimer >= Transmission.DirectionHoldS * 0.5 then
                state.Gear = 1
                state.DirectionRequestTimer = 0
                state.ShiftTimer = 0
            end
        else
            state.DirectionRequestTimer = 0
        end
    end

    if state.Gear < 0 then
        return brake, throttle
    end
    return throttle, brake
end

--[[
    Passages automatiques (automatique et double embrayage), selon le régime
    côté roues (turbine) : les seuils baissent à faible charge ; l'hystérésis
    est garantie par la validation (pas de pompage).
]]
local function autoShift(
    state: Types.VehicleRuntimeState,
    transmission: Types.TransmissionDefinition,
    driveThrottle: number,
    wheelOmega: number
)
    local gear = state.Gear
    if gear < 1 or state.ShiftTimer > 0 then
        return
    end
    local overall = Transmission.fixedOverallRatio(transmission, gear)
    if wheelOmega * overall <= 0 then
        return
    end
    local rpm = Engine.rpm(math.abs(wheelOmega * overall))
    local factor = 0.55 + 0.45 * driveThrottle
    if rpm > transmission.ShiftUpRpm * factor and gear < #transmission.ForwardRatios then
        state.Gear = gear + 1
        state.ShiftTimer = transmission.ShiftDurationS
    elseif rpm < transmission.ShiftDownRpm * factor and gear > 1 then
        state.Gear = gear - 1
        state.ShiftTimer = transmission.ShiftDurationS * 0.6
    end
end

-- Variateur : le rapport évolue vers celui qui place le moteur au régime visé.
local function updateCvt(
    state: Types.VehicleRuntimeState,
    powertrain: Types.PowertrainDefinition,
    driveThrottle: number,
    wheelOmega: number,
    dt: number
)
    local transmission = powertrain.Transmission
    local cvt = transmission.Cvt :: Types.CvtDefinition
    local short, long = transmission.ForwardRatios[1], transmission.ForwardRatios[2]
    local targetRpm = cvt.CruiseRpm + driveThrottle * (cvt.PowerRpm - cvt.CruiseRpm)
    local w = math.abs(wheelOmega) * transmission.FinalDrive
    local desired = if w > 1e-3 then Engine.omega(targetRpm) / w else short
    desired = math.clamp(desired, long, short)
    local step = cvt.RatioRatePerS * dt
    state.CvtRatio = math.clamp(state.CvtRatio + math.clamp(desired - state.CvtRatio, -step, step), long, short)
end

--[[
    Met à jour la sélection et les minuteries de la boîte.
    `wheelOmega` = vitesse angulaire moyenne des roues motrices (rad/s).
    Retourne (accélérateur effectif, pédale de frein effective).
]]
function Transmission.update(
    state: Types.VehicleRuntimeState,
    powertrain: Types.PowertrainDefinition,
    input: Types.DriverInput,
    forwardSpeed: number,
    wheelOmega: number,
    dt: number
): (number, number)
    local transmission = powertrain.Transmission
    local kind = transmission.Kind
    if state.ShiftTimer > 0 then
        state.ShiftTimer = math.max(0, state.ShiftTimer - dt)
    end
    if state.ManualHoldTimer > 0 then
        state.ManualHoldTimer = math.max(0, state.ManualHoldTimer - dt)
    end
    state.ClutchPedal = if kind == "Manual" then math.clamp(input.Clutch, 0, 1) else 0

    if not Transmission.hasSelector(kind) then
        local throttle, brake = updateHoldBrakeSelection(state, input, forwardSpeed, dt)
        if kind == "Automatic" then
            autoShift(state, transmission, throttle, wheelOmega)
        elseif kind == "CVT" and state.Gear > 0 then
            updateCvt(state, powertrain, throttle, wheelOmega, dt)
        end
        return throttle, brake
    end

    if kind == "DualClutch" then
        -- Neutre au démarrage : « accélérer » engage le 1er rapport (position D).
        if state.Gear == 0 and input.Throttle > 0.05 and forwardSpeed > -Transmission.StopSpeed then
            state.Gear = 1
        end
        if state.ManualHoldTimer <= 0 then
            autoShift(state, transmission, input.Throttle, wheelOmega)
        end
    end
    return input.Throttle, input.Brake
end

--[[
    Demande de passage du conducteur (`direction` = +1 montée, -1 descente).
    Ordre séquentiel : R ← N ← 1 ← 2 … (la marche arrière s'atteint en
    descendant depuis le neutre, véhicule arrêté).
]]
function Transmission.requestShift(
    state: Types.VehicleRuntimeState,
    powertrain: Types.PowertrainDefinition,
    direction: number,
    forwardSpeed: number,
    wheelOmega: number
): ShiftResult
    local transmission = powertrain.Transmission
    local kind = transmission.Kind
    if not Transmission.hasSelector(kind) then
        return "NotAvailable"
    end
    if kind == "Manual" and state.ClutchPedal < Transmission.ClutchShiftThreshold then
        return "ClutchRequired"
    end
    local target = state.Gear + (if direction > 0 then 1 else -1)
    if target > #transmission.ForwardRatios or target < -1 then
        return "Limit"
    end
    local stopped = math.abs(forwardSpeed) < Transmission.StopSpeed
    -- Engager la marche arrière en roulant (ou un rapport avant en reculant) :
    -- refusé pour toutes les boîtes (pignons non synchronisés).
    if target == -1 and not stopped then
        return "StopRequired"
    end
    if target == 1 and state.Gear == 0 and forwardSpeed < -Transmission.StopSpeed then
        return "StopRequired"
    end
    -- Boîtes pilotées : la gestion refuse une rétrogradation au-delà du rupteur.
    -- (Manuelle : rien ne l'empêche ; l'embrayage glissera et le moteur surrégimera.)
    if kind ~= "Manual" and target >= 1 and target < state.Gear then
        local rpm = Engine.rpm(math.abs(wheelOmega * Transmission.fixedOverallRatio(transmission, target)))
        if rpm > limitRpm(powertrain) then
            return "OverRev"
        end
    end
    state.Gear = target
    if kind ~= "Manual" and target ~= 0 then
        state.ShiftTimer = transmission.ShiftDurationS
    end
    if kind == "DualClutch" then
        state.ManualHoldTimer = Transmission.ManualHoldS
    end
    return "Ok"
end

--[[
    Mode de couplage moteur ↔ roues et capacité de l'embrayage (N·m).
    - Manuelle : capacité selon la pédale (point de patinage vers 30-50 %) ;
    - double embrayage, séquentielle, CVT : embrayage automatisé « centrifuge »
      dont la capacité croît avec le régime moteur, ce qui régule le régime de
      démarrage selon l'accélérateur, sans caler, et rouvre près de l'arrêt ;
    - automatique : convertisseur (ou pontage si `state.Coupled`) ;
    - rapport unique : couplage permanent.
]]
function Transmission.coupling(
    state: Types.VehicleRuntimeState,
    powertrain: Types.PowertrainDefinition,
    engineOmega: number,
    driveThrottle: number
): (CouplingMode, number)
    local transmission = powertrain.Transmission
    local kind = transmission.Kind
    if state.Gear == 0 then
        return "Open", 0
    end
    if kind == "SingleSpeed" then
        return "Rigid", math.huge
    end
    if kind == "Automatic" then
        return "Converter", 0
    end
    local clutch = transmission.Clutch :: Types.ClutchDefinition
    if kind == "Manual" then
        local engagement = 1 - state.ClutchPedal
        local bite = math.clamp((engagement - 0.15) / 0.7, 0, 1)
        return "Clutch", clutch.MaxTorqueNm * bite * bite
    end
    local idle = idleRpm(powertrain)
    local launchTarget = idle + math.max(driveThrottle, 0.08) * (transmission.LaunchRpm - idle)
    local fraction = (Engine.rpm(engineOmega) - idle * 1.05) / math.max(launchTarget - idle * 1.05, 50)
    return "Clutch", clutch.MaxTorqueNm * math.clamp(fraction, 0, 1)
end

--[[
    Couples du convertisseur : (couple absorbé à la pompe, couple à la turbine).
    Modèle simplifié : couple ∝ ω_pompe × glissement, calé pour qu'à pleine
    charge, turbine bloquée, le moteur se stabilise au régime de calage ;
    multiplication de couple décroissante jusqu'au point de couplage (0,85).
    En retenue (turbine plus rapide), couplage symétrique sans multiplication.
]]
function Transmission.converterTorques(
    converter: Types.ConverterDefinition,
    stallTorqueNm: number,
    pumpOmega: number,
    turbineOmega: number
): (number, number)
    local stallOmega = Engine.omega(converter.StallRpm)
    local k = stallTorqueNm / (stallOmega * stallOmega)
    local fastest = math.max(math.abs(pumpOmega), math.abs(turbineOmega))
    local pump = k * fastest * (pumpOmega - turbineOmega)
    if pump <= 0 or pumpOmega <= 1e-3 then
        return pump, pump
    end
    local speedRatio = math.clamp(turbineOmega / pumpOmega, 0, 1)
    local torqueRatio = 1 + (converter.StallTorqueRatio - 1) * math.max(0, 1 - speedRatio / 0.85)
    return pump, pump * torqueRatio
end

return table.freeze(Transmission)
