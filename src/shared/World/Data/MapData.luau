--!strict
-- Données VERSIONNÉES du réseau routier de la carte ouverte (lot 0.3).
-- Mètres ; x vers l'est, z vers le sud (le nord est en -z) ; y = altitude.
-- Les noms de lieux sont fictifs et provisoires.
--
-- Organisation :
-- - Métropole : cours central carré, 8 avenues radiales, boulevard extérieur
--   (24 sommets, r = 1 380 m), périphérique (r = 1 500 m) à 8 échangeurs ;
-- - autoroute A1 de référence en arc autour de la métropole (motorsport →
--   banlieues → littoral → port → cols), voies rapides et autoroutes radiales ;
-- - routes dessinées des banlieues, docks, campagne, montagne, littoral et du
--   complexe motorsport ; quartiers générés (World/RoadNetwork) dans les
--   polygones listés en fin de fichier.
-- Le périphérique et les autoroutes ne reçoivent aucun carrefour en T : les
-- quartiers sont bornés par leurs propres avenues.

local WorldConfig = require(script.Parent.Parent.WorldConfig)

type NodeData = { Id: string, X: number, Z: number, Y: number?, Control: string?, Name: string? }
type RoadData = { Id: string, Class: string, From: string, To: string, Via: { { number } }?, Name: string? }
type DistrictData = {
    Id: string,
    Kind: string,
    Boundary: { string },
    Rotation: number,
    BlockMin: number,
    BlockMax: number,
    StreetClass: string,
    Seed: number,
    ParkChance: number,
}

local nodes: { NodeData } = {}
local roads: { RoadData } = {}
local districts: { DistrictData } = {}

local function node(id: string, x: number, z: number, y: number?, control: string?, name: string?)
    table.insert(nodes, { Id = id, X = x, Z = z, Y = y, Control = control, Name = name })
end

local function road(id: string, class: string, from: string, to: string, via: { { number } }?, name: string?)
    table.insert(roads, { Id = id, Class = class, From = from, To = to, Via = via, Name = name })
end

local function polar(bearingDeg: number, radius: number): (number, number)
    local b = math.rad(bearingDeg)
    return radius * math.sin(b), -radius * math.cos(b)
end

local function district(
    id: string,
    kind: string,
    boundary: { string },
    rotation: number,
    blockMin: number,
    blockMax: number,
    streetClass: string,
    seed: number,
    parkChance: number
)
    table.insert(districts, {
        Id = id,
        Kind = kind,
        Boundary = boundary,
        Rotation = rotation,
        BlockMin = blockMin,
        BlockMax = blockMax,
        StreetClass = streetClass,
        Seed = seed,
        ParkChance = parkChance,
    })
end

local function pad(k: number): string
    return string.format("%02d", k)
end

-- ======================== MÉTROPOLE ========================

node("O", 0, 0, 0, "Signals", "Place Centrale")
node("C_N", 0, -250, 0, "Signals")
node("C_E", 250, 0, 0, "Signals")
node("C_S", 0, 250, 0, "Signals")
node("C_W", -250, 0, 0, "Signals")
node("C_NE", 250, -250, 0, "Signals")
node("C_SE", 250, 250, 0, "Signals")
node("C_SW", -250, 250, 0, "Signals")
node("C_NW", -250, -250, 0, "Signals")

road("AV-NORD-C", "Avenue", "O", "C_N", nil, "Avenue du Nord")
road("AV-EST-C", "Avenue", "O", "C_E", nil, "Avenue de l'Est")
road("AV-SUD-C", "Avenue", "O", "C_S", nil, "Avenue du Sud")
road("AV-OUEST-C", "Avenue", "O", "C_W", nil, "Avenue de l'Ouest")
-- Cours central (carré de 500 m).
local corners = { "C_NW", "C_N", "C_NE", "C_E", "C_SE", "C_S", "C_SW", "C_W" }
for i, id in corners do
    road("COURS-" .. i, "Avenue", id, corners[i % #corners + 1], nil, "Cours de la Ville")
end

-- Boulevard extérieur : 24 sommets (tous les 15°), rayon 1 380 m.
for k = 0, 23 do
    local x, z = polar(k * 15, 1380)
    node("B" .. pad(k), x, z, 0, if k % 3 == 0 then "Signals" else "None")
end
for k = 0, 23 do
    road("BD-EXT-" .. pad(k), "Avenue", "B" .. pad(k), "B" .. pad((k + 1) % 24), nil, "Boulevard Extérieur")
end

-- Avenues radiales du cours au boulevard, puis accès au périphérique.
local radials: { { K: number, Inner: string, Name: string } } = {
    { K = 0, Inner = "C_N", Name = "Avenue du Nord" },
    { K = 3, Inner = "C_NE", Name = "Boulevard des Cols" },
    { K = 6, Inner = "C_E", Name = "Avenue de l'Est" },
    { K = 9, Inner = "C_SE", Name = "Boulevard du Port" },
    { K = 12, Inner = "C_S", Name = "Avenue du Sud" },
    { K = 15, Inner = "C_SW", Name = "Boulevard de la Plaine" },
    { K = 18, Inner = "C_W", Name = "Avenue de l'Ouest" },
    { K = 21, Inner = "C_NW", Name = "Boulevard des Forêts" },
}
for _, r in radials do
    road("RAD-" .. pad(r.K), "Avenue", r.Inner, "B" .. pad(r.K), nil, r.Name)
end

-- Périphérique : 8 échangeurs, tracé courbe entre eux.
for k = 0, 21, 3 do
    local x, z = polar(k * 15, 1500)
    node("P" .. pad(k), x, z, 0, "Signals", "Échangeur " .. pad(k))
    road("ACC-" .. pad(k), "Avenue", "B" .. pad(k), "P" .. pad(k), nil, "Accès au périphérique")
end
for k = 0, 21, 3 do
    local via = {}
    for step = 1, 5 do
        local x, z = polar(k * 15 + step * 7.5, 1500)
        table.insert(via, { x, z })
    end
    road("PERI-" .. pad(k), "Peripherique", "P" .. pad(k), "P" .. pad((k + 3) % 24), via, "Périphérique")
end

-- Quartiers centraux (quatre quadrants du cours) et huit secteurs.
district("Q-NE", "Affaires", { "O", "C_N", "C_NE", "C_E" }, 4, 95, 130, "Rue", 1101, 0.1)
district("Q-SE", "Commerces", { "O", "C_E", "C_SE", "C_S" }, -6, 95, 130, "Rue", 1102, 0.15)
district("Q-SW", "Affaires", { "O", "C_S", "C_SW", "C_W" }, 9, 95, 130, "Rue", 1103, 0.1)
district("Q-NW", "Commerces", { "O", "C_W", "C_NW", "C_N" }, -3, 95, 130, "Rue", 1104, 0.2)
type Sector = {
    Id: string,
    Boundary: { string },
    Kind: string,
    Rotation: number,
    Min: number,
    Max: number,
    Seed: number,
    Park: number,
}
local sectors: { Sector } = {
    {
        Id = "S-NNE",
        Boundary = { "C_N", "C_NE", "B03", "B02", "B01", "B00" },
        Kind = "Affaires",
        Rotation = 7,
        Min = 110,
        Max = 150,
        Seed = 2101,
        Park = 0.08,
    },
    {
        Id = "S-ENE",
        Boundary = { "C_NE", "C_E", "B06", "B05", "B04", "B03" },
        Kind = "Commerces",
        Rotation = -10,
        Min = 120,
        Max = 165,
        Seed = 2102,
        Park = 0.1,
    },
    {
        Id = "S-ESE",
        Boundary = { "C_E", "C_SE", "B09", "B08", "B07", "B06" },
        Kind = "Residentiel",
        Rotation = 18,
        Min = 100,
        Max = 140,
        Seed = 2103,
        Park = 0.15,
    },
    {
        Id = "S-SSE",
        Boundary = { "C_SE", "C_S", "B12", "B11", "B10", "B09" },
        Kind = "Residentiel",
        Rotation = -4,
        Min = 110,
        Max = 150,
        Seed = 2104,
        Park = 0.2,
    },
    {
        Id = "S-SSW",
        Boundary = { "C_S", "C_SW", "B15", "B14", "B13", "B12" },
        Kind = "Mixte",
        Rotation = 12,
        Min = 105,
        Max = 145,
        Seed = 2105,
        Park = 0.12,
    },
    {
        Id = "S-WSW",
        Boundary = { "C_SW", "C_W", "B18", "B17", "B16", "B15" },
        Kind = "Residentiel",
        Rotation = -15,
        Min = 100,
        Max = 140,
        Seed = 2106,
        Park = 0.15,
    },
    {
        Id = "S-WNW",
        Boundary = { "C_W", "C_NW", "B21", "B20", "B19", "B18" },
        Kind = "Commerces",
        Rotation = 3,
        Min = 120,
        Max = 160,
        Seed = 2107,
        Park = 0.1,
    },
    {
        Id = "S-NNW",
        Boundary = { "C_NW", "C_N", "B00", "B23", "B22", "B21" },
        Kind = "Public",
        Rotation = -20,
        Min = 130,
        Max = 180,
        Seed = 2108,
        Park = 0.3,
    },
}
for _, s in sectors do
    district(s.Id, s.Kind, s.Boundary, s.Rotation, s.Min, s.Max, "Rue", s.Seed, s.Park)
end

-- ======================== AUTOROUTE A1 ET RADIALES ========================

node("A1_00", -4300, 300, 0, "Merge", "Échangeur du Motorsport")
node("A1_01", -2300, 2600, 0, "Merge", "Échangeur de la Plaine")
node("A1_02", 0, 3050, 0, "Merge", "Échangeur du Littoral")
node("A1_03", 2600, 2050, 0, "Merge", "Échangeur du Port")
node("A1_04", 2350, 300, 0, "Merge", "Échangeur de l'Est")
node("A1_05", 3100, -2550, 0, "Merge", "Échangeur des Cols")

road("A1-1", "Autoroute", "A1_00", "A1_01", { { -4000, 900 }, { -3500, 1500 }, { -2900, 2200 } }, "A1")
road("A1-2", "Autoroute", "A1_01", "A1_02", { { -1500, 2950 }, { -700, 3080 } }, "A1")
road("A1-3", "Autoroute", "A1_02", "A1_03", { { 1200, 3000 }, { 2100, 2700 } }, "A1")
road("A1-4", "Autoroute", "A1_03", "A1_04", { { 2450, 1200 } }, "A1")
road("A1-5", "Autoroute", "A1_04", "A1_05", { { 2400, -700 }, { 2750, -1650 } }, "A1")

-- A6 (sud), A4 (est), A2 (nord), voies rapides sud-ouest, ouest et nord-est.
node("A6_1", 0, 2200, 0, "Signals", "Échangeur de la Gare")
road("A6-1", "Autoroute", "P12", "A6_1", nil, "A6")
road("A6-2", "Autoroute", "A6_1", "A1_02", nil, "A6")
road("A4-1", "Autoroute", "P06", "A1_04", { { 1950, 120 } }, "A4")

node("A2_1", -200, -2500, 0, "Signals", "Échangeur de Vauclair")
node("A2_2", -700, -3500, 0, "Signals", "Échangeur des Peupliers")
node("A2_N", -1100, -4400, 0, "Signals", "Carrefour du Nord")
road("A2-1", "VoieRapide", "P00", "A2_1", { { -60, -2000 } }, "Voie rapide du Nord")
road("A2-2", "VoieRapide", "A2_1", "A2_2", { { -420, -3000 } }, "Voie rapide du Nord")
road("A2-3", "VoieRapide", "A2_2", "A2_N", { { -950, -3950 } }, "Voie rapide du Nord")

node("VRSO_1", -1700, 1800, 0, "Signals", "Échangeur des Tilleuls")
road("VRSO-1", "VoieRapide", "P15", "VRSO_1", nil, "Voie rapide du Sud-Ouest")
road("VRSO-2", "VoieRapide", "VRSO_1", "A1_01", nil, "Voie rapide du Sud-Ouest")

node("VRO_1", -2600, 100, 0, "Signals", "Échangeur des Vignes")
node("VRO_2", -3500, 250, 0, "Signals", "Échangeur des Lisières")
road("VRO-1", "VoieRapide", "P18", "VRO_1", nil, "Voie rapide de l'Ouest")
road("VRO-2", "VoieRapide", "VRO_1", "VRO_2", nil, "Voie rapide de l'Ouest")
road("VRO-3", "VoieRapide", "VRO_2", "A1_00", nil, "Voie rapide de l'Ouest")

node("VRNE_1", 1750, -1650, 0, "Merge")
node("VRNE_2", 2350, -2150, 0, "Signals", "Échangeur du Lac")
road("VRNE-1", "VoieRapide", "P03", "VRNE_1", nil, "Voie rapide des Cols")
road("VRNE-2", "VoieRapide", "VRNE_1", "VRNE_2", nil, "Voie rapide des Cols")
road("VRNE-3", "VoieRapide", "VRNE_2", "A1_05", nil, "Voie rapide des Cols")

-- ======================== BANLIEUES ========================

-- Sud-ouest : lotissements des Tilleuls et parc d'activités.
node("SW_E", -1650, 500, 0, "Signals")
node("SW_C", -2700, 1300, 0, "Signals")
node("SW_S", -2300, 2250, 0, "Signals")
node("SW_W", -3000, 1850, 0, "Yield")
road("AV-LILAS", "Avenue", "VRO_1", "SW_E", nil, "Avenue des Lilas")
road("AV-PLAINE", "Avenue", "SW_E", "VRSO_1", nil, "Avenue de la Plaine")
road("AV-TILLEULS", "Avenue", "VRSO_1", "SW_C", nil, "Avenue des Tilleuls")
road("AV-VIGNES", "Avenue", "SW_C", "VRO_1", nil, "Avenue des Vignes")
road("AV-COMMERCE", "Avenue", "VRSO_1", "SW_S", nil, "Avenue du Commerce")
road("AV-ENTREPRISES", "Avenue", "SW_S", "SW_W", nil, "Avenue des Entreprises")
road("AV-ARTISANS", "Avenue", "SW_W", "SW_C", nil, "Avenue des Artisans")
road("ACC-PLAINE", "Avenue", "SW_S", "A1_01", nil, "Accès de la Plaine")
district("TILLEULS", "Pavillonnaire", { "VRO_1", "SW_E", "VRSO_1", "SW_C" }, 22, 70, 105, "Rue", 3101, 0.08)
district("PARC-SO", "Activites", { "SW_C", "VRSO_1", "SW_S", "SW_W" }, -12, 150, 210, "Rue", 3102, 0.05)

-- Sud : Hortensias et Jardins du Sud, de part et d'autre de l'A6.
node("H_1", -150, 1700, 0, "Signals")
node("H_2", -950, 1650, 0, "Yield")
node("H_3", -1100, 2150, 0, "Yield")
node("H_4", -150, 2200, 0, "Signals")
road("RUE-HORTENSIAS-N", "Avenue", "H_1", "H_2", nil, "Rue des Hortensias")
road("RUE-HORTENSIAS-O", "Avenue", "H_2", "H_3", nil, "Rue des Hortensias")
road("AV-GARE-O", "Avenue", "H_3", "H_4", nil, "Avenue de la Gare")
road("RUE-HORTENSIAS-E", "Avenue", "H_4", "H_1", nil, "Rue des Hortensias")
road("ACC-HORTENSIAS", "Avenue", "H_1", "P12", nil, "Accès des Hortensias")
road("ACC-GARE-O", "Avenue", "H_4", "A6_1", nil, "Avenue de la Gare")
district("HORTENSIAS", "Pavillonnaire", { "H_1", "H_2", "H_3", "H_4" }, -8, 75, 110, "Rue", 3201, 0.1)

node("S_1", 150, 1700, 0, "Signals")
node("S_2", 1050, 1750, 0, "Signals")
node("S_3", 1100, 2200, 0, "Yield")
node("S_4", 150, 2200, 0, "Signals")
node("SE1", 1700, 1700, 0, "Signals", "Carrefour du Port")
road("RUE-JARDINS-N", "Avenue", "S_1", "S_2", nil, "Rue des Jardins")
road("RUE-JARDINS-E", "Avenue", "S_2", "S_3", nil, "Rue des Jardins")
road("AV-GARE-E", "Avenue", "S_3", "S_4", nil, "Avenue de la Gare")
road("RUE-JARDINS-O", "Avenue", "S_4", "S_1", nil, "Rue des Jardins")
road("ACC-JARDINS", "Avenue", "S_1", "P12", nil, "Accès des Jardins")
road("ACC-GARE-E", "Avenue", "S_4", "A6_1", nil, "Avenue de la Gare")
road("AV-PORT-1", "Avenue", "P09", "SE1", nil, "Avenue du Port")
road("AV-PORT-2", "Avenue", "SE1", "A1_03", nil, "Avenue du Port")
road("RUE-JARDINS-PORT", "Avenue", "S_2", "SE1", nil, "Rue du Port")
district("JARDINS", "Residentiel", { "S_1", "S_2", "S_3", "S_4" }, 6, 80, 120, "Rue", 3301, 0.12)

-- Nord-ouest : Les Chênes (pavillonnaire) et zone commerciale des Lisières.
node("NW1", -1750, -1600, 0, "Signals")
node("NW2", -2900, -1500, 0, "Signals")
node("NW3", -3000, -700, 0, "Signals")
node("NW4", -1900, -650, 0, "Signals")
node("NW5", -3100, -180, 0, "Signals")
node("NW6", -1950, -200, 0, "Signals")
road("RTE-FORET", "Avenue", "P21", "NW1", nil, "Route de la Forêt")
road("BD-CHENES-N", "Avenue", "NW1", "NW2", nil, "Boulevard des Chênes")
road("BD-CHENES-O", "Avenue", "NW2", "NW3", nil, "Boulevard des Chênes")
road("BD-CHENES-S", "Avenue", "NW3", "NW4", nil, "Boulevard des Chênes")
road("BD-CHENES-E", "Avenue", "NW4", "NW1", nil, "Boulevard des Chênes")
road("RUE-COMMERCE-O", "Avenue", "NW3", "NW5", nil, "Rue du Commerce")
road("RUE-COMMERCE", "Avenue", "NW5", "NW6", nil, "Rue du Commerce")
road("RUE-COMMERCE-E", "Avenue", "NW6", "NW4", nil, "Rue du Commerce")
road("AV-LISIERES", "Avenue", "NW6", "P18", nil, "Avenue des Lisières")
road("ACC-LISIERES", "Avenue", "NW5", "VRO_2", nil, "Accès des Lisières")
district("CHENES", "Pavillonnaire", { "NW1", "NW2", "NW3", "NW4" }, 31, 75, 110, "Rue", 3401, 0.1)
district("LISIERES", "Activites", { "NW4", "NW3", "NW5", "NW6" }, 2, 140, 200, "Rue", 3402, 0.05)

-- Est : quartier du Levant, entre le périphérique et le port.
node("E_1", 1750, 450, 0, "Signals")
node("E_2", 2150, 500, 0, "Yield")
node("E_3", 2150, 1250, 0, "Yield")
node("E_4", 1700, 1300, 0, "Signals")
road("RUE-LEVANT-N", "Avenue", "E_1", "E_2", nil, "Rue du Levant")
road("RUE-LEVANT-E", "Avenue", "E_2", "E_3", nil, "Rue du Levant")
road("RUE-LEVANT-S", "Avenue", "E_3", "E_4", nil, "Rue du Levant")
road("RUE-LEVANT-O", "Avenue", "E_4", "E_1", nil, "Rue du Levant")
road("ACC-LEVANT", "Avenue", "E_1", "P06", nil, "Accès du Levant")
road("RUE-LEVANT-PORT", "Avenue", "E_4", "SE1", nil, "Rue du Levant")
district("LEVANT", "Residentiel", { "E_1", "E_2", "E_3", "E_4" }, 15, 80, 120, "Rue", 3501, 0.12)

-- ======================== DOCKS ET ZONE INDUSTRIELLE ========================

node("D_W0", 2800, -650, 0, "Signals")
node("D_E0", 3850, -650, 0, "Yield")
node("D_W1", 2800, 350, 0, "Signals")
node("D3", 3880, 350, 0, "Yield")
node("D2", 3880, 1650, 0, "Signals", "Môle Sud")
node("D_W2", 2800, 1650, 0, "Signals")
road("QUAI-NORD", "Avenue", "D_W1", "D3", nil, "Quai du Nord")
road("QUAI-EST", "Avenue", "D3", "D2", nil, "Quai de l'Est")
road("QUAI-SUD", "Avenue", "D2", "D_W2", nil, "Quai du Sud")
road("BD-INDUSTRIEL", "Avenue", "D_W2", "D_W1", nil, "Boulevard Industriel")
road("RUE-USINES", "Avenue", "D_W0", "D_E0", nil, "Rue des Usines")
road("QUAI-NORD-E", "Avenue", "D_E0", "D3", nil, "Quai du Levant")
road("BD-INDUSTRIEL-N", "Avenue", "D_W1", "D_W0", nil, "Boulevard Industriel")
road("ACC-DOCKS-N", "Avenue", "A1_04", "D_W1", nil, "Accès des Docks")
road("AV-DOCKS", "Avenue", "A1_03", "D_W2", nil, "Avenue des Docks")
district("DOCKS", "Docks", { "D_W1", "D3", "D2", "D_W2" }, 0, 190, 260, "Avenue", 4101, 0.05)
district("USINES", "Industriel", { "D_W0", "D_E0", "D3", "D_W1" }, 0, 170, 240, "Avenue", 4102, 0.05)

-- ======================== MONTAGNES ========================

node("M_COL", 2600, -4300, 250, "Yield", "Col du Grand Ravin")
node("M_LAC", 2200, -4450, 215, "Yield", "Carrefour du Lac")
node("BELV", 4300, -4250, 240, "None", "Belvédère des Crêtes")
-- Montée du col : neuf épingles (pentes de 4 à 10 %).
road("M1-1", "Montagne", "A1_05", "M_COL", {
    { 3300, -2850, 15 },
    { 3500, -3100, 35 },
    { 3150, -3200, 60 },
    { 3450, -3400, 85 },
    { 3050, -3500, 110 },
    { 3400, -3700, 135 },
    { 3000, -3850, 165 },
    { 3300, -4030, 190 },
    { 2900, -4170, 215 },
}, "Col du Grand Ravin")
road("M1-2", "Montagne", "M_COL", "M_LAC", nil, "Col du Grand Ravin")
road("M1-3", "Montagne", "M_LAC", "SA2", {
    { 1900, -4300, 185 },
    { 1550, -4500, 145 },
    { 1250, -4350, 108 },
    { 950, -4560, 68 },
    { 700, -4420, 36 },
    { 450, -4350, 15 },
}, "Descente de Saint-Amarre")
-- Route des Crêtes : panoramique, en cul-de-sac vers le belvédère.
road("M2-1", "Montagne", "M_COL", "BELV", {
    { 3000, -4550, 262 },
    { 3500, -4650, 270 },
    { 3950, -4550, 255 },
}, "Route des Crêtes")
-- Route du Lac : second itinéraire sinueux depuis la voie rapide des Cols.
road("M3-1", "Montagne", "VRNE_2", "M_LAC", {
    { 2150, -2500, 20 },
    { 2400, -2850, 50 },
    { 2050, -3100, 80 },
    { 2350, -3400, 110 },
    { 1950, -3650, 140 },
    { 2250, -3950, 170 },
    { 2050, -4200, 195 },
}, "Route du Lac")

-- ======================== CAMPAGNE ========================

node("SA1", 100, -4250, 0, "Yield")
node("SA2", 650, -4200, 0, "Signals", "Saint-Amarre")
node("SA3", 600, -3850, 0, "Yield")
node("SA4", 120, -3900, 0, "Yield")
road("RUE-SA-N", "Rue", "SA1", "SA2", nil, "Grand-Rue de Saint-Amarre")
road("RUE-SA-E", "Rue", "SA2", "SA3", nil, "Rue de l'Église")
road("RUE-SA-S", "Rue", "SA3", "SA4", nil, "Rue des Écoles")
road("RUE-SA-O", "Rue", "SA4", "SA1", nil, "Rue du Moulin")
district("SAINT-AMARRE", "Village", { "SA1", "SA2", "SA3", "SA4" }, 4, 80, 130, "Rue", 5101, 0.2)

node("V1", -2900, -3200, 0, "Yield")
node("V2", -2300, -3150, 0, "Signals", "Vauclair")
node("V3", -2250, -2750, 0, "Signals")
node("V4", -2850, -2700, 0, "Yield")
road("RUE-V-N", "Rue", "V1", "V2", nil, "Grand-Rue de Vauclair")
road("RUE-V-E", "Rue", "V2", "V3", nil, "Rue du Lavoir")
road("RUE-V-S", "Rue", "V3", "V4", nil, "Rue des Vergers")
road("RUE-V-O", "Rue", "V4", "V1", nil, "Rue de la Fontaine")
district("VAUCLAIR", "Village", { "V1", "V2", "V3", "V4" }, -7, 85, 140, "Rue", 5201, 0.25)

node("ES", -3800, -1900, 0, "Signals", "Les Essarts")
node("PEUP_E", -2200, -4500, 0, "Yield")
node("PEUP_C", -1650, -4450, 0, "Yield")
node("PEUP_M", -3000, -4480, 0, "Yield")
node("PEUP_W", -4200, -4450, 0, "Yield")
road("D1", "Departementale", "A2_1", "V3", { { -1200, -2650 } }, "D1")
road("D2", "Departementale", "V4", "ES", { { -3350, -2350 } }, "D2")
road("D3", "Departementale", "NW2", "ES", nil, "D3")
road("D4-1", "Departementale", "A2_N", "PEUP_C", nil, "Ligne droite des Peupliers")
road("D4-2", "Departementale", "PEUP_C", "PEUP_E", nil, "Ligne droite des Peupliers")
road("D4-3", "Departementale", "PEUP_E", "PEUP_M", nil, "Ligne droite des Peupliers")
road("D4-4", "Departementale", "PEUP_M", "PEUP_W", nil, "Ligne droite des Peupliers")
road("D5", "Departementale", "A2_2", "SA4", { { -250, -3750 } }, "D5")
road("D6", "Departementale", "A2_N", "SA1", { { -500, -4380 } }, "D6")
road("D7", "Departementale", "PEUP_W", "ES", { { -4000, -3300 }, { -3900, -2500 } }, "D7")
road("D8", "Departementale", "V1", "PEUP_M", { { -2950, -3850 } }, "D8")
road("CH-1", "Chemin", "V2", "PEUP_C", { { -1950, -3500 }, { -1700, -4000 } }, "Chemin des Bois")

-- ======================== COMPLEXE MOTORSPORT ========================

node("MS_P", -4300, 0, 0, "Signals", "Paddock")
node("MS_N", -4400, -1300, 0, "Yield")
node("CIR_S", -4500, -400, 0, "Yield", "Ligne de départ")
node("CIR_N", -4510, -1150, 0, "None")
node("DRAG_A", -4150, -150, 0, "Yield", "Départ du drag")
node("DRAG_B", -4150, -800, 0, "Yield")
node("DRIFT", -4100, -960, 0, "None", "Zone de drift")
node("TECH_A", -3950, -250, 0, "Yield", "Parcours technique")
node("TECH_B", -3790, -520, 0, "None")
road("MS-ACCES", "Avenue", "A1_00", "MS_P", nil, "Allée du Paddock")
road("MS-NORD", "Departementale", "MS_P", "MS_N", { { -4350, -650 } }, "Route du Circuit")
road("D9", "Departementale", "MS_N", "ES", nil, "D9")
road("MS-STANDS", "Rue", "MS_P", "CIR_S", nil, "Voie des stands")
-- Circuit (environ 3,2 km) : deux tronçons formant la boucle.
road("CIRCUIT-1", "Piste", "CIR_S", "CIR_N", nil, "Circuit — ligne droite")
road("CIRCUIT-2", "Piste", "CIR_N", "CIR_S", {
    { -4600, -1260 },
    { -4800, -1230 },
    { -4870, -1000 },
    { -4800, -820 },
    { -4900, -600 },
    { -4900, -320 },
    { -4800, -140 },
    { -4620, -100 },
}, "Circuit")
road("DRAG-1", "Piste", "DRAG_A", "DRAG_B", nil, "Ligne droite de drag (402 m + dégagement)")
road("DRAG-ACC", "Rue", "MS_P", "DRAG_A", nil, "Accès au drag")
road("DRIFT-ACC", "Rue", "DRAG_B", "DRIFT", nil, "Accès à la zone de drift")
road("TECH-ACC", "Rue", "MS_P", "TECH_A", nil, "Accès au parcours technique")
road("TECH-1", "Piste", "TECH_A", "TECH_B", { { -3800, -320 } }, "Parcours technique")
road("TECH-2", "Piste", "TECH_B", "TECH_A", { { -3900, -600 }, { -3990, -430 } }, "Parcours technique")
-- Spéciale de rallye (chemin gravillonné, fermé au trafic).
road("RALLYE-1", "Chemin", "MS_N", "PEUP_W", {
    { -4650, -2000 },
    { -4750, -2800 },
    { -4600, -3600 },
}, "Spéciale des Bois")

-- ======================== LITTORAL ========================

node("L_W", -3400, 3200, 0, "Yield", "Pointe de l'Ouest")
node("L_1", -1000, 3420, 0, "Signals")
node("L0", 0, 3400, 0, "Signals", "Port-Soleil")
node("L_2", 1500, 3380, 5, "Yield")
node("L_3", 3000, 3250, 35, "None", "Belvédère des Falaises")
node("L_4", 3700, 2400, 15, "Yield")
node("PS_NW", -1000, 3150, 0, "Signals")
node("PS_NE", -50, 3150, 0, "Signals")
road("D10-1", "Departementale", "L_W", "L_1", { { -2500, 3330 }, { -1700, 3420 } }, "Corniche du Littoral")
road("D10-2", "Departementale", "L_1", "L0", nil, "Promenade de Port-Soleil")
road("D10-3", "Departementale", "L0", "L_2", { { 700, 3420 } }, "Corniche du Littoral")
road("D10-4", "Departementale", "L_2", "L_3", { { 2200, 3450, 22 } }, "Route des Falaises")
road("D10-5", "Departementale", "L_3", "L_4", { { 3500, 2950, 28 } }, "Route des Falaises")
road("D10-6", "Departementale", "L_4", "D2", { { 3880, 2000, 6 } }, "Route des Falaises")
road("D11", "Departementale", "L_W", "A1_00", { { -3950, 2600 }, { -4350, 1700 }, { -4500, 900 } }, "D11")
road("BD-PLAGE", "Avenue", "PS_NW", "PS_NE", nil, "Boulevard de la Plage")
road("AV-PORT-SOLEIL", "Avenue", "PS_NE", "L0", nil, "Avenue de Port-Soleil")
road("RUE-PHARE", "Avenue", "L_1", "PS_NW", nil, "Rue du Phare")
road("ACC-PLAGE", "Avenue", "PS_NE", "A1_02", nil, "Accès de la Plage")
district("PORT-SOLEIL", "Balneaire", { "PS_NW", "PS_NE", "L0", "L_1" }, 3, 60, 85, "Rue", 6101, 0.15)

return table.freeze({
    Version = WorldConfig.MapVersion,
    Nodes = nodes,
    Roads = roads,
    Districts = districts,
})
