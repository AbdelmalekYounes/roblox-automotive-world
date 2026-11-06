--!strict
-- Lot ANIM-01 : intègre au gabarit de la Comète le volant séparé, importé dans Studio et envoyé sur Roblox par le
-- propriétaire (export réduit du dépôt d'art : `wk_comete_720s_volant_anim01.glb`, 2 pièces).
-- Le gabarit actuel n'est modifié que pour ces deux pièces :
-- - `COMETE_Habitacle_interior` (sans volant) remplace l'ancienne pièce, dans le même modèle `_Node` ;
-- - `COMETE_Volant` est ajouté dans son propre modèle `COMETE_Volant_Node` ;
-- - les 27 autres pièces gardent leurs identifiants.
-- Les deux pièces sont placées au centre de boîte attendu par l'export (repère du châssis), décalé comme le reste du
-- gabarit par la pièce de référence ; la texture de l'habitacle d'origine est reprise (mêmes UV, aucune nouvelle
-- texture à inscrire au manifeste). Rien n'est exécuté du fichier importé : il est seulement désérialisé, et refusé
-- s'il contient du code.
-- Usage : lune run tests/lune/tools/anim01-volant-comete.luau <import.rbxm> <export.json> [<sortie.rbxm>]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

local TEMPLATE = "assets/meshkits/Comete720s.rbxm"
-- Pièce de référence et centre de sa boîte (MeshKitData.Kits.wk_comete) : contrôlé par le test Lune du kit.
local REFERENCE = "COMETE_Caisse_body"
local REFERENCE_CENTER = Vector3.new(0, 0.354, -1.214)
local INTERIOR = "COMETE_Habitacle_interior"
local WHEEL = "COMETE_Volant"

local importPath, exportPath = process.args[1], process.args[2]
assert(importPath and exportPath, "usage : anim01-volant-comete.luau <import.rbxm> <export.json> [<sortie.rbxm>]")
local outPath = process.args[3] or TEMPLATE

local expected = serde.decode("json", fs.readFile(exportPath)).objets
local roots = roblox.deserializeModel(fs.readFile(TEMPLATE))
assert(#roots == 1, "gabarit : un seul modèle attendu")
local template = roots[1]

local function contentUri(inst: any, prop: string): string?
    local ok, value = pcall(function()
        return inst[prop]
    end)
    local text = if ok and value ~= nil then tostring(value) else ""
    return string.match(text, "(rbxassetid://%d+)")
end

-- Pièces importées : exactement les deux attendues, aucun code.
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
local count = 0
for name in imported do
    assert(name == INTERIOR or name == WHEEL, "pièce inattendue dans l'import : " .. name)
    count += 1
end
assert(count == 2, "import : 2 MeshParts attendues (" .. INTERIOR .. ", " .. WHEEL .. "), " .. count .. " trouvées")
assert(template:FindFirstChild(WHEEL, true) == nil, "le gabarit a déjà un volant séparé")

local reference = template:FindFirstChild(REFERENCE, true)
local oldInterior = template:FindFirstChild(INTERIOR, true)
assert(reference and oldInterior, "gabarit incomplet")
local shift = reference.CFrame.Position - REFERENCE_CENTER

for name, part in imported do
    assert(
        contentUri(part, "MeshContent"),
        name .. " : maillage non envoyé sur Roblox (cocher « Importer sur Roblox »)"
    )
    local center = expected[name].centre_boite
    part.CFrame = CFrame.new(shift + Vector3.new(center[1], center[2], center[3])) * part.CFrame.Rotation
    -- Même texture que l'habitacle d'origine (UV conservés par la séparation).
    part.TextureContent = oldInterior.TextureContent
    part.Anchored = oldInterior.Anchored
end

local node = oldInterior.Parent
imported[INTERIOR].Parent = node
oldInterior.Parent = nil
local wheelNode = roblox.Instance.new("Model")
wheelNode.Name = WHEEL .. "_Node"
imported[WHEEL].Parent = wheelNode
wheelNode.Parent = template

fs.writeFile(outPath, roblox.serializeModel({ template }))
for _, name in { INTERIOR, WHEEL } do
    local part = imported[name]
    local p = part.CFrame.Position - shift
    print(
        string.format(
            "%s : maillage %s, texture %s, centre (%.3f ; %.3f ; %.3f)",
            name,
            tostring(contentUri(part, "MeshContent")),
            tostring(contentUri(part, "TextureContent")),
            p.X,
            p.Y,
            p.Z
        )
    )
end
print("Ancien maillage de l'habitacle retiré : " .. tostring(contentUri(oldInterior, "MeshContent")))
print("Gabarit écrit : " .. outPath)
