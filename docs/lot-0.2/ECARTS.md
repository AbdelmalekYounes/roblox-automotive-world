# Analyse des écarts — lot 0.2 par rapport au cahier des charges global v1.0

Légende : **Conforme** (dans le périmètre du lot) · **Partiel** · **Non commencé** (prévu dans un lot ultérieur, le
périmètre n'est pas réduit) · **À arbitrer**. « Vérifié en Studio » = contrôlé automatiquement dans Roblox Studio,
dans la VM de test (tâches citées dans `RAPPORT_LOT_0.2.md`) : les commandes y sont injectées par le chemin du jeu,
la lecture réelle du clavier et de la manette ne l'est pas. Les arbitrages A1 à A6 du lot 0.1 sont conservés
(`docs/lot-0.1/ECARTS.md` §3).

## 1. Exigences du prompt du lot 0.2

| § | Exigence | État | Commentaire |
|---|---|---|---|
| 1 | Branche depuis le dernier commit du lot 0.1, lot 0.1 intact, PR brouillon sur la branche 0.1 | Conforme | `feat/advanced-vehicle-physics-0.2` depuis `0542fd0` ; PR #2 en brouillon, base `feat/vehicle-vertical-slice-0.1` |
| 2 | Simulation semi-réaliste, jamais de vitesse attribuée | Conforme, vérifié en Studio | Forces aux contacts uniquement ; moteur = corps en rotation couplé par la boîte |
| 3 | Essence : courbe, ralenti, rupteur, frein moteur, consommation charge/régime | Conforme, vérifié en Studio (consommation, rupteur) | Lune : ralenti régulé, rupteur, frein moteur, débit selon charge et régime, coupure en décélération |
| 3 | Diesel : couple à bas régime, plage adaptée, consommation différenciée | Conforme | P-02 (zone rouge 4 500 tr/min, couple max dès 2 000) ; consommation spécifique plus faible (Lune) |
| 3 | Électrique : couple, puissance et vitesse limitées, récupération configurable, batterie | Conforme, vérifié en Studio | P-03 ; récupération au lâcher (3 niveaux) et au freinage ; récupération créditée par le serveur seul |
| 4 | Automatique à convertisseur, manuelle avec embrayage, double embrayage, séquentielle, CVT, rapport unique | Conforme, vérifié en Studio | Chaque boîte atteint 100 km/h en Studio ; passages, marche arrière (A3), calage et relance (manuelle) |
| 4 | Changements de rapport selon les conditions mécaniques | Conforme | Embrayage exigé (manuelle), marche arrière à l'arrêt seulement, rétrogradation refusée au-delà du rupteur (boîtes pilotées) |
| 4 | Commandes ergonomiques clavier et manette, A1–A6 conservés | Conforme, **non vérifié par un humain** | Maj/Ctrl, RB/LB, C/B ; gestionnaires communs vérifiés en Studio ; ergonomie réelle à essayer |
| 5 | FWD/RWD/AWD, distribution de couple, différentiels, autobloquant configurable | Conforme | `Driveline` ; P-03 : central et arrière autobloquants |
| 5 | Différences observables (accélération, virage, faible adhérence, perte de motricité) | Partiel | Mesurées sur le banc Lune (μ 0,35 : AWD 2× plus rapide ; virage sous charge ; adhérence dissymétrique) ; en Studio : seulement accélération et démarrage sur mouillé |
| 6 | Frottement statique en pente | Conforme, vérifié en Studio | Glissement 0,000 st en 8 s sur la rampe à 10 % (frein à main P-01, frein P-02) |
| 6 | Adhérence longitudinale/latérale, perte progressive, sec/mouillé, charge verticale, relaxation | Conforme | Glissement combiné ajouté (roue bloquée sans force latérale) ; mouillé vérifié en Studio |
| 6 | Amortissement, débattement, bordures et irrégularités, balayages de forme selon les mesures | Conforme, vérifié en Studio | Sonde sphère retenue après mesures (pic vertical sur bordures de 12 cm : 28,0 → 15,9 m/s²) ; contact limité à la bande de roulement après un renversement mesuré |
| 6 | Pas de thermique des pneus ni d'usure périodique | Conforme | Non implémentés, volontairement |
| 7 | ABS, antipatinage, ESP présents seulement si équipé, désactivés par défaut, affichés, sans adhérence ajoutée | Conforme, vérifié en Studio | Aide absente refusée par le serveur ; remise à « désactivée » à chaque embarquement |
| 7 | A1 distinct de l'ESP, aucun correcteur caché | Conforme | `maxSteerAngle` ne lit que la vitesse ; aucune autre correction de trajectoire dans le code |
| 8 | Dégâts : rayures, localisés, importants avec conséquences mécaniques, confirmés serveur | Conforme, vérifié en Studio | Mur de choc à 15 puis 35 km/h ; deux véhicules ; voir limites §3 |
| 8 | Pas de persistance ; conception persistable | Conforme | État versionné en attributs `Dmg…` ; aucune sauvegarde |
| 9 | Essence, diesel, électricité distincts ; panne sans recharge gratuite ; validation serveur | Conforme, vérifié en Studio | Plancher physique serveur ; réserve vide verrouillée ; toujours vide après réembarquement |
| 10 | P-01 conservé, P-02 et P-03 conformes, configurations DCT / SEQ / CVT | Conforme | Plots 5 à 9 ; plots 1 à 4 gardent le P-01 |
| 11 | Cockpit, capot, pare-chocs ; clavier/manette ; sans perte de contrôle | Conforme, vérifié en Studio | Cycle de 5 vues à 37 km/h sans écart de commande |
| 12 | Mesures : temps par véhicule, requêtes physiques, temps d'image, dégâts, plusieurs véhicules ; avant/après | Partiel | Mesurées dans la VM (1 joueur, sans accélération graphique) : non représentatives de 24 joueurs à ~60 FPS, objectif **non déclaré atteint** |
| 13 | Tests ciblés et vérifications Rojo/Selene/StyLua/Luau/Lune/Python ; VM Studio | Conforme | Voir rapport |
| 14 | Périmètre exclu non commencé | Conforme | Aucun monde ouvert, station, crédit, profil, garage, compétition, GPS, catalogue |

## 2. Cahier des charges global — chapitres concernés (état après le lot 0.2)

| Réf. | Exigence | État |
|---|---|---|
| §1.2 | Physique différenciée par véhicule, transmission, motorisation, puissance, masse | Partiel — trois prototypes et trois configurations différenciés ; catalogue de 18 modèles non commencé |
| §1.2 | Aides seulement si le modèle en dispose, désactivées par défaut, pas d'aide cachée | Conforme |
| §3.2 | Propulsion / traction / intégrale ; boîtes automatique, manuelle, double embrayage, séquentielle, CVT ; thermique et électrique | Conforme (prototypes techniques) |
| §3.2 | Grip sec / pluie | Partiel — revêtement mouillé par zone ; météo dynamique non commencée (lot 0.3) |
| §3.3 | Trois niveaux de dégâts, effets mécaniques | Conforme en session ; « déformation limitée » représentée par des panneaux visuels décalés (la géométrie de collision ne change pas) |
| §3.3 | Persistance des dégâts et de l'énergie | Non commencé (lot 0.4) |
| §3.3 | Pas de maintenance périodique ni de thermique avancée des pneus | Conforme |
| §3.4 | Cockpit, capot, pare-chocs | Conforme ; mode photo non commencé (lot 0.8) |
| §3.5 | Désenlisement sans effet sur dégâts ni carburant | Conforme par construction (code inchangé, position seulement) ; **non retesté en Studio au lot 0.2** |
| §2.4 / AUD-WORLD-01 | Batterie vide sans recharge gratuite | Conforme (aucune recharge n'existe) ; recharge payante non commencée |
| AUD-PHYS-01 / AUD-COLL-01 | Dégâts et énergie confirmés serveur, tolérance réseau, prudence sans immunité | Conforme, vérifié en Studio ; sous latence non mesuré pour les dégâts |
| AUD-PERF-01/02 | 24 joueurs, ~60 FPS, percentiles | Non atteint / non mesuré de façon représentative |

## 3. Limites et écarts connus

- **A3 en pente** : avec une boîte automatique, CVT ou à rapport unique, maintenir « freiner » à l'arrêt engage la
  marche arrière ; sur une pente, le conducteur recule s'il garde le frein. Comportement conservé tel qu'arbitré ;
  le frein à main tient. **À arbitrer** si un maintien en pente « au pied » est souhaité.
- **Rampement** : la boîte automatique à convertisseur fait avancer le P-01 au pas (≈ 5,6 km/h sur le banc) quand on
  relâche le frein ; au lot 0.1 il restait immobile. Comportement réel d'un convertisseur, à confirmer par un humain.
- **Ressenti du P-01** : le convertisseur et le glissement combiné modifient le comportement validé au lot 0.1
  (0–100 km/h mesuré en Studio 8,92 s, tâche `233800`, contre 8,57 s au lot 0.1). Les paramètres n'ont pas été recalibrés.
- **Dégâts** : seuil de détection au-delà de la décélération maximale d'un freinage (≈ 10 à 13 km/h d'impact) :
  les frôlements ne laissent rien. Détection sur les vitesses répliquées : l'anomalie de réplication du lot 0.1
  (mouvement qui arrive par à-coups) pourrait produire une variation de vitesse ; elle n'est retenue que si un
  obstacle est au contact. Chocs sous latence, frontaux entre deux joueurs et à plus de deux véhicules : non testés.
- **ESP** : décrochage provoqué au frein à main ; l'ESP ne peut pas l'empêcher (le frein à main reste prioritaire).
- **Performances** : le pas de dynamique pure coûte environ 2,2 fois celui du lot 0.1 (banc Lune). Les mesures dans
  la VM ne sont pas représentatives d'un appareil de référence ni de 24 joueurs.
- **Anomalies du lot 0.1** : documentées dans `docs/lot-0.1/RAPPORT_VALIDATION.md` ; **non corrigées** par ce lot.
- **Essais humains** : clavier et manette réels (rapports, embrayage, aides, caméras), ressenti des boîtes et des
  aides : non réalisés.
