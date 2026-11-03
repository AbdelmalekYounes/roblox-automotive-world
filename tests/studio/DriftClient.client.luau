-- Essais CLIENT du lot 0.9.1 (session « drift », place de développement, 1 joueur).
-- 1. Épreuve OFFICIELLE de drift (DEV-DRIFT) avec le véhicule personnel (P-01, propulsion,
--    sans aide) : le score est calculé par le SERVEUR (DriftScoring) à partir de ses propres
--    échantillons (cap de la caisse, direction de la vitesse, vitesse, zone). Rien n'est
--    injecté : le client ne transmet aucun score, seulement des commandes de conduite.
-- 2. Demande « prêt » envoyée APRÈS le verrouillage : refus attendu (RaceAlreadyLocked),
--    sans effet sur l'engagement (l'épreuve se poursuit jusqu'au résultat).
-- Instrumenté (signalé) : la lecture clavier/manette est remplacée par un pilote de
-- dérive (frein à main, accélérateur, contre-braquage) ; embarquement par l'invite
-- activée par script. La physique du véhicule n'est pas modifiée.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local sessionStart = os.clock()
while ReplicatedStorage:GetAttribute("AWTestSession") == nil and os.clock() - sessionStart < 15 do
    task.wait()
end
if ReplicatedStorage:GetAttribute("AWTestSession") ~= "drift" then
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
local function trace(message: string)
    print(string.format("[AW_Test] drift %.1f s : %s", os.clock() - sessionStart, message))
end

local S = 1 / 0.28
local reportEvent = ReplicatedStorage:WaitForChild("AWTestReport", 30) :: RemoteEvent
local racingFolder = ReplicatedStorage:WaitForChild("AWRacing", 30) :: Instance
local racing = racingFolder:WaitForChild("Request", 10) :: RemoteFunction
local racePush = racingFolder:WaitForChild("Push", 10) :: RemoteEvent
local economy = (ReplicatedStorage:WaitForChild("AWEconomy", 30) :: Instance):WaitForChild(
        "Request",
        10
    ) :: RemoteFunction
local progression = (ReplicatedStorage:WaitForChild("AWProgression", 30) :: Instance):WaitForChild(
        "Request",
        10
    ) :: RemoteFunction
local RaceCourses =
    require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Racing"):WaitForChild("RaceCourses")) :: any
local client = player:WaitForChild("PlayerScripts"):WaitForChild("AutomotiveWorldClient")
local VehicleController = require(client:WaitForChild("Vehicles"):WaitForChild("VehicleController", 10)) :: any
local Gui = require(ReplicatedStorage:WaitForChild("AW_TestGui", 30)) :: any

local function call(remote: RemoteFunction, action: string, payload: any?, noRequestId: boolean?): any
    local data = payload or {}
    if not noRequestId and data.RequestId == nil then
        data.RequestId = HttpService:GenerateGUID(false)
    end
    task.wait(0.55)
    local ok, response = pcall(function()
        return remote:InvokeServer(action, data)
    end)
    if not ok or type(response) ~= "table" then
        return { Status = "Error", Error = tostring(response) }
    end
    trace(action .. " → " .. tostring(response.Status) .. " " .. tostring(response.Error))
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

-- Vue de l'épreuve publiée par le serveur, et résultats finaux.
local view: any = nil
local results: any = nil
racePush.OnClientEvent:Connect(function(kind: any, data: any)
    if kind == "Snapshot" and type(data) == "table" then
        view = if data.None then nil else data
    elseif kind == "Results" and type(data) == "table" then
        results = data
        trace("résultats : " .. HttpService:JSONEncode(data.Mine or {}))
    end
end)

-- ======================== Pilotes ========================

local model: Model? = nil
local mode = "hold" -- "hold" | "drive" | "drift"
local target: Vector3? = nil
local targetKmh = 0
local center: Vector3? = nil
local RADIUS_M = 16

local function bodyOf(): BasePart?
    return model and (model :: Model).PrimaryPart
end
local function speedKmh(): number
    local body = bodyOf()
    return if body then body.AssemblyLinearVelocity.Magnitude / S * 3.6 else 0
end
-- Même définition que le serveur : direction de la vitesse par rapport au cap de la caisse.
local function slipDeg(body: BasePart): number
    local look = body.CFrame.LookVector
    local velocity = body.AssemblyLinearVelocity
    local heading = math.atan2(look.X, -look.Z)
    local velocityHeading = math.atan2(velocity.X, -velocity.Z)
    return math.deg((velocityHeading - heading + math.pi) % (2 * math.pi) - math.pi)
end

local function pursue(body: BasePart, point: Vector3, kmh: number): any
    local forward = Vector3.new(body.CFrame.LookVector.X, 0, body.CFrame.LookVector.Z).Unit
    local offset = Vector3.new(point.X - body.Position.X, 0, point.Z - body.Position.Z)
    if offset.Magnitude < 1 then
        return { Throttle = 0, Brake = 0, Steer = 0, Handbrake = false, Clutch = 0 }
    end
    local cross = forward:Cross(offset.Unit).Y
    local angle = math.acos(math.clamp(forward:Dot(offset.Unit), -1, 1))
    local v = speedKmh()
    local steer = math.clamp(-math.sign(cross) * angle / 0.6 / (1 + v / 45), -1, 1)
    local wanted = kmh * math.clamp(1 - angle / math.pi * 1.6, 0.35, 1)
    local throttle = math.clamp((wanted - v) / 12, 0, 1)
    return {
        Throttle = throttle,
        Brake = if v > wanted + 8 then 0.6 else 0,
        Steer = steer,
        Handbrake = false,
        Clutch = 0,
    }
end

-- Dérive en cercle (sens antihoraire) : lancement au frein à main, puis accélérateur et
-- contre-braquage proportionnel à l'angle de dérive ; reprise si la dérive se perd.
local phase = "approach"
local phaseSince = 0
local lowSlipSince: number? = nil
local stats = { kicks = 0, maxSlip = 0, slipTime = 0, lastT = os.clock() }
local function setPhase(name: string)
    phase = name
    phaseSince = os.clock()
end

local function driftInput(body: BasePart): any
    local c = center :: Vector3
    local rel = Vector3.new(body.Position.X - c.X, 0, body.Position.Z - c.Z)
    local r = rel.Magnitude / S
    local v = speedKmh()
    local slip = slipDeg(body)
    local now = os.clock()
    local dt = now - stats.lastT
    stats.lastT = now
    if math.abs(slip) >= 12 and v >= 30 then
        stats.slipTime += dt
    end
    stats.maxSlip = math.max(stats.maxSlip, math.abs(slip))
    -- Point du cercle un peu en avant (sens antihoraire vu de dessus : angle croissant
    -- en x → -z).
    local a = math.atan2(-rel.Z, rel.X) + 0.7
    local ahead = Vector3.new(c.X + math.cos(a) * RADIUS_M * S, body.Position.Y, c.Z - math.sin(a) * RADIUS_M * S)
    if r > 36 then
        setPhase("approach")
        return pursue(body, Vector3.new(c.X, body.Position.Y, c.Z), 30)
    end
    if phase == "approach" then
        -- Lancement dès 32 km/h sur le cercle (la poursuite du cercle plafonne vers 35 km/h).
        if v >= 32 and math.abs(r - RADIUS_M) < 8 and now - phaseSince > 1.5 then
            setPhase("kick")
            stats.kicks += 1
        end
        return pursue(body, ahead, 55)
    elseif phase == "kick" then
        if now - phaseSince > 0.35 then
            setPhase("hold")
            lowSlipSince = nil
        end
        return { Throttle = 1, Brake = 0, Steer = -1, Handbrake = true, Clutch = 0 }
    elseif phase == "recover" then
        if math.abs(slip) < 35 or now - phaseSince > 2 then
            setPhase("approach")
        end
        return { Throttle = 0, Brake = 0, Steer = math.clamp(slip / 25, -1, 1), Handbrake = false, Clutch = 0 }
    end
    -- « hold » : maintien de la dérive.
    if math.abs(slip) > 90 then
        setPhase("recover")
        return { Throttle = 0, Brake = 0, Steer = math.clamp(slip / 25, -1, 1), Handbrake = false, Clutch = 0 }
    end
    if math.abs(slip) < 10 then
        lowSlipSince = lowSlipSince or now
        if now - (lowSlipSince :: number) > 0.6 then
            setPhase("approach")
        end
    else
        lowSlipSince = nil
    end
    if v < 26 then
        setPhase("approach")
    end
    local correction = if r > RADIUS_M + 5 then -0.35 elseif r < RADIUS_M - 5 then 0.25 else 0
    local steer = math.clamp(slip / 32 * 0.9 + correction, -1, 1)
    local throttle = if math.abs(slip) > 65 then 0.3 elseif math.abs(slip) > 50 then 0.7 else 1
    return { Throttle = throttle, Brake = 0, Steer = steer, Handbrake = false, Clutch = 0 }
end

local function provider(): any
    local body = bodyOf()
    if body == nil or mode == "hold" then
        local moving = speedKmh() > 3
        return { Throttle = 0, Brake = if moving then 1 else 0, Steer = 0, Handbrake = not moving, Clutch = 0 }
    end
    if mode == "drift" and center then
        return driftInput(body)
    end
    if target then
        return pursue(body, target, targetKmh)
    end
    return { Throttle = 0, Brake = 0, Steer = 0, Handbrake = true, Clutch = 0 }
end

local function driveTo(point: { X: number, Z: number }, kmh: number, radiusM: number, timeout: number): boolean
    target = Vector3.new(point.X * S, 0, point.Z * S)
    targetKmh = kmh
    mode = "drive"
    local reached = waitFor(function()
        local body = bodyOf()
        return body ~= nil
            and Vector3.new(body.Position.X / S - point.X, 0, body.Position.Z / S - point.Z).Magnitude < radiusM
    end, timeout)
    mode = "hold"
    waitFor(function()
        return speedKmh() < 1
    end, 10)
    return reached
end

local function board(vehicle: Model): boolean
    local body = vehicle.PrimaryPart
    local door = body and body:FindFirstChild("DriverDoor")
    local prompt = door and door:FindFirstChild("EnterPrompt") :: ProximityPrompt?
    if prompt == nil then
        return false
    end
    for attempt = 1, 4 do
        rootPart().CFrame = CFrame.new((door :: Attachment).WorldPosition + Vector3.new(0, 2, 0))
        task.wait(if attempt == 1 then 0.8 else 1.5)
        prompt:InputHoldBegin()
        task.wait(prompt.HoldDuration + 0.3)
        prompt:InputHoldEnd()
        if
            waitFor(function()
                return vehicle:GetAttribute("DriverUserId") == player.UserId
            end, 5)
        then
            model = vehicle
            VehicleController.setTestInputProvider(provider)
            return true
        end
    end
    return false
end

local function main()
    waitFor(function()
        local snap = call(economy, "Snapshot", {}, true).Snapshot
        return snap ~= nil and snap.State == "Active"
    end, 40)
    character():WaitForChild("HumanoidRootPart", 20)
    task.wait(3)
    Gui.calibrate(2)
    local snap = call(economy, "Snapshot", {}, true).Snapshot or {}
    local ownId, propertyId = nil, nil
    for _, vehicle in snap.Vehicles or {} do
        if vehicle.Name == "Prototype d'essai P-01" then
            ownId = vehicle.Id
        end
    end
    for _, property in snap.Properties or {} do
        propertyId = propertyId or property.Id
    end
    local zone = Workspace:WaitForChild("AutomotiveTestZone", 20) :: Instance
    local entrance = zone:WaitForChild("EntreeProprieteEssai", 10) :: BasePart
    rootPart().CFrame = CFrame.new(entrance.Position + Vector3.new(0, 3, 0))
    task.wait(1.2)
    call(progression, "Enter", { OwnerUserId = player.UserId, PropertyId = propertyId })
    local out = call(progression, "TakeOut", { VehicleId = ownId })
    call(progression, "Exit", {})
    local own: Model? = nil
    waitFor(function()
        for _, item in Workspace:GetDescendants() do
            if item:IsA("Model") and item:GetAttribute("PersonalVehicleId") == ownId then
                own = item
            end
        end
        return own ~= nil
    end, 10)
    record("drift.vehicule_personnel", own ~= nil, describe(out) .. " " .. tostring(ownId))
    if own == nil or not board(own :: Model) then
        record("drift.embarquement", false)
        return
    end
    -- Rejoindre le départ de l'épreuve en roulant (aucun déplacement du véhicule par le test).
    local course = RaceCourses.get("DEV-DRIFT")
    local start = course.Points[1]
    local reached = driveTo(start, 30, 6, 90)
    record("drift.depart_rejoint_en_roulant", reached, string.format("(%.0f, %.0f) m", start.X, start.Z))
    local join = call(racing, "Join", { CourseId = "DEV-DRIFT", Kind = "Official", Mode = "Protected" })
    record("drift.inscription_officielle", join.Status == "Ok", describe(join))
    if join.Status ~= "Ok" then
        return
    end
    waitFor(function()
        return view ~= nil
    end, 10)
    local ready = call(racing, "Ready", { Ready = true })
    record("drift.pret", ready.Status == "Ok", describe(ready))
    -- Demande « prêt » après le verrouillage (compte à rebours engagé).
    local locked = waitFor(function()
        return view ~= nil and (view.State == "Countdown" or view.State == "Running")
    end, 60)
    record("drift.verrouillage", locked, view and view.State)
    local late = call(racing, "Ready", { Ready = false })
    record(
        "drift.pret_apres_verrouillage_refuse",
        late.Status ~= "Ok" and late.Error == "RaceAlreadyLocked",
        describe(late)
    )
    local lateLeave = call(racing, "Leave", {})
    record(
        "drift.desinscription_apres_verrouillage_refusee",
        lateLeave.Status ~= "Ok",
        describe(lateLeave) .. " (l'abandon reste possible par « Abandonner »)"
    )
    local stillIn = view and view.Me and view.Me.Status
    record("drift.engagement_intact_apres_refus", stillIn ~= nil and stillIn ~= "Abandoned", tostring(stillIn))
    -- Départ puis dérive jusqu'à la fin de l'épreuve.
    waitFor(function()
        local now = Workspace:GetServerTimeNow()
        return view ~= nil and view.State == "Running" and (view.StartT == nil or now >= view.StartT)
    end, 30)
    local c = view and view.DriftCenter
    center = if c then Vector3.new(c.X * S, 0, c.Z * S) else Vector3.new(-84 * S, 0, -126 * S)
    trace("centre de dérive " .. HttpService:JSONEncode(c or {}))
    mode = "drift"
    setPhase("approach")
    local began = os.clock()
    local lastShot = 0
    local bestLive = 0
    while results == nil and os.clock() - began < 200 do
        local me = view and view.Me or {}
        if type(me.Drift) == "table" and type(me.Drift.Total) == "number" then
            bestLive = math.max(bestLive, me.Drift.Total)
        elseif type(me.Score) == "number" then
            bestLive = math.max(bestLive, me.Score)
        end
        if os.clock() - lastShot > 12 then
            lastShot = os.clock()
            Gui.shot("drift_" .. math.floor(os.clock() - began) .. "s", { phase = phase, kmh = math.floor(speedKmh()) })
        end
        if view and (view.State == "Finished" or view.State == "Cancelled") then
            break
        end
        task.wait(0.2)
    end
    mode = "hold"
    waitFor(function()
        return results ~= nil
    end, 20)
    local mine = results and results.Mine or {}
    local score = nil
    for _, entry in (results and results.Entries) or {} do
        if entry.UserId == player.UserId or entry.Me then
            score = entry.Score
        end
    end
    score = score or mine.Score
    record(
        "drift.score_positif_calcule_par_le_serveur",
        type(score) == "number" and score > 0,
        string.format(
            "score %s, issue %s, crédits %s ; pilote : %d lancement(s), angle max %.0f°, %.1f s en dérive ≥ 12° et ≥ 30 km/h (mesure client indicative), meilleur score affiché %s",
            tostring(score),
            tostring(mine.Outcome),
            tostring(mine.Credits),
            stats.kicks,
            stats.maxSlip,
            stats.slipTime,
            tostring(bestLive)
        )
    )
    measures.drift_resultats = HttpService:JSONEncode(results or {})
    Gui.shot("drift_resultats", {})
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
    record("drift.execution", false, err)
end
VehicleController.setTestInputProvider(nil)
for _, shot in Gui.report().shots do
    record(
        "drift.capture." .. shot.name,
        true,
        string.format("(%d, %d, %d) st, %s", shot.x, shot.y, shot.z, tostring(shot.context))
    )
end
reportEvent:FireServer({ vehicle = "drift", steps = steps, measures = measures })
