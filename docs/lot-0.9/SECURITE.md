# Audit de sécurité et anti-triche — lot 0.9

Principe (CLAUDE.md, AUD-PHYS-01, AUD-COLL-01) : le serveur ne fait jamais confiance à une valeur sensible du
client ; il valide en contexte, avec une tolérance réseau, et **corrige sans sanction automatique**. Aucune
sanction irréversible n'existe dans le code (ni exclusion, ni bannissement, ni retrait de biens) : une anomalie
réseau produit au plus une correction de position, un refus ou un journal.

Sources des preuves : tests Lune (`scripts\verify.ps1`, 329 tests au commit `38e3b3b`), sessions VM `lot04`,
`lot05`, `lot06`, `lot08` et historiques (`RAPPORT_VALIDATION_GLOBALE.md` §2). Ce qui n'est prouvé que par la
logique (Lune) est indiqué ; l'exploitation réelle par un tricheur humain n'a pas été tentée.

## 1. Surface réseau

15 canaux exposés aux clients, tous créés par le serveur :

| Canal | Type | Limiteur | Identifiant de demande | Remarques |
|---|---|---|---|---|
| `AutomotiveWorldRemotes` (`VehicleInput`, `VehicleAction`, `VehicleNotice`, `VehicleImpulse`) | Unreliable + 3 RemoteEvent | Oui (par joueur) | — | Commandes décodées et bornées (`InputCodec`), mouvements validés (`MovementRules`), actions revalidées |
| `AWProgression` (Request, Push) | RemoteFunction + RemoteEvent | 3/s | Oui (opérations sensibles) | Lieu, droits, état revalidés |
| `AWEconomy` (Request, Push) | RemoteFunction + RemoteEvent | 6 jetons, 2/s | Oui | Prix et montants lus du catalogue serveur, jamais du client |
| `AWRacing` (Request, Push) | RemoteFunction + RemoteEvent | 6 jetons, 2/s | Oui (sensibles) | Résultats calculés par le serveur (échantillonnage 10 Hz) |
| `AWInterface`, `AWSocial` | RemoteFunction + RemoteEvent | Oui | — | Vues filtrées par destinataire |
| `AWOnboarding` (Request, Push) | RemoteFunction + RemoteEvent | 6 jetons, 2/s | Transaction fixe `Grant:Starter` | Aucun crédit, aucun objet hors transaction unique |
| `AWRadio` | RemoteEvent | 4 jetons, 1/s | — | Conducteur assis seulement ; station disponible seulement |

Points d'accès de test (`AWTestHooks`, `AWTestSeatFallback`…) : créés uniquement dans Studio
(`RunService:IsStudio()`) ou par les scripts de test injectés ; absents d'une expérience publiée.

## 2. Contrôles demandés

| Menace | Contrôle | Preuve | Résultat |
|---|---|---|---|
| Usurpation de demandes | Action inconnue refusée ; identifiant de demande obligatoire et bien formé | VM `lot05` : `GiveCredits` → `ActionUnknown` ; sans identifiant / identifiant court → `RequestIdInvalid` | **Vérifié en jeu** |
| Manipulation des montants | Prix pris au catalogue serveur ; montants entiers bornés ; NaN et négatifs refusés | VM `lot05` : prix forgé 1 → débit 16 500 (catalogue) ; annonce à −5, 10¹², NaN → `PriceInvalid` ; Lune « montants : entiers positifs bornés » | **Vérifié en jeu** |
| Appels répétés (rejeu) | Transaction idempotente par identifiant | VM `lot05` : même identifiant rejoué → aucun second débit ni second véhicule ; Lune « répétition : un seul débit » | **Vérifié en jeu** |
| Transactions concurrentes | Verrou de l'annonce, une seule vente | VM `lot05` : deux achats simultanés de la même annonce (relance après correction du marché, voir §3) ; Lune « double achat concurrent » | Lune ; VM : voir rapport |
| Soldes insuffisants | Refus sans modification | VM `lot05` : modèle à 210 000 crédits → refus, solde inchangé | **Vérifié en jeu** |
| Débit abusif | Limiteur par joueur et par canal | VM `lot05` : 9 demandes sur 14 refusées (`RateLimited`) lors d'une rafale | **Vérifié en jeu** |
| Accès aux biens d'autrui | Propriété revalidée à chaque opération | VM `lot05` : mise en vente du véhicule d'un autre joueur → `VehicleNotOwned` ; VM `lot04` : conduite et entrée refusées sans droit, révocation | **Vérifié en jeu** |
| Données d'autres joueurs | Vues filtrées (groupes, carte, marché) | Lune « vue sociale filtrée », « points personnels limités au joueur » | Lune seulement |
| Fausse fin de mission | Aucune action client de fin ; fin observée par le serveur ; véhicule d'essai sans progression | VM `lot05` : `CompleteMission` → `ActionUnknown` ; abandon sans paiement ; Lune « gain de mission unique » | **Vérifié en jeu** |
| Fausse victoire | Résultats calculés par le serveur ; temps interpolé entre échantillons serveur | Lune « temps officiel interpolé, référence serveur », « non confirmés » | Lune ; VM `lot06` : voir rapport |
| Téléportation | Mouvement impossible corrigé, sans sanction | VM historiques : téléportation de 400 st corrigée (scénario de test) | **Vérifié en jeu** |
| Vitesses impossibles | Plafond par modèle (`MaxPlausibleSpeedKmh`), éjection physiquement impossible limitée | VM `lot08` : 8 éjections limitées journalisées pendant le banc, sans téléportation | **Vérifié en jeu** |
| Réutilisation d'identifiants | Identifiant de transaction lié à l'action ; rejoué → réponse d'origine | VM `lot04` / `lot05` ; Lune | **Vérifié en jeu** |
| Contournement des droits | Droits revalidés (propriété, invitation, conduite, place passager) | VM `lot04` ; Lune « place passager » | **Vérifié en jeu** (sauf passager : Lune) |
| Résultats classés | File d'attente obligatoire, échelle séparée, abandon compté | VM `lot06` : classée sans file → `RaceRankedNeedsQueue` ; Lune (échelles, abandon) | Partiel |
| Véhicule d'essai (arrivée) | Marqué, refusé en course et sans progression de mission | VM `lot08` : refusé (voir la note du §3) ; contrôle statique Lune | Partiel |

## 3. Défauts de sécurité ou d'intégrité trouvés pendant le lot

1. **Marché : réservation sans annonce** (`e097815`). Une mise en vente dont la réservation était appliquée
   mais pas encore écrite (« Pending », budget d'écriture) n'était jamais publiée : l'exemplaire restait
   réservé et invendable jusqu'à l'échéance. Aucun gain illégitime possible, mais blocage d'un bien. Corrigé,
   test Lune de régression (échoue sans la correction).
2. **Courses : inscription impossible** (`38e3b3b`). Le contrôle du siège exigeait un `VehicleSeat` ; toute
   inscription était refusée. Conséquence de sécurité : le refus du véhicule d'essai en course (`lot08`) passait
   pour une mauvaise raison ; la règle propre (`TestDriveNoRewards`) est revérifiée après correction.

## 4. Faux positifs : évaluation

- **Corrections de position** : avant le lot 0.9, les essais VM produisaient des corrections « Teleport » sur un
  conducteur honnête. Elles venaient d'un scénario de test (sortie ratée puis véhicule occupé déplacé par le
  serveur de test, voir QA-A01/A02) ; après correction du test, **aucune** correction intempestive sur quatre
  sessions de collision. En jeu, la correction reste sans sanction : un faux positif coûte au plus un recalage.
- **Réattributions de propriété réseau** : 0 à 2 par session de collision, toujours corrigées à la première
  vérification (« réattribution (1) »), sans effet mesuré. Journalisées, jamais sanctionnées.
- **Éjections limitées** : au contact brutal, la vitesse d'éjection est plafonnée (3 m/s) ; aucun joueur
  n'est déplacé de force ni sanctionné.
- **Limiteur de débit** : une rafale de plus de 6 demandes refuse les suivantes (`RateLimited`) ; un joueur
  normal (≈ 1 demande par action) n'est pas concerné. Les panneaux affichent le refus sans perte d'état.

## 5. Non vérifié

- Tentatives réelles de triche par un humain (exploits clients, injection de paquets) : **NON TESTÉ**.
- Arrangements entre comptes en classé (QA-R08), raccourcis réels en course (QA-R09) : **NON TESTÉ**.
- Inter-serveurs (marché, matchmaking) : code jamais exécuté (aucune expérience de test) : **NON TESTÉ**.
