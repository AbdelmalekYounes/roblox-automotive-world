--!strict
--[[
    Paramètres (lot 0.7) : lecture des préférences reçues du serveur,
    modifications locales immédiates (UIState), envoi DIFFÉRÉ et regroupé au
    serveur (au plus toutes les 5 s, seulement si quelque chose a changé) :
    aucune écriture pour chaque clic. Langue changée à chaud.
    Volumes : groupes de sons du jeu (aucun son original n'existe encore,
    lot 0.8) ; le volume général de Roblox reste un réglage du joueur.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Preferences = require(Shared:WaitForChild("UI"):WaitForChild("Preferences"))
local Localization = require(Shared.UI.Localization)
local InputMap = require(Shared.UI.InputMap)

local UIState = require(script.Parent.UIState)
local DevHud = require(script.Parent.DevHud)

local SettingsController = {}

local request: RemoteFunction
local lastSent: Preferences.Prefs? = nil
local dirtySince: number? = nil
local lastSendAt = -math.huge

local function applyAudio(prefs: Preferences.Prefs)
    for _, name in { "Vehicles", "Interface", "World" } do
        local groupName = "AW" .. name
        local group = SoundService:FindFirstChild(groupName)
        if group == nil then
            group = Instance.new("SoundGroup")
            group.Name = groupName
            group.Parent = SoundService
        end
        (group :: SoundGroup).Volume = (prefs.Audio :: any)[name] / 100 * prefs.Audio.Master / 100
    end
end

local function apply(prefs: Preferences.Prefs)
    Localization.setLanguage(prefs.Language)
    DevHud.setEnabled(prefs.Hud.DevHud)
    applyAudio(prefs)
end

-- Modification d'une préférence : `mutate` reçoit une copie.
function SettingsController.update(mutate: (Preferences.Prefs) -> ())
    local copy = Preferences.copy(UIState.prefs())
    mutate(copy)
    local clean = Preferences.sanitize(copy, InputMap.actions())
    if Preferences.equal(clean, UIState.prefs()) then
        return
    end
    UIState.setPrefs(clean)
    apply(clean)
    dirtySince = dirtySince or os.clock()
end

function SettingsController.reset()
    SettingsController.update(function(prefs)
        local defaults = Preferences.defaults()
        for key, value in defaults do
            (prefs :: any)[key] = value
        end
    end)
end

local function flush()
    if dirtySince == nil or os.clock() - lastSendAt < Preferences.SendIntervalS then
        return
    end
    local current = UIState.prefs()
    if lastSent and Preferences.equal(lastSent, current) then
        dirtySince = nil
        return
    end
    lastSendAt = os.clock()
    dirtySince = nil
    local ok, response = pcall(function()
        return request:InvokeServer("SavePreferences", { Prefs = current })
    end)
    if ok and type(response) == "table" and response.Status == "Ok" then
        lastSent = Preferences.copy(current)
    else
        dirtySince = os.clock() -- nouvel essai au prochain passage
    end
end

function SettingsController.start()
    local folder = ReplicatedStorage:WaitForChild("AWInterface")
    request = folder:WaitForChild("Request") :: RemoteFunction
    local push = folder:WaitForChild("Push") :: RemoteEvent
    push.OnClientEvent:Connect(function(kind: any, data: any)
        if kind == "Preferences" and type(data) == "table" then
            local clean = Preferences.sanitize(data, InputMap.actions())
            lastSent = Preferences.copy(clean)
            UIState.setPrefs(clean)
            apply(clean)
        end
    end)
    apply(UIState.prefs())
    task.spawn(function()
        local ok, response = pcall(function()
            return request:InvokeServer("Preferences")
        end)
        if ok and type(response) == "table" and type(response.Result) == "table" and lastSent == nil then
            local clean = Preferences.sanitize(response.Result, InputMap.actions())
            lastSent = Preferences.copy(clean)
            UIState.setPrefs(clean)
            apply(clean)
        end
        while true do
            task.wait(1)
            flush()
        end
    end)
end

function SettingsController.request(action: string, payload: any?): any
    local ok, response = pcall(function()
        return request:InvokeServer(action, payload or {})
    end)
    if not ok or type(response) ~= "table" then
        return { Status = "Error", Error = "ServerUnreachable" }
    end
    return response
end

return SettingsController
