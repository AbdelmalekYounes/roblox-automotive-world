# UI PREMIUM V1.2 — dossier de lancement (préparation, chantier NON commencé)

Préparé le 2026-11-05 à la demande du propriétaire (« priorité officielle V1.0 », priorité 2 : interfaces, après la
Comète). **Aucun code d'interface n'est écrit dans ce dossier.** Le chantier commence sur décision du propriétaire,
après la clôture de VEH3D-01 (PR #16 validée et fusionnée par lui, règle CLAUDE.md).

## 1. Point de départ (existant, vérifié dans le dépôt)

| Élément | Où | État |
|---|---|---|
| Thème | `src/client/UI/UITheme.luau` (134 lignes) | panneaux sombres, accent ambre, focus bleu, contraste élevé en option, police Gotham, coins arrondis ; dessiné par code, aucune image |
| Gestion des écrans | `UIManager`, `UIStack`, `UIState`, `InputRouter` | modale, plein écran bloqué en mouvement (AUD-UI-01), retour par Retour / bouton B, conduite capturée par une modale |
| Écrans existants | 21 modules dans `src/client/UI` | HUD, téléphone (applications, paramètres, crédits), GPS, carte, garage, économie, courses, social, notifications, parcours d'arrivée, mode photo, choix de silhouette |
| Références écrites | `docs/lot-0.7/ARCHITECTURE_LOT_0.7.md` (§2 à §9), `docs/lot-0.8/DIRECTION_ARTISTIQUE.md` §6, cahier des charges chapitre CH07, décisions AUD-UI-01 et AUD-UI-02, AUD-INPUT-01, AUD-ACCESS-01 | « direction visuelle provisoire » (lot 0.7) ; assets définitifs annoncés au lot 0.8 mais restés en glyphes texte |
| Essais | sessions VM `ui`, `ui_monde`, `ui_marche` (vrais clics, `GuiDriver`) | parcours vérifiés par vrais clics (lot 0.9.1) |

**Maquettes graphiques** : aucune maquette d'interface (image, fichier de conception) n'a été trouvée dans le dépôt de
jeu. Le dépôt d'art contient des emblèmes de marques (SVG), pas d'écrans. Les « maquettes existantes » citées par la
demande sont donc à fournir ou à désigner par le propriétaire (§4), sinon la base est le thème actuel et les documents
ci-dessus.

## 2. Ordre proposé par le propriétaire, découpé en lots

| Lot | Contenu | Livrable vérifiable |
|---|---|---|
| UI-1 | Système de conception : composants (boutons, listes, onglets, cartes, champs, jauges), typographie, couleurs, espacements, navigation, états (focus, désactivé, attente, erreur) | bibliothèque de composants + page de démonstration Studio ; tests Lune des jetons ; captures |
| UI-2 | HUD automobile | vitesse, rapport (dont N et R), énergie, dégâts, aides, mini-carte ; niveaux Minimal / Standard / Complet |
| UI-3 | Smartphone et paramètres | applications, paramètres, crédits ; manette et clavier |
| UI-4 | GPS, carte, navigation | itinéraire, guidage, carte plein écran |
| UI-5 | Garage et réglages | peinture, finition, pièces, confirmations serveur (AUD-UI-02) |
| UI-6 | Concessions et catalogue | fiches, comparatif, essai, achat confirmé par le serveur |
| UI-7 | Courses, métiers, progression | inscriptions, résultats, récompenses |
| UI-8 | Menus, notifications, écrans secondaires | arrivée, social, mode photo |
| UI-9 | Clavier, souris, manette | indications selon le périphérique actif, aucune action involontaire (AUD-INPUT-01) |
| UI-10 | Ergonomie et performances | essais de lisibilité, temps d'image des interfaces, résolutions |

Chaque lot suit la règle du projet : branche `feat/ui-…`, tests, rapport factuel, PR validée par le propriétaire.

## 3. Méthode pour chaque interface

- **Interactions réelles** : vrais clics et vraies touches dans la VM (`GuiDriver`), manette simulée si possible ;
  limites connues : touches O et Ctrl jamais reçues dans Studio.
- **Résolutions** : au moins 1280 × 720, 1920 × 1080, 2560 × 1440 et un format téléphone (Studio : émulation d'appareil),
  captures comparées ; aucun texte coupé ni bouton hors écran (défaut QA-F13 du lot 0.9.1).
- **Échanges serveur** : toute action sensible confirmée par le serveur, sans double exécution (AUD-UI-02) ; état
  « en attente » visible ; les textes restent des clés FR / EN.
- **Accessibilité** : taille du texte, contraste élevé, animations réduites (préférences existantes).
- **Non-régression** : sessions `ui`, `ui_monde`, `ui_marche` relancées à chaque lot.

## 4. Questions pour le propriétaire avant de commencer

1. Maquettes : en existe-t-il (fichiers, captures, références) ? Sinon, la direction actuelle (sombre, ambre) est-elle
   la base, ou faut-il d'abord une planche de style à valider ?
2. Icônes : garder des glyphes texte, ou produire des icônes (images à envoyer sur Roblox par le propriétaire) ?
3. Plateformes prioritaires de la V1.2 : PC et console (cahier des charges), le téléphone tactile en second ?
4. Ordre des lots : celui du §2, ou le HUD avant le système de conception ?

## 5. Préalables

- VEH3D-01 clôturé : PR #16 validée et fusionnée par le propriétaire.
- Les PR précédentes (#9 à #15) sont toujours en brouillon et non fusionnées : la base de la branche UI est à
  désigner par le propriétaire.
