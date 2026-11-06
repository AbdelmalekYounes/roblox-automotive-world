--!strict
--[[
    Cinématique inverse à deux segments pour un bras R15 (lot ANIM-01 : mains du conducteur sur le volant). Module
    PUR (aucun service), testé par Lune. Procédural, sans actif d'animation ni contrôle IK du moteur : le calcul est
    vérifiable hors Studio et s'adapte aux proportions de chaque avatar (longueurs lues sur ses articulations).

    Conventions des articulations (Motor6D, ou AnimationConstraint avec ses deux attaches) :
        Pièce1 = Pièce0 * C0 * Transform * C1⁻¹
    Chaîne : buste ─épaule→ bras ─coude→ avant-bras ─poignet→ main. Tout est exprimé dans le repère du HAUT DU BUSTE
    (`UpperTorso`). Le coude est une charnière autour de l'axe X de son repère (comme `SeatPose` : angle positif =
    avant-bras vers l'avant) ; l'épaule est une rotule. Le poignet n'est pas modifié (main dans l'axe de l'avant-bras).

    Résolution : longueurs bras (épaule→coude) et avant-bras (coude→prise), angle du coude par la loi des cosinus, puis
    rotation de l'épaule qui porte la prise sur la cible, et rotation autour de la ligne épaule→cible qui oriente le
    coude vers la direction « pôle » (vers le bas et l'extérieur pour un conducteur). Cible hors d'allonge : épaule
    avancée d'au plus `MaxShoulderShift`, puis bras tendu vers elle (`reached` faux). Coude borné à [0, MaxElbow].
]]

local ArmIk = {}

export type Chain = {
    ShoulderC0: CFrame, -- épaule : repère dans le buste
    ShoulderC1: CFrame, -- épaule : repère dans le bras
    ElbowC0: CFrame, -- coude : repère dans le bras
    ElbowC1: CFrame, -- coude : repère dans l'avant-bras
    WristC0: CFrame, -- poignet : repère dans l'avant-bras
    WristC1: CFrame, -- poignet : repère dans la main
    Grip: Vector3, -- point de prise dans la main (attache de prise, sinon centre)
}

ArmIk.MaxElbow = math.rad(150)
-- Avancée de l'épaule (protraction) quand la prise est hors d'allonge : au plus 0,3 st (8 cm à 0,28 m/st), dans la
-- direction de la cible, par la translation de `Transform` de l'épaule. Ordre de grandeur d'un conducteur qui tend les
-- bras ; au-delà, le bras reste tendu vers la cible (`reached` faux).
ArmIk.MaxShoulderShift = 0.3
-- Poignet : rotation bornée à 80° (lot ANIM-01, main orientée sur la jante).
ArmIk.MaxWrist = math.rad(80)
local EPSILON = 1e-4

-- Rotation minimale qui porte le vecteur unitaire `from` sur le vecteur unitaire `to`.
local function rotationBetween(from: Vector3, to: Vector3): CFrame
    local cross = from:Cross(to)
    local dot = math.clamp(from:Dot(to), -1, 1)
    if cross.Magnitude < 1e-9 then
        if dot > 0 then
            return CFrame.identity
        end
        -- Opposés : demi-tour autour d'un axe perpendiculaire quelconque.
        local other = if math.abs(from.X) < 0.9 then Vector3.xAxis else Vector3.yAxis
        return CFrame.fromAxisAngle(from:Cross(other).Unit, math.pi)
    end
    return CFrame.fromAxisAngle(cross.Unit, math.atan2(cross.Magnitude, dot))
end

-- Ramène un angle dans ]−π, π].
local function wrap(angle: number): number
    local a = angle % (2 * math.pi)
    return if a > math.pi then a - 2 * math.pi else a
end

-- Longueurs du bras (pivot de l'épaule → pivot du coude) et de l'avant-bras (pivot du coude → prise).
function ArmIk.lengths(chain: Chain): (number, number)
    local elbowInShoulder = chain.ShoulderC1:Inverse() * chain.ElbowC0
    local grip = (chain.ElbowC1:Inverse() * chain.WristC0 * chain.WristC1:Inverse()) * chain.Grip
    return elbowInShoulder.Position.Magnitude, grip.Magnitude
end

-- Position de la prise dans le buste pour des rotations d'épaule et de coude données (contrôle et essais).
function ArmIk.forward(chain: Chain, shoulder: CFrame, elbow: CFrame): Vector3
    local grip = (chain.ElbowC1:Inverse() * chain.WristC0 * chain.WristC1:Inverse()) * chain.Grip
    return (chain.ShoulderC0 * shoulder * chain.ShoulderC1:Inverse() * chain.ElbowC0 * elbow) * grip
end

-- Position du pivot du coude dans le buste pour une rotation d'épaule donnée.
function ArmIk.elbowPosition(chain: Chain, shoulder: CFrame): Vector3
    return (chain.ShoulderC0 * shoulder * chain.ShoulderC1:Inverse() * chain.ElbowC0).Position
end

-- Repères intermédiaires de la chaîne : coude vu de l'épaule, prise vue du coude, pivot de l'épaule vu du coude.
local function parts(chain: Chain): (CFrame, Vector3, Vector3)
    local a = chain.ShoulderC1:Inverse() * chain.ElbowC0
    local b = (chain.ElbowC1:Inverse() * chain.WristC0 * chain.WristC1:Inverse()) * chain.Grip
    return a, b, a:PointToObjectSpace(Vector3.zero)
end

-- Termes de la distance épaule → prise en fonction du pli φ du coude (charnière X) :
--   d²(φ) = L1² + L2² − 2 (uₓbₓ + P cos φ + Q sin φ) = L1² + L2² − 2 (uₓbₓ + M cos(φ − δ)).
local function hingeTerms(u: Vector3, b: Vector3): (number, number, number)
    local p = u.Y * b.Y + u.Z * b.Z
    local q = u.Z * b.Y - u.Y * b.Z
    return u.X * b.X, math.sqrt(p * p + q * q), math.atan2(q, p)
end

--[[
    Allonge minimale et maximale (pivot de l'épaule → prise) que permet la charnière du coude. Plus courte que la
    somme des deux segments quand le pivot de l'épaule n'est pas dans le plan de pli du coude (décalages des attaches).
]]
function ArmIk.reach(chain: Chain): (number, number)
    local _, b, u = parts(chain)
    local base = u.Magnitude ^ 2 + b.Magnitude ^ 2
    local axial, m = hingeTerms(u, b)
    return math.sqrt(math.max(base - 2 * (axial + m), 0)), math.sqrt(math.max(base - 2 * (axial - m), 0))
end

--[[
    Rotations à écrire dans `Transform` de l'épaule et du coude pour que la prise atteigne `target` (point dans le
    buste), le coude orienté vers `pole` (direction dans le buste). Rend aussi `reached` (cible à portée).
]]
function ArmIk.solve(chain: Chain, target: Vector3, pole: Vector3, maxShift: number?): (CFrame, CFrame, boolean)
    local a, b, u = parts(chain)
    local g = chain.ShoulderC0:PointToObjectSpace(target) -- cible dans le repère de l'épaule (pivot à l'origine)
    local axial, m, delta = hingeTerms(u, b)
    if a.Position.Magnitude < EPSILON or b.Magnitude < EPSILON or g.Magnitude < EPSILON or m < EPSILON then
        return CFrame.identity, CFrame.identity, false
    end
    local minReach, maxReach = ArmIk.reach(chain)
    minReach += EPSILON
    maxReach *= 1 - EPSILON
    -- Hors d'allonge : épaule avancée vers la cible (bornée), la suite se résout depuis le pivot déplacé.
    local shift = math.clamp(g.Magnitude - maxReach, 0, math.max(maxShift or ArmIk.MaxShoulderShift, 0))
    local offset = g.Unit * shift
    g -= offset
    local distance = g.Magnitude
    local reached = distance >= minReach and distance <= maxReach + 1e-6
    local d = math.clamp(distance, minReach, maxReach)

    -- 1. Coude : pli φ qui donne la distance voulue, cos(φ − δ) = (L1² + L2² − d² − 2 uₓbₓ) / 2M.
    local base = u.Magnitude ^ 2 + b.Magnitude ^ 2
    local spread = math.acos(math.clamp((base - d * d - 2 * axial) / (2 * m), -1, 1))
    local first, second = wrap(delta + spread), wrap(delta - spread)
    -- Pli naturel : angle positif (avant-bras vers l'avant), le plus petit ; à défaut, le négatif le plus proche de 0.
    local function score(angle: number): number
        return if angle >= 0 then angle else 10 - angle
    end
    local bend = math.clamp(if score(first) <= score(second) then first else second, 0, ArmIk.MaxElbow)
    local elbow = CFrame.Angles(bend, 0, 0)

    -- 2. Épaule : porter la prise sur la cible, puis tourner autour de la ligne épaule→cible vers le pôle.
    local v = (a * elbow) * b
    local direction = g.Unit
    local swing = rotationBetween(v.Unit, direction)
    local elbowAt = swing * a.Position
    local poleLocal = chain.ShoulderC0:VectorToObjectSpace(pole)
    local e = elbowAt - direction * elbowAt:Dot(direction)
    local w = poleLocal - direction * poleLocal:Dot(direction)
    local twist = CFrame.identity
    if e.Magnitude > EPSILON and w.Magnitude > EPSILON then
        local angle = math.atan2(direction:Dot(e:Cross(w)), e:Dot(w))
        twist = CFrame.fromAxisAngle(direction, angle)
    end
    return CFrame.new(offset) * twist * swing, elbow, reached
end

-- Repère de l'avant-bras dans le buste pour des rotations d'épaule et de coude données.
function ArmIk.lowerArm(chain: Chain, shoulder: CFrame, elbow: CFrame): CFrame
    return chain.ShoulderC0 * shoulder * chain.ShoulderC1:Inverse() * chain.ElbowC0 * elbow * chain.ElbowC1:Inverse()
end

-- Repère de la main dans le buste pour des rotations d'épaule, de coude et de poignet données.
function ArmIk.hand(chain: Chain, shoulder: CFrame, elbow: CFrame, wrist: CFrame): CFrame
    return ArmIk.lowerArm(chain, shoulder, elbow) * chain.WristC0 * wrist * chain.WristC1:Inverse()
end

--[[
    Rotation du poignet (à écrire dans `Transform`) qui donne à la main l'orientation de `hand` (repère voulu dans le
    buste), bornée à MaxWrist. Le pivot du poignet ne bouge pas : viser d'abord le poignet (`solve` avec
    `Grip = WristC1.Position`), au point `hand * WristC1.Position`, pour que la main tombe sur `hand`.
]]
function ArmIk.wrist(chain: Chain, shoulder: CFrame, elbow: CFrame, hand: CFrame): CFrame
    local parent = ArmIk.lowerArm(chain, shoulder, elbow) * chain.WristC0
    local rotation = (parent:Inverse() * hand * chain.WristC1).Rotation
    local axis, angle = rotation:ToAxisAngle()
    if math.abs(angle) > ArmIk.MaxWrist then
        return CFrame.fromAxisAngle(axis, math.sign(angle) * ArmIk.MaxWrist)
    end
    return rotation
end

return table.freeze(ArmIk)
