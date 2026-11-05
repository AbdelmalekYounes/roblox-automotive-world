# Pipeline Blender → Roblox Studio

Statut : **proposition**. Aucune géométrie définitive, aucun import, aucune publication d'actif sans validation du
propriétaire (`CLAUDE.md`). Spécification technique : `SPECIFICATION_MODELES_3D.md`.

## 1. Étapes

| # | Étape | Entrée | Sortie | Validation |
|---|---|---|---|---|
| 1 | Références | manifeste du véhicule (`references/<id>/`) | planche de références (locale) | sources et licences tracées |
| 2 | Fiche de design | fiche du véhicule (`DIRECTION_ARTISTIQUE_VEHICULES.md`) | direction retenue par le propriétaire | **validation propriétaire** |
| 3 | Gabarit technique | définition du jeu (dimensions, centres de roues, assises, caméras) | gabarit à l'échelle (blocs) dans Blender | cotes contrôlées contre la définition |
| 4 | Esquisses | gabarit + direction | 2 à 3 esquisses (profil, 3/4) | **validation propriétaire** |
| 5 | Maquette volumique (blockout) | esquisse retenue | volumes sans détail, habitacle aux cotes R15 | essai VM `avatar` sur la maquette |
| 6 | Modèle haute fidélité | maquette validée | carrosserie, roues, intérieur, LOD0 | revue visuelle |
| 7 | LOD et collisions | LOD0 | LOD1, LOD2, boîtes de collision | budget (VM `perf`) |
| 8 | Matériaux | modèle | UV, textures originales, matériaux | teinte de peinture vérifiée |
| 9 | Import Studio | fichiers exportés | MeshParts dans un fichier de travail local | **import et publication par le propriétaire** |
| 10 | Intégration | identifiants d'actifs approuvés | chemin de fabrication 3D à côté de `BodyKits` | Lune + VM (§6) |

## 2. Gabarit technique (étape 3)

Généré depuis le jeu, jamais retapé à la main : dimensions de `WorkingCatalog`, centres de roues
(`VehicleDynamics.wheelLayout`), hauteurs actuelles d'assise et de pavillon (`tests/lune/tools/cabin-geometry.luau`),
cibles R15 de la spécification §3.3. Un outil d'export du gabarit (fichier texte de cotes ou maillage de blocs) est une
**proposition** de la phase suivante.

## 3. Organisation de la scène Blender

```
<id>.blend
├─ REF        planches de références (non exportées)
├─ GABARIT    blocs du gabarit technique (non exportés)
├─ EXT        Carrosserie, Portiere_AVG/AVD/ARG/ARD, Capot, Coffre, Vitrage_*, Retro_G/D,
│             Phare_G/D (AWLight=Head), Feu_G/D (AWLight=Tail), Bouclier_AV/AR, Tuning_*
├─ INT        PlancheDeBord, Combine, Console, Volant (pivot colonne), Siege_Cond, Siege_Pass,
│             Pedales, Garnitures
├─ ROUES      Jante_FL/FR/RL/RR, Pneu_* (pivot moyeu, axe X)
├─ COLLISION  Coque, BouclierAvant, BouclierArriere, Habitacle (boîtes simples)
├─ ATTACHES   empties : CameraCockpit, CameraHood, CameraBumper, ExitLeft, ExitRight, SeatDriver, SeatPassenger
└─ LOD1, LOD2
```

Conventions : noms ASCII en PascalCase, origine des pièces au repère du véhicule (avant −Z), transformations
appliquées avant export, un matériau par famille (peinture, verre, pneu, chrome, intérieur).

## 4. Échelle et export

- Étalonnage **par essai** avant tout modèle : un cube témoin de 10 st et un cylindre de roue de rayon connu sont
  exportés, importés dans Studio (3D Importer) et mesurés ; le facteur d'échelle et l'orientation retenus sont consignés
  ici. (Les réglages d'export ne sont pas supposés : ils sont mesurés.)
- Format d'échange proposé : FBX ou glTF, une exportation par groupe (EXT, INT, ROUES, LOD).

## 5. Intégration Roblox (proposition, non implémentée)

- Nouveau chemin de fabrication à côté de `BodyKits` : la définition désigne un **kit de maillages** ; la fabrique crée
  le même contrat (châssis, collisions, sièges, roues, caméras) et y soude les MeshParts visuels.
- Les identifiants d'actifs vivent dans `Shared.Assets.AssetManifest` (aucun identifiant aujourd'hui), après import et
  publication **par le propriétaire** ; contrôle Lune : un modèle 3D sans identifiant approuvé retombe sur sa
  carrosserie provisoire.
- **D6 (propriétaire, 2026-11-04)** : les actifs appartiennent au **même créateur que l'expérience** (compte ou groupe
  qui la possède), pour éviter tout problème de droits d'utilisation ; import et publication par le propriétaire
  uniquement ; identifiants reportés dans `AssetManifest` par une PR relue.
- **Fichiers sources** (`.blend`, textures, exports) : dépôt GitHub **d'art privé séparé** avec **Git LFS**,
  **créé le 2026-11-04** : [roblox-automotive-world-art](https://github.com/AbdelmalekYounes/roblox-automotive-world-art) (privé) ; arborescence
  `vehicles/<id>/{blend,textures,export,ref-sheets}` et `brands/<marque>/` ; le dépôt du jeu ne
  contient que les manifestes, les gabarits et les identifiants ; aucune photographie de référence n'y est versionnée.
- Volant animé localement (comme les roues) : à implémenter avec le modèle pilote.

## 6. Validation de chaque modèle

1. Lune : noms, attributs `AWLight`, attaches présentes, centres de roues à ±0,05 st, collisions séparées du rendu,
   triangles et textures dans le budget.
2. VM `avatar` (8 morphologies, deux places) : tête sous le pavillon (cible §3.3), flancs, planche de bord, sorties,
   cockpit masqué, téléphone.
3. VM `perf` : budget de la spécification §6 avec 8, 16 et 24 véhicules.
4. VM `lot08` : banc des 18 modèles (pose, structure).
5. Captures inspectées (extérieur 3/4, profil, cockpit, nuit) ; essai humain.
