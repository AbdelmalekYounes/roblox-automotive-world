--!strict
--[[
    Brio (wk_brio) — citadine, définition physique AUTONOME (lot VEH3D-02, 2026-11-05).

    Décisions du propriétaire du 2026-11-05 : citadine issue du modèle tiers « Milano '95 » (Daniel Zhabotinsky,
    CC BY 4.0), nommée Brio ; essence, boîte AUTOMATIQUE, traction ; véhicule de service des métiers et achetable en
    concession (pas véhicule de départ). Valeurs générées par la règle de l'ancienne gamme (WorkingCatalog de `main`
    6a2dc34, base P-01 essence) à partir des cotes RÉELLES du modèle (longueur 3,85 m, empattement 2,42 m, roues de
    0,28 m), puis figées ici (tests/lune/tools/dump-definition.luau). Unités : SI ; hypothèses de conception, pas des
    mesures d'un véhicule réel.

    Carrosserie : kit de maillages tiers CC BY 4.0 (MeshKitData), à intégrer après l'import Studio du propriétaire.
]]

local Types = require(script.Parent.Parent.VehicleTypes)

local definition: Types.VehicleDefinition = {
    Aids = {
        Abs = true,
        StabilityControl = false,
        TractionControl = true,
    },
    Appearance = {
        AccentRgb = {
            240,
            240,
            240,
        },
        BodyRgb = {
            214,
            200,
            150,
        },
        BodyStyle = "Hatch",
        Label = "BRIO",
        TrimRgb = {
            30,
            30,
            34,
        },
    },
    Brakes = {
        HandbrakeTorqueNm = 1228.8,
        MaxTorqueFrontNm = 1075.2,
        MaxTorqueRearNm = 537.60000000000002,
    },
    Chassis = {
        CgHeightM = 0.5,
        DragAreaM2 = 0.62,
        FrontWeightFraction = 0.62,
        HeightM = 1.4399999999999999,
        LengthM = 3.8500000000000001,
        MassKg = 960,
        TrackFrontM = 1.3799999999999999,
        TrackRearM = 1.3999999999999999,
        WheelbaseM = 2.4199999999999999,
        WidthM = 1.6399999999999999,
    },
    DisplayName = "Brio",
    Id = "wk_brio",
    IsTestPrototype = false,
    Limits = {
        ExitMaxSpeedKmh = 20,
        MaxPlausibleSpeedKmh = 206,
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
            Capacity = 45,
            InitialFraction = 0.59999999999999998,
            Kind = "Petrol",
        },
        Engine = {
            BsfcGPerKWh = 250,
            EngineBrakeTorqueNm = 27,
            IdleControlTorqueNm = 15,
            IdleFuelLph = 0.80000000000000004,
            IdleRpm = 850,
            InertiaKgM2 = 0.089999999999999997,
            LimiterRpm = 7200,
            PartLoadPenalty = 1.2,
            RedlineRpm = 7000,
            StallRpm = 450,
            TorqueCurve = {
                {
                    Rpm = 1000,
                    TorqueNm = 53,
                },
                {
                    Rpm = 2000,
                    TorqueNm = 73,
                },
                {
                    Rpm = 3000,
                    TorqueNm = 84,
                },
                {
                    Rpm = 4000,
                    TorqueNm = 90,
                },
                {
                    Rpm = 5000,
                    TorqueNm = 92,
                },
                {
                    Rpm = 6000,
                    TorqueNm = 86,
                },
                {
                    Rpm = 6800,
                    TorqueNm = 77,
                },
                {
                    Rpm = 7200,
                    TorqueNm = 71,
                },
            },
        },
        Transmission = {
            Converter = {
                LockupGear = 3,
                StallRpm = 2510,
                StallTorqueRatio = 2,
            },
            Efficiency = 0.88,
            FinalDrive = 3.8999999999999999,
            ForwardRatios = {
                3.3999999999999999,
                2.1000000000000001,
                1.5,
                1.1499999999999999,
                0.92000000000000004,
                0.76000000000000001,
            },
            Kind = "Automatic",
            LaunchRpm = 3002,
            ReverseRatio = 3.2999999999999998,
            ShiftDownRpm = 2856,
            ShiftDurationS = 0.25,
            ShiftUpRpm = 6800,
        },
    },
    Steering = {
        HighSpeedAngleDeg = 9,
        HighSpeedReferenceKmh = 140,
        MaxAngleDeg = 35,
        RackSpeedDegPerS = 110,
    },
    Suspension = {
        ContactProbe = "Sphere",
        Front = {
            AntiRollNpm = 12577.811320754718,
            BumpDampingNsPm = 2066.3547169811322,
            BumpStopRateNpm = 250000,
            ReboundDampingNsPm = 3234.2943396226419,
            RestLengthM = 0.20000000000000001,
            SpringRateNpm = 30096.905660377361,
            TravelM = 0.20000000000000001,
        },
        Rear = {
            AntiRollNpm = 5588.4255319148933,
            BumpDampingNsPm = 1366.059574468085,
            BumpStopRateNpm = 250000,
            ReboundDampingNsPm = 2111.1829787234042,
            RestLengthM = 0.20000000000000001,
            SpringRateNpm = 20490.893617021276,
            TravelM = 0.20000000000000001,
        },
    },
    Tires = {
        LoadSensitivity = 0.10000000000000001,
        PeakFrictionLateral = 0.97999999999999998,
        PeakFrictionLongitudinal = 1.0289999999999999,
        PeakSlipAngleDeg = 7,
        PeakSlipRatio = 0.10000000000000001,
        RadiusM = 0.28000000000000003,
        RelaxationLengthM = 0.34999999999999998,
        RollingResistance = 0.012999999999999999,
        SlidingFrictionRatio = 0.80000000000000004,
        WetGripRatio = 0.71999999999999997,
        WetSlidingFrictionRatio = 0.69999999999999996,
        WheelInertiaKgM2 = 0.74781976744186063,
        WidthM = 0.17499999999999999,
    },
}

return definition
