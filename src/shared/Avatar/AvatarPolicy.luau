--!strict
--[[
    Politique d'avatar (lot AVATAR-01). Décision du propriétaire : R15 exclusivement ;
    l'apparence Roblox du joueur (visage, vêtements, accessoires) est conservée autant que
    possible. Révision du 2026-11-04 (propriétaire) : avatars HUMAINS uniquement, « non pas
    semi-Lego » : type de corps imposé à 1 et corps remplacé, pour tous les joueurs, par l'un
    des deux corps retenus (masculin ou féminin, au choix du joueur) ; la tête est conservée, sauf
    une tête classique « bloc », remplacée par celle du corps (décision du même jour).

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
-- `Head` : tête du paquet, posée SEULEMENT à la place d'une tête classique « bloc » (voir plus bas).
export type Body = { Id: string, BundleId: number, Source: string, Parts: { [string]: number }, Head: number }

AvatarPolicy.Bodies = table.freeze({
    Masculin = table.freeze({
        Id = "Masculin",
        BundleId = 995,
        Source = "Base Body - Billie",
        Head = 11748988354, -- « Billie - Head »
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
        Head = 11740063830, -- « Jordan - Head »
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
-- Parties toujours remplacées. La tête (`Head`) ne l'est que si elle est classique (`headFor`).
AvatarPolicy.ReplacedParts = table.freeze({ "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" })

-- Têtes classiques « bloc » (décision du propriétaire, 2026-11-04 : « Remplacer têtes
-- classiques ») : remplacées par la tête du corps choisi, ce qui change le visage ; toute autre tête
-- est conservée. Critère mesuré par le moteur (tâche VM 20261104-161530) : la tête par défaut et 5
-- têtes classiques de Roblox, publiées comme « têtes dynamiques », sont des cubes (largeur et
-- profondeur / hauteur de 0,99 à 1,00) ; les 8 têtes réalistes des paquets 988 à 995 sont plus hautes
-- que larges (0,65 à 0,71 ; profondeur 0,74 à 0,80). Seuil : 0,90 sur les deux rapports. La forme
-- ne dépend pas de l'échelle de tête (homothétie).
AvatarPolicy.ClassicHeadMinRatio = 0.9

-- Vrai si la pièce `Head` mesurée (studs) a la forme d'une tête classique « bloc ».
function AvatarPolicy.isClassicHeadShape(x: number, y: number, z: number): boolean
    if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" or not (y > 0) then
        return false
    end
    return x / y >= AvatarPolicy.ClassicHeadMinRatio and z / y >= AvatarPolicy.ClassicHeadMinRatio
end

-- Tête à porter avec le corps `bodyId` : celle du paquet si la tête du joueur est classique
-- (identifiant 0 : tête par défaut, toujours classique), sinon celle du joueur.
function AvatarPolicy.headFor(bodyId: string, playerHead: number, classic: boolean): number
    local body = AvatarPolicy.Bodies[bodyId]
    if body ~= nil and (classic or playerHead == 0) then
        return body.Head
    end
    return playerHead
end

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
