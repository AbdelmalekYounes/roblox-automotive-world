--!strict
--[[
    Catalogue commercial des concessions (lot 0.5), VERSIONNÉ.

    Dix-huit emplacements, comme le prévoit le cahier des charges :
    - « Working »  : modèle de travail PROVISOIRE (définition WorkingCatalog),
      achetable seulement en environnement de développement ;
    - « Reserved » : emplacement d'un modèle officiel à venir, jamais achetable ;
    - « Official » : modèle validé par le propriétaire (aucun aujourd'hui),
      achetable dans tous les environnements.
    Les prix sont des hypothèses de travail, non un barème validé.
    Les prototypes techniques (P-01, P-02, P-03) n'y figurent pas.
]]

local VehicleCatalog = {}

VehicleCatalog.Version = "0.5.0-travail"

export type Availability = "Working" | "Reserved" | "Official"

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

local BOTH = { "SVC-DEALER-METRO", "SVC-DEALER-BANLIEUE" }

local ENTRIES: { Entry } = {
    {
        Slot = 1,
        Id = "aster",
        DefinitionId = "wk_aster",
        Name = "Aster",
        Category = "Citadine",
        Price = 14_000,
        Availability = "Working",
        Dealers = BOTH,
    },
    {
        Slot = 2,
        Id = "brio",
        DefinitionId = "wk_brio",
        Name = "Brio",
        Category = "Compacte",
        Price = 18_500,
        Availability = "Working",
        Dealers = BOTH,
    },
    {
        Slot = 3,
        Id = "cadence",
        DefinitionId = "wk_cadence",
        Name = "Cadence",
        Category = "Berline",
        Price = 26_000,
        Availability = "Working",
        Dealers = { "SVC-DEALER-METRO" },
    },
    {
        Slot = 4,
        Id = "dune",
        DefinitionId = "wk_dune",
        Name = "Dune",
        Category = "SUV",
        Price = 34_000,
        Availability = "Working",
        Dealers = { "SVC-DEALER-BANLIEUE" },
    },
    {
        Slot = 5,
        Id = "eclat",
        DefinitionId = "wk_eclat",
        Name = "Éclat",
        Category = "Sportive",
        Price = 48_000,
        Availability = "Working",
        Dealers = { "SVC-DEALER-METRO" },
    },
    {
        Slot = 6,
        Id = "fil",
        DefinitionId = "wk_fil",
        Name = "Fil",
        Category = "Électrique",
        Price = 30_000,
        Availability = "Working",
        Dealers = BOTH,
    },
}
for slot = 7, 18 do
    table.insert(ENTRIES, {
        Slot = slot,
        Id = "reserve-" .. slot,
        DefinitionId = nil,
        Name = "Modèle officiel à venir",
        Category = "—",
        Price = 0,
        Availability = "Reserved",
        Dealers = {},
    })
end
VehicleCatalog.Entries = table.freeze(ENTRIES)
VehicleCatalog.Slots = 18

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
    return entry.Availability == "Working" and environment == "Dev" and entry.DefinitionId ~= nil
end

return table.freeze(VehicleCatalog)
