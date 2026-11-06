# Lot ANIM-01 — Volants qui tournent, mains du conducteur sur le volant

- Date : 2026-11-06.
- Branche : `claude/anim-01-volants-mains-f84390`, créée depuis `main` `d295473`. Rien n'est poussé.
- Lot mené en parallèle de PHONE-01 (exception du propriétaire du 2026-11-06 : fichiers disjoints).
- Demande du propriétaire : « les volants des véhicules qui tournent, mains sur le volant en FPV ».
- Dépôt d'art : branche locale `anim-01-volant-comete`, commit `c9e0add`, créée depuis `origin/main` `f009761`, non
  poussée (worktree `E:\ROBLOX DEV\aw-art-anim01`).

## 1. Décisions du propriétaire (2026-11-06, toutes posées en une fois au début du lot)

| Question | Décision |
| --- | --- |
| Rapport de direction | **Réaliste** : angle du volant = angle des roues avant × rapport. Brio 14:1 (±490° à fond en manœuvre, ±126° à 140 km/h), Comète 12:1 (±360° / ±108°). |
| Mains aux grands angles | **Suivent puis glissent** : prise à 9 h 15, les mains tournent avec la jante jusqu'à ±100°, puis restent posées sur la jante à cette position pendant que le volant continue de tourner. |
| Comète sans volant séparé | **Séparer dans ce lot** : séparation dans Blender (dépôt d'art), puis nouvel envoi des maillages par le propriétaire. |
| Visibilité en vue cockpit | **Avant-bras et mains** ; bras (épaules) et reste du corps masqués. |

## 2. Fonctionnement

### 2.1 Volant qui tourne

- **Données** (`src/shared/Vehicles/MeshKitData.luau`, champ `SteeringWheel` de chaque kit) : pièce du gabarit, centre
  de la jante, axe de la colonne, rayon de prise, rapport. Les valeurs sont mesurées sur les sommets (§3).
- **Serveur** (`src/server/Vehicles/MeshKits.luau`) : si le gabarit contient la pièce du volant, elle est articulée
  au châssis par un `Motor6D` nommé `AWVolant`, au lieu d'être soudée. Le repère de cette articulation a son origine au
  centre de la jante et son axe Z le long de la colonne (`SteeringWheel.jointFrame`). Sans masse ni collision :
  aucun effet physique.
- **Client** (`src/client/Vehicles/SteeringWheelVisuals.luau`) : chaque client fait tourner le volant de **tous** les
  véhicules par `Transform`, qui n'est pas répliqué (même méthode que les roues, `WheelVisuals`). Angle du volant =
  `fraction de braquage × VehicleDynamics.maxSteerAngle(définition, vitesse) × rapport`. La fraction de braquage vient :
  - pour le véhicule piloté par ce client, de la position de crémaillère de sa simulation (`SteerPosition`, valeur
    exacte) ;
  - pour les autres véhicules, de la consigne `VisualSteer` répliquée par le serveur, lissée à la vitesse de la
    crémaillère du modèle. Cette consigne est quantifiée au vingtième et brutale au clavier.

  L'angle dépend de la vitesse, comme l'affichage des roues. Le sens est horaire vu du conducteur pour un braquage à
  droite (test Lune 3).
- **Ordre** : `SeatPoseController` appelle `SteeringWheelVisuals.update` au début de son pas `PreSimulation`, puis
  pose les mains. Le volant et les mains utilisent donc le même angle dans la même image. `VehicleController`
  transmet seulement la référence de l'état du véhicule piloté (`SteeringWheelVisuals.setLocal`, ajout de 2 lignes
  dans sa section).

### 2.2 Mains sur le volant

- **Qui** : le conducteur, quand son siège porte une pose de conduite avec bras (`Citadine`, `Sportive`) et que son
  véhicule a un volant connu. Le passager n'est pas modifié. Les sièges sans volant connu (pose `Conduite`) gardent les
  décalages statiques des bras.
- **Prises** (`src/shared/Vehicles/SteeringWheel.luau`) : à 9 h 15 sur la jante, sur l'horizontale du plan de la
  jante. Elles tournent avec le volant jusqu'à ±100° (`HandFollowLimit`). Au-delà, elles restent à ±100° sur la jante :
  les mains glissent.
- **Bras** (`src/shared/Vehicles/ArmIk.luau`) : cinématique inverse à deux segments, procédurale, sans actif
  d'animation ni `IKControl` du moteur.
  - Les longueurs sont lues sur les articulations de chaque avatar, `Motor6D` ou `AnimationConstraint` (C0/C1 ou
    attaches). La prise est l'attache `LeftGripAttachment` / `RightGripAttachment`, sinon le centre de la main.
  - Le coude est une charnière (axe X, pli vers l'avant, 0 à 150°) ; l'épaule est une rotule. Le coude est orienté
    vers le bas, l'extérieur et un peu l'arrière.
  - Hors d'allonge, l'épaule avance vers la cible d'au plus **0,3 st** (8 cm), puis le bras reste tendu vers elle (§6).
  - Le poignet n'est pas modifié : la main reste dans l'axe de l'avant-bras.
  - Les rotations remplacent l'animation des épaules et des coudes, en fondu de 0,3 s (`SeatPose.BlendS`), à l'aller
    comme au retour.
- **Pour tous** : chaque client calcule les bras de tous les conducteurs avec le même angle de volant. Les autres
  joueurs voient donc les mains suivre le volant, sans réplication par image.
- **Téléphone sorti** (`AWPhoneRaised`) : **seul le bras droit est libéré** (`SeatPose.PhoneArmJoints` : épaule,
  coude et poignet droits). La main gauche reste sur le volant. Décision du propriétaire du 2026-11-06, transmise par
  PHONE-01 : « il faut que ça libere qu'un seul bras ». La version initiale de ce lot libérait les deux bras.
  - Le bras droit quitte le volant en 0,3 s, et PHONE-01 le pilote (épaule et coude, pose absolue).
  - Au rangement du téléphone, la main droite revient sur le volant.

### 2.3 Vue cockpit (joueur local)

- Mains posées : `SeatPoseController` pose sur la caméra du véhicule (`VehicleController.getCamera()`, interface de
  CAMERA-01) un filtre qui garde visibles `LeftLowerArm`, `RightLowerArm`, `LeftHand` et `RightHand`. Le reste du
  personnage reste masqué localement.
- En cockpit, `LocalTransparencyModifier = 0` est réappliqué à ces 4 pièces à chaque pas. C'est une protection contre
  le contrôleur de transparence du `PlayerModule` signalé au §4 du rapport CAMERA-01.
- Fin de conduite : le filtre est retiré.
- **Téléphone sorti :** le filtre reste posé. L'avant-bras et la main gauches restent visibles, avec leur
  transparence réécrite à chaque pas. Celle du bras droit n'est plus réécrite : PHONE-01 n'utilise pas le filtre ; il
  écrit lui-même la transparence locale du bras droit, de la main droite et du téléphone pendant le zoom, puis
  rétablit les valeurs d'origine. Note de coordination : `ANIM-01.md` dans le dossier des notes partagées.

### 2.4 Comète : volant séparé (en attente de l'import du propriétaire)

Le volant de la Comète faisait partie du maillage `COMETE_Habitacle_interior`.

Dépôt d'art (`c9e0add`) :
- `tools/blender/comete_volant_separe.py` sépare la partie détachée du volant : jante, branches, moyeu et colonne,
  256 sommets, 248 triangles.
  - Elle est repérée par sa géométrie : composantes connexes par les arêtes et par les sommets confondus. Le modèle
    d'origine découpe le volant en morceaux jointifs non soudés.
  - Elle devient `COMETE_Volant`, avec le même matériau et les mêmes UV.
  - Les commodos et le bloc d'instruments restent fixes dans l'habitacle.
- La boîte de l'habitacle est inchangée : centre (0,001 ; 0,931 ; −1,128).
- **Export réduit à importer** : `vehicles/wk_comete/export/wk_comete_720s_volant_anim01.glb`, avec 2 pièces
  (l'habitacle sans volant et le volant). Les 27 autres pièces de la Comète gardent leurs identifiants.
- Le LOD0 complet est réexporté pour rester cohérent avec la scène (29 pièces). **Il ne faut pas l'importer** : il
  redonnerait de nouveaux identifiants à toutes les pièces.

Dans le jeu, **tant que le gabarit n'a pas la pièce `COMETE_Volant`**, le volant de la Comète reste fixe (il est dans
l'habitacle) et les mains se posent dessus à 9 h 15, sans suivre le braquage (`angleFor` = 0). Dès que la pièce est
dans le gabarit et dans le manifeste, il tourne sans autre changement de code.

**Procédure pour le propriétaire**, la même que pour la Brio :
1. Dans une place locale vierge, ouvrir **Importer 3D** et choisir
   `E:\ROBLOX DEV\aw-art-anim01\vehicles\wk_comete\export\wk_comete_720s_volant_anim01.glb`.
2. Garder les réglages par défaut : « Unité d'échelle : Stud », facteur 1, « Avance du monde : Avant ». Cocher
   **« Importer sur Roblox »** (créateur : propriétaire de l'expérience).
3. Vérifier qu'il y a 2 MeshParts : `COMETE_Habitacle_interior` et `COMETE_Volant`.
4. Clic droit sur le modèle importé, puis **« Enregistrer dans un fichier »** : `aw-vm-exchange\comete_volant.rbxm`.
   Prévenir l'assistant.

Ensuite, l'assistant :
1. Lance `lune run tests/lune/tools/anim01-volant-comete.luau <comete_volant.rbxm>
   <aw-art-anim01>/vehicles/wk_comete/export/wk_comete_720s_volant_anim01.json`. L'outil :
   - remplace l'habitacle ;
   - ajoute `COMETE_Volant_Node` ;
   - place les deux pièces au centre attendu ;
   - reprend la texture d'origine de l'habitacle ;
   - refuse tout code et toute pièce inattendue.
2. Reporte au manifeste les 2 nouveaux identifiants de maillage et retire `106049474235075` (ancien habitacle).
3. Passe le test VEH3D-01 de 28 à 29 maillages.
4. Relance `verify.ps1`.

L'outil a été essayé **à blanc** sur un import fictif, construit à partir du gabarit actuel (§5). Le vrai fichier n'a
pas été essayé.

## 3. Mesures des volants (lecture seule, 2026-11-06)

Les mesures sont faites sur les sommets des volants, dans le repère du châssis :
- jante ajustée sur les sommets loin de l'axe (plan, puis cercle par moindres carrés, 4 passes) ;
- commande : `python -I docs/lot-anim-01/mesure_volants.py` (sorties reproduites ci-dessous).

| | Brio (`BRIO_Volant`) | Comète (`COMETE_Volant`) |
| --- | --- | --- |
| Source | `aw-art-citadine/.../wk_brio_milano95_lod0.glb` | relevé `volant_anim01.json` du script de séparation |
| Sommets (jante) | 159 (91) | 256 (98) |
| Centre de boîte de la pièce | (−1,166 ; 1,194 ; −0,152) | (−1,157 ; 0,992 ; −3,445) |
| Centre de la jante (`Hub`) | (−1,166 ; 1,197 ; −0,156) | (−1,157 ; 0,960 ; −2,951) |
| Axe vers le conducteur | (0,0021 ; 0,3459 ; 0,9383), x négligé | (0 ; 0,2096 ; 0,9778) |
| Inclinaison de la jante sur la verticale | 20,2° | 12,1° |
| Rayon de prise (boudin) | 0,591 st (0,543 à 0,646) | 0,593 st (0,533 à 0,648) |
| Rapport | 14:1 | 12:1 |

- Brio : le pivot de la pièce importée (centre de sa boîte) est à 0,005 st du centre de la jante. Le test Lune 7 le
  contrôle sur le gabarit réel, à 0,01 st.
- Comète : la pièce contient la colonne. Son centre de boîte n'est donc pas le centre de la jante. L'articulation
  utilise le centre de la jante, quel que soit le pivot de la pièce.

## 4. Fichiers

Nouveaux :
- `src/shared/Vehicles/SteeringWheel.luau` : rapport, sens, articulation, prises (pur) ;
- `src/shared/Vehicles/ArmIk.luau` : cinématique inverse du bras (pur) ;
- `src/client/Vehicles/SteeringWheelVisuals.luau` : rotation des volants ;
- `tests/lune/specs/Anim01.luau` : 8 tests ;
- `tests/lune/tools/anim01-volant-comete.luau` : intégration de l'import de la Comète ;
- `docs/lot-anim-01/mesure_volants.py` et ce rapport.

Modifiés :
- `src/client/Vehicles/SeatPoseController.luau` (fichier d'ANIM-01) : volant puis mains, avant-bras en cockpit ;
- `src/shared/Vehicles/SeatPose.luau` (fichier d'ANIM-01) : un commentaire, aucune valeur changée ;
- `src/shared/Vehicles/MeshKitData.luau` : champ `SteeringWheel`, ajouté au type et aux deux kits ;
- `src/server/Vehicles/MeshKits.luau` : articulation du volant ;
- fichiers partagés, ajouts minimaux marqués « Lot ANIM-01 » :
  - `src/client/Vehicles/VehicleController.luau` : `require` et `setLocal` ;
  - `tests/lune/run.luau` : 1 ligne après CAMERA-01.

Non modifiés : `README.md`, `docs/ROADMAP.md`, `docs/QA_BACKLOG.md`, `docs/CREDITS_ACTIFS.md`, `Localization.luau`
(aucun texte joueur), `PhoneController.luau`, `InterfaceService.luau`, `src/client/Audio/*`, `VehicleCamera.luau`.

## 5. Vérifications exécutées (2026-11-06)

| Commande | Résultat |
| --- | --- |
| `scripts\verify.ps1 -DownloadRobloxTypes` (dernière exécution, terminée à 02:01, après toutes les modifications de code) | Rojo, Selene, pilote Studio, StyLua, carte, place monde ouvert : OK. Lune **439 réussis, 0 échoué**, dont les 8 tests ANIM-01. Pytest 23 réussis. luau-lsp strict : 0 erreur ; restent 3 avertissements `DeprecatedApi` antérieurs, hors lot. |
| `rojo build default.project.json -o build/AW-ANIM-01.rbxlx` (02:01) | Place de test construite (3,09 Mo). |
| Blender 4.5.9 sans interface, `--factory-startup --disable-autoexec` : `comete_volant_separe.py`, puis 2 × `export_roblox_glb.py` | 19 parties détachées dans l'habitacle, 1 candidate retenue (256 sommets). Exports : 2 objets (2 154 triangles) et 29 objets (6 907 triangles). Seuls changent l'habitacle (2 154 → 1 906 triangles, même boîte) et le nouveau `COMETE_Volant`. |
| `python -I docs/lot-anim-01/mesure_volants.py` (Brio et Comète) | Valeurs du §3. |
| Essai à blanc de `anim01-volant-comete.luau` sur un import fictif (2 copies de l'habitacle actuel, déplacées) | Gabarit de sortie à 29 pièces ; centres (0,001 ; 0,931 ; −1,128) et (−1,157 ; 0,992 ; −3,445) ; texture d'origine reprise. Sortie écrite hors du dépôt. |

Tests ANIM-01 :
1. Rapport et angles extrêmes.
2. Lissage de la consigne.
3. Sens horaire, articulation cohérente avec la formule.
4. Prises sur la jante à 9 h 15, suivi puis glissement au-delà de 100°.
5. IK : 15 cibles atteintes à moins de 1e-3 st, pli du coude dans [0, 150°], coude du côté du pôle.
6. Hors d'allonge : épaule avancée, bras tendu.
7. Volants mesurés : pivot de `BRIO_Volant` dans le gabarit réel.
8. Câblage serveur et client, règle du téléphone.

Le test 5 utilise une chaîne R15 de synthèse : les repères réels des avatars ne sont lus qu'en jeu.

## 6. NON TESTÉ, limites et risques

**Rien n'a été essayé en jeu** : aucun test VM, selon la règle du propriétaire. Tout le §7 reste à vérifier.

- **Allonge, surtout sur la Comète (estimation non vérifiée).** Calcul simplifié à partir de la pose mesurée (buste
  incliné à 31°, épaules à environ 2,2 st au-dessus de l'assise pour un R15 standard) :
  - Comète : environ 2,3 st de l'épaule à la prise, pour une allonge R15 d'environ 1,9 st plus 0,3 st d'épaule. Les
    mains pourraient s'arrêter jusqu'à environ 0,1 st (3 cm) avant la jante, bras tendus.
  - Brio : environ 1,8 st, à portée.

  Si les mains n'atteignent pas la jante en jeu, les remèdes possibles sont une épaule plus avancée ou un buste moins
  incliné. Le second remonterait les têtes, dont la marge sous le pavillon de la Comète est faible. C'est une décision
  du propriétaire.
- **Vitesse de rotation en manœuvre.** La crémaillère du jeu atteint la butée en 0,32 s (110°/s pour 35°). Avec le
  rapport réaliste, le volant de la Brio peut tourner à environ 1 500°/s à l'arrêt, au clavier : il peut paraître
  « flou ». Un plafond de vitesse du volant seul serait un nouveau réglage, à décider.
- Mains R15 d'un seul bloc : les doigts ne se referment pas. La main est orientée sur la jante (§6 bis), mais sur
  certains avatars elle peut la traverser légèrement ou rester un peu à côté (`GripOut` = 0,12 st, réglable).
- Vue cockpit : seules les 4 pièces (avant-bras et mains) sont gardées. Les accessoires portés aux poignets (montres,
  manches en accessoire) restent masqués. Le comportement réel du contrôleur de transparence du `PlayerModule`
  n'est pas vérifié.
- Avatars R6 et squelettes incomplets : aucune IK, l'animation reste. Le jeu cible le R15.
- Autres joueurs : le volant suit `VisualSteer`, qui est la consigne et non la crémaillère, lissée côté client. Un
  léger écart avec le volant vu par le conducteur est attendu.
- Comète : volant fixe jusqu'à l'import du propriétaire (§2.4). L'outil d'intégration n'a été essayé qu'à blanc.
- Coordination PHONE-01 : pendant les 0,3 s où le bras droit quitte le volant (ou y revient), les deux lots
  écrivent son épaule et son coude, chacun avec son fondu. Une brève transition mêlée est possible ; elle n'est pas
  vérifiée.

À reporter par la coordination dans `docs/QA_BACKLOG.md` : la liste du §7, NON TESTÉ en jeu.

## 6 bis. Premier essai du propriétaire (2026-11-06) et correction

Retour du propriétaire, avec une capture en vue cockpit de la Brio :
- « comete le volant bouge pas » ;
- « brio le volant et les mains bougent mais les mains n'attrapent pas le volant quand on tourne ».

Constats :
- **Comète** : le volant ne tourne pas, comme attendu. La pièce `COMETE_Volant` n'est pas encore dans le gabarit ;
  l'import par le propriétaire est en attente (§2.4).
- **Brio**, d'après la capture (braquage à droite, au-delà de 100°) :
  - la main gauche est montée vers 12 h et la droite descendue vers 6 h : cela correspond au calcul (prises tournées
    de 100°, puis glissement) ;
  - mais le poignet n'était pas orienté : la main restait dans l'axe de l'avant-bras, doigts tendus au-dessus de la
    jante ;
  - le point visé (centre de la paume) était sur l'axe du boudin. La main passait donc à côté de la jante, au lieu de
    l'entourer.

Correction (commit suivant `692cb2f`) :
- **Main orientée sur la jante** (`SteeringWheel.handFrame`) :
  - pouce le long de la jante, vers le haut à 9 h 15 ;
  - paume tournée vers le moyeu ;
  - doigts vers l'avant et vers le moyeu, autour de la jante ;
  - centre de la main à 0,12 st à l'extérieur du boudin (`GripOut`).

  Le repère tourne avec la prise : suivi jusqu'à ±100°, puis glissement, comme décidé.
- **Visée au poignet** : l'IK amène le pivot du poignet à sa place, puis le poignet tourne la main dans l'orientation
  voulue. Cette rotation est bornée à 80° (`ArmIk.wrist`). Viser le poignet raccourcit aussi l'allonge demandée
  d'environ une longueur de main, ce qui aide pour la Comète (§6).
- Les poignets rejoignent `SeatPose.ArmJoints` : ils ne sont jamais touchés quand le téléphone est sorti (QA-A10).
- La convention des mains R15 au repos est prise comme suit : pouce vers l'avant, paume vers le corps, axe Y vers le
  poignet. **Elle n'est pas vérifiée en jeu** : si les paumes apparaissent tournées vers l'extérieur ou les pouces
  vers le bas, c'est cette convention qu'il faut inverser.
- Tests ajoutés :
  - Lune 9 : orientation de la main, suivi et glissement ;
  - Lune 10 : main remise exactement à l'orientation voulue, et poignet borné.
- `verify.ps1 -DownloadRobloxTypes` (terminé à 02:16) : tout OK. Lune **441 réussis, 0 échoué**, pytest 23, luau-lsp
  0 erreur. La place `build\AW-ANIM-01.rbxlx` est reconstruite.

**Toujours non vérifié en jeu.** La liste du §7 reste à refaire, en particulier les points 2, 5, 8 et 18.

## 6 ter. Téléphone : un seul bras libéré (2026-11-06)

Demande du propriétaire, transmise par la session PHONE-01, citée : « oui il faut que ça libere qu'un seul bras ».

Ce qui change :
- `SeatPose.PhoneArmJoints` (`RightShoulder`, `RightElbow`, `RightWrist`) remplace `SeatPose.ArmJoints` pour la règle
  du téléphone. `ArmJoints` reste la liste des articulations des bras, jamais posées au passager.
- Le calcul des mains n'est plus coupé quand le téléphone est sorti ; seules les articulations droites sont sautées.

Vérifications : `verify.ps1 -DownloadRobloxTypes` (terminé à 02:18) tout OK, Lune 441/441, test 8 mis à jour (bras
droit seulement). La place est reconstruite. **Non vérifié en jeu** (§7, points 14 à 16).

## 7. Liste de vérification en jeu (propriétaire)

Place : `build\AW-ANIM-01.rbxlx`. Véhicules par le menu d'administration (F2) ou la concession (Dev). Prévoir au
moins 2 joueurs : Studio, Test › Serveur local, 2 joueurs. Prévoir aussi plusieurs avatars : petit, standard, grand,
Rthro si possible.

**A. Brio, conducteur, vue extérieure**
1. En montant, les mains se posent sur le volant en environ 0,3 s, à 9 h 15, sans saccade.
2. À l'arrêt, braquer à fond à droite : le volant tourne dans le sens horaire, d'environ 1 tour 1/3 (490°). Les mains
   suivent jusqu'à environ un quart de tour (100°), puis restent sur la jante pendant qu'il continue.
3. Même chose à gauche, puis retour au centre : volant droit, mains revenues à 9 h 15.
4. Sur route (80 à 140 km/h), petits braquages : le volant tourne peu (±1/3 de tour au maximum), mains toujours sur la
   jante.
5. Coudes vers le bas et l'extérieur, aucun bras à travers le corps, le siège ou la planche de bord. Mains au contact de
   la jante, ni dans le vide ni enfoncées. Paume tournée vers le moyeu, pouce le long de la jante, doigts autour de la
   jante (§6 bis), y compris en braquant.
6. Le volant tourne autour de sa colonne, sans se décaler ni « voler ». La vitesse de rotation en manœuvre est-elle
   acceptable (§6) ?

**B. Brio, conducteur, vue cockpit**
7. Avant-bras et mains visibles sur le volant. Bras (épaules), tête, buste et jambes invisibles. Rien ne bouche la vue.
8. Braquer : les mains tournent avec la jante, puis glissent. Le volant reste visible et tourne.
9. Changer de vue (V) plusieurs fois : en cockpit, toujours les avant-bras seulement ; en vue extérieure, tout le
   personnage.

**C. Observateur (2e joueur, à pied ou passager)**
10. Le volant de la Brio conduite par l'autre joueur tourne dans le même sens que ses roues, et ses mains suivent.
11. Le passager garde sa pose actuelle : bras non modifiés, aucune main sur le volant.

**D. Comète**
12. Avant l'import (§2.4) : mains posées à 9 h 15 sur le volant, qui ne tourne pas. **Les mains atteignent-elles la
    jante, avec chaque avatar (§6) ?**
13. Après l'import et l'intégration : refaire A à C. Volant d'environ un tour (360°) à fond, environ 1/3 de tour à
    140 km/h ; commodos et bloc d'instruments fixes ; aucun trou dans la planche de bord à l'emplacement du volant.

**E. Téléphone sorti en conduisant**
14. Sortir le téléphone en roulant : seul le bras droit quitte le volant, en 0,3 s, et tient le téléphone (PHONE-01).
    La main gauche reste sur la jante et suit le volant, qui continue de tourner.
15. Ranger le téléphone : la main droite revient sur le volant, sans saut. En cockpit, les deux avant-bras sont de
    nouveau visibles.
16. En cockpit, téléphone sorti : l'avant-bras et la main gauches restent visibles sur le volant. Le bras droit et le
    téléphone sont réglés par PHONE-01. Noter tout clignotement ou conflit (§6).

**F. Divers**
17. Descendre du véhicule : bras rendus à l'animation normale. Plus aucun avant-bras forcé visible à pied ou dans un
    autre véhicule.
18. Plusieurs avatars (petit, grand, Rthro) : mains sur la jante sans bras disloqué. Noter l'avatar et le véhicule de
    tout cas où les mains n'atteignent pas la jante.
