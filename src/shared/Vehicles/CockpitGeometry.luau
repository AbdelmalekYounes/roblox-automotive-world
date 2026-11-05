--!strict
--[[
    Point de vue cockpit (lot 0.9.1, QA-F15) : hauteur des yeux du conducteur.

    Constat (captures inspectées, tâche VM 20261103-200648) : à hauteur fixe
    (assise + 2,45 studs), le centre du volant se trouvait presque à hauteur des
    yeux (7 cm plus bas sur les prototypes) ; le volant, vu de face, cachait le
    milieu de la route. Règle : les yeux sont relevés juste assez pour que le
    HAUT du volant passe au moins MinWheelDropDeg sous la ligne de visée, sans
    approcher du pavillon. Purement visuel : aucune masse, aucune physique.
    Unités : studs (repère du châssis).
]]

local CockpitGeometry = {}

CockpitGeometry.EyeAboveSeat = 2.45 -- yeux d'un avatar assis au-dessus de l'assise
CockpitGeometry.MinWheelDropDeg = 10 -- haut du volant sous la ligne de visée
CockpitGeometry.RoofClearance = 0.6 -- marge sous le pavillon

-- Hauteur des yeux. `roofY` : nil pour un véhicule ouvert (prototype, roadster).
function CockpitGeometry.eyeY(seatY: number, wheelTopY: number, wheelDistance: number, roofY: number?): number
    local base = seatY + CockpitGeometry.EyeAboveSeat
    local needed = wheelTopY + math.max(wheelDistance, 0.5) * math.tan(math.rad(CockpitGeometry.MinWheelDropDeg))
    local eye = math.max(base, needed)
    if roofY then
        eye = math.min(eye, roofY - CockpitGeometry.RoofClearance)
    end
    return eye
end

-- Angle (degrés) entre la ligne de visée horizontale et le haut du volant.
function CockpitGeometry.wheelDropDeg(eyeY: number, wheelTopY: number, wheelDistance: number): number
    return math.deg(math.atan2(eyeY - wheelTopY, math.max(wheelDistance, 1e-3)))
end

return table.freeze(CockpitGeometry)
