-- Essais CLIENT du lot 0.6 (session « lot06 », 2 joueurs), écrits au lot 0.9 et
-- injectés par le pilote dans le Studio de test uniquement. Les clients passent
-- par le VRAI canal des courses (AWRacing.Request) et conduisent avec la VRAIE
-- simulation du véhicule : seule la lecture clavier/manette est remplacée par un
-- pilote automatique (VehicleController.setTestInputProvider) qui suit les points
-- de passage publiés par le serveur. Ce pilote n'a rien d'un humain : il valide la
-- chaîne inscription → grille → départ → points de passage → résultat, pas le
-- ressenti ni l'équilibrage.
--
-- 1. Épreuve OFFICIELLE (sprint) à deux, véhicules personnels sortis : le joueur 2
--    part volontairement avant le feu vert (faux départ attendu), réservation de
--    l'exemplaire pendant l'épreuve, résultat et récompense.
-- 2. Joueur 1 seul, ENTRAÎNEMENT avec un prototype du parc : drag, contre-la-montre,
--    circuit (3 tours), rallye, drift ; refus attendus (falsifications).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local sessionStart = os.clock()
while ReplicatedStorage:GetAttribute("AWTestSession") == nil and os.clock() - sessionStart < 15 do
    task.wait()
end
if ReplicatedStorage:GetAttribute("AWTestSession") ~= "lot06" then
    return
end

local steps = {}
local measures = {}
local function record(name: string, ok: boolean, detail: any)
    table.insert(steps, { name = name, ok = ok, detail = if detail ~= nil then tostring(detail) else nil })
end
local function waitFor(predicate: () -> boolean, timeout: number): boolean
    local start = os.clock()
    while os.clock() - start < timeout do
        if predicate() then
            return true
        end
        task.wait(0.1)
    end
    return predicate()
end

local S = 1 / 0.28 -- studs par mètre (VehicleConstants.MetersPerStud = 0,28)
local reportEvent = ReplicatedStorage:WaitForChild("AWTestReport", 30)
local signalEvent = ReplicatedStorage:WaitForChild("AWTestSignal", 30)
local racingFolder = ReplicatedStorage:WaitForChild("AWRacing", 30) :: Instance
local racing = racingFolder:WaitForChild("Request", 10) :: RemoteFunction
local racePush = racingFolder:WaitForChild("Push", 10) :: RemoteEvent
local RaceCourses =
    require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Racing"):WaitForChild("RaceCourses")) :: any
local progression = (ReplicatedStorage:WaitForChild("AWProgression", 30) :: Instance):WaitForChild(
        "Request",
        10
    ) :: RemoteFunction
local economy = (ReplicatedStorage:WaitForChild("AWEconomy", 30) :: Instance):WaitForChild(
        "Request",
        10
    ) :: RemoteFunction
local VehicleController = require(
    player
        :WaitForChild("PlayerScripts")
        :WaitForChild("AutomotiveWorldClient")
        :WaitForChild("Vehicles")
        :WaitForChild("VehicleController")
) :: any

local index = 0
waitFor(function()
    index = player:GetAttribute("AWTestIndex") or 0
    return index > 0
end, 30)
local prefix = "lot06.j" .. index .. "."

local function trace(message: string)
    print(string.format("[AW_Test] lot06 j%d %.1f s : %s", index, os.clock() - sessionStart, message))
end
local function signal(name: string)
    signalEvent:FireServer("AW06:" .. name)
end
local function waitSignal(name: string, timeout: number): boolean
    trace("attente du signal " .. name)
    return waitFor(function()
        return ReplicatedStorage:GetAttribute("AW06_" .. name) == true
    end, timeout)
end

local view: any = nil -- dernier état d'épreuve publié par le serveur
racePush.OnClientEvent:Connect(function(kind: any, data: any)
    if kind == "Snapshot" and type(data) == "table" then
        view = if data.None then nil else data
    elseif kind == "Results" and type(data) == "table" then
        -- Fin d'épreuve : le serveur publie les résultats (et non un dernier instantané), comme
        -- le lit le panneau des courses du jeu. On en tire l'état final de ce participant.
        local mine = data.Mine or {}
        local me = view and view.Me or {}
        for _, entry in data.Entries or {} do
            if entry.UserId == player.UserId or entry.Me then
                me.OfficialS = entry.OfficialS or entry.TimeS or me.OfficialS
                me.PenaltyS = entry.PenaltyS or me.PenaltyS
                me.ReactionS = entry.ReactionS or me.ReactionS
                me.Score = entry.Score
                me.TrapSpeedKmh = entry.TrapSpeedKmh
                me.BestLapS = entry.BestLapS
            end
        end
        me.Status = if mine.Outcome == "Finished" then "Finished" else tostring(mine.Outcome)
        me.Credits = mine.Credits
        view = { State = "Finished", Me = me, Discipline = data.Discipline, CourseId = view and view.CourseId }
    end
end)

local function race(action: string, payload: any?): any
    local data = payload or {}
    data.RequestId = data.RequestId or HttpService:GenerateGUID(false)
    task.wait(0.55)
    local ok, response = pcall(function()
        return racing:InvokeServer(action, data)
    end)
    if not ok or type(response) ~= "table" then
        return { Status = "Error", Error = tostring(response) }
    end
    trace(action .. " → " .. tostring(response.Status) .. " " .. tostring(response.Error))
    return response
end
local function call(remote: RemoteFunction, action: string, payload: any?): any
    local data = payload or {}
    data.RequestId = data.RequestId or HttpService:GenerateGUID(false)
    task.wait(0.5)
    local ok, response = pcall(function()
        return remote:InvokeServer(action, data)
    end)
    if not ok or type(response) ~= "table" then
        return { Status = "Error", Error = tostring(response) }
    end
    return response
end
local function describe(response: any): string
    return tostring(response.Status) .. (if response.Error then " / " .. tostring(response.Error) else "")
end
local function character(): Model
    return player.Character or player.CharacterAdded:Wait()
end
local function rootPart(): BasePart
    return character():WaitForChild("HumanoidRootPart", 10) :: BasePart
end
local function balance(): number
    local response = call(economy, "Snapshot", {})
    local snap = response.Snapshot
    return if snap and snap.Wallet then snap.Wallet.Balance else -1
end

-- ======================== Pilote automatique ========================

local driving: { Model: Model?, Target: Vector3?, SpeedKmh: number, Hold: boolean, Launch: boolean? } =
    { Model = nil, Target = nil, SpeedKmh = 0, Hold = true, Launch = nil }

local function speedKmh(model: Model): number
    local body = model.PrimaryPart
    return if body then body.AssemblyLinearVelocity.Magnitude / S * 3.6 else 0
end

-- Commande : cap vers la cible (direction = LookVector du châssis), vitesse visée.
local function autopilot(): any
    local model = driving.Model
    local body = model and model.PrimaryPart
    if body == nil or driving.Hold or driving.Target == nil then
        -- Arrêt : frein au-dessus de 3 km/h, puis frein à main. Maintenir « freiner » à
        -- l'arrêt engagerait la marche arrière d'une boîte automatique (arbitrage A3).
        local moving = model ~= nil and speedKmh(model :: Model) > 3
        return { Throttle = 0, Brake = if moving then 1 else 0, Steer = 0, Handbrake = not moving, Clutch = 0 }
    end
    local target = driving.Target :: Vector3
    local forward = Vector3.new(body.CFrame.LookVector.X, 0, body.CFrame.LookVector.Z).Unit
    local offset = Vector3.new(target.X - body.Position.X, 0, target.Z - body.Position.Z)
    if offset.Magnitude < 1 then
        return { Throttle = 0, Brake = 0, Steer = 0, Handbrake = true, Clutch = 0 }
    end
    local direction = offset.Unit
    local cross = forward:Cross(direction).Y
    local angle = math.acos(math.clamp(forward:Dot(direction), -1, 1))
    local v = speedKmh(model :: Model)
    -- Direction adoucie avec la vitesse (sinon oscillation à 100 km/h et plus) ; ralenti
    -- à l'approche de la cible (évite de dépasser un point puis de couper vers un poteau).
    local steer = math.clamp(-math.sign(cross) * angle / 0.6 / (1 + v / 45), -1, 1)
    local wanted = driving.SpeedKmh * math.clamp(1 - angle / math.pi * 1.6, 0.35, 1)
    local distanceM = offset.Magnitude / S
    if not driving.Launch and distanceM < 25 then
        wanted = math.min(wanted, math.max(18, distanceM * 1.4))
    end
    if driving.Launch then
        return { Throttle = 1, Brake = 0, Steer = steer, Handbrake = false, Clutch = 0 }
    end
    local throttle = math.clamp((wanted - v) / 12, 0, 1)
    local brake = if v > wanted + 10 then 0.6 else 0
    return { Throttle = throttle, Brake = brake, Steer = steer, Handbrake = false, Clutch = 0 }
end

local function meters(point: any): Vector3
    return Vector3.new(point.X * S, 0, point.Z * S)
end

-- Conduit jusqu'à un point (m), puis s'arrête. Renvoie vrai si atteint dans le délai.
local function driveTo(point: any, kmh: number, radiusM: number, timeout: number): boolean
    local model = driving.Model
    if model == nil or model.PrimaryPart == nil then
        return false
    end
    driving.Target = meters(point)
    driving.SpeedKmh = kmh
    driving.Hold = false
    local reached = waitFor(function()
        local body = (model :: Model).PrimaryPart :: BasePart
        local flat = Vector3.new(
            body.Position.X - (driving.Target :: Vector3).X,
            0,
            body.Position.Z - (driving.Target :: Vector3).Z
        )
        return flat.Magnitude / S < radiusM
    end, timeout)
    driving.Hold = true
    waitFor(function()
        return speedKmh(model :: Model) < 2
    end, 10)
    return reached
end

local function board(model: Model): boolean
    local body = model.PrimaryPart
    local door = body and body:FindFirstChild("DriverDoor")
    local prompt = door and door:FindFirstChild("EnterPrompt") :: ProximityPrompt?
    if prompt == nil then
        return false
    end
    local ok = false
    for attempt = 1, 3 do
        rootPart().CFrame = CFrame.new((door :: Attachment).WorldPosition + Vector3.new(0, 2, 0))
        task.wait(if attempt == 1 then 0.8 else 1.5)
        prompt:InputHoldBegin()
        task.wait(prompt.HoldDuration + 0.3)
        prompt:InputHoldEnd()
        ok = waitFor(function()
            return model:GetAttribute("DriverUserId") == player.UserId
        end, 5)
        if ok then
            break
        end
    end
    if ok then
        driving.Model = model
        VehicleController.setTestInputProvider(autopilot)
    end
    return ok
end

-- ======================== Déroulé d'une épreuve ========================

--[[
    Attend la fin du verrouillage, rejoint sa place de grille, attend le départ
    (ou part avant le feu si `falseStart`), suit les points de passage jusqu'à
    l'arrivée. Renvoie la dernière vue reçue.
]]
local function runEvent(label: string, kmh: number, falseStart: boolean?, maxS: number): any
    local started = os.clock()
    -- Grille : rejoindre sa place dès qu'elle est publiée.
    local slotDone = false
    local lastTrace = 0
    while os.clock() - started < maxS do
        if os.clock() - lastTrace > 2 and driving.Model and (driving.Model :: Model).PrimaryPart then
            lastTrace = os.clock()
            local body = (driving.Model :: Model).PrimaryPart :: BasePart
            local me0 = view and view.Me or {}
            trace(
                string.format(
                    "%s : état %s/%s, point %s, position (%.0f, %.0f) m, %.0f km/h, cible %s, maintien %s",
                    label,
                    tostring(view and view.State),
                    tostring(me0.Status),
                    tostring(me0.Next),
                    body.Position.X / S,
                    body.Position.Z / S,
                    speedKmh(driving.Model :: Model),
                    if driving.Target
                        then string.format(
                            "(%.0f, %.0f)",
                            (driving.Target :: Vector3).X / S,
                            (driving.Target :: Vector3).Z / S
                        )
                        else "aucune",
                    tostring(driving.Hold)
                )
            )
        end
        local v = view
        if v == nil then
            task.wait(0.2)
            continue
        end
        local me = v.Me or {}
        if
            v.State == "Finished"
            or v.State == "Cancelled"
            or me.Status == "Finished"
            or me.Status == "DNF"
            or me.Status == "Abandoned"
        then
            break
        end
        if v.State == "Countdown" or v.State == "Running" then
            if not slotDone and me.SlotPoint and me.Status ~= "Racing" then
                driveTo(me.SlotPoint, 15, 3, 20)
                slotDone = true
            end
            local now = Workspace:GetServerTimeNow()
            local startT = me.StartT or v.StartT
            local waiting = startT ~= nil and now < startT
            -- Faux départ volontaire : on part 3 s avant le feu vert (ligne franchie trop tôt).
            if waiting and not (falseStart and now > startT - 3) then
                driving.Hold = true
            elseif v.Discipline == "Drift" then
                -- Drift : cercle serré autour du centre de la zone, frein à main par à-coups.
                local center = v.DriftCenter
                if center then
                    local body = (driving.Model :: Model).PrimaryPart :: BasePart
                    local x, z = body.Position.X / S - center.X, body.Position.Z / S - center.Z
                    local a = math.atan2(z, x) + 0.6
                    driving.Target = meters({ X = center.X + math.cos(a) * 18, Z = center.Z + math.sin(a) * 18 })
                    driving.SpeedKmh = 45
                    driving.Hold = false
                end
            else
                local next = me.Checkpoints and me.Checkpoints[1]
                if next == nil then
                    -- Sans point de passage publié (drag) : viser le bout du parcours.
                    local course = RaceCourses.get(v.CourseId)
                    next = course and course.Points[#course.Points]
                end
                if next then
                    driving.Target = meters(next)
                    driving.SpeedKmh = kmh
                    driving.Hold = false
                    driving.Launch = v.Discipline == "Drag"
                end
            end
        end
        task.wait(0.1)
    end
    driving.Launch = nil
    driving.Hold = true
    local final = view and view.Me
    if final and final.Status == "Racing" then
        -- Épreuve non terminée dans le délai : abandon (libère l'engagement pour la suivante).
        race("Abandon")
    end
    waitFor(function()
        return view == nil or (view.Me and view.Me.Status ~= "Racing") or view.State == "Finished"
    end, 30)
    trace(label .. " terminé : " .. HttpService:JSONEncode(view and view.Me or {}))
    return view
end

local function registrationOf(courseId: string): any
    local response = race("Catalog")
    for _, course in (response.Result and response.Result.Courses) or {} do
        if course.Id == courseId then
            return course.Registration
        end
    end
    return nil
end

local function main()
    local fleet = Workspace:WaitForChild("VehiculesEssai", 30) :: Instance
    local catalog = race("Catalog")
    record(
        prefix .. "catalogue_courses",
        catalog.Result ~= nil and #(catalog.Result.Courses or {}) == 6,
        describe(catalog)
    )

    -- ===== 1. Épreuve officielle à deux (véhicules personnels) =====
    local snapshot = call(progression, "Snapshot", {})
    local snap = snapshot.Snapshot or {}
    local vehicleId, free = nil, nil
    for _, vehicle in snap.Vehicles or {} do
        if vehicle.ModelId == "proto_p01" then
            vehicleId = vehicle.Id
        end
    end
    for _, property in snap.Properties or {} do
        if property.Origin == "FreeStarter" then
            free = property
        end
    end
    local zone = Workspace:WaitForChild("AutomotiveTestZone", 20) :: Instance
    local entrance = zone:WaitForChild("EntreeProprieteEssai", 10) :: BasePart
    rootPart().CFrame = CFrame.new(entrance.Position + Vector3.new(0, 3, 0))
    task.wait(1.2)
    call(progression, "Enter", { OwnerUserId = player.UserId, PropertyId = free and free.Id })
    local out = call(progression, "TakeOut", { VehicleId = vehicleId })
    record(prefix .. "vehicule_personnel_sorti", out.Status == "Confirmed" or out.Status == "Pending", describe(out))
    local personal: Model? = nil
    waitFor(function()
        local folder = Workspace:FindFirstChild("VehiculesPersonnels")
        for _, child in (folder and folder:GetChildren()) or {} do
            if child:GetAttribute("PersonalVehicleId") == vehicleId then
                personal = child :: Model
            end
        end
        return personal ~= nil
    end, 15)
    local boarded = personal ~= nil and board(personal :: Model)
    record(prefix .. "embarque_vehicule_personnel", boarded)
    local reg = registrationOf("DEV-SPRINT")
    if boarded and reg then
        driveTo(reg, 25, 30, 60)
    end
    local before = balance()
    -- Falsification : épreuve classée sans file d'attente, épreuve inconnue.
    local ranked = race("Join", { CourseId = "DEV-SPRINT", Kind = "Ranked" })
    record(prefix .. "classee_sans_file_refusee", ranked.Error == "RaceRankedNeedsQueue", describe(ranked))
    local unknown = race("Join", { CourseId = "DEV-INEXISTANT", Kind = "Official" })
    record(prefix .. "epreuve_inconnue_refusee", unknown.Error == "RaceUnknown", describe(unknown))
    local join = race("Join", { CourseId = "DEV-SPRINT", Kind = "Official", Mode = "Protected" })
    record(prefix .. "inscription_officielle", join.Status == "Ok", describe(join))
    signal("Joined" .. index)
    waitSignal("Joined" .. (if index == 1 then 2 else 1), 120)
    -- Pendant l'engagement, l'exemplaire est réservé : le ranger est refusé.
    local store = call(progression, "Store", { VehicleId = vehicleId })
    record(
        prefix .. "exemplaire_reserve_pendant_course",
        store.Status ~= "Confirmed" and store.Status ~= "Pending",
        describe(store)
    )
    driveTo(waitFor(function()
        return view ~= nil
    end, 10) and view.Start or reg, 15, 20, 40)
    local ready = race("Ready", { Ready = true })
    record(prefix .. "pret_au_depart", ready.Status == "Ok", describe(ready))
    local result = runEvent("sprint officiel", 45, index == 2, 300)
    local me = result and result.Me or {}
    measures["sprint_temps_officiel_j" .. index] = me.OfficialS
    measures["sprint_penalite_j" .. index] = me.PenaltyS
    record(
        prefix .. "sprint_arrivee",
        me.Status == "Finished" and type(me.OfficialS) == "number",
        HttpService:JSONEncode(me)
    )
    if index == 2 then
        record(
            prefix .. "faux_depart_penalise",
            me.FalseStart == true or (me.PenaltyS or 0) >= 5,
            "pénalité " .. tostring(me.PenaltyS)
        )
    else
        record(prefix .. "depart_regulier_sans_penalite", not me.FalseStart, "pénalité " .. tostring(me.PenaltyS))
    end
    local after = 0
    local paid = waitFor(function()
        after = balance()
        return after > before
    end, 30)
    record(prefix .. "recompense_creditee", paid, string.format("%d → %d", before, after))
    local storedBack = call(progression, "Store", { VehicleId = vehicleId })
    record(prefix .. "exemplaire_libere_apres_course", storedBack.Error ~= "VehicleReserved", describe(storedBack))
    signal("SprintDone" .. index)

    if index == 2 then
        waitSignal("TrainingDone", 900)
        return
    end

    -- ===== 2. Entraînement, prototype du parc (joueur 1) =====
    waitSignal("SprintDone2", 120)
    local humanoid = character():FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.Sit = false
        humanoid.Jump = true
    end
    task.wait(2)
    VehicleController.setTestInputProvider(nil)
    local proto: Model? = nil
    for _, child in fleet:GetChildren() do
        if
            child:IsA("Model")
            and child:GetAttribute("DefinitionId") == "proto_p01"
            and child:GetAttribute("DriverUserId") == 0
        then
            proto = child
        end
    end
    local fleetBoarded = proto ~= nil and board(proto :: Model)
    record(prefix .. "embarque_prototype_parc", fleetBoarded)
    local publicWithFleet = race("Join", { CourseId = "DEV-DRAG", Kind = "Official" })
    record(
        prefix .. "officielle_avec_vehicule_du_parc_refusee",
        publicWithFleet.Error ~= nil and publicWithFleet.Status ~= "Ok",
        describe(publicWithFleet)
    )
    for _, plan in
        {
            { Id = "DEV-DRAG", Label = "drag", Kmh = 120, MaxS = 180 },
            { Id = "DEV-TT", Label = "contre-la-montre", Kmh = 45, MaxS = 240 },
            { Id = "DEV-CIRCUIT", Label = "circuit", Kmh = 40, MaxS = 420 },
            { Id = "DEV-RALLY", Label = "rallye", Kmh = 35, MaxS = 360 },
            { Id = "DEV-DRIFT", Label = "drift", Kmh = 45, MaxS = 240 },
        }
    do
        -- Mise en place : sortir, faire poser le prototype au point d'inscription, remonter.
        local humanoidNow = character():FindFirstChildOfClass("Humanoid")
        if humanoidNow then
            humanoidNow.Sit = false
            humanoidNow.Jump = true
        end
        task.wait(2)
        if proto then
            signalEvent:FireServer("AW06:Place:" .. (proto :: Model).Name .. ":" .. plan.Id)
            waitFor(function()
                return ReplicatedStorage:GetAttribute("AW06_Placed") == plan.Id
            end, 10)
            task.wait(1)
            board(proto :: Model)
        end
        local created = race("CreatePrivate", { CourseId = plan.Id, Kind = "Training", Mode = "Protected" })
        if created.Status == "Ok" then
            waitFor(function()
                return view ~= nil
            end, 10)
            if view and view.Start then
                driveTo(view.Start, 15, 20, 40)
            end
            race("Ready", { Ready = true })
            local outcome = runEvent(plan.Label, plan.Kmh, false, plan.MaxS)
            local done = outcome and outcome.Me or {}
            local finished = done.Status == "Finished"
            local detail = HttpService:JSONEncode({
                Status = done.Status,
                Reason = done.Reason,
                OfficialS = done.OfficialS,
                Lap = done.Lap,
                LapTimes = done.LapTimes,
                ReactionS = done.ReactionS,
                Drift = done.Drift,
                Score = done.Score,
                TrapSpeedKmh = done.TrapSpeedKmh,
                BestLapS = done.BestLapS,
                Credits = done.Credits,
            })
            record(prefix .. "entrainement_" .. string.lower(string.sub(plan.Id, 5)), finished, detail)
            measures["entrainement_" .. plan.Label] = detail
        else
            record(prefix .. "entrainement_" .. string.lower(string.sub(plan.Id, 5)), false, describe(created))
        end
        task.wait(2)
    end
    VehicleController.setTestInputProvider(nil)
    signal("TrainingDone")
end

trace("début du test")
local ran, failure = xpcall(main, debug.traceback)
if not ran then
    record(prefix .. "script_sans_plantage", false, failure)
end
VehicleController.setTestInputProvider(nil)
trace(if ran then "fin du test" else "plantage : " .. tostring(failure))
reportEvent:FireServer({ vehicle = "lot06-j" .. index, steps = steps, measures = measures })
