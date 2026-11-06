# Amendements du cahier des charges global v1.0

Écarts au cahier des charges (`docs/CAHIER_DES_CHARGES_GLOBAL_v1.0.md`), **décidés par le propriétaire**. Ils sont
consignés ici, datés et cités. Le cahier des charges validé n'est pas réécrit : en cas de doute, ce registre indique la
décision la plus récente.

## A-01 — gamme réduite à deux véhicules (2026-11-05, lot BASE-01)

Décision du propriétaire : « on va enlever je pense les 17 autres véhicules et repartir sur une base propre avec non
seulement la Comète et on va faire un autre véhicule en 3D bien fait ». Choix précisés le même jour :
- second véhicule : **citadine** ;
- issue d'un **modèle tiers CC BY** : Milano '95 de Daniel Zhabotinsky ;
- suppression des 17 modèles, des prototypes et du parc d'essai ;
- prototypes conservés comme **jeux d'essai des tests** ;
- **aucun véhicule provisoire** en attendant la citadine.

| Cahier des charges | Exigence d'origine | Désormais |
|---|---|---|
| §1 et CH03 | dix-huit modèles fictifs originaux | **deux** modèles : Comète, puis la citadine (VEH3D-02) |
| §1.2 | véhicules fictifs originaux | deux modèles **tiers CC BY**, inspirés de voitures réelles (McLaren 720S, Fiat Punto mk1) : risque de forme accepté par le propriétaire en les choisissant (audit V1.0 §7.6) |
| CH09 | extérieurs et intérieurs soignés pour les dix-huit | pour les deux |
| §3.1, §10.1, AUD-ONB-01 | trois véhicules de départ au choix | **un** (la citadine) ; aucun tant qu'elle n'est pas intégrée |
| Gamme par familles et marques fictives | 4 marques, familles | sans objet pour l'instant ; marques conservées dans les documents |
| Métiers à véhicule fourni (taxi, livraison, convoi, essais) | véhicule de service | indisponibles avec une raison affichée, tant qu'aucun véhicule de service n'existe |

## A-02 — antipatinage actif au départ des sessions de conduite (2026-11-06)

**Décision du propriétaire.** Il a répondu « E puis B » à la proposition `docs/PROPOSITION_PATINAGE.md`, rédigée
après le lot AUDIO-03. Cette proposition s'appuie sur des mesures au banc planaire :
- **Comète**, aides coupées : 3,7 s de patinage au départ, et tête-à-queue dès qu'on accélère en braquant ;
- **avec l'antipatinage** : plus de tête-à-queue, et un 0 à 100 km/h plus rapide (4,19 s au lieu de 4,49 s).

| Cahier des charges | Exigence d'origine | Désormais |
|---|---|---|
| Ligne 55 (§1.2) | aides « état par défaut désactivé » | **antipatinage actif** au début de chaque session de conduite, s'il équipe le modèle ; ABS et contrôle de stabilité toujours désactivés par défaut |

Ce qui ne change pas :
- **Aides absentes** : un modèle sans antipatinage n'en reçoit pas.
- **Réglage par le joueur** : l'antipatinage reste désactivable (touche 2, ou réglages à la croix de la manette) ; son
  état est affiché au HUD.
- **Aucune aide cachée** : l'avis « antipatinage désactivé » (option E) est une information, pas une aide.

Mise en œuvre : `Constants.AidsOnAtStart` et `VehicleService.assignDriver`.
