--!strict
--[[
    Première connexion et formation (lot 0.8, AUD-ONB-01), canal AWOnboarding.

    - Progression du parcours dans le profil (Onboarding, schéma 5), par
      mutations NON sensibles (aucun crédit, aucun objet) ; règles pures :
      Shared/Onboarding/OnboardingRules.
    - Première apparition protégée : champ de force de 60 s (aucune
      invulnérabilité durable), seulement tant que le parcours n'est pas fini.
    - Essai facultatif d'un candidat : véhicule TEMPORAIRE protégé à côté du
      joueur (aucune écriture durable, jamais dans le profil, aucune
      récompense), 3 min au plus, un à la fois, rejouable.
    - Choix définitif : la transaction unique existante « Grant:Starter »
      (ProgressionService) — serveur, idempotente, non répétable, exemplaire
      incessible. Candidats : liste officielle (vide aujourd'hui) ou, en
      développement seulement, la proposition (exemplaires synthétiques).
    - Propriété gratuite : attribuée une fois au premier chargement
      (« Grant:FreeProperty ») ; le parcours la présente.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local OnboardingRules = require(Shared:WaitForChild("Onboarding"):WaitForChild("OnboardingRules"))
local StarterCatalog = require(Shared:WaitForChild("Garage"):WaitForChild("StarterCatalog"))
local VehicleCatalog = require(Shared:WaitForChild("Economy"):WaitForChild("VehicleCatalog"))
local WorkingCatalog =
    require(Shared:WaitForChild("Vehicles"):WaitForChild("Definitions"):WaitForChild("WorkingCatalog"))

local ProfileService = require(script.Parent.Parent.Persistence.ProfileService)
local RateLimiter = require(script.Parent.Parent.Security.RateLimiter)
local VehicleService = require(script.Parent.Parent.Vehicles.VehicleService)
local ProgressionService = require(script.Parent.Parent.Progression.ProgressionService)
local MissionService = require(script.Parent.Parent.Economy.MissionService)

local OnboardingService = {}

local FOLDER = "AWOnboarding"

local push: RemoteEvent
local limiters: { [Player]: RateLimiter.Bucket } = {}
local testDrives: { [Player]: { Model: Model, Until: number } } = {}
local protected: { [Player]: boolean } = {}

local function rejected(key: string): any
    return { Status = "Rejected", Error = key }
end

local function specOf(modelId: string): any?
    for _, spec in WorkingCatalog.Specs do
        if spec.Id == modelId then
            return spec
        end
    end
    return nil
end

-- Fiche comparative d'un candidat (données de la gamme, aucune donnée de profil).
local function candidateView(modelId: string): any
    local spec = specOf(modelId)
    local entry = VehicleCatalog.forDefinition(modelId)
    return {
        Id = modelId,
        Name = if spec then spec.Name else modelId,
        Category = if entry then entry.Category else "",
        Energy = if spec then spec.Base else "",
        Gearbox = if spec then spec.Gearbox else "",
        Layout = if spec then spec.Layout else "",
        PowerKw = if spec then spec.PowerKw else 0,
        MassKg = if spec then spec.MassKg else 0,
        Price = if entry then entry.Price else 0,
    }
end

local function status(player: Player): any
    local session = ProfileService.get(player)
    local profile = if session then session.Data else nil
    local candidates, synthetic = StarterCatalog.candidates(ProfileService.environment().Name)
    local list = {}
    for _, id in candidates do
        table.insert(list, candidateView(id))
    end
    return {
        State = if profile then profile.Onboarding else OnboardingRules.new(),
        StarterChosen = profile ~= nil and profile.Starter.State == "Chosen",
        StarterModel = if profile then profile.Starter.ModelId else nil,
        PropertyGranted = profile ~= nil and profile.Grants.FreeProperty ~= nil,
        Candidates = list,
        Official = StarterCatalog.available(),
        Synthetic = synthetic,
        TestDriveActive = testDrives[player] ~= nil,
    }
end

local function mutate(player: Player, fn: (any) -> (boolean, string?)): any
    local session = ProfileService.get(player)
    if session == nil or session.State ~= "Active" then
        return { Status = "Unavailable", Error = "ProfileUnavailable" }
    end
    local err: string? = nil
    session:mutate(function(profile)
        local ok, reason = fn(profile)
        err = reason
        return ok
    end)
    if err then
        return rejected(err :: string)
    end
    return { Status = "Ok", Result = status(player) }
end

local function endTestDrive(player: Player)
    local drive = testDrives[player]
    if drive then
        testDrives[player] = nil
        VehicleService.despawnPersonal(drive.Model)
    end
end

local handlers: { [string]: (Player, any) -> any } = {}

handlers.Status = function(player)
    return { Status = "Ok", Result = status(player) }
end

handlers.Advance = function(player, payload)
    local step = if type(payload) == "table" then payload.Step else nil
    return mutate(player, function(profile)
        return OnboardingRules.advance(profile.Onboarding, step, os.time())
    end)
end

handlers.Skip = function(player)
    return mutate(player, function(profile)
        OnboardingRules.skip(profile.Onboarding, profile.Starter.State == "Chosen", os.time())
        return true, nil
    end)
end

handlers.TestDrive = function(player, payload)
    local modelId = if type(payload) == "table" then payload.ModelId else nil
    local candidates = StarterCatalog.candidates(ProfileService.environment().Name)
    if type(modelId) ~= "string" or table.find(candidates, modelId) == nil then
        return rejected("StarterNotCandidate")
    end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid == nil or humanoid.SeatPart ~= nil then
        return rejected("LeaveVehicleFirst")
    end
    endTestDrive(player)
    local model =
        MissionService.spawnBeside(player, modelId, "ESSAI-" .. string.sub(HttpService:GenerateGUID(false), 1, 8))
    if model == nil then
        return rejected("NoSpaceForVehicle")
    end
    testDrives[player] = { Model = model, Until = os.clock() + OnboardingRules.TestDriveS }
    local session = ProfileService.get(player)
    if session and session.Data then
        session:mutate(function(profile)
            profile.Onboarding.TestDrives += 1
            return true
        end)
    end
    return { Status = "Ok", Result = status(player) }
end

handlers.EndTestDrive = function(player)
    endTestDrive(player)
    return { Status = "Ok", Result = status(player) }
end

handlers.Choose = function(player, payload)
    local modelId = if type(payload) == "table" then payload.ModelId else nil
    endTestDrive(player)
    local response = ProgressionService.chooseStarter(player, modelId)
    if response.Status == "Confirmed" or response.Status == "Pending" or response.Status == "Duplicate" then
        local session = ProfileService.get(player)
        if session then
            session:mutate(function(profile)
                OnboardingRules.starterChosen(profile.Onboarding, os.time())
                return true
            end)
        end
    end
    return { Status = response.Status, Error = response.Error, Result = status(player) }
end

handlers.Exercise = function(player, payload)
    local id = if type(payload) == "table" then payload.Id else nil
    return mutate(player, function(profile)
        return OnboardingRules.exercise(profile.Onboarding, id, os.time())
    end)
end

local function handle(player: Player, action: any, payload: any): any
    if type(action) ~= "string" or handlers[action] == nil then
        return rejected("ActionUnknown")
    end
    local bucket = limiters[player]
    if bucket == nil then
        bucket = RateLimiter.new(6, 2, os.clock())
        limiters[player] = bucket
    end
    if not RateLimiter.consume(bucket, os.clock()) then
        return rejected("RateLimited")
    end
    local ok, response = pcall(handlers[action], player, payload)
    if not ok then
        ProfileService.Log:write("Error", "OnboardingHandlerFailed", { Action = action, Error = tostring(response) })
        return rejected("ServerError")
    end
    return response
end

-- Première apparition protégée (champ de force temporaire, une fois par session).
local function protect(player: Player, character: Model)
    if protected[player] then
        return
    end
    local session = ProfileService.get(player)
    local state = if session and session.Data then session.Data.Onboarding else nil
    if state == nil or OnboardingRules.completed(state) then
        return
    end
    protected[player] = true
    local field = Instance.new("ForceField")
    field.Name = "ProtectionArrivee"
    field.Visible = true
    field.Parent = character
    task.delay(OnboardingRules.SpawnProtectionS, function()
        if field.Parent then
            field:Destroy()
        end
    end)
end

function OnboardingService.start()
    local existing = ReplicatedStorage:FindFirstChild(FOLDER)
    if existing then
        existing:Destroy()
    end
    local folder = Instance.new("Folder")
    folder.Name = FOLDER
    local request = Instance.new("RemoteFunction")
    request.Name = "Request"
    request.Parent = folder
    push = Instance.new("RemoteEvent")
    push.Name = "Push"
    push.Parent = folder
    folder.Parent = ReplicatedStorage
    request.OnServerInvoke = function(player: Player, action: any, payload: any): any
        return handle(player, action, payload)
    end
    ProfileService.onLoaded(function(player, _session)
        push:FireClient(player, "Status", status(player))
        if player.Character then
            protect(player, player.Character)
        end
    end)
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(character)
            protect(player, character)
        end)
    end)
    Players.PlayerRemoving:Connect(function(player)
        endTestDrive(player)
        limiters[player] = nil
        protected[player] = nil
    end)
    -- Essais : limités dans le temps (aucun véhicule temporaire oublié).
    RunService.Heartbeat:Connect(function()
        local now = os.clock()
        for player, drive in testDrives do
            if now > drive.Until or drive.Model.Parent == nil then
                endTestDrive(player)
                push:FireClient(player, "Status", status(player))
            end
        end
    end)
end

return table.freeze(OnboardingService)
