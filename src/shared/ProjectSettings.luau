-- Paramètres contractuels issus du cahier des charges global v1.0.
-- Cette table ne contient aucun état joueur ni secret serveur.

local Settings = {
    InternalProjectName = "AutomotiveWorld",
    DevelopmentVersion = "0.0.1",
    RequirementsVersion = "1.0",
    LaunchZoneCount = 7,
    LaunchVehicleModelCount = 18,
    StarterModelChoiceCount = 3,
    MaximumPlayersTarget = 24,
    TargetFps = 60,
    TargetFrameTimeMs = {
        Median = 16.67,
        P95 = 20,
        P99 = 33.3,
    },
}

-- On fige les valeurs de contrat communes au client et au serveur.
-- Les tables imbriquées sont figées séparément.
table.freeze(Settings.TargetFrameTimeMs)
return table.freeze(Settings)
