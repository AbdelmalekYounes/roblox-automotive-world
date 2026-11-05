--!strict
--[[
    Catalogue commercial des concessions (lot 0.5), VERSIONNÉ.

    Lot BASE-01 (décision du propriétaire du 2026-11-05, écart au cahier des charges consigné dans
    docs/AMENDEMENTS_CAHIER_DES_CHARGES.md) : deux emplacements, la Comète et la future citadine ; les 17 autres
    modèles de la gamme proposée du lot 0.8 sont retirés. Statuts :
    - « PendingApproval » / « Working » : proposition ou modèle de travail,
      achetable seulement en environnement de développement ;
    - « Reserved » : emplacement d'un modèle officiel à venir, jamais achetable ;
    - « Official » : modèle validé par le propriétaire (aucun aujourd'hui),
      achetable dans tous les environnements.
    Prix : hypothèses de travail.
]]

local VehicleCatalog = {}

VehicleCatalog.Version = "veh3d-02"

export type Availability = "PendingApproval" | "Working" | "Reserved" | "Official"

export type Entry = {
    Slot: number,
    Id: string,
    DefinitionId: string?,
    Name: string,
    Category: string,
    Price: number, -- crédits, prix neuf
    Availability: Availability,
    Dealers: { string }, -- concessions physiques (identifiants de la carte)
}

-- Lot BASE-01 (décision du propriétaire du 2026-11-05) : la Comète, puis la citadine Brio (lot VEH3D-02).
local ENTRIES: { Entry } = {
    {
        Slot = 1,
        Id = "comete",
        DefinitionId = "wk_comete",
        Name = "Comète",
        Category = "Supercar",
        Price = 185_000,
        Availability = "PendingApproval",
        Dealers = { "SVC-DEALER-METRO" },
    },
    -- Lot VEH3D-02 (décision du propriétaire du 2026-11-05) : citadine achetable en concession, pas véhicule de
    -- départ. Prix : hypothèse de travail ; statut relevé à « Official » seulement sur décision du propriétaire.
    {
        Slot = 2,
        Id = "brio",
        DefinitionId = "wk_brio",
        Name = "Brio",
        Category = "Citadine",
        Price = 12_000,
        Availability = "PendingApproval",
        Dealers = { "SVC-DEALER-METRO" },
    },
}
VehicleCatalog.Entries = table.freeze(ENTRIES)
VehicleCatalog.Slots = 2 -- Comète et citadine (lot BASE-01)

local byId: { [string]: Entry } = {}
local byDefinition: { [string]: Entry } = {}
for _, entry in ENTRIES do
    byId[entry.Id] = entry
    if entry.DefinitionId then
        byDefinition[entry.DefinitionId] = entry
    end
end

function VehicleCatalog.get(id: string): Entry?
    return byId[id]
end

-- Entrée du catalogue d'un modèle (pour la reprise : prix neuf).
function VehicleCatalog.forDefinition(definitionId: string): Entry?
    return byDefinition[definitionId]
end

--[[
    Achetable dans cet environnement ? Les modèles de travail ne le sont qu'en
    développement : aucune référence provisoire ne peut entrer dans un profil
    de test ou de production.
]]
function VehicleCatalog.purchasable(entry: Entry, environment: string): boolean
    if entry.Availability == "Official" then
        return entry.DefinitionId ~= nil
    end
    return (entry.Availability == "Working" or entry.Availability == "PendingApproval")
        and environment == "Dev"
        and entry.DefinitionId ~= nil
end

return table.freeze(VehicleCatalog)
