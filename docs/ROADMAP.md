# Roadmap indicative — cahier des charges officiel v1.0

L'ordre décrit des lots de travail, pas une réduction du périmètre final.

| Version de développement | Résultat attendu |
|---|---|
| 0.0.1 | Socle Rojo/Luau, démarrage client/serveur, documentation, tests statiques |
| 0.1 | Première voiture originale pilotable, entrée clavier/manette, conduite différenciable, métriques élémentaires |
| 0.2 | Physique avancée, transmissions, pneus, suspension, ressources et dégâts |
| 0.3 | Monde ouvert à sept zones, circulation et infrastructures |
| 0.4 | Profils persistants, collection, propriétés, garages, configurations |
| 0.5 | Crédits, huit familles de missions, concession et marché d'occasion |
| 0.6 | Six disciplines, compétitions réalistes/protégées, saison classée |
| 0.7 | Smartphone, HUD, GPS, social, permissions, accessibilité |
| 0.8 | Art, audio, radio, mode photo, onboarding, FR/EN |
| 0.9 | Tests intégrés, sécurité, anti-abus, performance et résilience |
| 1.0 | Vérification du périmètre complet et GO/NO-GO avant ouverture publique |

## État du lot 0.1 (branche `feat/vehicle-vertical-slice-0.1`)

- Code livré : zone d'essai isolée, prototype P-01, conduite clavier/manette, dynamique paramétrable, validation serveur.
- Vérifié hors Studio : build Rojo, lint Selene, format StyLua, typage strict luau-lsp, 100 tests Lune, 8 contrôles pytest.
- Vérifié dans Roblox Studio (VM VMware, `test-vm.cmd`, 6 sessions) : collisions entre joueurs corrigées (poussée du
  même ordre qu'un véhicule garé), propriété réseau vérifiée (refus, correction, déconnexion), arbitrages A1–A6 appliqués.
- **Ouvert avant clôture** : anomalie intermittente (mouvement d'un véhicule piloté qui n'atteint pas le serveur
  pendant quelques secondes), essais humains clavier/manette/chat et ressenti. VM de test restreinte au dossier d'échange.
- Rapports : `docs/lot-0.1/RAPPORT_VALIDATION.md` (final), `RAPPORT_TESTS.md` (historique) ; écarts et arbitrages :
  `docs/lot-0.1/ECARTS.md` ; proposition qui a servi de base au lot 0.2 : `docs/lot-0.1/PROPOSITION_LOT_0.2.md`.

## État du lot 0.2 (branche `feat/advanced-vehicle-physics-0.2`, PR brouillon #2, base : lot 0.1)

Commencé à la demande du propriétaire alors que la PR #1 n'est pas fusionnée (exception explicite à la règle
« un lot clôturé avant le suivant » de `CLAUDE.md`) ; le lot 0.1 reste intact sur sa branche.

- Livré : moteurs essence / diesel / électrique, six boîtes (automatique à convertisseur, manuelle, double embrayage,
  séquentielle, CVT, rapport unique), FWD/RWD/AWD et autobloquants, pneus (frottement statique, glissement combiné,
  relaxation, mouillé), ABS / antipatinage / ESP par modèle, énergie et dégâts de session confirmés serveur,
  caméras cockpit / capot / pare-chocs, prototypes P-02 et P-03, configurations de validation DCT / SEQ / CVT.
- Rapport : `docs/lot-0.2/RAPPORT_LOT_0.2.md` ; écarts : `docs/lot-0.2/ECARTS.md` ; architecture :
  `docs/lot-0.2/ARCHITECTURE_LOT_0.2.md`.
- Hors périmètre, prévus aux lots suivants : monde ouvert, stations et recharge payantes, crédits, profils et
  persistance (dont dégâts et énergie, lot 0.4), garages, compétitions, smartphone/GPS, catalogue des 18 modèles.

## État du lot 0.3 (branche `feat/open-world-map-0.3`, PR brouillon, base : lot 0.2)

Commencé à la demande du propriétaire alors que les PR #1 et #2 ne sont pas fusionnées ; les lots précédents restent
intacts sur leurs branches. Décision du propriétaire : essais humains, non-régression approfondie et charge regroupés
dans un lot QA ultérieur (`docs/QA_BACKLOG.md`).

- Livré : carte d'un seul tenant à sept zones en maquette (1 285 carrefours, 2 224 tronçons), générée hors ligne de
  façon déterministe ; infrastructures aux quantités du cahier des charges (emplacements et volumes) ; graphe routier
  (A*) ; trafic PNJ (virtuel / physique) et piétons ; météo et cycle jour/nuit de 30 min ; humidité de chaussée
  appliquée une seule fois ; place monde ouvert avec streaming ; zone d'essai conservée dans la place de développement.
- Vérifié hors Studio uniquement (187 tests Lune, 9 pytest, typage strict) ; **aucun essai Studio ni humain**.
- Rapport : `docs/lot-0.3/RAPPORT_LOT_0.3.md` ; architecture : `docs/lot-0.3/ARCHITECTURE_LOT_0.3.md`.

## Critères de passage du socle 0.0.1

- Arborescence source entièrement nouvelle.
- Manifeste Rojo valide et reproductible.
- Chargement des scripts client et serveur dans Roblox Studio (à vérifier en Studio).
- Aucun appel aux DataStores et aucun accès production.
- Tests statiques passants et limites des tests documentées.
