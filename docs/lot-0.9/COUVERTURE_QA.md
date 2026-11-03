# Couverture QA par fonction — état au lot 0.9.1

Pour chaque fonction : le type de test qui existe réellement, avec sa preuve. Légende des colonnes :

- **Unitaire** : test hors Studio (Lune, `tests/lune/specs/`), règles pures et contrôles statiques.
- **Studio instrumenté** : session VM où le test appelle les remotes du jeu ou remplace la lecture clavier/manette
  (pilote automatique) ; la simulation, les collisions et la validation serveur sont réelles.
- **GUI réelle** : session VM où l'interface est parcourue par de **vrais clics et vraies touches** (pont d'entrées,
  preuve par l'événement `Activated` ou l'effet observé).
- **Capture inspectée** : capture de la VM relue (référence `tâche / numéro`).
- **Test externe** : exige ce que la VM ne fournit pas (expérience de test isolée, DataStore réel, comptes, appareils).
- **Validation subjective** : jugement laissé au propriétaire (ressenti, lisibilité, esthétique, son).

Tâches : `20261103-hhmmss`, abrégées en `hhmmss` ; rapports dans `E:\ROBLOX DEV\aw-vm-exchange\jobs\` (hors dépôt).
« — » : aucun test de ce type. Les résultats sont détaillés dans `TESTS_INTERACTIFS_AUTONOMES.md` (lot 0.9.1) et
`RAPPORT_VALIDATION_GLOBALE.md` (lot 0.9).

| Fonction | Unitaire | Studio instrumenté | GUI réelle | Capture inspectée | Test externe | Validation subjective |
|---|---|---|---|---|---|---|
| Conduite (6 boîtes, aides, mouillé, énergie) | `Lot02*`, `PhysicsUnit`, `DrivingScenarios` | `lot02`, `solo`, `scenarios` (`185530`) | Accélérateur W, frein S, frein à main, sortie F (`224247`) | HUD `200648` 053–056 | Appareils réels (QA-P) | Ressenti (QA-H) |
| Robustesse numérique de la simulation | `Lot091Interactive` (QA-A08) | Occurrence observée `224247` (QA-A08, ouverte) | — | — | — | — |
| Caméras, vue cockpit | `Lot091Interactive` (QA-F15) | `lot08` : angle du volant ≥ 10° sur 27 véhicules (`213328`) | Touche V (`200648`, `220054`) | `200648` 053–055, `220054` 079–082 | — | Confort de vue |
| Collisions, propriété réseau | `CollisionExchangeSpec`, `NetworkOwnershipSpec` | `collision`, `collision_latence` (`185530`) | — | — | Charge réelle | — |
| Arrivée (onboarding) | `Lot08Content`, `Lot091Interactive` (QA-F13) | `lot08` (`185530`) | Parcours complet, annulation, confirmation (`200648`, `224247`) | `200648` 001–011 | Comptes réels (QA-V08) | Clarté du parcours |
| Garage, collection | `Lot04Progression` | `lot04` (`185530`) | 6 onglets, sélection, saisie de texte (`200648`) | `200648` 012–020 | DataStore réel (QA-D) | Ergonomie |
| Personnalisation (préparation) | `Lot04Progression` | `lot04` | Onglet ouvert seulement (hors garage) | `200648` 016 | — | Esthétique des options |
| Propriétés, invitations | `Lot04Progression` | `lot04` ; `social` : visite, conduite prêtée, retrait (`203223`) | Onglet ouvert | `200648` 015, 019 | DataStore réel | — |
| Concessions | `Lot05Economy` | `lot05` (`185530`) | Invite (E), devis, annulation, achat confirmé (`200648`) | `200648` 028–030 ; `220054` 067, 071 | — | Équilibrage (prix) |
| Marché | `Lot05Economy`, `Lot091Interactive` (QA-F16) | `lot05` (`185530`) | Mise en vente, retrait : défaut reproduit (`210055`), corrigé (`224247`) | `210055` 004–006 | Charge, inter-serveurs | Équilibrage |
| Missions, 8 métiers | `Lot05Economy`, `Lot09Integration` | `metiers` : 8 / 8 au moins une fois, 7 / 8 au mieux en une tâche (`213328`, `224247`) | Démarrage et abandon par clics (`200648`) | `200648` 026–027 ; écran `213328` 0158 (QA-F19) | Monde ouvert, comptes réels (QA-E04) | Intérêt des missions |
| Stations (énergie) | `Lot05Economy`, `Lot09Integration` | `lot05` (`185530`) | Onglet « Services » ouvert | `220054` 069–070, 073–074 | Plusieurs joueurs (QA-F10) | — |
| Courses (6 disciplines) | `Lot06Racing` | `lot06` : 6 disciplines jusqu'au résultat (`185530`) | Panneau, onglets, détail, records (`200648`) | `200648` 031–036 | Inter-serveurs (QA-R01) | Ressenti (QA-R15) |
| Drift noté | `Lot06Racing` | `drift` : **score 310 serveur** (`213328`) | — | — | — | Ressenti |
| Prêt après verrouillage | `Lot06Racing` | `drift` : `RaceAlreadyLocked`, engagement intact (`203223`, `213328`) | — | — | — | — |
| Classements | `Lot06Racing` | `lot06` | Tableau drift (`200648`) | `200648` 036–037 | OrderedDataStore (QA-R04) | — |
| Smartphone | `Lot07Interface`, `Lot091Interactive` (QA-F14) | Téléphone en main côté serveur (`200648`) | Toutes les applications ouvertes et refermées (`200648`) | `200648` 038–048 ; `220054` 091 | Vu par un autre joueur (QA-U10) | Pose du bras (QA-U10) |
| Carte | `Lot07Interface` | — | Touche M, zoom, choix d'un lieu (`203223`) | `200648` 049–051 ; `220054` 083–084 | — | Lisibilité (QA-U11) |
| GPS | `Lot07Interface`, `Lot091Interactive` (QA-F20) | `gps` : 5 arrivées / 7 en conduite réelle (`220054`) ; `gps2` : `225749` | Destination par clic, effacement X (`203223`) | `220054` gps_* | — | Justesse ressentie des indications |
| Social, groupes, partage | `Lot07Interface` | `social` à deux clients, confidentialité (`203223`) | Application Social ouverte (`200648`) | `200648` 044 | Communications Roblox (QA-U07) | — |
| Paramètres | `Lot07Interface` | — | Pages, niveau du HUD enregistré côté serveur (`200648`) | `200648` 039–043 | DataStore réel (QA-U09) | Lisibilité |
| Conduite et menus | `Lot07Interface`, `Lot091Interactive` (QA-F18) | — | Refus en roulant, mode rapide, véhicule immobile menu ouvert (`224247`) | `200648` 055–056 | — | — |
| Mode photo | `Lot08Content` | `lot08` (à pied, `185530`) | Par le téléphone ; touche O jamais reçue dans Studio (`224247`) | `224247` photo_* | Client Roblox (touche O) | Rendu des filtres |
| HUD | `Lot07Interface` | `solo` | Touche H (`203223`) | `200648` 053 | Résolutions réelles (QA-U04) | Lisibilité |
| Monde ouvert, 7 zones | `Lot03World`, `Lot03Systems` | `monde` (`193356`) | — | `220054` 060–066 | — | Esthétique |
| Bâtiments, garages, concessions | `Lot03World` | `monde` | — | `220054` 067–074 | — | Esthétique |
| Carrosseries | `Lot08Content` | `lot08` : banc 18 / 18 (`185530`) | — | `220054` 075–078 | — | Esthétique |
| Nuit, éclairage | `Lot08Content`, `Lot091Interactive` (QA-F17) | `perf` : 12 sources de nuit (`175506`) | — | `220054` 085–089 | Appareils réels | **Nuit très sombre** (jugement) |
| Pluie | `Lot03Systems` | `monde`, `perf` | — | `220054` 087–088, 090 | — | Rendu |
| Performances | — | `perf` (indicatif, VM) | — | — | **Appareils réels** (QA-P) | — |
| Persistance réelle (DataStore) | `Lot04Persistence` (mémoire) | Mémoire seulement | — | — | **Expérience de test isolée** (QA-D) | — |
| Manette | `InputArbiterSpec` | — | **Impossible** (pilote système) | — | Humain (QA-U03) | Ressenti |
| Son, radio | `Lot08Content` | `lot08` (radio) | — | — | — | **Humain** |

Ce qui reste sans aucun test en jeu, à ce jour : persistance sur DataStore réel, services inter-serveurs, manette,
son, comptes réels, charge à 24 joueurs, performances sur appareils réels — tous dépendants d'une validation externe
(`DEPENDANCES_VALIDATION_EXTERNE.md`) ou humaine (`CHECKLIST_TESTS_HUMAINS.md`).
