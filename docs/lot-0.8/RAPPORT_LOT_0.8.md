# Rapport du lot 0.8 — direction artistique, gamme, audio, radio, mode photo et arrivée

Branche `feat/art-audio-onboarding-0.8`, créée depuis `f48e886` (dernier commit du lot 0.7), PR brouillon vers
`feat/ui-gps-social-0.7`. Aucune branche précédente ni `main` n'a été modifiée ; aucune PR n'a été fusionnée.

Décision du propriétaire (lots 0.3 et suivants) : pas de grande campagne QA. Ce lot comporte les contrôles
automatiques, des tests purs ciblés et de courtes sessions de démarrage dans la VM. **Aucun essai humain n'a été
fait : le rendu, les sons, la radio en multijoueur, le mode photo et le parcours d'arrivée ne sont pas validés en
jeu** (`docs/QA_BACKLOG.md` §3 sexies). Aucune publication Roblox, aucun téléversement, aucun achat d'actif.

## 1. État des livrables

Légende : **Fonctionnel** (livré, règles testées hors Studio, branché en jeu) ; **Provisoire** (livré mais à
remplacer ou valider) ; **Proposé** (en attente d'approbation du propriétaire) ; **Non implémenté** ; **NON TESTÉ**
(aucune exécution en jeu de la fonction). La plupart des lignes combinent un état de livraison et NON TESTÉ.

| # | Livrable | État | Précisions |
|---|---|---|---|
| 1 | Pipeline et manifeste d'actifs | Fonctionnel | `AssetManifest` : 52 entrées, identifiants stables, variantes, LOD, provenance, licence, statut ; **aucun identifiant Roblox** (rien de téléversé) ; sources vérifiées par pytest |
| 2 | Direction artistique documentée | Provisoire | `DIRECTION_ARTISTIQUE.md`, valeurs dans `ArtDirection` ; validation artistique humaine NON TESTÉE |
| 3 | Catalogue de 18 modèles fictifs détaillés | **Proposé** | `CATALOGUE_18_VEHICULES.md` ; fiches FR/EN ; statut `PendingApproval`, jamais présentés comme des références commerciales |
| 4 | Trois véhicules de départ proposés | **Proposé** | Brio, Fil, Aster avec comparatif ; liste officielle `StarterCatalog.Candidates` **toujours vide** ; candidats utilisables en développement seulement (exemplaire synthétique) |
| 5 | Intégration au moteur physique et aux concessions | Fonctionnel (Dev) | 18 définitions validées au chargement ; 18 entrées commerciales liées ; achat en développement seulement. Comportement en jeu des 18 NON TESTÉ (banc planaire seulement) |
| 6 | Géométrie et intérieurs | Provisoire | 10 silhouettes construites par code (`BodyKits`), habitacle simplifié, place passager ; aucun maillage ni texture ; rendu NON TESTÉ |
| 7 | Amélioration des sept zones | Provisoire | 3 998 accessoires d'habillage générés hors ligne (aucune construction au démarrage), LOD client, lampadaires ; rendu NON TESTÉ |
| 8 | Système audio automobile | Provisoire — **contrôleurs seulement** | Couches thermiques (4) et électriques (3), régime et charge, véhicules observés limités ; 30 sons originaux synthétisés mais **non téléversés : rien n'est joué en jeu**. Signature sonore par modèle, revêtement, acoustique (tunnels, garages, cabine), perspective caméra : **non implémentés** |
| 9 | Radio et réglages individuels | Fonctionnel (règles), stations indisponibles | Station choisie par le conducteur (serveur), volume et coupure par occupant, aucune diffusion extérieure ; les trois stations restent **indisponibles** tant que leurs pistes originales ne sont pas téléversées |
| 10 | Ambiances et notifications sonores | Provisoire — contrôleurs seulement | Boucles par zone, pluie, vent ; signal par niveau de notification ; muets sans téléversement ; l'alerte reste toujours visuelle |
| 11 | Mode photo | Fonctionnel (règles), NON TESTÉ en jeu | Contextes, caméra bornée et tronquée aux obstacles, zoom, exposition, profondeur de champ, 6 filtres, masquage de l'interface, restauration exacte, clavier et manette, capture `CaptureService`. Passager en mouvement : **non implémenté** (refusé). Galerie propre au jeu : **non implémentée** (galerie Roblox proposée) |
| 12 | Onboarding (11 étapes) | Fonctionnel (Dev), NON TESTÉ en jeu | Protection d'apparition, introduction passable, univers, commandes, téléphone/carte/GPS, présentation des 3 candidats, essai facultatif protégé, confirmation explicite, attribution unique (transaction serveur), propriété gratuite unique, accès au monde |
| 13 | Exercices de formation | Fonctionnel (règles), NON TESTÉ en jeu | 8 exercices facultatifs, rejouables, sans crédit ni réparation ; mission professionnelle garantie du lot 0.5 inchangée |
| 14 | Finition des interfaces | Partiel | Nouveaux écrans au thème commun, focus manette, applications Radio, Photo, Guide, page Graphismes, conflit de touche manette corrigé. Reprise visuelle systématique des interfaces 0.4–0.7 (typographie, espacements, animations, icônes) : **non faite** |
| 15 | Localisation essentielle FR/EN | Fonctionnel (clés), relecture humaine NON TESTÉE | Textes du lot (`Texts08`) ; 241 appels `tr()` dans les panneaux Garage, Économie et Courses (370 traductions, dont libellés serveur) ; changement de langue à chaud |
| 16 | Vérifications techniques | Fait | §2 |
| 17–20 | Rapport, architecture, ressources et licences, catalogue | Fait | `docs/lot-0.8/` (+ direction artistique) |
| 21–22 | Registre QA, feuille de route | Fait | `QA_BACKLOG.md` §3 sexies (QA-V01 à V14) ; `ROADMAP.md` |
| 23 | PR brouillon et SHA | Fait | §2.4 |

Options de performance : qualité graphique (habillage, détails, sources de lumière, effets, couches sonores),
sons simultanés limités, réutilisation des sons par véhicule, streaming conservé. Les objectifs de 24 joueurs et
≈ 60 images/s **ne sont pas déclarés atteints** (aucune mesure).

## 2. Vérifications exécutées

### 2.1 Hors Studio

Tests du lot (`tests/lune/specs/Lot08Content.luau`, 17 tests ; `tests/test_lot08.py`, 4 tests) :

| Cas demandé | Résultat |
|---|---|
| Intégrité des 18 fiches | OK : identifiants `wk_*` uniques, données positives, empattement < longueur, catégorie et description FR/EN |
| Compatibilité des définitions physiques | OK : 18 validations ; silhouette, énergie et boîte conformes ; démultiplication ≥ 99 % de la vitesse annoncée (le test a révélé la Cadence plafonnée à 194 km/h pour 215 annoncés : corrigée, ainsi que Comète et Zénith) |
| Cohérence des identifiants du catalogue | OK : 18 entrées liées à une définition existante, emplacements uniques, prix et concession, aucune entrée « Official » |
| Séparation actifs provisoires / officiels | OK : achat en Dev seulement (refusé en test et production), liste officielle vide, aucun actif « Validated » |
| Conditions du choix du starter | OK : 3 candidats en Dev (synthétiques), aucun en test et production (`StarterCatalogUnavailable`), hors liste refusé |
| Attribution unique du starter | OK : second choix refusé (`StarterAlreadyChosen`), un exemplaire, incessible, synthétique ; parcours avancé après la transaction (unicité multisession : test du lot 0.4 conservé) |
| Attribution unique de la propriété gratuite | OK : seconde attribution refusée |
| Isolation des essais protégés | OK : durée bornée ; véhicule marqué, refusé par les courses et sans progression de mission ; véhicule temporaire protégé (contrôles statiques du code serveur) |
| Restrictions du mode photo | OK : à pied, conducteur arrêté ; refus en roulant (conducteur, passager) et en course ; rayon, hauteur et obstacle ; zoom borné |
| État individuel des volumes radio | OK : volume du passager, coupure individuelle, rien hors du véhicule, diffusion extérieure désactivée |
| Sélection de station par le conducteur | OK : passager et piéton refusés, station inconnue ou indisponible refusée, extinction toujours possible ; stations indisponibles aujourd'hui |
| Localisation FR/EN | OK : clés du lot, changement à chaud ; chaque `tr("…")` des trois panneaux traduit avec les mêmes spécificateurs (le test a d'abord signalé à tort « 60 % du » : motif corrigé) ; contrôle du lot 0.7 (toutes les clés, erreurs serveur) toujours vert |
| Réglages audio et accessibilité | OK : préférences v1 → v2 (volumes repris), bornes, qualité inconnue refusée ; couches selon la qualité, électrique distinct, moteur calé muet ; feux la nuit et par brouillard |
| Compatibilité des migrations | OK : profil v4 → v5, ancien joueur avec véhicule : parcours terminé (non imposé) ; nouveau : parcours proposé ; profil valide, original intact |
| Manifeste sans référence manquante ni inventée | OK : 0 erreur de validation, aucun identifiant Roblox, 30 sons conformes au script, carrosseries et habillages déclarés, identifiants audio utilisés tous déclarés ; pytest : sources existantes, aucune URL en dur |
| (en plus) Parcours et exercices ; place passager | OK : ordre imposé, passage, choix réservé à la transaction, étape franchissable sans candidat ; exercices ; passager propriétaire ou groupe |

Défauts trouvés et corrigés pendant le lot :

- démultiplication insuffisante de la Cadence (194 / 215 km/h), de la Comète et de la Zénith ;
- parcours bloquant en test et production (liste officielle vide) : l'étape du choix est désormais franchissable
  quand aucun candidat n'est disponible ;
- un véhicule d'essai pouvait servir à une course ou à une mission (récompense) : désormais refusé ;
- la touche X de la manette (téléphone, priorité haute) absorbait l'invite d'entrée dans un véhicule : téléphone
  déplacé sur Select.

Banc de la gamme : `lune run tools/vehicles/catalog.luau build/AutomotiveWorld.rbxlx` (2026-11-03) — résultats
dans le catalogue (modèle planaire, pas des mesures en jeu). Synthèse audio : `python tools/audio/synth.py`
(30 fichiers, 119,0 s, déterministe). Carte : 47 653 pièces dont 3 998 accessoires d'habillage, empreinte
identique sur deux générations.

### 2.2 Contrôles de démarrage dans Studio (VM)

À compléter après exécution.

### 2.3 Exécution finale

À compléter après exécution.

### 2.4 PR

À compléter.

## 3. Écarts, choix et points à arbitrer

1. **Approbations attendues** : gamme de 18 modèles, trois véhicules de départ (inscrire les identifiants dans
   `StarterCatalog.Candidates`), sons à écouter puis téléverser (`ASSETS_ET_LICENCES.md` §4).
2. **Audio** : contrôleurs livrés, aucun son joué en jeu ; la signature sonore complète n'est pas livrée.
3. **Garde-fou pytest assoupli** : `rbxassetid://` est désormais permis dans le seul `AssetManifest.luau`
   (fonction `contentId`, à partir d'un identifiant réel déclaré ; aucun aujourd'hui) ; `test_lot08.py` interdit
   toute URL écrite en dur.
4. **Groupes de collision** : toutes les pièces des véhicules passent dans `AWVehicule` (même comportement que le
   groupe par défaut, sauf face à un personnage protégé `AWArrivee`). Les véhicules du trafic PNJ ne sont pas
   concernés.
5. **Mode photo** : passager en mouvement refusé (option « si faisable » non retenue) ; refus pendant toute
   course (pas seulement classée) ; galerie : celle de Roblox, proposée ; si `CaptureService` est indisponible, le
   joueur est invité à utiliser la capture de Roblox.
6. **Feux stop** des autres véhicules non représentés (état de freinage non répliqué).
7. **Manette** : téléphone sur Select (au lieu de X), garage par le téléphone, mode photo par l'application
   Photo ; place passager sur E / X près de la portière droite.
8. **Préférences v2** : `Vehicles` → Moteur et `World` → Environnement ; catégories Effets, Radio, Voix ajoutées.
9. **Panneaux 0.4–0.6** : les noms propres (parcours, propriétés, lieux, modèles) et certains identifiants bruts
   restent tels quels ; textes déjà affichés (pied de page, devis en attente) gardent leur langue jusqu'au
   prochain affichage. Choix de mots à relire : « Préparation » → « Tuning », « Abandonner » (course) → « Retire ».
10. **Habillage** non bloquant (aucune collision) et posé à l'altitude de la route : quelques accessoires peuvent
    flotter ou s'enfoncer sur le relief en paliers (à vérifier visuellement, QA-V01).
11. **Interfaces** : la reprise visuelle complète des lots 0.4–0.7 n'est pas faite (à planifier).

Anomalies connues des lots précédents : non corrigées ni retestées (`docs/QA_BACKLOG.md` §1).
