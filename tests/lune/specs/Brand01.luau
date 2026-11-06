--!strict
-- Lot BRAND-01 : nom du jeu, logo et écran de chargement. Contrôles hors Studio : progression réelle (aucune avance
-- sans signal), délai maximal, repli sans logo, textes FR/EN, recopies de la charte et du manifeste, branchements de
-- l'écran dans la place. Le rendu, le fondu, les tailles d'écran et la manette relèvent de l'essai du propriétaire
-- (docs/lot-brand-01/RAPPORT_BRAND_01.md).

return function(T: any, H: any)
    local FIRST = "ReplicatedFirst.AutomotiveWorldFirst."
    local Brand = H.require(FIRST .. "Brand")
    local LoadingTexts = H.require(FIRST .. "LoadingTexts")
    local LoadingProgress = H.require(FIRST .. "LoadingProgress")
    local DesignTokens = H.require("ReplicatedStorage.Shared.UI.DesignTokens")
    local Localization = H.require("ReplicatedStorage.Shared.UI.Localization")
    local AssetManifest = H.require("ReplicatedStorage.Shared.Assets.AssetManifest")

    local function find(path: string): any
        local node = H.game()
        for segment in string.gmatch(path, "[^%.]+") do
            node = node and node:FindFirstChild(segment)
        end
        return node
    end

    -- Signaux : rien de prêt, puis surcharge champ par champ.
    local function signals(over: { [string]: any }?): any
        local s: { [string]: any } = {
            GameLoaded = false,
            ServerReady = false,
            ClientReady = false,
            CharacterReady = false,
            QueueSize = 0,
        }
        for key, value in over or {} do
            s[key] = value
        end
        return s
    end
    local ALL_READY =
        { GameLoaded = true, ServerReady = true, ClientReady = true, CharacterReady = true, QueueSize = 0 }

    -- Fait avancer l'état pendant `seconds` par pas de 1/60 s.
    local function run(state: any, over: { [string]: any }?, seconds: number)
        for _ = 1, math.floor(seconds * 60 + 0.5) do
            LoadingProgress.step(state, signals(over), 1 / 60)
        end
    end

    T.suite("BRAND-01 : écran de chargement et identité")

    T.test("place : écran dans ReplicatedFirst (LocalScript) et modules purs à côté", function()
        T.equal(find(FIRST .. "LoadingScreen").ClassName, "LocalScript")
        for _, name in { "Brand", "LoadingTexts", "LoadingProgress" } do
            T.equal(find(FIRST .. name).ClassName, "ModuleScript", name)
        end
        local source = find(FIRST .. "LoadingScreen").Source
        T.truthy(string.find(source, "RemoveDefaultLoadingScreen", 1, true), "écran par défaut non retiré")
        T.truthy(string.find(source, "RequestQueueSize", 1, true), "file de ContentProvider non lue")
        T.truthy(
            string.find(source, "task.delay(LoadingProgress.Defaults.MaxSeconds", 1, true),
            "filet de sécurité absent"
        )
        T.truthy(string.find(source, "DisplayOrder = 10000", 1, true), "ordre d'affichage")
    end)

    T.test(
        "signal « interface prête » : l'écran AWHud existe bien côté client (sinon délai maximal à chaque fois)",
        function()
            local hud = find("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.UI.HUDController").Source
            T.truthy(string.find(hud, 'Name = "AWHud"', 1, true), "HUDController ne crée plus AWHud")
            local screen = find(FIRST .. "LoadingScreen").Source
            T.truthy(string.find(screen, '"AWHud"', 1, true))
            T.truthy(string.find(screen, '"AutomotiveWorldReady"', 1, true))
            local server = find("ServerScriptService.AutomotiveWorldServer.Bootstrap").Source
            T.truthy(
                string.find(server, "AutomotiveWorldReady", 1, true),
                "le serveur ne publie plus AutomotiveWorldReady"
            )
        end
    )

    T.test("progression : poids des étapes = 1, aucune avance sans signal (pas de fausse barre)", function()
        local total = 0
        for _, step in LoadingProgress.Steps do
            total += step.Weight
        end
        T.near(total, 1, 1e-9)
        local state = LoadingProgress.new()
        run(state, nil, 20)
        T.equal(state.Shown, 0, "la barre a avancé sans aucun signal")
        T.equal(state.Done, false)
        T.equal(state.Phase, "loading.phase.connect")
    end)

    T.test("progression : chaque attente réelle fait avancer la barre, dans l'ordre affiché", function()
        local state = LoadingProgress.new()
        run(state, { GameLoaded = true, QueueSize = 50 }, 2)
        T.near(state.Target, 0.40, 1e-9, "connexion seule (file pleine)")
        T.equal(state.Phase, "loading.phase.server")
        run(state, { GameLoaded = true, ServerReady = true, QueueSize = 25 }, 2)
        T.near(state.Target, 0.40 + 0.15 + 0.20 * 0.5, 1e-9, "serveur + moitié de la file")
        T.equal(state.Phase, "loading.phase.client")
        run(state, { GameLoaded = true, ServerReady = true, ClientReady = true, QueueSize = 25 }, 1)
        T.equal(state.Phase, "loading.phase.character")
        run(
            state,
            { GameLoaded = true, ServerReady = true, ClientReady = true, CharacterReady = true, QueueSize = 25 },
            1
        )
        T.equal(state.Phase, "loading.phase.assets")
        T.equal(state.Done, false)
        run(state, ALL_READY, 0.1)
        T.equal(state.Done, true)
        T.equal(state.Reason, "ready")
        T.equal(state.Shown, 1)
    end)

    T.test("progression : la barre affichée ne recule jamais (file qui regrossit)", function()
        local state = LoadingProgress.new()
        local previous = 0
        for i = 1, 600 do
            local queue = if i < 200 then 100 - i // 2 elseif i < 300 then 400 else 300 - i // 3
            LoadingProgress.step(state, signals({ GameLoaded = true, QueueSize = math.max(queue, 10) }), 1 / 60)
            T.truthy(state.Shown >= previous - 1e-12, "recul à l'étape " .. i)
            previous = state.Shown
        end
    end)

    T.test("affichage minimal : pas d'éclair quand tout est déjà prêt", function()
        local state = LoadingProgress.new()
        run(state, ALL_READY, 0.5)
        T.equal(state.Done, false)
        run(state, ALL_READY, LoadingProgress.Defaults.MinSeconds)
        T.equal(state.Done, true)
        T.equal(state.Reason, "ready")
    end)

    T.test("délai maximal : l'écran se retire même si une attente n'aboutit jamais", function()
        local state = LoadingProgress.new()
        run(
            state,
            { GameLoaded = true, ServerReady = true, CharacterReady = true },
            LoadingProgress.Defaults.MaxSeconds - 0.5
        )
        T.equal(state.Done, false)
        run(state, { GameLoaded = true, ServerReady = true, CharacterReady = true }, 1)
        T.equal(state.Done, true)
        T.equal(state.Reason, "timeout")
        T.equal(state.Phase, "loading.phase.timeout")
        T.truthy(state.Shown < 1, "la barre n'est pas remplie artificiellement au délai maximal")
        -- Une fois terminé, l'état est figé.
        LoadingProgress.step(state, signals(ALL_READY), 1)
        T.equal(state.Reason, "timeout")
        T.truthy(LoadingProgress.Defaults.MaxSeconds <= 30, "délai maximal trop long")
    end)

    T.test("file de ressources qui ne se vide jamais (streaming) : délai de grâce, pas de blocage", function()
        local state = LoadingProgress.new()
        local busy =
            { GameLoaded = true, ServerReady = true, ClientReady = true, CharacterReady = true, QueueSize = 40 }
        run(state, busy, LoadingProgress.Defaults.AssetsGraceSeconds - 0.5)
        T.equal(state.Done, false)
        T.equal(state.Phase, "loading.phase.assets")
        run(state, busy, 1)
        T.equal(state.Done, true)
        T.equal(state.Reason, "ready")
        -- Sous la tolérance, la file compte comme vidée.
        local small = LoadingProgress.new()
        run(
            small,
            { GameLoaded = true, ServerReady = true, ClientReady = true, CharacterReady = true, QueueSize = 3 },
            2
        )
        T.equal(small.Reason, "ready")
    end)

    T.test("fond animé et fondu : tirets dans [-0,1 ; 1,1[ ; fondu nul si « réduire les animations »", function()
        for _, t in { 0, 0.5, 7.3, 1000 } do
            for i = 1, 8 do
                T.between(LoadingProgress.dashX(i, 8, t, 0.05), -0.1, 1.1, "tiret " .. i)
            end
        end
        T.truthy(LoadingProgress.dashX(1, 8, 1, 0.05) ~= LoadingProgress.dashX(1, 8, 0, 0.05), "les tirets défilent")
        T.equal(LoadingProgress.fadeSeconds(true), 0)
        T.truthy(LoadingProgress.fadeSeconds(false) > 0)
    end)

    T.test("repli sans logo : titre en texte tant que l'image n'est pas chargée", function()
        T.equal(Brand.titleMode("None"), "Text")
        T.equal(Brand.titleMode("Pending"), "Text")
        T.equal(Brand.titleMode("Failed"), "Text")
        T.equal(Brand.titleMode("Loaded"), "Image")
        if Brand.logoImageId() == nil then
            T.equal(Brand.logoContent(), nil)
        else
            T.equal(Brand.logoContent(), "rbxassetid://" .. string.format("%d", Brand.logoImageId()))
        end
        T.truthy(Brand.LogoWaitSeconds > 0 and Brand.LogoWaitSeconds < LoadingProgress.Defaults.MaxSeconds)
    end)

    T.test("identité : nom, logo égal au manifeste, couleurs égales à la charte V1.2", function()
        T.equal(Brand.Name, "Amberline")
        local entry = AssetManifest.get("ui.brand.logo")
        T.truthy(entry, "entrée ui.brand.logo absente du manifeste")
        T.equal(entry.RobloxAssetId, Brand.logoImageId(), "identifiant du logo différent entre manifeste et Brand")
        T.equal(#AssetManifest.validate(), 0)
        for name, color in Brand.Colors do
            T.truthy(DesignTokens.Colors[name] == color, "couleur différente de la charte : " .. name)
        end
        T.equal(Brand.FontFamily, DesignTokens.Families.Text)
        T.equal(Brand.LogoAspect, 4)
    end)

    T.test("textes : FR/EN complets, langue déduite du compte, aucune clé en double avec la localisation", function()
        local count = 0
        for key, entry in LoadingTexts.Entries do
            count += 1
            T.equal(#entry, 2, key)
            T.truthy(entry[1] ~= "" and entry[2] ~= "", key)
            T.truthy(not Localization.has(key), "clé déjà présente dans Localization : " .. key)
        end
        T.truthy(count >= 8)
        for _, step in LoadingProgress.Steps do
            T.truthy(LoadingTexts.Entries["loading.phase." .. step.Id], "texte d'étape absent : " .. step.Id)
        end
        for _, key in { "loading.welcome", "loading.phase.ready", "loading.phase.timeout" } do
            T.truthy(LoadingTexts.Entries[key], key)
        end
        T.equal(LoadingTexts.languageFor("fr-fr"), "fr")
        T.equal(LoadingTexts.languageFor("FR-CA"), "fr")
        T.equal(LoadingTexts.languageFor("en-us"), "en")
        T.equal(LoadingTexts.languageFor("de-de"), "en")
        T.equal(LoadingTexts.languageFor(nil), "en")
        T.equal(LoadingTexts.t("loading.welcome", "fr"), "Bienvenue à Valcourt")
        T.equal(LoadingTexts.t("loading.welcome", "en"), "Welcome to Valcourt")
        T.equal(LoadingTexts.t("cle.inconnue", "fr"), "cle.inconnue")
    end)
end
