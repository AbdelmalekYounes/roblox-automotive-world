--!strict
-- Lecture des commandes de conduite au clavier et à la manette.
-- Produit une intention normalisée (`DriverInput`) indépendante du périphérique.
--
-- Clavier : Z/W ou ↑ accélérer, S ou ↓ freiner/reculer, Q/A ou ← et D ou →
--           diriger, Espace frein à main.
-- Manette : gâchette droite accélérer, gâchette gauche freiner/reculer,
--           stick gauche diriger, bouton A frein à main.
-- Ce module ne fait que LIRE les périphériques ; le choix du périphérique
-- actif, les zones mortes, les rampes clavier et les protections contre les
-- commandes involontaires sont dans InputArbiter (module pur, testé hors Studio).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Vehicles"):WaitForChild("VehicleTypes"))
local InputArbiter = require(script.Parent.InputArbiter)

local DriverInput = {}
DriverInput.__index = DriverInput

type InputFields = {
    Arbiter: InputArbiter.State,
    Gamepad: Enum.UserInputType,
    WindowFocused: boolean,
    OnEvent: ((InputArbiter.Event) -> ())?,
}

export type DriverInputReader = typeof(setmetatable({} :: InputFields, DriverInput))

local THROTTLE_KEYS = { Enum.KeyCode.W, Enum.KeyCode.Z, Enum.KeyCode.Up }
local BRAKE_KEYS = { Enum.KeyCode.S, Enum.KeyCode.Down }
local LEFT_KEYS = { Enum.KeyCode.A, Enum.KeyCode.Q, Enum.KeyCode.Left }
local RIGHT_KEYS = { Enum.KeyCode.D, Enum.KeyCode.Right }

local function isGamepad(inputType: Enum.UserInputType): boolean
    return string.sub(inputType.Name, 1, 7) == "Gamepad"
end

function DriverInput.new(): DriverInputReader
    local self = setmetatable(
        {
            Arbiter = InputArbiter.newState(),
            Gamepad = Enum.UserInputType.Gamepad1,
            WindowFocused = true,
            OnEvent = nil,
        } :: InputFields,
        DriverInput
    )
    -- Manette suivie : la dernière ayant servi (pas seulement Gamepad1).
    UserInputService.InputBegan:Connect(function(inputObject)
        if isGamepad(inputObject.UserInputType) then
            self.Gamepad = inputObject.UserInputType
        end
    end)
    -- Fenêtre sans focus : les relâchements de touches peuvent être perdus.
    UserInputService.WindowFocusReleased:Connect(function()
        self.WindowFocused = false
    end)
    UserInputService.WindowFocused:Connect(function()
        self.WindowFocused = true
    end)
    return self
end

local function anyKeyDown(keys: { Enum.KeyCode }): boolean
    for _, key in keys do
        if UserInputService:IsKeyDown(key) then
            return true
        end
    end
    return false
end

-- Vrai si une zone de texte (y compris celle du chat) a le focus.
function DriverInput.isTyping(): boolean
    return UserInputService:GetFocusedTextBox() ~= nil
end

local function readKeyboard(): InputArbiter.KeyboardSample
    return {
        Throttle = anyKeyDown(THROTTLE_KEYS),
        Brake = anyKeyDown(BRAKE_KEYS),
        Left = anyKeyDown(LEFT_KEYS),
        Right = anyKeyDown(RIGHT_KEYS),
        Handbrake = UserInputService:IsKeyDown(Enum.KeyCode.Space),
    }
end

local function readGamepad(gamepad: Enum.UserInputType): InputArbiter.GamepadSample
    if not UserInputService:GetGamepadConnected(gamepad) then
        return InputArbiter.DisconnectedGamepad
    end
    local throttle, brake, steer = 0, 0, 0
    for _, state in UserInputService:GetGamepadState(gamepad) do
        if state.KeyCode == Enum.KeyCode.ButtonR2 then
            throttle = state.Position.Z
        elseif state.KeyCode == Enum.KeyCode.ButtonL2 then
            brake = state.Position.Z
        elseif state.KeyCode == Enum.KeyCode.Thumbstick1 then
            steer = state.Position.X
        end
    end
    return {
        Connected = true,
        Throttle = throttle,
        Brake = brake,
        Steer = steer,
        Handbrake = UserInputService:IsGamepadButtonDown(gamepad, Enum.KeyCode.ButtonA),
    }
end

-- Fonction appelée pour chaque événement d'arbitrage (ex. manette déconnectée).
function DriverInput.setEventHandler(self: DriverInputReader, handler: ((InputArbiter.Event) -> ())?)
    self.OnEvent = handler
end

-- À appeler une fois par image.
function DriverInput.poll(self: DriverInputReader, dt: number): Types.DriverInput
    local command: Types.DriverInput, event: InputArbiter.Event? =
        InputArbiter.step(self.Arbiter, readKeyboard(), readGamepad(self.Gamepad), {
            Typing = DriverInput.isTyping(),
            WindowFocused = self.WindowFocused,
        }, dt)
    local handler = self.OnEvent
    if event and handler then
        handler(event)
    end
    return command
end

-- Remise à zéro (début/fin de conduite) : plus aucun périphérique actif, et
-- une commande déjà maintenue devra être relâchée puis renouvelée.
function DriverInput.reset(self: DriverInputReader)
    self.Arbiter = InputArbiter.newState()
end

return DriverInput
