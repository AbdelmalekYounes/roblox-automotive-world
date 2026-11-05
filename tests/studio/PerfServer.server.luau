-- Mesures SERVEUR de référence (session « perf », place MONDE OUVERT, 1 joueur),
-- écrites au lot 0.9 et injectées par le pilote dans le Studio de test uniquement.
-- Trois phases de 45 s : jour clair, puis nuit (horloge avancée), puis nuit sous
-- la pluie (météo forcée). Relevés : pas de simulation des véhicules et battement
-- serveur (PerfStats, points d'accès de test), mémoire du serveur, agents du trafic,
-- nombre d'instances. Studio dans une VM : valeurs INDICATIVES (outillage), jamais
-- des résultats de performance du jeu publié.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Stats = game:GetService("Stats")
local StudioTestService = game:GetService("StudioTestService")
local Workspace = game:GetService("Workspace")

local args = StudioTestService:GetTestArgs()
local session = if type(args) == "table" and type(args.Session) == "string" then args.Session else ""
if session ~= "perf" then
    return
end

local steps = {}
local measures = {}
local function record(name: string, ok: boolean, detail: any)
    table.insert(steps, { name = name, ok = ok, detail = if detail ~= nil then tostring(detail) else nil })
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

local reportEvent = Instance.new("RemoteEvent")
reportEvent.Name = "AWTestReport"
reportEvent.Parent = ReplicatedStorage
ReplicatedStorage:SetAttribute("AWTestSession", session)
local signalEvent = Instance.new("RemoteEvent")
signalEvent.Name = "AWTestSignal"
signalEvent.Parent = ReplicatedStorage
signalEvent.OnServerEvent:Connect(function(_, message)
    if message == "AWPerf:Ready" then
        ReplicatedStorage:SetAttribute("AWPerfClientReady", true)
    end
end)
local reports = {}
reportEvent.OnServerEvent:Connect(function(player, payload)
    reports[tostring(player.UserId)] = payload
end)

local Server = ServerScriptService:WaitForChild("AutomotiveWorldServer")
local WorldFolder = Server:WaitForChild("World")
local WeatherService = require(WorldFolder:WaitForChild("WeatherService"))
local TrafficService = require(WorldFolder:WaitForChild("TrafficService"))
local WeatherModel =
    require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("World"):WaitForChild("WeatherModel"))
local hooks = ServerStorage:WaitForChild("AWTestHooks", 20) :: BindableFunction?

waitFor(function()
    return #Players:GetPlayers() >= 1
end, 60)
waitFor(function()
    return ReplicatedStorage:GetAttribute("AWPerfClientReady") == true
end, 90)

local function phase(name: string, seconds: number)
    if hooks then
        hooks:Invoke("ResetPerf")
    end
    ReplicatedStorage:SetAttribute("AWPerfPhase", name)
    local heartbeat = {}
    local started = os.clock()
    local connection = game:GetService("RunService").Heartbeat:Connect(function(dt)
        table.insert(heartbeat, dt * 1000)
    end)
    task.wait(seconds)
    connection:Disconnect()
    table.sort(heartbeat)
    local function q(p: number): number
        return heartbeat[math.max(1, math.ceil(#heartbeat * p))] or 0
    end
    local perf = if hooks then hooks:Invoke("ServerPerf") else nil
    local traffic = TrafficService.snapshot()
    measures[name] = {
        DurationS = math.floor((os.clock() - started) * 10) / 10,
        HeartbeatMedianMs = math.floor(q(0.5) * 100) / 100,
        HeartbeatP95Ms = math.floor(q(0.95) * 100) / 100,
        HeartbeatP99Ms = math.floor(q(0.99) * 100) / 100,
        VehicleStep = perf and perf.VehicleStep,
        Damage = perf and perf.Damage,
        Vehicles = perf and perf.Vehicles,
        TrafficAgents = traffic.Agents,
        TrafficPhysical = traffic.Physical,
        ServerMemoryMb = math.floor(Stats:GetTotalMemoryUsageMb()),
        Instances = #Workspace:GetDescendants(),
    }
end

phase("jour", 45)
-- Nuit : l'horloge partagée est avancée à 22 h (cycle de 30 min, lot 0.3).
local now = Workspace:GetServerTimeNow()
Workspace:SetAttribute("AWClockEpoch", now - ((22 - WeatherModel.StartHour) % 24) / 24 * WeatherModel.DayLengthS)
phase("nuit", 45)
WeatherService.force("Rain", 1)
phase("nuit_pluie", 45)
WeatherService.force("Clear", 0)
ReplicatedStorage:SetAttribute("AWPerfPhase", "fin")

local got = waitFor(function()
    return next(reports) ~= nil
end, 60)
record("perf.serveur.rapport_client", got)
record("perf.serveur.mesures_relevees", measures.jour ~= nil and measures.nuit_pluie ~= nil)

StudioTestService:EndTest({
    session = session,
    players = #Players:GetPlayers(),
    server = steps,
    measures = measures,
    clients = reports,
})
