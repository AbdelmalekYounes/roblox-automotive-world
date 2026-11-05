# Rapport de tests Roblox Studio (VM) 20261102-143507

_Généré automatiquement à partir de la sortie réelle de Studio. Chaque ligne correspond à une observation faite dans le moteur Roblox pendant la session indiquée._

| Exécution | Valeur |
|---|---|
| Studio | C:\Users\mimictest\AppData\Local\Roblox\Versions\version-7062aec9dbe74b14\RobloxStudioBeta.exe |
| Machine invitée / écran | DEV /  |
| Durée | 385.1 s |
| Délai dépassé | False |
| Captures d'écran | 129 (dossier screenshots) — état : ok |

Version Roblox : `0.745.0.7451137`

## Session « solo »

Durée 46,9 s, tentatives 1

### Serveur
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `serveur.zone_creee` | 116 instances |
| ✅ | `serveur.quatre_vehicules` | 4 véhicules |
| ✅ | `serveur.canaux_reseau` | 3 |
| ✅ | `serveur.vehicules_poses_et_immobiles` | VehiculeEssai_1: Y=1.78 vitesse=0.02 st/s droit=1.000 \| VehiculeEssai_2: Y=1.79 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_3: Y=1.79 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_4: Y=1.79 vitesse=0.00 st/s droit=1.000 |
| ✅ | `serveur.rapports_clients_recus` | 1 attendu(s) |
| ✅ | `serveur.propriete_reseau_conducteur` | 75 concordants, 2 discordants VehiculeEssai_1 propriétaire=serveur, VehiculeEssai_1 propriétaire=serveur |
| ✅ | `serveur.vehicules_libres_immobiles` | VehiculeEssai_2: 0.00 st \| VehiculeEssai_4: 0.00 st \| VehiculeEssai_3: 0.00 st |
| ✅ | `serveur.aucune_erreur_execution` |  |
| ✅ | `serveur.info_erreurs_internes_roblox` | 0 erreur(s) hors de notre code :  |
| ✅ | `serveur.info_invites_recues` | 1 : 941826283→VehiculeEssai_1 |
| ✅ | `serveur.journal_validation` | 1 message(s) : [AutomotiveWorld][Validation] Mouvement impossible (Teleport) sur essai-ad0ddf72-f6f2-42ab-8c93-7a347bfdc716, conducteur 941826283 : position corrigée, aucune sanction. |

### Client 941826283 — VehiculeEssai_1
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `client.demarrage` | bannière affichée |
| ✅ | `client.embarquement_invite` | essai 1 : assis, distance porte 2.5 st, invite active=false, ping 1 ms |
| ✅ | `client.session_conduite` | caméra=Scriptable HUD=true |
| ✅ | `client.propriete_attribuee` | DriverUserId=941826283 |
| ✅ | `client.tete_sous_le_toit` | marge tête 0.68 st, marge avec accessoires 0.34 st |
| ✅ | `client.repos_quatre_roues` | roues=4 ; vitesse 0.00 km/h à 1,5 s, 0.00 km/h à 4 s |
| ✅ | `client.acceleration_progressive` | 3.5 km/h à 0,25 s ; 14.3 km/h à 1 s |
| ✅ | `client.atteint_100_kmh` | 8.57 s (horloge client) |
| ✅ | `client.rapports_montent` | rapport max 3 |
| ✅ | `client.acceleration_bornee` | 8.22 m/s² max (moyenne glissante 50 ms) |
| ✅ | `client.sortie_refusee_en_roulant` | notification ExitTooFast=true |
| ✅ | `client.freinage_arret` | depuis 100 km/h : 47.4 m en 3.40 s |
| ✅ | `client.marche_arriere` | rapport=-1 vitesse=-8.05 m/s |
| ✅ | `client.virage_droite` | 77.4° en 2 s |
| ✅ | `client.virage_gauche` | -65.4° en 2 s |
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
| correction_ecart_0_5s_st | 0.0014070832403376699 |
| virage_droite_deg | 77.4310284260401 |
| correction_ecart_final_st | 0.003690777812153101 |
| freinage_depuis_kmh | 100.30598602294923 |
| freinage_duree_s | 3.398588199999722 |
| hud_0_100_s | 8.465069614350796 |
| acceleration_max_ms2 | 8.221495555630284 |
| virage_gauche_deg | -65.37276680542118 |
| repos_vitesse_4s_kmh | 0.00022551850997842848 |
| freinage_distance_m | 47.43861206054688 |
| marge_tete_toit_st | 0.6762505993247032 |
| ping_fin_ms | 3 |
| repos_vitesse_1_5s_kmh | 0.00022316675749607385 |
| marge_personnage_toit_st | 0.3383302316069603 |
| zero_a_cent_s | 8.565227899999627 |
| joueur | 1 |
| hud_100_0_m | 46.051368701856258 |
| ping_ms | 1 |

## Session « multijoueur »

Durée 77,8 s, tentatives 1

### Serveur
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `serveur.zone_creee` | 116 instances |
| ✅ | `serveur.quatre_vehicules` | 4 véhicules |
| ✅ | `serveur.canaux_reseau` | 3 |
| ✅ | `serveur.vehicules_poses_et_immobiles` | VehiculeEssai_1: Y=1.77 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_2: Y=1.77 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_3: Y=1.77 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_4: Y=1.77 vitesse=0.00 st/s droit=1.000 |
| ✅ | `serveur.rapports_clients_recus` | 2 attendu(s) |
| ✅ | `serveur.propriete_reseau_conducteur` | 157 concordants, 4 discordants VehiculeEssai_1 propriétaire=serveur, VehiculeEssai_1 propriétaire=serveur, VehiculeEssai_4 propriétaire=serveur, VehiculeEssai_4 propriétaire=serveur |
| ✅ | `serveur.vehicules_libres_immobiles` | VehiculeEssai_3: 0.04 st \| VehiculeEssai_2: 0.06 st |
| ✅ | `serveur.aucune_erreur_execution` |  |
| ✅ | `serveur.info_erreurs_internes_roblox` | 0 erreur(s) hors de notre code :  |
| ✅ | `serveur.info_invites_recues` | 2 : -1→VehiculeEssai_1, -2→VehiculeEssai_4 |
| ✅ | `serveur.journal_validation` | 2 message(s) : [AutomotiveWorld][Validation] Mouvement impossible (Teleport) sur essai-fb1ee599-ee93-4f61-a73d-cf33df09d795, conducteur -1 : position corrigée, aucune sanction. \|\| [AutomotiveWorld][Validation] Mouvement impossible (Teleport) sur essai-7150333f-a636-4750-8d37-1b5d192ef34a, conducteur -2 : position corrigée, aucune sanction. |

### Client -1 — VehiculeEssai_1
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `client.demarrage` | bannière affichée |
| ✅ | `client.embarquement_invite` | essai 1 : non assis, distance porte 1.6 st, invite active=true, ping 3 ms ; essai 2 : assis, distance porte 2.5 st, invite active=false, ping 4 ms |
| ✅ | `client.session_conduite` | caméra=Scriptable HUD=true |
| ✅ | `client.propriete_attribuee` | DriverUserId=-1 |
| ✅ | `client.tete_sous_le_toit` | marge tête 0.68 st, marge avec accessoires 0.34 st |
| ✅ | `client.info_attente_joueur_2` | signal reçu=true |
| ✅ | `client.repos_quatre_roues` | roues=4 ; vitesse 0.00 km/h à 1,5 s, 0.00 km/h à 4 s |
| ✅ | `client.acceleration_progressive` | 3.6 km/h à 0,25 s ; 14.6 km/h à 1 s |
| ✅ | `client.atteint_100_kmh` | 8.57 s (horloge client) |
| ✅ | `client.rapports_montent` | rapport max 3 |
| ✅ | `client.acceleration_bornee` | 5.20 m/s² max (moyenne glissante 50 ms) |
| ✅ | `client.sortie_refusee_en_roulant` | notification ExitTooFast=true |
| ✅ | `client.freinage_arret` | depuis 100 km/h : 47.5 m en 3.40 s |
| ✅ | `client.marche_arriere` | rapport=-1 vitesse=-8.00 m/s |
| ✅ | `client.virage_droite` | 77.1° en 2 s |
| ✅ | `client.virage_gauche` | -65.5° en 2 s |
| ✅ | `client.camera_proche_lointaine` | proche 14.5 st, Lointaine 24.0 st |
| ✅ | `client.frein_a_main_maintien` | déplacement 0.00 st |
| ✅ | `client.remise_sur_roues_inutile_refusee` |  |
| ✅ | `client.correction_mouvement_impossible` | notification=true, écart 11.9 st à 0,5 s, 0.4 st après retour au conducteur |
| ✅ | `client.sortie_a_l_arret` | caméra=Custom distance au véhicule 6.7 st |
| ✅ | `client.vehicule_libere` | DriverUserId=0 |
| ✅ | `client.aucune_erreur_execution` |  |
| ✅ | `client.info_erreurs_internes_roblox` | 0 erreur(s) hors de notre code :  |

| Mesure (moteur Roblox) | Valeur |
|---|---|
| correction_ecart_0_5s_st | 11.902176856994629 |
| virage_droite_deg | 77.11177904883334 |
| correction_ecart_final_st | 0.36771291494369509 |
| freinage_depuis_kmh | 100.34746627807617 |
| freinage_duree_s | 3.398201500000141 |
| hud_0_100_s | 8.466056210920215 |
| acceleration_max_ms2 | 5.19808633472394 |
| virage_gauche_deg | -65.52289123091743 |
| zero_a_cent_s | 8.566795600000205 |
| repos_vitesse_4s_kmh | 0.0002234361571026966 |
| marge_tete_toit_st | 0.6762517914175987 |
| ping_fin_ms | 6 |
| freinage_distance_m | 47.48002075195313 |
| marge_personnage_toit_st | 0.3383314236998558 |
| repos_vitesse_1_5s_kmh | 0.0002209348400356248 |
| joueur | 1 |
| hud_100_0_m | 46.092193714192067 |
| ping_ms | 12 |

### Client -2 — VehiculeEssai_4
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `client.demarrage` | bannière affichée |
| ✅ | `client.vehicule_occupe_refuse` | invite active=false |
| ✅ | `client.voit_autre_conducteur` | DriverUserId=-1 |
| ✅ | `client.embarquement_invite` | essai 1 : assis, distance porte 2.5 st, invite active=false, ping 6 ms |
| ✅ | `client.session_conduite` | caméra=Scriptable HUD=true |
| ✅ | `client.propriete_attribuee` | DriverUserId=-2 |
| ✅ | `client.tete_sous_le_toit` | marge tête 0.68 st, marge avec accessoires 0.34 st |
| ✅ | `client.repos_quatre_roues` | roues=4 ; vitesse 0.00 km/h à 1,5 s, 0.00 km/h à 4 s |
| ✅ | `client.acceleration_progressive` | 3.5 km/h à 0,25 s ; 14.5 km/h à 1 s |
| ✅ | `client.atteint_100_kmh` | 8.57 s (horloge client) |
| ✅ | `client.rapports_montent` | rapport max 3 |
| ✅ | `client.acceleration_bornee` | 4.92 m/s² max (moyenne glissante 50 ms) |
| ✅ | `client.sortie_refusee_en_roulant` | notification ExitTooFast=true |
| ✅ | `client.freinage_arret` | depuis 100 km/h : 47.5 m en 3.40 s |
| ✅ | `client.marche_arriere` | rapport=-1 vitesse=-8.08 m/s |
| ✅ | `client.virage_droite` | 78.0° en 2 s |
| ✅ | `client.virage_gauche` | -64.9° en 2 s |
| ✅ | `client.camera_proche_lointaine` | proche 14.5 st, Lointaine 24.0 st |
| ✅ | `client.frein_a_main_maintien` | déplacement 0.00 st |
| ✅ | `client.remise_sur_roues_inutile_refusee` |  |
| ✅ | `client.correction_mouvement_impossible` | notification=true, écart 9.8 st à 0,5 s, 0.3 st après retour au conducteur |
| ✅ | `client.sortie_a_l_arret` | caméra=Custom distance au véhicule 6.7 st |
| ✅ | `client.vehicule_libere` | DriverUserId=0 |
| ✅ | `client.aucune_erreur_execution` |  |
| ✅ | `client.info_erreurs_internes_roblox` | 1 erreur(s) hors de notre code : Players.Player2.PlayerScripts.ChatScript:116: Error calling SetCore CoreGuiChatConnections: SetCore: CoreGuiChatConnections has not been registered by the CoreScripts |

| Mesure (moteur Roblox) | Valeur |
|---|---|
| correction_ecart_0_5s_st | 9.79073715209961 |
| virage_droite_deg | 77.96501819038106 |
| correction_ecart_final_st | 0.34383881092071535 |
| freinage_depuis_kmh | 100.34116973876954 |
| freinage_duree_s | 3.397405599999729 |
| acceleration_max_ms2 | 4.919004270298349 |
| virage_gauche_deg | -64.87629357213409 |
| zero_a_cent_s | 8.5663555000001 |
| repos_vitesse_4s_kmh | 0.00022067872050683947 |
| marge_tete_toit_st | 0.6762513145804405 |
| ping_fin_ms | 7 |
| freinage_distance_m | 47.504258422851567 |
| marge_personnage_toit_st | 0.3383314236998558 |
| repos_vitesse_1_5s_kmh | 0.00022341208532452583 |
| joueur | 2 |
| hud_100_0_m | 45.31537186625163 |
| ping_ms | -1000 |

## Session « latence »

Durée 82,8 s, tentatives 1 ; latence demandée 100 ms (réglage appliqué : True)

### Serveur
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `serveur.zone_creee` | 116 instances |
| ✅ | `serveur.quatre_vehicules` | 4 véhicules |
| ✅ | `serveur.canaux_reseau` | 3 |
| ✅ | `serveur.vehicules_poses_et_immobiles` | VehiculeEssai_1: Y=1.78 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_2: Y=1.78 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_3: Y=1.78 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_4: Y=1.78 vitesse=0.00 st/s droit=1.000 |
| ✅ | `serveur.rapports_clients_recus` | 2 attendu(s) |
| ✅ | `serveur.propriete_reseau_conducteur` | 160 concordants, 4 discordants VehiculeEssai_1 propriétaire=serveur, VehiculeEssai_1 propriétaire=serveur, VehiculeEssai_4 propriétaire=serveur, VehiculeEssai_4 propriétaire=serveur |
| ✅ | `serveur.vehicules_libres_immobiles` | VehiculeEssai_3: 0.10 st \| VehiculeEssai_2: 0.12 st |
| ✅ | `serveur.aucune_erreur_execution` |  |
| ✅ | `serveur.info_erreurs_internes_roblox` | 0 erreur(s) hors de notre code :  |
| ✅ | `serveur.info_invites_recues` | 2 : -1→VehiculeEssai_1, -2→VehiculeEssai_4 |
| ✅ | `serveur.journal_validation` | 2 message(s) : [AutomotiveWorld][Validation] Mouvement impossible (Teleport) sur essai-81c00312-2007-4f5a-a2fe-798c5e481b91, conducteur -1 : position corrigée, aucune sanction. \|\| [AutomotiveWorld][Validation] Mouvement impossible (Teleport) sur essai-4775341c-ab33-4c5f-9636-b84938f07965, conducteur -2 : position corrigée, aucune sanction. |

### Client -1 — VehiculeEssai_1
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `client.demarrage` | bannière affichée |
| ✅ | `client.embarquement_invite` | essai 1 : non assis, distance porte 1.6 st, invite active=true, ping 214 ms ; essai 2 : assis, distance porte 2.5 st, invite active=false, ping 208 ms |
| ✅ | `client.session_conduite` | caméra=Scriptable HUD=true |
| ✅ | `client.propriete_attribuee` | DriverUserId=-1 |
| ✅ | `client.tete_sous_le_toit` | marge tête 0.68 st, marge avec accessoires 0.34 st |
| ✅ | `client.info_attente_joueur_2` | signal reçu=true |
| ✅ | `client.repos_quatre_roues` | roues=4 ; vitesse 0.00 km/h à 1,5 s, 0.00 km/h à 4 s |
| ✅ | `client.acceleration_progressive` | 3.5 km/h à 0,25 s ; 14.5 km/h à 1 s |
| ✅ | `client.atteint_100_kmh` | 8.56 s (horloge client) |
| ✅ | `client.rapports_montent` | rapport max 3 |
| ✅ | `client.acceleration_bornee` | 4.90 m/s² max (moyenne glissante 50 ms) |
| ✅ | `client.sortie_refusee_en_roulant` | notification ExitTooFast=true |
| ✅ | `client.freinage_arret` | depuis 102 km/h : 48.7 m en 3.45 s |
| ✅ | `client.marche_arriere` | rapport=-1 vitesse=-8.17 m/s |
| ✅ | `client.virage_droite` | 77.3° en 2 s |
| ✅ | `client.virage_gauche` | -65.5° en 2 s |
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
| correction_ecart_0_5s_st | 0.00277393008582294 |
| virage_droite_deg | 77.331442104147 |
| correction_ecart_final_st | 0.0049088140949606899 |
| freinage_depuis_kmh | 101.75219879150392 |
| freinage_duree_s | 3.4499587000000249 |
| hud_0_100_s | 8.465975501574576 |
| acceleration_max_ms2 | 4.903104352069306 |
| virage_gauche_deg | -65.5363381098099 |
| zero_a_cent_s | 8.56466330000012 |
| repos_vitesse_4s_kmh | 0.0002234004030469805 |
| marge_tete_toit_st | 0.6762508377432823 |
| ping_fin_ms | 204 |
| freinage_distance_m | 48.65359313964844 |
| marge_personnage_toit_st | 0.3383309468626976 |
| repos_vitesse_1_5s_kmh | 0.0002255867439089343 |
| joueur | 1 |
| hud_100_0_m | 45.9749502420911 |
| ping_ms | 216 |

### Client -2 — VehiculeEssai_4
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `client.demarrage` | bannière affichée |
| ✅ | `client.vehicule_occupe_refuse` | invite active=false |
| ✅ | `client.voit_autre_conducteur` | DriverUserId=-1 |
| ✅ | `client.embarquement_invite` | essai 1 : assis, distance porte 2.5 st, invite active=false, ping 205 ms |
| ✅ | `client.session_conduite` | caméra=Scriptable HUD=true |
| ✅ | `client.propriete_attribuee` | DriverUserId=-2 |
| ✅ | `client.tete_sous_le_toit` | marge tête 0.69 st, marge avec accessoires 0.35 st |
| ✅ | `client.repos_quatre_roues` | roues=4 ; vitesse 0.00 km/h à 1,5 s, 0.00 km/h à 4 s |
| ✅ | `client.acceleration_progressive` | 3.5 km/h à 0,25 s ; 14.4 km/h à 1 s |
| ✅ | `client.atteint_100_kmh` | 8.55 s (horloge client) |
| ✅ | `client.rapports_montent` | rapport max 3 |
| ✅ | `client.acceleration_bornee` | 4.87 m/s² max (moyenne glissante 50 ms) |
| ✅ | `client.sortie_refusee_en_roulant` | notification ExitTooFast=true |
| ✅ | `client.freinage_arret` | depuis 102 km/h : 48.6 m en 3.43 s |
| ✅ | `client.marche_arriere` | rapport=-1 vitesse=-8.07 m/s |
| ✅ | `client.virage_droite` | 77.0° en 2 s |
| ✅ | `client.virage_gauche` | -65.4° en 2 s |
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
| correction_ecart_0_5s_st | 0.0034111265558749439 |
| virage_droite_deg | 76.99259215934926 |
| correction_ecart_final_st | 0.0003678502980619669 |
| freinage_depuis_kmh | 101.80360107421875 |
| freinage_duree_s | 3.4333458999999495 |
| hud_0_100_s | 8.40102158114314 |
| acceleration_max_ms2 | 4.867515519651975 |
| virage_gauche_deg | -65.37907495547604 |
| zero_a_cent_s | 8.550910599999952 |
| repos_vitesse_4s_kmh | 0.0002130995155312121 |
| marge_tete_toit_st | 0.6852182373404503 |
| ping_fin_ms | 203 |
| freinage_distance_m | 48.60053771972657 |
| marge_personnage_toit_st | 0.34866591542959216 |
| repos_vitesse_1_5s_kmh | 0.0002238515327917412 |
| joueur | 2 |
| hud_100_0_m | 45.694281633473419 |
| ping_ms | 226 |

## Session « scenarios »

Durée 98,9 s, tentatives 1

### Serveur
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `serveur.zone_creee` | 116 instances |
| ✅ | `serveur.quatre_vehicules` | 4 véhicules |
| ✅ | `serveur.canaux_reseau` | 3 |
| ✅ | `serveur.vehicules_poses_et_immobiles` | VehiculeEssai_1: Y=1.78 vitesse=0.17 st/s droit=1.000 \| VehiculeEssai_2: Y=1.78 vitesse=0.17 st/s droit=1.000 \| VehiculeEssai_3: Y=1.78 vitesse=0.17 st/s droit=1.000 \| VehiculeEssai_4: Y=1.78 vitesse=0.17 st/s droit=1.000 |
| ✅ | `serveur.rapports_clients_recus` | 1 attendu(s) |
| ✅ | `serveur.propriete_reseau_conducteur` | 108 concordants, 2 discordants VehiculeEssai_1 propriétaire=serveur, VehiculeEssai_1 propriétaire=serveur |
| ✅ | `serveur.vehicules_libres_immobiles` | non applicable : véhicules déplacés par les scénarios |
| ✅ | `serveur.scenarios_termines` |  |
| ✅ | `scenario.bosse_terminee_par_le_client` |  |
| ✅ | `scenario.slalom_termine_par_le_client` |  |
| ✅ | `scenario.slalom_cones_touches` | 0 cône(s) déplacé(s) sur 8 |
| ✅ | `scenario.vehicule_renverse_prepare` | UpVector.Y = -1.00 |
| ✅ | `scenario.renverse_termine_par_le_client` |  |
| ✅ | `scenario.collision_parque_terminee_par_le_client` |  |
| ✅ | `scenario.collision_vehicule_gare_deplace` | déplacement max du véhicule garé 4.30 st (mesure serveur) |
| ✅ | `scenario.retour_automatique_au_plot` | revenu après 91 s (délai du jeu : 90 s) |
| ✅ | `scenario.aucune_correction_intempestive` | 0 correction(s) :  |
| ✅ | `serveur.aucune_erreur_execution` |  |
| ✅ | `serveur.info_erreurs_internes_roblox` | 0 erreur(s) hors de notre code :  |
| ✅ | `serveur.info_invites_recues` | 4 : 941826283→VehiculeEssai_1, 941826283→VehiculeEssai_1, 941826283→VehiculeEssai_1, 941826283→VehiculeEssai_1 |
| ✅ | `serveur.journal_validation` | 0 message(s) :  |

### Client 941826283 — VehiculeEssai_1
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `client.bosse_embarquement` | invite, essai 1 |
| ✅ | `client.bosse_franchie` | assiette max 6.6° (pente théorique 5,7°) |
| ✅ | `client.bosse_reste_droit` | UpVector.Y min 0.993 |
| ✅ | `client.bosse_pas_de_decollage` | quatre roues en l'air au plus 0.00 s |
| ✅ | `client.slalom_embarquement` | invite, essai 1 |
| ✅ | `client.slalom_parcouru` | 8 porte(s) franchie(s), écart latéral max 0.2 st |
| ✅ | `client.renverse_embarquement` | invite, essai 1 |
| ✅ | `client.remise_sur_roues` | UpVector.Y 1.000, roues au sol 4 |
| ✅ | `client.remise_sur_roues_delai` | second appui immédiat |
| ✅ | `client.roule_apres_remise` | 12.0 km/h après 2 s |
| ✅ | `client.collision_parque_embarquement` | invite, essai 1 |
| ✅ | `client.collision_parque_contact` | vitesse avant impact 19.5 km/h, 19.5 km/h juste après |
| ✅ | `client.collision_parque_reste_droit` | UpVector.Y 1.000 |
| ✅ | `client.collision_parque_toujours_conducteur` |  |
| ✅ | `client.aucune_erreur_execution` |  |

| Mesure (moteur Roblox) | Valeur |
|---|---|
| bosse_vitesse_min_montee_kmh | 27.551194381713868 |
| slalom_ecart_max_porte_st | 0.2142791748046875 |
| collision_parque_vitesse_impact_kmh | 19.53384075164795 |
| collision_parque_vitesse_apres_contact_kmh | 19.53384075164795 |
| bosse_temps_sans_contact_max_s | 0 |
| bosse_assiette_max_deg | 6.5615616264518039 |

## Session « collision »

Durée 49,8 s, tentatives 1

### Serveur
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `serveur.zone_creee` | 116 instances |
| ✅ | `serveur.quatre_vehicules` | 4 véhicules |
| ✅ | `serveur.canaux_reseau` | 3 |
| ✅ | `serveur.vehicules_poses_et_immobiles` | VehiculeEssai_1: Y=1.79 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_2: Y=1.79 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_3: Y=1.79 vitesse=0.00 st/s droit=1.000 \| VehiculeEssai_4: Y=1.79 vitesse=0.00 st/s droit=1.000 |
| ✅ | `serveur.rapports_clients_recus` | 2 attendu(s) |
| ✅ | `serveur.propriete_reseau_conducteur` | 64 concordants, 0 discordants  |
| ✅ | `serveur.vehicules_libres_immobiles` | non applicable : véhicules déplacés par les scénarios |
| ✅ | `serveur.scenarios_termines` |  |
| ✅ | `scenario.collision_terminee_par_le_client` |  |
| ✅ | `scenario.aucune_correction_intempestive` | 0 correction(s) :  |
| ✅ | `serveur.aucune_erreur_execution` |  |
| ✅ | `serveur.info_erreurs_internes_roblox` | 0 erreur(s) hors de notre code :  |
| ✅ | `serveur.info_invites_recues` | 2 : -1→VehiculeEssai_1, -2→VehiculeEssai_4 |
| ✅ | `serveur.journal_validation` | 0 message(s) :  |

### Client -1 — VehiculeEssai_1
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `client.collision_embarquement` | invite, essai 1 |
| ✅ | `client.collision_contact` | vitesse avant impact 19.5 km/h, 10.7 km/h juste après |
| ✅ | `client.collision_reste_droit` | UpVector.Y 1.000 |
| ✅ | `client.collision_toujours_conducteur` |  |
| ✅ | `client.aucune_erreur_execution` |  |

| Mesure (moteur Roblox) | Valeur |
|---|---|
| collision_vitesse_apres_contact_kmh | 10.69070749282837 |
| collision_vitesse_impact_kmh | 19.523686981201175 |

### Client -2 — VehiculeEssai_4
| Résultat | Contrôle | Détail |
|---|---|---|
| ✅ | `client.collision_embarquement` | invite, essai 2 |
| ✅ | `client.collision_vehicule_percute_bouge` | déplacement max 2.23 st |
| ✅ | `client.collision_percute_reste_droit` | UpVector.Y 1.000 |
| ✅ | `client.collision_percute_toujours_conducteur` |  |
| ✅ | `client.aucune_erreur_execution` |  |

| Mesure (moteur Roblox) | Valeur |
|---|---|
| collision_deplacement_vehicule_percute_st | 2.2347261905670168 |

**Synthèse : 214 contrôle(s) réussi(s), 0 échec(s), 0 limite(s) connue(s) ⚠️, 5 session(s).**

Non couvert automatiquement : lecture réelle du clavier et de la manette (commandes injectées par le point d'accès de test), ressenti de conduite, lisibilité, son. Voir les captures pour le rendu.
