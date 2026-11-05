--!strict
--[[
    Intérieurs PRIVÉS instanciés des propriétés (lot 0.4 §7).

    Une instance par propriété possédée occupée (propriétaire ou invités),
    construite à l'écart de la carte, hors de toute route. Elle est reliée à
    l'entrée de la propriété dans le monde : on n'y entre qu'en se tenant à
    cette entrée, et on en ressort à cette même entrée (pas de téléportation
    libre). Les véhicules exposés y sont des MAQUETTES ancrées et non
    conduisibles : l'exemplaire conduisible n'existe que s'il est « sorti ».
    L'instance est détruite quand plus personne ne l'occupe.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))
local VehicleDefinitions = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleDefinitions"))
local CosmeticCatalog = require(Shared:WaitForChild("Garage"):WaitForChild("CosmeticCatalog"))
local TuningRules = require(Shared:WaitForChild("Garage"):WaitForChild("TuningRules"))

local VehicleFactory = require(script.Parent.Parent.Vehicles.VehicleFactory)

local PropertyInteriors = {}

local S = 1 / Constants.MetersPerStud
-- Origine des intérieurs : loin au-delà de la carte (± 17 857 studs).
local ORIGIN = Vector3.new(40000, 0, 40000)
local CELL_STUDS = 700
local SLOT_SPACING_M = 7
local HALL_DEPTH_M = 22

export type Interior = {
    Key: string,
    OwnerUserId: number,
    PropertyId: string,
    Model: Model,
    Spawn: CFrame,
    Occupants: { [Player]: boolean },
    EmptySince: number?,
}

local interiors: { [string]: Interior } = {}
local cells: { [number]: string } = {}
local folder: Folder? = nil

local function container(): Folder
    if folder == nil then
        local created = Instance.new("Folder")
        created.Name = "InterieursPrives"
        created.Parent = Workspace
        folder = created
    end
    return folder :: Folder
end

local function keyOf(ownerUserId: number, propertyId: string): string
    return tostring(ownerUserId) .. "/" .. propertyId
end

local function freeCell(key: string): number
    local index = 1
    while cells[index] ~= nil do
        index += 1
    end
    cells[index] = key
    return index
end

local function block(
    parent: Instance,
    name: string,
    size: Vector3,
    frame: CFrame,
    color: Color3,
    material: Enum.Material
)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.Size = size
    part.CFrame = frame
    part.Color = color
    part.Material = material
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = parent
    return part
end

-- Maquette non conduisible d'un exemplaire exposé (apparence personnalisée).
local function showcase(parent: Instance, vehicle: any, frame: CFrame)
    local base = VehicleDefinitions.get(vehicle.ModelId)
    if base == nil then
        return
    end
    local definition = TuningRules.deepCopy(base)
    definition.Appearance = CosmeticCatalog.appearance(base.Appearance, vehicle.Cosmetics)
    local height = definition.Chassis.CgHeightM * S + 0.3
    local model = VehicleFactory.create(definition, frame * CFrame.new(0, height, 0), 0)
    model.Name = "Expose_" .. vehicle.Id
    CollectionService:RemoveTag(model, Constants.VehicleTag)
    for _, item in model:GetDescendants() do
        local removable = item:IsA("Seat")
            or item:IsA("ProximityPrompt")
            or item:IsA("Constraint")
            or item:IsA("VectorForce")
        if removable then
            item:Destroy()
        elseif item:IsA("BasePart") then
            item.Anchored = true
        end
    end
    model:SetAttribute("ShowcaseVehicleId", vehicle.Id)
    model.Parent = parent
end

--[[
    Construit (ou reconstruit) le contenu d'un intérieur : sol, murs, places
    numérotées, maquettes des exemplaires exposés, porte de sortie.
]]
local function furnish(interior: Interior, capacity: number, displayed: { [number]: any }, onExit: (Player) -> ())
    local model = interior.Model
    model:ClearAllChildren()
    local origin = interior.Spawn * CFrame.new(0, 0, 0)
    local width = math.max(capacity, 2) * SLOT_SPACING_M + 6
    block(
        model,
        "Sol",
        Vector3.new(width * S, 1, HALL_DEPTH_M * S),
        origin * CFrame.new(0, -0.5, 0),
        Color3.fromRGB(70, 72, 78),
        Enum.Material.Concrete
    )
    for _, side in { -1, 1 } do
        block(
            model,
            "Mur",
            Vector3.new(1, 6 * S, HALL_DEPTH_M * S),
            origin * CFrame.new(side * width * S / 2, 3 * S, 0),
            Color3.fromRGB(200, 200, 196),
            Enum.Material.SmoothPlastic
        )
    end
    block(
        model,
        "MurFond",
        Vector3.new(width * S, 6 * S, 1),
        origin * CFrame.new(0, 3 * S, HALL_DEPTH_M * S / 2),
        Color3.fromRGB(200, 200, 196),
        Enum.Material.SmoothPlastic
    )
    block(
        model,
        "MurAvant",
        Vector3.new(width * S, 6 * S, 1),
        origin * CFrame.new(0, 3 * S, -HALL_DEPTH_M * S / 2),
        Color3.fromRGB(200, 200, 196),
        Enum.Material.SmoothPlastic
    )
    block(
        model,
        "Toit",
        Vector3.new(width * S, 1, HALL_DEPTH_M * S),
        origin * CFrame.new(0, 6 * S, 0),
        Color3.fromRGB(230, 230, 228),
        Enum.Material.SmoothPlastic
    )
    for slot = 1, capacity do
        local x = (-width / 2 + 3 + (slot - 0.5) * SLOT_SPACING_M) * S
        local slotFrame = origin * CFrame.new(x, 0, 3 * S)
        local mark = block(
            model,
            "Place" .. slot,
            Vector3.new(2.6 * S, 0.05, 5.4 * S),
            slotFrame * CFrame.new(0, 0.03, 0),
            Color3.fromRGB(90, 150, 90),
            Enum.Material.SmoothPlastic
        )
        mark.CanCollide = false
        mark:SetAttribute("Slot", slot)
        local vehicle = displayed[slot]
        if vehicle then
            showcase(model, vehicle, slotFrame)
        end
    end
    local door = block(
        model,
        "Sortie",
        Vector3.new(3 * S, 0.2, 2 * S),
        origin * CFrame.new(0, 0.1, -(HALL_DEPTH_M / 2 - 2) * S),
        Color3.fromRGB(255, 160, 40),
        Enum.Material.Neon
    )
    door.CanCollide = false
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Sortir"
    prompt.ObjectText = "Propriété"
    prompt.HoldDuration = 0.3
    prompt.RequiresLineOfSight = false
    prompt.Parent = door
    prompt.Triggered:Connect(onExit)
end

function PropertyInteriors.get(ownerUserId: number, propertyId: string): Interior?
    return interiors[keyOf(ownerUserId, propertyId)]
end

-- Ouvre (ou retrouve) l'intérieur et le meuble selon l'état du profil.
function PropertyInteriors.open(
    ownerUserId: number,
    propertyId: string,
    capacity: number,
    displayed: { [number]: any },
    onExit: (Player) -> ()
): Interior
    local key = keyOf(ownerUserId, propertyId)
    local interior = interiors[key]
    if interior == nil then
        local cell = freeCell(key)
        local model = Instance.new("Model")
        model.Name = "Interieur_" .. key
        model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
        model:SetAttribute("OwnerUserId", ownerUserId)
        model:SetAttribute("PropertyId", propertyId)
        model:SetAttribute("Cell", cell)
        model.Parent = container()
        local origin = ORIGIN + Vector3.new((cell - 1) * CELL_STUDS, 0, 0)
        interior = {
            Key = key,
            OwnerUserId = ownerUserId,
            PropertyId = propertyId,
            Model = model,
            Spawn = CFrame.new(origin),
            Occupants = {},
            EmptySince = nil,
        }
        interiors[key] = interior
        furnish(interior, capacity, displayed, onExit)
    end
    return interior :: Interior
end

-- Met à jour les maquettes après un changement d'exposition.
function PropertyInteriors.refresh(
    ownerUserId: number,
    propertyId: string,
    capacity: number,
    displayed: { [number]: any },
    onExit: (Player) -> ()
)
    local interior = interiors[keyOf(ownerUserId, propertyId)]
    if interior then
        furnish(interior, capacity, displayed, onExit)
    end
end

-- Point d'arrivée d'un occupant (devant la porte, regard vers les places).
function PropertyInteriors.arrival(interior: Interior): CFrame
    return interior.Spawn * CFrame.new(0, 3, -(HALL_DEPTH_M / 2 - 4) * S)
end

function PropertyInteriors.occupy(interior: Interior, player: Player)
    interior.Occupants[player] = true
    interior.EmptySince = nil
end

function PropertyInteriors.leave(interior: Interior, player: Player, now: number)
    interior.Occupants[player] = nil
    if next(interior.Occupants) == nil then
        interior.EmptySince = now
    end
end

-- Intérieur où se trouve un joueur.
function PropertyInteriors.of(player: Player): Interior?
    for _, interior in interiors do
        if interior.Occupants[player] then
            return interior
        end
    end
    return nil
end

function PropertyInteriors.all(): { Interior }
    local list: { Interior } = {}
    for _, interior in interiors do
        table.insert(list, interior)
    end
    return list
end

-- Détruit les intérieurs vides depuis `delay` secondes.
function PropertyInteriors.collect(now: number, delay: number)
    for key, interior in interiors do
        if next(interior.Occupants) == nil and interior.EmptySince and now - interior.EmptySince >= delay then
            interior.Model:Destroy()
            interiors[key] = nil
            for index, owner in cells do
                if owner == key then
                    cells[index] = nil
                end
            end
        end
    end
end

return table.freeze(PropertyInteriors)
