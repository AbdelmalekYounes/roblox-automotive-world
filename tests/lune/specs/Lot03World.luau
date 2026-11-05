--!strict
-- Lot 0.3 — contrats de la carte ouverte (données et mise en page pures).
-- Ces tests vérifient la COHÉRENCE des données (zones, réseau, pentes,
-- dimensionnement, infrastructures) ; ils ne remplacent pas un essai en jeu.

return function(T: any, H: any)
    local Geometry = H.require("ReplicatedStorage.Shared.World.Geometry")
    local WorldConfig = H.require("ReplicatedStorage.Shared.World.WorldConfig")
    local WorldLayout = H.require("ReplicatedStorage.Shared.World.WorldLayout")
    local RoadGraph = H.require("ReplicatedStorage.Shared.World.RoadGraph")
    local ZoneData = H.require("ReplicatedStorage.Shared.World.Data.Zones")
    local MapData = H.require("ReplicatedStorage.Shared.World.Data.MapData")

    local layout = WorldLayout.get()
    local graph = RoadGraph.get()
    local network = layout.Network

    -- Index spatial des segments de toutes les routes (cellules de 150 m).
    local CELL = 150
    type Segment = { Edge: any, A: any, B: any }
    local grid: { [string]: { Segment } } = {}
    local function key(x: number, z: number): string
        return math.floor(x / CELL) .. ":" .. math.floor(z / CELL)
    end
    for _, edge in layout.Edges do
        local polyline = edge.Polyline
        for i = 2, #polyline do
            local a, b = polyline[i - 1], polyline[i]
            local segment = { Edge = edge, A = a, B = b }
            local seen = {}
            local steps = math.max(1, math.ceil(Geometry.distance(a, b) / (CELL / 2)))
            for s = 0, steps do
                local p = Geometry.lerp(a, b, s / steps)
                local k = key(p.X, p.Z)
                if not seen[k] then
                    seen[k] = true
                    grid[k] = grid[k] or {}
                    table.insert(grid[k], segment)
                end
            end
        end
    end
    local function nearby(x: number, z: number): { Segment }
        local result = {}
        local cx, cz = math.floor(x / CELL), math.floor(z / CELL)
        for dx = -1, 1 do
            for dz = -1, 1 do
                for _, segment in grid[(cx + dx) .. ":" .. (cz + dz)] or {} do
                    table.insert(result, segment)
                end
            end
        end
        return result
    end

    T.suite("Lot 0.3 — zones et réseau routier")

    T.test("les sept zones du cahier des charges existent et contiennent des routes", function()
        T.equal(#WorldConfig.ZoneIds, 7)
        local counts = {}
        for _, edge in layout.Edges do
            counts[edge.Zone] = (counts[edge.Zone] or 0) + edge.LengthM
        end
        for _, zone in WorldConfig.ZoneIds do
            T.truthy((ZoneData.Zones :: any)[zone] ~= nil, zone .. " défini")
            T.truthy((counts[zone] or 0) > 1000, string.format("%s : %.0f m de routes", zone, counts[zone] or 0))
        end
        local parts = {}
        for _, zone in WorldConfig.ZoneIds do
            table.insert(parts, string.format("%s %.1f km", zone, (counts[zone] or 0) / 1000))
        end
        T.note("Longueur de routes par zone : " .. table.concat(parts, " ; "))
    end)

    T.test("carte d'un seul tenant : tous les carrefours sont reliés (aucune téléportation)", function()
        local start = network.Nodes[1].Id
        local seen = { [start] = true }
        local queue = { start }
        while #queue > 0 do
            local id = table.remove(queue)
            for _, link in graph.Adjacency[id] do
                if not seen[link.To] then
                    seen[link.To] = true
                    table.insert(queue, link.To)
                end
            end
        end
        local missing = {}
        for _, node in network.Nodes do
            if not seen[node.Id] then
                table.insert(missing, node.Id)
            end
        end
        T.equal(#missing, 0, "carrefours isolés : " .. table.concat(missing, ", "))
        T.note(
            string.format(
                "Réseau : %d carrefours, %d tronçons, %d îlots",
                #network.Nodes,
                #network.Edges,
                #network.Cells
            )
        )
    end)

    T.test("identifiants stables et uniques ; aucun tronçon court ni avertissement", function()
        local seen = {}
        for _, edge in layout.Edges do
            T.truthy(not seen[edge.Id], "dupliqué : " .. edge.Id)
            seen[edge.Id] = true
            T.truthy(edge.LengthM >= 15, string.format("%s : %.1f m", edge.Id, edge.LengthM))
        end
        T.equal(#network.Warnings, 0, table.concat(network.Warnings, " ; "))
        T.equal(layout.Version, WorldConfig.MapVersion)
    end)

    T.test("quartiers : polygones convexes bornés par des routes droites", function()
        for _, district in MapData.Districts do
            local polygon = {}
            for _, id in district.Boundary do
                local node = network.NodeById[id]
                table.insert(polygon, { X = node.X, Z = node.Z })
            end
            T.truthy(Geometry.isConvex(polygon), district.Id .. " convexe")
        end
    end)

    T.test("aucun croisement non prévu entre deux routes", function()
        local crossings = {}
        local checked: { [any]: boolean } = {}
        for _, bucket in grid do
            for i = 1, #bucket do
                for j = i + 1, #bucket do
                    local s1, s2 = bucket[i], bucket[j]
                    if s1.Edge ~= s2.Edge then
                        local pairKey = tostring(s1) .. tostring(s2)
                        if not checked[pairKey] then
                            checked[pairKey] = true
                            local t = Geometry.segmentIntersection(s1.A, s1.B, s2.A, s2.B, 1e-4)
                            if t then
                                table.insert(crossings, s1.Edge.Id .. " × " .. s2.Edge.Id)
                            end
                        end
                    end
                end
            end
        end
        T.equal(#crossings, 0, table.concat(crossings, " ; "))
    end)

    T.test("emprises sans chevauchement hors des carrefours", function()
        local overlaps, reported = {}, {}
        for _, edge in layout.Edges do
            local polyline = edge.Polyline
            local from, to = network.NodeById[edge.From], network.NodeById[edge.To]
            for i = 1, #polyline do
                local p = polyline[i]
                for _, segment in nearby(p.X, p.Z) do
                    local other = segment.Edge
                    if other == edge or reported[edge.Id .. other.Id] then
                        continue
                    end
                    local clearance = (edge.CorridorM + other.CorridorM) / 2
                    local distance = Geometry.pointSegmentDistance(p, segment.A, segment.B)
                    if distance < clearance - 0.5 then
                        -- Près d'un carrefour (de l'un ou l'autre tronçon), le contact est normal.
                        local exclusion = clearance + 25
                        local nearJunction = false
                        for _, id in { edge.From, edge.To, other.From, other.To } do
                            local n = network.NodeById[id]
                            if math.sqrt((p.X - n.X) ^ 2 + (p.Z - n.Z) ^ 2) < exclusion then
                                nearJunction = true
                            end
                        end
                        if not nearJunction then
                            reported[edge.Id .. other.Id] = true
                            reported[other.Id .. edge.Id] = true
                            table.insert(overlaps, string.format("%s / %s (%.1f m)", edge.Id, other.Id, distance))
                        end
                    end
                end
            end
            local _ = from
            local _2 = to
        end
        T.equal(#overlaps, 0, table.concat(overlaps, " ; "))
    end)

    T.test("pentes praticables (≤ 12 %) et routes de montagne en altitude", function()
        local steepest, where, maxAltitude = 0, "", 0
        for _, edge in layout.Edges do
            local polyline = edge.Polyline
            for i = 2, #polyline do
                local a, b = polyline[i - 1], polyline[i]
                local run = Geometry.distance(a, b)
                if run > 1 then
                    local grade = math.abs(b.Y - a.Y) / run
                    if grade > steepest then
                        steepest, where = grade, edge.Id
                    end
                end
                maxAltitude = math.max(maxAltitude, b.Y)
            end
        end
        T.truthy(steepest <= 0.125, string.format("pente max %.1f %% (%s)", steepest * 100, where))
        T.truthy(maxAltitude >= 200, "dénivelé de montagne")
        T.note(
            string.format("Pente maximale %.1f %% (%s) ; altitude maximale %.0f m", steepest * 100, where, maxAltitude)
        )
    end)

    T.test("aucune route dans la mer", function()
        local wet = {}
        for _, edge in layout.Edges do
            for _, p in edge.Polyline do
                if Geometry.pointInPolygon(p, ZoneData.Sea) then
                    table.insert(wet, edge.Id)
                    break
                end
            end
        end
        T.equal(#wet, 0, table.concat(wet, ", "))
    end)

    T.test("trajet autoroutier de référence (A1) : 6 à 10 min à 110–130 km/h", function()
        local length = 0
        for _, id in { "A1-1", "A1-2", "A1-3", "A1-4", "A1-5" } do
            length += Geometry.polylineLength(layout.OriginPolyline[id])
        end
        local slow = RoadGraph.tripMinutes(length, WorldConfig.ReferenceCruiseKmh.Low)
        local fast = RoadGraph.tripMinutes(length, WorldConfig.ReferenceCruiseKmh.High)
        T.between(fast, WorldConfig.ReferenceTripMinutes.Min, WorldConfig.ReferenceTripMinutes.Max, "à 130 km/h")
        T.between(slow, WorldConfig.ReferenceTripMinutes.Min, WorldConfig.ReferenceTripMinutes.Max, "à 110 km/h")
        local route = RoadGraph.route(graph, "A1_00", "A1_05", "Time")
        T.truthy(route ~= nil, "itinéraire trouvé")
        T.note(
            string.format(
                "A1 (motorsport → cols) : %.2f km, %.1f min à 130 km/h, %.1f min à 110 km/h ; itinéraire le plus rapide %.2f km",
                length / 1000,
                fast,
                slow,
                (route :: any).LengthM / 1000
            )
        )
    end)

    T.test("chaque zone est reliée à la Place Centrale par un itinéraire", function()
        for _, zone in WorldConfig.ZoneIds do
            local target = RoadGraph.nearestNode(graph, 0, 0, function(id)
                local node = network.NodeById[id]
                return layout.ZoneOf(node.X, node.Z) == zone
            end)
            T.truthy(target ~= nil, zone)
            local route = RoadGraph.route(graph, "O", target :: string, "Distance")
            T.truthy(route ~= nil, "itinéraire vers " .. zone)
        end
    end)

    T.suite("Lot 0.3 — infrastructures")

    local function countBy(kind: string): { [string]: number }
        local result = {}
        for _, placement in layout.Placements do
            if placement.Kind == kind then
                result[placement.Zone] = (result[placement.Zone] or 0) + 1
            end
        end
        return result
    end
    local function total(map: { [string]: number }): number
        local sum = 0
        for _, n in map do
            sum += n
        end
        return sum
    end

    T.test("quantités du cahier des charges : 2 concessions, 3 garages, 6 stations, 3 lavages", function()
        local required = WorldConfig.RequiredServices
        T.equal(total(countBy("Dealership")), required.Dealership)
        T.equal(total(countBy("PublicGarage")), required.PublicGarage)
        T.equal(total(countBy("FuelStation")), required.FuelStation)
        T.equal(total(countBy("CarWash")), required.CarWash)
    end)

    T.test("au moins un point de recharge public dans chacune des sept zones", function()
        local zones = {}
        for _, placement in layout.Placements do
            if placement.Chargers > 0 and (placement.Kind == "FuelStation" or placement.Kind == "ChargingHub") then
                zones[placement.Zone] = (zones[placement.Zone] or 0) + placement.Chargers
            end
        end
        local parts = {}
        for _, zone in WorldConfig.ZoneIds do
            T.truthy((zones[zone] or 0) > 0, "recharge en " .. zone)
            table.insert(parts, zone .. " " .. tostring(zones[zone] or 0))
        end
        T.note("Places de recharge par zone : " .. table.concat(parts, ", "))
    end)

    T.test("chaque infrastructure est dans la zone déclarée, hors de l'eau et des chaussées", function()
        for _, placement in layout.Placements do
            T.equal(placement.Zone, placement.DeclaredZone, placement.Id)
            local samples = { { X = placement.Center.X, Z = placement.Center.Z } }
            local corners = placement.Corners
            for i = 1, #corners do
                local a, b = corners[i], corners[i % #corners + 1]
                for s = 0, 4 do
                    table.insert(samples, Geometry.lerp(a, b, s / 5))
                end
            end
            for _, p in samples do
                T.truthy(not Geometry.pointInPolygon(p, ZoneData.Sea), placement.Id .. " dans la mer")
                for _, segment in nearby(p.X, p.Z) do
                    local d = Geometry.pointSegmentDistance(p, segment.A, segment.B)
                    T.truthy(
                        d >= segment.Edge.CorridorM / 2 - 0.25,
                        string.format("%s empiète sur %s (%.1f m)", placement.Id, segment.Edge.Id, d)
                    )
                end
            end
        end
    end)

    T.test("aucun chevauchement entre infrastructures", function()
        local placements = layout.Placements
        for i = 1, #placements do
            for j = i + 1, #placements do
                local a, b = placements[i], placements[j]
                local overlap = Geometry.pointInPolygon(b.Center, a.Corners)
                    or Geometry.pointInPolygon(a.Center, b.Corners)
                for _, c in b.Corners do
                    overlap = overlap or Geometry.pointInPolygon(c, a.Corners)
                end
                T.truthy(not overlap, a.Id .. " / " .. b.Id)
            end
        end
    end)

    T.test("apparitions et parc des prototypes sur des emplacements sûrs (hors voies)", function()
        local fleet = layout.PlacementById["FLEET-METRO"]
        T.truthy(fleet ~= nil and fleet.Stalls >= 9, "9 places pour le parc des prototypes")
        local spawns = countBy("PlayerSpawn")
        T.truthy(total(spawns) >= 2, "points d'apparition")
    end)
end
