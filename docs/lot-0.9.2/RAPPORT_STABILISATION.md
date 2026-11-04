# Rapport de stabilisation — lot 0.9.2

Branche `feat/final-stabilization-0.9.2`, créée depuis `bf81465` (tête de la PR #10, lot 0.9.1), PR brouillon
[#11](https://github.com/AbdelmalekYounes/roblox-automotive-world/pull/11) vers `feat/autonomous-interactive-qa-0.9.1`.
`main` intacte ; rien n'est fusionné. **La V1.0 n'est pas commencée** ; aucune refonte graphique (le système de
conception est traité à part). Tous les essais Studio dans la VM ; aucune publication, aucun DataStore réel.

## 1. QA-A08 — valeurs non finies : cause établie et corrigée

### 1.1 Conditions de l'incident (tâche VM `20261103-224247`)

Session `metiers`, véhicule personnel **P-01** (boîte automatique à **convertisseur de couple**), trains avant
endommagés, plaqué contre une installation du parcours de précision ; le pilote alternait marche avant et marche
arrière (« dégagement »). Les 2 372 erreurs `TireModel.stopClamp` ont commencé 0,33 s après un passage en marche
arrière (21:53:45,34 → 45,67) et ont cessé quand le pilote est descendu puis remonté (état de simulation recréé).

### 1.2 Recherche

- Outil `tests/lune/tools/nan-hunt.luau` (scénarios `tests/lune/NanHunt.luau`) : exploration **reproductible** de
  `VehicleDynamics.step` — dégâts dans les bornes de `DamageModel`, contacts d'un véhicule plaqué, marches avant et
  arrière, pas de temps réels du simulateur (1 ms à 1/20 s, `VehicleSimulator.MAX_STEP_S`), à-coups de collision,
  calages, passages, panne d'énergie ; arrêt à la première valeur non finie avec l'historique des six pas.
- Premiers essais (270 000 pas, sans à-coups ni événements) : aucune valeur non finie.
- Avec à-coups et événements : divergences, **uniquement sur les boîtes à convertisseur** (P-01, `wk_mistral`,
  `wk_vigie`) ; jamais sur les boîtes manuelles (P-02, Brio) ni l'électrique (P-03). Toujours véhicule plaqué.
- Pistes écartées à la lecture : repère de contact du simulateur (déjà protégé : sphère limitée aux faces tournées
  vers le haut, axe avant de secours), pas de temps (borné), sorties de `DamageModel` (bornées), entrées réseau
  (`InputCodec` refuse les valeurs non finies).

### 1.3 Cause

Le couple du convertisseur (`Transmission.converterTorques`) croît comme le **carré** des vitesses
(`k · max(|ωp|, |ωt|) · (ωp − ωt)`) et était intégré **explicitement** dans les sous-pas, sans borne de stabilité.
Roues motrices lancées alors que le véhicule est plaqué (−133 rad/s contre un moteur à 542 rad/s : la turbine tourne
plus vite que la pompe), le couple calculé dépasse en un sous-pas l'écart qu'il doit réduire et l'inverse en
l'amplifiant ; comme il croît avec cet écart, la divergence s'emballe : −133 → −1,48·10⁶ → −4,9·10⁶⁹ rad/s → ∞ →
NaN (graine 8, scénario 83, P-01). `stopClamp` n'était que le premier calcul à lever une erreur. Le scénario de
l'incident (plaqué, alternances avant / arrière, roues motrices qui patinent) réunit exactement ces conditions.

### 1.4 Correction (`ebe4714`)

Borne de stabilité du schéma explicite (`VehicleDynamics.ConverterStabilityFactor = 1,8`) : en un sous-pas, l'écart
pompe/turbine peut changer de signe (dépassement que le schéma faisait déjà) mais son amplitude ne peut plus croître
(au plus 0,8 fois l'écart). Le modèle continu du convertisseur n'est pas modifié. Une première borne plus stricte
(« au plus annuler l'écart ») a été **rejetée** : le test montrait qu'elle agissait au départ arrêté de `wk_mistral`
(670 sous-pas), donc qu'elle modifiait la conduite normale.

Protection défensive du lot 0.9.1 **conservée** (neutralisation comptée et annoncée, `stopClamp` sans erreur).

### 1.5 Preuves et tests de régression (`tests/lune/specs/Lot092Stabilization.luau`)

| Vérification | Avant (`bf81465`) | Après |
|---|---|---|
| 13 scénarios fixés (P-01, `wk_mistral`) | ∞ puis NaN (13 / 13) | finis, **0 neutralisation**, borne active |
| Exploration élargie (tous les modèles, 60 scénarios) | — | 0 valeur non finie |
| 4 500 scénarios (5 modèles à convertisseur × 3 graines × 300) | divergences sur 3 modèles | **0** |
| Conduite normale (7 modèles à convertisseur : départ, freinage, marche arrière, reprise) | — | **0 sous-pas limité** |
| Entrées du conducteur et énergie (`InputCodec`) | — | NaN / ∞ refusés |
| Portefeuille (`Wallet`) | — | crédit NaN / ∞ refusé, solde intact, profil valide |

Non vérifié : reproduction **dans le moteur** de l'incident exact (conditions de patinage et de collision non
rejouables à l'identique) ; contrôle en jeu : aucune neutralisation relevée dans les campagnes VM du lot (§6).

## 2. QA-A09 — virage du joueur 2 après la marche arrière : erreur du scénario de test

Trajectoire tracée toutes les 0,25 s (session `latence`, tâche `20261104-020328`, 1 échec sur 6 sessions) :
le véhicule du joueur 2 (plot à x = 10,1 m) termine le freinage à x ≈ 8,0 m (dérive d'environ 2 m), recule jusqu'à
z = −180 m (rapport R, 28 km/h au plus), puis l'élan des virages l'emmène vers le nord : **à (8,2 ; −199,8) m et
37,5 km/h, choc frontal confirmé par le serveur contre le poteau droit du portique d'arrivée du drag d'essai**
(7,6 ; −204 m ; `Δv 13,6 m/s`), puis immobilisation contre le poteau : virage mesuré 0,0° (ou −148° quand le choc
le fait pivoter).

- Le même choc figure dans toutes les tâches où l'échec apparaît, y compris avec le code du lot 0.9 (`20261104-011801`).
- Boîte (R puis 1), commandes, propriété réseau et latence : conformes dans la trace ; aucune erreur.
- **Classement : erreur du scénario de test** (essais du lot 0.1 dont la ligne croise, à 2 m près, une installation
  du lot 0.6). Ce n'est pas un défaut de conduite.
- Correction du test (`9715443`) : pendant l'élan, le véhicule tient la ligne de son plot (correction de direction
  douce), comme un conducteur ; la mesure du virage est inchangée.
