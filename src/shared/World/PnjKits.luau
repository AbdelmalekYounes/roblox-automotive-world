--!strict
--[[
    Lot PNJ-01 : contrat des modèles 3D des voitures PNJ et des piétons (module PUR, testé par Lune).

    Décisions du propriétaire (2026-11-06) : modèles TIERS sous licence CC (téléchargés par le propriétaire, préparés
    dans le dépôt d'art, maillages envoyés sur Roblox par lui seul) ; voitures d'environ 2 000 triangles (les 10
    modèles du pack de Comrade1280, CC BY 4.0, coupé et sportive rares) ; piétons humains low-poly DÉCOUPÉS en pièces
    rigides et animés par le code (World/PedestrianGait).

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
    AvantM: number, -- porte-à-faux avant depuis le centre de l'empattement (m)
    ArriereM: number, -- porte-à-faux arrière (m)
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

--[[
    Variantes MESURÉES sur les modèles préparés (dépôt d'art, `vehicles/pnj/releves/voitures.json`, 2026-11-06) :
    pack « Generic passenger car pack » de Comrade1280 (CC BY 4.0, crédit obligatoire), 10 modèles génériques sans
    marque. Parts du trafic validées par le propriétaire (coupé et sportive rares). AvantM / ArriereM : porte-à-faux
    mesurés depuis le centre de l'empattement ; BoxHeightM (boîte de collision) et l'habitacle du repli sont déduits
    de la hauteur.
]]
local cars: { CarSilhouette } = {
    {
        Id = "Berline",
        Template = "PNJ_Berline",
        Weight = 0.18,
        LengthM = 4.358,
        AvantM = 2.172,
        ArriereM = 2.186,
        WidthM = 1.939,
        HeightM = 1.373,
        BoxHeightM = 0.65,
        WheelbaseM = 2.618,
        TrackM = 1.404,
        WheelRadiusM = 0.33,
        WheelWidthM = 0.235,
        CabinLengthM = 2.18,
        CabinHeightM = 0.42,
        CabinOffsetM = 0.17,
    },
    {
        Id = "Hayon",
        Template = "PNJ_Hayon",
        Weight = 0.16,
        LengthM = 3.956,
        AvantM = 2.015,
        ArriereM = 1.941,
        WidthM = 1.763,
        HeightM = 1.392,
        BoxHeightM = 0.66,
        WheelbaseM = 2.399,
        TrackM = 1.382,
        WheelRadiusM = 0.328,
        WheelWidthM = 0.202,
        CabinLengthM = 1.98,
        CabinHeightM = 0.43,
        CabinOffsetM = 0.16,
    },
    {
        Id = "SUV",
        Template = "PNJ_SUV",
        Weight = 0.16,
        LengthM = 4.624,
        AvantM = 2.24,
        ArriereM = 2.384,
        WidthM = 2.067,
        HeightM = 1.766,
        BoxHeightM = 0.89,
        WheelbaseM = 2.719,
        TrackM = 1.46,
        WheelRadiusM = 0.405,
        WheelWidthM = 0.315,
        CabinLengthM = 2.31,
        CabinHeightM = 0.58,
        CabinOffsetM = 0.18,
    },
    {
        Id = "Compacte",
        Template = "PNJ_Compacte",
        Weight = 0.14,
        LengthM = 3.259,
        AvantM = 1.702,
        ArriereM = 1.558,
        WidthM = 1.607,
        HeightM = 1.341,
        BoxHeightM = 0.63,
        WheelbaseM = 2.083,
        TrackM = 1.144,
        WheelRadiusM = 0.263,
        WheelWidthM = 0.183,
        CabinLengthM = 1.63,
        CabinHeightM = 0.41,
        CabinOffsetM = 0.13,
    },
    {
        Id = "Break",
        Template = "PNJ_Break",
        Weight = 0.12,
        LengthM = 4.396,
        AvantM = 2.181,
        ArriereM = 2.216,
        WidthM = 1.95,
        HeightM = 1.403,
        BoxHeightM = 0.67,
        WheelbaseM = 2.632,
        TrackM = 1.412,
        WheelRadiusM = 0.33,
        WheelWidthM = 0.236,
        CabinLengthM = 2.2,
        CabinHeightM = 0.43,
        CabinOffsetM = 0.18,
    },
    {
        Id = "Monospace",
        Template = "PNJ_Monospace",
        Weight = 0.1,
        LengthM = 4.598,
        AvantM = 2.231,
        ArriereM = 2.366,
        WidthM = 1.87,
        HeightM = 1.787,
        BoxHeightM = 0.91,
        WheelbaseM = 2.836,
        TrackM = 1.408,
        WheelRadiusM = 0.348,
        WheelWidthM = 0.267,
        CabinLengthM = 3.31,
        CabinHeightM = 0.58,
        CabinOffsetM = 0.18,
    },
    {
        Id = "PickUp",
        Template = "PNJ_PickUp",
        Weight = 0.06,
        LengthM = 5.179,
        AvantM = 2.476,
        ArriereM = 2.703,
        WidthM = 2.099,
        HeightM = 1.721,
        BoxHeightM = 0.87,
        WheelbaseM = 3.197,
        TrackM = 1.46,
        WheelRadiusM = 0.403,
        WheelWidthM = 0.315,
        CabinLengthM = 2.59,
        CabinHeightM = 0.55,
        CabinOffsetM = 0.21,
    },
    {
        Id = "ToutTerrain",
        Template = "PNJ_ToutTerrain",
        Weight = 0.04,
        LengthM = 3.942,
        AvantM = 1.902,
        ArriereM = 2.04,
        WidthM = 1.96,
        HeightM = 1.6,
        BoxHeightM = 0.79,
        WheelbaseM = 2.325,
        TrackM = 1.47,
        WheelRadiusM = 0.382,
        WheelWidthM = 0.301,
        CabinLengthM = 1.97,
        CabinHeightM = 0.51,
        CabinOffsetM = 0.16,
    },
    {
        Id = "Coupe",
        Template = "PNJ_Coupe",
        Weight = 0.02,
        LengthM = 4.249,
        AvantM = 2.135,
        ArriereM = 2.114,
        WidthM = 1.884,
        HeightM = 1.315,
        BoxHeightM = 0.62,
        WheelbaseM = 2.41,
        TrackM = 1.339,
        WheelRadiusM = 0.327,
        WheelWidthM = 0.284,
        CabinLengthM = 2.12,
        CabinHeightM = 0.39,
        CabinOffsetM = 0.17,
    },
    {
        Id = "Sportive",
        Template = "PNJ_Sportive",
        Weight = 0.02,
        LengthM = 3.912,
        AvantM = 2.073,
        ArriereM = 1.839,
        WidthM = 1.766,
        HeightM = 1.138,
        BoxHeightM = 0.51,
        WheelbaseM = 2.45,
        TrackM = 1.377,
        WheelRadiusM = 0.356,
        WheelWidthM = 0.293,
        CabinLengthM = 1.96,
        CabinHeightM = 0.33,
        CabinOffsetM = 0.16,
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

export type PartStyle = { Pattern: string, Color: Color3, Material: Enum.Material, Transparency: number }

--[[
    Couleurs des pièces UNIES du gabarit 3D (l'import glTF de Studio ne reprend pas les couleurs des matériaux sans
    texture : relevé du lot VEH3D-02). Premier motif trouvé dans le nom de la pièce ; la peinture est tirée à part.
    Les jantes et enjoliveurs (« Roue_XXX_Jante ») passent avant les pneus (« Roue_XXX »).
]]
PnjKits.PartStyles = table.freeze({
    table.freeze({
        Pattern = "_Jante",
        Color = Color3.fromRGB(150, 152, 156),
        Material = Enum.Material.Metal,
        Transparency = 0,
    }),
    table.freeze({
        Pattern = "_Enjoliveur",
        Color = Color3.fromRGB(150, 152, 156),
        Material = Enum.Material.Metal,
        Transparency = 0,
    }),
    table.freeze({
        Pattern = "Roue_",
        Color = Color3.fromRGB(22, 22, 22),
        Material = Enum.Material.SmoothPlastic,
        Transparency = 0,
    }),
    table.freeze({
        Pattern = "Garniture",
        Color = Color3.fromRGB(24, 24, 26),
        Material = Enum.Material.SmoothPlastic,
        Transparency = 0,
    }),
    table.freeze({
        Pattern = "Chrome",
        Color = Color3.fromRGB(165, 167, 171),
        Material = Enum.Material.Metal,
        Transparency = 0,
    }),
    table.freeze({
        Pattern = "Vitrage",
        Color = Color3.fromRGB(25, 30, 38),
        Material = Enum.Material.Glass,
        Transparency = 0.25,
    }),
    table.freeze({
        Pattern = "Feu_Stop",
        Color = Color3.fromRGB(110, 15, 15),
        Material = Enum.Material.SmoothPlastic,
        Transparency = 0,
    }),
    table.freeze({
        Pattern = "Clignotant",
        Color = Color3.fromRGB(130, 80, 20),
        Material = Enum.Material.SmoothPlastic,
        Transparency = 0,
    }),
    table.freeze({
        Pattern = "Phare",
        Color = Color3.fromRGB(215, 215, 205),
        Material = Enum.Material.SmoothPlastic,
        Transparency = 0,
    }),
    table.freeze({
        Pattern = "Optique",
        Color = Color3.fromRGB(190, 190, 185),
        Material = Enum.Material.SmoothPlastic,
        Transparency = 0,
    }),
})

function PnjKits.partStyle(name: string): PartStyle?
    for _, style in PnjKits.PartStyles do
        if string.find(name, style.Pattern, 1, true) then
            return style
        end
    end
    return nil
end

-- Roue portée par une pièce : la roue elle-même (« Roue_AVG ») ou une pièce qui lui est soudée (« Roue_AVG_Jante »).
function PnjKits.wheelOf(name: string): (string?, boolean)
    for _, wheel in PnjKits.Wheels do
        if name == wheel then
            return wheel, true
        elseif string.sub(name, 1, #wheel + 1) == wheel .. "_" then
            return wheel, false
        end
    end
    return nil, false
end

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

-- Centre de la boîte de collision (m, repère voiture) : posée sur la garde au sol, centrée sur la longueur hors tout
-- (les porte-à-faux avant et arrière diffèrent).
function PnjKits.boxCenter(car: CarSilhouette): Vector3
    return Vector3.new(0, PnjKits.ClearanceM + car.BoxHeightM / 2, (car.ArriereM - car.AvantM) / 2)
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
    Scale: number, -- facteur appliqué au squelette de base (taille 1,75 m) : repli en pièces simples
    -- Articulations MESURÉES sur le modèle 3D (m, repère piéton) : utilisées avec le gabarit 3D seulement.
    Rest: { [string]: Vector3 }?,
    -- Centre de la boîte de la pièce « Bassin » du gabarit (m, repère piéton) : retrouve l'origine du modèle importé.
    PelvisCenter: Vector3?,
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

--[[
    18 personnages du pack « Low Poly People » de David Jalbert (CC BY 4.0, crédit obligatoire) : corpulences
    normale, forte, ronde × homme / femme × 3 tenues. Articulations relevées sur les modèles préparés (dépôt d'art,
    `vehicles/pnj/pietons/pietons.json`, 2026-11-06).
]]
local morphologies: { Morphology } = {
    {
        Id = "Normal_HA",
        Template = "PNJ_Pieton_Normal_HA",
        Scale = 1.006,
        Rest = {
            Bassin = Vector3.new(0.0, 0.6889, -0.0067),
            Taille = Vector3.new(0.0, 0.9673, -0.0067),
            Cou = Vector3.new(0.0, 1.2753, -0.0067),
            EpauleG = Vector3.new(-0.1999, 1.1518, -0.0067),
            CoudeG = Vector3.new(-0.2381, 0.8799, -0.0067),
            EpauleD = Vector3.new(0.1999, 1.1518, -0.0067),
            CoudeD = Vector3.new(0.2381, 0.8799, -0.0067),
            HancheG = Vector3.new(-0.1341, 0.662, -0.0),
            GenouG = Vector3.new(-0.1413, 0.3693, -0.0134),
            HancheD = Vector3.new(0.1341, 0.662, 0.0),
            GenouD = Vector3.new(0.1413, 0.3693, -0.0134),
        },
        PelvisCenter = Vector3.new(0.0, 0.8448, -0.0146),
    },
    {
        Id = "Normal_HB",
        Template = "PNJ_Pieton_Normal_HB",
        Scale = 1.006,
        Rest = {
            Bassin = Vector3.new(0.0, 0.682, -0.0067),
            Taille = Vector3.new(0.0, 0.9577, -0.0067),
            Cou = Vector3.new(0.0, 1.2626, -0.0067),
            EpauleG = Vector3.new(-0.1979, 1.1404, -0.0067),
            CoudeG = Vector3.new(-0.2357, 0.8711, -0.0067),
            EpauleD = Vector3.new(0.1979, 1.1404, -0.0067),
            CoudeD = Vector3.new(0.2357, 0.8711, -0.0067),
            HancheG = Vector3.new(-0.1327, 0.6555, -0.0),
            GenouG = Vector3.new(-0.1399, 0.3656, -0.0132),
            HancheD = Vector3.new(0.1327, 0.6555, 0.0),
            GenouD = Vector3.new(0.1399, 0.3656, -0.0132),
        },
        PelvisCenter = Vector3.new(-0.0, 0.8345, -0.023),
    },
    {
        Id = "Normal_HC",
        Template = "PNJ_Pieton_Normal_HC",
        Scale = 1.006,
        Rest = {
            Bassin = Vector3.new(0.0, 0.6889, -0.0067),
            Taille = Vector3.new(0.0, 0.9673, -0.0067),
            Cou = Vector3.new(0.0, 1.2753, -0.0067),
            EpauleG = Vector3.new(-0.1999, 1.1519, -0.0067),
            CoudeG = Vector3.new(-0.2381, 0.8799, -0.0067),
            EpauleD = Vector3.new(0.1999, 1.1519, -0.0067),
            CoudeD = Vector3.new(0.2381, 0.8799, -0.0067),
            HancheG = Vector3.new(-0.1341, 0.6621, -0.0),
            GenouG = Vector3.new(-0.1413, 0.3693, -0.0134),
            HancheD = Vector3.new(0.1341, 0.6621, 0.0),
            GenouD = Vector3.new(0.1413, 0.3693, -0.0134),
        },
        PelvisCenter = Vector3.new(-0.0, 0.8429, -0.0233),
    },
    {
        Id = "Normal_FA",
        Template = "PNJ_Pieton_Normal_FA",
        Scale = 0.943,
        Rest = {
            Bassin = Vector3.new(0.0, 0.6366, -0.0062),
            Taille = Vector3.new(0.0, 0.8939, -0.0062),
            Cou = Vector3.new(0.0, 1.1785, -0.0062),
            EpauleG = Vector3.new(-0.1847, 1.0644, -0.0062),
            CoudeG = Vector3.new(-0.22, 0.8131, -0.0062),
            EpauleD = Vector3.new(0.1847, 1.0644, -0.0062),
            CoudeD = Vector3.new(0.22, 0.8131, -0.0062),
            HancheG = Vector3.new(-0.1239, 0.6118, -0.0),
            GenouG = Vector3.new(-0.1306, 0.3413, -0.0123),
            HancheD = Vector3.new(0.1239, 0.6118, 0.0),
            GenouD = Vector3.new(0.1306, 0.3413, -0.0123),
        },
        PelvisCenter = Vector3.new(-0.0, 0.779, -0.0204),
    },
    {
        Id = "Normal_FB",
        Template = "PNJ_Pieton_Normal_FB",
        Scale = 0.943,
        Rest = {
            Bassin = Vector3.new(0.0, 0.6285, -0.0061),
            Taille = Vector3.new(0.0, 0.8826, -0.0061),
            Cou = Vector3.new(0.0, 1.1636, -0.0061),
            EpauleG = Vector3.new(-0.1824, 1.0509, -0.0061),
            CoudeG = Vector3.new(-0.2172, 0.8028, -0.0061),
            EpauleD = Vector3.new(0.1824, 1.0509, -0.0061),
            CoudeD = Vector3.new(0.2172, 0.8028, -0.0061),
            HancheG = Vector3.new(-0.1223, 0.604, -0.0),
            GenouG = Vector3.new(-0.129, 0.337, -0.0122),
            HancheD = Vector3.new(0.1223, 0.604, 0.0),
            GenouD = Vector3.new(0.129, 0.337, -0.0122),
        },
        PelvisCenter = Vector3.new(-0.0, 0.7694, -0.0202),
    },
    {
        Id = "Normal_FC",
        Template = "PNJ_Pieton_Normal_FC",
        Scale = 0.943,
        Rest = {
            Bassin = Vector3.new(0.0, 0.6302, -0.0062),
            Taille = Vector3.new(0.0, 0.8849, -0.0062),
            Cou = Vector3.new(0.0, 1.1667, -0.0062),
            EpauleG = Vector3.new(-0.1829, 1.0537, -0.0062),
            CoudeG = Vector3.new(-0.2178, 0.8049, -0.0062),
            EpauleD = Vector3.new(0.1829, 1.0537, -0.0062),
            CoudeD = Vector3.new(0.2178, 0.8049, -0.0062),
            HancheG = Vector3.new(-0.1226, 0.6057, -0.0),
            GenouG = Vector3.new(-0.1293, 0.3379, -0.0122),
            HancheD = Vector3.new(0.1226, 0.6057, 0.0),
            GenouD = Vector3.new(0.1293, 0.3379, -0.0122),
        },
        PelvisCenter = Vector3.new(-0.0, 0.7429, -0.0213),
    },
    {
        Id = "Fort_HA",
        Template = "PNJ_Pieton_Fort_HA",
        Scale = 1.006,
        Rest = {
            Bassin = Vector3.new(-0.0, 0.6715, 0.0182),
            Taille = Vector3.new(-0.0, 0.9571, 0.0182),
            Cou = Vector3.new(-0.0, 1.2685, 0.0182),
            EpauleG = Vector3.new(-0.2435, 1.1435, 0.0182),
            CoudeG = Vector3.new(-0.2828, 0.864, 0.0182),
            EpauleD = Vector3.new(0.2435, 1.1435, 0.0182),
            CoudeD = Vector3.new(0.2828, 0.864, 0.0182),
            HancheG = Vector3.new(-0.1134, 0.6429, -0.0),
            GenouG = Vector3.new(-0.1387, 0.3784, -0.0025),
            HancheD = Vector3.new(0.1134, 0.6415, 0.0),
            GenouD = Vector3.new(0.1387, 0.377, -0.0025),
        },
        PelvisCenter = Vector3.new(-0.0, 0.8391, -0.0126),
    },
    {
        Id = "Fort_HB",
        Template = "PNJ_Pieton_Fort_HB",
        Scale = 1.006,
        Rest = {
            Bassin = Vector3.new(-0.0, 0.6782, 0.0184),
            Taille = Vector3.new(-0.0, 0.9667, 0.0184),
            Cou = Vector3.new(-0.0, 1.2811, 0.0184),
            EpauleG = Vector3.new(-0.2459, 1.155, 0.0184),
            CoudeG = Vector3.new(-0.2856, 0.8727, 0.0184),
            EpauleD = Vector3.new(0.2459, 1.155, 0.0184),
            CoudeD = Vector3.new(0.2856, 0.8727, 0.0184),
            HancheG = Vector3.new(-0.1146, 0.6494, -0.0),
            GenouG = Vector3.new(-0.1401, 0.3822, -0.0025),
            HancheD = Vector3.new(0.1146, 0.6479, 0.0),
            GenouD = Vector3.new(0.1401, 0.3807, -0.0025),
        },
        PelvisCenter = Vector3.new(-0.0, 0.8475, -0.0127),
    },
    {
        Id = "Fort_HC",
        Template = "PNJ_Pieton_Fort_HC",
        Scale = 1.006,
        Rest = {
            Bassin = Vector3.new(-0.0, 0.6942, 0.0189),
            Taille = Vector3.new(-0.0, 0.9895, 0.0189),
            Cou = Vector3.new(-0.0, 1.3113, 0.0189),
            EpauleG = Vector3.new(-0.2517, 1.1822, 0.0189),
            CoudeG = Vector3.new(-0.2923, 0.8932, 0.0189),
            EpauleD = Vector3.new(0.2517, 1.1822, 0.0189),
            CoudeD = Vector3.new(0.2923, 0.8932, 0.0189),
            HancheG = Vector3.new(-0.1173, 0.6647, -0.0),
            GenouG = Vector3.new(-0.1434, 0.3912, -0.0026),
            HancheD = Vector3.new(0.1173, 0.6632, 0.0),
            GenouD = Vector3.new(0.1434, 0.3897, -0.0026),
        },
        PelvisCenter = Vector3.new(-0.0, 0.8699, -0.0037),
    },
    {
        Id = "Fort_FA",
        Template = "PNJ_Pieton_Fort_FA",
        Scale = 0.943,
        Rest = {
            Bassin = Vector3.new(-0.0, 0.6221, 0.0169),
            Taille = Vector3.new(-0.0, 0.8867, 0.0169),
            Cou = Vector3.new(-0.0, 1.1751, 0.0169),
            EpauleG = Vector3.new(-0.2256, 1.0594, 0.0169),
            CoudeG = Vector3.new(-0.262, 0.8005, 0.0169),
            EpauleD = Vector3.new(0.2256, 1.0594, 0.0169),
            CoudeD = Vector3.new(0.262, 0.8005, 0.0169),
            HancheG = Vector3.new(-0.1051, 0.5956, -0.0),
            GenouG = Vector3.new(-0.1285, 0.3506, -0.0023),
            HancheD = Vector3.new(0.1051, 0.5943, 0.0),
            GenouD = Vector3.new(0.1285, 0.3492, -0.0023),
        },
        PelvisCenter = Vector3.new(-0.0, 0.6472, 0.0129),
    },
    {
        Id = "Fort_FB",
        Template = "PNJ_Pieton_Fort_FB",
        Scale = 0.943,
        Rest = {
            Bassin = Vector3.new(-0.0, 0.6326, 0.0172),
            Taille = Vector3.new(-0.0, 0.9018, 0.0172),
            Cou = Vector3.new(-0.0, 1.1951, 0.0172),
            EpauleG = Vector3.new(-0.2294, 1.0774, 0.0172),
            CoudeG = Vector3.new(-0.2664, 0.8141, 0.0172),
            EpauleD = Vector3.new(0.2294, 1.0774, 0.0172),
            CoudeD = Vector3.new(0.2664, 0.8141, 0.0172),
            HancheG = Vector3.new(-0.1069, 0.6057, -0.0),
            GenouG = Vector3.new(-0.1307, 0.3565, -0.0023),
            HancheD = Vector3.new(0.1069, 0.6044, 0.0),
            GenouD = Vector3.new(0.1307, 0.3551, -0.0023),
        },
        PelvisCenter = Vector3.new(0.0, 0.6682, 0.0131),
    },
    {
        Id = "Fort_FC",
        Template = "PNJ_Pieton_Fort_FC",
        Scale = 0.943,
        Rest = {
            Bassin = Vector3.new(-0.0, 0.6299, 0.0171),
            Taille = Vector3.new(-0.0, 0.8978, 0.0171),
            Cou = Vector3.new(-0.0, 1.1898, 0.0171),
            EpauleG = Vector3.new(-0.2284, 1.0726, 0.0171),
            CoudeG = Vector3.new(-0.2653, 0.8105, 0.0171),
            EpauleD = Vector3.new(0.2284, 1.0726, 0.0171),
            CoudeD = Vector3.new(0.2653, 0.8105, 0.0171),
            HancheG = Vector3.new(-0.1064, 0.6031, -0.0),
            GenouG = Vector3.new(-0.1301, 0.3549, -0.0023),
            HancheD = Vector3.new(0.1064, 0.6017, 0.0),
            GenouD = Vector3.new(0.1301, 0.3536, -0.0023),
        },
        PelvisCenter = Vector3.new(-0.0, 0.6896, 0.0202),
    },
    {
        Id = "Rond_HA",
        Template = "PNJ_Pieton_Rond_HA",
        Scale = 1.006,
        Rest = {
            Bassin = Vector3.new(-0.0, 0.7034, -0.0068),
            Taille = Vector3.new(-0.0, 0.9065, -0.0068),
            Cou = Vector3.new(-0.0, 1.2508, -0.0068),
            EpauleG = Vector3.new(-0.2483, 1.1255, -0.0068),
            CoudeG = Vector3.new(-0.285, 0.8645, -0.0068),
            EpauleD = Vector3.new(0.2483, 1.1255, -0.0068),
            CoudeD = Vector3.new(0.285, 0.8645, -0.0068),
            HancheG = Vector3.new(-0.1685, 0.6328, -0.0),
            GenouG = Vector3.new(-0.1651, 0.3791, -0.0135),
            HancheD = Vector3.new(0.1685, 0.6328, 0.0),
            GenouD = Vector3.new(0.1651, 0.3791, -0.0135),
        },
        PelvisCenter = Vector3.new(0.0, 0.7681, -0.1003),
    },
    {
        Id = "Rond_HB",
        Template = "PNJ_Pieton_Rond_HB",
        Scale = 1.006,
        Rest = {
            Bassin = Vector3.new(-0.0, 0.714, -0.0069),
            Taille = Vector3.new(-0.0, 0.9201, -0.0069),
            Cou = Vector3.new(-0.0, 1.2696, -0.0069),
            EpauleG = Vector3.new(-0.2521, 1.1424, -0.0069),
            CoudeG = Vector3.new(-0.2893, 0.8775, -0.0069),
            EpauleD = Vector3.new(0.2521, 1.1424, -0.0069),
            CoudeD = Vector3.new(0.2893, 0.8775, -0.0069),
            HancheG = Vector3.new(-0.1711, 0.6423, -0.0),
            GenouG = Vector3.new(-0.1676, 0.3848, -0.0138),
            HancheD = Vector3.new(0.1711, 0.6423, 0.0),
            GenouD = Vector3.new(0.1676, 0.3848, -0.0138),
        },
        PelvisCenter = Vector3.new(-0.0, 0.7674, -0.1104),
    },
    {
        Id = "Rond_HC",
        Template = "PNJ_Pieton_Rond_HC",
        Scale = 1.006,
        Rest = {
            Bassin = Vector3.new(-0.0, 0.7424, -0.0072),
            Taille = Vector3.new(-0.0, 0.9567, -0.0072),
            Cou = Vector3.new(-0.0, 1.3201, -0.0072),
            EpauleG = Vector3.new(-0.2621, 1.1879, -0.0072),
            CoudeG = Vector3.new(-0.3008, 0.9124, -0.0072),
            EpauleD = Vector3.new(0.2621, 1.1879, -0.0072),
            CoudeD = Vector3.new(0.3008, 0.9124, -0.0072),
            HancheG = Vector3.new(-0.1779, 0.6679, -0.0),
            GenouG = Vector3.new(-0.1743, 0.4001, -0.0143),
            HancheD = Vector3.new(0.1779, 0.6679, 0.0),
            GenouD = Vector3.new(0.1743, 0.4001, -0.0143),
        },
        PelvisCenter = Vector3.new(0.0, 0.8164, -0.1148),
    },
    {
        Id = "Rond_FA",
        Template = "PNJ_Pieton_Rond_FA",
        Scale = 0.943,
        Rest = {
            Bassin = Vector3.new(-0.0, 0.6544, -0.0064),
            Taille = Vector3.new(-0.0, 0.8434, -0.0064),
            Cou = Vector3.new(-0.0, 1.1637, -0.0064),
            EpauleG = Vector3.new(-0.2311, 1.0472, -0.0064),
            CoudeG = Vector3.new(-0.2652, 0.8044, -0.0064),
            EpauleD = Vector3.new(0.2311, 1.0472, -0.0064),
            CoudeD = Vector3.new(0.2652, 0.8044, -0.0064),
            HancheG = Vector3.new(-0.1568, 0.5888, -0.0),
            GenouG = Vector3.new(-0.1536, 0.3527, -0.0126),
            HancheD = Vector3.new(0.1568, 0.5888, 0.0),
            GenouD = Vector3.new(0.1536, 0.3527, -0.0126),
        },
        PelvisCenter = Vector3.new(0.0, 0.6563, -0.0901),
    },
    {
        Id = "Rond_FB",
        Template = "PNJ_Pieton_Rond_FB",
        Scale = 0.943,
        Rest = {
            Bassin = Vector3.new(-0.0, 0.6628, -0.0064),
            Taille = Vector3.new(-0.0, 0.8542, -0.0064),
            Cou = Vector3.new(-0.0, 1.1787, -0.0064),
            EpauleG = Vector3.new(-0.234, 1.0606, -0.0064),
            CoudeG = Vector3.new(-0.2686, 0.8147, -0.0064),
            EpauleD = Vector3.new(0.234, 1.0606, -0.0064),
            CoudeD = Vector3.new(0.2686, 0.8147, -0.0064),
            HancheG = Vector3.new(-0.1588, 0.5963, -0.0),
            GenouG = Vector3.new(-0.1556, 0.3572, -0.0128),
            HancheD = Vector3.new(0.1588, 0.5963, 0.0),
            GenouD = Vector3.new(0.1556, 0.3572, -0.0128),
        },
        PelvisCenter = Vector3.new(-0.0, 0.6781, -0.0913),
    },
    {
        Id = "Rond_FC",
        Template = "PNJ_Pieton_Rond_FC",
        Scale = 0.943,
        Rest = {
            Bassin = Vector3.new(-0.0, 0.614, -0.006),
            Taille = Vector3.new(-0.0, 0.7913, -0.006),
            Cou = Vector3.new(-0.0, 1.0918, -0.006),
            EpauleG = Vector3.new(-0.2168, 0.9825, -0.006),
            CoudeG = Vector3.new(-0.2488, 0.7547, -0.006),
            EpauleD = Vector3.new(0.2168, 0.9825, -0.006),
            CoudeD = Vector3.new(0.2488, 0.7547, -0.006),
            HancheG = Vector3.new(-0.1471, 0.5524, -0.0),
            GenouG = Vector3.new(-0.1441, 0.3309, -0.0118),
            HancheD = Vector3.new(0.1471, 0.5524, 0.0),
            GenouD = Vector3.new(0.1441, 0.3309, -0.0118),
        },
        PelvisCenter = Vector3.new(0.0, 0.6093, -0.0851),
    },
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

-- Palettes des piétons 3D (variantes de couleurs, texture des pièces) : gabarit porteur `PNJ_Pietons_Palettes`, pièces
-- `Palette_00` à `Palette_11` dont la texture est la palette.
PnjKits.PaletteTemplate = "PNJ_Pietons_Palettes"
PnjKits.PaletteCount = 12

export type Look = { Morphology: Morphology, Top: Color3, Bottom: Color3, Skin: Color3, Palette: number }

-- Apparence stable d'un piéton d'après sa clé (même personne pour tous les joueurs, à chaque passage).
function PnjKits.look(key: string): Look
    local h = PnjKits.hash(key)
    local morph = PnjKits.Morphologies[math.floor(PnjKits.hash(key .. "#corps") / 65536) % #PnjKits.Morphologies + 1]
    h = math.floor(h / #PnjKits.Morphologies)
    local top = PnjKits.Tops[h % #PnjKits.Tops + 1]
    h = math.floor(h / #PnjKits.Tops)
    local bottom = PnjKits.Bottoms[h % #PnjKits.Bottoms + 1]
    h = math.floor(h / #PnjKits.Bottoms)
    local skin = PnjKits.Skins[h % #PnjKits.Skins + 1]
    -- Palette tirée sur un hachage séparé (indépendante de la morphologie).
    -- Bits de poids fort : les bits faibles de FNV-1a varient peu quand seule la fin de la clé change.
    local palette = math.floor(PnjKits.hash(key .. "#palette") / 65536) % PnjKits.PaletteCount
    return { Morphology = morph, Top = top, Bottom = bottom, Skin = skin, Palette = palette }
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
