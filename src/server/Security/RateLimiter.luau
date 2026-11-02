--!strict
-- Limiteur de débit PUR à seau de jetons, utilisé pour chaque RemoteEvent.
-- Un client qui inonde le serveur voit simplement ses messages excédentaires
-- ignorés ; aucune sanction automatique n'est appliquée.

local RateLimiter = {}

export type Bucket = {
    Capacity: number,
    RefillPerSecond: number,
    Tokens: number,
    LastTime: number,
}

function RateLimiter.new(capacity: number, refillPerSecond: number, now: number): Bucket
    return {
        Capacity = capacity,
        RefillPerSecond = refillPerSecond,
        Tokens = capacity,
        LastTime = now,
    }
end

-- Consomme un jeton si disponible. Retourne true si le message est accepté.
function RateLimiter.consume(bucket: Bucket, now: number): boolean
    local elapsed = math.max(0, now - bucket.LastTime)
    bucket.LastTime = now
    bucket.Tokens = math.min(bucket.Capacity, bucket.Tokens + elapsed * bucket.RefillPerSecond)
    if bucket.Tokens >= 1 then
        bucket.Tokens -= 1
        return true
    end
    return false
end

return table.freeze(RateLimiter)
