# Rapport du lot 0.5 — économie, progression, métiers et marché automobile

Branche `feat/economy-progression-0.5`, créée depuis `6f1dc7d` (dernier commit du lot 0.4), PR brouillon vers
`feat/properties-garages-persistence-0.4`. Aucune branche précédente ni `main` n'a été modifiée.

Décision du propriétaire : campagnes Studio approfondies, essais humains et charge regroupés dans un lot QA
ultérieur. Ce lot comporte les contrôles rapides, les tests purs exigés **sur l'adaptateur mémoire** et deux courtes
sessions de démarrage dans la VM. **La persistance réelle (DataStore) et les transferts entre serveurs réels ne sont
pas validés** (`docs/QA_BACKLOG.md`, §3 bis et §3 ter).

## 1. État des livrables

Légende : **Implémenté** (code complet, logique testée hors Studio) ; **Partiel** (une partie manque, précisée) ;
**Simulé** (comportement représenté sans le système réel) ; **NON TESTÉ** (aucune exécution en jeu).

| # | Livrable | État | Précisions |
|---|---|---|---|
| 1 | Portefeuille persistant versionné | Implémenté | Profil v2, migration 1→2 ; crédits entiers ≥ 0 ; réservations ; historique borné. Persistance réelle NON TESTÉE |
| 2 | Réputation à cinq niveaux | Implémenté | Noms proposés (Débutant → Légende), seuils provisoires ; distincte des classements |
| 3 | Huit métiers | Partiel | Boucles serveur complètes (génération, étapes mesurées, échec, paiement unique) ; présentation provisoire : passagers et colis non représentés (repère d'étape seulement), véhicule en panne = maquette, **remorquage non implémenté** (intervention sur place seulement), taxi premium = majoration seulement. Jeu de bout en bout NON TESTÉ |
| 4 | Génération et validation serveur des missions | Implémenté | Itinéraires et durées décidés par le serveur ; échantillons serveur à 5 Hz ; correction de mouvement = échec |
| 5 | Concessions, achat et reprise | Implémenté | Achat sur place dans les deux concessions ; reprise ≈ 60 % × état ; catalogue de TRAVAIL (6 modèles provisoires, Dev seulement) + 12 emplacements réservés |
| 6 | Marché d'occasion sécurisé | Implémenté | Annonces, recherche, achat, annulation, expiration (72 h), commission 5 %. Index des annonces borné à 500 : à revoir à grande échelle |
| 7 | Transactions multiprofils durables et récupérables | Implémenté | Enregistrement distinct, étapes idempotentes, compensation, boîtes de réception, balayage, NeedsRecovery. Inter-serveurs réel NON TESTÉ |
| 8 | Immobilier et améliorations | Implémenté | Achat à l'entrée du bien, agrandissements, modules (proposés : Dev seulement), revente 70/40/60 % des montants payés |
| 9 | Pièces et préparations | Implémenté | Achat, revente 75 % du payé, main-d'œuvre facturée en garage public |
| 10 | Carburant, recharge, réparation, lavage | Partiel | Énergie progressive réglée au réel et récupérable ; réparation et lavage payants. Salissure visible seulement à la sortie suivante ; pas de réservation par borne (session limitée à 180 s) |
| 11 | Interfaces provisoires | Implémenté | Panneau J / stick droit (devis → confirmation → état réel). NON TESTÉ par un humain |
| 12 | Contrôles antifraude | Implémenté | Voir §5 |
| 13 | Tests et résultats factuels | Ce rapport, §2 |
| 14–16 | Rapport, architecture, registre QA | `RAPPORT_LOT_0.5.md`, `ARCHITECTURE_LOT_0.5.md`, `docs/QA_BACKLOG.md` |

## 2. Vérifications exécutées

### 2.1 Hors Studio

`powershell -ExecutionPolicy Bypass -File scripts\verify.ps1 -RobloxTypes .tooling\globalTypes.d.luau`, exécutée le
2026-11-03 de 04:00 à 04:01 sur le code du commit `2caf0c9` (arbre de travail : `docs/QA_BACKLOG.md` modifié).
Rojo (deux places), Selene, StyLua, pilote Studio, **Lune 263 réussis / 0 échoué** (dont 27 nouveaux du lot 0.5),
génération de la carte, **Pytest 10 réussis**, luau-lsp strict 0 erreur.

Tests du lot 0.5 (`tests/lune/specs/Lot05Economy.luau`), numérotés comme dans la demande :

| # | Cas | Résultat |
|---|---|---|
| 1 | Gains de mission uniques (fin rejouée) | OK : « Duplicate », solde crédité une fois |
| 2 | Solde insuffisant | OK : refus, profil inchangé |
| 3 | Répétition de demande | OK : même résultat, un débit, un exemplaire |
| 4 | Double achat concurrent (et étape par étape) | OK : une vente, l'autre « Aborted » sans débit |
| 5 | Double vente concurrente | OK : seconde annonce, reprise et sortie refusées (réservé) |
| 6 | Déconnexion / profil verrouillé ailleurs | OK : « Blocked », fonds réservés, reprise par la boîte de réception → « Committed » |
| 7 | Compensation | OK : acheteur remboursé, véhicule resté au vendeur, enregistrement conservé |
| 8 | Vente avec pièces installées | OK : pièces installées suivent, pièce détachée reste, configuration irréalisable exclue |
| 9 | Starter incessible | OK : reprise et mise en vente refusées |
| 10 | Commission de 5 % | OK : vendeur prix − 5 % ; seule la commission disparaît du total |
| 11 | Ratios immobiliers | OK : 70/40/60 % des montants payés ; gratuite invendable ; sixième refusée |
| 12 | Recharge interrompue | OK : fonds restitués, aucune énergie gratuite ; règlement au réel |
| 13 | Réparation payée une seule fois | OK : « Duplicate », puis « RepairNotNeeded » ; lavage sans effet mécanique |
| 14 | Sans crédit ni véhicule | OK : mission professionnelle payée, aucun véhicule acquis ; mauvais véhicule = pas de progression |
| 15 | Stockage indisponible | OK : achat non engagé, rien modifié (profil verrouillé : cas 6) |
| 16 | Migration v1 → v2 | OK : profil valide, données conservées, original intact |
| 17 | Perte de réponse | OK : arrêt entre deux étapes et écriture perdue, reprise sans doublon d'argent ni de véhicule |

Simulation des revenus (`lune run tools/economy/simulate.luau build/AutomotiveWorld.rbxlx 200 0.85`, même jour,
200 missions par métier, qualité 0,85) : revenus **bruts** de 11 471 (Livraison) à 12 800 (Taxi) crédits par heure
estimée, **nets** de 11 471 à 12 800 ; écart net max/min **1,12**. Valeurs de modèle, pas des mesures en jeu ; le
carburant pèse peu par mission (trajets de 1,5 à 8 km).

### 2.2 Contrôles de démarrage dans Studio (VM)

Courtes sessions existantes, pour détecter une erreur bloquante au démarrage (pas une campagne) :

| Tâche | Commit | Session | Résultat |
|---|---|---|---|
| `20261103-035455` | `77923a6` | `lot04` (place de développement, 2 joueurs) | 63 / 0 — aucune erreur d'exécution avec le profil v2 et les services économiques |
| `20261103-035626` | `77923a6` | `monde` (monde ouvert) | 31 / 1 → **défaut trouvé** : 29 invites « Garage public » au lieu de 16 |
| `20261103-035902` | `2caf0c9` | `monde` après correction | **33 / 0** : 16 invites de progression + 13 invites économiques, aucune erreur, conduite 126 km/h sur l'autoroute |

Défaut corrigé (`2caf0c9`) : les 13 lieux économiques ajoutés (2 concessions, 6 stations, 2 bornes, 3 lavages)
recevaient l'invite de la progression ; ils ont désormais une invite propre qui ouvre le panneau économie.

Les opérations économiques elles-mêmes n'ont été exécutées dans aucune session Studio : **NON TESTÉES en jeu**.

## 3. Écarts, choix et points à arbitrer

1. **Catalogue** : 6 modèles de TRAVAIL fictifs (Aster, Brio, Cadence, Dune, Éclat, Fil), mécanique dérivée des
   prototypes, visuels « PROVISOIRE », achetables en Dev seulement ; 12 emplacements réservés aux modèles officiels.
   Les 18 modèles et les 3 modèles de départ restent à valider (liste de départ toujours vide).
2. **Prix** : tous provisoires (véhicules, propriétés 25 000 / 40 000 / 60 000, modules, pièces, main-d'œuvre, énergie
   12 / 11 / 8 crédits, lavage 120, réparation au barème). Rémunération ≈ 9 000 à 12 800 crédits/heure selon la
   difficulté (hypothèse illustrative du cahier des charges : 8 000 à 12 000).
3. **Modules de garage** : toujours des propositions ; achat réservé au développement (« ModuleAwaitingDecision »).
4. **Remorquage** : non implémenté (matériel absent) ; l'assistance est une intervention sur place.
5. **Achat d'un bien** : sur place, à l'entrée ; la revente se fait depuis le menu (refusée si quelqu'un est dans le bien).
6. **Marché** : index des annonces dans le stockage des profils, borné à 500 ; une solution adaptée au volume
   (MemoryStore ou index paginé) est à décider avant une ouverture publique.
7. **Bornes** : pas de réservation par borne ; une session d'énergie est limitée à 180 s.
8. **Données synthétiques de développement** : 150 000 crédits synthétiques ajoutés en Dev (mémoire seulement).
9. **Véhicules de mission** : prototypes techniques prêtés (P-02 professionnel, P-01 fourni), jamais dans le profil.
10. Version de développement inchangée (`0.4.0-dev`) : à passer en `0.5.0-dev` à la clôture si souhaité.

Anomalies connues des lots précédents : non corrigées et non retestées dans ce lot (`docs/QA_BACKLOG.md` §1).

## 4. Correction après livraison : guidage des missions

Retour du propriétaire (2026-11-03) : avec le métier « Essais automobiles » dans le monde ouvert, le point de
départ est introuvable. Le départ est la piste de drag, à environ 3 à 5 km du point d'apparition, et la colonne
jaune (60 studs) n'y est plus visible. Le texte de mission affichait aussi l'identifiant technique (« Testing »).

Correction (client seulement, `src/client/UI/EconomyPanel.luau`) : flèche orientée par rapport à la caméra et
distance à vol d'oiseau sous le texte de mission ; étiquette de distance toujours visible au-dessus du repère ;
colonne de 400 studs posée au sol (lancer de rayon, répété toutes les 2 s tant que la zone se charge) ; nom
français du métier. Aucune règle serveur ni récompense modifiée.

Vérifications du 2026-11-03 sur l'arbre de travail (base `b80bf6a` + cette correction) : `scripts\verify.ps1`
tout OK (Lune 263 / 0, pytest 10, luau-lsp strict 0 erreur) ; VM, tâche `20261103-101510`, session `lot04` :
63 / 0, aucune erreur serveur. Cette session ne lance pas de mission : **le guidage n'a pas été exercé en jeu
(NON TESTÉ, `docs/QA_BACKLOG.md` QA-E14)**.

## 5. Antifraude (résumé)

Montants du barème serveur ; lieu physique vérifié ; refus en mouvement ; identifiants de demande contrôlés ;
transactions idempotentes ; réservations et confirmations durables ; aucune valeur client récompensée (missions et
énergie mesurées par le serveur) ; mission annulée sur correction de mouvement ; vraisemblance de durée ;
rémunération dégressive en cas de répétition ; plafond de 30 missions payées par heure ; limiteurs de débit ;
journal structuré borné.
