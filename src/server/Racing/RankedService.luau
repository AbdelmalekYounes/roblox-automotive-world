--!strict
--[[
    Classement compétitif (lot 0.6, §6.3), PUR. Points et rangs SÉPARÉS de la
    réputation générale (Racing.Ranked, jamais Reputation).

    Échelle « Race » (sprint, circuit) : Elo multijoueur. Chaque paire de
    participants classables compte comme une manche : gain attendu
    E = 1 / (1 + 10^((Rb − Ra) / 400)), résultat 1 (devant), 0,5 (égalité entre
    non-arrivés), 0 (derrière) ; variation = K × Σ(résultat − E) / (n − 1).
    - Classables : arrivées CONFIRMÉES, puis abandons, délais dépassés et
      disqualifications (derrière tous les arrivés).
    - Non classés (aucune variation) : arrivée non confirmée (à réconcilier),
      déconnexion (aucune sanction d'une anomalie réseau), non-partants.
    - Au moins deux classables, sinon aucune variation.

    Échelle « Drift » : logique propre, fondée sur la mesure de performance
    et non sur l'adversaire : performance = clamp(score / référence − 0,5, 0, 1)
    comparée à l'attendu du classement actuel face au niveau de référence
    du parcours (1 200 points).

    Anti-arrangement : les GAINS face aux mêmes adversaires, répétés dans les
    24 h, sont progressivement réduits (×1 jusqu'à 3 manches, ×0,5 jusqu'à 6,
    ×0,25 au-delà) et signalés « à examiner » ; les pertes ne sont pas
    modifiées et aucune sanction n'est automatique (SCN-14 : une simple
    répétition honnête ne doit pas être pénalisée — le gain reste positif).
]]

local Shared = script.Parent.Parent.Parent.Parent.ReplicatedStorage.Shared
local Seasons = require(Shared.Racing.Seasons)
local Persistence = script.Parent.Parent.Persistence
local ProfileSchema = require(Persistence.ProfileSchema)
local RaceScoring = require(script.Parent.RaceScoring)

local RankedService = {}

RankedService.K = 32
RankedService.DriftParRating = 1200
RankedService.PairWindowS = 24 * 3600
RankedService.PairFactors = table.freeze({ { Max = 3, Factor = 1 }, { Max = 6, Factor = 0.5 } })
RankedService.PairFloor = 0.25

local RANKABLE: { [string]: boolean } = {
    Finished = true,
    Abandoned = true,
    TimedOut = true,
    Disqualified = true,
}

export type Delta = { Delta: number, Opponents: { number } }

--[[
    Variations brutes d'une épreuve classée. `ratings` : points actuels de
    chaque participant dans l'échelle. Renvoie { [UserId] = Delta }.
]]
function RankedService.deltas(
    classification: RaceScoring.Classification,
    ladder: string,
    ratings: { [number]: number },
    parScore: number?
): { [number]: Delta }
    local result: { [number]: Delta } = {}
    local rankable: { RaceScoring.Entry } = {}
    for _, entry in classification.Entries do
        if RANKABLE[entry.Outcome] then
            table.insert(rankable, entry)
        end
    end
    if #rankable < 2 then
        return result
    end
    if ladder == "Drift" then
        for _, entry in rankable do
            local rating = ratings[entry.UserId] or Seasons.StartPoints
            local score = if entry.Outcome == "Finished" then entry.Score or 0 else 0
            local performance = math.clamp(score / math.max(parScore or 1, 1) - 0.5, 0, 1)
            local expected = 1 / (1 + 10 ^ ((RankedService.DriftParRating - rating) / 400))
            local opponents = {}
            for _, other in rankable do
                if other.UserId ~= entry.UserId then
                    table.insert(opponents, other.UserId)
                end
            end
            result[entry.UserId] = {
                Delta = math.floor(RankedService.K * (performance - expected) + 0.5),
                Opponents = opponents,
            }
        end
        return result
    end
    -- Elo multijoueur : place (arrivés) puis non-arrivés à égalité.
    local function placeOf(entry: RaceScoring.Entry): number
        return entry.Position or math.huge
    end
    for _, a in rankable do
        local ra = ratings[a.UserId] or Seasons.StartPoints
        local sum = 0
        local opponents = {}
        for _, b in rankable do
            if b.UserId ~= a.UserId then
                local rb = ratings[b.UserId] or Seasons.StartPoints
                local expected = 1 / (1 + 10 ^ ((rb - ra) / 400))
                local pa, pb = placeOf(a), placeOf(b)
                local actual = if pa < pb then 1 elseif pa > pb then 0 else 0.5
                sum += actual - expected
                table.insert(opponents, b.UserId)
            end
        end
        result[a.UserId] = {
            Delta = math.floor(RankedService.K * sum / (#rankable - 1) + 0.5),
            Opponents = opponents,
        }
    end
    return result
end

local function ladderOf(profile: ProfileSchema.Profile, ladder: string): ProfileSchema.Ladder
    local ranked = profile.Racing.Ranked
    local entry = ranked.Ladders[ladder]
    if entry == nil then
        entry = { Points = Seasons.StartPoints, Played = 0, Wins = 0, Peak = Seasons.StartPoints }
        ranked.Ladders[ladder] = entry
    end
    return entry
end
RankedService.ladderOf = ladderOf

function RankedService.points(profile: ProfileSchema.Profile, ladder: string): number
    local entry = profile.Racing.Ranked.Ladders[ladder]
    return if entry then entry.Points else Seasons.StartPoints
end

--[[
    Applique une variation au profil (dans la mutation du résultat).
    Renvoie (variation appliquée, facteur anti-arrangement, rang).
]]
function RankedService.apply(
    profile: ProfileSchema.Profile,
    ladder: string,
    delta: Delta,
    won: boolean,
    now: number
): (number, number, Seasons.Rank)
    local ranked = profile.Racing.Ranked
    local entry = ladderOf(profile, ladder)
    -- Mémoire des adversaires (fenêtre glissante, entrées échues retirées).
    for key, pair in ranked.Pairs do
        if now - pair.Since > RankedService.PairWindowS then
            ranked.Pairs[key] = nil
        end
    end
    local factorSum, count = 0, 0
    for _, opponent in delta.Opponents do
        local key = ladder .. ":" .. tostring(opponent)
        local pair = ranked.Pairs[key]
        if pair == nil then
            pair = { Count = 0, Since = now }
            ranked.Pairs[key] = pair
        end
        pair.Count += 1
        local factor = RankedService.PairFloor
        for _, step in RankedService.PairFactors do
            if pair.Count <= step.Max then
                factor = step.Factor
                break
            end
        end
        factorSum += factor
        count += 1
    end
    local factor = if count > 0 then factorSum / count else 1
    local applied = delta.Delta
    if applied > 0 then
        applied = math.max(1, math.floor(applied * factor + 0.5))
    end
    entry.Points = math.max(0, entry.Points + applied)
    entry.Played += 1
    if won then
        entry.Wins += 1
    end
    entry.Peak = math.max(entry.Peak, entry.Points)
    return applied, factor, Seasons.rank(entry.Points)
end

return table.freeze(RankedService)
