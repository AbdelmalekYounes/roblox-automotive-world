-- Suite de tests CLIENT exécutée dans une session de test Roblox Studio.
-- Injectée par le pilote (Driver.luau) uniquement dans le Studio de test.
--
-- Elle conduit le VRAI véhicule par le vrai chemin du jeu : invite
-- d'embarquement, simulation locale, forces, propriété réseau, serveur, caméra
-- et HUD. Seule la lecture clavier/manette est remplacée, via le point d'accès
-- Studio `VehicleController.setTestInputProvider`. Les actions discrètes
-- (sortie, remise sur roues) passent par le même RemoteEvent que les touches.
-- Les grandeurs mesurées ici le sont dans le moteur Roblox (pas d'estimation).

local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local METERS_PER_STUD = 0.28

local steps = {}
local measures = {}
local function record(name: string, ok: boolean, detail: any)
    table.insert(steps, { name = name, ok = ok, detail = if detail ~= nil then tostring(detail) else nil })
end

-- Erreurs de NOTRE code (échec) séparées des erreurs internes de Roblox (information).
local OUR_CODE_MARKERS = { "AutomotiveWorld", "ReplicatedStorage.Shared", "AW_Test" }
local function isOurError(message: string): boolean
    for _, marker in OUR_CODE_MARKERS do
        if string.find(message, marker, 1, true) then
            return true
        end
    end
    return false
end
local errors, robloxErrors = {}, {}
LogService.MessageOut:Connect(function(message, messageType)
    if messageType == Enum.MessageType.MessageError then
        table.insert(if isOurError(message) then errors else robloxErrors, message)
    end
end)

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

local reportEvent = ReplicatedStorage:WaitForChild("AWTestReport", 30)
local seatFallback = ReplicatedStorage:WaitForChild("AWTestSeatFallback", 30)
local signalEvent = ReplicatedStorage:WaitForChild("AWTestSignal", 30)
local remotes = ReplicatedStorage:WaitForChild("AutomotiveWorldRemotes", 30)
local actionRemote = remotes and remotes:WaitForChild("VehicleAction", 10)
local noticeRemote = remotes and remotes:WaitForChild("VehicleNotice", 10)

local notices = {}
if noticeRemote then
    noticeRemote.OnClientEvent:Connect(function(key)
        table.insert(notices, { key = key, at = os.clock() })
    end)
end
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
    record(
        "client.info_erreurs_internes_roblox",
        true,
        #robloxErrors .. " erreur(s) hors de notre code : " .. table.concat(robloxErrors, " || ")
    )
    if reportEvent then
        reportEvent:FireServer({ vehicle = vehicleName, steps = steps, measures = measures })
    end
end

-- C1 : démarrage du client (bannière, contrôleur, personnage).
local playerScripts = player:WaitForChild("PlayerScripts")
local clientFolder = playerScripts:WaitForChild("AutomotiveWorldClient", 20)
local controllerModule = clientFolder and clientFolder:WaitForChild("Vehicles"):WaitForChild("VehicleController", 10)
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local banner = player:WaitForChild("PlayerGui"):WaitForChild("AutomotiveWorldDevelopmentStatus", 20)
record("client.demarrage", controllerModule ~= nil and banner ~= nil, banner and "bannière affichée")
if controllerModule == nil then
    finish(nil)
    return
end
local VehicleController = require(controllerModule) :: any

-- Véhicule attribué par la suite serveur (ordre d'arrivée des joueurs).
local folder = Workspace:WaitForChild("VehiculesEssai", 20)
waitFor(function()
    return player:GetAttribute("AWTestPad") ~= nil
end, 20)
local myIndex = player:GetAttribute("AWTestIndex") or 1
local padIndex = player:GetAttribute("AWTestPad") or 1
local playerCount = ReplicatedStorage:GetAttribute("AWTestPlayers") or 1
local model = folder and folder:FindFirstChild("VehiculeEssai_" .. padIndex)
if model == nil then
    record("client.vehicule_attribue", false, "VehiculeEssai_" .. padIndex .. " introuvable")
    finish(nil)
    return
end
local root = model.PrimaryPart :: BasePart
measures.joueur = myIndex
measures.ping_ms = math.floor(player:GetNetworkPing() * 1000 + 0.5)

-- Commande injectée (remplace uniquement la lecture clavier/manette).
local command = { Throttle = 0, Brake = 0, Steer = 0, Handbrake = false }
local function setCommand(throttle: number, brake: number, steer: number, handbrake: boolean?)
    command.Throttle, command.Brake, command.Steer, command.Handbrake = throttle, brake, steer, handbrake == true
end
local function snapshot()
    return VehicleController.getTestSnapshot()
end

-- M2 (multijoueur) : le second joueur tente de prendre le véhicule déjà occupé.
if playerCount > 1 and myIndex > 1 then
    local other = folder:FindFirstChild("VehiculeEssai_1")
    local occupied = other and waitFor(function()
        return other:GetAttribute("DriverUserId") ~= 0
    end, 60)
    if other and occupied then
        local otherPrompt = other.PrimaryPart.DriverDoor.EnterPrompt :: ProximityPrompt
        character:PivotTo(CFrame.new(other.PrimaryPart.DriverDoor.WorldPosition + Vector3.new(-1, 1.5, 0)))
        task.wait(0.5)
        local driverBefore = other:GetAttribute("DriverUserId")
        pcall(function()
            otherPrompt:InputHoldBegin()
            task.wait(0.6)
            otherPrompt:InputHoldEnd()
        end)
        task.wait(1)
        record(
            "client.vehicule_occupe_refuse",
            other:GetAttribute("DriverUserId") == driverBefore and humanoid.SeatPart == nil,
            "invite active=" .. tostring(otherPrompt.Enabled)
        )
        record(
            "client.voit_autre_conducteur",
            other:GetAttribute("DriverUserId") ~= 0 and other:GetAttribute("DriverUserId") ~= player.UserId,
            "DriverUserId=" .. tostring(other:GetAttribute("DriverUserId"))
        )
    else
        record("client.vehicule_occupe_refuse", false, "le joueur 1 n'a pas embarqué")
    end
    -- On s'éloigne du véhicule du joueur 1 AVANT de le prévenir : il attend ce
    -- signal pour ses mesures au repos et pour rouler.
    local ownDoor = root:FindFirstChild("DriverDoor") :: Attachment
    character:PivotTo(CFrame.new(ownDoor.WorldPosition + Vector3.new(-1, 1.5, 0)))
    task.wait(0.5)
    signalEvent:FireServer("M2Done")
end

-- C2 : embarquement par l'invite de proximité (même chemin que la touche E).
local door = root:FindFirstChild("DriverDoor") :: Attachment
local prompt = door:FindFirstChild("EnterPrompt") :: ProximityPrompt
local boardingNotes = {}
local boarded = false
for attempt = 1, 2 do
    character:PivotTo(CFrame.new(door.WorldPosition + Vector3.new(-1, 1.5, 0)))
    task.wait(if attempt == 1 then 0.8 else 1.5)
    local characterRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    local ok, err = pcall(function()
        prompt:InputHoldBegin()
        task.wait(prompt.HoldDuration + 0.3)
        prompt:InputHoldEnd()
    end)
    boarded = waitFor(function()
        return snapshot().Driving
    end, 5)
    table.insert(
        boardingNotes,
        string.format(
            "essai %d : %s, distance porte %.1f st, invite active=%s, ping %d ms%s",
            attempt,
            if boarded then "assis" else "non assis",
            if characterRoot then (characterRoot.Position - door.WorldPosition).Magnitude else -1,
            tostring(prompt.Enabled),
            math.floor(player:GetNetworkPing() * 1000 + 0.5),
            if ok then "" else " erreur=" .. tostring(err)
        )
    )
    if boarded then
        break
    end
end
record("client.embarquement_invite", boarded, table.concat(boardingNotes, " ; "))
if not boarded then
    seatFallback:FireServer(model)
    boarded = waitFor(function()
        return snapshot().Driving
    end, 6)
    record("client.embarquement_secours_serveur", boarded, "diagnostic seulement")
    if not boarded then
        finish(model.Name)
        return
    end
end
VehicleController.setTestInputProvider(function()
    return table.clone(command)
end)

local camera = Workspace.CurrentCamera
local hud = player.PlayerGui:FindFirstChild("AutomotiveWorldDevHud")
local panel = hud and hud:FindFirstChild("Panneau")
record(
    "client.session_conduite",
    camera.CameraType == Enum.CameraType.Scriptable and panel ~= nil and panel.Visible,
    string.format("caméra=%s HUD=%s", camera.CameraType.Name, tostring(panel and panel.Visible))
)
record(
    "client.propriete_attribuee",
    model:GetAttribute("DriverUserId") == player.UserId,
    "DriverUserId=" .. tostring(model:GetAttribute("DriverUserId"))
)

-- En multijoueur, le joueur 1 attend que le joueur 2 ait fini son essai sur ce
-- véhicule et s'en soit éloigné (sinon le contact du personnage fausse les mesures).
if playerCount > 1 and myIndex == 1 then
    local released = waitFor(function()
        return ReplicatedStorage:GetAttribute("AWTestM2Done") == true
    end, 60)
    record("client.info_attente_joueur_2", true, "signal reçu=" .. tostring(released))
    task.wait(1)
end

-- C3 : au repos, quatre roues au sol. Vitesse relevée à 1,5 s puis à 4 s après
-- l'embarquement : le transfert de propriété réseau peut provoquer un léger
-- mouvement transitoire, qui doit s'éteindre.
setCommand(0, 0, 0)
task.wait(1.5)
local restEarly = snapshot()
task.wait(2.5)
local rest = snapshot()
measures.repos_vitesse_1_5s_kmh = restEarly.SpeedKmh
measures.repos_vitesse_4s_kmh = rest.SpeedKmh
record(
    "client.repos_quatre_roues",
    rest.GroundedWheels == 4 and rest.SpeedKmh < 0.5,
    string.format(
        "roues=%d ; vitesse %.2f km/h à 1,5 s, %.2f km/h à 4 s",
        rest.GroundedWheels,
        restEarly.SpeedKmh,
        rest.SpeedKmh
    )
)

-- C4 : accélération à fond, mesurée dans le moteur.
setCommand(1, 0, 0)
local launchStart = os.clock()
local speedAt025, speedAt1, maxGear, timeTo100 = nil, nil, 0, nil
local previousSpeed, maxAccel = 0, 0
local lastTime = os.clock()
waitFor(function()
    local s = snapshot()
    local now = os.clock()
    local elapsed = now - launchStart
    maxGear = math.max(maxGear, s.Gear)
    if speedAt025 == nil and elapsed >= 0.25 then
        speedAt025 = s.SpeedKmh
    end
    if speedAt1 == nil and elapsed >= 1 then
        speedAt1 = s.SpeedKmh
    end
    local dt = now - lastTime
    if dt > 0.05 then
        maxAccel = math.max(maxAccel, (s.SpeedKmh - previousSpeed) / 3.6 / dt)
        previousSpeed, lastTime = s.SpeedKmh, now
    end
    if s.SpeedKmh >= 100 then
        timeTo100 = elapsed
        return true
    end
    return false
end, 25)
measures.zero_a_cent_s = timeTo100
measures.acceleration_max_ms2 = maxAccel
record(
    "client.acceleration_progressive",
    speedAt025 ~= nil and speedAt025 < 15 and speedAt1 ~= nil and speedAt1 > 3,
    string.format("%.1f km/h à 0,25 s ; %.1f km/h à 1 s", speedAt025 or -1, speedAt1 or -1)
)
record("client.atteint_100_kmh", timeTo100 ~= nil, timeTo100 and string.format("%.2f s (horloge client)", timeTo100))
record("client.rapports_montent", maxGear >= 3, "rapport max " .. maxGear)
record("client.acceleration_bornee", maxAccel < 13, string.format("%.2f m/s² max (moyenne glissante 50 ms)", maxAccel))

-- C5 : sortie refusée en roulant (même RemoteEvent que la touche F).
local since = os.clock()
actionRemote:FireServer("Exit")
local refused = waitNotice("ExitTooFast", since, 2)
record(
    "client.sortie_refusee_en_roulant",
    refused and snapshot().Driving,
    "notification ExitTooFast=" .. tostring(refused)
)

-- C6 : freinage à fond jusqu'à l'arrêt.
setCommand(0, 1, 0)
local brakeStart = root.Position
local brakeSpeed = snapshot().SpeedKmh
local brakeTime = os.clock()
local stopped = waitFor(function()
    return snapshot().SpeedKmh < 1
end, 15)
local brakeDistance = Vector3.new(root.Position.X - brakeStart.X, 0, root.Position.Z - brakeStart.Z).Magnitude
    * METERS_PER_STUD
measures.freinage_depuis_kmh = brakeSpeed
measures.freinage_distance_m = brakeDistance
measures.freinage_duree_s = os.clock() - brakeTime
task.wait(0.2) -- laisse le HUD enregistrer sa mesure (mise à jour à l'image suivante)
measures.hud_100_0_m = snapshot().LastBrakeDistanceM
measures.hud_0_100_s = snapshot().LastLaunchSeconds
record(
    "client.freinage_arret",
    stopped and brakeDistance > 15 and brakeDistance < 90,
    string.format("depuis %.0f km/h : %.1f m en %.2f s", brakeSpeed, brakeDistance, measures.freinage_duree_s)
)

-- C7 : marche arrière (maintien de « freiner » à l'arrêt).
task.wait(2.5)
local reverse = snapshot()
record(
    "client.marche_arriere",
    reverse.Gear == -1 and reverse.ForwardSpeedMs < -0.5,
    string.format("rapport=%d vitesse=%.2f m/s", reverse.Gear, reverse.ForwardSpeedMs)
)
setCommand(1, 0, 0) -- « accélérer » freine en marche arrière
waitFor(function()
    return math.abs(snapshot().ForwardSpeedMs) < 0.3
end, 6)
setCommand(0, 0, 0)
task.wait(0.5)

-- C8 : virages. Cap mesuré sur le vecteur avant du châssis (vu de dessus).
local function heading(): number
    local look = root.CFrame.LookVector
    return math.atan2(look.X, -look.Z) -- 0 = nord (-Z), positif vers la droite (+X)
end
local function wrap(angle: number): number
    return (angle + math.pi) % (2 * math.pi) - math.pi
end
setCommand(0.6, 0, 0)
waitFor(function()
    return snapshot().SpeedKmh >= 40
end, 10)
local h0 = heading()
setCommand(0.3, 0, 0.6)
task.wait(2)
local rightTurn = math.deg(wrap(heading() - h0))
local h1 = heading()
setCommand(0.3, 0, -0.6)
task.wait(2)
local leftTurn = math.deg(wrap(heading() - h1))
measures.virage_droite_deg = rightTurn
measures.virage_gauche_deg = leftTurn
record("client.virage_droite", rightTurn > 15, string.format("%.1f° en 2 s", rightTurn))
record("client.virage_gauche", leftTurn < -15, string.format("%.1f° en 2 s", leftTurn))
setCommand(0, 1, 0)
waitFor(function()
    return snapshot().SpeedKmh < 1
end, 10)
setCommand(0, 0, 0)

-- C9 : caméra qui suit le véhicule, bascule proche/lointaine.
local function cameraDistance(): number
    return (camera.CFrame.Position - root.Position).Magnitude
end
task.wait(0.5)
local nearDistance = cameraDistance()
local presetName = VehicleController.toggleCameraForTest()
task.wait(1.5)
local farDistance = cameraDistance()
VehicleController.toggleCameraForTest()
record(
    "client.camera_proche_lointaine",
    nearDistance > 6 and nearDistance < 25 and farDistance > nearDistance + 3 and presetName == "Lointaine",
    string.format("proche %.1f st, %s %.1f st", nearDistance, presetName, farDistance)
)

-- C10 : frein à main, véhicule maintenu à l'arrêt.
setCommand(0, 0, 0, true)
local holdStart = root.Position
task.wait(2)
record(
    "client.frein_a_main_maintien",
    (root.Position - holdStart).Magnitude < 0.5,
    string.format("déplacement %.2f st", (root.Position - holdStart).Magnitude)
)

-- C11 : remise sur roues refusée sur un véhicule déjà droit.
since = os.clock()
actionRemote:FireServer("Unflip")
record("client.remise_sur_roues_inutile_refusee", waitNotice("UnflipNotNeeded", since, 2))

-- C12 : mouvement impossible (téléportation par le client propriétaire) → correction serveur.
task.wait(0.6)
local beforeTeleport = root.Position
since = os.clock()
-- 400 studs (112 m) vers le haut en un instant : impossible à vitesse plausible.
model:PivotTo(model:GetPivot() + Vector3.new(0, 400, 0))
local corrected = waitNotice("MovementCorrected", since, 3)
task.wait(0.5)
-- Vue du client pendant que le serveur détient le véhicule (information).
local earlyDistance = (root.Position - beforeTeleport).Magnitude
-- État final : après le retour de la propriété au conducteur (critère).
waitFor(function()
    return snapshot().Driving
end, 3)
task.wait(1.5)
local backDistance = (root.Position - beforeTeleport).Magnitude
measures.correction_ecart_0_5s_st = earlyDistance
measures.correction_ecart_final_st = backDistance
record(
    "client.correction_mouvement_impossible",
    corrected and backDistance < 20,
    string.format(
        "notification=%s, écart %.1f st à 0,5 s, %.1f st après retour au conducteur",
        tostring(corrected),
        earlyDistance,
        backDistance
    )
)

-- C13 : sortie à l'arrêt, retour au mode piéton.
setCommand(0, 0, 0, true)
task.wait(0.5)
actionRemote:FireServer("Exit")
local exited = waitFor(function()
    return not snapshot().Driving and humanoid.SeatPart == nil
end, 4)
task.wait(1.5) -- le serveur place le personnage puis vérifie (jusqu'à ~1 s)
local characterRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart?
local exitDistance = if characterRoot then (characterRoot.Position - root.Position).Magnitude else -1
record(
    "client.sortie_a_l_arret",
    exited and camera.CameraType == Enum.CameraType.Custom and exitDistance > 2 and exitDistance < 15,
    string.format("caméra=%s distance au véhicule %.1f st", camera.CameraType.Name, exitDistance)
)
record(
    "client.vehicule_libere",
    model:GetAttribute("DriverUserId") == 0,
    "DriverUserId=" .. tostring(model:GetAttribute("DriverUserId"))
)

VehicleController.setTestInputProvider(nil)
measures.ping_fin_ms = math.floor(player:GetNetworkPing() * 1000 + 0.5)
finish(model.Name)
