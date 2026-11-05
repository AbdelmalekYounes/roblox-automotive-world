--!strict
--[[
    Modules privés de garage et capacités des lieux de préparation (§4.3).

    Le cahier des charges prévoit des « modules privés optionnels installables
    dans les garages des propriétés compatibles, selon les catégories
    prévues » sans en donner la liste dans le dossier consolidé. Les HUIT
    catégories ci-dessous sont donc une PROPOSITION à arbitrer par le
    propriétaire (docs/lot-0.4/RAPPORT_LOT_0.4.md) ; l'architecture accepte
    toute autre liste sans changement de code ailleurs.

    Aucun module n'est achetable dans ce lot : l'achat, l'activation et la
    revente (60 %, §4.1) relèvent de l'économie (lot 0.5).

    Capacités : ce qu'un lieu permet de faire sur un véhicule. Les trois
    garages publics offrent la préparation complète ; un garage privé sans
    module permet le rangement, l'exposition, la consultation et l'application
    de configurations déjà réalisables (sans échange de pièces). Les garages
    publics restent ainsi indispensables (pose et dépose de pièces).
]]

local GarageModules = {}

export type Capability =
    "Store" -- ranger, exposer, sortir un véhicule
    | "ViewState" -- consulter l'état mécanique
    | "ApplyConfiguration" -- appliquer réglages et esthétique d'une configuration
    | "EditTuning" -- modifier les réglages mécaniques
    | "EditCosmetics" -- modifier l'apparence
    | "SwapParts" -- poser / déposer des pièces
    | "Repair" -- réparer (payant, lot 0.5)

export type Module = {
    Id: string,
    Label: string,
    Grants: { Capability },
    Proposal: boolean, -- vrai : catégorie proposée, non arbitrée
}

local function module(id: string, label: string, grants: { Capability }): Module
    return table.freeze({ Id = id, Label = label, Grants = table.freeze(grants), Proposal = true })
end

local MODULES: { Module } = {
    module("Workshop", "Atelier de réglage", { "EditTuning" }),
    module("PaintBooth", "Cabine d'esthétique", { "EditCosmetics" }),
    module("Lift", "Pont et diagnostic", {}),
    module("PartsStorage", "Rangement de pièces", {}),
    module("Charging", "Borne privée (recharge payante)", {}),
    module("WashBay", "Aire de lavage", {}),
    module("Showroom", "Éclairage d'exposition", {}),
    module("Lounge", "Salon des visiteurs", {}),
}
GarageModules.Modules = table.freeze(MODULES)
GarageModules.CategoryCount = #MODULES

local byId: { [string]: Module } = {}
for _, item in MODULES do
    byId[item.Id] = item
end

function GarageModules.get(id: string): Module?
    return byId[id]
end

local PRIVATE_BASE: { Capability } = { "Store", "ViewState", "ApplyConfiguration" }
local PUBLIC_GARAGE: { Capability } =
    { "ViewState", "ApplyConfiguration", "EditTuning", "EditCosmetics", "SwapParts", "Repair" }

-- Capacités d'un garage privé selon les modules installés.
function GarageModules.privateCapabilities(installed: { [string]: any }): { [string]: boolean }
    local result: { [string]: boolean } = {}
    for _, capability in PRIVATE_BASE do
        result[capability] = true
    end
    for id in installed do
        local item = byId[id]
        if item then
            for _, capability in item.Grants do
                result[capability] = true
            end
        end
    end
    return result
end

-- Capacités d'un garage public (préparation complète, §4.3). Le rangement
-- n'y est pas proposé : la collection se range dans les propriétés.
function GarageModules.publicCapabilities(): { [string]: boolean }
    local result: { [string]: boolean } = {}
    for _, capability in PUBLIC_GARAGE do
        result[capability] = true
    end
    return result
end

return table.freeze(GarageModules)
