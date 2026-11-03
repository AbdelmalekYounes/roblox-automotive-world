--!strict
--[[
    Cycle de vie des profils sur ce serveur (lot 0.4).

    - Environnement résolu une fois (Environment) : mémoire en Dev, DataStore
      seulement pour les expériences de test ou de production déclarées.
    - Arrivée d'un joueur : chargement sous verrou (nouvelles tentatives si un
      autre serveur ne l'a pas encore rendu), normalisation, attribution
      unique de la propriété gratuite (transaction fixe), données synthétiques
      en Dev seulement.
    - Battement d'une seconde : sauvegardes en attente, sauvegarde périodique
      (60 s) et rafraîchissement du verrou ; aucune écriture par image.
    - Départ : rappels des services (véhicule rangé, état durable), puis
      sauvegarde finale et libération du verrou. Arrêt du serveur : idem pour
      tous les joueurs (BindToClose), en parallèle.
    - État publié au client (attribut AWProfileState) pour l'indication de
      chargement et de sauvegarde ; jamais une réussite avant confirmation.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Environment = require(script.Parent.Environment)
local EnvironmentConfig = require(script.Parent.EnvironmentConfig)
local ProfileRepository = require(script.Parent.ProfileRepository)
local MemoryProfileRepository = require(script.Parent.MemoryProfileRepository)
local DataStoreProfileRepository = require(script.Parent.DataStoreProfileRepository)
local ProfileSession = require(script.Parent.ProfileSession)
local StructuredLog = require(script.Parent.StructuredLog)

local Progression = script.Parent.Parent.Progression
local GarageRules = require(Progression.GarageRules)
local PropertyRules = require(Progression.PropertyRules)
local DevSeed = require(Progression.DevSeed)

local VehicleDefinitions =
    require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Vehicles"):WaitForChild("VehicleDefinitions"))

local ProfileService = {}

local LOCKED_RETRIES = 8
local LOCKED_RETRY_S = 5
local UNAVAILABLE_RETRIES = 3
local SHUTDOWN_BUDGET_S = 25

ProfileService.StateAttribute = "AWProfileState"

local started = false
local resolved: Environment.Resolved
local repository: any
local sessions: { [Player]: ProfileSession.Session } = {}
local loadedCallbacks: { (Player, ProfileSession.Session) -> () } = {}
local releasingCallbacks: { (Player, ProfileSession.Session) -> () } = {}
local confirmedCallbacks: { (Player, { string }) -> () } = {}
local log = StructuredLog.new(500, os.time, function(entry)
    if entry.Level ~= "Info" then
        warn(StructuredLog.format(entry))
    end
end)
ProfileService.Log = log

local function publish(player: Player, state: string)
    player:SetAttribute(ProfileService.StateAttribute, state)
end

function ProfileService.environment(): Environment.Resolved
    return resolved
end

function ProfileService.get(player: Player): ProfileSession.Session?
    return sessions[player]
end

-- Session active d'un joueur présent sur CE serveur, par UserId.
function ProfileService.byUserId(userId: number): (Player?, ProfileSession.Session?)
    local player = Players:GetPlayerByUserId(userId)
    if player then
        return player, sessions[player]
    end
    return nil, nil
end

function ProfileService.onLoaded(callback: (Player, ProfileSession.Session) -> ())
    table.insert(loadedCallbacks, callback)
end

function ProfileService.onReleasing(callback: (Player, ProfileSession.Session) -> ())
    table.insert(releasingCallbacks, callback)
end

function ProfileService.onConfirmed(callback: (Player, { string }) -> ())
    table.insert(confirmedCallbacks, callback)
end

local function newSession(player: Player): ProfileSession.Session
    return ProfileSession.new({
        Repository = repository,
        Key = ProfileRepository.keyFor(player.UserId),
        UserId = player.UserId,
        Session = HttpService:GenerateGUID(false),
        Server = if game.JobId ~= "" then game.JobId else "studio",
        Environment = resolved.Name,
        Clock = os.time,
        Token = function()
            return HttpService:GenerateGUID(false)
        end,
        Log = log,
        LockTtl = 300,
        MinWriteInterval = 6,
        AutosaveInterval = 60,
        OnLoaded = function(profile, now)
            return GarageRules.normalize(profile, now)
        end,
    })
end

local function load(player: Player)
    publish(player, "Loading")
    local session = newSession(player)
    local state = session:load()
    local lockedTries, unavailableTries = 0, 0
    while (state == "Locked" or state == "Unavailable") and player.Parent == Players do
        if state == "Locked" then
            lockedTries += 1
            if lockedTries > LOCKED_RETRIES then
                break
            end
            task.wait(LOCKED_RETRY_S)
        else
            unavailableTries += 1
            if unavailableTries > UNAVAILABLE_RETRIES then
                break
            end
            task.wait(2 ^ unavailableTries)
        end
        session = newSession(player)
        state = session:load()
    end
    if player.Parent ~= Players then
        -- Parti pendant le chargement : rendre le verrou tout de suite.
        if state == "Active" or state == "ReadOnly" then
            session:save(true)
        end
        return
    end
    sessions[player] = session
    if state ~= "Active" then
        publish(player, state)
        return
    end

    -- Attributions uniques : transactions d'identifiant fixe (idempotentes
    -- même si le joueur part pendant l'initialisation).
    session:commit(PropertyRules.FreeGrantTxId, "FreeProperty", function(profile)
        if profile.Grants.FreeProperty ~= nil then
            return false, "FreePropertyAlreadyGranted"
        end
        return PropertyRules.grantFree(profile, os.time())
    end)
    if Environment.allowsSynthetic(resolved) then
        session:commit(DevSeed.TxId, "DevSeed", function(profile)
            return DevSeed.apply(profile, os.time(), function(modelId)
                return VehicleDefinitions.get(modelId)
            end)
        end)
    end
    publish(player, if session:dirty() then "Saving" else "Saved")
    for _, callback in loadedCallbacks do
        task.spawn(callback, player, session)
    end
end

local function release(player: Player)
    local session = sessions[player]
    if not session then
        return
    end
    for _, callback in releasingCallbacks do
        local ok, err = pcall(function()
            callback(player, session)
        end)
        if not ok then
            log:write("Error", "ReleaseCallbackFailed", { Error = tostring(err) })
        end
    end
    -- Une écriture en cours (sauvegarde périodique) doit se terminer d'abord.
    local status = session:save(true)
    local waited = 0
    while status == "Busy" and waited < SHUTDOWN_BUDGET_S do
        task.wait(0.5)
        waited += 0.5
        status = session:save(true)
    end
    if status ~= "Released" and status ~= "Skipped" then
        log:write("Warn", "ReleaseIncomplete", { Status = status, UserId = player.UserId })
    end
    sessions[player] = nil
end

function ProfileService.start()
    assert(not started, "ProfileService déjà démarré")
    started = true
    resolved = Environment.resolve(game.GameId, RunService:IsStudio(), EnvironmentConfig)
    if resolved.Store == "DataStore" then
        repository = DataStoreProfileRepository.new(resolved.StoreName)
    else
        repository = MemoryProfileRepository.new(resolved.StoreName)
    end
    ReplicatedStorage:SetAttribute("AWStorageEnvironment", resolved.Name)
    log:write(
        "Info",
        "ProfileServiceStarted",
        { Environment = resolved.Name, Store = resolved.Store, Reason = resolved.Reason }
    )
    print(
        string.format(
            "[AutomotiveWorld] Profils : environnement %s, stockage %s (%s)",
            resolved.Name,
            resolved.Store,
            resolved.Reason
        )
    )

    Players.PlayerAdded:Connect(function(player)
        load(player)
    end)
    for _, player in Players:GetPlayers() do
        task.spawn(load, player)
    end
    Players.PlayerRemoving:Connect(release)

    local accumulator = 0
    RunService.Heartbeat:Connect(function(dt)
        accumulator += dt
        if accumulator < 1 then
            return
        end
        accumulator = 0
        for player, session in sessions do
            task.spawn(function()
                local status = session:tick()
                if status == "Saved" then
                    publish(player, if session:dirty() then "Saving" else "Saved")
                elseif status == "Failed" then
                    publish(player, "SaveDelayed")
                end
                if session.State == "Lost" then
                    publish(player, "Lost")
                end
                local confirmed = session:takeConfirmed()
                if #confirmed > 0 then
                    for _, callback in confirmedCallbacks do
                        task.spawn(callback, player, confirmed)
                    end
                end
            end)
        end
    end)

    game:BindToClose(function()
        local remaining = 0
        for player in sessions do
            remaining += 1
            task.spawn(function()
                release(player)
                remaining -= 1
            end)
        end
        local waited = 0
        while remaining > 0 and waited < SHUTDOWN_BUDGET_S do
            task.wait(0.5)
            waited += 0.5
        end
    end)
end

-- Marque l'état « en cours d'écriture » visible du client après une mutation.
function ProfileService.markDirty(player: Player)
    local session = sessions[player]
    if session and session:dirty() then
        publish(player, "Saving")
    end
end

return table.freeze(ProfileService)
