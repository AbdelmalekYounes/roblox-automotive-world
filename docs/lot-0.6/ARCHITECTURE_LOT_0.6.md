# Lot 0.6 — architecture des courses, du matchmaking, de la compétition et des saisons

## 1. Vue d'ensemble

```
client/UI/RacePanel ── RemoteFunction AWRacing.Request (catalogue, rejoindre, prêt, abandon, file…)
        ▲                         │
        │ Push (instantané,       ▼
        │ événements, résultats)  server/Racing/RaceService  (lieu physique, véhicule conduit, horloge serveur)
        │                         │
        │      ┌──────────────────┼───────────────────────────┬──────────────────────────┐
        │  RaceLobby / RaceSession   RaceRules / DriftScoring    RaceValidator / RaceScoring   MatchmakingService
        │  (salons, cycle de vie)    (départs, points, tours)    (confirmation, classement)    (file, groupes)
        │                         │
        │   VehicleRaceReservation · RaceRewards · RankedService · SeasonService · RaceRecovery  (mutations pures d'un profil)
        │                         │
        │        ProfileAccess.apply / ProfileSession.commit (transaction unique par participant)
        │                         │
        └──── RacePersistence (Race_<id>, tableaux mémoire) ── CrossServerAdapter (MemoryStore, téléportation,
                                                                OrderedDataStore : Test/Prod seulement, NON TESTÉ)
```

Données partagées (`src/shared/Racing`) : `RaceDefinitions` (disciplines, types, modes, calendrier, barème),
`RaceCourses` (parcours versionnés), `Seasons` (rangs et saisons), `RaceProtocol` (canal).

Un SEUL socle : les six disciplines partagent le cycle de vie, l'échantillonnage, la validation, le
classement, les réservations, les récompenses et la récupération. Seules leurs règles propres
(`RaceDefinitions.Disciplines`) diffèrent : type de départ, classement au temps ou au score, échelle
classée, pénalités, couloir, tarif. Aucun contrôleur physique nouveau : la conduite reste celle du lot 0.2.

## 2. Parcours (`RaceCourses`, `RaceCourse`)

- Données versionnées : identifiant stable, version, discipline, zone, lieu, routes de la carte (identifiants de
  `MapData`, sens) ou points de la zone d'essai, boucle et tours, décalages de départ et d'arrivée, distance de
  drag, longueur déclarée, revêtements, difficulté, vitesse de référence, score de référence (drift), participants
  minimum et maximum, types autorisés, conditions standardisées.
- `RaceCourse.build` met bout à bout les tracés lissés de `WorldLayout.OriginPolyline` (les mêmes que le
  générateur de carte), place départ et arrivée, points de contrôle régulièrement espacés (le dernier est l'arrivée
  ou la ligne du tour), grille, couloirs de drag, box de départ, point d'inscription hors chaussée. Revêtements
  et circulation sont déduits des classes de routes.
- `RaceCourse.validate` contrôle routes connues et ENCHAÎNÉES par le même carrefour du graphe, boucle fermée,
  longueur déclarée (± 5 %), zone et revêtements déclarés, règles de discipline (circuit fermé, drag à
  deux couloirs, zone de drift), bornes de la zone d'essai. Un parcours invalide n'est jamais proposé.
- 16 parcours dans le monde ouvert (complexe motorsport, métropole, périphérique, cols, campagne, littoral) et
  6 dans la place de développement (une épreuve par discipline). Outil : `tools/racing/courses.luau`.
- Records : seulement sur les parcours SANS circulation (pistes du complexe, zone de drift) ; clé de record =
  parcours + version + conditions.

## 3. Cycle d'une épreuve (`RaceLobby`, `RaceSession`)

```
Open ──minimum atteint et tous prêts, ou délai (45 s)──▶ Countdown ──StartT (serveur)──▶ Running ──▶ Finished
  └──délai d'inscription (5 min) sans minimum──▶ Cancelled (engagements libérés)
```

- Salons publics (officielle) créés au point d'inscription ; classée : par la file (places réservées aux joueurs
  du match) ; privée et entraînement : créés par un organisateur (tours, participants, modes), jamais listés.
- Un joueur n'appartient qu'à une épreuve ; une voiture n'est engagée qu'une fois ; inscriptions fermées au
  verrouillage ; mode autorisé contrôlé ; entraînement toujours protégé.
- Verrouillage : places (grille dans l'ordre d'inscription, au classement pour une classée), instants officiels :
  grille `+25 s` (rejoindre sa place) `+5 s` (compte à rebours) ; drag `+30 s` (pré-départ), feux orange à
  −1,5 / −1 / −0,5 s ; départs individuels espacés de 20 s ; drift `+10 s`.
- Fin : tous terminés, ou 60 s après le premier arrivé (grille), ou délai maximal (3 × temps de référence, borné
  à 20 min).

## 4. Règles, chronométrage et validation (`RaceRules`, `DriftScoring`, `RaceValidator`, `RaceScoring`)

- Échantillons SERVEUR à 10 Hz : position, vitesse, cap de la caisse (partie principale du véhicule conduit),
  usure confirmée (`VehicleService.vehicleState`), corrections de mouvement ; horloge
  `Workspace:GetServerTimeNow()`. Aucune valeur client.
- Points de contrôle : franchissement de la LIGNE (perpendiculaire au tracé, demi-largeur = rayon) entre deux
  échantillons, dans le sens de marche ; instant interpolé. Un point manqué n'est pas validé (retour
  obligatoire) ; au rallye, pénalité de 30 s par point manqué et progression continue.
- Faux départ : participant « placé » (immobile à moins de 4 m de sa place) qui s'en écarte de plus de 2,5 m
  avant `StartT` : +5 s (grille), +10 s (rallye), manche perdue (drag, feu rouge). Retardataire : aucune
  pénalité, temps compté depuis `StartT`.
- Hors tracé : couloir par discipline ; pénalité au-delà de la tolérance, plafonnée par excursion ; compté
  seulement une fois le parcours rejoint. Drag : sortie de couloir de plus de 1,5 s = manche invalidée.
- Drag : temps de réaction (feu vert → ligne), temps écoulé, vitesse à l'arrivée ; boîtes manuelles et
  automatiques inchangées, aucune assistance imposée.
- Drift : angle de dérive (caisse / vitesse), vitesse ≥ 30 km/h, distance en dérive, continuité (reprise en
  moins de 1,2 s), enchaînement (changement de sens : multiplicateur jusqu'à × 4), maîtrise (oscillation
  brutale de l'angle : moitié des points), zone. Une figure n'est acquise qu'à sa fin propre ; choc notable,
  sortie de zone, tête-à-queue ou correction de mouvement la font perdre.
- Validation : arrivée CONFIRMÉE seulement si les données suffisent (échantillons, intervalle maximal 2 s,
  aucune correction, pas de position figée — QA-A01 —, vitesse moyenne plausible entre deux points). Sinon
  « Unconfirmed » : ni place, ni récompense, ni sanction.
- Classement : arrivées confirmées au temps officiel (temps + pénalités) ou au score ; puis non confirmées ;
  puis non-arrivés selon leur distance validée.

## 5. Réservation et modes (`VehicleRaceReservation`, `RaceRecovery`)

- Engagement (`RaceJoin:<engagement>`) : exemplaire possédé, sorti et libre → `Reservation = { Kind = "Race",
  TxId = <engagement>, ExpiresAt }` et `Racing.Active` (course, mode, véhicule, état initial en mode protégé).
  Durée : inscription + épreuve maximale + reconnexion + 2 min.
- Refusés pendant l'engagement : vente, reprise, annonce, transfert, pièces, réglages, configurations,
  rangement, seconde sortie (contrôles existants des lots 0.4–0.5) ; réparation, lavage et énergie (nouveau
  refus `VehicleInRace`) ; conduite par un autre joueur (droit restreint au propriétaire).
- Mode protégé : session protégée (aucune réconciliation durable), puis restauration EXACTE de l'état initial
  (énergie, dégâts — y compris antérieurs —, kilométrage, salissure) dans le profil et sur le véhicule
  matérialisé. Mode réaliste : état mesuré conservé (réparations et énergie payantes ensuite).
- Profil v3 (`ProfileMigration` 2 → 3) : `Racing = { Active, Results (40), Applied (90 jours), Ranked, Records,
  Recent, Stats }` ; validation : un engagement correspond toujours à la réservation de l'exemplaire et
  réciproquement.

## 6. Récompenses, classement, saisons (`RaceRewards`, `RankedService`, `SeasonService`)

- Crédits = tarif × minutes de RÉFÉRENCE × difficulté × performance × concurrence × type × répétition, +
  complément réaliste = coûts estimés (énergie 3 cr/km + usure probable par km). Officielle et classée × 1,
  privée × 0,2 (seulement aux paramètres officiels et à au moins deux participants, 3 par heure), entraînement
  × 0. Répétitions d'un même parcours dans l'heure dégressives jusqu'à 50 % ; 20 épreuves payées par heure.
- Une transaction par participant, `Race:<course>:<joueur>`, avec garde durable `Racing.Applied` : crédits,
  points classés, record personnel, historique, statistiques et libération de la réservation, tout ou rien.
- Classé : échelle « Race » (sprint, circuit : Elo multijoueur, K = 32) et « Drift » (performance face au score
  de référence). Non classés : non confirmés, déconnectés, non-partants. Anti-arrangement : gains répétés face
  aux mêmes adversaires réduits dans les 24 h (× 1 / 0,5 / 0,25), jamais de sanction automatique.
- Saisons de 8 semaines (origine : 2 novembre 2026 UTC), rangs Bronze → Diamant sur des points distincts de la
  réputation ; transition : archive, récompense unique selon le rang final (≥ 10 épreuves classées),
  réinitialisation de moitié vers 1 000 ; tableaux indexés par saison.

## 7. Conditions normalisées (AUD-WEATHER-01)

- Classée : toujours ; officielle : sur les parcours à records ; privée et entraînement : jamais.
- Normalisée : attribut `AWRaceWetness = 0` sur le SEUL véhicule engagé, lu par `VehicleSimulator` à la place
  de l'humidité de la météo (une seule source, jamais cumulée) ; les surfaces propres au parcours restent
  (zone mouillée versionnée). La météo du monde continue normalement. Résultat marqué `Sec-v1` ou
  `Dynamique` ; un record n'existe qu'en conditions normalisées.

## 8. Matchmaking et inter-serveurs (`MatchmakingService`, `CrossServerAdapter`)

- File de tickets (discipline, type, mode, niveau ; région si fournie) ; fenêtre de niveau élargie avec
  l'attente ; groupe de 2 à 8 ; confirmation en 20 s ; tickets abandonnés retirés après 5 min ; double ticket
  refusé. Repli LOCAL : l'épreuve classée est créée sur ce serveur, places réservées aux joueurs du match, qui
  rejoignent physiquement le point d'inscription.
- `CrossServerAdapter` (seul module autorisé à utiliser MemoryStore, TeleportService et OrderedDataStore, garde-fous
  Lune et pytest élargis à ce seul fichier) : file partagée, serveur réservé et téléportation explicite des
  participants confirmés, tableaux durables. Instancié seulement si l'environnement est Test ou Prod
  (`EnvironmentConfig`, vide) : JAMAIS exécuté — NON TESTÉ, aucun fonctionnement affirmé.

## 9. Reconnexion et récupération (AUD-RECON-01)

- Départ du joueur : avant le verrouillage, désinscription et libération ; ensuite, fenêtre de 90 s. Le véhicule
  rentre au garage (lot 0.4) mais reste réservé ; l'état de course est conservé côté serveur (capturé chaque
  seconde).
- Retour dans la fenêtre sur le même serveur : reprise proposée ; le véhicule est rematérialisé au dernier point
  validé (`ProgressionService.raceResume`, réservation de CET engagement exigée), avec l'état de course (mode
  protégé) ; le chronomètre n'a pas été arrêté. Contre-la-montre et drag : pas de reprise d'une manche commencée.
- Fenêtre dépassée : issue « Disconnected » (aucun gain, aucune variation classée).
- Résultats publiés (`Race_<id>`) avant toute application ; un profil absent ou verrouillé ailleurs est
  réconcilié par le serveur qui le détient (toutes les 30 s et à l'arrivée). Engagement échu sans résultat
  (serveur disparu) : « Interrupted » au chargement — libération, restauration exacte en mode protégé, aucun
  véhicule créé ni perdu.

## 10. Interface provisoire (`client/UI/RacePanel`)

Touche K (manette : clic du stick gauche). Onglets : épreuves (parcours par distance, détails, officielle, file
classée, salon privé, entraînement, épreuves ouvertes), mon épreuve (participants, prêt, désinscription,
abandon, confirmation de match, reprise), classements (rang, saison, historique, tableaux, records), résultats.
Affichage de course compact : compte à rebours, chronomètre (horloge serveur), position, tour, point, temps au
tour, meilleur tour, réaction, score de drift, faux départ et pénalités ; repères locaux des deux prochains
points et de la place. Ouvrir le panneau ne freine jamais la voiture.

## 11. Installations physiques (`RaceInstallations`)

Construites par code au démarrage : dalle et invite d'inscription, lignes et portiques de départ et d'arrivée,
places de grille, box de départ, arbre de départ du drag (feux pilotés par le serveur), bornes de la zone de
drift. Marquages non collisionnables et non détectés par les rayons ; poteaux des portiques au bord de la
chaussée.
