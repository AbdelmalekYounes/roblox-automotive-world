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

-- Plages par défaut de Roblox (`GameSettingsScaleRange*`), sans unité (facteurs).
AvatarPolicy.ScaleRanges = table.freeze({
    Height = table.freeze({ Min = 0.9, Max = 1.05 }),
    Width = table.freeze({ Min = 0.7, Max = 1 }),
    Head = table.freeze({ Min = 0.95, Max = 1 }),
    BodyType = table.freeze({ Min = 0, Max = 1 }),
    Proportion = table.freeze({ Min = 0, Max = 1 }),
} :: { [string]: Range })

-- Vrai si une limitation des proportions a été décidée à la suite des essais.
AvatarPolicy.LimitedByTests = false

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
