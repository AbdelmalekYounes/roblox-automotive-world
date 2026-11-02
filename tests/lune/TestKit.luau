--!strict
-- Mini-cadre de test pour Lune : enregistrement, assertions et rapport.
-- Aucune dépendance externe.

local TestKit = {}

type Case = { Suite: string, Name: string, Fn: () -> () }

local cases: { Case } = {}
local currentSuite = "?"

function TestKit.suite(name: string)
    currentSuite = name
end

function TestKit.test(name: string, fn: () -> ())
    table.insert(cases, { Suite = currentSuite, Name = name, Fn = fn })
end

local function fail(message: string)
    error(message, 3)
end

function TestKit.truthy(value: any, message: string?)
    if not value then
        fail(message or "valeur attendue vraie")
    end
end

function TestKit.equal(actual: any, expected: any, message: string?)
    if actual ~= expected then
        fail(string.format("%s : obtenu %s, attendu %s", message or "égalité", tostring(actual), tostring(expected)))
    end
end

function TestKit.near(actual: number, expected: number, tolerance: number, message: string?)
    if not (math.abs(actual - expected) <= tolerance) then
        fail(
            string.format(
                "%s : obtenu %.6g, attendu %.6g ± %.3g",
                message or "proximité",
                actual,
                expected,
                tolerance
            )
        )
    end
end

function TestKit.between(actual: number, low: number, high: number, message: string?)
    if not (actual >= low and actual <= high) then
        fail(string.format("%s : %.6g hors de [%.6g ; %.6g]", message or "intervalle", actual, low, high))
    end
end

function TestKit.finite(value: number, message: string?)
    if value ~= value or value == math.huge or value == -math.huge then
        fail((message or "valeur") .. " non finie")
    end
end

-- Notes informatives affichées dans le rapport (valeurs du modèle).
local notes: { string } = {}
function TestKit.note(text: string)
    table.insert(notes, text)
end

function TestKit.run(): boolean
    local passed, failed = 0, 0
    local lastSuite = nil
    for _, case in cases do
        if case.Suite ~= lastSuite then
            lastSuite = case.Suite
            print("\n[" .. case.Suite .. "]")
        end
        local ok, err = pcall(case.Fn)
        if ok then
            passed += 1
            print("  OK    " .. case.Name)
        else
            failed += 1
            print("  ÉCHEC " .. case.Name .. "\n        " .. tostring(err))
        end
    end
    if #notes > 0 then
        print("\n[Valeurs produites par le modèle hors Roblox — indicatives, non mesurées en jeu]")
        for _, text in notes do
            print("  • " .. text)
        end
    end
    print(string.format("\nRésultat : %d réussis, %d échoués, %d au total", passed, failed, passed + failed))
    return failed == 0
end

return TestKit
