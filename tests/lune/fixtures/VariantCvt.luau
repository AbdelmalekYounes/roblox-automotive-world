--!strict
-- JEU D'ESSAI (lot BASE-01) : définition « proto_p01_cvt », retirée du jeu le 2026-11-05 (décision du propriétaire, point P1),
-- conservée ici pour valider le moteur physique (boîtes, énergies). Valeurs résolues exactes, générées depuis `main`
-- (6a2dc34) par tests/lune/tools/dump-definition.luau. Jamais livré dans le jeu.
return {
    Aids = {
        Abs = false,
        StabilityControl = false,
        TractionControl = false,
    },
    Appearance = {
        AccentRgb = {
            140,
            220,
            80,
        },
        BodyRgb = {
            74,
            80,
            89,
        },
        Label = "P-01 CVT",
        TrimRgb = {
            28,
            30,
            34,
        },
    },
    Brakes = {
        HandbrakeTorqueNm = 1600,
        MaxTorqueFrontNm = 1400,
        MaxTorqueRearNm = 700,
    },
    Chassis = {
        CgHeightM = 0.5,
        DragAreaM2 = 0.66000000000000003,
        FrontWeightFraction = 0.53000000000000003,
        HeightM = 1.6200000000000001,
        LengthM = 4.2999999999999998,
        MassKg = 1250,
        TrackFrontM = 1.52,
        TrackRearM = 1.54,
        WheelbaseM = 2.5499999999999998,
        WidthM = 1.8,
    },
    DisplayName = "P-01 · variateur CVT (validation)",
    Id = "proto_p01_cvt",
    IsTestPrototype = true,
    Limits = {
        ExitMaxSpeedKmh = 20,
        MaxPlausibleSpeedKmh = 280,
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
                CoastLockRatio = 0,
                Kind = "Open",
                PowerLockRatio = 0,
                PreloadNm = 0,
            },
        },
        Energy = {
            Capacity = 50,
            InitialFraction = 0.59999999999999998,
            Kind = "Petrol",
        },
        Engine = {
            BsfcGPerKWh = 250,
            EngineBrakeTorqueNm = 45,
            IdleControlTorqueNm = 25,
            IdleFuelLph = 0.80000000000000004,
            IdleRpm = 850,
            InertiaKgM2 = 0.14999999999999999,
            LimiterRpm = 7200,
            PartLoadPenalty = 1.2,
            RedlineRpm = 7000,
            StallRpm = 450,
            TorqueCurve = {
                {
                    Rpm = 1000,
                    TorqueNm = 120,
                },
                {
                    Rpm = 2000,
                    TorqueNm = 165,
                },
                {
                    Rpm = 3000,
                    TorqueNm = 190,
                },
                {
                    Rpm = 4000,
                    TorqueNm = 205,
                },
                {
                    Rpm = 5000,
                    TorqueNm = 208,
                },
                {
                    Rpm = 6000,
                    TorqueNm = 195,
                },
                {
                    Rpm = 6800,
                    TorqueNm = 175,
                },
                {
                    Rpm = 7200,
                    TorqueNm = 160,
                },
            },
        },
        Transmission = {
            Clutch = {
                MaxTorqueNm = 320,
            },
            Cvt = {
                CruiseRpm = 1800,
                PowerRpm = 5800,
                RatioRatePerS = 1.6000000000000001,
            },
            Efficiency = 0.85999999999999999,
            FinalDrive = 5.2000000000000002,
            ForwardRatios = {
                2.6000000000000001,
                0.45000000000000001,
            },
            Kind = "CVT",
            LaunchRpm = 3000,
            ReverseRatio = 2.6000000000000001,
            ShiftDownRpm = 0,
            ShiftDurationS = 0,
            ShiftUpRpm = 0,
        },
    },
    Steering = {
        HighSpeedAngleDeg = 9,
        HighSpeedReferenceKmh = 140,
        MaxAngleDeg = 32,
        RackSpeedDegPerS = 110,
    },
    Suspension = {
        ContactProbe = "Sphere",
        Front = {
            AntiRollNpm = 14000,
            BumpDampingNsPm = 2300,
            BumpStopRateNpm = 250000,
            ReboundDampingNsPm = 3600,
            RestLengthM = 0.20000000000000001,
            SpringRateNpm = 33500,
            TravelM = 0.20000000000000001,
        },
        Rear = {
            AntiRollNpm = 9000,
            BumpDampingNsPm = 2200,
            BumpStopRateNpm = 250000,
            ReboundDampingNsPm = 3400,
            RestLengthM = 0.20000000000000001,
            SpringRateNpm = 33000,
            TravelM = 0.20000000000000001,
        },
    },
    Tires = {
        LoadSensitivity = 0.10000000000000001,
        PeakFrictionLateral = 1,
        PeakFrictionLongitudinal = 1.05,
        PeakSlipAngleDeg = 7,
        PeakSlipRatio = 0.10000000000000001,
        RadiusM = 0.32000000000000001,
        RelaxationLengthM = 0.34999999999999998,
        RollingResistance = 0.012999999999999999,
        SlidingFrictionRatio = 0.80000000000000004,
        WetGripRatio = 0.71999999999999997,
        WetSlidingFrictionRatio = 0.69999999999999996,
        WheelInertiaKgM2 = 1.2,
        WidthM = 0.215,
    },
}
