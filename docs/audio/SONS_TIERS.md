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

Limites connues :
- le ralenti de la variante « moteur » tourne à ~1 420 tr/min sur le banc. Il est ramené à 1 000 tr/min (× 0,70),
  puis joué jusqu'à 850 tr/min ;
- l'octave de `19_500` (variante « échappement ») reste à confirmer à l'écoute ;
- le ralenti de la variante « échappement » est très faible à l'origine : relevé d'environ 30 dB, son bruit de fond
  aussi.
