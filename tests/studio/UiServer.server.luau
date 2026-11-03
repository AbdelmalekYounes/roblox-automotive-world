-- Essais SERVEUR du lot 0.9.1 (sessions « ui » et « ui_monde », 1 joueur), injectés
-- par le pilote dans le Studio de test uniquement.
-- Rôle : recueillir le rapport du client, offrir une LECTURE de l'état autoritaire
-- (AWTestQuery, test seulement) pour vérifier côté serveur le résultat d'un parcours
-- d'interface réalisé par de vrais clics, puis contrôler la cohérence des profils.
-- Le client ne peut rien MODIFIER par ces points d'accès : ils lisent, ou posent le
-- décor d'un essai (signal « AWUI:… »), ce qui est signalé dans le rapport.
-- Profils en MÉMOIRE (environnement Dev) : aucun DataStore n'est touché.

local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StudioTestService = game:GetService("StudioTestService")

local args = StudioTestService:GetTestArgs()
local session = if type(args) == "table" and type(args.Session) == "string" then args.Session else ""
if session ~= "ui" and session ~= "ui_monde" then
    return
end

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
local query = Instance.new("RemoteFunction")
query.Name = "AWTestQuery"
query.Parent = ReplicatedStorage
ReplicatedStorage:SetAttribute("AWTestSession", session)
ReplicatedStorage:SetAttribute("AWTestPlayers", 1)

local Server = ServerScriptService:WaitForChild("AutomotiveWorldServer")
local ProfileService = require(Server:WaitForChild("Persistence"):WaitForChild("ProfileService"))
local ProfileSchema = require(Server.Persistence.ProfileSchema)

local reports = {}
reportEvent.OnServerEvent:Connect(function(player, payload)
    reports[tostring(player.UserId)] = payload
end)

-- Décor d'essai (signalé) : « AWUI:Seat » assoit le joueur au volant d'un prototype libre
-- du parc (comme le ferait l'invite, quand l'activation scriptée de l'invite échoue).
signalEvent.OnServerEvent:Connect(function(player, name)
    if type(name) ~= "string" or string.sub(name, 1, 5) ~= "AWUI:" then
        return
    end
    ReplicatedStorage:SetAttribute("AWUI_" .. string.sub(name, 6), true)
    record("ui.serveur.info_decor", true, name .. " (" .. player.Name .. ")")
end)

-- Résumé LISIBLE de l'état autoritaire (lecture seule, aucune donnée d'un autre joueur).
local function count(list: any): number
    local n = 0
    if type(list) == "table" then
        for _ in list do
            n += 1
        end
    end
    return n
end
query.OnServerInvoke = function(player)
    local profileSession = ProfileService.get(player)
    local data = profileSession and profileSession.Data
    if data == nil then
        return { Ready = false }
    end
    local vehicles = {}
    for id, vehicle in data.Vehicles do
        table.insert(vehicles, {
            Id = id,
            Model = vehicle.ModelId or vehicle.Model,
            Kind = vehicle.Kind,
            Reserved = vehicle.Reservation ~= nil,
            Custom = vehicle.Customization,
        })
    end
    return {
        Ready = true,
        Balance = data.Wallet.Balance,
        Reserved = data.Wallet.Reserved,
        Earned = data.Wallet.Earned,
        Spent = data.Wallet.Spent,
        Vehicles = vehicles,
        VehicleCount = count(data.Vehicles),
        Properties = count(data.Properties),
        Parts = count(data.Parts),
        Invitations = count(data.Invitations),
        Transactions = count(data.Transactions),
        Jobs = data.Jobs,
        Starter = data.Starter,
        Onboarding = data.Onboarding,
        Preferences = data.Preferences,
        RacingActive = data.Racing.Active ~= nil,
        RacingStats = data.Racing.Stats,
        Reputation = data.Reputation.Points,
    }
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

local joined = waitFor(function()
    return #Players:GetPlayers() >= 1
end, 60)
record("ui.serveur.joueur_connecte", joined, #Players:GetPlayers())
local gotReport = waitFor(function()
    return next(reports) ~= nil
end, 1700)
record("ui.serveur.rapport_client", gotReport)

for _, player in Players:GetPlayers() do
    local profileSession = ProfileService.get(player)
    local data = profileSession and profileSession.Data
    if data then
        local wallet = data.Wallet
        record(
            "ui.serveur.portefeuille_coherent",
            wallet.Balance >= 0 and wallet.Reserved >= 0,
            string.format("solde %d, réservé %d", wallet.Balance, wallet.Reserved)
        )
        local valid, problems = ProfileSchema.validate(data)
        record("ui.serveur.profil_coherent", valid, table.concat(problems, " ; "))
    end
end
record("ui.serveur.info_journal_validation", true, #validation .. " : " .. table.concat(validation, " || "))
record("ui.serveur.aucune_erreur_execution", #errors == 0, table.concat(errors, " || "))
record("ui.serveur.info_erreurs_internes_roblox", true, #robloxErrors .. " : " .. table.concat(robloxErrors, " || "))

StudioTestService:EndTest({
    session = session,
    players = #Players:GetPlayers(),
    server = steps,
    clients = reports,
})
