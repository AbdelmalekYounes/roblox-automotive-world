--!strict
--[[
    Saisons classées et rangs de COMPÉTITION (lot 0.6, §6.3), purs.

    - Saisons de huit semaines, numérotées depuis une origine fixe (instant
      UTC) : la saison courante se déduit de l'horloge serveur seule.
    - Cinq rangs : Bronze, Argent, Or, Platine, Diamant, par points de
      classement. Ils sont COMPLÈTEMENT INDÉPENDANTS des cinq niveaux de
      réputation générale (Shared/Economy/Reputation) : autre table, autres
      seuils, autre champ du profil.
    - Deux échelles : « Race » (sprint et circuit, Elo multijoueur) et
      « Drift » (logique propre, voir Racing/RankedService).
    Seuils et origine provisoires, réglables.
]]

local Seasons = {}

Seasons.LengthS = 8 * 7 * 24 * 3600
-- Origine : lundi 2 novembre 2026, 00:00 UTC (saison 1). Réglable avant ouverture.
Seasons.EpochUnix = 1_793_577_600
Seasons.StartPoints = 1000
-- Transition de saison : rapprochement de moitié vers le point de départ.
Seasons.SoftReset = 0.5
Seasons.Ladders = table.freeze({ "Race", "Drift" })

export type Rank = { Index: number, Name: string, MinPoints: number }

local RANKS: { Rank } = {
    { Index = 1, Name = "Bronze", MinPoints = 0 },
    { Index = 2, Name = "Argent", MinPoints = 1100 },
    { Index = 3, Name = "Or", MinPoints = 1250 },
    { Index = 4, Name = "Platine", MinPoints = 1450 },
    { Index = 5, Name = "Diamant", MinPoints = 1700 },
}
Seasons.Ranks = table.freeze(RANKS)

function Seasons.rank(points: number): Rank
    local current = RANKS[1]
    for _, rank in RANKS do
        if points >= rank.MinPoints then
            current = rank
        end
    end
    return current
end

-- Numéro de la saison à l'instant `unix` (1 = première saison ; 0 avant l'origine).
function Seasons.index(unix: number): number
    if unix < Seasons.EpochUnix then
        return 0
    end
    return math.floor((unix - Seasons.EpochUnix) / Seasons.LengthS) + 1
end

-- Début et fin (exclue) d'une saison.
function Seasons.bounds(index: number): (number, number)
    local start = Seasons.EpochUnix + (index - 1) * Seasons.LengthS
    return start, start + Seasons.LengthS
end

return table.freeze(Seasons)
