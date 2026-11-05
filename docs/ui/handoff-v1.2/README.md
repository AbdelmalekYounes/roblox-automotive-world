# Maquettes UI V1.2 du propriétaire (référence de conception)

Copie des fichiers de l'archive `Automotive_World_Design_v1.2_Handoff_COMPLET.zip`, fournie par le propriétaire le
2026-11-05 (SHA-256 de l'archive : `ac0fb6233fdf1687b0f73ce2de86c0f0867fabf402742dd2bd7456c6e8835f3d`).

| Fichier | Rôle |
|---|---|
| `HANDOFF_UI_ROBLOX.md` | guide d'intégration : direction retenue, correspondance aux modules, règles non négociables, étapes UI-01 à UI-04 |
| `Directions artistiques.dc.html` | direction « Automotive Premium » retenue provisoirement |
| `Design System.dc.html` | référence unique : couleurs, typographie, mesures, composants, icônes, états, animations, accessibilité, règles, raccourcis |
| `Smartphone.dc.html` | téléphone, 12 applications (étape UI-02) |
| `Garage.dc.html` | garage, 6 onglets (étape UI-03) |
| `Icônes Téléphone.dc.html` | planche des 12 icônes et consignes d'intégration Roblox (fournie le 2026-11-05, SHA-256 `715d96ba…dab3fa`) ; tracés identiques à ceux de `Smartphone.dc.html` (vérifié) |

**Ce ne sont pas du code du jeu** : ces pages illustrent le comportement et ne sont jamais exécutées par le jeu ni par
les essais. Elles dépendent de `support.js` (environnement d'exécution de l'outil de conception, qui charge des
bibliothèques depuis Internet). Ce fichier n'est **pas** copié dans le dépôt (aucune bibliothèque tierce, CLAUDE.md) ;
il reste dans l'archive du propriétaire (SHA-256 `8fe7df74405f3c55f49b7249c74ea1397e65d07dea2b1bd3b4a489bec2e28cbe`).

**Absents de l'archive**, bien que cités par les maquettes : le dossier `icons/` (sources SVG, PNG 64 et 128 px,
`icons.json`) et `HANDOFF_CLAUDE_CODE.md`. Les tracés SVG des 12 icônes figurent dans le script de
`Smartphone.dc.html`.
