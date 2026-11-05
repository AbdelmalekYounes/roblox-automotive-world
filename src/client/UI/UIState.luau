--!strict
--[[
    État partagé de l'interface côté client (lot 0.7) : préférences en cours,
    mode de conduite (à pied, à l'arrêt, en mouvement), capture des commandes
    de conduite par une interface modale, et abonnements aux changements.
    Ne contient AUCUNE donnée sensible : soldes, collections et résultats
    restent détenus par le serveur et ne sont lus que dans les réponses.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Preferences = require(Shared:WaitForChild("UI"):WaitForChild("Preferences"))
local DrivingGate = require(Shared.UI.DrivingGate)
local DesignTokens = require(Shared.UI:WaitForChild("DesignTokens"))

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

-- Taille de la vue utilisée par les mises en page (px). Studio SEULEMENT : surcharge d'essai par l'attribut
-- `AWTestViewport` (Vector2) de ReplicatedStorage, pour vérifier les résolutions de référence (1280 × 720 à
-- 3440 × 1440) dans la fenêtre fixe de la VM ; ignorée hors Studio.
function UIState.viewport(): Vector2
    if RunService:IsStudio() then
        local override = ReplicatedStorage:GetAttribute("AWTestViewport")
        if typeof(override) == "Vector2" then
            return override
        end
    end
    local camera = Workspace.CurrentCamera
    return if camera then camera.ViewportSize else Vector2.new(1920, 1080)
end

-- Disposition de la maquette (§3) pour la vue courante : échelle (1440 p = 1,333), disposition compacte.
function UIState.layout(): DesignTokens.Layout
    local size = UIState.viewport()
    return DesignTokens.layout(size.X, size.Y)
end

-- Appelé quand la taille de la vue change (fenêtre redimensionnée, surcharge d'essai).
function UIState.onViewport(listener: () -> ())
    local function bind(camera: Camera?)
        if camera then
            camera:GetPropertyChangedSignal("ViewportSize"):Connect(listener)
        end
    end
    bind(Workspace.CurrentCamera)
    Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        bind(Workspace.CurrentCamera)
        listener()
    end)
    ReplicatedStorage:GetAttributeChangedSignal("AWTestViewport"):Connect(listener)
end

-- Vrai tant qu'une interface modale complète est ouverte (lu par DriverInput).
function UIState.capturesDriving(): boolean
    return captured
end

function UIState.setCaptured(value: boolean)
    captured = value
end

return UIState
