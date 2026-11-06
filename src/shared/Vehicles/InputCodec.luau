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

-- ======================== Lot AUDIO-03 : sons des pneus ========================
-- Pas du glissement sonore transmis (0 à 1) et nombre de familles de revêtement (codes 0 à 3, TireAudioModel).
InputCodec.TireSlipStep = 0.1
InputCodec.TireSurfaceCodes = 4

-- Ajoute à une commande encodée le glissement sonore des pneus (7e valeur, 0 à 1, pas de 0,1) et la famille de
-- revêtement (8e valeur, entier 0 à 3). Simple DÉCLARATION, qui ne sert qu'au son des autres joueurs.
function InputCodec.appendTire(encoded: { number }, slip: number, surfaceCode: number): { number }
    -- Division par l'inverse du pas : 0,7 exact (et non 0,7000000000000001), pour comparer les envois successifs.
    local steps = math.round(1 / InputCodec.TireSlipStep)
    encoded[7] = math.round(math.clamp(slip, 0, 1) * steps) / steps
    encoded[8] = math.clamp(math.round(surfaceCode), 0, InputCodec.TireSurfaceCodes - 1)
    return encoded
end

local function finiteNumber(value: any, low: number, high: number): number?
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        return nil
    end
    return math.clamp(value, low, high)
end

-- Retourne une commande assainie (puis le cumul d'énergie, le régime, le glissement sonore
-- des pneus et le code de revêtement déclarés, s'ils sont valides), ou nil si la charge utile est invalide.
function InputCodec.decode(payload: any): (Types.DriverInput?, number?, number?, number?, number?)
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
    -- Pneus facultatifs (lot AUDIO-03) : glissement borné à 0–1, code de revêtement entier ; sinon nil.
    local tireSlip = finiteNumber(payload[7], 0, 1)
    local surface = finiteNumber(payload[8], 0, InputCodec.TireSurfaceCodes - 1)
    local tireSurface = if surface then math.round(surface) else nil
    return {
        Throttle = throttle,
        Brake = brake,
        Steer = steer,
        Handbrake = handbrake >= 0.5,
        Clutch = 0,
    },
        energy,
        rpm,
        tireSlip,
        tireSurface
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
