--!strict
--[[
    Matchmaking (lot 0.6), cœur PUR et adaptateurs injectés.

    File d'attente de tickets (un par joueur) :
      Queued ──groupe compatible──▶ Proposed ──tous confirment──▶ Matched
                                        └──refus / délai──▶ (ticket retiré ; les autres reviennent en file)
    - Critères : discipline, type (classée, officielle), mode, disponibilité
      du véhicule (vérifiée avant le ticket), niveau (points de l'échelle) :
      fenêtre de niveau élargie avec l'attente ; région et latence lorsque
      l'adaptateur les fournit (aucune n'est fournie aujourd'hui).
    - Taille : au moins MinGroup, au plus MaxGroup ; un groupe incomplet est
      proposé après MinWaitS d'attente du plus ancien.
    - Expiration contrôlée : ticket retiré après TicketTtlS ; confirmation à
      donner en ConfirmS ; double ticket refusé.

    Adaptateurs :
    - local (repli, place de développement, serveur unique) : seuls les
      tickets de ce serveur ; l'épreuve est créée ICI et les joueurs rejoignent
      physiquement le point de départ ;
    - inter-serveurs (MemoryStore + serveur réservé + téléportation explicite),
      voir RaceService : écrit mais DÉSACTIVÉ tant qu'aucune expérience de
      test isolée n'est déclarée — NON TESTÉ, rien n'affirme qu'il fonctionne.
]]

local MatchmakingService = {}

MatchmakingService.Params = table.freeze({
    MinGroup = 2,
    MaxGroup = 8,
    MinWaitS = 20,
    BaseBand = 150,
    BandPerTenS = 50,
    MaxBand = 800,
    ConfirmS = 20,
    TicketTtlS = 300,
})

export type TicketState = "Queued" | "Proposed" | "Confirmed"

export type Ticket = {
    UserId: number,
    Discipline: string,
    Kind: string,
    Mode: string,
    Rating: number,
    CreatedAt: number,
    State: TicketState,
    MatchId: string?,
    Deadline: number?,
    Region: string?,
}

export type Match = { MatchId: string, Discipline: string, Kind: string, UserIds: { number }, CreatedAt: number }

export type Queue = {
    Tickets: { [number]: Ticket },
    Matches: { [string]: Match },
    Counter: number,
    ServerTag: string,
}

function MatchmakingService.new(serverTag: string): Queue
    return { Tickets = {}, Matches = {}, Counter = 0, ServerTag = serverTag }
end

export type Request = { UserId: number, Discipline: string, Kind: string, Mode: string, Rating: number, Region: string? }

function MatchmakingService.enqueue(queue: Queue, request: Request, now: number): (boolean, string?)
    if queue.Tickets[request.UserId] then
        return false, "AlreadyQueued"
    end
    queue.Tickets[request.UserId] = {
        UserId = request.UserId,
        Discipline = request.Discipline,
        Kind = request.Kind,
        Mode = request.Mode,
        Rating = request.Rating,
        CreatedAt = now,
        State = "Queued",
        MatchId = nil,
        Deadline = nil,
        Region = request.Region,
    }
    return true, nil
end

-- Retrait volontaire (ou départ du joueur) ; le groupe proposé est dissous.
function MatchmakingService.cancel(queue: Queue, userId: number)
    local ticket = queue.Tickets[userId]
    if ticket == nil then
        return
    end
    queue.Tickets[userId] = nil
    if ticket.MatchId then
        MatchmakingService.dissolve(queue, ticket.MatchId :: string)
    end
end

-- Dissolution d'une proposition : les tickets restants reviennent en file.
function MatchmakingService.dissolve(queue: Queue, matchId: string)
    queue.Matches[matchId] = nil
    for _, ticket in queue.Tickets do
        if ticket.MatchId == matchId then
            ticket.State = "Queued"
            ticket.MatchId = nil
            ticket.Deadline = nil
        end
    end
end

function MatchmakingService.band(waitS: number): number
    local p = MatchmakingService.Params
    return math.min(p.MaxBand, p.BaseBand + p.BandPerTenS * math.floor(waitS / 10))
end

--[[
    Confirmation de participation. Renvoie le match complet quand TOUS les
    participants ont confirmé (à créer par l'appelant), sinon nil.
]]
function MatchmakingService.confirm(queue: Queue, userId: number, matchId: string, now: number): (Match?, string?)
    local ticket = queue.Tickets[userId]
    if ticket == nil or ticket.MatchId ~= matchId or ticket.State == "Queued" then
        return nil, "MatchNotProposed"
    end
    if now > (ticket.Deadline or 0) then
        return nil, "MatchExpired"
    end
    ticket.State = "Confirmed"
    local match = queue.Matches[matchId]
    if match == nil then
        return nil, "MatchNotProposed"
    end
    for _, id in match.UserIds do
        local other = queue.Tickets[id]
        if other == nil or other.State ~= "Confirmed" then
            return nil, nil
        end
    end
    -- Match conclu : les tickets sortent de la file.
    for _, id in match.UserIds do
        queue.Tickets[id] = nil
    end
    queue.Matches[matchId] = nil
    return match, nil
end

--[[
    Avance la file : expirations, puis nouvelles propositions. Renvoie
    (propositions, joueurs retirés).
]]
function MatchmakingService.tick(queue: Queue, now: number): ({ Match }, { number })
    local p = MatchmakingService.Params
    local removed: { number } = {}
    -- Propositions échues : les non-confirmés sont retirés, les autres reviennent en file.
    for matchId, match in queue.Matches do
        local expired = false
        for _, id in match.UserIds do
            local ticket = queue.Tickets[id]
            if ticket and ticket.State == "Proposed" and now > (ticket.Deadline or 0) then
                expired = true
            end
        end
        if expired then
            for _, id in match.UserIds do
                local ticket = queue.Tickets[id]
                if ticket and ticket.State == "Proposed" then
                    queue.Tickets[id] = nil
                    table.insert(removed, id)
                end
            end
            MatchmakingService.dissolve(queue, matchId)
        end
    end
    -- Tickets abandonnés (trop anciens).
    for id, ticket in queue.Tickets do
        if ticket.State == "Queued" and now - ticket.CreatedAt > p.TicketTtlS then
            queue.Tickets[id] = nil
            table.insert(removed, id)
        end
    end
    -- Groupes : par discipline, type et mode ; du plus ancien au plus récent.
    local queued: { Ticket } = {}
    for _, ticket in queue.Tickets do
        if ticket.State == "Queued" then
            table.insert(queued, ticket)
        end
    end
    table.sort(queued, function(a, b)
        if a.CreatedAt ~= b.CreatedAt then
            return a.CreatedAt < b.CreatedAt
        end
        return a.UserId < b.UserId
    end)
    local taken: { [number]: boolean } = {}
    local proposals: { Match } = {}
    for _, anchor in queued do
        if taken[anchor.UserId] then
            continue
        end
        local band = MatchmakingService.band(now - anchor.CreatedAt)
        local group = { anchor }
        for _, other in queued do
            if #group >= p.MaxGroup then
                break
            end
            if
                other ~= anchor
                and not taken[other.UserId]
                and other.Discipline == anchor.Discipline
                and other.Kind == anchor.Kind
                and other.Mode == anchor.Mode
                and (other.Region == nil or anchor.Region == nil or other.Region == anchor.Region)
                and math.abs(other.Rating - anchor.Rating)
                    <= math.max(band, MatchmakingService.band(now - other.CreatedAt))
            then
                table.insert(group, other)
            end
        end
        local waited = now - anchor.CreatedAt
        if #group >= p.MinGroup and (#group >= p.MaxGroup or waited >= p.MinWaitS) then
            queue.Counter += 1
            local matchId = string.format("M-%s-%d", queue.ServerTag, queue.Counter)
            local ids = {}
            for _, ticket in group do
                taken[ticket.UserId] = true
                ticket.State = "Proposed"
                ticket.MatchId = matchId
                ticket.Deadline = now + p.ConfirmS
                table.insert(ids, ticket.UserId)
            end
            local match = {
                MatchId = matchId,
                Discipline = anchor.Discipline,
                Kind = anchor.Kind,
                UserIds = ids,
                CreatedAt = now,
            }
            queue.Matches[matchId] = match
            table.insert(proposals, match)
        end
    end
    return proposals, removed
end

return table.freeze(MatchmakingService)
