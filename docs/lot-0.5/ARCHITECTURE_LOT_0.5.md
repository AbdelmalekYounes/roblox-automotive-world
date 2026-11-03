# Lot 0.5 — architecture de l'économie, des métiers et du marché

## 1. Vue d'ensemble

```
client/UI/EconomyPanel ── RemoteFunction AWEconomy.Request (devis, opérations + identifiant de demande)
        ▲                         │
        │ Push (instantané,       ▼
        │ fin de mission/énergie) server/Economy/EconomyService   (lieu physique, mouvement, montants serveur)
        │                         │              │                 │
        │       Commerce (pur, mono-profil)   Market (pur, multiprofil)   MissionService (missions en jeu)
        │                         │              │                 │
        │                   ProfileSession.commit   ProfileAccess    MissionGenerator / MissionEngine / RewardModel (purs)
        │                         │              │
        └──────────────── ProfileRepository (mémoire en Dev ; DataStore en Test/Prod déclarés — aucun aujourd'hui)
```

Modules purs testés par Lune (`tests/lune/specs/Lot05Economy.luau`) : `Wallet`, `Commerce`, `Market`,
`MissionEngine`, `MissionGenerator`, `MissionPlaces`, `RewardModel`, `ProfileAccess`, catalogues partagés.

## 2. Profil v2 (migration 1 → 2)

Ajouts : `Wallet` (Balance, Reserved, Earned, Spent — entiers ≥ 0), `Reputation` (points, mémoire anti-répétition),
`Jobs` (progression par métier), `Ledger` (60 dernières écritures), `Transfers` (rôle et état dans les transferts
multiprofils, séquestre côté vendeur), `Applied` (transferts déjà appliqués, rétention 30 jours), `Services`
(énergie : fonds réservés), et sur les exemplaires `PaidPrice`, `Dirt`, sur les propriétés `PaidPrice`,
`PaidExtensions`, `PaidModules` (montants réellement payés). Invariant validé à chaque mutation :
`Wallet.Reserved` = somme des transferts « acheteur réservé » + services en cours.

Migration (`ProfileMigration.Official[1]`) : ajoute ces champs avec des valeurs neutres (rien n'a été payé avant
le lot 0.5), sur une copie, sans rien supprimer.

## 3. Opérations mono-profil (`Commerce`)

Paiement ET acquisition dans UNE mutation d'un profil (une seule clé) : atomique, idempotente (transaction
`C:<demande>`), confirmée par écriture durable. Achat de véhicule (concession physique, modèle achetable dans
l'environnement), reprise (≈ 60 % du prix neuf × état), immobilier (achat à l'entrée du bien, revente
70 / 40 / 60 % des montants payés), agrandissement, modules (proposés : Dev seulement), pièces (revente 75 % du payé),
main-d'œuvre des garages publics (facturée dans la mutation de l'intervention), réparation (devis selon les dégâts,
état remis à neuf), lavage (salissure seulement).

**Énergie progressive** : ouverture = réservation des fonds du maximum livrable ; livraison par le serveur
(0,5 s, débit du barème, arrêt si plein, si le véhicule part ou bouge, au bout de 180 s) ; règlement = paiement de la
quantité livrée, restitution du reste, réserve durable augmentée d'autant. Interruption (arrêt du serveur) : au
chargement suivant, la réservation est restituée et l'énergie non réglée n'a jamais été rendue durable.

## 4. Transferts multiprofils (`Market`, AUD-TX-01)

Enregistrement de transaction distinct `Tx_<id>` (identifiant dérivé de la demande de l'acheteur), avancé par étapes
idempotentes, chacune rendue durable avant la suivante :

| État | Étape suivante (profil, identifiant d'étape) | Effet |
|---|---|---|
| Prepared | verrou de l'annonce (`Listing_<id>`, UpdateAsync) | une seule transaction par annonce (achats simultanés) |
| Locked | acheteur `T:<tx>:reserve` | fonds réservés (`Transfers[tx]`, Role Buyer) |
| Reserved | vendeur `T:<tx>:sell` | véhicule et pièces INSTALLÉES retirés, copie en séquestre, vendeur crédité du prix − 5 % |
| SellerApplied | acheteur `T:<tx>:receive` | réservation consommée, véhicule (même identifiant) et pièces remis |
| Committed | — | annonce vendue, séquestre nettoyé |
| Locked → Aborted | refus de réservation | annonce déverrouillée, rien débité |
| Reserved → Compensating → Compensated | vente impossible | acheteur remboursé, annonce close |

- `ProfileAccess.apply` : session du joueur si présent ici, sinon session temporaire (verrou pris puis rendu) ;
  verrou détenu ailleurs → « Deferred » et transaction inscrite dans `Inbox_<userId>`.
- Reprise : à l'arrivée d'un joueur et toutes les 30 s (boîtes des joueurs présents), balayage des transactions
  ouvertes (`Tx_Open`) toutes les 120 s ; blocage > 10 min → `NeedsRecovery` (toujours reprenable).
  L'enregistrement n'est jamais supprimé.
- Conservation : seule la commission de 5 % disparaît, explicitement. Une étape « Pending » (écriture non
  confirmée) n'avance jamais l'enregistrement.
- Annonces : réservation durable de l'exemplaire (`Reservation.Kind = "Listing"`, 72 h), puis `Listing_<id>` et
  index `Market_Index` (borné). Starter incessible, exemplaire synthétique, réservé ou sorti : refusés.

## 5. Métiers et missions

- `Jobs` : huit familles, tarif par minute estimée, risque, règle de véhicule (personnel, professionnel temporaire,
  fourni). `Jobs.withoutPersonalVehicle()` : Taxi, Livraison, Convoyage, Essais (AUD-ECO-01).
- `MissionGenerator` : itinéraires choisis par le serveur sur les données de la carte (`MissionPlaces` : carrefours
  des routes ouvertes au trafic, chemins et routes de montagne, slalom et créneau au paddock, ligne de drag) ou sur la
  zone d'essai. Durée ESTIMÉE = distance × 1,3 / vitesse moyenne + arrêts.
- `MissionEngine` : étapes Stop, Pass, OnFoot, Park, Accel, Brake et plots, évaluées sur des échantillons SERVEUR
  (5 Hz : position et vitesse répliquées, usure confirmée, corrections de mouvement). Échec : délai, correction.
  Qualité : temps, dégâts subis, freinages brusques (cargaison fragile), plots, précision du créneau, mesures d'essai.
- `RewardModel` : crédits = tarif × minutes estimées × difficulté × (1 + risque) × (0,5 + 0,5 × qualité) × premium ×
  répétition (1 ; 0,6 ; 0,35 ; 0,2 ; 0,1 dans l'heure) ; plafond de 30 missions payées par heure ; versement
  `Mission:<id>`.
- `MissionService` : véhicule professionnel/fourni matérialisé hors profil (session protégée), retiré en fin de
  mission, à l'abandon ou au départ ; maquette de véhicule en panne pour l'assistance ; repère local côté client.

## 6. Catalogues provisoires

- `VehicleCatalog` : 18 emplacements ; 6 modèles de TRAVAIL (définitions `wk_*`, dérivées des prototypes pour la
  mécanique, visuels provisoires) achetables en Dev seulement ; 12 emplacements réservés aux modèles officiels.
- `EconomyCatalog` : prix des propriétés (25 000 / 40 000 / 60 000), agrandissements, modules, pièces,
  main-d'œuvre, énergie (12 / 11 / 8 crédits par L ou kWh), lavage, réparation, bornes du marché. Tout est
  paramétrable ; aucune valeur n'est un équilibrage final.

## 7. Antifraude

Limiteurs de débit par joueur (économie : 6 jetons, 2/s), refus en mouvement, lieu physique vérifié pour chaque
opération, montants du barème serveur, identifiants de demande contrôlés, aucune valeur client récompensée (missions
mesurées par le serveur, énergie mesurée), vraisemblance de durée, répétition dégressive, plafond horaire,
suspension d'incident (`ProfileService.suspendWrites`), journal structuré borné sans données privées.
