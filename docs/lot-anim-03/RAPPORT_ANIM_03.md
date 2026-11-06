# Lot ANIM-03 — Gestes d'entrée et de sortie du véhicule

- Date : 2026-11-06.
- Branche : `feat/anim-03-entree-sortie`, créée depuis `origin/main` `1037a9a` (ANIM-02, PHONE-01 et AUDIO-04 fusionnés).
  Rien n'est poussé.
- Demande du propriétaire, transmise par la coordination, citée : « il faut revoir l'animation d'entrée et sorti de
  vehicule, pour l'instant on dirait que le personnage se fait aspirer par la voiture pour rentrer dedans, il faut
  animer tous les mouvements comme dans la vraie vie ».
- **État : code terminé et vérifié hors Studio ; À ESSAYER EN JEU par le propriétaire (§7).** Rien n'a été essayé en
  jeu. Aucun maillage ni actif à envoyer : tout est en code.

## 1. Décisions du propriétaire (2026-11-06, posées en une fois au début du lot)

| Question | Décision |
| --- | --- |
| Durée de l'entrée (marche jusqu'à la porte non comprise) | **≈ 2,5 s** ; sortie un peu plus courte (2,2 s). |
| Touche pour passer l'animation | **Non** : l'animation se joue toujours en entier. |
| Caméra pendant l'animation | **3e personne qui suit** : pendant l'entrée, caméra à pied derrière le personnage, puis vue de conduite choisie une fois installé ; à la sortie, vue de conduite jusqu'à l'ouverture de la porte, puis caméra à pied. |
| Le conducteur démarre pendant que le passager monte ou descend | **Départ bloqué** : le véhicule ne démarre pas tant que la séquence du passager n'est pas finie. |

Annoncé avant les questions, sans objection : animation entièrement en code (poses originales par images clés sur les
articulations, cinématique inverse), aucune animation importée ni envoyée ; commandes de conduite bloquées pendant
l'animation ; téléphone rangé au début.

## 2. Principe : déplacement continu, aucune téléportation

Le lot ANIM-02 faisait glisser le corps en ligne droite de la porte au siège en 0,5 s (« aspiré »). ANIM-03 le
remplace par une suite de gestes :

- Pendant toute la séquence, le personnage est **assis** : son `HumanoidRootPart` reste soudé au siège, donc la
  physique est stable et le véhicule ne bouge pas. Son **corps visible** est placé par l'articulation `Root`, le long
  d'un **trajet continu** : courbe de Hermite par des positions clés, avec des tangentes de Catmull-Rom. La vitesse est
  continue, nulle au départ et à l'arrivée.
- Le trajet d'entrée **part de la position réelle** du personnage debout à la porte (relevée par le serveur au début).
  Le trajet de sortie **arrive au point où le serveur le dépose**.
- Buste, cou, hanches et genoux suivent des **poses clés** adoucies.
- La main qui tient une poignée est placée par **cinématique inverse** (`ArmIk`, lot ANIM-01). Sa cible est la poignée
  **sur la porte à son angle de l'image** : la porte et la main avancent ensemble.
- **Une seule horloge** : le serveur publie la séquence (attribut texte `AWEmbarquement` du personnage : genre, place,
  porte, début en temps du serveur, point, cap). Chaque client calcule la même image : les autres joueurs voient les
  mêmes gestes, sans réplication par image.

### 2.1 Entrée (2,5 s après la marche jusqu'à la porte)

| t (s) | Geste | Porte |
| --- | --- | --- |
| marche (≤ 1 s) | Le personnage marche jusqu'au point de la porte, un peu en arrière de la poignée. | fermée |
| 0 → 0,35 | Il tend la main (côté poignée) vers la poignée extérieure ; buste légèrement penché. | fermée |
| 0,35 → 0,8 | Il tire la porte en reculant ; la main tient la poignée jusqu'à 0,6 s, puis la lâche ; il regarde vers l'ouverture. | s'ouvre |
| 0,8 → 1,3 | Il se tourne dos à l'habitacle, plie les genoux, baisse la tête et le buste. | ouverte |
| 1,3 → 1,75 | Il engage la première jambe (côté habitacle) dans l'habitacle, le bassin au-dessus du seuil. | ouverte |
| 1,75 → 2,05 | Il s'assoit, encore tourné vers la porte ; la seconde jambe est dehors. | ouverte |
| 1,95 → 2,3 | Il rentre la seconde jambe en se tournant face à la route, et tend la main côté porte vers la poignée intérieure. | ouverte |
| 2,15 → 2,5 | Il tire la porte jusqu'à la fermeture, la main sur la poignée. | se ferme |
| 2,5 → 2,8 | Fondu vers la pose assise des lots ANIM-01 et BRIO-02 : mains au volant (conducteur), pose « Citadine » ou « Sportive ». | fermée |

### 2.2 Sortie (2,2 s)

| t (s) | Geste | Porte |
| --- | --- | --- |
| 0 → 0,3 | Fondu depuis la pose assise ; main côté porte sur la poignée intérieure. | fermée |
| 0,25 → 0,7 | Il pousse la porte (main lâchée à 0,6 s). | s'ouvre |
| 0,7 → 0,95 | Il pivote vers la porte ; premier pied (côté porte) au sol. | ouverte |
| 0,95 → 1,15 | Second pied au sol, buste penché. | ouverte |
| 1,15 → 1,7 | Il se relève en baissant la tête et sort de l'habitacle. | ouverte |
| 1,55 → 2,2 | Debout dehors, il prend la poignée extérieure et referme la porte ; il arrive au point de dépôt, face à l'avant. | se ferme |
| 2,2 | Siège libéré, personnage déposé là où son corps est arrivé. | fermée |

Les deux véhicules ont la même chorégraphie, avec des réglages par porte (`MeshKitData`, champ `Doors`) :
- **Brio** : poignée extérieure mesurée (−2,80 ; 1,03 ; 2,09) ; poignée intérieure sur le panneau ; recul de 0,35 st
  (la porte s'ouvre vers le personnage) ; buste penché de 28°.
- **Comète** : pas de poignée visible sur le modèle, donc la main prend la porte à l'arrière (−3,25 ; 1,05 ; −0,45) ;
  presque aucun recul (la porte monte) ; buste penché de 40° (pavillon bas, seuil large).

## 3. Fonctionnement

- **Serveur** (`src/server/Vehicles/DoorService.luau`, réécrit ; appelé par `VehicleService`) :
  - Montée (invites « Conduire » et « Monter (passager) ») : place réservée, marche du client jusqu'au point de la
    porte (`Humanoid:MoveTo`, 1 s au plus), **toutes les règles revalidées**, séquence publiée, personnage assis.
  - Ouverture et fermeture de la porte publiées aux instants du calendrier (attribut texte du modèle, ANIM-02).
  - Sortie : point de dépôt choisi en arrière de la porte ouverte, hors de son balayage (sinon la porte ouverte
    traverserait le personnage). Pieds au sol (rayon vers le bas), place libre. Côté de la place, sinon l'autre côté
    (« autre porte si côté bloqué », ANIM-02). Aucun côté possible : sortie immédiate, comme avant.
  - À la fin de la sortie, dépôt exact à ce point (`exitPivotOverride`, placement vérifié existant).
  - **Interruptions** : véhicule détruit, joueur parti (personnage retiré), personnage mort, personnage sorti du
    siège par un autre chemin. La séquence s'arrête, la porte se referme, les attributs sont retirés.
  - **Départ bloqué** : attribut `AWDepartBloque` du modèle tant qu'une séquence de passager est en cours.
- **Client** :
  - `BoardingAnimator` (nouveau) : pose de chaque articulation à l'image (corps, buste, cou, hanches, genoux, bras ;
    main sur la poignée).
  - `SeatPoseController` (ANIM-01) l'applique **par-dessus la pose assise**, avec le poids de la séquence, puis la pose
    assise et les mains au volant reprennent en fondu. Le glissé d'ANIM-02 est supprimé.
  - `DoorVisuals` : angle de la porte tiré de la séquence pendant une séquence (même horloge que la main), sinon de
    l'état répliqué. Pour le joueur local : marche jusqu'à la porte ; téléphone rangé au début
    (`UIManager.close("Phone")`, PHONE-01 non modifié) ; caméra par défaut sur la **tête** (corps visible) pendant la
    séquence ; saut intercepté pendant la séquence ; personnage posé au point de dépôt dès que le siège est libéré.
  - `BoardingLock` (nouveau), appelé par `VehicleController` : commandes neutres et frein à main pendant la séquence du
    conducteur et pendant celle d'un passager (départ bloqué) ; caméra du véhicule suspendue selon la décision du
    propriétaire, puis reprise sur la vue de conduite choisie (FreeLook de CAMERA-01 inchangé).

## 4. Fichiers

Nouveaux :
- `src/shared/Vehicles/BoardingMotion.luau` (pur : calendrier, trajet, poses, mains, porte, codage) ;
- `src/client/Vehicles/BoardingAnimator.luau`, `src/client/Vehicles/BoardingLock.luau` ;
- `tests/lune/specs/Anim03.luau` (6 tests) ;
- `docs/lot-anim-03/RAPPORT_ANIM_03.md`.

Modifiés :
- `src/shared/Vehicles/Doors.luau` : poignées et réglages du geste ; glissé et calendrier d'ANIM-02 retirés ;
- `src/shared/Vehicles/MeshKitData.luau` : poignées et réglages des deux kits ;
- `src/server/Vehicles/DoorService.luau` : séquences réécrites ;
- `src/server/Vehicles/VehicleService.luau` (**fichier commun**) : section des portières (`boardOrSit`,
  `alightOrRelease`, `exitStand`), point de dépôt imposé dans `placeBeside` ;
- `src/client/Vehicles/SeatPoseController.luau` : gestes à la place du glissé ;
- `src/client/Vehicles/DoorVisuals.luau` : porte suivant la séquence, téléphone, caméra, dépôt ;
- `src/client/Vehicles/VehicleController.luau` (**fichier commun**) : `require` de `BoardingLock` et 2 appels marqués
  « Lot ANIM-03 » ;
- `tests/lune/specs/Anim02.luau` : tests du glissé (4 et 5) remplacés par ceux d'ANIM-03 ; `tests/lune/run.luau` :
  1 ligne.

Non modifiés : audio et `tools/audio` (AUDIO-02), carte et ville (MAP-01), `PhoneController.luau`, `VehicleCamera.luau`,
`DamageService.luau`, `README.md`, `docs/ROADMAP.md`, `docs/QA_BACKLOG.md`, `docs/CREDITS_ACTIFS.md`.

## 5. Vérifications exécutées (2026-11-06)

| Commande | Résultat |
| --- | --- |
| `scripts\verify.ps1 -DownloadRobloxTypes` (terminé à 14:33, après toutes les modifications) | Rojo, Selene (0 erreur, 0 avertissement), pilote Studio, StyLua, Lune **482 réussis, 0 échoué** (dont 6 tests ANIM-03), carte, place monde ouvert, pytest 33 réussis, luau-lsp strict 0 erreur (3 avertissements `DeprecatedApi` antérieurs, hors lot) : tout OK. |
| `rojo build default.project.json -o build/AW-ANIM-03.rbxlx` (14:33) | Place de test construite (3,52 Mo). |
| `scripts\verify.ps1 -DownloadRobloxTypes` (16:39, après la correction du §8) | Premier passage (16:38) : seul StyLua en échec (mise en forme du nouveau test), corrigé par `stylua`. Second passage : tout OK, Lune **483 réussis, 0 échoué** (dont le test 7 ANIM-03), pytest 33, luau-lsp strict 0 erreur. |
| `rojo build default.project.json -o build/AW-ANIM-03.rbxlx` (16:39) | Place de test reconstruite (3,52 Mo). |

Deux passages précédents de `verify.ps1` ont échoué au typage strict, puis ont été corrigés : rôles élargis en
`string` au décodage, table indexée par une valeur facultative, comparaison `CFrame ~= nil`. Un défaut relevé à la
relecture est aussi corrigé : une expression `if … then f() else nil, nil` ne gardait qu'une valeur, et la main n'aurait
jamais visé la poignée.

Tests ANIM-03 (Lune) :
1. minutage : 2,5 s et 2,2 s, phases dans l'ordre, porte ouverte puis refermée sans retour en arrière ;
2. main et porte synchronisées : main sur la poignée avant que la porte ne bouge, tenue pendant toute la fermeture ;
   cible de la main = poignée tournée avec la porte, à chaque instant ; main du bon côté ;
3. trajet continu, pour les deux véhicules, les deux portes, l'entrée et la sortie : départ à la position réelle,
   arrivée au siège (ou au point de dépôt), au plus 0,1 st et 0,06 rad par 1/120 s (aucune téléportation) ;
4. poses : debout au départ, une jambe engagée avant l'autre, buste et tête baissés, assis à la fin ; à la sortie, un
   pied avant l'autre, debout à la fin ; Comète plus penchée que la Brio ;
5. séquence : codage et refus des textes invalides, conduite bloquée pendant toute la séquence, caméra selon la
   décision, fondus, fin ;
6. câblage : serveur autoritaire, interruptions, départ bloqué, commandes et caméra, téléphone, aucune animation
   importée.

Le premier passage du test 3 a échoué : demi-tour de près de 180° en 0,5 s à l'entrée (0,075 rad par image). Le regard
est désormais tourné vers l'ouverture dès la fin de l'ouverture de la porte : il ne reste qu'environ 100° à tourner.

## 6. NON TESTÉ, limites et risques

**Rien n'a été essayé en jeu** (règle du propriétaire : il teste lui-même). En particulier :
- **Conventions des articulations R15** : les signes des angles (hanche positive = cuisse vers l'avant, genou
  négatif = jambe pliée, buste et cou négatifs = penchés en avant) sont ceux de `SeatPose`, vérifiés en jeu aux lots
  0.x et BRIO-02. Les poses absolues (debout, assis à 88°) n'ont jamais été vues ; si une jambe part en arrière ou si le
  buste se renverse, c'est un signe à inverser.
- **Raccord avec la pose assise** : la pose assise de fin (hanches 88°, genoux −88°) est une estimation de l'animation
  assise du moteur. Le fondu de 0,3 s peut laisser voir un léger mouvement des jambes en fin d'entrée.
- **Traversées** : aucun calcul de collision des membres. Une jambe ou la tête peut traverser le seuil, le montant ou
  la porte, surtout sur la Comète (seuil large, porte en élytre) et avec de grands avatars. Les points clés sont
  estimés à partir des cotes du kit, pas mesurés sur les avatars.
- **Poignées** : Brio mesurée ; poignée intérieure de la Brio, poignées de la Comète **estimées**. La main peut viser
  quelques centimètres à côté.
- **Main sur la porte** : la porte s'ouvre plus loin que le bras ne porte. La main suit la poignée au début de
  l'ouverture puis la lâche ; à la fermeture depuis l'intérieur, le bras est tendu tant que la poignée est loin.
- **Marche jusqu'à la porte** : `Humanoid:MoveTo` sur le client ; une touche de déplacement peut l'interrompre. Au bout
  de 1 s, le trajet part de là où est le personnage (à 16 st au plus).
- **Départ bloqué** : appliqué par le client du conducteur (commandes neutres). Le serveur ne l'impose pas.
- **Véhicule poussé** pendant une séquence : la séquence continue (seuls véhicule détruit, joueur parti ou mort
  l'interrompent).
- **Téléphone** : rangé au début ; s'il est rouvert pendant la séquence, rien ne l'empêche (non vérifié avec
  PHONE-01).
- **Caméra** : la caméra par défaut suit la tête ; à l'entrée, elle passe à la vue de conduite à 2,5 s. Le raccord de
  CAMERA-01 (regard libre remis à zéro) n'est pas vérifié en jeu.
- Avatars R6 ou squelettes incomplets : pas de geste (le personnage reste assis sans animation, porte animée).
- Écran tactile : le bouton de saut du passager n'est pas intercepté (sortie immédiate, porte entrouverte, ANIM-02).

À reporter par la coordination dans `docs/QA_BACKLOG.md` : la liste du §7, NON TESTÉ en jeu.

## 7. Liste de vérification en jeu (propriétaire)

Place : `build\AW-ANIM-03.rbxlx`, 2 joueurs (Test › Serveur local). Faire chaque point sur la **Brio** et sur la
**Comète**.

1. **Entrée conducteur** (« Conduire » à quelques pas) : marche jusqu'à la porte, main à la poignée, porte tirée (elle
   suit la main), demi-tour, tête baissée, une jambe, assis, seconde jambe, porte tirée et fermée, mains au volant.
   Environ 2,5 s, sans saut ni « aspiration ». Caméra à pied pendant le geste, puis vue de conduite.
2. Pendant l'entrée, accélérer : le véhicule ne bouge pas avant la fin.
3. **Sortie conducteur** : main sur la poignée intérieure, porte poussée, pivot, un pied puis l'autre, se relève, sort,
   referme la porte de l'extérieur. Personnage debout à côté, sans saut. La caméra repasse à pied à l'ouverture de la
   porte.
4. **Passager** : refaire 1 et 3 côté passager (sortie avec Espace). Pendant ce temps, le conducteur ne peut pas
   démarrer.
5. **Vu par le 2e joueur** : mêmes gestes, porte et main ensemble.
6. Noter tout membre qui traverse la carrosserie, une jambe ou le buste dans le mauvais sens, une main loin de la
   poignée (véhicule, côté, entrée ou sortie, avatar).
7. Téléphone sorti avant de monter : il est rangé au début du geste.
8. Interruption : supprimer le véhicule (menu d'administration) ou quitter la partie pendant un geste ; aucune porte
   ne reste ouverte et le personnage n'est pas bloqué.

## 8. Retours de l'essai du propriétaire et corrections

### Essai 1 (2026-11-06, Brio, entrée passager)

Retour : « il fait l'anim assis après il reste debout et se remet assis pour entrer ». Capture : personnage assis par
terre devant la porte passager, jambes vers l'avant, main vers la poignée.

Cause : le personnage est sur le siège dès le début de la séquence, donc l'animation « assis » du moteur joue sur
toutes ses articulations. La chorégraphie ne remplaçait que les articulations citées dans les poses clés voisines : de
0 à 0,8 s (main à la poignée, ouverture), aucune pose clé ne citait les hanches, et plusieurs ne citaient pas les
genoux. Ces articulations restaient donc à l'animation assise : le personnage paraissait assis dehors, puis debout dès
1,3 s (demi-tour), puis assis au siège. Le même défaut touchait la fin de la sortie (1,7 à 2,2 s, en s'éloignant).
Le test 4 ne le voyait pas : il vérifiait seulement que les articulations renvoyées étaient au repos, et aucune ne
l'était.

Correction :
- `BoardingMotion.poseAt` renvoie toujours les six articulations génériques (`BoardingMotion.PoseJoints`), au repos si
  la pose ne les cite pas ;
- `BoardingAnimator.compute` part du repos pour toutes les articulations prises en charge, poignets compris (ajoutés à
  la liste) ;
- nouveau test Lune 7 : à 101 instants de chaque séquence, les deux véhicules, toutes les articulations sont posées ;
  jambes au repos devant la porte et en s'éloignant ; câblage du client vérifié.

**NON TESTÉ en jeu** après la correction : à refaire avec les points 1, 3 et 4 du §7. Chevilles non prises en charge
(l'animation assise du moteur peut encore les incliner légèrement).
