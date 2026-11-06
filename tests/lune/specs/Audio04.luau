--!strict
-- Lot AUDIO-04 : bruits de collision. Contrôles hors Studio :
-- - familles d'obstacles, détection d'un Δv impossible pour les pneus, sons des chocs, raclement ;
-- - diffusion par le serveur (canal à sens unique, dès l'ouverture du suivi) ;
-- - écoute côté client (choc du conducteur joué localement, pas de doublon) ;
-- - manifeste.
-- L'écoute et le rendu en jeu relèvent du propriétaire.

return function(T: any, H: any)
    local SHARED = "ReplicatedStorage.Shared."
    local Model = H.require(SHARED .. "Audio.CollisionAudioModel")
    local AmbienceModel = H.require(SHARED .. "Audio.AmbienceModel")
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

    local ids = Model.Ids

    T.suite("AUDIO-04 — bruits de collision")

    T.test("1. familles d'obstacles : véhicule, objet léger non ancré, décor dur", function()
        T.equal(Model.classify(true, false, 1000), "Vehicle")
        T.equal(Model.classify(false, false, 15), "Object", "cône non ancré")
        T.equal(Model.classify(false, true, 15), "Hard", "pièce ancrée : décor")
        T.equal(Model.classify(false, false, 5000), "Hard", "objet lourd non ancré : décor")
    end)

    T.test("2. détection : Δv impossible pour les pneus, freinage et vitesse constante ignorés", function()
        local cruise = { { Time = 0, X = 20, Z = 0 }, { Time = 0.1, X = 20, Z = 0 } }
        T.equal(Model.excess(cruise, 0.2, 20, 0), 0, "vitesse constante")
        -- Freinage au maximum des pneus (≈ 15,9 m/s²) pendant 0,2 s : rien en excès.
        local braking = { { Time = 0, X = 20, Z = 0 } }
        T.equal(Model.excess(braking, 0.2, 20 - 15.9 * 0.2, 0), 0, "freinage à la limite des pneus")
        -- Arrêt de 10 m/s en 0,05 s : ≈ 10 − 0,8 − 0,5 = 8,7 m/s en excès.
        local wall = { { Time = 0, X = 10, Z = 0 } }
        local excess = Model.excess(wall, 0.05, 0, 0)
        T.truthy(excess > 8 and excess < 9.5, string.format("choc contre un mur : %.2f m/s", excess))
    end)

    T.test(
        "3. sons des chocs : seuil, variantes légère et lourde, volume croissant et borné, hauteur variée",
        function()
            T.equal(Model.impact("Hard", 0.5), nil, "sous le seuil : rien")
            T.equal(Model.impact("Hard", 2).Id, ids.HardLight)
            T.equal(Model.impact("Hard", 6).Id, ids.HardHeavy)
            T.equal(Model.impact("Vehicle", 2).Id, ids.VehicleLight)
            T.equal(Model.impact("Vehicle", 8).Id, ids.VehicleHeavy)
            T.equal(Model.impact("Object", 8).Id, ids.Object)
            local previous = 0
            for _, dv in { 1, 2, 4, 8, 14, 40 } do
                local shot = Model.impact("Hard", dv, 0.5)
                T.truthy(
                    shot.Volume >= previous and shot.Volume <= 1,
                    string.format("%d m/s : volume %.2f", dv, shot.Volume)
                )
                previous = shot.Volume
            end
            T.truthy(
                Model.impact("Object", 8, 0.5).Volume < Model.impact("Hard", 8, 0.5).Volume,
                "objet léger plus doux"
            )
            for _, r in { 0, 1 } do
                for _, dv in { 1, 40 } do
                    local speed = Model.impact("Vehicle", dv, r).Speed
                    T.truthy(speed >= 0.85 and speed <= 1.11, string.format("vitesse de lecture bornée : %.3f", speed))
                end
            end
            T.truthy(
                Model.impact("Hard", 2, 0).Speed ~= Model.impact("Hard", 2, 1).Speed,
                "hauteur variée d'un choc à l'autre"
            )
            T.equal(Model.glass(0.5).Id, ids.Glass)
        end
    )

    T.test("4. raclement : rien sans contact ni à l'arrêt, croissant avec la vitesse", function()
        T.equal(Model.scrape(false, 20).Volume, 0, "pas de contact")
        T.equal(Model.scrape(true, 1).Volume, 0, "contact à l'arrêt (véhicule appuyé contre un mur)")
        local slow, fast = Model.scrape(true, 4), Model.scrape(true, 15)
        T.truthy(slow.Volume > 0 and fast.Volume > slow.Volume and fast.Volume <= 1, "volume croissant")
        T.truthy(fast.Speed > slow.Speed, "plus aigu en glissant plus vite")
    end)

    T.test("5. serveur : diffusion à sens unique, dès l'ouverture du suivi, bris d'optique une fois", function()
        T.equal(Constants.Remotes.ImpactSound, "VehicleImpactSound")
        local damage = source("ServerScriptService.AutomotiveWorldServer.Vehicles.DamageService")
        local opening = string.find(damage, "-- Lot AUDIO-04 : son du choc dès l'ouverture du suivi", 1, true)
        local event = string.find(damage, "entry.Event = {", 1, true)
        T.truthy(
            opening ~= nil and event ~= nil and opening < event,
            "son émis à l'ouverture, avant le suivi de 0,4 s"
        )
        T.truthy(
            string.find(damage, 'if light:GetAttribute("AWLightBroken") ~= true then', 1, true) ~= nil,
            "bris d'optique : seulement au passage à « cassée »"
        )
        local service = source("ServerScriptService.AutomotiveWorldServer.Vehicles.VehicleService")
        T.truthy(
            string.find(service, 'local impactSound = Instance.new("UnreliableRemoteEvent")', 1, true) ~= nil,
            "canal non fiable (son seulement)"
        )
        T.truthy(string.find(service, "createdRemotes.ImpactSound:FireAllClients(", 1, true) ~= nil, "diffusé à tous")
        T.truthy(
            string.find(service, "ImpactSound.OnServerEvent", 1, true) == nil,
            "le serveur n'écoute rien sur ce canal"
        )
    end)

    T.test("6. client : choc du conducteur joué localement, diffusion validée et sans doublon", function()
        local audio = source("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.Audio.AudioController")
        T.truthy(
            string.find(audio, "detectDrivenImpact(driven, root)", 1, true) ~= nil,
            "détection locale à chaque image"
        )
        T.truthy(string.find(audio, "return -- déjà joué localement, sans délai", 1, true) ~= nil, "pas de doublon")
        T.truthy(
            string.find(audio, 'if typeof(model) ~= "Instance" or not model:IsA("Model")', 1, true) ~= nil,
            "arguments reçus vérifiés"
        )
        T.truthy(
            string.find(audio, "updateScrape(entry.Model, tirePart", 1, true) ~= nil,
            "raclement des véhicules observés"
        )
    end)

    T.test("7. manifeste : chaque son déclaré, catégorie « Effets », sortie de l'outil, licence", function()
        local AssetManifest = H.require(SHARED .. "Assets.AssetManifest")
        for _, id in ids do
            local asset = AssetManifest.get(id)
            T.truthy(asset ~= nil and asset.Category == "Audio", id .. " : déclaré")
            T.equal(AmbienceModel.categoryOf(id), "Effects", id .. " : volume « Effets » (décision Q4)")
            T.truthy(string.sub(asset.Output or "", 1, 23) == "build/audio/collisions/", id .. " : sortie de l'outil")
            T.truthy(string.find(asset.Licence, "CC0", 1, true) ~= nil, id .. " : licence relevée")
            -- Envoyés sur Roblox par le propriétaire le 2026-11-06 (audio04_collisions.rbxm) : jouables.
            T.truthy(AssetManifest.playable(id), id .. " : identifiant Roblox présent")
        end
        local seen = {}
        for _, number in AssetManifest.CollisionSoundIds do
            T.truthy(seen[number] == nil, "identifiants distincts")
            seen[number] = true
        end
    end)
end
