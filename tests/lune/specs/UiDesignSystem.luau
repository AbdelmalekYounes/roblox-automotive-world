--!strict
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
            { "PhoneIcons.image", "Tokens.Phone", "Radius.PhoneFrame", "Radius.PhoneScreen", "PhoneResize" }
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

    T.test("1. cadrage : le véhicule entier tient dans la zone, quel que soit son format", function()
        local Framing = H.require("ReplicatedStorage.Shared.UI.PreviewFraming")
        local fov = Framing.Fov
        for _, aspect in { 0.6, 1, 1.6, 2.4 } do
            local radius = 12
            local d = Framing.distance(radius, fov, aspect, 1)
            -- Angle sous lequel la sphère est vue, comparé au plus petit demi-champ (vertical ou horizontal).
            local seen = math.asin(radius / d)
            local half = math.rad(fov) / 2
            local limiting = math.min(half, math.atan(math.tan(half) * aspect))
            T.truthy(math.abs(seen - limiting) < 1e-6, "tangente aux bords, rapport " .. aspect)
        end
        T.truthy(
            Framing.distance(12, fov, 0.6) > Framing.distance(12, fov, 1.6),
            "zone étroite : caméra plus loin (limite horizontale)"
        )
        T.equal(Framing.distance(12, fov, 2.4), Framing.distance(12, fov, 4), "zone large : limite verticale seule")
        T.truthy(Framing.distance(12, fov, 1.5) > Framing.distance(12, fov, 1.5, 1), "marge appliquée")
        T.equal(Framing.distance(-1, fov, 1), 0, "rayon négatif ramené à 0")
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
end
