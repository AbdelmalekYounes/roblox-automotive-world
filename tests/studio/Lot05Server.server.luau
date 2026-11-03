-- Essais SERVEUR du lot 0.5 (session « lot05 », place de développement, 2 joueurs),
-- écrits au lot 0.9 et injectés par le pilote dans le Studio de test uniquement.
-- Il relaie les signaux et les petites données entre clients, place un véhicule
-- personnel NON OCCUPÉ à la station d'essai quand un client le demande (mise en
-- place de l'essai, pas une action de jeu), puis vérifie l'état autoritaire :
-- portefeuilles cohérents (aucun solde négatif, aucun fonds réservé restant,
-- variation = gains − dépenses), aucun exemplaire en double entre profils,
-- profils valides, transactions confirmées. Profils en MÉMOIRE (environnement Dev).

local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StudioTestService = game:GetService("StudioTestService")
local Workspace = game:GetService("Workspace")

local args = StudioTestService:GetTestArgs()
local session = if type(args) == "table" and type(args.Session) == "string" then args.Session else ""
if session ~= "lot05" then
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
local ProgressionService = require(Server:WaitForChild("Progression"):WaitForChild("ProgressionService"))

local zone = Workspace:WaitForChild("AutomotiveTestZone", 20)
local station = zone and zone:WaitForChild("StationEssai", 10) :: BasePart?

-- Signaux « AW05:<nom> » → attribut booléen ; données « AW05D:<clé>=<valeur> » → attribut texte.
signalEvent.OnServerEvent:Connect(function(player, message)
    if type(message) ~= "string" then
        return
    end
    if string.sub(message, 1, 5) == "AW05:" then
        local name = string.sub(message, 6)
        ReplicatedStorage:SetAttribute("AW05_" .. name, true)
        if name == "MoveToStation" and station then
            -- Mise en place : le véhicule sorti (inoccupé, simulé par le serveur) est posé à la station.
            local model = ProgressionService.outVehicle(player)
            if model then
                model:PivotTo(station.CFrame * CFrame.new(0, 4, 0))
                ReplicatedStorage:SetAttribute("AW05_AtStation", true)
            end
        end
    elseif string.sub(message, 1, 6) == "AW05D:" then
        local key, value = string.match(string.sub(message, 7), "^(%w+)=(.*)$")
        if key then
            ReplicatedStorage:SetAttribute("AW05D_" .. key, value)
        end
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

record("lot05.serveur.canal_economie", ReplicatedStorage:WaitForChild("AWEconomy", 20) ~= nil)
record("lot05.serveur.station_essai", station ~= nil)
local joined = waitFor(function()
    return #Players:GetPlayers() >= expectedPlayers
end, 60)
record("lot05.serveur.joueurs_connectes", joined, #Players:GetPlayers())
local loaded = waitFor(function()
    for _, player in Players:GetPlayers() do
        local profileSession = ProfileService.get(player)
        if profileSession == nil or profileSession.State ~= "Active" then
            return false
        end
    end
    return true
end, 40)
record("lot05.serveur.profils_actifs", loaded)

-- État initial des portefeuilles (référence des contrôles de fin).
local initial = {}
for _, player in Players:GetPlayers() do
    local data = ProfileService.get(player) and (ProfileService.get(player) :: any).Data
    if data then
        initial[player] = {
            Balance = data.Wallet.Balance,
            Earned = data.Wallet.Earned,
            Spent = data.Wallet.Spent,
        }
    end
end

local gotReports = waitFor(function()
    local count = 0
    for _ in reports do
        count += 1
    end
    return count >= expectedPlayers
end, 480)
record("lot05.serveur.rapports_clients", gotReports)

local confirmed = waitFor(function()
    for _, player in Players:GetPlayers() do
        local profileSession = ProfileService.get(player)
        if profileSession and next(profileSession.Pending) ~= nil then
            return false
        end
    end
    return true
end, 30)
record("lot05.serveur.transactions_confirmees", confirmed)

-- Portefeuilles et exemplaires : cohérence autoritaire après toutes les opérations.
local owners: { [string]: number } = {}
local duplicates = {}
for _, player in Players:GetPlayers() do
    local profileSession = ProfileService.get(player)
    local data = profileSession and profileSession.Data
    if data then
        local index = player:GetAttribute("AWTestIndex")
        local start = initial[player]
        local wallet = data.Wallet
        local delta = wallet.Balance - (if start then start.Balance else wallet.Balance)
        local flows = if start then (wallet.Earned - start.Earned) - (wallet.Spent - start.Spent) else delta
        record(
            "lot05.serveur.portefeuille_coherent_" .. index,
            wallet.Balance >= 0 and wallet.Reserved == 0 and delta == flows,
            string.format(
                "solde %d (variation %+d, gains − dépenses %+d), réservé %d",
                wallet.Balance,
                delta,
                flows,
                wallet.Reserved
            )
        )
        for id in data.Vehicles do
            owners[id] = (owners[id] or 0) + 1
            if owners[id] > 1 then
                table.insert(duplicates, id)
            end
        end
        local valid, problems = ProfileSchema.validate(data)
        record("lot05.serveur.profil_coherent_" .. index, valid, table.concat(problems, " ; "))
    end
end
record("lot05.serveur.aucun_exemplaire_en_double", #duplicates == 0, table.concat(duplicates, ", "))

record("lot05.serveur.aucune_erreur_execution", #errors == 0, table.concat(errors, " || "))
record("lot05.serveur.info_erreurs_internes_roblox", true, #robloxErrors .. " : " .. table.concat(robloxErrors, " || "))

StudioTestService:EndTest({
    session = session,
    players = #Players:GetPlayers(),
    server = steps,
    clients = reports,
})
