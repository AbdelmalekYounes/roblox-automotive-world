--!strict
-- Lot 0.6 — courses, compétition et saisons : règles, chronométrage,
-- classement, réservations, récompenses et récupération, sur des
-- échantillons SYNTHÉTIQUES et l'adaptateur MÉMOIRE. Ne valide PAS la
-- conduite réelle, le matchmaking inter-serveurs, la persistance Roblox ni
-- les collisions sous latence (NON TESTÉ, docs/QA_BACKLOG.md).

local SERVER = "ServerScriptService.AutomotiveWorldServer."
local SHARED = "ReplicatedStorage.Shared."

return function(T: any, H: any)
    local RaceCourse = H.require(SERVER .. "Racing.RaceCourse")
    local RaceRules = H.require(SERVER .. "Racing.RaceRules")
    local RaceSession = H.require(SERVER .. "Racing.RaceSession")
    local RaceLobby = H.require(SERVER .. "Racing.RaceLobby")
    local RaceScoring = H.require(SERVER .. "Racing.RaceScoring")
    local DriftScoring = H.require(SERVER .. "Racing.DriftScoring")
    local RaceRewards = H.require(SERVER .. "Racing.RaceRewards")
    local RankedService = H.require(SERVER .. "Racing.RankedService")
    local SeasonService = H.require(SERVER .. "Racing.SeasonService")
    local RaceRecovery = H.require(SERVER .. "Racing.RaceRecovery")
    local RacePersistence = H.require(SERVER .. "Racing.RacePersistence")
    local MatchmakingService = H.require(SERVER .. "Racing.MatchmakingService")
    local VehicleRaceReservation = H.require(SERVER .. "Racing.VehicleRaceReservation")
    local ProfileSchema = H.require(SERVER .. "Persistence.ProfileSchema")
    local ProfileMigration = H.require(SERVER .. "Persistence.ProfileMigration")
    local ProfileRepository = H.require(SERVER .. "Persistence.ProfileRepository")
    local MemoryProfileRepository = H.require(SERVER .. "Persistence.MemoryProfileRepository")
    local ProfileSession = H.require(SERVER .. "Persistence.ProfileSession")
    local VehicleOwnership = H.require(SERVER .. "Progression.VehicleOwnership")
    local GarageRules = H.require(SERVER .. "Progression.GarageRules")
    local Customization = H.require(SERVER .. "Progression.Customization")
    local Commerce = H.require(SERVER .. "Economy.Commerce")
    local Wallet = H.require(SERVER .. "Economy.Wallet")
    local RaceCourses = H.require(SHARED .. "Racing.RaceCourses")
    local RaceDefinitions = H.require(SHARED .. "Racing.RaceDefinitions")
    local Seasons = H.require(SHARED .. "Racing.Seasons")
    local Reputation = H.require(SHARED .. "Economy.Reputation")
    local GarageModules = H.require(SHARED .. "Garage.GarageModules")
    local CosmeticCatalog = H.require(SHARED .. "Garage.CosmeticCatalog")
    local Definitions = H.require(SHARED .. "Vehicles.VehicleDefinitions")

    local DT = 0.1
    local NOW = Seasons.EpochUnix + 3 * 24 * 3600 -- en saison 1

    local function built(id: string): any
        local b, errors = RaceCourse.build(RaceCourses.get(id))
        T.equal(#errors, 0, id .. " : " .. table.concat(errors, ";"))
        return b
    end

    local function sampleAt(x: number, z: number, heading: number, speed: number, t: number, vehicleId: string): any
        return {
            T = t,
            X = x,
            Z = z,
            VX = math.sin(heading) * speed,
            VZ = -math.cos(heading) * speed,
            SpeedMs = speed,
            Heading = heading,
            InVehicle = true,
            VehicleId = vehicleId,
            Wear = 0,
            Corrected = false,
        }
    end

    --[[
        Pilote synthétique : immobile à sa place jusqu'à `departT`, puis suit
        le tracé à vitesse constante (boucle : modulo du tour) jusqu'à
        `untilT`. Renvoie les événements produits.
    ]]
    local function drive(
        session: any,
        userId: number,
        vehicleId: string,
        speed: number,
        fromT: number,
        departT: number,
        untilT: number,
        tweak: ((any, number) -> ())?
    ): { string }
        local b = session.Built
        local participant = session.Participants[userId]
        local anchor = participant.Progress.Anchor or b.Start
        local all: { string } = {}
        local t = fromT
        while t <= untilT do
            local sample
            if t < departT then
                sample = sampleAt(anchor.X, anchor.Z, b.Start.Heading, 0, t, vehicleId)
            else
                local s = speed * (t - departT)
                if b.Closed then
                    s = math.min(s, b.LengthM * b.Laps + 5)
                    local lap = s % b.LengthM
                    -- Juste après la ligne en fin de tour : point au-delà du départ.
                    local frame = RaceCourse.pointAt(b.Path, b.Along, lap)
                    sample = sampleAt(frame.X, frame.Z, frame.Heading, speed, t, vehicleId)
                else
                    local frame = RaceCourse.pointAt(b.Path, b.Along, math.min(s, b.LengthM))
                    local beyond = math.max(0, s - b.LengthM)
                    local fx, fz = math.sin(frame.Heading), -math.cos(frame.Heading)
                    sample = sampleAt(frame.X + fx * beyond, frame.Z + fz * beyond, frame.Heading, speed, t, vehicleId)
                end
            end
            if tweak then
                tweak(sample, t)
            end
            for _, e in RaceSession.observe(session, userId, sample) do
                table.insert(all, e)
            end
            RaceSession.tick(session, t)
            t += DT
        end
        return all
    end

    local function entry(userId: number, rating: number?): any
        return {
            UserId = userId,
            VehicleId = "V-" .. userId,
            ModelId = "wk_brio",
            Mode = "Protected",
            Rating = rating,
            MaxPlausibleKmh = 260,
        }
    end

    local function newSession(courseId: string, kind: string?, users: { number }, params: any?): any
        local p = params or {}
        local session = RaceSession.new({
            Id = "R-" .. courseId,
            Built = built(courseId),
            Kind = kind or "Official",
            CreatedAt = 0,
            OrganizerUserId = p.Organizer,
            Laps = p.Laps,
            RewardEligible = p.RewardEligible,
        })
        for _, userId in users do
            local ok, err = RaceSession.register(session, entry(userId, p.Ratings and p.Ratings[userId]), 0)
            T.truthy(ok, tostring(err))
        end
        return session
    end

    -- Profil avec un exemplaire sorti (conduit), dégâts antérieurs possibles.
    local function profileWithCar(userId: number, damaged: boolean?): (any, string)
        local profile = ProfileSchema.new(userId, NOW, "Dev")
        local definition = Definitions.get("wk_brio")
        local vehicleId = VehicleOwnership.add(profile, {
            ModelId = "wk_brio",
            Origin = "Purchase",
            Untransferable = false,
            Synthetic = false,
            EnergyFraction = 0.7,
            Cosmetics = CosmeticCatalog.defaults(definition),
            PaidPrice = 18_500,
        }, NOW)
        if damaged then
            local vehicle = profile.Vehicles[vehicleId]
            vehicle.Damage.Zones.Front = 0.4
            vehicle.Damage.Engine = 0.8
        end
        assert(GarageRules.takeOut(profile, vehicleId, "sess-1", NOW))
        return profile, vehicleId
    end

    local function reserveArgs(vehicleId: string, mode: string, entryId: string?): any
        return {
            EntryId = entryId or "E-1",
            RaceId = "R-1",
            CourseId = "DEV-SPRINT",
            Discipline = "Sprint",
            Kind = "Official",
            Mode = mode,
            VehicleId = vehicleId,
        }
    end

    local function context(overrides: any): any
        local base = {
            ResultId = "R-1:501",
            EntryId = "E-1",
            RaceId = "R-1",
            CourseId = "DEV-SPRINT",
            Discipline = "Sprint",
            Kind = "Official",
            Mode = "Protected",
            Outcome = "Finished",
            Position = 1,
            Field = 4,
            OfficialS = 30,
            Score = nil,
            ParTimeS = 30,
            ParScore = nil,
            TotalKm = 0.45,
            Difficulty = 1,
            RewardEligible = true,
            Conditions = "Sec-v1",
            RecordEligible = true,
            RecordKey = "DEV-SPRINT:v1:Sec-v1",
            Ranked = nil,
        }
        for key, value in overrides or {} do
            base[key] = value
        end
        return base
    end

    T.suite("Lot 0.6 — parcours versionnés et graphe routier")

    T.test("tous les parcours sont valides : routes enchaînées, longueur, zone, revêtements", function()
        local zones: { [string]: boolean } = {}
        local disciplines: { [string]: boolean } = {}
        for _, course in RaceCourses.All do
            local errors = RaceCourse.validate(course)
            T.equal(#errors, 0, course.Id .. " : " .. table.concat(errors, " ; "))
            if course.Place == "OpenWorld" then
                zones[course.Area or course.Zone] = true
            end
            disciplines[course.Discipline] = true
        end
        for _, zone in { "Motorsport", "Metropole", "Périphérique", "Montagnes", "Campagne", "Littoral" } do
            T.truthy(zones[zone], "épreuve dans " .. zone)
        end
        for _, id in RaceDefinitions.DisciplineOrder do
            T.truthy(disciplines[id], "discipline " .. id)
        end
    end)

    T.test("route inconnue, routes non enchaînées et boucle ouverte sont refusées", function()
        local course = table.clone(RaceCourses.get("CIR-MS-GP"))
        course.Roads = { { Id = "CIRCUIT-1" } }
        local errors = RaceCourse.validate(course)
        T.truthy(table.find(errors, "LoopNotClosed") ~= nil, table.concat(errors, ";"))
        course.Roads = { { Id = "CIRCUIT-1" }, { Id = "DRAG-1" } }
        local found = false
        for _, e in RaceCourse.validate(course) do
            found = found or string.find(e, "RoadsNotConnected", 1, true) ~= nil
        end
        T.truthy(found, "routes non enchaînées détectées")
        course.Roads = { { Id = "ROUTE-FANTOME" } }
        local unknown = false
        for _, e in RaceCourse.validate(course) do
            unknown = unknown or string.find(e, "UnknownRoad", 1, true) ~= nil
        end
        T.truthy(unknown, "route inconnue détectée")
    end)

    T.suite("Lot 0.6 — disciplines, départs et chronométrage")

    T.test("1. les six disciplines se courent jusqu'au résultat (place de développement)", function()
        for _, id in { "DEV-SPRINT", "DEV-CIRCUIT", "DEV-TT", "DEV-DRAG", "DEV-RALLY" } do
            local session = newSession(id, "Official", { 501 })
            RaceSession.lock(session, 10)
            local p = session.Participants[501].Progress
            drive(session, 501, "V-501", 22, 10, p.StartT, p.StartT + 200)
            T.equal(p.Status, "Finished", id .. " : " .. tostring(p.Status) .. " " .. tostring(p.Reason))
            T.truthy(p.OfficialS and p.OfficialS > 0, id .. " temps officiel")
            T.equal(session.State, "Finished", id .. " épreuve close")
        end
        -- Drift : session de zone, terminée au bout de sa durée avec un score.
        local session = newSession("DEV-DRIFT", "Official", { 502 })
        RaceSession.lock(session, 10)
        local p = session.Participants[502].Progress
        local center = session.Built.DriftCenter
        local t = 10
        while t <= p.StartT + RaceDefinitions.Timing.DriftSessionS + 1 do
            local angle = t * 0.5
            local x, z = center.X + 20 * math.cos(angle), center.Z + 20 * math.sin(angle)
            local velocityHeading = math.atan2(-math.sin(angle), -math.cos(angle)) -- tangente
            local sample = sampleAt(x, z, velocityHeading - math.rad(35), 0, t, "V-502")
            sample.VX, sample.VZ = math.sin(velocityHeading) * 10, -math.cos(velocityHeading) * 10
            sample.SpeedMs = 10
            RaceSession.observe(session, 502, sample)
            RaceSession.tick(session, t)
            t += DT
        end
        T.equal(p.Status, "Finished", "drift terminé")
        T.truthy((p.Score or 0) > 0, "score de drift positif")
    end)

    T.test("2. points de contrôle ordonnés, tours, temps au tour et meilleur tour", function()
        local session = newSession("DEV-CIRCUIT", "Official", { 501 })
        RaceSession.lock(session, 10)
        local p = session.Participants[501].Progress
        drive(session, 501, "V-501", 20, 10, p.StartT, p.StartT + 120)
        T.equal(#p.LapTimes, 3, "trois tours")
        T.near(p.LapTimes[2], session.Built.LengthM / 20, 0.15, "tour lancé ≈ longueur / vitesse")
        T.equal(p.BestLapS, math.min(p.LapTimes[1], p.LapTimes[2], p.LapTimes[3]), "meilleur tour")
        -- Raccourci : couper directement vers l'arrivée ne valide rien.
        local cut = newSession("DEV-SPRINT", "Official", { 503 })
        RaceSession.lock(cut, 10)
        local q = cut.Participants[503].Progress
        local b = cut.Built
        local t = 10
        while t < q.StartT + 40 do
            local f = math.clamp((t - q.StartT) / 30, 0, 1)
            local x = b.Start.X + (b.Finish.X - b.Start.X) * f
            local z = b.Start.Z + (b.Finish.Z - b.Start.Z) * f
            local h = RaceCourse.heading(b.Finish.X - b.Start.X, b.Finish.Z - b.Start.Z)
            RaceSession.observe(cut, 503, sampleAt(x, z, h, if t < q.StartT then 0 else 15, t, "V-503"))
            t += DT
        end
        T.truthy(q.Status ~= "Finished", "raccourci : arrivée non validée")
        T.truthy(q.Next < #b.Checkpoints, "points intermédiaires toujours dus")
    end)

    T.test("2 bis. rallye : point manqué pénalisé, hors tracé pénalisé et plafonné", function()
        local session = newSession("DEV-RALLY", "Official", { 504 })
        RaceSession.lock(session, 10)
        local p = session.Participants[504].Progress
        local b = session.Built
        -- Écart latéral de 30 m pendant 6 s (hors couloir de 16 m) puis retour.
        drive(session, 504, "V-504", 18, 10, p.StartT, p.StartT + 80, function(sample, t)
            local since = t - p.StartT
            if since > 5 and since < 11 then
                local rx, rz = math.cos(sample.Heading), math.sin(sample.Heading)
                sample.X += rx * 30
                sample.Z += rz * 30
            end
        end)
        T.equal(p.Status, "Finished", "spéciale terminée")
        local off = 0
        local missed = 0
        for _, penalty in p.Penalties do
            if penalty.Reason == "OffCourse" then
                off += penalty.Seconds
            elseif penalty.Reason == "MissedCheckpoint" then
                missed += penalty.Seconds
            end
        end
        T.between(off, 2, 3.5, "≈ (6 s − 3 s de tolérance) × 1 s/s")
        T.truthy(missed == 0 or missed % 30 == 0, "pénalité de point manqué par multiples de 30 s")
        T.near(p.OfficialS, p.ElapsedS + p.PenaltyS, 1e-9, "temps officiel = écoulé + pénalités")
        T.truthy(b.Checkpoints[1] ~= nil, "points de contrôle présents")
    end)

    T.test(
        "3. faux départs : pénalité sur la grille, manche perdue au drag ; retardataire sans pénalité",
        function()
            local grid = newSession("DEV-SPRINT", "Official", { 505, 506 })
            RaceSession.lock(grid, 10)
            local p = grid.Participants[505].Progress
            -- Placé puis parti 1 s avant le feu vert.
            drive(grid, 505, "V-505", 20, 10, p.StartT - 1, p.StartT + 60)
            T.truthy(p.FalseStart, "faux départ détecté")
            T.equal(p.Penalties[1].Reason, "FalseStart", "pénalité de faux départ")
            T.equal(p.Penalties[1].Seconds, RaceDefinitions.Disciplines.Sprint.FalseStartPenaltyS, "5 s")
            local drag = newSession("DEV-DRAG", "Official", { 507 })
            RaceSession.lock(drag, 10)
            local d = drag.Participants[507].Progress
            drive(drag, 507, "V-507", 20, 10, d.StartT - 0.5, d.StartT + 30)
            T.equal(d.Status, "Disqualified", "feu rouge")
            T.equal(d.Reason, "FalseStart", "raison")
            -- Retardataire : jamais placé, part 8 s après le départ : aucune pénalité, temps depuis le départ officiel.
            local late = newSession("DEV-SPRINT", "Official", { 508 })
            RaceSession.lock(late, 10)
            local l = late.Participants[508].Progress
            l.Anchor = { X = 1000, Z = 1000 } -- loin de sa place : jamais « placé »
            drive(late, 508, "V-508", 20, l.StartT, l.StartT + 8, l.StartT + 60)
            T.equal(l.Status, "Finished", "retardataire arrivé")
            T.equal(l.PenaltyS, 0, "aucune pénalité")
            T.truthy(l.ElapsedS > 8 + 20, "les 8 s de retard comptent")
        end
    )

    T.test("4. départs synchronisés (grille), espacés (individuels) et feu vert (drag)", function()
        local grid = newSession("DEV-SPRINT", "Official", { 511, 512, 513 })
        local plan = RaceSession.lock(grid, 100)
        T.equal(plan[1].StartT, plan[2].StartT, "même instant")
        T.equal(
            plan[1].StartT,
            100 + RaceDefinitions.Timing.GridS + RaceDefinitions.Timing.CountdownS,
            "instant serveur"
        )
        T.truthy(grid.Participants[512].Progress.Anchor ~= nil, "place de grille attribuée")
        T.truthy(not RaceSession.register(grid, entry(514), 101), "inscriptions fermées après verrouillage")
        local tt = newSession("DEV-TT", "Official", { 521, 522, 523 })
        local spaced = RaceSession.lock(tt, 100)
        T.equal(spaced[2].StartT - spaced[1].StartT, RaceDefinitions.Timing.IndividualIntervalS, "départs espacés")
        T.equal(spaced[3].StartT - spaced[2].StartT, RaceDefinitions.Timing.IndividualIntervalS, "départs espacés")
        -- Avant son départ, aucun participant ne roule (chronomètre arrêté).
        local events = RaceSession.observe(tt, 522, sampleAt(0, 0, 0, 0, spaced[1].StartT + 1, "V-522"))
        T.equal(#events, 0, "pas de départ avant son instant")
        T.equal(tt.Participants[522].Progress.Status, "Waiting", "en attente")
    end)

    T.test("5. temps officiel interpolé entre deux échantillons, référence serveur", function()
        local session = newSession("DEV-DRAG", "Official", { 531 })
        RaceSession.lock(session, 10)
        local p = session.Participants[531].Progress
        drive(session, 531, "V-531", 25, 10, p.StartT + 0.3, p.StartT + 20)
        T.equal(p.Status, "Finished", "manche terminée")
        -- 201 m à 25 m/s après 0,3 s de réaction : 8,34 s (interpolé, pas un multiple de 0,1 s).
        T.near(p.ElapsedS, 0.3 + 201 / 25, 0.02, "temps écoulé")
        T.between(p.ReactionS, 0.3, 0.45, "temps de réaction (franchissement de la ligne)")
        T.near(p.TrapSpeedKmh, 90, 0.5, "vitesse à l'arrivée")
        local s = newSession("DEV-SPRINT", "Official", { 532 })
        RaceSession.lock(s, 10)
        local q = s.Participants[532].Progress
        drive(s, 532, "V-532", 20, 10, q.StartT, q.StartT + 40)
        T.near(q.ElapsedS, s.Built.LengthM / 20, 0.02, "sprint : longueur / vitesse")
    end)

    T.suite("Lot 0.6 — drift")

    local function driftRun(params: any): any
        local state = DriftScoring.new()
        local t = 0
        local wear = 0
        for i = 1, params.Steps or 100 do
            local heading = params.Heading and params.Heading(i) or 0
            local slip = params.Slip and params.Slip(i) or 35
            local speed = params.Speed or 12
            local vh = heading + math.rad(slip)
            if params.WearAt and i == params.WearAt then
                wear += 0.1
            end
            DriftScoring.observe(state, {
                T = t,
                X = 0,
                Z = 0,
                VX = math.sin(vh) * speed,
                VZ = -math.cos(vh) * speed,
                Heading = heading,
                Wear = wear,
                Corrected = false,
            }, if params.OutAt then i < params.OutAt else true)
            t += DT
        end
        return state
    end

    T.test("6. score de drift fondé sur la dérive et la vitesse ; rotation à l'arrêt = 0", function()
        local good = driftRun({ Steps = 100 })
        local goodScore = DriftScoring.finish(good)
        T.truthy(goodScore > 500, "dérive de 35° à 43 km/h pendant 10 s : " .. goodScore)
        T.near(good.DriftDistanceM, 12 * 9.9, 1.5, "distance en dérive")
        -- Rotation sur place : la caisse tourne, la vitesse est quasi nulle.
        local spin = DriftScoring.finish(driftRun({
            Steps = 100,
            Speed = 1,
            Heading = function(i)
                return i * 0.5
            end,
        }))
        T.equal(spin, 0, "rotation à l'arrêt")
        -- Sur-rotation (angle de 95°) : aucun point.
        T.equal(
            DriftScoring.finish(driftRun({
                Slip = function()
                    return 95
                end,
            })),
            0,
            "sur-rotation"
        )
        -- Enchaînement gauche-droite : multiplicateur.
        local chain = driftRun({
            Steps = 100,
            Slip = function(i)
                return if math.floor(i / 20) % 2 == 0 then 35 else -35
            end,
        })
        T.truthy(chain.Multiplier > 1, "enchaînement")
        T.truthy(DriftScoring.finish(chain) > goodScore, "enchaînement mieux payé")
    end)

    T.test("6 bis. rupture : collision ou sortie de zone font perdre la figure en cours", function()
        local clean = DriftScoring.finish(driftRun({ Steps = 100 }))
        local crash = driftRun({ Steps = 100, WearAt = 90 })
        T.truthy(DriftScoring.finish(crash) < clean * 0.15, "figure de 9 s perdue au choc (seule la suivante compte)")
        T.equal(crash.Breaks.Collision, 1, "rupture comptée")
        local out = driftRun({ Steps = 100, OutAt = 80 })
        T.equal(DriftScoring.finish(out), 0, "figure perdue hors zone")
        T.equal(out.Breaks.OutOfZone, 1, "sortie comptée")
    end)

    T.suite("Lot 0.6 — classement, abandons, validation")

    T.test("7. classement de plusieurs participants (temps, pénalités, non confirmés)", function()
        local session = newSession("DEV-SPRINT", "Official", { 541, 542, 543, 544 })
        RaceSession.lock(session, 10)
        local start = session.StartT
        drive(session, 541, "V-541", 21, 10, start, start + 40)
        drive(session, 542, "V-542", 23, 10, start, start + 40)
        drive(session, 543, "V-543", 25, 10, start, start + 40, function(sample)
            sample.Corrected = sample.T > start + 5 and sample.T < start + 5.15 -- correction serveur
        end)
        drive(session, 544, "V-544", 22, 10, start - 1, start + 40) -- faux départ (+5 s)
        local c = RaceSession.classification(session)
        T.equal(c.Entries[1].UserId, 542, "1er : le plus rapide confirmé")
        T.equal(c.Entries[1].Position, 1, "place 1")
        T.equal(c.Entries[2].UserId, 541, "2e : 541 (544 pénalisé de 5 s)")
        T.equal(c.Entries[3].UserId, 544, "3e : faux départ")
        T.equal(c.Entries[4].Outcome, "Unconfirmed", "correction de mouvement : non confirmé")
        T.equal(c.Entries[4].Position, nil, "sans place")
        T.equal(c.Confirmed, 3, "trois arrivées confirmées")
    end)

    T.test("8. abandon : sans place ni crédit, compté comme battu au classement", function()
        local session = newSession("DEV-SPRINT", "Ranked", { 551, 552 })
        RaceSession.lock(session, 10)
        local start = session.StartT
        drive(session, 551, "V-551", 20, 10, start, start + 5)
        T.truthy(RaceSession.abandon(session, 552), "abandon accepté")
        drive(session, 551, "V-551", 20, start + 5.1, start, start + 40)
        local c = RaceSession.classification(session)
        T.equal(c.Entries[2].Outcome, "Abandoned", "abandon")
        local deltas = RankedService.deltas(c, "Race", { [551] = 1000, [552] = 1000 }, nil)
        T.truthy(deltas[551].Delta > 0 and deltas[552].Delta < 0, "abandon = défaite classée")
        local profile = ProfileSchema.new(552, NOW, "Dev")
        local quote = RaceRewards.quote(profile, context({ Outcome = "Abandoned", Position = nil }), NOW)
        T.equal(quote.Credits, 0, "aucun crédit")
    end)

    T.suite("Lot 0.6 — réservation exclusive et modes")

    T.test("9. réservation exclusive : une seule course, véhicule sorti, annonce refusée", function()
        local profile, vehicleId = profileWithCar(601)
        local ok, result = VehicleRaceReservation.reserve(profile, reserveArgs(vehicleId, "Realistic"), NOW)
        T.truthy(ok, tostring(result))
        local vehicle = profile.Vehicles[vehicleId]
        T.equal(vehicle.Reservation.Kind, "Race", "réservation « Race »")
        T.equal(vehicle.Reservation.TxId, "E-1", "identifiant d'engagement")
        T.truthy(vehicle.Reservation.ExpiresAt > NOW + RaceDefinitions.Timing.MaxRaceS, "durée sûre")
        local again, err = VehicleRaceReservation.reserve(profile, reserveArgs(vehicleId, "Realistic", "E-2"), NOW)
        T.truthy(not again and err == "RaceAlreadyEngaged", "deuxième engagement refusé")
        T.truthy(
            (VehicleRaceReservation.reserve(profile, reserveArgs(vehicleId, "Realistic"), NOW)),
            "même engagement : idempotent"
        )
        local valid, errors = ProfileSchema.validate(profile)
        T.truthy(valid, table.concat(errors, ";"))
        -- Exemplaire rangé : refusé (départ physique uniquement).
        local stored = ProfileSchema.new(602, NOW, "Dev")
        local id = VehicleOwnership.add(stored, {
            ModelId = "wk_brio",
            Origin = "Purchase",
            Untransferable = false,
            Synthetic = false,
            EnergyFraction = 1,
            Cosmetics = {},
        }, NOW)
        T.equal(
            select(2, VehicleRaceReservation.reserve(stored, reserveArgs(id, "Protected"), NOW)),
            "VehicleNotOut",
            "non sorti"
        )
        -- Exemplaire en annonce : refusé.
        stored.Vehicles[id].Storage = { State = "Out", Session = "s" }
        VehicleOwnership.reserve(stored, id, "Listing", "L-1", NOW, 3600)
        T.equal(
            select(2, VehicleRaceReservation.reserve(stored, reserveArgs(id, "Protected"), NOW)),
            "VehicleListed",
            "en annonce"
        )
    end)

    T.test("10. pendant la course : vente, reprise, annonce, préparation, réparation, rangement refusés", function()
        local profile, vehicleId = profileWithCar(611, true)
        assert(VehicleRaceReservation.reserve(profile, reserveArgs(vehicleId, "Realistic"), NOW))
        local caps = GarageModules.publicCapabilities()
        local definition = Definitions.get("wk_brio")
        T.equal(select(2, Commerce.tradeInQuote(profile, vehicleId, NOW)), "VehicleReserved", "reprise")
        T.equal(
            Commerce.transferable(profile.Vehicles[vehicleId], NOW),
            "VehicleReserved",
            "vente / annonce / transfert"
        )
        T.equal(
            select(2, Customization.setPart(profile, vehicleId, "Tires", "TIRE-SPORT", definition, caps, NOW)),
            "VehicleReserved",
            "pièces"
        )
        T.equal(
            select(2, Customization.setTuning(profile, vehicleId, {}, definition, caps, NOW)),
            "VehicleReserved",
            "réglages"
        )
        T.equal(select(2, Commerce.repair(profile, vehicleId, NOW)), "VehicleInRace", "réparation")
        T.equal(select(2, Commerce.wash(profile, vehicleId, NOW)), "VehicleInRace", "lavage")
        T.equal(
            select(2, Commerce.startEnergy(profile, "S-1", vehicleId, "Petrol", 10, NOW)),
            "VehicleInRace",
            "énergie"
        )
        T.equal(select(2, GarageRules.store(profile, vehicleId, NOW)), "VehicleReserved", "rangement")
        T.equal(select(2, GarageRules.takeOut(profile, vehicleId, "sess-2", NOW)), "VehicleReserved", "seconde sortie")
    end)

    T.test("11. mode protégé : état initial restauré EXACTEMENT, dégâts antérieurs conservés", function()
        local profile, vehicleId = profileWithCar(621, true)
        local vehicle = profile.Vehicles[vehicleId]
        local before = ProfileMigration.deepCopy(vehicle)
        assert(VehicleRaceReservation.reserve(profile, reserveArgs(vehicleId, "Protected"), NOW))
        -- Course : dégâts, énergie, kilomètres (même si une écriture avait lieu).
        vehicle.Damage.Zones.Rear = 0.9
        vehicle.Damage.Engine = 0.3
        vehicle.Energy = 0.1
        vehicle.OdometerKm += 12
        local ok, info = VehicleRaceReservation.release(profile, "E-1", NOW + 100)
        T.truthy(ok, "libération")
        T.equal(vehicle.Damage.Zones.Rear, before.Damage.Zones.Rear, "dégâts de course effacés")
        T.equal(vehicle.Damage.Zones.Front, 0.4, "dégât antérieur conservé (pas de réparation gratuite)")
        T.equal(vehicle.Damage.Engine, 0.8, "moteur : état d'avant-course")
        T.equal(vehicle.Energy, before.Energy, "énergie restaurée")
        T.equal(vehicle.OdometerKm, before.OdometerKm, "kilométrage restauré")
        T.equal(vehicle.Reservation, nil, "réservation libérée")
        T.equal(profile.Racing.Active, nil, "engagement clos")
        T.truthy(info.Restored ~= nil, "état restauré renvoyé (véhicule matérialisé)")
        T.truthy((VehicleRaceReservation.release(profile, "E-1", NOW + 101)), "libération idempotente")
    end)

    T.test("12. mode réaliste : dégâts et consommation de course persistent", function()
        local profile, vehicleId = profileWithCar(631)
        local vehicle = profile.Vehicles[vehicleId]
        assert(VehicleRaceReservation.reserve(profile, reserveArgs(vehicleId, "Realistic"), NOW))
        T.equal(profile.Racing.Active.Snapshot, nil, "aucun instantané en mode réaliste")
        vehicle.Damage.Zones.Left = 0.5
        vehicle.Energy = 0.2
        VehicleRaceReservation.release(profile, "E-1", NOW + 100)
        T.equal(vehicle.Damage.Zones.Left, 0.5, "dégâts conservés")
        T.equal(vehicle.Energy, 0.2, "consommation conservée")
        T.equal(vehicle.Reservation, nil, "libéré")
    end)

    T.suite("Lot 0.6 — récompenses et idempotence")

    T.test("13. les deux modes officiels rapportent ; le réaliste couvre ses coûts estimés", function()
        local profile = ProfileSchema.new(641, NOW, "Dev")
        local protected = RaceRewards.quote(profile, context({ Mode = "Protected" }), NOW)
        local realistic = RaceRewards.quote(profile, context({ Mode = "Realistic" }), NOW)
        T.truthy(protected.Credits > 0, "protégé rémunéré")
        T.truthy(realistic.Credits > protected.Credits, "réaliste : brut plus élevé")
        local discipline = RaceDefinitions.Disciplines.Sprint
        local expectedCost = (RaceDefinitions.EnergyCostPerKm + discipline.WearCostPerKm) * 0.45
        T.near(
            realistic.Credits - expectedCost,
            protected.Credits,
            2,
            "net réaliste ≈ protégé à conditions égales"
        )
        -- Performance : rouler lentement ne paie pas plus (minutes de référence).
        local slow = RaceRewards.quote(profile, context({ OfficialS = 120, Position = 4 }), NOW)
        T.truthy(slow.Credits < protected.Credits, "lent et dernier : moins payé")
    end)

    T.test("14. entraînement : aucun crédit ; privée : seulement si éligible, faible et plafonnée", function()
        local profile = ProfileSchema.new(651, NOW, "Dev")
        T.equal(RaceRewards.quote(profile, context({ Kind = "Training" }), NOW).Credits, 0, "entraînement")
        T.equal(
            RaceRewards.quote(profile, context({ Kind = "Private", RewardEligible = false }), NOW).Credits,
            0,
            "privée non éligible"
        )
        local official = RaceRewards.quote(profile, context({}), NOW).Credits
        local private = RaceRewards.quote(profile, context({ Kind = "Private" }), NOW).Credits
        T.truthy(private > 0 and private <= official * 0.25, "privée éligible : faible")
        -- Plafond horaire des privées (3) : la 4e ne paie plus.
        for i = 1, 3 do
            assert(
                RaceRewards.payout(profile, context({ Kind = "Private", ResultId = "P" .. i, EntryId = nil }), NOW + i)
            )
        end
        local capped = RaceRewards.quote(profile, context({ Kind = "Private" }), NOW + 10)
        T.truthy(capped.Credits == 0 and capped.Capped, "plafond horaire")
        -- Session d'entraînement : toujours protégée.
        local training = newSession("DEV-SPRINT", "Training", {}, { Organizer = 651 })
        local e = entry(652)
        e.Mode = "Realistic"
        assert(RaceSession.register(training, e, 0))
        T.equal(training.Participants[652].Mode, "Protected", "entraînement protégé")
    end)

    -- Monde de test : stockage mémoire, sessions de profil, horloge.
    local function world()
        local clock = { Now = NOW }
        local counter = 0
        local repo = MemoryProfileRepository.new()
        local function token(): string
            counter += 1
            return "tok-" .. counter
        end
        local function session(userId: number): any
            local s = ProfileSession.new({
                Repository = repo,
                Key = ProfileRepository.keyFor(userId),
                UserId = userId,
                Session = token(),
                Server = "srv",
                Environment = "Dev",
                Clock = function()
                    return clock.Now
                end,
                Token = token,
                MinWriteInterval = 0,
                OnLoaded = function(profile, now)
                    return RaceRecovery.recover(profile, now)
                end,
            })
            s:load()
            return s
        end
        return clock, repo, session
    end

    T.test("15. paiement idempotent : rejoué, perdu en réponse ou après purge du journal", function()
        local clock, repo, session = world()
        local s = session(661)
        local vehicleId: string = ""
        s:commit("seed", "Seed", function(profile)
            vehicleId = VehicleOwnership.add(profile, {
                ModelId = "wk_brio",
                Origin = "Purchase",
                Untransferable = false,
                Synthetic = false,
                EnergyFraction = 0.6,
                Cosmetics = {},
            }, clock.Now)
            return GarageRules.takeOut(profile, vehicleId, "sess", clock.Now)
        end)
        s:commit("RaceJoin:E-1", "RaceJoin", function(profile)
            return VehicleRaceReservation.reserve(profile, reserveArgs(vehicleId, "Protected"), clock.Now)
        end)
        local ctx = context({ ResultId = "R-1:661" })
        local first = s:commit("Race:R-1:661", "Race", function(profile)
            return RaceRewards.payout(profile, ctx, clock.Now)
        end)
        T.equal(first.Status, "Confirmed", "versement confirmé")
        local balance = s.Data.Wallet.Balance
        T.truthy(balance > 0, "crédité")
        local again = s:commit("Race:R-1:661", "Race", function(profile)
            return RaceRewards.payout(profile, ctx, clock.Now)
        end)
        T.equal(again.Status, "Duplicate", "rejoué : doublon")
        -- Journal des transactions purgé : la garde durable Racing.Applied tient.
        s.Data.Transactions = {}
        local third = s:commit("Race:R-1:661", "Race", function(profile)
            return RaceRewards.payout(profile, ctx, clock.Now)
        end)
        T.truthy(third.Status == "Confirmed" and third.Result.Duplicate, "garde durable")
        T.equal(s.Data.Wallet.Balance, balance, "un seul versement")
        -- Réponse perdue (écriture appliquée) : la relecture ne rejoue pas.
        local s2 = session(662)
        s2:commit("seed", "Seed", function(_profile)
            return true, nil
        end)
        repo:inject("UncertainApplied")
        s2:commit("Race:R-2:662", "Race", function(profile)
            return RaceRewards.payout(profile, context({ ResultId = "R-2:662", EntryId = nil }), clock.Now)
        end)
        s2:save(true)
        local reloaded = session(662)
        local credited = reloaded.Data.Wallet.Balance
        reloaded:commit("Race:R-2:662", "Race", function(profile)
            return RaceRewards.payout(profile, context({ ResultId = "R-2:662", EntryId = nil }), clock.Now)
        end)
        T.equal(reloaded.Data.Wallet.Balance, credited, "aucun double versement après réponse incertaine")
    end)

    T.suite("Lot 0.6 — classement compétitif et saisons")

    T.test("16. points et rangs classés séparés de la réputation générale", function()
        local profile = ProfileSchema.new(671, NOW, "Dev")
        profile.Reputation.Points = 600
        local result = RaceRewards.payout(
            profile,
            context({
                Kind = "Ranked",
                EntryId = nil,
                Ranked = { Ladder = "Race", Delta = { Delta = 15, Opponents = { 672 } }, Won = true },
            }),
            NOW
        )
        T.truthy(result, "versement")
        T.equal(profile.Reputation.Points, 600, "réputation inchangée")
        T.equal(profile.Racing.Ranked.Ladders.Race.Points, 1015, "points classés")
        local rankNames, levelNames = {}, {}
        for _, rank in Seasons.Ranks do
            table.insert(rankNames, rank.Name)
        end
        for _, level in Reputation.Levels do
            table.insert(levelNames, level.Name)
        end
        T.equal(table.concat(rankNames, ","), "Bronze,Argent,Or,Platine,Diamant", "cinq rangs de compétition")
        for _, name in rankNames do
            T.truthy(table.find(levelNames, name) == nil, "aucun nom commun avec la réputation : " .. name)
        end
        -- Anti-arrangement : gains répétés face au même adversaire réduits, jamais négatifs.
        local gains = {}
        for i = 1, 8 do
            local applied = RankedService.apply(profile, "Race", { Delta = 16, Opponents = { 672 } }, true, NOW + i)
            table.insert(gains, applied)
        end
        T.equal(gains[1], 16, "1re répétition : plein gain")
        T.truthy(gains[8] < gains[1] and gains[8] > 0, "répétitions : gain réduit mais positif")
    end)

    T.test("17. transition de saison : archive, récompense unique, réinitialisation douce", function()
        local profile = ProfileSchema.new(681, NOW, "Dev")
        SeasonService.transition(profile, NOW)
        T.equal(profile.Racing.Ranked.Season, 1, "saison 1")
        local ladder = RankedService.ladderOf(profile, "Race")
        ladder.Points = 1500
        ladder.Played = 12
        local nextSeason = Seasons.EpochUnix + Seasons.LengthS + 10
        local changed, archived = SeasonService.transition(profile, nextSeason)
        T.truthy(changed, "transition")
        T.equal(profile.Racing.Ranked.Season, 2, "saison 2")
        T.equal(archived[1].Rank, "Platine", "rang final archivé")
        T.equal(profile.Racing.Ranked.History[1].Points, 1500, "historique")
        T.equal(profile.Wallet.Balance, RaceDefinitions.SeasonRewards.ByRank[4], "récompense de rang Platine")
        T.equal(ladder.Points, 1250, "réinitialisation de moitié vers 1000")
        T.equal(ladder.Played, 0, "compteur remis à zéro")
        local again = SeasonService.transition(profile, nextSeason + 60)
        T.truthy(not again, "aucune seconde transition")
        T.equal(profile.Wallet.Balance, RaceDefinitions.SeasonRewards.ByRank[4], "récompense versée une fois")
        -- Trop peu d'épreuves : archivé, sans récompense.
        local casual = ProfileSchema.new(682, NOW, "Dev")
        SeasonService.transition(casual, NOW)
        RankedService.ladderOf(casual, "Drift").Played = 3
        SeasonService.transition(casual, nextSeason)
        T.equal(casual.Wallet.Balance, 0, "pas de récompense sous le minimum")
    end)

    T.suite("Lot 0.6 — déconnexion et reprise")

    T.test("18. déconnexion avant les résultats : fenêtre, puis issue sans gain ni sanction", function()
        local session = newSession("DEV-SPRINT", "Ranked", { 691, 692, 693 })
        RaceSession.lock(session, 10)
        local start = session.StartT
        drive(session, 691, "V-691", 20, 10, start, start + 4)
        T.equal(RaceSession.disconnect(session, 693, start + 4), "Window", "fenêtre de reconnexion")
        drive(session, 691, "V-691", 20, start + 4.1, start, start + 30)
        drive(session, 692, "V-692", 18, 10, start, start + 40)
        RaceSession.tick(session, start + 4 + RaceDefinitions.Timing.ReconnectWindowS + 1)
        RaceSession.tick(session, start + 200)
        T.equal(session.State, "Finished", "épreuve close")
        local c = RaceSession.classification(session)
        local disconnected = nil
        for _, e in c.Entries do
            if e.UserId == 693 then
                disconnected = e
            end
        end
        T.equal(disconnected.Outcome, "Disconnected", "issue : déconnecté")
        local deltas = RankedService.deltas(c, "Race", {}, nil)
        T.equal(deltas[693], nil, "aucune variation classée (pas de sanction réseau)")
        T.truthy(deltas[691].Delta > 0, "les autres sont classés")
        local profile = ProfileSchema.new(693, NOW, "Dev")
        T.equal(RaceRewards.quote(profile, context({ Outcome = "Disconnected" }), NOW).Credits, 0, "aucun gain")
    end)

    T.test(
        "19. reprise sans doublon : même épreuve, résultat publié appliqué une fois, échéance sûre",
        function()
            local session = newSession("DEV-SPRINT", "Official", { 701 })
            RaceSession.lock(session, 10)
            local start = session.StartT
            drive(session, 701, "V-701", 20, 10, start, start + 8)
            RaceSession.disconnect(session, 701, start + 8)
            local progress = session.Participants[701].Progress
            local resumeAlong = session.Built.Checkpoints[progress.Next - 1].Along
            local ok, _, frame = RaceSession.reconnect(session, 701, start + 30)
            T.truthy(ok and frame ~= nil, "reprise acceptée dans la fenêtre")
            T.near(frame.X, session.Built.Checkpoints[progress.Next - 1].X, 1e-6, "reprise au dernier point validé")
            -- Le véhicule repart du point de reprise ; le chronomètre n'a pas été arrêté.
            drive(session, 701, "V-701", 20, start + 30, start + 30 - resumeAlong / 20, start + 60)
            T.equal(session.Participants[701].Progress.Status, "Finished", "terminée après reprise")
            local refused = RaceSession.reconnect(session, 701, start + 61)
            T.truthy(not refused, "pas de seconde reprise")
            -- Résultat publié par le serveur de course, appliqué par le serveur du profil.
            local clock, repo, profiles = world()
            local s = profiles(702)
            local vehicleId = ""
            s:commit("seed", "Seed", function(profile)
                vehicleId = VehicleOwnership.add(profile, {
                    ModelId = "wk_brio",
                    Origin = "Purchase",
                    Untransferable = false,
                    Synthetic = false,
                    EnergyFraction = 0.5,
                    Cosmetics = {},
                }, clock.Now)
                assert(GarageRules.takeOut(profile, vehicleId, "x", clock.Now))
                return VehicleRaceReservation.reserve(profile, reserveArgs(vehicleId, "Protected"), clock.Now)
            end)
            local ctx = context({ ResultId = "R-1:702" })
            RacePersistence.publish(repo, "R-1", { CourseId = "DEV-SPRINT" }, { ["702"] = ctx })
            RacePersistence.publish(repo, "R-1", {}, { ["702"] = context({ ResultId = "R-1:702", Position = 9 }) })
            local record = RacePersistence.read(repo, "R-1")
            T.equal(record.Results["702"].Position, 1, "résultat publié jamais remplacé")
            local pending = RaceRecovery.pendingResult(s.Data, record)
            T.truthy(pending ~= nil, "résultat en attente pour ce profil")
            s:commit("Race:" .. pending.ResultId, "Race", function(profile)
                return RaceRewards.payout(profile, pending, clock.Now)
            end)
            local balance = s.Data.Wallet.Balance
            T.equal(RaceRecovery.pendingResult(s.Data, record), nil, "plus rien en attente")
            T.equal(s.Data.Racing.Active, nil, "engagement libéré")
            T.truthy(balance > 0, "payé une fois")
            -- Engagement échu sans résultat (serveur de course disparu) : issue sûre au chargement.
            local s3 = profiles(703)
            local v3 = ""
            s3:commit("seed", "Seed", function(profile)
                v3 = VehicleOwnership.add(profile, {
                    ModelId = "wk_brio",
                    Origin = "Purchase",
                    Untransferable = false,
                    Synthetic = false,
                    EnergyFraction = 0.5,
                    Cosmetics = {},
                }, clock.Now)
                assert(GarageRules.takeOut(profile, v3, "x", clock.Now))
                assert(VehicleRaceReservation.reserve(profile, reserveArgs(v3, "Protected", "E-3"), clock.Now))
                profile.Vehicles[v3].Damage.Zones.Front = 0.7 -- dégât de course (jamais réconcilié en protégé)
                return true, nil
            end)
            s3:save(true)
            clock.Now += VehicleRaceReservation.DurationS + 1
            local reloaded = profiles(703)
            local vehicle = reloaded.Data.Vehicles[v3]
            T.equal(reloaded.Data.Racing.Active, nil, "engagement résolu")
            T.equal(vehicle.Reservation, nil, "réservation levée")
            T.equal(vehicle.Damage.Zones.Front, 0, "état initial restauré")
            T.equal(reloaded.Data.Wallet.Balance, 0, "aucune récompense")
            local count = 0
            for _ in reloaded.Data.Vehicles do
                count += 1
            end
            T.equal(count, 1, "aucun véhicule supplémentaire")
        end
    )

    T.test("20. météo normalisée pour le classé et les records ; dynamique ailleurs", function()
        local ranked = newSession("DEV-SPRINT", "Ranked", {})
        T.truthy(ranked.Normalized, "classée : conditions normalisées")
        T.equal(ranked.Conditions, "Sec-v1", "conditions versionnées du parcours")
        local private = newSession("DEV-SPRINT", "Private", {}, { Organizer = 1 })
        T.truthy(not private.Normalized, "privée : météo du monde")
        T.equal(private.Conditions, "Dynamique", "conditions dynamiques")
        local trafficOfficial =
            RaceSession.new({ Id = "X", Built = built("SPR-METRO-01"), Kind = "Official", CreatedAt = 0 })
        T.truthy(not trafficOfficial.Normalized, "officielle sur route ouverte : pas de record possible")
        local closedOfficial =
            RaceSession.new({ Id = "Y", Built = built("TT-MS-GP"), Kind = "Official", CreatedAt = 0 })
        T.truthy(closedOfficial.Normalized, "officielle sur piste fermée : normalisée (records)")
        -- Un record n'est enregistré que sous conditions normalisées.
        local profile = ProfileSchema.new(711, NOW, "Dev")
        RaceRewards.payout(profile, context({ EntryId = nil, RecordEligible = false, ResultId = "a" }), NOW)
        T.equal(profile.Racing.Records["DEV-SPRINT:v1:Sec-v1"], nil, "pas de record en conditions dynamiques")
        RaceRewards.payout(profile, context({ EntryId = nil, ResultId = "b", OfficialS = 28 }), NOW + 1)
        T.equal(profile.Racing.Records["DEV-SPRINT:v1:Sec-v1"].TimeS, 28, "record normalisé")
    end)

    T.suite("Lot 0.6 — salons, matchmaking et profil")

    T.test("salons : inscription unique, participation simultanée refusée, désinscription", function()
        local lobby = RaceLobby.new()
        local a = RaceSession.new({ Id = "A", Built = built("DEV-SPRINT"), Kind = "Official", CreatedAt = 0 })
        local b = RaceSession.new({ Id = "B", Built = built("DEV-TT"), Kind = "Official", CreatedAt = 0 })
        RaceLobby.add(lobby, a)
        RaceLobby.add(lobby, b)
        T.truthy(RaceLobby.join(lobby, a, entry(801), 0), "inscription")
        T.equal(select(2, RaceLobby.join(lobby, a, entry(801), 0)), "RaceAlreadyRegistered", "inscription répétée")
        T.equal(select(2, RaceLobby.join(lobby, b, entry(801), 0)), "RaceAlreadyEngaged", "deux courses à la fois")
        local other = entry(802)
        other.VehicleId = "V-801"
        T.equal(select(2, RaceLobby.join(lobby, a, other, 0)), "RaceVehicleAlreadyEngaged", "même véhicule")
        T.truthy(RaceLobby.leave(lobby, 801), "désinscription")
        T.truthy(RaceLobby.join(lobby, b, entry(801), 0), "puis autre course")
        T.equal(#RaceLobby.search(lobby, { Discipline = "TimeTrial" }), 1, "recherche")
        local private = RaceSession.new({
            Id = "P",
            Built = built("DEV-SPRINT"),
            Kind = "Private",
            CreatedAt = 0,
            OrganizerUserId = 9,
            Laps = 99,
        })
        RaceLobby.add(lobby, private)
        T.equal(#RaceLobby.search(lobby, { CourseId = "DEV-SPRINT" }), 1, "salon privé jamais listé")
    end)

    T.test("matchmaking : groupes par niveau, confirmation, expiration, double ticket", function()
        local queue = MatchmakingService.new("srv")
        local function request(userId: number, rating: number): any
            return { UserId = userId, Discipline = "Sprint", Kind = "Ranked", Mode = "Protected", Rating = rating }
        end
        T.truthy(MatchmakingService.enqueue(queue, request(1, 1000), 0), "ticket")
        T.truthy(not MatchmakingService.enqueue(queue, request(1, 1000), 0), "double ticket refusé")
        MatchmakingService.enqueue(queue, request(2, 1050), 1)
        MatchmakingService.enqueue(queue, request(3, 1900), 1)
        local proposals = MatchmakingService.tick(queue, 5)
        T.equal(#proposals, 0, "attente minimale")
        proposals = MatchmakingService.tick(queue, 25)
        T.equal(#proposals, 1, "un groupe")
        T.equal(#proposals[1].UserIds, 2, "niveaux proches seulement")
        local matchId = proposals[1].MatchId
        T.equal(MatchmakingService.confirm(queue, 1, matchId, 30), nil, "en attente des autres")
        local match = MatchmakingService.confirm(queue, 2, matchId, 31)
        T.truthy(match ~= nil, "match conclu")
        T.equal(queue.Tickets[1], nil, "tickets sortis de la file")
        -- Proposition non confirmée : retirée à l'échéance.
        MatchmakingService.enqueue(queue, request(4, 1890), 40)
        local second = MatchmakingService.tick(queue, 70)
        T.equal(#second, 1, "3 et 4 groupés (fenêtre élargie)")
        local _, removed = MatchmakingService.tick(queue, 70 + MatchmakingService.Params.ConfirmS + 1)
        T.equal(#removed, 2, "non confirmés retirés")
    end)

    T.test("profil : migration v2 → v3 sans perte, schéma courant valide", function()
        local current = ProfileSchema.new(901, NOW, "Dev")
        local v2: any = ProfileMigration.deepCopy(current)
        v2.SchemaVersion = 2
        v2.Racing = nil
        Wallet.credit(v2, 500, "Seed", "s", NOW)
        local migrated = ProfileMigration.migrate(v2)
        T.equal(migrated.Status, "Migrated", "migré")
        T.equal(migrated.Data.SchemaVersion, ProfileSchema.Version, "version courante")
        T.equal(migrated.Data.Wallet.Balance, 500, "portefeuille conservé")
        local ok, errors = ProfileSchema.validate(migrated.Data)
        T.truthy(ok, table.concat(errors, ";"))
        T.equal(v2.Racing, nil, "original intact")
    end)
end
