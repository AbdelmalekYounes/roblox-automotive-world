--!strict
--[[
    Exclusivité d'écriture des profils (AUD-LOCK-01, §8.2), en fonctions de
    transformation PURES destinées à UpdateAsync (ou à l'adaptateur mémoire).

    Enveloppe stockée sous la clé du joueur :
        { Format = 1, Meta = { Generation, Lock?, LastWriteAt, LastToken }, Data }

    - Generation : entier incrémenté à CHAQUE écriture ; une session n'écrit
      que si la génération stockée est celle qu'elle a lue (pas d'écriture
      obsolète, pas d'ancien serveur qui écrase un état plus récent).
    - Lock : session propriétaire et échéance. Un verrou d'une autre session
      non expiré interdit toute écriture ; un verrou EXPIRÉ (serveur disparu
      sans libérer) peut être repris, ce qui est journalisé.
    - LastToken : jeton unique de la dernière écriture, pour réconcilier une
      réponse incertaine (écriture peut-être appliquée) sans la rejouer à
      l'aveugle (§8.3).

    Renvoyer nil depuis une transformation annule l'écriture (UpdateAsync).
]]

local ProfileSessionLock = {}

ProfileSessionLock.Format = 1

export type Lock = {
    Session: string,
    Server: string, -- identifiant du serveur (JobId), pour le diagnostic
    AcquiredAt: number,
    ExpiresAt: number,
}

export type Meta = {
    Generation: number,
    Lock: Lock?,
    LastWriteAt: number,
    LastToken: string?,
    Recovered: number?, -- nombre de reprises de verrous expirés
}

export type Envelope = { Format: number, Meta: Meta, Data: any }

export type Outcome = {
    Status: "Acquired" | "Recovered" | "Locked" | "Saved" | "LockLost" | "Stale" | "Released",
    Holder: Lock?,
}

local function copyMeta(meta: Meta): Meta
    return {
        Generation = meta.Generation,
        Lock = meta.Lock,
        LastWriteAt = meta.LastWriteAt,
        LastToken = meta.LastToken,
        Recovered = meta.Recovered,
    }
end

--[[
    Prise du verrou. `outcome` reçoit le résultat (la transformation ne peut
    renvoyer qu'une enveloppe ou nil).
]]
function ProfileSessionLock.acquire(
    session: string,
    server: string,
    now: number,
    ttl: number,
    token: string,
    outcome: Outcome
): (Envelope?) -> Envelope?
    return function(old: Envelope?): Envelope?
        local meta: Meta = if old then copyMeta(old.Meta) else { Generation = 0, LastWriteAt = 0 }
        local lock = meta.Lock
        if lock and lock.Session ~= session and lock.ExpiresAt > now then
            outcome.Status = "Locked"
            outcome.Holder = lock
            return nil
        end
        outcome.Status = if lock and lock.Session ~= session then "Recovered" else "Acquired"
        outcome.Holder = lock
        if outcome.Status == "Recovered" then
            meta.Recovered = (meta.Recovered or 0) + 1
        end
        meta.Lock = { Session = session, Server = server, AcquiredAt = now, ExpiresAt = now + ttl }
        meta.Generation += 1
        meta.LastWriteAt = now
        meta.LastToken = token
        return { Format = ProfileSessionLock.Format, Meta = meta, Data = if old then old.Data else nil }
    end
end

--[[
    Écriture des données par la session détentrice. Refusée si le verrou a
    été perdu (repris par une autre session) ou si la génération ne
    correspond pas (écriture obsolète). `release` libère le verrou.
]]
function ProfileSessionLock.save(
    session: string,
    generation: number,
    data: any,
    now: number,
    ttl: number,
    token: string,
    release: boolean,
    outcome: Outcome
): (Envelope?) -> Envelope?
    return function(old: Envelope?): Envelope?
        if old == nil or old.Meta.Lock == nil or (old.Meta.Lock :: Lock).Session ~= session then
            outcome.Status = "LockLost"
            outcome.Holder = if old then old.Meta.Lock else nil
            return nil
        end
        if old.Meta.Generation ~= generation then
            outcome.Status = "Stale"
            outcome.Holder = old.Meta.Lock
            return nil
        end
        local meta = copyMeta(old.Meta)
        local lock = meta.Lock :: Lock
        meta.Generation += 1
        meta.LastWriteAt = now
        meta.LastToken = token
        meta.Lock = if release
            then nil
            else { Session = session, Server = lock.Server, AcquiredAt = lock.AcquiredAt, ExpiresAt = now + ttl }
        outcome.Status = if release then "Released" else "Saved"
        return { Format = ProfileSessionLock.Format, Meta = meta, Data = data }
    end
end

-- Libération sans écrire les données (session en lecture seule).
function ProfileSessionLock.release(
    session: string,
    now: number,
    token: string,
    outcome: Outcome
): (Envelope?) -> Envelope?
    return function(old: Envelope?): Envelope?
        if old == nil or old.Meta.Lock == nil or (old.Meta.Lock :: Lock).Session ~= session then
            outcome.Status = "LockLost"
            return nil
        end
        local meta = copyMeta(old.Meta)
        meta.Lock = nil
        meta.Generation += 1
        meta.LastWriteAt = now
        meta.LastToken = token
        outcome.Status = "Released"
        return { Format = ProfileSessionLock.Format, Meta = meta, Data = old.Data }
    end
end

return table.freeze(ProfileSessionLock)
