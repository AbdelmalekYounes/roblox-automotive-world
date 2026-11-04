# ASTER-02 — modèle haute fidélité de l'Aster

Point de départ : blockout **validé par le propriétaire le 2026-11-04** (`ASTER_02_BLOCKOUT.md`). Branche du jeu
`feat/aster-02-blockout`, branche du dépôt d'art `aster-02-blockout`.

HF1 acceptée par le propriétaire (« Oui, HF2 », 2026-11-04) ; HF2 acceptée (« Oui, HF3 », 2026-11-04) ; HF3 acceptée (« Oui, HF4 », 2026-11-04).

Statut :
- aucun import dans Studio, aucune publication, aucune intégration au jeu, aucune fusion ;
- physique et carrosseries provisoires inchangées.

## Plan par passes (une revue par captures à la fin de chaque passe)

| Passe | Contenu | État |
|---|---|---|
| **HF1** | Extérieur : carrosserie plus fine, découpée en panneaux séparés suivant le contrat d'ASTER-02 §2 (capot, hayon, 4 portières, boucliers avant et arrière), joints visibles, poignées affleurantes, plaques fictives, rétroviseurs sur pied, optiques, pneus toriques, jantes à 5 branches, disques | **Faite**, à revoir (§1) |
| **HF2** | Intérieur : planche de bord sculptée, combiné, console, volant à branches, sièges galbés, contre-portes, ciel de toit, dans les budgets `ENVELOPPES` | **Faite**, acceptée (§2) |
| **HF3** | Matériaux, UV, textures originales (≤ 3 de 1024 px), peinture teintable par le jeu, vitrage transparent | **Faite**, acceptée (§3) |
| **HF4** | Niveaux de détail LOD1 et LOD2, boîtes de collision, réduction des triangles (§1.3), attaches | **Faite**, à revoir (§4) ; **un écart à arbitrer** (§4.6) |
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

## 4. Passe HF4 — allègement, pièces du contrat, attaches, collisions, LOD

Génération reproductible, sans interface (`hf4` comprend les passes précédentes) :

```
AW_ASTER_STAGE=hf4 blender --background vehicles/wk_aster/blend/wk_aster.blend --python tools/blender/aster02_blockout.py
```

Le générateur exécute `aster02_hf3.py`, puis `aster02_hf4.py`. Dépôt d'art, commit `4ff1a75`.

Nouvel outil du dépôt du jeu, en lecture seule : `tests/lune/tools/aster-provisional.luau`. Il relève, sur la
carrosserie provisoire de l'Aster, les 4 pièces de collision et les caméras `CameraHood` et `CameraBumper` selon la
règle de `VehicleFactory`. Exécution du 2026-11-04 :

```
lune run tests/lune/tools/aster-provisional.luau build/AutomotiveWorld.rbxlx <dépôt d'art>/vehicles/wk_aster/ref-sheets/wk_aster_provisoire.json
```

### 4.1 Allègement du LOD0 : 101 744 → 36 696 triangles

| Mesure | Effet |
|---|---|
| Caisse simplifiée **une fois, avant la découpe en panneaux** (les joints restent des plans droits communs) : mode « plan » à 3°, qui ne supprime que les arêtes entre faces presque coplanaires | Principal gain |
| Vitrages simplifiés à 45 %, pièces d'intérieur à 60 % | |
| Jantes simplifiées à 60 % ; pneu à 32 × 8 segments au lieu de 64 × 16 ; fût, moyeu et disque à segments réduits | |
| Pièces gardées intactes : jante du volant (la vue cockpit est mesurée sur elle), contre-portes (marges de 1 à 2 cm) | Aucun |

**Essais écartés.** Ce sont des générations antérieures du 2026-11-04, prises avec la même caméra ;
capture `aster02_hf4_essais_allegement.jpg`.

| Essai | LOD0 | Défaut observé |
|---|---|---|
| Effondrement d'arêtes, 8 % de la caisse | 29 060 | Taches d'ombrage sur les flancs |
| Mode plan à 5° | 29 656 | Portières en aplats de teinte différente |
| Mode plan à 5°, avec report des normales pleine résolution | 29 656 | Traînées sombres aux passages de roues |

Hauteur hors tout après allègement : **1,712 m** (HF3 : 1,721 m), dans la limite de 1,72 m.

### 4.2 Une pièce par rôle, pivots, instances

- **Sous-pièces fusionnées dans leur pièce du contrat**, ce qui fait **57 objets** au lieu de 161 :
  - nervures dans la caisse ;
  - poignées dans leur portière ;
  - pied du rétroviseur dans le rétroviseur ; le miroir reste séparé, pour que la peinture ne soit mêlée qu'au joint ;
  - lignes de calandre dans la calandre ;
  - aérateurs, bandeau, casquette et boîte à gants dans la planche de bord ;
  - branches et moyeu dans le volant ;
  - sous-pièces des sièges, de la banquette, des contre-portes et de la console ;
  - pédales dans le pédalier ; tapis et pare-soleil regroupés.
- **Feux** : `ASTER_Feu_AvG/AvD` portent `AWLight = Head`, `ASTER_Feu_ArG/ArD` portent `AWLight = Tail` (propriété exportée en
  « extras » glTF). Les glaces sont en pièces `ASTER_Glace_*`.
- **Pivots** :
  - portières sur leur bord avant, côté extérieur ;
  - capot sur son bord arrière ;
  - hayon sur son bord haut ;
  - volant au centre de la jante (−1,40 ; 1,52 ; 1,10), axe local le long de la colonne.
- **Roues** : `ASTER_Pneu_*` et `ASTER_Jante_*` (avec fût, branches, moyeu et disque) sont **4 instances d'un même
  maillage**, avec le pivot au moyeu. Côté droit : même maillage tourné d'un demi-tour, sans miroir. Il en va de même au
  LOD1 et au LOD2.

### 4.3 Attaches

| Attache | Position (repère du jeu) | Origine |
|---|---|---|
| `CameraCockpit`, `SeatDriver`, `SeatPassenger`, `ExitLeft`, `ExitRight` | inchangées | scène du pipeline |
| `CameraHood` | (0 ; 2,36 ; −4,25), 0,82 st au-dessus du capot | **Adaptée**, voir ci-dessous |
| `CameraBumper` | (0 ; 0,36 ; −8,24), 0,60 st devant la caisse | Position actuelle de la carrosserie provisoire, reprise telle quelle (l'avant de la caisse est au même z) |

Pourquoi `CameraHood` est adaptée :
- la règle de la fabrique (0,45 m devant l'essieu avant, 0,8 st au-dessus du capot) donne z −2,14 ;
- sur l'Aster 3D, ce point tombe **sur le pare-brise**, dont le pied est à z −3,95 ;
- même intention appliquée au modèle : 0,8 st au-dessus du capot, 0,30 st devant le pied de pare-brise.

Le dossier de lancement demandait de placer cette attache « sur le modèle (capot) ».

### 4.4 Collisions

Quatre boîtes `COL_*` dans la collection `COLLISION`, non rendues, aux noms des zones actuelles :
- les niveaux en hauteur sont repris de la carrosserie provisoire (relevé Lune) ;
- les boîtes sont ajustées à la caisse visible, avec un dépassement admis de 0,25 st.

Avec une tolérance de 0,10 st (premier essai), la caisse arrondie ne laissait que des boucliers à 1,2 st en retrait du
nez. Maximiser le seul volume les repoussait aussi : les boucliers cherchent donc d'abord à atteindre l'extrémité
(largeur ≥ 85 % de la provisoire).

| Boîte | Modèle 3D (taille ; centre, st) | Provisoire | Dépassement mesuré |
|---|---|---|---|
| `COL_BouclierAvant` | 5,15 × 1,27 × 0,70 ; (0 ; −0,18 ; −7,16) | 6,06 × 1,67 × 0,70 ; (0 ; −0,38 ; −7,24) | 0,10 |
| `COL_BouclierArriere` | 5,21 × 1,27 × 0,70 ; (0 ; −0,18 ; +7,14) | 6,06 × 1,67 × 0,70 ; (0 ; −0,38 ; +7,24) | 0,11 |
| `COL_Coque` | 5,88 × 0,94 × 13,80 ; (0 ; 0,43 ; −0,01) | 6,16 × 1,26 × 13,98 ; (0 ; 0,59 ; 0) | 0,18 |
| `COL_Habitacle` | 4,44 × 3,17 × 6,72 ; (0 ; 2,48 ; 1,69) | 5,66 × 2,25 × 6,07 ; (0 ; 2,34 ; 1,82) | 0,12 |

Comment le dépassement est mesuré :
- grille de points sur chaque face, hors passages de roues ;
- un point est dehors si un rayon tiré selon la normale de la face s'échappe sans toucher la caisse ni le vitrage.

**Carrosserie visible non couverte** (dans l'axe, relevé `ref-sheets/wk_aster_collisions.json`) :
- jusqu'à **0,72 st** au-dessus du capot, entre le nez et le pied de pare-brise ;
- jusqu'à **3,4 st** sous le pare-brise incliné, en avant de la boîte d'habitacle ;
- jusqu'à **3,3 st** au hayon.

La carrosserie provisoire a la même lacune : son pare-brise et sa lunette en biseau ne sont pas collisionnables.
Une boîte de plus ou une forme biaisée sortirait du contrat (« boîtes simples, mêmes noms ») : c'est une **proposition**
pour l'intégration, non réalisée.

### 4.5 Niveaux de détail

| Niveau | Contenu | Triangles | Objets |
|---|---|---|---|
| LOD0 | modèle complet | 36 696 | 57 |
| LOD1 | carrosserie, détails, vitrage et intérieur fusionnés par groupe et simplifiés (35 %, 35 %, 50 %, 25 %) ; roues à 40 % | 12 978 (35 %) | 12 |
| LOD2 | carrosserie et détails fusionnés et simplifiés ; vitrage **opaque** (`AW_VitrageOpaque`) ; sans intérieur ni glaces d'optiques ; roues à 15 % | 3 544 (9,7 %) | 10 |

Fusion par groupe de matériaux : la peinture n'est jamais mêlée aux feux, au vitrage ou aux détails, au cas où
l'importateur garderait une seule MeshPart par maillage (hypothèse HF3).

Défauts corrigés pendant la passe :
- LOD2 à 1 100 triangles de caisse (déchirures) : passé à 2 200 ;
- glaces d'optiques opaques au LOD2 (signature lumineuse masquée) : retirées ;
- UV poussés dans la marge par la simplification : ramenés dans leur case.

La bascule entre niveaux (`RenderFidelity` ou dossier `Details` avec `DetailLod`) reste à décider à l'intégration.

### 4.6 Écart à arbitrer : LOD0 au-dessus de l'hypothèse de départ

La spécification (§6) donne comme **hypothèse** de départ un LOD0 de 15 000 à 25 000 triangles. Le critère
d'acceptation est D5 (temps d'image ≤ référence + 2 ms avec 24 Aster sur la VM), non mesuré à ce stade.

Le LOD0 retenu compte **36 696** triangles. Les essais à environ 29 000 dégradaient déjà visiblement la caisse (§4.1).
Décision du propriétaire :
- **(a)** garder 36 696 et laisser D5 trancher en HF5 ;
- **(b)** viser 25 000 au prix de la qualité de surface ;
- **(c)** retirer l'épaisseur des panneaux. La caisse perdrait près de la moitié de ses triangles, mais il faudrait
  que l'option « double face » des MeshPart fonctionne à l'import, ce qui n'est pas vérifié.

### 4.7 Contrôles (`aster02_checks.py`) : 33 sur 33, plus 3 relevés informatifs

Les 22 contrôles précédents passent toujours, avec trois écarts par rapport à HF3, tous dans les budgets :
- hauteur 1,712 m ;
- face arrière de la planche de bord à z 0,467 : elle comprend désormais casquette et aérateurs ;
- tête la plus proche : 0,87 st, sur le siège passager.

Contrôles ajoutés :

| Contrôle | Résultat mesuré |
|---|---|
| LOD1 ≤ 50 % du LOD0 | 35 % |
| LOD2 ≤ 10 % du LOD0 | 9,7 % |
| Silhouette des LOD (encombrement) | écart max 0,005 st (LOD1), 0,026 st (LOD2) ; seuil 0,10 |
| LOD2 | aucun matériau transparent, aucun matériau d'intérieur |
| Roues | 3 niveaux × pneu et jante : 4 instances d'un même maillage, pivots aux moyeux (±0,01 st) |
| Pivots | volant, 4 portières, capot, hayon |
| Attaches | 7 ; `CameraHood` 0,82 st au-dessus du capot ; `CameraBumper` 0,60 st devant la caisse |
| Feux | 4 pièces, `AWLight` conforme |
| Collisions | 4 noms ; dépassement ≤ 0,18 st (seuil 0,30) ; toutes au-dessus du sol |
| Peinture | pièces contenant la peinture : peinture et joint seulement, LOD compris |
| UV | chaque face dans la case de la famille de son matériau, LOD compris |

Relevés informatifs : triangles du LOD0, nombre d'objets, comparaison des collisions avec la carrosserie provisoire.

Les seuils de LOD (50 %, 10 %, 0,10 st) et de collision (0,25 st) sont **retenus pour cette passe** : ils ne viennent
pas du cahier des charges.

### 4.8 Captures (`captures/aster02_hf4/`, rendus EEVEE, éclairage de lecture)

- `aster02_hf4_planche_revue.jpg` : 9 vues ;
- `aster02_hf4_essais_allegement.jpg` : essais écartés et variante retenue.
- Vues séparées :
  - `_lod0_34_avant.jpg`, `_lod1_34_avant.jpg`, `_lod2_34_avant.jpg` (même caméra) ;
  - `_collisions_34_avant.jpg`, `_collisions_profil.jpg` ;
  - `_34_arriere.jpg`, `_detail_roue.jpg` ;
  - `_vue_cockpit.jpg`, `_vue_hood.jpg`, `_vue_bumper.jpg` (champ vertical de 70°, sans route dans la scène).

### 4.9 Non vérifié et limites

- Import, découpage par matériau, `AWLight` en « extras », bascule des LOD, D5 : passe HF5.
- Bords de baies en escalier, visibles depuis la vue cockpit : inchangés.
- Vitrages du LOD2 légèrement déchirés aux angles : vus de loin.

## 5. Non vérifié

- Import dans Studio, orientation (témoin v2), rendu Roblox, essais VM sur le modèle, performances D5.
