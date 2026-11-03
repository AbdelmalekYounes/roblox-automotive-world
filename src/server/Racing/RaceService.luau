--!strict
--[[
    Service des courses (lot 0.6) : point d'entrée UNIQUE des épreuves
    (canal AWRacing). Orchestration Roblox des modules purs du socle commun
    (RaceCourse, RaceLobby, RaceSession, RaceRules, RaceScoring,
    RaceValidator, RaceRewards, RankedService, SeasonService,
    VehicleRaceReservation, RaceRecovery, RacePersistence, MatchmakingService).

    - Inscription PHYSIQUE : au point d'inscription du parcours (ou à son
      départ), arrêté, au volant de son exemplaire personnel sorti
      (entraînement : tout véhicule conduit, sans conséquence durable).
      Engagement = transaction du profil (réservation exclusive, état initial
      en mode protégé), puis inscription au salon.
    - Aucun déplacement imposé : les participants rejoignent eux-mêmes leur
      place ; seule la reprise après reconnexion rematérialise le véhicule au
      dernier point validé (transition explicite et unique).
    - Échantillons SERVEUR à 10 Hz (position, vitesse, cap, usure confirmée,
      corrections) et horloge serveur (GetServerTimeNow) : aucun temps ni
      résultat client.
    - Mode protégé : session protégée (aucune écriture durable), puis
      restauration exacte. Conditions normalisées (classé, records) : humidité
      standardisée sur le véhicule engagé seulement ; la météo du monde
      continue normalement.
    - Fin d'épreuve : classement validé, contextes de paiement PUBLIÉS
      (Race_<id>) avant toute application, puis transaction unique par
      participant (crédits, points, record, libération) — rejouable sans
      doublon ; un profil verrouillé ailleurs est réconcilié par le serveur
      qui le détient.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RacingShared = Shared:WaitForChild("Racing")
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))
local VehicleDefinitions = require(Shared.Vehicles.VehicleDefinitions)
local RaceProtocol = require(RacingShared:WaitForChild("RaceProtocol"))
local RaceDefinitions = require(RacingShared:WaitForChild("RaceDefinitions"))
local RaceCourses = require(RacingShared:WaitForChild("RaceCourses"))
local Seasons = require(RacingShared:WaitForChild("Seasons"))

local Persistence = script.Parent.Parent.Persistence
local ProfileService = require(Persistence.ProfileService)
local ProfileSchema = require(Persistence.ProfileSchema)
local TransactionService = require(Persistence.TransactionService)
local RateLimiter = require(script.Parent.Parent.Security.RateLimiter)
local VehicleService = require(script.Parent.Parent.Vehicles.VehicleService)
local ProgressionService = require(script.Parent.Parent.Progression.ProgressionService)
local RaceCourse = require(script.Parent.RaceCourse)
local RaceLobby = require(script.Parent.RaceLobby)
local RaceSession = require(script.Parent.RaceSession)
local RaceScoring = require(script.Parent.RaceScoring)
local RaceRewards = require(script.Parent.RaceRewards)
local RankedService = require(script.Parent.RankedService)
local SeasonService = require(script.Parent.SeasonService)
local VehicleRaceReservation = require(script.Parent.VehicleRaceReservation)
local RaceRecovery = require(script.Parent.RaceRecovery)
local RacePersistence = require(script.Parent.RacePersistence)
local MatchmakingService = require(script.Parent.MatchmakingService)
local CrossServerAdapter = require(script.Parent.CrossServerAdapter)
local RaceInstallations = require(script.Parent.RaceInstallations)

local RaceService = {}

local S = 1 / Constants.MetersPerStud
local SAMPLE_S = 0.1
local TICK_S = 0.5
local MATCH_S = 2
local RECONCILE_S = 30
local REGISTER_RADIUS_M = 45
local READY_RADIUS_M = 35
local JOIN_MAX_SPEED_MS = 3
local KEEP_FINISHED_S = 120

type Response = { Status: string, Error: string?, Result: any? }

-- Participant présent sur CE serveur (clé : UserId, stable à la reconnexion).
type Runtime = {
    SessionId: string,
    EntryId: string?, -- engagement durable (nil : véhicule de flotte à l'entraînement)
    VehicleId: string,
    Model: Model?,
    Mode: string,
    PreviousMayDrive: ((Player) -> boolean)?,
    LastCorrections: number,
    LastEnergy: number?,
    LastDamage: any?,
    Released: boolean,
}

local started = false
local placeName = "Dev"
local push: RemoteEvent
local courses: { [string]: RaceCourse.Built } = {}
local installations: { [string]: RaceInstallations.Installation } = {}
local lobby = RaceLobby.new()
local queue: MatchmakingService.Queue
local runtimes: { [number]: Runtime } = {}
local limiters: { [Player]: RateLimiter.Bucket } = {}
local finalizing: { [string]: boolean } = {}
local boards: any = RacePersistence.memoryBoard()
local cross: CrossServerAdapter.Adapter? = nil
local crossResolved = false

-- Adaptateur inter-serveurs, créé à la première utilisation : l'environnement
-- n'est connu qu'une fois ProfileService démarré (après ce service).
local function crossAdapter(): CrossServerAdapter.Adapter?
    if not crossResolved then
        crossResolved = true
        cross = CrossServerAdapter.new(ProfileService.environment().Name, game.PlaceId)
    end
    return cross
end
local counter = 0

local function clock(): number
    return Workspace:GetServerTimeNow()
end

local function unix(): number
    return os.time()
end

local function rejected(key: string): Response
    return { Status = "Rejected", Error = key }
end

local function log(level: any, event: string, fields: any)
    ProfileService.Log:write(level, event, fields)
end

local function rootOf(player: Player): BasePart?
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return if root and root:IsA("BasePart") then root else nil
end

-- Véhicule conduit (siège conducteur occupé) et sa partie principale.
local function driven(player: Player): (Model?, BasePart?)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local seat = humanoid and humanoid.SeatPart
    -- Siège conducteur des véhicules (classe Seat depuis le lot 0.1, jamais VehicleSeat) ;
    -- la place passager est exclue. Lot 0.9 : l'ancien contrôle « VehicleSeat » refusait
    -- toute inscription en jeu (RaceDriveToJoin), défaut révélé par la session VM lot06.
    if seat == nil or seat.Name ~= "DriverSeat" or not (seat:IsA("Seat") or seat:IsA("VehicleSeat")) then
        return nil, nil
    end
    local model = seat:FindFirstAncestorWhichIsA("Model")
    if model == nil or model.PrimaryPart == nil then
        return nil, nil
    end
    return model, model.PrimaryPart
end

local function vehicleIdOf(model: Model): string
    local personal = model:GetAttribute("PersonalVehicleId")
    return if type(personal) == "string" then personal else model.Name
end

local function metersOf(position: Vector3): (number, number)
    return position.X / S, position.Z / S
end

local function distanceM(ax: number, az: number, bx: number, bz: number): number
    return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

local function groundY(x: number, z: number): number
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore: { Instance } = {}
    for _, player in Players:GetPlayers() do
        if player.Character then
            table.insert(ignore, player.Character)
        end
    end
    params.FilterDescendantsInstances = ignore
    local hit = Workspace:Raycast(Vector3.new(x * S, 2500, z * S), Vector3.new(0, -5000, 0), params)
    return if hit then hit.Position.Y else 0
end

local function newRaceId(): string
    counter += 1
    return string.format("%s-%d", string.sub(HttpService:GenerateGUID(false), 1, 8), counter)
end

local function entryIdOf(sessionId: string, userId: number): string
    return "E-" .. sessionId .. ":" .. tostring(userId)
end

-- ============================== Instantanés ==============================

local function participantsView(session: RaceSession.Session): { any }
    local list = {}
    for _, userId in session.Order do
        local participant = session.Participants[userId]
        local player = Players:GetPlayerByUserId(userId)
        local progress = participant.Progress
        table.insert(list, {
            UserId = userId,
            Name = if player then player.DisplayName else tostring(userId),
            Ready = participant.Ready,
            Mode = participant.Mode,
            Status = progress.Status,
            Lap = progress.Lap,
            Next = progress.Next,
            ProgressM = progress.ProgressM,
            FinishT = progress.FinishT,
        })
    end
    return list
end

-- Position en course (grille) : arrivés d'abord, puis distance validée.
local function livePositions(session: RaceSession.Session): { [number]: number }
    local order = table.clone(session.Order)
    table.sort(order, function(a, b)
        local pa, pb = session.Participants[a].Progress, session.Participants[b].Progress
        local fa, fb = pa.FinishT or math.huge, pb.FinishT or math.huge
        if fa ~= fb then
            return fa < fb
        end
        if pa.ProgressM ~= pb.ProgressM then
            return pa.ProgressM > pb.ProgressM
        end
        return (pa.LastPassT or math.huge) < (pb.LastPassT or math.huge)
    end)
    local positions = {}
    for index, userId in order do
        positions[userId] = index
    end
    return positions
end

local function sessionView(session: RaceSession.Session, userId: number): any
    local built = session.Built
    local course = built.Course
    local participant = session.Participants[userId]
    local view: any = {
        SessionId = session.Id,
        CourseId = built.Id,
        Name = course.Name,
        Discipline = session.Discipline.Id,
        DisciplineLabel = session.Discipline.Label,
        Kind = session.Kind.Id,
        KindLabel = session.Kind.Label,
        State = session.State,
        Laps = session.Laps,
        StartT = session.StartT,
        Normalized = session.Normalized,
        Conditions = session.Conditions,
        Modes = session.Modes,
        Private = session.OrganizerUserId ~= nil,
        Count = RaceSession.count(session),
        Max = session.MaxParticipants,
        Min = session.MinParticipants,
        CreatedAt = session.CreatedAt,
        Participants = participantsView(session),
        CheckpointsTotal = #built.Checkpoints,
        Start = { X = built.Start.X, Z = built.Start.Z },
        DriftCenter = built.DriftCenter,
        DriftRadiusM = built.DriftRadiusM,
    }
    if participant then
        local progress = participant.Progress
        local positions = livePositions(session)
        local nextCheckpoints = {}
        for k = progress.Next, math.min(progress.Next + 1, #built.Checkpoints) do
            local cp = built.Checkpoints[k]
            table.insert(nextCheckpoints, { X = cp.X, Z = cp.Z, Radius = cp.Radius, Index = k })
        end
        local slot = built.Grid[progress.Slot]
        view.Me = {
            Mode = participant.Mode,
            Ready = participant.Ready,
            Status = progress.Status,
            Reason = progress.Reason,
            StartT = progress.StartT,
            Slot = progress.Slot,
            SlotPoint = if slot and session.Discipline.Start ~= "Zone" then { X = slot.X, Z = slot.Z } else nil,
            Lap = progress.Lap,
            Next = progress.Next,
            Checkpoints = nextCheckpoints,
            LapTimes = progress.LapTimes,
            BestLapS = progress.BestLapS,
            PenaltyS = progress.PenaltyS,
            Penalties = progress.Penalties,
            FalseStart = progress.FalseStart,
            ReactionS = progress.ReactionS,
            FinishT = progress.FinishT,
            OfficialS = progress.OfficialS,
            Position = positions[userId],
            Drift = if progress.Drift
                then {
                    Total = progress.Drift.Total,
                    Combo = math.floor(progress.Drift.ComboPoints * progress.Drift.Multiplier),
                    Multiplier = progress.Drift.Multiplier,
                }
                else nil,
            ReconnectDeadline = participant.ReconnectDeadline,
        }
    end
    return view
end

local function pushSession(session: RaceSession.Session)
    for _, userId in session.Order do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            push:FireClient(player, "Snapshot", sessionView(session, userId))
        end
    end
end

-- ============================== Véhicule engagé ==============================

-- Protection (mode protégé), droit de conduire réservé au propriétaire,
-- conditions normalisées (humidité standardisée) sur le véhicule engagé.
local function applyHooks(runtime: Runtime, session: RaceSession.Session, owner: Player)
    local model = runtime.Model
    if model == nil then
        return
    end
    if runtime.EntryId then
        VehicleService.setPersonalProtected(model, runtime.Mode == "Protected")
        runtime.PreviousMayDrive = runtime.PreviousMayDrive or VehicleService.personalMayDrive(model)
        VehicleService.setPersonalMayDrive(model, function(candidate: Player)
            return candidate.UserId == owner.UserId
        end)
    end
    if session.Normalized then
        model:SetAttribute(Constants.RaceWetnessAttribute, 0)
    end
end

-- Fin de l'engagement pour le véhicule matérialisé : restauration exacte
-- (mode protégé), protection et droits d'avant-course rétablis.
local function releaseHooks(runtime: Runtime, restored: any?)
    local model = runtime.Model
    if model and model.Parent then
        if restored then
            VehicleService.restorePersonalDamage(model, restored.Damage)
            VehicleService.setPersonalEnergy(model, restored.Energy)
        end
        if runtime.EntryId then
            VehicleService.setPersonalProtected(model, false)
            if runtime.PreviousMayDrive then
                VehicleService.setPersonalMayDrive(model, runtime.PreviousMayDrive :: (Player) -> boolean)
            end
        end
        model:SetAttribute(Constants.RaceWetnessAttribute, nil)
    end
end

-- Libération anticipée (désinscription, abandon, épreuve annulée).
local function releaseEarly(userId: number, txPrefix: string)
    local runtime = runtimes[userId]
    if runtime == nil or runtime.Released then
        return
    end
    runtime.Released = true
    local restored = nil
    if runtime.EntryId then
        local entryId = runtime.EntryId :: string
        local outcome = ProfileService.access():apply(userId, txPrefix .. entryId, "RaceRelease", function(profile)
            return VehicleRaceReservation.release(profile, entryId, unix())
        end)
        if outcome.Result then
            restored = outcome.Result.Restored
        end
    end
    releaseHooks(runtime, restored)
end

-- ============================== Fin d'épreuve ==============================

local function contextFor(
    session: RaceSession.Session,
    entry: RaceScoring.Entry,
    classification: RaceScoring.Classification,
    deltas: { [number]: any },
    eligible: boolean
): any
    local built = session.Built
    local course = built.Course
    local participant = session.Participants[entry.UserId]
    local runtime = runtimes[entry.UserId]
    local ladder = session.Discipline.Ladder
    return {
        ResultId = RaceSession.resultId(session, entry.UserId),
        EntryId = if runtime then runtime.EntryId else entryIdOf(session.Id, entry.UserId),
        RaceId = session.Id,
        CourseId = built.Id,
        Discipline = session.Discipline.Id,
        Kind = session.Kind.Id,
        Mode = participant.Mode,
        Outcome = entry.Outcome,
        Position = entry.Position,
        Field = classification.Field,
        OfficialS = entry.OfficialS,
        Score = entry.Score,
        ParTimeS = built.ParTimeS,
        ParScore = built.ParScore,
        TotalKm = built.TotalM / 1000,
        Difficulty = course.Difficulty,
        RewardEligible = eligible,
        Conditions = session.Conditions,
        RecordEligible = session.Normalized and built.RecordEligible and session.Kind.Records,
        RecordKey = RaceCourses.recordKey(course),
        Ranked = if session.Kind.Ranked
                and ladder
                and deltas[entry.UserId]
            then { Ladder = ladder, Delta = deltas[entry.UserId], Won = entry.Position == 1 }
            else nil,
    }
end

local function resultsView(classification: RaceScoring.Classification): { any }
    local list = {}
    for _, entry in classification.Entries do
        local player = Players:GetPlayerByUserId(entry.UserId)
        table.insert(list, {
            UserId = entry.UserId,
            Name = if player then player.DisplayName else tostring(entry.UserId),
            Outcome = entry.Outcome,
            Reason = entry.Reason,
            Position = entry.Position,
            OfficialS = entry.OfficialS,
            PenaltyS = entry.PenaltyS,
            BestLapS = entry.BestLapS,
            ReactionS = entry.ReactionS,
            TrapSpeedKmh = entry.TrapSpeedKmh,
            Score = entry.Score,
            Reasons = entry.Reasons,
        })
    end
    return list
end

local function finalize(session: RaceSession.Session)
    if finalizing[session.Id] then
        return
    end
    finalizing[session.Id] = true
    local classification = RaceSession.classification(session)
    local built = session.Built
    -- Salon privé : rémunéré seulement aux paramètres officiels et à plusieurs.
    local eligible = session.Kind.Id ~= "Private" or (session.Laps == built.Course.Laps and classification.Field >= 2)
    local deltas: { [number]: any } = {}
    local ladder = session.Discipline.Ladder
    if session.Kind.Ranked and ladder then
        local ratings: { [number]: number } = {}
        for userId, participant in session.Participants do
            ratings[userId] = participant.Rating
        end
        deltas = RankedService.deltas(classification, ladder, ratings, built.ParScore)
    end
    local contexts: { [string]: any } = {}
    local byUser: { [number]: any } = {}
    for _, entry in classification.Entries do
        local runtime = runtimes[entry.UserId]
        if runtime and runtime.EntryId == nil then
            continue -- véhicule de flotte (entraînement) : rien de durable
        end
        local ctx = contextFor(session, entry, classification, deltas, eligible)
        contexts[tostring(entry.UserId)] = ctx
        byUser[entry.UserId] = ctx
    end
    -- Contextes PUBLIÉS avant toute application (récupération par un autre serveur).
    local status = RacePersistence.publish(ProfileService.repository(), session.Id, {
        CourseId = built.Id,
        Kind = session.Kind.Id,
        EndedAt = unix(),
    }, contexts)
    if status ~= "Ok" then
        log("Warn", "RaceRecordNotPublished", { RaceId = session.Id, Status = status })
    end
    local view = resultsView(classification)
    for _, entry in classification.Entries do
        local userId = entry.UserId
        local ctx = byUser[userId]
        local runtime = runtimes[userId]
        local mine: any = { Outcome = entry.Outcome, Credits = 0, Status = "None" }
        if ctx then
            local outcome = ProfileService.access():apply(userId, "Race:" .. ctx.ResultId, "Race", function(profile)
                return RaceRewards.payout(profile, ctx, unix())
            end)
            mine.Status = outcome.Status
            if outcome.Result then
                mine.Credits = outcome.Result.Credits or 0
                mine.RankedDelta = outcome.Result.RankedDelta
                mine.Rank = outcome.Result.Rank
                mine.Record = outcome.Result.Record
                mine.RealisticExtra = outcome.Result.RealisticExtra
                mine.Capped = outcome.Result.Capped
            end
            if runtime and not runtime.Released then
                runtime.Released = true
                releaseHooks(runtime, if outcome.Result then outcome.Result.Restored else nil)
            end
            -- Tableaux : points de saison (classé) et records (conditions normalisées).
            local player = Players:GetPlayerByUserId(userId)
            local profileSession = if player then ProfileService.get(player) else nil
            if profileSession and profileSession.Data and ctx.Ranked then
                local points = RankedService.points(profileSession.Data, ctx.Ranked.Ladder)
                local board = RacePersistence.seasonBoard(Seasons.index(unix()), ctx.Ranked.Ladder)
                boards:submit(board, userId, points, "Latest")
            end
            if ctx.RecordEligible and entry.Outcome == "Finished" then
                local board = RacePersistence.recordBoard(ctx.RecordKey)
                if session.Discipline.Ranking == "Score" then
                    boards:submit(board, userId, entry.Score or 0, "Higher")
                elseif entry.OfficialS then
                    boards:submit(board, userId, entry.OfficialS, "Lower")
                end
            end
        elseif runtime and not runtime.Released then
            runtime.Released = true
            releaseHooks(runtime, nil)
        end
        RaceLobby.release(lobby, userId)
        runtimes[userId] = nil
        local player = Players:GetPlayerByUserId(userId)
        if player then
            push:FireClient(player, "Results", {
                SessionId = session.Id,
                Name = built.Course.Name,
                Discipline = session.Discipline.Id,
                Ranking = session.Discipline.Ranking,
                Kind = session.Kind.Id,
                Conditions = session.Conditions,
                Entries = view,
                Mine = mine,
            })
        end
    end
    if installations[built.Id] then
        RaceInstallations.setLights(installations[built.Id], {})
    end
    log("Info", "RaceFinished", { RaceId = session.Id, CourseId = built.Id, Field = classification.Field })
end

local function cancelled(session: RaceSession.Session)
    for _, userId in table.clone(session.Order) do
        releaseEarly(userId, "RaceCancel:")
        RaceLobby.release(lobby, userId)
        runtimes[userId] = nil
        local player = Players:GetPlayerByUserId(userId)
        if player then
            push:FireClient(player, "Notice", "RaceCancelled")
            push:FireClient(player, "Snapshot", { None = true })
        end
    end
end

-- ============================== Requêtes ==============================

local handlers: { [string]: (Player, any, string?) -> Response } = {}

local function profileSummary(profile: ProfileSchema.Profile?): any
    if profile == nil then
        return nil
    end
    local racing = profile.Racing
    local ladders = {}
    for _, name in Seasons.Ladders do
        local points = RankedService.points(profile, name)
        local ladder = racing.Ranked.Ladders[name]
        ladders[name] = {
            Points = points,
            Rank = Seasons.rank(points).Name,
            Played = if ladder then ladder.Played else 0,
            Wins = if ladder then ladder.Wins else 0,
        }
    end
    local results = {}
    for id, result in racing.Results do
        table.insert(results, { Id = id, Result = result })
    end
    table.sort(results, function(a, b)
        return a.Result.At > b.Result.At
    end)
    while #results > 8 do
        table.remove(results)
    end
    local records = {}
    for key, record in racing.Records do
        records[key] = { TimeS = record.TimeS, Score = record.Score }
    end
    return {
        Ladders = ladders,
        History = racing.Ranked.History,
        Results = results,
        Records = records,
        Stats = racing.Stats,
        Engaged = racing.Active ~= nil,
    }
end

handlers.Catalog = function(player)
    local root = rootOf(player)
    local x, z = 0, 0
    if root then
        x, z = metersOf(root.Position)
    end
    local list = {}
    for id, built in courses do
        local course = built.Course
        local open = {}
        for _, session in RaceLobby.search(lobby, { CourseId = id }) do
            table.insert(open, {
                SessionId = session.Id,
                Kind = session.Kind.Id,
                Count = RaceSession.count(session),
                Max = session.MaxParticipants,
            })
        end
        local reg = built.Registration
        table.insert(list, {
            Id = id,
            Name = course.Name,
            Discipline = course.Discipline,
            DisciplineLabel = (RaceDefinitions.discipline(course.Discipline) :: any).Label,
            Zone = course.Area or course.Zone,
            LengthM = math.floor(built.TotalM),
            Laps = built.Laps,
            Difficulty = course.Difficulty,
            Kinds = course.Kinds,
            Traffic = built.Traffic,
            RecordEligible = built.RecordEligible,
            ParTimeS = built.ParTimeS,
            DistanceM = math.floor(distanceM(x, z, reg.X, reg.Z)),
            Registration = { X = reg.X, Z = reg.Z },
            Open = open,
            RecordKey = RaceCourses.recordKey(course),
        })
    end
    table.sort(list, function(a, b)
        return a.DistanceM < b.DistanceM
    end)
    local session = ProfileService.get(player)
    local current = RaceLobby.sessionOf(lobby, player.UserId)
    local season = Seasons.index(unix())
    local _, seasonEnd = Seasons.bounds(math.max(season, 1))
    local ticket = queue.Tickets[player.UserId]
    return {
        Status = "Ok",
        Result = {
            Courses = list,
            Season = { Index = season, EndsAt = seasonEnd },
            Profile = profileSummary(if session then session.Data else nil),
            Current = if current then sessionView(current, player.UserId) else nil,
            Queue = if ticket
                then { State = ticket.State, MatchId = ticket.MatchId, Discipline = ticket.Discipline }
                else nil,
            CrossServer = crossAdapter() ~= nil,
        },
    }
end

-- Contrôles communs d'inscription : lieu, arrêt, véhicule conduit.
local function joinChecks(player: Player, built: RaceCourse.Built, kind: string): (Response?, Model?, boolean)
    local model, body = driven(player)
    if model == nil or body == nil then
        return rejected("RaceDriveToJoin"), nil, false
    end
    if body.AssemblyLinearVelocity.Magnitude * Constants.MetersPerStud > JOIN_MAX_SPEED_MS then
        return rejected("MenuWhileMoving"), nil, false
    end
    local x, z = metersOf(body.Position)
    local reg, start = built.Registration, built.Start
    if math.min(distanceM(x, z, reg.X, reg.Z), distanceM(x, z, start.X, start.Z)) > REGISTER_RADIUS_M then
        return rejected("RaceJoinNotHere"), nil, false
    end
    local outModel, _ = ProgressionService.outVehicle(player)
    local personal = outModel == model and model:GetAttribute("OwnerUserId") == player.UserId
    if not personal and kind ~= "Training" then
        return rejected("RaceVehicleNotOwned"), nil, false
    end
    return nil, model, personal
end

local function maxPlausible(model: Model): number
    local definition = VehicleDefinitions.get(tostring(model:GetAttribute(Constants.Attributes.DefinitionId) or ""))
    if definition then
        return definition.Limits.MaxPlausibleSpeedKmh
    end
    return 320
end

-- Engagement : transaction du profil (réservation) puis inscription au salon.
local function engage(
    player: Player,
    session: RaceSession.Session,
    model: Model,
    personal: boolean,
    mode: string
): Response
    if RaceLobby.sessionOf(lobby, player.UserId) then
        return rejected("RaceAlreadyEngaged")
    end
    -- Lot 0.8 : les essais du parcours d'arrivée ne donnent accès à aucune épreuve (aucune récompense).
    if model:GetAttribute("AWTestDrive") == true then
        return rejected("TestDriveNoRewards")
    end
    if session.Kind.Id == "Training" then
        mode = "Protected"
    end
    if not table.find(session.Modes, mode :: any) then
        return rejected("RaceModeNotAllowed")
    end
    local vehicleId = vehicleIdOf(model)
    local entryId: string? = nil
    if personal then
        local profileSession = ProfileService.get(player)
        if profileSession == nil or profileSession.State ~= "Active" then
            return { Status = "Unavailable", Error = "ProfileUnavailable" }
        end
        ProgressionService.syncDurable(player)
        local id = entryIdOf(session.Id, player.UserId)
        local result = profileSession:commit("RaceJoin:" .. id, "RaceJoin", function(profile)
            SeasonService.transition(profile, unix())
            return VehicleRaceReservation.reserve(profile, {
                EntryId = id,
                RaceId = session.Id,
                CourseId = session.Built.Id,
                Discipline = session.Discipline.Id,
                Kind = session.Kind.Id,
                Mode = mode,
                VehicleId = vehicleId,
            }, unix())
        end)
        if result.Status ~= "Confirmed" and result.Status ~= "Pending" and result.Status ~= "Duplicate" then
            return { Status = result.Status, Error = result.Error }
        end
        entryId = id
    end
    local rating = 1000
    local ladder = session.Discipline.Ladder
    local profileSession = ProfileService.get(player)
    if ladder and profileSession and profileSession.Data then
        rating = RankedService.points(profileSession.Data, ladder)
    end
    local ok, err = RaceLobby.join(lobby, session, {
        UserId = player.UserId,
        VehicleId = vehicleId,
        ModelId = tostring(model:GetAttribute(Constants.Attributes.DefinitionId) or ""),
        Mode = mode,
        Rating = rating,
        MaxPlausibleKmh = maxPlausible(model),
    }, clock())
    local runtime: Runtime = {
        SessionId = session.Id,
        EntryId = entryId,
        VehicleId = vehicleId,
        Model = model,
        Mode = mode,
        PreviousMayDrive = nil,
        LastCorrections = select(2, VehicleService.vehicleState(model)),
        LastEnergy = nil,
        LastDamage = nil,
        Released = false,
    }
    if not ok then
        -- Inscription impossible : l'engagement est aussitôt libéré.
        runtimes[player.UserId] = runtime
        releaseEarly(player.UserId, "RaceJoinUndo:")
        runtimes[player.UserId] = nil
        return rejected(err :: string)
    end
    runtimes[player.UserId] = runtime
    applyHooks(runtime, session, player)
    pushSession(session)
    return { Status = "Ok", Result = sessionView(session, player.UserId) }
end

handlers.Join = function(player, payload)
    local data = if type(payload) == "table" then payload else {}
    local session: RaceSession.Session? = nil
    local built: RaceCourse.Built? = nil
    if data.SessionId then
        session = RaceLobby.get(lobby, data.SessionId)
        if session == nil or session.State ~= "Open" then
            return rejected("RaceRegistrationClosed")
        end
        built = (session :: RaceSession.Session).Built
    else
        built = courses[data.CourseId]
        if built == nil then
            return rejected("RaceUnknown")
        end
    end
    local b = built :: RaceCourse.Built
    local kind = if session then (session :: RaceSession.Session).Kind.Id else data.Kind
    if RaceDefinitions.kind(kind) == nil or not RaceCourses.allows(b.Course, kind) then
        return rejected("RaceKindNotAllowed")
    end
    if session == nil and (kind == "Private" or kind == "Training") then
        return rejected("RacePrivateNeedsLobby")
    end
    if session == nil and kind == "Ranked" then
        return rejected("RaceRankedNeedsQueue")
    end
    local problem, model, personal = joinChecks(player, b, kind)
    if problem then
        return problem
    end
    if session == nil then
        session = RaceLobby.openPublic(lobby, b.Id, kind)
        if session == nil then
            local created = RaceSession.new({ Id = newRaceId(), Built = b, Kind = kind, CreatedAt = clock() })
            RaceLobby.add(lobby, created)
            session = created
        end
    end
    return engage(player, session :: RaceSession.Session, model :: Model, personal, tostring(data.Mode or "Protected"))
end

handlers.CreatePrivate = function(player, payload)
    local data = if type(payload) == "table" then payload else {}
    local built = courses[data.CourseId]
    if built == nil then
        return rejected("RaceUnknown")
    end
    local kind: RaceDefinitions.KindId = if data.Kind == "Training" then "Training" else "Private"
    if not RaceCourses.allows(built.Course, kind) then
        return rejected("RaceKindNotAllowed")
    end
    local problem, model, personal = joinChecks(player, built, kind)
    if problem then
        return problem
    end
    local modes: { RaceDefinitions.ModeId } = {}
    if type(data.Modes) == "table" then
        for _, mode in data.Modes do
            if RaceDefinitions.validMode(mode) then
                table.insert(modes, mode)
            end
        end
    end
    local session = RaceSession.new({
        Id = newRaceId(),
        Built = built,
        Kind = kind,
        CreatedAt = clock(),
        OrganizerUserId = player.UserId,
        Laps = tonumber(data.Laps),
        MaxParticipants = tonumber(data.MaxParticipants),
        Modes = modes,
    })
    RaceLobby.add(lobby, session)
    local response = engage(player, session, model :: Model, personal, tostring(data.Mode or "Protected"))
    if response.Status ~= "Ok" then
        RaceSession.cancel(session, clock())
    end
    return response
end

handlers.Leave = function(player)
    local session = RaceLobby.sessionOf(lobby, player.UserId)
    if session == nil then
        return rejected("RaceNotRegistered")
    end
    local ok, err = RaceLobby.leave(lobby, player.UserId)
    if not ok then
        return rejected(err :: string)
    end
    releaseEarly(player.UserId, "RaceLeave:")
    runtimes[player.UserId] = nil
    pushSession(session)
    push:FireClient(player, "Snapshot", { None = true })
    return { Status = "Ok" }
end

handlers.Ready = function(player, payload)
    local session = RaceLobby.sessionOf(lobby, player.UserId)
    if session == nil then
        return rejected("RaceNotRegistered")
    end
    local ready = type(payload) == "table" and payload.Ready == true
    if ready then
        local root = rootOf(player)
        local start = session.Built.Start
        local x, z = 0, 0
        if root then
            x, z = metersOf(root.Position)
        end
        local center = session.Built.DriftCenter
        local tx, tz = start.X, start.Z
        if center then
            tx, tz = center.X, center.Z
        end
        if distanceM(x, z, tx, tz) > READY_RADIUS_M + (session.Built.DriftRadiusM or 0) then
            return rejected("RaceNotAtStart")
        end
    end
    local ok, err = RaceSession.setReady(session, player.UserId, ready)
    if not ok then
        return rejected(err :: string)
    end
    pushSession(session)
    return { Status = "Ok" }
end

handlers.Abandon = function(player)
    local session = RaceLobby.sessionOf(lobby, player.UserId)
    if session == nil then
        return rejected("RaceNotRegistered")
    end
    local ok, err = RaceSession.abandon(session, player.UserId)
    if not ok then
        return rejected(err :: string)
    end
    -- Le véhicule est libéré tout de suite ; le résultat (abandon) est réglé à la fin.
    releaseEarly(player.UserId, "RaceAbandon:")
    pushSession(session)
    return { Status = "Ok" }
end

handlers.Rejoin = function(player)
    local profileSession = ProfileService.get(player)
    local profile = if profileSession then profileSession.Data else nil
    local active = if profile then profile.Racing.Active else nil
    if active == nil then
        return rejected("RaceNotEngaged")
    end
    local session = RaceLobby.get(lobby, active.RaceId)
    if session == nil then
        return rejected("RaceOver")
    end
    local ok, err, frame = RaceSession.reconnect(session, player.UserId, clock())
    if not ok or frame == nil then
        return rejected(err or "RaceOver")
    end
    local f = frame :: RaceCourse.Frame
    local runtime = runtimes[player.UserId]
    local cframe = CFrame.new(f.X * S, groundY(f.X, f.Z) + 1, f.Z * S) * CFrame.Angles(0, -f.Heading, 0)
    local protected = active.Mode == "Protected"
    local status, model = ProgressionService.raceResume(
        player,
        active.EntryId,
        cframe,
        protected,
        if runtime and protected then { Energy = runtime.LastEnergy, Damage = runtime.LastDamage } else nil
    )
    if status ~= "Ok" or model == nil then
        return rejected(status)
    end
    local restored: Runtime = runtime
        or {
            SessionId = session.Id,
            EntryId = active.EntryId,
            VehicleId = active.VehicleId,
            Model = nil,
            Mode = active.Mode,
            PreviousMayDrive = nil,
            LastCorrections = 0,
            LastEnergy = nil,
            LastDamage = nil,
            Released = false,
        }
    restored.Model = model
    restored.LastCorrections = select(2, VehicleService.vehicleState(model :: Model))
    runtimes[player.UserId] = restored
    applyHooks(restored, session, player)
    pushSession(session)
    return { Status = "Ok" }
end

handlers.Queue = function(player, payload)
    local data = if type(payload) == "table" then payload else {}
    local discipline = RaceDefinitions.discipline(data.Discipline)
    if discipline == nil or discipline.Ladder == nil then
        return rejected("RaceRankedNotAllowed")
    end
    if not RaceDefinitions.validMode(data.Mode) then
        return rejected("RaceModeNotAllowed")
    end
    if RaceLobby.sessionOf(lobby, player.UserId) then
        return rejected("RaceAlreadyEngaged")
    end
    local model = ProgressionService.outVehicle(player)
    if model == nil then
        return rejected("RaceVehicleNotOwned")
    end
    local profileSession = ProfileService.get(player)
    local rating = if profileSession and profileSession.Data
        then RankedService.points(profileSession.Data, discipline.Ladder :: string)
        else 1000
    local ok, err = MatchmakingService.enqueue(queue, {
        UserId = player.UserId,
        Discipline = discipline.Id,
        Kind = "Ranked",
        Mode = data.Mode,
        Rating = rating,
    }, clock())
    if not ok then
        return rejected(err :: string)
    end
    return { Status = "Ok" }
end

handlers.Unqueue = function(player)
    MatchmakingService.cancel(queue, player.UserId)
    return { Status = "Ok" }
end

-- Parcours classé d'une discipline (le plus proche des joueurs du match).
local function rankedCourse(discipline: string, userIds: { number }): RaceCourse.Built?
    local best: RaceCourse.Built? = nil
    local bestDistance = math.huge
    for _, built in courses do
        if built.Discipline == discipline and RaceCourses.allows(built.Course, "Ranked") then
            local total = 0
            for _, userId in userIds do
                local player = Players:GetPlayerByUserId(userId)
                local root = player and rootOf(player)
                if root then
                    local x, z = metersOf(root.Position)
                    total += distanceM(x, z, built.Registration.X, built.Registration.Z)
                end
            end
            if total < bestDistance then
                best, bestDistance = built, total
            end
        end
    end
    return best
end

handlers.ConfirmMatch = function(player, payload)
    local matchId = if type(payload) == "table" then payload.MatchId else nil
    if type(matchId) ~= "string" then
        return rejected("MatchNotProposed")
    end
    local match, err = MatchmakingService.confirm(queue, player.UserId, matchId, clock())
    if err then
        return rejected(err)
    end
    if match then
        local built = rankedCourse(match.Discipline, match.UserIds)
        if built == nil then
            return rejected("RaceUnknown")
        end
        local session = RaceSession.new({
            Id = newRaceId(),
            Built = built,
            Kind = "Ranked",
            CreatedAt = clock(),
            MatchId = match.MatchId,
            Invited = match.UserIds,
        })
        RaceLobby.add(lobby, session)
        for _, userId in match.UserIds do
            local member = Players:GetPlayerByUserId(userId)
            if member then
                push:FireClient(member, "MatchReady", {
                    SessionId = session.Id,
                    CourseId = built.Id,
                    Name = built.Course.Name,
                    Registration = { X = built.Registration.X, Z = built.Registration.Z },
                })
            end
        end
    end
    return { Status = "Ok" }
end

handlers.Leaderboard = function(_player, payload)
    local data = if type(payload) == "table" then payload else {}
    local board: string
    local better: string
    if data.Board == "Race" or data.Board == "Drift" then
        board = RacePersistence.seasonBoard(Seasons.index(unix()), data.Board)
        better = "Latest"
    else
        local course = RaceCourses.get(data.CourseId)
        if course == nil then
            return rejected("RaceUnknown")
        end
        board = RacePersistence.recordBoard(RaceCourses.recordKey(course))
        better = if course.Discipline == "Drift" then "Higher" else "Lower"
    end
    local source = crossAdapter() or boards
    local top = source:top(board, 10, better)
    for _, item in top do
        local member = Players:GetPlayerByUserId(item.UserId)
        item.Name = if member then member.DisplayName else tostring(item.UserId)
    end
    return { Status = "Ok", Result = { Board = board, Entries = top } }
end

local function handle(player: Player, action: any, payload: any): Response
    if type(action) ~= "string" or handlers[action] == nil then
        return rejected("ActionUnknown")
    end
    local bucket = limiters[player]
    if bucket == nil then
        bucket = RateLimiter.new(6, 2, os.clock())
        limiters[player] = bucket
    end
    if not RateLimiter.consume(bucket, os.clock()) then
        return rejected("RateLimited")
    end
    if RaceProtocol.Sensitive[action] then
        if TransactionService.clientTxId(if type(payload) == "table" then payload.RequestId else nil) == nil then
            return rejected("RequestIdInvalid")
        end
    end
    local ok, response = pcall(handlers[action], player, payload, nil)
    if not ok then
        log("Error", "RaceHandlerFailed", { Action = action, Error = tostring(response) })
        return rejected("ServerError")
    end
    return response
end

-- ============================== Battements ==============================

local function sample(session: RaceSession.Session, userId: number)
    local player = Players:GetPlayerByUserId(userId)
    local runtime = runtimes[userId]
    if player == nil or runtime == nil then
        return
    end
    local participant = session.Participants[userId]
    if participant == nil then
        return
    end
    local status = participant.Progress.Status
    if status ~= "Waiting" and status ~= "Racing" then
        return
    end
    local model, body = driven(player)
    local root = rootOf(player)
    local part = body or root
    if part == nil then
        return
    end
    local position = part.Position
    local velocity = part.AssemblyLinearVelocity
    local look = part.CFrame.LookVector
    local wear, corrections = 0, 0
    local corrected = false
    if model then
        wear, corrections = VehicleService.vehicleState(model)
        corrected = corrections > runtime.LastCorrections
        runtime.LastCorrections = corrections
    end
    local x, z = metersOf(position)
    local events = RaceSession.observe(session, userId, {
        T = clock(),
        X = x,
        Z = z,
        VX = velocity.X * Constants.MetersPerStud,
        VZ = velocity.Z * Constants.MetersPerStud,
        SpeedMs = velocity.Magnitude * Constants.MetersPerStud,
        Heading = math.atan2(look.X, -look.Z),
        InVehicle = model ~= nil,
        VehicleId = if model then vehicleIdOf(model) else nil,
        Wear = wear,
        Corrected = corrected,
    })
    for _, event in events do
        push:FireClient(player, "Event", event)
    end
end

-- État de course conservé pour une reprise (mode protégé : dégâts de course isolés).
local function captureRuntime()
    for _, runtime in runtimes do
        local model = runtime.Model
        if model and model.Parent then
            local energy, damage = VehicleService.peekPersonal(model)
            if energy then
                runtime.LastEnergy = energy
                runtime.LastDamage = damage
            end
        end
    end
end

local function dragLights(session: RaceSession.Session)
    local installation = installations[session.Built.Id]
    if installation == nil or session.Discipline.Id ~= "Drag" or session.StartT == nil then
        return
    end
    local remaining = (session.StartT :: number) - clock()
    local red = false
    for _, participant in session.Participants do
        red = red or participant.Progress.Reason == "FalseStart"
    end
    RaceInstallations.setLights(installation, {
        Amber1 = remaining <= 1.5 and remaining > 0,
        Amber2 = remaining <= 1.0 and remaining > 0,
        Amber3 = remaining <= 0.5 and remaining > 0,
        Green = remaining <= 0 and session.State == "Running",
        Red = red,
    })
end

local function tickSessions()
    local now = clock()
    for _, session in lobby.Sessions do
        if session.State == "Open" and RaceSession.readyToLock(session, now) then
            RaceSession.lock(session, now)
            for _, userId in session.Order do
                local player = Players:GetPlayerByUserId(userId)
                if player then
                    push:FireClient(player, "Event", "Locked")
                end
            end
        end
        local events = RaceSession.tick(session, now)
        for _, event in events do
            if event == "Cancelled" then
                cancelled(session)
            elseif event == "Finished" then
                task.spawn(finalize, session)
            end
        end
        if session.State == "Countdown" or session.State == "Running" then
            dragLights(session)
            pushSession(session)
        end
    end
    RaceLobby.cleanup(lobby, now, KEEP_FINISHED_S)
end

local function tickMatchmaking()
    local proposals, removed = MatchmakingService.tick(queue, clock())
    for _, match in proposals do
        for _, userId in match.UserIds do
            local player = Players:GetPlayerByUserId(userId)
            if player then
                push:FireClient(player, "MatchProposed", {
                    MatchId = match.MatchId,
                    Discipline = match.Discipline,
                    Players = #match.UserIds,
                    ConfirmS = MatchmakingService.Params.ConfirmS,
                })
            end
        end
    end
    for _, userId in removed do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            push:FireClient(player, "Notice", "MatchExpired")
        end
    end
end

-- Réconciliation : résultat publié ailleurs ou engagement échu d'un joueur présent.
local function reconcile(player: Player)
    local profileSession = ProfileService.get(player)
    local profile = if profileSession and profileSession.State == "Active" then profileSession.Data else nil
    local active = if profile then profile.Racing.Active else nil
    if active == nil or RaceLobby.get(lobby, active.RaceId) ~= nil then
        return
    end
    local record = RacePersistence.read(ProfileService.repository(), active.RaceId)
    local pending = RaceRecovery.pendingResult(profile :: ProfileSchema.Profile, record)
    if pending then
        ProfileService.access():apply(player.UserId, "Race:" .. pending.ResultId, "Race", function(data)
            return RaceRewards.payout(data, pending, unix())
        end)
    elseif unix() >= active.ExpiresAt then
        ProfileService.access()
            :apply(player.UserId, "RaceInterrupted:" .. active.EntryId, "RaceInterrupted", function(data)
                return RaceRecovery.interrupt(data, unix())
            end)
    end
end

-- Invites des points d'inscription : ouvrent le panneau sur le parcours.
local function installPrompts()
    for id, installation in installations do
        local built = courses[id]
        local prompt = Instance.new("ProximityPrompt")
        prompt.Name = "AWRacePrompt"
        prompt.ActionText = "Course"
        prompt.ObjectText = built.Course.Name
        prompt.HoldDuration = 0.2
        prompt.MaxActivationDistance = 30
        prompt.RequiresLineOfSight = false
        prompt.Parent = installation.Pad
        prompt.Triggered:Connect(function(player)
            push:FireClient(player, "Open", { CourseId = id })
        end)
    end
end

function RaceService.start(openWorld: boolean, parent: Instance)
    assert(not started, "RaceService déjà démarré")
    started = true
    placeName = if openWorld then "OpenWorld" else "Dev"
    local built, problems = RaceCourse.buildPlace(placeName)
    courses = built
    for id, errors in problems do
        warn(string.format("[AutomotiveWorld] Parcours %s écarté : %s", id, table.concat(errors, " ; ")))
    end
    installations = RaceInstallations.build(courses, parent, not openWorld)
    queue = MatchmakingService.new(string.sub(HttpService:GenerateGUID(false), 1, 6))

    local existing = ReplicatedStorage:FindFirstChild(RaceProtocol.FolderName)
    if existing then
        existing:Destroy()
    end
    local folder = Instance.new("Folder")
    folder.Name = RaceProtocol.FolderName
    local request = Instance.new("RemoteFunction")
    request.Name = RaceProtocol.Request
    request.Parent = folder
    push = Instance.new("RemoteEvent")
    push.Name = RaceProtocol.Push
    push.Parent = folder
    folder.Parent = ReplicatedStorage
    request.OnServerInvoke = function(player: Player, action: any, payload: any): any
        return handle(player, action, payload)
    end
    installPrompts()

    -- Arrivée : reprise proposée si l'épreuve court encore ici (fenêtre ~90 s).
    ProfileService.onLoaded(function(player, session)
        local profile = session.Data :: ProfileSchema.Profile?
        local active = if profile then profile.Racing.Active else nil
        if active then
            local race = RaceLobby.get(lobby, active.RaceId)
            local participant = if race then race.Participants[player.UserId] else nil
            if participant and participant.Progress.Status == "Disconnected" and participant.ReconnectDeadline then
                push:FireClient(player, "Rejoin", {
                    SessionId = active.RaceId,
                    Name = (race :: RaceSession.Session).Built.Course.Name,
                    Deadline = participant.ReconnectDeadline,
                })
            else
                task.spawn(reconcile, player)
            end
        end
    end)
    -- Départ : désinscription avant le verrouillage, sinon fenêtre de reconnexion.
    ProfileService.onReleasing(function(player)
        MatchmakingService.cancel(queue, player.UserId)
        local session = RaceLobby.sessionOf(lobby, player.UserId)
        if session then
            if session.State == "Open" then
                RaceLobby.leave(lobby, player.UserId)
                releaseEarly(player.UserId, "RaceLeave:")
                runtimes[player.UserId] = nil
            else
                RaceSession.disconnect(session, player.UserId, clock())
                local runtime = runtimes[player.UserId]
                if runtime then
                    runtime.Model = nil
                end
            end
            pushSession(session)
        end
        limiters[player] = nil
    end)

    local sampleTimer, tickTimer, matchTimer, reconcileTimer, captureTimer = 0, 0, 0, 0, 0
    RunService.Heartbeat:Connect(function(dt)
        sampleTimer += dt
        tickTimer += dt
        matchTimer += dt
        reconcileTimer += dt
        captureTimer += dt
        if sampleTimer >= SAMPLE_S then
            sampleTimer = 0
            for _, session in lobby.Sessions do
                if session.State == "Countdown" or session.State == "Running" then
                    for _, userId in session.Order do
                        sample(session, userId)
                    end
                end
            end
        end
        if tickTimer >= TICK_S then
            tickTimer = 0
            tickSessions()
        end
        if captureTimer >= 1 then
            captureTimer = 0
            captureRuntime()
        end
        if matchTimer >= MATCH_S then
            matchTimer = 0
            tickMatchmaking()
        end
        if reconcileTimer >= RECONCILE_S then
            reconcileTimer = 0
            for _, player in Players:GetPlayers() do
                task.spawn(reconcile, player)
            end
        end
    end)
    local count = 0
    for _ in courses do
        count += 1
    end
    print(string.format("[AutomotiveWorld] %d parcours de course prêts (%s)", count, placeName))
end

-- Accès en lecture pour les essais automatisés (Studio) : parcours et salons.
function RaceService.state(): any
    return { Courses = courses, Lobby = lobby, Installations = installations }
end

return table.freeze(RaceService)
