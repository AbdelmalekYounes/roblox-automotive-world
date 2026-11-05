# Lot BASE-01 — base propre à deux véhicules : rapport

Branche `feat/base-01-deux-vehicules`, depuis `main` (`6a2dc34`). Rapport du 2026-11-05.
- Décisions du propriétaire : `PLAN_BASE_01.md` §1 et §7 ; écarts au cahier des charges :
  `docs/AMENDEMENTS_CAHIER_DES_CHARGES.md` (A-01).
- Rien n'est fusionné ni publié.
- Aucune session VM n'a été lancée : arrêt des tests automatiques demandé par le propriétaire.

## 1. Ce qui a été fait

**Comète autonome**
- `src/shared/Vehicles/Definitions/Comete.luau` contient la définition **résolue** que calculait `WorkingCatalog` sur
  `main`. Elle a été générée par `tests/lune/tools/dump-definition.luau` (outil en lecture seule).
- Référence figée : `tests/lune/fixtures/comete_definition_reference.json`.
- Test Lune `Base01` : égalité valeur par valeur (tolérance relative de 1e-12, due au lecteur JSON de Lune ; voir le
  test).

**Retirés du jeu**
- `PrototypeP01/P02/P03.luau`, `ValidationVariants.luau` et `WorkingCatalog.luau`, soit 17 modèles plus les prototypes
  et les variantes.
- `BodyKits.luau` : les 10 carrosseries provisoires.
- Le parc d'essai (`VehicleDefinitions.TestFleet`, apparition sur les plots). Les plots restent dans la carte, vides.
- Dans `VehicleFactory`, la branche des carrosseries provisoires. Seule une **coque de repli** générée par code reste
  utilisée, si le kit de maillages d'un modèle manquait.

**Rebranchés**

| Élément | Avant | Après BASE-01 |
|---|---|---|
| Registre `VehicleDefinitions` | 3 prototypes, 3 variantes, 18 modèles | la Comète seule ; `DefaultTestVehicleId = "wk_comete"` (bancs de Studio) |
| Catalogue `VehicleCatalog` | 18 entrées, 18 emplacements | 1 entrée (Comète, `PendingApproval`, achetable en Dev seulement), 2 emplacements |
| Départ `StarterCatalog` | 3 proposés (Brio, Fil, Aster) en Dev | **aucun** (point P2) ; choix refusé partout ; l'arrivée passe le choix et se termine |
| Métiers (`Jobs`, `MissionService`) | taxi et livraison sur P-02, convoi et essais sur P-01 | sans véhicule de service : refus « NoProfessionalVehicle » (texte FR/EN) ; taxi et livraison restent possibles avec sa propre voiture |
| Crédits de développement (`DevSeed`) | 3 prototypes synthétiques et 150 000 crédits | aucun véhicule ; **250 000 crédits**, pour pouvoir acheter la Comète (185 000) en Dev |
| Arrivée (`OnboardingService`) | fiches lues dans `WorkingCatalog` | fiches lues dans la définition et le catalogue |
| Textes (`Texts08`) | 36 entrées des 18 modèles | celles de la Comète |
| Manifeste | 10 silhouettes et la coque de prototype | coque de repli, optiques des kits, Comète |

**Tests**
- Prototypes et variantes conservés comme **jeux d'essai** : `tests/lune/fixtures/*.luau`, générés depuis `main` avec
  les valeurs exactes, et index `Fixtures.luau`.
- Les tests de physique (boîtes manuelle, automatique, double embrayage, séquentielle, CVT ; diesel, électrique) les
  utilisent.
- Tests adaptés : catalogue, départ, économie (soldes relevés pour la Comète), stabilisation, interface, Comète.
- **Tests retirés avec leur objet** :
  - gabarit de l'Aster (3 tests) ;
  - QA-F15 sur les carrosseries provisoires ;
  - calage par rebond sur l'Atlas ;
  - 10 cas QA-A08 de la Mistral.

  C'est consigné dans QA-B03.
- Outils retirés : `aster-template.luau`, `cabin-geometry.luau`. Outils adaptés : `vehicle-geometry`, `a08-repro`,
  `converter-nominal`, `nan-hunt`, `stall-impact`.

**Documents**
- Amendement A-01 au cahier des charges.
- Bandeau « ARCHIVE » sur les documents des 18 modèles.
- README, ROADMAP et QA_BACKLOG (§3 nonies) mis à jour.

## 2. Contrôles exécutés (2026-11-05)

| Commande | Résultat |
|---|---|
| `lune run tests/lune/run.luau build/AutomotiveWorld.rbxlx` | **389 réussis, 0 échec** (dont `Base01` : égalité de la Comète, registre et dossier propres) |
| `scripts\verify.ps1 -DownloadRobloxTypes` | toutes les étapes OK : Rojo, Selene, pilote Studio, StyLua, Lune, carte, place monde ouvert, pytest, luau-lsp strict (résultat final au §5) |
| `lune run tests/lune/tools/vehicle-geometry.luau build/AutomotiveWorld.rbxlx wk_comete build/geo.json` | 4 roues, sortie écrite |
| `lune run tests/lune/tools/converter-nominal.luau build/AutomotiveWorld.rbxlx` | P-01 (jeu d'essai) : 0 sous-pas limité |

## 3. Non testé, limites

- **Aucun essai en jeu** : liste de vérification ci-dessous.
- **Sessions VM non adaptées** (QA-B01). Elles supposent le parc d'essai ou les modèles retirés : `lot02`, `lot04`,
  `lot06`, `lot08`, `scenarios`, `monde`, `gps`, `ui*`, `avatar*`, `comete*`. Elles se compilent mais échoueraient à
  l'exécution.
- Couverture réduite des reproductions liées aux modèles retirés (QA-B03).
- **Sans véhicule fourni**, un joueur n'a de voiture qu'en achetant la Comète, en Dev seulement. En test ou en
  production, aucun véhicule n'est obtenable avant ADMIN-01 (menu admin) ou VEH3D-02 (citadine). C'est la conséquence
  voulue du point P2.

## 4. Ce que le propriétaire doit vérifier (Studio, place de cette branche)

Préparation : `rojo build default.project.json -o build\AutomotiveWorld-base01.rbxlx`, dans
`E:\ROBLOX DEV\aw-wt-base`. Ouvrir ce fichier dans Studio, puis cliquer sur Jouer.

1. **Démarrage** :
   - aucune erreur rouge dans la sortie ;
   - la zone d'essai s'affiche, les plots verts sont vides.
2. **Arrivée** (profil neuf) :
   - le parcours se termine sans demander de choisir un véhicule ;
   - aucun écran bloqué.
3. **Garage (P)** :
   - collection vide au départ ;
   - aucune carte de modèle retiré.
4. **Concession (J, devant la concession Métropole)** :
   - seule la **Comète** est proposée ;
   - « Devis d'achat » puis « Confirmer » : achat confirmé, solde de 250 000 moins 185 000.
5. **Comète achetée** : la sortir du garage, monter, rouler, sortir. Elle doit être identique à avant (physique
   inchangée, contrôlée par le test d'égalité).
6. **Métiers (J, onglet Métiers)** :
   - « Taxi » ou « Livraison » avec la Comète sortie : la mission démarre ;
   - sans voiture sortie, et pour « Convoi » ou « Essais » : refus « Aucun véhicule de service n'est disponible pour ce
     métier pour le moment ».
7. **Téléphone (T) › Véhicules** : aucune fiche de modèle retiré.
8. **Accès de revue** (Studio, côté Server) : `print(game.ServerStorage.AWRevue:Invoke("wk_comete"))` fait apparaître
   une Comète ; `print(game.ServerStorage.AWRevue:Invoke("wk_brio"))` répond « Échec (modèle inconnu…) ».

## 5. Résultat final de `verify.ps1`

Dernière exécution, le 2026-11-05, après toutes les modifications du lot : `scriptserify.ps1 -DownloadRobloxTypes`. Toutes
les étapes sont OK : Rojo, Selene, pilote Studio, StyLua, Lune (389 réussis, 0 échec), carte du monde ouvert, place monde
ouvert, pytest, luau-lsp strict.

## 6. Vérification par le propriétaire (2026-11-05)

Essai en jeu du propriétaire dans Studio, place `build/AutomotiveWorld-base01.rbxlx` (commit `6fcde41`) : **points 1 à 7
du §4 validés** (« 1. OK … 7. OK »). Le point 8 (accès de revue) n'a pas été rapporté. Clôture et fusion autorisées par le
propriétaire le 2026-11-05.

