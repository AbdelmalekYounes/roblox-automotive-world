--!strict
--[[
    Téléphone tenu en main (lot PHONE-01), PUR : cotes du modèle 3D original, prise en main, pose du
    bras qui le tient, cadrage de la caméra sur l'écran et choix de l'affichage.

    Décisions du propriétaire (2026-11-06) :
    - l'interface des applications est dessinée chez son utilisateur EXACTEMENT sur l'écran du modèle 3D
      tenu en main (calque d'écran recalé à chaque image), la caméra zoomant sur cet écran ; les autres
      joueurs voient le personnage tenir le téléphone, écran générique ;
    - réglage « Auto / En main / Classique » (Auto : en main sauf disposition compacte, où l'ancien
      téléphone dans le coin reste plus lisible) ;
    - à pied, le personnage s'arrête pendant l'usage ; en voiture, le zoom a lieu aussi en roulant.

    Unités : studs (1 st = 0,28 m) et degrés dans les tableaux, radians dans les calculs.
    Repère du téléphone : X largeur, Y hauteur (haut de l'écran), face avant (écran) vers −Z
    (`LookVector`), comme la face `Front` des pièces Roblox.
    Module pur, gelé : aucun service Roblox (seuls les types de valeur CFrame, Vector2, Vector3).
]]

local PhoneHold = {}

-- Attribut du personnage posé par le serveur tant que le téléphone est sorti (lu par tous les clients :
-- bras levé ; la pose assise ne touche plus aux bras, `SeatPose.ArmJoints`).
PhoneHold.Attribute = "AWPhoneRaised"
PhoneHold.ModelName = "TelephoneAW"
PhoneHold.BodyName = "Boitier"
PhoneHold.ScreenName = "Ecran"

-- Écran : même rapport que l'écran de l'interface (360 × 760 px logiques, téléphone « Normal » de la
-- maquette moins son bord de 10 px) pour que le calque recouvre exactement la dalle 3D.
PhoneHold.ScreenPixels = Vector2.new(360, 760)
local SCREEN_HEIGHT = 0.5 -- st (14 cm)
PhoneHold.Screen = table.freeze({
    Width = SCREEN_HEIGHT * 360 / 760, -- 0,237 st (6,6 cm)
    Height = SCREEN_HEIGHT,
    Depth = 0.002,
})
-- Boîtier : ≈ 7,5 × 15,2 × 0,84 cm, coins arrondis (rayon 1,1 cm), bord noir de 4 à 6 mm autour de la dalle.
PhoneHold.Body = table.freeze({
    Width = PhoneHold.Screen.Width + 0.032,
    Height = SCREEN_HEIGHT + 0.044,
    Thickness = 0.03,
    Corner = 0.04,
})

--[[
    Pose du bras droit (téléphone dans la main droite), décalages multipliés dans `Transform` après
    l'animation, sur l'épaule et le coude du R15 (Motor6D ou AnimationConstraint).
    Ordre des rotations (`CFrame.fromEulerAnglesYXZ`) : tangage d'abord (bras levé vers l'avant), puis
    lacet autour de la verticale du buste (bras ramené vers l'axe du corps), dans le repère de l'épaule.
    Recherche sur le gabarit R15 « bloc » par défaut (cotes approchées, voir tests/lune/specs/Phone01) :
    main devant la poitrine, ≈ 0,3 st à droite de l'axe, ≈ 0,75 st au-dessus du centre du buste et
    1,4 st devant. NON VÉRIFIÉ EN JEU : silhouettes et avatars réels peuvent demander un réglage.
]]
export type JointOffset = { Pitch: number, Yaw: number?, Roll: number? }
PhoneHold.Arm = table.freeze({
    RightShoulder = table.freeze({ Pitch = 65, Yaw = 45 }),
    RightElbow = table.freeze({ Pitch = 55 }),
} :: { [string]: JointOffset })
-- Pièce qui porte chaque articulation du bras (R15 exclusivement, AvatarPolicy).
PhoneHold.ArmParts =
    table.freeze({ RightShoulder = "RightUpperArm", RightElbow = "RightLowerArm" } :: { [string]: string })
PhoneHold.RaiseS = 0.3 -- montée et descente du bras (s)

--[[
    Prise en main : position du centre du boîtier et orientation dans le repère de `RightHand`.
    Calculée sur le gabarit R15 « bloc » avec la pose ci-dessus pour que l'écran regarde les yeux
    (≈ 1,1 st, 30 cm, regard 35° vers le bas) : boîtier contre la paume, haut de l'écran vers le haut.
    Angles : `CFrame.fromEulerAnglesYXZ` (degrés).
]]
PhoneHold.Grip = table.freeze({
    Position = Vector3.new(-0.0835, -0.0635, -0.19),
    Pitch = 1.40,
    Yaw = 47.95,
    Roll = -128.64,
})

function PhoneHold.gripCFrame(): CFrame
    local g = PhoneHold.Grip
    return CFrame.new(g.Position) * CFrame.fromEulerAnglesYXZ(math.rad(g.Pitch), math.rad(g.Yaw), math.rad(g.Roll))
end

-- Décalage d'une articulation du bras au taux `alpha` (0 = bras libre, 1 = téléphone tenu).
function PhoneHold.jointOffset(name: string, alpha: number): CFrame
    local entry = PhoneHold.Arm[name]
    if entry == nil then
        return CFrame.identity
    end
    local a = math.clamp(if alpha == alpha then alpha else 0, 0, 1)
    return CFrame.fromEulerAnglesYXZ(
        math.rad(entry.Pitch * a),
        math.rad((entry.Yaw or 0) * a),
        math.rad((entry.Roll or 0) * a)
    )
end

--[[
    Cadrage de la caméra : posée face à l'écran, sur sa normale, haut de l'image = haut de l'écran.
    Dans cette position, l'écran se projette en rectangle centré dans la vue, de hauteur `Fill` × hauteur
    de la vue (calcul exact, sans dépendre de l'ordre de mise à jour des caméras).
    - Fov : champ de vision vertical pendant l'usage (degrés) ;
    - Fill / FillCloser : part de la hauteur de la vue occupée par l'écran (normal, « + » agrandi) ;
    - BlendS : durée du zoom aller et retour ; ReducedBlendS : avec « Réduire les animations » ;
    - OverlayAt : avancement du zoom à partir duquel l'interface est affichée sur l'écran ;
    - ModelTimeoutS : délai d'attente du modèle créé par le serveur, au-delà : affichage classique.
]]
PhoneHold.Framing = table.freeze({
    Fov = 40,
    Fill = 0.84,
    FillCloser = 0.94,
    BlendS = 0.35,
    ReducedBlendS = 0.05,
    OverlayAt = 0.98,
    ModelTimeoutS = 2,
    HideHeadAbove = 0.5, -- tête masquée localement au-delà de la moitié du zoom (la caméra passe devant le visage)
})

-- Distance écran-caméra (st) pour que l'écran occupe `fill` de la hauteur de la vue.
function PhoneHold.viewDistance(screenHeight: number, fovDeg: number, fill: number): number
    local half = math.tan(math.rad(math.clamp(fovDeg, 1, 120)) / 2)
    local f = math.clamp(fill, 0.05, 1)
    return screenHeight / (2 * f * half)
end

-- Vue de la caméra devant l'écran (`screen` : repère de la dalle, face avant vers −Z).
function PhoneHold.viewCFrame(screen: CFrame, distance: number): CFrame
    -- Recul le long de la normale de l'écran, puis demi-tour pour regarder la dalle, même verticale.
    return screen * CFrame.new(0, 0, -distance) * CFrame.Angles(0, math.pi, 0)
end

-- Rectangle de l'interface dans la vue (px) : centre et taille, pour une vue de `viewport` px.
function PhoneHold.overlayRect(viewport: Vector2, fill: number): (Vector2, Vector2)
    local height = viewport.Y * math.clamp(fill, 0.05, 1)
    local width = height * PhoneHold.ScreenPixels.X / PhoneHold.ScreenPixels.Y
    return Vector2.new(viewport.X / 2, viewport.Y / 2), Vector2.new(width, height)
end

-- Affichage effectif : réglage du joueur et disposition compacte (petit écran, mobile).
export type Display = "InHand" | "Classic"
function PhoneHold.display(preference: any, compact: boolean): Display
    if preference == "InHand" or preference == "Classic" then
        return preference
    end
    return if compact then "Classic" else "InHand"
end

-- Le personnage doit-il rester immobile ? (téléphone en main, à pied ; jamais au volant ni passager).
function PhoneHold.freezesWalking(inHand: boolean, seated: boolean): boolean
    return inHand and not seated
end

return table.freeze(PhoneHold)
