# Architecture du lot 0.8 — rendu, gamme, audio, radio, photo, arrivée

Complète `docs/ARCHITECTURE.md` et les architectures des lots 0.1 à 0.7. Séparation inchangée : `src/server`
(autorité, validation), `src/client` (commandes, rendu, simulation du véhicule conduit), `src/shared` (règles
pures testées hors Studio).

## 1. Modules ajoutés

| Couche | Module | Rôle |
|---|---|---|
| shared | `Assets/AssetManifest` | Manifeste des ressources ; `playable`, `contentId`, `validate` |
| shared | `Art/ArtDirection` | Profils de qualité, étalonnage horaire, règle des feux |
| shared | `Audio/EngineAudioModel` | Couches moteur thermique (4) et électrique (3) : volume, vitesse de lecture |
| shared | `Audio/AmbienceModel` | Boucles d'ambiance par zone, pluie, vent ; catégories de volume |
| shared | `Audio/RadioRules` | Stations fictives, choix du conducteur, écoute par occupant, disponibilité |
| shared | `Photo/PhotoRules` | Contextes autorisés, caméra bornée, réglages et filtres |
| shared | `Onboarding/OnboardingRules` | Étapes du parcours, passage, exercices, migration |
| shared | `Onboarding/TrainingRules` | Réussite des 8 exercices à partir d'observations |
| shared | `Vehicles/PassengerRules` | Droit de monter en passager |
| shared | `UI/Texts08`, `UI/PanelTexts` | Textes FR/EN du lot ; traductions des panneaux des lots 0.4–0.6 |
| server | `Onboarding/OnboardingService` | Canal `AWOnboarding` ; essais ; choix via `Grant:Starter` ; protection d'apparition |
| server | `Audio/RadioService` | Canal `AWRadio` ; attribut `AWRadioStation` posé pour le seul conducteur |
| server | `Vehicles/BodyKits` | Carrosseries et habitacles des dix silhouettes |
| client | `UI/OnboardingController` | Écrans du parcours, comparatif, essai, confirmation, exercices |
| client | `UI/PhotoMode` | Mode photo (caméra scriptée, effets locaux, capture) |
| client | `Audio/AudioController` | Moteur, ambiances, sons d'interface (muets sans ressource téléversée) |
| client | `Audio/RadioController` | Écoute locale de la station commune, demande du conducteur |
| client | `World/DetailLod` | Visibilité de l'habillage et des détails de carrosserie |
| client | `World/VehicleLights` | Feux et lampadaires la nuit, sources limitées |
| outil | `tools/audio/synth.py` | Synthèse déterministe des 30 sons originaux |
| outil | `tools/world/build-world.luau` | + section « HABILLAGE » (7 zones) |

## 2. Gamme proposée et véhicules

`WorkingCatalog.build()` dérive 18 définitions physiques des prototypes P-01 à P-03 (voir
`CATALOGUE_18_VEHICULES.md`), enregistrées par `VehicleDefinitions` et validées au chargement. `VehicleCatalog`
(économie) les relie par `DefinitionId` ; disponibilité `PendingApproval` : achat en développement seulement.
`VehicleFactory` choisit `BodyKits` quand `Appearance.BodyStyle` est défini, sinon la carrosserie de prototype ;
il pose la place passager, son invite (`PassengerPrompt`) et les groupes de collision.

Groupes de collision (nouveaux) : toutes les pièces d'un véhicule sont dans `AWVehicule`, qui entre en collision
avec tout sauf `AWArrivee` (personnage protégé à sa première apparition). Comportement inchangé pour le reste.

## 3. Parcours d'arrivée

```
Client (OnboardingController) ──Request(action, payload)──▶ OnboardingService
   Status | Advance{Step} | Skip | TestDrive{ModelId} | EndTestDrive | Choose{ModelId} | Exercise{Id}
OnboardingService ──Push("Status", état)──▶ client (ouverture automatique si parcours non terminé)
```

- Progression : profil, champ `Onboarding` (schéma 5) ; mutations non sensibles (aucun crédit, aucun objet).
- Candidats : `StarterCatalog.candidates(environnement)` → liste officielle (vide) ou, en développement, la
  proposition (exemplaire synthétique).
- Choix : `ProgressionService.chooseStarter` → transaction unique `Grant:Starter` (idempotente, non répétable,
  exemplaire incessible), puis `OnboardingRules.starterChosen`.
- Essai : `MissionService.spawnBeside` (véhicule temporaire protégé, hors profil), marqué `AWTestDrive` ; refusé
  par les courses (`TestDriveNoRewards`) et sans progression de mission ; 3 min au plus, un à la fois.
- Propriété gratuite : transaction unique `Grant:FreeProperty` au premier chargement (lot 0.4), présentée à
  l'étape « Property » avec guidage GPS.
- Protection d'apparition : champ de force + groupe `AWArrivee`, 60 s au plus ou jusqu'à la montée en véhicule.
- Exercices : observés côté client (`TrainingRules`), seul le résultat « fait » est envoyé ; aucun crédit.

## 4. Audio et radio

```
EngineAudioModel / AmbienceModel ──(couches, volumes)──▶ AudioController ──▶ Sound (si RobloxAssetId réel)
                                                                     └─ SoundGroup AWEngine / AWEnvironment / AWInterface / AWEffects
Conducteur ──AWRadio:FireServer(station)──▶ RadioService ──▶ attribut AWRadioStation du véhicule
Occupant (RadioController) : volume = RadioRules.listenVolume(place, station, coupure, volume) → son 2D local
```

Volumes par catégorie : `SettingsController` crée les `SoundGroup` `AWEngine`, `AWEnvironment`, `AWInterface`,
`AWEffects`, `AWRadio`, `AWVoice` et applique général × catégorie (radio coupée = 0). Les sons de notification
passent par `NotificationService.setSoundSink` ; l'alerte reste toujours visuelle.

## 5. Mode photo

`PhotoMode` est un écran `UIManager` (modal, « Full » : interdit en roulant) ; `PhotoRules.allowed` est
réévalué à chaque image (fermeture automatique). Caméra `Scriptable` bornée par `PhotoRules.clamp` et tronquée
au premier impact d'un rayon lancé depuis le sujet. Effets `ColorCorrectionEffect` et `DepthOfFieldEffect`
placés dans la caméra (locaux), détruits à la sortie ; caméra, ScreenGui et interface Roblox restaurés à
l'identique. Capture : `CaptureService` (via `pcall`), enregistrement proposé dans la galerie Roblox.

## 6. Données persistantes

| Élément | Avant | Lot 0.8 |
|---|---|---|
| Schéma du profil | 4 | **5** : champ `Onboarding` ; migration 4 → 5 (terminé si le véhicule de départ est déjà choisi) |
| Préférences | version 1 | **2** : `Audio` = Général, Moteur, Environnement, Interface, Effets, Radio, Voix, `RadioMuted` ; `Graphics.Quality` ; reprise de `Vehicles` → Moteur et `World` → Environnement |

Aucune nouvelle écriture sensible ; aucun DataStore réel n'est utilisé par les tests.

## 7. Raccourcis

Téléphone : T / **Select** (manette ; X est désormais laissé à l'invite d'entrée dans un véhicule). Garage : P
(manette : via le téléphone). Mode photo : **O** (manette : application Photo). Dans le mode photo : W/A/S/D,
Q/E, flèches, sticks, I (interface).

## 8. Tests

- `tests/lune/specs/Lot08Content.luau` : 17 tests (les 15 points du brief, plus le parcours et les exercices
  — test 8 — et la place passager — test 17).
- `tests/test_lot08.py` : sources du manifeste, absence d'identifiant inventé, synthèse audio déterministe et
  conforme, boucles moteur sans saut.
- `tests/test_scaffold.py` : exception unique pour `AssetManifest.luau` (URL de contenu formée à partir d'un
  identifiant réel).
