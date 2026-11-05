# UI-03 — aperçu 3D du garage (ViewportFrame) : rapport

Branche `feat/ui-premium-v1.2`, PR #17 (brouillon). Rapport du 2026-11-05.

**Décision du propriétaire** (2026-11-05, « fait viewportframe ») : la zone 3D du garage (maquette « Garage » §4) affiche
le véhicule par un **ViewportFrame**, et non par une caméra de présentation dans le monde.

## 1. Ce qui est fait

| Élément | Contenu |
|---|---|
| Aperçu (client) | `src/client/UI/VehiclePreview.luau` : ViewportFrame `Apercu3D` dans la zone 3D, au-dessus du dégradé, sous le nom du véhicule ; caméra à 30° de champ, plongée 14°, cadrage automatique sur la sphère englobante ; rotation lente (12°/s), glisser à la souris ou au doigt, stick droit de la manette ; rotation automatique coupée par « réduire les animations » ; aucun calcul par image garage fermé |
| Véhicule affiché | exemplaire sélectionné, sinon le premier de la collection ; dans l'onglet Préparation, teinte du brouillon (carrosserie et accent) avant validation |
| Copie visuelle (serveur) | `src/server/Vehicles/VehiclePreviewService.luau` : à la première demande d'un modèle, copie construite par la fabrique habituelle, rendue **inerte** puis placée dans `ReplicatedStorage.AWVehiclePreview.Modeles` (une par modèle, partagée) |
| Règles pures | `src/shared/UI/PreviewFraming.luau` : distance de cadrage, forme de l'identifiant demandé, pas de rotation |
| Démarrage | `Bootstrap.server.luau` : `VehiclePreviewService.start()` dans les deux places |

**Écart à signaler** : j'avais annoncé au propriétaire que le ViewportFrame ne touchait pas au serveur. C'est inexact :
les gabarits 3D (ServerStorage) et la fabrique ne sont pas visibles du client, d'où le petit service serveur ci-dessus.
Il est en **lecture seule** : seul l'identifiant de modèle est lu dans la demande (forme validée, puis existence dans
le catalogue), aucune donnée de profil, aucune possession, aucune écriture ; au plus une copie par modèle du catalogue ;
délai minimal de 0,15 s entre deux demandes d'un joueur.

**Copie inerte** : étiquette `AWVehicle` et attributs d'identité retirés (aucun système du jeu ne la prend pour un
véhicule), pièces ancrées sans collision ni requête, joints, forces, invites, lumières et boîtes de collision supprimés.
Les pièces à repeindre portent `AWPaintRole` (Body / Accent) ; la Comète, en mode « Texture » (pas de carte de couleur
neutre envoyée), garde sa texture d'origine.

## 2. Essais

| Essai | Commande, tâche | Résultat |
|---|---|---|
| Statique | `scripts\verify.ps1 -RobloxTypes .tooling\globalTypes.d.luau`, 2026-11-05 | toutes les étapes OK ; Lune **389 / 389** (4 nouveaux : cadrage selon le format de la zone, identifiants refusés, rotation, service inerte et branché) ; pytest 14 / 14 ; luau-lsp strict 0 erreur |
| Aperçu 3D seul (VM) | `test-vm.cmd -Sessions ui_garage3d -GuiInput`, `20261105-114328` | **16 / 16** : ViewportFrame présent ; garage ouvert par la vraie touche P ; premier véhicule affiché (proto_p01, 30 pièces) et cadré ; copie serveur inerte (0 élément actif, 0 copie étiquetée) ; rotation automatique (229,6° → 247,8° en 1,5 s) ; vrai clic sur « Prototype d'essai P-02 » → aperçu proto_p02 ; Comète affichée (28 MeshPart, 39 pièces) ; 2 / 2 demandes refusées (modèle inconnu, identifiant mal formé) ; fermeture par vrai clic, rotation arrêtée ; aucune erreur serveur |

Captures (`aw-vm-exchange\jobs\20261105-114328\report\gui\named\`) : `001_ui_garage3d_premier.jpg`,
`002_ui_garage3d_selection.jpg`, `003_ui_garage3d_comete.jpg`.

La Comète n'est pas dans la collection du profil d'essai (proto_p01 à p03) : l'essai l'affiche en appelant directement le
module de l'aperçu. Sur la capture 003, le titre de la zone reste donc celui du véhicule sélectionné (« Prototype
d'essai P-02 ») ; c'est un effet de l'essai, pas du jeu.

## 3. Limites et NON TESTÉ

- **Rendu simplifié du ViewportFrame**, comme annoncé : une lumière, pas d'ombres, pas de reflets du décor, phares
  éteints.
- **Cadrage** : la sphère englobante est prudente ; le véhicule occupe environ 55 à 65 % de la largeur de la zone
  (aucun risque de coupe en rotation). À resserrer si le propriétaire le souhaite.
- NON TESTÉ en VM : **glisser à la souris** (le pont d'entrées de la VM n'envoie pas de glisser), **stick de manette**,
  repeinte en direct dans l'onglet Préparation, option « réduire les animations », écran 1440 p.
- Dégâts : la copie montre le modèle neuf (l'état de dégâts de l'exemplaire n'est pas reporté).
- Onglets du garage : contenu toujours restylé, pas recomposé selon la maquette (voir `UI_02_04_RAPPORT.md` §5) ; sur
  la capture 001, les boutons du véhicule de départ débordent du panneau compact (constat antérieur, non traité ici).
