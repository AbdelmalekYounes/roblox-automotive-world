-- Mesures CLIENT de référence (session « perf », place MONDE OUVERT), écrites au lot
-- 0.9 et injectées par le pilote dans le Studio de test uniquement. Pour chaque phase
-- annoncée par le serveur (jour, nuit, nuit sous la pluie) : temps d'image (médiane,
-- P95, P99, max) mesuré sur RenderStepped, mémoire du client, débit réseau reçu,
-- nombre de pièces chargées par le streaming, sources de lumière actives.
-- Studio dans une VM sans accélération graphique représentative : chiffres
-- INDICATIFS (méthode et outillage), à refaire sur des appareils réels.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")

local sessionStart = os.clock()
while ReplicatedStorage:GetAttribute("AWTestSession") == nil and os.clock() - sessionStart < 15 do
    task.wait()
end
if ReplicatedStorage:GetAttribute("AWTestSession") ~= "perf" then
    return
end

local player = Players.LocalPlayer
local reportEvent = ReplicatedStorage:WaitForChild("AWTestReport", 30) :: RemoteEvent
local steps = {}
local measures = {}

-- Attente du chargement initial (personnage et environnement).
local character = player.Character or player.CharacterAdded:Wait()
character:WaitForChild("HumanoidRootPart", 20)
task.wait(10)
local loadedAt = os.clock() - sessionStart
measures.chargement_s = math.floor(loadedAt * 10) / 10

local frames: { number } = {}
local currentPhase: string? = nil
RunService.RenderStepped:Connect(function(dt)
    if currentPhase then
        table.insert(frames, dt * 1000)
    end
end)

local function summarize(name: string)
    local list = table.clone(frames)
    table.sort(list)
    local function q(p: number): number
        return list[math.max(1, math.ceil(#list * p))] or 0
    end
    local parts, lights = 0, 0
    for _, item in Workspace:GetDescendants() do
        if item:IsA("BasePart") then
            parts += 1
        elseif item:IsA("Light") and item.Enabled then
            lights += 1
        end
    end
    measures[name] = {
        Frames = #list,
        MedianMs = math.floor(q(0.5) * 100) / 100,
        P95Ms = math.floor(q(0.95) * 100) / 100,
        P99Ms = math.floor(q(0.99) * 100) / 100,
        MaxMs = math.floor((list[#list] or 0) * 100) / 100,
        ClientMemoryMb = math.floor(Stats:GetTotalMemoryUsageMb()),
        ReceiveKbps = math.floor(Stats.DataReceiveKbps * 10) / 10,
        SendKbps = math.floor(Stats.DataSendKbps * 10) / 10,
        Parts = parts,
        ActiveLights = lights,
    }
end

local readyRemote = ReplicatedStorage:WaitForChild("AWTestSignal", 20)
if readyRemote and readyRemote:IsA("RemoteEvent") then
    readyRemote:FireServer("AWPerf:Ready")
end

local seen: { [string]: boolean } = {}
local deadline = os.clock() + 240
while os.clock() < deadline do
    local phase = ReplicatedStorage:GetAttribute("AWPerfPhase")
    if phase ~= currentPhase then
        if currentPhase and currentPhase ~= "fin" then
            summarize(currentPhase)
        end
        frames = {}
        currentPhase = if type(phase) == "string" then phase else nil
        if phase == "fin" then
            break
        end
        if type(phase) == "string" then
            seen[phase] = true
        end
    end
    task.wait(0.2)
end
table.insert(steps, { name = "perf.client.phases_mesurees", ok = seen.jour == true and seen.nuit_pluie == true })
reportEvent:FireServer({ vehicle = "perf", steps = steps, measures = measures })
