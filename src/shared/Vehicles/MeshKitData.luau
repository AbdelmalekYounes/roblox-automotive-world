--!strict
--[[
    Données des kits de maillages (lot VEH3D-01), module PUR (aucun service) : testé par Lune contre le gabarit
    réel de la place construite. Construction : module serveur `Vehicles/MeshKits`.

    Repère du châssis (studs, origine au centre de gravité, avant vers −Z). Valeurs MESURÉES sur le modèle (dépôt
    d'art : `vehicles/wk_comete/renders_720s/finition.json` et export `wk_comete_720s_lod0.json`, 2026-11-04).
    Modèle tiers CC BY 4.0, exception du propriétaire : docs/vehicle-3d/MODELES_TIERS.md.
]]

local MeshKitData = {}

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
    Paint: { Pattern: string, NeutralColorMap: number? },
    -- Maillages des feux séparés (export du 2026-11-04, dépôt d'art 195df9b) : rôle AWLight posé s'ils sont présents
    -- dans le gabarit (absents du premier envoi : sources seules).
    LightMeshes: { [string]: string },
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

MeshKitData.Kits = table.freeze({ wk_comete = COMETE })

-- Identifiant numérique d'un MeshId (adresse d'actif terminée par l'identifiant numérique).
function MeshKitData.assetNumber(meshId: string): number?
    local digits = string.match(meshId, "(%d+)%s*$")
    return if digits then tonumber(digits) else nil
end

return table.freeze(MeshKitData)
