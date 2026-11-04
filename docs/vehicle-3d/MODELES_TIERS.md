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
| 2026-11-04 | [2017 Mclaren 720s](https://sketchfab.com/3d-models/2017-mclaren-720s-f7bece69400f4640a4a3be746b44998b) (6 917 faces) | s0h1o9b | CC BY 4.0 (page du modèle, relevée par l'API le 2026-11-04) ; description : « Modelled in Blender, textures made in Photoshop » | Essai d'import pour la Comète (`wk_comete`) | Propriétaire : « Tester la 720s » | Téléchargé par le propriétaire ; **inspecté le 2026-11-04** (§1) ; préparation en attente de sa décision |

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
