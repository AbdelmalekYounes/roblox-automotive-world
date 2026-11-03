--!strict
--[[
    Accès aux profils pour les transactions MULTIPROFILS (lot 0.5, AUD-TX-01).

    apply(userId, txId, kind, mutate) applique une mutation idempotente au
    profil d'un joueur, où qu'il soit :
    - joueur présent sur CE serveur : transaction de sa session ;
    - joueur absent : session TEMPORAIRE (verrou pris, mutation, écriture,
      verrou rendu) ;
    - profil verrouillé par un autre serveur : « Deferred » — la transaction
      sera reprise par le serveur qui détient ce joueur (boîte de réception).

    Résultat « Confirmed »/« Duplicate » : appliqué ET durable ; « Pending » :
    appliqué en mémoire, écriture non encore confirmée (le protocole attend) ;
    « Rejected » : refusé par les règles (rien n'a changé) ; « Deferred » /
    « Unavailable » : rien n'a changé, réessayer plus tard.
    Pur : stockage, horloge, jetons et sessions en ligne sont injectés.
]]

local ProfileSession = require(script.Parent.ProfileSession)
local ProfileRepository = require(script.Parent.ProfileRepository)
local TransactionService = require(script.Parent.TransactionService)

local ProfileAccess = {}
ProfileAccess.__index = ProfileAccess

export type Options = {
    Repository: any,
    Environment: string,
    Clock: () -> number,
    Token: () -> string,
    Server: string,
    -- Session ACTIVE d'un joueur présent sur ce serveur (nil sinon).
    Online: (userId: number) -> any?,
    Log: any?,
    OnLoaded: ((any, number) -> boolean)?,
    MinWriteInterval: number?,
}

export type Outcome = {
    Status: "Confirmed" | "Pending" | "Duplicate" | "Rejected" | "Deferred" | "Unavailable",
    Result: any,
    Error: string?,
}

type Fields = { Options: Options }
export type Access = typeof(setmetatable({} :: Fields, ProfileAccess))

function ProfileAccess.new(options: Options): Access
    return setmetatable({ Options = options }, ProfileAccess)
end

function ProfileAccess.apply(
    self: Access,
    userId: number,
    txId: string,
    kind: string,
    mutate: TransactionService.Mutation
): Outcome
    local options = self.Options
    local online = options.Online(userId)
    if online then
        local result = online:commit(txId, kind, mutate)
        return { Status = result.Status, Result = result.Result, Error = result.Error }
    end
    local session = ProfileSession.new({
        Repository = options.Repository,
        Key = ProfileRepository.keyFor(userId),
        UserId = userId,
        Session = options.Token(),
        Server = options.Server,
        Environment = options.Environment,
        Clock = options.Clock,
        Token = options.Token,
        Log = options.Log,
        MinWriteInterval = options.MinWriteInterval,
        OnLoaded = options.OnLoaded,
    })
    local state = session:load()
    if state == "Locked" then
        return { Status = "Deferred", Result = nil, Error = "ProfileLockedElsewhere" }
    end
    if state ~= "Active" then
        if state == "ReadOnly" then
            session:save(true)
        end
        return { Status = "Unavailable", Result = nil, Error = "Profile" .. state }
    end
    local result = session:commit(txId, kind, mutate)
    local released = session:save(true)
    local status: any = result.Status
    if status == "Pending" then
        -- L'écriture de libération emporte la mutation : confirmée si elle a réussi.
        status = if released == "Released" then "Confirmed" else "Unavailable"
    end
    return { Status = status, Result = result.Result, Error = result.Error }
end

return ProfileAccess
