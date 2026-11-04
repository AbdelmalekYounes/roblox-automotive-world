# Roadmap indicative — cahier des charges officiel v1.0

L'ordre décrit des lots de travail, pas une réduction du périmètre final.

| Version de développement | Résultat attendu |
|---|---|
| 0.0.1 | Socle Rojo/Luau, démarrage client/serveur, documentation, tests statiques |
| 0.1 | Première voiture originale pilotable, entrée clavier/manette, conduite différenciable, métriques élémentaires |
| 0.2 | Physique avancée, transmissions, pneus, suspension, ressources et dégâts |
| 0.3 | Monde ouvert à sept zones, circulation et infrastructures |
| 0.4 | Profils persistants, collection, propriétés, garages, configurations |
| 0.5 | Crédits, huit familles de missions, concession et marché d'occasion |
| 0.6 | Six disciplines, compétitions réalistes/protégées, saison classée |
| 0.7 | Smartphone, HUD, GPS, social, permissions, accessibilité |
| 0.8 | Art, audio, radio, mode photo, onboarding, FR/EN |
| 0.9 | Tests intégrés, sécurité, anti-abus, performance et résilience |
| 1.0 | Vérification du périmètre complet et GO/NO-GO avant ouverture publique |

## État du lot 0.1 (branche `feat/vehicle-vertical-slice-0.1`)

- Code livré : zone d'essai isolée, prototype P-01, conduite clavier/manette, dynamique paramétrable, validation serveur.
- Vérifié hors Studio : build Rojo, lint Selene, format StyLua, typage strict luau-lsp, 100 tests Lune, 8 contrôles pytest.
- Vérifié dans Roblox Studio (VM VMware, `test-vm.cmd`, 6 sessions) : collisions entre joueurs corrigées (poussée du
  même ordre qu'un véhicule garé), propriété réseau vérifiée (refus, correction, déconnexion), arbitrages A1–A6 appliqués.
- **Ouvert avant clôture** : anomalie intermittente (mouvement d'un véhicule piloté qui n'atteint pas le serveur
  pendant quelques secondes), essais humains clavier/manette/chat et ressenti. VM de test restreinte au dossier d'échange.
- Rapports : `docs/lot-0.1/RAPPORT_VALIDATION.md` (final), `RAPPORT_TESTS.md` (historique) ; écarts et arbitrages :
  `docs/lot-0.1/ECARTS.md` ; proposition qui a servi de base au lot 0.2 : `docs/lot-0.1/PROPOSITION_LOT_0.2.md`.

## État du lot 0.2 (branche `feat/advanced-vehicle-physics-0.2`, PR brouillon #2, base : lot 0.1)

Commencé à la demande du propriétaire alors que la PR #1 n'est pas fusionnée (exception explicite à la règle
« un lot clôturé avant le suivant » de `CLAUDE.md`) ; le lot 0.1 reste intact sur sa branche.

- Livré : moteurs essence / diesel / électrique, six boîtes (automatique à convertisseur, manuelle, double embrayage,
  séquentielle, CVT, rapport unique), FWD/RWD/AWD et autobloquants, pneus (frottement statique, glissement combiné,
  relaxation, mouillé), ABS / antipatinage / ESP par modèle, énergie et dégâts de session confirmés serveur,
  caméras cockpit / capot / pare-chocs, prototypes P-02 et P-03, configurations de validation DCT / SEQ / CVT.
- Rapport : `docs/lot-0.2/RAPPORT_LOT_0.2.md` ; écarts : `docs/lot-0.2/ECARTS.md` ; architecture :
  `docs/lot-0.2/ARCHITECTURE_LOT_0.2.md`.
- Hors périmètre, prévus aux lots suivants : monde ouvert, stations et recharge payantes, crédits, profils et
  persistance (dont dégâts et énergie, lot 0.4), garages, compétitions, smartphone/GPS, catalogue des 18 modèles.

## État du lot 0.3 (branche `feat/open-world-map-0.3`, PR brouillon, base : lot 0.2)

Commencé à la demande du propriétaire alors que les PR #1 et #2 ne sont pas fusionnées ; les lots précédents restent
intacts sur leurs branches. Décision du propriétaire : essais humains, non-régression approfondie et charge regroupés
dans un lot QA ultérieur (`docs/QA_BACKLOG.md`).

- Livré : carte d'un seul tenant à sept zones en maquette (1 285 carrefours, 2 224 tronçons), générée hors ligne de
  façon déterministe ; infrastructures aux quantités du cahier des charges (emplacements et volumes) ; graphe routier
  (A*) ; trafic PNJ (virtuel / physique) et piétons ; météo et cycle jour/nuit de 30 min ; humidité de chaussée
  appliquée une seule fois ; place monde ouvert avec streaming ; zone d'essai conservée dans la place de développement.
- Vérifié hors Studio uniquement (187 tests Lune, 9 pytest, typage strict) ; **aucun essai Studio ni humain**.
- Rapport : `docs/lot-0.3/RAPPORT_LOT_0.3.md` ; architecture : `docs/lot-0.3/ARCHITECTURE_LOT_0.3.md`.

## État du lot 0.4 (branche `feat/properties-garages-persistence-0.4`, PR brouillon, base : lot 0.3)

- Livré : profils versionnés (schéma v1, migrations, verrou exclusif à génération, reprise des verrous expirés,
  transactions idempotentes, réconciliation des écritures incertaines, environnements Dev/Test/Prod séparés),
  collection à identifiants uniques, propriété gratuite unique, contrats du starter (liste officielle vide),
  propriétés (3 catégories, plafond 5) et intérieurs instanciés, garages, réglages, esthétique, pièces, 5
  configurations, état durable, invitations, contrats économiques, interface provisoire.
- Vérifié hors Studio uniquement (235 tests Lune sur adaptateur mémoire, 10 pytest, typage strict) ; persistance
  réelle, essais Studio et humains **NON TESTÉS** (`docs/QA_BACKLOG.md`).
- Rapport : `docs/lot-0.4/RAPPORT_LOT_0.4.md` ; architecture : `docs/lot-0.4/ARCHITECTURE_LOT_0.4.md`.

## État du lot 0.5 (branche `feat/economy-progression-0.5`, PR brouillon, base : lot 0.4)

- Livré : portefeuille (profil v2), réputation à cinq niveaux, huit métiers à boucles serveur, concessions
  (catalogue de travail provisoire), reprise, marché d'occasion à transferts multiprofils durables et récupérables,
  immobilier et améliorations, pièces, main-d'œuvre, énergie progressive, réparation, lavage, interface provisoire.
- Vérifié : 263 tests Lune sur adaptateur mémoire (dont les 17 cas demandés), contrôles de démarrage Studio ;
  persistance réelle, inter-serveurs, jeu de bout en bout et essais humains **NON TESTÉS**.
- Rapport : `docs/lot-0.5/RAPPORT_LOT_0.5.md` ; architecture : `docs/lot-0.5/ARCHITECTURE_LOT_0.5.md`.

## État du lot 0.6 (branche `feat/racing-competition-0.6`, PR brouillon, base : lot 0.5)

- Livré : socle de compétition commun et six disciplines (sprint, circuit, contre-la-montre, drift, drag, rallye),
  22 parcours versionnés validés sur le graphe routier (16 monde ouvert, 6 zone d'essai) et leurs installations,
  salons officiels, classés, privés et entraînement, modes protégé et réaliste, réservation exclusive des véhicules,
  chronométrage et validation serveur, récompenses idempotentes, classement compétitif, saisons de huit semaines,
  reconnexion et récupération, matchmaking (repli local), interface provisoire, simulation d'équilibrage.
- Vérifié : tests Lune sur échantillons synthétiques et adaptateur mémoire (dont les 20 cas demandés), contrôles de
  démarrage Studio ; matchmaking inter-serveurs, DataStore réel, courses jouées, latence, charge et essais humains
  **NON TESTÉS**.
- Rapport : `docs/lot-0.6/RAPPORT_LOT_0.6.md` ; architecture : `docs/lot-0.6/ARCHITECTURE_LOT_0.6.md`.

## État du lot 0.7 (branche `feat/ui-gps-social-0.7`, PR brouillon, base : lot 0.6)

- Livré : architecture d'interface commune (gestionnaire d'écrans, raccourcis, focus, conduite), HUD contextuel à
  trois niveaux, mini-carte, carte interactive, GPS routier avec guidage et recalcul, points d'intérêt issus des
  registres existants, smartphone tenu en main et ses applications, groupes de huit, invitations, partage de
  position volontaire et révocable, canaux Roblox officiels, notifications hiérarchisées, accessibilité,
  localisation FR/EN centralisée, préférences sauvegardées (profil v4).
- Vérifié : tests Lune des règles pures, contrôles de démarrage Studio ; parcours utilisateur, GPS réel,
  manette, lisibilité, communications, confidentialité multijoueur et DataStore **NON TESTÉS**.
- Rapport : `docs/lot-0.7/RAPPORT_LOT_0.7.md` ; architecture : `docs/lot-0.7/ARCHITECTURE_LOT_0.7.md`.

## État du lot 0.8 (branche `feat/art-audio-onboarding-0.8`, PR brouillon #8, base : lot 0.7)

- Livré : manifeste des ressources (aucun identifiant Roblox inventé), direction artistique, gamme PROPOSÉE de 18
  modèles fictifs intégrée au moteur physique et aux concessions (en attente d'approbation), carrosseries et
  habitacles par silhouette, place passager, habillage des sept zones, feux de nuit, qualité graphique, audio
  modulaire et radio (contrôleurs ; 30 sons originaux synthétisés, non téléversés), mode photo, parcours d'arrivée
  passable avec essais protégés et choix confirmé, exercices de formation, protection d'apparition, traduction des
  panneaux des lots 0.4 à 0.6, profil v5 et préférences v2.
- En attente du propriétaire : approbation de la gamme et des trois véhicules de départ, écoute et téléversement
  des sons.
- Vérifié : tests Lune et pytest des règles pures ; sessions de démarrage Studio `solo`, `lot04` et `monde` (un
  défaut bloquant du parcours d'arrivée y a été trouvé et corrigé) ; rendu, sons, radio multijoueur, mode photo,
  parcours avec de vrais comptes et performances **NON TESTÉS** (`docs/QA_BACKLOG.md` §3 sexies).
- Rapport : `docs/lot-0.8/RAPPORT_LOT_0.8.md` ; architecture : `docs/lot-0.8/ARCHITECTURE_LOT_0.8.md`.

## État du lot 0.9 (branche `feat/integration-qa-0.9`, PR brouillon #9, base : lot 0.8)

- Version intégrée des lots 0.1 à 0.8 ; registre QA audité et classé ; déclaration du propriétaire (essais du
  lot 0.1) consignée à part.
- Campagnes VM : sessions historiques, nouvelles sessions `lot05` (économie, marché, falsifications), `lot06`
  (courses), `lot08` (arrivée, banc des 18 modèles, photo, radio), `perf` (mesures de référence), `monde` étendu.
- Corrigé : inscription aux courses impossible en jeu (lot 0.6), annonce du marché jamais publiée (lot 0.5), mât du
  drag sur la ligne d'essai (lot 0.6), lampadaires et niveau de détail sous streaming (lot 0.8) ; comblé : capacité
  des stations, chargement visible des missions. QA-A02 expliquée (test) ; QA-A01 rétrogradée P2.
- Non fait : DataStore réel, charge à 24 joueurs, appareils réels, essais humains (checklist prête).
- Rapport : `docs/lot-0.9/RAPPORT_VALIDATION_GLOBALE.md`.

## État du lot 0.9.1 (branche `feat/autonomous-interactive-qa-0.9.1`, PR brouillon #10, base : lot 0.9)

- Pont d'entrées réelles **dans la VM** (`tools/vm/ScreenCapture.cs`, module `tests/studio/GuiDriver.luau`) : vrais
  clics, touches, saisie, molette, captures nommées ; sessions `ui`, `ui_marche`, `ui_monde`, `metiers`, `gps`, `gps2`,
  `drift`, `social`.
- Résultats : interfaces parcourues, 8 métiers terminés et payés (au moins une fois chacun), 5 arrivées GPS sur 7 en
  conduite réelle, social et confidentialité à deux clients, drift 310 points, prêt après verrouillage refusé.
- Corrigé : QA-F13 à F20 (confirmation hors de vue, signes de police, vue cockpit, retrait d'annonce, éclairage,
  véhicule qui rampe menu ouvert, passager du taxi, destination GPS de montagne) ; QA-A08 neutralisée (cause ouverte).
- Non fait : manette, deux clients en vrais clics, touche O dans le client Roblox, DataStore réel, appareils réels.
- Rapports : `docs/lot-0.9/TESTS_INTERACTIFS_AUTONOMES.md`, `docs/lot-0.9/COUVERTURE_QA.md`. **La V1.0 n'est pas
  commencée.**

## État du lot 0.9.2 (branche `feat/final-stabilization-0.9.2`, PR brouillon #11, base : lot 0.9.1)

- Stabilisation finale avant la V1.0, essais Studio dans la VM uniquement, sans publication ni DataStore réel.
- Corrigé : **QA-A08** (cause : couple du convertisseur sans borne de stabilité, `ebe4714`) ; **QA-A12** moteur calé
  sans relance sur boîte automatique (`5805636`, règle validée par le propriétaire le 2026-11-04) ; **QA-A10** bras du téléphone sur le squelette R15
  à contraintes (`000045c`) ; focus de navigation seulement à la manette (`9b8b052`).
- **QA-A09** expliquée : erreur du scénario de test (poteaux du portique du drag), tests corrigés, 24 virages sur 24.
- GPS : Montagnes et Motorsport atteints en conduite réelle, recalcul après sortie d'itinéraire ; 5 zones sur 7
  atteintes sur le code du lot (Métropole et Campagne : pilote coincé ou non atteint).
- Campagne finale (3 tâches VM, 20 sessions) : 1 197 réussis, 16 échecs classés (1 défaut probable du jeu, QA-A11 ;
  4 anomalies connues ; 10 défauts du test ; 1 limite de Studio), 1 limite connue.
- Rapport : `docs/lot-0.9.2/RAPPORT_STABILISATION.md`. **La V1.0 n'est pas commencée.**

## État du lot AVATAR-01 (branche `feat/avatar-r15-foundation`, PR brouillon #12, base : lot 0.9.2)

- R15 exclusivement (réglage des deux places, contrôle au serveur sans conversion), apparence du joueur conservée,
  échelles au choix du joueur (aucune limitation justifiée par les essais).
- Fondation des tenues indépendante des cosmétiques automobiles : emplacements classiques, superposés et rigides ;
  essayage, équipement, retrait, restauration ; identifiants invalides ; FR/EN ; cinq catégories en emplacements vides
  (aucune ressource, aucun identifiant, aucune boutique).
- Essais VM (8 morphologies, 5 véhicules puis les 18 modèles) : vue cockpit, téléphone, marche et bras vus par un autre
  joueur corrects ; **habitacles trop bas et trop étroits pour un R15 standard** (QA-A13, A14), **sortie passager sans
  placement** (QA-A15), conducteur parfois couché après la sortie (QA-A16) : à arbitrer.
- Rapport : `docs/lot-avatar-01/RAPPORT_AVATAR_R15.md`. Production graphique des tenues non engagée.

## Préparation des véhicules 3D (branche `feat/vehicle-3d-references`, base : lot AVATAR-01)

- Références de direction artistique des 18 modèles (121 images libres de Wikimedia Commons, stockées hors dépôt,
  manifestes versionnés), 18 fiches de design, spécification des modèles 3D, pipeline Blender → Roblox, plan de
  production, dossier du véhicule pilote **Aster** (trois directions).
- Aucune géométrie définitive, aucun actif importé ou publié, physique et carrosseries provisoires inchangées.
- Documents : `docs/vehicle-3d/`. Direction A « Trait » retenue pour l'Aster et habitacle « échelle Roblox + assise basse »
  (D1), pose assise propre au jeu (D3), ouvrants animés reportés (D4), critère de performance +2 ms (D5), publication par le
  propriétaire sous le créateur de l'expérience et sources dans un dépôt d'art privé (D6), plusieurs marques fictives et
  signature par famille, répartition en 4 marques le 2026-11-04 ; noms (Mivale, Orvane, Rocalt, Celvar) et
  emblèmes validés, dans le dépôt d'art privé (https://github.com/AbdelmalekYounes/roblox-automotive-world-art) ; recherche d'antériorité officielle à faire.

## Phase 1 de l'Aster (branche `feat/aster-phase1`, base : préparation des véhicules 3D)

- Pose assise du jeu activable par siège (aucun siège actuel ne la porte), gabarit technique de l'Aster mesuré en VM
  sur 10 morphologies (tous les contrôles réussis, tâche `20261104-151955`), export vers le dépôt d'art et scène Blender.
- Avatars humains uniquement (décision du propriétaire, 2026-11-04) : tous les joueurs reçoivent le corps 995 (masculin)
  ou 994 (féminin) à leur choix, vêtements conservés, tête classique « bloc » remplacée par celle du corps (contrôles
  réussis, tâche `20261104-170413`).
- Clôture (2026-11-04) : choix de silhouette validé par vrais clics et à deux joueurs, file ordonnée des applications
  d'apparence, plancher du gabarit abaissé (QA-A23) ; dossier de lancement `docs/vehicle-3d/ASTER_02_LANCEMENT.md`
  (ASTER-02 non lancé : GO conditionnel ; plancher abaissé validé ; décisions du 2026-11-04 appliquées — pose H5
  acceptée, toit 4,20 st, couleurs unifiées sur la tête, budgets de l'habitacle ; étalonnage Studio à relever). Rapport de clôture : `docs/vehicle-3d/ASTER_PHASE1_CLOTURE.md`.
- Rapport : `docs/vehicle-3d/ASTER_PHASE1.md`. À arbitrer : corps par défaut, couleurs de peau, D7, hauteur sous pavillon,
  pose adaptée à la taille. Étalonnage de l'import dans Studio à relever par le propriétaire.

## ASTER-02 — modélisation de l'Aster (branche `feat/aster-02-blockout`, base : phase 1 de l'Aster)

- Étalonnage relevé par le propriétaire : glTF 1:1 retenu, FBX écarté ; orientation à confirmer (témoin v2).
- Blockout extérieur et intérieur dans Blender (surface lofée, direction A « Trait »), contrôles automatiques 15/15,
  8 rendus de revue : `docs/vehicle-3d/ASTER_02_BLOCKOUT.md`. **À valider** avant le modèle haute fidélité ; aucun import,
  aucune publication, aucune intégration.
- Blockout validé par le propriétaire (2026-11-04). Haute fidélité par passes (`docs/vehicle-3d/ASTER_02_HAUTE_FIDELITE.md`) :
  HF1 à HF3 (extérieur, intérieur, matériaux) faites et acceptées ; HF4 faite, à revoir (LOD0 36 696 triangles au lieu de
  101 744, LOD1 12 978, LOD2 3 544, 4 collisions, attaches, roues instanciées ; contrôles 33/33 ; LOD0 au-dessus de
  l'hypothèse de 25 000 : gardé, D5 tranche, décision du propriétaire du 2026-11-04) ; HF5 à faire, sur accord.

## Critères de passage du socle 0.0.1

- Arborescence source entièrement nouvelle.
- Manifeste Rojo valide et reproductible.
- Chargement des scripts client et serveur dans Roblox Studio (à vérifier en Studio).
- Aucun appel aux DataStores et aucun accès production.
- Tests statiques passants et limites des tests documentées.
