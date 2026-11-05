-- Essais SERVEUR du lot UI-01 (session « ui_design », place de développement, 1 joueur, vraies entrées dans la VM) :
-- ouvre la page de démonstration du système de conception V1.2 (attribut AWDesignDemo, Studio seulement) et attend
-- le rapport du client. Aucune donnée de jeu touchée.

local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")

local args = StudioTestService:GetTestArgs()
local session = if type(args) == "table" and type(args.Session) == "string" then args.Session else ""
-- « ui_phone » (lot UI-02) : même serveur, sans la page de démonstration (téléphone seul).
-- « ui_garage » (UI-03) et « ui_panels » (UI-04) : même serveur, écran concerné seul.
if session ~= "ui_design" and session ~= "ui_phone" and session ~= "ui_garage" and session ~= "ui_panels" then
    return
end

local steps = {}
local function record(name: string, ok: boolean, detail: any)
    table.insert(steps, { name = name, ok = ok, detail = if detail ~= nil then tostring(detail) else nil })
end
local errors = {}
LogService.MessageOut:Connect(function(message, messageType)
    if messageType == Enum.MessageType.MessageError then
        if
            string.find(message, "AutomotiveWorld", 1, true)
            or string.find(message, "ReplicatedStorage.Shared", 1, true)
            or string.find(message, "AW_Test", 1, true)
        then
            table.insert(errors, message)
        end
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

record(
    session .. ".serveur.joueur_connecte",
    waitFor(function()
        return #Players:GetPlayers() >= 1
    end, 60)
)
task.wait(3)
if session == "ui_design" then
    ReplicatedStorage:SetAttribute("AWDesignDemo", true)
end
record(
    session .. ".serveur.rapport_client",
    waitFor(function()
        return next(reports) ~= nil
    end, 300)
)
ReplicatedStorage:SetAttribute("AWDesignDemo", false)
record(session .. ".serveur.aucune_erreur_execution", #errors == 0, table.concat(errors, " || "))
StudioTestService:EndTest({ session = session, players = 1, server = steps, clients = reports })
