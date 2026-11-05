--!strict
-- Génère le pilote RunScript à partir du modèle et des suites, puis vérifie
-- qu'il compile (une erreur de syntaxe dans un script RunScript n'est signalée
-- nulle part par Studio).
-- Usage : lune run tests/studio/build-driver.luau <sortie.luau> [sessions séparées par des virgules]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")

local KNOWN_SESSIONS = {
    solo = { Name = "solo", Players = 1 },
    multijoueur = { Name = "multijoueur", Players = 2 },
    latence = { Name = "latence", Players = 2, DelayMs = 100 },
    scenarios = { Name = "scenarios", Players = 1 },
    collision = { Name = "collision", Players = 2 },
    collision_latence = { Name = "collision_latence", Players = 2, DelayMs = 100 },
    lot02 = { Name = "lot02", Players = 1 },
    -- Lot 0.3 : place MONDE OUVERT (host-run.ps1 -Place OpenWorld).
    monde = { Name = "monde", Players = 1 },
    -- Lot 0.4 : progression, place de développement, deux joueurs.
    lot04 = { Name = "lot04", Players = 2 },
}

local output = process.args[1]
if output == nil then
    print(
        "Usage : lune run tests/studio/build-driver.luau <sortie.luau> [solo,multijoueur,latence,scenarios,collision,collision_latence,lot02]"
    )
    process.exit(2)
end

local sessions = {}
for name in
    string.gmatch(process.args[2] or "solo,multijoueur,latence,scenarios,collision,collision_latence,lot02", "[^,]+")
do
    local session = KNOWN_SESSIONS[name]
    if session == nil then
        print("Session inconnue : " .. name)
        process.exit(2)
    end
    table.insert(sessions, session)
end

local base = "tests/studio/"
local template = fs.readFile(base .. "Driver.template.luau")
local server = fs.readFile(base .. "ServerSuite.server.luau")
local client = fs.readFile(base .. "ClientSuite.client.luau")
local scenarioServer = fs.readFile(base .. "ScenarioServer.server.luau")
local scenarioClient = fs.readFile(base .. "ScenarioClient.client.luau")
local lot02Server = fs.readFile(base .. "Lot02Server.server.luau")
local lot02Client = fs.readFile(base .. "Lot02Client.client.luau")
local mondeServer = fs.readFile(base .. "MondeServer.server.luau")
local mondeClient = fs.readFile(base .. "MondeClient.client.luau")
local lot04Server = fs.readFile(base .. "Lot04Server.server.luau")
local lot04Client = fs.readFile(base .. "Lot04Client.client.luau")

for label, source in
    {
        serveur = server,
        client = client,
        scenarioServeur = scenarioServer,
        scenarioClient = scenarioClient,
        lot02Serveur = lot02Server,
        lot02Client = lot02Client,
        mondeServeur = mondeServer,
        mondeClient = mondeClient,
        lot04Serveur = lot04Server,
        lot04Client = lot04Client,
    }
do
    assert(not string.find(source, "]==]", 1, true), "La suite " .. label .. " ne doit pas contenir « ]==] »")
    -- Chaque suite doit compiler séparément.
    luau.compile(source)
end

-- Remplacement littéral (pas de motif) pour ne rien interpréter dans les sources.
local function replace(text: string, marker: string, value: string): string
    local first, last = string.find(text, marker, 1, true)
    assert(first and last, "Marqueur absent du modèle : " .. marker)
    return string.sub(text, 1, first - 1) .. value .. string.sub(text, last + 1)
end

local driver = template
driver = replace(driver, "@@SERVER_SUITE@@", server)
driver = replace(driver, "@@CLIENT_SUITE@@", client)
driver = replace(driver, "@@SCENARIO_SERVER@@", scenarioServer)
driver = replace(driver, "@@SCENARIO_CLIENT@@", scenarioClient)
driver = replace(driver, "@@LOT02_SERVER@@", lot02Server)
driver = replace(driver, "@@LOT02_CLIENT@@", lot02Client)
driver = replace(driver, "@@MONDE_SERVER@@", mondeServer)
driver = replace(driver, "@@MONDE_CLIENT@@", mondeClient)
driver = replace(driver, "@@LOT04_SERVER@@", lot04Server)
driver = replace(driver, "@@LOT04_CLIENT@@", lot04Client)
driver = replace(driver, "@@SESSIONS@@", serde.encode("json", sessions))
luau.compile(driver)

fs.writeFile(output, driver)
print(string.format("Pilote généré : %s (%d session(s), %d octets)", output, #sessions, #driver))
