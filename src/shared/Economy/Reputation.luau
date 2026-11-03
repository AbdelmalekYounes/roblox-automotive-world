--!strict
--[[
    Réputation GÉNÉRALE à cinq niveaux (§5.1), distincte des rangs classés des
    courses (lot 0.6). Les noms sont des PROPOSITIONS d'interface ; les seuils
    sont provisoires et réglables.
]]

local Reputation = {}

export type Level = { Index: number, Name: string, MinPoints: number }

local LEVELS: { Level } = {
    { Index = 1, Name = "Débutant", MinPoints = 0 },
    { Index = 2, Name = "Amateur", MinPoints = 500 },
    { Index = 3, Name = "Confirmé", MinPoints = 2_500 },
    { Index = 4, Name = "Expert", MinPoints = 8_000 },
    { Index = 5, Name = "Légende", MinPoints = 20_000 },
}
Reputation.Levels = table.freeze(LEVELS)

function Reputation.level(points: number): Level
    local current = LEVELS[1]
    for _, level in LEVELS do
        if points >= level.MinPoints then
            current = level
        end
    end
    return current
end

-- Progression vers le niveau suivant (0..1 ; 1 au dernier niveau).
function Reputation.progress(points: number): number
    local level = Reputation.level(points)
    local following = LEVELS[level.Index + 1]
    if following == nil then
        return 1
    end
    return (points - level.MinPoints) / (following.MinPoints - level.MinPoints)
end

return table.freeze(Reputation)
