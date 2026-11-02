# Analyse des écarts — lot 0.1 par rapport au cahier des charges global v1.0

Légende : **Conforme** (dans le périmètre du lot) · **Partiel** · **Non commencé** (prévu dans un lot ultérieur,
le périmètre n'est pas réduit) · **À arbitrer** (choix de réalisation non tranché par le cahier des charges).
« Vérifié en Studio » signifie : contrôlé automatiquement dans Roblox Studio, dans la VM de test (voir
`RAPPORT_VALIDATION.md`) ; les commandes y sont injectées, la lecture réelle du clavier et de la manette ne l'est pas.

## 1. Exigences du lot 0.1 (prompt de lot)

| Exigence | État | Commentaire |
|---|---|---|
| Une seule voiture fictive, originale, géométrie temporaire | Conforme | Prototype P-01 généré par code (blocs/cylindres), aucun actif Marketplace ni externe |
| Zone d'essai simple et isolée | Conforme | Sol fermé par murets, ligne droite graduée, slalom, cercle de 30 m, bosse à 10 % |
| Clavier et manette | Conforme, **non vérifié en jeu** | Mapping documenté ; tests Studio par commandes injectées ; volant non traité |
| Direction, accélération, freinage, marche arrière, caméra proche/lointaine | Conforme, vérifié en Studio | Marche arrière par maintien de « freiner » à l'arrêt |
| Masse, inertie, freinage, adhérence ; pas de vitesse instantanée | Conforme, vérifié en Studio | ≈ 14,5 km/h après 1 s, 0–100 km/h ≈ 8,5 s, 100–0 ≈ 47,5 m mesurés dans le moteur |
| Paramètres isolés par modèle | Conforme | `Definitions/PrototypeP01.luau`, validés et gelés |
| Architecture compatible FWD/RWD/AWD, thermique/électrique, transmissions, aides | Partiel | Points d'extension typés ; seuls RWD + thermique + automatique sont implémentés ; le reste est **refusé** par la validation |
| Conduite réactive client, validation serveur, tolérance réseau | Conforme, vérifié en Studio | Propriété réseau au conducteur, téléportation corrigée sans sanction, aucune fausse correction sous ~205 ms de latence |
| Plusieurs joueurs sans écrasement d'état | Conforme, vérifié en Studio | Deux clients, deux véhicules, véhicule occupé refusé ; défaut de sortie en multijoueur trouvé et corrigé |
| Aucun crédit, possession, achat, DataStore, récompense | Conforme | Vérifié par motifs interdits (Lune + pytest) ; identifiant de session `essai-…` non persistant |
| Séparation client / serveur / partagé | Conforme | Vérifiée par tests (structure de place, règles pytest) |
| Luau typé, commentaires en français | Conforme | `--!strict` sur tous les modules ; 0 erreur luau-lsp |
| Pas de dépendances opaques | Conforme | Aucune bibliothèque tierce dans le jeu ; outils de dev épinglés |

## 2. Cahier des charges global — chapitres concernés

| Réf. | Exigence | État lot 0.1 |
|---|---|---|
| §1.2 | Univers et véhicules fictifs originaux | Conforme |
| §1.2 | Physique différenciée par véhicule, pas d'arcade uniforme | Partiel — moteur paramétrable par modèle, mais un seul modèle existe ; différenciation non démontrée |
| §1.2 | Aides seulement si le modèle en dispose, désactivées par défaut, pas d'aide cachée | Conforme (aucune aide) ; réduction de braquage et rampes clavier arbitrées comme non-aides et affichées (A1, A2) |
| §1.2 | PC et console prioritaires | Partiel — clavier/souris et manette ; aucun essai sur console |
| §3.2 | Propulsion / traction / 4 roues motrices | Partiel — RWD implémenté ; calcul FWD/AWD présent mais non exercé |
| §3.2 | Masse, couple, régime, suspension, adhérence, état de route | Partiel — tous présents ; état de route limité à un multiplicateur par matériau |
| §3.2 | Boîtes automatique, manuelle, double embrayage, séquentielle, CVT | Partiel — automatique simplifiée seulement |
| §3.2 | Thermique et électrique | Partiel — thermique seulement, sans consommation |
| §3.2 | Grip sec/pluie, transfert de charge | Partiel — transfert de charge émergent de la physique 3D (non mesuré) ; pluie non commencée |
| §3.2 / AUD-PHYS-01 | Commandes réactives, contrôles serveur des états critiques, sans punir la latence | Conforme, vérifié en Studio — contrôle grossier (vitesse, déplacement, valeurs non finies) ; collisions et trajectoires murales non contrôlées |
| §3.3 | Dégâts 3 niveaux, effets mécaniques, persistance | Non commencé (lot 0.2 proposé) |
| §3.3 | Carburant / énergie consommés et sauvegardés | Non commencé |
| §3.4 | Caméras proche/lointaine | Conforme, vérifié en Studio (distances et captures) |
| §3.4 | Cockpit, capot, pare-chocs, mode photo | Non commencé |
| §3.4 / AUD-INPUT-01 | Indications selon le périphérique actif, pas d'action involontaire | Partiel — un seul périphérique actif, sur commande fraîche ; clavier ignoré en saisie de texte et sans focus ; manette déconnectée relâchée ; contrôles par défaut désactivés en conduite ; sortie bloquée au-dessus de 20 km/h. Logique testée hors Studio ; **lecture réelle des périphériques non vérifiée** (essai humain) |
| §3.5 | Désenlisement gratuit et limité, sans effet sur dégâts/carburant | Partiel — remise sur roues (immobile, renversé, délai 8 s) ; pas encore de désenlisement hors retournement |
| §7.1 | HUD vitesse, boîte, régime, alertes | Partiel — HUD **de développement** seulement ; pas d'alertes hiérarchisées ni de GPS |
| §7.4 / AUD-L10N-01 | Textes essentiels FR/EN | Partiel — messages serveur envoyés par clé ; textes en français uniquement |
| §8.1 | Simulation hybride, faux positifs sans sanction automatique | Conforme, vérifié en Studio — journalisation + repositionnement, aucune sanction |
| §8.5 / AUD-ENV-01 | Environnements isolés, données synthétiques, pas d'accès production | Conforme — aucune donnée, place non publiée, accès API à laisser désactivé |
| §10.2 | Premier spawn avec protections temporaires anti-collision | Non commencé (point d'apparition sans champ de force) |
| AUD-PERF-01/02 | 24 joueurs, ~60 FPS, percentiles de temps d'image | Non mesuré — aucune donnée de performance |
| AUD-WORLD-02 | Chargement prioritaire routes/collisions | Non commencé — streaming non configuré (zone unique de petite taille) |

## 3. Arbitrages A1 à A6 (orientations du propriétaire, 2 novembre 2026)

Ces choix, d'abord laissés « à arbitrer », ont été tranchés par le propriétaire du projet. Ils sont appliqués dans
le lot 0.1 tels que décrits ci-dessous ; les modifier relève d'un nouvel arbitrage.

| # | Orientation retenue | Mise en œuvre dans le lot 0.1 | Limites | Conséquences pour les lots futurs |
|---|---|---|---|---|
| A1 | Braquage maximal évoluant selon la vitesse, paramétré par véhicule, sans assistance électronique cachée | `Steering.MaxAngleDeg`, `HighSpeedAngleDeg`, `HighSpeedReferenceKmh` dans chaque définition (P-01 : 32° à l'arrêt → 9° à 140 km/h) ; loi **linéaire de la seule vitesse** (`VehicleDynamics.maxSteerAngle`), sans mesure de glissement, de lacet ni de dérive ; identique pour clavier et manette ; **affichée dans le HUD** ; tests Lune (bornes, décroissance, symétrie) | Valeurs du P-01 non validées par un essai humain ; loi unique, non réglable par le joueur ; un volant (non traité) pourrait demander une autre loi | Chaque modèle fournit ses trois valeurs ; toute correction dépendant du glissement ou du lacet serait une aide (ESP) et devra être déclarée dans `Aids`, désactivée par défaut |
| A2 | Rampes progressives conservées pour les touches numériques | `InputArbiter` : pédales 0 → 100 % en 0,2 s (retour en 0,125 s), direction 3,2 /s (retour 5 /s) ; gâchettes et stick restent proportionnels ; tests Lune | Rampes fixes ; pas de réglage joueur ; ressenti non évalué par un humain | Un réglage joueur pourra être exposé (options) sans changer les valeurs par défaut sans arbitrage |
| A3 | Marche arrière par maintien du frein pour une boîte automatique ; interfaces distinctes prévues pour les autres boîtes | Comportement de l'automatique inchangé ; types `ReverseEngagement` et `GearSelectorCommand` (`VehicleTypes`) ; `VehicleDefinitions.reverseEngagement` : automatique, CVT et rapport unique → maintien du frein ; manuelle, double embrayage, séquentielle → sélecteur ; tests Lune | Le sélecteur n'est **pas câblé** (ni touches, ni réseau, ni simulation) ; toute boîte non automatique reste refusée par la validation | Le lot qui introduira les boîtes manuelles branchera `GearSelectorCommand` (touches et boutons dédiés, champs ajoutés à `DriverInput` et au codec réseau) sans modifier l'automatique |
| A4 | Seuil provisoire de sortie : 20 km/h | `Limits.ExitMaxSpeedKmh = 20` (P-01), contrôlé par le **serveur** (vitesse observée côté serveur) ; test Lune et essai Studio (sortie refusée en roulant) | Provisoire ; même valeur pour tout modèle à ce stade ; pas de sortie d'urgence | À reconfirmer après les essais humains ; réglable par modèle si nécessaire |
| A5 | Conversion physique propre aux véhicules, gravité globale inchangée | 1 stud = 0,28 m ; forces calculées en SI puis converties ; compensation de gravité par véhicule (9,81 m/s² ressentis) ; `Workspace.Gravity` inchangée pour les personnages | Les objets qui ne sont pas des véhicules (cônes, personnages, décors mobiles) restent à la gravité Roblox : leurs interactions avec un véhicule ne sont pas « à l'échelle » ; la conversion suppose 0,28 m/stud pour tous les décors | Tout nouvel objet physique lié aux véhicules (remorques, débris, dégâts) doit utiliser la même conversion ; les calculs de collisions et de dégâts se font en SI |
| A6 | Simulation hybride : propriété réseau au conducteur, validation contextuelle serveur | Propriété **vérifiée** (`NetworkOwnership`, attribut `SimulationOwnerUserId`) ; véhicules stationnés simulés par le serveur ; plausibilité des mouvements (`MovementRules`) ; contacts entre véhicules de deux joueurs **confirmés par le serveur** avec complément d'impulsion (`CollisionMediator`) ; aucune sanction automatique | Le serveur ne re-simule pas le véhicule piloté : il borne et corrige, il ne garantit pas une trajectoire exacte ; un client modifié peut ignorer un complément d'impulsion (constaté et journalisé, sans sanction) ; le percuteur est arrêté net dans sa propre simulation (§4) | Les dégâts (lot 0.2) seront appliqués **après** confirmation serveur du contact, par le même médiateur ; la charge serveur et réseau à 24 joueurs reste à mesurer (AUD-PERF-01) |

@@COLLISIONS@@
## 5. Limites techniques connues

- Essais Studio automatisés (avec captures) : clavier, manette et ressenti restent à vérifier par un humain.
- Collisions entre véhicules : voir §4.5.
- Sous latence, la vue du client reste décalée ~0,5 s après une correction serveur avant de se recaler.
- Pas de frottement statique : un véhicule freiné sur une pente glisse très lentement (de l'ordre du cm/s selon le modèle).
- Un seul rayon par roue : une roue peut « tomber » dans un interstice ou accrocher une arête vive ; un balayage de
  forme (shapecast) est proposé pour le lot 0.2.
- Inertie du châssis approximée par un bloc homogène (inertie de roulis inférieure à celle d'une voiture réelle).
- Vitesse de pointe non mesurée en jeu ; le freinage en jeu (≈ 47,5 m) est plus long que dans le modèle planaire (40,2 m).
- La validation serveur ne détecte ni le vol, ni le passage à travers les murs, ni les trajectoires impossibles à vitesse plausible.
- Coût réseau des véhicules stationnés simulés par le serveur : limité par seuils et mise en sommeil, **non mesuré**.
