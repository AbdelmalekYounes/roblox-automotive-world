-- Essais SERVEUR du lot 0.6 (session « lot06 », place de développement, 2 joueurs),
-- écrits au lot 0.9 et injectés par le pilote dans le Studio de test uniquement.
-- Il relaie les signaux entre clients puis vérifie l'état autoritaire après les
-- épreuves : aucune épreuve restée ouverte ou en cours, aucun engagement actif ni
-- exemplaire réservé dans les profils, portefeuilles cohérents (gains − dépenses),
-- profils valides, transactions confirmées. Profils en MÉMOIRE (environnement Dev).

local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StudioTestService = game:GetService("StudioTestService")

local args = StudioTestService:GetTestArgs()
local session = if type(args) == "table" and type(args.Session) == "string" then args.Session else ""
if session ~= "lot06" then
    return
end
local expectedPlayers = if type(args) == "table" and type(args.Players) == "number" then args.Players else 2

local steps = {}
local function record(name: string, ok: boolean, detail: any)
    table.insert(steps, { name = name, ok = ok, detail = if detail ~= nil then tostring(detail) else nil })
end

local errors, robloxErrors, validation = {}, {}, {}
LogService.MessageOut:Connect(function(message, messageType)
    if messageType == Enum.MessageType.MessageError then
        local ours = string.find(message, "AutomotiveWorld", 1, true)
            or string.find(message, "ReplicatedStorage.Shared", 1, true)
            or string.find(message, "AW_Test", 1, true)
        table.insert(if ours then errors else robloxErrors, message)
    elseif string.find(message, "[Validation]", 1, true) then
        table.insert(validation, message)
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
-- Mise en place (test seulement) : « AW06:Place:<véhicule>:<épreuve> » pose le prototype
-- INOCCUPÉ du parc au point d'inscription de l'épreuve, puis « AW06_Placed » est publié.
signalEvent.OnServerEvent:Connect(function(_, name)
    if type(name) ~= "string" or string.sub(name, 1, 5) ~= "AW06:" then
        return
    end
    local vehicleName, courseId = string.match(name, "^AW06:Place:([^:]+):(.+)$")
    if vehicleName and courseId then
        local RaceService = require(
            game:GetService("ServerScriptService").AutomotiveWorldServer
                :WaitForChild("Racing")
                :WaitForChild("RaceService")
        ) :: any
        local built = RaceService.state().Courses[courseId]
        local fleet = workspace:FindFirstChild("VehiculesEssai")
        local model = fleet and fleet:FindFirstChild(vehicleName) :: Model?
        if built and model and model:GetAttribute("DriverUserId") == 0 then
            local reg = built.Registration
            local S = 1 / 0.28
            model:PivotTo(CFrame.new(reg.X * S, 4, reg.Z * S) * CFrame.Angles(0, -(reg.Heading or 0), 0))
        end
        ReplicatedStorage:SetAttribute("AW06_Placed", courseId)
        return
    end
    ReplicatedStorage:SetAttribute("AW06_" .. string.sub(name, 6), true)
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

local Server = ServerScriptService:WaitForChild("AutomotiveWorldServer")
local ProfileService = require(Server:WaitForChild("Persistence"):WaitForChild("ProfileService"))
local ProfileSchema = require(Server.Persistence.ProfileSchema)

record("lot06.serveur.canal_courses", ReplicatedStorage:WaitForChild("AWRacing", 20) ~= nil)
local joined = waitFor(function()
    return #Players:GetPlayers() >= expectedPlayers
end, 60)
record("lot06.serveur.joueurs_connectes", joined, #Players:GetPlayers())
waitFor(function()
    for _, player in Players:GetPlayers() do
        local profileSession = ProfileService.get(player)
        if profileSession == nil or profileSession.State ~= "Active" then
            return false
        end
    end
    return true
end, 40)
local initial = {}
for _, player in Players:GetPlayers() do
    local profileSession = ProfileService.get(player)
    local data = profileSession and profileSession.Data
    if data then
        initial[player] = { Balance = data.Wallet.Balance, Earned = data.Wallet.Earned, Spent = data.Wallet.Spent }
    end
end

local gotReports = waitFor(function()
    local count = 0
    for _ in reports do
        count += 1
    end
    return count >= expectedPlayers
end, 1500)
record("lot06.serveur.rapports_clients", gotReports)

waitFor(function()
    for _, player in Players:GetPlayers() do
        local profileSession = ProfileService.get(player)
        if profileSession and next(profileSession.Pending) ~= nil then
            return false
        end
    end
    return true
end, 30)
for _, player in Players:GetPlayers() do
    local profileSession = ProfileService.get(player)
    local data = profileSession and profileSession.Data
    if data then
        local index = player:GetAttribute("AWTestIndex")
        local reserved = 0
        for _, vehicle in data.Vehicles do
            if vehicle.Reservation and vehicle.Reservation.Kind == "Race" then
                reserved += 1
            end
        end
        record(
            "lot06.serveur.aucun_engagement_restant_" .. index,
            data.Racing.Active == nil and reserved == 0,
            string.format("engagement %s, %d exemplaire(s) réservé(s)", tostring(data.Racing.Active ~= nil), reserved)
        )
        local start = initial[player]
        local wallet = data.Wallet
        local delta = wallet.Balance - (if start then start.Balance else wallet.Balance)
        local flows = if start then (wallet.Earned - start.Earned) - (wallet.Spent - start.Spent) else delta
        record(
            "lot06.serveur.portefeuille_coherent_" .. index,
            wallet.Balance >= 0 and wallet.Reserved == 0 and delta == flows,
            string.format("variation %+d, gains − dépenses %+d, réservé %d", delta, flows, wallet.Reserved)
        )
        local valid, problems = ProfileSchema.validate(data)
        record("lot06.serveur.profil_coherent_" .. index, valid, table.concat(problems, " ; "))
    end
end
record("lot06.serveur.info_journal_validation", true, #validation .. " : " .. table.concat(validation, " || "))
record("lot06.serveur.aucune_erreur_execution", #errors == 0, table.concat(errors, " || "))
record("lot06.serveur.info_erreurs_internes_roblox", true, #robloxErrors .. " : " .. table.concat(robloxErrors, " || "))

StudioTestService:EndTest({
    session = session,
    players = #Players:GetPlayers(),
    server = steps,
    clients = reports,
})
