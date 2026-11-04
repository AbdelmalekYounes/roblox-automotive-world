# ASTER-02 — modèle haute fidélité de l'Aster

Point de départ : blockout **validé par le propriétaire le 2026-11-04** (`ASTER_02_BLOCKOUT.md`). Branche du jeu
`feat/aster-02-blockout`, branche du dépôt d'art `aster-02-blockout`.

HF1 acceptée par le propriétaire (« Oui, HF2 », 2026-11-04).

Statut :
- aucun import dans Studio, aucune publication, aucune intégration au jeu, aucune fusion ;
- physique et carrosseries provisoires inchangées.

## Plan par passes (une revue par captures à la fin de chaque passe)

| Passe | Contenu | État |
|---|---|---|
| **HF1** | Extérieur : carrosserie plus fine, découpée en panneaux séparés suivant le contrat d'ASTER-02 §2 (capot, hayon, 4 portières, boucliers avant et arrière), joints visibles, poignées affleurantes, plaques fictives, rétroviseurs sur pied, optiques, pneus toriques, jantes à 5 branches, disques | **Faite**, à revoir (§1) |
| **HF2** | Intérieur : planche de bord sculptée, combiné, console, volant à branches, sièges galbés, contre-portes, ciel de toit, dans les budgets `ENVELOPPES` | **Faite**, à revoir (§2) |
| HF3 | Matériaux, UV, textures originales (≤ 3 de 1024 px), peinture teintable par le jeu, vitrage transparent | À faire |
| HF4 | Niveaux de détail LOD1 et LOD2, boîtes de collision, réduction des triangles (§1.3), attaches | À faire |
| HF5 | Export glTF (réglage étalonné), import par le propriétaire (après le témoin d'orientation v2), essais VM : habitacle, sorties, cockpit, performances D5 | À faire, sur accord |

## 1. Passe HF1 — extérieur

Génération reproductible, sans interface :

```
AW_ASTER_STAGE=hf1 blender --background vehicles/wk_aster/blend/wk_aster.blend --python tools/blender/aster02_blockout.py
```

Le script part de la même surface que le blockout validé, à une résolution supérieure : 171 sections de 96 points.

### 1.1 Réalisé

- **Panneaux séparés**, découpés selon des plans droits puis classés par face :
  `ASTER_Caisse`, `ASTER_Capot`, `ASTER_Hayon`, `ASTER_BouclierAvant`, `ASTER_BouclierArriere`, `ASTER_PortiereAvG`,
  `ASTER_PortiereAvD`, `ASTER_PortiereArG`, `ASTER_PortiereArD`.
  - Chaque panneau a une épaisseur de 0,05 st, avec un rebord foncé qui marque les joints d'ouvrants.
  - Les portières vont du passage de roue au milieu du montant B (avant), puis du montant B au passage arrière
    (arrière), entre le bas de caisse et le bas du vitrage.
- **Détails** :
  - poignées affleurantes (saillie 0,015 st) ;
  - plaques fictives sans inscription ;
  - rétroviseurs : coque, pied, miroir ;
  - glaces claires sur les bandeaux lumineux « L ».
- **Roues** : pneu torique (section 0,385 × 0,732 st, ouvert au centre), jante à 5 branches avec rebord, fût, moyeu
  et disque, aux centres du gabarit.

### 1.2 Contrôles (`aster02_checks.py`) : 15 sur 15

Mêmes contrôles que pour le blockout :
- cotes et hauteur : 1,721 m hors tout ;
- budgets intérieurs ;
- têtes mesurées en VM : distance minimale 0,87 st ;
- mains ;
- vue cockpit : 10,3°.

### 1.3 Budget de triangles : dépassé à ce stade

Triangles évalués dans Blender (modificateurs appliqués) :

| Collection | Triangles |
|---|---|
| Extérieur | 79 300 |
| Intérieur (blockout) | 2 216 |
| Roues | 15 424 |
| **Total** | **96 940** |

C'est environ **4 fois** l'hypothèse de départ de la spécification (LOD0 15 000 à 25 000). Le critère d'acceptation reste
D5 (temps d'image + 2 ms sur la VM, non mesuré). Causes : la résolution de la caisse et l'épaisseur doublée de chaque
panneau. La réduction est prévue en HF4 :
- topologie allégée sur les surfaces planes ;
- panneaux sans épaisseur, rebord seulement aux joints ;
- roues instanciées ;
- LOD1 et LOD2.

### 1.4 Captures (`captures/aster02_hf1/`)

- `aster02_hf1_planche.jpg` : 8 vues.
- Vues séparées :
  - `aster02_hf1_34_avant.jpg`, `_34_arriere.jpg`, `_profil.jpg`, `_face.jpg` ;
  - `_arriere.jpg`, `_dessus.jpg` ;
  - `_detail_avant.jpg` (angle avant : « L », calandre, joint du capot) ;
  - `_detail_roue.jpg`.

### 1.5 Limites restantes

- Le joint entre le bouclier arrière et le hayon ondule légèrement côté gauche.
- Le bouclier avant et le bas du hayon sont toujours très arrondis : c'est la forme du blockout validé.
- Vitrage opaque dans les rendus (HF3) ; intérieur encore au niveau du blockout (HF2).
- Ressemblance avec la référence : revue visuelle par le propriétaire.

## 2. Passe HF2 — intérieur

Génération reproductible, sans interface (les passes sont cumulatives : `hf2` comprend `hf1`) :

```
AW_ASTER_STAGE=hf2 blender --background vehicles/wk_aster/blend/wk_aster.blend --python tools/blender/aster02_blockout.py
```

Sortie le 2026-11-04 : `AW_BLOCKOUT_OK hf2 51 70 40` (objets extérieur, intérieur, roues). Dépôt d'art, branche
`aster-02-blockout`, commits `1a519fd` (passe HF2) et `f257054` (rendu de l'habitacle).

### 2.1 Réalisé

Les pièces de l'intérieur du blockout sont remplacées ; le gabarit et les budgets `ENVELOPPES` sont inchangés.
- **Planche de bord** (`ASTER_PlancheDeBord`) : profil extrudé en bandeau sur toute la largeur, aérateurs, casquette
  au-dessus du combiné, écran flottant au centre.
- **Volant** : jante torique **inchangée** (rayon 0,55, section 0,065, inclinaison 15°), trois branches (à 3 h, 9 h et
  6 h), moyeu ; la vue cockpit reste mesurée sur cette jante.
- **Sièges** : coussin et dossier galbés avec maintiens latéraux, dossier toujours incliné de 18°, appui-tête sur
  tiges ; banquette arrière reprise dans le même dessin.
- **Contre-portes** (`ASTER_Garniture_D`, `ASTER_Garniture_G`) : panneau, accoudoir, seuil, poignée intérieure,
  haut-parleur.
- **Console** flottante avec sélecteur et accoudoir ; **ciel de toit**, pare-soleil, rétroviseur intérieur, tapis,
  pédalier et repose-pied.

### 2.2 Contrôles (`aster02_checks.py`) : 15 sur 15

Le contrôle des contre-portes porte désormais sur **toutes** leurs pièces (accoudoir, seuil, poignée…), pas seulement sur
le panneau.

| Contrôle | Résultat mesuré |
|---|---|
| Contre-porte passager | face intérieure x +2,829 (budget +2,83) |
| Contre-porte conducteur | face intérieure x −2,649 (budget −2,63) |
| Planche de bord | bas y 0,880 (≥ 0,86) ; face arrière z 0,432 (≤ 0,50) |
| Pédales | face arrière z −1,298 (budget ≤ −1,25) |
| Moquette, ciel de toit | dessus y −1,270 (≤ −1,26) ; dessous y 4,10 (≥ 3,65) |
| Têtes mesurées en VM | distance minimale 0,87 st (H4, siège conducteur ; seuil 0,75) |
| Mains | aucune dans la planche ou la console ; conducteur à 0,34 st au plus de la jante |
| Vue cockpit | 10,3° (règle : 10°) |
| Extérieur | longueur 15,24 st (définition 15,18, tolérance 0,10 ; plaques fictives comprises), hauteur 1,721 m |

Les marges des contre-portes sont faibles (1 à 2 cm de jeu) : toute pièce ajoutée plus tard devra repasser ce contrôle.

### 2.3 Triangles

| Collection | Triangles |
|---|---|
| Extérieur | 79 300 |
| Intérieur | 7 020 |
| Roues | 15 424 |
| **Total** | **101 744** |

L'intérieur ajoute 4 804 triangles. La réduction reste prévue en HF4 (§1.3).

### 2.4 Captures (`captures/aster02_hf2/`)

- `aster02_hf2_planche_revue.jpg` : 6 vues.
- `aster02_hf2_planche.jpg` (bandeau, combiné, écran), `_poste_conduite.jpg` (contre-porte passager masquée),
  `_sieges.jpg`, `_vue_cockpit.jpg` (depuis `CameraCockpit`), `_habitacle.jpg` (caisse, ciel de toit, pare-soleil et
  rétroviseur intérieur masqués), `_34_avant.jpg` (extérieur HF1, inchangé).

### 2.5 Limites restantes

- Jambes contre les maintiens des sièges et contre la console : **non mesuré** (points de jambes non relevés en VM).
- Bord de la baie au montant A en escalier, visible de l'intérieur.
- Vitrage opaque et matériaux provisoires (HF3).

## 3. Non vérifié

- Import dans Studio, orientation (témoin v2), rendu Roblox, essais VM sur le modèle, performances D5.
