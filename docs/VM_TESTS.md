# Tests Roblox Studio dans la VM VMware

Objectif : exécuter les essais du lot 0.1 **dans Roblox Studio**, avec la vraie physique et le vrai réseau,
**sans afficher de fenêtre sur ton PC ni utiliser ta souris ou ton clavier**. Tout se passe dans la VM
« ROBLOX DEV » (`E:\VMS\ROBLOX DEV\ROBLOX DEV.vmx`) ; ton PC ne fait que déposer une tâche et lire le rapport.

Même méthode que pour le projet précédent (agent dans la VM, dossier d'échange, Studio en mode script),
mais **code entièrement réécrit** pour ce projet (le cahier des charges interdit de reprendre du code d'un autre projet).

## Fonctionnement

```
Hôte (ton PC)                                   VM « ROBLOX DEV » (session ouverte automatiquement)
test-vm.cmd → tools/vm/host-run.ps1              tâche planifiée AutomotiveWorldAgent → C:\AWTests\agent\guest-agent.ps1
  vérifie que la VM tourne (vmrun list)
  attend agent-heartbeat.json        ◀──────────  battement de cœur toutes les 5 s
  rojo build → place.rbxl
  lune → driver.luau (suites Studio)
  dépose jobs/<id>/ + job.ready      ──────────▶  job.ready → job.claimed, copie locale
                                                  job-runner.ps1 : RobloxStudioBeta.exe --task RunScript …
                                                    pilote : ExecutePlayModeAsync (solo)
                                                             ExecuteMultiplayerTestAsync(2) (multijoueur, latence)
                                                  capture-screens.ps1 (optionnel) : captures de l'écran de la VM
  attend done.json                   ◀──────────  report/ (sortie Studio, journaux, captures, result.json) + done.json
  make-report.ps1 → report.md + build/test-reports/latest-vm.md
```

Dossier d'échange : `build\vm-exchange` (dans le dossier partagé `roblox-automotive-world-starter`, vu dans la VM
sous `\\vmware-host\Shared Folders\roblox-automotive-world-starter\build\vm-exchange`).

## Ce que les tests Studio vérifient réellement

Dans chaque session, une suite **serveur** et une suite **client** sont injectées dans le Studio de test (la place
n'est jamais enregistrée). La suite client conduit le vrai véhicule par le vrai chemin du jeu : invite d'embarquement,
simulation locale, forces, propriété réseau, contrôles serveur, caméra, HUD. **Seule la lecture clavier/manette est
remplacée** par un point d'accès réservé à Studio (`VehicleController.setTestInputProvider`).

| Session | Contenu |
|---|---|
| `solo` | zone et 4 véhicules posés et immobiles ; embarquement par l'invite ; 4 roues au sol ; accélération progressive et 0–100 km/h mesuré ; rapports qui montent ; sortie refusée en roulant ; freinage jusqu'à l'arrêt (distance mesurée) ; marche arrière ; virages droite et gauche (cap mesuré) ; caméra proche/lointaine ; frein à main ; remise sur roues refusée si inutile ; téléportation volontaire corrigée par le serveur ; sortie à l'arrêt ; propriété réseau = conducteur ; aucune erreur d'exécution serveur ou client |
| `multijoueur` | la même chose avec 2 clients sur 2 véhicules ; le 2ᵉ joueur ne peut pas prendre le véhicule occupé ; chacun voit l'autre conducteur ; les véhicules libres ne bougent pas |
| `latence` | `multijoueur` avec 100 ms de délai réseau demandé à Studio (`NetworkSettings.Inbound/OutboundNetworkMinDelayMs`) ; le ping réellement mesuré par chaque client figure dans le rapport |

Non couvert : lecture réelle des touches et de la manette, collisions entre véhicules, ressenti, son.

## Préparation (une seule fois)

Déjà fait lors du projet précédent : VMware Workstation, VM Windows 11 avec 3D, session ouverte automatiquement,
Roblox Studio installé et connecté avec un compte de test. Le dossier partagé pointe déjà sur ce dépôt.

1. **Démarre la VM** dans VMware Workstation. Elle est chiffrée (TPM virtuel) : `vmrun` ne peut pas la démarrer
   sans mot de passe, et aucun mot de passe n'est stocké par ces scripts.
2. **Dans la VM**, ouvre un PowerShell **administrateur** depuis le compte qui s'ouvre automatiquement, puis lance :
   ```powershell
   powershell -ExecutionPolicy Bypass -File "\\vmware-host\Shared Folders\roblox-automotive-world-starter\tools\vm\guest-setup.ps1"
   ```
   Le script refuse de s'exécuter hors d'une VM VMware. Il copie l'agent dans `C:\AWTests\agent`, crée la tâche
   planifiée `AutomotiveWorldAgent`, désactive la veille de la VM et démarre l'agent. Il n'installe rien.
   La tâche `MimicHuntersAgent` de l'autre projet n'est pas touchée.
3. Ouvre Roblox Studio une fois dans la VM pour accepter une éventuelle mise à jour ou reconnexion, puis ferme-le.
4. Ferme la fenêtre de VMware Workstation en choisissant **Run in Background** : la VM continue sans rien afficher.

## Lancer les tests (depuis l'hôte)

```bat
test-vm.cmd                         :: les 3 sessions
test-vm.cmd -Sessions solo          :: une session
test-vm.cmd -NoVmControl -DryRun    :: test du protocole seul (sortie factice, sans Studio)
```

Rapport : `build\vm-exchange\jobs\<id>\report\report.md` (captures dans `report\screenshots\`), copie dans
`build\test-reports\latest-vm.md`. Code de sortie 0 seulement si tous les contrôles réussissent.

## Limites et sécurité

- **Captures d'écran** : Windows Defender bloque la capture d'écran faite depuis PowerShell (constaté sur l'hôte le
  2 novembre 2026). Les captures sont donc **facultatives** : si elles sont bloquées dans la VM, les tests se déroulent
  quand même et le rapport indique « bloquées par l'antivirus de la VM ». Ajouter une exclusion Defender dans la VM
  (`C:\AWTests`) est possible, mais c'est ta décision.
- **Le dossier partagé donne à la VM un accès en écriture à tout le dépôt.** Pour le réduire, partage seulement
  `build\vm-exchange` (puis adapter le chemin `-Exchange` de `guest-setup.ps1`).
- Les mesures de la VM (GPU virtuel) ne valent pas mesure de performance.
- Aucun DataStore n'est utilisé ; la place n'est jamais publiée ni enregistrée.

## Dépannage

| Symptôme | Action |
|---|---|
| « La VM est chiffrée (TPM virtuel) » | Démarrer la VM dans Workstation, puis *Run in Background* |
| « L'agent de la VM ne répond pas » | Session Windows non ouverte, dossier partagé désactivé, ou étape 2 non faite (ou faite depuis un autre compte) |
| Délai dépassé, rapport sans sessions | Ouvrir Studio dans la VM : dialogue de mise à jour ou de connexion expirée ; voir les captures |
| Journal de l'agent | `C:\AWTests\agent.log` dans la VM |
