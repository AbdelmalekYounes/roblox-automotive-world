# Rapport de tests — lot 0.1 (vertical slice véhicule)

**Date** : 2 novembre 2026 · **Branche** : `feat/vehicle-vertical-slice-0.1` · **Version** : `0.1.0-dev`

> **Synthèse honnête.** Tout ce qui peut être vérifié sans lancer Roblox Studio a été exécuté et passe.
> **Aucun essai n'a été réalisé dans Roblox Studio** : ni spawn, ni embarquement, ni conduite, ni caméra,
> ni sortie, ni session à deux clients, ni latence simulée. Aucune capture ni vidéo n'a été produite.
> Le critère de clôture du lot (« voiture pilotable qui réagit progressivement ») **n'est donc pas encore démontré en jeu** :
> il l'est seulement pour le modèle physique pur, sur un banc hors Roblox.

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
| Roblox Studio | installé (`version-7062aec9dbe74b14`) — **non lancé** |

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
inertie de lacet d'une boîte uniforme). Les valeurs en jeu **différeront** ; elles devront être relevées en Studio
avec les mesures du HUD.

## 3. Moyens et limites des tests disponibles

| Moyen | Ce qu'il prouve | Ce qu'il ne prouve pas |
|---|---|---|
| Rojo build | Le projet se construit ; l'arborescence est conforme | Que les scripts s'exécutent sans erreur |
| Selene (std `roblox`) | Syntaxe, API globales connues, variables douteuses | Typage, comportement |
| luau-lsp strict + définitions Roblox | Cohérence des types et des appels d'API Roblox | Le comportement à l'exécution (physique, réplication, ordre des événements) |
| Lune sur la place construite | Logique pure : dynamique, validation, codec, mesures, structure, motifs interdits | Tout ce qui dépend du moteur : rayons, `VectorForce`, propriété réseau, sièges, caméra, interface |
| Banc planaire | Signes, bornes physiques, stabilité numérique de la dynamique pure | Le comportement 3D réel (roulis, tangage, collisions, intégration Roblox à 240 Hz) |
| pytest | Règles d'architecture (séparation, autorité serveur, typage strict, aucun actif externe) | Le fonctionnement |

Points qui **exigent** Roblox Studio : création de la zone et des véhicules au démarrage, appui des suspensions,
`Seat:Sit` avec `CanTouch = false`, transfert de propriété réseau, simulation côté client, animation des roues
par `Motor6D.Transform`, caméra scriptée, HUD, sortie et dépôt du personnage, correction serveur, réplication
entre deux clients, comportement sous latence.

## 4. Essais Roblox Studio — NON RÉALISÉS, procédure à exécuter

Aucune interaction graphique n'a été effectuée pendant ce lot. Procédure proposée (≈ 30 min) :

**Préparation**
1. `rojo build -o build\AutomotiveWorld.rbxlx`, ouvrir le fichier dans Studio, **ne pas publier**.
2. Vérifier que « Enable Studio Access to API Services » est **désactivé** (Game Settings > Security).
3. Ouvrir la fenêtre Output pour relever les messages `[AutomotiveWorld]` et toute erreur.

**Essai solo (Play)**

| # | Étape | Résultat attendu | Constaté |
|---|---|---|---|
| S1 | Lancer Play | Output : « 4 véhicules d'essai … prêts » puis « Serveur … initialisé » ; aucune erreur rouge | ☐ |
| S2 | Spawn | Personnage sur la plateforme bleue ; bannière « Zone d'essai véhicule » ; 4 prototypes immobiles sur leurs plots, roues au sol, sans rebond persistant | ☐ |
| S3 | Embarquement | Invite « Conduire » à la portière gauche ; maintien E → personnage assis ; HUD visible ; caméra derrière le véhicule | ☐ |
| S4 | Accélération | Z/W : départ progressif (pas de vitesse instantanée), rapports qui montent, régime cohérent ; relever le 0–100 du HUD | ☐ |
| S5 | Freinage | S à fond depuis > 100 km/h : décélération franche, possible blocage des roues (pas d'ABS) ; relever le 100–0 du HUD | ☐ |
| S6 | Marche arrière | À l'arrêt, maintenir S : « R » au HUD après ~0,3 s, le véhicule recule ; Z freine puis repasse en 1ʳᵉ | ☐ |
| S7 | Virages | Q/A et D : braquage progressif, moins d'angle à haute vitesse ; slalom de cônes ; cercle de 30 m | ☐ |
| S8 | Frein à main | Espace en virage : arrière qui décroche ; à l'arrêt : véhicule maintenu | ☐ |
| S9 | Caméra | V : bascule proche/lointaine (message) ; pas de traversée des murets | ☐ |
| S10 | Bosse à 10 % | Montée/descente sans décollage anormal ni oscillation persistante | ☐ |
| S11 | Sortie | F au-dessus de 20 km/h → message de refus ; à l'arrêt → personnage déposé à gauche, caméra et déplacements normaux rétablis | ☐ |
| S12 | Remise sur roues | Véhicule renversé et immobile : R → remis à l'endroit ; second appui → délai affiché | ☐ |
| S13 | Manette | Refaire S3–S11 à la manette ; l'aide du HUD bascule sur les boutons manette | ☐ |
| S14 | Retour au plot | Abandonner un véhicule loin de son plot : retour automatique après ~90 s si personne n'est proche | ☐ |

**Essai multijoueur (onglet Test > Clients and Servers, 2 joueurs)**

| # | Étape | Résultat attendu | Constaté |
|---|---|---|---|
| M1 | Deux joueurs montent dans deux véhicules différents | Chacun conduit le sien ; aucun échange de commandes ni d'état | ☐ |
| M2 | Le joueur 2 tente l'invite d'un véhicule occupé | Invite masquée ou message « déjà occupé » | ☐ |
| M3 | Observation croisée | Chaque client voit l'autre véhicule bouger, roues qui tournent et braquent | ☐ |
| M4 | Collision entre les deux véhicules | Contact physique crédible, pas d'éjection ni de correction serveur intempestive | ☐ |
| M5 | Propriété réseau (Studio Settings > Physics > « Are Owners Shown ») | Véhicule conduit : propriétaire = son conducteur ; véhicule libre : serveur | ☐ |

**Latence** : dans File > Studio Settings > Network, régler « Incoming Replication Lag » (par ex. 0,15 puis 0,3 s ;
nom du réglage à confirmer dans la version de Studio installée) puis refaire M1, M3, M4 et S11. Attendu : conduite
toujours réactive pour le conducteur, aucune correction « mouvement impossible » en conduite normale.
Relever dans Output tout message `[Validation]`.

## 5. Captures et vidéos

Aucune capture ni vidéo n'a été produite : Studio n'a pas été lancé.

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
- Documentation : `docs/lot-0.1/{RAPPORT_TESTS, ECARTS, PROPOSITION_LOT_0.2}.md`.
