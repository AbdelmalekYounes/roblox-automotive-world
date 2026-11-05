-- Essais SERVEUR du lot 0.9.1 (session « social », place de développement, 2 joueurs),
-- injectés par le pilote dans le Studio de test uniquement.
-- Relais de signaux entre clients, puis CONTRÔLE DE CONFIDENTIALITÉ côté serveur : le
-- client 2 renvoie tout ce qu'il a REÇU pendant la session (messages des remotes du jeu,
-- attributs répliqués du joueur 1) ; le serveur y cherche les données privées du joueur 1
-- (solde exact, identifiants des exemplaires de sa collection). Ces références ne
-- quittent jamais le serveur : aucun attribut répliqué ne les porte.
-- Profils en MÉMOIRE (environnement Dev) : aucun DataStore n'est touché.

local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StudioTestService = game:GetService("StudioTestService")

local args = StudioTestService:GetTestArgs()
local session = if type(args) == "table" and type(args.Session) == "string" then args.Session else ""
if session ~= "social" then
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
    reports[player] = payload
end)
-- « AWSO:<nom> » → attribut booléen ; « AWSOD:<clé>=<valeur> » → attribut texte (identifiants
-- publics seulement : numéro de joueur, invitation).
signalEvent.OnServerEvent:Connect(function(_, message)
    if type(message) ~= "string" then
        return
    end
    if string.sub(message, 1, 5) == "AWSO:" then
        ReplicatedStorage:SetAttribute("AWSO_" .. string.sub(message, 6), true)
    elseif string.sub(message, 1, 6) == "AWSOD:" then
        local key, value = string.match(string.sub(message, 7), "^(%w+)=(.*)$")
        if key then
            ReplicatedStorage:SetAttribute("AWSOD_" .. key, value)
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

local joined = waitFor(function()
    return #Players:GetPlayers() >= expectedPlayers
end, 60)
record("social.serveur.joueurs_connectes", joined, #Players:GetPlayers())
local gotReports = waitFor(function()
    local count = 0
    for _ in reports do
        count += 1
    end
    return count >= expectedPlayers
end, 900)
record("social.serveur.rapports_clients", gotReports)

local function byIndex(index: number): Player?
    for _, player in Players:GetPlayers() do
        if player:GetAttribute("AWTestIndex") == index then
            return player
        end
    end
    return nil
end

-- Recherche des données privées du joueur 1 dans ce que le joueur 2 a reçu.
local owner, guest = byIndex(1), byIndex(2)
local ownerData = owner and ProfileService.get(owner) and (ProfileService.get(owner) :: any).Data
local guestData = guest and ProfileService.get(guest) and (ProfileService.get(guest) :: any).Data
local observed = guest and reports[guest] and reports[guest].observed
if ownerData and guestData and type(observed) == "table" then
    local text = table.concat(observed, "\n")
    -- Montants : séparateurs de milliers retirés (espaces, espaces fines insécables).
    local normalized = string.gsub(string.gsub(text, "\u{202F}", " "), "\u{00A0}", " ")
    local digitsOnly = normalized
    for _ = 1, 2 do
        digitsOnly = string.gsub(digitsOnly, "(%d)[ .,](%d%d%d)", "%1%2")
    end
    local balance = tostring(ownerData.Wallet.Balance)
    local guestBalance = tostring(guestData.Wallet.Balance)
    local balanceLeak = balance ~= guestBalance and string.find(digitsOnly, balance, 1, true) ~= nil
    record(
        "social.confidentialite.solde_du_joueur_1_jamais_recu",
        balance ~= guestBalance and not balanceLeak,
        string.format(
            "%d message(s) / %d octets examinés ; solde du joueur 1 distinct du joueur 2 : %s",
            #observed,
            #text,
            tostring(balance ~= guestBalance)
        )
    )
    local leaked, checked = {}, 0
    for id in ownerData.Vehicles do
        checked += 1
        if guestData.Vehicles[id] == nil and string.find(text, id, 1, true) then
            table.insert(leaked, id)
        end
    end
    record(
        "social.confidentialite.collection_du_joueur_1_jamais_recue",
        checked > 0 and #leaked == 0,
        string.format("%d exemplaire(s) cherché(s), %d trouvé(s) : %s", checked, #leaked, table.concat(leaked, ", "))
    )
else
    record("social.confidentialite.donnees_disponibles", false, "profils ou observations absents")
end

for _, player in Players:GetPlayers() do
    local profileSession = ProfileService.get(player)
    local data = profileSession and profileSession.Data
    if data then
        local valid, problems = ProfileSchema.validate(data)
        record(
            "social.serveur.profil_coherent_" .. tostring(player:GetAttribute("AWTestIndex")),
            valid,
            table.concat(problems, " ; ")
        )
    end
end
record("social.serveur.aucune_erreur_execution", #errors == 0, table.concat(errors, " || "))
record(
    "social.serveur.info_erreurs_internes_roblox",
    true,
    #robloxErrors .. " : " .. table.concat(robloxErrors, " || ")
)

-- Les observations brutes ne sont pas recopiées dans le rapport (volume).
local clients = {}
for player, payload in reports do
    clients[tostring(player.UserId)] = { vehicle = payload.vehicle, steps = payload.steps, measures = payload.measures }
end
StudioTestService:EndTest({
    session = session,
    players = #Players:GetPlayers(),
    server = steps,
    clients = clients,
})
