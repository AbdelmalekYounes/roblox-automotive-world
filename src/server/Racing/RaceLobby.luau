--!strict
--[[
    Salons et inscriptions (lot 0.6), PUR : registre des épreuves d'un
    serveur et appartenance des joueurs.

    - Épreuves publiques (officielles, classées) : un salon ouvert par parcours
      et par type, créé à la demande au point d'inscription physique.
    - Salons privés et entraînements : créés par un organisateur (paramètres
      autorisés : tours, participants, modes), rejoints sur invitation par
      leur identifiant ; un salon privé n'est rémunéré que s'il est déclaré
      éligible (faibles récompenses plafonnées, RaceRewards).
    - Un joueur n'appartient qu'à UNE épreuve à la fois (participation
      simultanée à deux courses refusée) ; il en sort quand son résultat est
      appliqué ou par désinscription avant le verrouillage.
]]

local RaceSession = require(script.Parent.RaceSession)

local RaceLobby = {}

export type Lobby = {
    Sessions: { [string]: RaceSession.Session },
    Membership: { [number]: string },
}

function RaceLobby.new(): Lobby
    return { Sessions = {}, Membership = {} }
end

function RaceLobby.add(lobby: Lobby, session: RaceSession.Session)
    lobby.Sessions[session.Id] = session
end

function RaceLobby.get(lobby: Lobby, sessionId: any): RaceSession.Session?
    if type(sessionId) ~= "string" then
        return nil
    end
    return lobby.Sessions[sessionId]
end

function RaceLobby.sessionOf(lobby: Lobby, userId: number): RaceSession.Session?
    local id = lobby.Membership[userId]
    return if id then lobby.Sessions[id] else nil
end

-- Salon public ouvert d'un parcours et d'un type (officielle, classée).
function RaceLobby.openPublic(lobby: Lobby, courseId: string, kind: string): RaceSession.Session?
    for _, session in lobby.Sessions do
        if
            session.State == "Open"
            and session.Built.Id == courseId
            and session.Kind.Id == kind
            and session.OrganizerUserId == nil
            and RaceSession.count(session) < session.MaxParticipants
        then
            return session
        end
    end
    return nil
end

export type Filter = { Discipline: string?, Kind: string?, CourseId: string? }

-- Recherche : épreuves ouvertes (les salons privés ne sont jamais listés).
function RaceLobby.search(lobby: Lobby, filter: Filter): { RaceSession.Session }
    local list: { RaceSession.Session } = {}
    for _, session in lobby.Sessions do
        if session.State ~= "Open" or session.OrganizerUserId ~= nil then
            continue
        end
        if filter.Discipline and session.Discipline.Id ~= filter.Discipline then
            continue
        end
        if filter.Kind and session.Kind.Id ~= filter.Kind then
            continue
        end
        if filter.CourseId and session.Built.Id ~= filter.CourseId then
            continue
        end
        table.insert(list, session)
    end
    table.sort(list, function(a, b)
        return a.CreatedAt < b.CreatedAt
    end)
    return list
end

function RaceLobby.join(
    lobby: Lobby,
    session: RaceSession.Session,
    entry: RaceSession.Entry,
    now: number
): (boolean, string?)
    local current = lobby.Membership[entry.UserId]
    if current ~= nil then
        return false, if current == session.Id then "RaceAlreadyRegistered" else "RaceAlreadyEngaged"
    end
    local ok, err = RaceSession.register(session, entry, now)
    if not ok then
        return false, err
    end
    lobby.Membership[entry.UserId] = session.Id
    return true, nil
end

-- Désinscription avant le verrouillage.
function RaceLobby.leave(lobby: Lobby, userId: number): (boolean, string?)
    local session = RaceLobby.sessionOf(lobby, userId)
    if session == nil then
        return false, "RaceNotRegistered"
    end
    local ok, err = RaceSession.unregister(session, userId)
    if ok then
        lobby.Membership[userId] = nil
    end
    return ok, err
end

-- Sortie définitive (résultat appliqué, épreuve annulée).
function RaceLobby.release(lobby: Lobby, userId: number)
    lobby.Membership[userId] = nil
end

-- Retire les épreuves terminées dont plus personne n'est membre.
function RaceLobby.cleanup(lobby: Lobby, now: number, keepS: number)
    for id, session in lobby.Sessions do
        if
            (session.State == "Finished" or session.State == "Cancelled")
            and now - (session.EndedAt or now) >= keepS
        then
            local members = false
            for _, sessionId in lobby.Membership do
                if sessionId == id then
                    members = true
                end
            end
            if not members then
                lobby.Sessions[id] = nil
            end
        end
    end
end

return table.freeze(RaceLobby)
