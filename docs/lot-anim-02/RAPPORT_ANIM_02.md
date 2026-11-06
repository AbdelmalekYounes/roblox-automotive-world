# Lot ANIM-02 — Portières, animations d'entrée et de sortie du véhicule

- Date : 2026-11-06.
- Branche : `claude/anim-02-portieres-f3de70`, créée depuis `main` `af0cd49`. Rien n'est poussé.
- Lot mené en parallèle de PHONE-01, AUDIO-04 et MAP-01 (exception du propriétaire du 2026-11-06 : fichiers disjoints).
- Demande du propriétaire : « ajouter les animations d'entrée et de sortie du véhicule avec les portières ».
- Dépôt d'art : branche locale `anim-02-portieres`, commit `c1ce4ac`, créée depuis `origin/main` `e678ac2`, non
  poussée (worktree `E:\ROBLOX DEV\aw-art-anim02`).
- **État : terminé côté assistant, À ESSAYER EN JEU par le propriétaire (§8).** Maillages importés et envoyés sur
  Roblox par le propriétaire le 2026-11-06, intégrés aux gabarits (§5 bis) ; `verify.ps1` vert ; place de test
  `build\AW-ANIM-02.rbxlx` construite. Rien n'a été essayé en jeu. Garde-fou conservé : une porte n'est articulée que
  si toutes ses pièces sont dans le gabarit (sinon entrée et sortie sans porte, comme avant).

## 1. Décisions du propriétaire (2026-11-06, toutes posées en une fois au début du lot)

| Question | Décision |
| --- | --- |
| Niveau d'animation | **Simplifiée** : marche jusqu'à la porte (1 s au plus), la porte s'ouvre d'elle-même, le corps glisse jusqu'au siège, la porte se referme ; sortie dans l'ordre inverse. Pas de main sur la poignée. |
| Durée | **≈ 1 s à l'entrée, ≈ 0,8 s à la sortie** : porte 0,35 s, glissé 0,5 s (0,45 s à la sortie), fermeture 0,35 s. Le conducteur peut rouler dès qu'il est assis. |
| Règles | **Passager : même séquence** par sa porte ; **portes toujours fermées à l'arrêt** ; **autre porte si le côté est bloqué** (tout bloqué : sortie par le dessus, sans animation). Portes ouvertes solides : **non retenu**. |
| Comète | **Élytre fidèle** : panneau, vitre et partie du toit, ouverture vers le haut et l'avant. |

Annoncé avant les questions, sans objection du propriétaire : portes seulement visuelles (sans collision) ; aucun son
de portière dans ce lot ; rétroviseur monté sur la porte.

## 2. Portières séparées (dépôt d'art, `c1ce4ac`)

Aucune des deux scènes n'avait de portière distincte : la porte faisait partie des grands maillages par matériau
(relevés en lecture seule : profils des flancs, coupes transversales et parties détachées, Blender sans interface).

- **`tools/blender/portieres_separe.py`** découpe la porte par la géométrie, dans le repère du jeu :
  - règle « zone » : le maillage est coupé par les plans du contour de la porte (bmesh `bisect_plane`), seulement au
    voisinage de la porte ; les faces dont le centre tombe dans la zone deviennent la pièce de la porte ;
  - règle « parties » : parties détachées entières (rétroviseurs, baguettes, vitre de la Comète) ;
  - chaque pièce garde le matériau, les UV et les normales de sa source, et s'appelle `<PRÉFIXE>_Porte<G|D>_<suffixe>`
    (le suffixe garde les motifs de peinture `_Peinture` / `_body` et de vitrage `glass`).
- **Brio** (porte classique, sans cadre de vitre) : peau de `BRIO_Caisse_Peinture` de z −1,95 à 2,715, sous la ceinture
  (y 1,52) ; panneau intérieur de `BRIO_Habitacle` au-delà de |x| 2,36, entre y −0,80 et la ceinture ; rétroviseur,
  baguette et joint de `BRIO_Soubassement` (parties entières) ; vitre `BRIO_Vitrage_Conducteur` / `_Passager` (pièce
  déjà séparée, inchangée). Montant de pare-brise et pavillon restent fixes.
- **Comète** (élytre) : contour de profil du passage de roue avant (z −4,22) au bord arrière de la vitre de porte
  (z 0,05), du bas de porte (y −0,80) jusqu'au montant de pare-brise et dans le toit. Sous la ceinture (y 1,45) : peau
  du flanc au-delà de |x| 2,3 ; au-dessus : vitre et toit jusqu'à |x| 0,95 (bande centrale fixe). Pièces : `body`,
  `carbon_fibre`, `black_metallic`, `interior` (panneau et ciel de toit, sauf l'avant du panneau z < −3,55, côté
  planche de bord), `glass` (vitre de porte entière), rétroviseurs (`Retro_body`, `Retro_carbon_fibre`,
  `Retro_mirror`). Les anciennes pièces `COMETE_Retroviseurs_*`, entièrement passées dans les portes, disparaissent.
  - Premier essai : la prise d'air derrière la porte (z 0,05 à 1,0) était découpée avec elle et laissait voir à travers
    la voiture une fois ouverte ; elle reste désormais fixe.
- **Charnières** (repère du châssis, porte gauche ; la droite est son miroir), choisies sur les rendus d'aperçu
  (`tools/blender/portieres_apercu.py`) :
  - Brio : axe vertical au bord avant de la peau, point (−2,80 ; 0,30 ; −1,88), **65°** ;
  - Comète : point (−2,85 ; 1,38 ; −3,80) au pied du montant, axe (1,6 ; 1,12 ; 1,40) normé, **75°**. Trois axes
    essayés : le long du montant (la porte s'écarte surtout), très transversal (ciseaux), retenu : intermédiaire (la
    porte monte et s'écarte).
- Aperçus fermé / ouvert : `docs/lot-anim-02/apercu_portieres.jpg` (rendus Workbench ; la Comète en couleurs de
  matériau, ses textures n'étant pas dans la scène).
- **Triangles** (LOD0) : Brio 17 865 → 18 661 (+796) ; Comète 6 907 → 10 322 (+3 415, surtout l'habitacle, recoupé
  par les plans de la porte). Les LOD1 et LOD2 des scènes ne sont pas modifiés (le jeu n'utilise que le LOD0).
- **Exports réduits à importer** : `vehicles/wk_brio/export/wk_brio_milano95_portes_anim02.glb` (9 pièces, 9 696
  triangles) et `vehicles/wk_comete/export/wk_comete_720s_portes_anim02.glb` (21 pièces, 8 817 triangles), avec leurs
  relevés JSON. Les LOD0 complets sont réexportés pour rester cohérents avec les scènes : **ne pas les importer**.

## 3. Fonctionnement en jeu

### 3.1 Portes articulées

- Données : `src/shared/Vehicles/MeshKitData.luau`, champ `Doors` des deux kits (pièces, charnière, axe orienté pour
  qu'un angle positif ouvre, angle). Module pur `src/shared/Vehicles/Doors.luau` (miroir, repère d'articulation,
  état, glissé, calendrier, interruption).
- Serveur (`src/server/Vehicles/MeshKits.luau`) : par porte, une pièce de charnière invisible (sans masse ni
  collision) articulée au châssis par un `Motor6D` (`AWPortiere`), axe Z le long de la charnière ; les pièces de la
  porte lui sont soudées. **Seulement si toutes les pièces de la porte sont dans le gabarit.**
- Client (`src/client/Vehicles/DoorVisuals.luau`) : chaque client ouvre les portes de tous les véhicules par
  `Transform` (non répliqué), d'après l'état publié par le serveur : attribut texte du modèle (`AWPorteConducteur`,
  `AWPortePassager` : « de;vers;début;durée », temps du serveur `GetServerTimeNow`), ouverture adoucie. Tous les
  joueurs voient la porte au même moment, sans réplication par image.

### 3.2 Séquences (serveur : `src/server/Vehicles/DoorService.luau`, appelé par `VehicleService`)

- **Entrée** (invites « Conduire » et « Monter (passager) », mêmes contrôles qu'avant) :
  1. la porte s'ouvre (0,35 s) pendant que le client du joueur marche jusqu'au point de la porte
     (`Humanoid:MoveTo`, attribut `AWPortiereApproche`) ; la place est réservée (« véhicule occupé » pour les autres) ;
  2. dès que le personnage est arrivé (2,5 st près) et la porte ouverte, ou au bout de 1 s de marche, **toutes les
     règles sont revalidées** (siège libre, conducteur autorisé ou règle passager, distance ≤ 16 st, vivant) et le
     serveur l'assoit ;
  3. son corps glisse de la porte au siège en 0,5 s (attribut `AWPortiereGlisse` ; le `HumanoidRootPart` est déjà
     soudé au siège : le conducteur peut rouler tout de suite) ;
  4. la porte se referme (0,35 s).
- **Sortie** (touche de sortie du conducteur ; passager : touche de saut, voir 3.4) : vitesse ≤ limite de sortie du
  modèle, comme avant ; point de dépôt choisi comme le placement existant (côté de la place, sinon l'autre côté, sinon
  au-dessus) ; porte du côté de ce point (« autre porte si côté bloqué ») ; au-dessus : sortie immédiate sans
  animation. Puis : porte ouverte (0,35 s), corps glissé jusqu'au point de dépôt (0,45 s), siège libéré et personnage
  déposé par le placement vérifié existant, porte refermée.
- **Interruptions** (vitesse du véhicule > 4 st/s, ou nouveau choc compté par `DmgImpacts`, lu seulement) :
  - pendant la marche : assis tout de suite si la montée reste valide, sinon annulée ; porte refermée vite (0,2 s) ;
  - pendant le glissé d'entrée : glissé coupé net, porte refermée vite ;
  - pendant la sortie : libéré tout de suite si la vitesse permet encore de sortir, sinon la sortie est annulée (il
    reste assis) ; porte refermée vite.
- Portes **toujours fermées à l'arrêt** : une porte ne reste ouverte que tenue par une séquence en cours.
- Occupant sorti sans séquence (bouton de saut tactile, éjection du passager) : la porte passager s'entrouvre et se
  referme (0,25 s).

### 3.3 Glissé du corps (client)

`SeatPoseController` (fichier d'ANIM-01) appelle `DoorVisuals.update` à chaque pas, puis ajoute à l'articulation
`Root` d'un personnage assis le décalage du glissé (du `HumanoidRootPart` assis vers le point de la porte, pondéré dans
le temps). Le décalage fait partie de l'écriture suivie (`Offset`) : il est retiré comme le reste de la pose. En fin de
sortie, le client du joueur pose lui-même son personnage au point de dépôt dès que le siège est libéré (pas de retour
d'une image dans le siège) ; le serveur vérifie ensuite le même point.

### 3.4 Passager : touche de saut

Le saut du moteur libérait le siège sur-le-champ, sans porte. Pour un passager d'un véhicule à portières, son client
intercepte Espace et le bouton A (`ContextActionService`, priorité haute) et envoie une demande de sortie au serveur
(RemoteEvent `AWPortieres`, une demande par 0,5 s au plus), qui joue la séquence. Le bouton de saut tactile n'est pas
intercepté : sortie immédiate, porte entrouverte.

## 4. Fichiers

Nouveaux :
- `src/shared/Vehicles/Doors.luau` (pur), `src/server/Vehicles/DoorService.luau`, `src/client/Vehicles/DoorVisuals.luau` ;
- `tests/lune/specs/Anim02.luau` (7 tests) ; `tests/lune/tools/anim02-portieres.luau` (intégration des imports) ;
- `docs/lot-anim-02/RAPPORT_ANIM_02.md`, `docs/lot-anim-02/apercu_portieres.jpg`.

Modifiés (ajouts marqués « Lot ANIM-02 ») :
- `src/server/Vehicles/VehicleService.luau` : montées (`boardOrSit`), sorties (`alightOrRelease`), demande de sortie
  des passagers, porte entrouverte au saut ; section « Lot ANIM-02 » avant `handleUnflip` ;
- `src/server/Vehicles/MeshKits.luau` : charnières ;
- `src/shared/Vehicles/MeshKitData.luau` : champ `Doors` ;
- `src/client/Vehicles/SeatPoseController.luau` : portes à chaque pas, glissé par `Root` ;
- `tests/lune/run.luau` : 1 ligne après Anim01.

Non modifiés : `README.md`, `docs/ROADMAP.md`, `docs/QA_BACKLOG.md`, `docs/CREDITS_ACTIFS.md`, `DamageService.luau`,
`PhoneController.luau`, `InterfaceService.luau`, `src/client/Audio/*`, `VehicleCamera.luau`, `tools/world/*`,
`src/shared/World/*`, `Localization.luau` (aucun nouveau texte joueur : « véhicule occupé » et « sortie trop rapide »
réutilisent les clés existantes).

## 5. Import Studio par le propriétaire (fait le 2026-11-06)

1. Dans une place locale vierge, **Importer 3D**, deux fois :
   - `E:\ROBLOX DEV\aw-art-anim02\vehicles\wk_brio\export\wk_brio_milano95_portes_anim02.glb` ;
   - `E:\ROBLOX DEV\aw-art-anim02\vehicles\wk_comete\export\wk_comete_720s_portes_anim02.glb`.
2. Réglages par défaut (« Unité d'échelle : Stud », facteur 1, « Avance du monde : Avant ») ; cocher **« Importer sur
   Roblox »** (créateur : propriétaire de l'expérience).
3. Vérifier : Brio **9** MeshParts (`BRIO_Caisse_Peinture`, `BRIO_Habitacle`, `BRIO_Soubassement`, 6 `BRIO_Porte*`) ;
   Comète **21** (`COMETE_Caisse_body`, `_carbon_fibre`, `_black_metallic`, `COMETE_Habitacle_interior`,
   `COMETE_Vitrage_glass`, 16 `COMETE_Porte*`).
4. Clic droit, « Enregistrer dans un fichier » : `E:\ROBLOX DEV\aw-vm-exchange\anim02_brio_portes.rbxm` et
   `anim02_comete_portes.rbxm`.

Ensuite (assistant) : `lune run tests/lune/tools/anim02-portieres.luau <brio|comete> <import.rbxm> <export.json>`
(pièces placées aux centres de l'export, textures d'origine reprises, anciens maillages retirés, tout code refusé) ;
manifeste mis à jour ; centre de référence de la Brio (`BRIO_Caisse_Peinture`, devenu (0,006 ; 1,364 ; 2,813)) et
tests VEH3D (nombre de maillages : Brio 27 → 33, Comète 29 → 42 ; centres de la Brio) ajustés ; `verify.ps1`.

L'outil a été essayé **à blanc** sur des imports fictifs (pièces clonées du gabarit actuel, renommées), écrits hors du
dépôt : Brio 33 maillages, Comète 42, centres de l'export reproduits, textures d'origine reprises. Le vrai fichier n'a
pas été essayé.

## 5 bis. Intégration des imports (2026-11-06)

Fichiers déposés par le propriétaire (03:12), relevés en lecture seule (Lune) :
- `aw-vm-exchangenim02_brio_portes.rbxm` (SHA-256 `d2c4648f…`) : 9 MeshParts, 10 modèles, 6 SurfaceAppearance,
  **aucun script** ; tailles identiques à l'export ;
- `aw-vm-exchangenim02_comete_portes.rbxm` (SHA-256 `b049f59e…`) : 21 MeshParts, 22 modèles, 8 SurfaceAppearance,
  **aucun script** ; tailles identiques à l'export.

`lune run tests/lune/tools/anim02-portieres.luau <brio|comete> <import.rbxm> <export.json>` :
- `assets/meshkits/Brio.rbxm` : 27 → **33** maillages (SHA-256 `c693c8c7…` avant, `7d3a5393…` après) ; anciens
  maillages retirés : `77052823926801` (caisse), `134931851726367` (habitacle), `80144700231925` (soubassement) ;
- `assets/meshkits/Comete720s.rbxm` : 29 → **42** maillages (SHA-256 `e2872b58…` avant, `e3b3d35f…` après) ;
  retirés : `135006162692878`, `102224824061605`, `118695232875609` (caisse), `77774849215644` (habitacle),
  `81797127978233` (vitrage), `102573121267361`, `134599392040709`, `117440140283283` (anciens rétroviseurs) ;
- chaque pièce placée au centre de l'export (écart ≤ 0,001 st affiché par l'outil) ; textures d'origine reprises
  (`TextureContent` et `SurfaceAppearance` de la pièce source) : aucune nouvelle texture au manifeste.

Mises à jour :
- manifeste `veh.wk_brio.meshmilano95` (33 identifiants) et `veh.wk_comete.mesh720s` (42), relevés dans les gabarits ;
  textures inchangées ; nombre de triangles du LOD0 dans les variantes ;
- `MeshKitData` : centre de référence de la Brio (0,006 ; 1,364 ; 2,813) (portes retirées de `BRIO_Caisse_Peinture`) ;
- tests VEH3D-01 (29 → 42 maillages) et VEH3D-02 (27 → 33 ; centres de la caisse, du soubassement et des 6 pièces de
  portes) ; test ANIM-02 7 rendu strict (échoue si les pièces des portes manquent).

## 6. Vérifications exécutées (2026-11-06)

| Commande | Résultat |
| --- | --- |
| `scripts\verify.ps1 -DownloadRobloxTypes` (terminé à 03:07, après toutes les modifications de code) | Rojo, Selene (0 erreur, 0 avertissement), pilote Studio, StyLua, Lune **460 réussis, 0 échoué** (dont les 7 tests ANIM-02), carte, place monde ouvert, pytest 29 réussis, luau-lsp strict 0 erreur (3 avertissements `DeprecatedApi` antérieurs, hors lot) : tout OK. |
| Blender 4.5.9 sans interface, `--factory-startup --disable-autoexec` : `portieres_separe.py` (Brio, Comète), puis `export_roblox_glb.py` (exports réduits et LOD0) | Brio 6 pièces de portes, Comète 16 ; exports du §2. |
| `portieres_apercu.py` | Rendus fermés et ouverts (§2) ; centre de la porte gauche de la Brio (−2,729 ; 0,84 ; 0,253) → (−4,703 ; 0,84 ; −0,914) ; Comète (−2,617 ; 1,271 ; −2,024) → (−3,089 ; 2,757 ; −2,673). |
| Essai à blanc de `anim02-portieres.luau` (§5) | Gabarits de sortie à 33 et 42 maillages, écrits hors du dépôt. |
| `anim02-portieres.luau` sur les vrais imports (§5 bis) | Gabarits à 33 et 42 maillages. |
| `scriptserify.ps1 -DownloadRobloxTypes` après intégration (terminé à 03:14) | Tout OK : Selene 0/0, Lune **460 réussis, 0 échoué**, pytest 29, luau-lsp 0 erreur. |
| `rojo build default.project.json -o build/AW-ANIM-02.rbxlx` (03:14) | Place de test construite (3,43 Mo). |

Tests ANIM-02 (Lune) :
1. deux portes par véhicule, porte droite miroir de la gauche ;
2. ouverture : même mouvement que les aperçus Blender (à 0,01 st), porte qui s'écarte ; articulation = rotation autour
   de l'axe ;
3. état répliqué : fraction, inversion en cours de course, codage texte ;
4. glissé : codage, poids d'entrée et de sortie, décalage, garde-fou ;
5. calendrier, interruption, porte de sortie, point d'arrivée ;
6. câblage serveur et client, `DamageService` non modifié ;
7. gabarits réels : pièces des portes présentes, une fois, aux centres de l'export (±0,01 st).

## 7. NON TESTÉ, limites et risques

**Rien n'a été essayé en jeu** : aucun test VM, selon la règle du propriétaire. Tout le §8 reste à vérifier.

- **Collisions et dégâts** : portes purement visuelles. Une porte ouverte traverse les murs et les autres joueurs. Les
  boîtes `Collisions` et `DamageService` sont inchangées ; les **marques de dégâts du flanc** (posées sur la surface
  visible, soudées au châssis) **restent en place** quand la porte s'ouvre. Ajustement possible dans un lot
  dégâts : souder aux charnières les marques qui tombent sur une porte (non fait : `DamageService` hors de ce lot).
- **Glissé en pose assise** : l'animation assise du moteur reste jouée pendant le glissé (le personnage glisse
  assis, à l'entrée comme à la sortie). En fin de sortie, il passe debout d'un coup en étant déposé.
- **Marche jusqu'à la porte** : `Humanoid:MoveTo` sur le client ; si le joueur appuie sur une touche de déplacement,
  la marche peut s'interrompre ; le serveur assoit quand même au bout de 1 s si la distance reste ≤ 16 st (le glissé
  part alors de là où il est). Obstacle entre le joueur et la porte : même chose.
- **Comète** : découpe sur un maillage très simplifié, sans joint de porte : bords de la porte approchés ; l'intérieur
  de la porte ouverte montre des faces de l'habitacle d'origine (poignée en X, garnitures). L'avant du panneau
  intérieur reste fixe. Le trou laissé dans la caisse montre le siège et le seuil.
- **Brio** : le petit triangle de custode avant (au pied du montant) reste fixe ; le joint de vitre le long du montant
  reste sur la caisse.
- **Vue cockpit** : la porte qui s'ouvre et se ferme peut passer près de la caméra pendant le glissé.
- **Passager sur écran tactile** : sortie immédiate (porte entrouverte), sans glissé.
- **Téléphone (PHONE-01)** : non vérifié en même temps qu'une montée ou une descente.
- Son de portière : non fait (décision). L'état répliqué `AWPorteConducteur` / `AWPortePassager` suffit à un lot
  AUDIO pour le déclencher.

À reporter par la coordination dans `docs/QA_BACKLOG.md` : la liste du §8, NON TESTÉ en jeu.

## 8. Liste de vérification en jeu (propriétaire)

Place : `build\AW-ANIM-02.rbxlx`. Véhicules par le menu d'administration (F2) ou la concession (Dev). Prévoir au
moins 2 joueurs (Studio, Test › Serveur local, 2 joueurs). Pour chaque point, noter le véhicule et le côté.

**A. Portes au repos**
1. Brio et Comète garées : portes fermées, aucun trou ni jour visible autour des portes, peinture du garage
   appliquée aussi sur les portes, vitres de portes transparentes comme les autres.

**B. Brio, conducteur**
2. « Conduire » à 5-10 st de la porte : le personnage marche jusqu'à la porte gauche, qui s'ouvre vers l'avant
   (≈ 65°) pendant la marche, avec sa vitre, son rétroviseur et son panneau intérieur.
3. Le corps glisse de la porte au siège en ≈ 0,5 s, puis la porte se referme. Durée totale ≈ 1 s (hors marche).
4. Rouler aussitôt assis : la conduite répond ; la porte se ferme vite si elle était encore ouverte.
5. Sortir à l'arrêt : porte ouverte, corps glissé dehors, personnage debout à côté de la porte, porte refermée
   (≈ 0,8 s + 0,35 s). Aucun saut du personnage dans le siège puis dehors.

**C. Brio, passager**
6. « Monter (passager) » : même séquence par la porte droite.
7. Passager assis, Espace (ou bouton A) : sortie par la porte droite, même séquence. Pas de saut.
8. Le conducteur démarre pendant que le passager marche vers la porte : le passager est assis tout de suite, la porte
   se ferme vite.

**D. Comète**
9. Refaire B et C avec la Comète : portes en élytre qui montent et s'écartent (≈ 75°), vitre, partie du toit et
   rétroviseur avec la porte. Noter tout trou, toute face manquante ou tout morceau resté en l'air.
10. Vue de l'intérieur porte ouverte et fermée : rien de choquant (§7 : intérieur simplifié).

**E. Vu par un autre joueur**
11. Le 2e joueur voit la marche, la porte qui s'ouvre et se ferme et le glissé, au même rythme.

**F. Côté bloqué, interruptions**
12. Garer la Brio flanc gauche contre un mur, puis sortir côté conducteur : sortie par la porte droite, qui s'anime.
13. Les deux côtés bloqués : sortie par le dessus, sans animation (comportement précédent).
14. Pousser le véhicule (autre véhicule) pendant une montée ou une descente : la séquence s'arrête proprement, porte
    refermée vite, personnage assis ou déposé, jamais coincé dans la carrosserie.
15. Demander la sortie en roulant au-dessus de la limite : refusée comme avant (« sortie trop rapide »).

**G. Divers**
16. Plusieurs montées et descentes de suite, conducteur et passager : portes toujours refermées à la fin.
17. Sur écran tactile (passager) : bouton de saut → sortie immédiate, porte entrouverte puis refermée.
18. Vue cockpit pendant l'entrée et la sortie : rien de gênant (porte près de la caméra).
