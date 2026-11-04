--!strict
-- Lot VEH3D-01 : carrosserie 3D de la Comète (kit de maillages). Contrôles hors Studio, sur la place construite :
-- gabarit réel (ServerStorage), identifiants d'actifs, données mesurées du kit, repli de la fabrique.
-- Le comportement en jeu (soudures, roues animées, caméras, avatars) relève de la VM (QA_BACKLOG).

return function(T: any, H: any)
    local SHARED = "ReplicatedStorage.Shared."
    local Data = H.require(SHARED .. "Vehicles.MeshKitData")
    local AssetManifest = H.require(SHARED .. "Assets.AssetManifest")
    local Definitions = H.require(SHARED .. "Vehicles.VehicleDefinitions")
    local Dynamics = H.require(SHARED .. "Vehicles.Physics.VehicleDynamics")
    local Constants = H.require(SHARED .. "Vehicles.VehicleConstants")
    local game = H.game()

    local function source(path: string): string
        local node = game
        for segment in string.gmatch(path, "[^%.]+") do
            node = node:FindFirstChild(segment)
            assert(node, path)
        end
        return node.Source
    end

    -- Propriété « contenu » (MeshContent, ColorMapContent…) : identifiant numérique, ou nil.
    local function contentId(inst: any, prop: string): number?
        local ok, value = pcall(function()
            return inst[prop]
        end)
        if not ok or value == nil then
            return nil
        end
        local digits = string.match(tostring(value), "rbxassetid://(%d+)")
        return if digits then tonumber(digits) else nil
    end

    local function set(list: { number }?): { [number]: boolean }
        local out = {}
        for _, v in list or {} do
            out[v] = true
        end
        return out
    end

    local function sameSet(a: { [number]: boolean }, b: { [number]: boolean }): boolean
        for k in a do
            if not b[k] then
                return false
            end
        end
        for k in b do
            if not a[k] then
                return false
            end
        end
        return true
    end

    local kit = Data.Kits.wk_comete
    local folder = game:FindFirstChild("ServerStorage") and game.ServerStorage:FindFirstChild("AutomotiveWorldMeshKits")
    local template = folder and folder:FindFirstChild(kit.Template)

    T.suite("VEH3D-01 — Comète 3D (kit de maillages)")

    T.test("1. gabarit présent dans ServerStorage, 28 maillages, aucun script", function()
        T.truthy(template ~= nil and template.ClassName == "Model", "ServerStorage.AutomotiveWorldMeshKits.Comete720s")
        local meshes, scripts = 0, 0
        for _, item in template:GetDescendants() do
            if item.ClassName == "MeshPart" then
                meshes += 1
            elseif item:IsA("LuaSourceContainer") then
                scripts += 1
            end
        end
        T.equal(meshes, 28, "maillages du gabarit")
        T.equal(scripts, 0, "aucun code dans un modèle importé")
    end)

    T.test("2. identifiants d'actifs : exactement ceux du gabarit, rien d'inventé", function()
        local entry = AssetManifest.get(kit.ManifestId)
        T.truthy(entry ~= nil, kit.ManifestId)
        T.equal(entry.Status, "ReadyForReview", "validation réservée au propriétaire")
        T.truthy(string.find(entry.Licence, "CC BY", 1, true) ~= nil, "licence tierce déclarée")
        T.equal(entry.RobloxAssetId, nil, "pas d'identifiant unique jouable")
        local meshes, textures = {}, {}
        for _, item in template:GetDescendants() do
            if item.ClassName == "MeshPart" then
                local id = contentId(item, "MeshContent")
                T.truthy(id ~= nil, item.Name .. " : maillage envoyé sur Roblox")
                meshes[id :: number] = true
                local tex = contentId(item, "TextureContent")
                if tex then
                    textures[tex] = true
                end
            elseif item.ClassName == "SurfaceAppearance" then
                for _, prop in { "ColorMapContent", "NormalMapContent", "MetalnessMapContent", "RoughnessMapContent" } do
                    local tex = contentId(item, prop)
                    if tex then
                        textures[tex] = true
                    end
                end
            end
        end
        T.truthy(sameSet(meshes, set(entry.RobloxAssetIds)), "maillages du manifeste = maillages du gabarit")
        T.truthy(sameSet(textures, set(entry.RobloxTextureIds)), "textures du manifeste = textures du gabarit")
        T.equal(#AssetManifest.validate(), 0, "manifeste cohérent")
    end)

    T.test(
        "3. roues du modèle calées sur la physique (voie plus étroite de 0,10 à 0,20 st, décision du propriétaire)",
        function()
            local definition = Definitions.get("wk_comete")
            local layout = Dynamics.wheelLayout(definition)
            local M = Constants.MetersPerStud
            local hubY = -definition.Chassis.CgHeightM / M + definition.Tires.RadiusM / M
            local reference = template:FindFirstChild(kit.Reference, true)
            T.truthy(reference ~= nil, kit.Reference)
            local shift = reference.CFrame.Position - kit.ReferenceCenter -- (Lune : Position non sérialisée)
            for index, name in Constants.WheelNames do
                local place = layout[index]
                local tyre = template:FindFirstChild(kit.Wheels[name][1], true)
                T.truthy(tyre ~= nil, kit.Wheels[name][1])
                local p = tyre.CFrame.Position - shift
                local lateral = place.Lateral / M
                T.truthy(math.abs(p.Z - (-place.Longitudinal / M)) <= 0.03, name .. " : position longitudinale")
                T.truthy(math.abs(p.Y - hubY) <= 0.03, name .. " : hauteur du moyeu")
                local inward = math.abs(lateral) - math.abs(p.X)
                T.truthy(
                    inward >= 0.10 and inward <= 0.20,
                    string.format("%s : voie du modèle %.3f st plus étroite", name, inward)
                )
                T.truthy(math.sign(p.X) == math.sign(lateral), name .. " : bon côté")
            end
        end
    )

    T.test("4. sièges, caméras et collisions mesurés : cohérents entre eux", function()
        T.equal(kit.SeatDriver.X, -kit.SeatPassenger.X, "places symétriques")
        T.truthy(kit.SeatDriver.X < 0, "conduite à gauche, comme le jeu")
        local cabin = kit.Collisions.Habitacle
        for _, seat in { kit.SeatDriver, kit.SeatPassenger } do
            T.truthy(math.abs(seat.X - cabin.Center.X) <= cabin.Size.X / 2, "siège dans la largeur de l'habitacle")
            T.truthy(math.abs(seat.Z - cabin.Center.Z) <= cabin.Size.Z / 2, "siège dans la longueur de l'habitacle")
        end
        T.truthy(kit.CameraCockpit.Y < cabin.Center.Y + cabin.Size.Y / 2, "caméra cockpit sous le pavillon")
        T.truthy(kit.CameraBumper.Z < kit.Collisions.BouclierAvant.Center.Z, "caméra bouclier devant le nez")
        local names = {}
        for name in kit.Collisions do
            table.insert(names, name)
        end
        table.sort(names)
        T.equal(table.concat(names, ","), "BouclierArriere,BouclierAvant,Coque,Habitacle", "noms des zones de dégâts")
        local damage = source("ServerScriptService.AutomotiveWorldServer.Vehicles.DamageService")
        for _, name in names do
            T.truthy(
                string.find(damage, '"' .. name .. '"', 1, true) ~= nil or name == "Coque" or name == "Habitacle",
                name .. " : zone connue des dégâts"
            )
        end
    end)

    T.test("5. vitrage, feux et détails : présents dans le gabarit", function()
        local glass, details = 0, 0
        for _, item in template:GetDescendants() do
            if item.ClassName == "MeshPart" then
                if string.find(string.lower(item.Name), kit.GlassPattern, 1, true) then
                    glass += 1
                end
                for _, pattern in kit.DetailPattern do
                    if string.find(item.Name, pattern, 1, true) then
                        details += 1
                        break
                    end
                end
            end
        end
        T.truthy(glass >= 1, "pièces de vitrage repérées (transparence posée par la fabrique)")
        T.truthy(details >= 3, "pièces de détail repérées")
        local head, tail = 0, 0
        for _, spec in kit.Lights do
            head += if spec.Light == "Head" then 1 else 0
            tail += if spec.Light == "Tail" then 1 else 0
        end
        T.equal(head, 2, "deux phares")
        T.equal(tail, 2, "deux feux arrière")
    end)

    T.test("6. fabrique : kit seulement pour la Comète, repli sur la carrosserie provisoire", function()
        for _, definition in Definitions.all() do
            T.truthy((Data.Kits[definition.Id] ~= nil) == (definition.Id == "wk_comete"), definition.Id)
        end
        local factory = source("ServerScriptService.AutomotiveWorldServer.Vehicles.VehicleFactory")
        T.truthy(
            string.find(factory, "MeshKits.template(definition.Id)", 1, true) ~= nil,
            "kit demandé par la fabrique"
        )
        T.truthy(
            string.find(factory, "elseif styleName and BodyKits.has(styleName) then", 1, true) ~= nil,
            "repli provisoire"
        )
        local meshKits = source("ServerScriptService.AutomotiveWorldServer.Vehicles.MeshKits")
        T.truthy(string.find(meshKits, '"MaillageNonAutorise"', 1, true) ~= nil, "maillage hors manifeste refusé")
        T.equal(Data.assetNumber("rbxassetid://135006162692878"), 135006162692878)
        T.equal(Data.assetNumber("http://www.roblox.com/asset/?id=42"), 42)
        T.equal(Data.assetNumber(""), nil)
    end)
end
