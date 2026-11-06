# Lot AUDIO-03 — sons des pneus

Branche du jeu : `claude/audio-03-pneus-ba577d` (worktree, depuis `main` 6a54046). Plan rédigé le 2026-11-06.

Demande du propriétaire (2026-11-06) : « ajouter des sons liés aux pneus (frottement avec le sol, crissement lors de
dérapage etc.) ». Lot mené en parallèle de BRIO-02 et CAMERA-01, sur des fichiers disjoints (exception accordée par
le propriétaire pour ces lots).

## 1. État de départ (vérifié le 2026-11-06)

- **Aucun son de pneu n'est joué en jeu.** Le lot 0.8 a déclaré `audio.effect.skid`, un crissement synthétique
  (`tools/audio/synth.py`) jamais envoyé sur Roblox et branché nulle part. Il ne compte pas comme solution réaliste ; il
  reste au manifeste, inchangé.
- La physique calcule déjà, roue par roue, tout ce qu'il faut (`VehicleDynamics`, `VehicleSimulator`) :
  - glissement longitudinal `SlipRatio` (blocage au freinage, patinage au départ), pic d'adhérence de la Brio à 0,10 ;
  - angle de dérive `SlipAngle` (virage, dérapage), pic de la Brio à 7° ;
  - contact au sol, vitesse du contact, revêtement (`SurfaceFriction` selon le matériau Roblox), humidité (`Wet`,
    `Wetness`) ;
  - ABS (`AbsFactor`) : il maintient le glissement près du pic au lieu de bloquer la roue.
- Le matériau lui-même (asphalte, gravier, herbe…) n'est pas conservé : seul son coefficient d'adhérence l'est.
- Le son du véhicule conduit est recalculé à chaque image (`AudioController.updateDriven`) ; celui des véhicules
  observés toutes les 0,1 s, avec Doppler. Les données du véhicule conduit arrivent par `DevHud.latest()`.

## 2. Modèle sonore proposé

Module pur `src/shared/Audio/TireAudioModel.luau`, testé par Lune. Entrée : un résumé des quatre roues (glissements,
vitesse de contact, contact au sol, famille de revêtement, humidité, ABS). Sortie : volume et vitesse de lecture de
chaque boucle. Le son est émis à la position du véhicule (une seule source par véhicule, pas une par roue).

| Couche (boucle) | Ressource | Déclencheur | Réglage |
|---|---|---|---|
| Roulement sec | `audio.effect.tire.roll.dry` | vitesse sur revêtement dur | volume croissant avec la vitesse (rien sous ~5 km/h), hauteur 0,8 → 1,3 |
| Roulement meuble | `audio.effect.tire.roll.loose` | gravier, terre, herbe, sable, neige | crépitement de gravier ; plus grave et plus sourd sur herbe et neige |
| Chaussée mouillée | `audio.effect.tire.roll.wet` | humidité × vitesse | chuintement d'eau ; s'ajoute au roulement sec |
| Crissement | `audio.effect.tire.squeal` | dérive au-delà du pic (virage, dérapage), blocage, patinage | volume selon l'excès de glissement, hauteur selon la vitesse de glissement ; atténué sur le mouillé, absent sur le meuble |
| Frottement de glissade | `audio.effect.tire.scrub` | glissade franche (roue bloquée, dérapage large) | bruit large et grave sous le crissement |
| Glissade sur gravier | `audio.effect.tire.slide.loose` | glissement sur revêtement meuble | remplace le crissement hors asphalte |

Cas particuliers :
- **ABS** : la roue ne bloque pas, le glissement oscille près du pic ; le son donne un grondement pulsé (modulation
  purement sonore), et non un crissement continu.
- **Patinage au départ** : glissement longitudinal des roues motrices ; crissement plus aigu, suivant la vitesse de
  rotation des roues.
- **Vue cockpit** : sons des pneus étouffés comme le moteur (égaliseur d'habitacle).
- **Qualité graphique « Low »** : roulement et crissement seulement.

Famille de revêtement : déduite du nom du matériau Roblox (ajout d'un champ au contact, sans changer l'adhérence).

## 3. Enregistrements candidats (Freesound, relevés le 2026-11-06)

L'assistant **ne peut pas écouter** : licences et formats lus sur chaque page, à reconfirmer dans le fichier de
licence du téléchargement. Dossier de dépôt : `E:\ROBLOX DEV\aw-sound-references\pneus\freesound\` (garder les noms
d'origine, qui commencent par l'identifiant Freesound).

| # | Fichier (lien) | Auteur | Licence | Format relevé | Usage prévu |
|---|---|---|---|---|---|
| 1 | Chrysler LHS tire squeal 01 — <https://freesound.org/s/71736/> | audible-edge | CC0 | WAV 96 kHz 24 bits mono, 10,0 s | crissement en virage |
| 2 | Chrysler LHS tire squeal 02 — <https://freesound.org/s/71737/> | audible-edge | CC0 | WAV 96 kHz 24 bits mono, 11,1 s | crissement en virage |
| 3 | Chrysler LHS tire squeal 03 — <https://freesound.org/s/71738/> | audible-edge | CC0 | WAV 96 kHz 24 bits mono, 13,8 s | crissement en virage |
| 4 | Nissan Maxima burnout — <https://freesound.org/s/71740/> | audible-edge | CC0 | WAV 96 kHz 24 bits mono, 8,9 s | patinage au départ |
| 5 | Nissan Maxima handbrake turn — <https://freesound.org/s/71741/> | audible-edge | CC0 | WAV 96 kHz 24 bits mono, 10,4 s | glissade (frein à main), frottement |
| 6 | nissan-leaf — <https://freesound.org/s/170421/> | Eelke | CC0 | WAV 48 kHz 24 bits stéréo, 9,4 s | roulement sec (voiture électrique : pas de moteur thermique) |
| 7 | Car rolling on asphalt — <https://freesound.org/s/591079/> | orlandorizo | CC0 | WAV 48 kHz 24 bits stéréo, 1 min 29 | roulement sec continu, pris dans l'habitacle (secours et vue cockpit) |
| 8 | Passing Car (Wet road) — <https://freesound.org/s/462862/> | Breviceps | CC0 | WAV 48 kHz 16 bits stéréo, 5,8 s | chaussée mouillée (~100 km/h) |
| 9 | Car Tires Start and Stop on Gravel Shoulder — <https://freesound.org/s/529225/> | UnplugTheFridge | CC0 | WAV 48 kHz 32 bits stéréo, 35,6 s | roulement sur gravier (micro près du pneu) |
| 10 | auto car or van stop brake skid gravel short — <https://freesound.org/s/637161/> | kyles | CC0 | FLAC 48 kHz 24 bits mono, 1,1 s | glissade sur gravier |

Écartés après lecture des pages : `71739` (squeal 04, distorsion signalée par l'auteur), `536769` (Ogg 24 kHz,
64 kb/s), `271337` (16 bits 44,1 kHz, 3 s, déjà retravaillé), `817389` (M4A 67 kb/s), `251661/251662` (MP3 128 kb/s).
En option, lourd : `668552` (felix.blume, Land Cruiser sur terre, gravier et boue, CC0, WAV 48 kHz 24 bits,
11 min 19, 186 Mo), à prendre seulement si le gravier n° 9 déçoit.

Limites attendues :
- les crissements ont été enregistrés avec le moteur en marche : il faudra filtrer le moteur (il est grave, le
  crissement est entre ~1 et 4 kHz) ; le résultat est à juger à l'oreille ;
- les passages (n° 6 et 8) varient en niveau et en hauteur (Doppler) : boucles prises autour du point de passage,
  enveloppe aplanie, comme pour le moteur ;
- aucun enregistrement libre de roulement « micro au pneu » sur asphalte n'a été trouvé.

## 4. Décisions du propriétaire (2026-11-06)

Les quatre questions ont été posées en une fois ; le propriétaire a retenu chaque recommandation de l'assistant.

| Id | Sujet | Décision |
|---|---|---|
| Q1 | Revêtements couverts | **sec, mouillé et meuble** (gravier, terre, herbe, sable, neige), plus le crissement sur le dur |
| Q2 | Pneus des autres joueurs | **transmettre** un niveau de glissement déclaré par le conducteur, borné par le serveur et publié en attribut (même schéma que le régime d'AUDIO-01) ; usage purement sonore |
| Q3 | Véhicules concernés | **tous les véhicules**, mêmes sons, ajustés par la masse |
| Q4 | Réglage de volume | catégorie **« Effets »** existante, étouffée en vue cockpit |

## 5. Déroulement

| Étape | Qui | Contenu |
|---|---|---|
| 1 | Propriétaire | Réponses aux questions du §4 ; téléchargement des fichiers du §3 |
| 2 | Assistant | Inspection (licence, format, spectre, bruit de moteur), registre `docs/audio/SONS_TIERS.md` ; outil `tools/audio/tire_loops.py` (numpy seul) ; démos d'écoute tirées de la vraie dynamique (virage serré, freinage fort avec et sans ABS, départ en patinage, gravier, mouillé) |
| 3 | Propriétaire | Écoute des démos ; corrections |
| 4 | Assistant | `TireAudioModel` + tests Lune ; intégration au contrôleur (véhicule conduit et observés) ; manifeste ; `verify.ps1` |
| 5 | Propriétaire | Envoi des sons sur Roblox (`.rbxm` préfixé `audio03_` dans `aw-vm-exchange`) |
| 6 | Assistant | Identifiants au manifeste, place de test `build/AW-AUDIO-03.rbxlx`, rapport `RAPPORT_AUDIO_03.md` avec la liste de vérification |

## 6. Avancement (2026-11-06)

Fait pendant le téléchargement (étape 4 avancée, elle ne dépend pas des enregistrements), contrôlé hors Studio par
`scriptserify.ps1 -DownloadRobloxTypes` le 2026-11-06 : toutes les étapes OK, Lune **417 réussis sur 417** (dont
7 tests de `tests/lune/specs/Audio03.luau`), pytest 29 sur 29 (dont 6 de `tests/test_audio03.py`).

| Travail | Fichiers | Détail |
|---|---|---|
| Modèle pur | `Shared/Audio/TireAudioModel` | Familles de revêtement (dur, meuble, mou, glace) d'après le matériau Roblox ; résumé des quatre roues (crissement par excès de dérive ou de glissement longitudinal, porte sur la vitesse de glissement, glissade franche, revêtement majoritaire, humidité) ; six couches ; pulsation de l'ABS à 9 Hz ; masse ; qualité (2, 4 ou 6 couches) |
| Revêtement au contact | `VehicleTypes`, `VehicleSimulator` | Champ `Material` du contact (nom du matériau), pour le son seulement : l'adhérence ne change pas |
| Véhicule conduit | `VehicleController`, `DevHud` | Résumé recalculé à chaque image (`TireAudio` dans les données du HUD) |
| Autres joueurs (Q2) | `InputCodec`, `VehicleService`, `VehicleConstants` | 7ᵉ valeur : glissement 0–1 par pas de 0,1 ; 8ᵉ : code de revêtement 0–3. Le serveur borne, et met le glissement à 0 pour un véhicule à l'arrêt (vitesse vue par le serveur < 1 m/s) sans accélérateur ; attributs `AudioTireSlip` et `AudioTireSurface`, retirés quand le conducteur sort. Ancien client accepté |
| Contrôleur | `AudioController` | Pneus du véhicule conduit à chaque image ; véhicules observés toutes les 0,1 s, même limite de nombre et même Doppler que le moteur, roulement seul sans conducteur ; égaliseur d'habitacle aussi sur le groupe « Effets » (Q4) ; aucun son créé tant qu'une couche est muette |
| Manifeste | `AssetManifest` (section AUDIO-03) | Six ressources `audio.effect.tire.*`, CC0, sans identifiant ; exception de comptage dans `Lot08Content` |
| Outil | `tools/audio/tire_loops.py` | Lecture WAV 16/24/32 bits et flottant ; `inspect` (niveaux, bandes, raie de crissement par trame) ; boucles de bruit par grains ; démo rendue par un portage du modèle, d'après un relevé de la dynamique |

Mesure sur le banc planaire (Brio, 80 → 0 km/h, pas de 1/240 s ; valeurs du modèle, pas des mesures en jeu) :
- sans ABS : roues bloquées, crissement moyen 1,00 ;
- avec ABS : la dynamique garde le glissement sous le pic (crissement calculé moyen 0,02) ; un **plancher sonore de
  0,35** (au-dessus de 3 m/s), pulsé, donne le grondement de l'ABS : moyen 0,35 ; réglage à juger à l'écoute ;
- roue libre en ligne droite : aucun crissement (hors transitoire de départ du banc, 0,008 à 0,033 s, écarté).

Écart à la liste du §3 : le n° 10 (`637161`, FLAC) ne peut pas être lu sans dépendance hors numpy ; il n'est pas
nécessaire (glissade sur gravier tirée du n° 9). Le propriétaire peut ne pas le télécharger.

Non vérifié : tout le rendu en jeu (aucun son envoyé), la charge réseau des deux valeurs ajoutées (envoi seulement si
une valeur change, au plus `InputSendRateHz` fois par seconde comme avant).

En attente : le téléchargement des enregistrements du §3 par le propriétaire.

## 7. Boucles version 1 et validation à l'écoute (2026-11-06)

Les 9 fichiers ont été téléchargés par le propriétaire le 2026-11-06. Inspection, licences, extraits retenus et
mesures : `docs/audio/SONS_TIERS.md` § 2. Outil : `tools/audio/tire_loops.py` (commit b2b1840).

Fichiers d'écoute remis au propriétaire :
- `build/audio/tires/ecoute_boucles.wav` : chaque boucle trois fois ;
- `build/audio/tires/demo_pneus.wav` : 47 s, pneus seuls, d'après le relevé de la dynamique de la Brio.

Réponse du propriétaire : « C'est bon ». C'est un essai humain d'écoute sur des fichiers, pas un essai en jeu.

Sons à envoyer sur Roblox par le propriétaire : `build/audio/tires/a_envoyer/`. Le dossier contient 6 fichiers WAV
(48 kHz, mono, 1,2 Mo au total). Chaque nom `tire_<nom>` correspond à la ressource `audio.effect.tire.<nom>` (le
`_` remplace le `.`), sauf `squeal` et `scrub`, inchangés.

Retour attendu : un `.rbxm` des 6 objets Sound, enregistré dans `aw-vm-exchange` sous un nom préfixé `audio03_`.
L'assistant y relève les identifiants avec Lune (propriété `AudioContent`), puis les reporte au manifeste. Aucun
identifiant n'est saisi à la main.

## 8. Hors périmètre

- Chocs de suspension, bosses, plaques d'égout, crevaison, vent : possibles plus tard, à proposer.
- Klaxon, portes, frein à main (le bruit du levier) : hors de ce lot.
- Aucune publication Roblox par l'assistant.
