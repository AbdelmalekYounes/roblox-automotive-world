# Rapport de tests Roblox Studio (VM) 20261102-140007

_Généré automatiquement à partir de la sortie réelle de Studio. Chaque ligne correspond à une observation faite dans le moteur Roblox pendant la session indiquée._

| Exécution | Valeur |
|---|---|
| Studio | C:\Users\mimictest\AppData\Local\Roblox\Versions\version-7062aec9dbe74b14\RobloxStudioBeta.exe |
| Machine invitée / écran | DEV /  |
| Durée | 216.5 s |
| Délai dépassé | False |
| Captures d'écran | 0 (dossier screenshots) — état : bloquées par l'antivirus de la VM |

Version Roblox : `0.745.0.7451137`

## Session « solo »

Durée 46,2 s, tentatives 1

### Serveur
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `serveur.zone_creee` | 116 instances |
| ✅ | `serveur.quatre_vehicules` | 4 véhicules |
| ✅ | `serveur.canaux_reseau` | 3 |
| ✅ | `serveur.vehicules_poses_et_immobiles` | VehiculeEssai_1: Y=1.78 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_2: Y=1.78 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_3: Y=1.78 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_4: Y=1.78 vitesse=0.00 st/s droit=1.000 |
| ✅ | `serveur.rapports_clients_recus` | 1 attendu(s) |
| ✅ | `serveur.propriete_reseau_conducteur` | 74 concordants, 2 discordants VehiculeEssai_1 propriétaire=serveur, VehiculeEssai_1 propriétaire=serveur |
| ✅ | `serveur.vehicules_libres_immobiles` | VehiculeEssai_2: 0.00 st \| VehiculeEssai_4: 0.00 st \| VehiculeEssai_3: 0.00 st |
| ✅ | `serveur.aucune_erreur_execution` |  |
| ✅ | `serveur.info_erreurs_internes_roblox` | 0 erreur(s) hors de notre code :  |
| ✅ | `serveur.info_invites_recues` | 1 : 941826283→VehiculeEssai_1 |
| ✅ | `serveur.journal_validation` | 2 message(s) : [AutomotiveWorld][Validation] Mouvement inhabituel (FastDisplacement), toléré. Occurrences : 1 \|\| [AutomotiveWorld][Validation] Mouvement impossible (Teleport) sur essai-88e8135e-da5a-462e-bf5d-efbe6d30dac9, conducteur 941826283 : position corrigée, aucune sanction. |

### Client 941826283 — VehiculeEssai_1
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `client.demarrage` | bannière affichée |
| ✅ | `client.embarquement_invite` | essai 1 : assis, distance porte 2.7 st, invite active=false, ping 1 ms |
| ✅ | `client.session_conduite` | caméra=Scriptable HUD=true |
| ✅ | `client.propriete_attribuee` | DriverUserId=941826283 |
| ✅ | `client.repos_quatre_roues` | roues=4 ; vitesse 0.00 km/h à 1,5 s, 0.00 km/h à 4 s |
| ✅ | `client.acceleration_progressive` | 3.6 km/h à 0,25 s ; 14.6 km/h à 1 s |
| ✅ | `client.atteint_100_kmh` | 8.57 s (horloge client) |
| ✅ | `client.rapports_montent` | rapport max 3 |
| ✅ | `client.acceleration_bornee` | 7.45 m/s² max (moyenne glissante 50 ms) |
| ✅ | `client.sortie_refusee_en_roulant` | notification ExitTooFast=true |
| ✅ | `client.freinage_arret` | depuis 100 km/h : 47.6 m en 3.40 s |
| ✅ | `client.marche_arriere` | rapport=-1 vitesse=-8.02 m/s |
| ✅ | `client.virage_droite` | 77.1° en 2 s |
| ✅ | `client.virage_gauche` | -65.5° en 2 s |
| ✅ | `client.camera_proche_lointaine` | proche 14.5 st, Lointaine 24.0 st |
| ✅ | `client.frein_a_main_maintien` | déplacement 0.00 st |
| ✅ | `client.remise_sur_roues_inutile_refusee` |  |
| ✅ | `client.correction_mouvement_impossible` | notification=true, écart 0.0 st à 0,5 s, 0.0 st après retour au conducteur |
| ✅ | `client.sortie_a_l_arret` | caméra=Custom distance au véhicule 6.5 st |
| ✅ | `client.vehicule_libere` | DriverUserId=0 |
| ✅ | `client.aucune_erreur_execution` |  |
| ✅ | `client.info_erreurs_internes_roblox` | 0 erreur(s) hors de notre code :  |

| Mesure (moteur Roblox) | Valeur |
|---|---|
| repos_vitesse_4s_kmh | 0.00022328211343847215 |
| hud_0_100_s | 8.464619102189318 |
| correction_ecart_0_5s_st | 0.004373535513877869 |
| virage_droite_deg | 77.0684760182107 |
| acceleration_max_ms2 | 7.454407337897138 |
| virage_gauche_deg | -65.45973705243091 |
| freinage_depuis_kmh | 100.48780975341798 |
| hud_100_0_m | 46.16799518787183 |
| correction_ecart_final_st | 0.0051038386300206188 |
| freinage_distance_m | 47.55770263671875 |
| zero_a_cent_s | 8.565093999999818 |
| ping_fin_ms | 2 |
| repos_vitesse_1_5s_kmh | 0.00023046642600093039 |
| joueur | 1 |
| freinage_duree_s | 3.4011502999999267 |
| ping_ms | 2 |

## Session « multijoueur »

Durée 71,1 s, tentatives 1

### Serveur
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `serveur.zone_creee` | 116 instances |
| ✅ | `serveur.quatre_vehicules` | 4 véhicules |
| ✅ | `serveur.canaux_reseau` | 3 |
| ✅ | `serveur.vehicules_poses_et_immobiles` | VehiculeEssai_1: Y=1.78 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_2: Y=1.78 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_3: Y=1.78 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_4: Y=1.78 vitesse=0.00 st/s droit=1.000 |
| ✅ | `serveur.rapports_clients_recus` | 2 attendu(s) |
| ✅ | `serveur.propriete_reseau_conducteur` | 160 concordants, 4 discordants VehiculeEssai_1 propriétaire=serveur, VehiculeEssai_4 propriétaire=serveur, VehiculeEssai_1 propriétaire=serveur, VehiculeEssai_4 propriétaire=serveur |
| ✅ | `serveur.vehicules_libres_immobiles` | VehiculeEssai_2: 1.30 st \| VehiculeEssai_3: 0.30 st |
| ✅ | `serveur.aucune_erreur_execution` |  |
| ✅ | `serveur.info_erreurs_internes_roblox` | 0 erreur(s) hors de notre code :  |
| ✅ | `serveur.info_invites_recues` | 2 : -1→VehiculeEssai_1, -2→VehiculeEssai_4 |
| ✅ | `serveur.journal_validation` | 2 message(s) : [AutomotiveWorld][Validation] Mouvement impossible (Teleport) sur essai-2b65ec01-4ffd-4ded-a11e-63a5661797f0, conducteur -1 : position corrigée, aucune sanction. \|\| [AutomotiveWorld][Validation] Mouvement impossible (Teleport) sur essai-00723092-864c-4027-8e18-576fcfc44cfd, conducteur -2 : position corrigée, aucune sanction. |

### Client -1 — VehiculeEssai_1
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `client.demarrage` | bannière affichée |
| ✅ | `client.embarquement_invite` | essai 1 : assis, distance porte 2.7 st, invite active=false, ping 5 ms |
| ✅ | `client.session_conduite` | caméra=Scriptable HUD=true |
| ✅ | `client.propriete_attribuee` | DriverUserId=-1 |
| ✅ | `client.info_attente_joueur_2` | signal reçu=true |
| ✅ | `client.repos_quatre_roues` | roues=4 ; vitesse 0.00 km/h à 1,5 s, 0.00 km/h à 4 s |
| ✅ | `client.acceleration_progressive` | 3.6 km/h à 0,25 s ; 13.6 km/h à 1 s |
| ✅ | `client.atteint_100_kmh` | 8.60 s (horloge client) |
| ✅ | `client.rapports_montent` | rapport max 3 |
| ✅ | `client.acceleration_bornee` | 6.49 m/s² max (moyenne glissante 50 ms) |
| ✅ | `client.sortie_refusee_en_roulant` | notification ExitTooFast=true |
| ✅ | `client.freinage_arret` | depuis 100 km/h : 47.5 m en 3.40 s |
| ✅ | `client.marche_arriere` | rapport=-1 vitesse=-8.12 m/s |
| ✅ | `client.virage_droite` | 77.8° en 2 s |
| ✅ | `client.virage_gauche` | -65.5° en 2 s |
| ✅ | `client.camera_proche_lointaine` | proche 14.5 st, Lointaine 24.0 st |
| ✅ | `client.frein_a_main_maintien` | déplacement 0.00 st |
| ✅ | `client.remise_sur_roues_inutile_refusee` |  |
| ✅ | `client.correction_mouvement_impossible` | notification=true, écart 57.4 st à 0,5 s, 1.1 st après retour au conducteur |
| ✅ | `client.sortie_a_l_arret` | caméra=Custom distance au véhicule 6.6 st |
| ✅ | `client.vehicule_libere` | DriverUserId=0 |
| ✅ | `client.aucune_erreur_execution` |  |
| ✅ | `client.info_erreurs_internes_roblox` | 0 erreur(s) hors de notre code :  |

| Mesure (moteur Roblox) | Valeur |
|---|---|
| joueur | 1 |
| correction_ecart_0_5s_st | 57.435699462890628 |
| repos_vitesse_4s_kmh | 0.00022368014906533064 |
| virage_droite_deg | 77.8024862130561 |
| acceleration_max_ms2 | 6.492469926531604 |
| virage_gauche_deg | -65.48661025416378 |
| repos_vitesse_1_5s_kmh | 0.0003112978854915127 |
| hud_100_0_m | 46.0644482557817 |
| correction_ecart_final_st | 1.0796804428100587 |
| hud_0_100_s | 8.499308100668714 |
| zero_a_cent_s | 8.599805099999913 |
| ping_fin_ms | 6 |
| freinage_distance_m | 47.45149353027344 |
| freinage_depuis_kmh | 100.29154586791992 |
| freinage_duree_s | 3.4005670999999895 |
| ping_ms | 12 |

### Client -2 — VehiculeEssai_4
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `client.demarrage` | bannière affichée |
| ✅ | `client.vehicule_occupe_refuse` | invite active=false |
| ✅ | `client.voit_autre_conducteur` | DriverUserId=-1 |
| ✅ | `client.embarquement_invite` | essai 1 : assis, distance porte 2.7 st, invite active=false, ping 3 ms |
| ✅ | `client.session_conduite` | caméra=Scriptable HUD=true |
| ✅ | `client.propriete_attribuee` | DriverUserId=-2 |
| ✅ | `client.repos_quatre_roues` | roues=4 ; vitesse 0.00 km/h à 1,5 s, 0.00 km/h à 4 s |
| ✅ | `client.acceleration_progressive` | 3.3 km/h à 0,25 s ; 14.3 km/h à 1 s |
| ✅ | `client.atteint_100_kmh` | 8.57 s (horloge client) |
| ✅ | `client.rapports_montent` | rapport max 3 |
| ✅ | `client.acceleration_bornee` | 5.06 m/s² max (moyenne glissante 50 ms) |
| ✅ | `client.sortie_refusee_en_roulant` | notification ExitTooFast=true |
| ✅ | `client.freinage_arret` | depuis 100 km/h : 47.6 m en 3.40 s |
| ✅ | `client.marche_arriere` | rapport=-1 vitesse=-8.09 m/s |
| ✅ | `client.virage_droite` | 77.6° en 2 s |
| ✅ | `client.virage_gauche` | -65.6° en 2 s |
| ✅ | `client.camera_proche_lointaine` | proche 14.5 st, Lointaine 24.0 st |
| ✅ | `client.frein_a_main_maintien` | déplacement 0.00 st |
| ✅ | `client.remise_sur_roues_inutile_refusee` |  |
| ✅ | `client.correction_mouvement_impossible` | notification=true, écart 70.2 st à 0,5 s, 2.0 st après retour au conducteur |
| ✅ | `client.sortie_a_l_arret` | caméra=Custom distance au véhicule 6.5 st |
| ✅ | `client.vehicule_libere` | DriverUserId=0 |
| ✅ | `client.aucune_erreur_execution` |  |
| ✅ | `client.info_erreurs_internes_roblox` | 1 erreur(s) hors de notre code : Players.Player2.PlayerScripts.ChatScript:116: Error calling SetCore CoreGuiChatConnections: SetCore: CoreGuiChatConnections has not been registered by the CoreScripts |

| Mesure (moteur Roblox) | Valeur |
|---|---|
| joueur | 2 |
| correction_ecart_0_5s_st | 70.20557403564453 |
| repos_vitesse_4s_kmh | 0.00022326362086459996 |
| virage_droite_deg | 77.61861010796365 |
| acceleration_max_ms2 | 5.061710762919345 |
| virage_gauche_deg | -65.64472790822618 |
| repos_vitesse_1_5s_kmh | 0.00022376006527338176 |
| hud_100_0_m | 45.72950988585969 |
| correction_ecart_final_st | 1.9801967144012452 |
| hud_0_100_s | 8.465242106467486 |
| zero_a_cent_s | 8.566727499999843 |
| ping_fin_ms | 4 |
| freinage_distance_m | 47.5759375 |
| freinage_depuis_kmh | 100.32914657592774 |
| freinage_duree_s | 3.3991353999999776 |
| ping_ms | 17 |

## Session « latence »

Durée 77,8 s, tentatives 1 ; latence demandée 100 ms (réglage appliqué : True)

### Serveur
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `serveur.zone_creee` | 116 instances |
| ✅ | `serveur.quatre_vehicules` | 4 véhicules |
| ✅ | `serveur.canaux_reseau` | 3 |
| ✅ | `serveur.vehicules_poses_et_immobiles` | VehiculeEssai_1: Y=1.78 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_2: Y=1.78 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_3: Y=1.78 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_4: Y=1.78 vitesse=0.00 st/s droit=1.000 |
| ✅ | `serveur.rapports_clients_recus` | 2 attendu(s) |
| ✅ | `serveur.propriete_reseau_conducteur` | 164 concordants, 4 discordants VehiculeEssai_1 propriétaire=serveur, VehiculeEssai_1 propriétaire=serveur, VehiculeEssai_4 propriétaire=serveur, VehiculeEssai_4 propriétaire=serveur |
| ✅ | `serveur.vehicules_libres_immobiles` | VehiculeEssai_3: 0.21 st \| VehiculeEssai_2: 0.06 st |
| ✅ | `serveur.aucune_erreur_execution` |  |
| ✅ | `serveur.info_erreurs_internes_roblox` | 0 erreur(s) hors de notre code :  |
| ✅ | `serveur.info_invites_recues` | 2 : -1→VehiculeEssai_1, -2→VehiculeEssai_4 |
| ✅ | `serveur.journal_validation` | 2 message(s) : [AutomotiveWorld][Validation] Mouvement impossible (Teleport) sur essai-3e6b00d2-bb8a-4951-878d-1d715daa752a, conducteur -1 : position corrigée, aucune sanction. \|\| [AutomotiveWorld][Validation] Mouvement impossible (Teleport) sur essai-c01441b7-9678-4449-bdb7-987709010a4f, conducteur -2 : position corrigée, aucune sanction. |

### Client -1 — VehiculeEssai_1
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `client.demarrage` | bannière affichée |
| ✅ | `client.embarquement_invite` | essai 1 : non assis, distance porte 1.6 st, invite active=true, ping 204 ms ; essai 2 : assis, distance porte 2.7 st, invite active=false, ping 205 ms |
| ✅ | `client.session_conduite` | caméra=Scriptable HUD=true |
| ✅ | `client.propriete_attribuee` | DriverUserId=-1 |
| ✅ | `client.info_attente_joueur_2` | signal reçu=true |
| ✅ | `client.repos_quatre_roues` | roues=4 ; vitesse 0.00 km/h à 1,5 s, 0.00 km/h à 4 s |
| ✅ | `client.acceleration_progressive` | 3.6 km/h à 0,25 s ; 14.6 km/h à 1 s |
| ✅ | `client.atteint_100_kmh` | 8.55 s (horloge client) |
| ✅ | `client.rapports_montent` | rapport max 3 |
| ✅ | `client.acceleration_bornee` | 4.95 m/s² max (moyenne glissante 50 ms) |
| ✅ | `client.sortie_refusee_en_roulant` | notification ExitTooFast=true |
| ✅ | `client.freinage_arret` | depuis 102 km/h : 48.7 m en 3.45 s |
| ✅ | `client.marche_arriere` | rapport=-1 vitesse=-8.07 m/s |
| ✅ | `client.virage_droite` | 77.8° en 2 s |
| ✅ | `client.virage_gauche` | -64.8° en 2 s |
| ✅ | `client.camera_proche_lointaine` | proche 14.5 st, Lointaine 24.0 st |
| ✅ | `client.frein_a_main_maintien` | déplacement 0.00 st |
| ✅ | `client.remise_sur_roues_inutile_refusee` |  |
| ✅ | `client.correction_mouvement_impossible` | notification=true, écart 17.1 st à 0,5 s, 0.2 st après retour au conducteur |
| ✅ | `client.sortie_a_l_arret` | caméra=Custom distance au véhicule 6.5 st |
| ✅ | `client.vehicule_libere` | DriverUserId=0 |
| ✅ | `client.aucune_erreur_execution` |  |
| ✅ | `client.info_erreurs_internes_roblox` | 0 erreur(s) hors de notre code :  |

| Mesure (moteur Roblox) | Valeur |
|---|---|
| joueur | 1 |
| correction_ecart_0_5s_st | 17.09086036682129 |
| repos_vitesse_4s_kmh | 0.00022417544096242636 |
| virage_droite_deg | 77.79304626458809 |
| acceleration_max_ms2 | 4.947399401697713 |
| virage_gauche_deg | -64.75192200361319 |
| repos_vitesse_1_5s_kmh | 0.00022319706331472844 |
| hud_100_0_m | 46.04791638776616 |
| correction_ecart_final_st | 0.15368475019931794 |
| hud_0_100_s | 8.452180014923215 |
| zero_a_cent_s | 8.549614799999972 |
| ping_fin_ms | 204 |
| freinage_distance_m | 48.728241577148448 |
| freinage_depuis_kmh | 101.80696563720703 |
| freinage_duree_s | 3.4485471000000418 |
| ping_ms | 206 |

### Client -2 — VehiculeEssai_4
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `client.demarrage` | bannière affichée |
| ✅ | `client.vehicule_occupe_refuse` | invite active=false |
| ✅ | `client.voit_autre_conducteur` | DriverUserId=-1 |
| ✅ | `client.embarquement_invite` | essai 1 : assis, distance porte 2.7 st, invite active=false, ping 206 ms |
| ✅ | `client.session_conduite` | caméra=Scriptable HUD=true |
| ✅ | `client.propriete_attribuee` | DriverUserId=-2 |
| ✅ | `client.repos_quatre_roues` | roues=4 ; vitesse 0.00 km/h à 1,5 s, 0.00 km/h à 4 s |
| ✅ | `client.acceleration_progressive` | 3.4 km/h à 0,25 s ; 14.4 km/h à 1 s |
| ✅ | `client.atteint_100_kmh` | 8.65 s (horloge client) |
| ✅ | `client.rapports_montent` | rapport max 3 |
| ✅ | `client.acceleration_bornee` | 8.86 m/s² max (moyenne glissante 50 ms) |
| ✅ | `client.sortie_refusee_en_roulant` | notification ExitTooFast=true |
| ✅ | `client.freinage_arret` | depuis 102 km/h : 48.8 m en 3.45 s |
| ✅ | `client.marche_arriere` | rapport=-1 vitesse=-8.07 m/s |
| ✅ | `client.virage_droite` | 77.3° en 2 s |
| ✅ | `client.virage_gauche` | -65.5° en 2 s |
| ✅ | `client.camera_proche_lointaine` | proche 14.5 st, Lointaine 24.0 st |
| ✅ | `client.frein_a_main_maintien` | déplacement 0.00 st |
| ✅ | `client.remise_sur_roues_inutile_refusee` |  |
| ✅ | `client.correction_mouvement_impossible` | notification=true, écart 54.7 st à 0,5 s, 1.3 st après retour au conducteur |
| ✅ | `client.sortie_a_l_arret` | caméra=Custom distance au véhicule 6.3 st |
| ✅ | `client.vehicule_libere` | DriverUserId=0 |
| ✅ | `client.aucune_erreur_execution` |  |
| ✅ | `client.info_erreurs_internes_roblox` | 1 erreur(s) hors de notre code : Players.Player2.PlayerScripts.ChatScript:116: Error calling SetCore CoreGuiChatConnections: SetCore: CoreGuiChatConnections has not been registered by the CoreScripts |

| Mesure (moteur Roblox) | Valeur |
|---|---|
| joueur | 2 |
| correction_ecart_0_5s_st | 54.69131088256836 |
| repos_vitesse_4s_kmh | 0.00024257874756585806 |
| virage_droite_deg | 77.25836725511062 |
| acceleration_max_ms2 | 8.864046068378125 |
| virage_gauche_deg | -65.4957711572704 |
| repos_vitesse_1_5s_kmh | 0.00023216957633849234 |
| hud_100_0_m | 45.112335158912959 |
| correction_ecart_final_st | 1.2825573682785035 |
| hud_0_100_s | 8.599924717098475 |
| zero_a_cent_s | 8.650412799999913 |
| ping_fin_ms | 203 |
| freinage_distance_m | 48.82442749023438 |
| freinage_depuis_kmh | 101.88689804077149 |
| freinage_duree_s | 3.448020799999995 |
| ping_ms | 216 |

**Synthèse : 149 contrôle(s) réussi(s), 0 échec(s), 3 session(s).**

Non couvert automatiquement : lecture réelle du clavier et de la manette (commandes injectées par le point d'accès de test), ressenti de conduite, lisibilité, son. Voir les captures pour le rendu.
