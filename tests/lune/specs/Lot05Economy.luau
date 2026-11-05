--!strict
-- Lot 0.5 — économie : invariants des opérations qui créent de l'argent,
-- transfèrent un actif ou facturent un joueur, sur l'adaptateur MÉMOIRE, y
-- compris interruptions et répétitions. Ne valide PAS la persistance Roblox
-- réelle (DataStore, inter-serveurs : NON TESTÉ, docs/QA_BACKLOG.md).

local SERVER = "ServerScriptService.AutomotiveWorldServer."
local SHARED = "ReplicatedStorage.Shared."

return function(T: any, H: any)
    local ProfileSchema = H.require(SERVER .. "Persistence.ProfileSchema")
    local ProfileMigration = H.require(SERVER .. "Persistence.ProfileMigration")
    local ProfileRepository = H.require(SERVER .. "Persistence.ProfileRepository")
    local MemoryProfileRepository = H.require(SERVER .. "Persistence.MemoryProfileRepository")
    local ProfileSession = H.require(SERVER .. "Persistence.ProfileSession")
    local ProfileAccess = H.require(SERVER .. "Persistence.ProfileAccess")
    local Wallet = H.require(SERVER .. "Economy.Wallet")
    local Commerce = H.require(SERVER .. "Economy.Commerce")
    local Market = H.require(SERVER .. "Economy.Market")
    local RewardModel = H.require(SERVER .. "Economy.RewardModel")
    local MissionEngine = H.require(SERVER .. "Economy.MissionEngine")
    local MissionGenerator = H.require(SERVER .. "Economy.MissionGenerator")
    local MissionPlaces = H.require(SERVER .. "Economy.MissionPlaces")
    local VehicleOwnership = H.require(SERVER .. "Progression.VehicleOwnership")
    local StarterSelection = H.require(SERVER .. "Progression.StarterSelection")
    local PropertyRules = H.require(SERVER .. "Progression.PropertyRules")
    local Customization = H.require(SERVER .. "Progression.Customization")
    local GarageRules = H.require(SERVER .. "Progression.GarageRules")
    local EconomyCatalog = H.require(SHARED .. "Economy.EconomyCatalog")
    local VehicleCatalog = H.require(SHARED .. "Economy.VehicleCatalog")
    local Jobs = H.require(SHARED .. "Economy.Jobs")
    local Reputation = H.require(SHARED .. "Economy.Reputation")
    local GarageModules = H.require(SHARED .. "Garage.GarageModules")
    local CosmeticCatalog = H.require(SHARED .. "Garage.CosmeticCatalog")
    local Definitions = H.require(SHARED .. "Vehicles.VehicleDefinitions")

    local SELLER, BUYER, BUYER2 = 1001, 1002, 1003
    local PUBLIC = GarageModules.publicCapabilities()

    -- Monde de test : un stockage, une horloge, des sessions « en ligne ».
    local function world()
        local clock = { Now = 10_000 }
        local counter = 0
        local repo = MemoryProfileRepository.new()
        local online: { [number]: any } = {}
        local function token(): string
            counter += 1
            return "tok-" .. counter
        end
        local function session(userId: number, name: string?): any
            local s = ProfileSession.new({
                Repository = repo,
                Key = ProfileRepository.keyFor(userId),
                UserId = userId,
                Session = name or token(),
                Server = "srv",
                Environment = "Dev",
                Clock = function()
                    return clock.Now
                end,
                Token = token,
                MinWriteInterval = 0,
            })
            s:load()
            return s
        end
        local access = ProfileAccess.new({
            Repository = repo,
            Environment = "Dev",
            Clock = function()
                return clock.Now
            end,
            Token = token,
            Server = "srv",
            Online = function(userId)
                return online[userId]
            end,
            MinWriteInterval = 0,
        })
        local ctx = {
            Repository = repo,
            Profiles = access,
            Clock = function()
                return clock.Now
            end,
        }
        -- Crée un profil hors ligne avec un solde et, si demandé, un véhicule acheté.
        local function seed(userId: number, balance: number, withVehicle: boolean?): string?
            local s = session(userId)
            local vehicleId: string? = nil
            s:commit("seed", "Seed", function(profile)
                if balance > 0 then
                    Wallet.credit(profile, balance, "Seed", "seed", clock.Now)
                end
                if withVehicle then
                    local definition = Definitions.get("wk_brio")
                    vehicleId = VehicleOwnership.add(profile, {
                        ModelId = "wk_brio",
                        Origin = "Purchase",
                        Untransferable = false,
                        Synthetic = false,
                        EnergyFraction = 0.5,
                        Cosmetics = CosmeticCatalog.defaults(definition),
                        PaidPrice = 18_500,
                    }, clock.Now)
                end
                return true, nil
            end)
            s:save(true)
            return vehicleId
        end
        local function profileOf(userId: number): any
            local stored = repo.Store[ProfileRepository.keyFor(userId)]
            return stored and stored.Data
        end
        return clock, repo, ctx, online, session, seed, profileOf
    end

    local function total(profile: any): number
        return profile.Wallet.Balance + profile.Wallet.Reserved
    end

    T.suite("Lot 0.5 — portefeuille et migration")

    T.test("16. migration v1 → v2 : données conservées, portefeuille à zéro, profil valide", function()
        local v2 = ProfileSchema.new(77, 0, "Dev")
        PropertyRules.grantFree(v2, 0)
        VehicleOwnership.add(v2, {
            ModelId = "proto_p01",
            Origin = "DevSynthetic",
            Untransferable = true,
            Synthetic = true,
            EnergyFraction = 0.6,
            Cosmetics = {},
        }, 0)
        local v1: any = ProfileMigration.deepCopy(v2)
        v1.SchemaVersion = 1
        for _, key in { "Wallet", "Reputation", "Jobs", "Ledger", "Transfers", "Applied", "Services" } do
            v1[key] = nil
        end
        for _, vehicle in v1.Vehicles do
            vehicle.PaidPrice = nil
            vehicle.Dirt = nil
        end
        for _, property in v1.Properties do
            property.PaidPrice = nil
            property.PaidExtensions = nil
            property.PaidModules = nil
        end
        local result = ProfileMigration.migrate(v1)
        T.equal(result.Status, "Migrated")
        local ok, errors = ProfileSchema.validate(result.Data)
        T.truthy(ok, table.concat(errors, " ; "))
        T.equal(result.Data.Wallet.Balance, 0)
        T.equal(result.Data.Grants.FreeProperty.Ref, v2.Grants.FreeProperty.Ref, "attributions conservées")
        T.equal(v1.SchemaVersion, 1, "donnée d'origine intacte")
    end)

    T.test("montants : entiers positifs bornés seulement ; jamais de solde négatif", function()
        for _, bad in { 0, -5, 1.5, 0 / 0, math.huge, Wallet.MaxAmount + 1, "100" } do
            T.truthy(not Wallet.validAmount(bad), tostring(bad))
        end
        local profile = ProfileSchema.new(5, 0, "Dev")
        T.equal(select(2, Wallet.debit(profile, 10, "Test", "x", 0)), "InsufficientFunds")
        T.equal(profile.Wallet.Balance, 0)
    end)

    T.suite("Lot 0.5 — commerce mono-profil")

    T.test("2. solde insuffisant : achat refusé, profil inchangé", function()
        local _, _, _, _, session = world()
        local s = session(BUYER)
        local before = s.Data.Counters.Vehicle
        local result = s:commit("C:buy-0001", "BuyVehicle", function(profile)
            return Commerce.buyVehicle(profile, "brio", "Dev", Definitions.get("wk_brio"), 0)
        end)
        T.equal(result.Status, "Rejected")
        T.equal(result.Error, "InsufficientFunds")
        T.equal(s.Data.Counters.Vehicle, before)
        T.equal(next(s.Data.Vehicles), nil)
    end)

    T.test("3. répétition : même résultat, un seul débit, un seul exemplaire", function()
        local _, _, _, _, session = world()
        local s = session(BUYER)
        s:commit("seed", "Seed", function(profile)
            return Wallet.credit(profile, 50_000, "Seed", "s", 0)
        end)
        local function buy()
            return s:commit("C:buy-0002", "BuyVehicle", function(profile)
                return Commerce.buyVehicle(profile, "brio", "Dev", Definitions.get("wk_brio"), 0)
            end)
        end
        local first, second = buy(), buy()
        T.equal(first.Status, "Confirmed")
        T.equal(second.Status, "Duplicate")
        T.equal(second.Result.VehicleId, first.Result.VehicleId)
        T.equal(s.Data.Wallet.Balance, 50_000 - 18_500)
        local count = 0
        for _ in s.Data.Vehicles do
            count += 1
        end
        T.equal(count, 1)
    end)

    T.test(
        "catalogue : 18 emplacements, modèles de travail achetables en Dev seulement, prototypes absents",
        function()
            T.equal(#VehicleCatalog.Entries, 18)
            local working = 0
            for _, entry in VehicleCatalog.Entries do
                if entry.Availability == "Working" then
                    working += 1
                    T.truthy(VehicleCatalog.purchasable(entry, "Dev"), entry.Id)
                    T.truthy(
                        not VehicleCatalog.purchasable(entry, "Test") and not VehicleCatalog.purchasable(entry, "Prod"),
                        entry.Id
                    )
                    T.truthy(Definitions.get(entry.DefinitionId) ~= nil, entry.DefinitionId)
                else
                    T.truthy(not VehicleCatalog.purchasable(entry, "Dev"), entry.Id .. " réservé")
                end
                T.truthy(
                    entry.DefinitionId == nil or string.sub(entry.DefinitionId, 1, 6) ~= "proto_",
                    "pas de prototype"
                )
            end
            T.equal(working, 6)
            local profile = ProfileSchema.new(5, 0, "Prod")
            Wallet.credit(profile, 100_000, "Seed", "s", 0)
            T.equal(
                select(2, Commerce.buyVehicle(profile, "brio", "Prod", Definitions.get("wk_brio"), 0)),
                "CatalogNotPurchasable"
            )
        end
    )

    T.test("reprise ≈ 60 % ajustée à l'état ; pièces installées incluses, sans second versement", function()
        local profile = ProfileSchema.new(5, 0, "Dev")
        Wallet.credit(profile, 100_000, "Seed", "s", 0)
        local _, bought = Commerce.buyVehicle(profile, "brio", "Dev", Definitions.get("wk_brio"), 0)
        Commerce.buyPart(profile, "TIRE-SPORT", 0)
        Customization.setPart(profile, bought.VehicleId, "Tires", "TIRE-SPORT", Definitions.get("wk_brio"), PUBLIC, 0)
        local ok, quote = Commerce.tradeInQuote(profile, bought.VehicleId, 0)
        T.truthy(ok)
        T.equal(quote.Amount, math.floor(18_500 * 0.6), "neuf : 60 %")
        local balance = profile.Wallet.Balance
        T.truthy((Commerce.tradeIn(profile, bought.VehicleId, 0)), "reprise")
        T.equal(profile.Wallet.Balance, balance + quote.Amount)
        T.equal(next(profile.Parts), nil, "pièce installée partie avec le véhicule")
        T.truthy((ProfileSchema.validate(profile)), "cohérent")
        -- Un véhicule abîmé vaut moins.
        local _, second = Commerce.buyVehicle(profile, "brio", "Dev", Definitions.get("wk_brio"), 0)
        profile.Vehicles[second.VehicleId].Damage.Zones.Front = 1
        profile.Vehicles[second.VehicleId].Damage.Engine = 0.5
        local _, worn = Commerce.tradeInQuote(profile, second.VehicleId, 0)
        T.truthy(worn.Amount < quote.Amount, worn.Amount .. " < " .. quote.Amount)
    end)

    T.test("9. starter incessible : ni reprise ni mise en vente", function()
        local clock, _, ctx, _, session = world()
        local s = session(SELLER)
        local starterId = nil
        s:commit("Grant:Starter", "Starter", function(profile)
            local ok, result = StarterSelection.choose(
                profile,
                "wk_brio",
                { "wk_brio", "wk_aster", "wk_fil" },
                0,
                function(id)
                    local definition = Definitions.get(id)
                    return definition.Powertrain.Energy.InitialFraction, CosmeticCatalog.defaults(definition)
                end
            )
            starterId = if ok then result.VehicleId else nil
            return ok, result
        end)
        T.equal(select(2, Commerce.tradeInQuote(s.Data, starterId, clock.Now)), "VehicleUntransferable")
        s:save(true)
        local status, err = Market.createListing(ctx, SELLER, starterId, 5_000, "starter-try-01")
        T.equal(status, "Rejected")
        T.equal(err, "VehicleUntransferable")
    end)

    T.test("11. immobilier : 70 % / 40 % / 60 % des montants payés ; gratuite invendable ; plafond", function()
        local profile = ProfileSchema.new(5, 0, "Dev")
        PropertyRules.grantFree(profile, 0)
        Wallet.credit(profile, 500_000, "Seed", "s", 0)
        local _, bought = Commerce.buyProperty(profile, "RES-METRO-LOFTS", 0)
        T.equal(bought.Price, EconomyCatalog.PropertyPrice.Medium)
        local _, upgrade = Commerce.upgradeGarage(profile, bought.PropertyId, 0)
        local _, module = Commerce.buyModule(profile, bought.PropertyId, "Workshop", "Dev", 0)
        T.equal(
            select(2, Commerce.buyModule(profile, bought.PropertyId, "Workshop", "Dev", 0)),
            "ModuleAlreadyInstalled"
        )
        T.equal(select(2, Commerce.buyModule(profile, bought.PropertyId, "Lift", "Prod", 0)), "ModuleAwaitingDecision")
        local _, quote = Commerce.propertyQuote(profile, bought.PropertyId)
        local expected = math.floor(bought.Price * 0.7 + upgrade.Price * 0.4 + module.Price * 0.6)
        T.equal(quote.Amount, expected)
        local free = profile.Grants.FreeProperty.Ref
        T.equal(select(2, Commerce.sellProperty(profile, free, 0)), "PropertyNotSellable")
        for _ = 1, 3 do
            Commerce.buyProperty(profile, "RES-BANLIEUE-PLAINE", 0)
        end
        local balance = profile.Wallet.Balance
        T.equal(select(2, Commerce.buyProperty(profile, "RES-METRO-PARC", 0)), "PropertyLimit")
        T.truthy(profile.Wallet.Balance <= balance, "rien gagné")
        local before = profile.Wallet.Balance
        T.truthy((Commerce.sellProperty(profile, bought.PropertyId, 0)), "vendue")
        T.equal(profile.Wallet.Balance, before + expected)
    end)

    T.test("pièces : revente 75 % du prix payé ; pièce synthétique ou installée non revendable", function()
        local profile = ProfileSchema.new(5, 0, "Dev")
        Wallet.credit(profile, 10_000, "Seed", "s", 0)
        local _, part = Commerce.buyPart(profile, "BRAKE-SPORT", 0)
        local balance = profile.Wallet.Balance
        local _, sold = Commerce.sellPart(profile, part.PartItemId, 0)
        T.equal(sold.Amount, math.floor(2_400 * 0.75))
        T.equal(profile.Wallet.Balance, balance + sold.Amount)
        T.equal(select(2, Commerce.sellPart(profile, part.PartItemId, 0)), "PartNotOwned", "jamais vendue deux fois")
        profile.Parts["PT-x"] =
            { Id = "PT-x", PartId = "TIRE-RAIN", AcquiredAt = 0, Origin = "DevSynthetic", Synthetic = true }
        T.equal(select(2, Commerce.sellPart(profile, "PT-x", 0)), "PartNotEligible")
    end)

    T.test("13. réparation payée une seule fois ; jamais gratuite ; lavage sans effet mécanique", function()
        local _, _, _, _, session = world()
        local s = session(BUYER)
        s:commit("seed", "Seed", function(profile)
            Wallet.credit(profile, 20_000, "Seed", "s", 0)
            local _, bought = Commerce.buyVehicle(profile, "brio", "Dev", Definitions.get("wk_brio"), 0)
            local vehicle = profile.Vehicles[bought.VehicleId]
            vehicle.Damage.Zones.Front = 0.5
            vehicle.Dirt = 0.6
            return true, nil
        end)
        local id = next(s.Data.Vehicles)
        local _, quote = Commerce.repairQuote(s.Data, id)
        T.truthy(quote.Amount > 0, quote.Amount .. " crédits")
        local balance = s.Data.Wallet.Balance
        local function repair(tx: string)
            return s:commit(tx, "Repair", function(profile)
                return Commerce.repair(profile, id, 0)
            end)
        end
        T.equal(repair("C:repair-0001").Status, "Confirmed")
        T.equal(repair("C:repair-0001").Status, "Duplicate")
        T.equal(repair("C:repair-0002").Error, "RepairNotNeeded")
        T.equal(s.Data.Wallet.Balance, balance - quote.Amount)
        s.Data.Vehicles[id].Damage.Zones.Rear = 0.3
        local washed = s:commit("C:wash-0001", "Wash", function(profile)
            return Commerce.wash(profile, id, 0)
        end)
        T.equal(washed.Status, "Confirmed")
        T.equal(s.Data.Vehicles[id].Dirt, 0)
        T.equal(s.Data.Vehicles[id].Damage.Zones.Rear, 0.3, "le lavage ne répare rien")
    end)

    T.test("12. recharge interrompue : fonds restitués, aucune énergie gratuite ; règlement au réel", function()
        local clock, repo, _, _, session = world()
        local s = session(BUYER)
        s:commit("seed", "Seed", function(profile)
            Wallet.credit(profile, 20_000, "Seed", "s", 0)
            Commerce.buyVehicle(profile, "aster", "Dev", Definitions.get("wk_aster"), 0)
            return true, nil
        end)
        local id = next(s.Data.Vehicles)
        local energyBefore = s.Data.Vehicles[id].Energy
        local balanceBefore = s.Data.Wallet.Balance
        T.equal(
            s:commit("C:energy-0001", "Energy", function(profile)
                return Commerce.startEnergy(profile, "E1", id, "Diesel", 20, 0)
            end).Status,
            "Confirmed"
        )
        local unit = EconomyCatalog.EnergyPrice.Diesel
        T.equal(s.Data.Wallet.Reserved, 20 * unit)
        -- Serveur arrêté brutalement : la session disparaît sans régler.
        clock.Now += 400
        local recovered = ProfileSession.new({
            Repository = repo,
            Key = ProfileRepository.keyFor(BUYER),
            UserId = BUYER,
            Session = "after-crash",
            Server = "srv2",
            Environment = "Dev",
            Clock = function()
                return clock.Now
            end,
            Token = function()
                return "t" .. clock.Now
            end,
            OnLoaded = function(profile, now)
                return Commerce.recoverServices(profile, now)
            end,
        })
        T.equal(recovered:load(), "Active")
        T.equal(recovered.Data.Wallet.Reserved, 0)
        T.equal(recovered.Data.Wallet.Balance, balanceBefore, "aucun débit")
        T.equal(recovered.Data.Vehicles[id].Energy, energyBefore, "aucune énergie gratuite")
        -- Règlement normal : seule la quantité livrée est payée.
        recovered:commit("C:energy-0002", "Energy", function(profile)
            return Commerce.startEnergy(profile, "E2", id, "Diesel", 20, clock.Now)
        end)
        local settle = recovered:commit("C:energy-0003", "Energy", function(profile)
            return Commerce.settleEnergy(profile, "E2", 7.5, 42, clock.Now)
        end)
        T.equal(settle.Result.Cost, math.ceil(7.5 * unit))
        T.equal(recovered.Data.Wallet.Balance, balanceBefore - math.ceil(7.5 * unit))
        T.equal(recovered.Data.Wallet.Reserved, 0)
        T.near(recovered.Data.Vehicles[id].Energy, energyBefore + 7.5 / 42, 1e-9)
        T.truthy((ProfileSchema.validate(recovered.Data)), "cohérent")
    end)

    T.suite("Lot 0.5 — marché et transactions multiprofils")

    local function listed(price: number?)
        local clock, repo, ctx, online, session, seed, profileOf = world()
        local vehicleId = seed(SELLER, 0, true) :: string
        seed(BUYER, 60_000)
        seed(BUYER2, 60_000)
        local status, result = Market.createListing(ctx, SELLER, vehicleId, price or 20_000, "listing-req-01")
        T.equal(status, "Confirmed")
        return clock, repo, ctx, online, session, profileOf, vehicleId, result.ListingId
    end

    T.test(
        "10. vente : commission de 5 %, aucun crédit créé ni détruit hors commission, un seul véhicule",
        function()
            local _, _, ctx, _, _, profileOf, vehicleId, listingId = listed(20_000)
            local before = total(profileOf(SELLER)) + total(profileOf(BUYER))
            local state = Market.purchase(ctx, BUYER, listingId, "purchase-req-01")
            T.equal(state, "Committed")
            local seller, buyer = profileOf(SELLER), profileOf(BUYER)
            T.equal(seller.Wallet.Balance, 20_000 - 1_000, "vendeur : prix − 5 %")
            T.equal(buyer.Wallet.Balance, 60_000 - 20_000)
            T.equal(buyer.Wallet.Reserved, 0)
            T.equal(total(seller) + total(buyer), before - 1_000, "seule la commission disparaît")
            T.truthy(seller.Vehicles[vehicleId] == nil and buyer.Vehicles[vehicleId] ~= nil, "propriété transférée")
            T.equal(buyer.Vehicles[vehicleId].OwnerUserId, BUYER)
            T.truthy((ProfileSchema.validate(seller)) and (ProfileSchema.validate(buyer)), "profils cohérents")
            T.equal(
                Market.purchase(ctx, BUYER, listingId, "purchase-req-01"),
                "Committed",
                "répétition : même transaction"
            )
            T.equal(profileOf(BUYER).Wallet.Balance, 40_000, "pas de second débit")
        end
    )

    T.test("4. double achat concurrent : une seule vente, l'autre acheteur n'est pas débité", function()
        local _, _, ctx, _, _, profileOf, vehicleId, listingId = listed(20_000)
        -- Les deux transactions sont créées puis avancées en alternance.
        local stateA, a = Market.purchase(ctx, BUYER, listingId, "concurrent-a1")
        local stateB = Market.purchase(ctx, BUYER2, listingId, "concurrent-b1")
        T.equal(stateA, "Committed")
        T.equal(stateB, "Aborted")
        T.equal(profileOf(BUYER2).Wallet.Balance, 60_000)
        T.equal(profileOf(BUYER2).Wallet.Reserved, 0)
        local owners = 0
        for _, id in { SELLER, BUYER, BUYER2 } do
            if profileOf(id).Vehicles[vehicleId] then
                owners += 1
            end
        end
        T.equal(owners, 1)
        T.truthy(a.TxId ~= nil)
    end)

    T.test("4 bis. achats imbriqués étape par étape : le verrou de l'annonce départage", function()
        local clock, repo, ctx, _, _, profileOf, _, listingId = listed(20_000)
        local function prepare(buyer: number, tx: string)
            repo:update(Market.txKey(tx), function()
                return {
                    Id = tx,
                    Kind = "MarketSale",
                    State = "Prepared",
                    ListingId = listingId,
                    Buyer = buyer,
                    Seller = SELLER,
                    VehicleId = repo.Store[Market.listingKey(listingId)].VehicleId,
                    Price = 20_000,
                    Fee = 1_000,
                    CreatedAt = clock.Now,
                    UpdatedAt = clock.Now,
                    Log = {},
                }
            end)
        end
        prepare(BUYER, "TX-A")
        prepare(BUYER2, "TX-B")
        T.equal(Market.step(ctx, "TX-A"), "Locked")
        T.equal(Market.step(ctx, "TX-B"), "Aborted")
        T.equal(Market.resume(ctx, "TX-A"), "Committed")
        T.equal(profileOf(BUYER2).Wallet.Balance, 60_000)
    end)

    T.test("5. double vente : un exemplaire n'a qu'une annonce et aucune opération incompatible", function()
        local clock, _, ctx, _, session, profileOf, vehicleId = listed(20_000)
        local status, err = Market.createListing(ctx, SELLER, vehicleId, 25_000, "listing-req-02")
        T.equal(status, "Rejected")
        T.equal(err, "VehicleReserved")
        T.equal(select(2, Commerce.tradeInQuote(profileOf(SELLER), vehicleId, clock.Now)), "VehicleReserved")
        T.equal(select(2, GarageRules.takeOut(profileOf(SELLER), vehicleId, "s", clock.Now)), "VehicleReserved")
        local _ = session
    end)

    T.test("6. déconnexion pendant le transfert : profil verrouillé ailleurs → différé, puis repris", function()
        local clock, _, ctx, online, session, profileOf, vehicleId, listingId = listed(20_000)
        -- Le vendeur est connecté sur un AUTRE serveur (verrou détenu, session inconnue d'ici).
        local elsewhere = session(SELLER, "other-server")
        local state, result = Market.purchase(ctx, BUYER, listingId, "deferred-req-01")
        T.equal(state, "Blocked")
        T.equal(profileOf(BUYER).Wallet.Reserved, 20_000, "fonds réservés, ni perdus ni dépensables")
        T.truthy(profileOf(SELLER).Vehicles[vehicleId] ~= nil, "véhicule encore chez le vendeur")
        -- Le serveur du vendeur traite sa boîte de réception.
        online[SELLER] = elsewhere
        local processed = Market.processInbox(ctx, SELLER)
        T.equal(processed[result.TxId], "Committed")
        elsewhere:save(true)
        online[SELLER] = nil
        T.truthy(profileOf(BUYER).Vehicles[vehicleId] ~= nil, "véhicule livré")
        T.equal(profileOf(SELLER).Wallet.Balance, 19_000)
        local _ = clock
    end)

    T.test("17. perte de réponse : arrêt entre deux étapes, reprise par un autre serveur sans doublon", function()
        local clock, repo, ctx, _, _, profileOf, vehicleId, listingId = listed(20_000)
        -- Le serveur s'arrête après la réservation des fonds (avant la vente).
        local txId = "MS-" .. BUYER .. "-crash-req-01"
        repo:update(Market.txKey(txId), function()
            return {
                Id = txId,
                Kind = "MarketSale",
                State = "Prepared",
                ListingId = listingId,
                Buyer = BUYER,
                Seller = SELLER,
                VehicleId = vehicleId,
                Price = 20_000,
                Fee = 1_000,
                CreatedAt = clock.Now,
                UpdatedAt = clock.Now,
                Log = {},
            }
        end)
        T.equal(Market.step(ctx, txId), "Locked")
        T.equal(Market.step(ctx, txId), "Reserved")
        -- Réponse perdue sur l'avancement de la transaction après la vente :
        -- l'écriture du vendeur a eu lieu, l'enregistrement dit encore « Reserved ».
        repo:inject("Failed") -- perte de l'écriture de transition (rien d'écrit)
        local ok = pcall(Market.step, ctx, txId)
        T.truthy(ok)
        -- Nouvel « serveur » : reprise.
        local state = Market.resume(ctx, txId)
        T.equal(state, "Committed")
        local seller, buyer = profileOf(SELLER), profileOf(BUYER)
        T.equal(seller.Wallet.Balance, 19_000, "vendeur payé une seule fois")
        T.equal(buyer.Wallet.Balance, 40_000, "acheteur débité une seule fois")
        local copies = 0
        for _, profile in { seller, buyer } do
            if profile.Vehicles[vehicleId] then
                copies += 1
            end
        end
        T.equal(copies, 1, "un seul exemplaire")
    end)

    T.test("7. compensation : vente impossible après réservation → acheteur remboursé, rien perdu", function()
        local _, repo, ctx, _, session, profileOf, vehicleId, listingId = listed(20_000)
        -- Incohérence simulée : la réservation de l'annonce a disparu du profil vendeur.
        local s = session(SELLER)
        s:commit("tamper", "Test", function(profile)
            profile.Vehicles[vehicleId].Reservation = nil
            return true, nil
        end)
        s:save(true)
        local state, result = Market.purchase(ctx, BUYER, listingId, "compensate-req-01")
        T.equal(state, "Compensated")
        T.equal(profileOf(BUYER).Wallet.Balance, 60_000)
        T.equal(profileOf(BUYER).Wallet.Reserved, 0)
        T.truthy(profileOf(SELLER).Vehicles[vehicleId] ~= nil, "véhicule resté au vendeur")
        T.equal(profileOf(SELLER).Wallet.Balance, 0, "vendeur non payé")
        T.equal(repo.Store[Market.txKey(result.TxId)].State, "Compensated", "enregistrement conservé")
    end)

    T.test(
        "8. vente avec pièces installées : elles suivent ; pièces détachées et configurations irréalisables restent",
        function()
            local clock, _, ctx, _, session, _, profileOf = world()
            local s = session(SELLER)
            local vehicleId: string = ""
            s:commit("prep", "Test", function(profile)
                Wallet.credit(profile, 50_000, "Seed", "s", 0)
                local _, bought = Commerce.buyVehicle(profile, "brio", "Dev", Definitions.get("wk_brio"), 0)
                vehicleId = bought.VehicleId
                Commerce.buyPart(profile, "TIRE-SPORT", 0)
                Commerce.buyPart(profile, "BRAKE-SPORT", 0)
                Commerce.buyPart(profile, "TIRE-RAIN", 0)
                local definition = Definitions.get("wk_brio")
                Customization.setPart(profile, vehicleId, "Tires", "TIRE-SPORT", definition, PUBLIC, 0)
                Customization.setPart(profile, vehicleId, "Brakes", "BRAKE-SPORT", definition, PUBLIC, 0)
                Customization.saveConfiguration(profile, vehicleId, 1, "Complet", 0)
                Customization.setPart(profile, vehicleId, "Tires", "TIRE-RAIN", definition, PUBLIC, 0)
                Customization.saveConfiguration(profile, vehicleId, 2, "Pluie", 0)
                Customization.setPart(profile, vehicleId, "Tires", "TIRE-SPORT", definition, PUBLIC, 0)
                return true, nil
            end)
            s:save(true)
            local session2 = session(BUYER)
            session2:commit("seed", "Seed", function(profile)
                return Wallet.credit(profile, 40_000, "Seed", "s", 0)
            end)
            session2:save(true)
            local _, listing = Market.createListing(ctx, SELLER, vehicleId, 30_000, "parts-listing-1")
            T.equal(Market.purchase(ctx, BUYER, listing.ListingId, "parts-buy-001"), "Committed")
            local seller, buyer = profileOf(SELLER), profileOf(BUYER)
            local vehicle = buyer.Vehicles[vehicleId]
            local installed = {}
            for slot, partId in vehicle.InstalledParts do
                installed[slot] = buyer.Parts[partId].PartId
            end
            T.equal(installed.Tires, "TIRE-SPORT")
            T.equal(installed.Brakes, "BRAKE-SPORT")
            T.equal(#vehicle.Configurations, 1, "seule la configuration réalisable suit")
            local sellerParts = {}
            for _, part in seller.Parts do
                table.insert(sellerParts, part.PartId)
            end
            T.equal(#sellerParts, 1)
            T.equal(sellerParts[1], "TIRE-RAIN", "pièce détachée restée au vendeur")
            T.truthy((ProfileSchema.validate(buyer)) and (ProfileSchema.validate(seller)), "cohérents")
            local _ = clock
        end
    )

    T.test("15. stockage indisponible : achat non engagé, rien de modifié", function()
        local _, repo, ctx, _, _, profileOf, vehicleId, listingId = listed(20_000)
        repo.Unavailable = true
        local state = Market.purchase(ctx, BUYER, listingId, "unavailable-req-1")
        repo.Unavailable = false
        T.truthy(state == "Unknown" or state == "Blocked" or state == "Unavailable", state)
        T.equal(profileOf(BUYER).Wallet.Balance, 60_000)
        T.truthy(profileOf(SELLER).Vehicles[vehicleId] ~= nil)
    end)

    T.test("annulation : annonce close, véhicule libéré ; refusée pendant un achat", function()
        local clock, repo, ctx, _, _, profileOf, vehicleId, listingId = listed(20_000)
        T.equal(Market.cancelListing(ctx, SELLER, listingId), "Confirmed")
        T.truthy(profileOf(SELLER).Vehicles[vehicleId].Reservation == nil)
        T.equal(Market.purchase(ctx, BUYER, listingId, "after-cancel-1"), "Aborted")
        local _ = clock
        local _2 = repo
    end)

    T.suite("Lot 0.5 — métiers et réputation")

    local places = MissionPlaces.dev()

    local function roller(seed: number): () -> number
        local value = seed
        return function(): number
            value = (value * 16807) % 2147483647
            return value / 2147483647
        end
    end

    T.test("huit métiers : génération serveur pour chacun", function()
        T.equal(#Jobs.List, 8)
        for _, job in Jobs.List do
            local mission, err =
                MissionGenerator.generate(job.Id, "M-" .. job.Id, 1, { X = 0, Z = 20 }, places, 1, roller(7), 0)
            T.truthy(mission ~= nil, job.Id .. " : " .. tostring(err))
            if mission then
                T.truthy(
                    #mission.Steps > 0 and mission.EstimatedS > 0 and mission.TimeLimitS > mission.EstimatedS,
                    job.Id
                )
            end
        end
    end)

    -- Rejoue une mission avec des échantillons « serveur » simulés.
    local function drive(mission: any, vehicleId: string?): any
        local state = MissionEngine.start(mission, 0)
        local t, x, z = 0, 0, 20
        local function sample(speed: number, inVehicle: boolean, heading: number?)
            MissionEngine.observe(state, mission, {
                T = t,
                X = x,
                Z = z,
                Heading = heading or 0,
                SpeedMs = speed,
                InVehicle = inVehicle,
                VehicleId = vehicleId,
                Damage = 0,
                Corrected = false,
            })
        end
        for _, step in mission.Steps do
            if step.Point then
                local dx, dz = step.Point.X - x, step.Point.Z - z
                local length = math.sqrt(dx * dx + dz * dz)
                local n = math.max(1, math.ceil(length / 10))
                for i = 1, n do
                    x += dx / n
                    z += dz / n
                    t += 10 / 9
                    sample(9, true)
                end
            end
            if step.Kind == "Accel" then
                sample(0, true)
                for v = 1, 30 do
                    t += 0.3
                    sample(v, true)
                end
            elseif step.Kind == "Brake" then
                sample(28, true)
                for v = 27, 0, -1 do
                    t += 0.1
                    z -= 1.4
                    sample(v, true)
                end
            else
                for _ = 1, 30 do
                    t += 0.25
                    sample(0, step.Kind ~= "OnFoot", step.Heading)
                end
            end
            if state.Status ~= "Active" then
                break
            end
        end
        return state
    end

    T.test("1. gain de mission unique : rejouer la fin ne paie jamais deux fois", function()
        local _, _, _, _, session = world()
        local s = session(BUYER)
        local mission =
            MissionGenerator.generate("Delivery", "M-unique-1", BUYER, { X = 0, Z = 20 }, places, 1, roller(3), 0)
        local state = drive(mission, "PRO-1")
        T.equal(state.Status, "Completed")
        local quality = MissionEngine.quality(state, mission)
        local function pay()
            return s:commit("Mission:" .. mission.Id, "Mission", function(profile)
                return RewardModel.payout(profile, mission, true, quality, 1000)
            end)
        end
        local first, second = pay(), pay()
        T.equal(first.Status, "Confirmed")
        T.equal(second.Status, "Duplicate")
        T.truthy(first.Result.Credits > 0, first.Result.Credits .. " crédits")
        T.equal(s.Data.Wallet.Balance, first.Result.Credits)
        T.equal(s.Data.Jobs.Delivery.Completed, 1)
    end)

    T.test("14. sans crédit ni véhicule : mission professionnelle payée normalement, rien acquis", function()
        local _, _, _, _, session = world()
        local s = session(BUYER2)
        T.equal(s.Data.Wallet.Balance, 0)
        T.equal(next(s.Data.Vehicles), nil)
        local available = Jobs.withoutPersonalVehicle()
        T.truthy(#available >= 1, #available .. " métier(s)")
        local mission =
            MissionGenerator.generate("Delivery", "M-pro-1", BUYER2, { X = 0, Z = 20 }, places, 1, roller(11), 0)
        T.equal(mission.VehicleRule, "Professional")
        mission.ProvidedVehicleId = "PRO-M-pro-1"
        local state = drive(mission, "PRO-M-pro-1")
        T.equal(state.Status, "Completed")
        local paid = s:commit("Mission:" .. mission.Id, "Mission", function(profile)
            return RewardModel.payout(profile, mission, true, MissionEngine.quality(state, mission), 1000)
        end)
        T.truthy(paid.Result.Credits > 0)
        T.equal(next(s.Data.Vehicles), nil, "véhicule professionnel jamais acquis")
        -- Avec un autre véhicule que celui fourni, la mission n'avance pas.
        local other = drive(mission, "AUTRE")
        T.truthy(other.Status ~= "Completed", "mauvais véhicule")
    end)

    T.test(
        "anti-abus : correction de mouvement = échec ; répétition du même itinéraire de moins en moins payée",
        function()
            local mission =
                MissionGenerator.generate("Taxi", "M-abuse-1", 1, { X = 0, Z = 20 }, places, 1, roller(5), 0)
            local state = MissionEngine.start(mission, 0)
            MissionEngine.observe(
                state,
                mission,
                { T = 1, X = 0, Z = 20, Heading = 0, SpeedMs = 0, InVehicle = true, Damage = 0, Corrected = true }
            )
            T.equal(state.Status, "Failed")
            T.equal(state.FailReason, "MovementCorrected")
            local profile = ProfileSchema.new(9, 0, "Dev")
            local gains = {}
            for i = 1, 3 do
                local copy = table.clone(mission)
                copy.Id = "M-repeat-" .. i
                local _, result = RewardModel.payout(profile, copy, true, 1, 100 * i)
                table.insert(gains, result.Credits)
            end
            T.truthy(gains[2] < gains[1] and gains[3] < gains[2], table.concat(gains, " > "))
            T.truthy(
                not MissionEngine.plausible({ StartedAt = 0, FinishedAt = 1 } :: any, { DistanceM = 1000 } :: any),
                "trop rapide"
            )
        end
    )

    T.test("réputation : cinq niveaux, distincte des classements", function()
        T.equal(#Reputation.Levels, 5)
        T.equal(Reputation.level(0).Name, "Débutant")
        T.equal(Reputation.level(20_000).Name, "Légende")
        T.truthy(Reputation.progress(250) > 0 and Reputation.progress(250) < 1)
    end)

    T.test("équilibrage : revenus horaires bruts comparables entre métiers (simulation)", function()
        local rates = {}
        local open = MissionPlaces.openWorld()
        for _, job in Jobs.List do
            local credits, seconds = 0, 0
            for seed = 1, 40 do
                local mission = MissionGenerator.generate(
                    job.Id,
                    "S",
                    1,
                    open.Road[seed * 7 % #open.Road + 1],
                    open,
                    1,
                    roller(seed),
                    0
                )
                if mission then
                    mission.Difficulty = 2 -- difficulté comparable
                    local quote = RewardModel.quote(ProfileSchema.new(1, 0, "Dev"), mission, 0.85, 0)
                    credits += quote.Credits
                    seconds += mission.EstimatedS
                end
            end
            T.truthy(seconds > 0, job.Id .. " : missions générées en monde ouvert")
            rates[job.Id] = if seconds > 0 then credits / seconds * 3600 else 0
        end
        local low, high = math.huge, 0
        local parts = {}
        for id, rate in rates do
            low = math.min(low, rate)
            high = math.max(high, rate)
            table.insert(parts, string.format("%s %.0f", id, rate))
        end
        table.sort(parts)
        T.truthy(high / low <= 1.35, string.format("écart max/min %.2f", high / low))
        T.note("Crédits/heure bruts estimés (difficulté 2, qualité 0,85) : " .. table.concat(parts, ", "))
    end)
end
