# Ressources et licences — lot 0.8

Source de vérité : `src/shared/Assets/AssetManifest.luau` (version `0.8.0`). Ce document la résume ; en cas
d'écart, le manifeste fait foi et doit être corrigé avec ce document.

## 1. Règles

- **Toutes les ressources sont originales** et appartiennent au projet : géométrie construite par code, carte
  générée hors ligne, sons synthétisés par un script du dépôt. Aucun modèle, interface, texture, son, musique ni
  donnée provenant d'un autre projet (notamment Collectverse et Mimic Hunters), aucun actif Marketplace, aucun
  achat.
- **Aucun identifiant Roblox n'est inventé.** Le champ `RobloxAssetId` est `nil` pour toutes les entrées : rien
  n'a été téléversé. Tant qu'il est `nil`, la ressource n'est pas jouée en jeu (`AssetManifest.playable` faux) :
  les contrôleurs audio restent muets et les stations de radio indisponibles.
- Seule la fonction `AssetManifest.contentId` forme une URL de contenu, à partir d'un identifiant réel déclaré
  dans le manifeste. Le garde-fou `tests/test_scaffold.py` interdit ce motif partout ailleurs, et
  `tests/test_lot08.py` vérifie qu'aucune URL n'est écrite en dur dans le manifeste.
- Statuts : `Provisional` (provisoire), `ReadyForReview` (prêt à valider), `Validated` (validé — **réservé au
  propriétaire** ; la validation du manifeste refuse ce statut tant qu'il ne l'a pas accordé).
- Chaque entrée déclare : identifiant stable, catégorie, version, variantes Low/Medium/High, niveau de détail,
  provenance, licence, source (fichier du dépôt dont l'existence est vérifiée par pytest) et, pour les sons, le
  fichier produit.

## 2. Inventaire

| Famille | Identifiants | Nombre | Source | Statut |
|---|---|---|---|---|
| Carrosseries | `vehicle.body.micro` … `vehicle.body.pickup` | 10 | `src/server/Vehicles/BodyKits.luau` | Provisoire |
| Carrosserie de prototype | `vehicle.body.prototype` | 1 | `src/server/Vehicles/VehicleFactory.luau` | Provisoire |
| Feux des véhicules | `vehicle.lights` | 1 | `src/client/World/VehicleLights.luau` | Provisoire |
| Géométrie du monde | `world.geometry` | 1 | `tools/world/build-world.luau` | Provisoire |
| Habillage des zones | `world.decor.metropole` … `world.decor.littoral` | 7 | `tools/world/build-world.luau` | Provisoire |
| Éclairage | `world.lighting` | 1 | `src/shared/Art/ArtDirection.luau` | Provisoire |
| Moteur essence | `audio.engine.petrol.{idle,low,mid,high}` | 4 | `tools/audio/synth.py` | Provisoire, non téléversé |
| Moteur diesel | `audio.engine.diesel.{idle,low,mid,high}` | 4 | `tools/audio/synth.py` | Provisoire, non téléversé |
| Moteur électrique | `audio.engine.electric.{hum,whine,inverter}` | 3 | `tools/audio/synth.py` | Provisoire, non téléversé |
| Effets | `audio.effect.{skid,wind,impact,shift}` | 4 | `tools/audio/synth.py` | Provisoire, non téléversé |
| Ambiances | `audio.ambience.{city,suburb,harbour,mountain,countryside,circuit,coast,rain}` | 8 | `tools/audio/synth.py` | Provisoire, non téléversé |
| Interface | `audio.ui.{info,warning,critical,click}` | 4 | `tools/audio/synth.py` | Provisoire, non téléversé |
| Radio (compositions originales) | `audio.radio.{ville,route,nuit}` | 3 | `tools/audio/synth.py` | Provisoire, non téléversé |
| Thème d'interface | `ui.theme` | 1 | `src/client/UI/UITheme.luau` | Prêt à valider |

Total : 52 entrées, dont 30 sons.

## 3. Sons synthétisés

Commande (exécutée le 2026-11-03) :

```bash
python tools/audio/synth.py
```

Résultat : `30 sons synthétisés (119.0 s au total) -> build/audio` ; 5,1 Mo de WAV 16 bits mono à 22 050 Hz,
**non versionnés** (`build/` est ignoré par Git). Deux exécutions donnent des fichiers identiques octet pour octet
(vérifié par `diff -r` et par `tests/test_lot08.py`).

Méthode : oscillateurs à fréquences entières (boucles moteur d'une seconde sans raccord), bruit filtré par FFT
circulaire (ambiances sans raccord), enveloppes ; radio : accords, basse, mélodie tirée d'une graine fixe et
batterie synthétique, au tempo de chaque station. Aucun échantillon externe.

Limites : sons **provisoires et simples**, non écoutés par un humain ni comparés à de vrais moteurs ; la
signature sonore par modèle, l'acoustique (tunnels, garages, cabines) et la perspective caméra **ne sont pas
livrées** — seuls les contrôleurs existent (`AudioController`, `RadioController`).

## 4. Procédure de téléversement (propriétaire uniquement)

Aucune publication ni téléversement n'est faite par ce lot. Pour activer un son :

1. écouter le fichier de `build/audio/` et décider de sa validation ;
2. le téléverser depuis le compte ou le groupe propriétaire (Creator Hub), en respectant la modération Roblox ;
3. reporter l'identifiant **réel** obtenu dans `RobloxAssetId` de l'entrée, passer son statut à `Validated` si
   approuvé (la validation du manifeste et `tests/test_lot08.py` devront alors être adaptés pour accepter les
   identifiants réels déclarés), et vérifier en jeu.

## 5. Dépendances

Aucune bibliothèque tierce dans le jeu. Outils : ceux de `rokit.toml` (inchangés) ; synthèse audio : Python et
NumPy, utilisés hors jeu, pour produire les fichiers.
