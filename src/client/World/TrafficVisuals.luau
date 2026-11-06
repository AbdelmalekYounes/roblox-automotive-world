--!strict
--[[
    Lot PNJ-01 : animation LOCALE des voitures PNJ proches de la caméra — roues qui tournent et braquent, feux stop,
    clignotants, phares la nuit. Rien n'est répliqué : le serveur publie seulement l'état des feux (attributs posés
    au changement, World/TrafficBodies) ; la rotation des roues vient de la vitesse répliquée de la caisse.

    Coût borné : seules les voitures à moins de RADIUS_M de la caméra sont animées ; les feux ne changent de matériau
    qu'au changement d'état (aucune écriture inutile).
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PnjKits = require(Shared:WaitForChild("World"):WaitForChild("PnjKits"))
local WeatherModel = require(Shared:WaitForChild("World"):WaitForChild("WeatherModel"))
local ArtDirection = require(Shared:WaitForChild("Art"):WaitForChild("ArtDirection"))
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))

local TrafficVisuals = {}

local S = 1 / Constants.MetersPerStud
local TAG = "AWTrafficVehicle"
local RADIUS_M = 140
-- Clignotant : période réglementaire d'environ 1,5 Hz (allumé la moitié du temps).
local BLINK_PERIOD_S = 0.66
-- Braquage maximal affiché (rad) : celui d'une voiture de tourisme.
local MAX_STEER = math.rad(35)
local LIGHTS_CHECK_S = 2

type Lamp = { Part: BasePart, Off: Color3, On: Color3, OffMaterial: Enum.Material, Lit: boolean }
type Entry = {
    Model: Model,
    Root: BasePart,
    Car: PnjKits.CarSilhouette,
    Wheels: { { Motor: Motor6D, Front: boolean } },
    Spin: number, -- angle de rotation des roues (rad)
    Brake: { Lamp },
    Left: { Lamp },
    Right: { Lamp },
    Head: { Lamp },
}

local ON_COLORS = {
    Brake = Color3.fromRGB(255, 30, 30),
    Indicator = Color3.fromRGB(255, 150, 20),
    Head = Color3.fromRGB(255, 250, 230),
}

local entries: { [Model]: Entry } = {}

local function lamps(model: Model, names: { string }, on: Color3): { Lamp }
    local list = {}
    for _, name in names do
        local part = model:FindFirstChild(name, true)
        if part and part:IsA("BasePart") then
            table.insert(list, { Part = part, Off = part.Color, On = on, OffMaterial = part.Material, Lit = false })
        end
    end
    return list
end

local function setLamps(list: { Lamp }, lit: boolean)
    for _, lamp in list do
        if lamp.Lit ~= lit then
            lamp.Lit = lit
            lamp.Part.Material = if lit then Enum.Material.Neon else lamp.OffMaterial
            lamp.Part.Color = if lit then lamp.On else lamp.Off
        end
    end
end

local function register(model: Instance)
    if not model:IsA("Model") or entries[model] then
        return
    end
    local root = model.PrimaryPart or model:FindFirstChild("Caisse")
    local car = PnjKits.car(tostring(model:GetAttribute(PnjKits.Attributes.Silhouette)))
    if root == nil or not root:IsA("BasePart") or car == nil then
        return
    end
    local wheels = {}
    for _, name in PnjKits.Wheels do
        local wheel = model:FindFirstChild(name, true)
        local motor = wheel and wheel:FindFirstChildOfClass("Motor6D")
        if motor then
            table.insert(wheels, { Motor = motor, Front = string.sub(name, 6, 7) == "AV" })
        end
    end
    entries[model] = {
        Model = model,
        Root = root,
        Car = car,
        Wheels = wheels,
        Spin = 0,
        Brake = lamps(model, PnjKits.CarLights.Brake, ON_COLORS.Brake),
        Left = lamps(model, PnjKits.CarLights.Left, ON_COLORS.Indicator),
        Right = lamps(model, PnjKits.CarLights.Right, ON_COLORS.Indicator),
        Head = lamps(model, PnjKits.CarLights.Head, ON_COLORS.Head),
    }
end

local function lightsWanted(): boolean
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    local preset = WeatherModel.Presets[Workspace:GetAttribute("AWWeather") or "Clear"] or WeatherModel.Presets.Clear
    return ArtDirection.lightsOn(Lighting.ClockTime, if atmosphere then atmosphere.Density else 0, preset.RainRate)
end

function TrafficVisuals.start()
    -- Modèles arrivés (création, streaming) : enregistrés une fois ; retirés à leur destruction.
    CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model)
        -- Les pièces d'un modèle atomique arrivent ensemble, mais on attend la fin de la réplication de l'image.
        task.defer(register, model)
    end)
    CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model)
        entries[model :: Model] = nil
    end)
    for _, model in CollectionService:GetTagged(TAG) do
        register(model)
    end

    local headOn = false
    local sinceCheck = LIGHTS_CHECK_S
    RunService.PreRender:Connect(function(dt)
        local camera = Workspace.CurrentCamera
        if camera == nil then
            return
        end
        sinceCheck += dt
        if sinceCheck >= LIGHTS_CHECK_S then
            sinceCheck = 0
            headOn = lightsWanted()
        end
        local eye = camera.CFrame.Position
        local blink = (os.clock() % BLINK_PERIOD_S) < BLINK_PERIOD_S / 2
        for model, entry in entries do
            local root = entry.Root
            if root.Parent == nil then
                entries[model] = nil
                continue
            end
            if (root.Position - eye).Magnitude > RADIUS_M * S then
                continue
            end
            -- Vitesse longitudinale (m/s, positive en marche avant) et taux de lacet (rad/s).
            local velocity = root.AssemblyLinearVelocity / S
            local forward = velocity:Dot(root.CFrame.LookVector)
            local yawRate = root.AssemblyAngularVelocity.Y
            -- Braquage géométrique (modèle bicyclette) : tan(δ) = empattement × lacet / vitesse.
            local steer = 0
            if math.abs(forward) > 0.5 then
                steer = math.clamp(math.atan(entry.Car.WheelbaseM * yawRate / forward), -MAX_STEER, MAX_STEER)
            end
            -- Rotation des roues : roulement sans glissement (angle = distance / rayon) ; −X = sens de marche.
            entry.Spin = (entry.Spin - forward * dt / entry.Car.WheelRadiusM) % (2 * math.pi)
            local spin = CFrame.Angles(entry.Spin, 0, 0)
            local steered = CFrame.Angles(0, steer, 0) * spin
            for _, wheel in entry.Wheels do
                wheel.Motor.Transform = if wheel.Front then steered else spin
            end
            setLamps(entry.Brake, model:GetAttribute(PnjKits.Attributes.Brake) == true)
            local indicator = model:GetAttribute(PnjKits.Attributes.Indicator)
            setLamps(entry.Left, blink and indicator == "G")
            setLamps(entry.Right, blink and indicator == "D")
            setLamps(entry.Head, headOn)
        end
    end)
end

return table.freeze(TrafficVisuals)
