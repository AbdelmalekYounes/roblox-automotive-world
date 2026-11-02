# Analyse des écarts — lot 0.1 par rapport au cahier des charges global v1.0

Légende : **Conforme** (dans le périmètre du lot) · **Partiel** · **Non commencé** (prévu dans un lot ultérieur,
le périmètre n'est pas réduit) · **À arbitrer** (choix de réalisation non tranché par le cahier des charges).
« Vérifié en Studio » signifie : contrôlé automatiquement dans Roblox Studio, dans la VM de test (149/149, voir
`RAPPORT_TESTS.md` §4) ; les commandes y sont injectées, la lecture réelle du clavier et de la manette ne l'est pas.

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
| §1.2 | Aides seulement si le modèle en dispose, désactivées par défaut, pas d'aide cachée | Conforme (aucune aide) — voir points à arbitrer A1/A2 |
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
| §3.4 / AUD-INPUT-01 | Indications selon le périphérique actif, pas d'action involontaire | Partiel — aide du HUD selon le dernier périphérique ; contrôles par défaut désactivés en conduite ; sortie bloquée au-dessus de 20 km/h |
| §3.5 | Désenlisement gratuit et limité, sans effet sur dégâts/carburant | Partiel — remise sur roues (immobile, renversé, délai 8 s) ; pas encore de désenlisement hors retournement |
| §7.1 | HUD vitesse, boîte, régime, alertes | Partiel — HUD **de développement** seulement ; pas d'alertes hiérarchisées ni de GPS |
| §7.4 / AUD-L10N-01 | Textes essentiels FR/EN | Partiel — messages serveur envoyés par clé ; textes en français uniquement |
| §8.1 | Simulation hybride, faux positifs sans sanction automatique | Conforme, vérifié en Studio — journalisation + repositionnement, aucune sanction |
| §8.5 / AUD-ENV-01 | Environnements isolés, données synthétiques, pas d'accès production | Conforme — aucune donnée, place non publiée, accès API à laisser désactivé |
| §10.2 | Premier spawn avec protections temporaires anti-collision | Non commencé (point d'apparition sans champ de force) |
| AUD-PERF-01/02 | 24 joueurs, ~60 FPS, percentiles de temps d'image | Non mesuré — aucune donnée de performance |
| AUD-WORLD-02 | Chargement prioritaire routes/collisions | Non commencé — streaming non configuré (zone unique de petite taille) |

## 3. Choix de réalisation à arbitrer

| # | Choix fait dans le lot 0.1 | Pourquoi | Alternative |
|---|---|---|---|
| A1 | Angle de braquage maximal réduit avec la vitesse (32° → 9° à 140 km/h), pour tous les périphériques | Rend clavier et stick pilotables sans braquages violents à haute vitesse | Le désactiver (`HighSpeedAngleDeg = MaxAngleDeg`) ou le réserver à certains périphériques ; à classer comme « filtre de commande » ou « aide » |
| A2 | Rampes progressives sur les touches clavier (0 → 100 % en 0,2 s) | Le clavier est tout-ou-rien ; évite des à-coups irréalistes | Rampes réglables par le joueur |
| A3 | Marche arrière par maintien de « freiner » à l'arrêt | Convention usuelle pour une boîte automatique au clavier/manette | Commande dédiée de sélection D/R |
| A4 | Sortie interdite au-dessus de 20 km/h | Évite une sortie involontaire en roulant | Autre seuil ou autre règle |
| A5 | Échelle 1 stud = 0,28 m et gravité « réelle » appliquée aux seuls véhicules | Cohérence physique sans modifier les sauts des personnages | Gravité globale réaliste pour tout le monde |
| A6 | Le serveur ne re-simule pas le véhicule piloté ; il contrôle seulement la plausibilité | Réactivité, coût serveur, recommandation de tolérance réseau | Re-simulation serveur partielle (coût CPU/latence) |

## 4. Limites techniques connues

- Essais Studio automatisés (avec captures) : clavier, manette, ressenti, collisions entre véhicules, bosse, slalom,
  remise sur roues d'un véhicule renversé et retour au plot restent à vérifier.
- Sous latence, la vue du client reste décalée ~0,5 s après une correction serveur avant de se recaler.
- Pas de frottement statique : un véhicule freiné sur une pente glisse très lentement (de l'ordre du cm/s selon le modèle).
- Un seul rayon par roue : une roue peut « tomber » dans un interstice ou accrocher une arête vive ; un balayage de
  forme (shapecast) est proposé pour le lot 0.2.
- Inertie du châssis approximée par un bloc homogène (inertie de roulis inférieure à celle d'une voiture réelle).
- Vitesse de pointe non mesurée en jeu ; le freinage en jeu (≈ 47,5 m) est plus long que dans le modèle planaire (40,2 m).
- La validation serveur ne détecte ni le vol, ni le passage à travers les murs, ni les trajectoires impossibles à vitesse plausible.
- Coût réseau des véhicules stationnés simulés par le serveur : limité par seuils et mise en sommeil, **non mesuré**.
