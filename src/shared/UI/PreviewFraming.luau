--!strict
--[[
    Aperçu 3D du garage (lot UI-03, rendu par ViewportFrame choisi par le propriétaire le 2026-11-05) :
    règles PURES, testables hors Studio (Lune).

    - cadrage : distance de caméra pour que le véhicule entier tienne dans la zone 3D à toutes les orientations
      de la rotation (boîte du véhicule, perspective comprise), quel que soit le rapport largeur / hauteur ;
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
-- Marge autour du véhicule (1 = tangent aux bords de la zone à son orientation la plus large).
-- Demande du propriétaire (2026-11-05, « plus grand ») : cadrage serré sur la boîte du véhicule, 4 % de marge.
PreviewFraming.Margin = 1.04
-- Pas d'échantillonnage des orientations pour le cadrage (degrés) : 5° → 72 orientations par calcul.
PreviewFraming.FitStep = 5
-- Rotation automatique (degrés par seconde), coupée par « réduire les animations ».
PreviewFraming.AutoSpeed = 12
-- Glisser à la souris ou au doigt : degrés par pixel.
PreviewFraming.DragSpeed = 0.4
-- Stick droit de la manette : degrés par seconde à fond, zone morte.
PreviewFraming.StickSpeed = 90
PreviewFraming.StickDeadZone = 0.2
-- Délai minimal entre deux demandes d'un même joueur au serveur (secondes).
PreviewFraming.RequestInterval = 0.15

-- Cadrage serré : distance minimale pour que les 8 coins de la boîte du
-- véhicule (demi-dimensions hx, hy, hz, centrée sur le point visé) restent dans le champ, perspective comprise, pour
-- TOUTES les orientations de la rotation (pas FitStep) avec la plongée `pitchDeg`. La distance ne varie donc pas
-- pendant la rotation (pas d'effet de zoom), et le véhicule remplit la zone à son orientation la plus large.
-- Repère caméra : la caméra regarde vers -Z depuis (0, 0, d) ; un point (x, y, z) tient si
-- |x| × marge ≤ (d - z) × tan(h/2) et |y| × marge ≤ (d - z) × tan(v/2).
function PreviewFraming.fitDistance(
    hx: number,
    hy: number,
    hz: number,
    fovDeg: number,
    aspect: number,
    pitchDeg: number,
    margin: number?
): number
    local m = margin or PreviewFraming.Margin
    local tanV = math.tan(math.rad(fovDeg) / 2)
    local tanH = tanV * (if aspect > 0 then aspect else 1)
    local cp, sp = math.cos(math.rad(pitchDeg)), math.sin(math.rad(pitchDeg))
    local best = 0
    for step = 0, 359, PreviewFraming.FitStep do
        local a = math.rad(step)
        local ca, sa = math.cos(a), math.sin(a)
        for _, sx in { -1, 1 } do
            for _, sy in { -1, 1 } do
                for _, sz in { -1, 1 } do
                    local x, y, z = sx * hx, sy * hy, sz * hz
                    -- Inverse de l'orbite : rotation autour de Y (-angle), puis autour de X (plongée).
                    local x1, z1 = x * ca - z * sa, x * sa + z * ca
                    local y2, z2 = y * cp - z1 * sp, y * sp + z1 * cp
                    best = math.max(best, z2 + math.abs(x1) * m / tanH, z2 + math.abs(y2) * m / tanV)
                end
            end
        end
    end
    return best
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
