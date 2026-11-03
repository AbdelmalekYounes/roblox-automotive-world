-- Essais SERVEUR du lot 0.3 (session « monde », place MONDE OUVERT, 1 joueur),
-- injectés par le pilote dans le Studio de test uniquement. Remplace ServerSuite
-- pour cette session : démarrage de la carte générée, parc, apparitions, météo,
-- trafic PNJ, invites des lieux du lot 0.4, puis essais physiques sur la carte :
-- conduite réelle par le client sur une portion droite de l'autoroute, et
-- véhicules posés au repos sur une route de montagne, une rue et un chemin.
-- Le serveur de test place les véhicules et le personnage ; jamais le jeu.

local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StudioTestService = game:GetService("StudioTestService")
local Workspace = game:GetService("Workspace")

local args = StudioTestService:GetTestArgs()
local session = if type(args) == "table" and type(args.Session) == "string" then args.Session else ""
if session ~= "monde" then
    return
end

local S = 1 / 0.28
local steps = {}
local function record(name: string, ok: boolean, detail: any)
    table.insert(steps, { name = name, ok = ok, detail = if detail ~= nil then tostring(detail) else nil })
end

local errors, robloxErrors, corrections = {}, {}, {}
LogService.MessageOut:Connect(function(message, messageType)
    if messageType == Enum.MessageType.MessageError then
        local ours = string.find(message, "AutomotiveWorld", 1, true)
            or string.find(message, "ReplicatedStorage.Shared", 1, true)
            or string.find(message, "AW_Test", 1, true)
        table.insert(if ours then errors else robloxErrors, message)
    elseif messageType == Enum.MessageType.MessageWarning and string.find(message, "Mouvement impossible", 1, true) then
        table.insert(corrections, message)
    end
end)

local reportEvent = Instance.new("RemoteEvent")
reportEvent.Name = "AWTestReport"
reportEvent.Parent = ReplicatedStorage
local signalEvent = Instance.new("RemoteEvent")
signalEvent.Name = "AWTestSignal"
signalEvent.Parent = ReplicatedStorage
ReplicatedStorage:SetAttribute("AWTestSession", session)
ReplicatedStorage:SetAttribute("AWTestPlayers", 1)
ReplicatedStorage:SetAttribute("AWTestMovesVehicles", true)

local reports = {}
reportEvent.OnServerEvent:Connect(function(player, payload)
    reports[tostring(player.UserId)] = payload
end)
local done = {}
signalEvent.OnServerEvent:Connect(function(_, name)
    if type(name) == "string" then
        done[name] = true
    end
end)

local function waitFor(predicate: () -> boolean, timeout: number): boolean
    local start = os.clock()
    while os.clock() - start < timeout do
        if predicate() then
            return true
        end
        task.wait(0.2)
    end
    return predicate()
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldConfig = require(Shared.World.WorldConfig)
local WorldLayout = require(Shared.World.WorldLayout)
local server = ServerScriptService:WaitForChild("AutomotiveWorldServer")
local TrafficService = require(server.World.TrafficService)
local WeatherService = require(server.World.WeatherService)

-- 1. Carte, streaming, parc, apparitions.
local map = Workspace:WaitForChild("OpenWorld", 30)
record(
    "monde.carte_chargee",
    map ~= nil and map:GetAttribute("MapVersion") == WorldConfig.MapVersion,
    map
        and string.format(
            "version %s, %s pièces",
            tostring(map:GetAttribute("MapVersion")),
            tostring(map:GetAttribute("Parts"))
        )
)
record("monde.streaming_actif", Workspace.StreamingEnabled == true)
local fleet = Workspace:WaitForChild("VehiculesEssai", 20)
local vehicles = if fleet then fleet:GetChildren() else {}
record("monde.parc_neuf_prototypes", #vehicles == 9, #vehicles)
local enabled = {}
for _, spawn in (map and map:GetDescendants()) or {} do
    if spawn:IsA("SpawnLocation") and spawn.Enabled then
        local service = spawn:FindFirstAncestorWhichIsA("Model")
        table.insert(enabled, if service then service.Name else "?")
    end
end
record("monde.apparition_metropole_seule", #enabled == 1 and enabled[1] == "SPAWN-METRO", table.concat(enabled, ", "))

local settleStart = os.clock()
local settled = waitFor(function()
    for _, model in vehicles do
        local root = model.PrimaryPart
        if root == nil or root.AssemblyLinearVelocity.Magnitude >= 0.5 then
            return false
        end
    end
    return true
end, 15)
local fleetDetails = { string.format("immobiles après %.1f s", os.clock() - settleStart) }
local fleetOk = settled
for _, model in vehicles do
    local root = model.PrimaryPart
    if root then
        fleetOk = fleetOk and root.CFrame.UpVector.Y > 0.98
        table.insert(fleetDetails, string.format("%s Y=%.1f", model.Name, root.Position.Y))
    end
end
record("monde.parc_pose_immobile", fleetOk, table.concat(fleetDetails, " | "))

-- 2. Météo et horloge.
record(
    "monde.meteo_publiee",
    type(Workspace:GetAttribute("AWClockEpoch")) == "number"
        and type(Workspace:GetAttribute("AWWeather")) == "string"
        and type(Workspace:GetAttribute("AWRoadWetness")) == "number",
    tostring(Workspace:GetAttribute("AWWeather"))
)

-- 3. Lieux du lot 0.4 : invites sur les 13 entrées et 3 garages publics.
local prompts, economyPrompts = 0, 0
for _, item in (map and map:GetDescendants()) or {} do
    if item:IsA("ProximityPrompt") and item.Name == "AWProgressionPrompt" then
        prompts += 1
    elseif item:IsA("ProximityPrompt") and item.Name == "AWEconomyPrompt" then
        economyPrompts += 1
    end
end
record("monde.invites_lieux", prompts == 16, prompts)
-- Lot 0.5 : 2 concessions, 6 stations-service, 2 bornes, 3 lavages.
record("monde.invites_lieux_economiques", economyPrompts == 13, economyPrompts)
-- Lot 0.6 : 16 parcours du monde ouvert, chacun avec son point d'inscription physique.
local racePrompts = 0
for _, item in (map and map:GetDescendants()) or {} do
    if item:IsA("ProximityPrompt") and item.Name == "AWRacePrompt" then
        racePrompts += 1
    end
end
record("monde.points_inscription_courses", racePrompts == 16, racePrompts)
record("monde.canal_courses", ReplicatedStorage:FindFirstChild("AWRacing") ~= nil)

local player = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local character = player.Character or player.CharacterAdded:Wait()

-- 4. Trafic : agents, corps physiques au serveur, aucun tombé.
task.wait(20)
local traffic = TrafficService.snapshot()
local npcFolder = Workspace:FindFirstChild("TraficPNJ")
local npcCount, serverOwned, fallen = 0, 0, 0
for _, model in (npcFolder and npcFolder:GetChildren()) or {} do
    local root = model:IsA("Model") and model.PrimaryPart
    if root then
        npcCount += 1
        local ok, owner = pcall(function()
            return root:GetNetworkOwner()
        end)
        if ok and owner == nil then
            serverOwned += 1
        end
        if root.Position.Y < -40 or root.CFrame.UpVector.Y < 0.5 then
            fallen += 1
        end
    end
end
record(
    "monde.trafic_agents",
    traffic.Agents >= 100,
    string.format("%d agents, %d corps physiques", traffic.Agents, traffic.Physical)
)
record("monde.trafic_corps_pres_du_joueur", npcCount > 0, npcCount)
record(
    "monde.trafic_proprietaire_serveur",
    npcCount > 0 and serverOwned == npcCount,
    string.format("%d / %d", serverOwned, npcCount)
)
record("monde.trafic_aucun_tombe_ni_renverse", fallen == 0, fallen)

-- 5. Essai de conduite sur une portion droite de l'autoroute.
local layout = WorldLayout.get()
local function straightSegment(classes: { [string]: boolean }, minLength: number): (Vector3?, Vector3?, any)
    for _, edge in layout.Edges do
        if classes[edge.Class] and edge.LengthM > minLength + 200 then
            local points = edge.Polyline
            -- Point à 100 m du début, direction vers un point situé minLength plus loin.
            local function at(distance: number): any
                local travelled = 0
                for i = 2, #points do
                    local a, b = points[i - 1], points[i]
                    local d = math.sqrt((b.X - a.X) ^ 2 + (b.Z - a.Z) ^ 2)
                    if travelled + d >= distance then
                        local f = (distance - travelled) / d
                        return { X = a.X + (b.X - a.X) * f, Z = a.Z + (b.Z - a.Z) * f, Y = a.Y + (b.Y - a.Y) * f }
                    end
                    travelled += d
                end
                return points[#points]
            end
            local startPoint, endPoint = at(100), at(100 + minLength)
            local dx, dz = endPoint.X - startPoint.X, endPoint.Z - startPoint.Z
            local length = math.sqrt(dx * dx + dz * dz)
            local deviation = 0
            for distance = 100, 100 + minLength, 20 do
                local p = at(distance)
                local cross = math.abs((p.X - startPoint.X) * dz - (p.Z - startPoint.Z) * dx) / length
                deviation = math.max(deviation, cross)
            end
            if deviation < 1.5 then
                local direction = Vector3.new(dx / length, 0, dz / length)
                return Vector3.new(startPoint.X, startPoint.Y, startPoint.Z), direction, edge
            end
        end
    end
    return nil, nil, nil
end

local function placeOnRoad(model: Model, pointM: Vector3, direction: Vector3, lateralM: number)
    local right = Vector3.new(-direction.Z, 0, direction.X)
    local position = (pointM + right * lateralM) * S
    local definitionId = model:GetAttribute("DefinitionId")
    local cg = if definitionId == "proto_p03" then 0.47 elseif definitionId == "proto_p02" then 0.55 else 0.5
    local pivot = CFrame.lookAt(
        position + Vector3.new(0, cg * S + 1.5, 0),
        position + Vector3.new(0, cg * S + 1.5, 0) + direction
    )
    pcall(function()
        player:RequestStreamAroundAsync(position, 10)
    end)
    model:PivotTo(pivot)
    local root = model.PrimaryPart :: BasePart
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end

local highwayPoint, highwayDirection, highwayEdge = straightSegment({ Autoroute = true }, 600)
record("monde.portion_droite_trouvee", highwayPoint ~= nil, highwayEdge and highwayEdge.Id)
local driveModel = fleet and fleet:FindFirstChild("VehiculeEssai_1")
if highwayPoint and highwayDirection and driveModel then
    -- Voie de droite d'une chaussée à 3 voies : 3 voies × 3,5 m + terre-plein / 2.
    placeOnRoad(driveModel :: Model, highwayPoint, highwayDirection, 1.5 + 2.5 * 3.5)
    local right = Vector3.new(-highwayDirection.Z, 0, highwayDirection.X)
    character:PivotTo(CFrame.new((highwayPoint + right * (1.5 + 2.5 * 3.5 - 3)) * S + Vector3.new(0, 4, 0)))
    task.wait(3)
    ReplicatedStorage:SetAttribute("AWMondeVehicle", driveModel.Name)
    ReplicatedStorage:SetAttribute("AWMondeStage", "drive")
    local finished = waitFor(function()
        return done.MondeDriveDone == true
    end, 150)
    record("monde.conduite_terminee", finished)
end

-- 6. Repos sur une route de montagne, une rue et un chemin (véhicules du serveur).
local function restTest(label: string, classes: { [string]: boolean }, modelName: string)
    local point, direction, edge = straightSegment(classes, 40)
    local model = fleet and fleet:FindFirstChild(modelName)
    if point == nil or direction == nil or model == nil then
        record("monde.repos_" .. label, false, "portion ou véhicule introuvable")
        return
    end
    placeOnRoad(model :: Model, point, direction, 2)
    character:PivotTo(CFrame.new(point * S + Vector3.new(12, 6, 12)))
    task.wait(8)
    local root = (model :: Model).PrimaryPart :: BasePart
    local height = root.Position.Y - point.Y * S
    local speed = root.AssemblyLinearVelocity.Magnitude
    record(
        "monde.repos_" .. label,
        root.CFrame.UpVector.Y > 0.9 and height > 0.5 and height < 6 and speed < 2,
        string.format(
            "%s : hauteur %.2f st au-dessus du tracé, vitesse %.2f st/s, droit %.3f",
            edge.Id,
            height,
            speed,
            root.CFrame.UpVector.Y
        )
    )
end
restTest("route_montagne", { Montagne = true }, "VehiculeEssai_5")
restTest("rue", { Rue = true }, "VehiculeEssai_6")
restTest("chemin", { Chemin = true }, "VehiculeEssai_2")

-- 7. Pluie forcée : humidité publiée et lue.
WeatherService.force("Rain", 1)
task.wait(2)
record(
    "monde.pluie_forcee_publiee",
    Workspace:GetAttribute("AWWeather") == "Rain" and Workspace:GetAttribute("AWRoadWetness") == 1
)
ReplicatedStorage:SetAttribute("AWMondeStage", "rain")
waitFor(function()
    return done.MondeRainSeen == true
end, 20)
WeatherService.force("Clear", 0)

-- 8. Rapport du client et bilan.
waitFor(function()
    return next(reports) ~= nil
end, 60)
record("monde.rapport_client", next(reports) ~= nil)
record("monde.aucune_correction_serveur", #corrections == 0, #corrections .. " : " .. table.concat(corrections, " || "))
record("monde.aucune_erreur_execution", #errors == 0, table.concat(errors, " || "))
record("monde.info_erreurs_internes_roblox", true, #robloxErrors .. " : " .. table.concat(robloxErrors, " || "))

StudioTestService:EndTest({
    session = session,
    players = #Players:GetPlayers(),
    server = steps,
    clients = reports,
})
