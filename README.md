# Automotive World — Lot 0.1 (vertical slice véhicule)

> **Nom technique provisoire** : ce n'est pas le nom commercial du jeu.
> **Référentiel** : cahier des charges global Roblox v1.0, officiellement validé le 2 novembre 2026.
> **Périmètre du livrable** : une zone d'essai isolée et **un seul véhicule fictif de test** (« Prototype d'essai P-01 »),
> pilotable au clavier et à la manette. Ni catalogue, ni carte, ni économie, ni sauvegarde.
> **Statut** : finalisation du lot en cours de revue (PR #1, **non fusionnée**). Hors Studio : tous les contrôles
> verts (100 tests Lune). Dans Roblox Studio via la VM de test : collisions entre joueurs corrigées, propriété réseau
> vérifiée ; une anomalie intermittente de réplication reste ouverte, et clavier/manette réels et ressenti
> restent à vérifier par un humain. Détail : [docs/lot-0.1/RAPPORT_VALIDATION.md](docs/lot-0.1/RAPPORT_VALIDATION.md).

## Prérequis (Windows)

- Windows 10/11, Roblox Studio installé.
- [Rokit](https://github.com/rojo-rbx/rokit) : installe les versions épinglées dans `rokit.toml`
  (Rojo 7.7.1, Selene 0.27.1, StyLua 0.20.0, luau-lsp 1.70.1, Lune 0.11.1).
- Plugin Rojo 7 pour Roblox Studio (uniquement pour la synchronisation en direct).
- Git, Python 3.10+ avec `pytest`.

```powershell
# Depuis la racine du dépôt : installe/valide les outils épinglés.
rokit install
```

## Construire et ouvrir la zone d'essai

```powershell
rojo build -o build\AutomotiveWorld.rbxlx
```

1. Ouvrir `build\AutomotiveWorld.rbxlx` dans Roblox Studio (ne pas publier la place).
2. **Ne pas** activer « Enable Studio Access to API Services » : le lot n'utilise aucun DataStore et aucun test ne doit en toucher.
3. Cliquer sur **Play**. La bannière « Zone d'essai véhicule » apparaît ; quatre prototypes sont stationnés sur les plots verts.
4. S'approcher de la portière gauche d'un véhicule et **maintenir E** (manette : **X**) pour monter.
5. Pour la synchronisation en direct pendant le développement : `rojo serve`, puis connecter le plugin Rojo.

## Commandes de conduite

| Action | Clavier | Manette |
|---|---|---|
| Accélérer | Z / W / ↑ | Gâchette droite (RT) |
| Freiner ; **reculer** (maintenir à l'arrêt ≈ 0,3 s) | S / ↓ | Gâchette gauche (LT) |
| Diriger | Q / A / ← et D / → | Stick gauche |
| Frein à main | Espace | A |
| Caméra proche / lointaine | V | Croix haut |
| Remettre sur roues (véhicule immobile et renversé) | R | Croix bas |
| Sortir (sous 20 km/h) | F | Y |

Le HUD de développement (en bas à droite) affiche vitesse, rapport, régime, commandes effectives,
aides présentes (aucune sur ce modèle), la réduction du braquage avec la vitesse (32° → 9° à 140 km/h) et deux
**mesures locales indicatives** : 0–100 km/h et 100–0 km/h.

**Clavier et manette ensemble** : un seul périphérique pilote à la fois ; il prend la main sur une commande
« fraîche » (au repos puis sollicité). Une touche déjà enfoncée en montant dans le véhicule, un stick qui dérive ou
une gâchette effleurée ne produisent donc aucune commande. Le clavier est ignoré pendant la saisie de texte (chat)
et quand la fenêtre perd le focus ; une manette déconnectée est relâchée immédiatement (message à l'écran), sans
reprise automatique par l'autre périphérique.

## Vérifications locales (non intrusives)

```powershell
# Build Rojo + Selene + StyLua + tests Lune (hors Studio) + pytest.
powershell -ExecutionPolicy Bypass -File scripts\verify.ps1

# Idem avec l'analyse de types stricte luau-lsp (télécharge les définitions Roblox officielles dans .tooling\).
powershell -ExecutionPolicy Bypass -File scripts\verify.ps1 -DownloadRobloxTypes
```

Ces vérifications n'ouvrent aucune fenêtre et ne lancent pas Studio. **Elles ne remplacent pas les essais
en Studio** : la physique Roblox, le réseau, la caméra et l'interface n'y sont pas exécutés.
Détail des moyens et limites : [docs/lot-0.1/RAPPORT_TESTS.md](docs/lot-0.1/RAPPORT_TESTS.md).

## Tests dans Roblox Studio, via la VM (sans prendre ton PC)

```powershell
test-vm.cmd
```

Les essais Studio (solo, deux joueurs, latence, scénarios, deux expériences de collision) s'exécutent dans la VM
VMware de test ; ton bureau, ta souris et ton clavier ne sont pas utilisés. La VM ne voit que le dossier d'échange,
hors du dépôt. Préparation, permissions et fonctionnement : [docs/VM_TESTS.md](docs/VM_TESTS.md).

## Organisation du code

| Dossier | Contenu |
|---|---|
| `src/shared/Vehicles` | Types, définitions, dynamique **pure** (pneu, suspension, groupe motopropulseur), adaptateur Roblox `VehicleSimulator`, codec réseau, mesures |
| `src/server` | Zone d'essai, fabrique du véhicule, service autoritaire (embarquement, propriété réseau vérifiée, validation des mouvements, médiation des collisions entre joueurs), limiteur de débit |
| `src/client` | Commandes clavier/manette (arbitrage des périphériques), caméra, animation des roues, HUD de développement |
| `tests/lune` | Tests exécutés par Lune sur la place construite par Rojo (modules purs + structure) |
| `tests/test_scaffold.py` | Contrôles statiques Python |
| `docs/lot-0.1` | Rapport de validation, rapport de tests, analyse des écarts et arbitrages, proposition du lot 0.2 |
| `tools/vm` | Essais Studio dans la VM (hôte, agent, préparation, partage) |

Architecture détaillée : [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Gouvernance

Règles permanentes : [CLAUDE.md](CLAUDE.md).

- Le cahier des charges validé et les 33 décisions AUD font foi.
- Aucun code, modèle, interface, texture ni donnée de Collectverse ou Mimic Hunters n'est réutilisé ;
  la géométrie du prototype est générée par code à partir de primitives.
- Aucun crédit, achat, possession définitive, récompense ni DataStore n'est implémenté.
- Aucun objectif (24 joueurs, ~60 FPS, performances du véhicule) n'est déclaré atteint : rien n'a été mesuré en jeu.
