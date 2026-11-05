--!strict
--[[
    Place passager (lot 0.8), règle PURE : qui peut monter à côté du conducteur.

    - Exemplaire personnel : son propriétaire, ou un membre du même groupe que
      le propriétaire ou que le conducteur actuel.
    - Véhicule du parc d'essai (sans propriétaire) : libre tant que personne ne
      conduit ; sinon, seulement un membre du groupe du conducteur (pas
      d'auto-stop chez un inconnu).
    - Jamais le conducteur lui-même. Le serveur revalide aussi la distance et
      l'état du personnage ; être passager ne donne aucun droit de conduire.
]]

local PassengerRules = {}

export type Context = {
    OwnerUserId: number?, -- nil : véhicule sans propriétaire (parc d'essai)
    DriverUserId: number?,
    RiderUserId: number,
}

function PassengerRules.mayRide(context: Context, sameGroup: (number, number) -> boolean): (boolean, string?)
    local rider = context.RiderUserId
    local driver = context.DriverUserId
    local owner = context.OwnerUserId
    if driver == rider then
        return false, "PassengerIsDriver"
    end
    if owner ~= nil then
        if rider == owner or sameGroup(owner, rider) or (driver ~= nil and sameGroup(driver, rider)) then
            return true, nil
        end
        return false, "PassengerNotAllowed"
    end
    if driver == nil or sameGroup(driver, rider) then
        return true, nil
    end
    return false, "PassengerNotAllowed"
end

return table.freeze(PassengerRules)
