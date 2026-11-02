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
- **Ouvert avant clôture** : anomalie intermittente (client attribué qui ne simule pas son véhicule), essais humains
  clavier/manette/chat et ressenti, migration du partage de la VM.
- Rapports : `docs/lot-0.1/RAPPORT_VALIDATION.md` (final), `RAPPORT_TESTS.md` (historique) ; écarts et arbitrages :
  `docs/lot-0.1/ECARTS.md` ; suite : `docs/lot-0.1/PROPOSITION_LOT_0.2.md` (non commencée).

## Critères de passage du socle 0.0.1

- Arborescence source entièrement nouvelle.
- Manifeste Rojo valide et reproductible.
- Chargement des scripts client et serveur dans Roblox Studio (à vérifier en Studio).
- Aucun appel aux DataStores et aucun accès production.
- Tests statiques passants et limites des tests documentées.
