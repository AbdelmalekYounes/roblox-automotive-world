--!strict
--[[
    Routage centralisé des raccourcis (lot 0.7) : un seul endroit lie les
    touches aux interfaces (cœur pur : Shared/UI/InputMap).

    - Actions globales (téléphone, carte, garage, économie, courses, niveau
      du HUD, effacer l'itinéraire) liées par ContextActionService ; les
      touches clavier personnalisées sont relues à chaque changement de
      préférences (refus des touches réservées à la conduite).
    - « Retour » (Retour arrière, manette B) n'est lié QUE pendant qu'une
      interface capture la conduite : au volant, B reste l'embrayage.
    - Pendant une saisie de texte (chat), ContextActionService ne déclenche
      aucune action.
    - Garde de confirmation : dernier périphérique et instant de chaque
      pression ; une confirmation n'est acceptée que d'une pression neuve
      (InputMap.accepts). Changer de périphérique ne confirme jamais rien.
]]

local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InputMap = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("InputMap"))

local UIState = require(script.Parent.UIState)
local UIManager = require(script.Parent.UIManager)

local InputRouter = {}

local handlers: { [string]: () -> () } = {}
local guard = InputMap.newGuard(-math.huge)
local lastPressBegan = -math.huge
local backBound = false
local PREFIX = "AWUI_"

function InputRouter.on(action: string, handler: () -> ())
    handlers[action] = handler
end

local function deviceOf(inputType: Enum.UserInputType): string
    local name = inputType.Name
    if string.sub(name, 1, 7) == "Gamepad" then
        return "Gamepad"
    elseif name == "Touch" then
        return "Touch"
    end
    return "KeyboardMouse"
end

local function keyCode(name: string?): Enum.KeyCode?
    if name == nil then
        return nil
    end
    local ok, code = pcall(function()
        return (Enum.KeyCode :: any)[name]
    end)
    return if ok then code else nil
end

local function bindAll()
    local custom = UIState.prefs().Bindings
    for _, binding in InputMap.Defaults do
        if binding.Action == "Back" then
            continue
        end
        ContextActionService:UnbindAction(PREFIX .. binding.Action)
        local keys: { Enum.KeyCode } = {}
        local keyboard = keyCode(InputMap.keyFor(binding.Action, custom))
        if keyboard then
            table.insert(keys, keyboard)
        end
        local pad = keyCode(binding.Gamepad)
        if pad then
            table.insert(keys, pad)
        end
        if #keys == 0 then
            continue
        end
        ContextActionService:BindActionAtPriority(PREFIX .. binding.Action, function(_, state)
            if state == Enum.UserInputState.Begin then
                local handler = handlers[binding.Action]
                if handler then
                    task.spawn(handler)
                end
            end
            return Enum.ContextActionResult.Sink
        end, false, Enum.ContextActionPriority.High.Value, table.unpack(keys))
    end
end

-- « Retour » seulement quand une interface capture la conduite.
local function updateBack()
    local wanted = UIState.capturesDriving()
    if wanted == backBound then
        return
    end
    backBound = wanted
    if wanted then
        ContextActionService:BindActionAtPriority(PREFIX .. "Back", function(_, state)
            if state == Enum.UserInputState.Begin then
                UIManager.back()
            end
            return Enum.ContextActionResult.Sink
        end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Backspace, Enum.KeyCode.ButtonB)
    else
        ContextActionService:UnbindAction(PREFIX .. "Back")
    end
end

-- Nouvelle demande de confirmation affichée.
function InputRouter.armConfirm()
    InputMap.arm(guard, os.clock())
end

-- La pression qui déclenche la confirmation est-elle neuve ?
function InputRouter.confirmAllowed(): boolean
    return InputMap.accepts(guard, lastPressBegan)
end

function InputRouter.lastDevice(): string?
    return guard.Device
end

function InputRouter.start()
    bindAll()
    UIState.onPrefs(function()
        bindAll()
    end)
    InputMap.deviceChanged(guard, deviceOf(UserInputService:GetLastInputType()), os.clock())
    UserInputService.LastInputTypeChanged:Connect(function(inputType)
        InputMap.deviceChanged(guard, deviceOf(inputType), os.clock())
    end)
    UserInputService.InputBegan:Connect(function(input)
        local kind = input.UserInputType
        if
            kind == Enum.UserInputType.Keyboard
            or kind == Enum.UserInputType.MouseButton1
            or kind == Enum.UserInputType.Touch
            or string.sub(kind.Name, 1, 7) == "Gamepad"
        then
            if input.KeyCode ~= Enum.KeyCode.Thumbstick1 and input.KeyCode ~= Enum.KeyCode.Thumbstick2 then
                lastPressBegan = os.clock()
            end
        end
    end)
    RunService.Heartbeat:Connect(updateBack)
end

return InputRouter
