# VEH3D-01 — rapport de finalisation de la Comète 3D

Branche `feat/veh3d-01-comete`, PR #16 (brouillon, non fusionnée) ; reconstruite sans ASTER-02 dans
`feat/veh3d-01-comete-v2` le 2026-11-05 (option B de `docs/audit/AUDIT_INTEGRATION_V1.0.md`, code identique). Rapport du 2026-11-05, rédigé à la demande du
propriétaire (« priorité officielle V1.0 » : finaliser la Comète, puis les interfaces). Physique et modèle 3D intégré
conservés. Seule la Comète est essayée (demande du propriétaire du 2026-11-05 : pas les 18 modèles).

Une réussite des tests automatisés ne remplace pas la revue visuelle du propriétaire. **Rien n'a été envoyé ni publié
sur Roblox par l'assistant.**

## 1. Vérifications exécutées

| Vérification | Commande | Date, tâche | Résultat |
|---|---|---|---|
| Statique | `scripts\verify.ps1 -RobloxTypes .tooling\globalTypes.d.luau` | 2026-11-05 | toutes les étapes OK ; Lune 373 / 373 ; luau-lsp strict OK |
| Comète complète | `test-vm.cmd -Sessions comete -GuiInput` | `20261105-013629` | 86 réussis, 2 échecs : touche Ctrl, compte des captures en session perf (corrigé) |
| Pose « Sportive » | idem | `20261105-020557`, puis `20261105-020940` | 68 réussis, 1 échec (Ctrl) ; pieds posés sur le plancher (§3.E) |
| Performances | `-Sessions comete_perf` | `20261105-013629` | triangles et appels de dessin mesurés ; temps de rendu non mesurables (§3.D) |
| Morphologies R15 | `-Sessions comete_avatar` | `20261105-015804`, puis `20261105-023349` | 16 sorties sur 16 en échec avant correction ; après : sorties 16 / 16, pose de jeu 16 / 16 (§3.E) |
| Contrôle final | `-Sessions comete_avatar,comete -GuiInput` | `20261105-023349` | **189 réussis, 1 échec (touche Ctrl)** |
| Choc avant intermittent | `-Sessions comete` | `20261105-024819`, puis `-025226` et `-025503` | non confirmé 1 fois sur 7 ; après correction : 3 / 3 (`-025226`, `-025503`, `-030115`), 0 choc écarté |
| Revue du propriétaire | Studio, son poste | 2026-11-05 | « tout fonctionne correctement » (`VEH3D_01_REVUE.md`) |
| 2 joueurs | `-Sessions comete2` | `20261105-015804` | contrôles de réplication tous réussis ; 1 échec du compte des captures du conducteur (corrigé) |
| Vitrage | `-Sessions comete_vitres`, puis `comete` | `20261105-003353`, `20261105-005339` | réglage C retenu et vérifié |

Limite de l'environnement, constante : la touche **Ctrl n'arrive jamais au jeu** dans Studio. La marche arrière est
donc engagée par l'appel de test du contrôleur, ce qui est signalé dans chaque rapport.

## 2. Anomalies trouvées et corrigées

| Anomalie | Cause | Correction | Vérifiée |
|---|---|---|---|
| Bloc gris opaque devant le nez après un choc de niveau 2 | `DamageService` copiait la boîte de collision invisible du bouclier | boîtes du kit marquées `AWCollisionOnly`, jamais copiées | VM : aucun bloc opaque après 2 chocs |
| Vitres latérales noires de l'extérieur | réglage du jeu (verre 28/32/38, 0,45) ; ce n'était pas une texture peinte (affirmation d'abord fausse, corrigée) | réglage C : Glass 120/135/145, 0,6 | VM `20261105-005339` |
| Optique cassée rallumée la nuit | l'éclairage remettait le néon à chaque passage | attribut `AWLightBroken`, éclairage éteint | VM : 4 optiques cassées, 0 allumée |
| Aucun feu stop dans le jeu | freinage non répliqué | attribut `VisualBrake` publié par le serveur (comme le braquage) | VM : solo et joueur 2 |
| Marques de dégâts cachées dans la caisse | placées d'après les cotes de la carrosserie provisoire | surface visible mesurée dans Blender (`DamageMarks`) | VM : 15 marques, captures |
| Pieds sous le plancher et sous la caisse | assise de la Comète très basse (coussin à 0,28 st du plancher) | pose « Sportive » propre à ses sièges, réglée par mesures successives | VM : 8 morphologies, pieds posés, têtes sous le pavillon mesuré |
| Choc avant à 42 km/h parfois non confirmé (1 passage sur 7) | recherche d'obstacle aux cotes du châssis (±8,13 st, marge 1,2) alors que le bouclier du kit va à 8,83 st : mur peut-être hors de la boîte après le rebond (cause probable, non démontrée) | recherche étendue aux boîtes de collision du kit | VM : 3 passages sur 3, 0 choc écarté |
| Voiture qui ne roule pas en revue | boîte séquentielle au neutre, touche Maj attendue | l'accélérateur engage le 1er à l'arrêt (décision du propriétaire) | Lune (test 10) ; VM `20261105-030115` : W seul, 1er engagé au premier essai |
| Sorties : conducteur couché, passager sur le toit (16 sur 16) | l'occupant assis est dans le volume de collision de l'habitacle ; libéré, il en était expulsé | groupe de collision `AWSortie` (sans collision avec les véhicules) de l'assise au placement ; passager placé côté droit (QA-A15) ; accord du propriétaire | VM : 16 sorties sur 16 |

## 3. État par point demandé

### A. Carrosserie et matériaux

- **Couleurs du garage** : prêtes dans le code, **inactives**. La teinte passe par `SurfaceAppearance.Color`, qui
  multiplie la carte de couleur ; sur la carte d'origine (zone orange), on n'obtiendrait que des orange plus sombres.
  Une carte neutre a été préparée (dépôt d'art `c4ffd34`) : zone de peinture gris clair, lignes de carrosserie
  conservées, étriers inchangés. Aperçus Blender (origine, blanc, bleu, jaune) : `vehicles/wk_comete/renders_peinture/`.
  Elle s'active automatiquement dès que le gabarit porte cette carte (identifiant à inscrire dans
  `MeshKitData.Paint.NeutralColorMap`). **Action du propriétaire : envoi** (§5).
- **Finition** (brillant, métallisé, mat, nacré) : choisie dans le garage, appliquée à **aucun** véhicule du jeu
  aujourd'hui, carrosseries provisoires comprises. Écart antérieur au lot, non traité.
- **Vitrage** : réglage C, conservé. **Textures** : inchangées (aucune dégradation).
- **Jour et nuit** : captures de jour et de nuit faites.

### B. Phares et feux

- Feux stop : faits (renforcement ×3 des sources arrière pendant le freinage, de jour comme de nuit), répliqués.
- Phares et feux arrière la nuit : 4 sources sur 4 sur une Comète neuve.
- **Le maillage des feux ne s'illumine pas** : les feux ne sont pas séparés dans le `.rbxm` envoyé. Le code pose déjà
  `AWLight` sur `COMETE_Feu_Av` et `COMETE_Feu_Ar` s'ils sont présents. **Action du propriétaire : envoi** (§5).
- Feux de recul : non représentés (le frein maintenu à l'arrêt enclenche la marche arrière, A3, et allume les stops).

### C. Dégâts

- Dégâts mécaniques conservés : moteur 0,32 à 0,38 après le choc avant, voyant « moteur endommagé ».
- Visuels adaptés aux MeshParts : rayures, enfoncements sombres, déformations larges, **posés sur la surface mesurée** ;
  optiques éteintes ; fumée moteur. Aucun bloc de collision visible.
- **Limite** : le maillage n'est pas découpé par panneau. Aucune pièce ne peut donc se déformer, et les marques
  ressemblent à des pièces sombres rectangulaires (capture `comete_degats_avant_gros_plan`). Solution robuste proposée :
  découper boucliers, capot et portes dans Blender, puis faire basculer ou enfoncer ces pièces comme les panneaux
  provisoires. Cela demande un envoi (§5) : **à décider**.
- Choc latéral : non couvert. La validation anti-éjection limite à 3 m/s un véhicule vide lancé par le serveur ; un
  choc latéral demande un second véhicule conduit.

### D. Optimisation

| Véhicules | Triangles P-01 / Comète (jour) | Appels de dessin P-01 / Comète |
|---|---|---|
| 1 | 6 408 / 19 130 | 31 / 64 |
| 8 | 20 135 / 68 123 | 42 / 68 |
| 16 | 29 015 / 124 115 | 50 / 72 |
| 24 | 37 991 / 180 107 | 58 / 76 |

- La Comète coûte environ **7 000 triangles par véhicule**, sous l'hypothèse de 25 000 du LOD0. Les appels de dessin
  restent faibles : maillages et textures sont partagés.
- **Temps de rendu : non mesurables dans la VM.** `RenderCPUFrameTime` et `RenderGPUFrameTime` y valent 0, et le temps
  d'image reste collé au plafond de 60 images/s. **Le budget D5 (+2 ms à 24 véhicules) n'est ni validé ni invalidé** :
  il faut une mesure sur un poste réel.
- **LOD1 et LOD2 : non intégrés.** Ils sont prêts dans le dépôt d'art (4 364 et 2 257 triangles), mais doivent être
  envoyés sur Roblox. Vu le faible coût mesuré, ils ne sont pas indispensables tant que D5 n'est pas mesuré ; la
  bascule de LOD automatique de Roblox reste active.

### E. Avatars et interactions

- **Embarquement réel** : vraie touche E maintenue (invite « Conduire », 0,3 s), réussi.
- **Téléphone** : au volant (vraie touche T, ouvert puis refermé) ; avec les 8 morphologies, debout et en passager
  (bras levé, téléphone en main).
- **Caméras** : cockpit, capot et bouclier atteints par la vraie touche V ; avatar masqué en vue cockpit.
- **Morphologies R15** (8, représentatives et extrêmes), avec la pose standard du moteur mesurée par le serveur :
  16 assises sur 16 ; rien ne traverse les flancs ; jambes libres sous la planche de bord ; assise sans enfoncement.
- **Pose de jeu « Sportive »** (nouvelle, sièges de la Comète seulement : bassin enfoncé de 0,18 st, buste incliné
  de 31°, cuisses à 4°, genoux à 56°), mesurée **par le client** pour les 8 morphologies, conducteur et passager
  (tâche `20261105-023349`) : 16 / 16.
  - Dessous des pieds entre −0,85 et −0,71 st, donc au-dessus du plancher mesuré (−0,92), sur le pédalier.
  - Haut de la tête entre 2,05 et 2,66 st, donc sous le dessous du pavillon mesuré dans Blender (2,71 à 2,73 st ;
    marge de contrôle 2,70).
  - Avatar du compte de test : mains à |x| 1,73 et 2,24 (flanc 3,49).
  - Le critère serveur « pieds dans l'habitacle » mesure la pose standard du moteur, que le serveur voit seul ; il est
    gardé pour information.
- **Sorties : corrigées** (accord du propriétaire du 2026-11-05).
  - Cause : l'occupant assis se trouve dans le volume de collision de l'habitacle. Libéré, le moteur physique l'en
    expulsait : conducteur couché, passager sur le toit.
  - Correction **générique** : l'occupant passe dans le groupe de collision `AWSortie`, sans collision avec les
    véhicules, de l'assise jusqu'à son placement vérifié ; son groupe d'origine lui est ensuite rendu. Garde-fous :
    personnage détruit, ou debout 3 s sans placement ; la protection d'arrivée n'est jamais rendue. Le passager est
    placé côté droit (QA-A15).
  - Vraies touches F et Espace : **conducteur 8 / 8, passager 8 / 8** (avant : 0 / 16).
  - Essayé sur la Comète seule. Les autres modèles utilisent le même code, mais n'ont pas été essayés à la demande du
    propriétaire.
- **Réplication à 2 joueurs** : le joueur 2 reçoit les 28 maillages, voit la jante tourner, le braquage (pneu 30°) et
  les feux stop, et voit la tête du conducteur. Les commandes du joueur 1 sont instrumentées.

### F. Crédits et licence

- Écran **Téléphone › Paramètres › Crédits et licences** (FR et EN) : auteur, plateforme, licence CC BY 4.0 et son
  adresse, modifications. Données dans `Shared/Assets/Attributions`, avec un contrôle Lune : toute entrée CC BY du
  manifeste a son attribution.
- **Affichage non vérifié par une capture.** Il faudra une revue humaine ou une session d'interface.
- **Décision du propriétaire** : afficher ou non le **titre** (« 2017 Mclaren 720s ») et le **lien** de l'œuvre.
  CC BY 4.0 demande le lien « dans la mesure du raisonnable » et ne rend pas le titre obligatoire. Le titre contient un
  nom de marque, et les règles de Roblox encadrent les liens externes. Les deux sont masqués par défaut ; le texte
  complet reste dans `docs/CREDITS_ACTIFS.md`.
- **Risque commercial, signalé à part** : la Comète **reproduit la forme d'un modèle commercial existant**, même sans
  logo ni nom. Le dessin d'une carrosserie peut être protégé (dessins et modèles, habillage), indépendamment de la
  licence CC BY du maillage, qui ne couvre que le travail de l'auteur du modèle 3D. Le jeu n'est pas monétisé (décision
  du propriétaire), mais ce risque n'est pas levé. À arbitrer avant toute publication, éventuellement avec un avis
  juridique.

## 4. Limites restantes

Choc latéral ; dégâts sans déformation de pièce ; feux non lumineux ; peinture non personnalisable ; LOD1 et LOD2 non
intégrés ; D5 non mesuré ; sorties corrigées mais non essayées sur les 17 autres modèles ; écran de crédits sans
capture ; finition du garage appliquée à aucun véhicule ; essai humain.

## 5. Actions du propriétaire

| Action | Pourquoi | Préparé |
|---|---|---|
| **Envoi groupé** des maillages et textures sur Roblox, puis `.rbxm` dans `aw-vm-exchange` | feux lumineux, peinture du garage, éventuellement LOD et panneaux de dégâts | carte neutre `c4ffd34`, feux séparés `195df9b` ; LOD1/LOD2 et panneaux à exporter si retenus |
| Décider : LOD1/LOD2 dans l'envoi ? | coût mesuré faible | export prêt à faire |
| Décider : panneaux de dégâts déformables ? | marques actuelles rectangulaires | découpe Blender à faire |
| Décider : titre et lien dans les crédits | conformité CC BY et règles Roblox | bascule `ShowTitle` / `ShowUrl` |
| Revue visuelle et conduite | **faite le 2026-11-05** (« tout fonctionne correctement », points non notés un par un) | `VEH3D_01_REVUE.md` |
| Mesure D5 sur un poste réel | la VM ne fournit pas les temps de rendu | session `comete_perf` réutilisable |
| Arbitrer le risque lié au dessin commercial | §3.F | — |

## 6. Recommandation

**Revue faite le 2026-11-05 : « tout fonctionne correctement ». GO pour la clôture de VEH3D-01**, envoi groupé et crédits
reportés par le propriétaire (`VEH3D_01_REVUE.md`). Recommandation initiale : GO pour la revue ; clôture possible après elle. Le code est complet et testé dans le périmètre qui
ne demande pas d'envoi d'actifs ; les sorties sont corrigées (16 / 16) ; le contrôle final donne 189 réussis sur 190
(le seul échec est la touche Ctrl, limite de Studio). Avant de clôturer :
1. ta revue visuelle et une conduite ;
2. ta décision sur l'envoi groupé (feux lumineux, peinture), ou l'acceptation de ces limites pour cette version ;
3. ta décision sur le titre et le lien des crédits, et sur le risque lié au dessin commercial.

État au moment de la rédaction : le chantier UI PREMIUM V1.2 n'était pas commencé. Il a été mené ensuite
(`docs/ui/UI_V1_2_FINALISATION_RAPPORT.md`).
