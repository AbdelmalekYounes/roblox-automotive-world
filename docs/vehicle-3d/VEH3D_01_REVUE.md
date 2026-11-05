# VEH3D-01 — fiche de revue de la Comète par le propriétaire

Essai humain : à remplir par le propriétaire. Rien ici n'a été coché par l'assistant.

## Préparer

1. Ouvrir dans Roblox Studio, sur ton poste : `E:\ROBLOX DEV\aw-wt-veh3d01\build\AutomotiveWorld.rbxlx`, construit le
   2026-11-05 à 02 h 40 avec le code final (`1b02177`). Pour le reconstruire : `rojo build -o build\AutomotiveWorld.rbxlx`
   dans ce dossier.
2. Lancer **Play** (F5).
3. La Comète n'est pas dans le parc de la zone d'essai, et la concession la marque « en attente d'approbation ». Pour la
   faire apparaître à côté de toi : onglet **Test**, bouton **Current: Client** basculé sur **Server**, puis coller dans
   la barre de commande (accès de revue propre à Studio ; un `require` depuis la barre de commande charge une autre
   copie des modules et répond « VehicleService non démarré ») :

   ```lua
   print(game.ServerStorage.AWRevue:Invoke("wk_comete"))
   ```

   Revenir ensuite sur **Client** pour jouer.
4. Nuit : même barre de commande, côté **Server** : `game.Lighting.ClockTime = 0` (14 pour revenir au jour).

Fenêtre d'arrivée au premier lancement : la passer, puis fermer « Choisir votre véhicule » avec la touche Retour (sinon
la conduite reste bloquée, comportement normal du jeu).

## À regarder

| # | Point | Comment | Verdict (OK / à revoir + remarque) |
|---|---|---|---|
| 1 | Allure générale | tour du véhicule à pied, jour | |
| 2 | Vitrage (réglage C) | conducteur visible de l'extérieur, vue intérieure dégagée | |
| 3 | Montée | maintenir **E** à la porte conducteur ; place passager côté droit | |
| 4 | Pose assise | vue extérieure par la vitre ; pieds, tête, mains | |
| 5 | Caméras | **V** : poursuite, cockpit, capot, bouclier | |
| 6 | Conduite | **Z/W** engage le 1er à l'arrêt (depuis le 2026-11-05 ; avant : **Maj** obligatoire), **Maj/Ctrl** pour monter et descendre, **S/A/D** | |
| 7 | Roues | rotation et braquage des roues du modèle | |
| 8 | Feux stop | freiner (**S**) en roulant, regarder l'arrière | |
| 9 | Nuit | phares et feux arrière : sources allumées, optiques non lumineuses (limite connue) | |
| 10 | Dégâts | percuter le mur jaune de la zone d'essai : rayures, enfoncements sombres, fumée | |
| 11 | Sortie conducteur | **F** : debout à gauche du véhicule | |
| 12 | Sortie passager | **Espace** : debout à droite du véhicule | |
| 13 | Téléphone au volant | **T** | |
| 14 | Crédits | Téléphone › Paramètres › Crédits et licences : texte FR (et EN après changement de langue) | |
| 15 | Peinture | garage : la couleur ne change pas la Comète (limite connue, envoi requis) | |

## Décisions demandées

| Décision | Choix |
|---|---|
| Envoi groupé (feux séparés, carte de peinture neutre ; LOD1/LOD2 ? panneaux de dégâts ?) ou limites acceptées pour cette version | |
| Crédits : afficher le titre de l'œuvre ? le lien ? | |
| Risque lié au dessin commercial : accepté / avis juridique / autre | |
| Clôture de VEH3D-01 | |

## Résultat de la revue (2026-11-05)

Revue faite par le propriétaire dans Studio, sur son poste. Verdict, dans ses mots : **« tout fonctionne
correctement »**. Les 15 points n'ont pas été notés un par un.

Pendant la revue : la voiture ne roulait pas au premier essai. Cause : la boîte séquentielle partait au neutre et
attendait la touche Maj. Le propriétaire a demandé que l'accélérateur engage le 1er rapport (voir ci-dessous).
L'accès de revue d'abord indiqué (`require` depuis la barre de commande) répondait « VehicleService non démarré » ; il
est remplacé par `ServerStorage.AWRevue`.

| Décision | Choix du propriétaire |
|---|---|
| Envoi groupé (feux séparés, carte de peinture neutre, LOD, panneaux) | **plus tard** ; limites gardées pour cette version |
| Crédits : titre et lien de l'œuvre | **plus tard** ; masqués d'ici là |
| Risque lié au dessin commercial | **gardé** : « dans tous les cas il n'y aura aucun problème » (décision du propriétaire, non vérifiée juridiquement) |
| Boîte séquentielle | **l'accélérateur engage le 1er** au neutre et à l'arrêt, comme le double embrayage (toutes les boîtes séquentielles) |

