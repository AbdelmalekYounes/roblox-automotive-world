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
end
