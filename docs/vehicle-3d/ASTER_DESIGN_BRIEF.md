# Aster (`wk_aster`) — dossier du véhicule pilote

Statut : **proposition**. Aucune géométrie définitive avant validation du propriétaire. Référence de direction
artistique choisie par le propriétaire : **Volkswagen Golf VIII** (inspiration, **pas** reproduction : nom, marque,
calandre, logo et signature lumineuse distinctive ne sont pas repris).

Légende : **[observé]** vu sur les références du manifeste `references/wk_aster/` (planche inspectée le 2026-11-04) ;
**[jeu]** valeur du code ou mesurée dans le moteur ; **[proposé]** décision artistique à valider.

## 1. Données du jeu (inchangées)

| Donnée | Valeur [jeu] |
|---|---|
| Catégorie | compacte, essence, automatique, traction, 95 kW, 1 280 kg |
| Dimensions | 4,25 × 1,78 × 1,47 m, empattement 2,62 m (`WorkingCatalog.luau`) |
| Silhouette provisoire | `Hatch` (`BodyKits`) |
| Habitacle provisoire | assise à 0,60 m du sol ; assise → pavillon **3,11 st (0,87 m)** ; largeur d'habitacle 5,66 st (1,58 m) (`tests/lune/tools/cabin-geometry.luau`) |
| Avatars R15 (AVATAR-01, `20261104-111326`) | tête sous le pavillon : M2 −0,17 st, référence −0,56 st, type de corps maximal −1,24 st (négatif = au-dessus du toit) ; avant-bras au-delà des flancs jusqu'à 0,37 st ; jambe/volant 0,24 st |

`Chassis.HeightM` ne sert qu'aux visuels et à la boîte de détection des chocs (`DamageService`) [jeu] : un pavillon
visuel plus haut ne change pas la dynamique, mais la boîte de choc devrait suivre la carrosserie réelle [décision].

## 2. Références (8 images, licences libres)

Manifeste : `references/wk_aster/manifest.json` ; sources détaillées : `SOURCES_IMAGES.md`. Couverture : trois quarts
avant ×2, profil, trois quarts arrière ×2, poste de conduite, sièges et console, détail du feu arrière. **Manquante** :
vue strictement de face ou de dos.

## 3. Fiche artistique (référence observée)

### Extérieur [observé]

- Compacte cinq portes : porte-à-faux avant court, capot court et assez plat, pavillon long, hayon presque vertical.
- Montant arrière épais et incliné vers l'avant, vitrage latéral qui remonte vers l'arrière.
- Ligne d'épaule nette, continue des phares aux feux arrière ; bas de caisse simple.
- Phares fins et horizontaux reliés par un bandeau à hauteur de capot (lumineux sur la version restylée) ; prise d'air
  basse large.
- Feux arrière horizontaux qui empiètent sur le hayon ; becquet de pavillon.
- Jantes de grand diamètre, motifs à branches fines (plusieurs dessins selon les versions).

### Intérieur [observé]

- Planche de bord basse et horizontale ; combiné numérique et écran central **flottants** dans un même bandeau.
- Aérateurs fins horizontaux ; petit sélecteur de boîte sur la console ; console centrale haute et sculptée.
- Volant à trois branches (méplat en bas sur la version sportive photographiée) ; sièges à joues latérales marquées.

### À retenir comme inspiration [proposé]

Proportions de compacte « sérieuse », hayon droit, ligne d'épaule continue, bandeau numérique horizontal.

### À transformer [proposé]

Bandeau lumineux continu avec logo central, forme du montant arrière, dessin de la calandre et des boucliers, dessin
des jantes et des feux arrière : remplacés par des dessins propres.

### À inventer [proposé]

Signature lumineuse d'Automotive World (commune à la gamme, décision D2), monogramme fictif, détails de surface,
garnissage, jantes, palette de couleurs.

## 4. Trois directions de design originales

| | A « Trait » | B « Galet » | C « Module » |
|---|---|---|---|
| Idée | compacte sobre et tendue, évolution « premium » | volumes arrondis, joufflus, très lisibles à distance | graphique et carrée, « utilitaire chic » |
| Silhouette | proche de la référence ; pavillon relevé de ~0,3 m, lunette plus droite | dôme de pavillon naturellement haut, passages de roues ronds et marqués | caisse verticale, grande surface vitrée, toit plat |
| Signature avant | deux traits lumineux en « L » aux angles, calandre fermée à motif de lignes | phares ronds-carrés dans des alvéoles, sourire de prise d'air | barre lumineuse **segmentée** horizontale (éviter les « pixels » carrés trop proches d'un autre constructeur) |
| Montant arrière | insert vitré qui « fait flotter » le pavillon | montant large et galbé, bicolore | montant vertical, vitre de custode carrée |
| Intérieur | bandeau horizontal, combiné sous casquette, console flottante | planche de bord arrondie, écran central rond-carré | rails modulaires, commandes physiques, rangements apparents |
| Habitacle R15 (D1) | pavillon +1,2 st pour la cible minimale : silhouette un peu haute, compensée par un vitrage fin | cible confort atteignable sans casser le style (dôme) | cible confort la plus simple (caisse verticale) |
| Lisibilité Roblox | bonne de près, moyenne de loin | **excellente** de loin | bonne |
| Risque de ressemblance | le plus élevé (proche de la référence) | faible | faible à moyen (vérifier les barres lumineuses existantes) |
| Complexité 3D | moyenne (surfaces tendues, reflets) | faible à moyenne | faible |

Recommandation initiale : B « Galet ». **Décision du propriétaire (2026-11-04) : direction A « Trait »** pour l'Aster.

Conséquences de ce choix [proposé] :

- **Dissemblance renforcée** (direction la plus proche de la référence) : revue de profil et de face superposés à la
  référence à chaque porte ; signature en « L » aux angles, calandre fermée à motif de lignes et montant arrière à
  insert vitré obligatoires ; aucun bandeau lumineux continu ni logo central.
- **Habitacle** (D1 tranchée : échelle Roblox + assise basse) : la cible minimale R15 (≥ 4,30 st) relève le pavillon d'environ 1,2 st par rapport à la
  carrosserie provisoire ; à compenser par un vitrage latéral fin, une ligne de caisse haute et, si D3 le permet, une
  assise abaissée de 0,3 à 0,5 st, pour garder une silhouette réaliste.
- **Surfaces tendues** : reflets à soigner (normales, matériaux), complexité 3D moyenne.
- Le langage commun de la gamme (signature lumineuse, monogramme) reste à valider (suite de D2).

## 5. Proposition d'habitacle (cotes cibles, studs du repère du véhicule)

| Élément | Cible [proposé] | Base |
|---|---|---|
| Assise → pavillon | ≥ 4,30 st (minimum), 5,00 st (confort) | spécification §3.3 (aujourd'hui 3,11 st) |
| Hauteur d'assise | abaissée de 0,3 à 0,5 st si la pose de conduite le permet (D3) | assise à 0,60 m aujourd'hui |
| Largeur intérieure | +0,7 st (0,35 st par côté) | dépassement des avant-bras 0,37 st |
| Volant | centré sur l'axe du siège conducteur, position finale fixée par l'essai de pose (D3) | mains à 2,3 st du volant aujourd'hui |
| Planche de bord | reculée de 0,3 st vers l'avant au droit des genoux | recouvrement jambe/volant 0,24 st |
| Caméra cockpit | à hauteur des yeux de la référence (centre de sa tête mesuré 0,77 st **au-dessus** du point de vue actuel de l'Aster), volant ≥ 10° sous la ligne de visée | AVATAR-01, QA-F15 |
| Sorties | `ExitLeft`/`ExitRight` à 1 st des portières, boîte libre 3 × 7,5 × 3 st | AVATAR-01 |
| Place passager | même gabarit que le conducteur | AVATAR-01 |

## 6. Structure du modèle Blender

Voir `PIPELINE_BLENDER_ROBLOX.md` §3 (collections EXT, INT, ROUES, COLLISION, ATTACHES, LOD). Pour l'Aster : 4 portières
séparées, hayon séparé, volant séparé, deux sièges avant + banquette arrière simplifiée (non occupée en jeu).

## 7. Intégration Roblox

Contrat de `SPECIFICATION_MODELES_3D.md` §2 : visuels soudés sans masse dans `Carrosserie`, collisions simples aux
mêmes noms, roues `Wheel<FL..RR>` animées localement, `AWLight` sur les feux, attaches de caméra et de sortie ;
carrosserie provisoire `Hatch` conservée comme repli tant que les actifs ne sont pas approuvés.

## 8. Budget de performance (à mesurer)

Point de départ [hypothèse] : LOD0 15 000 à 20 000 triangles (intérieur compris), LOD1 ≈ 40 %, LOD2 ≈ 10 % ; 3 textures
de 1024 px au plus. Critère : spécification §6 (24 Aster visibles, temps d'image ≤ référence + 2 ms sur la VM).

## 9. Procédure de validation

1. Étalonnage d'échelle (cube et roue témoins) consigné.
2. Maquette volumique aux cotes du §5 → session VM `avatar` (8 morphologies, deux places, sorties, cockpit).
3. Choix de la direction (A, B, C) par le propriétaire sur esquisses.
4. Modèle haute fidélité → Lune (structure, centres de roues, attributs) + VM `perf` + VM `lot08`.
5. Captures inspectées (3/4, profil, cockpit, nuit) ; essai humain ; revue de dissemblance avec la référence.
