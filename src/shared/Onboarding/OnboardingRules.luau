--!strict
--[[
    Première connexion (lot 0.8, §10.1, AUD-ONB-01), règles PURES.

    Étapes : accueil → univers → commandes → téléphone, carte et GPS →
    véhicules de départ → (essai facultatif) → choix confirmé → propriété
    gratuite → monde ouvert. L'introduction est PASSABLE à tout moment ;
    rien n'oblige à la revoir, et elle reste consultable ensuite.
    Le choix du véhicule de départ n'est PAS fait ici : il passe par la
    transaction serveur unique « Grant:Starter » (StarterSelection) ; ce module
    ne fait que suivre la progression. La propriété gratuite est attribuée par
    sa transaction unique « Grant:FreeProperty » dès le premier chargement.
    Exercices de formation : facultatifs, rejouables, sans aucun crédit.
]]

local OnboardingRules = {}

OnboardingRules.Version = 1

OnboardingRules.Steps = table.freeze({
    "Welcome",
    "World",
    "Controls",
    "Phone",
    "Starters",
    "Choose",
    "Property",
    "Done",
})

OnboardingRules.Exercises = table.freeze({
    "AccelerateBrake",
    "Turn",
    "Shift",
    "Park",
    "UseGps",
    "ReachGarage",
    "AcceptMission",
    "DiscoverRaces",
})

-- Protection de la première apparition (pas d'invulnérabilité durable).
OnboardingRules.SpawnProtectionS = 60
-- Essai d'un candidat : durée maximale (protégé, sans conséquence durable).
OnboardingRules.TestDriveS = 180

export type State = {
    Version: number,
    Step: string,
    Seen: { [string]: number },
    Skipped: boolean,
    CompletedAt: number?,
    Exercises: { [string]: number },
    TestDrives: number,
}

function OnboardingRules.new(): State
    return {
        Version = OnboardingRules.Version,
        Step = "Welcome",
        Seen = {},
        Skipped = false,
        CompletedAt = nil,
        Exercises = {},
        TestDrives = 0,
    }
end

local function index(step: string): number?
    return table.find(OnboardingRules.Steps, step)
end

--[[
    Étape vue (« suivant »). On n'avance que d'une étape à la fois, sans
    sauter le choix du véhicule : l'étape « Choose » n'est franchie que par
    starterChosen, SAUF si aucun candidat n'est disponible (`canChoose` faux :
    liste officielle encore vide en test ou en production) — le joueur n'est
    alors pas bloqué et choisira son véhicule quand la liste sera publiée.
    Renvoie (accepté, raison).
]]
function OnboardingRules.advance(state: State, step: any, now: number, canChoose: boolean?): (boolean, string?)
    local current = index(state.Step)
    local target = if type(step) == "string" then index(step) else nil
    if current == nil or target == nil then
        return false, "OnboardingStepUnknown"
    end
    if target ~= current then
        return false, "OnboardingStepOrder"
    end
    if step == "Choose" and canChoose ~= false then
        return false, "OnboardingChooseStarter"
    end
    state.Seen[step] = now
    state.Step = OnboardingRules.Steps[math.min(current + 1, #OnboardingRules.Steps)]
    if state.Step == "Done" and state.CompletedAt == nil then
        state.CompletedAt = now
    end
    return true, nil
end

-- Passer l'introduction : on va directement au choix du véhicule (ou à la fin s'il est
-- fait, ou si aucun candidat n'est disponible).
function OnboardingRules.skip(state: State, starterChosen: boolean, now: number, canChoose: boolean?)
    state.Skipped = true
    if starterChosen or canChoose == false then
        state.Step = "Done"
        state.CompletedAt = state.CompletedAt or now
    elseif (index(state.Step) or 1) < (index("Choose") :: number) then
        state.Step = "Choose"
    end
end

-- Le véhicule de départ vient d'être attribué (transaction « Grant:Starter » confirmée).
function OnboardingRules.starterChosen(state: State, now: number)
    if (index(state.Step) or 1) <= (index("Choose") :: number) then
        state.Seen.Choose = now
        state.Step = "Property"
    end
end

-- Exercice terminé : seulement mémorisé (aucun crédit, aucune réparation).
function OnboardingRules.exercise(state: State, id: any, now: number): (boolean, string?)
    if type(id) ~= "string" or table.find(OnboardingRules.Exercises, id) == nil then
        return false, "ExerciseUnknown"
    end
    state.Exercises[id] = state.Exercises[id] or now
    return true, nil
end

function OnboardingRules.completed(state: State): boolean
    return state.Step == "Done"
end

-- Valeur d'un ancien profil (migration) : terminé si le véhicule est déjà choisi.
function OnboardingRules.migrate(starterChosen: boolean, now: number): State
    local state = OnboardingRules.new()
    if starterChosen then
        state.Step = "Done"
        state.CompletedAt = now
        state.Skipped = true
    end
    return state
end

function OnboardingRules.valid(state: any): boolean
    return type(state) == "table"
        and type(state.Step) == "string"
        and index(state.Step) ~= nil
        and type(state.Seen) == "table"
        and type(state.Exercises) == "table"
end

return table.freeze(OnboardingRules)
