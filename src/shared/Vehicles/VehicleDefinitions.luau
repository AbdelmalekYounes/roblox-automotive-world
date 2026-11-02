--!strict
-- Registre des définitions de véhicules et validation de leur cohérence.
--
-- Une *définition* (modèle) décrit une voiture ; elle n'est liée à aucun
-- joueur et ne représente aucune possession (cf. glossaire du cahier des charges).
-- La validation refuse explicitement toute fonctionnalité non encore
-- implémentée, afin qu'aucune définition ne prétende l'avoir.

local Types = require(script.Parent.VehicleTypes)
local PrototypeP01 = require(script.Parent.Definitions.PrototypeP01)

local VehicleDefinitions = {}

local function positive(errors: { string }, value: number, label: string)
    if not (value > 0) or value == math.huge then
        table.insert(errors, label .. " doit être strictement positif et fini")
    end
end

-- Vérifie une définition. Retourne (valide, liste d'erreurs en français).
function VehicleDefinitions.validate(definition: Types.VehicleDefinition): (boolean, { string })
    local errors: { string } = {}
    local chassis = definition.Chassis
    local powertrain = definition.Powertrain
    local engine = powertrain.Engine
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
        local fraction = if isFront then chassis.FrontWeightFraction else 1 - chassis.FrontWeightFraction
        local staticCompression = chassis.MassKg * 9.81 * fraction / 2 / axle.SpringRateNpm
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
    if tire.SlidingFrictionRatio <= 0 or tire.SlidingFrictionRatio > 1 then
        table.insert(errors, "Tires.SlidingFrictionRatio hors de ]0 ; 1]")
    end
    positive(errors, definition.Brakes.MaxTorqueFrontNm, "Brakes.MaxTorqueFrontNm")
    positive(errors, definition.Brakes.MaxTorqueRearNm, "Brakes.MaxTorqueRearNm")

    -- Direction
    local steering = definition.Steering
    positive(errors, steering.MaxAngleDeg, "Steering.MaxAngleDeg")
    positive(errors, steering.RackSpeedDegPerS, "Steering.RackSpeedDegPerS")
    positive(errors, steering.HighSpeedReferenceKmh, "Steering.HighSpeedReferenceKmh")
    if steering.HighSpeedAngleDeg <= 0 or steering.HighSpeedAngleDeg > steering.MaxAngleDeg then
        table.insert(errors, "Steering.HighSpeedAngleDeg doit être dans ]0 ; MaxAngleDeg]")
    end

    -- Motorisation : seules les configurations réellement implémentées passent.
    if powertrain.Kind ~= "Combustion" then
        table.insert(errors, "Motorisation « " .. powertrain.Kind .. " » non implémentée dans le lot 0.1")
    end
    if transmission.Kind ~= "Automatic" then
        table.insert(errors, "Transmission « " .. transmission.Kind .. " » non implémentée dans le lot 0.1")
    end
    if
        not (
            engine.IdleRpm > 0
            and engine.IdleRpm < engine.ClutchLaunchRpm
            and engine.ClutchLaunchRpm < engine.RedlineRpm
        )
    then
        table.insert(errors, "Engine : ordre ralenti < régime de démarrage < zone rouge non respecté")
    end
    if engine.LimiterRpm < engine.RedlineRpm then
        table.insert(errors, "Engine.LimiterRpm doit être supérieur ou égal à RedlineRpm")
    end
    positive(errors, engine.InertiaKgM2, "Engine.InertiaKgM2")
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

    local ratios = transmission.ForwardRatios
    if #ratios < 1 then
        table.insert(errors, "Transmission.ForwardRatios vide")
    else
        local smallestStep = math.huge
        for i, ratio in ratios do
            positive(errors, ratio, "Transmission.ForwardRatios[" .. i .. "]")
            if i > 1 then
                if ratio >= ratios[i - 1] then
                    table.insert(errors, "Transmission.ForwardRatios doit être strictement décroissant")
                    break
                end
                smallestStep = math.min(smallestStep, ratio / ratios[i - 1])
            end
        end
        -- Hystérésis : après une montée de rapport, le régime ne doit pas
        -- retomber sous le seuil de rétrogradation (pompage de la boîte).
        if smallestStep < math.huge and transmission.ShiftDownRpm >= transmission.ShiftUpRpm * smallestStep then
            table.insert(errors, "Transmission : seuils de passage incompatibles avec l'étagement (pompage)")
        end
    end
    positive(errors, transmission.ReverseRatio, "Transmission.ReverseRatio")
    positive(errors, transmission.FinalDrive, "Transmission.FinalDrive")
    if transmission.Efficiency <= 0 or transmission.Efficiency > 1 then
        table.insert(errors, "Transmission.Efficiency hors de ]0 ; 1]")
    end
    if transmission.ShiftUpRpm > engine.LimiterRpm then
        table.insert(errors, "Transmission.ShiftUpRpm au-delà du rupteur")
    end

    -- Transmission aux roues : cohérence entre architecture déclarée et répartition.
    local share = drivetrain.FrontTorqueShare
    if drivetrain.Layout == "RWD" and share ~= 0 then
        table.insert(errors, "Drivetrain RWD : FrontTorqueShare doit valoir 0")
    elseif drivetrain.Layout == "FWD" and share ~= 1 then
        table.insert(errors, "Drivetrain FWD : FrontTorqueShare doit valoir 1")
    elseif drivetrain.Layout == "AWD" and (share <= 0 or share >= 1) then
        table.insert(errors, "Drivetrain AWD : FrontTorqueShare doit être dans ]0 ; 1[")
    end

    -- Aides : aucune n'est implémentée ; une définition ne peut donc pas en déclarer.
    if definition.Aids.Abs or definition.Aids.TractionControl or definition.Aids.StabilityControl then
        table.insert(errors, "Aides à la conduite (ABS/antipatinage/ESP) non implémentées dans le lot 0.1")
    end

    positive(errors, definition.Limits.MaxPlausibleSpeedKmh, "Limits.MaxPlausibleSpeedKmh")
    positive(errors, definition.Limits.ExitMaxSpeedKmh, "Limits.ExitMaxSpeedKmh")

    return #errors == 0, errors
end

-- Vitesse maximale limitée par la boîte (rupteur sur le dernier rapport), km/h.
-- Il s'agit d'une borne cinématique, pas d'une performance mesurée.
function VehicleDefinitions.gearLimitedTopSpeedKmh(definition: Types.VehicleDefinition): number
    local transmission = definition.Powertrain.Transmission
    local lastRatio = transmission.ForwardRatios[#transmission.ForwardRatios]
    local wheelRpm = definition.Powertrain.Engine.LimiterRpm / (lastRatio * transmission.FinalDrive)
    return wheelRpm * 2 * math.pi / 60 * definition.Tires.RadiusM * 3.6
end

local registry: { [string]: Types.VehicleDefinition } = {}

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
end

register(PrototypeP01)

VehicleDefinitions.DefaultTestVehicleId = PrototypeP01.Id

function VehicleDefinitions.get(id: string): Types.VehicleDefinition?
    return registry[id]
end

return table.freeze(VehicleDefinitions)
