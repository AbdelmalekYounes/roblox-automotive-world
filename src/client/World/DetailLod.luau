--!strict
--[[
    Niveau de détail local (lot 0.8) : visibilité de l'habillage des zones
    (OpenWorld/Habillage/<zone>/<secteur>) et des détails de carrosserie
    (Carrosserie/Details), selon la distance à la caméra et la qualité choisie
    (ArtDirection.Profiles). Purement local : LocalTransparencyModifier, rien
    n'est répliqué, aucune collision ni physique n'est touchée (l'habillage est
    déjà non bloquant). Les pièces arrivées par streaming reçoivent l'état
    courant de leur modèle.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArtDirection = require(Shared:WaitForChild("Art"):WaitForChild("ArtDirection"))
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))
local UIState = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIState"))

local DetailLod = {}

local S = 1 / Constants.MetersPerStud
local UPDATE_S = 0.5
-- Hystérésis (m) : évite le clignotement à la limite de distance.
local HYSTERESIS_M = 15

local hidden: { [Instance]: boolean } = {}
local watched: { [Instance]: boolean } = {}

local function apply(container: Instance, hide: boolean)
    local value = if hide then 1 else 0
    for _, item in container:GetDescendants() do
        if item:IsA("BasePart") then
            item.LocalTransparencyModifier = value
        end
    end
end

local function watch(container: Instance)
    if watched[container] then
        return
    end
    watched[container] = true
    container.DescendantAdded:Connect(function(item)
        if hidden[container] and item:IsA("BasePart") then
            item.LocalTransparencyModifier = 1
        end
    end)
    container.Destroying:Connect(function()
        watched[container] = nil
        hidden[container] = nil
    end)
end

-- Visibilité voulue avec hystérésis autour de la distance limite.
local function decide(container: Instance, distanceM: number, limitM: number)
    local wasHidden = hidden[container] == true
    local hide = if limitM <= 0
        then true
        elseif wasHidden then distanceM > limitM - HYSTERESIS_M
        else distanceM > limitM + HYSTERESIS_M
    if hide ~= wasHidden then
        hidden[container] = hide
        watch(container)
        apply(container, hide)
    end
end

local function update(dressing: Instance?)
    local camera = Workspace.CurrentCamera
    if camera == nil then
        return
    end
    local profile = ArtDirection.profile(UIState.prefs().Graphics.Quality)
    local eye = camera.CFrame.Position
    if dressing then
        for _, zone in dressing:GetChildren() do
            for _, sector in zone:GetChildren() do
                local center = sector:GetAttribute("Center")
                if typeof(center) == "Vector3" then
                    -- Distance au bord du secteur (500 m de côté), en mètres.
                    local flat = Vector3.new(center.X - eye.X, 0, center.Z - eye.Z)
                    local edgeM = math.max(0, flat.Magnitude / S - 250)
                    decide(sector, edgeM, profile.DecorDistanceM)
                end
            end
        end
    end
    for _, vehicle in CollectionService:GetTagged(Constants.VehicleTag) do
        local body = vehicle:FindFirstChild("Carrosserie")
        local details = body and body:FindFirstChild("Details")
        if details and vehicle:IsA("Model") then
            local distanceM = (vehicle:GetPivot().Position - eye).Magnitude / S
            decide(details, distanceM, profile.DetailDistanceM)
        end
    end
end

function DetailLod.start()
    local world = Workspace:FindFirstChild("OpenWorld")
    local dressing = if world then world:FindFirstChild("Habillage") else nil
    local timer = 0
    RunService.Heartbeat:Connect(function(dt)
        timer += dt
        if timer >= UPDATE_S then
            timer = 0
            update(dressing)
        end
    end)
end

return table.freeze(DetailLod)
