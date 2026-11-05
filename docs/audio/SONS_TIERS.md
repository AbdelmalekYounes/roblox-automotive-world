# Registre des sons tiers

Sons enregistrés par d'autres et utilisés dans le jeu, sur décision du propriétaire (lot AUDIO-01, décision D1 du
2026-11-05 : « enregistrements libres »). Les fichiers d'origine restent **hors dépôt**, dans
`E:\ROBLOX DEV\aw-sound-references\`. Seul l'outil qui les transforme est versionné (`tools/audio/engine_loops.py`).

## Conditions

- Licences admises : **CC0** (domaine public, aucun crédit exigé) ou **CC BY**. Une source CC BY entraîne un crédit en
  jeu (`Shared/Assets/Attributions`) et une ligne dans `docs/CREDITS_ACTIFS.md`.
- La licence est relevée sur la page de chaque son, puis reconfirmée dans le fichier de licence du téléchargement.
- L'envoi sur Roblox est fait par le propriétaire (publication d'actifs). L'assistant ne publie rien.
- L'assistant ne peut pas écouter : le choix à l'oreille revient au propriétaire.

## 1. Brio : « The Dyno Sessions: 190E » (Chippy569, Freesound)

| Élément | Relevé |
|---|---|
| Source | <https://freesound.org/people/Chippy569/packs/9658/>, pack téléchargé en entier par le propriétaire le 2026-11-05 (64 fichiers) |
| Auteur | Chippy569, enregistré par Track Time Audio (« Dyno Sessions ») |
| Licence | **CC0 1.0** pour les 64 sons : `_readme_and_license.txt` du téléchargement (64 lignes « license: Creative Commons 0 ») |
| Sujet | Mercedes-Benz 190E-16V (4 cylindres) au banc. Aucun logo ni nom de marque n'est diffusé dans le jeu |
| Format | WAV 96 kHz, 24 bits ; micros Audix D6 (échappement, 30 cm), DPA 4062 (compartiment moteur), Rode NT1a (à distance) |
| Retenu | Micro **d'échappement (D6)**, pour l'homogénéité du timbre entre les régimes |

### Régimes mesurés

Mesure faite par l'outil le 2026-11-05 : raie d'allumage × 30 tr/min. Les numéros des noms de fichiers ne sont pas
tous des régimes : « 500 » ne correspond à aucune mesure.

| Fichier | Charge | Régime mesuré |
|---|---|---|
| `162515__chippy569__21_500_d6.wav` | vide (ralenti) | 1 013 tr/min, très faible (−51 dBFS) |
| `162506__chippy569__19_500_d6.wav` | charge | 1 288 tr/min (ambiguïté d'octave levée par l'ordre des étiquettes ; à confirmer à l'écoute) |
| `162509__chippy569__19_2500_d6.wav` | charge | 2 557 tr/min |
| `162512__chippy569__20_6500_d6.wav` | charge | 6 208 tr/min |
| `162518__chippy569__21_2500_d6.wav` | vide | 2 431 tr/min |
| `162521__chippy569__21_6500_d6.wav` | vide | 6 298 tr/min |
| `162501__chippy569__17_shortsweep_d6.wav` | montée en charge | ~2 000 → 6 800 tr/min en 2,1 s |
| `162504__chippy569__17_medsweep_d6.wav` | descentes pied levé | ~4 000 → 1 360 tr/min (3,3 à 7,5 s) |
| `162528__chippy569__23_startismall_d6.wav`, `162525__chippy569__23_startbig_d6.wav` | démarrage, arrêt | — |

### Sons produits

Commande : `python -I tools/audio/engine_loops.py brio "E:\ROBLOX DEV\aw-sound-references\brio\freesound"`.
Sortie : `build/audio/engines/brio/`, détail dans `rapport.json`. Tous les fichiers sont en WAV 48 kHz, 16 bits, mono.

| Ressource | Origine (transformation) |
|---|---|
| `on.1000`, `off.1000` | ralenti, transposé × 0,987 |
| `on.1450` | `19_500` (1 288 tr/min), × 1,126 |
| `on.2100`, `on.3000` | `19_2500`, × 0,821 et × 1,173 |
| `on.4300` | montée 0,95–1,50 s (3 669 → 5 263 tr/min), dépliée à régime constant |
| `on.6200` | `20_6500`, × 0,999 |
| `off.1450` | descente 6,85–7,40 s (1 753 → 1 448 tr/min), dépliée |
| `off.2100`, `off.3000` | `21_2500`, × 0,864 et × 1,234 |
| `off.4300` | descente 3,25–4,05 s (4 112 → 3 489 tr/min), dépliée |
| `off.6200` | `21_6500`, × 0,984 |
| `start`, `stop`, `stall` | `23_startismall` (1,85–4,6 s) ; `23_startbig` (6,55–8,2 s et 6,75–7,9 s), avec fondus |
| `demo_montee_lever_de_pied` | démo d'écoute, non envoyée : ralenti, montée en charge 6 s, lever de pied 4 s, ralenti |

Contrôles de l'outil (2026-11-05) :
- régime vérifié de chaque boucle à ±3 % du régime de référence ;
- raccord de boucle sous les sauts ordinaires du signal (au plus 0,29 fois le 99ᵉ centile) ;
- niveau continu au raccord, à ±2 dB ;
- niveaux RMS de −15 dBFS en charge et −21 dBFS en décharge, crête sous −1 dBFS.

Limites connues :
- seuls 3 régimes stables ont été enregistrés ; les autres points viennent de transpositions ou d'extraits de balayage
  courts (0,5 à 0,9 s) ;
- le ralenti d'origine est très faible : relevé de 30 dB, son bruit de fond aussi ;
- l'octave de `19_500` reste à confirmer à l'écoute (§ ci-dessus).
