--!strict
--[[
    État DURABLE d'un exemplaire (lot 0.4 §12, §3.3) : énergie, dégâts,
    kilométrage, réconciliés par le serveur à partir de ses propres mesures
    (EnergyModel, DamageService, positions validées), jamais d'une valeur
    déclarée par le client.

    Règles de réconciliation (monotones) :
    - énergie : ne peut pas augmenter hors d'une recharge légitime (lot 0.5) ;
    - dégâts : ne peuvent pas diminuer hors d'une réparation (lot 0.5) ;
    - kilométrage : ne fait qu'augmenter, d'une distance plausible.
    Une session PROTÉGÉE (essai, course protégée, lots futurs) n'écrit rien :
    l'état durable préexistant reste intact (§3.3, §10.2).
]]

local Persistence = script.Parent.Parent.Persistence
local ProfileSchema = require(Persistence.ProfileSchema)

local DurableState = {}

export type Runtime = {
    EnergyFraction: number, -- mesure serveur, fraction de la réserve
    Damage: any, -- DamageModel.DamageState du serveur
    DistanceKm: number, -- distance parcourue mesurée depuis la dernière réconciliation
    ElapsedS: number, -- durée couverte par cette distance
    MaxSpeedKmh: number, -- vitesse maximale plausible du modèle
    Protected: boolean,
}

local function worse(stored: number, measured: any, lowerIsWorse: boolean): number
    if type(measured) ~= "number" or measured ~= measured then
        return stored
    end
    if lowerIsWorse then
        return math.clamp(math.min(stored, measured), 0, 1)
    end
    return math.clamp(math.max(stored, measured), 0, 1)
end

--[[
    Applique l'état mesuré à l'exemplaire. Renvoie vrai si l'enregistrement
    a changé (la sauvegarde périodique l'écrira ; rien n'est écrit à chaque
    image).
]]
function DurableState.reconcile(vehicle: ProfileSchema.Vehicle, runtime: Runtime, now: number): boolean
    if runtime.Protected then
        return false
    end
    local before = vehicle.Energy
    vehicle.Energy = worse(vehicle.Energy, runtime.EnergyFraction, true)
    local changed = vehicle.Energy ~= before

    local damage = runtime.Damage
    if type(damage) == "table" then
        local stored = vehicle.Damage
        for zone, wear in stored.Zones do
            local value = worse(wear, damage.Zones and damage.Zones[zone], false)
            if value ~= wear then
                stored.Zones[zone] = value
                changed = true
            end
        end
        for _, key in { "Engine", "Steering" } do
            local current = (stored :: any)[key]
            local value = worse(current, damage[key], true)
            if value ~= current then
                (stored :: any)[key] = value
                changed = true
            end
        end
        for index, health in stored.Suspension do
            local value = worse(health, damage.Suspension and damage.Suspension[index], true)
            if value ~= health then
                stored.Suspension[index] = value
                changed = true
            end
        end
        if type(damage.Impacts) == "number" and damage.Impacts > stored.Impacts then
            stored.Impacts = math.floor(damage.Impacts)
            changed = true
        end
        if type(damage.SteeringPullSide) == "number" and damage.SteeringPullSide ~= 0 then
            stored.SteeringPullSide = math.sign(damage.SteeringPullSide)
        end
    end

    -- Distance bornée par la vitesse maximale plausible (marge 20 %).
    local limit = runtime.MaxSpeedKmh * 1.2 * math.max(runtime.ElapsedS, 0) / 3600
    local distance = math.clamp(runtime.DistanceKm, 0, limit)
    if distance > 0 then
        vehicle.OdometerKm += distance
        changed = true
    end
    if changed then
        vehicle.UpdatedAt = now
    end
    return changed
end

return table.freeze(DurableState)
