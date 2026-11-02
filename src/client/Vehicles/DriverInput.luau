--!strict
-- Lecture des commandes de conduite au clavier et à la manette.
-- Produit une intention normalisée (`DriverInput`) indépendante du périphérique.
--
-- Clavier : Z/W ou ↑ accélérer, S ou ↓ freiner/reculer, Q/A ou ← et D ou →
--           diriger, Espace frein à main.
-- Manette : gâchette droite accélérer, gâchette gauche freiner/reculer,
--           stick gauche diriger, bouton A frein à main.
-- Les touches numériques sont progressives (rampes) pour éviter des
-- commandes « tout ou rien » irréalistes ; les gâchettes restent analogiques.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Vehicles"):WaitForChild("VehicleTypes"))

local DriverInput = {}
DriverInput.__index = DriverInput

local GAMEPAD = Enum.UserInputType.Gamepad1
local STICK_DEADZONE = 0.12
local TRIGGER_DEADZONE = 0.04
local PEDAL_RISE_PER_S = 5 -- 0 → 1 en 0,2 s
local PEDAL_FALL_PER_S = 8
local STEER_RATE_PER_S = 3.2
local STEER_RETURN_PER_S = 5

type InputFields = {
    Throttle: number,
    Brake: number,
    Steer: number,
}

export type DriverInputReader = typeof(setmetatable({} :: InputFields, DriverInput))

function DriverInput.new(): DriverInputReader
    return setmetatable({ Throttle = 0, Brake = 0, Steer = 0 } :: InputFields, DriverInput)
end

local function anyKeyDown(keys: { Enum.KeyCode }): boolean
    for _, key in keys do
        if UserInputService:IsKeyDown(key) then
            return true
        end
    end
    return false
end

local function approach(current: number, target: number, rateUp: number, rateDown: number, dt: number): number
    if target > current then
        return math.min(target, current + rateUp * dt)
    end
    return math.max(target, current - rateDown * dt)
end

local function readGamepad(): (number, number, number, boolean)
    if not UserInputService:GetGamepadConnected(GAMEPAD) then
        return 0, 0, 0, false
    end
    local throttle, brake, steer = 0, 0, 0
    for _, state in UserInputService:GetGamepadState(GAMEPAD) do
        if state.KeyCode == Enum.KeyCode.ButtonR2 then
            throttle = state.Position.Z
        elseif state.KeyCode == Enum.KeyCode.ButtonL2 then
            brake = state.Position.Z
        elseif state.KeyCode == Enum.KeyCode.Thumbstick1 then
            steer = state.Position.X
        end
    end
    throttle = if throttle > TRIGGER_DEADZONE then throttle else 0
    brake = if brake > TRIGGER_DEADZONE then brake else 0
    -- Zone morte du stick puis remise à l'échelle sur [0 ; 1].
    local magnitude = math.abs(steer)
    steer = if magnitude > STICK_DEADZONE
        then math.sign(steer) * (magnitude - STICK_DEADZONE) / (1 - STICK_DEADZONE)
        else 0
    local handbrake = UserInputService:IsGamepadButtonDown(GAMEPAD, Enum.KeyCode.ButtonA)
    return math.clamp(throttle, 0, 1), math.clamp(brake, 0, 1), math.clamp(steer, -1, 1), handbrake
end

-- À appeler une fois par image. Le jeu ne lit les touches que lorsque
-- aucune zone de texte n'a le focus (pas d'action involontaire en tapant).
function DriverInput.poll(self: DriverInputReader, dt: number): Types.DriverInput
    local typing = UserInputService:GetFocusedTextBox() ~= nil

    local keyThrottle = not typing and anyKeyDown({ Enum.KeyCode.W, Enum.KeyCode.Z, Enum.KeyCode.Up })
    local keyBrake = not typing and anyKeyDown({ Enum.KeyCode.S, Enum.KeyCode.Down })
    local keyLeft = not typing and anyKeyDown({ Enum.KeyCode.A, Enum.KeyCode.Q, Enum.KeyCode.Left })
    local keyRight = not typing and anyKeyDown({ Enum.KeyCode.D, Enum.KeyCode.Right })
    local keyHandbrake = not typing and UserInputService:IsKeyDown(Enum.KeyCode.Space)

    local padThrottle, padBrake, padSteer, padHandbrake = readGamepad()

    self.Throttle = approach(self.Throttle, if keyThrottle then 1 else 0, PEDAL_RISE_PER_S, PEDAL_FALL_PER_S, dt)
    self.Brake = approach(self.Brake, if keyBrake then 1 else 0, PEDAL_RISE_PER_S, PEDAL_FALL_PER_S, dt)

    local keySteerTarget = (if keyRight then 1 else 0) - (if keyLeft then 1 else 0)
    local returning = keySteerTarget == 0 or math.sign(keySteerTarget) ~= math.sign(self.Steer)
    local rate = if returning then STEER_RETURN_PER_S else STEER_RATE_PER_S
    self.Steer = approach(self.Steer, keySteerTarget, rate, rate, dt)

    -- Le périphérique le plus sollicité l'emporte (bascule sans à-coup).
    return {
        Throttle = math.max(self.Throttle, padThrottle),
        Brake = math.max(self.Brake, padBrake),
        Steer = if math.abs(padSteer) > math.abs(self.Steer) then padSteer else self.Steer,
        Handbrake = keyHandbrake or padHandbrake,
    }
end

-- Remise à zéro (début/fin de conduite).
function DriverInput.reset(self: DriverInputReader)
    self.Throttle = 0
    self.Brake = 0
    self.Steer = 0
end

return DriverInput
