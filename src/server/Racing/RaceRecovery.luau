--!strict
--[[
    Interruption, reconnexion et récupération des engagements (lot 0.6,
    AUD-RECON-01, SCN-11, SCN-12), PUR.

    Ce qui survit à une déconnexion ou à l'arrêt d'un serveur est DURABLE dans
    le profil : identité, course, engagement, véhicule, réservation, mode et
    état initial (mode protégé), résultats déjà appliqués. Le reste (progression
    en cours) vit dans la session de course du serveur qui l'organise.

    - Reconnexion au même serveur pendant la fenêtre (~90 s) : la session de
      course reprend le participant (RaceSession.reconnect) ; la réservation
      n'a jamais été levée.
    - Résultat publié par le serveur de course (enregistrement Race_<id>) mais
      non appliqué au profil (joueur parti, profil verrouillé ailleurs) : le
      serveur qui détient le profil l'applique (pendingResult) — une seule
      fois (Racing.Applied).
    - Engagement échu sans résultat (serveur de course disparu) : issue
      cohérente « Interrupted » : aucune récompense, aucun point, réservation
      libérée, état initial restauré EXACTEMENT en mode protégé (ni réparation
      gratuite, ni perte de dégâts antérieurs) ; en mode réaliste l'état
      mesuré déjà réconcilié reste. Jamais de véhicule supplémentaire : le
      véhicule ne change pas de propriétaire et n'est jamais dupliqué.
]]

local Persistence = script.Parent.Parent.Persistence
local ProfileSchema = require(Persistence.ProfileSchema)
local VehicleRaceReservation = require(script.Parent.VehicleRaceReservation)

local RaceRecovery = {}

-- Identifiant du résultat d'un participant (le même que celui de la course).
function RaceRecovery.resultId(raceId: string, userId: number): string
    return raceId .. ":" .. tostring(userId)
end

--[[
    Résout un engagement échu. Utilisée au chargement (normalisation) et par
    la réconciliation périodique. Renvoie vrai si le profil a changé.
]]
function RaceRecovery.recover(profile: ProfileSchema.Profile, now: number): boolean
    local racing = profile.Racing
    if racing == nil then
        return false
    end
    local active = racing.Active
    if active == nil or now < active.ExpiresAt then
        return false
    end
    RaceRecovery.interrupt(profile, now)
    return true
end

-- Issue « Interrupted » d'un engagement (sans condition d'échéance).
function RaceRecovery.interrupt(profile: ProfileSchema.Profile, now: number): (boolean, any)
    local racing = profile.Racing
    local active = racing.Active
    if active == nil then
        return true, { AlreadyReleased = true }
    end
    local resultId = RaceRecovery.resultId(active.RaceId, profile.UserId)
    if racing.Applied[resultId] == nil then
        racing.Results[resultId] = {
            RaceId = active.RaceId,
            CourseId = active.CourseId,
            Discipline = active.Discipline,
            Kind = active.Kind,
            Mode = active.Mode,
            Outcome = "Interrupted",
            Position = nil,
            Field = 0,
            TimeS = nil,
            Score = nil,
            Credits = 0,
            RankedDelta = nil,
            Conditions = "",
            At = now,
        }
        racing.Applied[resultId] = now
        racing.Stats.Disconnected = (racing.Stats.Disconnected or 0) + 1
    end
    return VehicleRaceReservation.release(profile, active.EntryId, now)
end

--[[
    Résultat publié pour ce joueur et non encore appliqué : renvoie le
    contexte de paiement enregistré par le serveur de course (ou nil).
]]
function RaceRecovery.pendingResult(profile: ProfileSchema.Profile, record: any): any?
    local active = profile.Racing.Active
    if active == nil or type(record) ~= "table" or record.RaceId ~= active.RaceId then
        return nil
    end
    local results = record.Results
    local context = if type(results) == "table" then results[tostring(profile.UserId)] else nil
    if type(context) ~= "table" or profile.Racing.Applied[context.ResultId] then
        return nil
    end
    return context
end

return table.freeze(RaceRecovery)
