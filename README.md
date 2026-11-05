# Automotive World — Lot 0.9 (intégration et validation globale)

> **Nom technique provisoire** : ce n'est pas le nom commercial du jeu.
> **Référentiel** : cahier des charges global Roblox v1.0, officiellement validé le 2 novembre 2026.
> **Périmètre** : une carte ouverte en maquette (sept zones fictives d'un seul tenant, routes, infrastructures,
> trafic PNJ, piétons, météo et jour/nuit), une zone d'essai isolée et des **prototypes techniques fictifs** (P-01
> essence/automatique/propulsion, P-02 diesel/manuelle/traction, P-03 électrique/rapport unique/intégrale, et trois
> configurations de validation des boîtes double embrayage, séquentielle et CVT). Lot 0.4 : profils versionnés
> (verrou de session, transactions idempotentes), collection, propriétés et garages, préparation, configurations,
> invitations. Lot 0.5 : crédits, réputation, huit métiers, concessions (catalogue de travail provisoire), marché
> d'occasion à transferts multiprofils récupérables, immobilier, pièces, énergie, réparation, lavage. Lot 0.6 : six
> disciplines de course sur un socle commun (sprint, circuit, contre-la-montre, drift, drag, rallye), 16 parcours
> dans le monde ouvert et 6 en zone d'essai, salons, modes protégé et réaliste, réservation exclusive du véhicule,
> classement et saisons de huit semaines, matchmaking (repli local ; inter-serveurs écrit mais non exécuté). Lot 0.7 :
> interface commune, HUD contextuel, mini-carte, carte, GPS, smartphone, groupes et partage de position volontaire,
> notifications, accessibilité, français et anglais, préférences sauvegardées. Lot 0.8 : gamme PROPOSÉE de 18 modèles
> fictifs (en attente d'approbation), carrosseries par silhouette, habillage des sept zones, feux de nuit, qualité
> graphique, audio modulaire et radio (contrôleurs ; sons originaux synthétisés mais non téléversés), mode photo,
> parcours d'arrivée et exercices de formation. Lot 0.9 : version intégrée des lots 0.1 à 0.8, campagnes VM étendues
> (économie, courses, arrivée, banc des 18 modèles, mesures), corrections (courses, marché, rendu de nuit), audit de
> sécurité, préparation des essais DataStore. **Pas une autorisation de lancement public.** Aucune
> expérience de test ou de production n'est déclarée : tout profil reste **en mémoire** (aucune écriture DataStore).
> **Statut** : lot 0.9 sur `feat/integration-qa-0.9` (PR brouillon #9, base : lot 0.8 ; PR #1 à #8 non fusionnées).
> Rapport : [docs/lot-0.9/RAPPORT_VALIDATION_GLOBALE.md](docs/lot-0.9/RAPPORT_VALIDATION_GLOBALE.md). Essais
> humains : [checklist](docs/lot-0.9/CHECKLIST_TESTS_HUMAINS.md) ; DataStore, charge et appareils réels : **NON
> TESTÉS** ([docs/QA_BACKLOG.md](docs/QA_BACKLOG.md)).

## Prérequis (Windows)

- Windows 10/11, Roblox Studio installé.
- [Rokit](https://github.com/rojo-rbx/rokit) : installe les versions épinglées dans `rokit.toml`
  (Rojo 7.7.1, Selene 0.27.1, StyLua 0.20.0, luau-lsp 1.70.1, Lune 0.11.1).
- Plugin Rojo 7 pour Roblox Studio (uniquement pour la synchronisation en direct).
- Git, Python 3.10+ avec `pytest`.

```powershell
# Depuis la racine du dépôt : installe/valide les outils épinglés.
rokit install
```

## Construire et ouvrir la zone d'essai

```powershell
rojo build -o build\AutomotiveWorld.rbxlx
```

1. Ouvrir `build\AutomotiveWorld.rbxlx` dans Roblox Studio (ne pas publier la place).
2. **Ne pas** activer « Enable Studio Access to API Services » : le lot n'utilise aucun DataStore et aucun test ne doit en toucher.
3. Cliquer sur **Play**. La bannière « Zone d'essai véhicule » apparaît ; neuf véhicules sont stationnés sur les plots
   verts (plots 1 à 4 : P-01 ; puis P-02, P-03, P-01 DCT, P-01 SEQ, P-01 CVT). La zone comprend aussi une zone mouillée
   (sud-ouest), des bordures et bosses (est), un mur de choc (sud) et la bosse à 10 %.
4. S'approcher de la portière gauche d'un véhicule et **maintenir E** (manette : **X**) pour monter.
5. Pour la synchronisation en direct pendant le développement : `rojo serve`, puis connecter le plugin Rojo.

## Construire la place du monde ouvert (lot 0.3)

```powershell
rojo build -o build\AutomotiveWorld.rbxlx
lune run tools/world/build-world.luau build\AutomotiveWorld.rbxlx build\world\OpenWorld.rbxm
rojo build openworld.project.json -o build\AutomotiveWorld-OpenWorld.rbxl
```

La carte est générée hors ligne, de façon déterministe, à partir des données versionnées de `src/shared/World/Data`.
La place `build\AutomotiveWorld-OpenWorld.rbxl` contient la carte, le streaming activé, le parc des neuf prototypes en
métropole et le point d'apparition voisin. Comportement en jeu **non encore vérifié** (`docs/QA_BACKLOG.md` §3).

## Collection, propriétés et garages (lot 0.4)

Touche **P** (manette : **Select**) : panneau provisoire (collection, véhicule, propriétés, préparation,
configurations, invitations) et badge d'état de sauvegarde. En développement, chaque joueur reçoit une propriété
gratuite et des données **synthétiques** (trois prototypes, une propriété moyenne, une pièce de chaque type),
perdues à l'arrêt du serveur. Zone d'essai : entrée de propriété (repère bleu) et garage public (repère orange)
à l'ouest du point d'apparition.

## Économie et métiers (lot 0.5)

Touche **J** (manette : clic du stick droit) : portefeuille, réputation, métiers, concession, marché, immobilier
et services. Chaque opération financière affiche un devis, demande une confirmation et montre l'état réel renvoyé
par le serveur. En développement : 150 000 crédits synthétiques ; concession (repère jaune) et station-service
(repère vert) d'essai à l'ouest du point d'apparition. Simulation des revenus :
`lune run tools/economy/simulate.luau build/AutomotiveWorld.rbxlx`.

## Courses (lot 0.6)

Touche **K** (manette : clic du stick gauche) : parcours (du plus proche au plus lointain), épreuves ouvertes, salon
privé, entraînement, file classée, mon épreuve, classements, résultats. On rejoint une épreuve **sur place** : arrêté
sur la dalle violette d'inscription du parcours (ou à son départ), au volant de sa voiture sortie du garage
(entraînement : tout véhicule). Zone d'essai : une épreuve par discipline. Contrôle des parcours :
`lune run tools/racing/courses.luau build/AutomotiveWorld.rbxlx` ; simulation des gains :
`lune run tools/economy/simulate-races.luau build/AutomotiveWorld.rbxlx`.

## Interface, GPS et smartphone (lot 0.7)

| Action | Clavier | Manette |
|---|---|---|
| Téléphone (applications, mode rapide en roulant) | T | Select (lot 0.8 ; X reste à l'invite d'entrée) |
| Carte complète (destination, filtres) | M | via le téléphone |
| Garage et collection | P | via le téléphone |
| Économie et métiers | J | clic du stick droit |
| Courses | K | clic du stick gauche |
| Niveau du HUD (minimal, standard, complet) | H | via le téléphone |
| Effacer l'itinéraire | X | via le téléphone |
| Retour / fermer | Retour arrière | B (seulement quand un menu est ouvert) |

Les menus complets ne s'ouvrent qu'à l'arrêt ou à pied ; en roulant, le téléphone passe en mode rapide. Paramètres
(langue FR/EN, HUD, mini-carte, accessibilité, notifications, audio, raccourcis) : application Paramètres.

## Gamme, audio, radio, photo et arrivée (lot 0.8)

| Action | Clavier | Manette |
|---|---|---|
| Mode photo (à pied ou véhicule arrêté, jamais en course) | O | application Photo du téléphone |
| Dans le mode photo : déplacer / monter-descendre / orienter / interface | W A S D / Q E / flèches / I | stick gauche / — / stick droit / — |
| Monter en passager (propriétaire ou groupe) | E près de la portière droite | X |
| Radio (le conducteur choisit, chacun règle ou coupe son écoute) | application Radio du téléphone | idem |

- **Gamme proposée** : 18 modèles fictifs, achetables en développement seulement
  ([catalogue](docs/lot-0.8/CATALOGUE_18_VEHICULES.md)). Trois véhicules de départ proposés (Brio, Fil, Aster) :
  la liste officielle reste vide jusqu'à l'approbation du propriétaire.
- **Sons** : `python tools/audio/synth.py` produit 30 sons originaux dans `build/audio/` ; rien n'est téléversé, donc
  rien n'est joué en jeu et les stations de radio sont indisponibles
  ([ressources et licences](docs/lot-0.8/ASSETS_ET_LICENCES.md)).
- **Qualité graphique** (Paramètres → Graphismes) : basse, moyenne, haute
  ([direction artistique](docs/lot-0.8/DIRECTION_ARTISTIQUE.md)).
- **Parcours d'arrivée** : s'ouvre à la première connexion, passable ; consultable ensuite (application Guide).

## Commandes de conduite

| Action | Clavier | Manette |
|---|---|---|
| Accélérer | Z / W / ↑ | Gâchette droite (RT) |
| Freiner ; **reculer** (maintenir à l'arrêt ≈ 0,3 s) | S / ↓ | Gâchette gauche (LT) |
| Diriger | Q / A / ← et D / → | Stick gauche |
| Frein à main | Espace | A |
| Rapport supérieur / inférieur (manuelle, double embrayage, séquentielle) ; marche arrière : descendre depuis le neutre, à l'arrêt | Maj gauche / Ctrl gauche | RB / LB |
| Embrayage (boîte manuelle) | C | B |
| ABS / antipatinage / ESP (si le modèle en est équipé) | 1 / 2 / 3 | Croix gauche (choisir), croix droite (changer) |
| Niveau de récupération (électrique) | G | Croix gauche / droite |
| Caméra : proche, lointaine, cockpit, capot, pare-chocs | V | Croix haut |
| Remettre sur roues (véhicule immobile et renversé) | R | Croix bas |
| Sortir (sous 20 km/h) | F | Y |

Le HUD de développement (en bas à droite) affiche vitesse, rapport, régime, commandes effectives (dont
l'embrayage), énergie restante et consommation, état de chaque aide (absente / désactivée / activée / en action),
récupération, dégâts, caméra, la réduction du braquage avec la vitesse (A1) et deux **mesures locales
indicatives** : 0–100 km/h et 100–0 km/h. Les aides présentes sont **désactivées à chaque embarquement**.
Avec une boîte automatique, CVT ou à rapport unique, maintenir « freiner » à l'arrêt engage la marche arrière
(arbitrage A3) : en pente, utiliser le frein à main.

**Clavier et manette ensemble** : un seul périphérique pilote à la fois ; il prend la main sur une commande
« fraîche » (au repos puis sollicité). Une touche déjà enfoncée en montant dans le véhicule, un stick qui dérive ou
une gâchette effleurée ne produisent donc aucune commande. Le clavier est ignoré pendant la saisie de texte (chat)
et quand la fenêtre perd le focus ; une manette déconnectée est relâchée immédiatement (message à l'écran), sans
reprise automatique par l'autre périphérique.

## Vérifications locales (non intrusives)

```powershell
# Build Rojo + Selene + StyLua + tests Lune (hors Studio) + pytest.
powershell -ExecutionPolicy Bypass -File scripts\verify.ps1

# Idem avec l'analyse de types stricte luau-lsp (télécharge les définitions Roblox officielles dans .tooling\).
powershell -ExecutionPolicy Bypass -File scripts\verify.ps1 -DownloadRobloxTypes
```

Ces vérifications n'ouvrent aucune fenêtre et ne lancent pas Studio. **Elles ne remplacent pas les essais
en Studio** : la physique Roblox, le réseau, la caméra et l'interface n'y sont pas exécutés.
Détail des moyens et limites : [docs/lot-0.1/RAPPORT_TESTS.md](docs/lot-0.1/RAPPORT_TESTS.md).

## Tests dans Roblox Studio, via la VM (sans prendre ton PC)

```powershell
test-vm.cmd
```

Les essais Studio (solo, deux joueurs, latence, scénarios, deux expériences de collision, essais du lot 0.2) s'exécutent dans la VM
VMware de test ; ton bureau, ta souris et ton clavier ne sont pas utilisés. La VM ne voit que le dossier d'échange,
hors du dépôt. Préparation, permissions et fonctionnement : [docs/VM_TESTS.md](docs/VM_TESTS.md).

## Organisation du code

| Dossier | Contenu |
|---|---|
| `src/shared/Garage` | Catalogues et règles **purs** : propriétés, modules de garage, pièces, réglages, esthétique, starter, contrats économiques, protocole |
| `src/server/Persistence` | Profils versionnés, verrou de session, transactions, migrations, environnements, adaptateurs mémoire et DataStore |
| `src/shared/Economy` | Catalogue commercial (18 emplacements), barème provisoire, métiers, réputation, protocole économique |
| `src/server/Economy` | Portefeuille, commerce, marché et transferts multiprofils, missions, rémunération, service économique |
| `src/shared/Racing` | Disciplines, types et modes d'épreuve, parcours versionnés, rangs et saisons, protocole des courses |
| `src/shared/UI` | Localisation FR/EN (dont textes du lot 0.8 et traductions des panneaux), préférences, pile des écrans, raccourcis, conduite et interfaces, notifications |
| `src/shared/Assets`, `src/shared/Art` | Manifeste des ressources ; direction artistique (qualité, étalonnage, feux) |
| `src/shared/Audio`, `src/shared/Photo`, `src/shared/Onboarding` | Règles **pures** : audio moteur et ambiances, radio, mode photo, parcours d'arrivée et exercices |
| `src/server/Onboarding`, `src/server/Audio` | Parcours d'arrivée (essais, choix, protection d'apparition) ; radio (choix du conducteur) |
| `src/shared/Navigation` | Index et projection de la carte, itinéraires et guidage du GPS |
| `src/server/Social` | Groupes, partage de position, communications, préférences, points d'intérêt, téléphone tenu en main |
| `src/server/Racing` | Socle de compétition : parcours, salons, sessions, règles, drift, validation, classement, réservation, récompenses, classement compétitif, saisons, récupération, matchmaking, service des courses |
| `src/server/Progression` | Règles de collection, starter, propriétés, garages, préparation, invitations ; lieux, intérieurs, service des demandes |
| `src/shared/World` | Données de carte versionnées, réseau routier, mise en page, graphe (A*), feux, météo, trafic et piétons **purs** |
| `src/shared/Vehicles` | Types, définitions, dynamique **pure** (pneu, suspension, moteurs, boîtes, différentiels, aides, énergie, dégâts), adaptateur Roblox `VehicleSimulator`, codec réseau, mesures |
| `src/server` | Monde ouvert (parc, météo, trafic PNJ), zone d'essai, fabrique des véhicules, service autoritaire (embarquement, propriété réseau vérifiée, validation des mouvements, énergie, aides, dégâts confirmés serveur, médiation des collisions entre joueurs), limiteur de débit |
| `src/client` | Commandes clavier/manette (arbitrage des périphériques), caméras, animation des roues, HUD de développement, ambiance, feux, piétons, chargement anticipé |
| `tools/world` | Générateur hors ligne de la carte (Lune), habillage des sept zones |
| `tools/audio`, `tools/vehicles` | Synthèse des sons originaux (Python) ; banc d'essai de la gamme (Lune) |
| `places` | Configuration des deux places (développement, monde ouvert) |
| `tests/lune` | Tests exécutés par Lune sur la place construite par Rojo (modules purs + structure) |
| `tests/test_scaffold.py`, `tests/test_lot08.py` | Contrôles statiques Python ; manifeste et synthèse audio |
| `docs/lot-0.1` | Rapport de validation, rapport de tests, analyse des écarts et arbitrages, proposition du lot 0.2 |
| `docs/lot-0.2` | Rapport du lot 0.2 (mesures réelles), écarts, changements d'architecture |
| `docs/lot-0.3` | Rapport du lot 0.3, architecture du monde ouvert |
| `docs/lot-0.4` | Rapport du lot 0.4, architecture de la persistance et des garages |
| `docs/lot-0.5` | Rapport du lot 0.5, architecture de l'économie |
| `docs/lot-0.6` | Rapport du lot 0.6, architecture des courses et de la compétition |
| `docs/lot-0.7` | Rapport du lot 0.7, architecture de l'interface, du GPS et du social |
| `docs/lot-0.8` | Rapport du lot 0.8, architecture, catalogue des 18 modèles, ressources et licences, direction artistique |
| `docs/lot-0.9` | Validation globale, anomalies et corrections, performances, sécurité, checklist humaine, dépendances externes |
| `docs/QA_BACKLOG.md` | Registre unique des essais reportés et des anomalies ouvertes |
| `tools/vm` | Essais Studio dans la VM (hôte, agent, préparation, partage) |

Architecture détaillée : [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Gouvernance

Règles permanentes : [CLAUDE.md](CLAUDE.md).

- Le cahier des charges validé et les 33 décisions AUD font foi.
- Aucun code, modèle, interface, texture ni donnée de Collectverse ou Mimic Hunters n'est réutilisé ;
  la géométrie du prototype est générée par code à partir de primitives.
- Les crédits (lot 0.5) ne sont gagnés que par des activités mesurées par le serveur ; aucun achat Robux. La
  persistance n'écrit dans un DataStore que pour une
  expérience de test ou de production explicitement déclarée (aucune aujourd'hui).
- Aucun objectif (24 joueurs, ~60 FPS) n'est déclaré atteint : les premières mesures de coût du lot 0.2 ont été faites
  dans une VM sans accélération graphique, avec un seul joueur ; elles ne sont pas représentatives.
