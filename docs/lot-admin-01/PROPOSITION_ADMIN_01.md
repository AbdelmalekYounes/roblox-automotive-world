# Lot ADMIN-01 — expérience privée de test et menu d'administration : proposition

Proposition rédigée le 2026-11-05 à la demande du propriétaire :

> « on va également déployer une expérience privée, il faudra développer un menu admin dans lequel on peut faire
> plusieurs actions comme : cycle jour/nuit, faire apparaître des véhicules, réparer un véhicule dans lequel on est, un
> mode no clip, ajout de crédit au joueur ; si tu as d'autres propositions n'hésite pas »

**Rien n'est développé ni publié.** La publication reste faite par le propriétaire, dans Roblox (règle CLAUDE.md :
aucune publication sans son accord explicite, et je ne publie jamais moi-même).

## 1. Expérience privée de test

### Ce que fait le propriétaire (Roblox)

1. Créer une expérience **privée** dans le Creator Hub, publier la place depuis Studio, et laisser l'accès limité à son
   compte et à ses invités.
2. Me donner l'**identifiant de l'expérience** (GameId / Universe). Je l'inscris dans
   `EnvironmentConfig.TestGameIds`. L'expérience passe alors en environnement **Test** : DataStore réel mais **isolé**
   (`AW_TEST_Profiles_v1`), jamais celui de production, et **sans crédits synthétiques** (`DevSeed` n'existe qu'en Dev).
3. Réglages de l'expérience :
   - avatars R15 (AVATAR-01) ;
   - accès de Studio aux API (DataStores) si on veut tester depuis Studio.
4. **Propriété des actifs (D6)** : les maillages de la Comète, les icônes du téléphone et les actifs de la citadine
   doivent appartenir au **même créateur** que l'expérience, sinon ils risquent de ne pas se charger (QA-K02, jamais
   vérifié hors Studio).

### Ce que je fais avant la première publication (prérequis, P1)

- **QA-D11** : aujourd'hui, une place publiée dont l'identifiant n'est pas déclaré passe en mode « Dev ». Elle donne
  alors les crédits synthétiques et rend les modèles en attente achetables.
  Correctif : hors de Studio, un identifiant non déclaré **refuse** le mode Dev (serveur en lecture seule ou joueurs
  renvoyés avec un message).
- Inscription du GameId fourni par le propriétaire.
- Liste de vérification de la première connexion : profil créé dans le magasin de test, sauvegarde, reconnexion,
  chargement des maillages.

C'est aussi la première occasion de faire **tourner le DataStore réel** (blocage persistance n° 1 de l'audit, §7.2),
dans un magasin de test.

## 2. Menu d'administration

### Principes de sécurité

- **Le serveur décide de tout** : liste d'administrateurs par identifiant de joueur (UserId), inscrite côté serveur.
  Au départ, le compte du propriétaire seul : quel identifiant ? à confirmer.
- **Un seul point d'entrée** :
  - une fonction distante `AWAdmin` avec une **liste fermée d'actions** ;
  - limite de débit ;
  - paramètres validés (types, bornes, véhicules connus) ;
  - refus silencieux pour un non-administrateur, journalisé côté serveur.
- **Environnements** : actif en **Dev (Studio) et Test (expérience privée)** ; **désactivé en Production** sauf décision
  contraire du propriétaire (point A1).
- **Journal d'audit** de chaque action : qui, quoi, quand, sur qui, résultat. Visible dans le menu.
- Les crédits passent par les transactions identifiées de l'économie existante : motif « AdminGrant », montant borné par
  action, jamais une écriture directe du solde.
- Interface au style V1.2 (PanelKit) : touche dédiée (F8 proposée) et application « Admin » du téléphone, **visibles
  seulement des administrateurs**. Confirmation pour les actions sensibles (crédits, actions sur un autre joueur).

### Actions demandées

| Action | Fonctionnement prévu | Point d'attention |
|---|---|---|
| Cycle jour/nuit | Régler l'heure (matin, midi, soir, nuit), figer ou relancer le cycle, changer sa vitesse | S'applique à tout le serveur |
| Faire apparaître des véhicules | Choisir un modèle (Comète, puis la citadine) : véhicule temporaire à côté de soi, comme l'accès de revue | Véhicule non possédé, retiré à la sortie ; option « donner au joueur » (A3) |
| Réparer le véhicule dans lequel on est | Dégâts remis à zéro, optiques rallumées, énergie pleine en option | Passe par `DamageService`, pas par le client |
| Mode no clip | Déplacement libre à pied, sans collision ni gravité, vitesse réglable | Le serveur valide les mouvements (`MovementRules`) : l'administrateur en no clip en est exempté, et c'est journalisé |
| Ajouter des crédits | À soi ou à un joueur présent ; montant borné | Transaction « AdminGrant » journalisée ; persistante dans le magasin de test |

### Mes propositions supplémentaires

- **Météo** : sec, pluie, brouillard, orage (`WeatherService.force` existe déjà).
- **Téléportation** : vers les 7 zones et les lieux (concessions, garages, stations, départs de course), vers un joueur,
  ou amener un joueur à soi.
- **Véhicule** : retourner sur ses roues, plein d'énergie, invulnérabilité (aucun dégât), retirer tous les véhicules
  apparus.
- **Personnage** : réapparaître, vitesse de marche, invisibilité pour les autres (captures, observation).
- **Profil de test** :
  - voir l'état du profil (version, sauvegarde, verrou) ;
  - donner ou retirer un véhicule possédé ;
  - réinitialiser son profil (repartir comme un nouveau joueur, pour rejouer l'arrivée) — **en Test seulement**.
- **Progression** : régler la réputation, terminer ou annuler la mission en cours.
- **Courses** : lancer une course sans attendre les autres joueurs, avec des concurrents fantômes si possible plus tard.
- **Diagnostic** : surcouche FPS, ping, position, zone, environnement (Dev, Test ou Prod), état du DataStore. Utile pour
  tes essais manuels, puisque les campagnes VM sont arrêtées.
- **Joueurs** : liste des joueurs présents, expulser avec un motif.
- **Journal** : les 50 dernières actions d'administration.

## 3. Points à trancher

- **A1** — Menu admin en Production : désactivé (recommandé) ou actif pour les administrateurs ?
- **A2** — Ordre des lots : BASE-01, puis ADMIN-01 et l'expérience privée (recommandé : une base propre avant la
  première publication) ; ou ADMIN-01 d'abord.
- **A3** — Véhicules apparus : temporaires seulement (recommandé), ou option « donner » (possession enregistrée) ?
- **A4** — Montant maximal de crédits par action (proposé : 1 000 000).
- **A5** — Liste des propositions du §2 à retenir dans ce lot (le reste en lot suivant).
- **A6** — Identifiant du compte administrateur : celui des essais VM est `youyou31110`, à confirmer.

## 4. Décisions du propriétaire (2026-11-05)

- **A1** : menu **actif pour les administrateurs dans tous les environnements**, Production comprise.
- **A2** : ordre recommandé (BASE-01 clôturé et fusionné le 2026-11-05, PR #20), puis ADMIN-01, puis VEH3D-02.
- **A3** : véhicules apparus **temporaires** seulement (aucune possession enregistrée).
- **A4** : **100 000** crédits au plus par action.
- **A5** : « fais tout » : toutes les propositions du §2 sont retenues.
- **A6** : compte administrateur : celui des essais, `youyou31110` (UserId 941826283, relevé dans les rapports des tâches VM).

Conséquence de A3 sur le §2 : « donner ou retirer un véhicule possédé » n'est **pas** réalisé ; les véhicules apparus
restent temporaires.

