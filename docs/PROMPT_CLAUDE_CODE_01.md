# PROMPT 01 — Claude Code — Lot 0.1 : première voiture pilotable

Tu es développeur principal d'un nouveau jeu automobile multijoueur Roblox 100 % original.
Le cahier des charges GLOBAL v1.0, composé de onze chapitres et de 33 arbitrages transversaux AUD, est officiellement validé. Il constitue le référentiel fonctionnel.

## Contexte technique

Le dépôt commence avec le socle `Automotive World` version 0.0.1, en Luau/Rojo 7.7.1.
**Ne réutilise aucun code, modèle, interface, texture ni donnée des projets Collectverse ou Mimic Hunters.**
Le nom `AutomotiveWorld` est purement technique et provisoire.

## Première étape obligatoire

1. Examiner le dépôt, `README.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md` et le cahier des charges complet mis à disposition.
2. Installer ou vérifier Rojo et les outils de validation locaux si nécessaires.
3. Faire fonctionner `rojo build` ; corriger toute erreur réelle, sans supposer sa réussite.
4. Documenter précisément les moyens et limites des tests disponibles.
5. Créer une branche spécifique `feat/vehicle-vertical-slice-0.1` si un dépôt Git est disponible ; ne jamais écraser `main`.

## Objectif du lot 0.1

Créer, dans une zone d'essai simple et isolée, **une seule voiture 100 % fictive et originale, pilotable au clavier et à la manette**, avec un premier modèle de conduite sérieux et modulable. Pas de catalogue final ni de carte complète dans ce lot.

### Exigences

- Modèle automobile de test simple, géométrie temporaire originale (pas d'actif Marketplace non validé).
- Commandes de direction, accélération, freinage, marche arrière, caméra proche/lointaine au minimum.
- Simulation de masse et inertie, freinage et adhérence avec paramètres isolés par modèle ; ne pas faire une commande arcade de vitesse instantanée.
- Architecture compatible avec futures FWD/RWD/AWD, modèles thermiques/électriques, transmissions et aides spécifiques. Ne pas déclarer ces fonctionnalités implémentées avant leur réalisation.
- Conduite réactive côté joueur, validations serveur des mouvements impossibles et états critiques ; tolérance réseau. Ne pas faire confiance à un montant ou résultat sensible envoyé par le client.
- Possibilité de plusieurs joueurs présents sans écrasement de l'état des autres véhicules.
- Aucun crédit, possession définitive, achat, DataStore ou récompense ajouté prématurément.
- Séparer clairement code client, serveur et partagé.
- Écrire en Luau typé lorsque pertinent, avec commentaires explicatifs en français.
- Refuser les dépendances opaques ou les modèles préexistants non inspectés.

## Tests obligatoires

- Construire le projet avec Rojo.
- Vérifier la compilation/analyse des scripts avec les outils réellement disponibles.
- Tester dans Roblox Studio : spawn, embarquement, accélération, freinage, marche arrière, virages, caméra, sortie de voiture.
- Tester si possible avec deux clients simulés et de la latence réseau configurée.
- Aucun test ne doit accéder aux DataStores de production.
- Si Studio ou l'interaction graphique est indisponible, ne prétends pas les avoir testés : liste les étapes manuelles restantes.
- Éviter de monopoliser souris, clavier ou écran ; privilégier processus et tests non intrusifs. Toute interaction graphique nécessaire doit être annoncée.

## Livrables

- Code source versionné et commenté.
- README mis à jour avec instructions Windows.
- Liste des fichiers modifiés.
- Rapport de tests : commandes exécutées, résultats observés, limitations.
- Vidéo ou captures locales seulement si réellement produites, jamais inventées.
- Analyse des écarts par rapport au cahier des charges.
- Proposition du lot 0.2, sans l'implémenter automatiquement.

## Critère de clôture

Une voiture originale de test est pilotable et réagit progressivement, sans avoir introduit d'économie non sécurisée. Les tests effectivement réalisés sont documentés. N'invente ni performances ni validations non mesurées.
