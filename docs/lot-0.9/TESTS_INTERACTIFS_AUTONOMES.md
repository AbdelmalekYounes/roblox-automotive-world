# Tests interactifs autonomes — lot 0.9.1

Branche `feat/autonomous-interactive-qa-0.9.1`, créée depuis `2c814d4` (dernier commit du lot 0.9), PR brouillon
[#10](https://github.com/AbdelmalekYounes/roblox-automotive-world/pull/10) vers `feat/integration-qa-0.9`. `main` et les
branches des lots précédents sont intactes ; rien n'est fusionné. **Tous les essais ont tourné dans la VM VMware** ;
le bureau, la souris et le clavier du poste principal n'ont jamais été utilisés. Aucune publication Roblox, aucun
DataStore réel (profils en mémoire, environnement Dev), aucune API de production.

Ce document décrit ce qui a été **exécuté et observé** ; la couverture fonction par fonction est dans
`COUVERTURE_QA.md`, les défauts dans `docs/QA_BACKLOG.md` (§1 et §1 bis). Les rapports bruts des tâches sont dans
`E:\ROBLOX DEV\aw-vm-exchange\jobs\<tâche>\report\` (hors dépôt) : `report.md`, `gui\input-log.txt` (chaque clic et
chaque touche), `gui\named\` (captures nommées), `screenshots\` (écran de la VM toutes les 2 s).

## 1. Ce qui n'a pas été refait, et pourquoi

Les campagnes du lot 0.9 (`20261103-185530`, 649 / 3 ; `20261103-193356`, 41 / 0) couvraient déjà, par les remotes du
jeu et un pilote automatique : conduite, collisions, banc des 18 modèles, économie et marché, six disciplines de course,
monde ouvert et mesures. Elles n'ont **pas** été relancées à l'identique : le lot 0.9.1 ajoute ce qui manquait (vrais
clics et vraies touches, métiers de bout en bout, trajets GPS, social à deux clients, drift noté, captures inspectées).
Elles sont rejouées **une fois**, en fin de lot, comme contrôle de non-régression du code corrigé (§14).

## 2. Capacités d'interaction réellement disponibles

Audit de `docs/VM_TESTS.md`, `tools/vm/` (agent, exécuteur, outil de capture) et `tests/studio/` : jusqu'au lot 0.9,
**aucune entrée clavier/souris n'était simulée** ; les suites appelaient les remotes du jeu et remplaçaient la lecture
du clavier par `VehicleController.setTestInputProvider`.

| Capacité | Disponible ? | Comment | Preuve |
|---|---|---|---|
| Souris (clic) | **Oui, dans la VM** | Pont d'entrées : `SendInput` de Windows, exécuté par `aw-capture.exe` dans la session de la VM | `20261103-195821` : clic reçu par l'événement `Activated` du bouton en 0,30 s |
| Clavier | **Oui, dans la VM** | Même pont ; codes de balayage (VM en AZERTY : codes virtuels → A, W au lieu de Q, Z) | Étalonnage clavier de chaque session : `mode scan retenu (vk : A,W,Y ; scan : Q,Z,Y)` |
| Saisie de texte | Oui | Caractères Unicode | `ui.garage.saisie_texte_reelle` : « Essai GUI 1 » lu dans le champ (`20261103-200648`) |
| Molette | Oui | Défilement des cadres rognés | `ui.arrivee.info_defilement_molette` |
| Sélection de boutons | Oui | Clic au centre calculé (AbsolutePosition + bande supérieure), preuve par `Activated` | Tous les `ui.*` « reçu » |
| Navigation au focus | **Observée, non pilotée** | `GuiService.SelectedObject` relevé à l'ouverture ; touche Entrée testée avec focus | `ui.garage.info_touche_entree_avec_focus` |
| Manette émulée | **Non** | Exigerait l'installation d'un pilote dans la VM (non autorisée par les règles du projet) | — |
| Captures d'écran | Oui | Écran entier toutes les 2 s, et captures nommées de la vue du jeu, reliées à la position et au contexte | `gui\named\` |
| Propriétés de l'interface | Oui | Lecture des instances `PlayerGui` (visibilité, rognage, texte, focus) | Suites `ui*` |
| Deux clients à la fois | **Non (souris/clavier)** | Une seule fenêtre étalonnée ; Studio ouvre une fenêtre par client | Session `social` : remotes du jeu (instrumenté) |

**Garde-fous du pont** (`tools/vm/ScreenCapture.cs`) : actif seulement pour les tâches qui le demandent (`guiInput`,
sessions `ui…`, `-GuiInput`) ; aucune action avant l'étalonnage ; pointeur borné à la vue du jeu (jamais la barre de
Studio, donc jamais « Arrêter ») ; touches limitées (lettres, chiffres, espace, entrée, échap, retour, tabulation,
flèches, `\`, Maj) ; journal de chaque commande. Détails : `docs/VM_TESTS.md`, section « Entrées réelles ».

## 3. Scripts réutilisables

`tests/studio/GuiDriver.luau` (module de test injecté dans le Studio de la VM uniquement) :

| Fonction | Rôle |
|---|---|
| `calibrate()`, `calibrateKeys()` | Étalonnage souris (repères magenta, clic de contrôle) et clavier (codes virtuels ou de balayage) |
| `click(élément, libellé)` | Vrai clic ; attend `Activated` (preuve), sinon « NON reçu » |
| `key`, `keyDown`, `keyUp`, `keyWith` | Appui, maintien, relâchement (conduite au clavier), mode forcé (diagnostic) |
| `type(texte)`, `wheel(cadre, crans)`, `reveal(élément)` | Saisie, molette, défilement réel jusqu'à un élément rogné |
| `findButton`, `findText`, `shown`, `clippedBy`, `present` | Recherche par texte affiché, visibilité réelle (ancêtres, rognage, vue) |
| `shot(nom, contexte)` | Capture nommée reliée à la position du personnage et au contexte |

Sessions (`tests/studio/build-driver.luau`) : `ui` (interfaces, Dev), `ui_marche` (marché, reproduction ciblée),
`ui_monde` (captures du monde ouvert), `metiers` (8 métiers), `gps` / `gps2` (trajets), `drift`, `social` (2 clients).
Lancement : `powershell -ExecutionPolicy Bypass -File tools\vm\host-run.ps1 -NoVmControl [-Place OpenWorld] -Sessions ui -GuiInput`.

## 4. Tâches VM exécutées (Studio `0.745.449`, 2026-11-03)

Le commit est celui de la tête au dépôt de la tâche (`job.json`). Les dernières tâches ont été déposées depuis des
copies de travail figées sur le commit indiqué (`git worktree`), pour pouvoir poursuivre les corrections pendant
l'attente de la VM.

| Tâche | Commit | Place | Sessions | Réussis / échecs | Constat principal |
|---|---|---|---|---|---|
| `195613` | `4d9a1e5` | Dev | `ui` | 7 / 2 | Pont actif (commandes lues ≈ 1 s après l'impression) ; repères couverts par la barre de Roblox : aucun clic reçu, **aucun parcours n'est déclaré** |
| `195821` | `9821f07` | Dev | `ui` | 171 / 20 | **Vrais clics et vraies touches reçus** ; confirmation du premier véhicule hors de vue (QA-F13) |
| `200648` | `e48ec3c` | Dev | `ui`, `metiers` | 196 / 9 | QA-F13 vérifié ; captures inspectées : QA-F14, QA-F15 ; métiers 3 / 8 (véhicule calé contre un mât) |
| `203223` | `d3d2a9a` | Dev | `ui`, `metiers`, `drift`, `social` | 252 / 9 | **Social entièrement réussi** ; prêt après verrouillage refusé ; drift 0 (pilote) ; métiers 3 / 8 |
| `203235` | `d3d2a9a` | Monde ouvert | `gps`, `ui_monde` | 56 / 6 | Fenêtre de migration d'éclairage (QA-F17) ; pont arrêté après 600 captures (défaut de l'outil) |
| `210055` | `4947ec5` | Dev | `ui_marche` | 37 / 0 ¹ | **QA-F16 reproduit par vrai clic** (« Refusée : Demande invalide », annonce toujours listée, capture 006) |
| `213328` | `e1c7207` | Dev | `ui`, `metiers`, `drift`, `lot08` | 266 / 6 | **Drift : score 310** ; métiers 6 / 8 ; cockpit ≥ 10° sur 27 véhicules ; QA-F18 trouvé |
| `220054` | `82731da` | Monde ouvert | `gps`, `ui_monde` | 156 / 6 | **5 arrivées GPS sur 7** ; QA-F20 trouvé ; 32 captures du monde |
| `224247` | `790388e` | Dev | `ui`, `metiers`, `ui_marche` | 262 / 2 376 ² | QA-F16 et QA-F18 vérifiés ; métiers 7 / 8 ; QA-A08 (2 372 erreurs « clamp ») |
| `225749` | `da9cfa2` | Monde ouvert | `gps2` | 38 / 4 | Itinéraire de montagne calculé (QA-F20 vérifié dans le jeu) ; aucune arrivée (pilote immobilisé) |
| `231150` | `9b0eebd` | **invalide** | 16 sessions Dev | (598 / 63) | **Tâche invalide** : deux dépôts dans la même seconde ont partagé ce dossier ; les sessions Dev ont tourné sur la place monde ouvert (zone d'essai absente). Défaut de l'outil hôte, corrigé (`10450e1`) ; résultats **non retenus** |

¹ Le « 0 échec » de `210055` contient **un faux succès du test** (`ui.marche.annonce_retiree_serveur`) : la lecture de
l'état était refusée par le limiteur du serveur et passait pour « aucune annonce ». La capture 006 et le message du pied
prouvent le contraire. Corrigé dans les tests (`82731da` : lectures espacées, lecture refusée = inconnue).
² 2 372 des échecs sont des occurrences d'une même erreur d'exécution (QA-A08), 4 sont des échecs de contrôles.

## 5. Campagne 1 — interfaces parcourues par vrais clics et vraies touches

Session `ui` (tâches `195821`, `200648`, `203223`, `213328`, `224247`), place de développement, profil neuf en mémoire.
Chaque ligne « reçu » signifie : clic réel envoyé dans la VM **et** événement `Activated` déclenché par le moteur sur ce
bouton. Le résultat côté serveur est **lu** (point d'accès de test `AWTestQuery` ou remote « Snapshot » du jeu), jamais
provoqué.

| Écran | Ouverture | Parcouru | Résultat vérifié côté serveur | Fermeture |
|---|---|---|---|---|
| Arrivée (onboarding) | Automatique au premier lancement | 4 × « Suivant », « Choisir », **« Annuler »** (sans effet), « Choisir », « Confirmer », « Suivant », « Entrer dans le monde » | Étapes Welcome → … → Done ; véhicule de départ choisi (`wk_brio`) seulement après confirmation | Fenêtre fermée |
| Garage / collection | Touche **P** | 6 onglets ; sélection d'un exemplaire ; **saisie réelle** du nom de configuration ; « Enregistrer ici » | Solde et véhicules inchangés (aucune action involontaire) | Bouton « Fermer » |
| Personnalisation | Onglet « Préparation » | Onglet affiché, capturé | — (réglages non appliqués : hors d'un garage) | — |
| Propriétés | Onglet « Propriétés » | Onglet affiché, capturé | — | — |
| Économie : métiers | Touche **J** | « Livraison de colis » puis « Abandonner » | Mission créée puis supprimée par le serveur | Touche **Retour** |
| Concession | Invite, **touche E** réelle | Devis → **Annuler** (solde inchangé) → Devis → **Confirmer** | Solde 150 000 → 135 500, véhicules 3 → 4 | « Fermer » |
| Marché | Touche **J**, onglet | Devis de mise en vente → Confirmer → **Retirer l'annonce** | Annonce publiée ; retrait **refusé avant QA-F16**, effectif après (`224247`) | « Fermer » |
| Courses / classements | Touche **K** | 4 onglets, détail d'un parcours, records, tableau drift | Lecture seule | « Fermer » |
| Smartphone | Touche **T** | Paramètres (6 pages), Social, Véhicules, Missions, Guide, Notifications, « ← Retour » | **Modèle de téléphone en main** constaté par le serveur ; réglage « Niveau du HUD » enregistré côté serveur | Bouton « × » ; téléphone rangé |
| Paramètres | Téléphone → Paramètres | Niveau du HUD changé par un clic, puis remis | Préférences relues côté serveur | « ← Retour » |
| Carte et GPS | Touche **M** | Zoom +, choix d'un lieu à 230 m, « Définir comme destination » | Guidage affiché dans le HUD | « Fermer » ; touche **X** efface la destination |
| Mode photo | Touche O : **jamais reçue dans Studio** ; téléphone → Photo → « Ouvrir le mode photo » | Zoom, filtre, « Quitter » | Caméra restaurée (`Custom`) | « Quitter » |
| HUD | Touche **H** | Trois niveaux | Notification « Niveau du HUD » | — |
| Passage à la conduite | Invite, **touche E** | Accélérateur **W** réel (15–16 km/h), garage refusé en roulant, téléphone en mode rapide, freinage **S**, frein à main **Espace**, sortie **F** | Aucune validation en roulant ; menu ouvert à l'arrêt : accélérateur ignoré et (après QA-F18) véhicule immobile | — |

Constats sur les comportements demandés :

- **Focus** : à l'ouverture par touche, le focus de navigation est posé sur l'onglet courant (garage, économie,
  courses) même à la souris ; il reste visible (contour) sur un onglet après un clic sur un autre. La touche Entrée
  avec ce focus n'a **aucun effet côté serveur** (`ui.garage.entree_sans_effet_serveur`). Observation d'ergonomie
  laissée au propriétaire, non corrigée (hors périmètre sans arbitrage).
- **Confirmations** : achat, mise en vente, choix du véhicule : jamais d'effet avant « Confirmer » ; « Annuler » sans
  effet (vérifié côté serveur).
- **Erreurs** : affichées au pied du panneau (« Refusée : … ») ; un bouton grisé cliqué ne déclenche rien.
- **Actions involontaires** : solde et collection inchangés après les parcours de consultation.
- **Touche O** : le témoin L arrive au jeu, O n'arrive jamais (ni par code virtuel, ni par code de balayage) :
  interception par Studio présumée (raccourci de zoom de la caméra I/O). Classée **limite connue** ; à vérifier dans le
  client Roblox par un humain. Le chemin par le téléphone fonctionne.

## 6. Campagne 2 — les huit métiers par un pilote

Session `metiers` (Dev). La mission est générée par le vrai service ; chaque étape est validée par le serveur à partir
de ses échantillons ; le versement est le sien. **Remplacé (signalé)** : la lecture clavier (le pilote calcule
accélérateur, frein, direction) ; l'embarquement par l'invite est activé par script. Démarrage par la demande normale
de l'interface (`StartMission`, chemin vérifié par vrai clic en §5).

| Métier | Véhicule | Exécution retenue | Crédits / qualité | Résultat dans les 4 tâches (`200648`, `203223`, `213328`, `224247`) |
|---|---|---|---|---|
| Livraison de colis | personnel | `224247` : 3 étapes, 62 s | 158 / 1,00 | réussi, réussi, réussi, réussi |
| Taxi / VTC | personnel | `224247` : 2 étapes, 34 s | 118 / 1,00 | réussi, délai, délai, réussi |
| Pièces spéciales | personnel | `224247` : 45 s | 137 / 0,40 (cargaison fragile, freinages brusques) | délai, délai, réussi, réussi |
| Assistance routière | personnel | `224247` : arrêt puis **intervention à pied**, 24 s | 129 / 1,00 | délai, délai, réussi, réussi |
| Stationnement et slalom | personnel | `213328` : 5 portes + créneau, 139 s | 169 / 0,47 | délai, délai, réussi, délai |
| Exploration tout-terrain | personnel | `213328` : 3 points, 53 s | 146 / 1,00 | délai, délai, réussi, réussi |
| Voiturier et convoyage | **fourni** | `224247` : stationnement, 41 s | 176 / 0,82 | délai, réussi, délai, réussi |
| Essais automobiles | **fourni** | `224247` : 0–100 km/h puis freinage, 32 s | 229 / 1,00 | réussi, réussi, réussi, réussi |

Les « délais » des deux premières tâches viennent du pilote (véhicule calé contre un mât, puis immobilisé par les
dégâts) ; le pilote a été amélioré entre chaque tâche (§11), jamais la physique ni les règles des missions.

**Les huit métiers ont chacun été terminés et payés au moins une fois** ; la meilleure tâche en compte 7 sur 8
(`224247`). Les échecs restants sont des **délais dépassés du pilote** (calé contre les installations de la zone
d'essai, véhicule endommagé), jamais une validation forcée. Interventions du pilote comptées dans le rapport (remise
sur roues, descente et remontée). Monde ouvert : **NON TESTÉ** (place de développement seulement).

## 7. Campagne 3 — GPS et sept zones, en conduite réelle

Sessions `gps` / `gps2` (monde ouvert). Aucune téléportation pendant les trajets : le véhicule est posé **une fois**
au départ sur une rue proche de l'apparition (signalé), puis le pilote suit les points de l'itinéraire calculé par le
GPS du jeu ; l'arrivée est celle que **constate le GPS** (25 m). Destination posée par la fonction du GPS (le choix par
vrai clic sur la carte est vérifié en §5).

`20261103-220054` (commit `82731da`) :

| Trajet | Itinéraire | Guidage | Arrivée |
|---|---|---|---|
| 1 Banlieues | 2,5 km, 5 manœuvres, 977 m ≥ 90 km/h | « Straight dans 184 m (Boulevard Extérieur) » | **Oui**, 241 s, écart 24 m |
| 2 Métropole | 3,8 km, 8 manœuvres | « Straight dans 127 m (Avenue de la Plaine) » | **Oui**, 490 s ; sortie volontaire **non obtenue** (écart 2 m) |
| 3 Littoral | 3,8 km, 1 550 m ≥ 90 km/h | Manœuvre annoncée | **Oui**, 335 s |
| 4 Docks | 6,5 km dont **4,75 km ≥ 90 km/h** (voies rapides, autoroute) | Manœuvre annoncée | **Oui**, 538 s |
| 5 Montagnes | **refusé « Invalid »** | — | Défaut **QA-F20** (corrigé `da9cfa2`) |
| 6 Campagne | 7,9 km, 5,1 km ≥ 90 km/h | Manœuvre annoncée | **Oui**, 530 s |
| 7 Motorsport | 8,4 km | Manœuvre annoncée | Non : véhicule immobilisé (dégâts) après 90 s, trajet abandonné |

Zones traversées : Banlieues, Métropole, Littoral, Docks, Campagne (5 / 7). Recalcul après sortie d'itinéraire : une
sortie dans un champ a été capturée lors de `203235` (capture 019), mais le rapport du client n'est pas arrivé
(session trop longue) : **non mesuré** ; test refait du côté dégagé dans `gps2`. 
**`gps2` (`20261103-225749`, commit `da9cfa2`, après QA-F20)** : l'itinéraire vers la destination de montagne,
refusé « Invalid » avant la correction, est **calculé dans le jeu** (7,5 km, 3 manœuvres, 3,3 km ≥ 90 km/h) ; celui
du Motorsport aussi (4,9 km). Guidage affiché (« Dans 860 m : Tournez à gauche — Voie rapide de l'Ouest », capture 006)
et notification **« Recalcul de l'itinéraire… »** observée (capture 016). **Aucune des deux arrivées** : véhicule
endommagé dès les premières minutes puis immobilisé en Métropole derrière un véhicule arrêté (le pilote freine derrière
un obstacle mais ne dépasse pas ; 18 et 48 dégagements), trajets abandonnés après 90 s d'immobilisation.

Bilan des sept zones : **5 zones atteintes en conduite réelle** (Banlieues, Métropole, Littoral, Docks, Campagne) ;
Montagnes et Motorsport : itinéraires calculés et guidage affiché, **arrivée NON OBTENUE** (limite du pilote, pas du
jeu). Recalcul après sortie : observé (notification, capture 016), **non mesuré** par le contrôle automatique.

## 8. Campagne 4 — social et permissions à deux clients

Session `social` (`20261103-203223`), deux clients Studio. Demandes par les remotes du jeu, celles qu'envoient les
boutons du téléphone et du garage (**instrumenté** : le pont ne vise qu'une fenêtre). **Entièrement réussie.**

- Groupe : invitation retirée avant réponse (l'ancienne est inutilisable : `GroupInviteExpired`), nouvelle invitation
  acceptée, groupe à deux.
- Position : partagée par le joueur 1 → reçue par le joueur 2 (**écart 0,0 m**) ; coupée → plus reçue ; la position du
  joueur 2, qui ne partageait pas, n'est **jamais** arrivée chez le joueur 1.
- Propriété : invitation « visite » seule → **conduite refusée** ; « visite + conduite » → **véhicule prêté conduit**
  (13 km/h) ; droit retiré en roulant → arrêt sûr puis **descente** ; nouvelle conduite refusée.
- Départ du groupe, puis dissolution.
- **Confidentialité** : les 79 messages (9 KB) reçus par le joueur 2 et les attributs répliqués du joueur 1 ont été
  examinés côté serveur : ni le solde du joueur 1 (rendu unique par un achat), ni l'un de ses 3 exemplaires.

## 9. Campagne 5 — drift noté et prêt après verrouillage

Session `drift` (`20261103-213328`) : épreuve **officielle** DEV-DRIFT avec le véhicule personnel P-01 (propulsion,
sans aide), départ rejoint en roulant. Pilote de dérive (frein à main, accélérateur, contre-braquage) : 25 lancements,
angle maximal 72°, 11,7 s de dérive ≥ 12° à ≥ 30 km/h (mesure client indicative). **Score 310 calculé par le serveur**
(`DriftScoring`, échantillons serveur ; le client ne transmet aucun score). Crédits 0 (versement « Pending » au relevé).

Demande « prêt » envoyée **après** le verrouillage : `Rejected / RaceAlreadyLocked` ; désinscription refusée de même ;
engagement intact, épreuve poursuivie jusqu'au résultat (`203223` et `213328`).

## 10. Campagne 6 — captures inspectées

Captures nommées de la vue du jeu (pleine résolution), relues une à une ; chacune est reliée dans le rapport de sa tâche
à la position du personnage, au contexte (onglet, zone, heure, météo) et à la version (`DEV 0.4.0-dev`, CdC 1.0).

| Sujet | Captures | Constat |
|---|---|---|
| Arrivée | `195821` 007, `200648` 007 | Confirmation hors de vue (QA-F13) → visible après correction |
| HUD, mini-carte | `200648` 053–056, `220054` gps_* | Lisibles ; tableau réduit en vue cockpit, comme prévu |
| Cockpit | `200648` 055, `220054` 081 | Volant devant la route (QA-F15) → sous la ligne de visée après correction |
| Téléphone | `200648` 038–048, `220054` 091 | Boutons en carrés vides (QA-F14) → « + » et « × » ; **téléphone tenu bras baissé** (QA-U10, diagnostic en cours) |
| Carte, GPS | `200648` 049–052, `220054` 083–084 | Carte et destination lisibles |
| Garages, concessions, stations | `220054` 067–074 | Bâtiments présents, accès lisibles |
| Carrosseries | `220054` 075–078 | Prototype d'essai lisible |
| Décor des 7 zones | `220054` 060–066 | **Fenêtre d'arrivée restée devant une partie du décor** (test : corrigé, introduction passée par clic) |
| Nuit, pluie | `220054` 085–090 | Nuit très sombre hors des halos des lampadaires (12 sources au plus en qualité moyenne) : **jugement laissé au propriétaire** |
| Panneaux de course | `213328` drift_* (non enregistrées : défaut de l'outil, corrigé) ; `200648` 031–037 | Panneau lisible |
| Mode photo | `224247` photo_* | Panneau et filtre |
| Chargement de mission | Écran `213328` 0158 | **Passager au-dessus du toit** (QA-F19, corrigé) |
| Fenêtre de Studio | `203235` (toutes) | Fenêtre de migration d'éclairage (QA-F17, corrigé) |

## 11. Défauts trouvés et corrigés pendant le lot

| Id | Gravité | Défaut | Trouvé par | Correction | Régression |
|---|---|---|---|---|---|
| QA-F13 | P2 | Confirmation du premier véhicule hors de vue ; pied « Fait. » périmé (arrivée, devis) | Vrais clics (`195821`) | `e48ec3c`, `c626686` | Lune ; vrais clics (`200648`) |
| QA-F14 | P3 | Signes absents de la police (« ⤢ », « ✕ », « ✓ ») | Capture 038 | `a008dea` | Lune ; capture 091 |
| QA-F15 | P2 | Volant à hauteur des yeux en vue cockpit (1,1° de marge au pire) | Capture 055 | `a008dea` (`CockpitGeometry`) | Lune (18 modèles) ; VM ≥ 10° sur 27 véhicules |
| QA-F16 | P1 | « Retirer l'annonce » toujours refusé | Lecture de code, puis vrai clic | `b34c38a` | Lune (échoue sans) ; vrai clic (`224247`) |
| QA-F17 | P2 | Éclairage « Compatibility » : fenêtre modale de Studio sur le jeu | Captures `203235` | `82731da` | Lune ; `220054` |
| QA-F18 | P2 | Menu ouvert à l'arrêt : véhicule qui rampe, panneau refermé | Vraies touches (`213328`) | `790388e` | Lune (échoue sans) ; `224247` |
| QA-F19 | P3 | Passager du taxi au-dessus du toit | Capture d'écran | `790388e` | Lune |
| QA-F20 | P2 | Destination au milieu d'une longue route refusée ; fin en ligne droite à travers le relief | Trajet réel (`220054`) | `da9cfa2` | Lune (16 routes, échoue sans) |
| QA-A08 | P1 | NaN dans la simulation : 2 372 erreurs « clamp », simulation figée | `224247` | `9b0eebd` (effet neutralisé) | Lune ; **cause première non établie : anomalie ouverte** |

Défauts **du test** corrigés (jamais présentés comme défauts du jeu) : repères d'étalonnage couverts par la barre de
Roblox ; recherche de l'écran photo figée ; destination trop proche ; véhicule à boîte manuelle laissé au point mort ;
pilote bloqué contre des mâts et des installations (rayons ajoutés) ; arrêt d'étape exigé plus près que le rayon réel ;
pont arrêté après 600 captures et commandes ignorées entre sessions (outil) ; lectures refusées par le limiteur prises
pour un état vide (faux succès §4 ¹).

## 12. Tests impossibles ou partiels

| Demande | Pourquoi | Alternative livrée |
|---|---|---|
| Manette émulée | Pilote système à installer dans la VM (interdit sans accord) | Focus observé ; navigation à la manette : humain (QA-U03) |
| Vrais clics à deux clients | Une seule fenêtre étalonnée à la fois | Remotes du jeu, signalé comme instrumenté |
| Touche O (mode photo) | N'atteint jamais le jeu dans Studio | Ouverture par le téléphone ; vérification humaine dans le client Roblox |
| Métiers et GPS sans pilote | Conduite humaine impossible dans la VM | Pilote automatique (simulation, collisions et validation réelles) |
| Ressenti, lisibilité, son | Jugement humain | `CHECKLIST_TESTS_HUMAINS.md` |
| DataStore réel, publication | Interdit par le lot | Profils en mémoire |

## 13. Dépendances restantes avant la V1.0

Inchangées par ce lot (voir `DEPENDANCES_VALIDATION_EXTERNE.md`) : expérience de test isolée pour les DataStores et
les services inter-serveurs, essais humains (checklist), performances sur appareils réels, arbitrages du propriétaire.
Ajouts du lot : origine du NaN (QA-A08), bras du téléphone (QA-U10), touche O dans le client Roblox, nuit très
sombre (jugement), focus de navigation laissé sur un onglet (ergonomie).

## 14. Non-régression

- Hors Studio, 2026-11-03 23:01, commit `9b0eebd` : `scripts\verify.ps1 -RobloxTypes .tooling\globalTypes.d.luau` —
  Rojo (deux places), Selene, StyLua, pilote Studio, **Lune 340 / 0**, carte déterministe, pytest 14, luau-lsp strict
  0 erreur.
- VM, code final `9b0eebd` : sessions historiques et des lots 0.4 à 0.9.1 sur la place de développement, `monde`,
  `perf`, `ui_monde`, `gps` sur le monde ouvert : résultats au §14 bis, complétés en fin de lot.
