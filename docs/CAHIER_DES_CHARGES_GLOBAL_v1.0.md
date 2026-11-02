> **Statut actualisé — 2 novembre 2026 :** Ce dossier documentaire a été **officiellement approuvé globalement** par le propriétaire du projet, après sa rédaction initiale. Les mentions « non approuvé » et « aucune exécution » présentes dans le texte historique ci-dessous décrivent l'état **avant** cette approbation. Le développement a ensuite été autorisé explicitement. Les contraintes fonctionnelles et les réserves techniques demeurent applicables.

---

# CAHIER DES CHARGES GLOBAL CONSOLIDÉ

## Jeu automobile multijoueur Roblox — Projet original

**Dossier de consolidation documentaire — version candidate 1.0**  
**Date de référence : 2 novembre 2026**  
**Référentiel : onze chapitres individuels officiellement validés en v1.0 ; trente-trois décisions AUD validées**  
**Statut d'approbation : À SOUMETTRE À VALIDATION GLOBALE — NON APPROUVÉ À CE STADE**  
**Autorisation d'exécution : AUCUNE**

> **Portée du document.** Ce dossier rassemble et précise les règles validées, les scénarios E.2, les risques E.3 et les conditions de vérification E.4. Il est préparé pour la décision finale du propriétaire du projet. Il ne prétend pas reproduire mot pour mot les textes intégraux des onze chapitres et tous leurs critères numérotés d'origine, qui ne sont pas fournis ici comme fichiers sources complets. En cas de différence avec une décision antérieure explicitement validée, cette décision antérieure prévaut jusqu'à arbitrage explicite. Les critères complémentaires de ce dossier sont des propositions documentaires de vérification, pas des résultats de tests.

---

# 0. Synthèse exécutive et gouvernance

**Vision.** Concevoir un monde automobile Roblox original, social et multijoueur, privilégiant la sensation de conduite semi-réaliste, l'identité des véhicules, le plaisir de progression, les courses compétitives et une économie équitable. Les marques et modèles automobiles du lancement sont fictifs et créés spécifiquement pour le jeu. Aucun code ni actif d'un autre projet ne sera repris par défaut.

**Engagements majeurs.** Sept zones, dix-huit modèles au lancement dont trois options de départ gratuites, deux concessions, trois garages publics, six stations-service, trois lavages, recharge électrique dans les sept zones, huit familles de missions, six disciplines de course, propriétés et garages évolutifs, saisons classées de huit semaines, dégâts persistants et modes protégés, interface smartphone, esthétique et audio premium, FR/EN, PC/console prioritaires. Capacité cible de vingt-quatre joueurs par serveur et fluidité d'environ 60 FPS sous réserve d'études et validations.

**Statut.** Les chapitres 1 à 11 et les 33 décisions transversales AUD ont été validés individuellement. Leur consolidation documentaire n'emporte pas l'approbation du cahier des charges global, encore distincte. Toute programmation, tout prototype, essai technique, production d'actifs, changement de dépôt, déploiement ou publication demeure interdit avant accord global exprès.

**Critères de bonne fin documentaire.** Couverture du périmètre, règles sans contradiction majeure identifiée, scénarios nominaux et dégradés définis, risques classés, paramètres à fixer identifiés et traçabilité entre chapitres, arbitrages et vérifications. La réalisation effective, les chiffres de performance, les politiques Roblox au moment de la mise en ligne et les réponses de services tiers devront être validés ultérieurement.

## 0.1. Glossaire

- **Modèle :** définition d'une voiture du catalogue ; **exemplaire :** véhicule individuel possédé, assorti d'un identifiant unique.
- **Starter :** exemplaire gratuit attribué une fois après choix définitif parmi trois modèles ; son instance est incessible. Un autre exemplaire du même modèle acheté normalement suit les règles ordinaires.
- **Mode réaliste :** course qui conserve les consommations et dommages persistants applicables.
- **Mode protégé :** session où les conséquences générées pendant l'épreuve sont isolées, puis l'état persistant d'avant-course est conservé ou restauré sans effacer les dégâts préexistants.
- **Pièce installée :** composant actuellement intégré à l'exemplaire ; **pièce détachée :** composant possédé hors véhicule.
- **Configuration :** ensemble de réglages sauvegardés, non un inventaire supplémentaire.
- **Opération sensible :** opération modifiant crédits, propriété, inventaire, résultat classé, permission ou autre état durable.
- **Réconciliation :** procédure vérifiant les états effectivement confirmés pour mener une opération à son état valide, la reprendre ou la compenser sans duplication.
- **GO / NO-GO :** décision formelle de rendre la version publique, distincte de la validation documentaire et de l'autorisation de démarrer le développement.

## 0.2. Règle de précédence

Les onze chapitres individuels v1.0 validés et les décisions AUD explicitement approuvées font foi. Les présentes reformulations constituent le dossier transversal. Aucune recommandation de réalisation, optimisation ou conformité externe n'autorise une réduction du périmètre. Tout conflit constaté, objectif non réalisable ou changement de politique Roblox sera documenté puis soumis à décision explicite.

# 1. Vision produit et expérience fondamentale

## 1.1. Proposition de valeur

L'expérience est un jeu de voiture multijoueur en monde ouvert centré sur la conduite, la collection, l'acquisition et la préparation de véhicules, les trajets, les missions et les compétitions. La physique est accessible à apprendre mais suffisamment exigeante pour rendre la vitesse, la maîtrise de l'adhérence et la qualité des réglages significatives. Les joueurs doivent pouvoir progresser sans acheter de Robux.

## 1.2. Principes non négociables

- Univers et véhicules fictifs originaux ; pas d'emploi non autorisé de marques, logos, sons ou musiques protégés.
- Physique différenciée par véhicule, transmission, motorisation, puissance, masse et préparation ; ne pas substituer une conduite arcade uniforme.
- ABS, antipatinage et contrôle de stabilité existent uniquement lorsque le modèle en dispose ; état par défaut désactivé selon les règles validées, sans assistances universelles cachées.
- Aucun avantage compétitif direct vendu contre Robux ; les achats cosmétiques et commodités permises ne modifient pas les performances mécaniques, les places de propriétés au-delà des limites validées, ni le résultat des compétitions.
- PC et console constituent les plateformes prioritaires du lancement. L'adaptation mobile/tablette intervient ultérieurement, sans promettre une disponibilité au lancement.
- Les fonctionnalités du lancement doivent être présentes avant le lancement public définitif ; le développement pourra être organisé en lots intégrés lorsqu'il sera autorisé.

# 2. Carte, monde partagé et infrastructure

## 2.1. Les sept zones

1. **Métropole :** centre dense, routes urbaines, circulation, stationnement et services.
2. **Banlieues :** transitions résidentielles, routes secondaires, accès au réseau principal.
3. **Zone industrielle et docks :** voiries larges, fret et activités de livraison.
4. **Montagnes et cols :** dénivelés, virages serrés, maîtrise du freinage et de l'adhérence.
5. **Campagne :** routes ouvertes, exploration et diversité des revêtements.
6. **Complexe motorsport :** équipements dédiés à plusieurs disciplines compétitives.
7. **Littoral :** routes côtières, stationnement et espaces de rencontre.

Les espaces doivent former une géographie fonctionnelle, sans téléportation libre imposée comme remplacement du déplacement normal. Un trajet autoroutier d'environ six à dix minutes est une indication de conception issue du chapitre 2, non un résultat de mesure.

## 2.2. Équipements fixes du lancement

- Deux concessions automobiles physiques pour les véhicules neufs.
- Trois garages publics proposant la préparation et les interventions validées.
- Six stations-service, conservées en totalité.
- Trois lavages automobiles.
- Réseau de recharge électrique avec au moins un emplacement public dans chaque zone, réparti entre certaines stations-service et des pôles dédiés ; la possibilité réelle des itinéraires est vérifiée à partir de l'autonomie des modèles électriques.
- Propriétés achetables et propriété de départ gratuite selon le chapitre 4.

## 2.3. Temps, météo et circulation

Cycle jour/nuit synchronisé d'environ trente minutes. Météo dynamique incluant soleil, pluie, brouillard et orage ; les effets de surface et de visibilité doivent influer sur la conduite lorsque prévus. Le trafic PNJ et les piétons conservent leur présence modérée. Les véhicules PNJ pertinents restent collisionnables ; les PNJ éloignés peuvent être simulés à moindre coût sans anomalies de proximité. Les routes et volumes de collision indispensables sont chargés avant l'arrivée d'un véhicule rapide.

## 2.4. Recharge électrique

Facturation en crédits selon l'énergie réellement ajoutée, tarif affiché et coût confirmé. Recharge progressive courte, variable selon la borne, le modèle et l'énergie demandée. Les mécanismes doivent empêcher le blocage abusif des emplacements par d'autres joueurs et protéger les opérations interrompues. Batterie vide : dépannage/remorquage ordinaires, pas de recharge d'urgence gratuite ; la mission garantie d'AUD-ECO-01 reste accessible même sans voiture personnelle utilisable.

# 3. Catalogue, conduite et dommages des véhicules

## 3.1. Catalogue et acquisition

Dix-huit modèles fictifs originaux au lancement, avec diversité de silhouettes, catégories, niveaux de performance, transmissions, prix et motorisations. Trois modèles constituent un choix de départ gratuit, représentés comme des options raisonnablement équivalentes ; ils peuvent être essayés dans un contexte protégé avant sélection. Le choix est définitif et l'exemplaire attribué gratuitement ne peut ni se vendre ni se transférer. L'attribution est contrôlée côté serveur et idempotente.

## 3.2. Simulation

Conduite fondée sur propulsion/traction/quatre roues motrices, répartition des masses, couple, régime, suspension, adhérence des pneus et état de route. Boîtes automatiques, manuelles et variantes validées (double embrayage, séquentielle, CVT), ainsi que motorisations thermiques et électriques, selon l'identité de chaque voiture. Différences de grip sec/pluie, accélération, freinage et transfert de charge. Les commandes restent réactives avec contrôles serveur des états critiques, sans punir automatiquement la latence.

## 3.3. Dégâts et ressources

Trois niveaux visuels de dégâts (rayures, dommages localisés, déformation limitée sous réserve des possibilités validées), effets mécaniques pertinents et persistance des conséquences hors sessions protégées. Essence, diesel et énergie électrique sont consommés et sauvegardés selon les règles du véhicule. Pas d'obligation générale de maintenance périodique de composants ni de simulation thermique avancée des pneus au lancement. Le lavage et la réparation suivent des mécanismes distincts de la gratuité des essais protégés.

## 3.4. Caméras et contrôles

Caméras de poursuite proche/lointaine, cockpit, capot, pare-chocs, et mode photo spécifique. Clavier/souris et manette prioritaires ; compatibilité volant conditionnée à la faisabilité et aux périphériques retenus. Les indications d'interface suivent le périphérique actif, sans déclencher d'action involontaire.

## 3.5. Immobilisation

Une fonction limitée et gratuite de désenlisement peut remettre le véhicule dans une position valable sans modifier gratuitement les dégâts ni le carburant. Des prestations de dépannage/remorquage payantes restent possibles selon les règles existantes. La batterie vide ne donne pas droit à une recharge cachée.

# 4. Propriétés, garages et préparation

## 4.1. Propriétés

Une propriété gratuite initiale est attribuée de façon unique, non revendable, et compte dans la limite maximale de cinq propriétés possédées simultanément. Les propriétés payantes sont revendables à 70 % de leur coût ; extensions à 40 % et modules à 60 % selon les montants réellement éligibles et les règles du chapitre 4. Aucune augmentation pay-to-win des plafonds par Robux.

## 4.2. Capacité physique et collection

Capacités typiques d'exposition selon type de propriété : petits garages de 1 à 2 places, moyens de 3 à 5, grands de 6 à 10. Ces capacités physiques ne limitent pas arbitrairement le nombre d'exemplaires automobiles possédés dans la collection, sous réserve de limites purement techniques justifiées et explicitement arbitrées si besoin.

## 4.3. Préparation et modules

Trois garages publics de préparation complète ; modules privés optionnels installables dans les garages des propriétés compatibles, selon les catégories prévues. Préparation mécanique et esthétique, pièces réellement possédées et compatibles. Jusqu'à cinq configurations de réglages par véhicule, sans duplication de composants.

## 4.4. Permissions et prêts

Accès aux propriétés sur invitation, permissions vérifiées à chaque action sensible. Les droits groupe/propriété/prêt réel sont indépendants. Prêt réel : les conséquences persistent selon les règles approuvées. Essai protégé : isolation des conséquences. Révocation : aucune nouvelle action autorisée, usages en cours terminés ou arrêtés en état sûr sans perte d'actif.

# 5. Progression, missions, économie et monétisation

## 5.1. Progression

Les crédits rémunèrent les activités autorisées, avec une réputation générale à cinq niveaux distincte des rangs classés. L'ordre de grandeur de huit à douze mille crédits par heure est une hypothèse illustrative d'équilibrage, non une rémunération garantie. Les paramètres définitifs doivent respecter la durée, la difficulté, les coûts et les abus possibles.

## 5.2. Huit familles de missions

1. Taxi / VTC.
2. Livraison de colis.
3. Transport de pièces spéciales.
4. Assistance à des PNJ immobilisés.
5. Voiturier, convoyage ou déplacement commandé.
6. Stationnement et slalom de précision.
7. Exploration tout-terrain.
8. Essais et tests de véhicules.

Elles restent viables économiquement aux côtés des courses. Au moins une activité de ce catalogue doit toujours être accessible à un joueur sans crédit ni véhicule personnel utilisable, grâce à un véhicule professionnel temporaire, sans avance de crédits, avec paiement normal et protections anti-abus.

## 5.3. Marché de l'automobile

Achat de voitures neuves dans l'une des deux concessions physiques uniquement. Marché de véhicules d'occasion utilisable via les interfaces autorisées à l'arrêt ou à pied. Commission de 5 % sur les ventes entre joueurs. Reprise en concession approximativement égale à 60 % du prix neuf, ajustée à l'état. Les pièces payées détachées éligibles peuvent être revendues à 75 % de leur prix d'achat. Les pièces installées suivent le véhicule vendu ; profils de réglages transférés uniquement s'ils restent réalisables. Les cosmétiques premium liés au compte ne sont jamais transférés.

## 5.4. Immobilier et coût de la vie

Les prix de propriétés d'environ 25 à 60 mille crédits représentent une fourchette de travail illustrative, non un barème officiellement figé. Réparer, recharger et rouler doivent avoir un coût lisible mais ne doivent pas créer d'impasse économique permanente. Les activités de précision peuvent donner une rémunération normalement calibrée sans duplication ou exploitation.

## 5.5. Robux

Cosmétiques et commodités équitables permises ; interdiction des boosts de performance, crédits payants déséquilibrants, droits immobiliers excédant les plafonds validés, résultats compétitifs achetables ou réparations premium donnant un avantage injustifié. Toute fonction payante doit être présentée honnêtement et respecter les règles Roblox en vigueur.

# 6. Courses, compétition et saisons

## 6.1. Six disciplines

Sprint, circuit, contre-la-montre, drift, drag et rallye. Disciplines adaptées à des conditions et parcours pertinents ; les spécificités des classements et modes restent conformes au chapitre 6.

## 6.2. Modes réaliste et protégé

Le mode réaliste applique les dommages et consommations persistants validés. Le mode protégé conserve/restaure exactement l'état persistant du véhicule d'avant-course, y compris les dégâts déjà présents. Les deux modes de course officiels sont rémunérateurs. Les gains bruts réalistes tiennent compte des coûts/risques pour viser un gain net comparable au mode protégé à durée, difficulté et performance équivalentes, sans garantie de gains individuels. Les essais et entraînements privés ne rapportent rien ; les courses privées éligibles conservent leurs faibles récompenses encadrées.

## 6.3. Compétition classée

Saisons de huit semaines. Rangs Bronze, Argent, Or, Platine, Diamant indépendants de la réputation générale. Ranked sprint/circuit ; drift dispose de sa logique compétitive distincte. Météo et adhérence normalisées pour résultats officiels et records comparables. Les règles anti-arrangement et anti-farming ne doivent pas pénaliser les répétitions honnêtes.

## 6.4. Transition des sessions

Le véhicule est réservé exclusivement à l'engagement dans une course. Vente, prêt concurrent, démontage ou autre opération incompatible bloqués. Le transfert entre serveurs et la sortie doivent conserver le propriétaire, l'énergie, les dégâts et les résultats corrects. Reconnexion au même événement proposée lorsque possible, cible d'environ quatre-vingt-dix secondes sous réserve de faisabilité et des règles d'équité. Issue de course décidée par les états confirmés ; récompense unique après validation serveur.

# 7. Interface, smartphone, navigation et social

## 7.1. HUD et GPS

Affichage contextuel de la vitesse, boîte, régimes et alertes utiles, GPS lisible et navigation adaptée au clavier/souris comme à la manette. Le joueur peut configurer les informations non essentielles. Trois niveaux d'alerte hiérarchisés ; les alertes critiques sont multimodales, les notifications secondaires peuvent être différées pendant la conduite et restent consultables dans un historique.

## 7.2. Smartphone

Smartphone physiquement tenu, possibilité d'affichage agrandi, contrôles rapides sécurisés. Pas de mise en pause du monde, de freinage automatique, de réparation ou tuning à distance, ni d'achat de voiture neuve hors concession. Les fonctions complètes et transactions sensibles ne sont accessibles que dans les contextes prévus, notamment à l'arrêt ou à pied. Si le véhicule se met à rouler, seules les actions rapides restent utilisables ; brouillons éventuels conservés sans confirmation automatique.

## 7.3. Social et permissions

Groupes temporaires de huit joueurs maximum. Partage de position explicitement opt-in, désactivé par défaut, révocable et terminé à la sortie du groupe. Invitations de propriétés séparées du statut de groupe et des prêts de véhicules. Pas d'accès automatique aux informations économiques ni à la collection privée ; seules les expositions volontaires et les droits valides permettent les consultations correspondantes.

## 7.4. Accessibilité et langue

Changement de périphérique sans validation involontaire ; focus préservé ou restauré. Interface console intégralement navigable à la manette. Contrastes, tailles, options d'animation et de volumes configurables. Français et anglais vérifiés pour tous les textes essentiels, particulièrement les achats, ventes, avertissements et erreurs ; changement de langue sans perte de progression.

# 8. Architecture, sécurité et persistance

## 8.1. Principes

Simulation hybride : conduite réactive côté utilisateur, événements durables et sensibles contrôlés par le serveur. Contrôles contextuels des positions, collisions, dégâts, résultats et opérations économiques. Tolérance raisonnable aux perturbations réseau ; les faux positifs ne déclenchent pas automatiquement des sanctions. La présente spécification n'impose aucune bibliothèque ni architecture de code avant étude.

## 8.2. Identité et écriture exclusive

Identifiant unique par exemplaire de voiture et par transaction. Profil actif sous exclusivité d'écriture ; un ancien serveur ne peut écraser un état plus récent. Réservations de véhicules en course et pendant les transactions incompatibles. Les verrouillages doivent être récupérables après déconnexion, sans blocage permanent injustifié.

## 8.3. Transactions

États persistants et traçables pour transferts de crédits, pièces, véhicules et propriétés. Réservation des ressources, confirmation serveur, reprise ou compensation en cas d'interruption, absence de double paiement/propriété. Une réponse incertaine doit être réconciliée plutôt que répétée à l'aveugle. Les confirmations d'interface doivent refléter le résultat effectif du serveur.

## 8.4. Panne et restauration

Lorsque les sauvegardes sont indisponibles, suspension des opérations persistantes impossibles à sécuriser ; uniquement les activités réellement sûres peuvent rester accessibles. Restaurations ciblées à partir des états confirmés, journaux et sauvegardes, sans retour arrière aveugle qui effacerait des transactions légitimes. Corrections économiques ciblées, protection des joueurs de bonne foi ; sanctions séparées de la rectification d'un actif.

## 8.5. Évolutions et sécurité

Schémas de données versionnés, migrations compatibles lorsque possible, mises en ligne progressives si pertinentes et retour arrière ne détruisant pas les données plus récentes. Accès minimaux aux environnements, développement/test/production isolés, données synthétiques par défaut, aucun transfert de possessions de test. Anti-cheat contextualisé, sanctions proportionnées, modération et réexamen possible. Journalisation et analytics limités aux besoins d'exploitation et de sûreté, en respectant la confidentialité.

# 9. Direction artistique, audio et photographie

## 9.1. Qualité visuelle

Style semi-réaliste premium cohérent dans les sept zones. Extérieurs et intérieurs soignés pour les dix-huit modèles ; niveaux de détail adaptés à la distance. Reflets et matériaux sensibles à la météo, éclairage jour/nuit, trois niveaux visuels de dommages selon les limites validées. Les optimisations graphiques ne modifient pas la physique ou les fonctionnalités requises.

## 9.2. Audio

Signature sonore par voiture, régime moteur et charge, préparation, revêtement et perspective caméra ; acoustique adaptée aux tunnels, garages, cabines et espaces ouverts. Volumes séparés pour les catégories importantes. Plusieurs stations thématiques fictives avec sons/musiques originaux ou licences compatibles. Le conducteur sélectionne la station commune ; chaque occupant règle son propre volume et peut couper l'écoute ; aucune diffusion extérieure par défaut.

## 9.3. Mode photo

Caméra libre dans des limites encadrées, zoom, profondeur de champ, exposition, filtres, masquage du HUD ; pas de pause multijoueur ni de modification globale de la météo. Conducteur uniquement à l'arrêt, personnage à pied dans les contextes autorisés et passager en mouvement si ce support est faisable. Aucune caméra libre photographique en compétition officielle et aucun contournement des propriétés privées. Capture et partage volontaires et modérés. Galerie privée intégrée limitée conditionnelle à la faisabilité.

# 10. Accueil, tutoriels et qualité de vie

## 10.1. Première connexion

Introduction courte et passable ; trois choix de voitures gratuites comparables avec essais immersifs protégés facultatifs. Choix final explicite, définitif et non répétable, dont l'exemplaire accordé est incessible. Propriété initiale gratuite attribuée une fois. Le joueur peut accéder à l'expérience ordinaire sans finir toutes les leçons ; l'attribution du véhicule personnel impose son choix, mais pas l'achèvement d'un exercice facultatif.

## 10.2. Formation

Modules optionnels, rejouables, sans récompenses, sans dégâts persistants générés et sans réparation gratuite d'un véhicule déjà endommagé. Conseils facultatifs dans le smartphone, aide contextuelle désactivable, possibilité de reprendre après déconnexion. Premier spawn avec protections temporaires contre les collisions/griefing, sans invulnérabilité générale durable. Missions rémunérées normales accessibles séparément des entraînements, y compris l'activité garantie sans crédits ni voiture.

## 10.3. Confirmation et information

Avertissements sur les actions risquées, possibilité de masquer certains conseils facultatifs, mais confirmations économiques et sécuritaires indispensables non contournables. Aucun téléporteur gratuit universel ni arrêt automatique du véhicule depuis les menus.

# 11. Lancement, essais futurs et exploitation

## 11.1. Feuille de route conditionnée à l'autorisation globale

Réalisation ultérieure en lots intégrés : socle conduite/multijoueur/persistance/économie, puis carte, garages, missions, courses, interfaces, immersion et services, jusqu'à réunir tout le périmètre avant le lancement public définitif. Ce découpage est un ordre de préparation, pas une autorisation de commencer ni une réduction du périmètre.

## 11.2. Phases d'accès

Validation interne ; tests fermés ; éventuel accès limité pertinent ; ouverture publique contrôlée auprès des comptes Roblox autorisés ; élargissement aux moins de seize ans lorsque la plateforme l'autorise. Le public cible et le contenu final ne sont pas abandonnés. Les conditions d'âge, publication, classification et abonnement ou frais applicables devront être vérifiées à la date effective de mise en ligne.

## 11.3. GO / NO-GO

Le GO exige le périmètre complet, les campagnes de tests requises réussies, zéro anomalie P0 ou P1 connue non résolue, les anomalies P2/P3 évaluées, l'économie et les données fiables, l'équité compétitive, la localisation FR/EN essentielle, le support et la modération préparés, les obligations Roblox satisfaites et les performances mesurées sur PC/console. Une réserve de faisabilité non démontrée ne peut être présentée comme atteinte ; tout abaissement de cible demande un arbitrage exprès.

## 11.4. Exploitation

Surveillance de la stabilité, onboarding, progression, économie, courses, triche et signalements. Correctifs urgents possibles en toute période ; stabilité prioritaire sur calendrier artificiel de contenu. Saisons classées de huit semaines, avec contrôles réguliers de balance et incidents. Données de tests isolées de la production et non transférées automatiquement. Communication et support structurés par incident technique, économique, de progression et communautaire.

---

# 12. Registre officiel des 33 arbitrages AUD

**Principe.** Les descriptions ci-dessous sont des formulations consolidées des décisions formelles précédemment validées. Les détails normatifs figurent également dans les chapitres spécialisés ci-dessus. Chaque AUD doit être relié aux scénarios de validation du présent dossier.

| Identifiant | Règle consolidée validée | Chapitres |
|---|---|---|
| **AUD-ECO-01** | Mission rémunérée garantie sans argent ni véhicule personnel utilisable ; véhicule professionnel temporaire sans avance, revenus normaux, anti-abus. | 3, 5, 10 |
| **AUD-ECO-02** | Pièces installées transférées avec voiture ; pièces détachées conservées ; profils réalisables seulement ; reprise standard sans double remboursement ; droits premium liés au compte non transférables. | 3, 4, 5, 8 |
| **AUD-RACE-01** | Courses réalistes/protégées rémunératrices, rentabilité nette comparable à conditions équivalentes ; anti-farming contextuel ; abandons encadrés. | 5, 6, 8 |
| **AUD-WORLD-01** | Recharge publique dans sept zones, itinéraires EV viables, implantation mixte, coût par énergie ajoutée, délai court, disponibilité et zéro recharge d’urgence gratuite. | 2, 3, 5 |
| **AUD-PHYS-01** | Conduite réactive et validation contextuelle des collisions, dégâts, mouvements et résultats sensibles, avec tolérance réseau. | 1, 3, 8 |
| **AUD-RACE-02** | Réservation exclusive du véhicule lors des courses, opérations incompatibles bloquées, reprise sécurisée après interruption. | 3, 6, 8 |
| **AUD-WORLD-02** | Chargement prioritaire des routes et collisions, optimisation des PNJ lointains tout en conservant un trafic modéré collisionnable. | 2, 3, 9 |
| **AUD-WEATHER-01** | Normalisation météo/adhérence pour classements et records officiels ; météo dynamique dans le monde et activités autorisées. | 2, 6 |
| **AUD-PERF-01** | Adaptation des éléments graphiques et simulations non critiques, jamais de la physique, de l’équité ni des fonctionnalités promises. | 2, 3, 9 |
| **AUD-RECON-01** | Reconnexion même course lorsque possible, cible ~90 s conditionnelle ; réconciliation des états et récompenses uniquement confirmées serveur. | 6, 8 |
| **AUD-COLL-01** | Contacts et dégâts confirmés contextuellement côté serveur, latence prise en compte, prudence sans immunité exploitable. | 2, 3, 8 |
| **AUD-PERF-02** | 24 joueurs et ~60 FPS visés ; temps d’image médian ≤16,67 ms, P95 ≤20 ms, P99 ≤33,3 ms sur matériel de référence, objectifs sous étude. | 2, 8, 11 |
| **AUD-UI-01** | Menus complets et confirmations bloqués dès la mise en mouvement ; actions rapides autorisées et aucun freinage automatique. | 7, 10 |
| **AUD-UI-02** | Opérations sensibles identifiées, résultats confirmés serveur, récupération après interruption sans double exécution ni fausse réussite. | 5, 7, 8 |
| **AUD-RADIO-01** | Le conducteur choisit la station ; coupure et volume individuels pour les occupants. | 7, 9 |
| **AUD-PHOTO-01** | Photo à pied ou conducteur arrêté ; passager roulant conditionnel ; caméra limitée, pas libre en course officielle, partage volontaire, galerie conditionnelle. | 7, 9 |
| **AUD-ONB-01** | Introduction passable, choix final parmi trois voitures indispensable à l’attribution du starter ; propriété gratuite unique ; exercices facultatifs. | 3, 4, 10 |
| **AUD-INPUT-01** | Indications adaptées au clavier/manette actif, focus conservé/restauré, aucune action ou confirmation involontaire. | 7, 10 |
| **AUD-ACCESS-01** | Alertes multimodales et configurables, notifications secondaires réduites en conduite, historique consultable. | 7, 9, 10 |
| **AUD-L10N-01** | Textes essentiels français et anglais relus, langue modifiable, repli réservé aux textes non critiques. | 7, 10, 11 |
| **AUD-SOC-01** | Droits distincts groupe/propriété/prêt ; invitations contrôlées, contrôle serveur à chaque action sensible, révocation à l’expiration. | 4, 7, 8 |
| **AUD-PRIV-01** | Position opt-in désactivée par défaut ; économie privée ; collection sous permission/exposition volontaire ; photo sans intrusion. | 4, 7, 9 |
| **AUD-DATA-01** | Suspendre nouvelles écritures non sécurisables lors des pannes ; seules activités sûres maintenues ; informer et réconcilier. | 5, 8, 11 |
| **AUD-LOCK-01** | Profil sous écriture exclusive ; session précédente empêchée d’écraser les données confirmées ; récupération sans blocage permanent. | 6, 8 |
| **AUD-TX-01** | Transactions multiprofils identifiées, ressources réservées, états durables récupérables, confirmation/compensation et aucun double paiement/propriété. | 4, 5, 8 |
| **AUD-MIG-01** | Migrations versionnées, compatibles si possible, déploiement progressif si réalisable, retour arrière sans écraser nouvelles données. | 8, 11 |
| **AUD-INC-01** | Suspension ciblée si sûre, étendue si menace globale, restauration vérifiée et communication avant reprise. | 8, 11 |
| **AUD-MOD-01** | Signalements examinés, mesures proportionnées, prévention faux positifs, réexamen possible et confidentialité. | 7, 8, 11 |
| **AUD-REST-01** | Restauration ciblée sur états confirmés, journaux et sauvegardes ; contrôle des transferts plus récents, sans retour aveugle. | 5, 8, 11 |
| **AUD-ECO-03** | Gel ciblé des actifs suspects, investigation, correction des duplications confirmées, protection des innocents, sanctions distinctes. | 5, 8 |
| **AUD-PERM-01** | Révocation immédiate des nouvelles permissions, transition sûre des usages en cours, transactions confirmées indépendantes. | 4, 7, 8 |
| **AUD-PUB-01** | Publication contrôlée aux comptes autorisés puis élargissement aux moins de 16 ans si Roblox l’autorise, sans réduction du public cible ni du contenu. | 10, 11 |
| **AUD-ENV-01** | Dev/test/prod isolés, accès minimaux, données synthétiques, copies protégées si essentielles, zéro transfert d’actifs de test. | 8, 11 |

# 13. Revue E.2 — Scénarios de bout en bout

**Méthode.** Les scénarios suivants sont des cas d'acceptation documentaires recommandés. Ils ne sont pas des tests exécutés. Les étapes servent à vérifier les comportements nominaux, les cas dégradés et les garanties transversales. Référence SCN = nouveau numéro documentaire de scénario, distinct des critères historiques des chapitres.

## SCN-01 — Première connexion et sélection

**Chapitres :** 10; 3; 4. **Décisions :** AUD-ONB-01, AUD-UI-02, AUD-LOCK-01.

**Précondition :** Nouveau profil sans voiture/propriété.

**Parcours prévu :** Passer intro ; comparer/essayer trois modèles ; confirmer un modèle ; se reconnecter.

**Résultat acceptable :** Une seule attribution de l’exemplaire starter incessible et de la propriété gratuite ; les exercices restent accessibles et facultatifs.

**Cas dégradé / contrôle négatif :** Double clic, latence ou déconnexion ne crée aucun doublon.

## SCN-02 — Impasse économique

**Chapitres :** 5; 10. **Décisions :** AUD-ECO-01, AUD-RACE-01.

**Précondition :** Solde nul, véhicules personnels inutilisables.

**Parcours prévu :** Ouvrir l’aide ; rejoindre une famille de mission garantie ; obtenir un véhicule professionnel temporaire et terminer la mission.

**Résultat acceptable :** Aucune avance de crédits ; paiement normal après réussite légitime ; véhicule temporaire non acquis.

**Cas dégradé / contrôle négatif :** Abandon ou reconnexion ne procure pas double paiement ni réparation de bien personnel.

## SCN-03 — Achat de voiture neuve

**Chapitres :** 3; 5; 7; 8. **Décisions :** AUD-UI-01, AUD-UI-02, AUD-TX-01.

**Précondition :** Joueur avec crédits suffisants.

**Parcours prévu :** Se rendre à une concession ; consulter modèle/conditions ; confirmer ; récupérer exemplaire unique.

**Résultat acceptable :** Débit, attribution et inventaire cohérents et confirmés serveur ; achat neuf non réalisable à distance.

**Cas dégradé / contrôle négatif :** Échec d’écriture ou fermeture UI ne duplique ni paiement ni véhicule.

## SCN-04 — Préparation et configurations

**Chapitres :** 3; 4; 5. **Décisions :** AUD-ECO-02.

**Précondition :** Véhicule possédé, pièces payées et pièces détachées.

**Parcours prévu :** Installer des pièces compatibles au garage ; créer cinq configurations ; basculer entre profils.

**Résultat acceptable :** Aucun profil ne duplique physiquement les pièces ; compatibilité et propriété contrôlées.

**Cas dégradé / contrôle négatif :** Pièce revendue ou absente invalide l’application des configurations concernées.

## SCN-05 — Vente de véhicule modifié

**Chapitres :** 3; 4; 5; 8. **Décisions :** AUD-ECO-02, AUD-TX-01, AUD-REST-01.

**Précondition :** Voiture avec pièces installées, stock et cinq profils.

**Parcours prévu :** Retirer une pièce ; mettre en vente ; afficher récapitulatif ; acheter depuis autre profil stationnaire.

**Résultat acceptable :** L’acheteur reçoit la voiture et ses pièces installées, seuls profils réalisables ; le vendeur garde les pièces retirées, frais 5 % appliqués.

**Cas dégradé / contrôle négatif :** Une déconnexion après paiement est réconciliée sans double crédit ni double véhicule.

## SCN-06 — Reprise concession

**Chapitres :** 3; 5. **Décisions :** AUD-ECO-02, AUD-TX-01.

**Précondition :** Voiture payante préparée.

**Parcours prévu :** Retirer volontairement pièces ; demander reprise ; valider ; revendre pièces détachées éligibles.

**Résultat acceptable :** Reprise selon base ~60 % prix neuf ajustée à l’état ; pas de paiement automatique séparé pour pièces installées ; pièces détachées éligibles à 75 %.

**Cas dégradé / contrôle négatif :** Un même composant n’est jamais vendu deux fois.

## SCN-07 — Propriété et limite de garages

**Chapitres :** 4; 5. **Décisions :** AUD-UI-02, AUD-SOC-01.

**Précondition :** Joueur possédant plusieurs véhicules.

**Parcours prévu :** Recevoir propriété initiale ; acheter propriétés et modules ; gérer exposition avec une collection plus vaste.

**Résultat acceptable :** La propriété gratuite compte dans le plafond de cinq, n’est pas revendable ; collection ne dépend pas du nombre de slots exposables.

**Cas dégradé / contrôle négatif :** La tentative d’acquérir une sixième propriété est bloquée selon règles.

## SCN-08 — Prêt réel et révocation

**Chapitres :** 4; 7; 8. **Décisions :** AUD-SOC-01, AUD-PERM-01.

**Précondition :** Propriétaire prête un véhicule à un groupe.

**Parcours prévu :** Accepter prêt réel ; rouler ; révoquer le droit pendant une activité.

**Résultat acceptable :** Les nouveaux droits sont immédiatement refusés ; usage en cours termine en état sûr, dommages persistants gérés normalement.

**Cas dégradé / contrôle négatif :** Aucune duplication, vente ou téléportation dangereuse à la révocation.

## SCN-09 — Essai protégé distinct

**Chapitres :** 3; 4; 10. **Décisions :** AUD-RACE-01, AUD-ONB-01.

**Précondition :** Joueur avec véhicule endommagé.

**Parcours prévu :** Ouvrir essai protégé ; conduire ; sortir.

**Résultat acceptable :** Aucune récompense, aucun dommage nouveau persistant et aucun effacement des dégâts antérieurs.

**Cas dégradé / contrôle négatif :** Quitter brutalement l’essai ne restaure pas abusivement les dommages d’avant.

## SCN-10 — Course réaliste officielle

**Chapitres :** 3; 6; 8. **Décisions :** AUD-RACE-02, AUD-RACE-01, AUD-TX-01.

**Précondition :** Véhicule engagé dans sprint ou circuit.

**Parcours prévu :** Réserver voiture ; vérifier conditions ; courir, endommager et consommer ; valider résultat.

**Résultat acceptable :** Dégâts/énergie de la session réaliste persistent ; récompense unique confirmée serveur.

**Cas dégradé / contrôle négatif :** Tentative vente/démontage pendant course refusée.

## SCN-11 — Course protégée officielle

**Chapitres :** 3; 6; 8. **Décisions :** AUD-RECON-01, AUD-RACE-01.

**Précondition :** Véhicule possédant déjà des dommages.

**Parcours prévu :** Entrer en course protégée ; subir dégâts ; sortir.

**Résultat acceptable :** État initial exact conservé/restauré ; aucun dégât antérieur supprimé ; crédits officiels selon barème valide.

**Cas dégradé / contrôle négatif :** Reconnexion et sortie interrompues ne réparent pas le véhicule.

## SCN-12 — Déconnexion pendant course

**Chapitres :** 6; 8. **Décisions :** AUD-RECON-01, AUD-LOCK-01.

**Précondition :** Transfert ou course en cours.

**Parcours prévu :** Couper connexion ; reconnecter durant fenêtre possible ; sinon terminer selon règlement.

**Résultat acceptable :** Reprise proposée si admissible, cible ~90 secondes conditionnelle ; verrou résolu et résultat unique.

**Cas dégradé / contrôle négatif :** Double connexion n’attribue pas deux récompenses.

## SCN-13 — Course classée et météo

**Chapitres :** 2; 6. **Décisions :** AUD-WEATHER-01.

**Précondition :** Météo mondiale changeante.

**Parcours prévu :** Lancer record et compétition classée pendant pluie puis changement météo.

**Résultat acceptable :** Conditions normalisées et comparables pour le classement ; météo dynamique dans le monde environnant et les activités libres.

**Cas dégradé / contrôle négatif :** Le climat du monde ne fausse pas le record officiel.

## SCN-14 — Course arrangée et farming

**Chapitres :** 5; 6; 8. **Décisions :** AUD-RACE-01, AUD-MOD-01.

**Précondition :** Deux comptes répètent anormalement des épreuves.

**Parcours prévu :** Observer résultats et schémas ; appliquer contrôles serveur et règles d’abandon.

**Résultat acceptable :** Fraude avérée détectable, gains frauduleux bloqués selon preuve ; joueurs honnêtes répétant un circuit non pénalisés automatiquement.

**Cas dégradé / contrôle négatif :** Latence ou simple répétition ne suffisent pas à sanctionner.

## SCN-15 — Collision multijoueur ambiguë

**Chapitres :** 2; 3; 8. **Décisions :** AUD-PHYS-01, AUD-COLL-01.

**Précondition :** Deux joueurs avec latences différentes.

**Parcours prévu :** Croisement rapide, contact apparent divergent, puis sauvegarde dommages.

**Résultat acceptable :** Dégât persistant attribué seulement après validation contextuelle ; traitement prudent, pas d’immunité exploitable.

**Cas dégradé / contrôle négatif :** Une connexion mauvaise ne suffit pas à accuser un joueur.

## SCN-16 — Trafic et chargement rapide

**Chapitres :** 2; 3; 9. **Décisions :** AUD-WORLD-02, AUD-PERF-01.

**Précondition :** Conduite rapide vers métropole et docks.

**Parcours prévu :** Traverser plusieurs zones avec PNJ et météo ; observer routes/collisions essentielles.

**Résultat acceptable :** Routes/intersections disponibles avant l’arrivée ; PNJ collisionnables proches cohérents ; détails éloignés optimisables.

**Cas dégradé / contrôle négatif :** Aucun obstacle critique invisible créé par le chargement.

## SCN-17 — Recharge électrique et panne sèche

**Chapitres :** 2; 3; 5. **Décisions :** AUD-WORLD-01, AUD-ECO-01, AUD-TX-01.

**Précondition :** VE faible énergie, solde potentiellement nul.

**Parcours prévu :** Planifier trajet, utiliser borne publique, facturation partielle, puis simuler batterie vide.

**Résultat acceptable :** Une borne au moins par zone, trajet réalisable selon autonomie, paiement proportionnel ; en panne, remorquage et mission rémunérée garantie.

**Cas dégradé / contrôle négatif :** Interruption de recharge ne produit pas énergie gratuite ni double débit.

## SCN-18 — Menu complet pendant mouvement

**Chapitres :** 3; 7. **Décisions :** AUD-UI-01, AUD-UI-02.

**Précondition :** Transaction non confirmée sur smartphone.

**Parcours prévu :** Ouvrir marché à l’arrêt, commencer à avancer, revenir à l’arrêt.

**Résultat acceptable :** Fonctions sensibles bloquées en mouvement, commandes rapides disponibles, aucune commande de frein, brouillon éventuel préservé.

**Cas dégradé / contrôle négatif :** Opération déjà envoyée suivie au serveur et non répétée.

## SCN-19 — Radio en véhicule social

**Chapitres :** 7; 9. **Décisions :** AUD-RADIO-01.

**Précondition :** Conducteur et deux passagers.

**Parcours prévu :** Changer station, couper écoute chez passager, quitter véhicule.

**Résultat acceptable :** Station commune pilotée par conducteur ; volume/coupure individuels ; pas de diffusion externe par défaut.

**Cas dégradé / contrôle négatif :** Aucune obligation d’écoute pour passager ayant coupé.

## SCN-20 — Photo, vie privée et classement

**Chapitres :** 7; 9. **Décisions :** AUD-PHOTO-01, AUD-PRIV-01.

**Précondition :** Véhicule à l’arrêt, propriété privée, course officielle.

**Parcours prévu :** Photo à pied ; essayer filmer à travers lieu interdit ; ouvrir mode caméra en ranked.

**Résultat acceptable :** Caméra encadrée, propriété protégée, pas de caméra libre en épreuve officielle ; partage volontaire.

**Cas dégradé / contrôle négatif :** Galerie privée seulement si faisable, pas d’accès détourné à informations privées.

## SCN-21 — Bascule clavier/manette et FR/EN

**Chapitres :** 7; 10; 11. **Décisions :** AUD-INPUT-01, AUD-L10N-01, AUD-ACCESS-01.

**Précondition :** PC puis console, interfaces transactions.

**Parcours prévu :** Basculer périphérique au milieu d’un menu ; changer langue ; ouvrir alerte.

**Résultat acceptable :** Focus récupéré, aucune action involontaire, textes essentiels complets dans les deux langues, alertes multimodales et historique.

**Cas dégradé / contrôle négatif :** Aucune confirmation économique due au changement de périphérique.

## SCN-22 — Sauvegarde indisponible

**Chapitres :** 5; 8; 11. **Décisions :** AUD-DATA-01, AUD-TX-01.

**Précondition :** Panne temporaire du service persistant.

**Parcours prévu :** Tenter vente/achat, continuer seulement activité sûre, restaurer service.

**Résultat acceptable :** Opérations non sécurisables suspendues, joueur informé, état incertain rapproché des résultats confirmés.

**Cas dégradé / contrôle négatif :** Ni faux succès ni double attribution à la reprise.

## SCN-23 — Reconnexion concurrente

**Chapitres :** 8. **Décisions :** AUD-LOCK-01, AUD-MIG-01.

**Précondition :** Profil actif puis nouvelle session rapide.

**Parcours prévu :** Se connecter sur second serveur pendant que premier tente d’écrire.

**Résultat acceptable :** Ancien détenteur ne remplace pas un état plus récent ; exclusivité rétablie.

**Cas dégradé / contrôle négatif :** Aucun verrou irrécupérable.

## SCN-24 — Restauration économique ciblée

**Chapitres :** 5; 8; 11. **Décisions :** AUD-REST-01, AUD-ECO-03.

**Précondition :** Achat confirmé puis corruption du profil.

**Parcours prévu :** Choisir sauvegarde antérieure ; réconcilier ventes et paiements ultérieurs.

**Résultat acceptable :** Restaurer uniquement les états justifiés, préserver transactions confirmées et propriété unique.

**Cas dégradé / contrôle négatif :** Ne pas ressusciter voiture déjà vendue ou crédit déjà dépensé.

## SCN-25 — Mise à jour incompatible

**Chapitres :** 8; 11. **Décisions :** AUD-MIG-01, AUD-ENV-01.

**Précondition :** Deux versions de schéma durant déploiement.

**Parcours prévu :** Mettre à jour environnement de validation, simuler écriture ancienne et rollback.

**Résultat acceptable :** Migration versionnée, ancienne version empêchée d’écraser champs nouveaux ; rollback contrôlé.

**Cas dégradé / contrôle négatif :** Zéro transfert d’actifs de test en production.

## SCN-26 — Incident majeur et modération

**Chapitres :** 8; 11. **Décisions :** AUD-INC-01, AUD-MOD-01, AUD-ECO-03.

**Précondition :** Exploitation potentielle et signalements.

**Parcours prévu :** Isoler fonctionnalité, enquêter, informer, corriger, rouvrir ; examiner signalement ambigu.

**Résultat acceptable :** Suspension proportionnée, restauration vérifiée ; sanctions sur preuves, réexamen possible.

**Cas dégradé / contrôle négatif :** Pas d’exposition de données privées dans communication publique.

## SCN-27 — Groupe, propriété et confidentialité

**Chapitres :** 4; 7; 9. **Décisions :** AUD-SOC-01, AUD-PRIV-01, AUD-PERM-01.

**Précondition :** Groupe de huit joueurs, accès propriété, partage opt-in.

**Parcours prévu :** Consentir localisation ; rejoindre propriété invitée ; quitter groupe ; prendre photo depuis l’extérieur.

**Résultat acceptable :** Partage arrêté au départ, propriété et prêt indépendants, finances privées ; caméra incapable de traverser permissions.

**Cas dégradé / contrôle négatif :** Aucun droit résiduel après révocation.

## SCN-28 — Performance 24 joueurs et 60 FPS

**Chapitres :** 2; 3; 8; 9; 11. **Décisions :** AUD-PERF-01, AUD-PERF-02.

**Précondition :** Configuration PC/console de référence à définir.

**Parcours prévu :** Mettre 24 joueurs avec trafic, pluie, collisions, courses et changements de zones.

**Résultat acceptable :** Mesurer médiane ≤16,67ms, P95≤20ms, P99≤33,3ms et viser ~60 FPS sans altérer la physique ni retirer le trafic.

**Cas dégradé / contrôle négatif :** Tout écart entraîne étude/NO-GO ou arbitrage explicite, jamais réduction silencieuse.

## SCN-29 — Accès à la publication

**Chapitres :** 11. **Décisions :** AUD-PUB-01, AUD-ENV-01.

**Précondition :** Version complète prête et compte créateur éligible.

**Parcours prévu :** Vérifier qualité, règles Roblox, classification, public autorisé, phases de lancement.

**Résultat acceptable :** Ouverture seulement aux comptes autorisés, puis élargissement lorsque permis ; contrôle GO/NO-GO satisfait.

**Cas dégradé / contrôle négatif :** Aucune annonce mensongère d’accès universel ; toutes fonctionnalités promises présentes à ouverture définitive.

## SCN-30 — Saison classée 8 semaines

**Chapitres :** 6; 11. **Décisions :** AUD-RACE-01, AUD-WEATHER-01, AUD-ENV-01.

**Précondition :** Compétitions et classements opérationnels.

**Parcours prévu :** Ouvrir saison, jouer sprint/circuit et drift approprié, terminer saison, traiter récompenses.

**Résultat acceptable :** Rangs distincts réputation, résultats intègres, cycle huit semaines, support/patchs possibles à tout moment.

**Cas dégradé / contrôle négatif :** Aucun transfert de scores ou actifs de test à production.

# 14. Revue E.3 — Registre des risques et réserves de faisabilité

**Échelle documentaire.** Criticité **C1** = intégrité fondamentale, sécurité ou blocage de publication ; **C2** = fonctionnalité ou performance importante ; **C3** = qualité, production ou présentation. Il s'agit de priorités de préparation, pas de mesures probabilistes validées. Les réserves « étude » ne réduisent aucun engagement ferme.

| ID | Risque et effet possible | Criticité | Mesures de maîtrise / preuve future |
|---|---|---|---|
| **RSK-01** | Écriture concurrente de profil : perte/duplication d’actif | C1 | AUD-LOCK-01 ; preuve sur reconnexion concurrente SCN-23 |
| **RSK-02** | Transaction multi-profils partielle : crédit ou véhicule perdu | C1 | AUD-TX-01 ; réservations, journal durable, reprise/compensation SCN-05/22 |
| **RSK-03** | Restauration aveugle : annulation d’achats ou doublons | C1 | AUD-REST-01 ; rapprochement des transactions SCN-24 |
| **RSK-04** | Fraude économique propagée entre joueurs | C1 | AUD-ECO-03 ; gel ciblé, investigation, innocents protégés SCN-26 |
| **RSK-05** | Sauvegardes indisponibles lors de récompenses | C1 | AUD-DATA-01 ; suspendre les écritures non sécurisées SCN-22 |
| **RSK-06** | Migrations incompatibles et perte de données | C1 | AUD-MIG-01 ; versionnement et retour arrière non destructif SCN-25 |
| **RSK-07** | Triche physique et faux positifs liés au réseau | C1 | AUD-PHYS-01 / COLL-01 ; validation contextuelle SCN-15 |
| **RSK-08** | Course protégée réparant un véhicule endommagé | C1 | Snapshot/reprise des états confirmés SCN-11 |
| **RSK-09** | Reconnexion de compétition, double récompense | C1 | AUD-RECON-01 ; idempotence, réservations SCN-12 |
| **RSK-10** | Chargement routier insuffisant à grande vitesse | C1 | AUD-WORLD-02 ; priorité collisions et routes SCN-16 |
| **RSK-11** | 24 joueurs et performances incompatibles avec rendu premium | C2 | AUD-PERF-01/02 ; budgets et scénarios PC/console SCN-28 |
| **RSK-12** | Trafic PNJ collisionnable trop coûteux | C2 | Simulation distante optimisée sans suppression PNJ SCN-16/28 |
| **RSK-13** | Météo officielle créant classement incomparable | C2 | AUD-WEATHER-01 ; normalisation SCN-13 |
| **RSK-14** | Rentabilité protégée déséquilibrant les missions | C2 | AUD-RACE-01 ; rentabilité nette et anti-farming SCN-14 |
| **RSK-15** | Revente de pièces et vente voiture dupliquant actifs | C1 | AUD-ECO-02 ; transfert indivisible et inventaire SCN-05/06 |
| **RSK-16** | Réseau recharge VE insuffisant en zone éloignée | C2 | AUD-WORLD-01 ; couverture autonomie et itinéraire SCN-17 |
| **RSK-17** | Permission révoquée cause disparition ou maintien de droit | C1 | AUD-SOC-01 / PERM-01 ; transition sûre SCN-08/27 |
| **RSK-18** | Caméra photo révèle lieu privé ou compétiteur | C2 | AUD-PHOTO-01 / PRIV-01 ; caméra bornée SCN-20 |
| **RSK-19** | Traduction ambiguë d’une transaction | C2 | AUD-L10N-01 ; revue FR/EN SCN-21 |
| **RSK-20** | Musique non licenciée ou audio non conforme | C1 | Catalogue original/licencié ; contrôle des droits chapitre 9 |
| **RSK-21** | Changement politique Roblox et inadmissibilité publication | C1 | AUD-PUB-01 ; contrôle officiel avant ouverture SCN-29 |
| **RSK-22** | Test ou Studio modifie la production | C1 | AUD-ENV-01 ; isolation des environnements SCN-25 |
| **RSK-23** | Galerie photo personnelle indisponible | C3 | Fonction conditionnelle ; valider faisabilité sans retirer le mode photo |
| **RSK-24** | Volants ou contrôleurs additionnels non pris en charge | C3 | Support conditionnel ; validation de compatibilité |
| **RSK-25** | Charge de contenu 18 voitures / 7 zones | C2 | Lotissement intégré futur, LOD, sans retrait du contenu |
| **RSK-26** | Support/incident insuffisant à l’ouverture | C1 | AUD-INC-01 / MOD-01 ; organisation et GO/NO-GO chapitre 11 |

## 14.1. Conditions d'étude de faisabilité

Les études devront distinguer les éléments **fermes (F)**, **conditionnels déjà approuvés (C)**, **objectifs mesurables (O)** et **paramètres restant à fixer (P)**. Les objectifs de 24 joueurs, environ 60 FPS, temps d'image médian/P95/P99 et reconnexion autour de 90 secondes nécessitent des vérifications techniques futures. Les paramètres de barème économique, les quantités exactes de bornes au-delà du minimum par zone, les configurations matérielles de référence et les seuils d'exploitation ne sont pas des autorisations de réduire une fonctionnalité ferme.

## 14.2. Critères de préparation de la preuve

- Définir des configurations PC et console de référence, niveaux de qualité graphique, scénarios représentatifs et durée d'observation.
- Mesurer FPS, percentiles d'image, latence et temps de simulation dans des conditions proches des 24 joueurs cibles.
- Vérifier sauvegardes, transactions multi-profils, reconnexions et migrations avec des environnements isolés.
- Vérifier les prix, gains nets, dégâts persistants et abus potentiels sans exiger de gains garantis.
- Recontrôler les obligations de publication, classification, audience et droits d'auteur à la date réelle d'ouverture.

---

# 15. Revue E.4 — Matrice de traçabilité et critères de validation

## 15.1. Matrice des chapitres

| Chapitre | Domaine prioritaire | AUD transversaux | Scénarios clés |
|---|---|---|---|
| **CH01** | Vision, identité, conduite exigeante et équité | AUD-PHYS-01; AUD-PERF-01; AUD-RACE-01 | SCN-10, 15, 28 |
| **CH02** | Carte, sept zones, services, météo et PNJ | AUD-WORLD-01/02; AUD-WEATHER-01; AUD-PERF-02 | SCN-13, 16, 17, 28 |
| **CH03** | 18 modèles, motorisations, aides, dommages, énergie | AUD-ECO-01/02; AUD-PHYS-01; AUD-COLL-01 | SCN-01, 04, 10, 11, 15 |
| **CH04** | Propriétés, garages, capacité, configuration et prêts | AUD-ECO-02; AUD-SOC-01; AUD-PERM-01 | SCN-04, 07, 08, 27 |
| **CH05** | Huit missions, monnaie, prix, marché et P2W | AUD-ECO-01/02/03; AUD-RACE-01; AUD-TX-01 | SCN-02, 03, 05, 06, 14 |
| **CH06** | Six disciplines, modes, ranked et saison | AUD-RACE-01/02; AUD-RECON-01; AUD-WEATHER-01 | SCN-10 à 14, 30 |
| **CH07** | Smartphone, social, HUD, GPS et accessibilité | AUD-UI-01/02; AUD-INPUT-01; AUD-ACCESS-01; AUD-PRIV-01 | SCN-18, 21, 27 |
| **CH08** | Architecture, persistance, serveur et anti-triche | AUD-DATA-01; AUD-LOCK-01; AUD-TX-01; AUD-MIG-01; AUD-REST-01 | SCN-15, 22 à 26 |
| **CH09** | Rendu, audio, radio et photo | AUD-RADIO-01; AUD-PHOTO-01; AUD-PERF-01 | SCN-19, 20, 28 |
| **CH10** | Première connexion, starters, tutoriels | AUD-ONB-01; AUD-ECO-01; AUD-L10N-01 | SCN-01, 02, 09 |
| **CH11** | Publication, langues, performance, support | AUD-PUB-01; AUD-ENV-01; AUD-INC-01; AUD-MOD-01 | SCN-21, 25, 26, 29, 30 |

## 15.2. Niveaux de contrôle d'acceptation

- **Contrôle documentaire (maintenant) :** règle définie, responsabilité et dépendance identifiées, cas nominal et dégradé rédigés ; ne démontre pas le jeu.
- **Contrôle de prototype et architecture (après autorisation globale) :** montrer la faisabilité sans modifier les obligations de lancement.
- **Validation intégrée (après réalisation) :** scénario exécuté sur le jeu complet avec traces et résultats reproductibles.
- **Validation de publication :** GO/NO-GO de la version complète selon le chapitre 11, les règles Roblox à jour et les cibles explicitement acceptées.

## 15.3. Référentiels d'acceptation existants

Les référentiels RACE-01 à RACE-20, UI-01 à UI-20, TECH-01 à TECH-20, ART-01 à ART-20, ONB-01 à ONB-20 et LAUNCH-01 à LAUNCH-20, ainsi que les critères déjà définis dans les autres chapitres, demeurent intacts. **Le présent dossier ne reconstitue pas artificiellement leurs libellés individuels non disponibles parmi les sources consultables.** L'annexion des versions intégrales originales est une opération de traçabilité documentaire requise pour une fusion littérale exhaustive. Les scénarios SCN-01 à SCN-30 sont une couche complémentaire, non un renommage des critères originaux.

## 15.4. Exigences de conformité transversales

- Zéro duplication confirmée d'exemplaire ou de transaction dans les scénarios de réception.
- Aucun transfert involontaire de droit premium personnel.
- Aucune réparation gratuite des dommages antérieurs via mode protégé.
- Aucune suppression des sept zones, dix-huit véhicules, six disciplines ou infrastructures validées.
- Aucune modification des règles physiques officielles pour obtenir plus de FPS.
- Aucun transfert d'actifs tests vers l'environnement public.
- Aucun affichage de réussite d'opération sensible avant confirmation serveur.
- Aucun lancement avec P0 ou P1 connu non résolu ; traitement explicite des P2/P3.

---

# 16. Revue E.4 — Contradictions, dépendances et clôture

## 16.1. Vérification de cohérence documentaire

La revue croisée des engagements **accessibles dans cette consolidation** ne fait apparaître aucune contradiction fonctionnelle majeure non résolue. Les cas potentiellement ambigus ont une règle : starter incessible vs modèle commercial, collection vs places d'exposition, mode protégé vs dégâts préexistants, course vs réservation exclusive, permissions révocables vs transaction déjà confirmée, phase d'accès Roblox vs périmètre final complet. Ce constat n'est pas une certification exhaustive mot à mot des onze chapitres intégraux absents des fichiers sources de cette session.

## 16.2. Chaînes de dépendances critiques

1. **Économie :** identité du profil → inventaire → droit de propriété → réservation → transaction → sauvegarde → restauration.
2. **Automobile et courses :** modèle → physique → météo/adhérence → collisions/dégâts → état réel/protégé → résultat confirmé → récompense.
3. **Monde et performance :** carte → streaming routier → PNJ proches → météo → 24 joueurs → qualité d'image.
4. **Accueil :** première connexion → choix starter → attribution unique → propriété gratuite → tutoriels facultatifs → mission viable.
5. **Exploitation :** versions isolées → validation → GO/NO-GO → audience autorisée → surveillance → incidents → correction → mise à jour sûre.

## 16.3. Paramètres restant à déterminer sans arbitrage du périmètre

- Nom définitif du jeu et terminologie de la monnaie, si non fixés officiellement.
- Détail de chacun des dix-huit modèles originaux (dimensions, performances, prix, motorisation, équipement), à conserver conforme au chapitre 3 intégral.
- Plan exact de la carte, longueur des trajets, nombre et coordonnées des bornes au-delà du minimum des sept zones.
- Prix détaillés des activités, véhicules, composants, propriétés et modules ; revenus nets de référence.
- Configurations PC et console de référence, budgets mémoire/réseau, durée des mesures et conditions d'essais.
- Délais d'expiration et séquences de récupération de transactions, profils et sessions, sans modifier leurs garanties.
- Paramètres de modération, rétention et accès aux journaux, conformes aux règles applicables.
- Noms des stations radio et catalogue des contenus dûment autorisés.
- Critères exacts de tous les référentiels historiques, à annexer depuis les originaux complets.
- Conditions réelles de publication et de classification Roblox au moment du lancement.

## 16.4. Ordre de préparation futur, sans développement autorisé

Lorsque l'accord global sera obtenu, les études d'architecture et de faisabilité pourront préparer les lots intégrés. Leur ordre recommandé : socle multijoueur / conduite / identités persistantes, économie et transferts, carte et trafic, garages/propriétés, missions/courses, interface, immersion, sécurité et validation finale. Tous les éléments du périmètre approuvé doivent être présents avant la sortie publique définitive ; les délais et équipes ne sont pas estimés sans ressources réelles.

---

# 17. Procédure d'approbation et statut final

## 17.1. Clôture de la rédaction documentaire

La rédaction du dossier de consolidation, des scénarios E.2 et du registre de risques E.3 est **achevée dans le périmètre des informations disponibles**. La matrice E.4 fournit une traçabilité par chapitre et par décision AUD. L'annexion intégrale des critères historiques demeure à réaliser depuis leurs textes sources si l'on souhaite une fusion certifiée mot à mot ; ne pas interpréter cette limitation comme une autorisation de renommer ou de modifier les critères d'origine.

## 17.2. Distinctions de statut

- **Chapitres individuels 1–11 :** officiellement validés v1.0.
- **Arbitrages AUD-01 à AUD-33 (références nominatives du présent dossier) :** officiellement validés individuellement.
- **Dossier consolidé candidat :** rédigé et prêt à être examiné.
- **Validation du cahier des charges GLOBAL :** **NON ACCORDÉE À CE JOUR**.
- **Développement et essais techniques :** **NON AUTORISÉS**.
- **Publication :** **NON AUTORISÉE**.

## 17.3. Formule de décision réservée au propriétaire

Après lecture, toute approbation devra être formulée explicitement et séparément, par exemple : « Je valide officiellement le cahier des charges global consolidé du jeu automobile Roblox, version 1.0, avec son périmètre, ses 11 chapitres et ses 33 arbitrages AUD. » Cette phrase est un **exemple de formule**, pas une validation présente ou implicite ; toute autorisation de développer devra aussi être explicitement définie.

## 17.4. Statut de fin de revue

**Revue E documentaire : terminée pour le contenu reconstituable et les scénarios.**  
**Références historiques à annexer : libellés intégraux des critères originaux si exigés pour une exhaustivité littérale.**  
**Décision globale : en attente de validation expresse du propriétaire.**

---

# 18. Sources externes documentaires (à revérifier au lancement)

- Roblox Creator Hub, **Data stores** : https://create.roblox.com/docs/cloud-services/data-stores
- Roblox Creator Hub, **Data store versioning, listing, and caching** : https://create.roblox.com/docs/cloud-services/data-stores/versioning-listing-and-caching
- Roblox Creator Hub, **Best practices for data stores** : https://create.roblox.com/docs/cloud-services/data-stores/best-practices
- Roblox Creator Hub, **Roblox Kids and Select** : https://create.roblox.com/docs/production/publishing/kids-and-select
- Roblox Support, **How to Publish Games on Roblox** : https://en.help.roblox.com/hc/en-us/articles/203313890-How-to-Publish-Games-on-Roblox

Les règles de publication, classification, sécurité et données peuvent évoluer ; l'état réel à la date de publication future fait autorité.

**FIN — CAHIER DES CHARGES GLOBAL CONSOLIDÉ, VERSION CANDIDATE 1.0.**
