# Rapport de validation final — lot 0.1

**Date** : 2 novembre 2026 · **Branche** : `feat/vehicle-vertical-slice-0.1` · **PR** : #1 · **Version** : `0.1.0-dev`
**Commits de la finalisation** : `2573c77` (corrections), `7ae0c60` (borne d'éjection), puis documentation et
diagnostic de test (voir l'historique Git).

Ce rapport couvre la **finalisation** du lot 0.1 demandée après la première revue : collisions multijoueurs,
propriété réseau, périphériques, arbitrages A1–A6, sécurité de la VM, gouvernance. Tous les résultats viennent des
exécutions du 2 novembre 2026 (après-midi), identifiées par leur tâche. Les résultats antérieurs (214/214, tâche
`20261102-143507`) restent dans `RAPPORT_TESTS.md` et ne sont pas repris ici comme nouvelles mesures.

## 1. Synthèse et recommandation

**Recommandation : modifications supplémentaires nécessaires avant la fusion** (ne pas fusionner en l'état).

Ce qui est fait et vérifié :
- **Collisions entre joueurs** : cause mesurée et corrigée. Le véhicule conduit percuté est désormais déplacé de
  3,1 à 4,4 st au lieu de 0,08 à 1,09 st, dans la plage d'un véhicule garé, sans téléportation ni sanction (§3.1).
- **Propriété réseau** : transitions vérifiées, récupération sûre, plus de double simulation, déconnexion et
  correction testées dans Studio (§3.2).
- **Périphériques** : arbitrage clavier/manette/saisie de texte, testé hors Studio (§3.3).
- **Arbitrages A1–A6** appliqués et documentés (`ECARTS.md` §3) ; **`CLAUDE.md`** ajouté.
- Contrôles hors Studio : tous verts (§2).

Ce qui empêche de recommander la fusion :
1. **Anomalie intermittente non expliquée** (§5.1) : le serveur attribue et confirme la propriété réseau d'un
   véhicule à un client, mais ce client ne le simule pas effectivement. Observée sur le code final dans 1 campagne
   complète sur 2 (13 contrôles en échec pour un client de la session « latence »), et pendant la mise au point dans
   des essais de collision ; non reproduite lors de la dernière exécution. Elle existait déjà avant les modifications
   (tâche `164243`). Un diagnostic est maintenant enregistré automatiquement pour la capturer.
2. **Essais humains** encore à faire : clavier et manette réels, saisie dans le chat, ressenti (§4).
3. **Migration de la VM** à terminer par le propriétaire : changement de dossier partagé dans VMware Workstation
   (la VM chiffrée exige un mot de passe que les scripts ne gèrent pas), puis `guest-setup.ps1` dans la VM (§6).

## 2. Commandes exécutées hors Studio

`powershell -ExecutionPolicy Bypass -File scripts\verify.ps1 -RobloxTypes .tooling\globalTypes.d.luau`, exécuté sur le
code du commit `2573c77`, puis chaque étape relancée après `7ae0c60` et après les dernières modifications :

| Étape | Commande | Résultat |
|---|---|---|
| Build | `rojo build -o build\AutomotiveWorld.rbxlx` | OK |
| Lint | `selene src` + suites Studio | 0 erreur, 0 avertissement |
| Pilote Studio | `lune run tests/studio/build-driver.luau build\driver-check.luau` | OK, 6 sessions, compilé |
| Format | `stylua --check src tests\lune tests\studio` | OK |
| Typage strict | `luau-lsp analyze --platform=roblox … src` (définitions officielles 1.70.1) | 0 erreur (3 erreurs de typage réelles corrigées en cours de route) |
| Tests Lune | `lune run tests\lune\run.luau build\AutomotiveWorld.rbxlx` | **100 réussis, 0 échoué** (66 → 100) |
| Pytest | `python -m pytest -q tests` | **8 réussis** |
| Protocole VM | `host-run.ps1 -NoVmControl -DryRun -Exchange <temporaire>` avec l'agent v2 lancé sur l'hôte | OK (dossier d'échange hors dépôt, `setup\` publié, agent v2) |
| Outil de capture | `csc.exe … tools\vm\ScreenCapture.cs` sur l'hôte | Compile ; **non exécuté** sur l'hôte (il capturerait ton écran) |

Nouveaux tests Lune : propriété réseau vérifiée (6), arbitrage des périphériques (11), échange d'impulsion et borne
d'éjection (14), arbitrages A1/A3/A4 (3).

## 3. Essais Roblox Studio dans la VM

Exécutés par `test-vm.cmd` dans la VM VMware (Studio 0.745.0.7451137), sans toucher au poste. Les tâches marquées
« travail » ont tourné sur le code en cours, non encore commité (base `3d82eb8`).

| Tâche | Code | Sessions | Résultat | Rôle |
|---|---|---|---|---|
| `164243` | travail (avant correction) | collision ×2 | 107 ✅ / 3 ❌ | **Mesure de référence** de la cause |
| `165827` | travail | collision ×2 | 114 / 4 | 1ʳᵉ correction : Δv trop faible, échange parasite |
| `170653` | travail | collision ×2 | 112 / 6 | Δv complet mais poussée excessive (choc « élastique ») |
| `171642` | travail | collision ×2 | 111 / 7 | Restitution e = 0,3 : poussée correcte ; essai sans contact |
| `172425` | travail | 6 sessions | 323 / 4 | Collisions OK ; scénario « propriété refusée » à corriger |
| `173648` → `175452` | travail | scenarios (+ multijoueur) | 40–105 / 0–3 | Mise au point du refus de propriété ; dernière : 45 / 0 / 1 ⚠️ |
| `175728` | `2573c77` | 6 sessions | 328 ✅ / 1 ❌ / 1 ⚠️ | Éjection d'un véhicule garé (440 st) malgré la 1ʳᵉ borne |
| `180955` | `7ae0c60` | collision ×2, scenarios | 164 / 1 / 1 ⚠️ | Collisions OK ; véhicules non immobiles au départ (1 fois) |
| `181719` | `7ae0c60` | solo, scenarios | **81 / 0 / 1 ⚠️** | Départ immobile non reproduit |
| `182028` | `7ae0c60` | 6 sessions | 314 / **14** / 2 ⚠️ | **Anomalie §5.1** : un client de la session « latence » ne simule pas |
| `183321` | `7ae0c60` + diagnostic de test | latence, multijoueur, collision | **188 / 0 / 0** | Anomalie non reproduite ; diagnostic opérationnel |

Mesures de conduite (tâche `182028`, sessions saines) : 0–100 km/h ≈ 8,57 s ; 100–0 km/h ≈ 47,5 m (48,9 m sous
latence, ping mesuré 223–230 ms) ; bosse 6,5° ; slalom 0 cône déplacé ; retour au plot après 90 s. Aucune capture
d'écran : l'agent actuel de la VM (v1) ne transmet pas le source de l'outil de capture (§6).

### 3.1 Collisions entre véhicules de deux joueurs

Cause, correction et différences légitimes entre véhicule garé et véhicule conduit : **`ECARTS.md` §4**. Résumé :

| | Avant (`164243`) | Après (`180955`) |
|---|---|---|
| Percuté conduit, déplacement final (0 ms) | 0,45 / 0,65 / 0,22 st | 3,89 / 4,44 / 3,54 st |
| Percuté conduit (100 ms par sens) | 1,09 / 0,08 st (+ 1 essai sans contact) | 3,45 / 3,13 / 3,59 st |
| Percuté garé (0 ms / 100 ms) | 3,2–7,1 / 3,1–4,6 st | 3,1–7,3 / 3,3–5,6 st |
| Échanges d'impulsion confirmés serveur | — | 1 par essai « conduit », 0 « garé » |
| Corrections serveur, impulsions non constatées | 1 correction | 0 / 0 |

Tests reproductibles : sessions `collision` et `collision_latence` (6 essais chacune, critère automatique « conduit »
entre 0,5 et 2,5 fois la médiane « garé ») ; 14 tests Lune du calcul d'échange.

### 3.2 Propriété réseau (`VehicleService.setOwner`)

| Exigence | Mise en œuvre | Vérification |
|---|---|---|
| Vérifier l'attribution réelle | `NetworkOwnership.transfer` : succès seulement si `GetNetworkOwner` confirme | Lune (6 tests) ; Studio : `serveur.attribut_simulation_conforme_au_proprietaire` (0 écart sur 300 à 1 150 contrôles par session) |
| Récupération sûre si Roblox refuse | Retour au serveur, conducteur sorti du siège avec un message, sans sanction ; réaffirmation après ancrage/désancrage ; revérification toutes les 0,2 s | Studio : véhicule ancré → refus notifié, aucune conduite ni simulation client, état serveur cohérent ; puis rétabli (propriétaire = attribut = joueur) et le véhicule roule |
| Pas de double simulation | Attribut `SimulationOwnerUserId` écrit après confirmation ; le client ne simule que s'il porte son identifiant | Studio : `client.correction_simulation_suspendue_puis_reprise` dans chaque session (solo, deux joueurs, latence) |
| Embarquement, sortie, déconnexion, correction | Embarquement et sortie déjà testés ; recalage sur la position serveur à l'attribution | Studio : `serveur.deconnexion_vehicule_libere` (joueur 2 expulsé en conduisant : véhicule rendu au serveur, libre, réembarquable) |
| Contrôles serveur et tolérance à la latence conservés | `MovementRules` inchangé | Aucune correction intempestive sous ~205–230 ms de ping |

### 3.3 Périphériques

| Vérifié automatiquement (Lune, logique d'`InputArbiter`) | Non vérifiable automatiquement |
|---|---|
| Touche maintenue à l'embarquement ignorée ; rampes A2 ; stick qui dérive sans effet sur le clavier ; passage clavier ↔ manette sur commande fraîche ; un seul périphérique à la fois ; saisie de texte : clavier ignoré, touche restée enfoncée ignorée à la sortie du chat ; perte de focus : relâchement, touche « bloquée » ignorée au retour ; manette déconnectée : relâchée, message, aucune reprise automatique, pas de redémarrage à la reconnexion ; zones mortes | Lecture réelle des touches et de la manette par Roblox, détection du chat de Roblox (`GetFocusedTextBox` sur la barre de chat), déconnexion physique d'une manette, perte de focus réelle : **essais humains** (§4) |

Les actions F/R/V (et leurs boutons) sont ignorées pendant une saisie de texte (contrôle ajouté dans les
gestionnaires, en plus de celui du moteur) : vérifié par lecture du code, pas par un essai.

## 4. Essais humains encore nécessaires (aucun n'a été réalisé)

| # | Essai | Attendu |
|---|---|---|
| H1 | Conduite au clavier (Z/W, S, Q/A/D, Espace, V, R, F) | Réponse progressive, marche arrière en maintenant S à l'arrêt, sortie refusée au-dessus de 20 km/h |
| H2 | Conduite à la manette (RT, LT, stick, A, croix, Y) | Idem ; aide du HUD en mode manette |
| H3 | Clavier et manette ensemble | Le dernier périphérique sollicité pilote ; pas de cumul |
| H4 | Taper dans le chat (« z », « q », espace, « f ») en conduisant | Aucune commande ni sortie du véhicule |
| H5 | Débrancher la manette en accélérant, puis la rebrancher gâchette enfoncée | Relâchement, message ; pas de redémarrage avant un nouvel appui |
| H6 | Alt-Tab en maintenant une touche | Aucune accélération « fantôme » au retour |
| H7 | Ressenti : braquage réduit à haute vitesse (A1), rampes (A2), seuil de sortie (A4), collisions entre deux joueurs | Jugement du propriétaire |

## 5. Anomalies et limites restantes

### 5.1 Client attribué mais qui ne simule pas (intermittent, cause non établie)

- **Observations** : `164243` (avant toute modification) — collision sous latence, un essai où le percuteur voit
  un impact que le serveur ne voit pas ; `170653` et `171642` — un essai sur six par session de collision, véhicule
  du joueur 1 immobile chez lui puis corrigé (« Teleport ») ; `182028` — même chose dans la session « collision »
  (⚠️), et session « latence », client 1 : roues
  jamais au sol, vitesse nulle, téléportation de test non vue par le serveur (13 contrôles en échec), alors que le
  serveur relevait le joueur 1 comme propriétaire réseau et l'attribut comme conforme.
- **Non reproduite** dans `172425`, `175728`, `180955`, `181719`, `183321`.
- **Ce qui a été tenté** : recalage de la copie locale sur la position serveur à l'attribution (jamais déclenché),
  vérification permanente du propriétaire réseau (aucun écart relevé pendant l'anomalie).
- **Suite proposée** : le diagnostic ajouté (`diag_embarquement_*`, `diag_repos_*` : simulation active, attribut,
  ancrage local, `ReceiveAge`, écart à la position serveur, roues au sol) sera enregistré à la prochaine occurrence ;
  relancer plusieurs campagnes après la migration de la VM pour la capturer. Le cas ne peut pas être exclu en jeu réel.

### 5.2 Autres limites

- Le percuteur s'arrête net contre le véhicule d'un autre joueur (`ECARTS.md` §4.5).
- Véhicule **ancré** (cas provoqué par le test) : le personnage reste assis côté client après le refus, sans
  pouvoir conduire (⚠️ limite connue, jamais comptée comme réussie).
- Une fois (`180955`), les 4 véhicules n'étaient pas encore immobiles 4 s après le démarrage (1,04 st/s) ;
  non reproduit ensuite ; un lien avec la borne d'éjection n'est pas exclu.
- Limites antérieures inchangées : `ECARTS.md` §5.

## 6. Sécurité de la VM de test

| Exigence | État |
|---|---|
| Écritures de la VM limitées au dossier d'échange | **Scripts prêts, migration à terminer** : dossier `E:\ROBLOX DEV\aw-vm-exchange` créé hors du dépôt, `setup\` publié ; le changement de partage via `vmrun` a été **refusé** (VM chiffrée : mot de passe requis, non demandé ni stocké). À faire dans VMware Workstation, puis `guest-setup.ps1` dans la VM (`docs/VM_TESTS.md`). D'ici là, la VM garde l'accès au dépôt et les tests passent par `-Exchange <dépôt>\build\vm-exchange` |
| Pas de modification automatique du dépôt depuis la VM | L'hôte n'exécute rien qui vienne du dossier d'échange (rapports lus comme données) ; effectif une fois le partage du dépôt retiré |
| Agents d'autres projets | `guest-setup.ps1` ne touche plus aucun autre agent sans `-StopTasks Nom`. `MimicHuntersAgent` reste désactivé (fait plus tôt, à la demande explicite du propriétaire) ; réactivable : `Enable-ScheduledTask -TaskName MimicHuntersAgent` |
| Permissions et opérations documentées | `docs/VM_TESTS.md`, tableau « Permissions et opérations des scripts » |
| Exclusion Defender `C:\AWTests` | **Plus nécessaire avec le nouvel agent** : capture par un outil compilé dans la VM depuis `ScreenCapture.cs`, exécuté hors du dossier exclu. **Non encore vérifié dans la VM** (l'agent v1 ne transmet pas ce source : 0 capture lors de ces campagnes). Retrait de l'exclusion : décision du propriétaire, après une campagne avec captures sous l'agent v2 |
| Aucun autre réglage de sécurité modifié | Aucun |
| Aucune publication Roblox | Aucune (Studio ouvre un fichier local en mode script) |

## 7. Fichiers modifiés par la finalisation

- **Nouveaux** : `CLAUDE.md`, `src/server/Vehicles/{NetworkOwnership, CollisionMediator}.luau`,
  `src/shared/Vehicles/Physics/CollisionExchange.luau`, `src/client/Vehicles/InputArbiter.luau`,
  `tests/lune/specs/{NetworkOwnershipSpec, InputArbiterSpec, CollisionExchangeSpec}.luau`,
  `tools/vm/{ScreenCapture.cs, configure-share.ps1}`, `docs/lot-0.1/RAPPORT_VALIDATION.md`.
- **Modifiés** : `VehicleService`, `VehicleController`, `DriverInput`, `VehicleConstants`, `VehicleTypes`,
  `VehicleDefinitions`, `Messages` ; suites Studio (`ServerSuite`, `ClientSuite`, `ScenarioServer`, `ScenarioClient`,
  `build-driver`) ; `tests/lune/run.luau`, `specs/Definitions.luau` ; `tools/vm/{host-run, guest-agent, guest-setup,
  job-runner}.ps1` ; `README.md`, `docs/{ARCHITECTURE, VM_TESTS}.md`, `docs/lot-0.1/{ECARTS, RAPPORT_TESTS,
  PROPOSITION_LOT_0.2}.md`.
- **Supprimé** : `tools/vm/capture-screens.ps1` (capture PowerShell bloquée par l'antivirus).
