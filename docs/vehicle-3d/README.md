# Véhicules 3D — références et préparation

Préparation des modèles 3D des 18 véhicules proposés ; catalogue toujours proposé. Seule la **Comète** a une
carrosserie 3D intégrée (VEH3D-01 : modèle tiers CC BY, maillages envoyés par le propriétaire) ; les 17 autres gardent
leur carrosserie provisoire. **ASTER-02 est suspendu** depuis le 2026-11-04 : ses documents de modélisation restent
sur la PR #15 (`feat/aster-02-blockout`).

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
| [ASTER_02_LANCEMENT.md](ASTER_02_LANCEMENT.md) | Dossier de lancement de la modélisation de l'Aster (lancée, puis **suspendue** le 2026-11-04) |
| `ASTER_02_HAUTE_FIDELITE.md` (PR #15, suspendu) | Modèle haute fidélité de l'Aster, passes HF1 à HF4 |
| [VEH3D_01_INTEGRATION_COMETE.md](VEH3D_01_INTEGRATION_COMETE.md) | Lot VEH3D-01 : intégration de la Comète 3D (plan, étape du propriétaire, essais) |
| [VEH3D_01_CLOTURE.md](VEH3D_01_CLOTURE.md) | Rapport de finalisation de la Comète (état, limites, décisions) |
| [VEH3D_01_REVUE.md](VEH3D_01_REVUE.md) | Fiche de revue de la Comète et résultat de la revue du propriétaire (2026-11-05) |
| [MODELES_TIERS.md](MODELES_TIERS.md) | Registre des modèles 3D tiers : conditions, exceptions accordées par le propriétaire, inspections, préparations (crédits : `../CREDITS_ACTIFS.md`) |
| `ASTER_02_REPRODUCTION.md`, `ASTER_02_BLOCKOUT.md` (PR #15, suspendu) | Blockouts « reproduction » et « Trait » de l'Aster |
| [ASTER_02_DECISIONS.md](ASTER_02_DECISIONS.md) | Journal des décisions : pose (H5), toit, couleurs, marges ; jeu jamais monétisé, exception 720s, suspension d'ASTER-02 (§4 ter, §4 quater) |
| [ASTER_PHASE1.md](ASTER_PHASE1.md) | Phase 1 de l'Aster : pose assise du jeu, gabarit mesuré en VM, avatars humains (deux corps au choix), étalonnage |

Décisions prises (2026-11-04) : direction **A « Trait »** pour l'Aster ; D1 habitacle **« échelle Roblox + assise
basse »** ; D3 **pose assise propre au jeu** ; D4 **ouvrants animés plus tard** ; D5 **+2 ms avec 24 véhicules visibles** ; D6 **actifs publiés par le propriétaire sous le créateur de
l'expérience, sources dans un dépôt d'art privé (Git LFS)** ; langage commun **plusieurs marques fictives, signature
par famille**. Répartition en 4 marques validée ; noms **Mivale, Orvane, Rocalt, Celvar** et emblèmes **validés** (2026-11-04), dans le [dépôt d'art privé](https://github.com/AbdelmalekYounes/roblox-automotive-world-art) ; recherche d'antériorité officielle à faire avant tout usage commercial.

Outil de mesure (lecture seule) : `lune run tests/lune/tools/cabin-geometry.luau build/AutomotiveWorld.rbxlx`.
