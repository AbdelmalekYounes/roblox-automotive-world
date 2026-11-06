--!strict
--[[
    Lot PNJ-01 : allure des piétons animée par le CODE (module PUR, testé par Lune), sans aucun actif d'animation.

    Cinématique directe sur le squelette de World/PnjKits : chaque articulation reçoit une rotation locale, chaque
    pièce rigide suit son articulation. Trois allures : attente (respiration, transfert d'appui), marche, course.

    Cycle de marche (une foulée = deux pas, phase 0 → 1) : appui du talon gauche à la phase 0, du droit à 0,5.
    La phase vient de la DISTANCE parcourue divisée par la longueur de foulée : les pieds ne glissent pas, quelle que
    soit la vitesse du piéton. Ordres de grandeur de la marche humaine : 1,4 m/s ≈ foulée 1,45 m (≈ 1,9 pas/s),
    hanche ±20°, genou jusqu’à ~50° en phase oscillante, balancier des bras opposé aux jambes, bassin qui monte et
    descend de 2 à 3 cm deux fois par foulée. Course : genou ~95°, coudes pliés à ~80°, buste penché de 10°.

    Conventions (voir PnjKits) : regard vers −Z ; une rotation POSITIVE autour de X porte vers l'avant (−Z) un
    membre qui pend (cuisse, bras) ; le genou plie donc en NÉGATIF, le coude en positif.
]]

local PnjKits = require(script.Parent.PnjKits)

local PedestrianGait = {}

export type Kind = "Idle" | "Walk" | "Run"

-- Seuil de vitesse (m/s) entre marche et course.
PedestrianGait.RunThresholdMs = 2.4

-- Longueur d'une foulée complète (m) selon la vitesse et l'allure (taille 1,75 m ; × échelle de la morphologie).
function PedestrianGait.strideLength(speed: number, kind: Kind, scale: number?): number
    local s = scale or 1
    if kind == "Run" then
        return (0.9 + 0.45 * speed) * s
    end
    return (0.9 + 0.4 * math.clamp(speed, 0.5, 2.4)) * s
end

-- Allure d'après la vitesse.
function PedestrianGait.kindFor(speed: number): Kind
    if speed < 0.15 then
        return "Idle"
    elseif speed >= PedestrianGait.RunThresholdMs then
        return "Run"
    end
    return "Walk"
end

export type Pose = {
    Root: CFrame, -- décalage du bassin (montée, balancement) appliqué à l'articulation racine
    Rotations: { [string]: CFrame }, -- rotation locale de chaque articulation
}

local TAU = 2 * math.pi
local rad = math.rad

--[[
    Pose à la phase `phase` (foulées, seule la partie fractionnaire compte) pour l'allure `kind` et la vitesse
    `speed` (m/s). `time` (s) anime l'attente (respiration), `seed` décale les mouvements d'attente entre piétons.
]]
function PedestrianGait.pose(kind: Kind, phase: number, speed: number, time: number, seed: number?): Pose
    local p = phase % 1
    local rotations: { [string]: CFrame } = {}
    if kind == "Idle" then
        local t = time + (seed or 0) % 100
        local breath = math.sin(TAU * t / 4.2)
        local sway = math.sin(TAU * t / 9.5)
        rotations.Taille = CFrame.Angles(rad(-1.5 + 1.0 * breath), 0, rad(1.2 * sway))
        rotations.Cou = CFrame.Angles(rad(2 * math.sin(TAU * t / 7.1)), rad(12 * math.sin(TAU * t / 13.3)), 0)
        rotations.EpauleG = CFrame.Angles(rad(2), 0, rad(-4))
        rotations.EpauleD = CFrame.Angles(rad(2), 0, rad(4))
        rotations.CoudeG = CFrame.Angles(rad(10), 0, 0)
        rotations.CoudeD = CFrame.Angles(rad(10), 0, 0)
        -- Appui plus marqué sur une jambe qui change lentement (transfert de poids).
        rotations.HancheG = CFrame.Angles(0, 0, rad(-2 * sway))
        rotations.HancheD = CFrame.Angles(0, 0, rad(-2 * sway))
        rotations.GenouG = CFrame.Angles(rad(-3 - 3 * math.max(sway, 0)), 0, 0)
        rotations.GenouD = CFrame.Angles(rad(-3 - 3 * math.max(-sway, 0)), 0, 0)
        return { Root = CFrame.new(0.015 * sway, -0.004 * math.abs(sway), 0), Rotations = rotations }
    end

    local run = kind == "Run"
    -- Amplitudes (degrés) qui croissent avec la vitesse (une marche lente balance moins).
    local walkGain = math.clamp((speed - 0.4) / 1.0, 0.45, 1.25)
    local hipAmp = if run then 38 else 20 * walkGain
    local kneeSwing = if run then 95 else 52 * math.clamp(walkGain, 0.7, 1.15)
    local kneeStance = if run then 22 else 6
    -- Course : genou d'appui jamais tendu (amorti à la réception).
    local kneeBase = if run then 12 else 0
    local armAmp = if run then 42 else 16 * walkGain
    local elbowBase = if run then 80 else 12
    local bob = if run then 0.05 else 0.024 * walkGain
    local lean = if run then 10 else 3

    local function leg(offset: number): (CFrame, CFrame)
        local a = TAU * (p + offset)
        local hip = hipAmp * math.cos(a)
        -- Oscillation (cuisse qui revient vers l'avant) quand sin(a) < 0 ; appui sinon.
        local swing = math.max(-math.sin(a), 0)
        local knee = kneeBase + kneeStance * math.max(math.sin(a), 0) ^ 2 + kneeSwing * swing ^ 1.5
        return CFrame.Angles(rad(hip), 0, 0), CFrame.Angles(rad(-knee), 0, 0)
    end
    rotations.HancheG, rotations.GenouG = leg(0)
    rotations.HancheD, rotations.GenouD = leg(0.5)

    local function arm(offset: number, side: number): (CFrame, CFrame)
        -- Bras opposé à la jambe du même côté.
        local swingAngle = -armAmp * math.cos(TAU * (p + offset))
        local elbow = elbowBase + (if run then 10 else 14) * math.max(swingAngle / math.max(armAmp, 1), 0)
        return CFrame.Angles(rad(swingAngle), 0, rad(side * (if run then 6 else 4))), CFrame.Angles(rad(elbow), 0, 0)
    end
    rotations.EpauleG, rotations.CoudeG = arm(0, -1)
    rotations.EpauleD, rotations.CoudeD = arm(0.5, 1)

    -- Bassin : rotation autour de la verticale avec la jambe en avant, buste en contre-rotation.
    local twist = (if run then 8 else 5) * math.cos(TAU * p)
    rotations.Bassin = CFrame.Angles(0, rad(-twist), 0)
    rotations.Taille = CFrame.Angles(rad(-lean), rad(1.6 * twist), 0)
    rotations.Cou = CFrame.Angles(rad(lean * 0.6), rad(-0.6 * twist), 0)

    -- Montée et descente : plus bas aux doubles appuis (phases 0 et 0,5).
    local height = -bob * math.cos(2 * TAU * p)
    return { Root = CFrame.new(0, height, 0), Rotations = rotations }
end

--[[
    Repères (m, repère piéton) de chaque articulation pour une pose, à l'échelle `scale`. Le repère d'une
    articulation au repos vaut CFrame.new(Rest × scale).
]]
function PedestrianGait.jointFrames(pose: Pose, scale: number): { [string]: CFrame }
    local frames: { [string]: CFrame } = {}
    for _, joint in PnjKits.Joints do
        local rest = joint.Rest * scale
        local rotation = pose.Rotations[joint.Name] or CFrame.identity
        local parentName = joint.Parent
        if parentName == nil then
            frames[joint.Name] = pose.Root * CFrame.new(rest) * rotation
        else
            local parentJoint = PnjKits.joint(parentName) :: PnjKits.Joint
            local parentFrame = frames[parentName]
            frames[joint.Name] = parentFrame * CFrame.new(rest - parentJoint.Rest * scale) * rotation
        end
    end
    return frames
end

--[[
    Repère d'une pièce rigide : `rest` = repère de la pièce au repos (repère piéton, m). La pièce suit son
    articulation : repère animé de l'articulation × (repos de l'articulation)⁻¹ × repos de la pièce.
]]
function PedestrianGait.segmentFrame(
    frames: { [string]: CFrame },
    jointName: string,
    rest: CFrame,
    scale: number
): CFrame
    local joint = PnjKits.joint(jointName) :: PnjKits.Joint
    return frames[jointName] * CFrame.new(-joint.Rest * scale) * rest
end

return table.freeze(PedestrianGait)
