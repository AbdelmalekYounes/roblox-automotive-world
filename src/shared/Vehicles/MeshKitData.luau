--!strict
--[[
    Données des kits de maillages (lot VEH3D-01), module PUR (aucun service) : testé par Lune contre le gabarit
    réel de la place construite. Construction : module serveur `Vehicles/MeshKits`.

    Repère du châssis (studs, origine au centre de gravité, avant vers −Z). Valeurs MESURÉES sur le modèle (dépôt
    d'art : `vehicles/wk_comete/renders_720s/finition.json` et export `wk_comete_720s_lod0.json`, 2026-11-04).
    Modèle tiers CC BY 4.0, exception du propriétaire : docs/vehicle-3d/MODELES_TIERS.md.
]]

local MeshKitData = {}

local SteeringWheel = require(script.Parent.SteeringWheel)

export type Box = { Center: Vector3, Size: Vector3 }
export type Kit = {
    Template: string, -- nom du modèle du dossier des gabarits (côté serveur, AutomotiveWorldMeshKits)
    ManifestId: string, -- entrée du manifeste qui liste les identifiants d'actifs autorisés
    -- Pièce de référence et centre de sa boîte dans le repère du châssis : donne le décalage du gabarit.
    Reference: string,
    ReferenceCenter: Vector3,
    SeatDriver: Vector3, -- CENTRE de la pièce Seat (0,4 st d'épaisseur : dessus d'assise + 0,2 au-dessus)
    -- Pose assise du jeu (Shared.Vehicles.SeatPose) des deux places, et plancher des pieds mesuré (y, z mini, z maxi).
    SeatPoses: { Driver: string, Passenger: string },
    Footwell: { FloorY: number, FrontZ: number, RearZ: number },
    RoofUnderside: number, -- dessous du pavillon au-dessus des places (y, mesuré), pour les têtes
    SeatPassenger: Vector3,
    CameraCockpit: Vector3,
    CameraHood: Vector3,
    CameraBumper: Vector3,
    SideHalf: number, -- demi-largeur hors rétroviseurs (invites d'embarquement)
    Collisions: { [string]: Box }, -- noms des zones de dégâts (DamageService)
    -- Roues : nom de la roue du jeu → pièces du modèle (pneu, jante), affichées à LEUR position.
    Wheels: { [string]: { string } },
    GlassPattern: string, -- pièces de vitrage (transparence perdue à l'import glTF)
    -- Sources de lumière (le maillage des feux, texturé, ne passe pas en néon) : invisibles, AWLight.
    Lights: { { Name: string, Light: string, Position: Vector3, Size: Vector3 } },
    DetailPattern: { string }, -- pièces masquées au loin (dossier Details, DetailLod)
    -- Peinture du garage (finalisation VEH3D-01) : pièces peintes (suffixe) ; la teinte du garage passe par
    -- `SurfaceAppearance.Color`, qui MULTIPLIE la carte de couleur. Elle n'est appliquée que si ces pièces portent la
    -- carte de couleur NEUTRE `NeutralColorMap` (zone de peinture claire, lignes de carrosserie conservées), à envoyer
    -- par le propriétaire ; sinon la teinte d'origine de la texture est gardée (aucune dégradation).
    -- Plain (lot VEH3D-02) : peinture UNIE sans carte de couleur ; la teinte du garage remplace la couleur importée.
    Paint: { Pattern: string, NeutralColorMap: number?, Plain: boolean? },
    -- Maillages des feux séparés (export du 2026-11-04, dépôt d'art 195df9b) : rôle AWLight posé s'ils sont présents
    -- dans le gabarit (absents du premier envoi : sources seules).
    LightMeshes: { [string]: string },
    -- Couleurs des matériaux UNIS sans texture (lot VEH3D-02) : l'import glTF de Studio ne les reprend pas (pièces
    -- grises par défaut, relevé du gabarit Brio du 2026-11-05) ; la fabrique les repose. Valeurs sRGB des matériaux
    -- Blender (conversion de la couleur linéaire).
    Colors: { [string]: Color3 }?,
    -- Marques de dégâts (DamageService) posées sur la surface VISIBLE, mesurée par rayons sur le maillage :
    -- avant et arrière en x = −1, 0, +1 (z de la surface), flancs en z = −1,6, 0, +1,6 (|x| de la surface).
    DamageMarks: {
        FrontY: number,
        Front: { number },
        RearY: number,
        Rear: { number },
        SideY: number,
        Side: { number },
    },
    -- Volant qui tourne et prises des mains (lot ANIM-01) : pièce du gabarit, centre et axe de la jante MESURÉS sur
    -- les sommets du volant (export glTF, lecture seule, 2026-11-06), rapport de direction. La pièce n'est articulée
    -- que si elle est présente dans le gabarit ; les mains se posent sur la jante dans tous les cas.
    SteeringWheel: SteeringWheel.Spec?,
}

-- Mesures du 2026-11-04 (MODELES_TIERS.md §3 et §4). Dessus d'assise y −0,643 → centre du Seat −0,843.
local COMETE: Kit = {
    Template = "Comete720s",
    ManifestId = "veh.wk_comete.mesh720s",
    Reference = "COMETE_Caisse_body",
    ReferenceCenter = Vector3.new(0, 0.354, -1.214),
    SeatDriver = Vector3.new(-1.2, -0.843, -1.45),
    SeatPassenger = Vector3.new(1.2, -0.843, -1.45),
    SeatPoses = { Driver = "Sportive", Passenger = "SportivePassager" },
    -- Plancher sous le pédalier mesuré par rayons (Blender, 2026-11-05) : y −0,92 entre z −4,6 et −3,2.
    Footwell = { FloorY = -0.92, FrontZ = -4.6, RearZ = -3.2 },
    -- Dessous du pavillon au droit des places (x ±1,2 ; z −1,5 à −0,5) : 2,71 à 2,73 st (Blender, 2026-11-05).
    RoofUnderside = 2.70,
    CameraCockpit = Vector3.new(-1.2, 1.798, -1.8),
    CameraHood = Vector3.new(0, 2.024, -5.797),
    CameraBumper = Vector3.new(0, 0.514, -10.084),
    SideHalf = 3.49,
    Collisions = {
        Coque = { Center = Vector3.new(0, 0.414, -1.022), Size = Vector3.new(6.621, 0.6, 13.143) },
        BouclierAvant = { Center = Vector3.new(0, -0.264, -8.164), Size = Vector3.new(4.112, 1.757, 1.341) },
        BouclierArriere = { Center = Vector3.new(0, 0.036, 6.003), Size = Vector3.new(4.417, 1.157, 1.106) },
        Habitacle = { Center = Vector3.new(0, 1.621, -0.899), Size = Vector3.new(3.373, 1.814, 4.197) },
    },
    Wheels = {
        FL = { "COMETE_Pneu_AvG", "COMETE_Jante_AvG" },
        FR = { "COMETE_Pneu_AvD", "COMETE_Jante_AvD" },
        RL = { "COMETE_Pneu_ArG", "COMETE_Jante_ArG" },
        RR = { "COMETE_Pneu_ArD", "COMETE_Jante_ArD" },
    },
    GlassPattern = "glass",
    Lights = {
        {
            Name = "PhareGauche",
            Light = "Head",
            Position = Vector3.new(-2.75, 0.54, -8.5),
            Size = Vector3.new(0.6, 0.3, 0.1),
        },
        {
            Name = "PhareDroit",
            Light = "Head",
            Position = Vector3.new(2.75, 0.54, -8.5),
            Size = Vector3.new(0.6, 0.3, 0.1),
        },
        {
            Name = "FeuGauche",
            Light = "Tail",
            Position = Vector3.new(-2.12, 1.02, 6.7),
            Size = Vector3.new(0.6, 0.3, 0.1),
        },
        {
            Name = "FeuDroit",
            Light = "Tail",
            Position = Vector3.new(2.12, 1.02, 6.7),
            Size = Vector3.new(0.6, 0.3, 0.1),
        },
    },
    DetailPattern = { "COMETE_Habitacle", "COMETE_Freins", "COMETE_EssuieGlaces", "COMETE_Retroviseurs_mirror" },
    Paint = { Pattern = "_body", NeutralColorMap = nil },
    LightMeshes = { COMETE_Feu_Av = "Head", COMETE_Feu_Ar = "Tail" },
    -- Volant (lot ANIM-01) : séparé de `COMETE_Habitacle_interior` dans le dépôt d'art (`comete_volant_separe.py`,
    -- 2026-11-06), pièce `COMETE_Volant` à importer par le propriétaire ; tant qu'elle manque au gabarit, le volant
    -- reste fixe (dans l'habitacle) et les mains se posent dessus à 9 h 15. Jante ajustée sur 98 sommets : centre
    -- (−1,157 ; 0,960 ; −2,951), plan incliné de 12° sur la verticale, rayon 0,593 st (0,533 à 0,648 : boudin).
    -- Rapport 12:1 (sportive, plus directe) : ±360° de volant à fond en manœuvre (30°), ±108° à 140 km/h (9°).
    SteeringWheel = {
        Part = "COMETE_Volant",
        Hub = Vector3.new(-1.157, 0.96, -2.951),
        Axis = Vector3.new(0, 0.2096, 0.9778).Unit,
        GripRadius = 0.593,
        Ratio = 12,
    },
    -- Mesure du 2026-11-05 (Blender, rayons sur la collection EXT hors vitrage, wk_comete_720s.blend).
    DamageMarks = {
        FrontY = -0.264,
        Front = { -9.171, -9.323, -9.171 },
        RearY = 0.036,
        Rear = { 6.838, 6.892, 6.838 },
        SideY = 0.414,
        Side = { 3.394, 3.41, 3.454 },
    },
}

-- Brio (lot VEH3D-02), modèle tiers « Milano '95 » (Daniel Zhabotinsky, CC BY 4.0). Mesures du 2026-11-05 (dépôt
-- d'art : `vehicles/wk_brio/renders_milano95/finition.json`, export `vehicles/wk_brio/export/wk_brio_milano95_lod0.json`).
-- Places corrigées au lot BRIO-02 (coupes par rayons du 2026-11-06, Blender sans interface, en lecture seule, sur
-- `wk_brio_milano95.blend`) : le siège du modèle n'a pas de coussin plat distinct ; le relevé du 2026-11-05 en
-- (x ∓1,2 ; z 1,55) tombait sur le DOSSIER incliné (y 0,62), ~0,95 st au-dessus du vrai coussin. Le personnage s'y
-- asseyait trop haut et trop en arrière : têtes et cheveux à travers le pavillon (capture du propriétaire).
-- Habitacle mesuré (place conducteur, x −1,2 ; passager symétrique à 0,015 st près) :
-- - coussin : y −0,26 (bord avant, z −0,2) à −0,41 (pied du dossier, z 1,21), largeur x −2,1 à −0,4 ;
-- - dossier : pied en (y −0,41 ; z 1,21), haut y 1,96 vers z 2,05, incliné de 20 à 28° vers l'arrière ;
-- - plancher des pieds y −0,88 à −0,90 entre z −0,3 et −2,1 ; tablier et pédalier vers z −2,2 à −2,4 ;
-- - dessous de la planche de bord : y 0,80 (z −0,5) à 0,15 (z −2,0) ; volant x −1,80 à −0,53, y 0,59 à 1,80,
--   z −0,42 à 0,12 ;
-- - dessous du pavillon : 3,06 (z 0,8) à 3,15 (z 1,8) ; il redescend à 2,84 au bandeau avant (z 0,6).
-- Siège du jeu placé sur le coussin à z 0,75, à 0,48 st du dossier (Comète : 0,59 ; dossier plus incliné
-- ici) : dessus d'assise y −0,353 (conducteur) et −0,368 (passager) → centre du Seat 0,2 st plus bas.
local BRIO: Kit = {
    Template = "Brio",
    ManifestId = "veh.wk_brio.meshmilano95",
    Reference = "BRIO_Caisse_Peinture",
    ReferenceCenter = Vector3.new(0.005, 1.201, 2.776),
    SeatDriver = Vector3.new(-1.2, -0.553, 0.75),
    SeatPassenger = Vector3.new(1.2, -0.568, 0.75),
    -- Pose « Citadine » (SeatPose, lot BRIO-02) : coussin 0,53 st au-dessus du plancher des pieds.
    SeatPoses = { Driver = "Citadine", Passenger = "CitadinePassager" },
    -- Plancher des pieds sous la planche de bord (relevé du 2026-11-06 ; celui du 2026-11-05 mesurait le coussin).
    Footwell = { FloorY = -0.88, FrontZ = -2.1, RearZ = -0.3 },
    -- Dessous du pavillon au droit de la place conducteur (z 1,2) : 3,10 st, soit 3,45 st au-dessus de l'assise ;
    -- 3,15 au droit des têtes (z ~1,8, buste incliné).
    RoofUnderside = 3.10,
    -- Vue cockpit inchangée (décision du propriétaire du 2026-11-06) : relevée au lot VEH3D-02 sur l'ancienne assise.
    CameraCockpit = Vector3.new(-1.2, 2.501, 1.2),
    CameraHood = Vector3.new(0, 2.356, -2.751),
    CameraBumper = Vector3.new(0, -0.286, -6.721),
    -- Caisse hors rétroviseurs (pièces peintes : demi-largeur 2,87 à 2,91 st).
    SideHalf = 2.92,
    Collisions = {
        Coque = { Center = Vector3.new(0, 0.114, 1.038), Size = Vector3.new(5.888, 1.4, 9.643) },
        BouclierAvant = { Center = Vector3.new(0, -0.111, -4.577), Size = Vector3.new(4.656, 1.45, 1.787) },
        BouclierArriere = { Center = Vector3.new(0, -0.036, 6.416), Size = Vector3.new(4.828, 1.3, 1.314) },
        Habitacle = { Center = Vector3.new(0, 1.925, 2.6), Size = Vector3.new(4.223, 2.222, 5.101) },
    },
    -- Une pièce par roue (pneu et jante fusionnés), pivot au moyeu (écart ≤ 0,052 st à la physique).
    Wheels = {
        FL = { "BRIO_Roue_AvG" },
        FR = { "BRIO_Roue_AvD" },
        RL = { "BRIO_Roue_ArG" },
        RR = { "BRIO_Roue_ArD" },
    },
    GlassPattern = "vitrage",
    Lights = {
        {
            Name = "PhareGauche",
            Light = "Head",
            Position = Vector3.new(-1.796, 0.486, -5.448),
            Size = Vector3.new(0.6, 0.3, 0.1),
        },
        {
            Name = "PhareDroit",
            Light = "Head",
            Position = Vector3.new(1.81, 0.464, -5.448),
            Size = Vector3.new(0.6, 0.3, 0.1),
        },
        {
            Name = "FeuGauche",
            Light = "Tail",
            Position = Vector3.new(-2.005, 2.393, 6.02),
            Size = Vector3.new(0.6, 0.3, 0.1),
        },
        {
            Name = "FeuDroit",
            Light = "Tail",
            Position = Vector3.new(2.042, 2.368, 6.02),
            Size = Vector3.new(0.6, 0.3, 0.1),
        },
    },
    DetailPattern = { "BRIO_Habitacle", "BRIO_Suspension", "BRIO_Garniture" },
    Paint = { Pattern = "_Peinture", NeutralColorMap = nil, Plain = true },
    -- Les verres (matériaux unis, transparence perdue à l'import) s'allument avec les blocs qu'ils couvrent.
    LightMeshes = {
        BRIO_Feu_Av = "Head",
        BRIO_VerreOptiqueAv = "Head",
        BRIO_Feu_Ar = "Tail",
        BRIO_VerreFeuAr = "Tail",
    },
    -- Volant (lot ANIM-01) : pièce séparée `BRIO_Volant` du gabarit (VEH3D-02). Jante ajustée sur 91 sommets (export
    -- LOD0, 2026-11-06) : centre (−1,166 ; 1,197 ; −0,156), à 0,005 st du centre de la boîte de la pièce ; plan incliné
    -- de 20° sur la verticale ; rayon 0,591 st (0,543 à 0,646). Composante latérale de l'axe (0,002) négligée.
    -- Rapport 14:1 (citadine) : ±490° de volant à fond en manœuvre (35°), ±126° à 140 km/h (9°).
    SteeringWheel = {
        Part = "BRIO_Volant",
        Hub = Vector3.new(-1.166, 1.197, -0.156),
        Axis = Vector3.new(0, 0.3459, 0.9383).Unit,
        GripRadius = 0.591,
        Ratio = 14,
    },
    -- Matériaux de `milano95_prepare.py` : AW_Phare, AW_VerreOptique, AW_Feu, AW_VerreFeu, AW_Clignotant, AW_Recul.
    Colors = {
        BRIO_Feu_Av = Color3.fromRGB(246, 246, 243),
        BRIO_VerreOptiqueAv = Color3.fromRGB(243, 246, 250),
        BRIO_Feu_Ar = Color3.fromRGB(212, 49, 49),
        BRIO_VerreFeuAr = Color3.fromRGB(225, 63, 63),
        BRIO_Clignotants = Color3.fromRGB(255, 179, 57),
        BRIO_Recul = Color3.fromRGB(249, 249, 249),
    },
    -- Mesure du 2026-11-05 (Blender, rayons sur la collection EXT, vitrage compris, wk_brio_milano95.blend).
    DamageMarks = {
        FrontY = -0.111,
        Front = { -5.957, -6.053, -5.96 },
        RearY = -0.036,
        Rear = { 7.597, 7.667, 7.597 },
        SideY = 0.114,
        Side = { 2.831, 2.865, 2.833 },
    },
}

MeshKitData.Kits = table.freeze({ wk_comete = COMETE, wk_brio = BRIO })

-- Identifiant numérique d'un MeshId (adresse d'actif terminée par l'identifiant numérique).
function MeshKitData.assetNumber(meshId: string): number?
    local digits = string.match(meshId, "(%d+)%s*$")
    return if digits then tonumber(digits) else nil
end

return table.freeze(MeshKitData)
