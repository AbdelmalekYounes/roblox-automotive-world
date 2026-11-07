--!strict
-- Lot PNJ-01 : mise au format du contrat (World/PnjKits) du gabarit des voitures PNJ importé par le propriétaire.
-- L'import glTF de Studio nomme chaque voiture « Scene » et range chaque maillage dans un modèle portant le nom de la
-- pièce : on renomme chaque voiture `PNJ_<Id>` (identifiée par le nom d'origine de sa carrosserie) et on remplace chaque
-- modèle intermédiaire par son maillage, renommé comme la pièce. Aucun script accepté ; rien n'est exécuté.
-- Piétons (facultatif) : modèles déjà nommés `PNJ_Pieton_<Id>` et `PNJ_Pietons_Palettes` (nom de scène glTF), ajoutés
-- au même dossier ; leurs identifiants de maillage et de texture sont listés à part.
-- Usage : lune run tests/lune/tools/pnj01-kits.luau <voitures.rbxm> <sortie.rbxm> [<pietons.rbxm>]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local source, target, pedestrians = process.args[1], process.args[2], process.args[3]
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

-- Piétons : modèles intermédiaires remplacés par leur maillage ; identifiants de maillage et de texture relevés.
local pedMeshes: { number } = {}
local pedTextures: { number } = {}
if pedestrians then
    local pedRoots = roblox.deserializeModel(fs.readFile(pedestrians))
    local models = {}
    for _, root in pedRoots do
        if root.ClassName == "Folder" then
            for _, child in root:GetChildren() do
                table.insert(models, child)
            end
        else
            table.insert(models, root)
        end
    end
    local count = 0
    for _, model in models do
        for _, item in model:GetDescendants() do
            assert(not item:IsA("LuaSourceContainer"), "script refusé : " .. item:GetFullName())
        end
        assert(
            string.sub(model.Name, 1, 11) == "PNJ_Pieton_" or model.Name == "PNJ_Pietons_Palettes",
            "modèle inattendu : " .. model.Name
        )
        for _, wrapper in model:GetChildren() do
            if wrapper.ClassName == "Model" then
                local parts = wrapper:GetChildren()
                assert(#parts == 1 and parts[1].ClassName == "MeshPart", "pièce inattendue : " .. wrapper.Name)
                parts[1].Name = wrapper.Name
                parts[1].Parent = model
                wrapper:Destroy()
            end
        end
        for _, part in model:GetChildren() do
            local mesh = tonumber(string.match(tostring((part :: any).MeshContent), "rbxassetid://(%d+)"))
            local texture = tonumber(string.match(tostring((part :: any).TextureContent), "rbxassetid://(%d+)"))
            assert(mesh, "maillage sans identifiant : " .. model.Name .. "." .. part.Name)
            table.insert(pedMeshes, mesh :: number)
            if texture and not table.find(pedTextures, texture :: number) then
                table.insert(pedTextures, texture :: number)
            end
        end
        model.Parent = folder
        count += 1
    end
    table.sort(pedMeshes)
    print(string.format("AW_PNJ01_PIETONS %d modèles, %d maillages, %d textures", count, #pedMeshes, #pedTextures))
end
fs.writeFile(target, roblox.serializeModel({ folder }))
print("AW_PNJ01_IDS " .. #ids)
print(table.concat(ids, ", "))
if pedestrians then
    table.sort(pedTextures)
    print("AW_PNJ01_PIETONS_MAILLAGES " .. table.concat(pedMeshes, ", "))
    print("AW_PNJ01_PIETONS_TEXTURES " .. table.concat(pedTextures, ", "))
end
