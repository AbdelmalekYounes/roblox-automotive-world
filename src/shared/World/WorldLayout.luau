--!strict
-- Mise en page PURE et DÉTERMINISTE du monde ouvert : réseau routier, tracés
-- lissés, zones, infrastructures placées. Construite une fois (mise en cache)
-- à partir des données versionnées ; utilisée par le générateur hors ligne, le
-- serveur (apparitions, trafic), le client (piétons) et les tests.

local Geometry = require(script.Parent.Geometry)
local WorldConfig = require(script.Parent.WorldConfig)
local RoadNetwork = require(script.Parent.RoadNetwork)
local MapData = require(script.Parent.Data.MapData)
local ZoneData = require(script.Parent.Data.Zones)
local Infrastructure = require(script.Parent.Data.Infrastructure)

local WorldLayout = {}

-- Pas d'échantillonnage des tracés courbes (m).
local CURVE_STEP = 12

export type EdgeLayout = {
    Id: string,
    From: string,
    To: string,
    Class: string,
    Name: string?,
    Zone: string,
    Polyline: { Geometry.Point3 },
    LengthM: number,
    WidthM: number, -- chaussée
    CorridorM: number, -- chaussée + trottoirs
}

export type Placement = {
    Id: string,
    Kind: string,
    Zone: string,
    DeclaredZone: string,
    Name: string,
    Center: Geometry.Point3,
    -- Direction vers laquelle l'entrée fait face (vers la route), vecteur unitaire.
    Facing: Geometry.Point,
    Width: number,
    Depth: number,
    Corners: { Geometry.Point },
    Chargers: number,
    Pumps: number,
    Stalls: number,
    Road: string?,
}

export type Layout = {
    Version: string,
    Network: RoadNetwork.Network,
    Edges: { EdgeLayout },
    EdgeById: { [string]: EdgeLayout },
    Placements: { Placement },
    PlacementById: { [string]: Placement },
    ZoneOf: (x: number, z: number) -> string,
    -- Tracé lissé complet d'une route dessinée (avant scission).
    OriginPolyline: { [string]: { Geometry.Point3 } },
}

local function zoneOf(x: number, z: number): string
    local point = { X = x, Z = z }
    for _, id in ZoneData.Lookup do
        if Geometry.pointInPolygon(point, (ZoneData.Zones :: any)[id].Polygon) then
            return id
        end
    end
    return "Banlieues"
end
WorldLayout.zoneOf = zoneOf

-- Point et tangente à la fraction `t` de la longueur d'une polyligne.
local function sampleAt(polyline: { Geometry.Point3 }, t: number): (Geometry.Point3, Geometry.Point)
    local total = 0
    local lengths = {}
    for i = 2, #polyline do
        local d = Geometry.distance(polyline[i - 1], polyline[i])
        lengths[i] = d
        total += d
    end
    local target = math.clamp(t, 0, 1) * total
    for i = 2, #polyline do
        local d = lengths[i]
        if target <= d or i == #polyline then
            local a, b = polyline[i - 1], polyline[i]
            local f = if d > 0 then math.clamp(target / d, 0, 1) else 0
            local tangent = if d > 0 then { X = (b.X - a.X) / d, Z = (b.Z - a.Z) / d } else { X = 0, Z = -1 }
            return { X = a.X + (b.X - a.X) * f, Z = a.Z + (b.Z - a.Z) * f, Y = a.Y + (b.Y - a.Y) * f }, tangent
        end
        target -= d
    end
    return polyline[#polyline], { X = 0, Z = -1 }
end
WorldLayout.sampleAt = sampleAt

local cached: Layout? = nil

function WorldLayout.get(): Layout
    if cached then
        return cached
    end
    -- Les données sont typées dans leur module ; le constructeur revalide tout.
    local network = RoadNetwork.build(MapData :: any)

    -- Tracés lissés des routes dessinées (avant scission).
    local originPolyline: { [string]: { Geometry.Point3 } } = {}
    for _, road in MapData.Roads do
        local from = network.NodeById[road.From]
        local to = network.NodeById[road.To]
        local control = { { X = from.X, Z = from.Z, Y = from.Y } }
        local vias: { { number } } = road.Via or {}
        for _, via in vias do
            table.insert(control, { X = via[1], Z = via[2], Y = via[3] or 0 })
        end
        table.insert(control, { X = to.X, Z = to.Z, Y = to.Y })
        originPolyline[road.Id] = if #control > 2 then Geometry.smooth(control, CURVE_STEP) else control
    end

    local edges: { EdgeLayout } = {}
    local edgeById: { [string]: EdgeLayout } = {}
    for _, edge in network.Edges do
        -- Tronçon entier d'une route dessinée : tracé lissé ; tronçon scindé (route
        -- droite) ou rue générée : segment exact.
        local origin = originPolyline[edge.Origin]
        local whole = origin ~= nil and edge.OriginRange[1] == 0 and edge.OriginRange[2] == 1
        local polyline: { Geometry.Point3 } = if whole then origin else edge.Points
        local roadClass = WorldConfig.RoadClasses[edge.Class]
        local mid = sampleAt(polyline, 0.5)
        local layout: EdgeLayout = {
            Id = edge.Id,
            From = edge.From,
            To = edge.To,
            Class = edge.Class,
            Name = edge.Name,
            Zone = zoneOf(mid.X, mid.Z),
            Polyline = polyline,
            LengthM = Geometry.polylineLength(polyline :: any),
            WidthM = WorldConfig.carriagewayWidthM(roadClass),
            CorridorM = WorldConfig.corridorWidthM(roadClass),
        }
        table.insert(edges, layout)
        edgeById[edge.Id] = layout
    end

    -- Infrastructures : face à la route, au-delà de son emprise.
    local roadClassOf: { [string]: string } = {}
    for _, road in MapData.Roads do
        roadClassOf[road.Id] = road.Class
    end
    local placements: { Placement } = {}
    local placementById: { [string]: Placement } = {}
    for _, item in Infrastructure do
        local center: Geometry.Point3
        local facing: Geometry.Point
        if item.At then
            local heading = math.rad(item.At[3] or 0)
            center = { X = item.At[1], Z = item.At[2], Y = 0 }
            facing = { X = math.sin(heading), Z = -math.cos(heading) }
        else
            local road = assert(item.Road, item.Id .. " : route ou position manquante")
            local polyline = assert(originPolyline[road], item.Id .. " : route inconnue " .. road)
            local point, tangent = sampleAt(polyline, item.T or 0.5)
            -- Normale droite (sens de la route) : (-dz, dx).
            local right = { X = -tangent.Z, Z = tangent.X }
            local sign = if item.Side == "Left" then -1 else 1
            local roadClass = WorldConfig.RoadClasses[roadClassOf[road]]
            local offset = WorldConfig.corridorWidthM(roadClass) / 2 + 2 + item.Depth / 2
            center = { X = point.X + right.X * sign * offset, Z = point.Z + right.Z * sign * offset, Y = point.Y }
            facing = { X = -right.X * sign, Z = -right.Z * sign }
        end
        local side = { X = -facing.Z, Z = facing.X }
        local hw, hd = item.Width / 2, item.Depth / 2
        local corners = {}
        for _, c in { { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } } do
            table.insert(corners, {
                X = center.X + side.X * hw * c[1] + facing.X * hd * c[2],
                Z = center.Z + side.Z * hw * c[1] + facing.Z * hd * c[2],
            })
        end
        local placement: Placement = {
            Id = item.Id,
            Kind = item.Kind,
            Zone = zoneOf(center.X, center.Z),
            DeclaredZone = item.Zone,
            Name = item.Name,
            Center = center,
            Facing = facing,
            Width = item.Width,
            Depth = item.Depth,
            Corners = corners,
            Chargers = item.Chargers or 0,
            Pumps = item.Pumps or 0,
            Stalls = item.Stalls or 0,
            Road = item.Road,
        }
        table.insert(placements, placement)
        placementById[item.Id] = placement
    end

    local layout: Layout = {
        Version = network.Version,
        Network = network,
        Edges = edges,
        EdgeById = edgeById,
        Placements = placements,
        PlacementById = placementById,
        ZoneOf = zoneOf,
        OriginPolyline = originPolyline,
    }
    cached = layout
    return layout
end

return table.freeze(WorldLayout)
