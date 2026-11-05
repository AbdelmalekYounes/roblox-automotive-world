--!strict
--[[
    Préparation mécanique PURE (§4.3, lot 0.4) : réglages autorisés par modèle
    et application à une COPIE de la définition du lot 0.2.

    - Chaque réglage a une plage propre au modèle et aux pièces installées ;
      une valeur hors plage ou un réglage inconnu est REFUSÉ (jamais ramené
      en silence dans la plage).
    - Un réglage n'existe que si l'équipement du modèle le permet (ex. le
      blocage d'un différentiel exige un autobloquant, la loi de passage
      exige une boîte qui change seule de rapport et un moteur thermique).
    - La définition résultante est revalidée par VehicleDefinitions.validate
      avant toute utilisation (côté serveur).

    Unités : facteurs sans dimension, mètres pour la hauteur de caisse,
    fraction pour la répartition de freinage, tr/min pour la loi de passage.
]]

local PartCatalog = require(script.Parent.PartCatalog)
local VehicleDefinitions = require(script.Parent.Parent.Vehicles.VehicleDefinitions)

local TuningRules = {}

export type Range = { Min: number, Max: number, Default: number, Label: string, Unit: string }
export type Tuning = { [string]: number }
export type InstalledParts = { [string]: string } -- emplacement → identifiant de pièce du catalogue

local function deepCopy(value: any): any
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, child in value do
        copy[key] = deepCopy(child)
    end
    return copy
end
TuningRules.deepCopy = deepCopy

local function installed(parts: InstalledParts, slot: string): PartCatalog.Part?
    local id = parts[slot]
    return if id then PartCatalog.get(id) else nil
end

local function totalBrake(definition: any): number
    return definition.Brakes.MaxTorqueFrontNm + definition.Brakes.MaxTorqueRearNm
end

local function drivenLimitedSlip(definition: any, parts: InstalledParts): boolean
    local drivetrain = definition.Powertrain.Drivetrain
    local rearLsd = drivetrain.RearDifferential.Kind == "LimitedSlip" or parts.RearDifferential ~= nil
    local frontLsd = drivetrain.FrontDifferential.Kind == "LimitedSlip" or parts.FrontDifferential ~= nil
    if drivetrain.Layout == "RWD" then
        return rearLsd
    elseif drivetrain.Layout == "FWD" then
        return frontLsd
    end
    return rearLsd or frontLsd
end

--[[
    Plages de réglage d'un modèle avec ses pièces installées. Les valeurs par
    défaut reproduisent exactement la définition d'origine (facteur 1, décalage
    0, répartition et loi de passage d'origine).
]]
function TuningRules.ranges(definition: any, parts: InstalledParts): { [string]: Range }
    local coilover = installed(parts, "Suspension")
    local wide = coilover ~= nil and coilover.WidensTuning
    local spring = if wide then { 0.7, 1.4 } else { 0.85, 1.2 }
    local ranges: { [string]: Range } = {
        SpringFront = { Min = spring[1], Max = spring[2], Default = 1, Label = "Ressorts avant", Unit = "×" },
        SpringRear = { Min = spring[1], Max = spring[2], Default = 1, Label = "Ressorts arrière", Unit = "×" },
        DampingFront = { Min = 0.85, Max = 1.2, Default = 1, Label = "Amortissement avant", Unit = "×" },
        DampingRear = { Min = 0.85, Max = 1.2, Default = 1, Label = "Amortissement arrière", Unit = "×" },
        AntiRollFront = { Min = 0.7, Max = 1.3, Default = 1, Label = "Antiroulis avant", Unit = "×" },
        AntiRollRear = { Min = 0.7, Max = 1.3, Default = 1, Label = "Antiroulis arrière", Unit = "×" },
        RideHeight = {
            Min = if wide then -0.05 else -0.02,
            Max = if wide then 0.03 else 0.02,
            Default = 0,
            Label = "Hauteur de caisse",
            Unit = "m",
        },
        BrakeBias = {
            Min = 0.55,
            Max = 0.75,
            Default = definition.Brakes.MaxTorqueFrontNm / totalBrake(definition),
            Label = "Répartition de freinage (avant)",
            Unit = "",
        },
        SteeringLock = { Min = 0.9, Max = 1.1, Default = 1, Label = "Angle de braquage", Unit = "×" },
        FinalDrive = { Min = 0.92, Max = 1.08, Default = 1, Label = "Rapport de pont", Unit = "×" },
    }
    -- La répartition d'origine doit rester réglable même hors de la plage usuelle.
    local bias = ranges.BrakeBias
    bias.Min = math.min(bias.Min, bias.Default)
    bias.Max = math.max(bias.Max, bias.Default)

    if drivenLimitedSlip(definition, parts) then
        -- Valeurs par défaut : celles de l'autobloquant effectivement monté.
        local layout = definition.Powertrain.Drivetrain.Layout
        local slot = if layout == "FWD" then "FrontDifferential" else "RearDifferential"
        local part = installed(parts, slot)
        local stock = definition.Powertrain.Drivetrain[slot]
        local power = if part then part.Effects.PowerLockRatio or 0 else stock.PowerLockRatio
        local coast = if part then part.Effects.CoastLockRatio or 0 else stock.CoastLockRatio
        ranges.DiffPowerLock = { Min = 0, Max = 0.6, Default = power, Label = "Blocage en charge", Unit = "" }
        ranges.DiffCoastLock = { Min = 0, Max = 0.5, Default = coast, Label = "Blocage au lever", Unit = "" }
    end
    local powertrain = definition.Powertrain
    local kind = powertrain.Transmission.Kind
    local engine = powertrain.Engine
    if engine and (kind == "Automatic" or kind == "DualClutch") then
        ranges.ShiftUpRpm = {
            Min = engine.RedlineRpm - 1200,
            Max = engine.LimiterRpm - 100,
            Default = powertrain.Transmission.ShiftUpRpm,
            Label = "Loi de passage (montée)",
            Unit = "tr/min",
        }
    end
    return ranges
end

-- Vérifie qu'un jeu de réglages est réalisable ; renvoie les erreurs (clés).
function TuningRules.validate(definition: any, tuning: Tuning, parts: InstalledParts): (boolean, { string })
    local errors: { string } = {}
    local ranges = TuningRules.ranges(definition, parts)
    for key, value in tuning do
        local range = ranges[key]
        if range == nil then
            table.insert(errors, "TuningUnknown:" .. tostring(key))
        elseif type(value) ~= "number" or value ~= value or value < range.Min - 1e-9 or value > range.Max + 1e-9 then
            table.insert(errors, "TuningOutOfRange:" .. key)
        end
    end
    if #errors == 0 then
        -- Chaque valeur est dans sa plage, mais une COMBINAISON peut rendre le
        -- véhicule irréalisable (ex. ressorts souples et caisse abaissée :
        -- talonnage) : la définition dérivée est revalidée.
        local derived = TuningRules.apply(definition, tuning, parts)
        local valid = VehicleDefinitions.validate(derived)
        if not valid then
            table.insert(errors, "TuningUnrealizable")
        end
    end
    return #errors == 0, errors
end

-- Les pièces installées conviennent-elles au modèle ?
function TuningRules.validateParts(definition: any, parts: InstalledParts): (boolean, { string })
    local errors: { string } = {}
    for slot, id in parts do
        local item = PartCatalog.get(id)
        if item == nil then
            table.insert(errors, "PartUnknown:" .. tostring(id))
        elseif item.Slot ~= slot then
            table.insert(errors, "PartWrongSlot:" .. id)
        elseif not PartCatalog.compatible(item, definition) then
            table.insert(errors, "PartIncompatible:" .. id)
        end
    end
    return #errors == 0, errors
end

local function scaleAxle(axle: any, springFactor: number, dampingFactor: number, antiRollFactor: number, ride: number)
    axle.SpringRateNpm *= springFactor
    axle.BumpDampingNsPm *= dampingFactor
    axle.ReboundDampingNsPm *= dampingFactor
    axle.AntiRollNpm *= antiRollFactor
    axle.RestLengthM += ride
    -- Abaisser la caisse réduit aussi le débattement disponible (le
    -- débattement ne peut pas dépasser la longueur libre).
    axle.TravelM = math.min(axle.TravelM, axle.RestLengthM)
end

--[[
    Définition dérivée : pièces installées puis réglages, sur une copie. La
    définition d'origine (gelée) n'est jamais modifiée. L'identifiant reste
    celui du modèle : la dérivée n'est pas un nouveau modèle.
]]
function TuningRules.apply(base: any, tuning: Tuning, parts: InstalledParts): any
    local definition = deepCopy(base)
    local function value(key: string, default: number): number
        local v = tuning[key]
        return if type(v) == "number" then v else default
    end

    -- 1. Pièces.
    local tires = installed(parts, "Tires")
    if tires then
        local peak = tires.Effects.PeakFriction or 1
        definition.Tires.PeakFrictionLongitudinal *= peak
        definition.Tires.PeakFrictionLateral *= peak
        definition.Tires.WetGripRatio = math.min(definition.Tires.WetGripRatio * (tires.Effects.WetGrip or 1), 1)
    end
    local brakes = installed(parts, "Brakes")
    if brakes then
        local factor = brakes.Effects.BrakeTorque or 1
        definition.Brakes.MaxTorqueFrontNm *= factor
        definition.Brakes.MaxTorqueRearNm *= factor
    end
    for _, slot in { "RearDifferential", "FrontDifferential" } do
        local diff = installed(parts, slot)
        if diff then
            definition.Powertrain.Drivetrain[slot] = {
                Kind = "LimitedSlip",
                PreloadNm = diff.Effects.PreloadNm or 0,
                PowerLockRatio = diff.Effects.PowerLockRatio or 0,
                CoastLockRatio = diff.Effects.CoastLockRatio or 0,
            }
        end
    end
    local map = installed(parts, "EngineMap")
    if map and definition.Powertrain.Engine then
        for _, point in definition.Powertrain.Engine.TorqueCurve do
            point.TorqueNm *= map.Effects.Torque or 1
        end
    end

    -- 2. Réglages.
    local ride = value("RideHeight", 0)
    scaleAxle(
        definition.Suspension.Front,
        value("SpringFront", 1),
        value("DampingFront", 1),
        value("AntiRollFront", 1),
        ride
    )
    scaleAxle(
        definition.Suspension.Rear,
        value("SpringRear", 1),
        value("DampingRear", 1),
        value("AntiRollRear", 1),
        ride
    )
    local bias = tuning.BrakeBias
    if type(bias) == "number" then
        local total = totalBrake(definition)
        definition.Brakes.MaxTorqueFrontNm = total * bias
        definition.Brakes.MaxTorqueRearNm = total * (1 - bias)
    end
    definition.Steering.MaxAngleDeg *= value("SteeringLock", 1)
    definition.Powertrain.Transmission.FinalDrive *= value("FinalDrive", 1)
    local power, coast = tuning.DiffPowerLock, tuning.DiffCoastLock
    if type(power) == "number" or type(coast) == "number" then
        local drivetrain = definition.Powertrain.Drivetrain
        for _, slot in { "RearDifferential", "FrontDifferential" } do
            local diff = drivetrain[slot]
            if diff.Kind == "LimitedSlip" then
                diff.PowerLockRatio = if type(power) == "number" then power else diff.PowerLockRatio
                diff.CoastLockRatio = if type(coast) == "number" then coast else diff.CoastLockRatio
            end
        end
    end
    local shift = tuning.ShiftUpRpm
    if type(shift) == "number" then
        definition.Powertrain.Transmission.ShiftUpRpm = shift
    end
    return definition
end

return table.freeze(TuningRules)
