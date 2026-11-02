# Rapport de tests Roblox Studio (VM) 20261102-141650

_Généré automatiquement à partir de la sortie réelle de Studio. Chaque ligne correspond à une observation faite dans le moteur Roblox pendant la session indiquée._

| Exécution | Valeur |
|---|---|
| Studio | C:\Users\mimictest\AppData\Local\Roblox\Versions\version-7062aec9dbe74b14\RobloxStudioBeta.exe |
| Machine invitée / écran | DEV /  |
| Durée | 219.6 s |
| Délai dépassé | False |
| Captures d'écran | 81 (dossier screenshots) — état : ok |

Version Roblox : `0.745.0.7451137`

## Session « solo »

Durée 46,9 s, tentatives 1

### Serveur
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `serveur.zone_creee` | 116 instances |
| ✅ | `serveur.quatre_vehicules` | 4 véhicules |
| ✅ | `serveur.canaux_reseau` | 3 |
| ✅ | `serveur.vehicules_poses_et_immobiles` | VehiculeEssai_1: Y=1.78 vitesse=0.01 st/s droit=1.000 \| VehiculeEssai_2: Y=1.77 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_3: Y=1.77 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_4: Y=1.77 vitesse=0.00 st/s droit=1.000 |
| ✅ | `serveur.rapports_clients_recus` | 1 attendu(s) |
| ✅ | `serveur.propriete_reseau_conducteur` | 76 concordants, 2 discordants VehiculeEssai_1 propriétaire=serveur, VehiculeEssai_1 propriétaire=serveur |
| ✅ | `serveur.vehicules_libres_immobiles` | VehiculeEssai_2: 0.00 st \| VehiculeEssai_4: 0.00 st \| VehiculeEssai_3: 0.00 st |
| ✅ | `serveur.aucune_erreur_execution` |  |
| ✅ | `serveur.info_erreurs_internes_roblox` | 0 erreur(s) hors de notre code :  |
| ✅ | `serveur.info_invites_recues` | 1 : 941826283→VehiculeEssai_1 |
| ✅ | `serveur.journal_validation` | 2 message(s) : [AutomotiveWorld][Validation] Mouvement inhabituel (FastDisplacement), toléré. Occurrences : 1 \|\| [AutomotiveWorld][Validation] Mouvement impossible (Teleport) sur essai-e3e7591a-9bbe-4c79-81c4-a764fb0d6f4a, conducteur 941826283 : position corrigée, aucune sanction. |

### Client 941826283 — VehiculeEssai_1
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `client.demarrage` | bannière affichée |
| ✅ | `client.embarquement_invite` | essai 1 : assis, distance porte 2.5 st, invite active=false, ping 2 ms |
| ✅ | `client.session_conduite` | caméra=Scriptable HUD=true |
| ✅ | `client.propriete_attribuee` | DriverUserId=941826283 |
| ✅ | `client.tete_sous_le_toit` | marge tête 0.68 st, marge avec accessoires 0.34 st |
| ✅ | `client.repos_quatre_roues` | roues=4 ; vitesse 0.00 km/h à 1,5 s, 0.00 km/h à 4 s |
| ✅ | `client.acceleration_progressive` | 3.6 km/h à 0,25 s ; 14.6 km/h à 1 s |
| ✅ | `client.atteint_100_kmh` | 8.57 s (horloge client) |
| ✅ | `client.rapports_montent` | rapport max 3 |
| ✅ | `client.acceleration_bornee` | 7.41 m/s² max (moyenne glissante 50 ms) |
| ✅ | `client.sortie_refusee_en_roulant` | notification ExitTooFast=true |
| ✅ | `client.freinage_arret` | depuis 100 km/h : 47.5 m en 3.40 s |
| ✅ | `client.marche_arriere` | rapport=-1 vitesse=-8.07 m/s |
| ✅ | `client.virage_droite` | 77.3° en 2 s |
| ✅ | `client.virage_gauche` | -64.7° en 2 s |
| ✅ | `client.camera_proche_lointaine` | proche 14.5 st, Lointaine 24.0 st |
| ✅ | `client.frein_a_main_maintien` | déplacement 0.00 st |
| ✅ | `client.remise_sur_roues_inutile_refusee` |  |
| ✅ | `client.correction_mouvement_impossible` | notification=true, écart 0.0 st à 0,5 s, 0.0 st après retour au conducteur |
| ✅ | `client.sortie_a_l_arret` | caméra=Custom distance au véhicule 6.8 st |
| ✅ | `client.vehicule_libere` | DriverUserId=0 |
| ✅ | `client.aucune_erreur_execution` |  |
| ✅ | `client.info_erreurs_internes_roblox` | 0 erreur(s) hors de notre code :  |

| Mesure (moteur Roblox) | Valeur |
|---|---|
| correction_ecart_0_5s_st | 0.00362192839384079 |
| virage_droite_deg | 77.3152744209278 |
| correction_ecart_final_st | 0.0018241815268993378 |
| freinage_depuis_kmh | 100.3775001525879 |
| freinage_duree_s | 3.4013033000001089 |
| hud_0_100_s | 8.466742306249217 |
| acceleration_max_ms2 | 7.409566368197729 |
| virage_gauche_deg | -64.6631497781065 |
| repos_vitesse_4s_kmh | 0.00022327071928884834 |
| freinage_distance_m | 47.47707702636719 |
| marge_tete_toit_st | 0.6762505993247032 |
| ping_fin_ms | 4 |
| repos_vitesse_1_5s_kmh | 0.00024161181645467877 |
| marge_personnage_toit_st | 0.3383304700255394 |
| zero_a_cent_s | 8.56569189999982 |
| joueur | 1 |
| hud_100_0_m | 46.08886173353671 |
| ping_ms | 0 |

## Session « multijoueur »

Durée 74,7 s, tentatives 1

### Serveur
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `serveur.zone_creee` | 116 instances |
| ✅ | `serveur.quatre_vehicules` | 4 véhicules |
| ✅ | `serveur.canaux_reseau` | 3 |
| ✅ | `serveur.vehicules_poses_et_immobiles` | VehiculeEssai_1: Y=1.78 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_2: Y=1.78 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_3: Y=1.78 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_4: Y=1.78 vitesse=0.00 st/s droit=1.000 |
| ✅ | `serveur.rapports_clients_recus` | 2 attendu(s) |
| ✅ | `serveur.propriete_reseau_conducteur` | 163 concordants, 4 discordants VehiculeEssai_1 propriétaire=serveur, VehiculeEssai_1 propriétaire=serveur, VehiculeEssai_4 propriétaire=serveur, VehiculeEssai_4 propriétaire=serveur |
| ✅ | `serveur.vehicules_libres_immobiles` | VehiculeEssai_3: 0.11 st \| VehiculeEssai_2: 0.05 st |
| ✅ | `serveur.aucune_erreur_execution` |  |
| ✅ | `serveur.info_erreurs_internes_roblox` | 0 erreur(s) hors de notre code :  |
| ✅ | `serveur.info_invites_recues` | 2 : -1→VehiculeEssai_1, -2→VehiculeEssai_4 |
| ✅ | `serveur.journal_validation` | 2 message(s) : [AutomotiveWorld][Validation] Mouvement impossible (Teleport) sur essai-64f7ea0c-9bdd-4c3e-8ae6-aa2847c75c15, conducteur -1 : position corrigée, aucune sanction. \|\| [AutomotiveWorld][Validation] Mouvement impossible (Teleport) sur essai-5f3bba35-356b-4488-8f21-42406fae226c, conducteur -2 : position corrigée, aucune sanction. |

### Client -1 — VehiculeEssai_1
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `client.demarrage` | bannière affichée |
| ✅ | `client.embarquement_invite` | essai 1 : assis, distance porte 2.5 st, invite active=false, ping 15 ms |
| ✅ | `client.session_conduite` | caméra=Scriptable HUD=true |
| ✅ | `client.propriete_attribuee` | DriverUserId=-1 |
| ✅ | `client.tete_sous_le_toit` | marge tête 0.68 st, marge avec accessoires 0.34 st |
| ✅ | `client.info_attente_joueur_2` | signal reçu=true |
| ✅ | `client.repos_quatre_roues` | roues=4 ; vitesse 0.00 km/h à 1,5 s, 0.00 km/h à 4 s |
| ✅ | `client.acceleration_progressive` | 3.6 km/h à 0,25 s ; 14.4 km/h à 1 s |
| ✅ | `client.atteint_100_kmh` | 8.55 s (horloge client) |
| ✅ | `client.rapports_montent` | rapport max 3 |
| ✅ | `client.acceleration_bornee` | 5.02 m/s² max (moyenne glissante 50 ms) |
| ✅ | `client.sortie_refusee_en_roulant` | notification ExitTooFast=true |
| ✅ | `client.freinage_arret` | depuis 100 km/h : 47.5 m en 3.40 s |
| ✅ | `client.marche_arriere` | rapport=-1 vitesse=-8.07 m/s |
| ✅ | `client.virage_droite` | 77.1° en 2 s |
| ✅ | `client.virage_gauche` | -65.5° en 2 s |
| ✅ | `client.camera_proche_lointaine` | proche 14.5 st, Lointaine 24.0 st |
| ✅ | `client.frein_a_main_maintien` | déplacement 0.00 st |
| ✅ | `client.remise_sur_roues_inutile_refusee` |  |
| ✅ | `client.correction_mouvement_impossible` | notification=true, écart 73.0 st à 0,5 s, 2.5 st après retour au conducteur |
| ✅ | `client.sortie_a_l_arret` | caméra=Custom distance au véhicule 6.1 st |
| ✅ | `client.vehicule_libere` | DriverUserId=0 |
| ✅ | `client.aucune_erreur_execution` |  |
| ✅ | `client.info_erreurs_internes_roblox` | 0 erreur(s) hors de notre code :  |

| Mesure (moteur Roblox) | Valeur |
|---|---|
| correction_ecart_0_5s_st | 73.00157165527344 |
| virage_droite_deg | 77.11123787173234 |
| correction_ecart_final_st | 2.4920337200164797 |
| freinage_depuis_kmh | 100.26410064697267 |
| freinage_duree_s | 3.4046714000000977 |
| hud_0_100_s | 8.45034940354526 |
| acceleration_max_ms2 | 5.024300692643951 |
| virage_gauche_deg | -65.49200121856986 |
| zero_a_cent_s | 8.55034250000017 |
| repos_vitesse_4s_kmh | 0.00021917488920735197 |
| marge_tete_toit_st | 0.676250122487545 |
| ping_fin_ms | 4 |
| freinage_distance_m | 47.505625610351568 |
| marge_personnage_toit_st | 0.3383299931883812 |
| repos_vitesse_1_5s_kmh | 0.00022065889206714928 |
| joueur | 1 |
| hud_100_0_m | 46.11890405355119 |
| ping_ms | 20 |

### Client -2 — VehiculeEssai_4
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `client.demarrage` | bannière affichée |
| ✅ | `client.vehicule_occupe_refuse` | invite active=false |
| ✅ | `client.voit_autre_conducteur` | DriverUserId=-1 |
| ✅ | `client.embarquement_invite` | essai 1 : assis, distance porte 2.5 st, invite active=false, ping 5 ms |
| ✅ | `client.session_conduite` | caméra=Scriptable HUD=true |
| ✅ | `client.propriete_attribuee` | DriverUserId=-2 |
| ✅ | `client.tete_sous_le_toit` | marge tête 0.68 st, marge avec accessoires 0.34 st |
| ✅ | `client.repos_quatre_roues` | roues=4 ; vitesse 0.00 km/h à 1,5 s, 0.00 km/h à 4 s |
| ✅ | `client.acceleration_progressive` | 3.4 km/h à 0,25 s ; 13.4 km/h à 1 s |
| ✅ | `client.atteint_100_kmh` | 8.63 s (horloge client) |
| ✅ | `client.rapports_montent` | rapport max 3 |
| ✅ | `client.acceleration_bornee` | 6.10 m/s² max (moyenne glissante 50 ms) |
| ✅ | `client.sortie_refusee_en_roulant` | notification ExitTooFast=true |
| ✅ | `client.freinage_arret` | depuis 100 km/h : 47.5 m en 3.40 s |
| ✅ | `client.marche_arriere` | rapport=-1 vitesse=-8.00 m/s |
| ✅ | `client.virage_droite` | 77.7° en 2 s |
| ✅ | `client.virage_gauche` | -65.5° en 2 s |
| ✅ | `client.camera_proche_lointaine` | proche 14.5 st, Lointaine 24.0 st |
| ✅ | `client.frein_a_main_maintien` | déplacement 0.00 st |
| ✅ | `client.remise_sur_roues_inutile_refusee` |  |
| ✅ | `client.correction_mouvement_impossible` | notification=true, écart 0.0 st à 0,5 s, 0.0 st après retour au conducteur |
| ✅ | `client.sortie_a_l_arret` | caméra=Custom distance au véhicule 6.7 st |
| ✅ | `client.vehicule_libere` | DriverUserId=0 |
| ✅ | `client.aucune_erreur_execution` |  |
| ✅ | `client.info_erreurs_internes_roblox` | 0 erreur(s) hors de notre code :  |

| Mesure (moteur Roblox) | Valeur |
|---|---|
| correction_ecart_0_5s_st | 0.001712847501039505 |
| virage_droite_deg | 77.66062431500272 |
| correction_ecart_final_st | 0.004267917480319738 |
| freinage_depuis_kmh | 100.33549118041992 |
| freinage_duree_s | 3.3983432999998515 |
| hud_0_100_s | 8.484439365565777 |
| acceleration_max_ms2 | 6.1012169660611959 |
| virage_gauche_deg | -65.51139247799438 |
| zero_a_cent_s | 8.634574499999872 |
| repos_vitesse_4s_kmh | 0.00021454583911690862 |
| marge_tete_toit_st | 0.6762508377432823 |
| ping_fin_ms | 4 |
| freinage_distance_m | 47.45923095703125 |
| marge_personnage_toit_st | 0.3383307084441185 |
| repos_vitesse_1_5s_kmh | 0.00022948752448428422 |
| joueur | 2 |
| hud_100_0_m | 44.70261184735985 |
| ping_ms | 5 |

## Session « latence »

Durée 77,1 s, tentatives 1 ; latence demandée 100 ms (réglage appliqué : True)

### Serveur
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `serveur.zone_creee` | 116 instances |
| ✅ | `serveur.quatre_vehicules` | 4 véhicules |
| ✅ | `serveur.canaux_reseau` | 3 |
| ✅ | `serveur.vehicules_poses_et_immobiles` | VehiculeEssai_1: Y=1.78 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_2: Y=1.78 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_3: Y=1.78 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_4: Y=1.78 vitesse=0.00 st/s droit=1.000 |
| ✅ | `serveur.rapports_clients_recus` | 2 attendu(s) |
| ✅ | `serveur.propriete_reseau_conducteur` | 171 concordants, 4 discordants VehiculeEssai_1 propriétaire=serveur, VehiculeEssai_1 propriétaire=serveur, VehiculeEssai_4 propriétaire=serveur, VehiculeEssai_4 propriétaire=serveur |
| ✅ | `serveur.vehicules_libres_immobiles` | VehiculeEssai_3: 0.13 st \| VehiculeEssai_2: 0.16 st |
| ✅ | `serveur.aucune_erreur_execution` |  |
| ✅ | `serveur.info_erreurs_internes_roblox` | 0 erreur(s) hors de notre code :  |
| ✅ | `serveur.info_invites_recues` | 2 : -1→VehiculeEssai_1, -2→VehiculeEssai_4 |
| ✅ | `serveur.journal_validation` | 2 message(s) : [AutomotiveWorld][Validation] Mouvement impossible (Teleport) sur essai-ae3a410e-7cf3-4f2f-8e7e-8cf162a601c2, conducteur -1 : position corrigée, aucune sanction. \|\| [AutomotiveWorld][Validation] Mouvement impossible (Teleport) sur essai-c6da1b85-8213-4d8c-9e2f-8ba55a643320, conducteur -2 : position corrigée, aucune sanction. |

### Client -1 — VehiculeEssai_1
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `client.demarrage` | bannière affichée |
| ✅ | `client.embarquement_invite` | essai 1 : assis, distance porte 2.5 st, invite active=false, ping 213 ms |
| ✅ | `client.session_conduite` | caméra=Scriptable HUD=true |
| ✅ | `client.propriete_attribuee` | DriverUserId=-1 |
| ✅ | `client.tete_sous_le_toit` | marge tête 0.69 st, marge avec accessoires 0.35 st |
| ✅ | `client.info_attente_joueur_2` | signal reçu=true |
| ✅ | `client.repos_quatre_roues` | roues=4 ; vitesse 0.00 km/h à 1,5 s, 0.00 km/h à 4 s |
| ✅ | `client.acceleration_progressive` | 3.6 km/h à 0,25 s ; 14.6 km/h à 1 s |
| ✅ | `client.atteint_100_kmh` | 8.55 s (horloge client) |
| ✅ | `client.rapports_montent` | rapport max 3 |
| ✅ | `client.acceleration_bornee` | 4.82 m/s² max (moyenne glissante 50 ms) |
| ✅ | `client.sortie_refusee_en_roulant` | notification ExitTooFast=true |
| ✅ | `client.freinage_arret` | depuis 102 km/h : 48.6 m en 3.43 s |
| ✅ | `client.marche_arriere` | rapport=-1 vitesse=-8.08 m/s |
| ✅ | `client.virage_droite` | 77.7° en 2 s |
| ✅ | `client.virage_gauche` | -65.7° en 2 s |
| ✅ | `client.camera_proche_lointaine` | proche 14.5 st, Lointaine 24.0 st |
| ✅ | `client.frein_a_main_maintien` | déplacement 0.00 st |
| ✅ | `client.remise_sur_roues_inutile_refusee` |  |
| ✅ | `client.correction_mouvement_impossible` | notification=true, écart 62.3 st à 0,5 s, 0.5 st après retour au conducteur |
| ✅ | `client.sortie_a_l_arret` | caméra=Custom distance au véhicule 6.9 st |
| ✅ | `client.vehicule_libere` | DriverUserId=0 |
| ✅ | `client.aucune_erreur_execution` |  |
| ✅ | `client.info_erreurs_internes_roblox` | 0 erreur(s) hors de notre code :  |

| Mesure (moteur Roblox) | Valeur |
|---|---|
| correction_ecart_0_5s_st | 62.29597091674805 |
| virage_droite_deg | 77.67176334993961 |
| correction_ecart_final_st | 0.5251240730285645 |
| freinage_depuis_kmh | 101.77011337280274 |
| freinage_duree_s | 3.43225990000019 |
| hud_0_100_s | 8.448393801227212 |
| acceleration_max_ms2 | 4.822568732663559 |
| virage_gauche_deg | -65.71056164297119 |
| zero_a_cent_s | 8.549099100000149 |
| repos_vitesse_4s_kmh | 0.00022314988891594111 |
| marge_tete_toit_st | 0.688323400914669 |
| ping_fin_ms | 205 |
| freinage_distance_m | 48.62935974121094 |
| marge_personnage_toit_st | 0.35188981145620348 |
| repos_vitesse_1_5s_kmh | 0.0001943071183632128 |
| joueur | 1 |
| hud_100_0_m | 45.836148950678239 |
| ping_ms | 206 |

### Client -2 — VehiculeEssai_4
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `client.demarrage` | bannière affichée |
| ✅ | `client.vehicule_occupe_refuse` | invite active=false |
| ✅ | `client.voit_autre_conducteur` | DriverUserId=-1 |
| ✅ | `client.embarquement_invite` | essai 1 : assis, distance porte 2.5 st, invite active=false, ping 205 ms |
| ✅ | `client.session_conduite` | caméra=Scriptable HUD=true |
| ✅ | `client.propriete_attribuee` | DriverUserId=-2 |
| ✅ | `client.tete_sous_le_toit` | marge tête 0.68 st, marge avec accessoires 0.34 st |
| ✅ | `client.repos_quatre_roues` | roues=4 ; vitesse 0.00 km/h à 1,5 s, 0.00 km/h à 4 s |
| ✅ | `client.acceleration_progressive` | 3.6 km/h à 0,25 s ; 14.4 km/h à 1 s |
| ✅ | `client.atteint_100_kmh` | 8.62 s (horloge client) |
| ✅ | `client.rapports_montent` | rapport max 3 |
| ✅ | `client.acceleration_bornee` | 8.61 m/s² max (moyenne glissante 50 ms) |
| ✅ | `client.sortie_refusee_en_roulant` | notification ExitTooFast=true |
| ✅ | `client.freinage_arret` | depuis 102 km/h : 48.8 m en 3.45 s |
| ✅ | `client.marche_arriere` | rapport=-1 vitesse=-8.07 m/s |
| ✅ | `client.virage_droite` | 77.2° en 2 s |
| ✅ | `client.virage_gauche` | -65.5° en 2 s |
| ✅ | `client.camera_proche_lointaine` | proche 14.5 st, Lointaine 24.0 st |
| ✅ | `client.frein_a_main_maintien` | déplacement 0.00 st |
| ✅ | `client.remise_sur_roues_inutile_refusee` |  |
| ✅ | `client.correction_mouvement_impossible` | notification=true, écart 0.0 st à 0,5 s, 0.0 st après retour au conducteur |
| ✅ | `client.sortie_a_l_arret` | caméra=Custom distance au véhicule 6.7 st |
| ✅ | `client.vehicule_libere` | DriverUserId=0 |
| ✅ | `client.aucune_erreur_execution` |  |
| ✅ | `client.info_erreurs_internes_roblox` | 0 erreur(s) hors de notre code :  |

| Mesure (moteur Roblox) | Valeur |
|---|---|
| correction_ecart_0_5s_st | 0.0029548369348049165 |
| virage_droite_deg | 77.15821489100695 |
| correction_ecart_final_st | 0.002941154409199953 |
| freinage_depuis_kmh | 101.92561111450196 |
| freinage_duree_s | 3.449641800000336 |
| hud_0_100_s | 8.550606019794941 |
| acceleration_max_ms2 | 8.612439842728206 |
| virage_gauche_deg | -65.48625641666013 |
| zero_a_cent_s | 8.615857900000265 |
| repos_vitesse_4s_kmh | 0.00022383178293239325 |
| marge_tete_toit_st | 0.676250122487545 |
| ping_fin_ms | 205 |
| freinage_distance_m | 48.846323852539068 |
| marge_personnage_toit_st | 0.3383299931883812 |
| repos_vitesse_1_5s_kmh | 0.00022433123958762736 |
| joueur | 2 |
| hud_100_0_m | 45.59013884182683 |
| ping_ms | 206 |

**Synthèse : 154 contrôle(s) réussi(s), 0 échec(s), 3 session(s).**

Non couvert automatiquement : lecture réelle du clavier et de la manette (commandes injectées par le point d'accès de test), ressenti de conduite, lisibilité, son. Voir les captures pour le rendu.
