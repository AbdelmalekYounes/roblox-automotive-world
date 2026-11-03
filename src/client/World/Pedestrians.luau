--!strict
-- Piétons du monde ouvert, rendus localement autour de la caméra (lot 0.3).
-- Positions déterministes (World/PedestrianModel) : tous les clients voient les
-- mêmes passants au même endroit, sans échange réseau. Nombre plafonné
-- (MAX_VISIBLE) et rayon limité (RADIUS_M) pour borner le coût de rendu.
-- Figurants NON SOLIDES : ni collision, ni requête, ni contact (ils ne
-- perturbent jamais les lancers de rayon des suspensions).

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldShared = Shared:WaitForChild("World")
local WorldLayout = require(WorldShared:WaitForChild("WorldLayout"))
local PedestrianModel = require(WorldShared:WaitForChild("PedestrianModel"))
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))

local Pedestrians = {}

local S = 1 / Constants.MetersPerStud
local UPDATE_INTERVAL_S = 0.1
local RADIUS_M = 150
local MAX_VISIBLE = 60
local CELL_M = 200
local BODY = Vector3.new(0.45, 1.25, 0.3) * S
local HEAD = Vector3.new(0.25, 0.25, 0.25) * S
local CLOTHES = {
    Color3.fromRGB(60, 70, 110),
    Color3.fromRGB(150, 60, 50),
    Color3.fromRGB(70, 110, 70),
    Color3.fromRGB(200, 190, 160),
    Color3.fromRGB(40, 40, 45),
    Color3.fromRGB(120, 90, 140),
}

type Figure = { Body: BasePart, Head: BasePart }

local function cellKey(x: number, z: number): string
    return math.floor(x / CELL_M) .. ":" .. math.floor(z / CELL_M)
end

local function makePart(name: string, size: Vector3, color: Color3, parent: Instance): BasePart
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.Color = color
    part.Material = Enum.Material.SmoothPlastic
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Parent = parent
    return part
end

function Pedestrians.start()
    -- Index spatial des trottoirs (une seule fois, à partir des données de carte).
    local layout = WorldLayout.get()
    local cells: { [string]: { PedestrianModel.Sidewalk } } = {}
    for _, edge in layout.Edges do
        for _, sidewalk in PedestrianModel.sidewalks(edge) do
            local seen: { [string]: boolean } = {}
            for _, p in sidewalk.Path.Points do
                local key = cellKey(p.X, p.Z)
                if not seen[key] then
                    seen[key] = true
                    local list = cells[key]
                    if list == nil then
                        list = {}
                        cells[key] = list
                    end
                    table.insert(list, sidewalk)
                end
            end
        end
    end

    local folder = Instance.new("Folder")
    folder.Name = "PietonsLocaux"
    folder.Parent = Workspace
    local active: { [string]: Figure } = {}
    local pool: { Figure } = {}
    local random = Random.new(7)

    local function acquire(): Figure
        local figure = table.remove(pool)
        if figure then
            figure.Body.Transparency = 0
            figure.Head.Transparency = 0
            return figure
        end
        local color = CLOTHES[random:NextInteger(1, #CLOTHES)]
        return {
            Body = makePart("Pieton", BODY, color, folder),
            Head = makePart("Tete", HEAD, Color3.fromRGB(225, 190, 160), folder),
        }
    end

    local function release(figure: Figure)
        figure.Body.Transparency = 1
        figure.Head.Transparency = 1
        table.insert(pool, figure)
    end

    local accumulator = 0
    RunService.Heartbeat:Connect(function(dt)
        accumulator += dt
        if accumulator < UPDATE_INTERVAL_S then
            return
        end
        accumulator = 0
        local camera = Workspace.CurrentCamera
        if camera == nil then
            return
        end
        local origin = camera.CFrame.Position / S
        local now = Workspace:GetServerTimeNow()

        -- Trottoirs des cellules voisines, sans doublon.
        local candidates: { { Walker: PedestrianModel.Walker, Distance: number } } = {}
        local visited: { [PedestrianModel.Sidewalk]: boolean } = {}
        local span = math.ceil(RADIUS_M / CELL_M)
        local cx, cz = math.floor(origin.X / CELL_M), math.floor(origin.Z / CELL_M)
        for i = cx - span, cx + span do
            for j = cz - span, cz + span do
                local list: { PedestrianModel.Sidewalk } = cells[i .. ":" .. j] or {}
                for _, sidewalk in list do
                    if visited[sidewalk] then
                        continue
                    end
                    visited[sidewalk] = true
                    for _, walker in PedestrianModel.walkers(sidewalk, now) do
                        local p = walker.Position
                        local distance = math.sqrt((p.X - origin.X) ^ 2 + (p.Z - origin.Z) ^ 2)
                        if distance < RADIUS_M then
                            table.insert(candidates, { Walker = walker, Distance = distance })
                        end
                    end
                end
            end
        end
        table.sort(candidates, function(a, b)
            return a.Distance < b.Distance
        end)

        local keep: { [string]: boolean } = {}
        local parts: { BasePart } = {}
        local frames: { CFrame } = {}
        for index = 1, math.min(#candidates, MAX_VISIBLE) do
            local walker = candidates[index].Walker
            keep[walker.Key] = true
            local figure = active[walker.Key]
            if figure == nil then
                figure = acquire()
                active[walker.Key] = figure
            end
            local p = walker.Position
            local base = Vector3.new(p.X * S, p.Y * S, p.Z * S)
            local look = Vector3.new(walker.Heading.X, 0, walker.Heading.Z)
            local bodyFrame =
                CFrame.lookAt(base + Vector3.new(0, BODY.Y / 2, 0), base + Vector3.new(0, BODY.Y / 2, 0) + look)
            table.insert(parts, figure.Body)
            table.insert(frames, bodyFrame)
            table.insert(parts, figure.Head)
            table.insert(frames, bodyFrame * CFrame.new(0, (BODY.Y + HEAD.Y) / 2, 0))
        end
        for key, figure in active do
            if not keep[key] then
                active[key] = nil
                release(figure)
            end
        end
        Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
    end)
end

return table.freeze(Pedestrians)
