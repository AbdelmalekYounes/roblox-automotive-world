--!strict
--[[
    Piétons du monde ouvert, rendus localement autour de la caméra (lot 0.3, silhouettes articulées au lot PNJ-01).

    Positions déterministes (World/PedestrianModel) : tous les clients voient les mêmes passants au même endroit,
    avec la même apparence (World/PnjKits.look), sans échange réseau. Nombre plafonné (MAX_VISIBLE) et rayon limité
    (RADIUS_M) pour borner le coût de rendu.

    Lot PNJ-01 : chaque piéton est une silhouette en 11 pièces rigides (gabarit 3D découpé du dossier
    ReplicatedStorage.AutomotiveWorldPnjKits s'il est présent et autorisé par le manifeste, sinon pièces simples aux
    mêmes noms) animée par le code (World/PedestrianGait) : la phase de marche suit la distance parcourue, donc les
    pieds ne glissent pas. Fréquence d'animation selon la distance (NEAR_M : chaque image ; au-delà : MID_HZ).

    Figurants NON SOLIDES : ni collision, ni requête, ni contact (ils ne perturbent jamais les lancers de rayon des
    suspensions).
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldShared = Shared:WaitForChild("World")
local WorldLayout = require(WorldShared:WaitForChild("WorldLayout"))
local PedestrianModel = require(WorldShared:WaitForChild("PedestrianModel"))
local PedestrianGait = require(WorldShared:WaitForChild("PedestrianGait"))
local PnjKits = require(WorldShared:WaitForChild("PnjKits"))
local AssetManifest = require(Shared:WaitForChild("Assets"):WaitForChild("AssetManifest"))
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))

local Pedestrians = {}

local S = 1 / Constants.MetersPerStud
local SELECT_INTERVAL_S = 0.1 -- choix des piétons visibles
local RADIUS_M = 150
local MAX_VISIBLE = 60
local CELL_M = 200
-- Animation à chaque image jusqu'à NEAR_M ; au-delà, MID_HZ images par seconde.
local NEAR_M = 50
local MID_HZ = 12
-- Vitesse de rotation maximale du corps (rad/s) : demi-tour progressif au bout du trottoir.
local TURN_RATE = 5

type Active = {
    Sidewalk: PedestrianModel.Sidewalk,
    Index: number,
    Distance: number,
}

type Figure = {
    Parts: { BasePart },
    Joints: { string }, -- articulation de chaque pièce (même ordre)
    Rest: { CFrame }, -- repère de repos de chaque pièce (repère piéton, m)
    Scale: number,
    Morphology: string,
    Yaw: number?, -- cap affiché (rad), lissé
    LastAnimated: number,
}

local function cellKey(x: number, z: number): string
    return math.floor(x / CELL_M) .. ":" .. math.floor(z / CELL_M)
end

local function assetNumber(content: string): number?
    local digits = string.match(content, "(%d+)%s*$")
    return if digits then tonumber(digits) else nil
end

-- Gabarit 3D d'une morphologie s'il est présent, complet et autorisé par le manifeste ; sinon nil (repli).
local function pedestrianTemplate(morph: PnjKits.Morphology): Model?
    local folder = ReplicatedStorage:FindFirstChild(PnjKits.FolderName)
    local model = folder and folder:FindFirstChild(morph.Template)
    if model == nil or not model:IsA("Model") then
        return nil
    end
    local allowed: { [number]: boolean } = {}
    local entry = AssetManifest.get(PnjKits.PedestrianManifestId)
    if entry and entry.RobloxAssetIds then
        for _, id in entry.RobloxAssetIds do
            allowed[id] = true
        end
    end
    local names: { [string]: boolean } = {}
    for _, item in model:GetDescendants() do
        if item:IsA("MeshPart") then
            local id = assetNumber(item.MeshId)
            if id == nil or not allowed[id] then
                return nil
            end
        end
        if item:IsA("BasePart") then
            names[item.Name] = true
        end
    end
    if #PnjKits.missingPedestrianParts(names) > 0 then
        return nil
    end
    return model
end

local function prepare(part: BasePart, parent: Instance)
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Parent = parent
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

    local templates: { [string]: Model } = {}
    for _, morph in PnjKits.Morphologies do
        local template = pedestrianTemplate(morph)
        if template then
            templates[morph.Id] = template
        end
    end

    -- Réserve de silhouettes par morphologie (aucune création ni destruction en régime établi).
    local pools: { [string]: { Figure } } = {}
    local hiddenFrame = CFrame.new(0, -10000, 0)

    local function build(morph: PnjKits.Morphology): Figure
        local figure: Figure = {
            Parts = {},
            Joints = {},
            Rest = {},
            Scale = morph.Scale,
            Morphology = morph.Id,
            Yaw = nil,
            LastAnimated = 0,
        }
        local template = templates[morph.Id]
        local pivot = if template then template:GetPivot() else CFrame.identity
        for _, segment in PnjKits.Segments do
            local part: BasePart
            local rest: CFrame
            if template then
                local source = template:FindFirstChild(segment.Name, true) :: BasePart
                part = source:Clone()
                -- Repos mesuré sur le gabarit (pivot = origine du piéton, au sol entre les pieds), en mètres.
                local relative = pivot:ToObjectSpace(source.CFrame)
                rest = relative.Rotation + relative.Position / S
            else
                local p = Instance.new("Part")
                p.Size = segment.Size * morph.Scale * S
                p.Material = Enum.Material.SmoothPlastic
                p.TopSurface = Enum.SurfaceType.Smooth
                p.BottomSurface = Enum.SurfaceType.Smooth
                part = p
                rest = CFrame.new(segment.Center * morph.Scale)
            end
            part.Name = segment.Name
            prepare(part, folder)
            table.insert(figure.Parts, part)
            table.insert(figure.Joints, segment.Joint)
            table.insert(figure.Rest, rest)
        end
        return figure
    end

    local function dress(figure: Figure, look: PnjKits.Look)
        if templates[figure.Morphology] then
            return -- gabarit 3D : textures d'origine conservées
        end
        for index, segment in PnjKits.Segments do
            local part = figure.Parts[index]
            part.Color = if segment.Skin then look.Skin elseif segment.Lower then look.Bottom else look.Top
        end
    end

    local function acquire(look: PnjKits.Look): Figure
        local pool = pools[look.Morphology.Id]
        local figure = if pool then table.remove(pool) else nil
        if figure == nil then
            figure = build(look.Morphology)
        end
        local f = figure :: Figure
        for _, part in f.Parts do
            part.Transparency = 0
        end
        f.Yaw = nil
        f.LastAnimated = 0
        dress(f, look)
        return f
    end

    local function release(figure: Figure)
        local parts, frames = {}, {}
        for _, part in figure.Parts do
            part.Transparency = 1
            table.insert(parts, part)
            table.insert(frames, hiddenFrame)
        end
        Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
        local pool = pools[figure.Morphology]
        if pool == nil then
            pool = {}
            pools[figure.Morphology] = pool
        end
        table.insert(pool, figure)
    end

    local active: { [string]: Active } = {}
    local figures: { [string]: Figure } = {}

    -- Choix des piétons visibles (cellules voisines de la caméra, les plus proches d'abord).
    local function chooseVisible(origin: Vector3, now: number)
        local candidates: { { Key: string, Active: Active } } = {}
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
                    for k = 1, sidewalk.Count do
                        local walker = PedestrianModel.walker(sidewalk, k, now)
                        if walker == nil then
                            break
                        end
                        local p = walker.Position
                        local distance = math.sqrt((p.X - origin.X) ^ 2 + (p.Z - origin.Z) ^ 2)
                        if distance < RADIUS_M then
                            table.insert(candidates, {
                                Key = walker.Key,
                                Active = { Sidewalk = sidewalk, Index = k, Distance = distance },
                            })
                        end
                    end
                end
            end
        end
        table.sort(candidates, function(a, b)
            return a.Active.Distance < b.Active.Distance
        end)
        local keep: { [string]: boolean } = {}
        for index = 1, math.min(#candidates, MAX_VISIBLE) do
            local candidate = candidates[index]
            keep[candidate.Key] = true
            active[candidate.Key] = candidate.Active
            if figures[candidate.Key] == nil then
                figures[candidate.Key] = acquire(PnjKits.look(candidate.Key))
            end
        end
        for key, figure in figures do
            if not keep[key] then
                figures[key] = nil
                active[key] = nil
                release(figure)
            end
        end
    end

    local sinceSelect = SELECT_INTERVAL_S
    local parts: { BasePart } = {}
    local frames: { CFrame } = {}
    RunService.PreRender:Connect(function(dt)
        local camera = Workspace.CurrentCamera
        if camera == nil then
            return
        end
        local origin = camera.CFrame.Position / S
        local now = Workspace:GetServerTimeNow()
        sinceSelect += dt
        if sinceSelect >= SELECT_INTERVAL_S then
            sinceSelect = 0
            chooseVisible(origin, now)
        end

        table.clear(parts)
        table.clear(frames)
        local clock = os.clock()
        for key, entry in active do
            local figure = figures[key]
            -- Au-delà de NEAR_M : animation à MID_HZ seulement (coût réduit, mouvement encore fluide de loin).
            if entry.Distance > NEAR_M and clock - figure.LastAnimated < 1 / MID_HZ then
                continue
            end
            local elapsed = if figure.LastAnimated > 0 then clock - figure.LastAnimated else 0
            figure.LastAnimated = clock
            local walker = PedestrianModel.walker(entry.Sidewalk, entry.Index, now)
            if walker == nil then
                continue
            end
            local p = walker.Position
            entry.Distance = math.sqrt((p.X - origin.X) ^ 2 + (p.Z - origin.Z) ^ 2)
            -- Cap lissé (demi-tour en ~0,6 s au lieu d'un retournement instantané).
            local target = math.atan2(-walker.Heading.X, -walker.Heading.Z)
            local yaw = figure.Yaw or target
            local delta = (target - yaw + math.pi) % (2 * math.pi) - math.pi
            local maxTurn = TURN_RATE * math.min(elapsed, 0.25)
            yaw += math.clamp(delta, -maxTurn, maxTurn)
            figure.Yaw = yaw

            local kind: PedestrianGait.Kind = PedestrianGait.kindFor(walker.Speed)
            local stride = PedestrianGait.strideLength(walker.Speed, kind, figure.Scale)
            local pose = PedestrianGait.pose(kind, walker.Travel / stride, walker.Speed, now, PnjKits.hash(key))
            local joints = PedestrianGait.jointFrames(pose, figure.Scale)
            local base = CFrame.new(p.X * S, p.Y * S, p.Z * S) * CFrame.Angles(0, yaw, 0)
            for index, part in figure.Parts do
                local local_ =
                    PedestrianGait.segmentFrame(joints, figure.Joints[index], figure.Rest[index], figure.Scale)
                table.insert(parts, part)
                -- Repère piéton en mètres → studs (translation seulement).
                table.insert(frames, base * (local_.Rotation + local_.Position * S))
            end
        end
        if #parts > 0 then
            Workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
        end
    end)
end

return table.freeze(Pedestrians)
