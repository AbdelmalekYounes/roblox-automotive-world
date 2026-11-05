# Rapport du lot 0.2 — physique automobile avancée

Branche `feat/advanced-vehicle-physics-0.2` (depuis `0542fd0`, dernier commit du lot 0.1), PR brouillon #2 (base :
`feat/vehicle-vertical-slice-0.1`). Date des exécutions : 2 novembre 2026. Ce rapport ne contient **que des
exécutions réelles** : chaque chiffre cite la commande ou la tâche qui l'a produit. Les essais automatisés ne sont
pas des essais humains.

Changements d'architecture : `ARCHITECTURE_LOT_0.2.md`. Écarts au cahier des charges : `ECARTS.md`.

## 1. Synthèse

| Bloc | Livré | Vérifié hors Studio (Lune) | Vérifié dans Studio (VM) |
|---|---|---|---|
| Essence, diesel, électrique | Oui | Oui | 0–100 km/h, consommation, récupération, panne |
| Six boîtes | Oui | Oui | Les six atteignent 100 km/h ; passages ; marche arrière (A3) ; calage/relance (manuelle) |
| FWD / RWD / AWD, autobloquants | Oui | Oui (faible adhérence, virage, adhérence dissymétrique) | Partiel (accélération, démarrage sur mouillé) |
| Pneus : frottement statique, glissement combiné, mouillé, relaxation | Oui | Oui | Pente, mouillé contre sec, ABS |
| Suspension : sonde sphère | Oui (par défaut, d'après mesures) | — | Bordures rayon contre sphère |
| ABS, antipatinage, ESP | Oui | Oui | Avec / sans, état par défaut, aide absente, HUD |
| Dégâts (3 niveaux, mécanique) | Oui | Oui | Mur à 15 et 35 km/h, deux véhicules |
| Énergie (autorité serveur) | Oui | Oui | Débit serveur, récupération, panne sans recharge |
| P-02, P-03, configurations DCT / SEQ / CVT | Oui | Oui | Oui |
| Caméras cockpit / capot / pare-chocs | Oui | — | Oui (cycle à 37 km/h) |
| Mesures de coût | Oui | Banc CPU avant / après | VM : non représentatif |

Restent : essais humains (clavier, manette, ressenti), anomalies intermittentes du lot 0.1 (non corrigées),
différences d'architecture motrice en virage non mesurées dans Studio, performances représentatives (24 joueurs).

## 2. Vérifications hors Studio

Commande : `powershell -ExecutionPolicy Bypass -File scripts\verify.ps1 -DownloadRobloxTypes` (étapes exécutées
une à une pendant le développement, état final au commit `11ce9bf`) :

| Étape | Résultat |
|---|---|
| Rojo build | OK |
| Selene (src + suites Studio, dont `Lot02*`) | 0 erreur, 0 avertissement |
| Pilote Studio (7 sessions) généré et compilé | OK |
| StyLua | OK |
| luau-lsp strict (`--!strict`) | 0 erreur |
| Lune | **161 réussis / 0 échoué** (100 au lot 0.1) |
| pytest | 8 réussis |

Valeurs produites par le modèle sur le banc planaire Lune (indicatives, **pas des mesures en jeu**) :

| Mesure (banc) | Valeur |
|---|---|
| 0–100 km/h | automatique 8,67 s ; manuelle 10,18 s (conducteur simulé) ; électrique 5,70 s ; double embrayage 7,60 s ; séquentielle 7,50 s ; CVT 7,78 s |
| Convertisseur du P-01 | calage 2 400 tr/min ; rampement 5,6 km/h |
| Faible adhérence μ 0,35, 0–50 km/h (châssis P-01) | RWD 11,07 s ; FWD 10,73 s ; AWD 5,10 s |
| Roue arrière gauche sur μ 0,15, 0–40 km/h | ouvert 21,22 s ; autobloquant 6,02 s |
| Pleine charge en virage (μ 0,6), lacet après / avant | RWD 2,52 (survire) ; FWD 0,52 (sous-vire) |
| P-02, 80–0 km/h | sec 23,7 m ; mouillé 50,7 m |
| P-03, changement de file 80 km/h sur mouillé | dérive max 39,1° sans ESP, 5,5° avec |
| Croisière 90 km/h | P-01 9,8 L/100 km ; P-02 7,3 L/100 km ; P-03 18,2 kWh/100 km |
| Coût d'un pas de dynamique pure (P-01) | lot 0.1 (`0542fd0`) 20,7 µs ; lot 0.2 44,8 µs (× 2,2) — Lune, `build/scratch/bench.luau`, 5 séries de 20 000 pas |

## 3. Essais dans Roblox Studio (VM)

Commande : `tools\vm\host-run.ps1` (équivalent de `test-vm.cmd`), Studio `0.745.0.7451137` dans la VM, aucune
interaction avec le poste principal. Session `lot02` : 1 joueur, 22 étapes placées par le serveur de test
(`tests/studio/Lot02Server.server.luau`) et conduites par le vrai chemin du jeu (`Lot02Client.client.luau`).

### 3.1 Historique des exécutions

| Tâche | Commit | Sessions | Réussis / échecs / limites | Ce qui a été appris ou corrigé |
|---|---|---|---|---|
| `20261102-224147` | `b29c2ca` | lot02 | 132 / 5 / 0 | Bug : dégâts du percuteur nuls (vitesse lue après effacement de l'historique). Bug : ESP en « sous-virage » pendant un frein à main (dérive 13,2° contre 4,8°). Critère caméra capot (une image de retard). Borne d'éjection du lot 0.1 qui bridait les véhicules de banc |
| `20261102-225205` | `c30a12d` | 7 sessions | 455 / 11 / 1 | Choc à 35 km/h découpé en petits chocs (~2 m/s) → suivi d'événement 0,4 s. Essai ESP sans vrai survirage (≈ 5°) → changement de file. Véhicules encore en mouvement à 4 s dans 2 sessions → contrôle mesuré. Session « scenarios » : correction « Teleport » puis étape suivante faussée (famille de l'anomalie du lot 0.1) |
| `20261102-231537` | `7bdc776` | 7 sessions | 458 / 8 / 1 | Sonde sphère par défaut : un véhicule conduit percuté s'est retrouvé **sur le flanc** (1 essai sur 6) → la sphère ne s'appuie plus que sous la bande de roulement, jamais sur un autre véhicule. Limiteur d'actions serveur atteint par l'essai des aides → essai espacé |
| `20261102-233800` | `11ce9bf` | 7 sessions | **461 / 5 / 1** | **Campagne de référence** (§3.2 à §3.9) : session lot02 sans échec ; plus de véhicule renversé (12 essais « percuté conduit » droits) |

### 3.2 Boîtes et motorisations (ligne droite, départ arrêté)

Tâche `20261102-233800`. Ligne droite, départ arrêté, pleine charge ; passages de rapport par les mêmes
gestionnaires que les touches (Maj gauche / RB) pour les boîtes à sélecteur.

| Véhicule (boîte) | 0–100 km/h | Rapports vus | Marche arrière (A3) | Énergie consommée (client) |
|---|---|---|---|---|
| P-01 (automatique à convertisseur) | 8,92 s | 1 > 2 > 3 | maintien du frein, recul 16,0 st | 0,1019 L |
| P-02 (manuelle, diesel, traction) | 12,10 s (conducteur simulé) | 2 > 3 > 4 | sélecteur, recul 16,2 st | 0,0732 L |
| P-03 (rapport unique, électrique, intégrale) | 5,88 s | 1 | maintien du frein, recul 19,1 st | 0,2851 kWh |
| P-01 DCT (double embrayage) | 7,85 s | 1 > 2 > 3 | sélecteur, recul 11,0 st | 0,0802 L |
| P-01 SEQ (séquentielle) | 7,65 s | 2 > 3 | sélecteur, recul 11,2 st | 0,0796 L |
| P-01 CVT | 8,04 s | rapport continu (1,306 à 100 km/h) | maintien du frein, recul 10,4 st | 0,0851 L |

- Boîte manuelle (P-02) : passage refusé sans embrayage (reste au neutre) ; 1re engagée puis embrayage lâché sans
  gaz → **moteur calé**, relancé embrayage enfoncé.
- P-03 : lâcher 3 s à 100 km/h → 92,9 km/h, 0,0181 kWh récupérés (client).
- Au lot 0.1, le P-01 faisait 8,57 s (tâche `182028`) : écart dû au convertisseur, documenté (`ECARTS.md` §3).

### 3.3 Aides électroniques

Tâche `20261102-233800`.

| Contrôle | Mesure |
|---|---|
| État par défaut (P-03, équipé des trois aides) | ABS, antipatinage, ESP « désactivé » (état de la simulation et HUD) |
| Activation / désactivation (touches 1, 2, 3 ; confirmation serveur) | HUD « activé » puis « désactivé » |
| Réglage à la manette (croix gauche puis droite) | antipatinage activé |
| Aide absente (P-01, touche 1) | refus du serveur (« AidAbsent »), HUD « ABS : absent », attribut serveur `false` |
| ABS, freinage à fond depuis 61 km/h sur mouillé (P-03) | sans : roues avant bloquées 97 % du temps, 27,8 m ; avec : 0 %, 21,7 m |
| Antipatinage, démarrage pleine charge sur mouillé (P-02, 4 s) | glissement moyen AV 1,10 sans, 0,17 avec ; 32,9 / 37,9 km/h |
| ESP, changement de file à 80 km/h sur mouillé (P-03) | dérive max 38,5° sans, 6,5° avec ; ESP en action pendant l'essai |

L'ABS ne freine pas « mieux que le pneu » : il évite le blocage (la distance plus courte vient du glissement
combiné : roue bloquée = adhérence de glissement). L'antipatinage réduit le couple, l'ESP freine une roue ; aucune
aide ne modifie les limites d'adhérence (vérifié par les tests Lune).

### 3.4 Adhérence, pente, bordures

Tâche `20261102-233800`.

| Essai | Mesure |
|---|---|
| Freinage à fond depuis 60 km/h (P-03, sans ABS) | sec 16,9 m ; mouillé 27,8 m |
| Rampe à 10 %, P-01, frein à main seul, 8 s | glissement 0,000 st ; relâché : redescend de 9,7 st en 2,5 s |
| Rampe à 10 %, P-02, frein à 50 % au neutre, 8 s | glissement 0,000 st ; relâché : redescend de 9,9 st en 2,5 s |
| Bordures transversales de 12 cm à 30 km/h, P-01, **sonde rayon** | accél. verticale max 28,0 m/s², tangage max 0,67 rad/s |
| Idem, **sonde sphère** | accél. verticale max 15,9 m/s², tangage max 0,50 rad/s ; 0 repli sur le rayon |

Sonde sphère retenue par défaut : bénéfice mesuré dans trois campagnes (pic vertical 28,0 → 17,9 ; 28,4 → 16,7 ;
27,2 → 17,6 ; 28,0 → 15,9 m/s²), pour environ +8 µs de requêtes par pas (voir §3.8). Au lot 0.1, un véhicule freiné
glissait de quelques cm/s en pente ; il ne glisse plus (frottement statique).

### 3.5 Dégâts

Tâche `20261102-233800`, P-01 contre le mur de choc puis contre un autre P-01 garé.

| Essai | État serveur après le choc | Conséquence lue par la simulation du conducteur |
|---|---|---|
| Mur à ~15 km/h | usure avant 0,20 (niveau 1 : rayures), 1 choc, 3 éléments visuels | aucune conséquence mécanique |
| Mur à ~35 km/h (même véhicule) | usure avant 1,00 (niveau 3), moteur 0,50, direction 0,79, 2 chocs au total, 4 éléments visuels | puissance 68 %, tirage de direction −0,54°, HUD « AV importants, moteur 68 %, direction faussée, train FL » |
| Deux véhicules à ~25 km/h (percuteur contre flanc) | percuteur avant 0,28 ; percuté droite 0,28 ; 1 choc chacun, 2 lignes de journal (pas de double comptage) | percuteur : « AV rayures » |

Énergie inchangée par les chocs ; aucune correction de mouvement pendant la session lot02. Côté serveur : 4 chocs
confirmés, 1 variation de vitesse sans obstacle au contact (non retenue), 9 requêtes de volume.

### 3.6 Énergie

Tâche `20261102-233800`. Réserves de départ : 60 % (30 L, 33 L, 37,2 kWh).

| Véhicule | Retiré par le serveur | dont plancher physique | Déclaration client acceptée | Récupéré (serveur) |
|---|---|---|---|---|
| P-01 | 0,1019 L | 0,0572 L | 0,1019 L | — |
| P-02 | 0,0732 L | 0,0503 L | 0,0732 L | — |
| P-03 | 0,2851 kWh | 0,2506 kWh | 0,2851 kWh | 0,0776 kWh |
| P-01 DCT / SEQ / CVT | 0,0802 / 0,0796 / 0,0851 L | 0,0532 / 0,0522 / 0,0563 L | égale au retrait | — |

- Pour un client honnête, la déclaration (consommation détaillée) dépasse le plancher : c'est elle qui est retenue,
  bornée en débit. Le plancher reste le minimum imposé à un client qui déclarerait moins.
- **Panne sèche** (P-01, réserve fixée à 0,03 L par le point d'accès de test) : vide après 2,9 s à 44 km/h ;
  pleine charge 2 s : 35,9 → 31,1 km/h, moteur arrêté ; ressorti puis remonté : niveau 0, moteur ne repart pas.
- **Batterie vide** (P-03, 0,02 kWh) : vide après 1,5 s ; pleine charge 2 s : 26,2 → 25,4 km/h ; toujours vide après
  réembarquement ; aucune récupération créditée batterie vide.

### 3.7 Caméras et commandes

Tâche `20261102-233800`, configuration CVT à 37 km/h, bascule par le gestionnaire de la touche V / croix haut.

| Vue | Position caméra dans le repère du véhicule (st) | Vers l'avant | Remarque |
|---|---|---|---|
| Lointaine | x 0,0 · y 9,5 · z 24,9 | 0,98 | |
| Cockpit | x −1,1 · y 2,0 · z 1,9 | 1,00 | place du conducteur (à gauche), tête masquée localement |
| Capot | x 0,0 · y 2,1 · z −2,0 | 1,00 | |
| Pare-chocs | x 0,0 · y −0,3 · z −7,5 | 1,00 | |
| Proche | x 0,0 · y 6,4 · z 16,0 | 0,98 | |

Vitesse entre 36,0 et 38,3 km/h pendant les cinq bascules, conduite et simulation actives : aucune perte de
contrôle. Chaque action liée a une touche et un bouton de manette (aides : touches 1 / 2 / 3 au clavier, croix
gauche / droite à la manette). La lecture réelle des touches et boutons reste un essai humain.

### 3.8 Coûts mesurés (VM, 1 joueur, sans accélération graphique)

Tâche `20261102-233800`. **Non représentatif** : VM sans accélération graphique, un seul joueur, serveur et
client sur la même machine virtuelle. L'objectif « 24 joueurs à ~60 FPS » n'est **pas** déclaré atteint.

| Mesure | Médiane | P95 | P99 | Échantillons |
|---|---|---|---|---|
| Temps d'image client (en conduite, 5 bascules de caméra) | 16,66 ms | 18,81 ms | 19,76 ms | 365 images |
| Pas de simulation du véhicule piloté (client, P-01 CVT) | 220 µs | 428 µs | 662 µs | 564 pas |
| — dont requêtes physiques (4 par pas) | 52,8 µs | | | |
| Requêtes, sonde rayon / sphère (bordures) | 41,4 / 49,1 µs | | P99 155 / 224 µs | |
| Battement serveur, parc de 9 véhicules au repos | 0,094 ms | 0,201 ms | 0,327 ms | 901 |
| Battement serveur, 9 + 16 véhicules simulés par le serveur en mouvement | 0,209 ms | 0,427 ms | 0,735 ms | 1 200 |
| Pas d'un véhicule simulé par le serveur (banc) | 0,060 ms | 0,205 ms | 0,371 ms | 4 000 |
| Service de dégâts par battement (banc) | 0,191 ms | | 0,715 ms | |

Avant / après : pas de dynamique pure 20,7 → 44,8 µs (banc Lune, §2) ; sonde sphère ≈ +8 µs par pas (4 requêtes).
Les 16 véhicules du banc sont restés droits et en mouvement.

### 3.9 Non-régression du lot 0.1

Campagne `20261102-233800` (commit `11ce9bf`) : mêmes sessions qu'au lot 0.1, véhicules P-01 sur les plots 1 à 4.

| Session | Réussis / échecs / limites | Commentaire |
|---|---|---|
| solo | 36 / 0 / 0 | |
| multijoueur | 65 / 0 / 0 | |
| latence (100 ms) | 63 / 0 / 0 | |
| scenarios | 42 / 3 / 1 | voir ci-dessous |
| collision | 60 / 0 / 0 | percuté conduit 4,37 / 3,33 / 4,09 st, garé 2,50 / 4,20 / 2,45 st ; 3 échanges confirmés |
| collision_latence | 58 / 2 / 0 | 2 réattributions de propriété réseau et 1 correction « Teleport » (famille de l'anomalie du lot 0.1) |

**Session « scenarios »** : après l'essai de collision contre un véhicule garé, la sortie du véhicule n'a pas été
effective ; l'étape suivante du test a alors déplacé le personnage encore assis (donc le véhicule) : correction
« Teleport » par le serveur, puis contrôles « propriété refusée » faussés. Observé dans 2 campagnes sur 3 du lot 0.2
(`225205`, `233800`), jamais dans les campagnes finales du lot 0.1. Diagnostic ajouté et deux exécutions dédiées :
§3.10.

### 3.10 Sortie non effective dans « scenarios » : diagnostic

Tâche `20261102-235945` (commit `11ce9bf` + diagnostic de sortie dans `ScenarioClient`, commité ensuite) :
session « scenarios » exécutée deux fois. **89 réussis, 1 échec, 2 limites connues** : les deux sorties de véhicule
ont été effectives, aucune correction « Teleport », étape « propriété refusée » correcte (refus du moteur journalisé :
« Network Ownership API cannot be called on Anchored parts »).

| Exécution de « scenarios » pendant le lot 0.2 | Sortie après la collision | Correction « Teleport » |
|---|---|---|
| `225205` | non effective | oui |
| `231537` | effective | non |
| `233800` | non effective | oui |
| `235945` (×2) | effective | non |

Conclusion factuelle : défaut **intermittent** (2 exécutions sur 5), cause non établie ; il n'est pas possible
d'affirmer qu'il s'agit d'une régression du lot 0.2 ni de l'exclure. Le diagnostic consignera la vitesse, le rapport,
l'état assis et un éventuel refus « ExitTooFast » à la prochaine occurrence (`client.diag_sortie_<n>`).

Autre observation intermittente : l'attribut `SimulationOwnerUserId` a été vu une fois à 0 alors que le joueur était
propriétaire effectif (1 contrôle sur 7 101 dans `224147`, 1 sur 1 706 dans `235945`, 0 dans les autres sessions),
même famille que l'anomalie de propriété du lot 0.1.

## 4. Anomalies et limites

- **Anomalies du lot 0.1** (`docs/lot-0.1/RAPPORT_VALIDATION.md` §5) : toujours présentes et **non corrigées**.
  Observées pendant ce lot dans les sessions de collision (réattributions de propriété réseau, corrections
  « Teleport », un essai sans contact) ; sortie de véhicule non effective dans « scenarios » (2 exécutions sur 5,
  §3.10). Conformément à la demande, seules deux exécutions ciblées ont été ajoutées (diagnostic).
- **Nouvelles régressions trouvées et corrigées pendant le lot** : véhicule percuté renversé avec la sonde sphère
  (`231537`, corrigé dans `11ce9bf`) ; voir §3.1 pour les autres.
- Limites du lot 0.2 : `ECARTS.md` §3.

## 5. Essais humains restant à faire

1. Clavier : Maj gauche / Ctrl gauche (rapports), C (embrayage), 1 / 2 / 3 (aides), G (récupération), V (caméras).
2. Manette : RB / LB, B (embrayage), croix gauche / droite (réglages), croix haut (caméras).
3. Démarrage en côte et calage avec la boîte manuelle au clavier (rampe d'embrayage de 0,6 s) et à la manette.
4. Ressenti des six boîtes, du rampement de l'automatique, des aides et du glissement combiné (roue bloquée).
5. Lisibilité du HUD (aides, énergie, dégâts) et des vues cockpit / capot / pare-chocs.
