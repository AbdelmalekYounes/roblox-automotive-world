--!strict
-- Lot 0.9.2 — stabilisation finale : non-régression des causes établies des anomalies
-- QA-A08 (valeurs non finies) et suivantes. Règles pures et scénarios reproductibles ; les
-- vérifications dans le moteur sont dans les sessions VM (docs/lot-0.9.2/RAPPORT_STABILISATION.md).

local NanHunt = require("../NanHunt")
local PlanarSim = require("../PlanarSim")

local SHARED = "ReplicatedStorage.Shared."

-- Scénarios qui divergeaient (∞ puis NaN) avec le code du lot 0.9.1 (`bf81465`), trouvés par
-- tests/lune/tools/nan-hunt.luau : { modèle, graine de base, numéro de scénario }.
local DIVERGED_BEFORE = {
    { "proto_p01", 8, 83 },
    { "proto_p01", 8, 104 },
    { "proto_p01", 8, 191 },
    { "wk_mistral", 7, 3 },
    { "wk_mistral", 7, 6 },
    { "wk_mistral", 7, 8 },
    { "wk_mistral", 7, 10 },
    { "wk_mistral", 7, 13 },
    { "wk_mistral", 8, 2 },
    { "wk_mistral", 8, 3 },
    { "wk_mistral", 8, 5 },
    { "wk_mistral", 8, 6 },
    { "wk_mistral", 8, 8 },
}

-- Contacts d'un véhicule posé sur le sol plat, à la vitesse de contact `forward` (m/s).
local function flatContacts(Dynamics: any, definition: any, forward: number)
    local list = {}
    for i = 1, 4 do
        list[i] = {
            Grounded = true,
            Compression = Dynamics.staticCompression(definition, i <= 2),
            CompressionVelocity = 0,
            LongitudinalVelocity = forward,
            LateralVelocity = 0,
            SurfaceFriction = 1,
            Wet = false,
            Wetness = 0,
        }
    end
    return list
end

-- Pas de simulation de `seconds` secondes, véhicule plaqué (vitesse de contact nulle).
local function holdPinned(Dynamics: any, definition: any, state: any, input: any, seconds: number)
    local motion = { Forward = 0, Lateral = 0, YawRate = 0 }
    for _ = 1, math.floor(seconds * 60) do
        Dynamics.step(state, definition, table.clone(input), flatContacts(Dynamics, definition, 0), motion, 1 / 60)
    end
end

return function(T: any, H: any)
    local Dynamics = H.require(SHARED .. "Vehicles.Physics.VehicleDynamics")
    local DamageModel = H.require(SHARED .. "Vehicles.Physics.DamageModel")
    local Definitions = H.require(SHARED .. "Vehicles.VehicleDefinitions")

    T.suite("Lot 0.9.2 — stabilisation finale")

    T.test("QA-A08 : les 13 scénarios qui divergeaient restent finis, sans neutralisation", function()
        local resets = Dynamics.numericResets()
        local limits = Dynamics.converterLimits()
        local failures = {}
        for _, case in DIVERGED_BEFORE do
            local result =
                NanHunt.scenario(Dynamics, DamageModel, { Definitions.get(case[1]) }, case[2] * 100003 + case[3])
            if result then
                table.insert(
                    failures,
                    string.format("%s %d/%d pas %d : %s", case[1], case[2], case[3], result.Step, result.Bad)
                )
            end
        end
        T.equal(#failures, 0, table.concat(failures, " ; "))
        T.equal(Dynamics.numericResets(), resets, "aucune neutralisation : la cause est traitée, pas l'effet")
        T.truthy(Dynamics.converterLimits() > limits, "la borne de stabilité du convertisseur a agi")
    end)

    T.test("QA-A08 : exploration élargie (tous les modèles) sans valeur non finie", function()
        local definitions = Definitions.all()
        local failures = {}
        for n = 1, 60 do
            local result = NanHunt.scenario(Dynamics, DamageModel, definitions, 11 * 100003 + n)
            if result then
                table.insert(
                    failures,
                    string.format("%s scénario %d pas %d : %s", result.Definition, n, result.Step, result.Bad)
                )
            end
        end
        T.equal(#failures, 0, table.concat(failures, " ; "))
    end)

    T.test("QA-A08 : aucune valeur non finie ne passe vers le serveur ni l'économie", function()
        local InputCodec = H.require(SHARED .. "Vehicles.InputCodec")
        local Wallet = H.require("ServerScriptService.AutomotiveWorldServer.Economy.Wallet")
        local ProfileSchema = H.require("ServerScriptService.AutomotiveWorldServer.Persistence.ProfileSchema")
        -- Entrées du conducteur et énergie déclarée (seules valeurs numériques envoyées par le client).
        T.equal(InputCodec.decode({ 0 / 0, 0, 0, 0 }), nil, "accélérateur NaN refusé")
        T.equal(InputCodec.decode({ 0.5, 0, math.huge, 0 }), nil, "direction infinie refusée")
        local _, energy = InputCodec.decode({ 0.5, 0, 0, 0, 0 / 0 })
        T.equal(energy, nil, "énergie NaN ignorée")
        -- Portefeuille : un montant non fini (crédit de mission calculé sur une valeur non
        -- finie, par exemple) est refusé sans toucher au profil.
        local profile = ProfileSchema.new(1, 0, "Dev")
        for _, amount in { 0 / 0, math.huge, -math.huge } do
            T.truthy(not Wallet.validAmount(amount), "montant " .. tostring(amount) .. " invalide")
            local ok = Wallet.credit(profile, amount, "Mission", "essai", 0)
            T.truthy(not ok, "crédit " .. tostring(amount) .. " refusé")
        end
        T.equal(profile.Wallet.Balance, 0, "solde intact")
        T.truthy((ProfileSchema.validate(profile)), "profil valide")
    end)

    T.test("Interfaces : focus de navigation posé seulement à la manette", function()
        local node = H.game()
        for segment in string.gmatch("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.UI.UIManager", "[^%.]+") do
            node = node:FindFirstChild(segment)
        end
        local source = node.Source
        local focusAt = string.find(source, "local function focusOf", 1, true)
        T.truthy(focusAt ~= nil, "focusOf présent")
        local body = string.sub(source, focusAt :: number, (focusAt :: number) + 400)
        T.truthy(string.find(body, "gamepadActive()", 1, true) ~= nil, "focus conditionné à la manette")
        T.truthy(string.find(source, "LastInputTypeChanged", 1, true) ~= nil, "focus posé au passage à la manette")
    end)

    T.test("QA-A10 : bras levé aussi sur le squelette R15 à contraintes d'animation", function()
        local node = H.game()
        for segment in string.gmatch("ServerScriptService.AutomotiveWorldServer.Social.InterfaceService", "[^%.]+") do
            node = node:FindFirstChild(segment)
        end
        local source = node.Source
        T.truthy(string.find(source, 'IsA("Motor6D")', 1, true) ~= nil, "chemin Motor6D conservé (R6, R15 classique)")
        T.truthy(
            string.find(source, 'IsA("AnimationConstraint")', 1, true) ~= nil,
            "épaule à contrainte d'animation reconnue"
        )
        T.truthy(string.find(source, "Attachment0", 1, true) ~= nil, "rotation de l'attache côté torse")
        T.truthy(string.find(source, "shoulder.Rest", 1, true) ~= nil, "position de repos rétablie au rangement")
    end)

    T.test("QA-A08 : borne du convertisseur inactive en conduite normale (physique inchangée)", function()
        local checked = 0
        for _, definition in Definitions.all() do
            if definition.Powertrain.Transmission.Converter then
                checked += 1
                local before = Dynamics.converterLimits()
                local snaps = PlanarSim.run(Dynamics, definition, {
                    Dt = 1 / 60,
                    Duration = 40,
                    Input = function(t: number)
                        -- Départ plein gaz, freinage puis marche arrière (frein maintenu à
                        -- l'arrêt, A3), retour en marche avant.
                        local throttle = if t < 15 or (t >= 25 and t < 30) then 1 else 0
                        local brake = if t >= 15 and t < 25 then 1 else 0
                        return { Throttle = throttle, Brake = brake, Steer = 0, Handbrake = false, Clutch = 0 }
                    end,
                })
                T.truthy(snaps[#snaps].Time > 35, definition.Id .. " : essai complet")
                T.equal(Dynamics.converterLimits(), before, definition.Id .. " : aucune limitation pendant l'essai")
            end
        end
        T.truthy(checked >= 5, "modèles à convertisseur contrôlés : " .. checked)
    end)
    T.test("Calage : une boîte sans pédale d'embrayage relance quand l'accélérateur est relâché", function()
        local pedals = { Throttle = 0.6, Brake = 0, Steer = 0, Handbrake = false, Clutch = 0 }
        local released = { Throttle = 0, Brake = 0, Steer = 0, Handbrake = true, Clutch = 0 }
        -- Automatique à convertisseur calée en D (cas de la course GPS, tâche 20261104-021402).
        local auto = Definitions.get("proto_p01")
        local state = Dynamics.createState(auto)
        Dynamics.startEngine(state, auto)
        state.Gear = 1
        state.EngineRunning, state.EngineStalled, state.EngineOmega = false, true, 0
        holdPinned(Dynamics, auto, state, pedals, 1)
        T.truthy(state.EngineStalled, "accélérateur enfoncé : pas de démarreur")
        holdPinned(Dynamics, auto, state, released, 1)
        T.truthy(state.EngineRunning and not state.EngineStalled, "accélérateur relâché : moteur relancé")
        T.equal(state.Gear, 1, "toujours en D")
        -- Boîte manuelle : règle inchangée (embrayage enfoncé ou neutre ; la pédale suit la
        -- commande avec une rampe, puis 0,6 s de démarreur).
        local manual = Definitions.get("proto_p02")
        local m = Dynamics.createState(manual)
        Dynamics.startEngine(m, manual)
        m.Gear = 1
        m.EngineRunning, m.EngineStalled, m.EngineOmega = false, true, 0
        holdPinned(Dynamics, manual, m, released, 1)
        T.truthy(m.EngineStalled, "manuelle en prise, embrayage relâché : reste calée")
        holdPinned(Dynamics, manual, m, { Throttle = 0, Brake = 0, Steer = 0, Handbrake = true, Clutch = 1 }, 2)
        T.truthy(m.EngineRunning and not m.EngineStalled, "manuelle, embrayage enfoncé : relancée")
    end)

    T.test("Calage par rebond contre un obstacle : borne du convertisseur inactive, relance", function()
        -- Reproduction (tests/lune/tools/stall-impact.luau) : wk_atlas, départ à 40 %
        -- d'accélérateur pendant 4 s, choc puis rebond à 5 m/s pendant 0,25 s, pilote qui
        -- accélère encore : le moteur cale, à l'identique avec ou sans la borne.
        local definition = Definitions.get("wk_atlas")
        local state = Dynamics.createState(definition)
        Dynamics.startEngine(state, definition)
        local forward, dt = 0, 1 / 60
        local limits = Dynamics.converterLimits()
        for step = 1, math.floor(4.5 / dt) do
            local t = step * dt
            if t <= 4 then
                local omega, share = 0, 0
                for _, wheel in state.Wheels do
                    omega += wheel.AngularVelocity * wheel.DriveShare
                    share += wheel.DriveShare
                end
                forward += (omega / share * definition.Tires.RadiusM - forward) * math.min(1, dt * 3)
            else
                forward = if t < 4.25 then -5 else 0
            end
            local input =
                { Throttle = if t <= 4 then 0.4 else 0.6, Brake = 0, Steer = 0, Handbrake = false, Clutch = 0 }
            Dynamics.step(
                state,
                definition,
                input,
                flatContacts(Dynamics, definition, forward),
                { Forward = forward, Lateral = 0, YawRate = 0 },
                dt
            )
        end
        T.truthy(state.EngineStalled, "moteur calé par le rebond")
        T.equal(Dynamics.converterLimits(), limits, "borne du convertisseur jamais active")
        holdPinned(Dynamics, definition, state, { Throttle = 0, Brake = 0, Steer = 0, Handbrake = true, Clutch = 0 }, 1)
        T.truthy(state.EngineRunning, "relancé, pédales relâchées")
    end)
end
