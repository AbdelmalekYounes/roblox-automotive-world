# Direction artistique — Automotive World (lot 0.8)

Statut : **proposition provisoire**, à valider par le propriétaire. Aucun élément de ce document n'a été jugé par
un humain en jeu (validation artistique reportée au lot QA, `docs/QA_BACKLOG.md` §3 sexies).

Valeurs de référence dans le code : `src/shared/Art/ArtDirection.luau` (profils de qualité, étalonnage, feux) ;
habillage des zones : `tools/world/build-world.luau` (section « HABILLAGE ») ; carrosseries :
`src/server/Vehicles/BodyKits.luau`.

## 1. Intention

Style **semi-réaliste sobre** (§9.1) : volumes simples et lisibles, proportions automobiles crédibles, matériaux
Roblox de base (aucune texture importée), couleurs franches mais pas saturées. La voiture reste le sujet : le décor
accompagne sans distraire, et rien de décoratif ne bloque la conduite (accessoires d'habillage non collidables).

Originalité : tout est construit par code dans ce dépôt (pièces de base, générateur déterministe, sons
synthétisés). Aucun modèle, interface, texture, son ou donnée d'un autre projet (notamment Collectverse et Mimic
Hunters), aucun actif Marketplace.

## 2. Véhicules

- Dix silhouettes (`Micro`, `Hatch`, `Sedan`, `Wagon`, `Coupe`, `Roadster`, `Supercar`, `SUV`, `OffRoad`,
  `Pickup`) définies par quelques fractions (capot, bouclier, fin de toit, poupe, ligne de ceinture, garde au sol).
- Teintes : couleur de caisse par modèle, accent (calandre, filets), garnissage intérieur sombre ; vitrages
  teintés translucides ; chromes absents (matériaux `SmoothPlastic`, `Glass`, `Metal`).
- Feux : phares blanc chaud, feux arrière rouges ; la nuit, les pièces deviennent lumineuses (`Neon`) et les
  sources de lumière réelles sont réservées aux véhicules les plus proches.
- Niveaux de détail : coque, vitrages, toit et roues toujours visibles ; calandre, rétroviseurs, filets,
  montants, roue de secours, pied d'aileron, combiné, console et dossiers (dossier `Details`) masqués selon la
  distance et la qualité.

## 3. Zones (palette et accessoires)

| Zone | Palette dominante | Accessoires d'habillage (générés le long des routes) |
|---|---|---|
| Métropole | béton gris, métal anthracite, lumière chaude | lampadaires, abris de bus, jardinières, potelets |
| Banlieues | verts de haie, jaune de boîte aux lettres, crème | lampadaires, haies, boîtes aux lettres, arbres |
| Docks | rouille, bleu et jaune de conteneurs | conteneurs empilés, caisses, lampadaires froids |
| Montagnes | vert sombre, ardoise, rouge des jalons | conifères, rochers, jalons à neige |
| Campagne | paille, vert tendre, bois | bottes de foin, clôtures, peupliers |
| Motorsport | noir pneu, blanc, rouge | piles de pneus, banderoles sans marque, postes de commissaires |
| Littoral | vert palme, rouge et bleu de parasols | palmiers, parasols, lampadaires froids |

Volumes générés (exécution du 2026-11-03, `lune run tools/world/build-world.luau …`) : Métropole 900,
Banlieues 900, Docks 400, Montagnes 498, Campagne 600, Motorsport 300, Littoral 400 accessoires, soit
3 998 accessoires et environ 10 400 pièces supplémentaires (carte : 47 653 pièces). Génération déterministe
(empreinte identique sur deux exécutions).

## 4. Lumière et heure

- Étalonnage par images clés (0 h, 6 h, 9 h, 13 h, 18 h, 20 h 30) : ambiance, ambiance extérieure, teinte,
  contraste, saturation, compensation d'exposition ; interpolation linéaire.
- Feux allumés de 19 h 30 à 6 h 45, par brouillard (densité ≥ 0,4) ou forte pluie.
- Effets selon la qualité : correction colorimétrique et bloom (moyenne, haute), rayons du soleil (haute).
- **Aucun effet sur la conduite** : l'adhérence ne dépend que de l'humidité de chaussée (`AWRoadWetness`,
  lot 0.3) ; la météo n'est pas modifiée une seconde fois par le rendu.

## 5. Qualité graphique (préférence du joueur)

| Réglage | Basse | Moyenne (défaut) | Haute |
|---|---|---|---|
| Habillage des zones visible jusqu'à | masqué | 180 m | 350 m |
| Détails de carrosserie jusqu'à | masqués | 120 m | 250 m |
| Véhicules avec sources de lumière | 0 | 4 | 8 |
| Lampadaires avec source de lumière | 0 | 12 | 24 |
| Couches sonores moteur | 2 | 3 | toutes |
| Véhicules observés sonorisés | 0 | 3 | 6 |
| Effets (étalonnage, bloom, rayons) | aucun | étalonnage, bloom | tous |

Les réglages graphiques ne modifient ni la physique, ni le réseau, ni la sécurité. Les objectifs de 24 joueurs et
≈ 60 images/s ne sont **pas** déclarés atteints : aucune mesure de performance n'a été faite (lot QA).

## 6. Interface

Thème du lot 0.7 inchangé (`UITheme` : panneaux sombres, accent ambre, focus bleu visible, contraste élevé en
option). Icônes : glyphes texte (aucune image importée). Le lot 0.8 ajoute les écrans du parcours d'arrivée, les
applications Radio, Photo et Guide du téléphone, la page Graphismes et le panneau du mode photo.
