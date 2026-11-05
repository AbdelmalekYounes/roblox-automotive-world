--!strict
--[[
    État partagé de l'interface côté client (lot 0.7) : préférences en cours,
    mode de conduite (à pied, à l'arrêt, en mouvement), capture des commandes
    de conduite par une interface modale, et abonnements aux changements.
    Ne contient AUCUNE donnée sensible : soldes, collections et résultats
    restent détenus par le serveur et ne sont lus que dans les réponses.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Preferences = require(Shared:WaitForChild("UI"):WaitForChild("Preferences"))
local DrivingGate = require(Shared.UI.DrivingGate)

local UIState = {}

local prefs: Preferences.Prefs = Preferences.defaults()
local mode: DrivingGate.Mode = "OnFoot"
local captured = false
local prefListeners: { (Preferences.Prefs) -> () } = {}
local modeListeners: { (DrivingGate.Mode) -> () } = {}

function UIState.prefs(): Preferences.Prefs
    return prefs
end

function UIState.setPrefs(value: Preferences.Prefs)
    prefs = value
    for _, listener in prefListeners do
        task.spawn(listener, prefs)
    end
end

function UIState.onPrefs(listener: (Preferences.Prefs) -> ())
    table.insert(prefListeners, listener)
end

function UIState.mode(): DrivingGate.Mode
    return mode
end

function UIState.setMode(value: DrivingGate.Mode)
    if value ~= mode then
        mode = value
        for _, listener in modeListeners do
            task.spawn(listener, mode)
        end
    end
end

function UIState.onMode(listener: (DrivingGate.Mode) -> ())
    table.insert(modeListeners, listener)
end

-- Vrai tant qu'une interface modale complète est ouverte (lu par DriverInput).
function UIState.capturesDriving(): boolean
    return captured
end

function UIState.setCaptured(value: boolean)
    captured = value
end

return UIState
