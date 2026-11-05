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
    -- Lot 0.9 : économie et marché (2 joueurs), courses (2 joueurs), arrivée et gamme (1 joueur).
    lot05 = { Name = "lot05", Players = 2 },
    lot06 = { Name = "lot06", Players = 2 },
    lot08 = { Name = "lot08", Players = 1 },
    -- Lot 0.9 : mesures de référence (place MONDE OUVERT, -Place OpenWorld).
    perf = { Name = "perf", Players = 1 },
    -- Lot 0.9.1 : interfaces par vraies entrées dans la VM (pont d'entrées, voir
    -- tools/vm/ScreenCapture.cs) ; « ui_monde » sur la place MONDE OUVERT.
    ui = { Name = "ui", Players = 1 },
    ui_monde = { Name = "ui_monde", Players = 1 },
    ui_marche = { Name = "ui_marche", Players = 1 },
    -- Lot 0.9.1 : huit métiers par un pilote (Dev), trajets GPS (MONDE OUVERT), drift (Dev).
    metiers = { Name = "metiers", Players = 1 },
    gps = { Name = "gps", Players = 1 },
    gps2 = { Name = "gps2", Players = 1 },
    drift = { Name = "drift", Players = 1 },
    -- Lot 0.9.1 : social et permissions, deux clients (Dev).
    social = { Name = "social", Players = 2 },
    -- Lot AVATAR-01 : avatars R15 dans les véhicules (vraies entrées), vue par un autre joueur.
    avatar = { Name = "avatar", Players = 1 },
    avatar2 = { Name = "avatar2", Players = 2 },
    -- Phase 1 de l'Aster : maquette en blocs d'après le gabarit, pose assise du jeu.
    aster = { Name = "aster", Players = 1 },
    -- Clôture de la phase 1 : choix de silhouette par vrais clics, puis réplication à 2 joueurs.
    silhouette = { Name = "silhouette", Players = 1 },
    silhouette2 = { Name = "silhouette2", Players = 2 },
    -- Lot VEH3D-01 : Comète 3D (kit de maillages), essais QA-K01 à QA-K08 (vraies entrées).
    comete = { Name = "comete", Players = 1 },
    comete_vitres = { Name = "comete_vitres", Players = 1 },
    comete_perf = { Name = "comete_perf", Players = 1 },
    comete2 = { Name = "comete2", Players = 2 },
    comete_avatar = { Name = "comete_avatar", Players = 1 },
    -- Lot UI-01 : système de conception V1.2 (page de démonstration, vrais clics).
    ui_design = { Name = "ui_design", Players = 1 },
    -- Lot UI-02 : téléphone V1.2 seul (vraies touches et vrais clics).
    ui_phone = { Name = "ui_phone", Players = 1 },
    -- Lots UI-03 et UI-04 : garage seul ; panneaux économie et courses seuls.
    ui_garage = { Name = "ui_garage", Players = 1 },
    ui_panels = { Name = "ui_panels", Players = 1 },
    -- Lot UI-03 : aperçu 3D du garage (ViewportFrame) seul.
    ui_garage3d = { Name = "ui_garage3d", Players = 1 },
}

-- Suites supplémentaires (lot 0.9) : { nom de script, fichier, client ? }.
local EXTRA = {
    { "AW_TestLot05Server", "Lot05Server.server.luau", false },
    { "AW_TestLot05Client", "Lot05Client.client.luau", true },
    { "AW_TestLot06Server", "Lot06Server.server.luau", false },
    { "AW_TestLot06Client", "Lot06Client.client.luau", true },
    { "AW_TestLot08Server", "Lot08Server.server.luau", false },
    { "AW_TestLot08Client", "Lot08Client.client.luau", true },
    { "AW_TestPerfServer", "PerfServer.server.luau", false },
    { "AW_TestPerfClient", "PerfClient.client.luau", true },
    -- Lot 0.9.1 : pilote d'interface par vraies entrées (module partagé) et campagnes.
    { "AW_TestGui", "GuiDriver.luau", "module" },
    { "AW_TestUiServer", "UiServer.server.luau", false },
    { "AW_TestUiClient", "UiClient.client.luau", true },
    { "AW_TestMetiersClient", "MetiersClient.client.luau", true },
    { "AW_TestGpsClient", "GpsClient.client.luau", true },
    { "AW_TestDriftClient", "DriftClient.client.luau", true },
    { "AW_TestSocialServer", "SocialServer.server.luau", false },
    { "AW_TestSocialClient", "SocialClient.client.luau", true },
    { "AW_TestUiMondeClient", "UiMondeClient.client.luau", true },
    { "AW_TestAsterTemplate", "AsterTemplate.luau", "module" },
    { "AW_TestAvatarServer", "AvatarServer.server.luau", false },
    { "AW_TestAvatarClient", "AvatarClient.client.luau", true },
    { "AW_TestCometeServer", "CometeServer.server.luau", false },
    { "AW_TestCometeClient", "CometeClient.client.luau", true },
    { "AW_TestUiDesignServer", "UiDesignServer.server.luau", false },
    { "AW_TestUiDesignClient", "UiDesignClient.client.luau", true },
    { "AW_TestUiPhoneClient", "UiPhoneClient.client.luau", true },
    { "AW_TestUiScreensClient", "UiScreensClient.client.luau", true },
    { "AW_TestUiGarage3DClient", "UiGarage3DClient.client.luau", true },
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
local extras = {}
for _, entry in EXTRA do
    local path = base .. entry[2]
    if fs.isFile(path) then
        local source = fs.readFile(path)
        assert(not string.find(source, "]==]", 1, true), "La suite " .. entry[2] .. " ne doit pas contenir « ]==] »")
        luau.compile(source)
        table.insert(
            extras,
            string.format(
                "table.insert(EXTRA_SUITES, { %q, [==[%s]==], %s })",
                entry[1],
                source,
                if entry[3] == "module" then '"module"' elseif entry[3] then "true" else "false"
            )
        )
    end
end
driver = replace(driver, "-- @@EXTRA_SUITES@@", table.concat(extras, "\n"))
luau.compile(driver)

fs.writeFile(output, driver)
print(string.format("Pilote généré : %s (%d session(s), %d octets)", output, #sessions, #driver))
