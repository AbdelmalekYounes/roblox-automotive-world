--!strict
--[[
    Conversion monde ↔ carte (lot 0.7), PURE.

    Monde en mètres (x est, z sud, nord = -z). Une vue : centre (m), échelle
    (pixels par mètre), rotation (cap en rad : la mini-carte tourne avec le
    véhicule pour que « devant » soit en haut) et taille (pixels). Le centre
    de la vue correspond au milieu du cadre. Utilisée par la mini-carte, la
    carte complète (clic → destination) et les tests.
]]

local MapProjection = {}

export type View = {
    CenterX: number,
    CenterZ: number,
    Scale: number, -- px par m
    Rotation: number, -- rad ; 0 = nord en haut
    Width: number,
    Height: number,
}

function MapProjection.view(
    centerX: number,
    centerZ: number,
    scale: number,
    rotation: number,
    width: number,
    height: number
): View
    return { CenterX = centerX, CenterZ = centerZ, Scale = scale, Rotation = rotation, Width = width, Height = height }
end

-- Monde (m) → pixels du cadre (u vers la droite, v vers le bas).
function MapProjection.toMap(view: View, x: number, z: number): (number, number)
    local dx, dz = x - view.CenterX, z - view.CenterZ
    -- Rotation de -cap : le cap du véhicule pointe vers le haut.
    local c, s = math.cos(-view.Rotation), math.sin(-view.Rotation)
    local rx = dx * c - dz * s
    local rz = dx * s + dz * c
    return view.Width / 2 + rx * view.Scale, view.Height / 2 + rz * view.Scale
end

-- Pixels du cadre → monde (m).
function MapProjection.toWorld(view: View, u: number, v: number): (number, number)
    local rx = (u - view.Width / 2) / view.Scale
    local rz = (v - view.Height / 2) / view.Scale
    local c, s = math.cos(view.Rotation), math.sin(view.Rotation)
    return view.CenterX + rx * c - rz * s, view.CenterZ + rx * s + rz * c
end

-- Rectangle du monde couvert par la vue (boîte englobante, toutes rotations).
function MapProjection.bounds(view: View): (number, number, number, number)
    local halfDiag = math.sqrt(view.Width ^ 2 + view.Height ^ 2) / 2 / view.Scale
    return view.CenterX - halfDiag, view.CenterZ - halfDiag, view.CenterX + halfDiag, view.CenterZ + halfDiag
end

-- Un point (pixels) est-il dans le cadre, avec une marge ?
function MapProjection.inside(view: View, u: number, v: number, margin: number?): boolean
    local m = margin or 0
    return u >= -m and v >= -m and u <= view.Width + m and v <= view.Height + m
end

-- Point ramené sur le bord du cadre (indicateur d'un objectif hors vue).
function MapProjection.clampToEdge(view: View, u: number, v: number, inset: number): (number, number)
    local cx, cy = view.Width / 2, view.Height / 2
    local dx, dy = u - cx, v - cy
    if dx == 0 and dy == 0 then
        return u, v
    end
    local hx, hy = cx - inset, cy - inset
    local factor = math.min(hx / math.max(math.abs(dx), 1e-6), hy / math.max(math.abs(dy), 1e-6), 1)
    return cx + dx * factor, cy + dy * factor
end

-- Lot UI V1.2 (retour du propriétaire : des routes dépassaient du cadre de la mini-carte) : rognage MATHÉMATIQUE des
-- segments, indépendant du masque graphique (un cadre qui rogne ses enfants ne rogne pas les éléments tournés).

-- Segment (pixels) rogné au rectangle de la vue agrandi de `margin` (Liang–Barsky) ; nil s'il est entièrement dehors.
function MapProjection.clipRect(
    view: View,
    u1: number,
    v1: number,
    u2: number,
    v2: number,
    margin: number?
): (number?, number?, number?, number?)
    local m = margin or 0
    local minU, minV, maxU, maxV = -m, -m, view.Width + m, view.Height + m
    local du, dv = u2 - u1, v2 - v1
    local t0, t1 = 0, 1
    for _, edge in { { -du, u1 - minU }, { du, maxU - u1 }, { -dv, v1 - minV }, { dv, maxV - v1 } } do
        local p, q = edge[1], edge[2]
        if p == 0 then
            if q < 0 then
                return nil, nil, nil, nil
            end
        else
            local r = q / p
            if p < 0 then
                if r > t1 then
                    return nil, nil, nil, nil
                end
                t0 = math.max(t0, r)
            else
                if r < t0 then
                    return nil, nil, nil, nil
                end
                t1 = math.min(t1, r)
            end
        end
    end
    return u1 + du * t0, v1 + dv * t0, u1 + du * t1, v1 + dv * t1
end

-- Segment (pixels) rogné au disque centré de la vue, de rayon `radius` ; nil s'il est entièrement dehors.
function MapProjection.clipCircle(
    view: View,
    u1: number,
    v1: number,
    u2: number,
    v2: number,
    radius: number
): (number?, number?, number?, number?)
    local cx, cy = view.Width / 2, view.Height / 2
    local fx, fy = u1 - cx, v1 - cy
    local du, dv = u2 - u1, v2 - v1
    local a = du * du + dv * dv
    local r2 = radius * radius
    if a < 1e-9 then
        if fx * fx + fy * fy <= r2 then
            return u1, v1, u2, v2
        end
        return nil, nil, nil, nil
    end
    local b = 2 * (fx * du + fy * dv)
    local c = fx * fx + fy * fy - r2
    local disc = b * b - 4 * a * c
    if disc < 0 then
        return nil, nil, nil, nil
    end
    local root = math.sqrt(disc)
    local ta, tb = (-b - root) / (2 * a), (-b + root) / (2 * a)
    local t0, t1 = math.max(0, ta), math.min(1, tb)
    if t0 > t1 then
        return nil, nil, nil, nil
    end
    return u1 + du * t0, v1 + dv * t0, u1 + du * t1, v1 + dv * t1
end

-- Point ramené sur le cercle intérieur de la vue (objectif hors de la mini-carte ronde).
function MapProjection.clampToCircle(view: View, u: number, v: number, inset: number): (number, number)
    local cx, cy = view.Width / 2, view.Height / 2
    local dx, dy = u - cx, v - cy
    local distance = math.sqrt(dx * dx + dy * dy)
    local radius = math.min(cx, cy) - inset
    if distance <= radius or distance < 1e-6 then
        return u, v
    end
    return cx + dx / distance * radius, cy + dy / distance * radius
end

return table.freeze(MapProjection)
