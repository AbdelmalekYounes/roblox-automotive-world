--!strict
-- Définition du « Prototype d'essai P-01 ».
--
-- Véhicule 100 % fictif, créé pour le lot 0.1. Ce n'est NI un modèle du
-- catalogue de lancement (18 modèles), NI une option de départ gratuite.
-- Toutes les valeurs ci-dessous sont des hypothèses de conception choisies
-- pour obtenir une berlinette propulsion plausible ; aucune n'est une mesure.
-- Elles sont regroupées ici pour être modifiées sans toucher au code.

local Types = require(script.Parent.Parent.VehicleTypes)

local definition: Types.VehicleDefinition = {
    Id = "proto_p01",
    DisplayName = "Prototype d'essai P-01",
    IsTestPrototype = true,

    Chassis = {
        MassKg = 1250,
        LengthM = 4.3,
        WidthM = 1.8,
        HeightM = 1.45,
        WheelbaseM = 2.55,
        TrackFrontM = 1.52,
        TrackRearM = 1.54,
        CgHeightM = 0.5,
        FrontWeightFraction = 0.53,
        DragAreaM2 = 0.66,
    },

    -- Fréquences propres visées ≈ 1,6 Hz (avant) et 1,7 Hz (arrière).
    Suspension = {
        Front = {
            RestLengthM = 0.2,
            TravelM = 0.2,
            SpringRateNpm = 33500,
            BumpDampingNsPm = 2300,
            ReboundDampingNsPm = 3600,
            AntiRollNpm = 14000,
            BumpStopRateNpm = 250000,
        },
        Rear = {
            RestLengthM = 0.2,
            TravelM = 0.2,
            SpringRateNpm = 33000,
            BumpDampingNsPm = 2200,
            ReboundDampingNsPm = 3400,
            AntiRollNpm = 9000,
            BumpStopRateNpm = 250000,
        },
    },

    Tires = {
        RadiusM = 0.32,
        WidthM = 0.215,
        WheelInertiaKgM2 = 1.2,
        PeakFrictionLongitudinal = 1.05,
        PeakFrictionLateral = 1.0,
        SlidingFrictionRatio = 0.8,
        PeakSlipRatio = 0.1,
        PeakSlipAngleDeg = 7,
        LoadSensitivity = 0.1,
        RollingResistance = 0.013,
    },

    Brakes = {
        MaxTorqueFrontNm = 1400,
        MaxTorqueRearNm = 700,
        HandbrakeTorqueNm = 1600,
    },

    Steering = {
        MaxAngleDeg = 32,
        HighSpeedAngleDeg = 9,
        HighSpeedReferenceKmh = 140,
        RackSpeedDegPerS = 110,
    },

    Powertrain = {
        Kind = "Combustion",
        Engine = {
            IdleRpm = 850,
            RedlineRpm = 7000,
            LimiterRpm = 7200,
            ClutchLaunchRpm = 2600,
            InertiaKgM2 = 0.15,
            EngineBrakeTorqueNm = 45,
            TorqueCurve = {
                { Rpm = 1000, TorqueNm = 120 },
                { Rpm = 2000, TorqueNm = 165 },
                { Rpm = 3000, TorqueNm = 190 },
                { Rpm = 4000, TorqueNm = 205 },
                { Rpm = 5000, TorqueNm = 208 },
                { Rpm = 6000, TorqueNm = 195 },
                { Rpm = 6800, TorqueNm = 175 },
                { Rpm = 7200, TorqueNm = 160 },
            },
        },
        Transmission = {
            Kind = "Automatic",
            ForwardRatios = { 3.4, 2.1, 1.5, 1.15, 0.92, 0.76 },
            ReverseRatio = 3.3,
            FinalDrive = 3.9,
            Efficiency = 0.88,
            ShiftUpRpm = 6800,
            ShiftDownRpm = 3000,
            ShiftDurationS = 0.25,
        },
        Drivetrain = {
            Layout = "RWD",
            FrontTorqueShare = 0,
        },
    },

    -- Ce prototype n'a volontairement aucune aide (état réel, non caché).
    Aids = {
        Abs = false,
        TractionControl = false,
        StabilityControl = false,
    },

    Limits = {
        MaxPlausibleSpeedKmh = 280,
        ExitMaxSpeedKmh = 20,
    },

    Appearance = {
        BodyRgb = { 74, 80, 89 },
        AccentRgb = { 255, 122, 26 },
        TrimRgb = { 28, 30, 34 },
        Label = "P-01 ESSAI",
    },
}

return definition
