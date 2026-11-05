--!strict
local Fixtures = require("../fixtures/Fixtures")
-- Lot 0.4 — progression : starter, propriétés, garages, collection,
-- personnalisation, configurations, invitations, état durable, contrats
-- économiques et cohérence avec les identifiants de la carte du lot 0.3.
-- Données SYNTHÉTIQUES ; adaptateur mémoire ; aucun service Roblox.

local SERVER = "ServerScriptService.AutomotiveWorldServer."
local SHARED = "ReplicatedStorage.Shared."

return function(T: any, H: any)
    local ProfileSchema = H.require(SERVER .. "Persistence.ProfileSchema")
    local ProfileRepository = H.require(SERVER .. "Persistence.ProfileRepository")
    local MemoryProfileRepository = H.require(SERVER .. "Persistence.MemoryProfileRepository")
    local ProfileSession = H.require(SERVER .. "Persistence.ProfileSession")
    local TransactionService = H.require(SERVER .. "Persistence.TransactionService")
    local VehicleOwnership = H.require(SERVER .. "Progression.VehicleOwnership")
    local StarterSelection = H.require(SERVER .. "Progression.StarterSelection")
    local PropertyRules = H.require(SERVER .. "Progression.PropertyRules")
    local GarageRules = H.require(SERVER .. "Progression.GarageRules")
    local Customization = H.require(SERVER .. "Progression.Customization")
    local InvitationRules = H.require(SERVER .. "Progression.InvitationRules")
    local DurableState = H.require(SERVER .. "Progression.DurableState")
    local StarterCatalog = H.require(SHARED .. "Garage.StarterCatalog")
    local PropertyCatalog = H.require(SHARED .. "Garage.PropertyCatalog")
    local GarageModules = H.require(SHARED .. "Garage.GarageModules")
    local TuningRules = H.require(SHARED .. "Garage.TuningRules")
    local CosmeticCatalog = H.require(SHARED .. "Garage.CosmeticCatalog")
    local PartCatalog = H.require(SHARED .. "Garage.PartCatalog")
    local EconomyContracts = H.require(SHARED .. "Garage.EconomyContracts")
    local Definitions = H.require(SHARED .. "Vehicles.VehicleDefinitions")
    local Infrastructure = H.require(SHARED .. "World.Data.Infrastructure")

    local USER = 777
    local P01 = Fixtures.get("proto_p01")
    local P03 = Fixtures.get("proto_p03")
    local PUBLIC = GarageModules.publicCapabilities()
    local PRIVATE = GarageModules.privateCapabilities({})
    -- Liste SYNTHÉTIQUE pour éprouver le processus (jamais utilisée en jeu).
    local SYNTHETIC_STARTERS = { "proto_p01", "proto_p02", "proto_p03" }

    local function prepare(modelId: string): (number?, any)
        -- Jeux d'essai (lot BASE-01) : les prototypes ne sont plus dans le registre du jeu.
        local definition = Definitions.get(modelId) or Fixtures.get(modelId)
        if definition == nil then
            return nil, nil
        end
        return definition.Powertrain.Energy.InitialFraction, CosmeticCatalog.defaults(definition)
    end

    local function newProfile(): any
        return ProfileSchema.new(USER, 0, "Dev")
    end

    local function addVehicle(profile: any, modelId: string?): string
        return VehicleOwnership.add(profile, {
            ModelId = modelId or "proto_p01",
            Origin = "DevSynthetic",
            Untransferable = false,
            Synthetic = true,
            EnergyFraction = 0.6,
            Cosmetics = CosmeticCatalog.defaults(P01),
        }, 0)
    end

    local function addPart(profile: any, partId: string): string
        local id = ProfileSchema.nextId(profile, "Part", "PT")
        profile.Parts[id] = { Id = id, PartId = partId, AcquiredAt = 0, Origin = "DevSynthetic", Synthetic = true }
        return id
    end

    local function sessionHarness()
        local clock = { Now = 100 }
        local repo = MemoryProfileRepository.new()
        local counter = 0
        local function open(name: string): any
            local session = ProfileSession.new({
                Repository = repo,
                Key = ProfileRepository.keyFor(USER),
                UserId = USER,
                Session = name,
                Server = name,
                Environment = "Dev",
                Clock = function()
                    return clock.Now
                end,
                Token = function()
                    counter += 1
                    return "t" .. counter
                end,
                MinWriteInterval = 6,
            })
            session:load()
            return session
        end
        return clock, repo, open
    end

    T.suite("Lot 0.4 — véhicule gratuit de départ")

    T.test("liste officielle vide : choix refusé, aucun prototype attribué", function()
        T.equal(#StarterCatalog.Candidates, 0)
        T.truthy(not StarterCatalog.available(), "indisponible")
        local profile = newProfile()
        local ok, err = StarterSelection.choose(profile, "proto_p01", StarterCatalog.Candidates, 0, prepare)
        T.truthy(not ok, "refusé")
        T.equal(err, "StarterCatalogUnavailable")
        T.equal(next(profile.Vehicles), nil)
    end)

    T.test("choix synthétique : un seul exemplaire incessible, même avec double clic et reconnexion", function()
        local clock, repo, open = sessionHarness()
        local a = open("A")
        clock.Now += 7
        local function choose(session: any, modelId: string): any
            return session:commit(StarterSelection.TxId, "Starter", function(profile)
                return StarterSelection.choose(profile, modelId, SYNTHETIC_STARTERS, clock.Now, prepare)
            end)
        end
        local first = choose(a, "proto_p02")
        T.equal(first.Status, "Confirmed")
        local double = choose(a, "proto_p03")
        T.equal(double.Status, "Duplicate")
        T.equal(double.Result.ModelId, "proto_p02", "réponse d'origine")
        clock.Now += 10
        a:save(true)
        local b = open("B")
        clock.Now += 7
        T.equal(choose(b, "proto_p01").Status, "Duplicate")
        local count, vehicle = 0, nil
        for _, item in b.Data.Vehicles do
            count += 1
            vehicle = item
        end
        T.equal(count, 1)
        T.truthy(vehicle.Untransferable and vehicle.Origin == "Starter", "incessible")
        T.equal(b.Data.Starter.State, "Chosen")
        local transferable = VehicleOwnership.transferableCopy(b.Data, vehicle.Id, clock.Now)
        T.truthy(not transferable, "ni vente ni transfert")
        T.equal(repo.Store[ProfileRepository.keyFor(USER)].Data.Starter.ModelId, "proto_p02")
    end)

    T.test("choix hors liste refusé", function()
        local profile = newProfile()
        local ok, err = StarterSelection.choose(profile, "inconnu", SYNTHETIC_STARTERS, 0, prepare)
        T.truthy(not ok)
        T.equal(err, "StarterNotCandidate")
    end)

    T.suite("Lot 0.4 — propriétés")

    T.test("propriété gratuite attribuée une fois, invendable, comptée dans le plafond de cinq", function()
        local clock, _, open = sessionHarness()
        local a = open("A")
        clock.Now += 7
        local grant = function(session: any): any
            return session:commit(PropertyRules.FreeGrantTxId, "FreeProperty", function(profile)
                return PropertyRules.grantFree(profile, clock.Now)
            end)
        end
        T.equal(grant(a).Status, "Confirmed")
        T.equal(grant(a).Status, "Duplicate")
        -- Même si le journal ne contenait plus la transaction : l'état la protège.
        a.Data.Transactions[PropertyRules.FreeGrantTxId] = nil
        clock.Now += 7
        local again = grant(a)
        T.equal(again.Status, "Rejected")
        T.equal(again.Error, "FreePropertyAlreadyGranted")
        local profile = a.Data
        T.equal(PropertyRules.count(profile), 1)
        local free = profile.Properties[profile.Grants.FreeProperty.Ref]
        T.truthy(not free.Sellable, "invendable")
        T.equal(free.Category, "Small")
        T.equal(select(2, PropertyRules.release(profile, free.Id)), "PropertyNotSellable")
        for i = 1, 4 do
            T.truthy((PropertyRules.acquire(profile, "RES-METRO-LOFTS", "DevSynthetic", true, i)), "acquisition " .. i)
        end
        local ok, err = PropertyRules.acquire(profile, "RES-METRO-PARC", "DevSynthetic", true, 9)
        T.truthy(not ok)
        T.equal(err, "PropertyLimit", "sixième refusée")
        T.equal(
            select(2, PropertyRules.acquire(profile, PropertyCatalog.StarterOfferId, "Purchase", false, 9)),
            "PropertyStarterOfferNotForSale"
        )
    end)

    T.test("capacités par catégorie et agrandissement borné", function()
        T.equal(PropertyCatalog.capacity("Small", 0), 1)
        T.equal(PropertyCatalog.capacity("Small", 5), 2)
        T.equal(PropertyCatalog.capacity("Medium", 0), 3)
        T.equal(PropertyCatalog.capacity("Medium", 2), 5)
        T.equal(PropertyCatalog.capacity("Prestige", 0), 6)
        T.equal(PropertyCatalog.capacity("Prestige", 4), 10)
        local profile = newProfile()
        PropertyRules.grantFree(profile, 0)
        local id = profile.Grants.FreeProperty.Ref
        T.truthy((PropertyRules.upgradeGarage(profile, id)), "niveau 1")
        T.equal(select(2, PropertyRules.upgradeGarage(profile, id)), "GarageMaxLevel")
    end)

    T.suite("Lot 0.4 — garages et collection")

    T.test("collection sans limite liée aux places ; exposition bornée par la capacité", function()
        local profile = newProfile()
        PropertyRules.grantFree(profile, 0)
        local home = profile.Grants.FreeProperty.Ref
        local ids = {}
        for i = 1, 300 do
            ids[i] = addVehicle(profile)
        end
        T.truthy((ProfileSchema.validate(profile)), "300 exemplaires valides")
        T.truthy((GarageRules.display(profile, ids[1], home, 1, 0)), "place 1")
        T.equal(select(2, GarageRules.display(profile, ids[2], home, 1, 0)), "SlotOccupied")
        T.equal(select(2, GarageRules.display(profile, ids[2], home, 2, 0)), "SlotOutOfRange")
        local page, pages = VehicleOwnership.page(profile, 2, 20)
        T.equal(#page, 20)
        T.equal(pages, 15)
        T.truthy(ProfileSchema.estimateSize(profile) < ProfileSchema.SoftLimitBytes, "loin de la limite technique")
        T.note(
            string.format(
                "Taille estimée d'un profil de 300 exemplaires : %d octets",
                ProfileSchema.estimateSize(profile)
            )
        )
    end)

    T.test("un exemplaire n'est jamais sorti deux fois ; exposition impossible pendant la sortie", function()
        local profile = newProfile()
        PropertyRules.grantFree(profile, 0)
        local home = profile.Grants.FreeProperty.Ref
        local a, b = addVehicle(profile), addVehicle(profile)
        GarageRules.display(profile, a, home, 1, 0)
        T.truthy((GarageRules.takeOut(profile, a, "S1", 0)), "sortie")
        T.equal(select(2, GarageRules.takeOut(profile, a, "S2", 0)), "VehicleOut")
        T.equal(select(2, GarageRules.takeOut(profile, b, "S1", 0)), "AnotherVehicleOut")
        T.equal(select(2, GarageRules.display(profile, a, home, 1, 0)), "VehicleOut")
        T.truthy((GarageRules.display(profile, b, home, 1, 0)), "place libérée par la sortie")
        local _, back = GarageRules.bringBack(profile, a, 0)
        T.equal(back.State, "Stored", "place reprise entre-temps : rangé")
        T.truthy((ProfileSchema.validate(profile)), "cohérent")
    end)

    T.test("au rechargement, un exemplaire resté sorti revient et les réservations échues tombent", function()
        local profile = newProfile()
        PropertyRules.grantFree(profile, 0)
        local home = profile.Grants.FreeProperty.Ref
        local a = addVehicle(profile)
        GarageRules.display(profile, a, home, 1, 0)
        GarageRules.takeOut(profile, a, "ServeurDisparu", 0)
        T.truthy((VehicleOwnership.reserve(profile, a, "Race", "tx", 0, 60)), "réservé")
        T.truthy(GarageRules.normalize(profile, 100), "modifié")
        T.equal(profile.Vehicles[a].Storage.State, "Displayed")
        T.truthy(profile.Vehicles[a].Reservation == nil, "réservation échue levée")
    end)

    T.test("réservation : opérations incompatibles refusées (AUD-RACE-02)", function()
        local profile = newProfile()
        local a = addVehicle(profile)
        VehicleOwnership.reserve(profile, a, "Race", "tx-1", 0, 600)
        T.equal(select(2, GarageRules.takeOut(profile, a, "S", 10)), "VehicleReserved")
        T.equal(select(2, Customization.setTuning(profile, a, {}, P01, PUBLIC, 10)), "VehicleReserved")
        T.equal(select(2, VehicleOwnership.reserve(profile, a, "Sale", "tx-2", 10, 60)), "VehicleReserved")
        T.truthy(VehicleOwnership.clearReservation(profile, a, "tx-1"), "levée par sa transaction")
    end)

    T.test("cession d'une propriété : véhicules exposés rangés, collection intacte", function()
        local profile = newProfile()
        local _, paid = PropertyRules.acquire(profile, "RES-METRO-LOFTS", "DevSynthetic", true, 0)
        local a = addVehicle(profile)
        GarageRules.display(profile, a, paid, 3, 0)
        local ok, result = PropertyRules.release(profile, paid)
        T.truthy(ok)
        T.equal(result.Moved, 1)
        T.equal(profile.Vehicles[a].Storage.State, "Stored")
        T.truthy((ProfileSchema.validate(profile)), "cohérent")
    end)

    T.suite("Lot 0.4 — préparation mécanique et esthétique")

    T.test(
        "réglages : valeurs par défaut = définition d'origine ; bornes revalidées pour chaque prototype",
        function()
            for _, definition in Definitions.all() do
                local ranges = TuningRules.ranges(definition, {})
                local defaults = {}
                for key, range in ranges do
                    defaults[key] = range.Default
                end
                T.truthy((TuningRules.validate(definition, defaults, {})), definition.Id .. " valeurs par défaut")
                -- Chaque réglage seul à ses deux bornes : définition dérivée valide.
                for key, range in ranges do
                    for _, value in { range.Min, range.Max } do
                        local tuning = { [key] = value }
                        local ok, errors = TuningRules.validate(definition, tuning, {})
                        T.truthy(
                            ok,
                            string.format(
                                "%s %s=%s : %s",
                                definition.Id,
                                key,
                                tostring(value),
                                table.concat(errors, " ")
                            )
                        )
                    end
                end
                local same = TuningRules.apply(definition, defaults, {})
                T.near(same.Suspension.Front.SpringRateNpm, definition.Suspension.Front.SpringRateNpm, 1e-6)
                T.near(same.Brakes.MaxTorqueFrontNm, definition.Brakes.MaxTorqueFrontNm, 1e-6)
            end
        end
    )

    T.test("combinaison irréalisable refusée (ressorts souples + caisse abaissée)", function()
        local P02 = Fixtures.get("proto_p02")
        local ok, errors = TuningRules.validate(P02, { SpringFront = 0.85, SpringRear = 0.85, RideHeight = -0.02 }, {})
        T.truthy(not ok, "refusée")
        T.equal(errors[1], "TuningUnrealizable")
    end)

    T.test("réglage hors plage ou inconnu refusé (jamais ramené en silence)", function()
        local ok, errors = TuningRules.validate(P01, { SpringFront = 3 }, {})
        T.truthy(not ok)
        T.equal(errors[1], "TuningOutOfRange:SpringFront")
        T.truthy(not (TuningRules.validate(P01, { Turbo = 1 }, {})), "inconnu")
        -- Blocage de différentiel : seulement avec un autobloquant.
        T.truthy(not (TuningRules.validate(P01, { DiffPowerLock = 0.3 }, {})), "P-01 ouvert")
        T.truthy(
            (TuningRules.validate(P01, { DiffPowerLock = 0.3 }, { RearDifferential = "DIFF-LSD-REAR" })),
            "avec autobloquant"
        )
        T.truthy(not (TuningRules.validate(P03, { ShiftUpRpm = 6000 }, {})), "électrique : pas de loi de passage")
    end)

    T.test(
        "pièces : posées depuis une pièce détachée possédée, jamais dupliquées, garage public requis",
        function()
            local profile = newProfile()
            local a, b = addVehicle(profile), addVehicle(profile)
            T.equal(select(2, Customization.setPart(profile, a, "Tires", "TIRE-SPORT", P01, PUBLIC, 0)), "PartNotOwned")
            local item = addPart(profile, "TIRE-SPORT")
            T.equal(
                select(2, Customization.setPart(profile, a, "Tires", "TIRE-SPORT", P01, PRIVATE, 0)),
                "CapabilityMissing:SwapParts"
            )
            T.truthy((Customization.setPart(profile, a, "Tires", "TIRE-SPORT", P01, PUBLIC, 0)), "posée")
            T.equal(profile.Parts[item].InstalledOn, a)
            T.equal(select(2, Customization.setPart(profile, b, "Tires", "TIRE-SPORT", P01, PUBLIC, 0)), "PartNotOwned")
            T.equal(
                select(2, Customization.setPart(profile, a, "FrontDifferential", "DIFF-LSD-FRONT", P01, PUBLIC, 0)),
                "PartIncompatible"
            )
            T.truthy((Customization.setPart(profile, a, "Tires", nil, P01, PUBLIC, 0)), "déposée")
            T.truthy(profile.Parts[item].InstalledOn == nil, "redevenue détachée")
            T.truthy((ProfileSchema.validate(profile)), "cohérent")
        end
    )

    T.test("pièce déposée : réglages devenus irréalisables retirés", function()
        local profile = newProfile()
        local a = addVehicle(profile)
        addPart(profile, "DIFF-LSD-REAR")
        Customization.setPart(profile, a, "RearDifferential", "DIFF-LSD-REAR", P01, PUBLIC, 0)
        T.truthy((Customization.setTuning(profile, a, { DiffPowerLock = 0.4 }, P01, PUBLIC, 0)), "réglé")
        Customization.setPart(profile, a, "RearDifferential", nil, P01, PUBLIC, 0)
        T.truthy(profile.Vehicles[a].Tuning.DiffPowerLock == nil, "retiré")
    end)

    T.test("esthétique : catalogue validé, apparence dérivée sans dupliquer la géométrie", function()
        local cosmetics = CosmeticCatalog.defaults(P01)
        cosmetics.BodyColor = "Rouge"
        cosmetics.Accessories = { "RoofRack" }
        T.truthy((CosmeticCatalog.validate(cosmetics)), "valide")
        local appearance = CosmeticCatalog.appearance(P01.Appearance, cosmetics)
        T.equal(appearance.BodyRgb[1], 176)
        T.equal(appearance.TrimRgb, P01.Appearance.TrimRgb)
        cosmetics.BodyColor = "Fuchsia"
        T.truthy(not (CosmeticCatalog.validate(cosmetics)), "couleur inconnue")
        local profile = newProfile()
        local a = addVehicle(profile)
        T.equal(
            select(2, Customization.setCosmetics(profile, a, CosmeticCatalog.defaults(P01), PRIVATE, 0)),
            "CapabilityMissing:EditCosmetics"
        )
        T.truthy((Customization.setCosmetics(profile, a, CosmeticCatalog.defaults(P01), PUBLIC, 0)), "garage public")
    end)

    T.suite("Lot 0.4 — configurations (AUD-ECO-02, SCN-04)")

    T.test("cinq configurations au plus, sans duplication de pièces", function()
        local profile = newProfile()
        local a = addVehicle(profile)
        local sport = addPart(profile, "TIRE-SPORT")
        for i = 1, 5 do
            T.truthy((Customization.saveConfiguration(profile, a, i, "Profil " .. i, i)), "configuration " .. i)
        end
        T.equal(select(2, Customization.saveConfiguration(profile, a, 6, "Trop", 6)), "ConfigIndex")
        Customization.setPart(profile, a, "Tires", "TIRE-SPORT", P01, PUBLIC, 7)
        Customization.setTuning(profile, a, { SpringFront = 1.1 }, P01, PUBLIC, 7)
        T.truthy((Customization.saveConfiguration(profile, a, 2, "Sport", 8)), "écrasée")
        -- Basculer entre configurations ne crée aucune pièce.
        T.truthy((Customization.applyConfiguration(profile, a, 1, P01, PUBLIC, 9)), "configuration de série")
        T.truthy(profile.Parts[sport].InstalledOn == nil, "pièce détachée")
        T.truthy((Customization.applyConfiguration(profile, a, 2, P01, PUBLIC, 10)), "configuration sport")
        T.equal(profile.Parts[sport].InstalledOn, a)
        local count = 0
        for _ in profile.Parts do
            count += 1
        end
        T.equal(count, 1, "toujours une seule pièce")
        T.equal(profile.Vehicles[a].Tuning.SpringFront, 1.1)
    end)

    T.test(
        "configuration dont la pièce manque ou est ailleurs : refusée ; garage privé sans échange de pièces",
        function()
            local profile = newProfile()
            local a, b = addVehicle(profile), addVehicle(profile)
            addPart(profile, "TIRE-SPORT")
            Customization.setPart(profile, a, "Tires", "TIRE-SPORT", P01, PUBLIC, 0)
            Customization.saveConfiguration(profile, a, 1, "Sport", 0)
            -- Même configuration copiée sur b : la pièce est installée sur a.
            profile.Vehicles[b].Configurations[1] = table.clone(profile.Vehicles[a].Configurations[1])
            T.equal(select(2, Customization.applyConfiguration(profile, b, 1, P01, PUBLIC, 1)), "ConfigPartsMissing")
            Customization.setPart(profile, a, "Tires", nil, P01, PUBLIC, 1)
            T.equal(select(2, Customization.applyConfiguration(profile, a, 1, P01, PRIVATE, 2)), "ConfigNeedsPartSwap")
            Customization.saveConfiguration(profile, a, 2, "Série", 3)
            T.truthy(
                (Customization.applyConfiguration(profile, a, 2, P01, PRIVATE, 4)),
                "réglages seuls au garage privé"
            )
        end
    )

    T.test(
        "vente future : pièces installées suivent, configurations réalisables seulement, pièces détachées au vendeur",
        function()
            local profile = newProfile()
            local a = VehicleOwnership.add(profile, {
                ModelId = "proto_p01",
                Origin = "Purchase",
                Untransferable = false,
                Synthetic = false,
                EnergyFraction = 0.5,
                Cosmetics = CosmeticCatalog.defaults(P01),
            }, 0)
            addPart(profile, "TIRE-SPORT")
            addPart(profile, "BRAKE-SPORT")
            Customization.setPart(profile, a, "Tires", "TIRE-SPORT", P01, PUBLIC, 0)
            Customization.saveConfiguration(profile, a, 1, "Pneus", 0)
            Customization.setPart(profile, a, "Brakes", "BRAKE-SPORT", P01, PUBLIC, 0)
            Customization.saveConfiguration(profile, a, 2, "Pneus + freins", 0)
            Customization.setPart(profile, a, "Brakes", nil, P01, PUBLIC, 0)
            local ok, copy = VehicleOwnership.transferableCopy(profile, a, 0)
            T.truthy(ok)
            T.equal(#copy.Vehicle.Configurations, 1, "seule la configuration réalisable")
            T.truthy(copy.Parts.Tires ~= nil and copy.Parts.Brakes == nil, "pièce installée seulement")
        end
    )

    T.suite("Lot 0.4 — invitations")

    T.test("visite et conduite séparées, expiration, révocation, groupes inactifs", function()
        local profile = newProfile()
        PropertyRules.grantFree(profile, 0)
        local home = profile.Grants.FreeProperty.Ref
        local _, other = PropertyRules.acquire(profile, "RES-METRO-LOFTS", "DevSynthetic", true, 0)
        local ok, invite = InvitationRules.create(profile, home, 99, true, false, 600, 0)
        T.truthy(ok)
        T.truthy(InvitationRules.allows(profile, home, 99, "Visit", 10), "visite")
        T.truthy(not InvitationRules.allows(profile, other, 99, "Visit", 10), "autre propriété")
        T.truthy(not InvitationRules.allows(profile, home, 99, "Drive", 10), "pas de conduite")
        T.truthy(not InvitationRules.allows(profile, home, 98, "Visit", 10), "inconnu refusé")
        T.truthy(not InvitationRules.allows(profile, home, 99, "Visit", 601), "expirée")
        InvitationRules.revoke(profile, invite.InvitationId)
        T.truthy(not InvitationRules.allows(profile, home, 99, "Visit", 10), "révoquée")
        T.equal(select(2, InvitationRules.create(profile, home, USER, true, false, 600, 0)), "InviteSelf")
        T.equal(select(2, InvitationRules.create(profile, home, 99, false, false, 600, 0)), "InviteRights")
        local sources = { InvitationRules.InvitationSource, InvitationRules.GroupSource }
        InvitationRules.create(profile, home, 55, false, true, 600, 0)
        T.truthy(InvitationRules.check(sources, profile, nil, 55, "Drive", 1), "conduite accordée")
        T.truthy(not InvitationRules.GroupSource.allows(profile, home, 55, "Visit", 1), "groupes : lot 0.7")
    end)

    T.suite("Lot 0.4 — état durable (dégâts, énergie, kilométrage)")

    T.test("réconciliation monotone ; session protégée sans effet", function()
        local profile = newProfile()
        local a = addVehicle(profile)
        local vehicle = profile.Vehicles[a]
        local damage = ProfileSchema.pristineDamage()
        damage.Zones.Front = 0.4
        damage.Engine = 0.8
        local runtime = {
            EnergyFraction = 0.5,
            Damage = damage,
            DistanceKm = 1,
            ElapsedS = 60,
            MaxSpeedKmh = 200,
            Protected = false,
        }
        T.truthy(DurableState.reconcile(vehicle, runtime, 1), "modifié")
        T.equal(vehicle.Energy, 0.5)
        T.equal(vehicle.Damage.Zones.Front, 0.4)
        -- Une valeur « meilleure » (recharge ou réparation gratuites) est ignorée.
        local repaired = ProfileSchema.pristineDamage()
        DurableState.reconcile(vehicle, {
            EnergyFraction = 0.9,
            Damage = repaired,
            DistanceKm = 0,
            ElapsedS = 0,
            MaxSpeedKmh = 200,
            Protected = false,
        }, 2)
        T.equal(vehicle.Energy, 0.5)
        T.equal(vehicle.Damage.Zones.Front, 0.4)
        T.equal(vehicle.Damage.Engine, 0.8)
        -- Distance bornée par la vitesse plausible (200 km/h × 1,2 × 60 s = 4 km).
        DurableState.reconcile(vehicle, {
            EnergyFraction = 0.5,
            Damage = damage,
            DistanceKm = 50,
            ElapsedS = 60,
            MaxSpeedKmh = 200,
            Protected = false,
        }, 3)
        T.near(vehicle.OdometerKm, 1 + 4, 1e-6)
        local before = vehicle.OdometerKm
        T.truthy(not DurableState.reconcile(vehicle, {
            EnergyFraction = 0,
            Damage = damage,
            DistanceKm = 3,
            ElapsedS = 60,
            MaxSpeedKmh = 200,
            Protected = true,
        }, 4), "protégée")
        T.equal(vehicle.OdometerKm, before)
        T.equal(vehicle.Energy, 0.5)
    end)

    T.suite("Lot 0.4 — contrats économiques et monde")

    T.test("ratios approuvés ; opérations économiques déclarées", function()
        T.equal(EconomyContracts.Ratios.DealerTradeIn, 0.6)
        T.equal(EconomyContracts.Ratios.DetachedPartResale, 0.75)
        T.equal(EconomyContracts.Ratios.PropertyResale, 0.7)
        T.equal(EconomyContracts.Ratios.ExtensionResale, 0.4)
        T.equal(EconomyContracts.Ratios.ModuleResale, 0.6)
        T.equal(EconomyContracts.Ratios.PlayerMarketCommission, 0.05)
        -- Lot 0.5 : opérations implémentées (contenu de travail réservé au développement).
        for _, operation in EconomyContracts.Operations do
            T.truthy(EconomyContracts.available(operation), operation)
        end
        T.truthy(not EconomyContracts.available("Inconnue"), "opération inconnue")
        T.equal(EconomyContracts.dealerTradeIn(10000, 1), 6000)
        T.equal(EconomyContracts.detachedPartResale(1000, true), 750)
        T.equal(EconomyContracts.playerSaleNet(1000), 950)
    end)

    T.test("chaque offre de propriété est reliée à un emplacement de la carte du lot 0.3", function()
        local byId = {}
        for _, item in Infrastructure do
            byId[item.Id] = item
        end
        local entrances = {}
        for _, offer in PropertyCatalog.Offers do
            local placement = byId[offer.Entrance]
            T.truthy(placement ~= nil, offer.Id .. " → " .. offer.Entrance)
            if placement then
                T.truthy(placement.Kind == "PropertySlot" or placement.Kind == "ResidentialGarageSlot", offer.Entrance)
            end
            entrances[offer.Entrance] = true
        end
        for _, item in Infrastructure do
            if item.Kind == "PropertySlot" or item.Kind == "ResidentialGarageSlot" then
                T.truthy(entrances[item.Id], "emplacement utilisé : " .. item.Id)
            end
        end
        local starter = PropertyCatalog.offer(PropertyCatalog.StarterOfferId)
        T.truthy(starter ~= nil and starter.Starter and starter.Category == "Small", "offre de départ")
        local garages = 0
        for _, item in Infrastructure do
            if item.Kind == "PublicGarage" then
                garages += 1
            end
        end
        T.equal(garages, 3)
    end)

    T.test("modules de garage : huit catégories (proposition à arbitrer), garages publics complets", function()
        T.equal(GarageModules.CategoryCount, 8)
        T.truthy(PUBLIC.SwapParts and PUBLIC.EditTuning and PUBLIC.EditCosmetics, "public complet")
        T.truthy(not PRIVATE.SwapParts and not PRIVATE.EditTuning, "privé sans module")
        local workshop = GarageModules.privateCapabilities({ Workshop = {} })
        T.truthy(workshop.EditTuning and not workshop.SwapParts, "atelier : réglages seulement")
    end)

    T.test("données synthétiques de développement : une fois, marquées, jamais un starter", function()
        local DevSeed = H.require(SERVER .. "Progression.DevSeed")
        local profile = newProfile()
        local ok, result = DevSeed.apply(profile, 0, function(id)
            return Definitions.get(id)
        end)
        T.truthy(ok)
        -- Lot BASE-01 (point P2) : plus aucun véhicule synthétique ; propriété, pièces et solde restent.
        T.equal(result.Vehicles, 0)
        T.equal(next(profile.Vehicles), nil, "aucun véhicule")
        T.equal(profile.Starter.State, "Pending", "aucun starter attribué")
        T.equal(select(2, DevSeed.apply(profile, 1, Definitions.get)), "DevSeedAlreadyApplied")
        T.truthy((ProfileSchema.validate(profile)), "cohérent")
    end)

    T.test("protocole : toute action sensible est une action connue", function()
        local Protocol = H.require(SHARED .. "Garage.ProgressionProtocol")
        for action in Protocol.Sensitive do
            T.truthy(table.find(Protocol.Actions, action) ~= nil, action)
        end
    end)

    T.test("identifiant de demande client : format contrôlé", function()
        T.equal(TransactionService.clientTxId("abcd-1234-efgh"), "C:abcd-1234-efgh")
        T.equal(TransactionService.clientTxId("court"), nil)
        T.equal(TransactionService.clientTxId("avec espace 123"), nil)
        T.equal(TransactionService.clientTxId(42), nil)
        T.truthy(#PartCatalog.Slots == 6, "six emplacements de pièces")
    end)
end
