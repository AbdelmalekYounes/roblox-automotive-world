--!strict
--[[
    Récompenses de course (lot 0.6, AUD-RACE-01), PURES.

    Crédits = tarif de la discipline × minutes de RÉFÉRENCE du parcours ×
      difficulté × performance × concurrence × type d'épreuve × répétition
      + complément du mode RÉALISTE.
    - Minutes de référence (longueur / vitesse de référence) : rouler
      lentement n'augmente jamais le gain.
    - Performance : place et temps face à la référence (épreuve à plusieurs),
      temps face à la référence (seul, contre-la-montre, rallye, drag), score
      face à la référence (drift).
    - Type : officielle et classée × 1 ; privée éligible × 0,2 (plafond de 3
      par heure) ; entraînement × 0 (jamais de crédit).
    - Mode réaliste : complément brut égal aux coûts ESTIMÉS de l'épreuve
      (énergie + usure probable par km) pour viser un gain NET comparable au
      mode protégé à durée, difficulté et performance équivalentes, sans
      garantie individuelle (coûts réels payés ensuite à l'économie).
    - Anti-abus contextuel : répétitions d'un même parcours dans l'heure
      dégressives sans jamais descendre sous 50 % (répétition honnête) ;
      plafond horaire d'épreuves payées ; rien sans arrivée CONFIRMÉE.

    payout() : mutation unique du profil, transaction « Race:<résultat> »,
    garde d'idempotence durable Racing.Applied : crédits, points classés,
    record personnel, statistiques, historique ET libération de la
    réservation (restauration exacte en mode protégé) — tout ou rien.
]]

local Shared = script.Parent.Parent.Parent.Parent.ReplicatedStorage.Shared
local RaceDefinitions = require(Shared.Racing.RaceDefinitions)
local RaceCourses = require(Shared.Racing.RaceCourses)
local Persistence = script.Parent.Parent.Persistence
local ProfileSchema = require(Persistence.ProfileSchema)
local Wallet = require(script.Parent.Parent.Economy.Wallet)
local VehicleRaceReservation = require(script.Parent.VehicleRaceReservation)
local RankedService = require(script.Parent.RankedService)
local SeasonService = require(script.Parent.SeasonService)

local RaceRewards = {}

-- Gain minimal de score au drift (fraction de la référence) : en dessous, rien.
RaceRewards.DriftMinShare = 0.1

export type Context = {
    ResultId: string,
    EntryId: string?, -- engagement à libérer (nil : aucun, ex. véhicule de flotte)
    RaceId: string,
    CourseId: string,
    Discipline: string,
    Kind: string,
    Mode: string,
    Outcome: string,
    Position: number?,
    Field: number,
    OfficialS: number?,
    Score: number?,
    ParTimeS: number,
    ParScore: number?,
    TotalKm: number,
    Difficulty: number,
    RewardEligible: boolean,
    Conditions: string,
    RecordEligible: boolean, -- conditions normalisées + parcours à records + type à records
    RecordKey: string,
    Ranked: { Ladder: string, Delta: any, Won: boolean }?,
}

export type Quote = {
    Credits: number,
    Base: number,
    RealisticExtra: number,
    Performance: number,
    RepeatFactor: number,
    Capped: boolean,
}

local function repeatFactor(profile: ProfileSchema.Profile, courseId: string, now: number): number
    local recent = profile.Racing.Recent[courseId]
    if recent == nil or now - recent.Since > RaceDefinitions.RepeatWindowS then
        return 1
    end
    local factors = RaceDefinitions.RepeatFactors
    return factors[math.min(recent.Count + 1, #factors)]
end

local function paidLastHour(profile: ProfileSchema.Profile, now: number): number
    local count = 0
    for _, entry in profile.Ledger do
        if entry.Kind == "Race" and now - entry.At < 3600 then
            count += 1
        end
    end
    return count
end

function RaceRewards.performance(ctx: Context): number
    local discipline = RaceDefinitions.discipline(ctx.Discipline) :: RaceDefinitions.Discipline
    if discipline.Ranking == "Score" then
        local share = (ctx.Score or 0) / math.max(ctx.ParScore or 1, 1)
        if share < RaceRewards.DriftMinShare then
            return 0
        end
        return math.clamp(share, 0.3, 1)
    end
    local timeFactor = math.clamp(ctx.ParTimeS / math.max(ctx.OfficialS or math.huge, 1e-3), 0.4, 1)
    if discipline.Start == "Grid" and ctx.Field >= 2 and ctx.Position then
        local placement = 1 - 0.5 * ((ctx.Position :: number) - 1) / (ctx.Field - 1)
        return 0.6 * placement + 0.4 * timeFactor
    end
    return timeFactor
end

function RaceRewards.quote(profile: ProfileSchema.Profile, ctx: Context, now: number): Quote
    local none = { Credits = 0, Base = 0, RealisticExtra = 0, Performance = 0, RepeatFactor = 1, Capped = false }
    local kind = RaceDefinitions.kind(ctx.Kind) :: RaceDefinitions.Kind
    local discipline = RaceDefinitions.discipline(ctx.Discipline) :: RaceDefinitions.Discipline
    if ctx.Outcome ~= "Finished" or kind.RewardFactor <= 0 or not ctx.RewardEligible then
        return none
    end
    local performance = RaceRewards.performance(ctx)
    if performance <= 0 then
        return none
    end
    if paidLastHour(profile, now) >= kind.MaxPaidPerHour then
        none.Capped = true
        return none
    end
    local minutes = math.clamp(ctx.ParTimeS / 60, 0.25, 20)
    local difficulty = 0.85 + 0.15 * math.clamp(ctx.Difficulty, 1, 3)
    local competition = 1 + 0.04 * math.min(math.max(ctx.Field - 1, 0), 7)
    local repeated = repeatFactor(profile, ctx.CourseId, now)
    local base = discipline.RatePerMin * minutes * difficulty * performance * competition * kind.RewardFactor * repeated
    local extra = 0
    if ctx.Mode == "Realistic" then
        extra = (RaceDefinitions.EnergyCostPerKm + discipline.WearCostPerKm)
            * ctx.TotalKm
            * kind.RewardFactor
            * repeated
    end
    return {
        Credits = math.floor(base + extra),
        Base = math.floor(base),
        RealisticExtra = math.floor(extra),
        Performance = performance,
        RepeatFactor = repeated,
        Capped = false,
    }
end

local function prune(racing: ProfileSchema.Racing, now: number)
    local ids: { string } = {}
    for id in racing.Results do
        table.insert(ids, id)
    end
    if #ids > ProfileSchema.MaxRaceResults then
        table.sort(ids, function(a, b)
            local ta, tb = racing.Results[a].At, racing.Results[b].At
            if ta ~= tb then
                return ta < tb
            end
            return a < b
        end)
        for i = 1, #ids - ProfileSchema.MaxRaceResults do
            racing.Results[ids[i]] = nil
        end
    end
    for id, at in racing.Applied do
        if now - at > ProfileSchema.RaceAppliedRetentionS then
            racing.Applied[id] = nil
        end
    end
    for key, recent in racing.Recent do
        if now - recent.Since > RaceDefinitions.RepeatWindowS then
            racing.Recent[key] = nil
        end
    end
end

--[[
    Mutation du résultat d'un participant (une transaction, tout ou rien).
    Rejouée : renvoie le résultat déjà appliqué sans rien modifier.
]]
function RaceRewards.payout(profile: ProfileSchema.Profile, ctx: Context, now: number): (boolean, any)
    local racing = profile.Racing
    if racing.Applied[ctx.ResultId] then
        local previous = racing.Results[ctx.ResultId]
        return true, { Duplicate = true, Credits = if previous then previous.Credits else 0 }
    end
    SeasonService.transition(profile, now)
    local quote = RaceRewards.quote(profile, ctx, now)
    if quote.Credits > 0 then
        local ok, err = Wallet.credit(profile, quote.Credits, "Race", ctx.ResultId, now)
        if not ok then
            return false, err
        end
    end
    -- Points classés (variation calculée sur toute l'épreuve, appliquée ici).
    local rankedDelta: number? = nil
    local rankName: string? = nil
    local pairFactor = 1
    if ctx.Ranked and ctx.Ranked.Delta then
        local applied, factor, rank =
            RankedService.apply(profile, ctx.Ranked.Ladder, ctx.Ranked.Delta, ctx.Ranked.Won, now)
        rankedDelta, rankName, pairFactor = applied, rank.Name, factor
    end
    -- Record personnel (conditions normalisées seulement).
    local record = false
    if ctx.Outcome == "Finished" and ctx.RecordEligible then
        local best = racing.Records[ctx.RecordKey]
        local discipline = RaceDefinitions.discipline(ctx.Discipline) :: RaceDefinitions.Discipline
        if discipline.Ranking == "Score" then
            if best == nil or (ctx.Score or 0) > (best.Score or 0) then
                racing.Records[ctx.RecordKey] = { Score = ctx.Score, At = now, ResultId = ctx.ResultId }
                record = true
            end
        elseif ctx.OfficialS and (best == nil or ctx.OfficialS < (best.TimeS or math.huge)) then
            racing.Records[ctx.RecordKey] = { TimeS = ctx.OfficialS, At = now, ResultId = ctx.ResultId }
            record = true
        end
    end
    -- Répétitions (anti-abus contextuel), statistiques, historique.
    if ctx.Outcome == "Finished" then
        local recent = racing.Recent[ctx.CourseId]
        if recent == nil or now - recent.Since > RaceDefinitions.RepeatWindowS then
            racing.Recent[ctx.CourseId] = { Count = 1, Since = now }
        else
            recent.Count += 1
        end
    end
    local stats = racing.Stats
    stats.Started = (stats.Started or 0) + 1
    local statKey = if ctx.Outcome == "Finished"
        then "Finished"
        elseif ctx.Outcome == "Unconfirmed" then "Unconfirmed"
        elseif ctx.Outcome == "Disconnected" then "Disconnected"
        else "Abandoned"
    stats[statKey] = (stats[statKey] or 0) + 1
    racing.Results[ctx.ResultId] = {
        RaceId = ctx.RaceId,
        CourseId = ctx.CourseId,
        Discipline = ctx.Discipline,
        Kind = ctx.Kind,
        Mode = ctx.Mode,
        Outcome = ctx.Outcome,
        Position = ctx.Position,
        Field = ctx.Field,
        TimeS = ctx.OfficialS,
        Score = ctx.Score,
        Credits = quote.Credits,
        RankedDelta = rankedDelta,
        Conditions = ctx.Conditions,
        At = now,
    }
    racing.Applied[ctx.ResultId] = now
    -- Fin effective de l'engagement : libération (et restauration en mode protégé).
    local released: any = nil
    if ctx.EntryId then
        local _, info = VehicleRaceReservation.release(profile, ctx.EntryId :: string, now)
        released = info
    end
    prune(racing, now)
    return true,
        {
            Credits = quote.Credits,
            Base = quote.Base,
            RealisticExtra = quote.RealisticExtra,
            Capped = quote.Capped,
            RepeatFactor = quote.RepeatFactor,
            RankedDelta = rankedDelta,
            Rank = rankName,
            PairFactor = pairFactor,
            Record = record,
            Restored = if released then released.Restored else nil,
        }
end

-- Clé de record d'un parcours (version et conditions).
function RaceRewards.recordKey(courseId: string): string
    local course = RaceCourses.get(courseId)
    return if course then RaceCourses.recordKey(course) else courseId
end

return table.freeze(RaceRewards)
