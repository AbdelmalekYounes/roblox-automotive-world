--!strict
--[[
    Aperçu 3D du garage (lot UI-03, rendu par ViewportFrame choisi par le propriétaire le 2026-11-05) :
    règles PURES, testables hors Studio (Lune).

    - cadrage : distance de caméra pour que le véhicule entier tienne dans la zone 3D, quelle que soit sa forme
      (sphère englobante) et le rapport largeur / hauteur de la zone ;
    - demande au serveur : seul un identifiant de modèle bien formé est accepté (le serveur vérifie ensuite qu'il
      existe dans le catalogue) ;
    - rotation : vitesses et angle de plongée de la caméra.
    Unités : degrés pour les réglages, studs pour les distances.
]]

local PreviewFraming = {}

-- Champ vertical de la caméra (degrés) : focale longue, peu de déformation de perspective sur une voiture.
PreviewFraming.Fov = 30
-- Plongée de la caméra (degrés sous l'horizontale) : on voit le capot et le pavillon sans écraser le profil.
PreviewFraming.Pitch = 14
-- Marge autour de la sphère englobante (1 = véhicule tangent aux bords de la zone).
PreviewFraming.Margin = 1.08
-- Rotation automatique (degrés par seconde), coupée par « réduire les animations ».
PreviewFraming.AutoSpeed = 12
-- Glisser à la souris ou au doigt : degrés par pixel.
PreviewFraming.DragSpeed = 0.4
-- Stick droit de la manette : degrés par seconde à fond, zone morte.
PreviewFraming.StickSpeed = 90
PreviewFraming.StickDeadZone = 0.2
-- Délai minimal entre deux demandes d'un même joueur au serveur (secondes).
PreviewFraming.RequestInterval = 0.15

-- Distance caméra → centre pour qu'une sphère de rayon `radius` tienne dans la vue (champ vertical `fovDeg`,
-- rapport largeur / hauteur `aspect`). Le champ horizontal se déduit du vertical : tan(h/2) = tan(v/2) × aspect ;
-- l'angle limitant est le plus petit des deux.
function PreviewFraming.distance(radius: number, fovDeg: number, aspect: number, margin: number?): number
    local half = math.rad(fovDeg) / 2
    local safeAspect = if aspect > 0 then aspect else 1
    local horizontalHalf = math.atan(math.tan(half) * safeAspect)
    local limiting = math.min(half, horizontalHalf)
    return math.max(radius, 0) * (margin or PreviewFraming.Margin) / math.sin(limiting)
end

-- Identifiant de modèle acceptable dans une demande client : chaîne courte de lettres, chiffres et « _ ».
function PreviewFraming.validModelId(value: any): boolean
    return type(value) == "string" and #value >= 1 and #value <= 64 and string.match(value, "^[%w_]+$") ~= nil
end

-- Angle de rotation suivant (degrés, ramené dans [0, 360[) : rotation automatique, glisser, stick.
function PreviewFraming.step(angle: number, dt: number, auto: boolean, dragPixels: number, stickX: number): number
    local value = angle
    if auto then
        value += PreviewFraming.AutoSpeed * dt
    end
    value -= dragPixels * PreviewFraming.DragSpeed
    if math.abs(stickX) > PreviewFraming.StickDeadZone then
        value -= stickX * PreviewFraming.StickSpeed * dt
    end
    return value % 360
end

return table.freeze(PreviewFraming)
