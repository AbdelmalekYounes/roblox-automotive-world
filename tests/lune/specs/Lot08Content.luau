--!strict
-- Lot 0.8 — direction artistique, gamme de 18 modèles, audio, radio, mode photo,
-- parcours d'arrivée : règles PURES et données (fiches, manifeste, localisation,
-- migrations). Ne valide PAS le rendu, le son réel, la radio en multijoueur, le
-- mode photo en jeu ni le parcours avec de vrais comptes (NON TESTÉ, QA_BACKLOG).

local SERVER = "ServerScriptService.AutomotiveWorldServer."
local SHARED = "ReplicatedStorage.Shared."
local CLIENT = "StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient."

return function(T: any, H: any)
    local Definitions = H.require(SHARED .. "Vehicles.VehicleDefinitions")
    local VehicleCatalog = H.require(SHARED .. "Economy.VehicleCatalog")
    local StarterCatalog = H.require(SHARED .. "Garage.StarterCatalog")
    local CosmeticCatalog = H.require(SHARED .. "Garage.CosmeticCatalog")
    local OnboardingRules = H.require(SHARED .. "Onboarding.OnboardingRules")
    local TrainingRules = H.require(SHARED .. "Onboarding.TrainingRules")
    local PhotoRules = H.require(SHARED .. "Photo.PhotoRules")
    local RadioRules = H.require(SHARED .. "Audio.RadioRules")
    local EngineAudioModel = H.require(SHARED .. "Audio.EngineAudioModel")
    local AmbienceModel = H.require(SHARED .. "Audio.AmbienceModel")
    local AssetManifest = H.require(SHARED .. "Assets.AssetManifest")
    local ArtDirection = H.require(SHARED .. "Art.ArtDirection")
    local PassengerRules = H.require(SHARED .. "Vehicles.PassengerRules")
    local Localization = H.require(SHARED .. "UI.Localization")
    local Preferences = H.require(SHARED .. "UI.Preferences")
    local InputMap = H.require(SHARED .. "UI.InputMap")
    local ProfileSchema = H.require(SERVER .. "Persistence.ProfileSchema")
    local ProfileMigration = H.require(SERVER .. "Persistence.ProfileMigration")
    local StarterSelection = H.require(SERVER .. "Progression.StarterSelection")
    local PropertyRules = H.require(SERVER .. "Progression.PropertyRules")
    local VehicleOwnership = H.require(SERVER .. "Progression.VehicleOwnership")

    local function prepare(modelId: string): (number?, any)
        local definition = Definitions.get(modelId)
        if definition == nil then
            return nil, nil
        end
        return definition.Powertrain.Energy.InitialFraction, CosmeticCatalog.defaults(definition)
    end

    local function count(map: any): number
        local n = 0
        for _ in map do
            n += 1
        end
        return n
    end

    T.suite("Lot BASE-01 — gamme réduite à la Comète (décision du propriétaire du 2026-11-05)")

    -- Lot VEH3D-02 : la Brio (citadine) rejoint la Comète ; l'identifiant `wk_brio` de l'ancienne gamme proposée est
    -- repris pour la nouvelle définition (aucun profil réel ne la possédait : jamais achetable hors Dev).
    T.test("1. registre : la Comète et la Brio, sans prototype ni modèle retiré, textes FR/EN", function()
        local ids = {}
        for _, definition in Definitions.all() do
            table.insert(ids, definition.Id)
        end
        T.equal(table.concat(ids, ","), "wk_comete,wk_brio", "modèles enregistrés")
        for _, retired in { "proto_p01", "proto_p02", "proto_p03", "proto_p01_dct", "wk_aster", "wk_atlas" } do
            T.truthy(Definitions.get(retired) == nil, retired .. " : retiré du jeu")
        end
        for _, id in ids do
            for _, suffix in { ".category", ".desc" } do
                T.truthy(Localization.has("vehicle." .. id .. suffix), id .. suffix .. " FR/EN")
            end
        end
    end)

    T.test("2. compatibilité physique : la Comète passe la validation et atteint sa vitesse", function()
        local definition = Definitions.get("wk_comete")
        local ok, errors = Definitions.validate(definition)
        T.truthy(ok, table.concat(errors, " ; "))
        T.equal(definition.Powertrain.Energy.Kind, "Petrol")
        -- Lot AUDIO-02 (décision du propriétaire, 2026-11-06) : double embrayage, comme la McLaren 720S.
        T.equal(definition.Powertrain.Transmission.Kind, "DualClutch")
        T.truthy(Definitions.gearLimitedTopSpeedKmh(definition) >= 320 * 0.99, "démultiplication suffisante")
    end)

    T.test("3. catalogue : deux entrées liées (Comète, Brio), deux emplacements, jamais officielles", function()
        T.equal(#VehicleCatalog.Entries, 2)
        T.equal(VehicleCatalog.Slots, 2, "Comète et citadine")
        for index, id in { "wk_comete", "wk_brio" } do
            local entry = VehicleCatalog.Entries[index]
            T.equal(entry.DefinitionId, id)
            T.truthy(Definitions.get(entry.DefinitionId) ~= nil, "définition existante")
            T.truthy(entry.Price > 0 and #entry.Dealers >= 1, "prix et concession")
            T.truthy(entry.Availability ~= "Official", "aucune référence officielle")
        end
    end)

    T.test("4. actifs provisoires séparés des officiels : achat en Dev seulement, aucun départ", function()
        for _, entry in VehicleCatalog.Entries do
            T.equal(entry.Availability, "PendingApproval", entry.Id)
            T.truthy(VehicleCatalog.purchasable(entry, "Dev"), entry.Id .. " : achetable en Dev")
            T.truthy(not VehicleCatalog.purchasable(entry, "Test"), entry.Id .. " : pas en test")
            T.truthy(not VehicleCatalog.purchasable(entry, "Production"), entry.Id .. " : pas en production")
        end
        T.equal(#StarterCatalog.Candidates, 0, "liste officielle vide")
        T.equal(#StarterCatalog.Proposed, 0, "aucune proposition (point P2)")
        for _, asset in AssetManifest.Assets do
            T.truthy(asset.Status ~= "Validated", asset.Id .. " : rien n'est validé à la place du propriétaire")
        end
    end)

    T.suite("Lot 0.8 — véhicule de départ et propriété")

    T.test("5. aucun véhicule de départ en attendant la citadine (point P2) : choix refusé partout", function()
        for _, environment in { "Dev", "Test", "Production" } do
            local list = StarterCatalog.candidates(environment)
            T.equal(#list, 0, environment .. " : aucun candidat")
            local profile = ProfileSchema.new(1, 0, environment)
            local ok, err = StarterSelection.choose(profile, "wk_comete", list, 0, prepare)
            T.truthy(not ok)
            T.equal(err, "StarterCatalogUnavailable", environment)
        end
    end)

    T.test("6. attribution unique : un exemplaire synthétique, incessible, non répétable", function()
        -- Liste explicite (règles de StarterSelection, indépendantes du catalogue) : le seul modèle du jeu.
        local dev = { "wk_comete" }
        local profile = ProfileSchema.new(2, 0, "Dev")
        local ok, result = StarterSelection.choose(profile, dev[1], dev, 10, prepare, true)
        T.truthy(ok, "premier choix")
        local again, err = StarterSelection.choose(profile, dev[1], dev, 11, prepare, true)
        T.truthy(not again)
        T.equal(err, "StarterAlreadyChosen")
        T.equal(count(profile.Vehicles), 1, "un seul exemplaire")
        local vehicle = profile.Vehicles[result.VehicleId]
        T.truthy(
            vehicle.Untransferable and vehicle.Synthetic and vehicle.Origin == "Starter",
            "incessible, synthétique"
        )
        T.truthy(not VehicleOwnership.transferableCopy(profile, vehicle.Id, 12), "ni vente ni transfert")
        local state = OnboardingRules.new()
        state.Step = "Choose"
        OnboardingRules.starterChosen(state, 10)
        T.equal(state.Step, "Property", "le parcours avance après la transaction")
    end)

    T.test("7. propriété gratuite unique, présentée par le parcours", function()
        local profile = ProfileSchema.new(3, 0, "Dev")
        T.truthy((PropertyRules.grantFree(profile, 1)), "attribuée")
        local again, err = PropertyRules.grantFree(profile, 2)
        T.truthy(not again)
        T.equal(err, "FreePropertyAlreadyGranted")
        T.equal(PropertyRules.count(profile), 1)
    end)

    T.test("8. parcours : passable, ordre imposé, choix réservé à la transaction, exercices sans gain", function()
        local state = OnboardingRules.new()
        T.equal(select(2, OnboardingRules.advance(state, "Phone", 1)), "OnboardingStepOrder", "pas de saut")
        for _, step in { "Welcome", "World", "Controls", "Phone", "Starters" } do
            T.truthy((OnboardingRules.advance(state, step, 1)), step)
        end
        T.equal(state.Step, "Choose")
        T.equal(select(2, OnboardingRules.advance(state, "Choose", 1)), "OnboardingChooseStarter")
        -- Aucun candidat (liste officielle vide hors Dev) : le joueur n'est pas bloqué.
        local blocked = OnboardingRules.new()
        blocked.Step = "Choose"
        T.truthy((OnboardingRules.advance(blocked, "Choose", 2, false)), "étape franchie sans candidat")
        T.equal(blocked.Step, "Property")
        local skippedEmpty = OnboardingRules.new()
        OnboardingRules.skip(skippedEmpty, false, 2, false)
        T.truthy(OnboardingRules.completed(skippedEmpty), "passer sans candidat : parcours terminé")
        local skipped = OnboardingRules.new()
        OnboardingRules.skip(skipped, false, 5)
        T.equal(skipped.Step, "Choose", "passer l'intro mène au choix, sans l'attribuer")
        OnboardingRules.skip(skipped, true, 6)
        T.truthy(OnboardingRules.completed(skipped), "terminé si le véhicule est déjà choisi")
        T.truthy((OnboardingRules.exercise(state, "Park", 3)), "exercice noté")
        T.equal(select(2, OnboardingRules.exercise(state, "Credits", 3)), "ExerciseUnknown")
        T.equal(#OnboardingRules.Exercises, 8)
        T.truthy(OnboardingRules.SpawnProtectionS <= 120, "protection d'apparition temporaire")
        -- Exercice « accélérer puis freiner » : observations successives.
        local progress = TrainingRules.start("AccelerateBrake", nil)
        local o = { T = 0, SpeedKmh = 55, Heading = 0, Gear = 3, X = 0, Z = 0, InVehicle = true }
        T.truthy(not TrainingRules.observe(progress, o))
        o.SpeedKmh = 1
        T.truthy(TrainingRules.observe(progress, o), "réussi")
        local park =
            TrainingRules.start("Park", { T = 0, SpeedKmh = 0, Heading = 0, Gear = 0, X = 0, Z = 0, InVehicle = true })
        local target = park.Target :: any
        local stop = { T = 1, SpeedKmh = 0, Heading = 0, Gear = 1, X = target.X, Z = target.Z, InVehicle = true }
        T.truthy(not TrainingRules.observe(park, stop))
        stop.T = 3.5
        T.truthy(TrainingRules.observe(park, stop), "stationné 2 s dans la place")
    end)

    T.test("9. isolation des essais : durée bornée, véhicule marqué, refusé par missions et courses", function()
        T.truthy(OnboardingRules.TestDriveS > 0 and OnboardingRules.TestDriveS <= 300, "durée bornée")
        local function source(path: string): string
            local node = H.game()
            for segment in string.gmatch(path, "[^%.]+") do
                node = node:FindFirstChild(segment)
            end
            return node.Source
        end
        local onboarding = source(SERVER .. "Onboarding.OnboardingService")
        T.truthy(
            string.find(onboarding, 'SetAttribute("AWTestDrive", true)', 1, true) ~= nil,
            "véhicule d'essai marqué"
        )
        T.truthy(
            string.find(source(SERVER .. "Racing.RaceService"), '"TestDriveNoRewards"', 1, true) ~= nil,
            "course refusée"
        )
        T.truthy(
            string.find(source(SERVER .. "Economy.MissionService"), 'GetAttribute("AWTestDrive")', 1, true) ~= nil,
            "mission sans progression"
        )
        local mission = source(SERVER .. "Economy.MissionService")
        T.truthy(
            string.find(mission, "Protected = true", 1, true) ~= nil,
            "véhicule temporaire protégé (aucune écriture durable)"
        )
        T.truthy(Localization.has("TestDriveNoRewards"), "refus traduit")
    end)

    T.suite("Lot 0.8 — mode photo, radio, audio")

    T.test("10. mode photo : contextes autorisés, caméra bornée, réglages limités", function()
        local function allowed(c: any): (boolean, string?)
            return PhotoRules.allowed(c)
        end
        T.truthy((allowed({ OnFoot = true, Seat = "None", SpeedKmh = 0, Racing = false })), "à pied")
        T.truthy((allowed({ OnFoot = false, Seat = "Driver", SpeedKmh = 0.5, Racing = false })), "conducteur arrêté")
        T.equal(
            select(2, allowed({ OnFoot = false, Seat = "Driver", SpeedKmh = 30, Racing = false })),
            "PhotoDriverMoving"
        )
        T.equal(
            select(2, allowed({ OnFoot = false, Seat = "Passenger", SpeedKmh = 30, Racing = false })),
            "PhotoPassengerMoving"
        )
        T.equal(select(2, allowed({ OnFoot = true, Seat = "None", SpeedKmh = 0, Racing = true })), "PhotoRacing")
        local subject = { X = 0, Y = 0, Z = 0 }
        local far = PhotoRules.clamp(subject, { X = 100, Y = 0, Z = 0 }, nil)
        T.near(far.X, PhotoRules.MaxRadiusM, 1e-6, "rayon borné")
        local wall = PhotoRules.clamp(subject, { X = 10, Y = 0, Z = 0 }, 4)
        T.truthy(wall.X < 4, "arrêtée avant l'obstacle (pas de traversée de mur)")
        local low = PhotoRules.clamp(subject, { X = 1, Y = -20, Z = 0 }, nil)
        T.truthy(low.Y >= PhotoRules.MinHeightM - 1e-6, "pas sous le sol")
        T.equal(PhotoRules.step(PhotoRules.Fov.Max, 50, PhotoRules.Fov), PhotoRules.Fov.Max, "zoom borné")
        for _, name in PhotoRules.Filters do
            T.truthy(Localization.has("photo.filter." .. name), name)
        end
    end)

    T.test("11. radio : volume et coupure par occupant, rien à l'extérieur", function()
        T.equal(RadioRules.ExteriorBroadcast, false, "aucune diffusion extérieure par défaut")
        T.equal(RadioRules.listenVolume("Passenger", "ville", false, 40), 0.4, "volume du passager")
        T.equal(RadioRules.listenVolume("Passenger", "ville", true, 40), 0, "coupée chez lui seulement")
        T.equal(RadioRules.listenVolume("Driver", "ville", false, 100), 1, "le conducteur garde son volume")
        T.equal(RadioRules.listenVolume("None", "ville", false, 100), 0, "hors du véhicule : rien")
        T.equal(RadioRules.listenVolume("Driver", RadioRules.Off, false, 100), 0)
        local prefs = Preferences.defaults()
        T.equal(prefs.Audio.RadioMuted, false)
        T.truthy(prefs.Audio.Radio >= 0 and prefs.Audio.Radio <= 100)
    end)

    T.test("12. station choisie par le conducteur ; indisponible sans pistes téléversées", function()
        local none = function(_: string): boolean
            return false
        end
        local all = function(_: string): boolean
            return true
        end
        T.equal(select(2, RadioRules.setStation("Passenger", "ville", all)), "RadioDriverOnly")
        T.equal(select(2, RadioRules.setStation("None", "ville", all)), "RadioDriverOnly")
        T.truthy((RadioRules.setStation("Driver", "ville", all)), "conducteur, pistes disponibles")
        T.equal(select(2, RadioRules.setStation("Driver", "ville", none)), "RadioStationUnavailable")
        T.equal(select(2, RadioRules.setStation("Driver", "inconnue", all)), "RadioStationUnknown")
        T.truthy((RadioRules.setStation("Driver", RadioRules.Off, none)), "toujours possible d'éteindre")
        for _, station in RadioRules.Stations do
            T.truthy(
                not RadioRules.available(station, AssetManifest.playable),
                station.Id .. " : indisponible aujourd'hui"
            )
            for _, track in station.Tracks do
                T.truthy(AssetManifest.get(track) ~= nil, track .. " : déclarée au manifeste (originale)")
            end
        end
    end)

    T.test("13. réglages audio, graphiques et accessibilité : catégories, migration v1 → v2, bornes", function()
        local old =
            Preferences.sanitize({ Version = 1, Audio = { Master = 80, Vehicles = 30, World = 20, Interface = 50 } })
        T.equal(old.Version, 2)
        T.equal(old.Audio.Engine, 30, "ancien volume véhicules repris")
        T.equal(old.Audio.Environment, 20, "ancien volume monde repris")
        T.equal(old.Audio.Interface, 50)
        for _, category in AmbienceModel.Categories do
            T.truthy(type((old.Audio :: any)[category]) == "number", category)
            T.truthy(Localization.has("settings.volume." .. category), category .. " traduit")
        end
        local dirty =
            Preferences.sanitize({ Audio = { Radio = 900, RadioMuted = "oui" }, Graphics = { Quality = "Ultra" } })
        T.equal(dirty.Audio.Radio, 100, "volume borné")
        T.equal(dirty.Audio.RadioMuted, false, "type invalide : défaut")
        T.equal(dirty.Graphics.Quality, "Medium", "qualité inconnue refusée")
        T.truthy(not dirty.Access.ReduceMotion and dirty.Access.VisualAlerts, "accessibilité : défauts sûrs")
        -- Couches moteur : électrique distinct, nombre de couches selon la qualité.
        local petrol = EngineAudioModel.combustion("Petrol", 2800, 0.5, false, "Low")
        local audible = 0
        for _, layer in petrol do
            T.truthy(string.find(layer.Id, "petrol", 1, true) ~= nil, layer.Id)
            T.truthy(layer.Speed >= EngineAudioModel.MinSpeed and layer.Speed <= EngineAudioModel.MaxSpeed)
            if layer.Volume > 0 then
                audible += 1
            end
        end
        T.truthy(audible <= 2, "qualité basse : deux couches au plus")
        for _, layer in EngineAudioModel.electric(0.5, 0.5, "High") do
            T.truthy(string.find(layer.Id, "electric", 1, true) ~= nil, "électrique sans couche thermique")
        end
        for _, layer in EngineAudioModel.combustion("Diesel", 900, 0, true, "High") do
            T.equal(layer.Volume, 0, "moteur calé : silence")
        end
        local mix = AmbienceModel.mix("Docks", 900, 12, 0)
        T.truthy(mix["audio.ambience.rain"] > 0 and mix["audio.ambience.harbour"] > 0, "zone + pluie")
        T.truthy(not InputMap.Reserved[InputMap.keyFor("Photo", {}) :: string], "touche photo libre")
        -- Qualité graphique : profils complets, éclairage sans effet sur l'adhérence.
        for _, quality in ArtDirection.Qualities do
            local profile = ArtDirection.profile(quality)
            T.truthy(
                profile.VehicleLightSources <= 8 and profile.StreetLightSources <= 24,
                quality .. " : sources limitées"
            )
        end
        T.truthy(
            ArtDirection.lightsOn(22, 0, 0) and not ArtDirection.lightsOn(13, 0.3, 0),
            "feux la nuit, pas en plein jour"
        )
        T.truthy(ArtDirection.lightsOn(13, 0.62, 0), "feux par brouillard")
    end)

    T.suite("Lot 0.8 — localisation, migrations, manifeste")

    T.test("14. localisation FR/EN : textes du lot et des panneaux des lots 0.4 à 0.6", function()
        for _, key in { "onb.title.Welcome", "onb.confirmChoice", "radio.mute", "photo.capture", "quality.High" } do
            T.truthy(Localization.has(key), key)
        end
        Localization.setLanguage("en")
        T.equal(Localization.t("onb.next"), "Next")
        T.equal(Localization.t("onb.choose", { name = "Brio" }), "Choose the Brio")
        Localization.setLanguage("fr")
        T.equal(Localization.t("onb.next"), "Suivant", "retour au français à chaud")
        -- Panneaux : chaque libellé tr("…") a sa traduction, avec les mêmes spécificateurs.
        local function specifiers(text: string): string
            local list = {}
            -- Sans drapeau « espace » : « 60 % du prix » est du texte, pas un spécificateur.
            for spec in string.gmatch(text, "%%[%-%+#0]*%d*%.?%d*[cdiouxXeEfgGqs%%]") do
                table.insert(list, spec)
            end
            return table.concat(list, ",")
        end
        local missing, mismatched, total = {}, {}, 0
        for _, name in { "GaragePanel", "EconomyPanel", "RacePanel", "AdminPanel" } do
            local node = H.game()
            for segment in string.gmatch(CLIENT .. "UI." .. name, "[^%.]+") do
                node = node:FindFirstChild(segment)
            end
            for literal in string.gmatch(node.Source, 'tr%(%s*"([^"]*)"') do
                total += 1
                local english = Localization.PanelTexts[literal]
                if english == nil then
                    table.insert(missing, name .. " : " .. literal)
                elseif specifiers(english) ~= specifiers(literal) then
                    table.insert(mismatched, literal)
                end
            end
        end
        T.truthy(total >= 150, "libellés des panneaux passés par tr() : " .. total)
        T.equal(#missing, 0, "sans traduction : " .. table.concat(missing, " | "))
        T.equal(#mismatched, 0, "spécificateurs différents : " .. table.concat(mismatched, " | "))
        Localization.setLanguage("en")
        T.truthy(Localization.tr("Rangé") ~= "Rangé" or Localization.PanelTexts["Rangé"] == nil, "repli contrôlé")
        Localization.setLanguage("fr")
    end)

    T.test("15. migrations : profil v4 → v5 (parcours), compatibilité des anciens profils", function()
        T.equal(ProfileSchema.Version, 5)
        local fresh = ProfileSchema.new(9, 0, "Dev")
        T.truthy(OnboardingRules.valid(fresh.Onboarding), "profil neuf : parcours à faire")
        T.equal(fresh.Onboarding.Step, "Welcome")
        local v4: any = ProfileMigration.deepCopy(fresh)
        v4.SchemaVersion = 4
        v4.Onboarding = nil
        v4.Starter = { State = "Chosen", ModelId = "wk_comete", VehicleId = "V1", ChosenAt = 1 }
        local migrated = ProfileMigration.migrate(v4)
        T.equal(migrated.Status, "Migrated")
        T.equal(migrated.Data.SchemaVersion, 5)
        T.truthy(
            OnboardingRules.completed(migrated.Data.Onboarding),
            "joueur existant : parcours terminé, pas imposé"
        )
        T.equal(v4.Onboarding, nil, "original intact")
        local newcomer: any = ProfileMigration.deepCopy(fresh)
        newcomer.SchemaVersion = 4
        newcomer.Onboarding = nil
        local second = ProfileMigration.migrate(newcomer)
        T.equal(second.Data.Onboarding.Step, "Welcome", "nouveau joueur : parcours proposé")
        T.truthy((ProfileSchema.validate(second.Data)), "profil valide")
    end)

    T.test("16. manifeste : aucune référence manquante ni inventée", function()
        local errors = AssetManifest.validate()
        T.equal(#errors, 0, table.concat(errors, " ; "))
        local audio, prefixes = 0, {}
        for _, asset in AssetManifest.Assets do
            -- Seules exceptions : les icônes du téléphone (lot UI-02, essai UiDesignSystem) et les sons de moteur de la
            -- Brio (lot AUDIO-01, essai Audio01), envoyés par le propriétaire.
            if
                string.sub(asset.Id, 1, 14) == "ui.icon.phone."
                or string.sub(asset.Id, 1, 18) == "audio.engine.brio."
                -- Sons du moteur de la Comète (lot AUDIO-02, essai Audio02), envoyés par le propriétaire.
                or string.sub(asset.Id, 1, 20) == "audio.engine.comete."
                -- Sons des pneus (lot AUDIO-03, essai Audio03), envoyés par le propriétaire.
                or string.sub(asset.Id, 1, 18) == "audio.effect.tire."
                -- Bruits de collision (lot AUDIO-04, essai Audio04), envoyés par le propriétaire.
                or string.sub(asset.Id, 1, 23) == "audio.effect.collision."
            then
                continue
            end
            T.equal(asset.RobloxAssetId, nil, asset.Id .. " : aucun identifiant Roblox inventé")
            T.equal(AssetManifest.contentId(asset.Id), nil, asset.Id .. " : non jouable")
            T.truthy(not AssetManifest.playable(asset.Id))
            -- Sons ENREGISTRÉS du lot AUDIO-01 (build/audio/engines/…) : contrôlés par la suite Audio01 ; sons des
            -- pneus du lot AUDIO-03 (build/audio/tires/…) : contrôlés par la suite Audio03.
            if
                asset.Category == "Audio"
                and string.sub(asset.Output or "", 1, 20) ~= "build/audio/engines/"
                and string.sub(asset.Output or "", 1, 18) ~= "build/audio/tires/"
                -- Bruits de collision du lot AUDIO-04 (build/audio/collisions/…) : contrôlés par la suite Audio04.
                and string.sub(asset.Output or "", 1, 23) ~= "build/audio/collisions/"
            then
                audio += 1
                T.truthy(
                    asset.Output ~= nil and string.match(asset.Output :: string, "^build/audio/[a-z_]+%.wav$") ~= nil,
                    asset.Id
                )
                prefixes[string.match(asset.Id, "^audio%.(%a+)")] = true
            end
        end
        T.equal(audio, 30, "30 sons, comme tools/audio/synth.py")
        for _, family in { "engine", "effect", "ambience", "ui", "radio" } do
            T.truthy(prefixes[family], family)
        end
        T.truthy(AssetManifest.get("veh.wk_comete.mesh720s") ~= nil, "carrosserie 3D de la Comète déclarée")
        T.truthy(AssetManifest.get("vehicle.body.prototype") ~= nil, "coque de repli déclarée")
        for zone in AmbienceModel.ZoneLoops do
            T.truthy(AssetManifest.get("world.decor." .. string.lower(zone)) ~= nil, zone .. " : habillage déclaré")
            T.truthy(AssetManifest.get(AmbienceModel.ZoneLoops[zone]) ~= nil, zone .. " : ambiance déclarée")
        end
        -- Les identifiants utilisés par l'audio existent tous au manifeste.
        for _, layer in EngineAudioModel.combustion("Petrol", 3000, 1, false, "High") do
            T.truthy(AssetManifest.get(layer.Id) ~= nil, layer.Id)
        end
        for _, layer in EngineAudioModel.combustion("Diesel", 3000, 1, false, "High") do
            T.truthy(AssetManifest.get(layer.Id) ~= nil, layer.Id)
        end
        for _, layer in EngineAudioModel.electric(1, 1, "High") do
            T.truthy(AssetManifest.get(layer.Id) ~= nil, layer.Id)
        end
        for id in AmbienceModel.mix("Littoral", 900, 12, 200) do
            T.truthy(AssetManifest.get(id) ~= nil, id)
        end
    end)

    T.test("17. place passager : propriétaire ou groupe, jamais le conducteur", function()
        local groups = { [1] = "A", [2] = "A", [3] = "B" }
        local same = function(a: number, b: number): boolean
            return groups[a] ~= nil and groups[a] == groups[b]
        end
        local ride = function(owner: number?, driver: number?, rider: number): (boolean, string?)
            return PassengerRules.mayRide({ OwnerUserId = owner, DriverUserId = driver, RiderUserId = rider }, same)
        end
        T.truthy((ride(1, nil, 1)), "propriétaire")
        T.truthy((ride(1, nil, 2)), "groupe du propriétaire")
        T.equal(select(2, ride(1, nil, 3)), "PassengerNotAllowed", "inconnu refusé")
        T.equal(select(2, ride(1, 1, 1)), "PassengerIsDriver")
        T.truthy((ride(nil, nil, 3)), "parc d'essai sans conducteur")
        T.equal(select(2, ride(nil, 1, 3)), "PassengerNotAllowed", "pas d'auto-stop chez un inconnu")
        T.truthy(Localization.has("PassengerNotAllowed"))
    end)
end
