-- Point d'entrée serveur : initialise uniquement le socle de développement.
-- Aucun achat, attribution de véhicule ou écriture DataStore à cette étape.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Settings = require(Shared:WaitForChild("ProjectSettings"))

-- Des invariants simples détectent immédiatement une erreur de configuration.
assert(Settings.RequirementsVersion == "1.0", "Version du cahier des charges non conforme")
assert(Settings.LaunchVehicleModelCount == 18, "Catalogue de lancement incohérent")
assert(Settings.LaunchZoneCount == 7, "Nombre de zones incohérent")

-- Cet attribut répliqué permet au client d'observer le démarrage du serveur.
-- Il n'est PAS une preuve d'autorisation pour une opération sensible.
ReplicatedStorage:SetAttribute("AutomotiveWorldReady", true)

print(string.format(
    "[AutomotiveWorld] Serveur de développement initialisé (v%s, cahier des charges %s)",
    Settings.DevelopmentVersion,
    Settings.RequirementsVersion
))
