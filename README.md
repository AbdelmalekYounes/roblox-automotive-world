# Automotive World — Socle technique 0.0.1

> **Nom technique provisoire** : ce n'est pas le nom commercial du jeu.
> **Référentiel** : cahier des charges global Roblox v1.0, officiellement validé le 2 novembre 2026.
> **Périmètre du livrable** : structure Rojo et deux scripts d'amorçage, **pas encore de véhicule pilotable**.

## Prérequis

- Roblox Studio sur Windows ou macOS.
- Rojo 7.7.1 (version épinglée dans `rokit.toml`), idéalement via Rokit.
- Plugin Rojo 7 pour Roblox Studio.
- Git, Python 3.10+ pour les contrôles statiques.

## Démarrer dans Roblox Studio

1. Extraire l'archive dans un **nouveau dossier indépendant**.
2. Installer Rojo (voir https://create.roblox.com/docs/projects/external-tools).
3. Dans le dossier du projet, lancer : `rojo build -o development.rbxlx`.
4. Ouvrir `development.rbxlx` dans Roblox Studio.
5. Cliquer sur **Play** : une bannière `Socle technique chargé` doit apparaître.
6. Pour les modifications en direct, exécuter `rojo serve`, puis connecter le plugin Rojo.

**Important :** ne pas activer l'accès aux DataStores de production dans Studio. Le socle n'utilise actuellement aucun DataStore.

## Vérifications locales

```bash
# Exécute les contrôles statiques du projet et les tests du manifeste.
python -m pytest -q tests
```

Le test Rojo/Studio réel doit encore être exécuté sur un environnement équipé de Roblox Studio. Les tests Python ne le remplacent pas.

## Référence fonctionnelle

Le dossier approuvé globalement est inclus sous `docs/CAHIER_DES_CHARGES_GLOBAL_v1.0.md`. Les mentions de statut pré-approbation qui y subsistent sont historiques ; l’en-tête actualise la décision officielle.

## Étape suivante

`docs/PROMPT_CLAUDE_CODE_01.md` donne les instructions d'implémentation de la première **vertical slice automobile**, avec une unique voiture fictive de test et une simulation sérieuse, sans intégration économique prématurée.

## Gouvernance

- Le cahier des charges validé et les 33 décisions AUD font foi.
- Aucun code ni actif de Collectverse ou Mimic Hunters ne sera réutilisé.
- Le dépôt de destination GitHub sera dédié à ce jeu ; aucun dépôt existant n'est modifié par cette archive.
- Le contenu de ce socle n'annonce aucun objectif technique comme atteint (24 joueurs, ~60 FPS, etc.).
