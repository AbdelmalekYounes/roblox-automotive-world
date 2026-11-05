-- Point d'entrée serveur. Selon la place (ReplicatedStorage.PlaceConfig) :
-- - « Dev » (default.project.json) : zone d'essai des lots 0.1 et 0.2 ;
-- - « OpenWorld » (openworld.project.json) : carte générée du lot 0.3, parc des
--   prototypes, météo et horloge, trafic PNJ.
-- Aucun achat, attribution définitive de véhicule ou écriture DataStore.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Settings = require(Shared:WaitForChild("ProjectSettings"))
local PlaceConfig = require(ReplicatedStorage:WaitForChild("PlaceConfig")) :: { Mode: string }

local WorldFolder = script.Parent:WaitForChild("World")
local TestZoneBuilder = require(WorldFolder:WaitForChild("TestZoneBuilder"))
local OpenWorldService = require(WorldFolder:WaitForChild("OpenWorldService"))
local WeatherService = require(WorldFolder:WaitForChild("WeatherService"))
local TrafficService = require(WorldFolder:WaitForChild("TrafficService"))
local ProfileService = require(script.Parent:WaitForChild("Persistence"):WaitForChild("ProfileService"))
local ProgressionService = require(script.Parent:WaitForChild("Progression"):WaitForChild("ProgressionService"))
local EconomyService = require(script.Parent:WaitForChild("Economy"):WaitForChild("EconomyService"))
local VehicleService = require(script.Parent:WaitForChild("Vehicles"):WaitForChild("VehicleService"))

-- Des invariants simples détectent immédiatement une erreur de configuration.
assert(Settings.RequirementsVersion == "1.0", "Version du cahier des charges non conforme")
assert(Settings.LaunchVehicleModelCount == 18, "Catalogue de lancement incohérent")
assert(Settings.LaunchZoneCount == 7, "Nombre de zones incohérent")

if PlaceConfig.Mode == "OpenWorld" then
    -- La carte est déjà dans la place (générée hors ligne) : rien à construire.
    local world = OpenWorldService.start()
    VehicleService.start(world)
    WeatherService.start()
    TrafficService.start()
    ProgressionService.start(world.Root, nil)
    EconomyService.start(true, world.Root, nil)
else
    -- La zone est construite sans attente pour exister avant l'apparition des joueurs.
    local zone = TestZoneBuilder.build()
    VehicleService.start(zone)
    ProgressionService.start(nil, zone)
    EconomyService.start(false, nil, zone)
end
-- Profils (lot 0.4) : après les services qui écoutent leur cycle de vie.
ProfileService.start()
ReplicatedStorage:SetAttribute("AutomotiveWorldMode", PlaceConfig.Mode)

-- Cet attribut répliqué permet au client d'observer le démarrage du serveur.
-- Il n'est PAS une preuve d'autorisation pour une opération sensible.
ReplicatedStorage:SetAttribute("AutomotiveWorldReady", true)

print(
    string.format(
        "[AutomotiveWorld] Serveur initialisé (%s, v%s, cahier des charges %s)",
        PlaceConfig.Mode,
        Settings.DevelopmentVersion,
        Settings.RequirementsVersion
    )
)
