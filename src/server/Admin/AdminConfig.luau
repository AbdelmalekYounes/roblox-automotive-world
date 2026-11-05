--!strict
-- Administrateurs du jeu (lot ADMIN-01). Côté SERVEUR seulement : jamais répliqué, jamais modifiable par un client.
-- Décisions du propriétaire du 2026-11-05 : le compte des essais VM, youyou31110 (A6), et son compte Studio,
-- Akroniik (UserId relevé par le diagnostic du menu dans sa sortie Studio). Seul le propriétaire du projet peut
-- modifier cette liste.
return table.freeze({
    AdminUserIds = table.freeze({
        941826283, -- youyou31110 (essais VM)
        7835831473, -- Akroniik (compte Studio du propriétaire)
    }) :: { number },
})
