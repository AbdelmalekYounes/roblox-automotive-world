# Règles permanentes du projet Roblox Automotive World

Ce fichier s'applique à tout travail sur ce dépôt (humain ou assistant). En cas de doute, il prime sur les
habitudes ; seul le propriétaire du projet peut le modifier ou accorder une exception.

## Référence et périmètre

- Le **cahier des charges global v1.0** (`docs/CAHIER_DES_CHARGES_GLOBAL_v1.0.md`) et ses **33 décisions AUD**
  font autorité. Un écart doit être signalé et arbitré, jamais décidé seul.
- **Aucune modification du périmètre sans autorisation** : on livre ce que le lot demande, ni moins ni plus.
  Les améliorations repérées hors périmètre sont proposées (ex. `PROPOSITION_LOT_x.md`), pas réalisées.
- **Un lot doit être clôturé avant de commencer le suivant** : tests passés, rapport factuel rédigé, écarts
  documentés, pull request validée et fusionnée par le propriétaire.
- Aucun crédit, achat, possession définitive, DataStore ni récompense avant le lot qui les prévoit.

## Architecture et code

- Séparation stricte : `src/server` (autorité, validation), `src/client` (commandes, rendu, simulation locale
  du véhicule piloté), `src/shared` (types, définitions, modules physiques **purs** testables hors Studio).
- Le serveur ne fait jamais confiance à une valeur sensible envoyée par un client : il valide en contexte, avec
  une tolérance réseau, et corrige sans sanction automatique (AUD-PHYS-01, AUD-COLL-01).
- **Luau typé** (`--!strict`) partout où c'est pertinent ; 0 erreur `luau-lsp`.
- **Commentaires explicatifs en français** : pourquoi, unités, limites. Textes joueur envoyés par clé.
- Paramètres physiques isolés par modèle (`src/shared/Vehicles/Definitions/`), validés et gelés ; ce qui n'est
  pas implémenté est **refusé** par la validation, jamais simulé en silence.

## Originalité et dépendances

- **Aucun emprunt de code, de modèle, d'interface, de texture, de son ni de donnée à d'autres projets**
  (notamment Collectverse et Mimic Hunters), ni d'actif Marketplace non inspecté.
- Pas de dépendance opaque : outils épinglés dans `rokit.toml`, aucune bibliothèque tierce dans le jeu.

## Tests et rapports

- **Tests obligatoires** pour toute modification : `scripts\verify.ps1 -DownloadRobloxTypes` (Rojo, Selene,
  StyLua, luau-lsp strict, Lune, pytest) et, pour ce qui dépend du moteur, `test-vm.cmd` (Roblox Studio dans la VM).
- **Rapports factuels** : n'écrire que ce qui a été exécuté et mesuré, avec la commande, la date et l'identifiant
  de la tâche. Ne jamais présenter un résultat ancien comme une nouvelle exécution, ni un test automatisé comme un
  essai humain. Ce qui n'a pas été vérifié est listé comme tel.
- README, rapports (`docs/lot-x/`), feuille de route et tests doivent rester cohérents entre eux.

## Environnement de test et sécurité

- Les tests ne doivent **jamais** accéder aux DataStores de production ni à des données réelles.
- Tests **non intrusifs** sur le poste principal : pas de prise de contrôle de la souris, du clavier ou de
  l'écran ; les essais Studio se font dans la VM VMware (`docs/VM_TESTS.md`). Toute interaction graphique
  nécessaire est annoncée et laissée au propriétaire.
- La VM ne voit que le dossier d'échange (hors du dépôt) ; aucun script ne modifie un réglage de sécurité, ni
  l'agent d'un autre projet, sans accord explicite.
- **Aucune publication Roblox** (place, paquet, actif) sans accord explicite du propriétaire.

## Git

- Travailler sur une branche de lot (`feat/...`) ; ne jamais écraser `main` ; aucune fusion sans validation du
  propriétaire.
