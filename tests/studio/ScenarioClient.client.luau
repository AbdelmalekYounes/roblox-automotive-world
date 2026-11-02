-- Scénarios CLIENT étendus (sessions « scenarios » et « collision »), exécutés dans
-- une session de test Roblox Studio. Injecté par le pilote uniquement.
--
-- Comme ClientSuite, ce script conduit le VRAI véhicule par le vrai chemin du jeu ;
-- seule la lecture clavier/manette est remplacée (VehicleController.setTestInputProvider).
-- Un petit régulateur (cap vers une cible + vitesse) joue le rôle du conducteur.

local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
local session = ReplicatedStorage:GetAttribute("AWTestSession")
if session ~= "scenarios" and session ~= "collision" then
    return
end

local steps, measures = {}, {}
local function record(name: string, ok: boolean, detail: any, knownLimitation: string?)
    table.insert(steps, {
        name = name,
        ok = ok,
        detail = if detail ~= nil then tostring(detail) else nil,
        -- Limite connue et documentée : affichée ⚠️, jamais comptée comme réussie.
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
local function waitNotice(key: string, since: number, timeout: number): boolean
    return waitFor(function()
        for _, notice in notices do
            if notice.key == key and notice.at >= since then
                return true
            end
        end
        return false
    end, timeout)
end

local function finish(vehicleName: string?)
    record("client.aucune_erreur_execution", #errors == 0, table.concat(errors, " || "))
    reportEvent:FireServer({ vehicle = vehicleName, steps = steps, measures = measures })
end

local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local controllerModule = player
    :WaitForChild("PlayerScripts")
    :WaitForChild("AutomotiveWorldClient", 20)
    :WaitForChild("Vehicles")
    :WaitForChild("VehicleController", 10)
local VehicleController = require(controllerModule) :: any
local function snapshot()
    return VehicleController.getTestSnapshot()
end

waitFor(function()
    return player:GetAttribute("AWTestPad") ~= nil
end, 20)
local myIndex = player:GetAttribute("AWTestIndex") or 1
local folder = Workspace:WaitForChild("VehiculesEssai", 20)
local model = folder:WaitForChild("VehiculeEssai_" .. (player:GetAttribute("AWTestPad") or 1), 10) :: Model
local root = model.PrimaryPart :: BasePart

-- Commande injectée et régulateur.
local command = { Throttle = 0, Brake = 0, Steer = 0, Handbrake = false }
local function setCommand(throttle: number, brake: number, steer: number, handbrake: boolean?)
    command.Throttle, command.Brake, command.Steer, command.Handbrake = throttle, brake, steer, handbrake == true
end

-- Angle (rad) vers une cible dans le plan, positif à droite.
local function bearingTo(target: Vector3): number
    local localTarget = root.CFrame:PointToObjectSpace(target)
    return math.atan2(localTarget.X, -localTarget.Z)
end

-- Un pas de régulation : braquage proportionnel au cap, vitesse visée.
local function drive(target: Vector3, targetKmh: number)
    local s = snapshot()
    local steer = math.clamp(bearingTo(target) * 2.2, -1, 1)
    local gap = targetKmh - s.SpeedKmh
    if gap > 0 then
        setCommand(math.clamp(gap * 0.08, 0.05, 0.7), 0, steer)
    else
        setCommand(0, math.clamp(-gap * 0.08, 0, 0.6), steer)
    end
end

local function stop(timeout: number)
    setCommand(0, 1, 0)
    waitFor(function()
        return snapshot().SpeedKmh < 1
    end, timeout)
    setCommand(0, 0, 0, true)
end

local function board(label: string): boolean
    local door = root:FindFirstChild("DriverDoor") :: Attachment
    local prompt = door:FindFirstChild("EnterPrompt") :: ProximityPrompt
    for attempt = 1, 2 do
        character:PivotTo(CFrame.new(door.WorldPosition + Vector3.new(0, 1.5, 0) - root.CFrame.RightVector))
        task.wait(if attempt == 1 then 0.8 else 1.5)
        pcall(function()
            prompt:InputHoldBegin()
            task.wait(prompt.HoldDuration + 0.3)
            prompt:InputHoldEnd()
        end)
        if waitFor(function()
            return snapshot().Driving
        end, 5) then
            record("client." .. label .. "_embarquement", true, "invite, essai " .. attempt)
            VehicleController.setTestInputProvider(function()
                return table.clone(command)
            end)
            return true
        end
    end
    seatFallback:FireServer(model)
    local ok = waitFor(function()
        return snapshot().Driving
    end, 5)
    record(
        "client." .. label .. "_embarquement",
        false,
        if ok then "invite refusée ; siège attribué par le secours serveur" else "échec"
    )
    if ok then
        VehicleController.setTestInputProvider(function()
            return table.clone(command)
        end)
    end
    return ok
end

local function leave()
    stop(10)
    task.wait(0.5)
    actionRemote:FireServer("Exit")
    waitFor(function()
        return not snapshot().Driving and humanoid.SeatPart == nil
    end, 5)
    VehicleController.setTestInputProvider(nil)
    task.wait(1.5)
end

local function waitStage(name: string)
    return waitFor(function()
        return ReplicatedStorage:GetAttribute("AWScenarioStage") == name
    end, 60)
end

-- Percute à ~20 km/h le flanc d'un autre véhicule placé 80 st plus au nord.
-- `prefix` distingue les contrôles (véhicule conduit par un joueur ou garé).
local function ramInto(other: Model, prefix: string)
    local otherStart = other:GetPivot().Position
    local impactKmh, peakKmh, contact = 0, 0, false
    local afterKmh = 0
    local history = {}
    waitFor(function()
        drive(Vector3.new(0, 0, root.Position.Z - 60), 20)
        local now = os.clock()
        local speed = snapshot().SpeedKmh
        peakKmh = math.max(peakKmh, speed)
        table.insert(history, { at = now, speed = speed })
        while #history > 0 and now - history[1].at > 0.3 do
            table.remove(history, 1)
        end
        local recentMax = 0
        for _, h in history do
            recentMax = math.max(recentMax, h.speed)
        end
        local displaced = (other:GetPivot().Position - otherStart).Magnitude > 0.3
        if peakKmh > 15 and (recentMax - speed > 4 or displaced) then
            contact = true
            impactKmh = recentMax
            afterKmh = speed
            return true
        end
        return root.Position.Z < -260
    end, 20)
    stop(5)
    task.wait(2)
    measures[prefix .. "_vitesse_impact_kmh"] = impactKmh
    measures[prefix .. "_vitesse_apres_contact_kmh"] = afterKmh
    record(
        "client." .. prefix .. "_contact",
        contact,
        string.format("vitesse avant impact %.1f km/h, %.1f km/h juste après", impactKmh, afterKmh)
    )
    record(
        "client." .. prefix .. "_reste_droit",
        root.CFrame.UpVector.Y > 0.9,
        string.format("UpVector.Y %.3f", root.CFrame.UpVector.Y)
    )
    record("client." .. prefix .. "_toujours_conducteur", snapshot().Driving)
end

if session == "scenarios" then
    -- S10 : bosse à 10 % (rampe 60 st, plateau 40 st, rampe 60 st), à 30 km/h.
    if waitStage("bosse") and board("bosse") then
        local minUp, maxPitch, maxAirborne, airborneSince = 1, 0, 0, nil
        local minSpeedOnClimb = math.huge
        local finished = waitFor(function()
            drive(Vector3.new(300, 0, root.Position.Z - 60), 30)
            local s = snapshot()
            local cf = root.CFrame
            minUp = math.min(minUp, cf.UpVector.Y)
            maxPitch = math.max(maxPitch, math.abs(math.deg(math.asin(math.clamp(cf.LookVector.Y, -1, 1)))))
            if root.Position.Z < -300 and root.Position.Z > -400 then
                minSpeedOnClimb = math.min(minSpeedOnClimb, s.SpeedKmh)
            end
            if s.GroundedWheels == 0 then
                airborneSince = airborneSince or os.clock()
                maxAirborne = math.max(maxAirborne, os.clock() - airborneSince)
            else
                airborneSince = nil
            end
            return root.Position.Z < -520
        end, 40)
        measures.bosse_assiette_max_deg = maxPitch
        measures.bosse_vitesse_min_montee_kmh = if minSpeedOnClimb < math.huge then minSpeedOnClimb else nil
        measures.bosse_temps_sans_contact_max_s = maxAirborne
        record(
            "client.bosse_franchie",
            finished,
            string.format("assiette max %.1f° (pente théorique 5,7°)", maxPitch)
        )
        record("client.bosse_reste_droit", minUp > 0.9, string.format("UpVector.Y min %.3f", minUp))
        record(
            "client.bosse_pas_de_decollage",
            maxAirborne < 0.3,
            string.format("quatre roues en l'air au plus %.2f s", maxAirborne)
        )
        leave()
    end
    signalEvent:FireServer("bosse")

    -- Slalom : passage alterné à ±9 st de chaque cône, à 25 km/h.
    if waitStage("slalom") and board("slalom") then
        local slalom = Workspace:WaitForChild("AutomotiveTestZone"):WaitForChild("Slalom")
        local gates = {}
        for i = 1, 8 do
            local cone = slalom:FindFirstChild("Cone" .. i) :: BasePart
            table.insert(gates, Vector3.new(cone.Position.X + (if i % 2 == 1 then -9 else 9), 0, cone.Position.Z))
        end
        local gate = 1
        local maxMiss = 0
        local finished = waitFor(function()
            local target = gates[gate]
            if target == nil then
                drive(Vector3.new(131, 0, root.Position.Z - 60), 20)
                return root.Position.Z < -560
            end
            if root.Position.Z <= target.Z then
                maxMiss = math.max(maxMiss, math.abs(root.Position.X - target.X))
                gate += 1
                return false
            end
            drive(target, 25)
            return false
        end, 60)
        measures.slalom_ecart_max_porte_st = maxMiss
        record(
            "client.slalom_parcouru",
            finished and gate > 8,
            string.format("%d porte(s) franchie(s), écart latéral max %.1f st", gate - 1, maxMiss)
        )
        leave()
    end
    signalEvent:FireServer("slalom")

    -- S12 : véhicule renversé, puis remise sur roues (touche R / croix bas).
    if waitStage("renverse") and board("renverse") then
        task.wait(1)
        local since = os.clock()
        actionRemote:FireServer("Unflip")
        local done = waitNotice("UnflipDone", since, 3)
        task.wait(3)
        local s = snapshot()
        record(
            "client.remise_sur_roues",
            done and root.CFrame.UpVector.Y > 0.95 and s.GroundedWheels == 4,
            string.format("UpVector.Y %.3f, roues au sol %d", root.CFrame.UpVector.Y, s.GroundedWheels)
        )
        since = os.clock()
        actionRemote:FireServer("Unflip")
        record("client.remise_sur_roues_delai", waitNotice("UnflipCooldown", since, 3), "second appui immédiat")
        -- Le véhicule remis droit roule normalement.
        setCommand(0.5, 0, 0)
        task.wait(2)
        record(
            "client.roule_apres_remise",
            snapshot().SpeedKmh > 5,
            string.format("%.1f km/h après 2 s", snapshot().SpeedKmh)
        )
        leave()
    end
    signalEvent:FireServer("renverse")

    -- Même impact contre un véhicule GARÉ (simulé par le serveur), pour comparer
    -- avec la collision entre deux véhicules conduits par des joueurs.
    if waitStage("collision_parque") and board("collision_parque") then
        ramInto(folder:FindFirstChild("VehiculeEssai_2") :: Model, "collision_parque")
        leave()
    end
    signalEvent:FireServer("collision_parque")
    finish(model.Name)
elseif session == "collision" then
    -- M4 : le joueur 1 percute à ~20 km/h le flanc du véhicule du joueur 2 (frein à main serré).
    if not (waitStage("collision") and board("collision")) then
        signalEvent:FireServer(if myIndex == 2 then "CollisionReady" else "collision")
        finish(model.Name)
        return
    end
    if myIndex == 2 then
        setCommand(0, 0, 0, true)
        task.wait(1.5)
        local start = root.Position
        signalEvent:FireServer("CollisionReady")
        local maxDisplacement = 0
        waitFor(function()
            maxDisplacement = math.max(maxDisplacement, (root.Position - start).Magnitude)
            return ReplicatedStorage:GetAttribute("AWCollisionDone") == true
        end, 60)
        task.wait(1)
        measures.collision_deplacement_vehicule_percute_st = maxDisplacement
        record(
            "client.collision_vehicule_percute_bouge",
            maxDisplacement > 0.3,
            string.format("déplacement max %.2f st", maxDisplacement),
            "transfert d'impulsion faible et variable entre deux véhicules conduits "
                .. "(0,2 à 2,2 st sur 5 essais, contre 3,1 à 4,3 st pour un véhicule garé) ; "
                .. "cause supposée : propriétés réseau distinctes, non démontrée ; voir ECARTS.md"
        )
        record(
            "client.collision_percute_reste_droit",
            root.CFrame.UpVector.Y > 0.9,
            string.format("UpVector.Y %.3f", root.CFrame.UpVector.Y)
        )
        record("client.collision_percute_toujours_conducteur", snapshot().Driving)
    else
        waitFor(function()
            return ReplicatedStorage:GetAttribute("AWCollisionReady") == true
        end, 60)
        ramInto(folder:FindFirstChild("VehiculeEssai_4") :: Model, "collision")
        signalEvent:FireServer("collision")
        task.wait(2)
    end
    VehicleController.setTestInputProvider(nil)
    finish(model.Name)
end
