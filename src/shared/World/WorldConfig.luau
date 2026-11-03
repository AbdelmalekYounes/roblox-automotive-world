--!strict
-- Configuration PURE du monde ouvert (lot 0.3) : version des données de carte,
-- échelle, emprise, classes de routes et zones. Les dimensions sont en mètres
-- (conversion en studs uniquement à la construction : 1 stud = 0,28 m, A5).
--
-- Dimensionnement (voir docs/lot-0.3/RAPPORT_LOT_0.3.md) : le trajet autoroutier
-- de référence (A1, du complexe motorsport aux montagnes) doit durer 6 à 10 min
-- à une vitesse de croisière crédible des prototypes (110 à 130 km/h, P-01
-- mesuré à 0–100 km/h en 8,9 s et capable de bien plus) ; il mesure donc
-- 12 à 17 km. La carte tient dans un carré de 10 km de côté (± 17 857 studs
-- autour de l'origine, loin des limites de précision de Roblox).

local WorldConfig = {}

-- Toute modification des données de carte incrémente cette version (les
-- identifiants de routes, carrefours et services en dépendent).
WorldConfig.MapVersion = "0.3.0"
WorldConfig.MetersPerStud = 0.28
WorldConfig.HalfExtentM = 5000
-- Altitude du niveau de la mer (m) et du fond marin.
WorldConfig.SeaLevelM = -1.5
WorldConfig.SeaFloorM = -8

-- Trajet de référence : vitesses de croisière retenues pour l'estimation.
WorldConfig.ReferenceCruiseKmh = { Low = 110, High = 130 }
WorldConfig.ReferenceTripMinutes = { Min = 6, Max = 10 }

export type RoadClassId =
    "Autoroute"
    | "Peripherique"
    | "VoieRapide"
    | "Bretelle"
    | "Avenue"
    | "Rue"
    | "Departementale"
    | "Montagne"
    | "Chemin"
    | "Piste"

export type RoadClass = {
    Id: RoadClassId,
    Label: string,
    LanesPerDirection: number,
    LaneWidthM: number,
    ShoulderM: number, -- accotement de chaque côté (bande d'arrêt, bas-côté)
    SidewalkM: number, -- trottoir de chaque côté (0 = aucun)
    MedianM: number, -- terre-plein central
    SpeedKmh: number,
    Material: string, -- nom de matériau Roblox (adhérence : SurfaceFriction)
    Barriers: "None" | "Edges" | "EdgesAndMedian",
    Rank: number, -- priorité aux carrefours (plus grand = prioritaire)
    Traffic: boolean, -- ouverte au trafic PNJ
    Pedestrians: boolean,
}

local function class(props: RoadClass): RoadClass
    return table.freeze(props)
end

-- Largeurs inspirées des normes routières usuelles (voies de 3,25 à 3,5 m).
WorldConfig.RoadClasses = table.freeze({
    Autoroute = class({
        Id = "Autoroute",
        Label = "Autoroute",
        LanesPerDirection = 3,
        LaneWidthM = 3.5,
        ShoulderM = 2.5,
        SidewalkM = 0,
        MedianM = 3,
        SpeedKmh = 130,
        Material = "Asphalt",
        Barriers = "EdgesAndMedian",
        Rank = 6,
        Traffic = true,
        Pedestrians = false,
    }),
    Peripherique = class({
        Id = "Peripherique",
        Label = "Périphérique",
        LanesPerDirection = 2,
        LaneWidthM = 3.5,
        ShoulderM = 2,
        SidewalkM = 0,
        MedianM = 2,
        SpeedKmh = 90,
        Material = "Asphalt",
        Barriers = "EdgesAndMedian",
        Rank = 6,
        Traffic = true,
        Pedestrians = false,
    }),
    VoieRapide = class({
        Id = "VoieRapide",
        Label = "Voie rapide",
        LanesPerDirection = 2,
        LaneWidthM = 3.5,
        ShoulderM = 1.5,
        SidewalkM = 0,
        MedianM = 2,
        SpeedKmh = 110,
        Material = "Asphalt",
        Barriers = "EdgesAndMedian",
        Rank = 5,
        Traffic = true,
        Pedestrians = false,
    }),
    Bretelle = class({
        Id = "Bretelle",
        Label = "Bretelle",
        LanesPerDirection = 1,
        LaneWidthM = 3.75,
        ShoulderM = 1.5,
        SidewalkM = 0,
        MedianM = 1,
        SpeedKmh = 70,
        Material = "Asphalt",
        Barriers = "Edges",
        Rank = 4,
        Traffic = true,
        Pedestrians = false,
    }),
    Avenue = class({
        Id = "Avenue",
        Label = "Avenue",
        LanesPerDirection = 2,
        LaneWidthM = 3.25,
        ShoulderM = 0.5,
        SidewalkM = 4,
        MedianM = 1.5,
        SpeedKmh = 50,
        Material = "Asphalt",
        Barriers = "None",
        Rank = 4,
        Traffic = true,
        Pedestrians = true,
    }),
    Rue = class({
        Id = "Rue",
        Label = "Rue",
        LanesPerDirection = 1,
        LaneWidthM = 3.25,
        ShoulderM = 1,
        SidewalkM = 2.5,
        MedianM = 0,
        SpeedKmh = 40,
        Material = "Asphalt",
        Barriers = "None",
        Rank = 2,
        Traffic = true,
        Pedestrians = true,
    }),
    Departementale = class({
        Id = "Departementale",
        Label = "Route départementale",
        LanesPerDirection = 1,
        LaneWidthM = 3.5,
        ShoulderM = 1,
        SidewalkM = 0,
        MedianM = 0,
        SpeedKmh = 80,
        Material = "Asphalt",
        Barriers = "None",
        Rank = 3,
        Traffic = true,
        Pedestrians = false,
    }),
    Montagne = class({
        Id = "Montagne",
        Label = "Route de montagne",
        LanesPerDirection = 1,
        LaneWidthM = 3.25,
        ShoulderM = 0.75,
        SidewalkM = 0,
        MedianM = 0,
        SpeedKmh = 60,
        Material = "Asphalt",
        Barriers = "Edges",
        Rank = 3,
        Traffic = true,
        Pedestrians = false,
    }),
    Chemin = class({
        Id = "Chemin",
        Label = "Chemin",
        LanesPerDirection = 1,
        LaneWidthM = 2.75,
        ShoulderM = 0.5,
        SidewalkM = 0,
        MedianM = 0,
        SpeedKmh = 40,
        Material = "Gravel",
        Barriers = "None",
        Rank = 1,
        Traffic = false,
        Pedestrians = false,
    }),
    Piste = class({
        Id = "Piste",
        Label = "Piste de course",
        LanesPerDirection = 1,
        LaneWidthM = 6,
        ShoulderM = 3,
        SidewalkM = 0,
        MedianM = 0,
        SpeedKmh = 250,
        Material = "Asphalt",
        Barriers = "Edges",
        Rank = 1,
        Traffic = false,
        Pedestrians = false,
    }),
}) :: { [string]: RoadClass }

-- Largeur de chaussée (voies + terre-plein + accotements), hors trottoirs.
function WorldConfig.carriagewayWidthM(roadClass: RoadClass): number
    return 2 * (roadClass.LanesPerDirection * roadClass.LaneWidthM + roadClass.ShoulderM) + roadClass.MedianM
end

-- Emprise totale (chaussée + trottoirs).
function WorldConfig.corridorWidthM(roadClass: RoadClass): number
    return WorldConfig.carriagewayWidthM(roadClass) + 2 * roadClass.SidewalkM
end

export type ZoneId = "Metropole" | "Banlieues" | "Docks" | "Montagnes" | "Campagne" | "Motorsport" | "Littoral"

-- Ordre officiel des sept zones (cahier des charges §2.1).
local ZONE_IDS: { ZoneId } = {
    "Metropole",
    "Banlieues",
    "Docks",
    "Montagnes",
    "Campagne",
    "Motorsport",
    "Littoral",
}
WorldConfig.ZoneIds = table.freeze(ZONE_IDS)

-- Densités relatives (0 à 1) : trafic PNJ et piétons, ajustables sans code.
WorldConfig.ZoneDensity = table.freeze({
    Metropole = table.freeze({ Traffic = 1.0, Pedestrians = 1.0 }),
    Banlieues = table.freeze({ Traffic = 0.6, Pedestrians = 0.4 }),
    Docks = table.freeze({ Traffic = 0.5, Pedestrians = 0.1 }),
    Montagnes = table.freeze({ Traffic = 0.2, Pedestrians = 0.0 }),
    Campagne = table.freeze({ Traffic = 0.25, Pedestrians = 0.15 }),
    Motorsport = table.freeze({ Traffic = 0.1, Pedestrians = 0.2 }),
    Littoral = table.freeze({ Traffic = 0.45, Pedestrians = 0.6 }),
})

-- Nombre de services exigés par le cahier des charges (§2.2).
WorldConfig.RequiredServices = table.freeze({
    Dealership = 2,
    PublicGarage = 3,
    FuelStation = 6,
    CarWash = 3,
    ChargingZonesMin = 7, -- au moins un point public par zone
})

return table.freeze(WorldConfig)
