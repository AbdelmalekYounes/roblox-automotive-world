--!strict
-- Encodage compact des commandes conducteur pour le réseau, et décodage
-- DÉFENSIF côté serveur : toute donnée reçue d'un client est considérée
-- comme non fiable (types, NaN, infinis, bornes).

local Types = require(script.Parent.VehicleTypes)

local InputCodec = {}

local function quantize(value: number): number
    return math.round(value * 100) / 100
end

-- Pas de quantification du régime transmis (tr/min) : assez fin pour le son, assez grossier pour ne pas
-- renvoyer la commande à chaque image (envoi seulement si une valeur change, lot AUDIO-01).
InputCodec.RpmStep = 100
InputCodec.MaxRpm = 20000

-- Tableau compact { accélérateur, frein, direction, frein à main (0/1),
-- cumul d'énergie consommée déclaré par le client (L ou kWh, session de conduite),
-- régime moteur déclaré (tr/min, 0 = moteur arrêté ou calé ; lot AUDIO-01) }.
-- Le cumul n'est qu'une DÉCLARATION : le serveur ne l'accepte qu'au-dessus de son
-- propre plancher physique et à un débit plausible (EnergyModel.settle). Le régime ne sert
-- qu'au SON des autres joueurs : borné par le serveur, sans aucun effet de jeu.
function InputCodec.encode(input: Types.DriverInput, energyUsed: number?, engineRpm: number?): { number }
    return {
        quantize(input.Throttle),
        quantize(input.Brake),
        quantize(input.Steer),
        if input.Handbrake then 1 else 0,
        math.round((energyUsed or 0) * 1e5) / 1e5,
        math.round((engineRpm or 0) / InputCodec.RpmStep) * InputCodec.RpmStep,
    }
end

local function finiteNumber(value: any, low: number, high: number): number?
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        return nil
    end
    return math.clamp(value, low, high)
end

-- Retourne une commande assainie (puis le cumul d'énergie et le régime déclarés,
-- s'ils sont valides), ou nil si la charge utile est invalide.
function InputCodec.decode(payload: any): (Types.DriverInput?, number?, number?)
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
    -- Régime facultatif (lot AUDIO-01) : borné ; absent ou invalide → nil (ancien client).
    local rpm = finiteNumber(payload[6], 0, InputCodec.MaxRpm)
    return {
        Throttle = throttle,
        Brake = brake,
        Steer = steer,
        Handbrake = handbrake >= 0.5,
        Clutch = 0,
    },
        energy,
        rpm
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
