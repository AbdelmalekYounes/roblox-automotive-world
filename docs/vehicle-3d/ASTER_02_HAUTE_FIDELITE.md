# ASTER-02 — modèle haute fidélité de l'Aster

Point de départ : blockout **validé par le propriétaire le 2026-11-04** (`ASTER_02_BLOCKOUT.md`). Branche du jeu
`feat/aster-02-blockout`, branche du dépôt d'art `aster-02-blockout`.

HF1 acceptée par le propriétaire (« Oui, HF2 », 2026-11-04) ; HF2 acceptée (« Oui, HF3 », 2026-11-04).

Statut :
- aucun import dans Studio, aucune publication, aucune intégration au jeu, aucune fusion ;
- physique et carrosseries provisoires inchangées.

## Plan par passes (une revue par captures à la fin de chaque passe)

| Passe | Contenu | État |
|---|---|---|
| **HF1** | Extérieur : carrosserie plus fine, découpée en panneaux séparés suivant le contrat d'ASTER-02 §2 (capot, hayon, 4 portières, boucliers avant et arrière), joints visibles, poignées affleurantes, plaques fictives, rétroviseurs sur pied, optiques, pneus toriques, jantes à 5 branches, disques | **Faite**, à revoir (§1) |
| **HF2** | Intérieur : planche de bord sculptée, combiné, console, volant à branches, sièges galbés, contre-portes, ciel de toit, dans les budgets `ENVELOPPES` | **Faite**, acceptée (§2) |
| **HF3** | Matériaux, UV, textures originales (≤ 3 de 1024 px), peinture teintable par le jeu, vitrage transparent | **Faite**, à revoir (§3) |
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

## 3. Passe HF3 — matériaux, UV, textures, vitrage

Génération reproductible, sans interface (`hf3` comprend `hf1` et `hf2`) :

```
AW_ASTER_STAGE=hf3 blender --background vehicles/wk_aster/blend/wk_aster.blend --python tools/blender/aster02_blockout.py
```

Le générateur exécute alors `tools/blender/aster02_hf3.py`. Cette passe ne crée **aucune géométrie** : 101 744 triangles,
comme en HF2 (recompté). Dépôt d'art, commit `00c72de`.

### 3.1 Réalisé

- **17 familles de matériaux PBR** (Principled BSDF), une par famille comme le demande le pipeline : peinture, vitrage,
  glaces d'optiques, miroir, joint (plastique noir), calandre, jante (métal), décor (aluminium brossé), intérieur
  (plastique grainé), garniture, sièges (tissu), moquette, pneu, plaque, écran, feux avant, feux arrière.
- **Peinture teintable** : `AW_Peinture` n'a **aucune texture**. Sa couleur est un simple paramètre, pour que le jeu
  puisse imposer la couleur de MeshPart. Preuve dans Blender : trois rendus où seule la couleur de ce matériau
  change (rouge, bleu nuit, blanc).
- **Vitrage** : `AW_Vitrage`, transparence 0,55 (alpha 0,45), mélangé. Glaces d'optiques : transparence 0,70.
  Exigence : ≥ 0,3. Les rétroviseurs extérieurs, qui étaient en vitrage, passent dans un matériau miroir opaque.
- **Textures** : 3 atlas de 1024 px **calculés par le script**, graine fixe : bruits, trame de tissu, losanges de
  réflecteur. Aucune photographie, aucune inscription ; la plaque reste vierge, avec un simple liseré.
  - `AW_Aster_Couleur.png` ;
  - `AW_Aster_Normales.png` ;
  - `AW_Aster_ORM.png`, au format glTF : G rugosité, B métal.

  Deux générations successives donnent des fichiers identiques : mêmes empreintes SHA-256, consignées dans
  `textures/textures_manifest.json`.
- **UV** : les 161 objets ont des UV (projection automatique, ou à plat pour les plaques et les écrans). Chaque objet
  est posé dans la case de sa famille, sur une grille de 4 × 4 cases de 256 px avec une marge de 6 px. Les familles
  sans texture (peinture, verre, miroir, joint) sont posées dans une case neutre.

### 3.2 Contrôles (`aster02_checks.py`) : 22 sur 22

Les 15 contrôles précédents passent toujours, avec les mêmes valeurs qu'en HF2. Sept contrôles s'ajoutent :

| Contrôle | Résultat mesuré |
|---|---|
| UV présents | 161 objets sur 161 |
| UV dans la case de leur famille | 161 objets, marge 6 px |
| Textures | 3, de 1024 × 1024, empreintes conformes au manifeste |
| Peinture teintable | `AW_Peinture` sans texture ; pièces peintes : peinture et joint seulement |
| Vitrage | transparence 0,55 (vitrage) et 0,70 (optiques), rendu mélangé ; seuil 0,30 |
| Miroirs | rétroviseurs en `AW_Miroir`, opaque |
| Familles | 17, toutes nommées |

### 3.3 Densité de texture mesurée (et ce qu'elle impose)

Un seul atlas de 1024 px couvre environ 470 st² de surfaces texturées.

| Famille | Densité mesurée | Soit environ |
|---|---|---|
| Moquette | 21 px/st | 1,3 cm par pixel |
| Pneu | 23 px/st | 1,2 cm par pixel |
| Jante | 26 px/st | 1,1 cm par pixel |
| Sièges, garnitures | 27 px/st | 1 cm par pixel |
| Intérieur | 31 px/st | 0,9 cm par pixel |

Les plaques et les écrans montent à plus de 300 px/st.

Conséquence observée sur les premiers rendus : un grain plus fin qu'un pixel apparaissait en grosses bosses. Les
corrections ont été mesurées sur les rendus suivants :
- motifs ramenés à 1 ou 2 pixels ;
- contraste de couleur faible ;
- relief très atténué sur les grandes surfaces intérieures ;
- deux cases données aux garnitures, qui couvrent la plus grande surface texturée.

Le détail fin des surfaces intérieures reste donc limité par le budget de 3 textures.

### 3.4 Captures (`captures/aster02_hf3/`, rendus EEVEE)

Éclairage de lecture neutre (ciel uni, un soleil) : **ce n'est pas le rendu de Roblox**.
- `aster02_hf3_planche_revue.jpg` : 12 vues.
- Extérieur et vitrage :
  - `aster02_hf3_34_avant.jpg`, `_34_arriere.jpg`, `_profil.jpg` (habitacle visible à travers le vitrage) ;
  - `_vitre_laterale.jpg` ;
  - `_vue_cockpit.jpg` (pare-brise en place).
- Intérieur et roue : `_sieges.jpg`, `_planche.jpg`, `_detail_roue.jpg`.
- Teintes et textures :
  - `_teinte_rouge.jpg`, `_teinte_bleu_nuit.jpg`, `_teinte_blanc.jpg` ;
  - `_atlas.jpg` (les trois atlas).

### 3.5 Hypothèses à vérifier à l'import (HF5)

- **Teinte** : sans texture, la peinture devrait prendre la couleur de MeshPart. Non vérifié dans Roblox.
- **Panneaux peints à deux matériaux** : peinture, plus le rebord du joint. Le découpage par l'importateur n'est pas
  connu. Si un panneau devient une seule MeshPart, le rebord prendra la teinte. Remède prévu : rebord en pièce
  séparée, ou panneaux sans épaisseur (HF4).
- **Atlas ORM** : Roblox attend des cartes séparées de rugosité et de métal. La conversion par l'importateur n'est pas
  connue. Elle pourrait exiger une 4ᵉ texture ou un matériau Roblox pour les pièces métalliques : **écart à arbitrer**
  le cas échéant.
- **Émission des feux et de l'écran** : rendue dans Blender seulement. En jeu, l'éclairage passe par l'attribut
  `AWLight` prévu au contrat.

### 3.6 Limites restantes

- Pneus sans sculpture de bande de roulement.
- Bord de la baie au montant A en escalier, visible depuis la vue cockpit.
- Joint du bouclier arrière légèrement ondulé.

## 4. Non vérifié

- Import dans Studio, orientation (témoin v2), rendu Roblox, essais VM sur le modèle, performances D5.
