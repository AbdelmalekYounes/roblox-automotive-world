# Dépendances de validation externe — lot 0.9

Ce qui ne peut pas être terminé par le développement seul : décisions du propriétaire, actions sur des comptes
Roblox, ressources artistiques, matériel. Rien de cette liste n'a été fait à ta place ; aucune publication, aucun
téléversement, aucun DataStore réel n'a été utilisé.

## 1. Décisions du propriétaire (aucune action technique nécessaire avant)

| # | Décision | Où | Effet tant qu'elle n'est pas prise |
|---|---|---|---|
| D1 | Approuver (ou modifier) la gamme de 18 modèles fictifs | `docs/lot-0.8/CATALOGUE_18_VEHICULES.md` ; données `src/shared/Economy/VehicleCatalog.luau` | Achat en développement seulement (`PendingApproval`) |
| D2 | Choisir les trois véhicules de départ officiels (proposition : Brio, Fil, Aster) | `StarterCatalog.Candidates` (liste vide) | Aucun véhicule de départ hors développement ; le parcours d'arrivée laisse passer l'étape |
| D3 | Direction artistique (silhouettes, palette, habillage, éclairage) | `docs/lot-0.8/DIRECTION_ARTISTIQUE.md` | Rendu provisoire |
| D4 | Sons synthétisés : garder, refaire ou remplacer | `build/audio/` (`python tools/audio/synth.py`) | Aucun son joué en jeu |
| D5 | Stations de radio : noms, thèmes, pistes (originales ou sous licence) | `src/shared/Audio/RadioRules.luau` | Stations indisponibles |
| D6 | Arbitrage A3 : maintien « freiner » à l'arrêt = marche arrière (automatique) | `docs/lot-0.2/RAPPORT_LOT_0.2.md` | Comportement actuel conservé (il a causé les faux échecs de sortie des essais automatisés : §2 du rapport de validation) |
| D7 | Protection d'apparition : durée (60 s) et anti-percussion par groupes de collision | `OnboardingRules.SpawnProtectionS` | Valeurs actuelles |
| D8 | Mode photo : passager en mouvement (refusé aujourd'hui), refus pendant toute course | `PhotoRules` | Comportement actuel |
| D9 | Équilibrage : barèmes des métiers et des courses | `tools/economy/simulate*.luau` | Barèmes provisoires |
| D10 | Lancement du lot 1.0 | — | Aucun travail du lot 1.0 commencé |

## 2. Actions sur un compte ou un groupe Roblox (propriétaire uniquement)

| # | Action | Prérequis | Débloque |
|---|---|---|---|
| R1 | Créer une **expérience de test isolée** (distincte de toute production), déclarer son identifiant dans `EnvironmentConfig.TestGameIds` (revue de code) | Compte ou groupe propriétaire | Campagne DataStore réelle (`RAPPORT_VALIDATION_GLOBALE.md` §6), QA-D01 à D10, QA-E01, E02, R01 à R04, U09 |
| R2 | Activer l'accès aux API Roblox (Studio) sur cette expérience de test **seulement** | R1 | Essais DataStore depuis Studio |
| R3 | Téléverser les sons approuvés (D4, D5) | Modération Roblox | `AssetManifest.RobloxAssetId`, QA-V04, V05, V06, V12 |
| R4 | Publier une version de test privée de l'expérience isolée (jamais la production) | R1 | Essais à plusieurs comptes réels, matchmaking inter-serveurs (QA-R01), charge (QA-P01, V13) |
| R5 | Comptes de test (2 à 24) | R4 | Essais multijoueurs humains, charge |

## 3. Ressources artistiques (intervention externe)

| # | Ressource | Remplace | Statut |
|---|---|---|---|
| A1 | Maillages et textures des 18 véhicules (ou validation des carrosseries construites par code) | `BodyKits` (pièces de base) | Provisoire |
| A2 | Intérieurs détaillés | Habitacle simplifié | Provisoire |
| A3 | Animations (téléphone en main, entrée et sortie de véhicule) | Bras levé par l'épaule, aucune animation | Non implémenté (un actif d'animation exige une publication) |
| A4 | Signature sonore par modèle, revêtements, acoustique (tunnels, garages, cabine), perspective caméra | Couches génériques | Non implémenté |
| A5 | Pistes de radio (originales ou sous licence) | Boucles synthétiques | Provisoire, non téléversé |
| A6 | Décors et bâtiments finaux des sept zones | Générateur hors ligne | Provisoire |
| A7 | Icônes d'interface | Glyphes texte | Provisoire |

## 4. Matériel et mesures

| # | Besoin | Pourquoi |
|---|---|---|
| M1 | Un ordinateur de référence (carte graphique courante) et un mobile de référence | La VM n'a pas d'accélération graphique représentative : aucun objectif d'images par seconde ne peut être déclaré atteint (`PERFORMANCES.md`) |
| M2 | Une vraie manette et un vrai clavier sur la machine de test | Essais humains (`CHECKLIST_TESTS_HUMAINS.md`) |
| M3 | Une expérience publiée en test (R4) avec 24 clients | Charge et réseau (QA-P01, P04, R06, U06, V13) |
