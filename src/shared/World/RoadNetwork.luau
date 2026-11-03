--!strict
-- Construction PURE et DÉTERMINISTE du réseau routier à partir des données de
-- carte versionnées (World/Data) : mêmes données → même graphe, mêmes
-- identifiants, partout (générateur hors ligne, serveur, tests).
--
-- 1. Carrefours et routes dessinés (axes, montagne, littoral, pistes).
-- 2. Quartiers : chaque quartier est un polygone borné par des routes
--    dessinées ; un quadrillage IRRÉGULIER (orientation, pas et graine propres
--    au quartier) y est découpé ; chaque rue qui atteint le bord crée un
--    carrefour en T inséré dans la route de bord (qui est alors scindée).
-- 3. Résultat : nœuds, tronçons (polylignes 3D de contrôle), îlots.
-- Identifiants stables : routes dessinées par leur identifiant de données
-- (tronçons scindés : « <id>.<n> »), rues générées « Q:<quartier>:<famille><i>:<k> ».

local Geometry = require(script.Parent.Geometry)
local WorldConfig = require(script.Parent.WorldConfig)

local RoadNetwork = {}

export type Control = "None" | "Signals" | "Yield" | "Merge" | "Roundabout"

export type Node = {
    Id: string,
    X: number,
    Z: number,
    Y: number,
    Control: Control,
    Name: string?,
}

export type Edge = {
    Id: string,
    From: string,
    To: string,
    Class: string,
    Name: string?,
    -- Points de contrôle 3D (extrémités comprises), en mètres.
    Points: { Geometry.Point3 },
    -- Route dessinée d'origine et intervalle couvert (après scission).
    Origin: string,
    OriginRange: { number },
    District: string?,
    Bridge: boolean,
}

export type Cell = {
    District: string,
    Kind: string,
    -- Contour de l'îlot (polygone convexe, mètres), dans l'ordre.
    Corners: { Geometry.Point },
    -- Orientation du quadrillage du quartier (degrés), pour aligner les bâtiments.
    Rotation: number,
    Park: boolean,
    Seed: number,
}

export type Network = {
    Version: string,
    Nodes: { Node },
    NodeById: { [string]: Node },
    Edges: { Edge },
    EdgeById: { [string]: Edge },
    Cells: { Cell },
    Warnings: { string },
}

-- Données d'entrée (voir World/Data/MapData).
export type NodeData = { Id: string, X: number, Z: number, Y: number?, Control: Control?, Name: string? }
export type RoadData = {
    Id: string,
    Class: string,
    From: string,
    To: string,
    Via: { { number } }?, -- { x, z, y? }
    Name: string?,
    Bridge: boolean?,
}
export type DistrictData = {
    Id: string,
    Kind: string,
    Boundary: { string },
    Rotation: number, -- degrés
    BlockMin: number,
    BlockMax: number,
    StreetClass: string,
    Seed: number,
    ParkChance: number,
}
export type MapData = {
    Version: string,
    Nodes: { NodeData },
    Roads: { RoadData },
    Districts: { DistrictData },
}

-- Distance minimale (m) entre un carrefour en T et un autre carrefour du même bord.
local MIN_T_SPACING = 30
-- Longueur minimale d'un tronçon de rue généré.
local MIN_SEGMENT = 20

local function point3(x: number, z: number, y: number?): Geometry.Point3
    return { X = x, Z = z, Y = y or 0 }
end

local function edgeKey(a: string, b: string): string
    return if a < b then a .. "|" .. b else b .. "|" .. a
end

function RoadNetwork.build(data: MapData): Network
    local warnings: { string } = {}
    local nodes: { Node } = {}
    local nodeById: { [string]: Node } = {}
    local function addNode(node: Node)
        assert(nodeById[node.Id] == nil, "Identifiant de carrefour dupliqué : " .. node.Id)
        table.insert(nodes, node)
        nodeById[node.Id] = node
    end
    for _, n in data.Nodes do
        addNode({ Id = n.Id, X = n.X, Z = n.Z, Y = n.Y or 0, Control = n.Control or "None", Name = n.Name })
    end

    -- Routes dessinées.
    type Draft = {
        Data: RoadData,
        Points: { Geometry.Point3 },
        Splits: { { T: number, Node: string } },
    }
    local drafts: { Draft } = {}
    local draftByPair: { [string]: Draft } = {}
    for _, road in data.Roads do
        assert(WorldConfig.RoadClasses[road.Class], "Classe de route inconnue : " .. road.Class)
        local from = assert(nodeById[road.From], "Carrefour inconnu : " .. road.From .. " (" .. road.Id .. ")")
        local to = assert(nodeById[road.To], "Carrefour inconnu : " .. road.To .. " (" .. road.Id .. ")")
        local points = { point3(from.X, from.Z, from.Y) }
        local vias: { { number } } = road.Via or {}
        for _, via in vias do
            table.insert(points, point3(via[1], via[2], via[3]))
        end
        table.insert(points, point3(to.X, to.Z, to.Y))
        local draft: Draft = { Data = road, Points = points, Splits = {} }
        table.insert(drafts, draft)
        if road.Via == nil or #road.Via == 0 then
            draftByPair[edgeKey(road.From, road.To)] = draft
        end
    end

    -- Quartiers : quadrillage découpé dans le polygone de bord.
    local generated: { Edge } = {}
    local cells: { Cell } = {}
    for _, district in data.Districts do
        local polygon: { Geometry.Point } = {}
        local boundary: { Draft } = {}
        -- Vrai si la route de bord est orientée à l'inverse de l'arête du polygone :
        -- les positions t calculées sur l'arête doivent alors être inversées.
        local reversed: { boolean } = {}
        local count = #district.Boundary
        for i, id in district.Boundary do
            local node = assert(nodeById[id], "Bord de quartier inconnu : " .. id .. " (" .. district.Id .. ")")
            table.insert(polygon, { X = node.X, Z = node.Z })
            local nextId = district.Boundary[i % count + 1]
            local draft = draftByPair[edgeKey(id, nextId)]
            assert(draft, "Quartier " .. district.Id .. " : pas de route droite entre " .. id .. " et " .. nextId)
            boundary[i] = draft
            reversed[i] = draft.Data.From ~= id
        end

        local random = Geometry.random(district.Seed)
        local angle = math.rad(district.Rotation)
        local axes = {
            { X = math.cos(angle), Z = math.sin(angle) },
            { X = -math.sin(angle), Z = math.cos(angle) },
        }

        -- Lignes de chaque famille : direction = axe, positions sur la normale.
        type Line = {
            Family: number,
            Index: number,
            Origin: Geometry.Point,
            Direction: Geometry.Point,
            Offset: number,
            S0: number,
            S1: number,
            EdgeIn: number,
            EdgeOut: number,
            TIn: number,
            TOut: number,
        }
        local families: { { Line } } = { {}, {} }
        for family = 1, 2 do
            local direction = axes[family]
            local normal = axes[3 - family]
            local low, high = math.huge, -math.huge
            for _, p in polygon do
                local d = p.X * normal.X + p.Z * normal.Z
                low = math.min(low, d)
                high = math.max(high, d)
            end
            local position = low + Geometry.randomRange(random, district.BlockMin * 0.5, district.BlockMax)
            local index = 0
            while position < high - district.BlockMin * 0.5 do
                index += 1
                local origin = { X = normal.X * position, Z = normal.Z * position }
                local s0, s1, edgeIn, edgeOut, tIn, tOut = Geometry.clipLineConvex(origin, direction, polygon)
                if s0 and s1 and edgeIn and edgeOut and tIn and tOut then
                    table.insert(families[family], {
                        Family = family,
                        Index = index,
                        Origin = origin,
                        Direction = direction,
                        Offset = position,
                        S0 = s0,
                        S1 = s1,
                        EdgeIn = edgeIn,
                        EdgeOut = edgeOut,
                        TIn = tIn,
                        TOut = tOut,
                    })
                end
                position += Geometry.randomRange(random, district.BlockMin, district.BlockMax)
            end
        end

        -- Carrefours en T acceptés par bord (positions t sur le bord).
        local tByBoundary: { { number } } = {}
        for i = 1, count do
            tByBoundary[i] = {}
        end
        local function roadT(edgeIndex: number, t: number): number
            return if reversed[edgeIndex] then 1 - t else t
        end
        local function endpointOk(edgeIndex: number, polygonT: number): boolean
            local draft = boundary[edgeIndex]
            local t = roadT(edgeIndex, polygonT)
            local length = Geometry.distance(draft.Points[1], draft.Points[#draft.Points])
            if t * length < MIN_T_SPACING or (1 - t) * length < MIN_T_SPACING then
                return false
            end
            -- Points déjà posés sur cette route (ce quartier ou un voisin).
            for _, split in draft.Splits do
                if math.abs(split.T - t) * length < MIN_T_SPACING then
                    return false
                end
            end
            for _, other in tByBoundary[edgeIndex] do
                if math.abs(other - t) * length < MIN_T_SPACING then
                    return false
                end
            end
            return true
        end

        local function at(line: Line, s: number): Geometry.Point
            return { X = line.Origin.X + line.Direction.X * s, Z = line.Origin.Z + line.Direction.Z * s }
        end

        -- Croisements entre familles (toutes les lignes candidates).
        type Stop = { S: number, Node: string }
        local stops: { [Line]: { Stop } } = {}
        local all: { Line } = {}
        local streetCorridor = WorldConfig.corridorWidthM(WorldConfig.RoadClasses[district.StreetClass])
        -- Une rue ne doit pas longer une route de bord à moins de la somme des
        -- demi-emprises (plus une marge) : sinon les chaussées se chevauchent.
        local function tooClose(line: Line): boolean
            local a, b = at(line, line.S0), at(line, line.S1)
            for i = 1, count do
                if i ~= line.EdgeIn and i ~= line.EdgeOut then
                    local p, q = polygon[i], polygon[i % count + 1]
                    local edgeCorridor = WorldConfig.corridorWidthM(WorldConfig.RoadClasses[boundary[i].Data.Class])
                    local clearance = (streetCorridor + edgeCorridor) / 2 + 6
                    local d = math.min(
                        Geometry.pointSegmentDistance(a, p, q),
                        Geometry.pointSegmentDistance(b, p, q),
                        Geometry.pointSegmentDistance(p, a, b),
                        -- Parenthèses : ne garder que la distance (la fonction renvoie aussi t).
                        (Geometry.pointSegmentDistance(q, a, b))
                    )
                    if d < clearance then
                        return true
                    end
                end
            end
            return false
        end
        for family = 1, 2 do
            for _, line in families[family] do
                if line.S1 - line.S0 >= MIN_SEGMENT * 2 and not tooClose(line) then
                    table.insert(all, line)
                    stops[line] = {}
                end
            end
        end
        for _, a in all do
            if a.Family ~= 1 then
                continue
            end
            for _, b in all do
                if b.Family ~= 2 then
                    continue
                end
                -- Familles orthogonales : le croisement est la somme des origines.
                local p = { X = a.Origin.X + b.Origin.X, Z = a.Origin.Z + b.Origin.Z }
                local sa = (p.X - a.Origin.X) * a.Direction.X + (p.Z - a.Origin.Z) * a.Direction.Z
                local sb = (p.X - b.Origin.X) * b.Direction.X + (p.Z - b.Origin.Z) * b.Direction.Z
                if sa > a.S0 + 0.5 and sa < a.S1 - 0.5 and sb > b.S0 + 0.5 and sb < b.S1 - 0.5 then
                    local id = string.format("X:%s:%d:%d", district.Id, a.Index, b.Index)
                    addNode({ Id = id, X = p.X, Z = p.Z, Y = 0, Control = "Yield", Name = nil })
                    table.insert(stops[a], { S = sa, Node = id })
                    table.insert(stops[b], { S = sb, Node = id })
                end
            end
        end

        -- Extrémités : carrefour en T sur le bord si l'emplacement est libre ;
        -- sinon la rue s'arrête au dernier croisement (pas de rue en impasse
        -- collée à un autre carrefour).
        local familyLetter = { "A", "B" }
        for _, line in all do
            local list = stops[line]
            table.sort(list, function(p, q)
                return p.S < q.S
            end)
            local letter = familyLetter[line.Family]
            local firstGap = if #list > 0 then list[1].S - line.S0 else math.huge
            local lastGap = if #list > 0 then line.S1 - list[#list].S else math.huge
            if firstGap >= MIN_SEGMENT and endpointOk(line.EdgeIn, line.TIn) then
                local id = string.format("T:%s:%s%d:a", district.Id, letter, line.Index)
                local point = at(line, line.S0)
                addNode({ Id = id, X = point.X, Z = point.Z, Y = 0, Control = "Yield", Name = nil })
                table.insert(boundary[line.EdgeIn].Splits, { T = roadT(line.EdgeIn, line.TIn), Node = id })
                table.insert(tByBoundary[line.EdgeIn], roadT(line.EdgeIn, line.TIn))
                table.insert(list, 1, { S = line.S0, Node = id })
            end
            if lastGap >= MIN_SEGMENT and endpointOk(line.EdgeOut, line.TOut) then
                local id = string.format("T:%s:%s%d:b", district.Id, letter, line.Index)
                local point = at(line, line.S1)
                addNode({ Id = id, X = point.X, Z = point.Z, Y = 0, Control = "Yield", Name = nil })
                table.insert(boundary[line.EdgeOut].Splits, { T = roadT(line.EdgeOut, line.TOut), Node = id })
                table.insert(tByBoundary[line.EdgeOut], roadT(line.EdgeOut, line.TOut))
                table.insert(list, { S = line.S1, Node = id })
            end
            for k = 2, #list do
                local a, b = nodeById[list[k - 1].Node], nodeById[list[k].Node]
                if list[k].S - list[k - 1].S < MIN_SEGMENT then
                    table.insert(
                        warnings,
                        string.format("Tronçon court (%.1f m) dans %s", list[k].S - list[k - 1].S, district.Id)
                    )
                end
                local id = string.format("Q:%s:%s%d:%d", district.Id, letter, line.Index, k - 1)
                table.insert(generated, {
                    Id = id,
                    From = a.Id,
                    To = b.Id,
                    Class = district.StreetClass,
                    Name = nil,
                    Points = { point3(a.X, a.Z, 0), point3(b.X, b.Z, 0) },
                    Origin = id,
                    OriginRange = { 0, 1 },
                    District = district.Id,
                    Bridge = false,
                })
            end
        end

        -- Îlots : bandes entre lignes consécutives de chaque famille, découpées
        -- dans le polygone du quartier (couverture jusqu'aux routes de bord).
        local bounds: { { number } } = { { -1e7 }, { -1e7 } }
        for family = 1, 2 do
            for _, line in families[family] do
                table.insert(bounds[family], line.Offset)
            end
            table.insert(bounds[family], 1e7)
        end
        for i = 1, #bounds[1] - 1 do
            for j = 1, #bounds[2] - 1 do
                -- Famille 1 : positions sur axes[2] ; famille 2 : sur axes[1].
                local block = polygon
                local n1, n2 = axes[2], axes[1]
                block = Geometry.clipHalfPlane(block, n1, bounds[1][i])
                block = Geometry.clipHalfPlane(block, { X = -n1.X, Z = -n1.Z }, -bounds[1][i + 1])
                block = Geometry.clipHalfPlane(block, n2, bounds[2][j])
                block = Geometry.clipHalfPlane(block, { X = -n2.X, Z = -n2.Z }, -bounds[2][j + 1])
                if #block >= 3 and Geometry.polygonArea(block) > district.BlockMin * district.BlockMin * 0.25 then
                    table.insert(cells, {
                        District = district.Id,
                        Kind = district.Kind,
                        Corners = block,
                        Rotation = district.Rotation,
                        Park = Geometry.nextRandom(random) < district.ParkChance,
                        Seed = math.floor(Geometry.nextRandom(random) * 1e6),
                    })
                end
            end
        end
    end

    -- Tronçons définitifs : routes dessinées scindées aux carrefours en T.
    local edges: { Edge } = {}
    local edgeById: { [string]: Edge } = {}
    local function addEdge(edge: Edge)
        assert(edgeById[edge.Id] == nil, "Identifiant de tronçon dupliqué : " .. edge.Id)
        table.insert(edges, edge)
        edgeById[edge.Id] = edge
    end
    for _, draft in drafts do
        local road = draft.Data
        if #draft.Splits == 0 then
            addEdge({
                Id = road.Id,
                From = road.From,
                To = road.To,
                Class = road.Class,
                Name = road.Name,
                Points = draft.Points,
                Origin = road.Id,
                OriginRange = { 0, 1 },
                District = nil,
                Bridge = road.Bridge == true,
            })
            continue
        end
        -- Seules les routes droites (sans points intermédiaires) servent de bord.
        table.sort(draft.Splits, function(p, q)
            return p.T < q.T
        end)
        local a, b = draft.Points[1], draft.Points[#draft.Points]
        local previousNode, previousT = road.From, 0
        local pieces = table.clone(draft.Splits)
        table.insert(pieces, { T = 1, Node = road.To })
        for k, split in pieces do
            local p0 = {
                X = a.X + (b.X - a.X) * previousT,
                Z = a.Z + (b.Z - a.Z) * previousT,
                Y = a.Y + (b.Y - a.Y) * previousT,
            }
            local p1 =
                { X = a.X + (b.X - a.X) * split.T, Z = a.Z + (b.Z - a.Z) * split.T, Y = a.Y + (b.Y - a.Y) * split.T }
            -- Le carrefour en T prend l'altitude de la route de bord.
            nodeById[split.Node].Y = p1.Y
            addEdge({
                Id = road.Id .. "." .. k,
                From = previousNode,
                To = split.Node,
                Class = road.Class,
                Name = road.Name,
                Points = { p0, p1 },
                Origin = road.Id,
                OriginRange = { previousT, split.T },
                District = nil,
                Bridge = road.Bridge == true,
            })
            previousNode, previousT = split.Node, split.T
        end
    end
    for _, edge in generated do
        addEdge(edge)
    end

    return {
        Version = data.Version,
        Nodes = nodes,
        NodeById = nodeById,
        Edges = edges,
        EdgeById = edgeById,
        Cells = cells,
        Warnings = warnings,
    }
end

return table.freeze(RoadNetwork)
