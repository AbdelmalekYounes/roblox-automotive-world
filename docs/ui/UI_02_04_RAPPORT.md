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
| Icônes | 12 PNG blancs (64 et 128 px) tracés depuis les chemins SVG de la maquette (`tools/ui/make_phone_icons.py`, `assets/ui/icons/`) ; une entrée de manifeste par icône (`ui.icon.phone.<app>`, **sans identifiant Roblox**) ; tant que l'image n'est pas envoyée, le téléphone affiche un **cadre vide** |
| Caractères Unicode | supprimés : émojis des applications, loupe du réglage rapide, flèche de retour, pictogrammes des invitations et du partage de position (remplacés par des mots, FR / EN) |
| Mode rapide | inchangé (contenu limité, réglages rapides) ; le téléphone agrandi est refusé en mode rapide |
| Focus manette | contour ambre sur les tuiles ; recherche du premier bouton dans toute la grille |

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
| Garage seul | `-Sessions ui_garage`, `20261105-034903` | tout réussi : touche P, disposition 56 / 48 / 40, panneaux 340 / 540 / 460 (compacte), filet ambre, police V1.2 sur tous les textes, fermeture par vrai clic |
| Économie et courses | `-Sessions ui_panels`, `20261105-034506` | ouverture J et K, police V1.2 (13 et 20 textes), onglet actif ambre |

## 5. Limites et NON TESTÉ

- **Icônes** : à envoyer sur Roblox par le propriétaire (12 PNG de 128 px dans `assets/ui/icons/`). Il faudra ensuite
  inscrire leurs identifiants dans le manifeste ; d'ici là, cadres vides.
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
