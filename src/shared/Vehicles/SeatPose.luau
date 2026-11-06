--!strict
--[[
    Pose assise propre au jeu (décision D3 du propriétaire, 2026-11-04 ; docs/vehicle-3d).

    Bassin abaissé, buste incliné en arrière, jambes allongées vers le pédalier, bras vers
    le volant (conducteur seulement). Réalisation procédurale, sans actif d'animation :
    chaque client compose ces décalages avec la pose assise du moteur, sur `Transform` des
    articulations (Motor6D ou AnimationConstraint), comme le bras du téléphone (QA-A10).

    ACTIVABLE : seuls les sièges portant l'attribut `AWSeatPose` (nom d'une pose de
    `SeatPose.Poses`, ex. « Conduite » ou « Passager ») reçoivent la pose ; aucun siège des carrosseries provisoires ne le porte,
    le comportement actuel est donc inchangé. Les futurs modèles 3D (habitacles aux cotes de
    la pose) le porteront.

    Angles en degrés : tangage autour de l'axe latéral de l'articulation (positif : buste vers
    l'arrière, membre vers l'avant), lacet autour de l'axe vertical (bras rentrés vers le
    volant) ; translation en studs dans le repère de l'articulation.
    Purement visuel : aucune masse, aucune collision, aucune réplication par image.
    Module pur, gelé.
]]

local SeatPose = {}

SeatPose.Attribute = "AWSeatPose"
SeatPose.BlendS = 0.3 -- mise en place et retrait progressifs

export type JointOffset = { Pitch: number, Yaw: number?, Down: number? }
-- Articulations des hanches (LeftHip, RightHip) : cuisses relevées (pose « Sportive »).
export type Pose = { [string]: JointOffset }

local LEGS: Pose = {
    Root = { Pitch = 0, Down = 0.3 }, -- bassin abaissé dans l'assise
    Waist = { Pitch = 18 }, -- buste incliné en arrière
    Neck = { Pitch = -12 }, -- regard ramené vers la route
    LeftKnee = { Pitch = 40 }, -- jambes allongées vers le pédalier
    RightKnee = { Pitch = 40 },
}

-- Lot ANIM-01 : pour le conducteur d'un véhicule dont le volant est connu (`MeshKitData.SteeringWheel`), ces décalages
-- statiques des bras sont remplacés en jeu par la cinématique inverse des mains sur la jante (`ArmIk`,
-- `SeatPoseController`) ; ils restent la pose des bras sur les sièges sans volant connu.
local function withArms(base: Pose): Pose
    -- Bras vers le volant, rentrés vers l'axe du siège. Mesure VM du 2026-11-04 (tâche
    -- 20261104-134156) : avec 55° d'épaule et 25° de coude, les mains montaient à hauteur de
    -- tête et restaient à ±1,5 st de l'axe ; angles réduits et bras ramenés vers l'intérieur.
    local pose = table.clone(base)
    pose.LeftShoulder = { Pitch = 32, Yaw = -22 }
    pose.RightShoulder = { Pitch = 32, Yaw = 22 }
    pose.LeftElbow = { Pitch = 15 }
    pose.RightElbow = { Pitch = 15 }
    return pose
end

-- Assise très basse (Comète, lot VEH3D-01) : coussin à 0,28 st du plancher (mesuré dans Blender le 2026-11-05).
-- Avec LEGS, les pieds traversaient le plancher et le dessous de caisse (session VM, tâche 20261105-015804) :
-- bassin peu abaissé, cuisses légèrement relevées, jambes tendues vers le pédalier. Réglage par mesure VM :
-- genoux 40° → dessous des pieds à −1,5 st (sous le plancher) ; genoux 78° et cuisses 12° → +0,41 st (pieds à la
-- planche de bord, tâche 20261105-020557) ; genoux 52° : pieds posés pour les 8 morphologies, mais têtes de 3 sur 8
-- au-dessus du pavillon mesuré (2,71 st ; tâche 20261105-022424) : bassin plus enfoncé, buste plus incliné, genoux
-- un peu plus ouverts pour garder les pieds posés ; buste à 31° : la plus grande morphologie (M3) dépassait de 0,01 st
-- la marge de 2,70 st à 28° (tâche 20261105-022922).
local LOW_LEGS: Pose = {
    Root = { Pitch = 0, Down = 0.18 },
    Waist = { Pitch = 31 },
    Neck = { Pitch = -20 },
    LeftHip = { Pitch = 4 },
    RightHip = { Pitch = 4 },
    LeftKnee = { Pitch = 56 },
    RightKnee = { Pitch = 56 },
}

-- Citadine (Brio, lot BRIO-02, décision du propriétaire du 2026-11-06) : dérivée de LOW_LEGS, dont les têtes et les
-- pieds ont été MESURÉS en VM (tâche 20261105-023349, buste 31° : haut de la tête au plus 3,30 st au-dessus de
-- l'assise, morphologie M3 ; dessous des pieds 0,10 à 0,21 st sous l'assise). Habitacle de la Brio mesuré dans
-- Blender (2026-11-06) : coussin 0,53 st au-dessus du plancher des pieds (Comète : 0,28), dessous du pavillon 3,41 à
-- 3,50 st au-dessus de l'assise au droit des têtes (Comète : 3,34). Il faut donc des pieds plus bas, la tête au
-- moins aussi basse :
-- - bassin enfoncé de 0,10 st de plus (0,28) : tête et pieds 0,10 plus bas (translation pure) ;
-- - genoux 50° au lieu de 56° : jambes un peu moins tendues, pieds encore ~0,15 à 0,25 st plus bas (sensibilité
--   relevée entre les essais VM de la Comète : 0,02 à 0,04 st par degré) ;
-- - buste 31°, cou −20°, cuisses 4° : inchangés (valeurs mesurées).
-- Estimation, NON VÉRIFIÉE EN JEU : haut de la tête au plus ~3,20 st au-dessus de l'assise (M3), ~0,3 st sous le
-- pavillon ; dessous des pieds 0,1 à 0,2 st au-dessus du plancher. Le propriétaire vérifie avec plusieurs avatars.
local CITY_LEGS: Pose = table.clone(LOW_LEGS)
CITY_LEGS.Root = { Pitch = 0, Down = 0.28 }
CITY_LEGS.LeftKnee = { Pitch = 50 }
CITY_LEGS.RightKnee = { Pitch = 50 }

SeatPose.Poses = table.freeze({
    Conduite = table.freeze(withArms(LEGS)),
    Passager = table.freeze(table.clone(LEGS)),
    Sportive = table.freeze(withArms(LOW_LEGS)),
    SportivePassager = table.freeze(table.clone(LOW_LEGS)),
    Citadine = table.freeze(withArms(CITY_LEGS)),
    CitadinePassager = table.freeze(table.clone(CITY_LEGS)),
} :: { [string]: Pose })

-- Articulations des bras (poignets ajoutés au lot ANIM-01, mains orientées sur le volant) ; jamais posées au passager.
SeatPose.ArmJoints = table.freeze({
    LeftShoulder = true,
    RightShoulder = true,
    LeftElbow = true,
    RightElbow = true,
    LeftWrist = true,
    RightWrist = true,
})

-- Articulations laissées au lot PHONE-01 quand le téléphone est sorti (`AWPhoneRaised`, bras levé, QA-A10) : le bras
-- DROIT seulement. Décision du propriétaire du 2026-11-06, transmise par PHONE-01 : « il faut que ça libere qu'un
-- seul bras » ; la main gauche reste sur le volant. PHONE-01 pilote l'épaule et le coude droits.
SeatPose.PhoneArmJoints = table.freeze({ RightShoulder = true, RightElbow = true, RightWrist = true })

-- Pose demandée par la valeur de l'attribut d'un siège (nil : pose standard du moteur).
function SeatPose.poseFor(value: any): Pose?
    if type(value) ~= "string" then
        return nil
    end
    return SeatPose.Poses[value]
end

-- Décalage d'une articulation au taux d'avancement `alpha` (0 à 1) : (tangage et lacet en
-- radians, descente en studs).
function SeatPose.offset(entry: JointOffset, alpha: number): (number, number, number)
    local a = math.clamp(alpha, 0, 1)
    return math.rad(entry.Pitch * a), math.rad((entry.Yaw or 0) * a), (entry.Down or 0) * a
end

return table.freeze(SeatPose)
