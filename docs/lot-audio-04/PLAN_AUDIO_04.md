# Lot AUDIO-04 — bruits de collision

Branche : `feat/audio-04-collisions` (worktree, depuis `main` af0cd49). Plan rédigé le 2026-11-06.

Demande du propriétaire (2026-11-06) : « ajouter aussi les bruits de collision (murs, voitures) ». Mêmes règles que
pour AUDIO-03 :
- **sources** : enregistrements libres CC0 ou CC BY, téléchargés par le propriétaire ;
- **écoute** : démos à écouter avant tout envoi ;
- **envoi** : sons envoyés sur Roblox par le propriétaire ;
- **tests en jeu** : aucun essai Studio automatique.

## 1. État de départ (vérifié le 2026-11-06)

- **Aucun bruit de choc n'est joué.** `audio.effect.impact` (lot 0.8) est un son synthétique jamais envoyé et branché
  nulle part. Il reste au manifeste, inchangé.
- **Détection serveur des chocs** (`DamageService`, AUD-COLL-01) :
  1. une variation de vitesse impossible pour les pneus (au-delà de 1,3 × 1,25 × g, plus une tolérance) coïncide avec
     un obstacle au contact au-dessus des roues ;
  2. un suivi de **0,4 s** mesure le Δv total ;
  3. les dégâts sont appliqués (seuil `DamageModel.MinImpact` = 1,5 m/s).

  Une optique cassée reçoit l'attribut `AWLightBroken`, qui est répliqué.
- **Délai trop long pour un son** : la confirmation arrive 0,4 s après le choc, plus la réplication.
- **Collisions entre véhicules** : `CollisionMediator` et `Physics/CollisionExchange` (complément d'impulsion
  confirmé par le serveur).

## 2. Modèle proposé

Module pur `src/shared/Audio/CollisionAudioModel.luau`, testé par Lune.

| Son | Déclencheur | Réglage |
|---|---|---|
| Choc contre le décor | Δv horizontal impossible pour les pneus, obstacle fixe au contact | volume et sous-variante selon le Δv (léger < 4 m/s, moyen < 9 m/s, fort au-delà) ; hauteur variée de ±5 % |
| Choc contre un objet léger | même déclencheur, obstacle mobile et léger (cônes, barrières non ancrées) | plus sourd, plus court |
| Choc entre véhicules | même déclencheur, obstacle = autre véhicule | tôle froissée ; intensité selon la vitesse de rapprochement |
| Bris de verre | une optique passe à `AWLightBroken` | un éclat par optique |
| Raclement (boucle) | carrosserie au contact d'un obstacle en mouvement (glissement le long d'un mur) | volume et hauteur selon la vitesse de glissement |

Sources de déclenchement :
- **Véhicule conduit** : la détection est **locale et immédiate**, d'après la vitesse simulée et une recherche
  d'obstacle autour de la caisse (même principe que `DamageService`, seuil plus bas pour les petits chocs). C'est
  purement sonore, sans effet de jeu.
- **Autres joueurs** :
  - le serveur diffuse le choc **dès l'ouverture de son suivi** (et non à sa confirmation) : véhicule, position,
    intensité, type d'obstacle ; c'est une valeur observée par le serveur, jamais envoyée par un client ;
  - le raclement est détecté localement par chaque client, pour les véhicules proches ;
  - le conducteur ignore la diffusion de son propre choc, déjà joué localement ;
  - un choc entre deux véhicules n'est joué qu'une fois par client.
- **Écoute** : catégorie de volume et égaliseur d'habitacle comme les pneus (question Q4).

## 3. Enregistrements candidats (Freesound, relevés le 2026-11-06, tous CC0)

L'assistant ne peut pas écouter. Licences et formats ont été lus sur chaque page, à reconfirmer au téléchargement.
Dossier : `E:\ROBLOX DEV\aw-sound-references\collisions\freesound\`. Garder les noms d'origine.

| # | Fichier (lien) | Auteur | Format relevé | Usage prévu |
|---|---|---|---|---|
| 1 | S021 Metal Impact — <https://freesound.org/s/385937/> | Pól (pack « Foundation Sound Effects », voiture de rallye) | WAV 48 kHz 24 bits mono, 1,5 s | choc contre du métal (glissières, poteaux) |
| 2 | S020 Rock Impact — <https://freesound.org/s/385938/> | Pól | WAV 48 kHz 24 bits mono, 0,75 s | choc contre un mur, du béton, de la roche |
| 3 | S022 Plastic Impact — <https://freesound.org/s/385940/> | Pól | WAV 48 kHz 24 bits mono, 1,0 s | objet léger, petits chocs |
| 4 | S023 Metal Rail Scrape — <https://freesound.org/s/385939/> | Pól | WAV 48 kHz 24 bits mono, 4,25 s | raclement le long d'un mur ou d'une glissière |
| 5 | Car Crash M-S — <https://freesound.org/s/346301/> | PauliusI (vraie Peugeot 406 contre une Ford Ka) | WAV 48 kHz 24 bits stéréo, 10,0 s | choc entre véhicules |
| 6 | Glass Smash — <https://freesound.org/s/848312/> | dwswords | WAV 48 kHz 16 bits stéréo, 2,7 s | bris d'optique |
| 7 | S019 Landing Impact — <https://freesound.org/s/385933/> | Pól | (pack ci-dessus) | réception brutale d'un saut, **seulement si Q2 = oui** |

Écartés : les enregistrements « vintage » de craigsmith (copies de bandes de cinéma, bruit de fond), et les
assemblages ou effets retravaillés (bols, outils, armes).

## 4. Décisions du propriétaire (2026-11-06)

Les quatre questions ont été posées en une fois ; le propriétaire a retenu chaque recommandation.

| Id | Sujet | Décision |
|---|---|---|
| Q1 | Familles de chocs | **décor dur, objet léger, véhicule contre véhicule**, plus le **bris des optiques** |
| Q2 | Réception de saut | **non**, plus tard : le fichier n° 7 n'est pas à télécharger |
| Q3 | Chocs des autres joueurs | **diffusés par le serveur** dès la détection ; raclement détecté localement |
| Q4 | Réglage de volume | **« Effets »**, étouffé en vue cockpit |

## 5. Avancement (2026-11-06)

Travail fait pendant le téléchargement : il ne dépend pas des enregistrements. Contrôle par
`scriptserify.ps1 -DownloadRobloxTypes` le 2026-11-06 : toutes les étapes OK, Lune 460 sur 460 (dont 7 tests
`Audio04`), pytest 33 sur 33 (dont 4 tests `test_audio04.py`).

| Travail | Fichiers | Détail |
|---|---|---|
| Modèle pur | `Shared/Audio/CollisionAudioModel` | Familles d'obstacles, Δv en excès sur les pneus, sept sons (choc léger et lourd contre le décor, objet, choc léger et lourd entre véhicules, verre, raclement), volume et hauteur |
| Diffusion serveur | `DamageService`, `VehicleService`, `VehicleConstants` | Canal `VehicleImpactSound` (UnreliableRemoteEvent, serveur → clients ; le serveur n'y écoute rien). Le choc est émis dès l'**ouverture** du suivi, avec l'intensité observée par le serveur ; le bris d'optique est émis une fois, au passage à « cassée ». La détection des dégâts est inchangée |
| Client | `AudioController` | Véhicule conduit : choc détecté localement à chaque image (vitesse simulée, obstacle au contact), raclement toutes les 0,05 s. Véhicules observés : chocs diffusés par le serveur, raclement local pour les plus proches. Arguments reçus vérifiés ; le choc du conducteur n'est pas rejoué ; un choc entre deux véhicules n'est entendu qu'une fois |
| Manifeste | `AssetManifest` (section AUDIO-04) | Sept ressources `audio.effect.collision.*`, CC0, sans identifiant ; exception de comptage dans `Lot08Content` |
| Outil | `tools/audio/collision_sounds.py` | Sons ponctuels pris à l'attaque, filtrés, fondus, crête normalisée ; boucle de raclement par grains ; démo (chocs de 2 à 14 m/s par famille, verre, raclement) |

Non vérifié :
- tout le rendu en jeu ;
- le coût des recherches de contact (une requête toutes les 0,05 s pour le véhicule conduit, toutes les 0,1 s pour
  au plus 6 véhicules observés) ;
- la charge réseau de la diffusion (un message par choc confirmé à l'ouverture et par optique cassée).

En attente : le téléchargement des enregistrements du § 3 par le propriétaire.

## 6. Hors périmètre

- Changement de la détection des dégâts ou de leurs seuils : seule une diffusion sonore est ajoutée au serveur.
- Sons de klaxon, de portes, d'alarme.
- Aucune publication Roblox par l'assistant.
