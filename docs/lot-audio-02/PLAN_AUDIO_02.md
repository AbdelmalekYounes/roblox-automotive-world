# Lot AUDIO-02 — sons de moteur de la Comète

Branche : `feat/audio-02-comete` (worktree, depuis `main` 1037a9a). Plan rédigé le 2026-11-06.

Demande du propriétaire (2026-11-06) : « ajouter le son moteur etc. de la Comète ». Ce lot suit le lot AUDIO-01
(Brio, `docs/lot-audio-01/PLAN_AUDIO_01.md`) et en reprend les décisions :
- **D1** : enregistrements libres CC0 ou CC BY ;
- **D2** : volets moteur, événements, habitacle et autres joueurs ; turbo et pétarades au lever de pied pour la
  Comète ;
- **D3** : rupteur à 8 500 tr/min.

Mêmes règles : téléchargement, écoute et envoi sur Roblox par le propriétaire, aucun essai Studio automatique.

## 1. État de départ (vérifié le 2026-11-06)

- **La Comète est muette** : aucun profil sonore (`EngineSoundProfiles` ne contient que la Brio).
- **Moteur** : V8 biturbo, ralenti à 850 tr/min, zone rouge à 8 300 tr/min, rupteur à 8 500 (décision D3).
- **Boîte séquentielle** : une coupure de couple à chaque passage, déjà suivie par la charge réelle du son
  (`EngineLoad`).
- **Ce que le modèle sonore v2 sait déjà faire**, si le profil le déclare (`EngineAudioModel`) :
  - couche `turbo` (sifflement selon la charge et le régime) ;
  - événements `BlowOff` (décharge au lever de pied) et `Pops` (pétarades à haut régime) ;
  - Doppler, habitacle, régime transmis aux autres joueurs.
- **Outils d'AUDIO-01 à reprendre** :
  - `tools/audio/engine_loops.py` : balayages dépliés, enveloppe aplanie, grains alignés sur le cycle, indices en
    flottants ;
  - `tests/lune/tools/engine-sound-trace.luau` : relevé de la vraie dynamique, à lancer avec `wk_comete`.
- **MP3 illisibles** : aucun décodeur MP3 n'est disponible sur le poste (pas de Blender ni de ffmpeg). Les sources
  sont donc prises en **WAV**.

## 2. Mesure du régime d'un V8

Un V8 à 4 temps allume 4 fois par tour : la raie d'allumage vaut régime / 15 (Hz). Elle remplace le régime / 30 du
4 cylindres de la Brio. Pour un V8 à vilebrequin croisé, la demi-raie (régime / 30) est forte aussi, d'où la
sonorité « grondante ». Le régime de chaque extrait sera mesuré, puis confirmé par l'ordre des raies.

## 3. Enregistrements candidats (Freesound, relevés le 2026-11-06, tous CC0, WAV)

Dossier de dépôt : `E:\ROBLOX DEV\aw-sound-references\comete\freesound\`. Garder les noms d'origine.

| # | Fichier (lien) | Auteur | Format relevé | Usage prévu |
|---|---|---|---|---|
| 1 | Car Engine: Maserati GranTurismo Switch to Sport Mode and Launch — <https://freesound.org/s/585215/> | myeclecticself | 48 kHz 16 bits stéréo, 16,6 s | **source principale** : ralenti, départ et montée **en charge**, passages de rapport (V8 d'origine Ferrari) |
| 2 | Car Engine: Maserati GranTurismo Drive By 2 — <https://freesound.org/s/585214/> | myeclecticself | 48 kHz 16 bits stéréo, 10,8 s | haut régime en charge, lever de pied (même moteur) |
| 3 | S63 AMG V8 Engine Revs — <https://freesound.org/s/505321/> | marcelweiss | 48 kHz 16 bits stéréo, 6,2 s | montées et descentes **à vide** d'un V8 biturbo (décharge), décharge du turbo |
| 4 | v8 engine rev — <https://freesound.org/s/651534/> | overmedium | 44,1 kHz 16 bits stéréo binaural, 8,5 s | ralenti et coups de gaz (complément) |
| 5 | Car Antilag (No cleanup, 32float) — <https://freesound.org/s/797835/> | modusmogulus | 48 kHz 32 bits flottants stéréo, 11,3 s | **pétarades** (anti-lag, détonations à l'échappement) |
| 6 | Import car revs on Chassis Dyno with Turbo — <https://freesound.org/s/496171/> | editboy23 | 48 kHz 16 bits stéréo, 35,5 s | **sifflement du turbo**, isolé par filtrage (moteur 6 cylindres ; l'auteur signale une saturation par endroits) ; selon Q3 |

Déjà disponible, pour le démarrage (selon Q2) : démarreur de la 190E de la Brio, `162525__chippy569__23_startbig_d6`,
dans `aw-sound-references\brio\freesound\` (CC0, au registre).

Écartés après lecture des pages :
- les montées au banc de V8 d'Ears68 (177184, 177185) : en **MP3** ;
- 339136, 339137, 339703 (FFKoenigsegg20012017) : la provenance est douteuse (étiquettes de modèles de jeux vidéo,
  « 217 MPH ») ;
- le V8 de Formule 1 (181187) : de 6 700 à 18 000 tr/min, trop haut pour une transposition crédible ;
- les V8 de Range Rover (FLAC) et la Ford 460 (MP3).

**Caractère** : aucun V8 de supercar à vilebrequin plat (son aigu et rageur) n'existe en libre et en WAV. Le caractère
sera celui d'un V8 de grand tourisme (Maserati, V8 Ferrari à vilebrequin croisé) et d'un V8 biturbo AMG : grave et
rond (question Q1).

## 4. Décisions du propriétaire (2026-11-06)

| Id | Sujet | Décision |
|---|---|---|
| Q1 | Caractère du moteur | **V8 « grand tourisme » libre** (Maserati et AMG), recommandation retenue |
| Q2 | Démarrage | **démarreur de la 190E** enchaîné sur le ralenti du V8, recommandation retenue |
| Q3 | Sifflement du turbo | **isolé dans l'enregistrement du Supra** au banc, recommandation retenue |
| Q4 | Passage de rapport | réponse du propriétaire : « il faudrait que la voiture soit en boîte auto pour être fidèle à la McLaren 720S » |

**Q4 se transforme en demande de changement de boîte**, hors du périmètre sonore. La physique du jeu connaît déjà
une boîte **à double embrayage** (`DualClutch`) : passages automatiques, reprise possible à la main (Maj et Ctrl),
sans convertisseur. C'est le type de boîte de la 720S (7 rapports, double embrayage). Passer la Comète de
`Sequential` à `DualClutch` ne change qu'un champ de sa définition, mais c'est un changement de physique : la
référence d'égalité et des tests sont concernés. Sa place (dans ce lot ou dans un lot séparé) est demandée au
propriétaire.

### Boîte à double embrayage (décision du propriétaire, 2026-11-06 : « Oui, dans ce lot »)

Fait le 2026-11-06 :
- **Définition** : `Definitions/Comete.luau`, `Transmission.Kind` passe de `Sequential` à **`DualClutch`**. Les
  passages sont automatiques (régime conseillé de 8 100 tr/min, modulé par l'accélérateur) et le conducteur peut
  reprendre la main avec Maj et Ctrl. Coupure de 0,06 s inchangée.
- **Référence d'égalité régénérée** (`tests/lune/tools/dump-definition.luau`) : le seul champ changé est
  `Powertrain.Transmission.Kind`.
- **Tests adaptés** :
  - `Veh3d01Comete` n° 10 : accélérer au neutre engage la 1ʳᵉ, et la boîte monte en 2ᵉ au-delà du passage conseillé ;
  - `Lot08Content` n° 2 ;
  - `Base01` : commentaire de la référence.
  - Le test Studio `Lot08Client` traite déjà le double embrayage comme une boîte automatique ; il n'a pas été exécuté.

Mesure sur le banc planaire (Comète à fond, pas de 1/240 s ; valeurs du modèle, pas des mesures en jeu) :

| Boîte | Antipatinage | 0–100 km/h | 0–200 km/h | Passages (rapport à la vitesse) |
|---|---|---|---|---|
| Double embrayage | actif (état de départ, A-02) | 4,13 s | 9,12 s | 2ᵉ à 94 km/h, 3ᵉ à 149, 4ᵉ à 202 (vers 8 100 tr/min) |
| Double embrayage | coupé | 4,46 s | 9,60 s | 2ᵉ à 20 km/h, 3ᵉ à 50 km/h : les roues patinent, le régime côté roues atteint le seuil de passage |
| Séquentielle (ancienne) | actif | 4,09 s | — | aucun passage sans le conducteur : reste en 1ʳᵉ au rupteur (8 513 tr/min) |

`verify.ps1 -DownloadRobloxTypes` (2026-11-06) : toutes les étapes OK, Lune 477 sur 477, pytest 33 sur 33. La conduite
en jeu n'est pas vérifiée.

### Premières mesures des enregistrements (2026-11-06)

Le propriétaire a déposé 5 des 6 fichiers. Il manque le n° 5 (pétarades, 797835).

Analyse : raies entre 25 et 700 Hz par trames de 0,2 s, puis régime estimé par un peigne de demi-ordres (V8 à
vilebrequin croisé), trames de 0,12 s :
- **n° 1, Maserati, départ** :
  - **ralenti stable de 0,2 à 7,8 s**, à **850–860 tr/min** (raie d'allumage de 56 Hz = régime / 15), soit le ralenti
    de la Comète ;
  - départ vers 8,4 s : montée en 1ʳᵉ jusqu'à environ 5 500 tr/min (mesure incertaine, scores faibles), passage vers
    9,3 s, puis montée en 2ᵉ de 3 100 à 5 400 tr/min jusqu'à 10,5 s, pendant que la voiture s'éloigne (−8 dB et effet
    Doppler) ;
  - une raie parasite fixe à 86 Hz est présente du début à la fin (bruit ambiant).
- **n° 3, AMG** : ralenti à 59 Hz ; trois coups de gaz à vide de 0,3 à 0,5 s chacun, avec leurs retombées.
- **n° 4, V8 binaural** : ralenti à 44–46 Hz ; coups de gaz courts.

**Constat** : aucune montée continue et stable **en charge** au-delà de ~5 500 tr/min. Les boucles en charge devront
être prises sur de courts extraits (départ de la Maserati, passage n° 2), puis transposées. La qualité est à juger à
l'écoute des démos.

## 5. Déroulement

Le déroulement est celui d'AUDIO-01 :
1. réponses et téléchargement ;
2. inspection et mesure des régimes ;
3. boucles en charge et en décharge ;
4. événements ;
5. démos d'écoute, dont une tirée du relevé de la dynamique de la Comète ;
6. écoute par le propriétaire ;
7. envoi (`.rbxm` préfixé `audio02_`) ;
8. identifiants reportés ;
9. place `build/AW-AUDIO-02.rbxlx` et rapport `RAPPORT_AUDIO_02.md`.

## 6. Hors périmètre

- Modifier la physique de la Comète : le constat d'AUDIO-01 sur le rupteur concernait la Brio.
- Les sons de la Brio restent inchangés.
- Aucune publication Roblox par l'assistant.
