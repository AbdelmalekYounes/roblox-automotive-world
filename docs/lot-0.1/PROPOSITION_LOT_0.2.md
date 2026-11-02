# Proposition — lot 0.2 (NON implémenté, soumis à décision)

Référence roadmap : « Physique avancée, transmissions, pneus, suspension, ressources et dégâts ».
Rien de ce document n'est commencé ; il sert à décider du contenu du lot suivant.

## 0. Préalable : clore réellement le lot 0.1

1. ~~Exécuter les essais Studio~~ : fait automatiquement dans la VM (149/149, `RAPPORT_TESTS.md` §4).
   Restent à vérifier par un humain : clavier et manette réels, rendu visuel, ressenti, taille de l'avatar.
2. Étendre les scénarios automatisés : bosse à 10 %, slalom, véhicule réellement renversé puis remis sur roues,
   retour automatique au plot, collision entre deux véhicules.
3. Calibrer le prototype à partir des mesures faites en jeu (freinage plus long qu'attendu par le modèle),
   sans retoucher les règles du cahier des charges.
4. Arbitrer les choix A1 à A6 de `ECARTS.md`.
5. Captures : décider d'une exclusion Windows Defender limitée à `C:\AWTests` **dans la VM** (décision du
   propriétaire), sans quoi les essais restent sans image.

## 1. Contenu proposé

| Bloc | Contenu | Critère d'acceptation proposé |
|---|---|---|
| Transmissions | Boîte manuelle (embrayage simplifié, rapports au clavier/manette), double embrayage, séquentielle ; mono-rapport électrique | Chaque type refusé tant que non implémenté ; tests de passages, de surrégime et de calage |
| Motorisation électrique | Couple/puissance selon régime, freinage régénératif, état d'énergie de session | Autonomie et consommation calculées serveur, aucune recharge gratuite cachée |
| Consommation thermique | Carburant consommé selon charge et régime, état de session | Valeurs bornées, panne sèche cohérente (pas de remplissage gratuit) |
| Pneus | Frottement statique (arrêt en pente), longueur de relaxation, adhérence sec/mouillé prête pour la météo du lot 0.3 | Véhicule immobile sur la bosse à 10 % frein serré ; pas d'oscillation à basse vitesse |
| Suspension | Balayage de forme par roue (shapecast), réglages de géométrie simples | Franchissement de bordures sans accroche anormale |
| Différentiels et architectures | Différentiel autobloquant optionnel, répartition AWD ; deux prototypes d'essai supplémentaires (FWD et AWD/électrique), toujours hors catalogue | Les trois prototypes se comportent différemment à paramètres documentés |
| Aides (par modèle) | ABS, antipatinage, ESP disponibles seulement si la définition les déclare ; désactivées par défaut selon les règles validées | Aucune aide active sur un modèle qui n'en dispose pas ; état visible au HUD |
| Dégâts (session) | 3 niveaux visuels sur primitives, effets mécaniques simples, contacts confirmés serveur (AUD-COLL-01) | Dégât appliqué seulement après validation serveur ; **aucune persistance** avant le lot 0.4 |
| Caméras | Cockpit, capot, pare-chocs | Bascule sans action involontaire ; pas de caméra libre |
| Mesure de performance | Relevé des temps d'image (médiane, P95, P99) dans le HUD de développement | Premières mesures sur une configuration de référence à définir, sans conclure sur la cible 24 joueurs |

## 2. Hors périmètre du lot 0.2

Économie, crédits, achats, possession définitive, DataStore et persistance (lots 0.4–0.5), carte à sept zones
et circulation (0.3), courses (0.6), HUD définitif, smartphone et localisation complète (0.7).

## 3. Risques

- Coût CPU de la simulation (balayages de forme, 3 prototypes, dégâts) : à mesurer dès le début du lot.
- Dégâts multijoueur et latence : risque de faux positifs (AUD-COLL-01) ; prudence et tolérance à conserver.
- Boîte manuelle à la manette et au clavier : ergonomie à valider en essais réels.
