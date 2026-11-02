# Tests Roblox Studio dans la VM VMware

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

Non couvert : lecture réelle des touches et de la manette, ressenti, son (essais humains, voir `docs/lot-0.1/RAPPORT_TESTS.md`).
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
test-vm.cmd                                   :: les 6 sessions
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
| `job-runner.ps1` | VM, droits limités | lance Studio en mode script sur la place locale ; compile `ScreenCapture.cs` avec le compilateur C# de Windows vers `%LOCALAPPDATA%\AutomotiveWorldTests\bin` ; arrête seulement les processus qu'il a lancés ; copie la sortie et les journaux Studio de la tâche | simuler des entrées clavier/souris ; publier ; enregistrer la place |
| `make-report.ps1` | Hôte | transforme la sortie Studio en `report.md` | — |

Écritures de la VM, au total : `agent-heartbeat.json`, `jobs\<id>\job.claimed`, `jobs\<id>\report\` et
`jobs\<id>\done.json` dans le dossier d'échange ; `%LOCALAPPDATA%\AutomotiveWorldTests\` et les journaux Roblox
dans la VM elle-même.

## Sécurité : état et historique

- **Partage restreint** : le partage `roblox-automotive-world-starter` donne à la VM un accès en écriture à tout le
  dépôt. Les scripts sont prêts pour le seul dossier d'échange, hors du dépôt ; **au 2 novembre 2026, le changement
  de partage reste à faire à la main** dans VMware Workstation (VM chiffrée), puis `guest-setup.ps1` à relancer dans
  la VM (étapes 1 et 2 ci-dessus). Tant que ce n'est pas fait : `test-vm.cmd -Exchange "<dépôt>uildm-exchange"`.
- **Captures sans exclusion antivirus** : l'ancien script PowerShell de capture était bloqué par Windows Defender (AMSI) ;
  le propriétaire avait ajouté dans la VM une exclusion `C:\AWTests`. La capture est désormais faite par un petit
  outil compilé **dans la VM** à partir d'un source lisible (`tools\vm\ScreenCapture.cs`), exécuté depuis
  `%LOCALAPPDATA%\AutomotiveWorldTests\bin`, dossier non exclu. L'exclusion `C:\AWTests` n'est donc plus nécessaire ;
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
| Journal de l'agent | `%LOCALAPPDATA%\AutomotiveWorldTests\agent.log` dans la VM |
