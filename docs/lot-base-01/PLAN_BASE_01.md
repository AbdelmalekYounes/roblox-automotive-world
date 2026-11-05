# Lot BASE-01 — base propre à deux véhicules : plan

Branche `feat/base-01-deux-vehicules`, depuis `main` (`6a2dc34`). Plan rédigé le 2026-11-05. **Aucun code n'est encore
modifié** : le plan et les points du §5 sont à valider par le propriétaire.

## 1. Décisions du propriétaire (2026-11-05)

- « On va enlever je pense les 17 autres véhicules et repartir sur une base propre avec non seulement la Comète, et on va
  faire un autre véhicule en 3D bien fait. »
- Second véhicule : **citadine / compacte** (elle servira aussi de véhicule de départ).
- Fabrication : **modèle tiers sous licence libre (CC BY)**, comme la Comète.
- 17 autres modèles et parc d'essai : **tout supprimer** (les 17 modèles du catalogue, les prototypes P-01 à P-03, les
  variantes de validation, le parc d'essai et les carrosseries provisoires).

## 2. Écarts au cahier des charges (arbitrés par le propriétaire, à consigner)

| Cahier des charges | Exigence | Après BASE-01 |
|---|---|---|
| §1 et CH03 | « dix-huit modèles fictifs originaux » | **deux** modèles : Comète et citadine |
| §1.2 (non négociable) | véhicules fictifs originaux | deux modèles **tiers CC BY**, possiblement d'après des voitures réelles (risque de forme, voir audit §7.6) |
| CH09 | extérieurs et intérieurs soignés pour les 18 | soignés pour les 2 |
| Arrivée | trois véhicules de départ au choix | **un** : la citadine (tant qu'elle n'existe pas, voir §5, P2) |
| Gamme par familles et marques fictives | 4 marques, familles | sans objet pour l'instant |

Proposition : consigner ces écarts dans un fichier d'amendements (`docs/AMENDEMENTS_CAHIER_DES_CHARGES.md`), daté et
cité, **sans réécrire** le cahier des charges validé.

## 3. Ce qui disparaît (inventaire sur `main`, 2026-11-05)

**Code du jeu (21 fichiers concernés)** :
- **Définitions** :
  - supprimés : `PrototypeP01/P02/P03.luau`, `ValidationVariants.luau`, `WorkingCatalog.luau` ;
  - la Comète y est **dérivée** de P-03 et des variantes : sa définition doit devenir autonome, aux mêmes valeurs
    physiques.
- **Registre et catalogues** : `VehicleDefinitions.luau` (21 références), `VehicleCatalog.luau` (19),
  `StarterCatalog.luau`, `Texts08.luau` (36 : noms et descriptions des 18).
- **Carrosseries provisoires** : `BodyKits.luau` supprimé ; `VehicleFactory.luau` ne construit plus que des véhicules à
  kit de maillages.
- **Parc d'essai** : `VehicleService.luau` (dossier `VehiculesEssai`, `TestFleet`, `DefaultTestVehicle`).
- **Utilisateurs des prototypes** :
  - `Jobs.luau` et `MissionService.luau` (véhicules professionnels `proto_p01` et `proto_p02` : taxi, livraison…) ;
  - `DevSeed.luau` (véhicules de développement) ;
  - `OnboardingService.luau`.
- **Divers** : `AssetManifest.luau`, `MeshKitData.luau`, `Attributions.luau`, `VehicleLights.luau` (mentions).

**Tests** : 43 fichiers référencent les 17 modèles ou les prototypes.
- Lune : `Definitions`, `PhysicsUnit`, `DrivingScenarios`, `Lot02*`, `Lot03` à `Lot092`, `UiDesignSystem`, `Veh3d01Comete`,
  `PlaceStructure`…
- Sessions Studio : `Lot02`, `Lot04`, `Lot06`, `Lot08`, métiers, monde, UI, Comète, avatars…
- `test_scaffold.py`.

**Documents** :
- `docs/vehicle-3d/references/` (18 dossiers de références) ;
- fiches de `DIRECTION_ARTISTIQUE_VEHICULES.md` ;
- `PLAN_PRODUCTION_18_VEHICULES.md`, `CATALOGUE_REFERENCES.md` ;
- catalogue du lot 0.8.

## 4. Étapes proposées

**Partie A — base propre (code, ce lot)**
1. Définition **autonome de la Comète**, avec des valeurs identiques à celles calculées aujourd'hui. Contrôle : comparer
   la définition résolue avant et après (test Lune d'égalité).
2. Suppression des 17 modèles, des prototypes, des variantes, du parc d'essai et des carrosseries provisoires.
3. Rebranchement de tout ce qui les utilisait :
   - catalogue : Comète seule, puis citadine ;
   - véhicule de départ, métiers, crédits de développement (voir §5, P2) ;
   - textes ;
   - usine à véhicules sans carrosserie provisoire.
4. Tests : suppression ou réécriture des 43 fichiers selon le §5 (P1) ; `verify.ps1` au vert.
5. Documents : README, ROADMAP, QA_BACKLOG (les entrées propres aux 17 modèles sont closes « sans objet »), amendements
   du cahier des charges, archivage des documents des 17 (voir §5, P5).
6. Liste de vérification pour le propriétaire.

**Partie B — citadine 3D (lot suivant, VEH3D-02, même chemin que la Comète)**
1. Candidats CC BY recherchés : recherche en cours, en lecture seule. Choix du propriétaire, qui télécharge lui-même.
2. Inspection (outil d'inspection du dépôt d'art), puis préparation dans Blender : logos retirés, échelle, attaches,
   collisions, LOD.
3. Export glTF selon la règle d'étalonnage ; envoi des maillages sur Roblox par le propriétaire.
4. Définition physique de la citadine (voir §5, P3) et kit de maillages (`MeshKitData`) ; crédits CC BY.
5. Essais par le propriétaire.

## 5. Points à trancher par le propriétaire

- **P1 — tests de la physique.** Les prototypes servent aussi de **jeux d'essai** pour valider le moteur physique :
  boîtes manuelle, automatique, double embrayage, séquentielle, CVT ; moteurs diesel et électrique. La Comète seule
  (séquentielle, essence) ne couvre pas tout.
  - *Recommandé* : les supprimer du jeu, mais garder leurs données comme jeux d'essai **dans `tests/`**, jamais livrés
    dans le jeu.
  - *Variante* : tout réécrire sur la Comète et la citadine, en acceptant la perte de couverture.
- **P2 — en attendant la citadine.** Véhicule de départ, véhicules des métiers (taxi, livraison…) et crédits de
  développement n'auront plus de modèle adapté.
  - *Recommandé* : la Comète partout, provisoirement, en attendant VEH3D-02.
  - *Variante* : arrivée et métiers sans véhicule tant que la citadine n'existe pas.
- **P3 — physique de la citadine.** Énergie (essence, électrique…), boîte (manuelle, automatique…), puissance. À fixer
  avec le modèle choisi.
- **P4 — marques fictives** (Mivale, Orvane, Rocalt, Celvar). Les garder pour plus tard, ou les abandonner.
- **P5 — documents des 17.** *Recommandé* : les déplacer dans `docs/archive/` (historique conservé) plutôt que les
  effacer.
- **P6 — sauvegardes de profil.** Les profils de test qui possèdent un des 17 modèles. Aucun DataStore réel n'a jamais
  tourné, donc aucun joueur n'est concerné. Une migration du schéma retirera ou remplacera ces véhicules dans les
  profils existants (règle à fixer : remplacement par la Comète, ou retrait simple).

## 6. Contrôles prévus

- `scripts/verify.ps1 -DownloadRobloxTypes` au vert à chaque étape.
- Test Lune d'égalité de la définition de la Comète avant et après.
- Aucune session VM automatique (arrêt demandé par le propriétaire le 2026-11-05) : liste de vérification en jeu
  fournie au propriétaire.
- PR à la fin de la partie A, fusion sur son accord (`main` protégé : PR obligatoire).

## 7. Décisions du propriétaire sur les points ouverts (2026-11-05)

- **P1** : prototypes P-01 à P-03 et variantes de validation **supprimés du jeu**, gardés comme **jeux d'essai dans
  `tests/`** (jamais livrés), pour que la couverture du moteur physique reste entière.
- **P2** : **aucun véhicule provisoire**. Tant que la citadine n'est pas intégrée, l'arrivée ne propose pas de véhicule de
  départ, les métiers qui exigent un véhicule professionnel sont indisponibles avec une raison affichée, et les crédits de
  développement ne donnent plus de véhicule.
- **Ordre des lots** : BASE-01, puis ADMIN-01 (expérience privée et menu admin), puis VEH3D-02 (citadine) dès que le
  modèle est téléchargé.
- **Citadine** : **Milano '95** de Daniel Zhabotinsky (CC BY 4.0, 18,1 k triangles ; `docs/vehicle-3d/VEH3D_02_CANDIDATS.md`).
  Ressemblance avec la Fiat Punto mk1 acceptée par ce choix ; insigne de calandre et plaque à retirer.
- **Par défaut, sauf avis contraire du propriétaire** :
  - P5 : documents des 17 modèles archivés dans `docs/archive/` ;
  - P6 : migration du schéma de profil qui **retire** les 17 modèles des profils de test existants ;
  - P4 : marques fictives conservées dans les documents, sans usage en jeu.

## 8. Écarts d'exécution par rapport aux valeurs par défaut du §7 (2026-11-05)

- **P5** : les documents des 17 modèles **ne sont pas déplacés**. Le déplacement casserait les liens des rapports de lots
  historiques. Ils portent à la place un bandeau « ARCHIVE » : `CATALOGUE_18_VEHICULES.md`, `CATALOGUE_REFERENCES.md`,
  `PLAN_PRODUCTION_18_VEHICULES.md`, `DIRECTION_ARTISTIQUE_VEHICULES.md`. Les dossiers `docs/vehicle-3d/references/`
  restent en place.
- **P6** : **aucune migration du schéma**. Aucun profil persistant n'existe : le DataStore n'a jamais tourné, et tout est
  en mémoire en Dev. L'expérience de test (ADMIN-01) démarrera avec des profils neufs. Une migration ne serait utile que
  si des profils de test étaient créés avant BASE-01.

