--!strict
--[[
    Pose assise propre au jeu (décision D3 du propriétaire, 2026-11-04 ; docs/vehicle-3d).

    Bassin abaissé, buste incliné en arrière, jambes allongées vers le pédalier, bras vers
    le volant (conducteur seulement). Réalisation procédurale, sans actif d'animation :
    chaque client compose ces décalages avec la pose assise du moteur, sur `Transform` des
    articulations (Motor6D ou AnimationConstraint), comme le bras du téléphone (QA-A10).

    ACTIVABLE : seuls les sièges portant l'attribut `AWSeatPose` (« Conduite » ou
    « Passager ») reçoivent la pose ; aucun siège des carrosseries provisoires ne le porte,
    le comportement actuel est donc inchangé. Les futurs modèles 3D (habitacles aux cotes de
    la pose) le porteront.

    Angles en degrés autour de l'axe latéral de l'articulation (positif : buste vers
    l'arrière, membre vers l'avant), translation en studs dans le repère de l'articulation.
    Purement visuel : aucune masse, aucune collision, aucune réplication par image.
    Module pur, gelé.
]]

local SeatPose = {}

SeatPose.Attribute = "AWSeatPose"
SeatPose.BlendS = 0.3 -- mise en place et retrait progressifs

export type JointOffset = { Pitch: number, Down: number? }
export type Pose = { [string]: JointOffset }

local LEGS: Pose = {
    Root = { Pitch = 0, Down = 0.3 }, -- bassin abaissé dans l'assise
    Waist = { Pitch = 18 }, -- buste incliné en arrière
    Neck = { Pitch = -12 }, -- regard ramené vers la route
    LeftKnee = { Pitch = 40 }, -- jambes allongées vers le pédalier
    RightKnee = { Pitch = 40 },
}

local function withArms(base: Pose): Pose
    local pose = table.clone(base)
    pose.LeftShoulder = { Pitch = 55 } -- bras vers le volant
    pose.RightShoulder = { Pitch = 55 }
    pose.LeftElbow = { Pitch = 25 }
    pose.RightElbow = { Pitch = 25 }
    return pose
end

SeatPose.Poses = table.freeze({
    Conduite = table.freeze(withArms(LEGS)),
    Passager = table.freeze(table.clone(LEGS)),
} :: { [string]: Pose })

-- Articulations des bras : jamais modifiées quand le téléphone est sorti (bras levé, QA-A10).
SeatPose.ArmJoints = table.freeze({ LeftShoulder = true, RightShoulder = true, LeftElbow = true, RightElbow = true })

-- Pose demandée par la valeur de l'attribut d'un siège (nil : pose standard du moteur).
function SeatPose.poseFor(value: any): Pose?
    if type(value) ~= "string" then
        return nil
    end
    return SeatPose.Poses[value]
end

-- Décalage d'une articulation au taux d'avancement `alpha` (0 à 1) : (angle en radians, descente en studs).
function SeatPose.offset(entry: JointOffset, alpha: number): (number, number)
    local a = math.clamp(alpha, 0, 1)
    return math.rad(entry.Pitch * a), (entry.Down or 0) * a
end

return table.freeze(SeatPose)
