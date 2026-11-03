--!strict
--[[
    Rémunération et réputation des missions (lot 0.5), PURES et réglables.

    crédits = RatePerMin × minutes ESTIMÉES × difficulté × (1 + risque)
              × (0,5 + 0,5 × qualité) × premium × facteur de répétition
    - minutes ESTIMÉES par le serveur à la génération (distance, arrêts),
      jamais le temps réel : aller lentement ne rapporte pas plus ;
    - facteur de répétition : un même itinéraire ou parcours refait dans
      l'heure rapporte de moins en moins (1 ; 0,6 ; 0,35 ; 0,2 …) ;
    - plafond horaire de missions payées par joueur.
    La réputation suit la même logique (pas de réputation illimitée pour une
    action triviale répétée). Le versement est une transaction d'identifiant
    « Mission:<id> » : jamais payée deux fois.
]]

local Persistence = script.Parent.Parent.Persistence
local ProfileSchema = require(Persistence.ProfileSchema)
local Wallet = require(script.Parent.Wallet)

local Shared = script.Parent.Parent.Parent.Parent.ReplicatedStorage.Shared
local Jobs = require(Shared.Economy.Jobs)

local RewardModel = {}

RewardModel.DifficultyFactor = table.freeze({ 1.0, 1.25, 1.5 })
RewardModel.PremiumFactor = 1.3
RewardModel.RepeatWindowS = 3600
RewardModel.RepeatFactors = table.freeze({ 1, 0.6, 0.35, 0.2, 0.1 })
RewardModel.MaxPaidPerHour = 30
RewardModel.ReputationPerMinute = 10

export type Quote = { Credits: number, Reputation: number, RepeatFactor: number }

function RewardModel.repeatFactor(profile: ProfileSchema.Profile, routeKey: string, now: number): number
    local recent = profile.Reputation.Recent[routeKey]
    if recent == nil or now - recent.Since > RewardModel.RepeatWindowS then
        return 1
    end
    return RewardModel.RepeatFactors[math.min(recent.Count + 1, #RewardModel.RepeatFactors)]
end

function RewardModel.quote(profile: ProfileSchema.Profile, mission: any, quality: number, now: number): Quote
    local job = Jobs.get(mission.Job)
    if job == nil then
        return { Credits = 0, Reputation = 0, RepeatFactor = 0 }
    end
    local minutes = math.max(mission.EstimatedS, 30) / 60
    local difficulty = RewardModel.DifficultyFactor[math.clamp(mission.Difficulty, 1, 3)]
    local premium = if mission.Premium and quality >= 0.8 then RewardModel.PremiumFactor else 1
    local repeated = RewardModel.repeatFactor(profile, mission.RouteKey, now)
    local credits = job.RatePerMin
        * minutes
        * difficulty
        * (1 + job.Risk)
        * (0.5 + 0.5 * math.clamp(quality, 0, 1))
        * premium
        * repeated
    local reputation = RewardModel.ReputationPerMinute * minutes * difficulty * quality * repeated
    return { Credits = math.floor(credits), Reputation = math.floor(reputation), RepeatFactor = repeated }
end

-- Missions payées dans l'heure (tous métiers) : plafond anti-abus.
local function paidLastHour(profile: ProfileSchema.Profile, now: number): number
    local count = 0
    for _, entry in profile.Ledger do
        if entry.Kind == "Mission" and now - entry.At < 3600 then
            count += 1
        end
    end
    return count
end

--[[
    Versement d'une mission réussie (mutation d'un profil, transaction
    « Mission:<id> »). Met à jour gains, réputation, progression du métier et
    anti-répétition. Échec de mission : progression « Failed » seulement.
]]
function RewardModel.payout(
    profile: ProfileSchema.Profile,
    mission: any,
    completed: boolean,
    quality: number,
    now: number
): (boolean, any)
    local jobProgress = profile.Jobs[mission.Job]
    if jobProgress == nil then
        jobProgress = { Completed = 0, Failed = 0, Xp = 0, Best = 0 }
        profile.Jobs[mission.Job] = jobProgress
    end
    if not completed then
        jobProgress.Failed += 1
        return true, { Credits = 0, Reputation = 0 }
    end
    if paidLastHour(profile, now) >= RewardModel.MaxPaidPerHour then
        jobProgress.Completed += 1
        return true, { Credits = 0, Reputation = 0, Capped = true }
    end
    local quote = RewardModel.quote(profile, mission, quality, now)
    if quote.Credits > 0 then
        local ok, err = Wallet.credit(profile, quote.Credits, "Mission", mission.Id, now)
        if not ok then
            return false, err
        end
    end
    profile.Reputation.Points += quote.Reputation
    local recent = profile.Reputation.Recent[mission.RouteKey]
    if recent == nil or now - recent.Since > RewardModel.RepeatWindowS then
        profile.Reputation.Recent[mission.RouteKey] = { Count = 1, Since = now }
    else
        recent.Count += 1
    end
    -- Bornage de la mémoire anti-répétition (entrées échues retirées).
    for key, entry in profile.Reputation.Recent do
        if now - entry.Since > RewardModel.RepeatWindowS then
            profile.Reputation.Recent[key] = nil
        end
    end
    jobProgress.Completed += 1
    jobProgress.Xp += quote.Reputation
    jobProgress.Best = math.max(jobProgress.Best, quality)
    return true, { Credits = quote.Credits, Reputation = quote.Reputation, RepeatFactor = quote.RepeatFactor }
end

return table.freeze(RewardModel)
