--!strict
--[[
    Gestionnaire des interfaces (lot 0.7) : ouverture, fermeture, retour,
    focus et règles de conduite (AUD-UI-01), pour TOUS les écrans (panneaux
    des lots 0.4 à 0.6 compris). Cœur pur : Shared/UI/UIStack, DrivingGate.

    - Une seule modale principale à la fois : ouvrir un écran ferme le
      précédent ; fermer rend le focus au contrôle d'avant.
    - Écran COMPLET demandé en roulant : refusé (ou ouvert en mode rapide s'il
      en a un) avec un message ; s'il était ouvert et que la voiture se met à
      rouler, il passe en mode rapide ou se masque en GARDANT son contenu
      (brouillon), sans rien valider. La voiture n'est jamais freinée, le
      monde jamais mis en pause.
    - Tant qu'une modale complète est ouverte (à l'arrêt ou à pied), les
      commandes de conduite sont ignorées (UIState.capturesDriving) ; elles
      devront être relâchées puis renouvelées (InputArbiter).
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIStack = require(Shared:WaitForChild("UI"):WaitForChild("UIStack"))
local DrivingGate = require(Shared.UI.DrivingGate)
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))

local UIState = require(script.Parent.UIState)

local UIManager = {}

export type Screen = {
    Name: string,
    Kind: UIStack.Kind,
    Full: boolean, -- exige l'arrêt ou la marche à pied
    Open: () -> (),
    Close: () -> (),
    Quick: ((boolean) -> ())?, -- bascule en mode rapide (conduite), sans perte de contenu
    Focus: (() -> GuiObject?)?,
}

local screens: { [string]: Screen } = {}
local stack = UIStack.new()
local demoted: { [string]: boolean } = {}
local notifier: (string, string) -> () = function(_key: string, _level: string) end
local started = false

function UIManager.register(screen: Screen)
    screens[screen.Name] = screen
end

-- Fonction d'affichage des messages (NotificationService), injectée au démarrage.
function UIManager.setNotifier(fn: (string, string) -> ())
    notifier = fn
end

local function refreshCapture()
    UIState.setCaptured(UIStack.capturesDriving(stack) and UIState.mode() ~= "Moving")
end

-- Lot 0.9.2 : focus de navigation seulement à la manette (règle du parcours d'arrivée,
-- lot 0.8). Au clavier et à la souris, le contour restait sur l'onglet d'ouverture et la
-- touche Entrée l'activait (onglet changé sans demande : essai VM du lot 0.9.1).
local function gamepadActive(): boolean
    return string.sub(UserInputService:GetLastInputType().Name, 1, 7) == "Gamepad"
end

local function focusOf(screen: Screen)
    if not gamepadActive() then
        GuiService.SelectedObject = nil
        return
    end
    local focus = screen.Focus
    local target = if focus then focus() else nil
    GuiService.SelectedObject = target
end

local function restoreFocus(previous: any)
    if
        typeof(previous) == "Instance"
        and previous:IsA("GuiObject")
        and previous:IsDescendantOf(game)
        and previous.Visible
    then
        GuiService.SelectedObject = previous
    else
        GuiService.SelectedObject = nil
    end
end

function UIManager.isOpen(name: string): boolean
    return UIStack.isOpen(stack, name)
end

function UIManager.open(name: string): boolean
    local screen = screens[name]
    if screen == nil then
        return false
    end
    local moving = UIState.mode() == "Moving"
    local quick = false
    if screen.Full and moving then
        if screen.Quick == nil then
            notifier("ui.blockedMoving", "Warning")
            return false
        end
        quick = true
    end
    local closed = UIStack.open(stack, name, screen.Kind, GuiService.SelectedObject, quick)
    for _, entry in closed do
        local other = screens[entry.Name]
        if other then
            other.Close()
        end
        demoted[entry.Name] = nil
    end
    screen.Open()
    if screen.Quick then
        (screen.Quick :: (boolean) -> ())(quick)
    end
    if quick then
        demoted[name] = true
    elseif not moving then
        -- En roulant, aucun bouton n'est sélectionné : la manette conduit, elle
        -- ne peut pas activer un bouton par mégarde.
        focusOf(screen)
    end
    refreshCapture()
    return true
end

function UIManager.close(name: string)
    local screen = screens[name]
    local ok, focus = UIStack.close(stack, name)
    if not ok or screen == nil then
        return
    end
    demoted[name] = nil
    screen.Close()
    restoreFocus(focus)
    refreshCapture()
end

function UIManager.toggle(name: string)
    if UIManager.isOpen(name) then
        UIManager.close(name)
    else
        UIManager.open(name)
    end
end

-- Retour : ferme l'écran du dessus. Renvoie vrai si un écran a été fermé.
function UIManager.back(): boolean
    local top = UIStack.top(stack)
    if top == nil then
        return false
    end
    UIManager.close(top.Name)
    return true
end

function UIManager.anyOpen(): boolean
    return UIStack.top(stack) ~= nil
end

-- Mode de conduite surveillé (0,2 s) : bascules rapide/complet sans validation.
local function watch()
    local character = Players.LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local seat = humanoid and humanoid.SeatPart
    local speed = 0
    if seat then
        speed = seat.AssemblyLinearVelocity.Magnitude * Constants.MetersPerStud
    end
    local before = UIState.mode()
    local mode: any = DrivingGate.mode(seat ~= nil, speed, before :: any)
    if mode == before then
        return
    end
    UIState.setMode(mode)
    if mode == "Moving" then
        for _, entry in table.clone(stack.Entries) do
            local screen = screens[entry.Name]
            if screen and screen.Full and not entry.Quick then
                if screen.Quick then
                    entry.Quick = true
                    demoted[entry.Name] = true;
                    (screen.Quick :: (boolean) -> ())(true)
                else
                    -- Masqué, contenu conservé ; rouvrir à l'arrêt le retrouve tel quel.
                    UIManager.close(entry.Name)
                end
                notifier("ui.draftKept", "Info")
            end
        end
        GuiService.SelectedObject = nil
    elseif before == "Moving" then
        for _, entry in stack.Entries do
            local screen = screens[entry.Name]
            if screen and demoted[entry.Name] and screen.Quick then
                entry.Quick = false
                demoted[entry.Name] = nil;
                (screen.Quick :: (boolean) -> ())(false)
                focusOf(screen)
            end
        end
    end
    refreshCapture()
end

function UIManager.start()
    if started then
        return
    end
    started = true
    -- Passage à la manette pendant qu'une fenêtre est ouverte (à l'arrêt) : focus posé.
    UserInputService.LastInputTypeChanged:Connect(function()
        local top = UIStack.top(stack)
        local screen = if top then screens[top.Name] else nil
        if screen and gamepadActive() and GuiService.SelectedObject == nil and UIState.mode() ~= "Moving" then
            focusOf(screen)
        end
    end)
    local timer = 0
    RunService.Heartbeat:Connect(function(dt)
        timer += dt
        if timer >= 0.2 then
            timer = 0
            watch()
        end
    end)
end

return UIManager
