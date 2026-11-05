# UI PREMIUM V1.2 — ce que le propriétaire doit vérifier

Branche `feat/ui-premium-v1.2` (PR #17). Liste rédigée le 2026-11-05, après l'arrêt des essais automatiques demandé
par le propriétaire. Cocher au fur et à mesure ; noter tout écart avec une capture.

**Préparation** : `rojo build default.project.json -o build\AutomotiveWorld.rbxlx`, ouvrir la place dans Studio, Jouer.
Pour le monde ouvert : `rojo build openworld.project.json -o build\OpenWorld.rbxlx`. Profil neuf : passer
l'introduction, choisir une silhouette (si « apparence en chargement » s'affiche, recliquer après 2 s).

## 1. Garage (touche P)

À faire d'abord hors garage, puis au **garage public d'essai** (préparation et configurations permises).

- [ ] Barre haute : « GARAGE », lieu exact (« Hors garage · consultation », « Garage public », « Propriété · garage
      privé »), badge « BROUILLON NON ENVOYÉ » seulement quand un réglage ou une teinte diffère de l'enregistré.
- [ ] Collection : cartes avec vignette 3D en vue 3/4, rangement (RANGÉ / EXPOSÉ / SORTI), nom, catégorie et
      motorisation, étiquettes ; clic sur une carte → onglet Véhicule de ce véhicule.
- [ ] Véhicule de départ (profil neuf) : boutons sans débordement ; clic → **confirmation** « Ce choix est définitif »,
      « Annuler » ne fait rien.
- [x] Zone 3D : cliquer-glisser fait tourner le véhicule ; molette = zoom ; boutons 3/4, Avant, Arrière, Profil ;
      case « Rotation automatique » ; « Réinitialiser » ; flèches à l'écran retirées (validé par le propriétaire le
      2026-11-05).
- [ ] Véhicule : 4 cellules d'état, fiche technique (valeurs plausibles, rien d'inventé), raisons sous la barre
      d'actions quand Sortir / Exposer / Ranger sont grisés.
- [ ] Préparation › Réglages : glissière (clic et glisser), boutons − et + ; valeur en ambre si modifiée ;
      « Appliquer le brouillon » → bandeau EN ATTENTE puis CONFIRMÉ ; « Annuler le brouillon » remet tout.
- [ ] Préparation › Esthétique : la teinte de caisse change **en direct** sur le véhicule 3D ; accessoires limités à 2.
- [ ] Préparation › Pièces : pièces non possédées grisées avec raison ; hors garage public, raison affichée.
- [ ] Configurations : saisir un nom, « Enregistrer ici » → carte « 1. <nom> » ; « Supprimer » → confirmation.
- [ ] Retour arrière : Préparation → Véhicule → Collection → fermeture. PageUp / PageDown changent d'onglet.
- [ ] Comète : l'acheter à la concession d'essai (achetable en développement), puis la sélectionner au garage :
      maillages 3D dans la zone 3D et dans la vignette de sa carte.

## 2. Smartphone (touche T)

- [ ] Accueil : 12 icônes (Carte en cyan, autres en ambre), pastille de notifications.
- [ ] Ouvrir chacune des 12 applications : titre exact, titres de section, cartes à filet de couleur, boutons avec
      valeur à droite, aucun texte coupé ; « Retour » revient à l'accueil.
- [ ] Véhicules : une carte par véhicule (catégorie · rangement · réserve), bouton « Garage et collection » (P).
- [ ] Paramètres : chaque réglage « libellé | valeur » change au clic (langue, niveau du HUD, accessibilité…).
- [ ] **En conduite** (prototype P-01, accélérer au-delà de 15 km/h, puis T) : étiquette « MODE RAPIDE »,
      itinéraire, encadré « écran complet à l'arrêt », aucun bouton sélectionnable ; P (garage) refusé ; à l'arrêt,
      l'écran complet revient.

## 3. Économie (J) et courses (K)

- [ ] Plein écran, onglets à filet ambre, cartes ; boutons grisés : la raison doit être compréhensible.
- [ ] Concession (invite E devant la concession d'essai) : « Devis d'achat » → confirmation avec le montant ;
      « Annuler » sans effet ; second devis → la confirmation revient ; « Confirmer » → achat confirmé par le serveur.
- [ ] Métiers : « Démarrer » → mission en cours (carte cyan) ; « Abandonner » → confirmation ; bandeau de mission et
      flèche de guidage (chevron) en haut de l'écran.
- [ ] Courses : « Détails » d'un parcours, « Officielle » loin du point d'inscription → bandeau REFUSÉ avec le motif.
- [ ] La mini-carte ne recouvre plus ces panneaux.

## 4. HUD, carte, notifications

- [ ] En conduite : tableau en carte, vitesse en chiffres et « KM/H » à côté, rapport en ambre, jauges ; mini-carte
      **ronde** (itinéraire cyan, flèche blanche, repères dessinés : lettres G F E W $, carré, losange, damier).
- [ ] Carte (M) : titre « CARTE », destination en cyan, lieux sur deux lignes avec distance ; choisir un lieu
      éloigné → guidage en carte à filet cyan pendant la conduite. **Monde ouvert** : routes visibles sur la carte.
- [ ] Notifications : cartes à filet (cyan information, ambre avertissement, rouge critique), aucun pictogramme.
- [ ] Mode photo (par le téléphone) : barre en carte sombre ; arrivée et formation : états « Réussi » / « À faire ».

## 5. Résolutions et accessibilité

- [ ] 1280 × 720 (disposition compacte), 1920 × 1080, 2560 × 1440 (tout agrandi de 1,333, rien ne déborde),
      ultralarge 3440 × 1440 (contenu centré). Vérifier garage, téléphone, économie, HUD.
- [ ] Paramètres › Accessibilité : taille du texte 80 à 150 %, contraste renforcé, réduire les animations (le véhicule
      du garage ne tourne plus seul).

## 6. Manette (non testée automatiquement)

- [ ] Select ouvre le garage ; LB / RB changent d'onglet ; stick droit tourne le véhicule ; B revient d'un niveau ;
      contour ambre de focus visible sur chaque bouton ; les tuiles du téléphone sont atteignables.

## 7. Points ouverts à trancher par le propriétaire

- Propositions sans maquette à valider : économie, courses, HUD, carte, notifications, arrivée, photo.
- Écarts de maquette : vue « Intérieur », graphique « effet estimé », 0–100 et v60 absents ; pièces posées dès la
  demande ; « Fermer » du garage dans la barre d'aide.
- Bras levé en marchant avec le téléphone (monde ouvert) : 8° mesurés contre 25° attendus, cause non établie —
  à regarder en marchant avec le téléphone ouvert.

## 8. Retours du propriétaire du 2026-11-05

Validé par le propriétaire : garage, confirmations de l'économie et des métiers, fluidité de la mini-carte, routes
rognées au cercle de la mini-carte, courses. Grande carte : conservée en l'état pour l'instant.

Corrigé ensuite (contrôles statiques au vert), puis **validé par le propriétaire en jeu le 2026-11-05** (« c'est bon ») :

- [x] **Flèche du joueur** (mini-carte et grande carte) : flèche de navigation blanche pointue à base échancrée,
      contour sombre, dessinée ligne par ligne au pixel (l'ancienne ressemblait à un « A »). Vérifier qu'elle suit le
      cap en tournant, sans couture visible. Aperçu calculé (pas une capture du jeu) : `apercu_fleche_joueur.png`.
- [x] Si un **disque sombre** reste visible sous la flèche à l'arrêt, noter l'endroit : c'est probablement le repère
      d'un lieu à cet emplacement (non établi).
- [x] **Téléphone, accueil** : la première rangée d'icônes commence sous les boutons ronds « + » et « × » ; le nom de
      chaque application est plus près de son icône ; le dock reste en bas sans chevaucher la grille.
- [x] **Téléphone, applications** : chevron « < » à gauche de « Accueil » sans chevauchement ; grand titre sous la
      ligne « Accueil » / « + » / « × » ; contenu sous le titre. En conduite, l'étiquette « MODE RAPIDE » est alignée
      sur le titre.
