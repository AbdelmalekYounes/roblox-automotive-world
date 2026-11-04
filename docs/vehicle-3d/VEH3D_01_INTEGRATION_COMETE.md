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

## 5. Non fait à l'ouverture du lot

Aucun code. Le `.rbxm` du propriétaire est attendu. Aucune publication par l'assistant.
