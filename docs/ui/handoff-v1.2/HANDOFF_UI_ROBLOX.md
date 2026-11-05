# Automotive World — Handoff UI/UX v1.2

## Source et statut

Quatre maquettes Claude Design v1.2 fournies par le propriétaire le 4 novembre 2026 : `Directions artistiques.dc.html`, `Design System.dc.html`, `Smartphone.dc.html`, `Garage.dc.html`.

Statut : **proposition à valider dans Roblox Studio**, **pas du code Roblox exécutable**. Les `.dc.html` utilisent le runtime de Claude Design (`support.js`), maintenant fourni à côté des quatre maquettes. Le runtime charge React/ReactDOM depuis un CDN si ces bibliothèques ne sont pas déjà disponibles : un accès Internet peut donc être nécessaire pour la prévisualisation. La syntaxe de `support.js` a été vérifiée ; les interactions complètes n’ont pas été validées dans un navigateur. Ne pas prétendre qu'ouvrir ces fichiers directement reproduit leur comportement. Les scripts intégrés peuvent servir de spécification des états et des interactions.

## Direction retenue pour l'implémentation candidate

- Automotive Premium : fond `#0E0F11`, surfaces `#16181B` et `#1E2125`, ambre `#E8A33D`, texte `#ECEAE6`.
- Cyan `#5CC8D6` limité au GPS/instruments, rouge `#E5534B` pour course/refus, vert d'état pour succès.
- Titillium Web pour textes, Roboto Mono pour valeurs. Vérifier les noms d'assets de polices et leur rendu dans Roblox Studio : ne pas supposer les API de police sans test.
- Focus manette visible, contraste renforcé, tailles de texte, réduction des animations, localisation FR/EN.

## Correspondance aux modules du jeu

- `Design System.dc.html` → `src/client/UI/UITheme.luau` puis composants visuels réutilisables.
- `Smartphone.dc.html` → `src/client/UI/PhoneController.luau` : 12 apps (Map, Vehicles, Properties, Missions, Races, Market, Social, Radio, Photo, Guide, Settings, Notifications), intégration avec les services et `UIManager` existants, pas de nouveau service de transactions.
- `Garage.dc.html` → `src/client/UI/GaragePanel.luau` : 6 onglets (Collection, Véhicule, Propriétés, Préparation, Configurations, Invitations) et zone centrale réservée au rendu de véhicule (ViewportFrame ou caméra de présentation, arbitrer après essai).
- Écrans/couches globaux : `src/client/UI/UIManager.luau`, `src/shared/UI/DrivingGate.luau`, `src/shared/UI/InputMap.luau`.
- Les caractéristiques automobiles viennent du catalogue officiel proposé, jamais des valeurs simulées. Les graphiques de performance de la maquette ne sont **pas** des calculs physiques validés.

## Intégration : règles non négociables

1. Les maquettes représentent des **états simulés** : aucun achat, vente, sauvegarde, réparation, tuning, droit d'accès ou changement de langue ne peut être annoncé confirmé avant la réponse de son service Roblox réel.
2. Respecter les règles d'immobilisation, capture d'input et le délai de confirmation (`InputMap.ConfirmDelayS = 0.25`, `SwitchDelayS = 0.4`) ; les remotes serveur gardent leur autorité.
3. Ne pas ajouter de commande locale de conduite, de nouveau service financier ou de seconde persistance.
4. Les 5 véhicules des maquettes ne sont pas la gamme officiellement approuvée ; le catalogue actuel propose 18 modèles fictifs, actuellement en attente de validation.
5. Les illustrations véhicule et le plateau 3D restent **des espaces réservés**. Aucun modèle de voiture 3D n'a été fourni par les fichiers.
6. Les icônes du téléphone sont décrites par des chemins SVG dans le script du `.dc.html`. Pour Roblox, produire et vérifier des PNG/atlas appropriés si nécessaire, sans réutiliser des caractères Unicode.
7. Prévoir la VM Studio et les scripts GUI autonomes pour les vérifications. Le rendu final devra être vérifié dans le moteur Roblox et pas uniquement via les maquettes.
8. Travailler sur une branche/worktree UI distincte ; la PR #11 (`feat/final-stabilization-0.9.2`) est en cours. Ne pas modifier ses fichiers ni lancer deux tests VM simultanément.

## Plan par étapes et critères d'acceptation

### Étape UI-01 — Design system et composants
- Implémenter tokens et éléments de base sans modifier la logique des services ni remplacer les écrans actuels.
- Tester les polices, focus PC/manette si possible, FR/EN, contraste, adaptation aux 4 résolutions, animations réduites.
- Ajouter une démo/route de test UI désactivée en production ; vérification hors Studio puis VM.
- Captures de contrôle de l'apparence et absence d'erreurs Studio.

### Étape UI-02 — Smartphone
- Refaire `PhoneController` à partir du design, sans changer les demandes envoyées aux services.
- Conserver le mode rapide/les restrictions actuelles, le modèle physique en main et les applications existantes.
- Conserver les brouillons et états réels quand l'interface passe en conduite.
- Tests des 12 apps, des notifications, du retour, des opérations sensibles et du focus manette.

### Étape UI-03 — Garage
- Refaire la collection et les 6 onglets, centre de présentation 3D, fiche latérale.
- Ne jamais simuler une transaction ou un état confirmé ; gérer Pending, Rejected, Offline et Confirmed selon les services.
- Réutiliser les règles réelles de `TuningRules`, `PartCatalog` et les 5 configurations par véhicule.
- Vérifier garage public/privé, hors garage, conduite, action refusée et état sauvegardé.

### Étape UI-04 — Autres écrans et harmonisation
- HUD, économie, concessions, courses, carte et notifications.
- Non-régression transversale avant tout merge.

## Vérifications non encore faites

- Tests réels du runtime Claude Design, de la VM Studio, des polices Roblox et des exports d'icônes.
- Rendu visuel des carrosseries et des ViewportFrame dans le moteur.
- Interactions manette sur matériel réel.
- Statut définitif de la branche 0.9.2 avant intégration.
