--!strict
-- Lot VEH3D-02 : la Brio (citadine). Contrôles hors Studio sur la place construite : définition autonome figée,
-- rôles décidés par le propriétaire (2026-11-05), données mesurées du kit de maillages, manifeste et crédits.
-- Gabarit Studio importé et envoyé sur Roblox par le propriétaire (assets/meshkits/Brio.rbxm, 2026-11-05). Le
-- comportement en jeu est vérifié par le propriétaire.
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
        -- Lot BRIO-02 : places descendues sur le vrai coussin (dans la boîte de la coque, sous la ceinture de caisse).
        for _, seat in { kit.SeatDriver, kit.SeatPassenger } do
            T.truthy(
                inside(seat, kit.Collisions.Coque) or inside(seat, kit.Collisions.Habitacle),
                "place dans la caisse"
            )
        end
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

    -- Centres attendus (repère du châssis), relevés par l'export du dépôt d'art (`wk_brio_milano95_lod0.json`,
    -- 2026-11-05) ; le gabarit importé doit les reproduire, au décalage de la pièce de référence près.
    local EXPORT: { [string]: { number } } = {
        BRIO_BouclierArriereInterieur = { 0.005, -0.288, 6.795 },
        BRIO_BouclierArriere_Peinture = { 0.005, -0.286, 6.794 },
        BRIO_BouclierAvantInterieur = { 0.005, -0.321, -4.89 },
        BRIO_BouclierAvant_Peinture = { 0.005, -0.321, -4.908 },
        -- Lot ANIM-02 : portes retirées de la caisse et du soubassement (export `..._portes_anim02.json`).
        BRIO_Caisse_Peinture = { 0.006, 1.364, 2.813 },
        BRIO_Capot_Peinture = { 0.012, 0.979, -4.15 },
        BRIO_Clignotants = { 0.006, 1.071, 0.758 },
        BRIO_Feu_Ar = { 0.016, 2.37, 6.018 },
        BRIO_Feu_Av = { 0.006, 0.469, -5.435 },
        BRIO_Garniture = { -0.65, -0.901, 2.084 },
        BRIO_Habitacle = { 0.014, 1.132, 2.288 },
        BRIO_Kit_Peinture = { 0.007, 0.877, 0.944 },
        BRIO_Recul = { 0.015, 1.915, 6.267 },
        BRIO_Roue_ArD = { 2.514, -0.801, 5.359 },
        BRIO_Roue_ArG = { -2.514, -0.771, 5.359 },
        BRIO_Roue_AvD = { 2.514, -0.801, -3.284 },
        BRIO_Roue_AvG = { -2.514, -0.771, -3.284 },
        BRIO_Soubassement = { 0.006, 0.84, 0.76 },
        -- Lot ANIM-02 : pièces des portières.
        BRIO_PorteG_Peinture = { -2.671, 0.31, 0.432 },
        BRIO_PorteD_Peinture = { 2.684, 0.293, 0.432 },
        BRIO_PorteG_Habitacle = { -2.468, 0.36, 0.408 },
        BRIO_PorteD_Habitacle = { 2.48, 0.36, 0.404 },
        BRIO_PorteG_Soubassement = { -2.934, 0.706, 0.507 },
        BRIO_PorteD_Soubassement = { 2.962, 0.67, 0.507 },
        BRIO_Suspension = { -0.001, -0.248, 0.968 },
        BRIO_VerreFeuAr = { 0.014, 2.125, 6.147 },
        BRIO_VerreOptiqueAv = { 0.006, 0.469, -5.168 },
        BRIO_Vitrage_Conducteur = { -2.241, 2.08, 0.777 },
        BRIO_Vitrage_Custodes = { 0.014, 2.227, 4.183 },
        BRIO_Vitrage_Lunette = { 0.014, 2.201, 6.5 },
        BRIO_Vitrage_PareBrise = { 0.015, 2.305, -1.24 },
        BRIO_Vitrage_Passager = { 2.275, 2.052, 0.777 },
        BRIO_Volant = { -1.166, 1.194, -0.152 },
    }

    -- Propriété « contenu » (MeshContent, ColorMapContent…) : identifiant numérique, ou nil.
    local function contentId(inst: any, prop: string): number?
        local ok, value = pcall(function()
            return inst[prop]
        end)
        local digits = if ok and value ~= nil then string.match(tostring(value), "rbxassetid://(%d+)") else nil
        return if digits then tonumber(digits) else nil
    end

    local function sameList(found: { [number]: boolean }, list: { number }?): boolean
        local n = 0
        for _, id in list or {} do
            n += 1
            if not found[id] then
                return false
            end
        end
        for _ in found do
            n -= 1
        end
        return n == 0
    end

    T.test("4. gabarit importé : 27 maillages, aucun script, identifiants = manifeste, crédit CC BY", function()
        local kit = Data.Kits.wk_brio
        local folder = H.game().ServerStorage:FindFirstChild("AutomotiveWorldMeshKits")
        local template = folder and folder:FindFirstChild(kit.Template)
        T.truthy(template ~= nil and template.ClassName == "Model", "ServerStorage.AutomotiveWorldMeshKits.Brio")
        local entry = AssetManifest.get(kit.ManifestId)
        T.truthy(entry ~= nil, "entrée du manifeste")
        T.equal(entry.Status, "ReadyForReview", "validation réservée au propriétaire")
        T.equal(entry.RobloxAssetId, nil, "pas d'identifiant unique jouable")
        local meshes, textures, count, scripts = {}, {}, 0, 0
        for _, item in template:GetDescendants() do
            if item.ClassName == "MeshPart" then
                count += 1
                local id = contentId(item, "MeshContent")
                T.truthy(id ~= nil, item.Name .. " : maillage envoyé sur Roblox")
                meshes[id :: number] = true
            elseif item.ClassName == "SurfaceAppearance" then
                local tex = contentId(item, "ColorMapContent")
                if tex then
                    textures[tex] = true
                end
            elseif item:IsA("LuaSourceContainer") then
                scripts += 1
            end
        end
        -- 33 depuis le lot ANIM-02 (6 pièces de portes).
        T.equal(count, 33, "maillages du gabarit")
        T.equal(scripts, 0, "aucun code dans un modèle importé")
        T.truthy(sameList(meshes, entry.RobloxAssetIds), "maillages du manifeste = maillages du gabarit")
        T.truthy(sameList(textures, entry.RobloxTextureIds), "textures du manifeste = textures du gabarit")
        T.equal(#AssetManifest.validate(), 0, "manifeste cohérent")
        local credit = Attributions.forManifest(kit.ManifestId)
        T.truthy(credit ~= nil and credit.Creator == "Daniel Zhabotinsky", "auteur crédité")
    end)

    T.test(
        "5. positions du gabarit conformes à l'export (±0,01 st) ; couleurs des matériaux unis reposées",
        function()
            local kit = Data.Kits.wk_brio
            local template = H.game().ServerStorage.AutomotiveWorldMeshKits:FindFirstChild(kit.Template)
            local reference = template:FindFirstChild(kit.Reference, true)
            T.truthy(reference ~= nil, kit.Reference)
            local shift = reference.CFrame.Position - kit.ReferenceCenter
            local seen = 0
            for _, item in template:GetDescendants() do
                if item.ClassName == "MeshPart" then
                    local expected = EXPORT[item.Name]
                    T.truthy(expected ~= nil, item.Name .. " : pièce de l'export")
                    if expected then
                        seen += 1
                        local d = item.CFrame.Position - shift
                        local gap = math.max(
                            math.abs(d.X - expected[1]),
                            math.abs(d.Y - expected[2]),
                            math.abs(d.Z - expected[3])
                        )
                        T.truthy(gap <= 0.01, string.format("%s : écart %.4f st", item.Name, gap))
                    end
                    -- Pièce sans texture, ni peinte ni vitrée : sa couleur doit être reposée par la fabrique.
                    local plain = item:FindFirstChildOfClass("SurfaceAppearance") == nil
                        and string.sub(item.Name, -#kit.Paint.Pattern) ~= kit.Paint.Pattern
                        and string.find(string.lower(item.Name), kit.GlassPattern, 1, true) == nil
                    if plain then
                        T.truthy(kit.Colors ~= nil and kit.Colors[item.Name] ~= nil, item.Name .. " : couleur reposée")
                    end
                end
            end
            T.equal(seen, 33, "toutes les pièces de l'export (27 + 6 pièces de portes, lot ANIM-02)")
            for wheel, parts in kit.Wheels do
                T.truthy(template:FindFirstChild(parts[1], true) ~= nil, wheel .. " : " .. parts[1])
            end
        end
    )
end
