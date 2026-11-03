--!strict
--[[
    Saisons classées de huit semaines (lot 0.6, §6.3, SCN-30), PUR.

    transition(profile, now) — appelée au chargement du profil et avant tout
    résultat classé : si la saison du profil est passée, pour chaque échelle :
    - archivage (saison, points, rang final, épreuves jouées) dans l'historique
      personnel (borné) ;
    - récompense de fin de saison configurable selon le rang final, versée UNE
      fois (marque « <saison>:<échelle> », transaction « Season:… ») si le
      joueur a disputé assez d'épreuves classées ;
    - réinitialisation douce : les points se rapprochent de moitié du point de
      départ ; compteurs de saison remis à zéro.
    Les tableaux de classement de saison sont indexés par numéro de saison
    (Racing/RacePersistence) : une nouvelle saison repart d'un tableau vide.
]]

local Shared = script.Parent.Parent.Parent.Parent.ReplicatedStorage.Shared
local Seasons = require(Shared.Racing.Seasons)
local RaceDefinitions = require(Shared.Racing.RaceDefinitions)
local Persistence = script.Parent.Parent.Persistence
local ProfileSchema = require(Persistence.ProfileSchema)
local Wallet = require(script.Parent.Parent.Economy.Wallet)

local SeasonService = {}

export type Archived = { Season: number, Ladder: string, Points: number, Rank: string, Reward: number }

-- Renvoie (profil modifié, éléments archivés).
function SeasonService.transition(profile: ProfileSchema.Profile, now: number): (boolean, { Archived })
    local ranked = profile.Racing.Ranked
    local current = Seasons.index(now)
    local archived: { Archived } = {}
    if ranked.Season == current then
        return false, archived
    end
    if ranked.Season == 0 or ranked.Season > current then
        -- Première participation (ou horloge antérieure) : rien à clore.
        ranked.Season = current
        return true, archived
    end
    local old = ranked.Season
    local rewards = RaceDefinitions.SeasonRewards
    for _, ladderName in Seasons.Ladders do
        local ladder = ranked.Ladders[ladderName]
        if ladder == nil then
            continue
        end
        local rank = Seasons.rank(ladder.Points)
        local reward = 0
        local mark = string.format("%d:%s", old, ladderName)
        if ladder.Played >= rewards.MinRankedRaces and ranked.Rewarded[mark] == nil then
            reward = rewards.ByRank[rank.Index] or 0
            if reward > 0 then
                local ok = Wallet.credit(profile, reward, "Season", "Season:" .. mark, now)
                if not ok then
                    reward = 0
                end
            end
            ranked.Rewarded[mark] = now
        end
        table.insert(ranked.History, {
            Season = old,
            Ladder = ladderName,
            Points = ladder.Points,
            Rank = rank.Name,
            Played = ladder.Played,
        })
        table.insert(
            archived,
            { Season = old, Ladder = ladderName, Points = ladder.Points, Rank = rank.Name, Reward = reward }
        )
        ladder.Points =
            math.floor(Seasons.StartPoints + (ladder.Points - Seasons.StartPoints) * Seasons.SoftReset + 0.5)
        ladder.Played = 0
        ladder.Wins = 0
        ladder.Peak = ladder.Points
    end
    while #ranked.History > ProfileSchema.MaxSeasonHistory do
        table.remove(ranked.History, 1)
    end
    ranked.Season = current
    return true, archived
end

return table.freeze(SeasonService)
