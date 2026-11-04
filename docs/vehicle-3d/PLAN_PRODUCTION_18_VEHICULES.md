# Plan de production des 18 véhicules 3D

Statut : **proposition**. Aucune production 3D définitive avant validation du propriétaire. Le catalogue des 18 modèles
reste **proposé** (`docs/lot-0.8/CATALOGUE_18_VEHICULES.md`, `PendingApproval`) ; ce plan ne l'approuve pas.

## 1. Phases et portes de validation

| Phase | Contenu | Porte (décision du propriétaire) |
|---|---|---|
| 0 | Références des 18 modèles, fiches de design, spécification, pipeline (**ce lot**) | Validation des documents et des décisions D1 à D6 |
| 1 | **Aster pilote** : étalonnage de l'échelle, gabarit, esquisses des 3 directions, maquette volumique, essai R15 en VM | Direction de l'Aster et langage de design commun |
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
| D1 | Proportions de l'habitacle face aux avatars R15 (spécification §3.3 : échelle Roblox, assise basse, limitation du type de corps, combinaison) |
| D2 | Direction artistique de l'Aster (A, B ou C, `ASTER_DESIGN_BRIEF.md`) et langage commun de la gamme (signature lumineuse, monogramme fictif) |
| D3 | Animation de conduite : pose assise propre au jeu ou IK des mains sur le volant |
| D4 | Ouvrants animés (portières) : maintenant ou plus tard |
| D5 | Critère de performance (spécification §6) |
| D6 | Qui importe et publie les actifs (le propriétaire) et où sont rangés les fichiers sources (dépôt d'art séparé, non public) |

## 4. Risques

- Ressemblance trop proche d'un modèle réel (marque, calandre, signature lumineuse) : revue de dissemblance à chaque
  porte, voir `DIRECTION_ARTISTIQUE_VEHICULES.md` §1.
- Habitacles bas des sportives et supercars incompatibles avec les grands avatars sans décision D1.
- Budget de performance avec 24 joueurs : mesurer dès l'Aster, avant la duplication.
- Droits des images de référence : usage interne de travail uniquement (`SOURCES_IMAGES.md`).
