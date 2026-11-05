--!strict
--[[
    Protocole client ↔ serveur des courses (lot 0.6). Le client DEMANDE (voir
    le catalogue, rejoindre, se déclarer prêt, abandonner…) ; le serveur
    revalide tout (lieu physique, véhicule conduit et possédé, réservation,
    état de l'épreuve) et répond par l'état RÉEL. Aucun résultat, temps,
    score ou classement n'est jamais accepté du client : ils sont mesurés par
    le serveur à partir de ses propres échantillons.

    Messages poussés par le serveur (Push) : « Snapshot » (état de l'épreuve
    du joueur), « Event » (point de contrôle, tour, pénalité, faux départ…),
    « Results » (classement confirmé et récompenses), « Rejoin » (reprise
    proposée après reconnexion), « Open » (ouvrir le panneau).
]]

local RaceProtocol = {}

RaceProtocol.FolderName = "AWRacing"
RaceProtocol.Request = "Request"
RaceProtocol.Push = "Push"

-- Attribut répliqué du dossier : instant serveur du prochain départ (affichage).
RaceProtocol.Actions = table.freeze({
    "Catalog", -- parcours, épreuves ouvertes, classements, rang et saison
    "Join", -- rejoindre une épreuve publique ou un salon (au point d'inscription)
    "CreatePrivate", -- salon privé ou entraînement (paramètres d'organisateur)
    "Leave", -- désinscription avant le verrouillage
    "Ready", -- confirmation de disponibilité
    "Abandon", -- abandon pendant l'épreuve
    "Rejoin", -- reprise après reconnexion (même épreuve)
    "Queue", -- matchmaking classé
    "Unqueue",
    "ConfirmMatch",
    "Leaderboard",
})

-- Opérations qui engagent ou libèrent un exemplaire : identifiant de demande obligatoire.
RaceProtocol.Sensitive = table.freeze({
    Join = true,
    CreatePrivate = true,
    Leave = true,
    Rejoin = true,
})

return table.freeze(RaceProtocol)
