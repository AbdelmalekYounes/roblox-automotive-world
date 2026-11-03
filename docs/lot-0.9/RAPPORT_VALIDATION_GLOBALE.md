# Rapport de validation globale — lot 0.9

Branche `feat/integration-qa-0.9`, créée depuis `7c4297b` (dernier commit du lot 0.8), PR brouillon #9 vers
`feat/art-audio-onboarding-0.8`. `main` et les branches des lots 0.1 à 0.8 sont intactes ; aucune PR fusionnée.
**Ce lot n'autorise pas un lancement public.** Aucune publication Roblox, aucun téléversement, aucun DataStore
réel, aucune API de production.

Documents associés : `ANOMALIES_ET_CORRECTIONS.md` (bilan des anomalies et classement du registre),
`SECURITE.md`, `PERFORMANCES.md`, `CHECKLIST_TESTS_HUMAINS.md`, `DEPENDANCES_VALIDATION_EXTERNE.md`.

## 1. Version intégrée

Les têtes des huit PR (`0542fd0`, `c0f7a28`, `c00a5c6`, `6f1dc7d`, `c0c458b`, `c408164`, `f48e886`, `7c4297b`) sont
contenues dans la branche du lot 0.8 (vérifié par `git merge-base --is-ancestor`). Les lots 0.1 à 0.8 se chargent
ensemble : vérification hors Studio entièrement réussie dès le départ (2026-11-03 15:12, `9168c8a` : Lune 324 / 0,
pytest 14, luau-lsp strict 0 erreur, carte déterministe) et première campagne VM de huit sessions complète
(`20261103-151033`, 507 réussis / 26 échecs — échecs analysés au §2).

## 2. Campagnes VM exécutées (Studio `0.745.449`, VM VMware, 2026-11-03)

Commande : `powershell -ExecutionPolicy Bypass -File tools\vm\host-run.ps1 -NoVmControl [-Place OpenWorld]
-Sessions …`. Rapports : `E:\ROBLOX DEV\aw-vm-exchange\jobs\<tâche>\report\report.md` (hors dépôt). Le commit est
celui de la tête au dépôt de la tâche.

| Tâche | Commit | Place | Sessions | Réussis / échecs | Constat |
|---|---|---|---|---|---|
| `151033` | `7c4297b` | Dev | 7 historiques + `lot04` | 507 / 26 | Mât du drag sur la ligne d'essai (QA-F05) ; relevé du HUD trop tôt ; sorties non effectives (QA-A02) |
| `153933` | `708331e` | Dev | `multijoueur`, `latence`, 2 collisions, `lot02` | 376 / 9 | Multijoueur et latence réussis ; ESP sur un portique (QA-F06) |
| `155713` | `dcf47c8` | Dev | 2 × 2 collisions, `lot02`, `lot05`, `lot06`, `lot08` | 472 / 25 | **Plus aucune** sortie ratée ni correction « Teleport » ; `lot02` réussi ; marché (QA-F08) ; courses (QA-F07) |
| `163722` | `38e3b3b` | Dev | `lot05`, `lot06`, `lot08` | 104 / 16 | Marché corrigé ; pilote des courses (marche arrière à l'arrêt) |
| `170323` | `42434c2` | Dev | `lot05`, `lot06`, `lot08` | 112 / 8 | **Épreuve officielle complète** ; banc **18 / 18** |
| `173128` | `28816d9` | Dev | `lot05`, `lot06` | 86 / 7 | `lot05` **entièrement réussi** |
| `174932` | `28816d9` | Monde ouvert | `monde`, `perf` | **41 / 0** | Lampadaires éteints relevés par la mesure (défaut, `PERFORMANCES.md` §4) |
| `175506` | `f2fe391` | Monde ouvert | `perf` | 3 / 0 | 12 lampadaires allumés de nuit |
| `175825` | `f2fe391` | Dev | `lot06` | 23 / 1 | Faux départ pénalisé (5 s) ; pilote bloqué contre un poteau d'arrivée |
| `182533`, `184407` | `025717c`, `737d081` | Dev | `lot06` | 36 / 7, 38 / 5 | Fin d'épreuve lue dans « Results » ; sprint à deux et drag jusqu'au résultat |
| **`185530`** | **`855b93b`** | Dev | **11 sessions** (7 historiques, `lot04`, `lot05`, `lot06`, `lot08`) | **649 / 3** (+1 limite connue) | **Campagne finale** : voir ci-dessous |
| **`193356`** | `741d848` (code identique à `855b93b`) | Monde ouvert | `monde`, `perf` | **41 / 0** | Habillage reçu (686 pièces), autoroute 133,5 km/h, 12 lampadaires de nuit |

**Campagne finale** (`20261103-185530`, 2026-11-03 18:55–19:33) : 649 réussis, 3 échecs, 1 limite connue.

- Échecs : 2 × `scenario.propriete_reseau_sans_anomalie` (une « réattribution (1) » chacun, QA-A01 résiduel) ;
  `lot06.j2.pret_au_depart` (`RaceAlreadyLocked` : le joueur 2 se déclare prêt après le verrouillage automatique ;
  il court quand même — refus légitime, minutage du test).
- Limite connue : véhicule ancré par le test (QA-A05).
- **Courses** : les **six disciplines jouées jusqu'au résultat** dans Studio par le pilote automatique — sprint
  officiel à deux (49,4 s et 50,4 s, faux départ pénalisé de 5 s, récompenses +74 et +46), drag (11,4 s, 113 km/h,
  réaction 1,43 s), contre-la-montre (42,6 s), circuit de 3 tours (141,9 s, meilleur tour 46,8 s), rallye
  (59,8 s), drift (session de 90 s, score 0 : le pilote ne dérive pas — le calcul du score est vérifié en Lune) ;
  entraînements sans crédit ; aucun engagement ni exemplaire réservé restant.
- **Banc** 18 / 18 ; parcours d'arrivée, photo, radio ; `lot05` et `lot04` entièrement réussis ; `lot02`,
  `solo`, `multijoueur`, `latence`, `scenarios` réussis.

Vérification hors Studio sur le même commit (`855b93b`, 2026-11-03 18:55) :
`scripts\verify.ps1 -RobloxTypes .tooling\globalTypes.d.luau` — Rojo (deux places), Selene, StyLua, pilote
Studio, **Lune 329 / 0**, génération déterministe de la carte (47 653 pièces), **pytest 14**, luau-lsp strict
0 erreur.

Nouvelles sessions écrites pour ce lot : **`lot05`** (économie et marché à deux joueurs, falsifications),
**`lot06`** (courses : épreuve officielle à deux, cinq disciplines en entraînement, pilote automatique),
**`lot08`** (parcours d'arrivée, banc des 18 modèles, photo, radio), **`perf`** (mesures de référence) ;
`monde` contrôle en plus l'habillage reçu.

## 3. État par système

Confiance : **haute** (vérifié en jeu de bout en bout et en Lune), **moyenne** (règles en Lune, parcours en jeu
partiel), **basse** (logique seulement, ou dépend d'un essai humain ou externe).

| Système | État | Essais réalisés | Non réalisés | Anomalies (gravité) | Corrections du lot | Confiance | Dépendances externes |
|---|---|---|---|---|---|---|---|
| Véhicule, physique, 6 boîtes, 3 architectures, aides, pneus, freinage, dégâts, énergie, caméras | Implémenté | Lune ; `lot02` (6 boîtes, ABS, TC, ESP, freinage sec, pente, bordures, dégâts, panne, caméras) ; banc `lot08` | Mouillé en conduite réelle (QA-S07), ressenti | QA-A04/A07 (P2) | QA-F05, F06 | Haute | Ressenti (propriétaire) |
| Propriété réseau, réplication, collisions | Implémenté | 7 sessions historiques, 2 × 2 collisions | — | QA-A01 résiduel (P2), A03 (P3) | Cause de QA-A02 et du symptôme de QA-A01 établie (test) | Moyenne | — |
| Entrée / sortie | Implémenté | Sessions historiques, `lot08` | Manette réelle | — | — | Haute | — |
| 18 modèles proposés | Proposé | Validation physique (Lune) ; banc en jeu 18 / 18 | Ressenti | — | — | Moyenne | **Approbation** (D1) |
| Monde ouvert (7 zones, routes, autoroute, montagne, streaming, trafic, piétons, météo, jour / nuit, éclairage, habillage) | Implémenté (rendu provisoire) | `monde` (autoroute 133 km/h, repos en montagne, rue, chemin, streaming, trafic, piétons, pluie, horloge, habillage) ; `perf` (nuit, pluie) | Traversée des 7 zones au volant (QA-H12), véhicules d'autres joueurs hors rayon (S05) | — | Lampadaires et niveau de détail (`f2fe391`) | Moyenne | — |
| Propriétés, garages, collection, préparation, configurations, invitations | Implémenté | `lot04` (2 joueurs) | DataStore réel | — | — | Haute (mémoire) | Expérience isolée (R1) |
| Économie : crédits, concessions, marché, pièces, carburant, recharge, lavage, réparation, immobilier | Implémenté | `lot05` (achats, falsifications, rejeu, solde, débit abusif, marché concurrent, pièces, plein, lavage) | Immobilier et réparation en jeu, recharge électrique, inter-serveurs | — | **QA-F08** (marché), QA-F10 (stations) | Haute (mémoire) | R1 |
| Huit métiers, récompenses | Implémenté (présentation partielle) | Lune (8 métiers, gain unique) ; `lot05` (démarrage, fin falsifiée refusée, abandon sans paiement) | **Mission complète en jeu** (QA-E04, E05) | Remorquage non implémenté | QA-F11 (chargement visible) | Moyenne | — |
| Courses : 6 disciplines, départs, faux départs, points de passage, tours, drift, salons, modes, réservation, classements, récompenses | Implémenté | Lune (19 + tests) ; `lot06` : épreuve officielle à deux de bout en bout (inscription, réservation, grille, départ, arrivée, récompense, libération), faux départ pénalisé, **six disciplines jusqu'au résultat**, classée sans file refusée | Classé réel, drift avec dérive réelle, monde ouvert, inter-serveurs, jeu humain | — | **QA-F07** (inscription impossible) | Haute (Dev) | R1 (inter-serveurs) |
| HUD, GPS, carte, smartphone, groupes, permissions, notifications, localisation, accessibilité | Implémenté | Lune (lot 0.7) ; HUD en jeu (sessions historiques) ; panneaux traduits (Lune) | Parcours d'interface, manette, lisibilité (humain) | — | — | Moyenne | Humain |
| Mode photo | Implémenté | Lune ; `lot08` (ouverture à pied, caméra restaurée à l'identique) | Mur, propriété, capture | — | — | Moyenne | Humain |
| Parcours d'arrivée et exercices | Implémenté (Dev) | `lot08` (11 étapes, essai, refus en course, choix unique, propriété, exercices) | Comptes réels | — | QA-F09 (lot 0.8) | Haute (Dev) | **D2** (liste officielle) |
| Audio, radio | Contrôleurs seulement | Lune ; `lot08` (station indisponible refusée) | Tout son réel | Aucun son joué (attendu) | — | Basse | **D4, D5, R3** |
| Persistance (DataStore) | Implémenté, jamais exécuté sur DataStore | Simulations mémoire (§6) | Tout essai réel | — | — | Basse | **R1, R2** |
| Performances | Outillage | `perf`, `lot02` | Appareils réels, 24 joueurs | — | Lampadaires | Basse | M1, R4, R5 |

## 4. Scénarios de jeu de bout en bout

| Scénario | Exécuté | Résultat |
|---|---|---|
| 1. Nouveau joueur | **Oui**, `lot08` (Dev, candidats synthétiques) | Introduction, refus hors ordre, essai d'un candidat (véhicule marqué, refusé en course), fin de l'essai, choix confirmé, second choix sans effet, propriété gratuite, parcours terminé, exercices ; protection d'apparition relevée par le serveur |
| 2. Progression normale | **Partiel**, `lot05` + `lot04` | Achats à la concession, pièces au garage public, sortie du garage, plein, mission démarrée puis abandonnée ; **mission complète NON exécutée** (pilotage jusqu'aux étapes non automatisé) |
| 3. Conduite et exploration | **Partiel**, `monde` | Autoroute à 133 km/h, repos sur route de montagne, rue et chemin, trafic, piétons, pluie ; **traversée des sept zones avec GPS NON exécutée** |
| 4. Compétition | **Oui**, `lot06` | Inscription avec véhicule personnel, exemplaire réservé pendant l'épreuve, grille, départ, arrivée (49,4 s), récompense, libération, aucun engagement restant ; faux départ pénalisé de 5 s ; cinq disciplines d'entraînement jusqu'au résultat, sans crédit |
| 5. Commerce entre joueurs | **Oui**, `lot05` | Annonce, deux achats simultanés (un seul aboutit), débit de l'acheteur, crédit du vendeur (prix − 5 %), exemplaire unique ; interruption réelle (arrêt de serveur) NON exécutée (Lune seulement) |
| 6. Social | **Partiel**, `lot04` | Invitation, visite, révocation ; groupes et partage de position : Lune seulement |
| 7. Conditions dégradées | **Partiel** | Latence 100 ms (`latence`, `collision_latence`) ; stockage indisponible, écriture incertaine, verrou repris, interruption de transfert : **simulations mémoire** (§6) ; crash de serveur réel : NON TESTÉ |

## 5. Gamme de 18 modèles (proposition, non approuvée)

Mesures en jeu (`lot08`, `20261103-170323`, ligne droite d'essai, pilote automatique, conducteur non humain)
comparées au banc planaire hors Studio (lot 0.8) :

| # | Modèle | Boîte | W/kg | 0–100 banc (s) | 0–100 en jeu (s) | Écart | Vitesse à 230 m (km/h) | Arrêt (m) |
|---|---|---|---|---|---|---|---|---|
| 1 | Pixel | rapport unique | 51 | 11,6 | 12,18 | +5 % | 102,0 | 51,1 |
| 2 | Brio | manuelle | 67 | 10,9 | 13,45 | +23 % | 101,6 | 49,4 |
| 3 | Fil | rapport unique | 64 | 10,8 | 11,17 | +3 % | 111,4 | 58,5 |
| 4 | Aster | automatique | 74 | 10,9 | 11,32 | +4 % | 107,0 | 52,5 |
| 5 | Nova | CVT | 69 | 10,8 | 11,23 | +4 % | 109,6 | 56,5 |
| 6 | Cadence | automatique | 72 | 10,1 | 10,43 | +3 % | 111,1 | 62,1 |
| 7 | Lumen | manuelle | 68 | 10,3 | 11,95 | +16 % | 108,7 | 60,9 |
| 8 | Orée | rapport unique | 112 | 6,1 | 6,27 | +3 % | 139,6 | 63,5 |
| 9 | Brise | manuelle | 104 | 8,3 | 10,00 | +20 % | 119,4 | 63,2 |
| 10 | Rafale | double embrayage | 141 | 6,6 | 6,81 | +3 % | 138,8 | 69,0 |
| 11 | Éclat | manuelle | 136 | 6,7 | 8,31 | +24 % | 132,0 | 66,1 |
| 12 | Mistral | automatique | 192 | 5,7 | 5,82 | +2 % | 148,8 | 63,9 |
| 13 | Comète | séquentielle | 324 | 4,5 | 4,77 | +6 % | 181,2 | 55,3 |
| 14 | Zénith | rapport unique | 316 | 3,2 | 3,33 | +4 % | 195,9 | 48,4 |
| 15 | Dune | automatique | 75 | 10,1 | 10,45 | +3 % | 107,8 | 58,7 |
| 16 | Vigie | automatique | 115 | 6,7 | 6,98 | +4 % | 125,2 | 69,5 |
| 17 | Sentier | manuelle | 69 | 11,3 | 13,05 | +15 % | 105,9 | 57,1 |
| 18 | Atlas | automatique | 67 | 9,8 | 10,05 | +3 % | 108,8 | 56,6 |

Analyse :

- **Cohérence fiche / jeu** : boîtes automatique, CVT, double embrayage, séquentielle et rapport unique : écart de
  +2 à +6 % (latence de commande, adhérence réelle, mesure à l'horloge client). Boîtes **manuelles : +15 à +24 %**,
  dû au pilote du test (passage à 90 % du régime maximal, embrayage dosé en 0,4 s) ; un humain ferait mieux. Aucun
  écart n'indique une fiche fausse.
- **Diversité physique** : rapport poids / puissance de 51 à 324 W/kg ; 0–100 de 3,3 à 13,5 s ; 4 électriques,
  3 diesels, 11 essences ; 6 types de boîte ; traction, propulsion, intégrale. Les trois candidats de départ ont des
  performances voisines (0–100 en jeu 11,2 à 13,5 s) et des caractères différents (`docs/lot-0.8/CATALOGUE_18_VEHICULES.md` §3).
- **Distances d'arrêt** : mesurées depuis des vitesses différentes (vitesse atteinte à 230 m) : non comparables
  entre modèles ; aucune anomalie (48 à 70 m).
- **Silhouettes et actifs provisoires** : 10 silhouettes construites par code, aucun maillage ni texture, habitacle
  simplifié (`docs/lot-0.8/ASSETS_ET_LICENCES.md`). Rien n'est marqué officiel ni approuvé.

## 6. Persistance : simulations mémoire et préparation de l'essai réel

Aucun DataStore réel n'a été utilisé (`EnvironmentConfig` : aucune expérience déclarée ; pytest le vérifie).

| Scénario du brief | Simulation mémoire existante (tests Lune) | Essai réel |
|---|---|---|
| Premier profil | « création, sauvegarde confirmée, libération, rechargement » | NON TESTÉ (QA-D01) |
| Sauvegarde et reconnexion | idem ; « verrou rafraîchi » | NON TESTÉ |
| Arrêt brutal | « verrou détenu : seconde session refusée, puis reprend un verrou expiré » | NON TESTÉ (QA-D03) |
| Verrou repris | idem ; « un ancien serveur ne peut pas écraser un état plus récent » ; « génération périmée » | NON TESTÉ (QA-D02) |
| Mutation concurrente | « budget par clé », « répétition signalée rejouée », lot 0.9 « annonce en attente » | NON TESTÉ |
| Transactions entre deux serveurs | « perte de réponse : reprise par un autre serveur sans doublon », « déconnexion pendant le transfert » | NON TESTÉ (QA-E02) |
| Vente interrompue | « compensation : acheteur remboursé », « stockage indisponible : achat non engagé » | NON TESTÉ (QA-E01) |
| Réservation de véhicule interrompue | courses 9, 18, 19 (réservation, déconnexion, reprise sans doublon) | NON TESTÉ (QA-R03) |
| Migration | v1 → v2 → v3 → v4 → v5, données conservées, original intact | NON TESTÉ (QA-D09) |
| Restauration ciblée | **Aucun outil** (champs retirés conservés dans `Legacy` seulement) | NON TESTÉ, procédure à écrire (QA-D08) |
| Budget DataStore dépassé | « stockage indisponible : opérations suspendues (AUD-DATA-01) », réponses incertaines | NON TESTÉ (QA-D06, D07) |

Procédure de l'essai réel (à exécuter seulement après les décisions R1 et R2 de
`DEPENDANCES_VALIDATION_EXTERNE.md`) :

1. Le propriétaire crée une expérience **de test isolée**, active l'accès aux API **sur elle seule**, et déclare
   son identifiant dans `EnvironmentConfig.TestGameIds` par une revue de code. Rien n'est déclaré en production.
2. Construire et publier la place de développement dans cette expérience (privée). Vérifier au démarrage le journal
   `Profils : environnement Test, stockage DataStore` ; arrêter si « Prod » apparaît.
3. Exécuter, avec deux comptes de test : premier profil ; sauvegarde puis reconnexion sur le même serveur puis sur
   un autre ; arrêt brutal (fermer le serveur depuis le Creator Hub pendant une sortie de véhicule) puis
   reconnexion ; deux sessions simultanées du même compte (verrou) ; vente entre deux comptes sur deux serveurs,
   arrêt d'un serveur entre deux étapes ; course officielle interrompue par une déconnexion ; consommation du
   budget (`DataStoreService:GetRequestBudgetForRequestType`) avec 10 changements rapides.
4. Après chaque scénario : relire le profil (console développeur, ou outil de lecture à écrire), vérifier solde,
   exemplaires (aucun doublon), réservations, journal des transactions.
5. Consigner commande, date, identifiant de session et résultat dans `docs/QA_BACKLOG.md` §3 bis ; tout écart
   devient une anomalie.

## 7. Fonctions incomplètes et actifs manquants

| Élément | État | Réalisé au lot 0.9 | Intervention nécessaire |
|---|---|---|---|
| Remorquage (assistance) | Non implémenté | — | Conception physique (attelage entre un véhicule simulé par un client et un véhicule remorqué) sans dégrader la propriété réseau : à arbitrer, lot dédié |
| Passagers et colis des métiers | Était un repère d'étape | **Chargement visible** (QA-F11) | Silhouettes définitives et animations (A1, A3) |
| Bornes et pompes | Pas d'occupation | **Capacité par lieu** (QA-F10) | File d'attente éventuelle : à arbitrer |
| Échelle du marché | Index borné à 500 | — | Essai de charge sur DataStore réel (QA-E03) |
| Matchmaking inter-serveurs | Écrit, jamais exécuté | — | Expérience isolée publiée (R1, R4) |
| Résultats non confirmés | Classés sans gain (Lune) | — | Essai réel sous latence (QA-R05) |
| 18 véhicules | Intégrés, proposés | Banc en jeu 18 / 18 | Approbation (D1), modèles finaux (A1) |
| Audio, radio | Contrôleurs, aucun son joué | — | D4, D5, R3 |
| Animations | Provisoires (aucune) | — | A3 (exige une publication d'actif) |
| Anciennes interfaces 0.4–0.7 | Fonctionnelles, finition partielle | — | Reprise visuelle (lot ultérieur) |
| Décors et modèles | Provisoires | Lampadaires de nuit réparés | A6 |

## 8. Recommandation pour le lot 1.0

**Recommandation : NON pour un lancement public ; OUI pour engager le lot 1.0 en tant que lot de vérification du
périmètre, à condition de lever d'abord les dépendances externes bloquantes.**

Ce que le lot 0.9 établit :

- Les huit lots fonctionnent ensemble ; toutes les sessions automatisées passent, hors une anomalie réseau
  bénigne (QA-A01 résiduel, P2, aucun effet mesuré).
- Les chaînes critiques sont vérifiées **en jeu** et plus seulement en logique : conduite et six boîtes, 18 modèles,
  progression et garages, économie et marché (falsifications refusées, vente concurrente, rejeu), courses dans les
  six disciplines avec résultat, récompense et libération, parcours d'arrivée.
- Quatre défauts **bloquants** jamais vus auparavant ont été trouvés et corrigés (courses injouables, annonces
  bloquées, ligne d'essai obstruée, éclairage de nuit inopérant) : preuve que les campagnes en jeu étaient
  nécessaires et qu'il en reste à faire sur les parties non couvertes.

Ce qui empêche une ouverture publique :

1. **Persistance jamais exécutée sur DataStore** : risque de perte ou de doublon de biens non mesuré (QA-D01 à
   D10). Bloquant.
2. **Aucune mesure sur appareils réels ni à 24 joueurs** : objectifs de performance non démontrés (QA-P01 à P09).
3. **Aucun essai humain consigné** depuis le lot 0.1 (ressenti, manette, lisibilité, interfaces) : checklist prête.
4. **Contenu en attente d'approbation** : gamme, véhicules de départ (liste officielle vide), sons non téléversés
   (aucun son en jeu), direction artistique provisoire.
5. Inter-serveurs (marché, matchmaking) jamais exécuté.

Ordre proposé avant ou au début du lot 1.0 :

1. Décisions D1, D2, D4 (gamme, départs, sons) et création de l'expérience de test isolée (R1, R2).
2. Campagne DataStore réelle (§6), puis inter-serveurs.
3. Essais humains (checklist, huit sessions) et mesures sur appareils réels.
4. Lot 1.0 : vérification du périmètre complet contre le CDC et décision GO / NO-GO, sur la base de ces
   résultats.
