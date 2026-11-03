--!strict
--[[
    Parcours de course VERSIONNÉS (lot 0.6, §6). Chaque parcours a un
    identifiant stable et une version : un changement de tracé incrémente la
    version, ce qui sépare ses records et classements des anciens.

    Monde ouvert : le tracé est une suite de ROUTES de la carte du lot 0.3
    (identifiants de World/Data/MapData), parcourues dans le sens indiqué ;
    RaceCourse.validate vérifie qu'elles s'enchaînent sur le graphe routier
    (même carrefour), que la longueur déclarée correspond au tracé, que la zone
    et les revêtements déclarés sont ceux de la carte. Place de développement :
    points en mètres sur la zone d'essai (aucune route).

    Champs :
    - Discipline, Place ("OpenWorld" | "Dev"), Zone (zone de la carte), Area, Name ;
    - Roads { Id, Reverse? } ou Points { X, Z } ; Closed (boucle) ; Laps ;
    - Direction : sens de parcours (indication lisible) ;
    - StartOffsetM : distance du départ après le début du tracé ;
      FinishOffsetM : distance de l'arrivée avant la fin (tracé ouvert) ;
      DistanceM : drag, distance chronométrée ;
    - LengthM : longueur DÉCLARÉE d'un tour ou du tracé (contrôlée à ±5 %) ;
    - Surface : revêtements déclarés ("Asphalt", "Gravel") ;
    - Difficulty (1 à 3) ; RefSpeedKmh : vitesse de référence (temps de
      référence = longueur / vitesse) ; ParScore : drift ;
    - MinParticipants, MaxParticipants ; Kinds : types d'épreuve autorisés ;
    - Conditions : conditions standardisées des épreuves normalisées ;
    - Zone de drift : DriftCenter { X, Z }, DriftRadiusM.
    Les valeurs de référence (vitesses, scores) sont provisoires et réglables.
]]

local RaceCourses = {}

RaceCourses.Version = "0.6.0"

export type RoadRef = { Id: string, Reverse: boolean? }
export type Point = { X: number, Z: number }

export type Course = {
    Id: string,
    Version: number,
    Discipline: string,
    Place: "OpenWorld" | "Dev",
    Zone: string, -- zone de la carte (contrôlée)
    Area: string?, -- lieu lisible quand il diffère de la zone (périphérique)
    Name: string,
    Roads: { RoadRef }?,
    Points: { Point }?,
    Closed: boolean,
    Laps: number,
    Direction: string,
    StartOffsetM: number,
    FinishOffsetM: number,
    DistanceM: number?,
    LengthM: number,
    Surface: { string },
    Difficulty: number,
    RefSpeedKmh: number,
    ParScore: number?,
    MinParticipants: number,
    MaxParticipants: number,
    Kinds: { string },
    Conditions: string,
    DriftCenter: Point?,
    DriftRadiusM: number?,
    CheckpointSpacingM: number?,
}

local ALL = { "Official", "Ranked", "Private", "Training" }
local UNRANKED = { "Official", "Private", "Training" }

local COURSES: { Course } = {}

local function course(c: Course)
    table.insert(COURSES, table.freeze(c))
end

-- ======================== MONDE OUVERT ========================

-- Complexe motorsport : pistes fermées (sans circulation), records éligibles.
course({
    Id = "CIR-MS-GP",
    Version = 1,
    Discipline = "Circuit",
    Place = "OpenWorld",
    Zone = "Motorsport",
    Name = "Grand Circuit du Complexe",
    Roads = { { Id = "CIRCUIT-1" }, { Id = "CIRCUIT-2" } },
    Closed = true,
    Laps = 3,
    Direction = "Horaire (ligne droite vers le nord)",
    StartOffsetM = 60,
    FinishOffsetM = 0,
    LengthM = 2800,
    Surface = { "Asphalt" },
    Difficulty = 2,
    RefSpeedKmh = 125,
    MinParticipants = 1,
    MaxParticipants = 12,
    Kinds = ALL,
    Conditions = "Sec-v1",
})
course({
    Id = "CIR-MS-TECH",
    Version = 1,
    Discipline = "Circuit",
    Place = "OpenWorld",
    Zone = "Motorsport",
    Name = "Parcours technique",
    Roads = { { Id = "TECH-1" }, { Id = "TECH-2" } },
    Closed = true,
    Laps = 5,
    Direction = "Horaire",
    StartOffsetM = 20,
    FinishOffsetM = 0,
    LengthM = 895,
    Surface = { "Asphalt" },
    Difficulty = 3,
    RefSpeedKmh = 85,
    MinParticipants = 1,
    MaxParticipants = 8,
    Kinds = ALL,
    Conditions = "Sec-v1",
})
course({
    Id = "TT-MS-GP",
    Version = 1,
    Discipline = "TimeTrial",
    Place = "OpenWorld",
    Zone = "Motorsport",
    Name = "Tour chronométré du Grand Circuit",
    Roads = { { Id = "CIRCUIT-1" }, { Id = "CIRCUIT-2" } },
    Closed = true,
    Laps = 1,
    Direction = "Horaire",
    StartOffsetM = 60,
    FinishOffsetM = 0,
    LengthM = 2800,
    Surface = { "Asphalt" },
    Difficulty = 2,
    RefSpeedKmh = 125,
    MinParticipants = 1,
    MaxParticipants = 8,
    Kinds = UNRANKED,
    Conditions = "Sec-v1",
})
course({
    Id = "DRG-MS-402",
    Version = 1,
    Discipline = "Drag",
    Place = "OpenWorld",
    Zone = "Motorsport",
    Name = "Drag 402 m",
    Roads = { { Id = "DRAG-1" } },
    Closed = false,
    Laps = 1,
    Direction = "Vers le nord",
    StartOffsetM = 20,
    FinishOffsetM = 0,
    DistanceM = 402,
    LengthM = 650,
    Surface = { "Asphalt" },
    Difficulty = 1,
    RefSpeedKmh = 110,
    MinParticipants = 1,
    MaxParticipants = 2,
    Kinds = UNRANKED,
    Conditions = "Sec-v1",
})
course({
    Id = "DRG-MS-201",
    Version = 1,
    Discipline = "Drag",
    Place = "OpenWorld",
    Zone = "Motorsport",
    Name = "Drag 201 m",
    Roads = { { Id = "DRAG-1" } },
    Closed = false,
    Laps = 1,
    Direction = "Vers le nord",
    StartOffsetM = 20,
    FinishOffsetM = 0,
    DistanceM = 201,
    LengthM = 650,
    Surface = { "Asphalt" },
    Difficulty = 1,
    RefSpeedKmh = 90,
    MinParticipants = 1,
    MaxParticipants = 2,
    Kinds = UNRANKED,
    Conditions = "Sec-v1",
})
course({
    Id = "DRF-MS-ZONE",
    Version = 1,
    Discipline = "Drift",
    Place = "OpenWorld",
    Zone = "Motorsport",
    Name = "Zone de drift du Complexe",
    -- Accès : arrivée de la route d'accès ; la session se joue dans la zone.
    Roads = { { Id = "DRIFT-ACC" } },
    Closed = false,
    Laps = 1,
    Direction = "Libre dans la zone",
    StartOffsetM = 0,
    FinishOffsetM = 0,
    LengthM = 168,
    Surface = { "Asphalt" },
    Difficulty = 2,
    RefSpeedKmh = 50,
    ParScore = 12_000,
    MinParticipants = 1,
    MaxParticipants = 6,
    Kinds = ALL,
    Conditions = "Sec-v1",
    DriftCenter = { X = -4080, Z = -1060 },
    DriftRadiusM = 70,
})
course({
    Id = "RAL-MS-FORET",
    Version = 1,
    Discipline = "Rally",
    Place = "OpenWorld",
    Zone = "Motorsport",
    Name = "Spéciale de la Forêt",
    Roads = { { Id = "RALLYE-1" } },
    Closed = false,
    Laps = 1,
    Direction = "Du complexe vers les Peupliers",
    StartOffsetM = 30,
    FinishOffsetM = 30,
    LengthM = 3300,
    Surface = { "Gravel" },
    Difficulty = 3,
    RefSpeedKmh = 70,
    MinParticipants = 1,
    MaxParticipants = 8,
    Kinds = UNRANKED,
    Conditions = "Sec-v1",
})

-- Métropole et périphérique : routes ouvertes (circulation PNJ) : pas de records.
course({
    Id = "SPR-METRO-01",
    Version = 1,
    Discipline = "Sprint",
    Place = "OpenWorld",
    Zone = "Metropole",
    Name = "Traversée du Cours",
    Roads = {
        { Id = "AV-NORD-C" },
        { Id = "COURS-2" },
        { Id = "COURS-3" },
        { Id = "RAD-06" },
        { Id = "BD-EXT-06" },
        { Id = "BD-EXT-07" },
    },
    Closed = false,
    Laps = 1,
    Direction = "Place Centrale → Boulevard Extérieur (est)",
    StartOffsetM = 25,
    FinishOffsetM = 25,
    LengthM = 2600,
    Surface = { "Asphalt" },
    Difficulty = 2,
    RefSpeedKmh = 75,
    MinParticipants = 1,
    MaxParticipants = 8,
    Kinds = ALL,
    Conditions = "Sec-v1",
})
course({
    Id = "SPR-PERI-01",
    Version = 1,
    Discipline = "Sprint",
    Place = "OpenWorld",
    Zone = "Metropole",
    Area = "Périphérique",
    Name = "Quart de périphérique",
    Roads = { { Id = "PERI-00" }, { Id = "PERI-03" } },
    Closed = false,
    Laps = 1,
    Direction = "Échangeur 00 → Échangeur 06 (sens horaire)",
    StartOffsetM = 60,
    FinishOffsetM = 60,
    LengthM = 2355,
    Surface = { "Asphalt" },
    Difficulty = 1,
    RefSpeedKmh = 125,
    MinParticipants = 1,
    MaxParticipants = 8,
    Kinds = ALL,
    Conditions = "Sec-v1",
    CheckpointSpacingM = 300,
})
course({
    Id = "TT-PERI-TOUR",
    Version = 1,
    Discipline = "TimeTrial",
    Place = "OpenWorld",
    Zone = "Metropole",
    Area = "Périphérique",
    Name = "Tour du périphérique",
    Roads = {
        { Id = "PERI-00" },
        { Id = "PERI-03" },
        { Id = "PERI-06" },
        { Id = "PERI-09" },
        { Id = "PERI-12" },
        { Id = "PERI-15" },
        { Id = "PERI-18" },
        { Id = "PERI-21" },
    },
    Closed = true,
    Laps = 1,
    Direction = "Sens horaire",
    StartOffsetM = 60,
    FinishOffsetM = 0,
    LengthM = 9400,
    Surface = { "Asphalt" },
    Difficulty = 2,
    RefSpeedKmh = 125,
    MinParticipants = 1,
    MaxParticipants = 8,
    Kinds = UNRANKED,
    Conditions = "Sec-v1",
    CheckpointSpacingM = 400,
})

-- Cols de montagne.
course({
    Id = "RAL-COL-RAVIN",
    Version = 1,
    Discipline = "Rally",
    Place = "OpenWorld",
    Zone = "Montagnes",
    Name = "Spéciale du Grand Ravin",
    Roads = { { Id = "M1-1" }, { Id = "M1-2" } },
    Closed = false,
    Laps = 1,
    Direction = "Échangeur des Cols → Carrefour du Lac",
    StartOffsetM = 60,
    FinishOffsetM = 30,
    LengthM = 4250,
    Surface = { "Asphalt" },
    Difficulty = 3,
    RefSpeedKmh = 65,
    MinParticipants = 1,
    MaxParticipants = 8,
    Kinds = UNRANKED,
    Conditions = "Sec-v1",
})
course({
    Id = "SPR-COL-BELV",
    Version = 1,
    Discipline = "Sprint",
    Place = "OpenWorld",
    Zone = "Montagnes",
    Name = "Montée du Belvédère",
    Roads = { { Id = "M2-1" } },
    Closed = false,
    Laps = 1,
    Direction = "Col du Grand Ravin → Belvédère des Crêtes",
    StartOffsetM = 30,
    FinishOffsetM = 30,
    LengthM = 1910,
    Surface = { "Asphalt" },
    Difficulty = 2,
    RefSpeedKmh = 70,
    MinParticipants = 1,
    MaxParticipants = 6,
    Kinds = UNRANKED,
    Conditions = "Sec-v1",
})

-- Campagne.
course({
    Id = "RAL-CAMP-BOIS",
    Version = 1,
    Discipline = "Rally",
    Place = "OpenWorld",
    Zone = "Campagne",
    Name = "Spéciale des Bois",
    Roads = { { Id = "CH-1" }, { Id = "D4-2" } },
    Closed = false,
    Laps = 1,
    Direction = "Vauclair → Les Peupliers (est)",
    StartOffsetM = 30,
    FinishOffsetM = 30,
    LengthM = 2065,
    Surface = { "Gravel", "Asphalt" },
    Difficulty = 2,
    RefSpeedKmh = 70,
    MinParticipants = 1,
    MaxParticipants = 8,
    Kinds = UNRANKED,
    Conditions = "Sec-v1",
})
course({
    Id = "SPR-CAMP-PEUP",
    Version = 1,
    Discipline = "Sprint",
    Place = "OpenWorld",
    Zone = "Campagne",
    Name = "Ligne droite des Peupliers",
    Roads = { { Id = "D4-1" }, { Id = "D4-2" }, { Id = "D4-3" } },
    Closed = false,
    Laps = 1,
    Direction = "Carrefour du Nord → ouest",
    StartOffsetM = 40,
    FinishOffsetM = 40,
    LengthM = 1905,
    Surface = { "Asphalt" },
    Difficulty = 1,
    RefSpeedKmh = 110,
    MinParticipants = 1,
    MaxParticipants = 8,
    Kinds = UNRANKED,
    Conditions = "Sec-v1",
})

-- Littoral.
course({
    Id = "SPR-LIT-CORN",
    Version = 1,
    Discipline = "Sprint",
    Place = "OpenWorld",
    Zone = "Littoral",
    Name = "Corniche du Littoral",
    Roads = { { Id = "D10-1" }, { Id = "D10-2" } },
    Closed = false,
    Laps = 1,
    Direction = "Pointe de l'Ouest → Port-Soleil",
    StartOffsetM = 40,
    FinishOffsetM = 40,
    LengthM = 3400,
    Surface = { "Asphalt" },
    Difficulty = 2,
    RefSpeedKmh = 95,
    MinParticipants = 1,
    MaxParticipants = 8,
    Kinds = UNRANKED,
    Conditions = "Sec-v1",
})
course({
    Id = "TT-LIT-FAL",
    Version = 1,
    Discipline = "TimeTrial",
    Place = "OpenWorld",
    Zone = "Littoral",
    Name = "Route des Falaises",
    Roads = { { Id = "D10-3" }, { Id = "D10-4" }, { Id = "D10-5" } },
    Closed = false,
    Laps = 1,
    Direction = "Port-Soleil → falaises de l'est",
    StartOffsetM = 40,
    FinishOffsetM = 40,
    LengthM = 4210,
    Surface = { "Asphalt" },
    Difficulty = 2,
    RefSpeedKmh = 90,
    MinParticipants = 1,
    MaxParticipants = 8,
    Kinds = UNRANKED,
    Conditions = "Sec-v1",
})

-- ======================== PLACE DE DÉVELOPPEMENT ========================
-- Zone d'essai (sol plat) : une épreuve par discipline, à l'écart des plots,
-- de la bosse et des bordures. Coordonnées en mètres.

course({
    Id = "DEV-SPRINT",
    Version = 1,
    Discipline = "Sprint",
    Place = "Dev",
    Zone = "Essai",
    Name = "Sprint d'essai",
    Points = {
        { X = -40, Z = -40 },
        { X = -40, Z = -180 },
        { X = 20, Z = -280 },
        { X = 110, Z = -280 },
        { X = 170, Z = -200 },
    },
    Closed = false,
    Laps = 1,
    Direction = "Nord puis est",
    StartOffsetM = 0,
    FinishOffsetM = 0,
    LengthM = 470,
    Surface = { "Asphalt" },
    Difficulty = 1,
    RefSpeedKmh = 70,
    MinParticipants = 1,
    MaxParticipants = 8,
    Kinds = ALL,
    Conditions = "Sec-v1",
    CheckpointSpacingM = 90,
})
course({
    Id = "DEV-CIRCUIT",
    Version = 1,
    Discipline = "Circuit",
    Place = "Dev",
    Zone = "Essai",
    Name = "Circuit d'essai",
    Points = {
        { X = -60, Z = -200 },
        { X = -60, Z = -290 },
        { X = 60, Z = -290 },
        { X = 60, Z = -200 },
    },
    Closed = true,
    Laps = 3,
    Direction = "Horaire",
    StartOffsetM = 15,
    FinishOffsetM = 0,
    LengthM = 420,
    Surface = { "Asphalt" },
    Difficulty = 1,
    RefSpeedKmh = 60,
    MinParticipants = 1,
    MaxParticipants = 8,
    Kinds = ALL,
    Conditions = "Sec-v1",
    CheckpointSpacingM = 70,
})
course({
    Id = "DEV-TT",
    Version = 1,
    Discipline = "TimeTrial",
    Place = "Dev",
    Zone = "Essai",
    Name = "Contre-la-montre d'essai",
    Points = {
        { X = 160, Z = -20 },
        { X = 170, Z = -150 },
        { X = 170, Z = -280 },
        { X = 100, Z = -300 },
    },
    Closed = false,
    Laps = 1,
    Direction = "Nord",
    StartOffsetM = 0,
    FinishOffsetM = 0,
    LengthM = 335,
    Surface = { "Asphalt" },
    Difficulty = 1,
    RefSpeedKmh = 70,
    MinParticipants = 1,
    MaxParticipants = 8,
    Kinds = UNRANKED,
    Conditions = "Sec-v1",
    CheckpointSpacingM = 80,
})
course({
    Id = "DEV-DRAG",
    Version = 1,
    Discipline = "Drag",
    Place = "Dev",
    Zone = "Essai",
    Name = "Drag d'essai 201 m",
    Points = { { X = 0, Z = -3 }, { X = 0, Z = -250 } },
    Closed = false,
    Laps = 1,
    Direction = "Nord (ligne droite d'essai)",
    StartOffsetM = 0,
    FinishOffsetM = 0,
    DistanceM = 201,
    LengthM = 247,
    Surface = { "Asphalt" },
    Difficulty = 1,
    RefSpeedKmh = 90,
    MinParticipants = 1,
    MaxParticipants = 2,
    Kinds = UNRANKED,
    Conditions = "Sec-v1",
})
course({
    Id = "DEV-DRIFT",
    Version = 1,
    Discipline = "Drift",
    Place = "Dev",
    Zone = "Essai",
    Name = "Drift d'essai (cercle)",
    Points = { { X = -84, Z = -70 }, { X = -84, Z = -86 } },
    Closed = false,
    Laps = 1,
    Direction = "Libre dans la zone",
    StartOffsetM = 0,
    FinishOffsetM = 0,
    LengthM = 16,
    Surface = { "Asphalt" },
    Difficulty = 1,
    RefSpeedKmh = 40,
    ParScore = 8_000,
    MinParticipants = 1,
    MaxParticipants = 4,
    Kinds = ALL,
    Conditions = "Sec-v1",
    DriftCenter = { X = -84, Z = -126 },
    DriftRadiusM = 45,
})
course({
    Id = "DEV-RALLY",
    Version = 1,
    Discipline = "Rally",
    Place = "Dev",
    Zone = "Essai",
    Name = "Spéciale d'essai (zone mouillée)",
    Points = {
        { X = -130, Z = 20 },
        { X = -130, Z = -80 },
        { X = -80, Z = -200 },
        { X = -150, Z = -280 },
        { X = -180, Z = -150 },
    },
    Closed = false,
    Laps = 1,
    Direction = "Sud puis boucle ouest",
    StartOffsetM = 0,
    FinishOffsetM = 0,
    LengthM = 470,
    Surface = { "Asphalt" },
    Difficulty = 2,
    RefSpeedKmh = 60,
    MinParticipants = 1,
    MaxParticipants = 6,
    Kinds = UNRANKED,
    Conditions = "Sec-v1",
    CheckpointSpacingM = 90,
})

RaceCourses.All = table.freeze(COURSES)

local byId: { [string]: Course } = {}
for _, c in COURSES do
    byId[c.Id] = c
end

function RaceCourses.get(id: any): Course?
    if type(id) ~= "string" then
        return nil
    end
    return byId[id]
end

function RaceCourses.forPlace(place: string): { Course }
    local list: { Course } = {}
    for _, c in COURSES do
        if c.Place == place then
            table.insert(list, c)
        end
    end
    return list
end

function RaceCourses.allows(c: Course, kind: string): boolean
    return table.find(c.Kinds, kind) ~= nil
end

-- Clé de classement / record : parcours, version et conditions.
function RaceCourses.recordKey(c: Course): string
    return string.format("%s:v%d:%s", c.Id, c.Version, c.Conditions)
end

return table.freeze(RaceCourses)
