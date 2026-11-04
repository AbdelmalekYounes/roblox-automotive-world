# Spécification des futurs modèles 3D des véhicules

Statut : **proposition**, à valider par le propriétaire avant toute géométrie définitive. Rien n'est intégré au jeu ;
les carrosseries provisoires (`BodyKits`) et la physique restent inchangées.

Légende : **[mesuré]** valeur relevée dans le code ou dans le moteur (commande et tâche citées) ; **[hypothèse]** cible
de départ à confirmer par un essai ; **[décision]** choix à arbitrer.

## 1. Échelle et repère

- 1 stud = **0,28 m** (`VehicleConstants.MetersPerStud`) [mesuré]. Les dimensions de chaque définition
  (`WorkingCatalog.luau` : longueur, largeur, hauteur, empattement, voies, rayon des pneus) font foi : la carrosserie se
  dessine autour d'elles, **jamais l'inverse** (aucune caractéristique physique ne change pour un modèle 3D).
- Repère du véhicule : origine au centre du bloc `Chassis` (PrimaryPart), avant vers **−Z**, haut +Y, droite +X ; sol à
  `−CgHeightM` [mesuré, `VehicleFactory`].
- Centres de roues : `VehicleDynamics.wheelLayout(definition)` (longitudinal, latéral) et rayon `Tires.RadiusM` ; les
  jantes et pneus du modèle doivent tomber **exactement** sur ces centres (tolérance proposée ±0,05 st [hypothèse]).

## 2. Contrat d'intégration actuel (à conserver)

Structure produite aujourd'hui par `VehicleFactory.create` [mesuré, en-tête du fichier] :

```
Model (PrimaryPart = Chassis, étiquette AWVehicle)
├─ Chassis        bloc invisible : masse, collisions basses, attaches Suspension*/Contact*,
│                 CameraCockpit / CameraHood / CameraBumper, DriverDoor (invite)
├─ Carrosserie    pièces visuelles SANS masse, soudées ; Details (masqués selon la distance, DetailLod)
│                 pièces de collision : Coque, BouclierAvant, BouclierArriere, Habitacle
│                 feux : attribut AWLight = "Head" / "Tail" (VehicleLights)
├─ DriverSeat / PassengerSeat   Seat (CanCollide faux, CanTouch faux), embarquement par le serveur
└─ Wheel<FL..RR>  roues visuelles, animées localement (Motor6D.Transform : débattement, braquage, rotation)
```

Le modèle 3D remplace **uniquement les visuels** de `Carrosserie` et des roues ; châssis, sièges (positions mises à
jour), attaches, collisions et caméras restent des objets du jeu.

| Élément | Exigence |
|---|---|
| Carrosserie principale | MeshPart(s) visuels : `Massless`, `CanCollide`/`CanQuery`/`CanTouch` faux, soudés au châssis |
| Collisions | **indépendantes du rendu** : boîtes ou enveloppes simples (coque, boucliers, habitacle), mêmes noms qu'aujourd'hui pour les zones de dégâts et la détection de choc ; aucune collision sur le maillage détaillé |
| Roues | une jante + un pneu par roue (ou un maillage), pivot au **centre du moyeu**, axe de rotation X ; disques et étriers facultatifs, fixes |
| Portières, capot, coffre | pièces séparées, pivot sur la charnière ; **fermées en jeu** (D4, propriétaire, 2026-11-04 : animation reportée à un lot ultérieur, sans reprise des modèles) |
| Vitrages | pare-brise, latérales, lunette séparés ; matériau verre, transparence ≥ 0,3 pour voir l'avatar de l'extérieur |
| Rétroviseurs | séparés (exclus de l'enveloppe des flancs, comme aujourd'hui) |
| Feux | pièces séparées avec attribut `AWLight` = `Head`/`Tail` (feux allumés par `VehicleLights`) |
| Tuning | emplacements nommés (boucliers, jupes, aileron, jantes) — compatibilité avec `Garage` à préciser [décision] |
| Intérieur | planche de bord, volant (pièce séparée, pivot sur l'axe de colonne), sièges, console, combiné, pédales si visibles, garnitures |
| Points de caméra | attaches `CameraCockpit` (yeux du conducteur), `CameraHood`, `CameraBumper` fournies par le modèle |
| Points de sortie | **nouveau** : attaches `ExitLeft`, `ExitRight` (au sol, hors carrosserie) |
| Dégâts visuels | zones `Front`, `Rear`, `Left`, `Right` (`DamageModel`) ; rayures actuelles (primitives) conservées ; variantes déformées par zone : proposition ultérieure |

## 3. Habitacle compatible avec les avatars R15 (mesures du lot AVATAR-01)

### 3.1 Avatars assis [mesuré, tâche VM `20261104-111326`, 2026-11-04]

Hauteur du sommet de la tête **au-dessus du dessus de l'assise**, personnage assis par le moteur (pose standard) :

| Morphologie (échelles de la HumanoidDescription) | Tête seule | Cheveux du compte de test |
|---|---|---|
| M2 petit et mince (0,90 ; 0,70 ; tête 0,95) | 3,27 st (0,92 m) | +0,35 st |
| M1 référence (échelles 1) | **3,66 st (1,02 m)** | +0,37 st |
| M3 grand classique (hauteur 1,05) | 3,76 st | +0,37 st |
| M5 grand élancé (type de corps 1, proportions 1) | 3,88 st | +0,35 st |
| M4 grand, type de corps maximal (hauteur 1,05, type de corps 1) | **4,35 st (1,22 m)** | +0,35 st |

Bassin : 0,45 st au-dessus de l'assise pour la référence. Mains : 1,6 à 4,0 st du centre du volant (aucune animation
de conduite). Avant-bras : jusqu'à 0,31 st au-delà des flancs actuels.

### 3.2 Habitacles provisoires actuels [mesuré, `lune run tests/lune/tools/cabin-geometry.luau`, 2026-11-04]

Distance du dessus de l'assise au dessous du pavillon : **2,20 st** (Comète) à **4,00 st** (Atlas) ; Aster **3,11 st
(0,87 m)**. Tableau complet : `DIRECTION_ARTISTIQUE_VEHICULES.md` §2.

### 3.3 Exigences proposées

| Exigence | Valeur | Justification |
|---|---|---|
| Hauteur assise → pavillon, **minimum** | **≥ 4,30 st (1,20 m)** | référence 3,66 + cheveux 0,37 + marge 0,25 [hypothèse] |
| Hauteur assise → pavillon, **cible confort** | **≥ 5,00 st (1,40 m)** | grand type de corps 4,35 + cheveux 0,36 + marge 0,30 |
| Demi-largeur intérieure au niveau des épaules | ≥ demi-largeur actuelle + 0,35 st | dépassement mesuré 0,31 st + marge [hypothèse] |
| Dégagement jambes / planche de bord | ≤ 0,10 st de recouvrement pour la référence | recouvrements mesurés jusqu'à 0,60 st |
| Volant | position déduite d'un essai de pose (animation ou IK de conduite à décider) | mains actuellement hors du volant |
| Points de sortie | boîte libre ≥ 3 × 7,5 × 3 st (le plus grand avatar mesuré fait 7,09 st hors tout) | boîte actuelle 2,5 × 5 × 2,5 st |
| Vue cockpit | `CameraCockpit` placée pour la référence (tête 3,66 st), volant ≥ 10° sous la ligne de visée (QA-F15) | personnage masqué localement : validé 10/10 |

**Conflit à arbitrer [décision D1]** : ces hauteurs dépassent celles d'un habitacle aux proportions réelles (l'Aster
provisoire, proche des proportions de sa référence, offre 0,87 m ; la cible minimale demande 1,20 m), parce que les
avatars Roblox sont grands à l'échelle 0,28 m/stud (référence debout : 5,09 st = 1,43 m ; type de corps maximal : 6,78 st
= 1,90 m). Options :

1. **Habitacle « échelle Roblox »** : pavillon et vitrages plus hauts que la référence réelle, assise abaissée ; silhouette
   stylisée assumée (option recommandée pour la cible minimale) ;
2. **assise plus basse et inclinée** (siège baquet, pose de conduite personnalisée) : gagne de la hauteur sans changer la
   silhouette, exige une animation assise propre au jeu ;
3. **limiter le type de corps dans les véhicules** (réglages d'avatar de l'expérience) : contraire à l'objectif
   d'apparence conservée, à n'envisager que pour les extrêmes ;
4. combinaison 1 + 2 (proposée pour la cible confort).

**Décision du propriétaire (2026-11-04) : option 4, « échelle Roblox + assise basse ».** Conséquences [proposé] :

- pavillon et vitrages dessinés à l'échelle des avatars Roblox (au-delà des proportions réelles), assise abaissée et
  pose de conduite plus allongée pour limiter la hausse du pavillon ;
- cible de conception : **≥ 4,30 st** de l'assise au pavillon pour tous les modèles, **5,00 st** visés quand la
  silhouette le permet (SUV, tout-terrain, pick-up, compactes hautes) ;
- l'assise basse suppose une **pose assise propre au jeu** (animation ou réglage de la pose du moteur) : elle lie cette
  décision à **D3** ;
- aucune limitation du type de corps n'est retenue.

**Décision du propriétaire (2026-11-04), D3 : pose assise propre au jeu** (pas d'IK des mains). Conséquences [proposé] :

- une pose de conduite **originale** (aucune animation de la place de marché ni d'un autre projet), commune aux places
  conducteur et passager, avec une variante passager sans volant ; buste incliné en arrière, bassin bas, jambes
  allongées vers le pédalier, mains à 10 h 10 ;
- deux réalisations possibles, à départager par un essai en VM : animation assise jouée par le jeu au remplacement de
  l'animation `sit` du moteur (actif d'animation à publier **par le propriétaire**), ou pose procédurale appliquée par
  chaque client sur `Transform` des articulations, sur le modèle du bras du téléphone (QA-A10), sans actif ;
- le **volant et le pédalier se placent là où la pose met les mains et les pieds** : la pose est fixée d'abord (cotes
  relevées en VM sur les 8 morphologies du lot AVATAR-01), puis reportée dans le gabarit technique de chaque modèle ;
- les mains ne suivent pas la rotation du volant (pose fixe) ; un léger mouvement des bras au braquage est une
  amélioration possible, non retenue à ce stade ;
- validation : nouvelle mesure de la hauteur de tête assise (§3.1) avec la pose du jeu, distance mains-volant, pieds et
  jambes contre la planche de bord, sur les 8 morphologies.

## 4. Matériaux et textures

- Peinture : couleur de carrosserie personnalisable (`Appearance.BodyRgb` et préparation) → la peinture doit rester
  **teintable par le jeu** (couleur de MeshPart) ; l'usage de `SurfaceAppearance` sur les pièces peintes est à valider
  par un essai de teinte [hypothèse].
- Pièces non peintes (pneus, intérieur, chromes, plastiques) : `SurfaceAppearance` ou matériaux Roblox ; textures
  **originales** (aucune photo de référence utilisée comme texture).
- Aucune marque, aucun logo, aucune inscription réelle ; plaques et monogrammes **fictifs** d'Automotive World.

## 5. Niveaux de détail

| Niveau | Contenu | Bascule |
|---|---|---|
| LOD0 | modèle complet, intérieur détaillé | proche de la caméra |
| LOD1 | intérieur simplifié, détails fondus dans la carrosserie | distance moyenne |
| LOD2 | silhouette, vitrages opaques, roues simplifiées | loin |

Mécanisme : `RenderFidelity` des MeshParts et/ou bascule locale du dossier `Details` par `DetailLod` (déjà en place,
purement local, sans réplication) [hypothèse à valider].

## 6. Budget de performance mesurable

Le budget n'est **pas** fixé en nombre de polygones a priori : il découle d'essais.

| Mesure | Outil | Condition |
|---|---|---|
| Temps d'image client (moyen, 1 % le plus lent) | session VM `perf` (monde ouvert) | 1, 8, 16 et 24 véhicules visibles, de jour et de nuit |
| Mémoire graphique (maillages, textures) | statistiques du client Studio | mêmes scènes |
| Triangles par niveau de détail | export Blender + importeur de Studio | par modèle |
| Nombre de pièces et de textures uniques | comptage dans la place construite (Lune) | par modèle |
| Données répliquées | statistiques réseau de Studio | 24 véhicules en mouvement |

Critère d'acceptation proposé [décision D5] : avec 24 véhicules 3D visibles, temps d'image client **≤ référence actuelle
(primitives) + 2 ms** sur la VM, et aucune régression du réseau (les pièces soudées sans masse ne répliquent pas de
mouvement propre). Point de départ des essais [hypothèse] : LOD0 ≈ 15 000 à 25 000 triangles par véhicule, ≤ 3 textures
uniques de 1024 px ; à ajuster selon les mesures. Les limites d'import de Roblox (triangles par MeshPart, taille des
textures) sont à vérifier à la date de l'import.

## 7. Réseau et diffusion

- Physique inchangée : un seul assemblage simulé (châssis), visuels soudés sans masse ; les roues et le volant animés
  **localement** (aucune réplication par image).
- Monde ouvert : diffusion des modèles par la diffusion de Roblox ; pas d'actif chargé à la demande depuis un
  identifiant non inspecté.

## 8. Validation (voir `PIPELINE_BLENDER_ROBLOX.md` §6)

Lune (structure, noms, attributs, attaches, centres de roues), VM `avatar` (8 morphologies, deux places, sorties,
cockpit), VM `perf` (budget), VM `lot08` (banc des 18 modèles), captures inspectées, essai humain.
