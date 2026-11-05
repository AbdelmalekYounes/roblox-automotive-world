--!strict
--[[
    Cycle de vie d'une épreuve (lot 0.6), PUR (horloge injectée : instants du
    serveur, Workspace:GetServerTimeNow).

      Open ──(minimum atteint et tous prêts, ou délai)──▶ Countdown ──StartT──▶ Running ──▶ Finished
        └──(délai d'inscription sans minimum)──▶ Cancelled

    - Open : inscriptions (une place par joueur, mode autorisé), désinscription,
      confirmation de disponibilité (« prêt »). Inscriptions FERMÉES dès le
      verrouillage.
    - Verrouillage : places attribuées (grille, couloirs de drag, ordre des
      départs individuels), instants officiels de départ fixés par le serveur.
    - Running : échantillons serveur (RaceRules), abandons, déconnexions
      (fenêtre de reconnexion ~90 s, AUD-RECON-01), fin quand tous ont
      terminé, après le délai d'arrivée suivant le premier, ou au délai maximal.
]]

local Shared = script.Parent.Parent.Parent.Parent.ReplicatedStorage.Shared
local RaceDefinitions = require(Shared.Racing.RaceDefinitions)
local RaceCourse = require(script.Parent.RaceCourse)
local RaceRules = require(script.Parent.RaceRules)
local RaceScoring = require(script.Parent.RaceScoring)
local RaceValidator = require(script.Parent.RaceValidator)

local RaceSession = {}

export type State = "Open" | "Countdown" | "Running" | "Finished" | "Cancelled"

export type Participant = {
    UserId: number,
    VehicleId: string,
    ModelId: string,
    Mode: RaceDefinitions.ModeId,
    Rating: number,
    MaxPlausibleKmh: number,
    Ready: boolean,
    JoinedAt: number,
    Progress: RaceRules.Progress,
    ReconnectDeadline: number?,
}

export type Params = {
    Id: string,
    Built: RaceCourse.Built,
    Kind: RaceDefinitions.KindId,
    CreatedAt: number,
    OrganizerUserId: number?,
    Laps: number?, -- réglage d'organisateur (salon privé, entraînement)
    MaxParticipants: number?,
    Modes: { RaceDefinitions.ModeId }?, -- modes autorisés par l'organisateur
    RewardEligible: boolean?, -- salon privé déclaré éligible (faibles récompenses)
    MatchId: string?,
    -- Places réservées (match classé, salon privé sur invitation) : seuls ces joueurs.
    Invited: { number }?,
}

export type Session = {
    Id: string,
    Built: RaceCourse.Built,
    Discipline: RaceDefinitions.Discipline,
    Kind: RaceDefinitions.Kind,
    State: State,
    CreatedAt: number,
    LockedAt: number?,
    StartT: number?, -- premier départ officiel
    FirstFinishT: number?,
    EndedAt: number?,
    OrganizerUserId: number?,
    Laps: number,
    MaxParticipants: number,
    MinParticipants: number,
    Modes: { RaceDefinitions.ModeId },
    RewardEligible: boolean,
    Normalized: boolean,
    Conditions: string,
    MatchId: string?,
    Invited: { [number]: boolean }?,
    Participants: { [number]: Participant },
    Order: { number },
}

function RaceSession.new(params: Params): Session
    local built = params.Built
    local course = built.Course
    local discipline = RaceDefinitions.discipline(course.Discipline) :: RaceDefinitions.Discipline
    local kind = RaceDefinitions.kind(params.Kind) :: RaceDefinitions.Kind
    local limits = RaceDefinitions.OrganizerLimits
    local laps = built.Laps
    local maxParticipants = course.MaxParticipants
    if kind.OrganizerSettings then
        if built.Closed and params.Laps then
            laps = math.clamp(math.floor(params.Laps), limits.Laps.Min, limits.Laps.Max)
        end
        if params.MaxParticipants then
            maxParticipants = math.clamp(math.floor(params.MaxParticipants), 1, course.MaxParticipants)
        end
    end
    local modes: { RaceDefinitions.ModeId } = { "Protected", "Realistic" }
    if kind.Id == "Training" then
        modes = { "Protected" } -- entraînement : aucune conséquence durable
    elseif kind.OrganizerSettings and params.Modes and #params.Modes > 0 then
        modes = {}
        for _, mode in params.Modes do
            if RaceDefinitions.validMode(mode) and not table.find(modes, mode) then
                table.insert(modes, mode)
            end
        end
    end
    local normalized = RaceDefinitions.normalized(kind, built.RecordEligible)
    local invited: { [number]: boolean }? = nil
    if params.Invited then
        invited = {}
        for _, userId in params.Invited do
            (invited :: { [number]: boolean })[userId] = true
        end
    end
    local session: Session = {
        Id = params.Id,
        Built = if laps ~= built.Laps then RaceSession.withLaps(built, laps) else built,
        Discipline = discipline,
        Kind = kind,
        State = "Open",
        CreatedAt = params.CreatedAt,
        LockedAt = nil,
        StartT = nil,
        FirstFinishT = nil,
        EndedAt = nil,
        OrganizerUserId = params.OrganizerUserId,
        Laps = laps,
        MaxParticipants = maxParticipants,
        MinParticipants = if kind.Ranked then math.max(2, course.MinParticipants) else course.MinParticipants,
        Modes = modes,
        RewardEligible = kind.Id ~= "Private" or params.RewardEligible == true,
        Normalized = normalized,
        Conditions = if normalized then course.Conditions else "Dynamique",
        MatchId = params.MatchId,
        Invited = invited,
        Participants = {},
        Order = {},
    }
    return session
end

-- Copie d'un parcours construit avec un autre nombre de tours (organisateur).
function RaceSession.withLaps(built: RaceCourse.Built, laps: number): RaceCourse.Built
    local copy = table.clone(built)
    copy.Laps = laps
    copy.TotalM = built.LengthM * laps
    copy.ParTimeS = copy.TotalM / (built.Course.RefSpeedKmh / 3.6) + 4
    return copy
end

function RaceSession.count(session: Session): number
    return #session.Order
end

export type Entry = {
    UserId: number,
    VehicleId: string,
    ModelId: string,
    Mode: any,
    Rating: number?,
    MaxPlausibleKmh: number,
}

function RaceSession.register(session: Session, entry: Entry, now: number): (boolean, string?)
    if session.State ~= "Open" then
        return false, "RaceRegistrationClosed"
    end
    if session.Participants[entry.UserId] then
        return false, "RaceAlreadyRegistered"
    end
    if #session.Order >= session.MaxParticipants then
        return false, "RaceFull"
    end
    if session.Invited and not (session.Invited :: { [number]: boolean })[entry.UserId] then
        return false, "RaceNotInvited"
    end
    local mode = if session.Kind.Id == "Training" then "Protected" else entry.Mode
    if not table.find(session.Modes, mode) then
        return false, "RaceModeNotAllowed"
    end
    for _, other in session.Participants do
        if other.VehicleId == entry.VehicleId then
            return false, "RaceVehicleAlreadyEngaged"
        end
    end
    local slot = #session.Order + 1
    session.Participants[entry.UserId] = {
        UserId = entry.UserId,
        VehicleId = entry.VehicleId,
        ModelId = entry.ModelId,
        Mode = mode,
        Rating = entry.Rating or 1000,
        MaxPlausibleKmh = entry.MaxPlausibleKmh,
        Ready = false,
        JoinedAt = now,
        Progress = RaceRules.newProgress(entry.UserId, entry.VehicleId, slot),
        ReconnectDeadline = nil,
    }
    table.insert(session.Order, entry.UserId)
    return true, nil
end

function RaceSession.unregister(session: Session, userId: number): (boolean, string?)
    if session.Participants[userId] == nil then
        return false, "RaceNotRegistered"
    end
    if session.State ~= "Open" then
        return false, "RaceAlreadyLocked"
    end
    session.Participants[userId] = nil
    local index = table.find(session.Order, userId)
    if index then
        table.remove(session.Order, index)
    end
    return true, nil
end

function RaceSession.setReady(session: Session, userId: number, ready: boolean): (boolean, string?)
    local participant = session.Participants[userId]
    if participant == nil then
        return false, "RaceNotRegistered"
    end
    if session.State ~= "Open" then
        return false, "RaceAlreadyLocked"
    end
    participant.Ready = ready
    return true, nil
end

-- Le verrouillage peut-il avoir lieu ?
function RaceSession.readyToLock(session: Session, now: number): boolean
    if session.State ~= "Open" or #session.Order < session.MinParticipants then
        return false
    end
    local allReady = true
    local firstJoin = math.huge
    for _, participant in session.Participants do
        allReady = allReady and participant.Ready
        firstJoin = math.min(firstJoin, participant.JoinedAt)
    end
    return allReady or now - firstJoin >= RaceDefinitions.Timing.AutoStartS
end

--[[
    Verrouillage : places et instants officiels de départ. Ordre de grille :
    inscription (classée : meilleur classement devant). Renvoie la liste des
    (UserId, place, instant de départ).
]]
function RaceSession.lock(session: Session, now: number): { { UserId: number, Slot: number, StartT: number } }
    assert(session.State == "Open", "épreuve déjà verrouillée")
    local timing = RaceDefinitions.Timing
    local order = table.clone(session.Order)
    if session.Kind.Ranked then
        table.sort(order, function(a, b)
            local ra, rb = session.Participants[a].Rating, session.Participants[b].Rating
            if ra ~= rb then
                return ra > rb
            end
            return a < b
        end)
    end
    local built = session.Built
    local startKind = session.Discipline.Start
    local plan = {}
    local first = math.huge
    for index, userId in order do
        local participant = session.Participants[userId]
        local startT: number
        local anchor: { X: number, Z: number }?
        if startKind == "Grid" then
            startT = now + timing.GridS + timing.CountdownS
            anchor = built.Grid[index]
        elseif startKind == "Lights" then
            startT = now + timing.StagingS
            anchor = built.Grid[index]
        elseif startKind == "Individual" then
            startT = now + timing.GridS + timing.CountdownS + (index - 1) * timing.IndividualIntervalS
            anchor = built.Start
        else
            startT = now + timing.CountdownS * 2
            anchor = nil
        end
        participant.Progress.Slot = index
        if anchor then
            RaceRules.arm(participant.Progress, startT, anchor)
        else
            participant.Progress.StartT = startT
        end
        first = math.min(first, startT)
        table.insert(plan, { UserId = userId, Slot = index, StartT = startT })
    end
    session.State = "Countdown"
    session.LockedAt = now
    session.StartT = first
    return plan
end

function RaceSession.cancel(session: Session, now: number)
    session.State = "Cancelled"
    session.EndedAt = now
end

function RaceSession.observe(session: Session, userId: number, sample: RaceRules.Sample): { string }
    local participant = session.Participants[userId]
    if participant == nil or (session.State ~= "Countdown" and session.State ~= "Running") then
        return {}
    end
    local events = RaceRules.observe(participant.Progress, session.Built, session.Discipline, sample)
    if table.find(events, "Finished") and session.FirstFinishT == nil then
        session.FirstFinishT = participant.Progress.FinishT
    end
    return events
end

-- Déconnexion : avant le verrouillage, désinscription ; ensuite, fenêtre de reconnexion.
function RaceSession.disconnect(session: Session, userId: number, now: number): string
    local participant = session.Participants[userId]
    if participant == nil then
        return "NotRegistered"
    end
    if session.State == "Open" then
        RaceSession.unregister(session, userId)
        return "Unregistered"
    end
    local progress = participant.Progress
    if progress.Status == "Waiting" or progress.Status == "Racing" then
        progress.Status = "Disconnected"
        participant.ReconnectDeadline = now + RaceDefinitions.Timing.ReconnectWindowS
        return "Window"
    end
    return "AlreadyClosed"
end

--[[
    Reconnexion à la même épreuve : possible pendant la fenêtre, tant que
    l'épreuve court et que la reprise est équitable (le chronomètre n'a pas
    été arrêté ; contre-la-montre et drag ne reprennent pas une manche
    commencée). Renvoie (accepté, raison, position de reprise).
]]
function RaceSession.reconnect(session: Session, userId: number, now: number): (boolean, string?, RaceCourse.Frame?)
    local participant = session.Participants[userId]
    if participant == nil then
        return false, "RaceNotRegistered", nil
    end
    local progress = participant.Progress
    if progress.Status ~= "Disconnected" then
        return false, "RaceNotDisconnected", nil
    end
    if session.State ~= "Countdown" and session.State ~= "Running" then
        return false, "RaceOver", nil
    end
    if now > (participant.ReconnectDeadline or 0) then
        return false, "ReconnectWindowExpired", nil
    end
    local started = progress.StartT ~= nil and now >= (progress.StartT :: number)
    local id = session.Discipline.Id
    if started and (id == "TimeTrial" or id == "Drag") then
        return false, "ResumeNotFair", nil
    end
    RaceRules.resume(progress)
    participant.ReconnectDeadline = nil
    local built = session.Built
    -- Reprise au dernier point validé ; sinon à sa place de départ.
    local frame: RaceCourse.Frame = built.Grid[progress.Slot] or built.Start
    if started and progress.Next > 1 then
        local cp = built.Checkpoints[progress.Next - 1]
        frame = { X = cp.X, Z = cp.Z, Y = cp.Y, Heading = cp.Heading }
    elseif started and built.Closed and progress.Lap > 1 then
        frame = built.Start
    end
    return true, nil, frame
end

function RaceSession.abandon(session: Session, userId: number): (boolean, string?)
    local participant = session.Participants[userId]
    if participant == nil then
        return false, "RaceNotRegistered"
    end
    if session.State == "Open" then
        return false, "RaceNotStarted"
    end
    RaceRules.close(participant.Progress, "Abandoned", "Abandon")
    return true, nil
end

local function open(progress: RaceRules.Progress): boolean
    return progress.Status == "Waiting" or progress.Status == "Racing" or progress.Status == "Disconnected"
end

--[[
    Avance l'horloge de l'épreuve. Renvoie les transitions (« Started »,
    « Finished », « Cancelled », « ReconnectExpired:<UserId> »).
]]
function RaceSession.tick(session: Session, now: number): { string }
    local events: { string } = {}
    local timing = RaceDefinitions.Timing
    if session.State == "Open" then
        if now - session.CreatedAt >= timing.LobbyMaxS then
            RaceSession.cancel(session, now)
            table.insert(events, "Cancelled")
        end
        return events
    end
    if session.State == "Countdown" and now >= (session.StartT :: number) then
        session.State = "Running"
        table.insert(events, "Started")
    end
    if session.State ~= "Running" then
        return events
    end
    for userId, participant in session.Participants do
        local progress = participant.Progress
        if progress.Status == "Disconnected" and now > (participant.ReconnectDeadline or math.huge) then
            RaceRules.close(progress, "Disconnected", "ReconnectWindowExpired")
            progress.Status = "Disconnected"
            participant.ReconnectDeadline = nil
            table.insert(events, "ReconnectExpired:" .. userId)
        end
    end
    local anyOpen = false
    local lastStart = session.StartT :: number
    for _, participant in session.Participants do
        local progress = participant.Progress
        lastStart = math.max(lastStart, progress.StartT or lastStart)
        -- Un déconnecté dans sa fenêtre garde l'épreuve ouverte (reprise possible).
        if open(progress) and (progress.Status ~= "Disconnected" or participant.ReconnectDeadline ~= nil) then
            anyOpen = true
        end
    end
    local window = session.Discipline.FinishWindowS
    local finishWindowOver = session.FirstFinishT ~= nil
        and window > 0
        and now >= (session.FirstFinishT :: number) + window
    local tooLong = now >= lastStart + math.min(timing.MaxRaceS, math.max(session.Built.ParTimeS * 3, 120))
    if not anyOpen or finishWindowOver or tooLong then
        for _, participant in session.Participants do
            if open(participant.Progress) then
                local reason = if participant.Progress.Status == "Disconnected" then "Disconnected" else "TimedOut"
                RaceRules.close(
                    participant.Progress,
                    if reason == "Disconnected" then "Disconnected" else "TimedOut",
                    reason
                )
            end
        end
        session.State = "Finished"
        session.EndedAt = now
        table.insert(events, "Finished")
    end
    return events
end

-- Classement (validation serveur de chaque arrivée).
function RaceSession.classification(session: Session): RaceScoring.Classification
    local entries: { RaceScoring.Entry } = {}
    for _, userId in session.Order do
        local participant = session.Participants[userId]
        local verdict = RaceValidator.checkFor(participant.Progress, session.Discipline, participant.MaxPlausibleKmh)
        table.insert(entries, RaceScoring.entry(participant.Progress, verdict))
    end
    return RaceScoring.classify(entries, session.Discipline.Ranking)
end

-- Identifiant stable du résultat d'un participant.
function RaceSession.resultId(session: Session, userId: number): string
    return session.Id .. ":" .. tostring(userId)
end

return table.freeze(RaceSession)
