# ASTER-02 — blockout « reproduction » de la référence (à valider)

Décision du propriétaire du 2026-11-04 (`ASTER_02_DECISIONS.md` §4 bis) : reproduire le véhicule de référence
**sans logo**, aux **proportions réelles**, face avant et détails compris. Le dessin « Trait » (blockout validé, passes HF1
à HF4) reste disponible et inchangé (`AW_ASTER_DESIGN=trait`, scène `wk_aster.blend`).

Statut :
- maquette volumique seulement, à revoir par le propriétaire avant toute passe haute fidélité ;
- aucun import, aucune publication, aucune fusion ;
- physique et carrosseries provisoires inchangées.

## 1. Méthode

Génération reproductible, sans interface. Scène séparée `vehicles/wk_aster/blend/wk_aster_reproduction.blend` ; le
dépôt d'art est à la branche `aster-02-blockout`.

```
AW_ASTER_DESIGN=reproduction AW_ASTER_STAGE=blockout blender --background vehicles/wk_aster/blend/wk_aster.blend --python tools/blender/aster02_blockout.py
```

**Relevé.** Le profil vient de la photo de profil du manifeste (`03_profil.jpg`, 1280 × 501 px). Les points sont
relevés à l'œil sur une grille de 10 px ; ils sont écrits dans le générateur (`TOP_PX` et voisins), avec leur
conversion :
- **horizontal** : les centres de roues de la photo (232 et 1032 px) sont placés sur les centres du gabarit (z −3,743 et
  +5,614). Les porte-à-faux de la photo sont ramenés aux extrémités de la définition du jeu ; les roues restent celles
  de la physique ;
- **vertical** : sol de la photo (472 à 478 px), 83,1 px par stud. Le dessus du pavillon tombe ainsi à la hauteur de la
  définition, 1,47 m.

**Précision estimée** : environ ±5 px, soit ±0,06 st. La perspective de la photo, qui comprime les extrémités, n'est
pas corrigée. Il n'existe ni vue de face ni vue de dos dans le manifeste : les largeurs et la face avant sont estimées
sur les vues de trois quarts.

## 2. Ce qui change par rapport à « Trait »

| Élément | Reproduction |
|---|---|
| Profil | relevé sur la photo : capot plongeant, pare-brise incliné (pied à z −2,30, haut à z +1,03), pavillon tendu, becquet de pavillon, lunette inclinée, hayon court |
| Hauteur | **1,472 m** mesurés (définition 1,47 m) au lieu de 1,721 m |
| Vitrage latéral | une baie continue du rétroviseur au montant C (montant B noir), bas de vitre montant de y 1,62 à 1,98 ; plus d'insert de custode |
| Ligne d'épaule | montante, du haut du phare au feu arrière |
| Face avant | phares fins sur le haut du nez, bandeau lumineux entre les phares, calandre haute fine, grande entrée d'air basse ; **emplacement du logo laissé lisse** |
| Arrière | lunette, feux en coin (épais à l'extérieur, minces vers le centre, sous la lunette) |
| Plan | coins plus carrés (superellipse d'ordre 12 au lieu de 8) |
| Bas de caisse | bande sombre entre y −1,36 et −0,94 (voir §4) |

## 3. Contrôles (`aster02_checks.py`) : 13 sur 15

| Contrôle | Résultat mesuré |
|---|---|
| Longueur, largeur | 15,19 st (définition 15,18) ; 6,34 st (définition 6,36) |
| Hauteur hors tout | **1,472 m** (cible de la reproduction : 1,47 m) |
| Roues | au sol, centres à 0,000 st du gabarit |
| Garnitures, moquette, pédales, planche de bord | dans les budgets |
| Mains | hors planche et console ; conducteur à 0,34 st au plus de la jante |
| Vue cockpit | 10,3° (règle : 10°) |
| **Ciel de toit** | **KO** : dessous à y 3,21, budget ≥ 3,65 (budget établi pour le toit à 4,20 st) |
| **Têtes** (points mesurés en VM, pose du jeu, toit 4,20) | **KO** : distance minimale 0,71 st (F1, conducteur), seuil 0,75 |

Ces deux échecs sont la conséquence attendue de la hauteur réelle (`ASTER_02_DECISIONS.md` §4 bis). L'écart sur les
têtes est faible au regard du seuil, mais il est mesuré sur les points relevés avec le toit à 4,20 st. Les cheveux,
les chapeaux et les grandes morphologies doivent être **remesurés en VM** sur ce modèle.

## 4. Écarts connus avec la référence (à arbitrer ou à traiter)

| Écart | Cause | Piste |
|---|---|---|
| Nez plus long, arrière plus court | Les roues suivent la physique : porte-à-faux avant 1,08 m et arrière 0,55 m dans la définition, contre environ 0,88 et 0,77 m sur la vraie voiture (estimation, non vérifiée par une source du dépôt) | Modifier `wheelLayout` dans la définition est un changement de physique, donc un lot séparé et sur accord |
| Bas de caisse 0,46 st plus bas que sur la photo | Plancher abaissé à −1,30 (décision antérieure) : la caisse doit le cacher | Bande sombre pour lire la bonne hauteur ; ou plancher relevé, à décider avec la reprise de l'habitacle |
| Hauteur sous pavillon | Hauteur réelle | Assise, pose et contrôles VM à reprendre ; aucune solution choisie |
| Formes fines | Le blockout ne les a pas encore : ouvrants, plis de capot, phares détaillés, jantes de la référence | Passes HF, après validation |
| Défauts visibles | Zigzag au bout intérieur des feux arrière (grille du feu sur la jonction hayon–caisse) ; bord du montant A en escalier, vu du cockpit ; dessous du plancher visible depuis l'arrière | Passes HF |

**Ressemblance.** De profil, le contour du modèle se superpose à la photo au niveau des roues, du pavillon, du
pare-brise et du hayon ; le nez dépasse et l'arrière est un peu court (§4). La comparaison côte à côte et la
superposition utilisent les photos tierces (CC BY-SA 4.0) : elles restent **hors du dépôt**, comme le demande le
manifeste, et ont été remises au propriétaire.

## 5. Captures (`captures/aster02_repro/`, modèle seul)

- `aster02_repro_planche.jpg` : 9 vues.
- Vues séparées :
  - `aster02_repro_34_avant.jpg`, `_34_arriere.jpg`, `_profil.jpg` ;
  - `_face.jpg`, `_arriere.jpg`, `_dessus.jpg` ;
  - `_habitacle.jpg`, `_vue_cockpit.jpg` ;
  - `_profil_ortho.jpg` (orthographique, 60 px par stud).

## 6. Non vérifié

- Habitacle avec les avatars (VM).
- Import Studio (témoin d'orientation v2).
- Vraies cotes de la référence : longueur, porte-à-faux, largeur du pavillon, qui ne sont pas dans le manifeste.
- Vue de face.
- Ressemblance : revue par le propriétaire.
