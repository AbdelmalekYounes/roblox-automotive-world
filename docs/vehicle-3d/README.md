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
| [ASTER_PHASE1_CLOTURE.md](ASTER_PHASE1_CLOTURE.md) | Clôture de la phase 1 : essais par vrais clics, file d'application, anomalies, recommandation |
| [ASTER_02_LANCEMENT.md](ASTER_02_LANCEMENT.md) | Dossier de lancement de la modélisation de l'Aster (non lancée) |
| [ASTER_PHASE1.md](ASTER_PHASE1.md) | Phase 1 de l'Aster : pose assise du jeu, gabarit mesuré en VM, avatars humains (deux corps au choix), étalonnage |

Décisions prises (2026-11-04) : direction **A « Trait »** pour l'Aster ; D1 habitacle **« échelle Roblox + assise
basse »** ; D3 **pose assise propre au jeu** ; D4 **ouvrants animés plus tard** ; D5 **+2 ms avec 24 véhicules visibles** ; D6 **actifs publiés par le propriétaire sous le créateur de
l'expérience, sources dans un dépôt d'art privé (Git LFS)** ; langage commun **plusieurs marques fictives, signature
par famille**. Répartition en 4 marques validée ; noms **Mivale, Orvane, Rocalt, Celvar** et emblèmes **validés** (2026-11-04), dans le [dépôt d'art privé](https://github.com/AbdelmalekYounes/roblox-automotive-world-art) ; recherche d'antériorité officielle à faire avant tout usage commercial.

Outil de mesure (lecture seule) : `lune run tests/lune/tools/cabin-geometry.luau build/AutomotiveWorld.rbxlx`.
