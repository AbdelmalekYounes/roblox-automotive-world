# ASTER-02 — dossier de lancement de la modélisation de l'Aster

Statut : **proposition, non lancée.** Aucune modélisation définitive, aucun import, aucune publication tant que le
propriétaire n'a pas validé ce dossier et levé les prérequis du §8. Rédigé à la clôture de la phase 1 (2026-11-04,
branche `feat/aster-phase1`). Références : `SPECIFICATION_MODELES_3D.md` (contrat général), `PIPELINE_BLENDER_ROBLOX.md`
(étapes), `ASTER_DESIGN_BRIEF.md` (direction A « Trait »), `ASTER_PHASE1.md` (mesures).

Repère : studs (1 st = 0,28 m), repère du véhicule du jeu (origine au centre du châssis, avant vers −Z, haut +Y,
droite +X, sol à y −1,786). Dans Blender : x → x, y → z, z → −y (1 unité = 1 stud).

## 1. Entrées (dépôt d'art privé, commits `edb57fc` et `254c94f`)

| Fichier | Contenu |
|---|---|
| `vehicles/wk_aster/blend/wk_aster.blend` | Scène du pipeline : collections, gabarit final en fil de fer verrouillé, repères d'intégration |
| `vehicles/wk_aster/ref-sheets/wk_aster_gabarit.{json,obj}` + `_params.json` | Gabarit final (23 blocs) et paramètres, exportés du jeu |
| `vehicles/wk_aster/ref-sheets/aster_trait_{profil,face}.{svg,png}` | Esquisses techniques « Trait » sur le gabarit final |
| `vehicles/wk_aster/ref-sheets/aster_habitacle_coupe.{svg,png}` | Coupe d'habitacle avec têtes, mains et pointes de pied mesurées (10 morphologies) |
| `vehicles/wk_aster/ref-sheets/mesures_vm_20261104-181108.jsonl` | Mesures brutes de la session VM `aster` |
| `calibration/temoins_*.fbx`, `temoins.glb` | Témoins d'échelle : **relevé dans Studio à faire par le propriétaire** (§8) |

Cotes du gabarit final (mesurées en VM, tâche `20261104-181108`, deux corps humains retenus, pose du jeu) :

| Élément | Valeur |
|---|---|
| Dessus de l'assise | y −0,04 ; siège conducteur x −1,40, z 2,42 ; passager x +1,40 |
| Dessous du pavillon | y 4,56 (assise + 4,60) ; cheveux au plus haut : assise + 3,39 (pose du jeu), + 3,76 (pose standard) |
| Plancher | dessus y −1,30, tôle 0,1 ; garde au sol 0,39 st (0,11 m) ; pieds 0,07 à 0,34 st au-dessus (pose du jeu) |
| Volant | centre (−1,40 ; 1,52 ; 1,10), rayon 0,55, incliné de 15° (haut vers le conducteur) ; mains à 0,15–0,34 st de la jante |
| Pédalier | z −1,4 (pointes de pied jusqu'à z −1,21) |
| Planche de bord | centre z 0, y 0,86 à 1,56 |
| Largeur intérieure | portières à x ±2,93 (faces internes) ; marge des bras ≥ 0,21 st |
| Hors tout | 1,83 m (définition physique : 1,47 m, inchangée) |

## 2. Liste des maillages

Nommage : `ASTER_<rôle>_<détail>` dans Blender, conservé à l'import. Matériaux : peinture teintable (couleur de
MeshPart), vitrage, caoutchouc, plastique, chrome, éclairage ; textures originales, ≤ 3 de 1024 px (hypothèse D5).

| Collection | Maillage | Rôle | LOD0 / LOD1 / LOD2 |
|---|---|---|---|
| EXT | `ASTER_Caisse` | Coque peinte (ailes, pavillon, montants) | oui / oui / silhouette |
| EXT | `ASTER_BouclierAvant`, `ASTER_BouclierArriere` | Boucliers peints, séparés (dégâts, tuning) | oui / fondus / fondus |
| EXT | `ASTER_Capot`, `ASTER_Hayon` | Ouvrants, pivot sur charnière, fermés en jeu (D4) | oui / fondus / fondus |
| EXT | `ASTER_PortiereAvG/AvD/ArG/ArD` | Portières, pivot sur charnière avant, fermées (D4) | oui / fondues / fondues |
| EXT | `ASTER_Vitrage_PareBrise`, `_Lunette`, `_Lateral*` | Verre, transparence ≥ 0,3 | oui / oui / opaque |
| EXT | `ASTER_Retro_G/D` | Rétroviseurs séparés | oui / oui / non |
| EXT | `ASTER_Feu_AvG/AvD` (attribut `AWLight = Head`), `ASTER_Feu_ArG/ArD` (`Tail`) | Signature « L » de la direction Trait | oui / oui / simplifiés |
| EXT | `ASTER_Calandre`, `ASTER_Embleme_Mivale` | Calandre fictive, emblème Mivale (dépôt d'art) | oui / oui / non |
| INT | `ASTER_PlancheDeBord`, `ASTER_Combine`, `ASTER_Console` | Intérieur | oui / simplifié / non |
| INT | `ASTER_Volant` | Pièce séparée, pivot sur l'axe de colonne | oui / simplifié / non |
| INT | `ASTER_Siege_Cond`, `ASTER_Siege_Pass`, `ASTER_Banquette` | Sièges, **avec embase et rails** (le gabarit laisse l'assise sans appui) | oui / simplifiés / non |
| INT | `ASTER_Pedalier`, `ASTER_Garnitures`, `ASTER_Plancher` | Plancher au niveau du gabarit (y −1,30) | oui / non / non |
| ROUES | `ASTER_Jante`, `ASTER_Pneu` (×4 instances) | Pivot au centre du moyeu, axe X | oui / oui / simplifiées |
| COLLISION | `COL_Coque`, `COL_BouclierAvant`, `COL_BouclierArriere`, `COL_Habitacle` | Boîtes simples, mêmes noms que les zones actuelles | — |
| LOD1, LOD2 | variantes des maillages ci-dessus | Bascule par `RenderFidelity` / `DetailLod` (à valider) | — |

## 3. Contrat des pivots et des attaches (repère du jeu)

| Élément | Position / pivot | Exigence |
|---|---|---|
| Roues (centres de moyeu) | AvG (−2,714 ; −0,661 ; −3,743), AvD (+2,714 ; −0,661 ; −3,743), ArG (−2,750 ; −0,661 ; +5,614), ArD (+2,750 ; −0,661 ; +5,614) ; rayon 1,125, largeur 0,732 | Issus de `VehicleDynamics.wheelLayout` ; tolérance ±0,05 st ; animées localement (`Motor6D.Transform`) |
| `DriverSeat` | dessus d'assise (−1,40 ; −0,04 ; 2,42) | Objet `Seat` du jeu ; attribut **`AWSeatPose = "Conduite"` obligatoire** (§5) |
| `PassengerSeat` | (+1,40 ; −0,04 ; 2,42) | `AWSeatPose = "Passager"` obligatoire |
| `CameraCockpit` | (−1,40 ; 2,14 ; 2,96) | Yeux du conducteur moyen (H3, tâche `20261104-181108`) |
| `CameraHood`, `CameraBumper` | à placer sur le modèle (capot, bouclier) | Comme aujourd'hui |
| `ExitLeft`, `ExitRight` | (∓4,68 ; −1,69 ; 2,42) | Au sol, hors carrosserie ; nouveau (le placement du passager reste lié à QA-A15) |
| Volant | pivot au centre (−1,40 ; 1,52 ; 1,10), axe de colonne incliné de 15° | Rotation visuelle locale (proposition) |
| Portières, capot, hayon | pivot sur la charnière | Fermés en jeu (D4) |
| Feux | pièces séparées | Attribut `AWLight` (`Head` / `Tail`) |
| Châssis | origine du repère | Inchangé : masse, collisions basses, attaches `Suspension*` / `Contact*` |

Toutes les pièces visuelles : `Massless`, `CanCollide`, `CanQuery` et `CanTouch` à faux, soudées au châssis. Les
collisions restent des boîtes simples, indépendantes du rendu.

## 4. Organisation du modèle

```
Blender (wk_aster.blend)                     Roblox (Model, PrimaryPart = Chassis, étiquette AWVehicle)
├─ REF        images (non exportées)          ├─ Chassis            objet du jeu (inchangé)
├─ GABARIT    fil de fer verrouillé           ├─ Carrosserie        MeshParts EXT + INT, soudés, sans masse
├─ EXT        carrosserie, vitrages, feux     │   └─ Details        LOD et détails fins (DetailLod)
├─ INT        habitacle                       ├─ DriverSeat / PassengerSeat (AWSeatPose)
├─ ROUES      jante + pneu                    ├─ Wheel<FL..RR>      jante + pneu par roue
├─ COLLISION  boîtes (non rendues)            └─ attaches Camera*, Exit*
├─ ATTACHES   empties (repères du §3)
└─ LOD1, LOD2
```

## 5. Tests R15 et performances (avant intégration définitive)

| Essai | Outil | Critère |
|---|---|---|
| Structure, noms, attributs, centres de roues | Lune (place construite) | 100 % des exigences du §3 ; écart des moyeux ≤ 0,05 st |
| Habitacle, deux corps × échelles extrêmes | VM `aster` adaptée au modèle (10 morphologies, 2 places, 2 poses) | Tête et cheveux sous le pavillon, bras dans l'habitacle, jambes et **pieds au-dessus du plancher**, mains sur la jante ≤ 0,35 st, vue au-dessus du volant ≥ 0 |
| Pose du jeu activée | VM `aster` | Les deux sièges portent `AWSeatPose` (sinon, pose standard : pieds jusqu'à 0,42 st sous le plancher, tâche `20261104-181108`) |
| Avatars, sorties, cockpit | VM `avatar`, `silhouette` | Aucune régression par rapport à la tâche `20261104-181108` |
| Réplication | VM `silhouette2` | Corps vu identique par un autre client |
| Performances (D5) | VM `perf`, monde ouvert | 24 Aster visibles, jour et nuit : temps d'image ≤ référence actuelle + 2 ms ; mémoire graphique relevée |
| Rendu | captures inspectées, essai humain du propriétaire | Signature « Trait », lisibilité, vitrages |

## 6. Étapes d'importation Roblox

1. **Étalonnage (prérequis)** : le propriétaire importe les témoins `calibration/` dans Studio et relève `Size` ; le
   réglage d'export qui donne un cube de 10 × 10 × 10 est consigné dans `PIPELINE_BLENDER_ROBLOX.md` §4.
2. Modélisation dans `wk_aster.blend`, autour du gabarit verrouillé. Revue des captures Blender par le propriétaire
   avant tout export.
3. Export au réglage étalonné (FBX ou glTF), un fichier par collection exportée.
4. Import dans une place **locale** de Studio. L'envoi des maillages sur Roblox crée des actifs : c'est le
   **propriétaire qui les publie**, sous le créateur de l'expérience (D6). L'assistant ne publie rien.
5. Montage selon §4, attaches et attributs du §3, collisions simples, `Massless`.
6. Essais du §5 dans la VM, puis essai humain du propriétaire.
7. Remplacement de la carrosserie provisoire de l'Aster seulement, sur une branche de lot, après validation.

## 7. Hors du périmètre d'ASTER-02

- Les 17 autres véhicules et les carrosseries provisoires : elles ne sont pas redimensionnées (QA-A13, A14, A17, A21
  restent ouvertes pour elles).
- Animation des ouvrants (D4) et tuning.
- Sortie du passager (QA-A15, en attente de décision).

## 8. Prérequis et décisions avant le lancement

| # | Point | État |
|---|---|---|
| 1 | Valider le **plancher abaissé** (−1,30 st, bas de caisse à 0,39 st du sol) | Changement de géométrie de la clôture, **à valider** |
| 2 | Relever l'étalonnage Blender → Studio (§6.1) | **À faire par le propriétaire** |
| 3 | Vue au-dessus du volant pour la plus petite morphologie (H5 : −0,03 st) : accepter, ou pose adaptée à la taille | **À arbitrer** |
| 4 | Corps par défaut avant le choix du joueur (masculin, provisoire) | À confirmer |
| 5 | Couleurs de peau du joueur conservées (ruptures visibles, captures de la clôture) | À arbitrer |
| 6 | Hauteur sous pavillon : 4,60 st conservés ou ≈ 4,00 st (cheveux au plus haut : assise + 3,76 en pose standard) | À arbitrer |
| 7 | D7, largeur : marges positives avec les deux corps (≥ 0,21 st) | À confirmer comme sans objet |
