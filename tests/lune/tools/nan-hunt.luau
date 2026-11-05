--!strict
-- Recherche de valeurs non finies (QA-A08, lot 0.9.2) : exploration pseudo-aléatoire
-- reproductible de VehicleDynamics.step (scénarios de tests/lune/NanHunt.luau). Affiche la
-- PREMIÈRE valeur non finie de chaque scénario fautif (au plus 5) et l'historique.
-- Outil de diagnostic : aucune modification du jeu.
-- Usage : lune run tests/lune/tools/nan-hunt.luau build/AutomotiveWorld.rbxlx [scénarios] [graine] [modèle]

local process = require("@lune/process")
local Harness = require("../Harness")
-- Lot BASE-01 : prototypes et variantes retirés du jeu, conservés comme jeux d'essai.
local Fixtures = require("../fixtures/Fixtures")
local function withFixtures(list: { any }): { any }
    for _, fixture in Fixtures.all() do
        table.insert(list, fixture)
    end
    return list
end
local NanHunt = require("../NanHunt")

Harness.loadPlace(process.args[1] or "build/AutomotiveWorld.rbxlx")
local SHARED = "ReplicatedStorage.Shared."
local Dynamics = Harness.require(SHARED .. "Vehicles.Physics.VehicleDynamics")
local DamageModel = Harness.require(SHARED .. "Vehicles.Physics.DamageModel")
local Definitions = Harness.require(SHARED .. "Vehicles.VehicleDefinitions")

local scenarios = tonumber(process.args[2] or "") or 400
local baseSeed = tonumber(process.args[3] or "") or 1
local definitions = withFixtures(Definitions.all())
if process.args[4] then
    definitions = { Definitions.get(process.args[4]) }
end
local found = 0
local resetsBefore = Dynamics.numericResets()
for n = 1, scenarios do
    local result = NanHunt.scenario(Dynamics, DamageModel, definitions, baseSeed * 100003 + n)
    if result then
        found += 1
        print(
            string.format(
                "NON FINI — scénario %d (graine %d), %s, pas %d, phase %s, dt %.4f, plaqué %s, gravité %.2f : %s",
                n,
                baseSeed,
                result.Definition,
                result.Step,
                result.Phase,
                result.Dt,
                tostring(result.Pinned),
                result.Severity,
                result.Bad
            )
        )
        for _, line in result.History do
            print("    avant " .. line)
        end
        if found >= 5 then
            break
        end
    end
end
print(
    string.format(
        "%d scénario(s) exploré(s), %d avec valeur non finie, neutralisations comptées : %d",
        scenarios,
        found,
        Dynamics.numericResets() - resetsBefore
    )
)
