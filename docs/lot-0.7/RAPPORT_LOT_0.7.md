# Rapport du lot 0.7 — interface complète, GPS, smartphone et fonctionnalités sociales

Branche `feat/ui-gps-social-0.7`, créée depuis `c408164` (dernier commit du lot 0.6), PR brouillon vers
`feat/racing-competition-0.6`. Aucune branche précédente ni `main` n'a été modifiée.

Décision du propriétaire : pas de grande campagne QA ; essais humains, multijoueur, communications réelles,
lisibilité, charge et DataStore reportés au lot QA (`docs/QA_BACKLOG.md` §3 quinquies). Ce lot comporte les
contrôles rapides, des tests purs ciblés et de courtes sessions de démarrage dans la VM. **Aucun parcours utilisateur
n'a été joué par un humain ; le rendu, l'ergonomie et la lisibilité ne sont pas validés.**

## 1. État des livrables

Légende : **Implémenté** (code complet, règles testées hors Studio) ; **Partiel** (une partie manque, précisée) ;
**NON TESTÉ** (aucune exécution en jeu de la fonction).

| # | Livrable | État | Précisions |
|---|---|---|---|
| 1 | Architecture UI centralisée | Implémenté | `UIManager`, `UIStack`, `InputRouter`/`InputMap`, `UIState`, `UITheme`, `Localization` ; panneaux des lots 0.4–0.6 inscrits, règles serveur inchangées |
| 2 | HUD contextuel et personnalisable | Implémenté | Minimal / Standard / Complet, cockpit, course, à pied ; taille, coin, mini-carte. Rendu NON TESTÉ visuellement |
| 3 | Mini-carte | Implémenté | Routes simplifiées, itinéraire, lieux, objectif au bord, membres qui partagent ; rotation et zoom |
| 4 | Carte interactive | Implémenté | Glisser, molette, stick droit, zoom, liste des lieux (manette), « Définir ici », profil routes / tout-terrain |
| 5 | GPS (itinéraires, recalcul) | Implémenté | Graphe du lot 0.3, profils, manœuvres, distance, durée, recalcul limité. Zone d'essai : guidage direct. Avec trafic et streaming réels : NON TESTÉ |
| 6 | Smartphone physiquement représenté | Partiel | Modèle provisoire original dans la main, bras levé par l'épaule (aucune animation : pas d'actif externe), écran générique pour les autres. Pose réelle NON TESTÉE |
| 7 | Applications connectées | Implémenté | 9 applications ; lecture des instantanés existants ; actions par les panneaux et canaux existants (aucune seconde logique d'achat ou de récompense) |
| 8 | Groupes de huit | Implémenté | Créer, inviter, accepter, refuser, quitter, exclure, confier la direction, dissoudre ; absences et direction vacante |
| 9 | Invitations et permissions | Implémenté | Responsable seul, expiration, retrait ; le groupe ne donne aucun droit (propriétés, conduite, prêts, économie) |
| 10 | Partage de position volontaire | Implémenté | Désactivé par défaut, groupe actuel, 2 h au plus, arrêts immédiats ; envois filtrés par destinataire |
| 11 | Communications conformes | Partiel | Canaux TextChatService (groupe, proximité 80 m) ; filtrage, âge, modération par Roblox ; voix selon Roblox (non gérée). Jamais exécuté avec de vrais comptes : NON TESTÉ |
| 12 | Notifications hiérarchisées | Partiel | 3 niveaux, conduite, regroupement, historique ; multimodal : texte, icône, cadre clignotant — **aucun son** (aucun son original avant le lot 0.8) |
| 13 | Accessibilité | Implémenté | Texte, contraste, animations, opacité, sensibilité, notifications secondaires, alertes visuelles, volumes (groupes de sons, aucun son existant) |
| 14 | Navigation clavier/manette | Implémenté | Focus visible et rendu, retour B seulement en menu, raccourcis personnalisables, garde de confirmation. Essais humains NON TESTÉS |
| 15 | Localisation FR/EN | Partiel | 330+ clés FR/EN (statuts, erreurs, achats, ventes, autorisations, sécurité, navigation, paramètres) ; changement à chaud. Libellés internes des panneaux provisoires 0.4–0.6 toujours en français. Relecture : lot 0.8 |
| 16 | Préférences sauvegardées | Implémenté | Profil v4, migration 3 → 4, nettoyage serveur, envoi regroupé (≤ 1 / 5 s), écriture par la sauvegarde périodique. DataStore réel NON TESTÉ |
| 17 | Tests essentiels et rapport factuel | Ce rapport, §2 |
| 18–22 | Rapport, architecture, registre QA, feuille de route, PR | `RAPPORT_LOT_0.7.md`, `ARCHITECTURE_LOT_0.7.md`, `QA_BACKLOG.md` §3 quinquies, `ROADMAP.md` |

## 2. Vérifications exécutées

### 2.1 Hors Studio

`powershell -ExecutionPolicy Bypass -File scripts\verify.ps1 -RobloxTypes .tooling\globalTypes.d.luau` :
voir §2.3 pour l'exécution finale (date, commit). Tests du lot (`tests/lune/specs/Lot07Interface.luau`, 17 tests) :

| Cas demandé | Résultat |
|---|---|
| Calcul d'itinéraires | OK : Place Centrale → Port-Soleil 3,4 km, 3 min, 6 manœuvres ordonnées, arrivée en dernier ; paddock → Col du Grand Ravin > 5 km guidé ; profils routes / tout-terrain |
| Recalcul et destinations invalides | OK : NaN et hors carte refusés ; pas de recalcul avant 3 s hors itinéraire ni en rafale ; arrivée détectée ; guidage direct |
| Routes ↔ mini-carte | OK : aller-retour exact, cap vers le haut, objectif ramené au bord ; tracés simplifiés, requête limitée aux cellules visibles, niveau de détail |
| Points d'intérêt | OK : 0 erreur ; chaque point remonte à un lieu de la carte ou à un parcours ; 16 départs de course ; points personnels limités au joueur ; doublon détecté |
| Ouverture / fermeture | OK : une seule modale, retour sur le dessus, rien de capturé après fermeture |
| Gestion du focus | OK : focus d'avant rendu, réouverture sans écrasement, mode rapide sans capture |
| Blocage des menus financiers en mouvement | OK : écran complet et confirmation refusés en roulant, rapide autorisé, hystérésis |
| Groupes de huit au plus | OK : huitième accepté, neuvième refusé, un groupe à la fois |
| Invitations et révocations | OK : expiration, retrait, refus, responsable seul, préférence du destinataire, direction transmise, dissolution, absences |
| Partage désactivé par défaut | OK : rien par défaut, groupe seulement, jamais soi-même, désactivation, déconnexion, échéance, sortie |
| Filtrage des données privées | OK : seuls les champs autorisés, même avec un annuaire « bavard » (solde, collection, propriétés, transactions) |
| Localisation | OK : toutes les clés FR/EN, mêmes paramètres, changement à chaud, préfixes, formats ; TOUTES les clés d'erreur `rejected("…")` du serveur traduites (le test a révélé 2 manques, corrigés) |
| Migration des paramètres | OK : v3 → v4, profil valide, original intact ; nettoyage (bornes, énumérations, champs étrangers, critiques non désactivables, partage jamais durable) |
| Notifications et priorités | OK : différées / compactes / critiques en conduite, multimodal, regroupement, niveaux désactivés, historique borné, non lues |
| Pas de double confirmation au changement de périphérique | OK : pressions antérieures ou trop proches refusées ; capture de la conduite puis relâchement exigé |

Défauts trouvés par ces tests et corrigés : une invitation expirée bloquait une nouvelle invitation jusqu'au
passage suivant de l'horloge ; un groupe vidé par le départ de son dernier membre ne fermait pas son canal ; deux
clés d'erreur du serveur (`PropertyUnknownOffer`, `VehicleModelMissing`) n'avaient aucun texte.

### 2.2 Contrôles de démarrage dans Studio (VM)

| Tâche | Session | Résultat |
|---|---|---|
| `20261103-120345` | `solo` + `lot04` (place de développement) | **102 / 0** : conduite avec le nouveau HUD (`client.session_conduite` : HUD visible), canaux d'interface et des groupes, aucune erreur client ni serveur |
| `20261103-120617` | `monde` (monde ouvert) | **37 / 0** : canaux d'interface et des groupes, **55 points d'intérêt** publics issus des registres, aucune erreur, conduite à 133 km/h sur l'autoroute |

Ces sessions vérifient le chargement et la conduite de base ; **aucune interface n'a été parcourue** (téléphone,
carte, groupes, paramètres : NON TESTÉS en jeu).

### 2.3 Exécution finale

`powershell -ExecutionPolicy Bypass -File scripts\verify.ps1 -RobloxTypes .tooling\globalTypes.d.luau`, exécutée le
2026-11-03 à 12:08 sur le commit `d674308` (code du lot) : Rojo (deux places), Selene, StyLua, pilote Studio,
**Lune 307 réussis / 0 échoué** (dont 17 du lot 0.7), génération de la carte, **Pytest 10 réussis**, luau-lsp strict
0 erreur. Les sessions VM ci-dessus ont été exécutées sur l'arbre de travail dont le code est identique à ce commit.

## 3. Écarts, choix et points à arbitrer

1. **Téléphone** : pas d'animation (un actif d'animation exigerait une publication) ; bras levé par l'épaule.
2. **Son** : aucun son original n'existe ; les alertes critiques sont visuelles (texte, icône, cadre clignotant) ;
   les volumes pilotent des groupes de sons encore vides.
3. **Libellés des panneaux 0.4–0.6** : restés en français (statuts et erreurs traduits) ; migration complète au lot 0.8.
4. **HUD de développement** : désactivé par défaut (paramètres) ; un contrôle Studio existant (`client.session_conduite`)
   vérifie désormais le nouveau HUD.
5. **Communications** : texte seulement par les canaux officiels ; la voix reste un réglage Roblox. Les invitations
   ne concernent que les joueurs du même serveur (pas d'invitation inter-serveurs).
6. **Raccourcis** : T (téléphone, manette X), M (carte), H (niveau du HUD), X (effacer l'itinéraire) ajoutés ; P, J, K
   conservés. Retour : Retour arrière / B seulement quand un menu est ouvert (B reste l'embrayage au volant).
7. **Carte en roulant** : consultation autorisée (aucune action sensible), sans sélection manette ; à arbitrer
   (lecture d'une carte complète en conduite).
8. **Écran d'accueil du téléphone** : heure réelle du joueur (l'heure du jeu reste celle du ciel).
9. Version de développement inchangée (`0.4.0-dev`).

Anomalies connues des lots précédents : non corrigées ni retestées (`docs/QA_BACKLOG.md` §1).
