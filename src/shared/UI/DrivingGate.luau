--!strict
--[[
    Interfaces et conduite (lot 0.7, AUD-UI-01, §7.2), PUR.

    État de conduite : à pied, à l'arrêt (au volant, < 1 m/s, comme les
    contrôles serveur des lots 0.4–0.6) ou en mouvement (hystérésis : on
    redevient « à l'arrêt » sous 0,5 m/s).
    - Écrans COMPLETS (panneaux, confirmations financières) : à pied ou à
      l'arrêt seulement.
    - Écrans RAPIDES (navigation, prochaine direction, réglages rapides,
      alertes en lecture seule) : toujours.
    Si la voiture se met à rouler, les écrans complets passent en mode
    rapide (contenu conservé comme brouillon, RIEN n'est validé) ; le jeu ne
    freine jamais la voiture et ne met pas le monde en pause. Les services
    serveur refusent de toute façon les opérations sensibles en mouvement.
]]

local DrivingGate = {}

DrivingGate.MovingAboveMs = 1
DrivingGate.StoppedBelowMs = 0.5

export type Mode = "OnFoot" | "Stopped" | "Moving"
export type Screen = "Full" | "Quick"

function DrivingGate.mode(seated: boolean, speedMs: number, previous: Mode?): Mode
    if not seated then
        return "OnFoot"
    end
    if speedMs > DrivingGate.MovingAboveMs then
        return "Moving"
    end
    if previous == "Moving" and speedMs > DrivingGate.StoppedBelowMs then
        return "Moving"
    end
    return "Stopped"
end

function DrivingGate.allows(screen: Screen, mode: Mode): boolean
    return screen == "Quick" or mode ~= "Moving"
end

-- Une action financière ou sensible peut-elle être CONFIRMÉE maintenant ?
function DrivingGate.canConfirm(mode: Mode): boolean
    return mode ~= "Moving"
end

return table.freeze(DrivingGate)
