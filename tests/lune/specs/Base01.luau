--!strict
-- Lot BASE-01 (décision du propriétaire du 2026-11-05) : la Comète devient une définition AUTONOME, aux valeurs
-- IDENTIQUES à celles que calculait WorkingCatalog sur `main` (6a2dc34) ; référence figée dans
-- tests/lune/fixtures/comete_definition_reference.json par tests/lune/tools/dump-definition.luau.
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local REFERENCE = "tests/lune/fixtures/comete_definition_reference.json"

-- Comparaison profonde ; renvoie le premier chemin divergent (ou nil).
local function diff(a: any, b: any, path: string): string?
    if type(a) ~= type(b) then
        return path .. " : type " .. type(a) .. " ≠ " .. type(b)
    end
    if type(a) == "number" then
        -- Le lecteur JSON de Lune n'est pas exact au dernier chiffre (1855.9999999999998 relu 1856, alors que le
        -- fichier porte la valeur exacte) : tolérance relative de 1e-12, très en dessous de toute grandeur physique.
        if math.abs(a - b) > 1e-12 * math.max(1, math.abs(b)) then
            return path .. " : " .. tostring(a) .. " ≠ " .. tostring(b)
        end
        return nil
    end
    if type(a) ~= "table" then
        if a ~= b then
            return path .. " : " .. tostring(a) .. " ≠ " .. tostring(b)
        end
        return nil
    end
    for key, value in a do
        local found = diff(value, b[key], path .. "." .. tostring(key))
        if found then
            return found
        end
    end
    for key in b do
        if a[key] == nil then
            return path .. "." .. tostring(key) .. " : absent"
        end
    end
    return nil
end

return function(T: any, H: any)
    local Definitions = H.require("ReplicatedStorage.Shared.Vehicles.VehicleDefinitions")

    T.suite("Lot BASE-01 — base propre à deux véhicules")

    T.test("Comète autonome : valeurs identiques à la référence calculée sur main", function()
        local reference = serde.decode("json", fs.readFile(REFERENCE))
        local definition = Definitions.get("wk_comete")
        T.truthy(definition ~= nil, "Comète enregistrée")
        local found = diff(definition, reference, "wk_comete")
        T.truthy(found == nil, found or "identique")
    end)

    T.test("jeu sans prototype ni modèle retiré ; jeux d'essai hors du jeu", function()
        local root = H.game()
        local definitions = root.ReplicatedStorage.Shared.Vehicles.Definitions
        local names = {}
        for _, child in definitions:GetChildren() do
            table.insert(names, child.Name)
        end
        table.sort(names)
        T.equal(table.concat(names, ","), "Comete", "dossier des définitions du jeu")
        T.truthy(
            root.ServerScriptService.AutomotiveWorldServer.Vehicles:FindFirstChild("BodyKits") == nil,
            "BodyKits supprimé"
        )
    end)
end
