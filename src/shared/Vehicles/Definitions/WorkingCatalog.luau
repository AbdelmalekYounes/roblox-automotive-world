--!strict
--[[
    Gamme PROPOSÉE de 18 modèles fictifs (lot 0.8), EN ATTENTE D'APPROBATION
    du propriétaire du projet (statut « PendingApproval » dans
    Economy/VehicleCatalog). Aucun de ces modèles n'est une référence
    commerciale officielle : ils ne sont achetables qu'en environnement de
    développement, et la liste officielle des véhicules de départ reste vide.

    Chaque modèle est une définition physique COMPLÈTE et distincte : masse,
    dimensions, centre de gravité, répartition, traînée, suspension (mise à
    l'échelle de la masse et du caractère), pneus, freins, direction,
    motorisation (thermique essence ou diesel, électrique), boîte (manuelle,
    automatique, double embrayage, séquentielle, variation continue, rapport
    unique), architecture (traction, propulsion, intégrale, autobloquants),
    aides, limites et silhouette de carrosserie (Appearance.BodyStyle,
    construite par VehicleFactory). Les mécaniques dérivent des trois bases
    techniques validées des lots 0.1–0.2 (P-01 essence, P-02 diesel, P-03
    électrique) : seules leurs lois sont reprises, chaque modèle a ses
    propres valeurs. Toutes les valeurs sont des hypothèses de conception,
    pas des mesures ; aucune ne reproduit un modèle réel.

    Identifiants stables : préfixe « wk_ » (les six modèles de travail du
    lot 0.5 gardent le leur : Aster, Brio, Cadence, Dune, Éclat, Fil).
]]

local Types = require(script.Parent.Parent.VehicleTypes)
local PrototypeP01 = require(script.Parent.PrototypeP01)
local PrototypeP02 = require(script.Parent.PrototypeP02)
local PrototypeP03 = require(script.Parent.PrototypeP03)
local ValidationVariants = require(script.Parent.ValidationVariants)

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

export type Spec = {
    Id: string,
    Name: string,
    Base: "Petrol" | "Diesel" | "Electric",
    Gearbox: "Manual" | "Automatic" | "DualClutch" | "Sequential" | "CVT" | "SingleSpeed",
    Layout: "FWD" | "RWD" | "AWD",
    FrontShare: number?, -- intégrale : part avant du couple
    Lsd: boolean?, -- différentiel autobloquant sur l'essieu moteur principal
    PowerKw: number, -- puissance de pointe visée
    MassKg: number,
    LengthM: number,
    WidthM: number,
    HeightM: number,
    WheelbaseM: number,
    CgHeightM: number,
    FrontWeight: number,
    DragAreaM2: number,
    TireRadiusM: number,
    TireWidthM: number,
    Grip: number, -- multiplicateur d'adhérence des pneus d'origine
    Stiffness: number, -- multiplicateur des fréquences de suspension (1 = base)
    TravelM: number?, -- débattement (SUV, tout-terrain)
    SteerDeg: number,
    Capacity: number, -- litres ou kWh
    TopSpeedKmh: number, -- électrique : vitesse maximale du moteur ; thermique : plausibilité
    FinalDrive: number?,
    Aids: { Abs: boolean, TractionControl: boolean, StabilityControl: boolean },
    Style: string,
    Body: { number },
    Accent: { number },
    Trim: { number },
}

local dct = (ValidationVariants[1] :: any).Powertrain.Transmission
local sequential = (ValidationVariants[2] :: any).Powertrain.Transmission
local cvt = (ValidationVariants[3] :: any).Powertrain.Transmission

local function openDiff(): any
    return { Kind = "Open", PreloadNm = 0, PowerLockRatio = 0, CoastLockRatio = 0 }
end

local function lsd(): any
    return { Kind = "LimitedSlip", PreloadNm = 40, PowerLockRatio = 0.3, CoastLockRatio = 0.15 }
end

local function peakTorque(curve: { { Rpm: number, TorqueNm: number } }): number
    local best = 0
    for _, point in curve do
        best = math.max(best, point.TorqueNm)
    end
    return best
end

-- Puissance de pointe (kW) d'une courbe de couple.
local function peakPowerKw(curve: { { Rpm: number, TorqueNm: number } }): number
    local best = 0
    for _, point in curve do
        best = math.max(best, point.TorqueNm * point.Rpm * 2 * math.pi / 60 / 1000)
    end
    return best
end

local function build(spec: Spec): Types.VehicleDefinition
    local base: any = if spec.Base == "Petrol"
        then PrototypeP01
        elseif spec.Base == "Diesel" then PrototypeP02
        else PrototypeP03
    local d = deepCopy(base) :: any
    d.Id = spec.Id
    d.DisplayName = spec.Name
    d.IsTestPrototype = false

    -- Châssis.
    local chassis = d.Chassis
    local massFactor = spec.MassKg / base.Chassis.MassKg
    chassis.MassKg = spec.MassKg
    chassis.LengthM = spec.LengthM
    chassis.WidthM = spec.WidthM
    chassis.HeightM = spec.HeightM
    chassis.WheelbaseM = spec.WheelbaseM
    chassis.TrackFrontM = spec.WidthM - 0.26
    chassis.TrackRearM = spec.WidthM - 0.24
    chassis.CgHeightM = spec.CgHeightM
    chassis.FrontWeightFraction = spec.FrontWeight
    chassis.DragAreaM2 = spec.DragAreaM2

    -- Suspension : mêmes fréquences propres que la base × caractère du modèle,
    -- raideurs mises à l'échelle de la CHARGE de chaque essieu (même enfoncement
    -- statique relatif que la base : les bornes de réglage restent réalisables).
    local baseFront = base.Chassis.FrontWeightFraction
    local loadFactor = {
        Front = spec.MassKg * spec.FrontWeight / (base.Chassis.MassKg * baseFront),
        Rear = spec.MassKg * (1 - spec.FrontWeight) / (base.Chassis.MassKg * (1 - baseFront)),
    }
    local axles: { [string]: any } = { Front = d.Suspension.Front, Rear = d.Suspension.Rear }
    for axleName, axle in axles do
        local load = (loadFactor :: any)[axleName]
        axle.SpringRateNpm *= load * math.max(1, spec.Stiffness * spec.Stiffness)
        axle.BumpDampingNsPm *= load * spec.Stiffness
        axle.ReboundDampingNsPm *= load * spec.Stiffness
        axle.AntiRollNpm *= load * spec.Stiffness
        if spec.TravelM then
            axle.TravelM = spec.TravelM
            axle.RestLengthM = math.max(axle.RestLengthM, spec.TravelM + 0.04)
        end
    end

    -- Pneus, freins, direction.
    local tires = d.Tires
    tires.RadiusM = spec.TireRadiusM
    tires.WidthM = spec.TireWidthM
    tires.WheelInertiaKgM2 *= (spec.TireRadiusM / base.Tires.RadiusM) ^ 2 * (spec.TireWidthM / base.Tires.WidthM)
    tires.PeakFrictionLongitudinal *= spec.Grip
    tires.PeakFrictionLateral *= spec.Grip
    local brakeFactor = massFactor * math.max(1, spec.Grip)
    d.Brakes.MaxTorqueFrontNm *= brakeFactor
    d.Brakes.MaxTorqueRearNm *= brakeFactor
    d.Brakes.HandbrakeTorqueNm *= massFactor
    d.Steering.MaxAngleDeg = spec.SteerDeg
    d.Steering.HighSpeedAngleDeg = math.min(d.Steering.HighSpeedAngleDeg, spec.SteerDeg)

    -- Motorisation.
    local powertrain = d.Powertrain
    powertrain.Energy.Capacity = spec.Capacity
    local transmission: any
    if spec.Base == "Electric" then
        local motor = powertrain.Motor
        local powerFactor = spec.PowerKw / base.Powertrain.Motor.MaxPowerKw
        motor.MaxPowerKw = spec.PowerKw
        motor.MaxTorqueNm = math.floor(base.Powertrain.Motor.MaxTorqueNm * math.clamp(powerFactor, 0.35, 2.2) + 0.5)
        motor.TopSpeedKmh = spec.TopSpeedKmh
        motor.RegenMaxPowerKw = math.floor(math.min(spec.PowerKw * 0.5, 200) + 0.5)
        transmission = deepCopy(base.Powertrain.Transmission)
    else
        local engine = powertrain.Engine
        local factor = spec.PowerKw / peakPowerKw(base.Powertrain.Engine.TorqueCurve)
        for _, point in engine.TorqueCurve do
            point.TorqueNm = math.floor(point.TorqueNm * factor + 0.5)
        end
        engine.InertiaKgM2 *= math.clamp(factor, 0.6, 2)
        engine.EngineBrakeTorqueNm *= math.clamp(factor, 0.6, 2.5)
        engine.IdleControlTorqueNm *= math.clamp(factor, 0.6, 2.5)
        local torque = peakTorque(engine.TorqueCurve)
        if spec.Gearbox == "Manual" then
            transmission = deepCopy(PrototypeP02.Powertrain.Transmission)
        elseif spec.Gearbox == "Automatic" then
            transmission = deepCopy(PrototypeP01.Powertrain.Transmission)
        elseif spec.Gearbox == "DualClutch" then
            transmission = deepCopy(dct)
        elseif spec.Gearbox == "Sequential" then
            transmission = deepCopy(sequential)
        else
            transmission = deepCopy(cvt)
        end
        -- Seuils adaptés à la plage du moteur (essence ou diesel).
        local redline, idle = engine.RedlineRpm, engine.IdleRpm
        if transmission.Kind ~= "CVT" then
            transmission.ShiftUpRpm = redline - 200
            transmission.ShiftDownRpm = math.floor((redline - 200) * 0.42)
            if transmission.Kind ~= "Manual" then
                transmission.LaunchRpm = math.floor(idle + (redline - idle) * 0.35)
            else
                transmission.LaunchRpm = math.floor(idle + 700)
            end
        else
            transmission.Cvt.CruiseRpm = math.max(idle + 400, math.floor(redline * 0.26))
            transmission.Cvt.PowerRpm = math.floor(redline * 0.83)
            transmission.LaunchRpm = math.floor(idle + (redline - idle) * 0.35)
        end
        if transmission.Converter then
            transmission.Converter.StallRpm = math.floor(idle + (redline - idle) * 0.27)
        end
        if transmission.Clutch then
            transmission.Clutch.MaxTorqueNm = math.ceil(torque * 1.3)
        end
    end
    if spec.FinalDrive then
        transmission.FinalDrive = spec.FinalDrive
    end
    powertrain.Transmission = transmission

    -- Architecture motrice.
    local drivetrain: any = {
        Layout = spec.Layout,
        FrontTorqueShare = if spec.Layout == "FWD" then 1 elseif spec.Layout == "RWD" then 0 else spec.FrontShare or 0.4,
        FrontDifferential = if spec.Lsd and spec.Layout == "FWD" then lsd() else openDiff(),
        RearDifferential = if spec.Lsd and spec.Layout ~= "FWD" then lsd() else openDiff(),
    }
    if spec.Layout == "AWD" then
        drivetrain.CenterDifferential =
            { Kind = "LimitedSlip", PreloadNm = 50, PowerLockRatio = 0.3, CoastLockRatio = 0.2 }
    end
    powertrain.Drivetrain = drivetrain

    d.Aids = table.clone(spec.Aids)
    d.Limits.MaxPlausibleSpeedKmh = math.max(160, math.floor(spec.TopSpeedKmh * 1.25 + 0.5))
    d.Appearance = {
        BodyRgb = spec.Body,
        AccentRgb = spec.Accent,
        TrimRgb = spec.Trim,
        Label = string.upper(spec.Name),
        BodyStyle = spec.Style,
    }
    return d :: Types.VehicleDefinition
end

local AIDS_ALL = { Abs = true, TractionControl = true, StabilityControl = true }
local AIDS_ABS_TC = { Abs = true, TractionControl = true, StabilityControl = false }
local AIDS_ABS = { Abs = true, TractionControl = false, StabilityControl = false }

-- Les spécifications sont exposées (fiches, catalogue, tests de cohérence).
local SPECS: { Spec } = {
    -- Citadines.
    {
        Id = "wk_pixel",
        Name = "Pixel",
        Base = "Electric",
        Gearbox = "SingleSpeed",
        Layout = "RWD",
        PowerKw = 45,
        MassKg = 880,
        LengthM = 3.15,
        WidthM = 1.62,
        HeightM = 1.55,
        WheelbaseM = 2.1,
        CgHeightM = 0.46,
        FrontWeight = 0.46,
        DragAreaM2 = 0.6,
        TireRadiusM = 0.29,
        TireWidthM = 0.165,
        Grip = 0.95,
        Stiffness = 1,
        SteerDeg = 36,
        Capacity = 22,
        TopSpeedKmh = 125,
        FinalDrive = 9.5,
        Aids = AIDS_ALL,
        Style = "Micro",
        Body = { 120, 200, 210 },
        Accent = { 245, 245, 240 },
        Trim = { 40, 42, 46 },
    },
    {
        Id = "wk_brio",
        Name = "Brio",
        Base = "Petrol",
        Gearbox = "Manual",
        Layout = "FWD",
        PowerKw = 70,
        MassKg = 1050,
        LengthM = 3.8,
        WidthM = 1.7,
        HeightM = 1.5,
        WheelbaseM = 2.45,
        CgHeightM = 0.5,
        FrontWeight = 0.61,
        DragAreaM2 = 0.64,
        TireRadiusM = 0.3,
        TireWidthM = 0.185,
        Grip = 0.98,
        Stiffness = 1,
        SteerDeg = 35,
        Capacity = 42,
        TopSpeedKmh = 175,
        Aids = AIDS_ABS_TC,
        Style = "Hatch",
        Body = { 176, 28, 34 },
        Accent = { 240, 240, 240 },
        Trim = { 30, 30, 34 },
    },
    {
        Id = "wk_fil",
        Name = "Fil",
        Base = "Electric",
        Gearbox = "SingleSpeed",
        Layout = "FWD",
        PowerKw = 85,
        MassKg = 1320,
        LengthM = 4.05,
        WidthM = 1.76,
        HeightM = 1.56,
        WheelbaseM = 2.58,
        CgHeightM = 0.48,
        FrontWeight = 0.56,
        DragAreaM2 = 0.62,
        TireRadiusM = 0.31,
        TireWidthM = 0.195,
        Grip = 0.98,
        Stiffness = 1,
        SteerDeg = 35,
        Capacity = 45,
        TopSpeedKmh = 150,
        FinalDrive = 8.6,
        Aids = AIDS_ALL,
        Style = "Hatch",
        Body = { 26, 82, 56 },
        Accent = { 236, 236, 232 },
        Trim = { 36, 38, 40 },
    },
    -- Compactes.
    {
        Id = "wk_aster",
        Name = "Aster",
        Base = "Petrol",
        Gearbox = "Automatic",
        Layout = "FWD",
        PowerKw = 95,
        MassKg = 1280,
        LengthM = 4.25,
        WidthM = 1.78,
        HeightM = 1.47,
        WheelbaseM = 2.62,
        CgHeightM = 0.5,
        FrontWeight = 0.6,
        DragAreaM2 = 0.64,
        TireRadiusM = 0.315,
        TireWidthM = 0.205,
        Grip = 1,
        Stiffness = 1,
        SteerDeg = 34,
        Capacity = 48,
        TopSpeedKmh = 195,
        Aids = AIDS_ALL,
        Style = "Hatch",
        Body = { 210, 214, 220 },
        Accent = { 40, 120, 200 },
        Trim = { 34, 36, 40 },
    },
    {
        Id = "wk_nova",
        Name = "Nova",
        Base = "Petrol",
        Gearbox = "CVT",
        Layout = "FWD",
        PowerKw = 85,
        MassKg = 1240,
        LengthM = 4.4,
        WidthM = 1.76,
        HeightM = 1.46,
        WheelbaseM = 2.64,
        CgHeightM = 0.5,
        FrontWeight = 0.6,
        DragAreaM2 = 0.6,
        TireRadiusM = 0.31,
        TireWidthM = 0.195,
        Grip = 0.98,
        Stiffness = 0.95,
        SteerDeg = 34,
        Capacity = 45,
        TopSpeedKmh = 185,
        Aids = AIDS_ALL,
        Style = "Sedan",
        Body = { 90, 96, 104 },
        Accent = { 220, 220, 225 },
        Trim = { 34, 36, 40 },
    },
    -- Berlines et break.
    {
        Id = "wk_cadence",
        Name = "Cadence",
        Base = "Diesel",
        Gearbox = "Automatic",
        Layout = "FWD",
        PowerKw = 110,
        MassKg = 1520,
        LengthM = 4.8,
        WidthM = 1.83,
        HeightM = 1.46,
        WheelbaseM = 2.8,
        CgHeightM = 0.52,
        FrontWeight = 0.6,
        DragAreaM2 = 0.62,
        TireRadiusM = 0.325,
        TireWidthM = 0.215,
        Grip = 1,
        Stiffness = 0.95,
        SteerDeg = 33,
        Capacity = 60,
        TopSpeedKmh = 215,
        -- Pont allongé : la boîte automatique de base plafonnait à 194 km/h.
        FinalDrive = 3.4,
        Aids = AIDS_ALL,
        Style = "Sedan",
        Body = { 28, 58, 120 },
        Accent = { 200, 200, 205 },
        Trim = { 30, 32, 36 },
    },
    {
        Id = "wk_lumen",
        Name = "Lumen",
        Base = "Diesel",
        Gearbox = "Manual",
        Layout = "FWD",
        PowerKw = 100,
        MassKg = 1480,
        LengthM = 4.7,
        WidthM = 1.82,
        HeightM = 1.5,
        WheelbaseM = 2.75,
        CgHeightM = 0.53,
        FrontWeight = 0.6,
        DragAreaM2 = 0.66,
        TireRadiusM = 0.32,
        TireWidthM = 0.205,
        Grip = 0.98,
        Stiffness = 0.95,
        SteerDeg = 33,
        Capacity = 58,
        TopSpeedKmh = 205,
        Aids = AIDS_ABS_TC,
        Style = "Wagon",
        Body = { 120, 40, 50 },
        Accent = { 210, 210, 210 },
        Trim = { 32, 32, 34 },
    },
    {
        Id = "wk_oree",
        Name = "Orée",
        Base = "Electric",
        Gearbox = "SingleSpeed",
        Layout = "AWD",
        FrontShare = 0.45,
        PowerKw = 230,
        MassKg = 2050,
        LengthM = 4.95,
        WidthM = 1.9,
        HeightM = 1.45,
        WheelbaseM = 2.95,
        CgHeightM = 0.47,
        FrontWeight = 0.5,
        DragAreaM2 = 0.56,
        TireRadiusM = 0.345,
        TireWidthM = 0.245,
        Grip = 1.05,
        Stiffness = 1.05,
        SteerDeg = 32,
        Capacity = 85,
        TopSpeedKmh = 220,
        FinalDrive = 9.0,
        Aids = AIDS_ALL,
        Style = "Sedan",
        Body = { 230, 232, 236 },
        Accent = { 60, 170, 210 },
        Trim = { 40, 40, 44 },
    },
    -- Coupés et sportives.
    {
        Id = "wk_brise",
        Name = "Brise",
        Base = "Petrol",
        Gearbox = "Manual",
        Layout = "RWD",
        Lsd = true,
        PowerKw = 110,
        MassKg = 1060,
        LengthM = 3.95,
        WidthM = 1.73,
        HeightM = 1.24,
        WheelbaseM = 2.35,
        CgHeightM = 0.44,
        FrontWeight = 0.51,
        DragAreaM2 = 0.6,
        TireRadiusM = 0.305,
        TireWidthM = 0.205,
        Grip = 1.05,
        Stiffness = 1.2,
        SteerDeg = 33,
        Capacity = 40,
        TopSpeedKmh = 210,
        Aids = AIDS_ABS_TC,
        Style = "Roadster",
        Body = { 20, 90, 70 },
        Accent = { 230, 210, 160 },
        Trim = { 120, 70, 40 },
    },
    {
        Id = "wk_rafale",
        Name = "Rafale",
        Base = "Petrol",
        Gearbox = "DualClutch",
        Layout = "FWD",
        Lsd = true,
        PowerKw = 200,
        MassKg = 1420,
        LengthM = 4.3,
        WidthM = 1.8,
        HeightM = 1.43,
        WheelbaseM = 2.65,
        CgHeightM = 0.47,
        FrontWeight = 0.61,
        DragAreaM2 = 0.66,
        TireRadiusM = 0.33,
        TireWidthM = 0.235,
        Grip = 1.1,
        Stiffness = 1.25,
        SteerDeg = 33,
        Capacity = 50,
        TopSpeedKmh = 250,
        Aids = AIDS_ALL,
        Style = "Hatch",
        Body = { 230, 230, 235 },
        Accent = { 220, 30, 40 },
        Trim = { 20, 20, 22 },
    },
    {
        Id = "wk_eclat",
        Name = "Éclat",
        Base = "Petrol",
        Gearbox = "Manual",
        Layout = "RWD",
        Lsd = true,
        PowerKw = 185,
        MassKg = 1360,
        LengthM = 4.45,
        WidthM = 1.82,
        HeightM = 1.32,
        WheelbaseM = 2.6,
        CgHeightM = 0.45,
        FrontWeight = 0.52,
        DragAreaM2 = 0.62,
        TireRadiusM = 0.33,
        TireWidthM = 0.235,
        Grip = 1.1,
        Stiffness = 1.25,
        SteerDeg = 32,
        Capacity = 55,
        TopSpeedKmh = 245,
        Aids = AIDS_ABS,
        Style = "Coupe",
        Body = { 240, 196, 32 },
        Accent = { 22, 23, 26 },
        Trim = { 22, 23, 26 },
    },
    {
        Id = "wk_mistral",
        Name = "Mistral",
        Base = "Petrol",
        Gearbox = "Automatic",
        Layout = "RWD",
        Lsd = true,
        PowerKw = 330,
        MassKg = 1720,
        LengthM = 4.75,
        WidthM = 1.92,
        HeightM = 1.33,
        WheelbaseM = 2.8,
        CgHeightM = 0.46,
        FrontWeight = 0.52,
        DragAreaM2 = 0.64,
        TireRadiusM = 0.345,
        TireWidthM = 0.265,
        Grip = 1.12,
        Stiffness = 1.2,
        SteerDeg = 31,
        Capacity = 70,
        TopSpeedKmh = 290,
        Aids = AIDS_ALL,
        Style = "Coupe",
        Body = { 70, 20, 30 },
        Accent = { 200, 170, 110 },
        Trim = { 50, 30, 25 },
    },
    -- Supercars.
    {
        Id = "wk_comete",
        Name = "Comète",
        Base = "Petrol",
        Gearbox = "Sequential",
        Layout = "RWD",
        Lsd = true,
        PowerKw = 470,
        MassKg = 1450,
        LengthM = 4.55,
        WidthM = 2.0,
        HeightM = 1.18,
        WheelbaseM = 2.7,
        CgHeightM = 0.42,
        FrontWeight = 0.42,
        DragAreaM2 = 0.6,
        TireRadiusM = 0.34,
        TireWidthM = 0.295,
        Grip = 1.2,
        Stiffness = 1.45,
        SteerDeg = 30,
        Capacity = 80,
        TopSpeedKmh = 320,
        FinalDrive = 3.0,
        Aids = AIDS_ALL,
        Style = "Supercar",
        Body = { 255, 120, 0 },
        Accent = { 20, 20, 22 },
        Trim = { 20, 20, 22 },
    },
    {
        Id = "wk_zenith",
        Name = "Zénith",
        Base = "Electric",
        Gearbox = "SingleSpeed",
        Layout = "AWD",
        FrontShare = 0.4,
        PowerKw = 600,
        MassKg = 1900,
        LengthM = 4.7,
        WidthM = 2.02,
        HeightM = 1.2,
        WheelbaseM = 2.8,
        CgHeightM = 0.41,
        FrontWeight = 0.45,
        DragAreaM2 = 0.58,
        TireRadiusM = 0.345,
        TireWidthM = 0.295,
        Grip = 1.2,
        Stiffness = 1.4,
        SteerDeg = 30,
        Capacity = 100,
        TopSpeedKmh = 300,
        FinalDrive = 6.9,
        Aids = AIDS_ALL,
        Style = "Supercar",
        Body = { 30, 34, 44 },
        Accent = { 0, 220, 200 },
        Trim = { 24, 24, 28 },
    },
    -- SUV et tout-terrain.
    {
        Id = "wk_dune",
        Name = "Dune",
        Base = "Petrol",
        Gearbox = "Automatic",
        Layout = "AWD",
        FrontShare = 0.4,
        PowerKw = 120,
        MassKg = 1600,
        LengthM = 4.45,
        WidthM = 1.84,
        HeightM = 1.66,
        WheelbaseM = 2.68,
        CgHeightM = 0.62,
        FrontWeight = 0.57,
        DragAreaM2 = 0.82,
        TireRadiusM = 0.35,
        TireWidthM = 0.215,
        Grip = 0.98,
        Stiffness = 0.95,
        TravelM = 0.24,
        SteerDeg = 34,
        Capacity = 55,
        TopSpeedKmh = 195,
        Aids = AIDS_ALL,
        Style = "SUV",
        Body = { 196, 176, 140 },
        Accent = { 60, 60, 64 },
        Trim = { 50, 48, 46 },
    },
    {
        Id = "wk_vigie",
        Name = "Vigie",
        Base = "Petrol",
        Gearbox = "Automatic",
        Layout = "AWD",
        FrontShare = 0.4,
        PowerKw = 240,
        MassKg = 2080,
        LengthM = 4.95,
        WidthM = 1.96,
        HeightM = 1.74,
        WheelbaseM = 2.95,
        CgHeightM = 0.66,
        FrontWeight = 0.54,
        DragAreaM2 = 0.9,
        TireRadiusM = 0.37,
        TireWidthM = 0.255,
        Grip = 1,
        Stiffness = 1,
        TravelM = 0.26,
        SteerDeg = 32,
        Capacity = 80,
        TopSpeedKmh = 240,
        Aids = AIDS_ALL,
        Style = "SUV",
        Body = { 40, 44, 50 },
        Accent = { 190, 190, 196 },
        Trim = { 70, 50, 40 },
    },
    {
        Id = "wk_sentier",
        Name = "Sentier",
        Base = "Petrol",
        Gearbox = "Manual",
        Layout = "AWD",
        FrontShare = 0.5,
        PowerKw = 90,
        MassKg = 1300,
        LengthM = 3.9,
        WidthM = 1.76,
        HeightM = 1.72,
        WheelbaseM = 2.4,
        CgHeightM = 0.66,
        FrontWeight = 0.55,
        DragAreaM2 = 0.86,
        TireRadiusM = 0.36,
        TireWidthM = 0.215,
        Grip = 0.95,
        Stiffness = 0.85,
        TravelM = 0.28,
        SteerDeg = 36,
        Capacity = 50,
        TopSpeedKmh = 165,
        Aids = AIDS_ABS,
        Style = "OffRoad",
        Body = { 90, 110, 70 },
        Accent = { 230, 160, 40 },
        Trim = { 40, 40, 38 },
    },
    {
        Id = "wk_atlas",
        Name = "Atlas",
        Base = "Diesel",
        Gearbox = "Automatic",
        Layout = "AWD",
        FrontShare = 0.35,
        PowerKw = 150,
        MassKg = 2250,
        LengthM = 5.3,
        WidthM = 1.95,
        HeightM = 1.82,
        WheelbaseM = 3.2,
        CgHeightM = 0.7,
        FrontWeight = 0.57,
        DragAreaM2 = 1.0,
        TireRadiusM = 0.38,
        TireWidthM = 0.255,
        Grip = 0.97,
        Stiffness = 0.9,
        TravelM = 0.28,
        SteerDeg = 33,
        Capacity = 80,
        TopSpeedKmh = 185,
        Aids = AIDS_ABS_TC,
        Style = "Pickup",
        Body = { 170, 40, 30 },
        Accent = { 210, 210, 210 },
        Trim = { 40, 40, 40 },
    },
}

local DEFINITIONS: { Types.VehicleDefinition } = {}
for _, spec in SPECS do
    table.insert(DEFINITIONS, build(spec))
end

return table.freeze({
    Specs = table.freeze(SPECS),
    Definitions = DEFINITIONS,
    build = build,
})
