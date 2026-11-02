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
}

local output = process.args[1]
if output == nil then
    print("Usage : lune run tests/studio/build-driver.luau <sortie.luau> [solo,multijoueur,latence]")
    process.exit(2)
end

local sessions = {}
for name in string.gmatch(process.args[2] or "solo,multijoueur,latence", "[^,]+") do
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

for label, source in { serveur = server, client = client } do
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
driver = replace(driver, "@@SESSIONS@@", serde.encode("json", sessions))
luau.compile(driver)

fs.writeFile(output, driver)
print(string.format("Pilote généré : %s (%d session(s), %d octets)", output, #sessions, #driver))
