--!strict
--[[
    Conduite et caméra pendant l'entrée et la sortie (lot ANIM-03), côté client du conducteur. Appelé par
    `VehicleController` (deux appels, section « Lot ANIM-03 »).

    - Commandes : pendant sa propre séquence (entrée ou sortie) et tant qu'un passager monte ou descend (`AWDepartBloque`
      du modèle, décision du propriétaire du 2026-11-06 : départ bloqué), les commandes envoyées à la simulation sont
      neutres, frein à main serré : le véhicule reste immobile et l'animation n'est pas perturbée.
    - Caméra (décision du propriétaire : 3e personne qui suit) : la caméra du véhicule est suspendue pendant l'entrée et,
      à la sortie, dès l'ouverture de la porte ; la caméra par défaut suit alors la tête du personnage
      (`DoorVisuals`). Elle reprend la vue de conduite choisie une fois l'entrée terminée.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local VehiclesShared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Vehicles")
local Types = require(VehiclesShared:WaitForChild("VehicleTypes"))
local BoardingMotion = require(VehiclesShared:WaitForChild("BoardingMotion"))

local BoardingLock = {}

local function sequenceOf(character: Model?): BoardingMotion.Sequence?
    if character == nil then
        return nil
    end
    return BoardingMotion.decode(character:GetAttribute(BoardingMotion.Attribute))
end

-- Commandes du conducteur bloquées (séquence du conducteur, ou passager qui monte ou descend).
function BoardingLock.drivingLocked(model: Model, character: Model?): boolean
    if model:GetAttribute(BoardingMotion.DepartureAttribute) == true then
        return true
    end
    local sequence = sequenceOf(character)
    return sequence ~= nil and BoardingMotion.locked(sequence, Workspace:GetServerTimeNow())
end

-- Commandes neutres, frein à main serré, quand la conduite est bloquée.
function BoardingLock.filterInput(model: Model, character: Model?, input: Types.DriverInput): Types.DriverInput
    if not BoardingLock.drivingLocked(model, character) then
        return input
    end
    return { Throttle = 0, Brake = 0, Steer = 0, Handbrake = true, Clutch = 0 }
end

-- Suspend ou reprend la caméra du véhicule selon la séquence du joueur local.
function BoardingLock.holdCamera(camera: any, model: Model, character: Model?)
    local sequence = sequenceOf(character)
    local held = sequence ~= nil and BoardingMotion.cameraHeld(sequence, Workspace:GetServerTimeNow())
    if held and camera.Model ~= nil then
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        camera:stop(humanoid)
    elseif not held and camera.Model == nil then
        camera:start(model, Players.LocalPlayer.Character)
    end
end

return BoardingLock
