# Lot PNJ-01 — piétons et voitures PNJ : rapport (étape 1, « partie modèles » : modèles 3D intégrés)

- Date : 2026-11-06. Branche `claude/pnj-01-pietons-trafic-f6c937`, partie de `main` 1037a9a. Rien n'est poussé.
- Périmètre de cette étape (décision du propriétaire) : la **partie modèles**, sans toucher à la carte. Le
  **comportement** (virages, carrefours, réaction au joueur, traversées des piétons, densités) **attend la fin de
  MAP-01**.
- Place de test : `build/AW-PNJ-01.rbxlx` (Rojo, `default.project.json`) et `build/AW-PNJ-01-monde.rbxl`
  (`openworld.project.json`, carte du monde ouvert générée).

## 1. Décisions du propriétaire (2026-11-06)

| Sujet | Décision |
|---|---|
| Ordre | Le comportement attend MAP-01. La partie modèles se fait maintenant, sans toucher à la carte. |
| Source des modèles 3D | **Modèles tiers sous licence CC** : le propriétaire les télécharge, je les prépare dans le dépôt d'art, et lui seul envoie les maillages sur Roblox. |
| Voitures PNJ | Voitures d'environ 2 000 triangles, roues séparées qui tournent, feux séparés, carrosserie teintable, collision gardée en boîte simple. Puis : **les 10 modèles du pack de Comrade1280** (CC BY 4.0), coupé et sportive rares (§6.1). |
| Piétons | **Humains low-poly découpés en pièces rigides et animés par le code** : aucun actif d'animation. |
| Encore ouvert (à reprendre après MAP-01) | Recommandations 1 (réaction au joueur), 2 (piétons face aux véhicules), 4 (densité et coût) et 6 (découpage), décrites dans la note de passation. |

## 2. État des lieux mesuré (avant le lot)

Mesures du modèle pur sous Lune, le 2026-11-06, avec l'outil `tests/lune/tools/pnj01-mesure.luau`. Ce sont des
sorties du modèle, pas des mesures en jeu.

```
lune run tests/lune/tools/pnj01-mesure.luau build/AutomotiveWorld.rbxlx
```

- **Réseau** : 2 217 tronçons ouverts au trafic, soit 320,7 km. Carrefours de degré ≥ 3 : 59 à feux, 1 144
  cédez-le-passage, 6 insertions.
- **Trafic** (150 agents × 300 s, pas de 0,2 s) :
  - coût du pas du modèle : 0,48 ms en moyenne, P95 0,61 ms ;
  - décélération maximale 8 m/s², et plus de 7 m/s² dans 0,17 % des échantillons ;
  - à-coups (plus de 10 m/s³) dans 0,32 % des échantillons ;
  - **4 571 changements de cap de plus de 30° en 0,2 s**, c'est-à-dire un raccord droit au carrefour ;
  - accélération latérale calculée jusqu'à 461 m/s² ;
  - virages de plus de 60° pris à **39,6 km/h** en moyenne, contre 42,5 km/h en ligne droite.
- **Aspect des voitures** : caisse en boîte avec habitacle, sans roues, feux arrière toujours allumés, ni
  clignotant ni feu stop.
- **Piétons** :
  - 1 916 trottoirs, 4 668 piétons théoriques ;
  - figurants de 2 blocs déplacés 10 fois par seconde ;
  - aucune animation ni traversée ;
  - 33 paires superposées (moins de 0,5 m) à t = 777 s.

Les défauts de **comportement** (virages, carrefours, superpositions) relèvent de l'étape suivante, après MAP-01.

## 3. Ce que fait cette étape

### 3.1 Contrat des modèles 3D — `src/shared/World/PnjKits.luau` (pur)

- **Variantes de voitures** : d'abord 4 silhouettes de catégorie, puis remplacées par les **10 modèles mesurés** du
  pack (§6.1). Pour chacune : longueur, porte-à-faux, largeur, hauteur, empattement, voie, rayon et largeur des
  roues, part du trafic.
- **Pièces nommées d'une voiture** (gabarit `PNJ_<Id>`) :
  - `Roue_AVG`, `Roue_AVD`, `Roue_ARG`, `Roue_ARD` (obligatoires) ;
  - `Feu_Stop_G/D`, `Clignotant_AVG/AVD/ARG/ARD`, `Phare_G/D` (facultatifs) ;
  - les pièces peintes contiennent `Peinture` dans leur nom.
  - **Origine du gabarit** (pivot du modèle) : au sol, au centre de l'empattement, avant vers −Z.
- **Squelette des piétons** :
  - taille de base 1,75 m, 11 articulations : bassin, taille, cou, épaules, coudes, hanches, genoux ;
  - 11 pièces rigides : `Bassin`, `Buste`, `Tete`, `BrasG_Haut`, `BrasG_Bas`, `BrasD_Haut`, `BrasD_Bas`,
    `JambeG_Haut`, `JambeG_Bas`, `JambeD_Haut`, `JambeD_Bas` ;
  - 18 personnages `PNJ_Pieton_<Id>` (§6.2), aux articulations mesurées ;
  - **origine** : au sol entre les pieds, regard vers −Z, debout, bras le long du corps.
- **Apparence stable** : morphologie, couleurs du haut, du bas et de la peau tirées d'un hachage de la clé du
  piéton. Tous les joueurs voient la même personne.
- **Garde-fou** : un gabarit n'est utilisé que s'il est présent dans `ReplicatedStorage.AutomotiveWorldPnjKits`,
  complet, et si **chacun** de ses maillages figure au manifeste d'actifs (`world.pnj.cars`,
  `world.pnj.pedestrians`). Sinon le jeu construit un **repli** en pièces simples, avec les mêmes noms, les mêmes
  cotes et les mêmes articulations. C'est ce repli qui est visible tant que les modèles ne sont pas intégrés.

### 3.2 Allure des piétons — `src/shared/World/PedestrianGait.luau` (pur)

- Cinématique directe sur le squelette : chaque articulation reçoit une rotation et chaque pièce suit son
  articulation. Trois allures : attente (respiration, transfert d'appui, tête qui regarde), marche et course
  (au-delà de 2,4 m/s).
- **Phase = distance parcourue / longueur de foulée**, donc les pieds ne glissent presque pas :
  - foulée de 1,46 m à 1,4 m/s ;
  - hanche ±20° ;
  - genou jusqu'à environ 52° en phase oscillante ;
  - bras opposés aux jambes ;
  - bassin qui monte et descend de 2,4 cm deux fois par foulée ;
  - en course : genou à environ 95°, coudes à 80°, buste penché de 10°.
- Vue de profil contrôlée hors Roblox avec `tests/lune/tools/pnj01-allure.luau`, qui exporte le JSON, puis tracé
  dans un dossier temporaire.

### 3.3 Voitures PNJ — serveur `src/server/World/TrafficBodies.luau`, client `src/client/World/TrafficVisuals.luau`

- **Collision inchangée dans son principe** :
  - une seule boîte non ancrée « Caisse », guidée par AlignPosition / AlignOrientation à force limitée ;
  - elle prend maintenant **les cotes de la silhouette**, au lieu d'une boîte unique de 4,6 m ;
  - densité inchangée (8). DamageService et CollisionExchange ne sont pas touchés.
- **Visuel** : gabarit 3D cloné, ou repli. Le repli comprend :
  - habitacle vitré et toit peint ;
  - 4 roues avec enjoliveur décentré, pour que la rotation se voie ;
  - feux stop, 4 clignotants et 2 phares.

  Toutes ces pièces sont sans masse, sans collision, sans requête et sans contact.
- **Roues** : reliées par Motor6D. Chaque client les fait **tourner** (roulement sans glissement) et **braquer**
  (modèle bicyclette à partir du lacet répliqué, limité à 35°), sans aucun échange réseau.
- **Feux** (`src/shared/World/TrafficCues.luau`, pur) :
  - **feu stop** au-delà de 0,8 m/s² de décélération ou à l'arrêt ;
  - **clignotant** à moins de 45 m d'un carrefour quand le tronçon suivant tourne de plus de 25°. Il reste allumé
    sur les 8 premiers mètres de la voie suivante.
  - Le serveur ne publie que les **changements** (attributs `AWPnjFrein`, `AWPnjClignotant`).
  - Le client fait clignoter à environ 1,5 Hz et allume les **phares la nuit**, ou par brouillard ou pluie forte,
    avec la règle `ArtDirection.lightsOn` des véhicules des joueurs.
  - Seules les voitures à moins de 140 m de la caméra sont animées.
- Chaque agent garde sa silhouette et sa teinte tant qu'il existe.

### 3.4 Piétons — `src/client/World/Pedestrians.luau`

- Silhouettes de 11 pièces, issues du gabarit ou du repli, réutilisées dans une réserve par morphologie : aucune
  création ni destruction en régime établi.
- Choix des 60 plus proches dans un rayon de 150 m, 10 fois par seconde, comme avant. Animation **à chaque image**
  jusqu'à 50 m, puis 12 fois par seconde au-delà.
- **Demi-tour progressif** au bout du trottoir (5 rad/s, environ 0,6 s) au lieu d'un retournement instantané.
- `PedestrianModel.walker` (nouvelle fonction) calcule un seul piéton et ajoute `Speed` et `Travel` à chaque
  piéton. Les positions restent celles du lot 0.3.

## 4. Fichiers

- **Nouveaux** :
  - `src/shared/World/PnjKits.luau`, `PedestrianGait.luau`, `TrafficCues.luau` ;
  - `src/server/World/TrafficBodies.luau`, `src/client/World/TrafficVisuals.luau` ;
  - `tests/lune/specs/Pnj01.luau` ;
  - `tests/lune/tools/pnj01-mesure.luau`, `pnj01-allure.luau` ;
  - ce rapport.
- **Modifiés** :
  - `src/server/World/TrafficService.luau` : corps par TrafficBodies, silhouettes et feux ;
  - `src/client/World/Pedestrians.luau` : réécrit ;
  - `src/shared/World/PedestrianModel.luau` : `walker`, `Speed`, `Travel`.
- **Fichiers partagés (ajouts minimaux)** :
  - `src/client/Bootstrap.client.luau` : 2 lignes, démarrage de `TrafficVisuals` ;
  - `tests/lune/run.luau` : 2 lignes en fin de liste.
- **Frontière MAP-01 respectée** : aucune modification de `tools/world/*`, `City/*`, `Signals`, `TrafficLights`,
  `RoadNetwork`, `RoadGraph`, `MapData`, `WorldLayout`.
- **Non touchés** : README, ROADMAP, QA_BACKLOG, CREDITS_ACTIFS, DamageService, CollisionExchange.

## 5. Mesures et contrôles (exécutés le 2026-11-06)

- `lune run tests/lune/run.luau build/AutomotiveWorld.rbxlx` : **488 réussis, 0 échoué**, dont les 12 nouveaux
  tests PNJ-01 :
  - cotes et tirage pondéré (350 / 300 / 250 / 100 sur 1 000) ;
  - squelette, apparence stable et variée ;
  - pose de repos exacte ;
  - jambes et bras alternés ;
  - genou jamais en hyperextension ;
  - cheville d'appui entre −0,06 et 0,12 m ;
  - **glissement du pied d'appui sous 30 % à 1,0, 1,3 et 1,6 m/s** ;
  - coudes de course au-delà de 70° ;
  - pieds immobiles à l'attente ;
  - calcul isolé identique au calcul par trottoir ;
  - feux stop ;
  - côté du clignotant, et clignotant vérifié sur plus de 40 virages réels du réseau, jamais au milieu d'un
    tronçon long ;
  - câblage.
- `scripts\verify.ps1 -DownloadRobloxTypes` : résultat au §8.
- **Non mesurés** : coût client des 660 pièces de piétons animées, coût serveur des pièces visuelles supplémentaires
  du repli (16 pièces par voiture au lieu de 4 pour le repli, environ 21 pour un modèle 3D, au plus 48 voitures), coût réseau des attributs de feux. À mesurer
  par le propriétaire (§7) ou lors du lot de performance.

## 6. Modèles 3D tiers

### 6.1 Voitures : préparées le 2026-11-06, en attente d'import par le propriétaire

- **Source** : « Generic passenger car pack » de Comrade1280, licence **CC BY 4.0** (crédit obligatoire).
  - Page : <https://sketchfab.com/3d-models/generic-passenger-car-pack-20f9af9b8a404d5cb022ac6fe87f21f5>.
  - Téléchargé par le propriétaire, avec le fichier de licence, dans
    `E:\ROBLOX DEVw-vehicle-references\pnjoitures\` (hors dépôt).
  - Inspection (`inspect_import.py`) : 10 voitures, 69 310 triangles, roues séparées, aucune animation, aucun
    script, aucun nom évoquant un logo.
  - **Crédit à ajouter à `docs/CREDITS_ACTIFS.md`** et à l'écran des attributions (par la coordination).
- **Décision du propriétaire** : les 10 modèles entrent dans le trafic, avec ces parts :
  - berline 18 %, hayon 16 %, SUV 16 %, compacte 14 %, break 12 % ;
  - monospace 10 %, pick-up 6 %, tout-terrain 4 % ;
  - coupé 2 %, sportive 2 %.
- **Préparation** dans le dépôt d'art, worktree `E:\ROBLOX DEVw-art-pnj01`, branche `pnj-01-modeles`, commit
  610f62f, non poussé :
  - script `tools/blender/pnj01_voitures.py`, détail dans `vehicles/pnj/README.md` ;
  - **toutes les textures sont retirées**, parce que l'atlas des optiques assemble des photos de vrais feux ;
  - chaque face est classée d'après la couleur de la texture d'origine, puis reçoit un matériau uni : peinture
    teintable, garniture, chrome, vitrage, feu stop, clignotant, phare, optique, pneu, jante ;
  - environ 7 000 → **environ 2 000 triangles** par voiture (2 001 à 2 159) ;
  - origine au sol au centre de l'empattement ;
  - 10 GLB (`vehicles/pnj/export/PNJ_<Id>.glb`, environ 130 Ko chacun), selon la règle d'étalonnage ;
  - aperçus dans `vehicles/pnj/apercus/`.
- **Jeu** : `PnjKits.Cars` reprend les **cotes mesurées** des 10 modèles (`vehicles/pnj/releves/voitures.json`).
  - `PnjKits.PartStyles` réapplique les couleurs unies, car l'import glTF de Studio les perd.
  - Les jantes sont soudées à leur roue ; elles tournent avec elle.
  - L'origine de chaque gabarit est **déduite des 4 roues**, parce que le pivot d'un modèle importé n'est pas fiable.
  - La boîte de collision est centrée sur la longueur hors tout.
- **Import par le propriétaire** :
  1. importer les 10 GLB depuis `E:\ROBLOX DEVw-vm-exchange\pnj01_voitures\` avec les réglages par défaut ;
  2. placer les 10 modèles `PNJ_<Id>` dans un dossier `AutomotiveWorldPnjKits` ;
  3. enregistrer ce dossier dans un fichier `.rbxm`.
- **Intégration ensuite**, fichiers partagés à arbitrer par la coordination :
  - `default.project.json` et `openworld.project.json` : `ReplicatedStorage.AutomotiveWorldPnjKits` →
    `assets/pnjkits/AutomotiveWorldPnjKits.rbxm` ;
  - `.gitignore` : `!assets/pnjkits/*.rbxm` ;
  - `AssetManifest` : entrée `world.pnj.cars` avec les identifiants des maillages.

### 6.1 bis Voitures : importées et intégrées le 2026-11-06

- **Import** : fait par le propriétaire (`aw-vm-exchange/pnj01_kits.rbxm`), puis contrôlé : 1 dossier, 10 modèles,
  205 MeshParts, **aucun script**.
- **Mise au format** : l'outil `tests/lune/tools/pnj01-kits.luau` nomme chaque voiture `PNJ_<Id>` et retire les
  modèles intermédiaires créés par Studio. Le résultat est `assets/pnjkits/AutomotiveWorldPnjKits.rbxm`, servi dans
  `ReplicatedStorage.AutomotiveWorldPnjKits`.
- **Manifeste** : entrée `world.pnj.cars` avec les 205 identifiants.
- **Attribution** : Comrade1280 (CC BY 4.0) dans l'écran « Crédits et licences ».
- **Test Lune** : sur les 10 voitures importées, empattement et voie conformes aux mesures à 5 cm près, roue gauche
  bien à gauche, et liste du manifeste identique aux maillages du gabarit.

### 6.2 Piétons : préparés, importés et intégrés le 2026-11-06

- **Pack Quaternius UACP (CC0) écarté** par le propriétaire : style « chibi », trop cartoon.
- **Source retenue** : « Low Poly People » de **David Jalbert**, **CC BY 4.0** (crédit obligatoire), page
  <https://davidjalbert.itch.io/low-poly-people>.
  - Téléchargé par le propriétaire dans `aw-vehicle-references/pnj/pietons/jalbert/`.
  - Le pack ne contient **aucun fichier de licence** : la licence est celle annoncée par la page.
  - **Capture de la page de licence à fournir par le propriétaire.**
- **Préparation** dans le dépôt d'art (commits 9f1361f puis cb8bd94, script `tools/blender/pnj01_pietons_jalbert.py`) :
  - les 18 personnages : corpulences normale, forte et ronde × homme / femme × 3 tenues ;
  - environ 1 150 triangles, sans réduction ;
  - bras abaissés ;
  - découpage par os dominant en 11 pièces ;
  - articulations et centre du bassin relevés (`vehicles/pnj/pietons/pietons.json`) ;
  - palette d'origine du pack conservée (64 px, cases de couleur, aucune photo) et **11 variantes de couleurs**
    (peau, cheveux, haut, bas, chaussures) ;
  - un GLB porteur des 12 palettes, pour que Studio envoie les images en un seul import.
- **Import par le propriétaire** (`aw-vm-exchange/pnj_pietons.rbxm`) : 19 modèles, 210 maillages, 30 textures,
  **aucun script**. Fusionné dans le même gabarit par l'outil.
- **Jeu** :
  - `PnjKits.Morphologies` contient les 18 personnages, avec leurs articulations mesurées et le centre du bassin.
    L'origine du modèle importé est retrouvée par le bassin.
  - `PedestrianGait` accepte ces articulations mesurées.
  - Chaque piéton reçoit une palette tirée par hachage (`TextureID` de ses pièces) : même aspect pour tous les
    joueurs, 18 × 12 combinaisons.
  - Manifeste `world.pnj.pedestrians` : 210 maillages et 30 textures.
  - Attribution de David Jalbert dans l'écran des crédits.
- **Test Lune** : 18 personnages complets, pieds au sol à 3 cm près depuis l'origine retrouvée, jambe gauche en −X,
  genou mesuré à moins de 12 cm du haut de la jambe basse, 12 palettes autorisées, manifeste identique au gabarit.
- **Crédits à ajouter à `docs/CREDITS_ACTIFS.md`** par la coordination : Comrade1280 et David Jalbert.

## 7. Liste de vérification en jeu (propriétaire)

**Validé en jeu par le propriétaire le 2026-11-06** (« c'est bon c'est validé »), dans `build/AW-PNJ-01-monde.rbxl`
construite à 18 h 30. Le détail point par point n'a pas été communiqué. Aucune mesure de performance n'a été
transmise (point 10).

Ouvrir `build/AW-PNJ-01-monde.rbxl` (monde ouvert), lancer Play et aller en ville (Métropole). Les voitures et
piétons sont les **modèles 3D** (§6). La place `build/AW-PNJ-01.rbxlx` sert à voir le contenu du dossier
`ReplicatedStorage.AutomotiveWorldPnjKits`.

1. **Voitures PNJ, aspect** :
   - les 10 modèles 3D circulent : surtout berlines, citadines à hayon, SUV, compactes, breaks et monospaces, quelques
     pick-up et tout-terrain, rarement un coupé ou une sportive ;
   - chaque voiture a une teinte de carrosserie tirée au hasard, des garnitures sombres, des chromes clairs, des
     vitres sombres, des pneus noirs et des jantes grises ;
   - aucune pièce grise « par défaut », aucune pièce décalée ou flottante, et la voiture est posée sur ses roues :
     ni enfoncée dans la route, ni en l'air.
2. **Roues** : derrière ou à côté d'une voiture PNJ en mouvement, la jante tourne dans le bon sens. Dans un
   virage, les roues **avant** braquent du côté du virage ; à l'arrêt, roues immobiles.
3. **Feux stop** : à l'approche d'un feu rouge ou d'une file, les deux feux arrière passent au **rouge vif** pendant
   le freinage et restent allumés à l'arrêt ; ils s'éteignent au redémarrage.
4. **Clignotants** : avant un carrefour où la voiture tourne, les clignotants **orange** du bon côté (avant et
   arrière) clignotent environ 1,5 fois par seconde, puis s'éteignent après le virage. Rien en ligne droite.
5. **Phares** : avec le menu admin (F2), régler l'heure de nuit (par exemple 22 h). Les phares avant des voitures PNJ
   proches s'allument en blanc ; de jour, ils sont éteints.
6. **Collision** :
   - percuter une voiture PNJ avec la Comète ou la Brio : contact sur la **forme de la caisse** (boîte invisible aux
     cotes du modèle), ni traversée ni contact franchement dans le vide ;
   - le PNJ s'arrête puis repart ;
   - les dégâts et bruits de choc sont les mêmes qu'avant ;
   - les roues et feux du PNJ ne bloquent rien.
7. **Piétons, aspect** :
   - sur les trottoirs du centre, des personnages 3D low-poly (pack Jalbert) : corpulences variées, hommes et femmes ;
   - les couleurs de peau, cheveux, haut, pantalon et chaussures varient d'un piéton à l'autre, sans fond vert
     généralisé ;
   - aucune fente visible entre les pièces à l'arrêt ;
   - en marchant, de légers écarts aux épaules, coudes, hanches ou genoux sont possibles (pièces rigides) : à
     signaler s'ils sont gênants ;
   - personne ne marche en pose T ni penché sur le côté.
8. **Piétons, marche** :
   - de près (moins de 50 m), les jambes alternent, les bras se balancent à l'opposé et le corps monte et descend
     légèrement ;
   - les **pieds ne patinent pas** au sol, ou très peu ;
   - au bout du trottoir, le piéton **fait demi-tour en environ une demi-seconde** au lieu de pivoter d'un coup.
9. **Stabilité** : se déplacer en ville pendant 2 à 3 minutes. Aucune silhouette ne reste figée en l'air, aucune
   pièce ne flotte détachée, et les piétons qui sortent du rayon disparaissent sans laisser de morceau.
10. **Performance (indicatif)** : en ville, au milieu des piétons et du trafic, regarder les images par seconde
    (Shift + F5). Comparer avec `main` au même endroit. Une baisse nette est à signaler.

## 8. Contrôles statiques

`scriptserify.ps1 -DownloadRobloxTypes`, exécuté le 2026-11-06 et terminé vers 17 h 20 (code de sortie 0) :

| Étape | Résultat |
|---|---|
| Rojo build | OK |
| Selene | OK |
| Pilote Studio | OK |
| StyLua | OK |
| Lune | OK (488 / 0) |
| Carte du monde ouvert | OK |
| Rojo build (place monde ouvert) | OK |
| Pytest | OK (33 réussis) |
| luau-lsp strict | OK |

Le premier passage avait échoué sur un avertissement Selene (`select` masqué) et sur des erreurs de typage dans
`PnjKits` et `TrafficBodies`. Ils ont été corrigés avant le second passage.

Places de test construites à 17 h 21 :
- `build/AW-PNJ-01.rbxlx`, avec `rojo build default.project.json -o build/AW-PNJ-01.rbxlx` ;
- `build/AW-PNJ-01-monde.rbxl`, copie de la place monde ouvert produite par verify.ps1.

**Dernière exécution** : 2026-11-06, terminée vers 18 h 30, après l'intégration des voitures et des piétons 3D :
`scriptserify.ps1 -DownloadRobloxTypes` est **entièrement vert**.
- Rojo, Selene, Pilote Studio, StyLua, carte du monde ouvert et pytest (33 réussis) : OK.
- luau-lsp : 0 erreur.
- Lune : **491 réussis, 0 échoué**.

Les places de test ont été reconstruites à 18 h 30 :
- `build/AW-PNJ-01.rbxlx` ;
- `build/AW-PNJ-01-monde.rbxl`.

## 9. Non testé / limites connues

- Essai en jeu : validé globalement par le propriétaire (§7), sans détail point par point ni mesure d'images par seconde. Ni le rendu, ni le coût, ni la synchronisation des feux
  n'ont été vus dans Studio.
- Les modèles 3D sont intégrés mais **jamais vus dans le moteur** :
  - origine retrouvée depuis les roues (voitures) et le bassin (piétons) ;
  - couleurs réappliquées par nom de pièce ;
  - `TextureID` changé à l'exécution sur les piétons.
  Ces points sont contrôlés sur les données du gabarit par Lune, pas à l'affichage.
- Pièces rigides des piétons : fentes possibles aux articulations en mouvement (aucune déformation de peau).
- Le **comportement** est inchangé (étape suivante, après MAP-01) :
  - virages pris trop vite, raccord droit au carrefour ;
  - pas de changement de voie ni de klaxon ;
  - piétons qui se superposent, sans traversée ni réaction aux véhicules ;
  - densité indépendante de l'heure.
- Le **clignotant d'une voiture tout juste apparue** peut s'allumer brièvement sur un tronçon courbe (apparition
  loin des joueurs ; sans effet visible attendu).
- **Contrôle de la distance des piétons** : il est fait à leur choix (toutes les 0,1 s), donc un piéton peut passer
  d'une bande de fréquence d'animation à l'autre avec 0,1 s de retard.
- `main` a avancé depuis 1037a9a (AUDIO-02, ANIM-03). Un conflit trivial est attendu à la fusion sur
  `tests/lune/run.luau` (garder toutes les lignes).
