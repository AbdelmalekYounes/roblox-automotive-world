# Rapport du lot 0.3 — développement du monde ouvert

Branche `feat/open-world-map-0.3` (créée depuis `c0f7a28`, dernier commit du lot 0.2), PR brouillon vers
`feat/advanced-vehicle-physics-0.2`. Les branches `main`, `feat/vehicle-vertical-slice-0.1` et
`feat/advanced-vehicle-physics-0.2` n'ont pas été modifiées.

Décision du propriétaire pour ce lot : les essais humains, les campagnes approfondies de non-régression et les tests
de charge sont **regroupés dans un lot QA ultérieur**. Ce rapport ne contient donc que des vérifications hors Studio ;
**aucun essai Studio ni humain n'a été exécuté pendant ce lot**. Tout ce qui reste à vérifier est listé dans
[`docs/QA_BACKLOG.md`](../QA_BACKLOG.md), marqué **NON TESTÉ**.

## 1. Synthèse

| Livrable demandé | État | Vérifié par |
|---|---|---|
| Carte d'un seul tenant, 7 zones en maquette (blockout) | Livré | Tests Lune « Lot 0.3 — carte » (connexité, zones, pentes, mer) ; rendu en plan |
| Réseau principal et secondaire, graphe exploitable | Livré | Tests Lune (pas de croisement sans carrefour, emprises, A*, temps de trajet) |
| Infrastructures en quantités du cahier des charges | Livré (emplacements et volumes, sans interface économique) | Tests Lune (quantités, recharge par zone, implantation) |
| Trafic PNJ et piétons | Livré (premier niveau) | Tests Lune du modèle pur ; **comportement en jeu NON TESTÉ** |
| Météo et cycle jour/nuit synchronisés | Livré | Tests Lune du modèle ; **rendu en jeu NON TESTÉ** |
| Intégration des véhicules V0.2 | Livrée (parc de 9 prototypes, physique inchangée sauf humidité continue) | Tests Lune (humidité appliquée une fois) ; **conduite sur la carte NON TESTÉE** |
| Architecture de chargement du monde ouvert | Livrée (carte générée hors ligne, streaming par secteur) | Génération déterministe (empreinte identique sur deux exécutions), build Rojo ; **streaming en jeu NON TESTÉ** |
| Rapport et registre QA | Ce document ; `docs/QA_BACKLOG.md` | — |

## 2. Vérifications exécutées (hors Studio)

Commande : `powershell -ExecutionPolicy Bypass -File scripts\verify.ps1 -RobloxTypes .tooling\globalTypes.d.luau`,
exécutée le 2026-11-03 de 01:34 à 01:35 sur le code du commit `72b5f22` (arbre de travail : seul
`docs/QA_BACKLOG.md` en plus). Sortie conservée localement dans `build/verify-lot03.log` (non versionnée).

| Étape | Résultat |
|---|---|
| Rojo build (place de développement) | OK |
| Selene | OK (0 erreur, 0 avertissement) |
| Pilote Studio (génération + compilation, sans lancer Studio) | OK |
| StyLua `--check` (src, tests, tools/world) | OK |
| Lune (tests hors Studio) | OK — **187 réussis, 0 échoués** |
| Carte du monde ouvert (`tools/world/build-world.luau`) | OK — 36 968 pièces (4 473 bâtiments, 2 542 cellules de relief, 479 arbres), 43 services, 0,7 Mo |
| Rojo build (place monde ouvert, `openworld.project.json`) | OK — `build\AutomotiveWorld-OpenWorld.rbxl`, 911 332 octets |
| Pytest | OK — 9 réussis |
| luau-lsp `analyze` (strict, définitions Roblox 1.70.1) | OK — 0 erreur |

Contrôles complémentaires, même date :

- **Déterminisme du générateur** : deux générations successives produisent un fichier identique octet pour octet
  (SHA-256 `3efe858e…0e997a09`). Durée d'une génération : 1,75 s (`time`, poste principal).
- **Étiquettes de la carte générée** relues avec Lune : 9 `AWFleetSlot`, 43 `AWService`, 214 `AWTrafficLight`,
  32 `AWFuelPump`, 38 `AWCharger`, 3 `SpawnLocation` ; racine `OpenWorld` en version de carte `0.3.0`.

Ces contrôles portent sur les données, les modules purs et la compilation. Ils ne démontrent **pas** le comportement
dans le moteur Roblox (physique, réseau, streaming, rendu).

## 3. Carte

### 3.1 Échelle et dimensionnement

- Données en mètres (x vers l'est, z vers le sud), converties en studs à la génération (1 stud = 0,28 m, arbitrage A5).
  Carte dans un carré de 10 km (± 17 857 studs), loin des limites de précision.
- Trajet autoroutier de référence (A1, complexe motorsport → cols) : **13,22 km**, soit **6,1 min à 130 km/h** et
  **7,2 min à 110 km/h** (calcul sur le tracé, test Lune) — dans la fourchette demandée de 6 à 10 min. Vitesses de
  croisière retenues : P-01 mesuré 0–100 km/h en 8,92 s en Studio au lot 0.2 et vitesse de pointe du modèle 224 km/h.
  Itinéraire le plus rapide entre les deux extrémités par le graphe : 8,89 km.

### 3.2 Zones (noms fictifs)

| Zone | Contenu | Routes |
|---|---|---|
| Métropole | Place centrale, carré central, boulevard circulaire (r ≈ 1 380 m), 8 radiales, 4 quartiers et 8 secteurs en quadrillages irréguliers, périphérique (r ≈ 1 500 m) | 100,9 km |
| Banlieues | 6 quartiers pavillonnaires et commerciaux (Tilleuls, Parc Sud-Ouest, Hortensias, Jardins, Chênes et Lisières, Levant) | 124,6 km |
| Zone industrielle et docks | Quais, boulevard industriel, rue des usines, accès nord | 30,3 km |
| Montagnes et cols | Col à 250 m (9 lacets), route des crêtes, route du lac, descente vers la campagne | 14,1 km |
| Campagne | Villages de Saint-Amarre et Vauclair, départementales D1 à D9, chemins | 35,7 km |
| Complexe motorsport | Circuit, piste de drag, zone de drift, piste technique, rallye | 8,0 km |
| Littoral | Port-Soleil, corniche et falaises, boulevard de la plage, phare | 16,3 km |

Réseau : **1 285 carrefours, 2 224 tronçons, 1 120 îlots**. Longueur par classe : rues 167,0 km, avenues 79,2 km,
départementales 27,2 km, autoroute 15,7 km, montagne 11,7 km, voies rapides 10,5 km, périphérique 9,4 km,
chemins 4,8 km, pistes 4,3 km. Pente maximale 10,9 % (M1-3), altitude maximale 270 m. 60 carrefours à feux.

### 3.3 Routes

Classes paramétrées dans `WorldConfig.RoadClasses` (voies, largeur de voie, accotements, trottoirs, terre-plein,
vitesse, matériau, glissières, rang de priorité, ouverture au trafic et aux piétons) : autoroute 2 × 3 voies de 3,5 m,
périphérique et voies rapides 2 × 2, bretelles, avenues 2 × 2 avec trottoirs de 4 m, rues 2 × 1, départementales,
routes de montagne avec glissières, chemins en gravier (`Pebble`, adhérence 0,6), pistes. Les quartiers sont des
quadrillages **irréguliers** (orientation, pas et graine propres à chaque quartier, découpés dans un polygone borné
par des routes dessinées) ; les rues qui atteignent le bord créent des carrefours en T.

Contrôles automatiques (tests Lune) : carte connexe (aucune téléportation nécessaire), aucune intersection de tracés
hors carrefour, emprises sans chevauchement hors carrefours, pentes ≤ 12,5 %, aucune route en mer, chaque zone
atteignable depuis la place centrale par A*.

### 3.4 Infrastructures (emplacements et volumes, sans interface économique)

| Type | Exigé | Placé | Répartition |
|---|---|---|---|
| Concessions | 2 | 2 | Métropole, Banlieues |
| Garages publics | 3 | 3 | Métropole, Banlieues, Docks |
| Stations-service | 6 | 6 | Métropole, Banlieues, Docks, Montagnes, Campagne, Littoral |
| Stations de lavage | 3 | 3 | Métropole, Banlieues, Littoral |
| Recharge publique | ≥ 1 par zone | 7 zones | places de recharge : Métropole 14, Banlieues 4, Docks 4, Montagnes 4, Campagne 2, Motorsport 6, Littoral 4 |

Emplacements structurels : 10 parcelles de propriétés privées, 3 garages résidentiels, 7 lieux sociaux, 2 parkings,
1 aire de drift, 1 parc des prototypes (9 plots), 3 points d'apparition. Bâtiments publics creux (façade ouverte,
volume intérieur). Implantation vérifiée par test : dans la zone déclarée, hors chaussée, hors mer, sans chevauchement.

## 4. Systèmes

### 4.1 Chargement (architecture)

- **Aucune construction de décor au démarrage du serveur** : la carte est générée hors ligne par
  `tools/world/build-world.luau` à partir des données versionnées (`WorldConfig.MapVersion = "0.3.0"`), puis incluse
  dans la place monde ouvert. Le serveur vérifie seulement la version (`OpenWorldService`).
- Streaming Roblox activé dans la place monde ouvert (`StreamingMinRadius` 1024, `StreamingTargetRadius` 3072,
  `PauseOutsideLoadedArea`, comportement « Improved »). Routes, disques de carrefour, trottoirs et glissières sont des
  modèles **persistants** (collisions toujours présentes) ; décor et relief par secteurs de 500 m ; services
  `Atomic` ; véhicules `Atomic`. Le client demande le chargement anticipé de la zone atteinte dans 4 s au-delà de
  15 m/s (`StreamAhead`).
- La zone d'essai des lots 0.1/0.2 reste dans la place de développement (`default.project.json`, mode `Dev`).

### 4.2 Véhicules

Les 9 configurations du parc d'essai (`VehicleDefinitions.TestFleet`) apparaissent sur les plots `FLEET-METRO`,
orientés vers la route. Seule l'apparition voisine (`SPAWN-METRO`) est active (voir §6). Physique, motorisations,
dégâts, consommation, propriété réseau et caméras du lot 0.2 sont inchangés, à une exception : l'**humidité** devient
continue (0 à 1) et combine par **maximum** la surface mouillée par conception (`AWWet`) et la chaussée mouillée par
la météo (`AWRoadWetness`) : la réduction d'adhérence n'est jamais appliquée deux fois. Banc Lune, P-02 80–0 km/h :
sec 23,7 m, humidité 0,5 39,3 m, mouillé 50,7 m, mouillé + pluie 50,7 m (identique).

### 4.3 Météo et jour/nuit

Cycle de 30 min (départ à 9 h) ; états dégagé, pluie, brouillard, orage tirés par le serveur et publiés en attributs ;
chaque client calcule l'heure et l'ambiance (brume, luminosité, pluie, éclairs, reflets). Conditions standardisées des
futures épreuves classées (AUD-WEATHER-01) définies dans `WeatherModel.Standard` (dégagé, sec, 13 h), non utilisées
avant le lot des compétitions.

### 4.4 Trafic PNJ

Modèle pur `TrafficModel` : circulation à droite sur les voies du graphe, IDM (accélérations et freinages progressifs,
distance de sécurité), anticipation des routes plus lentes, feux déterministes partagés avec les clients, carrefours
sans feux par réservation et cédez-le-passage selon le rang de la route, attente si l'entrée d'une voie est occupée,
réaction aux véhicules et piétons des joueurs. `TrafficService` (serveur) : 140 agents répartis selon la densité des
zones ; agents **virtuels** loin des joueurs, **physiques** (non ancrés, appartenant au serveur, guidés par
contraintes à force limitée, donc solides et poussables) jusqu'à 260 m, 48 au plus. Banc Lune : 150 agents pendant
300 s simulées, 0 chevauchement sur une même voie, 0 dépassement de vitesse, 0 feu rouge franchi, 150 agents ont
circulé ; un PNJ s'arrête avant un véhicule de joueur immobile.

### 4.5 Piétons

`PedestrianModel` : positions déterministes (tronçon, numéro, heure du serveur) sur les trottoirs des classes qui en
ont, densité par zone, à l'écart des plateformes de carrefour. Rendu local autour de la caméra (150 m, 60 au plus).
4 668 piétons théoriques sur la carte, 0 en montagne.

## 5. Écarts, limites et choix à arbitrer

1. **Essais Studio et humains non faits** (décision du propriétaire) : tout le comportement dans le moteur est
   **NON TESTÉ** (`docs/QA_BACKLOG.md` §2 à §4). Aucune performance (24 joueurs, ~60 FPS) n'est revendiquée.
2. **Apparitions** : seule `SPAWN-METRO` est active, car le seul parc de véhicules est en métropole ; les apparitions
   Motorsport et Littoral existent mais sont désactivées. **À arbitrer** au lot qui distribuera des véhicules.
3. **Trafic** : pas de changement de voie ni de dépassement ; pas de clignotants ni de rendu des roues ; au carrefour
   sans feux, un flux continu sur la même approche peut retarder longtemps une approche secondaire (réservation
   renouvelée, durée bornée à 8 s par agent). Le contact véhicule client ↔ PNJ serveur relève de la même mécanique
   moteur que QA-A01 et doit être vérifié (QA-S11).
4. **Piétons** : figurants non solides (pas de collision ni de lancer de rayon) ; ils ne traversent pas la chaussée.
   Une collision piéton/véhicule est une décision de jeu non prise ici.
5. **Maquette** : bâtiments en volumes simples, relief en cellules de 60 m, pas de terrain Roblox (`Terrain`), ponts
   représentés par des tabliers et remblais ; pas de signalisation horizontale détaillée aux carrefours.
6. **Humidité** : appliquée à toute surface touchée, y compris l'intérieur des bâtiments ouverts (simplification).
7. **Version de développement** passée à `0.3.0-dev` (`ProjectSettings`).

Anomalies existantes des lots 0.1 et 0.2 : **non corrigées et non retestées** dans ce lot (QA-A01 à QA-A07).

## 6. Reproduire

```
lune run tools/world/build-world.luau build\AutomotiveWorld.rbxlx build\world\OpenWorld.rbxm
rojo build openworld.project.json -o build\AutomotiveWorld-OpenWorld.rbxl
```

(`build\AutomotiveWorld.rbxlx` est produit par `rojo build -o build\AutomotiveWorld.rbxlx` ; `scripts\verify.ps1`
enchaîne le tout.) Architecture détaillée : [`ARCHITECTURE_LOT_0.3.md`](ARCHITECTURE_LOT_0.3.md).

## 7. Mise à jour après la campagne de tests du 2026-11-03

La session Studio `monde` (nouvelle) a trouvé un défaut de la carte : 195 pièces dépassaient la taille maximale du
moteur (2 048 studs) et étaient raccourcies, laissant des trous aux bouts des longues chaussées droites. Corrigé dans
`b41e0f1` (tracés redécoupés à 500 m, garde-fou dans le générateur ; carte : 37 239 pièces). Après correction, la
session passe entièrement (tâche `20261103-030159`, 32/32), dont une conduite réelle à 133,4 km/h sur l'autoroute.
Détail : `docs/QA_CAMPAGNE_2026-11-03.md`.
