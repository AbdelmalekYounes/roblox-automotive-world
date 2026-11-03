# Rapport du lot 0.6 — courses, matchmaking, compétition et saisons

Branche `feat/racing-competition-0.6`, créée depuis `c0c458b` (dernier commit du lot 0.5), PR brouillon vers
`feat/economy-progression-0.5`. Aucune branche précédente ni `main` n'a été modifiée.

Décision du propriétaire : essais humains, longues campagnes multijoueurs et tests de charge reportés au lot QA. Ce
lot comporte les contrôles rapides, des tests purs ciblés sur des échantillons SYNTHÉTIQUES et l'adaptateur
MÉMOIRE, et deux courtes sessions de démarrage dans la VM. **Aucune course n'a été jouée en conduite réelle ; le
matchmaking inter-serveurs, la persistance DataStore et les collisions de compétition sous latence ne sont pas
validés** (`docs/QA_BACKLOG.md`, §3 quater).

## 1. État des livrables

Légende : **Implémenté** (code complet, logique testée hors Studio) ; **Partiel** (une partie manque, précisée) ;
**Simulé** (comportement représenté sans le système réel) ; **NON TESTÉ** (aucune exécution en jeu).

| # | Livrable | État | Précisions |
|---|---|---|---|
| 1 | Architecture commune des courses | Implémenté | Un socle (`src/server/Racing`) pour les six disciplines ; règles propres dans `RaceDefinitions` ; aucun contrôleur physique nouveau |
| 2 | Six disciplines selon leurs règles | Implémenté | Sprint, circuit, contre-la-montre, drift (score physique), drag (arbre, réaction), rallye (pénalités). Jouées en jeu : NON TESTÉ |
| 3 | Parcours intégrés au monde ouvert | Implémenté | 16 parcours versionnés (motorsport, métropole, périphérique, cols, campagne, littoral) + 6 en zone d'essai, validés sur le graphe routier |
| 4 | Grilles, feux, départs et arrivées | Implémenté | Installations construites par code ; pose sur le relief : NON TESTÉE visuellement (QA-R16) |
| 5 | Salons officiels et privés | Implémenté | Officielle, classée (par la file, places réservées), privée et entraînement (organisateur : tours, participants, modes) |
| 6 | Modes réaliste et protégé | Implémenté | Restauration exacte en protégé ; persistance en réaliste. En jeu : NON TESTÉ |
| 7 | Réservations sécurisées des véhicules | Implémenté | Réservation « Race » durable, opérations incompatibles refusées, échéance sûre |
| 8 | Matchmaking inter-serveurs et repli local | Partiel | Repli local implémenté et testé (Lune) ; adaptateur MemoryStore / serveur réservé / téléportation ÉCRIT mais jamais exécuté (aucune expérience de test déclarée) : **NON TESTÉ**, rien n'affirme qu'il fonctionne |
| 9 | Chronométrage et validation serveur | Implémenté | Échantillons serveur à 10 Hz, horloge serveur, franchissement de ligne interpolé, arrivées « non confirmées » sans sanction |
| 10 | Récompenses idempotentes | Implémenté | Transaction unique par participant + garde durable `Racing.Applied` ; résultats publiés avant application |
| 11 | Classements compétitifs | Partiel | Échelles « Race » (Elo) et « Drift » ; tableaux en MÉMOIRE (serveur unique) ; tableaux durables (OrderedDataStore) dans l'adaptateur NON TESTÉ |
| 12 | Saisons de huit semaines | Implémenté | Rangs Bronze → Diamant distincts de la réputation, transition, récompense unique, historique |
| 13 | Reconnexion et récupération | Partiel | Même serveur dans la fenêtre de ~90 s, résultats publiés réconciliés, engagement échu résolu ; reprise après transfert inter-serveurs : NON TESTÉE |
| 14 | Interfaces provisoires clavier/manette | Implémenté | Panneau K / stick gauche, affichage de course compact. NON TESTÉ par un humain |
| 15 | Tests essentiels et résultats factuels | Ce rapport, §2 |
| 16–19 | Rapport, architecture, registre QA, feuille de route | `RAPPORT_LOT_0.6.md`, `ARCHITECTURE_LOT_0.6.md`, `docs/QA_BACKLOG.md` §3 quater, `docs/ROADMAP.md` |

## 2. Vérifications exécutées

### 2.1 Hors Studio

`powershell -ExecutionPolicy Bypass -File scripts\verify.ps1 -RobloxTypes .tooling\globalTypes.d.luau`, exécutée le
2026-11-03 à 11:21 sur l'arbre de travail du lot (base `c0c458b` + modifications du lot, non encore commitées) :
Rojo (deux places), Selene, StyLua, pilote Studio, **Lune 290 réussis / 0 échoué** (dont 26 nouveaux du lot 0.6),
génération de la carte, **Pytest 10 réussis**, luau-lsp strict 0 erreur.

Tests du lot 0.6 (`tests/lune/specs/Lot06Racing.luau`), numérotés comme dans la demande :

| # | Cas | Résultat |
|---|---|---|
| 1 | Les six disciplines | OK : les 6 épreuves d'essai se courent jusqu'à un temps officiel (drift : score) et se ferment |
| 2 | Points de contrôle et tours | OK : 3 tours, tour lancé ≈ longueur / vitesse, meilleur tour ; raccourci : arrivée non validée ; rallye : hors tracé pénalisé (≈ 3 s pour 6 s hors couloir) |
| 3 | Faux départs | OK : +5 s sur la grille ; drag : manche invalidée (feu rouge) ; retardataire : aucune pénalité |
| 4 | Départs synchronisés | OK : même instant serveur sur la grille, départs individuels espacés de 20 s, inscriptions fermées |
| 5 | Calcul des temps | OK : drag 201 m à 25 m/s après 0,3 s : 8,34 s interpolés (± 0,02 s), réaction et vitesse d'arrivée |
| 6 | Scoring drift | OK : dérive de 35° à 43 km/h marque ; rotation à l'arrêt et sur-rotation = 0 ; enchaînement mieux payé ; choc et sortie de zone font perdre la figure |
| 7 | Classement de plusieurs participants | OK : ordre au temps officiel avec pénalités ; arrivée corrigée par le serveur = « non confirmée », sans place |
| 8 | Abandons | OK : sans place ni crédit, battu au classement |
| 9 | Réservation exclusive | OK : un seul engagement, véhicule sorti obligatoire, véhicule en annonce refusé, profil valide |
| 10 | Refus pendant la course | OK : reprise, vente/annonce/transfert, pièces, réglages, réparation, lavage, énergie, rangement, seconde sortie |
| 11 | Restauration exacte du mode protégé | OK : dégâts de course effacés, dégâts antérieurs conservés, énergie et kilométrage restaurés |
| 12 | Persistance du mode réaliste | OK : dégâts et consommation conservés |
| 13 | Récompenses des deux modes | OK : les deux rémunérés ; réaliste − coûts estimés ≈ protégé (± 2 crédits) |
| 14 | Entraînement sans récompense | OK : entraînement 0 ; privée non éligible 0 ; privée éligible faible et plafonnée (3/h) ; entraînement toujours protégé |
| 15 | Paiements idempotents | OK : rejoué, journal purgé (garde durable), réponse perdue après écriture : un seul versement |
| 16 | Classement séparé de la réputation | OK : réputation inchangée ; aucun nom commun ; gains répétés face au même adversaire réduits mais positifs |
| 17 | Transitions de saison | OK : archive, rang Platine récompensé une fois, réinitialisation de moitié ; sous 10 épreuves : rien |
| 18 | Déconnexion avant les résultats | OK : fenêtre, puis « Disconnected » : aucun gain, aucune variation classée |
| 19 | Reprise sans doublon | OK : reprise au dernier point validé, pas de seconde reprise ; résultat publié appliqué une fois ; engagement échu : état initial restauré, aucun véhicule créé |
| 20 | Normalisation météo | OK : classée normalisée (`Sec-v1`), privée et route ouverte dynamiques ; record seulement en conditions normalisées |

Tests complémentaires : validité des 22 parcours (routes enchaînées, longueur, zone, revêtements) et refus d'une route
inconnue, de routes non enchaînées et d'une boucle ouverte ; salons (inscription unique, participation simultanée,
même véhicule, salons privés non listés) ; matchmaking (groupes par niveau, confirmation, expiration, double ticket) ;
migration du profil v2 → v3.

Contrôle des parcours (`lune run tools/racing/courses.luau build/AutomotiveWorld.rbxlx`, même jour) : 22 / 22 OK.
Il a d'abord relevé mes propres erreurs de saisie (longueurs déclarées, zone du périphérique), corrigées avec les
valeurs mesurées.

Simulation d'équilibrage (`lune run tools/economy/simulate-races.luau build/AutomotiveWorld.rbxlx 0.8 4`, même jour,
performance 0,8, 4 participants) : **8 154 à 11 164 crédits par heure de course** en mode protégé selon le parcours,
contre **12 283** en moyenne pour les métiers (0,66 à 0,91 fois les métiers) ; net du mode réaliste ≈ protégé ;
avec 75 s hors course par épreuve : 1 719 (drag, manches très courtes) à 8 522 crédits par heure. Valeurs de
modèle, pas des mesures en jeu.

### 2.2 Contrôles de démarrage dans Studio (VM)

| Tâche | Session | Résultat |
|---|---|---|
| `20261103-110953` | `lot04` (place de développement, 2 joueurs) | 6 réussis / 7 échecs → **défaut trouvé** : `RaceService` lisait l'environnement des profils avant le démarrage de `ProfileService` ; l'erreur arrêtait l'amorçage du serveur (aucun profil, aucun canal) |
| `20261103-111939` | `lot04` après correction | **65 / 0** : 6 points d'inscription, canal des courses, aucune erreur d'exécution |
| `20261103-112132` | `monde` (monde ouvert, après correction) | **35 / 0** : 16 points d'inscription, canal des courses, aucune erreur d'exécution, conduite à 123 km/h sur l'autoroute |

Correction : l'adaptateur inter-serveurs est créé à la première utilisation (après `ProfileService.start`).

Ces sessions vérifient le chargement, pas les courses : **aucune épreuve n'a été courue dans Studio** (QA-R10).

## 3. Écarts, choix et points à arbitrer

1. **Inter-serveurs** : `CrossServerAdapter` (MemoryStore, serveur réservé, téléportation, OrderedDataStore) est le
   seul module autorisé à ces API ; les garde-fous Lune (`PlaceStructure`) et pytest (`test_scaffold.py`) ont été
   élargis à CE seul fichier, de façon explicite. Il n'est instancié que si une expérience Test/Prod est déclarée
   (aucune) : jamais exécuté. Une expérience de test isolée sera nécessaire pour l'éprouver (accord du propriétaire).
2. **Barème** : tarifs par discipline (185 à 215 crédits par minute de référence), coûts estimés du mode réaliste
   (énergie 3 cr/km, usure 20 à 60 cr/km), privées × 0,2, récompenses de saison (2 000 à 30 000) : provisoires.
   Les courses rapportent un peu moins que les métiers par heure (choix prudent pour ne pas rendre les métiers
   inutiles) ; à arbitrer.
3. **Drag** : manches très courtes ; avec le temps d'inscription, le gain horaire est faible. Enchaînement de manches
   dans un même salon : non implémenté (proposition).
4. **Classement compétitif** : seuils des rangs (1 100 / 1 250 / 1 450 / 1 700 points), K = 32, réinitialisation de
   moitié, minimum de 10 épreuves pour la récompense, origine de saison (2 novembre 2026 UTC) : provisoires.
5. **Privées** : rémunérées seulement aux paramètres officiels (tours) et à au moins deux participants ; décision
   d'éligibilité automatique, sans réglage d'organisateur.
6. **Records** : seulement sur les parcours sans circulation ; les sprints sur routes ouvertes n'ont pas de record
   (circulation PNJ non maîtrisable). Les épreuves classées sur route ouverte restent comparables entre adversaires
   d'une même épreuve.
7. **Reprise après reconnexion** : rematérialisation au dernier point validé (exception explicite à « pas de
   téléportation ») ; refusée pour une manche de contre-la-montre ou de drag déjà commencée (équité).
8. **Non confirmés** : une arrivée non confirmée reste « à réconcilier » ; aucun outil de modération ne la confirme
   aujourd'hui (proposition pour un lot ultérieur).
9. **Entraînement** : autorisé avec un véhicule de la flotte d'essai, sans aucune écriture durable.
10. Version de développement inchangée (`0.4.0-dev`) : à passer en `0.6.0-dev` à la clôture si souhaité.

Anomalies connues des lots précédents : non corrigées ni retestées dans ce lot (`docs/QA_BACKLOG.md` §1). Elles sont
prises en compte par la validation des résultats (position figée, corrections → « non confirmé »).

## 4. Antifraude (résumé)

Aucun résultat, temps ou score accepté du client ; échantillons et horloge serveur ; inscription physique au point
du parcours, arrêté, au volant de son propre véhicule ; une épreuve et une voiture à la fois ; points de contrôle
obligatoires dans l'ordre (franchissement de ligne) ; hors tracé pénalisé ; faux départs ; vitesse moyenne plausible
entre deux points ; corrections de mouvement → non confirmé (sans sanction) ; drift sans points à l'arrêt ni en
sur-rotation ; minutes de référence (rouler lentement ne paie pas) ; répétitions dégressives et plafond horaire ;
privées plafonnées ; anti-arrangement du classement (gains réduits, signalement) ; limiteur de débit ; identifiants
de demande ; transactions idempotentes.
