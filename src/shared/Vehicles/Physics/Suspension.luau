--!strict
-- Suspension PURE : ressort, amortisseur bi-tube simplifié (compression /
-- détente distinctes), butée de fin de course et barre antiroulis.

local Types = require(script.Parent.Parent.VehicleTypes)

local Suspension = {}

-- Force normale (N) transmise par la roue au châssis, selon l'axe de suspension.
function Suspension.normalForce(axle: Types.AxleSuspension, contact: Types.WheelContact): number
    if not contact.Grounded then
        return 0
    end
    local x = contact.Compression
    local v = contact.CompressionVelocity
    local damping = if v > 0 then axle.BumpDampingNsPm else axle.ReboundDampingNsPm
    local force = axle.SpringRateNpm * x + damping * v
    -- Butée : raideur progressive sur les 15 % finaux du débattement.
    local bumpStart = axle.TravelM * 0.85
    if x > bumpStart then
        force += axle.BumpStopRateNpm * (x - bumpStart)
    end
    -- Un pneu ne peut que pousser, jamais tirer le véhicule vers le sol.
    return math.max(0, force)
end

-- Barre antiroulis : transfère de la charge du côté le moins comprimé vers
-- le plus comprimé, proportionnellement à la différence de compression.
function Suspension.applyAntiRoll(
    rate: number,
    left: Types.WheelContact,
    right: Types.WheelContact,
    normals: { number },
    leftIndex: number,
    rightIndex: number
)
    if rate <= 0 then
        return
    end
    local leftX = if left.Grounded then left.Compression else 0
    local rightX = if right.Grounded then right.Compression else 0
    local transfer = rate * (leftX - rightX)
    if left.Grounded then
        normals[leftIndex] = math.max(0, normals[leftIndex] + transfer)
    end
    if right.Grounded then
        normals[rightIndex] = math.max(0, normals[rightIndex] - transfer)
    end
end

return table.freeze(Suspension)
