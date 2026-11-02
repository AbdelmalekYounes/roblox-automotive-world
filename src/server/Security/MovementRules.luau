--!strict
-- Règles PURES de plausibilité des mouvements d'un véhicule piloté par un client
-- (AUD-PHYS-01). Le serveur compare deux échantillons successifs de position
-- et de vitesse, avec une tolérance large pour ne pas punir la latence :
-- - « Ok »         : mouvement plausible ;
-- - « Suspicious » : au-delà de la marge souple → journalisé, aucune action ;
-- - « Impossible » : au-delà de la marge dure → correction de position,
--                    sans sanction automatique (les faux positifs restent possibles).

local MovementRules = {}

export type Sample = {
    Time: number, -- s
    X: number, -- m
    Y: number,
    Z: number,
    SpeedMs: number,
}

export type Verdict = "Ok" | "Suspicious" | "Impossible"

export type Tuning = {
    SoftFactor: number,
    HardFactor: number,
    TeleportSlackM: number,
}

MovementRules.DefaultTuning = table.freeze({
    SoftFactor = 1.25,
    HardFactor = 2.0,
    TeleportSlackM = 6,
}) :: Tuning

local function isFinite(value: number): boolean
    return value == value and value ~= math.huge and value ~= -math.huge
end

function MovementRules.isSampleFinite(sample: Sample): boolean
    return isFinite(sample.X) and isFinite(sample.Y) and isFinite(sample.Z) and isFinite(sample.SpeedMs)
end

-- Évalue l'échantillon courant par rapport au précédent.
-- Retourne le verdict et un code de raison (nil si « Ok »).
function MovementRules.evaluate(
    previous: Sample,
    current: Sample,
    maxPlausibleSpeedMs: number,
    tuning: Tuning?
): (Verdict, string?)
    local t = tuning or MovementRules.DefaultTuning
    if not MovementRules.isSampleFinite(current) then
        return "Impossible", "NonFinite"
    end

    local hardSpeed = maxPlausibleSpeedMs * t.HardFactor
    if current.SpeedMs > hardSpeed then
        return "Impossible", "Overspeed"
    end

    local dt = current.Time - previous.Time
    local distance = 0
    if dt > 0 and MovementRules.isSampleFinite(previous) then
        local dx = current.X - previous.X
        local dy = current.Y - previous.Y
        local dz = current.Z - previous.Z
        distance = math.sqrt(dx * dx + dy * dy + dz * dz)
        if distance > hardSpeed * dt + t.TeleportSlackM then
            return "Impossible", "Teleport"
        end
    end

    local softSpeed = maxPlausibleSpeedMs * t.SoftFactor
    if current.SpeedMs > softSpeed then
        return "Suspicious", "FastSpeed"
    end
    if dt > 0 and distance > softSpeed * dt + t.TeleportSlackM * 0.5 then
        return "Suspicious", "FastDisplacement"
    end
    return "Ok", nil
end

return table.freeze(MovementRules)
