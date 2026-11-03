-- Essais CLIENT du lot 0.3 (session « monde », place monde ouvert), injectés par
-- le pilote dans le Studio de test uniquement : apparition, carte reçue
-- (streaming), feux, piétons, heure locale, conduite sur l'autoroute avec la
-- VRAIE simulation (seule la lecture clavier/manette est remplacée par
-- setTestInputProvider), puis lecture de la pluie forcée.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local sessionStart = os.clock()
while ReplicatedStorage:GetAttribute("AWTestSession") == nil and os.clock() - sessionStart < 15 do
    task.wait()
end
if ReplicatedStorage:GetAttribute("AWTestSession") ~= "monde" then
    return
end

local S = 1 / 0.28
local steps = {}
local measures = {}
local function record(name: string, ok: boolean, detail: any)
    table.insert(steps, { name = name, ok = ok, detail = if detail ~= nil then tostring(detail) else nil })
end
local function waitFor(predicate: () -> boolean, timeout: number): boolean
    local start = os.clock()
    while os.clock() - start < timeout do
        if predicate() then
            return true
        end
        task.wait(0.1)
    end
    return predicate()
end

local reportEvent = ReplicatedStorage:WaitForChild("AWTestReport", 30)
local signalEvent = ReplicatedStorage:WaitForChild("AWTestSignal", 30)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldLayout = require(Shared:WaitForChild("World"):WaitForChild("WorldLayout"))
local WeatherModel = require(Shared.World.WeatherModel)
local VehicleController = require(
    player
        :WaitForChild("PlayerScripts")
        :WaitForChild("AutomotiveWorldClient")
        :WaitForChild("Vehicles")
        :WaitForChild("VehicleController", 10)
)

local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart", 20) :: BasePart

-- 1. Apparition près de l'esplanade du Boulevard (SPAWN-METRO).
local spawnPlacement = WorldLayout.get().PlacementById["SPAWN-METRO"]
local spawnPosition = Vector3.new(spawnPlacement.Center.X * S, root.Position.Y, spawnPlacement.Center.Z * S)
local spawnDistance = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(
    spawnPosition.X,
    0,
    spawnPosition.Z
)).Magnitude
record("monde.client.apparition_metropole", spawnDistance < 80, string.format("%.0f st de l'apparition", spawnDistance))

-- 2. Carte reçue : routes persistantes, décor proche.
local map = Workspace:WaitForChild("OpenWorld", 30)
task.wait(5)
local roads, decor = 0, 0
local routes = map and map:FindFirstChild("Routes")
for _, part in (routes and routes:GetDescendants()) or {} do
    if part:IsA("BasePart") then
        roads += 1
    end
end
local decorFolder = map and map:FindFirstChild("Decor")
for _, part in (decorFolder and decorFolder:GetDescendants()) or {} do
    if part:IsA("BasePart") then
        decor += 1
    end
end
record("monde.client.routes_recues", roads > 1000, roads .. " pièces de route")
record("monde.client.decor_proche_recu", decor > 0, decor .. " pièces de décor")
-- Lot 0.9 : habillage du lot 0.8 (accessoires par zone, streaming normal) reçu près de l'apparition.
local dressing = Workspace:FindFirstChild("OpenWorld") and (Workspace.OpenWorld :: Instance):FindFirstChild("Habillage")
local dressingParts, dressingZones = 0, {}
for _, zoneFolder in (dressing and dressing:GetChildren()) or {} do
    local count = 0
    for _, item in zoneFolder:GetDescendants() do
        if item:IsA("BasePart") then
            count += 1
        end
    end
    if count > 0 then
        table.insert(dressingZones, zoneFolder.Name .. " " .. count)
    end
    dressingParts += count
end
record(
    "monde.client.habillage_recu",
    dressing ~= nil and dressingParts > 0,
    dressingParts .. " pièce(s) : " .. table.concat(dressingZones, ", ")
)
measures.routes_recues = roads
measures.decor_recu = decor

-- 3. Feux, piétons, heure locale.
task.wait(2)
local lamps, colored = 0, 0
local palette = {
    Color3.fromRGB(40, 220, 90),
    Color3.fromRGB(255, 170, 30),
    Color3.fromRGB(230, 40, 40),
}
for _, lamp in CollectionService:GetTagged("AWTrafficLight") do
    if lamp:IsA("BasePart") and (lamp.Position - root.Position).Magnitude < 1500 then
        lamps += 1
        for _, color in palette do
            if lamp.Color == color then
                colored += 1
            end
        end
    end
end
record(
    "monde.client.feux_colores",
    lamps == 0 or colored == lamps,
    string.format("%d / %d lampes proches", colored, lamps)
)
local pedestrians = waitFor(function()
    local folder = Workspace:FindFirstChild("PietonsLocaux")
    if folder == nil then
        return false
    end
    for _, part in folder:GetChildren() do
        if part:IsA("BasePart") and part.Transparency < 1 then
            return true
        end
    end
    return false
end, 15)
record("monde.client.pietons_rendus", pedestrians)
local epoch = Workspace:GetAttribute("AWClockEpoch")
local expected = if type(epoch) == "number" then WeatherModel.clockTime(Workspace:GetServerTimeNow(), epoch) else -1
local clockGap = math.abs(Lighting.ClockTime - expected)
record("monde.client.heure_synchronisee", clockGap < 0.2 or clockGap > 23.8, string.format("écart %.3f h", clockGap))

-- 4. Conduite sur l'autoroute.
local stageReached = waitFor(function()
    return ReplicatedStorage:GetAttribute("AWMondeStage") == "drive"
end, 120)
if stageReached then
    local fleet = Workspace:WaitForChild("VehiculesEssai", 20)
    local name = ReplicatedStorage:GetAttribute("AWMondeVehicle")
    local model = fleet and fleet:WaitForChild(name, 30) :: Model?
    local boarded = false
    if model then
        waitFor(function()
            return model.PrimaryPart ~= nil and (model.PrimaryPart.Position - root.Position).Magnitude < 40
        end, 20)
        local door = model.PrimaryPart and model.PrimaryPart:FindFirstChild("DriverDoor")
        local prompt = door and door:FindFirstChild("EnterPrompt") :: ProximityPrompt?
        if prompt then
            root.CFrame = CFrame.new((door :: Attachment).WorldPosition + Vector3.new(0, 2, 0))
            task.wait(0.5)
            prompt:InputHoldBegin()
            task.wait(prompt.HoldDuration + 0.3)
            prompt:InputHoldEnd()
        end
        boarded = waitFor(function()
            return model:GetAttribute("DriverUserId") == player.UserId
        end, 10)
    end
    record("monde.client.embarquement_autoroute", boarded)
    if boarded and model then
        local vehicleRoot = model.PrimaryPart :: BasePart
        local startPosition = vehicleRoot.Position
        local maxSpeed, minHeight, minUpright, noGround = 0, math.huge, 1, 0
        -- Garde au sol mesurée par un lancer vertical (la route peut monter ou descendre).
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { model, character }
        VehicleController.setTestInputProvider(function()
            return { Throttle = 1, Brake = 0, Steer = 0, Handbrake = false, Clutch = 0 }
        end)
        local t0 = os.clock()
        while os.clock() - t0 < 14 do
            local speedKmh = vehicleRoot.AssemblyLinearVelocity.Magnitude * 0.28 * 3.6
            maxSpeed = math.max(maxSpeed, speedKmh)
            local hit = Workspace:Raycast(vehicleRoot.Position, Vector3.new(0, -30, 0), params)
            if hit then
                minHeight = math.min(minHeight, vehicleRoot.Position.Y - hit.Position.Y)
            else
                noGround += 1
            end
            minUpright = math.min(minUpright, vehicleRoot.CFrame.UpVector.Y)
            task.wait(0.1)
        end
        VehicleController.setTestInputProvider(function()
            return { Throttle = 0, Brake = 1, Steer = 0, Handbrake = false, Clutch = 0 }
        end)
        waitFor(function()
            return vehicleRoot.AssemblyLinearVelocity.Magnitude < 1
        end, 12)
        VehicleController.setTestInputProvider(nil)
        local distance = (vehicleRoot.Position - startPosition).Magnitude * 0.28
        measures.autoroute_vitesse_max_kmh = math.floor(maxSpeed * 10) / 10
        measures.autoroute_distance_m = math.floor(distance)
        measures.autoroute_hauteur_min_st = math.floor(minHeight * 100) / 100
        record(
            "monde.client.autoroute_vitesse_atteinte",
            maxSpeed > 80,
            string.format("%.1f km/h en 14 s, %.0f m", maxSpeed, distance)
        )
        record(
            "monde.client.autoroute_jamais_sous_la_route",
            noGround == 0 and minHeight > 0.3,
            string.format("garde au sol min %.2f st, %d échantillon(s) sans sol", minHeight, noGround)
        )
        record("monde.client.autoroute_reste_droit", minUpright > 0.9, string.format("%.3f", minUpright))
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.Sit = false
            humanoid.Jump = true
        end
    end
    signalEvent:FireServer("MondeDriveDone")
end

-- 5. Pluie forcée par le serveur : humidité lue par le client.
local rain = waitFor(function()
    return ReplicatedStorage:GetAttribute("AWMondeStage") == "rain" and Workspace:GetAttribute("AWRoadWetness") == 1
end, 200)
record("monde.client.pluie_recue", rain)
signalEvent:FireServer("MondeRainSeen")

reportEvent:FireServer({ vehicle = "monde", steps = steps, measures = measures })
