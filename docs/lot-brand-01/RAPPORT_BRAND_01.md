# Lot BRAND-01 — Nom du jeu, logo et écran de chargement : rapport

- **Demande du propriétaire** (2026-11-06) : « il faudrait aussi un ecran de chargement du jeu avec un logo et un vrai
  nom pour le jeu ».
- **Branche** : `claude/brand-01-nom-logo-chargement-fc9fd1`, créée depuis `main` ff933df. Dépôt d'art : branche
  `brand-01-amberline` (depuis `origin/main` e6608e9), commit `dcf2aca`, dossier `E:\ROBLOX DEV\aw-art-brand01`.
  Rien n'a été poussé ; ni pull request ni fusion (session de coordination). Aucune publication Roblox.
- **Date** : 2026-11-06.
- **État** : nom et logo choisis par le propriétaire ; code et tests hors Studio terminés ; **logo pas encore envoyé
  sur Roblox** (l'écran affiche donc le titre en texte, repli prévu) ; **rien n'a été essayé dans Studio** (§7).

## 1. Décisions du propriétaire (2026-11-06)

Questions posées en une fois au début, puis choix du logo sur planche.

| Question | Décision |
| --- | --- |
| Nom du jeu (8 propositions vérifiées, §2) | **Amberline** |
| Style du logo | **Mot + symbole** |
| Contenu de l'écran en plus du logo et de la progression | **Phrase d'accueil** fixe (pas de conseils tournants) |
| Fond de l'écran | **Anthracite animé** (lignes de route ambre qui défilent lentement) |
| Piste de logo (3 dessinées) | **3 « Virage »** : route ambre en S vue du dessus + AMBERLINE en capitales |

Le nom technique du code (`AutomotiveWorld`, projets Rojo `AutomotiveWorld_Development` et `AutomotiveWorld_OpenWorld`,
dossiers `AutomotiveWorldClient/Server/First`) **n'est pas changé** (contrôle pytest). Le nom affiché vit dans
`src/first/Brand.luau` (`Brand.Name`).

## 2. Vérification des noms

Recherche web rapide du 2026-11-06 (jeu Roblox, autre jeu vidéo, marque évidente). **Ce n'est pas une recherche
officielle de marque** (registres EUIPO, INPI, USPTO, OMPI non consultés).

| Nom proposé | Résultat |
| --- | --- |
| **Amberline** (retenu) | aucun jeu ni marque de ce nom trouvé ; un studio de jeux « Amber » (Roumanie) existe, nom différent |
| Valcourt | aucun jeu ; vraie ville du Québec, berceau de Bombardier / BRP |
| Plein Phare | aucun jeu ni marque trouvé ; sens surtout français |
| Volant | petite application iOS « Volant Auto Jeux » (jeu de conduite) |
| Bitume | aucun jeu trouvé |
| Kilomètre Zéro | aucun jeu trouvé |
| Rouage | aucun jeu trouvé |
| Route Sept | jeu de course « Road 7 » existant |

Écartés avant proposition : Corso (proche du jeu Roblox « Corsa Legends »), Calandre (parfum Paco Rabanne, nom d'un
concessionnaire), Asphalt, Redline, Torque, Tarmac (déjà pris par des jeux ou des marques connues). Amberline se
distingue des quatre marques fictives de voitures (Mivale, Orvane, Rocalt, Celvar).

## 3. Logo

- Trois pistes « mot + symbole » dessinées par script (`tools/brand/build_amberline.py` du dépôt d'art) : 1 Route,
  2 Horizon, 3 Virage (planche `brands/amberline/planche.png`). Formes géométriques originales, aucune silhouette de
  voiture, aucun emblème existant ; motifs distincts des emblèmes de Mivale, Orvane, Rocalt et Celvar.
- Mot en **Titillium Web Bold** (SIL Open Font License 1.1, copie livrée avec Roblox Studio), **converti en tracés** :
  aucune police embarquée ni redistribuée. Couleurs de la charte V1.2 (ambre `#E8A33D`, texte `#ECEAE6`, fond
  `#0E0F11` → `#1E2125`).
- PNG exportés (Chrome sans fenêtre), déterministes : relance du script le 2026-11-06, SHA-256 identiques.

| Fichier (dépôt d'art) | Taille | SHA-256 | Copie pour l'envoi |
| --- | --- | --- | --- |
| `brands/amberline/virage/logo.png` (fond transparent) | 1024 × 256 | `87ec8aac…5740c` | `aw-vm-exchange\brand01_amberline_logo_1024x256.png` |
| `brands/amberline/virage/icone.png` (fond anthracite) | 512 × 512 | `e9f0387a…5fc87` | `aw-vm-exchange\brand01_amberline_icone_512.png` |

### 3.1 Marche à suivre pour l'envoi (propriétaire)

Sous le **même créateur que l'expérience** (compte ou groupe).

1. **Logo de l'écran de chargement** : dans Studio, *Affichage > Gestionnaire d'actifs* (Asset Manager), bouton
   *Importer en masse* (Bulk Import), choisir `E:\ROBLOX DEV\aw-vm-exchange\brand01_amberline_logo_1024x256.png`.
   Une fois l'image acceptée par la modération, clic droit sur l'image > *Copier l'ID dans le presse-papiers*, et me
   transmettre ce nombre. Attention : un envoi par le Creator Hub en « Decal » donne un identifiant de **décalque**,
   différent de l'identifiant d'**image** attendu ; le Gestionnaire d'actifs donne directement le bon.
2. **Icône de l'expérience** (facultatif, proposition) : Creator Hub > Créations > l'expérience > *Configurer* >
   icône, envoyer `brand01_amberline_icone_512.png` (Roblox arrondit lui-même les coins ; marge de sécurité de 48 px).
3. **Nom de l'expérience** : même page, *Informations de base* > nom « Amberline ». C'est au propriétaire de le faire
   (aucune publication par l'assistant).

À réception de l'identifiant du logo, il sera relevé à trois endroits, contrôlés par les tests : `src/first/Brand.luau`
(table `BRAND_IMAGE_IDS`), entrée `ui.brand.logo` du manifeste, table exacte de `tests/test_brand01.py`. Le contrôle
existant `tests/test_lot08.py::test_asset_manifest_declares_no_roblox_id` (liste exacte des valeurs non nulles de
`RobloxAssetId`) devra alors recevoir une ligne de plus.

## 4. Écran de chargement

Fichiers : `src/first/` (dossier `ReplicatedFirst.AutomotiveWorldFirst`, ajouté aux deux projets Rojo).

| Module | Rôle |
| --- | --- |
| `LoadingScreen.client.luau` | LocalScript : retire l'écran par défaut (`RemoveDefaultLoadingScreen`), construit et anime l'écran, fondu de sortie |
| `LoadingProgress.luau` (pur) | progression réelle, délais, défilement des tirets, durée du fondu |
| `LoadingTexts.luau` (pur) | textes par clé FR/EN, langue déduite du compte Roblox |
| `Brand.luau` (pur) | nom affiché, identifiant du logo (aucun pour l'instant), couleurs recopiées de la charte, choix image / texte |

### 4.1 Progression réelle

La barre n'avance que sur des attentes observées, avec un poids chacune (somme 1) :

| Étape | Signal | Poids |
| --- | --- | --- |
| Connexion | `game:IsLoaded()` (réplication initiale) | 0,40 |
| Monde | attribut `AutomotiveWorldReady` de ReplicatedStorage (serveur démarré) | 0,15 |
| Interface | écran `AWHud` présent dans PlayerGui (client démarré, créé par HUDController) | 0,15 |
| Personnage | personnage avec `HumanoidRootPart` | 0,10 |
| Images et sons | file `ContentProvider.RequestQueueSize` : 1 − taille / plus haute taille vue | 0,20 |

- La file peut ne jamais se vider (streaming) : elle compte comme finie sous 4 éléments, ou 6 s après les quatre
  autres attentes.
- Valeur affichée lissée, **jamais en recul**. Affichage minimal 1,2 s (pas d'éclair dans Studio).
- **Délai maximal 30 s** : l'écran se retire même si une attente n'aboutit pas (texte « Chargement plus long que
  prévu : le jeu démarre. »), sans remplir artificiellement la barre. **Filet de sécurité** indépendant à 35 s ; toute
  erreur retire l'écran immédiatement (avertissement dans la sortie). Le jeu n'est jamais bloqué : l'écran ne capte
  aucune entrée et les autres scripts tournent dessous.
- Un test Lune vérifie que les signaux existent encore dans le code (`AWHud` dans HUDController,
  `AutomotiveWorldReady` dans le serveur) : un renommage ferait sinon attendre le délai maximal à chaque partie.

### 4.2 Affichage

- Fond anthracite (dégradé vertical léger) ; trois lignes de tirets ambre dans le bas, qui défilent vers la gauche
  (plus proches = plus épaisses, plus rapides, plus visibles).
- Logo au format 4 : 1, au plus 62 % de la largeur ; **repli** : « AMBERLINE » en Titillium Web gras souligné d'un
  filet ambre, tant que l'image n'est pas envoyée, pas chargée, refusée ou en retard (4 s). L'image n'est montrée
  qu'une fois réellement chargée (jamais de cadre vide).
- Phrase d'accueil « Bienvenue à Valcourt » / « Welcome to Valcourt », barre ambre sur rail anthracite, étape en cours.
- Langue : français si la langue du compte Roblox commence par « fr », anglais sinon (les préférences du jeu ne sont
  pas encore chargées à ce moment-là).
- Tailles relatives à l'écran (téléphone, tablette, PC, télévision), textes à taille adaptée, jamais sous 11 px ;
  couverture de la barre supérieure et de l'encoche ; aucun élément interactif (souris, tactile, manette sans effet).
- « Réduire les animations » du système (`GuiService.ReducedMotionEnabled`) : fond figé, sortie sans fondu ; sinon
  fondu de 0,6 s.
- `DisplayOrder` 10000 : au-dessus des écrans du jeu (téléphone 12, choix de silhouette 14, parcours d'arrivée 15,
  page de démonstration 9000), sous le calque d'étalonnage des essais (100000). Ces écrans se construisent dessous et
  apparaissent au fondu.

## 5. Fichiers touchés

- **Nouveaux** : `src/first/Brand.luau`, `src/first/LoadingProgress.luau`, `src/first/LoadingTexts.luau`,
  `src/first/LoadingScreen.client.luau`, `tests/lune/specs/Brand01.luau`, `tests/test_brand01.py`, ce rapport.
- **Communs, par ajouts** : `default.project.json` et `openworld.project.json` (bloc `ReplicatedFirst`, 6 lignes
  chacun) ; `src/shared/Assets/AssetManifest.luau` (entrée `ui.brand.logo` avant `AssetManifest.Assets`) ;
  `tests/lune/run.luau` (`require("./specs/Brand01")` en fin de liste) ; `tests/test_scaffold.py` (exception
  `rbxassetid://` étendue à `Brand.luau`, écart E3).
- **Non touchés** : fichiers de MAP-01 (`src/server/World`…) et de COMMANDES-01 (véhicule, HUD de conduite, feux) ;
  `Localization.luau` ; README, ROADMAP, QA_BACKLOG, CREDITS_ACTIFS (§9).

## 6. Tests exécutés

| Date | Commande | Résultat |
| --- | --- | --- |
| 2026-11-06 | `lune run tests/lune/run.luau build/AW-BRAND-01.rbxlx` (après `rojo build`) | 499 réussis, 0 échoué (dont 13 tests BRAND-01) |
| 2026-11-06 17:28 | `scripts\verify.ps1 -DownloadRobloxTypes` (1er passage) | ÉCHEC : pytest (`rbxassetid://` interdit hors du manifeste) et luau-lsp (types de `src/first`) ; corrigés |
| 2026-11-06 17:30–17:31 | `scripts\verify.ps1 -DownloadRobloxTypes` (2e passage) | tout OK : Rojo, Selene, pilote Studio, StyLua, Lune 499/0, carte du monde ouvert, place monde ouvert, pytest 42 réussis, luau-lsp strict sans erreur |
| 2026-11-06 17:32 | `rojo build -o build\AW-BRAND-01.rbxlx` | place de test reconstruite (code final) |

Tests BRAND-01 (Lune) : place (LocalScript dans ReplicatedFirst, modules purs, retrait de l'écran par défaut, file de
ContentProvider, filet de sécurité) ; signaux encore présents dans le code ; poids = 1 et **aucune avance sans signal** ;
avance étape par étape dans l'ordre ; **jamais de recul** ; affichage minimal ; **délai maximal** (sans barre remplie,
état figé ensuite) ; file qui ne se vide jamais (délai de grâce, tolérance) ; tirets et fondu ; **repli sans logo** ;
logo égal au manifeste, couleurs égales à la charte, police de la charte ; textes FR/EN, langue, aucune clé en double
avec la localisation centrale. Pytest BRAND-01 : table exacte des identifiants (vide), entrée du manifeste, bloc
ReplicatedFirst dans les deux projets, nom technique inchangé.

## 7. NON TESTÉ

Rien n'a été lancé dans Roblox Studio (le propriétaire teste lui-même) :

- rendu réel de l'écran (logo de repli, police, dégradé, tirets), fondu de sortie, ordre d'affichage au-dessus du
  parcours d'arrivée et du téléphone ;
- comportement des signaux en jeu (durée réelle, ordre des étapes, valeur de la file de ContentProvider) dans la zone
  d'essai et dans le monde ouvert (streaming) ;
- tailles d'écran (téléphone, tablette, ultralarge), manette, tactile, « réduire les animations » ;
- logo en image (pas encore envoyé sur Roblox) ; icône de l'expérience ;
- délai maximal et filet de sécurité en conditions réelles (testés seulement en logique pure).

## 8. Liste de vérification en jeu (propriétaire)

Place : `build\AW-BRAND-01.rbxlx` (zone d'essai). Pour le monde ouvert : `build\AutomotiveWorld-OpenWorld.rbxl`
produite par `verify.ps1`.

1. Play : l'écran par défaut de Roblox ne s'affiche pas ; à sa place, fond anthracite, « AMBERLINE » souligné ambre,
   « Bienvenue à Valcourt », barre ambre, étape en cours, tirets ambre qui défilent en bas.
2. La barre avance par à-coups réels (pas de remplissage régulier minuté) et ne recule jamais ; l'écran disparaît en
   fondu (~0,6 s) au bout d'environ 1 à 3 s dans Studio ; le parcours d'arrivée / le choix de silhouette apparaissent
   ensuite normalement et se commandent.
3. Monde ouvert : même chose, chargement plus long ; l'écran se retire au plus tard après 30 s.
4. Émulateur d'appareils de Studio (téléphone, tablette, 4K) : rien de coupé, textes lisibles, logo centré.
5. Compte en anglais (ou émulation de langue) : textes en anglais.
6. Après l'envoi du logo (§3.1) et son report dans le code : le logo « Virage » remplace le titre en texte.

## 9. Écarts et points à arbitrer

- **E1 — nouveau dossier `src/first`** (ReplicatedFirst), hors du trio `server` / `client` / `shared` de CLAUDE.md :
  indispensable, un écran de chargement doit s'exécuter avant la réplication de ReplicatedStorage. Il ne contient que
  du code client d'affichage et trois modules purs testés.
- **E2 — valeurs recopiées** : couleurs de la charte et identifiant du logo sont dupliqués dans `Brand.luau` (le
  manifeste et DesignTokens ne sont pas encore disponibles à l'affichage) ; égalité vérifiée par le test Lune.
- **E3 — `tests/test_scaffold.py`** : l'exception qui autorise `rbxassetid://` dans le seul manifeste est étendue à
  `Brand.luau` (même raison qu'E2 ; la table de `Brand.luau` est contrôlée exactement par `tests/test_brand01.py`).
- **E4 — langue** : déduite de la langue du compte Roblox, pas du réglage de langue du jeu (pas encore chargé) ; un
  joueur au compte anglais qui a choisi le français dans le jeu verra l'écran de chargement en anglais.
- **E5 — « Valcourt »** dans la phrase d'accueil : nom de ville de MAP-01 ; à changer si la ville est renommée.

## 10. À reporter par la coordination (fichiers non modifiés ici)

- **README** : nom du jeu « Amberline » (le nom technique reste « Automotive World ») ; écran de chargement (une
  ligne, renvoi vers ce rapport).
- **ROADMAP** : lot BRAND-01 (nom, logo, écran de chargement), état « à essayer par le propriétaire » ; envoi du logo
  en attente.
- **QA_BACKLOG** : les 6 points du §8, **NON TESTÉ**.
- **CREDITS_ACTIFS** : aucun actif tiers ; mention possible « logo : mot en Titillium Web (SIL OFL 1.1), converti en
  tracés ».
