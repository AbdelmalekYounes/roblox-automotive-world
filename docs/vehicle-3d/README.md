# Véhicules 3D — références et préparation

Préparation des futurs modèles 3D des 18 véhicules proposés. **Aucune géométrie définitive, aucun import ni publication
d'actif, aucune modification de la physique ni des carrosseries provisoires** ; catalogue toujours proposé.

| Document | Contenu |
|---|---|
| [CATALOGUE_REFERENCES.md](CATALOGUE_REFERENCES.md) | Véhicule fictif ↔ référence réelle, couverture des angles, images manquantes |
| [SOURCES_IMAGES.md](SOURCES_IMAGES.md) | Méthode, pages officielles (liens), 121 images retenues avec auteur, licence, URL, date |
| [references/](references/) | Un manifeste par véhicule (`manifest.json`, `MANIFEST.md`) ; images hors dépôt |
| [DIRECTION_ARTISTIQUE_VEHICULES.md](DIRECTION_ARTISTIQUE_VEHICULES.md) | Règles de transformation, habitacles et avatars R15, 18 fiches |
| [SPECIFICATION_MODELES_3D.md](SPECIFICATION_MODELES_3D.md) | Contrat d'intégration Roblox, cotes R15, LOD, matériaux, budget mesurable |
| [PIPELINE_BLENDER_ROBLOX.md](PIPELINE_BLENDER_ROBLOX.md) | Étapes, scène Blender, échelle étalonnée, intégration, validation |
| [ASTER_DESIGN_BRIEF.md](ASTER_DESIGN_BRIEF.md) | Véhicule pilote : fiche, trois directions, habitacle, budget, validation |
| [PLAN_PRODUCTION_18_VEHICULES.md](PLAN_PRODUCTION_18_VEHICULES.md) | Phases, familles, décisions D1 à D6, risques |

Décisions prises (2026-11-04) : direction **A « Trait »** pour l'Aster ; D1 habitacle **« échelle Roblox + assise
basse »** ; D3 **pose assise propre au jeu**. Décisions à prendre : D2 (suite) langage commun de la gamme ; D4 ouvrants animés ; D5 critère de performance ; D6 import, publication et
rangement des fichiers sources.

Outil de mesure (lecture seule) : `lune run tests/lune/tools/cabin-geometry.luau build/AutomotiveWorld.rbxlx`.
