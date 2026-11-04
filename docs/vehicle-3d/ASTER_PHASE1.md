# Aster — rapport de la phase 1 (pose assise, gabarit, avatars humains)

Branche `feat/aster-phase1` (base `feat/vehicle-3d-references`), commits `8a4144a` → `3c3db30`, 2026-11-04.
Dépôt d'art privé : `AbdelmalekYounes/roblox-automotive-world-art`, commits `37de4d8` et `80ede43`.

Rapport factuel : seuls figurent les essais exécutés, avec leur commande et leur identifiant de tâche. Ce qui n'a
pas été vérifié est listé au §8. Aucun modèle 3D définitif n'a été produit. Aucune publication Roblox n'a eu lieu.
Aucun DataStore n'est utilisé. La physique des véhicules n'est pas modifiée.

## 1. Demandes et décisions du propriétaire (2026-11-04)

| Sujet | Décision du propriétaire |
|---|---|
| Lancement | « Oui, phase 1 » ; Blender installé à sa demande |
| D1, D3 (rappel) | Habitacle à l'échelle Roblox avec assise basse ; pose assise propre au jeu |
| Avatars | « uniquement l'avatar humain et non pas semi lego », puis « Corps humain + proportions » |
| Corps | Un corps masculin et un corps féminin, en ne modifiant que le corps : **995 Billie** (masculin) et **994 Jordan** (féminin) |
| Attribution | **Choix du joueur** |
| Portée | **Tous les joueurs** reçoivent l'un des deux corps |
| Têtes classiques | « Remplacer têtes classiques » : une tête « bloc » prend la tête du paquet (visage changé) ; les autres têtes sont conservées |

## 2. Réalisé

### 2.1 Pose assise du jeu (D3)

- `src/shared/Vehicles/SeatPose.luau` (module pur, gelé) : pose « Conduite » et pose « Passager ». La pose
  Conduite ajoute les bras au volant, la pose Passager concerne seulement les jambes et le buste.
  Le bassin descend de 0,3 st, le buste est incliné de 18°, le cou de −12° et les genoux de 40°. Les épaules
  sont à 32° avec ±22° de lacet, les coudes à 15°.
- `src/client/Vehicles/SeatPoseController.luau` : chaque client compose les décalages sur `Transform` en
  `PreSimulation`, après l'animation, avec une transition de 0,3 s. Les bras sont laissés libres quand le
  téléphone est sorti (`AWPhoneRaised`).
- **Activable par siège** : la pose ne s'applique qu'aux sièges portant l'attribut `AWSeatPose`. Aucune
  carrosserie provisoire ne le porte, donc le comportement actuel du jeu est inchangé. Un test Lune le vérifie.

### 2.2 Gabarit technique de l'Aster

- `tests/studio/AsterTemplate.luau` (module pur) : environ 23 blocs dans le repère du véhicule (plancher,
  caisses, portières, vitrages, pavillon, sièges, volant, pédalier, planche de bord, roues de la définition,
  repères de sortie). La hauteur physique de la définition (1,47 m) n'est pas modifiée.
- Paramètres finaux, issus des mesures VM :

  | Paramètre | Valeur |
  |---|---|
  | Hauteur sous pavillon | 4,60 st |
  | Volant | centre (−1,40 ; 1,52 ; 1,10), rayon 0,55 st, incliné de 15° |
  | Pédalier | z −1,4 st |
  | Planche de bord | z 0 |

  Avec ces paramètres, la maquette mesure **1,83 m hors tout**.
- `tests/lune/tools/aster-template.luau` exporte le gabarit en JSON et en OBJ (1 unité = 1 stud, rotations
  appliquées), ainsi que les témoins d'étalonnage. Les paramètres partiels sont complétés par les valeurs par défaut.
- Le gabarit final est exporté dans le dépôt d'art (`vehicles/wk_aster/ref-sheets/`, avec
  `wk_aster_gabarit_params.json`).
- La scène Blender `wk_aster.blend` est régénérée. Le repère `CameraCockpit` est recalé à (−1,40 ; 2,18 ; 3,04),
  d'après le centre de tête de H3 sur le corps masculin en pose du jeu (tâche `20261104-151955`), avancé de 0,1 st.

### 2.3 Avatars humains uniquement

- `AvatarPolicy` :
  - type de corps imposé à 1 ;
  - deux corps `Bodies.Masculin` (paquet 995) et `Bodies.Feminin` (paquet 994). Les identifiants des 5 pièces
    ont été relevés le 2026-11-04 sur `catalog.roblox.com/v1/bundles/{id}/details` : paquets gratuits,
    créateur Roblox ;
  - remplacement du torse, des bras et des jambes ;
  - **têtes classiques « bloc » remplacées** par la tête du paquet de la silhouette choisie (« Billie - Head »
    11748988354, « Jordan - Head » 11740063830), ce qui change le visage. Toute autre tête est conservée.
    Critère de forme mesuré par le moteur, sans liste d'identifiants : Roblox publie de nombreuses têtes « bloc »
    comme têtes dynamiques, dont celle du compte de test (« Stevie Standard », type 79). Est classique une tête
    dont la largeur et la profondeur valent au moins 0,90 fois la hauteur (`isClassicHeadShape`, mesures au
    §5.4). La tête par défaut (identifiant 0) est toujours remplacée. La forme est mesurée une fois par tête,
    à l'apparition, avant tout remplacement ;
  - corps par défaut `Masculin`, **provisoire** (§7).
- `AvatarService` :
  - le corps est appliqué à chaque apparition, pour tous les joueurs. L'apparence initiale est mémorisée
    d'abord ; le corps, puis la tenue équipée, sont appliqués ensuite dans un fil séparé. `ApplyDescriptionAsync`
    est borné à 10 s par essai, avec 3 essais au plus, chacun journalisé ;
  - nouvelle action `BodyChoose`. Elle est refusée si le corps est inconnu (`AvatarBodyUnknown`), si le joueur
    est assis, si l'apparence est encore en chargement ou si une opération est en cours. Un corps non appliqué
    donne `AvatarBodyInvalid` ;
  - attributs `AWAvatarBody` et `AWAvatarBodyChosen`. Le choix vaut pour la session seulement.
- Client :
  - panneau « Choisissez votre silhouette » (`src/client/UI/BodyChoice.luau`) à la première apparition, tant
    que le joueur n'a pas choisi. Il est placé en haut de l'écran et n'est pas bloquant ;
  - option « Silhouette » dans Téléphone › Paramètres › Interface ;
  - textes en français et en anglais (`Localization`).

### 2.4 Étalonnage de l'échelle Blender → Studio

Les témoins `calibration/temoins_*.fbx|glb` sont prêts dans le dépôt d'art : un cube de 10 st et la roue de
l'Aster (dimensions Blender : 10 × 10 × 10 et 0,732 × 2,25 × 2,25). La procédure d'import est décrite dans
`calibration/README.md`. Le **relevé dans Studio reste à faire par le propriétaire** (importeur graphique).

## 3. Commandes

| Commande | Résultat |
|---|---|
| `scripts\verify.ps1 -RobloxTypes .tooling\globalTypes.d.luau` (2026-11-04, après `3c3db30`) | Rojo, Selene (0 erreur, 0 avertissement), pilote Studio, StyLua, **Lune 359/359**, carte, Rojo monde ouvert, pytest 14/14, **luau-lsp strict : 0 erreur** — toutes les étapes OK |
| `tools\vm\host-run.ps1 -NoVmControl -Place Dev -Sessions <sessions> -GuiInput …` | Passages VM du §4 |
| `lune run tests/lune/tools/aster-template.luau build/AutomotiveWorld.rbxlx <sortie> <params.json>` | Gabarit final : 23 blocs, assise −0,04 st, pavillon 4,56 st, 1,83 m hors tout |
| `blender --background --factory-startup --python tools/blender/setup_aster_scene.py` (Blender 4.5.9 LTS) | `AW_BLENDER_OK`, témoins 10 × 10 × 10 et 0,732 × 2,25 × 2,25 |

## 4. Passages dans la VM (Roblox Studio, VM VMware, compte de test)

| Tâche | Commit | Sessions | Résultat | Objet |
|---|---|---|---|---|
| `20261104-134156` | `8a4144a` | aster | 20 réussis / 7 échecs | Pose v1 : mains à hauteur de tête |
| `20261104-134756` | `715aa9c` | aster | 21 / 6 | Pose v2, volant tourné face au conducteur |
| `20261104-135355` | `fe89f7e` | aster | 23 / 6 | 7 morphologies humaines, 4,60 st sous pavillon ; mains à 1,9–2,2 st de la jante (§6.1) |
| `20261104-145632` | `284ce4b` | avatar, aster | 301 / 130 | Choix du corps validé, corps par défaut non appliqué (§6.2) ; repère corrigé |
| `20261104-151955` | `316e462` | avatar, aster | 296 / 137 | **Aster : tous les contrôles réussis** ; avatar : préparation bloquée (§6.2) |
| `20261104-154409` | `df5c0b9` | avatar | 273 / 130 | **Corps humains : tous les contrôles réussis** |
| `20261104-161530` | `9cfc493` | aster | 43 / 0 | Forme de 14 têtes mesurée (§5.4) |
| `20261104-162124` | `83cb6de` | avatar, aster | 297 / 148 | Têtes classiques remplacées (contrôles réussis) ; Aster : vue au-dessus du volant −0,03 st pour H5 ; clavier non étalonné dans la session `avatar` (§5.3) |
| `20261104-164354` | `83cb6de` | avatar | 256 / 145 | Même défaut de clavier ; contrôles des têtes réussis |
| `20261104-170413` | `3c3db30` | avatar | 273 / 130 | **Corps et têtes : tous les contrôles réussis** ; clavier étalonné (diagnostic) |

## 5. Résultats

### 5.1 Gabarit de l'Aster — paramètres finaux

Deux passages : `20261104-151955` (commit `316e462`) avec la tête classique du compte de test, puis
`20261104-162124` (commit `83cb6de`) avec la tête remplacée par celle du paquet, conformément à la règle du §2.3.
Le tableau donne le second passage, le premier entre parenthèses quand il diffère.

Les mesures sont faites côté client, dans le repère du gabarit. Il y a 10 morphologies : H1 à H7 sur le corps
masculin, et F1, F2, F4 sur le corps féminin (mêmes échelles que H1, H2 et H4). Chacune est mesurée sur les deux
places et dans les deux poses, soit 40 mesures sur 40.

| Pose, place | Tête au-dessus de l'assise | Marge corps–pavillon | Marge latérale | Chevauchement des jambes | Mains–jante | Yeux au-dessus du volant |
|---|---|---|---|---|---|---|
| Standard, conducteur | 2,99 à 3,57 st (3,01 à 3,68) | 1,03 à 1,61 (0,92 à 1,59) | 0,21 à 0,75 | 0 | — | — |
| **Jeu, conducteur** | 2,60 à 3,18 (2,62 à 3,29) | 1,42 à 2,00 (1,31 à 1,98) | 0,41 à 0,86 | 0 | **0,15 à 0,34 st** (seuil 0,35) | **−0,03 à 0,58 st** (0,01 à 0,67) |

Passager : mêmes hauteurs et marges, marge latérale de 0,21 st au moins.

- Second passage : 17 contrôles `aster.*` réussis sur 18. **Échec : vue au-dessus du volant, H5 −0,03 st.** Tous
  les contrôles étaient réussis au premier passage.
- **Accessoires** : en pose du jeu, les cheveux montent au plus à 3,39 st au-dessus de l'assise (marge 1,21 st au
  moins) ; en pose standard, 3,76 st (marge 0,84 st). Seul le chapeau haut d'essai (H6, volontairement extrême)
  dépasse.
- La pose du jeu abaisse la tête d'environ 0,4 st par rapport à la pose standard.
- **Limite d'un volant fixe.** Les yeux sont estimés au centre de la tête + 0,15 st. Recalculé sur ces mesures,
  regagner 0,05 st de vue pour H5 éloigne les mains de 0,40 st de la jante, au-delà du seuil de 0,35 st. Un volant
  fixe unique ne peut satisfaire à la fois les mains des grands avatars et la vue des petits. Volant et seuils sont
  laissés tels quels ; voir §7.4.
- Le repère `CameraCockpit` (d'après le premier passage) reste à moins de 0,1 st du centre de tête de H3 mesuré au
  second passage (−1,40 ; 2,14 ; 3,06).

### 5.2 Corps et têtes — tâche `20261104-170413` (commit `3c3db30`)

Les mêmes contrôles de corps étaient déjà réussis dans la tâche `20261104-154409`, avant la règle des têtes.

| Contrôle | Détail mesuré |
|---|---|
| `avatar.corps.defaut_applique` ✅ | Attribut `Masculin` ; torse 11748986529 |
| `avatar.corps.tete_classique_remplacee` ✅ | Tête du joueur 10638267973, classique ; portée 11748988354 (Billie) |
| `avatar.corps.choix_feminin_applique` ✅ | Ok ; torse 11740060397 |
| `avatar.corps.tete_selon_forme_vetements_conserves` ✅ | Tête → 11740063830 (Jordan) ; haut 144076358 → 144076358 |
| `avatar.corps.choix_memorise_session` ✅ | |
| `avatar.corps.corps_inconnu_refuse` ✅ | `AvatarBodyUnknown` |
| `avatar.corps.retour_masculin` ✅ | Ok |
| `avatar.tenue.apparence_initiale_memorisee` ✅, `restauration_apparence_initiale` ✅ | |

Ces contrôles appellent le service directement, côté serveur. Le panneau de choix est **affiché** dans les
captures de la session `aster` (tâche `20261104-151955`, captures 095 et 096), mais il n'a été **cliqué par aucun
essai** (§8).

### 5.3 Effet des corps humains sur les carrosseries provisoires (session `avatar`)

Comparaison des contrôles en échec : tâche `20261104-154409` (corps masculin) contre tâche `20261104-111326`
(lot AVATAR-01, corps du compte de test).

- **130 échecs contre 165 ; 59 contrôles en échec auparavant ne le sont plus**, surtout des têtes sous le pavillon
  (corps réaliste moins haut assis).
- **Nouveaux échecs :**
  - 12 contrôles « pieds dans l'habitacle » sur `wk_atlas`, `wk_brio`, `wk_dune`, `wk_fil`, `wk_pixel` et
    `wk_sentier`. Les pieds des grandes morphologies M4 et M7 (et M5 sur `wk_sentier`) dépassent de 0,01 à
    0,24 st ;
  - 10 sorties du conducteur sur `wk_brise`, `wk_dune` et `wk_pixel` : personnage couché, ou en recouvrement avec
    le véhicule. C'est la même famille que QA-A15 et QA-A16. Ces sorties ne sont pas corrigées : le propriétaire a
    demandé d'attendre pour QA-A15 ;
  - `telephone_bras_leve` en échec de façon intermittente : M4 et M7 ici, M2 et M5 dans la tâche
    `20261104-151955`, aucun dans la tâche `20261104-145632`. Le bras part parfois de 31–32° au lieu de 6°.
    La cause n'est pas établie.

Avec les têtes remplacées (tâche `20261104-170413` contre `20261104-154409`) :

- le nombre d'échecs est identique (130) ;
- **nouvel échec stable** : la tête réaliste, plus haute, touche le pavillon dans `wk_dune` (M1, M3, M6, M8 :
  −0,01 à −0,25 st) et `wk_sentier` (M8 : −0,01 st), sur les deux places ;
- les sorties du conducteur et le bras du téléphone continuent de varier d'un passage à l'autre.

**Clavier de la VM.** Dans les tâches `20261104-162124` et `20261104-164354`, les touches de l'étalonnage n'ont
pas été reçues dans la session `avatar`, d'où l'échec de toutes les marches. Dans le même passage, la session
`aster` était étalonnée. La tâche `20261104-170413` (diagnostic ajouté) est étalonnée : aucun champ de texte ni
aucune sélection n'avait le focus. Elle montre que le mode « vk » y produisait A, W, Y pour Q, Z, Y, ce qui
indique une disposition AZERTY ; le mode « scan » a été retenu. **Cause probable : disposition du clavier de la VM
variable d'un passage à l'autre. Non prouvée** pour les deux passages en échec, dont le détail n'était pas
journalisé. Aucun réglage de la VM n'a été modifié.

Ces échecs sont inscrits au registre QA (QA-A17 à A22).

### 5.4 Forme des têtes — tâche `20261104-161530` (commit `9cfc493`)

Pièce `Head` mesurée par le moteur (échelle de tête 1) :

| Têtes | Taille (studs) | Largeur / hauteur | Profondeur / hauteur |
|---|---|---|---|
| Défaut (0) | 1,127 × 1,133 × 1,128 | 0,994 | 0,996 |
| 5 classiques Roblox (Stevie Standard, Freckles, Squigglin Out, Err..., Check It) | 1,198 × 1,202 × 1,199 à 1,207 | 0,996 | 0,997 à 1,004 |
| 8 réalistes des paquets 988 à 995 | 1,268 à 1,282 × 1,799 à 1,943 × 1,383 à 1,490 | 0,653 à 0,711 | 0,737 à 0,802 |

Seuil retenu : 0,90 sur les deux rapports.

## 6. Défauts trouvés et corrigés pendant la phase

### 6.1 Repère de mesure

Les passages 1 à 3 ont été mesurés dans le repère du plancher, et non dans celui du gabarit. Le pivot d'un modèle
doté d'une `PrimaryPart` suit cette pièce côté client, avec un décalage de (0 ; −0,39 ; +1,92) st.

- Les **mesures relatives** de ces passages restent valides : hauteurs au-dessus de l'assise, marges, chevauchements.
- Les **positions absolues** ne le sont pas : mains, tête et pointes de pied, ainsi que le volant, le pédalier, la
  planche de bord et le repère Blender qui en avaient été déduits.

Correction : le serveur transmet l'origine du gabarit (attribut `AWAsterOrigin`, de type CFrame) et le client mesure
dans ce repère.

Deux autres défauts corrigés :

- L'inclinaison du volant tournait le disque autour de son propre axe, donc sans effet visible. L'ordre de
  composition des rotations est corrigé, et un test Lune le couvre (`AsterTemplate.rotate`).
- L'export OBJ ignorait les rotations ; il les applique maintenant.

### 6.2 Application du corps à l'apparition

- Tâche `20261104-145632` : le premier `ApplyDescriptionAsync` est refusé par le moteur (« DataModel was not
  available »).
- Tâche `20261104-151955` : avec une attente puis plusieurs essais, un appel ne rend plus la main. La préparation
  du personnage se bloque, et l'apparence initiale n'est jamais mémorisée.
- Correction `df5c0b9` : mémorisation d'abord, corps en arrière-plan, appel borné dans le temps. Validée par la
  tâche `20261104-154409`, qui ne contient aucun avertissement « Avatar humain » dans ses journaux.

## 7. Points à arbitrer par le propriétaire

1. **Corps par défaut avant le choix du joueur** : `Masculin`, à titre provisoire.
2. **Couleurs de peau.** Les têtes classiques sont désormais remplacées, sur décision du propriétaire. Les couleurs
   du joueur restent conservées : sur le compte de test, bras gris et jambes bleues (capture 001 de la tâche
   `20261104-170413`). Faut-il les harmoniser ? **Non fait.** Les têtes stylisées non cubiques (animaux, objets…)
   sont conservées par le critère de forme.
3. **D7, largeur de l'habitacle.** Avec les deux corps retenus, la marge latérale est **positive** sur les deux
   places : au moins 0,21 st dans la largeur physique de 1,78 m. Le problème mesuré au passage 3 avec le corps du
   compte de test (épaules au-delà de la portière) ne se pose plus. Il reste à confirmer qu'aucune décision D7
   n'est nécessaire.
4. **Pose adaptée à la taille (proposition).** Placer les mains sur la jante selon la taille de l'avatar, en
   corrigeant l'épaule et le coude, rendrait la vue et la prise du volant valables pour toutes les morphologies.
   Aujourd'hui, la plus petite voit 0,03 st sous le haut du volant (§5.1). **Non fait.**
5. **Hauteur sous pavillon (proposition).** Avec les têtes remplacées, les cheveux montent au plus à 3,39 st
   au-dessus de l'assise en pose du jeu, et à 3,76 st en pose standard. Les 4,60 st du gabarit pourraient descendre
   à environ 4,00 st, ce qui rapprocherait la maquette (1,83 m hors tout) de la silhouette visée. **Non fait.**
6. **QA-A15** (sortie du passager) reste en attente, à la demande du propriétaire (« Attends »).

## 8. Non vérifié

- **Interface du choix** : les boutons du panneau et l'option « Silhouette » du téléphone n'ont été cliqués par
  aucun essai, VM ou humain. Le panneau est seulement vu affiché.
- **Changement de corps en jeu** : non vérifié avec un vrai joueur, ni à deux joueurs (réplication vue par un autre
  client).
- **Rendu des corps et des têtes** : seul le compte de test est vu, en captures. Aucun essai avec d'autres avatars
  (autres têtes dynamiques réalistes ou stylisées, vêtements 3D superposés) ni sur appareil réel. Le critère de
  forme n'est mesuré que sur les 14 têtes du §5.4.
- **Étalonnage Blender → Studio** : import non réalisé ; le propriétaire doit relever `Size` (§2.4).
- **Esquisses « Trait »** du dépôt d'art : non mises à jour selon le gabarit final.
- **Pose du jeu sur les véhicules réels** : non activée, puisqu'aucun siège ne porte `AWSeatPose`.
- **Bras du téléphone** : échec intermittent, cause non établie (QA-A20).
- **Clavier de la VM** : cause des deux échecs d'étalonnage non prouvée (QA-A22).
- **Performances** : rien n'a été mesuré dans cette phase.
