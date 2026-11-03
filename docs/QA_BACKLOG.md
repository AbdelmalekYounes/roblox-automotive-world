# Registre QA — essais reportés et anomalies ouvertes

Registre **unique** des essais non effectués et des anomalies non résolues des lots 0.1, 0.2, 0.3 et 0.4. Décision du
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

Dernière mise à jour : 2026-11-03 (lot 0.4, branche `feat/properties-garages-persistence-0.4`).

## 1. Anomalies ouvertes

| Id | Lot | Système | Priorité | Description | Conditions de reproduction | État |
|---|---|---|---|---|---|---|
| QA-A01 | 0.1 | Propriété réseau / réplication | P1 | Client propriétaire et simulant (`ReceiveAge` = 0) mais le serveur ne voit pas le véhicule avancer, puis voit un saut (correction « Teleport »). Détail : `docs/lot-0.1/RAPPORT_VALIDATION.md` §5.1 | Sessions `collision`, `collision_latence` ; surtout après sortie puis réembarquement rapide suivant un repositionnement par le serveur de test. Intermittent (≈ 1 essai sur 6 dans certaines campagnes) | **Ouverte**, cause non établie, diagnostics en place |
| QA-A02 | 0.2 | Sortie du véhicule | P1 | Sortie non effective après la collision contre un véhicule garé, puis étape suivante faussée (« Teleport », « propriété refusée »). Détail : `docs/lot-0.2/RAPPORT_LOT_0.2.md` §3.10 | Session `scenarios` : 2 exécutions sur 5 (`225205`, `233800`) | **Ouverte**, intermittente, diagnostic `client.diag_sortie_<n>` en place |
| QA-A03 | 0.2 | Propriété réseau (attribut) | P2 | `SimulationOwnerUserId` vu à 0 alors que le joueur était propriétaire effectif | 1 contrôle sur 7 101 (`224147`), 1 sur 1 706 (`235945`) | **Ouverte** |
| QA-A04 | 0.1 | Collisions entre joueurs | P2 | Le percuteur s'arrête net contre le véhicule d'un autre joueur (`docs/lot-0.1/ECARTS.md` §4.5) | Session `collision` | **Limite connue** |
| QA-A05 | 0.1 | Véhicule ancré | P3 | Personnage resté assis côté client après refus, sans pouvoir conduire | Cas provoqué par le test (véhicule ancré) | **Limite connue** |
| QA-A06 | 0.1 | Démarrage | P3 | Une fois (`180955`), véhicules pas encore immobiles 4 s après le démarrage (1,04 st/s) | Non reproduit ensuite | **Ouverte**, non reproduite |
| QA-A07 | 0.1 | Collisions | P3 | Variabilité du percuté conduit : un glissement de 9,06 st (`193233`) | Session `collision` | **Ouverte** |

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

À lancer dans la VM : `rojo build openworld.project.json -o build\AutomotiveWorld-OpenWorld.rbxl` après
`lune run tools/world/build-world.luau build\AutomotiveWorld.rbxlx build\world\OpenWorld.rbxm` ; la session dédiée
au monde ouvert reste à écrire dans `tests/studio` (aucune n'existe encore).

| Id | Système | Priorité | Essai | Attendu | État |
|---|---|---|---|---|---|
| QA-S01 | Démarrage | P1 | Ouverture de la place monde ouvert, démarrage serveur et client | Aucune erreur ; `OpenWorldService` trouve 9 plots ; message « Serveur initialisé (OpenWorld…) » | **NON TESTÉ** |
| QA-S02 | Apparitions | P1 | Apparition du joueur | Uniquement à `SPAWN-METRO`, hors chaussée ; les 9 prototypes alignés sur leurs plots, face à la route | **NON TESTÉ** |
| QA-S03 | Physique sur la carte | P1 | Conduite automatisée des P-01/P-02/P-03 sur autoroute, avenue, rue, montagne, chemin, bretelle, pont | Aucune roue qui traverse, pas d'accroche aux raccords de tronçons et disques de carrefour, pentes franchissables | **NON TESTÉ** |
| QA-S04 | Streaming | P1 | Traversée rapide (A1 à 130 km/h) avec `StreamingEnabled` | Routes et collisions toujours présentes (modèles persistants) ; aucun arrêt par `PauseOutsideLoadedArea` en conditions normales ; décor chargé avant d'être atteint | **NON TESTÉ** |
| QA-S05 | Streaming / véhicules | P1 | Véhicules d'autres joueurs hors rayon puis de retour | Modèle `Atomic` complet ou absent, jamais partiel ; le simulateur client ne plante pas | **NON TESTÉ** |
| QA-S06 | Météo | P2 | Forçage des quatre états (`WeatherService.force`) | Attributs publiés, ambiance client mise à jour, `AWRoadWetness` lu par le simulateur | **NON TESTÉ** |
| QA-S07 | Adhérence mouillée | P1 | Place de développement : freinage 80–0 km/h sur la zone mouillée (`AWWet`) avec et sans `AWRoadWetness` = 1 forcé sur Workspace, puis sur sol sec avec `AWRoadWetness` = 1 | Les trois distances mouillées identiques (réduction appliquée une fois) ; écart avec le banc Lune documenté | **NON TESTÉ** |
| QA-S08 | Horloge | P3 | Cycle complet de 30 min, deux clients | Même heure chez les deux clients (±1 s) | **NON TESTÉ** |
| QA-S09 | Feux | P2 | Couleur des lampes contre l'arrêt des PNJ | PNJ arrêtés au rouge exactement quand la lampe est rouge | **NON TESTÉ** |
| QA-S10 | Trafic physique | P1 | Joueur qui percute un PNJ, PNJ qui arrive derrière un joueur arrêté, joueur arrêté dans un carrefour | PNJ solide (pas de traversée), poussé puis arrêté ; aucun PNJ projeté en l'air ni bloqué durablement ; propriété réseau des PNJ au serveur | **NON TESTÉ** |
| QA-S11 | Trafic / joueur | P1 | Contact véhicule client ↔ PNJ serveur sous latence | Pas de correction serveur abusive du véhicule du joueur, pas d'interaction avec QA-A01 | **NON TESTÉ** |
| QA-S12 | Trafic | P2 | Apparition et retrait des corps physiques | Jamais à moins de 300 m d'un joueur pour une apparition d'agent ; matérialisation sans chevauchement d'un véhicule de joueur | **NON TESTÉ** |
| QA-S13 | Piétons | P2 | Rendu local autour de la caméra | ≤ 60 figurants, sur les trottoirs, jamais touchés par les lancers de suspension | **NON TESTÉ** |
| QA-S14 | Dégâts / énergie | P2 | Dégâts, consommation, propriété réseau et caméras du lot 0.2 dans le monde ouvert | Inchangés par rapport à la zone d'essai | **NON TESTÉ** |
| QA-S15 | Retour au plot | P3 | Prototype abandonné loin du parc | Renvoi au plot après 90 s sans joueur à proximité, sans heurter le trafic | **NON TESTÉ** |
| QA-S16 | Non-régression | P1 | Les 7 sessions VM existantes sur la place de développement (`test-vm.cmd`) avec le code du lot 0.3 | Mêmes résultats qu'au lot 0.2 (hors anomalies QA-A01/A02) | **NON TESTÉ** |

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
| QA-S17 | Véhicules personnels | P1 | Sortie, conduite, retour : dégâts, énergie et kilométrage restaurés à la reconnexion | Valeurs serveur réconciliées (énergie jamais augmentée, dégâts jamais réduits) | **NON TESTÉ** |
| QA-S18 | Définition réglée | P1 | Exemplaire réglé conduit par son propriétaire : même définition chez le client et le serveur | Aucune correction de mouvement due à un écart de réglages | **NON TESTÉ** |
| QA-S19 | Intérieurs | P2 | Intérieurs privés instanciés (streaming, 10 joueurs dans 10 intérieurs) | Arrivée sans chute, maquettes non conduisibles, sortie à la même entrée | **NON TESTÉ** |
| QA-S20 | Entrées | P2 | Invites d'entrée sur les 13 emplacements de la carte et les 3 garages publics | Invites présentes, lieux reconnus même secteur non chargé côté client | **NON TESTÉ** |
| QA-S21 | Zone d'essai | P2 | Place de développement : entrée et garage public d'essai, données synthétiques (3 prototypes, 1 propriété moyenne, pièces) | Disponibles en Dev seulement, perdues à l'arrêt du serveur (stockage mémoire) | **NON TESTÉ** |
| QA-S22 | Non-régression | P1 | Sessions VM existantes après les modifications du service des véhicules (création des enregistrements, participants des collisions) | Résultats identiques au lot 0.2 (hors anomalies connues) | **NON TESTÉ** |

## 4. Charge, performance et stabilité

| Id | Système | Priorité | Essai | Attendu | État |
|---|---|---|---|---|---|
| QA-P01 | Serveur | P1 | 24 joueurs répartis dans les zones, trafic à 140 agents | Fréquence serveur stable ; coût de `TrafficService` mesuré par pas | **NON TESTÉ** |
| QA-P02 | Client | P1 | Images par seconde sur un appareil de référence (ordinateur et mobile), métropole dense, pluie, nuit | Mesure réelle ; **aucun objectif (~60 FPS) n'est déclaré atteint** | **NON TESTÉ** |
| QA-P03 | Mémoire | P2 | Mémoire client et serveur avec la carte complète (≈ 37 000 pièces) et le streaming | Mesure réelle, comparaison avec et sans streaming | **NON TESTÉ** |
| QA-P04 | Réseau | P2 | Bande passante par joueur (trafic physique, véhicules, attributs météo) | Mesure réelle | **NON TESTÉ** |
| QA-P05 | Démarrage | P2 | Temps de démarrage serveur (calcul `WorldLayout`, `TrafficModel.newWorld`) et client (index des trottoirs) | Mesure réelle | **NON TESTÉ** |
| QA-P06 | Stabilité | P2 | Session longue (≥ 2 h) | Pas de fuite (corps PNJ, figurants), pas de blocage du trafic | **NON TESTÉ** |
| QA-P08 | Profils | P2 | Coût des copies de profil par transaction (profil volumineux) et des instantanés envoyés aux clients | Mesure réelle | **NON TESTÉ** |
| QA-P09 | Intérieurs | P3 | Coût des maquettes exposées (jusqu'à 10 par intérieur) | Mesure réelle | **NON TESTÉ** |
| QA-P07 | Réglages | P3 | Budget PNJ (140), rayon physique (260 m), plafond (48), rayon des piétons (150 m), rayons de streaming | Réglages ajustés d'après QA-P01 à P04 | **NON TESTÉ** |

## 5. Vérifications de la dernière exécution hors Studio

Ces contrôles automatiques ne remplacent aucun essai ci-dessus. Résultats et commandes : `docs/lot-0.3/RAPPORT_LOT_0.3.md` §2 et
`docs/lot-0.4/RAPPORT_LOT_0.4.md` §2.
