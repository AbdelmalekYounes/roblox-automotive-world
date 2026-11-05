-- Suite de tests SERVEUR exécutée dans une session de test Roblox Studio.
-- Injectée par le pilote (Driver.luau) uniquement dans le Studio de test : la
-- place n'est jamais enregistrée avec ce script. Elle ne simule aucune entrée.
--
-- Rôle : vérifier l'état autoritaire (zone, véhicules posés, propriété réseau,
-- absence d'erreurs d'exécution), collecter les rapports des clients puis
-- terminer la session avec StudioTestService:EndTest(rapport).

local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")
local Workspace = game:GetService("Workspace")

local args = StudioTestService:GetTestArgs()
local sessionName = if type(args) == "table" and type(args.Session) == "string" then args.Session else "inconnue"
local expectedPlayers = if type(args) == "table" and type(args.Players) == "number" then args.Players else 1
-- Sessions qui ont leur propre suite serveur complète (MondeServer, Lot04Server).
if
    sessionName == "monde"
    or sessionName == "lot04"
    or sessionName == "lot05"
    or sessionName == "lot06"
    or sessionName == "lot08"
    or sessionName == "perf"
    or sessionName == "ui"
    or sessionName == "ui_monde"
    or sessionName == "ui_marche"
    or sessionName == "metiers"
    or sessionName == "gps"
    or sessionName == "gps2"
    or sessionName == "drift"
    or sessionName == "social"
    or sessionName == "avatar"
    or sessionName == "avatar2"
    or sessionName == "aster"
    or sessionName == "silhouette"
    or sessionName == "silhouette2"
    or sessionName == "comete"
    or sessionName == "comete_vitres"
    or sessionName == "comete_perf"
    or sessionName == "comete2"
    or sessionName == "comete_avatar"
    or sessionName == "ui_design"
    or sessionName == "ui_phone"
    or sessionName == "ui_garage"
    or sessionName == "ui_panels"
    or sessionName == "ui_garage3d"
    or sessionName == "ui_garage2"
    or sessionName == "ui_panels2"
    or sessionName == "ui_hud"
    or sessionName == "ui_resolutions"
    or sessionName == "ui_navigation"
then
    return
end
local CLIENT_TIMEOUT_S = 240

local steps = {}
local function record(name: string, ok: boolean, detail: any)
    table.insert(steps, { name = name, ok = ok, detail = if detail ~= nil then tostring(detail) else nil })
end

-- Journal des erreurs et avertissements serveur pendant la session. Les erreurs
-- de NOTRE code (scripts du jeu ou de test) sont séparées des erreurs internes
-- de Roblox (scripts du moteur), consignées à titre d'information.
local OUR_CODE_MARKERS = { "AutomotiveWorld", "ReplicatedStorage.Shared", "AW_Test" }
local function isOurError(message: string): boolean
    for _, marker in OUR_CODE_MARKERS do
        if string.find(message, marker, 1, true) then
            return true
        end
    end
    return false
end
local errors, robloxErrors, validationWarnings = {}, {}, {}
LogService.MessageOut:Connect(function(message, messageType)
    if messageType == Enum.MessageType.MessageError then
        table.insert(if isOurError(message) then errors else robloxErrors, message)
    elseif messageType == Enum.MessageType.MessageWarning and string.find(message, "[Validation]", 1, true) then
        table.insert(validationWarnings, message)
    end
end)

-- Canal de rapport des clients de test (n'existe que dans cette session).
local reportEvent = Instance.new("RemoteEvent")
reportEvent.Name = "AWTestReport"
reportEvent.Parent = ReplicatedStorage
ReplicatedStorage:SetAttribute("AWTestSession", sessionName)
ReplicatedStorage:SetAttribute("AWTestPlayers", expectedPlayers)

local clientReports = {}
reportEvent.OnServerEvent:Connect(function(player, payload)
    clientReports[tostring(player.UserId)] = payload
end)

-- Signaux de synchronisation entre clients de test (relayés par le serveur).
local signalEvent = Instance.new("RemoteEvent")
signalEvent.Name = "AWTestSignal"
signalEvent.Parent = ReplicatedStorage
signalEvent.OnServerEvent:Connect(function(_, name)
    if name == "M2Done" then
        ReplicatedStorage:SetAttribute("AWTestM2Done", true)
    end
end)

-- Attribution des véhicules par le SERVEUR, dans l'ordre d'arrivée (au démarrage,
-- un client ne voit pas encore les autres joueurs). Plots éloignés : 1 puis 4.
local PAD_ORDER = { 1, 4, 2, 3 }
local joinCount = 0
local function assignVehicle(player: Player)
    joinCount += 1
    player:SetAttribute("AWTestIndex", joinCount)
    player:SetAttribute("AWTestPad", PAD_ORDER[joinCount] or joinCount)
end
Players.PlayerAdded:Connect(assignVehicle)
for _, player in Players:GetPlayers() do
    if player:GetAttribute("AWTestIndex") == nil then
        assignVehicle(player)
    end
end

-- Diagnostic d'embarquement : invites réellement reçues par le serveur.
local promptLog = {}
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt, player)
    local model = prompt:FindFirstAncestorOfClass("Model")
    table.insert(
        promptLog,
        string.format("%s→%s", tostring(player.UserId), if model then model.Name else prompt:GetFullName())
    )
end)

-- Secours de diagnostic : si l'embarquement par l'invite échoue, le client peut
-- demander au serveur de l'asseoir pour que la suite continue (l'échec reste consigné).
local seatEvent = Instance.new("RemoteEvent")
seatEvent.Name = "AWTestSeatFallback"
seatEvent.Parent = ReplicatedStorage
seatEvent.OnServerEvent:Connect(function(player, model)
    if typeof(model) ~= "Instance" or not model:IsA("Model") then
        return
    end
    local seat = model:FindFirstChild("DriverSeat")
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if seat and seat:IsA("Seat") and humanoid and seat.Occupant == nil then
        seat:Sit(humanoid)
    end
end)

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

-- S1 : zone, véhicules et canaux réseau présents.
local zone = Workspace:WaitForChild("AutomotiveTestZone", 10)
local vehiclesFolder = Workspace:WaitForChild("VehiculesEssai", 10)
local remotes = ReplicatedStorage:WaitForChild("AutomotiveWorldRemotes", 10)
local vehicles = if vehiclesFolder then vehiclesFolder:GetChildren() else {}
record("serveur.zone_creee", zone ~= nil, zone and #zone:GetDescendants() .. " instances")
-- Lot 0.2 : 9 véhicules (plots 1 à 4 : P-01 du lot 0.1, puis P-02, P-03, DCT, SEQ, CVT).
record("serveur.parc_neuf_vehicules", #vehicles == 9, #vehicles .. " véhicules")
record("serveur.canaux_reseau", remotes ~= nil and #remotes:GetChildren() == 4, remotes and #remotes:GetChildren())

-- S2 : véhicules stationnés posés, immobiles et droits (suspension réelle).
-- Lot 0.2 : mesuré dans deux sessions, les 9 véhicules oscillaient encore
-- ensemble à 4 s (rebond d'apparition). On attend l'immobilité jusqu'à 12 s et
-- l'on consigne le temps réellement mesuré.
local settleStart = os.clock()
task.wait(4)
local function allSettled(): boolean
    for _, model in vehicles do
        local root = model.PrimaryPart
        if root == nil or root.AssemblyLinearVelocity.Magnitude >= 0.5 then
            return false
        end
    end
    return true
end
local settledInTime = waitFor(allSettled, 8)
local settleSeconds = os.clock() - settleStart
local startPositions = {}
local details, settledOk = { string.format("immobiles après %.1f s", settleSeconds) }, settledInTime
for _, model in vehicles do
    local root = model.PrimaryPart
    if root then
        startPositions[model] = root.Position
        local speed = root.AssemblyLinearVelocity.Magnitude
        local upright = root.CFrame.UpVector.Y
        local height = root.Position.Y
        local ok = speed < 0.5 and upright > 0.98 and height > 1.0 and height < 2.8
        settledOk = settledOk and ok
        table.insert(
            details,
            string.format("%s: Y=%.2f vitesse=%.2f st/s droit=%.3f", model.Name, height, speed, upright)
        )
    else
        settledOk = false
    end
end
record("serveur.vehicules_poses_et_immobiles", settledOk and #vehicles > 0, table.concat(details, " | "))

-- S3 : propriété réseau = conducteur pendant la conduite (échantillons toutes les 0,5 s).
local ownerMatches, ownerMismatches, ownerSamples = 0, 0, {}
-- L'attribut SimulationOwnerUserId (lu par les clients) doit toujours refléter
-- le propriétaire réseau effectif, pour TOUS les véhicules.
local attributeChecks, attributeMismatches, attributeSamples = 0, 0, {}
local monitoring = true
task.spawn(function()
    while monitoring do
        for _, model in vehicles do
            local driverId = model:GetAttribute("DriverUserId")
            local root = model.PrimaryPart
            if root then
                local okOwner, effective = pcall(function()
                    return root:GetNetworkOwner()
                end)
                if okOwner then
                    attributeChecks += 1
                    local expected = if effective then effective.UserId else 0
                    if model:GetAttribute("SimulationOwnerUserId") ~= expected then
                        attributeMismatches += 1
                        if #attributeSamples < 5 then
                            table.insert(
                                attributeSamples,
                                string.format(
                                    "%s attribut=%s effectif=%s",
                                    model.Name,
                                    tostring(model:GetAttribute("SimulationOwnerUserId")),
                                    tostring(expected)
                                )
                            )
                        end
                    end
                end
            end
            if root and type(driverId) == "number" and driverId ~= 0 then
                local owner = root:GetNetworkOwner()
                if owner and owner.UserId == driverId then
                    ownerMatches += 1
                else
                    ownerMismatches += 1
                    if #ownerSamples < 5 then
                        table.insert(
                            ownerSamples,
                            model.Name .. " propriétaire=" .. (if owner then tostring(owner.UserId) else "serveur")
                        )
                    end
                end
            end
        end
        task.wait(0.5)
    end
end)

-- Attente des rapports clients (délai allongé par les sessions longues, ex. lot02).
local clientTimeout = ReplicatedStorage:GetAttribute("AWTestClientTimeout")
local gotAll = waitFor(function()
    local count = 0
    for _ in clientReports do
        count += 1
    end
    return count >= expectedPlayers
end, if type(clientTimeout) == "number" then clientTimeout else CLIENT_TIMEOUT_S)
monitoring = false
record("serveur.rapports_clients_recus", gotAll, string.format("%d attendu(s)", expectedPlayers))

-- Les corrections de la suite client (téléportation volontaire) passent
-- brièvement la propriété au serveur : quelques échantillons discordants sont normaux.
record(
    "serveur.propriete_reseau_conducteur",
    ownerMatches > 0 and ownerMismatches <= 6 * expectedPlayers,
    string.format("%d concordants, %d discordants %s", ownerMatches, ownerMismatches, table.concat(ownerSamples, ", "))
)

record(
    "serveur.attribut_simulation_conforme_au_proprietaire",
    attributeChecks > 0 and attributeMismatches == 0,
    string.format(
        "%d contrôle(s), %d écart(s) %s",
        attributeChecks,
        attributeMismatches,
        table.concat(attributeSamples, ", ")
    )
)

-- Déconnexion d'un conducteur (session multijoueur, après les rapports) : le
-- joueur 2 est assis par le serveur dans un véhicule libre puis expulsé ; le
-- véhicule doit revenir au serveur, libre et réembarquable.
if sessionName == "multijoueur" then
    local leaving: Player? = nil
    for _, candidate in Players:GetPlayers() do
        if candidate:GetAttribute("AWTestIndex") == 2 then
            leaving = candidate
        end
    end
    local spare = vehiclesFolder and vehiclesFolder:FindFirstChild("VehiculeEssai_3")
    local leavingHumanoid = if leaving and leaving.Character
        then leaving.Character:FindFirstChildOfClass("Humanoid")
        else nil
    local seat = if spare then spare:FindFirstChild("DriverSeat") else nil
    if leaving and spare and leavingHumanoid and seat and seat:IsA("Seat") then
        seat:Sit(leavingHumanoid)
        local spareRoot = spare.PrimaryPart :: BasePart
        local boarded = waitFor(function()
            return spare:GetAttribute("DriverUserId") == leaving.UserId
                and spare:GetAttribute("SimulationOwnerUserId") == leaving.UserId
        end, 5)
        record("serveur.deconnexion_conducteur_embarque", boarded, "joueur 2 assis par le serveur dans VehiculeEssai_3")
        leaving:Kick("Test automatisé de déconnexion (Studio)")
        local released = waitFor(function()
            return spare:GetAttribute("DriverUserId") == 0
        end, 8)
        local owner = spareRoot:GetNetworkOwner()
        local prompt = (spareRoot:FindFirstChild("DriverDoor") :: Attachment):FindFirstChild(
                "EnterPrompt"
            ) :: ProximityPrompt
        record(
            "serveur.deconnexion_vehicule_libere",
            released and owner == nil and spare:GetAttribute("SimulationOwnerUserId") == 0 and prompt.Enabled,
            string.format(
                "libéré=%s propriétaire=%s attribut=%s invite=%s",
                tostring(released),
                if owner then tostring(owner.UserId) else "serveur",
                tostring(spare:GetAttribute("SimulationOwnerUserId")),
                tostring(prompt.Enabled)
            )
        )
    else
        record("serveur.deconnexion_vehicule_libere", false, "préparation impossible (joueur 2 ou véhicule absent)")
    end
end

-- S4 : les véhicules non utilisés n'ont pas bougé.
local driftDetails, driftOk = {}, true
local driven = {}
for _, report in clientReports do
    if type(report) == "table" and type(report.vehicle) == "string" then
        driven[report.vehicle] = true
    end
end
for model, start in startPositions do
    if not driven[model.Name] and model.PrimaryPart then
        local drift = (model.PrimaryPart.Position - start).Magnitude
        driftOk = driftOk and drift < 1.5
        table.insert(driftDetails, string.format("%s: %.2f st", model.Name, drift))
    end
end
if ReplicatedStorage:GetAttribute("AWTestMovesVehicles") then
    record("serveur.vehicules_libres_immobiles", true, "non applicable : véhicules déplacés par les scénarios")
else
    record("serveur.vehicules_libres_immobiles", driftOk, table.concat(driftDetails, " | "))
end

-- Contrôles des scénarios étendus (ScenarioServer), dont le retour au plot (~90 s).
local scenarioChannel = game:GetService("ServerStorage"):FindFirstChild("AWTestScenario")
if scenarioChannel then
    local done = waitFor(function()
        return scenarioChannel:GetAttribute("Done") == true
    end, 200)
    record("serveur.scenarios_termines", done)
    local encoded = scenarioChannel:GetAttribute("Steps")
    if type(encoded) == "string" then
        for _, step in game:GetService("HttpService"):JSONDecode(encoded) do
            table.insert(steps, step)
        end
    end
end

record("serveur.aucune_erreur_execution", #errors == 0, table.concat(errors, " || "))
record(
    "serveur.info_erreurs_internes_roblox",
    true,
    #robloxErrors .. " erreur(s) hors de notre code : " .. table.concat(robloxErrors, " || ")
)
record("serveur.info_invites_recues", true, #promptLog .. " : " .. table.concat(promptLog, ", "))
record(
    "serveur.journal_validation",
    true,
    #validationWarnings .. " message(s) : " .. table.concat(validationWarnings, " || ")
)

StudioTestService:EndTest({
    session = sessionName,
    players = #Players:GetPlayers(),
    server = steps,
    clients = clientReports,
})
