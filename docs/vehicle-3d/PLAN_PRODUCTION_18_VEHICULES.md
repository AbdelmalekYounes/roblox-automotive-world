# Plan de production des 18 véhicules 3D

Statut : **proposition**. Aucune production 3D définitive avant validation du propriétaire. Le catalogue des 18 modèles
reste **proposé** (`docs/lot-0.8/CATALOGUE_18_VEHICULES.md`, `PendingApproval`) ; ce plan ne l'approuve pas.

## 1. Phases et portes de validation

| Phase | Contenu | Porte (décision du propriétaire) |
|---|---|---|
| 0 | Références des 18 modèles, fiches de design, spécification, pipeline (**ce lot**) | Validation des documents et des décisions D1 à D6 |
| 1 | **Aster pilote** (direction A « Trait » retenue) : pose assise du jeu (essai VM), étalonnage de l'échelle, gabarit, esquisses, maquette volumique, essai R15 en VM | Pose assise validée, langage de design commun |
| 2 | Aster haute fidélité, LOD, collisions, matériaux, intégration derrière un kit de maillages (provisoire en repli) | Budget de performance mesuré (VM `perf`), essais `avatar` |
| 3 | Familles de silhouettes (gabarits d'habitacle partagés) | Validation par famille |
| 4 | Finitions, nuit, dégâts visuels, captures, essais humains | Recette finale |

## 2. Familles (ordre proposé après l'Aster)

| Ordre | Famille | Modèles | Raison |
|---|---|---|---|
| 1 | Compactes et citadines | Aster (pilote), Brio, Fil, Rafale, Pixel | habitacle commun de l'Aster réutilisé et adapté |
| 2 | Berlines et break | Nova, Cadence, Lumen, Orée | même plate-forme d'habitacle, carrosseries plus longues |
| 3 | SUV et tout-terrain | Dune, Vigie, Sentier, Atlas | habitacles hauts (les plus proches de la cible R15 aujourd'hui) |
| 4 | Sportives et GT | Brise, Éclat, Mistral | habitacles bas : pose de conduite et décision D1 critiques |
| 5 | Supercars | Comète, Zénith | habitacle le plus bas (2,20 et 2,27 st aujourd'hui) : en dernier |

## 3. Décisions à prendre avant la phase 1

| Id | Décision |
|---|---|
| D1 | Proportions de l'habitacle : **« échelle Roblox + assise basse » retenue par le propriétaire (2026-11-04)** (spécification §3.3, option 4) ; dépend de D3 pour la pose assise |
| D2 | Direction de l'Aster : **A « Trait » retenue par le propriétaire (2026-11-04)** ; langage commun : **plusieurs marques fictives, signature par famille** (propriétaire, 2026-11-04) ; **répartition en 4 marques validée** ; noms (après vérification des droits) et emblèmes à valider (`DIRECTION_ARTISTIQUE_VEHICULES.md` §1 bis) |
| D3 | Animation de conduite : **pose assise propre au jeu retenue par le propriétaire (2026-11-04)** (spécification §3.3) ; réalisation (animation publiée ou pose procédurale) à départager par un essai en VM |
| D4 | Ouvrants animés : **plus tard, retenu par le propriétaire (2026-11-04)** ; pièces séparées et charnières préparées dans chaque modèle, fermées en jeu, embarquement instantané inchangé |
| D5 | Critère de performance : **+2 ms de temps d'image avec 24 véhicules visibles, retenu par le propriétaire (2026-11-04)** (spécification §6) ; appareils réels à essayer avant le lancement |
| D6 | **Retenu par le propriétaire (2026-11-04)** : actifs importés et publiés **par le propriétaire**, sous le **même créateur que l'expérience** ; fichiers sources dans un **dépôt GitHub d'art privé séparé avec Git LFS** (à créer par le propriétaire) ; le dépôt du jeu ne garde que manifestes et identifiants |

## 4. Risques

- Ressemblance trop proche d'un modèle réel (marque, calandre, signature lumineuse) : revue de dissemblance à chaque
  porte, voir `DIRECTION_ARTISTIQUE_VEHICULES.md` §1.
- Habitacles bas des sportives et supercars incompatibles avec les grands avatars sans décision D1.
- Budget de performance avec 24 joueurs : mesurer dès l'Aster, avant la duplication.
- Droits des images de référence : usage interne de travail uniquement (`SOURCES_IMAGES.md`).
