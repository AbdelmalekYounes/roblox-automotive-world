--!strict
local Fixtures = require("../fixtures/Fixtures")
-- Lot UI-01 : système de conception UI PREMIUM V1.2. Contrôles hors Studio des jetons (valeurs des maquettes du
-- propriétaire, contrastes calculés, tailles, résolutions, animations). Le rendu (polices, focus, captures) relève de
-- la VM (session « ui_design »).

return function(T: any, H: any)
    local Tokens = H.require("ReplicatedStorage.Shared.UI.DesignTokens")

    local function hex(color: Color3): string
        return string.format(
            "#%02X%02X%02X",
            math.floor(color.R * 255 + 0.5),
            math.floor(color.G * 255 + 0.5),
            math.floor(color.B * 255 + 0.5)
        )
    end

    T.suite("UI-01 — système de conception V1.2 (jetons)")

    T.test("1. couleurs : valeurs exactes de la maquette", function()
        local expected = {
            BgBase = "#0E0F11",
            BgChrome = "#121416",
            Surface1 = "#16181B",
            Surface2 = "#1E2125",
            Surface2Hover = "#262A2F",
            Line = "#33363C",
            Text = "#ECEAE6",
            TextMuted = "#A3A29C",
            TextOnAmber = "#15120B",
            Amber = "#E8A33D",
            AmberSoft = "#2A2416",
            AmberSoftText = "#F4BE6A",
            GpsCyan = "#5CC8D6",
            RaceRed = "#E5534B",
            Ok = "#7FCF9C",
            WarnBg = "#1E1A10",
            WarnLine = "#6B5A2E",
            WarnText = "#F1E3C4",
            DangerBg = "#2A1715",
            DangerText = "#F2C9C5",
            OkBg = "#132219",
            OkText = "#BFE6CC",
            Stage3D = "#2A2E34",
            AppTile = "#1A1D21",
        }
        for name, value in expected do
            T.equal(hex(Tokens.Colors[name]), value, name)
        end
        T.equal(hex(Tokens.color("Line", true)), "#6B6F77", "bordure en contraste renforcé")
        T.equal(hex(Tokens.color("TextMuted", true)), "#D9D7D2", "texte secondaire en contraste renforcé")
        T.equal(hex(Tokens.color("Amber", true)), "#E8A33D", "sans variante : couleur normale")
    end)

    T.test("2. contrastes : texte ≥ 4,5:1 partout (valeurs annoncées par la maquette retrouvées)", function()
        local c = Tokens.Colors
        local text = Tokens.contrast(c.Text, c.BgBase)
        T.truthy(math.abs(text - 15.9) < 0.15, string.format("texte sur fond : %.2f:1 (maquette 15,9:1)", text))
        local muted = Tokens.contrast(c.TextMuted, c.BgBase)
        T.truthy(math.abs(muted - 7.4) < 0.15, string.format("texte secondaire : %.2f:1 (maquette 7,4:1)", muted))
        local pairs_ = {
            { "Text", "Surface1" },
            { "Text", "Surface2" },
            { "Text", "Surface2Hover" },
            { "TextMuted", "Surface1" },
            { "TextMuted", "Surface2" },
            { "TextOnAmber", "Amber" },
            { "AmberSoftText", "AmberSoft" },
            { "WarnText", "WarnBg" },
            { "DangerText", "DangerBg" },
            { "OkText", "OkBg" },
            { "Amber", "BgBase" },
            { "GpsCyan", "BgBase" },
            { "RaceRed", "BgBase" },
            { "Ok", "BgBase" },
        }
        for _, pair in pairs_ do
            local ratio = Tokens.contrast(c[pair[1]], c[pair[2]])
            T.truthy(ratio >= Tokens.MinContrast, string.format("%s sur %s : %.2f:1", pair[1], pair[2], ratio))
        end
        T.truthy(
            Tokens.contrast(Tokens.color("TextMuted", true), c.Surface2) > Tokens.contrast(c.TextMuted, c.Surface2),
            "le contraste renforcé augmente bien le contraste"
        )
    end)

    T.test("3. typographie : deux familles, aucun texte sous 11 px, échelle 80 à 150 %", function()
        local families = {}
        for name, style in Tokens.Type do
            families[style.Family] = true
            T.truthy(style.Size >= Tokens.MinTextSize, name .. " ≥ 11 px")
        end
        T.truthy(families.TitilliumWeb and families.RobotoMono, "Titillium Web et Roboto Mono")
        local n = 0
        for _ in families do
            n += 1
        end
        T.equal(n, 2, "deux polices seulement")
        T.equal(Tokens.textSize("Body", 100), 14, "corps 14")
        T.equal(Tokens.textSize("Label", 80), 11, "libellé 12 à 80 % : minimum 11")
        T.equal(Tokens.textSize("Label", 50), 11, "réglage borné à 80 %")
        T.equal(Tokens.textSize("H1", 150), 42, "titre 28 à 150 %")
        T.equal(Tokens.textSize("H1", 300), 42, "réglage borné à 150 %")
        T.equal(Tokens.Type.Race.Italic, true, "chiffres de course en italique")
    end)

    T.test("4. mesures : pas de 4, cibles ≥ 32 px, bouton principal 44 px", function()
        for _, step in Tokens.Space do
            T.equal(step % 4, 0, "espacement multiple de 4")
        end
        T.equal(Tokens.PrimaryButtonHeight, 44, "bouton principal")
        T.truthy(Tokens.MinTarget >= 32 and Tokens.MinTargetPartChip >= 36, "cibles minimales")
        T.equal(Tokens.Radius.Button, 4, "rayon des boutons")
        T.equal(Tokens.Radius.Card, 6, "rayon des cartes")
        T.equal(Tokens.FocusStroke, 2, "contour de focus 2 px")
    end)

    T.test("5. résolutions : 1440 p à l'échelle 1,333 ; disposition compacte sous 1400 px logiques", function()
        local cases = {
            { 2560, 1440, 1.333, false },
            { 1920, 1080, 1, false },
            { 1366, 768, 1, true },
            { 1280, 720, 1, true },
        }
        for _, case in cases do
            local layout = Tokens.layout(case[1], case[2])
            T.truthy(
                math.abs(layout.Scale - case[3]) < 0.001,
                string.format("%d×%d : échelle %.3f", case[1], case[2], layout.Scale)
            )
            T.equal(layout.Compact, case[4], string.format("%d×%d : compacte %s", case[1], case[2], tostring(case[4])))
        end
        local garage = Tokens.Garage
        T.equal(1920 - garage.SidePanel.Vehicle[1], 1500, "zone 3D du Véhicule en 1080 p : largeur restante 1500")
        T.equal(1080 - garage.TopBar - garage.Tabs - garage.HelpBar, 936, "zone 3D : hauteur − 144 = 936")
    end)

    T.test("6. animations : durées de la maquette, toutes à 0 si « réduire les animations »", function()
        T.equal(Tokens.duration("PanelOpen"), 0.16, "ouverture de panneau 160 ms")
        T.equal(Tokens.duration("Present"), 0.22, "présentation du véhicule 220 ms")
        T.equal(Tokens.duration("CameraView"), 0.4, "vue de caméra 400 ms")
        for name in Tokens.Motion do
            T.equal(Tokens.duration(name, true), 0, name .. " : réduite à 0")
        end
        T.truthy(Tokens.NotificationShowS >= 3.5 and Tokens.NotificationShowS <= 4, "notification 3,5 à 4 s")
    end)

    T.test("7. états de sauvegarde : six états, « Confirmed » réservé au serveur", function()
        T.equal(table.concat(Tokens.SaveStates, ","), "Loading,Draft,Pending,Confirmed,Rejected,Offline", "six états")
        T.equal(Tokens.StatusRailColor.Gps, "GpsCyan", "filet GPS cyan")
        T.equal(Tokens.StatusRailColor.Pending, "Amber", "filet en attente ambre")
        T.equal(Tokens.StatusRailColor.Done, "Ok", "filet réussi vert")
    end)

    T.test("8. capitales des libellés : lettres accentuées comprises", function()
        T.equal(Tokens.upper("Réglages"), "RÉGLAGES", "é")
        T.equal(Tokens.upper("Préparation à l'arrêt"), "PRÉPARATION À L'ARRÊT", "é, à, ê")
        T.equal(Tokens.upper("Cœur, façade, où"), "CŒUR, FAÇADE, OÙ", "œ, ç, ù")
    end)

    T.suite("UI-02 — téléphone V1.2")

    local game = H.game()
    local function source(path: string): string
        local node = game
        for segment in string.gmatch(path, "[^%.]+") do
            node = node:FindFirstChild(segment)
            assert(node, path)
        end
        return node.Source
    end

    T.test(
        "1. icônes : 12 applications, déclarées au manifeste avec l'image envoyée par le propriétaire",
        function()
            local Icons = H.require("ReplicatedStorage.Shared.UI.PhoneIcons")
            local Manifest = H.require("ReplicatedStorage.Shared.Assets.AssetManifest")
            T.equal(#Icons.Apps, 12, "12 applications")
            local seen = {}
            for _, app in Icons.Apps do
                local entry = Manifest.get("ui.icon.phone." .. string.lower(app))
                T.truthy(entry ~= nil, app .. " : entrée du manifeste")
                local id = entry.RobloxAssetId
                T.truthy(
                    id ~= nil and id == Manifest.PhoneIconIds[app],
                    app .. " : identifiant de la table du propriétaire"
                )
                T.truthy(not seen[id], app .. " : identifiant distinct")
                seen[id] = true
                T.equal(Icons.image(app), "rbxassetid://" .. tostring(id), app .. " : image servie par contentId")
            end
            T.equal(Icons.tint("Map"), "GpsCyan", "carte en cyan")
            T.equal(Icons.tint("Radio"), "Amber", "autres en ambre")
            T.equal(#Manifest.validate(), 0, "manifeste cohérent")
        end
    )

    T.test("2. téléphone : aucun caractère Unicode en guise d'icône, tailles de la maquette", function()
        local phone = source("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.UI.PhoneController")
        for _, glyph in { "🗺", "🚗", "⌂", "★", "🏁", "☺", "♪", "◎", "⚙", "🔔", "🔍", "←" } do
            T.truthy(string.find(phone, glyph, 1, true) == nil, "glyphe absent : " .. glyph)
        end
        for _, needle in
            -- 2026-11-05 : coque de smartphone moderne demandée par le propriétaire (coins 54 / 44 px au lieu des
            -- rayons 34 / 26 de la maquette), pastille, barre d'accueil et dock.
            { "PhoneIcons.image", "Tokens.Phone", "BarreAccueil", "Pastille", "Dock", "PhoneResize" }
        do
            T.truthy(string.find(phone, needle, 1, true) ~= nil, needle)
        end
        T.truthy(Tokens.Phone.Normal.X == 380 and Tokens.Phone.Normal.Y == 780, "taille normale 380 × 780")
        T.truthy(Tokens.Phone.Enlarged.X == 460 and Tokens.Phone.Enlarged.Y == 940, "taille agrandie 460 × 940")
        T.truthy(
            Tokens.Phone.CompactNormal.X == 330 and Tokens.Phone.CompactNormal.Y == 600,
            "taille compacte 330 × 600"
        )
    end)

    T.suite("UI-03 — aperçu 3D du garage (ViewportFrame)")

    T.test("1. cadrage serré : véhicule entier à toutes les orientations, tangent à la plus large", function()
        local Framing = H.require("ReplicatedStorage.Shared.UI.PreviewFraming")
        local fov, pitch, m = Framing.Fov, Framing.Pitch, Framing.Margin
        local tanV = math.tan(math.rad(fov) / 2)
        -- Projection indépendante (CFrame recomposé à la main) : plus grande occupation de la zone par un coin.
        local function occupancy(hx: number, hy: number, hz: number, aspect: number, d: number, deg: number): number
            local tanH = tanV * aspect
            local a, p = math.rad(deg), math.rad(pitch)
            local worst = 0
            for _, sx in { -1, 1 } do
                for _, sy in { -1, 1 } do
                    for _, sz in { -1, 1 } do
                        local x, y, z = sx * hx, sy * hy, sz * hz
                        local x1, z1 = x * math.cos(a) - z * math.sin(a), x * math.sin(a) + z * math.cos(a)
                        local y2, z2 = y * math.cos(p) - z1 * math.sin(p), y * math.sin(p) + z1 * math.cos(p)
                        local depth = d - z2
                        worst = math.max(worst, math.abs(x1) / (depth * tanH), math.abs(y2) / (depth * tanV))
                    end
                end
            end
            return worst
        end
        -- Boîtes réelles : prototype (≈ 4,6 × 1,8 × 1,5 m) et Comète (≈ 4,5 × 1,9 × 1,2 m), en studs.
        for _, box in { { 3.3, 2.7, 8.3 }, { 3.5, 2.2, 8.1 } } do
            for _, aspect in { 0.8, 1.2, 1.8 } do
                local d = Framing.fitDistance(box[1], box[2], box[3], fov, aspect, pitch)
                local peak = 0
                for deg = 0, 359 do
                    peak = math.max(peak, occupancy(box[1], box[2], box[3], aspect, d, deg))
                end
                -- Entre deux orientations échantillonnées (5°), l'écart reste sous 1 % de la zone.
                T.truthy(peak <= 1 / m + 0.01, string.format("jamais coupé (%.3f), rapport %.1f", peak, aspect))
                T.truthy(
                    peak >= 1 / m - 0.001,
                    string.format("tangent avec la marge (%.3f), rapport %.1f", peak, aspect)
                )
                -- Plus près qu'un cadrage sur la sphère englobante (l'ancien réglage, marge 1,08).
                local r = math.sqrt(box[1] ^ 2 + box[2] ^ 2 + box[3] ^ 2)
                local limiting = math.min(math.rad(fov) / 2, math.atan(tanV * aspect))
                T.truthy(d < r * 1.08 / math.sin(limiting), "plus grand qu'avec la sphère, rapport " .. aspect)
            end
        end
    end)

    T.test("2. demandes au serveur : seul un identifiant de modèle bien formé passe", function()
        local Framing = H.require("ReplicatedStorage.Shared.UI.PreviewFraming")
        T.truthy(Framing.validModelId("wk_comete"), "wk_comete")
        T.truthy(Framing.validModelId("proto_p01"), "proto_p01")
        for _, bad in { "", string.rep("a", 65), "../x", "a b", "Comète", 12, nil, {} } do
            T.truthy(not Framing.validModelId(bad), "refusé : " .. tostring(bad))
        end
        T.truthy(Framing.RequestInterval > 0, "délai minimal entre deux demandes")
    end)

    T.test("3. rotation : automatique, glisser, stick, réduite à [0, 360[", function()
        local Framing = H.require("ReplicatedStorage.Shared.UI.PreviewFraming")
        T.equal(Framing.step(0, 1, true, 0, 0), Framing.AutoSpeed, "rotation automatique")
        T.equal(Framing.step(10, 1, false, 0, 0), 10, "sans rotation automatique (réduire les animations)")
        T.equal(Framing.step(100, 0, false, 10, 0), 100 - 10 * Framing.DragSpeed, "glisser")
        T.equal(Framing.step(100, 1, false, 0, 0.1), 100, "stick dans la zone morte")
        T.equal(Framing.step(100, 0.5, false, 0, 1), (100 - Framing.StickSpeed * 0.5) % 360, "stick à fond")
        T.equal(Framing.step(350, 1, true, 0, 0), (350 + Framing.AutoSpeed) % 360, "retour sous 360")
    end)

    T.test("4. service serveur : copie inerte, lecture seule, branché au démarrage et au garage", function()
        local service = source("ServerScriptService.AutomotiveWorldServer.Vehicles.VehiclePreviewService")
        for _, needle in
            {
                "RemoveTag(model, Constants.VehicleTag)",
                "item.Anchored = true",
                "item.CanCollide = false",
                "item.CanQuery = false",
                "PreviewFraming.validModelId(modelId)",
                "VehicleDefinitions.get(modelId)",
                "PreviewFraming.RequestInterval",
            }
        do
            T.truthy(string.find(service, needle, 1, true) ~= nil, needle)
        end
        for _, forbidden in { "ProfileService", "DataStore", "SetAsync", "UpdateAsync" } do
            T.truthy(string.find(service, forbidden, 1, true) == nil, "absent : " .. forbidden)
        end
        local boot = source("ServerScriptService.AutomotiveWorldServer.Bootstrap")
        T.truthy(string.find(boot, "VehiclePreviewService.start()", 1, true) ~= nil, "démarré par le serveur")
        local garage = source("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.UI.GaragePanel")
        for _, needle in { "VehiclePreview.attach(stage)", "VehiclePreview.show(", "VehiclePreview.setActive(" } do
            T.truthy(string.find(garage, needle, 1, true) ~= nil, needle)
        end
    end)

    T.suite("UI-03 — garage V1.2 recomposé (règles de présentation)")

    local View = H.require("ReplicatedStorage.Shared.UI.GarageView")

    T.test("1. navigation : six onglets en boucle, retour d'un niveau puis fermeture", function()
        T.equal(#View.Tabs, 6, "six onglets")
        T.equal(View.cycleTab("Collection", 1), "Véhicule", "suivant")
        T.equal(View.cycleTab("Collection", -1), "Invitations", "précédent en boucle")
        T.equal(View.cycleTab("Invitations", 1), "Collection", "suivant en boucle")
        T.equal(View.backTab("Préparation"), "Véhicule", "Préparation → Véhicule")
        T.equal(View.backTab("Configurations"), "Véhicule", "Configurations → Véhicule")
        T.equal(View.backTab("Véhicule"), "Collection", "Véhicule → Collection")
        T.equal(View.backTab("Propriétés"), "Collection", "Propriétés → Collection")
        T.equal(View.backTab("Collection"), nil, "Collection → fermer")
    end)

    T.test(
        "2. états du serveur : en attente, confirmé, refusé, hors ligne ; jamais confirmé par défaut",
        function()
            T.equal(View.statusKind("Pending"), "Pending")
            T.equal(View.statusKind("Confirmed"), "Confirmed")
            T.equal(View.statusKind("Rejected"), "Rejected")
            T.equal(View.statusKind("Unavailable"), "Offline")
            T.equal(View.statusKind(nil), "Offline", "appel échoué = hors ligne")
            T.equal(View.statusKind("Ok"), "Info", "lecture : ni confirmé ni refusé")
            local bg, fg = View.statusTokens("Confirmed")
            T.truthy(bg == "OkBg" and fg == "OkText", "confirmé en vert")
            bg, fg = View.statusTokens("Offline")
            T.truthy(bg == "DangerBg" and fg == "DangerText", "hors ligne en rouge")
            bg = View.statusTokens("Pending")
            T.equal(bg, "AmberSoft", "en attente en ambre")
            T.truthy(View.inGarage({ Kind = "Property" }) and View.inGarage({ Kind = "PublicGarage" }), "au garage")
            T.truthy(not View.inGarage({ Kind = "Visit" }) and not View.inGarage(nil), "hors garage")
        end
    )

    T.test("3. actions du véhicule : disponibilités et raisons conformes aux règles du serveur", function()
        local property = { Id = "P1", Capacity = 2, Slots = { ["1"] = "V9" } }
        local inProp = { Context = { Kind = "Property", PropertyId = "P1" } }
        local stored = { Id = "V1", Storage = { State = "Stored" } }
        local a = View.vehicleActions(stored, inProp, property)
        T.truthy(a.TakeOut.Enabled, "sortir possible")
        T.truthy(a.Display.Enabled and a.Display.Slot == 2, "exposer à la première place libre")
        T.truthy(not a.Store.Enabled and a.Store.Reason == "Déjà rangé", "ranger : déjà rangé")
        local displayed = { Id = "V1", Storage = { State = "Displayed" } }
        a = View.vehicleActions(displayed, inProp, property)
        T.truthy(a.Store.Enabled and a.Store.Kind == "Store", "ranger un véhicule exposé")
        local out = { Id = "V1", Storage = { State = "Out" } }
        a = View.vehicleActions(out, { Context = {} }, nil)
        T.truthy(a.Store.Enabled and a.Store.Kind == "Return", "rentrer un véhicule sorti")
        T.truthy(not a.TakeOut.Enabled, "déjà sorti")
        a = View.vehicleActions(stored, { Context = {}, OutVehicle = "V2" }, nil)
        T.truthy(not a.TakeOut.Enabled and a.TakeOut.Reason == "Un autre véhicule est déjà sorti", "un seul sorti")
        T.truthy(
            not a.Display.Enabled and a.Display.Reason == "Exige d'être dans votre propriété",
            "exposer hors propriété"
        )
        local full = { Id = "P1", Capacity = 1, Slots = { ["1"] = "V9" } }
        a = View.vehicleActions(stored, inProp, full)
        T.truthy(not a.Display.Enabled and a.Display.Reason == "Aucune place libre", "aucune place libre")
    end)

    T.test("4. fiche technique : valeurs lues dans la définition et le catalogue, aucune mesure inventée", function()
        local Definitions = H.require("ReplicatedStorage.Shared.Vehicles.VehicleDefinitions")
        local Catalog = H.require("ReplicatedStorage.Shared.Economy.VehicleCatalog")
        for _, id in { "wk_comete", "proto_p01" } do
            local definition = Definitions.get(id) or Fixtures.get(id) -- prototype : jeu d'essai (lot BASE-01)
            T.truthy(definition ~= nil, id)
            local entry = Catalog.forDefinition(id)
            local specs = View.specs(definition, entry)
            local keys = {}
            for _, spec in specs do
                keys[spec.Key] = spec.Value
            end
            for _, key in
                {
                    "Énergie",
                    "Boîte",
                    "Transmission",
                    "Masse",
                    "L × l × h (emp.) m",
                    "Réservoir / batterie",
                    "Aides",
                }
            do
                T.truthy(keys[key] ~= nil, id .. " : " .. key)
            end
            T.equal(
                keys["Masse"],
                View.thousands(definition.Chassis.MassKg) .. " kg",
                id .. " : masse de la définition"
            )
            T.truthy(
                keys["0–100 (banc)"] == nil and keys["V. annoncée"] == nil,
                id .. " : aucune mesure non fournie"
            )
            if entry then
                T.equal(keys["Valeur catalogue"], View.thousands(entry.Price) .. " cr", id .. " : prix du catalogue")
            else
                T.equal(keys["Valeur catalogue"], nil, id .. " : pas de prix hors catalogue")
            end
            local kw = View.peakPowerKw(definition)
            T.truthy(kw ~= nil and kw > 20 and kw < 1200, id .. " : puissance plausible " .. tostring(kw))
        end
        T.equal(View.category(Fixtures.get("proto_p01"), nil), "Prototype technique", "prototype hors catalogue")
        T.equal(View.category(nil, { Category = "Supercar" }), "Supercar", "catégorie du catalogue")
        local badge = View.availability(nil, { Availability = "PendingApproval" })
        T.equal(badge, "Proposé · en attente d'approbation", "gamme non approuvée signalée")
    end)

    T.test("5. réglages : pas, mise en forme et plage de la maquette", function()
        local mult = { Min = 0.85, Max = 1.2, Default = 1, Unit = "×" }
        T.equal(View.tuningStep(mult), 0.01)
        T.equal(View.formatTuning(mult, 1.05), "1,05×")
        T.equal(View.formatTuning({ Unit = "m" }, 0.01), "+0,010 m")
        T.equal(View.formatTuning({ Unit = "m" }, -0.02), "-0,020 m")
        T.equal(View.formatTuning({ Unit = "tr/min" }, 6500), "6500 tr/min")
        T.equal(View.formatTuning({ Unit = "" }, 0.62), "62 %")
        T.equal(View.snap(mult, 1.234), 1.2, "borné au maximum")
        T.truthy(math.abs(View.snap(mult, 1.0449) - 1.04) < 1e-9, "arrondi au pas")
        T.equal(View.snap({ Min = 5000, Max = 7000, Unit = "tr/min" }, 6024), 6000, "pas de 50 tr/min")
    end)

    T.test("6. brouillon : détecté seulement s'il diffère de l'enregistré ; accessoires bornés", function()
        local vehicle = {
            Tuning = { SpringFront = 1.1 },
            Cosmetics = {
                BodyColor = "Rouge",
                AccentColor = "Noir",
                Finish = "Gloss",
                Wheels = "Stock",
                ShowLabel = true,
                BodyKit = { Front = "Stock" },
                Accessories = {},
            },
        }
        T.truthy(not View.hasDraft(vehicle, {}, nil), "rien")
        T.truthy(not View.hasDraft(vehicle, { SpringFront = 1.1 }, nil), "valeur identique")
        T.truthy(View.hasDraft(vehicle, { SpringFront = 1.12 }, nil), "réglage modifié")
        local copy = table.clone(vehicle.Cosmetics)
        T.truthy(not View.hasDraft(vehicle, {}, copy), "esthétique identique")
        copy.BodyColor = "Bleu"
        T.truthy(View.hasDraft(vehicle, {}, copy), "couleur modifiée")
        local list = View.toggleAccessory({}, "RoofRack", 2)
        list = View.toggleAccessory(list, "Stripes", 2)
        list = View.toggleAccessory(list, "LightBar", 2)
        T.equal(#list, 2, "deux accessoires au plus")
        list = View.toggleAccessory(list, "RoofRack", 2)
        T.equal(#list, 1, "retrait")
    end)

    T.test("7. configurations : enregistrer dans l'ordre, appliquer et supprimer s'il existe, au garage", function()
        local configs = { { Name = "A", Realizable = true } }
        local caps = { ApplyConfiguration = true }
        local a = View.configActions(1, configs, true, caps)
        T.truthy(a.Save.Enabled and a.Apply.Enabled and a.Delete.Enabled, "emplacement 1 rempli")
        a = View.configActions(2, configs, true, caps)
        T.truthy(
            a.Save.Enabled and not a.Apply.Enabled and a.Apply.Reason == "Emplacement vide",
            "emplacement 2 suivant"
        )
        a = View.configActions(3, configs, true, caps)
        T.truthy(not a.Save.Enabled and a.Save.Reason == "Remplir dans l'ordre", "pas de trou")
        a = View.configActions(1, configs, false, {})
        T.truthy(not a.Save.Enabled and not a.Delete.Enabled and not a.Apply.Enabled, "hors garage")
        T.equal(a.Delete.Reason, "Exige une propriété ou un garage public", "raison hors garage")
    end)

    T.test("8. collection : colonnes des cartes aux résolutions de référence", function()
        local function cols(width: number, compactMode: boolean): number
            local c = View.cardColumns(width, compactMode, 16)
            return c
        end
        T.equal(cols(1920 - 56, false), 5, "1920 : 5 cartes de 300 px au moins")
        T.equal(cols(1280 - 56, true), 4, "1280 compact : 4 cartes de 240 px au moins")
        T.equal(cols(3440 - 56, false), 10, "ultralarge 3440 : 10 cartes")
        local c, w = View.cardColumns(1864, false, 16)
        T.truthy(w >= 300 and c * w + (c - 1) * 16 <= 1864, "largeur des cartes ≥ 300 px, rien ne déborde")
        T.equal(cols(200, true), 1, "au moins une colonne")
    end)

    T.test("9. garage : confirmations des choix définitifs, anti double envoi, aucun glyphe en icône", function()
        local garage = source("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.UI.GaragePanel")
        for _, needle in
            {
                'confirmThen(tr("Choisir %s comme véhicule de départ',
                'confirmThen(tr("Revendre %s',
                'confirmThen(tr("Supprimer la configuration %d',
                "if busy then",
                "data.RequestId = HttpService:GenerateGUID(false)",
                "VehiclePreview.thumbnail(",
                "Back = back,",
                "GarageView.vehicleActions(",
                "TuningRules.validate(",
            }
        do
            T.truthy(string.find(garage, needle, 1, true) ~= nil, needle)
        end
        for _, glyph in { "◀", "▶", "←", "→", "‹", "›", "✓", "✕" } do
            T.truthy(string.find(garage, glyph, 1, true) == nil, "glyphe absent : " .. glyph)
        end
        local manager = source("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.UI.UIManager")
        T.truthy(string.find(manager, "screen.Back()", 1, true) ~= nil, "retour d'un niveau avant fermeture")
    end)

    T.suite("Carte V1.2 — rognage des routes (mini-carte ronde, grande carte)")

    T.test(
        "1. segments rognés au rectangle et au disque, jamais hors du cadre ; objectif ramené au cercle",
        function()
            local Projection = H.require("ReplicatedStorage.Shared.Navigation.MapProjection")
            local view = Projection.view(0, 0, 1, 0, 200, 200)
            -- Rectangle : dedans inchangé, traversant coupé au bord, dehors rejeté.
            local a, b, c, d = Projection.clipRect(view, 20, 20, 180, 180, 0)
            T.truthy(a == 20 and b == 20 and c == 180 and d == 180, "segment intérieur inchangé")
            a, b, c, d = Projection.clipRect(view, -100, 100, 300, 100, 0)
            T.truthy(math.abs(a - 0) < 1e-6 and math.abs(c - 200) < 1e-6 and b == 100 and d == 100, "coupé aux bords")
            a = Projection.clipRect(view, -50, -50, -10, -20, 0)
            T.equal(a, nil, "segment extérieur rejeté")
            -- Disque de rayon 90 centré : extrémités ramenées sur le cercle.
            a, b, c, d = Projection.clipCircle(view, -100, 100, 300, 100, 90)
            T.truthy(math.abs(a - 10) < 1e-6 and math.abs(c - 190) < 1e-6, "coupé sur le cercle")
            a, b, c, d = Projection.clipCircle(view, 90, 90, 110, 110, 90)
            T.truthy(a == 90 and c == 110, "segment intérieur inchangé")
            a = Projection.clipCircle(view, 0, 0, 20, 0, 90)
            T.equal(a, nil, "coin extérieur au disque rejeté")
            -- Un segment rogné n'a aucun point hors du disque.
            for _, seg in { { -300, -40, 400, 260 }, { 100, -500, 100, 900 }, { -10, 190, 210, 10 } } do
                local u1, v1, u2, v2 = Projection.clipCircle(view, seg[1], seg[2], seg[3], seg[4], 90)
                if u1 then
                    for _, point in { { u1, v1 }, { u2, v2 } } do
                        local r = math.sqrt((point[1] - 100) ^ 2 + (point[2] - 100) ^ 2)
                        T.truthy(r <= 90 + 1e-6, "point dans le disque : " .. r)
                    end
                end
            end
            local u, v = Projection.clampToCircle(view, 400, 100, 12)
            T.truthy(math.abs(u - 188) < 1e-6 and math.abs(v - 100) < 1e-6, "objectif ramené au cercle intérieur")
        end
    )
end
