--!strict
-- Définition du « Prototype d'essai P-02 » (lot 0.2).
--
-- Véhicule 100 % fictif : break compact à traction avant, moteur diesel et
-- boîte manuelle à six rapports avec embrayage. Plus lourd que le P-01, avant
-- très chargé, couple élevé à bas régime et plage de régime courte. Ce n'est
-- NI un modèle du catalogue de lancement, NI une option de départ gratuite.
-- Toutes les valeurs sont des hypothèses de conception, aucune n'est une mesure.

local Types = require(script.Parent.Parent.VehicleTypes)

local definition: Types.VehicleDefinition = {
    Id = "proto_p02",
    DisplayName = "Prototype d'essai P-02",
    IsTestPrototype = true,

    Chassis = {
        MassKg = 1460,
        LengthM = 4.45,
        WidthM = 1.82,
        HeightM = 1.62,
        WheelbaseM = 2.65,
        TrackFrontM = 1.55,
        TrackRearM = 1.53,
        CgHeightM = 0.55,
        FrontWeightFraction = 0.61,
        DragAreaM2 = 0.68,
    },

    -- Suspension plus souple que celle du P-01 (≈ 1,4 Hz avant, 1,5 Hz arrière).
    Suspension = {
        -- Sonde de contact : balayage de sphère, retenu d'après les mesures en Studio
        -- (bordures de 12 cm : pic vertical −37 à −41 %, ≈ +7 µs par pas ; RAPPORT_LOT_0.2).
        ContactProbe = "Sphere",
        Front = {
            RestLengthM = 0.2,
            TravelM = 0.2,
            SpringRateNpm = 32000,
            BumpDampingNsPm = 2400,
            ReboundDampingNsPm = 3900,
            AntiRollNpm = 16000,
            BumpStopRateNpm = 250000,
        },
        Rear = {
            RestLengthM = 0.2,
            TravelM = 0.2,
            SpringRateNpm = 26000,
            BumpDampingNsPm = 2000,
            ReboundDampingNsPm = 3200,
            AntiRollNpm = 6000,
            BumpStopRateNpm = 250000,
        },
    },

    Tires = {
        RadiusM = 0.315,
        WidthM = 0.205,
        WheelInertiaKgM2 = 1.1,
        PeakFrictionLongitudinal = 1.0,
        PeakFrictionLateral = 0.95,
        SlidingFrictionRatio = 0.78,
        PeakSlipRatio = 0.1,
        PeakSlipAngleDeg = 7,
        LoadSensitivity = 0.12,
        RollingResistance = 0.012,
        WetGripRatio = 0.7,
        WetSlidingFrictionRatio = 0.68,
        RelaxationLengthM = 0.4,
    },

    Brakes = {
        MaxTorqueFrontNm = 1700,
        MaxTorqueRearNm = 600,
        HandbrakeTorqueNm = 1400,
    },

    Steering = {
        MaxAngleDeg = 34,
        HighSpeedAngleDeg = 9,
        HighSpeedReferenceKmh = 140,
        RackSpeedDegPerS = 100,
    },

    Powertrain = {
        Energy = {
            Kind = "Diesel",
            Capacity = 55, -- litres
            InitialFraction = 0.6,
        },
        Engine = {
            IdleRpm = 800,
            RedlineRpm = 4500,
            LimiterRpm = 4700,
            StallRpm = 450,
            InertiaKgM2 = 0.22,
            EngineBrakeTorqueNm = 60,
            IdleControlTorqueNm = 40,
            -- Couple maximal dès 2 000 tr/min, chute rapide au-delà de 3 500.
            TorqueCurve = {
                { Rpm = 1000, TorqueNm = 180 },
                { Rpm = 1500, TorqueNm = 280 },
                { Rpm = 2000, TorqueNm = 320 },
                { Rpm = 2500, TorqueNm = 320 },
                { Rpm = 3000, TorqueNm = 300 },
                { Rpm = 3500, TorqueNm = 270 },
                { Rpm = 4000, TorqueNm = 230 },
                { Rpm = 4500, TorqueNm = 180 },
                { Rpm = 4700, TorqueNm = 150 },
            },
            -- Meilleur rendement que l'essence, pénalité de charge partielle plus faible.
            BsfcGPerKWh = 215,
            PartLoadPenalty = 0.9,
            IdleFuelLph = 0.6,
        },
        Transmission = {
            Kind = "Manual",
            ForwardRatios = { 3.73, 2.05, 1.32, 0.97, 0.76, 0.62 },
            ReverseRatio = 3.5,
            FinalDrive = 3.9,
            Efficiency = 0.92,
            -- Seuils non utilisés (passages par le conducteur), gardés cohérents.
            ShiftUpRpm = 4300,
            ShiftDownRpm = 1500,
            ShiftDurationS = 0,
            LaunchRpm = 1500,
            Clutch = {
                MaxTorqueNm = 420,
            },
        },
        Drivetrain = {
            Layout = "FWD",
            FrontTorqueShare = 1,
            FrontDifferential = { Kind = "Open", PreloadNm = 0, PowerLockRatio = 0, CoastLockRatio = 0 },
            RearDifferential = { Kind = "Open", PreloadNm = 0, PowerLockRatio = 0, CoastLockRatio = 0 },
        },
    },

    -- Équipé de l'ABS et de l'antipatinage (désactivés par défaut), sans ESP.
    Aids = {
        Abs = true,
        TractionControl = true,
        StabilityControl = false,
    },

    Limits = {
        MaxPlausibleSpeedKmh = 240,
        ExitMaxSpeedKmh = 20,
    },

    Appearance = {
        BodyRgb = { 52, 96, 140 },
        AccentRgb = { 240, 210, 60 },
        TrimRgb = { 30, 32, 36 },
        Label = "P-02 ESSAI",
    },
}

return definition
