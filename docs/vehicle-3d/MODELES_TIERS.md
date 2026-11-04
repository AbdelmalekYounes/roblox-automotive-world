# Registre des modèles 3D tiers

Règle du projet (CLAUDE.md) : aucun emprunt de modèle à d'autres projets, aucun actif non inspecté. Seul le
propriétaire accorde une exception. Ce registre consigne chaque exception, ses conditions et l'état de l'inspection.

Le jeu ne sera jamais monétisé (décision du propriétaire, `ASTER_02_DECISIONS.md` §4 ter).

## Conditions communes

- **Origine** : le modèle doit être l'œuvre déclarée de son auteur. Un modèle « basé sur » un jeu vidéo, un
  configurateur ou un autre modèle est refusé, quelle que soit la licence affichée.
- **Licence** vérifiée sur la page du modèle et inscrite ici. CC BY : crédit obligatoire dans le jeu (auteur, titre,
  lien, licence, mention « modifié »).
- **Téléchargement par le propriétaire** (compte Sketchfab), dans un dossier vide hors des dépôts :
  `E:\ROBLOX DEV\aw-vehicle-references\<véhicule>\<source>\`.
- **Inspection** avant tout usage, sans interface et sans exécution de script embarqué
  (`tools/blender/inspect_import.py` du dépôt d'art, Blender lancé avec `--factory-startup --disable-autoexec`) :
  - contenu (objets, caméras, lumières, animations, scripts) ;
  - triangles, matériaux, textures ;
  - repérage des logos et inscriptions (noms d'objets, de matériaux et de textures) ;
  - encombrement comparé à la définition du jeu ;
  - captures.
- **Logos, noms de marque et inscriptions retirés** ; plaques fictives.
- **Aucune publication Roblox** sans l'accord du propriétaire.

## Exceptions accordées

| Date | Modèle | Auteur | Licence | Usage | Décision | État |
|---|---|---|---|---|---|---|
| 2026-11-04 | [2017 Mclaren 720s](https://sketchfab.com/3d-models/2017-mclaren-720s-f7bece69400f4640a4a3be746b44998b) (6 917 faces) | s0h1o9b | CC BY 4.0 (page du modèle, relevée par l'API le 2026-11-04) ; description : « Modelled in Blender, textures made in Photoshop » | Essai d'import pour la Comète (`wk_comete`) | Propriétaire : « Tester la 720s » | Téléchargé par le propriétaire ; inspecté (§1) ; préparé (§2) ; attaches, collisions et LOD faits (§3) ; LOD0 exporté et **importé dans Studio par le propriétaire : géométrie conforme, vitrage opaque** (§5) ; non intégré |

## Modèles examinés et refusés

Voir `ASTER_02_DECISIONS.md` §4 ter. Les modèles de ddiaz-design (Golf GTI 2024, Golf R 2025, GR86, MX-5) déclarent
venir de jeux vidéo commerciaux ou d'un configurateur de constructeur : ils sont refusés.

## 1. Inspection de la McLaren 720s (2026-11-04)

Fichiers déposés par le propriétaire dans `aw-vehicle-references/wk_comete/sketchfab_720s/` :
- `scene.gltf` et `scene.bin` ;
- 5 textures PNG ;
- `license.txt`.

Commande :

```
blender --background --factory-startup --disable-autoexec --python tools/blender/inspect_import.py -- <scene.gltf> <dossier> 4.55 2.0 1.18 2.7 0.34
```

Résultats dans `aw-vehicle-references/wk_comete/inspection_720s/`, hors dépôt.

| Point | Constat |
|---|---|
| Licence (`license.txt` et extras glTF) | CC BY 4.0 ; auteur « _Sheep19 » (profil `shobhit190401` ; l'API affichait le compte `s0h1o9b`, sans doute renommé). Crédit fourni : « This work is based on "2017 Mclaren 720s" (lien) by _Sheep19 (lien) licensed under CC-BY-4.0 (lien) » |
| Contenu | 25 maillages, 15 nœuds vides (hiérarchie d'export FBX), 14 matériaux, 5 textures de 512 px (deux identiques), extension `KHR_materials_clearcoat` ; aucune caméra, lumière, armature, aucun texte ni script |
| Animations | 3 (`spoilerAction` sur l'aileron et les deux essieux) : inutiles en jeu, à retirer |
| Triangles | **6 915** (habitacle 2 154, caisse 1 384, fibre de carbone 1 044…) |
| Échelle | 3,07 × 1,45 (rétroviseurs compris) × 0,80 m : **réduite d'un facteur 1,475 environ**. À × 1,475 : empattement 2,66 m (définition 2,70), rayon de pneu 0,336 m (définition 0,34). Avant vers −X |
| Roues | Un objet par **essieu** (deux roues chacun) : à séparer en quatre pour le jeu |
| **Logos et inscriptions** | Objet `badges` (8 triangles). Dans les textures de caisse et de carrosserie (et en relief dans la carte de normales) : mot « McLaren » inversé, logo en virgule rouge, « 720S », « McLaren » sur les étriers de frein. Textures d'intérieur : pictogrammes de commandes, à revoir au détail. **À retirer** (objet supprimé, zones des textures repeintes) |

Préparation proposée, **sur accord du propriétaire** :
1. retirer l'objet `badges` et les animations ;
2. repeindre les zones de logos et d'inscriptions dans les textures ;
3. séparer les roues ;
4. mettre à l'échelle et caler sur les roues et les dimensions de la définition de la Comète ;
5. inscrire le crédit CC BY dans le jeu et dans le manifeste ;
6. contrôles et captures pour revue.

Aucun import Studio ni publication.

## 2. Préparation de la McLaren 720s (2026-11-04, accord du propriétaire : « Oui, prépare »)

Dépôt d'art : `vehicles/wk_comete/` (voir son README pour les commandes et le crédit). Géométrie cible relevée dans le jeu
par `tests/lune/tools/vehicle-geometry.luau` (lecture seule).

| Étape | Résultat |
|---|---|
| Logos et inscriptions | Objet `badges` supprimé. Textures nettoyées par `clean_720s_textures.py`, avec les originaux intacts hors dépôt. Dans l'atlas de carrosserie : 3 631 pixels modifiés (mots-symboles, « 720S », virgule, lettrage des étriers, logo des caches de moyeu). Dans la carte de normales : 10 027 pixels mis à plat. Textures d'intérieur inchangées (aucun logo identifiable à 512 px). Rendus contrôlés à l'œil |
| Animations | 3 supprimées |
| Orientation et échelle | Avant du modèle (−X) tourné vers l'avant du jeu. Échelle **uniforme** de 5,354 st par unité, soit × 1,499 si le fichier est en mètres, tirée de l'empattement du jeu (2,70 m) |
| Roues | Essieux séparés en 4 roues (`COMETE_Pneu_*`, `COMETE_Jante_*`, pivot au moyeu) |
| Écart des roues avec la physique | Longitudinal : 0 (calage). Hauteur des moyeux : avant 0, arrière +0,025 st. **Voies plus étroites que la physique** : avant ±2,98 st contre ±3,107 (0,126 st, 3,5 cm par côté), arrière ±2,98 contre ±3,143 (0,169 st, 4,7 cm par côté) |
| Pneus | Rayon 1,19 st à l'avant et 1,217 st à l'arrière (pneus décalés du modèle), contre 1,214 st pour la physique. Point bas à y −1,478 pour un sol à −1,5 : 6 mm de jour |
| Encombrement (hors rétroviseurs) | 16,44 × 7,01 × 4,31 st, contre 16,25 × 7,14 × 4,21 st pour la définition (+5 cm, −4 cm, +3 cm) |
| Triangles | 6 907 : extérieur 4 179, intérieur 2 168, roues 560 |
| Pièces | `COMETE_<rôle>_<matériau>` ; collections EXT, INT, ROUES |
| Rendus | `vehicles/wk_comete/renders_720s/` : 3/4 avant et arrière, profil, face, arrière, dessus, habitacle, roue ; repères rouges aux centres de roues de la physique |

**Décision du propriétaire (2026-11-04) : « Garder l'échelle »**.
- L'échelle uniforme est conservée, le modèle n'est pas déformé.
- À l'intégration, les roues visuelles du modèle s'afficheront à leur propre position, 3,5 à 4,7 cm plus à l'intérieur
  que les points de contact de la physique, sans changer la physique.

Côté du volant : **à gauche**. Rendus de l'habitacle sans la carrosserie, vus de dessus et depuis l'arrière (Blender,
2026-11-04). C'est conforme au jeu, qui place le conducteur à x −1,61.

Non fait à ce stade : sièges, attaches, collisions et LOD, traités au §3.

Non vérifié :
- habitacle avec les avatars (VM) ;
- import Studio ;
- crédit affiché dans le jeu (`docs/CREDITS_ACTIFS.md`, à l'intégration).

## 3. Attaches, collisions et LOD de la Comète (2026-11-04, accord du propriétaire : « Oui, continue »)

Commande :

```
blender --background --factory-startup --disable-autoexec vehicles/wk_comete/blend/wk_comete_720s.blend --python tools/blender/comete_720s_finish.py -- vehicles/wk_comete/ref-sheets/wk_comete_geometrie.json vehicles/wk_comete/renders_720s
```

Résultats dans `renders_720s/finition.json`. Rendus : `aster02_render_hf4.py -- <dossier> -1.5 comete_720s`.

**Repères mesurés sur le modèle** par rayons, à chaque exécution (repère du jeu, studs) :

| Repère | Position | Carrosserie provisoire |
|---|---|---|
| `SeatDriver` / `SeatPassenger` (dessus d'assise) | (∓1,20 ; −0,64 ; −1,45) | (∓1,611 ; 0,51 ; 0,03) |
| `CameraCockpit` | (−1,20 ; 1,80 ; −1,80) | règle de la fabrique |
| `CameraHood` | (0 ; 2,02 ; −5,80), 0,80 st au-dessus du capot, 0,30 st devant le pied de pare-brise (z −5,50) | (0 ; 1,514 ; −3,986) |
| `CameraBumper` | (0 ; 0,51 ; −10,08), 0,65 st devant le nez (z −9,43) | (0 ; 0,514 ; −8,775) |
| `ExitLeft` / `ExitRight` | (∓4,69 ; −1,5 ; −1,45), 0,8 st au-delà des rétroviseurs | — |

Les sièges du modèle sont plus bas, plus en avant et plus près de l'axe que ceux de la carrosserie provisoire.
**À l'intégration, le jeu devra prendre les repères du modèle.**

`CameraCockpit` suit la règle du jeu `CockpitGeometry.eyeY`. Le haut du volant, mesuré à y 1,58 et z −3,06, passe 10,0°
sous la visée ; la caméra est 0,94 st sous le pavillon.

Hauteur de l'assise au dessous du pavillon : 3,38 st (0,95 m), avatars non mesurés.

**Collisions** : 4 boîtes aux noms des zones de dégâts. Leurs hauteurs partent de celles de la carrosserie provisoire.
- La coque est cherchée entre les roues : une boîte sur toute la longueur était bridée par le nez bas et pointu.
- Chaque bouclier comble l'extrémité jusqu'à la coque.
- Dépassement hors de la caisse visible : 0,25 st au plus, mesuré par rayons sortants, hors passages de roues.

| Boîte | Taille ; centre | Provisoire |
|---|---|---|
| `COL_Coque` | 6,62 × 0,60 × 13,14 ; (0 ; 0,41 ; −1,02) | 6,94 × 0,60 × 15,05 ; (0 ; 0,41 ; 0) |
| `COL_BouclierAvant` | 4,11 × 1,76 × 1,34 ; (0 ; −0,26 ; −8,16) : 0,60 st du nez non couverts | 6,84 × 1,76 × 0,70 ; (0 ; −0,26 ; −7,78) |
| `COL_BouclierArriere` | 4,42 × 1,16 × 1,11 ; (0 ; 0,04 ; 6,00) | 6,84 × 1,76 × 0,70 ; (0 ; −0,26 ; 7,78) |
| `COL_Habitacle` | 3,37 × 1,81 × 4,20 ; (0 ; 1,62 ; −0,90) | 6,44 × 2,00 × 2,60 ; (0 ; 1,71 ; 0,33) |

**Le modèle n'est pas centré comme la définition.** Son nez est à z −9,43 et son arrière à +7,01, alors que la
définition va de −8,125 à +8,125 : les roues de la physique sont placées plus en avant que sur le vrai véhicule.
Les collisions suivent le modèle ; les collisions basses du châssis restent celles de la définition.

**LOD**, réglés à l'image :

| Niveau | Triangles |
|---|---|
| LOD0 | 6 907 |
| LOD1 | 4 364 (63 %) |
| LOD2 | 2 257 (33 %) |

- Premier essai à 3 307 (48 %) et 956 (14 %) triangles : la caisse se déchirait, avec des pointes au LOD1 et des flancs
  troués au LOD2, alors que l'encombrement restait conforme. Les seuils de 50 % et 15 % sont donc abandonnés pour ce
  modèle déjà léger.
- LOD1 : roues intactes.
- LOD2 :
  - vitrage opaque, sans habitacle ;
  - un cylindre à 12 côtés par roue, au rayon du pneu ;
  - quelques défauts de surface sur les flancs, et des roues sombres sans jante, visibles de près seulement.

**Contrôles** : 11 sur 11, plus 4 relevés informatifs (`finition.json`).

Non vérifié :
- habitacle avec les avatars (VM) : têtes, jambes, mains sur le volant ;
- peinture teintable : la teinte est dans la texture du modèle, et non dans un matériau uni comme sur l'Aster ;
- bascule des LOD ;
- import Studio (témoin d'orientation v2) ;
- performances D5.

## 4. Export du LOD0 pour un premier import dans Studio (2026-11-04, demande du propriétaire : « importons la comète »)

Règle d'étalonnage (dépôt d'art, `calibration/README.md`) : glTF, demi-tour de 180° autour de la verticale avant
l'export, import avec les réglages par défaut. Outil : `tools/blender/export_roblox_glb.py`. La scène n'est pas modifiée.

```
blender --background --factory-startup --disable-autoexec vehicles/wk_comete/blend/wk_comete_720s.blend --python tools/blender/export_roblox_glb.py -- vehicles/wk_comete/export/wk_comete_720s_lod0.glb EXT INT ROUES
```

Fichier produit : `vehicles/wk_comete/export/wk_comete_720s_lod0.glb`, soit 1,25 Mo, 28 objets et 6 907 triangles.
Les valeurs attendues sont dans `wk_comete_720s_lod0.json`.

Contrôle par relecture dans Blender, après le demi-tour de l'importeur :
- les 28 objets sont présents ;
- écart maximal des centres avec le repère du jeu : 0,0005 st ;
- aucune animation, caméra ni script ;
- les 5 textures embarquées sont identiques aux textures nettoyées.

**Attendu dans Studio**, en positions relatives : l'emplacement d'insertion décale tout, seules les différences comptent.

| Mesure | Attendu |
|---|---|
| Size de `COMETE_Caisse_body` | 6,984 ; 2,994 ; 16,44 |
| `COMETE_Pneu_AvG` − `COMETE_Pneu_ArG` | (−0,005 ; −0,025 ; **−9,643**) : roue avant vers −Z, l'avant du jeu |
| `COMETE_Pneu_AvD` − `COMETE_Pneu_AvG` | (**+5,962** ; 0 ; 0) : roue droite vers +X |
| `COMETE_Retroviseurs_body` − `COMETE_Caisse_body` (centres) | (0 ; +1,053 ; −2,360) |

**Point de décision du propriétaire.** Avec « Importer sur Roblox » coché, les maillages sont envoyés sur son compte, ce
qui revient à une publication d'actifs ; le crédit CC BY s'appliquera dès que le modèle sera partagé. L'assistant ne
publie rien.

Non fait :
- LOD1 et LOD2 non exportés ;
- attaches et collisions non exportées : ce sont des repères du jeu, créés par la fabrique à l'intégration, et leurs
  valeurs sont dans `renders_720s/finition.json` ;
- aucune intégration au jeu.

## 5. Premier import dans Studio (relevé par le propriétaire, 2026-11-04)

Import de `wk_comete_720s_lod0.glb` avec les réglages par défaut. Captures fournies par le propriétaire : fenêtres
Propriétés et quatre vues 3D.

| Mesure | Studio | Attendu |
|---|---|---|
| Size de `COMETE_Caisse_body` | 6,984 ; 2,994 ; 16,44 | identique |
| Position `COMETE_Caisse_body` | (−1,345 ; 1,833 ; 25) | — (emplacement d'insertion) |
| `Pneu_AvG` (−4,326 ; 1,192 ; 20,621) − `Pneu_ArG` (−4,321 ; 1,217 ; 30,264) | (−0,005 ; −0,025 ; −9,643) | identique |
| `Pneu_AvD` (1,636 ; 1,192 ; 20,621) − `Pneu_AvG` | (+5,962 ; 0 ; 0) | identique |
| `Pneu_ArD` (1,631 ; 1,217 ; 30,264) − `Pneu_ArG` | (+5,952 ; 0 ; 0) | 2 × 2,976 |
| `Caisse_body` − `Pneu_AvG` (centres) | (2,981 ; 0,641 ; 4,379) | (2,981 ; 0,640 ; 4,379) |
| Size des pneus | avant 1,031 ; 2,379 ; 2,343 ; arrière 1,054 ; 2,434 ; 2,397 | identique |

**Lecture.**
- Échelle, orientation et positions relatives sont **exactes**, ce qui valide la règle d'étalonnage sur un vrai modèle.
- Les pièces arrivent en MeshParts nommées comme dans Blender, chacune dans un modèle `<nom>_Node`.
- Textures sans logos ; couleur de caisse, feux et caches de moyeu conformes aux rendus.

**Défaut constaté : vitrage opaque, gris clair.** Le pare-brise, les vitres et les petites pièces vitrées près de la roue
arrière sont touchés. La transparence du matériau glTF n'est pas reprise par l'importeur. C'est l'hypothèse « vitrage » de
la passe HF3 de l'Aster, désormais **observée**.

Piste, à l'intégration : la fabrique donne aux pièces de vitrage (`*_glass*`) un matériau Verre, une transparence d'au
moins 0,3 et une teinte sombre. Une autre voie serait une transparence portée par la texture (SurfaceAppearance) ; elle
est à essayer.

Lot VEH3D-01 (2026-11-04) : feux séparés en `COMETE_Feu_Av` (`AWLight = Head`) et `COMETE_Feu_Ar` (`Tail`), de 44 triangles chacun. Le LOD0 est réexporté (28 pièces, relu : centres à 0,0005 st près) et attend l'envoi sur Roblox par le propriétaire (`VEH3D_01_INTEGRATION_COMETE.md` §2).

Non vérifié :
- l'envoi sur Roblox des maillages (choix « Importer sur Roblox » du propriétaire) ;
- l'éclairage des feux (`AWLight`) ;
- la conduite, les LOD, les performances D5, les avatars à bord.
