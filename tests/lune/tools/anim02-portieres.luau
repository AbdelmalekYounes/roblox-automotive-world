--!strict
-- Lot ANIM-02 : intègre au gabarit d'un véhicule les portières séparées, importées dans Studio et envoyées sur Roblox
-- par le propriétaire (exports réduits du dépôt d'art : `wk_brio_milano95_portes_anim02.glb`, 9 pièces ;
-- `wk_comete_720s_portes_anim02.glb`, 21 pièces).
-- Le gabarit n'est modifié que pour ces pièces :
-- - les pièces fixes retouchées (porte retirée) remplacent les anciennes, dans le même modèle `_Node` ;
-- - les pièces de portes sont ajoutées, chacune dans son modèle `<nom>_Node` ;
-- - Comète : les anciens rétroviseurs (`COMETE_Retroviseurs_*`), entièrement passés dans les portes, sont retirés ;
-- - toutes les autres pièces gardent leurs identifiants.
-- Chaque pièce est placée au centre de boîte attendu par l'export (repère du châssis), décalé comme le reste du gabarit
-- par la pièce de référence AVANT remplacement. Sa texture est celle de sa pièce d'origine (même atlas, UV conservés
-- par la découpe) : `TextureContent` et `SurfaceAppearance` recopiés ; aucune nouvelle texture à inscrire au manifeste.
-- Rien n'est exécuté du fichier importé : il est seulement désérialisé, et refusé s'il contient du code.
-- Usage : lune run tests/lune/tools/anim02-portieres.luau <brio|comete> <import.rbxm> <export.json> [<sortie.rbxm>]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

type Car = {
    Template: string,
    Reference: string,
    ReferenceCenter: any, -- centre de la référence AVANT ce lot (MeshKitData du gabarit d'entrée)
    Sources: { [string]: string }, -- suffixe d'une pièce de porte → pièce d'origine (texture)
    Removed: { string }, -- pièces retirées du gabarit
}

local CARS: { [string]: Car } = {
    brio = {
        Template = "assets/meshkits/Brio.rbxm",
        Reference = "BRIO_Caisse_Peinture",
        ReferenceCenter = Vector3.new(0.005, 1.201, 2.776),
        Sources = {
            Peinture = "BRIO_Caisse_Peinture",
            Habitacle = "BRIO_Habitacle",
            Soubassement = "BRIO_Soubassement",
        },
        Removed = {},
    },
    comete = {
        Template = "assets/meshkits/Comete720s.rbxm",
        Reference = "COMETE_Caisse_body",
        ReferenceCenter = Vector3.new(0, 0.354, -1.214),
        Sources = {
            body = "COMETE_Caisse_body",
            carbon_fibre = "COMETE_Caisse_carbon_fibre",
            black_metallic = "COMETE_Caisse_black_metallic",
            interior = "COMETE_Habitacle_interior",
            glass = "COMETE_Vitrage_glass",
            Retro_body = "COMETE_Retroviseurs_body",
            Retro_carbon_fibre = "COMETE_Retroviseurs_carbon_fibre",
            Retro_mirror = "COMETE_Retroviseurs_mirror",
        },
        Removed = { "COMETE_Retroviseurs_body", "COMETE_Retroviseurs_carbon_fibre", "COMETE_Retroviseurs_mirror" },
    },
}

local carName, importPath, exportPath = process.args[1], process.args[2], process.args[3]
local car = CARS[carName or ""]
assert(car and importPath and exportPath, "usage : anim02-portieres.luau <brio|comete> <import.rbxm> <export.json>")
local outPath = process.args[4] or car.Template

local expected = serde.decode("json", fs.readFile(exportPath)).objets
local roots = roblox.deserializeModel(fs.readFile(car.Template))
assert(#roots == 1, "gabarit : un seul modèle attendu")
local template = roots[1]

local function contentUri(inst: any, prop: string): string?
    local ok, value = pcall(function()
        return inst[prop]
    end)
    local text = if ok and value ~= nil then tostring(value) else ""
    return string.match(text, "(rbxassetid://%d+)")
end

-- Pièces importées : exactement celles de l'export, aucun code.
local imported: { [string]: any } = {}
for _, root in roblox.deserializeModel(fs.readFile(importPath)) do
    for _, item in root:GetDescendants() do
        assert(not item:IsA("LuaSourceContainer"), "code refusé dans l'import : " .. item:GetFullName())
        if item.ClassName == "MeshPart" then
            assert(imported[item.Name] == nil, "pièce en double : " .. item.Name)
            imported[item.Name] = item
        end
    end
end
local wanted, count = 0, 0
for name in expected do
    wanted += 1
    assert(imported[name], "pièce manquante dans l'import : " .. name)
end
for name in imported do
    assert(expected[name], "pièce inattendue dans l'import : " .. name)
    count += 1
end
assert(count == wanted, string.format("import : %d MeshParts attendues, %d trouvées", wanted, count))

local function find(name: string): any
    for _, item in template:GetDescendants() do
        if item.ClassName == "MeshPart" and item.Name == name then
            return item
        end
    end
    return nil
end

local reference = find(car.Reference)
assert(reference, "gabarit incomplet : " .. car.Reference)
-- Décalage du gabarit, mesuré sur la référence d'AVANT remplacement.
local shift = reference.CFrame.Position - car.ReferenceCenter

-- Pièce d'origine d'une pièce importée : elle-même (pièce fixe retouchée) ou la source de la porte.
local function sourceOf(name: string): any
    local suffix = string.match(name, "_Porte[GD]_(.+)$")
    local origin = if suffix then car.Sources[suffix] else name
    assert(origin, "source inconnue pour " .. name)
    local part = find(origin)
    assert(part, "pièce d'origine absente du gabarit : " .. origin)
    return part
end

local removedMeshes: { string } = {}
local report: { string } = {}
local originals: { [string]: any } = {}
for name in imported do
    originals[name] = sourceOf(name)
end
for name, part in imported do
    assert(
        contentUri(part, "MeshContent"),
        name .. " : maillage non envoyé sur Roblox (cocher « Importer sur Roblox »)"
    )
    local origin = originals[name]
    local center = expected[name].centre_boite
    part.CFrame = CFrame.new(shift + Vector3.new(center[1], center[2], center[3])) * part.CFrame.Rotation
    part.Anchored = origin.Anchored
    -- Texture de la pièce d'origine (même atlas, mêmes UV).
    part.TextureContent = origin.TextureContent
    for _, child in part:GetChildren() do
        if child.ClassName == "SurfaceAppearance" then
            child.Parent = nil
        end
    end
    for _, child in origin:GetChildren() do
        if child.ClassName == "SurfaceAppearance" then
            child:Clone().Parent = part
        end
    end
    local existing = find(name)
    if existing then
        -- Pièce fixe retouchée : remplace l'ancienne dans son modèle.
        table.insert(removedMeshes, tostring(contentUri(existing, "MeshContent")))
        part.Parent = existing.Parent
        existing.Parent = nil
    else
        local node = roblox.Instance.new("Model")
        node.Name = name .. "_Node"
        part.Parent = node
        node.Parent = template
    end
    local p = part.CFrame.Position - shift
    table.insert(
        report,
        string.format(
            "%s : maillage %s, texture %s%s, centre (%.3f ; %.3f ; %.3f)",
            name,
            tostring(contentUri(part, "MeshContent")),
            tostring(contentUri(part, "TextureContent")),
            if part:FindFirstChildOfClass("SurfaceAppearance") then " + SurfaceAppearance" else "",
            p.X,
            p.Y,
            p.Z
        )
    )
end
for _, name in car.Removed do
    local old = find(name)
    if old then
        table.insert(removedMeshes, tostring(contentUri(old, "MeshContent")))
        local node = old.Parent
        old.Parent = nil
        if node and node.ClassName == "Model" and #node:GetChildren() == 0 then
            node.Parent = nil
        end
    end
end

fs.writeFile(outPath, roblox.serializeModel({ template }))
table.sort(report)
for _, line in report do
    print(line)
end
local total = 0
for _, item in template:GetDescendants() do
    if item.ClassName == "MeshPart" then
        total += 1
    end
end
print("Maillages retirés : " .. table.concat(removedMeshes, ", "))
print(string.format("Gabarit écrit : %s (%d maillages)", outPath, total))
