# Rapport du lot AVATAR-01 — R15 normal, compatibilité automobile, fondation des tenues

Branche `feat/avatar-r15-foundation`, créée depuis `82fd279` (tête de la PR #11, lot 0.9.2, vérifiée le
2026-11-04 avant le travail), dans un worktree indépendant ; PR brouillon
[#12](https://github.com/AbdelmalekYounes/roblox-automotive-world/pull/12) vers `feat/final-stabilization-0.9.2`.
`main` intacte ; rien n'est fusionné. Aucune publication Roblox, aucun DataStore, aucun actif Roblox, aucune boutique.
Essais Studio dans la VM uniquement.

**Écart de méthode signalé** : `CLAUDE.md` demande qu'un lot soit clôturé (PR fusionnée) avant le suivant ; la PR #11
n'est pas fusionnée. Le lot part de sa tête **sur instruction explicite du propriétaire** (brief AVATAR-01), comme les
lots précédents.

## 1. Audit du système existant (lecture du code, `82fd279`)

| Élément | Constat | Conséquence pour R15 personnalisé |
|---|---|---|
| Réglages d'avatar | Aucun réglage dans les projets Rojo : `StarterPlayer` sans propriété ; type d'avatar laissé au défaut de l'expérience | Corrigé (§2) |
| Apparitions | Personnages chargés par le moteur (`CharacterAutoLoads`) ; `ProgressionService` appelle `LoadCharacter` en sortie d'intérieur ; aucune `HumanoidDescription` imposée | Apparence du joueur conservée |
| Sièges | `Seat` (pas `VehicleSeat`) conducteur et passager, 1,8 × 0,4 × 1,8 st, `CanCollide`/`CanTouch` faux, position par carrosserie (`BodyKits.SeatOffset`) ; embarquement par le serveur (`Seat:Sit`) | Assise et pose : animation `sit` du moteur, fonction de la taille de l'avatar (mesurée §4) |
| Animations d'embarquement | Aucune : le moteur pose le personnage sur le siège | Rien à adapter |
| Mains | Aucune animation de conduite (pas d'IK) : les mains suivent la pose assise standard | Mains loin du volant (mesuré §4) |
| Caméra cockpit | Point de vue fixe par modèle (`CockpitGeometry.EyeAboveSeat` = 2,45 st au-dessus de l'assise, relevé au-dessus du volant) ; personnage rendu invisible **localement** en cockpit (`LocalTransparencyModifier` sur toutes les pièces et décalques, accessoires compris) | Indépendant de la taille ; hypothèse d'un avatar « moyen » (§4) |
| Sortie | `findExitPivot` : boîte libre fixe 2,5 × 5 × 2,5 st, hauteur du véhicule + 1,5 st, côté conducteur puis passager puis au-dessus ; passager : saut du moteur (aucun placement) | Hypothèse d'une taille de 5 st (mesuré §4) |
| Téléphone | Modèle soudé à `RightHand`, décalage fixe (0 ; −0,15 ; −0,25 st) ; bras : Motor6D (R6, R15 classique) ou attribut `AWPhoneRaised` appliqué par chaque client sur `Transform` (QA-A10, lot 0.9.2) | Décalage indépendant de la taille de main (mesuré §4) ; **correction QA-A10 conservée**, aucun élément ne prouve d'incompatibilité |
| Articulations | Code compatible Motor6D et nouveau squelette (`AnimationConstraint`) ; `StarterPlayer.AvatarJointUpgrade` laissé au défaut | Rien à changer sans preuve |
| Masse | Pièces du personnage assis **non** rendues sans masse : elles s'ajoutent à `AssemblyMass` du véhicule ; le simulateur rapporte ses forces à cette masse totale (`VehicleSimulator`, `forceScale`) | Accélération inchangée ; centre de gravité et inertie modifiés selon l'avatar (mesuré §4, **non corrigé** : physique hors périmètre) |
| Dimensions supposées | 2,45 st (yeux), 5 st (sortie), +1,5 st (hauteur de dépose), siège 1,8 st ; aucune autre hypothèse trouvée | Vérifiées par les essais §4 |

## 2. Configuration R15 proposée et appliquée

| Réglage | Valeur | Où | État |
|---|---|---|---|
| Type d'avatar | **R15** (`StarterPlayer.GameSettingsAvatar`) | `default.project.json`, `openworld.project.json` | **Appliqué** (place construite : jeton 1 = R15 ; test Lune) |
| Apparence du joueur | chargée (`LoadCharacterAppearance = true`) | idem | **Appliqué** |
| Animations personnalisées du joueur | autorisées (`AllowCustomAnimations = true`) | idem | **Appliqué** |
| Échelles | **choix du joueur** (plages par défaut de Roblox : hauteur 0,90-1,05, largeur 0,70-1,00, tête 0,95-1,00, type de corps et proportions 0-1) | `Shared.Avatar.AvatarPolicy` | Aucune limitation (`LimitedByTests = false`) : voir §4 |
| Articulations | défaut de Roblox (`AvatarJointUpgrade`) | — | Inchangé |
| Contrôle au serveur | personnage non R15 **signalé** (journal, attribut `AWAvatarRig`), jamais converti | `AvatarService` | **Appliqué** |
| Réglages d'avatar de l'expérience publiée (fenêtre « Avatar Settings » de Studio : corps, vêtements, accessoires, collisions) | à régler à la publication : R15, « Player Choice » partout | Expérience Roblox | **Action du propriétaire** : ces réglages ne sont pas accessibles par script et l'expérience n'est pas publiée (aucune publication sans accord) |

Une conversion silencieuse d'un personnage R6 en R15 a été écartée : un personnage reconstruit par script perd les
scripts d'animation fournis par le moteur.

## 3. Fondation des tenues (indépendante des cosmétiques automobiles)

```
Shared/Cosmetics/OutfitCatalog   emplacements (3 classiques, 9 superposés, 8 rigides), 5 catégories, tenues
Shared/Cosmetics/OutfitRules     règles pures : identifiants, validation, essayage, retrait, restauration
Server/Avatar/AvatarService      R15, apparence initiale, application (ApplyDescriptionAsync), canal AWAvatar.Request
Shared/UI/Localization           textes FR/EN (catégories, emplacements, refus)
```

- **Emplacements** : Shirt / Pants / T-shirt classiques (champs de `HumanoidDescription`) ; vêtements superposés
  (chaussures, pantalon, short, robe ou jupe, T-shirt, chemise, pull, veste) avec un **ordre de superposition proposé**
  (à confirmer avec les fichiers artistiques) ; accessoires rigides (couvre-chef, cheveux, visage, cou, épaules,
  devant, dos, taille).
- **Essayage** (30 s puis retour automatique), **équipement** (réappliqué après une réapparition), **retrait** d'un
  emplacement (il reprend ce que portait le joueur), **restauration** de l'apparence initiale (lue au chargement de
  chaque personnage). Le corps, le visage, les couleurs et les échelles du joueur ne sont jamais modifiés.
- **Identifiants invalides** : mal formés (0, négatif, fractionnaire, NaN, infini, texte) refusés avant le moteur ;
  bien formés mais refusés par le moteur → apparence précédente rétablie, refus « OutfitAssetInvalid ».
- **Autorité** : le client ne désigne qu'une **tenue du catalogue** ; un identifiant d'actif envoyé par un client est
  ignoré. Demandes limitées (4, puis 1 par seconde). Changement refusé assis dans un véhicule.
- **Collection future** : cinq catégories (pilote circuit premium, pilote street racing, mécanicien, assistance
  routière, chauffeur VTC), une tenue-**emplacement** chacune (statut « Placeholder », aucun identifiant). **Aucune
  ressource produite, aucun identifiant inventé, aucune boutique ni monétisation** ; production graphique non engagée.
- **Non fait** (hors périmètre) : interface d'essayage (la direction artistique est traitée à part), persistance des
  tenues (aucune sauvegarde dans ce lot).

## 4. Essais dans le moteur (VM)

| Tâche | Code | Sessions | Résultat | Remarque |
|---|---|---|---|---|
| `20261104-104818` (2026-11-04 10:48–11:06) | `dccf857` | `avatar`, `avatar2` | 7 / 1 lus par le rapport | **Défauts du test** : ligne de résultat de `avatar` > 100 000 caractères, tronquée par Studio (444 contrôles et les 300 relevés `@@AWAVATAR@@` récupérés à la main) ; vues extérieures au volant écrasées par la caméra du véhicule ; critère de plancher mal défini ; repère « Toit » de 0,1 st du roadster compté comme pavillon ; marche et téléphone mesurés avant la fin de la reconstruction du personnage (M2, M4) ; position du téléphone mal lue dans `avatar2` |
| `20261104-111326` (2026-11-04 11:13–11:47) | `f05a22a` | `avatar`, `avatar2` | **235 réussis, 165 échecs**, 2 sessions | Résultats ci-dessous ; 84 captures |

Instrumenté (signalé) : morphologies appliquées par le serveur de test (échelles de la `HumanoidDescription` du compte de
test) ; accessoires d'essai = pièces simples créées par le test (aucun actif) ; véhicules temporaires protégés ;
personnage assis par `Seat:Sit` (comme l'invite). Vraies entrées dans la VM : marche (W), téléphone (T), vue cockpit
(V), sortie conducteur (F), sortie passager (Espace).

### 4.1 Compte de test et réglage

- Squelette **R15**, nouveau système d'articulations : **15 `AnimationConstraint`, 0 Motor6D** ; `AWAvatarRig` = R15 ;
  0 personnage non R15 ; R15 aussi après réapparition.
- Apparence réelle du compte : **vêtements classiques** (Shirt et Pants), 1 accessoire (cheveux), **aucun vêtement 3D
  superposé**. `GameSettingsAvatar` n'est pas lisible par script (contrôlé dans la place construite, test Lune).

### 4.2 Morphologies testées (tâche `20261104-111326`, pose stabilisée)

| Id | Morphologie | Échelles lues (hauteur ; largeur ; profondeur ; tête ; type de corps ; proportions) | Corps (st) | Hors tout (st) | HipHeight |
|---|---|---|---|---|---|
| M1 | référence | 1 ; 1 ; 1 ; 1 ; 0 ; 0 | 5,09 | 5,42 | 2,00 |
| M2 | petit et mince | 0,90 ; 0,70 ; 0,70 ; 0,95 ; 0 ; 0 | 4,65 | 4,97 | 1,80 |
| M3 | grand classique | 1,05 ; 1 ; 1 ; 1 ; 0 ; 0 | 5,30 | 5,63 | 2,10 |
| M4 | grand, type de corps maximal | 1,05 ; 1 ; 1 ; 1 ; 1 ; 0 | 6,78 | 7,09 | 3,04 |
| M5 | grand élancé | 1,05 ; 0,70 ; 0,70 ; 1 ; 1 ; 1 | 6,19 | 6,50 | 2,75 |
| M6 | petit et large | 0,90 ; 1 ; 1 ; 1 ; 0 ; 0 | 4,71 | 5,04 | 1,80 |
| M7 | M4 + chapeau haut d'essai (2,6 st) | comme M4 | 6,78 | 9,19 | 3,04 |
| M8 | référence + accessoires d'essai volumineux (dos 3,4 × 2,4 st, épaulettes, ceinture) | comme M1 | 5,11 | 5,43 | 2,00 |

Debout (8 / 8 morphologies) : **marche** par la vraie touche W (24 à 25 st en 1,5 s, animations `WalkAnim`/`RunAnim`) ;
**téléphone** par la vraie touche T : bras levé de 43° à 48° (54-55° du tronc), téléphone à 0,29 st de la main, devant le
personnage (`captures/001_debout_M1_telephone.jpg`, `028_debout_M4_telephone.jpg`). Les échecs M2 et M4 de la première
tâche venaient du test (mesure avant la fin de la reconstruction).

### 4.3 Assise dans les véhicules (marges en studs, repère du véhicule ; négatif = dépassement)

Échantillon (P-01, `wk_pixel` micro, `wk_comete` supercar, `wk_brise` roadster, `wk_dune` SUV) : 8 morphologies aux deux
places ; les 14 autres modèles : morphologies extrêmes M2, M4, M5, M7, M8 aux deux places. 212 assises mesurées (les 8
« non assis » sont la place passager **absente** du P-01 : défaut du test, corrigé ensuite, non rejoué).

| Modèle | Siège | Tête seule : M2 / réf. (M1 ou M8) / M4 | Avec accessoires, pire (M7) | Flancs, pire | Jambes / planche, pire | Mains → volant (réf.) | Non assis |
|---|---|---|---|---|---|---|---|
| `proto_p01` | conducteur | +1,02 / +0,63 / -0,06 | -2,46 | +0,22 | +0,00 | +2,81 | — |
| `proto_p01` | passager | ouvert | ouvert | — | +0,00 | — | M1,M2,M3,M4,M5,M6,M7,M8 |
| `wk_aster` | conducteur | -0,17 / -0,56 / -1,24 | -3,65 | -0,33 | +0,24 LeftLowerLeg/Volant | +2,31 | — |
| `wk_aster` | passager | -0,17 / -0,56 / -1,24 | -3,65 | -0,37 | +0,00 | — | — |
| `wk_atlas` | conducteur | +0,72 / +0,33 / -0,35 | -2,76 | -0,18 | +0,38 LeftLowerLeg/PlancheDeBord | +1,66 | — |
| `wk_atlas` | passager | +0,72 / +0,33 / -0,35 | -2,76 | -0,22 | +0,38 LeftLowerLeg/PlancheDeBord | — | — |
| `wk_brio` | conducteur | +0,02 / -0,37 / -1,05 | -3,46 | -0,40 | +0,39 LeftLowerLeg/Volant | +2,10 | — |
| `wk_brio` | passager | +0,02 / -0,37 / -1,05 | -3,46 | -0,44 | +0,04 LeftFoot/Console | — | — |
| `wk_brise` | conducteur | ouvert | ouvert | -0,37 | +0,55 LeftUpperLeg/PlancheDeBord | +2,46 | — |
| `wk_brise` | passager | ouvert | ouvert | -0,42 | +0,55 LeftUpperLeg/PlancheDeBord | — | — |
| `wk_cadence` | conducteur | -0,26 / -0,65 / -1,33 | -3,74 | -0,28 | +0,41 RightLowerLeg/Volant | +1,77 | — |
| `wk_cadence` | passager | -0,26 / -0,65 / -1,33 | -3,74 | -0,33 | +0,39 LeftLowerLeg/PlancheDeBord | — | — |
| `wk_comete` | conducteur | -1,07 / -1,46 / -2,15 | -4,55 | -0,13 | +0,60 LeftUpperLeg/Volant | +1,87 | — |
| `wk_comete` | passager | -1,07 / -1,46 / -2,15 | -4,55 | -0,18 | +0,55 LeftLowerLeg/PlancheDeBord | — | — |
| `wk_dune` | conducteur | +0,32 / -0,07 / -0,76 | -3,16 | -0,27 | +0,00 | +3,57 | — |
| `wk_dune` | passager | +0,32 / -0,07 / -0,76 | -3,16 | -0,32 | +0,00 | — | — |
| `wk_eclat` | conducteur | -0,78 / -1,18 / -1,86 | -4,27 | -0,29 | +0,60 LeftUpperLeg/Volant | +1,86 | — |
| `wk_eclat` | passager | -0,78 / -1,18 / -1,86 | -4,27 | -0,34 | +0,55 LeftLowerLeg/PlancheDeBord | — | — |
| `wk_fil` | conducteur | +0,18 / -0,21 / -0,89 | -3,30 | -0,35 | +0,38 LeftLowerLeg/Volant | +2,22 | — |
| `wk_fil` | passager | +0,18 / -0,21 / -0,89 | -3,30 | -0,39 | +0,00 | — | — |
| `wk_lumen` | conducteur | -0,09 / -0,48 / -1,16 | -3,57 | -0,29 | +0,00 | +3,42 | — |
| `wk_lumen` | passager | -0,09 / -0,48 / -1,16 | -3,57 | -0,34 | +0,00 | — | — |
| `wk_mistral` | conducteur | -0,83 / -1,22 / -1,91 | -4,31 | -0,20 | +0,60 LeftUpperLeg/Volant | +1,77 | — |
| `wk_mistral` | passager | -0,83 / -1,22 / -1,91 | -4,31 | -0,25 | +0,55 LeftLowerLeg/PlancheDeBord | — | — |
| `wk_nova` | conducteur | -0,17 / -0,57 / -1,25 | -3,65 | -0,35 | +0,55 LeftLowerLeg/PlancheDeBord | +1,63 | — |
| `wk_nova` | passager | -0,17 / -0,57 / -1,25 | -3,65 | -0,39 | +0,55 LeftLowerLeg/PlancheDeBord | — | — |
| `wk_oree` | conducteur | -0,40 / -0,80 / -1,48 | -3,88 | -0,22 | +0,49 RightUpperLeg/Volant | +1,79 | — |
| `wk_oree` | passager | -0,40 / -0,80 / -1,48 | -3,88 | -0,27 | +0,32 LeftLowerLeg/PlancheDeBord | — | — |
| `wk_pixel` | conducteur | +0,26 / -0,13 / -0,82 | -3,22 | -0,47 | +0,23 LeftLowerLeg/Volant | +2,36 | — |
| `wk_pixel` | passager | +0,26 / -0,13 / -0,82 | -3,22 | -0,52 | +0,11 LeftFoot/Console | — | — |
| `wk_rafale` | conducteur | -0,39 / -0,78 / -1,47 | -3,87 | -0,31 | +0,20 LeftLowerLeg/Volant | +2,33 | — |
| `wk_rafale` | passager | -0,39 / -0,78 / -1,47 | -3,87 | -0,35 | +0,01 LeftFoot/PlancheDeBord | — | — |
| `wk_sentier` | conducteur | +0,48 / +0,09 / -0,60 | -3,00 | -0,35 | +0,00 | +3,62 | — |
| `wk_sentier` | passager | +0,48 / +0,09 / -0,60 | -3,00 | -0,39 | +0,00 | — | — |
| `wk_vigie` | conducteur | +0,49 / +0,10 / -0,58 | -2,99 | -0,17 | +0,00 | +4,00 | — |
| `wk_vigie` | passager | +0,49 / +0,10 / -0,58 | -2,99 | -0,21 | +0,00 | — | — |
| `wk_zenith` | conducteur | -1,00 / -1,39 / -2,08 | -4,48 | -0,11 | +0,60 LeftUpperLeg/Volant | +1,82 | — |
| `wk_zenith` | passager | -1,00 / -1,39 / -2,08 | -4,48 | -0,16 | +0,55 LeftLowerLeg/PlancheDeBord | — | — |

Lecture : « tête seule » = sommet de la tête **sans** cheveux ni chapeau, sous le dessous du pavillon ; la référence est M1
(échantillon) ou M8 (même corps, autres modèles). Captures : `captures/007_wk_comete_conducteur_M1.jpg` (tête entière
au-dessus du pavillon), `004_wk_pixel_conducteur_M1.jpg` et `013_wk_dune_conducteur_M1.jpg` (cheveux à travers le
toit, avant-bras à travers la portière), `010_wk_brise_conducteur_M1.jpg` (roadster), `082_wk_vigie_conducteur_M7.jpg`.

Constats :

1. **Pavillon trop bas pour un R15 standard** : tête seule au-dessus du dessous du pavillon dans **14 véhicules fermés sur
   18** avec la référence (jusqu'à 1,46 st, `wk_comete`), dans **10 sur 18 même pour la plus petite morphologie (M2)** ;
   avec les cheveux du compte de test, **17 sur 18**. Limiter les proportions ne suffirait donc pas : aucune limitation
   n'est appliquée (§2). Correction possible : géométrie de l'habitacle (assise plus basse ou pavillon plus haut) dans
   `BodyKits` — **à arbitrer** (silhouettes de la gamme proposée) ; aucun paramètre physique n'est en cause.
2. **Avant-bras à travers la portière** : marge négative aux flancs pour 30 assises sur 37 avec le corps de référence
   (jusqu'à 0,31 st) ; aucune avec M2. Même nature (largeur d'habitacle ou pose assise), **à arbitrer**.
3. **Jambes dans la planche de bord ou le volant** au-delà de 0,5 st dans 6 modèles bas (`wk_brise`, `wk_comete`,
   `wk_eclat`, `wk_mistral`, `wk_nova`, `wk_zenith`), dès la référence.
4. **Mains** : 1,6 à 4,0 st du centre du volant (aucune animation de conduite) — limite de la pose assise du moteur.
5. **Assise** : aucun enfoncement du bassin dans le siège (bassin au moins 0,29 st au-dessus) ; pieds au-dessus du
   dessous de caisse partout sauf le **P-01** (châssis ouvert : pieds 0,2 à 0,7 st plus bas que la carrosserie).
6. **Vue cockpit** (vraie touche V, M1 et M7, 5 véhicules) : **10 / 10**, aucune pièce du personnage ni de ses
   accessoires visible (`captures/057_cockpit_wk_comete_M7.jpg`) ; la caméra est fixe par modèle, la tête réelle est
   jusqu'à 2,1 st au-dessus du point de vue (M4, `wk_comete`), sans effet puisque le personnage est masqué.
7. **Téléphone en place passager** (M1, M4, 4 véhicules) : 8 / 8, téléphone à 0,29 st de la main.
8. **Masse** : le personnage assis ajoute 7 (M2) à 21 (M4) unités de masse Roblox à l'ensemble du véhicule (1 169 à
   2 137) ; le simulateur rapporte ses forces à cette masse ; effet sur le centre de gravité **non mesuré** ; physique
   non modifiée.

### 4.4 Sorties

| Place | Chemin | Réussies | Échecs |
|---|---|---|---|
| Conducteur | vraie touche F, placement par le serveur (`findExitPivot`) | **35 / 40** | personnage retrouvé **couché** au sol (`wk_pixel` M2, `wk_dune` M2, M3, M8) ; recouvrement avec le véhicule (`wk_brise` M5) — cause non établie |
| Passager | vraie touche Espace : saut du moteur, **aucun placement par le jeu** | **0 / 32** | sur le toit ou la carrosserie (`wk_comete`, `wk_brise`), couché au sol (`wk_pixel`, `wk_dune`), dès la référence |

La sortie passager est un **défaut du jeu antérieur à ce lot** (indépendant de la morphologie) ; non corrigé ici.

### 4.5 Bras et téléphone vus par un autre joueur (`avatar2`, QA-A10)

Le joueur 2 voit le bras du joueur 1 levé à **55°** du tronc et son téléphone à 0,29 st de la main, 1,84 st devant
(téléphone sorti par le canal du jeu, instrumenté). La correction QA-A10 fonctionne pour les autres joueurs ; elle n'a
pas été modifiée.

### 4.6 Tenues dans le moteur

Catalogue reçu par le client (5 emplacements) ; emplacement non disponible refusé ; tenue inconnue refusée ;
identifiant d'actif envoyé par le client ignoré ; retrait d'un emplacement ; demandes limitées ; textes FR/EN ;
identifiant bien formé mais inexistant **refusé par le moteur, apparence intacte** ; restauration exacte de l'apparence
initiale ; refus dans un véhicule (« OutfitNotWhileSeated »). Vêtements **classiques** du compte conservés et restaurés ;
vêtements **3D superposés : NON TESTÉ** (aucun actif autorisé disponible, aucun porté par le compte de test).

## 5. Tests automatisés

- Lune : `tests/lune/specs/AvatarFoundation.luau` (7 tests : politique, réglage des deux places, catalogue, emplacements
  et textes FR/EN, identifiants, essayage / retrait / restauration, autorité du serveur) ; total **355 / 0**.
- `scripts\verify.ps1 -RobloxTypes .tooling\globalTypes.d.luau`  (2026-11-04, worktree du lot, `82e7bd5`) : 9 étapes OK, Lune 355 / 0.
- VM : sessions `avatar` et `avatar2` (`tests/studio/AvatarServer.server.luau`, `AvatarClient.client.luau`), journal
  machine `@@AWAVATAR@@` pour les tableaux.

## 6. Problèmes ouverts et décisions à prendre

| Id | Problème | Proposition | Décision |
|---|---|---|---|
| QA-A13 | Pavillon trop bas : tête d'un R15 standard au-dessus du toit (14 / 18 fermés), cheveux 17 / 18 | Abaisser l'assise ou relever le pavillon par silhouette (`BodyKits`), puis rejouer `avatar` ; pas de limitation des proportions (insuffisante) | Propriétaire (gamme proposée) |
| QA-A14 | Avant-bras à travers la portière (30 / 37 assises de référence) ; jambes dans la planche de bord (6 modèles bas) | Habitacle plus large ou siège décalé vers l'intérieur ; planche de bord reculée | Propriétaire |
| QA-A15 | Sortie passager sans placement : sur le toit ou couché (0 / 32) | Même placement que le conducteur (`findExitPivot`) au départ du passager | À autoriser (comportement du jeu) |
| QA-A16 | Conducteur couché après la sortie (4 / 40), recouvrement (1 / 40) | Diagnostic (hauteur de dépose fixe +1,5 st, petites morphologies) | Ouvert |
| — | Mains loin du volant | Animation ou IK de conduite (nouvelle fonction) | Proposition |
| — | Vêtements 3D superposés, accessoires réels, packs de corps | Essai avec des actifs autorisés fournis par le propriétaire | NON TESTÉ |
| — | Réglages « Avatar Settings » de l'expérience publiée | R15, « Player Choice » | Action du propriétaire |
| — | Persistance des tenues, interface d'essayage | Lots ultérieurs (direction artistique séparée) | Hors périmètre |

QA-A11 (lot 0.9.2) n'est pas touchée ; QA-A08, A10 et A12 ne sont pas modifiées (aucun fichier de physique ni du
téléphone n'est changé par ce lot).

## 7. Livraison

- Commits : `e616ef5` (R15, tenues, tests Lune), `dccf857` (sessions VM), `f05a22a` (corrections des tests VM), `82e7bd5`
  (rapport, documents) ; dernier SHA : voir la PR #12.
- PR brouillon [#12](https://github.com/AbdelmalekYounes/roblox-automotive-world/pull/12), non fusionnée.
