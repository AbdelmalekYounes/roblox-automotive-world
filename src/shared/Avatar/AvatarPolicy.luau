--!strict
--[[
    Politique d'avatar (lot AVATAR-01). Décision du propriétaire : R15 exclusivement ;
    l'apparence Roblox du joueur (visage, vêtements, accessoires) est conservée autant que
    possible. Révision du 2026-11-04 (propriétaire) : avatars HUMAINS uniquement, « non pas
    semi-Lego » : type de corps imposé à 1 et corps remplacé, pour tous les joueurs, par l'un
    des deux corps retenus (masculin ou féminin, au choix du joueur) ; la tête est conservée.

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

-- Corps humains imposés (décision du propriétaire, 2026-11-04) : **tous** les joueurs reçoivent
-- l'un des deux corps, au choix du joueur (« Masculin » ou « Feminin ») ; seules les parties du
-- corps sont remplacées : la TÊTE, le visage, la couleur de peau, les vêtements et les
-- accessoires du joueur sont conservés. Corps retenus par le propriétaire parmi les paquets
-- gratuits « Base Body » publiés par Roblox (créateur Roblox, identifiant 1) ; identifiants
-- relevés le 2026-11-04 sur catalog.roblox.com/v1/bundles/{id}/details (aucun inventé).
-- Clés de `Parts` : champs de `HumanoidDescription`.
export type Body = { Id: string, BundleId: number, Source: string, Parts: { [string]: number } }

AvatarPolicy.Bodies = table.freeze({
    Masculin = table.freeze({
        Id = "Masculin",
        BundleId = 995,
        Source = "Base Body - Billie",
        Parts = table.freeze({
            Torso = 11748986529,
            LeftArm = 11748981874,
            RightArm = 11748984354,
            LeftLeg = 11748983268,
            RightLeg = 11748985458,
        }),
    }),
    Feminin = table.freeze({
        Id = "Feminin",
        BundleId = 994,
        Source = "Base Body - Jordan",
        Parts = table.freeze({
            Torso = 11740060397,
            LeftArm = 11740050465,
            RightArm = 11740055375,
            LeftLeg = 11740052832,
            RightLeg = 11740057815,
        }),
    }),
} :: { [string]: Body })

-- Ordre d'affichage du choix.
AvatarPolicy.BodyOrder = table.freeze({ "Masculin", "Feminin" })
-- Corps appliqué tant que le joueur n'a pas choisi (panneau de choix affiché à l'apparition).
-- PROVISOIRE, à confirmer par le propriétaire (signalé dans le rapport de phase 1).
AvatarPolicy.DefaultBody = "Masculin"
-- Parties remplacées : jamais la tête (`Head`), pour garder le visage du joueur.
AvatarPolicy.ReplacedParts = table.freeze({ "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" })

-- Corps désigné par un identifiant reçu (client ou réglage) ; nil si inconnu.
function AvatarPolicy.body(id: any): Body?
    if type(id) ~= "string" then
        return nil
    end
    return AvatarPolicy.Bodies[id]
end

-- Vrai si les parties lues (`HumanoidDescription`) sont exactement celles du corps.
function AvatarPolicy.wearsBody(parts: { [string]: number }, bodyId: string): boolean
    local body = AvatarPolicy.Bodies[bodyId]
    if body == nil then
        return false
    end
    for _, field in AvatarPolicy.ReplacedParts do
        if parts[field] ~= body.Parts[field] then
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
