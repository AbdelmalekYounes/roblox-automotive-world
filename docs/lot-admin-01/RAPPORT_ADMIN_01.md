# Lot ADMIN-01 — menu d'administration et préparation de l'expérience privée : rapport

Branche `feat/admin-01-menu-admin`, depuis `main` (`1195a92`, BASE-01 fusionné). Rapport du 2026-11-05.
Décisions du propriétaire : `PROPOSITION_ADMIN_01.md` §4 (A1 à A6). Rien n'est fusionné ni publié. Aucune session VM.

## 1. Ce qui a été fait

### Serveur (autorité)

- **`Server/Admin/AdminConfig`** : liste des administrateurs, côté serveur seulement, jamais répliquée. Elle contient
  `youyou31110`, UserId 941826283 (A6).
- **`Server/Admin/AdminService`** :
  - un seul point d'entrée, `ReplicatedStorage.AWAdmin.Request` ;
  - **droits vérifiés avant tout**, puis limite de débit, puis validation des paramètres (`Shared/Admin/AdminRules`,
    liste fermée de 22 actions) ;
  - un non-administrateur est refusé, et le refus est consigné dans la sortie du serveur ;
  - **journal** : 50 dernières actions (qui, quoi, sur qui, détail, résultat), dans le menu et dans la sortie du serveur
    (`[AutomotiveWorld][Admin]`) ;
  - le joueur administrateur reçoit l'attribut `AWAdmin`. Il sert seulement à afficher le menu : le serveur revérifie
    chaque demande.
  - Le menu est actif dans **tous les environnements** (A1).
- **Actions** :

| Domaine | Actions | Fonctionnement |
|---|---|---|
| Monde | heure (matin, midi, soir, nuit), cycle (figé, normal, × 10, × 60), météo (sec, pluie, brouillard, orage) | `WeatherService.setClock` : ancre et vitesse publiées en attributs (`AWClockAnchor`, `AWClockSpeed`) ; `WeatherService.force`. Dans la place de développement, le rendu du ciel démarre au premier réglage. |
| Véhicule | apparition **temporaire** de tout modèle du jeu (A3), retrait des véhicules apparus, réparation (avec ou sans plein), remise sur roues immédiate, invulnérabilité | `MissionService.spawnBeside` (véhicule protégé, jamais possédé, retiré au départ de l'administrateur) ; `DamageService.repair` (état intact, marques et fumée retirées, optiques rétablies) ; `VehicleService.adminFlip` ; attribut `AWAdminInvulnerable` (aucun dégât compté) |
| Personnage | no clip (vitesse 30, 60 ou 150 st/s), vitesse de marche (16 à 100), invisibilité, réapparition, téléportation vers les lieux publics de la carte | no clip : autorisé par le serveur (attribut), appliqué par le client (`Client/Admin/NoclipController`) ; téléportation : points de `InterfaceService`, sol trouvé par rayon vertical ; refusée au volant |
| Joueurs | aller à, amener, donner des crédits, expulser (motif obligatoire) | crédits : transaction « AdminGrant » du portefeuille, **1 à 100 000 par action** (A4) ; confirmation demandée |
| Profil | crédits pour soi (+1 000, +10 000, +100 000), réputation (paliers), abandon de la mission, départ forcé de sa course, **réinitialisation du profil** | réputation : transaction tracée ; départ forcé : salon ramené à l'effectif présent, tous prêts ; réinitialisation : **Dev et Test seulement**, puis reconnexion |
| Diagnostic | surcouche FPS, ping, position, environnement, état du profil, mémoire | client, rafraîchie deux fois par seconde |

### Client

- **`Client/UI/AdminPanel`** : menu au style V1.2 (PanelKit), sept onglets, **touche F8**.
  - Il n'est construit que si le serveur a marqué le joueur administrateur.
  - Confirmation pour les crédits, la réputation, l'expulsion, « amener » et la réinitialisation.
  - Les refus du serveur sont traduits (24 nouvelles clés FR/EN) ; les textes du menu passent par `tr` (108 entrées
    ajoutées à `PanelTexts`).
- **`Client/Admin/NoclipController`** : collisions coupées, vitesse imposée à chaque image ; caméra, Espace (monter),
  Maj gauche (descendre).

### Prérequis de l'expérience privée : correctif QA-D11

- `Environment.resolve` : **hors de Studio**, une expérience dont l'identifiant n'est déclaré nulle part passe en
  environnement **« Unconfigured »**.
  - Stockage en mémoire.
  - **Aucun crédit synthétique, aucun achat réservé au développement, aucun véhicule de départ synthétique.**
- Studio garde « Dev ».

### Cohérence

- `ProjectSettings.LaunchVehicleModelCount` passe de 18 à 2 (BASE-01), avec l'assertion de démarrage associée.

## 2. Contrôles exécutés (2026-11-05)

| Commande | Résultat |
|---|---|
| `scripts\verify.ps1 -DownloadRobloxTypes` | toutes les étapes OK : Rojo, Selene, pilote Studio, StyLua, Lune, carte, place monde ouvert, pytest, luau-lsp strict |
| `lune run tests/lune/run.luau build/AutomotiveWorld.rbxlx` | **398 réussis, 0 échec** |

Tests ajoutés :
- `Admin01` (8 tests) :
  - droits côté serveur, liste fermée, bornes des crédits et des autres paramètres ;
  - journal circulaire, confirmations ;
  - horloge réglable ;
  - un traitement par action ;
  - droits vérifiés avant la validation ;
  - réinitialisation jamais en production ;
  - menu réservé aux administrateurs.
- `Lot04Persistence` : QA-D11.
- Couverture des traductions étendue au menu admin.

## 3. Non testé, limites

- **Aucun essai en jeu** : liste de vérification ci-dessous.
- **No clip** : appliqué par le client. Le serveur ne contrôle pas les déplacements à pied des personnages ; il
  autorise et consigne le mode.
- **Invisibilité** : pièces rendues transparentes, nom masqué. Un accessoire ajouté ensuite resterait visible jusqu'à
  la réapparition.
- **Réparation** : sur un véhicule à kit de maillages (la Comète), tout est rétabli. Sur une coque de repli, les
  déformations éventuelles ne sont pas annulées.
- **A1, menu actif en production** : un compte administrateur compromis aurait ces pouvoirs. La liste n'existe que
  côté serveur, et chaque action est consignée.
- **DataStore réel** : toujours jamais exécuté. Il le sera dans l'expérience privée, une fois son identifiant déclaré.

## 4. Expérience privée de test : étapes du propriétaire

1. Dans le **Creator Hub**, créer une expérience et la laisser **privée**.
2. Dans Studio, ouvrir `build\AutomotiveWorld-admin01.rbxlx` (ou la place du monde ouvert), puis **Fichier › Publier
   sur Roblox**, vers cette expérience. **Je ne publie jamais.**
3. Dans les réglages de l'expérience :
   - avatars R15 ;
   - **Sécurité › Autoriser l'accès de Studio aux services d'API**, si tu veux essayer le DataStore depuis Studio.
4. Me donner l'**identifiant de l'expérience** (Universe ID ou Game ID). Je l'inscris dans
   `EnvironmentConfig.TestGameIds` (environnement Test, DataStore isolé `AW_TEST_Profiles_v1`), puis tu republies.
   Avant cette déclaration, l'expérience tourne en « Unconfigured » : rien n'est sauvegardé ni distribué.
5. **Propriété des actifs (D6)** : les maillages de la Comète et les icônes doivent appartenir au créateur de
   l'expérience, sinon ils risquent de ne pas se charger.

## 5. Ce que le propriétaire doit vérifier (Studio, place de cette branche)

Préparation : ouvrir `E:\ROBLOX DEV\aw-wt-admin\build\AutomotiveWorld-admin01.rbxlx`, puis cliquer sur Jouer.

Studio joue avec ton compte, `youyou31110`.

1. **Accès** : F8 ouvre le menu « ADMINISTRATION » avec ses sept onglets ; F8 ou « Fermer » le referme.
2. **Monde** :
   - « Nuit » rend le ciel nocturne, « Midi » ramène le jour ;
   - « Figer » arrête le temps ;
   - « Pluie » fait tomber la pluie, « Sec » l'arrête.
3. **Véhicule** :
   - « Comète » fait apparaître une Comète à côté de toi ;
   - monte, abîme-la contre un mur, puis « Réparer » : les marques disparaissent ;
   - « Invulnérable : oui », puis un choc : aucune marque ;
   - « Remettre sur roues » fonctionne même en roulant ;
   - « Retirer mes véhicules apparus » fait disparaître la Comète.
4. **Personnage** :
   - « No clip : actif » permet de voler et de traverser les murs (Espace pour monter, Maj gauche pour descendre) ;
     « No clip : inactif » te repose au sol ;
   - « Marche 64 » te fait courir plus vite ;
   - « Invisible : oui » rend ton personnage transparent ;
   - « Réapparaître » fonctionne ;
   - Téléportation : choisis « Concessions », puis une concession, et tu y es téléporté.
5. **Joueurs** : ta ligne affiche « Aller à », « Amener » et « Expulser » grisés (« C'est vous »). Avec un montant de
   5 000 : « Donner des crédits », confirmation, puis le solde augmente de 5 000 (vérifier avec J). Un montant de
   200 000 grise le bouton.
6. **Profil** :
   - environnement « Dev » ;
   - « + 100 000 » augmente le solde ;
   - réputation « 8000 » donne le niveau Expert dans J ;
   - « Réinitialiser mon profil », confirmation : tu es déconnecté avec le message, et tu retrouves un profil neuf à la
     reconnexion.
7. **Diagnostic** : « Afficher la surcouche » montre FPS, ping, position, « Dev », l'état du profil et la mémoire, en
   haut à gauche.
8. **Journal** : chaque action ci-dessus apparaît, la plus récente en tête.
9. **Optionnel, deux joueurs** (onglet Test › Serveur local à 2 joueurs, ou après la publication) :
   - le second joueur n'a ni F8 ni menu ;
   - depuis ton menu : « Aller à », « Amener », crédits, puis « Expulser » avec un motif.

## 6. Retour du propriétaire : « F8 ne fait rien » (2026-11-05)

Causes possibles, **non établies** (aucun essai de ma part) :
- Studio réserve probablement F8 pendant le jeu (raccourci « Run »), si bien que la touche n'arrive pas au jeu ;
- ou le compte Studio n'est pas l'UserId 941826283.

Corrections :
- seconde touche **F2** ;
- accès **Téléphone › Paramètres › Administration** (administrateurs seulement) ;
- diagnostic dans la sortie :
  - serveur : « … reconnu administrateur » ;
  - client : « Menu d'administration disponible » ;
  - ou, au bout de 10 s : « Menu indisponible : le compte … (UserId …) n'est pas administrateur ».

`verify.ps1 -DownloadRobloxTypes` : toutes les étapes OK, Lune 398/398.

Résultat du diagnostic, rapporté par le propriétaire : « Menu indisponible : le compte Akroniik (UserId 7835831473)
n'est pas administrateur ». **Cause établie** : le compte Studio du propriétaire n'était pas dans la liste. Akroniik
(7835831473) est ajouté à `AdminConfig`, à côté de youyou31110 (941826283).

