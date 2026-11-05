# Checklist des essais humains — lot 0.9

À l'attention du propriétaire. Ces essais demandent un humain : ressenti, lisibilité, vrais périphériques, vrais
comptes, plusieurs appareils. **Aucun n'est considéré comme réussi sans ton retour.** Les essais automatisés
(VM) déjà passés sont indiqués pour éviter de refaire ce qu'une machine vérifie déjà.

Déjà déclarés (ne pas refaire, sauf si tu veux en consigner le détail) : tes « neuf vérifications manuelles du
lot 0.1 sans problème » (brief du lot 0.2) — conduite clavier, manette, les deux ensemble, chat, manette
débranchée, perte de focus (QA-H01 à QA-H06). Merci de préciser, si possible, quelles étaient les neuf : le rapport
du lot 0.1 n'en listait que sept.

## Comment rapporter

Pour chaque ligne : **OK**, **KO** ou **non fait**. En cas de KO, relève :

- l'heure, la place (développement ou monde ouvert), le lieu sur la carte (zone, route ou nom du lieu) ;
- le véhicule (nom affiché) et le périphérique (clavier-souris, manette : modèle) ;
- ce que tu as fait, ce que tu attendais, ce qui s'est passé ;
- une capture ou une courte vidéo si possible ; le texte de la notification affichée ;
- dans Studio : la fenêtre Output (erreurs en rouge), copiée.

Conditions communes : place construite depuis la branche `feat/integration-qa-0.9` (`rojo build`, voir README),
Studio ou session de test privée ; profils **en mémoire** (aucune sauvegarde réelle, c'est normal).

## Session 1 — Conduite et physique (≈ 45 min, place de développement)

| # | Étapes | Attendu |
|---|---|---|
| 1.1 | Clavier : Maj / Ctrl gauche (rapports) sur P-02 (manuelle), C (embrayage), 1/2/3 (aides), G (récupération, P-03), V (caméras) | Effet immédiat, affiché au HUD (QA-H07) |
| 1.2 | Manette : RB / LB, B (embrayage), croix gauche/droite (aides), croix haut (caméra) | Idem (QA-H08) |
| 1.3 | P-02 : démarrer en côte (rampe), faire caler volontairement, redémarrer | Rampe d'embrayage utilisable, calage clair au HUD (QA-H09) |
| 1.4 | Conduire les six boîtes (P-01 auto, P-02 manuelle, P-03 rapport unique, variantes DCT, séquentielle, CVT) ; tester l'arrêt en pente frein relâché | Ressenti crédible ; dis si le maintien à l'arrêt (arbitrage A3) te convient (QA-H10) |
| 1.5 | ABS, antipatinage, ESP actifs puis coupés : freinage d'urgence, départ arraché, survirage provoqué | Différence perceptible, indicateurs au HUD |
| 1.6 | Zone mouillée de la zone d'essai : freinage 80–0 km/h | Distance nettement plus longue qu'au sec (QA-S07) |
| 1.7 | Lisibilité du HUD (aides, énergie, dégâts) et des vues cockpit / capot / pare-chocs | Lisible sans masquer la route (QA-H11) |
| 1.8 | Choc volontaire contre un mur à ~15 puis ~35 km/h ; puis entre deux voitures (deux comptes) | Dégâts visibles, direction et moteur affectés au second choc |
| 1.9 | **18 modèles proposés** (garage ou concession, en développement) : conduire chacun 2 min | Note de ressenti par modèle ; signale tout modèle injouable (QA-V02) |

## Session 2 — Monde ouvert (≈ 60 min, place monde ouvert)

| # | Étapes | Attendu |
|---|---|---|
| 2.1 | Depuis le parc des prototypes, parcourir les **sept zones** au volant, sans téléportation, en suivant le GPS | Aucune chute, aucun blocage, routes continues (QA-H12) |
| 2.2 | Carrefours, bretelles, lacets de montagne, corniche | Tracés lisibles et variés (QA-H13) |
| 2.3 | Rouler dans le trafic : feux, priorités, PNJ qui arrive derrière toi à l'arrêt ; percuter (doucement) un PNJ | Comportement crédible, jamais traversé (QA-H14, QA-S10) |
| 2.4 | Pluie, brouillard, orage, nuit (attendre ou demander un forçage) | Visibilité et adhérence différentes, phares allumés la nuit (QA-H15) |
| 2.5 | Qualité graphique basse / moyenne / haute (Paramètres → Graphismes) | Décor et lumières plus ou moins présents ; dis si la basse reste agréable |
| 2.6 | Accessoires d'habillage (lampadaires, conteneurs, palmiers…) | Aucun accessoire flottant ou enterré gênant ; signale les lieux (QA-V01) |

## Session 3 — Garages et économie (≈ 45 min)

| # | Étapes | Attendu |
|---|---|---|
| 3.1 | Panneau garage (P) au clavier-souris puis à la manette (via le téléphone) | Navigation complète, focus visible, aucune action involontaire (QA-H16) |
| 3.2 | Entrer dans sa propriété, exposer, ranger, sortir un véhicule, le ramener | Une seule voiture conduisible ; retour refusé loin de l'entrée (QA-H17) |
| 3.3 | Garage public : réglages, pièce, esthétique ; réglages extrêmes | Effet perceptible ; refus clairs (QA-H18) |
| 3.4 | Panneau économie (J) : devis, confirmation, état « en attente » puis « confirmé » | Jamais « réussi » avant la réponse du serveur (QA-E10, QA-H20) |
| 3.5 | Les 8 métiers, au moins une mission complète chacun, dont une **sans véhicule personnel** (véhicule professionnel prêté) | Mission guidée, payée une fois (QA-E04, QA-E05, QA-E14) |
| 3.6 | Plein, recharge, lavage, réparation ; interrompre un plein en repartant | Facturation juste, rien de gratuit (QA-E06, QA-E12) |

## Session 4 — Courses (≈ 45 min, deux comptes conseillés)

| # | Étapes | Attendu |
|---|---|---|
| 4.1 | Panneau K au clavier et à la manette ; inscription, prêt, grille | Utilisable, affichage de course lisible (QA-R14) |
| 4.2 | Une épreuve de chaque discipline (sprint, circuit, contre-la-montre, drift, drag, rallye) | Départ, points de passage, arrivée, résultat (QA-R10 à R12) |
| 4.3 | Faux départ volontaire au sprint et au drag | Pénalité (sprint) / manche perdue (drag) |
| 4.4 | Mode protégé avec dégâts antérieurs ; mode réaliste | Protégé : état restauré ; réaliste : dégâts conservés (QA-R17) |
| 4.5 | Ressenti des départs, de la grille, des pénalités et du drift | Ton jugement (QA-R15) |

## Session 5 — GPS et smartphone (≈ 30 min)

| # | Étapes | Attendu |
|---|---|---|
| 5.1 | Téléphone (T / Select) : chaque application ; à l'arrêt et en roulant | Mode rapide en roulant, aucun freinage ni validation involontaire (QA-U05) |
| 5.2 | Destination lointaine, suivre le GPS, sortir volontairement de l'itinéraire | Indications à temps, recalcul (QA-U02) |
| 5.3 | Résolutions, taille de texte, contraste, opacité | Lisible (QA-U04) ; passage en anglais : aucun texte qui déborde (QA-U12) |
| 5.4 | Notifications pendant la conduite | Discrètes ; alertes critiques bien perçues (QA-U13) |

## Session 6 — Social (≈ 30 min, deux comptes)

| # | Étapes | Attendu |
|---|---|---|
| 6.1 | Créer un groupe, inviter, accepter, quitter, exclure | Conforme (lot 0.7) |
| 6.2 | Partage de position : désactivé par défaut, activer, révoquer | Position visible seulement pendant le partage (QA-U08) |
| 6.3 | Inviter l'autre dans sa propriété, visite, conduite prêtée, révocation | Accès refusé sans invitation ; retour à l'entrée à la révocation (QA-H19) |
| 6.4 | Place passager (portière droite) : propriétaire, membre du groupe, inconnu | Inconnu refusé |
| 6.5 | Canaux texte de groupe et de proximité | Messages filtrés par Roblox (QA-U07) |

## Session 7 — Audio et graphismes (après téléversement des sons seulement)

Les sons ne sont **pas** téléversés : rien n'est joué aujourd'hui. Cette session n'a de sens qu'après ton feu vert
et le téléversement (`docs/lot-0.8/ASSETS_ET_LICENCES.md` §4).

| # | Étapes | Attendu |
|---|---|---|
| 7.1 | Écouter les 30 fichiers de `build/audio/` (`python tools/audio/synth.py`) | Ton avis : à garder, à refaire, à remplacer |
| 7.2 | Après téléversement : moteurs essence, diesel, électrique ; ambiances par zone ; volumes par catégorie | Fondus sans saut, volumes indépendants (QA-V04, V05) |
| 7.3 | Radio à trois (conducteur, deux passagers) : station, coupure individuelle, sortie | Station commune, coupure chez soi seulement, rien entendu dehors (QA-V06) |
| 7.4 | Mode photo : à pied, à l'arrêt, contre un mur, près d'une propriété, capture | Caméra bornée, aucune traversée, capture proposée (QA-V07) |

## Session 8 — Arrivée d'un nouveau joueur (≈ 20 min)

| # | Étapes | Attendu |
|---|---|---|
| 8.1 | Nouveau profil (place de développement) : introduction complète, puis une seconde fois en la passant | Passable à tout moment (QA-V08) |
| 8.2 | Essayer les trois candidats, choisir, confirmer ; tenter de choisir à nouveau | Un seul véhicule de départ, incessible |
| 8.3 | Les 8 exercices | Réussite détectée, aucun crédit (QA-V10) |
| 8.4 | Pendant les 60 premières secondes, demander à un second compte de te foncer dessus en voiture | Aucun dégât, voiture qui ne te percute pas (QA-V09) |
| 8.5 | Ouverture automatique de la fenêtre au clavier, puis à la manette | Aucun gel ; focus seulement à la manette (QA-V15) |

## Session 9 — Points laissés par la campagne interactive du lot 0.9.1 (≈ 20 min)

Ces points n'ont pas pu être tranchés dans la VM (`TESTS_INTERACTIFS_AUTONOMES.md` §12–13).

| # | Étapes | Attendu |
|---|---|---|
| 9.1 | Dans le **client Roblox** (pas Studio), à pied : touche **O** | Le mode photo s'ouvre (dans Studio, la touche n'atteint jamais le jeu) |
| 9.2 | Ouvrir le téléphone (T) à pied, regarder son personnage de face puis depuis un second compte | Téléphone dans la main, **bras levé** (la capture de la VM le montre bras baissé, QA-U10) |
| 9.3 | Monde ouvert, de nuit (22 h), qualité moyenne puis haute, en ville et sur route | Avis : la nuit est-elle trop sombre hors des lampadaires ? |
| 9.4 | Ouvrir le garage (P) à la souris, cliquer un autre onglet | Avis : le contour de focus resté sur le premier onglet gêne-t-il ? |
| 9.5 | Vue cockpit (V jusqu'à « Cockpit ») sur trois modèles | Route visible au-dessus du volant ; position des yeux naturelle (QA-F15) |
| 9.6 | Mission de taxi : passager pris en charge | Passager assis à la place passager, pas au-dessus du toit (QA-F19) |
