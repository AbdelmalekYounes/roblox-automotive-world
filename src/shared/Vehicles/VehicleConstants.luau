--!strict
-- Constantes communes au client et au serveur pour les véhicules.
-- Aucune donnée joueur ni secret : uniquement des conventions techniques.

local VehicleConstants = {
    -- Échelle retenue : 1 stud = 0,28 m (convention d'échelle avatar Roblox).
    -- Toute la dynamique est calculée en mètres puis convertie à la frontière.
    MetersPerStud = 0.28,
    -- Gravité « réelle » appliquée aux véhicules, indépendamment de
    -- Workspace.Gravity (qui reste celle des personnages).
    StandardGravity = 9.81,
    AirDensity = 1.225,

    -- Étiquette CollectionService portée par chaque véhicule d'essai.
    VehicleTag = "AWVehicle",

    RemotesFolderName = "AutomotiveWorldRemotes",
    Remotes = table.freeze({
        Action = "VehicleAction", -- RemoteEvent client → serveur (actions discrètes)
        Input = "VehicleInput", -- UnreliableRemoteEvent client → serveur (commandes)
        Notice = "VehicleNotice", -- RemoteEvent serveur → client (messages)
        -- RemoteEvent serveur → client : complément d'impulsion après une collision
        -- confirmée par le serveur. Le serveur n'écoute RIEN sur ce canal.
        Impulse = "VehicleImpulse",
    }),

    -- Actions discrètes acceptées par le serveur (liste fermée).
    Actions = table.freeze({
        Exit = "Exit",
        Unflip = "Unflip",
        -- Argument : nom de l'aide ("Abs", "TractionControl", "StabilityControl").
        -- Refusé si le modèle n'en est pas équipé.
        ToggleAid = "ToggleAid",
        -- Niveau suivant de récupération au lâcher (véhicules électriques).
        CycleRegen = "CycleRegen",
    }),

    -- Aides connues (liste fermée, validée par le serveur).
    AidNames = table.freeze({ "Abs", "TractionControl", "StabilityControl" }),

    Attributes = table.freeze({
        VehicleId = "VehicleId",
        DefinitionId = "DefinitionId",
        DriverUserId = "DriverUserId",
        -- Qui simule le véhicule : UserId du conducteur, ou 0 pour le serveur.
        -- Écrit par le serveur seulement APRÈS confirmation de la propriété réseau.
        SimulationOwnerUserId = "SimulationOwnerUserId",
        -- Position du véhicule (CFrame) vue par le serveur au moment où il confie la
        -- simulation au conducteur : le client recale sa copie locale si elle diffère.
        SimulationPivot = "SimulationPivot",
        VisualSteer = "VisualSteer",
        IsTestVehicle = "IsTestVehicle",
        PadIndex = "PadIndex",
        -- Énergie (écrite par le serveur seul) : niveau en L ou kWh, réserve vide.
        EnergyLevel = "EnergyLevel",
        EnergyEmpty = "EnergyEmpty",
        -- État des aides et de la récupération (écrits par le serveur seul, après validation).
        AidAbs = "AidAbs",
        AidTractionControl = "AidTractionControl",
        AidStabilityControl = "AidStabilityControl",
        RegenLevel = "RegenLevel",
        -- Les dégâts sont publiés en attributs « Dmg… » (voir Physics/DamageModel).
    }),

    -- Attribut d'une pièce de décor : revêtement mouillé (zone d'essai).
    WetSurfaceAttribute = "AWWet",
    -- Attribut de Workspace : humidité de chaussée due à la météo (0 à 1), écrit
    -- par le serveur seul (WeatherService, lot 0.3).
    RoadWetnessAttribute = "AWRoadWetness",

    -- Ordre canonique des roues : avant gauche, avant droite, arrière gauche, arrière droite.
    WheelNames = table.freeze({ "FL", "FR", "RL", "RR" }),

    -- Fréquence d'envoi des commandes au serveur (affichage des autres clients).
    InputSendRateHz = 15,
}

return table.freeze(VehicleConstants)
