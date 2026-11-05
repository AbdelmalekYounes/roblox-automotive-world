# QA-A24 — banc des 18 modèles à 10 / 18 : diagnostic par lecture du code

Étape 2 de l'option B (`AUDIT_INTEGRATION_V1.0.md` §6.2), demandée par le propriétaire le 2026-11-05 (« Oui, dans le
code »). **Aucune exécution** : lecture du code et des rapports VM déjà présents dans `aw-vm-exchange/jobs/`.
**Cause non établie** ; un essai manuel court permet de trancher (§4).

## 1. Faits relevés dans les rapports existants

| Tâche | Commit | Banc |
|---|---|---|
| 20261104-001121 | `9b0eebd` | 18 / 18 |
| 20261104-042820 | `c352f26` (lot 0.9.2) | 18 / 18 |
| 20261105-132615 | `bcfbae6` (UI) | 10 / 18 |
| 20261105-141629 | `84cefab` (Comète) | 10 / 18 |

1. **Ce n'est pas une question de modèle.** Dans l'ordre du banc (`WorkingCatalog.Specs`), les 10 premiers passent
   (Pixel, Brio, Fil, Aster, Nova, Cadence, Lumen, Orée, Brise, Rafale), puis **les 8 suivants échouent tous** (Éclat,
   Mistral, Comète, Zénith, Dune, Vigie, Sentier, Atlas). Un état se dégrade pendant la séance, à partir de la 11ᵉ
   itération.
2. **Refus silencieux du serveur.** Diagnostic de chaque échec : « notification aucune ; invite true ; distance porte
   1,7 à 2,7 st, centre 4,9 à 5,6 st ; siège occupé false ; joueur assis false ; conducteur 0 ». Le serveur n'a envoyé
   aucun message de refus (« VehicleBusy », « VehicleNotYours », « VehicleUnavailable »).
3. **Le dernier succès finit par un choc dont l'ordre a changé.** Journal de `20261105-141629` : le résultat de la Rafale
   est écrit à 233,7 s, **puis** « Choc confirmé sur Perso_BANC-wk_rafale : zone Left, Δv 14,9 m/s, niveau 3, mécanique
   true, obstacle MuretNord ». Au lot 0.9.2 (`20261104-042820`), le même choc (Left, Δv 15,7 m/s) est écrit **avant**
   le résultat de la Rafale, et l'Éclat s'embarque ensuite normalement. Le choc de l'Orée (8ᵉ, avant son résultat)
   n'empêche pas la Brise ni la Rafale de s'embarquer. L'ordre des lignes serveur et client dans la sortie de Studio
   n'est pas une preuve de chronologie : c'est un indice, pas un fait établi.

## 2. Chemin d'embarquement relu

- Banc (`tests/studio/Lot08Client.client.luau`, `board`) : personnage placé 2 st au-dessus de l'attache `DriverDoor`,
  `EnterPrompt:InputHoldBegin()`, attente de `DriverUserId` 5 s, trois tentatives. Sortie par `leave()` :
  `Humanoid.Sit = false` et saut, côté client.
- Serveur (`src/server/Vehicles/VehicleService.luau`, `onPromptTriggered`) : **six sorties silencieuses** (aucune
  notification) avant `Seat:Sit(humanoid)` :
  1. `recordByDriver[player] ~= nil` (le joueur passe encore pour conducteur d'un autre véhicule) ;
  2. `os.clock() < record.CorrectionUntil` ;
  3. personnage absent ;
  4. humanoïde absent, mort, ou `SeatPart ~= nil` côté serveur ;
  5. `HumanoidRootPart` absente ;
  6. distance au centre > 16 st.

  Puis `Seat:Sit(humanoid)` peut lui-même ne pas aboutir sans erreur (humanoïde qui n'entre pas dans l'état assis).

## 3. Ce qui est écarté, et ce qui reste

**Écarté par la lecture :**
- **Géométrie des modèles** : les mêmes modèles passaient en 0.9.2, et l'échec suit l'ordre, pas le modèle.
- **Distance** : centre à 5 st, sous la limite de 16.
- **Fuite de `recordByDriver` au retrait du véhicule** : `despawnPersonal` appelle `releaseDriver`, qui vide l'entrée.
- **Changements de `DamageService`** (dans l'intervalle) : marques sur les kits, optiques, emprise de recherche ; rien ne
  touche le joueur ni le siège.
- **Pose assise** (`SeatPoseController`) : n'agit que sur les sièges `AWSeatPose` (Comète) et ne change aucun état de
  l'humanoïde.
- **Harnais du banc** : `Lot08Client` et `Lot08Server` n'ont pas changé dans l'intervalle.

**Reste possible (non départagé) :**
- **H1 — état du personnage après une sortie pendant ou juste avant un choc** : humanoïde bloqué dans un état qui
  refuse l'assise, ou vu « assis » par le serveur. Code concerné : les sorties de `a0debec` (groupe de collision
  `AWSortie`, `setExiting`, `placeBeside`).
- **H2 — état du joueur côté serveur** qui survit au personnage : `recordByDriver` rempli par un autre chemin que le
  retrait.
- **H3 — l'invite ne déclenche plus `Triggered` sur le serveur** : invite affichée côté client, mais refusée par le
  moteur.

Remarque de conception, indépendante de la cause : ces refus **silencieux** laissent un vrai joueur appuyer sur E sans
aucun retour. À corriger (notification ou journal) une fois la cause connue, sur ton accord.

## 4. Essai manuel proposé (environ 10 minutes, dans Studio)

Construire la place de la branche `feat/ui-premium-v1.2-v2` (`rojo build default.project.json -o build\AutomotiveWorld.rbxlx`),
l'ouvrir et cliquer sur Jouer.

Faire apparaître un véhicule :
- onglet **Test**, bouton **Current: Client** basculé sur **Server** ;
- dans la barre de commande : `print(game.ServerStorage.AWRevue:Invoke("wk_eclat"))` ;
- revenir sur **Client** pour conduire.

1. **Témoin.** Monter dans l'Éclat avec E. Attendu : ça marche, ce qui confirme que le modèle n'est pas en cause.
2. **Reproduction.**
   - Faire apparaître la Rafale (`"wk_rafale"`).
   - La lancer à plus de 50 km/h contre un mur.
   - Sortir **au moment du choc**, avec Espace (saut) ou F.
   - Faire apparaître l'Éclat, puis essayer d'y monter avec E (trois essais).
3. **Si la montée échoue**, côté **Server**, coller :
   `local p=game.Players:GetPlayers()[1] local h=p.Character:FindFirstChildOfClass("Humanoid") print("vie",h.Health,"assis",h.SeatPart,"etat",h:GetState(),"groupe",p.Character.HumanoidRootPart.CollisionGroup)`.
   Faire la même chose côté **Client**, puis noter les deux lignes et toute erreur rouge de la sortie.
4. **Toujours en cas d'échec** : réinitialiser le personnage (Échap, puis Réinitialiser), puis réessayer de monter dans
   l'Éclat.
   - Si ça remarche : l'état est lié au **personnage** (H1).
   - Si ça échoue encore : l'état est lié au **joueur** côté serveur (H2), ou à l'invite (H3).
5. **Si l'étape 2 ne reproduit pas** : le dire. Je proposerais alors une session VM ciblée avec un journal des sorties
   silencieuses (sur ton accord, par exception à l'arrêt des tests automatiques).

## 5. Résultat de l'essai du propriétaire (2026-11-05)

Essai manuel du propriétaire dans Studio, place de `feat/ui-premium-v1.2-v2` (`9caba94`), véhicules apparus par
`ServerStorage.AWRevue` :
- témoin : Mistral (boîte automatique, l'un des 8 modèles en échec au banc), montée et conduite **OK** ;
- Rafale lancée contre un mur, sortie au moment du choc, puis Mistral : **montée OK**.

**La reproduction échoue** : un humain monte normalement dans un modèle « en échec » après une sortie pendant un choc.
H1, sous la forme essayée, n'est pas confirmée. Restent possibles :
- un état qui s'accumule seulement sur une longue séance (11 véhicules à la suite) ;
- un artefact du chemin propre au banc (téléportation du personnage par le client, sortie par `Humanoid.Sit = false`,
  invite déclenchée par script), révélé par les changements de l'intervalle.

Impact joueur : non constaté à ce jour, sur un seul essai humain.

## 6. Session VM ciblée (2026-11-05, accord du propriétaire)

Commande : `toolsm\host-run.ps1 -Sessions lot08 -NoVmControl -TimeoutSec 2700`, lancée depuis la branche de diagnostic
`diag/qa-a24` (commit `3247a39`, issu de `feat/ui-premium-v1.2-v2` ; journal TEMPORAIRE de chaque refus silencieux
dans `onPromptTriggered` et `onOccupantChanged`, diagnostic du banc enrichi). Tâche **20261105-183402** : 26 réussis,
2 échecs (le volant du cockpit, déjà connu, et le banc).

Résultats mesurés :

- **Banc 13 / 18** (contre 10 / 18 dans les deux tâches précédentes).
- Échecs : Éclat, Mistral, Comète, Zénith, Sentier. Dune, Vigie et Atlas, en échec la fois précédente, passent.
- Pour **chaque montée réussie** (14 véhicules, dont celui de l'essai de l'arrivée) : « invite déclenchée », puis
  « après Sit (1 s) : occupant true ; état Seated ; conducteur youyou31110 ».
- Pour **chaque échec** : **aucune ligne « invite déclenchée »**. Le serveur n'a jamais reçu l'invite ; aucune des
  sorties silencieuses du serveur n'est en cause.
- Côté client, au moment de l'échec : invite active ; personnage en état Running ; groupe de collision Default ; non
  ancré ; à 2,0 à 2,7 st de la porte.

Conclusions :

1. **H1 et H2 sont écartées** : le serveur n'a pas reçu l'invite, et l'état du personnage est normal.
2. **H3 est confirmée** : l'activation **par script** de l'invite (`InputHoldBegin`) n'aboutit pas pour ces modèles.
3. Ce n'est pas une dégradation au fil de la séance. Les échecs dépendent du modèle : l'Éclat, la Mistral, la Comète et
   le Zénith échouent dans les deux tâches, les grands SUV seulement parfois. L'ordre du banc mettait les petits
   modèles en premier.
4. Avec la vraie touche E, le propriétaire monte normalement dans la Mistral (essai du §5). **Aucun défaut du jeu
   n'est constaté** : c'est un **défaut du banc**, révélé par les changements de l'intervalle.

Mécanisme exact **non établi**. Piste principale : les corps humains imposés à tous les joueurs depuis la phase 1 de
l'Aster (`fe89f7e`, `284ce4b`) changent la taille du personnage. Le banc le pose « 2 st au-dessus de la porte » puis
déclenche l'invite par script ; l'invite ne serait alors pas encore « affichée » côté client. Autre piste : la priorité
entre invites de même touche (E).

Proposition : corriger le banc (attendre que l'invite soit affichée par `ProximityPromptService.PromptShown`, journaliser
l'invite affichée), puis le rejouer une fois pour confirmer. Le journal temporaire reste sur la branche locale
`diag/qa-a24`, qui n'est ni poussée ni fusionnée.

