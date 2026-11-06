# Lot PHONE-01 — Téléphone tenu en main : rapport

- **Demande du propriétaire** : « lorsque l'on appuie sur la touche du téléphone, il faudrait idéalement que le
  personnage le tienne comme dans la vraie vie, que ça fasse un zoom dessus dans sa main, et qu'on puisse utiliser le
  téléphone directement depuis la main du personnage au lieu de juste afficher un menu sur l'écran ».
- **Branche** : `claude/phone-01-telephone-en-main-ed35ff`, créée depuis `main` d295473 (vérifié par `git log -1`).
- **Contexte** : 2e vague en parallèle d'ANIM-01 (exception du propriétaire du 2026-11-06, fichiers disjoints). Rien
  n'a été poussé ; ni pull request ni fusion (session de coordination). Aucune publication Roblox.
- **Date** : 2026-11-06.
- **État** : code et tests hors Studio terminés ; **rien n'a été essayé en jeu** (tout le §6 est NON TESTÉ).

## 1. Décisions

### 1.1 Posées au propriétaire en une fois (2026-11-06)

| Question | Décision |
| --- | --- |
| Rendu de l'interface « dans la main » | **Calée sur l'écran 3D** (recommandée) : l'interface existante est redessinée à chaque image exactement sur la dalle du modèle tenu en main (la main, la coque et le décor restent visibles autour). Souris, tactile, manette et défilement fonctionnent comme avant, texte net. (Écartée : `SurfaceGui` collée sur la pièce, texte moins net et manette incertaine.) |
| Repli plein écran | **Réglage Auto / En main / Classique** (recommandé), dans téléphone > Paramètres > Interface, enregistré avec les préférences. Auto = en main sauf disposition compacte (petit écran, mobile), où l'ancien téléphone dans le coin reste plus lisible. |
| À pied pendant l'usage | **Le personnage s'arrête** (recommandé) : commandes de marche suspendues, rendues au rangement. |
| En voiture qui roule | **Zoom aussi en roulant** (choix du propriétaire, différent de la recommandation) : le conducteur zoome sur le téléphone même en roulant ; l'écran montre alors le **mode rapide** existant (lecture, réglages rapides, sans sélection manette), l'écran complet revenant à l'arrêt comme avant. |

### 1.2 Choix par défaut pris dans le lot (à confirmer ou corriger en jeu)

- **Main droite** (comme avant). Le bras gauche n'est pas piloté par ce lot (voir §4).
- **Modèle 3D original en pièces simples** créé par le serveur (aucun actif importé, aucune marque, aucun logo) :
  boîtier graphite aux coins arrondis, vitre noire, dalle, bloc photo au dos, touches latérales. ≈ 7,5 × 15,2 × 0,8 cm.
- **Zoom** : 0,35 s aller et retour (0,05 s avec « Réduire les animations »), champ de vision 40°, écran occupant
  84 % de la hauteur de la vue ; le bouton « + » du téléphone le rapproche (94 %) au lieu d'agrandir la coque.
- **Passager** : règles inchangées (mode rapide en roulant, écran complet à l'arrêt), avec zoom.
- **Arrêt à pied** seulement en affichage « en main » ; en affichage classique, la marche reste libre comme avant.
- **Rangement fluide** : le téléphone reste en main pendant le retour de la caméra, puis le serveur le range.

## 2. Fonctionnement

### 2.1 Tenue du téléphone (vue par tous)

- À l'ouverture (T, manette X), le serveur crée le modèle (`InterfaceService.makePhone`) et le soude à `RightHand`
  par une `Weld` dont le décalage est la **prise en main** partagée (`PhoneHold.Grip`), puis pose l'attribut
  `AWPhoneRaised` du personnage.
- Chaque client lève le bras de **tous** les personnages portant l'attribut (`PhoneHoldController`, `PreSimulation`) :
  épaule (65° vers l'avant, 45° vers l'axe du corps) et coude (55°) multipliés dans `Transform` après l'animation,
  Motor6D comme AnimationConstraint (méthode QA-A10). Montée / descente en 0,3 s.
- Assis (conducteur, passager), la pose assise d'ANIM-01 (`SeatPoseController`) laisse les bras dès que l'attribut est
  posé (règle existante, `SeatPose.ArmJoints`, non modifiée) : c'est ce lot qui pilote alors le bras droit.
- L'ancien réglage C0 du Motor6D côté serveur (lot 0.7) est **retiré** : il se serait ajouté à la pose du client.
- Les autres joueurs voient un **écran générique** (fond et heure) : le contenu des applications n'est affiché que
  chez l'utilisateur.
- La pose et la prise en main ont été calculées sur un gabarit R15 « bloc » aux cotes approchées (test Lune) :
  écran tourné vers les yeux à moins de 10°, à ≈ 30 cm, regard ≈ 35° vers le bas, haut de l'écran vers le haut.

### 2.2 Zoom et interface « en main » (joueur local)

- **Au volant** : visée imposée de la caméra du véhicule (`VehicleController.getCamera():setLookOverride`, CAMERA-01),
  y compris en roulant ; retirée au rangement (et automatiquement en fin de conduite).
- **À pied et passager** (caméra Roblox par défaut) : la caméra est prise (`Scriptable`) le temps de l'usage, puis
  rendue à la place qu'elle occupait **par rapport au personnage** (correct aussi dans un véhicule qui roule), avec
  son type et son champ de vision d'origine.
- Position de la caméra : sur la normale de l'écran, à la distance qui donne la hauteur voulue ; l'écran se projette
  alors en rectangle centré exact. L'interface (même code qu'avant, sans la coque dessinée) est posée sur ce rectangle
  à chaque image, une fois le zoom arrivé à 98 %.
- Pendant le zoom : bras droit, main et téléphone restent visibles localement (même en vue cockpit, où le personnage
  est masqué) ; la tête et ses accessoires sont masqués localement au-delà de la moitié du zoom (la caméra passe
  devant le visage). Valeurs d'origine rétablies au retour.
- Souris libérée pendant l'usage (elle restait bloquée au centre en vue à la première personne).
- **Replis** : affichage classique si le réglage le demande, en disposition compacte (Auto), ou si le modèle du
  serveur n'arrive pas dans les 2 s (personnage sans main droite…). Changer le réglage pendant l'usage bascule
  aussitôt, sans ranger le téléphone.

### 2.3 Interface pour les autres lots

- `VehicleController.isDriving(): boolean` (ajout) : vrai pendant une session de conduite.
- `PhoneHold` (module pur partagé) : cotes, pose du bras, prise en main, cadrage, choix d'affichage.

## 3. Fichiers

| Fichier | Rôle |
| --- | --- |
| `src/shared/UI/PhoneHold.luau` (nouveau) | Module **pur** : cotes du modèle, pose du bras, prise en main, cadrage, rectangle de l'interface, choix d'affichage, arrêt à pied. |
| `src/client/UI/PhoneHoldController.luau` (nouveau) | Bras de tous les personnages ; zoom (véhicule ou caméra par défaut) ; transparences locales ; marche suspendue ; rectangle de l'écran. |
| `src/client/UI/PhoneController.luau` | Affichage en main / classique, placement de l'interface sur l'écran 3D, « + » = rapprocher, réglage « Affichage du téléphone », rangement après le retour de la caméra ; ancien bras levé déplacé dans `PhoneHoldController`. |
| `src/server/Social/InterfaceService.luau` | Nouveau modèle 3D, soudure de prise en main, réglage C0 retiré. |
| `src/shared/UI/Preferences.luau` | Ajout `Phone = { Display = "Auto" }` et `Preferences.PhoneDisplays` (défaut, nettoyage). Profil existant : défaut appliqué, pas de migration, `Version` inchangée. |
| `src/shared/UI/Localization.luau` | Section PHONE-01 : 5 clés FR / EN. |
| `src/client/Vehicles/VehicleController.luau` | Ajout seulement : `VehicleController.isDriving()`. |
| `tests/lune/specs/Phone01.luau` (nouveau), `tests/lune/run.luau` | 8 tests hors Studio (une ligne ajoutée dans `run.luau`). |
| `tests/lune/specs/Lot092Stabilization.luau` | Test QA-A10 suivi dans le nouveau fichier (bras posé par `PhoneHoldController`, attribut inchangé). |

Non touchés : `SeatPose.luau`, `SeatPoseController.luau` (ANIM-01), `src/client/Audio/*` (AUDIO-03), `README.md`,
`docs/ROADMAP.md`, `docs/QA_BACKLOG.md`, `docs/CREDITS_ACTIFS.md`, `AssetManifest.luau`.

## 4. Limites connues et points pour les autres lots

- **Gabarit approché** : la prise en main est calculée sur des cotes R15 « bloc » approchées. Sur des avatars très
  différents (Rthro, silhouettes du jeu), le téléphone peut être un peu décalé dans la main ou moins bien tourné vers
  le visage. Le zoom, lui, suit toujours l'écran réel : l'interface reste lisible. Réglage éventuel :
  `PhoneHold.Arm` et `PhoneHold.Grip` (valeurs seulement).
- **Bras gauche au volant** : quand le téléphone est sorti, `SeatPoseController` laisse les **deux** bras ; le bras
  gauche reprend la pose assise du moteur (pas sur le volant). À traiter par ANIM-01 s'il le souhaite (par exemple
  garder `LeftShoulder` / `LeftElbow` sur le volant quand seul le bras droit tient le téléphone) ; non modifié ici.
- **Visibilité en cockpit** : ce lot n'utilise pas `setCharacterVisibilityFilter` (réservé à ANIM-01) ; il écrit
  directement `LocalTransparencyModifier` du bras droit et du téléphone pendant le zoom, puis rétablit les valeurs
  d'origine. Si la vue est changée (touche V) pendant l'usage, l'état d'affichage du personnage peut rester celui
  d'avant le changement jusqu'au prochain changement de vue (non vérifié).
- **Entrer dans un véhicule pendant l'usage à pied** (rare : le personnage est arrêté) : la caméra est rendue sans
  fondu à celle du véhicule ; son champ de vision d'origine est rétabli en fin de conduite.
- **Conducteur en roulant** : l'écran du téléphone occupe la vue (choix du propriétaire) ; la route n'est visible
  qu'autour du téléphone.
- **Transition** : pendant les 0,35 s du zoom, l'écran 3D montre le fond générique ; l'interface apparaît à
  l'arrivée (pas de fondu d'opacité : un `CanvasGroup` aurait rendu le texte flou).
- **Autres joueurs** : le bras est posé par chaque client ; un client qui n'anime plus un personnage lointain
  (animation non réévaluée) garde la pose sans cumul (même protection que QA-A10).

## 5. Vérifications exécutées (2026-11-06, tâche PHONE-01)

- `scripts\verify.ps1 -DownloadRobloxTypes` (2026-11-06, 3e exécution, sur le code livré) : **toutes les étapes OK**
  — Rojo build, Selene 0 erreur, pilote Studio (génération + compilation), StyLua, **Lune 439 réussis / 0 échoué**,
  carte du monde ouvert, Rojo build monde ouvert, **pytest 23 réussis**, **luau-lsp strict 0 erreur** (aucun
  avertissement sur les fichiers du lot). Les deux exécutions précédentes avaient échoué (formatage StyLua, puis
  2 erreurs de typage luau-lsp), corrigées avant la 3e.
- Place de test : `rojo build default.project.json -o build/AW-PHONE-01.rbxlx` (reconstruite le 2026-11-06 à
  01:57 sur le code livré ; fichier ignoré par git).
- Tests Lune ajoutés (`Phone01`, 8 tests) : cotes du modèle ; écran tourné vers les yeux sur le gabarit approché ;
  bornes des décalages du bras ; cadrage exact (projection perspective du coin de la dalle) et rectangle de
  l'interface ; choix Auto / En main / Classique et arrêt à pied ; préférence nettoyée ; textes FR / EN ; branchements
  dans les sources (soudure, visée imposée, caméra rendue, aucun actif importé).
- **Aucun essai en jeu, aucun test VM** (règle du 2026-11-05 : le propriétaire teste lui-même).

## 6. Liste de vérification en jeu (NON TESTÉ — à faire par le propriétaire)

Place : `build/AW-PHONE-01.rbxlx`. Réglage par défaut « Auto » ; fenêtre de taille normale (pas compacte).
Sauf mention, la touche est T (manette : X).

### 6.1 À pied

1. Appuyer sur T : le bras droit se lève, un téléphone graphite apparaît dans la main droite, la caméra zoome en
   ≈ 0,35 s sur son écran ; l'interface (accueil, icônes, dock) apparaît **exactement sur l'écran** du téléphone,
   la main et la coque visibles autour. Noter si le téléphone est mal placé dans la main ou mal tourné.
2. Le personnage ne marche plus (ZQSD / stick gauche, saut) tant que le téléphone est ouvert.
3. Ranger (T, ×, ou Retour / B) : l'interface disparaît, la caméra revient en douceur **à sa place d'avant**, puis le
   téléphone disparaît et le bras redescend ; la marche revient.
4. Recommencer en vue à la première personne (molette à fond) : la souris est libre pour toucher l'écran ; retour en
   première personne au rangement.
5. Bouton « + » : l'écran se rapproche ; à nouveau : il revient.
6. Ouvrir / fermer très vite plusieurs fois : pas de caméra bloquée, pas de téléphone resté en main.

### 6.2 Chaque application (en main, à l'arrêt)

7. Carte (ouvre la grande carte), Véhicules, Propriétés, Missions, Courses, Marché, Social, Radio, Photo (ouvre le
   mode photo), Guide, Paramètres (toutes les pages, réglage « Affichage du téléphone »), Notifications : contenu
   lisible, défilement, boutons, barre d'accueil, retour.

### 6.3 Entrées

8. Souris : clic sur les icônes et boutons, molette dans les listes.
9. Manette : focus visible sur une icône à l'apparition de l'interface, navigation à la croix / stick, A pour
   activer, B pour revenir / fermer.
10. Tactile (émulateur Studio, appareil en paysage) : en Auto, l'affichage **classique** est attendu en disposition
    compacte ; forcer « En main » et vérifier toucher et glisser sur l'écran du téléphone.

### 6.4 Conducteur

11. À l'arrêt au volant, T : bras droit levé (bras gauche : pose assise du moteur, voir §4), zoom sur l'écran dans
    chaque vue (Proche, Lointaine, Cockpit, Capot, Pare-chocs) ; en cockpit, bras droit et téléphone visibles.
12. Démarrer et rouler téléphone ouvert : zoom conservé, l'écran passe en **mode rapide** ; la conduite répond
    normalement (aucun freinage) ; à l'arrêt, l'écran complet revient.
13. Ouvrir le téléphone **en roulant** : même zoom, mode rapide.
14. Ranger : retour à la vue de conduite et au regard libre (clic droit) ; personnage à nouveau masqué en cockpit.
15. Sortir du véhicule téléphone ouvert : la caméra passe à la vue à pied, toujours zoomée sur l'écran ; ranger.

### 6.5 Passager

16. Assis passager, à l'arrêt puis en roulant : bras levé, zoom sur l'écran (mode rapide en roulant), retour de la
    caméra à sa place autour du personnage au rangement, même si le véhicule a avancé.

### 6.6 Vu par un autre joueur (deux clients Studio)

17. Le second joueur voit le bras levé, le téléphone dans la main (à pied, conducteur, passager) avec un écran
    générique (fond et heure) — **jamais** le contenu des applications ; le bras redescend au rangement.

### 6.7 Réglage et replis

18. Paramètres > Interface > « Affichage du téléphone » : Auto → En main → Classique ; en Classique, l'ancien
    téléphone dans le coin revient (le personnage tient toujours le téléphone, pas de zoom, marche libre) ; le
    changement s'applique sans fermer le téléphone ; le réglage est conservé après reconnexion.
19. « Réduire les animations » (Accessibilité) : zoom quasi instantané.
20. Langue EN : libellés du réglage traduits.
