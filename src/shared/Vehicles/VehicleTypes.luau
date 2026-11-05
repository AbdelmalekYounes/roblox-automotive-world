--!strict
-- Contrats de types partagés de la simulation automobile.
-- Ce module ne contient AUCUNE logique : uniquement des types Luau.
--
-- Unités : système international (mètres, kilogrammes, newtons, secondes,
-- radians, tr/min) sauf mention contraire dans le nom du champ.
-- La conversion vers les « studs » Roblox est faite uniquement dans
-- l'adaptateur `VehicleSimulator`, jamais dans la dynamique pure.

-- Familles prévues par le cahier des charges (chapitre 3.2). Toutes sont
-- implémentées depuis le lot 0.2 ; `VehicleDefinitions.validate` vérifie la
-- cohérence de chaque définition avec sa famille.
export type EnergyKind = "Petrol" | "Diesel" | "Electric"
export type TransmissionKind = "Automatic" | "Manual" | "DualClutch" | "Sequential" | "CVT" | "SingleSpeed"
export type DrivetrainLayout = "FWD" | "RWD" | "AWD"
export type DifferentialKind = "Open" | "LimitedSlip"
-- Sonde de contact des roues : rayon (lot 0.1) ou balayage de sphère (lot 0.2).
export type ContactProbe = "Ray" | "Sphere"

export type TorquePoint = {
    Rpm: number,
    TorqueNm: number,
}

-- Moteur thermique (essence ou diesel). Le couple de la courbe est le couple
-- NET à pleine charge ; à charge partielle il est mélangé au couple de
-- frottement/pompage (`EngineBrakeTorqueNm`, atteint à la zone rouge).
export type CombustionEngineDefinition = {
    IdleRpm: number,
    RedlineRpm: number,
    -- Rupteur : coupure d'injection au-delà de ce régime.
    LimiterRpm: number,
    -- En dessous de ce régime, un moteur entraîné (embrayage fermé) cale.
    StallRpm: number,
    InertiaKgM2: number,
    EngineBrakeTorqueNm: number,
    -- Couple maximal que la régulation de ralenti peut ajouter (N·m).
    IdleControlTorqueNm: number,
    TorqueCurve: { TorquePoint },
    -- Consommation spécifique au meilleur rendement (g/kWh) et surconsommation
    -- relative à très faible charge (0 = aucune, 1 = doublement).
    BsfcGPerKWh: number,
    PartLoadPenalty: number,
    -- Débit au ralenti (L/h) ; croît avec le régime (frottements, pompage).
    IdleFuelLph: number,
}

-- Moteur électrique : couple constant jusqu'à la vitesse de base (= puissance
-- maximale / couple maximal), puis puissance constante, jusqu'au régime maximal.
export type ElectricMotorDefinition = {
    MaxTorqueNm: number,
    MaxPowerKw: number,
    MaxRpm: number,
    InertiaKgM2: number,
    -- Vitesse maximale limitée électroniquement (constructeur, pas une aide).
    TopSpeedKmh: number,
    DriveEfficiency: number,
    RegenMaxPowerKw: number,
    RegenMaxTorqueNm: number,
    RegenEfficiency: number,
    -- Niveaux de récupération au lâcher d'accélérateur (fraction de la capacité
    -- de récupération) ; le premier est le niveau par défaut. Le freinage au
    -- pied récupère toujours dans la limite de la capacité (freinage combiné).
    RegenLevels: { number },
    -- Consommation des équipements (électronique, ventilation) pendant la conduite (kW).
    AuxPowerKw: number,
}

-- Réserve d'énergie : litres (essence, diesel) ou kWh (électrique).
export type EnergyStoreDefinition = {
    Kind: EnergyKind,
    Capacity: number,
    -- Niveau au début d'une session technique (aucune persistance avant le lot 0.4).
    InitialFraction: number,
}

-- Arbitrage A3 : façon d'engager la marche arrière, propre à chaque famille de
-- boîte. « HoldBrakeAtStop » (maintien de « freiner » à l'arrêt) pour les boîtes
-- sans sélecteur (automatique, CVT, rapport unique) ; « Selector » pour les
-- boîtes manuelle, double embrayage et séquentielle (rétrograder depuis le
-- neutre, véhicule arrêté).
export type ReverseEngagement = "HoldBrakeAtStop" | "Selector"

-- Commandes de sélecteur (lot 0.2 : montée et descente câblées au clavier et à
-- la manette ; la marche arrière et le neutre s'atteignent par descente).
export type GearSelectorCommand = "ShiftUp" | "ShiftDown" | "SelectReverse" | "SelectNeutral" | "SelectDrive"

-- Embrayage à friction (manuelle, double embrayage, séquentielle, CVT au démarrage).
export type ClutchDefinition = {
    MaxTorqueNm: number,
}

-- Convertisseur de couple simplifié (boîte automatique).
export type ConverterDefinition = {
    -- Régime moteur atteint à pleine charge, turbine bloquée (« calage »).
    StallRpm: number,
    -- Multiplication de couple turbine bloquée (≈ 1,8 à 2,2).
    StallTorqueRatio: number,
    -- Rapport à partir duquel l'embrayage de pontage peut se fermer.
    LockupGear: number,
}

-- Variateur continu : rapport entre ForwardRatios[1] (court) et [2] (long).
export type CvtDefinition = {
    -- Régime moteur visé à charge nulle puis à pleine charge.
    CruiseRpm: number,
    PowerRpm: number,
    -- Vitesse maximale de variation du rapport (unités de rapport par seconde).
    RatioRatePerS: number,
}

export type TransmissionDefinition = {
    Kind: TransmissionKind,
    -- CVT : { rapport le plus court, rapport le plus long }.
    ForwardRatios: { number },
    ReverseRatio: number,
    FinalDrive: number,
    Efficiency: number,
    -- Seuils des passages automatiques (automatique, double embrayage).
    ShiftUpRpm: number,
    ShiftDownRpm: number,
    -- Durée de coupure de couple pendant un passage (0 pour la manuelle : c'est
    -- l'embrayage du conducteur qui découple).
    ShiftDurationS: number,
    -- Régime visé par l'embrayage automatisé au démarrage (double embrayage,
    -- séquentielle, CVT) à pleine charge.
    LaunchRpm: number,
    Clutch: ClutchDefinition?,
    Converter: ConverterDefinition?,
    Cvt: CvtDefinition?,
}

-- Différentiel : ouvert ou autobloquant à friction (couple de blocage =
-- précharge + fraction du couple d'entrée, différente en traction et en
-- retenue moteur).
export type DifferentialDefinition = {
    Kind: DifferentialKind,
    PreloadNm: number,
    PowerLockRatio: number,
    CoastLockRatio: number,
}

export type DrivetrainDefinition = {
    Layout: DrivetrainLayout,
    -- Part du couple envoyée au train avant (0 = propulsion, 1 = traction).
    FrontTorqueShare: number,
    FrontDifferential: DifferentialDefinition,
    RearDifferential: DifferentialDefinition,
    -- Transmission intégrale seulement : couplage entre les deux essieux.
    CenterDifferential: DifferentialDefinition?,
}

export type PowertrainDefinition = {
    Energy: EnergyStoreDefinition,
    -- Exactement l'un des deux selon `Energy.Kind` (vérifié par la validation).
    Engine: CombustionEngineDefinition?,
    Motor: ElectricMotorDefinition?,
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
    ContactProbe: ContactProbe,
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
    -- Revêtement mouillé : adhérence maximale et glissement franc relatifs au sec.
    WetGripRatio: number,
    WetSlidingFrictionRatio: number,
    -- Longueur de relaxation latérale (m) : la force latérale s'établit sur
    -- cette distance parcourue (0 = instantanée).
    RelaxationLengthM: number,
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
    -- Arbitrage A1 : l'angle maximal décroît LINÉAIREMENT avec la seule vitesse
    -- (aucune mesure de glissement, de lacet ni de dérive), jusqu'à cette vitesse.
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

-- Équipements d'aide à la conduite PRÉSENTS sur le modèle (cahier des charges
-- §1.2). Une aide absente n'existe pas ; une aide présente est désactivée par
-- défaut et s'active à la demande du conducteur.
export type DriverAids = {
    Abs: boolean,
    TractionControl: boolean,
    StabilityControl: boolean,
}

export type AidName = "Abs" | "TractionControl" | "StabilityControl"

-- État d'activation des aides pendant une session (tout à false au départ).
export type AidsState = {
    Abs: boolean,
    TractionControl: boolean,
    StabilityControl: boolean,
}

export type VehicleLimits = {
    -- Vitesse maximale plausible utilisée par la validation serveur.
    MaxPlausibleSpeedKmh: number,
    -- Arbitrage A4 : seuil PROVISOIRE (20 km/h), à confirmer par des essais
    -- humains ; validé par le serveur, jamais par le client.
    ExitMaxSpeedKmh: number,
}

export type VehicleAppearance = {
    BodyRgb: { number },
    AccentRgb: { number },
    TrimRgb: { number },
    Label: string,
    -- Lot 0.8 : silhouette construite par VehicleFactory (absente : prototype technique).
    BodyStyle: string?,
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
    -- 0..1 : pédale d'embrayage enfoncée (1 = moteur découplé). Lue seulement
    -- par la boîte manuelle.
    Clutch: number,
}

-- Contact d'une roue avec le sol, exprimé dans le repère de la roue.
export type WheelContact = {
    Grounded: boolean,
    Compression: number, -- m, 0 = détente totale
    CompressionVelocity: number, -- m/s, positive quand la suspension se comprime
    LongitudinalVelocity: number, -- m/s, vitesse du point de contact selon l'axe de la roue
    LateralVelocity: number, -- m/s, positive vers la droite de la roue
    SurfaceFriction: number, -- multiplicateur d'adhérence du revêtement
    Wet: boolean, -- revêtement mouillé par conception (attribut AWWet)
    -- Humidité de chaussée due à la météo (0 = sèche, 1 = détrempée). Combinée
    -- à `Wet` par maximum : la réduction d'adhérence n'est appliquée qu'une fois.
    Wetness: number?,
}

-- Mouvement du châssis vu par la dynamique (repère véhicule).
export type ChassisMotion = {
    Forward: number, -- m/s
    Lateral: number, -- m/s, positive vers la droite
    YawRate: number, -- rad/s, positive en tournant vers la droite
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
    DriveShare: number, -- part du couple moteur reçue par cette roue (différentiels ouverts)
    AngularVelocity: number, -- rad/s, positive en marche avant
    SpinAngle: number, -- rad, pour l'affichage
    SteerAngle: number, -- rad, positif vers la droite
    Compression: number, -- m
    SlipRatio: number,
    SlipAngle: number, -- rad
    -- Frottement statique : déplacement élastique du contact (m) quand la roue adhère à l'arrêt.
    StickLongitudinal: number,
    StickLateral: number,
    -- Force latérale retardée (relaxation), N.
    LateralForce: number,
    -- Dernier couple de frein appliqué (N·m), pour l'affichage et les tests.
    BrakeTorque: number,
    -- ABS : fraction de la pression de freinage conservée (1 = aucune intervention).
    AbsFactor: number,
    -- ESP : couple de freinage ajouté par le contrôle de stabilité (N·m).
    EscBrakeTorque: number,
}

-- Conséquences mécaniques des dégâts (1 = intact). Fournies par l'adaptateur
-- (lues dans les attributs écrits par le serveur), jamais décidées par le client.
export type VehicleCondition = {
    EnginePower: number, -- multiplicateur du couple moteur
    SteeringRange: number, -- multiplicateur de l'angle de braquage
    SteeringPullRad: number, -- tirage de la direction (rad, positif à droite)
    CornerGrip: { number }, -- adhérence par roue (géométrie faussée)
    CornerToeRad: { number }, -- parallélisme faussé par roue (rad)
}

-- Indicateurs d'intervention des aides (affichage HUD, tests).
export type AidActivity = {
    Abs: boolean,
    TractionControl: boolean,
    StabilityControl: boolean,
}

export type VehicleRuntimeState = {
    Wheels: { WheelRuntime },
    Gear: number, -- -1 marche arrière, 0 neutre, 1..n rapports avant
    -- Moteur (thermique ou électrique) : vitesse de rotation en rad/s.
    EngineOmega: number,
    EngineRpm: number,
    EngineRunning: boolean,
    EngineStalled: boolean,
    StarterTimer: number,
    -- Embrayage ou pontage fermé : moteur et roues tournent ensemble.
    Coupled: boolean,
    -- Capacité courante de l'embrayage (N·m), pour l'affichage.
    ClutchCapacityNm: number,
    ClutchPedal: number,
    CvtRatio: number,
    ShiftTimer: number,
    -- Double embrayage : délai pendant lequel un passage demandé n'est pas
    -- défait par la logique automatique.
    ManualHoldTimer: number,
    DirectionRequestTimer: number,
    SteerPosition: number, -- -1..1 après limitation de vitesse de crémaillère
    DriveThrottle: number,
    BrakePedal: number,
    -- Antipatinage : fraction du couple moteur autorisée.
    TractionFactor: number,
    Aids: AidsState,
    AidActivity: AidActivity,
    RegenLevel: number, -- indice dans Motor.RegenLevels
    -- Énergie : disponible (réserve non vide) et cumuls de la session (L ou kWh).
    EnergyAvailable: boolean,
    EnergyUsed: number,
    EnergyRecovered: number,
    -- Puissance instantanée côté réserve (kW, négative en récupération).
    PowerKw: number,
    -- Puissance mécanique du moteur (kW).
    EnginePowerKw: number,
    Condition: VehicleCondition,
}

return {}
