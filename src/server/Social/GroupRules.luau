--!strict
--[[
    Groupes temporaires de joueurs (lot 0.7, §7.3, AUD-SOC-01, AUD-PRIV-01), PUR.

    - Au plus 8 membres ; un joueur n'appartient qu'à un groupe.
    - Le responsable invite, exclut, confie la direction, dissout. Une
      invitation expire (2 min), peut être retirée, acceptée ou refusée.
    - Le groupe est DISTINCT des invitations de propriété, des droits de
      conduite, des prêts et des droits économiques : en être membre ne donne
      AUCUN droit (vérifiés séparément par le serveur à chaque opération).
    - Déconnexion : le membre reste listé « absent » 5 min puis sort ; un
      responsable absent plus de 60 s cède la direction au membre présent le
      plus ancien ; groupe vide = dissous.
    - Partage de position : DÉSACTIVÉ par défaut, activé explicitement pour
      le groupe ACTUEL, pour 2 h au plus ; il s'arrête immédiatement à la
      désactivation, à la sortie du groupe, à la dissolution, à la
      déconnexion et à l'échéance.
    - Vue sociale : seulement identité d'affichage, rôle, présence et partage
      (jamais solde, collection, propriétés, transactions ni profil).
]]

local GroupRules = {}

GroupRules.MaxMembers = 8
GroupRules.InviteTtlS = 120
GroupRules.MaxPendingInvites = 7
GroupRules.LeaderGraceS = 60
GroupRules.MemberGraceS = 300
GroupRules.SharingMaxS = 2 * 3600

export type Member = {
    UserId: number,
    JoinedAt: number,
    Online: boolean,
    OfflineSince: number?,
    Sharing: boolean,
    SharingUntil: number?,
}

export type Group = {
    Id: string,
    Leader: number,
    Members: { [number]: Member },
    Order: { number }, -- ordre d'arrivée
    CreatedAt: number,
}

export type Invite = { Id: string, GroupId: string, From: number, To: number, ExpiresAt: number }

export type Registry = {
    Groups: { [string]: Group },
    MemberOf: { [number]: string },
    Invites: { [string]: Invite },
    Counter: number,
    Tag: string,
}

-- Événements à notifier : { Kind, UserId?, Target?, GroupId }.
export type Event = { Kind: string, GroupId: string?, UserId: number?, Target: number? }

function GroupRules.new(tag: string): Registry
    return { Groups = {}, MemberOf = {}, Invites = {}, Counter = 0, Tag = tag }
end

local function nextId(registry: Registry, prefix: string): string
    registry.Counter += 1
    return string.format("%s-%s-%d", prefix, registry.Tag, registry.Counter)
end

function GroupRules.groupOf(registry: Registry, userId: number): Group?
    local id = registry.MemberOf[userId]
    return if id then registry.Groups[id] else nil
end

function GroupRules.count(group: Group): number
    return #group.Order
end

function GroupRules.create(registry: Registry, leaderId: number, now: number): (Group?, string?)
    if registry.MemberOf[leaderId] then
        return nil, "GroupAlready"
    end
    local group: Group = {
        Id = nextId(registry, "G"),
        Leader = leaderId,
        Members = {},
        Order = {},
        CreatedAt = now,
    }
    group.Members[leaderId] = { UserId = leaderId, JoinedAt = now, Online = true, OfflineSince = nil, Sharing = false }
    table.insert(group.Order, leaderId)
    registry.Groups[group.Id] = group
    registry.MemberOf[leaderId] = group.Id
    return group, nil
end

local function pendingFor(registry: Registry, groupId: string): number
    local count = 0
    for _, invite in registry.Invites do
        if invite.GroupId == groupId then
            count += 1
        end
    end
    return count
end

--[[
    Invitation par le responsable (le groupe est créé s'il n'existe pas).
    `acceptsInvites` : préférence du destinataire.
]]
function GroupRules.invite(
    registry: Registry,
    fromId: number,
    toId: number,
    now: number,
    acceptsInvites: boolean?
): (Invite?, string?)
    if fromId == toId then
        return nil, "GroupSelf"
    end
    -- Invitations échues retirées d'abord : elles ne bloquent jamais une nouvelle invitation.
    for id, invite in registry.Invites do
        if now > invite.ExpiresAt then
            registry.Invites[id] = nil
        end
    end
    local group = GroupRules.groupOf(registry, fromId)
    if group == nil then
        local created, err = GroupRules.create(registry, fromId, now)
        if created == nil then
            return nil, err
        end
        group = created
    end
    local g = group :: Group
    if g.Leader ~= fromId then
        return nil, "GroupNotLeader"
    end
    if registry.MemberOf[toId] then
        return nil, "GroupTargetBusy"
    end
    if acceptsInvites == false then
        return nil, "GroupTargetBusy"
    end
    for _, invite in registry.Invites do
        if invite.GroupId == g.Id and invite.To == toId then
            return nil, "GroupInvitePending"
        end
    end
    if GroupRules.count(g) + pendingFor(registry, g.Id) >= GroupRules.MaxMembers then
        return nil, if GroupRules.count(g) >= GroupRules.MaxMembers then "GroupFull" else "GroupInviteLimit"
    end
    if pendingFor(registry, g.Id) >= GroupRules.MaxPendingInvites then
        return nil, "GroupInviteLimit"
    end
    local invite: Invite = {
        Id = nextId(registry, "I"),
        GroupId = g.Id,
        From = fromId,
        To = toId,
        ExpiresAt = now + GroupRules.InviteTtlS,
    }
    registry.Invites[invite.Id] = invite
    return invite, nil
end

function GroupRules.accept(registry: Registry, userId: number, inviteId: any, now: number): (Group?, string?)
    local invite = if type(inviteId) == "string" then registry.Invites[inviteId] else nil
    if invite == nil or invite.To ~= userId then
        return nil, "GroupInviteExpired"
    end
    if now > invite.ExpiresAt then
        registry.Invites[invite.Id] = nil
        return nil, "GroupInviteExpired"
    end
    registry.Invites[invite.Id] = nil
    if registry.MemberOf[userId] then
        return nil, "GroupAlready"
    end
    local group = registry.Groups[invite.GroupId]
    if group == nil then
        return nil, "GroupInviteExpired"
    end
    if GroupRules.count(group) >= GroupRules.MaxMembers then
        return nil, "GroupFull"
    end
    group.Members[userId] = { UserId = userId, JoinedAt = now, Online = true, OfflineSince = nil, Sharing = false }
    table.insert(group.Order, userId)
    registry.MemberOf[userId] = group.Id
    -- Les autres invitations reçues deviennent sans objet.
    for id, other in registry.Invites do
        if other.To == userId then
            registry.Invites[id] = nil
        end
    end
    return group, nil
end

function GroupRules.decline(registry: Registry, userId: number, inviteId: any): boolean
    local invite = if type(inviteId) == "string" then registry.Invites[inviteId] else nil
    if invite == nil or invite.To ~= userId then
        return false
    end
    registry.Invites[invite.Id] = nil
    return true
end

-- Retrait d'une invitation par le responsable (révocation).
function GroupRules.revokeInvite(registry: Registry, leaderId: number, inviteId: any): boolean
    local invite = if type(inviteId) == "string" then registry.Invites[inviteId] else nil
    local group = if invite then registry.Groups[invite.GroupId] else nil
    if invite == nil or group == nil or group.Leader ~= leaderId then
        return false
    end
    registry.Invites[invite.Id] = nil
    return true
end

local function dissolve(registry: Registry, group: Group, events: { Event })
    for _, userId in group.Order do
        registry.MemberOf[userId] = nil
        table.insert(events, { Kind = "Dissolved", GroupId = group.Id, UserId = userId })
    end
    if #group.Order == 0 then
        -- Groupe vidé par le départ du dernier membre : canal fermé, rien à notifier.
        table.insert(events, { Kind = "Dissolved", GroupId = group.Id })
    end
    for id, invite in registry.Invites do
        if invite.GroupId == group.Id then
            registry.Invites[id] = nil
        end
    end
    registry.Groups[group.Id] = nil
end

-- Nouveau responsable : le membre présent le plus ancien (sinon le plus ancien).
local function electLeader(group: Group): number?
    for _, userId in group.Order do
        if group.Members[userId].Online then
            return userId
        end
    end
    return group.Order[1]
end

local function remove(registry: Registry, group: Group, userId: number, kind: string, events: { Event })
    group.Members[userId] = nil
    local index = table.find(group.Order, userId)
    if index then
        table.remove(group.Order, index)
    end
    registry.MemberOf[userId] = nil
    table.insert(events, { Kind = kind, GroupId = group.Id, UserId = userId })
    if #group.Order == 0 then
        dissolve(registry, group, events)
        return
    end
    if group.Leader == userId then
        group.Leader = electLeader(group) :: number
        table.insert(events, { Kind = "NewLeader", GroupId = group.Id, UserId = group.Leader })
    end
end

function GroupRules.leave(registry: Registry, userId: number): ({ Event }, string?)
    local events: { Event } = {}
    local group = GroupRules.groupOf(registry, userId)
    if group == nil then
        return events, "GroupNone"
    end
    remove(registry, group, userId, "Left", events)
    return events, nil
end

function GroupRules.kick(registry: Registry, leaderId: number, targetId: number): ({ Event }, string?)
    local events: { Event } = {}
    local group = GroupRules.groupOf(registry, leaderId)
    if group == nil then
        return events, "GroupNone"
    end
    if group.Leader ~= leaderId then
        return events, "GroupNotLeader"
    end
    if targetId == leaderId then
        return events, "GroupSelf"
    end
    if group.Members[targetId] == nil then
        return events, "GroupNotMember"
    end
    remove(registry, group, targetId, "Kicked", events)
    return events, nil
end

function GroupRules.promote(registry: Registry, leaderId: number, targetId: number): ({ Event }, string?)
    local events: { Event } = {}
    local group = GroupRules.groupOf(registry, leaderId)
    if group == nil then
        return events, "GroupNone"
    end
    if group.Leader ~= leaderId then
        return events, "GroupNotLeader"
    end
    if group.Members[targetId] == nil or targetId == leaderId then
        return events, "GroupNotMember"
    end
    group.Leader = targetId
    table.insert(events, { Kind = "NewLeader", GroupId = group.Id, UserId = targetId })
    return events, nil
end

function GroupRules.dissolve(registry: Registry, leaderId: number): ({ Event }, string?)
    local events: { Event } = {}
    local group = GroupRules.groupOf(registry, leaderId)
    if group == nil then
        return events, "GroupNone"
    end
    if group.Leader ~= leaderId then
        return events, "GroupNotLeader"
    end
    dissolve(registry, group, events)
    return events, nil
end

-- Partage de position : activation explicite pour le groupe actuel, échéance bornée.
function GroupRules.setSharing(registry: Registry, userId: number, on: boolean, now: number): (boolean, string?)
    local group = GroupRules.groupOf(registry, userId)
    if group == nil then
        return false, "GroupNone"
    end
    local member = group.Members[userId]
    member.Sharing = on
    member.SharingUntil = if on then now + GroupRules.SharingMaxS else nil
    return true, nil
end

-- Présence (déconnexion : le partage s'arrête aussitôt).
function GroupRules.setOnline(registry: Registry, userId: number, online: boolean, now: number)
    local group = GroupRules.groupOf(registry, userId)
    if group == nil then
        return
    end
    local member = group.Members[userId]
    member.Online = online
    member.OfflineSince = if online then nil else now
    if not online then
        member.Sharing = false
        member.SharingUntil = nil
    end
end

-- Échéances : invitations, partages, absences prolongées, direction vacante.
function GroupRules.tick(registry: Registry, now: number): { Event }
    local events: { Event } = {}
    for id, invite in registry.Invites do
        if now > invite.ExpiresAt then
            registry.Invites[id] = nil
        end
    end
    for _, group in table.clone(registry.Groups) do
        for _, userId in table.clone(group.Order) do
            local member = group.Members[userId]
            if member == nil then
                continue
            end
            if member.Sharing and member.SharingUntil and now >= member.SharingUntil then
                member.Sharing = false
                member.SharingUntil = nil
                table.insert(events, { Kind = "SharingEnded", GroupId = group.Id, UserId = userId })
            end
            if not member.Online and member.OfflineSince and now - member.OfflineSince >= GroupRules.MemberGraceS then
                remove(registry, group, userId, "TimedOut", events)
            end
        end
        local current = registry.Groups[group.Id]
        if current then
            local leader = current.Members[current.Leader]
            if
                leader
                and not leader.Online
                and leader.OfflineSince
                and now - leader.OfflineSince >= GroupRules.LeaderGraceS
            then
                local elected = electLeader(current)
                if elected and elected ~= current.Leader and current.Members[elected].Online then
                    current.Leader = elected
                    table.insert(events, { Kind = "NewLeader", GroupId = current.Id, UserId = elected })
                end
            end
        end
    end
    return events
end

--[[
    Positions visibles par `viewerId` : membres de SON groupe, présents, qui
    partagent ; jamais lui-même ; rien hors groupe. `positions` : { [UserId] = point }.
]]
function GroupRules.visiblePositions(
    registry: Registry,
    viewerId: number,
    positions: { [number]: any }
): { [number]: any }
    local out: { [number]: any } = {}
    local group = GroupRules.groupOf(registry, viewerId)
    if group == nil then
        return out
    end
    for userId, member in group.Members do
        if userId ~= viewerId and member.Online and member.Sharing and positions[userId] then
            local p = positions[userId]
            out[userId] = { X = p.X, Z = p.Z, Heading = p.Heading }
        end
    end
    return out
end

-- Champs autorisés d'une vue sociale (liste blanche, AUD-PRIV-01).
GroupRules.MemberFields = table.freeze({ "UserId", "Name", "Leader", "Online", "Sharing", "Friend" })

--[[
    Vue sociale filtrée pour un destinataire. `directory(userId)` fournit des
    informations de joueur ; SEULS les champs de la liste blanche sont copiés.
]]
function GroupRules.view(registry: Registry, viewerId: number, directory: (number) -> any, now: number): any
    local function member(userId: number, data: any): any
        local info = directory(userId) or {}
        return {
            UserId = userId,
            Name = if type(info.Name) == "string" then info.Name else tostring(userId),
            Leader = data.Leader == true,
            Online = data.Online == true,
            Sharing = data.Sharing == true,
            Friend = info.Friend == true,
        }
    end
    local view: any = { Group = nil, Incoming = {}, Outgoing = {} }
    local group = GroupRules.groupOf(registry, viewerId)
    if group then
        local members = {}
        for _, userId in group.Order do
            local m = group.Members[userId]
            table.insert(
                members,
                member(userId, { Leader = userId == group.Leader, Online = m.Online, Sharing = m.Sharing })
            )
        end
        local own = group.Members[viewerId]
        view.Group = {
            Id = group.Id,
            Leader = group.Leader,
            IsLeader = group.Leader == viewerId,
            Members = members,
            Sharing = own.Sharing,
            SharingLeftS = if own.SharingUntil then math.max(0, own.SharingUntil - now) else nil,
        }
        if group.Leader == viewerId then
            for _, invite in registry.Invites do
                if invite.GroupId == group.Id then
                    table.insert(view.Outgoing, { Id = invite.Id, To = member(invite.To, {}) })
                end
            end
        end
    end
    for _, invite in registry.Invites do
        if invite.To == viewerId and now <= invite.ExpiresAt then
            table.insert(view.Incoming, { Id = invite.Id, From = member(invite.From, {}) })
        end
    end
    return view
end

return table.freeze(GroupRules)
