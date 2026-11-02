-- Essais CLIENT du lot 0.2 (session « lot02 »), injectés par le pilote dans le
-- Studio de test uniquement. Comme ScenarioClient, ce script conduit les VRAIS
-- véhicules par le vrai chemin du jeu : seule la lecture clavier/manette est
-- remplacée (setTestInputProvider) et les touches ponctuelles (rapports, aides,
-- caméra) passent par les MÊMES gestionnaires que les liaisons clavier/manette
-- (invokeActionForTest). La lecture réelle des périphériques reste un essai humain.

local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local function waitFor(predicate: () -> boolean, timeout: number): boolean
    local start = os.clock()
    while os.clock() - start < timeout do
        if predicate() then
            return true
        end
        task.wait()
    end
    return predicate()
end

waitFor(function()
    return ReplicatedStorage:GetAttribute("AWTestSession") ~= nil
end, 15)
if ReplicatedStorage:GetAttribute("AWTestSession") ~= "lot02" then
    return
end

local steps, measures = {}, {}
local function record(name: string, ok: boolean, detail: any, knownLimitation: string?)
    table.insert(steps, {
        name = name,
        ok = ok,
        detail = if detail ~= nil then tostring(detail) else nil,
        known = if not ok then knownLimitation else nil,
    })
end

local OUR_CODE_MARKERS = { "AutomotiveWorld", "ReplicatedStorage.Shared", "AW_Test" }
local errors = {}
LogService.MessageOut:Connect(function(message, messageType)
    if messageType ~= Enum.MessageType.MessageError then
        return
    end
    for _, marker in OUR_CODE_MARKERS do
        if string.find(message, marker, 1, true) then
            table.insert(errors, message)
            return
        end
    end
end)

local reportEvent = ReplicatedStorage:WaitForChild("AWTestReport", 30)
local seatFallback = ReplicatedStorage:WaitForChild("AWTestSeatFallback", 30)
local signalEvent = ReplicatedStorage:WaitForChild("AWTestSignal", 30)
local remotes = ReplicatedStorage:WaitForChild("AutomotiveWorldRemotes", 30)
local actionRemote = remotes:WaitForChild("VehicleAction", 10)
local noticeRemote = remotes:WaitForChild("VehicleNotice", 10)

local notices = {}
noticeRemote.OnClientEvent:Connect(function(key)
    table.insert(notices, { key = key, at = os.clock() })
end)
local function noticeSince(key: string, since: number): boolean
    for _, notice in notices do
        if notice.key == key and notice.at >= since then
            return true
        end
    end
    return false
end

local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local VehicleController = require(
    player
        :WaitForChild("PlayerScripts")
        :WaitForChild("AutomotiveWorldClient", 20)
        :WaitForChild("Vehicles")
        :WaitForChild("VehicleController", 10)
) :: any
local function snapshot()
    return VehicleController.getTestSnapshot()
end
local function invoke(action: string)
    VehicleController.invokeActionForTest(action)
end

local folder = Workspace:WaitForChild("VehiculesEssai", 20)
local camera = Workspace.CurrentCamera

-- Commande injectée.
local command = { Throttle = 0, Brake = 0, Steer = 0, Handbrake = false, Clutch = 0 }
local function setCommand(throttle: number, brake: number, steer: number, handbrake: boolean?, clutch: number?)
    command.Throttle, command.Brake, command.Steer = throttle, brake, steer
    command.Handbrake = handbrake == true
    command.Clutch = clutch or 0
end

local model: Model = nil :: any
local root: BasePart = nil :: any

local function bearingTo(target: Vector3): number
    local localTarget = root.CFrame:PointToObjectSpace(target)
    return math.atan2(localTarget.X, -localTarget.Z)
end

-- Régulateur : cap vers une cible, vitesse visée (pédales progressives).
local function drive(target: Vector3, targetKmh: number, clutch: number?)
    local s = snapshot()
    local steer = math.clamp(bearingTo(target) * 2.2, -1, 1)
    local gap = targetKmh - s.SpeedKmh
    if gap > 0 then
        setCommand(math.clamp(gap * 0.08, 0.05, 1), 0, steer, false, clutch)
    else
        setCommand(0, math.clamp(-gap * 0.08, 0, 0.6), steer, false, clutch)
    end
end

-- Arrêt : frein (embrayage enfoncé, sans effet hors boîte manuelle). En marche
-- arrière d'une boîte « maintien du frein » (A3), « freiner » ferait reculer :
-- on n'utilise alors que le frein à main.
local function stop(timeout: number)
    local holdBrake = snapshot().Gear < 0
        and (
            model:GetAttribute("DefinitionId") == "proto_p01"
            or model:GetAttribute("DefinitionId") == "proto_p03"
            or model:GetAttribute("DefinitionId") == "proto_p01_cvt"
        )
    if holdBrake then
        setCommand(0, 0, 0, true, 1)
    else
        setCommand(0, 1, 0, false, 1)
    end
    waitFor(function()
        return snapshot().SpeedKmh < 1
    end, timeout)
    setCommand(0, 0, 0, true, 1)
end

local function triggerPrompt(target: Model, attempt: number)
    local targetRoot = target.PrimaryPart :: BasePart
    local door = targetRoot:FindFirstChild("DriverDoor") :: Attachment
    local prompt = door:FindFirstChild("EnterPrompt") :: ProximityPrompt
    character:PivotTo(CFrame.new(door.WorldPosition + Vector3.new(0, 1.5, 0) - targetRoot.CFrame.RightVector))
    task.wait(if attempt == 1 then 0.8 else 1.5)
    pcall(function()
        prompt:InputHoldBegin()
        task.wait(prompt.HoldDuration + 0.3)
        prompt:InputHoldEnd()
    end)
end

local function board(stage: string): boolean
    setCommand(0, 0, 0, true)
    for attempt = 1, 2 do
        triggerPrompt(model, attempt)
        if waitFor(function()
            return snapshot().Driving and snapshot().SimulationActive
        end, 5) then
            VehicleController.setTestInputProvider(function()
                return table.clone(command)
            end)
            return true
        end
    end
    seatFallback:FireServer(model)
    local ok = waitFor(function()
        return snapshot().Driving and snapshot().SimulationActive
    end, 6)
    record("client.lot02_" .. stage .. "_embarquement_invite", false, if ok then "secours serveur" else "échec")
    if ok then
        VehicleController.setTestInputProvider(function()
            return table.clone(command)
        end)
    end
    return ok
end

local function leave()
    stop(10)
    task.wait(0.4)
    actionRemote:FireServer("Exit")
    waitFor(function()
        return not snapshot().Driving and humanoid.SeatPart == nil
    end, 6)
    VehicleController.setTestInputProvider(nil)
    task.wait(1)
end

-- Aide activée par le MÊME gestionnaire que la touche (1, 2, 3) ; attend la
-- confirmation du serveur (attribut) et la prise en compte par la simulation.
local AID_ACTIONS = {
    Abs = "AWVehicleAidAbs",
    TractionControl = "AWVehicleAidTractionControl",
    StabilityControl = "AWVehicleAidStabilityControl",
}
local function setAid(aid: string, enabled: boolean): boolean
    if (snapshot().Aids[aid] == true) == enabled then
        return true
    end
    invoke(AID_ACTIONS[aid])
    return waitFor(function()
        return (snapshot().Aids[aid] == true) == enabled
    end, 3)
end

local function stageDone(stage: string)
    signalEvent:FireServer("AW02Done:" .. stage)
end

local function fmt(value: number?, pattern: string?): string
    if value == nil or value ~= value then
        return "—"
    end
    return string.format(pattern or "%.2f", value)
end

-- ÉTAPES ---------------------------------------------------------------------

-- Boîte : départ arrêté, 0–100 km/h (ou vitesse max sur 300 m), passages,
-- arrêt, marche arrière selon A3, énergie consommée.
local function gearboxStage(stage: string)
    local s = snapshot()
    local id = s.DefinitionId
    local start = root.Position
    local manual = id == "proto_p02"
    local sequential = id == "proto_p01_seq"
    local selector = manual or sequential or id == "proto_p01_dct"

    record("client." .. stage .. "_moteur_demarre", s.EngineRunning, "moteur en marche à l'embarquement")

    if manual then
        -- Passage refusé sans embrayage (au neutre, pédale relâchée).
        setCommand(0, 0, 0, true, 0)
        task.wait(0.5)
        invoke("AWVehicleShiftUp")
        task.wait(0.3)
        record(
            "client." .. stage .. "_manuelle_passage_refuse_sans_embrayage",
            snapshot().Gear == 0,
            string.format("rapport %d après la demande sans embrayage", snapshot().Gear)
        )
        -- Calage volontaire : rapport engagé, embrayage lâché d'un coup sans gaz.
        setCommand(0, 0, 0, true, 1)
        task.wait(0.4)
        invoke("AWVehicleShiftUp")
        local engaged = waitFor(function()
            return snapshot().Gear == 1
        end, 1)
        setCommand(0, 0, 0, true, 0)
        local stalled = waitFor(function()
            return snapshot().EngineStalled
        end, 3)
        setCommand(0, 0, 0, true, 1)
        local restarted = waitFor(function()
            return snapshot().EngineRunning
        end, 3)
        record(
            "client." .. stage .. "_manuelle_calage_et_relance",
            engaged and stalled and restarted,
            string.format(
                "1re engagée %s, calé %s, relancé embrayage enfoncé %s",
                tostring(engaged),
                tostring(stalled),
                tostring(restarted)
            )
        )
        task.wait(0.3)
    elseif sequential then
        invoke("AWVehicleShiftUp")
        task.wait(0.2)
    end

    -- Départ et accélération sur la ligne droite.
    local launchAt = os.clock()
    local reached: number? = nil
    local gears, maxGear, maxRpm = {}, 0, 0
    local clutch = if manual then 1 else 0
    local shifting = false
    local lastGear = snapshot().Gear
    local done = waitFor(function()
        local now = snapshot()
        maxGear = math.max(maxGear, now.Gear)
        maxRpm = math.max(maxRpm, now.EngineRpm)
        if now.Gear ~= lastGear then
            table.insert(gears, now.Gear)
            lastGear = now.Gear
        end
        if reached == nil and now.SpeedKmh >= 100 then
            reached = os.clock() - launchAt
        end
        local target = Vector3.new(start.X, 0, root.Position.Z - 80)
        local steer = math.clamp(bearingTo(target) * 2.2, -1, 1)
        if manual then
            if not shifting and now.EngineRpm > 3900 and now.Gear < 6 and now.Gear >= 1 then
                shifting = true
                task.spawn(function()
                    clutch = 1
                    task.wait(0.15)
                    invoke("AWVehicleShiftUp")
                    task.wait(0.05)
                    for i = 1, 8 do
                        clutch = 1 - i / 8
                        task.wait(0.05)
                    end
                    shifting = false
                end)
            elseif not shifting and clutch > 0 then
                clutch = math.max(0, clutch - 1 / 60 / 0.9)
            end
            setCommand(if shifting then 0.2 else 1, 0, steer, false, clutch)
        else
            if sequential and now.EngineRpm > 6800 and now.Gear < 6 then
                invoke("AWVehicleShiftUp")
            end
            setCommand(1, 0, steer, false)
        end
        return reached ~= nil or (root.Position - start).Magnitude > 1000
    end, 45)
    measures[stage .. "_0_100_s"] = reached
    measures[stage .. "_rapport_max"] = maxGear
    measures[stage .. "_regime_max"] = maxRpm
    record(
        "client." .. stage .. "_0_100_kmh",
        done and reached ~= nil and not snapshot().EngineStalled,
        string.format(
            "%s s ; rapports vus %s ; régime max %d",
            fmt(reached),
            table.concat(gears, ">"),
            math.floor(maxRpm)
        )
    )
    local expectedGears = if id == "proto_p03" or id == "proto_p01_cvt" then 1 else 3
    record("client." .. stage .. "_passages", maxGear >= expectedGears, "rapport max " .. maxGear)

    if id == "proto_p01_cvt" then
        local ratio = snapshot().CvtRatio
        record(
            "client." .. stage .. "_cvt_rapport_variable",
            ratio < 2.5 and ratio > 0.45,
            string.format("rapport %.3f à 100 km/h", ratio)
        )
    end

    -- Électrique : lâcher 3 s (récupération), puis freinage.
    if id == "proto_p03" then
        local recoveredBefore = snapshot().EnergyRecovered
        local speedBefore = snapshot().SpeedKmh
        setCommand(0, 0, 0)
        task.wait(3)
        record(
            "client." .. stage .. "_recuperation_au_lacher",
            snapshot().EnergyRecovered > recoveredBefore and snapshot().SpeedKmh < speedBefore - 4,
            string.format(
                "%.1f → %.1f km/h en 3 s, %.4f kWh récupérés",
                speedBefore,
                snapshot().SpeedKmh,
                snapshot().EnergyRecovered - recoveredBefore
            )
        )
    end

    -- Arrêt (manuelle : embrayage enfoncé pour ne pas caler).
    setCommand(0, 1, 0, false, if manual then 1 else 0)
    waitFor(function()
        return snapshot().SpeedKmh < 1
    end, 15)
    setCommand(0, 0, 0, true, if manual then 1 else 0)
    task.wait(0.8)

    -- Marche arrière (A3).
    local reverseStart = root.Position
    local reversed = false
    if selector then
        for _ = 1, 8 do
            if snapshot().Gear == -1 then
                break
            end
            invoke("AWVehicleShiftDown")
            task.wait(0.2)
        end
        local inReverse = snapshot().Gear == -1
        for i = 1, 20 do
            setCommand(0.45, 0, 0, false, if manual then math.max(0, 1 - i / 15) else 0)
            task.wait(0.1)
        end
        reversed = inReverse and (root.Position - reverseStart):Dot(root.CFrame.LookVector) < -1
    else
        setCommand(0, 1, 0)
        waitFor(function()
            return snapshot().Gear == -1
        end, 2)
        setCommand(0, 0.5, 0)
        task.wait(2)
        reversed = snapshot().Gear == -1 and (root.Position - reverseStart):Dot(root.CFrame.LookVector) < -1
    end
    record(
        "client." .. stage .. "_marche_arriere",
        reversed,
        string.format(
            "%s ; recul %.1f st",
            if selector then "sélecteur" else "maintien du frein",
            (root.Position - reverseStart).Magnitude
        )
    )
    stop(6)
    local energyUsed = snapshot().EnergyUsed
    measures[stage .. "_energie_consommee"] = energyUsed
    record("client." .. stage .. "_energie_consommee", energyUsed > 0, string.format("%.4f (L ou kWh)", energyUsed))
end

-- Aides : état par défaut, activation/désactivation, HUD.
local function aidsStateStage(stage: string)
    local s = snapshot()
    record(
        "client.aides_desactivees_par_defaut",
        s.Aids.Abs == false and s.Aids.TractionControl == false and s.Aids.StabilityControl == false,
        s.HudSystems
    )
    record(
        "client.hud_aides_desactivees",
        string.find(s.HudSystems, "ABS : désactivé", 1, true) ~= nil
            and string.find(s.HudSystems, "ESP : désactivé", 1, true) ~= nil,
        s.HudSystems
    )
    local allOn = setAid("Abs", true) and setAid("TractionControl", true) and setAid("StabilityControl", true)
    task.wait(0.4)
    local hud = snapshot().HudSystems
    record(
        "client.aides_activation_confirmee_serveur",
        allOn
            and string.find(hud, "ABS : activé", 1, true) ~= nil
            and string.find(hud, "ESP : activé", 1, true) ~= nil,
        hud
    )
    local allOff = setAid("Abs", false) and setAid("TractionControl", false) and setAid("StabilityControl", false)
    record("client.aides_desactivation", allOff, snapshot().HudSystems)
    -- Réglage à la manette (croix gauche puis droite) : même chemin serveur.
    invoke("AWVehicleSelectSetting")
    invoke("AWVehicleApplySetting")
    local viaPad = waitFor(function()
        return snapshot().Aids.TractionControl == true
    end, 3)
    record("client.aides_reglage_manette", viaPad, "croix gauche (sélection 2e réglage) puis droite")
    setAid("TractionControl", false)
    -- Récupération réglable (G).
    local level = snapshot().RegenLevel
    invoke("AWVehicleRegen")
    local changed = waitFor(function()
        return snapshot().RegenLevel ~= level
    end, 3)
    record("client.recuperation_reglable", changed, string.format("niveau %d → %d", level, snapshot().RegenLevel))
    local _ = stage
end

local function absentAidStage(_stage: string)
    local since = os.clock()
    invoke("AWVehicleAidAbs")
    local refused = waitFor(function()
        return noticeSince("AidAbsent", since)
    end, 3)
    task.wait(0.5)
    local s = snapshot()
    record(
        "client.aide_absente_refusee",
        refused and s.Aids.Abs == false and string.find(s.HudSystems, "ABS : absent", 1, true) ~= nil,
        s.HudSystems
    )
end

-- Freinage en ligne droite depuis 60 km/h ; renvoie distance et fraction de blocage.
local function brakeRun(brakeZ: number?): (number, number, number)
    local start = root.Position
    waitFor(function()
        drive(Vector3.new(start.X, 0, root.Position.Z - 80), 62)
        local reachedSpeed = snapshot().SpeedKmh >= 60
        if brakeZ then
            return reachedSpeed and root.Position.Z <= brakeZ
        end
        return reachedSpeed
    end, 20)
    local brakeStart = root.Position
    local startSpeed = snapshot().SpeedKmh
    local frames, locked = 0, 0
    setCommand(0, 1, 0)
    waitFor(function()
        local s = snapshot()
        if s.SpeedKmh > 8 then
            frames += 1
            if (s.WheelSlip[1] or 0) < -0.5 or (s.WheelSlip[2] or 0) < -0.5 then
                locked += 1
            end
        end
        return s.SpeedKmh < 0.5
    end, 15)
    local distance = (root.Position - brakeStart).Magnitude * 0.28
    return distance, locked / math.max(frames, 1), startSpeed
end

local brakeResults = {}
local function absStage(stage: string, enabled: boolean)
    setAid("Abs", enabled)
    local distance, lockFraction, speed = brakeRun(60)
    local wet = snapshot().WetWheels
    brakeResults[stage] = { Distance = distance, Lock = lockFraction, Speed = speed }
    measures[stage .. "_distance_m"] = distance
    measures[stage .. "_blocage_avant"] = lockFraction
    record(
        "client." .. stage .. "_freinage_mouille",
        distance > 0 and wet >= 2,
        string.format(
            "%.1f m depuis %.0f km/h, roues avant bloquées %.0f %% du temps, roues sur mouillé %d",
            distance,
            speed,
            lockFraction * 100,
            wet
        )
    )
end

local tcResults = {}
local function tcStage(stage: string, enabled: boolean)
    setAid("TractionControl", enabled)
    -- Démarrage en 1re, embrayage relâché en 0,6 s, pleine charge 4 s, sur mouillé.
    setCommand(0, 0, 0, true, 1)
    task.wait(0.4)
    invoke("AWVehicleShiftUp")
    waitFor(function()
        return snapshot().Gear == 1
    end, 1)
    local slipSum, count, peak = 0, 0, 0
    local started = os.clock()
    waitFor(function()
        local t = os.clock() - started
        setCommand(1, 0, 0, false, math.max(0, 1 - t / 0.6))
        if t > 1 then
            local s = snapshot()
            local slip = math.max(s.WheelSlip[1] or 0, s.WheelSlip[2] or 0)
            slipSum += slip
            count += 1
            peak = math.max(peak, slip)
        end
        return t > 4 or snapshot().Gear ~= 1
    end, 6)
    local mean = slipSum / math.max(count, 1)
    tcResults[stage] = { Mean = mean, Speed = snapshot().SpeedKmh }
    measures[stage .. "_glissement_moyen_av"] = mean
    record(
        "client." .. stage .. "_demarrage_mouille",
        count > 0 and not snapshot().EngineStalled,
        string.format(
            "glissement moyen AV %.2f, max %.2f, %.1f km/h à 4 s, antipatinage %s",
            mean,
            peak,
            snapshot().SpeedKmh,
            if snapshot().AidActivity.TractionControl then "en action" else "inactif à la fin"
        )
    )
    setCommand(0, 1, 0, false, 1)
    waitFor(function()
        return snapshot().SpeedKmh < 1
    end, 10)
    setCommand(0, 0, 0, true, 1)
end

local escResults = {}
local function escStage(stage: string, enabled: boolean)
    setAid("StabilityControl", enabled)
    local start = root.Position
    waitFor(function()
        drive(Vector3.new(start.X, 0, root.Position.Z - 80), 62)
        return snapshot().SpeedKmh >= 60
    end, 15)
    -- Coup de volant avec frein à main bref sur mouillé.
    local peakBeta, peakYaw = 0, 0
    local escActive = false
    local started = os.clock()
    waitFor(function()
        local t = os.clock() - started
        if t < 0.6 then
            setCommand(0.3, 0, 0.8, t > 0.15 and t < 0.45)
        else
            setCommand(0.2, 0, 0.25)
        end
        local velocity = root.AssemblyLinearVelocity
        local forward = velocity:Dot(root.CFrame.LookVector)
        local lateral = velocity:Dot(root.CFrame.RightVector)
        if velocity.Magnitude > 3 then
            peakBeta = math.max(peakBeta, math.abs(math.atan2(lateral, math.max(forward, 1))))
        end
        peakYaw = math.max(peakYaw, math.abs(snapshot().YawRate))
        escActive = escActive or snapshot().AidActivity.StabilityControl == true
        return t > 3
    end, 5)
    escResults[stage] = { Beta = peakBeta, Yaw = peakYaw }
    measures[stage .. "_derive_max_deg"] = math.deg(peakBeta)
    record(
        "client." .. stage .. "_survirage_provoque",
        snapshot().Driving,
        string.format(
            "dérive max %.1f°, lacet max %.2f rad/s, ESP intervenu %s",
            math.deg(peakBeta),
            peakYaw,
            tostring(escActive)
        )
    )
    if enabled then
        record("client.esp_intervient_en_survirage", escActive, "indicateur d'action de l'ESP pendant l'essai")
    end
end

local function dryBrakeStage(_stage: string)
    setAid("Abs", false)
    local distance, lockFraction, speed = brakeRun(nil)
    brakeResults.sec = { Distance = distance, Lock = lockFraction, Speed = speed }
    measures.freinage_sec_distance_m = distance
    local wet = brakeResults.abs_off
    record(
        "client.mouille_freine_plus_long_que_sec",
        wet ~= nil and wet.Distance > distance * 1.1,
        string.format(
            "sec %.1f m (depuis %.0f km/h), mouillé %s m",
            distance,
            speed,
            if wet then fmt(wet.Distance, "%.1f") else "—"
        )
    )
end

local function slopeStage(stage: string, useHandbrake: boolean)
    local start = root.Position
    if useHandbrake then
        setCommand(0, 0, 0, true)
    else
        setCommand(0, 0.5, 0)
    end
    task.wait(1)
    local held = root.Position
    task.wait(8)
    local drift = (root.Position - held).Magnitude
    measures[stage .. "_glissement_st"] = drift
    record(
        "client." .. stage .. "_maintien_en_pente",
        drift < 0.1 and snapshot().Gear ~= -1,
        string.format("glissement %.3f st en 8 s (rapport %d)", drift, snapshot().Gear)
    )
    -- Relâché (neutre, sans frein) : le véhicule doit redescendre.
    setCommand(0, 0, 0)
    task.wait(2.5)
    local rolled = (root.Position - held).Magnitude
    record(
        "client." .. stage .. "_redescend_sans_frein",
        rolled > 1,
        string.format("%.1f st en 2,5 s (départ à %.1f st du placement)", rolled, (held - start).Magnitude)
    )
    setCommand(0, 0, 0, true)
    task.wait(1)
end

local curbResults = {}
local function curbStage(stage: string)
    VehicleController.resetPerfForTest()
    local start = root.Position
    local previousVy = root.AssemblyLinearVelocity.Y
    local maxVertical, maxPitch, minGrounded = 0, 0, 4
    local lastTime = os.clock()
    waitFor(function()
        drive(Vector3.new(start.X, 0, root.Position.Z - 60), 30)
        local now = os.clock()
        local dt = now - lastTime
        lastTime = now
        local vy = root.AssemblyLinearVelocity.Y
        if dt > 0 and root.Position.Z < -50 then
            maxVertical = math.max(maxVertical, math.abs(vy - previousVy) * 0.28 / dt)
            maxPitch = math.max(maxPitch, math.abs(root.AssemblyAngularVelocity:Dot(root.CFrame.RightVector)))
            minGrounded = math.min(minGrounded, snapshot().GroundedWheels)
        end
        previousVy = vy
        return root.Position.Z < -300
    end, 40)
    local perf = snapshot().Perf
    curbResults[stage] = {
        Vertical = maxVertical,
        Pitch = maxPitch,
        Query = perf and perf.Queries.Median or 0,
        QueryP99 = perf and perf.Queries.P99 or 0,
        Step = perf and perf.Step.Median or 0,
        Fallbacks = perf and perf.SphereFallbacks or 0,
    }
    measures[stage .. "_acceleration_verticale_max_ms2"] = maxVertical
    measures[stage .. "_tangage_max_rad_s"] = maxPitch
    record(
        "client." .. stage .. "_passage_bordures",
        snapshot().Driving and root.CFrame.UpVector.Y > 0.9,
        string.format(
            "sonde %s : accél. verticale max %.1f m/s², tangage max %.2f rad/s, roues au sol min %d ; requêtes %s µs (médiane), P99 %s µs, pas complet %s µs, replis rayon %d",
            perf and perf.Probe or "?",
            maxVertical,
            maxPitch,
            minGrounded,
            fmt(curbResults[stage].Query * 1e6, "%.1f"),
            fmt(curbResults[stage].QueryP99 * 1e6, "%.1f"),
            fmt(curbResults[stage].Step * 1e6, "%.1f"),
            curbResults[stage].Fallbacks
        )
    )
end

local function crashStage(stage: string, kmh: number)
    local start = root.Position
    local impactsBefore = model:GetAttribute("DmgImpacts") or 0
    waitFor(function()
        drive(Vector3.new(start.X, 0, root.Position.Z + 60), kmh)
        return (model:GetAttribute("DmgImpacts") or 0) > impactsBefore or root.Position.Z > 200
    end, 15)
    local impactSpeed = snapshot().SpeedKmh
    task.wait(1.5)
    local s = snapshot()
    measures[stage .. "_puissance_moteur"] = s.EnginePower
    record(
        "client." .. stage .. "_degats_lus_par_la_simulation",
        (model:GetAttribute("DmgImpacts") or 0) > impactsBefore,
        string.format(
            "vitesse relevée après contact %.1f km/h ; puissance moteur %.0f %% ; tirage direction %.2f° ; HUD : %s",
            impactSpeed,
            s.EnginePower * 100,
            math.deg(s.SteeringPullRad),
            s.HudSystems
        )
    )
end

local function pairCrashStage(_stage: string)
    local start = root.Position
    local impactsBefore = model:GetAttribute("DmgImpacts") or 0
    waitFor(function()
        drive(Vector3.new(start.X, 0, root.Position.Z - 60), 25)
        return (model:GetAttribute("DmgImpacts") or 0) > impactsBefore or root.Position.Z < -60
    end, 15)
    task.wait(1.5)
    record(
        "client.degats_deux_vehicules_percuteur",
        (model:GetAttribute("DmgImpacts") or 0) > impactsBefore,
        snapshot().HudSystems
    )
end

local function emptyStage(stage: string)
    local s = snapshot()
    local start = root.Position
    local t0 = os.clock()
    local emptyAt: number? = nil
    local speedAtEmpty = 0
    waitFor(function()
        drive(Vector3.new(start.X, 0, root.Position.Z - 80), 70)
        if emptyAt == nil and not snapshot().EnergyAvailable then
            emptyAt = os.clock()
            speedAtEmpty = snapshot().SpeedKmh
        end
        return emptyAt ~= nil and os.clock() - (emptyAt :: number) > 4
    end, 60)
    -- Accélérateur à fond : aucune propulsion.
    local before = snapshot().SpeedKmh
    setCommand(1, 0, 0)
    task.wait(2)
    local after = snapshot().SpeedKmh
    local still = snapshot()
    record(
        "client." .. stage .. "_plus_de_propulsion",
        emptyAt ~= nil and after <= before + 0.5 and not still.EngineRunning,
        string.format(
            "vide après %.1f s à %.0f km/h ; pleine charge 2 s : %.1f → %.1f km/h ; moteur en marche %s ; niveau serveur %.4f",
            if emptyAt then (emptyAt :: number) - t0 else -1,
            speedAtEmpty,
            before,
            after,
            tostring(still.EngineRunning),
            still.ServerEnergyLevel
        )
    )
    local _ = s
    stop(20)
    -- Sortir puis remonter : toujours vide (aucune recharge gratuite).
    leave()
    if board(stage .. "_remontee") then
        task.wait(1)
        local again = snapshot()
        record(
            "client." .. stage .. "_toujours_vide_apres_reembarquement",
            not again.EnergyAvailable and not again.EngineRunning and again.ServerEnergyLevel <= 0,
            string.format("niveau %.4f, moteur %s", again.ServerEnergyLevel, tostring(again.EngineRunning))
        )
    end
end

local function cameraStage(_stage: string)
    local start = root.Position
    waitFor(function()
        drive(Vector3.new(start.X, 0, root.Position.Z - 80), 40)
        return snapshot().SpeedKmh > 36
    end, 20)
    local frames = {}
    local connection = RunService.RenderStepped:Connect(function(dt)
        table.insert(frames, dt)
    end)
    local names, checks = {}, {}
    local speedMin, speedMax = math.huge, 0
    local wasDriving = true
    for _ = 1, 5 do
        invoke("AWVehicleCamera")
        local settleUntil = os.clock() + 1.2
        waitFor(function()
            drive(Vector3.new(start.X, 0, root.Position.Z - 80), 40)
            local s = snapshot()
            speedMin = math.min(speedMin, s.SpeedKmh)
            speedMax = math.max(speedMax, s.SpeedKmh)
            wasDriving = wasDriving and s.Driving and s.SimulationActive
            return os.clock() > settleUntil
        end, 3)
        local name = snapshot().CameraName
        table.insert(names, name)
        local localPos = root.CFrame:PointToObjectSpace(camera.CFrame.Position)
        local forward = camera.CFrame.LookVector:Dot(root.CFrame.LookVector)
        local head = character:FindFirstChild("Head") :: BasePart?
        local hidden = if head then head.LocalTransparencyModifier else -1
        -- Vues embarquées : position de l'attachement correspondant, à une image de
        -- retard près (≈ 0,6 st à 40 km/h, mesuré), orientation vers l'avant.
        local mounts = { Cockpit = "CameraCockpit", Capot = "CameraHood", ["Pare-chocs"] = "CameraBumper" }
        local mount = if mounts[name] then root:FindFirstChild(mounts[name]) else nil
        local gap = if mount and mount:IsA("Attachment") then (localPos - mount.Position).Magnitude else math.huge
        local ok
        if name == "Cockpit" then
            ok = forward > 0.95 and gap < 1.2 and localPos.X < 0 and hidden == 1
        elseif name == "Capot" then
            ok = forward > 0.95 and gap < 1.2 and localPos.Y > 0.5 and localPos.Z < 0
        elseif name == "Pare-chocs" then
            ok = forward > 0.95 and gap < 1.2 and localPos.Y < 0.5 and localPos.Z < -5
        else
            ok = (camera.CFrame.Position - root.Position).Magnitude > 6
        end
        table.insert(
            checks,
            string.format(
                "%s:%s(x %.1f y %.1f z %.1f, avant %.2f, tête %s)",
                name,
                if ok then "ok" else "ÉCHEC",
                localPos.X,
                localPos.Y,
                localPos.Z,
                forward,
                tostring(hidden)
            )
        )
        record("client.camera_" .. string.lower((string.gsub(name, "[^%w]", ""))) .. "_coherente", ok, checks[#checks])
    end
    connection:Disconnect()
    record(
        "client.cameras_sans_perte_de_controle",
        wasDriving and speedMin > 30 and speedMax < 50 and snapshot().CameraName == "Proche",
        string.format(
            "cycle %s ; vitesse %.1f–%.1f km/h pendant les bascules",
            table.concat(names, " → "),
            speedMin,
            speedMax
        )
    )
    table.sort(frames)
    local function percentile(p: number): number
        return frames[math.clamp(math.ceil(p * #frames), 1, math.max(#frames, 1))] or 0
    end
    measures.temps_image_mediane_ms = percentile(0.5) * 1000
    measures.temps_image_p95_ms = percentile(0.95) * 1000
    measures.temps_image_p99_ms = percentile(0.99) * 1000
    record(
        "client.info_temps_image_vm",
        true,
        string.format(
            "%d images : médiane %.2f ms, P95 %.2f ms, P99 %.2f ms — VM sans accélération graphique : NON représentatif du matériel de référence",
            #frames,
            percentile(0.5) * 1000,
            percentile(0.95) * 1000,
            percentile(0.99) * 1000
        )
    )
    local perf = snapshot().Perf
    if perf then
        record(
            "client.info_cout_simulation_vehicule",
            true,
            string.format(
                "pas complet médiane %.1f µs, P95 %.1f µs, P99 %.1f µs (n=%d) ; requêtes %d par pas, médiane %.1f µs",
                perf.Step.Median * 1e6,
                perf.Step.P95 * 1e6,
                perf.Step.P99 * 1e6,
                perf.Step.Count,
                perf.QueriesPerStep,
                perf.Queries.Median * 1e6
            )
        )
    end
    -- Chaque action a une touche ET un bouton de manette (aides au clavier :
    -- touches 1/2/3 ; à la manette : croix gauche/droite).
    local bindings = VehicleController.bindingsForTest()
    local missing = {}
    for name, keys in bindings do
        local keyboard, gamepad = false, false
        for _, key in keys do
            if string.find(key, "Button") or string.find(key, "DPad") then
                gamepad = true
            else
                keyboard = true
            end
        end
        local aidOnly = string.find(name, "Aid") or name == "AWVehicleRegen"
        local padOnly = name == "AWVehicleSelectSetting" or name == "AWVehicleApplySetting"
        if not ((keyboard or padOnly) and (gamepad or aidOnly)) then
            table.insert(missing, name)
        end
    end
    record(
        "client.commandes_clavier_et_manette",
        #missing == 0,
        if #missing == 0 then "toutes couvertes" else table.concat(missing, ", ")
    )
end

local STAGES: { [string]: (string) -> () } = {
    aides_etat = aidsStateStage,
    aide_absente = absentAidStage,
    abs_off = function(stage)
        absStage(stage, false)
    end,
    abs_on = function(stage)
        absStage(stage, true)
    end,
    tc_off = function(stage)
        tcStage(stage, false)
    end,
    tc_on = function(stage)
        tcStage(stage, true)
    end,
    esc_off = function(stage)
        escStage(stage, false)
    end,
    esc_on = function(stage)
        escStage(stage, true)
    end,
    freinage_sec = dryBrakeStage,
    pente_p01_frein_a_main = function(stage)
        slopeStage(stage, true)
    end,
    pente_p02_frein = function(stage)
        slopeStage(stage, false)
    end,
    bordures_rayon = curbStage,
    bordures_sphere = curbStage,
    degats_mur_15 = function(stage)
        crashStage(stage, 15)
    end,
    degats_mur_35 = function(stage)
        crashStage(stage, 35)
    end,
    degats_deux_vehicules = pairCrashStage,
    panne_seche_p01 = emptyStage,
    batterie_vide_p03 = emptyStage,
    cameras = cameraStage,
}

-- BOUCLE DES ÉTAPES ------------------------------------------------------------

local handled = {}
local lastActivity = os.clock()
while os.clock() - lastActivity < 240 do
    local stage = ReplicatedStorage:GetAttribute("AW02Stage")
    if type(stage) == "string" and not handled[stage] then
        handled[stage] = true
        lastActivity = os.clock()
        model = folder:WaitForChild(ReplicatedStorage:GetAttribute("AW02Vehicle"), 10) :: Model
        root = model.PrimaryPart :: BasePart
        if board(stage) then
            local routine = STAGES[stage]
            if routine == nil and string.sub(stage, 1, 6) == "boite_" then
                routine = gearboxStage
            end
            local ok, err = pcall(routine or function() end, stage)
            if not ok then
                record("client." .. stage .. "_execution", false, tostring(err))
            end
            leave()
        else
            record("client." .. stage .. "_embarquement", false, "impossible")
        end
        stageDone(stage)
        lastActivity = os.clock()
    end
    task.wait(0.2)
    if ReplicatedStorage:GetAttribute("AW02Finished") then
        break
    end
end

-- Comparaisons finales (aides avec / sans, sondes).
local absOff, absOn = brakeResults.abs_off, brakeResults.abs_on
if absOff and absOn then
    record(
        "client.abs_evite_le_blocage",
        absOn.Lock < 0.15 and absOff.Lock > absOn.Lock,
        string.format(
            "blocage AV sans ABS %.0f %%, avec %.0f %% ; distances %.1f / %.1f m",
            absOff.Lock * 100,
            absOn.Lock * 100,
            absOff.Distance,
            absOn.Distance
        )
    )
end
local tcOff, tcOn = tcResults.tc_off, tcResults.tc_on
if tcOff and tcOn then
    record(
        "client.antipatinage_limite_le_patinage",
        tcOn.Mean < tcOff.Mean * 0.7,
        string.format(
            "glissement moyen %.2f sans, %.2f avec ; %.1f / %.1f km/h à 4 s",
            tcOff.Mean,
            tcOn.Mean,
            tcOff.Speed,
            tcOn.Speed
        )
    )
end
local escOff, escOn = escResults.esc_off, escResults.esc_on
if escOff and escOn then
    record(
        "client.esp_reduit_la_derive",
        escOn.Beta < escOff.Beta,
        string.format(
            "dérive max %.1f° sans, %.1f° avec ; lacet max %.2f / %.2f rad/s",
            math.deg(escOff.Beta),
            math.deg(escOn.Beta),
            escOff.Yaw,
            escOn.Yaw
        )
    )
end
local ray, sphere = curbResults.bordures_rayon, curbResults.bordures_sphere
if ray and sphere then
    record(
        "client.info_sondes_rayon_contre_sphere",
        true,
        string.format(
            "accél. verticale max %.1f / %.1f m/s² ; tangage max %.2f / %.2f rad/s ; requêtes médiane %.1f / %.1f µs (rayon / sphère)",
            ray.Vertical,
            sphere.Vertical,
            ray.Pitch,
            sphere.Pitch,
            ray.Query * 1e6,
            sphere.Query * 1e6
        )
    )
end

record("client.aucune_erreur_execution", #errors == 0, table.concat(errors, " || "))
reportEvent:FireServer({ vehicle = nil, steps = steps, measures = measures })
