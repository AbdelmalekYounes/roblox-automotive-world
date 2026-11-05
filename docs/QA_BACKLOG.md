# Registre QA — essais reportés et anomalies ouvertes

Registre **unique** des essais non effectués et des anomalies non résolues des lots 0.1 à 0.9.2, AVATAR-01, Aster phase 1, VEH3D-01 et UI V1.2. Décision du
propriétaire (lot 0.3) : les essais humains, les campagnes approfondies de non-régression et les tests de charge sont
regroupés dans un **lot QA ultérieur**, lancé à sa demande (« on testera tout d'un coup »).

Règles de ce registre :

- Tout ce qui n'a pas été exécuté est marqué **NON TESTÉ**. Une ligne ne passe à « fait » qu'avec la commande, la
  date, l'identifiant de tâche et le résultat mesuré, consignés dans le rapport du lot concerné.
- Une anomalie n'est **jamais** déclarée corrigée sans preuve (exécution qui la reproduisait auparavant, puis qui ne
  la reproduit plus, sur un nombre d'essais indiqué).
- Priorité : **P1** bloque la clôture du lot ou peut fausser d'autres essais ; **P2** comportement visible par le
  joueur ; **P3** confort, réglage, mesure.
- Les essais Studio se lancent dans la VM (`docs/VM_TESTS.md`), jamais sur le poste principal ; les essais humains
  sont faits par le propriétaire. **Depuis le 2026-11-05**, plus de campagne VM automatique : le propriétaire teste
  lui-même à partir de listes de vérification ; une session VM n'est lancée que sur sa demande.

Dernière mise à jour : 2026-11-05, audit d'intégration V1.0 (§3 octies ; `docs/audit/AUDIT_INTEGRATION_V1.0.md`).
Mise à jour précédente : 2026-11-04, clôture de la phase 1 de l'Aster (branche `feat/aster-phase1` ; QA-A17 à A23 ; rapport `docs/vehicle-3d/ASTER_PHASE1_CLOTURE.md` ; rapport `docs/vehicle-3d/ASTER_PHASE1.md`). Mise à jour précédente : lot 0.9.2 (QA-A08 à A12, U02, U10 ; `docs/lot-0.9.2/RAPPORT_STABILISATION.md`).
Analyse détaillée des anomalies (probabilité, impact, exploitation, dépendances, coût) :
`docs/lot-0.9/ANOMALIES_ET_CORRECTIONS.md` §4.

## 1. Anomalies ouvertes

| Id | Lot | Système | Priorité | Description | Conditions de reproduction | État |
|---|---|---|---|---|---|---|
| QA-A01 | 0.1 | Propriété réseau / réplication | P1 | Client propriétaire et simulant (`ReceiveAge` = 0) mais le serveur ne voit pas le véhicule avancer, puis voit un saut (correction « Teleport »). Détail : `docs/lot-0.1/RAPPORT_VALIDATION.md` §5.1 | Sessions `collision`, `collision_latence` ; surtout après sortie puis réembarquement rapide suivant un repositionnement par le serveur de test. Intermittent (≈ 1 essai sur 6 dans certaines campagnes) | **Ouverte, P2** (lot 0.9) — le symptôme visible (véhicule immobile puis « Teleport ») venait du scénario de test (voir QA-A02) : 0 occurrence sur 4 sessions de collision après correction (`20261103-155713`). Reste : 0 à 2 « réattribution (1) » par session, corrigées à la première vérification, sans effet mesuré ; cause moteur non établie |
| QA-A02 | 0.2 | Sortie du véhicule | P1 | Sortie non effective après la collision contre un véhicule garé, puis étape suivante faussée (« Teleport », « propriété refusée »). Détail : `docs/lot-0.2/RAPPORT_LOT_0.2.md` §3.10 | Session `scenarios` : 2 exécutions sur 5 (`225205`, `233800`) | **Expliquée (lot 0.9), faux défaut du test** — l'arrêt du scénario maintenait « freiner » à l'arrêt : marche arrière (arbitrage A3), sortie refusée à juste titre (`ExitTooFast`, 21 à 35 km/h mesurés). Test corrigé (`dcf47c8`) : 0 sortie non effective sur 4 sessions (`20261103-155713`) |
| QA-A03 | 0.2 | Propriété réseau (attribut) | P2 | `SimulationOwnerUserId` vu à 0 alors que le joueur était propriétaire effectif | 1 contrôle sur 7 101 (`224147`), 1 sur 1 706 (`235945`), 1 sur 2 340 (`023510`), 1 sur 7 092 (`030408`) | **Ouverte** |
| QA-A04 | 0.1 | Collisions entre joueurs | P2 | Le percuteur s'arrête net contre le véhicule d'un autre joueur (`docs/lot-0.1/ECARTS.md` §4.5) | Session `collision` | **Limite connue** |
| QA-A05 | 0.1 | Véhicule ancré | P3 | Personnage resté assis côté client après refus, sans pouvoir conduire | Cas provoqué par le test (véhicule ancré) | **Limite connue** |
| QA-A06 | 0.1 | Démarrage | P3 | Une fois (`180955`), véhicules pas encore immobiles 4 s après le démarrage (1,04 st/s) | Non reproduit ensuite | **Ouverte**, non reproduite |
| QA-A07 | 0.1 | Collisions | P3 | Variabilité du percuté conduit : un glissement de 9,06 st (`193233`) | Session `collision` | **Ouverte** |
| QA-A08 | 0.2 | Simulation du véhicule | P1 | Valeur non finie (NaN) dans l'état d'une roue ou d'un contact : 2 372 erreurs « clamp » en 43 s (`TireModel.stopClamp`), simulation figée | `20261103-224247`, session `metiers` : véhicule personnel endommagé (trains avant), plaqué contre un obstacle, marche avant et arrière alternées. Une occurrence | **Corrigée (lot 0.9.2)** — cause : couple du convertisseur intégré sans borne de stabilité (divergence quand le véhicule est plaqué, boîtes à convertisseur seulement) ; borne `ebe4714` (`ConverterStabilityFactor` 1,8), neutralisation du lot 0.9.1 conservée ; tests Lune (13 scénarios qui divergeaient, 4 500 scénarios, conduite normale non limitée) ; en jeu : 0 neutralisation dans la campagne finale. Incident exact non rejoué dans le moteur. `docs/lot-0.9.2/RAPPORT_STABILISATION.md` §1 |
| QA-A09 | 0.1 | Conduite à deux clients | P2 | Client 2 : essai de virage après la marche arrière raté (0,0° ou −106° à −148° en 2 s : véhicule encore en marche arrière ou immobile) | Sessions `multijoueur` et `latence`, client 2 seulement : 2 sur 4 (`20261104-001121`, `-011029`) avec le code du lot 0.9.1, **et 2 sur 4 avec le code du lot 0.9** (`20261104-011801`, `855b93b`) : **pas une régression**. Absent des campagnes du lot 0.9 | **Expliquée (lot 0.9.2), erreur du scénario de test** — l'élan des virages envoyait les véhicules sur les poteaux du portique d'arrivée du drag (chocs confirmés par le serveur) ; tests corrigés (`9715443`, `6479c2e`) ; `20261104-035727` : 24 virages sur 24. Aucune modification du jeu |
| QA-A10 | 0.7 | Téléphone en main | P3 | Téléphone tenu **bras baissé** : le serveur tourne l'épaule de 60° (`InterfaceService`), mais les captures montrent le bras le long du corps | Captures `20261103-220054` 091 et `20261104-012609` 032 (monde ouvert, avatar par défaut de Studio) ; relevé de l'articulation côté client non concluant (articulation non trouvée par le test) | **Corrigée (lot 0.9.2)** — cause : nouveau squelette R15 (« Avatar Joint Upgrade », `AnimationConstraint`, aucun Motor6D) ; `000045c` : attribut `AWPhoneRaised`, décalage appliqué par chaque client sur `Transform` (PreSimulation) ; `20261104-031929` et `-050215` : bras levé de 46-47°, téléphone dans la main, aussi en marchant. Vu par un autre joueur, R6 : NON TESTÉ |
| QA-A11 | 0.9.2 | Collisions sous latence | P2 | Véhicule conduit percuté à 18,7 km/h retourné (`UpVector.Y` −0,353) ; copie locale du percuteur entrée de 1,40 st dans le percuté | `20261104-040910`, `collision_latence`, essai 1 ; 1 fois sur 96 essais de ce contrôle depuis le lot 0.2 (l'autre corrigé au lot 0.2) | **Ouverte** — cause non établie, non reproduite ; code des collisions non modifié au lot 0.9.2 |
| QA-A12 | 0.9.2 | Moteur, boîtes sans pédale d'embrayage | P1 | Moteur calé définitivement sur boîte automatique (aucune relance sans embrayage ni neutre) | `20261104-021402`, `gps2` : calé après un choc contre un poteau de feu, immobilisé | **Corrigée (lot 0.9.2)** — `5805636` : démarreur quand l'accélérateur est relâché ; tests Lune ; `20261104-031929` : relancé en 0,7 s. Règle de jeu **validée par le propriétaire le 2026-11-04** (sans commande explicite) ; mécanisme exact du calage de P-01 non reproduit hors moteur |
| QA-A13 | AVATAR-01 | Habitacles / avatars R15 | P1 | Tête d'un R15 standard au-dessus du dessous du pavillon : 14 véhicules fermés sur 18 (référence, jusqu'à 1,46 st, `wk_comete`), 10 sur 18 avec la plus petite morphologie, 17 sur 18 avec les cheveux du compte de test | `20261104-111326`, session `avatar` (captures 007, 004, 013) | **Ouverte** — géométrie de l'habitacle (`BodyKits`) à arbitrer ; une limitation des proportions ne suffirait pas ; `docs/lot-avatar-01/RAPPORT_AVATAR_R15.md` §4.3 |
| QA-A14 | AVATAR-01 | Habitacles / avatars R15 | P2 | Avant-bras à travers la portière (30 assises de référence sur 37, jusqu'à 0,31 st) ; jambes dans la planche de bord ou le volant (> 0,5 st) dans 6 modèles bas | `20261104-111326`, session `avatar` | **Ouverte** — à arbitrer avec QA-A13 |
| QA-A15 | AVATAR-01 | Sortie passager | P1 | Le passager sort par le saut du moteur, sans placement par le jeu : sur le toit ou couché au sol, 0 sortie correcte sur 32, dès la morphologie de référence | `20261104-104818`, `-111326`, vraie touche Espace | **Corrigée (VEH3D-01, `a0debec`)** — passager placé côté droit, sans collision avec les véhicules jusqu'au placement ; 8 / 8 sur la Comète (`20261105-023349`) ; autres modèles : NON TESTÉ (demande du propriétaire : Comète seule) |
| QA-A16 | AVATAR-01 | Sortie conducteur | P2 | Personnage retrouvé couché après la sortie (4 sur 40 : `wk_pixel`, `wk_dune`, surtout petites morphologies) ; recouvrement avec le véhicule (1 sur 40) | `20261104-111326`, vraie touche F | **Corrigée (VEH3D-01, `a0debec`)** — cause : occupant expulsé du volume de collision de l'habitacle ; 8 / 8 sur la Comète (`20261105-023349`) ; autres modèles : NON TESTÉ |
| QA-A17 | Aster phase 1 | Habitacles provisoires / corps humains | P3 | Avec le corps humain masculin (995), les pieds des grandes morphologies (M4, M7 ; M5 sur `wk_sentier`) dépassent du plancher de 0,01 à 0,24 st dans 6 carrosseries provisoires (`wk_atlas`, `wk_brio`, `wk_dune`, `wk_fil`, `wk_pixel`, `wk_sentier`) | `20261104-154409`, session `avatar` (comparé à `20261104-111326`) | **Ouverte** — carrosseries provisoires ; les modèles 3D suivront le gabarit (`docs/vehicle-3d/ASTER_PHASE1.md` §5.3) |
| QA-A18 | Aster phase 1 | Sortie conducteur / corps humains | P2 | 10 sorties du conducteur en échec en plus avec le corps humain (`wk_brise`, `wk_dune`, `wk_pixel`) : personnage couché ou en recouvrement avec le véhicule | `20261104-154409` (comparé à `20261104-111326`), vraie touche F | **Corrigée par la même modification (`a0debec`)** — vérifiée sur la Comète seulement ; autres modèles : NON TESTÉ |
| QA-A19 | Aster phase 1 | Apparence / corps humains | P2 | Tête classique « bloc » du joueur conservée sur le corps réaliste : rendu partiellement « semi-Lego » | Capture 001 de `20261104-154409` | **Corrigée** — décision du propriétaire « Remplacer têtes classiques » ; critère de forme (`AvatarPolicy.isClassicHeadShape`), contrôles réussis en `20261104-170413` ; couleurs de peau conservées, à arbitrer (`ASTER_PHASE1.md` §7) |
| QA-A20 | Aster phase 1 | Téléphone en main | P3 | `telephone_bras_leve` en échec intermittent : bras de départ à 30–36° au repos (M2, M7 en `20261104-174434` : vitesse nulle, aucune piste de marche ni de course) | `20261104-151955`, `-154409`, `-174434` ; 0 sur 8 en `20261104-181108` (attente du bras au repos, pistes relevées) | **Ouverte** — hypothèse « fin de marche » écartée ; cause non établie (capture 005 de `174434` : bras écarté au repos) ; le test attend désormais le repos (< 15°) |
| QA-A23 | Aster phase 1 | Gabarit de l'Aster / pieds | P1 | Pieds des corps réalistes 0,67 à 0,94 st sous le dessus du plancher (pose du jeu), non détectés : le contrôle des jambes ne couvrait que planche de bord, volant et pédalier | `20261104-162124` (mesures) | **Corrigée dans le gabarit** — plancher à −1,30 st, contrôle « pieds au-dessus du plancher » réussi en pose du jeu (`20261104-181108` : 0,07 à 0,34 st) ; pose standard encore sous le plancher (jusqu'à −0,42 st) : sièges de l'Aster avec `AWSeatPose` obligatoires (`ASTER_02_LANCEMENT.md`) ; plancher abaissé validé par le propriétaire (2026-11-04) |
| QA-A21 | Aster phase 1 | Habitacles provisoires / têtes réalistes | P3 | Tête réaliste (classique remplacée) au-dessus du dessous du pavillon dans `wk_dune` (M1, M3, M6, M8 : −0,01 à −0,25 st) et `wk_sentier` (M8 : −0,01 st), deux places | `20261104-170413`, session `avatar` (comparé à `20261104-154409`) | **Ouverte** — carrosseries provisoires (QA-A13) |
| QA-A22 | Aster phase 1 | Tests VM / clavier | P3 | Touches de l'étalonnage non reçues dans la session `avatar` (toutes les marches en échec) ; disposition AZERTY de la VM (mode « vk » : A, W, Y pour Q, Z, Y) | `20261104-162124`, `-164354` ; non reproduit en `-170413`, `-174434`, `-181108` (6 étalonnages au 1er essai) | **Atténuée, non prouvée** — étalonnage à 3 essais avec reprise du focus (`GuiDriver.calibrateKeys`) ; reprises jamais mises à l'épreuve ; aucun réglage de la VM modifié |

### 1 bis. Défauts trouvés par la campagne du 2026-11-03 et corrigés

| Id | Lot | Système | Priorité | Défaut | Correction | Preuve |
|---|---|---|---|---|---|---|
| QA-F01 | 0.4 | Garages | P1 | Une sortie répétée (même demande) pendant l'attente de sauvegarde matérialisait une seconde copie conduisible du véhicule (`20261103-025318`) | `5da05aa` | `20261103-025600`, `20261103-030408` : 1 exemplaire, aucun véhicule restant |
| QA-F04 | 0.6 | Démarrage des courses | P1 | `RaceService` lisait l'environnement des profils avant le démarrage de `ProfileService` : amorçage du serveur interrompu (`20261103-110953`, 7 échecs) | Adaptateur inter-serveurs créé à la première utilisation (commit du lot 0.6) | `20261103-111939` (65 / 0), `20261103-112132` (35 / 0) |
| QA-F03 | 0.5 | Lieux économiques | P2 | Les 13 lieux économiques recevaient l'invite « Préparer / Garage public » de la progression (29 invites au lieu de 16, `20261103-035626`) | `2caf0c9` | `20261103-035902` : 16 + 13 invites, aucune erreur |
| QA-F02 | 0.3 | Carte | P1 | 195 pièces dépassaient 2 048 studs et étaient raccourcies par le moteur : trous aux bouts des longues chaussées droites (P-01 sur l'herbe, 37,8 km/h, `20261103-025743`) | `b41e0f1` | `20261103-030159` : 133,4 km/h sur A6-2, toujours sur la route |
| QA-F05 | 0.6 | Zone d'essai / drag | P1 | Mât solide de l'arbre de départ au centre de la ligne droite d'essai : bancs du lot 0.2 bloqués (`20261103-151033`) | `708331e` | `20261103-155713` : `lot02` réussi |
| QA-F07 | 0.6 | Courses | P1 | Inscription impossible en jeu (`VehicleSeat` exigé, siège `Seat`) (`20261103-155713`) | `38e3b3b` | `20261103-170323`, `-184407` : épreuve officielle de bout en bout |
| QA-F08 | 0.5 | Marché | P1 | Annonce jamais publiée quand la réservation est « Pending » : exemplaire bloqué (`20261103-155713`) | `e097815` | `20261103-163722` : vente concurrente réglée ; test Lune (échoue sans la correction) |
| QA-F10 | 0.5 | Stations | P2 | Pleins simultanés illimités par station | `12b632e` | Lune |
| QA-F12 | 0.8 | Rendu de nuit | P2 | Lampadaires et niveau de détail de l'habillage jamais suivis (carte reçue après le démarrage) (`20261103-174932`) | `f2fe391` | `20261103-175506` : 12 lampadaires allumés de nuit |
| QA-F13 | 0.8 | Arrivée, économie | P2 | Confirmation du premier véhicule ajoutée hors de vue (bas de la liste) ; pied « Fait. » périmé pendant une confirmation (arrivée, devis) (`20261103-195821`, vrais clics) | `e48ec3c`, `c626686` | `20261103-200648` : confirmation visible (y = 595) et cliquée ; Lune |
| QA-F14 | 0.7 | Téléphone, HUD | P3 | Signes « ⤢ », « ✕ », « ✓ » absents de la police : carrés vides (captures 038, 039) | `a008dea` | Capture 091 (`20261103-220054`) ; Lune (aucun signe absent) |
| QA-F15 | 0.2 | Vue cockpit | P2 | Volant à hauteur des yeux, cachant le milieu de la route (capture 055) ; marge 1,1° au pire | `a008dea` | `20261103-213328` : ≥ 10° sur les 9 + 18 modèles construits ; Lune |
| QA-F16 | 0.5 | Marché | P1 | « Retirer l'annonce » toujours refusé (opération sensible sans identifiant) | `b34c38a` | Reproduit par vrai clic sur `4947ec5` (`20261103-210055`, capture 006) ; corrigé : annonce retirée (`20261103-224247`) ; Lune |
| QA-F17 | 0.3 | Éclairage des places | P2 | Technologie « Compatibility » (retirée par Roblox) : fenêtre de migration modale au-dessus du jeu dans Studio, clics bloqués | `82731da` | `20261103-220054` : plus de fenêtre, étalonnage réussi ; Lune |
| QA-F18 | 0.7 | Conduite et menus | P2 | Menu modal ouvert à l'arrêt : commandes neutralisées frein à main compris ; boîte automatique qui rampe (4,2 km/h), panneau refermé | `790388e` | `20261103-224247` : 0,0 km/h, panneau ouvert ; Lune (échoue sans) |
| QA-F19 | 0.9 | Chargement de mission | P3 | Passager du taxi au-dessus du toit (capture 0158) | `790388e` | Lune ; rendu après correction : NON TESTÉ sur capture |
| QA-F20 | 0.7 | GPS | P2 | Destination au milieu d'une longue route refusée « Invalid » (montagne) ; arrivée en ligne droite à travers le relief | `da9cfa2` | Lune (16 longues routes, échoue sans) ; `20261103-225749` : itinéraire de montagne calculé dans le jeu (7,5 km) |

## 2. Essais humains

**Déclaration du propriétaire** (brief du lot 0.2, 2026-11-02) : « Le propriétaire a terminé ses neuf vérifications
manuelles du lot 0.1 sans signaler de problème. » Ces essais n'ont laissé ni étapes, ni résultats chiffrés, ni
journal : ils sont classés **DÉCLARÉ (propriétaire)**, une origine distincte des essais automatisés et des essais
consignés. Écart à lever : le rapport du lot 0.1 ne liste que **sept** essais humains (H1 à H7 de
`docs/lot-0.1/RAPPORT_VALIDATION.md` §4, repris en QA-H01 à QA-H06 ; H7 « ressenti » n'a pas de ligne propre) ; la
correspondance exacte des neuf vérifications reste à confirmer par le propriétaire. Aucun autre essai humain n'a été
déclaré ou consigné.

| Id | Lot | Système | Priorité | Essai | Attendu | État |
|---|---|---|---|---|---|---|
| QA-H01 | 0.1 | Commandes | P1 | Conduite au clavier (Z/W, S, Q/A/D, Espace, V, R, F) | Réponse progressive, marche arrière en maintenant S à l'arrêt, sortie refusée au-dessus de 20 km/h | **DÉCLARÉ (propriétaire)** — non consigné en détail |
| QA-H02 | 0.1 | Commandes | P1 | Conduite à la manette (RT, LT, stick, A, croix, Y) | Idem, aide du HUD en mode manette | **DÉCLARÉ (propriétaire)** — non consigné en détail |
| QA-H03 | 0.1 | Commandes | P2 | Clavier et manette ensemble | Le dernier périphérique sollicité pilote, pas de cumul | **DÉCLARÉ (propriétaire)** — non consigné en détail |
| QA-H04 | 0.1 | Commandes | P2 | Taper dans le chat en conduisant | Aucune commande ni sortie | **DÉCLARÉ (propriétaire)** — non consigné en détail |
| QA-H05 | 0.1 | Commandes | P2 | Débrancher / rebrancher la manette gâchette enfoncée | Relâchement, message, pas de redémarrage avant un nouvel appui | **DÉCLARÉ (propriétaire)** — non consigné en détail |
| QA-H06 | 0.1 | Commandes | P3 | Perte de focus de la fenêtre en conduisant | Relâchement, touche « bloquée » ignorée au retour | **DÉCLARÉ (propriétaire)** — non consigné en détail |
| QA-H07 | 0.2 | Commandes | P1 | Clavier : Maj / Ctrl gauche (rapports), C (embrayage), 1/2/3 (aides), G (récupération), V (caméras) | Effet immédiat, affiché au HUD | **NON TESTÉ** |
| QA-H08 | 0.2 | Commandes | P1 | Manette : RB / LB, B, croix gauche / droite, croix haut | Idem | **NON TESTÉ** |
| QA-H09 | 0.2 | Boîte manuelle | P2 | Démarrage en côte et calage au clavier et à la manette | Rampe d'embrayage de 0,6 s utilisable | **NON TESTÉ** |
| QA-H10 | 0.2 | Ressenti | P2 | Six boîtes, rampement de l'automatique, aides, glissement combiné ; maintien en pente (A3, à arbitrer) | Ressenti crédible ; arbitrage A3 | **NON TESTÉ** |
| QA-H11 | 0.2 | HUD / caméras | P3 | Lisibilité du HUD (aides, énergie, dégâts), vues cockpit / capot / pare-chocs | Lisible, sans masquer la route | **NON TESTÉ** |
| QA-H12 | 0.3 | Monde ouvert | P1 | Parcourir les sept zones en P-01, P-02, P-03 depuis le parc des prototypes, sans téléportation | Aucune chute, aucun blocage, routes continues ; trajets crédibles | **NON TESTÉ** |
| QA-H13 | 0.3 | Routes | P2 | Lisibilité des carrefours, bretelles, lacets de montagne, corniche ; sensation de rues non répétitives | Tracé lisible et varié | **NON TESTÉ** |
| QA-H14 | 0.3 | Trafic / piétons | P2 | Ressenti du trafic PNJ (feux, priorités, réaction au joueur) et des piétons | Comportement crédible, jamais traversé | **NON TESTÉ** |
| QA-H15 | 0.3 | Météo / jour-nuit | P2 | Pluie, brouillard, orage, nuit : visibilité et ressenti d'adhérence | Différences visibles et sensibles, conduite toujours possible | **NON TESTÉ** |
| QA-H16 | 0.4 | Interface progression | P1 | Panneau (touche P / Select) au clavier-souris et à la manette : onglets, sélection, focus, fermeture | Navigation complète sans souris à la manette, aucune action involontaire | **NON TESTÉ** |
| QA-H17 | 0.4 | Garages | P1 | Entrer dans sa propriété, exposer, ranger, sortir un véhicule, le ramener à l'entrée | Une seule voiture conduisible, maquettes à jour, retour refusé loin de l'entrée | **NON TESTÉ** |
| QA-H18 | 0.4 | Préparation | P2 | Réglages, esthétique, pièces au garage public ; ressenti des réglages extrêmes | Effet perceptible, refus clairs des combinaisons irréalisables | **NON TESTÉ** |
| QA-H19 | 0.4 | Visites | P2 | Deux joueurs : invitation, visite, conduite prêtée, révocation pendant la visite et pendant la conduite | Accès refusé sans invitation ; révocation : sortie à l'entrée, descente une fois arrêté | **NON TESTÉ** |
| QA-H20 | 0.4 | Indications de sauvegarde | P2 | Lisibilité du badge d'état (chargement, en attente, sauvegardé, lecture seule) | Jamais « enregistré » avant confirmation | **NON TESTÉ** |

## 3. Essais Studio reportés du lot 0.3 (moteur requis)

Session Studio `monde` (place monde ouvert) : `test-vm.cmd -Place OpenWorld -Sessions monde` (génère la carte puis
la place). Session `lot04` (progression, 2 joueurs) : `test-vm.cmd -Sessions lot04`. Résultats de la campagne du
2026-11-03 dans la colonne « État ».

| Id | Système | Priorité | Essai | Attendu | État |
|---|---|---|---|---|---|
| QA-S01 | Démarrage | P1 | Ouverture de la place monde ouvert, démarrage serveur et client | Aucune erreur ; `OpenWorldService` trouve 9 plots ; message « Serveur initialisé (OpenWorld…) » | **FAIT** — `20261103-030159` : démarrage sans erreur, carte 0.3.0 (37 239 pièces), 9 plots |
| QA-S02 | Apparitions | P1 | Apparition du joueur | Uniquement à `SPAWN-METRO`, hors chaussée ; les 9 prototypes alignés sur leurs plots, face à la route | **FAIT** — `030159` : seule `SPAWN-METRO` active, joueur à 6 st de l'apparition, 9 prototypes posés immobiles (orientation non mesurée) |
| QA-S03 | Physique sur la carte | P1 | Conduite automatisée des P-01/P-02/P-03 sur autoroute, avenue, rue, montagne, chemin, bretelle, pont | Aucune roue qui traverse, pas d'accroche aux raccords de tronçons et disques de carrefour, pentes franchissables | **PARTIEL** — `030159` : autoroute A6-2 à 133,4 km/h sans passer sous la route ; repos sur route de montagne (M1-1), rue, chemin. Défaut trouvé et corrigé (pièces > 2 048 studs, QA-F02). Bretelles, ponts, raccords : **NON TESTÉ** |
| QA-S04 | Streaming | P1 | Traversée rapide (A1 à 130 km/h) avec `StreamingEnabled` | Routes et collisions toujours présentes (modèles persistants) ; aucun arrêt par `PauseOutsideLoadedArea` en conditions normales ; décor chargé avant d'être atteint | **PARTIEL** — `030159` : 13 618 pièces de route reçues (toutes), 397 m à grande vitesse sans perte de sol. Traversée longue (A1 complète) et pause de streaming : **NON TESTÉ** |
| QA-S05 | Streaming / véhicules | P1 | Véhicules d'autres joueurs hors rayon puis de retour | Modèle `Atomic` complet ou absent, jamais partiel ; le simulateur client ne plante pas | **NON TESTÉ** |
| QA-S06 | Météo | P2 | Forçage des quatre états (`WeatherService.force`) | Attributs publiés, ambiance client mise à jour, `AWRoadWetness` lu par le simulateur | **PARTIEL** — `030159` : pluie forcée publiée (`AWRoadWetness` = 1) et reçue par le client. Brouillard, orage, rendu visuel : **NON TESTÉ** |
| QA-S07 | Adhérence mouillée | P1 | Place de développement : freinage 80–0 km/h sur la zone mouillée (`AWWet`) avec et sans `AWRoadWetness` = 1 forcé sur Workspace, puis sur sol sec avec `AWRoadWetness` = 1 | Les trois distances mouillées identiques (réduction appliquée une fois) ; écart avec le banc Lune documenté | **NON TESTÉ** |
| QA-S08 | Horloge | P3 | Cycle complet de 30 min, deux clients | Même heure chez les deux clients (±1 s) | **PARTIEL** — `030159` : écart de 0,002 h avec un client. Deux clients, cycle complet : **NON TESTÉ** |
| QA-S09 | Feux | P2 | Couleur des lampes contre l'arrêt des PNJ | PNJ arrêtés au rouge exactement quand la lampe est rouge | **PARTIEL** — `030159` : 8/8 lampes proches colorées selon la règle. Arrêt des PNJ au rouge observé en jeu : **NON TESTÉ** |
| QA-S10 | Trafic physique | P1 | Joueur qui percute un PNJ, PNJ qui arrive derrière un joueur arrêté, joueur arrêté dans un carrefour | PNJ solide (pas de traversée), poussé puis arrêté ; aucun PNJ projeté en l'air ni bloqué durablement ; propriété réseau des PNJ au serveur | **PARTIEL** — `030159` : 140 agents, 5 corps physiques près du joueur, tous au serveur, aucun tombé ni renversé. Chocs joueur ↔ PNJ : **NON TESTÉ** |
| QA-S11 | Trafic / joueur | P1 | Contact véhicule client ↔ PNJ serveur sous latence | Pas de correction serveur abusive du véhicule du joueur, pas d'interaction avec QA-A01 | **NON TESTÉ** |
| QA-S12 | Trafic | P2 | Apparition et retrait des corps physiques | Jamais à moins de 300 m d'un joueur pour une apparition d'agent ; matérialisation sans chevauchement d'un véhicule de joueur | **NON TESTÉ** |
| QA-S13 | Piétons | P2 | Rendu local autour de la caméra | ≤ 60 figurants, sur les trottoirs, jamais touchés par les lancers de suspension | **PARTIEL** — `030159` : piétons rendus autour de la caméra. Nombre, trottoirs, rayons : **NON TESTÉ** |
| QA-S14 | Dégâts / énergie | P2 | Dégâts, consommation, propriété réseau et caméras du lot 0.2 dans le monde ouvert | Inchangés par rapport à la zone d'essai | **NON TESTÉ** |
| QA-S15 | Retour au plot | P3 | Prototype abandonné loin du parc | Renvoi au plot après 90 s sans joueur à proximité, sans heurter le trafic | **NON TESTÉ** |
| QA-S16 | Non-régression | P1 | Les 7 sessions VM existantes sur la place de développement (`test-vm.cmd`) avec le code du lot 0.3 | Mêmes résultats qu'au lot 0.2 (hors anomalies QA-A01/A02) | **FAIT** — `20261103-023510` (463/3/1) et `20261103-030408` (526/4/1, dernier commit) : échecs uniquement dans les familles QA-A01, QA-A02, QA-A03 |

## 3 bis. Essais reportés du lot 0.4 (persistance et progression)

Toute la logique pure (profils, verrou, migrations, idempotence, environnements, règles de garage) est vérifiée par
Lune **sur l'adaptateur mémoire** ; la persistance RÉELLE n'est pas validée. Les essais DataStore se feront
uniquement dans une expérience Roblox de TEST isolée, après déclaration de son identifiant par le propriétaire dans
`src/server/Persistence/EnvironmentConfig.luau` (jamais l'expérience de production, jamais l'accès Studio aux API
de production).

| Id | Système | Priorité | Essai | Attendu | État |
|---|---|---|---|---|---|
| QA-D01 | DataStore | P1 | Expérience de test isolée : création, sauvegarde, reconnexion, relecture d'un profil réel | Données identiques après reconnexion ; nom de magasin `AW_TEST_Profiles_v1` | **NON TESTÉ** |
| QA-D02 | Verrou | P1 | Changement rapide de serveur (rejoindre un autre serveur juste après avoir quitté) | Chargement après libération (≤ 40 s de reprises), aucune écriture de l'ancien serveur après la nouvelle | **NON TESTÉ** |
| QA-D03 | Verrou | P1 | Arrêt brutal d'un serveur (sans BindToClose) puis reconnexion | Reprise du verrou expiré après ≤ 5 min, journalisée ; aucune perte de transaction confirmée | **NON TESTÉ** |
| QA-D04 | Arrêt serveur | P1 | Fermeture normale (BindToClose) avec plusieurs joueurs, véhicules sortis | Profils sauvegardés et verrous rendus dans le budget de 25 s ; véhicules revenus au garage | **NON TESTÉ** |
| QA-D05 | Déconnexion | P1 | Déconnexion forcée pendant : le choix de départ (quand la liste existera), une sortie de véhicule, une configuration | Aucun doublon, état cohérent à la reconnexion (SCN-01) | **NON TESTÉ** |
| QA-D06 | Écritures incertaines | P1 | Erreurs DataStore réelles (budget épuisé, délai) | Réconciliation par relecture, statut « en attente » puis confirmé, jamais rejoué à l'aveugle | **NON TESTÉ** |
| QA-D07 | Budget | P2 | 24 joueurs : écritures par minute, `GetRequestBudgetForRequestType` | Aucune limitation sur une session normale (sauvegarde 60 s, transactions ≥ 6 s par clé) | **NON TESTÉ** |
| QA-D08 | Restauration | P2 | Restauration ciblée d'un profil depuis une version DataStore (AUD-REST-01) | Procédure documentée exécutée sur des données de test ; transferts plus récents préservés | **NON TESTÉ** (procédure seulement décrite) |
| QA-D09 | Migration | P2 | Première migration réelle (v1 → v2) en déploiement progressif | Ancien serveur en lecture seule sur un profil v2, aucune donnée effacée | **NON TESTÉ** (aucune v2 n'existe) |
| QA-D10 | Taille | P3 | Profil volumineux (milliers de véhicules) | Limite technique explicite, sans perte ; fractionnement à arbitrer | **NON TESTÉ** |
| QA-S17 | Véhicules personnels | P1 | Sortie, conduite, retour : dégâts, énergie et kilométrage restaurés à la reconnexion | Valeurs serveur réconciliées (énergie jamais augmentée, dégâts jamais réduits) | **PARTIEL** — `20261103-030408` : énergie restaurée à la sortie (30 L = 60 % × 50 L). Dégâts et kilométrage après reconnexion : **NON TESTÉ** |
| QA-S18 | Définition réglée | P1 | Exemplaire réglé conduit par son propriétaire : même définition chez le client et le serveur | Aucune correction de mouvement due à un écart de réglages | **NON TESTÉ** |
| QA-S19 | Intérieurs | P2 | Intérieurs privés instanciés (streaming, 10 joueurs dans 10 intérieurs) | Arrivée sans chute, maquettes non conduisibles, sortie à la même entrée | **PARTIEL** — `030408` : entrée physique, maquette exposée, sortie à la même entrée, visiteur reconduit après révocation (2 joueurs). Dix intérieurs simultanés : **NON TESTÉ** |
| QA-S20 | Entrées | P2 | Invites d'entrée sur les 13 emplacements de la carte et les 3 garages publics | Invites présentes, lieux reconnus même secteur non chargé côté client | **PARTIEL** — `030159` : 16 invites présentes dans la carte. Usage de chaque invite : **NON TESTÉ** |
| QA-S21 | Zone d'essai | P2 | Place de développement : entrée et garage public d'essai, données synthétiques (3 prototypes, 1 propriété moyenne, pièces) | Disponibles en Dev seulement, perdues à l'arrêt du serveur (stockage mémoire) | **FAIT** — `030408` : entrée et garage public d'essai, données synthétiques (3 prototypes, 2 propriétés, pièces), environnement « Dev » en mémoire |
| QA-S22 | Non-régression | P1 | Sessions VM existantes après les modifications du service des véhicules (création des enregistrements, participants des collisions) | Résultats identiques au lot 0.2 (hors anomalies connues) | **FAIT** — `030408` : 7 sessions historiques sur le code du lot 0.4, aucune erreur d'exécution, échecs uniquement dans les familles connues |

## 3 ter. Essais reportés du lot 0.5 (économie, métiers, marché)

Les invariants des opérations qui créent de l'argent, transfèrent un actif ou facturent un joueur sont vérifiés par
Lune **sur l'adaptateur mémoire** (`tests/lune/specs/Lot05Economy.luau`), y compris interruptions et répétitions.
Cela ne valide PAS la persistance Roblox ni les transferts entre serveurs réels.

| Id | Système | Priorité | Essai | Attendu | État |
|---|---|---|---|---|---|
| QA-E01 | Transferts réels | P1 | Vente entre deux joueurs sur DataStore d'une expérience de test isolée, puis arrêt brutal entre deux étapes | Transfert terminé ou compensé à la reprise, aucun doublon | **NON TESTÉ** |
| QA-E02 | Inter-serveurs | P1 | Vendeur et acheteur sur deux serveurs différents (boîtes de réception, balayage) | Transfert terminé par le serveur du vendeur, fonds réservés jamais perdus | **NON TESTÉ** |
| QA-E03 | Marché | P2 | Recherche d'annonces avec beaucoup d'annonces (index `Market_Index` borné à 500) | Résultats corrects ; montée en charge à revoir (MemoryStore ou index paginé) | **NON TESTÉ** |
| QA-E04 | Missions en jeu | P1 | Les 8 métiers joués de bout en bout (Dev et monde ouvert), avec véhicule personnel, professionnel et fourni | Étapes reconnues, paiement unique, véhicule temporaire retiré | **FAIT en jeu, place de développement (lot 0.9.1)** — les 8 métiers terminés et payés par le service, chacun au moins une fois, par un pilote automatique (lecture clavier remplacée ; étapes validées par les échantillons du serveur) : 6 métiers dans `20261103-213328`, Taxi et convoyage dans `20261103-224247` (7 / 8 dans cette tâche). Véhicules personnel et fourni. Monde ouvert : **NON TESTÉ**. Voir `docs/lot-0.9/TESTS_INTERACTIFS_AUTONOMES.md` §5 |
| QA-E05 | AUD-ECO-01 | P1 | Joueur sans crédit ni véhicule personnel : mission de livraison avec véhicule professionnel | Paiement normal, aucun véhicule acquis, aucun débit | **NON TESTÉ** (logique Lune seulement) |
| QA-E06 | Énergie en jeu | P1 | Plein, recharge, interruption (départ, véhicule déplacé, serveur arrêté) | Paiement au réel, aucune énergie gratuite, fonds restitués | **PARTIEL (lot 0.9)** — `lot05` : plein facturé au réel, plein inutile refusé ; capacité des pompes (`StationRules`, Lune) ; recharge électrique et interruption en jeu : NON TESTÉ |
| QA-E07 | Concessions | P2 | Achat et reprise dans les deux concessions de la carte ; refus à distance | Exemplaire unique, débit confirmé, reprise ≈ 60 % | **PARTIEL (lot 0.9)** — `lot05` : achat à la concession d'essai, refus à distance, prix du catalogue malgré un prix forgé ; concessions de la carte et reprise : NON TESTÉ |
| QA-E08 | Immobilier | P2 | Achat à l'entrée d'un bien, agrandissement, module, revente avec visiteurs présents | Ratios 70/40/60 %, véhicules exposés rangés, revente refusée si occupée | **NON TESTÉ** |
| QA-E09 | Garage public | P2 | Main-d'œuvre facturée (pièce, esthétique, réglages) ; solde insuffisant | Intervention annulée en entier si le paiement échoue | **PARTIEL (lot 0.9)** — `lot05` : pièce achetée puis revendue (75 %) une seule fois ; main-d'œuvre et solde insuffisant au garage : NON TESTÉ |
| QA-E10 | Interface économie | P1 | Panneau J / stick droit au clavier, souris et manette ; devis, confirmation, état réel ; blocage en mouvement | Jamais de réussite affichée avant confirmation | **NON TESTÉ** (humain) |
| QA-E14 | Guidage de mission | P1 | Mission lancée loin de son départ (Essais dans le monde ouvert : piste de drag à ~4 km) : flèche, distance, étiquette du repère, colonne posée au sol | Objectif trouvé sans connaître la carte ; flèche juste quel que soit l'angle de caméra | **NON TESTÉ** (humain) |
| QA-E11 | Équilibrage | P2 | Revenus horaires réels par métier contre la simulation (`tools/economy/simulate.luau`) | Écarts compris et documentés | **NON TESTÉ** |
| QA-E12 | Lavage | P3 | Salissure visible et lavage | Teinte rendue à la prochaine sortie ; aucune réparation | **NON TESTÉ** |
| QA-E13 | Bornes | P3 | Occupation d'une borne par plusieurs joueurs | Pas de blocage abusif (session limitée à 180 s) ; réservation par borne non implémentée | **NON TESTÉ** |

## 3 quater. Essais reportés du lot 0.6 (courses, matchmaking, compétition, saisons)

Les règles (départs, faux départs, points de contrôle, tours, temps, drift, classement, abandons), les réservations,
les modes protégé et réaliste, les récompenses, le classement, les saisons et la récupération sont vérifiés par
Lune sur des échantillons SYNTHÉTIQUES et l'adaptateur MÉMOIRE (`tests/lune/specs/Lot06Racing.luau`). Cela ne valide
ni la conduite réelle en course, ni la persistance Roblox, ni l'inter-serveurs.

| Id | Système | Priorité | Essai | Attendu | État |
|---|---|---|---|---|---|
| QA-R01 | Matchmaking inter-serveurs | P1 | `CrossServerAdapter` dans une expérience de test isolée : file MemoryStore, serveur réservé, téléportation des participants confirmés | Match formé entre serveurs, transition explicite, réservations conservées | **NON TESTÉ** (code jamais exécuté) |
| QA-R02 | Reconnexion après transfert | P1 | Déconnexion pendant une épreuve puis retour (même serveur, autre serveur, après téléportation) | Reprise dans ~90 s au dernier point validé ; sinon issue « Disconnected » ; aucun double paiement | **NON TESTÉ** (logique Lune seulement) |
| QA-R03 | Résilience DataStore | P1 | Résultats et réservations sur DataStore réel : arrêt du serveur de course entre la publication `Race_<id>` et l'application, profil verrouillé ailleurs | Résultat appliqué une fois par le serveur du profil ; engagement échu résolu (mode protégé restauré) | **NON TESTÉ** |
| QA-R04 | Tableaux durables | P2 | Tableaux de saison et records sur OrderedDataStore (`CrossServerAdapter`) | Valeurs correctes, records conservés au meilleur | **NON TESTÉ** |
| QA-R05 | Collisions en course sous latence | P1 | Départ groupé de grille, dépassements et contacts à 2–8 joueurs, latences différentes (anomalies QA-A01 à A04) | Résultats confirmés ou « non confirmés » à réconcilier, jamais de sanction d'une anomalie réseau | **NON TESTÉ** |
| QA-R06 | Charge | P1 | 24 joueurs dont plusieurs épreuves simultanées (échantillonnage à 10 Hz, instantanés à 2 Hz) | Fréquence serveur stable, coût par participant mesuré | **NON TESTÉ** |
| QA-R07 | Équilibrage réel | P2 | Gains réels par discipline et mode contre `tools/economy/simulate-races.luau` et les métiers ; coûts réels du mode réaliste contre l'estimation (énergie, usure) | Écarts mesurés et documentés ; métiers toujours compétitifs | **NON TESTÉ** |
| QA-R08 | Exploitabilité du classement | P2 | Arrangements entre comptes, abandons volontaires, déconnexions répétées en classé | Gains réduits face aux mêmes adversaires, signalement, aucune sanction automatique | **NON TESTÉ** |
| QA-R09 | Anti-triche en situation réelle | P1 | Raccourcis, sorties de tracé, véhicule de quelqu'un d'autre, faux départs, vitesse invraisemblable | Points manqués non validés, pénalités, arrivées non confirmées | **NON TESTÉ** (logique Lune seulement) |
| QA-R10 | Six disciplines en jeu | P1 | Sprint, circuit, contre-la-montre, drift, drag, rallye joués de bout en bout (place de développement et monde ouvert), modes protégé et réaliste | Départs, points, tours, arrivées, résultats confirmés, récompenses, véhicule libéré | **FAIT en Studio (lot 0.9)** — `20261103-185530` : les six disciplines jouées jusqu'au résultat par un pilote automatique (sprint officiel à deux, drag, contre-la-montre, circuit 3 tours, rallye, drift) ; place de développement seulement ; jeu humain et monde ouvert : NON TESTÉ |
| QA-R11 | Drift en jeu | P2 | Score sur une vraie conduite (angles, transitions), rotation à l'arrêt, chocs, sortie de zone | Pas de gros score sans dérive maîtrisée | **FAIT en jeu (lot 0.9.1)** — épreuve officielle DEV-DRIFT, véhicule personnel P-01 (propulsion, sans aide), pilote de dérive : **score 310 calculé par le serveur** (`20261103-213328`, 25 lancements, angle max 72°). Rotation à l'arrêt, chocs et sortie de zone : modèle Lune seulement. Ressenti : humain |
| QA-R12 | Drag en jeu | P2 | Arbre de départ, faux départ réel, boîtes manuelle et automatique, temps de réaction | Feux synchronisés sur l'horloge serveur, aucune assistance imposée | **PARTIEL (lot 0.9)** — drag d'entraînement : réaction 1,65 s, 11,9 s, 113 km/h ; faux départ réel au sprint pénalisé de 5 s (`20261103-184407`) ; boîte manuelle et faux départ au drag : NON TESTÉ |
| QA-R13 | Météo normalisée | P2 | Course classée sous la pluie du monde : adhérence du véhicule engagé, puis retour aux conditions du monde après l'épreuve | Adhérence sèche standardisée pendant l'épreuve seulement ; météo du monde inchangée | **NON TESTÉ** |
| QA-R14 | Interface courses | P1 | Panneau K / stick gauche au clavier, souris et manette ; affichage de course lisible sans masquer la conduite ; repères | Utilisable, aucune action de conduite bloquée | **NON TESTÉ** (humain) |
| QA-R15 | Ressenti | P2 | Ressenti des départs, de la grille, des pénalités et du drift par le propriétaire | Avis consigné | **NON TESTÉ** (humain) |
| QA-R16 | Installations | P3 | Portiques, places et dalles d'inscription posés au sol sur les 16 parcours (relief, ponts) | Aucun élément flottant ni enterré, aucun obstacle sur la trajectoire | **NON TESTÉ** |
| QA-R17 | Mode protégé en jeu | P1 | Course protégée avec dégâts antérieurs, chocs pendant la course, sortie brutale du jeu | Dégâts antérieurs conservés, dégâts de course effacés, rien réparé gratuitement | **NON TESTÉ** (logique Lune seulement) |

## 3 quinquies. Essais reportés du lot 0.7 (interface, GPS, smartphone, social)

Les règles (itinéraires, recalcul, projection, points d'intérêt, pile d'écrans, focus, blocage en conduite,
raccourcis, confirmations, notifications, groupes, partage de position, filtrage, localisation, préférences) sont
vérifiées par Lune (`tests/lune/specs/Lot07Interface.luau`). Cela ne valide ni l'affichage réel, ni l'ergonomie,
ni les communications Roblox, ni la confidentialité en multijoueur réel.

| Id | Système | Priorité | Essai | Attendu | État |
|---|---|---|---|---|---|
| QA-U01 | Parcours utilisateur | P1 | Parcours complet : à pied, téléphone, carte, destination, conduite guidée, mission, course, garage, marché | Navigation cohérente, une seule fenêtre à la fois, focus rendu | **PARTIEL (lot 0.9.1)** — parcours par **vrais clics et vraies touches dans la VM** (pont d'entrées, `20261103-195821` → `20261103-224247`) : arrivée, garage (6 onglets, saisie de texte), économie (6 onglets, métier, concession, marché), courses, classements, téléphone (applications, paramètres), carte, destination, mode photo (par le téléphone), HUD, conduite. Une fenêtre à la fois vérifiée ; ergonomie et ressenti : humain |
| QA-U02 | GPS réel | P1 | Guidage sur plusieurs km avec trafic PNJ et streaming réel des secteurs ; sortie d'itinéraire et recalcul | Indications justes et à temps, recalcul sans saccade, aucun gel | **PARTIEL (lot 0.9.1)** — conduite réelle guidée par le GPS du jeu dans le monde ouvert (`20261103-220054`) : 5 arrivées sur 7 zones (24,5 km, voies rapides et autoroute comprises), trafic PNJ et streaming réels ; destination de montagne refusée (QA-F20, corrigé, itinéraire calculé ensuite) ; Montagnes et Motorsport non atteints (pilote) ; notification de recalcul observée, non mesurée. **Lot 0.9.2** : Montagnes et Motorsport atteints en conduite réelle, sans téléportation (`20261104-031929`) ; sortie d'itinéraire par une autre route, recalcul après 22-23 s (`031929`, `050215`) ; campagne finale `050215` : 4 arrivées sur 7 (Banlieues, Littoral, Docks, Motorsport), pilote coincé vers Métropole et Montagnes, Campagne non atteinte. Sur le code du lot 0.9.2 : 5 zones sur 7 atteintes, jamais les 7 dans une même tâche |
| QA-U03 | Clavier / manette | P1 | Navigation complète à la manette ; passage clavier ↔ manette pendant une confirmation ; touches personnalisées | Aucune accélération ni confirmation involontaire, focus toujours récupérable | **NON TESTÉ** (humain) |
| QA-U04 | Lisibilité | P2 | Résolutions (720p à 4K, ultra-large), tailles de texte, contraste renforcé, opacité | HUD et téléphone lisibles sans masquer la route | **NON TESTÉ** |
| QA-U05 | Conduite et menus | P1 | Ouvrir un panneau à l'arrêt puis démarrer ; ouvrir le téléphone en roulant | Mode rapide ou masquage avec brouillon, aucune validation, aucun freinage | **FAIT par vraies touches (lot 0.9.1)** — garage refusé en roulant, téléphone en mode rapide, accélérateur ignoré menu ouvert ; véhicule qui rampait menu ouvert (QA-F18, corrigé) : immobile après correction (`20261103-224247`). Ressenti : humain |
| QA-U06 | Charge sociale | P2 | 24 joueurs, 3 groupes de 8, partage de position actif | Envois par destinataire stables, aucune fuite de position | **NON TESTÉ** |
| QA-U07 | Communications | P1 | Canaux texte de groupe et de proximité sous les règles Roblox (âge, confidentialité, modération), comptes restreints | Messages filtrés par Roblox, refus respectés, aucun contournement | **NON TESTÉ** |
| QA-U08 | Confidentialité multijoueur | P1 | Deux joueurs dans un groupe : aucune vue du solde, de la collection, des propriétés ; partage désactivé par défaut puis révoqué | Rien de privé reçu (inspection des messages réseau) | **FAIT à deux clients (lot 0.9.1)** — `20261103-203223` : 79 messages reçus par le joueur 2 inspectés côté serveur, ni le solde ni les 3 exemplaires du joueur 1 ; partage de position seulement avec consentement, arrêté sur demande. Communications Roblox (QA-U07) non couvertes |
| QA-U09 | Préférences sur DataStore | P2 | Préférences sauvegardées puis retrouvées après reconnexion, sur une expérience de test isolée ; changements rapides répétés | Retrouvées ; aucune écriture par changement visuel | **NON TESTÉ** (mémoire seulement) |
| QA-U10 | Téléphone en main | P2 | Modèle dans la main (R15, R6), bras levé, rangement, vu par les autres joueurs | Pose correcte, écran générique pour les autres | **PARTIEL (lot 0.9.1)** — modèle en main constaté par le serveur et sur capture (`20261103-220054` 091, `20261104-012609` 032) ; **bras non levé** (QA-A10) ; vu par un autre joueur : NON TESTÉ. **Lot 0.9.2** : bras levé (QA-A10 corrigée), téléphone devant le personnage et dans la main, aussi en marchant (`20261104-031929`, `-050215`). **Lot AVATAR-01** : **vu par un autre joueur** (bras à 55°, téléphone dans la main, `20261104-111326`, `avatar2`) ; 8 morphologies R15 et place passager (téléphone à 0,29 st de la main) ; R6 : sans objet (R15 seul) |
| QA-U11 | Mini-carte et carte | P2 | Coût du dessin (mini-carte 5 Hz, carte), lisibilité des routes et des icônes, rotation | Images par seconde stables ; dessin lisible | **PARTIEL (lot 0.9.1)** — mini-carte et carte relevées sur captures (Dev et monde ouvert) ; coût du dessin non mesuré |
| QA-U12 | Localisation | P2 | Relecture FR/EN de tous les textes, longueur des textes anglais dans les cadres | Aucun débordement, traductions justes | **NON TESTÉ** (lot 0.8 : panneaux des lots 0.4–0.6 traduits, contrôle automatique des clés seulement ; relecture humaine à faire) |
| QA-U13 | Notifications en conduite | P2 | Différées, compactes et critiques pendant une conduite réelle ; aide visuelle | Route dégagée, alertes critiques perçues | **NON TESTÉ** (humain) |

## 3 sexies. Essais reportés du lot 0.8 (rendu, gamme, audio, radio, photo, arrivée)

Les règles pures (fiches et définitions des 18 modèles, catalogue, séparation des actifs provisoires, conditions et
unicité du véhicule de départ, propriété gratuite, isolation des essais, mode photo, radio, réglages audio et
graphiques, localisation, migrations, manifeste, place passager) sont vérifiées par Lune
(`tests/lune/specs/Lot08Content.luau`) et pytest (`tests/test_lot08.py`). Cela ne valide ni le rendu, ni le son
réel, ni le ressenti, ni le comportement multijoueur.

| Id | Système | Priorité | Essai | Attendu | État |
|---|---|---|---|---|---|
| QA-V01 | Direction artistique | P2 | Validation artistique humaine : carrosseries des 10 silhouettes, habitacles, habillage des 7 zones, étalonnage jour/nuit, effets par qualité | Cohérent, lisible, conforme à `DIRECTION_ARTISTIQUE.md` | **NON TESTÉ** (humain) |
| QA-V02 | Gamme de 18 | P1 | Essais réels des 18 modèles (accélération, freinage, virage, vitesse de pointe, boîtes, aides) dans Studio puis par un humain | Comportement conforme aux fiches ; valeurs du banc planaire confirmées ou corrigées | **PARTIEL (lot 0.9)** — banc en jeu 18 / 18 (`20261103-170323`) : 0–100 km/h à +2–6 % du banc planaire (boîtes non manuelles), +15–24 % (manuelles, pilote du test) ; ressenti : NON TESTÉ (humain) |
| QA-V03 | Carrosseries et collisions | P1 | Coque, boucliers et habitacle collidables des 10 silhouettes : chocs, sortie, dommages du lot 0.2, place passager | Aucune pièce coinçante, sortie possible, dommages visibles | **NON TESTÉ** |
| QA-V04 | Sons moteur | P2 | Ressenti des moteurs et des sons (après téléversement par le propriétaire) : fondus de couches, électrique, calage | Sons crédibles, fondus sans saut | **NON TESTÉ** (aucun son téléversé : rien n'est joué en jeu) |
| QA-V05 | Audio spatial | P2 | Atténuation par distance, nombre de véhicules sonorisés par qualité, ambiances par zone et pluie | Spatialisation correcte, aucune saturation | **NON TESTÉ** |
| QA-V06 | Radio multijoueur | P1 | Conducteur et deux passagers : changer de station, couper chez un passager, régler les volumes, sortir du véhicule ; joueur extérieur | Station commune pilotée par le conducteur ; coupure et volume individuels ; rien entendu dehors (SCN-19) | **NON TESTÉ** (stations indisponibles tant que les pistes ne sont pas téléversées) |
| QA-V07 | Mode photo complet | P1 | À pied, conducteur arrêté, passager ; caméra contre un mur et près d'une propriété ; ouverture en course ; masquage et restauration ; capture et enregistrement | Caméra bornée, aucun mur traversé, refus en course, restauration exacte, capture proposée (SCN-20) | **PARTIEL (lot 0.9.1)** — ouverture par le téléphone, zoom, filtre, quitter par vrais clics, caméra restaurée (`20261103-224247`) ; touche O jamais reçue dans Studio (limite connue, à vérifier dans le client Roblox) ; capture et enregistrement : NON TESTÉ |
| QA-V08 | Parcours d'arrivée | P1 | Onboarding avec des comptes réels : nouveau joueur, passage de l'introduction, essai, choix confirmé, reconnexion pendant le choix, joueur existant (migration 4 → 5) | Un seul véhicule, propriété unique, parcours non imposé aux anciens joueurs | **FAIT par vrais clics (lot 0.9.1)** — étapes, choix annulé puis confirmé, entrée dans le monde (`20261103-200648` et suivantes) ; défaut QA-F13 (confirmation hors de vue) corrigé ; comptes réels et reconnexion : NON TESTÉ |
| QA-V09 | Protection d'apparition | P2 | Véhicule lancé sur un nouveau joueur pendant 60 s ; fin à la montée en voiture | Aucun choc subi ; protection levée ensuite | **NON TESTÉ** |
| QA-V10 | Exercices | P3 | Les 8 exercices en jeu, dont stationnement et changement de rapport en boîte automatique | Réussite détectée, aucun crédit | **NON TESTÉ** |
| QA-V11 | Performances du rendu | P1 | Images par seconde et mémoire avec l'habillage (≈ 47 650 pièces), nuit avec sources de lumière, qualités basse à haute | Mesure réelle ; aucun objectif déclaré atteint | **NON TESTÉ** |
| QA-V12 | Compatibilité des actifs | P2 | Téléversement réel des 30 sons (modération, formats), puis lecture en jeu | Acceptés et joués | **NON TESTÉ** (propriétaire) |
| QA-V13 | Charge à 24 joueurs | P1 | 24 joueurs avec feux, sons et radio actifs | Fréquence stable | **NON TESTÉ** |
| QA-V15 | Focus de la fenêtre d'arrivée | P2 | Ouverture automatique au clavier, à la souris puis à la manette, dans un vrai client (hors Studio) ; vérifier que la cause du gel (sélection imposée, corrigée au lot 0.8) ne touche aucune autre fenêtre ouverte d'elle-même | Aucun gel ; focus seulement à la manette | **NON TESTÉ** (hors Studio) |
| QA-V14 | Manette | P2 | Téléphone sur Select, invite d'entrée sur X, mode photo par l'application Photo, garage par le téléphone | Aucun conflit de touches | **NON TESTÉ** (humain) |

## 3 septies. Essais reportés du lot VEH3D-01 (Comète 3D, moteur requis)

**Finalisation du 2026-11-05** : état détaillé, anomalies corrigées et actions du propriétaire dans
`docs/vehicle-3d/VEH3D_01_CLOTURE.md` (sessions `comete`, `comete_perf`, `comete_avatar`, `comete2`). Nouveaux constats :
sorties conducteur 8 / 8 et passager 8 / 8 en échec sur la Comète (`20261105-015804`), **corrigées** (`a0debec`,
groupe de collision `AWSortie` ; 16 / 16 dans `20261105-023349`, Comète seule) ;
D5 non mesurable dans la VM (temps de rendu à 0) ; pose de jeu « Sportive » : 8 morphologies, pieds posés, têtes sous le pavillon mesuré (16 / 16, `20261105-023349`).

Contrôlé hors Studio (Lune, 2026-11-04) : gabarit, identifiants, données du kit, repli. Tout ce qui suit dépend du moteur.
Identifiants QA-K (kit de maillages) : les QA-V01 à V09 sont ceux des lots 0.8 et 0.9 (§3 sexies et précédents).
Session VM : `test-vm.cmd -Sessions comete -GuiInput` (`tests/studio/CometeServer.server.luau`, `CometeClient.client.luau`).

| Id | Essai | Attendu | État |
|---|---|---|---|
| QA-K01 | Apparition de la Comète | Carrosserie 3D soudée, sans masse, posée sur ses roues ; les 17 autres véhicules gardent leur carrosserie provisoire | **FAIT (VM, `20261105-002227`)** — 28 maillages posés, sans masse ni collision, soudés ; CG à 1,50 st du sol (définition 1,50), assiette 1,000 ; P-01 apparu avec sa carrosserie provisoire (30 primitives, 0 pièce du kit). Les 16 autres modèles : contrôle Lune seulement (kit pour la seule Comète) |
| QA-K02 | Maillages vus par la VM | Les maillages envoyés par le propriétaire se chargent dans la session de test (droits d'usage des actifs) | **FAIT dans le Studio de la VM (`20261105-002227`)** — 34 contenus distincts chargés (`Success`), 0 échec, 0,4 s, compte de test. Chargement dans l'expérience publiée : NON TESTÉ |
| QA-K03 | Roues | Pneus et jantes tournent et braquent avec les roues du jeu ; voie visuelle 3,5 à 4,7 cm en retrait accepté | **FAIT (VM, `20261105-002227`)** — pneus et jantes soudés aux 4 roues ; braquage du pneu avant gauche 35,3° (vraie touche A) ; jante 5 766° de rotation sur 16 st (vraie touche W, 41,6 km/h max). Retrait de la voie : constaté sur les captures, non mesuré en jeu |
| QA-K04 | Embarquement et pose | Invites conducteur et passager ; sièges avec `AWSeatPose` ; têtes, mains et pieds dans l'habitacle (3,38 st d'assise au pavillon) | **PARTIEL (VM, `20261105-002227`)** — invites « Conduire » et « Monter (passager) » présentes ; `AWSeatPose` posé ; assise par `Seat:Sit` (instrumenté) ; avatar par défaut : tête à 2,30 st (haut de la boîte Habitacle 2,53), mains |x| 1,73 / 2,24 (flanc 3,49), pieds au-dessus du sol ; sorties par vraies touches F et Espace. Invite E réelle, autres morphologies, marge sous le pavillon du maillage : NON TESTÉ |
| QA-K05 | Caméras | Vues cockpit, capot et bouclier aux repères mesurés ; volant 10° sous la visée | **FAIT (VM, `20261105-002227`)** — vues cockpit, capot et bouclier atteintes par la vraie touche V, repères à ±0,01 st, captures. Volant 10° sous la visée : règle vérifiée en Lune, non mesurée en jeu |
| QA-K06 | Collisions et dégâts | Chocs avant, arrière et latéraux ; zones de dégâts reconnues ; aucune collision sur les maillages visuels | **PARTIEL (VM, `20261105-002227`)** — choc avant contre `MurDeChoc` à 41,6 km/h (zone avant 1,00, moteur 0,38) ; choc arrière en marche arrière à 21,8 km/h (zone arrière 0,41) ; aucun bloc opaque après les chocs (défaut corrigé, voir VEH3D-01 §7) ; R engagée par l'appel de test (Ctrl jamais reçu par le jeu dans Studio). Choc latéral : NON TESTÉ (véhicule vide lancé par le serveur plafonné à 3 m/s par la validation anti-éjection). Dégâts visuels sur les maillages : non représentés (rayures seulement) |
| QA-K07 | Vitrage et feux | Vitrage sombre transparent ; phares et feux allumés la nuit (sources invisibles ; maillage des feux non lumineux, feux non séparés dans le `.rbxm` reçu) | **FAIT pour les sources (VM, `20261105-002227`)** — 4 / 4 sources allumées la nuit, vitrage 2 / 2 transparent (≥ 0,3). Captures : lueur rouge à l'arrière ; maillage des phares non lumineux (feux non séparés) ; **vitres latérales noires vues de l'extérieur**, avatar invisible : ce sont bien des pièces de verre (`COMETE_Vitrage_glass`, 9 faces par côté, rayons traversants vérifiés dans Blender le 2026-11-05), c'est le réglage du jeu (verre sombre 28/32/38, transparence 0,45, matériau Glass) qui les assombrit. Comparatif de 5 réglages dans la VM (`20261105-003353`) : conducteur visible avec C (verre clair 120/135/145, 0,6), D ou E. **Réglage C choisi par le propriétaire le 2026-11-05**, appliqué (`a61a11c`) ; session `comete` `20261105-005339` : 59 / 1 (Ctrl), conducteur visible par la vitre latérale sur les captures |
| QA-K08 | Performances D5 | 24 Comète visibles, jour et nuit : temps d'image ≤ référence + 2 ms | **NON CONCLUANT (`20261105-002227`)** — 24 Comète contre 24 P-01 immobiles : moyenne 16,66 / 16,66 ms le jour, 16,91 / 16,66 ms la nuit ; P95 18,56 / 18,68 et 18,81 / 18,51 ms. Studio de la VM plafonné à 60 images/s : écart invisible sous le plafond. Mesure D5 sur un poste réel : NON TESTÉ |

## 3 octies. UI V1.2 et audit d'intégration V1.0 (2026-11-05)

Constats relevés dans les rapports VM existants (aucune nouvelle exécution) et dans le code.

| Id | Priorité | Constat | État |
|---|---|---|---|
| QA-A24 | P3 (défaut du banc, 2026-11-05) | **Banc des 18 modèles (`lot08.client.banc_18_modeles`) : régression.** 18 / 18 à `c352f26` (lot 0.9.2, `20261104-042820`) ; 10 / 18 à `84cefab` (`20261105-141629`) et `bcfbae6` (`20261105-132615`). « Embarquement impossible » pour Zénith, Dune, Éclat, Comète, Vigie, Sentier, Atlas, Mistral (invite affichée, siège non occupé, conducteur 0). Classé à tort « identique sur la base » dans `docs/ui/UI_V1_2_FINALISATION_RAPPORT.md` §4 | **Ouverte, cause non établie** (commits suspects : AVATAR-01, Aster phase 1, VEH3D-01 ; audit §6.2). Lecture du code (2026-11-05, `docs/audit/DIAGNOSTIC_QA_A24.md`) : échecs à partir de la 11ᵉ itération quel que soit le modèle, refus silencieux du serveur ; hypothèses H1 à H3. Essai du propriétaire (2026-11-05) : sortie pendant un choc puis montée dans la Mistral **OK**, non reproduit. **Session VM ciblée `20261105-183402`** (banc 13 / 18) : pour chaque échec, le serveur ne reçoit jamais l'invite ; personnage normal. Défaut du banc (activation de l'invite par script), pas du jeu ; échecs liés au modèle, mécanisme exact non établi ; correction du banc proposée. Diagnostic : essai d'embarquement manuel par le propriétaire, ou session VM ciblée sur son accord |
| QA-A25 | P3 | Choix de silhouette : un clic pendant le chargement de l'apparence est refusé, il faut recliquer | Ouverte ; proposé : griser les boutons tant que l'apparence n'est pas prête |
| QA-U14 | P2 | Navigation des interfaces V1.2 à la manette réelle | NON TESTÉ (la VM n'envoie aucune manette) |
| QA-U15 | P3 | Interfaces V1.2 sur écrans réels 1080 p, 1440 p, ultralarge (essais VM sur écran virtuel) | NON TESTÉ |
| QA-U16 | P2 | GPS sur le code V1.2 (tâche `20261105-155234` coupée) ; essai `ui_hud` corrigé, non relancé | NON TESTÉ |
| QA-U17 | P3 | Téléphone en main en marchant (monde ouvert) : bras levé de 8° mesurés contre 25° attendus (`20261105-154646`), lien avec QA-A20 et QA-U10 | Ouverte, non classée |
| QA-D11 | P1 (avant publication) | Une place publiée dont l'identifiant n'est pas déclaré dans `EnvironmentConfig` est traitée en « Dev / mémoire » : crédits synthétiques (`DevSeed`) attribués et modèles en attente achetables (`Environment.luau`, `ProfileService.luau`) | Ouverte : déclarer les identifiants ou refuser le mode Dev hors Studio avant toute publication |

## 3 nonies. Lot BASE-01 — base propre à deux véhicules (2026-11-05)

Les 17 modèles, les prototypes, le parc d'essai et les carrosseries provisoires sont retirés du jeu
(`docs/lot-base-01/RAPPORT_BASE_01.md`).

**Sans objet** désormais (constats propres aux carrosseries provisoires ou aux modèles retirés) :
- QA-A13 et A14 : pavillons bas, jambes dans la planche de bord ;
- QA-A17 : pieds sous le plancher ;
- QA-A21 : tête contre le toit (Dune, Sentier) ;
- QA-A15, A16 et A18 sur les 17 autres modèles : la Comète est corrigée ;
- QA-A24 : banc des 18 modèles.

| Id | Priorité | Constat | État |
|---|---|---|---|
| QA-B01 | P2 | Sessions VM qui supposent le parc d'essai ou les modèles retirés : `lot02`, `lot04`, `lot06`, `lot08`, `scenarios`, `monde`, `gps`, `ui*`, `avatar*`, `comete*` (fichiers de `tests/studio` qui citent `proto_p0x`, `wk_…`, `VehiculesEssai`) | **NON ADAPTÉES** : elles se compilent (`verify.ps1`) mais échoueraient à l'exécution ; à reprendre si une campagne VM est relancée |
| QA-B02 | P2 | Arrivée sans véhicule de départ, métiers à véhicule fourni refusés (« NoProfessionalVehicle »), concession limitée à la Comète en Dev | **Validé en jeu par le propriétaire le 2026-11-05** (rapport BASE-01 §6) |
| QA-B03 | P3 | Reproductions QA-A08 et du calage par rebond liées aux modèles retirés (10 cas de la Mistral, rebond de l'Atlas) : non rejouables sur les jeux d'essai | Couverture réduite, consignée ; les 3 cas du P-01 et la règle de relance restent testés |

## 4. Charge, performance et stabilité

| Id | Système | Priorité | Essai | Attendu | État |
|---|---|---|---|---|---|
| QA-P01 | Serveur | P1 | 24 joueurs répartis dans les zones, trafic à 140 agents | Fréquence serveur stable ; coût de `TrafficService` mesuré par pas | **NON TESTÉ** |
| QA-P02 | Client | P1 | Images par seconde sur un appareil de référence (ordinateur et mobile), métropole dense, pluie, nuit | Mesure réelle ; **aucun objectif (~60 FPS) n'est déclaré atteint** | **NON TESTÉ** |
| QA-P03 | Mémoire | P2 | Mémoire client et serveur avec la carte complète (≈ 47 650 pièces depuis le lot 0.8) et le streaming | Mesure réelle, comparaison avec et sans streaming | **NON TESTÉ** |
| QA-P04 | Réseau | P2 | Bande passante par joueur (trafic physique, véhicules, attributs météo) | Mesure réelle | **NON TESTÉ** |
| QA-P05 | Démarrage | P2 | Temps de démarrage serveur (calcul `WorldLayout`, `TrafficModel.newWorld`) et client (index des trottoirs) | Mesure réelle | **NON TESTÉ** |
| QA-P06 | Stabilité | P2 | Session longue (≥ 2 h) | Pas de fuite (corps PNJ, figurants), pas de blocage du trafic | **NON TESTÉ** |
| QA-P08 | Profils | P2 | Coût des copies de profil par transaction (profil volumineux) et des instantanés envoyés aux clients | Mesure réelle | **NON TESTÉ** |
| QA-P09 | Intérieurs | P3 | Coût des maquettes exposées (jusqu'à 10 par intérieur) | Mesure réelle | **NON TESTÉ** |
| QA-P07 | Réglages | P3 | Budget PNJ (140), rayon physique (260 m), plafond (48), rayon des piétons (150 m), rayons de streaming | Réglages ajustés d'après QA-P01 à P04 | **NON TESTÉ** |

## 5. Vérifications de la dernière exécution hors Studio

Campagne Studio groupée du 2026-11-03 : [`QA_CAMPAGNE_2026-11-03.md`](QA_CAMPAGNE_2026-11-03.md).

Ces contrôles automatiques ne remplacent aucun essai ci-dessus. Résultats et commandes : `docs/lot-0.3/RAPPORT_LOT_0.3.md` §2 et
`docs/lot-0.4/RAPPORT_LOT_0.4.md` §2.
