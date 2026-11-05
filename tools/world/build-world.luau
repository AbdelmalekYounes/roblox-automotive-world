--!strict
-- Générateur HORS LIGNE et DÉTERMINISTE de la carte ouverte (lot 0.3).
--
-- Lit la mise en page pure (World/WorldLayout, données versionnées) dans la
-- place de développement construite par Rojo, puis écrit un modèle binaire
-- `OpenWorld.rbxm` inclus par `openworld.project.json`. Le serveur ne
-- reconstruit donc aucune pièce au démarrage : la carte est un artefact de
-- construction, reproductible à partir des données (même version → même modèle).
--
-- Organisation pour le streaming (StreamingEnabled) :
-- - Routes/<secteur> : chaussées, carrefours, trottoirs, glissières, en modèles
--   PERSISTANTS (toujours chargés : les collisions des routes sont disponibles
--   avant qu'un véhicule rapide les atteigne, AUD-WORLD-02) ;
-- - Decor/<secteur>, Relief/<secteur>, Sol : chargés selon la distance ;
-- - Services/<id> : modèles atomiques (un service arrive en entier) ;
-- - Habillage/<zone>/<secteur> (lot 0.8) : accessoires par zone, visibilité réglée par le client.
--
-- Usage : lune run tools/world/build-world.luau <place.rbxlx> <sortie.rbxm>

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Harness = require("../../tests/lune/Harness")

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local Enum = roblox.Enum

local placePath, outputPath = process.args[1], process.args[2]
if placePath == nil or outputPath == nil then
    print("Usage : lune run tools/world/build-world.luau <place.rbxlx> <sortie.rbxm>")
    process.exit(2)
end

Harness.loadPlace(placePath :: string)
local Geometry = Harness.require("ReplicatedStorage.Shared.World.Geometry")
local WorldConfig = Harness.require("ReplicatedStorage.Shared.World.WorldConfig")
local WorldLayout = Harness.require("ReplicatedStorage.Shared.World.WorldLayout")
local ZoneData = Harness.require("ReplicatedStorage.Shared.World.Data.Zones")
local Signals = Harness.require("ReplicatedStorage.Shared.World.Signals")

local layout = WorldLayout.get()
local network = layout.Network
local S = 1 / WorldConfig.MetersPerStud -- studs par mètre
local SECTOR = 500 -- côté des secteurs de streaming (m)

local stats = { Parts = 0 }

-- ============================== OUTILS ==============================

local root = Instance.new("Model")
root.Name = "OpenWorld"
root:SetAttribute("MapVersion", WorldConfig.MapVersion)
root:SetAttribute("Generator", "tools/world/build-world.luau")

local function folder(parent: any, name: string): any
    local existing = parent:FindFirstChild(name)
    if existing then
        return existing
    end
    local f = Instance.new("Folder")
    f.Name = name
    f.Parent = parent
    return f
end

local groups = {
    Routes = folder(root, "Routes"),
    Decor = folder(root, "Decor"),
    Relief = folder(root, "Relief"),
    Sol = folder(root, "Sol"),
    Services = folder(root, "Services"),
    Apparitions = folder(root, "Apparitions"),
}

-- Modèle de secteur (créé à la demande).
local function sectorModel(group: string, x: number, z: number, persistent: boolean): any
    local i, j = math.floor(x / SECTOR), math.floor(z / SECTOR)
    local name = string.format("%s_%d_%d", group, i, j)
    local parent = groups[group]
    local existing = parent:FindFirstChild(name)
    if existing then
        return existing
    end
    local model = Instance.new("Model")
    model.Name = name
    model.ModelStreamingMode = if persistent
        then Enum.ModelStreamingMode.Persistent
        else Enum.ModelStreamingMode.Default
    model:SetAttribute("Sector", string.format("%d:%d", i, j))
    model.Parent = parent
    return model
end

type PartProps = {
    Name: string,
    Size: any, -- Vector3 en studs
    CFrame: any,
    Color: any,
    Material: any?,
    Collide: boolean?,
    Transparency: number?,
    Shape: any?,
}

local function part(parent: any, props: PartProps): any
    local p = Instance.new("Part")
    p.Name = props.Name
    p.Anchored = true
    p.Size = props.Size
    p.CFrame = props.CFrame
    p.Color = props.Color
    p.Material = props.Material or Enum.Material.SmoothPlastic
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    local collide = props.Collide ~= false
    p.CanCollide = collide
    p.CanQuery = collide
    p.CanTouch = false
    p.CastShadow = collide
    p.Transparency = props.Transparency or 0
    if props.Shape then
        p.Shape = props.Shape
    end
    p.Parent = parent
    stats.Parts += 1
    return p
end

local function rgb(r: number, g: number, b: number): any
    return Color3.fromRGB(r, g, b)
end

local function v3(x: number, y: number, z: number): any
    return Vector3.new(x * S, y * S, z * S)
end

-- Bloc posé entre deux points (mètres), haut de la pièce à l'altitude des points.
local function strip(
    parent: any,
    name: string,
    a: any,
    b: any,
    width: number,
    thickness: number,
    lift: number,
    color: any,
    material: any?,
    collide: boolean?
): any?
    local dx, dz = b.X - a.X, b.Z - a.Z
    local horizontal = math.sqrt(dx * dx + dz * dz)
    if horizontal < 0.05 then
        return nil
    end
    local dy = b.Y - a.Y
    local length = math.sqrt(horizontal * horizontal + dy * dy)
    local mid = Vector3.new((a.X + b.X) / 2 * S, ((a.Y + b.Y) / 2 + lift) * S, (a.Z + b.Z) / 2 * S)
    local target = Vector3.new(b.X * S, (b.Y + lift) * S, b.Z * S)
    local cframe = CFrame.lookAt(mid, target) * CFrame.new(0, -thickness / 2 * S, 0)
    return part(parent, {
        Name = name,
        Size = Vector3.new(width * S, thickness * S, length * S),
        CFrame = cframe,
        Color = color,
        Material = material,
        Collide = collide,
    })
end

-- Simplification de Douglas-Peucker (3D) d'une polyligne.
local function simplifyRaw(points: { any }, tolerance: number): { any }
    if #points <= 2 then
        return points
    end
    local keep = table.create(#points, false)
    keep[1], keep[#points] = true, true
    local function recurse(first: number, last: number)
        local a, b = points[first], points[last]
        local worst, index = 0, nil
        for i = first + 1, last - 1 do
            local p = points[i]
            local d = Geometry.pointSegmentDistance(p, a, b)
            -- L'altitude compte aussi (pentes et épingles).
            local _, t = Geometry.pointSegmentDistance(p, a, b)
            local y = a.Y + (b.Y - a.Y) * t
            d = math.max(d, math.abs(p.Y - y))
            if d > worst then
                worst, index = d, i
            end
        end
        if index and worst > tolerance then
            keep[index] = true
            recurse(first, index)
            recurse(index, last)
        end
    end
    recurse(1, #points)
    local result = {}
    for i, p in points do
        if keep[i] then
            table.insert(result, p)
        end
    end
    return result
end

-- Longueur maximale d'un segment (m). Une pièce Roblox ne peut pas dépasser
-- 2 048 studs par côté (≈ 573 m) : au-delà, le moteur la RACCOURCIT en silence,
-- ce qui laissait un trou au bout des longues chaussées droites (mesuré en
-- Studio, tâche 20261103-025743). Tout tracé simplifié est donc redécoupé.
local MAX_SEGMENT_M = 500

local function simplify(points: { any }, tolerance: number): { any }
    local reduced = simplifyRaw(points, tolerance)
    local result = { reduced[1] }
    for i = 2, #reduced do
        local a, b = reduced[i - 1], reduced[i]
        local length = math.sqrt((b.X - a.X) ^ 2 + (b.Y - a.Y) ^ 2 + (b.Z - a.Z) ^ 2)
        local pieces = math.max(1, math.ceil(length / MAX_SEGMENT_M))
        for k = 1, pieces do
            local f = k / pieces
            table.insert(
                result,
                if k == pieces
                    then b
                    else { X = a.X + (b.X - a.X) * f, Y = a.Y + (b.Y - a.Y) * f, Z = a.Z + (b.Z - a.Z) * f }
            )
        end
    end
    return result
end

-- Décalage latéral d'une polyligne (m, positif à droite du sens de marche).
local function offsetPolyline(points: { any }, offset: number): { any }
    local count = #points
    local result = {}
    for i = 1, count do
        local a, b = points[math.max(i - 1, 1)], points[math.min(i + 1, count)]
        local dx, dz = b.X - a.X, b.Z - a.Z
        local length = math.sqrt(dx * dx + dz * dz)
        if length < 1e-6 then
            dx, dz, length = 0, -1, 1
        end
        table.insert(
            result,
            { X = points[i].X - dz / length * offset, Z = points[i].Z + dx / length * offset, Y = points[i].Y }
        )
    end
    return result
end

-- Tronque une polyligne de `cutA` mètres au début et `cutB` à la fin.
local function trim(points: { any }, cutA: number, cutB: number): { any }
    local total = Geometry.polylineLength(points)
    if total <= cutA + cutB + 1 then
        return {}
    end
    local function at(distance: number): any
        local travelled = 0
        for i = 2, #points do
            local d = Geometry.distance(points[i - 1], points[i])
            if travelled + d >= distance then
                local t = (distance - travelled) / d
                local a, b = points[i - 1], points[i]
                return { X = a.X + (b.X - a.X) * t, Z = a.Z + (b.Z - a.Z) * t, Y = a.Y + (b.Y - a.Y) * t }, i
            end
            travelled += d
        end
        return points[#points], #points
    end
    local startPoint, startIndex = at(cutA)
    local endPoint, endIndex = at(total - cutB)
    local result = { startPoint }
    for i = startIndex, endIndex - 1 do
        table.insert(result, points[i])
    end
    table.insert(result, endPoint)
    return result
end

-- ============================== COULEURS ==============================

local ASPHALT = rgb(52, 54, 58)
local ASPHALT_HIGHWAY = rgb(46, 48, 52)
local GRAVEL = rgb(140, 125, 100)
local SIDEWALK = rgb(170, 170, 165)
local MARKING = rgb(235, 235, 230)
local MARKING_EDGE = rgb(230, 200, 60)
local BARRIER = rgb(175, 180, 185)

local ZONE_GROUND = {
    Metropole = { rgb(120, 125, 118), Enum.Material.Pavement },
    Banlieues = { rgb(105, 140, 85), Enum.Material.Grass },
    Docks = { rgb(130, 128, 120), Enum.Material.Concrete },
    Montagnes = { rgb(95, 120, 80), Enum.Material.Grass },
    Campagne = { rgb(120, 150, 80), Enum.Material.Grass },
    Motorsport = { rgb(110, 145, 90), Enum.Material.Grass },
    Littoral = { rgb(205, 190, 140), Enum.Material.Sand },
}

-- ============================== ROUTES ==============================

-- Rayon des plateformes de carrefour : demi-emprise la plus large des tronçons.
local junctionRadius: { [string]: number } = {}
local degree: { [string]: number } = {}
for _, edge in layout.Edges do
    for _, id in { edge.From, edge.To } do
        junctionRadius[id] = math.max(junctionRadius[id] or 0, edge.WidthM / 2)
        degree[id] = (degree[id] or 0) + 1
    end
end

for _, edge in layout.Edges do
    local roadClass = WorldConfig.RoadClasses[edge.Class]
    local polyline = simplify(edge.Polyline, 0.15)
    local mid = polyline[math.max(1, math.floor(#polyline / 2))]
    local roads = sectorModel("Routes", mid.X, mid.Z, true)
    local decor = sectorModel("Decor", mid.X, mid.Z, false)
    local elevated = false
    for _, p in polyline do
        if p.Y > 1 then
            elevated = true
        end
    end
    -- Chaussée : bloc épais en altitude (porte la route sans relief dessous).
    local thickness = if elevated then 1.5 else 0.6
    local color = if edge.Class == "Chemin" then GRAVEL elseif roadClass.Rank >= 5 then ASPHALT_HIGHWAY else ASPHALT
    local material = Enum.Material[roadClass.Material]
    for i = 2, #polyline do
        local surface = strip(
            roads,
            "Chaussee",
            polyline[i - 1],
            polyline[i],
            edge.WidthM,
            thickness,
            0.05 + (i % 2) * 0.004,
            color,
            material,
            true
        )
        if surface then
            surface:SetAttribute("RoadId", edge.Id)
            surface:SetAttribute("RoadClass", edge.Class)
        end
    end
    -- Recouvrement des angles : petits disques aux sommets intérieurs.
    for i = 2, #polyline - 1 do
        local p = polyline[i]
        part(roads, {
            Name = "Raccord",
            Size = Vector3.new(thickness * S, edge.WidthM * S, edge.WidthM * S),
            CFrame = CFrame.new(p.X * S, (p.Y + 0.05 - thickness / 2) * S, p.Z * S) * CFrame.Angles(0, 0, math.pi / 2),
            Color = color,
            Material = material,
            Shape = Enum.PartType.Cylinder,
        })
    end

    local trimA = (junctionRadius[edge.From] or 0) + 2
    local trimB = (junctionRadius[edge.To] or 0) + 2
    local carriage = edge.WidthM

    -- Trottoirs (bordure de 15 cm), hors des carrefours.
    if roadClass.SidewalkM > 0 then
        for _, side in { -1, 1 } do
            local line = trim(offsetPolyline(polyline, side * (carriage + roadClass.SidewalkM) / 2), trimA, trimB)
            for i = 2, #line do
                strip(
                    roads,
                    "Trottoir",
                    line[i - 1],
                    line[i],
                    roadClass.SidewalkM,
                    0.6,
                    0.2,
                    SIDEWALK,
                    Enum.Material.Concrete,
                    true
                )
            end
        end
    end

    -- Glissières (bords, terre-plein central) hors des carrefours.
    local barrierOffsets = {}
    if roadClass.Barriers ~= "None" then
        table.insert(barrierOffsets, carriage / 2 + 0.3)
        table.insert(barrierOffsets, -carriage / 2 - 0.3)
    end
    if roadClass.Barriers == "EdgesAndMedian" then
        table.insert(barrierOffsets, 0)
    end
    local barrierTrimA = if degree[edge.From] == 1 then 0 else trimA + 12
    local barrierTrimB = if degree[edge.To] == 1 then 0 else trimB + 12
    for _, offset in barrierOffsets do
        local line = trim(offsetPolyline(simplify(edge.Polyline, 0.4), offset), barrierTrimA, barrierTrimB)
        for i = 2, #line do
            strip(
                roads,
                "Glissiere",
                line[i - 1],
                line[i],
                if offset == 0 then 0.6 else 0.3,
                0.85,
                0.9,
                BARRIER,
                Enum.Material.Metal,
                true
            )
        end
    end

    -- Marquages : bords de chaussée et séparations de voies (non collisionnables).
    local markingLine = simplify(edge.Polyline, 0.5)
    local markOffsets = {}
    local lanes = roadClass.LanesPerDirection
    local half = roadClass.MedianM / 2
    if edge.Class == "Rue" then
        -- Rues : ligne centrale seule (la bordure du trottoir marque le bord).
        table.insert(markOffsets, 0)
    elseif edge.Class ~= "Chemin" then
        for _, side in { -1, 1 } do
            table.insert(markOffsets, side * (half + lanes * roadClass.LaneWidthM))
            for lane = 1, lanes - 1 do
                table.insert(markOffsets, side * (half + lane * roadClass.LaneWidthM))
            end
            if roadClass.MedianM > 0 then
                table.insert(markOffsets, side * half)
            end
        end
        if roadClass.MedianM == 0 then
            table.insert(markOffsets, 0)
        end
    end
    for _, offset in markOffsets do
        local line = trim(offsetPolyline(markingLine, offset), trimA, trimB)
        local yellow = roadClass.MedianM > 0 and math.abs(math.abs(offset) - half) < 0.01
        for i = 2, #line do
            strip(
                decor,
                "Marquage",
                line[i - 1],
                line[i],
                0.15,
                0.02,
                0.07,
                if yellow then MARKING_EDGE else MARKING,
                Enum.Material.SmoothPlastic,
                false
            )
        end
    end
end

-- Plateformes de carrefour.
for _, node in network.Nodes do
    local radius = junctionRadius[node.Id]
    if radius and (degree[node.Id] or 0) >= 3 then
        local roads = sectorModel("Routes", node.X, node.Z, true)
        local disc = part(roads, {
            Name = "Carrefour",
            Size = Vector3.new(0.6 * S, (radius * 2 + 2) * S, (radius * 2 + 2) * S),
            CFrame = CFrame.new(node.X * S, (node.Y + 0.058 - 0.3) * S, node.Z * S) * CFrame.Angles(0, 0, math.pi / 2),
            Color = ASPHALT,
            Material = Enum.Material.Asphalt,
            Shape = Enum.PartType.Cylinder,
        })
        disc:SetAttribute("NodeId", node.Id)
    end
end

-- ============================== FEUX TRICOLORES ==============================

for _, node in network.Nodes do
    if node.Control ~= "Signals" or (degree[node.Id] or 0) < 3 then
        continue
    end
    local approaches = Signals.approaches(layout, node.Id)
    for _, approach in approaches do
        -- Poteau à droite de la voie d'arrivée, juste avant le carrefour.
        local p = approach.StopPoint
        local right = approach.Right
        local x = p.X + right.X * (approach.HalfWidth + 1.2)
        local z = p.Z + right.Z * (approach.HalfWidth + 1.2)
        local signals = sectorModel("Decor", x, z, false)
        local pole = part(signals, {
            Name = "FeuPoteau",
            Size = v3(0.25, 4.5, 0.25),
            CFrame = CFrame.new(x * S, (node.Y + 2.25) * S, z * S),
            Color = rgb(40, 42, 45),
            Material = Enum.Material.Metal,
        })
        local head = part(signals, {
            Name = "FeuTete",
            Size = v3(0.45, 1.2, 0.45),
            CFrame = CFrame.new(x * S, (node.Y + 4.6) * S, z * S),
            Color = rgb(30, 30, 30),
            Collide = false,
        })
        local lamp = part(signals, {
            Name = "FeuLampe",
            Size = v3(0.5, 0.35, 0.5),
            CFrame = CFrame.new(x * S, (node.Y + 4.6) * S, z * S),
            Color = rgb(60, 60, 60),
            Material = Enum.Material.Neon,
            Collide = false,
        })
        lamp:SetAttribute("NodeId", node.Id)
        lamp:SetAttribute("Group", approach.Group)
        lamp:AddTag("AWTrafficLight")
        local _ = pole
        local _2 = head
    end
end

-- ============================== SOL, MER, RELIEF ==============================

local half = WorldConfig.HalfExtentM
local function inSea(x: number, z: number): boolean
    return Geometry.pointInPolygon({ X = x, Z = z }, ZoneData.Sea)
end

local TILE = 500
for i = 0, (2 * half) / TILE - 1 do
    for j = 0, (2 * half) / TILE - 1 do
        local x0, z0 = -half + i * TILE, -half + j * TILE
        -- Tuile mixte (côte) : subdivisée en carrés de 100 m.
        local corners = {
            inSea(x0, z0),
            inSea(x0 + TILE, z0),
            inSea(x0, z0 + TILE),
            inSea(x0 + TILE, z0 + TILE),
            inSea(x0 + TILE / 2, z0 + TILE / 2),
        }
        local allSea, anySea = true, false
        for _, c in corners do
            allSea = allSea and c
            anySea = anySea or c
        end
        local step = if anySea and not allSea then 100 else TILE
        for a = 0, TILE / step - 1 do
            for b = 0, TILE / step - 1 do
                local cx, cz = x0 + (a + 0.5) * step, z0 + (b + 0.5) * step
                local ground = sectorModel("Sol", cx, cz, false)
                if inSea(cx, cz) then
                    part(ground, {
                        Name = "FondMarin",
                        Size = v3(step, 2, step),
                        CFrame = CFrame.new(cx * S, (WorldConfig.SeaFloorM - 1) * S, cz * S),
                        Color = rgb(150, 140, 110),
                        Material = Enum.Material.Sand,
                    })
                    part(ground, {
                        Name = "Mer",
                        Size = v3(step, 0.2, step),
                        CFrame = CFrame.new(cx * S, WorldConfig.SeaLevelM * S, cz * S),
                        Color = rgb(40, 110, 160),
                        Material = Enum.Material.Glass,
                        Transparency = 0.35,
                        Collide = false,
                    })
                else
                    local zone = layout.ZoneOf(cx, cz)
                    local style = ZONE_GROUND[zone]
                    local coastal = step < TILE
                        and (
                            inSea(cx + step, cz)
                            or inSea(cx - step, cz)
                            or inSea(cx, cz + step)
                            or inSea(cx, cz - step)
                        )
                    local surface = part(ground, {
                        Name = "Sol",
                        Size = v3(step, 4, step),
                        CFrame = CFrame.new(cx * S, -2 * S, cz * S),
                        Color = if coastal then rgb(215, 200, 150) else style[1],
                        Material = if coastal then Enum.Material.Sand else style[2],
                    })
                    surface:SetAttribute("Zone", zone)
                end
            end
        end
    end
end

-- Relief : champ de hauteurs par cellules de 60 m (sommets et épaulement des
-- routes en altitude), jamais au-dessus d'une route qui traverse la cellule.
local CELL = 60
type RoadSample = { X: number, Z: number, Y: number, Half: number }
local samples: { [string]: { RoadSample } } = {}
local function cellKey(i: number, j: number): string
    return i .. ":" .. j
end
for _, edge in layout.Edges do
    local polyline = edge.Polyline
    for k = 2, #polyline do
        local a, b = polyline[k - 1], polyline[k]
        local d = Geometry.distance(a, b)
        local n = math.max(1, math.ceil(d / 8))
        for s = 0, n do
            local t = s / n
            local p = {
                X = a.X + (b.X - a.X) * t,
                Z = a.Z + (b.Z - a.Z) * t,
                Y = a.Y + (b.Y - a.Y) * t,
                Half = edge.CorridorM / 2,
            }
            local ci, cj = math.floor(p.X / CELL), math.floor(p.Z / CELL)
            for di = -2, 2 do
                for dj = -2, 2 do
                    local key = cellKey(ci + di, cj + dj)
                    samples[key] = samples[key] or {}
                    table.insert(samples[key], p)
                end
            end
        end
    end
end
local reliefCells = 0
for i = math.floor(-half / CELL), math.floor(half / CELL) - 1 do
    for j = math.floor(-half / CELL), math.floor(half / CELL) - 1 do
        local cx, cz = (i + 0.5) * CELL, (j + 0.5) * CELL
        local height = 0
        for _, peak in ZoneData.Peaks do
            local d = math.sqrt((cx - peak[1]) ^ 2 + (cz - peak[2]) ^ 2)
            if d < peak[4] then
                height = math.max(height, peak[3] * (1 - d / peak[4]))
            end
        end
        local cap = math.huge
        for _, p in samples[cellKey(i, j)] or {} do
            local d = math.sqrt((cx - p.X) ^ 2 + (cz - p.Z) ^ 2)
            -- Épaulement des routes en altitude (talus d'environ 35°).
            if p.Y > 1 then
                height = math.max(height, p.Y - 0.8 - math.max(0, d - p.Half - 4) * 0.7)
            end
            -- Une route qui passe dans la cellule (ou tout près) plafonne le relief.
            if d < CELL * 0.75 + p.Half then
                cap = math.min(cap, p.Y - 0.8)
            end
        end
        height = math.min(height, cap)
        if height > 1.5 and not inSea(cx, cz) then
            local relief = sectorModel("Relief", cx, cz, false)
            local zone = layout.ZoneOf(cx, cz)
            part(relief, {
                Name = "Relief",
                Size = v3(CELL, height, CELL),
                CFrame = CFrame.new(cx * S, height / 2 * S, cz * S),
                Color = if height > 180
                    then rgb(200, 200, 205)
                    elseif zone == "Littoral" then rgb(150, 135, 110)
                    else rgb(105, 115, 95),
                Material = if height > 180
                    then Enum.Material.Rock
                    elseif zone == "Littoral" then Enum.Material.Rock
                    else Enum.Material.Ground,
            })
            reliefCells += 1
        end
    end
end

-- Remblais sous les routes en altitude (comble l'écart avec le relief).
for _, edge in layout.Edges do
    local polyline = simplify(edge.Polyline, 0.3)
    for k = 2, #polyline do
        local a, b = polyline[k - 1], polyline[k]
        local low = math.min(a.Y, b.Y)
        if low > 2 then
            local depth = math.min(low, 14)
            local relief = sectorModel("Relief", (a.X + b.X) / 2, (a.Z + b.Z) / 2, false)
            local topA = { X = a.X, Z = a.Z, Y = a.Y - 1.4 }
            local topB = { X = b.X, Z = b.Z, Y = b.Y - 1.4 }
            strip(
                relief,
                "Remblai",
                topA,
                topB,
                edge.WidthM + 2,
                depth,
                0,
                rgb(110, 105, 95),
                Enum.Material.Ground,
                true
            )
        end
    end
end

-- ============================== BÂTIMENTS ==============================

type Style = { Lot: { number }, Height: { number }, Gap: { number }, Fill: number, Colors: { any }, Material: any }
local STYLES: { [string]: Style } = {
    Affaires = {
        Lot = { 28, 48 },
        Height = { 35, 120 },
        Gap = { 4, 8 },
        Fill = 0.95,
        Colors = { rgb(150, 165, 180), rgb(120, 135, 150), rgb(175, 180, 190) },
        Material = Enum.Material.Glass,
    },
    Commerces = {
        Lot = { 24, 42 },
        Height = { 12, 32 },
        Gap = { 3, 7 },
        Fill = 0.9,
        Colors = { rgb(200, 180, 150), rgb(180, 160, 140), rgb(210, 200, 185) },
        Material = Enum.Material.Concrete,
    },
    Residentiel = {
        Lot = { 20, 34 },
        Height = { 12, 26 },
        Gap = { 4, 9 },
        Fill = 0.85,
        Colors = { rgb(205, 190, 170), rgb(190, 175, 160), rgb(220, 210, 195) },
        Material = Enum.Material.Brick,
    },
    Mixte = {
        Lot = { 20, 40 },
        Height = { 10, 45 },
        Gap = { 4, 8 },
        Fill = 0.85,
        Colors = { rgb(180, 175, 170), rgb(200, 190, 175), rgb(160, 165, 175) },
        Material = Enum.Material.Concrete,
    },
    Public = {
        Lot = { 40, 60 },
        Height = { 8, 20 },
        Gap = { 8, 14 },
        Fill = 0.6,
        Colors = { rgb(215, 205, 185), rgb(190, 180, 165) },
        Material = Enum.Material.Limestone,
    },
    Pavillonnaire = {
        Lot = { 11, 15 },
        Height = { 6, 8 },
        Gap = { 6, 10 },
        Fill = 0.75,
        Colors = { rgb(230, 220, 200), rgb(215, 195, 170), rgb(235, 230, 220) },
        Material = Enum.Material.Plaster,
    },
    Activites = {
        Lot = { 40, 80 },
        Height = { 8, 14 },
        Gap = { 10, 18 },
        Fill = 0.8,
        Colors = { rgb(170, 175, 180), rgb(150, 155, 160) },
        Material = Enum.Material.Metal,
    },
    Industriel = {
        Lot = { 45, 90 },
        Height = { 10, 18 },
        Gap = { 10, 20 },
        Fill = 0.85,
        Colors = { rgb(140, 140, 135), rgb(160, 150, 130) },
        Material = Enum.Material.CorrodedMetal,
    },
    Docks = {
        Lot = { 50, 100 },
        Height = { 12, 18 },
        Gap = { 12, 22 },
        Fill = 0.85,
        Colors = { rgb(150, 145, 135), rgb(120, 110, 100) },
        Material = Enum.Material.CorrodedMetal,
    },
    Village = {
        Lot = { 12, 18 },
        Height = { 6, 9 },
        Gap = { 5, 12 },
        Fill = 0.65,
        Colors = { rgb(225, 210, 180), rgb(200, 185, 160) },
        Material = Enum.Material.Cobblestone,
    },
    Balneaire = {
        Lot = { 14, 24 },
        Height = { 8, 20 },
        Gap = { 4, 9 },
        Fill = 0.85,
        Colors = { rgb(245, 240, 230), rgb(230, 225, 200), rgb(200, 225, 230) },
        Material = Enum.Material.Plaster,
    },
}

-- Emprises réservées (services) : aucun bâtiment de quartier dessus.
local reserved = {}
for _, placement in layout.Placements do
    table.insert(reserved, placement.Corners)
end
local function insideReserved(p: any): boolean
    for _, corners in reserved do
        if Geometry.pointInPolygon(p, corners) then
            return true
        end
    end
    return false
end

local MARGIN = 12.5
local buildings = 0
for _, cell in network.Cells do
    local style = STYLES[cell.Kind] or STYLES.Mixte
    local random = Geometry.random(cell.Seed)
    local polygon = cell.Corners
    local centerX, centerZ = 0, 0
    for _, c in polygon do
        centerX += c.X
        centerZ += c.Z
    end
    centerX /= #polygon
    centerZ /= #polygon
    local decor = sectorModel("Decor", centerX, centerZ, false)
    if cell.Park then
        -- Parc : pelouse et quelques arbres.
        local area = Geometry.polygonArea(polygon)
        part(decor, {
            Name = "Parc",
            Size = v3(math.sqrt(area) * 0.7, 0.1, math.sqrt(area) * 0.7),
            CFrame = CFrame.new(centerX * S, 0.06 * S, centerZ * S) * CFrame.Angles(0, -math.rad(cell.Rotation), 0),
            Color = rgb(110, 165, 90),
            Material = Enum.Material.Grass,
            Collide = false,
        })
        for _ = 1, 4 do
            local tx = centerX + Geometry.randomRange(random, -20, 20)
            local tz = centerZ + Geometry.randomRange(random, -20, 20)
            part(decor, {
                Name = "Tronc",
                Size = v3(0.5, 4, 0.5),
                CFrame = CFrame.new(tx * S, 2 * S, tz * S),
                Color = rgb(95, 70, 50),
                Material = Enum.Material.Wood,
            })
            part(decor, {
                Name = "Feuillage",
                Size = v3(4, 4, 4),
                CFrame = CFrame.new(tx * S, 5 * S, tz * S),
                Color = rgb(70, 125, 60),
                Material = Enum.Material.Grass,
                Shape = Enum.PartType.Ball,
                Collide = false,
            })
        end
        continue
    end
    local angle = math.rad(cell.Rotation)
    local ax = { X = math.cos(angle), Z = math.sin(angle) }
    local az = { X = -math.sin(angle), Z = math.cos(angle) }
    -- Boîte englobante dans le repère du quartier.
    local minU, maxU, minV, maxV = math.huge, -math.huge, math.huge, -math.huge
    for _, c in polygon do
        local u = c.X * ax.X + c.Z * ax.Z
        local v = c.X * az.X + c.Z * az.Z
        minU, maxU = math.min(minU, u), math.max(maxU, u)
        minV, maxV = math.min(minV, v), math.max(maxV, v)
    end
    local function inside(p: any): boolean
        if not Geometry.pointInPolygon(p, polygon) then
            return false
        end
        for k = 1, #polygon do
            -- Parenthèses : seule la distance compte (la fonction renvoie aussi t).
            if (Geometry.pointSegmentDistance(p, polygon[k], polygon[k % #polygon + 1])) < MARGIN then
                return false
            end
        end
        return not insideReserved(p)
    end
    local u = minU + MARGIN
    while u < maxU - MARGIN do
        local lotU = Geometry.randomRange(random, style.Lot[1], style.Lot[2])
        local v = minV + MARGIN
        while v < maxV - MARGIN do
            local lotV = Geometry.randomRange(random, style.Lot[1], style.Lot[2])
            local gap = Geometry.randomRange(random, style.Gap[1], style.Gap[2])
            local w, d = lotU - gap, lotV - gap
            local cu, cv = u + lotU / 2, v + lotV / 2
            local function world(du: number, dv: number): any
                return { X = ax.X * (cu + du) + az.X * (cv + dv), Z = ax.Z * (cu + du) + az.Z * (cv + dv) }
            end
            local ok = w > 5 and d > 5
            if ok then
                for _, c in { { -w / 2, -d / 2 }, { w / 2, -d / 2 }, { w / 2, d / 2 }, { -w / 2, d / 2 } } do
                    if not inside(world(c[1], c[2])) then
                        ok = false
                        break
                    end
                end
            end
            if ok and Geometry.nextRandom(random) < style.Fill then
                local height = Geometry.randomRange(random, style.Height[1], style.Height[2])
                local center = world(0, 0)
                local color = style.Colors[1 + math.floor(Geometry.nextRandom(random) * #style.Colors)]
                part(decor, {
                    Name = "Batiment",
                    Size = v3(w, height, d),
                    CFrame = CFrame.new(center.X * S, height / 2 * S, center.Z * S) * CFrame.Angles(0, -angle, 0),
                    Color = color,
                    Material = style.Material,
                })
                buildings += 1
            end
            v += lotV
        end
        u += lotU
    end
end

-- Arbres épars en campagne et en montagne (déterministes, loin des routes).
local treeRandom = Geometry.random(9001)
local trees = 0
for _ = 1, 900 do
    local x = Geometry.randomRange(treeRandom, -half + 50, half - 50)
    local z = Geometry.randomRange(treeRandom, -half + 50, half - 50)
    local zone = layout.ZoneOf(x, z)
    if (zone == "Campagne" or zone == "Montagnes" or zone == "Banlieues") and not inSea(x, z) then
        local clear = true
        for _, p in samples[cellKey(math.floor(x / CELL), math.floor(z / CELL))] or {} do
            if math.sqrt((x - p.X) ^ 2 + (z - p.Z) ^ 2) < p.Half + 8 then
                clear = false
                break
            end
        end
        if clear and not insideReserved({ X = x, Z = z }) then
            local decor = sectorModel("Decor", x, z, false)
            part(decor, {
                Name = "Tronc",
                Size = v3(0.6, 5, 0.6),
                CFrame = CFrame.new(x * S, 2.5 * S, z * S),
                Color = rgb(95, 70, 50),
                Material = Enum.Material.Wood,
            })
            part(decor, {
                Name = "Feuillage",
                Size = v3(5, 6, 5),
                CFrame = CFrame.new(x * S, 7 * S, z * S),
                Color = rgb(60, 110, 55),
                Material = Enum.Material.Grass,
                Shape = Enum.PartType.Ball,
                Collide = false,
            })
            trees += 1
        end
    end
end

-- ============================== HABILLAGE (lot 0.8) ==============================
-- Mobilier et accessoires propres à chaque zone, le long des routes, générés de
-- façon déterministe (graine par zone). Habillage/<zone>/<secteur> : modèles en
-- streaming normal ; le client règle leur visibilité selon la distance et la
-- qualité graphique (DetailLod). Accessoires non bloquants (aucune collision)
-- et sans ombre : ils ne gênent ni la conduite ni les performances. Lampadaires :
-- une source de lumière désactivée, allumée la nuit par le client (nombre limité).

local dressingRoot = folder(root, "Habillage")
root:SetAttribute("DressingVersion", "0.8.0")
local dressingCounts: { [string]: number } = {}

local function dressingModel(zone: string, x: number, z: number): any
    local i, j = math.floor(x / SECTOR), math.floor(z / SECTOR)
    local zoneFolder = folder(dressingRoot, zone)
    local name = string.format("Habillage_%d_%d", i, j)
    local existing = zoneFolder:FindFirstChild(name)
    if existing then
        return existing
    end
    local model = Instance.new("Model")
    model.Name = name
    model.ModelStreamingMode = Enum.ModelStreamingMode.Default
    model:SetAttribute("Sector", string.format("%d:%d", i, j))
    model:SetAttribute("AWDecorZone", zone)
    model:SetAttribute("Center", Vector3.new((i + 0.5) * SECTOR * S, 0, (j + 0.5) * SECTOR * S))
    model.Parent = zoneFolder
    return model
end

-- Pièce d'habillage : jamais bloquante, sans ombre portée.
local function prop(parent: any, name: string, size: any, cf: any, color: any, material: any?, shape: any?): any
    local p = part(parent, {
        Name = name,
        Size = size,
        CFrame = cf,
        Color = color,
        Material = material,
        Collide = false,
        Shape = shape,
    })
    p.CastShadow = false
    return p
end

-- Repère local d'un accessoire : position (m), cap (rad), altitude (m).
type Spot = { X: number, Z: number, Y: number, Heading: number }

local function at(spot: Spot, du: number, dy: number, dv: number): any
    -- du : latéral, dv : longitudinal (m) ; dy : hauteur au-dessus du sol (m).
    local c, s = math.cos(spot.Heading), math.sin(spot.Heading)
    local x = spot.X + du * c + dv * s
    local z = spot.Z - du * s + dv * c
    return CFrame.new(x * S, (spot.Y + dy) * S, z * S) * CFrame.Angles(0, spot.Heading, 0)
end

local CYL = Enum.PartType.Cylinder
local BALL = Enum.PartType.Ball
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylindre debout

local function streetLamp(m: any, spot: Spot, warm: boolean)
    prop(m, "Mat", v3(0.25, 6, 0.25), at(spot, 0, 3, 0), rgb(70, 74, 80), Enum.Material.Metal)
    prop(m, "Potence", v3(1.6, 0.15, 0.2), at(spot, -0.8, 6, 0), rgb(70, 74, 80), Enum.Material.Metal)
    local head = prop(m, "Lanterne", v3(0.6, 0.2, 0.4), at(spot, -1.5, 5.9, 0), rgb(240, 236, 220), Enum.Material.Glass)
    head:SetAttribute("AWStreetLight", true)
    local light = Instance.new("PointLight")
    light.Name = "Lumiere"
    light.Enabled = false
    light.Range = 40
    light.Brightness = 1.4
    light.Color = if warm then rgb(255, 214, 160) else rgb(225, 235, 255)
    light.Shadows = false
    light.Parent = head
end

local function tree(m: any, spot: Spot, trunk: number, crown: number, color: any)
    prop(m, "Tronc", v3(0.4, trunk, 0.4), at(spot, 0, trunk / 2, 0), rgb(95, 70, 50), Enum.Material.Wood)
    prop(
        m,
        "Feuillage",
        v3(crown, crown, crown),
        at(spot, 0, trunk + crown * 0.35, 0),
        color,
        Enum.Material.Grass,
        BALL
    )
end

-- Accessoires par zone : (modèle, repère, aléa). Teintes : ArtDirection (palette).
local ZONE_PROPS: { [string]: { Spacing: number, Max: number, Build: (any, Spot, any) -> () } } = {
    Metropole = {
        Spacing = 34,
        Max = 900,
        Build = function(m, spot, random)
            local roll = Geometry.randomRange(random, 0, 1)
            if roll < 0.55 then
                streetLamp(m, spot, true)
            elseif roll < 0.75 then
                -- Abri de bus.
                prop(m, "AbriToit", v3(3.2, 0.12, 1.4), at(spot, 0, 2.4, 0), rgb(60, 64, 70), Enum.Material.Metal)
                prop(m, "AbriVitre", v3(3.2, 2.2, 0.06), at(spot, 0.6, 1.2, 0), rgb(190, 215, 230), Enum.Material.Glass).Transparency =
                    0.6
                prop(m, "AbriBanc", v3(2.4, 0.1, 0.4), at(spot, 0.3, 0.45, 0), rgb(150, 110, 70), Enum.Material.Wood)
            elseif roll < 0.9 then
                prop(
                    m,
                    "Jardiniere",
                    v3(1.6, 0.6, 0.8),
                    at(spot, 0, 0.3, 0),
                    rgb(120, 118, 112),
                    Enum.Material.Concrete
                )
                prop(m, "Massif", v3(1.4, 0.5, 0.6), at(spot, 0, 0.8, 0), rgb(80, 135, 70), Enum.Material.Grass)
            else
                for k = -1, 1 do
                    prop(
                        m,
                        "Potelet",
                        v3(0.6, 0.15, 0.15),
                        at(spot, 0, 0.3, k * 1.2) * UPRIGHT,
                        rgb(40, 42, 46),
                        Enum.Material.Metal,
                        CYL
                    )
                end
            end
        end,
    },
    Banlieues = {
        Spacing = 30,
        Max = 900,
        Build = function(m, spot, random)
            local roll = Geometry.randomRange(random, 0, 1)
            if roll < 0.3 then
                streetLamp(m, spot, true)
            elseif roll < 0.6 then
                prop(m, "Haie", v3(0.8, 1.1, 4), at(spot, 0.5, 0.55, 0), rgb(70, 120, 60), Enum.Material.Grass)
            elseif roll < 0.8 then
                prop(
                    m,
                    "BoiteAuxLettres",
                    v3(0.35, 0.3, 0.5),
                    at(spot, 0, 1, 0),
                    rgb(200, 190, 60),
                    Enum.Material.Metal
                )
                prop(m, "Piquet", v3(0.08, 0.9, 0.08), at(spot, 0, 0.45, 0), rgb(90, 90, 90), Enum.Material.Metal)
            else
                tree(m, spot, 2.6, 3, rgb(85, 140, 70))
            end
        end,
    },
    Docks = {
        Spacing = 40,
        Max = 400,
        Build = function(m, spot, random)
            local roll = Geometry.randomRange(random, 0, 1)
            if roll < 0.5 then
                -- Conteneurs empilés (teintes industrielles).
                local palette = { rgb(170, 60, 45), rgb(40, 90, 150), rgb(60, 120, 70), rgb(200, 150, 40) }
                local stack = 1 + math.floor(Geometry.randomRange(random, 0, 2.99))
                for level = 0, stack - 1 do
                    local color = palette[1 + math.floor(Geometry.randomRange(random, 0, 3.99))]
                    prop(
                        m,
                        "Conteneur",
                        v3(2.44, 2.59, 6.06),
                        at(spot, 3, 1.3 + level * 2.6, 0),
                        color,
                        Enum.Material.CorrodedMetal
                    )
                end
            elseif roll < 0.75 then
                prop(m, "Caisse", v3(1.2, 1.2, 1.2), at(spot, 1, 0.6, 0), rgb(150, 115, 70), Enum.Material.WoodPlanks)
                prop(m, "Caisse", v3(1, 1, 1), at(spot, 1, 1.7, 0.1), rgb(140, 105, 65), Enum.Material.WoodPlanks)
            else
                streetLamp(m, spot, false)
            end
        end,
    },
    Montagnes = {
        Spacing = 28,
        Max = 500,
        Build = function(m, spot, random)
            local roll = Geometry.randomRange(random, 0, 1)
            if roll < 0.5 then
                -- Conifère : tronc et étages de feuillage.
                prop(m, "Tronc", v3(0.4, 3, 0.4), at(spot, 1.5, 1.5, 0), rgb(85, 60, 45), Enum.Material.Wood)
                for k = 0, 2 do
                    local size = 3.4 - k * 0.9
                    prop(
                        m,
                        "Aiguilles",
                        v3(size, 1.6, size),
                        at(spot, 1.5, 2.6 + k * 1.3, 0),
                        rgb(40, 85, 55),
                        Enum.Material.Grass
                    )
                end
            elseif roll < 0.8 then
                local size = Geometry.randomRange(random, 1, 2.5)
                prop(
                    m,
                    "Rocher",
                    v3(size, size * 0.7, size * 1.2),
                    at(spot, 2, size * 0.3, 0),
                    rgb(120, 118, 115),
                    Enum.Material.Slate
                )
            else
                -- Jalon à neige (rouge et blanc).
                prop(
                    m,
                    "Jalon",
                    v3(0.1, 1.8, 0.1),
                    at(spot, 0.2, 0.9, 0),
                    rgb(220, 50, 40),
                    Enum.Material.SmoothPlastic
                )
            end
        end,
    },
    Campagne = {
        Spacing = 36,
        Max = 600,
        Build = function(m, spot, random)
            local roll = Geometry.randomRange(random, 0, 1)
            if roll < 0.35 then
                -- Botte de foin couchée.
                prop(
                    m,
                    "BotteDeFoin",
                    v3(1.2, 1.5, 1.5),
                    at(spot, 4, 0.75, 0),
                    rgb(215, 185, 105),
                    Enum.Material.Fabric,
                    CYL
                )
            elseif roll < 0.65 then
                for k = -2, 2 do
                    prop(
                        m,
                        "Piquet",
                        v3(0.12, 1, 0.12),
                        at(spot, 0.5, 0.5, k * 2),
                        rgb(120, 95, 65),
                        Enum.Material.Wood
                    )
                end
                prop(m, "Lisse", v3(0.06, 0.08, 8), at(spot, 0.5, 0.8, 0), rgb(130, 100, 70), Enum.Material.Wood)
            else
                -- Peuplier élancé.
                prop(m, "Tronc", v3(0.35, 4, 0.35), at(spot, 2, 2, 0), rgb(110, 90, 70), Enum.Material.Wood)
                prop(m, "Feuillage", v3(1.8, 5, 1.8), at(spot, 2, 5.5, 0), rgb(95, 145, 70), Enum.Material.Grass)
            end
        end,
    },
    Motorsport = {
        Spacing = 22,
        Max = 300,
        Build = function(m, spot, random)
            local roll = Geometry.randomRange(random, 0, 1)
            if roll < 0.5 then
                -- Pile de pneus (protection).
                for level = 0, 2 do
                    prop(
                        m,
                        "Pneu",
                        v3(0.3, 0.65, 0.65),
                        at(spot, 1.2, 0.15 + level * 0.3, 0) * UPRIGHT,
                        rgb(30, 30, 32),
                        Enum.Material.Rubber,
                        CYL
                    )
                end
            elseif roll < 0.8 then
                -- Banderole aux couleurs du circuit (sans marque).
                prop(
                    m,
                    "Banderole",
                    v3(0.06, 0.8, 4),
                    at(spot, 1.4, 0.8, 0),
                    if roll < 0.65 then rgb(230, 230, 235) else rgb(220, 60, 50),
                    Enum.Material.Fabric
                )
            else
                -- Poste de commissaire.
                prop(
                    m,
                    "Poste",
                    v3(1.2, 2.2, 1.2),
                    at(spot, 2.5, 1.1, 0),
                    rgb(240, 240, 240),
                    Enum.Material.SmoothPlastic
                )
                prop(m, "PosteToit", v3(1.5, 0.12, 1.5), at(spot, 2.5, 2.25, 0), rgb(230, 120, 40), Enum.Material.Metal)
            end
        end,
    },
    Littoral = {
        Spacing = 32,
        Max = 400,
        Build = function(m, spot, random)
            local roll = Geometry.randomRange(random, 0, 1)
            if roll < 0.45 then
                -- Palmier : stipe incliné et palmes.
                prop(
                    m,
                    "Stipe",
                    v3(0.35, 5, 0.35),
                    at(spot, 2, 2.5, 0) * CFrame.Angles(0, 0, math.rad(6)),
                    rgb(140, 110, 80),
                    Enum.Material.Wood
                )
                for k = 0, 3 do
                    local frond = at(spot, 2.3, 5.1, 0) * CFrame.Angles(0, k * math.pi / 2, math.rad(18))
                    prop(
                        m,
                        "Palme",
                        v3(0.1, 0.4, 2.6),
                        frond * CFrame.new(0, 0, 1.2 * S),
                        rgb(70, 140, 60),
                        Enum.Material.Grass
                    )
                end
            elseif roll < 0.75 then
                streetLamp(m, spot, false)
            else
                prop(m, "Parasol", v3(0.08, 2.2, 0.08), at(spot, 3, 1.1, 0), rgb(230, 230, 230), Enum.Material.Metal)
                prop(
                    m,
                    "Toile",
                    v3(0.2, 2.2, 2.2),
                    at(spot, 3, 2.2, 0) * UPRIGHT,
                    if roll < 0.87 then rgb(230, 90, 70) else rgb(60, 140, 200),
                    Enum.Material.Fabric,
                    CYL
                )
            end
        end,
    },
}

-- Vrai si un point est trop près d'une chaussée (autre que la sienne).
local function onRoad(x: number, z: number, margin: number): boolean
    for _, p in samples[cellKey(math.floor(x / CELL), math.floor(z / CELL))] or {} do
        if math.sqrt((x - p.X) ^ 2 + (z - p.Z) ^ 2) < p.Half + margin then
            return true
        end
    end
    return false
end

local ZONE_ORDER = { "Metropole", "Banlieues", "Docks", "Montagnes", "Campagne", "Motorsport", "Littoral" }
for zoneIndex, zone in ZONE_ORDER do
    local spec = ZONE_PROPS[zone]
    local random = Geometry.random(8000 + zoneIndex)
    local count = 0
    for _, edge in layout.Edges do
        if edge.Zone ~= zone or count >= spec.Max then
            continue
        end
        local polyline = edge.Polyline
        local carried = Geometry.randomRange(random, 0, spec.Spacing)
        local side = 1
        for k = 2, #polyline do
            local a, b = polyline[k - 1], polyline[k]
            local length = Geometry.distance(a, b)
            if length < 0.01 then
                continue
            end
            local dx, dz = (b.X - a.X) / length, (b.Z - a.Z) / length
            local heading = math.atan2(dx, dz)
            local distance = carried
            while distance < length and count < spec.Max do
                local t = distance / length
                local offset = edge.CorridorM / 2 + 1.5
                -- Normale à gauche / à droite selon le côté, en alternance.
                local x = a.X + (b.X - a.X) * t + dz * offset * side
                local z = a.Z + (b.Z - a.Z) * t - dx * offset * side
                local y = a.Y + (b.Y - a.Y) * t
                local spot = { X = x, Z = z, Y = y, Heading = heading + (if side > 0 then 0 else math.pi) }
                if
                    not onRoad(x, z, 0.5)
                    and not insideReserved({ X = x, Z = z })
                    and (zone == "Littoral" or not inSea(x, z))
                then
                    spec.Build(dressingModel(zone, x, z), spot, random)
                    count += 1
                end
                side = -side
                distance += spec.Spacing
            end
            carried = distance - length
        end
    end
    dressingCounts[zone] = count
end
local dressingTotal = 0
for _, n in dressingCounts do
    dressingTotal += n
end
root:SetAttribute("DressingProps", dressingTotal)
do
    local parts = {}
    for _, zone in ZONE_ORDER do
        table.insert(parts, string.format("%s %d", zone, dressingCounts[zone] or 0))
        dressingRoot:SetAttribute("Props_" .. zone, dressingCounts[zone] or 0)
    end
    print("Habillage par zone : " .. table.concat(parts, ", "))
end

-- ============================== SERVICES ==============================

local SERVICE_COLORS = {
    Dealership = rgb(225, 230, 235),
    PublicGarage = rgb(200, 120, 60),
    FuelStation = rgb(230, 60, 50),
    CarWash = rgb(70, 150, 220),
    ChargingHub = rgb(60, 190, 140),
    Parking = rgb(90, 92, 96),
    PropertySlot = rgb(160, 200, 120),
    ResidentialGarageSlot = rgb(180, 170, 150),
    SocialSpot = rgb(210, 170, 90),
    FleetParking = rgb(255, 140, 40),
    PlayerSpawn = rgb(70, 130, 180),
    DriftPad = rgb(60, 62, 66),
}

-- Repère local d'un service : origine au centre, -Z vers la route (entrée).
local function serviceFrame(placement: any): any
    local c = placement.Center
    local origin = Vector3.new(c.X * S, c.Y * S, c.Z * S)
    local facing = Vector3.new(placement.Facing.X, 0, placement.Facing.Z)
    return CFrame.lookAt(origin, origin + facing)
end

-- Bâtiment creux : quatre murs (ouverture côté entrée), toit ; dimensions en m.
local function shell(
    model: any,
    frame: any,
    offsetZ: number,
    width: number,
    depth: number,
    height: number,
    color: any,
    material: any,
    doorWidth: number
)
    local wall = 0.3
    local function block(
        name: string,
        sx: number,
        sy: number,
        sz: number,
        x: number,
        y: number,
        z: number,
        transparency: number?
    )
        local p = part(model, {
            Name = name,
            Size = v3(sx, sy, sz),
            CFrame = frame * CFrame.new(x * S, y * S, z * S),
            Color = color,
            Material = material,
        })
        p.Transparency = transparency or 0
        return p
    end
    local front = offsetZ - depth / 2
    local back = offsetZ + depth / 2
    -- Façade : deux pans et un linteau (ouverture d'accès des véhicules).
    local side = (width - doorWidth) / 2
    if side > 0.5 then
        block("Facade", side, height, wall, -(doorWidth / 2 + side / 2), height / 2, front)
        block("Facade", side, height, wall, doorWidth / 2 + side / 2, height / 2, front)
    end
    block("Linteau", doorWidth, math.max(height - 4.5, 0.5), wall, 0, height - math.max(height - 4.5, 0.5) / 2, front)
    block("MurFond", width, height, wall, 0, height / 2, back)
    block("MurGauche", wall, height, depth, -width / 2, height / 2, offsetZ)
    block("MurDroit", wall, height, depth, width / 2, height / 2, offsetZ)
    block("Toit", width + 0.6, 0.4, depth + 0.6, 0, height + 0.2, offsetZ)
end

for _, placement in layout.Placements do
    local model = Instance.new("Model")
    model.Name = placement.Id
    model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
    model:SetAttribute("ServiceId", placement.Id)
    model:SetAttribute("Kind", placement.Kind)
    model:SetAttribute("Zone", placement.Zone)
    model:SetAttribute("DisplayName", placement.Name)
    model:SetAttribute("Chargers", placement.Chargers)
    model:SetAttribute("Pumps", placement.Pumps)
    model:SetAttribute("Stalls", placement.Stalls)
    model:SetAttribute("MapVersion", WorldConfig.MapVersion)
    model:AddTag("AWService")
    model.Parent = if placement.Kind == "PlayerSpawn" or placement.Kind == "FleetParking"
        then groups.Apparitions
        else groups.Services

    local frame = serviceFrame(placement)
    local w, d = placement.Width, placement.Depth
    local color = SERVICE_COLORS[placement.Kind] or rgb(180, 180, 180)
    -- Dalle d'accès (au niveau de la route) et socle si le terrain est plus bas.
    local slab = part(model, {
        Name = "Dalle",
        Size = v3(w, 0.6, d),
        CFrame = frame * CFrame.new(0, -0.24 * S, 0),
        Color = rgb(80, 82, 86),
        Material = Enum.Material.Asphalt,
    })
    model.PrimaryPart = slab
    if placement.Center.Y > 1 then
        part(model, {
            Name = "Socle",
            Size = v3(w, math.min(placement.Center.Y, 30), d),
            CFrame = frame * CFrame.new(0, (-0.55 - math.min(placement.Center.Y, 30) / 2) * S, 0),
            Color = rgb(110, 105, 95),
            Material = Enum.Material.Ground,
        })
    end

    local kind = placement.Kind
    if kind == "Dealership" then
        shell(model, frame, d * 0.15, w * 0.6, d * 0.6, 7, color, Enum.Material.Glass, 8)
        for k = 1, math.min(placement.Stalls, 8) do
            part(model, {
                Name = "Exposition",
                Size = v3(0.15, 0.03, 5),
                CFrame = frame * CFrame.new((-w / 2 + k * w / 9) * S, 0.08 * S, (-d / 2 + 4) * S),
                Color = MARKING,
                Collide = false,
            })
        end
    elseif kind == "PublicGarage" or kind == "ResidentialGarageSlot" then
        shell(
            model,
            frame,
            d * 0.1,
            w * 0.8,
            d * 0.7,
            if kind == "PublicGarage" then 7 else 3.5,
            color,
            Enum.Material.Concrete,
            if kind == "PublicGarage" then 10 else 4
        )
    elseif kind == "CarWash" then
        -- Tunnel de lavage ouvert aux deux bouts.
        local tunnelW, tunnelD = math.min(8, w * 0.5), d * 0.8
        for _, side in { -1, 1 } do
            part(model, {
                Name = "Paroi",
                Size = v3(0.4, 4.5, tunnelD),
                CFrame = frame * CFrame.new(side * tunnelW / 2 * S, 2.25 * S, 0),
                Color = color,
                Material = Enum.Material.Glass,
            })
        end
        part(model, {
            Name = "Toit",
            Size = v3(tunnelW + 0.8, 0.4, tunnelD),
            CFrame = frame * CFrame.new(0, 4.7 * S, 0),
            Color = color,
        })
    elseif kind == "FuelStation" or kind == "ChargingHub" then
        local canopyW, canopyD = w * 0.7, d * 0.45
        for _, sx in { -1, 1 } do
            for _, sz in { -1, 1 } do
                part(model, {
                    Name = "Pilier",
                    Size = v3(0.5, 5, 0.5),
                    CFrame = frame * CFrame.new(sx * canopyW / 2.3 * S, 2.5 * S, (sz * canopyD / 2.5 - d * 0.1) * S),
                    Color = rgb(200, 200, 200),
                    Material = Enum.Material.Metal,
                })
            end
        end
        part(model, {
            Name = "Auvent",
            Size = v3(canopyW, 0.6, canopyD),
            CFrame = frame * CFrame.new(0, 5.3 * S, -d * 0.1 * S),
            Color = color,
        })
        for k = 1, placement.Pumps do
            local x = -canopyW / 2 + k * canopyW / (placement.Pumps + 1)
            local pump = part(model, {
                Name = "Pompe",
                Size = v3(0.8, 1.8, 0.6),
                CFrame = frame * CFrame.new(x * S, 0.9 * S, -d * 0.1 * S),
                Color = rgb(240, 240, 240),
            })
            pump:SetAttribute("PumpIndex", k)
            pump:AddTag("AWFuelPump")
        end
        -- Bornes de recharge sur des places réservées aux véhicules électriques.
        for k = 1, placement.Chargers do
            local x = -w / 2 + k * w / (placement.Chargers + 1)
            local charger = part(model, {
                Name = "Borne",
                Size = v3(0.6, 1.6, 0.4),
                CFrame = frame * CFrame.new(x * S, 0.8 * S, (d / 2 - 1) * S),
                Color = rgb(40, 200, 150),
            })
            charger:SetAttribute("ChargerIndex", k)
            charger:SetAttribute("ServiceId", placement.Id)
            charger:AddTag("AWCharger")
            part(model, {
                Name = "PlaceElectrique",
                Size = v3(2.8, 0.03, 5.2),
                CFrame = frame * CFrame.new(x * S, 0.07 * S, (d / 2 - 4.2) * S),
                Color = rgb(60, 190, 140),
                Collide = false,
            })
        end
        if kind == "FuelStation" then
            shell(model, frame, d * 0.32, w * 0.3, d * 0.3, 4, rgb(235, 235, 230), Enum.Material.Concrete, 3)
        end
    elseif kind == "FleetParking" then
        for k = 1, placement.Stalls do
            -- Plots du parc des prototypes (lus par le service des véhicules).
            local x = -w / 2 + k * w / (placement.Stalls + 1)
            local slot = part(model, {
                Name = "Plot" .. k,
                Size = v3(4, 0.05, 7),
                CFrame = frame * CFrame.new(x * S, 0.08 * S, 0),
                Color = rgb(90, 150, 90),
                Collide = false,
            })
            slot.CanQuery = false
            slot:SetAttribute("SlotIndex", k)
            slot:AddTag("AWFleetSlot")
        end
    elseif kind == "PlayerSpawn" then
        local spawn = Instance.new("SpawnLocation")
        spawn.Name = "Apparition"
        spawn.Anchored = true
        spawn.Neutral = true
        spawn.Duration = 0
        spawn.Size = v3(4, 0.3, 4)
        spawn.CFrame = frame * CFrame.new(0, 0.2 * S, 0)
        spawn.Color = color
        spawn.Material = Enum.Material.SmoothPlastic
        spawn.Parent = model
        stats.Parts += 1
    elseif kind == "PropertySlot" then
        -- Emplacement réservé : clôture basse et panneau (propriétés : lot 0.4).
        for _, side in { -1, 1 } do
            part(model, {
                Name = "Cloture",
                Size = v3(0.2, 1, d),
                CFrame = frame * CFrame.new(side * w / 2 * S, 0.5 * S, 0),
                Color = color,
                Material = Enum.Material.Wood,
            })
        end
        part(model, {
            Name = "Cloture",
            Size = v3(w, 1, 0.2),
            CFrame = frame * CFrame.new(0, 0.5 * S, d / 2 * S),
            Color = color,
            Material = Enum.Material.Wood,
        })
    elseif kind == "DriftPad" then
        for _, radius in { 20, 45 } do
            part(model, {
                Name = "Cercle",
                Size = v3(0.03, radius * 2, radius * 2),
                CFrame = frame * CFrame.new(0, 0.07 * S, 0) * CFrame.Angles(0, 0, math.pi / 2),
                Color = MARKING,
                Collide = false,
                Shape = Enum.PartType.Cylinder,
                Transparency = 0.6,
            })
        end
    end

    -- Panneau d'identification face à la route.
    part(model, {
        Name = "Enseigne",
        Size = v3(math.min(w * 0.4, 12), 2, 0.3),
        CFrame = frame * CFrame.new(w * 0.35 * S, 4 * S, (-d / 2 + 1) * S),
        Color = color,
        Material = Enum.Material.Neon,
        Collide = false,
    })
end

-- ============================== ÉCRITURE ==============================

-- Garde-fou : aucune pièce au-delà de la taille maximale du moteur (2 048 studs).
local MAX_PART_STUDS = 2048
local oversized = 0
for _, item in root:GetDescendants() do
    if item:IsA("BasePart") then
        local size = item.Size
        if math.max(size.X, size.Y, size.Z) > MAX_PART_STUDS then
            oversized += 1
            if oversized <= 5 then
                print(string.format("Pièce trop grande : %s (%s)", item:GetFullName(), tostring(size)))
            end
        end
    end
end
if oversized > 0 then
    error(string.format("%d pièce(s) dépassent %d studs : le moteur les raccourcirait", oversized, MAX_PART_STUDS))
end

root:SetAttribute("Parts", stats.Parts)
local data = roblox.serializeModel({ root })
local directory = string.match(outputPath :: string, "^(.*)[/\\]") or "."
if not fs.isDir(directory) then
    fs.writeDir(directory)
end
fs.writeFile(outputPath :: string, data)
print(
    string.format(
        "Carte %s générée : %d pièces (%d bâtiments, %d cellules de relief, %d arbres, %d accessoires d'habillage), %d services, %.1f Mo → %s",
        WorldConfig.MapVersion,
        stats.Parts,
        buildings,
        reliefCells,
        trees,
        dressingTotal,
        #layout.Placements,
        #data / 1e6,
        outputPath :: string
    )
)
