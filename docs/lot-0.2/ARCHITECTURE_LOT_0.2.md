# Lot 0.2 — changements d'architecture

Ce document décrit ce que le lot 0.2 ajoute ou modifie par rapport à l'architecture du lot 0.1
(`docs/ARCHITECTURE.md`). Les résultats mesurés sont dans `RAPPORT_LOT_0.2.md`, les écarts dans `ECARTS.md`.

## 1. Principes conservés

- Simulation hybride (A6) : le conducteur simule son véhicule ; le serveur valide, borne et corrige sans sanction.
- Dynamique **pure** dans `shared/Vehicles/Physics` (aucune API Roblox), testée hors Studio par Lune.
- Paramètres par modèle dans `shared/Vehicles/Definitions`, validés au chargement puis gelés.
- Arbitrages A1 à A6 inchangés. A1 reste un filtre de commande indépendant des aides ; A3 est désormais câblé
  pour les boîtes à sélecteur.

## 2. Groupe motopropulseur : un moteur qui tourne vraiment

Au lot 0.1, le régime moteur était déduit des roues et un « embrayage simplifié » imposait un régime de démarrage.
Au lot 0.2, le moteur est un **corps en rotation** (inertie propre) couplé aux roues par la boîte :

```
 Engine (couple selon régime, charge, état)      Transmission (choix du rapport, loi de couplage)
   thermique : courbe, ralenti régulé,             Open      : neutre, moteur libre
               rupteur, frein moteur, calage        Rigid     : embrayage/pontage fermé, rapport unique
   électrique : couple puis puissance, vitesse       Clutch    : embrayage qui patine (capacité en N·m)
                limitée, récupération               Converter : convertisseur (pompe/turbine)
          │                                                   │
          └──────────── sous-pas couplés (4 par image) ───────┘
                                   │ couple à l'entrée des différentiels
                         Driveline (central, avant, arrière ; ouvert / autobloquant)
                                   │ couple par roue
                         TireModel.integrateWheel (rotation de chaque roue)
```

- `VehicleDynamics.step` intègre ensemble, en 4 sous-pas par image : le moteur (s'il n'est pas solidaire), le couple
  transmis, les différentiels et la rotation des roues. Quand l'embrayage (ou le pontage) est fermé, l'inertie du moteur
  est ramenée aux roues par le rapport, comme au lot 0.1.
- **Calage** : un moteur thermique entraîné sous son régime de calage s'arrête ; relance au démarreur embrayage enfoncé
  (ou au neutre), ou « à la poussette ». Les embrayages automatisés (double embrayage, séquentielle, CVT) ont une loi
  « centrifuge » qui ne cale pas ; le convertisseur ne cale pas.
- **Protections mécaniques** (`Transmission.requestShift`) : marche arrière seulement à l'arrêt (toutes les boîtes),
  embrayage enfoncé exigé (manuelle), rétrogradation refusée au-delà du rupteur (boîtes pilotées).
- **A3 câblé** : boîtes à sélecteur → la marche arrière s'atteint en descendant depuis le neutre, véhicule arrêté ;
  boîtes sans sélecteur (automatique, CVT, rapport unique) → maintien de « freiner » à l'arrêt, inchangé.

## 3. Pneus

- **Glissement combiné** (`TireModel.combinedFactors`) : la force disponible dépend du glissement total, partagée au
  prorata des glissements longitudinal et latéral. Au lot 0.1, une simple ellipse laissait environ 80 % de la force
  latérale à une roue bloquée (le véhicule tournait roues bloquées) ; ce n'est plus le cas, ce qui donne son sens à l'ABS.
- **Frottement statique** (`TireModel.stiction`) : ressort amorti ancré au sol tant que le contact adhère (roue retenue
  par le frein en longitudinal, contact quasi immobile en latéral) ; corrige le glissement lent en pente du lot 0.1.
- **Relaxation latérale** et **adhérence mouillée** (attribut `AWWet` d'une pièce de décor) : paramètres par pneu.

## 4. Aides électroniques (`Physics/DriverAids`)

- Présence = équipement du modèle (`definition.Aids`) ; activation = attribut écrit par le **serveur** (`AidAbs`,
  `AidTractionControl`, `AidStabilityControl`), remis à `false` à chaque embarquement. Le client demande
  (`ToggleAid`) ; le serveur refuse si le modèle n'en est pas équipé.
- ABS : module la pression de chaque roue d'après son glissement. Antipatinage : réduit le couple moteur.
  ESP : freine une roue choisie (avant extérieure en survirage, arrière intérieure en sous-virage). Aucune ne modifie
  les limites d'adhérence du pneu.

## 5. Énergie (`Physics/EnergyModel`, `VehicleService`)

```
 Client (simulation détaillée)                     Serveur (autorité)
   consommation selon régime/charge   cumul       plancher physique : énergie minimale du mouvement OBSERVÉ
   (L ou kWh) ─────────────────────► déclaré ───► règlement = max(plancher, déclaration bornée en débit)
   prédiction prudente du niveau ◄── EnergyLevel  récupération électrique calculée par le serveur seul
   propulsion coupée si vide     ◄── EnergyEmpty  réserve vide verrouillée, aucune recharge
```

- Un client ne peut ni consommer moins que le plancher, ni déclarer un débit implausible, ni créer de l'énergie.
- État de session seulement (`EnergyModel.Account`) ; la sauvegarde appartient au lot 0.4.

## 6. Dégâts (`Physics/DamageModel`, `server/Vehicles/DamageService`)

- Confirmation **serveur** (AUD-COLL-01) : variation de vitesse horizontale qu'aucun pneu ne peut produire, puis
  obstacle collisionnable réellement présent dans la boîte englobante élargie (au-dessus des roues). Entre deux
  véhicules, les dégâts infligés à l'autre sont bornés par un choc de carrosseries à la vitesse de rapprochement
  observée. Les repositionnements serveur suspendent la détection.
- État versionné (`DamageModel.Version`), publié en attributs `Dmg…` : usure de 4 zones (3 niveaux visuels) et santé
  de composants (moteur, direction, suspension par roue) → `VehicleCondition` (puissance, braquage, tirage, adhérence
  et parallélisme par roue), lue par la simulation du propriétaire.
- Visuels : primitives originales sans masse ni collision (rayures, panneaux déformés, optiques éteintes, fumée
  intégrée au moteur Roblox). La géométrie de collision n'est jamais modifiée.

## 7. Caméras et commandes

- `VehicleCamera` : proche, lointaine, cockpit, capot, pare-chocs. Les vues embarquées suivent des attachements
  (`CameraCockpit`, `CameraHood`, `CameraBumper`) que `VehicleFactory` place d'après la géométrie du modèle.
- Commandes ponctuelles liées par `VehicleController` (une table de gestionnaires partagée par le clavier, la manette
  et les essais Studio) : rapports (Maj gauche / Ctrl gauche, RB / LB), embrayage (C, B), aides (1, 2, 3 ; croix
  gauche pour choisir, croix droite pour changer), récupération (G), caméra (V, croix haut).

## 8. Sondes de contact et mesures de coût

- `Suspension.ContactProbe` : `Ray` (lot 0.1) ou `Sphere` (balayage `Workspace:Spherecast` du rayon du pneu, repli
  sur le rayon en cas de contact dès le départ). Le choix par défaut suit les mesures (`RAPPORT_LOT_0.2.md`).
- `PerfStats` (pur) : médiane, P95, P99 sur fenêtre glissante ; mesurés : pas de simulation par véhicule, requêtes
  physiques, battement serveur, service de dégâts ; temps d'image client (indicatif dans la VM).

## 9. Séparation du code (mise à jour)

| Couche | Modules | Dépend de Roblox ? |
|---|---|---|
| Dynamique pure | `TireModel`, `Suspension`, `Engine`, `Transmission`, `Driveline`, `DriverAids`, `EnergyModel`, `DamageModel`, `VehicleDynamics`, `SurfaceFriction`, `CollisionExchange` | Non — testée par Lune |
| Contrats | `VehicleTypes`, `VehicleDefinitions`, `Definitions/*`, `InputCodec`, `Telemetry`, `PerfStats`, `VehicleConstants` | Non |
| Adaptateur | `VehicleSimulator` (sondes, mouillé, lacet, attributs serveur, coûts) | Oui |
| Serveur | `VehicleService`, `DamageService`, `VehicleFactory`, `TestZoneBuilder`, `CollisionMediator`, `NetworkOwnership`, `Security/*` | Oui |
| Client | `VehicleController`, `DriverInput`, `InputArbiter`, `VehicleCamera`, `WheelVisuals`, `UI/DevHud`, `UI/Messages` | Oui (sauf `InputArbiter`) |

`Physics/Powertrain` (lot 0.1) est supprimé : ses fonctions sont réparties entre `Engine`, `Transmission` et `Driveline`.

## 10. Points d'accès réservés aux essais Studio

`VehicleController.setTestInputProvider`, `invokeActionForTest`, `getTestSnapshot`, `bindingsForTest`,
`resetPerfForTest`, et côté serveur la `BindableFunction` `ServerStorage.AWTestHooks` (énergie, dégâts, coûts, banc de
charge) n'existent ou ne fonctionnent que si `RunService:IsStudio()`. L'attribut `AWTestProbe` (sonde forcée) n'est lu
qu'en Studio.
