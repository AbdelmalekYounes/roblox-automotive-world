# Architecture initiale — v0.0.1

## Contraintes du cahier des charges v1.0

- **Client** : entrées de conduite, caméra, interface, rétroaction immédiate. Ne décide jamais seul d'un changement persistant sensible.
- **Serveur** : autorité sur possessions, crédits, achats, ventes, dégâts persistants, éligibilité et récompenses des courses.
- **Shared** : configurations sans secret, contrats de données et utilitaires purs accessibles des deux côtés.
- **Sauvegardes** : non implémentées dans le socle. Leur futur service devra posséder un modèle versionné, un contrôle exclusif de session et des écritures récupérables.
- **Véhicules** : un *modèle* est une définition de catalogue ; une *instance* est un exemplaire possédé, identifié de façon unique.
- **Réseau** : aucun client ne pourra envoyer directement un montant de crédits à créditer ni un état de véhicule à persister sans validation serveur.
- **Tests** : environnement de validation isolé de la production ; ne pas connecter Studio à une production réelle.

## Arborescence

- `src/server` : démarrage et futurs services autoritaires.
- `src/client` : interface et futures commandes de conduite.
- `src/shared` : paramètres et contrats Luau communs.
- `tests` : validations statiques et tests futurs.
- `docs` : plan et instructions de réalisation.

## Décision d'architecture pour la première voiture

La première voiture sera un **prototype technique original**, distinct de tout actif commercial du lancement. Il devra servir à valider la conduite réaliste de base et l'architecture hybride. Il ne devra pas être confondu avec le véhicule gratuit définitif. L'implémentation physique détaillée sera produite et testée dans le lot suivant avant toute extension aux 18 modèles.

## Architecture véhicule — lot 0.1

### Principe : simulation hybride (AUD-PHYS-01)

```
 Client conducteur (propriétaire réseau)          Serveur (autorité)
 ┌─────────────────────────────────┐              ┌────────────────────────────────────┐
 │ DriverInput (clavier/manette)   │  commandes   │ VehicleService                     │
 │   → VehicleSimulator.step       │ ───────────► │  - assied / débarque (Seat:Sit)    │
 │     rayons → VehicleDynamics    │  (15 Hz,     │  - SetNetworkOwner(conducteur|nil) │
 │     → VectorForce par roue      │  bornées)    │  - MovementRules toutes les 0,2 s  │
 │ VehicleCamera, DevHud           │              │  - simule les véhicules stationnés │
 │ WheelVisuals (tous véhicules)   │ ◄─────────── │  - messages par clé                │
 └─────────────────────────────────┘  attributs,  └────────────────────────────────────┘
                                      notices
```

- **Réactivité** : le conducteur simule son propre véhicule localement (propriété réseau Roblox), sans attendre le serveur.
- **Autorité** : le serveur seul assied un joueur, attribue la propriété réseau, autorise la sortie et la remise sur roues,
  et contrôle la plausibilité des mouvements. Les commandes reçues sont décodées défensivement (`InputCodec.decode`)
  et limitées en débit (`RateLimiter`) ; elles ne servent qu'à l'affichage du braquage chez les autres joueurs.
- **Tolérance réseau** : seuil souple (×1,25 de la vitesse plausible) → journalisation seule ; seuil dur (×2, ou
  déplacement impossible, ou valeur non finie) → repositionnement sur la dernière position valide, **sans sanction**.
- **Multijoueur** : chaque véhicule possède son propre état (`VehicleSimulator` par modèle) ; un joueur ne peut conduire
  qu'un véhicule, un véhicule n'a qu'un conducteur ; aucun état global partagé entre véhicules.
- **Propriété réseau vérifiée** (`server/Vehicles/NetworkOwnership`) : une transition n'est réussie que si
  `GetNetworkOwner` confirme le propriétaire demandé. En cas de refus du moteur (pièce ancrée, joueur parti…), le
  serveur garde la simulation, le joueur est sorti du siège avec un message, sans sanction. Le serveur revérifie le
  propriétaire effectif chaque seconde. L'attribut `SimulationOwnerUserId` (écrit seulement après confirmation) dit
  **qui simule** : le client ne simule que s'il porte son identifiant, le serveur seulement s'il vaut 0 — jamais les
  deux. Pendant une correction serveur, le client suspend sa simulation et repart d'un état neuf.
- **Collisions entre véhicules de deux joueurs** (`server/Vehicles/CollisionMediator`, `shared/Vehicles/Physics/CollisionExchange`) :
  chaque client résout le contact contre une copie répliquée de l'autre véhicule ; le serveur confirme le choc à
  partir de ses propres observations (rapprochement et décélération du percuteur), puis demande au propriétaire du
  véhicule percuté d'appliquer le **complément** d'impulsion non reçu (borné, sans double comptage). Voir
  `docs/lot-0.1/ECARTS.md` §4.
- **Périphériques** (`client/Vehicles/InputArbiter`, module pur) : un seul périphérique actif, activé par une commande
  fraîche ; clavier ignoré pendant une saisie de texte ou sans focus ; manette déconnectée relâchée.

### Séparation du code

| Couche | Modules | Dépend de Roblox ? |
|---|---|---|
| Dynamique pure (`shared/Vehicles/Physics`) | `TireModel`, `Suspension`, `Powertrain`, `VehicleDynamics`, `SurfaceFriction`, `CollisionExchange` | Non — testée par Lune |
| Contrats (`shared/Vehicles`) | `VehicleTypes`, `VehicleDefinitions`, `Definitions/PrototypeP01`, `InputCodec`, `Telemetry`, `VehicleConstants` | Non |
| Adaptateur (`shared/Vehicles/VehicleSimulator`) | rayons de suspension, conversion d'unités, `VectorForce` | Oui — exécuté par le propriétaire réseau |
| Serveur (`server/`) | `VehicleService`, `VehicleFactory`, `TestZoneBuilder`, `CollisionMediator`, `NetworkOwnership`, `Security/MovementRules`, `Security/RateLimiter` | Oui (sauf `NetworkOwnership` et règles pures) |
| Client (`client/`) | `VehicleController`, `DriverInput`, `InputArbiter`, `VehicleCamera`, `WheelVisuals`, `UI/DevHud`, `UI/Messages` | Oui (sauf `InputArbiter`) |

### Modèle physique

- **Châssis** : un bloc unique porte la masse ; son centre est le centre de gravité. Roblox intègre masse et inertie ;
  aucune vitesse n'est imposée. Les forces calculées en newtons sont converties par `masse Roblox / (masse kg × 0,28)`
  (1 stud = 0,28 m), et une force de compensation donne au véhicule une gravité réelle de 9,81 m/s² sans modifier
  `Workspace.Gravity` des personnages.
- **Suspension** : rayon par roue, ressort + amortisseur compression/détente, butée progressive, barre antiroulis.
- **Pneus** : glissement longitudinal et dérive, courbe à pic puis glissement franc, sensibilité à la charge,
  ellipse de friction, adhérence par revêtement. Rotation de chaque roue intégrée en sous-pas semi-implicites.
- **Groupe motopropulseur** : courbe de couple, ralenti, rupteur, frein moteur, embrayage/convertisseur simplifié,
  boîte automatique à 6 rapports, marche arrière, inertie moteur ramenée aux roues, répartition avant/arrière fixe et
  différentiels ouverts.
- **Freins** : couple avant/arrière, frein à main arrière ; **aucune aide** (ABS, antipatinage, ESP) n'existe.
- **Direction** : vitesse de crémaillère limitée, angle maximal décroissant **linéairement avec la seule vitesse**
  (arbitrage A1 : paramètres par modèle, identique pour tous les périphériques, affiché dans le HUD, aucune mesure de
  glissement ni de lacet), géométrie d'Ackermann.

> **Lot 0.2** : les points d'extension ci-dessous sont implémentés (moteurs essence/diesel/électrique, six boîtes,
> FWD/RWD/AWD et autobloquants, aides par modèle, mouillé, énergie et dégâts de session, caméras embarquées).
> Changements d'architecture : `docs/lot-0.2/ARCHITECTURE_LOT_0.2.md`. Le tableau suivant décrit l'état du lot 0.1.

### Points d'extension (déclarés, NON implémentés au lot 0.1)

| Futur besoin | Point d'extension | État lot 0.1 |
|---|---|---|
| Traction / intégrale | `Drivetrain.Layout` + `FrontTorqueShare` | Calcul générique présent et testé unitairement ; seul le RWD est exercé ; non validé en jeu |
| Électrique | `PowertrainKind = "Electric"` | Refusé par `VehicleDefinitions.validate` |
| Boîtes manuelle, double embrayage, séquentielle, CVT | `TransmissionKind`, `ReverseEngagement`, `GearSelectorCommand` (A3) | Refusées par la validation ; commandes de sélecteur typées, non câblées |
| ABS / antipatinage / ESP | `DriverAids` | Toute valeur `true` est refusée |
| Météo / revêtement mouillé | `WheelContact.SurfaceFriction` | Multiplicateur par matériau seulement |
| Dégâts, carburant/énergie | — | Non commencés (lot 0.2) |

## Exclusions du socle 0.0.1

Aucun DataStore, achat, économie, dégâts persistants, course, radio, carte de sept zones ni modèle automobile de production n'est encore implémenté. Ces sujets sont prévus dans les lots de développement, non abandonnés.
