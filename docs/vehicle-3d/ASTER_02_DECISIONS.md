# ASTER-02 — recommandations sur les décisions restantes

Statut : **décidé par le propriétaire le 2026-11-04**, recommandations retenues sur les quatre points. Décisions appliquées et mesurées (tâche VM `20261104-193715`, commit `9f1c4b7`) : voir « Décisions et vérification » en fin de document. Version d'origine des recommandations ci-dessous. Données :
session VM `aster`, tâche `20261104-181108` (commit `6627a1f`), gabarit final (plancher −1,30 st). Il y a
10 morphologies : H1 à H7 sur le corps masculin 995, F1, F2 et F4 sur le corps féminin 994, avec les têtes remplacées
selon la règle des têtes classiques. Les valeurs sont en studs (1 st = 0,28 m), au-dessus du dessus de l'assise
sauf mention. QA-A15 (sortie du passager) reste en attente et n'est pas traitée ici.

## Mesures par morphologie (place conducteur, pose du jeu)

| Morph. | Taille / largeur | Yeux − haut du volant | Mains–jante | Cheveux | Marge cheveux–pavillon | Marge latérale cond. / pass. | Pieds–plancher |
|---|---|---|---|---|---|---|---|
| H1 | 1,05 / 1 | +0,47 | 0,15 | 3,22 | 1,38 | 0,48 / 0,33 | 0,12 |
| H2 | 0,90 / 0,70 | +0,08 | 0,29 | 2,79 | 1,81 | 0,78 / 0,67 | 0,24 |
| H3 | 1,00 / 0,85 | +0,22 | 0,24 | 2,96 | 1,64 | 0,68 / 0,56 | 0,21 |
| H4 | 1,05 / 0,70 | +0,14 | 0,34 | 2,89 | 1,71 | 0,86 / 0,75 | 0,23 |
| **H5** | 0,90 / 1 | **−0,03** | 0,30 | 2,71 | 1,89 | 0,61 / 0,48 | 0,34 |
| H6 (chapeau d'essai) | 1,05 / 1 | +0,47 | 0,15 | 4,43 | 0,17 | 0,48 / 0,33 | 0,12 |
| H7 (accessoires) | 1,00 / 0,85 | +0,22 | 0,24 | 2,96 | 1,64 | 0,68 / 0,56 | 0,21 |
| F1 | 1,05 / 1 | +0,58 | 0,34 | **3,39** | 1,21 | 0,41 / **0,21** | **0,07** |
| F2 | 0,90 / 0,70 | +0,17 | 0,20 | 2,94 | 1,66 | 0,74 / 0,58 | 0,19 |
| F4 | 1,05 / 0,70 | +0,20 | 0,29 | 3,01 | 1,59 | 0,82 / 0,67 | 0,18 |

Yeux estimés au centre de la tête + 0,15 st. Pose standard (sans `AWSeatPose`) : cheveux jusqu'à 3,76 (F1), chapeau
d'essai 4,87.

## 1. Pose de conduite adaptée à la taille (H5)

**Fait établi** : en vue cockpit, le joueur ne voit pas par les yeux de son avatar. La caméra est un point fixe du
véhicule (`CameraCockpit`), calculé par la règle du jeu (`CockpitGeometry.eyeY`) : le haut du volant passe 10° sous
la ligne de visée, et l'avatar est masqué. Vérifié avec le module du jeu pour l'Aster : point (−1,40 ; 2,24 ; 2,07),
volant à 10,00°. Le −0,03 st de H5 n'a donc **aucun effet sur la vue de conduite**. Il ne se voit que de l'extérieur :
les yeux d'un petit avatar arrivent à hauteur du haut du volant, comme pour une personne de petite taille.

| Option | Effet | Coût | Risque |
|---|---|---|---|
| **A. Accepter, pose actuelle (recommandé)** | Aucun changement ; vue cockpit correcte pour tous | Nul | Aucun mesuré |
| B. Bassin relevé selon la taille (client, ≤ 0,3 st) | Yeux de H5 au-dessus du volant ; mains relevées d'environ 0,13 st (estimation) | Petit (`SeatPose`), nouvelle mesure VM | Mains–jante à revérifier (H5 : 0,30, seuil 0,35) |
| C. Bras orientés vers la jante selon la taille (cinématique inverse) | Mains toujours sur la jante | Moyen (calcul par articulation, tests) | Postures anormales sur les échelles extrêmes |

**Recommandation : A.** Le critère « vue au-dessus du volant » de la session VM `aster` devient informatif : il
mesure la vue de l'avatar, pas celle du joueur. Le critère de la vue de conduite est l'angle de 10° de
`CockpitGeometry`, vérifié pour l'Aster. B ou C restent possibles plus tard, si l'aspect extérieur le demande.

**Correction apportée au dossier** : `CameraCockpit` passe de (−1,40 ; 2,14 ; 2,96) à (−1,40 ; 2,24 ; 2,07), selon la
règle du jeu. L'ancien point, au centre de la tête mesurée, ne laissait que 2,16° sous la ligne de visée : le volant
aurait masqué la route (défaut QA-F15 du lot 0.9.1). La scène Blender est corrigée.

## 2. Hauteur définitive du toit

Les sièges de l'Aster portent `AWSeatPose` (exigence d'ASTER-02) : la **pose du jeu** est la référence. Le point de
vue cockpit doit rester 0,6 st sous le pavillon (`CockpitGeometry.RoofClearance`) : 2,24 + 0,6 = 2,84 au-dessus du
châssis, sans contrainte pour les valeurs ci-dessous.

| Dessous du pavillon (au-dessus de l'assise) | Hors tout | Marge cheveux, pose du jeu | Chapeau d'essai (pose du jeu) | Pose standard (cheveux) |
|---|---|---|---|---|
| 4,60 (gabarit actuel) | 1,83 m | 1,21 | +0,17 | +0,84 |
| **4,20 (recommandé)** | 1,72 m | **0,81** | −0,23 (traverse) | +0,44 |
| 4,00 | 1,66 m | 0,61 | −0,43 | +0,24 |

Repères : définition physique 1,47 m (inchangée) ; référence réelle Golf VIII ≈ 1,49 m. L'écart vient de l'échelle
Roblox (D1).

**Recommandation : 4,20 st.** La marge reste confortable sur les cheveux réalistes, et un seul paramètre change
(`HeadroomSt`). La silhouette s'abaisse de 0,11 m. Les chapeaux très hauts traversent le pavillon ; c'est le cas de
la plupart des jeux Roblox, et la proposition est d'accepter.

Si vous retenez 4,20 :
- réexport du gabarit ;
- nouvelle mesure VM `aster` ;
- mise à jour des esquisses.

## 3. Couleurs du personnage

Constat (captures `captures/aster_phase1_tetes_couleurs.jpg`, tâche `20261104-181108`) : les couleurs Roblox du
joueur sont appliquées par partie. Sur le corps réaliste, des couleurs différentes créent des ruptures nettes au cou,
aux épaules et aux hanches. Le compte de test a des jambes bleues et des bras gris.

| Option | Effet | Coût |
|---|---|---|
| A. Conserver (état actuel) | Choix du joueur respecté ; ruptures visibles ; teintes non humaines possibles | Nul |
| **B. Unifier sur la couleur de la tête (recommandé)** | Une seule teinte de peau, celle que le joueur a choisie pour le visage ; plus de rupture | Petit : une règle dans `AvatarPolicy`, à l'apparition et au changement de silhouette ; tests Lune et VM |
| C. Nuancier de teintes humaines dans le panneau de silhouette | Teintes réalistes au choix | Moyen : interface, textes FR/EN, essais par vrais clics |

**Recommandation : B maintenant, C éventuellement plus tard.** B ne restreint pas le choix du joueur : un visage bleu
donne un corps bleu. Il supprime seulement les ruptures dues au mélange des parties. Rien n'est modifié sans votre
décision.

## 4. Marges de l'habitacle (contraintes de modélisation)

Les volumes intérieurs du modèle 3D ne doivent pas réduire les marges mesurées en dessous des seuils proposés
ci-dessous. Garnitures, moquette et ciel de toit sont comptés dans le budget indiqué.

| Zone | Marge mesurée (min.) | Seuil proposé | Budget pour le modèle |
|---|---|---|---|
| Ciel de toit | 1,21 (F1, cheveux) avec 4,60 ; 0,81 avec 4,20 | ≥ 0,30 | Épaisseur ≤ 0,50 st (4,20) |
| Garnitures de portière (place passager) | 0,21 (F1) | ≥ 0,10 | Saillie ≤ 0,10 st vers l'intérieur depuis x ±2,93 |
| Garnitures de portière (place conducteur) | 0,41 (F1) | ≥ 0,10 | ≤ 0,30 st |
| Plancher, moquette | 0,07 (F1) | ≥ 0,03 | Moquette ≤ 0,04 st, ou creux de pieds plus bas |
| Planche de bord / jambes | 0 chevauchement | 0 | Bas de planche ≥ y 0,86 ; face arrière ≤ z 0,50 |
| Volant | mains–jante 0,15 à 0,34 | ≤ 0,35 | Jante à la cote du gabarit (±0,05) |
| Pédalier | pointes de pied jusqu'à z −1,21 | ≥ 0,04 | Face des pédales ≤ z −1,25 |
| Dessus de l'assise | y −0,04 (`Seat`) | exact | Coussin visible au niveau de la pièce `Seat` (±0,05) |

**D7 (largeur)** : avec les deux corps retenus, toutes les marges latérales sont positives (≥ 0,21 st). La décision
D7 est **sans objet**, à confirmer.

**Recommandation** : inscrire ces budgets comme volumes d'encombrement (fil de fer) dans la scène Blender, dans une
collection `ENVELOPPES`, et ajouter à la session VM du modèle réel les contrôles « garnitures » et « moquette ».

## Décisions et vérification (2026-11-04)

| Point | Décision du propriétaire | Appliqué | Vérifié |
|---|---|---|---|
| Pose (H5) | « Accepter » | Contrôle VM « yeux de l'avatar au-dessus du volant » rendu informatif ; vue de conduite contrôlée par la règle `CockpitGeometry` (Lune) | Lune : `CameraCockpit` (−1,40 ; 2,24 ; 2,07), haut du volant à 10° sous la visée, ≥ 0,6 st sous le pavillon |
| Toit | « 4,20 st — 1,72 m » | Gabarit `HeadroomSt = 4,20` ; dépôt d'art `00e9ade` | VM `20261104-193715`, pose du jeu : marge corps ≥ 1,02, marge cheveux ≥ 0,81 (hors chapeau d'essai : −0,23, accepté), marge latérale ≥ 0,21, pieds ≥ 0,07 ; tous les contrôles de la pose du jeu réussis |
| Couleurs | « Unifier sur la tête » | `AvatarPolicy.UnifySkinOnHead` : tronc, bras et jambes prennent la couleur de la tête, à chaque application du corps | VM `20261104-193715` : couleurs de départ différentes unifiées sur les deux silhouettes ; capture `captures/aster_02_couleurs_unifiees.jpg` |
| Marges, D7 | « Valider budgets + D7 » | Budgets du §4 ; collection `ENVELOPPES` (7 plans) dans `wk_aster.blend` ; D7 sans objet | Scène relue par Blender sans interface (collections, repères, pavillon à 4,16) |

Échecs restants de la tâche `20261104-193715` : pieds sous le plancher en **pose standard** (siège sans `AWSeatPose`), sans
objet pour l'Aster, dont les sièges portent l'attribut (exigence d'ASTER-02).

## 4 bis. Changement de direction : reproduction de la référence (2026-11-04)

Décision du propriétaire, écart au cahier des charges **arbitré par lui** (CLAUDE.md : seul le propriétaire accorde une
exception).

Il a écrit : « on ne prend pas en compte ce que dit le CDC sur la reproduction des véhicules ; on va essayer de
reproduire le véhicule sans le logo Volkswagen ». Réponses aux deux questions posées :
- **hauteur : proportions réelles**, environ 1,46 m ; la hauteur de la définition du jeu est 1,47 m ;
- **face avant et détails : tout reproduire**, c'est-à-dire bandeau lumineux, phares, calandre, boucliers, feux et
  jantes, sans le logo.

| Point | Conséquence |
|---|---|
| Direction A « Trait », signature Mivale « L » | Remplacées pour l'Aster ; le blockout validé et les passes HF1 à HF4 restent dans l'historique (dépôt d'art `4ff1a75`) |
| Interdits maintenus | Aucun logo, aucun nom « Volkswagen » ni « Golf » dans le jeu, les fichiers du modèle ou les textures ; aucune photographie utilisée comme texture ; plaques fictives. Les photos du manifeste servent de référence de modelage seulement |
| Risque signalé au propriétaire | La forme d'un véhicule récent peut être protégée (dessin ou modèle, image de marque), même sans logo ; un ayant droit peut faire retirer un contenu publié sur Roblox. Ce risque porte sur la publication, que seul le propriétaire décide (aucune publication sans son accord) |
| Toit (décision du §2 remplacée) | Hors tout ramené à la hauteur de la définition, 1,47 m, soit le dessus du pavillon à y 3,46. Il reste environ 3,3 st entre l'assise et le dessous du pavillon, au lieu de 4,20 : **les marges de tête mesurées en VM (§2) ne tiennent plus**. Assise, pose et contrôles VM sont à reprendre ; aucune solution n'est choisie à ce stade |
| Physique | Inchangée : la définition (4,25 × 1,78 × 1,47 m, empattement 2,62 m) est déjà proche des cotes réelles de la référence |

## 5. Rappel des autres points ouverts

- Corps par défaut avant le choix du joueur : masculin, provisoire (à confirmer).
- Étalonnage Blender → Studio : à relever par le propriétaire (`calibration/README.md` du dépôt d'art).
- QA-A15 : en attente.
