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
    }),

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
    }),

    -- Ordre canonique des roues : avant gauche, avant droite, arrière gauche, arrière droite.
    WheelNames = table.freeze({ "FL", "FR", "RL", "RR" }),

    -- Fréquence d'envoi des commandes au serveur (affichage des autres clients).
    InputSendRateHz = 15,
}

return table.freeze(VehicleConstants)
