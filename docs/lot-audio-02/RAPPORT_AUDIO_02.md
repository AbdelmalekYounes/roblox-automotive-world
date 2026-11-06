# Rapport du lot AUDIO-02 — sons de moteur de la Comète

Branche : `feat/audio-02-comete` (depuis `main` 1037a9a). Rapport rédigé le 2026-11-06. Le déroulement complet
(mesures, sources écartées, choix) est dans [PLAN_AUDIO_02.md](PLAN_AUDIO_02.md), et le registre des sources dans
[docs/audio/SONS_TIERS.md](../audio/SONS_TIERS.md), § 4.

Demande du propriétaire (2026-11-06) : « ajouter le son moteur etc. de la Comète ».

## 1. Décisions du propriétaire (2026-11-06)

| Id | Décision |
|---|---|
| Q1 | Caractère : V8 « grand tourisme » |
| Q2 | Démarrage : démarreur de la 190E enchaîné sur le V8 |
| Q3 | Sifflement du turbo isolé dans l'enregistrement de la Supra au banc |
| Q4 | Boîte automatique « pour être fidèle à la McLaren 720S », dans ce lot : la Comète passe en **double embrayage** |
| Source | Pack « V8 Lotus » de wikusv (Freesound, **CC BY 4.0**) comme source principale, avec crédit en jeu (« Oui, le pack Lotus ») |
| Variante | **Micro B** (canal droit du pack), choisie à l'écoute des deux démos de conduite |

## 2. Livré

| Élément | Fichiers |
|---|---|
| Boîte à double embrayage (passages automatiques, reprise en main par Maj et Ctrl) | `src/shared/Vehicles/Definitions/Comete.luau` ; référence d'égalité régénérée ; tests `Veh3d01Comete` n° 10, `Lot08Content` n° 2 |
| Outil des boucles adapté au V8 (raie d'allumage = régime / 15) et aux WAV flottants ou multicanaux | `tools/audio/engine_loops.py` (profil `comete`), `tests/test_audio01.py` (2 tests ajoutés) |
| Profil sonore `wk_comete` : 7 régimes (900 à 6 000 tr/min), ralenti 850, rupteur 8 500, turbo et pétarades | `src/shared/Audio/EngineSoundProfiles.luau` |
| 20 sons au manifeste, avec les identifiants Roblox envoyés par le propriétaire | `AssetManifest` (table `COMETE_ENGINE_SOUND_IDS`) |
| Crédit en jeu de wikusv (CC BY 4.0) ; titre et lien masqués comme les crédits précédents | `Attributions` (champ facultatif `ManifestPrefix`), `Localization` (`credits.*.comete_moteur`) |
| Tests | `tests/lune/specs/Audio02.luau` (4), `tests/test_audio02.py` (3) ; exceptions dans `Lot08Content` n° 16 et `test_lot08.py` |

| Ressource | Identifiant Roblox | Source |
|---|---|---|
| `audio.engine.comete.on.900` | 83384498469427 | V8 Lotus (CC BY 4.0) |
| `audio.engine.comete.on.1300` | 100553872617727 | V8 Lotus |
| `audio.engine.comete.on.1850` | 85384338510920 | V8 Lotus (extrait en décharge, voir § 6) |
| `audio.engine.comete.on.2600` | 90690244574000 | V8 Lotus |
| `audio.engine.comete.on.3700` | 97894996462848 | V8 Lotus |
| `audio.engine.comete.on.5000` | 97980308427871 | V8 Lotus |
| `audio.engine.comete.on.6000` | 105297364249104 | V8 Lotus |
| `audio.engine.comete.off.900` | 120191647228722 | V8 Lotus |
| `audio.engine.comete.off.1300` | 105331659485512 | V8 Lotus |
| `audio.engine.comete.off.1850` | 131272682000973 | V8 Lotus |
| `audio.engine.comete.off.2600` | 119009401498330 | V8 Lotus |
| `audio.engine.comete.off.3700` | 128027842617189 | V8 Lotus |
| `audio.engine.comete.off.5000` | 140052785677863 | V8 Lotus |
| `audio.engine.comete.off.6000` | 94265877209550 | V8 Lotus (transposé × 1,19, voir § 6) |
| `audio.engine.comete.start` | 120993955265076 | démarreur de la 190E (Chippy569, CC0) puis reprise du V8 Lotus |
| `audio.engine.comete.stop` | 77261071295590 | V8 Lotus |
| `audio.engine.comete.stall` | 81322298159845 | V8 Lotus |
| `audio.engine.comete.turbo` | 103425012740677 | Supra au banc, editboy23 (CC0), sifflement isolé |
| `audio.engine.comete.blowoff` | 114657971551659 | même enregistrement, décharge |
| `audio.engine.comete.pops` | 108996350554637 | anti-lag, modusmogulus (CC0) |

## 3. Exécuté et mesuré

| Date | Contrôle | Résultat |
|---|---|---|
| 2026-11-06 | Banc planaire (modèle, pas le jeu), Comète à fond, double embrayage, antipatinage actif | 0–100 km/h en 4,13 s, 0–200 en 9,12 s ; passages en 2ᵉ à 94 km/h, 3ᵉ à 149, 4ᵉ à 202 |
| 2026-11-06 | Mesures de l'outil (`rapport.json`, micro B) | Régime vérifié des boucles à ±2 % du régime de référence, sauf `on.2600` (2 542) ; creux 0,5 à 4,8 dB ; raccords 0,4 à 4,4 dB |
| 2026-11-06 | **Essai humain d'écoute** des démos de conduite par le propriétaire | « Micro B ». C'est une écoute de fichiers, pas un essai en jeu |
| 2026-11-06 | `scripts\verify.ps1 -DownloadRobloxTypes` au commit 0f998a0 (intégration sans identifiants) | Toutes les étapes OK ; Lune 481 sur 481 ; pytest 38 sur 38 |
| 2026-11-06 | Relevé des identifiants : Lune, `AudioContent` de `aw-vm-exchange/audio02_comete.rbxm` (SHA-256 `89c7dfc6…`) | 20 objets Sound, 20 identifiants distincts, noms conformes (`comete_<nom>`) |
| 2026-11-06 | `scripts\verify.ps1 -DownloadRobloxTypes` après report des identifiants (commit bae4289) | Toutes les étapes OK ; Lune **481 réussis sur 481** ; pytest **38 sur 38** ; luau-lsp strict sans erreur |

Place de test : `build/AW-AUDIO-02.rbxlx`, construite par `rojo build default.project.json -o build/AW-AUDIO-02.rbxlx`
au commit bae4289. Elle contient les 20 identifiants (relevé dans le fichier construit) et la boîte `DualClutch`. Elle contient aussi les sons de la Brio, des pneus et des collisions, déjà dans `main`.

## 4. Points non vérifiés

- **Tout le rendu en jeu** : aucun essai Studio n'a été exécuté par l'assistant. La liste du § 5 est à faire par le
  propriétaire.
- **Double embrayage en conduite réelle** : seulement mesuré au banc planaire. Le test Studio `Lot08Client`, qui traite
  déjà le double embrayage comme une boîte automatique, n'a pas été exécuté.
- **Écoute par les autres joueurs** (régime transmis, Doppler) : non essayée à deux joueurs.
- **Écran des crédits** : l'entrée de wikusv est contrôlée par Lune, pas vue à l'écran.

## 5. Liste de vérification en jeu (propriétaire)

Ouvrez `build/AW-AUDIO-02.rbxlx` dans Studio et lancez « Jouer » (environnement Dev). Faites apparaître la **Comète**
par le menu d'administration (F2) et montez à bord. Réglez le volume « moteur » au maximum.

1. **Démarrage** : on entend le démarreur, puis le V8 qui prend et se pose au ralenti.
2. **Ralenti** : grave et régulier, sans battement ni coupure audible toutes les secondes.
3. **Boîte automatique** : à l'arrêt au neutre, appuyez sur l'accélérateur. La 1ʳᵉ s'engage seule et la voiture part.
4. **Accélération à fond** : le régime monte sans trou ni saut de volume. Les rapports passent seuls vers 8 100 tr/min,
   avec une courte coupure à chaque passage (2ᵉ vers 95 km/h, 3ᵉ vers 150 km/h au banc).
5. **Turbo** : en charge au-dessus d'environ 3 000 tr/min, un sifflement s'ajoute. Il n'y en a pas au ralenti ni pied
   levé.
6. **Lever de pied à haut régime** (au-dessus de 5 000 tr/min) : une décharge du turbo et des pétarades.
7. **Lever de pied à bas régime** (sous 3 000 tr/min) : ni pétarades ni décharge.
8. **Reprise en main** : Maj ou Ctrl passent un rapport à la main ; la boîte reprend la main seule après 4 s environ.
9. **Rupteur** : la boîte passe avant le rupteur (8 500 tr/min). Si vous l'atteignez (rétrogradage à la main avec Ctrl
   à haut régime, ou en dernier rapport), une coupure rythmée. Sinon, notez-le « non atteint ».
10. **Arrêt du moteur** : descendez du véhicule (**F**). On entend le V8 qui s'éteint.
11. **Vue cockpit** (**V**) : le moteur est plus étouffé.
12. **Brio** : prenez la Brio. Ses sons n'ont pas changé.
13. **Crédits** : dans les réglages, ouvrez l'écran « Crédits et licences ». On y voit l'entrée « Sons du moteur de la Comète », avec
    wikusv, Freesound et CC BY 4.0.
14. **À deux joueurs** (Studio : Test › Clients et serveurs, 2 joueurs), facultatif : quand l'autre joueur passe avec la
    Comète, vous entendez son moteur monter et descendre.

## 6. Écarts et limites

- **Source en CC BY 4.0** (et non CC0 comme la Brio) : le crédit est obligatoire. Il est affiché en jeu, et l'entrée de
  `docs/CREDITS_ACTIFS.md` est à ajouter par la coordination (fichier réservé).
- **Titre et lien du crédit masqués** : le titre du pack contient un nom de marque. La décision d'affichage reste
  reportée, comme pour les crédits précédents.
- **`on.1850`** vient d'un extrait en décharge : aucun passage en charge propre n'existait à ce régime.
- **`off.6000`** est transposé × 1,19 : la source la plus haute en décharge est à 5 060 tr/min.
- **Démarreur** : il vient d'un 4 cylindres (190E), décision Q2.
- **Caractère « vilebrequin plat »** de la Lotus : supposé, pas confirmé.
- **Écrêtage** : le micro B du fichier 232272 est écrêté à 3,39 % des échantillons. Il a été jugé acceptable à
  l'écoute de la démo.
- **Fichiers partagés** : seulement des ajouts dans `AssetManifest`, `Attributions`, `Localization`,
  `tests/lune/run.luau` et `SONS_TIERS.md`, plus l'adaptation des deux contrôles d'identifiants.
