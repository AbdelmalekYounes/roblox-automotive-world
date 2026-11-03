# Campagne de tests groupée — 2026-11-03

Demande du propriétaire : « fais tous les tests ». Campagne exécutée sur la branche
`feat/properties-garages-persistence-0.4` (qui contient les lots 0.1 à 0.4). Tous les essais Roblox Studio ont tourné
dans la VM de test (`docs/VM_TESTS.md`), jamais sur le poste principal ; aucune publication, aucun DataStore.

Ce document ne rapporte que ce qui a été exécuté. Ce qui ne pouvait pas l'être (essais humains, DataStore réel,
charge) reste **NON TESTÉ** dans [`QA_BACKLOG.md`](QA_BACKLOG.md), avec ce qu'il faut pour le faire (§5).

## 1. Exécutions

| Tâche VM | Commit | Place | Sessions | Résultat (réussis / échecs / limites connues) |
|---|---|---|---|---|
| `20261103-023510` | `412869e` | développement | 7 sessions historiques | 463 / 3 / 1 |
| `20261103-025318` | `ac3cf72` | développement | `lot04` (nouvelle, 2 joueurs) | 60 / 3 / 0 → **défaut trouvé** (§3.1) |
| `20261103-025600` | `5da05aa` | développement | `lot04` après correction | **63 / 0 / 0** |
| `20261103-025743` | `5da05aa` | monde ouvert | `monde` (nouvelle) | 31 / 1 / 0 → **défaut trouvé** (§3.2) |
| `20261103-030159` | `b41e0f1` | monde ouvert | `monde` après correction | **32 / 0 / 0** |
| `20261103-030408` | `b41e0f1` | développement | 7 sessions historiques + `lot04` (campagne finale) | **526 / 4 / 1** |

Commande : `tools\vm\host-run.ps1 -NoVmControl [-Place OpenWorld] -Sessions …` (équivalent de `test-vm.cmd`).
Studio `0.745.449.7450003` dans la VM. Rapports détaillés : `aw-vm-exchange\jobs\<tâche>\report\report.md` (hors dépôt).

Hors Studio, même jour : `scripts\verify.ps1 -RobloxTypes .tooling\globalTypes.d.luau` — toutes les étapes OK
(résultat final au §6).

## 2. Nouvelles sessions écrites pour cette campagne

- **`monde`** (place monde ouvert, 1 joueur) : carte et version, streaming, parc de 9 prototypes posé, apparition
  unique en métropole, météo publiée puis pluie forcée reçue par le client, trafic (agents, corps physiques au
  serveur, aucun tombé), 16 invites des lieux du lot 0.4, routes et décor reçus par le client, feux colorés, piétons
  rendus, heure synchronisée, **conduite réelle 14 s à plein gaz sur une portion droite de l'autoroute** (vraie
  simulation, seule la lecture clavier/manette est remplacée), véhicules au repos sur route de montagne, rue et chemin.
- **`lot04`** (place de développement, 2 joueurs) : profils en mémoire, propriété gratuite unique et données
  synthétiques, starter refusé (liste vide), entrée physique dans la propriété, exposition et capacités, sortie
  idempotente et unique avec énergie restaurée, droit de conduire refusé à l'autre joueur, invitation, visite,
  révocation avec retour à l'entrée, retour du véhicule à sa place, garage public (réglages, pièce, esthétique,
  configurations sans duplication de pièce), demandes invalides, transactions toutes confirmées.

## 3. Défauts trouvés et corrigés (preuve d'exécution avant / après)

### 3.1 Second véhicule conduisible sur une sortie répétée (lot 0.4) — corrigé

- **Constat** (`20261103-025318`) : une seconde demande « Sortir » portant le même identifiant, arrivée pendant que
  la première attendait sa sauvegarde, renvoyait « Pending » et matérialisait une **seconde copie conduisible** du
  même exemplaire (`aucun_vehicule_personnel_restant` : 1 en fin de session).
- **Correction** (`5da05aa`) : les répétitions sont signalées (`Replayed`) et ne produisent plus aucun effet de
  bord ; refus si un exemplaire est déjà matérialisé ; test Lune ajouté.
- **Preuve** : `20261103-025600` et `20261103-030408` — « Pending, 1 exemplaire(s) dans le monde », aucun véhicule
  personnel restant.

### 3.2 Chaussées raccourcies par le moteur (lot 0.3) — corrigé

- **Constat** (`20261103-025743`) : le P-01 posé sur l'autoroute A6-2 n'atteignait que 37,8 km/h en 14 s (44 m) ; les
  captures montrent la voiture sur l'herbe puis heurtant un bord de chaussée (dégâts avant). Cause établie hors
  Studio : Roblox limite une pièce à 2 048 studs par côté et **raccourcit en silence** les pièces plus longues ; 195
  pièces de la carte la dépassaient (24 chaussées, 126 marquages, 37 glissières, 8 trottoirs), d'où des trous aux
  extrémités des longues portions droites.
- **Correction** (`b41e0f1`) : tracés redécoupés en segments de 500 m au plus ; le générateur échoue désormais si une
  pièce dépasse 2 048 studs. Carte : 37 239 pièces (36 968 avant). Génération toujours déterministe (deux
  générations identiques, SHA-256 `c2a272d3c891250d…`).
- **Preuve** : `20261103-030159` — 133,4 km/h en 14 s sur 397 m, garde au sol minimale 1,76 st, aucun échantillon
  sans sol, véhicule resté droit.

## 4. Anomalies connues observées pendant la campagne (non corrigées)

| Anomalie | Observée | Détail |
|---|---|---|
| QA-A01 (propriété réseau / réplication) | oui | réattributions de propriété réseau en `collision` (`023510`) et `collision_latence` (`023510`, `030408`) ; une correction « Teleport » en `collision_latence` (`030408`) ; corrections « Teleport » consignées (à titre d'information) dans les journaux des sessions `solo`, `multijoueur`, `latence` |
| QA-A02 (sortie non effective) | oui, 1 fois sur 2 campagnes | `030408`, `collision_latence`, diagnostic `client.diag_sortie_4` : « avant 27,3 km/h rapport -1 ; après 0,0 km/h, conduite=true, assis=true, ExitTooFast=true » — la demande de sortie est arrivée **véhicule en marche arrière à 27,3 km/h**, refusée (sortie au-dessus de 20 km/h), et le personnage est resté assis. Première trace chiffrée de l'anomalie ; la cause n'est pas établie (vitesse du scénario au moment de la demande ou défaut du jeu). Non reproduite dans `scenarios` (2 exécutions sur 2 sans échec). |
| QA-A03 (attribut de propriété) | oui | 1 écart sur 2 340 contrôles (`023510`, `collision`) ; 1 sur 7 092 (`030408`, `lot02`) |
| QA-A05 (véhicule ancré) | oui | limite connue (⚠️) dans `scenarios`, inchangée |

Aucune erreur d'exécution de notre code dans aucune session (contrôles `aucune_erreur_execution`).

## 5. Ce qui ne peut pas être fait depuis la VM

| Catégorie | Pourquoi | Ce qu'il faut |
|---|---|---|
| Essais humains QA-H01 à QA-H20 | clavier, manette, ressenti, lisibilité : un humain | le propriétaire, dans Studio (place de développement : P / Select ; place monde ouvert) |
| DataStore réel QA-D01 à QA-D10 | aucune expérience de test déclarée ; publication interdite sans accord | accord pour publier une **expérience de TEST isolée**, son `GameId` dans `EnvironmentConfig.TestGameIds`, l'accès Studio aux API **de cette expérience de test uniquement** |
| Charge QA-P01 à QA-P09 | 24 joueurs et appareils de référence : impossibles dans la VM sans accélération graphique | serveur de test Roblox réel et appareils de référence |

## 6. Vérifications hors Studio (finales)

`scripts\verify.ps1 -RobloxTypes .tooling\globalTypes.d.luau`, 2026-11-03 à 03:25, code du commit `b41e0f1` (arbre de
travail : documentation seule modifiée) : Rojo (2 places), Selene, StyLua, **236 tests Lune**, génération de la carte
(37 239 pièces, aucune au-delà de 2 048 studs), **10 pytest**, luau-lsp strict : tout OK.
