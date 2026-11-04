--!strict
--[[
    Politique d'avatar (lot AVATAR-01). Décision du propriétaire : R15 exclusivement ;
    l'apparence Roblox du joueur (corps, visage, vêtements, accessoires) est conservée
    autant que possible ; pas d'avatar « Blocky » imposé ; proportions limitées
    seulement si les essais de compatibilité le justifient.

    Application :
    - réglage de la place (`StarterPlayer.GameSettingsAvatar = R15`,
      `LoadCharacterAppearance = true`, projets Rojo) ; les réglages d'avatar de
      l'expérience publiée (fenêtre « Avatar Settings » de Studio) relèvent du
      propriétaire et ne sont pas accessibles par script ;
    - contrôle au serveur (`AvatarService`) : un personnage non R15 est signalé,
      jamais converti en silence.

    Plages d'échelle : choix du joueur, c'est-à-dire les plages par défaut de Roblox
    (aucune limitation tant que les essais ne la justifient pas : `LimitedByTests`).
    Module pur : aucune dépendance au moteur, testable hors Studio.
]]

local AvatarPolicy = {}

-- Seul squelette admis (nom de `Enum.HumanoidRigType`).
AvatarPolicy.RigType = "R15"

export type Range = { Min: number, Max: number }

-- Plages d'échelle (`GameSettingsScaleRange*`), sans unité (facteurs). Plages par défaut de
-- Roblox, SAUF le type de corps : **avatars humains uniquement** (décision du propriétaire,
-- 2026-11-04 : « l'avatar humain et non pas semi-Lego ») → type de corps imposé à 1
-- (proportions humaines) ; taille, largeur, tête et finesse restent au choix du joueur.
AvatarPolicy.ScaleRanges = table.freeze({
    Height = table.freeze({ Min = 0.9, Max = 1.05 }),
    Width = table.freeze({ Min = 0.7, Max = 1 }),
    Head = table.freeze({ Min = 0.95, Max = 1 }),
    BodyType = table.freeze({ Min = 1, Max = 1 }),
    Proportion = table.freeze({ Min = 0, Max = 1 }),
} :: { [string]: Range })

-- Limitation décidée par le propriétaire (avatars humains), pas par les essais.
AvatarPolicy.LimitedByTests = false
AvatarPolicy.HumanOnly = true

-- Corps humain de remplacement des corps « en blocs » (parties du corps par défaut, identifiant
-- 0) : identifiants des parties d'un corps humain choisi par le propriétaire. VIDE tant que le
-- choix n'est pas fait : aucun identifiant n'est inventé ; seules les proportions humaines
-- sont alors imposées. Clés : champs de `HumanoidDescription`.
AvatarPolicy.HumanBody = table.freeze({} :: { [string]: number })
AvatarPolicy.BodyPartFields = table.freeze({ "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" })

-- Corps « en blocs » : toutes les parties du corps à 0 (corps par défaut de Roblox).
function AvatarPolicy.isBlockyBody(parts: { [string]: number }): boolean
    for _, field in AvatarPolicy.BodyPartFields do
        if (parts[field] or 0) ~= 0 then
            return false
        end
    end
    return true
end

-- Échelle ramenée dans sa plage (valeur non finie : minimum de la plage).
function AvatarPolicy.clampScale(name: string, value: number): number
    local range = AvatarPolicy.ScaleRanges[name]
    if range == nil then
        return value
    end
    if type(value) ~= "number" or value ~= value then
        return range.Min
    end
    return math.clamp(value, range.Min, range.Max)
end

function AvatarPolicy.isAllowedRig(rigTypeName: string): boolean
    return rigTypeName == AvatarPolicy.RigType
end

-- Vrai si chaque échelle connue est un nombre fini dans sa plage (les absentes sont ignorées).
function AvatarPolicy.scalesWithinRanges(scales: { [string]: number }): (boolean, { string })
    local outside: { string } = {}
    for name, value in scales do
        local range = AvatarPolicy.ScaleRanges[name]
        if range ~= nil then
            if type(value) ~= "number" or value ~= value or value < range.Min - 1e-6 or value > range.Max + 1e-6 then
                table.insert(outside, name)
            end
        end
    end
    table.sort(outside)
    return #outside == 0, outside
end

return table.freeze(AvatarPolicy)
