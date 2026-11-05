# Lot AUDIO-01 — sons de moteur réalistes de la Comète et de la Brio

Branche du jeu : `feat/audio-01-moteurs` (depuis `main` 2520952). Plan rédigé le 2026-11-05.

## 1. État de départ (vérifié le 2026-11-05)

- **Aucun son de moteur n'est joué en jeu.** `AudioController` ne crée un son que si la ressource a un identifiant
  Roblox réel (`AssetManifest`), et aucun son n'a jamais été envoyé sur Roblox (lot 0.8).
- Les sons prévus (`tools/audio/synth.py`) sont des boucles synthétiques d'une seconde, faites d'harmoniques pures.
  Il y a quatre couches thermiques (850, 2 000, 3 500 et 5 500 tr/min), sans distinction de charge ni de véhicule.
- La Comète et la Brio ont le même régime dans leur définition : ralenti à 850 tr/min, rupteur à 7 200 tr/min.
- Pour les véhicules des autres joueurs, le régime n'est pas transmis : il est estimé à partir de la vitesse
  (`EngineAudioModel.estimateRpm`).

## 2. Décisions du propriétaire (2026-11-05)

| Id | Sujet | Décision |
|---|---|---|
| D1 | Source des sons | **Enregistrements libres** (CC0 ou CC BY), téléchargés par le propriétaire ; l'assistant les inspecte, puis en tire des boucles par régime et par charge. Exception « actif tiers », registre et crédits comme pour les modèles 3D |
| D2 | Périmètre | Les quatre volets : **moteur en charge et en décharge** ; **événements** (démarrage, arrêt, calage, rupteur, passages de rapport, pétarades et turbo de la Comète) ; **habitacle / extérieur** (son étouffé en vue cockpit, effet Doppler) ; **autres joueurs réalistes** (régime et charge transmis) |
| D3 | Régimes | Comète montée à **8 500 tr/min** (V8 biturbo) ; la Brio garde 7 200 tr/min (4 cylindres). Cela modifie la physique de la Comète : nouvelle référence d'égalité, à revérifier en jeu |

## 3. Enregistrements candidats (Freesound, relevés le 2026-11-05)

L'assistant **ne peut pas écouter** : il lit les pages, puis analyse les fichiers (spectre, régime mesuré, points de
boucle). Le jugement à l'oreille revient au propriétaire. Licences relevées sur chaque page ; à reconfirmer au
téléchargement (une connexion à Freesound est nécessaire).

Dossier de dépôt proposé, hors dépôt Git et sur le modèle des références 3D :
`E:\ROBLOX DEV\aw-sound-references\<véhicule>\freesound\`. Garder les noms de fichiers d'origine (ils commencent par
l'identifiant Freesound).

### 3.1 Brio (4 cylindres) : pack « The Dyno Sessions: 190E », Chippy569, CC0

<https://freesound.org/people/Chippy569/packs/9658/> : télécharger **le pack entier** (bouton « Download pack »).

Mercedes-Benz 190E-16V, 4 cylindres 16 soupapes, enregistrée au banc. Boucles prévues pour être répétées, 96 kHz et
24 bits, prises par trois micros : moteur (DPA 4062 sur la traverse de radiateur), échappement (Audix D6 à 30 cm de la
sortie) et à distance (Rode NT1a à 9 m).

| Régime (approx.) | En charge | Sans charge (point mort) |
|---|---|---|
| ~500 tr/min (affiché) | `19_500_*` | `21_500_*` |
| ~2 500 tr/min | `19_2500_*` | `21_2500_*` |
| ~6 500 tr/min | `20_6500_*` | `21_6500_*` |

Le pack contient aussi une montée en régime (`Acceleration Sweep - 4062`) et un démarrage avec petit coup de gaz
(`23_StartISmall_*`). Les sons de klaxon, de portes, de coffre, de vitre et de frein à main peuvent servir plus tard,
hors de ce lot.

Limite : seuls trois régimes ont été enregistrés. Les régimes intermédiaires seront obtenus par transposition et par
grains pris dans la montée en régime. Le régime « 500 » reste à vérifier par l'analyse, car il est inférieur au ralenti
habituel.

### 3.2 Comète (V8 biturbo) : enregistrements séparés, tous CC0

| Fichier | Auteur | Lien | Usage prévu |
|---|---|---|---|
| S63 AMG V8 Engine Revs (6,2 s, 48 kHz, stéréo) | marcelweiss | <https://freesound.org/s/505321/> | Ralenti et montées à vide d'un V8 biturbo (décharge) |
| v8 engine rev.wav (8,5 s, binaural) | overmedium | <https://freesound.org/s/651534/> | Coups de gaz et ralenti (complément) |
| DR015 dyno run-up GM Holden V8 supercharged (2 min, MP3) | Ears68 | <https://freesound.org/s/177184/> | Montées **en charge** au banc ; foule en fond, à vérifier |
| DR0000 dyno run-up Chev V8 (MP3) | Ears68 | <https://freesound.org/s/177185/> | Autre montée en charge, de secours |

Limite : aucun enregistrement libre trouvé d'un V8 de supercar à vilebrequin plat, tournant à régime fixe et en
charge. Le caractère sera celui d'un V8 biturbo « AMG », grave et rond. Si ces fichiers déçoivent à l'écoute, deux
voies restent possibles : d'autres candidats que le propriétaire repère, ou une bibliothèque payante. Un achat est une
décision du propriétaire, et sa licence doit permettre l'usage dans un jeu.

## 4. Déroulement

| Étape | Qui | Contenu |
|---|---|---|
| 1 | Propriétaire | Télécharger les fichiers du §3 dans `aw-sound-references` ; écouter et écarter ce qui ne convient pas |
| 2 | Assistant | Inspection : licence, durée, fréquence, régime mesuré (fréquence d'allumage), bruit de fond. Registre `docs/audio/SONS_TIERS.md` et `CREDITS_ACTIFS.md` |
| 3 | Assistant | Outil `tools/audio/engine_loops.py` (numpy, sans dépendance nouvelle ; MP3 décodé par le `aud` de Blender) : boucles sans clic à 6 ou 8 régimes, en charge et en décharge, pour chaque véhicule ; événements découpés ; niveaux homogènes. Fichiers d'écoute pour le propriétaire |
| 4 | Propriétaire | Écoute des boucles, puis envoi des sons retenus sur Roblox (publication d'actifs) et transmission des identifiants |
| 5 | Assistant | Identifiants au manifeste, profils sonores par véhicule, tests ; liste de vérification |
| 6 | Propriétaire | Vérification en jeu, puis validation |

Travaux de code menés **en parallèle de l'étape 1** (ils ne dépendent pas des enregistrements) :
- **Comète à 8 500 tr/min (D3)** : rupteur, zone rouge, passage de rapport et courbe de couple prolongée. Nouvelle
  référence d'égalité.
- **Régime et charge transmis** : le serveur publie, environ 10 fois par seconde, le régime et la charge du conducteur,
  bornés par la définition. Ces valeurs sont purement sonores et n'ont aucun effet sur le jeu.
- **`EngineAudioModel` v2**, module pur testé par Lune :
  - profil sonore par véhicule (régimes des boucles, en charge et en décharge) ;
  - fondu croisé selon le régime et la charge ;
  - détection des événements (passage de rapport, rupteur, lever de pied, calage) ;
  - réglages habitacle / extérieur.
- **Contrôleur** : filtre « habitacle » en vue cockpit (égaliseur, graves renforcés, aigus coupés) et Doppler des
  véhicules observés.

## 5. Hors périmètre

- Pneus, vent, chocs, klaxon et portes : sons possibles plus tard, à proposer.
- Les sons d'interface, d'ambiance et de radio du lot 0.8 restent inchangés.
- Aucune publication Roblox par l'assistant.

## 6. Avancement (2026-11-05)

Fait, et contrôlé hors Studio par `scripts\verify.ps1 -DownloadRobloxTypes` le 2026-11-05 : toutes les étapes OK, Lune
**409 réussis sur 409** (dont 6 tests de `tests/lune/specs/Audio01.luau`).

| Travail | Fichiers | Détail |
|---|---|---|
| Comète à 8 500 tr/min (D3) | `Definitions/Comete.luau`, `comete_definition_reference.json` | Zone rouge 8 300, rupteur 8 500, passage conseillé 8 100. Courbe prolongée à puissance quasi constante : maximum ~475 kW, contre ~470 avant. Nouvelle référence d'égalité ; le diff ne porte que sur ces champs |
| Régime transmis | `InputCodec`, `VehicleController`, `VehicleService`, `VehicleConstants` | Le conducteur déclare son régime (6e valeur de la commande, pas de 100 tr/min, 0 si le moteur est arrêté). Le serveur le borne (rupteur du modèle + 5 %) et publie `AudioRpm` et `AudioLoad` (accélérateur). Ces attributs sont retirés quand le conducteur sort. Usage purement sonore. Un ancien client reste accepté |
| Modèle sonore v2 | `EngineAudioModel`, `EngineSoundProfiles` | Profils enregistrés : boucles en charge et en décharge par régime, fondu croisé, transposition bornée (0,7 à 1,45), couche turbo. Événements : démarrage, arrêt, calage, rapport, rupteur, pétarades, décharge du turbo. Égaliseur d'habitacle et Doppler. Aucun profil inscrit tant que les enregistrements ne sont pas traités |
| Contrôleur | `AudioController`, `DevHud` | Profil du modèle s'il existe, sinon modèle générique. Les véhicules garés sans conducteur sont silencieux. Égaliseur « habitacle » en vue cockpit. Doppler sur les véhicules observés. Événements ponctuels avec délai minimal |

Non vérifié :
- tout le rendu en jeu : aucun son n'est encore envoyé sur Roblox ;
- la conduite de la Comète à 8 500 tr/min ;
- la charge réseau de la 6e valeur (envoi seulement quand une valeur change, au plus 15 fois par seconde comme avant).

En attente : le téléchargement des enregistrements du §3 par le propriétaire (étape 1).
