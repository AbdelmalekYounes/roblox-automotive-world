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

## 4. Collisions entre véhicules (AUD-PHYS-01, AUD-COLL-01)

### 4.1 Cause mesurée de la poussée faible et variable

Expérience reproductible (`test-vm.cmd -Sessions collision,collision_latence`) : 6 impacts latéraux à 19,5 km/h,
alternant véhicule percuté **conduit** par le joueur 2 (frein à main) et véhicule **garé** (simulé par le serveur),
même mise en place, sans latence puis avec 100 ms de délai dans chaque sens. Mesures du serveur et des deux clients.

Avant correction (tâche `20261102-164243`) :

| Mesure | Percuté conduit | Percuté garé |
|---|---|---|
| Propriétaires au contact (relevés par le serveur) | joueur 1 percute joueur 2 | joueur 1 percute serveur |
| Déplacement final du percuté (vue serveur), 0 ms | 0,45 / 0,65 / 0,22 st | 3,19 / 3,46 / 7,10 st |
| Idem, 100 ms | 1,09 / 0,08 st (+ 1 essai sans contact, voir §4.5) | 3,58 / 3,11 / 4,62 st |
| Vitesse du percuteur 0,5 s après le contact | **0,05 à 0,09 km/h** (arrêté net) | 8 à 9,5 km/h (pousse le véhicule) |
| Vitesse de la copie du percuteur vue par le client percuté, au plus près | 0,7 à 7,4 st/s (−1,9 sous latence) | — |
| (vitesse réelle du percuteur à l'impact) | 19,4 st/s | 19,4 st/s |

**Cause.** Avec la propriété réseau au conducteur (A6), le contact entre deux véhicules de joueurs différents est
résolu **deux fois, séparément** : chez le percuteur, contre une copie répliquée du véhicule percuté, que sa
simulation traite comme un obstacle piloté par le flux réseau (le véhicule « ne bouge pas » chez lui : le percuteur
s'arrête net) ; chez le client percuté, contre une copie du percuteur qui arrive avec deux trajets réseau de retard
(percuteur → serveur → percuté), donc **déjà arrêtée** à son contact : elle ne transmet presque rien. La quantité
de mouvement perdue par le percuteur n'est transmise à personne. La variabilité vient de l'instant où les paquets
répliqués encadrent le contact. Contre un véhicule garé, la boucle est plus courte (percuteur ↔ serveur) : le
serveur pousse le véhicule garé, le percuteur le voit s'écarter et continue.

### 4.2 Correction (sans téléportation ni sanction)

- `server/Vehicles/CollisionMediator` confirme le choc **à partir des seules observations du serveur** (positions
  répliquées, jamais une valeur envoyée par un client) : contact des boîtes englobantes, percuteur en approche,
  rapprochement réel et décélération du percuteur.
- Il calcule la variation de vitesse due au véhicule percuté (`shared/Vehicles/Physics/CollisionExchange`) :
  jamais plus que la quantité de mouvement réellement perdue par le percuteur, et jamais plus que le **choc de
  carrosseries** attendu à la vitesse de rapprochement observée ((1 + e)·mS/(mS + mT)·v, restitution e = 0,3).
  Un client ne peut donc pas déclencher une poussée plus forte qu'un vrai choc à vitesse plausible.
- Le propriétaire du véhicule percuté applique seulement le **complément** non reçu dans sa propre simulation
  (`ApplyImpulseAtPosition` au point de contact) : pas de double comptage, rien n'est jamais retiré (choc frontal).
- Le serveur vérifie ensuite que le véhicule a réagi ; sinon il journalise, sans sanction (prudence sans immunité).
- Le serveur suit le choc pendant 0,7 s et renvoie la variation de vitesse **totale** attendue quand elle augmente ;
  le client n'applique que ce qui lui manque, donc les envois successifs ne se cumulent pas.
- Véhicules simulés par le serveur : vitesse horizontale et montée plafonnées à la borne physique d'un choc
  (2 × vitesse du véhicule le plus rapide à proximité + 3 m/s, sans croissance au-delà), chute libre, pour neutraliser
  les **éjections numériques** mesurées (véhicule garé projeté à 79, 250 puis 440 st après un choc à 20 km/h) ;
  seule la vitesse est corrigée, jamais la position.
- À chaque attribution de la propriété, le serveur publie la position qui fait foi (`SimulationPivot`) ; le client
  recale sa copie locale si elle s'en écarte de plus de 3 st (aucun recalage n'a été nécessaire dans les mesures).

### 4.3 Résultats mesurés après correction

Commit `7ae0c60`, tâche `20261102-180955` (mêmes 6 essais par session ; déplacement final du véhicule percuté, vue serveur) :

| Session | Percuté conduit | Percuté garé | Δv demandé par le serveur | Corrections serveur |
|---|---|---|---|---|
| `collision` (0 ms) | 3,89 / 4,44 / 3,54 st | 5,64 / 3,09 / 7,34 st | 3,56 à 3,87 m/s | 0 |
| `collision_latence` (100 ms par sens) | 3,45 / 3,13 / 3,59 st | 3,34 / 4,69 / 5,62 st | 3,47 à 3,72 m/s | 0 |

Avant correction, le véhicule conduit était déplacé de 0,08 à 1,09 st ; il l'est maintenant de 3,1 à 4,4 st, dans
la plage du véhicule garé (critère automatisé : entre 0,5 et 2,5 fois la médiane « garé », vérifié à chaque essai).
Chaque essai « conduit » a donné exactement un échange confirmé, aucun essai « garé » n'en a déclenché ; aucune
impulsion « non constatée », aucune correction de mouvement.

Itérations mesurées pendant la mise au point (toutes conservées dans `RAPPORT_VALIDATION.md`) : première version
(Δv calculé trop tôt, 1 à 1,8 m/s, et échange parasite en sens inverse) ; conservation pure (le percuté glissait
8 à 14,7 st, 2 à 3 fois plus qu'un véhicule garé : choc « élastique ») ; borne de restitution e = 0,3 retenue.
Éjections de véhicules garés par la physique serveur : 79 st, 250 st puis 440 st mesurés ; une première borne
(croissance de 50 m/s² admise) a été contournée par une poussée soutenue ; la borne finale n'admet plus de
croissance au-delà du choc (plus grand déplacement transitoire mesuré ensuite : 16,5 st, final 4,7 st).

### 4.4 Différences physiques légitimes entre véhicule garé et véhicule conduit

| Aspect | Véhicule garé | Véhicule conduit | Légitime ? |
|---|---|---|---|
| Qui simule | le serveur | le client du conducteur (A6) | Oui : choix d'architecture |
| Freins | frein à main serré, moteur coupé | ce que fait le conducteur (dans l'expérience : frein à main) | Oui |
| Masse | véhicule seul | véhicule + personnage assis (soudé au véhicule) | Oui, faible écart |
| Résolution du contact | une seule simulation (serveur) avec la copie du percuteur | deux simulations + complément confirmé serveur | Écart résiduel : voir ci-dessous |
| Percuteur après le choc | continue en poussant (~8 à 12 km/h après 0,5 s) | **s'arrête net** dans sa propre simulation | **Non** : limite connue (le véhicule percuté reçoit la quantité de mouvement, mais le percuteur ne la conserve pas) |
| Délai de la poussée chez le percuté | un trajet réseau | deux trajets réseau + confirmation serveur (~0,1 à 0,4 s) | Oui, inhérent à la latence |

### 4.5 Limites restantes

- Le percuteur s'arrête net contre le véhicule d'un autre joueur (au lieu de continuer à ~moitié de sa vitesse) :
  corriger cela demanderait de déplacer la simulation pendant le choc (propriété réseau temporaire), proposé au lot 0.2.
- La normale de contact est approchée par la direction entre les centres : un choc décentré ou en angle produit une
  poussée moins exacte (rotation comprise, via le point d'application).
- Un client modifié peut ignorer le complément : l'écart est constaté et journalisé, sans sanction automatique.
- Seuls des chocs latéraux à 20 km/h sont automatisés ; chocs frontaux, à haute vitesse, à plus de deux véhicules : non testés.
- **Anomalie intermittente non expliquée** : dans 6 des 17 sessions de collision exécutées (tâches `164243`,
  `170653` ×2, `171642` ×2, `182028`), un essai sur six n'a pas eu lieu : le véhicule du joueur 1, réembarqué juste
  après un repositionnement par le serveur de test, ne bougeait pas (ou percutait autre chose) chez son client, puis
  était corrigé (« Teleport », sans sanction). Même famille qu'un client qui ne simule pas son véhicule pourtant
  attribué (`RAPPORT_VALIDATION.md` §5.1). Le recalage sur la position serveur a été ajouté sans s'être déclenché ;
  cause non établie.
- Un véhicule garé percuté peut encore se déplacer vite pendant un instant (16,5 st au plus, mesuré) avant de
  retomber dans la borne.

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
