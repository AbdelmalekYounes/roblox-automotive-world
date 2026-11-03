--!strict
--[[
    Lieux de la progression (lot 0.4) : entrées des propriétés et garages
    publics, identifiés par les identifiants d'infrastructure du lot 0.3.

    Les positions viennent des DONNÉES de la carte (WorldLayout), jamais d'une
    instance chargée : un lieu reste identifiable même si son secteur n'est pas
    reçu par le client (streaming). Dans la place de développement, toutes
    les entrées et tous les garages publics sont représentés par deux points
    de la zone d'essai (alias explicites).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldLayout = require(Shared:WaitForChild("World"):WaitForChild("WorldLayout"))
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))
local PropertyCatalog = require(Shared:WaitForChild("Garage"):WaitForChild("PropertyCatalog"))

local Locations = {}

local S = 1 / Constants.MetersPerStud

-- Lot 0.5 : concessions, stations-service, bornes, lavages.
export type Kind = "Entrance" | "PublicGarage" | "Dealership" | "FuelStation" | "ChargingHub" | "CarWash"

export type Place = {
    Id: string,
    Kind: Kind,
    Pumps: number?,
    Chargers: number?,
    Label: string,
    Zone: string,
    Frame: CFrame, -- centre au niveau du sol, regard vers la route (studs)
    Radius: number, -- rayon d'accès (studs)
    ExitFrame: CFrame, -- emplacement de sortie d'un véhicule, face à la route
}

local places: { [string]: Place } = {}
local aliases: { [string]: string } = {}

local function register(place: Place)
    places[place.Id] = place
end

-- Monde ouvert : entrées (emplacements de propriétés) et trois garages publics.
function Locations.loadOpenWorld()
    local layout = WorldLayout.get()
    local wanted: { [string]: Kind } = {}
    for _, offer in PropertyCatalog.Offers do
        wanted[offer.Entrance] = "Entrance"
    end
    for _, placement in layout.Placements do
        local kind = placement.Kind
        if
            kind == "PublicGarage"
            or kind == "Dealership"
            or kind == "FuelStation"
            or kind == "ChargingHub"
            or kind == "CarWash"
        then
            wanted[placement.Id] = kind :: Kind
        end
    end
    for id, kind: Kind in wanted do
        local placement = layout.PlacementById[id]
        assert(placement, "Emplacement absent de la carte : " .. id)
        local c = placement.Center
        local origin = Vector3.new(c.X * S, c.Y * S, c.Z * S)
        local facing = Vector3.new(placement.Facing.X, 0, placement.Facing.Z)
        local frame = CFrame.lookAt(origin, origin + facing)
        -- Sortie sur la dalle d'accès, côté route.
        local exitOffset = (placement.Depth / 2 - 5) * S
        register({
            Id = id,
            Kind = kind,
            Label = placement.Name,
            Zone = placement.Zone,
            Frame = frame,
            Radius = (math.max(placement.Width, placement.Depth) / 2 + 12) * S,
            ExitFrame = frame * CFrame.new(0, 0, -exitOffset),
            Pumps = placement.Pumps,
            Chargers = placement.Chargers,
        })
    end
end

-- Place de développement : deux points de la zone d'essai, alias de tous les lieux.
function Locations.loadDev(entrance: BasePart, garage: BasePart, dealer: BasePart?, station: BasePart?)
    local function place(id: string, kind: Kind, part: BasePart, label: string)
        local frame = CFrame.lookAt(part.Position, part.Position + part.CFrame.LookVector * Vector3.new(1, 0, 1))
        register({
            Id = id,
            Kind = kind,
            Label = label,
            Zone = "Essai",
            Frame = frame,
            Radius = math.max(part.Size.X, part.Size.Z) / 2 + 30,
            ExitFrame = frame * CFrame.new(0, 0, -(part.Size.Z / 2 + 14)),
            Pumps = 2,
            Chargers = 2,
        })
    end
    place("DEV-ENTREE", "Entrance", entrance, "Entrée de propriété (essai)")
    place("DEV-GARAGE", "PublicGarage", garage, "Garage public (essai)")
    for _, offer in PropertyCatalog.Offers do
        aliases[offer.Entrance] = "DEV-ENTREE"
    end
    for _, id in { "SVC-GARAGE-METRO", "SVC-GARAGE-BANLIEUE", "SVC-GARAGE-DOCKS" } do
        aliases[id] = "DEV-GARAGE"
    end
    -- Lot 0.5 : concession et station d'essai (carburant, recharge, lavage).
    if dealer then
        place("DEV-CONCESSION", "Dealership", dealer, "Concession (essai)")
        for _, id in { "SVC-DEALER-METRO", "SVC-DEALER-BANLIEUE" } do
            aliases[id] = "DEV-CONCESSION"
        end
    end
    if station then
        place("DEV-STATION", "FuelStation", station, "Station-service (essai)")
    end
end

function Locations.get(id: string): Place?
    return places[aliases[id] or id]
end

-- Identifiant effectif d'un lieu (après alias de la place de développement).
function Locations.resolve(id: string): string
    return aliases[id] or id
end

function Locations.all(): { Place }
    local list: { Place } = {}
    for _, place in places do
        table.insert(list, place)
    end
    table.sort(list, function(a, b)
        return a.Id < b.Id
    end)
    return list
end

-- Lieu d'un type donné le plus proche d'une position, s'il est dans son rayon.
function Locations.near(position: Vector3, kind: Kind): Place?
    local best: Place? = nil
    local bestDistance = math.huge
    for _, place in places do
        if place.Kind == kind then
            local offset = position - place.Frame.Position
            local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
            if distance <= place.Radius and distance < bestDistance then
                best, bestDistance = place, distance
            end
        end
    end
    return best
end

-- Lot 0.5 : services d'un lieu (carburant, recharge, lavage).
function Locations.services(place: Place): { Fuel: boolean, Charge: boolean, Wash: boolean }
    if place.Id == "DEV-STATION" then
        return { Fuel = true, Charge = true, Wash = true }
    end
    return {
        Fuel = place.Kind == "FuelStation" and (place.Pumps or 0) > 0,
        Charge = (place.Kind == "FuelStation" or place.Kind == "ChargingHub") and (place.Chargers or 0) > 0,
        Wash = place.Kind == "CarWash",
    }
end

-- Lieu de service le plus proche offrant au moins un service.
function Locations.nearService(position: Vector3): Place?
    local best: Place? = nil
    local bestDistance = math.huge
    for _, place in places do
        if place.Kind == "FuelStation" or place.Kind == "ChargingHub" or place.Kind == "CarWash" then
            local offset = position - place.Frame.Position
            local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
            if distance <= place.Radius and distance < bestDistance then
                best, bestDistance = place, distance
            end
        end
    end
    return best
end

function Locations.within(place: Place, position: Vector3): boolean
    local offset = position - place.Frame.Position
    return Vector3.new(offset.X, 0, offset.Z).Magnitude <= place.Radius
end

return table.freeze(Locations)
