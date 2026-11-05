--!strict
--[[
    Parcours construits (lot 0.6), PURS, en mètres (x est, z sud, nord = -z).

    À partir des données versionnées (Shared/Racing/RaceCourses) :
    - tracé : polylignes lissées des routes de la carte (WorldLayout,
      identiques à celles du générateur), mises bout à bout dans le sens
      indiqué ; ou points de la zone d'essai ;
    - départ, arrivée (tracé ouvert) ou ligne de départ/arrivée (boucle) ;
    - points de contrôle ORDONNÉS, espacés régulièrement, le dernier étant
      l'arrivée ou la fin du tour ;
    - grille (sprint, circuit), couloirs (drag), position de départ
      individuel, zone (drift), point d'inscription physique hors chaussée ;
    - revêtements et circulation déduits des classes de routes.

    validate() contrôle la cohérence avec le graphe routier : routes connues,
    enchaînées par le même carrefour, boucle fermée, longueur, zone et
    revêtements déclarés.
]]

local Shared = script.Parent.Parent.Parent.Parent.ReplicatedStorage.Shared
local WorldLayout = require(Shared.World.WorldLayout)
local WorldConfig = require(Shared.World.WorldConfig)
local MapData = require(Shared.World.Data.MapData)
local RaceCourses = require(Shared.Racing.RaceCourses)
local RaceDefinitions = require(Shared.Racing.RaceDefinitions)

local RaceCourse = {}

export type Point3 = { X: number, Z: number, Y: number }
export type Frame = { X: number, Z: number, Y: number, Heading: number }
export type Checkpoint = {
    Index: number,
    X: number,
    Z: number,
    Y: number,
    Along: number, -- distance le long du tracé depuis le départ (m)
    Radius: number,
    Heading: number,
}

export type Built = {
    Course: RaceCourses.Course,
    Id: string,
    Discipline: string,
    Closed: boolean,
    Laps: number,
    Path: { Point3 },
    Along: { number },
    LengthM: number, -- un tour (boucle) ou départ → arrivée
    TotalM: number, -- distance totale de l'épreuve
    Start: Frame,
    Finish: Frame,
    Checkpoints: { Checkpoint },
    Grid: { Frame },
    Registration: Frame,
    DriftCenter: { X: number, Z: number }?,
    DriftRadiusM: number?,
    Surfaces: { string },
    Traffic: boolean,
    RecordEligible: boolean, -- sans circulation : temps comparables entre sessions
    ParTimeS: number,
    ParScore: number?,
    GateRadiusM: number,
    RoadHalfWidthM: number,
}

-- Bornes du sol de la zone d'essai (mètres) : 1400 × 1400 studs centrés en z = -400 studs.
RaceCourse.DevBounds = table.freeze({ MinX = -190, MaxX = 190, MinZ = -300, MaxZ = 80 })
RaceCourse.DefaultSpacingM = 180
RaceCourse.LengthTolerance = 0.05

-- Cap d'une direction (rad) : 0 = nord (-z), positif vers l'est.
function RaceCourse.heading(dx: number, dz: number): number
    return math.atan2(dx, -dz)
end

local function forward(heading: number): (number, number)
    return math.sin(heading), -math.cos(heading)
end

-- Droite du sens de marche (est quand on regarde le nord).
local function right(heading: number): (number, number)
    return math.cos(heading), math.sin(heading)
end

local function dist(a: { X: number, Z: number }, b: { X: number, Z: number }): number
    local dx, dz = a.X - b.X, a.Z - b.Z
    return math.sqrt(dx * dx + dz * dz)
end

local roadsById: { [string]: any }? = nil
local function roadData(id: string): any?
    if roadsById == nil then
        local map: { [string]: any } = {}
        for _, road in MapData.Roads do
            map[road.Id] = road
        end
        roadsById = map
    end
    return (roadsById :: { [string]: any })[id]
end

-- Matériau → revêtement déclaré.
local SURFACE_OF: { [string]: string } = { Asphalt = "Asphalt", Pebble = "Gravel", Ground = "Gravel" }

local function cumulative(path: { Point3 }): { number }
    local along = { 0 }
    for i = 2, #path do
        along[i] = along[i - 1] + dist(path[i - 1], path[i])
    end
    return along
end

-- Point et cap à la distance `s` le long d'une polyligne.
local function pointAt(path: { Point3 }, along: { number }, s: number): Frame
    local total = along[#along]
    local target = math.clamp(s, 0, total)
    for i = 2, #path do
        if target <= along[i] or i == #path then
            local a, b = path[i - 1], path[i]
            local span = along[i] - along[i - 1]
            local f = if span > 0 then math.clamp((target - along[i - 1]) / span, 0, 1) else 0
            return {
                X = a.X + (b.X - a.X) * f,
                Z = a.Z + (b.Z - a.Z) * f,
                Y = a.Y + (b.Y - a.Y) * f,
                Heading = RaceCourse.heading(b.X - a.X, b.Z - a.Z),
            }
        end
    end
    local last = path[#path]
    return { X = last.X, Z = last.Z, Y = last.Y, Heading = 0 }
end
RaceCourse.pointAt = pointAt

-- Sous-polyligne entre deux distances.
local function slice(path: { Point3 }, along: { number }, from: number, to: number): { Point3 }
    local out: { Point3 } = {}
    local a = pointAt(path, along, from)
    table.insert(out, { X = a.X, Z = a.Z, Y = a.Y })
    for i = 1, #path do
        if along[i] > from and along[i] < to then
            table.insert(out, { X = path[i].X, Z = path[i].Z, Y = path[i].Y })
        end
    end
    local b = pointAt(path, along, to)
    table.insert(out, { X = b.X, Z = b.Z, Y = b.Y })
    return out
end

type RawPath = {
    Path: { Point3 },
    Surfaces: { string },
    Traffic: boolean,
    HalfWidthM: number,
    Errors: { string },
}

-- Tracé brut d'un parcours du monde ouvert (routes enchaînées).
local function roadPath(course: RaceCourses.Course): RawPath
    local layout = WorldLayout.get()
    local path: { Point3 } = {}
    local errors: { string } = {}
    local surfaces: { [string]: boolean } = {}
    local traffic = false
    local halfWidth = 0
    local previousEnd: string? = nil
    local firstStart: string? = nil
    local roads: { RaceCourses.RoadRef } = course.Roads or {}
    for _, ref in roads do
        local road = roadData(ref.Id)
        local polyline = layout.OriginPolyline[ref.Id]
        if road == nil or polyline == nil then
            table.insert(errors, "UnknownRoad:" .. ref.Id)
            continue
        end
        local startNode = if ref.Reverse then road.To else road.From
        local endNode = if ref.Reverse then road.From else road.To
        if previousEnd ~= nil and previousEnd ~= startNode then
            table.insert(
                errors,
                string.format("RoadsNotConnected:%s(%s≠%s)", ref.Id, tostring(previousEnd), startNode)
            )
        end
        firstStart = firstStart or startNode
        previousEnd = endNode
        local class = WorldConfig.RoadClasses[road.Class]
        surfaces[SURFACE_OF[class.Material] or class.Material] = true
        traffic = traffic or class.Traffic
        halfWidth = math.max(halfWidth, WorldConfig.carriagewayWidthM(class) / 2)
        local count = #polyline
        for k = 1, count do
            local p = polyline[if ref.Reverse then count - k + 1 else k]
            local point = { X = p.X, Z = p.Z, Y = p.Y or 0 }
            local last = path[#path]
            if last == nil or dist(last, point) > 0.5 then
                table.insert(path, point)
            end
        end
    end
    if course.Closed and previousEnd ~= firstStart then
        table.insert(errors, "LoopNotClosed")
    end
    local list: { string } = {}
    for surface in surfaces do
        table.insert(list, surface)
    end
    table.sort(list)
    return { Path = path, Surfaces = list, Traffic = traffic, HalfWidthM = halfWidth, Errors = errors }
end

local function pointsPath(course: RaceCourses.Course): RawPath
    local path: { Point3 } = {}
    local points: { RaceCourses.Point } = course.Points or {}
    for _, p in points do
        table.insert(path, { X = p.X, Z = p.Z, Y = 0 })
    end
    if course.Closed and #path > 0 then
        table.insert(path, { X = path[1].X, Z = path[1].Z, Y = 0 })
    end
    return { Path = path, Surfaces = { "Asphalt" }, Traffic = false, HalfWidthM = 7, Errors = {} }
end

--[[
    Construit un parcours. Renvoie (parcours, erreurs) : un parcours dont la
    liste d'erreurs n'est pas vide ne doit pas être proposé aux joueurs.
]]
function RaceCourse.build(course: RaceCourses.Course): (Built?, { string })
    local raw = if course.Place == "OpenWorld" then roadPath(course) else pointsPath(course)
    local errors = raw.Errors
    if #raw.Path < 2 then
        table.insert(errors, "PathTooShort")
        return nil, errors
    end
    local discipline = RaceDefinitions.discipline(course.Discipline)
    if discipline == nil then
        table.insert(errors, "DisciplineUnknown")
        return nil, errors
    end
    local fullAlong = cumulative(raw.Path)
    local fullLength = fullAlong[#fullAlong]

    -- Tracé de l'épreuve, commençant au départ.
    local path: { Point3 }
    if course.Closed then
        -- Boucle : on la fait commencer à la ligne de départ/arrivée.
        local offset = math.clamp(course.StartOffsetM, 0, fullLength)
        local first = slice(raw.Path, fullAlong, offset, fullLength)
        local second = slice(raw.Path, fullAlong, 0, offset)
        path = first
        for i = 2, #second do
            table.insert(path, second[i])
        end
    else
        local from = course.StartOffsetM
        local to = if course.DistanceM then from + course.DistanceM else fullLength - course.FinishOffsetM
        if to <= from or to > fullLength + 1e-6 then
            table.insert(errors, "OffsetsOutOfRange")
            return nil, errors
        end
        path = slice(raw.Path, fullAlong, from, to)
    end
    local along = cumulative(path)
    local length = along[#along]
    local start = pointAt(path, along, 0)
    local finish = pointAt(path, along, length)
    if course.Closed then
        finish = { X = start.X, Z = start.Z, Y = start.Y, Heading = start.Heading }
    end

    local gateRadius = math.max(9, raw.HalfWidthM + 5)
    local checkpoints: { Checkpoint } = {}
    if discipline.Start ~= "Zone" then
        local spacing = course.CheckpointSpacingM or RaceCourse.DefaultSpacingM
        local count = math.max(2, math.ceil(length / spacing))
        if discipline.Id == "Drag" then
            count = 1 -- arrivée seulement (couloir rectiligne)
        end
        for k = 1, count do
            local s = length * k / count
            local p = pointAt(path, along, s)
            local radius = gateRadius
            if discipline.Id == "Drag" then
                radius = 8
            end
            table.insert(checkpoints, {
                Index = k,
                X = p.X,
                Z = p.Z,
                Y = p.Y,
                Along = s,
                Radius = radius,
                Heading = if k == count and not course.Closed then finish.Heading else p.Heading,
            })
        end
    end

    -- Grille et couloirs : derrière la ligne, dans le sens de marche.
    local grid: { Frame } = {}
    local fx, fz = forward(start.Heading)
    local rx, rz = right(start.Heading)
    for i = 1, course.MaxParticipants do
        local back, side
        if discipline.Start == "Lights" then
            back, side = 0, if i == 1 then -3 else 3
        else
            local row = math.floor((i - 1) / 2)
            back = 6 + row * 8
            side = if (i - 1) % 2 == 0 then -2.8 else 2.8
        end
        table.insert(grid, {
            X = start.X - fx * back + rx * side,
            Z = start.Z - fz * back + rz * side,
            Y = start.Y,
            Heading = start.Heading,
        })
    end
    local padSide = raw.HalfWidthM + 9
    local registration: Frame = {
        X = start.X - fx * 20 + rx * padSide,
        Z = start.Z - fz * 20 + rz * padSide,
        Y = start.Y,
        Heading = start.Heading,
    }

    local laps = if course.Closed then course.Laps else 1
    local total = length * laps
    local parTime = total / (course.RefSpeedKmh / 3.6) + 4 -- départ arrêté
    if discipline.Start == "Zone" then
        parTime = RaceDefinitions.Timing.DriftSessionS
    end
    local built: Built = {
        Course = course,
        Id = course.Id,
        Discipline = course.Discipline,
        Closed = course.Closed,
        Laps = laps,
        Path = path,
        Along = along,
        LengthM = length,
        TotalM = total,
        Start = start,
        Finish = finish,
        Checkpoints = checkpoints,
        Grid = grid,
        Registration = registration,
        DriftCenter = course.DriftCenter,
        DriftRadiusM = course.DriftRadiusM,
        Surfaces = raw.Surfaces,
        -- Drift : la session se joue sur une aire fermée (la route d'accès n'en fait pas partie).
        Traffic = raw.Traffic and discipline.Start ~= "Zone",
        RecordEligible = not raw.Traffic or discipline.Start == "Zone",
        ParTimeS = parTime,
        ParScore = course.ParScore,
        GateRadiusM = gateRadius,
        RoadHalfWidthM = raw.HalfWidthM,
    }
    -- Longueur déclarée : un tour (boucle) ou le tracé complet de référence.
    local measured = if course.Closed then length else fullLength
    if math.abs(measured - course.LengthM) > course.LengthM * RaceCourse.LengthTolerance then
        table.insert(errors, string.format("LengthMismatch:%d≠%d", math.floor(measured), course.LengthM))
    end
    return built, errors
end

-- Validation complète des données d'un parcours (structure, carte, règles).
function RaceCourse.validate(course: RaceCourses.Course): { string }
    local errors: { string } = {}
    local discipline = RaceDefinitions.discipline(course.Discipline)
    if discipline == nil then
        return { "DisciplineUnknown" }
    end
    for _, kind in course.Kinds do
        if RaceDefinitions.kind(kind) == nil then
            table.insert(errors, "KindUnknown:" .. kind)
        end
    end
    if table.find(course.Kinds, "Ranked") and discipline.Ladder == nil then
        table.insert(errors, "RankedNotAllowedForDiscipline")
    end
    if course.Laps < 1 or course.Laps ~= math.floor(course.Laps) then
        table.insert(errors, "Laps")
    end
    if discipline.Id == "Circuit" and not course.Closed then
        table.insert(errors, "CircuitMustBeClosed")
    end
    if course.Closed and discipline.Id ~= "Circuit" and discipline.Id ~= "TimeTrial" then
        table.insert(errors, "ClosedNotAllowed")
    end
    if discipline.Id == "Drag" and (course.DistanceM == nil or course.MaxParticipants > 2) then
        table.insert(errors, "DragRules")
    end
    if
        discipline.Id == "Drift" and (course.DriftCenter == nil or course.DriftRadiusM == nil or course.ParScore == nil)
    then
        table.insert(errors, "DriftZoneMissing")
    end
    if course.MinParticipants < 1 or course.MaxParticipants < course.MinParticipants then
        table.insert(errors, "Participants")
    end
    if course.Difficulty < 1 or course.Difficulty > 3 then
        table.insert(errors, "Difficulty")
    end
    if course.RefSpeedKmh < 20 or course.RefSpeedKmh > 250 then
        table.insert(errors, "RefSpeed")
    end
    if (course.Place == "OpenWorld") ~= (course.Roads ~= nil) then
        table.insert(errors, "PathSource")
    end
    local built, buildErrors = RaceCourse.build(course)
    for _, e in buildErrors do
        table.insert(errors, e)
    end
    if built == nil then
        return errors
    end
    if course.Place == "OpenWorld" then
        local zone = WorldLayout.zoneOf(built.Start.X, built.Start.Z)
        if zone ~= course.Zone then
            table.insert(errors, string.format("ZoneMismatch:%s≠%s", zone, course.Zone))
        end
        local declared = table.clone(course.Surface)
        table.sort(declared)
        if table.concat(declared, ",") ~= table.concat(built.Surfaces, ",") then
            table.insert(
                errors,
                string.format("SurfaceMismatch:%s≠%s", table.concat(built.Surfaces, ","), table.concat(declared, ","))
            )
        end
    else
        local b = RaceCourse.DevBounds
        for _, p in built.Path do
            if p.X < b.MinX or p.X > b.MaxX or p.Z < b.MinZ or p.Z > b.MaxZ then
                table.insert(errors, "OutsideDevZone")
                break
            end
        end
    end
    return errors
end

--[[
    Distance d'un point au tracé, recherchée autour de l'indice `hint`
    (progression connue) puis, si elle paraît grande, sur tout le tracé.
    Renvoie (distance, indice du segment, distance le long du tracé).
]]
function RaceCourse.nearest(built: Built, x: number, z: number, hint: number?): (number, number, number)
    local path, along = built.Path, built.Along
    local best, bestIndex, bestAlong = math.huge, 1, 0
    local function scan(from: number, to: number)
        for i = math.max(2, from), math.min(#path, to) do
            local a, b = path[i - 1], path[i]
            local abx, abz = b.X - a.X, b.Z - a.Z
            local len2 = abx * abx + abz * abz
            local t = if len2 > 0 then math.clamp(((x - a.X) * abx + (z - a.Z) * abz) / len2, 0, 1) else 0
            local px, pz = a.X + abx * t, a.Z + abz * t
            local d = math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
            if d < best then
                best, bestIndex = d, i
                bestAlong = along[i - 1] + (along[i] - along[i - 1]) * t
            end
        end
    end
    local center = hint or 2
    scan(center - 60, center + 60)
    if best > built.RoadHalfWidthM * 4 + 20 then
        scan(2, #path)
    end
    return best, bestIndex, bestAlong
end

-- Point d'un segment [a, b] le plus proche d'un point c : (fraction 0..1, distance).
function RaceCourse.closestOnSegment(
    ax: number,
    az: number,
    bx: number,
    bz: number,
    cx: number,
    cz: number
): (number, number)
    local abx, abz = bx - ax, bz - az
    local len2 = abx * abx + abz * abz
    local t = if len2 > 0 then math.clamp(((cx - ax) * abx + (cz - az) * abz) / len2, 0, 1) else 0
    local px, pz = ax + abx * t, az + abz * t
    return t, math.sqrt((cx - px) ^ 2 + (cz - pz) ^ 2)
end

-- Parcours construits d'une place (seuls les parcours valides).
function RaceCourse.buildPlace(place: string): ({ [string]: Built }, { [string]: { string } })
    local built: { [string]: Built } = {}
    local problems: { [string]: { string } } = {}
    for _, course in RaceCourses.forPlace(place) do
        local errors = RaceCourse.validate(course)
        if #errors == 0 then
            built[course.Id] = (RaceCourse.build(course)) :: Built
        else
            problems[course.Id] = errors
        end
    end
    return built, problems
end

return table.freeze(RaceCourse)
