--!strict
-- Outil en lecture seule (lot BASE-01) : écrit la définition RÉSOLUE d'un véhicule, telle que le registre la calcule,
-- en JSON trié (référence d'égalité) et en source Luau (définition autonome).
-- Usage : lune run tests/lune/tools/dump-definition.luau build/AutomotiveWorld.rbxlx <id> <sortie.json> [sortie.luau]
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Harness = require("../Harness")

Harness.loadPlace(process.args[1])
local Definitions = Harness.require("ReplicatedStorage.Shared.Vehicles.VehicleDefinitions")
local id = process.args[2]
local definition = Definitions.get(id)
assert(definition, "définition inconnue : " .. tostring(id))

local function sortedKeys(t: any): { any }
    local keys = {}
    for k in t do
        table.insert(keys, k)
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)
    return keys
end

-- JSON canonique (clés triées) : comparaison exacte avant / après.
local function canon(v: any): any
    if type(v) ~= "table" then
        return v
    end
    local out = {}
    for k, child in v do
        out[k] = canon(child)
    end
    return out
end
fs.writeFile(process.args[3], serde.encode("json", canon(definition), true))

local function isArray(t: any): boolean
    local n = 0
    for _ in t do
        n += 1
    end
    return n == #t
end

local function literal(v: any, indent: string): string
    local kind = type(v)
    if kind == "number" then
        if v == math.floor(v) and math.abs(v) < 1e15 then
            return string.format("%d", v)
        end
        return string.format("%.17g", v)
    elseif kind == "string" then
        return string.format("%q", v)
    elseif kind == "boolean" then
        return tostring(v)
    elseif kind == "table" then
        local inner = indent .. "    "
        local parts = {}
        if isArray(v) then
            for _, child in ipairs(v) do
                table.insert(parts, inner .. literal(child, inner) .. ",")
            end
        else
            for _, k in sortedKeys(v) do
                table.insert(parts, inner .. tostring(k) .. " = " .. literal(v[k], inner) .. ",")
            end
        end
        if #parts == 0 then
            return "{}"
        end
        return "{\n" .. table.concat(parts, "\n") .. "\n" .. indent .. "}"
    end
    error("type non pris en charge : " .. kind)
end
if process.args[4] then
    fs.writeFile(process.args[4], "return " .. literal(definition, "") .. "\n")
end
print("ok : " .. id)
