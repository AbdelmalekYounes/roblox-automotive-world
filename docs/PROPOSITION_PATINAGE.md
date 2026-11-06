# Proposition — patinage quand l'antipatinage est coupé (Comète, Brio)

Rédigée le 2026-11-06, à la demande du propriétaire (« Effectuez cette tâche ici »), après le lot AUDIO-03. **Aucune
modification du jeu** : ce document chiffre des options, et l'arbitrage revient au propriétaire. Les options qui
touchent les règles d'aides demandent une décision écrite ; celles qui touchent la physique demandent un lot.

## 1. Constat

Pendant les essais en jeu des sons de pneus (lot AUDIO-03), le propriétaire a entendu crisser la Comète dès qu'il
accélérait ou tournait. La mesure a montré que le son traduisait un **vrai patinage** dans la physique. Le son a
depuis été rendu tolérant au patinage (décision « son plus tolérant », voir `docs/lot-audio-03/RAPPORT_AUDIO_03.md`
§ 6), mais la physique est restée la même.

Deux règles existantes se combinent :
- **Aides coupées au départ** : cahier des charges, ligne 55 : « ABS, antipatinage et contrôle de stabilité
  existent uniquement lorsque le modèle en dispose ; état par défaut désactivé selon les règles validées, sans
  assistances universelles cachées ». En jeu, `VehicleService.assignDriver` remet toutes les aides à « désactivé » à
  chaque prise du volant.
- **Accélérateur au clavier** : la touche donne l'accélérateur à fond en 0,2 s (rampe `PEDAL_RISE_PER_S = 5`
  d'`InputArbiter`, arbitrage A2, qui n'est pas une aide). Il n'y a pas de position intermédiaire.

La Brio et la Comète sont toutes deux **équipées** de l'antipatinage (`Aids.TractionControl = true`, touche **2**).

## 2. Mesures (banc planaire, 2026-11-06)

Commande :

```
lune run tests/lune/tools/patinage-mesure.luau build/AutomotiveWorld.rbxlx
```

La place est construite par `rojo build -o build/AutomotiveWorld.rbxlx` depuis `origin/main` d295473.

Conditions de mesure :
- **Banc planaire** (`tests/lune/PlanarSim`), pas de 1/240 s, sol sec. Ce sont des **sorties du modèle, pas des
  mesures dans Roblox**.
- **Options** : chacune est essayée sur une **copie** de la définition.
- **Patinage franc** : la roue la moins glissante de l'essieu moteur dépasse 3 fois le glissement du pic
  d'adhérence (0,10).
- **Virage** : départ lancé, braquage à fond et accélérateur à fond (rampe), pendant 3 s. Le tableau donne la dérive
  maximale de la caisse et le cap final ; au-delà de 360°, la voiture a fait un tour complet.

### Comète (propulsion, 784 N·m, autobloquant arrière 0,3 / 40 N·m)

| Option | 0–100 km/h | Patinage franc au départ | Virage à 20 km/h | Virage à 40 km/h |
|---|---|---|---|---|
| **Actuel** (aides coupées, rampe 0,2 s) | 4,49 s | 3,68 s | tête-à-queue : dérive 83°, cap 318° ; patinage 2,69 s | tête-à-queue : dérive 85°, cap 309° |
| Antipatinage actif | **4,19 s** | 0,36 s | tenu : dérive 6°, aucun patinage | tenu : dérive 3°, aucun patinage |
| Rampe clavier de 1,0 s | 4,80 s | 3,30 s | tête-à-queue (83°) | tête-à-queue (85°) |
| Autobloquant arrière renforcé (0,6) | 4,49 s | 3,68 s | tête-à-queue (83°) | tête-à-queue (85°) |

Vérification à la main (rapports de la définition) :
- **Couple aux roues arrière**, accélérateur à fond (784 N·m × rapport × 3 × 0,93 / 0,34 m) :
  - 1ʳᵉ : environ 20,6 kN ;
  - 2ᵉ : environ 14,1 kN ;
  - 3ᵉ : environ 10,6 kN.
- **Adhérence de l'essieu arrière** : environ 10,4 kN à l'arrêt (1 450 kg × 58 % × 9,81 × 1,26), un peu plus avec le
  transfert de charge à l'accélération.

Le patinage en 1ʳᵉ et en 2ᵉ est donc **cohérent** pour une propulsion de 475 kW sans antipatinage. Ce n'est pas un
défaut de calcul.

### Brio (traction, différentiel avant ouvert)

| Option | 0–100 km/h | Roue intérieure qui patine, virage à 20 km/h | Idem à 40 km/h |
|---|---|---|---|
| **Actuel** | 13,61 s | 1,92 s (l'essieu entier : 0 s) | 1,54 s |
| Antipatinage actif | 13,61 s | 0,29 s | 0,10 s |
| Rampe clavier de 1,0 s | 14,07 s | 1,57 s | 1,55 s |
| Autobloquant avant (0,3 / 20 N·m) | 13,61 s | 2,46 s | 0,12 s |

La Brio ne patine jamais en ligne droite. En virage serré, accélérateur à fond, la roue avant intérieure se déleste et
patine seule : c'est le comportement attendu d'un différentiel ouvert. Elle ne part pas en glissade : sa dérive est de
5° à 40 km/h. La dérive de 18° relevée à 20 km/h vient de la géométrie du braquage à fond à basse vitesse, pas d'une
glissade.

## 3. Options

| # | Option | Effet mesuré | Conformité | Coût |
|---|---|---|---|---|
| A | **Statu quo**. Le son tolère déjà le patinage (AUDIO-03) | Comète : tête-à-queue dès qu'on accélère en braquant, patinage au départ | Conforme | Aucun |
| B | **Antipatinage actif au départ** pour les modèles qui en sont équipés (ABS et ESP inchangés, ou les trois aides) | Comète : 0–100 plus rapide (4,19 s contre 4,49 s), plus de tête-à-queue ; Brio : patinage de la roue intérieure ramené à 0,1–0,3 s. Toujours désactivable (touche **2**) | **Écart** à la ligne 55 (« état par défaut désactivé ») : amendement à inscrire dans `docs/AMENDEMENTS_CAHIER_DES_CHARGES.md` | Petit : `VehicleService.assignDriver`, HUD, tests et rapport |
| C | Accélérateur plus progressif au clavier (rampe de 1,0 s au lieu de 0,2 s) | Presque aucun effet : la Comète patine encore 3,30 s et part en tête-à-queue | Conforme (comme A2) | Petit, mais rend toutes les voitures plus molles au démarrage |
| D | Différentiel modifié (Comète : autobloquant renforcé ; Brio : autobloquant avant) | Comète : aucun effet (les deux roues patinent) ; Brio : effet à 40 km/h seulement | Change la définition du véhicule (nouvelle référence d'égalité) | Moyen, et peu réaliste pour une citadine |
| E | **Signalement** : avis au HUD la première fois qu'un essieu patine franchement avec l'antipatinage coupé (« Antipatinage désactivé — touche 2 ») | Ne change pas la conduite ; le joueur apprend à l'activer | Conforme (information, pas une aide) | Petit : un texte au HUD par clé de traduction, des tests |

Exclue d'office : une limite cachée de l'accélérateur au clavier selon le patinage. Ce serait une « assistance
universelle cachée », interdite par la ligne 55.

## 4. Recommandation

1. **E tout de suite.** Le signalement est conforme et sans effet sur la physique, et il répond au ressenti « ça patine
   dès que j'accélère ».
2. **B à décider par le propriétaire.** C'est la seule option mesurée qui supprime les tête-à-queue de la Comète.
   Elle demande un amendement explicite de la règle « aides désactivées par défaut ». Une variante plus restreinte est
   possible : antipatinage actif au départ pour les modèles de plus de 300 kW seulement.
3. **C et D ne sont pas recommandées** : leur effet mesuré est faible ou nul.

## 5. Non vérifié

- Tout le comportement **dans Roblox** : les chiffres viennent du banc planaire, qui remplace le moteur physique de
  Roblox par un châssis plan.
- Le ressenti au **clavier** et à la **manette** : avec la manette, l'accélérateur est proportionnel et le patinage
  peut se doser.
- Les **autres modèles** du jeu (seules la Brio et la Comète ont été mesurées).

## 6. Décision et réalisation (2026-11-06)

**Décision du propriétaire : « E puis B ».** L'amendement **A-02** est consigné dans
`docs/AMENDEMENTS_CAHIER_DES_CHARGES.md`.

| Option | Réalisation |
|---|---|
| **E — avis** | Module pur `src/shared/Vehicles/SpinNotice.luau`. L'avis apparaît quand une roue motrice dépasse 3 fois le pic d'adhérence pendant 0,3 s, avec l'antipatinage équipé mais coupé. Il est montré **une fois par session**, pour le véhicule simulé par ce joueur (`VehicleController`). Texte par clé `TractionSpinAidOff`, en français et en anglais (`Localization`). Aucune commande n'est modifiée |
| **B — antipatinage actif au départ** | Table `Constants.AidsOnAtStart = { TractionControl = true }`. `VehicleService.assignDriver` active l'aide seulement si le modèle en est équipé. ABS et ESP restent désactivés au départ, et tout reste réglable par le joueur |

Tests :
- `tests/lune/specs/Patinage.luau`, 4 tests. Sur le banc planaire, au départ arrêté à fond, la Comète affiche l'avis
  à 0,59 s sans antipatinage, et aucun avis avec.
- Le test Studio `Lot02Client` attend désormais l'antipatinage actif au départ (`client.aides_etat_par_defaut`).
  Ce test n'a **pas** été exécuté : les essais Studio sont faits par le propriétaire.
- `scripts\verify.ps1 -DownloadRobloxTypes` (2026-11-06, branche `feat/proposition-patinage`) : toutes les étapes
  OK, Lune 435 réussis sur 435, pytest 23 sur 23.

Place de test : `build/AW-PATINAGE.rbxlx`. Elle est construite depuis cette branche, qui ne contient **pas** les sons de
pneus d'AUDIO-03.

### Liste de vérification en jeu (propriétaire)

1. Monter dans la **Comète** : le HUD indique l'antipatinage **activé**, l'ABS et l'ESP désactivés.
2. Accélérer à fond à l'arrêt, puis en braquant à fond vers 30 km/h : peu de patinage, pas de tête-à-queue.
3. Couper l'antipatinage (touche **2**), puis accélérer à fond à l'arrêt. Le message « Les roues patinent :
   l'antipatinage est désactivé (touche 2, ou réglages à la croix sur manette). » apparaît une fois. Il ne réapparaît
   pas pendant cette session de conduite.
4. Sortir puis remonter : l'antipatinage est de nouveau **activé**.
5. **Brio** : antipatinage activé au départ. En virage serré à fond, la roue intérieure patine peu.

### Validation en jeu (2026-11-06)

Le propriétaire a d'abord essayé `build/AW-PATINAGE.rbxlx` et a signalé : « quand je dérape j'ai pas le bruit ». La cause
est que cette place, construite depuis cette branche, ne contient pas les sons de pneus d'AUDIO-03. Une place commune
a donc été construite :
- branche locale d'essai `test/audio03-patinage`, commit b5a791c, qui fusionne AUDIO-03 et cette branche ;
- `verify.ps1 -DownloadRobloxTypes` : toutes les étapes OK, Lune 443 sur 443 ;
- place `build/AW-AUDIO-03-PATINAGE.rbxlx`.

Réponse du propriétaire sur cette place : **« Oui, c'est bon »**. C'est un essai humain du propriétaire ;
l'assistant n'a exécuté aucun essai Studio. La validation porte sur l'ensemble (antipatinage au départ, avis, sons en
glissade), sans détail point par point de la liste ci-dessus.
