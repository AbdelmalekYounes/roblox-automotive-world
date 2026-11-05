--!strict
-- Données VERSIONNÉES des infrastructures et emplacements (cahier des charges
-- §2.2) : services publics, bornes de recharge, stationnements, emplacements
-- réservés aux futures propriétés, garages résidentiels et lieux sociaux,
-- apparitions et parc des prototypes.
--
-- Placement : le long d'une route dessinée (`Road`, abscisse `T` de 0 à 1 sur
-- son tracé d'origine, côté `Side` par rapport au sens From → To), toujours du
-- côté où aucun quartier n'est généré ; ou par position absolue (`At`).
-- `Width` = largeur le long de la route, `Depth` = profondeur (mètres).
-- Les interfaces économiques (achat, réparation, plein, recharge payante)
-- arrivent dans les lots suivants : ici, seuls les lieux et leurs volumes.

export type Kind =
    "Dealership"
    | "PublicGarage"
    | "FuelStation"
    | "CarWash"
    | "ChargingHub"
    | "Parking"
    | "PropertySlot"
    | "ResidentialGarageSlot"
    | "SocialSpot"
    | "FleetParking"
    | "PlayerSpawn"
    | "DriftPad"

export type Item = {
    Id: string,
    Kind: Kind,
    Zone: string,
    Name: string,
    Road: string?,
    T: number?,
    Side: ("Left" | "Right")?,
    At: { number }?, -- { x, z, cap en degrés }
    Width: number,
    Depth: number,
    -- Bornes de recharge publiques (nombre de places équipées).
    Chargers: number?,
    Pumps: number?,
    Stalls: number?,
}

local items: { Item } = {}

local function add(item: Item)
    table.insert(items, item)
end

-- Le côté « extérieur » du boulevard extérieur (vers le périphérique) est la
-- gauche dans le sens des sommets B00 → B23 (sens horaire).
local function boulevard(k: number): string
    return string.format("BD-EXT-%02d", k)
end

-- ======================== MÉTROPOLE ========================
add({
    Id = "SVC-DEALER-METRO",
    Kind = "Dealership",
    Zone = "Metropole",
    Name = "Concession du Grand Boulevard",
    Road = boulevard(4),
    T = 0.5,
    Side = "Left",
    Width = 110,
    Depth = 70,
    Stalls = 12,
})
add({
    Id = "SVC-GARAGE-METRO",
    Kind = "PublicGarage",
    Zone = "Metropole",
    Name = "Garage du Centre",
    Road = boulevard(10),
    T = 0.5,
    Side = "Left",
    Width = 70,
    Depth = 50,
    Stalls = 6,
})
add({
    Id = "SVC-FUEL-METRO",
    Kind = "FuelStation",
    Zone = "Metropole",
    Name = "Station du Boulevard",
    Road = boulevard(19),
    T = 0.5,
    Side = "Left",
    Width = 70,
    Depth = 45,
    Pumps = 6,
    Chargers = 4,
})
add({
    Id = "SVC-WASH-METRO",
    Kind = "CarWash",
    Zone = "Metropole",
    Name = "Lavage Central",
    Road = boulevard(22),
    T = 0.5,
    Side = "Left",
    Width = 45,
    Depth = 35,
    Stalls = 3,
})
add({
    Id = "SVC-CHARGE-METRO",
    Kind = "ChargingHub",
    Zone = "Metropole",
    Name = "Pôle de recharge de l'Opéra",
    Road = boulevard(7),
    T = 0.5,
    Side = "Left",
    Width = 60,
    Depth = 35,
    Chargers = 10,
})
add({
    Id = "FLEET-METRO",
    Kind = "FleetParking",
    Zone = "Metropole",
    Name = "Parc des prototypes",
    Road = boulevard(13),
    T = 0.5,
    Side = "Left",
    Width = 110,
    Depth = 60,
    Stalls = 9,
})
add({
    Id = "SPAWN-METRO",
    Kind = "PlayerSpawn",
    Zone = "Metropole",
    Name = "Esplanade du Boulevard",
    Road = boulevard(14),
    T = 0.25,
    Side = "Left",
    Width = 30,
    Depth = 30,
})
add({
    Id = "SOCIAL-METRO",
    Kind = "SocialSpot",
    Zone = "Metropole",
    Name = "Parvis des Rencontres",
    Road = boulevard(14),
    T = 0.65,
    Side = "Left",
    Width = 70,
    Depth = 50,
})
add({
    Id = "PARK-METRO-N",
    Kind = "Parking",
    Zone = "Metropole",
    Name = "Parking du Nord",
    Road = boulevard(1),
    T = 0.3,
    Side = "Left",
    Width = 70,
    Depth = 45,
    Stalls = 20,
})
add({
    Id = "PROP-METRO-1",
    Kind = "PropertySlot",
    Zone = "Metropole",
    Name = "Résidence du Parc (emplacement)",
    Road = boulevard(16),
    T = 0.4,
    Side = "Left",
    Width = 50,
    Depth = 40,
})
add({
    Id = "PROP-METRO-2",
    Kind = "PropertySlot",
    Zone = "Metropole",
    Name = "Lofts de l'Est (emplacement)",
    Road = boulevard(1),
    T = 0.75,
    Side = "Left",
    Width = 45,
    Depth = 40,
})
add({
    Id = "GARAGE-METRO-1",
    Kind = "ResidentialGarageSlot",
    Zone = "Metropole",
    Name = "Box résidentiel du Parc",
    Road = boulevard(16),
    T = 0.7,
    Side = "Left",
    Width = 20,
    Depth = 12,
})

-- ======================== BANLIEUES ========================
add({
    Id = "SVC-DEALER-BANLIEUE",
    Kind = "Dealership",
    Zone = "Banlieues",
    Name = "Concession de la Plaine",
    Road = "AV-COMMERCE",
    T = 0.62,
    Side = "Left",
    Width = 90,
    Depth = 50,
    Stalls = 10,
})
add({
    Id = "SVC-GARAGE-BANLIEUE",
    Kind = "PublicGarage",
    Zone = "Banlieues",
    Name = "Garage des Tilleuls",
    Road = "AV-LILAS",
    T = 0.5,
    Side = "Left",
    Width = 60,
    Depth = 45,
    Stalls = 5,
})
add({
    Id = "SVC-FUEL-BANLIEUE",
    Kind = "FuelStation",
    Zone = "Banlieues",
    Name = "Station des Lisières",
    Road = "RUE-COMMERCE",
    T = 0.45,
    Side = "Right",
    Width = 70,
    Depth = 45,
    Pumps = 6,
    Chargers = 4,
})
add({
    Id = "SVC-WASH-BANLIEUE",
    Kind = "CarWash",
    Zone = "Banlieues",
    Name = "Lavage des Vignes",
    Road = "AV-VIGNES",
    T = 0.5,
    Side = "Left",
    Width = 45,
    Depth = 35,
    Stalls = 3,
})
add({
    Id = "PROP-BANLIEUE-1",
    Kind = "PropertySlot",
    Zone = "Banlieues",
    Name = "Villa de la Plaine (emplacement)",
    Road = "AV-PLAINE",
    T = 0.3,
    Side = "Left",
    Width = 40,
    Depth = 35,
})
add({
    Id = "PROP-BANLIEUE-2",
    Kind = "PropertySlot",
    Zone = "Banlieues",
    Name = "Villa des Coteaux (emplacement)",
    Road = "AV-PLAINE",
    T = 0.55,
    Side = "Left",
    Width = 40,
    Depth = 35,
})
add({
    Id = "PROP-BANLIEUE-3",
    Kind = "PropertySlot",
    Zone = "Banlieues",
    Name = "Maison de la Forêt (emplacement)",
    Road = "RTE-FORET",
    T = 0.5,
    Side = "Left",
    Width = 40,
    Depth = 35,
})
add({
    Id = "GARAGE-BANLIEUE-1",
    Kind = "ResidentialGarageSlot",
    Zone = "Banlieues",
    Name = "Garage de la Plaine",
    Road = "AV-PLAINE",
    T = 0.78,
    Side = "Left",
    Width = 20,
    Depth = 12,
})
add({
    Id = "SOCIAL-BANLIEUE",
    Kind = "SocialSpot",
    Zone = "Banlieues",
    Name = "Parking du Centre commercial",
    Road = "AV-ENTREPRISES",
    T = 0.5,
    Side = "Left",
    Width = 80,
    Depth = 50,
})

-- ======================== DOCKS ========================
add({
    Id = "SVC-GARAGE-DOCKS",
    Kind = "PublicGarage",
    Zone = "Docks",
    Name = "Garage Poids Lourds du Port",
    Road = "AV-DOCKS",
    T = 0.45,
    Side = "Right",
    Width = 80,
    Depth = 50,
    Stalls = 6,
})
add({
    Id = "SVC-FUEL-DOCKS",
    Kind = "FuelStation",
    Zone = "Docks",
    Name = "Station du Port",
    Road = "ACC-DOCKS-N",
    T = 0.55,
    Side = "Right",
    Width = 80,
    Depth = 50,
    Pumps = 8,
    Chargers = 4,
})
add({
    Id = "PARK-DOCKS",
    Kind = "Parking",
    Zone = "Docks",
    Name = "Aire des poids lourds",
    Road = "ACC-DOCKS-N",
    T = 0.55,
    Side = "Left",
    Width = 120,
    Depth = 60,
    Stalls = 12,
})

-- ======================== MONTAGNES ========================
add({
    Id = "SVC-FUEL-MONTAGNE",
    Kind = "FuelStation",
    Zone = "Montagnes",
    Name = "Station du Col",
    Road = "VRNE-3",
    T = 0.5,
    Side = "Right",
    Width = 70,
    Depth = 45,
    Pumps = 4,
    Chargers = 4,
})
add({
    Id = "SOCIAL-MONTAGNE",
    Kind = "SocialSpot",
    Zone = "Montagnes",
    Name = "Belvédère des Crêtes",
    Road = "M2-1",
    T = 0.96,
    Side = "Right",
    Width = 50,
    Depth = 35,
})
add({
    Id = "PROP-MONTAGNE-1",
    Kind = "PropertySlot",
    Zone = "Montagnes",
    Name = "Chalet des Crêtes (emplacement)",
    Road = "M2-1",
    T = 0.45,
    Side = "Right",
    Width = 35,
    Depth = 30,
})
add({
    Id = "PROP-MONTAGNE-2",
    Kind = "PropertySlot",
    Zone = "Montagnes",
    Name = "Chalet du Lac (emplacement)",
    Road = "M3-1",
    T = 0.92,
    Side = "Left",
    Width = 35,
    Depth = 30,
})

-- ======================== CAMPAGNE ========================
add({
    Id = "SVC-FUEL-CAMPAGNE",
    Kind = "FuelStation",
    Zone = "Campagne",
    Name = "Station des Peupliers",
    Road = "D4-3",
    T = 0.5,
    Side = "Left",
    Width = 70,
    Depth = 45,
    Pumps = 4,
    Chargers = 2,
})
add({
    Id = "PROP-CAMPAGNE-1",
    Kind = "PropertySlot",
    Zone = "Campagne",
    Name = "Ferme des Vergers (emplacement)",
    Road = "D1",
    T = 0.4,
    Side = "Right",
    Width = 60,
    Depth = 45,
})
add({
    Id = "SOCIAL-CAMPAGNE",
    Kind = "SocialSpot",
    Zone = "Campagne",
    Name = "Aire des Peupliers",
    Road = "D4-4",
    T = 0.5,
    Side = "Left",
    Width = 60,
    Depth = 40,
})

-- ======================== MOTORSPORT ========================
add({
    Id = "SVC-CHARGE-MOTORSPORT",
    Kind = "ChargingHub",
    Zone = "Motorsport",
    Name = "Bornes du Paddock",
    Road = "MS-ACCES",
    T = 0.35,
    Side = "Right",
    Width = 40,
    Depth = 30,
    Chargers = 6,
})
add({
    Id = "PARK-PADDOCK",
    Kind = "SocialSpot",
    Zone = "Motorsport",
    Name = "Paddock",
    Road = "MS-ACCES",
    T = 0.55,
    Side = "Left",
    Width = 120,
    Depth = 70,
    Stalls = 30,
})
add({
    Id = "SPAWN-MOTORSPORT",
    Kind = "PlayerSpawn",
    Zone = "Motorsport",
    Name = "Entrée du complexe",
    Road = "MS-ACCES",
    T = 0.85,
    Side = "Right",
    Width = 25,
    Depth = 25,
})
add({
    Id = "MS-DRIFT",
    Kind = "DriftPad",
    Zone = "Motorsport",
    Name = "Zone de drift",
    At = { -4080, -1060, 0 },
    Width = 150,
    Depth = 150,
})

-- ======================== LITTORAL ========================
add({
    Id = "SVC-FUEL-LITTORAL",
    Kind = "FuelStation",
    Zone = "Littoral",
    Name = "Station de la Corniche",
    Road = "D10-3",
    T = 0.5,
    Side = "Left",
    Width = 70,
    Depth = 45,
    Pumps = 4,
    Chargers = 4,
})
add({
    Id = "SVC-WASH-LITTORAL",
    Kind = "CarWash",
    Zone = "Littoral",
    Name = "Lavage de la Plage",
    Road = "RUE-PHARE",
    T = 0.5,
    Side = "Left",
    Width = 40,
    Depth = 30,
    Stalls = 2,
})
add({
    Id = "SOCIAL-LITTORAL",
    Kind = "SocialSpot",
    Zone = "Littoral",
    Name = "Parking de la Plage",
    Road = "D10-2",
    T = 0.55,
    Side = "Right",
    Width = 120,
    Depth = 60,
    Stalls = 30,
})
add({
    Id = "SOCIAL-FALAISES",
    Kind = "SocialSpot",
    Zone = "Littoral",
    Name = "Belvédère des Falaises",
    Road = "D10-4",
    T = 0.93,
    Side = "Right",
    Width = 50,
    Depth = 30,
})
add({
    Id = "SPAWN-LITTORAL",
    Kind = "PlayerSpawn",
    Zone = "Littoral",
    Name = "Promenade de Port-Soleil",
    Road = "D10-2",
    T = 0.2,
    Side = "Right",
    Width = 25,
    Depth = 25,
})
add({
    Id = "PROP-LITTORAL-1",
    Kind = "PropertySlot",
    Zone = "Littoral",
    Name = "Villa des Embruns (emplacement)",
    Road = "D10-1",
    T = 0.3,
    Side = "Right",
    Width = 40,
    Depth = 35,
})
add({
    Id = "PROP-LITTORAL-2",
    Kind = "PropertySlot",
    Zone = "Littoral",
    Name = "Villa de la Pointe (emplacement)",
    Road = "D10-1",
    T = 0.6,
    Side = "Right",
    Width = 40,
    Depth = 35,
})
add({
    Id = "GARAGE-LITTORAL-1",
    Kind = "ResidentialGarageSlot",
    Zone = "Littoral",
    Name = "Garage des Embruns",
    Road = "D10-1",
    T = 0.42,
    Side = "Right",
    Width = 20,
    Depth = 12,
})

return table.freeze(items)
