--!strict
--[[
    Chronométrage et classement (lot 0.6), PURS.

    Temps officiel = instant d'arrivée − instant officiel de départ (horloge
    serveur) + pénalités. Drag : il inclut le temps de réaction (départ au feu
    vert) ; le temps écoulé seul (ET) et la vitesse d'arrivée sont aussi
    publiés. Drift : classement au score.

    Classement : arrivées CONFIRMÉES seulement (RaceValidator), par temps
    officiel croissant ou score décroissant ; à égalité, l'arrivée la plus
    tôt, puis l'identifiant. Les arrivées non confirmées n'ont pas de place
    (à réconcilier) ; les non-arrivés sont listés ensuite selon leur distance
    validée, sans place.
]]

local RaceRules = require(script.Parent.RaceRules)
local RaceValidator = require(script.Parent.RaceValidator)

local RaceScoring = {}

export type Outcome =
    "Finished"
    | "Unconfirmed"
    | "Abandoned"
    | "Disconnected"
    | "Disqualified"
    | "TimedOut"
    | "DidNotStart"

export type Entry = {
    UserId: number,
    VehicleId: string,
    Outcome: Outcome,
    Reason: string?,
    Position: number?,
    OfficialS: number?,
    ElapsedS: number?,
    PenaltyS: number,
    BestLapS: number?,
    LapTimes: { number },
    ReactionS: number?,
    TrapSpeedKmh: number?,
    Score: number?,
    ProgressM: number,
    FinishT: number?,
    Reasons: { string },
}

export type Classification = {
    Entries: { Entry },
    Field: number, -- participants ayant pris le départ
    Confirmed: number, -- arrivées confirmées
    BestLapS: number?,
    BestLapUserId: number?,
}

local function outcomeOf(progress: RaceRules.Progress, verdict: RaceValidator.Verdict): Outcome
    local status = progress.Status
    if status == "Finished" then
        return if verdict.Confirmed then "Finished" else "Unconfirmed"
    elseif status == "Waiting" or status == "Racing" then
        return "TimedOut"
    end
    return status :: any
end

function RaceScoring.entry(progress: RaceRules.Progress, verdict: RaceValidator.Verdict): Entry
    return {
        UserId = progress.UserId,
        VehicleId = progress.VehicleId,
        Outcome = outcomeOf(progress, verdict),
        Reason = progress.Reason,
        Position = nil,
        OfficialS = progress.OfficialS,
        ElapsedS = progress.ElapsedS,
        PenaltyS = progress.PenaltyS,
        BestLapS = progress.BestLapS,
        LapTimes = table.clone(progress.LapTimes),
        ReactionS = progress.ReactionS,
        TrapSpeedKmh = progress.TrapSpeedKmh,
        Score = progress.Score,
        ProgressM = progress.ProgressM,
        FinishT = progress.FinishT,
        Reasons = verdict.Reasons,
    }
end

--[[
    Classe des entrées. `ranking` : "Time" ou "Score".
]]
function RaceScoring.classify(entries: { Entry }, ranking: "Time" | "Score"): Classification
    local finished: { Entry } = {}
    local unconfirmed: { Entry } = {}
    local others: { Entry } = {}
    local field = 0
    local bestLap: number?, bestLapUser: number? = nil, nil
    for _, entry in entries do
        if entry.Outcome ~= "DidNotStart" then
            field += 1
        end
        if entry.Outcome == "Finished" then
            table.insert(finished, entry)
            if entry.BestLapS and (bestLap == nil or entry.BestLapS < bestLap) then
                bestLap, bestLapUser = entry.BestLapS, entry.UserId
            end
        elseif entry.Outcome == "Unconfirmed" then
            table.insert(unconfirmed, entry)
        else
            table.insert(others, entry)
        end
    end
    table.sort(finished, function(a, b)
        if ranking == "Score" then
            local sa, sb = a.Score or 0, b.Score or 0
            if sa ~= sb then
                return sa > sb
            end
        else
            local ta, tb = a.OfficialS or math.huge, b.OfficialS or math.huge
            if ta ~= tb then
                return ta < tb
            end
        end
        local fa, fb = a.FinishT or math.huge, b.FinishT or math.huge
        if fa ~= fb then
            return fa < fb
        end
        return a.UserId < b.UserId
    end)
    for index, entry in finished do
        entry.Position = index
    end
    table.sort(others, function(a, b)
        if a.ProgressM ~= b.ProgressM then
            return a.ProgressM > b.ProgressM
        end
        return a.UserId < b.UserId
    end)
    local ordered: { Entry } = {}
    for _, list in { finished, unconfirmed, others } do
        for _, entry in list do
            table.insert(ordered, entry)
        end
    end
    return {
        Entries = ordered,
        Field = field,
        Confirmed = #finished,
        BestLapS = bestLap,
        BestLapUserId = bestLapUser,
    }
end

-- Temps lisible (m:ss.mmm).
function RaceScoring.format(seconds: number?): string
    if seconds == nil then
        return "—"
    end
    local minutes = math.floor(seconds / 60)
    local rest = seconds - minutes * 60
    return string.format("%d:%06.3f", minutes, rest)
end

return table.freeze(RaceScoring)
