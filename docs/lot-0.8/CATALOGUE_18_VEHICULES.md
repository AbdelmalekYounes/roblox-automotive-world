# Catalogue des 18 véhicules — gamme PROPOSÉE (lot 0.8)

**Statut : proposé, en attente d'approbation du propriétaire (`PendingApproval`).** Ces dix-huit modèles sont
**fictifs** : noms, silhouettes, fiches et prix ont été conçus pour Automotive World. Ils ne reproduisent aucun
véhicule, aucune marque ni aucune référence commerciale réelle, et ne doivent pas être présentés comme tels. Rien
n'est validé à la place du propriétaire ; la liste officielle du catalogue de lancement reste à arrêter.

Sources dans le code :

- fiches et construction des définitions physiques : `src/shared/Vehicles/Definitions/WorkingCatalog.luau` ;
- entrées commerciales (emplacement, prix, concessions, disponibilité) : `src/shared/Economy/VehicleCatalog.luau`
  (version `0.8.0-proposition`) ;
- textes joueur FR/EN (catégorie, description) : `src/shared/UI/Texts08.luau` ;
- carrosseries : `src/server/Vehicles/BodyKits.luau` (dix silhouettes) ;
- banc d'essai : `tools/vehicles/catalog.luau`.

## 1. Méthode et limites

- Chaque fiche part d'un prototype validé des lots 0.1–0.2 (P-01, P-02 ou P-03) puis met à l'échelle masse,
  suspensions (selon la charge par essieu), pneus, freins, couple ou puissance du moteur, boîte (manuelle P-02,
  automatique P-01, double embrayage, séquentielle, variation continue des variantes de validation), pont,
  différentiel et aides. Chaque définition passe la validation physique stricte des lots 0.1–0.2 au chargement
  (test Lune n° 2 du lot 0.8).
- **Chiffres de performance : banc PLANAIRE hors Studio** (`lune run tools/vehicles/catalog.luau
  build/AutomotiveWorld.rbxlx`, 2026-11-03), conducteur simulé, route sèche plane. Ce ne sont **pas** des mesures
  en jeu : les 18 modèles n'ont été conduits ni dans Studio ni par un humain (NON TESTÉ, `docs/QA_BACKLOG.md`
  §3 sexies). « v60 » est la vitesse atteinte après 60 s d'accélération, pas une vitesse maximale certifiée.
- Corrections de démultiplication faites pendant ce lot : Cadence (pont 3,4 : la boîte automatique de base
  plafonnait à 194 km/h), Comète (pont 3,0), Zénith (rapport 6,9). Le test n° 2 vérifie désormais que chaque
  modèle peut atteindre 99 % de sa vitesse annoncée.
- Consommation et autonomie réelles par modèle : non mesurées dans ce lot.
- Géométrie : carrosseries **construites par code** à partir de pièces Roblox de base (aucun maillage, aucune
  texture) ; habitacle simplifié (planche de bord, combiné, console, sièges) ; place passager. Statut de finition :
  **provisoire** (voir §4).

## 2. Vue d'ensemble

Dimensions : longueur × largeur × hauteur (empattement), en mètres. Prix en crédits (proposition).

| # | Modèle | Catégorie FR / EN | Motorisation | kW | kg | Dimensions | Réservoir / batterie | V. annoncée km/h | 0–100 s (banc) | v60 km/h (banc) | Prix | Concessions | Silhouette |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | **Pixel** (`wk_pixel`) | Citadine électrique / Electric city car | électrique, rapport unique, propulsion | 45 | 880 | 3.15 × 1.62 × 1.55 (2.1) | 22 kWh | 125 | 11.6 | 123 | 14 500 | Métropole | Micro |
| 2 | **Brio** (`wk_brio`) | Citadine / City car | essence, manuelle, traction | 70 | 1 050 | 3.8 × 1.7 × 1.5 (2.45) | 42 L | 175 | 10.9 | 182 | 16 500 | Métropole, Banlieues | Hatch |
| 3 | **Fil** (`wk_fil`) | Citadine électrique / Electric city car | électrique, rapport unique, traction | 85 | 1 320 | 4.05 × 1.76 × 1.56 (2.58) | 45 kWh | 150 | 10.8 | 148 | 19 500 | Métropole, Banlieues | Hatch |
| 4 | **Aster** (`wk_aster`) | Compacte / Compact | essence, automatique, traction | 95 | 1 280 | 4.25 × 1.78 × 1.47 (2.62) | 48 L | 195 | 10.9 | 195 | 19 000 | Métropole, Banlieues | Hatch |
| 5 | **Nova** (`wk_nova`) | Compacte / Compact | essence, variation continue, traction | 85 | 1 240 | 4.4 × 1.76 × 1.46 (2.64) | 45 L | 185 | 10.8 | 190 | 21 000 | Métropole | Sedan |
| 6 | **Cadence** (`wk_cadence`) | Berline / Saloon | diesel, automatique, traction | 110 | 1 520 | 4.8 × 1.83 × 1.46 (2.8) | 60 L | 215 | 10.1 | 203 | 32 000 | Métropole | Sedan |
| 7 | **Lumen** (`wk_lumen`) | Break / Estate | diesel, manuelle, traction | 100 | 1 480 | 4.7 × 1.82 × 1.5 (2.75) | 58 L | 205 | 10.3 | 199 | 27 000 | Banlieues | Wagon |
| 8 | **Orée** (`wk_oree`) | Berline électrique / Electric saloon | électrique, rapport unique, intégrale | 230 | 2 050 | 4.95 × 1.9 × 1.45 (2.95) | 85 kWh | 220 | 6.1 | 217 | 68 000 | Métropole | Sedan |
| 9 | **Brise** (`wk_brise`) | Roadster / Roadster | essence, manuelle, propulsion | 110 | 1 060 | 3.95 × 1.73 × 1.24 (2.35) | 40 L | 210 | 10.9 | 182 | 33 000 | Banlieues | Roadster |
| 10 | **Rafale** (`wk_rafale`) | Sportive compacte / Hot hatch | essence, double embrayage, traction | 200 | 1 420 | 4.3 × 1.8 × 1.43 (2.65) | 50 L | 250 | 6.6 | 260 | 42 000 | Métropole | Hatch |
| 11 | **Éclat** (`wk_eclat`) | Coupé sportif / Sports coupé | essence, manuelle, propulsion | 185 | 1 360 | 4.45 × 1.82 × 1.32 (2.6) | 55 L | 245 | 6.7 | 258 | 46 000 | Métropole | Coupe |
| 12 | **Mistral** (`wk_mistral`) | Coupé GT / GT coupé | essence, automatique, propulsion | 330 | 1 720 | 4.75 × 1.92 × 1.33 (2.8) | 70 L | 290 | 5.7 | 306 | 98 000 | Métropole | Coupe |
| 13 | **Comète** (`wk_comete`) | Supercar / Supercar | essence, séquentielle, propulsion | 470 | 1 450 | 4.55 × 2 × 1.18 (2.7) | 80 L | 320 | 4.5 | 328 | 185 000 | Métropole | Supercar |
| 14 | **Zénith** (`wk_zenith`) | Supercar électrique / Electric supercar | électrique, rapport unique, intégrale | 600 | 1 900 | 4.7 × 2.02 × 1.2 (2.8) | 100 kWh | 300 | 3.2 | 297 | 210 000 | Métropole | Supercar |
| 15 | **Dune** (`wk_dune`) | SUV compact / Compact SUV | essence, automatique, intégrale | 120 | 1 600 | 4.45 × 1.84 × 1.66 (2.68) | 55 L | 195 | 10.1 | 197 | 34 000 | Banlieues | SUV |
| 16 | **Vigie** (`wk_vigie`) | Grand SUV / Large SUV | essence, automatique, intégrale | 240 | 2 080 | 4.95 × 1.96 × 1.74 (2.95) | 80 L | 240 | 6.7 | 243 | 72 000 | Banlieues | SUV |
| 17 | **Sentier** (`wk_sentier`) | Tout-terrain / Off-roader | essence, manuelle, intégrale | 90 | 1 300 | 3.9 × 1.76 × 1.72 (2.4) | 50 L | 165 | 11.3 | 176 | 26 000 | Banlieues | OffRoad |
| 18 | **Atlas** (`wk_atlas`) | Pick-up tout-terrain / Off-road pickup | diesel, automatique, intégrale | 150 | 2 250 | 5.3 × 1.95 × 1.82 (3.2) | 80 L | 185 | 9.8 | 195 | 52 000 | Banlieues | Pickup |

Les dix-huit couvrent les familles demandées : citadines (Pixel, Brio, Fil), compactes (Aster, Nova), berlines et
break (Cadence, Lumen, Orée), coupés et sportives (Brise, Rafale, Éclat, Mistral), supercars (Comète, Zénith), SUV
et tout-terrain (Dune, Vigie, Sentier, Atlas). Énergies : 11 essence, 3 diesel, 4 électriques. Boîtes : manuelle
(5), automatique (6), double embrayage, séquentielle, variation continue, rapport unique (4).

## 3. Véhicules de départ PROPOSÉS (trois candidats)

**Proposition en attente d'approbation.** La liste OFFICIELLE `StarterCatalog.Candidates` reste **vide** : en test
et en production, le choix est refusé (`StarterCatalogUnavailable`). Les trois candidats ci-dessous
(`StarterCatalog.Proposed`) ne sont utilisables qu'en **développement**, où l'exemplaire attribué est marqué
**synthétique**. Pour les activer, le propriétaire inscrit les trois identifiants retenus dans
`StarterCatalog.Candidates` (modification à valider par une revue).

| Critère | Brio (`wk_brio`) | Fil (`wk_fil`) | Aster (`wk_aster`) |
|---|---|---|---|
| Catégorie | Citadine | Citadine électrique | Compacte |
| Énergie, boîte, transmission | essence, **manuelle**, traction | **électrique**, rapport unique, traction | essence, **automatique**, traction |
| Puissance, masse | 70 kW, 1 050 kg | 85 kW, 1 320 kg | 95 kW, 1 280 kg |
| 0–100 km/h (banc) | 10,9 s | 10,8 s | 10,9 s |
| Vitesse annoncée / v60 (banc) | 175 / 182 km/h | 150 / 148 km/h | 195 / 195 km/h |
| Réserve | 42 L | 45 kWh | 48 L |
| Aides | ABS, antipatinage | ABS, antipatinage, ESP | ABS, antipatinage, ESP |
| Valeur catalogue | 16 500 crédits | 19 500 crédits | 19 000 crédits |
| Profil de conduite | légère, vive ; apprend le passage des rapports | couple immédiat, douce, silencieuse ; recharge aux bornes | polyvalente, confortable, la plus rapide sur route |
| Pour | prix le plus bas, sensation mécanique, la plus légère | conduite la plus simple, aucun calage, ESP | autoroute et longues missions, ESP, aucune gestion de boîte |
| Contre | pas d'ESP, calage possible | vitesse de pointe faible (150 km/h), dépend des bornes | moins impliquante, plus chère que la Brio |

Pourquoi ces trois : trois **façons de conduire** différentes (manuelle, électrique, automatique) pour des
performances voisines (0–100 km/h ≈ 10,8–10,9 s) et des valeurs proches (16 500 à 19 500 crédits), afin
qu'aucun choix ne donne un avantage économique ou sportif durable ; tous trois sont des tractions à aides
actives, sûres pour débuter. Aucun n'est une supercar, un tout-terrain ou un utilitaire de métier.

## 4. Géométrie et intérieurs réellement disponibles

| Élément | Disponible | Statut |
|---|---|---|
| Carrosserie par silhouette (Micro, Hatch, Sedan, Wagon, Coupe, Roadster, Supercar, SUV, OffRoad, Pickup) | Oui, construite par code (`BodyKits`) : coque, boucliers, ailes, calandre, vitrages, toit, montants, lunette ; arceaux (roadster), benne et hayon (pick-up), roue de secours (tout-terrain), aileron (supercar) | Provisoire — aucun maillage, aucune texture ; rendu NON TESTÉ visuellement |
| Habitacle | Planche de bord, combiné, console, dossiers ; siège conducteur et **place passager** | Provisoire, simplifié |
| Feux | Phares (SpotLight) et feux arrière (PointLight), allumés la nuit, en nombre limité | Provisoire ; feux stop des autres véhicules non représentés |
| Niveaux de détail | Détails (dossier `Carrosserie/Details`) masqués au-delà de 120 m (qualité moyenne) ou 250 m (haute) | Provisoire |
| Dommages visuels | Ceux du lot 0.2 (boucliers, phares/feux) | Inchangés |
| Variantes de teinte | Couleurs de caisse, d'accent et de garnissage par modèle | Provisoire |

## 5. Fiches détaillées (FR/EN)

### 1. Pixel — Citadine électrique

- FR : Minuscule et silencieuse, moteur arrière : idéale pour se faufiler en ville.
- EN : Tiny and quiet, rear motor: ideal for slipping through town.
- Motorisation : électrique, 45 kW ; boîte rapport unique ; propulsion ; pont 9.5
- Châssis : 880 kg, répartition avant 46 %, centre de gravité 0.46 m, pneus rayon 0.29 m × 165 mm, adhérence relative 0.95, braquage 36°, SCx 0.6 m²
- Aides : ABS, antipatinage, ESP ; silhouette `Micro`
- Vitesse annoncée 125 km/h ; plafond de démultiplication calculé 125 km/h ; banc planaire : 0–100 km/h 11.6 s, vitesse après 60 s 123 km/h
- Prix proposé 14 500 crédits ; concessions : Métropole

### 2. Brio — Citadine

- FR : Légère et vive, boîte manuelle : la plus simple pour apprendre à passer les rapports.
- EN : Light and lively, manual gearbox: the easiest way to learn shifting.
- Motorisation : essence, 70 kW ; boîte manuelle ; traction ; pont 3.9 ; zone rouge 7 000 tr/min
- Châssis : 1 050 kg, répartition avant 61 %, centre de gravité 0.5 m, pneus rayon 0.3 m × 185 mm, adhérence relative 0.98, braquage 35°, SCx 0.64 m²
- Aides : ABS, antipatinage ; silhouette `Hatch`
- Vitesse annoncée 175 km/h ; plafond de démultiplication calculé 337 km/h ; banc planaire : 0–100 km/h 10.9 s, vitesse après 60 s 182 km/h
- Prix proposé 16 500 crédits ; concessions : Métropole, Banlieues

### 3. Fil — Citadine électrique

- FR : Couple immédiat et rapport unique : conduite douce, recharge aux bornes.
- EN : Instant torque and a single gear: smooth driving, charge at the hubs.
- Motorisation : électrique, 85 kW ; boîte rapport unique ; traction ; pont 8.6
- Châssis : 1 320 kg, répartition avant 56 %, centre de gravité 0.48 m, pneus rayon 0.31 m × 195 mm, adhérence relative 0.98, braquage 35°, SCx 0.62 m²
- Aides : ABS, antipatinage, ESP ; silhouette `Hatch`
- Vitesse annoncée 150 km/h ; plafond de démultiplication calculé 150 km/h ; banc planaire : 0–100 km/h 10.8 s, vitesse après 60 s 148 km/h
- Prix proposé 19 500 crédits ; concessions : Métropole, Banlieues

### 4. Aster — Compacte

- FR : Polyvalente, boîte automatique : confortable au quotidien comme sur route.
- EN : Versatile, automatic gearbox: comfortable every day and on the road.
- Motorisation : essence, 95 kW ; boîte automatique ; traction ; pont 3.9 ; zone rouge 7 000 tr/min
- Châssis : 1 280 kg, répartition avant 60 %, centre de gravité 0.5 m, pneus rayon 0.315 m × 205 mm, adhérence relative 1, braquage 34°, SCx 0.64 m²
- Aides : ABS, antipatinage, ESP ; silhouette `Hatch`
- Vitesse annoncée 195 km/h ; plafond de démultiplication calculé 288 km/h ; banc planaire : 0–100 km/h 10.9 s, vitesse après 60 s 195 km/h
- Prix proposé 19 000 crédits ; concessions : Métropole, Banlieues

### 5. Nova — Compacte

- FR : Boîte à variation continue, consommation sage : la compacte tranquille.
- EN : Continuously variable gearbox, frugal: the relaxed compact.
- Motorisation : essence, 85 kW ; boîte variation continue ; traction ; pont 5.2 ; zone rouge 7 000 tr/min
- Châssis : 1 240 kg, répartition avant 60 %, centre de gravité 0.5 m, pneus rayon 0.31 m × 195 mm, adhérence relative 0.98, braquage 34°, SCx 0.6 m²
- Aides : ABS, antipatinage, ESP ; silhouette `Sedan`
- Vitesse annoncée 185 km/h ; plafond de démultiplication calculé 360 km/h ; banc planaire : 0–100 km/h 10.8 s, vitesse après 60 s 190 km/h
- Prix proposé 21 000 crédits ; concessions : Métropole

### 6. Cadence — Berline

- FR : Diesel automatique, grand empattement : stable et reposante sur longue distance.
- EN : Automatic diesel, long wheelbase: stable and relaxing over long distances.
- Motorisation : diesel, 110 kW ; boîte automatique ; traction ; pont 3.4 ; zone rouge 4 500 tr/min
- Châssis : 1 520 kg, répartition avant 60 %, centre de gravité 0.52 m, pneus rayon 0.325 m × 215 mm, adhérence relative 1, braquage 33°, SCx 0.62 m²
- Aides : ABS, antipatinage, ESP ; silhouette `Sedan`
- Vitesse annoncée 215 km/h ; plafond de démultiplication calculé 223 km/h ; banc planaire : 0–100 km/h 10.1 s, vitesse après 60 s 203 km/h
- Prix proposé 32 000 crédits ; concessions : Métropole

### 7. Lumen — Break

- FR : Diesel manuel et grand coffre : la voiture des métiers de livraison.
- EN : Manual diesel with a big boot: the delivery jobs car.
- Motorisation : diesel, 100 kW ; boîte manuelle ; traction ; pont 3.9 ; zone rouge 4 500 tr/min
- Châssis : 1 480 kg, répartition avant 60 %, centre de gravité 0.53 m, pneus rayon 0.32 m × 205 mm, adhérence relative 0.98, braquage 33°, SCx 0.66 m²
- Aides : ABS, antipatinage ; silhouette `Wagon`
- Vitesse annoncée 205 km/h ; plafond de démultiplication calculé 234 km/h ; banc planaire : 0–100 km/h 10.3 s, vitesse après 60 s 199 km/h
- Prix proposé 27 000 crédits ; concessions : Banlieues

### 8. Orée — Berline électrique

- FR : Deux moteurs, transmission intégrale : rapide, silencieuse et sûre.
- EN : Two motors, all-wheel drive: fast, quiet and secure.
- Motorisation : électrique, 230 kW ; boîte rapport unique ; intégrale ; pont 9
- Châssis : 2 050 kg, répartition avant 50 %, centre de gravité 0.47 m, pneus rayon 0.345 m × 245 mm, adhérence relative 1.05, braquage 32°, SCx 0.56 m²
- Aides : ABS, antipatinage, ESP ; silhouette `Sedan`
- Vitesse annoncée 220 km/h ; plafond de démultiplication calculé 220 km/h ; banc planaire : 0–100 km/h 6.1 s, vitesse après 60 s 217 km/h
- Prix proposé 68 000 crédits ; concessions : Métropole

### 9. Brise — Roadster

- FR : Découvrable, légère et propulsion : le plaisir de conduire avant la puissance.
- EN : Open-top, light and rear-driven: driving fun before power.
- Motorisation : essence, 110 kW ; boîte manuelle ; propulsion ; pont 3.9 ; zone rouge 7 000 tr/min
- Châssis : 1 060 kg, répartition avant 51 %, centre de gravité 0.44 m, pneus rayon 0.305 m × 205 mm, adhérence relative 1.05, braquage 33°, SCx 0.6 m²
- Aides : ABS, antipatinage ; silhouette `Roadster`
- Vitesse annoncée 210 km/h ; plafond de démultiplication calculé 342 km/h ; banc planaire : 0–100 km/h 10.9 s, vitesse après 60 s 182 km/h
- Prix proposé 33 000 crédits ; concessions : Banlieues

### 10. Rafale — Sportive compacte

- FR : Traction vive à double embrayage et différentiel autobloquant.
- EN : Lively front-driver with a dual-clutch gearbox and limited-slip differential.
- Motorisation : essence, 200 kW ; boîte double embrayage ; traction ; pont 3.9 ; zone rouge 7 000 tr/min
- Châssis : 1 420 kg, répartition avant 61 %, centre de gravité 0.47 m, pneus rayon 0.33 m × 235 mm, adhérence relative 1.1, braquage 33°, SCx 0.66 m²
- Aides : ABS, antipatinage, ESP ; silhouette `Hatch`
- Vitesse annoncée 250 km/h ; plafond de démultiplication calculé 328 km/h ; banc planaire : 0–100 km/h 6.6 s, vitesse après 60 s 260 km/h
- Prix proposé 42 000 crédits ; concessions : Métropole

### 11. Éclat — Coupé sportif

- FR : Coupé propulsion à boîte manuelle, équilibré, exigeant sur le mouillé.
- EN : Rear-driven coupé with a manual gearbox, balanced, demanding in the wet.
- Motorisation : essence, 185 kW ; boîte manuelle ; propulsion ; pont 3.9 ; zone rouge 7 000 tr/min
- Châssis : 1 360 kg, répartition avant 52 %, centre de gravité 0.45 m, pneus rayon 0.33 m × 235 mm, adhérence relative 1.1, braquage 32°, SCx 0.62 m²
- Aides : ABS ; silhouette `Coupe`
- Vitesse annoncée 245 km/h ; plafond de démultiplication calculé 370 km/h ; banc planaire : 0–100 km/h 6.7 s, vitesse après 60 s 258 km/h
- Prix proposé 46 000 crédits ; concessions : Métropole

### 12. Mistral — Coupé GT

- FR : Grand tourisme puissant et stable à haute vitesse.
- EN : Powerful grand tourer, stable at high speed.
- Motorisation : essence, 330 kW ; boîte automatique ; propulsion ; pont 3.9 ; zone rouge 7 000 tr/min
- Châssis : 1 720 kg, répartition avant 52 %, centre de gravité 0.46 m, pneus rayon 0.345 m × 265 mm, adhérence relative 1.12, braquage 31°, SCx 0.64 m²
- Aides : ABS, antipatinage, ESP ; silhouette `Coupe`
- Vitesse annoncée 290 km/h ; plafond de démultiplication calculé 316 km/h ; banc planaire : 0–100 km/h 5.7 s, vitesse après 60 s 306 km/h
- Prix proposé 98 000 crédits ; concessions : Métropole

### 13. Comète — Supercar

- FR : Moteur central, boîte séquentielle, appui aérodynamique : réservée aux pilotes aguerris.
- EN : Mid-engine, sequential gearbox, aerodynamic downforce: for seasoned drivers.
- Motorisation : essence, 470 kW ; boîte séquentielle ; propulsion ; pont 3 ; zone rouge 7 000 tr/min
- Châssis : 1 450 kg, répartition avant 42 %, centre de gravité 0.42 m, pneus rayon 0.34 m × 295 mm, adhérence relative 1.2, braquage 30°, SCx 0.6 m²
- Aides : ABS, antipatinage, ESP ; silhouette `Supercar`
- Vitesse annoncée 320 km/h ; plafond de démultiplication calculé 334 km/h ; banc planaire : 0–100 km/h 4.5 s, vitesse après 60 s 328 km/h
- Prix proposé 185 000 crédits ; concessions : Métropole

### 14. Zénith — Supercar électrique

- FR : Accélération foudroyante, intégrale, aides électroniques complètes.
- EN : Blistering acceleration, all-wheel drive, full electronic aids.
- Motorisation : électrique, 600 kW ; boîte rapport unique ; intégrale ; pont 6.9
- Châssis : 1 900 kg, répartition avant 45 %, centre de gravité 0.41 m, pneus rayon 0.345 m × 295 mm, adhérence relative 1.2, braquage 30°, SCx 0.58 m²
- Aides : ABS, antipatinage, ESP ; silhouette `Supercar`
- Vitesse annoncée 300 km/h ; plafond de démultiplication calculé 300 km/h ; banc planaire : 0–100 km/h 3.2 s, vitesse après 60 s 297 km/h
- Prix proposé 210 000 crédits ; concessions : Métropole

### 15. Dune — SUV compact

- FR : Garde au sol relevée et intégrale : à l'aise sur les chemins de campagne.
- EN : Raised ride height and all-wheel drive: at home on country tracks.
- Motorisation : essence, 120 kW ; boîte automatique ; intégrale ; pont 3.9 ; zone rouge 7 000 tr/min
- Châssis : 1 600 kg, répartition avant 57 %, centre de gravité 0.62 m, pneus rayon 0.35 m × 215 mm, adhérence relative 0.98, braquage 34°, SCx 0.82 m²
- Aides : ABS, antipatinage, ESP ; silhouette `SUV`
- Vitesse annoncée 195 km/h ; plafond de démultiplication calculé 321 km/h ; banc planaire : 0–100 km/h 10.1 s, vitesse après 60 s 197 km/h
- Prix proposé 34 000 crédits ; concessions : Banlieues

### 16. Vigie — Grand SUV

- FR : Lourd mais puissant, grand habitacle : confortable et rassurant.
- EN : Heavy yet powerful, roomy cabin: comfortable and reassuring.
- Motorisation : essence, 240 kW ; boîte automatique ; intégrale ; pont 3.9 ; zone rouge 7 000 tr/min
- Châssis : 2 080 kg, répartition avant 54 %, centre de gravité 0.66 m, pneus rayon 0.37 m × 255 mm, adhérence relative 1, braquage 32°, SCx 0.9 m²
- Aides : ABS, antipatinage, ESP ; silhouette `SUV`
- Vitesse annoncée 240 km/h ; plafond de démultiplication calculé 339 km/h ; banc planaire : 0–100 km/h 6.7 s, vitesse après 60 s 243 km/h
- Prix proposé 72 000 crédits ; concessions : Banlieues

### 17. Sentier — Tout-terrain

- FR : Court, haut et manuel : conçu pour la montagne, pas pour l'autoroute.
- EN : Short, tall and manual: built for the mountains, not the motorway.
- Motorisation : essence, 90 kW ; boîte manuelle ; intégrale ; pont 3.9 ; zone rouge 7 000 tr/min
- Châssis : 1 300 kg, répartition avant 55 %, centre de gravité 0.66 m, pneus rayon 0.36 m × 215 mm, adhérence relative 0.95, braquage 36°, SCx 0.86 m²
- Aides : ABS ; silhouette `OffRoad`
- Vitesse annoncée 165 km/h ; plafond de démultiplication calculé 404 km/h ; banc planaire : 0–100 km/h 11.3 s, vitesse après 60 s 176 km/h
- Prix proposé 26 000 crédits ; concessions : Banlieues

### 18. Atlas — Pick-up tout-terrain

- FR : Diesel robuste à benne, intégral : le compagnon des chantiers et du port.
- EN : Rugged diesel pickup with a bed, all-wheel drive: the companion of building sites and the harbour.
- Motorisation : diesel, 150 kW ; boîte automatique ; intégrale ; pont 3.9 ; zone rouge 4 500 tr/min
- Châssis : 2 250 kg, répartition avant 57 %, centre de gravité 0.7 m, pneus rayon 0.38 m × 255 mm, adhérence relative 0.97, braquage 33°, SCx 1 m²
- Aides : ABS, antipatinage ; silhouette `Pickup`
- Vitesse annoncée 185 km/h ; plafond de démultiplication calculé 227 km/h ; banc planaire : 0–100 km/h 9.8 s, vitesse après 60 s 195 km/h
- Prix proposé 52 000 crédits ; concessions : Banlieues
