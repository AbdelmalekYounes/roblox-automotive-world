--!strict
-- Textes de la progression (lot 0.4), indexés par les clés envoyées par le
-- serveur (AUD-L10N-01 : français seul pour l'instant, anglais à produire).

local ProgressionMessages = {}

local FRENCH: { [string]: string } = {
    -- Statuts
    Confirmed = "Enregistré (sauvegarde confirmée).",
    Pending = "Appliqué — sauvegarde en attente de confirmation.",
    Duplicate = "Déjà fait (demande répétée ignorée).",
    Ok = "",
    Unavailable = "Profil momentanément non modifiable.",
    -- États du profil
    Loading = "Profil : chargement…",
    Saved = "Profil : sauvegardé",
    Saving = "Profil : sauvegarde en cours…",
    SaveDelayed = "Profil : sauvegarde retardée, nouvel essai automatique",
    Locked = "Profil : ouvert sur un autre serveur, réessayez dans un instant",
    ReadOnly = "Profil : lecture seule (aucune modification possible)",
    Lost = "Profil : session remplacée par un autre serveur — reconnectez-vous",
    -- Erreurs
    ProfileUnavailable = "Votre profil n'est pas modifiable pour le moment.",
    MenuWhileMoving = "Arrêtez-vous pour utiliser ce menu.",
    RateLimited = "Trop de demandes : patientez un instant.",
    RequestIdInvalid = "Demande invalide.",
    ServerError = "Erreur du serveur : rien n'a été modifié.",
    ActionUnknown = "Action inconnue.",
    PayloadInvalid = "Demande incomplète.",
    EconomyUnavailable = "Indisponible : l'économie arrive au lot 0.5.",
    StarterCatalogUnavailable = "Choix du véhicule de départ indisponible : modèles de lancement non encore définis.",
    StarterAlreadyChosen = "Votre véhicule de départ est déjà choisi.",
    StarterNotCandidate = "Ce modèle ne fait pas partie du choix de départ.",
    VehicleNotOwned = "Véhicule introuvable dans votre collection.",
    VehicleReserved = "Véhicule réservé par une autre opération.",
    VehicleOut = "Ce véhicule est sorti : ramenez-le d'abord.",
    VehicleNotOut = "Aucun véhicule sorti.",
    AnotherVehicleOut = "Un autre de vos véhicules est déjà sorti.",
    SlotOccupied = "Cette place est occupée.",
    SlotOutOfRange = "Place inexistante pour cette propriété.",
    NotInOwnProperty = "Entrez dans votre propriété pour faire cela.",
    DisplayOtherProperty = "Exposition possible seulement dans la propriété où vous êtes.",
    TakeOutNotHere = "Sortie possible depuis votre propriété ou à son entrée.",
    ExitBlocked = "Sortie encombrée : réessayez dans un instant.",
    ReturnNotHere = "Ramenez le véhicule à l'entrée d'une de vos propriétés ou à un garage public.",
    ReturnMoving = "Immobilisez le véhicule pour le ranger.",
    NotInGarage = "À faire dans un garage (public ou de votre propriété).",
    ["CapabilityMissing:EditTuning"] = "Réglages : garage public (ou atelier privé, lot 0.5).",
    ["CapabilityMissing:EditCosmetics"] = "Esthétique : garage public (ou cabine privée, lot 0.5).",
    ["CapabilityMissing:SwapParts"] = "Pose et dépose de pièces : garage public uniquement.",
    ["CapabilityMissing:ApplyConfiguration"] = "Configurations : dans un garage.",
    TuningInvalid = "Réglages invalides.",
    TuningUnrealizable = "Combinaison de réglages irréalisable pour ce modèle.",
    PartNotOwned = "Vous ne possédez pas de pièce détachée de ce type.",
    PartIncompatible = "Pièce incompatible avec ce modèle.",
    PartUnknown = "Pièce inconnue.",
    ConfigIndex = "Emplacement de configuration invalide.",
    ConfigName = "Nom de configuration invalide (1 à 24 caractères).",
    ConfigNeedsPartSwap = "Cette configuration demande d'échanger des pièces : garage public.",
    ConfigPartsMissing = "Pièces de cette configuration indisponibles.",
    ConfigPartIncompatible = "Pièce de cette configuration incompatible.",
    InviteGuestNotPresent = "Le joueur invité doit être sur ce serveur.",
    InviteSelf = "Vous ne pouvez pas vous inviter.",
    InviteRights = "Choisissez au moins un droit.",
    InviteDuration = "Durée d'invitation invalide.",
    InviteLimit = "Trop d'invitations actives.",
    InviteUnknown = "Invitation introuvable.",
    PropertyNotOwned = "Propriété introuvable.",
    EnterOnFoot = "Entrée à pied uniquement.",
    AlreadyInside = "Vous êtes déjà à l'intérieur.",
    OwnerNotPresent = "Le propriétaire n'est pas sur ce serveur.",
    PropertyUnknown = "Propriété introuvable.",
    EnterNotAtEntrance = "Rendez-vous à l'entrée de la propriété.",
    EnterNotAllowed = "Accès refusé : invitation nécessaire.",
    NotInside = "Vous n'êtes pas dans une propriété.",
    VisitEnded = "Visite terminée (invitation retirée ou propriétaire parti).",
    DriveRevokedStop = "Le prêt de ce véhicule a été retiré : arrêtez-vous pour en descendre.",
    ProfileTooLarge = "Limite technique de taille du profil atteinte.",
}

function ProgressionMessages.text(key: string?): string
    if key == nil then
        return ""
    end
    local text = FRENCH[key]
    if text then
        return text
    end
    -- Préfixe générique (ex. « TuningOutOfRange:SpringFront »).
    local prefix = string.match(key, "^([^:]+):")
    if prefix == "TuningOutOfRange" then
        return "Réglage hors plage."
    elseif prefix == "TuningUnknown" then
        return "Réglage non disponible sur ce modèle."
    elseif prefix and string.sub(prefix, 1, 8) == "Cosmetic" then
        return "Choix esthétique invalide."
    end
    return key
end

return table.freeze(ProgressionMessages)
