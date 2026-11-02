--!strict
-- Contrats de types partagés de la simulation automobile.
-- Ce module ne contient AUCUNE logique : uniquement des types Luau.
--
-- Unités : système international (mètres, kilogrammes, newtons, secondes,
-- radians, tr/min) sauf mention contraire dans le nom du champ.
-- La conversion vers les « studs » Roblox est faite uniquement dans
-- l'adaptateur `VehicleSimulator`, jamais dans la dynamique pure.

-- Familles prévues par le cahier des charges (chapitre 3.2).
-- Seules les valeurs acceptées par `VehicleDefinitions.validate` sont
-- réellement implémentées ; les autres sont des points d'extension déclarés.
export type PowertrainKind = "Combustion" | "Electric"
export type TransmissionKind = "Automatic" | "Manual" | "DualClutch" | "Sequential" | "CVT" | "SingleSpeed"
export type DrivetrainLayout = "FWD" | "RWD" | "AWD"

export type TorquePoint = {
    Rpm: number,
    TorqueNm: number,
}

export type EngineDefinition = {
    IdleRpm: number,
    RedlineRpm: number,
    LimiterRpm: number,
    -- Régime maximal atteint par l'embrayage/convertisseur simplifié au démarrage.
    ClutchLaunchRpm: number,
    InertiaKgM2: number,
    EngineBrakeTorqueNm: number,
    TorqueCurve: { TorquePoint },
}

export type TransmissionDefinition = {
    Kind: TransmissionKind,
    ForwardRatios: { number },
    ReverseRatio: number,
    FinalDrive: number,
    Efficiency: number,
    ShiftUpRpm: number,
    ShiftDownRpm: number,
    ShiftDurationS: number,
}

export type DrivetrainDefinition = {
    Layout: DrivetrainLayout,
    -- Part du couple envoyée au train avant (0 = propulsion, 1 = traction).
    FrontTorqueShare: number,
}

export type PowertrainDefinition = {
    Kind: PowertrainKind,
    Engine: EngineDefinition,
    Transmission: TransmissionDefinition,
    Drivetrain: DrivetrainDefinition,
}

export type AxleSuspension = {
    -- Longueur libre du ressort (débattement en détente totale).
    RestLengthM: number,
    TravelM: number,
    SpringRateNpm: number,
    BumpDampingNsPm: number,
    ReboundDampingNsPm: number,
    AntiRollNpm: number,
    BumpStopRateNpm: number,
}

export type SuspensionDefinition = {
    Front: AxleSuspension,
    Rear: AxleSuspension,
}

export type TireDefinition = {
    RadiusM: number,
    WidthM: number,
    WheelInertiaKgM2: number,
    PeakFrictionLongitudinal: number,
    PeakFrictionLateral: number,
    -- Fraction de l'adhérence maximale conservée en glissement franc.
    SlidingFrictionRatio: number,
    PeakSlipRatio: number,
    PeakSlipAngleDeg: number,
    LoadSensitivity: number,
    RollingResistance: number,
}

export type BrakeDefinition = {
    MaxTorqueFrontNm: number,
    MaxTorqueRearNm: number,
    HandbrakeTorqueNm: number,
}

export type SteeringDefinition = {
    MaxAngleDeg: number,
    -- Angle maximal commandable à haute vitesse (filtre de commande déclaré,
    -- identique pour tous les périphériques ; ce n'est pas une aide de stabilité).
    HighSpeedAngleDeg: number,
    HighSpeedReferenceKmh: number,
    RackSpeedDegPerS: number,
}

export type ChassisDefinition = {
    MassKg: number,
    LengthM: number,
    WidthM: number,
    HeightM: number,
    WheelbaseM: number,
    TrackFrontM: number,
    TrackRearM: number,
    CgHeightM: number,
    FrontWeightFraction: number,
    -- Surface frontale multipliée par le coefficient de traînée (Cx·S).
    DragAreaM2: number,
}

-- Aides à la conduite : présentes uniquement si le modèle en dispose
-- (cahier des charges §1.2). Aucune n'est implémentée dans le lot 0.1.
export type DriverAids = {
    Abs: boolean,
    TractionControl: boolean,
    StabilityControl: boolean,
}

export type VehicleLimits = {
    -- Vitesse maximale plausible utilisée par la validation serveur.
    MaxPlausibleSpeedKmh: number,
    ExitMaxSpeedKmh: number,
}

export type VehicleAppearance = {
    BodyRgb: { number },
    AccentRgb: { number },
    TrimRgb: { number },
    Label: string,
}

export type VehicleDefinition = {
    Id: string,
    DisplayName: string,
    IsTestPrototype: boolean,
    Chassis: ChassisDefinition,
    Suspension: SuspensionDefinition,
    Tires: TireDefinition,
    Brakes: BrakeDefinition,
    Steering: SteeringDefinition,
    Powertrain: PowertrainDefinition,
    Aids: DriverAids,
    Limits: VehicleLimits,
    Appearance: VehicleAppearance,
}

-- Intention du conducteur, normalisée et indépendante du périphérique.
export type DriverInput = {
    Throttle: number, -- 0..1 (touche/gâchette « accélérer »)
    Brake: number, -- 0..1 (touche/gâchette « freiner / reculer »)
    Steer: number, -- -1 (gauche) .. 1 (droite)
    Handbrake: boolean,
}

-- Contact d'une roue avec le sol, exprimé dans le repère de la roue.
export type WheelContact = {
    Grounded: boolean,
    Compression: number, -- m, 0 = détente totale
    CompressionVelocity: number, -- m/s, positive quand la suspension se comprime
    LongitudinalVelocity: number, -- m/s, vitesse du point de contact selon l'axe de la roue
    LateralVelocity: number, -- m/s, positive vers la droite de la roue
    SurfaceFriction: number, -- multiplicateur d'adhérence du revêtement
}

-- Efforts calculés pour une roue (repère de contact, newtons).
export type WheelForces = {
    Normal: number,
    Longitudinal: number,
    Lateral: number,
}

export type WheelRuntime = {
    Index: number,
    IsFront: boolean,
    Side: number, -- -1 gauche, +1 droite
    DriveShare: number, -- part du couple moteur reçue par cette roue
    AngularVelocity: number, -- rad/s, positive en marche avant
    SpinAngle: number, -- rad, pour l'affichage
    SteerAngle: number, -- rad, positif vers la droite
    Compression: number, -- m
    SlipRatio: number,
}

export type VehicleRuntimeState = {
    Wheels: { WheelRuntime },
    Gear: number, -- -1 marche arrière, 0 neutre, 1..n rapports avant
    EngineRpm: number,
    ShiftTimer: number,
    DirectionRequestTimer: number,
    SteerPosition: number, -- -1..1 après limitation de vitesse de crémaillère
    DriveThrottle: number,
    BrakePedal: number,
}

return {}
