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

return table.freeze(MapProjection)
