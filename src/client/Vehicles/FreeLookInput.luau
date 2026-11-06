--!strict
-- Lecture des commandes du regard libre en conduite (lot CAMERA-01).
--
-- Souris : clic DROIT maintenu + déplacement (décision du propriétaire,
--          2026-11-06). Le curseur est figé sur place pendant l'appui puis
--          rendu tel qu'il était : la souris n'est jamais « volée » et les
--          clics d'interface (bouton gauche) restent libres.
-- Manette : stick DROIT (aucune commande de conduite ne l'utilise).
-- Tactile : un doigt glissé sur une zone libre de l'écran (pas sur un bouton).
--
-- Ce module ne fait que LIRE les périphériques et accumuler les déplacements
-- bruts ; la conversion en angles, les limites et le retour au centre sont
-- dans Shared/Vehicles/FreeLook (module pur, testé hors Studio). Il est actif
-- seulement pendant une session de conduite (connect / disconnect par
-- VehicleCamera) et se suspend (`cancel`) dès qu'une interface est ouverte.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local FreeLook = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Vehicles"):WaitForChild("FreeLook"))

local FreeLookInput = {}
FreeLookInput.__index = FreeLookInput

type InputFields = {
    Connections: { RBXScriptConnection },
    MouseHeld: boolean,
    -- Comportement de la souris avant l'appui, restauré au relâchement.
    SavedBehavior: Enum.MouseBehavior?,
    Touch: InputObject?,
    PendingMouse: Vector2,
    PendingTouch: Vector2,
    Gamepad: Enum.UserInputType,
    Suspended: boolean,
}

export type FreeLookInput = typeof(setmetatable({} :: InputFields, FreeLookInput))

function FreeLookInput.new(): FreeLookInput
    return setmetatable(
        {
            Connections = {},
            MouseHeld = false,
            SavedBehavior = nil,
            Touch = nil,
            PendingMouse = Vector2.zero,
            PendingTouch = Vector2.zero,
            Gamepad = Enum.UserInputType.Gamepad1,
            Suspended = false,
        } :: InputFields,
        FreeLookInput
    )
end

local function isGamepad(inputType: Enum.UserInputType): boolean
    return string.sub(inputType.Name, 1, 7) == "Gamepad"
end

local function releaseMouse(self: FreeLookInput)
    if not self.MouseHeld then
        return
    end
    self.MouseHeld = false
    local saved = self.SavedBehavior
    self.SavedBehavior = nil
    -- On ne restaure que si personne d'autre n'a changé le comportement entre-temps.
    if saved and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCurrentPosition then
        UserInputService.MouseBehavior = saved
    end
end

-- Abandonne tout regard en cours (interface ouverte, saisie de texte, fin de
-- conduite, fenêtre sans focus) : souris rendue, doigt oublié, déplacements
-- en attente jetés. Un nouvel appui sera nécessaire pour reprendre.
function FreeLookInput.cancel(self: FreeLookInput)
    releaseMouse(self)
    self.Touch = nil
    self.PendingMouse = Vector2.zero
    self.PendingTouch = Vector2.zero
end

-- Suspension demandée par la caméra (interface ouverte, visée imposée…).
function FreeLookInput.setSuspended(self: FreeLookInput, suspended: boolean)
    if suspended and not self.Suspended then
        self:cancel()
    end
    self.Suspended = suspended
end

function FreeLookInput.connect(self: FreeLookInput)
    self:disconnect()
    local connections = self.Connections
    table.insert(
        connections,
        UserInputService.InputBegan:Connect(function(inputObject: InputObject, gameProcessed: boolean)
            local kind = inputObject.UserInputType
            if isGamepad(kind) then
                self.Gamepad = kind
                return
            end
            -- Appui sur un élément d'interface, ou caméra suspendue : rien.
            if gameProcessed or self.Suspended then
                return
            end
            if kind == Enum.UserInputType.MouseButton2 and not self.MouseHeld then
                self.MouseHeld = true
                self.SavedBehavior = UserInputService.MouseBehavior
                UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
            elseif kind == Enum.UserInputType.Touch and self.Touch == nil then
                self.Touch = inputObject
            end
        end)
    )
    table.insert(
        connections,
        UserInputService.InputChanged:Connect(function(inputObject: InputObject)
            local kind = inputObject.UserInputType
            if isGamepad(kind) then
                self.Gamepad = kind
            elseif kind == Enum.UserInputType.MouseMovement and self.MouseHeld then
                local delta = inputObject.Delta
                self.PendingMouse += Vector2.new(delta.X, delta.Y)
            elseif kind == Enum.UserInputType.Touch and inputObject == self.Touch then
                local delta = inputObject.Delta
                self.PendingTouch += Vector2.new(delta.X, delta.Y)
            end
        end)
    )
    table.insert(
        connections,
        UserInputService.InputEnded:Connect(function(inputObject: InputObject)
            local kind = inputObject.UserInputType
            if kind == Enum.UserInputType.MouseButton2 then
                releaseMouse(self)
            elseif kind == Enum.UserInputType.Touch and inputObject == self.Touch then
                self.Touch = nil
            end
        end)
    )
    -- Fenêtre sans focus : le relâchement du clic droit peut être perdu.
    table.insert(
        connections,
        UserInputService.WindowFocusReleased:Connect(function()
            self:cancel()
        end)
    )
end

function FreeLookInput.disconnect(self: FreeLookInput)
    for _, connection in self.Connections do
        connection:Disconnect()
    end
    table.clear(self.Connections)
    self:cancel()
    self.Suspended = false
end

local function readStick(gamepad: Enum.UserInputType): Vector2
    if not UserInputService:GetGamepadConnected(gamepad) then
        return Vector2.zero
    end
    for _, state in UserInputService:GetGamepadState(gamepad) do
        if state.KeyCode == Enum.KeyCode.Thumbstick2 then
            return Vector2.new(state.Position.X, state.Position.Y)
        end
    end
    return Vector2.zero
end

-- Déplacement du regard depuis le dernier appel (radians) et vrai si le
-- joueur « tient » le regard (le retour au centre attend alors).
function FreeLookInput.consume(
    self: FreeLookInput,
    dt: number,
    sensitivityLevel: number,
    invertY: boolean
): (number, number, boolean)
    if self.Suspended then
        return 0, 0, false
    end
    local mouse, touch = self.PendingMouse, self.PendingTouch
    self.PendingMouse = Vector2.zero
    self.PendingTouch = Vector2.zero
    local mouseYaw, mousePitch =
        FreeLook.pointerDelta(mouse.X, mouse.Y, FreeLook.MouseRadPerPixel, sensitivityLevel, invertY)
    local touchYaw, touchPitch =
        FreeLook.pointerDelta(touch.X, touch.Y, FreeLook.TouchRadPerPixel, sensitivityLevel, invertY)
    local stick = readStick(self.Gamepad)
    local stickYaw, stickPitch = FreeLook.stickDelta(stick.X, stick.Y, dt, sensitivityLevel, invertY)
    local holding = self.MouseHeld or self.Touch ~= nil or FreeLook.stickHeld(stick.X, stick.Y)
    return mouseYaw + touchYaw + stickYaw, mousePitch + touchPitch + stickPitch, holding
end

return FreeLookInput
