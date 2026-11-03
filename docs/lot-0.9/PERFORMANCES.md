# Performances — premier bilan (lot 0.9)

**Aucun objectif du cahier des charges n'est déclaré atteint.** Cibles (CDC) : 24 joueurs par serveur, ≈ 60
images/s, temps d'image médian ≤ 16,67 ms, P95 ≤ 20 ms, P99 ≤ 33,3 ms. Les mesures ci-dessous viennent de Roblox
Studio dans une **machine virtuelle sans accélération graphique représentative** : elles valident l'outillage et
donnent des ordres de grandeur, pas les performances du jeu publié.

## 1. Outillage livré

- Session VM **`perf`** (place monde ouvert, `tools\vm\host-run.ps1 -NoVmControl -Place OpenWorld -Sessions perf`) :
  trois phases de 45 s (jour clair, nuit à 22 h, nuit sous la pluie forcée). Client : temps d'image
  (`RenderStepped`) médiane / P95 / P99 / max, mémoire, débit reçu et émis, pièces chargées par le streaming,
  sources de lumière actives, heure. Serveur : intervalle de battement (médiane, P95, P99), coût du pas des
  véhicules et des dégâts (`PerfStats`, points d'accès de test), mémoire, agents du trafic et corps physiques,
  instances.
- Session historique **`lot02`** : coût serveur du parc au repos et d'un banc de 16 véhicules simulés.
- Banc hors Studio des véhicules (`tools/vehicles/catalog.luau`), simulations économiques (`tools/economy`).

## 2. Mesures (VM, Studio `0.745.449`, tâche `20261103-174932`, commit `28816d9`)

| Phase | Image médiane | P95 | P99 | Max | Mémoire (processus Studio) | Pièces chargées (client) | Lumières actives |
|---|---|---|---|---|---|---|---|
| Jour | 16,65 ms | 18,71 ms | 20,09 ms | 26,4 ms | 3 439 Mo | 16 511 | 0 |
| Nuit | 16,62 ms | 18,65 ms | 20,22 ms | 31,0 ms | 2 695 Mo | 16 511 | 0 (défaut, §4) |
| Nuit + pluie | 16,63 ms | 18,71 ms | 20,29 ms | 45,0 ms | 2 572 Mo | 16 503 | 0 (défaut, §4) |

Serveur, mêmes phases : intervalle de battement médian 16,9 ms, P95 18,4–18,8 ms, P99 19,7–20,7 ms ; 140 agents
de trafic, 0 à 2 corps physiques (aucun joueur ne roule) ; ≈ 51 260 instances dans `Workspace` ; coût des dégâts
médian ≈ 0,06 ms par pas (P99 ≈ 0,25 ms). Chargement initial du client (personnage + 10 s) : 12,7 s.

Lecture critique :

- En jeu solo dans Studio, **client et serveur partagent le même processus** : la mémoire (2,6–3,4 Go) est celle
  de Studio entier, non séparable ; l'intervalle d'image est **plafonné à 60 Hz** (médiane ≈ 16,67 ms), donc la
  médiane ne mesure pas la marge disponible. Seuls P95, P99 et le maximum renseignent : les pics (jusqu'à 45 ms
  sous la pluie) dépassent la cible P99 à l'occasion, sans conclusion possible sur une machine réelle.
- Débit réseau ≈ 0 (client et serveur locaux) : non représentatif.
- `lot02` (même VM, `20261103-155713`) : coût du gestionnaire de battement du parc au repos médiane 0,074 ms ; avec
  16 véhicules simulés par le serveur, médiane 0,186 ms, P99 0,563 ms — marge large côté simulation serveur.

## 3. Optimisations en place (non critiques, sans toucher à la physique ni à l'équité)

- Qualité graphique (basse, moyenne, haute) : distance de l'habillage (masqué / 180 / 350 m), des détails de
  carrosserie (masqués / 120 / 250 m), sources de lumière limitées (véhicules 0 / 4 / 8, lampadaires 0 / 12 / 24),
  effets de post-traitement, couches sonores et véhicules sonorisés.
- Habillage généré hors ligne (aucune construction au démarrage), accessoires sans collision ni ombre, streaming
  conservé (secteurs de 500 m) ; routes en modèles persistants (sécurité de conduite, inchangé).
- Piétons rendus localement autour de la caméra ; trafic : corps physiques seulement près des joueurs.

## 4. Défaut trouvé par la mesure

**Lampadaires et niveau de détail de l'habillage jamais suivis** (lot 0.8) : `VehicleLights` et `DetailLod`
cherchaient `OpenWorld/Habillage` une seule fois au démarrage du client, avant son arrivée par le streaming ; de
nuit, aucune source ne s'allumait et la qualité « basse » ne masquait pas l'habillage. Corrigé (`f2fe391`) :
recherche répétée tant que le dossier manque. Vérification : voir `RAPPORT_VALIDATION_GLOBALE.md` §2.

## 5. Procédure de mesure sur appareils réels (à faire par le propriétaire)

1. Publier la place **monde ouvert** dans l'**expérience de test isolée** (jamais la production), en privé.
2. Ordinateur de référence (carte graphique courante) puis mobile de référence : rejoindre la partie, ouvrir la
   console développeur (F9) → onglets *Memory*, *Network*, *ScriptProfiler* ; activer *MicroProfiler*
   (Ctrl+F6) pour le temps d'image.
3. Relever, pour chaque qualité graphique (Paramètres → Graphismes), sur 60 s : à l'arrêt en métropole, en
   conduite sur l'autoroute A6, de nuit sous la pluie (attendre ou forcer la météo dans une place de test) :
   temps d'image médian / P95 / P99 (MicroProfiler), mémoire client, débit reçu.
4. Charge : 24 comptes de test dans le même serveur, répartis dans les zones (QA-P01, V13) ; relever le
   temps serveur (*Server Stats*) et la bande passante par joueur.
5. Session longue (≥ 2 h) : mémoire en début et fin (fuites, QA-P06).
6. Consigner les résultats dans `docs/QA_BACKLOG.md` §4 avec l'appareil, la qualité et la date.
