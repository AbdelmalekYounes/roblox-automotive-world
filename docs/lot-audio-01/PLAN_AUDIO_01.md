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

## 7. Brio d'abord (décision du propriétaire, 2026-11-05)

Le propriétaire a choisi de traiter **la Brio seule pour l'instant** et a téléchargé le pack 190E (64 fichiers, tous
en CC0).

Fait le 2026-11-05 :
- **Inspection et mesure des régimes** : registre `docs/audio/SONS_TIERS.md`. Les numéros des noms de fichiers ne sont
  pas tous des régimes.
- **Outil** `tools/audio/engine_loops.py` :
  - 12 boucles (6 régimes, en charge et en décharge) ;
  - démarrage, arrêt et calage ;
  - démo d'écoute rendue avec le mélange du jeu ;
  - `rapport.json`.
- **Profil `wk_brio`** (`EngineSoundProfiles`) et 15 ressources au manifeste (`audio.engine.brio.*`, CC0, sans
  identifiant). Les événements sont nommés en minuscules (`start`, `stop`, `stall`).
- **Tests** :
  - Audio01 6 : profil valide, rupteur de la définition, chaque ressource déclarée ;
  - `tests/test_audio01.py` : mesure du régime, dépliage d'un balayage, niveaux, cohérence avec le profil du jeu ;
  - Lot08 16 : les sons enregistrés sont comptés à part.


## 8. Version 2 après écoute (2026-11-05)

Retour du propriétaire sur la version 1 : « ça sonne pas bien du tout, on entend très bien le découpage ». Causes
mesurées et corrections : `docs/audio/SONS_TIERS.md` (§ « Sons produits — version 2 »).

| Correction | Où |
|---|---|
| 8 points plus rapprochés, pris sur des balayages continus ; boucles de ~1,6 s par grains alignés sur le cycle ; enveloppe lente aplanie ; niveaux suivant le régime ; deux variantes de micro | `tools/audio/engine_loops.py` |
| Fondus à puissance constante (régime et charge) | `EngineAudioModel.profileLayers`, démo |
| Moteur du véhicule conduit recalculé à chaque image (au lieu de toutes les 0,1 s) ; égaliseur d'habitacle posé seulement quand la vue change | `AudioController` |
| Profil Brio à 8 points ; 19 sons au manifeste | `EngineSoundProfiles`, `AssetManifest` |

Étape suivante : écoute des deux démos par le propriétaire et choix de la variante. Ensuite, envoi sur Roblox des
19 sons de la variante choisie, puis identifiants au manifeste.

## 9. Coupures au ralenti, défaut de l'outil (2026-11-05)

Retour du propriétaire sur la version 2 : « on entend des coupures les deux premières et les deux dernières
secondes », pour les deux variantes. La cause est un débordement d'entier dans le rééchantillonnage 96 → 48 kHz :
voir `docs/audio/SONS_TIERS.md`. Correction et test de non-régression ; sons et démos reproduits.

## 10. Passages de rapport (2026-11-05, demande du propriétaire : « au niveau des passages de vitesses il se passe quoi niveau son »)

Constat :
- à chaque passage, la boîte automatique coupe le couple pendant 0,25 s (`VehicleDynamics` : `ShiftTimer`) et le régime
  redescend vers celui du rapport suivant ;
- le son suivait bien le régime, mais restait sur la boucle « en charge », parce que la charge du son était la pédale ;
- la démo précédente ne contenait aucun passage.

Correction, approuvée par le propriétaire (« Oui, corrige ») :
- **Charge réelle du moteur :** `VehicleController` publie `EngineLoad` dans les données du HUD. Elle vaut 0 pendant un
  passage, sinon l'accélérateur effectif après les aides.
- **Son :** `AudioController` suit cette charge, lissée avec une constante de temps de 0,06 s. À chaque passage, la
  boucle « en décharge » prend brièvement le relais : on entend un creux net, sans claquement.
- **Détection des événements :** elle compare désormais deux relevés espacés d'au moins 0,1 s. Le véhicule conduit est
  mis à jour à chaque image, et une chute de régime ne se voit pas d'une image à la suivante.
- **Démo `demo_passages_<variante>.wav` :**
  - ralenti ;
  - départ pied au plancher au régime de calage du convertisseur ;
  - passages 1-2, 2-3 et 3-4 à 6 800 tr/min avec les rapports de la Brio ;
  - lever de pied en 4ᵉ, puis ralenti.

  Creux mesuré à chaque passage : 6 à 8 dB pendant ~0,2 s.
- **Non traité :** les véhicules des autres joueurs gardent la charge de la pédale, mais la chute de régime y est déjà
  transmise. C'est une option, à décider par le propriétaire.

## 11. Rétrogradages (2026-11-05, demande du propriétaire : « il faut aussi le faire pour les rapports descendants »)

Vérification :
- la boîte coupe aussi le couple aux rétrogradages (0,15 s, `Transmission.autoShift`), et la charge sonore du §10 s'y
  applique déjà ;
- relevé de la VRAIE dynamique de la Brio, par le nouvel outil `tests/lune/tools/engine-sound-trace.luau` (banc
  planaire, pas de 1/240 s) :
  - montées 1-2 à 53 km/h et 2-3 à 87 km/h ;
  - au lever de pied, 3-4 puis 4-5 ;
  - rétrogradages 5-4 en décélération (~1 570 tr/min) ;
  - rétrogradage forcé 4-3-2 à 40 km/h (régime 1 600 → 4 200 tr/min en 0,5 s) ;
  - 3-2-1 au freinage.

Constat : en décélération, la charge est déjà nulle et le convertisseur déverrouillé garde le régime presque constant
(1 550 → 1 610 tr/min). Le rétrogradage était donc presque inaudible.

Correction :
- **Coup de gaz sonore :** à chaque rétrogradage, la charge est portée à au moins 0,35 pendant 0,15 s, comme
  l'égalisation de régime de nombreuses boîtes. Effet uniquement sonore, aucune incidence physique
  (`AudioController`).
- **Démo `demo_conduite_<variante>.wav` :** tirée du relevé de la dynamique du jeu
  (`engine_loops.py --trace build/audio/engines/brio_trace.csv`). Montée de 4 à 5 dB pendant ~0,15 s à chaque
  rétrogradage.

**Constat hors son, à arbitrer par le propriétaire :** en 1ʳᵉ et en 2ᵉ pied au plancher, le moteur reste au rupteur
(7 200 tr/min) jusqu'à 1,5 s avant de passer le rapport (de 10,75 à 12,3 s dans le relevé). Le passage se décide sur
le régime côté roues (`ShiftUpRpm` 6 800), alors que le glissement du convertisseur porte le moteur au rupteur avant.
Cela s'entendra en jeu comme un moteur bloqué au rupteur. Une correction de la boîte (physique) ne relève pas de ce lot
sans accord.

## 12. Validation à l'écoute et envoi (2026-11-05)

Le propriétaire a validé à l'oreille la variante **« moteur »** :
- démos corrigées après les coupures ;
- passages de rapport ;
- conduite tirée de la vraie dynamique.

Ses réponses successives : « c'est bon » (démos corrigées), « c'est bien » (passages, avant la demande sur les
rétrogradages), « C'est bon » (démo de conduite). Ce sont des essais humains d'écoute sur des fichiers, pas en jeu.

Sons à envoyer sur Roblox par le propriétaire : `build/audio/engines/brio/a_envoyer/`. Le dossier contient 19 fichiers
WAV (48 kHz, mono, 3,4 Mo au total), nommés `brio_on_<tr/min>`, `brio_off_<tr/min>`, `brio_start`, `brio_stop`
et `brio_stall`. Chaque nom correspond à la ressource `audio.engine.brio.<on|off>.<tr/min>` ou
`audio.engine.brio.<start|stop|stall>` du manifeste.

Retour attendu : un `.rbxm` des 19 objets Sound insérés depuis le gestionnaire d'actifs, déposé dans `aw-vm-exchange`.
L'assistant y relève les identifiants avec Lune, puis les reporte au manifeste. Aucun identifiant n'est saisi à la main.

Décision ouverte, hors son : moteur collé au rupteur en 1ʳᵉ et en 2ᵉ (§11).

## 13. Sons envoyés, identifiants intégrés (2026-11-06)

Le propriétaire a importé les 19 sons dans Studio (importation groupée), les a insérés puis enregistrés dans
`aw-vm-exchange/brio_sound.rbxm` (SHA-256 `a7d9301e…`).

L'assistant y a relevé les 19 identifiants avec Lune (propriété `AudioContent`) : 19 identifiants distincts, un par
fichier. Ils sont reportés dans `AssetManifest` (table `BRIO_ENGINE_SOUND_IDS`, statut `ReadyForReview`).

Contrôles :
- pytest : la table du manifeste est exactement celle relevée ;
- Lune (Audio01 6) : chaque ressource du profil porte son identifiant et elle est jouable ;
- `scriptserify.ps1 -DownloadRobloxTypes` (2026-11-06) : Lune 410 sur 410, pytest 23 sur 23, toutes les étapes OK.

Place de test : `build/AW-Audio-Brio.rbxlx` (branche à ce commit). Elle porte un nom distinct pour ne pas être écrasée
par `verify.ps1`.

### Liste de vérification en jeu (propriétaire)

Lancer la place dans Studio (« Jouer »), environnement Dev. Obtenir la Brio par le menu d'administration (F2) ou par la
concession, puis monter à bord.

1. **Démarrage** : bruit de démarrage, puis ralenti régulier, sans coupure.
2. **Accélération à fond** :
   - montée continue du son, sans découpage audible entre les régimes ;
   - passages de rapport 1-2 et 2-3 entendus (bref creux puis reprise).
3. **Rupteur** : en 1ʳᵉ et en 2ᵉ, le moteur reste un moment à 7 200 tr/min avant de passer. C'est le constat de
   physique du §11, attendu tant qu'il n'est pas corrigé.
4. **Lever de pied** :
   - le son passe au « pied levé » ;
   - les rétrogradages en décélération s'entendent (petit coup de gaz).
5. **Rétrogradage forcé** : vers 40 km/h, écraser l'accélérateur. Le régime remonte nettement.
6. **Vue cockpit** (changement de caméra) : son plus étouffé et plus grave. Il redevient normal en vue extérieure.
7. **Réglages** : Téléphone › Paramètres, volume « Moteur ». Le son de la Brio suit le réglage.
8. **Arrêt du moteur** (si une touche le permet), ou sortie du véhicule : bruit d'arrêt.
9. **À deux joueurs** (Studio : Test › Clients et serveurs, 2 joueurs) :
   - la Brio de l'autre joueur s'entend, avec son régime réel et l'effet Doppler quand elle passe ;
   - une Brio garée, sans conducteur, est silencieuse.
10. **Comète** :
    - elle reste **muette** (aucun son enregistré pour elle, décision « la Brio d'abord ») ;
    - compte-tours jusqu'à 8 300 tr/min (zone rouge), rupteur à 8 500 ;
    - conduite à revérifier (décision D3).

### Validation en jeu (2026-11-06)

Le propriétaire a parcouru la liste ci-dessus dans Studio, sur `build/AW-Audio-Brio.rbxlx` (branche à 773edf2), et a
répondu « c'est tout à fait bon ». Les 10 points sont validés (QA-S01 à QA-S03). Il s'agit d'un essai humain du
propriétaire : l'assistant n'a exécuté aucun essai Studio.

Restent ouverts :
- les sons de la Comète (« la Brio d'abord ») ;
- le rupteur en 1ʳᵉ et en 2ᵉ de la Brio (QA-S04, réglage de boîte à arbitrer).
