# Rapport du lot 0.4 — persistance, propriétés, garages et collection

Branche `feat/properties-garages-persistence-0.4`, créée depuis `c00a5c6` (dernier commit du lot 0.3), PR brouillon
vers `feat/open-world-map-0.3`. Les branches `main`, `feat/vehicle-vertical-slice-0.1`,
`feat/advanced-vehicle-physics-0.2` et `feat/open-world-map-0.3` n'ont pas été modifiées.

Conformément à la décision du propriétaire, **aucun essai Studio, humain ou de charge n'a été exécuté** pendant ce
lot. **La persistance réelle (DataStore) n'est pas validée** : toute la logique est éprouvée sur l'adaptateur mémoire.
Les essais reportés sont dans [`docs/QA_BACKLOG.md`](../QA_BACKLOG.md) (§2, §3 bis, §4), marqués **NON TESTÉ**.

## 1. Synthèse des livrables

| # | Livrable | État | Vérifié par |
|---|---|---|---|
| 1 | Profils versionnés | Livré (schéma v1, validation, migrations) | Lune (adaptateur mémoire) |
| 2 | Adaptateur DataStore et adaptateur mémoire | Livrés ; DataStore jamais instancié (aucune expérience déclarée) | Lune (mémoire) ; DataStore : **NON TESTÉ** |
| 3 | Verrou de session, idempotence | Livrés (génération, reprise des verrous expirés, réconciliation) | Lune |
| 4 | Collection à identifiants uniques | Livrée (sans limite de nombre, pagination) | Lune |
| 5 | Propriété de départ unique | Livrée (transaction fixe + attribution inscrite) | Lune |
| 6 | Contrats du starter définitif | Livrés ; **liste officielle vide** → choix refusé | Lune (liste synthétique injectée) |
| 7 | Propriétés et garages évolutifs | Livrés (3 catégories, plafond 5, niveaux, intérieurs instanciés) | Lune (règles) ; intérieurs : **NON TESTÉ** |
| 8 | Personnalisation esthétique et mécanique | Livrée (catalogues, plages par modèle, pièces) | Lune |
| 9 | Cinq configurations par véhicule | Livrées (sans duplication de pièces) | Lune |
| 10 | Dégâts, énergie, kilométrage durables | Livrés (mesures serveur, réconciliation monotone) | Lune (règles) ; en jeu : **NON TESTÉ** |
| 11 | Invitations avec permissions | Livrées (visite / conduite séparées, révocation) | Lune (règles) ; en jeu : **NON TESTÉ** |
| 12 | Interfaces provisoires | Livrées (panneau P / Select, badge d'état) | Typage seulement ; **NON TESTÉ** |
| 13 | Préparation de l'économie V0.5 | Contrats et ratios ; toutes les opérations payantes indisponibles | Lune |
| 14–16 | Rapport, architecture, registre QA | Ce document, `ARCHITECTURE_LOT_0.4.md`, `docs/QA_BACKLOG.md` | — |

## 2. Vérifications exécutées (hors Studio)

Commande : `powershell -ExecutionPolicy Bypass -File scripts\verify.ps1 -RobloxTypes .tooling\globalTypes.d.luau`,
exécutée le 2026-11-03 à 02:25 sur le code du commit `39b76b9` (arbre de travail : seul `docs/QA_BACKLOG.md` modifié).
Sortie conservée localement dans `build/verify-lot04.log` (non versionnée).

| Étape | Résultat |
|---|---|
| Rojo build (place de développement) | OK |
| Selene | OK (0 erreur, 0 avertissement) |
| Pilote Studio (génération + compilation, sans lancer Studio) | OK |
| StyLua `--check` | OK |
| Lune (tests hors Studio) | OK — **235 réussis, 0 échoués** (dont 48 nouveaux du lot 0.4) |
| Génération de la carte du lot 0.3 | OK — 36 968 pièces, 43 services |
| Rojo build (place monde ouvert) | OK |
| Pytest | OK — **10 réussis** |
| luau-lsp `analyze` strict | OK — 0 erreur |

Tests du lot 0.4 (`tests/lune/specs/Lot04Persistence.luau`, `Lot04Progression.luau`), tous sur données SYNTHÉTIQUES :

- environnements : aucune expérience déclarée → mémoire partout ; Test et Prod séparés ; Studio sur la production →
  mémoire ; données synthétiques en Dev seulement ;
- verrou : seconde session refusée, reprise d'un verrou expiré journalisée, **ancien serveur empêché d'écraser un
  état plus récent**, génération périmée refusée, rafraîchissement périodique ;
- écritures : réponse incertaine appliquée → confirmée sans double application ; réponse perdue ou échec → « en
  attente » puis confirmée ; budget de 6 s par clé ; stockage indisponible → opérations suspendues ; suspension
  d'incident ; journal borné ;
- migrations : migration injectée sur copie avec `Legacy`, version plus récente → lecture seule sans réécriture,
  profil d'un autre environnement → lecture seule ; validation (place occupée deux fois, pièce orpheline) ;
- starter : liste officielle vide → refus ; liste synthétique → un seul exemplaire incessible malgré double clic et
  reconnexion ;
- propriétés : gratuite unique (même si le journal est purgé), invendable, plafond de cinq (sixième refusée) ;
  capacités 1–2 / 3–5 / 6–10 ; cession → véhicules exposés rangés ;
- garages : 300 exemplaires sans limite (≈ 267 Ko estimés), exposition bornée, jamais deux sorties, normalisation au
  rechargement, réservations ;
- préparation : réglages par défaut = définition d'origine, chaque borne valide pour les six définitions, combinaison
  irréalisable refusée, pièces jamais dupliquées, garage public requis pour les pièces ; esthétique validée ;
- configurations : cinq au plus, basculer ne crée aucune pièce, pièce absente → refus, copie transférable avec
  configurations réalisables seulement ;
- invitations, état durable monotone, session protégée, ratios économiques, cohérence des offres avec les
  identifiants de la carte du lot 0.3 (13 emplacements, 3 garages publics).

## 3. Ce qui fonctionne côté serveur (code livré, comportement en jeu NON TESTÉ)

- Arrivée : chargement sous verrou (jusqu'à 8 reprises de 5 s si un autre serveur le détient), normalisation,
  propriété gratuite (« Box résidentiel du Parc », petite catégorie), et en Dev : trois prototypes synthétiques,
  une propriété moyenne et une pièce de chaque type.
- Départ et arrêt : véhicule sorti rangé avec son état durable, visiteurs reconduits, sauvegarde finale et libération.
- Demandes : toutes revalidées (lieu réel, capacités, droits, mouvement > 1 m/s refusé) ; statut réel renvoyé.
- Place de développement : entrée de propriété et garage public d'essai dans la zone d'essai.

## 4. Écarts, choix et points à arbitrer

1. **Huit catégories de modules** : le dossier consolidé ne les énumère pas ; huit catégories sont **proposées**
   (`GarageModules`, marquées `Proposal`). À arbitrer.
2. **Véhicule de départ** : liste officielle vide (modèles de lancement non définis) ; aucun prototype n'est attribué
   comme voiture définitive. À fournir : trois identifiants du catalogue.
3. **Données synthétiques de développement** : les prototypes P-01/P-02/P-03 sont donnés en Dev (mémoire seulement)
   pour éprouver les garages, marqués `DevSynthetic`, jamais en Test/Prod.
4. **Capacités des garages privés** : sans module, ni réglages ni esthétique ni pièces ; seules les configurations
   réalisables sans échange de pièces s'appliquent. Les garages publics restent nécessaires. À valider.
5. **Catégories des offres** : déduites de l'emprise des emplacements du lot 0.3 (≥ 50 m : prestige ; boxes et
   chalets : petite). Propriété de départ : box résidentiel métropole. Aucun prix (lot 0.5).
6. **Visites** : le propriétaire doit être présent sur le même serveur (son profil n'est lu qu'ici). Lecture
   inter-serveurs : lot ultérieur.
7. **Un seul exemplaire sorti** par joueur à la fois.
8. **Limite technique de taille** : 3,5 Mo par profil (≈ des milliers d'exemplaires) ; fractionnement décrit,
   non implémenté. À arbitrer si nécessaire (§4.2 du cahier des charges).
9. **Retour d'un véhicule** : physique (à une entrée possédée ou un garage public) ; à la déconnexion, le véhicule
   revient automatiquement à son garage (le joueur quitte aussi le monde).
10. **Délai de reprise** : après un arrêt brutal de serveur, jusqu'à 5 min avant de reprendre le verrou.
11. **Restauration ciblée (AUD-REST-01)** : décrite (versions DataStore + journal + `Legacy`), aucun outil livré.
12. **Stockage en Dev** : mémoire du serveur ; un profil de développement est perdu à l'arrêt du serveur.
13. Version de développement passée à `0.4.0-dev`.

Anomalies existantes (QA-A01 à QA-A07) : **non corrigées et non retestées**. Les modifications du service des
véhicules (création des enregistrements, participants des collisions reconstruits à chaque battement) doivent être
couvertes par la non-régression Studio (QA-S22).

## 5. Reproduire

```
rojo build -o build\AutomotiveWorld.rbxlx
lune run tests\lune\run.luau build\AutomotiveWorld.rbxlx
```

Dans Studio (place de développement ou monde ouvert), le panneau s'ouvre avec **P** (manette : **Select**) ; l'entrée
de propriété et le garage public d'essai sont à l'ouest du point d'apparition de la zone d'essai (repères bleu et orange).
