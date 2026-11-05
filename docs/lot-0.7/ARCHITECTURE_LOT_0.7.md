# Lot 0.7 — architecture de l'interface, du GPS, du smartphone et du social

## 1. Vue d'ensemble

```
                         ┌───────────── InputRouter (raccourcis centralisés, garde de confirmation)
                         ▼
   UIManager (une modale à la fois, focus, conduite AUD-UI-01) ── UIState (préférences, mode, capture)
      │        │          │          │            │             │
   Phone    Map      Garage (P)  Economy (J)  Races (K)     (écrans inscrits)
      │        │
      │   MapRenderer ◄── MapIndex (routes simplifiées, grille)        HUDController (tableau, mini-carte, guidage)
      │        ▲                                                         │
      └── GPSController ── RouteGuide (A* du lot 0.3, profils, manœuvres, recalcul) ◄┘
      │
      ├── SocialController ── AWSocial ── server/Social/SocialService ── GroupRules (pur)
      ├── SettingsController ── AWInterface ── server/Social/InterfaceService ── Preferences (pur), PointsOfInterest (pur)
      └── NotificationService ── NotificationQueue (pur)       Localization (FR/EN, pur, partagé)
```

Cœurs PURS testés par Lune (`tests/lune/specs/Lot07Interface.luau`) : `Shared/UI/{Localization, Preferences,
UIStack, InputMap, DrivingGate, NotificationQueue}`, `Shared/Navigation/{RouteGuide, MapIndex, MapProjection}`,
`server/Social/{GroupRules, PointsOfInterest}`. Le reste est l'interface Roblox (client) et deux services serveur
fins. AUCUNE règle serveur des lots 0.4 à 0.6 n'a été réécrite : les panneaux existants s'inscrivent au
gestionnaire commun et gardent leurs canaux.

## 2. Gestionnaire d'écrans et commandes

- `UIStack` : une seule modale principale ; ouvrir une modale ferme la précédente ; le focus d'avant la première
  ouverture est rendu à la fermeture ; « retour » ferme l'écran du dessus.
- `UIManager` : registre des écrans (`Phone`, `Map`, `Garage`, `Economy`, `Races`), mode de conduite surveillé
  toutes les 0,2 s (`DrivingGate` : à pied, à l'arrêt < 1 m/s, en mouvement avec hystérésis 0,5 m/s).
  Écran complet demandé en roulant : refusé (ou mode rapide) ; s'il était ouvert, il passe en mode rapide ou se
  masque en GARDANT son contenu ; rien n'est validé ; aucun bouton n'est sélectionné en roulant (la manette conduit).
- Capture : tant qu'une modale complète est ouverte (à l'arrêt ou à pied), `InputArbiter` reçoit
  `UiCaptured = true` : clavier et manette perdent la main et devront être revus au repos (même règle que la
  saisie de texte). Jamais de freinage ni de pause : la capture n'existe pas en roulant.
- `InputMap` / `InputRouter` : actions globales (téléphone T / X, carte M, garage P / Select, économie J / stick
  droit, courses K / stick gauche, niveau du HUD H, effacer l'itinéraire X), « retour » (Retour arrière / B) lié
  seulement pendant une capture (au volant, B reste l'embrayage). Touches clavier personnalisables, jamais une
  touche réservée (conduite, interaction, chat, système) ni en double.
- Garde de confirmation : une confirmation (achat, vente, engagement en course) n'est acceptée que d'une pression
  commencée ≥ 0,25 s après l'affichage de la demande et ≥ 0,4 s après le dernier changement de périphérique.

## 3. HUD contextuel

`HUDController` lit les données de conduite déjà calculées par `VehicleController` (via `DevHud.latest`, enrichies
du type de boîte, de la motorisation et du moteur calé) et les attributs de dégâts du véhicule.
Minimal / Standard / Complet ; vue cockpit réduite ; course : l'affichage de course du lot 0.6 prime, mission et
navigation masquées ; à pied : pas de tableau. Taille (70–140 %), coin (bas droite / gauche), mini-carte (zoom,
orientation), informations en conduite. Alertes énergie ≤ 15 % et mécanique (moteur ou direction < 50 %,
défaillance < 20–25 %) toujours affichées et notifiées une fois par franchissement. Le HUD de développement reste
disponible (paramètres), désactivé par défaut.

## 4. GPS, mini-carte, carte

- `RouteGuide.plan` : profil `Road` (ni chemins ni pistes), `AllTerrain` (chemins), `Track` ; départ = extrémités
  du tronçon le plus proche (les deux essayées), arrivée = carrefour accessible le plus proche (≤ 600 m) puis ligne
  directe ; A* en temps du lot 0.3 ; manœuvres aux carrefours (gauche, droite, serrer, tout droit, demi-tour) avec
  le nom de la route suivante. Zone d'essai : guidage direct.
- Suivi 4 fois par seconde (projection locale sur l'itinéraire), recalcul après 3 s hors itinéraire (> 35 m) et au
  plus toutes les 5 s, calcul dans une tâche séparée. Objectif de mission suivi automatiquement si le joueur n'a pas
  choisi de destination. Aucune téléportation.
- `MapIndex` : tracés simplifiés (≥ 20 m ou virage ≥ 12°), grille de 200 m, importance par classe ; niveau de détail
  selon l'échelle. `MapRenderer` : réserve d'éléments réutilisés, plafond de segments (450 mini-carte, 1 800 carte),
  marqueurs ramenés au bord pour l'objectif. Les positions viennent des données de la carte : compatibles avec le
  streaming.
- Points d'intérêt (`PointsOfInterest`, serveur) : issus de `Locations` (concessions, garages, stations, bornes,
  lavages, entrées), des parcours (`RaceCourse`), de `WorldLayout` (lieux sociaux, arrivées) ; points personnels du
  demandeur seulement (ses propriétés, sa mission). Identifiants d'origine préfixés, validés.

## 5. Smartphone

`PhoneController` : modèle provisoire original placé par le serveur dans la main (bras levé par l'épaule, aucune
animation externe ; écran vu des autres : l'heure seulement). Taille normale ou agrandie. Applications : accueil,
carte, véhicules, propriétés, missions, courses, marché, social, paramètres, notifications. Elles lisent les
instantanés existants (`AWProgression`, `AWEconomy`, `AWRacing`, `AWSocial`) et ouvrent les panneaux pour agir :
aucune seconde logique d'achat, de vente ou de récompense ; démarrer une mission utilise le canal de l'économie.
En roulant : mode rapide (itinéraire, alertes en lecture, niveau du HUD, zoom, effacer l'itinéraire), aucune
sélection manette.

## 6. Groupes, partage de position, communications

- `GroupRules` : 8 membres au plus, une appartenance, invitations du responsable (2 min, retrait, refus,
  préférence « accepter les invitations »), exclusion, direction confiée, dissolution ; absent : 5 min puis retiré,
  responsable absent > 60 s : direction au membre présent le plus ancien.
- Le groupe est distinct des invitations de propriété, des droits de conduite, des prêts et de l'économie : aucun
  droit n'en découle ; chaque service revérifie ses propres droits.
- Partage de position : désactivé par défaut, activé pour le groupe ACTUEL pour 2 h au plus, arrêté à la
  désactivation, à la sortie, à la dissolution, à la déconnexion, à l'échéance. Positions envoyées par destinataire
  (`visiblePositions`) : membres de son groupe qui partagent, jamais lui-même, rien hors groupe.
- Vue sociale filtrée par liste blanche (nom d'affichage, rôle, présence, partage, ami) : aucun solde, inventaire,
  collection, propriété, transaction ni donnée de profil.
- Communications : `TextChatService` (canal texte par groupe, canal de proximité à 80 m via `ShouldDeliverCallback`) ;
  filtrage, âge, confidentialité et modération restent ceux de Roblox ; la voix suit les réglages Roblox. Aucun
  message texte propre au jeu. Canal indisponible ou utilisateur refusé : signalé, jamais contourné.

## 7. Notifications

`NotificationQueue` : Info, Warning, Critical ; en conduite : informations différées (résumé à l'arrêt),
avertissements compacts, critiques toujours affichées et multimodales (texte, icône, cadre clignotant ; son : aucun
son original disponible, lot 0.8). Regroupement des répétitions, niveaux désactivables sauf Critique, historique de
50 éléments consultable. Sources : notices du véhicule, panneaux, groupes, GPS, HUD, état de sauvegarde du profil
(`AWProfileState` : session perdue, sauvegarde retardée).

## 8. Préférences, accessibilité, localisation

- Profil v4 (`ProfileMigration` 3 → 4) : `Preferences` (langue, HUD, mini-carte, notifications, accessibilité,
  audio, préférences sociales, raccourcis). Nettoyage serveur (bornes, énumérations, champs inconnus ignorés, alertes
  critiques non désactivables, partage de position jamais durable). Envoi client regroupé (au plus toutes les 5 s,
  seulement si changé) ; le serveur marque le profil à sauvegarder (mutation non sensible) : l'écriture suit la
  sauvegarde périodique et les verrous existants.
- Accessibilité : taille des textes, contraste renforcé, animations réduites, opacité des panneaux, sensibilité de
  navigation, notifications secondaires réduites, alertes visuelles renforcées, volumes (groupes de sons du jeu).
- `Localization` : une entrée = { fr, en } par clé, paramètres nommés `{nom}` (anciens formats `%d / %s` conservés),
  langue changée à chaud ; `ProgressionMessages` et `Messages` y renvoient. Les libellés internes des panneaux
  provisoires des lots 0.4 à 0.6 restent en français (écart documenté) ; leurs statuts et erreurs sont traduits.

## 9. Direction visuelle provisoire

`UITheme` : palette sobre (ambre automobile sur fond sombre), contraste renforcé, typographies Gotham, coins
arrondis, contour de focus net, animations courtes (supprimées si demandé), panneaux à opacité réglable. Assets
définitifs : lot 0.8.
