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

    T.test("1. gabarit présent dans ServerStorage, 29 maillages, aucun script", function()
        T.truthy(template ~= nil and template.ClassName == "Model", "ServerStorage.AutomotiveWorldMeshKits.Comete720s")
        local meshes, scripts = 0, 0
        for _, item in template:GetDescendants() do
            if item.ClassName == "MeshPart" then
                meshes += 1
            elseif item:IsA("LuaSourceContainer") then
                scripts += 1
            end
        end
        -- 29 depuis le lot ANIM-01 (volant séparé de l'habitacle, COMETE_Volant).
        T.equal(meshes, 29, "maillages du gabarit")
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

    T.test("6. fabrique : kit pour la Comète et la Brio (VEH3D-02), repli sur la coque générée par code", function()
        for _, definition in Definitions.all() do
            local expected = definition.Id == "wk_comete" or definition.Id == "wk_brio"
            T.truthy((Data.Kits[definition.Id] ~= nil) == expected, definition.Id)
        end
        local factory = source("ServerScriptService.AutomotiveWorldServer.Vehicles.VehicleFactory")
        T.truthy(
            string.find(factory, "MeshKits.template(definition.Id)", 1, true) ~= nil,
            "kit demandé par la fabrique"
        )
        T.truthy(string.find(factory, "BodyKits", 1, true) == nil, "carrosseries provisoires supprimées (lot BASE-01)")
        T.truthy(string.find(factory, "Carrosserie de REPLI", 1, true) ~= nil, "repli : coque générée par code")
        local meshKits = source("ServerScriptService.AutomotiveWorldServer.Vehicles.MeshKits")
        T.truthy(string.find(meshKits, '"MaillageNonAutorise"', 1, true) ~= nil, "maillage hors manifeste refusé")
        -- Boîtes de collision du kit jamais copiées en panneau déformé (bloc opaque, VEH3D-01 §7).
        T.truthy(string.find(meshKits, '"AWCollisionOnly", true', 1, true) ~= nil, "boîtes marquées par la fabrique")
        local damage = source("ServerScriptService.AutomotiveWorldServer.Vehicles.DamageService")
        T.truthy(string.find(damage, 'GetAttribute("AWCollisionOnly")', 1, true) ~= nil, "dégâts : boîtes ignorées")
        T.equal(Data.assetNumber("rbxassetid://135006162692878"), 135006162692878)
        T.equal(Data.assetNumber("http://www.roblox.com/asset/?id=42"), 42)
        T.equal(Data.assetNumber(""), nil)
    end)

    T.test("7. crédits CC BY : attribution pour chaque œuvre tierce, textes FR et EN", function()
        local Attributions = H.require("ReplicatedStorage.Shared.Assets.Attributions")
        local Localization = H.require("ReplicatedStorage.Shared.UI.Localization")
        for _, entry in AssetManifest.Assets do
            if type(entry.Licence) == "string" and string.find(entry.Licence, "CC BY", 1, true) then
                T.truthy(Attributions.forManifest(entry.Id) ~= nil, entry.Id .. " : attribution affichée en jeu")
            end
        end
        T.truthy(Attributions.forManifest(kit.ManifestId) ~= nil, "attribution de la Comète")
        for _, item in Attributions.List do
            T.truthy(AssetManifest.get(item.ManifestId) ~= nil, item.ManifestId .. " : entrée du manifeste")
            T.truthy(item.Creator ~= "" and item.Licence == "CC BY 4.0", "auteur et licence")
            T.equal(item.ShowTitle, false, "titre (nom de marque) masqué tant que le propriétaire n'a pas tranché")
            T.equal(item.ShowUrl, false, "lien externe masqué tant que le propriétaire n'a pas tranché")
            for _, key in { item.UsageKey, item.ChangesKey, "settings.credits", "credits.entry", "credits.licence" } do
                local fr, en = Localization.t(key, nil, "fr"), Localization.t(key, nil, "en")
                T.truthy(fr ~= key and en ~= key and fr ~= en, key .. " : FR et EN")
            end
        end
        local phone = source("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.UI.PhoneController")
        T.truthy(string.find(phone, '"Credits"', 1, true) ~= nil, "page Crédits des paramètres du téléphone")
    end)

    T.test(
        "8. dégâts et feux : marques sur la surface mesurée, feux stop répliqués, optique cassée éteinte",
        function()
            local marks = kit.DamageMarks
            local front = kit.Collisions.BouclierAvant
            local rear = kit.Collisions.BouclierArriere
            for i = 1, 3 do
                T.truthy(marks.Front[i] < front.Center.Z - front.Size.Z / 2 + 0.25, "avant : surface devant la boîte")
                T.truthy(marks.Front[i] > kit.CameraBumper.Z, "avant : en retrait de la caméra bouclier")
                T.truthy(
                    marks.Rear[i] > rear.Center.Z + rear.Size.Z / 2 - 0.25,
                    "arrière : surface derrière la boîte"
                )
                T.truthy(
                    marks.Side[i] > 3 and marks.Side[i] <= kit.SideHalf,
                    "flanc entre la coque et les rétroviseurs"
                )
            end
            local damage = source("ServerScriptService.AutomotiveWorldServer.Vehicles.DamageService")
            T.truthy(string.find(damage, "DamageMarks", 1, true) ~= nil, "dégâts : surface du kit")
            T.truthy(
                string.find(damage, '"AWLightBroken", true', 1, true) ~= nil,
                "dégâts : optique marquée cassée"
            )
            local service = source("ServerScriptService.AutomotiveWorldServer.Vehicles.VehicleService")
            T.truthy(string.find(service, "Attributes.VisualBrake, braking", 1, true) ~= nil, "freinage publié")
            local lights = source("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.World.VehicleLights")
            T.truthy(string.find(lights, "VisualBrake", 1, true) ~= nil, "feux stop lus par l'éclairage")
            T.truthy(string.find(lights, "AWLightBroken", 1, true) ~= nil, "optique cassée laissée éteinte")
            T.equal(
                kit.Paint.NeutralColorMap,
                nil,
                "teinte du garage inactive tant que la texture neutre n'est pas envoyée"
            )
        end
    )

    T.test(
        "9. sorties : occupant sans collision avec les véhicules jusqu'à son placement, passager placé à droite",
        function()
            T.equal(Constants.CollisionGroups.Exiting, "AWSortie", "groupe de sortie")
            local factory = source("ServerScriptService.AutomotiveWorldServer.Vehicles.VehicleFactory")
            T.truthy(
                string.find(factory, "CollisionGroupSetCollidable(groups.Vehicle, groups.Exiting, false)", 1, true)
                    ~= nil,
                "sortie et véhicule sans collision"
            )
            local service = source("ServerScriptService.AutomotiveWorldServer.Vehicles.VehicleService")
            local _, seated = string.gsub(service, "setExiting%(seatedCharacter%)", "")
            T.equal(seated, 2, "conducteur et passager passent dans le groupe en s'asseyant")
            T.truthy(
                string.find(service, "placeBeside(record, previous, character, 1)", 1, true) ~= nil,
                "passager côté droit"
            )
            T.truthy(
                string.find(service, "placeBeside(record, humanoid, character, -1)", 1, true) ~= nil,
                "conducteur côté gauche"
            )
            T.truthy(string.find(service, "EXIT_ORPHAN_S", 1, true) ~= nil, "garde-fou : groupe rendu sans placement")
            T.truthy(string.find(service, "Protected then", 1, true) ~= nil, "protection d'arrivée jamais rendue")
        end
    )

    T.test(
        "10. boîte séquentielle : accélérer au neutre et à l'arrêt engage le 1er (décision du propriétaire)",
        function()
            local Transmission = H.require(SHARED .. "Vehicles.Physics.Transmission")
            local definition = Definitions.get("wk_comete")
            T.equal(definition.Powertrain.Transmission.Kind, "Sequential", "Comète : boîte séquentielle")
            local function state(): any
                return { Gear = 0, ShiftTimer = 0, ManualHoldTimer = 0, ClutchPedal = 0 }
            end
            local press = { Throttle = 0.6, Brake = 0, Steer = 0, Handbrake = false, Clutch = 0 }
            local idle = { Throttle = 0, Brake = 0, Steer = 0, Handbrake = false, Clutch = 0 }
            local s1 = state()
            Transmission.update(s1, definition.Powertrain, idle, 0, 0, 1 / 60)
            T.equal(s1.Gear, 0, "au repos : reste au neutre")
            Transmission.update(s1, definition.Powertrain, press, 0, 0, 1 / 60)
            T.equal(s1.Gear, 1, "accélérer à l'arrêt : 1er engagé")
            local s2 = state()
            Transmission.update(s2, definition.Powertrain, press, 6, 20, 1 / 60)
            T.equal(s2.Gear, 0, "en roue libre au neutre (6 m/s) : pas d'engagement imposé")
            local s3 = state()
            s3.Gear = -1
            Transmission.update(s3, definition.Powertrain, press, 0, 0, 1 / 60)
            T.equal(s3.Gear, -1, "marche arrière conservée")
        end
    )
end
