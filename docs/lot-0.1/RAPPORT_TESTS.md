# Rapport de tests — lot 0.1 (vertical slice véhicule)

**Date** : 2 novembre 2026 · **Branche** : `feat/vehicle-vertical-slice-0.1` · **Version** : `0.1.0-dev`

> **Synthèse.** Les essais Roblox Studio ont été **réalisés automatiquement dans la VM VMware de test**
> (Studio 0.745.0.7451137), sans utiliser le bureau, la souris ni le clavier de l'utilisateur :
> **154 contrôles réussis sur 154** lors de la dernière exécution complète (sessions solo, deux joueurs,
> deux joueurs avec ~205 ms de latence mesurée), avec **81 captures d'écran réelles** de la VM. Le prototype est pilotable et réagit progressivement dans le
> moteur Roblox réel (0–100 km/h ≈ 8,5 s, 100–0 km/h ≈ 47,5 m).
> **Restent non vérifiés** : la lecture réelle du clavier et de la manette (les commandes sont injectées par un point
> d'accès réservé à Studio), la manette, les collisions entre véhicules, la bosse, le slalom, la remise sur roues d'un véhicule réellement renversé,
> le retour automatique au plot, le ressenti et le son.

## 1. Environnement

| Élément | Valeur constatée |
|---|---|
| Système | Windows 11 Pro 10.0.26200 |
| Rojo | 7.7.1 (via Rokit 1.2.0) |
| Selene | 0.27.1 (bibliothèque standard `roblox` déjà présente en cache local) |
| StyLua | 0.20.0 |
| luau-lsp | 1.70.1 + définitions officielles `globalTypes.d.luau` du tag `1.70.1` (SHA-256 `2857efa8…7080`, 851 435 octets), hors dépôt |
| Lune | 0.11.1 |
| Python / pytest | 3.12.7 / 7.4.3 |
| Git | 2.47.1 |
| Roblox Studio | 0.745.0.7451137, **dans la VM VMware « ROBLOX DEV »** (Windows 11, compte de test), jamais sur le bureau de l'hôte |

Le dossier reçu n'était pas un dépôt Git : il a été initialisé, le socle 0.0.1 reçu a été validé tel quel sur `main`,
puis tout le travail a été fait sur `feat/vehicle-vertical-slice-0.1`. Aucun dépôt distant, aucun push.

## 2. Commandes exécutées et résultats observés

Toutes ces commandes sont regroupées dans `scripts\verify.ps1` (dernière exécution complète : code de sortie 0).

| # | Commande | Résultat observé |
|---|---|---|
| 1 | `rojo build -o build\AutomotiveWorld.rbxlx` (socle 0.0.1, avant modification) | OK — le socle reçu construisait sans erreur |
| 2 | `python -m pytest -q tests` (socle 0.0.1) | 4 réussis |
| 3 | `rojo build -o build\AutomotiveWorld.rbxlx` (lot 0.1) | OK |
| 4 | `selene src` | 0 erreur, 0 avertissement (1 avertissement d'ombrage de variable corrigé en cours de route) |
| 5 | `stylua --check src tests\lune` | OK |
| 6 | `rojo sourcemap …` puis `luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --definitions=@roblox=… src` | 0 erreur en mode strict (2 erreurs de typage réelles corrigées : `DevHud`, `WheelVisuals`) |
| 7 | `lune run tests\lune\run.luau build\AutomotiveWorld.rbxlx` | **66 réussis, 0 échoué** |
| 8 | `python -m pytest -q tests` | **8 réussis** |

### Ce que couvrent les 66 tests Lune

Les modules sont lus **dans la place `.rbxlx` produite par Rojo** (l'artefact réel), avec la vraie arborescence
`script.Parent` ; seuls les modules sans service Roblox peuvent y être exécutés.

- **Structure de la place** (4) : arborescence et classes (Script / LocalScript / ModuleScript), aucun script exécutable
  dans l'espace partagé, code serveur non répliqué, recherche de motifs interdits dans **toutes** les sources
  (DataStore, MemoryStore, MarketplaceService/ProcessReceipt, InsertService, `loadstring`, `require(<id>)`,
  requêtes HTTP, TeleportService, manipulation de crédits), commentaires présents.
- **Définitions** (15) : le prototype est valide, gelé récursivement, marqué prototype ; refus des motorisations,
  boîtes et aides non implémentées, des incohérences de transmission, des valeurs nulles/NaN, d'un ressort qui talonne.
- **Physique unitaire** (18) : courbe de pneu, ellipse de friction, anti-dépassement, blocage de roue au freinage,
  roue libre, **cohérence couple/force en régime établi**, patinage borné, suspension, courbe de couple, rapports,
  répartition RWD/FWD/AWD (calcul seul), logique de marche arrière, revêtements.
- **Défenses réseau** (15) : décodage défensif des commandes (NaN, infini, types, champs manquants, non-table, nil),
  plausibilité des mouvements (normal, à-coup réseau toléré, suspect, survitesse, téléportation, non fini),
  limiteur de débit.
- **Mesures locales** (4) : logique 0–100 km/h et 100–0 km/h, annulations.
- **Scénarios de conduite sur banc planaire** (10) : immobilité frein à main serré, accélération progressive bornée
  par l'adhérence avec montée des rapports, freinage jusqu'à l'arrêt, roue libre, marche arrière, virages droite
  et gauche (signe du lacet), vitesse de pointe finie, stabilité numérique à 30 et 240 Hz.

### Défaut réel trouvé et corrigé grâce aux tests

La première version de l'intégration de la roue équilibrait le couple moteur avec une force de pneu **linéaire**,
alors que la force transmise au châssis suivait la courbe **non linéaire** : environ 25 % de la force motrice
disparaissait en régime établi (0–100 km/h du modèle à 10,6 s au lieu de ~8,4 s). Correction : linéarisation autour
du glissement courant (`TireModel.integrateWheel`) et vitesse de référence basse portée à 4 m/s pour garder la
raideur du pneu sous le seuil de stabilité de l'intégration du châssis. Un test de non-régression a été ajouté.

### Valeurs produites par le modèle (banc planaire, hors Roblox — NE SONT PAS des mesures en jeu)

| Grandeur | Valeur du modèle |
|---|---|
| 0–100 km/h (pas 1/60 s) | 8,37 s ; accélération max 4,72 m/s² |
| 100–0 km/h, freinage total, sans ABS | 40,2 m ; décélération max 9,99 m/s² |
| Virage à 60 km/h, braquage 60 % | accélération latérale max 8,79 m/s² |
| Vitesse de pointe (traînée Cx·S 0,66 m²) | 224 km/h |
| Vitesse cinématique au rupteur en 6ᵉ | 293 km/h (borne, pas une performance) |

Le banc planaire remplace le moteur physique Roblox par un modèle 2D (transferts de charge quasi statiques,
inertie de lacet d'une boîte uniforme). Comparaison avec les mesures faites ensuite dans Studio (§4.2) :
0–100 km/h ≈ 8,5 s en jeu contre 8,37 s pour le modèle ; 100–0 km/h ≈ 47,5 m en jeu contre 40,2 m :
le freinage réel est plus long que dans le banc planaire (transferts de charge et roues 3D non représentés).

## 3. Moyens et limites des tests disponibles

| Moyen | Ce qu'il prouve | Ce qu'il ne prouve pas |
|---|---|---|
| Rojo build | Le projet se construit ; l'arborescence est conforme | Que les scripts s'exécutent sans erreur |
| Selene (std `roblox`) | Syntaxe, API globales connues, variables douteuses | Typage, comportement |
| luau-lsp strict + définitions Roblox | Cohérence des types et des appels d'API Roblox | Le comportement à l'exécution (physique, réplication, ordre des événements) |
| Lune sur la place construite | Logique pure : dynamique, validation, codec, mesures, structure, motifs interdits | Tout ce qui dépend du moteur : rayons, `VectorForce`, propriété réseau, sièges, caméra, interface |
| Banc planaire | Signes, bornes physiques, stabilité numérique de la dynamique pure | Le comportement 3D réel (roulis, tangage, collisions, intégration Roblox à 240 Hz) |
| pytest | Règles d'architecture (séparation, autorité serveur, typage strict, aucun actif externe) | Le fonctionnement |
| Tests Studio dans la VM (`test-vm.cmd`) | Le jeu réel dans Studio : physique, propriété réseau, sièges, caméra, HUD, serveur, deux clients, latence | La lecture réelle des touches et de la manette, le rendu visuel, le ressenti |

Points qui **exigent** Roblox Studio (couverts depuis par les tests dans la VM, §4) : création de la zone et des véhicules au démarrage, appui des suspensions,
`Seat:Sit` avec `CanTouch = false`, transfert de propriété réseau, simulation côté client, animation des roues
par `Motor6D.Transform`, caméra scriptée, HUD, sortie et dépôt du personnage, correction serveur, réplication
entre deux clients, comportement sous latence.

## 4. Essais Roblox Studio — réalisés dans la VM (automatisés)

Méthode et outillage : [docs/VM_TESTS.md](../VM_TESTS.md). `test-vm.cmd` construit la place et le pilote, la VM
exécute `RobloxStudioBeta.exe --task RunScript`, le pilote lance les sessions par `StudioTestService`
(`ExecutePlayModeAsync`, `ExecuteMultiplayerTestAsync(2)`), et chaque session renvoie ses contrôles.
Rapport complet de la dernière exécution : [RAPPORT_STUDIO_VM.md](RAPPORT_STUDIO_VM.md) (tâche `20261102-141650`).

### 4.1 Historique des exécutions (2 novembre 2026)

| Tâche | Résultat | Cause / correction |
|---|---|---|
| 133427 | Pilote arrêté avant la 1ʳᵉ session | `RunService:GetRobloxVersion()` interdit en RunScript (« lacking capability RobloxScript ») → `pcall(version)` |
| 133558 | 114 ✅ / 4 ❌ | Suite de test : les deux clients se choisissaient le même véhicule ; erreur interne de Roblox (`ChatScript … CoreGuiChatConnections`) comptée à tort → attribution par le serveur, erreurs Roblox séparées |
| 134054 | 144 ✅ / 3 ❌ | Suite de test : le joueur 2 se téléportait contre le véhicule du joueur 1 pendant son départ → synchronisation |
| 134557 | 147 ✅ / 2 ❌ | **Défaut réel du jeu** : en multijoueur, la sortie laissait parfois le personnage dans l'habitacle (déplacement serveur écrasé par la position envoyée par le client) → `VehicleService` attend la libération du siège, place, vérifie et recommence au besoin |
| 135040 | 146 ✅ / 3 ❌ | Sortie corrigée partout ; mesures post-correction et au repos faussées par le calendrier du test → mesure de l'état final, joueur 2 éloigné avant les mesures |
| 135529 | **149 ✅ / 0 ❌** | — |
| 140007 | **149 ✅ / 0 ❌** | Mesure 100–0 du HUD relevée (lecture décalée d'une image) |
| 141222 | 33 ✅ / 0 ❌ (solo) | Exclusion Defender `C:\AWTests` ajoutée dans la VM par l'utilisateur : **32 captures**. Elles révèlent un **défaut visuel** : la tête du conducteur traverse le toit |
| 141509 | 33 ✅ / 1 ❌ (solo) | Nouveau contrôle mesuré : tête **0,38 st au-dessus** du dessous du toit (0,72 st avec accessoires) |
| 141650 | **154 ✅ / 0 ❌** | Habitacle porté à 1,62 m et assise abaissée de 0,45 st : marge **+0,68 st** (+0,34 st avec accessoires) ; 81 captures |

### 4.2 Résultats des dernières exécutions (tâches 140007 et 141650)

| # | Essai | Résultat observé dans Studio |
|---|---|---|
| S1 | Démarrage | zone (116 instances), 4 véhicules, 3 canaux réseau ; **aucune erreur de notre code** (serveur et clients) |
| S2 | Véhicules posés | 4 véhicules à Y ≈ 1,77–1,78 st, vitesse ≤ 0,09 st/s, droits (UpVector.Y = 1,000) ; véhicules non utilisés immobiles (≤ 0,03 st) |
| S3 | Embarquement | par l'invite de proximité (même chemin que la touche E) ; caméra scriptée et HUD affichés ; propriété réseau attribuée au conducteur ; tête du conducteur 0,68 st sous le toit |
| S4 | Accélération | ≈ 3,4 km/h à 0,25 s, ≈ 14,5 km/h à 1 s ; 0–100 km/h **8,55–8,65 s** (horloge client), **8,45–8,60 s** (HUD) ; rapports jusqu'au 3ᵉ |
| S5 | Freinage | depuis ≈ 100 km/h : **47,5–48,8 m** en ≈ 3,4 s (HUD : 45,1–46,2 m, mesuré dès le passage sous 100 km/h) |
| S6 | Marche arrière | rapport R enclenché à l'arrêt, ≈ −7,4 m/s après 2,5 s |
| S7 | Virages | à ≈ 40 km/h, braquage 60 % : +77° à droite, −65° à gauche en 2 s (l'écart vient du contre-braquage depuis le virage précédent) |
| S8 | Frein à main | véhicule maintenu à l'arrêt (déplacement 0,00 st en 2 s) |
| S9 | Caméra | proche 14,5 st, lointaine 24,0 st (bascule par le même code que la touche V) |
| S11 | Sortie | refusée au-dessus de 20 km/h (notification) ; à l'arrêt : personnage déposé à 6–7 st, caméra rétablie, véhicule libéré |
| S12 | Remise sur roues | **seul le refus** sur un véhicule droit est vérifié |
| — | Mouvement impossible | téléportation de 400 st par le client propriétaire : **corrigée par le serveur** (1 correction par essai, aucune sanction) ; écart final ≤ 2,0 st après retour au conducteur |
| M1 | Deux joueurs | chacun conduit son véhicule ; mêmes résultats que S3–S11 pour les deux |
| M2 | Véhicule occupé | le 2ᵉ joueur ne peut pas le prendre (invite désactivée, conducteur inchangé) |
| M3 | Observation croisée | chaque client voit le conducteur de l'autre véhicule (attribut répliqué) — **le rendu des roues n'est pas vérifié** |
| M5 | Propriété réseau | conducteur propriétaire sur 68–140 échantillons ; seuls discordants : pendant les corrections volontaires |
| Lat. | Latence | réglage Studio de 100 ms par sens : ping **mesuré 203–216 ms** ; tous les contrôles réussis |

Observations : à la première tentative, l'invite d'embarquement déclenchée par script juste après la téléportation
du personnage n'atteint pas toujours le serveur (2ᵉ tentative réussie) ; sous latence, la vue du client reste
décalée de 17 à 70 st pendant ~0,5 s après une correction serveur, puis se recale.

### 4.3 Encore à vérifier par un humain (ou par une version future des tests)

| # | Point | Pourquoi |
|---|---|---|
| S9/M3 | Caméra contre les murets, roues des autres véhicules vues depuis l'autre client | Non scénarisés (les captures ne montrent que la vue du client principal) |
| S4–S8 | Clavier (Z/W, S, Q/A/D, Espace) et sensation de conduite | Commandes injectées par le point d'accès de test |
| S13 | Manette | Aucune manette (réelle ou virtuelle) dans la VM |
| S7/S10 | Slalom, cercle de 30 m, bosse à 10 % | Non scénarisés |
| S12 | Remise sur roues d'un véhicule renversé | Non scénarisé |
| S14 | Retour automatique au plot (90 s) | Non scénarisé |
| M4 | Collision entre deux véhicules | Non scénarisé |

## 5. Captures et vidéos

Captures **réellement produites** par la VM (une toutes les 2 s pendant les sessions), après l'ajout par l'utilisateur
d'une exclusion Windows Defender limitée à `C:\AWTests` **dans la VM** (Defender bloquait la capture d'écran depuis
PowerShell ; il n'a pas été contourné). Aucune vidéo. Sélection archivée dans [captures/](captures/) :

| Fichier | Contenu |
|---|---|
| `01-avant-tete-traverse-le-toit.jpg` | Avant correction : cheveux du conducteur au-dessus du toit orange |
| `02-apres-tete-sous-le-toit.jpg` | Après correction, à 69 km/h en 2ᵉ : tête sous le toit, derrière le vitrage |
| `03-sortie-a-pied-invite-conduire.jpg` | Sortie à l'arrêt : personnage à côté de la portière, invite « Conduire » |
| `04-teleportation-volontaire-avant-correction.jpg` | Véhicule téléporté à 400 st par le test, juste avant la correction serveur |
| `05-hud-et-repere-150m.jpg` | HUD (vitesse, rapport, barres) et panneau « 150 m » de la ligne droite |

Toutes les captures de chaque exécution restent dans `build\vm-exchange\jobs\<id>\report\screenshots` (non versionnées).

## 6. Fichiers créés ou modifiés

**Modifiés** : `.gitignore`, `README.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `rokit.toml`,
`src/client/Bootstrap.client.luau`, `src/server/Bootstrap.server.luau`, `src/shared/ProjectSettings.luau`,
`tests/test_scaffold.py`.

**Créés** :
- Configuration : `.gitattributes`, `selene.toml`, `stylua.toml`, `scripts/verify.ps1`.
- Partagé : `src/shared/Vehicles/{VehicleTypes, VehicleConstants, VehicleDefinitions, VehicleSimulator, InputCodec, Telemetry}.luau`,
  `src/shared/Vehicles/Definitions/PrototypeP01.luau`,
  `src/shared/Vehicles/Physics/{TireModel, Suspension, Powertrain, VehicleDynamics, SurfaceFriction}.luau`.
- Serveur : `src/server/Vehicles/{VehicleService, VehicleFactory}.luau`, `src/server/World/TestZoneBuilder.luau`,
  `src/server/Security/{MovementRules, RateLimiter}.luau`.
- Client : `src/client/Vehicles/{VehicleController, DriverInput, VehicleCamera, WheelVisuals}.luau`,
  `src/client/UI/{DevHud, Messages}.luau`.
- Tests : `tests/lune/{run, Harness, TestKit, PlanarSim}.luau`,
  `tests/lune/specs/{PlaceStructure, Definitions, PhysicsUnit, NetworkSecurity, TelemetrySpec, DrivingScenarios}.luau`.
- Documentation : `docs/lot-0.1/{RAPPORT_TESTS, ECARTS, PROPOSITION_LOT_0.2, RAPPORT_STUDIO_VM}.md`, `docs/VM_TESTS.md`.
- Tests Studio et VM : `tests/studio/{Driver.template, ServerSuite.server, ClientSuite.client, build-driver}.luau`,
  `tools/vm/{host-run, guest-agent, guest-setup, job-runner, capture-screens, make-report}.ps1`, `test-vm.cmd`.
- Modifiés pour les essais Studio : `src/client/Vehicles/VehicleController.luau` (points d'accès réservés à Studio),
  `src/server/Vehicles/VehicleService.luau` (correction de la sortie en multijoueur),
  `src/server/Vehicles/VehicleFactory.luau` et `Definitions/PrototypeP01.luau` (habitacle et assise).
- Captures : `docs/lot-0.1/captures/*.jpg`.
