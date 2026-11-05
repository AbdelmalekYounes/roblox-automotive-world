--!strict
-- Lot ADMIN-01 — menu d'administration : règles PURES (validation, bornes, journal), horloge réglable, droits,
-- cohérence règles / service / interface, et correctif QA-D11 (testé dans Lot04Persistence). Ne valide PAS le
-- comportement en jeu (no clip, téléportation, apparition, réparation) : liste de vérification du propriétaire.

local SHARED = "ReplicatedStorage.Shared."
local SERVER = "ServerScriptService.AutomotiveWorldServer."
local CLIENT = "StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient."

return function(T: any, H: any)
    local AdminRules = H.require(SHARED .. "Admin.AdminRules")
    local AdminConfig = H.require(SERVER .. "Admin.AdminConfig")
    local WeatherModel = H.require(SHARED .. "World.WeatherModel")

    local function source(path: string): string
        local node = H.game()
        for segment in string.gmatch(path, "[^%.]+") do
            node = node:FindFirstChild(segment)
        end
        return node.Source
    end

    T.suite("Lot ADMIN-01 — menu d'administration")

    T.test("droits : le compte du propriétaire seul, côté serveur, jamais répliqué", function()
        T.equal(#AdminConfig.AdminUserIds, 1)
        T.truthy(AdminRules.isAdmin(941826283, AdminConfig.AdminUserIds), "youyou31110 administrateur")
        T.truthy(not AdminRules.isAdmin(1, AdminConfig.AdminUserIds), "un autre joueur ne l'est pas")
        local shared = H.game().ReplicatedStorage.Shared
        T.truthy(shared:FindFirstChild("AdminConfig", true) == nil, "liste absente de l'espace répliqué")
    end)

    T.test("liste fermée : action inconnue refusée, paramètres absents traités", function()
        T.equal(select(2, AdminRules.validate("Fly", {})), "AdminActionUnknown")
        T.equal(select(2, AdminRules.validate(42, {})), "AdminActionUnknown")
        for _, action in
            {
                "Snapshot",
                "RemoveSpawned",
                "FlipVehicle",
                "Respawn",
                "AbandonMission",
                "ResetProfile",
                "ForceRaceStart",
            }
        do
            T.truthy((AdminRules.validate(action, nil)), action .. " sans paramètre")
        end
    end)

    T.test("crédits : 1 à 100 000 par action (A4), entiers, joueur valide", function()
        T.truthy((AdminRules.validate("GrantCredits", { UserId = 5, Amount = 100000 })), "100 000 accepté")
        T.equal(select(2, AdminRules.validate("GrantCredits", { UserId = 5, Amount = 100001 })), "AdminAmountInvalid")
        T.equal(select(2, AdminRules.validate("GrantCredits", { UserId = 5, Amount = 0 })), "AdminAmountInvalid")
        T.equal(select(2, AdminRules.validate("GrantCredits", { UserId = 5, Amount = 10.5 })), "AdminAmountInvalid")
        T.equal(select(2, AdminRules.validate("GrantCredits", { UserId = 5, Amount = 0 / 0 })), "AdminAmountInvalid")
        T.equal(select(2, AdminRules.validate("GrantCredits", { UserId = -1, Amount = 10 })), "AdminPlayerInvalid")
        T.equal(AdminRules.MaxCreditGrant, 100000)
    end)

    T.test("bornes : heure, cycle, météo, vitesses, réputation, motif", function()
        T.truthy((AdminRules.validate("SetClock", { Hour = 23.5 })), "23 h 30")
        T.equal(select(2, AdminRules.validate("SetClock", { Hour = 24 })), "AdminHourInvalid")
        T.equal(select(2, AdminRules.validate("SetClock", { Hour = math.huge })), "AdminHourInvalid")
        T.truthy((AdminRules.validate("SetClockSpeed", { Speed = 0 })), "heure figée")
        T.equal(select(2, AdminRules.validate("SetClockSpeed", { Speed = 61 })), "AdminSpeedInvalid")
        T.truthy((AdminRules.validate("SetWeather", { State = "Storm" })), "orage")
        T.equal(select(2, AdminRules.validate("SetWeather", { State = "Snow" })), "AdminWeatherInvalid")
        T.equal(select(2, AdminRules.validate("SetWalkSpeed", { Value = 500 })), "AdminSpeedInvalid")
        local ok, noclip = AdminRules.validate("SetNoclip", { On = true })
        T.truthy(ok and noclip.Speed == AdminRules.NoclipSpeed.Default, "vitesse par défaut du no clip")
        T.equal(select(2, AdminRules.validate("SetNoclip", { On = "oui" })), "AdminFlagInvalid")
        T.equal(select(2, AdminRules.validate("SetReputation", { Points = 100001 })), "AdminAmountInvalid")
        T.equal(select(2, AdminRules.validate("Kick", { UserId = 2, Reason = "   " })), "AdminReasonInvalid")
        local kicked, clean = AdminRules.validate("Kick", { UserId = 2, Reason = "  test  " })
        T.truthy(kicked and clean.Reason == "test", "motif nettoyé")
        T.equal(
            select(2, AdminRules.validate("Kick", { UserId = 2, Reason = string.rep("x", 121) })),
            "AdminReasonInvalid"
        )
        T.equal(select(2, AdminRules.validate("Teleport", { PointId = "" })), "AdminPointInvalid")
        T.equal(select(2, AdminRules.validate("SpawnVehicle", { ModelId = 3 })), "AdminModelInvalid")
    end)

    T.test("journal circulaire : la plus récente en tête, 50 au plus ; lecture non consignée", function()
        local log = {}
        for i = 1, 60 do
            AdminRules.logPush(log, { At = i, AdminId = 1, AdminName = "a", Action = "X", Detail = "", Result = "OK" })
        end
        T.equal(#log, AdminRules.LogSize)
        T.equal(log[1].At, 60, "la plus récente en tête")
        T.truthy(not AdminRules.logged("Snapshot") and AdminRules.logged("GrantCredits"), "Snapshot non consigné")
        for _, action in { "GrantCredits", "Kick", "ResetProfile", "BringPlayer", "SetReputation" } do
            T.truthy(AdminRules.Confirm[action], action .. " : confirmation demandée")
        end
    end)

    T.test("horloge : ancre et vitesse réglables, heure figée à vitesse nulle", function()
        T.near(WeatherModel.clockTime(100, 100), WeatherModel.StartHour, 1e-9, "valeurs d'origine")
        T.near(WeatherModel.clockTime(100, 100, 19, 1), 19, 1e-9, "ancre")
        T.near(WeatherModel.clockTime(100 + 3600, 100, 19, 0), 19, 1e-9, "figée")
        local quarter = WeatherModel.DayLengthS / 4
        T.near(WeatherModel.clockTime(100 + quarter / 10, 100, 0, 10), 6, 1e-9, "× 10 : un quart de jour")
    end)

    T.test("service : chaque action a son traitement ; droits vérifiés avant tout", function()
        local service = source(SERVER .. "Admin.AdminService")
        for _, action in AdminRules.Actions do
            T.truthy(string.find(service, "handlers." .. action .. " = function", 1, true) ~= nil, action)
        end
        local guard = string.find(service, "if not isAdmin(player) then", 1, true)
        local validate = string.find(service, "AdminRules.validate(action, payload)", 1, true)
        T.truthy(guard ~= nil and validate ~= nil and guard < validate, "droits vérifiés avant la validation")
        T.truthy(
            string.find(service, 'environment.Name ~= "Dev" and environment.Name ~= "Test"', 1, true) ~= nil,
            "réinitialisation jamais en production"
        )
        T.truthy(
            string.find(service, 'Wallet.credit(profile, p.Amount, "AdminGrant"', 1, true) ~= nil,
            "crédits par transaction tracée"
        )
        local bootstrap = source(SERVER .. "Bootstrap")
        T.truthy(string.find(bootstrap, "AdminService.start()", 1, true) ~= nil, "service démarré")
    end)

    T.test(
        "interface : menu construit pour les administrateurs seulement, F8, no clip autorisé par le serveur",
        function()
            local panel = source(CLIENT .. "UI.AdminPanel")
            T.truthy(
                string.find(panel, 'player:GetAttribute("AWAdmin") == true', 1, true) ~= nil,
                "attribut du serveur"
            )
            T.truthy(string.find(panel, "Enum.KeyCode.F8, Enum.KeyCode.F2", 1, true) ~= nil, "touches F8 et F2")
            local noclip = source(CLIENT .. "Admin.NoclipController")
            T.truthy(
                string.find(noclip, 'player:GetAttribute("AWAdminNoclip") == true', 1, true) ~= nil,
                "autorisé par le serveur"
            )
            local bootstrap = source(CLIENT .. "Bootstrap")
            T.truthy(string.find(bootstrap, "AdminPanel.start()", 1, true) ~= nil, "panneau démarré")
        end
    )
end
