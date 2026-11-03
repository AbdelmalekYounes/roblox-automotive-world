--!strict
--[[
    Localisation CENTRALISÉE français / anglais (lot 0.7, §7.4, AUD-L10N-01).

    - Chaque texte joueur est identifié par une CLÉ ; le serveur n'envoie que
      des clés et des paramètres, jamais de phrase.
    - Une entrée = { fr, en } : les deux langues restent alignées (contrôlé
      par les tests : aucune clé sans traduction, mêmes paramètres).
    - Paramètres nommés « {nom} » ; les anciennes notices du véhicule (lots
      0.1–0.2) gardent leurs formats « %d / %s » dans les deux langues.
    - Changement de langue à chaud : aucune session ni progression touchée ;
      les interfaces se redessinent (Localization.changed).
    Lot 0.8 : textes du lot dans Texts08 ; libellés des panneaux des lots
    0.4 à 0.6 (garage, économie, courses) traduits via PanelTexts.
]]

local Localization = {}

export type Language = "fr" | "en"

Localization.Languages = table.freeze({ "fr", "en" } :: { Language })

local current: Language = "fr"
local listeners: { (Language) -> () } = {}

type Entry = { string }

local E: { [string]: Entry } = {
    -- ===================== Statuts des opérations (AUD-UI-02) =====================
    Confirmed = { "Enregistré (sauvegarde confirmée).", "Saved (save confirmed)." },
    Pending = { "Appliqué — sauvegarde en attente de confirmation.", "Applied — save awaiting confirmation." },
    Duplicate = { "Déjà fait (demande répétée ignorée).", "Already done (repeated request ignored)." },
    Ok = { "", "" },
    Unavailable = { "Profil momentanément non modifiable.", "Profile temporarily cannot be changed." },
    Loading = { "Profil : chargement…", "Profile: loading…" },
    Saved = { "Profil : sauvegardé", "Profile: saved" },
    Saving = { "Profil : sauvegarde en cours…", "Profile: saving…" },
    SaveDelayed = {
        "Profil : sauvegarde retardée, nouvel essai automatique",
        "Profile: save delayed, retrying automatically",
    },
    Locked = {
        "Profil : ouvert sur un autre serveur, réessayez dans un instant",
        "Profile: open on another server, try again shortly",
    },
    ReadOnly = { "Profil : lecture seule (aucune modification possible)", "Profile: read-only (no changes possible)" },
    Lost = {
        "Profil : session remplacée par un autre serveur — reconnectez-vous",
        "Profile: session replaced by another server — please rejoin",
    },
    Suspended = {
        "Profil : opérations sensibles suspendues (maintenance), rien n'est perdu",
        "Profile: sensitive operations suspended (maintenance), nothing is lost",
    },
    WritesSuspended = {
        "Opération suspendue temporairement (maintenance) : rien n'a été modifié.",
        "Operation temporarily suspended (maintenance): nothing was changed.",
    },
    -- ===================== Erreurs générales =====================
    ProfileUnavailable = {
        "Votre profil n'est pas modifiable pour le moment.",
        "Your profile cannot be changed right now.",
    },
    MenuWhileMoving = { "Arrêtez-vous pour utiliser ce menu.", "Stop the vehicle to use this menu." },
    RateLimited = { "Trop de demandes : patientez un instant.", "Too many requests: please wait a moment." },
    RequestIdInvalid = { "Demande invalide.", "Invalid request." },
    ServerError = { "Erreur du serveur : rien n'a été modifié.", "Server error: nothing was changed." },
    ActionUnknown = { "Action inconnue.", "Unknown action." },
    PayloadInvalid = { "Demande incomplète.", "Incomplete request." },
    ServerUnreachable = { "Serveur injoignable : rien n'est confirmé.", "Server unreachable: nothing is confirmed." },
    ProfileTooLarge = { "Limite technique de taille du profil atteinte.", "Technical profile size limit reached." },
    EconomyUnavailable = { "Indisponible pour le moment.", "Unavailable for now." },
    -- ===================== Collection, garages, propriétés (lot 0.4) =====================
    StarterCatalogUnavailable = {
        "Choix du véhicule de départ indisponible : modèles de lancement non encore définis.",
        "Starter vehicle choice unavailable: launch models not defined yet.",
    },
    StarterAlreadyChosen = {
        "Votre véhicule de départ est déjà choisi.",
        "Your starter vehicle is already chosen.",
    },
    StarterNotCandidate = {
        "Ce modèle ne fait pas partie du choix de départ.",
        "This model is not one of the starter choices.",
    },
    VehicleNotOwned = { "Véhicule introuvable dans votre collection.", "Vehicle not found in your collection." },
    VehicleReserved = { "Véhicule réservé par une autre opération.", "Vehicle reserved by another operation." },
    VehicleOut = { "Ce véhicule est sorti : ramenez-le d'abord.", "This vehicle is out: bring it back first." },
    VehicleNotOut = { "Aucun véhicule sorti.", "No vehicle is out." },
    AnotherVehicleOut = { "Un autre de vos véhicules est déjà sorti.", "Another of your vehicles is already out." },
    SlotOccupied = { "Cette place est occupée.", "This slot is taken." },
    SlotOutOfRange = { "Place inexistante pour cette propriété.", "No such slot in this property." },
    NotInOwnProperty = { "Entrez dans votre propriété pour faire cela.", "Enter your property to do this." },
    DisplayOtherProperty = {
        "Exposition possible seulement dans la propriété où vous êtes.",
        "You can only display vehicles in the property you are in.",
    },
    TakeOutNotHere = {
        "Sortie possible depuis votre propriété ou à son entrée.",
        "Take vehicles out from your property or at its entrance.",
    },
    ExitBlocked = { "Sortie encombrée : réessayez dans un instant.", "Exit blocked: try again shortly." },
    ReturnNotHere = {
        "Ramenez le véhicule à l'entrée d'une de vos propriétés ou à un garage public.",
        "Bring the vehicle to one of your property entrances or a public garage.",
    },
    ReturnMoving = { "Immobilisez le véhicule pour le ranger.", "Stop the vehicle to store it." },
    NotInGarage = {
        "À faire dans un garage (public ou de votre propriété).",
        "Do this in a garage (public or your own).",
    },
    ["CapabilityMissing:EditTuning"] = { "Réglages : dans un garage équipé.", "Tuning: in an equipped garage." },
    ["CapabilityMissing:EditCosmetics"] = {
        "Esthétique : dans un garage équipé.",
        "Cosmetics: in an equipped garage.",
    },
    ["CapabilityMissing:SwapParts"] = {
        "Pose et dépose de pièces : garage public uniquement.",
        "Fitting and removing parts: public garage only.",
    },
    ["CapabilityMissing:ApplyConfiguration"] = { "Configurations : dans un garage.", "Configurations: in a garage." },
    TuningInvalid = { "Réglages invalides.", "Invalid tuning." },
    TuningUnrealizable = {
        "Combinaison de réglages irréalisable pour ce modèle.",
        "This tuning combination is not possible on this model.",
    },
    TuningOutOfRange = { "Réglage hors plage.", "Setting out of range." },
    TuningUnknown = { "Réglage non disponible sur ce modèle.", "Setting not available on this model." },
    CosmeticInvalid = { "Choix esthétique invalide.", "Invalid cosmetic choice." },
    PartNotOwned = {
        "Vous ne possédez pas de pièce détachée de ce type.",
        "You do not own a spare part of this type.",
    },
    PartIncompatible = { "Pièce incompatible avec ce modèle.", "Part not compatible with this model." },
    PartUnknown = { "Pièce inconnue.", "Unknown part." },
    ConfigIndex = { "Emplacement de configuration invalide.", "Invalid configuration slot." },
    ConfigName = {
        "Nom de configuration invalide (1 à 24 caractères).",
        "Invalid configuration name (1 to 24 characters).",
    },
    ConfigNeedsPartSwap = {
        "Cette configuration demande d'échanger des pièces : garage public.",
        "This configuration requires swapping parts: public garage.",
    },
    ConfigPartsMissing = {
        "Pièces de cette configuration indisponibles.",
        "Parts for this configuration are unavailable.",
    },
    ConfigPartIncompatible = {
        "Pièce de cette configuration incompatible.",
        "A part of this configuration is incompatible.",
    },
    InviteGuestNotPresent = {
        "Le joueur invité doit être sur ce serveur.",
        "The invited player must be on this server.",
    },
    InviteSelf = { "Vous ne pouvez pas vous inviter.", "You cannot invite yourself." },
    InviteRights = { "Choisissez au moins un droit.", "Choose at least one permission." },
    InviteDuration = { "Durée d'invitation invalide.", "Invalid invitation duration." },
    InviteLimit = { "Trop d'invitations actives.", "Too many active invitations." },
    InviteUnknown = { "Invitation introuvable.", "Invitation not found." },
    PropertyNotOwned = { "Propriété introuvable.", "Property not found." },
    PropertyUnknown = { "Propriété introuvable.", "Property not found." },
    PropertyUnknownOffer = { "Offre de propriété inconnue.", "Unknown property offer." },
    VehicleModelMissing = { "Modèle de ce véhicule indisponible.", "This vehicle's model is unavailable." },
    EnterOnFoot = { "Entrée à pied uniquement.", "Enter on foot only." },
    AlreadyInside = { "Vous êtes déjà à l'intérieur.", "You are already inside." },
    OwnerNotPresent = { "Le propriétaire n'est pas sur ce serveur.", "The owner is not on this server." },
    EnterNotAtEntrance = { "Rendez-vous à l'entrée de la propriété.", "Go to the property entrance." },
    EnterNotAllowed = { "Accès refusé : invitation nécessaire.", "Access denied: an invitation is required." },
    NotInside = { "Vous n'êtes pas dans une propriété.", "You are not in a property." },
    VisitEnded = {
        "Visite terminée (invitation retirée ou propriétaire parti).",
        "Visit ended (invitation revoked or owner left).",
    },
    DriveRevokedStop = {
        "Le prêt de ce véhicule a été retiré : arrêtez-vous pour en descendre.",
        "Permission to drive this vehicle was revoked: stop to get out.",
    },
    VehicleNotYours = { "Ce véhicule appartient à un autre joueur.", "This vehicle belongs to another player." },
    -- ===================== Économie (lot 0.5) =====================
    InsufficientFunds = { "Solde insuffisant.", "Insufficient balance." },
    AmountInvalid = { "Montant invalide.", "Invalid amount." },
    BalanceLimit = { "Plafond de solde atteint.", "Balance limit reached." },
    NotAtDealer = {
        "Rendez-vous dans une concession qui propose ce modèle.",
        "Go to a dealership that sells this model.",
    },
    NotAtProperty = {
        "Rendez-vous à l'entrée de ce bien pour l'acheter.",
        "Go to this property's entrance to buy it.",
    },
    NotAtStation = { "Aucune station ou borne à proximité.", "No station or charger nearby." },
    NotAtCarWash = { "Aucun lavage à proximité.", "No car wash nearby." },
    NoPump = { "Pas de pompe ici pour ce véhicule.", "No pump here for this vehicle." },
    NoCharger = { "Pas de borne ici pour ce véhicule électrique.", "No charger here for this electric vehicle." },
    EnergyNotNeeded = { "Réserve déjà pleine.", "Already full." },
    ServiceBusy = {
        "Un service est déjà en cours pour ce véhicule.",
        "A service is already running for this vehicle.",
    },
    NoService = { "Aucun service en cours.", "No service running." },
    VehicleNotHere = { "Amenez votre véhicule sur place.", "Bring your vehicle here." },
    VehicleMoving = { "Immobilisez le véhicule.", "Stop the vehicle." },
    CatalogUnknown = { "Modèle inconnu.", "Unknown model." },
    CatalogNotPurchasable = {
        "Ce modèle n'est pas achetable dans cet environnement.",
        "This model cannot be bought in this environment.",
    },
    VehicleUntransferable = {
        "Ce véhicule est incessible (véhicule de départ).",
        "This vehicle cannot be transferred (starter vehicle).",
    },
    VehicleSynthetic = {
        "Donnée de développement : ni vendable ni cessible.",
        "Development data: cannot be sold or transferred.",
    },
    TradeInNoReference = { "Pas de prix neuf de référence pour ce modèle.", "No reference price for this model." },
    PropertyOccupied = { "Quelqu'un se trouve dans la propriété.", "Someone is inside the property." },
    PropertyNotSellable = { "Propriété gratuite : invendable.", "Free property: cannot be sold." },
    PropertyLimit = { "Cinq propriétés au plus.", "Five properties at most." },
    GarageMaxLevel = { "Garage déjà au niveau maximal.", "Garage already at maximum level." },
    ModuleAwaitingDecision = {
        "Module proposé, en attente de décision du propriétaire du projet.",
        "Proposed module, awaiting the project owner's decision.",
    },
    ModuleAlreadyInstalled = { "Module déjà installé.", "Module already installed." },
    PartInstalled = { "Déposez la pièce avant de la revendre.", "Remove the part before selling it." },
    PartNotEligible = { "Pièce non revendable (non payée).", "Part cannot be resold (not paid for)." },
    RepairNotNeeded = { "Aucune réparation nécessaire.", "No repair needed." },
    WashNotNeeded = { "Véhicule déjà propre.", "Vehicle already clean." },
    PriceInvalid = { "Prix hors limites.", "Price out of range." },
    ListingLimit = { "Trop d'annonces actives.", "Too many active listings." },
    ListingUnknown = { "Annonce introuvable.", "Listing not found." },
    ListingLocked = { "Un achat est en cours sur cette annonce.", "A purchase is in progress on this listing." },
    ListingClosed = { "Annonce close.", "Listing closed." },
    PurchaseAborted = {
        "Achat impossible (annonce indisponible ou solde insuffisant) : rien n'a été débité.",
        "Purchase not possible (listing unavailable or insufficient balance): nothing was charged.",
    },
    PurchaseCompensated = {
        "Vente impossible : vos fonds ont été restitués.",
        "Sale not possible: your funds were returned.",
    },
    TransferRecoverable = {
        "Transfert en cours : il sera terminé ou remboursé automatiquement.",
        "Transfer in progress: it will be completed or refunded automatically.",
    },
    JobUnknown = { "Métier inconnu.", "Unknown job." },
    MissionAlreadyActive = { "Une mission est déjà en cours.", "A mission is already active." },
    LeaveVehicleFirst = {
        "Descendez du véhicule pour recevoir le véhicule professionnel.",
        "Get out of your vehicle to receive the work vehicle.",
    },
    NoSpaceForVehicle = {
        "Pas de place libre à côté de vous pour le véhicule.",
        "No free space next to you for the vehicle.",
    },
    NoDestination = { "Aucune mission disponible ici pour ce métier.", "No mission available here for this job." },
    NoMission = { "Aucune mission en cours.", "No active mission." },
    MissionEnding = { "Mission en cours de clôture.", "Mission is ending." },
    Timeout = { "délai dépassé", "time limit exceeded" },
    Abandoned = { "abandonnée", "abandoned" },
    MovementCorrected = { "mouvement corrigé par le serveur", "movement corrected by the server" },
    -- ===================== Courses (lot 0.6) =====================
    RaceDriveToJoin = { "Présentez-vous au volant de votre voiture.", "Come in your own car, driving it." },
    RaceJoinNotHere = { "Rendez-vous au point d'inscription de ce parcours.", "Go to this course's sign-up point." },
    RaceVehicleNotOwned = {
        "Épreuve officielle : utilisez votre propre voiture (sortie du garage).",
        "Official event: use your own car (taken out of your garage).",
    },
    RaceAlreadyEngaged = {
        "Vous êtes déjà engagé dans une autre épreuve.",
        "You are already entered in another event.",
    },
    RaceAlreadyRegistered = { "Vous êtes déjà inscrit.", "You are already registered." },
    RaceRegistrationClosed = { "Inscriptions fermées.", "Registration closed." },
    RaceFull = { "Épreuve complète.", "Event full." },
    RaceModeNotAllowed = { "Mode non autorisé pour cette épreuve.", "Mode not allowed for this event." },
    RaceVehicleAlreadyEngaged = { "Cette voiture est déjà engagée.", "This car is already entered." },
    RaceNotRegistered = { "Vous n'êtes inscrit à aucune épreuve.", "You are not registered for any event." },
    RaceAlreadyLocked = {
        "Le départ est verrouillé : utilisez « Abandonner ».",
        "The start is locked: use “Retire”.",
    },
    RaceNotStarted = {
        "L'épreuve n'a pas commencé : désinscrivez-vous.",
        "The event has not started: unregister instead.",
    },
    RaceNotAtStart = {
        "Rejoignez la zone de départ avant de vous déclarer prêt.",
        "Reach the start area before declaring ready.",
    },
    RaceKindNotAllowed = { "Type d'épreuve non proposé sur ce parcours.", "Event type not offered on this course." },
    RacePrivateNeedsLobby = {
        "Créez ou rejoignez un salon pour cette épreuve.",
        "Create or join a lobby for this event.",
    },
    RaceRankedNeedsQueue = {
        "Les épreuves classées passent par la file classée.",
        "Ranked events go through the ranked queue.",
    },
    RaceRankedNotAllowed = { "Pas de classement pour cette discipline.", "No ranking for this discipline." },
    RaceUnknown = { "Parcours inconnu.", "Unknown course." },
    RaceNotEngaged = { "Aucun engagement de course en cours.", "No active race entry." },
    RaceOver = { "L'épreuve est terminée.", "The event is over." },
    RaceNotDisconnected = { "Aucune reprise à faire.", "Nothing to resume." },
    ReconnectWindowExpired = { "Délai de reprise dépassé.", "Resume window expired." },
    ResumeNotFair = { "Reprise impossible pour cette manche (équité).", "Cannot resume this run (fairness)." },
    RaceResumeFailed = { "Reprise impossible pour le moment.", "Cannot resume right now." },
    RaceNotInvited = { "Places réservées aux joueurs du match.", "Places reserved for the match players." },
    RaceCancelled = { "Épreuve annulée : pas assez de participants.", "Event cancelled: not enough participants." },
    AlreadyQueued = { "Vous êtes déjà dans la file.", "You are already queued." },
    MatchNotProposed = { "Aucun match à confirmer.", "No match to confirm." },
    MatchExpired = {
        "Match expiré : la confirmation n'est pas arrivée à temps.",
        "Match expired: confirmation came too late.",
    },
    VehicleInRace = {
        "Voiture engagée en course : opération impossible avant la fin.",
        "Car entered in a race: not possible until it ends.",
    },
    VehicleListed = { "Voiture en annonce sur le marché.", "Car is listed on the market." },
    -- ===================== Notices du véhicule (lots 0.1–0.2, formats %) =====================
    VehicleBusy = { "Ce véhicule est déjà occupé.", "This vehicle is already taken." },
    ExitTooFast = { "Ralentissez sous %d km/h pour sortir du véhicule.", "Slow below %d km/h to get out." },
    UnflipCooldown = { "Remise sur roues disponible dans %d s.", "Unflip available in %d s." },
    UnflipMoving = {
        "Immobilisez le véhicule avant de le remettre sur ses roues.",
        "Stop the vehicle before unflipping it.",
    },
    UnflipNotNeeded = { "Le véhicule est déjà sur ses roues.", "The vehicle is already upright." },
    UnflipDone = { "Véhicule remis sur ses roues.", "Vehicle set back on its wheels." },
    VehicleMovementCorrected = {
        "Position corrigée par le serveur (mouvement jugé impossible). Aucune sanction.",
        "Position corrected by the server (impossible movement). No penalty.",
    },
    CameraPreset = { "Caméra : %s", "Camera: %s" },
    VehicleUnavailable = {
        "Véhicule momentanément indisponible (prise en main refusée par le moteur). Réessayez.",
        "Vehicle temporarily unavailable (engine refused control). Try again.",
    },
    GamepadDisconnected = {
        "Manette déconnectée : commandes manette relâchées.",
        "Controller disconnected: controller inputs released.",
    },
    ShiftClutchRequired = { "Enfoncez l'embrayage pour changer de rapport.", "Press the clutch to change gear." },
    ShiftStopRequired = { "Arrêtez le véhicule pour engager ce rapport.", "Stop the vehicle to engage this gear." },
    ShiftOverRev = { "Rétrogradation refusée : régime trop élevé.", "Downshift refused: revs too high." },
    ShiftLimit = { "Pas de rapport au-delà.", "No gear beyond this one." },
    ShiftNotAvailable = { "Cette boîte change de rapport seule.", "This gearbox shifts by itself." },
    AidAbsent = { "Ce modèle n'est pas équipé de cette aide.", "This model does not have this aid." },
    AidChanged = { "%s", "%s" },
    RegenAbsent = { "Ce modèle n'a pas de récupération d'énergie.", "This model has no energy recovery." },
    RegenChanged = { "Récupération au lâcher : %s", "Lift-off recovery: %s" },
    EngineStalled = {
        "Moteur calé : enfoncez l'embrayage (ou neutre) pour redémarrer.",
        "Engine stalled: press the clutch (or neutral) to restart.",
    },
    EnergyEmpty = { "Réserve vide : plus de propulsion.", "Tank or battery empty: no more propulsion." },
    DamageMechanical = {
        "Dégâts mécaniques : le comportement du véhicule est affecté.",
        "Mechanical damage: vehicle handling is affected.",
    },
    -- ===================== Interface commune (lot 0.7) =====================
    ["ui.close"] = { "Fermer", "Close" },
    ["ui.back"] = { "Retour", "Back" },
    ["ui.open"] = { "Ouvrir", "Open" },
    ["ui.confirm"] = { "Confirmer", "Confirm" },
    ["ui.cancel"] = { "Annuler", "Cancel" },
    ["ui.on"] = { "activé", "on" },
    ["ui.off"] = { "désactivé", "off" },
    ["ui.yes"] = { "Oui", "Yes" },
    ["ui.no"] = { "Non", "No" },
    ["ui.loading"] = { "Chargement…", "Loading…" },
    ["ui.empty"] = { "Rien à afficher.", "Nothing to show." },
    ["ui.sent"] = { "Demande envoyée…", "Request sent…" },
    ["ui.done"] = { "Fait.", "Done." },
    ["ui.refused"] = { "Refusé : {reason}", "Refused: {reason}" },
    ["ui.blockedMoving"] = {
        "En mouvement : seules les actions rapides sont disponibles. Rien n'a été validé.",
        "While moving: only quick actions are available. Nothing was confirmed.",
    },
    ["ui.draftKept"] = {
        "Menu réduit pendant la conduite : votre saisie est conservée.",
        "Menu reduced while driving: your input is kept.",
    },
    ["ui.confirmAgain"] = {
        "Périphérique changé : appuyez de nouveau pour confirmer.",
        "Input device changed: press again to confirm.",
    },
    ["ui.panel.garage"] = { "Garage et collection", "Garage and collection" },
    ["ui.panel.economy"] = { "Économie et métiers", "Economy and jobs" },
    ["ui.panel.races"] = { "Courses", "Races" },
    ["ui.panel.map"] = { "Carte", "Map" },
    ["ui.panel.phone"] = { "Téléphone", "Phone" },
    -- ===================== HUD =====================
    ["hud.kmh"] = { "km/h", "km/h" },
    ["hud.rpm"] = { "tr/min", "rpm" },
    ["hud.gear"] = { "Rapport", "Gear" },
    ["hud.fuel"] = { "Carburant", "Fuel" },
    ["hud.battery"] = { "Batterie", "Battery" },
    ["hud.aids"] = { "Aides", "Aids" },
    ["hud.transmission.Automatic"] = { "Automatique", "Automatic" },
    ["hud.transmission.Manual"] = { "Manuelle", "Manual" },
    ["hud.transmission.SingleSpeed"] = { "Rapport unique", "Single speed" },
    ["hud.transmission.DualClutch"] = { "Double embrayage", "Dual clutch" },
    ["hud.transmission.Sequential"] = { "Séquentielle", "Sequential" },
    ["hud.transmission.CVT"] = { "Variation continue", "CVT" },
    ["hud.level.Minimal"] = { "Minimal", "Minimal" },
    ["hud.level.Standard"] = { "Standard", "Standard" },
    ["hud.level.Full"] = { "Complet", "Full" },
    ["hud.engineDamaged"] = { "Moteur endommagé", "Engine damaged" },
    ["hud.steeringDamaged"] = { "Direction endommagée", "Steering damaged" },
    ["hud.suspensionDamaged"] = { "Suspension endommagée", "Suspension damaged" },
    ["hud.stalled"] = { "Moteur calé", "Engine stalled" },
    ["hud.race.position"] = { "Position {position}/{count}", "Position {position}/{count}" },
    ["hud.race.lap"] = { "Tour {lap}/{laps}", "Lap {lap}/{laps}" },
    ["hud.race.checkpoint"] = { "Point {next}/{total}", "Checkpoint {next}/{total}" },
    ["hud.race.penalty"] = { "Pénalités +{seconds} s", "Penalties +{seconds} s" },
    ["hud.race.drift"] = { "{total} pts (+{combo} × {multiplier})", "{total} pts (+{combo} × {multiplier})" },
    ["hud.mission"] = { "{job} — {step}", "{job} — {step}" },
    -- ===================== GPS et carte =====================
    ["gps.noDestination"] = { "Aucune destination.", "No destination." },
    ["gps.computing"] = { "Calcul de l'itinéraire…", "Computing route…" },
    ["gps.recomputing"] = { "Recalcul de l'itinéraire…", "Recalculating route…" },
    ["gps.noRoute"] = { "Aucun itinéraire routier vers cette destination.", "No road route to this destination." },
    ["gps.invalid"] = { "Destination invalide.", "Invalid destination." },
    ["gps.arrived"] = { "Vous êtes arrivé.", "You have arrived." },
    ["gps.remaining"] = { "{distance} • {minutes} min", "{distance} • {minutes} min" },
    ["gps.direct"] = { "Direction : {distance} à vol d'oiseau", "Direction: {distance} as the crow flies" },
    ["gps.turn.Left"] = { "Tournez à gauche", "Turn left" },
    ["gps.turn.Right"] = { "Tournez à droite", "Turn right" },
    ["gps.turn.SlightLeft"] = { "Serrez à gauche", "Keep left" },
    ["gps.turn.SlightRight"] = { "Serrez à droite", "Keep right" },
    ["gps.turn.Straight"] = { "Continuez tout droit", "Continue straight" },
    ["gps.turn.UTurn"] = { "Faites demi-tour", "Make a U-turn" },
    ["gps.turn.Arrive"] = { "Arrivée", "Arrive" },
    ["gps.in"] = { "Dans {distance} : {action}", "In {distance}: {action}" },
    ["gps.onto"] = { "{action} — {road}", "{action} — {road}" },
    ["gps.setDestination"] = { "Définir comme destination", "Set as destination" },
    ["gps.clear"] = { "Effacer la destination", "Clear destination" },
    ["gps.profile.Road"] = { "Routes", "Roads" },
    ["gps.profile.AllTerrain"] = { "Tout-terrain (chemins)", "All-terrain (tracks)" },
    ["gps.missionTarget"] = { "Objectif de mission", "Mission objective" },
    ["gps.raceTarget"] = { "Objectif de course", "Race objective" },
    ["map.zoomIn"] = { "Zoom +", "Zoom in" },
    ["map.zoomOut"] = { "Zoom −", "Zoom out" },
    ["map.center"] = { "Recentrer", "Recenter" },
    ["map.filters"] = { "Filtres", "Filters" },
    ["map.search"] = { "Rechercher un lieu", "Search a place" },
    ["poi.Dealership"] = { "Concession", "Dealership" },
    ["poi.PublicGarage"] = { "Garage public", "Public garage" },
    ["poi.FuelStation"] = { "Station-service", "Fuel station" },
    ["poi.ChargingHub"] = { "Borne de recharge", "Charging hub" },
    ["poi.CarWash"] = { "Lavage", "Car wash" },
    ["poi.Property"] = { "Ma propriété", "My property" },
    ["poi.PropertyOffer"] = { "Propriété à vendre", "Property for sale" },
    ["poi.RaceStart"] = { "Départ de course", "Race start" },
    ["poi.MissionTarget"] = { "Mission", "Mission" },
    ["poi.SocialSpot"] = { "Lieu de rencontre", "Meeting spot" },
    ["poi.PlayerSpawn"] = { "Point d'arrivée", "Arrival point" },
    ["poi.GroupMember"] = { "Membre du groupe", "Group member" },
    ["poi.Destination"] = { "Destination choisie", "Chosen destination" },
    -- ===================== Smartphone =====================
    ["phone.home"] = { "Accueil", "Home" },
    ["phone.app.Map"] = { "Carte", "Map" },
    ["phone.app.Vehicles"] = { "Véhicules", "Vehicles" },
    ["phone.app.Properties"] = { "Propriétés", "Properties" },
    ["phone.app.Missions"] = { "Missions", "Jobs" },
    ["phone.app.Races"] = { "Courses", "Races" },
    ["phone.app.Market"] = { "Marché", "Market" },
    ["phone.app.Social"] = { "Social", "Social" },
    ["phone.app.Settings"] = { "Paramètres", "Settings" },
    ["phone.app.Notifications"] = { "Notifications", "Notifications" },
    ["phone.quickMode"] = {
        "Mode conduite : navigation et réglages rapides",
        "Driving mode: navigation and quick settings",
    },
    ["phone.enlarge"] = { "Agrandir", "Enlarge" },
    ["phone.shrink"] = { "Réduire", "Shrink" },
    ["phone.openFull"] = { "Ouvrir l'écran complet", "Open full screen" },
    ["phone.fullOnlyStopped"] = {
        "Écran complet disponible à l'arrêt ou à pied.",
        "Full screen available when stopped or on foot.",
    },
    ["phone.unread"] = { "{count} non lue(s)", "{count} unread" },
    ["phone.vehicle.state"] = {
        "{model} — {state} • énergie {energy} %",
        "{model} — {state} • energy {energy}%",
    },
    ["phone.vehicle.Stored"] = { "rangé", "stored" },
    ["phone.vehicle.Displayed"] = { "exposé", "on display" },
    ["phone.vehicle.Out"] = { "sorti", "out" },
    ["phone.vehicle.configs"] = { "{count} configuration(s)", "{count} configuration(s)" },
    ["phone.property.line"] = { "{name} — niveau {level}", "{name} — level {level}" },
    ["phone.property.navigate"] = { "Y aller", "Go there" },
    ["phone.mission.active"] = { "Mission en cours : {job}", "Active mission: {job}" },
    ["phone.mission.start"] = { "Démarrer", "Start" },
    ["phone.mission.line"] = { "{job} • {completed} réussie(s)", "{job} • {completed} completed" },
    ["phone.race.line"] = { "{name} — {discipline} • {distance}", "{name} — {discipline} • {distance}" },
    ["phone.race.rank"] = { "{ladder} : {rank} ({points} pts)", "{ladder}: {rank} ({points} pts)" },
    ["phone.race.season"] = { "Saison {index}", "Season {index}" },
    ["phone.market.line"] = { "{model} — {price}", "{model} — {price}" },
    ["phone.market.mine"] = { "Mes annonces : {count}", "My listings: {count}" },
    ["phone.credits"] = { "{amount} cr", "{amount} cr" },
    -- ===================== Social =====================
    ["social.group"] = { "Groupe", "Group" },
    ["social.noGroup"] = { "Vous n'êtes dans aucun groupe.", "You are not in a group." },
    ["social.create"] = { "Créer un groupe", "Create a group" },
    ["social.invite"] = { "Inviter", "Invite" },
    ["social.accept"] = { "Accepter", "Accept" },
    ["social.decline"] = { "Refuser", "Decline" },
    ["social.leave"] = { "Quitter le groupe", "Leave group" },
    ["social.kick"] = { "Exclure", "Remove" },
    ["social.promote"] = { "Confier la direction", "Make leader" },
    ["social.dissolve"] = { "Dissoudre le groupe", "Disband group" },
    ["social.leader"] = { "responsable", "leader" },
    ["social.offline"] = { "absent", "away" },
    ["social.friend"] = { "ami", "friend" },
    ["social.members"] = { "Membres ({count}/8)", "Members ({count}/8)" },
    ["social.players"] = { "Joueurs du serveur", "Players on this server" },
    ["social.invited"] = { "{name} vous invite dans son groupe.", "{name} invites you to their group." },
    ["social.inviteSent"] = { "Invitation envoyée à {name}.", "Invitation sent to {name}." },
    ["social.joined"] = { "{name} a rejoint le groupe.", "{name} joined the group." },
    ["social.left"] = { "{name} a quitté le groupe.", "{name} left the group." },
    ["social.kicked"] = { "Vous avez été retiré du groupe.", "You were removed from the group." },
    ["social.dissolved"] = { "Le groupe a été dissous.", "The group was disbanded." },
    ["social.newLeader"] = { "{name} dirige désormais le groupe.", "{name} now leads the group." },
    ["social.shareLocation"] = { "Partager ma position avec le groupe", "Share my location with the group" },
    ["social.showMembers"] = { "Afficher les membres qui partagent", "Show members who share" },
    ["social.sharingOff"] = { "Partage de position désactivé.", "Location sharing turned off." },
    ["social.sharingOn"] = {
        "Partage de position activé avec votre groupe actuel ({minutes} min).",
        "Location sharing on with your current group ({minutes} min).",
    },
    ["social.sharingEnded"] = { "Partage de position terminé.", "Location sharing ended." },
    ["social.raceSuggested"] = {
        "{name} propose l'épreuve « {course} ».",
        "{name} suggests the event “{course}”.",
    },
    ["social.suggestRace"] = { "Proposer au groupe", "Suggest to group" },
    ["social.channels"] = { "Canaux de communication", "Communication channels" },
    ["social.channel.Group"] = { "Groupe (texte filtré par Roblox)", "Group (text filtered by Roblox)" },
    ["social.channel.Proximity"] = { "Proximité (texte filtré par Roblox)", "Proximity (text filtered by Roblox)" },
    ["social.channel.Voice"] = {
        "Voix : selon vos paramètres Roblox (non géré par le jeu)",
        "Voice: per your Roblox settings (not managed by the game)",
    },
    ["social.channel.restricted"] = {
        "Indisponible selon vos paramètres Roblox.",
        "Unavailable under your Roblox settings.",
    },
    ["social.privacy"] = {
        "Le groupe ne donne accès ni à vos propriétés, ni à vos voitures, ni à votre économie.",
        "The group gives no access to your properties, cars or economy.",
    },
    GroupFull = { "Groupe complet (8 joueurs).", "Group full (8 players)." },
    GroupNotLeader = { "Réservé au responsable du groupe.", "Group leader only." },
    GroupNotMember = { "Ce joueur n'est pas dans votre groupe.", "This player is not in your group." },
    GroupAlready = { "Vous êtes déjà dans un groupe.", "You are already in a group." },
    GroupNone = { "Vous n'êtes dans aucun groupe.", "You are not in a group." },
    GroupTargetBusy = { "Ce joueur est déjà dans un groupe.", "This player is already in a group." },
    GroupInviteExpired = { "Invitation expirée ou retirée.", "Invitation expired or withdrawn." },
    GroupInvitePending = { "Invitation déjà envoyée.", "Invitation already sent." },
    GroupTargetAbsent = { "Ce joueur n'est pas sur ce serveur.", "This player is not on this server." },
    GroupSelf = { "Action impossible sur vous-même.", "You cannot do this to yourself." },
    GroupInviteLimit = { "Trop d'invitations en attente.", "Too many pending invitations." },
    -- ===================== Notifications =====================
    ["notif.level.Info"] = { "Information", "Info" },
    ["notif.level.Warning"] = { "Avertissement", "Warning" },
    ["notif.level.Critical"] = { "Critique", "Critical" },
    ["notif.lowFuel"] = { "Carburant faible ({percent} %).", "Low fuel ({percent}%)." },
    ["notif.lowBattery"] = { "Batterie faible ({percent} %).", "Low battery ({percent}%)." },
    ["notif.heavyDamage"] = { "Dégâts importants : rendez-vous dans un garage.", "Heavy damage: visit a garage." },
    ["notif.mechanicalFailure"] = {
        "Défaillance mécanique dangereuse : ralentissez.",
        "Dangerous mechanical failure: slow down.",
    },
    ["notif.saveUncertain"] = {
        "Sauvegarde incertaine pour une opération sensible : elle sera vérifiée, rien n'est rejoué.",
        "Uncertain save for a sensitive operation: it will be checked, nothing is replayed.",
    },
    ["notif.sessionLost"] = { "Session de profil perdue : reconnectez-vous.", "Profile session lost: please rejoin." },
    ["notif.missionAvailable"] = {
        "Missions disponibles : ouvrez l'application Missions.",
        "Jobs available: open the Jobs app.",
    },
    ["notif.history"] = { "Historique des notifications", "Notification history" },
    ["notif.clear"] = { "Tout effacer", "Clear all" },
    -- ===================== Paramètres =====================
    ["settings.interface"] = { "Interface", "Interface" },
    ["settings.controls"] = { "Commandes", "Controls" },
    ["settings.accessibility"] = { "Accessibilité", "Accessibility" },
    ["settings.notifications"] = { "Notifications", "Notifications" },
    ["settings.audio"] = { "Audio", "Audio" },
    ["settings.language"] = { "Langue : {language}", "Language: {language}" },
    ["settings.language.fr"] = { "Français", "Français" },
    ["settings.language.en"] = { "English", "English" },
    ["settings.hudLevel"] = { "Niveau du HUD : {level}", "HUD level: {level}" },
    ["settings.hudScale"] = { "Taille du HUD : {value} %", "HUD size: {value}%" },
    ["settings.hudCorner"] = { "Position du HUD : {value}", "HUD position: {value}" },
    ["settings.corner.BottomRight"] = { "bas droite", "bottom right" },
    ["settings.corner.BottomLeft"] = { "bas gauche", "bottom left" },
    ["settings.minimap"] = { "Mini-carte : {state}", "Minimap: {state}" },
    ["settings.minimapZoom"] = { "Zoom de la mini-carte : {value}", "Minimap zoom: {value}" },
    ["settings.minimapRotate"] = { "Mini-carte orientée : {state}", "Rotating minimap: {state}" },
    ["settings.devHud"] = { "HUD de développement : {state}", "Developer HUD: {state}" },
    ["settings.textScale"] = { "Taille des textes : {value} %", "Text size: {value}%" },
    ["settings.contrast"] = { "Contraste renforcé : {state}", "High contrast: {state}" },
    ["settings.reduceMotion"] = { "Réduire les animations : {state}", "Reduce motion: {state}" },
    ["settings.panelOpacity"] = { "Opacité des panneaux : {value} %", "Panel opacity: {value}%" },
    ["settings.navSensitivity"] = { "Sensibilité de navigation : {value}", "Navigation sensitivity: {value}" },
    ["settings.reduceSecondary"] = {
        "Réduire les notifications secondaires : {state}",
        "Reduce secondary notifications: {state}",
    },
    ["settings.visualAlerts"] = { "Alertes visuelles renforcées : {state}", "Enhanced visual alerts: {state}" },
    ["settings.drivingInfo"] = { "Informations en conduite : {state}", "Info while driving: {state}" },
    ["settings.volume"] = { "Volume {category} : {value} %", "{category} volume: {value}%" },
    ["settings.volume.Master"] = { "général", "master" },
    ["settings.volume.Interface"] = { "interface", "interface" },
    ["settings.rebind"] = { "Changer : {action} ({key})", "Change: {action} ({key})" },
    ["settings.rebindPrompt"] = { "Appuyez sur une touche… (Échap : annuler)", "Press a key… (Esc: cancel)" },
    ["settings.rebindConflict"] = {
        "Touche déjà utilisée par « {action} ».",
        "Key already used by “{action}”.",
    },
    ["settings.rebindReserved"] = { "Touche réservée à la conduite.", "Key reserved for driving." },
    ["settings.reset"] = { "Réinitialiser", "Reset" },
    ["settings.saved"] = { "Préférences enregistrées.", "Preferences saved." },
    ["action.Phone"] = { "Téléphone", "Phone" },
    ["action.Map"] = { "Carte", "Map" },
    ["action.Garage"] = { "Garage", "Garage" },
    ["action.Economy"] = { "Économie", "Economy" },
    ["action.Races"] = { "Courses", "Races" },
    ["action.HudLevel"] = { "Niveau du HUD", "HUD level" },
    ["action.ClearRoute"] = { "Effacer l'itinéraire", "Clear route" },
    ["action.Back"] = { "Retour", "Back" },
}

-- Textes du lot 0.8 (module séparé) : fusionnés sans jamais écraser une clé existante.
for key, entry in require(script.Parent.Texts08) do
    assert(E[key] == nil, "Clé de localisation en double : " .. key)
    E[key] = entry
end

Localization.Entries = E

-- Langue courante et changement à chaud (aucune session touchée).
function Localization.language(): Language
    return current
end

function Localization.setLanguage(language: any): boolean
    if language ~= "fr" and language ~= "en" then
        return false
    end
    if language ~= current then
        current = language
        for _, listener in listeners do
            pcall(listener, language)
        end
    end
    return true
end

function Localization.changed(listener: (Language) -> ())
    table.insert(listeners, listener)
end

local function raw(key: string, language: Language): string?
    local entry: Entry? = E[key]
    if entry == nil then
        -- Préfixes génériques des erreurs paramétrées (« TuningOutOfRange:Spring… »).
        local prefix = string.match(key, "^([^:]+):")
        if prefix and string.sub(prefix, 1, 8) == "Cosmetic" then
            prefix = "CosmeticInvalid"
        end
        entry = if prefix then E[prefix] else nil
        if entry == nil then
            return nil
        end
    end
    return (entry :: Entry)[if language == "en" then 2 else 1]
end

--[[
    Texte d'une clé avec paramètres nommés. Une clé inconnue est renvoyée
    telle quelle (visible, jamais une phrase inventée).
]]
function Localization.t(key: string?, params: { [string]: any }?, language: Language?): string
    if key == nil then
        return ""
    end
    local text = raw(key, language or current)
    if text == nil then
        return key
    end
    if params then
        text = string.gsub(text, "{(%w+)}", function(name: string): string
            local value = params[name]
            return if value ~= nil then tostring(value) else "{" .. name .. "}"
        end)
    end
    return text
end

-- Ancien format « %d / %s » (notices du véhicule).
function Localization.format(key: string, value: any, language: Language?): string
    local text = raw(key, language or current)
    if text == nil then
        return key
    end
    if value ~= nil and string.find(text, "%%") then
        local ok, formatted = pcall(string.format, text, value)
        if ok then
            return formatted
        end
    end
    return text
end

function Localization.has(key: string): boolean
    return raw(key, "fr") ~= nil
end

-- Paramètres d'un texte (contrôle d'alignement FR/EN).
function Localization.placeholders(text: string): { string }
    local names: { string } = {}
    for name in string.gmatch(text, "{(%w+)}") do
        table.insert(names, name)
    end
    for spec in string.gmatch(text, "%%[ds]") do
        table.insert(names, spec)
    end
    table.sort(names)
    return names
end

-- Distance lisible selon la langue.
function Localization.distance(meters: number, language: Language?): string
    local lang = language or current
    if meters < 1000 then
        return string.format("%d m", math.floor(meters / 10 + 0.5) * 10)
    end
    local text = string.format("%.1f km", meters / 1000)
    return if lang == "fr" then (string.gsub(text, "%.", ",")) else text
end

-- Montant lisible (séparateur de milliers selon la langue).
function Localization.amount(value: number, language: Language?): string
    local lang = language or current
    local digits = tostring(math.floor(value))
    local sep = if lang == "fr" then " " else ","
    local formatted = string.reverse((string.gsub(string.reverse(digits), "(%d%d%d)", "%1" .. sep)))
    return (string.gsub(formatted, "^[%s,]+", ""))
end

return Localization
