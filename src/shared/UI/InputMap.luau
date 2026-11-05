--!strict
--[[
    Raccourcis centralisés (lot 0.7, §7.4, AUD-INPUT-01), PURS.

    Contextes : Driving (commandes du véhicule, VehicleController), UI
    (navigation des interfaces), Phone, Map, Interaction (invites de
    proximité), Racing, Chat (Roblox). Chaque ACTION d'interface a une touche
    clavier et un bouton manette par défaut ; seules les touches clavier des
    actions « Rebindable » se personnalisent, jamais vers une touche réservée
    à la conduite ou au système, jamais en double.

    Les raccourcis provisoires des lots 0.4 à 0.6 restent valables : P (manette :
    Select) garage, J (stick droit) économie, K (stick gauche) courses.

    ConfirmGuard : une confirmation n'est acceptée que d'une pression qui a
    COMMENCÉ après l'affichage de la demande (+0,25 s) et après le dernier
    changement de périphérique (+0,4 s) : basculer du clavier à la manette ne
    confirme jamais une transaction ni une action dangereuse.
]]

local InputMap = {}

export type Context = "Driving" | "UI" | "Phone" | "Map" | "Interaction" | "Racing" | "Chat" | "Global"

export type Binding = {
    Action: string,
    Context: Context,
    Keyboard: string?,
    Gamepad: string?,
    Rebindable: boolean,
    -- Utilisable en roulant (action rapide, AUD-UI-01).
    WhileMoving: boolean,
}

local DEFAULTS: { Binding } = {
    {
        Action = "Phone",
        Context = "Global",
        Keyboard = "T",
        Gamepad = "ButtonX",
        Rebindable = true,
        WhileMoving = true,
    },
    { Action = "Map", Context = "Global", Keyboard = "M", Gamepad = nil, Rebindable = true, WhileMoving = true },
    {
        Action = "Garage",
        Context = "Global",
        Keyboard = "P",
        Gamepad = "ButtonSelect",
        Rebindable = true,
        WhileMoving = false,
    },
    {
        Action = "Economy",
        Context = "Global",
        Keyboard = "J",
        Gamepad = "ButtonR3",
        Rebindable = true,
        WhileMoving = false,
    },
    {
        Action = "Races",
        Context = "Global",
        Keyboard = "K",
        Gamepad = "ButtonL3",
        Rebindable = true,
        WhileMoving = true,
    },
    { Action = "HudLevel", Context = "Global", Keyboard = "H", Gamepad = nil, Rebindable = true, WhileMoving = true },
    { Action = "ClearRoute", Context = "Map", Keyboard = "X", Gamepad = nil, Rebindable = true, WhileMoving = true },
    {
        Action = "Back",
        Context = "UI",
        Keyboard = "Backspace",
        Gamepad = "ButtonB",
        Rebindable = false,
        WhileMoving = true,
    },
}
InputMap.Defaults = table.freeze(DEFAULTS)

-- Touches réservées (conduite, système, chat) : jamais attribuables.
InputMap.Reserved = table.freeze({
    W = "Driving",
    A = "Driving",
    S = "Driving",
    D = "Driving",
    Z = "Driving",
    Q = "Driving",
    Up = "Driving",
    Down = "Driving",
    Left = "Driving",
    Right = "Driving",
    Space = "Driving",
    C = "Driving",
    LeftShift = "Driving",
    LeftControl = "Driving",
    V = "Driving",
    F = "Driving",
    R = "Driving",
    G = "Driving",
    One = "Driving",
    Two = "Driving",
    Three = "Driving",
    E = "Interaction",
    Slash = "Chat",
    Escape = "System",
    Tab = "System",
    Return = "UI",
    Backspace = "UI",
})

function InputMap.actions(): { string }
    local list = {}
    for _, binding in DEFAULTS do
        table.insert(list, binding.Action)
    end
    return list
end

function InputMap.default(action: string): Binding?
    for _, binding in DEFAULTS do
        if binding.Action == action then
            return binding
        end
    end
    return nil
end

-- Touche clavier effective d'une action (personnalisation sinon défaut).
function InputMap.keyFor(action: string, custom: { [string]: string }?): string?
    local binding = InputMap.default(action)
    if binding == nil then
        return nil
    end
    if binding.Rebindable and custom and custom[action] then
        return custom[action]
    end
    return binding.Keyboard
end

--[[
    Contrôle d'une personnalisation : (vrai) ou (faux, "Reserved" |
    "NotRebindable" | "Unknown" | "Conflict:<action>").
]]
function InputMap.validate(custom: { [string]: string }, action: string, key: string): (boolean, string?)
    local binding = InputMap.default(action)
    if binding == nil then
        return false, "Unknown"
    end
    if not binding.Rebindable then
        return false, "NotRebindable"
    end
    if InputMap.Reserved[key] then
        return false, "Reserved"
    end
    for _, other in DEFAULTS do
        if other.Action ~= action and InputMap.keyFor(other.Action, custom) == key then
            return false, "Conflict:" .. other.Action
        end
    end
    return true, nil
end

-- Toutes les touches effectives sont distinctes et non réservées.
function InputMap.consistent(custom: { [string]: string }): boolean
    local seen: { [string]: boolean } = {}
    for _, binding in DEFAULTS do
        local key = InputMap.keyFor(binding.Action, custom)
        if key then
            if seen[key] or (binding.Rebindable and custom[binding.Action] and InputMap.Reserved[key]) then
                return false
            end
            seen[key] = true
        end
    end
    return true
end

-- ======================== Garde de confirmation ========================

export type Guard = { ShownAt: number, LastSwitchAt: number, Device: string? }

InputMap.ConfirmDelayS = 0.25
InputMap.SwitchDelayS = 0.4

function InputMap.newGuard(now: number): Guard
    return { ShownAt = now, LastSwitchAt = -math.huge, Device = nil }
end

-- Nouvelle demande de confirmation affichée.
function InputMap.arm(guard: Guard, now: number)
    guard.ShownAt = now
end

-- Changement de périphérique (clavier/souris ↔ manette ↔ tactile).
function InputMap.deviceChanged(guard: Guard, device: string, now: number)
    if guard.Device ~= nil and guard.Device ~= device then
        guard.LastSwitchAt = now
    end
    guard.Device = device
end

--[[
    Une confirmation déclenchée par une pression commencée à `pressBegan`
    est-elle acceptable ?
]]
function InputMap.accepts(guard: Guard, pressBegan: number): boolean
    return pressBegan >= guard.ShownAt + InputMap.ConfirmDelayS
        and pressBegan >= guard.LastSwitchAt + InputMap.SwitchDelayS
end

return table.freeze(InputMap)
