--!strict
-- Lot PNJ-01 : mise au format du contrat (World/PnjKits) du gabarit des voitures PNJ importé par le propriétaire.
-- L'import glTF de Studio nomme chaque voiture « Scene » et range chaque maillage dans un modèle portant le nom de la
-- pièce : on renomme chaque voiture `PNJ_<Id>` (identifiée par le nom d'origine de sa carrosserie) et on remplace chaque
-- modèle intermédiaire par son maillage, renommé comme la pièce. Aucun script accepté ; rien n'est exécuté.
-- Usage : lune run tests/lune/tools/pnj01-kits.luau <import.rbxm> <sortie.rbxm>
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local source, target = process.args[1], process.args[2]
assert(source and target, "usage : pnj01-kits.luau <import.rbxm> <sortie.rbxm>")
local roots = roblox.deserializeModel(fs.readFile(source))
assert(#roots == 1 and roots[1].ClassName == "Folder", "attendu : un seul dossier racine")
local folder = roots[1]
folder.Name = "AutomotiveWorldPnjKits"

-- Nom de la carrosserie dans le pack → identifiant du jeu (tools/blender/pnj01_voitures.py du dépôt d'art).
local PACK = {
    ["Compact"] = "Compacte",
    ["Hatchback"] = "Hayon",
    ["Sedan"] = "Berline",
    ["Wagon"] = "Break",
    ["SUV"] = "SUV",
    ["minivan"] = "Monospace",
    ["Pickup"] = "PickUp",
    ["Offroad"] = "ToutTerrain",
    ["Coupe"] = "Coupe",
    ["Sport"] = "Sportive",
}

local ids: { number } = {}
local seen: { [string]: boolean } = {}
for _, car in folder:GetChildren() do
    for _, item in car:GetDescendants() do
        assert(not item:IsA("LuaSourceContainer"), "script refusé : " .. item:GetFullName())
    end
    -- Identification par la carrosserie peinte.
    local paint = car:FindFirstChild("Peinture_Caisse")
    assert(paint, "Peinture_Caisse absente de " .. car.Name)
    local mesh = paint:FindFirstChildWhichIsA("MeshPart") or paint
    local id: string? = nil
    for key, value in PACK do
        if string.sub(string.lower(mesh.Name), 1, #key + 1) == string.lower(key) .. " " then
            id = value
        end
    end
    assert(id, "voiture non identifiée : " .. mesh.Name)
    assert(not seen[id :: string], "voiture en double : " .. (id :: string))
    seen[id :: string] = true
    car.Name = "PNJ_" .. (id :: string)
    -- Modèles intermédiaires → maillage seul, au nom de la pièce.
    for _, wrapper in car:GetChildren() do
        if wrapper.ClassName == "Model" then
            local parts = wrapper:GetChildren()
            assert(#parts == 1 and parts[1].ClassName == "MeshPart", "pièce inattendue : " .. wrapper.Name)
            local part = parts[1]
            part.Name = wrapper.Name
            part.Parent = car
            wrapper:Destroy()
        end
    end
    for _, part in car:GetChildren() do
        local content = tostring((part :: any).MeshContent)
        local number = tonumber(string.match(content, "rbxassetid://(%d+)"))
        assert(number, "maillage sans identifiant : " .. part.Name)
        table.insert(ids, number :: number)
    end
    print(string.format("AW_PNJ01_KIT %s : %d pièces", car.Name, #car:GetChildren()))
end
table.sort(ids)
fs.writeFile(target, roblox.serializeModel({ folder }))
print("AW_PNJ01_IDS " .. #ids)
print(table.concat(ids, ", "))
