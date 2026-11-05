# UI PREMIUM V1.2 — finalisation : rapport

Branche `feat/ui-premium-v1.2`, PR #17 (brouillon). Rapport du 2026-11-05. Demande du propriétaire : « AUTOMOTIVE WORLD —
UI PREMIUM V1.2 : FINALISATION » (garage, smartphone, autres interfaces, résolutions, navigation et sécurité,
vérification, livraison). Rien n'a été fusionné ni publié.

Références : maquettes `docs/ui/handoff-v1.2/` (Garage, Smartphone, Design System, Icônes Téléphone). Règles suivies :
données RÉELLES uniquement (instantanés des services, catalogues), aucune réussite affichée avant la réponse du serveur,
aucune fonctionnalité inventée ; ce qui n'existe pas dans le jeu n'est pas affiché.

## 1. Interfaces terminées

### 1.1 Garage (`GaragePanel`, `GarageView`, `VehiclePreview`) — maquette « Garage.dc.html »

| Élément de la maquette | État dans le jeu |
|---|---|
| Barre haute 56 : titre en capitales, lieu, « brouillon non envoyé » | fait (lieu réel : propriété, garage public, visite, hors garage) |
| Onglets 48 à filet ambre de 3 px | fait ; onglets aussi par PageUp/PageDown et LB/RB |
| Collection pleine largeur, cartes 300 px (240 compact) : vignette 16:9, rangement, nom, catégorie, motorisation, étiquettes | fait ; vignette = ViewportFrame fixe en vue 3/4 ; catégorie du catalogue commercial ou « Prototype technique » |
| Zone 3D : retour à la collection, nom 56/40, catégorie, statut de gamme, vues 3/4 · avant · arrière · profil, rotation, zoom 0,8–1,4, réinitialiser | fait (ViewportFrame) ; vue « Intérieur » **non faite** (pas de caméra d'habitacle dans l'aperçu) |
| Barre d'actions Sortir · Exposer · Ranger · Préparer | fait, avec la raison de chaque action indisponible (la manette n'a pas d'infobulle) |
| Véhicule : 4 cellules d'état, fiche technique, pièces installées, note de gamme | fait ; fiche limitée aux valeurs des définitions et du catalogue (puissance tirée de la courbe de couple, masse, dimensions, réservoir/batterie, aides, valeur catalogue) ; **0–100 km/h, v60, V. annoncée et description absents** (non fournis par les données du jeu) |
| Préparation : sous-onglets Réglages · Pièces · Esthétique, glissières min/origine/max, brouillon, annuler / appliquer | fait ; combinaison vérifiée par les vraies règles (`TuningRules.validate`) ; **graphique « effet estimé » non repris** (la maquette le dit illustratif et non relié à la physique) |
| Pièces : options par emplacement, incompatibles grisées | fait ; **écart** : une pièce est posée dès la demande (`SetPart` du serveur), pas à « Appliquer » |
| Esthétique : nuanciers, finition, jantes, kit, accessoires (2 au plus), inscription | fait, appliqué en direct à l'aperçu 3D |
| Configurations : nom, 5 cartes, enregistrer / appliquer / supprimer | fait ; suppression confirmée |
| Propriétés, Invitations | fait avec les données réelles (la maquette n'avait pas `PropertyCatalog`) ; revente confirmée |
| Bandeau d'état (en attente, refusé, hors ligne, confirmé) | fait (réponses réelles) |
| Fermer (P) en barre haute | **écart** : dans la barre d'aide (en barre haute, il passait sous le cartouche de Roblox) |

### 1.2 Smartphone (`PhoneController`) — maquette « Smartphone.dc.html »

- 12 icônes envoyées par le propriétaire, conservées. Rangées de la maquette : titres de section, cartes à filet d'état,
  boutons à valeur (Roboto Mono), bouton principal ambre, notes, avertissements.
- Véhicules en cartes (catégorie, rangement, réserve ; filet ambre exposé, cyan sorti) et « Garage et collection » (P).
- Carte, Propriétés, Missions, Courses, Marché, Social, Radio, Photo, Guide, Notifications, Paramètres recomposés ;
  paramètres présentés « libellé | valeur » ; service injoignable signalé, jamais simulé.
- Mode rapide en conduite : étiquette courte « MODE RAPIDE », itinéraire en carte cyan, aucune saisie ni bouton
  sélectionnable, avertissement « écran complet à l'arrêt ».

### 1.3 Autres interfaces (sans maquette dédiée : proposition cohérente avec les jetons, **à valider**)

| Interface | Recomposition |
|---|---|
| Économie (J) : portefeuille, métiers, concession, marché, immobilier, services | panneau plein écran commun (`PanelKit`) ; cellules de solde, réputation avec progression, historique ; cartes en grille ; devis → **confirmation protégée** avec les montants du serveur → état réel ; abandon de mission confirmé |
| Courses (K) | parcours en cartes, détail (fiche, types d'épreuve, épreuves ouvertes), mon épreuve (cellules, participants), classements, résultats ; affichage de course compact à filet rouge, chrono Roboto Mono italique |
| HUD de conduite | tableau en carte, vitesse et unité séparées, rapport ambre, jauges ; mini-carte ronde (fond #0F1214, liseré #2A4A50, itinéraire cyan, flèche joueur ambre) ; guidage en carte cyan |
| Carte (M) et GPS | repères **sans caractère Unicode ni émoji** (lettres latines pour les services, formes dessinées : carré, losange, cercle, anneau, cible, damier) ; fenêtre V1.2 ; lieux avec distance |
| Notifications | cartes à filet de couleur du niveau, libellé du niveau ; alerte critique en bandeau rouge sombre |
| Arrivée et formation, mode photo, silhouette | fenêtres V1.2, boutons 44 px, état des exercices en clair |

### 1.4 Résolutions, navigation, sécurité

- Règle 1440 p de la maquette appliquée aux écrans du jeu : contenu disposé en pixels logiques 1080 p puis agrandi
  (1,333) ; disposition compacte sous 1400 px logiques ; largeurs calculées en pixels logiques.
- Demandes au serveur bornées à 12 s : sans réponse, état « hors ligne » (une demande pouvait attendre indéfiniment).
- Focus manette : tout bouton actif est sélectionnable, tout bouton inactif ne l'est pas ; retour d'un niveau dans le
  garage (Retour arrière / B) ; confirmations protégées (départ, revente, suppression, abandon, devis).

## 2. Essais (exécutés le 2026-11-05)

Statique : `scripts\verify.ps1 -RobloxTypes .tooling\globalTypes.d.luau` — toutes les étapes OK, **Lune 398 / 398**,
pytest 14 / 14, luau-lsp strict 0 erreur (dernière exécution après le commit `7601693`).

| Session VM (`test-vm.cmd -Sessions <s> -GuiInput`) | Tâche | Résultat |
|---|---|---|
| `ui_garage2` (garage recomposé, garage public) | 20261105-122330 | 23 / 23 (+ 1 limite : PageDown non transmis par le pont de la VM) |
| `ui_garage3d` (aperçu 3D, Comète) | 20261105-122330 | tout réussi |
| `ui_garage` (disposition, polices) | 20261105-122651 | 13 / 13 |
| `ui_phone` (12 applications, mode rapide en conduite) | 20261105-123745 | 44 / 44 |
| `ui_panels2`, `ui_panels` (économie, courses) | 20261105-125026 | 24 / 24 et 12 / 12 |
| `ui_hud` (HUD, carte, notifications, conduite réelle) | 20261105-130646 | 12 / 12 |
| `ui_resolutions` (4 résolutions × 5 écrans) | 20261105-131603 | 26 / 26 |
| `ui_navigation` (focus, refusé, hors ligne, double clic) | 20261105-132328 | 21 / 21 |

Campagne de non-régression transversale : voir §4.

## 3. Écarts, limites et NON TESTÉ

- **Manette physique : NON TESTÉ** (le pont d'entrées de la VM n'envoie ni stick ni bouton) ; seule la sélectionnabilité
  des boutons est vérifiée. PageDown non transmis par le pont (limite connue de la session `ui_garage2`).
- **Résolutions** : vérifiées dans un écran virtuel à la taille exacte, réduit pour la fenêtre fixe de la VM (812 × 635),
  avec surcharge de la taille de vue en Studio ; ce n'est pas un vrai changement de résolution de Roblox. Un essai
  humain sur écrans réels reste à faire.
- **Double envoi** : le double clic réel a envoyé 2 demandes (la réponse du serveur est arrivée avant le second clic) ;
  aucune duplication (même emplacement réécrit). La garde « une demande à la fois » n'a donc pas été mise à l'épreuve
  par ce clic ; les demandes sensibles gardent un identifiant unique vérifié par le serveur.
- Écarts de maquette : vue « Intérieur », graphique « effet estimé », 0–100 et v60 non affichés ; pièces posées dès la
  demande ; Fermer dans la barre d'aide.
- Proposition à valider (pas de maquette) : économie, courses, HUD, carte, notifications, arrivée, photo, silhouette.
- Les signes « × », « ! » et « ● » des aides au pilotage du HUD (décision QA-F14) sont conservés.

## 4. Campagne de non-régression transversale

À compléter à la fin de la campagne.

## 5. Anomalies constatées (hors interface)

- Silhouette d'un profil neuf : un clic pendant le chargement de l'apparence est refusé par le serveur
  (« apparence en chargement ») et la fenêtre reste ouverte ; il faut recliquer. Proposé : griser les boutons tant que
  l'apparence n'est pas prête (lot AVATAR).
- Zone d'essai : la carte complète n'affiche aucune route (pas d'index routier dans la place de développement).

## 6. Prochaines tâches

1. Essai humain : manette réelle, écrans 1080 p, 1440 p et ultralarge réels, lisibilité des cartes et du HUD.
2. Validation par le propriétaire des propositions sans maquette (économie, courses, HUD, carte, notifications).
3. Vue « Intérieur » de l'aperçu 3D et état des dégâts de l'exemplaire dans l'aperçu.
4. Maquettes dédiées : concession, économie, courses, carte complète, HUD.

## Captures (`docs/ui/captures-v1.2/`)

Garage : `garage_collection.jpg`, `garage_vehicule.jpg`, `garage_preparation_reglages.jpg`,
`garage_preparation_esthetique.jpg`, `garage_confirmation.jpg`, `garage_apercu3d_comete.jpg` ; téléphone :
`telephone_accueil.jpg`, `telephone_vehicules.jpg`, `telephone_parametres.jpg`, `telephone_mode_rapide.jpg` ; HUD et
carte : `hud_conduite.jpg`, `carte.jpg`, `notifications.jpg` ; résolutions : `resolution_garage_3440x1440.jpg`,
`resolution_preparation_2560x1440.jpg`, `resolution_telephone_1280x720.jpg` ; états : `etat_refuse.jpg`,
`etat_hors_ligne.jpg`. Toutes prises dans la VM (fenêtre 812 × 635, disposition compacte), sauf les résolutions.
