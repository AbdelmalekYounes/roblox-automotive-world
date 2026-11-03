--!strict
-- Textes des statuts et erreurs des panneaux (lots 0.4 à 0.6), indexés par
-- les clés envoyées par le serveur. Lot 0.7 : textes FR/EN centralisés dans
-- Shared/UI/Localization ; ce module garde son interface d'origine.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Localization = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Localization"))

local ProgressionMessages = {}

function ProgressionMessages.text(key: string?): string
    return Localization.t(key)
end

return table.freeze(ProgressionMessages)
