--!strict
--[[
    Textes joueur du lot 0.8 (parcours d'arrivée, formation, fiches de la gamme
    proposée, audio, radio, mode photo, qualité graphique), au même format que
    Localization : { français, anglais }. Fusionnés au chargement de
    Localization (une clé déjà définie y est refusée : aucun écrasement).
    Les fiches des 18 modèles décrivent des véhicules FICTIFS (gamme proposée,
    en attente d'approbation) : aucune marque ni référence commerciale réelle.
]]

local T: { [string]: { string } } = {
    -- ===================== Parcours d'arrivée =====================
    ["onb.title.Welcome"] = { "Bienvenue à Automotive World", "Welcome to Automotive World" },
    ["onb.title.World"] = { "Un monde ouvert à parcourir", "An open world to explore" },
    ["onb.title.Controls"] = { "Les commandes", "Controls" },
    ["onb.title.Phone"] = { "Téléphone, carte et GPS", "Phone, map and GPS" },
    ["onb.title.Starters"] = { "Votre premier véhicule", "Your first vehicle" },
    ["onb.title.Choose"] = { "Choisir votre véhicule", "Choose your vehicle" },
    ["onb.title.Property"] = { "Votre propriété", "Your property" },
    ["onb.title.Done"] = { "C'est parti", "Let's go" },
    ["onb.text.Welcome"] = {
        "Conduisez, travaillez, courez et collectionnez des voitures dans un monde partagé. Cette présentation est courte et vous pouvez la passer à tout moment ; elle reste consultable dans le téléphone (application Guide).",
        "Drive, work, race and collect cars in a shared world. This introduction is short and you can skip it at any time; it remains available in the phone (Guide app).",
    },
    ["onb.text.World"] = {
        "Sept zones reliées par des routes : centre-ville, banlieue, zone industrielle, port, campagne, montagne et circuit. Garages publics, concessions, stations et lieux de rencontre sont indiqués sur la carte.",
        "Seven zones linked by roads: downtown, suburbs, industrial area, harbour, countryside, mountains and the circuit. Public garages, dealerships, stations and meeting spots are shown on the map.",
    },
    ["onb.text.Controls"] = {
        "À pied : approchez une voiture et utilisez l'invite pour monter. Au volant : accélérer, freiner, diriger ; changement de rapport selon la boîte ; F (manette : Y) pour descendre. Toutes les touches sont modifiables dans les paramètres.",
        "On foot: walk up to a car and use the prompt to get in. Driving: throttle, brake, steer; shifting depends on the gearbox; F (gamepad: Y) to get out. Every key can be changed in the settings.",
    },
    ["onb.text.Phone"] = {
        "T (manette : Select) ouvre le téléphone : carte, GPS, véhicules, propriétés, métiers, courses, groupe et paramètres. M ouvre la grande carte ; choisissez une destination pour être guidé.",
        "T (gamepad: Select) opens the phone: map, GPS, vehicles, properties, jobs, races, group and settings. M opens the large map; pick a destination to get guidance.",
    },
    ["onb.text.Property"] = {
        "Une propriété de départ vous est attribuée gratuitement, une seule fois. Elle abrite votre collection ; le GPS peut vous y conduire.",
        "A starter property is granted to you for free, once. It houses your collection; the GPS can take you there.",
    },
    ["onb.propertyPending"] = {
        "Votre propriété de départ sera attribuée dès que votre profil sera disponible.",
        "Your starter property will be granted as soon as your profile is available.",
    },
    ["onb.text.Done"] = {
        "Vous êtes prêt. Des exercices facultatifs (sans récompense) sont proposés pour prendre en main la conduite ; le premier métier garanti reste disponible dans le téléphone.",
        "You are ready. Optional exercises (no reward) help you get used to driving; the first guaranteed job is still available in the phone.",
    },
    ["onb.next"] = { "Suivant", "Next" },
    ["onb.skip"] = { "Passer l'introduction", "Skip the introduction" },
    ["onb.devCandidates"] = {
        "Développement : trois candidats PROPOSÉS, en attente d'approbation. L'exemplaire attribué ici est synthétique et n'existe qu'en développement.",
        "Development: three PROPOSED candidates, pending approval. The copy granted here is synthetic and only exists in development.",
    },
    ["onb.candidate"] = {
        "{name} — {category} · {energy}, {gearbox}, {layout} · {power} kW · {mass} kg · valeur {price}",
        "{name} — {category} · {energy}, {gearbox}, {layout} · {power} kW · {mass} kg · value {price}",
    },
    ["onb.testDrive"] = {
        "Essayer la {name} (3 min, sans conséquence)",
        "Test drive the {name} (3 min, no consequence)",
    },
    ["onb.endTestDrive"] = { "Terminer l'essai", "End the test drive" },
    ["onb.choose"] = { "Choisir la {name}", "Choose the {name}" },
    ["onb.confirmChoice"] = {
        "Choix définitif : la {name} devient votre véhicule de départ, une seule fois et sans échange. Confirmer ?",
        "Final choice: the {name} becomes your starter vehicle, once and with no exchange. Confirm?",
    },
    ["onb.training"] = { "Exercices de formation", "Training exercises" },
    ["onb.trainingText"] = {
        "Facultatifs et rejouables, ils ne rapportent rien. Choisissez un exercice puis suivez l'indication.",
        "Optional and repeatable, they give no reward. Pick an exercise and follow the hint.",
    },
    ["onb.enterWorld"] = { "Entrer dans le monde", "Enter the world" },
    ["onb.chooseLater"] = {
        "Vous pourrez choisir votre véhicule de départ depuis le garage dès que la liste officielle sera publiée.",
        "You will be able to choose your starter vehicle from the garage as soon as the official list is published.",
    },
    ["phone.app.Guide"] = { "Guide", "Guide" },
    OnboardingStepUnknown = { "Étape inconnue.", "Unknown step." },
    OnboardingStepOrder = { "Étape hors d'ordre.", "Step out of order." },
    OnboardingChooseStarter = {
        "Choisissez d'abord votre véhicule de départ.",
        "Choose your starter vehicle first.",
    },
    ExerciseUnknown = { "Exercice inconnu.", "Unknown exercise." },
    TestDriveNoRewards = {
        "Véhicule d'essai : aucune course ni mission avec lui.",
        "Test-drive vehicle: no races or jobs with it.",
    },
    PassengerIsDriver = { "Vous conduisez déjà ce véhicule.", "You are already driving this vehicle." },
    PassengerNotAllowed = {
        "Place passager réservée au propriétaire et à son groupe (ou au groupe du conducteur).",
        "Passenger seat reserved for the owner and their group (or the driver's group).",
    },

    -- ===================== Exercices =====================
    ["exercise.AccelerateBrake"] = { "Accélérer puis freiner", "Accelerate then brake" },
    ["exercise.Turn"] = { "Prendre un virage", "Take a turn" },
    ["exercise.Shift"] = { "Changer de rapport", "Change gear" },
    ["exercise.Park"] = { "Se garer", "Park" },
    ["exercise.UseGps"] = { "Utiliser le GPS", "Use the GPS" },
    ["exercise.ReachGarage"] = { "Rejoindre un garage public", "Reach a public garage" },
    ["exercise.AcceptMission"] = { "Accepter une mission", "Accept a job" },
    ["exercise.DiscoverRaces"] = { "Découvrir les courses", "Discover races" },
    ["exercise.AccelerateBrake.hint"] = {
        "Au volant, atteignez 50 km/h puis arrêtez-vous complètement.",
        "While driving, reach 50 km/h then come to a full stop.",
    },
    ["exercise.Turn.hint"] = {
        "Changez de direction d'au moins 90° en roulant.",
        "Change direction by at least 90° while moving.",
    },
    ["exercise.Shift.hint"] = {
        "Passez au moins le 2e rapport (boîte manuelle : touches de rapport).",
        "Reach at least 2nd gear (manual gearbox: shift keys).",
    },
    ["exercise.Park.hint"] = {
        "Une place est retenue 30 m devant vous : arrêtez-vous dans un rayon de 5 m pendant 2 s.",
        "A spot is set 30 m ahead of you: stop within 5 m of it for 2 s.",
    },
    ["exercise.UseGps.hint"] = {
        "Choisissez une destination sur la carte ou dans le téléphone.",
        "Pick a destination on the map or in the phone.",
    },
    ["exercise.ReachGarage.hint"] = {
        "Rendez-vous à moins de 40 m d'un garage public.",
        "Get within 40 m of a public garage.",
    },
    ["exercise.AcceptMission.hint"] = {
        "Ouvrez Missions dans le téléphone et acceptez-en une.",
        "Open Jobs in the phone and accept one.",
    },
    ["exercise.DiscoverRaces.hint"] = { "Ouvrez le panneau des courses (K).", "Open the races panel (K)." },
    ["exercise.done"] = { "Exercice réussi : {name}", "Exercise completed: {name}" },

    -- ===================== Radio (AUD-RADIO-01) =====================
    ["phone.app.Radio"] = { "Radio", "Radio" },
    ["radio.seat.Driver"] = {
        "Vous conduisez : vous choisissez la station.",
        "You are driving: you choose the station.",
    },
    ["radio.seat.Passenger"] = {
        "Passager : la station est choisie par le conducteur ; réglez ou coupez votre écoute.",
        "Passenger: the driver chooses the station; adjust or mute your own listening.",
    },
    ["radio.seat.None"] = {
        "Montez dans un véhicule pour écouter la radio.",
        "Get in a vehicle to listen to the radio.",
    },
    ["radio.current"] = { "Station : {station}", "Station: {station}" },
    ["radio.station.Off"] = { "Éteinte", "Off" },
    ["radio.station.ville"] = { "AW Ville — pop urbaine", "AW City — urban pop" },
    ["radio.station.route"] = { "AW Route — rock de route", "AW Road — road rock" },
    ["radio.station.nuit"] = { "AW Nuit — électro de nuit", "AW Night — night electro" },
    ["radio.unavailable"] = {
        "{station} : indisponible (pistes non téléversées)",
        "{station}: unavailable (tracks not uploaded)",
    },
    ["radio.mute"] = { "Couper ma radio : {state}", "Mute my radio: {state}" },
    ["radio.note"] = {
        "Musiques originales uniquement ; rien n'est diffusé à l'extérieur du véhicule.",
        "Original music only; nothing is played outside the vehicle.",
    },
    RadioDriverOnly = { "Seul le conducteur choisit la station.", "Only the driver chooses the station." },
    RadioStationUnknown = { "Station inconnue.", "Unknown station." },
    RadioStationUnavailable = { "Station indisponible pour le moment.", "Station unavailable for now." },

    -- ===================== Mode photo (AUD-PHOTO-01) =====================
    ["phone.app.Photo"] = { "Photo", "Photo" },
    ["action.Photo"] = { "Mode photo", "Photo mode" },
    ["photo.open"] = { "Ouvrir le mode photo", "Open photo mode" },
    ["photo.rules"] = {
        "À pied, ou à bord d'un véhicule à l'arrêt ; jamais pendant une course. Caméra limitée autour de vous, sans traverser les murs. Réglages visibles par vous seul.",
        "On foot, or in a stopped vehicle; never during a race. Camera limited around you, never through walls. Settings only visible to you.",
    },
    ["photo.help"] = {
        "W/A/S/D : déplacer · Q/E : descendre/monter · flèches : orienter · I : interface",
        "W/A/S/D: move · Q/E: down/up · arrows: aim · I: interface",
    },
    ["photo.status"] = {
        "Champ {fov}° · exposition {exposure} · profondeur {dof} ({focus} m) · filtre {filter}",
        "FOV {fov}° · exposure {exposure} · depth of field {dof} ({focus} m) · filter {filter}",
    },
    ["photo.zoomIn"] = { "Zoom +", "Zoom in" },
    ["photo.zoomOut"] = { "Zoom −", "Zoom out" },
    ["photo.exposureUp"] = { "Exposition +", "Exposure +" },
    ["photo.exposureDown"] = { "Exposition −", "Exposure −" },
    ["photo.dof"] = { "Profondeur de champ", "Depth of field" },
    ["photo.focus"] = { "Distance de netteté", "Focus distance" },
    ["photo.filter"] = { "Filtre suivant", "Next filter" },
    ["photo.hide"] = { "Masquer l'interface", "Hide interface" },
    ["photo.capture"] = { "Capturer", "Capture" },
    ["photo.exit"] = { "Quitter", "Exit" },
    ["photo.filter.None"] = { "aucun", "none" },
    ["photo.filter.Warm"] = { "chaud", "warm" },
    ["photo.filter.Cool"] = { "froid", "cool" },
    ["photo.filter.Mono"] = { "noir et blanc", "black and white" },
    ["photo.filter.Vintage"] = { "rétro", "vintage" },
    ["photo.filter.Vivid"] = { "éclatant", "vivid" },
    ["photo.captureUnavailable"] = {
        "Capture intégrée indisponible ici : utilisez la capture d'écran de Roblox.",
        "Built-in capture unavailable here: use Roblox's screenshot feature.",
    },
    PhotoRacing = { "Mode photo indisponible pendant une course.", "Photo mode unavailable during a race." },
    PhotoDriverMoving = { "Arrêtez-vous pour prendre une photo.", "Stop to take a photo." },
    PhotoPassengerMoving = {
        "Mode photo en passager : seulement à l'arrêt.",
        "Photo mode as a passenger: only when stopped.",
    },
    PhotoUnavailable = { "Mode photo indisponible ici.", "Photo mode unavailable here." },

    -- ===================== Paramètres : audio et graphismes =====================
    ["settings.volume.Engine"] = { "moteur", "engine" },
    ["settings.volume.Environment"] = { "environnement", "environment" },
    ["settings.volume.Effects"] = { "effets", "effects" },
    ["settings.volume.Radio"] = { "radio", "radio" },
    ["settings.volume.Voice"] = { "voix", "voice" },
    ["settings.graphics"] = { "Graphismes", "Graphics" },
    ["settings.quality"] = { "Qualité graphique : {value}", "Graphics quality: {value}" },
    ["settings.quality.note"] = {
        "Basse : habillage et détails masqués, aucune source de lumière ni effet. Haute : tout visible plus loin.",
        "Low: dressing and details hidden, no light sources or effects. High: everything visible further away.",
    },
    ["quality.Low"] = { "basse", "low" },
    ["quality.Medium"] = { "moyenne", "medium" },
    ["quality.High"] = { "haute", "high" },

    -- ===================== Caractéristiques =====================
    ["energy.Petrol"] = { "essence", "petrol" },
    ["energy.Diesel"] = { "diesel", "diesel" },
    ["energy.Electric"] = { "électrique", "electric" },
    ["layout.FWD"] = { "traction", "front-wheel drive" },
    ["layout.RWD"] = { "propulsion", "rear-wheel drive" },
    ["layout.AWD"] = { "transmission intégrale", "all-wheel drive" },

    -- ===================== Gamme proposée (18 modèles fictifs) =====================
    ["vehicle.wk_pixel.category"] = { "Citadine électrique", "Electric city car" },
    ["vehicle.wk_pixel.desc"] = {
        "Minuscule et silencieuse, moteur arrière : idéale pour se faufiler en ville.",
        "Tiny and quiet, rear motor: ideal for slipping through town.",
    },
    ["vehicle.wk_brio.category"] = { "Citadine", "City car" },
    ["vehicle.wk_brio.desc"] = {
        "Légère et vive, boîte manuelle : la plus simple pour apprendre à passer les rapports.",
        "Light and lively, manual gearbox: the easiest way to learn shifting.",
    },
    ["vehicle.wk_fil.category"] = { "Citadine électrique", "Electric city car" },
    ["vehicle.wk_fil.desc"] = {
        "Couple immédiat et rapport unique : conduite douce, recharge aux bornes.",
        "Instant torque and a single gear: smooth driving, charge at the hubs.",
    },
    ["vehicle.wk_aster.category"] = { "Compacte", "Compact" },
    ["vehicle.wk_aster.desc"] = {
        "Polyvalente, boîte automatique : confortable au quotidien comme sur route.",
        "Versatile, automatic gearbox: comfortable every day and on the road.",
    },
    ["vehicle.wk_nova.category"] = { "Compacte", "Compact" },
    ["vehicle.wk_nova.desc"] = {
        "Boîte à variation continue, consommation sage : la compacte tranquille.",
        "Continuously variable gearbox, frugal: the relaxed compact.",
    },
    ["vehicle.wk_cadence.category"] = { "Berline", "Saloon" },
    ["vehicle.wk_cadence.desc"] = {
        "Diesel automatique, grand empattement : stable et reposante sur longue distance.",
        "Automatic diesel, long wheelbase: stable and relaxing over long distances.",
    },
    ["vehicle.wk_lumen.category"] = { "Break", "Estate" },
    ["vehicle.wk_lumen.desc"] = {
        "Diesel manuel et grand coffre : la voiture des métiers de livraison.",
        "Manual diesel with a big boot: the delivery jobs car.",
    },
    ["vehicle.wk_oree.category"] = { "Berline électrique", "Electric saloon" },
    ["vehicle.wk_oree.desc"] = {
        "Deux moteurs, transmission intégrale : rapide, silencieuse et sûre.",
        "Two motors, all-wheel drive: fast, quiet and secure.",
    },
    ["vehicle.wk_brise.category"] = { "Roadster", "Roadster" },
    ["vehicle.wk_brise.desc"] = {
        "Découvrable, légère et propulsion : le plaisir de conduire avant la puissance.",
        "Open-top, light and rear-driven: driving fun before power.",
    },
    ["vehicle.wk_rafale.category"] = { "Sportive compacte", "Hot hatch" },
    ["vehicle.wk_rafale.desc"] = {
        "Traction vive à double embrayage et différentiel autobloquant.",
        "Lively front-driver with a dual-clutch gearbox and limited-slip differential.",
    },
    ["vehicle.wk_eclat.category"] = { "Coupé sportif", "Sports coupé" },
    ["vehicle.wk_eclat.desc"] = {
        "Coupé propulsion à boîte manuelle, équilibré, exigeant sur le mouillé.",
        "Rear-driven coupé with a manual gearbox, balanced, demanding in the wet.",
    },
    ["vehicle.wk_mistral.category"] = { "Coupé GT", "GT coupé" },
    ["vehicle.wk_mistral.desc"] = {
        "Grand tourisme puissant et stable à haute vitesse.",
        "Powerful grand tourer, stable at high speed.",
    },
    ["vehicle.wk_comete.category"] = { "Supercar", "Supercar" },
    ["vehicle.wk_comete.desc"] = {
        "Moteur central, boîte séquentielle, appui aérodynamique : réservée aux pilotes aguerris.",
        "Mid-engine, sequential gearbox, aerodynamic downforce: for seasoned drivers.",
    },
    ["vehicle.wk_zenith.category"] = { "Supercar électrique", "Electric supercar" },
    ["vehicle.wk_zenith.desc"] = {
        "Accélération foudroyante, intégrale, aides électroniques complètes.",
        "Blistering acceleration, all-wheel drive, full electronic aids.",
    },
    ["vehicle.wk_dune.category"] = { "SUV compact", "Compact SUV" },
    ["vehicle.wk_dune.desc"] = {
        "Garde au sol relevée et intégrale : à l'aise sur les chemins de campagne.",
        "Raised ride height and all-wheel drive: at home on country tracks.",
    },
    ["vehicle.wk_vigie.category"] = { "Grand SUV", "Large SUV" },
    ["vehicle.wk_vigie.desc"] = {
        "Lourd mais puissant, grand habitacle : confortable et rassurant.",
        "Heavy yet powerful, roomy cabin: comfortable and reassuring.",
    },
    ["vehicle.wk_sentier.category"] = { "Tout-terrain", "Off-roader" },
    ["vehicle.wk_sentier.desc"] = {
        "Court, haut et manuel : conçu pour la montagne, pas pour l'autoroute.",
        "Short, tall and manual: built for the mountains, not the motorway.",
    },
    ["vehicle.wk_atlas.category"] = { "Pick-up tout-terrain", "Off-road pickup" },
    ["vehicle.wk_atlas.desc"] = {
        "Diesel robuste à benne, intégral : le compagnon des chantiers et du port.",
        "Rugged diesel pickup with a bed, all-wheel drive: the companion of building sites and the harbour.",
    },
}

return T
