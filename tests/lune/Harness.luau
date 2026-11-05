--!strict
-- Chargeur de modules pour les tests Lune.
--
-- Les modules sont lus DANS LA PLACE CONSTRUITE PAR ROJO (.rbxlx) : on teste
-- donc l'artefact réel, avec la vraie arborescence (`script.Parent.X`).
-- Seuls les modules PURS (sans services Roblox) peuvent être exécutés ici ;
-- les scripts dépendant du moteur (physique, réseau, interface) exigent Studio.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Harness = {}

local cache: { [any]: any } = {}
local game: any = nil

function Harness.loadPlace(path: string): any
    game = roblox.deserializePlace(fs.readFile(path))
    return game
end

function Harness.game(): any
    assert(game, "Place non chargée : appeler Harness.loadPlace")
    return game
end

local function requireModule(moduleScript: any): any
    if cache[moduleScript] ~= nil then
        return cache[moduleScript]
    end
    assert(moduleScript.ClassName == "ModuleScript", "require attend un ModuleScript")
    local chunk = luau.load(moduleScript.Source, {
        debugName = moduleScript:GetFullName(),
        environment = {
            script = moduleScript,
            require = requireModule,
            -- `game` n'est volontairement PAS exposé : un module pur ne doit
            -- pas dépendre des services Roblox.
        },
    })
    local result = chunk()
    cache[moduleScript] = result
    return result
end

-- Charge un module à partir d'un chemin du DataModel, ex. "ReplicatedStorage.Shared.Vehicles.InputCodec".
function Harness.require(path: string): any
    local node = Harness.game()
    for segment in string.gmatch(path, "[^%.]+") do
        local child = node:FindFirstChild(segment)
        assert(child, "Introuvable dans la place : " .. path .. " (segment " .. segment .. ")")
        node = child
    end
    return requireModule(node)
end

return Harness
