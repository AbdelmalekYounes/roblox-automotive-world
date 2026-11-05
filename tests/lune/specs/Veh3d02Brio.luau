--!strict
-- Lot VEH3D-02 : la Brio (citadine). Contrôles hors Studio sur la place construite : définition autonome figée,
-- rôles décidés par le propriétaire (2026-11-05), données mesurées du kit de maillages, manifeste et crédits.
-- Le gabarit Studio (assets/meshkits/Brio.rbxm) n'existe pas encore : il est importé par le propriétaire ; tant qu'il
-- manque, la fabrique garde la carrosserie de repli. Le comportement en jeu est vérifié par le propriétaire.
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local REFERENCE = "tests/lune/fixtures/brio_definition_reference.json"

-- Comparaison profonde (même règle que Base01 : tolérance relative 1e-12 du lecteur JSON de Lune).
local function diff(a: any, b: any, path: string): string?
    if type(a) ~= type(b) then
        return path .. " : type " .. type(a) .. " ≠ " .. type(b)
    end
    if type(a) == "number" then
        if math.abs(a - b) > 1e-12 * math.max(1, math.abs(b)) then
            return path .. " : " .. tostring(a) .. " ≠ " .. tostring(b)
        end
        return nil
    end
    if type(a) ~= "table" then
        return if a ~= b then path .. " : " .. tostring(a) .. " ≠ " .. tostring(b) else nil
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

local function inside(p: Vector3, box: { Center: Vector3, Size: Vector3 }): boolean
    local d = p - box.Center
    return math.abs(d.X) <= box.Size.X / 2 and math.abs(d.Y) <= box.Size.Y / 2 and math.abs(d.Z) <= box.Size.Z / 2
end

return function(T: any, H: any)
    local SHARED = "ReplicatedStorage.Shared."
    local Definitions = H.require(SHARED .. "Vehicles.VehicleDefinitions")
    local Data = H.require(SHARED .. "Vehicles.MeshKitData")
    local AssetManifest = H.require(SHARED .. "Assets.AssetManifest")
    local Attributions = H.require(SHARED .. "Assets.Attributions")
    local VehicleCatalog = H.require(SHARED .. "Economy.VehicleCatalog")
    local Jobs = H.require(SHARED .. "Economy.Jobs")
    local StarterCatalog = H.require(SHARED .. "Garage.StarterCatalog")
    local Localization = H.require(SHARED .. "UI.Localization")

    T.suite("VEH3D-02 — Brio (citadine)")

    T.test("1. définition autonome identique à la référence figée ; essence, automatique, traction", function()
        local definition = Definitions.get("wk_brio")
        T.truthy(definition ~= nil, "Brio enregistrée")
        local found = diff(definition, serde.decode("json", fs.readFile(REFERENCE)), "wk_brio")
        T.truthy(found == nil, found or "identique")
        T.equal(definition.Powertrain.Energy.Kind, "Petrol")
        T.equal(definition.Powertrain.Transmission.Kind, "Automatic")
        T.equal(definition.Powertrain.Drivetrain.Layout, "FWD")
        T.equal(definition.IsTestPrototype, false)
    end)

    T.test("2. rôles : service des métiers, achetable en concession, pas véhicule de départ", function()
        local entry = VehicleCatalog.forDefinition("wk_brio")
        T.truthy(entry ~= nil, "entrée du catalogue")
        T.equal(entry.Slot, 2)
        T.truthy(entry.Availability ~= "Reserved" and #entry.Dealers > 0, "achetable en concession")
        T.truthy(table.find(StarterCatalog.Candidates, "wk_brio") == nil, "pas véhicule de départ")
        for _, id in { "Taxi", "Delivery", "Convoy", "Testing" } do
            T.equal((Jobs.get(id) :: any).ProfessionalModel, "wk_brio", id .. " : véhicule de service")
        end
        for _, suffix in { ".category", ".desc" } do
            local key = "vehicle.wk_brio" .. suffix
            T.truthy(Localization.has(key), key .. " FR/EN")
        end
    end)

    T.test("3. kit mesuré : places dans la caisse, caméras devant, marques sur la surface", function()
        local kit = Data.Kits.wk_brio
        T.truthy(kit ~= nil, "kit de la Brio")
        T.equal(kit.Template, "Brio")
        T.truthy(
            inside(kit.SeatDriver, kit.Collisions.Habitacle) or kit.SeatDriver.Y > kit.Collisions.Coque.Center.Y,
            "assise au-dessus de la coque"
        )
        T.truthy(kit.RoofUnderside > kit.SeatDriver.Y + 2, "hauteur sous pavillon")
        T.truthy(kit.CameraCockpit.Y < kit.RoofUnderside, "yeux sous le pavillon")
        T.truthy(kit.CameraBumper.Z < kit.DamageMarks.Front[2], "caméra bouclier devant le nez")
        for _, z in kit.DamageMarks.Front do
            T.truthy(z < kit.Collisions.BouclierAvant.Center.Z, "marque avant devant la boîte avant")
        end
        for _, z in kit.DamageMarks.Rear do
            T.truthy(z > kit.Collisions.BouclierArriere.Center.Z, "marque arrière derrière la boîte arrière")
        end
        for _, x in kit.DamageMarks.Side do
            T.truthy(
                x > kit.Collisions.Coque.Size.X / 2 - 0.5 and x <= kit.SideHalf,
                "flanc entre coque et demi-largeur"
            )
        end
        for wheel, parts in kit.Wheels do
            T.equal(#parts, 1, wheel .. " : une pièce (pneu et jante)")
        end
        T.truthy(kit.Paint.Plain == true, "peinture unie teintable")
    end)

    T.test("4. manifeste et crédits : aucun identifiant inventé, attribution CC BY", function()
        local entry = AssetManifest.get("veh.wk_brio.meshmilano95")
        T.truthy(entry ~= nil, "entrée du manifeste")
        T.equal(entry.Status, "Provisional", "en attente de l'import du propriétaire")
        T.equal(#(entry.RobloxAssetIds or {}), 0, "identifiants vides tant que le gabarit n'est pas importé")
        T.equal(#AssetManifest.validate(), 0, "manifeste cohérent")
        local credit = Attributions.forManifest("veh.wk_brio.meshmilano95")
        T.truthy(credit ~= nil and credit.Creator == "Daniel Zhabotinsky", "auteur crédité")
    end)
end
