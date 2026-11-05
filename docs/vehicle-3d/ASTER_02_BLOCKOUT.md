# ASTER-02 — blockout extérieur et intérieur de l'Aster (à valider)

Branche du jeu `feat/aster-02-blockout` (base `feat/aster-phase1`). Branche du dépôt d'art `aster-02-blockout`,
commits `087d98e` et `31a20cc`. Le 2026-11-04.

Statut : **blockout validé par le propriétaire (« Je valide », 2026-11-04)** ; passage au modèle haute fidélité
(`ASTER_02_HAUTE_FIDELITE.md`). Rapport d'origine ci-dessous.
- Le modèle n'est pas importé dans Studio et n'est pas intégré au jeu.
- Aucun actif n'est publié et rien n'est fusionné.
- La physique et les carrosseries provisoires sont inchangées.

## 1. Ce qui a été produit

| Élément | Contenu |
|---|---|
| Carrosserie (`ASTER_Caisse`) | **Surface lofée**, et non des blocs. 111 sections superellipses le long de l'axe (haut arrondi, flancs droits jusqu'au bas de caisse). Profils supérieur et inférieur en interpolation cubique monotone : bouclier droit, capot court, pare-brise incliné, pavillon tendu, hayon presque vertical. Rentrée du vitrage au-dessus de la ligne de caisse, passages de roues découpés, baies ouvertes sous les vitrages, épaisseur de 0,06 st |
| Vitrages | Panneaux séparés posés sur la surface : pare-brise, bandeau latéral continu (montant B noirci), insert vitré de custode qui « fait flotter » le pavillon (« Trait »), lunette |
| Signature et détails | Nervure d'épaule continue, signature lumineuse « L » aux quatre angles (Mivale), calandre fermée à motif de lignes, emblème (volume réservé), rétroviseurs |
| Roues | Pneu et jante par roue, aux centres du gabarit, axe X |
| Intérieur | Planche de bord en bandeau, combiné sous casquette, console flottante, volant (tore incliné de 15° et colonne), deux sièges (coussin au dessus d'assise, dossier incliné de 18° comme le buste de la pose du jeu, appui-tête, embase, rails), banquette arrière simplifiée, garnitures de portière, moquette, pédalier, ciel de toit |
| Repère cockpit | `CameraCockpit` recalé sur la **jante réelle** : (−1,40 ; **2,32** ; 2,07) au lieu de 2,24 (voir §3) |

Scripts versionnés dans le dépôt d'art (`tools/blender/`) :
- `aster02_blockout.py` : génération, reproductible depuis le gabarit et sans interface ;
- `aster02_checks.py` : contrôles ;
- `aster02_render.py` : rendus.

Création originale : aucune géométrie reprise d'un modèle existant, aucun actif Marketplace.

## 2. Contrôles automatiques (Blender 4.5.9 sans interface, `aster02_checks.py`) : 15 sur 15

| Contrôle | Résultat mesuré |
|---|---|
| Longueur | 15,21 st (définition 15,18) |
| Largeur hors rétroviseurs | 6,34 st (définition 6,36) |
| Hauteur hors tout | **1,721 m** (décision : 1,72 m) |
| Roues au sol, centres de roues | point bas −1,786 (sol −1,786) ; écart des centres 0,000 st |
| Ciel de toit | dessous à y 4,10 (budget ≥ 3,65) |
| Garnitures | face intérieure x +2,849 côté passager (budget +2,83) ; −2,749 côté conducteur (budget −2,63) |
| Moquette | dessus y −1,270 (budget ≤ −1,26) |
| Pédales | face arrière z −1,295 (budget ≤ −1,25) |
| Planche de bord | bas y 0,900 (≥ 0,86) ; face arrière z 0,420 (≤ 0,50) |
| Têtes mesurées en VM (pose du jeu, 10 morphologies, 2 places) | distance minimale à la géométrie 0,87 st (seuil 0,75 : demi-profondeur d'une tête réaliste) |
| Mains | aucune dans la planche de bord ou la console ; mains du conducteur à 0,34 st au plus de la jante |
| Vue cockpit | haut réel de la jante y 2,114 à z 0,94, à **10,3°** sous la ligne de visée depuis `CameraCockpit` |

Points mesurés utilisés : session VM `aster`, tâche `20261104-193715` (toit à 4,20 st). Ces contrôles portent sur la
géométrie dans Blender. **Ils ne remplacent pas une mesure en VM sur le modèle importé**, qui n'a pas encore été faite.

## 3. Défauts trouvés et corrigés pendant le blockout

| Défaut | Correction |
|---|---|
| Dossier incliné vers l'avant, dans les têtes (distance 0,14 st) | Dossier incliné de 18° vers l'arrière, articulé au bord du coussin |
| Point de vue cockpit : la règle de la fabrique (haut du volant = centre + 0,55) ignore la section de la jante et son inclinaison ; le haut réel part vers l'avant | `CameraCockpit` passe à y 2,32 : 10,3° mesurés sur la géométrie, 10° minimum. Dossier ASTER-02 et test Lune mis à jour. La fabrique des carrosseries provisoires est inchangée |
| Largeur dépassant de 0,03 st par côté (vitrages, nervure) | Caisse rétrécie de 0,04 st |
| Pédales dépassant le budget | Reculées de 0,08 st |
| Feux et emblème posés sur le capot, nervure repliée sur le capot, éclats de vitrage | Feux et emblème placés sur le bouclier par calcul de la surface ; nervure limitée à la zone utile ; baies ouvertes avec une marge sous chaque vitre |

## 4. Captures (rendus Workbench, `captures/aster02/`)

- `aster02_blockout_planche.jpg` : planche des 8 vues.
- Vues séparées :
  - `aster02_blockout_34_avant.jpg`, `_34_arriere.jpg`, `_profil.jpg` ;
  - `_face.jpg`, `_arriere.jpg`, `_dessus.jpg` ;
  - `_habitacle.jpg` (caisse, ciel de toit et garniture côté caméra masqués) ;
  - `_vue_cockpit.jpg` (depuis `CameraCockpit`, vitrage masqué).

## 5. Limites connues du blockout (à traiter en haute fidélité si la direction est validée)

- Bouclier avant et bas du hayon très arrondis : la silhouette garde un aspect « galet » aux extrémités.
- Vitrage très haut : environ 2,2 st (0,62 m) entre le bas des vitres et le haut du vitrage. C'est la conséquence directe de la
  hauteur sous pavillon retenue.
- Pas de lignes d'ouvrants (portières, capot, hayon) ni de pièces séparées. Elles viendront avec le modèle haute
  fidélité (liste du dossier de lancement §2).
- Bords des baies en escalier, visibles seulement de l'intérieur ; pas d'UV, de LOD, de collisions ni de matériaux
  définitifs.
- Roues légèrement en retrait du flanc ; pas de jante détaillée.

## 6. Non vérifié

- **Import dans Studio** : il attend la confirmation de l'orientation par le témoin v2
  (`calibration/temoins_orientation_v2.glb`), à relever par le propriétaire.
- Essais VM sur le modèle importé (habitacle, sorties, cockpit, performances D5).
- Rendu des vitrages transparents, qui sont opaques en blockout.
- Ressemblance avec la référence : revue visuelle à faire par le propriétaire (dissemblance renforcée, direction A).

## 7. Décision

Maquette volumique **validée par le propriétaire le 2026-11-04** : silhouette, proportions, vitrage, signature et
intérieur. Le modèle haute fidélité part de cette maquette.
