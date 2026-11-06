--!strict
--[[
    Lot PNJ-01 : contrat des modèles 3D des voitures PNJ et des piétons (module PUR, testé par Lune).

    Décisions du propriétaire (2026-11-06) : modèles TIERS sous licence CC (téléchargés par le propriétaire, préparés
    dans le dépôt d'art, maillages envoyés sur Roblox par lui seul) ; 4 silhouettes de voitures d'environ 2 000
    triangles ; piétons humains low-poly DÉCOUPÉS en pièces rigides et animés par le code (World/PedestrianGait).

    Tant qu'un gabarit n'est pas présent dans `ReplicatedStorage.AutomotiveWorldPnjKits` ET que chacun de ses
    maillages n'est pas inscrit au manifeste d'actifs, le jeu construit un REPLI en pièces simples ayant les mêmes
    noms, les mêmes cotes et les mêmes articulations : le comportement (roues, feux, animation) est le même.

    Repères :
    - voiture : mètres, origine au sol au centre de l'empattement, avant vers −Z, droite vers +X ;
    - piéton : mètres, origine au sol entre les pieds, regard vers −Z, sa GAUCHE vers −X.
]]

local PnjKits = {}

-- Dossier des gabarits (répliqué : les piétons sont rendus par chaque client, les voitures par le serveur).
PnjKits.FolderName = "AutomotiveWorldPnjKits"
-- Entrées du manifeste d'actifs qui listeront les identifiants autorisés (à créer à l'intégration des maillages).
PnjKits.CarManifestId = "world.pnj.cars"
PnjKits.PedestrianManifestId = "world.pnj.pedestrians"

-- Garde au sol de la boîte de collision (m) : la caisse physique flotte au-dessus de la chaussée (TrafficService).
PnjKits.ClearanceM = 0.3

export type CarSilhouette = {
    Id: string,
    Template: string, -- nom du modèle dans le dossier des gabarits
    Weight: number, -- part dans le trafic (somme normalisée au tirage)
    LengthM: number,
    WidthM: number,
    HeightM: number, -- hauteur hors tout
    BoxHeightM: number, -- hauteur de la boîte de collision (au-dessus de la garde au sol)
    WheelbaseM: number,
    TrackM: number, -- voie (entre centres des roues)
    WheelRadiusM: number,
    WheelWidthM: number,
    -- Habitacle du repli : longueur, hauteur, décalage du centre vers l'arrière (+Z).
    CabinLengthM: number,
    CabinHeightM: number,
    CabinOffsetM: number,
}

-- Cotes réalistes de catégories courantes (ordres de grandeur, aucune voiture réelle visée).
local cars: { CarSilhouette } = {
    {
        Id = "Citadine",
        Template = "PNJ_Citadine",
        Weight = 0.35,
        LengthM = 3.95,
        WidthM = 1.75,
        HeightM = 1.50,
        BoxHeightM = 0.85,
        WheelbaseM = 2.50,
        TrackM = 1.50,
        WheelRadiusM = 0.30,
        WheelWidthM = 0.19,
        CabinLengthM = 2.10,
        CabinHeightM = 0.55,
        CabinOffsetM = 0.25,
    },
    {
        Id = "Berline",
        Template = "PNJ_Berline",
        Weight = 0.30,
        LengthM = 4.65,
        WidthM = 1.82,
        HeightM = 1.45,
        BoxHeightM = 0.80,
        WheelbaseM = 2.80,
        TrackM = 1.56,
        WheelRadiusM = 0.32,
        WheelWidthM = 0.21,
        CabinLengthM = 2.30,
        CabinHeightM = 0.52,
        CabinOffsetM = 0.15,
    },
    {
        Id = "SUV",
        Template = "PNJ_SUV",
        Weight = 0.25,
        LengthM = 4.55,
        WidthM = 1.86,
        HeightM = 1.68,
        BoxHeightM = 0.95,
        WheelbaseM = 2.72,
        TrackM = 1.58,
        WheelRadiusM = 0.36,
        WheelWidthM = 0.23,
        CabinLengthM = 2.60,
        CabinHeightM = 0.62,
        CabinOffsetM = 0.30,
    },
    {
        Id = "Utilitaire",
        Template = "PNJ_Utilitaire",
        Weight = 0.10,
        LengthM = 5.20,
        WidthM = 2.00,
        HeightM = 2.25,
        BoxHeightM = 1.20,
        WheelbaseM = 3.25,
        TrackM = 1.70,
        WheelRadiusM = 0.34,
        WheelWidthM = 0.22,
        CabinLengthM = 4.30,
        CabinHeightM = 0.85,
        CabinOffsetM = 0.40,
    },
}
for _, item in cars do
    table.freeze(item)
end
PnjKits.Cars = table.freeze(cars)

-- Pièces nommées d'une voiture (gabarit 3D et repli). Roues : avant/arrière, gauche/droite.
PnjKits.Wheels = table.freeze({ "Roue_AVG", "Roue_AVD", "Roue_ARG", "Roue_ARD" })
PnjKits.CarLights = table.freeze({
    Brake = table.freeze({ "Feu_Stop_G", "Feu_Stop_D" }),
    Left = table.freeze({ "Clignotant_AVG", "Clignotant_ARG" }),
    Right = table.freeze({ "Clignotant_AVD", "Clignotant_ARD" }),
    Head = table.freeze({ "Phare_G", "Phare_D" }),
})
-- Pièces de carrosserie peintes (teinte tirée au hasard) : nom contenant ce motif.
PnjKits.PaintPattern = "Peinture"

-- Attributs posés par le serveur sur le modèle d'une voiture PNJ (changement seulement : coût réseau minime).
PnjKits.Attributes = table.freeze({
    Silhouette = "AWPnjSilhouette", -- identifiant de silhouette
    Brake = "AWPnjFrein", -- booléen
    Indicator = "AWPnjClignotant", -- "G", "D" ou absent
})

-- Position (m, repère voiture) du centre d'une roue.
function PnjKits.wheelCenter(car: CarSilhouette, wheel: string): Vector3
    local front = string.sub(wheel, 6, 7) == "AV"
    local left = string.sub(wheel, -1) == "G"
    return Vector3.new(
        (if left then -1 else 1) * car.TrackM / 2,
        car.WheelRadiusM,
        (if front then -1 else 1) * car.WheelbaseM / 2
    )
end

-- Centre de la boîte de collision (m, repère voiture) : posée sur la garde au sol.
function PnjKits.boxCenter(car: CarSilhouette): Vector3
    return Vector3.new(0, PnjKits.ClearanceM + car.BoxHeightM / 2, 0)
end

-- Silhouette d'après un tirage uniforme `roll` dans [0 ; 1[ (pondération Weight).
function PnjKits.pickCar(roll: number): CarSilhouette
    local total = 0
    for _, car in PnjKits.Cars do
        total += car.Weight
    end
    local target = roll * total
    for _, car in PnjKits.Cars do
        target -= car.Weight
        if target < 0 then
            return car
        end
    end
    return PnjKits.Cars[#PnjKits.Cars]
end

function PnjKits.car(id: string): CarSilhouette?
    for _, car in PnjKits.Cars do
        if car.Id == id then
            return car
        end
    end
    return nil
end

-- ─── Piétons ────────────────────────────────────────────────────────────────

export type Joint = {
    Name: string,
    Parent: string?, -- articulation parente (nil = racine posée sur l'origine)
    Rest: Vector3, -- position au repos (m, repère piéton, debout bras le long du corps)
}

export type Segment = {
    Name: string, -- nom de la pièce (gabarit 3D et repli)
    Joint: string, -- articulation qui la porte
    Center: Vector3, -- centre au repos (m) — repli seulement
    Size: Vector3, -- taille (m) — repli seulement
    Skin: boolean?, -- couleur de peau (sinon vêtement : haut, bas)
    Lower: boolean?, -- vêtement du bas (jambes, bassin)
}

export type Morphology = {
    Id: string,
    Template: string,
    Scale: number, -- facteur appliqué au squelette de base (taille 1,75 m)
}

-- Squelette de base (taille 1,75 m). Les modèles 3D seront découpés sur ces articulations (dépôt d'art).
local joints: { Joint } = {
    { Name = "Bassin", Parent = nil, Rest = Vector3.new(0, 0.98, 0) },
    { Name = "Taille", Parent = "Bassin", Rest = Vector3.new(0, 1.08, 0) },
    { Name = "Cou", Parent = "Taille", Rest = Vector3.new(0, 1.50, 0) },
    { Name = "EpauleG", Parent = "Taille", Rest = Vector3.new(-0.19, 1.44, 0) },
    { Name = "CoudeG", Parent = "EpauleG", Rest = Vector3.new(-0.21, 1.15, 0) },
    { Name = "EpauleD", Parent = "Taille", Rest = Vector3.new(0.19, 1.44, 0) },
    { Name = "CoudeD", Parent = "EpauleD", Rest = Vector3.new(0.21, 1.15, 0) },
    { Name = "HancheG", Parent = "Bassin", Rest = Vector3.new(-0.095, 0.94, 0) },
    { Name = "GenouG", Parent = "HancheG", Rest = Vector3.new(-0.095, 0.51, 0) },
    { Name = "HancheD", Parent = "Bassin", Rest = Vector3.new(0.095, 0.94, 0) },
    { Name = "GenouD", Parent = "HancheD", Rest = Vector3.new(0.095, 0.51, 0) },
}
for _, item in joints do
    table.freeze(item)
end
PnjKits.Joints = table.freeze(joints)

local segments: { Segment } = {
    {
        Name = "Bassin",
        Joint = "Bassin",
        Center = Vector3.new(0, 0.97, 0),
        Size = Vector3.new(0.34, 0.22, 0.20),
        Lower = true,
    },
    {
        Name = "Buste",
        Joint = "Taille",
        Center = Vector3.new(0, 1.30, 0),
        Size = Vector3.new(0.40, 0.44, 0.22),
    },
    {
        Name = "Tete",
        Joint = "Cou",
        Center = Vector3.new(0, 1.63, -0.01),
        Size = Vector3.new(0.19, 0.24, 0.22),
        Skin = true,
    },
    {
        Name = "BrasG_Haut",
        Joint = "EpauleG",
        Center = Vector3.new(-0.205, 1.30, 0),
        Size = Vector3.new(0.10, 0.31, 0.11),
    },
    {
        Name = "BrasG_Bas",
        Joint = "CoudeG",
        Center = Vector3.new(-0.215, 0.98, 0),
        Size = Vector3.new(0.085, 0.36, 0.09),
        Skin = true,
    },
    {
        Name = "BrasD_Haut",
        Joint = "EpauleD",
        Center = Vector3.new(0.205, 1.30, 0),
        Size = Vector3.new(0.10, 0.31, 0.11),
    },
    {
        Name = "BrasD_Bas",
        Joint = "CoudeD",
        Center = Vector3.new(0.215, 0.98, 0),
        Size = Vector3.new(0.085, 0.36, 0.09),
        Skin = true,
    },
    {
        Name = "JambeG_Haut",
        Joint = "HancheG",
        Center = Vector3.new(-0.095, 0.725, 0),
        Size = Vector3.new(0.15, 0.44, 0.16),
        Lower = true,
    },
    {
        Name = "JambeG_Bas",
        Joint = "GenouG",
        Center = Vector3.new(-0.095, 0.26, -0.02),
        Size = Vector3.new(0.11, 0.52, 0.14),
        Lower = true,
    },
    {
        Name = "JambeD_Haut",
        Joint = "HancheD",
        Center = Vector3.new(0.095, 0.725, 0),
        Size = Vector3.new(0.15, 0.44, 0.16),
        Lower = true,
    },
    {
        Name = "JambeD_Bas",
        Joint = "GenouD",
        Center = Vector3.new(0.095, 0.26, -0.02),
        Size = Vector3.new(0.11, 0.52, 0.14),
        Lower = true,
    },
}
for _, item in segments do
    table.freeze(item)
end
PnjKits.Segments = table.freeze(segments)

local morphologies: { Morphology } = {
    { Id = "H", Template = "PNJ_Pieton_H", Scale = 1.0 },
    { Id = "F", Template = "PNJ_Pieton_F", Scale = 0.94 },
}
for _, item in morphologies do
    table.freeze(item)
end
PnjKits.Morphologies = table.freeze(morphologies)

-- Teintes (vêtements du haut, du bas, peau) : variété sans motif ni marque.
PnjKits.Tops = table.freeze({
    Color3.fromRGB(60, 70, 110),
    Color3.fromRGB(150, 60, 50),
    Color3.fromRGB(70, 110, 70),
    Color3.fromRGB(200, 190, 160),
    Color3.fromRGB(40, 40, 45),
    Color3.fromRGB(120, 90, 140),
    Color3.fromRGB(225, 225, 220),
    Color3.fromRGB(190, 140, 60),
})
PnjKits.Bottoms = table.freeze({
    Color3.fromRGB(35, 45, 70),
    Color3.fromRGB(45, 45, 50),
    Color3.fromRGB(110, 95, 75),
    Color3.fromRGB(80, 85, 90),
    Color3.fromRGB(150, 135, 110),
})
PnjKits.Skins = table.freeze({
    Color3.fromRGB(245, 215, 190),
    Color3.fromRGB(225, 185, 150),
    Color3.fromRGB(190, 140, 100),
    Color3.fromRGB(140, 95, 65),
    Color3.fromRGB(95, 65, 45),
})

local jointIndex: { [string]: Joint } = {}
for _, joint in PnjKits.Joints do
    jointIndex[joint.Name] = joint
end

function PnjKits.joint(name: string): Joint?
    return jointIndex[name]
end

-- Hachage FNV-1a 32 bits d'un texte (tirages déterministes, identiques sur tous les clients).
function PnjKits.hash(text: string): number
    local h = 2166136261
    for i = 1, #text do
        h = bit32.bxor(h, string.byte(text, i))
        h = (h * 16777619) % 4294967296
    end
    return h
end

export type Look = { Morphology: Morphology, Top: Color3, Bottom: Color3, Skin: Color3 }

-- Apparence stable d'un piéton d'après sa clé (même personne pour tous les joueurs, à chaque passage).
function PnjKits.look(key: string): Look
    local h = PnjKits.hash(key)
    local morph = PnjKits.Morphologies[h % #PnjKits.Morphologies + 1]
    h = math.floor(h / #PnjKits.Morphologies)
    local top = PnjKits.Tops[h % #PnjKits.Tops + 1]
    h = math.floor(h / #PnjKits.Tops)
    local bottom = PnjKits.Bottoms[h % #PnjKits.Bottoms + 1]
    h = math.floor(h / #PnjKits.Bottoms)
    local skin = PnjKits.Skins[h % #PnjKits.Skins + 1]
    return { Morphology = morph, Top = top, Bottom = bottom, Skin = skin }
end

--[[
    Contrôle d'un gabarit : liste des noms de pièces attendues absentes (vide = complet). `names` = ensemble des noms
    des pièces du gabarit. Les feux sont facultatifs (une voiture sans clignotant reste valable).
]]
function PnjKits.missingCarParts(names: { [string]: boolean }): { string }
    local missing = {}
    for _, wheel in PnjKits.Wheels do
        if not names[wheel] then
            table.insert(missing, wheel)
        end
    end
    return missing
end

function PnjKits.missingPedestrianParts(names: { [string]: boolean }): { string }
    local missing = {}
    for _, segment in PnjKits.Segments do
        if not names[segment.Name] then
            table.insert(missing, segment.Name)
        end
    end
    return missing
end

return table.freeze(PnjKits)
