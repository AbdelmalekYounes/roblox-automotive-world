-- Pilote des tests Roblox Studio, exécuté par :
--   RobloxStudioBeta.exe --task RunScript --localPlaceFile place.rbxl --runScriptFile driver.luau
--                        --outputFile studio-output.log --quitAfterExecution
-- Contexte : DataModel d'ÉDITION, permissions de la barre de commande.
-- Ce fichier est un MODÈLE : tests/studio/build-driver.luau y insère les suites
-- et la liste des sessions. La place n'est jamais enregistrée : les scripts
-- injectés n'existent que dans le Studio de test.
-- Chaque résultat est imprimé sur une ligne « @@AW@@ {json} » lue par l'hôte.

local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local StudioTestService = game:GetService("StudioTestService")

local SERVER_SOURCE = [==[@@SERVER_SUITE@@]==]
local CLIENT_SOURCE = [==[@@CLIENT_SUITE@@]==]
local SCENARIO_SERVER_SOURCE = [==[@@SCENARIO_SERVER@@]==]
local SCENARIO_CLIENT_SOURCE = [==[@@SCENARIO_CLIENT@@]==]
local SESSIONS = HttpService:JSONDecode([==[@@SESSIONS@@]==])

local function emit(kind: string, data: any)
    print("@@AW@@ " .. HttpService:JSONEncode({ kind = kind, data = data }))
end

-- RunService:GetRobloxVersion() est interdit en RunScript (capacité RobloxScript) :
-- on lit la fonction globale version(), protégée au cas où elle le serait aussi.
-- selene: allow(undefined_variable)
local okVersion, studioVersion = pcall(version)
emit("start", { studio = if okVersion then studioVersion else "inconnue", sessions = SESSIONS })

local serverScript = Instance.new("Script")
serverScript.Name = "AW_TestServer"
serverScript.Source = SERVER_SOURCE
serverScript.Parent = ServerScriptService

local clientScript = Instance.new("LocalScript")
clientScript.Name = "AW_TestClient"
clientScript.Source = CLIENT_SOURCE
clientScript.Parent = StarterPlayer:WaitForChild("StarterPlayerScripts")

-- Scénarios étendus : inactifs hors des sessions « scenarios » et « collision ».
local scenarioServerScript = Instance.new("Script")
scenarioServerScript.Name = "AW_TestScenarioServer"
scenarioServerScript.Source = SCENARIO_SERVER_SOURCE
scenarioServerScript.Parent = ServerScriptService

local scenarioClientScript = Instance.new("LocalScript")
scenarioClientScript.Name = "AW_TestScenarioClient"
scenarioClientScript.Source = SCENARIO_CLIENT_SOURCE
scenarioClientScript.Parent = StarterPlayer:WaitForChild("StarterPlayerScripts")

-- Émulation de latence de Studio (réglages réseau) ; l'application effective
-- aux processus clients est mesurée par la suite client (ping), pas supposée.
local function setDelay(ms: number): (boolean, string?)
    local ok, err = pcall(function()
        local network = settings().Network
        network.InboundNetworkMinDelayMs = ms
        network.OutboundNetworkMinDelayMs = ms
    end)
    return ok, if ok then nil else tostring(err)
end

-- Une session lancée trop tôt peut se terminer sans résultat : délai initial.
task.wait(4)

for _, session in SESSIONS do
    local delayOk, delayError = true, nil
    if session.DelayMs then
        delayOk, delayError = setDelay(session.DelayMs)
    end
    local args = { Session = session.Name, Players = session.Players }
    local function launch()
        if session.Players > 1 then
            return StudioTestService:ExecuteMultiplayerTestAsync(session.Players, args)
        end
        return StudioTestService:ExecutePlayModeAsync(args)
    end
    local started = os.clock()
    local ok, result = pcall(launch)
    local attempts = 1
    if ok and result == nil then
        task.wait(4)
        attempts = 2
        ok, result = pcall(launch)
    end
    if session.DelayMs then
        setDelay(0)
    end
    emit("session", {
        name = session.Name,
        ok = ok,
        attempts = attempts,
        seconds = os.clock() - started,
        delayMs = session.DelayMs,
        delayApplied = delayOk,
        delayError = delayError,
        result = if ok then result else tostring(result),
    })
end

serverScript:Destroy()
clientScript:Destroy()
scenarioServerScript:Destroy()
scenarioClientScript:Destroy()
emit("end", {})
