--!strict
-- Encodage compact des commandes conducteur pour le réseau, et décodage
-- DÉFENSIF côté serveur : toute donnée reçue d'un client est considérée
-- comme non fiable (types, NaN, infinis, bornes).

local Types = require(script.Parent.VehicleTypes)

local InputCodec = {}

local function quantize(value: number): number
    return math.round(value * 100) / 100
end

-- Tableau compact { accélérateur, frein, direction, frein à main (0/1),
-- cumul d'énergie consommée déclaré par le client (L ou kWh, session de conduite) }.
-- Le cumul n'est qu'une DÉCLARATION : le serveur ne l'accepte qu'au-dessus de son
-- propre plancher physique et à un débit plausible (EnergyModel.settle).
function InputCodec.encode(input: Types.DriverInput, energyUsed: number?): { number }
    return {
        quantize(input.Throttle),
        quantize(input.Brake),
        quantize(input.Steer),
        if input.Handbrake then 1 else 0,
        math.round((energyUsed or 0) * 1e5) / 1e5,
    }
end

local function finiteNumber(value: any, low: number, high: number): number?
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        return nil
    end
    return math.clamp(value, low, high)
end

-- Retourne une commande assainie (et le cumul d'énergie déclaré, s'il est
-- valide), ou nil si la charge utile est invalide.
function InputCodec.decode(payload: any): (Types.DriverInput?, number?)
    if type(payload) ~= "table" then
        return nil
    end
    local throttle = finiteNumber(payload[1], 0, 1)
    local brake = finiteNumber(payload[2], 0, 1)
    local steer = finiteNumber(payload[3], -1, 1)
    local handbrake = finiteNumber(payload[4], 0, 1)
    if throttle == nil or brake == nil or steer == nil or handbrake == nil then
        return nil
    end
    -- Cumul facultatif : borné, jamais négatif ; absent ou invalide → nil.
    local energy = finiteNumber(payload[5], 0, 1e6)
    return {
        Throttle = throttle,
        Brake = brake,
        Steer = steer,
        Handbrake = handbrake >= 0.5,
        Clutch = 0,
    },
        energy
end

-- Commande neutre utilisée pour un véhicule stationné (frein à main serré).
InputCodec.Parked = table.freeze({
    Throttle = 0,
    Brake = 0,
    Steer = 0,
    Handbrake = true,
    Clutch = 0,
}) :: Types.DriverInput

return table.freeze(InputCodec)
