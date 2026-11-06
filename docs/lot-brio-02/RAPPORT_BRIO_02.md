# Lot BRIO-02 — boîte automatique de la Brio (rupteur) et assise (têtes dans le pavillon)

| | |
|---|---|
| Date | 2026-11-06 |
| Branche | `claude/brio-02-boite-assise-6ffe29`, partie de `main` 6a54046 (lot AUDIO-01 fusionné) |
| Commit du code | `50015fe` (le rapport est commité à part) |
| Lot mené en parallèle de | AUDIO-03 et CAMERA-01 (exception accordée par le propriétaire le 2026-11-06), fichiers disjoints |
| Place de test du propriétaire | `build/AW-BRIO-02.rbxlx` (`rojo build default.project.json -o build/AW-BRIO-02.rbxlx`) |
| Statut | Code et tests automatiques au vert ; **rendu et comportement en jeu NON TESTÉS** (vérification par le propriétaire, §5) |

Aucun test VM n'a été lancé (règle du propriétaire depuis le 2026-11-05) ; aucune action sur le bureau ; aucune
publication Roblox ; rien n'est poussé.

## 1. Décisions du propriétaire (2026-11-06, questions posées en début de lot)

| Question | Choix | Appliqué |
|---|---|---|
| Correction du rupteur | **Décider la montée aussi sur le régime moteur** (recommandé) | `Transmission.autoShift`, §2 |
| Assise | **Sièges sur le vrai coussin + pose dédiée « Citadine »** (recommandé) | `MeshKitData`, `SeatPose`, §3 |
| Vue cockpit (calculée sur l'ancienne assise) | **Ne pas y toucher** (recommandé) | `CameraCockpit` inchangée (2,501) |

## 2. Travail 1 — boîte automatique : moteur collé au rupteur (QA-S04 du backlog audio)

### Constat et cause
Relevé de la vraie dynamique (banc planaire hors Roblox, pas de 1/240 s ; valeurs du banc, **pas** des performances
mesurées dans Roblox) : pied au plancher, la Brio restait à 7 200 tr/min (`LimiterRpm`) avant de monter le rapport.
`autoShift` décidait la montée sur le régime **côté roues** (turbine = ω roues × rapport global) comparé à
`ShiftUpRpm` (6 800) × facteur de charge. Convertisseur ouvert (1re et 2e ; pontage à partir de la 3e), le glissement
porte le moteur ~400 à 800 tr/min au-dessus de la turbine : il atteignait le rupteur bien avant que la turbine
n'atteigne 6 800, puis attendait que la voiture accélère (lentement en 2e).

### Correction (`src/shared/Vehicles/Physics/Transmission.luau`)
Boîte **automatique** seulement : la montée se décide aussi quand le **régime moteur** dépasse `ShiftUpRpm` × facteur
de charge, à condition que le régime côté roues du rapport suivant reste au-dessus de
`ShiftDownRpm` × facteur × `EngineUpshiftDownMargin` (1,1) — garde anti-pompage indépendante du glissement. La règle
existante (turbine) est conservée ; l'hystérésis garantie par `VehicleDefinitions.validate` est inchangée ; les
rétrogradages restent décidés sur le seul régime côté roues. Double embrayage, séquentielle, manuelle, CVT : non
concernés. Définition de la Brio **inchangée** (référence d'égalité `brio_definition_reference.json` non régénérée).

### Mesures avant / après (banc planaire, 2026-11-06)
Commande : `lune run tests/lune/tools/engine-sound-trace.luau <place> wk_brio <sortie.csv>` sur la place de `main`
6a54046 (avant) et sur la place de la branche (après), dépouillement par script (paliers ≥ 7 150 tr/min).

| Scénario « son » (plancher → 95 km/h, décélération, kickdown, freinage) | Avant | Après |
|---|---|---|
| Palier au rupteur en 1re | 0,525 s (5,671 → 6,196 s) | **aucun** |
| Palier au rupteur en 2e | 1,708 s (10,596 → 12,304 s) | **aucun** |
| Régime maximal | 7 204 tr/min | 6 803 tr/min |
| Montée 1→2 / 2→3 | 53,5 / 87,0 km/h | 46,5 / 75,2 km/h |
| 0–50 / 0–80 / 0–95 km/h | 4,17 / 8,92 / 12,66 s | 4,34 / 9,08 / 12,32 s |
| Rétrogradages 5→4, 4→3, 3→2 (kickdown), 3→2, 2→1 (freinage) | 46,59 ; 39,96 ; 39,69 ; 29,19 ; 20,81 km/h | 46,58 ; 39,98 ; 39,71 ; 29,20 ; 20,83 km/h (identiques) |

Accélérateur constant depuis l'arrêt, 40 s (script temporaire équivalent au test Lune n° 1-2 de `Brio02`, supprimé
après usage) :

| Gaz | Avant : passages (km/h) / rupteur | Après : passages (km/h) / rupteur | Rétrogradages |
|---|---|---|---|
| 0,30 | 1→2 à 37 / 0 s | 1→2 à 35 / 0 s | 0 / 0 |
| 0,50 | 42, 67 / 0 s | 38, 61 / 0 s | 0 / 0 |
| 0,70 | 46, 75, 105 / 0 s | 41, 66, 105 / 0 s | 0 / 0 |
| 0,85 | 50, 81, 113 / 0 s | 44, 70, 113 / 0 s | 0 / 0 |
| 1,00 | 53, 87, 121 / **1,708 s** | 47, 75, 121 / 0 s | 0 / 0 |

Pas de pompage ; les passages pontés (3→4) sont inchangés. Effet sur les autres jeux d'essai (valeurs informatives de
la suite Lune, place de `main` contre place de la branche) : seule l'automatique P-01 bouge — 0–100 km/h 8,67 → 8,78 s,
démarrages sur faible adhérence 0–50 km/h (AWD, μ 0,35) 5,10 → 5,28 s, 0–40 km/h (μ 0,15) 21,22 → 20,97 s
(ouvert) et 6,02 → 5,93 s (autobloquant), rapport de lacet en virage 2,52 → 2,50 (RWD) et 0,52 → 0,54 (FWD).
Manuelle, double embrayage, séquentielle, CVT et électrique : valeurs identiques.

Conséquence pour le son (lot AUDIO-01) : pied au plancher, la Brio monte désormais à 6 800 tr/min au lieu de tenir
le rupteur ; le son du rupteur ne s'entend plus en accélération normale.

## 3. Travail 2 — assise de la Brio : têtes et cheveux à travers le pavillon

### Cause trouvée (mesure)
Coupes de l'habitacle par rayons, Blender 4.5.9 **sans interface et en lecture seule** (le `.blend` n'est pas
enregistré ; `git status` du dépôt d'art vide après coup), le 2026-11-06 :

```
blender --background --factory-startup --disable-autoexec <aw-art-citadine>/vehicles/wk_brio/blend/wk_brio_milano95.blend \
    --python docs/lot-brio-02/sonde_habitacle_brio.py -- docs/lot-brio-02/sonde_habitacle_brio.json
```

Le siège du modèle « Milano '95 » n'a pas de coussin plat distinct du dossier. Le relevé du lot VEH3D-02
(2026-11-05), fait par un seul rayon vertical en (x ∓1,2 ; z 1,55), tombait sur le **dossier incliné** (y 0,618) et
non sur le coussin : la place du jeu était ~0,95 st trop haute et trop en arrière. Le « plancher » relevé alors
(y −0,29 entre z −0,25 et 1,25) était en fait le coussin. Il restait 2,48 st entre cette fausse assise et le pavillon
(Comète : 3,34) : les têtes ne pouvaient pas tenir.

Habitacle mesuré (place conducteur x −1,2 ; passager à 0,015 st près ; détail dans `sonde_habitacle_brio.json`) :

| Élément | Mesure |
|---|---|
| Coussin | y −0,26 (bord avant, z −0,2) à −0,41 (pied du dossier, z 1,21) ; −0,353 en z 0,75 (passager −0,368) ; x −2,1 à −0,4 |
| Dossier | pied (y −0,41 ; z 1,21) → haut y 1,96 vers z 2,05 ; incliné de 20 à 28° |
| Plancher des pieds | y −0,88 à −0,90 entre z −0,3 et −2,1 ; tablier et pédalier vers z −2,2 à −2,4 |
| Dessous de planche de bord | y 0,80 (z −0,5) à 0,15 (z −2,0) |
| Volant | x −1,80 à −0,53 ; y 0,59 à 1,80 ; z −0,42 à 0,12 |
| Dessous du pavillon | 3,06 (z 0,8) → 3,10 (z 1,2) → 3,15 (z 1,8) ; 2,84 au bandeau avant (z 0,6) |

### Correction
- `src/shared/Vehicles/MeshKitData.luau` (`wk_brio`) : `SeatDriver` (−1,2 ; −0,553 ; 0,75) et `SeatPassenger`
  (1,2 ; −0,568 ; 0,75) — dessus d'assise sur le coussin mesuré, centre de la pièce Seat 0,2 st plus bas, à 0,48 st du
  dossier (Comète : 0,59 ; dossier plus incliné ici, et pieds du plus grand avatar gardés en deçà du pédalier) ;
  `Footwell` = { FloorY −0,88 ; z −2,1 à −0,3 } ; `RoofUnderside` 3,10 conservé (au droit de z 1,2, soit 3,45 st
  au-dessus de la nouvelle assise) ; `SeatPoses` = « Citadine » / « CitadinePassager » ; `CameraCockpit` inchangée.
  Les invites d'embarquement (portes) suivent le z de la place : elles avancent de 0,8 st.
- `src/shared/Vehicles/SeatPose.luau` : pose **Citadine** = pose Sportive de la Comète (mesurée en VM) avec bassin
  enfoncé de 0,28 st (au lieu de 0,18) et genoux à 50° (au lieu de 56°) ; buste 31°, cou −20°, cuisses 4° et bras
  vers le volant (conducteur) inchangés. Comète, Aster et carrosseries provisoires : non concernées.

### Raisonnement géométrique (estimations, NON VÉRIFIÉES EN JEU)
Base : mesures VM de la pose Sportive sur la Comète (tâche `20261105-023349`, 8 morphologies R15, buste 31°),
rapportées au dessus d'assise. Le décalage du bassin est une translation pure (tête et pieds descendent de 0,10 st).
L'effet des genoux est estimé entre 0,02 et 0,04 st par degré (écart entre les essais VM de la Comète), soit 0,13 à
0,24 st plus bas pour 6°. Le haut de tête mesuré est celui de la pièce `Head`, **sans les cheveux**.

| Morphologie (session VM `avatar`) | Haut de tête estimé (y) | Marge sous le pavillon (3,10 à 3,15) | Dessous des pieds estimé (y ; plancher −0,88) |
|---|---|---|---|
| M1 référence | 2,78 | 0,32 à 0,37 | −0,68 à −0,79 |
| M2 petit et mince | 2,48 | 0,62 à 0,67 | −0,75 à −0,86 |
| M3 grand classique (le plus haut) | 2,85 | 0,25 à 0,30 | −0,69 à −0,80 |
| M4 / M7 type de corps maximal | 2,50 | 0,60 à 0,65 | −0,70 à −0,81 |
| M5 grand élancé | 2,19 | 0,91 à 0,96 | −0,79 à −0,90 |
| M6 petit et large | 2,64 | 0,46 à 0,51 | −0,65 à −0,76 |
| M8 accessoires volumineux | 2,78 | 0,32 à 0,37 | −0,68 à −0,79 |

Avec l'ancienne assise (y 0,618), cette même pose aurait placé le haut de tête de M3 vers y 3,8, ~0,7 st au-dessus du
pavillon : c'est ce que montrait la capture du propriétaire. Pieds estimés entre 0,02 st sous le plancher (M5, au
pire) et 0,23 st au-dessus (Comète mesurée : 0,07 à 0,21 st au-dessus) ;
pointes de pied estimées entre z −1,7 (M1) et −2,4 (M4, au pédalier). Limites : les cheveux volumineux ajoutent
~0,2 à 0,4 st à la pièce `Head` (non mesuré) ; un chapeau haut (M7, 2,6 st) traversera, comme décidé pour l'Aster.

## 4. Tests automatiques exécutés (2026-11-06)

| Commande | Résultat |
|---|---|
| `scripts\verify.ps1 -DownloadRobloxTypes` (00:39:51 → 00:40:13) | **Tout OK** : Rojo, Selene, pilote Studio, StyLua, Lune **416 réussis / 0 échoué**, carte du monde, place monde ouvert, pytest 23, luau-lsp strict 0 erreur (3 avertissements d'API dépréciée préexistants, hors lot) |
| `rojo build default.project.json -o build/AW-BRIO-02.rbxlx` | Place construite (00:40) |

Nouvelle suite Lune `tests/lune/specs/Brio02.luau` (6 tests, enregistrée en fin de `tests/lune/run.luau`) :
plus de palier au rupteur > 0,1 s et rapports 1→2→3→4 dans l'ordre (plancher) ; ni pompage ni rupteur à 0,3-0,85
de gaz ; règle moteur réservée à l'automatique, garde anti-pompage, double embrayage inchangé ; définition de la Brio
valide et inchangée ; places sur le coussin mesuré, plancher 0,45-0,6 st sous l'assise, pavillon ≥ 3,4 st au-dessus ;
pose Citadine (bassin plus bas, genoux moins tendus, buste conservé, Comète inchangée).
Suite `Veh3d02Brio` : le contrôle « assise au-dessus de la coque » (fondé sur l'ancienne fausse assise) devient
« places dans la caisse » (boîte de la coque ou de l'habitacle).

## 5. Liste de vérification en jeu (propriétaire, place `build/AW-BRIO-02.rbxlx`)

Boîte automatique (Brio) — compte-tours et son :
1. Arrêt, pied au plancher : le moteur monte vers ~6 800 tr/min et passe la 2e **sans rester collé au rupteur**
   (plus de « rebond » du rupteur ni de son de coupure en 1re).
2. Même chose en 2e → 3e (vers 75 km/h, banc) : pas de palier au rupteur.
3. Accélération douce (mi-gaz) : passages plus tôt et sans aller-retour (pas de pompage 2↔3).
4. Rétrogradages : en décélérant puis en ré-accélérant franchement vers 40 km/h, la boîte rétrograde (kickdown) comme
   avant ; au freinage jusqu'à l'arrêt, descente 3→2→1 sans à-coup anormal.
5. Conduite générale : démarrage, marche arrière (maintien de « freiner » à l'arrêt), croisière ; rien d'inhabituel.
6. Comète (séquentielle) : inchangée (contrôle rapide).

Assise (Brio) — vérifier avec **plusieurs avatars** (le vôtre, un grand, un petit, des cheveux volumineux) :
7. Conducteur, vue extérieure : la tête et les cheveux restent **sous le toit** (aucune mèche visible sur le toit).
8. Passager : idem.
9. Personnage assis **dans** le siège (bassin dans le coussin, dos le long du dossier), pas en lévitation ni en
   arrière du dossier.
10. Pieds : posés sur le plancher ou juste au-dessus, sans traverser le plancher ni le dessous de caisse ; pointes de
    pied pas au travers du tablier (grand avatar).
11. Mains du conducteur vers le volant (pas au travers du pare-brise ni du toit) ; genoux sous le volant.
12. Invites « Monter (conducteur/passager) » : toujours au niveau des portes (elles ont avancé de 0,8 st), montée et
    descente normales des deux côtés.
13. Vue cockpit : inchangée (personnage masqué), comme avant.

À signaler si un point échoue : avatar utilisé, place, capture ; les réglages se font par deux valeurs (bassin
`Root.Down`, genoux `Knee`) de la pose Citadine, ou par la hauteur/z des places dans `MeshKitData`.

## 6. Non vérifié, écarts et remarques

- **NON TESTÉ en jeu** : tout le comportement de la boîte dans Roblox (le banc planaire n'est pas le moteur
  physique de Roblox) et toute la pose (positions de tête, cheveux, pieds, mains : estimations du §3).
- Cheveux et accessoires de tête : non mesurés (la mesure VM de référence porte sur la pièce `Head`).
- Comète : ses marges de tête mesurées en VM portent aussi sur la pièce `Head` seule (M3 : 0,04 st) ; des cheveux
  pourraient y effleurer le pavillon. Non examiné ici (hors périmètre) ; à surveiller.
- Vue cockpit de la Brio : yeux à y 2,501, soit ~2,85 st au-dessus de la nouvelle assise (règle du jeu : 2,45) ;
  conservée par décision du propriétaire.
- Le dépôt d'art (`finition.json`, `milano95_finish.py`) garde l'ancienne mesure d'assise et de plancher ; il n'est
  pas modifié par ce lot (dépôt distinct). À corriger lors d'un prochain passage sur le modèle.
- `docs/QA_BACKLOG.md` (non modifié, fichier partagé) : l'identifiant **QA-S04** y est employé deux fois (streaming,
  ligne 118, et rupteur de la Brio, ligne 348). La ligne 348 est à passer à « corrigé, à vérifier en jeu » à la
  fusion.
- `tests/lune/run.luau` : CAMERA-01 ajoute aussi une ligne après `Audio01` ; conflit trivial à la fusion (garder
  les deux lignes).

## 7. Fichiers

| Fichier | Nature |
|---|---|
| `src/shared/Vehicles/Physics/Transmission.luau` | Montée sur le régime moteur (automatique), `EngineUpshiftDownMargin` |
| `src/shared/Vehicles/MeshKitData.luau` | Places, plancher, pavillon et poses de la Brio |
| `src/shared/Vehicles/SeatPose.luau` | Poses Citadine / CitadinePassager |
| `tests/lune/specs/Brio02.luau`, `tests/lune/run.luau` | Nouvelle suite (une ligne en fin de liste) |
| `tests/lune/specs/Veh3d02Brio.luau` | Contrôle des places adapté |
| `docs/lot-brio-02/RAPPORT_BRIO_02.md` | Ce rapport |
| `docs/lot-brio-02/sonde_habitacle_brio.py`, `sonde_habitacle_brio.json` | Sonde Blender en lecture seule et son relevé |

## Validation du propriétaire (2026-11-06)

Le propriétaire a testé la place `build/AW-BRIO-02.rbxlx` dans Studio et a répondu « Les deux sont bons » (BRIO-02 et
CAMERA-01). La liste du §5 est validée. Il s'agit d'un essai humain du propriétaire : aucun essai Studio n'a été
exécuté par l'assistant.

