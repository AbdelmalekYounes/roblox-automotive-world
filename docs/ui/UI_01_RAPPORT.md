# UI-01 — système de conception V1.2 : rapport

Branche `feat/ui-premium-v1.2`, base `feat/veh3d-01-comete` (PR #16 non fusionnée). Rapport du 2026-11-05.

**Démarrage hors règle de clôture** : la règle « un lot clôturé avant le suivant » (CLAUDE.md) n'est pas remplie, la PR
#16 n'étant pas fusionnée (« Pas encore »). Le propriétaire a demandé de passer à l'interface juste après ; c'est
traité comme son exception, et la branche UI part de la branche de la Comète.

Référence : maquettes du propriétaire « Design System V1.2 » (direction « Automotive Premium »), copiées dans
`docs/ui/handoff-v1.2/` (README : provenance, fichiers absents). Étape UI-01 du guide `HANDOFF_UI_ROBLOX.md` : jetons et
éléments de base, **sans modifier la logique des services ni remplacer les écrans actuels**.

## 1. Réalisé

| Élément | Fichier | Contenu |
|---|---|---|
| Jetons | `src/shared/UI/DesignTokens.luau` (pur) | 23 couleurs (+ 2 variantes de contraste renforcé), 9 styles de texte (Titillium Web, Roboto Mono), minimum 11 px, capitales accentuées, espacements, rayons, cibles, résolutions et échelle (1440 p = 1,333 ; compacte sous 1400 px logiques), cotes du garage et du téléphone, 9 animations, réduction des animations, 6 états de sauvegarde, filets de statut, contraste WCAG |
| Thème | `src/client/UI/UITheme.luau` | noms historiques conservés, valeurs reprises des jetons ; Titillium Web à la place de Gotham (même graisse) ; focus ambre 2 px ; survol `#262A2F` ; rayons 4 et 6 ; animations nommées |
| Composants | `src/client/UI/Components.luau` | texte par style, bouton (principal, secondaire, révoquer ; désactivé expliqué), onglets (filet 3 px), choix segmenté, ligne de réglage (plage et pas de l'appelant), puce de pièce, pastille, carte à filet de statut, avertissement, cellule de course, badge d'état, zone 3D (dégradé), confirmation protégée (`InputMap.accepts`, refusée en mode rapide), échelle de l'écran |
| Démonstration | `src/client/UI/DesignDemo.luau` | page de tous les composants, **dans Studio seulement**, ouverte par l'attribut `AWDesignDemo` du serveur de test |
| Textes | `Localization` | 7 clés FR / EN (états, origine d'un réglage) |

## 2. Essais

| Essai | Commande, tâche | Résultat |
|---|---|---|
| Statique | `scripts\verify.ps1 -RobloxTypes .tooling\globalTypes.d.luau` | toutes les étapes OK ; Lune 383 / 383 (8 tests `UiDesignSystem`) |
| VM | `test-vm.cmd -Sessions ui_design -GuiInput`, `20261105-032450` | **15 / 15**, vrais clics |

Lune : couleurs au code hexadécimal près ; contrastes **calculés** égaux à ceux annoncés par la maquette (texte 15,9:1,
texte secondaire 7,4:1) et ≥ 4,5:1 pour toutes les paires texte / fond ; aucune taille sous 11 px ; pas de 4 ;
4 résolutions ; animations ramenées à 0 ; six états ; capitales accentuées.

VM (Studio de la VM, vue 1250 × 593, disposition compacte) :
- polices Titillium Web Regular et Bold, Roboto Mono Bold, effectivement chargées et mises en page ;
- échelle de l'écran conforme à la règle ;
- vrai clic reçu par le bouton principal ;
- bouton désactivé sans effet, avec sa raison affichée ;
- réglage borné à sa plage, puis en baisse d'un pas ;
- confirmation protégée **inactive à l'affichage**, armée ensuite, puis acceptée par un vrai clic ;
- focus ambre de 2 px ;
- six états affichés ;
- cartes sans étirement, filets à leur taille ;
- fenêtre de confirmation au-dessus de son voile et entière dans la vue.

Captures : `aw-vm-exchange\jobs\20261105-032450\report\gui\named\` (page, confirmation, focus).

## 3. Anomalies trouvées et corrigées pendant le lot

| Anomalie | Cause | Correction |
|---|---|---|
| « RéGLAGES » | `string.upper` ne traite que l'ASCII | `DesignTokens.upper` (lettres accentuées françaises), test Lune |
| Carte étirée sur toute la hauteur, colonne vide (vu sur capture, tests verts) | filet de statut dans la liste, hauteur relative dans un cadre à taille automatique | contenu dans son cadre, filet à taille recopiée ; contrôle de mise en page ajouté |
| Confirmation assombrie | ordre d'affichage global de la page | ordre par parent ; contrôle ajouté |
| Clics décalés de la barre de Roblox, confirmation hors de la vue | page sans marge du haut ; troisième colonne trop longue pour la VM | marge standard, largeurs compactes, confirmation en fenêtre centrée |

## 4. Écarts et limites

- **Effet sur les écrans existants** : la palette V1.2 et Titillium Web s'appliquent à tout ce qui passe par `UITheme`.
  Changements visibles :
  - focus bleu → ambre ;
  - texte minimum 12 → 11 px ;
  - contraste renforcé : avant noir et blanc purs, désormais la variante de la maquette (bordures et texte secondaire
    seulement).
  
  Les 34 réglages de police écrits directement dans le garage, l'économie, les courses et le HUD de développement
  restent en Gotham ; ces écrans seront refaits aux lots suivants. Non-régression des sessions `ui`, `ui_monde`,
  `ui_marche` : **NON TESTÉE**.
- **Échelle 1440 p et disposition compacte** : appliquées à la page de démonstration seulement ; pas encore aux écrans du
  jeu.
- **Résolutions** : règle testée en Lune pour les 4 résolutions ; rendu vérifié à la seule taille de la VM (1250 × 593).
- **Manette** : focus posé par script (aucune manette dans la VM) ; essai sur matériel réel NON FAIT.
- **Icônes** : le dossier `icons/` manque dans l'archive. Il faudra des PNG à partir des tracés SVG, puis un envoi sur
  Roblox par le propriétaire (lot UI-02).

## 5. Suite proposée

UI-02 — Smartphone : refaire `PhoneController` d'après `Smartphone.dc.html` (12 applications, tailles normale, agrandie
et compacte, mode rapide conservé, demandes aux services inchangées), icônes à produire. À commencer sur l'accord du
propriétaire.
