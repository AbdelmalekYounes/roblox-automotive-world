# VEH3D-01 — intégration de la Comète 3D

Branche du jeu `feat/veh3d-01-comete` (base : `feat/aster-02-blockout`, ASTER-02 suspendu) ; dépôt d'art, branche
`veh3d-01-comete`. Lot ouvert le 2026-11-04 à la demande du propriétaire.

Objectif : la Comète (`wk_comete`) roule dans le jeu avec le modèle 3D préparé (modèle tiers « 2017 Mclaren 720s »,
CC BY 4.0, registre `MODELES_TIERS.md`) **à la place de sa carrosserie provisoire**. La physique est inchangée. Les 17
autres véhicules ne changent pas.

## 1. État de départ (vérifié)

- Modèle préparé et contrôlé dans Blender (`MODELES_TIERS.md` §2 et §3) :
  - logos retirés ;
  - échelle et calage sur les roues du jeu ;
  - 4 roues, sièges, caméras, sorties et 4 collisions mesurés ;
  - LOD1 et LOD2.
- Étalonnage terminé (témoins v2 et v3) : glTF, demi-tour de 180° avant l'export, import par défaut.
- Premier import dans Studio par le propriétaire (`MODELES_TIERS.md` §5) : géométrie exacte, **vitrage opaque**.
- Feux séparés pour ce lot : `COMETE_Feu_Av` (`AWLight = Head`) et `COMETE_Feu_Ar` (`Tail`). Le fichier à importer est
  réexporté (dépôt d'art, `vehicles/wk_comete/export/wk_comete_720s_lod0.glb`, 28 pièces, 6 907 triangles).

## 2. Étape du propriétaire : envoi des maillages sur Roblox

Un jeu publié n'utilise que des maillages envoyés sur Roblox. C'est une **publication d'actifs** : décision et action du
propriétaire (CLAUDE.md, D6).

1. Place locale vierge, **Importer 3D**, fichier `wk_comete_720s_lod0.glb`, réglages par défaut. **« Importer sur
   Roblox » coché**, créateur : **propriétaire de l'expérience** (compte ou groupe, D6).
2. Dans l'Explorateur : clic droit sur le modèle importé, **« Enregistrer dans un fichier »**, format `.rbxm`.
3. Déposer le `.rbxm` dans le dossier d'échange (`aw-vm-exchange`), puis prévenir l'assistant.

Le crédit CC BY devient obligatoire dès que le jeu est partagé ou publié (§3, écran de crédits).

## 3. Travaux de l'assistant (après réception du `.rbxm`)

| Élément | Contenu |
|---|---|
| Modèle dans le dépôt | `.rbxm` versionné, synchronisé par Rojo. Contrôle Lune : noms des pièces, identifiants d'actifs présents, positions relatives conformes à l'export (±0,01 st) |
| Fabrique | Nouveau chemin de construction à côté de `BodyKits` : si la définition désigne un kit de maillages et que ses identifiants sont validés, le modèle est cloné et soudé au châssis (pièces sans masse, `CanCollide`, `CanQuery` et `CanTouch` à faux). **Sinon, retour à la carrosserie provisoire** |
| Roues | Roues visuelles du modèle à **leur propre position**, 3,5 à 4,7 cm plus à l'intérieur que la physique (décision « Garder l'échelle »), animées comme aujourd'hui (`Motor6D.Transform`) |
| Sièges | `DriverSeat` et `PassengerSeat` aux repères mesurés sur le modèle, avec `AWSeatPose` |
| Caméras, sorties | `CameraCockpit`, `CameraHood`, `CameraBumper`, `ExitLeft`, `ExitRight` aux repères mesurés |
| Collisions | 4 boîtes aux noms actuels (`Coque`, `BouclierAvant`, `BouclierArriere`, `Habitacle`), aux tailles mesurées. Les zones de dégâts restent fonctionnelles |
| Vitrage | Pièces `*_glass*` : matériau Verre, teinte sombre, transparence ≥ 0,3 (correction du défaut constaté à l'import) |
| Feux | `COMETE_Feu_Av` et `COMETE_Feu_Ar` portent `AWLight`, posé par la fabrique si l'importeur ne reprend pas la propriété glTF |
| Peinture | Teinte du modèle (dans sa texture) : la couleur de carrosserie du jeu ne s'applique pas à ce modèle. Limite documentée, à arbitrer |
| Crédits | Écran de crédits en jeu (textes FR et EN par clé) affichant le crédit CC BY de `docs/CREDITS_ACTIFS.md` |
| Manifeste | `AssetManifest` : entrée « modèle tiers, CC BY 4.0 », provenance, identifiants réels, statut `ReadyForReview` |

Les LOD1 et LOD2 ne sont pas intégrés dans ce lot. La bascule par `RenderFidelity` est laissée par défaut ; à revoir avec
la mesure D5.

## 4. Essais

| Essai | Outil | Critère |
|---|---|---|
| Structure | Lune | Pièces, attributs, sièges `AWSeatPose`, collisions nommées, centres de roues ; repli sur la carrosserie provisoire sans identifiant |
| Régression | `scripts\verify.ps1` | Toutes les étapes OK ; 17 autres véhicules inchangés |
| Jeu | VM (`test-vm.cmd`) | Apparition, conduite, montée et descente, caméras cockpit, capot et bouclier, dégâts aux 4 zones, phares la nuit |
| Avatars | VM `aster` adaptée | Têtes sous le pavillon, mains sur le volant, pieds au-dessus du plancher : 3,38 st d'assise au pavillon, non mesuré |
| Performances (D5) | VM `perf` | 24 Comète visibles, jour et nuit : temps d'image ≤ référence + 2 ms |
| Essai humain | Propriétaire | Revue visuelle et conduite |

## 5. Réalisé (2026-11-04)

**Gabarit reçu.** Le `.rbxm` a été déposé par le propriétaire dans `aw-vm-exchange` (`720s.rbxm`, 78 604 octets,
SHA-256 `4dc7dbff…ee040`). Inspection en lecture seule (`tests/lune/tools/inspect-rbxm.luau`) :
- 28 MeshParts, 16 SurfaceAppearance, 29 Models ;
- **aucun script** ;
- 28 identifiants de maillages et 5 de textures.

**Écart constaté** : ce `.rbxm` vient du **premier** export. Les feux n'y sont pas séparés : on y trouve
`COMETE_Caisse_lights` et `COMETE_Aileron_lights`, pas `COMETE_Feu_Av/Ar`. Un nouvel envoi n'est pas demandé tout de
suite : il sera groupé avec les autres changements du modèle.

| Élément | Fait |
|---|---|
| Gabarit | `assets/meshkits/Comete720s.rbxm`, rangé par Rojo dans `ServerStorage.AutomotiveWorldMeshKits`, dans les deux places : développement et monde ouvert |
| Données du kit | `src/shared/Vehicles/MeshKitData.luau`, module pur : repères, collisions, roues, vitrage, sources de lumière, détails |
| Construction | `src/server/Vehicles/MeshKits.luau` (voir ci-dessous) |
| Fabrique | `VehicleFactory` : kit demandé pour chaque véhicule, `elseif` vers la carrosserie provisoire sinon ; caméras et `AWSeatPose` posés pour le kit ; roues du modèle accrochées aux roues du jeu. Physique inchangée |
| Manifeste | Entrée `veh.wk_comete.mesh720s` : `ReadyForReview`, CC BY 4.0, `RobloxAssetIds` (28) et `RobloxTextureIds` (5). `RobloxAssetId` reste nil : aucun son ni ressource jouable n'est déclaré |

`MeshKits` :
- utilise le gabarit seulement s'il est présent et si **chaque** maillage est inscrit au manifeste ;
- recale le gabarit sur la pièce de référence ;
- rend les pièces sans masse et sans collision visuelle, puis les soude au châssis ;
- pose le vitrage en verre sombre, transparence 0,45 ;
- crée 4 boîtes de collision invisibles aux noms des zones de dégâts ;
- ajoute 4 sources de lumière invisibles (`AWLight`) ;
- range l'habitacle, les freins et les essuie-glaces dans `Details`.

**Contrôles** (`scripts\verify.ps1`, 2026-11-04) : toutes les étapes OK. Lune : 371 sur 371, dont les 6 nouveaux tests
`Veh3d01Comete` :
- gabarit : 28 maillages, aucun script ;
- identifiants du manifeste égaux à ceux du gabarit ;
- roues à ±0,03 st de la physique en longueur et en hauteur ; voie 0,10 à 0,20 st plus étroite, du bon côté ;
- sièges dans l'habitacle, caméras, noms des zones ;
- vitrage, feux et détails repérés ;
- kit pour la seule Comète, avec repli.

## 6. Non fait, non vérifié (mis à jour le 2026-11-05)

- Essais en jeu : voir §7. Restent **NON TESTÉS** : choc latéral, invite E par une vraie touche, autres
  morphologies d'avatar, mesure D5 sur un poste réel (la VM est plafonnée à 60 images/s), chargement des maillages
  dans l'expérience publiée (le Studio de la VM les charge), essai humain.
- Écran de crédits en jeu : **non fait**. Le crédit est obligatoire dès que le jeu est partagé ; texte prêt dans
  `docs/CREDITS_ACTIFS.md`.
- Feux non séparés dans le gabarit reçu : les sources de lumière éclairent, mais le maillage des feux ne s'illumine pas.
- **Vitres latérales noires vues de l'extérieur** (captures du 2026-11-05) : l'avatar n'est pas visible. Ce ne sont
  **pas** des vitres peintes, contrairement à ce qu'indiquait la première version de ce rapport (déduction non vérifiée,
  corrigée) : `COMETE_Vitrage_glass` contient les vitres latérales (9 faces par côté) et des rayons lancés dans Blender
  les traversent sans rien toucher derrière. C'est le réglage du jeu (matériau Glass, teinte 28/32/38, transparence
  0,45) qui les rend noires sur un habitacle sombre. Comparatif dans la VM, conducteur assis (session `comete_vitres`,
  tâche `20261105-003353`, 29 contrôles réussis) :

  | Réglage | Matériau | Teinte | Transparence | Conducteur vu de profil |
  |---|---|---|---|---|
  | A (actuel) | Glass | 28/32/38 | 0,45 | non (vitre noire) |
  | B | Glass | 28/32/38 | 0,70 | à peine |
  | C | Glass | 120/135/145 | 0,60 | oui de trois-quarts, reflet du ciel marqué |
  | D | SmoothPlastic | 120/135/145 | 0,60 | oui, net |
  | E | SmoothPlastic | 60/70/80 | 0,75 | oui, net |

  Réglage à choisir par le propriétaire ; D et E s'écartent du plan (§3 : « matériau Verre »). Aucun nouvel envoi des
  maillages n'est nécessaire pour ce point.
- La teinte de carrosserie du jeu ne s'applique pas : la couleur est dans la texture.
- Les dégâts visuels ne s'affichent pas sur les maillages : les zones de dégâts sont des boîtes invisibles (seules les
  rayures, pièces de décor, apparaissent).
- LOD1 et LOD2 non intégrés.

## 7. Essais dans la VM (2026-11-05)

Session `comete` (`tests/studio/CometeServer.server.luau`, `CometeClient.client.luau`), place de développement,
1 joueur, vraies entrées dans la VM : `test-vm.cmd -Sessions comete -GuiInput -TimeoutSec 1800`.

**Tâche de référence `20261105-002227`** (2026-11-05 vers 00 h 25, commit de base `73b23eb` + modifications non
encore commitées à ce moment) : **59 contrôles réussis, 1 échec** (`comete.k06.ctrl_recu_par_le_jeu`), 14 captures
nommées, 157 s. Rapport : `aw-vm-exchange\jobs\20261105-002227\report\report.md` (hors dépôt).

| Essai | Résultat |
|---|---|
| QA-K01 apparition | 28 maillages, sans masse ni collision, soudés ; CG à 1,50 st du sol ; P-01 inchangé |
| QA-K02 chargement | 34 contenus chargés, 0 échec (Studio de la VM, compte de test) |
| QA-K03 roues | braquage 35,3° (touche A), jante 5 766° (touche W, 41,6 km/h) |
| QA-K04 sièges | invites, `AWSeatPose`, pose conducteur et passager dans l'habitacle (avatar par défaut), sorties F et Espace |
| QA-K05 caméras | cockpit, capot, bouclier atteints par la touche V |
| QA-K06 dégâts | avant 41,6 km/h (zone 1,00) ; arrière 21,8 km/h (zone 0,41) ; latéral non couvert |
| QA-K07 nuit | 4 / 4 sources allumées, vitrage 2 / 2 transparent |
| QA-K08 performances | non concluant : 60 images/s des deux côtés |

**Défaut trouvé à la lecture du code et corrigé avant tout essai en jeu** (le bloc n'a donc jamais été observé) : au niveau de dégâts 2, le jeu
copiait le panneau `BouclierAvant` ou `BouclierArriere` pour le montrer enfoncé. Sur la Comète, ce panneau est la boîte
de collision invisible, et la copie était opaque : un bloc gris de 4,1 × 1,8 × 1,3 st serait apparu devant le nez. Les
boîtes du kit portent maintenant `AWCollisionOnly` et `DamageService` ne les copie plus. Après les deux chocs
(niveaux 3 et 2), en jeu : 6 éléments dans `Degats`, aucun bloc opaque.

**Passages précédents, même jour** (mise au point de la session, non retenus comme résultats) :

| Tâche | Cause de l'écart | Correction |
|---|---|---|
| `20261105-000204` | les suites de base (`ServerSuite`, `ClientSuite`) tournaient aussi et fermaient la session | session exclue de ces suites |
| `20261105-000811` | fenêtre d'arrivée « Choisir votre véhicule » ouverte : la conduite est capturée par l'interface (comportement voulu, lot 0.7) ; chocs lancés par le serveur plafonnés par la validation anti-éjection | fermeture par la vraie touche Retour ; choc arrière en marche arrière conduite |
| `20261105-001422`, `-001843` | rapport R jamais engagé : la touche Ctrl n'arrive pas au jeu dans Studio | relevé des touches reçues, repli instrumenté et signalé |

**Limites de l'environnement** : touche Ctrl jamais reçue par le jeu dans Studio (ni code virtuel ni code de
balayage), comme la touche O (lot 0.9.1) ; la VM rend à 60 images/s au plus.

**Instrumenté** (signalé dans les en-têtes des scripts) : véhicules temporaires protégés, placement par `PivotTo`
(véhicule vide), assise par `Seat:Sit`, heure imposée, caméra placée pour les captures, rétrogradage vers R par
l'appel de test `invokeActionForTest` (même gestionnaire que la touche), parc D5 construit par la fabrique et ancré.

**Captures** (`report\gui\named\`, hors dépôt) : trois-quarts avant et arrière, profil, dessus, roue, conducteur par
la vitre, trois vues de conduite, après les chocs, nuit avant et arrière, P-01. Ce sont des rendus du modèle tiers :
elles restent hors du dépôt.
