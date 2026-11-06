# Lot ANIM-02 — Portières, animations d'entrée et de sortie du véhicule

- Date : 2026-11-06.
- Branche : `claude/anim-02-portieres-f3de70`, créée depuis `main` `af0cd49`. Rien n'est poussé.
- Lot mené en parallèle de PHONE-01, AUDIO-04 et MAP-01 (exception du propriétaire du 2026-11-06 : fichiers disjoints).
- Demande du propriétaire : « ajouter les animations d'entrée et de sortie du véhicule avec les portières ».
- Dépôt d'art : branche locale `anim-02-portieres`, commit `c1ce4ac`, créée depuis `origin/main` `e678ac2`, non
  poussée (worktree `E:\ROBLOX DEV\aw-art-anim02`).
- **État : EN ATTENTE de l'import Studio du propriétaire** (§5). Rien n'a été essayé en jeu.

## 1. Décisions du propriétaire (2026-11-06, toutes posées en une fois au début du lot)

| Question | Décision |
| --- | --- |
| Niveau d'animation | **Simplifiée** : marche jusqu'à la porte (1 s au plus), la porte s'ouvre d'elle-même, le corps glisse jusqu'au siège, la porte se referme ; sortie dans l'ordre inverse. Pas de main sur la poignée. |
| Durée | **≈ 1 s à l'entrée, ≈ 0,8 s à la sortie** : porte 0,35 s, glissé 0,5 s (0,45 s à la sortie), fermeture 0,35 s. Le conducteur peut rouler dès qu'il est assis. |
| Règles | **Passager : même séquence** par sa porte ; **portes toujours fermées à l'arrêt** ; **autre porte si le côté est bloqué** (tout bloqué : sortie par le dessus, sans animation). Portes ouvertes **non solides** (option non retenue). |
| Comète | **Élytre fidèle** : panneau, vitre et partie du toit, ouverture vers le haut et l'avant. |

Sans question au propriétaire (annoncé avant les questions, sans objection) : portes seulement visuelles, aucun son de
portière dans ce lot, rétroviseur monté sur la porte.

## 2. Portières séparées (dépôt d'art)

_(rédaction complète en fin de lot)_
