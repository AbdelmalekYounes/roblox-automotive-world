--!strict
-- Vérifie la place construite par Rojo : arborescence, classes de scripts,
-- séparation client/serveur/partagé et absence d'API sensibles prématurées.

-- Lot 0.4 : seul l'adaptateur DataStore (persistance, AUD-ENV-01) peut
-- utiliser le DataStore ; il n'est instancié qu'en environnement Test/Prod.
local DATASTORE_ADAPTER = "ServerScriptService.AutomotiveWorldServer.Persistence.DataStoreProfileRepository"
local ADAPTER_ALLOWED = { DataStore = true, ["requête HTTP / stockage"] = true }
-- Lot 0.5 : les crédits existent, mais seulement dans l'économie serveur.
local ECONOMY_PREFIX = "ServerScriptService.AutomotiveWorldServer.Economy."
-- Lot 0.6 : récompenses de course (serveur) ; coordination inter-serveurs
-- (MemoryStore, serveur réservé, téléportation) et tableaux de classement
-- (OrderedDataStore) isolés dans UN adaptateur, instancié seulement si une
-- expérience de test isolée ou de production est déclarée (aucune ne l'est).
local RACING_PREFIX = "ServerScriptService.AutomotiveWorldServer.Racing."
local CROSS_SERVER_ADAPTER = "ServerScriptService.AutomotiveWorldServer.Racing.CrossServerAdapter"
local CROSS_SERVER_ALLOWED = {
    DataStore = true,
    MemoryStore = true,
    ["téléportation inter-serveurs"] = true,
    ["requête HTTP / stockage"] = true,
    ["crédits"] = true,
}

local FORBIDDEN_PATTERNS = {
    { Pattern = "DataStoreService", Label = "DataStore" },
    { Pattern = "GetDataStore", Label = "DataStore" },
    { Pattern = "GetOrderedDataStore", Label = "DataStore" },
    { Pattern = "MemoryStoreService", Label = "MemoryStore" },
    { Pattern = "MarketplaceService", Label = "achats Robux" },
    { Pattern = "ProcessReceipt", Label = "achats Robux" },
    { Pattern = "InsertService", Label = "insertion d'actifs externes" },
    { Pattern = "loadstring", Label = "exécution dynamique" },
    { Pattern = "require%(%s*%d", Label = "module externe par identifiant" },
    { Pattern = "GetAsync", Label = "requête HTTP / stockage" },
    { Pattern = "PostAsync", Label = "requête HTTP" },
    { Pattern = "RequestAsync", Label = "requête HTTP" },
    { Pattern = "TeleportService", Label = "téléportation inter-serveurs" },
    { Pattern = "[Cc]redits?%s*[%+%-]?=", Label = "crédits" },
}

return function(T: any, H: any)
    local game = H.game()

    T.suite("Place construite (rbxlx)")

    local function find(path: string): any
        local node = game
        for segment in string.gmatch(path, "[^%.]+") do
            node = node and node:FindFirstChild(segment)
        end
        return node
    end

    local expected = {
        { "ServerScriptService.AutomotiveWorldServer.Bootstrap", "Script" },
        { "ServerScriptService.AutomotiveWorldServer.Vehicles.VehicleService", "ModuleScript" },
        { "ServerScriptService.AutomotiveWorldServer.Vehicles.VehicleFactory", "ModuleScript" },
        { "ServerScriptService.AutomotiveWorldServer.World.TestZoneBuilder", "ModuleScript" },
        { "ServerScriptService.AutomotiveWorldServer.Security.MovementRules", "ModuleScript" },
        { "ServerScriptService.AutomotiveWorldServer.Security.RateLimiter", "ModuleScript" },
        { "ReplicatedStorage.Shared.ProjectSettings", "ModuleScript" },
        { "ReplicatedStorage.Shared.Vehicles.VehicleSimulator", "ModuleScript" },
        { "ReplicatedStorage.Shared.Vehicles.Physics.VehicleDynamics", "ModuleScript" },
        { "ReplicatedStorage.Shared.Vehicles.Definitions.Comete", "ModuleScript" },
        { "StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.Bootstrap", "LocalScript" },
        { "StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.Vehicles.VehicleController", "ModuleScript" },
        { "StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.UI.DevHud", "ModuleScript" },
    }
    T.test("arborescence et classes attendues", function()
        for _, entry in expected do
            local node = find(entry[1])
            T.truthy(node, "absent : " .. entry[1])
            T.equal(node.ClassName, entry[2], entry[1])
        end
    end)

    T.test("aucun Script/LocalScript exécutable dans l'espace partagé", function()
        for _, descendant in game:GetService("ReplicatedStorage"):GetDescendants() do
            T.truthy(
                descendant.ClassName ~= "Script" and descendant.ClassName ~= "LocalScript",
                "script exécutable dans ReplicatedStorage : " .. descendant:GetFullName()
            )
        end
    end)

    T.test("le code serveur n'est pas répliqué vers les clients", function()
        T.equal(game:GetService("ReplicatedStorage"):FindFirstChild("AutomotiveWorldServer"), nil)
        T.equal(find("ReplicatedStorage.Shared.Vehicles.MovementRules"), nil)
    end)

    T.test(
        "aucune API sensible prématurée (achats, HTTP, crédits… ; DataStore réservé à son adaptateur)",
        function()
            local scanned = 0
            for _, descendant in game:GetDescendants() do
                local class = descendant.ClassName
                if class == "Script" or class == "LocalScript" or class == "ModuleScript" then
                    scanned += 1
                    local source = descendant.Source
                    local fullName = descendant:GetFullName()
                    local allowed: { [string]: boolean } = if fullName == DATASTORE_ADAPTER then ADAPTER_ALLOWED else {}
                    if string.sub(fullName, 1, #ECONOMY_PREFIX) == ECONOMY_PREFIX then
                        allowed = { ["crédits"] = true }
                    elseif fullName == CROSS_SERVER_ADAPTER then
                        allowed = CROSS_SERVER_ALLOWED
                    elseif string.sub(fullName, 1, #RACING_PREFIX) == RACING_PREFIX then
                        allowed = { ["crédits"] = true }
                    end
                    for _, rule in FORBIDDEN_PATTERNS do
                        if allowed[rule.Label] then
                            continue
                        end
                        T.truthy(
                            string.find(source, rule.Pattern) == nil,
                            string.format("%s : motif interdit (%s)", descendant:GetFullName(), rule.Label)
                        )
                    end
                    T.truthy(
                        string.find(source, "%-%-") ~= nil,
                        "commentaires manquants : " .. descendant:GetFullName()
                    )
                end
            end
            T.truthy(scanned >= 20, "nombre de scripts analysés : " .. scanned)
        end
    )
end
