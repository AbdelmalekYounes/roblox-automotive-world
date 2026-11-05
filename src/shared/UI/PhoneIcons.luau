--!strict
--[[
    Icônes des 12 applications du téléphone (lot UI-02), module PUR. Images PNG blanches produites par
    `tools/ui/make_phone_icons.py` (manifeste : `ui.icon.phone.<app>`, en minuscules), teintées dans le jeu par ImageColor3 : ambre, cyan
    pour la carte (maquette « Design System V1.2 » §5).

    Les identifiants Roblox (manifeste, entrées `ui.icon.phone.<app>`) n'existent qu'après l'envoi des images par le
    propriétaire : tant qu'un identifiant vaut nil, le téléphone affiche un cadre vide à la place de l'icône (jamais un caractère Unicode : règle de la maquette).
]]

local AssetManifest = require(script.Parent.Parent.Assets.AssetManifest)

local PhoneIcons = {}

PhoneIcons.Apps = table.freeze({
    "Map",
    "Vehicles",
    "Properties",
    "Missions",
    "Races",
    "Market",
    "Social",
    "Radio",
    "Photo",
    "Guide",
    "Settings",
    "Notifications",
})

-- Jeton de couleur de l'icône (DesignTokens).
function PhoneIcons.tint(app: string): string
    return if app == "Map" then "GpsCyan" else "Amber"
end

-- Contenu d'image de l'icône, ou nil si elle n'est pas encore envoyée sur Roblox.
function PhoneIcons.image(app: string): string?
    return AssetManifest.contentId("ui.icon.phone." .. string.lower(app))
end

return table.freeze(PhoneIcons)
