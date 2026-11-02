--!strict
-- Définition du « Prototype d'essai P-03 » (lot 0.2).
--
-- Véhicule 100 % fictif : berline électrique à transmission intégrale, rapport
-- unique, freinage régénératif réglable. Lourde (batterie), centre de gravité
-- bas, couple immédiat. Ce n'est NI un modèle du catalogue de lancement, NI une
-- option de départ gratuite. Toutes les valeurs sont des hypothèses de conception.

local Types = require(script.Parent.Parent.VehicleTypes)

local definition: Types.VehicleDefinition = {
    Id = "proto_p03",
    DisplayName = "Prototype d'essai P-03",
    IsTestPrototype = true,

    Chassis = {
        MassKg = 1850,
        LengthM = 4.6,
        WidthM = 1.9,
        HeightM = 1.6,
        WheelbaseM = 2.8,
        TrackFrontM = 1.6,
        TrackRearM = 1.6,
        CgHeightM = 0.47,
        FrontWeightFraction = 0.48,
        DragAreaM2 = 0.6,
    },

    Suspension = {
        -- Sonde de contact : balayage de sphère, retenu d'après les mesures en Studio
        -- (bordures de 12 cm : pic vertical −37 à −41 %, ≈ +7 µs par pas ; RAPPORT_LOT_0.2).
        ContactProbe = "Sphere",
        Front = {
            RestLengthM = 0.2,
            TravelM = 0.2,
            SpringRateNpm = 38000,
            BumpDampingNsPm = 2800,
            ReboundDampingNsPm = 4200,
            AntiRollNpm = 18000,
            BumpStopRateNpm = 300000,
        },
        Rear = {
            RestLengthM = 0.2,
            TravelM = 0.2,
            SpringRateNpm = 40000,
            BumpDampingNsPm = 2900,
            ReboundDampingNsPm = 4400,
            AntiRollNpm = 14000,
            BumpStopRateNpm = 300000,
        },
    },

    Tires = {
        RadiusM = 0.34,
        WidthM = 0.235,
        WheelInertiaKgM2 = 1.5,
        PeakFrictionLongitudinal = 1.05,
        PeakFrictionLateral = 1.0,
        SlidingFrictionRatio = 0.8,
        PeakSlipRatio = 0.1,
        PeakSlipAngleDeg = 7,
        LoadSensitivity = 0.1,
        RollingResistance = 0.011,
        WetGripRatio = 0.72,
        WetSlidingFrictionRatio = 0.7,
        RelaxationLengthM = 0.35,
    },

    Brakes = {
        MaxTorqueFrontNm = 2000,
        MaxTorqueRearNm = 1200,
        HandbrakeTorqueNm = 1500,
    },

    Steering = {
        MaxAngleDeg = 30,
        HighSpeedAngleDeg = 8,
        HighSpeedReferenceKmh = 150,
        RackSpeedDegPerS = 110,
    },

    Powertrain = {
        Energy = {
            Kind = "Electric",
            Capacity = 62, -- kWh
            InitialFraction = 0.6,
        },
        Motor = {
            MaxTorqueNm = 420,
            MaxPowerKw = 220,
            MaxRpm = 16000,
            InertiaKgM2 = 0.08,
            TopSpeedKmh = 200,
            DriveEfficiency = 0.9,
            RegenMaxPowerKw = 90,
            RegenMaxTorqueNm = 300,
            RegenEfficiency = 0.85,
            -- Récupération au lâcher : modérée (défaut), forte, nulle.
            RegenLevels = { 0.3, 0.7, 0 },
            AuxPowerKw = 1.2,
        },
        Transmission = {
            Kind = "SingleSpeed",
            ForwardRatios = { 1 },
            ReverseRatio = 1,
            FinalDrive = 9.0,
            Efficiency = 0.95,
            ShiftUpRpm = 0,
            ShiftDownRpm = 0,
            ShiftDurationS = 0,
            LaunchRpm = 0,
        },
        Drivetrain = {
            Layout = "AWD",
            FrontTorqueShare = 0.4,
            FrontDifferential = { Kind = "Open", PreloadNm = 0, PowerLockRatio = 0, CoastLockRatio = 0 },
            RearDifferential = { Kind = "LimitedSlip", PreloadNm = 40, PowerLockRatio = 0.25, CoastLockRatio = 0.15 },
            CenterDifferential = {
                Kind = "LimitedSlip",
                PreloadNm = 50,
                PowerLockRatio = 0.3,
                CoastLockRatio = 0.2,
            },
        },
    },

    -- Équipé des trois aides, toutes désactivées par défaut.
    Aids = {
        Abs = true,
        TractionControl = true,
        StabilityControl = true,
    },

    Limits = {
        MaxPlausibleSpeedKmh = 240,
        ExitMaxSpeedKmh = 20,
    },

    Appearance = {
        BodyRgb = { 225, 228, 232 },
        AccentRgb = { 40, 200, 160 },
        TrimRgb = { 34, 36, 40 },
        Label = "P-03 ESSAI",
    },
}

return definition
