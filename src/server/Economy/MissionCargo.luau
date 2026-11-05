--!strict
--[[
    Chargement visible des missions (lot 0.9), règle PURE : d'après le métier et
    l'étape en cours, ce que transporte le véhicule — colis (livraison), passager
    (taxi) ou pièce (pièces spéciales). Le lot 0.5 n'affichait qu'un repère
    d'étape ; la représentation est purement visuelle (aucun effet sur la
    physique, la mission ou la rémunération).

    - Livraison : étape 1 = récupérer les colis ; ensuite, un colis par livraison
      restante (le colis de l'étape en cours inclus).
    - Taxi et pièces spéciales : étape 1 = prise en charge, étape 2 = dépôt ; le
      chargement est présent pendant l'étape 2.
]]

local MissionCargo = {}

export type Load = { Kind: "Parcel" | "Passenger" | "Part", Count: number }

function MissionCargo.load(job: string, stepCount: number, stepIndex: number): Load?
    if stepIndex < 2 or stepIndex > stepCount then
        return nil
    end
    if job == "Delivery" then
        return { Kind = "Parcel", Count = stepCount - stepIndex + 1 }
    elseif job == "Taxi" and stepIndex == 2 then
        return { Kind = "Passenger", Count = 1 }
    elseif job == "SpecialParts" and stepIndex == 2 then
        return { Kind = "Part", Count = 1 }
    end
    return nil
end

-- Clé de comparaison (rien n'est reconstruit tant que le chargement ne change pas).
function MissionCargo.key(load: Load?): string
    return if load then load.Kind .. ":" .. load.Count else ""
end

return table.freeze(MissionCargo)
