# Automotive World — audit d'intégration V1.0

Audit en **lecture seule**, réalisé le 2026-11-05 sur le dépôt `AbdelmalekYounes/roblox-automotive-world` (sommet UI
`c9b63ab`) et sur le dépôt d'art `AbdelmalekYounes/roblox-automotive-world-art` (sommet `c4ffd34`).

- Aucun code n'a été modifié, aucune branche n'a été fusionnée ou réécrite, aucun actif n'a été publié et `main` n'a
  pas été touché.
- Aucun test n'a été lancé : ni `test-vm.cmd` (arrêt demandé par le propriétaire le 2026-11-05), ni `verify.ps1`.
- Les seules écritures ont eu lieu dans la base d'objets de Git, par `git merge-tree --write-tree` (simulations de
  fusion). Elles ne créent ni branche, ni étiquette, ni modification de l'arbre de travail.
- Ce document n'est pas commité.

Sources :
- `git` et `gh` (commandes en annexe A) ;
- rapports des tâches VM déjà présents dans `aw-vm-exchange/jobs/` (relus, pas relancés) ;
- trois relectures déléguées de la documentation et du code (documents, systèmes de jeu, véhicules et art).

Ce qui n'a pas pu être établi est écrit **non établi**.

---

## 0. Résumé pour décision

1. **Pile linéaire de 17 PR, rien n'est fusionné.** `main` est toujours au socle 0.0.1 (`151cf02`). Chaque PR a pour
   base la précédente, de main ← #1 jusqu'à #16 ← #17. GitHub les déclare toutes fusionnables, sans conflit (« CLEAN »).
   Il n'y a ni intégration continue ni protection de `main`.
2. **ASTER-02 (#15) ne contient aucun code de jeu** : de la documentation, 61 captures, deux outils Lune en lecture
   seule et 12 lignes de test. La Comète (#16) et l'UI (#17) n'en dépendent pas pour le code. Elles en dépendent
   **pour des documents** : les registres `MODELES_TIERS.md` et `CREDITS_ACTIFS.md`, créés dans #15, sont
   indispensables à la licence CC BY de la Comète.
3. **On peut intégrer la Comète et l'UI sans ASTER-02.** La simulation donne **4 conflits, tous documentaires**, et
   **aucun dans le code**. Côté art, la simulation donne **1 conflit** (un script de rendu partagé).
4. **Une régression bloquante n'a pas été signalée par les rapports.** Le banc des 18 modèles était à **18 / 18** au
   lot 0.9.2 (`c352f26`, tâche 20261104-042820). Il est tombé à **10 / 18** à `84cefab` (tâche 20261105-141629) et
   reste à 10 / 18 sur la branche UI (tâche 20261105-132615). Huit modèles ne s'embarquent plus.
   - Le rapport UI classait cet échec « identique sur la base », mais sa comparaison s'arrêtait à la Comète.
   - Cause **non établie**. Elle se situe dans les PR #12 à #16.
5. **La V1.0 est loin d'être complète**, même si le code couvre presque tout le cahier des charges :
   - DataStore jamais exécuté ;
   - aucun son joué en jeu ;
   - gamme non approuvée, donc aucun véhicule de départ ni achat hors développement ;
   - 17 carrosseries provisoires ;
   - aucune mesure de performance sur du matériel réel ;
   - presque aucun essai humain hors UI et Comète ;
   - risque de propriété intellectuelle sur la Comète, en écart avec le cahier des charges §1.2.

**Proposition, détaillée au §6 :**
- fusionner d'abord les lots 0.1 à 0.9.2 (#1 à #11), couverts par le banc à 18 / 18 ;
- diagnostiquer la régression avant #12 et la suite ;
- reconstruire la Comète et l'UI sur Aster phase 1 (#14) dans de **nouvelles branches**, sans ASTER-02 ;
- laisser #15 ouverte comme archive suspendue.

Rien ne sera fait sans ton autorisation.

---

## 1. Dépendances réelles entre les PR #1 à #17

### 1.1 Structure

| PR | Lot | Base | Tête | Commits | Ampleur (fichiers, +/−) | Brouillon |
|---|---|---|---|---|---|---|
| #1 | 0.1 tranche verticale | main | `0542fd0` | 10 | 84, +11 428 / −52 | non |
| #2 | 0.2 physique avancée | #1 | `c0f7a28` | 6 | 54, +8 152 / −585 | oui |
| #3 | 0.3 monde ouvert | #2 | `c00a5c6` | 3 | 46, +6 870 / −31 | oui |
| #4 | 0.4 persistance, propriétés | #3 | `6f1dc7d` | 12 | 66, +9 727 / −124 | oui |
| #5 | 0.5 économie, métiers, marché | #4 | `c0c458b` | 7 | 49, +6 665 / −60 | oui |
| #6 | 0.6 courses, saisons | #5 | `c408164` | 3 | 48, +8 942 / −15 | oui |
| #7 | 0.7 UI, GPS, téléphone, social | #6 | `f48e886` | 2 | 49, +7 751 / −307 | oui |
| #8 | 0.8 DA, audio, photo, arrivée | #7 | `7c4297b` | 9 | 64, +8 741 / −918 | oui |
| #9 | 0.9 intégration, sécurité | #8 | `2c814d4` | 15 | 37, +3 339 / −49 | oui |
| #10 | 0.9.1 QA interactive | #9 | `bf81465` | 32 | 43, +6 190 / −78 | oui |
| #11 | 0.9.2 stabilisation | #10 | `82fd279` | 16 | 21, +1 727 / −123 | oui |
| #12 | AVATAR-01 R15, tenues | #11 | `50ebb1a` | 5 | 28, +3 017 / −1 | oui |
| #13 | Références 3D des 18 modèles | #12 | `d00ccb1` | 11 | 47, +4 362 (documentation + 1 outil) | oui |
| #14 | Aster phase 1 (avatars humains, ApplyQueue, SeatPose) | #13 | `c83b3de` | 20 | 36, +3 745 / −66 | oui |
| #15 | **ASTER-02 (suspendu)** | #14 | `97cc691` | 18 | 73, +1 164 / −4 (documentation, captures) | oui |
| #16 | VEH3D-01 Comète 3D | #15 | `84cefab` | 14 | 40, +3 671 / −53 | oui |
| #17 | UI PREMIUM V1.2 | #16 | `c9b63ab` | 19 | 108, +14 352 / −1 606 | **non (prête)** |

Toutes les branches sont strictement linéaires : chaque tête descend de la précédente. Les branches locales sont à
jour avec `origin`.

### 1.2 Dépendances de code (pas seulement d'empilement)

- **#2 à #11** : chaque lot s'appuie sur les systèmes des précédents (physique → monde → persistance → économie →
  courses → UI → contenu → QA). C'est une dépendance réelle, et l'ordre est imposé.
- **#12 (AVATAR-01)** : `AvatarService`, `AvatarPolicy`, `OutfitCatalog/Rules`, au-dessus de 0.9.2. #14 en dépend.
- **#13** : documentation et un outil (`cabin-geometry.luau`). Aucune dépendance de code, mais #14 et #15 s'appuient
  sur ses documents.
- **#14 (Aster phase 1)** : c'est du **code de jeu actif**, pas du travail ASTER-02. Elle apporte :
  - deux corps humains 994/995 imposés ;
  - le remplacement des têtes « bloc » ;
  - `ApplyQueue` ;
  - `BodyChoice` ;
  - `SeatPose` et `SeatPoseController` ;
  - les réglages du téléphone.

  **La Comète dépend de #14** (`SeatPose`, attribut `AWSeatPose`, `AvatarPolicy`), et l'UI aussi (fenêtre
  `BodyChoice` restylée).
- **#15 (ASTER-02)** : aucune dépendance de code entrante. La recherche dans `src`, `tests`, `scripts` et les
  projets Rojo de #16 et #17 ne trouve que :
  - des commentaires citant `MODELES_TIERS.md` et `CREDITS_ACTIFS.md` (`MeshKits.luau`, `MeshKitData.luau`,
    `AssetManifest.luau`) ;
  - un commentaire citant `ASTER_02_HAUTE_FIDELITE.md` (`tests/studio/CometeServer.server.luau:375`).
- **#16 (Comète)** : code de jeu (`MeshKits`, `MeshKitData`, `VehicleService`, `VehicleFactory`, `DamageService`,
  `Attributions`, kit `.rbxm`). Elle dépend de #14 et, pour la documentation de licence, de #15.
- **#17 (UI)** : dépend de #16 par empilement. Le garage affiche la Comète en 3D par le `ViewportFrame`, et le
  téléphone contient l'écran des crédits CC BY. Sans #16, l'UI fonctionnerait avec des carrosseries provisoires. La
  séparation n'est pas recommandée : le propriétaire a validé l'UI avec la Comète.

---

## 2. Travaux ASTER-02 suspendus, à ne pas réactiver

ASTER-02 a été suspendu par le propriétaire le 2026-11-04. Seule trace explicite : `ASTER_02_DECISIONS.md` §4 quater.

| Élément | Où | À laisser en sommeil |
|---|---|---|
| Blockout « Trait », passes HF1 à HF4 (LOD0 36 696 triangles), dessin « reproduction » (d'après une Golf VIII) | #15 : `ASTER_02_BLOCKOUT.md`, `ASTER_02_HAUTE_FIDELITE.md` (HF5 « à faire, sur accord »), `ASTER_02_REPRODUCTION.md` (« à valider »), 61 captures `docs/vehicle-3d/captures/aster02*` | oui |
| Décision §4 bis (reproduction de la référence) | `ASTER_02_DECISIONS.md` | oui (même risque de propriété intellectuelle que la Comète) |
| Outil `tests/lune/tools/aster-provisional.luau` ; 12 lignes ajoutées à `AsterPhase1Closure.luau` (jante réelle, CameraCockpit 2,32) | #15 | oui |
| Art : `aster02_blockout.py`, `aster02_hf3.py`, `aster02_hf4.py`, `aster02_checks.py`, scènes `wk_aster*.blend`, 13 commits de la branche art `aster-02-blockout` | dépôt d'art | oui |
| Étapes encore rédigées comme actives | `ASTER_02_HAUTE_FIDELITE.md:24`, `ASTER_02_REPRODUCTION.md:1,7-8`, `ASTER_02_LANCEMENT.md:3`, `ASTER_02_BLOCKOUT.md:1`, `ASTER_PHASE1_CLOTURE.md:79-82`, `docs/vehicle-3d/README.md:17,21-22`, `README.md:33-34` | à marquer « SUSPENDU » (voir §4) |

**À ne pas confondre avec ASTER-02.** Les éléments suivants sont nés pendant le chantier Aster, mais servent la
Comète et toute future intégration 3D. Ils doivent survivre.

| Élément utile hors ASTER-02 | Où | Pourquoi |
|---|---|---|
| `docs/vehicle-3d/MODELES_TIERS.md` (inspection, préparation, export, import de la 720s) | créé dans #15 | traçabilité de l'exception et de la licence |
| `docs/CREDITS_ACTIFS.md` | créé dans #15 | crédit CC BY obligatoire |
| `ASTER_02_DECISIONS.md` §4 ter (jeu jamais monétisé, modèles ddiaz refusés, exception 720s) et §4 quater (suspension) | #15 | décisions du propriétaire |
| Règle d'export glTF (demi-tour de 180°, FBX écarté) dans `PIPELINE_BLENDER_ROBLOX.md` | #15 + art `a3d55db`, `a474560` | étalonnage valable pour tout modèle |
| `tests/lune/tools/vehicle-geometry.luau` | #15 | a servi à préparer la Comète (facultatif) |
| Art : `inspect_import.py`, `comete_720s_*.py`, `export_roblox_glb.py`, `clean_720s_textures.py`, témoins v2 et v3, et `aster02_render_hf4.py` (utilisé pour les rendus de la Comète) | dépôt d'art | outillage de la Comète |

---

## 3. Intégrer la Comète et l'UI sans ASTER-02

### 3.1 Simulation (dépôt du jeu)

Commande :

```
git merge-tree --write-tree --name-only --merge-base=origin/feat/aster-02-blockout origin/feat/aster-phase1 origin/feat/ui-premium-v1.2
```

Elle calcule « #14 + les changements de #16 et #17 », sans ceux de #15. Résultat : **4 conflits, tous dans des
documents** :

| Fichier | Conflit | Résolution proposée |
|---|---|---|
| `docs/CREDITS_ACTIFS.md` | modifié dans #16, absent sans #15 | reprendre la version finale de #17 telle quelle |
| `docs/vehicle-3d/MODELES_TIERS.md` | idem | reprendre la version finale ; mettre à jour les lignes 30, 242 et 245, périmées (voir §4) |
| `docs/ROADMAP.md` | contenu | garder les sections Comète et UI, réduire ASTER-02 à « suspendu, travail sur la PR #15 » |
| `docs/vehicle-3d/README.md` | contenu | index Comète à jour, ASTER-02 marqué suspendu |

Aucun fichier de `src/`, `tests/` ni des projets Rojo n'entre en conflit.

À reprendre explicitement de #15, puisque ce ne sont pas des conflits :
- la section « étalonnage » de `PIPELINE_BLENDER_ROBLOX.md` ;
- les §4 ter et §4 quater de `ASTER_02_DECISIONS.md` (ou un court `DECISIONS_COMETE.md`) ;
- facultatif : `vehicle-geometry.luau`.

### 3.2 Simulation (dépôt d'art)

Les 10 commits de la Comète (`94b5d60` à `c4ffd34`) sont posés sur la branche art `aster-02-blockout`, après les
commits ASTER-02. Appliqués sur `main` de l'art (`9dfc628`), ils donnent **1 conflit** :
`tools/blender/aster02_render_hf4.py`, absent de main et modifié par la Comète.

Résolution : conserver ce script de rendu, idéalement renommé (par exemple `render_review.py`), sans les générateurs
de l'Aster.

### 3.3 Options

| Option | Principe | Pour | Contre |
|---|---|---|---|
| **A. Tout fusionner, #15 comprise** | fusionner la pile telle quelle | zéro conflit, aucune réécriture | ASTER-02 entre dans `main` (documents et captures suspendus, outils morts) ; contraire à ta demande d'indépendance |
| **B. Nouvelles branches sans #15 (recommandée)** | à partir de #14 (`c83b3de`) : rejouer #16 puis #17 dans `feat/veh3d-01-comete-v2` et `feat/ui-premium-v1.2-v2` ; résoudre les 4 conflits ; reprendre les registres | `main` sans ASTER-02 ; #15 reste une archive propre (après fusion de #14, sa différence avec `main` ne contient plus que ASTER-02) ; aucun historique effacé (branches et PR actuelles conservées) | nouveaux commits (nouvelles empreintes), donc PR #16 et #17 à remplacer par deux nouvelles PR ; validation des contenus à reconfirmer (voir le contrôle d'identité au §6) |
| C. Réécrire #16 et #17 en place | rebase puis poussée forcée des branches existantes | garde les numéros de PR | poussée forcée sur des branches revues ; historique de revue perdu ; non recommandé |

**Recommandation : option B.** Le contrôle clé consiste à comparer l'arbre reconstruit avec `c9b63ab`, avec
`git diff c9b63ab <nouvelle branche> -- src tests scripts *.project.json`. La différence doit se limiter aux éléments
propres à #15 : l'outil `aster-provisional.luau` et les 12 lignes de `AsterPhase1Closure.luau`. Les autres
différences doivent être documentaires. C'est ce qui permet de reporter tes validations du 2026-11-05 sans
rejouer toute la liste.

---

## 4. Documents obsolètes ou contradictoires

Constat d'ensemble : les documents de pilotage n'ont pas été touchés par le lot UI.
- `ROADMAP.md` : dernière modification à `fc82a86`.
- `README.md` : figé au 2026-11-04.
- `QA_BACKLOG.md` : dernière modification à `1b02177`.

### 4.1 Trompeurs pour une décision d'intégration

| # | Document | Problème | Correction proposée |
|---|---|---|---|
| D1 | `docs/ROADMAP.md` (fin) | aucune section UI V1.2 (#17) ; numéros de PR #13 à #16 absents ; pas d'état de la pile ; pas de prochaine étape | section UI V1.2 (prête, validée le 2026-11-05, grande carte en l'état) ; tableau de la pile #1 à #17 |
| D2 | `docs/ROADMAP.md:213-214` | « écran de crédits à faire » : il est fait (`VEH3D_01_CLOTURE.md:127`, `CREDITS_ACTIFS.md:10`) | « fait ; titre et lien masqués, décision reportée » |
| D3 | `README.md:1, 35` | statut « lot 0.9.2, PR #11 » ; ni ASTER-02, ni la Comète, ni l'UI V1.2 ; tableau des documents arrêté à `lot-avatar-01` | statut au sommet de la pile ; compléter le tableau |
| D4 | `README.md:33-34` | lien « lancement d'ASTER-02 » sans mention de la suspension | ajouter « suspendu le 2026-11-04 » |
| D5 | `README.md:240-241` | « Aucun code, modèle […] n'est réutilisé » : faux depuis la Comète | mentionner l'exception CC BY et renvoyer aux registres |
| D6 | `README.md:183-191`, `docs/VM_TESTS.md`, `QA_BACKLOG.md:15` | la VM est présentée comme méthode courante ; l'arrêt du 2026-11-05 n'apparaît que dans les documents UI | encadré « depuis le 2026-11-05 : essais par le propriétaire ; `verify.ps1` reste » |
| D7 | `CLAUDE.md` (« Tests et rapports ») | impose toujours `test-vm.cmd` : **contradiction avec ta consigne** | **à arbitrer par toi seul** (je ne modifie pas ce fichier) |
| D8 | `docs/ui/UI_V1_2_FINALISATION_RAPPORT.md:3, 62-63` | « PR #17 (brouillon) » ; contrôles « après 7601693 » ; les commits `f1a52d5` (grande carte, téléphone, rotation du garage) et `9195740` (flèche) ne sont pas décrits, ni ta validation | section « retours du 2026-11-05 » ; statut de la PR |
| D9 | `docs/ui/UI_V1_2_A_VERIFIER.md:73`, `README.md:82`, commentaire `GaragePanel.luau:19` | « Select ouvre le garage » : faux. `InputMap.luau` associe Select au **téléphone** ; le garage n'a pas de touche manette. **Erreur de ma liste de vérification.** | « Select ouvre le téléphone ; garage par l'application Véhicules » |
| D10 | `UI_V1_2_A_VERIFIER.md` §1, §3, §7 | cases décochées et §7 « à valider » alors que le §8 consigne ta validation (garage, confirmations, courses) | cocher ou annoter selon le §8 |
| D11 | `docs/ui/UI_PREMIUM_V1_2_LANCEMENT.md:1-5, 60-64` | « chantier NON commencé » ; préalable « PR #16 fusionnée » jamais rempli (l'exception n'est consignée que dans `UI_01_RAPPORT.md`) | titre « historique — chantier terminé » ; note sur l'exception |
| D12 | `docs/QA_BACKLOG.md` | aucune entrée UI V1.2 (manette, écrans réels, GPS non relancé, bras à 8°, clic de silhouette, banc 10 / 18) ; en-tête daté du 2026-11-04 | §3 octies ; en-tête |
| D13 | Documents ASTER-02 (voir §2) | étapes rédigées comme actives | bandeau identique « SUSPENDU le 2026-11-04 — ne pas réactiver sans décision » |
| D14 | `docs/vehicle-3d/README.md:3-4` | « aucun import ni publication d'actif » : faux depuis la Comète ; clôture et revue absentes de l'index | en-tête et index |
| D15 | `docs/vehicle-3d/VEH3D_01_CLOTURE.md:155, 169, 130, 144` | « aucune validation humaine » (contredit par sa ligne 21 et son §6) ; « UI V1.2 pas commencée » ; crédits « sans capture » | dater la revue ; retirer ou dater les lignes |
| D16 | `docs/vehicle-3d/MODELES_TIERS.md:12, 30, 242, 245` | « pas essayé en jeu » ; « envoi non vérifié » (contredit par QA-K02) ; auteur « s0h1o9b » contre « _Sheep19 » ; règle « titre et lien obligatoires » contre l'écran actuel | §6 « intégration » ; aligner la règle sur la décision retenue |
| D17 | `src/shared/Assets/Attributions.luau:11` | cite `docs/vehicle-3d/VEH3D_01_FINALISATION.md`, **inexistant** (seule référence cassée du dépôt) | renvoyer à `VEH3D_01_CLOTURE.md` §3.F et `VEH3D_01_REVUE.md` |
| D18 | `docs/ui/UI_V1_2_FINALISATION_RAPPORT.md:107` | banc lot08 classé « identique sur la base », alors que c'est une **régression** depuis la 0.9.2 (§0, point 4) | reclasser et ouvrir une entrée QA |

### 4.2 Incohérences mineures (à corriger dans le même passage)

- `ROADMAP.md` :
  - lignes 137-138 et 151, « V1.0 non commencée » : préciser que « V1.2 » désigne la version des maquettes, pas
    celle du jeu ;
  - lignes 161-162, QA-A15 et A16 « à arbitrer » : corrigées sur la Comète ;
  - lignes 188-189, « étalonnage à relever » : relevé.
- `ASTER_02_DECISIONS.md:171-172` et `ASTER_PHASE1.md:94` : même étalonnage périmé.
- `QA_BACKLOG.md` :
  - ligne 19 : phrase tronquée ;
  - ligne 25 : priorité de QA-A01 incohérente (P1 ou P2) ;
  - lignes 292-297 : section « dernière exécution » arrêtée aux lots 0.3 et 0.4 ;
  - QA-K04 et K06 non mis à jour.
- `VM_TESTS.md` : 27 sessions de `build-driver.luau` absentes du tableau.
- `VEH3D_01_INTEGRATION_COMETE.md:107, 130` : dépassé par le §8.
- `PLAN_PRODUCTION_18_VEHICULES.md:11-12, 24` : Aster pilote et Comète en dernier ; c'est l'inverse dans les faits.
- `DIRECTION_ARTISTIQUE_VEHICULES.md:224-225` : la fiche Comète demande de « transformer » et d'« inventer » ; la
  Comète intégrée reproduit la 720s.
- `docs/lot-0.8/ASSETS_ET_LICENCES.md:8-13` : « toutes les ressources sont originales », « RobloxAssetId nil
  partout ». Faux aujourd'hui : il y a 12 icônes, le kit de la Comète et le modèle tiers.
- `UI_V1_2_A_VERIFIER.md:7` : la commande du monde ouvert omet `lune run tools/world/build-world.luau`.
- `docs/ARCHITECTURE.md` : « v0.0.1 », renvois arrêtés au lot 0.7.
- `aw-art/vehicles/wk_comete/README.md` : « aucun import Studio » est périmé.
- `README` du dépôt d'art : « créations originales uniquement » est contredit par la 720s.

### 4.3 Documents relus et cohérents

- Les rapports de lots, avec des chiffres recoupés avec la ROADMAP :
  - lot 0.1 : Lune 100, pytest 8 ;
  - lot 0.3 : 187 ;
  - lot 0.4 : 235 ;
  - lot 0.5 : 263 ;
  - lot 0.9.2 : 1 197 / 16 / 1 ;
  - AVATAR-01.
- `VEH3D_01_REVUE.md`, `ASTER_02_DECISIONS.md` §4 quater, `UI_03_APERCU_3D_RAPPORT.md`,
  `handoff-v1.2/README.md`.

---

## 5. Inventaire des fonctionnalités

Légende :
- **Validée** : essai du propriétaire consigné et daté.
- **Auto** : test automatisé (Lune hors Studio, ou session VM). Ce n'est jamais un essai humain.
- **Non testée** : implémentée, sans aucun test.
- **Incomplète** : partielle, provisoire ou refusée par la validation.
- **Absente** : prévue au cahier des charges, introuvable dans le code.

### 5.1 Validées par le propriétaire

| Fonctionnalité | Date | Source |
|---|---|---|
| Commandes du lot 0.1 (déclaration globale, sans étapes consignées) | 2026-11-02 | `QA_BACKLOG.md` §2 |
| Règle de relance d'un moteur calé, boîte sans pédale (QA-A12) | 2026-11-04 | rapport 0.9.2 §3 |
| Revue de la Comète (« tout fonctionne correctement », 15 points non notés un par un) ; vitrage réglage C | 2026-11-05 | `VEH3D_01_REVUE.md` |
| UI V1.2 : garage (rotation à la souris, case de rotation automatique), confirmations de l'économie et des métiers, courses, mini-carte fluide, routes rognées, flèche du joueur, mise en page du téléphone ; grande carte gardée en l'état | 2026-11-05 | `UI_V1_2_A_VERIFIER.md` §8 |
| Décisions de contenu : avatars humains 994/995, marques fictives, jeu jamais monétisé, exception 720s | 2026-11-04 | `ASTER_02_DECISIONS.md`, `DIRECTION_ARTISTIQUE_VEHICULES.md` |

### 5.2 Testées automatiquement (sans essai humain)

- **Physique** :
  - moteurs (essence, diesel, électrique), 6 boîtes, transmissions ; ABS, antipatinage, ESP ; valeurs non finies
    (QA-A08) ;
  - banc 18 / 18 au lot 0.9.2, **10 / 18 depuis** (§0) ;
  - adhérence sèche et mouillée (freinage mouillé non testé) ;
  - validation serveur des mouvements.
- **Caméras** : proche, lointaine, cockpit, capot, pare-chocs (QA-K05).
- **Monde** :
  - carte 7 zones et placement des équipements ;
  - trafic, piétons, météo et jour/nuit : partiels ;
  - streaming : partiel.
- **Propriétés** :
  - propriété gratuite, plafond 5, configurations (5), invitations et prêt (même serveur) ;
  - revente : Lune seulement.
- **Persistance** : schéma v5 et migrations, verrou de session, écritures incertaines, mode hors ligne. **Lune et
  mémoire seulement.**
- **Économie** : portefeuille, réputation, 8 métiers (8/8 au lot 0.9.2, 7/8 le 2026-11-05 : Precision), mission
  garantie (Lune), occasion entre joueurs (même serveur), revente de pièces.
- **Courses** :
  - 6 disciplines sur la place de développement, avec 4 échecs ouverts au pilote d'essai ;
  - drift (310 points), réservation du véhicule, chronométrage et rangs (Lune).
- **Interface** : HUD (`ui_hud` 12/12), téléphone (`ui_phone` 44/44), résolutions par écran virtuel
  (`ui_resolutions` 26/26), navigation et délais (`ui_navigation` 21/21), menus bloqués en mouvement, groupes et
  partage de position.
- **Comète** :
  - pose « Sportive » sur 8 morphologies (16/16), vitrage, réplication à 2 joueurs ;
  - QA-K01, K02, K03, K05, K07 ; K04 et K06 partiels ; K08 non concluant.
- **Avatars** : R15 imposé, corps 994/995, tête « bloc » remplacée, ApplyQueue (Lune), choix de silhouette (vrais
  clics dans la VM).

### 5.3 Implémentées, non testées

- Commandes du lot 0.2 au ressenti (QA-H07, H08, H10).
- Désenlisement.
- Réparation et lavage.
- Équilibrage (tous les prix sont provisoires).
- Météo normalisée en course.
- Modes réaliste et protégé en jeu (QA-R17).
- Anti-triche en course (QA-R09).
- Discussion texte.
- Capture du mode photo.
- 8 exercices de formation et protection d'apparition.
- Accessibilité (taille, contraste, animations).
- Relecture FR/EN (QA-U12).
- **Navigation à la manette** (la VM n'envoie aucune manette).
- **DataStore réel** (jamais instancié).
- Sauvegarde périodique et à la fermeture du serveur (QA-D04).
- Préférences sauvegardées.
- GPS sur le code V1.2 (tâche coupée).
- Écran de crédits : affichage jamais vérifié par toi.
- Chargement de la Comète dans une expérience publiée.
- Sorties corrigées sur les 17 autres modèles.

### 5.4 Incomplètes

- **Audio** : 30 sons synthétisés, **aucun envoyé**, rien n'est joué ; radio indisponible ; pas de signature
  sonore par modèle.
- **Gamme** : 18 modèles en attente d'approbation ; `StarterCatalog.Candidates = {}`. Aucun véhicule de départ ni
  achat hors développement.
- **Dégâts visuels** : sans déformation (rayures sur la Comète). Comète : feux non lumineux, peinture du garage
  inactive, LOD1 et LOD2 non intégrés, pas de repli si un maillage est retiré par Roblox.
- **Carrosseries** : 17 sur 18 provisoires (pièces de base) ; habitacles trop bas ou serrés (QA-A13, A14, A17, A21).
- **Monde** :
  - points d'apparition (Métropole seule) ;
  - modules privés de garage (développement seulement).
- **Courses et social** :
  - matchmaking (repli local, code entre serveurs jamais exécuté) ;
  - reconnexion en course (même serveur) ;
  - notifications sans son.
- **Avatars et UI** :
  - téléphone en main (bras à 8° mesurés contre 25° attendus, non classé) ;
  - clic de silhouette refusé pendant le chargement ;
  - tenues (5 catégories sans actif) ;
  - `DefaultBody` provisoire ;
  - écarts de maquette (vue Intérieur, 0–100, pièce posée dès la demande).
- **Direction artistique** : jamais validée en jeu (QA-V01).

### 5.5 Absentes

- Dépannage et remorquage payant (§3.5, SCN-17).
- Restauration ciblée de profil (outil).
- Fractionnement des profils volumineux.
- Signalements et modération propres au jeu.
- Gel ciblé des actifs suspects.
- Invitations entre serveurs.
- Galerie photo propre au jeu (choix : galerie Roblox).
- Volant périphérique (conditionnel au cahier des charges).
- Robux : absent, **conforme** à la décision « jamais monétisé ».

---

## 6. Ordre de consolidation proposé

### 6.1 Préalables (décisions et actions du propriétaire)

1. **Protéger `main`** dans GitHub (interdire la poussée directe). C'est un réglage de dépôt que je ne modifie pas.
2. **Décider de la méthode de fusion**. Recommandation : « merge commit » à chaque étape, **jamais « squash » ni
   « rebase »** dans une pile. Ces deux méthodes réécrivent les commits et feraient apparaître de faux conflits dans
   toutes les PR suivantes.
3. **Étiquettes de sauvegarde** des 17 têtes actuelles (par exemple `sauvegarde/2026-11-05/pr-NN`), poussées sur
   GitHub. Cela demande ton accord.
4. **Ménage local** : à décider par toi, rien n'a été touché.
   - `E:/ROBLOX DEV/aw-wt-vehicle3d` contient une suppression non commitée de
     `docs/vehicle-3d/ASTER_DESIGN_BRIEF.md`.
   - Le dossier `aw-art/` (vide hormis un `calibration/README.md` de 0 octet) traîne, non suivi, à la racine du dépôt
     principal. Risque d'ajout par erreur.

### 6.2 Étapes

| Étape | Contenu | Conflits attendus | Contrôles | Risque |
|---|---|---|---|---|
| **1** | Fusionner **#1 → #11** (lots 0.1 à 0.9.2) dans `main` | aucun (linéaire, « CLEAN ») | `verify.ps1` sur `main` ; banc lot08 à 18 / 18 au dernier commit de code de #11 (`c352f26`, les 2 commits suivants sont documentaires) | faible ; échecs connus ouverts (lot06, Precision, QA-A01, A05) à accepter comme dette |
| **2** | **Diagnostiquer la régression du banc** (10 / 18) entre `c352f26` et `84cefab` | — | essai d'embarquement des 8 modèles (Zénith, Dune, Éclat, Comète, Vigie, Sentier, Atlas, Mistral), **à la main par toi**, ou une session VM ciblée **si tu l'autorises** ; bissection sur les commits suspects (ci-dessous) | **élevé** : régression du jeu possible, ou artefact du banc ; non établi |
| **3** | Fusionner **#12 (AVATAR-01), #13, #14** après correction ou classement de l'étape 2 | aucun | `verify.ps1` ; embarquement et sortie sur un modèle provisoire et sur la Comète ; choix de silhouette | moyen (code des avatars dans l'intervalle de la régression) |
| **4** | Créer `feat/veh3d-01-comete-v2` à partir de #14 et y rejouer les 14 commits de #16 ; reprendre les registres ; corriger `Attributions.luau:11` | 4 conflits documentaires (§3.1) | `verify.ps1` ; contrôle d'identité `git diff 84cefab <v2> -- src tests` (seules différences attendues : propres à #15) | faible pour le code ; validation à reconfirmer par l'identité des arbres |
| **5** | Créer `feat/ui-premium-v1.2-v2` à partir de la v2 de la Comète et y rejouer les 19 commits de #17 | aucun attendu | `verify.ps1` ; `git diff c9b63ab <v2> -- src tests scripts` (identique hors éléments de #15) ; **ta courte liste de revérification** (garage, téléphone, carte, crédits) | faible |
| **6** | Passe documentaire (§4) dans la v2 de l'UI ou une branche dédiée | — | relecture ; liens vérifiés | faible |
| **7** | Fusionner les v2 (Comète puis UI) dans `main` ; fermer #16 et #17 avec un renvoi vers les nouvelles PR | — | `verify.ps1` sur `main` ; build des deux places | faible |
| **8** | **#15 reste ouverte**, en brouillon « suspendu » ; après l'étape 3, la recibler sur `main` (sa différence ne contient alors que ASTER-02) | — | — | nul |
| **9** | Dépôt d'art : branche `veh3d-01-comete-v2` depuis l'art `main` avec les 10 commits de la Comète ; script de rendu conservé ; `aster-02-blockout` intouchée | 1 conflit (§3.2) | rendus refaits à l'identique (empreintes des JSON) | faible ; fichiers LFS à vérifier |

**Intervalle de la régression** (code des véhicules ou des avatars modifié entre `c352f26` et `84cefab`) :
- AVATAR-01 : `e616ef5` (R15 imposé).
- Aster phase 1 :
  - `8a4144a`, `715aa9c` (pose) ;
  - `fe89f7e` (corps humains imposés) ;
  - `284ce4b`, `316e462`, `df5c0b9`, `83cb6de`, `c9c19be` (ApplyQueue) ;
  - `9f1c4b7`.
- Comète :
  - `73b23eb`, `f98da36`, `a61a11c`, `624baab`, `3695535` ;
  - `a0debec` (« occupant sans collision avec les véhicules jusqu'à son placement ») ;
  - `1b02177`, `fc82a86`.

Le diagnostic des tâches dit « invite affichée, siège non occupé, conducteur 0 », sur des modèles aux habitacles
bas (Éclat, Mistral, Zénith) comme hauts (Dune, Vigie, Sentier, Atlas). **Aucune cause n'est avancée ici** : seule une
bissection la donnera.

**Variante plus courte de l'étape 1.** Recibler #11 sur `main` et la fusionner fusionne #1 à #10 en même temps. Que
GitHub marque alors automatiquement #1 à #10 comme fusionnées est probable, mais **non vérifié**. La fusion une par
une garde une trace de revue par lot, comme le demande CLAUDE.md.

### 6.3 Risques transverses

- **Aucune intégration continue.** `verify.ps1` ne tourne qu'en local : chaque étape demande de le lancer à la main.
- **Gouvernance.** CLAUDE.md impose de clore un lot (PR fusionnée) avant le suivant. Aucune des 17 PR n'est
  fusionnée, et plusieurs lots ont démarré par exception. La consolidation régularise la situation, mais ta revue
  doit porter sur la pile entière (environ 110 000 lignes ajoutées).
- **Binaires dans le dépôt du jeu** : captures (environ 5,3 Mo dans `docs/vehicle-3d/captures`), `Comete720s.rbxm`,
  captures UI. Rien de bloquant, à surveiller.
- **Validations humaines liées à des empreintes** : l'option B change les empreintes. C'est le contrôle d'identité
  des arbres qui justifie de reporter tes validations.

---

## 7. Blocages à une V1.0 complète

### 7.1 Gameplay

1. **Gamme non approuvée** (D1 et D2 du lot 0.9). Aucun véhicule de départ, aucun achat hors développement.
   → Ta décision.
2. **Régression du banc 10 / 18** (§6, étape 2).
3. **Remorquage absent** (§3.5, SCN-17).
4. **Courses jamais jouées en conditions réelles** :
   - 4 disciplines en échec au pilote d'essai ;
   - pas de course en monde ouvert ;
   - modes réaliste et protégé non essayés ;
   - matchmaking local seulement.
5. **Essais humains quasi absents** hors UI et Comète : ressenti de conduite, manette, QA-H07 à H20, U03, U12.
6. Arbitrages ouverts :
   - modules de garage ;
   - dégâts sans déformation ;
   - habitacles R15 (QA-A13, A14) ;
   - téléphone en main (8°) ;
   - clic de silhouette.

### 7.2 Persistance

1. **DataStore jamais exécuté.** `EnvironmentConfig.TestGameIds` et `ProdGameIds` sont vides : tout tourne « Dev /
   mémoire » et la progression est perdue à l'arrêt du serveur. Il faut une expérience de test isolée, puis
   QA-D01 à D10, E01, E02, R03, U09.
2. **Code entre serveurs jamais exécuté** : MemoryStore, téléportation, tableaux durables, boîtes de réception.
3. **`Market_Index`** : une seule clé partagée, limitée à 500 annonces. Point de contention.
4. **Outils manquants** : restauration ciblée, fractionnement, répétition d'une migration réelle.
5. Double libération possible d'un profil (`PlayerRemoving` puis `BindToClose`) : **non établi**, à vérifier.

### 7.3 Performances

1. **Aucune mesure sur matériel réel**, ni à 24 joueurs, ni sur mobile ; ni mémoire, ni bande passante, ni session
   longue. La VM est plafonnée à 60 Hz (QA-P01 à P09, V11, V13, K08). La carte compte environ 47 650 pièces, avec des
   pics à 45 ms en P99 sous la pluie dans la VM.
2. **Budget 3D de la gamme inconnu** : environ 7 000 triangles par Comète, mais l'Aster HF était à 36 696 au LOD0.
   Le budget des 18 modèles n'est pas extrapolé.

### 7.4 Sécurité

1. **Place publiée non déclarée.** Un `gameId` inconnu donne « Dev / mémoire », donc l'attribution des **crédits
   synthétiques** (`DevSeed`, `ProfileService.luau:185-191`) et la possibilité d'acheter les modèles en attente
   (vérifié dans `Environment.luau:59-65`). C'est sans effet durable (mémoire), mais **bloquant avant toute
   publication** : il faut déclarer les identifiants ou refuser le mode « Dev » hors Studio.
2. Aucune tentative de triche réelle ; arrangements et raccourcis en course non testés (QA-R08, R09).
3. Pas d'outils de signalement, de gel d'actifs ni de confirmation des arrivées « non confirmées » (AUD-MOD-01,
   AUD-ECO-03).
4. Anomalies de propriété réseau et de collision ouvertes (QA-A01, A03, A11) : risque de dégâts mal attribués.
5. Point positif : chaque fonction distante a une limite de débit ; aucun `InvokeClient` ni `loadstring` ; points
   d'accès de test réservés à Studio.

### 7.5 Véhicules

1. **17 carrosseries provisoires** : le cahier des charges (CH09) demande des extérieurs et intérieurs soignés pour
   les 18 modèles. QA-A13, A14, A17 et A21 sont ouvertes.
2. **Sorties corrigées** vérifiées sur la Comète seule.
3. **Comète** :
   - feux non lumineux ;
   - peinture inactive (carte neutre prête, art `c4ffd34`, envoi reporté) ;
   - LOD1 et LOD2 non intégrés ;
   - choc latéral non testé ;
   - pas de repli si Roblox retire un maillage ;
   - banc lot08 jamais mesuré avec le kit 3D.
4. Finition du garage (brillant, mat) appliquée à aucun véhicule.
5. Aster 3D : suspendu (hors V1.0 sauf décision contraire de ta part).

### 7.6 Contenu artistique et conformité

1. **Audio absent du jeu** : écoute et envoi des 30 sons à faire par toi, puis QA-V04 à V06 et V12 ; sons par modèle
   non produits.
2. **Comète, propriété intellectuelle.**
   - Le modèle CC BY ne couvre que le travail du modélisateur, pas le dessin de la McLaren 720S.
   - **Écart non arbitré avec le cahier des charges**, §1.2 « Principes non négociables » (« véhicules fictifs
     originaux »). L'exception porte sur la règle « aucun emprunt » de CLAUDE.md, pas sur le cahier des charges.
   - Il faut soit amender le cahier des charges, soit remplacer la carrosserie avant publication (AUD-PUB-01).
3. **Crédits CC BY** :
   - lien de l'œuvre masqué (`ShowUrl = false`) ;
   - affichage jamais vérifié ;
   - auteur « _Sheep19 » ou « s0h1o9b » : renommage supposé, non prouvé.
4. **Créateur des actifs (D6).** Les icônes viennent du compte youyou31110 ; le créateur des maillages de la Comète
   et celui de l'expérience ne sont pas établis. Si les créateurs diffèrent, des actifs peuvent ne pas se charger
   dans l'expérience publiée (QA-K02 non testé).
5. **Direction artistique** jamais validée en jeu (QA-V01). Monde et éclairage provisoires. Antériorité des marques
   fictives (Mivale, Orvane, Rocalt, Celvar) non recherchée. Textures d'intérieur et moyeu du volant de la Comète :
   absence de logo vérifiée par l'assistant seulement.

---

## 8. Décisions demandées au propriétaire

1. Option d'intégration : **B (recommandée)**, A ou C (§3.3).
2. Méthode de fusion (« merge commit ») et protection de `main`.
3. Feu vert pour l'étape 1 (#1 à #11).
4. Méthode de diagnostic de la régression du banc : essai manuel par toi, ou une session VM ciblée par exception à
   l'arrêt des tests automatiques.
5. Arbitrage CLAUDE.md contre l'arrêt des tests VM (D7).
6. Comète : amender le cahier des charges §1.2 ou prévoir une carrosserie originale avant publication.
7. Crédits : afficher ou non le titre et le lien de l'œuvre.
8. Gamme et véhicules de départ (D1 et D2), `DefaultBody`.
9. Périmètre de la V1.0 : ce qui peut être reporté après la V1.0 (remorquage, outils de modération, 17 carrosseries
   3D, audio par modèle…).

---

## 9. Exécution de l'option B (2026-11-05)

Option **B** choisie par le propriétaire le 2026-11-05. Exécuté le même jour, **sans fusion ni modification de `main`**,
sans toucher aux branches ni aux PR existantes :

| Étape (§6.2) | Résultat |
|---|---|
| 4 — `feat/veh3d-01-comete-v2` | créée depuis `origin/feat/aster-phase1` (`c83b3de`) ; 14 commits de #16 rejoués par `git cherry-pick -x` ; 4 conflits documentaires résolus en reprenant le fichier du commit d'origine ; registres utiles de #15 repris (`PIPELINE_BLENDER_ROBLOX.md`, `ASTER_02_DECISIONS.md`, `vehicle-geometry.luau`), commit `2649d91` |
| Contrôle d'identité (Comète) | `git diff origin/feat/veh3d-01-comete feat/veh3d-01-comete-v2 -- src scripts *.project.json assets tools tests` : seules différences `aster-provisional.luau` (absent) et 12 lignes de `AsterPhase1Closure.luau` (absentes), toutes deux propres à #15 ; `src` identique |
| 5 — `feat/ui-premium-v1.2-v2` | 19 commits de #17 rejoués sans conflit ; `git diff origin/feat/ui-premium-v1.2 …` sur le code : mêmes deux seules différences |
| `scripts/verify.ps1 -DownloadRobloxTypes` | toutes étapes OK sur `2649d91` (Comète v2) et sur le sommet UI v2 avant la passe documentaire ; relancé après elle (voir le commit de la passe) |
| 6 — passe documentaire | corrections D1 à D18 principales (ROADMAP, README, QA_BACKLOG §3 octies avec QA-A24, A25, U14 à U17, D11, VM_TESTS, dossiers UI et Comète, bandeaux « suspendu » sur les documents ASTER présents, index des véhicules 3D, 3 commentaires de code sans effet) ; les documents ASTER-02 restés sur la PR #15 ne sont pas modifiés |
| 9 — art `veh3d-01-comete-v2` | créée depuis l'art `main` (`9dfc628`) ; 10 commits de la Comète rejoués, 1 conflit (`aster02_render_hf4.py`, gardé tel quel, autonome) ; dossier `vehicles/wk_comete`, `calibration` et scripts de la Comète identiques à `veh3d-01-comete` ; tête `f271b92` |

**Non fait, en attente d'accord** : étapes 1, 2, 3, 7 et 8 (fusions dans `main`, diagnostic de QA-A24, reciblage de
#15), ouverture des nouvelles PR, fermeture de #16 et #17, protection de `main`, étiquettes de sauvegarde.
Validations du propriétaire du 2026-11-05 : reportées sur les branches v2 par l'identité du code ; **une courte
revérification en jeu reste conseillée** avant fusion.

## Annexe A — commandes exécutées (2026-11-05, lecture seule)

```
gh pr list --state all --limit 30 --json number,title,state,isDraft,baseRefName,headRefName,headRefOid,mergedAt,createdAt
git fetch --all --prune
git merge-base --is-ancestor <base> <tête>          # linéarité, pour chaque PR
git rev-list --count <base>..<tête> ; git diff --shortstat <base>...<tête>
git diff --stat origin/feat/aster-phase1...origin/feat/aster-02-blockout
git diff --stat origin/feat/aster-02-blockout...origin/feat/veh3d-01-comete
git grep -n -I -E "aster-provisional|vehicle-geometry|ASTER_02_..." origin/feat/veh3d-01-comete -- src tests scripts
git merge-tree --write-tree --name-only --merge-base=origin/feat/aster-02-blockout origin/feat/aster-phase1 origin/feat/ui-premium-v1.2
gh pr view <n> --json mergeable,mergeStateStatus,reviewDecision,statusCheckRollup     # #1, #11, #14 à #17
gh api repos/AbdelmalekYounes/roblox-automotive-world/branches/main/protection        # 404 : non protégée
git worktree list ; git status --porcelain (chaque arbre)
# dépôt d'art
git log --oneline --graph --all ; gh pr list --repo AbdelmalekYounes/roblox-automotive-world-art   # aucune PR
git merge-tree --write-tree --name-only --merge-base=1633c67 origin/main origin/veh3d-01-comete
# rapports VM existants (lecture)
grep "banc_18_modeles" aw-vm-exchange/jobs/2026110[45]-*/report/report.md + "commit" de job.json
git log --oneline c352f26..origin/feat/veh3d-01-comete -- src/server/Vehicles src/server/Avatar src/shared/Vehicles src/shared/Avatar src/client/Vehicles
```

Résultats du banc des 18 modèles par tâche :

| Tâche | Commit | Résultat |
|---|---|---|
| 20261104-001121 | `9b0eebd` | 18 / 18 |
| 20261104-042820 | `c352f26` | 18 / 18 |
| 20261105-132615 | `bcfbae6` | 10 / 18 |
| 20261105-141629 | `84cefab` | 10 / 18 |
