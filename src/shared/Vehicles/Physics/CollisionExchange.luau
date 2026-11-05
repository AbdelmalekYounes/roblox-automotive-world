--!strict
-- Échange d'impulsion entre deux véhicules simulés par DEUX clients différents
-- (module pur, unités SI, testé hors Studio).
--
-- Pourquoi : avec la propriété réseau au conducteur (A6), chaque client résout
-- le contact contre une COPIE RÉPLIQUÉE de l'autre véhicule, que sa simulation
-- traite comme un obstacle cinématique. Mesuré dans Studio : le percuteur
-- s'arrête net contre un véhicule qui « ne bouge pas » chez lui, tandis que le
-- client du véhicule percuté ne voit arriver qu'une copie déjà arrêtée ; la
-- quantité de mouvement perdue par le percuteur n'est transmise à personne.
--
-- Principe (AUD-COLL-01) : le serveur confirme le contact à partir de SES
-- observations (positions répliquées, jamais une valeur envoyée par un client),
-- puis demande au propriétaire du véhicule percuté d'appliquer le COMPLÉMENT
-- d'impulsion qu'il n'a pas reçu dans sa propre simulation.
-- - Conservation : le percuté reçoit au plus la quantité de mouvement que le
--   percuteur a réellement perdue (mS·perte = mT·Δv).
-- - Borne physique : jamais plus que le choc de carrosseries attendu à la vitesse
--   de rapprochement observée ((1 + e)·mS/(mS + mT)·v, restitution e = 0,3).
--   Mesuré dans Studio : sans cette borne, le percuteur étant arrêté net chez
--   lui, le percuté recevait toute sa vitesse (choc « élastique ») et glissait
--   2 à 3 fois plus loin qu'un véhicule garé percuté de la même façon.
-- - Pas de double comptage : seul le complément non encore reçu est appliqué ;
--   rien n'est jamais retiré (choc frontal : chacun a déjà rebondi chez lui).

local CollisionExchange = {}

export type Sample = {
    Time: number, -- s
    X: number, -- m (plan horizontal)
    Z: number,
}

export type Params = {
    WindowS: number, -- durée d'observation avant/pendant le contact
    BaselineS: number, -- écart minimal entre deux positions pour une vitesse
    MinLossMs: number, -- décélération minimale du percuteur pour confirmer le contact
    MinClosingMs: number, -- vitesse de rapprochement minimale
    Restitution: number, -- coefficient de restitution carrosserie/carrosserie (0 = mou, 1 = élastique)
}

export type Assessment = {
    LossMs: number, -- vitesse perdue par le percuteur selon la normale
    ClosingMs: number, -- vitesse de rapprochement maximale observée
    TargetDeltaVMs: number, -- variation de vitesse due au véhicule percuté
}

CollisionExchange.DefaultParams = table.freeze({
    WindowS = 0.6,
    BaselineS = 0.1,
    MinLossMs = 1.0,
    MinClosingMs = 1.0,
    -- Valeur prudente commune au lot 0.1 ; à porter dans les définitions de
    -- véhicules avec les dégâts (lot 0.2).
    Restitution = 0.3,
}) :: Params

-- Vitesses (projetées sur la normale nx, nz) calculées par différences de
-- positions sur au moins `baseline` secondes, dans la fenêtre [now - window ; now].
-- Renvoie une liste chronologique de { Time, V }.
function CollisionExchange.normalSpeeds(
    samples: { Sample },
    nx: number,
    nz: number,
    now: number,
    params: Params
): { { Time: number, V: number } }
    local result = {}
    local first = 1
    for i = 1, #samples do
        local current = samples[i]
        if now - current.Time > params.WindowS + params.BaselineS then
            first = i + 1
            continue
        end
        -- Échantillon de référence le plus récent au moins `baseline` plus tôt.
        local reference: Sample? = nil
        for j = i - 1, first, -1 do
            if current.Time - samples[j].Time >= params.BaselineS then
                reference = samples[j]
                break
            end
        end
        if reference and now - current.Time <= params.WindowS then
            local dt = current.Time - reference.Time
            local v = ((current.X - reference.X) * nx + (current.Z - reference.Z) * nz) / dt
            table.insert(result, { Time = current.Time, V = v })
        end
    end
    return result
end

-- Évalue un contact supposé entre un percuteur et un véhicule percuté (normale
-- unitaire nx, nz orientée du percuteur vers le percuté). Renvoie nil si les
-- observations ne montrent pas un contact réel (pas de rapprochement, ou pas
-- de décélération du percuteur).
function CollisionExchange.assess(
    strikerSamples: { Sample },
    strikerMassKg: number,
    struckSamples: { Sample },
    struckMassKg: number,
    nx: number,
    nz: number,
    now: number,
    params: Params?
): Assessment?
    local p = params or CollisionExchange.DefaultParams
    local striker = CollisionExchange.normalSpeeds(strikerSamples, nx, nz, now, p)
    local struck = CollisionExchange.normalSpeeds(struckSamples, nx, nz, now, p)
    if #striker < 2 or #struck < 1 then
        return nil
    end
    local peak = -math.huge
    for _, s in striker do
        peak = math.max(peak, s.V)
    end
    -- Le percuteur doit s'être réellement approché : un véhicule poussé (qui
    -- s'éloigne) n'est jamais pris pour un percuteur.
    if peak < p.MinClosingMs then
        return nil
    end
    local loss = peak - striker[#striker].V
    -- Vitesse de rapprochement : vitesse max du percuteur moins la vitesse du
    -- percuté la plus proche dans le temps.
    local closing = -math.huge
    for _, s in striker do
        local nearest = struck[1]
        for _, t in struck do
            if math.abs(t.Time - s.Time) < math.abs(nearest.Time - s.Time) then
                nearest = t
            end
        end
        closing = math.max(closing, s.V - nearest.V)
    end
    if loss < p.MinLossMs or closing < p.MinClosingMs then
        return nil
    end
    local conserved = strikerMassKg / struckMassKg * loss
    local bound = (1 + p.Restitution) * strikerMassKg / (strikerMassKg + struckMassKg) * closing
    return {
        LossMs = loss,
        ClosingMs = closing,
        TargetDeltaVMs = math.min(conserved, bound),
    }
end

-- Variation de vitesse DÉJÀ reçue selon la normale, d'après l'historique
-- chronologique des vitesses (projetées) du véhicule percuté : plus forte
-- hausse observée (un minimum puis un maximum ultérieur). Une poussée faible,
-- déjà freinée par les pneus à l'arrivée du message, est donc bien comptée.
-- Estimation prudente : elle ne peut que réduire le complément.
function CollisionExchange.alreadyReceived(normalSpeedsHistory: { number }, current: number): number
    local lowest, rise = math.huge, 0
    for _, v in normalSpeedsHistory do
        lowest = math.min(lowest, v)
        rise = math.max(rise, v - lowest)
    end
    lowest = math.min(lowest, current)
    return math.max(rise, current - lowest)
end

-- Borne physique de la vitesse (m/s) d'un véhicule simulé par le serveur : un
-- choc ne peut pas donner au véhicule percuté plus de 2 fois la vitesse du
-- percuteur (choc élastique, quelles que soient les masses). Sert à neutraliser
-- les éjections numériques mesurées dans Studio (véhicule garé projeté à 47 et
-- 59 m/s après un choc à 5,4 m/s) quand la copie répliquée d'un véhicule piloté
-- pénètre un véhicule garé. Mesuré aussi : une borne qui laissait croître la
-- vitesse d'un pas à l'autre (50 m/s²) était contournée par une poussée
-- numérique soutenue ; au-delà de la borne, la vitesse ne peut donc plus croître.
-- - horizontal et montée : jamais au-delà de max(borne de choc, valeur précédente
--   déjà admise) ;
-- - chute : libre (gravité).
-- Entrées et sorties en m/s ; renvoie la vitesse bornée et vrai si elle a été réduite.
function CollisionExchange.limitServerVelocity(
    vx: number,
    vy: number,
    vz: number,
    previousHorizontalMs: number,
    nearbyMaxSpeedMs: number
): (number, number, number, boolean)
    local bound = 2 * nearbyMaxSpeedMs + 3
    local horizontalLimit = math.max(bound, previousHorizontalMs)
    local horizontal = math.sqrt(vx * vx + vz * vz)
    local limited = false
    if horizontal > horizontalLimit then
        local scale = horizontalLimit / horizontal
        vx *= scale
        vz *= scale
        limited = true
    end
    if vy > bound then
        vy = bound
        limited = true
    end
    return vx, vy, vz, limited
end

-- Complément à appliquer : jamais négatif, jamais plus que la cible.
function CollisionExchange.complement(targetDeltaV: number, alreadyDeltaV: number): number
    return math.clamp(targetDeltaV - alreadyDeltaV, 0, math.max(targetDeltaV, 0))
end

return table.freeze(CollisionExchange)
