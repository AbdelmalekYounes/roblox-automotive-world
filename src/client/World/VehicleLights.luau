--!strict
--[[
    Éclairage de nuit (lot 0.8), local et limité :
    - feux des véhicules (pièces AWLight = "Head" / "Tail" des kits de maillages) : la
      pièce s'illumine (Neon) sur tous les véhicules dès que la règle
      ArtDirection.lightsOn est vraie ; les SOURCES de lumière réelles
      (Lumiere) ne sont activées que sur les N véhicules les plus proches ;
    - lampadaires de l'habillage (AWStreetLight) : lanterne illuminée, source
      réelle sur les N plus proches seulement.
    N dépend de la qualité graphique (ArtDirection.Profiles). Aucun effet sur
    la conduite : l'adhérence ne dépend que de l'humidité de chaussée.
    Feux STOP (lot VEH3D-01) : les pièces AWLight = "Tail" s'allument aussi, plus fort, quand le serveur publie
    le freinage (attribut VisualBrake, de jour comme de nuit). Optique cassée par un choc (AWLightBroken) :
    éteinte jusqu'à la réparation.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArtDirection = require(Shared:WaitForChild("Art"):WaitForChild("ArtDirection"))
local WeatherModel = require(Shared:WaitForChild("World"):WaitForChild("WeatherModel"))
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))
local UIState = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIState"))

local VehicleLights = {}

local UPDATE_S = 0.5

-- Matériau d'origine des pièces lumineuses (restauré au jour).
local original: { [BasePart]: Enum.Material } = {}

local function glow(part: BasePart, on: boolean)
    if on then
        if original[part] == nil then
            original[part] = part.Material
            part.Destroying:Connect(function()
                original[part] = nil
            end)
        end
        if part.Material ~= Enum.Material.Neon then
            part.Material = Enum.Material.Neon
        end
    elseif original[part] and part.Material ~= original[part] then
        part.Material = original[part]
    end
end

local function setSource(part: BasePart, on: boolean)
    local light = part:FindFirstChild("Lumiere")
    if light and light:IsA("Light") and light.Enabled ~= on then
        light.Enabled = on
    end
end

-- Intensité d'un feu arrière : veilleuse (1) ou stop (3), mémorisée à la première lecture.
local baseBrightness: { [Light]: number } = {}
local function setBrake(part: BasePart, braking: boolean)
    local light = part:FindFirstChild("Lumiere")
    if light and light:IsA("Light") then
        if baseBrightness[light] == nil then
            baseBrightness[light] = light.Brightness
            light.Destroying:Connect(function()
                baseBrightness[light] = nil
            end)
        end
        local wanted = baseBrightness[light] * (if braking then 3 else 1)
        if light.Brightness ~= wanted then
            light.Brightness = wanted
        end
    end
end

type Candidate = { Part: BasePart, Distance: number }

-- Allume les sources des `count` éléments les plus proches, éteint les autres.
local function nearest(candidates: { Candidate }, count: number, on: boolean)
    table.sort(candidates, function(a, b)
        return a.Distance < b.Distance
    end)
    for index, candidate in candidates do
        setSource(candidate.Part, on and index <= count)
    end
end

local function lightsWanted(): boolean
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    local preset = WeatherModel.Presets[Workspace:GetAttribute("AWWeather") or "Clear"] or WeatherModel.Presets.Clear
    return ArtDirection.lightsOn(Lighting.ClockTime, if atmosphere then atmosphere.Density else 0, preset.RainRate)
end

local function update(lanterns: { [BasePart]: boolean })
    local camera = Workspace.CurrentCamera
    if camera == nil then
        return
    end
    local eye = camera.CFrame.Position
    local on = lightsWanted()
    local profile = ArtDirection.profile(UIState.prefs().Graphics.Quality)

    -- Véhicules : une entrée par véhicule (ses phares et feux partagent le rang).
    local vehicles: { { Parts: { BasePart }, Distance: number, Braking: boolean } } = {}
    for _, vehicle in CollectionService:GetTagged(Constants.VehicleTag) do
        if vehicle:IsA("Model") then
            local parts = {}
            local body = vehicle:FindFirstChild("Carrosserie")
            local braking = vehicle:GetAttribute(Constants.Attributes.VisualBrake) == true
            if body then
                for _, item in body:GetDescendants() do
                    if item:IsA("BasePart") and item:GetAttribute("AWLight") ~= nil then
                        local broken = item:GetAttribute("AWLightBroken") == true
                        local tail = item:GetAttribute("AWLight") == "Tail"
                        if broken then
                            glow(item, false)
                            setSource(item, false)
                        else
                            table.insert(parts, item)
                            glow(item, on or (tail and braking))
                            if tail then
                                setBrake(item, braking)
                            end
                        end
                    end
                end
            end
            if #parts > 0 then
                table.insert(vehicles, {
                    Parts = parts,
                    Distance = (vehicle:GetPivot().Position - eye).Magnitude,
                    Braking = braking,
                })
            end
        end
    end
    table.sort(vehicles, function(a, b)
        return a.Distance < b.Distance
    end)
    for index, entry in vehicles do
        local braking = entry.Braking
        for _, part in entry.Parts do
            local tail = part:GetAttribute("AWLight") == "Tail"
            setSource(part, (on or (tail and braking)) and index <= profile.VehicleLightSources)
        end
    end

    local street: { Candidate } = {}
    for lantern in lanterns do
        if lantern.Parent == nil then
            lanterns[lantern] = nil
        else
            glow(lantern, on)
            table.insert(street, { Part = lantern, Distance = (lantern.Position - eye).Magnitude })
        end
    end
    nearest(street, profile.StreetLightSources, on)
end

function VehicleLights.start()
    local lanterns: { [BasePart]: boolean } = {}
    local function consider(item: Instance)
        if item:IsA("BasePart") and item:GetAttribute("AWStreetLight") then
            lanterns[item] = true
        end
    end
    -- Dossier d'habillage cherché à chaque passage tant qu'il manque : avec le streaming,
    -- « OpenWorld » arrive APRÈS le démarrage du client (lot 0.9 : lampadaires jamais suivis).
    local dressing: Instance? = nil
    local timer = 0
    RunService.Heartbeat:Connect(function(dt)
        timer += dt
        if timer < UPDATE_S then
            return
        end
        timer = 0
        if dressing == nil then
            local world = Workspace:FindFirstChild("OpenWorld")
            local found = if world then world:FindFirstChild("Habillage") else nil
            if found then
                dressing = found
                for _, item in found:GetDescendants() do
                    consider(item)
                end
                found.DescendantAdded:Connect(consider)
            end
        end
        update(lanterns)
    end)
end

return table.freeze(VehicleLights)
