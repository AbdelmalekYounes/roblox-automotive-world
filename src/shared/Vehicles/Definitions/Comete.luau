--!strict
--[[
    Comète (wk_comete) — définition physique AUTONOME (lot BASE-01, 2026-11-05).

    Décision du propriétaire du 2026-11-05 : la gamme ne garde que la Comète (puis la citadine, VEH3D-02) ; les
    17 autres modèles, les prototypes P-01 à P-03 et les variantes de validation sont retirés du jeu. Jusqu'ici, la
    Comète était CALCULÉE par WorkingCatalog à partir du prototype P-03 et des variantes de validation ; ses valeurs
    sont figées ici À L'IDENTIQUE (générées par tests/lune/tools/dump-definition.luau, comparées à la référence
    tests/lune/fixtures/comete_definition_reference.json par un test Lune). Unités : SI (m, kg, N·m, kW, s) ; les
    valeurs sont des hypothèses de conception, pas des mesures d'un véhicule réel.

    Carrosserie : kit de maillages tiers CC BY 4.0 (MeshKitData, docs/vehicle-3d/MODELES_TIERS.md).
]]

local Types = require(script.Parent.Parent.VehicleTypes)

local definition: Types.VehicleDefinition = {
    Aids = {
        Abs = true,
        StabilityControl = true,
        TractionControl = true,
    },
    Appearance = {
        AccentRgb = {
            20,
            20,
            22,
        },
        BodyRgb = {
            255,
            120,
            0,
        },
        BodyStyle = "Supercar",
        Label = "COMèTE",
        TrimRgb = {
            20,
            20,
            22,
        },
    },
    Brakes = {
        HandbrakeTorqueNm = 1855.9999999999998,
        MaxTorqueFrontNm = 1948.8,
        MaxTorqueRearNm = 974.39999999999998,
    },
    Chassis = {
        CgHeightM = 0.41999999999999998,
        DragAreaM2 = 0.59999999999999998,
        FrontWeightFraction = 0.41999999999999998,
        HeightM = 1.1799999999999999,
        LengthM = 4.5499999999999998,
        MassKg = 1450,
        TrackFrontM = 1.74,
        TrackRearM = 1.76,
        WheelbaseM = 2.7000000000000002,
        WidthM = 2,
    },
    DisplayName = "Comète",
    Id = "wk_comete",
    IsTestPrototype = false,
    Limits = {
        ExitMaxSpeedKmh = 20,
        MaxPlausibleSpeedKmh = 400,
    },
    Powertrain = {
        Drivetrain = {
            FrontDifferential = {
                CoastLockRatio = 0,
                Kind = "Open",
                PowerLockRatio = 0,
                PreloadNm = 0,
            },
            FrontTorqueShare = 0,
            Layout = "RWD",
            RearDifferential = {
                CoastLockRatio = 0.14999999999999999,
                Kind = "LimitedSlip",
                PowerLockRatio = 0.29999999999999999,
                PreloadNm = 40,
            },
        },
        Energy = {
            Capacity = 80,
            InitialFraction = 0.59999999999999998,
            Kind = "Petrol",
        },
        Engine = {
            BsfcGPerKWh = 250,
            EngineBrakeTorqueNm = 112.5,
            IdleControlTorqueNm = 62.5,
            IdleFuelLph = 0.80000000000000004,
            IdleRpm = 850,
            InertiaKgM2 = 0.29999999999999999,
            LimiterRpm = 7200,
            PartLoadPenalty = 1.2,
            RedlineRpm = 7000,
            StallRpm = 450,
            TorqueCurve = {
                {
                    Rpm = 1000,
                    TorqueNm = 453,
                },
                {
                    Rpm = 2000,
                    TorqueNm = 622,
                },
                {
                    Rpm = 3000,
                    TorqueNm = 717,
                },
                {
                    Rpm = 4000,
                    TorqueNm = 773,
                },
                {
                    Rpm = 5000,
                    TorqueNm = 784,
                },
                {
                    Rpm = 6000,
                    TorqueNm = 735,
                },
                {
                    Rpm = 6800,
                    TorqueNm = 660,
                },
                {
                    Rpm = 7200,
                    TorqueNm = 603,
                },
            },
        },
        Transmission = {
            Clutch = {
                MaxTorqueNm = 1020,
            },
            Efficiency = 0.93000000000000005,
            FinalDrive = 3,
            ForwardRatios = {
                3.2000000000000002,
                2.2000000000000002,
                1.6499999999999999,
                1.3,
                1.0800000000000001,
                0.92000000000000004,
            },
            Kind = "Sequential",
            LaunchRpm = 3002,
            ReverseRatio = 3.2999999999999998,
            ShiftDownRpm = 2856,
            ShiftDurationS = 0.059999999999999998,
            ShiftUpRpm = 6800,
        },
    },
    Steering = {
        HighSpeedAngleDeg = 9,
        HighSpeedReferenceKmh = 140,
        MaxAngleDeg = 30,
        RackSpeedDegPerS = 110,
    },
    Suspension = {
        ContactProbe = "Sphere",
        Front = {
            AntiRollNpm = 18660.679245283016,
            BumpDampingNsPm = 3065.6830188679241,
            BumpStopRateNpm = 250000,
            ReboundDampingNsPm = 4798.4603773584904,
            RestLengthM = 0.20000000000000001,
            SpringRateNpm = 64745.892452830187,
            TravelM = 0.20000000000000001,
        },
        Rear = {
            AntiRollNpm = 18680.936170212768,
            BumpDampingNsPm = 4566.4510638297879,
            BumpStopRateNpm = 250000,
            ReboundDampingNsPm = 7057.2425531914905,
            RestLengthM = 0.20000000000000001,
            SpringRateNpm = 99320.310638297888,
            TravelM = 0.20000000000000001,
        },
    },
    Tires = {
        LoadSensitivity = 0.10000000000000001,
        PeakFrictionLateral = 1.2,
        PeakFrictionLongitudinal = 1.26,
        PeakSlipAngleDeg = 7,
        PeakSlipRatio = 0.10000000000000001,
        RadiusM = 0.34000000000000002,
        RelaxationLengthM = 0.34999999999999998,
        RollingResistance = 0.012999999999999999,
        SlidingFrictionRatio = 0.80000000000000004,
        WetGripRatio = 0.71999999999999997,
        WetSlidingFrictionRatio = 0.69999999999999996,
        WheelInertiaKgM2 = 1.8587572674418604,
        WidthM = 0.29499999999999998,
    },
}

return definition
