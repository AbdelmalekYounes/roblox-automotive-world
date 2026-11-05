--!strict
-- Géométrie plane PURE (aucune API Roblox) pour la carte : coordonnées en
-- mètres, x vers l'est, z vers le sud (convention Roblox : le nord est en -z).
-- Utilisée par la construction du réseau routier, le générateur hors ligne,
-- le trafic et les tests.

local Geometry = {}

export type Point = { X: number, Z: number }

function Geometry.point(x: number, z: number): Point
    return { X = x, Z = z }
end

function Geometry.distance(a: Point, b: Point): number
    local dx, dz = b.X - a.X, b.Z - a.Z
    return math.sqrt(dx * dx + dz * dz)
end

function Geometry.lerp(a: Point, b: Point, t: number): Point
    return { X = a.X + (b.X - a.X) * t, Z = a.Z + (b.Z - a.Z) * t }
end

-- Position d'un cap (degrés, 0 = nord, 90 = est) à une distance donnée.
function Geometry.fromBearing(bearingDeg: number, radius: number, center: Point?): Point
    local c = center or { X = 0, Z = 0 }
    local b = math.rad(bearingDeg)
    return { X = c.X + radius * math.sin(b), Z = c.Z - radius * math.cos(b) }
end

-- Produit vectoriel 2D (orientation) de (b - a) et (c - a).
local function cross(a: Point, b: Point, c: Point): number
    return (b.X - a.X) * (c.Z - a.Z) - (b.Z - a.Z) * (c.X - a.X)
end
Geometry.cross = cross

--[[
    Intersection stricte de deux segments [a, b] et [c, d] : retourne les
    paramètres (t, u) dans ]0 ; 1[ ou nil. Les contacts aux extrémités
    (carrefours partagés) ne comptent pas comme des croisements.
]]
function Geometry.segmentIntersection(a: Point, b: Point, c: Point, d: Point, epsilon: number?): (number?, number?)
    local eps = epsilon or 1e-6
    local rX, rZ = b.X - a.X, b.Z - a.Z
    local sX, sZ = d.X - c.X, d.Z - c.Z
    local denominator = rX * sZ - rZ * sX
    if math.abs(denominator) < 1e-12 then
        return nil, nil
    end
    local qX, qZ = c.X - a.X, c.Z - a.Z
    local t = (qX * sZ - qZ * sX) / denominator
    local u = (qX * rZ - qZ * rX) / denominator
    if t > eps and t < 1 - eps and u > eps and u < 1 - eps then
        return t, u
    end
    return nil, nil
end

-- Distance d'un point à un segment.
function Geometry.pointSegmentDistance(p: Point, a: Point, b: Point): (number, number)
    local dx, dz = b.X - a.X, b.Z - a.Z
    local lengthSquared = dx * dx + dz * dz
    local t = 0
    if lengthSquared > 0 then
        t = math.clamp(((p.X - a.X) * dx + (p.Z - a.Z) * dz) / lengthSquared, 0, 1)
    end
    local qx, qz = a.X + dx * t, a.Z + dz * t
    return math.sqrt((p.X - qx) ^ 2 + (p.Z - qz) ^ 2), t
end

-- Point dans un polygone (règle pair-impair).
function Geometry.pointInPolygon(p: Point, polygon: { Point }): boolean
    local inside = false
    local count = #polygon
    local j = count
    for i = 1, count do
        local a, b = polygon[i], polygon[j]
        if (a.Z > p.Z) ~= (b.Z > p.Z) then
            local x = (b.X - a.X) * (p.Z - a.Z) / (b.Z - a.Z) + a.X
            if p.X < x then
                inside = not inside
            end
        end
        j = i
    end
    return inside
end

-- Vrai si le polygone (sommets dans l'ordre) est convexe.
function Geometry.isConvex(polygon: { Point }): boolean
    local count = #polygon
    local sign = 0
    for i = 1, count do
        local c = cross(polygon[i], polygon[i % count + 1], polygon[(i + 1) % count + 1])
        if math.abs(c) > 1e-9 then
            local s = math.sign(c)
            if sign == 0 then
                sign = s
            elseif s ~= sign then
                return false
            end
        end
    end
    return true
end

--[[
    Coupe la droite { origin + s · direction } par un polygone CONVEXE.
    Retourne (sEntrée, sSortie, indexArêteEntrée, indexArêteSortie, tEntrée,
    tSortie) où l'arête i va du sommet i au sommet i + 1 et t est la position
    sur cette arête, ou nil si la droite ne traverse pas le polygone.
]]
function Geometry.clipLineConvex(
    origin: Point,
    direction: Point,
    polygon: { Point }
): (number?, number?, number?, number?, number?, number?)
    local hits = {}
    local count = #polygon
    for i = 1, count do
        local a, b = polygon[i], polygon[i % count + 1]
        local eX, eZ = b.X - a.X, b.Z - a.Z
        local denominator = direction.X * eZ - direction.Z * eX
        if math.abs(denominator) > 1e-12 then
            local qX, qZ = a.X - origin.X, a.Z - origin.Z
            local s = (qX * eZ - qZ * eX) / denominator
            local t = (qX * direction.Z - qZ * direction.X) / denominator
            if t >= 0 and t <= 1 then
                table.insert(hits, { S = s, Edge = i, T = t })
            end
        end
    end
    if #hits < 2 then
        return nil
    end
    table.sort(hits, function(p, q)
        return p.S < q.S
    end)
    local first, last = hits[1], hits[#hits]
    if last.S - first.S < 1e-6 then
        return nil
    end
    return first.S, last.S, first.Edge, last.Edge, first.T, last.T
end

--[[
    Coupe un polygone CONVEXE par le demi-plan { p : p · normal >= offset }
    (Sutherland-Hodgman). Retourne le polygone résultant (éventuellement vide).
]]
function Geometry.clipHalfPlane(polygon: { Point }, normal: Point, offset: number): { Point }
    local result: { Point } = {}
    local count = #polygon
    for i = 1, count do
        local a, b = polygon[i], polygon[i % count + 1]
        local da = a.X * normal.X + a.Z * normal.Z - offset
        local db = b.X * normal.X + b.Z * normal.Z - offset
        if da >= 0 then
            table.insert(result, a)
        end
        if (da >= 0) ~= (db >= 0) then
            local t = da / (da - db)
            table.insert(result, { X = a.X + (b.X - a.X) * t, Z = a.Z + (b.Z - a.Z) * t })
        end
    end
    return result
end

-- Aire (valeur absolue) d'un polygone.
function Geometry.polygonArea(polygon: { Point }): number
    local area = 0
    local count = #polygon
    for i = 1, count do
        local a, b = polygon[i], polygon[i % count + 1]
        area += a.X * b.Z - b.X * a.Z
    end
    return math.abs(area) / 2
end

-- Longueur d'une polyligne.
function Geometry.polylineLength(points: { Point }): number
    local total = 0
    for i = 2, #points do
        total += Geometry.distance(points[i - 1], points[i])
    end
    return total
end

--[[
    Lissage d'un tracé par spline de Catmull-Rom centripète passant par les
    points de contrôle ; échantillonné tous les `step` mètres environ. Les
    extrémités sont conservées exactement (raccord aux carrefours).
    Les points peuvent porter une altitude Y, interpolée linéairement.
]]
export type Point3 = { X: number, Z: number, Y: number }

function Geometry.smooth(control: { Point3 }, step: number): { Point3 }
    local count = #control
    if count <= 2 then
        return table.clone(control)
    end
    local result: { Point3 } = { control[1] }
    for i = 1, count - 1 do
        local segmentStart = #result
        local p0 = control[math.max(i - 1, 1)]
        local p1 = control[i]
        local p2 = control[i + 1]
        local p3 = control[math.min(i + 2, count)]
        local length = math.sqrt((p2.X - p1.X) ^ 2 + (p2.Z - p1.Z) ^ 2)
        local samples = math.max(1, math.ceil(length / step))
        for k = 1, samples do
            local t = k / samples
            local t2, t3 = t * t, t * t * t
            local function blend(a: number, b: number, c: number, d: number): number
                return 0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
            end
            table.insert(result, {
                X = blend(p0.X, p1.X, p2.X, p3.X),
                Z = blend(p0.Z, p1.Z, p2.Z, p3.Z),
                Y = p1.Y,
            })
        end
        -- Altitude au prorata de la distance parcourue sur ce segment (et non
        -- du paramètre de la spline, dont la vitesse varie dans les virages).
        local total = 0
        for k = segmentStart + 1, #result do
            total += Geometry.distance(result[k - 1], result[k])
        end
        local travelled = 0
        for k = segmentStart + 1, #result do
            travelled += Geometry.distance(result[k - 1], result[k])
            result[k].Y = p1.Y + (p2.Y - p1.Y) * (if total > 0 then travelled / total else 1)
        end
    end
    result[#result] = control[count]
    return result
end

-- Générateur pseudo-aléatoire DÉTERMINISTE (même graine → même carte).
export type Random = { State: number }

function Geometry.random(seed: number): Random
    return { State = (math.floor(seed) % 2147483646) + 1 }
end

-- Valeur dans [0 ; 1[ (générateur de Park-Miller, reproductible partout).
function Geometry.nextRandom(random: Random): number
    random.State = (random.State * 48271) % 2147483647
    return (random.State - 1) / 2147483646
end

function Geometry.randomRange(random: Random, low: number, high: number): number
    return low + (high - low) * Geometry.nextRandom(random)
end

return table.freeze(Geometry)
