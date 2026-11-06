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

-- Main posée sur la jante (retour du propriétaire du 2026-11-06 : mains dans l'axe de l'avant-bras, doigts tendus à
-- côté de la jante, « les mains n'attrapent pas le volant ») : centre de la main décalé vers l'extérieur de la jante
-- (demi-épaisseur de la main et boudin, en studs) ; doigts vers l'avant et vers le moyeu, autour de la jante.
SteeringWheel.GripOut = 0.12
SteeringWheel.FingerInward = 0.5

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

--[[
    Repère voulu de la main (`side` : −1 gauche, +1 droite) dans le châssis, pour un angle de volant. Convention des
    mains R15 au repos : axe Y de la main vers le poignet, pouce vers −Z, paume vers l'intérieur (−X pour la main
    droite, +X pour la gauche). Main posée :
    - pouce le long de la jante, vers le haut à 9 h 15 (la jante traverse le poing) ;
    - paume tournée vers le moyeu ; doigts vers l'avant (−axe) et vers le moyeu, autour de la jante ;
    - centre de la main à `GripOut` à l'extérieur de la jante.
    Le repère tourne avec les prises (suivi jusqu'à ±HandFollowLimit, puis glissement).
]]
function SteeringWheel.handFrame(spec: Spec, angle: number, side: number): CFrame
    local axis = spec.Axis.Unit
    local right = Vector3.new(1, 0, 0)
    local horizontal = (right - axis * right:Dot(axis)).Unit
    local turn = SteeringWheel.rotation(spec, SteeringWheel.handAngle(angle))
    local radial = turn:VectorToWorldSpace(horizontal * (if side < 0 then -1 else 1))
    local thumb = if side < 0 then radial:Cross(axis) else axis:Cross(radial)
    local y = (axis + radial * SteeringWheel.FingerInward).Unit
    local z = -thumb.Unit
    local x = y:Cross(z)
    return CFrame.fromMatrix(spec.Hub + radial * (spec.GripRadius + SteeringWheel.GripOut), x, y, z)
end

return table.freeze(SteeringWheel)
