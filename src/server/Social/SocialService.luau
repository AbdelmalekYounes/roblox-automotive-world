--!strict
--[[
    Groupes, invitations, partage de position et communications (lot 0.7,
    §7.3, AUD-SOC-01, AUD-PRIV-01), canal AWSocial.

    - Règles : Social/GroupRules (pures). Le serveur revalide chaque demande ;
      le groupe ne donne AUCUN droit sur les propriétés, les voitures, les
      prêts ou l'économie (ces droits restent vérifiés par leurs services).
    - Vue envoyée à chaque destinataire : filtrée (identité d'affichage, rôle,
      présence, partage, ami) ; positions : seulement celles des membres de
      SON groupe qui partagent, une fois par seconde.
    - Communications : canaux OFFICIELS de TextChatService (filtrage, âge,
      confidentialité et modération gérés par Roblox) : un canal texte par
      groupe et un canal de proximité (remise limitée à 80 m). Aucun
      message texte propre au jeu. La voix suit les paramètres Roblox du
      joueur (non gérée). Si TextChatService n'est pas disponible ou refuse
      un joueur, le canal est indiqué indisponible (jamais contourné).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))
local RaceCourses = require(Shared:WaitForChild("Racing"):WaitForChild("RaceCourses"))

local ProfileService = require(script.Parent.Parent.Persistence.ProfileService)
local RateLimiter = require(script.Parent.Parent.Security.RateLimiter)
local GroupRules = require(script.Parent.GroupRules)

local SocialService = {}

local S = 1 / Constants.MetersPerStud
local FOLDER = "AWSocial"
local POSITION_S = 1
local TICK_S = 2
local PROXIMITY_M = 80

local started = false
local push: RemoteEvent
local registry: GroupRules.Registry
local limiters: { [Player]: RateLimiter.Bucket } = {}
local friendCache: { [string]: boolean } = {}
local channels: { [string]: TextChannel } = {}
local proximity: TextChannel? = nil

local function now(): number
    return os.clock()
end

local function rejected(key: string): any
    return { Status = "Rejected", Error = key }
end

local function friends(a: Player, b: Player): boolean
    local key = if a.UserId < b.UserId then a.UserId .. ":" .. b.UserId else b.UserId .. ":" .. a.UserId
    local cached = friendCache[key]
    if cached ~= nil then
        return cached
    end
    local ok, result = pcall(function()
        return a:IsFriendsWith(b.UserId)
    end)
    local value = ok and result == true
    friendCache[key] = value
    return value
end

local function acceptsInvites(player: Player): boolean
    local session = ProfileService.get(player)
    local prefs = if session and session.Data then session.Data.Preferences else nil
    return not (prefs and prefs.Social and prefs.Social.AcceptInvites == false)
end

-- ======================== Communications (TextChatService) ========================

local function chatAvailable(): boolean
    local ok, version = pcall(function()
        return TextChatService.ChatVersion
    end)
    return ok and version == Enum.ChatVersion.TextChatService
end

local function groupChannel(groupId: string): TextChannel?
    if not chatAvailable() then
        return nil
    end
    local channel: TextChannel? = channels[groupId]
    if channel == nil then
        local created = Instance.new("TextChannel")
        created.Name = "AWGroup_" .. groupId
        created.Parent = TextChatService
        channels[groupId] = created
        channel = created
    end
    return channel
end

local function addToChannel(channel: TextChannel?, player: Player): boolean
    if channel == nil then
        return false
    end
    local ok, source = pcall(function()
        return channel:AddUserAsync(player.UserId)
    end)
    -- AddUserAsync renvoie (TextSource, succès) : refus = paramètres Roblox du joueur.
    return ok and source ~= nil
end

local function removeFromChannel(channel: TextChannel?, player: Player)
    if channel == nil then
        return
    end
    for _, child in channel:GetChildren() do
        if child:IsA("TextSource") and child.UserId == player.UserId then
            child:Destroy()
        end
    end
end

local function closeChannel(groupId: string)
    local channel = channels[groupId]
    if channel then
        channel:Destroy()
        channels[groupId] = nil
    end
end

local function setupProximity()
    if not chatAvailable() then
        return
    end
    local channel = Instance.new("TextChannel")
    channel.Name = "AWProximity"
    channel.Parent = TextChatService
    -- Remise limitée aux joueurs proches ; le filtrage du texte reste celui de Roblox.
    channel.ShouldDeliverCallback = function(message: TextChatMessage, target: TextSource): boolean
        local from = if message.TextSource then Players:GetPlayerByUserId(message.TextSource.UserId) else nil
        local to = Players:GetPlayerByUserId(target.UserId)
        local a = from and from.Character and from.Character:FindFirstChild("HumanoidRootPart")
        local b = to and to.Character and to.Character:FindFirstChild("HumanoidRootPart")
        if a == nil or b == nil or not a:IsA("BasePart") or not b:IsA("BasePart") then
            return false
        end
        return (a.Position - b.Position).Magnitude * Constants.MetersPerStud <= PROXIMITY_M
    end
    proximity = channel
end

-- ======================== Vues et événements ========================

local function directory(viewer: Player): (number) -> any
    return function(userId: number): any
        local player = Players:GetPlayerByUserId(userId)
        if player == nil then
            return { Name = tostring(userId) }
        end
        return { Name = player.DisplayName, Friend = player ~= viewer and friends(viewer, player) }
    end
end

local function viewFor(player: Player): any
    local view = GroupRules.view(registry, player.UserId, directory(player), now())
    local others = {}
    for _, other in Players:GetPlayers() do
        if other ~= player then
            table.insert(others, {
                UserId = other.UserId,
                Name = other.DisplayName,
                Friend = friends(player, other),
                InGroup = registry.MemberOf[other.UserId] ~= nil,
            })
        end
    end
    table.sort(others, function(a, b)
        if a.Friend ~= b.Friend then
            return a.Friend
        end
        return a.Name < b.Name
    end)
    view.Players = others
    view.Channels = {
        Group = view.Group ~= nil and (channels :: any)[view.Group.Id] ~= nil,
        Proximity = proximity ~= nil,
        Chat = chatAvailable(),
    }
    return view
end

local function pushView(player: Player)
    push:FireClient(player, "View", viewFor(player))
end

local function pushGroup(groupId: string?)
    local group = if groupId then registry.Groups[groupId] else nil
    if group then
        for _, userId in group.Order do
            local member = Players:GetPlayerByUserId(userId)
            if member then
                pushView(member)
            end
        end
    end
end

local function notify(userId: number, key: string, params: any?)
    local player = Players:GetPlayerByUserId(userId)
    if player then
        push:FireClient(player, "Notice", { Key = key, Params = params })
    end
end

local function nameOf(userId: number): string
    local player = Players:GetPlayerByUserId(userId)
    return if player then player.DisplayName else tostring(userId)
end

-- Conséquences des événements : canaux, partage arrêté, notifications.
local function apply(events: { GroupRules.Event }, groupBefore: string?)
    for _, event in events do
        local userId = event.UserId or 0
        local player = if event.UserId then Players:GetPlayerByUserId(userId) else nil
        if event.Kind == "Left" or event.Kind == "Kicked" or event.Kind == "TimedOut" then
            if player then
                removeFromChannel(channels[event.GroupId :: string], player)
                push:FireClient(player, "Positions", {})
                if event.Kind == "Kicked" then
                    notify(userId, "social.kicked")
                end
                pushView(player)
            end
            local group = registry.Groups[event.GroupId :: string]
            if group then
                for _, other in group.Order do
                    notify(other, "social.left", { name = nameOf(userId) })
                end
            end
        elseif event.Kind == "Dissolved" then
            if player then
                push:FireClient(player, "Positions", {})
                notify(userId, "social.dissolved")
                pushView(player)
            end
            closeChannel(event.GroupId :: string)
        elseif event.Kind == "NewLeader" then
            local group = registry.Groups[event.GroupId :: string]
            if group then
                for _, other in group.Order do
                    notify(other, "social.newLeader", { name = nameOf(userId) })
                end
            end
        elseif event.Kind == "SharingEnded" then
            notify(userId, "social.sharingEnded")
        end
    end
    pushGroup(groupBefore)
end

-- ======================== Requêtes ========================

local handlers: { [string]: (Player, any) -> any } = {}

handlers.Snapshot = function(player)
    return { Status = "Ok", Result = viewFor(player) }
end

handlers.CreateGroup = function(player)
    local group, err = GroupRules.create(registry, player.UserId, now())
    if group == nil then
        return rejected(err :: string)
    end
    addToChannel(groupChannel(group.Id), player)
    pushView(player)
    return { Status = "Ok" }
end

handlers.Invite = function(player, payload)
    local targetId = if type(payload) == "table" then tonumber(payload.UserId) else nil
    local target = if targetId then Players:GetPlayerByUserId(targetId) else nil
    if target == nil then
        return rejected("GroupTargetAbsent")
    end
    local hadGroup = registry.MemberOf[player.UserId] ~= nil
    local invite, err = GroupRules.invite(registry, player.UserId, target.UserId, now(), acceptsInvites(target))
    if invite == nil then
        return rejected(err :: string)
    end
    if not hadGroup then
        addToChannel(groupChannel(invite.GroupId), player)
    end
    push:FireClient(target, "Invite", { Id = invite.Id, From = player.DisplayName })
    notify(target.UserId, "social.invited", { name = player.DisplayName })
    pushView(player)
    pushView(target)
    return { Status = "Ok", Result = { Name = target.DisplayName } }
end

handlers.Accept = function(player, payload)
    local group, err =
        GroupRules.accept(registry, player.UserId, if type(payload) == "table" then payload.InviteId else nil, now())
    if group == nil then
        pushView(player)
        return rejected(err :: string)
    end
    addToChannel(groupChannel(group.Id), player)
    for _, other in group.Order do
        if other ~= player.UserId then
            notify(other, "social.joined", { name = player.DisplayName })
        end
    end
    pushGroup(group.Id)
    return { Status = "Ok" }
end

handlers.Decline = function(player, payload)
    GroupRules.decline(registry, player.UserId, if type(payload) == "table" then payload.InviteId else nil)
    pushView(player)
    return { Status = "Ok" }
end

handlers.RevokeInvite = function(player, payload)
    local inviteId = if type(payload) == "table" then payload.InviteId else nil
    local invite = if type(inviteId) == "string" then registry.Invites[inviteId] else nil
    if not GroupRules.revokeInvite(registry, player.UserId, inviteId) then
        return rejected("GroupNotLeader")
    end
    if invite then
        local target = Players:GetPlayerByUserId(invite.To)
        if target then
            pushView(target)
        end
    end
    pushView(player)
    return { Status = "Ok" }
end

local function groupAction(
    fn: (GroupRules.Registry, number, number) -> ({ GroupRules.Event }, string?)
): (Player, any) -> any
    return function(player, payload)
        local before = registry.MemberOf[player.UserId]
        local targetId = if type(payload) == "table" then tonumber(payload.UserId) or 0 else 0
        local events, err = fn(registry, player.UserId, targetId)
        if err then
            return rejected(err)
        end
        apply(events, before)
        return { Status = "Ok" }
    end
end

handlers.Kick = groupAction(GroupRules.kick)
handlers.Promote = groupAction(GroupRules.promote)
handlers.Leave = groupAction(function(r, userId, _)
    return GroupRules.leave(r, userId)
end)
handlers.Dissolve = groupAction(function(r, userId, _)
    return GroupRules.dissolve(r, userId)
end)

handlers.SetSharing = function(player, payload)
    local on = type(payload) == "table" and payload.On == true
    local ok, err = GroupRules.setSharing(registry, player.UserId, on, now())
    if not ok then
        return rejected(err :: string)
    end
    if on then
        notify(player.UserId, "social.sharingOn", { minutes = math.floor(GroupRules.SharingMaxS / 60) })
    else
        notify(player.UserId, "social.sharingOff")
    end
    pushGroup(registry.MemberOf[player.UserId])
    return { Status = "Ok" }
end

-- Proposition d'épreuve au groupe : chacun s'inscrit lui-même, sur place.
handlers.SuggestRace = function(player, payload)
    local group = GroupRules.groupOf(registry, player.UserId)
    local course = RaceCourses.get(if type(payload) == "table" then payload.CourseId else nil)
    if group == nil then
        return rejected("GroupNone")
    end
    if course == nil then
        return rejected("RaceUnknown")
    end
    for _, userId in group.Order do
        if userId ~= player.UserId then
            notify(userId, "social.raceSuggested", { name = player.DisplayName, course = course.Name })
            local member = Players:GetPlayerByUserId(userId)
            if member then
                push:FireClient(member, "RaceSuggested", { CourseId = course.Id })
            end
        end
    end
    return { Status = "Ok" }
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
        ProfileService.Log:write("Error", "SocialHandlerFailed", { Action = action, Error = tostring(response) })
        return rejected("ServerError")
    end
    return response
end

-- Positions partagées : chaque destinataire ne reçoit que celles de SON groupe.
local function sendPositions()
    local positions: { [number]: any } = {}
    for _, player in Players:GetPlayers() do
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root and root:IsA("BasePart") then
            local look = root.CFrame.LookVector
            positions[player.UserId] =
                { X = root.Position.X / S, Z = root.Position.Z / S, Heading = math.atan2(look.X, -look.Z) }
        end
    end
    for _, group in registry.Groups do
        for _, userId in group.Order do
            local viewer = Players:GetPlayerByUserId(userId)
            if viewer then
                local visible = GroupRules.visiblePositions(registry, userId, positions)
                local list = {}
                for memberId, point in visible do
                    table.insert(list, {
                        UserId = memberId,
                        Name = nameOf(memberId),
                        X = point.X,
                        Z = point.Z,
                        Heading = point.Heading,
                    })
                end
                push:FireClient(viewer, "Positions", list)
            end
        end
    end
end

function SocialService.start()
    assert(not started, "SocialService déjà démarré")
    started = true
    registry = GroupRules.new(string.sub(game.JobId ~= "" and game.JobId or "studio", 1, 6))
    local existing = game:GetService("ReplicatedStorage"):FindFirstChild(FOLDER)
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
    folder.Parent = game:GetService("ReplicatedStorage")
    request.OnServerInvoke = function(player: Player, action: any, payload: any): any
        return handle(player, action, payload)
    end
    pcall(setupProximity)
    Players.PlayerAdded:Connect(function(player)
        -- Retour pendant la période de grâce : de nouveau présent (partage toujours désactivé).
        GroupRules.setOnline(registry, player.UserId, true, now())
        local groupId = registry.MemberOf[player.UserId]
        if groupId then
            addToChannel(groupChannel(groupId), player)
            pushGroup(groupId)
        end
        if proximity then
            addToChannel(proximity, player)
        end
    end)
    Players.PlayerRemoving:Connect(function(player)
        GroupRules.setOnline(registry, player.UserId, false, now())
        -- Les invitations qu'il a reçues ou envoyées tombent.
        for id, invite in registry.Invites do
            if invite.To == player.UserId or invite.From == player.UserId then
                registry.Invites[id] = nil
            end
        end
        pushGroup(registry.MemberOf[player.UserId])
        limiters[player] = nil
    end)
    local positionTimer, tickTimer = 0, 0
    RunService.Heartbeat:Connect(function(dt)
        positionTimer += dt
        tickTimer += dt
        if positionTimer >= POSITION_S then
            positionTimer = 0
            sendPositions()
        end
        if tickTimer >= TICK_S then
            tickTimer = 0
            local events = GroupRules.tick(registry, now())
            if #events > 0 then
                local touched: { [string]: boolean } = {}
                for _, event in events do
                    if event.GroupId then
                        touched[event.GroupId] = true
                    end
                end
                apply(events, nil)
                for groupId in touched do
                    pushGroup(groupId)
                end
            end
        end
    end)
end

function SocialService.registry(): GroupRules.Registry
    return registry
end

return table.freeze(SocialService)
