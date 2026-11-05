--!strict
-- Notices du véhicule (lots 0.1–0.2), indexées par les clés envoyées par le
-- serveur. Lot 0.7 : textes FR/EN centralisés dans Shared/UI/Localization ;
-- ce module garde son interface d'origine (format « %d / %s »).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Localization = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Localization"))

local Messages = {}

-- Même clé côté serveur, texte propre à la notice du véhicule.
local ALIASES: { [string]: string } = { MovementCorrected = "VehicleMovementCorrected" }

function Messages.format(key: string, value: any): string
    return Localization.format(ALIASES[key] or key, value)
end

return Messages
