--!strict
--[[
    Choix du véhicule gratuit de départ (§3.1, §10.1, AUD-ONB-01).

    Le cahier des charges prévoit trois modèles de lancement choisis parmi les
    dix-huit du catalogue ; ces modèles ne sont PAS encore définis. Les
    prototypes P-01, P-02 et P-03 sont des véhicules d'essai et ne doivent pas
    être attribués comme voiture définitive : la liste officielle est donc
    VIDE et le choix est refusé (« StarterCatalogUnavailable ») tant que le
    propriétaire n'a pas validé les trois modèles.

    Le processus serveur (StarterSelection) est complet et testé avec une liste
    synthétique injectée par les tests.
]]

local StarterCatalog = {}

-- Identifiants des trois modèles officiels (catalogue de lancement), à fournir.
local CANDIDATES: { string } = {}
StarterCatalog.Candidates = table.freeze(CANDIDATES)
StarterCatalog.RequiredCount = 3

function StarterCatalog.available(): boolean
    return #StarterCatalog.Candidates == StarterCatalog.RequiredCount
end

return table.freeze(StarterCatalog)
