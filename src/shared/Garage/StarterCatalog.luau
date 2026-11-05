--!strict
--[[
    Choix du véhicule gratuit de départ (§3.1, §10.1, AUD-ONB-01).

    Le cahier des charges prévoit trois modèles de lancement choisis parmi les
    dix-huit du catalogue. La liste OFFICIELLE reste VIDE tant que le
    propriétaire n'a pas validé les trois modèles : en test et en production,
    le choix est refusé (« StarterCatalogUnavailable »).

    Lot 0.8 : trois CANDIDATS PROPOSÉS (en attente d'approbation) parmi la gamme
    proposée, pour que le parcours d'arrivée soit complet et essayable en
    DÉVELOPPEMENT seulement ; l'exemplaire attribué y est alors marqué
    « synthétique » (donnée de développement, jamais hors de l'environnement
    Dev). Comparatif : docs/lot-0.8/CATALOGUE_18_VEHICULES.md.
]]

local StarterCatalog = {}

-- Identifiants des trois modèles officiels (catalogue de lancement), à fournir par le propriétaire.
local CANDIDATES: { string } = {}
StarterCatalog.Candidates = table.freeze(CANDIDATES)
StarterCatalog.RequiredCount = 1 -- la citadine (lot BASE-01)

-- Proposition (PendingApproval) : trois caractères de conduite différents,
-- valeurs comparables (16 500 à 19 500 crédits).
-- Lot BASE-01 (décision du propriétaire du 2026-11-05, point P2) : aucun véhicule de départ tant que la
-- citadine (VEH3D-02) n'est pas intégrée ; le choix est refusé dans tous les environnements.
StarterCatalog.Proposed = table.freeze({}) :: { string }
StarterCatalog.ProposalStatus = "PendingApproval"

function StarterCatalog.available(): boolean
    return #StarterCatalog.Candidates == StarterCatalog.RequiredCount
end

--[[
    Candidats utilisables dans un environnement : la liste officielle si elle
    est complète ; sinon, en développement seulement, la proposition (les
    exemplaires sont alors synthétiques). Renvoie (liste, synthétique).
]]
function StarterCatalog.candidates(environment: string): ({ string }, boolean)
    if StarterCatalog.available() then
        return StarterCatalog.Candidates, false
    end
    if environment == "Dev" then
        return StarterCatalog.Proposed, true
    end
    return {}, false
end

return table.freeze(StarterCatalog)
