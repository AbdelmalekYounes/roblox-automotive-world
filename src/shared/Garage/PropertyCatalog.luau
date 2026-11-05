--!strict
--[[
    Catalogue PUR des propriétés privées (cahier des charges §4.1, §4.2, §5.4).

    - Trois catégories : petite (1 à 2 places exposées), moyenne (3 à 5),
      prestige (6 à 10). La capacité limite les véhicules EXPOSÉS, jamais la
      taille de la collection.
    - Une propriété possédée est un enregistrement du profil ; elle référence
      une OFFRE de ce catalogue. Chaque offre est reliée à une ENTRÉE de la
      carte (identifiant d'infrastructure du lot 0.3) : l'intérieur est un
      espace privé instancié par propriétaire. Plusieurs joueurs peuvent donc
      posséder la même offre sans dépendre d'une parcelle physique unique.
    - Les prix ne sont pas figés par le cahier des charges (fourchette
      illustrative 25 000 à 60 000 crédits, §5.4) : aucun prix ici. L'achat et
      la revente relèvent de l'économie (lot 0.5), voir EconomyContracts.
]]

local PropertyCatalog = {}

-- Cinq propriétés au plus, propriété gratuite comprise (§4.1, SCN-07).
PropertyCatalog.MaxOwned = 5

export type CategoryId = "Small" | "Medium" | "Prestige"

export type Category = {
    Id: CategoryId,
    Label: string,
    MinSlots: number, -- places exposées au niveau 0 du garage
    MaxSlots: number, -- places exposées au niveau maximal
}

PropertyCatalog.Categories = table.freeze({
    Small = table.freeze({ Id = "Small" :: CategoryId, Label = "Petite propriété", MinSlots = 1, MaxSlots = 2 }),
    Medium = table.freeze({ Id = "Medium" :: CategoryId, Label = "Propriété moyenne", MinSlots = 3, MaxSlots = 5 }),
    Prestige = table.freeze({
        Id = "Prestige" :: CategoryId,
        Label = "Propriété prestige",
        MinSlots = 6,
        MaxSlots = 10,
    }),
}) :: { [string]: Category }

export type Offer = {
    Id: string,
    Category: CategoryId,
    -- Entrée dans le monde ouvert : identifiant d'infrastructure (Data/Infrastructure).
    Entrance: string,
    Label: string,
    -- Offre de la propriété gratuite initiale (jamais en vente).
    Starter: boolean,
}

local function offer(id: string, category: CategoryId, entrance: string, label: string, starter: boolean?): Offer
    return table.freeze({
        Id = id,
        Category = category,
        Entrance = entrance,
        Label = label,
        Starter = starter == true,
    })
end

-- Offres reliées aux emplacements structurels de la carte du lot 0.3.
-- Catégorie choisie selon l'emprise de l'emplacement (≥ 50 m : prestige).
local OFFERS: { Offer } = {
    offer("OFFRE-DEPART", "Small", "GARAGE-METRO-1", "Box résidentiel du Parc (propriété de départ)", true),
    offer("RES-GARAGE-BANLIEUE", "Small", "GARAGE-BANLIEUE-1", "Garage de la Plaine"),
    offer("RES-GARAGE-LITTORAL", "Small", "GARAGE-LITTORAL-1", "Garage des Embruns"),
    offer("RES-METRO-PARC", "Prestige", "PROP-METRO-1", "Résidence du Parc"),
    offer("RES-METRO-LOFTS", "Medium", "PROP-METRO-2", "Lofts de l'Est"),
    offer("RES-BANLIEUE-PLAINE", "Medium", "PROP-BANLIEUE-1", "Villa de la Plaine"),
    offer("RES-BANLIEUE-COTEAUX", "Medium", "PROP-BANLIEUE-2", "Villa des Coteaux"),
    offer("RES-BANLIEUE-FORET", "Medium", "PROP-BANLIEUE-3", "Maison de la Forêt"),
    offer("RES-MONTAGNE-CRETES", "Small", "PROP-MONTAGNE-1", "Chalet des Crêtes"),
    offer("RES-MONTAGNE-LAC", "Small", "PROP-MONTAGNE-2", "Chalet du Lac"),
    offer("RES-CAMPAGNE-VERGERS", "Prestige", "PROP-CAMPAGNE-1", "Ferme des Vergers"),
    offer("RES-LITTORAL-EMBRUNS", "Medium", "PROP-LITTORAL-1", "Villa des Embruns"),
    offer("RES-LITTORAL-POINTE", "Medium", "PROP-LITTORAL-2", "Villa de la Pointe"),
}
PropertyCatalog.Offers = table.freeze(OFFERS)

local byId: { [string]: Offer } = {}
for _, item in OFFERS do
    assert(byId[item.Id] == nil, "offre dupliquée : " .. item.Id)
    byId[item.Id] = item
end

PropertyCatalog.StarterOfferId = "OFFRE-DEPART"

function PropertyCatalog.offer(id: string): Offer?
    return byId[id]
end

-- Niveau maximal d'agrandissement du garage d'une catégorie.
function PropertyCatalog.maxGarageLevel(category: CategoryId): number
    local data = PropertyCatalog.Categories[category]
    return data.MaxSlots - data.MinSlots
end

-- Places d'exposition d'une propriété à un niveau de garage donné.
function PropertyCatalog.capacity(category: CategoryId, garageLevel: number): number
    local data = PropertyCatalog.Categories[category]
    return math.clamp(data.MinSlots + math.max(math.floor(garageLevel), 0), data.MinSlots, data.MaxSlots)
end

return table.freeze(PropertyCatalog)
