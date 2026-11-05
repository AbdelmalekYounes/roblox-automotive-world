-- Essais SERVEUR du lot 0.4 (session « lot04 », place de développement, 2 joueurs),
-- injectés par le pilote dans le Studio de test uniquement. Ce script remplace
-- ServerSuite pour cette session : il prépare les canaux de rapport, relaie les
-- signaux entre clients, vérifie l'état autoritaire (profils en MÉMOIRE,
-- propriétés, invites, transactions confirmées) et termine la session.
-- Aucune écriture DataStore : l'environnement doit être « Dev » (mémoire).

local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StudioTestService = game:GetService("StudioTestService")
local Workspace = game:GetService("Workspace")

local args = StudioTestService:GetTestArgs()
local session = if type(args) == "table" and type(args.Session) == "string" then args.Session else ""
if session ~= "lot04" then
    return
end
local expectedPlayers = if type(args) == "table" and type(args.Players) == "number" then args.Players else 2

local steps = {}
local function record(name: string, ok: boolean, detail: any)
    table.insert(steps, { name = name, ok = ok, detail = if detail ~= nil then tostring(detail) else nil })
end

local errors, robloxErrors = {}, {}
LogService.MessageOut:Connect(function(message, messageType)
    if messageType == Enum.MessageType.MessageError then
        local ours = string.find(message, "AutomotiveWorld", 1, true)
            or string.find(message, "ReplicatedStorage.Shared", 1, true)
            or string.find(message, "AW_Test", 1, true)
        table.insert(if ours then errors else robloxErrors, message)
    end
end)

local reportEvent = Instance.new("RemoteEvent")
reportEvent.Name = "AWTestReport"
reportEvent.Parent = ReplicatedStorage
local signalEvent = Instance.new("RemoteEvent")
signalEvent.Name = "AWTestSignal"
signalEvent.Parent = ReplicatedStorage
ReplicatedStorage:SetAttribute("AWTestSession", session)
ReplicatedStorage:SetAttribute("AWTestPlayers", expectedPlayers)

local reports = {}
reportEvent.OnServerEvent:Connect(function(player, payload)
    reports[tostring(player.UserId)] = payload
end)
-- Signaux entre clients : « AW04:<nom> » → attribut AW04_<nom>.
signalEvent.OnServerEvent:Connect(function(_, name)
    if type(name) == "string" and string.sub(name, 1, 5) == "AW04:" then
        ReplicatedStorage:SetAttribute("AW04_" .. string.sub(name, 6), true)
    end
end)

local joinCount = 0
local function assign(player: Player)
    if player:GetAttribute("AWTestIndex") == nil then
        joinCount += 1
        player:SetAttribute("AWTestIndex", joinCount)
    end
end
Players.PlayerAdded:Connect(assign)
for _, player in Players:GetPlayers() do
    assign(player)
end

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

local ProfileService = require(
    ServerScriptService:WaitForChild("AutomotiveWorldServer"):WaitForChild("Persistence"):WaitForChild("ProfileService")
)
local ProfileSchema = require(ServerScriptService.AutomotiveWorldServer.Persistence.ProfileSchema)

-- L'attribut est publié au démarrage de ProfileService (après les autres services).
waitFor(function()
    return ReplicatedStorage:GetAttribute("AWStorageEnvironment") ~= nil
end, 20)
record(
    "lot04.serveur.environnement_memoire",
    ReplicatedStorage:GetAttribute("AWStorageEnvironment") == "Dev",
    ReplicatedStorage:GetAttribute("AWStorageEnvironment")
)
local progression = ReplicatedStorage:WaitForChild("AWProgression", 20)
record(
    "lot04.serveur.canaux_progression",
    progression ~= nil and progression:FindFirstChild("Request") ~= nil and progression:FindFirstChild("Push") ~= nil
)
local zone = Workspace:WaitForChild("AutomotiveTestZone", 20)
local entrance = zone and zone:FindFirstChild("EntreeProprieteEssai")
local garage = zone and zone:FindFirstChild("GaragePublicEssai")
record(
    "lot04.serveur.invites_entree_et_garage",
    entrance ~= nil
        and garage ~= nil
        and entrance:FindFirstChild("AWProgressionPrompt") ~= nil
        and garage:FindFirstChild("AWProgressionPrompt") ~= nil
)

local joined = waitFor(function()
    return #Players:GetPlayers() >= expectedPlayers
end, 60)
record("lot04.serveur.joueurs_connectes", joined, #Players:GetPlayers())

-- Profils chargés, propriété gratuite unique et données synthétiques de Dev.
local loaded = waitFor(function()
    for _, player in Players:GetPlayers() do
        local profileSession = ProfileService.get(player)
        if profileSession == nil or profileSession.State ~= "Active" then
            return false
        end
    end
    return true
end, 40)
record("lot04.serveur.profils_actifs", loaded)
-- Lot 0.6 : six épreuves d'essai (une par discipline), profils au schéma 3.
local racePrompts = 0
local coursesFolder = Workspace:FindFirstChild("Courses")
for _, item in (coursesFolder and coursesFolder:GetDescendants()) or {} do
    if item:IsA("ProximityPrompt") and item.Name == "AWRacePrompt" then
        racePrompts += 1
    end
end
record("lot04.serveur.points_inscription_courses", racePrompts == 6, racePrompts)
record("lot04.serveur.canal_courses", ReplicatedStorage:FindFirstChild("AWRacing") ~= nil)
-- Lot 0.7 : canaux d'interface et des groupes ; profils au schéma 4 (préférences).
record(
    "lot04.serveur.interface_et_groupes",
    ReplicatedStorage:FindFirstChild("AWInterface") ~= nil and ReplicatedStorage:FindFirstChild("AWSocial") ~= nil,
    nil
)
for _, player in Players:GetPlayers() do
    local profileSession = ProfileService.get(player)
    local data = profileSession and profileSession.Data
    if data then
        local properties, vehicles, free = 0, 0, 0
        for _, property in data.Properties do
            properties += 1
            if property.Origin == "FreeStarter" then
                free += 1
            end
        end
        for _ in data.Vehicles do
            vehicles += 1
        end
        record(
            "lot04.serveur.profil_initial_" .. player:GetAttribute("AWTestIndex"),
            free == 1 and properties == 2 and vehicles == 3 and data.Starter.State == "Pending",
            string.format(
                "%d propriété(s) dont %d gratuite, %d véhicule(s), starter %s",
                properties,
                free,
                vehicles,
                data.Starter.State
            )
        )
    end
end

-- Rapports des deux clients.
local gotReports = waitFor(function()
    local count = 0
    for _ in reports do
        count += 1
    end
    return count >= expectedPlayers
end, 420)
record("lot04.serveur.rapports_clients", gotReports)

-- Transactions toutes confirmées (sauvegardes en mémoire), profils cohérents.
local confirmed = waitFor(function()
    for _, player in Players:GetPlayers() do
        local profileSession = ProfileService.get(player)
        if profileSession and next(profileSession.Pending) ~= nil then
            return false
        end
    end
    return true
end, 30)
record("lot04.serveur.transactions_confirmees", confirmed)
for _, player in Players:GetPlayers() do
    local profileSession = ProfileService.get(player)
    if profileSession and profileSession.Data then
        local valid, problems = ProfileSchema.validate(profileSession.Data)
        record(
            "lot04.serveur.profil_coherent_" .. player:GetAttribute("AWTestIndex"),
            valid,
            table.concat(problems, " ; ")
        )
    end
end
local personal = Workspace:FindFirstChild("VehiculesPersonnels")
local remaining = 0
if personal then
    remaining = #personal:GetChildren()
end
record("lot04.serveur.aucun_vehicule_personnel_restant", remaining == 0, remaining)

record("lot04.serveur.aucune_erreur_execution", #errors == 0, table.concat(errors, " || "))
record("lot04.serveur.info_erreurs_internes_roblox", true, #robloxErrors .. " : " .. table.concat(robloxErrors, " || "))

StudioTestService:EndTest({
    session = session,
    players = #Players:GetPlayers(),
    server = steps,
    clients = reports,
})
