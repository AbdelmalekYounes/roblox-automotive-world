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
| 2026-11-04 | [2017 Mclaren 720s](https://sketchfab.com/3d-models/2017-mclaren-720s-f7bece69400f4640a4a3be746b44998b) (6 917 faces) | s0h1o9b | CC BY 4.0 (page du modèle, relevée par l'API le 2026-11-04) ; description : « Modelled in Blender, textures made in Photoshop » | Essai d'import pour la Comète (`wk_comete`) | Propriétaire : « Tester la 720s » | Téléchargé par le propriétaire ; inspecté (§1) ; **préparé le 2026-11-04, à revoir** (§2) ; non intégré |

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

Non fait, non vérifié :
- sièges, attaches (`SeatDriver`, caméras, sorties), collisions ;
- LOD ;
- habitacle avec les avatars (VM) ;
- import Studio ;
- crédit affiché dans le jeu (`docs/CREDITS_ACTIFS.md`, à l'intégration).
