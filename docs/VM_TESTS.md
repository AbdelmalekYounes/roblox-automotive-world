# Tests Roblox Studio dans la VM VMware

> **Depuis le 2026-11-05**, à la demande du propriétaire, les campagnes VM automatiques sont arrêtées : il teste
> lui-même à partir de listes de vérification. Ce document décrit l'outil, conservé et lancé seulement sur sa demande.

Objectif : exécuter les essais du lot 0.1 **dans Roblox Studio**, avec la vraie physique et le vrai réseau,
**sans afficher de fenêtre sur ton PC ni utiliser ta souris ou ton clavier**. Tout se passe dans la VM
« ROBLOX DEV » (`E:\VMS\ROBLOX DEV\ROBLOX DEV.vmx`) ; ton PC ne fait que déposer une tâche et lire le rapport.

Même méthode que pour le projet précédent (agent dans la VM, dossier d'échange, Studio en mode script),
mais **code entièrement réécrit** pour ce projet (le cahier des charges interdit de reprendre du code d'un autre projet).

## Fonctionnement

```
Hôte (ton PC)                                   VM « ROBLOX DEV » (session ouverte automatiquement)
test-vm.cmd → tools/vm/host-run.ps1              tâche planifiée AutomotiveWorldAgent (droits limités)
  vérifie que la VM tourne (vmrun list)            → %LOCALAPPDATA%\AutomotiveWorldTests\agent\guest-agent.ps1
  signale tout partage qui exposerait le dépôt
  attend agent-heartbeat.json        ◀──────────  battement de cœur toutes les 5 s
  rojo build → place.rbxl
  lune → driver.luau (suites Studio)
  dépose jobs/<id>/ + job.ready      ──────────▶  job.ready → job.claimed, copie locale (liste fermée de fichiers)
                                                  job-runner.ps1 : RobloxStudioBeta.exe --task RunScript …
                                                    pilote : ExecutePlayModeAsync (solo, scenarios)
                                                             ExecuteMultiplayerTestAsync(2) (autres sessions)
                                                  aw-capture.exe (facultatif) : compilé dans la VM depuis
                                                    ScreenCapture.cs, captures de l'écran de la VM
  attend done.json                   ◀──────────  report/ (sortie Studio, journaux, captures, result.json) + done.json
  make-report.ps1 → report.md + build/test-reports/latest-vm.md
```

**Dossier d'échange** : `E:\ROBLOX DEV\aw-vm-exchange` (à côté du dépôt, **hors du dépôt**), partagé avec la VM sous
le nom `aw-vm-exchange` (`\\vmware-host\Shared Folders\aw-vm-exchange`). C'est le **seul** dossier que la VM voit et
peut écrire. Chemin modifiable par `test-vm.cmd -Exchange <dossier>` (mémorisé dans `build\vm-config.json`).

## Ce que les tests Studio vérifient réellement

Dans chaque session, une suite **serveur** et une suite **client** sont injectées dans le Studio de test (la place
n'est jamais enregistrée ni publiée). La suite client conduit le vrai véhicule par le vrai chemin du jeu : invite
d'embarquement, simulation locale, forces, propriété réseau, contrôles serveur, caméra, HUD. **Seule la lecture
clavier/manette est remplacée** par un point d'accès réservé à Studio (`VehicleController.setTestInputProvider`).

| Session | Contenu |
|---|---|
| `solo` | zone et 4 véhicules posés et immobiles ; embarquement par l'invite ; 4 roues au sol ; accélération progressive et 0–100 km/h mesuré ; rapports qui montent ; sortie refusée en roulant ; freinage jusqu'à l'arrêt (distance mesurée) ; marche arrière ; virages ; caméra proche/lointaine ; frein à main ; remise sur roues refusée si inutile ; téléportation volontaire corrigée par le serveur, **simulation client suspendue pendant la correction puis reprise** ; sortie à l'arrêt ; propriété réseau = conducteur et **attribut de simulation conforme au propriétaire effectif** ; aucune erreur d'exécution |
| `multijoueur` | la même chose avec 2 clients ; le 2ᵉ joueur ne peut pas prendre le véhicule occupé ; **déconnexion d'un conducteur** (expulsion du joueur 2 assis) : véhicule rendu au serveur, libre et réembarquable |
| `latence` | `multijoueur` avec 100 ms de délai réseau demandé à Studio dans chaque sens ; le ping mesuré figure dans le rapport |
| `scenarios` | bosse à 10 %, slalom, véhicule sur le toit remis sur roues, retour au plot (délai réel de 90 s), impact contre un véhicule garé, **propriété réseau refusée par le moteur** (véhicule ancré : embarquement refusé proprement) puis rétablie |
| `collision` | expérience de collision : 6 impacts latéraux à ~20 km/h, alternant véhicule **conduit** par l'autre joueur et véhicule **garé** ; mesures serveur et clients, échanges d'impulsion confirmés par le serveur |
| `collision_latence` | la même expérience avec 100 ms de délai réseau dans chaque sens |
| `lot02` | lot 0.2, 1 joueur, 22 étapes : six boîtes, aides avec/sans, mouillé, pente, bordures (rayon/sphère), dégâts, énergie et panne, caméras, banc de 16 véhicules serveur (≈ 7 min 30) |
| `avatar`, `avatar2` | lot AVATAR-01 : morphologies R15 dans les véhicules, sorties, tenues, téléphone (vraies entrées) ; bras levé vu par un 2ᵉ joueur |
| `aster` | phase 1 de l'Aster : maquette en blocs d'après le gabarit, 10 morphologies sur les deux corps humains, pose standard et pose du jeu, mesures côté client (`@@AWASTER@@`), forme des têtes |
| `silhouette` | clôture de la phase 1 : choix de silhouette par **vrais clics** (panneau d'apparition, téléphone), vêtements, têtes classiques et non classiques, réapparition, couleurs de peau, changements successifs avec expirations forcées |
| `silhouette2` | 2 clients : corps du joueur 1 mesuré par le joueur 2 et comparé au serveur à chaque changement (changements appelés par le serveur de test) |
| `comete` | lot VEH3D-01 : Comète 3D (kit de maillages), essais QA-K01 à QA-K08 : structure, chargement des maillages, roues, sièges, caméras (touche V), conduite et chocs avant/arrière contre `MurDeChoc`, nuit, temps d'image de 24 Comète ; à lancer avec `-GuiInput` |
| `comete_vitres` | lot VEH3D-01 : même début que `comete`, puis 5 réglages du vitrage capturés conducteur assis (profil, trois-quarts) ; à lancer avec `-GuiInput` |

Non couvert par ces sessions : lecture réelle des touches et de la manette, ressenti, son (essais humains, voir
`docs/lot-0.1/RAPPORT_TESTS.md`). Lot 0.9.1 : les sessions `ui` et `ui_monde` utilisent de **vraies** entrées
souris et clavier **dans la VM** (section suivante) ; la manette reste non couverte.

## Entrées réelles dans la VM (lot 0.9.1)

But : parcourir les interfaces par de vrais clics et de vraies touches, et non en appelant leurs fonctions.

```
client de test (GuiDriver.luau)                     aw-capture.exe (ScreenCapture.cs), DANS la VM
print("@@AWIN@@ 12 click 937 355") ── journal Studio (%LOCALAPPDATA%\Roblox\logs) ──▶ SendInput (souris, clavier)
Activated / KeyCode reçus par le jeu ◀──────────── clic et touches dans la fenêtre de Studio de la VM
```

- **Activation** : par tâche seulement (`job.json` → `guiInput`), d'office pour les sessions `ui…`, ou
  `test-vm.cmd -GuiInput`. Sans ce drapeau, l'outil ne fait que des captures, comme avant.
- **Étalonnage** : le test affiche deux carrés magenta à l'intérieur de la vue du jeu (les coins sont couverts par la
  barre de Roblox et le filigrane de Windows) ; l'outil les repère sur l'écran de la VM (décalage et échelle), puis
  clique le premier : l'événement `Activated` du bouton prouve que le clic réel est arrivé. Clavier : touches sans action
  envoyées par code virtuel puis par code de balayage ; le mode dont les `KeyCode` reçus sont exacts est retenu (VM en
  AZERTY : codes de balayage).
- **Garde-fous** : aucune action avant l'étalonnage ; pointeur **borné à la vue du jeu** (jamais la barre d'outils de
  Studio, donc jamais « Arrêter ») ; touches limitées à une liste (lettres, chiffres, espace, entrée, échap, retour,
  tabulation, flèches, `\`, Maj) : ni touches de fonction, ni Ctrl, ni Alt ; chaque commande est consignée dans
  `report\gui\input-log.txt`. Les entrées sont produites dans la session Windows de la VM et n'en sortent pas : la
  souris et le clavier du poste principal ne sont jamais utilisés.
- **Captures nommées** : `report\gui\named\NNN_<nom>.jpg`, vue du jeu en pleine résolution, reliées dans le rapport à
  la position du personnage et au contexte.
- **Limites** : une seule fenêtre étalonnée à la fois ; les sessions à deux clients (deux fenêtres de Studio) passent
  par les remotes du jeu (instrumenté, signalé). Aucune manette n'est émulée (il faudrait installer un pilote dans la VM).
- **Ordre des sessions (lot 0.9.2)** : placer les sessions à vrais clics (`ui`, `ui_marche`, `ui_monde`) **en tête** de
  tâche. Placée en 7ᵉ position après six sessions à deux clients (`20261104-031015`), la session `ui` a obtenu un
  étalonnage faux (échelle 1,763) et aucun clic n'est arrivé ; en tête (`20261104-035727`, `-042820`), l'étalonnage
  est juste.
- **Longueur d'une ligne de résultat (lot AVATAR-01)** : la sortie de Studio tronque une ligne au-delà de **100 000
  caractères** (tâche `20261104-104818` : session `avatar` illisible par le rapport) ; garder les résultats d'une session
  compacts (détails courts, aucun journal d'entrées dans le rapport) et écrire les mesures détaillées sur des lignes
  séparées.
- **Captures au volant** : le contrôleur du véhicule replace la caméra à chaque image (`PreRender`) ; une capture cadrée
  par script doit réimposer la caméra à chaque étape de rendu (voir `AvatarClient.client.luau`).
- **Touche O** : jamais reçue par le jeu dans Studio (ni code virtuel ni code de balayage) ; le mode photo s'ouvre par
  le téléphone. Limite de l'environnement, connue depuis le lot 0.9.1.
- **Touche Ctrl** : jamais reçue par le jeu dans Studio (tâches `20261105-001843` et `-002227`) ; la session `comete`
  engage R par l'appel de test et le signale.
- **Fenêtre d'arrivée** : un profil neuf ouvre « Choisir votre véhicule », qui capture la conduite (lot 0.7) ; une
  session qui conduit la ferme d'abord par la vraie touche Retour.
Statut ⚠️ « limite connue » : contrôle en échec dont la cause est documentée ; jamais compté comme réussi.

## Préparation de la VM

Déjà fait : VMware Workstation, VM Windows 11 avec 3D, session ouverte automatiquement, Roblox Studio installé et
connecté avec un compte de test.

1. **Sur l'hôte**, partager uniquement le dossier d'échange avec la VM :
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools\vm\configure-share.ps1 -Apply -RemoveRepoShare
   ```
   Le script crée `E:\ROBLOX DEV\aw-vm-exchange` et y publie `setup\`. La VM « ROBLOX DEV » étant **chiffrée**,
   `vmrun` exige son mot de passe pour modifier les partages (constaté le 2 novembre 2026) : le script affiche alors
   les étapes à faire **à la main dans VMware Workstation** (*VM > Settings > Options > Shared Folders* : retirer
   `roblox-automotive-world-starter`, ajouter `aw-vm-exchange` → `E:\ROBLOX DEV\aw-vm-exchange`, lecture/écriture).
   Aucun mot de passe n'est demandé ni stocké par les scripts.
2. **Dans la VM** (action manuelle du propriétaire), PowerShell **administrateur** depuis le compte qui s'ouvre
   automatiquement :
   ```powershell
   powershell -ExecutionPolicy Bypass -File "\\vmware-host\Shared Folders\aw-vm-exchange\setup\guest-setup.ps1"
   ```
   Relançable sans risque. Il refuse de s'exécuter hors d'une VM VMware, installe l'agent dans
   `%LOCALAPPDATA%\AutomotiveWorldTests\agent`, (ré)enregistre la tâche `AutomotiveWorldAgent` et démarre l'agent.
   Il **liste** les agents d'autres projets sans les toucher (les arrêter seulement sur demande : `-StopTasks Nom`).
3. Ouvrir Roblox Studio une fois dans la VM pour accepter une éventuelle mise à jour ou reconnexion, puis le fermer.
4. Fermer la fenêtre de VMware Workstation en choisissant **Run in Background**.

La VM est chiffrée (TPM virtuel) : `vmrun` ne peut pas la démarrer sans mot de passe, et aucun mot de passe n'est
stocké par ces scripts. La démarrer dans Workstation puis *Run in Background*.

## Lancer les tests (depuis l'hôte)

```bat
test-vm.cmd                                   :: les 7 sessions (≈ 20 min)
test-vm.cmd -Sessions lot02 -TimeoutSec 1800  :: essais du lot 0.2 seuls
test-vm.cmd -Sessions lot04                   :: progression du lot 0.4 (2 joueurs)
test-vm.cmd -Place OpenWorld -Sessions monde  :: place monde ouvert du lot 0.3 (carte générée d'abord)
test-vm.cmd -Sessions collision,collision_latence
test-vm.cmd -NoVmControl -DryRun              :: test du protocole seul (sortie factice, sans Studio)
```

Rapport : `<échange>\jobs\<id>\report\report.md` (captures dans `report\screenshots\`), copie dans
`build\test-reports\latest-vm.md`. Code de sortie 0 seulement si tous les contrôles réussissent.

## Permissions et opérations des scripts

| Script | Où, avec quels droits | Ce qu'il fait | Ce qu'il ne fait jamais |
|---|---|---|---|
| `test-vm.cmd` → `host-run.ps1` | Hôte, utilisateur courant | `vmrun list/start/suspend` (sans identifiants) ; lit le `.vmx` pour signaler un partage exposant le dépôt ; `rojo build` et `lune` ; écrit dans le dossier d'échange (tâche, `setup\`) et dans `build\` ; lit les rapports de la VM **comme données** | exécuter un fichier venant du dossier d'échange ; publier une place ; toucher la souris, le clavier ou l'écran |
| `configure-share.ps1` | Hôte, utilisateur courant, **seulement avec `-Apply`** | `vmrun enableSharedFolders / addSharedFolder / setSharedFolderState` pour `aw-vm-exchange` ; `removeSharedFolder` du partage du dépôt avec `-RemoveRepoShare` | autre réglage de la VM ou de l'hôte |
| `guest-setup.ps1` | VM, PowerShell administrateur, lancé à la main | copie l'agent dans `%LOCALAPPDATA%\AutomotiveWorldTests\agent` ; tâche planifiée `AutomotiveWorldAgent` (utilisateur courant, **droits limités**, à l'ouverture de session) ; veille et économiseur d'écran de la VM désactivés ; liste les autres agents ; signale l'ancienne exclusion Defender | modifier un réglage de sécurité (antivirus, pare-feu, comptes) ; arrêter ou désactiver un agent d'un autre projet sans `-StopTasks` |
| `guest-agent.ps1` | VM, droits limités | battement de cœur ; prise de tâche ; copie d'une **liste fermée** de fichiers ; lance `job-runner.ps1` ; renvoie le rapport | lire un mot de passe ; contacter un service ; écrire hors du dossier d'échange et de `%LOCALAPPDATA%\AutomotiveWorldTests` |
| `job-runner.ps1` | VM, droits limités | lance Studio en mode script sur la place locale ; compile `ScreenCapture.cs` avec le compilateur C# de Windows vers `%LOCALAPPDATA%\AutomotiveWorldTests\bin` ; arrête seulement les processus qu'il a lancés ; copie la sortie et les journaux Studio de la tâche ; **si la tâche le demande** (`guiInput`, lot 0.9.1) démarre le pont d'entrées réelles **dans la VM** (section « Entrées réelles ») | simuler des entrées hors de la VM ou sans `guiInput` ; publier ; enregistrer la place |
| `make-report.ps1` | Hôte | transforme la sortie Studio en `report.md` | — |

Écritures de la VM, au total : `agent-heartbeat.json`, `jobs\<id>\job.claimed`, `jobs\<id>\report\` et
`jobs\<id>\done.json` dans le dossier d'échange ; `%LOCALAPPDATA%\AutomotiveWorldTests\` et les journaux Roblox
dans la VM elle-même.

## Sécurité : état et historique

- **Partage restreint** (fait le 2 novembre 2026) : la VM ne voit plus que `aw-vm-exchange` →
  `E:\ROBLOX DEV\aw-vm-exchange`, hors du dépôt (changement fait par le propriétaire dans VMware Workstation, la VM
  chiffrée refusant `vmrun` sans mot de passe), agent v2 installé par `guest-setup.ps1`.
- **Captures sans exclusion antivirus** : l'ancien script PowerShell de capture était bloqué par Windows Defender (AMSI) ;
  le propriétaire avait ajouté dans la VM une exclusion `C:\AWTests`. La capture est désormais faite par un petit
  outil compilé **dans la VM** à partir d'un source lisible (`tools\vm\ScreenCapture.cs`), exécuté depuis
  `%LOCALAPPDATA%\AutomotiveWorldTests\bin`, dossier non exclu (vérifié : 294 captures le 2 novembre 2026). L'exclusion
  `C:\AWTests` n'est donc plus nécessaire ;
  la retirer est une décision du propriétaire de la VM : `Remove-MpPreference -ExclusionPath "C:\AWTests"`
  (PowerShell administrateur, dans la VM). Si l'antivirus bloquait l'outil, les tests se dérouleraient quand même
  et le rapport l'indiquerait.
- **Autres projets** : l'agent `MimicHuntersAgent` a été arrêté et désactivé (non supprimé) le 2 novembre 2026, à la
  demande explicite du propriétaire. Les scripts actuels ne touchent plus aux agents d'autres projets sans
  `-StopTasks`. Réactivation : `Enable-ScheduledTask -TaskName MimicHuntersAgent`.
- Les mesures de la VM (GPU virtuel) ne valent pas mesure de performance.
- Aucun DataStore n'est utilisé ; la place n'est jamais publiée ni enregistrée.

## Dépannage

| Symptôme | Action |
|---|---|
| « La VM est chiffrée (TPM virtuel) » | Démarrer la VM dans Workstation, puis *Run in Background* |
| « L'agent de la VM ne répond pas » | Session Windows non ouverte, partage `aw-vm-exchange` absent, ou étape 2 non faite (ou faite depuis un autre compte) |
| Avertissement « expose le dépôt à la VM » | Lancer `configure-share.ps1 -Apply -RemoveRepoShare` |
| Délai dépassé, rapport sans sessions | Ouvrir Studio dans la VM : dialogue de mise à jour ou de connexion expirée ; voir les captures |
| Session à vrais clics sans aucun clic reçu (étalonnage incohérent) | La placer en tête de tâche (voir « Ordre des sessions ») |
| Journal de l'agent | `%LOCALAPPDATA%\AutomotiveWorldTests\agent.log` dans la VM |
