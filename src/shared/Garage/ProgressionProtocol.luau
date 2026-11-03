--!strict
--[[
    Protocole client ↔ serveur de la progression (lot 0.4).

    - Une RemoteFunction « Request » : le client DEMANDE une action ; le
      serveur revalide tout (identité, lieu, droits, état du profil) et répond
      par un statut. « Confirmed » seulement après écriture durable confirmée ;
      « Pending » : appliqué, écriture en attente (l'interface l'indique) ;
      aucune réussite n'est affichée avant la réponse du serveur.
    - Un RemoteEvent « Push » : le serveur informe (instantané, confirmation
      tardive, proposition d'entrée, contexte de lieu).
    Les textes affichés sont résolus côté client à partir de clés.
]]

local ProgressionProtocol = {}

ProgressionProtocol.FolderName = "AWProgression"
ProgressionProtocol.Request = "Request"
ProgressionProtocol.Push = "Push"

-- Actions acceptées par le serveur ; toute autre est refusée.
ProgressionProtocol.Actions = table.freeze({
    "Snapshot",
    "CollectionPage",
    "ChooseStarter",
    "Display",
    "Store",
    "TakeOut",
    "Return",
    "SetTuning",
    "SetCosmetics",
    "SetPart",
    "SaveConfig",
    "DeleteConfig",
    "ApplyConfig",
    "Invite",
    "RevokeInvite",
    "Enter",
    "Exit",
    "BuyProperty",
    "SellProperty",
    "UpgradeGarage",
    "InstallModule",
})

-- Actions qui modifient le profil : identifiant de demande obligatoire.
ProgressionProtocol.Sensitive = table.freeze({
    ChooseStarter = true,
    Display = true,
    Store = true,
    TakeOut = true,
    Return = true,
    SetTuning = true,
    SetCosmetics = true,
    SetPart = true,
    SaveConfig = true,
    DeleteConfig = true,
    ApplyConfig = true,
    Invite = true,
    RevokeInvite = true,
})

ProgressionProtocol.PageSize = 20

return table.freeze(ProgressionProtocol)
