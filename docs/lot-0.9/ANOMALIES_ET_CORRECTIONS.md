# Anomalies et corrections — lot 0.9

Bilan des anomalies de la version intégrée (lots 0.1 à 0.8). Chaque correction suit la démarche du brief :
comportement initial, conditions de reproduction, modification ciblée, contrôle de régression, vérification,
résultat réellement obtenu. Les tâches VM (`20261103-hhmmss`) sont décrites dans
`RAPPORT_VALIDATION_GLOBALE.md` §2 ; leurs rapports sont dans `E:\ROBLOX DEV\aw-vm-exchange\jobs\` (hors dépôt).

## 1. Défauts trouvés et corrigés pendant le lot 0.9

| Id | Lot d'origine | Système | Gravité | Comportement initial | Reproduction | Correction | Régression | Résultat après |
|---|---|---|---|---|---|---|---|---|
| QA-F05 | 0.6 | Courses / zone d'essai | **P1** | Le mât **solide** de l'arbre de départ du drag était posé au milieu de la ligne droite d'essai : toute voiture partant de (0, 0) cap au nord butait dessus (0 km/h, moteur au rupteur) ; un joueur pouvait aussi le percuter | `20261103-151033`, `lot02` : 0–100 km/h impossible pour les 6 boîtes, essais de freinage, panne, caméras faussés | `708331e` : arbre déplacé en bord de chaussée | Lune (contrôle du code construit) ; VM `lot02` | `20261103-153933`, `-155713` : `lot02` sans ces échecs |
| QA-F06 | 0.6 | Zone d'essai (conflit de tracé) | P3 (test) | L'essai ESP du lot 0.2 partait sur un poteau du portique de départ du rallye d'essai ; dérive nulle mesurée | `20261103-153933`, `lot02` : `esp_intervient_en_survirage`, `esp_reduit_la_derive` | `dcf47c8` : essai décalé de 70 st à l'ouest (zone dégagée) ; le tracé du rallye n'est pas modifié | VM `lot02` | `20261103-155713` : `lot02` entièrement réussi |
| QA-F07 | 0.6 | **Courses** | **P1** | **Aucune inscription possible en jeu** : `RaceService` exigeait un `VehicleSeat` alors que le siège conducteur est un `Seat` depuis le lot 0.1 (`RaceDriveToJoin`). Jamais vu : les courses n'avaient jamais été jouées dans Studio | `20261103-155713`, nouvelle session `lot06` : toutes les inscriptions refusées | `38e3b3b` : siège nommé `DriverSeat`, classe `Seat` ou `VehicleSeat` (la place passager reste exclue) | Lune (contrôle statique) ; VM `lot06` | `20261103-170323` : épreuve officielle complète (inscription, grille, départ, arrivée en 41,8 s, récompense +78) |
| QA-F08 | 0.5 | **Marché** | **P1** | Une mise en vente dont la réservation était appliquée mais pas encore écrite (« Pending », budget d'écriture par profil) n'était jamais publiée : exemplaire réservé pour une annonce introuvable, invendable jusqu'à l'échéance | `20261103-155713`, `lot05` : acheteur → `ListingUnknown` | `e097815` : annonce créée aussi en « Pending » (l'achat revérifie la réservation du vendeur à chaque étape) | Lune : **échoue sans la correction, passe avec** | `20261103-163722` : deux achats simultanés, un seul aboutit ; vendeur crédité du prix − 5 % (vue serveur) |
| QA-F09 | 0.8 | Parcours d'arrivée | **P1** | La fenêtre d'arrivée, ouverte d'elle-même, imposait le focus sur son premier bouton : gel d'un client Studio à deux joueurs | Lot 0.8 : 11 échecs `lot04` sur 12 | `099822b` (lot 0.8) : focus à la manette seulement | VM `lot04` | 3 réussites sur 3 (lot 0.8), puis `20261103-151033` (`lot04` réussi) |
| QA-F10 | 0.5 | Stations | P2 | Aucune limite d'occupation : une station acceptait plus de pleins simultanés qu'elle n'a de pompes ou de bornes (lacune signalée au lot 0.5) | Lecture du code | `12b632e` : `StationRules` (une place par session, capacité du lieu, 2 par défaut en zone d'essai, refus `StationFull`) | Lune | Lune 7 vérifications ; en jeu : **NON TESTÉ** à plusieurs joueurs |
| QA-F12 | 0.8 | Rendu de nuit, niveau de détail | P2 | `VehicleLights` et `DetailLod` cherchaient l'habillage une seule fois au démarrage du client, avant son arrivée par le streaming : aucun lampadaire allumé de nuit, habillage jamais masqué en qualité basse | `20261103-174932`, `perf` : 0 source active de nuit | `f2fe391` : recherche répétée tant que l'habillage manque | VM `perf` (sources actives relevées) | `20261103-175506` : 12 sources de nuit (plafond de la qualité moyenne) |
| QA-F11 | 0.5 | Métiers | P3 | Passagers, colis et pièces non représentés (repère d'étape seulement) | Rapport du lot 0.5 | `12b632e` : `MissionCargo` + pièces décoratives soudées au véhicule conduit (sans masse ni collision) | Lune | Rendu en jeu : **NON TESTÉ** |

## 2. Faux défauts : causes trouvées dans les essais automatisés

| Id | Symptôme | Cause établie | Correction (tests) | Résultat |
|---|---|---|---|---|
| **QA-A02** (lot 0.2) | « Sortie non effective » après une collision, étape suivante faussée | La fonction d'arrêt du scénario maintenait « freiner » à l'arrêt : une boîte automatique engage alors la marche arrière (arbitrage A3) ; la voiture repartait en arrière (21 à 35 km/h mesurés) et la sortie était **légitimement refusée** (`ExitTooFast`, seuil 20 km/h) | `dcf47c8` : frein relâché sous 3 km/h, puis frein à main | `20261103-155713` : 4 sessions de collision (2 × 2), **aucune** sortie non effective |
| QA-A01 (partie « réembarquement ») | Véhicule immobile chez son conducteur après un repositionnement par le serveur de test, puis correction « Teleport » | Conséquence de QA-A02 : conducteur resté à bord, puis véhicule **occupé** déplacé par le serveur de test → validation (téléportation) → réattribution | Même correction | `20261103-155713` : **aucune** correction « Teleport », aucun essai sans contact (limite connue jamais déclenchée) |
| — | HUD absent au relevé (`client.session_conduite`, multijoueur et latence) | Le tableau s'affiche à la première image de conduite ; le relevé était immédiat | `708331e` : attente jusqu'à 3 s | `20261103-153933` : réussi |
| — | Courses : inscription refusée (« MenuWhileMoving »), drag sans fin, dernier arrivé « en course » | Pilote automatique du test : même piège « freiner à l'arrêt » ; aucun point de passage publié pour le drag ; la fin d'épreuve arrive dans le message « Results » (lu par le panneau du jeu, ignoré par le test) | `42434c2`, `28816d9`, `025717c`, `737d081`, `855b93b` | `20261103-184407` : sprint à deux et drag jusqu'au résultat |
| — | Banc : 4 boîtes manuelles immobiles, embarquements ratés au hasard | Test : première non engagée ; activation scriptée d'une invite parfois ignorée (déjà connu des sessions historiques) | `38e3b3b`, `42434c2` : première engagée, trois tentatives | `20261103-170323` : **18 / 18** modèles mesurés (20 tentatives pour 18) |

## 3. Anomalies encore ouvertes

| Id | Système | Gravité réelle | Type | Probabilité | Impact joueur | Exploitation | Diagnostic au lot 0.9 | Statut |
|---|---|---|---|---|---|---|---|---|
| QA-A01 (résiduel) | Propriété réseau | **P2** (était P1) | Intermittente | 0 à 2 « réattribution (1) » par session de collision ; 1 écart d'attribut sur ≈ 2 000 contrôles dans 2 sessions sur 4 | Aucun effet mesuré (corrigé à la première vérification, pas de correction de position) | Nul (journal, jamais de sanction) | Cause exacte non établie : réattribution automatique du moteur au contact d'assemblages ; le symptôme visible du lot 0.1 venait du scénario (§2) | **Ouverte**, surveillée |
| QA-A03 | Attribut de simulation | P3 | Intermittente | ≈ 1 sur 2 000 contrôles | Aucun observé | Nul | Même famille que QA-A01 | Ouverte |
| QA-A04 / A07 | Collisions entre joueurs | P2 | Limitation technique | Dispersion des poussées (conduit 2,7–8,4 st, garé 1,9–8,4 st selon les essais) | Poussée variable entre essais | Faible | Arbitrage moteur Roblox des contacts entre assemblages de propriétaires différents | Limite connue |
| QA-A05 | Véhicule ancré | P3 | Limitation (cas de test) | Provoqué par le test seulement | — | — | — | Limite connue |
| QA-A06 | Démarrage | P3 | Non reproduite | 0 occurrence depuis le lot 0.1 | — | — | — | Ouverte, non reproduite |

## 4. Classement du registre QA (131 lignes au début du lot)

Types : **AC** anomalie confirmée, **AI** intermittente, **LT** limitation technique, **FP** fonctionnalité
partielle, **NE** test non exécuté, **AP** arbitrage du propriétaire, **DP** déclaration du propriétaire.
Criticité réelle : P1 (bloque, fausse des données ou des résultats), P2 (visible), P3 (confort). Coût : S (≤ 1 j),
M (quelques jours), L (dépend d'un tiers ou d'un lot).

| Famille | Lignes | Type | Criticité | Probabilité | Impact | Exploitation | Dépendances | Coût | État au lot 0.9 |
|---|---|---|---|---|---|---|---|---|---|
| Anomalies | QA-A01 à A07 | AI / LT | P2–P3 | §3 | §3 | Nul | Moteur Roblox | M | §3 |
| Défauts corrigés | QA-F01 à F11 | AC | P1–P3 | — | — | — | — | — | Corrigés (F05 à F11 au lot 0.9, §1) |
| Essais humains lot 0.1 | QA-H01 à H06 | DP | P1–P3 | — | — | — | Propriétaire | — | **Déclarés** (9 vérifications annoncées, 7 listées) |
| Essais humains lots 0.2 à 0.4 | QA-H07 à H20 | NE | P1–P3 | — | Ressenti, lisibilité | — | Propriétaire, matériel réel | S chacun | Checklist (`CHECKLIST_TESTS_HUMAINS.md`) |
| Studio lot 0.3 | QA-S01 à S16 | NE / FP | P1–P3 | — | — | — | VM | S | S01, S02, S16 faits ; partiels mis à jour par `monde` (voir rapport) |
| DataStore | QA-D01 à D10 | NE | P1–P2 | — | Perte ou doublon de données | Élevée si défaut | **Expérience de test isolée (R1)** | M | Simulations mémoire couvertes (rapport §6) ; réel NON TESTÉ |
| Progression lot 0.4 | QA-S17 à S22 | NE / FP | P1–P2 | — | — | — | VM | S | `lot04` réussi ; S18, S19 partiels |
| Économie | QA-E01 à E14 | NE / FP / AP | P1–P3 | — | Intégrité économique | Élevée | VM, R1, propriétaire (équilibrage) | M | `lot05` : falsifications, marché, stations, pièces, mission (début / abandon) vérifiés en jeu ; métiers de bout en bout NON TESTÉS (E04, E05) |
| Courses | QA-R01 à R17 | NE / FP | P1–P3 | — | Résultats officiels | Élevée | VM, R1 (inter-serveurs) | M | `lot06` : épreuve officielle de bout en bout vérifiée en jeu ; voir rapport pour les cinq autres disciplines |
| Interface lot 0.7 | QA-U01 à U13 | NE | P1–P2 | — | Ergonomie, confidentialité | Moyenne (U08) | Humain, R1 | S–M | Inchangé (humain) |
| Lot 0.8 | QA-V01 à V15 | NE / AP | P1–P3 | — | Art, son, arrivée | Faible | Propriétaire, téléversement | S–L | V02 : banc 18 / 18 en jeu ; V08 : parcours d'arrivée vérifié en jeu (Dev) ; V07 : photo partiellement (à pied) |
| Performance | QA-P01 à P09 | NE | P1–P3 | — | Fluidité | — | Matériel de référence (M1), R4 | M | Outillage `perf` livré ; mesures VM indicatives (`PERFORMANCES.md`) |
