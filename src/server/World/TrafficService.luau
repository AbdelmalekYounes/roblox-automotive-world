--!strict
--[[
    Trafic PNJ du monde ouvert (lot 0.3), contrôlé par le serveur SEUL.

    Trois niveaux de détail, selon la distance au joueur le plus proche :
    - virtuel (loin) : l'agent n'existe que dans World/TrafficModel (quelques
      nombres), simulé à STEP_S ; aucun coût réseau ni physique ;
    - physique (près, PHYSICAL_RADIUS_M) : un véhicule simplifié NON ANCRÉ,
      appartenant au serveur, guidé par AlignPosition / AlignOrientation à
      force limitée. Il est réellement solide : un joueur qui le percute le
      pousse et le fait réagir (arrêt, reprise), il ne le traverse pas ;
    - les agents physiques les plus proches sont prioritaires (plafond
      PHYSICAL_MAX), les autres restent virtuels.

    Réglages initiaux (BUDGET, rayons, plafond) NON MESURÉS en charge : voir
    docs/QA_BACKLOG.md. Ils ne touchent ni la physique ni les collisions des
    véhicules des joueurs.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldShared = Shared:WaitForChild("World")
local RoadGraph = require(WorldShared:WaitForChild("RoadGraph"))
local TrafficModel = require(WorldShared:WaitForChild("TrafficModel"))
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))
-- Lot PNJ-01 : silhouettes, modèles 3D (ou repli), feux stop et clignotants.
local PnjKits = require(WorldShared:WaitForChild("PnjKits"))
local TrafficCues = require(WorldShared:WaitForChild("TrafficCues"))
local TrafficBodies = require(script.Parent:WaitForChild("TrafficBodies"))

local TrafficService = {}

local S = 1 / Constants.MetersPerStud -- studs par mètre
local BUDGET = 140 -- agents sur toute la carte
local PHYSICAL_RADIUS_M = 260
local PHYSICAL_MAX = 48
local STEP_S = 0.2
-- Apparition ou retrait d'un agent : jamais à moins de cette distance d'un joueur.
local HIDDEN_SPAWN_M = 300
-- Agent bloqué au-delà de ce délai, loin des joueurs : replacé ailleurs.
local STUCK_RELOCATE_S = 60
-- Écart corps / cible (m) : au-delà, incident (arrêt) ; bien au-delà, recalage.
local INCIDENT_M = 3
local RESET_M = 25
local INCIDENT_HOLD_S = 4

local PALETTE = {
    Color3.fromRGB(200, 200, 205),
    Color3.fromRGB(40, 42, 48),
    Color3.fromRGB(150, 30, 35),
    Color3.fromRGB(30, 70, 140),
    Color3.fromRGB(235, 235, 230),
    Color3.fromRGB(90, 110, 90),
    Color3.fromRGB(120, 120, 128),
}

type Body = TrafficBodies.Body

local started = false
local random = Random.new()
local world: TrafficModel.World
local choices: { TrafficModel.SpawnChoice } = {}
local choicesTotal = 0
local bodies: { [number]: Body } = {}
local stuckSince: { [number]: number } = {}
-- Lot PNJ-01 : silhouette et teinte de chaque agent, tirées une fois (le même PNJ garde son aspect).
local looks: { [number]: { Car: PnjKits.CarSilhouette, Color: Color3 } } = {}
local lastSpeed: { [number]: number } = {}
local folder: Folder
local rayParams = RaycastParams.new()

local function roll(): number
    return random:NextNumber()
end

local function studs(p: { X: number, Y: number, Z: number }): Vector3
    return Vector3.new(p.X * S, p.Y * S, p.Z * S)
end

-- Positions (m) des personnages des joueurs.
local function playerPositions(): { Vector3 }
    local list = {}
    for _, player in Players:GetPlayers() do
        local character = player.Character
        if character then
            table.insert(list, character:GetPivot().Position / S)
        end
    end
    return list
end

local function nearestPlayer(positions: { Vector3 }, x: number, z: number): number
    local best = math.huge
    for _, p in positions do
        best = math.min(best, math.sqrt((p.X - x) ^ 2 + (p.Z - z) ^ 2))
    end
    return best
end

-- Véhicules des joueurs (et piétons joueurs) : obstacles pour les PNJ.
local function gatherObstacles(): { TrafficModel.Obstacle }
    local obstacles: { TrafficModel.Obstacle } = {}
    for _, vehicle in CollectionService:GetTagged(Constants.VehicleTag) do
        if vehicle:IsA("Model") and vehicle.PrimaryPart then
            local root = vehicle.PrimaryPart :: BasePart
            local p = root.Position / S
            table.insert(obstacles, {
                X = p.X,
                Z = p.Z,
                Speed = root.AssemblyLinearVelocity.Magnitude / S,
                Radius = math.max(root.Size.X, root.Size.Z) / S / 2,
            })
        end
    end
    for _, player in Players:GetPlayers() do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if character and humanoid and humanoid.SeatPart == nil then
            local p = character:GetPivot().Position / S
            table.insert(obstacles, { X = p.X, Z = p.Z, Speed = 0, Radius = 0.5 })
        end
    end
    return obstacles
end

local function spawnHidden(positions: { Vector3 }): boolean
    for _ = 1, 12 do
        local link = TrafficModel.pick(choices, choicesTotal, roll())
        local lanes = RoadGraph.laneCount(link.Edge)
        local agent =
            TrafficModel.spawn(world, link, random:NextInteger(1, lanes), roll(), random:NextNumber(0.88, 1.05))
        local here = TrafficModel.position(agent)
        local crowded = false
        for _, other in world.Agents do
            if
                other ~= agent
                and other.EdgeId == agent.EdgeId
                and other.Lane == agent.Lane
                and other.Forward == agent.Forward
            then
                if math.abs(other.S - agent.S) < 20 then
                    crowded = true
                    break
                end
            end
        end
        if not crowded and nearestPlayer(positions, here.X, here.Z) > HIDDEN_SPAWN_M then
            return true
        end
        TrafficModel.remove(world, agent)
    end
    return false
end

local function lookOf(agentId: number): { Car: PnjKits.CarSilhouette, Color: Color3 }
    local look = looks[agentId]
    if look == nil then
        look = { Car = PnjKits.pickCar(roll()), Color = PALETTE[random:NextInteger(1, #PALETTE)] }
        looks[agentId] = look
    end
    return look
end

-- Repère cible d'un agent : sur la chaussée (lancer vertical), dans le sens de marche.
local function targetFrame(agent: TrafficModel.Agent, lead: number, car: PnjKits.CarSilhouette): CFrame
    local here = TrafficModel.sample(agent.Path, agent.S + lead)
    local ahead = TrafficModel.sample(agent.Path, agent.S + lead + 3)
    local position = studs(here)
    -- Départ à 2,2 m au-dessus du tracé seulement : sous un pont, le lancer ne
    -- doit pas toucher le tablier supérieur.
    local hit = Workspace:Raycast(position + Vector3.new(0, 8, 0), Vector3.new(0, -24, 0), rayParams)
    local groundY = if hit then hit.Position.Y else position.Y
    local center = Vector3.new(position.X, groundY + PnjKits.boxCenter(car).Y * S, position.Z)
    local forward = studs(ahead) - position
    if forward.Magnitude < 1e-3 then
        forward = Vector3.new(0, 0, -1)
    end
    return CFrame.lookAt(center, center + forward.Unit)
end

local function overlapsPlayer(frame: CFrame, car: PnjKits.CarSilhouette): boolean
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { folder, Workspace:FindFirstChild("OpenWorld") :: Instance }
    local parts = Workspace:GetPartBoundsInBox(
        frame,
        Vector3.new(car.WidthM, car.HeightM, car.LengthM) * S + Vector3.new(2, 2, 2),
        params
    )
    return #parts > 0
end

local function removeBody(agentId: number)
    local body = bodies[agentId]
    if body then
        body.Model:Destroy()
        bodies[agentId] = nil
    end
end

local function stepSimulation(now: number)
    TrafficModel.step(world, STEP_S, now, gatherObstacles(), roll)
    local positions = playerPositions()

    -- Classement des agents par distance au joueur le plus proche.
    local ranked: { { Agent: TrafficModel.Agent, Distance: number } } = {}
    for _, agent in world.Agents do
        local here = TrafficModel.position(agent)
        table.insert(ranked, { Agent = agent, Distance = nearestPlayer(positions, here.X, here.Z) })
    end
    table.sort(ranked, function(a, b)
        return a.Distance < b.Distance
    end)

    local relocate: { TrafficModel.Agent } = {}
    for index, entry in ranked do
        local agent = entry.Agent
        local wantBody = index <= PHYSICAL_MAX and entry.Distance <= PHYSICAL_RADIUS_M
        local body = bodies[agent.Id]
        if wantBody and body == nil then
            local look = lookOf(agent.Id)
            local frame = targetFrame(agent, 0, look.Car)
            if not overlapsPlayer(frame, look.Car) then
                bodies[agent.Id] = TrafficBodies.build(agent.Id, look.Car, frame, look.Color, folder)
            end
        elseif not wantBody and body then
            removeBody(agent.Id)
        elseif body then
            -- Lot PNJ-01 : feux stop et clignotants publiés au changement seulement.
            TrafficBodies.publish(
                body,
                TrafficCues.braking(agent.Speed, lastSpeed[agent.Id] or agent.Speed, STEP_S),
                TrafficCues.indicator(agent)
            )
        end
        lastSpeed[agent.Id] = agent.Speed
        -- Agent immobile depuis longtemps, loin des joueurs : replacé.
        if agent.Speed < 0.2 then
            stuckSince[agent.Id] = stuckSince[agent.Id] or now
            if now - stuckSince[agent.Id] > STUCK_RELOCATE_S and entry.Distance > HIDDEN_SPAWN_M then
                table.insert(relocate, agent)
            end
        else
            stuckSince[agent.Id] = nil
        end
    end
    for _, agent in relocate do
        removeBody(agent.Id)
        stuckSince[agent.Id] = nil
        looks[agent.Id] = nil
        lastSpeed[agent.Id] = nil
        TrafficModel.remove(world, agent)
        spawnHidden(positions)
    end
    -- Complément progressif du budget (deux par pas au plus).
    for _ = 1, 2 do
        if #world.Agents < BUDGET then
            spawnHidden(positions)
        end
    end
end

-- Guidage des corps physiques à chaque image (position extrapolée entre deux pas).
local function steerBodies(sinceStep: number)
    for _, agent in world.Agents do
        local body = bodies[agent.Id]
        if body == nil then
            continue
        end
        local frame = targetFrame(agent, agent.Speed * sinceStep, body.Car)
        body.Align.Position = frame.Position
        body.Orient.CFrame = frame.Rotation
        local deviation = (body.Root.Position - frame.Position).Magnitude / S
        if deviation > RESET_M then
            -- Projeté loin (choc violent) : recalé seulement hors de vue directe.
            local positions = playerPositions()
            if nearestPlayer(positions, body.Root.Position.X / S, body.Root.Position.Z / S) > 40 then
                body.Model:PivotTo(frame)
                body.Root.AssemblyLinearVelocity = Vector3.zero
                body.Root.AssemblyAngularVelocity = Vector3.zero
            end
            agent.Holding = INCIDENT_HOLD_S
        elseif deviation > INCIDENT_M then
            -- Heurté ou bloqué : le PNJ s'arrête puis repart (pas de traversée).
            agent.Holding = INCIDENT_HOLD_S
        end
    end
end

function TrafficService.start()
    assert(not started, "TrafficService déjà démarré")
    started = true
    world = TrafficModel.newWorld(RoadGraph.get())
    choices, choicesTotal = TrafficModel.spawnChoices(world)
    assert(choicesTotal > 0, "Aucune route ouverte au trafic")

    folder = Instance.new("Folder")
    folder.Name = "TraficPNJ"
    folder.Parent = Workspace
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { folder }
    rayParams.RespectCanCollide = true
    rayParams.IgnoreWater = true

    -- Population initiale (aucun joueur encore présent : apparition libre).
    local positions = playerPositions()
    for _ = 1, BUDGET do
        spawnHidden(positions)
    end

    local accumulator = 0
    RunService.Heartbeat:Connect(function(dt)
        accumulator += dt
        if accumulator >= STEP_S then
            accumulator -= STEP_S
            stepSimulation(Workspace:GetServerTimeNow())
        end
        steerBodies(accumulator)
    end)
end

-- Instantané pour les tests en Studio (lecture seule).
function TrafficService.snapshot(): { Agents: number, Physical: number }
    local physical = 0
    for _ in bodies do
        physical += 1
    end
    return { Agents = if world then #world.Agents else 0, Physical = physical }
end

return table.freeze(TrafficService)
