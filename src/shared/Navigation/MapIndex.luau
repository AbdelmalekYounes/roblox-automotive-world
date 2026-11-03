--!strict
--[[
    Index de dessin et de recherche des routes (lot 0.7), PUR.

    À partir des tronçons du graphe routier (WorldLayout, lot 0.3) :
    - polylignes SIMPLIFIÉES (un point tous les ≥ 20 m ou à chaque changement
      de direction marqué) : la carte ne dessine jamais des milliers de
      points à chaque image ;
    - grille spatiale (cellules de 200 m) : la mini-carte ne parcourt que les
      cellules visibles ;
    - importance par classe de route (autoroute → chemin) : la carte complète
      n'affiche les petites rues qu'à fort zoom ;
    - tronçon le plus proche d'une position (départ d'un itinéraire),
      éventuellement filtré par un profil de véhicule.
]]

local World = script.Parent.Parent.World
local WorldConfig = require(World.WorldConfig)

local MapIndex = {}

MapIndex.CellM = 200
MapIndex.MinStepM = 20
MapIndex.TurnDeg = 12

export type Segment = {
    AX: number,
    AZ: number,
    BX: number,
    BZ: number,
    EdgeId: string,
    Class: string,
    Importance: number, -- 1 (petite rue) à 6 (autoroute)
}

export type Index = {
    Segments: { Segment },
    Cells: { [string]: { number } },
    Edges: { [string]: any },
    PointCount: number, -- points des tracés d'origine
}

local function cellKey(cx: number, cz: number): string
    return cx .. ":" .. cz
end

-- Simplification : garde les extrémités, les virages marqués et un point tous les MinStepM.
function MapIndex.simplify(points: { { X: number, Z: number } }): { { X: number, Z: number } }
    local count = #points
    if count <= 2 then
        return points
    end
    local out = { points[1] }
    local last = points[1]
    for i = 2, count - 1 do
        local p, n = points[i], points[i + 1]
        local d = math.sqrt((p.X - last.X) ^ 2 + (p.Z - last.Z) ^ 2)
        local h1 = math.atan2(p.X - last.X, -(p.Z - last.Z))
        local h2 = math.atan2(n.X - p.X, -(n.Z - p.Z))
        local turn = math.abs(((h2 - h1 + math.pi) % (2 * math.pi)) - math.pi)
        if d >= MapIndex.MinStepM or (d >= 4 and math.deg(turn) >= MapIndex.TurnDeg) then
            table.insert(out, p)
            last = p
        end
    end
    table.insert(out, points[count])
    return out
end

function MapIndex.build(layout: any): Index
    local index: Index = { Segments = {}, Cells = {}, Edges = {}, PointCount = 0 }
    local size = MapIndex.CellM
    for _, edge in layout.Edges do
        index.Edges[edge.Id] = edge
        index.PointCount += #edge.Polyline
        local roadClass = WorldConfig.RoadClasses[edge.Class]
        local importance = math.clamp(roadClass.Rank, 1, 6)
        local points = MapIndex.simplify(edge.Polyline)
        for i = 2, #points do
            local a, b = points[i - 1], points[i]
            local segment: Segment = {
                AX = a.X,
                AZ = a.Z,
                BX = b.X,
                BZ = b.Z,
                EdgeId = edge.Id,
                Class = edge.Class,
                Importance = importance,
            }
            table.insert(index.Segments, segment)
            local id = #index.Segments
            -- Inscrit dans chaque cellule couverte par la boîte du segment.
            local minX, maxX = math.min(a.X, b.X), math.max(a.X, b.X)
            local minZ, maxZ = math.min(a.Z, b.Z), math.max(a.Z, b.Z)
            for cx = math.floor(minX / size), math.floor(maxX / size) do
                for cz = math.floor(minZ / size), math.floor(maxZ / size) do
                    local key = cellKey(cx, cz)
                    local cell = index.Cells[key]
                    if cell == nil then
                        cell = {}
                        index.Cells[key] = cell
                    end
                    table.insert(cell, id)
                end
            end
        end
    end
    return index
end

-- Segments dans un rectangle (m), d'importance au moins `minImportance`.
function MapIndex.query(
    index: Index,
    minX: number,
    minZ: number,
    maxX: number,
    maxZ: number,
    minImportance: number?
): { Segment }
    local size = MapIndex.CellM
    local seen: { [number]: boolean } = {}
    local list: { Segment } = {}
    local floor = minImportance or 1
    for cx = math.floor(minX / size), math.floor(maxX / size) do
        for cz = math.floor(minZ / size), math.floor(maxZ / size) do
            local cell: { number } = index.Cells[cellKey(cx, cz)] or {}
            for _, id in cell do
                if not seen[id] then
                    seen[id] = true
                    local segment = index.Segments[id]
                    if segment.Importance >= floor then
                        table.insert(list, segment)
                    end
                end
            end
        end
    end
    return list
end

--[[
    Tronçon le plus proche (dans `radius` m) accepté par `allow(classe)`.
    Renvoie (identifiant, distance, point projeté) ou nil.
]]
function MapIndex.nearestEdge(
    index: Index,
    x: number,
    z: number,
    radius: number,
    allow: ((string) -> boolean)?
): (string?, number, { X: number, Z: number }?)
    local best: string? = nil
    local bestDistance = math.huge
    local bestPoint: { X: number, Z: number }? = nil
    for _, segment in MapIndex.query(index, x - radius, z - radius, x + radius, z + radius) do
        if allow == nil or allow(segment.Class) then
            local abx, abz = segment.BX - segment.AX, segment.BZ - segment.AZ
            local len2 = abx * abx + abz * abz
            local t = if len2 > 0 then math.clamp(((x - segment.AX) * abx + (z - segment.AZ) * abz) / len2, 0, 1) else 0
            local px, pz = segment.AX + abx * t, segment.AZ + abz * t
            local d = math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
            if d < bestDistance then
                best, bestDistance, bestPoint = segment.EdgeId, d, { X = px, Z = pz }
            end
        end
    end
    if bestDistance > radius then
        return nil, math.huge, nil
    end
    return best, bestDistance, bestPoint
end

-- Importance minimale affichée selon l'échelle (mètres couverts par la vue).
function MapIndex.minImportanceFor(viewSpanM: number): number
    if viewSpanM > 6000 then
        return 4
    elseif viewSpanM > 2500 then
        return 3
    elseif viewSpanM > 1200 then
        return 2
    end
    return 1
end

return table.freeze(MapIndex)
