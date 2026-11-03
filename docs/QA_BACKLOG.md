# Registre QA — essais reportés et anomalies ouvertes

Registre **unique** des essais non effectués et des anomalies non résolues des lots 0.1 à 0.8. Décision du
propriétaire (lot 0.3) : les essais humains, les campagnes approfondies de non-régression et les tests de charge sont
regroupés dans un **lot QA ultérieur**, lancé à sa demande (« on testera tout d'un coup »).

Règles de ce registre :

- Tout ce qui n'a pas été exécuté est marqué **NON TESTÉ**. Une ligne ne passe à « fait » qu'avec la commande, la
  date, l'identifiant de tâche et le résultat mesuré, consignés dans le rapport du lot concerné.
- Une anomalie n'est **jamais** déclarée corrigée sans preuve (exécution qui la reproduisait auparavant, puis qui ne
  la reproduit plus, sur un nombre d'essais indiqué).
- Priorité : **P1** bloque la clôture du lot ou peut fausser d'autres essais ; **P2** comportement visible par le
  joueur ; **P3** confort, réglage, mesure.
- Les essais Studio se lancent dans la VM (`docs/VM_TESTS.md`), jamais sur le poste principal ; les essais humains
  sont faits par le propriétaire.

Dernière mise à jour : 2026-11-03, lot 0.8 (branche `feat/art-audio-onboarding-0.8`).

## 1. Anomalies ouvertes

| Id | Lot | Système | Priorité | Description | Conditions de reproduction | État |
|---|---|---|---|---|---|---|
| QA-A01 | 0.1 | Propriété réseau / réplication | P1 | Client propriétaire et simulant (`ReceiveAge` = 0) mais le serveur ne voit pas le véhicule avancer, puis voit un saut (correction « Teleport »). Détail : `docs/lot-0.1/RAPPORT_VALIDATION.md` §5.1 | Sessions `collision`, `collision_latence` ; surtout après sortie puis réembarquement rapide suivant un repositionnement par le serveur de test. Intermittent (≈ 1 essai sur 6 dans certaines campagnes) | **Ouverte**, cause non établie ; réobservée le 2026-11-03 (réattributions en `collision`, `collision_latence`, une correction « Teleport »), voir `docs/QA_CAMPAGNE_2026-11-03.md` §4 |
| QA-A02 | 0.2 | Sortie du véhicule | P1 | Sortie non effective après la collision contre un véhicule garé, puis étape suivante faussée (« Teleport », « propriété refusée »). Détail : `docs/lot-0.2/RAPPORT_LOT_0.2.md` §3.10 | Session `scenarios` : 2 exécutions sur 5 (`225205`, `233800`) | **Ouverte**, intermittente ; 2026-11-03 : 1 occurrence en `collision_latence` (`030408`) avec diagnostic : demande de sortie à 27,3 km/h en marche arrière (refus ExitTooFast), personnage resté assis ; cause non établie |
| QA-A03 | 0.2 | Propriété réseau (attribut) | P2 | `SimulationOwnerUserId` vu à 0 alors que le joueur était propriétaire effectif | 1 contrôle sur 7 101 (`224147`), 1 sur 1 706 (`235945`), 1 sur 2 340 (`023510`), 1 sur 7 092 (`030408`) | **Ouverte** |
| QA-A04 | 0.1 | Collisions entre joueurs | P2 | Le percuteur s'arrête net contre le véhicule d'un autre joueur (`docs/lot-0.1/ECARTS.md` §4.5) | Session `collision` | **Limite connue** |
| QA-A05 | 0.1 | Véhicule ancré | P3 | Personnage resté assis côté client après refus, sans pouvoir conduire | Cas provoqué par le test (véhicule ancré) | **Limite connue** |
| QA-A06 | 0.1 | Démarrage | P3 | Une fois (`180955`), véhicules pas encore immobiles 4 s après le démarrage (1,04 st/s) | Non reproduit ensuite | **Ouverte**, non reproduite |
| QA-A07 | 0.1 | Collisions | P3 | Variabilité du percuté conduit : un glissement de 9,06 st (`193233`) | Session `collision` | **Ouverte** |

### 1 bis. Défauts trouvés par la campagne du 2026-11-03 et corrigés

| Id | Lot | Système | Priorité | Défaut | Correction | Preuve |
|---|---|---|---|---|---|---|
| QA-F01 | 0.4 | Garages | P1 | Une sortie répétée (même demande) pendant l'attente de sauvegarde matérialisait une seconde copie conduisible du véhicule (`20261103-025318`) | `5da05aa` | `20261103-025600`, `20261103-030408` : 1 exemplaire, aucun véhicule restant |
| QA-F04 | 0.6 | Démarrage des courses | P1 | `RaceService` lisait l'environnement des profils avant le démarrage de `ProfileService` : amorçage du serveur interrompu (`20261103-110953`, 7 échecs) | Adaptateur inter-serveurs créé à la première utilisation (commit du lot 0.6) | `20261103-111939` (65 / 0), `20261103-112132` (35 / 0) |
| QA-F03 | 0.5 | Lieux économiques | P2 | Les 13 lieux économiques recevaient l'invite « Préparer / Garage public » de la progression (29 invites au lieu de 16, `20261103-035626`) | `2caf0c9` | `20261103-035902` : 16 + 13 invites, aucune erreur |
| QA-F02 | 0.3 | Carte | P1 | 195 pièces dépassaient 2 048 studs et étaient raccourcies par le moteur : trous aux bouts des longues chaussées droites (P-01 sur l'herbe, 37,8 km/h, `20261103-025743`) | `b41e0f1` | `20261103-030159` : 133,4 km/h sur A6-2, toujours sur la route |

## 2. Essais humains (aucun n'a été réalisé)

| Id | Lot | Système | Priorité | Essai | Attendu | État |
|---|---|---|---|---|---|---|
| QA-H01 | 0.1 | Commandes | P1 | Conduite au clavier (Z/W, S, Q/A/D, Espace, V, R, F) | Réponse progressive, marche arrière en maintenant S à l'arrêt, sortie refusée au-dessus de 20 km/h | **NON TESTÉ** |
| QA-H02 | 0.1 | Commandes | P1 | Conduite à la manette (RT, LT, stick, A, croix, Y) | Idem, aide du HUD en mode manette | **NON TESTÉ** |
| QA-H03 | 0.1 | Commandes | P2 | Clavier et manette ensemble | Le dernier périphérique sollicité pilote, pas de cumul | **NON TESTÉ** |
| QA-H04 | 0.1 | Commandes | P2 | Taper dans le chat en conduisant | Aucune commande ni sortie | **NON TESTÉ** |
| QA-H05 | 0.1 | Commandes | P2 | Débrancher / rebrancher la manette gâchette enfoncée | Relâchement, message, pas de redémarrage avant un nouvel appui | **NON TESTÉ** |
| QA-H06 | 0.1 | Commandes | P3 | Perte de focus de la fenêtre en conduisant | Relâchement, touche « bloquée » ignorée au retour | **NON TESTÉ** |
| QA-H07 | 0.2 | Commandes | P1 | Clavier : Maj / Ctrl gauche (rapports), C (embrayage), 1/2/3 (aides), G (récupération), V (caméras) | Effet immédiat, affiché au HUD | **NON TESTÉ** |
| QA-H08 | 0.2 | Commandes | P1 | Manette : RB / LB, B, croix gauche / droite, croix haut | Idem | **NON TESTÉ** |
| QA-H09 | 0.2 | Boîte manuelle | P2 | Démarrage en côte et calage au clavier et à la manette | Rampe d'embrayage de 0,6 s utilisable | **NON TESTÉ** |
| QA-H10 | 0.2 | Ressenti | P2 | Six boîtes, rampement de l'automatique, aides, glissement combiné ; maintien en pente (A3, à arbitrer) | Ressenti crédible ; arbitrage A3 | **NON TESTÉ** |
| QA-H11 | 0.2 | HUD / caméras | P3 | Lisibilité du HUD (aides, énergie, dégâts), vues cockpit / capot / pare-chocs | Lisible, sans masquer la route | **NON TESTÉ** |
| QA-H12 | 0.3 | Monde ouvert | P1 | Parcourir les sept zones en P-01, P-02, P-03 depuis le parc des prototypes, sans téléportation | Aucune chute, aucun blocage, routes continues ; trajets crédibles | **NON TESTÉ** |
| QA-H13 | 0.3 | Routes | P2 | Lisibilité des carrefours, bretelles, lacets de montagne, corniche ; sensation de rues non répétitives | Tracé lisible et varié | **NON TESTÉ** |
| QA-H14 | 0.3 | Trafic / piétons | P2 | Ressenti du trafic PNJ (feux, priorités, réaction au joueur) et des piétons | Comportement crédible, jamais traversé | **NON TESTÉ** |
| QA-H15 | 0.3 | Météo / jour-nuit | P2 | Pluie, brouillard, orage, nuit : visibilité et ressenti d'adhérence | Différences visibles et sensibles, conduite toujours possible | **NON TESTÉ** |
| QA-H16 | 0.4 | Interface progression | P1 | Panneau (touche P / Select) au clavier-souris et à la manette : onglets, sélection, focus, fermeture | Navigation complète sans souris à la manette, aucune action involontaire | **NON TESTÉ** |
| QA-H17 | 0.4 | Garages | P1 | Entrer dans sa propriété, exposer, ranger, sortir un véhicule, le ramener à l'entrée | Une seule voiture conduisible, maquettes à jour, retour refusé loin de l'entrée | **NON TESTÉ** |
| QA-H18 | 0.4 | Préparation | P2 | Réglages, esthétique, pièces au garage public ; ressenti des réglages extrêmes | Effet perceptible, refus clairs des combinaisons irréalisables | **NON TESTÉ** |
| QA-H19 | 0.4 | Visites | P2 | Deux joueurs : invitation, visite, conduite prêtée, révocation pendant la visite et pendant la conduite | Accès refusé sans invitation ; révocation : sortie à l'entrée, descente une fois arrêté | **NON TESTÉ** |
| QA-H20 | 0.4 | Indications de sauvegarde | P2 | Lisibilité du badge d'état (chargement, en attente, sauvegardé, lecture seule) | Jamais « enregistré » avant confirmation | **NON TESTÉ** |

## 3. Essais Studio reportés du lot 0.3 (moteur requis)

Session Studio `monde` (place monde ouvert) : `test-vm.cmd -Place OpenWorld -Sessions monde` (génère la carte puis
la place). Session `lot04` (progression, 2 joueurs) : `test-vm.cmd -Sessions lot04`. Résultats de la campagne du
2026-11-03 dans la colonne « État ».

| Id | Système | Priorité | Essai | Attendu | État |
|---|---|---|---|---|---|
| QA-S01 | Démarrage | P1 | Ouverture de la place monde ouvert, démarrage serveur et client | Aucune erreur ; `OpenWorldService` trouve 9 plots ; message « Serveur initialisé (OpenWorld…) » | **FAIT** — `20261103-030159` : démarrage sans erreur, carte 0.3.0 (37 239 pièces), 9 plots |
| QA-S02 | Apparitions | P1 | Apparition du joueur | Uniquement à `SPAWN-METRO`, hors chaussée ; les 9 prototypes alignés sur leurs plots, face à la route | **FAIT** — `030159` : seule `SPAWN-METRO` active, joueur à 6 st de l'apparition, 9 prototypes posés immobiles (orientation non mesurée) |
| QA-S03 | Physique sur la carte | P1 | Conduite automatisée des P-01/P-02/P-03 sur autoroute, avenue, rue, montagne, chemin, bretelle, pont | Aucune roue qui traverse, pas d'accroche aux raccords de tronçons et disques de carrefour, pentes franchissables | **PARTIEL** — `030159` : autoroute A6-2 à 133,4 km/h sans passer sous la route ; repos sur route de montagne (M1-1), rue, chemin. Défaut trouvé et corrigé (pièces > 2 048 studs, QA-F02). Bretelles, ponts, raccords : **NON TESTÉ** |
| QA-S04 | Streaming | P1 | Traversée rapide (A1 à 130 km/h) avec `StreamingEnabled` | Routes et collisions toujours présentes (modèles persistants) ; aucun arrêt par `PauseOutsideLoadedArea` en conditions normales ; décor chargé avant d'être atteint | **PARTIEL** — `030159` : 13 618 pièces de route reçues (toutes), 397 m à grande vitesse sans perte de sol. Traversée longue (A1 complète) et pause de streaming : **NON TESTÉ** |
| QA-S05 | Streaming / véhicules | P1 | Véhicules d'autres joueurs hors rayon puis de retour | Modèle `Atomic` complet ou absent, jamais partiel ; le simulateur client ne plante pas | **NON TESTÉ** |
| QA-S06 | Météo | P2 | Forçage des quatre états (`WeatherService.force`) | Attributs publiés, ambiance client mise à jour, `AWRoadWetness` lu par le simulateur | **PARTIEL** — `030159` : pluie forcée publiée (`AWRoadWetness` = 1) et reçue par le client. Brouillard, orage, rendu visuel : **NON TESTÉ** |
| QA-S07 | Adhérence mouillée | P1 | Place de développement : freinage 80–0 km/h sur la zone mouillée (`AWWet`) avec et sans `AWRoadWetness` = 1 forcé sur Workspace, puis sur sol sec avec `AWRoadWetness` = 1 | Les trois distances mouillées identiques (réduction appliquée une fois) ; écart avec le banc Lune documenté | **NON TESTÉ** |
| QA-S08 | Horloge | P3 | Cycle complet de 30 min, deux clients | Même heure chez les deux clients (±1 s) | **PARTIEL** — `030159` : écart de 0,002 h avec un client. Deux clients, cycle complet : **NON TESTÉ** |
| QA-S09 | Feux | P2 | Couleur des lampes contre l'arrêt des PNJ | PNJ arrêtés au rouge exactement quand la lampe est rouge | **PARTIEL** — `030159` : 8/8 lampes proches colorées selon la règle. Arrêt des PNJ au rouge observé en jeu : **NON TESTÉ** |
| QA-S10 | Trafic physique | P1 | Joueur qui percute un PNJ, PNJ qui arrive derrière un joueur arrêté, joueur arrêté dans un carrefour | PNJ solide (pas de traversée), poussé puis arrêté ; aucun PNJ projeté en l'air ni bloqué durablement ; propriété réseau des PNJ au serveur | **PARTIEL** — `030159` : 140 agents, 5 corps physiques près du joueur, tous au serveur, aucun tombé ni renversé. Chocs joueur ↔ PNJ : **NON TESTÉ** |
| QA-S11 | Trafic / joueur | P1 | Contact véhicule client ↔ PNJ serveur sous latence | Pas de correction serveur abusive du véhicule du joueur, pas d'interaction avec QA-A01 | **NON TESTÉ** |
| QA-S12 | Trafic | P2 | Apparition et retrait des corps physiques | Jamais à moins de 300 m d'un joueur pour une apparition d'agent ; matérialisation sans chevauchement d'un véhicule de joueur | **NON TESTÉ** |
| QA-S13 | Piétons | P2 | Rendu local autour de la caméra | ≤ 60 figurants, sur les trottoirs, jamais touchés par les lancers de suspension | **PARTIEL** — `030159` : piétons rendus autour de la caméra. Nombre, trottoirs, rayons : **NON TESTÉ** |
| QA-S14 | Dégâts / énergie | P2 | Dégâts, consommation, propriété réseau et caméras du lot 0.2 dans le monde ouvert | Inchangés par rapport à la zone d'essai | **NON TESTÉ** |
| QA-S15 | Retour au plot | P3 | Prototype abandonné loin du parc | Renvoi au plot après 90 s sans joueur à proximité, sans heurter le trafic | **NON TESTÉ** |
| QA-S16 | Non-régression | P1 | Les 7 sessions VM existantes sur la place de développement (`test-vm.cmd`) avec le code du lot 0.3 | Mêmes résultats qu'au lot 0.2 (hors anomalies QA-A01/A02) | **FAIT** — `20261103-023510` (463/3/1) et `20261103-030408` (526/4/1, dernier commit) : échecs uniquement dans les familles QA-A01, QA-A02, QA-A03 |

## 3 bis. Essais reportés du lot 0.4 (persistance et progression)

Toute la logique pure (profils, verrou, migrations, idempotence, environnements, règles de garage) est vérifiée par
Lune **sur l'adaptateur mémoire** ; la persistance RÉELLE n'est pas validée. Les essais DataStore se feront
uniquement dans une expérience Roblox de TEST isolée, après déclaration de son identifiant par le propriétaire dans
`src/server/Persistence/EnvironmentConfig.luau` (jamais l'expérience de production, jamais l'accès Studio aux API
de production).

| Id | Système | Priorité | Essai | Attendu | État |
|---|---|---|---|---|---|
| QA-D01 | DataStore | P1 | Expérience de test isolée : création, sauvegarde, reconnexion, relecture d'un profil réel | Données identiques après reconnexion ; nom de magasin `AW_TEST_Profiles_v1` | **NON TESTÉ** |
| QA-D02 | Verrou | P1 | Changement rapide de serveur (rejoindre un autre serveur juste après avoir quitté) | Chargement après libération (≤ 40 s de reprises), aucune écriture de l'ancien serveur après la nouvelle | **NON TESTÉ** |
| QA-D03 | Verrou | P1 | Arrêt brutal d'un serveur (sans BindToClose) puis reconnexion | Reprise du verrou expiré après ≤ 5 min, journalisée ; aucune perte de transaction confirmée | **NON TESTÉ** |
| QA-D04 | Arrêt serveur | P1 | Fermeture normale (BindToClose) avec plusieurs joueurs, véhicules sortis | Profils sauvegardés et verrous rendus dans le budget de 25 s ; véhicules revenus au garage | **NON TESTÉ** |
| QA-D05 | Déconnexion | P1 | Déconnexion forcée pendant : le choix de départ (quand la liste existera), une sortie de véhicule, une configuration | Aucun doublon, état cohérent à la reconnexion (SCN-01) | **NON TESTÉ** |
| QA-D06 | Écritures incertaines | P1 | Erreurs DataStore réelles (budget épuisé, délai) | Réconciliation par relecture, statut « en attente » puis confirmé, jamais rejoué à l'aveugle | **NON TESTÉ** |
| QA-D07 | Budget | P2 | 24 joueurs : écritures par minute, `GetRequestBudgetForRequestType` | Aucune limitation sur une session normale (sauvegarde 60 s, transactions ≥ 6 s par clé) | **NON TESTÉ** |
| QA-D08 | Restauration | P2 | Restauration ciblée d'un profil depuis une version DataStore (AUD-REST-01) | Procédure documentée exécutée sur des données de test ; transferts plus récents préservés | **NON TESTÉ** (procédure seulement décrite) |
| QA-D09 | Migration | P2 | Première migration réelle (v1 → v2) en déploiement progressif | Ancien serveur en lecture seule sur un profil v2, aucune donnée effacée | **NON TESTÉ** (aucune v2 n'existe) |
| QA-D10 | Taille | P3 | Profil volumineux (milliers de véhicules) | Limite technique explicite, sans perte ; fractionnement à arbitrer | **NON TESTÉ** |
| QA-S17 | Véhicules personnels | P1 | Sortie, conduite, retour : dégâts, énergie et kilométrage restaurés à la reconnexion | Valeurs serveur réconciliées (énergie jamais augmentée, dégâts jamais réduits) | **PARTIEL** — `20261103-030408` : énergie restaurée à la sortie (30 L = 60 % × 50 L). Dégâts et kilométrage après reconnexion : **NON TESTÉ** |
| QA-S18 | Définition réglée | P1 | Exemplaire réglé conduit par son propriétaire : même définition chez le client et le serveur | Aucune correction de mouvement due à un écart de réglages | **NON TESTÉ** |
| QA-S19 | Intérieurs | P2 | Intérieurs privés instanciés (streaming, 10 joueurs dans 10 intérieurs) | Arrivée sans chute, maquettes non conduisibles, sortie à la même entrée | **PARTIEL** — `030408` : entrée physique, maquette exposée, sortie à la même entrée, visiteur reconduit après révocation (2 joueurs). Dix intérieurs simultanés : **NON TESTÉ** |
| QA-S20 | Entrées | P2 | Invites d'entrée sur les 13 emplacements de la carte et les 3 garages publics | Invites présentes, lieux reconnus même secteur non chargé côté client | **PARTIEL** — `030159` : 16 invites présentes dans la carte. Usage de chaque invite : **NON TESTÉ** |
| QA-S21 | Zone d'essai | P2 | Place de développement : entrée et garage public d'essai, données synthétiques (3 prototypes, 1 propriété moyenne, pièces) | Disponibles en Dev seulement, perdues à l'arrêt du serveur (stockage mémoire) | **FAIT** — `030408` : entrée et garage public d'essai, données synthétiques (3 prototypes, 2 propriétés, pièces), environnement « Dev » en mémoire |
| QA-S22 | Non-régression | P1 | Sessions VM existantes après les modifications du service des véhicules (création des enregistrements, participants des collisions) | Résultats identiques au lot 0.2 (hors anomalies connues) | **FAIT** — `030408` : 7 sessions historiques sur le code du lot 0.4, aucune erreur d'exécution, échecs uniquement dans les familles connues |

## 3 ter. Essais reportés du lot 0.5 (économie, métiers, marché)

Les invariants des opérations qui créent de l'argent, transfèrent un actif ou facturent un joueur sont vérifiés par
Lune **sur l'adaptateur mémoire** (`tests/lune/specs/Lot05Economy.luau`), y compris interruptions et répétitions.
Cela ne valide PAS la persistance Roblox ni les transferts entre serveurs réels.

| Id | Système | Priorité | Essai | Attendu | État |
|---|---|---|---|---|---|
| QA-E01 | Transferts réels | P1 | Vente entre deux joueurs sur DataStore d'une expérience de test isolée, puis arrêt brutal entre deux étapes | Transfert terminé ou compensé à la reprise, aucun doublon | **NON TESTÉ** |
| QA-E02 | Inter-serveurs | P1 | Vendeur et acheteur sur deux serveurs différents (boîtes de réception, balayage) | Transfert terminé par le serveur du vendeur, fonds réservés jamais perdus | **NON TESTÉ** |
| QA-E03 | Marché | P2 | Recherche d'annonces avec beaucoup d'annonces (index `Market_Index` borné à 500) | Résultats corrects ; montée en charge à revoir (MemoryStore ou index paginé) | **NON TESTÉ** |
| QA-E04 | Missions en jeu | P1 | Les 8 métiers joués de bout en bout (Dev et monde ouvert), avec véhicule personnel, professionnel et fourni | Étapes reconnues, paiement unique, véhicule temporaire retiré | **NON TESTÉ** |
| QA-E05 | AUD-ECO-01 | P1 | Joueur sans crédit ni véhicule personnel : mission de livraison avec véhicule professionnel | Paiement normal, aucun véhicule acquis, aucun débit | **NON TESTÉ** (logique Lune seulement) |
| QA-E06 | Énergie en jeu | P1 | Plein, recharge, interruption (départ, véhicule déplacé, serveur arrêté) | Paiement au réel, aucune énergie gratuite, fonds restitués | **NON TESTÉ** |
| QA-E07 | Concessions | P2 | Achat et reprise dans les deux concessions de la carte ; refus à distance | Exemplaire unique, débit confirmé, reprise ≈ 60 % | **NON TESTÉ** |
| QA-E08 | Immobilier | P2 | Achat à l'entrée d'un bien, agrandissement, module, revente avec visiteurs présents | Ratios 70/40/60 %, véhicules exposés rangés, revente refusée si occupée | **NON TESTÉ** |
| QA-E09 | Garage public | P2 | Main-d'œuvre facturée (pièce, esthétique, réglages) ; solde insuffisant | Intervention annulée en entier si le paiement échoue | **NON TESTÉ** |
| QA-E10 | Interface économie | P1 | Panneau J / stick droit au clavier, souris et manette ; devis, confirmation, état réel ; blocage en mouvement | Jamais de réussite affichée avant confirmation | **NON TESTÉ** (humain) |
| QA-E14 | Guidage de mission | P1 | Mission lancée loin de son départ (Essais dans le monde ouvert : piste de drag à ~4 km) : flèche, distance, étiquette du repère, colonne posée au sol | Objectif trouvé sans connaître la carte ; flèche juste quel que soit l'angle de caméra | **NON TESTÉ** (humain) |
| QA-E11 | Équilibrage | P2 | Revenus horaires réels par métier contre la simulation (`tools/economy/simulate.luau`) | Écarts compris et documentés | **NON TESTÉ** |
| QA-E12 | Lavage | P3 | Salissure visible et lavage | Teinte rendue à la prochaine sortie ; aucune réparation | **NON TESTÉ** |
| QA-E13 | Bornes | P3 | Occupation d'une borne par plusieurs joueurs | Pas de blocage abusif (session limitée à 180 s) ; réservation par borne non implémentée | **NON TESTÉ** |

## 3 quater. Essais reportés du lot 0.6 (courses, matchmaking, compétition, saisons)

Les règles (départs, faux départs, points de contrôle, tours, temps, drift, classement, abandons), les réservations,
les modes protégé et réaliste, les récompenses, le classement, les saisons et la récupération sont vérifiés par
Lune sur des échantillons SYNTHÉTIQUES et l'adaptateur MÉMOIRE (`tests/lune/specs/Lot06Racing.luau`). Cela ne valide
ni la conduite réelle en course, ni la persistance Roblox, ni l'inter-serveurs.

| Id | Système | Priorité | Essai | Attendu | État |
|---|---|---|---|---|---|
| QA-R01 | Matchmaking inter-serveurs | P1 | `CrossServerAdapter` dans une expérience de test isolée : file MemoryStore, serveur réservé, téléportation des participants confirmés | Match formé entre serveurs, transition explicite, réservations conservées | **NON TESTÉ** (code jamais exécuté) |
| QA-R02 | Reconnexion après transfert | P1 | Déconnexion pendant une épreuve puis retour (même serveur, autre serveur, après téléportation) | Reprise dans ~90 s au dernier point validé ; sinon issue « Disconnected » ; aucun double paiement | **NON TESTÉ** (logique Lune seulement) |
| QA-R03 | Résilience DataStore | P1 | Résultats et réservations sur DataStore réel : arrêt du serveur de course entre la publication `Race_<id>` et l'application, profil verrouillé ailleurs | Résultat appliqué une fois par le serveur du profil ; engagement échu résolu (mode protégé restauré) | **NON TESTÉ** |
| QA-R04 | Tableaux durables | P2 | Tableaux de saison et records sur OrderedDataStore (`CrossServerAdapter`) | Valeurs correctes, records conservés au meilleur | **NON TESTÉ** |
| QA-R05 | Collisions en course sous latence | P1 | Départ groupé de grille, dépassements et contacts à 2–8 joueurs, latences différentes (anomalies QA-A01 à A04) | Résultats confirmés ou « non confirmés » à réconcilier, jamais de sanction d'une anomalie réseau | **NON TESTÉ** |
| QA-R06 | Charge | P1 | 24 joueurs dont plusieurs épreuves simultanées (échantillonnage à 10 Hz, instantanés à 2 Hz) | Fréquence serveur stable, coût par participant mesuré | **NON TESTÉ** |
| QA-R07 | Équilibrage réel | P2 | Gains réels par discipline et mode contre `tools/economy/simulate-races.luau` et les métiers ; coûts réels du mode réaliste contre l'estimation (énergie, usure) | Écarts mesurés et documentés ; métiers toujours compétitifs | **NON TESTÉ** |
| QA-R08 | Exploitabilité du classement | P2 | Arrangements entre comptes, abandons volontaires, déconnexions répétées en classé | Gains réduits face aux mêmes adversaires, signalement, aucune sanction automatique | **NON TESTÉ** |
| QA-R09 | Anti-triche en situation réelle | P1 | Raccourcis, sorties de tracé, véhicule de quelqu'un d'autre, faux départs, vitesse invraisemblable | Points manqués non validés, pénalités, arrivées non confirmées | **NON TESTÉ** (logique Lune seulement) |
| QA-R10 | Six disciplines en jeu | P1 | Sprint, circuit, contre-la-montre, drift, drag, rallye joués de bout en bout (place de développement et monde ouvert), modes protégé et réaliste | Départs, points, tours, arrivées, résultats confirmés, récompenses, véhicule libéré | **NON TESTÉ** |
| QA-R11 | Drift en jeu | P2 | Score sur une vraie conduite (angles, transitions), rotation à l'arrêt, chocs, sortie de zone | Pas de gros score sans dérive maîtrisée | **NON TESTÉ** (modèle Lune seulement) |
| QA-R12 | Drag en jeu | P2 | Arbre de départ, faux départ réel, boîtes manuelle et automatique, temps de réaction | Feux synchronisés sur l'horloge serveur, aucune assistance imposée | **NON TESTÉ** |
| QA-R13 | Météo normalisée | P2 | Course classée sous la pluie du monde : adhérence du véhicule engagé, puis retour aux conditions du monde après l'épreuve | Adhérence sèche standardisée pendant l'épreuve seulement ; météo du monde inchangée | **NON TESTÉ** |
| QA-R14 | Interface courses | P1 | Panneau K / stick gauche au clavier, souris et manette ; affichage de course lisible sans masquer la conduite ; repères | Utilisable, aucune action de conduite bloquée | **NON TESTÉ** (humain) |
| QA-R15 | Ressenti | P2 | Ressenti des départs, de la grille, des pénalités et du drift par le propriétaire | Avis consigné | **NON TESTÉ** (humain) |
| QA-R16 | Installations | P3 | Portiques, places et dalles d'inscription posés au sol sur les 16 parcours (relief, ponts) | Aucun élément flottant ni enterré, aucun obstacle sur la trajectoire | **NON TESTÉ** |
| QA-R17 | Mode protégé en jeu | P1 | Course protégée avec dégâts antérieurs, chocs pendant la course, sortie brutale du jeu | Dégâts antérieurs conservés, dégâts de course effacés, rien réparé gratuitement | **NON TESTÉ** (logique Lune seulement) |

## 3 quinquies. Essais reportés du lot 0.7 (interface, GPS, smartphone, social)

Les règles (itinéraires, recalcul, projection, points d'intérêt, pile d'écrans, focus, blocage en conduite,
raccourcis, confirmations, notifications, groupes, partage de position, filtrage, localisation, préférences) sont
vérifiées par Lune (`tests/lune/specs/Lot07Interface.luau`). Cela ne valide ni l'affichage réel, ni l'ergonomie,
ni les communications Roblox, ni la confidentialité en multijoueur réel.

| Id | Système | Priorité | Essai | Attendu | État |
|---|---|---|---|---|---|
| QA-U01 | Parcours utilisateur | P1 | Parcours complet : à pied, téléphone, carte, destination, conduite guidée, mission, course, garage, marché | Navigation cohérente, une seule fenêtre à la fois, focus rendu | **NON TESTÉ** (humain) |
| QA-U02 | GPS réel | P1 | Guidage sur plusieurs km avec trafic PNJ et streaming réel des secteurs ; sortie d'itinéraire et recalcul | Indications justes et à temps, recalcul sans saccade, aucun gel | **NON TESTÉ** |
| QA-U03 | Clavier / manette | P1 | Navigation complète à la manette ; passage clavier ↔ manette pendant une confirmation ; touches personnalisées | Aucune accélération ni confirmation involontaire, focus toujours récupérable | **NON TESTÉ** (humain) |
| QA-U04 | Lisibilité | P2 | Résolutions (720p à 4K, ultra-large), tailles de texte, contraste renforcé, opacité | HUD et téléphone lisibles sans masquer la route | **NON TESTÉ** |
| QA-U05 | Conduite et menus | P1 | Ouvrir un panneau à l'arrêt puis démarrer ; ouvrir le téléphone en roulant | Mode rapide ou masquage avec brouillon, aucune validation, aucun freinage | **NON TESTÉ** (humain) |
| QA-U06 | Charge sociale | P2 | 24 joueurs, 3 groupes de 8, partage de position actif | Envois par destinataire stables, aucune fuite de position | **NON TESTÉ** |
| QA-U07 | Communications | P1 | Canaux texte de groupe et de proximité sous les règles Roblox (âge, confidentialité, modération), comptes restreints | Messages filtrés par Roblox, refus respectés, aucun contournement | **NON TESTÉ** |
| QA-U08 | Confidentialité multijoueur | P1 | Deux joueurs dans un groupe : aucune vue du solde, de la collection, des propriétés ; partage désactivé par défaut puis révoqué | Rien de privé reçu (inspection des messages réseau) | **NON TESTÉ** (logique Lune seulement) |
| QA-U09 | Préférences sur DataStore | P2 | Préférences sauvegardées puis retrouvées après reconnexion, sur une expérience de test isolée ; changements rapides répétés | Retrouvées ; aucune écriture par changement visuel | **NON TESTÉ** (mémoire seulement) |
| QA-U10 | Téléphone en main | P2 | Modèle dans la main (R15, R6), bras levé, rangement, vu par les autres joueurs | Pose correcte, écran générique pour les autres | **NON TESTÉ** |
| QA-U11 | Mini-carte et carte | P2 | Coût du dessin (mini-carte 5 Hz, carte), lisibilité des routes et des icônes, rotation | Images par seconde stables ; dessin lisible | **NON TESTÉ** |
| QA-U12 | Localisation | P2 | Relecture FR/EN de tous les textes, longueur des textes anglais dans les cadres | Aucun débordement, traductions justes | **NON TESTÉ** (lot 0.8 : panneaux des lots 0.4–0.6 traduits, contrôle automatique des clés seulement ; relecture humaine à faire) |
| QA-U13 | Notifications en conduite | P2 | Différées, compactes et critiques pendant une conduite réelle ; aide visuelle | Route dégagée, alertes critiques perçues | **NON TESTÉ** (humain) |

## 3 sexies. Essais reportés du lot 0.8 (rendu, gamme, audio, radio, photo, arrivée)

Les règles pures (fiches et définitions des 18 modèles, catalogue, séparation des actifs provisoires, conditions et
unicité du véhicule de départ, propriété gratuite, isolation des essais, mode photo, radio, réglages audio et
graphiques, localisation, migrations, manifeste, place passager) sont vérifiées par Lune
(`tests/lune/specs/Lot08Content.luau`) et pytest (`tests/test_lot08.py`). Cela ne valide ni le rendu, ni le son
réel, ni le ressenti, ni le comportement multijoueur.

| Id | Système | Priorité | Essai | Attendu | État |
|---|---|---|---|---|---|
| QA-V01 | Direction artistique | P2 | Validation artistique humaine : carrosseries des 10 silhouettes, habitacles, habillage des 7 zones, étalonnage jour/nuit, effets par qualité | Cohérent, lisible, conforme à `DIRECTION_ARTISTIQUE.md` | **NON TESTÉ** (humain) |
| QA-V02 | Gamme de 18 | P1 | Essais réels des 18 modèles (accélération, freinage, virage, vitesse de pointe, boîtes, aides) dans Studio puis par un humain | Comportement conforme aux fiches ; valeurs du banc planaire confirmées ou corrigées | **NON TESTÉ** (banc planaire hors Studio seulement) |
| QA-V03 | Carrosseries et collisions | P1 | Coque, boucliers et habitacle collidables des 10 silhouettes : chocs, sortie, dommages du lot 0.2, place passager | Aucune pièce coinçante, sortie possible, dommages visibles | **NON TESTÉ** |
| QA-V04 | Sons moteur | P2 | Ressenti des moteurs et des sons (après téléversement par le propriétaire) : fondus de couches, électrique, calage | Sons crédibles, fondus sans saut | **NON TESTÉ** (aucun son téléversé : rien n'est joué en jeu) |
| QA-V05 | Audio spatial | P2 | Atténuation par distance, nombre de véhicules sonorisés par qualité, ambiances par zone et pluie | Spatialisation correcte, aucune saturation | **NON TESTÉ** |
| QA-V06 | Radio multijoueur | P1 | Conducteur et deux passagers : changer de station, couper chez un passager, régler les volumes, sortir du véhicule ; joueur extérieur | Station commune pilotée par le conducteur ; coupure et volume individuels ; rien entendu dehors (SCN-19) | **NON TESTÉ** (stations indisponibles tant que les pistes ne sont pas téléversées) |
| QA-V07 | Mode photo complet | P1 | À pied, conducteur arrêté, passager ; caméra contre un mur et près d'une propriété ; ouverture en course ; masquage et restauration ; capture et enregistrement | Caméra bornée, aucun mur traversé, refus en course, restauration exacte, capture proposée (SCN-20) | **NON TESTÉ** |
| QA-V08 | Parcours d'arrivée | P1 | Onboarding avec des comptes réels : nouveau joueur, passage de l'introduction, essai, choix confirmé, reconnexion pendant le choix, joueur existant (migration 4 → 5) | Un seul véhicule, propriété unique, parcours non imposé aux anciens joueurs | **NON TESTÉ** (Dev, candidats synthétiques ; aucune attribution en test ou production avant approbation) |
| QA-V09 | Protection d'apparition | P2 | Véhicule lancé sur un nouveau joueur pendant 60 s ; fin à la montée en voiture | Aucun choc subi ; protection levée ensuite | **NON TESTÉ** |
| QA-V10 | Exercices | P3 | Les 8 exercices en jeu, dont stationnement et changement de rapport en boîte automatique | Réussite détectée, aucun crédit | **NON TESTÉ** |
| QA-V11 | Performances du rendu | P1 | Images par seconde et mémoire avec l'habillage (≈ 47 650 pièces), nuit avec sources de lumière, qualités basse à haute | Mesure réelle ; aucun objectif déclaré atteint | **NON TESTÉ** |
| QA-V12 | Compatibilité des actifs | P2 | Téléversement réel des 30 sons (modération, formats), puis lecture en jeu | Acceptés et joués | **NON TESTÉ** (propriétaire) |
| QA-V13 | Charge à 24 joueurs | P1 | 24 joueurs avec feux, sons et radio actifs | Fréquence stable | **NON TESTÉ** |
| QA-V14 | Manette | P2 | Téléphone sur Select, invite d'entrée sur X, mode photo par l'application Photo, garage par le téléphone | Aucun conflit de touches | **NON TESTÉ** (humain) |

## 4. Charge, performance et stabilité

| Id | Système | Priorité | Essai | Attendu | État |
|---|---|---|---|---|---|
| QA-P01 | Serveur | P1 | 24 joueurs répartis dans les zones, trafic à 140 agents | Fréquence serveur stable ; coût de `TrafficService` mesuré par pas | **NON TESTÉ** |
| QA-P02 | Client | P1 | Images par seconde sur un appareil de référence (ordinateur et mobile), métropole dense, pluie, nuit | Mesure réelle ; **aucun objectif (~60 FPS) n'est déclaré atteint** | **NON TESTÉ** |
| QA-P03 | Mémoire | P2 | Mémoire client et serveur avec la carte complète (≈ 47 650 pièces depuis le lot 0.8) et le streaming | Mesure réelle, comparaison avec et sans streaming | **NON TESTÉ** |
| QA-P04 | Réseau | P2 | Bande passante par joueur (trafic physique, véhicules, attributs météo) | Mesure réelle | **NON TESTÉ** |
| QA-P05 | Démarrage | P2 | Temps de démarrage serveur (calcul `WorldLayout`, `TrafficModel.newWorld`) et client (index des trottoirs) | Mesure réelle | **NON TESTÉ** |
| QA-P06 | Stabilité | P2 | Session longue (≥ 2 h) | Pas de fuite (corps PNJ, figurants), pas de blocage du trafic | **NON TESTÉ** |
| QA-P08 | Profils | P2 | Coût des copies de profil par transaction (profil volumineux) et des instantanés envoyés aux clients | Mesure réelle | **NON TESTÉ** |
| QA-P09 | Intérieurs | P3 | Coût des maquettes exposées (jusqu'à 10 par intérieur) | Mesure réelle | **NON TESTÉ** |
| QA-P07 | Réglages | P3 | Budget PNJ (140), rayon physique (260 m), plafond (48), rayon des piétons (150 m), rayons de streaming | Réglages ajustés d'après QA-P01 à P04 | **NON TESTÉ** |

## 5. Vérifications de la dernière exécution hors Studio

Campagne Studio groupée du 2026-11-03 : [`QA_CAMPAGNE_2026-11-03.md`](QA_CAMPAGNE_2026-11-03.md).

Ces contrôles automatiques ne remplacent aucun essai ci-dessus. Résultats et commandes : `docs/lot-0.3/RAPPORT_LOT_0.3.md` §2 et
`docs/lot-0.4/RAPPORT_LOT_0.4.md` §2.
