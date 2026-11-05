# Lot CAMERA-01 — Caméra libre en conduite : rapport

- **Demande du propriétaire** : « ajouter la possibilité de bouger la caméra quand on conduit (pour pouvoir regarder
  autour) et qu'elle ne reste pas fixe ».
- **Branche** : `claude/camera-01-camera-libre-5d3237`, créée depuis `main` 6a54046 (vérifié par `git log -1`).
- **Contexte** : lot réalisé en parallèle de BRIO-02 et AUDIO-03 (exception accordée par le propriétaire le 2026-11-06),
  sur des fichiers disjoints. Rien n'a été poussé ; ni pull request ni fusion (session de coordination).
- **Date** : 2026-11-06.

## 1. Décisions du propriétaire (2026-11-06)

Questions posées en une fois au début du lot ; les quatre recommandations ont été retenues.

| Question | Décision |
| --- | --- |
| Regard à la souris | **Clic droit maintenu** + déplacement de la souris. Le curseur est figé sur place pendant l'appui puis rendu tel qu'il était ; aucun conflit avec les clics d'interface (bouton gauche). |
| Retour au centre | La vue reste **1,5 s** après le relâchement puis revient en **≈ 0,7 s** ; dès **15 km/h**, elle revient après **0,4 s**, en **≈ 0,4 s**. |
| Limites d'angle | « Réalistes » : vues embarquées (cockpit, capot, pare-chocs) **±120°** à gauche / droite, **−40° à +30°** bas / haut ; vues de poursuite : **orbite 360°**, caméra abaissée de 10° au plus et montée de 60° au plus, sans traverser les murs. |
| Réglages du joueur | **Sensibilité 1 à 5** (défaut 3) et **inversion verticale**, dans téléphone > Paramètres > Commandes, enregistrées avec les autres préférences. |

## 2. Fonctionnement

- **Toutes les vues** (touche V / croix haut inchangée) : Proche, Lointaine, Cockpit, Capot, Pare-chocs.
  - Vues embarquées : la « tête » tourne sur place (lacet puis tangage dans le repère du véhicule).
  - Vues de poursuite : la caméra tourne autour du véhicule ; regarder vers le haut l'abaisse, vers le bas l'élève
    (comme la caméra Roblox à pied). Le rayon anti-traversée existant s'applique toujours.
  - Changer de vue remet le regard droit devant. Regard nul = exactement les vues d'avant le lot.
- **Commandes** :
  - souris : clic droit maintenu + déplacement (0,25° par pixel à la sensibilité 3) ;
  - manette : stick droit (zone morte 0,15, courbe quadratique, 150°/s à fond à la sensibilité 3) ;
  - tactile : un doigt glissé sur une zone libre de l'écran (0,35° par pixel), jamais sur un bouton.
  - Sensibilité : facteurs ×0,5 / ×0,75 / ×1 / ×1,4 / ×2 (niveaux 1 à 5).
- **Retour au centre** : tant que le joueur « tient » le regard (clic droit enfoncé, doigt posé, stick hors zone
  morte), la vue ne revient pas, même en roulant. Après relâchement : délai puis retour exponentiel, indépendant de la
  cadence d'image ; en orbite, toujours par le chemin le plus court.
- **Aucune perte de contrôle** : le regard n'utilise aucune entrée de conduite (clavier ZQSD / flèches, gâchettes,
  stick gauche, boutons) et ne touche ni à la simulation ni aux commandes envoyées au serveur. Aucune donnée réseau
  nouvelle.
- **Interfaces** : dès qu'un écran est ouvert (téléphone, carte, garage, économie, courses, accueil, mode photo, menu
  d'administration F2) ou qu'un texte est saisi (chat), le regard est suspendu : clic droit relâché, souris rendue
  dans son état précédent, déplacements en attente jetés. Il faut un nouvel appui pour reprendre. Un clic droit sur
  un élément d'interface n'est jamais pris par la caméra. Perte de focus de la fenêtre : regard relâché.
- **Audio** : le nom de vue « Cockpit » est conservé (égaliseur d'habitacle d'AUDIO-01, `data.CameraName`).

## 3. Fichiers

| Fichier | Rôle |
| --- | --- |
| `src/shared/Vehicles/FreeLook.luau` (nouveau) | Module **pur** : limites, sensibilité, inversion, zone morte, retour au centre, fondu d'une visée imposée. |
| `src/client/Vehicles/FreeLookInput.luau` (nouveau) | Lecture souris (clic droit), stick droit, doigt ; suspension et restitution de la souris. |
| `src/client/Vehicles/VehicleCamera.luau` | Regard appliqué aux deux familles de vues ; interface de la 2e vague (§4). |
| `src/client/Vehicles/VehicleController.luau` | Ajout seulement : `VehicleController.getCamera()`. |
| `src/shared/UI/Preferences.luau` | Ajout de `Camera = { Sensitivity, InvertY }` (défauts, bornes, nettoyage). Un profil existant reçoit les défauts : pas de migration, `Preferences.Version` inchangée. |
| `src/client/UI/PhoneController.luau` | Page Paramètres > Commandes : section « Caméra en conduite » (2 réglages). |
| `src/shared/UI/Localization.luau` | Section CAMERA-01 : 3 clés FR / EN. |
| `src/client/UI/DevHud.luau` | Aide des touches du HUD de développement : clic droit / stick droit. |
| `tests/lune/specs/Camera01FreeLook.luau` (nouveau), `tests/lune/run.luau` | 15 tests hors Studio (ajout d'une ligne dans `run.luau`). |

Fichiers des autres lots non touchés : `src/client/Audio/*`, `Transmission.luau`, `MeshKitData.luau`,
`SeatPose.luau` ; ni `README.md`, `docs/ROADMAP.md`, `docs/QA_BACKLOG.md`, `docs/CREDITS_ACTIFS.md`.

## 4. Interface pour la 2e vague (posée, documentée, non utilisée par le jeu dans ce lot)

L'instance s'obtient par `VehicleController.getCamera()` (instance unique, valable d'une session de conduite à
l'autre).

```lua
-- Visée imposée (ex. téléphone tenu en main, regard vers une portière) :
camera:setLookOverride({
    Target = function(): CFrame? -- relue à chaque image ; nil = garder la dernière visée
        return phoneHandle.CFrame * CFrame.new(0, 0, 1.2) -- exemple
    end,
    Fov = 40,      -- facultatif : champ de vision imposé (degrés)
    BlendS = 0.35, -- facultatif : durée du fondu aller / retour (s)
})
camera:setLookOverride(nil) -- retour à la vue normale sur la même durée
camera:hasLookOverride() --> boolean

-- Bras / mains visibles en vue cockpit (par défaut tout le personnage est masqué localement) :
camera:setCharacterVisibilityFilter(function(part: Instance): boolean
    return string.find(part.Name, "Arm") ~= nil or string.find(part.Name, "Hand") ~= nil
end)
camera:setCharacterVisibilityFilter(nil) -- tout masquer à nouveau

camera:isCockpit()   --> boolean : vue cockpit effective
camera:lookAngles()  --> (lacet, tangage) en radians, relatifs au véhicule ; (0, 0) = droit devant
```

Règles : une seule visée imposée à la fois (la dernière remplace la précédente) ; pendant une visée imposée le
regard libre est suspendu ; une erreur dans `Target` est interceptée (vue normale conservée) ; la visée est retirée
automatiquement à la fin de la conduite. Le filtre de visibilité s'applique aux `BasePart` et `Decal` du personnage
au moment où le cockpit est activé (ou aussitôt s'il l'est déjà) ; les pièces ajoutées ensuite au personnage ne
sont pas reprises automatiquement (à traiter par le lot « mains sur le volant », par exemple en réappelant
`setCharacterVisibilityFilter`). Point à vérifier par ce lot : le contrôleur de transparence du `PlayerModule`
Roblox pourrait aussi modifier `LocalTransparencyModifier` ; le masquage actuel du cockpit a été validé en jeu par le
propriétaire, mais l'affichage partiel des bras n'a jamais été essayé.

## 5. Vérifications exécutées

| Commande | Date | Résultat |
| --- | --- | --- |
| `powershell -ExecutionPolicy Bypass -File scripts\verify.ps1 -DownloadRobloxTypes` | 2026-11-06 | **Toutes les étapes OK** : Rojo, Selene, pilote Studio (génération + compilation), StyLua, Lune **425 réussis / 0 échoué** (dont les 15 tests CAMERA-01), carte du monde, place monde ouvert, pytest **23 passed**, luau-lsp strict **0 erreur** (seuls les 3 avertissements `DeprecatedApi` existants côté serveur). |
| `rojo build default.project.json -o build\AW-CAMERA-01.rbxlx` | 2026-11-06 | Place de test construite (`build\AW-CAMERA-01.rbxlx`, 3 056 896 octets). |

Les tests Lune vérifient la **logique** : limites des deux modes, lacet circulaire de l'orbite, passage orbite →
embarquée, valeurs non finies ignorées, sens / sensibilité / inversion de la souris et du doigt, zone morte et
courbe du stick, délais et vitesses du retour au centre (à l'arrêt et dès 15 km/h), absence de retour quand le regard
est tenu, chemin le plus court en orbite, indépendance de la cadence d'image, fondu de la visée imposée, préférences
nettoyées (bornes, type, champ inconnu, profil ancien), textes FR / EN alignés, présence de l'interface de la 2e vague
et du nom de vue « Cockpit ».

## 6. NON TESTÉ

Aucun essai dans Roblox Studio (ni VM, ni poste principal) : depuis le 2026-11-05, le propriétaire teste lui-même.
Sont donc **NON TESTÉS** : la lecture réelle du clic droit, de la souris, du stick droit et du doigt par Roblox ; le
rendu des vues ; le blocage puis la restitution du curseur ; la suspension avec les écrans ouverts ; les réglages du
téléphone en jeu ; le comportement sur un appareil tactile réel. L'interface de la 2e vague n'est utilisée par aucun
code du jeu : elle n'a été vérifiée que par compilation, typage et le test pur du fondu.

À noter pour l'essai tactile : le jeu n'a pas encore de commandes de conduite tactiles (clavier et manette
seulement) ; au doigt, on peut s'asseoir au volant et regarder autour, mais pas rouler.

## 7. Liste de vérification en jeu (propriétaire)

Ouvrir `build\AW-CAMERA-01.rbxlx` dans Studio, lancer « Play », monter au volant d'un véhicule (Brio ou Comète).

**Souris (clic droit maintenu)**

1. Vue Proche : maintenir le clic droit et bouger la souris → la caméra tourne autour de la voiture (on peut faire le
   tour complet) ; souris vers le haut = caméra plus basse qui regarde vers le haut ; elle ne traverse pas un mur.
2. Pendant l'appui, le curseur reste figé sur place ; au relâchement, il est utilisable normalement.
3. À l'arrêt, relâcher : la vue reste ≈ 1,5 s puis revient doucement derrière la voiture (≈ 0,7 s).
4. Rouler à plus de 15 km/h après avoir regardé de côté : la vue revient plus vite (≈ 0,4 s + 0,4 s).
5. Clic droit maintenu en roulant : la vue reste où on la tient, sans revenir.
6. Vue Lointaine : mêmes points 1 et 3.
7. Vue Cockpit : la tête tourne jusqu'à ≈ 120° à gauche et à droite (vitre latérale visible), ≈ 40° vers le bas et
   ≈ 30° vers le haut, pas au-delà ; le personnage reste masqué ; le son d'habitacle est inchangé.
8. Vues Capot et Pare-chocs : rotation sur place avec les mêmes limites.
9. Touche V pendant qu'on regarde de côté : la nouvelle vue part droit devant.

**Manette (stick droit)**

10. Dans chaque vue, le stick droit fait regarder autour ; léger effleurement sans effet (zone morte) ; stick lâché :
    retour au centre comme à la souris ; stick gauche, gâchettes et boutons conduisent comme avant.

**Tactile (si possible : émulateur d'appareil de Studio ou appareil réel)**

11. Au volant, glisser un doigt sur une zone libre de l'écran : la caméra tourne ; sur un bouton de l'interface : rien.

**Interfaces ouvertes**

12. Ouvrir le téléphone (T / X), la carte, le menu d'administration (F2), le mode photo à l'arrêt : le clic droit et
    le stick droit ne bougent plus la caméra ; les clics dans les fenêtres fonctionnent ; la souris n'est jamais
    bloquée. Ouvrir le chat et taper un texte : pas de mouvement de caméra.
13. Ouvrir le téléphone pendant un clic droit maintenu : la souris est rendue aussitôt.

**Réglages**

14. Téléphone > Paramètres > Commandes > « Caméra en conduite » : la sensibilité passe de 1 à 5 (puis revient à 1) et
    change nettement la vitesse ; « axe vertical inversé » inverse haut / bas à la souris, au stick et au doigt.
15. Si la sauvegarde des préférences est active dans la session d'essai : quitter puis revenir, les deux réglages
    sont conservés (même chemin que les autres préférences ; aucune donnée de production).

**Conduite inchangée**

16. Sans toucher à la souris ni au stick droit, les vues sont identiques à avant le lot ; accélération, freinage,
    direction, rapports, sortie (F / Y) inchangés ; sortir du véhicule rend la caméra Roblox habituelle.

## 8. Hors périmètre (propositions, non réalisées)

- Regard libre pour les **passagers** (seul le conducteur a une caméra de véhicule aujourd'hui).
- Touche « regarder derrière » instantanée, et commandes de conduite tactiles.
