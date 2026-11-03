--!strict
--[[
    Règles de départ, de progression et d'arrivée (lot 0.6), PURES, communes
    aux six disciplines ; seules les règles propres (RaceDefinitions) varient.

    Tout est évalué sur des échantillons SERVEUR horodatés par l'horloge du
    serveur (Workspace:GetServerTimeNow) : jamais sur une heure ou un résultat
    fourni par le client.

    - Départ : instant officiel StartT (commun pour la grille, individuel pour
      contre-la-montre et rallye, feu vert pour le drag). Un participant
      « placé » (immobile sur sa position) qui la quitte avant StartT commet
      un FAUX DÉPART : pénalité (grille, départ individuel) ou manche perdue
      (drag, feu rouge). Un retardataire part quand il veut : son temps court
      depuis StartT (aucune pénalité, aucun avantage).
    - Points de contrôle : obligatoires dans l'ordre ; le passage est détecté
      sur le SEGMENT entre deux échantillons (rien ne passe entre deux
      mesures) et son instant interpolé. Un point manqué n'est pas validé :
      il faut y revenir (sprint, circuit, contre-la-montre) ; au rallye, il
      est pénalisé (règle configurable) et la progression continue.
    - Tours (boucle) : le dernier point est la ligne ; temps au tour et
      meilleur tour.
    - Hors tracé : au-delà du couloir, l'excursion est chronométrée ;
      pénalité au-delà de la tolérance, plafonnée (un pilote honnête qui sort
      et revient n'est jamais disqualifié). Drag : sortie de couloir prolongée
      = manche invalidée.
    - Drag : temps de réaction (feu vert → franchissement de la ligne de
      départ), temps écoulé, vitesse à l'arrivée ; aucune assistance imposée.
    - Drift : score DriftScoring dans la zone pendant la durée de session.
]]

local Shared = script.Parent.Parent.Parent.Parent.ReplicatedStorage.Shared
local RaceDefinitions = require(Shared.Racing.RaceDefinitions)
local RaceCourse = require(script.Parent.RaceCourse)
local DriftScoring = require(script.Parent.DriftScoring)

local RaceRules = {}

RaceRules.StageRadiusM = 4 -- placé : à moins de 4 m de sa position de départ…
RaceRules.StageSpeedMs = 0.5 -- … et immobile
RaceRules.FalseStartMoveM = 2.5 -- placé puis déplacé de plus de 2,5 m avant le départ
RaceRules.SkipLookahead = 3 -- points suivants surveillés (point manqué)

export type Status =
    "Waiting"
    | "Racing"
    | "Finished"
    | "Abandoned"
    | "Disconnected"
    | "Disqualified"
    | "TimedOut"
    | "DidNotStart"

export type Sample = {
    T: number,
    X: number,
    Z: number,
    VX: number,
    VZ: number,
    SpeedMs: number,
    Heading: number,
    InVehicle: boolean,
    VehicleId: string?,
    Wear: number,
    Corrected: boolean,
}

export type Progress = {
    UserId: number,
    VehicleId: string,
    Slot: number,
    Status: Status,
    Reason: string?,
    StartT: number?,
    Anchor: { X: number, Z: number }?,
    Staged: boolean,
    FalseStart: boolean,
    LeftAt: number?,
    ReactionS: number?,
    Next: number,
    Lap: number,
    LapStartT: number?,
    LapTimes: { number },
    BestLapS: number?,
    CheckpointTimes: { number },
    PenaltyS: number,
    Penalties: { { Reason: string, Seconds: number } },
    OffSince: number?,
    OffTotalS: number,
    LaneOutSince: number?,
    Hint: number,
    OnCourse: boolean, -- le parcours a été rejoint après le départ
    ProgressM: number, -- distance validée (points passés), pour classer les non-arrivés
    Missed: { [number]: boolean },
    Last: Sample?,
    FinishT: number?,
    ElapsedS: number?,
    OfficialS: number?,
    TrapSpeedKmh: number?,
    Drift: DriftScoring.State?,
    Score: number?,
    -- Qualité des données (RaceValidator).
    Samples: number,
    MaxGapS: number,
    Corrections: number,
    FrozenS: number,
    MaxSpeedMs: number,
    WrongVehicleS: number,
    -- Vitesse moyenne maximale entre deux points passés (vraisemblance).
    MaxSegmentSpeedMs: number,
    LastPassT: number?,
    LastPassM: number,
}

function RaceRules.newProgress(userId: number, vehicleId: string, slot: number): Progress
    return {
        UserId = userId,
        VehicleId = vehicleId,
        Slot = slot,
        Status = "Waiting",
        Reason = nil,
        StartT = nil,
        Anchor = nil,
        Staged = false,
        FalseStart = false,
        LeftAt = nil,
        ReactionS = nil,
        Next = 1,
        Lap = 1,
        LapStartT = nil,
        LapTimes = {},
        BestLapS = nil,
        CheckpointTimes = {},
        PenaltyS = 0,
        Penalties = {},
        OffSince = nil,
        OffTotalS = 0,
        LaneOutSince = nil,
        Hint = 2,
        OnCourse = false,
        ProgressM = 0,
        Missed = {},
        Last = nil,
        FinishT = nil,
        ElapsedS = nil,
        OfficialS = nil,
        TrapSpeedKmh = nil,
        Drift = nil,
        Score = nil,
        Samples = 0,
        MaxGapS = 0,
        Corrections = 0,
        FrozenS = 0,
        MaxSpeedMs = 0,
        WrongVehicleS = 0,
        MaxSegmentSpeedMs = 0,
        LastPassT = nil,
        LastPassM = 0,
    }
end

-- Fixe l'instant officiel de départ et la position de départ (grille, box).
function RaceRules.arm(progress: Progress, startT: number, anchor: { X: number, Z: number })
    progress.StartT = startT
    progress.Anchor = { X = anchor.X, Z = anchor.Z }
end

local function penalize(progress: Progress, reason: string, seconds: number)
    if seconds <= 0 then
        return
    end
    progress.PenaltyS += seconds
    table.insert(progress.Penalties, { Reason = reason, Seconds = seconds })
end

local function finish(progress: Progress, t: number, speedMs: number)
    progress.Status = "Finished"
    progress.FinishT = t
    progress.ElapsedS = t - (progress.StartT :: number)
    progress.OfficialS = (progress.ElapsedS :: number) + progress.PenaltyS
    progress.TrapSpeedKmh = speedMs * 3.6
end

local function stop(progress: Progress, status: Status, reason: string)
    progress.Status = status
    progress.Reason = reason
end

-- Arrêt imposé de l'extérieur (abandon, déconnexion, délai, disqualification).
function RaceRules.close(progress: Progress, status: Status, reason: string)
    if progress.Status == "Waiting" or progress.Status == "Racing" or progress.Status == "Disconnected" then
        stop(progress, status, reason)
    end
end

-- Reprise après reconnexion (même épreuve, AUD-RECON-01) : le chronomètre a
-- continué ; les échantillons repartent de zéro (aucun passage interpolé à travers le trou).
function RaceRules.resume(progress: Progress)
    if progress.Status == "Disconnected" then
        progress.Status = if progress.StartT then "Racing" else "Waiting"
        progress.Reason = nil
        progress.Last = nil
        progress.OffSince = nil
        if progress.Drift then
            (progress.Drift :: DriftScoring.State).Last = nil
        end
    end
end

-- Données de qualité (trous, corrections, gel apparent de la réplication).
local function bookkeeping(progress: Progress, sample: Sample, last: Sample?)
    progress.Samples += 1
    if sample.Corrected then
        progress.Corrections += 1
    end
    progress.MaxSpeedMs = math.max(progress.MaxSpeedMs, sample.SpeedMs)
    if last then
        local dt = sample.T - last.T
        progress.MaxGapS = math.max(progress.MaxGapS, dt)
        -- Position figée alors que la voiture roulait vite : réplication suspecte (QA-A01).
        local moved = math.sqrt((sample.X - last.X) ^ 2 + (sample.Z - last.Z) ^ 2)
        if moved < 0.05 and last.SpeedMs > 10 and sample.SpeedMs > 10 then
            progress.FrozenS += dt
        end
    end
end

local function inZone(built: RaceCourse.Built, x: number, z: number): boolean
    local center = built.DriftCenter
    if center == nil then
        return false
    end
    return math.sqrt((x - center.X) ^ 2 + (z - center.Z) ^ 2) <= (built.DriftRadiusM or 0)
end

--[[
    Franchissement de la LIGNE d'un point de contrôle (perpendiculaire au
    tracé, demi-largeur = rayon) entre deux échantillons, dans le sens de
    marche. Renvoie la fraction du segment au franchissement, ou nil. Une
    simple proximité donnerait un instant trop précoce (entrée dans le rayon).
]]
function RaceRules.crossing(last: Sample, sample: Sample, cp: RaceCourse.Checkpoint): number?
    local hx, hz = math.sin(cp.Heading), -math.cos(cp.Heading)
    local before = (last.X - cp.X) * hx + (last.Z - cp.Z) * hz
    local after = (sample.X - cp.X) * hx + (sample.Z - cp.Z) * hz
    if not (before < 0 and after >= 0) then
        return nil
    end
    local f = before / (before - after)
    local x = last.X + (sample.X - last.X) * f
    local z = last.Z + (sample.Z - last.Z) * f
    -- Écart latéral au point de franchissement.
    local lateral = math.abs((x - cp.X) * -hz + (z - cp.Z) * hx)
    if lateral > cp.Radius then
        return nil
    end
    return f
end

-- Passages de points de contrôle sur le segment [last, sample].
local function checkpoints(
    progress: Progress,
    built: RaceCourse.Built,
    discipline: RaceDefinitions.Discipline,
    last: Sample,
    sample: Sample,
    events: { string }
)
    local list = built.Checkpoints
    local guard = 0
    while progress.Status == "Racing" and guard < #list + 1 do
        guard += 1
        local cp = list[progress.Next]
        if cp == nil then
            return
        end
        local t = RaceRules.crossing(last, sample, cp)
        if t ~= nil then
            local passT = last.T + (sample.T - last.T) * t
            progress.CheckpointTimes[cp.Index] = passT
            progress.ProgressM = (progress.Lap - 1) * built.LengthM + cp.Along
            local fromT = progress.LastPassT or progress.StartT :: number
            if passT > fromT then
                local average = (progress.ProgressM - progress.LastPassM) / (passT - fromT)
                progress.MaxSegmentSpeedMs = math.max(progress.MaxSegmentSpeedMs, average)
            end
            progress.LastPassT = passT
            progress.LastPassM = progress.ProgressM
            if cp.Index == #list then
                if built.Closed then
                    local lapTime = passT - (progress.LapStartT or progress.StartT :: number)
                    table.insert(progress.LapTimes, lapTime)
                    if progress.BestLapS == nil or lapTime < (progress.BestLapS :: number) then
                        progress.BestLapS = lapTime
                    end
                    table.insert(events, "Lap")
                    if progress.Lap >= built.Laps then
                        finish(progress, passT, sample.SpeedMs)
                        table.insert(events, "Finished")
                        return
                    end
                    progress.Lap += 1
                    progress.Next = 1
                    progress.LapStartT = passT
                else
                    finish(progress, passT, sample.SpeedMs)
                    table.insert(events, "Finished")
                    return
                end
            else
                progress.Next += 1
                table.insert(events, "Checkpoint")
            end
        else
            -- Point manqué ? La ligne d'un point suivant est franchie sans celle-ci.
            local advanced = false
            local lastIndex = math.min(progress.Next + RaceRules.SkipLookahead, #list)
            for j = progress.Next + 1, lastIndex do
                if built.Closed and j == #list then
                    continue -- la ligne n'est jamais un raccourci du tour (voitures sur la grille)
                end
                if RaceRules.crossing(last, sample, list[j]) ~= nil then
                    local penalty = discipline.MissedCheckpointPenaltyS
                    if penalty then
                        -- Rallye : pénalité par point manqué, la progression continue.
                        for k = progress.Next, j - 1 do
                            progress.Missed[k] = true
                            penalize(progress, "MissedCheckpoint", penalty)
                        end
                        progress.Next = j
                        table.insert(events, "Penalty")
                        advanced = true
                    elseif not progress.Missed[progress.Next] then
                        progress.Missed[progress.Next] = true
                        table.insert(events, "MissedCheckpoint")
                    end
                    break
                end
            end
            if not advanced then
                return
            end
        end
    end
end

--[[
    Intègre un échantillon serveur. Renvoie la liste des événements produits
    (« FalseStart », « Started », « Checkpoint », « Lap », « Finished »,
    « Penalty », « MissedCheckpoint », « Disqualified », « Drift:… »).
]]
function RaceRules.observe(
    progress: Progress,
    built: RaceCourse.Built,
    discipline: RaceDefinitions.Discipline,
    sample: Sample
): { string }
    local events: { string } = {}
    local last = progress.Last
    bookkeeping(progress, sample, last)
    progress.Last = sample
    if progress.Status ~= "Waiting" and progress.Status ~= "Racing" then
        return events
    end
    local startT = progress.StartT
    if startT == nil then
        return events
    end
    local rightVehicle = sample.InVehicle and sample.VehicleId == progress.VehicleId
    if not rightVehicle then
        if last then
            progress.WrongVehicleS += math.max(0, sample.T - last.T)
        end
        -- Aucune progression hors du véhicule engagé ; les échantillons suivants repartent d'ici.
        return events
    end

    -- Avant le départ : placement et faux départ.
    if sample.T < startT then
        local anchor = progress.Anchor
        if anchor then
            local away = math.sqrt((sample.X - anchor.X) ^ 2 + (sample.Z - anchor.Z) ^ 2)
            if not progress.Staged then
                if away <= RaceRules.StageRadiusM and sample.SpeedMs <= RaceRules.StageSpeedMs then
                    progress.Staged = true
                end
            elseif not progress.FalseStart and away > RaceRules.FalseStartMoveM then
                progress.FalseStart = true
                table.insert(events, "FalseStart")
                if discipline.Id == "Drag" then
                    stop(progress, "Disqualified", "FalseStart")
                    table.insert(events, "Disqualified")
                    return events
                end
                penalize(progress, "FalseStart", discipline.FalseStartPenaltyS)
            end
        end
        return events
    end

    if progress.Status == "Waiting" then
        progress.Status = "Racing"
        progress.LapStartT = startT
        table.insert(events, "Started")
        if discipline.Start == "Zone" then
            progress.Drift = DriftScoring.new()
        end
    end
    if last == nil or last.T >= sample.T then
        return events
    end

    -- Drift : session en zone.
    if discipline.Start == "Zone" then
        local drift = progress.Drift :: DriftScoring.State
        local endT = startT + RaceDefinitions.Timing.DriftSessionS
        if sample.T >= endT then
            progress.Score = DriftScoring.finish(drift)
            finish(progress, endT, sample.SpeedMs)
            table.insert(events, "Finished")
            return events
        end
        local event = DriftScoring.observe(drift, {
            T = sample.T,
            X = sample.X,
            Z = sample.Z,
            VX = sample.VX,
            VZ = sample.VZ,
            Heading = sample.Heading,
            Wear = sample.Wear,
            Corrected = sample.Corrected,
        }, inZone(built, sample.X, sample.Z))
        if event then
            table.insert(events, "Drift:" .. event)
        end
        return events
    end

    -- Distance au tracé : hors tracé et couloir de drag.
    local distance, index, along = RaceCourse.nearest(built, sample.X, sample.Z, progress.Hint)
    progress.Hint = index
    if discipline.Id == "Drag" then
        if progress.LeftAt == nil and along > 0.5 then
            progress.LeftAt = sample.T
            progress.ReactionS = sample.T - startT
        end
        if distance > discipline.CorridorM then
            progress.LaneOutSince = progress.LaneOutSince or sample.T
            if sample.T - (progress.LaneOutSince :: number) >= (discipline.LaneDisqualifyS or math.huge) then
                stop(progress, "Disqualified", "LaneViolation")
                table.insert(events, "Disqualified")
                return events
            end
        else
            progress.LaneOutSince = nil
        end
    elseif not progress.OnCourse then
        -- Avant d'avoir rejoint le parcours (retardataire) : rien n'est compté.
        progress.OnCourse = distance <= discipline.CorridorM
    elseif distance > discipline.CorridorM then
        progress.OffSince = progress.OffSince or sample.T
    elseif progress.OffSince then
        local excursion = sample.T - (progress.OffSince :: number)
        progress.OffTotalS += excursion
        progress.OffSince = nil
        local charged = math.min(math.max(excursion - discipline.OffCourseGraceS, 0), discipline.OffCoursePenaltyCapS)
        if charged > 0 then
            penalize(progress, "OffCourse", math.floor(charged * discipline.OffCoursePenaltyPerS * 10 + 0.5) / 10)
            table.insert(events, "Penalty")
        end
    end

    checkpoints(progress, built, discipline, last, sample, events)
    return events
end

-- Classement des non-arrivés : distance validée.
function RaceRules.progressM(progress: Progress): number
    return progress.ProgressM
end

return table.freeze(RaceRules)
