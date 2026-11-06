# Lot PNJ-01 — piétons et voitures PNJ : rapport (étape 1, « partie modèles »)

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
| Voitures PNJ | **4 silhouettes d'environ 2 000 triangles** : citadine, berline, SUV/break, utilitaire. Roues séparées qui tournent, feux séparés, carrosserie teintable, collision gardée en boîte simple. |
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

- **Silhouettes de voitures** (cotes réalistes de catégorie, aucune voiture réelle visée) :

  | Silhouette | Part | Long. | Larg. | Haut. | Empatt. | Rayon roue |
  |---|---|---|---|---|---|---|
  | Citadine | 35 % | 3,95 m | 1,75 m | 1,50 m | 2,50 m | 0,30 m |
  | Berline | 30 % | 4,65 m | 1,82 m | 1,45 m | 2,80 m | 0,32 m |
  | SUV | 25 % | 4,55 m | 1,86 m | 1,68 m | 2,72 m | 0,36 m |
  | Utilitaire | 10 % | 5,20 m | 2,00 m | 2,25 m | 3,25 m | 0,34 m |

- **Pièces nommées d'une voiture** (gabarit `PNJ_<Silhouette>`) :
  - `Roue_AVG`, `Roue_AVD`, `Roue_ARG`, `Roue_ARD` (obligatoires) ;
  - `Feu_Stop_G/D`, `Clignotant_AVG/AVD/ARG/ARD`, `Phare_G/D` (facultatifs) ;
  - les pièces peintes contiennent `Peinture` dans leur nom.
  - **Origine du gabarit** (pivot du modèle) : au sol, au centre de l'empattement, avant vers −Z.
- **Squelette des piétons** :
  - taille de base 1,75 m, 11 articulations : bassin, taille, cou, épaules, coudes, hanches, genoux ;
  - 11 pièces rigides : `Bassin`, `Buste`, `Tete`, `BrasG_Haut`, `BrasG_Bas`, `BrasD_Haut`, `BrasD_Bas`,
    `JambeG_Haut`, `JambeG_Bas`, `JambeD_Haut`, `JambeD_Bas` ;
  - 2 morphologies : `PNJ_Pieton_H` (échelle 1,0) et `PNJ_Pieton_F` (échelle 0,94) ;
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
  du repli (16 pièces par voiture au lieu de 4, au plus 48 voitures), coût réseau des attributs de feux. À mesurer
  par le propriétaire (§7) ou lors du lot de performance.

## 6. Suite : intégration des modèles tiers (quand le propriétaire les aura téléchargés)

1. **Téléchargement par le propriétaire**, dans `E:\ROBLOX DEV\aw-vehicle-references\pnj\<silhouette|pietons>\<source>\`,
   avec une capture de la page de licence :
   - licence CC0 ou CC BY, jamais NC ou ND, et rien qui soit tiré d'un jeu ou d'un configurateur ;
   - pistes : Kenney Car Kit (CC0), Quaternius Universal Base Characters (CC0, environ 13 000 triangles, corps de
     base), Sketchfab filtré sur « Téléchargeable » avec la licence CC0 ou CC BY ;
   - liste et licences à vérifier à réception.
2. **Préparation dans le dépôt d'art** (Blender 4.5.9 portable, scripts sans interface) :
   - voitures : logos retirés, échelle uniforme vers les cotes du §3.1, roues séparées et nommées, feux séparés,
     pièces peintes nommées `Peinture…`, réduction à environ 2 000 triangles ;
   - piétons : mise en pose debout bras le long du corps, **découpage par os dominant** en 11 pièces, réduction à
     environ 1 200 triangles ;
   - export glTF selon la règle d'étalonnage (demi-tour autour de Z avant export), puis contrôles et aperçus.
3. **Import et envoi** des maillages par le propriétaire ; il fournit le `.rbxm` des gabarits.
4. **Intégration dans le jeu** :
   - fichiers partagés, à arbitrer par la coordination :
     - `default.project.json` et `openworld.project.json` : `ReplicatedStorage.AutomotiveWorldPnjKits` →
       `assets/pnjkits` ;
     - `.gitignore` : `!assets/pnjkits/*.rbxm` ;
     - `AssetManifest` : entrées `world.pnj.cars` et `world.pnj.pedestrians` avec les identifiants ;
   - cotes et repos réels mesurés sur les gabarits ;
   - crédits CC BY dans `docs/CREDITS_ACTIFS.md`, par la coordination.

## 7. Liste de vérification en jeu (propriétaire) — **NON TESTÉ**

Ouvrir `build/AW-PNJ-01-monde.rbxl` (monde ouvert), lancer Play, aller en ville (Métropole). Ce que l'on voit est
le **repli** (pièces simples) : les modèles 3D viendront à l'intégration.

1. **Voitures PNJ, aspect** :
   - plusieurs tailles de voitures circulent : petites citadines, berlines, SUV plus hauts, quelques utilitaires
     longs et hauts ;
   - chacune a 4 roues noires avec un enjoliveur clair, un habitacle sombre vitré et un toit de la couleur de la
     caisse.
2. **Roues** : derrière ou à côté d'une voiture PNJ en mouvement, l'enjoliveur tourne dans le bon sens. Dans un
   virage, les roues **avant** braquent du côté du virage ; à l'arrêt, roues immobiles.
3. **Feux stop** : à l'approche d'un feu rouge ou d'une file, les deux feux arrière passent au **rouge vif** pendant
   le freinage et restent allumés à l'arrêt ; ils s'éteignent au redémarrage.
4. **Clignotants** : avant un carrefour où la voiture tourne, les clignotants **orange** du bon côté (avant et
   arrière) clignotent environ 1,5 fois par seconde, puis s'éteignent après le virage. Rien en ligne droite.
5. **Phares** : avec le menu admin (F2), régler l'heure de nuit (par exemple 22 h). Les phares avant des voitures PNJ
   proches s'allument en blanc ; de jour, ils sont éteints.
6. **Collision** :
   - percuter une voiture PNJ avec la Comète ou la Brio : contact sur la **forme de la caisse**, ni traversée ni
     contact dans le vide au-dessus du toit ;
   - le PNJ s'arrête puis repart ;
   - les dégâts et bruits de choc sont les mêmes qu'avant ;
   - les roues et feux du PNJ ne bloquent rien.
7. **Piétons, aspect** :
   - sur les trottoirs du centre, des silhouettes humaines en 11 pièces : tête couleur peau, buste et bras du haut
     de la couleur du haut, avant-bras couleur peau, bassin et jambes de la couleur du bas ;
   - deux tailles (hommes et femmes un peu plus petites), des tenues variées.
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

## 9. Non testé / limites connues

- **Aucun essai en jeu** (§7 à faire par le propriétaire). Ni le rendu, ni le coût, ni la synchronisation des feux
  n'ont été vus dans Studio.
- Les **modèles 3D ne sont pas intégrés** : le §6 attend les téléchargements du propriétaire.
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
