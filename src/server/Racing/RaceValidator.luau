--!strict
--[[
    Validation serveur d'un résultat (lot 0.6, AUD-PHYS-01, AUD-COLL-01), PURE.

    Un résultat d'arrivée n'est CONFIRMÉ que si les données serveur suffisent
    à l'établir. Sinon il est « Unconfirmed » (à réconcilier) : ni
    récompensé, ni classé, ni sanctionné. Aucune de ces raisons n'entraîne de
    sanction automatique : une latence, un trou de réplication ou une
    correction de mouvement ne prouvent pas une triche (SCN-14, SCN-15).

    Raisons :
    - InsufficientData : trop peu d'échantillons pour la durée ;
    - DataGap : intervalle sans mesure trop long pendant l'épreuve ;
    - MovementCorrected : le serveur a corrigé un mouvement invraisemblable ;
    - ReplicationFrozen : position figée alors que la voiture roulait
      (anomalie de réplication documentée, QA-A01) ;
    - ImplausibleSpeed : vitesse moyenne entre deux points supérieure à la
      vitesse plausible du modèle.
]]

local Shared = script.Parent.Parent.Parent.Parent.ReplicatedStorage.Shared
local RaceDefinitions = require(Shared.Racing.RaceDefinitions)
local RaceRules = require(script.Parent.RaceRules)

local RaceValidator = {}

RaceValidator.Params = table.freeze({
    MinSamplesPerS = 3, -- échantillonnage visé : 10 Hz
    MaxGapS = 2,
    MaxFrozenS = 1.5,
    SpeedMargin = 1.15,
})

export type Verdict = { Confirmed: boolean, Reasons: { string } }

function RaceValidator.check(progress: RaceRules.Progress, maxPlausibleKmh: number): Verdict
    local p = RaceValidator.Params
    local reasons: { string } = {}
    if progress.Status ~= "Finished" then
        -- Abandon, disqualification, délai : issues décidées par les règles, rien à confirmer.
        return { Confirmed = true, Reasons = reasons }
    end
    local duration = math.max(progress.ElapsedS or 0, 1)
    if progress.Samples < duration * p.MinSamplesPerS then
        table.insert(reasons, "InsufficientData")
    end
    if progress.MaxGapS > p.MaxGapS then
        table.insert(reasons, "DataGap")
    end
    if progress.Corrections > 0 then
        table.insert(reasons, "MovementCorrected")
    end
    if progress.FrozenS > p.MaxFrozenS then
        table.insert(reasons, "ReplicationFrozen")
    end
    if progress.MaxSegmentSpeedMs > maxPlausibleKmh / 3.6 * p.SpeedMargin then
        table.insert(reasons, "ImplausibleSpeed")
    end
    return { Confirmed = #reasons == 0, Reasons = reasons }
end

-- Discipline classée par score (drift) : aucune vitesse moyenne à contrôler.
function RaceValidator.checkFor(
    progress: RaceRules.Progress,
    discipline: RaceDefinitions.Discipline,
    maxPlausibleKmh: number
): Verdict
    if discipline.Ranking == "Score" then
        return RaceValidator.check(progress, math.huge)
    end
    return RaceValidator.check(progress, maxPlausibleKmh)
end

return table.freeze(RaceValidator)
