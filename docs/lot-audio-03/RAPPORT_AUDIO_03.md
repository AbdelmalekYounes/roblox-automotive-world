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
| 2026-11-06 | **Essai humain d'écoute** par le propriétaire de `ecoute_boucles.wav` et `demo_pneus.wav` | « C'est bon ». C'est une écoute de fichiers, pas un essai en jeu |

Place de test : `build/AW-AUDIO-03.rbxlx`, construite par `rojo build default.project.json -o build/AW-AUDIO-03.rbxlx`
au commit c56b9c4. Son nom distinct évite qu'elle soit écrasée par `verify.ps1`.

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
3. **Virage serré** :
   - vers 50–60 km/h, braquer à fond ;
   - un crissement apparaît à la limite d'adhérence, et disparaît en ligne droite.
4. **Freinage fort avec ABS** (ABS actif, touche **1** pour l'activer ou le couper) :
   - vers 80 km/h, freiner à fond (**S**) ;
   - on entend un grondement saccadé, pas un crissement continu.
5. **Freinage sans ABS** :
   - couper l'ABS (**1**), puis freiner à fond vers 50 km/h ;
   - gros crissement de roues bloquées jusqu'à l'arrêt.
6. **Frein à main** (**Espace**) en roulant, ou en virage : glissade audible.
7. **Départ sans antipatinage** : couper l'antipatinage (**2**), puis accélérer à fond à l'arrêt. Sur le banc
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
13. **Comète** : ses pneus s'entendent, un peu plus forts et plus graves (masse 1 450 kg). Son moteur reste muet
    (décision « la Brio d'abord » d'AUDIO-01).

## 6. Écarts et limites

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
