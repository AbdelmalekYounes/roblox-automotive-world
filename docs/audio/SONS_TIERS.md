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

### Sons produits — version 2 (2026-11-05, après écoute du propriétaire)

**Version 1, rejetée par le propriétaire** (« ça sonne pas bien du tout, on entend très bien le découpage »).
Causes relevées par mesure :
- **sources hétérogènes d'un point au voisin** : écart de timbre jusqu'à 8 dB ;
- **boucles courtes** : 0,25 à 0,5 s ;
- **fondus linéaires** : creux de 3 dB au milieu de chaque transition ;
- **sauts de niveau dans les boucles prises sur un balayage** : jusqu'à 17 dB, parce qu'un balayage devient plus fort
  en montant ;
- **démo calculée en escalier**, et moteur recalculé toutes les 0,1 s en jeu.

Version 2 :
- **8 points**, de 1 000 à 6 300 tr/min, espacés d'un facteur ~1,3. Chaque point vient autant que possible d'un même
  balayage continu.
- **Préparation des boucles :**
  1. extrait déplié à régime constant ;
  2. enveloppe lente aplanie ;
  3. allongement à ~1,6 s par grains de 6 cycles alignés sur le cycle moteur ;
  4. raccord à puissance constante.
- **Niveaux** suivant une courbe régulière du régime : +3 dB par octave en charge, +2 dB en décharge.
- **Deux variantes** produites, à départager à l'oreille par le propriétaire :

| Variante | Sources | Écart de timbre moyen entre points voisins (mesure) |
|---|---|---|
| `moteur` (**recommandée**) | DPA 4062 : montée continue `162499` (1 550 → 6 400 tr/min, arrêtée avant le rupteur du banc), descente continue `162502` (7 000 → 1 470 tr/min), ralenti stable de la même prise (6,4–8,6 s, ~1 420 tr/min) | ~3,4 dB |
| `echappement` | Audix D6 : montée `162501`, descentes `162504`, prises stables `21_500`, `19_500`, `21_6500` pour les extrémités | ~5,1 dB |

Commande : `python -I tools/audio/engine_loops.py brio "E:\ROBLOX DEV\aw-sound-references\brio\freesound"`.
Sortie : `build/audio/engines/brio/<variante>/`, avec 16 boucles `on.<tr/min>` et `off.<tr/min>`, `start`, `stop`,
`stall`, une démo `demo_<variante>.wav` et `rapport.json`. Tous les fichiers sont en WAV 48 kHz, 16 bits, mono.

Contrôles de l'outil sur la variante `moteur` (2026-11-05) :
- régime de chaque boucle à ±4 % de sa référence ;
- variation de niveau dans une boucle (trames de 2 cycles) : 1,0 à 2,5 dB au-dessus du ralenti, 5 à 6 dB au ralenti
  (irrégularité naturelle) ;
- démo : saut de niveau d'une trame de 60 ms à la suivante, médiane 0,54 dB.

**Défaut de l'outil corrigé le 2026-11-05 (3ᵉ écoute du propriétaire : « on entend des coupures les deux premières et
les deux dernières secondes »).**
- **Cause :** le passage de 96 à 48 kHz calculait `indice × 96 000` en entiers 32 bits (type par défaut de numpy sous
  Windows). Au-delà de ~0,47 s de son, le calcul débordait et lisait des positions fausses : des coupures périodiques
  d'environ 0,4 s toutes les 0,9 s (−9 dB).
- **Sons touchés :** ceux issus d'une prise stable de plus de 0,5 s, dans les versions 1 et 2 : boucles de ralenti,
  `on.1300`, `on.1700` et `off.6300` de la variante échappement, `start`, `stop` et `stall`.
- **Correction :** indices en flottants, plus le test `test_resampling_keeps_long_signals_intact`.
- **Après correction :** aucune boucle ne présente de creux de plus de 8 dB sous sa médiane (trames de 50 ms). Démo
  « moteur » : ralenti constant à −23 dBFS. La démo « échappement » garde un creux d'environ 4 dB vers 9,8 s, pendant
  la descente.

Limites connues :
- le ralenti de la variante « moteur » tourne à ~1 420 tr/min sur le banc. Il est ramené à 1 000 tr/min (× 0,70),
  puis joué jusqu'à 850 tr/min ;
- l'octave de `19_500` (variante « échappement ») reste à confirmer à l'écoute ;
- le ralenti de la variante « échappement » est très faible à l'origine : relevé d'environ 30 dB, son bruit de fond
  aussi.

## 2. Pneus (lot AUDIO-03) : enregistrements séparés de Freesound, tous CC0

Téléchargés un par un par le propriétaire le 2026-11-06 dans `E:\ROBLOX DEV\aw-sound-references\pneus\freesound\`
(9 fichiers). Un téléchargement isolé ne contient pas de fichier de licence : la licence est celle **relevée sur la page
de chaque son le 2026-11-06** (« Creative Commons 0 »). Aucun logo ni nom de marque n'est diffusé dans le jeu.

| N° | Fichier | Auteur | Licence | Format lu par l'outil | SHA-256 (début) |
|---|---|---|---|---|---|
| 1 | `71736__audible-edge__chrysler-lhs-tire-squeal-01-04-25-2009.wav` | audible-edge | CC0 | 96 kHz, mono, 10,0 s | `5249889e2410fa07` |
| 2 | `71737__audible-edge__chrysler-lhs-tire-squeal-02-04-25-2009.wav` | audible-edge | CC0 | 96 kHz, mono, 11,1 s | `44a7ee84c44a1286` |
| 3 | `71738__audible-edge__chrysler-lhs-tire-squeal-03-04-25-2009.wav` | audible-edge | CC0 | 96 kHz, mono, 13,8 s | `6dd839fa59832d4f` |
| 4 | `71740__audible-edge__nissan-maxima-burnout-04-25-2009.wav` | audible-edge | CC0 | 96 kHz, mono, 8,9 s | `f4af2c030aa58e00` |
| 5 | `71741__audible-edge__nissan-maxima-handbrake-turn-04-25-2009.wav` | audible-edge | CC0 | 96 kHz, mono, 10,4 s | `083f252ff24f7716` |
| 6 | `170421__eelke__nissan-leaf.wav` | Eelke | CC0 | 48 kHz, stéréo, 9,4 s | `dbebd8f7ca0ebb07` |
| 7 | `591079__orlandorizo__car-rolling-on-asphalt.wav` | orlandorizo | CC0 | 48 kHz, stéréo, 88,9 s | `be7dae67649d7d62` |
| 8 | `462862__breviceps__passing-car-wet-road.wav` | Breviceps | CC0 | 48 kHz, stéréo, 5,8 s | `2a289a0b1a5b14ec` |
| 9 | `529225__unplugthefridge__car-tires-start-and-stop-on-gravel-shoulder.wav` | UnplugTheFridge | CC0 | 48 kHz, stéréo, 35,6 s | `6dd24d311a1f721a` |

### Analyse (2026-11-06)

Analyse par trames de 0,5 s, avec un spectre lissé (Welch, 2 048 points) : niveau, part de chaque bande et raie
dominante entre 600 Hz et 6 kHz. Aucun écrêtage n'a été trouvé (0 % d'échantillons au-delà de 0,98).

- **Crissements (n° 1 à 5)** : enregistrés moteur en marche. Les passages qui crissent nettement ont une raie qui
  dépasse de 25 à 34 dB le reste de la bande ; les graves (< 300 Hz, moteur) y restent de 12 à 26 dB plus bas.
  - n° 4 : de 3,0 à 5,5 s, le crissement le plus net et le plus régulier (raie à 1,5–1,64 kHz, −6 à −11 dBFS) ;
  - n° 3 : de 6,0 à 9,0 s, crissement de virage plus grave (raie vers 1 kHz) ;
  - n° 5 : de 5,0 à 7,0 s, glissade au frein à main (1,3 kHz), plus courte ;
  - n° 1 et 2 : crissements plus brefs (4,0 et 6,0 s ; 4,0 à 6,5 s), non retenus.
- **n° 6 (Leaf)** : passage au plus près vers 6 à 7 s (−19 dBFS), bruit large sans raie de moteur thermique.
- **n° 7** : pris dans l'habitacle, presque tout sous 300 Hz (bruit de caisse) ; non retenu.
- **n° 8 (mouillé)** : de 1,3 à 3,3 s, chuintement dominant entre 1 et 4 kHz.
- **n° 9 (gravier)** : deux départs et deux arrêts. Roulement régulier de 4,0 à 8,5 s, passage plus fort de 17,0 à
  20,5 s. Aucune vraie glissade sur gravier n'est présente.

### Sons produits — version 1 (2026-11-06)

Commande :

```
python -I tools/audio/tire_loops.py build "E:\ROBLOX DEV\aw-sound-references\pneus\freesound" --trace build/audio/tires/brio_trace.csv
```

Le relevé est produit par `lune run tests/lune/tools/tire-sound-trace.luau build/AutomotiveWorld.rbxlx wk_brio
build/audio/tires/brio_trace.csv`. Sortie dans `build/audio/tires/` : six boucles en WAV 48 kHz, 16 bits, mono, plus
`ecoute_boucles.wav` (chaque boucle jouée trois fois), `demo_pneus.wav` et `rapport.json`.

| Ressource | Source, extrait | Méthode | Raccord (dB) | Plus grand creux (dB, trames de 50 ms) |
|---|---|---|---|---|
| `roll.dry` | n° 6, 5,5–7,5 s, 60 Hz–9 kHz | grains, 2,0 s | 0,46 | 1,11 |
| `roll.loose` | n° 9, 4,0–8,5 s, 80 Hz–12 kHz | grains, 2,0 s | 0,80 | 2,23 |
| `roll.wet` | n° 8, 1,3–3,3 s, 300 Hz–12 kHz | grains, 2,0 s | 2,60 | 1,36 |
| `squeal` | n° 3, 6,0–9,0 s, 400 Hz–8 kHz | extrait naturel bouclé, 2,04 s | 0,30 | 4,15 |
| `scrub` | n° 4, 3,0–5,5 s, 400 Hz–8 kHz | extrait naturel bouclé, 2,22 s | 5,90 | 6,64 |
| `slide.loose` | n° 9, 17,0–20,5 s, 200 Hz–12 kHz | grains, 2,0 s | 1,23 | 1,87 |

Méthodes :
- **Bruits (roulement, eau, gravier)** : grains de 160 ms brassés, sans répétition reconnaissable.
- **Crissements** : extrait naturel bouclé. Des grains d'un son presque pur, superposés avec des phases au hasard,
  battraient. Le point de boucle est celui qui ressemble le plus au début (corrélation, écart de niveau), avec un
  fondu de 0,2 s.

Le « raccord » est l'écart de niveau entre la dernière et la première trame de 20 ms. Pour `scrub` (5,9 dB) et
`roll.wet` (2,6 dB), il se situe dans les variations naturelles du son : 89ᵉ et 95ᵉ centiles des écarts entre trames
voisines de 20 ms de la même boucle. Il reste à confirmer à l'oreille.

Limites connues :
- **Glissade sur gravier** : elle est tirée d'un passage plus dense du même enregistrement, pas d'une vraie glissade.
- **Roulement sec** : il vient d'un passage de voiture à distance, et non d'un micro placé au pneu.
- **Démo** : elle ne contient que les pneus (pas le moteur). Elle suit une dynamique relevée sur le banc planaire,
  et non dans Roblox.
