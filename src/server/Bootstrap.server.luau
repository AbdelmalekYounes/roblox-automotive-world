-- Point d'entrée serveur : initialise le socle de développement puis la
-- zone d'essai du lot 0.1 et ses véhicules de test.
-- Aucun achat, attribution définitive de véhicule ou écriture DataStore.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Settings = require(Shared:WaitForChild("ProjectSettings"))

local TestZoneBuilder = require(script.Parent:WaitForChild("World"):WaitForChild("TestZoneBuilder"))
local VehicleService = require(script.Parent:WaitForChild("Vehicles"):WaitForChild("VehicleService"))

-- Des invariants simples détectent immédiatement une erreur de configuration.
assert(Settings.RequirementsVersion == "1.0", "Version du cahier des charges non conforme")
assert(Settings.LaunchVehicleModelCount == 18, "Catalogue de lancement incohérent")
assert(Settings.LaunchZoneCount == 7, "Nombre de zones incohérent")

-- La zone est construite sans attente pour exister avant l'apparition des joueurs.
local zone = TestZoneBuilder.build()
VehicleService.start(zone)

-- Cet attribut répliqué permet au client d'observer le démarrage du serveur.
-- Il n'est PAS une preuve d'autorisation pour une opération sensible.
ReplicatedStorage:SetAttribute("AutomotiveWorldReady", true)

print(
    string.format(
        "[AutomotiveWorld] Serveur de développement initialisé (v%s, cahier des charges %s)",
        Settings.DevelopmentVersion,
        Settings.RequirementsVersion
    )
)
