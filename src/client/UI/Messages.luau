--!strict
-- Textes affichés au joueur, indexés par clé.
-- Le serveur n'envoie que des clés (jamais de texte libre) afin de préparer
-- la localisation FR/EN exigée (AUD-L10N-01). Seul le français est rédigé
-- (lots 0.1 et 0.2) ; l'anglais reste à produire et à relire.

local Messages = {}

local FRENCH: { [string]: string } = {
    VehicleBusy = "Ce véhicule est déjà occupé.",
    ExitTooFast = "Ralentissez sous %d km/h pour sortir du véhicule.",
    UnflipCooldown = "Remise sur roues disponible dans %d s.",
    UnflipMoving = "Immobilisez le véhicule avant de le remettre sur ses roues.",
    UnflipNotNeeded = "Le véhicule est déjà sur ses roues.",
    UnflipDone = "Véhicule remis sur ses roues.",
    MovementCorrected = "Position corrigée par le serveur (mouvement jugé impossible). Aucune sanction.",
    CameraPreset = "Caméra : %s",
    VehicleUnavailable = "Véhicule momentanément indisponible (prise en main refusée par le moteur). Réessayez.",
    GamepadDisconnected = "Manette déconnectée : commandes manette relâchées.",
    -- Lot 0.2
    ShiftClutchRequired = "Enfoncez l'embrayage pour changer de rapport.",
    ShiftStopRequired = "Arrêtez le véhicule pour engager ce rapport.",
    ShiftOverRev = "Rétrogradation refusée : régime trop élevé.",
    ShiftLimit = "Pas de rapport au-delà.",
    ShiftNotAvailable = "Cette boîte change de rapport seule.",
    AidAbsent = "Ce modèle n'est pas équipé de cette aide.",
    AidChanged = "%s",
    RegenAbsent = "Ce modèle n'a pas de récupération d'énergie.",
    RegenChanged = "Récupération au lâcher : %s",
    EngineStalled = "Moteur calé : enfoncez l'embrayage (ou neutre) pour redémarrer.",
    EnergyEmpty = "Réserve vide : plus de propulsion. Aucune recharge n'est disponible dans cette zone d'essai.",
    DamageMechanical = "Dégâts mécaniques : le comportement du véhicule est affecté.",
}

function Messages.format(key: string, value: any): string
    local template = FRENCH[key]
    if template == nil then
        return key
    end
    if value ~= nil and string.find(template, "%%") then
        local ok, text = pcall(string.format, template, value)
        if ok then
            return text
        end
    end
    return template
end

return table.freeze(Messages)
