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
- Vérifié hors Studio : build Rojo, lint Selene, format StyLua, typage strict luau-lsp, 66 tests Lune, 8 contrôles pytest.
- Vérifié dans Roblox Studio (VM VMware, `test-vm.cmd`) : 214/214 contrôles sur 5 sessions (solo, deux joueurs,
  latence ~205 ms, scénarios, collision), avec captures ; deux défauts réels trouvés et corrigés (sortie en multijoueur,
  tête traversant le toit) ; poussée faible et variable entre deux véhicules conduits, à traiter au lot 0.2.
- **Non encore vérifié** : clavier et manette réels, ressenti.
- Rapport : `docs/lot-0.1/RAPPORT_TESTS.md` ; écarts : `docs/lot-0.1/ECARTS.md` ; suite : `docs/lot-0.1/PROPOSITION_LOT_0.2.md`.

## Critères de passage du socle 0.0.1

- Arborescence source entièrement nouvelle.
- Manifeste Rojo valide et reproductible.
- Chargement des scripts client et serveur dans Roblox Studio (à vérifier en Studio).
- Aucun appel aux DataStores et aucun accès production.
- Tests statiques passants et limites des tests documentées.
