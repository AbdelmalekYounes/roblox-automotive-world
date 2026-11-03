-- Essais CLIENT du lot 0.8 (session « lot08 », 1 joueur), écrits au lot 0.9 et
-- injectés par le pilote dans le Studio de test uniquement.
-- 1. Parcours d'arrivée de bout en bout par le VRAI canal (AWOnboarding) : étapes,
--    essai d'un candidat, véhicule d'essai refusé en course, choix confirmé, refus
--    d'un second choix, propriété, exercices.
-- 2. Mode photo : refus en roulant, ouverture à pied, caméra restaurée à l'identique.
-- 3. Radio : station indisponible refusée, extinction acceptée (conducteur).
-- 4. Banc des 18 modèles proposés sur la ligne droite d'essai : 0–100 km/h, vitesse
--    à 230 m, distance d'arrêt. VRAIE simulation (seule la lecture clavier/manette
--    est remplacée) : mesures automatisées, pas un essai humain ni un ressenti.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local sessionStart = os.clock()
while ReplicatedStorage:GetAttribute("AWTestSession") == nil and os.clock() - sessionStart < 15 do
    task.wait()
end
if ReplicatedStorage:GetAttribute("AWTestSession") ~= "lot08" then
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
        task.wait(0.05)
    end
    return predicate()
end
local function trace(message: string)
    print(string.format("[AW_Test] lot08 %.1f s : %s", os.clock() - sessionStart, message))
end

local S = 1 / 0.28
local reportEvent = ReplicatedStorage:WaitForChild("AWTestReport", 30)
local signalEvent = ReplicatedStorage:WaitForChild("AWTestSignal", 30)
local onboarding = (ReplicatedStorage:WaitForChild("AWOnboarding", 30) :: Instance):WaitForChild(
        "Request",
        10
    ) :: RemoteFunction
local racing = (ReplicatedStorage:WaitForChild("AWRacing", 30) :: Instance):WaitForChild(
        "Request",
        10
    ) :: RemoteFunction
local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehicleDefinitions = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleDefinitions")) :: any
local WorkingCatalog = require(Shared.Vehicles:WaitForChild("Definitions"):WaitForChild("WorkingCatalog")) :: any
local client = player:WaitForChild("PlayerScripts"):WaitForChild("AutomotiveWorldClient")
local VehicleController = require(client:WaitForChild("Vehicles"):WaitForChild("VehicleController", 10)) :: any
local UI = client:WaitForChild("UI")
local PhotoMode = require(UI:WaitForChild("PhotoMode")) :: any
local UIManager = require(UI:WaitForChild("UIManager")) :: any
local RadioController = require(client:WaitForChild("Audio"):WaitForChild("RadioController")) :: any

local function ask(remote: RemoteFunction, action: string, payload: any?): any
    local data = payload or {}
    data.RequestId = data.RequestId or HttpService:GenerateGUID(false)
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
local function rootPart(): BasePart
    local character = player.Character or player.CharacterAdded:Wait()
    return character:WaitForChild("HumanoidRootPart", 10) :: BasePart
end

local command = { Throttle = 0, Brake = 1, Steer = 0, Handbrake = false, Clutch = 0 }
local function provider(): any
    return command
end

local function board(model: Model): boolean
    local body = model.PrimaryPart
    local door = body and body:FindFirstChild("DriverDoor")
    local prompt = door and door:FindFirstChild("EnterPrompt") :: ProximityPrompt?
    if prompt == nil then
        return false
    end
    rootPart().CFrame = CFrame.new((door :: Attachment).WorldPosition + Vector3.new(0, 2, 0))
    task.wait(0.8)
    prompt:InputHoldBegin()
    task.wait(prompt.HoldDuration + 0.3)
    prompt:InputHoldEnd()
    return waitFor(function()
        return model:GetAttribute("DriverUserId") == player.UserId
    end, 10)
end
local function leave()
    local humanoid = (player.Character :: Model):FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.Sit = false
        humanoid.Jump = true
    end
    task.wait(1.5)
end

-- Banc : départ arrêté, plein gaz cap au nord (−Z), passages de rapports, puis freinage.
local function bench(model: Model, modelId: string): any
    local definition = VehicleDefinitions.get(modelId)
    local kind = definition.Powertrain.Transmission.Kind
    local redline = if definition.Powertrain.Engine then definition.Powertrain.Engine.RedlineRpm else 0
    local manual = kind == "Manual"
    local sequential = kind == "Sequential"
    local body = model.PrimaryPart :: BasePart
    local start = body.Position
    VehicleController.setTestInputProvider(provider)
    command = { Throttle = 0, Brake = 0, Steer = 0, Handbrake = false, Clutch = if manual then 1 else 0 }
    task.wait(0.5)
    local launchAt = os.clock()
    local reached: number? = nil
    local shifting = false
    local maxGear = 0
    local done = waitFor(function()
        local snap = VehicleController.getTestSnapshot()
        maxGear = math.max(maxGear, snap.Gear)
        local speed = snap.SpeedKmh
        if reached == nil and speed >= 100 then
            reached = os.clock() - launchAt
        end
        local ahead = Vector3.new(start.X, 0, body.Position.Z - 80)
        local flat = Vector3.new(ahead.X - body.Position.X, 0, ahead.Z - body.Position.Z).Unit
        local forward = Vector3.new(body.CFrame.LookVector.X, 0, body.CFrame.LookVector.Z).Unit
        local steer = math.clamp(-forward:Cross(flat).Y * 2.2, -1, 1)
        local clutch = command.Clutch
        if manual then
            if os.clock() - launchAt < 1.2 and snap.Gear <= 1 then
                clutch = math.max(0, 1 - (os.clock() - launchAt) / 1.0)
            elseif not shifting and snap.EngineRpm > redline * 0.9 and snap.Gear >= 1 and snap.Gear < 6 then
                shifting = true
                task.spawn(function()
                    command.Clutch = 1
                    task.wait(0.15)
                    VehicleController.invokeActionForTest("AWVehicleShiftUp")
                    task.wait(0.05)
                    for i = 1, 8 do
                        command.Clutch = 1 - i / 8
                        task.wait(0.05)
                    end
                    shifting = false
                end)
            end
            if not shifting then
                command.Clutch = clutch
            end
        elseif sequential and snap.EngineRpm > redline * 0.92 and snap.Gear < 7 then
            VehicleController.invokeActionForTest("AWVehicleShiftUp")
        end
        command.Throttle = if shifting then 0.2 else (if manual and os.clock() - launchAt < 1.2 then 0.7 else 1)
        command.Steer = steer
        command.Brake = 0
        return (body.Position - start).Magnitude / S >= 230
    end, 40)
    local vmax = VehicleController.getTestSnapshot().SpeedKmh
    -- Freinage plein, roues droites.
    local brakeFrom = body.Position
    command = { Throttle = 0, Brake = 1, Steer = 0, Handbrake = false, Clutch = if manual then 1 else 0 }
    local stopped = waitFor(function()
        return VehicleController.getTestSnapshot().SpeedKmh < 1
    end, 20)
    local brakeM = (body.Position - brakeFrom).Magnitude / S
    VehicleController.setTestInputProvider(nil)
    return {
        ZeroToHundredS = reached,
        SpeedAt230Kmh = math.floor(vmax * 10) / 10,
        StopM = if stopped then math.floor(brakeM * 10) / 10 else nil,
        MaxGear = maxGear,
        Reached230 = done,
    }
end

local function main()
    waitFor(function()
        return ReplicatedStorage:GetAttribute("AW08_ServerReady") == true
    end, 60)

    -- ===== 1. Parcours d'arrivée =====
    local status = ask(onboarding, "Status")
    local state = status.Result or {}
    record(
        "lot08.client.candidats_dev_synthetiques",
        #(state.Candidates or {}) == 3 and state.Synthetic == true and state.Official == false,
        string.format(
            "%d candidat(s), synthétique %s, officiel %s",
            #(state.Candidates or {}),
            tostring(state.Synthetic),
            tostring(state.Official)
        )
    )
    local skipAhead = ask(onboarding, "Advance", { Step = "Phone" })
    record("lot08.client.etape_hors_ordre_refusee", skipAhead.Error == "OnboardingStepOrder", describe(skipAhead))
    for _, step in { "Welcome", "World", "Controls", "Phone", "Starters" } do
        ask(onboarding, "Advance", { Step = step })
    end
    local choose0 = ask(onboarding, "Advance", { Step = "Choose" })
    record(
        "lot08.client.choix_non_franchissable_sans_vehicule",
        choose0.Error == "OnboardingChooseStarter",
        describe(choose0)
    )
    local outside = ask(onboarding, "TestDrive", { ModelId = "wk_comete" })
    record("lot08.client.essai_hors_candidats_refuse", outside.Error == "StarterNotCandidate", describe(outside))
    -- Essai d'un candidat : véhicule temporaire marqué, refusé en course.
    local drive = ask(onboarding, "TestDrive", { ModelId = "wk_brio" })
    local trial: Model? = nil
    waitFor(function()
        local folder = Workspace:FindFirstChild("VehiculesPersonnels")
        for _, child in (folder and folder:GetChildren()) or {} do
            if child:GetAttribute("AWTestDrive") == true then
                trial = child :: Model
            end
        end
        return trial ~= nil
    end, 15)
    record("lot08.client.essai_vehicule_marque", drive.Status == "Ok" and trial ~= nil, describe(drive))
    if trial and board(trial :: Model) then
        local catalog = ask(racing, "Catalog")
        local reg = nil
        for _, course in (catalog.Result and catalog.Result.Courses) or {} do
            if course.Id == "DEV-DRAG" then
                reg = course.Registration
            end
        end
        -- Le véhicule d'essai est posé près du joueur : on y vérifie la règle (refus attendu quel que soit le lieu).
        local training = ask(racing, "CreatePrivate", { CourseId = "DEV-DRAG", Kind = "Training" })
        record(
            "lot08.client.vehicule_essai_refuse_en_course",
            training.Status ~= "Ok",
            describe(training) .. (if reg then string.format(" (inscription à %d, %d m)", reg.X, reg.Z) else "")
        )
        if training.Status == "Ok" then
            ask(racing, "Leave")
        end
        leave()
    end
    local ended = ask(onboarding, "EndTestDrive")
    local removed = waitFor(function()
        return trial == nil or (trial :: Model).Parent == nil
    end, 10)
    record("lot08.client.essai_termine_vehicule_retire", ended.Status == "Ok" and removed, describe(ended))
    -- Choix confirmé, puis second choix refusé.
    local chosen = ask(onboarding, "Choose", { ModelId = "wk_fil" })
    record("lot08.client.choix_confirme", chosen.Status == "Confirmed" or chosen.Status == "Pending", describe(chosen))
    local second = ask(onboarding, "Choose", { ModelId = "wk_brio" })
    record(
        "lot08.client.second_choix_sans_effet",
        second.Status ~= "Confirmed" and second.Status ~= "Pending",
        describe(second)
    )
    local after = (ask(onboarding, "Status").Result or {})
    record(
        "lot08.client.vehicule_de_depart_attribue",
        after.StarterChosen == true and after.StarterModel == "wk_fil" and after.PropertyGranted == true,
        string.format(
            "modèle %s, propriété %s, étape %s",
            tostring(after.StarterModel),
            tostring(after.PropertyGranted),
            after.State and after.State.Step
        )
    )
    ask(onboarding, "Advance", { Step = "Property" })
    local final = (ask(onboarding, "Status").Result or {}).State or {}
    record("lot08.client.parcours_termine", final.Step == "Done", final.Step)
    local exercise = ask(onboarding, "Exercise", { Id = "Park" })
    local fakeExercise = ask(onboarding, "Exercise", { Id = "Credits" })
    record(
        "lot08.client.exercices_sans_falsification",
        exercise.Status == "Ok" and fakeExercise.Error == "ExerciseUnknown",
        describe(exercise) .. " / " .. describe(fakeExercise)
    )

    -- ===== 2. Mode photo : à pied, caméra restaurée à l'identique =====
    local camera = Workspace.CurrentCamera
    local beforeType, beforeFov = camera.CameraType, camera.FieldOfView
    PhotoMode.request()
    local opened = waitFor(function()
        return UIManager.isOpen("Photo") and camera.CameraType == Enum.CameraType.Scriptable
    end, 5)
    task.wait(1)
    UIManager.close("Photo")
    task.wait(0.5)
    record(
        "lot08.client.photo_a_pied_et_camera_restauree",
        opened and camera.CameraType == beforeType and math.abs(camera.FieldOfView - beforeFov) < 0.01,
        string.format(
            "ouvert %s ; type %s → %s ; champ %.1f → %.1f",
            tostring(opened),
            beforeType.Name,
            camera.CameraType.Name,
            beforeFov,
            camera.FieldOfView
        )
    )

    -- ===== 3 et 4. Banc des 18 modèles (et radio, photo en roulant, sur le premier) =====
    local strip = CFrame.lookAt(Vector3.new(0, 3, -6 * S), Vector3.new(0, 3, -60 * S))
    local results = {}
    for i, spec in WorkingCatalog.Specs do
        rootPart().CFrame = strip
        task.wait(0.8)
        signalEvent:FireServer("AW08:Spawn:" .. spec.Id)
        local name = nil
        waitFor(function()
            name = ReplicatedStorage:GetAttribute("AW08_Spawned")
            return type(name) == "string" and string.find(name, spec.Id, 1, true) ~= nil
        end, 15)
        local folder = Workspace:FindFirstChild("VehiculesPersonnels")
        local model = folder and folder:FindFirstChild(name or "") :: Model?
        if model and board(model) then
            if i == 1 then
                local unavailable = RadioController.setStation("ville")
                local off = RadioController.setStation("Off")
                record(
                    "lot08.client.radio_station_indisponible_refusee",
                    unavailable == false and off == true,
                    string.format("ville %s, éteinte %s", tostring(unavailable), tostring(off))
                )
            end
            local measure = bench(model, spec.Id)
            results[spec.Id] = measure
            trace(spec.Id .. " : " .. HttpService:JSONEncode(measure))
            leave()
        else
            results[spec.Id] = { Error = "embarquement impossible (" .. tostring(name) .. ")" }
        end
        signalEvent:FireServer("AW08:Despawn")
        task.wait(1)
    end
    local measured = 0
    for _, spec in WorkingCatalog.Specs do
        local m = results[spec.Id]
        if m and m.Reached230 then
            measured += 1
        end
        measures["banc_" .. spec.Id] = HttpService:JSONEncode(m or {})
    end
    record(
        "lot08.client.banc_18_modeles",
        measured == #WorkingCatalog.Specs,
        measured .. " / " .. #WorkingCatalog.Specs .. " ont parcouru 230 m"
    )
end

trace("début du test")
local ran, failure = xpcall(main, debug.traceback)
if not ran then
    record("lot08.client.script_sans_plantage", false, failure)
end
VehicleController.setTestInputProvider(nil)
trace(if ran then "fin du test" else "plantage : " .. tostring(failure))
reportEvent:FireServer({ vehicle = "lot08", steps = steps, measures = measures })
