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
| 2026-11-04 | [2017 Mclaren 720s](https://sketchfab.com/3d-models/2017-mclaren-720s-f7bece69400f4640a4a3be746b44998b) (6 917 faces) | s0h1o9b | CC BY 4.0 (page du modèle, relevée par l'API le 2026-11-04) ; description : « Modelled in Blender, textures made in Photoshop » | Essai d'import pour la Comète (`wk_comete`) | Propriétaire : « Tester la 720s » | **Attente du téléchargement** par le propriétaire ; inspection non faite |

## Modèles examinés et refusés

Voir `ASTER_02_DECISIONS.md` §4 ter. Les modèles de ddiaz-design (Golf GTI 2024, Golf R 2025, GR86, MX-5) déclarent
venir de jeux vidéo commerciaux ou d'un configurateur de constructeur : ils sont refusés.
