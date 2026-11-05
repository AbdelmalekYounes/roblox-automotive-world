--!strict
-- JEU D'ESSAI (lot BASE-01) : définition « proto_p02 », retirée du jeu le 2026-11-05 (décision du propriétaire, point P1),
-- conservée ici pour valider le moteur physique (boîtes, énergies). Valeurs résolues exactes, générées depuis `main`
-- (6a2dc34) par tests/lune/tools/dump-definition.luau. Jamais livré dans le jeu.
return {
    Aids = {
        Abs = true,
        StabilityControl = false,
        TractionControl = true,
    },
    Appearance = {
        AccentRgb = {
            240,
            210,
            60,
        },
        BodyRgb = {
            52,
            96,
            140,
        },
        Label = "P-02 ESSAI",
        TrimRgb = {
            30,
            32,
            36,
        },
    },
    Brakes = {
        HandbrakeTorqueNm = 1400,
        MaxTorqueFrontNm = 1700,
        MaxTorqueRearNm = 600,
    },
    Chassis = {
        CgHeightM = 0.55000000000000004,
        DragAreaM2 = 0.68000000000000005,
        FrontWeightFraction = 0.60999999999999999,
        HeightM = 1.6200000000000001,
        LengthM = 4.4500000000000002,
        MassKg = 1460,
        TrackFrontM = 1.55,
        TrackRearM = 1.53,
        WheelbaseM = 2.6499999999999999,
        WidthM = 1.8200000000000001,
    },
    DisplayName = "Prototype d'essai P-02",
    Id = "proto_p02",
    IsTestPrototype = true,
    Limits = {
        ExitMaxSpeedKmh = 20,
        MaxPlausibleSpeedKmh = 240,
    },
    Powertrain = {
        Drivetrain = {
            FrontDifferential = {
                CoastLockRatio = 0,
                Kind = "Open",
                PowerLockRatio = 0,
                PreloadNm = 0,
            },
            FrontTorqueShare = 1,
            Layout = "FWD",
            RearDifferential = {
                CoastLockRatio = 0,
                Kind = "Open",
                PowerLockRatio = 0,
                PreloadNm = 0,
            },
        },
        Energy = {
            Capacity = 55,
            InitialFraction = 0.59999999999999998,
            Kind = "Diesel",
        },
        Engine = {
            BsfcGPerKWh = 215,
            EngineBrakeTorqueNm = 60,
            IdleControlTorqueNm = 40,
            IdleFuelLph = 0.59999999999999998,
            IdleRpm = 800,
            InertiaKgM2 = 0.22,
            LimiterRpm = 4700,
            PartLoadPenalty = 0.90000000000000002,
            RedlineRpm = 4500,
            StallRpm = 450,
            TorqueCurve = {
                {
                    Rpm = 1000,
                    TorqueNm = 180,
                },
                {
                    Rpm = 1500,
                    TorqueNm = 280,
                },
                {
                    Rpm = 2000,
                    TorqueNm = 320,
                },
                {
                    Rpm = 2500,
                    TorqueNm = 320,
                },
                {
                    Rpm = 3000,
                    TorqueNm = 300,
                },
                {
                    Rpm = 3500,
                    TorqueNm = 270,
                },
                {
                    Rpm = 4000,
                    TorqueNm = 230,
                },
                {
                    Rpm = 4500,
                    TorqueNm = 180,
                },
                {
                    Rpm = 4700,
                    TorqueNm = 150,
                },
            },
        },
        Transmission = {
            Clutch = {
                MaxTorqueNm = 420,
            },
            Efficiency = 0.92000000000000004,
            FinalDrive = 3.8999999999999999,
            ForwardRatios = {
                3.73,
                2.0499999999999998,
                1.3200000000000001,
                0.96999999999999997,
                0.76000000000000001,
                0.62,
            },
            Kind = "Manual",
            LaunchRpm = 1500,
            ReverseRatio = 3.5,
            ShiftDownRpm = 1500,
            ShiftDurationS = 0,
            ShiftUpRpm = 4300,
        },
    },
    Steering = {
        HighSpeedAngleDeg = 9,
        HighSpeedReferenceKmh = 140,
        MaxAngleDeg = 34,
        RackSpeedDegPerS = 100,
    },
    Suspension = {
        ContactProbe = "Sphere",
        Front = {
            AntiRollNpm = 16000,
            BumpDampingNsPm = 2400,
            BumpStopRateNpm = 250000,
            ReboundDampingNsPm = 3900,
            RestLengthM = 0.20000000000000001,
            SpringRateNpm = 32000,
            TravelM = 0.20000000000000001,
        },
        Rear = {
            AntiRollNpm = 6000,
            BumpDampingNsPm = 2000,
            BumpStopRateNpm = 250000,
            ReboundDampingNsPm = 3200,
            RestLengthM = 0.20000000000000001,
            SpringRateNpm = 26000,
            TravelM = 0.20000000000000001,
        },
    },
    Tires = {
        LoadSensitivity = 0.12,
        PeakFrictionLateral = 0.94999999999999996,
        PeakFrictionLongitudinal = 1,
        PeakSlipAngleDeg = 7,
        PeakSlipRatio = 0.10000000000000001,
        RadiusM = 0.315,
        RelaxationLengthM = 0.40000000000000002,
        RollingResistance = 0.012,
        SlidingFrictionRatio = 0.78000000000000003,
        WetGripRatio = 0.69999999999999996,
        WetSlidingFrictionRatio = 0.68000000000000005,
        WheelInertiaKgM2 = 1.1000000000000001,
        WidthM = 0.20499999999999999,
    },
}
