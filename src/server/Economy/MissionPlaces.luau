--!strict
--[[
    Lieux utilisés par les missions (lot 0.5), PURS, en mètres (x est, z sud).

    Monde ouvert : à partir des DONNÉES de la carte du lot 0.3 (WorldLayout) —
    carrefours des routes ouvertes au trafic, points des chemins et routes de
    montagne, parcours de précision au paddock du complexe motorsport, ligne
    droite de drag pour les essais.
    Place de développement : points fixes de la zone d'essai (distances
    réduites, même logique), pour éprouver les boucles de jeu.
]]

local Shared = script.Parent.Parent.Parent.Parent.ReplicatedStorage.Shared
local WorldLayout = require(Shared.World.WorldLayout)
local WorldConfig = require(Shared.World.WorldConfig)

local MissionPlaces = {}

export type Point = { X: number, Z: number }

export type Places = {
    Name: string,
    Road: { Point },
    Offroad: { Point },
    Course: { Gates: { Point }, Hazards: { Point }, Park: Point, ParkHeading: number },
    Strip: { Start: Point, Heading: number, LengthM: number },
    SpeedMs: number, -- vitesse moyenne retenue pour les estimations
    Range: { Near: number, Min: number, Max: number }, -- distances de génération
}

-- Cap (rad) d'une direction : 0 = nord (-z), positif vers l'est.
function MissionPlaces.heading(dx: number, dz: number): number
    return math.atan2(dx, -dz)
end

local cachedOpen: Places? = nil

function MissionPlaces.openWorld(): Places
    if cachedOpen then
        return cachedOpen
    end
    local layout = WorldLayout.get()
    local road: { Point } = {}
    local seen: { [string]: boolean } = {}
    for _, edge in layout.Edges do
        local class = WorldConfig.RoadClasses[edge.Class]
        if class.Traffic and edge.Class ~= "Autoroute" and edge.Class ~= "Peripherique" then
            for _, id in { edge.From, edge.To } do
                if not seen[id] then
                    seen[id] = true
                    local node = layout.Network.NodeById[id]
                    table.insert(road, { X = node.X, Z = node.Z })
                end
            end
        end
    end
    local offroad: { Point } = {}
    for _, edge in layout.Edges do
        if edge.Class == "Chemin" or edge.Class == "Montagne" then
            for i = 1, #edge.Polyline, 6 do
                local p = edge.Polyline[i]
                table.insert(offroad, { X = p.X, Z = p.Z })
            end
        end
    end
    -- Parcours de précision au paddock : slalom le long de l'emplacement.
    local paddock = layout.PlacementById["PARK-PADDOCK"]
    local f = paddock.Facing
    local s = { X = -f.Z, Z = f.X }
    local c = paddock.Center
    local gates, hazards = {}, {}
    for k = 0, 4 do
        local along = -40 + 18 * k
        local lateral = if k % 2 == 0 then 5 else -5
        table.insert(gates, { X = c.X + s.X * along + f.X * lateral, Z = c.Z + s.Z * along + f.Z * lateral })
        table.insert(hazards, { X = c.X + s.X * (along + 9), Z = c.Z + s.Z * (along + 9) })
    end
    local park = { X = c.X + s.X * 52, Z = c.Z + s.Z * 52 }
    local dragA = layout.Network.NodeById["DRAG_A"]
    local dragB = layout.Network.NodeById["DRAG_B"]
    local dx, dz = dragB.X - dragA.X, dragB.Z - dragA.Z
    local length = math.sqrt(dx * dx + dz * dz)
    local places: Places = {
        Name = "OpenWorld",
        Road = road,
        Offroad = offroad,
        Course = { Gates = gates, Hazards = hazards, Park = park, ParkHeading = MissionPlaces.heading(s.X, s.Z) },
        Strip = {
            Start = { X = dragA.X + dx / length * 20, Z = dragA.Z + dz / length * 20 },
            Heading = MissionPlaces.heading(dx, dz),
            LengthM = length - 20,
        },
        SpeedMs = 13, -- ≈ 47 km/h de moyenne en ville et sur route
        Range = { Near = 500, Min = 700, Max = 3000 },
    }
    cachedOpen = places
    return places
end

-- Zone d'essai de la place de développement (coordonnées en mètres).
function MissionPlaces.dev(): Places
    local road: { Point } = {}
    for _, x in { -150, -80, 0, 80, 150 } do
        for _, z in { -280, -200, -120, -40, 40 } do
            table.insert(road, { X = x, Z = z })
        end
    end
    local gates, hazards = {}, {}
    for k = 0, 4 do
        table.insert(gates, { X = 100 + (if k % 2 == 0 then 4 else -4), Z = -120 - 16 * k })
        table.insert(hazards, { X = 100, Z = -128 - 16 * k })
    end
    return {
        Name = "Dev",
        Road = road,
        Offroad = {
            { X = -150, Z = -60 },
            { X = -60, Z = -150 },
            { X = 60, Z = -150 },
            { X = 150, Z = -60 },
            { X = -120, Z = -220 },
            { X = 120, Z = -220 },
        },
        Course = { Gates = gates, Hazards = hazards, Park = { X = 100, Z = -215 }, ParkHeading = 0 },
        Strip = { Start = { X = -30, Z = -10 }, Heading = 0, LengthM = 290 },
        SpeedMs = 9,
        Range = { Near = 120, Min = 120, Max = 320 },
    }
end

return table.freeze(MissionPlaces)
