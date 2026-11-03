--!strict
-- Lot 0.4 — persistance : environnements, schéma, migrations, verrou de
-- session, écritures obsolètes, réponses incertaines, idempotence.
-- Exécuté sur l'adaptateur MÉMOIRE : la persistance réelle (DataStore) reste
-- NON TESTÉE (docs/QA_BACKLOG.md).

local SERVER = "ServerScriptService.AutomotiveWorldServer."

return function(T: any, H: any)
    local Environment = H.require(SERVER .. "Persistence.Environment")
    local EnvironmentConfig = H.require(SERVER .. "Persistence.EnvironmentConfig")
    local ProfileSchema = H.require(SERVER .. "Persistence.ProfileSchema")
    local ProfileMigration = H.require(SERVER .. "Persistence.ProfileMigration")
    local ProfileRepository = H.require(SERVER .. "Persistence.ProfileRepository")
    local MemoryProfileRepository = H.require(SERVER .. "Persistence.MemoryProfileRepository")
    local ProfileSession = H.require(SERVER .. "Persistence.ProfileSession")
    local StructuredLog = H.require(SERVER .. "Persistence.StructuredLog")
    local PropertyRules = H.require(SERVER .. "Progression.PropertyRules")

    local USER = 4242

    local function harness()
        local clock = { Now = 1000 }
        local counter = 0
        local repo = MemoryProfileRepository.new()
        local log = StructuredLog.new(50, function()
            return clock.Now
        end)
        local function session(name: string, extra: any?): any
            local options: any = {
                Repository = repo,
                Key = ProfileRepository.keyFor(USER),
                UserId = USER,
                Session = name,
                Server = "job-" .. name,
                Environment = "Dev",
                Clock = function()
                    return clock.Now
                end,
                Token = function()
                    counter += 1
                    return "tok" .. counter
                end,
                Log = log,
                LockTtl = 300,
                MinWriteInterval = 6,
            }
            for key, value in extra or {} do
                options[key] = value
            end
            return ProfileSession.new(options)
        end
        return clock, repo, session, log
    end

    local function stored(repo: any): any
        return repo.Store[ProfileRepository.keyFor(USER)]
    end

    T.suite("Lot 0.4 — environnements de stockage (AUD-ENV-01)")

    T.test("aucune expérience déclarée : tout s'exécute en mémoire, jamais en DataStore", function()
        T.equal(#EnvironmentConfig.TestGameIds, 0)
        T.equal(#EnvironmentConfig.ProdGameIds, 0)
        for _, studio in { true, false } do
            local resolved = Environment.resolve(123456, studio, EnvironmentConfig)
            T.equal(resolved.Name, "Dev")
            T.equal(resolved.Store, "Memory")
        end
    end)

    T.test("test et production séparés ; Studio sur la production retombe en mémoire", function()
        local config = { TestGameIds = { 11 }, ProdGameIds = { 22 }, SchemaTag = "v1" }
        local test = Environment.resolve(11, false, config)
        T.equal(test.Name, "Test")
        T.equal(test.StoreName, "AW_TEST_Profiles_v1")
        local prod = Environment.resolve(22, false, config)
        T.equal(prod.Name, "Prod")
        T.equal(prod.StoreName, "AW_PROD_Profiles_v1")
        local studio = Environment.resolve(22, true, config)
        T.equal(studio.Store, "Memory")
        T.equal(studio.Reason, "StudioOnProduction")
        T.truthy(test.StoreName ~= prod.StoreName, "noms de magasins distincts")
        T.truthy(Environment.allowsSynthetic(Environment.resolve(1, true, config)), "synthétique en Dev")
        T.truthy(not Environment.allowsSynthetic(test) and not Environment.allowsSynthetic(prod), "jamais en test/prod")
    end)

    T.test("clé de profil stable fondée sur le UserId", function()
        T.equal(ProfileRepository.keyFor(42), "Profile_42")
        T.truthy(not pcall(ProfileRepository.keyFor, 0), "UserId 0 refusé")
    end)

    T.suite("Lot 0.4 — verrou de session et écritures (adaptateur mémoire)")

    T.test("création, sauvegarde confirmée, libération, rechargement", function()
        local clock, repo, session = harness()
        local a = session("A")
        T.equal(a:load(), "Active")
        T.equal(a.Data.UserId, USER)
        T.equal(a:save(), "Throttled", "la prise de verrou vient d'écrire (budget par clé)")
        clock.Now += 7
        T.equal(a:save(), "Saved")
        clock.Now += 10
        T.equal(a:save(true), "Released")
        T.truthy(stored(repo).Meta.Lock == nil, "verrou libéré")
        local b = session("B")
        T.equal(b:load(), "Active")
        T.equal(b.Data.CreatedAt, 1000)
    end)

    T.test("verrou détenu : une seconde session est refusée, puis reprend un verrou expiré", function()
        local clock, repo, session, log = harness()
        local a = session("A")
        a:load()
        a:save()
        local b = session("B")
        T.equal(b:load(), "Locked")
        clock.Now += 301
        local c = session("C")
        T.equal(c:load(), "Active")
        T.equal(stored(repo).Meta.Recovered, 1)
        local recovered = false
        for _, entry in log:list() do
            if entry.Event == "ProfileLockRecovered" then
                recovered = true
            end
        end
        T.truthy(recovered, "reprise journalisée")
    end)

    T.test("un ancien serveur ne peut pas écraser un état plus récent", function()
        local clock, repo, session = harness()
        local old = session("Old")
        old:load()
        old:save()
        clock.Now += 400 -- l'ancien serveur ne rafraîchit plus son verrou
        local new = session("New")
        T.equal(new:load(), "Active")
        new:mutate(function(profile)
            profile.Counters.Vehicle = 77
            return true
        end)
        clock.Now += 7
        T.equal(new:save(), "Saved")
        old:mutate(function(profile)
            profile.Counters.Vehicle = 1
            return true
        end)
        clock.Now += 7
        T.equal(old:save(), "Lost")
        T.equal(old.State, "Lost")
        T.equal(stored(repo).Data.Counters.Vehicle, 77, "état récent préservé")
        T.equal(
            old:commit("C:abcdefgh1", "Test", function()
                return true, nil
            end).Status,
            "Unavailable"
        )
    end)

    T.test("génération périmée : écriture refusée (aucune écriture obsolète)", function()
        local clock, repo, session = harness()
        local a = session("A")
        a:load()
        a.Generation -= 1 -- simule une lecture périmée
        a:mutate(function()
            return true
        end)
        clock.Now += 7
        local before = stored(repo).Meta.Generation
        T.equal(a:save(), "Lost")
        T.equal(stored(repo).Meta.Generation, before)
    end)

    T.test("réponse incertaine appliquée : réconciliée, confirmée, jamais rejouée", function()
        local clock, repo, session = harness()
        local a = session("A")
        a:load()
        clock.Now += 7
        repo:inject("UncertainApplied")
        local result = a:commit("C:request-0001", "Test", function(profile)
            profile.Counters.Vehicle += 1
            return true, "fait"
        end)
        T.equal(result.Status, "Confirmed")
        T.equal(stored(repo).Data.Counters.Vehicle, 1, "appliquée une seule fois")
        local again = a:commit("C:request-0001", "Test", function(profile)
            profile.Counters.Vehicle += 1
            return true, "fait"
        end)
        T.equal(again.Status, "Duplicate")
        T.equal(again.Result, "fait")
        T.equal(a.Data.Counters.Vehicle, 1)
    end)

    T.test("réponse incertaine perdue ou échec : en attente, puis confirmée par la sauvegarde suivante", function()
        local clock, repo, session = harness()
        local a = session("A")
        a:load()
        clock.Now += 7
        repo:inject("UncertainLost")
        local first = a:commit("C:request-0002", "Test", function(profile)
            profile.Counters.Part += 1
            return true, nil
        end)
        T.equal(first.Status, "Pending")
        T.truthy(a:isPending("C:request-0002"), "en attente")
        repo:inject("Failed")
        clock.Now += 7
        T.equal(a:tick(), "Failed")
        clock.Now += 7
        T.equal(a:tick(), "Saved")
        T.equal(stored(repo).Data.Counters.Part, 1)
        local confirmed = a:takeConfirmed()
        T.equal(confirmed[1], "C:request-0002")
        T.truthy(not a:isPending("C:request-0002"), "plus en attente")
    end)

    T.test("budget par clé : deux transactions en moins de 6 s → la seconde attend", function()
        local clock, _, session = harness()
        local a = session("A")
        a:load()
        clock.Now += 7
        T.equal(
            a:commit("C:request-0003", "Test", function()
                return true, nil
            end).Status,
            "Confirmed"
        )
        clock.Now += 1
        T.equal(
            a:commit("C:request-0004", "Test", function()
                return true, nil
            end).Status,
            "Pending"
        )
        T.equal(a:tick(), "Throttled")
        clock.Now += 6
        T.equal(a:tick(), "Saved")
    end)

    T.test("mutation refusée : profil inchangé ; profil incohérent : refusé", function()
        local clock, _, session = harness()
        local a = session("A")
        a:load()
        clock.Now += 7
        local refused = a:commit("C:request-0005", "Test", function(profile)
            profile.Counters.Vehicle = 999
            return false, "Nope"
        end)
        T.equal(refused.Status, "Rejected")
        T.equal(a.Data.Counters.Vehicle, 0)
        local broken = a:commit("C:request-0006", "Test", function(profile)
            profile.Properties.X = { Id = "X" }
            return true, nil
        end)
        T.equal(broken.Status, "Rejected")
        T.truthy(a.Data.Properties.X == nil, "aucune donnée incohérente")
    end)

    T.test("stockage indisponible : opérations persistantes suspendues (AUD-DATA-01)", function()
        local _, repo, session = harness()
        repo.Unavailable = true
        local a = session("A")
        T.equal(a:load(), "Unavailable")
        T.equal(
            a:commit("C:request-0007", "Test", function()
                return true, nil
            end).Status,
            "Unavailable"
        )
    end)

    T.test("suspension ciblée des opérations sensibles (AUD-INC-01)", function()
        local reason: string? = "incident"
        local clock, _, session = harness()
        local a = session("A", {
            Suspended = function()
                return reason
            end,
        })
        a:load()
        clock.Now += 7
        local refused = a:commit("C:request-0009", "Test", function()
            return true, nil
        end)
        T.equal(refused.Status, "Unavailable")
        T.equal(refused.Error, "WritesSuspended")
        reason = nil
        T.equal(
            a:commit("C:request-0009", "Test", function()
                return true, nil
            end).Status,
            "Confirmed"
        )
    end)

    T.test("verrou rafraîchi périodiquement même sans modification", function()
        local clock, repo, session = harness()
        local a = session("A")
        a:load()
        a:save()
        local expires = stored(repo).Meta.Lock.ExpiresAt
        clock.Now += 101
        T.equal(a:tick(), "Saved")
        T.truthy(stored(repo).Meta.Lock.ExpiresAt > expires, "échéance repoussée")
    end)

    T.test("journal des transactions borné", function()
        local clock, _, session = harness()
        local a = session("A")
        a:load()
        for i = 1, 130 do
            clock.Now += 7
            a:commit("C:bulk-request-" .. i, "Test", function()
                return true, nil
            end)
        end
        local count = 0
        for _ in a.Data.Transactions do
            count += 1
        end
        T.equal(count, ProfileSchema.MaxRecentTransactions)
    end)

    T.test("journal structuré borné, sans champ complexe", function()
        local log = StructuredLog.new(3, function()
            return 0
        end)
        for i = 1, 5 do
            log:write("Info", "E" .. i, { N = i, Table = { 1 }, Text = string.rep("x", 200) })
        end
        local list = log:list()
        T.equal(#list, 3)
        T.equal(list[1].Event, "E3")
        T.truthy(list[3].Fields.Table == nil, "table filtrée")
        T.equal(#list[3].Fields.Text, 64)
    end)

    T.suite("Lot 0.4 — schéma et migrations (AUD-MIG-01)")

    T.test("profil neuf valide ; version courante sans migration", function()
        local profile = ProfileSchema.new(USER, 0, "Dev")
        T.truthy((ProfileSchema.validate(profile)), "valide")
        T.equal(ProfileMigration.migrate(profile).Status, "Current")
    end)

    T.test("migration injectée : copie, données conservées, champ retiré gardé dans Legacy", function()
        local raw: any = ProfileSchema.new(USER, 0, "Dev")
        raw.OldField = "à conserver"
        raw.Unknown = { Keep = true }
        local migrations = {
            {
                From = 1,
                Describe = "essai",
                Apply = function(data)
                    ProfileMigration.retire(data, "OldField")
                    data.SchemaVersion = 2
                    return data
                end,
            },
        }
        local result = ProfileMigration.migrate(raw, 2, migrations)
        T.equal(result.Status, "Migrated")
        T.equal(result.Data.Legacy.OldField, "à conserver")
        T.truthy(result.Data.Unknown.Keep, "champ inconnu conservé")
        T.equal(raw.SchemaVersion, 1, "original intact")
        T.equal(ProfileMigration.migrate(raw, 3, migrations).Status, "Invalid", "migration manquante")
    end)

    T.test("donnée d'une version plus récente : lecture seule, jamais réécrite", function()
        local clock, repo, session = harness()
        local newer: any = ProfileSchema.new(USER, 0, "Dev")
        newer.SchemaVersion = ProfileSchema.Version + 1
        repo.Store[ProfileRepository.keyFor(USER)] =
            { Format = 1, Meta = { Generation = 5, LastWriteAt = 0 }, Data = newer }
        local a = session("A")
        T.equal(a:load(), "ReadOnly")
        T.equal(a.Detail, "SchemaNewer")
        T.equal(
            a:commit("C:request-0008", "Test", function()
                return true, nil
            end).Status,
            "Unavailable"
        )
        clock.Now += 10
        a:save(true)
        T.equal(stored(repo).Data.SchemaVersion, ProfileSchema.Version + 1, "donnée récente intacte")
        T.truthy(stored(repo).Meta.Lock == nil, "verrou rendu")
    end)

    T.test("profil d'un autre environnement : lecture seule (aucun transfert d'actifs de test)", function()
        local _, repo, session = harness()
        local foreign = ProfileSchema.new(USER, 0, "Test")
        repo.Store[ProfileRepository.keyFor(USER)] =
            { Format = 1, Meta = { Generation = 1, LastWriteAt = 0 }, Data = foreign }
        local a = session("A")
        T.equal(a:load(), "ReadOnly")
        T.equal(a.Detail, "EnvironmentMismatch")
    end)

    T.test("validation : place occupée deux fois et pièce orpheline détectées", function()
        local profile: any = ProfileSchema.new(USER, 0, "Dev")
        PropertyRules.grantFree(profile, 0)
        local propertyId = profile.Grants.FreeProperty.Ref
        for i = 1, 2 do
            local id = "V-" .. USER .. "-" .. i
            profile.Vehicles[id] = {
                Schema = 1,
                Id = id,
                ModelId = "m",
                OwnerUserId = USER,
                AcquiredAt = 0,
                Origin = "Test",
                Untransferable = false,
                Synthetic = true,
                OdometerKm = 0,
                Energy = 1,
                Damage = ProfileSchema.pristineDamage(),
                InstalledParts = {},
                Tuning = {},
                Cosmetics = {},
                Configurations = {},
                Storage = { State = "Displayed", PropertyId = propertyId, Slot = 1 },
                UpdatedAt = 0,
            }
        end
        profile.Parts["PT-1"] = {
            Id = "PT-1",
            PartId = "TIRE-SPORT",
            AcquiredAt = 0,
            Origin = "Test",
            InstalledOn = "V-x",
            Synthetic = true,
        }
        local ok, errors = ProfileSchema.validate(profile)
        T.truthy(not ok, "invalide")
        local joined = table.concat(errors, " ")
        T.truthy(string.find(joined, "SlotTaken") ~= nil, joined)
        T.truthy(string.find(joined, "PartOrphan") ~= nil, joined)
    end)
end
