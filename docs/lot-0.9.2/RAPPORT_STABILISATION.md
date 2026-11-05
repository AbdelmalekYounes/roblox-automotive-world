# Rapport de stabilisation — lot 0.9.2

Branche `feat/final-stabilization-0.9.2`, créée depuis `bf81465` (tête de la PR #10, lot 0.9.1), PR brouillon
[#11](https://github.com/AbdelmalekYounes/roblox-automotive-world/pull/11) vers `feat/autonomous-interactive-qa-0.9.1`.
`main` intacte ; rien n'est fusionné. **La V1.0 n'est pas commencée** ; aucune refonte graphique (le système de
conception est traité à part). Tous les essais Studio dans la VM ; aucune publication, aucun DataStore réel.

## 1. QA-A08 — valeurs non finies : cause établie et corrigée

### 1.1 Conditions de l'incident (tâche VM `20261103-224247`)

Session `metiers`, véhicule personnel **P-01** (boîte automatique à **convertisseur de couple**), trains avant
endommagés, plaqué contre une installation du parcours de précision ; le pilote alternait marche avant et marche
arrière (« dégagement »). Les 2 372 erreurs `TireModel.stopClamp` ont commencé 0,33 s après un passage en marche
arrière (21:53:45,34 → 45,67) et ont cessé quand le pilote est descendu puis remonté (état de simulation recréé).

### 1.2 Recherche

- Outil `tests/lune/tools/nan-hunt.luau` (scénarios `tests/lune/NanHunt.luau`) : exploration **reproductible** de
  `VehicleDynamics.step` — dégâts dans les bornes de `DamageModel`, contacts d'un véhicule plaqué, marches avant et
  arrière, pas de temps réels du simulateur (1 ms à 1/20 s, `VehicleSimulator.MAX_STEP_S`), à-coups de collision,
  calages, passages, panne d'énergie ; arrêt à la première valeur non finie avec l'historique des six pas.
- Premiers essais (270 000 pas, sans à-coups ni événements) : aucune valeur non finie.
- Avec à-coups et événements : divergences, **uniquement sur les boîtes à convertisseur** (P-01, `wk_mistral`,
  `wk_vigie`) ; jamais sur les boîtes manuelles (P-02, Brio) ni l'électrique (P-03). Toujours véhicule plaqué.
- Pistes écartées à la lecture : repère de contact du simulateur (déjà protégé : sphère limitée aux faces tournées
  vers le haut, axe avant de secours), pas de temps (borné), sorties de `DamageModel` (bornées), entrées réseau
  (`InputCodec` refuse les valeurs non finies).

### 1.3 Cause

Le couple du convertisseur (`Transmission.converterTorques`) croît comme le **carré** des vitesses
(`k · max(|ωp|, |ωt|) · (ωp − ωt)`) et était intégré **explicitement** dans les sous-pas, sans borne de stabilité.
Roues motrices lancées alors que le véhicule est plaqué (−133 rad/s contre un moteur à 542 rad/s : la turbine tourne
plus vite que la pompe), le couple calculé dépasse en un sous-pas l'écart qu'il doit réduire et l'inverse en
l'amplifiant ; comme il croît avec cet écart, la divergence s'emballe : −133 → −1,48·10⁶ → −4,9·10⁶⁹ rad/s → ∞ →
NaN (graine 8, scénario 83, P-01). `stopClamp` n'était que le premier calcul à lever une erreur. Le scénario de
l'incident (plaqué, alternances avant / arrière, roues motrices qui patinent) réunit exactement ces conditions.

### 1.4 Correction (`ebe4714`)

Borne de stabilité du schéma explicite (`VehicleDynamics.ConverterStabilityFactor = 1,8`) : en un sous-pas, l'écart
pompe/turbine peut changer de signe (dépassement que le schéma faisait déjà) mais son amplitude ne peut plus croître
(au plus 0,8 fois l'écart). Le modèle continu du convertisseur n'est pas modifié. Une première borne plus stricte
(« au plus annuler l'écart ») a été **rejetée** : le test montrait qu'elle agissait au départ arrêté de `wk_mistral`
(670 sous-pas), donc qu'elle modifiait la conduite normale.

Protection défensive du lot 0.9.1 **conservée** (neutralisation comptée et annoncée, `stopClamp` sans erreur).

### 1.5 Preuves et tests de régression (`tests/lune/specs/Lot092Stabilization.luau`)

| Vérification | Avant (`bf81465`) | Après |
|---|---|---|
| 13 scénarios fixés (P-01, `wk_mistral`) | ∞ puis NaN (13 / 13) | finis, **0 neutralisation**, borne active |
| Exploration élargie (tous les modèles, 60 scénarios) | — | 0 valeur non finie |
| 4 500 scénarios (5 modèles à convertisseur × 3 graines × 300) | divergences sur 3 modèles | **0** |
| Conduite normale (7 modèles à convertisseur : départ, freinage, marche arrière, reprise) | — | **0 sous-pas limité** |
| Entrées du conducteur et énergie (`InputCodec`) | — | NaN / ∞ refusés |
| Portefeuille (`Wallet`) | — | crédit NaN / ∞ refusé, solde intact, profil valide |

Non vérifié : reproduction **dans le moteur** de l'incident exact (conditions de patinage et de collision non
rejouables à l'identique) ; contrôle en jeu : aucune neutralisation relevée dans les campagnes VM du lot (§7).

## 2. QA-A09 — virage du joueur 2 après la marche arrière : erreur du scénario de test

Trajectoire tracée toutes les 0,25 s (session `latence`, tâche `20261104-020328`, 1 échec sur 6 sessions) :
le véhicule du joueur 2 (plot à x = 10,1 m) termine le freinage à x ≈ 8,0 m (dérive d'environ 2 m), recule jusqu'à
z = −180 m (rapport R, 28 km/h au plus), puis l'élan des virages l'emmène vers le nord : **à (8,2 ; −199,8) m et
37,5 km/h, choc frontal confirmé par le serveur contre le poteau droit du portique d'arrivée du drag d'essai**
(7,6 ; −204 m ; `Δv 13,6 m/s`), puis immobilisation contre le poteau : virage mesuré 0,0° (ou −148° quand le choc
le fait pivoter).

- Le même choc figure dans toutes les tâches où l'échec apparaît, y compris avec le code du lot 0.9 (`20261104-011801`).
- Boîte (R puis 1), commandes, propriété réseau et latence : conformes dans la trace ; aucune erreur.
- **Classement : erreur du scénario de test** (essais du lot 0.1 dont la ligne croise, à 2 m près, une installation
  du lot 0.6). Ce n'est pas un défaut de conduite.
- Correction du test (`9715443`) : pendant l'élan, le véhicule tient la ligne de son plot (correction de direction
  douce), comme un conducteur ; la mesure du virage est inchangée.
- Vérification (tâche `20261104-031015`, `a089a03`, 3 × `multijoueur` + 3 × `latence`) : ligne tenue (écart
  0,05 à 0,08 m) ; le joueur 2 réussit ses virages dans les 6 sessions, mais le **joueur 1** échoue 2 fois : la
  trace montre le virage à droite commencé à z ≈ −200 m qui l'envoie sur le poteau **gauche** du même portique
  (−7,6 ; −204 m ; serveur : `PortiqueArriveePoteau`, Δv 12,8 m/s). Même erreur de scénario, de l'autre côté.
- Seconde correction du test (`6479c2e`) : le virage commence 8 m après les poteaux d'installation situés devant
  (moins de 15 m de la ligne), vitesse maintenue vers 40 km/h jusque-là.
- Vérification (tâche `20261104-035727`, `6479c2e`, 2026-11-04 03:57, 3 × `multijoueur` + 3 × `latence`) :
  **24 virages réussis sur 24** (6 sessions × 2 joueurs × 2 virages), poteaux dépassés avant le virage dans les
  12 cas (`elan_poteaux_depasses`). Campagne finale (`20261104-040910`) : `multijoueur` et `latence` sans échec.
- Aucune modification du jeu pour QA-A09.

## 3. Moteur calé définitivement sur boîte automatique (QA-A12) : défaut de jeu établi et corrigé

### 3.1 Constat (tâche VM `20261104-021402`, session `gps2`, code `9715443`)

À 2,7 km du départ vers Motorsport, le véhicule du pilote GPS (P-01, automatique à convertisseur) percute un
poteau de feu (serveur : `Choc confirmé … zone Left, Δv 24.9 m/s, niveau 3, mécanique true, obstacle FeuPoteau`)
puis reste immobile 90 s malgré 10 dégagements ; le HUD affiche « Direction endommagée • Moteur calé » (captures
`006` et `007`). Les deux trajets restants partent de ce point et sont abandonnés.

### 3.2 La borne du convertisseur (§1.4) n'y est pour rien

Banc `tests/lune/tools/stall-impact.luau` : 7 modèles à convertisseur × 2 accélérations × 2 durées d'élan × 2 états
du moteur × (choc sec, freinage au choc, rebond de 5 m/s), chaque essai rejoué **avec la borne et avec une copie du
module sans borne** : 224 essais, **0 différence** de calage, **0 activation** de la borne pendant les chocs.
Le calage est reproduit par le rebond en arrière contre l'obstacle (turbine entraînée à l'envers alors que le moteur
tire en D) sur `wk_atlas` ; pour P-01, le mécanisme exact du calage en jeu **n'est pas reproduit** hors moteur
(aucun calage au banc, même avec un rebond de 12 m/s) : le pilote GPS journalise désormais chaque calage avec son
contexte (vitesse, rapport, pontage, roues au sol, limitations de la borne).

### 3.3 Cause du blocage : aucune relance possible sans pédale d'embrayage

La relance d'un moteur calé exigeait l'embrayage enfoncé ou le neutre (`VehicleDynamics.updateEngineState`). Sur une
boîte sans pédale d'embrayage (automatique, double embrayage, séquentielle, CVT), le sélecteur ne repasse jamais au
neutre en jeu : **un moteur calé le restait jusqu'à la sortie du véhicule** (banc : calé après pédales relâchées sur
le code `2f304b7`). Défaut de jeu, indépendant du pilote d'essai.

Correction (`5805636`) : sans pédale d'embrayage, le démarreur tourne quand le conducteur relâche l'accélérateur
(équivalent du passage par N/P et de la clé, sans nouvelle commande). Boîte manuelle inchangée. Tests Lune : relance
de P-01 calée en D accélérateur relâché, aucune relance accélérateur enfoncé, P-02 manuelle inchangée ; calage par
rebond de `wk_atlas` sans activation de la borne puis relance.

### 3.4 Vérification en jeu (tâche `20261104-031929`, `360f903`, session `gps2`)

Le pilote heurte de nouveau le poteau de feu au même endroit (`FeuPoteau`, Δv 25,0 m/s) ; le calage est relevé avec
son contexte : `moteur calé en (-2578, 102) — proto_p01, 18 km/h, rapport 1, ponté false, 4 roue(s) au sol,
limitations du convertisseur 0`, puis `moteur relancé en 0.7 s` (pédales relâchées). La borne du convertisseur n'a
agi à aucun moment des deux trajets (`limitations_convertisseur` = 0 et 0). Le trajet se poursuit et arrive.

## 4. QA-A10 — téléphone tenu bras baissé : cause établie et corrigée

- **Cause** (tâche `20261104-021402`, relevé `ui_monde.info_articulations_avatar`) : l'avatar par défaut utilise le
  nouveau squelette R15 de Roblox (« Avatar Joint Upgrade ») : épaule `AnimationConstraint:RightShoulder` et
  `BallSocketConstraint:RightShoulderBallSocket`, **aucun Motor6D**. `InterfaceService` ne cherchait qu'un Motor6D :
  le bras n'était jamais levé.
- **Première correction rejetée par l'essai** (`d98f60c`, tâche `20261104-025158`) : rotation de l'attache côté torse
  — bras inchangé (8° → 8°). La documentation de Roblox indique que C0 est en lecture seule sur ces articulations et
  qu'il ne faut pas modifier les attaches du squelette ; elle recommande de multiplier le décalage dans `Transform`
  après l'animation (`RunService.PreSimulation`), côté client, l'état étant partagé par attribut.
- **Correction** (`000045c`, vérifiée avec `360f903`) : le serveur publie l'attribut `AWPhoneRaised` du personnage (chemin Motor6D conservé
  pour R6 et R15 classique) ; chaque client (`PhoneController`) applique 60° à l'épaule de chaque joueur concerné,
  progressivement (0,25 s), sans cumul quand l'animation n'est pas réévaluée ; attaches non modifiées. Direction
  artistique inchangée (aucune interface modifiée).
- **Vérification** (tâche `20261104-031929`, mesure géométrique indépendante du squelette, vraies touches) :

| Contrôle | Mesure |
|---|---|
| `ui_monde.telephone_bras_leve` | bras à 55° de la verticale (avant : 8°), **levé de 47°** (rotation de 60° composée avec la pose d'attente) |
| `ui_monde.telephone_devant_le_personnage` | téléphone 1,8 st devant, 0,3 st au-dessus du centre du personnage, 0,29 st de la main (avant correction : 0,7 st devant, 1,1 st **sous** le centre) |
| `ui_monde.telephone_en_marchant` | vraie touche W 2,5 s : 13,6 st parcourus, bras levé d'au moins 31° pendant la marche, téléphone toujours dans la main (≤ 0,29 st) |

  Capture `054_telephone_en_main_face`. Campagne finale (`20261104-050215`, `c352f26`) : levé de 46°, téléphone
  à 0,29 st de la main, 12,2 st parcourus en marchant, bras levé d'au moins 33°. Non vérifié : vue par un **autre
  joueur** (une seule session cliente en monde ouvert) — le mécanisme est le même pour tous les personnages
  (attribut lu par chaque client) ; avatar R6 : non essayé dans ce lot.

## 5. GPS — destinations des 7 zones par conduite réelle

Pilote d'essai (`tests/studio/GpsClient.client.luau`) amélioré, **sans téléportation** (le véhicule est posé une
seule fois au départ, puis conduit) :

- voie de droite (décalage de 1,8 m de l'axe de l'itinéraire) ; dépassement par la gauche d'un obstacle immobile ;
- trois rayons d'obstacle (axe et coins avant) ; dégagements journalisés, alternés et allongés quand ils se répètent ;
- moteur calé : pédales relâchées (relance, §3) ;
- **sortie d'itinéraire par la route** : point de route à 180-400 m et à plus de 90 m de l'itinéraire, itinéraire du
  jeu pour s'y rendre (même planificateur que le GPS) ; le coup de volant « vers le côté dégagé » des lots
  précédents ne quittait pas l'itinéraire en ville (2 à 7 m d'écart, tâches `20261104-021402` et `-025158`).

| Tâche | Code | Motorsport | Montagnes | Sortie et recalcul |
|---|---|---|---|---|
| `20261104-021402` | `9715443` | abandon (calé, immobilisé 90 s) | abandon (même point) | sortie insuffisante (2 m) |
| `20261104-025158` | `a089a03` | **arrivé** (463 s, 24 m) | abandon (carrefour, 90 s) | sortie insuffisante (7 m) |
| `20261104-031929` | `360f903` | **arrivé** (414 s, 24 m) | **arrivé** (1 582 s, 24 m) | **écart 51 m, recalcul après 22 s** |

Arrivées **constatées par le GPS du jeu** (statut « Arrivé »). Zones traversées pendant `gps2` : Banlieues,
Métropole, Montagnes, Motorsport. Conduite du pilote encore imparfaite : 39 chocs confirmés par le serveur pendant
les deux trajets (surtout des glissières, trois fois le même poteau de feu), 29 dégagements ; ce sont des limites du
pilote d'essai, pas des défauts du jeu (chocs constatés, dégâts appliqués, aucune erreur).

Session `gps` à 7 destinations, campagne finale (`20261104-050215`, `c352f26`, 2026-11-04 05:02–06:00, 3 007 s) :

| Trajet | Résultat |
|---|---|
| 1 Banlieues | **arrivé** (271 s, 25 m) |
| 2 Métropole | abandon : pilote coincé en (−2 587, 94) m, 21 dégagements (moteur en marche), immobilisé 90 s |
| 3 Littoral | **arrivé** (385 s, 23 m) |
| 4 Docks | **arrivé** (437 s, 23 m) |
| 5 Montagnes | sortie d'itinéraire 55 m, **recalcul après 23 s** ; puis abandon à 832 m de l'arrivée : pilote coincé en (2 151, −2 506) m |
| 6 Campagne | abandon : part du point où le trajet 5 s'est arrêté (aucun repositionnement, par choix), même blocage |
| 7 Motorsport | **arrivé** (840 s, 23 m) |

0 calage, 0 limitation du convertisseur, 0 neutralisation de valeur non finie pendant les 7 trajets.

**Bilan des 7 zones sur le code du lot 0.9.2** : arrivée constatée par le GPS pour **5 zones** — Banlieues, Littoral,
Docks, Montagnes (`031929`), Motorsport (`025158`, `031929`, `050215`). **Métropole et Campagne : non atteintes
sur le code de ce lot** (arrivées constatées seulement au lot 0.9.1, tâche `20261103-220054`, code `82731da`). Six
zones traversées en conduite dans la même session (`050215`), toutes sauf Campagne. Les 7 zones n'ont jamais été
atteintes dans une même tâche. Les abandons sont des limites du pilote d'essai (blocages sans erreur du jeu), non
corrigées dans ce lot.

## 6. Interfaces : focus, Entrée, retour, photo

- **Défaut constaté au lot 0.9.1 en vrais clics** : au clavier et à la souris, le contour de navigation restait sur
  l'onglet d'ouverture et la touche Entrée l'activait (onglet changé sans demande).
- **Correction** (`9b8b052`, `UIManager`) : la règle du parcours d'arrivée (lot 0.8, QA-F09) s'applique à tous les
  panneaux : focus posé seulement à la manette, ou au passage à la manette pendant qu'une fenêtre est ouverte.
  Direction artistique inchangée. Test Lune : « Interfaces : focus de navigation posé seulement à la manette ».
- **Vérification en vrais clics et vraies touches** (`20261104-035727` et campagne finale `20261104-042820`) :
  `ui.garage.aucun_focus_clavier_souris`, `ui.garage.entree_sans_changement_d_onglet`,
  `ui.garage.entree_sans_effet_serveur` (solde inchangé), `ui.concession.entree_ne_confirme_pas` (confirmation
  toujours affichée, aucun achat), `ui.carte.fermee_par_touche_retour`, `ui.photo.app_photo_du_telephone`,
  `ui.conduite.embarquement_touche_E` : réussis dans les deux tâches.
- Défaut **du test** trouvé et corrigé (`c352f26`) : dans la phase photo de la session `ui`, une variable locale
  masquait celle de la phase ; le mode photo restait ouvert et bloquait l'embarquement par E (échec de
  `embarquement_touche_E` dans `035727`, réussi dans les 7 tâches précédentes et dans `042820`).
- Non vérifié : comportement à la **manette** (aucune manette émulée dans la VM) ; touche O (limite de Studio, §7).

## 7. Campagne finale de non-régression

Trois tâches VM, 2026-11-04, sessions dans l'ordre (`ui` en tête : voir `docs/VM_TESTS.md`) :

| Tâche | Code | Place | Sessions | Résultat |
|---|---|---|---|---|
| `20261104-040910` (04:09–04:27) | `013ff21` (jeu identique à `c352f26`) | Dev | `solo`, `multijoueur`, `latence`, `scenarios`, `collision`, `collision_latence`, `lot02`, `lot04` | 527 réussis, 5 échecs, 1 limite connue |
| `20261104-042820` (04:28–05:01) | `c352f26` | Dev | `ui`, `ui_marche`, `lot05`, `lot06`, `lot08`, `metiers`, `drift`, `social` | 445 réussis, 4 échecs |
| `20261104-050215` (05:02–06:00) | `c352f26` | OpenWorld | `monde`, `perf`, `ui_monde`, `gps` | 225 réussis, 7 échecs |
| **Total** | | | 20 sessions | **1 197 réussis, 16 échecs, 1 limite connue** |

Domaines couverts : conduite et propriété réseau, multijoueur et latence (100 ms), collisions, économie et marché
(`lot05`), courses (`lot06`), 8 métiers (`metiers.bilan_huit_metiers` : 8 / 8 terminés et payés), interfaces en vrais
clics, GPS et monde ouvert, performances, drift, social. Aucune erreur d'exécution du jeu ; aucune neutralisation de
valeur non finie dans les trois journaux.

Classement de chaque échec :

| Contrôle | Tâche | Classement | Explication |
|---|---|---|---|
| `client.essai1_pilote_percute_reste_droit` (`UpVector.Y −0,353`) | `040910`, `collision_latence` | **Défaut probable du jeu, cause non établie** (nouveau : QA-A11) | Véhicule conduit percuté à 18,7 km/h, retourné à plus de 110°. Seul indice : la copie locale du percuteur vue par le percuté a pénétré de 1,40 st (`copie_percuteur_ecart_min_st` = −1,40, contre +0,54 et +0,59 aux deux autres essais). 2 échecs sur 96 de ce contrôle dans tout l'historique (l'autre au lot 0.2, corrigé). Code des collisions non modifié dans ce lot. Non corrigé |
| `scenario.propriete_reseau_sans_anomalie` × 2 | `040910`, `scenarios` et `collision_latence` | Anomalie connue QA-A01 (jeu ou moteur, non tranché) | « Réattribution (1) », corrigée à la vérification suivante, sans effet mesuré |
| `serveur.attribut_simulation_conforme_au_proprietaire` | `040910`, `lot02` | Anomalie connue QA-A03 | 1 écart sur 7 074 contrôles |
| `scenario.collision_poussee_pilote_comparable_au_gare` | `040910`, `collision_latence` | Anomalie connue QA-A07 (variabilité), critère du test | Conduit 7,58 st contre 2,5 × la médiane du garé (5,6 st) ; déjà en échec dans 4 tâches antérieures |
| `lot06.j1.entrainement_circuit` | `042820` | **Défaut du test** (pilote) | Après le 1ᵉʳ tour (51,7 s), le pilote coupe le virage vers la ligne de départ et bute à 0 km/h en (−65, −216) m contre le poteau ouest du portique (x ≈ −67,6 m, z = −215 m), sans dégagement, jusqu'au délai. Même point exact au lot 0.9.1 (`20261104-001121`) |
| `lot06.j1.entrainement_rally`, `_drift` | `042820` | Défaut du test (conséquence) | `RaceDriveToJoin` après l'expiration du circuit |
| `ui.photo.ouverture_touche_O` | `042820` | **Limite de l'environnement** | Touche O jamais reçue par le jeu dans Studio (connue depuis le lot 0.9.1) ; le mode photo s'ouvre par le téléphone |
| `monde.trafic_corps_pres_du_joueur`, `monde.trafic_proprietaire_serveur` | `050215` | **Défaut du test** (échantillon unique) | 140 agents ; 0 corps physique à moins de 260 m au seul instant mesuré, contre 1 à 5 dans les 10 tâches antérieures ; code du trafic non modifié depuis le lot 0.9.1 |
| `gps.trajet_2/5/6…arrivee_constatee_par_le_gps`, `gps.sept_zones_traversees`, `gps.arrivees` | `050215` | **Défaut du test** (limites du pilote) | Blocages du pilote, moteur en marche, sans erreur du jeu (§5) |
| Limite connue : `client.propriete_refusee_personnage_releve` | `040910` | Limite connue QA-A05 | Véhicule ancré par le test |

Aucun échec n'est classé « dépendance externe ». Aucun échec n'a été réessayé pour obtenir un meilleur taux.

## 8. Problèmes ouverts

- **QA-A11 (nouveau, P2)** : véhicule conduit percuté qui se retourne sous latence (une occurrence) ; cause non
  établie ; à reproduire avant toute correction.
- **Mécanisme exact du calage de P-01** en jeu : non reproduit hors moteur (§3.2) ; la relance corrige le blocage.
- **Règle de relance — validée par le propriétaire le 2026-11-04** : le démarreur tourne quand le conducteur d'une
  boîte sans pédale d'embrayage relâche l'accélérateur (§3.3), sans commande explicite. Ressenti en jeu par un humain :
  NON TESTÉ.
- QA-A10 vu par un autre joueur et avec un avatar R6 : NON TESTÉ.
- GPS : Métropole et Campagne non atteintes sur le code de ce lot ; pilote GPS encore sujet aux blocages.
- Pilote de course du circuit d'essai : bute sur le portique au 2ᵉ tour (défaut du test, non corrigé).
- Contrôle du trafic : relevé instantané unique (défaut du test, non corrigé).
- Anomalies anciennes toujours ouvertes : QA-A01, QA-A03, QA-A06, QA-A07 ; limites QA-A04, QA-A05.
- Non faits : manette, touche O dans un vrai client Roblox, DataStore réel, appareils réels, essais humains.

## 9. Livraison

- Corrections du jeu : `ebe4714` (QA-A08), `9b8b052` (focus), `5805636` (relance du moteur calé), `d98f60c` puis
  `000045c` (QA-A10). Corrections des tests : `aeee110`, `d8c2c8e`, `9715443`, `a089a03`, `360f903`, `6479c2e`,
  `c352f26`.
- Tests de régression : `tests/lune/specs/Lot092Stabilization.luau` (8 tests) ; outils `tests/lune/tools/nan-hunt.luau`
  et `tests/lune/tools/stall-impact.luau`.
- Vérification hors Studio : `scripts\verify.ps1` (résultat dans la PR #11).
- PR brouillon [#11](https://github.com/AbdelmalekYounes/roblox-automotive-world/pull/11), non fusionnée.
