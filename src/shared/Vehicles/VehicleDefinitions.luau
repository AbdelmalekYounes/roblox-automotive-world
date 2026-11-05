--!strict
-- Registre des définitions de véhicules et validation de leur cohérence.
--
-- Une *définition* (modèle) décrit une voiture ; elle n'est liée à aucun
-- joueur et ne représente aucune possession (cf. glossaire du cahier des charges).
-- La validation vérifie chaque famille (énergie, boîte, transmission) selon
-- ses propres règles : une définition incohérente (ex. un moteur électrique
-- avec une boîte manuelle, un embrayage plus faible que le moteur) est refusée
-- au chargement, jamais simulée en silence.

local Types = require(script.Parent.VehicleTypes)
local PrototypeP01 = require(script.Parent.Definitions.PrototypeP01)
local PrototypeP02 = require(script.Parent.Definitions.PrototypeP02)
local PrototypeP03 = require(script.Parent.Definitions.PrototypeP03)
local ValidationVariants = require(script.Parent.Definitions.ValidationVariants)

local VehicleDefinitions = {}

local function positive(errors: { string }, value: number, label: string)
    if not (value > 0) or value == math.huge then
        table.insert(errors, label .. " doit être strictement positif et fini")
    end
end

local function fraction(errors: { string }, value: number, label: string)
    if not (value > 0 and value <= 1) then
        table.insert(errors, label .. " hors de ]0 ; 1]")
    end
end

local function validateEngine(errors: { string }, engine: Types.CombustionEngineDefinition)
    if not (engine.StallRpm > 0 and engine.StallRpm < engine.IdleRpm and engine.IdleRpm < engine.RedlineRpm) then
        table.insert(errors, "Engine : ordre calage < ralenti < zone rouge non respecté")
    end
    if engine.LimiterRpm < engine.RedlineRpm then
        table.insert(errors, "Engine.LimiterRpm doit être supérieur ou égal à RedlineRpm")
    end
    positive(errors, engine.InertiaKgM2, "Engine.InertiaKgM2")
    positive(errors, engine.BsfcGPerKWh, "Engine.BsfcGPerKWh")
    positive(errors, engine.IdleFuelLph, "Engine.IdleFuelLph")
    if not (engine.PartLoadPenalty >= 0 and engine.PartLoadPenalty <= 3) then
        table.insert(errors, "Engine.PartLoadPenalty hors de [0 ; 3]")
    end
    if not (engine.EngineBrakeTorqueNm >= 0 and engine.IdleControlTorqueNm >= 0) then
        table.insert(errors, "Engine : couples de frottement et de ralenti doivent être positifs ou nuls")
    end
    if #engine.TorqueCurve < 2 then
        table.insert(errors, "Engine.TorqueCurve : au moins deux points requis")
    else
        for i = 2, #engine.TorqueCurve do
            if engine.TorqueCurve[i].Rpm <= engine.TorqueCurve[i - 1].Rpm then
                table.insert(errors, "Engine.TorqueCurve : régimes non strictement croissants")
                break
            end
        end
    end
end

local function validateMotor(errors: { string }, motor: Types.ElectricMotorDefinition)
    positive(errors, motor.MaxTorqueNm, "Motor.MaxTorqueNm")
    positive(errors, motor.MaxPowerKw, "Motor.MaxPowerKw")
    positive(errors, motor.MaxRpm, "Motor.MaxRpm")
    positive(errors, motor.InertiaKgM2, "Motor.InertiaKgM2")
    positive(errors, motor.TopSpeedKmh, "Motor.TopSpeedKmh")
    fraction(errors, motor.DriveEfficiency, "Motor.DriveEfficiency")
    fraction(errors, motor.RegenEfficiency, "Motor.RegenEfficiency")
    if not (motor.RegenMaxPowerKw >= 0 and motor.RegenMaxTorqueNm >= 0 and motor.AuxPowerKw >= 0) then
        table.insert(errors, "Motor : récupération et auxiliaires doivent être positifs ou nuls")
    end
    if #motor.RegenLevels < 1 then
        table.insert(errors, "Motor.RegenLevels : au moins un niveau requis")
    end
    for _, level in motor.RegenLevels do
        if not (level >= 0 and level <= 1) then
            table.insert(errors, "Motor.RegenLevels : niveau hors de [0 ; 1]")
            break
        end
    end
end

local function peakTorque(engine: Types.CombustionEngineDefinition): number
    local best = 0
    for _, point in engine.TorqueCurve do
        best = math.max(best, point.TorqueNm)
    end
    return best
end

local function validateFixedRatios(errors: { string }, transmission: Types.TransmissionDefinition, hysteresis: boolean)
    local ratios = transmission.ForwardRatios
    if #ratios < 1 then
        table.insert(errors, "Transmission.ForwardRatios vide")
        return
    end
    local smallestStep = math.huge
    for i, ratio in ratios do
        positive(errors, ratio, "Transmission.ForwardRatios[" .. i .. "]")
        if i > 1 then
            if ratio >= ratios[i - 1] then
                table.insert(errors, "Transmission.ForwardRatios doit être strictement décroissant")
                return
            end
            smallestStep = math.min(smallestStep, ratio / ratios[i - 1])
        end
    end
    -- Hystérésis : après une montée de rapport, le régime ne doit pas retomber
    -- sous le seuil de rétrogradation (pompage de la boîte).
    if
        hysteresis
        and smallestStep < math.huge
        and transmission.ShiftDownRpm >= transmission.ShiftUpRpm * smallestStep
    then
        table.insert(errors, "Transmission : seuils de passage incompatibles avec l'étagement (pompage)")
    end
end

local function validateTransmission(
    errors: { string },
    powertrain: Types.PowertrainDefinition,
    transmission: Types.TransmissionDefinition
)
    local kind = transmission.Kind
    local engine = powertrain.Engine
    positive(errors, transmission.ReverseRatio, "Transmission.ReverseRatio")
    positive(errors, transmission.FinalDrive, "Transmission.FinalDrive")
    fraction(errors, transmission.Efficiency, "Transmission.Efficiency")

    if kind == "SingleSpeed" then
        if powertrain.Motor == nil then
            table.insert(errors, "Transmission SingleSpeed réservée au moteur électrique")
        end
        if #transmission.ForwardRatios ~= 1 then
            table.insert(errors, "Transmission SingleSpeed : exactement un rapport")
        end
        for _, ratio in transmission.ForwardRatios do
            positive(errors, ratio, "Transmission.ForwardRatios")
        end
        return
    end
    if engine == nil then
        table.insert(errors, "Transmission « " .. kind .. " » réservée au moteur thermique dans ce lot")
        return
    end

    if kind == "CVT" then
        local ratios = transmission.ForwardRatios
        if #ratios ~= 2 or not (ratios[1] > ratios[2] and ratios[2] > 0) then
            table.insert(errors, "Transmission CVT : { rapport court, rapport long } avec court > long > 0")
        end
        local cvt = transmission.Cvt
        if cvt == nil then
            table.insert(errors, "Transmission CVT : paramètres Cvt manquants")
        else
            if
                not (
                    cvt.CruiseRpm >= engine.IdleRpm
                    and cvt.PowerRpm > cvt.CruiseRpm
                    and cvt.PowerRpm <= engine.RedlineRpm
                )
            then
                table.insert(errors, "Transmission CVT : régimes visés hors de la plage du moteur")
            end
            positive(errors, cvt.RatioRatePerS, "Cvt.RatioRatePerS")
        end
    elseif kind == "Automatic" or kind == "Manual" or kind == "DualClutch" or kind == "Sequential" then
        validateFixedRatios(errors, transmission, kind == "Automatic" or kind == "DualClutch")
        if (kind == "Automatic" or kind == "DualClutch") and transmission.ShiftUpRpm > engine.LimiterRpm then
            table.insert(errors, "Transmission.ShiftUpRpm au-delà du rupteur")
        end
    else
        table.insert(errors, "Transmission inconnue : " .. tostring(kind))
        return
    end

    if kind == "Automatic" then
        local converter = transmission.Converter
        if converter == nil then
            table.insert(errors, "Transmission Automatic : convertisseur manquant")
        else
            if not (converter.StallRpm > engine.IdleRpm and converter.StallRpm < engine.RedlineRpm) then
                table.insert(errors, "Converter.StallRpm hors de ]ralenti ; zone rouge[")
            end
            if not (converter.StallTorqueRatio >= 1 and converter.StallTorqueRatio <= 3) then
                table.insert(errors, "Converter.StallTorqueRatio hors de [1 ; 3]")
            end
            if not (converter.LockupGear >= 1 and converter.LockupGear <= #transmission.ForwardRatios) then
                table.insert(errors, "Converter.LockupGear hors des rapports")
            end
        end
        return
    end

    -- Boîtes à embrayage : il doit transmettre tout le couple du moteur.
    local clutch = transmission.Clutch
    if clutch == nil then
        table.insert(errors, "Transmission « " .. kind .. " » : embrayage manquant")
    elseif clutch.MaxTorqueNm < peakTorque(engine) * 1.1 then
        table.insert(errors, "Clutch.MaxTorqueNm inférieur à 1,1 × le couple maximal du moteur")
    end
    if
        kind ~= "Manual"
        and not (transmission.LaunchRpm > engine.IdleRpm and transmission.LaunchRpm < engine.RedlineRpm)
    then
        table.insert(errors, "Transmission.LaunchRpm hors de ]ralenti ; zone rouge[")
    end
end

local function validateDifferential(
    errors: { string },
    differential: Types.DifferentialDefinition,
    label: string,
    driven: boolean
)
    if differential.Kind ~= "Open" and differential.Kind ~= "LimitedSlip" then
        table.insert(errors, label .. " : type inconnu")
        return
    end
    if not (differential.PreloadNm >= 0) then
        table.insert(errors, label .. ".PreloadNm négatif")
    end
    for _, ratio in { differential.PowerLockRatio, differential.CoastLockRatio } do
        if not (ratio >= 0 and ratio <= 1) then
            table.insert(errors, label .. " : taux de blocage hors de [0 ; 1]")
            break
        end
    end
    if differential.Kind == "Open" and (differential.PreloadNm ~= 0 or differential.PowerLockRatio ~= 0) then
        table.insert(errors, label .. " : un différentiel ouvert n'a ni précharge ni blocage")
    end
    if not driven and differential.Kind ~= "Open" then
        table.insert(errors, label .. " : essieu non moteur avec autobloquant")
    end
end

-- Vérifie une définition. Retourne (valide, liste d'erreurs en français).
function VehicleDefinitions.validate(definition: Types.VehicleDefinition): (boolean, { string })
    local errors: { string } = {}
    local chassis = definition.Chassis
    local powertrain = definition.Powertrain
    local transmission = powertrain.Transmission
    local drivetrain = powertrain.Drivetrain

    if type(definition.Id) ~= "string" or #definition.Id == 0 then
        table.insert(errors, "Id manquant")
    end

    -- Châssis
    positive(errors, chassis.MassKg, "Chassis.MassKg")
    positive(errors, chassis.WheelbaseM, "Chassis.WheelbaseM")
    positive(errors, chassis.TrackFrontM, "Chassis.TrackFrontM")
    positive(errors, chassis.TrackRearM, "Chassis.TrackRearM")
    positive(errors, chassis.CgHeightM, "Chassis.CgHeightM")
    positive(errors, chassis.DragAreaM2, "Chassis.DragAreaM2")
    if chassis.FrontWeightFraction < 0.3 or chassis.FrontWeightFraction > 0.7 then
        table.insert(errors, "Chassis.FrontWeightFraction hors de [0,3 ; 0,7]")
    end
    if chassis.CgHeightM <= definition.Tires.RadiusM then
        table.insert(errors, "Le centre de gravité doit être au-dessus de l'axe des roues")
    end

    -- Suspension
    local probe = definition.Suspension.ContactProbe
    if probe ~= "Ray" and probe ~= "Sphere" then
        table.insert(errors, "Suspension.ContactProbe inconnue")
    end
    for _, axleName in { "Front", "Rear" } do
        local axle: Types.AxleSuspension = (definition.Suspension :: any)[axleName]
        positive(errors, axle.RestLengthM, "Suspension." .. axleName .. ".RestLengthM")
        positive(errors, axle.TravelM, "Suspension." .. axleName .. ".TravelM")
        positive(errors, axle.SpringRateNpm, "Suspension." .. axleName .. ".SpringRateNpm")
        positive(errors, axle.BumpDampingNsPm, "Suspension." .. axleName .. ".BumpDampingNsPm")
        positive(errors, axle.ReboundDampingNsPm, "Suspension." .. axleName .. ".ReboundDampingNsPm")
        if axle.TravelM > axle.RestLengthM then
            table.insert(errors, "Suspension." .. axleName .. " : débattement supérieur à la longueur libre")
        end
        local isFront = axleName == "Front"
        local share = if isFront then chassis.FrontWeightFraction else 1 - chassis.FrontWeightFraction
        local staticCompression = chassis.MassKg * 9.81 * share / 2 / axle.SpringRateNpm
        if staticCompression >= axle.TravelM * 0.85 then
            table.insert(errors, "Suspension." .. axleName .. " : ressort trop souple (talonnage statique)")
        end
    end

    -- Pneumatiques et freins
    local tire = definition.Tires
    positive(errors, tire.RadiusM, "Tires.RadiusM")
    positive(errors, tire.WheelInertiaKgM2, "Tires.WheelInertiaKgM2")
    positive(errors, tire.PeakFrictionLongitudinal, "Tires.PeakFrictionLongitudinal")
    positive(errors, tire.PeakFrictionLateral, "Tires.PeakFrictionLateral")
    positive(errors, tire.PeakSlipRatio, "Tires.PeakSlipRatio")
    positive(errors, tire.PeakSlipAngleDeg, "Tires.PeakSlipAngleDeg")
    fraction(errors, tire.SlidingFrictionRatio, "Tires.SlidingFrictionRatio")
    fraction(errors, tire.WetGripRatio, "Tires.WetGripRatio")
    fraction(errors, tire.WetSlidingFrictionRatio, "Tires.WetSlidingFrictionRatio")
    if not (tire.RelaxationLengthM >= 0 and tire.RelaxationLengthM <= 2) then
        table.insert(errors, "Tires.RelaxationLengthM hors de [0 ; 2]")
    end
    positive(errors, definition.Brakes.MaxTorqueFrontNm, "Brakes.MaxTorqueFrontNm")
    positive(errors, definition.Brakes.MaxTorqueRearNm, "Brakes.MaxTorqueRearNm")

    -- Direction (A1)
    local steering = definition.Steering
    positive(errors, steering.MaxAngleDeg, "Steering.MaxAngleDeg")
    positive(errors, steering.RackSpeedDegPerS, "Steering.RackSpeedDegPerS")
    positive(errors, steering.HighSpeedReferenceKmh, "Steering.HighSpeedReferenceKmh")
    if steering.HighSpeedAngleDeg <= 0 or steering.HighSpeedAngleDeg > steering.MaxAngleDeg then
        table.insert(errors, "Steering.HighSpeedAngleDeg doit être dans ]0 ; MaxAngleDeg]")
    end

    -- Énergie et source de couple : exactement une, cohérente avec la réserve.
    local energy = powertrain.Energy
    local kind = energy.Kind
    if kind ~= "Petrol" and kind ~= "Diesel" and kind ~= "Electric" then
        table.insert(errors, "Energy.Kind inconnu : " .. tostring(kind))
    end
    positive(errors, energy.Capacity, "Energy.Capacity")
    fraction(errors, energy.InitialFraction, "Energy.InitialFraction")
    if kind == "Electric" then
        if powertrain.Motor == nil or powertrain.Engine ~= nil then
            table.insert(errors, "Énergie électrique : moteur électrique seul requis")
        end
    elseif powertrain.Engine == nil or powertrain.Motor ~= nil then
        table.insert(errors, "Énergie " .. tostring(kind) .. " : moteur thermique seul requis")
    end
    if powertrain.Engine then
        validateEngine(errors, powertrain.Engine)
    end
    if powertrain.Motor then
        validateMotor(errors, powertrain.Motor)
    end
    validateTransmission(errors, powertrain, transmission)

    -- Transmission aux roues : architecture, répartition et différentiels.
    local share = drivetrain.FrontTorqueShare
    local layout = drivetrain.Layout
    if layout == "RWD" and share ~= 0 then
        table.insert(errors, "Drivetrain RWD : FrontTorqueShare doit valoir 0")
    elseif layout == "FWD" and share ~= 1 then
        table.insert(errors, "Drivetrain FWD : FrontTorqueShare doit valoir 1")
    elseif layout == "AWD" and (share <= 0 or share >= 1) then
        table.insert(errors, "Drivetrain AWD : FrontTorqueShare doit être dans ]0 ; 1[")
    elseif layout ~= "RWD" and layout ~= "FWD" and layout ~= "AWD" then
        table.insert(errors, "Drivetrain : architecture inconnue")
    end
    validateDifferential(errors, drivetrain.FrontDifferential, "Drivetrain.FrontDifferential", share > 0)
    validateDifferential(errors, drivetrain.RearDifferential, "Drivetrain.RearDifferential", share < 1)
    if layout == "AWD" then
        if drivetrain.CenterDifferential == nil then
            table.insert(errors, "Drivetrain AWD : différentiel central manquant")
        else
            validateDifferential(errors, drivetrain.CenterDifferential, "Drivetrain.CenterDifferential", true)
        end
    elseif drivetrain.CenterDifferential ~= nil then
        table.insert(errors, "Drivetrain : différentiel central réservé à la transmission intégrale")
    end

    -- Aides : seules les trois aides connues, déclarées comme présentes ou absentes.
    for _, aid in { "Abs", "TractionControl", "StabilityControl" } do
        if type((definition.Aids :: any)[aid]) ~= "boolean" then
            table.insert(errors, "Aids." .. aid .. " doit être un booléen")
        end
    end

    positive(errors, definition.Limits.MaxPlausibleSpeedKmh, "Limits.MaxPlausibleSpeedKmh")
    positive(errors, definition.Limits.ExitMaxSpeedKmh, "Limits.ExitMaxSpeedKmh")

    return #errors == 0, errors
end

-- Arbitrage A3 : mode d'engagement de la marche arrière selon la boîte.
function VehicleDefinitions.reverseEngagement(kind: Types.TransmissionKind): Types.ReverseEngagement
    if kind == "Automatic" or kind == "CVT" or kind == "SingleSpeed" then
        return "HoldBrakeAtStop"
    end
    return "Selector"
end

-- Vitesse maximale limitée par la transmission (rupteur ou régime maximal du
-- moteur électrique sur le rapport le plus long, limitation électronique), km/h.
-- Il s'agit d'une borne cinématique, pas d'une performance mesurée.
function VehicleDefinitions.gearLimitedTopSpeedKmh(definition: Types.VehicleDefinition): number
    local powertrain = definition.Powertrain
    local transmission = powertrain.Transmission
    local lastRatio = transmission.ForwardRatios[#transmission.ForwardRatios]
    local maxRpm = if powertrain.Engine
        then powertrain.Engine.LimiterRpm
        else (powertrain.Motor :: Types.ElectricMotorDefinition).MaxRpm
    local wheelRpm = maxRpm / (lastRatio * transmission.FinalDrive)
    local kinematic = wheelRpm * 2 * math.pi / 60 * definition.Tires.RadiusM * 3.6
    if powertrain.Motor then
        return math.min(kinematic, powertrain.Motor.TopSpeedKmh)
    end
    return kinematic
end

local registry: { [string]: Types.VehicleDefinition } = {}
local ordered: { Types.VehicleDefinition } = {}

-- Gel récursif : une définition ne peut plus être modifiée à l'exécution.
local function deepFreeze(value: any)
    if type(value) ~= "table" or table.isfrozen(value) then
        return
    end
    for _, child in value do
        deepFreeze(child)
    end
    table.freeze(value)
end

local function register(definition: Types.VehicleDefinition)
    local ok, errors = VehicleDefinitions.validate(definition)
    if not ok then
        error(
            "Définition de véhicule invalide « "
                .. tostring(definition.Id)
                .. " » : "
                .. table.concat(errors, " ; ")
        )
    end
    assert(registry[definition.Id] == nil, "Identifiant de définition dupliqué : " .. definition.Id)
    deepFreeze(definition)
    registry[definition.Id] = definition
    table.insert(ordered, definition)
end

register(PrototypeP01)
register(PrototypeP02)
register(PrototypeP03)
for _, definition in ValidationVariants do
    register(definition)
end

VehicleDefinitions.DefaultTestVehicleId = PrototypeP01.Id

-- Parc de la zone d'essai, plot par plot : les plots 1 à 4 gardent le P-01 du
-- lot 0.1 (essais de non-régression), les suivants accueillent le lot 0.2.
VehicleDefinitions.TestFleet = table.freeze({
    "proto_p01",
    "proto_p01",
    "proto_p01",
    "proto_p01",
    "proto_p02",
    "proto_p03",
    "proto_p01_dct",
    "proto_p01_seq",
    "proto_p01_cvt",
})

function VehicleDefinitions.get(id: string): Types.VehicleDefinition?
    return registry[id]
end

-- Toutes les définitions enregistrées, dans l'ordre d'enregistrement.
function VehicleDefinitions.all(): { Types.VehicleDefinition }
    return table.clone(ordered)
end

return table.freeze(VehicleDefinitions)
