# Catalogue des références — 18 véhicules

Association **sans ambiguïté** entre chaque véhicule fictif (identifiant interne et nom conservés) et sa référence
réelle de **direction artistique**, choisie par le propriétaire. Ces références ne sont pas des instructions de
reproduction (`DIRECTION_ARTISTIQUE_VEHICULES.md` §1) ; les caractéristiques physiques fictives des définitions du jeu
ne sont pas remplacées. Le catalogue reste **proposé** (`docs/lot-0.8/CATALOGUE_18_VEHICULES.md`, `PendingApproval`).

Le catalogue du lot 0.8 précisait que les modèles « ne reproduisent aucun véhicule » réel : les références ci-dessous
relèvent de la direction artistique et ne changent pas cette règle (aucune marque, aucun logo, aucune signature
distinctive reprise).

## 1. Correspondances et couverture

Recherche du 2026-11-04 sur Wikimedia Commons (licences libres) ; angles vérifiés à l'œil sur planches contact.

| ID interne | Véhicule fictif | Référence réelle | Silhouette provisoire | Images retenues | 3/4 AV | Profil | 3/4 AR | Face | Intérieur | Détail | Remarque |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `wk_pixel` | Pixel | Smart EQ Fortwo | Micro | [7](references/wk_pixel/MANIFEST.md) | ✔ | ✔ | ✔ | — | — | — | 1 vue de la génération électrique précédente |
| `wk_brio` | Brio | Hyundai i10 N Line | Hatch | [6](references/wk_brio/MANIFEST.md) | ✔ | — | ✔ | — | ✔ | — | génération i10 AC3 ; finition N Line non identifiée |
| `wk_fil` | Fil | Renault 5 E-Tech Electric | Hatch | [5](references/wk_fil/MANIFEST.md) | ✔ | — | — | — | ✔ | ✔ |  |
| `wk_aster` | Aster | Volkswagen Golf VIII | Hatch | [8](references/wk_aster/MANIFEST.md) | ✔ | ✔ | ✔ | — | ✔ | ✔ |  |
| `wk_nova` | Nova | Nissan Versa | Sedan | [6](references/wk_nova/MANIFEST.md) | ✔ | — | ✔ | ✔ | ✔ | — |  |
| `wk_cadence` | Cadence | Peugeot 508 II | Sedan | [7](references/wk_cadence/MANIFEST.md) | ✔ | — | ✔ | — | ✔ | — | 1 vue de la version break |
| `wk_lumen` | Lumen | Škoda Octavia Combi | Wagon | [6](references/wk_lumen/MANIFEST.md) | ✔ | ✔ | ✔ | — | — | — |  |
| `wk_oree` | Orée | Hyundai Ioniq 6 | Sedan | [8](references/wk_oree/MANIFEST.md) | ✔ | ✔ | — | ✔ | ✔ | ✔ |  |
| `wk_brise` | Brise | Mazda MX-5 ND | Roadster | [7](references/wk_brise/MANIFEST.md) | ✔ | — | ✔ | — | ✔ | ✔ |  |
| `wk_rafale` | Rafale | Volkswagen Golf GTI Clubsport | Hatch | [6](references/wk_rafale/MANIFEST.md) | ✔ | — | ✔ | — | ✔ | — | 1 vue Clubsport, autres Golf VIII GTI |
| `wk_eclat` | Éclat | Toyota GR86 | Coupe | [7](references/wk_eclat/MANIFEST.md) | ✔ | ✔ | ✔ | — | ✔ | — |  |
| `wk_mistral` | Mistral | Aston Martin DB11 V8 | Coupe | [8](references/wk_mistral/MANIFEST.md) | ✔ | — | ✔ | — | ✔ | ✔ | version V8/V12 non identifiée ; 1 cabriolet |
| `wk_comete` | Comète | McLaren 720S | Supercar | [5](references/wk_comete/MANIFEST.md) | ✔ | — | — | ✔ | — | — |  |
| `wk_zenith` | Zénith | Rimac Nevera | Supercar | [7](references/wk_zenith/MANIFEST.md) | ✔ | — | ✔ | — | — | ✔ | 2 vues du prototype C_Two |
| `wk_dune` | Dune | Mazda CX-5 | SUV | [7](references/wk_dune/MANIFEST.md) | ✔ | ✔ | ✔ | — | ✔ | — |  |
| `wk_vigie` | Vigie | BMW X5 | SUV | [7](references/wk_vigie/MANIFEST.md) | ✔ | — | ✔ | — | ✔ | ✔ |  |
| `wk_sentier` | Sentier | Suzuki Jimny 5 portes | OffRoad | [6](references/wk_sentier/MANIFEST.md) | ✔ | — | ✔ | — | ✔ | — |  |
| `wk_atlas` | Atlas | Ford Ranger | Pickup | [8](references/wk_atlas/MANIFEST.md) | ✔ | — | ✔ | — | ✔ | — |  |

**Total : 121 images retenues** (de 5 à 8 par véhicule) ; 18 écartées après revue visuelle (autre modèle, version de course, logo seul, doublon, hors sujet).

## 2. Images manquantes

- Intérieur : Pixel, Lumen, Comète, Zénith.
- Profil strict : Brio, Fil, Nova, Cadence, Brise, Rafale, Mistral, Comète, Zénith, Vigie, Sentier, Atlas.
- Vue de face ou de dos : Pixel, Brio, Fil, Aster, Cadence, Lumen, Brise, Rafale, Éclat, Mistral, Zénith, Dune, Vigie, Sentier, Atlas.
- Trois quarts arrière : Fil, Orée, Comète.
- Détail : Pixel, Brio, Nova, Cadence, Lumen, Rafale, Éclat, Comète, Dune, Sentier, Atlas.

Pistes : galeries officielles (liens dans `SOURCES_IMAGES.md` §2, conditions d'utilisation à vérifier, souvent un
compte de presse) ou photographies prises par le propriétaire ; aucune image n'est inventée.

## 3. Organisation

- `references/<id>/manifest.json` et `MANIFEST.md` : images retenues, écartées (avec la raison), angle vérifié,
  auteur, licence, URL, date de consultation, chemin local.
- Images : `E:/ROBLOX DEV/aw-vehicle-references/<id>/` (**hors dépôt, non suivi par Git** ; aucune photographie de
  tiers n'est versionnée).
- `references/coverage.json` : couverture calculée (source de ce tableau).
