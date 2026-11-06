--!strict
--[[
    Volant affiché et prises des mains (lot ANIM-01, décisions du propriétaire du 2026-11-06). Module PUR (aucun
    service), testé par Lune ; utilisé par le serveur (articulation du volant, `Vehicles/MeshKits`) et par chaque client
    (rotation et mains, `Vehicles/SteeringWheelVisuals` et `Vehicles/SeatPoseController`).

    Rapport « réaliste » : angle du volant = angle des roues avant × rapport du modèle. Le jeu réduit déjà l'angle des
    roues avec la vitesse (`VehicleDynamics.maxSteerAngle`) : le volant fait plus d'un tour en manœuvre et tourne peu
    sur route, comme une vraie direction à rapport fixe. Il n'y a pas d'autre plafond que la butée des roues.

    Mains « qui suivent puis glissent » : prise à 9 h 15 ; les mains tournent avec la jante jusqu'à ±100°, puis restent
    posées sur la jante à cette position pendant que le volant continue de tourner sous elles (au-delà, des bras R15
    se croiseraient).

    Repère : celui du châssis (studs, avant vers −Z, haut +Y, droite +X). L'axe de la colonne pointe du volant VERS le
    conducteur. Angle positif = braquage à droite (convention de `VehicleDynamics` : SteerPosition > 0 à droite), donc
    rotation dans le sens horaire vue par le conducteur, c'est-à-dire d'un angle NÉGATIF autour de l'axe.
    Purement visuel : aucune masse, aucune collision, aucune conséquence sur la conduite.
]]

local SteeringWheel = {}

export type Spec = {
    Part: string, -- pièce du gabarit qui tourne (pivot = centre de sa boîte)
    Hub: Vector3, -- centre de la jante (repère du châssis, mesuré sur les sommets)
    Axis: Vector3, -- axe de la colonne, unitaire, du volant vers le conducteur
    GripRadius: number, -- rayon de la jante au milieu du boudin (studs)
    Ratio: number, -- rapport de direction : degrés de volant par degré de roue
}

-- Nom du Motor6D du volant (enfant de la pièce du volant), posé par le serveur, animé par chaque client.
SteeringWheel.JointName = "AWVolant"

-- Prise des mains : à 9 h 15, angles suivis jusqu'à ±100° (décision du propriétaire).
SteeringWheel.HandFollowLimit = math.rad(100)

-- Angle du volant (radians, positif à droite) pour un angle de roue avant donné (radians).
function SteeringWheel.wheelAngle(roadWheelAngle: number, ratio: number): number
    return roadWheelAngle * ratio
end

-- Rapproche `current` de `target` à vitesse bornée (radians par seconde) : lissage de la consigne répliquée (quantifiée
-- au vingtième, et brutale au clavier) chez les autres joueurs, à la vitesse de la crémaillère.
function SteeringWheel.approach(current: number, target: number, maxRate: number, dt: number): number
    local step = math.max(maxRate, 0) * math.max(dt, 0)
    return current + math.clamp(target - current, -step, step)
end

-- Rotation du volant autour de sa colonne pour un angle (positif à droite = horaire pour le conducteur).
function SteeringWheel.rotation(spec: Spec, angle: number): CFrame
    return CFrame.fromAxisAngle(spec.Axis, -angle)
end

-- Repère de l'articulation du volant dans le châssis : origine au centre de la jante, Z le long de l'axe (vers le
-- conducteur). Une rotation `CFrame.Angles(0, 0, -angle)` de ce repère fait tourner le volant de `angle`.
function SteeringWheel.jointFrame(spec: Spec): CFrame
    return CFrame.lookAt(spec.Hub, spec.Hub - spec.Axis, Vector3.yAxis)
end

-- Rotation à écrire dans `Transform` de l'articulation (repère `jointFrame`).
function SteeringWheel.jointTransform(angle: number): CFrame
    return CFrame.Angles(0, 0, -angle)
end

-- Angle suivi par les mains : celui du volant, borné à ±HandFollowLimit (au-delà, les mains glissent sur la jante).
function SteeringWheel.handAngle(angle: number): number
    return math.clamp(angle, -SteeringWheel.HandFollowLimit, SteeringWheel.HandFollowLimit)
end

--[[
    Points de prise des mains gauche et droite (repère du châssis) pour un angle de volant : sur la jante, à 9 h 15
    au repos (horizontale du plan de la jante), tournés de l'angle suivi par les mains.
]]
function SteeringWheel.grips(spec: Spec, angle: number): (Vector3, Vector3)
    local axis = spec.Axis.Unit
    -- Horizontale du plan de la jante : droite du véhicule, rendue perpendiculaire à l'axe.
    local right = Vector3.new(1, 0, 0)
    local side = right - axis * right:Dot(axis)
    side = side.Unit * spec.GripRadius
    local turn = SteeringWheel.rotation(spec, SteeringWheel.handAngle(angle))
    return spec.Hub - turn:VectorToWorldSpace(side), spec.Hub + turn:VectorToWorldSpace(side)
end

return table.freeze(SteeringWheel)
