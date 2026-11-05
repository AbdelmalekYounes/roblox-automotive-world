# UI-02 à UI-04 — téléphone, garage, écrans : rapport

Branche `feat/ui-premium-v1.2`, PR #17 (brouillon). Rapport du 2026-11-05.

Les lots s'enchaînent sans demande d'accord intermédiaire, à la demande du propriétaire (« fais tout l'UI »). Les essais
VM portent **uniquement sur ce qui a été refait** : une session courte par écran (consigne du propriétaire). Référence :
maquettes V1.2 (`docs/ui/handoff-v1.2/`). Règle suivie : aucune demande aux services n'est modifiée, l'interface
seule change.

## 1. UI-02 — téléphone

| Élément | Contenu |
|---|---|
| Coque | tailles de la maquette (380 × 780, agrandie 460 × 940, compactes 330 × 600 / 380 × 660), coin bas-droit, marges 40 / 20, rayons 34 / 26 ; hauteur limitée à la vue |
| En-tête | heure, bouton Retour (au lieu d'une première ligne « ← »), titre, étiquette « mode rapide », agrandir, fermer |
| Accueil | grille de 12 tuiles (56 px, icône 28 px, ambre ; carte en cyan), pastille des notifications non lues, 4 colonnes calculées sur la largeur (3 rangées sans défilement) |
| Lignes | titres en capitales (libellé), texte, notes discrètes, boutons de 44 px ; inactif à 0,45 d'opacité |
| Icônes | 12 PNG blancs (64 et 128 px) tracés depuis les chemins SVG de la maquette (`tools/ui/make_phone_icons.py`, `assets/ui/icons/`) ; une entrée de manifeste par icône (`ui.icon.phone.<app>`) ; images **envoyées par le propriétaire le 2026-11-05** (voir §1 bis) ; le cadre vide reste prévu pour une icône sans image |
| Caractères Unicode | supprimés : émojis des applications, loupe du réglage rapide, flèche de retour, pictogrammes des invitations et du partage de position (remplacés par des mots, FR / EN) |
| Mode rapide | inchangé (contenu limité, réglages rapides) ; le téléphone agrandi est refusé en mode rapide |
| Focus manette | contour ambre sur les tuiles ; recherche du premier bouton dans toute la grille |

## 1 bis. Icônes envoyées sur Roblox (2026-11-05)

- Envoi par le propriétaire : 12 décalques importés sur create.roblox.com (compte youyou31110), puis conversion en
  identifiants d'**image** par une ligne collée dans la barre de commande de Studio (chargement de chaque décalque,
  lecture de sa texture, aucune modification de la place). Aucune publication d'expérience.
- Contrôle de l'assistant sur l'API publique `economy.roblox.com/v2/assets/<id>/details` : les 12 identifiants sont de
  type 1 (image), nommés `<App>_128`, créés par le même compte ; les 12 décalques d'origine sont de type 13.
- Inscription : table `PHONE_ICON_IDS` de `AssetManifest` (seuls identifiants Roblox déclarés au manifeste, en dehors
  de la liste de maillages de la Comète). Les essais « aucun identifiant inventé » (pytest `test_lot08`, Lune
  `Lot08Content` 16) admettent désormais ces 12 valeurs exactes et elles seules ; `UiDesignSystem` 1 vérifie que
  `PhoneIcons.image()` sert `rbxassetid://<id>` pour chacune.

| Application | Image | Application | Image |
|---|---|---|---|
| Map | 139759611688719 | Market | 79661493327089 |
| Vehicles | 75819885655066 | Social | 104529493537486 |
| Properties | 86911212052819 | Radio | 97090714931696 |
| Missions | 123109347713390 | Photo | 124133194296037 |
| Races | 135512154723543 | Guide | 78344066959818 |
| Settings | 117473178109905 | Notifications | 77842663800346 |

## 2. UI-03 — garage

| Élément | Contenu |
|---|---|
| Disposition | écran plein : barre haute 56, onglets 48 (filet ambre de 3 px sur l'onglet actif, largeur automatique), barre d'aide 40 |
| Panneau latéral | à droite, largeur de l'onglet : Véhicule 420 / 340, Préparation 680 / 540, autres 560 / 460 (compacte sous 1400 px logiques) |
| Zone 3D | à gauche, dégradé de la maquette, nom du véhicule sélectionné ; **le rendu du véhicule (ViewportFrame ou caméra de présentation) n'est pas fait** : la maquette le laisse à arbitrer après essai |
| Contenu des onglets | logique et demandes inchangées ; polices et couleurs converties en V1.2 ; boutons secondaires, inactifs à 0,45 |
| Fermer | dans la barre d'aide, en bas à droite (en haut à droite, il passait sous le cartouche du joueur affiché par Roblox) |
| Ordre d'affichage | au-dessus du HUD (la mini-carte recouvrait le panneau latéral) |

## 3. UI-04 — autres écrans

| Écran | Changement |
|---|---|
| Économie (J), courses (K) | polices Titillium Web (conversion dans leur fabrique), couleurs V1.2 ; onglet actif ambre doux ; rouge réservé aux refus et au chrono ; tracés de parcours en cyan |
| HUD | vitesse et rapport en Roboto Mono gras ; le reste suit le thème |
| Carte, notifications | fond et pastille aux jetons V1.2 |
| HUD de développement | fond et textes aux jetons ; barres de mesure gardées (outil d'instrumentation) |

## 4. Essais

| Essai | Commande, tâche | Résultat |
|---|---|---|
| Statique | `scripts\verify.ps1 -RobloxTypes .tooling\globalTypes.d.luau` | toutes les étapes OK ; Lune 385 / 385 (2 tests du téléphone en plus) |
| Téléphone seul | `test-vm.cmd -Sessions ui_phone -GuiInput`, `20261105-035136` | **19 / 19** : touche T, téléphone entier dans la vue, 12 tuiles avec emplacement d'icône, Carte, Véhicules, Notifications, Paramètres par vrais clics et retour par l'en-tête, page Crédits et licences (attribution CC BY de la Comète affichée), agrandir, fermer |
| Icônes envoyées (statique) | `scripts\verify.ps1 -RobloxTypes .tooling\globalTypes.d.luau`, 2026-11-05 | toutes les étapes OK ; Lune 385 / 385 ; pytest 14 / 14 |
| Icônes envoyées (téléphone seul) | `test-vm.cmd -Sessions ui_phone -GuiInput`, `20261105-111833` | 20 / 21 : 12 images posées, teinte correcte, mais l'image « Races » **pas encore chargée** au bout de 20 s (envoi récent) |
| Icônes envoyées (téléphone seul, second passage) | même commande, `20261105-112045` | **21 / 21** : 12 tuiles, 12 images, aucun cadre vide, **12 / 12 chargées** (`IsLoaded`), carte en cyan et les autres en ambre ; capture `001_ui_phone_accueil.jpg` |
| Garage seul | `-Sessions ui_garage`, `20261105-034903` | tout réussi : touche P, disposition 56 / 48 / 40, panneaux 340 / 540 / 460 (compacte), filet ambre, police V1.2 sur tous les textes, fermeture par vrai clic |
| Économie et courses | `-Sessions ui_panels`, `20261105-034506` | ouverture J et K, police V1.2 (13 et 20 textes), onglet actif ambre |

## 5. Limites et NON TESTÉ

- **Icônes** : envoyées et vérifiées dans la VM (§1 bis). Un premier chargement juste après l'envoi a échoué pour une
  image sur 12 (délai de Roblox) ; non testé : affichage chez un joueur hors Studio, sur une place publiée.
- **Observation, non corrigée** : sur les captures des deux passages, la fenêtre « Choisissez votre silhouette »
  d'un profil neuf est encore affichée par-dessus le téléphone après le clic sur « Masculin » (les clics suivants du
  téléphone réussissent). Hors périmètre de cet envoi ; à examiner avec l'écran d'arrivée.
- **Zone 3D du garage** : pas de rendu du véhicule (arbitrage ViewportFrame ou caméra de présentation à faire).
- **Échelle 1440 p** : non appliquée aux écrans du jeu. Les écrans pleins sont dimensionnés en proportion de l'écran, et
  un UIScale de 1,333 les ferait déborder ; une mise en page dédiée est nécessaire.
- **Contenu des onglets du garage** : restylé, pas recomposé selon la maquette (cartes de collection, fiche à droite,
  graphique des performances, qui n'est pas validé physiquement selon la maquette elle-même).
- Lignes du téléphone : les fiches de véhicule restent des lignes, pas des cartes.
- Non testés en VM : mode rapide en conduite, manette réelle, téléphone en 1080 p et 1440 p (seule la taille de la VM),
  sessions générales `ui`, `ui_monde`, `ui_marche` (consigne : seulement le nouveau).
- **Écart de méthode** : un premier passage de la session générale `ui` (`20261105-033732`) a été lancé avant la
  consigne. Il a révélé les deux défauts corrigés du téléphone (débordement, noms en capitales).
