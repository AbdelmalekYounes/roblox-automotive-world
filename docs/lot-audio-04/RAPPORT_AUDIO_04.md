# Rapport du lot AUDIO-04 — bruits de collision

Branche : `feat/audio-04-collisions` (depuis `main` af0cd49, toujours à jour au 2026-11-06). Rapport rédigé le
2026-11-06. Le déroulement complet est dans [PLAN_AUDIO_04.md](PLAN_AUDIO_04.md), et le registre des sources dans
[docs/audio/SONS_TIERS.md](../audio/SONS_TIERS.md), § 3.

Demande du propriétaire (2026-11-06) : « ajouter aussi les bruits de collision (murs, voitures) ».

## 1. Décisions du propriétaire (2026-11-06)

| Id | Décision |
|---|---|
| Q1 | Familles de chocs : décor dur, objet léger, véhicule contre véhicule, plus le bris des optiques |
| Q2 | Réception de saut : non, plus tard |
| Q3 | Chocs des autres joueurs : diffusés par le serveur dès la détection ; raclement détecté localement |
| Q4 | Volume réglé par la catégorie « Effets », étouffé en vue cockpit |

## 2. Livré

| Élément | Fichiers |
|---|---|
| Modèle sonore pur, testé par Lune | `src/shared/Audio/CollisionAudioModel.luau` |
| Diffusion serveur (canal `VehicleImpactSound`, serveur → clients ; le serveur n'y écoute rien) | `DamageService` (émission à l'ouverture du suivi d'un choc et à la casse d'une optique), `VehicleService`, `VehicleConstants` |
| Lecture | `src/client/Audio/AudioController.luau` : choc du véhicule conduit détecté localement à chaque image ; chocs des autres par la diffusion ; raclement local ; aucun doublon |
| 7 sons au manifeste, avec les identifiants Roblox envoyés par le propriétaire | `AssetManifest` (table `COLLISION_SOUND_IDS`) |
| Outil de transformation (numpy seul) | `tools/audio/collision_sounds.py` |
| Tests | `tests/lune/specs/Audio04.luau` (7), `tests/test_audio04.py` (4) ; exceptions dans `Lot08Content` et `test_lot08.py` |

| Ressource | Identifiant Roblox | Source (CC0) |
|---|---|---|
| `audio.effect.collision.hard.light` | 119936631540140 | choc contre la roche, Pól (385938) |
| `audio.effect.collision.hard.heavy` | 84821488985222 | choc contre le métal, Pól (385937) |
| `audio.effect.collision.object` | 107111383496078 | choc contre le plastique, Pól (385940) |
| `audio.effect.collision.vehicle.light` | 73753197716718 | vrai choc entre voitures, impact seul, PauliusI (346301) |
| `audio.effect.collision.vehicle.heavy` | 103306869584523 | même choc, impact et débris |
| `audio.effect.collision.glass` | 73806268842632 | bris de verre, dwswords (848312) |
| `audio.effect.collision.scrape` | 126532496130819 | raclement contre une glissière, Pól (385939) |

## 3. Exécuté et mesuré

| Date | Contrôle | Résultat |
|---|---|---|
| 2026-11-06 | `scripts\verify.ps1 -DownloadRobloxTypes` au commit a40e365 | Toutes les étapes OK ; Lune **460 réussis sur 460** ; pytest **33 sur 33** ; luau-lsp strict sans erreur |
| 2026-11-06 | Analyse des enregistrements (SONS_TIERS § 3) | Impact du choc entre voitures à 3,645 s (approche écartée). Écrêtage d'origine : 3,5 % des échantillons pour le choc métal, 1,3 % pour la roche |
| 2026-11-06 | Mesures de l'outil (`rapport.json`) | Raclement : raccord de 2,35 dB, plus grand creux de 1,86 dB |
| 2026-11-06 | Relevé des identifiants : Lune, `AudioContent` de `aw-vm-exchange/audio04_collisions.rbxm` (SHA-256 `0026b85c…`) | 7 objets Sound, 7 identifiants distincts, noms conformes (`collision_<nom>`) |
| 2026-11-06 | **Essai humain d'écoute** de `demo_collisions.wav` par le propriétaire | « C'est bon ». C'est une écoute de fichier, pas un essai en jeu |

Place de test : `build/AW-AUDIO-04.rbxlx`, construite par `rojo build default.project.json -o build/AW-AUDIO-04.rbxlx`
au commit a40e365. Elle contient aussi les sons de pneus (AUDIO-03) et l'antipatinage actif au départ (A-02), déjà
dans `main`.

## 4. Validation en jeu et points non vérifiés

**Validation en jeu par le propriétaire (2026-11-06).** Il a joué `build/AW-AUDIO-04.rbxlx` (commit a40e365) dans
Studio et a répondu **« Tout est bon »**. C'est un essai humain du propriétaire ; l'assistant n'a exécuté aucun essai
Studio. La réponse porte sur l'ensemble de la liste du § 5, sans détail point par point.

Non vérifié :
- **Points du § 5 dépendant de la carte ou de la configuration** : l'objet léger (selon les objets présents) et
  l'essai à deux joueurs. Ils ne sont pas détaillés dans la réponse.
- **Coût des recherches de contact** : une requête toutes les 0,05 s pour le véhicule conduit, toutes les 0,1 s pour
  au plus 6 véhicules observés.
- **Charge réseau de la diffusion** : un message par choc et par optique cassée, sur un canal non fiable.
- **Délai réel** entre un choc d'un autre joueur et son son ; il est estimé à 0,1 à 0,2 s, sans mesure.

## 5. Liste de vérification en jeu (propriétaire)

Ouvrez `build/AW-AUDIO-04.rbxlx` dans Studio et lancez « Jouer » (environnement Dev). Prenez la Brio ou la Comète par
le menu d'administration (F2), puis montez à bord. Réglez le volume « effets » au maximum.

1. **Petit choc** : avancez doucement (~10 km/h) contre un mur. Un choc sourd et court, joué tout de suite.
2. **Choc violent** : percutez un mur à 40–60 km/h. Un choc fort et métallique, sans retard.
3. **Bris de verre** : après un choc frontal assez fort (optique cassée), un bruit de verre suit, à peu près 0,4 s
   après le choc.
4. **Raclement** : longez un mur en l'effleurant vers 30 km/h. Un raclement continu, qui s'arrête dès que la voiture
   s'écarte du mur.
5. **Appui à l'arrêt** : restez arrêté contre le mur. Aucun bruit.
6. **Choc entre véhicules** : faites apparaître un second véhicule (F2) et percutez-le. On entend une tôle froissée,
   **une seule fois**.
7. **Objet léger** (cône ou barrière mobile, si la carte en a ; sinon, point à marquer « non testé ») : un choc plus
   doux, plastique.
8. **Vue cockpit** (**V**) : les chocs sont plus étouffés.
9. **Réglages** : le volume « effets » règle les chocs.
10. **À deux joueurs** (Studio : Test › Clients et serveurs, 2 joueurs) : quand l'autre joueur percute un mur ou une
    voiture près de vous, vous l'entendez. Ses raclements le long d'un mur aussi.

## 6. Écarts et limites

- **Écrêtage d'origine** des chocs métal et roche : il ne peut pas être corrigé. Il a été jugé acceptable à l'écoute
  de la démo.
- **Seuils de son** : la détection locale du véhicule conduit est plus sensible que celle des dégâts. Un petit choc sous
  1,5 m/s fait du bruit sans faire de dégâts.
- **Chocs d'un autre joueur** : ils sont entendus à partir de la détection du serveur, donc seulement s'il dépasse le
  seuil des dégâts (1,5 m/s). Les petits chocs des autres sont muets.
- **Fichiers partagés** : seulement des ajouts dans `AssetManifest`, `tests/lune/run.luau` et `SONS_TIERS.md`, plus
  l'adaptation des deux contrôles d'identifiants. La détection des dégâts (`DamageService`) est inchangée ; seule
  l'émission sonore s'y ajoute.
