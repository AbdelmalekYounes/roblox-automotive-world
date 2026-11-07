--!strict
--[[
    Progression de l'écran de chargement (lot BRAND-01), module PUR : testé par Lune.

    La barre ne montre QUE des attentes réelles (aucune fausse progression minutée) :
      1. connect   — `game:IsLoaded()` : réplication initiale terminée (le plus long sur une grande carte) ;
      2. server    — attribut `AutomotiveWorldReady` de ReplicatedStorage : le serveur a démarré ses services ;
      3. client    — interface du jeu construite (écran `AWHud` présent dans PlayerGui, créé par HUDController au
                     démarrage du client) ;
      4. character — personnage du joueur apparu (avec sa HumanoidRootPart) ;
      5. assets    — file de téléchargement de `ContentProvider` vidée (images, sons, maillages demandés).
    Pour la file : sa taille totale n'est pas connue d'avance ; la fraction vaut 1 − taille / plus haute taille vue.
    Elle peut ne jamais tomber à zéro (streaming continu) : elle compte comme finie sous `AssetQueueTolerance`
    éléments, ou `AssetsGraceSeconds` après la fin des quatre autres attentes.

    Délais (s) :
      - `MinSeconds`  : affichage minimal, évite un éclair à l'écran quand tout est déjà prêt (Studio) ;
      - `MaxSeconds`  : délai MAXIMAL ; au-delà, l'écran se retire quoi qu'il arrive (le jeu n'est jamais bloqué).
    La valeur affichée ne recule jamais et rejoint la cible en douceur (`Smoothing`, par seconde).
]]

local LoadingProgress = {}

export type StepId = "connect" | "server" | "client" | "character" | "assets"
export type Step = { Id: StepId, Weight: number }

-- Ordre d'affichage des étapes et poids dans la barre (somme = 1).
local STEPS: { Step } = {
    { Id = "connect", Weight = 0.40 },
    { Id = "server", Weight = 0.15 },
    { Id = "client", Weight = 0.15 },
    { Id = "character", Weight = 0.10 },
    { Id = "assets", Weight = 0.20 },
}
for _, step in STEPS do
    table.freeze(step)
end
LoadingProgress.Steps = table.freeze(STEPS)

export type Config = {
    MinSeconds: number,
    MaxSeconds: number,
    AssetQueueTolerance: number,
    AssetsGraceSeconds: number,
    Smoothing: number,
}

LoadingProgress.Defaults = table.freeze({
    MinSeconds = 1.2,
    MaxSeconds = 30,
    AssetQueueTolerance = 4,
    AssetsGraceSeconds = 6,
    Smoothing = 6,
} :: Config)

-- Observations du client à un instant donné (lues par l'écran, jamais inventées).
export type Signals = {
    GameLoaded: boolean,
    ServerReady: boolean,
    ClientReady: boolean,
    CharacterReady: boolean,
    QueueSize: number,
}

export type Reason = "ready" | "timeout"

export type State = {
    Config: Config,
    Elapsed: number, -- secondes depuis l'affichage
    Peak: number, -- plus haute taille de file observée
    Shown: number, -- fraction affichée, 0 à 1, croissante
    Target: number, -- fraction réelle
    OthersDoneAt: number?, -- instant où les quatre premières attentes ont abouti
    Phase: string, -- clé du texte d'étape (LoadingTexts)
    Done: boolean,
    Reason: Reason?,
}

function LoadingProgress.new(config: Config?): State
    local cfg = config or LoadingProgress.Defaults
    assert(cfg.MinSeconds >= 0 and cfg.MaxSeconds > cfg.MinSeconds, "délais incohérents")
    return {
        Config = cfg,
        Elapsed = 0,
        Peak = 0,
        Shown = 0,
        Target = 0,
        OthersDoneAt = nil,
        Phase = "loading.phase.connect",
        Done = false,
        Reason = nil,
    }
end

-- Fraction de la file de ressources (0 à 1) et fin de cette étape.
local function assetsFraction(state: State, signals: Signals, othersDone: boolean): (number, boolean)
    local queue = math.max(0, signals.QueueSize)
    if queue > state.Peak then
        state.Peak = queue
    end
    local cfg = state.Config
    local graceOver = othersDone
        and state.OthersDoneAt ~= nil
        and state.Elapsed - (state.OthersDoneAt :: number) >= cfg.AssetsGraceSeconds
    local finished = (signals.GameLoaded and queue <= cfg.AssetQueueTolerance) or graceOver
    if finished then
        return 1, true
    end
    if state.Peak <= 0 then
        return 0, false
    end
    return math.clamp(1 - queue / state.Peak, 0, 1), false
end

--[[
    Avance l'état de `dt` secondes avec les observations du moment. Renvoie l'état (modifié sur place).
    Une fois `Done`, l'état ne change plus (la sortie est définitive, même si un signal retombe).
]]
function LoadingProgress.step(state: State, signals: Signals, dt: number): State
    if state.Done then
        return state
    end
    local cfg = state.Config
    state.Elapsed += math.max(0, dt)

    local done: { [string]: boolean } = {
        connect = signals.GameLoaded,
        server = signals.ServerReady,
        client = signals.ClientReady,
        character = signals.CharacterReady,
    }
    local othersDone = done.connect and done.server and done.client and done.character
    if othersDone and state.OthersDoneAt == nil then
        state.OthersDoneAt = state.Elapsed
    elseif not othersDone then
        state.OthersDoneAt = nil
    end
    local assets, assetsDone = assetsFraction(state, signals, othersDone)
    done.assets = assetsDone

    local target = 0
    local phase: string? = nil
    for _, step in LoadingProgress.Steps do
        local fraction = if step.Id == "assets" then assets elseif done[step.Id] then 1 else 0
        target += step.Weight * fraction
        if phase == nil and not done[step.Id] then
            phase = "loading.phase." .. step.Id
        end
    end
    state.Target = math.clamp(target, 0, 1)

    -- Lissage exponentiel vers la cible, sans jamais reculer.
    local alpha = math.clamp(dt * cfg.Smoothing, 0, 1)
    state.Shown = math.max(state.Shown, state.Shown + (state.Target - state.Shown) * alpha)

    if phase == nil and state.Elapsed >= cfg.MinSeconds then
        state.Done, state.Reason, state.Phase, state.Shown = true, "ready", "loading.phase.ready", 1
    elseif state.Elapsed >= cfg.MaxSeconds then
        state.Done, state.Reason, state.Phase = true, "timeout", "loading.phase.timeout"
    else
        state.Phase = phase or "loading.phase.ready"
    end
    return state
end

--[[
    Fond animé : abscisse (fraction de largeur) du tiret `index` (1 à `count`) d'une ligne de route qui défile vers la
    gauche à `speed` largeurs par seconde. Les tirets sont répartis sur 1,2 largeur pour entrer et sortir de l'écran
    sans saut visible ; résultat dans [-0,1 ; 1,1[.
]]
function LoadingProgress.dashX(index: number, count: number, t: number, speed: number): number
    local span = 1.2
    local x = (index - 1) / count * span - t * speed
    return (x % span) - 0.1
end

-- Durée du fondu de sortie (s) : 0,6 s, ou instantané si « réduire les animations » est actif.
function LoadingProgress.fadeSeconds(reduceMotion: boolean): number
    return if reduceMotion then 0 else 0.6
end

return table.freeze(LoadingProgress)
