--!strict
--[[
    Génération SERVEUR des missions des huit métiers (lot 0.5), PURE et
    déterministe pour un tirage donné (`roll` fourni). Le client ne choisit que
    le métier : itinéraire, difficulté, délais et références sont décidés ici.

    Estimation de durée : distance × 1,3 (détours routiers) / vitesse moyenne
    retenue, plus les arrêts. C'est elle qui fonde la rémunération.
]]

local MissionPlaces = require(script.Parent.MissionPlaces)

local Shared = script.Parent.Parent.Parent.Parent.ReplicatedStorage.Shared
local Jobs = require(Shared.Economy.Jobs)

local MissionGenerator = {}

MissionGenerator.RouteFactor = 1.3
-- Références des essais (véhicule d'essai fourni : prototype P-01, mesures du lot 0.2).
MissionGenerator.TestTargets = table.freeze({ Accel0100 = 9.5, Brake = 45 })

type Point = MissionPlaces.Point

local function dist(a: Point, b: Point): number
    return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2)
end

-- Point de la liste dans un anneau [min ; max] autour de `from` (tirage).
local function pick(points: { Point }, from: Point, min: number, max: number, roll: () -> number): Point?
    local candidates = {}
    for _, p in points do
        local d = dist(p, from)
        if d >= min and d <= max then
            table.insert(candidates, p)
        end
    end
    if #candidates == 0 then
        return nil
    end
    return candidates[math.clamp(math.floor(roll() * #candidates) + 1, 1, #candidates)]
end

local function nearest(points: { Point }, from: Point): Point
    local best, bestD = points[1], math.huge
    for _, p in points do
        local d = dist(p, from)
        if d < bestD then
            best, bestD = p, d
        end
    end
    return best
end

local function key(job: string, a: Point, b: Point): string
    return string.format("%s:%d:%d>%d:%d", job, a.X // 50, a.Z // 50, b.X // 50, b.Z // 50)
end

--[[
    Mission d'un métier, ou nil + raison. `player` : position (m) du joueur ;
    `reputationLevel` : 1 à 5 (premium dès le niveau 2) ; `roll()` : tirage
    uniforme [0 ; 1[.
]]
function MissionGenerator.generate(
    jobId: string,
    id: string,
    userId: number,
    player: Point,
    places: MissionPlaces.Places,
    reputationLevel: number,
    roll: () -> number,
    now: number
): (any?, string?)
    local job = Jobs.get(jobId)
    if job == nil then
        return nil, "JobUnknown"
    end
    local range = places.Range
    local speed = places.SpeedMs
    local difficulty = 1 + math.floor(roll() * 3)
    local steps: { any } = {}
    local hazards = {}
    local distanceM = 0
    local holds = 0
    local routeKey = jobId
    local fragile = false
    local premium = false
    local targets: any = nil
    local start = nearest(places.Road, player)

    if jobId == "Taxi" or jobId == "SpecialParts" or jobId == "Convoy" then
        local pickup = pick(places.Road, player, 0, range.Near, roll) or start
        local destination = pick(places.Road, pickup, range.Min, range.Max, roll)
        if destination == nil then
            return nil, "NoDestination"
        end
        if jobId == "Convoy" then
            -- Le véhicule fourni est remis sur place : seul le trajet compte.
            table.insert(
                steps,
                { Kind = "Park", Point = destination, Radius = 4, Hold = 3, Label = "Garer le véhicule confié" }
            )
            distanceM = dist(player, destination)
            holds = 3
        else
            table.insert(steps, {
                Kind = "Stop",
                Point = pickup,
                Radius = 10,
                Hold = 3,
                Label = if jobId == "Taxi" then "Prendre le passager" else "Charger la pièce",
            })
            table.insert(steps, {
                Kind = "Stop",
                Point = destination,
                Radius = 10,
                Hold = 3,
                Label = if jobId == "Taxi" then "Déposer le passager" else "Livrer la pièce",
            })
            distanceM = dist(player, pickup) + dist(pickup, destination)
            holds = 6
        end
        routeKey = key(jobId, pickup, destination)
        fragile = jobId == "SpecialParts"
        premium = jobId == "Taxi" and reputationLevel >= 2 and roll() < 0.35
    elseif jobId == "Delivery" then
        local current = pick(places.Road, player, 0, range.Near, roll) or start
        table.insert(steps, { Kind = "Stop", Point = current, Radius = 10, Hold = 3, Label = "Récupérer les colis" })
        distanceM = dist(player, current)
        local first = current
        for n = 1, 1 + difficulty do
            local nextPoint = pick(places.Road, current, range.Min * 0.4, range.Max * 0.5, roll)
            if nextPoint == nil then
                break
            end
            table.insert(steps, { Kind = "Stop", Point = nextPoint, Radius = 10, Hold = 3, Label = "Livraison " .. n })
            distanceM += dist(current, nextPoint)
            current = nextPoint
        end
        if #steps < 2 then
            return nil, "NoDestination"
        end
        holds = 3 * #steps
        routeKey = key(jobId, first, current)
    elseif jobId == "Assistance" then
        local breakdown = pick(places.Road, player, range.Near * 0.5, range.Max * 0.6, roll)
        if breakdown == nil then
            return nil, "NoDestination"
        end
        table.insert(
            steps,
            { Kind = "Stop", Point = breakdown, Radius = 18, Hold = 2, Label = "Rejoindre le véhicule en panne" }
        )
        table.insert(steps, { Kind = "OnFoot", Point = breakdown, Radius = 8, Hold = 6, Label = "Intervenir à pied" })
        distanceM = dist(player, breakdown)
        holds = 10
        routeKey = key(jobId, start, breakdown)
    elseif jobId == "Precision" then
        local course = places.Course
        for index, gate in course.Gates do
            table.insert(steps, { Kind = "Pass", Point = gate, Radius = 4, Label = "Porte " .. index })
        end
        for _, cone in course.Hazards do
            table.insert(hazards, { Point = cone, Radius = 1.2 })
        end
        table.insert(steps, {
            Kind = "Park",
            Point = course.Park,
            Radius = 1.5,
            Hold = 2,
            Heading = course.ParkHeading,
            Tolerance = 12,
            Label = "Stationnement final",
        })
        distanceM = dist(player, course.Gates[1]) + dist(course.Gates[1], course.Park)
        holds = 20 -- manœuvres lentes
        routeKey = "Precision:" .. places.Name
        difficulty = 2
    elseif jobId == "Exploration" then
        -- Premier point : le secteur tout-terrain le plus proche (on s'y rend
        -- par la route) ; les suivants s'enchaînent dans ce secteur.
        local current = nearest(places.Offroad, player)
        table.insert(steps, { Kind = "Pass", Point = current, Radius = 12, Label = "Entrée du secteur" })
        distanceM = dist(player, current)
        local count = 1 + difficulty
        for n = 1, count do
            local nextPoint = pick(places.Offroad, current, range.Min * 0.3, range.Max * 0.6, roll)
            if nextPoint == nil then
                break
            end
            table.insert(steps, { Kind = "Pass", Point = nextPoint, Radius = 12, Label = "Point d'exploration " .. n })
            distanceM += dist(current, nextPoint)
            current = nextPoint
        end
        if #steps == 0 then
            return nil, "NoDestination"
        end
        routeKey = key(jobId, start, current)
    elseif jobId == "Testing" then
        local strip = places.Strip
        table.insert(
            steps,
            { Kind = "Stop", Point = strip.Start, Radius = 8, Hold = 2, Label = "Se placer au départ" }
        )
        table.insert(steps, { Kind = "Accel", Label = "0 à 100 km/h" })
        table.insert(steps, { Kind = "Brake", Label = "Freinage depuis 90 km/h" })
        distanceM = dist(player, strip.Start) + strip.LengthM
        holds = 25
        targets = MissionGenerator.TestTargets
        routeKey = "Testing:" .. places.Name
    else
        return nil, "JobUnknown"
    end

    local estimated = distanceM * MissionGenerator.RouteFactor / speed + holds
    return {
        Id = id,
        Job = jobId,
        UserId = userId,
        Difficulty = difficulty,
        Premium = premium,
        Steps = steps,
        Hazards = hazards,
        TimeLimitS = math.max(estimated * 2.5, 120),
        EstimatedS = estimated,
        DistanceM = distanceM,
        RouteKey = routeKey,
        Fragile = fragile,
        VehicleRule = job.Vehicle,
        ProvidedVehicleId = nil,
        Targets = targets,
        CreatedAt = now,
    },
        nil
end

return table.freeze(MissionGenerator)
