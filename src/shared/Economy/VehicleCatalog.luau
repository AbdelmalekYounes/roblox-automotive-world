--!strict
--[[
    Catalogue commercial des concessions (lot 0.5), VERSIONNÉ.

    Dix-huit emplacements, comme le prévoit le cahier des charges. Lot 0.8 :
    gamme PROPOSÉE de 18 modèles fictifs (Vehicles/Definitions/WorkingCatalog),
    tous « PendingApproval » tant que le propriétaire n'a pas validé la gamme :
    - « PendingApproval » / « Working » : proposition ou modèle de travail,
      achetable seulement en environnement de développement ;
    - « Reserved » : emplacement d'un modèle officiel à venir, jamais achetable ;
    - « Official » : modèle validé par le propriétaire (aucun aujourd'hui),
      achetable dans tous les environnements.
    Répartition : concession Métropole (urbaines, électriques, sportives et
    prestige), concession Banlieues (familiales, SUV, tout-terrain, roadster) ;
    trois modèles d'entrée de gamme dans les deux. Prix : hypothèses de travail.
    Les prototypes techniques (P-01, P-02, P-03) n'y figurent pas.
]]

local VehicleCatalog = {}

VehicleCatalog.Version = "0.8.0-proposition"

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

local BOTH = { "SVC-DEALER-METRO", "SVC-DEALER-BANLIEUE" }

local ENTRIES: { Entry } = {
    {
        Slot = 1,
        Id = "pixel",
        DefinitionId = "wk_pixel",
        Name = "Pixel",
        Category = "Citadine électrique",
        Price = 14_500,
        Availability = "PendingApproval",
        Dealers = { "SVC-DEALER-METRO" },
    },
    {
        Slot = 2,
        Id = "brio",
        DefinitionId = "wk_brio",
        Name = "Brio",
        Category = "Citadine",
        Price = 16_500,
        Availability = "PendingApproval",
        Dealers = BOTH,
    },
    {
        Slot = 3,
        Id = "fil",
        DefinitionId = "wk_fil",
        Name = "Fil",
        Category = "Citadine électrique",
        Price = 19_500,
        Availability = "PendingApproval",
        Dealers = BOTH,
    },
    {
        Slot = 4,
        Id = "aster",
        DefinitionId = "wk_aster",
        Name = "Aster",
        Category = "Compacte",
        Price = 19_000,
        Availability = "PendingApproval",
        Dealers = BOTH,
    },
    {
        Slot = 5,
        Id = "nova",
        DefinitionId = "wk_nova",
        Name = "Nova",
        Category = "Compacte",
        Price = 21_000,
        Availability = "PendingApproval",
        Dealers = { "SVC-DEALER-METRO" },
    },
    {
        Slot = 6,
        Id = "cadence",
        DefinitionId = "wk_cadence",
        Name = "Cadence",
        Category = "Berline",
        Price = 32_000,
        Availability = "PendingApproval",
        Dealers = { "SVC-DEALER-METRO" },
    },
    {
        Slot = 7,
        Id = "lumen",
        DefinitionId = "wk_lumen",
        Name = "Lumen",
        Category = "Break",
        Price = 27_000,
        Availability = "PendingApproval",
        Dealers = { "SVC-DEALER-BANLIEUE" },
    },
    {
        Slot = 8,
        Id = "oree",
        DefinitionId = "wk_oree",
        Name = "Orée",
        Category = "Berline électrique",
        Price = 68_000,
        Availability = "PendingApproval",
        Dealers = { "SVC-DEALER-METRO" },
    },
    {
        Slot = 9,
        Id = "brise",
        DefinitionId = "wk_brise",
        Name = "Brise",
        Category = "Roadster",
        Price = 33_000,
        Availability = "PendingApproval",
        Dealers = { "SVC-DEALER-BANLIEUE" },
    },
    {
        Slot = 10,
        Id = "rafale",
        DefinitionId = "wk_rafale",
        Name = "Rafale",
        Category = "Sportive compacte",
        Price = 42_000,
        Availability = "PendingApproval",
        Dealers = { "SVC-DEALER-METRO" },
    },
    {
        Slot = 11,
        Id = "eclat",
        DefinitionId = "wk_eclat",
        Name = "Éclat",
        Category = "Coupé sportif",
        Price = 46_000,
        Availability = "PendingApproval",
        Dealers = { "SVC-DEALER-METRO" },
    },
    {
        Slot = 12,
        Id = "mistral",
        DefinitionId = "wk_mistral",
        Name = "Mistral",
        Category = "Coupé GT",
        Price = 98_000,
        Availability = "PendingApproval",
        Dealers = { "SVC-DEALER-METRO" },
    },
    {
        Slot = 13,
        Id = "comete",
        DefinitionId = "wk_comete",
        Name = "Comète",
        Category = "Supercar",
        Price = 185_000,
        Availability = "PendingApproval",
        Dealers = { "SVC-DEALER-METRO" },
    },
    {
        Slot = 14,
        Id = "zenith",
        DefinitionId = "wk_zenith",
        Name = "Zénith",
        Category = "Supercar électrique",
        Price = 210_000,
        Availability = "PendingApproval",
        Dealers = { "SVC-DEALER-METRO" },
    },
    {
        Slot = 15,
        Id = "dune",
        DefinitionId = "wk_dune",
        Name = "Dune",
        Category = "SUV compact",
        Price = 34_000,
        Availability = "PendingApproval",
        Dealers = { "SVC-DEALER-BANLIEUE" },
    },
    {
        Slot = 16,
        Id = "vigie",
        DefinitionId = "wk_vigie",
        Name = "Vigie",
        Category = "Grand SUV",
        Price = 72_000,
        Availability = "PendingApproval",
        Dealers = { "SVC-DEALER-BANLIEUE" },
    },
    {
        Slot = 17,
        Id = "sentier",
        DefinitionId = "wk_sentier",
        Name = "Sentier",
        Category = "Tout-terrain",
        Price = 26_000,
        Availability = "PendingApproval",
        Dealers = { "SVC-DEALER-BANLIEUE" },
    },
    {
        Slot = 18,
        Id = "atlas",
        DefinitionId = "wk_atlas",
        Name = "Atlas",
        Category = "Pick-up tout-terrain",
        Price = 52_000,
        Availability = "PendingApproval",
        Dealers = { "SVC-DEALER-BANLIEUE" },
    },
}
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
    return (entry.Availability == "Working" or entry.Availability == "PendingApproval")
        and environment == "Dev"
        and entry.DefinitionId ~= nil
end

return table.freeze(VehicleCatalog)
