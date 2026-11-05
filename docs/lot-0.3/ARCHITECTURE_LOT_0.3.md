# Lot 0.3 — architecture du monde ouvert

## 1. Données → mise en page → carte générée

```
src/shared/World/Data/MapData.luau        carrefours, routes dessinées, quartiers (données versionnées)
src/shared/World/Data/Zones.luau          polygones des 7 zones, mer, reliefs
src/shared/World/Data/Infrastructure.luau services et emplacements (identifiants stables)
        │
        ▼  RoadNetwork.build (pur, déterministe)
src/shared/World/RoadNetwork.luau         nœuds, tronçons, îlots ; rues générées par quartier
src/shared/World/WorldLayout.luau         tracés lissés, zones, largeurs, implantation des services (cache)
src/shared/World/RoadGraph.luau           voisinage, A*, voies (circulation à droite)
        │
        ├─► tools/world/build-world.luau  (Lune, hors ligne) → build/world/OpenWorld.rbxm
        ├─► serveur : OpenWorldService, TrafficService
        ├─► client : Pedestrians
        └─► tests Lune : Lot03World, Lot03Systems
```

Les mêmes données produisent partout le même graphe et les mêmes identifiants (« `<route>.<n>` » pour un tronçon
scindé, « `Q:<quartier>:<famille><i>:<k>` » pour une rue générée). Toute modification des données incrémente
`WorldConfig.MapVersion` ; le serveur refuse de démarrer si la carte incluse n'a pas la même version.

## 2. Places

| Place | Manifeste | `PlaceConfig.Mode` | Contenu |
|---|---|---|---|
| Développement | `default.project.json` | `Dev` | Zone d'essai des lots 0.1/0.2, sessions VM existantes |
| Monde ouvert | `openworld.project.json` | `OpenWorld` | Carte générée, streaming activé |

`Bootstrap.server` et `Bootstrap.client` choisissent les services selon le mode.

## 3. Organisation de la carte générée (`Workspace.OpenWorld`)

| Dossier | Contenu | Streaming |
|---|---|---|
| `Routes/<secteur>` | chaussées, raccords, disques de carrefour, trottoirs, glissières | `Persistent` |
| `Decor/<secteur>`, `Relief/<secteur>`, `Sol/<secteur>` | bâtiments, parcs, arbres, feux, relief, sol, mer | `Default` (secteurs de 500 m) |
| `Services/<id>` | concessions, garages, stations, lavages, recharge, parcelles | `Atomic` |
| `Apparitions/<id>` | parc des prototypes (plots `AWFleetSlot`), points d'apparition | `Atomic` |

## 4. Exécution

| Module | Côté | Rôle |
|---|---|---|
| `server/World/OpenWorldService` | serveur | Version de carte, plots du parc, apparitions actives |
| `server/World/WeatherService` | serveur | Horloge (`AWClockEpoch`), météo (`AWWeather`), humidité (`AWRoadWetness`) |
| `server/World/TrafficService` | serveur | Agents PNJ (virtuels / physiques), corps solides près des joueurs |
| `shared/World/WeatherModel` | partagé, pur | Cycle, enchaînements, humidité, conditions standardisées |
| `shared/World/Signals` | partagé, pur | État des feux à partir de l'heure du serveur |
| `shared/World/TrafficModel` | partagé, pur | IDM, choix d'itinéraire, carrefours, obstacles |
| `shared/World/PedestrianModel` | partagé, pur | Positions déterministes des piétons |
| `client/World/Environment` | client | Heure, brume, pluie, éclairs, reflets (visuel seulement) |
| `client/World/TrafficLights` | client | Couleur des lampes (même règle que le serveur) |
| `client/World/Pedestrians` | client | Figurants autour de la caméra |
| `client/World/StreamAhead` | client | Chargement anticipé à grande vitesse |

Autorité : seul le serveur décide de la météo, de l'heure de référence et du trafic ; les clients calculent à partir
d'attributs serveur ou de l'heure du serveur, sans rien renvoyer. Aucune valeur client n'est utilisée par ces services.

## 5. Humidité et adhérence

`WheelContact.Wetness` (0 à 1) s'ajoute à `Wet` ; `VehicleDynamics` utilise `max(Wet ? 1 : 0, Wetness)` pour
interpoler l'adhérence de pic et le frottement de glissement entre les valeurs sèches et mouillées de chaque pneu.
`VehicleSimulator` lit `Workspace.AWRoadWetness` une fois par pas (absent = 0 dans la place de développement).
