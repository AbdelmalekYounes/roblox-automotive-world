# Lot VEH3D-02 — la Brio (citadine 3D)

Branche du jeu : `feat/veh3d-02-citadine` (depuis `main` 181919a). Branche d'art : `veh3d-02-citadine` (dépôt
`roblox-automotive-world-art`, depuis ded10e6). Rapport rédigé le 2026-11-05.

## 1. Décisions du propriétaire (2026-11-05)

| Sujet | Décision |
|---|---|
| Modèle | « Milano '95 - Low poly model », Daniel Zhabotinsky, CC BY 4.0 (`MODELES_TIERS.md`) |
| Nom | **Brio** (`wk_brio`) |
| Mécanique | essence, boîte **automatique**, traction |
| Rôles | véhicule de **service des métiers** et **achetable en concession** ; **pas** véhicule de départ |
| Optiques | matériaux unis (la texture d'origine assemble des photos de vrais blocs optiques) |
| Intérieur | gardé ; logos à vérifier |
| Carrosserie | peinture unie |

L'identifiant `wk_brio` vient de l'ancienne gamme proposée (lot 0.8, retirée par BASE-01). Il est repris pour la nouvelle
définition. Aucun profil réel ne possédait l'ancien modèle : il n'a jamais été achetable hors Dev.

## 2. Réalisé

### 2.1 Dépôt d'art (Blender 4.5.9, arrière-plan, `--factory-startup --disable-autoexec`)

Détail et mesures : `MODELES_TIERS.md` §6.

- `milano95_prepare.py` :
  - insignes et plaques supprimés ;
  - matériaux unis ;
  - échelle tirée de l'empattement (0,9987 de l'échelle réelle) ;
  - quatre roues séparées, pivot au moyeu, écart à la physique ≤ 0,052 st ;
  - six rendus de revue (`vehicles/wk_brio/renders_milano95/`).
- `milano95_finish.py` :
  - **13 contrôles sur 13** ;
  - repères des places et des caméras, plancher, pavillon ;
  - 4 boîtes de collision, feux, marques de dégâts ;
  - LOD1 et LOD2 préparés, non exportés.
- `export_roblox_glb.py` : `vehicles/wk_brio/export/wk_brio_milano95_lod0.glb`, 27 pièces, 17 865 triangles. Le relevé
  des centres attendus dans Studio est dans `wk_brio_milano95_lod0.json`.

### 2.2 Jeu

| Élément | Fichier | Contenu |
|---|---|---|
| Définition | `src/shared/Vehicles/Definitions/Brio.luau` | Définition autonome générée par la règle de l'ancienne gamme (WorkingCatalog de `main` 6a2dc34, base P-01 essence) à partir des cotes réelles : 3,85 m, empattement 2,42 m, 960 kg, 55 kW, roues de 0,28 m ; ABS et antipatinage. Figée par `tests/lune/fixtures/brio_definition_reference.json` |
| Kit de maillages | `src/shared/Vehicles/MeshKitData.luau` | Entrée `wk_brio`, gabarit `Brio`, valeurs mesurées de `finition.json`. Pose standard `Conduite` / `Passager`. Les verres d'optique s'allument avec les blocs (`AWLight`) |
| Peinture unie | `src/server/Vehicles/MeshKits.luau` | Nouveau champ `Paint.Plain` : la teinte du garage remplace la couleur importée, sans carte de couleur |
| Manifeste | `src/shared/Assets/AssetManifest.luau` | `veh.wk_brio.meshmilano95`, statut `ReadyForReview` : 27 maillages et 3 textures relevés dans le gabarit importé (§6) |
| Crédits | `Attributions.luau`, `Localization.luau`, `docs/CREDITS_ACTIFS.md` | Crédit CC BY de Daniel Zhabotinsky, textes FR et EN |
| Catalogue | `src/shared/Economy/VehicleCatalog.luau` | Emplacement 2 : « Brio », catégorie Citadine, prix 12 000 (hypothèse), concession `SVC-DEALER-METRO`, statut `PendingApproval` (achetable en Dev seulement) |
| Métiers | `src/shared/Economy/Jobs.luau` | `ProfessionalModel = "wk_brio"` pour Taxi, Delivery, Convoy et Testing (fin du refus « NoProfessionalVehicle ») |
| Textes | `src/shared/UI/Texts08.luau` | `vehicle.wk_brio.category` et `vehicle.wk_brio.desc` (FR et EN) |
| Départ | `StarterCatalog` | **Inchangé** : la Brio n'est pas un véhicule de départ |

Le gabarit `assets/meshkits/Brio.rbxm` est intégré depuis le 2026-11-05 (§6). Si un maillage n'est pas autorisé par
le manifeste, la fabrique revient à la carrosserie de repli générée par code (existante depuis BASE-01).

### 2.3 Tests

`scripts\verify.ps1 -DownloadRobloxTypes`, exécuté le 2026-11-05 dans `aw-wt-citadine`, est tout au vert :

| Outil | Résultat |
|---|---|
| Rojo | OK |
| Selene | OK |
| Pilote Studio | OK |
| StyLua | OK |
| Lune | **402 réussis sur 402** |
| Carte | OK |
| Place monde ouvert | OK |
| Pytest | 14 réussis |
| luau-lsp strict | 0 erreur |

Nouvelle suite `tests/lune/specs/Veh3d02Brio.luau` (4 tests) :
- définition identique à la référence ;
- essence, automatique, traction ;
- rôles ;
- cohérence du kit mesuré ;
- manifeste sans identifiant et crédit.

Les tests de BASE-01 qui affirmaient « la Comète seule » ont été adaptés :
- `Definitions` ;
- `Lot05Economy` ;
- `Lot08Content` (1 et 3) ;
- `Veh3d01Comete` (6) ;
- `Base01`.

Aucun essai Studio n'a été exécuté par l'assistant. Conformément à la décision du propriétaire, aucun test VM
automatique n'a été lancé.

## 3. Étape du propriétaire : import dans Studio et envoi des maillages

Un jeu publié n'utilise que des maillages envoyés sur Roblox. C'est une publication d'actifs : décision et action du
propriétaire.

1. Dans une place locale vierge, ouvrir **Importer 3D** et choisir le fichier
   `E:\ROBLOX DEV\aw-art-citadine\vehicles\wk_brio\export\wk_brio_milano95_lod0.glb`, avec les réglages par défaut :
   - « Unité d'échelle : Stud », facteur 1 ;
   - « Avance du monde : Avant » ;
   - **« Importer sur Roblox » coché**, créateur : propriétaire de l'expérience.
2. Contrôle rapide dans l'Explorateur :
   - 27 MeshParts nommées `BRIO_…` ;
   - quatre roues `BRIO_Roue_AvG`, `AvD`, `ArG` et `ArD` ;
   - aucune plaque ni aucun insigne.
3. Clic droit sur le modèle importé, puis **« Enregistrer dans un fichier »** au format `.rbxm`. Déposer le fichier dans
   `aw-vm-exchange` et prévenir l'assistant.

Ensuite, l'assistant :
- renomme le gabarit en `Brio` et le place dans `assets/meshkits/Brio.rbxm` ;
- reporte les identifiants réels dans le manifeste ;
- ajoute un contrôle Lune du gabarit : pièces, identifiants, positions à ±0,01 st de l'export ;
- relance `verify.ps1`.

## 4. Liste de vérification en jeu (propriétaire, après l'import)

Les véhicules s'obtiennent par le menu d'administration (F2) ou par la concession (en Dev).

1. **Apparition et allure** :
   - carrosserie 3D, et non la coque de repli ;
   - vitres claires ;
   - aucune plaque ni aucun logo ;
   - le petit motif de l'intérieur (`UCB_Interiors_2`) ne montre aucun logo.
2. **Roues** : posées au sol, elles tournent et braquent (avant) sans traverser les ailes.
3. **Places** :
   - conducteur et passager assis sur les sièges ;
   - pieds au plancher ;
   - tête sous le pavillon (pose standard non vérifiée sur ce modèle).
4. **Caméras** : cockpit au-dessus du volant, capot, bouclier.
5. **Conduite** :
   - boîte automatique (passages seuls) ;
   - traction ;
   - environ 165 km/h en pointe ;
   - ABS au freinage fort.
6. **Feux la nuit** :
   - phares et verres avant allumés ;
   - feux arrière, plus forts au freinage.
7. **Garage** : changer la couleur de carrosserie, toute la caisse change (peinture unie).
8. **Chocs** : marques de dégâts sur la surface avant, arrière et latérale ; réparation par le menu d'administration.
9. **Métiers** : Taxi, Livraison, Convoyage et Essais sans véhicule personnel. Une Brio de service apparaît, il n'y a plus
   de refus.
10. **Concession** (Dev) : la Brio est listée à 12 000, l'achat est possible, elle n'est pas proposée au départ.
11. **Crédits** : Téléphone › Paramètres › « Crédits et licences » affiche la Brio et Daniel Zhabotinsky.

Avant l'import, les points 5, 9 et 10 sont déjà vérifiables sur la carrosserie de repli.

## 5. Non fait, non vérifié

- Statut commercial : `PendingApproval`, donc achetable en Dev seulement. Pour la rendre achetable dans l'expérience de
  test, il faut passer à `Official` : décision du propriétaire.
- Prix de 12 000 : hypothèse de travail.
- LOD1 et LOD2 non exportés : RenderFidelity automatique, comme la Comète.
- Silhouette proche d'un modèle réel (Fiat Punto mk1), sans aucun logo ni nom de marque : accepté au choix du modèle.

## 6. Intégration du gabarit importé (2026-11-05)

Le propriétaire a importé le GLB dans Studio, envoyé les maillages sur Roblox et déposé `aw-vm-exchange/brio.rbxm`
(22:21). Le fichier est copié **tel quel** dans `assets/meshkits/Brio.rbxm` (empreinte SHA-256 identique, `c693c8c7…`).
Rojo nomme le modèle d'après le fichier (`Brio`), comme `Comete720s`.

Relevé du gabarit (Lune, `@lune/roblox`) :
- 27 MeshParts `BRIO_…` dans leurs modèles `_Node`, 11 SurfaceAppearance, aucun script ;
- 27 identifiants de maillage et 3 textures (pneus, dessous de caisse, intérieur), reportés dans le manifeste ;
- positions : toutes les pièces, ramenées au repère du châssis par la pièce de référence, à ±0,01 st de l'export.

**Écart constaté :** les matériaux unis sans texture n'ont pas de couleur à l'import (gris par défaut 163/162/165). La
peinture reçoit la teinte du garage (`Paint.Plain`) et le vitrage le réglage existant. Pour les 6 autres pièces (blocs
et verres des feux, clignotants, recul), le kit porte désormais leurs couleurs (`MeshKitData.Colors`, valeurs sRGB des
matériaux Blender) et la fabrique les repose.

Tests : `lune run tests/lune/run.luau build/AutomotiveWorld.rbxlx`, puis `scriptserify.ps1 -DownloadRobloxTypes`
(2026-11-05) : 403 réussis sur 403, toutes les étapes OK. Nouveaux tests 4 et 5 de `Veh3d02Brio` : gabarit, identifiants
= manifeste, positions, couleurs reposées.

## 7. Validation du propriétaire (2026-11-05)

Le propriétaire a parcouru la liste du §4 dans Studio, sur la place `build/AW-Brio.rbxlx` (branche à 7c05456), et a
répondu « Tout est bon » : les 11 points sont validés, dont l'absence de logo dans le motif de l'intérieur. Essai humain
du propriétaire ; l'assistant n'a exécuté aucun essai Studio.

Reste ouvert (décision du propriétaire, hors validation) :
- statut commercial `PendingApproval` (achetable en Dev seulement ; `Official` pour l'expérience de test) ;
- prix de 12 000 (hypothèse de travail).
