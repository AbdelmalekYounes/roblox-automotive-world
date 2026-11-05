# Aster phase 1 — rapport de clôture (avatars humains, préparation d'ASTER-02)

> **ASTER-02 SUSPENDU par le propriétaire le 2026-11-04** (« aster on abandonne pour l'instant ») — travail conservé sur la PR #15 (`feat/aster-02-blockout`), **aucune étape active**, ne pas réactiver sans décision du propriétaire. Ce document reste comme historique.

Branche `feat/aster-phase1`, PR #14 (brouillon), commits `09b3efb` → `6627a1f` (code) et suivant (documents), 2026-11-04.
Dépôt d'art : `edb57fc`, `254c94f`. Rien n'est fusionné ; aucun actif n'est publié ; aucun DataStore n'est utilisé.

## 1. Tests réellement effectués

| Commande / tâche | Commit | Résultat |
|---|---|---|
| `scripts\verify.ps1 -RobloxTypes .tooling\globalTypes.d.luau` | `6627a1f` | Toutes les étapes OK : Lune **365/365**, luau-lsp strict 0 erreur, Selene 0, pytest 14/14 |
| Lune `AsterPhase1Closure` (file d'application, opérations lentes simulées) | `c9c19be` | Réussi sur 3 exécutions consécutives |
| VM `20261104-174434` : `silhouette`, `avatar`, `aster`, `silhouette2` | `c9c19be` | 364 réussis / 139 échecs |
| VM `20261104-181108` : `silhouette`, `avatar`, `aster` | `6627a1f` | 366 réussis / 134 échecs |

Ce qui a été vérifié, et par quel moyen :

| Point demandé | Résultat | Moyen |
|---|---|---|
| Choix à l'apparition (Féminin) | ✅ corps et tête Jordan, vêtements identiques, panneau fermé | **Vrai clic** dans la VM (`181108`) |
| Changement depuis le smartphone (→ Masculin) | ✅ corps et tête Billie, bouton « Silhouette : Masculin » | **Vrais clics** : touche T, Paramètres, Interface, Silhouette (`181108`) |
| Conservation des vêtements | ✅ haut, bas et accessoire inchangés à chaque étape | Serveur (`181108`) |
| Remplacement des têtes classiques | ✅ tête classique du compte de test remplacée selon la silhouette | Serveur (`181108`) |
| Conservation des têtes non classiques | ✅ tête réaliste (988) conservée, même après un changement de silhouette | Apparence imposée par le test (`181108`) |
| Réapparition | ✅ choix conservé, panneau non réaffiché | `LoadCharacter` par le test (`181108`) |
| Réplication à deux joueurs | ✅ corps du joueur 1 vu par le joueur 2 comme par le serveur (écart 0,001 st), 4 phases | `silhouette2` (`174434`) ; changements appelés par le serveur de test, **pas de vrais clics** (une seule fenêtre de la VM les reçoit) |
| Couleurs de peau différentes | ✅ conservées sans correction, sur les deux silhouettes ; captures ci-dessous | `181108` |
| Changements successifs, opérations expirées | ✅ 5 demandes avec un délai forcé à 0,05 s : dernier choix appliqué, aucun écrasement pendant 5 s, attribut cohérent | `174434` et `181108` |

**Non vérifié** :
- opération réellement bloquée dans le moteur (au-delà de 30 s) : seulement simulée en Lune ;
- essai humain ;
- appareils réels ;
- autres avatars que le compte de test ;
- vrais clics à deux joueurs.

## 2. Anomalies corrigées

| Anomalie | Correction | Preuve |
|---|---|---|
| Application expirée pouvant écraser un choix plus récent ; tenues sans délai ; chevauchements (audit) | `ApplyQueue` : une application à la fois par personnage, dans l'ordre ; une application expirée garde son tour jusqu'à sa fin réelle ; abandon à 30 s puis réconciliation ; tenues et rétablissement bornés ; attribut du corps mis à jour à la fin réelle | Lune (4 scénarios) ; VM : régression réussie |
| **Pieds sous le plancher** de l'Aster (0,67 à 0,94 st, pose du jeu), non couverts par le contrôle des jambes | Plancher du gabarit abaissé à −1,30 st (garde au sol 0,39 st) ; nouveau contrôle « pieds au-dessus du plancher » | `181108` : 0,07 à 0,34 st au-dessus en pose du jeu |
| Test du téléphone : bouton hors de la vue de la liste | Bouton amené dans la vue par la molette ; effet du clic contrôlé | `181108` |
| QA-A22 : étalonnage du clavier sans reprise | Jusqu'à 3 essais avec reprise du focus, chaque essai journalisé | Étalonné au 1er essai dans les 6 étalonnages de `174434` et `181108` (3 par passage) ; **les reprises n'ont pas eu à servir** |

## 3. Problèmes encore ouverts

| Id | Problème | État |
|---|---|---|
| QA-A20 | Bras de départ du téléphone à 30–36° au repos (2 relevés sur 8 en `174434`, vitesse nulle, aucune piste de marche) | Hypothèse « marche » écartée ; 0 sur 8 en `181108` (attente du repos ajoutée) ; capture 005 de `174434` : bras écarté au repos. **Cause non établie** |
| QA-A22 | Clavier non reçu (2 passages antérieurs) | Non reproduit depuis ; reprises en place mais pas encore mises à l'épreuve |
| — | Vue au-dessus du volant, plus petite morphologie H5 : −0,03 st | Limite d'un volant fixe ; pose adaptée à la taille proposée |
| — | Pose standard (siège sans `AWSeatPose`) : pieds jusqu'à 0,42 st sous le plancher abaissé | Sans effet si les sièges de l'Aster portent l'attribut (exigence d'ASTER-02) |
| — | Couleurs de peau du joueur : ruptures visibles au cou, aux épaules et aux hanches ; jambes bleues et bras gris sur le compte de test | Présenté, **aucune correction** (décision du propriétaire) |
| QA-A13, A14, A17, A18, A21 | Carrosseries provisoires (pavillon, portières, pieds, sorties) | Non redimensionnées, comme demandé |
| QA-A15 | Sortie du passager | En attente de décision |
| — | Échecs de la session `avatar` (131) | Tous dans ces familles connues ; les sorties varient d'un passage à l'autre |

## 4. Captures des deux silhouettes

`captures/aster_phase1_silhouettes.jpg` : silhouettes féminine (994 Jordan) et masculine (995 Billie), de face et de
trois quarts, choisies par vrais clics (tâche `20261104-181108`).

`captures/aster_phase1_tetes_couleurs.jpg` : tête non classique conservée ; couleurs de peau différentes sur les deux
silhouettes, sans correction.

## 5. ASTER-02

Dossier de lancement : `ASTER_02_LANCEMENT.md`. Il comprend :
- le gabarit Blender final ;
- les esquisses « Trait » et la coupe d'habitacle ;
- la liste des maillages ;
- le contrat des pivots et des attaches ;
- l'organisation du modèle ;
- les tests R15 et de performance ;
- les étapes d'import.

## 6. Recommandation

**GO conditionnel pour ASTER-02 (modélisation dans Blender)**, après deux actions du propriétaire :

1. valider le plancher abaissé — **fait** (« Je valide », 2026-11-04) ;
2. relever l'étalonnage Blender → Studio — **reste à faire**.

Le système d'avatars est validé pour servir de base aux mesures : vrais clics, réplication, régression.

**NO-GO pour l'intégration définitive dans le jeu** tant que ces points ne sont pas tranchés :
- la vue au-dessus du volant pour H5 ;
- QA-A15 (sortie du passager) ;
- les essais de performance D5 avec le modèle réel.
