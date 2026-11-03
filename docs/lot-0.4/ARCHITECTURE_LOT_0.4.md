# Lot 0.4 — architecture de la persistance, des propriétés et des garages

## 1. Vue d'ensemble

```
client/UI/GaragePanel ── RemoteFunction AWProgression.Request (intentions + identifiant de demande)
        ▲                       │
        │ Push (instantané,     ▼
        │ confirmations)  server/Progression/ProgressionService   (revalidation : lieu, capacités, droits, mouvement)
        │                       │            │                 │
        │            Progression/* (pur)   Locations      PropertyInteriors   Vehicles/VehicleService (exemplaires personnels)
        │                       │
        │               server/Persistence/ProfileService  (cycle de vie, sauvegardes, BindToClose)
        │                       │
        │               Persistence/ProfileSession (pur) ── TransactionService (pur) ── ProfileSessionLock (pur)
        │                       │
        └──────────── ProfileRepository : MemoryProfileRepository (Dev, tests) | DataStoreProfileRepository (Test, Prod)
```

Tout ce qui est marqué « pur » est sans service Roblox et testé par Lune (`tests/lune/specs/Lot04*.luau`).

## 2. Environnements (AUD-ENV-01)

`Persistence/Environment.resolve(GameId, IsStudio, EnvironmentConfig)` :

| Cas | Environnement | Stockage | Magasin |
|---|---|---|---|
| Expérience inconnue (dont Studio local) | Dev | mémoire | `AW_DEV_Profiles_v1` (mémoire du serveur) |
| `GameId` ∈ `TestGameIds` | Test | DataStore | `AW_TEST_Profiles_v1` |
| `GameId` ∈ `ProdGameIds`, hors Studio | Prod | DataStore | `AW_PROD_Profiles_v1` |
| `GameId` ∈ `ProdGameIds`, dans Studio | Dev | mémoire | — (jamais d'accès à la production depuis Studio) |

Les deux listes sont **vides** : aucune écriture DataStore n'a lieu aujourd'hui. Données synthétiques (`DevSeed`) :
seulement en Dev mémoire. Un profil dont le champ `Environment` diffère de l'environnement courant est ouvert en
lecture seule (aucun transfert d'actifs de test).

## 3. Enregistrement et verrou (AUD-LOCK-01, AUD-DATA-01)

Clé : `Profile_<UserId>`. Valeur (enveloppe) :

```
{ Format = 1,
  Meta = { Generation, Lock = { Session, Server, AcquiredAt, ExpiresAt }?, LastWriteAt, LastToken, Recovered? },
  Data = profil (schéma v1) }
```

- Toutes les écritures passent par `UpdateAsync` avec une transformation pure (`ProfileSessionLock`) :
  - `acquire` : refuse si une autre session détient un verrou non expiré ; reprend un verrou expiré (journalisé) ;
  - `save` : refuse si le verrou n'est plus le sien (`LockLost`) ou si la génération stockée n'est pas celle lue
    (`Stale`) → la session passe « Lost » et n'écrit plus jamais (aucun écrasement d'un état plus récent) ;
  - `release` : libère sans écrire les données (session en lecture seule).
- Durée du verrou 300 s, rafraîchi au moins toutes les 100 s ; sauvegarde périodique 60 s si modifié ; écart
  minimal de 6 s entre deux écritures d'une même clé ; une seule écriture à la fois par session (`Saving`).
- Réponse incertaine (`Uncertain`) : relecture sans cache ; jeton `LastToken` trouvé → écriture appliquée ; même
  génération et verrou détenu → non appliquée (nouvel essai ultérieur) ; sinon verrou perdu.
- Stockage injoignable → état « Unavailable » : opérations sensibles refusées, nouvel essai du chargement.
- Suspension d'incident (`ProfileService.suspendWrites`, AUD-INC-01) : transactions refusées « WritesSuspended »,
  sauvegardes ordinaires et libérations maintenues.

## 4. Transactions (AUD-TX-01, AUD-UI-02)

`ProfileSession.commit(txId, kind, mutate)` :
1. transaction déjà au journal → `Duplicate` (réponse d'origine) ou `Pending` si non encore confirmée ;
2. `TransactionService.apply` exécute la mutation sur une **copie**, valide le profil complet (`ProfileSchema.validate`)
   et la limite de taille, inscrit la transaction, puis remplace le profil ;
3. écriture immédiate : `Confirmed` si confirmée ; sinon `Pending` (budget, échec transitoire) et confirmation
   ultérieure par `tick`, notifiée au client (`Push "Confirmed"`).

Identifiants : fixes pour les attributions uniques (`Grant:FreeProperty`, `Grant:Starter`, `Grant:DevSeed`, doublés
par `Profile.Grants`, jamais purgé) ; `C:<RequestId>` pour les demandes client (GUID, format contrôlé). Journal
récent borné à 100 entrées.

**Transactions multiprofils (lot 0.5, non implémentées)** : enregistrement de transaction séparé (clé
`Tx_<id>`) avec états `Reserved → Committed | Compensated`, réservation des ressources dans chaque profil
(`Vehicle.Reservation`), application idempotente dans chaque profil par l'identifiant de transaction, reprise au
chargement des transactions non terminées. Les contrats et réservations du lot 0.4 sont prévus pour cela.

## 5. Schéma du profil (v1)

| Champ | Contenu |
|---|---|
| `Vehicles[id]` | exemplaire : `ModelId`, `OwnerUserId`, `AcquiredAt`, `Origin`, `Untransferable`, `Synthetic`, `OdometerKm`, `Energy` (fraction), `Damage` (format DamageModel), `InstalledParts` (emplacement → exemplaire de pièce), `Tuning`, `Cosmetics`, `Configurations` (≤ 5), `Storage` (Stored/Displayed/Out), `Reservation`, `Schema` |
| `Parts[id]` | exemplaire de pièce : `PartId` (catalogue), `InstalledOn` (nil = détachée), `PaidPrice` (lot 0.5), `Synthetic` |
| `Properties[id]` | `OfferId`, `Category`, `GarageLevel`, `Modules`, `Sellable`, `Origin`, `Synthetic` |
| `Invitations[id]` | `PropertyId`, `GuestUserId`, `Visit`, `Drive`, `ExpiresAt`, `Revoked` |
| `Starter`, `Grants` | choix de départ, attributions uniques |
| `Counters` | compteurs persistants des identifiants (`V-<UserId>-<n>`, `P-…`, `PT-…`, `I-…`) |
| `Transactions` | journal récent (idempotence) |

Migrations (`ProfileMigration`) : n → n + 1 sur copie, champs abandonnés déplacés dans `Legacy`, version plus récente
que le code → lecture seule (déploiement progressif), migration manquante → lecture seule. Aucune migration n'existe
encore (v1 est la première version).

**Taille et pagination** : estimation hors Roblox (`ProfileSchema.estimateSize`) ; 300 exemplaires ≈ 267 Ko
(banc Lune). Limite technique : 3,5 Mo (DataStore : 4 Mo) → acquisition refusée « ProfileTooLarge ». L'interface
reçoit la collection par pages de 20. **Fractionnement prévu, non implémenté** (à arbitrer s'il devient nécessaire) :
clés de pages `Collection_<UserId>_<n>` écrites sous le même verrou, l'enregistrement principal ne gardant qu'un index.

## 6. Collection, garages et lieux

- États exclusifs d'un exemplaire : `Stored` (sans limite), `Displayed` (place d'une propriété, capacité bornée),
  `Out` (matérialisé par UNE session). Un seul exemplaire sorti par joueur. Au chargement (verrou détenu), un
  exemplaire resté `Out` revient à sa place ou au rangement ; les réservations échues tombent.
- Lieux (`Locations`) : positions calculées depuis les données de la carte (`WorldLayout`), jamais depuis une
  instance chargée. 13 entrées (10 emplacements de propriétés, 3 boxes résidentiels) et 3 garages publics. Place de
  développement : deux points d'essai, alias explicites de tous les lieux.
- Intérieurs (`PropertyInteriors`) : un intérieur par propriété occupée, à l'écart de la carte (x ≥ 40 000 studs),
  maquettes ancrées des véhicules exposés, porte de sortie vers la même entrée. Entrée seulement depuis l'entrée
  physique de la propriété, à pied ; pas de téléportation libre.
- Sortie d'un véhicule : depuis l'intérieur ou l'entrée d'une propriété possédée, sur un emplacement libre devant
  l'entrée. Retour : le véhicule doit être ramené (immobile) à une entrée possédée ou à un garage public.

## 7. Capacités des lieux (préparation)

| Capacité | Garage public | Garage privé sans module | Module (proposé) |
|---|---|---|---|
| Ranger / exposer / sortir | — | oui | — |
| Consulter l'état | oui | oui | — |
| Appliquer une configuration réalisable sans échange de pièces | oui | oui | — |
| Modifier les réglages | oui | non | Atelier de réglage |
| Modifier l'esthétique | oui | non | Cabine d'esthétique |
| Poser / déposer des pièces | oui | non | — (garages publics indispensables) |
| Réparer | oui (lot 0.5, payant) | non | — |

Huit catégories de modules **proposées** (`GarageModules`) : Atelier de réglage, Cabine d'esthétique, Pont et
diagnostic, Rangement de pièces, Borne privée (recharge payante), Aire de lavage, Éclairage d'exposition, Salon.

## 8. Réglages, esthétique, configurations

- `TuningRules` : plages par modèle et par pièces installées (ressorts, amortisseurs, antiroulis, hauteur de caisse,
  répartition de freinage, braquage, rapport de pont, blocage de différentiel si autobloquant, loi de passage si
  boîte automatique ou double embrayage et moteur thermique). Toute valeur est validée, puis la **définition
  dérivée** est revalidée par `VehicleDefinitions.validate` (une combinaison irréalisable est refusée).
- Le serveur publie `TuningSpec` (JSON : réglages et pièces du catalogue) sur le modèle ; le client recalcule la même
  définition dérivée pour sa simulation locale.
- `CosmeticCatalog` : couleurs, finitions, jantes, éléments de carrosserie, accessoires, inscription ; appliqués par une
  apparence dérivée (`Appearance`) sans dupliquer la géométrie.
- Configurations : ≤ 5 par exemplaire ; l'application vérifie l'existence et la compatibilité des pièces requises ;
  copie transférable (vente future) : seules les configurations réalisables suivent le véhicule (AUD-ECO-02).

## 9. État durable

`DurableState.reconcile` (toutes les 30 s pour l'exemplaire sorti, et au retour ou au départ du joueur) applique les
mesures SERVEUR (énergie d'`EnergyModel`, dégâts de `DamageService`, distance des positions validées) avec des règles
monotones ; une session protégée n'écrit rien. Les écritures suivent la sauvegarde périodique (jamais par image).

## 10. Invitations et permissions (AUD-SOC-01, AUD-PERM-01)

Invitation individuelle (joueur présent sur le serveur, UserId vérifié), droits `Visit` et `Drive` séparés, durée
5 min à 24 h, révocation. Surveillance chaque seconde : visiteur sans droit → reconduit à l'entrée ; conducteur prêté
sans droit → descente une fois sous 2 m/s. Interface `PermissionSource` prévue pour les groupes (lot 0.7, source
inactive). Les visiteurs ne reçoivent aucune donnée du profil du propriétaire.
