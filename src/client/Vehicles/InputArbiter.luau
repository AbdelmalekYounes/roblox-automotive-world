--!strict
-- Arbitrage des périphériques de conduite (module PUR, testé hors Studio).
--
-- Reçoit à chaque image l'état BRUT du clavier et de la manette, plus le
-- contexte (saisie de texte, focus de la fenêtre), et produit une commande
-- normalisée. Règles destinées à empêcher toute commande involontaire :
-- 1. Un seul périphérique pilote à la fois : le « périphérique actif ».
-- 2. Un périphérique ne devient actif que sur une commande FRAÎCHE : il doit
--    avoir été vu au repos, puis sollicité. Une touche maintenue pendant
--    l'embarquement, un stick qui dérive ou une gâchette effleurée sur la
--    manette posée n'interfèrent donc pas avec l'autre périphérique.
-- 3. Le clavier est ignoré pendant une saisie de texte, et les deux périphériques
--    sans focus de la fenêtre. Ensuite, chacun doit être revu AU REPOS avant de
--    reprendre la main : une touche restée enfoncée en quittant le chat, ou
--    « bloquée » par un relâchement perdu hors focus, ne produit rien.
-- 4. Une manette déconnectée est relâchée immédiatement ; si elle pilotait,
--    plus aucun périphérique n'est actif jusqu'à la prochaine commande fraîche
--    (pas de reprise automatique par un autre périphérique).
-- Les rampes du clavier (arbitrage A2) sont conservées ; les commandes
-- analogiques de la manette restent proportionnelles.
-- Lot 0.2 : pédale d'embrayage (touche ou bouton, donc numérique sur les deux
-- périphériques) avec une rampe dans l'esprit d'A2 : enfoncée en 0,1 s,
-- relâchée en 0,6 s pour permettre un démarrage progressif.

local InputArbiter = {}

local STICK_DEADZONE = 0.12
local TRIGGER_DEADZONE = 0.04
local PEDAL_RISE_PER_S = 5 -- 0 → 1 en 0,2 s
local PEDAL_FALL_PER_S = 8
local STEER_RATE_PER_S = 3.2
local STEER_RETURN_PER_S = 5
local CLUTCH_PRESS_PER_S = 10
local CLUTCH_RELEASE_PER_S = 1 / 0.6

export type Device = "Keyboard" | "Gamepad"

export type KeyboardSample = {
    Throttle: boolean,
    Brake: boolean,
    Left: boolean,
    Right: boolean,
    Handbrake: boolean,
    Clutch: boolean?,
}

export type GamepadSample = {
    Connected: boolean,
    Throttle: number, -- gâchette brute [0 ; 1]
    Brake: number,
    Steer: number, -- stick brut [-1 ; 1]
    Handbrake: boolean,
    Clutch: boolean?,
}

export type Context = {
    Typing: boolean,
    WindowFocused: boolean,
    -- Lot 0.7 : une interface modale complète capture la navigation (clavier
    -- et manette) ; comme pendant une saisie, les deux périphériques perdent
    -- la main et devront être revus au repos. Jamais vrai en roulant
    -- (AUD-UI-01 : les menus complets sont fermés en mouvement).
    UiCaptured: boolean?,
}

export type Command = {
    Throttle: number,
    Brake: number,
    Steer: number,
    Handbrake: boolean,
    Clutch: number,
}

export type State = {
    -- Rampes du clavier.
    Throttle: number,
    Brake: number,
    Steer: number,
    -- Rampe de la pédale d'embrayage (les deux périphériques).
    Clutch: number,
    Active: Device?,
    -- Vrai si le périphérique a été vu au repos depuis sa dernière sollicitation.
    KeyboardRested: boolean,
    GamepadRested: boolean,
    GamepadWasConnected: boolean,
}

export type Event = "GamepadDisconnected"

InputArbiter.NeutralKeyboard = table.freeze({
    Throttle = false,
    Brake = false,
    Left = false,
    Right = false,
    Handbrake = false,
}) :: KeyboardSample

InputArbiter.DisconnectedGamepad = table.freeze({
    Connected = false,
    Throttle = 0,
    Brake = 0,
    Steer = 0,
    Handbrake = false,
}) :: GamepadSample

-- État initial : aucun périphérique actif et aucun n'est réputé « au repos » :
-- une commande déjà maintenue au début de la conduite est ignorée.
function InputArbiter.newState(): State
    return {
        Throttle = 0,
        Brake = 0,
        Steer = 0,
        Clutch = 0,
        Active = nil,
        KeyboardRested = false,
        GamepadRested = false,
        GamepadWasConnected = false,
    }
end

local function approach(current: number, target: number, rateUp: number, rateDown: number, dt: number): number
    if target > current then
        return math.min(target, current + rateUp * dt)
    end
    return math.max(target, current - rateDown * dt)
end

-- Zones mortes appliquées, stick remis à l'échelle sur [0 ; 1].
function InputArbiter.shapeGamepad(sample: GamepadSample): Command
    if not sample.Connected then
        return { Throttle = 0, Brake = 0, Steer = 0, Handbrake = false, Clutch = 0 }
    end
    local throttle = if sample.Throttle > TRIGGER_DEADZONE then sample.Throttle else 0
    local brake = if sample.Brake > TRIGGER_DEADZONE then sample.Brake else 0
    local magnitude = math.abs(sample.Steer)
    local steer = if magnitude > STICK_DEADZONE
        then math.sign(sample.Steer) * (magnitude - STICK_DEADZONE) / (1 - STICK_DEADZONE)
        else 0
    return {
        Throttle = math.clamp(throttle, 0, 1),
        Brake = math.clamp(brake, 0, 1),
        Steer = math.clamp(steer, -1, 1),
        Handbrake = sample.Handbrake,
        Clutch = if sample.Clutch then 1 else 0,
    }
end

local function keyboardEngaged(keys: KeyboardSample): boolean
    return keys.Throttle or keys.Brake or keys.Left or keys.Right or keys.Handbrake or keys.Clutch == true
end

local function gamepadEngaged(pad: Command): boolean
    return pad.Throttle > 0 or pad.Brake > 0 or pad.Steer ~= 0 or pad.Handbrake or pad.Clutch > 0
end

-- Un pas d'arbitrage. Renvoie la commande et un éventuel événement à signaler.
function InputArbiter.step(
    state: State,
    rawKeys: KeyboardSample,
    rawPad: GamepadSample,
    context: Context,
    dt: number
): (Command, Event?)
    local event: Event? = nil
    local captured = context.UiCaptured == true
    local keyboardReadable = context.WindowFocused and not context.Typing and not captured
    local gamepadReadable = context.WindowFocused and not captured
    local keys = if keyboardReadable then rawKeys else InputArbiter.NeutralKeyboard
    local pad = InputArbiter.shapeGamepad(if gamepadReadable then rawPad else InputArbiter.DisconnectedGamepad)

    if state.GamepadWasConnected and not rawPad.Connected then
        state.GamepadRested = false
        if state.Active == "Gamepad" then
            state.Active = nil
            event = "GamepadDisconnected"
        end
    end
    state.GamepadWasConnected = rawPad.Connected

    -- Sollicitations fraîches : un périphérique au repos qui s'engage prend la main.
    local keysEngaged = keyboardEngaged(keys)
    local padEngaged = gamepadEngaged(pad)
    if keysEngaged and state.KeyboardRested then
        state.Active = "Keyboard"
    elseif padEngaged and state.GamepadRested then
        state.Active = "Gamepad"
    end
    if not keyboardReadable then
        -- Saisie de texte ou fenêtre sans focus : le clavier perd la main et devra
        -- être revu au repos (lecture réelle) avant de la reprendre.
        state.KeyboardRested = false
        if state.Active == "Keyboard" then
            state.Active = nil
        end
    elseif not keysEngaged then
        state.KeyboardRested = true
    elseif state.Active ~= "Keyboard" then
        state.KeyboardRested = false
    end
    if not gamepadReadable then
        state.GamepadRested = false
        if state.Active == "Gamepad" then
            state.Active = nil
        end
    elseif not padEngaged then
        state.GamepadRested = rawPad.Connected
    elseif state.Active ~= "Gamepad" then
        state.GamepadRested = false
    end

    -- Rampes du clavier : elles retombent dès que le clavier n'est plus actif.
    local useKeys = state.Active == "Keyboard"
    local keyThrottle = useKeys and keys.Throttle
    local keyBrake = useKeys and keys.Brake
    state.Throttle = approach(state.Throttle, if keyThrottle then 1 else 0, PEDAL_RISE_PER_S, PEDAL_FALL_PER_S, dt)
    state.Brake = approach(state.Brake, if keyBrake then 1 else 0, PEDAL_RISE_PER_S, PEDAL_FALL_PER_S, dt)
    local steerTarget = if useKeys then (if keys.Right then 1 else 0) - (if keys.Left then 1 else 0) else 0
    local returning = steerTarget == 0 or math.sign(steerTarget) ~= math.sign(state.Steer)
    local rate = if returning then STEER_RETURN_PER_S else STEER_RATE_PER_S
    state.Steer = approach(state.Steer, steerTarget, rate, rate, dt)
    local clutchHeld = (useKeys and keys.Clutch == true) or (state.Active == "Gamepad" and pad.Clutch > 0)
    state.Clutch = approach(state.Clutch, if clutchHeld then 1 else 0, CLUTCH_PRESS_PER_S, CLUTCH_RELEASE_PER_S, dt)

    -- Lot 0.9.1 (QA-F18) : interface modale ouverte (seulement à l'arrêt) : frein à main
    -- serré. Les commandes étant neutralisées, le joueur ne pouvait plus retenir le
    -- véhicule : une boîte automatique rampait au ralenti et le panneau se fermait.
    if state.Active == "Gamepad" then
        return {
            Throttle = pad.Throttle,
            Brake = pad.Brake,
            Steer = pad.Steer,
            Handbrake = pad.Handbrake or captured,
            Clutch = state.Clutch,
        },
            event
    end
    -- Clavier actif, ou aucun périphérique : rampes clavier (qui retombent à 0).
    return {
        Throttle = state.Throttle,
        Brake = state.Brake,
        Steer = state.Steer,
        Handbrake = (useKeys and keys.Handbrake) or captured,
        Clutch = state.Clutch,
    },
        event
end

return InputArbiter
