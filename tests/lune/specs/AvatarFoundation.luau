--!strict
-- Lot AVATAR-01 — R15 normal et fondation cosmétique : politique d'avatar, réglage des
-- deux places, catalogue des tenues (cinq catégories sans ressource), règles pures
-- d'essayage / équipement / retrait / restauration, refus des identifiants mal formés.
-- Les identifiants numériques de ces tests sont des valeurs ARBITRAIRES de règles pures :
-- ils ne sont jamais envoyés au moteur ni ajoutés au catalogue.
-- Les essais dans le moteur (personnages dans les véhicules) : session VM « avatar ».

local SHARED = "ReplicatedStorage.Shared."

return function(T: any, H: any)
    local AvatarPolicy = H.require(SHARED .. "Avatar.AvatarPolicy")
    local OutfitCatalog = H.require(SHARED .. "Cosmetics.OutfitCatalog")
    local OutfitRules = H.require(SHARED .. "Cosmetics.OutfitRules")
    local Localization = H.require(SHARED .. "UI.Localization")

    local function source(path: string): string
        local node = H.game()
        for segment in string.gmatch(path, "[^%.]+") do
            node = node:FindFirstChild(segment)
        end
        return node.Source
    end

    T.suite("Lot AVATAR-01 — R15 et tenues")

    T.test("Politique : R15 seul, plages d'échelle par défaut de Roblox, aucune limitation décidée", function()
        T.truthy(AvatarPolicy.isAllowedRig("R15"), "R15 admis")
        T.truthy(not AvatarPolicy.isAllowedRig("R6"), "R6 refusé")
        T.equal(AvatarPolicy.LimitedByTests, false, "proportions non limitées sans preuve")
        local ranges = AvatarPolicy.ScaleRanges
        T.equal(ranges.Height.Min, 0.9)
        T.equal(ranges.Height.Max, 1.05)
        T.equal(ranges.Width.Min, 0.7)
        T.equal(ranges.Head.Min, 0.95)
        T.equal(ranges.BodyType.Max, 1)
        T.equal(ranges.BodyType.Min, 1, "avatars humains : type de corps imposé (propriétaire, 2026-11-04)")
        T.equal(ranges.Proportion.Max, 1)
        T.truthy((AvatarPolicy.scalesWithinRanges({ Height = 1.05, Width = 0.7, BodyType = 1 })), "extrêmes admis")
        T.truthy(AvatarPolicy.HumanOnly, "avatars humains uniquement")
        T.truthy(not (AvatarPolicy.scalesWithinRanges({ BodyType = 0 })), "corps « en blocs » hors plage")
        T.equal(AvatarPolicy.clampScale("BodyType", 0), 1, "proportions humaines imposées")
        T.equal(AvatarPolicy.clampScale("Height", 0 / 0), 0.9, "valeur non finie ramenée au minimum")
        -- Deux corps retenus par le propriétaire (2026-11-04) : 995 Billie et 994 Jordan, corps seul.
        T.equal(table.concat(AvatarPolicy.BodyOrder, ","), "Masculin,Feminin", "choix proposé au joueur")
        T.equal(AvatarPolicy.Bodies.Masculin.BundleId, 995, "corps masculin : Base Body - Billie")
        T.equal(AvatarPolicy.Bodies.Feminin.BundleId, 994, "corps féminin : Base Body - Jordan")
        T.equal(AvatarPolicy.Bodies.Masculin.Parts.Torso, 11748986529)
        T.equal(AvatarPolicy.Bodies.Feminin.Parts.Torso, 11740060397)
        T.truthy(table.find(AvatarPolicy.ReplacedParts, "Head") == nil, "tête jamais remplacée d'office")
        -- Têtes classiques (propriétaire, 2026-11-04) : critère de forme mesuré en VM (20261104-161530).
        T.truthy(AvatarPolicy.isClassicHeadShape(1.127, 1.133, 1.128), "tête par défaut : classique")
        T.truthy(AvatarPolicy.isClassicHeadShape(1.198, 1.202, 1.207), "tête classique dynamique (Err...)")
        T.truthy(not AvatarPolicy.isClassicHeadShape(1.282, 1.802, 1.383), "tête réaliste Addison : conservée")
        T.truthy(not AvatarPolicy.isClassicHeadShape(1.269, 1.943, 1.472), "tête réaliste Billie : conservée")
        T.truthy(not AvatarPolicy.isClassicHeadShape(1.279, 1.801, 1.445), "tête réaliste Dawson (profondeur 0,80)")
        T.truthy(not AvatarPolicy.isClassicHeadShape(1, 0, 1), "hauteur nulle : non classée")
        T.equal(AvatarPolicy.headFor("Masculin", 10638267973, true), 11748988354, "classique → tête Billie")
        T.equal(AvatarPolicy.headFor("Feminin", 10638267973, true), 11740063830, "classique → tête Jordan")
        T.equal(AvatarPolicy.headFor("Feminin", 0, false), 11740063830, "tête par défaut toujours remplacée")
        T.equal(AvatarPolicy.headFor("Masculin", 11702291006, false), 11702291006, "tête réaliste conservée")
        local seen = {}
        for _, id in AvatarPolicy.BodyOrder do
            local body = AvatarPolicy.Bodies[id]
            T.equal(body.Parts.Head, nil, id .. " : aucune tête imposée")
            for _, field in AvatarPolicy.ReplacedParts do
                local assetId = body.Parts[field]
                T.truthy(type(assetId) == "number" and assetId > 0, id .. "." .. field .. " renseigné")
                T.truthy(seen[assetId] == nil, "identifiant unique " .. tostring(assetId))
                seen[assetId] = true
            end
        end
        T.truthy(AvatarPolicy.body(AvatarPolicy.DefaultBody) ~= nil, "corps par défaut connu")
        T.equal(AvatarPolicy.body("Robot"), nil, "corps inconnu refusé")
        T.equal(AvatarPolicy.body(42), nil, "identifiant non textuel refusé")
        local worn = table.clone(AvatarPolicy.Bodies.Feminin.Parts) :: { [string]: number }
        worn.Head = 999 -- tête du joueur, sans effet sur la vérification
        T.truthy(AvatarPolicy.wearsBody(worn, "Feminin"), "corps porté reconnu")
        T.truthy(not AvatarPolicy.wearsBody(worn, "Masculin"), "autre corps non reconnu")
        worn.LeftLeg = 0
        T.truthy(not AvatarPolicy.wearsBody(worn, "Feminin"), "partie manquante détectée")
        local ok, outside = AvatarPolicy.scalesWithinRanges({ Height = 1.2, Width = 0 / 0 })
        T.truthy(not ok, "hors plage refusé")
        T.equal(table.concat(outside, ","), "Height,Width", "hauteur excessive et NaN signalés")
    end)

    T.test("Réglage des deux places : R15, apparence du joueur chargée", function()
        local starter = H.game():GetService("StarterPlayer")
        T.truthy(string.find(tostring(starter.GameSettingsAvatar), "R15", 1, true) ~= nil, "place Dev : R15")
        T.equal(starter.LoadCharacterAppearance, true, "place Dev : apparence du joueur")
        local fs = require("@lune/fs")
        local serde = require("@lune/serde")
        for _, file in { "default.project.json", "openworld.project.json" } do
            local project = serde.decode("json", fs.readFile(file))
            local props = project.tree.StarterPlayer["$properties"]
            T.truthy(props ~= nil and props.GameSettingsAvatar == "R15", file .. " : R15")
            T.truthy(props.LoadCharacterAppearance == true, file .. " : apparence du joueur")
        end
        local bootstrap = source("ServerScriptService.AutomotiveWorldServer.Bootstrap")
        T.truthy(string.find(bootstrap, "AvatarService.start()", 1, true) ~= nil, "contrôle R15 démarré")
    end)

    T.test("Catalogue : cinq catégories préparées, emplacements sans ressource ni identifiant", function()
        local expected = { "CircuitPremium", "StreetRacing", "Mechanic", "RoadsideAssistance", "RideHailDriver" }
        T.equal(#OutfitCatalog.Categories, #expected, "cinq catégories")
        for index, id in expected do
            T.equal(OutfitCatalog.Categories[index].Id, id, "ordre des catégories")
        end
        T.equal(#OutfitCatalog.Outfits, 5, "une tenue-emplacement par catégorie")
        for _, outfit in OutfitCatalog.Outfits do
            T.equal(outfit.Status, "Placeholder", outfit.Id .. " : emplacement")
            T.equal(next(outfit.Items), nil, outfit.Id .. " : aucun identifiant d'actif")
            local valid, errors = OutfitRules.validateOutfit(outfit)
            T.truthy(valid, outfit.Id .. " : " .. table.concat(errors, ","))
        end
        -- Aucun identifiant d'actif écrit dans le catalogue (ni nombre long, ni rbxassetid).
        local catalog = source("ReplicatedStorage.Shared.Cosmetics.OutfitCatalog")
        T.truthy(string.find(catalog, "rbxassetid", 1, true) == nil, "aucun rbxassetid")
        T.truthy(string.find(catalog, "%d%d%d%d%d") == nil, "aucun identifiant numérique")
        T.truthy(string.find(catalog, "require(", 1, true) == nil, "catalogue autonome (aucun module requis)")
        -- Indépendant des cosmétiques automobiles.
        T.truthy(string.find(catalog, "require%([^)]*Vehicles") == nil, "aucune dépendance aux véhicules")
        T.truthy(string.find(catalog, "require%([^)]*Garage") == nil, "aucune dépendance au garage")
    end)

    T.test("Catalogue : emplacements classiques, superposés et rigides ; textes FR/EN", function()
        local groups = { Classic = 0, Layered = 0, Rigid = 0 }
        local accessoryTypes = {
            TShirt = true,
            Shirt = true,
            Pants = true,
            Jacket = true,
            Sweater = true,
            Shorts = true,
            LeftShoe = true,
            RightShoe = true,
            DressSkirt = true,
            Hat = true,
            Hair = true,
            Face = true,
            Neck = true,
            Shoulder = true,
            Front = true,
            Back = true,
            Waist = true,
        }
        local keys = {}
        for _, slot in OutfitCatalog.Slots do
            groups[slot.Group] += 1
            if slot.Group == "Classic" then
                T.truthy(slot.Field == "Shirt" or slot.Field == "Pants" or slot.Field == "GraphicTShirt", slot.Id)
            else
                T.truthy(accessoryTypes[slot.AccessoryType] == true, slot.Id .. " : type d'accessoire Roblox")
            end
            if slot.Group == "Layered" then
                T.truthy(type(slot.Order) == "number", slot.Id .. " : ordre de superposition")
            end
            table.insert(keys, slot.LabelKey)
        end
        T.equal(groups.Classic, 3, "Shirt / Pants / T-shirt")
        T.equal(groups.Layered, 9, "vêtements superposés")
        T.equal(groups.Rigid, 8, "accessoires additionnels")
        for _, category in OutfitCatalog.Categories do
            table.insert(keys, category.LabelKey)
        end
        for _, outfit in OutfitCatalog.Outfits do
            table.insert(keys, outfit.LabelKey)
        end
        for _, reason in
            {
                "OutfitUnknown",
                "OutfitNotAvailable",
                "OutfitAssetInvalid",
                "OutfitNotWhileSeated",
                "OutfitNoCharacter",
                "OutfitAppearanceLoading",
                "OutfitBusy",
                "OutfitSlotUnknown",
            }
        do
            table.insert(keys, reason)
        end
        for _, key in keys do
            local fr = Localization.t(key, nil, "fr")
            local en = Localization.t(key, nil, "en")
            T.truthy(fr ~= key and fr ~= "", key .. " : français")
            T.truthy(en ~= key and en ~= "" and en ~= fr or key == "outfit.slot.LayeredTShirt", key .. " : anglais")
        end
    end)

    T.test("Identifiants d'actifs : mal formés refusés avant le moteur", function()
        T.truthy(OutfitRules.validAssetId(1), "entier positif")
        T.truthy(OutfitRules.validAssetId(2 ^ 53), "plus grand entier exact")
        for _, bad in { 0, -5, 1.5, 0 / 0, math.huge, -math.huge, 2 ^ 53 + 2, "123", true } do
            T.truthy(not OutfitRules.validAssetId(bad), "refusé : " .. tostring(bad))
        end
        local ok, errors = OutfitRules.validateOutfit({
            Id = "essai",
            Category = "Mechanic",
            Status = "Available",
            LabelKey = "x",
            Items = { LayeredJacket = 1.5, Inconnu = 3 },
        })
        T.truthy(not ok, "tenue mal formée refusée")
        T.equal(table.concat(errors, ","), "OutfitAssetInvalid:LayeredJacket,OutfitSlotUnknown:Inconnu")
        local _, placeholder = OutfitRules.validateOutfit({
            Id = "essai",
            Category = "Mechanic",
            Status = "Placeholder",
            LabelKey = "x",
            Items = { Hat = 7 },
        })
        T.equal(placeholder[1], "OutfitPlaceholderHasAssets", "un emplacement ne porte pas d'actif")
        T.truthy(not (OutfitRules.validateOutfit(nil)), "absence refusée")
    end)

    T.test("Essayage, retrait d'un emplacement et restauration de l'apparence initiale", function()
        -- Apparence « joueur » : chemise classique, cheveux, chapeau, veste superposée.
        local initial = {
            Shirt = 11,
            Pants = 12,
            GraphicTShirt = 0,
            Accessories = {
                { AssetId = 21, AccessoryType = "Hair", IsLayered = false },
                { AssetId = 22, AccessoryType = "Hat", IsLayered = false },
                { AssetId = 23, AccessoryType = "Jacket", IsLayered = true, Order = 9 },
            },
        }
        local outfit = {
            Id = "essai.1",
            Category = "Mechanic",
            Status = "Available",
            LabelKey = "x",
            Items = { ClassicPants = 31, Hat = 32, LayeredJacket = 33, LayeredLeftShoe = 34 },
        }
        T.truthy((OutfitRules.validateOutfit(outfit)), "tenue d'essai valide")
        local worn = OutfitRules.wear(initial, outfit)
        T.equal(worn.Shirt, 11, "haut du joueur conservé (non porté par la tenue)")
        T.equal(worn.Pants, 31, "bas remplacé")
        local byType = {}
        for _, item in worn.Accessories do
            T.truthy(byType[item.AccessoryType] == nil, "un seul accessoire par emplacement : " .. item.AccessoryType)
            byType[item.AccessoryType] = item
        end
        T.equal(byType.Hair.AssetId, 21, "cheveux du joueur conservés")
        T.equal(byType.Hat.AssetId, 32, "chapeau remplacé")
        T.equal(byType.Jacket.AssetId, 33, "veste remplacée")
        T.truthy(byType.Jacket.IsLayered and byType.Jacket.Order == 7, "veste superposée, ordre du catalogue")
        T.truthy(byType.LeftShoe.IsLayered and byType.LeftShoe.Order == 1, "chaussure ajoutée")
        T.equal(initial.Pants, 12, "apparence initiale non modifiée")

        local without, reason = OutfitRules.removeSlot(worn, initial, "Hat")
        T.equal(reason, nil)
        local hats = 0
        for _, item in (without :: any).Accessories do
            if item.AccessoryType == "Hat" then
                hats += 1
                T.equal(item.AssetId, 22, "chapeau du joueur rendu")
            end
        end
        T.equal(hats, 1, "un chapeau après retrait")
        local shoeless = OutfitRules.removeSlot(worn, initial, "LayeredLeftShoe")
        for _, item in (shoeless :: any).Accessories do
            T.truthy(item.AccessoryType ~= "LeftShoe", "chaussure retirée (absente au départ)")
        end
        local classic = OutfitRules.removeSlot(worn, initial, "ClassicPants")
        T.equal((classic :: any).Pants, 12, "bas du joueur rendu")
        T.equal(select(2, OutfitRules.removeSlot(worn, initial, "Inconnu")), "OutfitSlotUnknown")

        T.truthy(OutfitRules.equal(OutfitRules.copy(initial), initial), "restauration exacte")
        T.truthy(not OutfitRules.equal(worn, initial), "tenue différente de l'apparence initiale")
        -- Actif ignoré par le moteur : détecté (le serveur rétablit alors l'apparence).
        local applied = OutfitRules.copy(worn)
        table.remove(applied.Accessories, #applied.Accessories)
        T.truthy(#OutfitRules.missing(worn, applied) == 1, "actif manquant détecté")
        T.equal(#OutfitRules.missing(worn, worn), 0)
    end)

    T.test("Serveur : le client ne désigne qu'une tenue du catalogue ; refus assis", function()
        local server = source("ServerScriptService.AutomotiveWorldServer.Avatar.AvatarService")
        T.truthy(
            string.find(server, "outfitFor(data.Id)", 1, true) ~= nil,
            "tenue choisie par identifiant de catalogue"
        )
        T.truthy(string.find(server, "data.AssetId", 1, true) == nil, "aucun identifiant d'actif reçu du client")
        T.truthy(string.find(server, '"OutfitNotWhileSeated"', 1, true) ~= nil, "refus dans un véhicule")
        T.truthy(string.find(server, "RateLimiter.consume", 1, true) ~= nil, "demandes limitées")
        T.truthy(
            string.find(server, "ApplyDescriptionAsync(before)", 1, true) ~= nil,
            "apparence rétablie après échec"
        )
        -- QA-A10 (lot 0.9.2) non remplacée : le téléphone et le bras ne dépendent pas de ce lot.
        T.truthy(string.find(server, "AWPhoneRaised", 1, true) == nil, "bras du téléphone non touché")
    end)
end
