# Direction artistique des 18 véhicules

Statut : **proposition** ; catalogue toujours **proposé** (`PendingApproval`). Les références réelles sont des
**références de direction artistique choisies par le propriétaire**, pas des modèles à reproduire.

Légende de chaque fiche : **[observé]** vu sur les images du manifeste du véhicule (planches inspectées le
2026-11-04, liste dans `SOURCES_IMAGES.md`) ; **[jeu]** valeur du code ou mesurée dans le moteur ; **[proposé]**
décision artistique à valider. Ce qui n'a pas été vu sur une image est signalé comme tel.

## 1. Règles communes de transformation

Le cahier des charges impose des véhicules **fictifs**, sans emploi non autorisé de marques, logos ou signatures
protégés (`docs/CAHIER_DES_CHARGES_GLOBAL_v1.0.md`, §1). Pour chaque modèle :

- **Retenir** : la catégorie, les proportions générales, l'architecture de l'habitacle, l'esprit (sportif, utilitaire…).
- **Transformer** : calandre, phares et feux, signature lumineuse, montants, boucliers, jantes, planche de bord —
  aucun de ces éléments n'est reproduit à l'identique.
- **Inventer** : langage de design commun d'Automotive World (signature lumineuse, monogramme, détails), couleurs,
  garnissages, noms et inscriptions fictifs.
- **Interdit** : logos, noms et typographies des constructeurs, plaques réelles, textures issues des photographies.
- Revue de **dissemblance** à chaque porte de validation : vue de profil et de face superposées à la référence.

## 1 bis. Langage commun de la gamme

**Décisions du propriétaire (2026-11-04)** : **plusieurs marques fictives** ; **signature lumineuse propre à chaque
famille** (pas de motif commun à toute la gamme). **Répartition des modèles en quatre marques validée par le
propriétaire (2026-11-04)** ; pistes de signature et emblèmes : **[proposé]**, à dessiner puis valider.

| Marque (nom validé) | Rôle | Modèles | Piste de signature lumineuse (famille) | Emblème |
|---|---|---|---|---|
| **Mivale** | généraliste urbaine | Pixel, Brio, Fil, **Aster**, Rafale | deux traits en « L » aux angles (déjà retenus pour l'Aster « Trait ») | deux équerres en « L » aux angles opposés, carré central |
| **Orvane** | routière et familiale | Nova, Cadence, Lumen, Orée | trait horizontal fin terminé par un point lumineux à l'intérieur, interrompu au centre (jamais de bandeau continu) | deux traits horizontaux décalés, chacun terminé par un point |
| **Rocalt** | aventure | Dune, Vigie, Sentier, Atlas | blocs lumineux carrés à deux étages verticaux, protégés par un cadre | écusson à sommet plat, deux blocs superposés |
| **Celvar** | sport et prestige | Brise, Éclat, Mistral, Comète, Zénith | trois traits obliques courts, inclinés vers l'arrière | lame hexagonale allongée coupée par une entaille oblique |

Règles :

- **Noms de marque** : **validés par le propriétaire le 2026-11-04** (Mivale, Orvane, Rocalt, Celvar) après une **vérification
  préliminaire** sur le web (aucune marque ni véhicule de ces noms trouvé ; détail et noms écartés dans
  `brands/BRANDS.md` du dépôt d'art) ; **recherche d'antériorité officielle (EUIPO, INPI, USPTO, OMPI ; classes 12, 9,
  41) à faire avant tout usage commercial**. « Automotive World » étant un nom technique provisoire, aucune marque n'en
  dérive.
- **Emblèmes** : **validés par le propriétaire le 2026-11-04** ; formes géométriques originales sans lettres (SVG dans `brands/<marque>/` du dépôt d'art), à comparer
  aux emblèmes déposés avant usage commercial ; plaques
  et inscriptions fictives.
- **Unité entre marques** : seuls des éléments techniques communs (gabarit d'habitacle, pose assise, combinés et
  commandes génériques) ; chaque marque garde ses formes, ses couleurs et ses jantes.
- **Électriques** (Pixel, Fil, Orée, Zénith) : pas d'identité « électrique » transversale ; chaque marque traite
  l'électrique dans son propre langage (repère discret, à proposer).
- Dans les fiches ci-dessous, « AW » désigne **la marque fictive du modèle** selon ce tableau.

## 2. Habitacles provisoires et avatars R15 (point de départ chiffré)

Assise → pavillon des carrosseries provisoires [jeu, `lune run tests/lune/tools/cabin-geometry.luau`, 2026-11-04] et
dégagement de la tête de la référence R15 sous le pavillon [jeu, AVATAR-01, `20261104-111326`]. Cible minimale de la
spécification : **≥ 4,30 st**.

| Modèle | Silhouette | Assise → pavillon | Écart à la cible minimale | Tête de la référence sous le pavillon |
|---|---|---|---|---|
| Pixel (`wk_pixel`) | Micro | 3,53 st | -0,77 st | -0,13 st |
| Brio (`wk_brio`) | Hatch | 3,3 st | -1,00 st | -0,37 st |
| Fil (`wk_fil`) | Hatch | 3,46 st | -0,84 st | -0,21 st |
| Aster (`wk_aster`) | Hatch | 3,11 st | -1,19 st | -0,56 st |
| Nova (`wk_nova`) | Sedan | 3,1 st | -1,20 st | -0,57 st |
| Cadence (`wk_cadence`) | Sedan | 3,02 st | -1,28 st | -0,65 st |
| Lumen (`wk_lumen`) | Wagon | 3,19 st | -1,11 st | -0,48 st |
| Orée (`wk_oree`) | Sedan | 2,87 st | -1,43 st | -0,80 st |
| Brise (`wk_brise`) | Roadster | ouvert | — | sans pavillon |
| Rafale (`wk_rafale`) | Hatch | 2,88 st | -1,42 st | -0,78 st |
| Éclat (`wk_eclat`) | Coupe | 2,49 st | -1,81 st | -1,18 st |
| Mistral (`wk_mistral`) | Coupe | 2,44 st | -1,86 st | -1,22 st |
| Comète (`wk_comete`) | Supercar | 2,2 st | -2,10 st | -1,46 st |
| Zénith (`wk_zenith`) | Supercar | 2,27 st | -2,03 st | -1,39 st |
| Dune (`wk_dune`) | SUV | 3,59 st | -0,71 st | -0,07 st |
| Vigie (`wk_vigie`) | SUV | 3,77 st | -0,53 st | +0,10 st |
| Sentier (`wk_sentier`) | OffRoad | 3,75 st | -0,55 st | +0,09 st |
| Atlas (`wk_atlas`) | Pickup | 4,0 st | -0,30 st | +0,33 st |

Tous les habitacles fermés sont **sous la cible minimale** ; les plus bas (Éclat, Mistral, Comète, Zénith) de près de 2 st. Décision D1 (spécification §3.3).

## 3. Fiches des 18 véhicules

Chaque fiche renvoie à son manifeste `references/<id>/MANIFEST.md` (images, angles vérifiés, auteurs, licences).
« Non observé » : aucune image du manifeste ne montre cet élément. Les directions de chaque fiche sont des pistes ; la
direction détaillée n'est rédigée que pour l'Aster (`ASTER_DESIGN_BRIEF.md`).

### 3.1 Pixel (`wk_pixel`) — réf. Smart EQ Fortwo

- Jeu : citadine électrique 2 places, 3,15 × 1,62 × 1,55 m, empattement 2,1 m ; silhouette provisoire `Micro`.
- Extérieur [observé] : volume très court et haut, porte-à-faux quasi nuls, capot minuscule et pare-brise très avancé ;
  roues aux quatre coins ; phares en amande sur les ailes, calandre à motif alvéolé ; cellule de sécurité contrastée
  autour de l'habitacle (bicolore) ; feux arrière verticaux aux angles, hayon vitré.
- Intérieur : **non observé** (aucune image retenue).
- Retenir : « cube » deux places, cellule bicolore lisible. Transformer : phares, motif de calandre, cellule de
  sécurité (dessin propre). Inventer : signature lumineuse AW, jantes, intérieur complet.
- R15 : tête de la référence 0,13 st au-dessus du pavillon provisoire ; habitacle haut par nature, cible confort
  accessible.

### 3.2 Brio (`wk_brio`) — réf. Hyundai i10 N Line

- Jeu : citadine 5 portes, 3,8 × 1,7 × 1,5 m (2,45) ; `Hatch`.
- Références : **génération i10 AC3** (finitions courantes ; la finition N Line n'est pas identifiée sur les images).
- Extérieur [observé] : petite cinq portes haute, capot court, vitrage latéral en trois parties, hayon presque vertical ;
  phares étirés vers les ailes, calandre large et basse ; feux arrière horizontaux qui entrent dans le hayon.
- Intérieur [observé] : planche de bord horizontale simple, écran central posé, aérateurs ronds aux extrémités, levier
  de vitesses manuel.
- Retenir : citadine « pratique » à gros vitrage. Transformer : calandre, feux, aérateurs. Inventer : version sportive
  propre (teintes, jupes) puisque la référence N Line n'est pas documentée par l'image.
- R15 : −0,37 st sous la référence ; cible minimale : +1,0 st d'habitacle.

### 3.3 Fil (`wk_fil`) — réf. Renault 5 E-Tech Electric

- Jeu : citadine électrique, 4,05 × 1,76 × 1,56 m (2,58) ; `Hatch`.
- Extérieur [observé] : citadine néo-rétro trapue, capot court surélevé avec bossage, phares rectangulaires à coins
  arrondis, petits feux de jour carrés dans le bouclier, passages de roues marqués, toit bicolore (salon), hayon court
  avec bandeau noir et signature arrière graphique.
- Intérieur [observé] : écrans combiné et central en un seul bloc incliné vers le conducteur, volant à méplat, garnissage
  textile coloré, console flottante.
- Retenir : ton néo-rétro joyeux, proportions trapues. Transformer : bossage de capot, phares, signature arrière,
  inscriptions (aucune). Inventer : clin d'œil « héritage » propre à AW.
- R15 : −0,21 st ; habitacle assez haut, cible minimale +0,84 st.

### 3.4 Aster (`wk_aster`) — réf. Volkswagen Golf VIII — **véhicule pilote**

Voir `ASTER_DESIGN_BRIEF.md` (fiche complète, trois directions, habitacle, budget, validation).

### 3.5 Nova (`wk_nova`) — réf. Nissan Versa

- Jeu : compacte tricorps, 4,4 × 1,76 × 1,46 m (2,64) ; `Sedan`.
- Extérieur [observé] : berline compacte basse, capot plongeant, grande calandre en « V » encadrée de chrome, phares
  effilés en boomerang, ligne de vitrage qui plonge vers une malle courte (allure de coupé), feux arrière en boomerang.
- Intérieur [observé] : planche de bord horizontale, écran central encastré au-dessus des commandes, aérateurs ronds,
  coutures contrastées.
- Retenir : berline « accessible » au profil fluide. Transformer : calandre en V, phares boomerang. Inventer : face
  avant AW, jantes.
- R15 : −0,57 st ; cible minimale +1,2 st (pavillon de berline à relever).

### 3.6 Cadence (`wk_cadence`) — réf. Peugeot 508 II

- Jeu : berline, 4,8 × 1,83 × 1,46 m (2,8) ; `Sedan`.
- Références : berline (et une vue de la version break, notée).
- Extérieur [observé] : berline-coupé basse et large, capot long et plat, vitres sans encadrement, phares fins
  prolongés par des feux de jour verticaux en « crocs », calandre large à motif, feux arrière en bandeau noir horizontal
  sur toute la largeur.
- Intérieur [observé] : petit volant bas, combiné numérique **au-dessus** du volant, écran central, rangée de touches
  façon piano, console haute.
- Retenir : berline basse et tendue, « haute couture ». Transformer : feux de jour verticaux, bandeau arrière, poste de
  conduite à petit volant (signature distinctive). Inventer : architecture de planche de bord propre.
- R15 : −0,65 st ; cible minimale +1,28 st.

### 3.7 Lumen (`wk_lumen`) — réf. Škoda Octavia Combi

- Jeu : break, 4,7 × 1,82 × 1,5 m (2,75) ; `Wagon`.
- Extérieur [observé] : break long au pavillon horizontal, hayon incliné, phares fins encadrant une calandre droite à
  lames verticales, nervure de capot, feux arrière effilés qui entrent dans le hayon, vitrage arrière prolongé.
- Intérieur : **non observé**.
- Retenir : break familial sobre et long. Transformer : calandre à lames, feux en pointe. Inventer : intérieur,
  galerie de toit, signature AW.
- R15 : −0,48 st ; cible minimale +1,11 st ; le pavillon horizontal facilite la hauteur sur toute la longueur.

### 3.8 Orée (`wk_oree`) — réf. Hyundai Ioniq 6

- Jeu : berline électrique, 4,95 × 1,9 × 1,45 m (2,95) ; `Sedan`.
- Extérieur [observé] : profil en arche continue (« goutte d'eau »), capot très court et bas, poupe effilée avec double
  aileron, feux arrière en bandeau fin, signature lumineuse avant et arrière en petits éléments (« pixels »),
  rétroviseurs à caméra.
- Intérieur [observé] : écrans combiné et central dans un même bandeau, volant à quatre points lumineux, console haute.
- Retenir : silhouette aérodynamique fluide. Transformer : **signature en pixels** et volant à points (très
  distinctifs), double aileron. Inventer : signature lumineuse AW non pixelisée.
- R15 : −0,80 st ; profil en arche : la hauteur sous pavillon chute vers l'arrière.

### 3.9 Brise (`wk_brise`) — réf. Mazda MX-5 ND

- Jeu : roadster, 3,95 × 1,73 × 1,24 m (2,35) ; `Roadster` (ouvert).
- Extérieur [observé] : roadster court à capot long et bas, habitacle reculé, ailes avant saillantes, phares étroits,
  bouche avant pentagonale, feux arrière ronds-allongés, capote souple (et une version à toit rigide).
- Intérieur [observé] : habitacle étroit pour deux, tunnel central haut, aérateurs ronds, écran posé, volant à trois
  branches.
- Retenir : petit roadster « pur », capot long. Transformer : bouche avant, feux arrière, ailes. Inventer : arceaux,
  couleurs, jantes.
- R15 : pas de pavillon ; jambes/planche de bord 0,55 st : habitacle à allonger vers l'avant ; tête au vent (aucun
  toit à traverser, la capote fermée devra suivre la cible).

### 3.10 Rafale (`wk_rafale`) — réf. Volkswagen Golf GTI Clubsport

- Jeu : sportive compacte, 4,3 × 1,8 × 1,43 m (2,65) ; `Hatch`.
- Références : une vue **Clubsport**, les autres **Golf VIII GTI** (version voisine) ; même base que l'Aster.
- Extérieur [observé] : compacte cinq portes abaissée, grand aileron de pavillon, filet rouge sur la calandre, bas de
  caisse et décors latéraux, jantes de grand diamètre, double sortie d'échappement.
- Intérieur [observé] : sièges baquets à appuie-tête intégrés, garnissage gris à surpiqûres rouges, combiné et écran en
  bandeau, volant sport.
- Retenir : « Aster sportive » (plate-forme commune, décision de gamme). Transformer : filet rouge, décors,
  aileron. Inventer : version sportive de Mivale (l'Éclat relève de Celvar).
- R15 : −0,78 st ; partage l'habitacle de l'Aster (même cible).

### 3.11 Éclat (`wk_eclat`) — réf. Toyota GR86

- Jeu : coupé sportif 2+2, 4,45 × 1,82 × 1,32 m (2,6) ; `Coupe`.
- Extérieur [observé] : coupé bas, capot long, ailes avant galbées avec ouïes latérales, grande bouche avant en
  trapèze, phares étirés, poupe courte et haute, petit becquet, double échappement.
- Intérieur [observé] : poste de conduite simple, combiné numérique, tunnel haut avec levier manuel, sièges sport.
- Retenir : coupé propulsion « accessible » aux proportions classiques. Transformer : bouche avant, ouïes, feux.
  Inventer : signature sportive AW.
- R15 : −1,18 st ; habitacle très bas (cible minimale +1,81 st) : décision D1 critique.

### 3.12 Mistral (`wk_mistral`) — réf. Aston Martin DB11 V8

- Jeu : coupé GT, 4,75 × 1,92 × 1,33 m (2,8) ; `Coupe`.
- Références : version (V8 ou V12) non identifiée sur les images ; une vue cabriolet.
- Extérieur [observé] : GT longue au capot très long, calandre caractéristique de la marque, ouïes d'aile, vitrage
  latéral étiré, poupe tombante avec feux fins en forme d'aile, épaules arrière larges.
- Intérieur [observé] : console centrale haute, volant sport, garnissages cuir (conduite à droite).
- Retenir : proportions de grande GT (capot long, habitacle reculé). Transformer : **calandre et feux, très
  identifiables** : à réinventer entièrement. Inventer : face avant AW de prestige.
- R15 : −1,22 st ; cible minimale +1,86 st.

### 3.13 Comète (`wk_comete`) — réf. McLaren 720S

- Jeu : supercar, 4,55 × 2,0 × 1,18 m (2,7) ; `Supercar`.
- Références : versions de série et dérivées en salon ; versions de course écartées.
- Extérieur [observé] : moteur central, cockpit en bulle très avancé, phares enfoncés dans des orbites qui servent de
  prises d'air, flancs creusés, poupe large et ajourée (portes ouvertes et aileron en position non observés).
- Intérieur : **non observé**.
- Retenir : supercar à cockpit-bulle, flancs creusés. Transformer : **orbites des phares** (signature majeure),
  flancs creusés. Inventer : intérieur, signature avant AW.
- R15 : habitacle le plus bas du catalogue (2,20 st ; −1,46 st sous la référence) : la cible minimale demande +2,1 st
  ou une pose de conduite très allongée (D1, D3).

### 3.14 Zénith (`wk_zenith`) — réf. Rimac Nevera

- Jeu : supercar électrique, 4,7 × 2,02 × 1,2 m (2,8) ; `Supercar`.
- Références : Nevera (dont une série anniversaire) et le prototype C_Two qui l'a précédé (noté).
- Extérieur [observé] : supercar basse au capot sculpté de prises d'air, phares fins, flancs creusés, portes en élytre,
  poupe large à diffuseur, jantes de grand diamètre ajourées.
- Intérieur : **non observé** (visible seulement par une porte ouverte, sans détail exploitable).
- Retenir : supercar électrique sculptée. Transformer : capot, phares, diffuseur. Inventer : intérieur, traitement
  électrique propre à Celvar.
- R15 : 2,27 st, −1,39 st : mêmes enjeux que la Comète.

### 3.15 Dune (`wk_dune`) — réf. Mazda CX-5

- Jeu : SUV compact, 4,45 × 1,84 × 1,66 m (2,68) ; `SUV`.
- Extérieur [observé] : SUV aux surfaces lisses et sculptées, grande calandre pentagonale entourée d'un trait chromé qui
  rejoint les phares fins, protections de passages de roues noires, ligne de vitrage montante, feux arrière fins.
- Intérieur [observé] : planche de bord horizontale, écran posé au sommet, aérateurs fins, console haute avec sélecteur.
- Retenir : SUV élégant et sobre. Transformer : calandre et trait chromé (signature). Inventer : face avant AW,
  protections, barres de toit.
- R15 : −0,07 st ; proche de la cible pour la référence (cible minimale +0,71 st).

### 3.16 Vigie (`wk_vigie`) — réf. BMW X5

- Jeu : grand SUV, 4,95 × 1,96 × 1,74 m (2,95) ; `SUV`.
- Références : dont une variante à hydrogène en livrée de salon (notée).
- Extérieur [observé] : grand SUV haut et massif, capot long, **double calandre** de grande taille (signature de
  marque), phares hexagonaux à doubles éléments, feux arrière en « L » très fins, vitrage plat.
- Intérieur [observé] : écrans combiné et central en un seul bloc incurvé, console large, sièges cuir.
- Retenir : grand SUV statutaire. Transformer : **double calandre et doubles phares** (à exclure absolument). Inventer
  : face avant AW de grand SUV.
- R15 : +0,10 st ; habitacle le plus proche de la cible (cible minimale +0,53 st).

### 3.17 Sentier (`wk_sentier`) — réf. Suzuki Jimny 5 portes

- Jeu : tout-terrain, 3,9 × 1,76 × 1,72 m (2,4) ; `OffRoad`.
- Extérieur [observé] : caisse cubique, capot plat et court, phares ronds encadrant une calandre à fentes verticales,
  passages de roues carrés surdimensionnés, roue de secours sur la porte arrière, feux arrière dans le bouclier.
- Intérieur [observé] : planche de bord très horizontale et fonctionnelle, écran central, poignée de maintien passager.
- Retenir : petit 4×4 cubique « outil ». Transformer : calandre à fentes, phares ronds (archétype courant, à
  redessiner). Inventer : protections, porte-bagages, roue de secours AW.
- R15 : +0,09 st ; caisse haute, cible minimale +0,55 st facile.

### 3.18 Atlas (`wk_atlas`) — réf. Ford Ranger

- Jeu : pick-up, 5,3 × 1,95 × 1,82 m (3,2) ; `Pickup`.
- Références : versions courantes et Raptor (notées).
- Extérieur [observé] : pick-up double cabine, face haute et verticale, phares en « C » encadrant une calandre large,
  capot haut et plat, passages de roues massifs, benne longue, feux arrière verticaux.
- Intérieur [observé] : grand écran central **vertical**, planche de bord horizontale, console large.
- Retenir : pick-up robuste à double cabine. Transformer : phares en « C », écran vertical, calandre. Inventer : benne
  et accessoires AW.
- R15 : +0,33 st ; seul modèle proche de la cible minimale (−0,30 st).
