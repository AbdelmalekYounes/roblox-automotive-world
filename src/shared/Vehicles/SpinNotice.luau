--!strict
--[[
    Avis « antipatinage désactivé » (docs/PROPOSITION_PATINAGE.md, option E, décision du propriétaire du 2026-11-06 :
    « E puis B »). Règle PURE, testée par Lune.

    Quand une roue motrice patine franchement alors que le modèle est ÉQUIPÉ de l'antipatinage et que le joueur l'a
    coupé, le HUD l'indique une fois par session de conduite, avec la commande pour l'activer. C'est une information,
    pas une aide : aucune commande n'est modifiée (cahier des charges, ligne 55 : « sans assistances universelles
    cachées »).
]]

local Types = require(script.Parent.VehicleTypes)

local SpinNotice = {}

-- Patinage franc : glissement dans le sens du couple au-delà de 3 × le pic d'adhérence du pneu (banc planaire :
-- l'antipatinage régule autour de 1,5 à 2 × le pic), tenu au moins 0,3 s (un à-coup bref n'est pas signalé).
SpinNotice.SlipFactor = 3
SpinNotice.HoldS = 0.3

-- Vrai si une roue motrice patine franchement (glissement signé selon le sens de marche demandé par le rapport).
function SpinNotice.isSpinning(state: Types.VehicleRuntimeState, definition: Types.VehicleDefinition): boolean
    local limit = definition.Tires.PeakSlipRatio * SpinNotice.SlipFactor
    local direction = if state.Gear < 0 then -1 else 1
    for _, wheel in state.Wheels do
        if wheel.DriveShare > 0 and wheel.SlipRatio * direction > limit then
            return true
        end
    end
    return false
end

--[[
    Avance la minuterie de patinage de `dt` secondes ; renvoie la nouvelle minuterie et vrai quand l'avis doit être
    montré. Rien si le modèle n'a pas d'antipatinage (rien à activer) ou s'il est déjà actif.
]]
function SpinNotice.step(
    timer: number,
    state: Types.VehicleRuntimeState,
    definition: Types.VehicleDefinition,
    dt: number
): (number, boolean)
    if definition.Aids.TractionControl ~= true or state.Aids.TractionControl then
        return 0, false
    end
    local next = if SpinNotice.isSpinning(state, definition) then timer + dt else 0
    return next, next >= SpinNotice.HoldS
end

return table.freeze(SpinNotice)
