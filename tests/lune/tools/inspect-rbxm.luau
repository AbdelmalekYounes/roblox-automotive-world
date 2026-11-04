--!strict
-- Inspection (lecture seule) d'un modèle .rbxm fourni par le propriétaire : arborescence, classes, identifiants
-- d'actifs (MeshId, TextureID, SurfaceAppearance), tailles, positions, attributs, et présence de SCRIPTS (refusés :
-- un modèle importé ne doit contenir aucun code). Rien n'est exécuté : le fichier est seulement désérialisé.
-- Usage : lune run tests/lune/tools/inspect-rbxm.luau <modèle.rbxm> [<sortie.json>]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local path = process.args[1]
assert(path, "usage : inspect-rbxm.luau <modèle.rbxm> [<sortie.json>]")
local roots = roblox.deserializeModel(fs.readFile(path))

local function round(v: number): number
    return math.floor(v * 1000 + 0.5) / 1000
end

-- Lecture tolérante : selon la version de Studio, certaines propriétés (MeshId, TextureID…) ne sont pas
-- sérialisées, ou le sont sous un autre nom (MeshContent, TextureContent).
local function get(inst: any, prop: string): any
    local ok, value = pcall(function()
        return inst[prop]
    end)
    if not ok or value == nil then
        return nil
    end
    return tostring(value)
end

local rows = {}
local scripts = {}
local classes: { [string]: number } = {}
local function visit(inst: any, depth: number, parentPath: string)
    local fullPath = if parentPath == "" then inst.Name else parentPath .. "/" .. inst.Name
    classes[inst.ClassName] = (classes[inst.ClassName] or 0) + 1
    local row: any = { Path = fullPath, Class = inst.ClassName }
    if inst:IsA("LuaSourceContainer") then
        table.insert(scripts, fullPath)
    end
    if inst:IsA("BasePart") then
        row.Size = { round(inst.Size.X), round(inst.Size.Y), round(inst.Size.Z) }
        local p = inst.CFrame.Position
        row.Position = { round(p.X), round(p.Y), round(p.Z) }
        row.Transparency = inst.Transparency
        row.Material = tostring(inst.Material)
    end
    if inst.ClassName == "MeshPart" then
        for _, prop in { "MeshId", "MeshContent", "TextureID", "TextureContent", "RenderFidelity", "DoubleSided" } do
            row[prop] = get(inst, prop)
        end
    end
    if inst.ClassName == "SurfaceAppearance" then
        for _, prop in
            {
                "ColorMap",
                "NormalMap",
                "MetalnessMap",
                "RoughnessMap",
                "ColorMapContent",
                "NormalMapContent",
                "MetalnessMapContent",
                "RoughnessMapContent",
                "AlphaMode",
            }
        do
            row[prop] = get(inst, prop)
        end
    end
    local attrs = inst:GetAttributes()
    if next(attrs) then
        row.Attributes = attrs
    end
    table.insert(rows, row)
    for _, child in inst:GetChildren() do
        visit(child, depth + 1, fullPath)
    end
end
for _, r in roots do
    visit(r, 0, "")
end
local report = { Fichier = path, Racines = #roots, Classes = classes, Scripts = scripts, Instances = rows }
if process.args[2] then
    fs.writeFile(process.args[2], serde.encode("json", report, true))
end
print("AW_RBXM", #rows, "instances", #scripts, "scripts")
for class, n in classes do
    print("AW_RBXM_CLASSE", class, n)
end
for _, s in scripts do
    print("AW_RBXM_SCRIPT", s)
end
