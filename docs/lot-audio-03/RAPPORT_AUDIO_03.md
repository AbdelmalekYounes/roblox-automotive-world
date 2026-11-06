# Rapport du lot AUDIO-03 — sons des pneus

Branche : `claude/audio-03-pneus-ba577d` (worktree, depuis `main` 6a54046). Rapport rédigé le 2026-11-06.
Le déroulement complet est dans [PLAN_AUDIO_03.md](PLAN_AUDIO_03.md) ; le registre des sources est dans
[docs/audio/SONS_TIERS.md](../audio/SONS_TIERS.md), § 2.

Demande du propriétaire (2026-11-06) : « ajouter des sons liés aux pneus (frottement avec le sol, crissement lors de
dérapage etc.) ». Lot mené en parallèle de BRIO-02 et CAMERA-01, sur une exception accordée par le propriétaire.

## 1. Décisions du propriétaire (2026-11-06)

| Id | Décision |
|---|---|
| Q1 | Revêtements : sec, mouillé et meuble (gravier, terre, herbe, sable, neige), plus le crissement sur le dur |
| Q2 | Pneus des autres joueurs : glissement déclaré par le conducteur, borné par le serveur, publié en attribut |
| Q3 | Tous les véhicules, mêmes sons, ajustés par la masse |
| Q4 | Volume réglé par la catégorie « Effets » ; sons étouffés en vue cockpit |

## 2. Livré

| Élément | Fichiers |
|---|---|
| Modèle sonore pur, testé par Lune | `src/shared/Audio/TireAudioModel.luau` |
| Matériau sous chaque roue (son seulement, aucun effet sur l'adhérence) | `VehicleTypes`, `VehicleSimulator` |
| Résumé des roues à chaque image, pour le véhicule conduit | `VehicleController`, `DevHud` |
| Glissement et revêtement transmis (7ᵉ et 8ᵉ valeurs, contrôle de contexte au serveur) | `InputCodec`, `VehicleService`, `VehicleConstants` |
| Lecture : véhicule conduit à chaque image ; véhicules observés avec Doppler ; égaliseur d'habitacle sur « Effets » | `src/client/Audio/AudioController.luau` |
| 6 sons au manifeste, avec les identifiants Roblox envoyés par le propriétaire | `AssetManifest` (table `TIRE_SOUND_IDS`) |
| Outil de transformation (numpy seul) et relevé de la dynamique | `tools/audio/tire_loops.py`, `tests/lune/tools/tire-sound-trace.luau` |
| Tests | `tests/lune/specs/Audio03.luau` (7 tests), `tests/test_audio03.py` (6 tests), exceptions dans `Lot08Content` et `test_lot08.py` |

Les six sons :

| Ressource | Identifiant Roblox | Source (CC0) |
|---|---|---|
| `audio.effect.tire.roll.dry` | 90291890857090 | Nissan Leaf, Eelke (170421) |
| `audio.effect.tire.roll.loose` | 79688428452888 | gravier, UnplugTheFridge (529225) |
| `audio.effect.tire.roll.wet` | 109725784350976 | chaussée mouillée, Breviceps (462862) |
| `audio.effect.tire.squeal` | 108267751330014 | crissement en virage, audible-edge (71738) |
| `audio.effect.tire.scrub` | 79292953985747 | patinage, audible-edge (71740) |
| `audio.effect.tire.slide.loose` | 112587939989359 | gravier, UnplugTheFridge (529225) |

## 3. Exécuté et mesuré

| Date | Contrôle | Résultat |
|---|---|---|
| 2026-11-06 | `scripts\verify.ps1 -DownloadRobloxTypes`, au commit c56b9c4 | Toutes les étapes OK ; Lune **417 réussis sur 417** ; pytest **29 sur 29** ; luau-lsp strict sans erreur |
| 2026-11-06 | Banc planaire (Brio, 80 → 0 km/h, pas de 1/240 s ; test Audio03 n° 7) | Sans ABS : crissement moyen 1,00. Avec ABS : 0,35 (plancher sonore). Roue libre : 0 |
| 2026-11-06 | Mesure des boucles par l'outil (`rapport.json`) | Raccords de 0,30 à 5,9 dB, creux maximaux de 1,1 à 6,6 dB (détail dans SONS_TIERS § 2) |
| 2026-11-06 | Relevé des identifiants : Lune, propriété `AudioContent` de `aw-vm-exchange/audio03_pneus.rbxm` (SHA-256 `ec5e12f0…`) | 6 objets Sound, 6 identifiants distincts, noms conformes (`tire_<nom>`) |
| 2026-11-06 | Fusion de `origin/main` d295473 (BRIO-02 et CAMERA-01) au commit fba478c, puis `verify.ps1 -DownloadRobloxTypes` | Un seul conflit, `tests/lune/run.luau` (toutes les suites gardées). Toutes les étapes OK ; Lune **438 réussis sur 438** ; pytest 29 sur 29 ; luau-lsp strict sans erreur ; test Audio03 n° 7 inchangé |
| 2026-11-06 | **Essai humain d'écoute** par le propriétaire de `ecoute_boucles.wav` et `demo_pneus.wav` | « C'est bon ». C'est une écoute de fichiers, pas un essai en jeu |

Place de test : `build/AW-AUDIO-03.rbxlx`, reconstruite par `rojo build default.project.json -o build/AW-AUDIO-03.rbxlx`
après la fusion de main (commit fba478c). Elle contient donc aussi BRIO-02 et CAMERA-01. Son nom distinct évite
qu'elle soit écrasée par `verify.ps1`.

## 4. Non vérifié

- **Tout le rendu en jeu** : l'assistant n'a lancé aucun essai Studio. La vérification revient au propriétaire (§ 5).
- **Charge réseau** des deux valeurs ajoutées à la commande. L'envoi n'a lieu que si une valeur change, au plus
  `InputSendRateHz` fois par seconde, comme avant.
- **Démos** : elles ont été calculées sur le banc planaire, sans le moteur et sans le moteur physique de Roblox.

## 5. Liste de vérification en jeu (propriétaire)

Ouvrez `build/AW-AUDIO-03.rbxlx` dans Studio et lancez « Jouer » (environnement Dev). Prenez la Brio par le menu
d'administration (F2) ou par la concession, puis montez à bord. Réglez le volume « Effets » au maximum
(Téléphone › Paramètres).

1. **Arrêt** : à l'arrêt, aucun bruit de pneu.
2. **Roulement** :
   - le bruit de roulement apparaît dès quelques km/h ;
   - il monte avec la vitesse, sans coupure ni « tic » répété toutes les 2 s.
3. **Virage** (version 3, voir § 6). Toutes les aides sont **coupées** au début de chaque session de conduite :
   - virages au clavier jusqu'à 60 km/h, même en braquant à fond et en gardant l'accélérateur : **aucun
     crissement** ;
   - vers 90–100 km/h, braquer à fond : l'avant glisse franchement, un crissement apparaît.
4. **Freinage fort avec ABS** (l'activer d'abord avec la touche **1**) :
   - vers 80 km/h, freiner à fond (**S**) ;
   - on entend un grondement saccadé, pas un crissement continu.
5. **Freinage sans ABS** :
   - ABS coupé (état de départ, ou touche **1**), puis freiner à fond vers 50 km/h ;
   - gros crissement de roues bloquées jusqu'à l'arrêt.
6. **Frein à main** (**Espace**) en roulant, ou en virage : glissade audible.
7. **Départ sans antipatinage** (état de départ ; la touche **2** l'active) : accélérer à fond à l'arrêt. Sur le banc
   planaire, la Brio patine à peine : un crissement bref ou absent est attendu.
8. **Pluie** :
   - menu d'administration (F2) › météo « Pluie » ;
   - en roulant, on entend un chuintement d'eau ;
   - en freinant fort, le crissement est nettement plus faible.
   - Remettre ensuite « Sec ».
9. **Herbe ou gravier** (si la carte de test en a ; sinon, point à marquer « non testé ») :
   - hors de la route, le roulement devient un crépitement plus sourd ;
   - en freinant fort, on entend une glissade de gravier, sans crissement.
10. **Vue cockpit** (**V**) : les pneus sont plus étouffés et plus graves. Ils redeviennent normaux en vue extérieure.
11. **Réglages** : le volume « Effets » règle les pneus. Le volume « Moteur » ne les change pas.
12. **À deux joueurs** (Studio : Test › Clients et serveurs, 2 joueurs) :
    - les pneus de la Brio de l'autre joueur s'entendent : roulement, crissement en virage et au freinage, effet
      Doppler au passage ;
    - une voiture garée immobile est silencieuse.
13. **Comète** (version 4, voir § 6) : à fond en ligne droite une fois lancée, presque aucun crissement ; départ
    arrêté à fond ou tête-à-queue : crissement. Ses pneus sont un peu plus forts et plus graves (masse 1 450 kg).
    Son moteur reste muet
    (décision « la Brio d'abord » d'AUDIO-01).

## 6. Correction après le premier essai en jeu (2026-11-06)

Retour du propriétaire sur la place de test : « le bruit des crissements se fait à peine les roues tournées ; il faut
que ça soit le cas uniquement lorsque le véhicule perd l'adhérence ».

**Cause, mesurée sur le banc planaire (Brio, vitesse tenue, braquage amené en 0,5 s).** En version 1, le crissement
commençait à 0,7 fois le pic d'adhérence, donc avant que le pneu glisse. Or, au clavier, le braquage est tout ou rien,
et l'avant dépasse vite son pic de dérive :
- à 20 km/h roues braquées à fond : dérive avant de 9,7° (pic 7°) et crissement de 0,12 ;
- ce niveau est presque aussi fort que le roulement à cette vitesse, donc il s'entend dans chaque virage serré.

**Correction (version 2 du modèle, `TireAudioModel`)** :
- utilisation du pneu = glissement combiné rapporté au pic ; le crissement commence à **1,25 fois le pic** et il est
  plein à 4 fois ;
- part latérale ignorée sous 15 km/h, pleine au-dessus de 25 km/h ; le blocage et le patinage restent audibles à
  toute vitesse ;
- vitesse de glissement minimale relevée de 0,4 à 1 m/s ;
- volume du crissement proportionnel à l'intensité puissance 1,5 : un début de glisse reste discret.

Les sons envoyés sur Roblox ne changent pas.

**Mesure après correction (banc planaire, test Audio03 n° 8) :**
- aucun crissement à 10 et 20 km/h roues braquées à fond, ni à 40 km/h à mi-braquage, ni à 60 km/h jusqu'à
  mi-braquage ;
- roues braquées à fond à 80 km/h, l'avant glisse : crissement de 0,45 ;
- freinage roues bloquées et ABS inchangés (test n° 7).

`verify.ps1 -DownloadRobloxTypes` (2026-11-06) : toutes les étapes OK, Lune 439 sur 439. La place
`build/AW-AUDIO-03.rbxlx` a été reconstruite. Le point 3 de la liste du § 5 est à revérifier en jeu : en virage
normal, aucun crissement ; il n'apparaît qu'en glissade (braquage brutal à vitesse élevée, frein à main, blocage).

### Version 3 (second essai en jeu, 2026-11-06)

Retour du propriétaire sur la version 2 : « c'est toujours pareil ».

**Causes, mesurées sur le banc planaire.** Conditions : Brio, aides coupées comme au départ d'une session, braquage
d'un coup comme au clavier.
1. **Patinage de la roue intérieure.** Accélérateur enfoncé en braquant à fond, la roue avant intérieure patine
   seule, de 20 à 40 km/h (glissement de 16 à 27 fois le pic). Le crissement atteignait 0,71 alors que la voiture
   tourne normalement.
2. **Sous-virage dans chaque virage serré.** Au clavier, l'avant dépasse son pic de dérive à chaque virage serré, de
   3,4 à 4,2 fois de 30 à 60 km/h. La voiture tourne moins, mais elle ne glisse pas pour le joueur.
3. **Écart entre le banc et le jeu.** Le banc donnait aux roues avant la vitesse latérale de la caisse. En jeu, c'est
   la vitesse latérale de chaque roue braquée, bien plus forte, donc le crissement s'y déclenchait davantage. La vitesse
   de glissement latérale est désormais tirée de l'angle de dérive (|vx| × tan α), identique en jeu et sur le banc.

**Correction.** Le crissement est réservé à la perte d'adhérence du **véhicule** :
- **glissement longitudinal d'un essieu**, c'est-à-dire de ses deux roues : démarrage en patinage, roues bloquées. Une
  roue intérieure qui patine seule ne crisse plus ;
- **dérive de l'arrière** (dérapage, frein à main), dès 15 km/h ;
- **dérive de l'avant** (sous-virage franc) seulement de 50 à 90 km/h et plus.

**Mesure après correction (banc planaire, tests Audio03 n° 2 et n° 8)** :

| Situation | Crissement |
|---|---|
| Braquage à fond de 20 à 60 km/h, accélérateur relâché ou enfoncé | aucun |
| 40 km/h à mi-braquage | aucun |
| 80 km/h, braquage à fond | 0,30 |
| 100 km/h, braquage à fond | 0,82 |
| Frein à main en virage à 40 km/h | 1,00 |
| Freinage roues bloquées, ABS | inchangés |

### Version 4 : Comète, patinage toléré (2026-11-06)

Précision du propriétaire : « en fait c'est sur la Comète que ça fait ça ».

**Mesure sur le banc planaire.** Conditions : Comète (propulsion, 475 kW), aides coupées comme au départ d'une
session, accélérateur à fond comme au clavier. Le crissement correspondait à un vrai patinage des roues arrière :
- en ligne droite, de 20 à 60 km/h : glissement de 6 à 18 fois le pic d'adhérence ;
- au départ arrêté : 51 fois le pic ;
- avec l'antipatinage (touche **2**) : environ 2 fois le pic.

**Décision du propriétaire, après présentation des deux voies : « Son plus tolérant ».**

**Correction.** Le patinage (roue plus rapide que le sol) n'est audible qu'au-delà de **8 fois** le pic, et il est
plein à **40 fois**. Le blocage au freinage garde les seuils communs (1,25 à 4 fois).

**Mesure après correction (test Audio03 n° 8)** :
- Comète à fond sans antipatinage :
  - départ arrêté : crissement maximal 1,00, moyen 0,45 (démarrage en force) ;
  - lancée à 20 km/h : moyen 0,09 ;
  - lancée à 40 km/h : moyen 0,01 ;
- avec l'antipatinage : 0 ;
- Brio : muette dans tous ces cas, comme en version 3.

**Limite connue.** Sans antipatinage, braquer à fond en accélérant fait partir l'arrière de la Comète en
tête-à-queue (dérive arrière d'environ 10 fois le pic). Ce cas crisse toujours, car c'est une vraie perte
d'adhérence de la voiture.

## 7. Écarts et limites

- **Physique, hors périmètre** : dans la dynamique, la roue avant intérieure de la Brio patine dès qu'on accélère en
  braquant à fond, même à 20 km/h, quand l'antipatinage est coupé (c'est l'état de départ). Le son l'ignore désormais.
  Le comportement physique lui-même reste à arbitrer par le propriétaire.

- **Glissade sur gravier** : aucune vraie glissade sur gravier n'a été trouvée dans les enregistrements lisibles. Le
  n° 10 (FLAC) ne peut pas être décodé sans dépendance hors numpy. Le son vient d'un passage plus dense du gravier.
- **Plancher sonore de l'ABS** (0,35) : c'est un choix de conception. La physique seule rendrait le freinage avec ABS
  presque muet.
- **Changement hors du dossier audio** : un champ `Material` a été ajouté au contact des roues (`VehicleTypes`,
  `VehicleSimulator`). Il sert au son seulement et ne modifie pas l'adhérence.
- **Fichiers partagés** : seulement des ajouts, dans une section au nom du lot (`AssetManifest`, `tests/lune/run.luau`,
  `SONS_TIERS.md`). Deux contrôles existants ont été adaptés : la liste exacte des identifiants dans `test_lot08.py`
  et l'exception de comptage dans `Lot08Content`. `Localization.luau` n'a pas été touché : aucun texte joueur ajouté.
- Le crissement synthétique `audio.effect.skid` du lot 0.8 reste au manifeste, inchangé et non utilisé.
