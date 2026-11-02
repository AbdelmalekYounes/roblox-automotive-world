# Architecture initiale — v0.0.1

## Contraintes du cahier des charges v1.0

- **Client** : entrées de conduite, caméra, interface, rétroaction immédiate. Ne décide jamais seul d'un changement persistant sensible.
- **Serveur** : autorité sur possessions, crédits, achats, ventes, dégâts persistants, éligibilité et récompenses des courses.
- **Shared** : configurations sans secret, contrats de données et utilitaires purs accessibles des deux côtés.
- **Sauvegardes** : non implémentées dans le socle. Leur futur service devra posséder un modèle versionné, un contrôle exclusif de session et des écritures récupérables.
- **Véhicules** : un *modèle* est une définition de catalogue ; une *instance* est un exemplaire possédé, identifié de façon unique.
- **Réseau** : aucun client ne pourra envoyer directement un montant de crédits à créditer ni un état de véhicule à persister sans validation serveur.
- **Tests** : environnement de validation isolé de la production ; ne pas connecter Studio à une production réelle.

## Arborescence

- `src/server` : démarrage et futurs services autoritaires.
- `src/client` : interface et futures commandes de conduite.
- `src/shared` : paramètres et contrats Luau communs.
- `tests` : validations statiques et tests futurs.
- `docs` : plan et instructions de réalisation.

## Décision d'architecture pour la première voiture

La première voiture sera un **prototype technique original**, distinct de tout actif commercial du lancement. Il devra servir à valider la conduite réaliste de base et l'architecture hybride. Il ne devra pas être confondu avec le véhicule gratuit définitif. L'implémentation physique détaillée sera produite et testée dans le lot suivant avant toute extension aux 18 modèles.

## Exclusions du socle 0.0.1

Aucun DataStore, achat, économie, dégâts persistants, course, radio, carte de sept zones ni modèle automobile de production n'est encore implémenté. Ces sujets sont prévus dans les lots de développement, non abandonnés.
