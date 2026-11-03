--!strict
--[[
    Installations PHYSIQUES des épreuves (lot 0.6), construites par code au
    démarrage du serveur à partir des parcours validés (aucun modèle ni actif
    externe) :
    - point d'inscription (dalle et invite « Course ») hors chaussée, près du
      départ : on rejoint une épreuve en s'y présentant avec sa voiture ;
    - ligne de départ (et d'arrivée sur une boucle), ligne d'arrivée, portique ;
    - places de grille peintes (sprint, circuit), couloirs et arbre de départ
      à feux (drag), box de départ individuel (contre-la-montre, rallye),
      repères de la zone de drift.
    Marquages non collisionnables et non détectés par les rayons : ils ne
    modifient ni la physique ni la conduite. Les points de contrôle ne sont
    affichés que pour les participants (client).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))
local RaceCourse = require(script.Parent.RaceCourse)

local RaceInstallations = {}

local S = 1 / Constants.MetersPerStud

export type Installation = {
    CourseId: string,
    Pad: BasePart,
    Lights: { [string]: BasePart }?, -- drag : Amber1..3, Green, Red
}

local LIGHT_OFF = Color3.fromRGB(40, 40, 40)
local LIGHT_COLORS = {
    Amber1 = Color3.fromRGB(255, 170, 0),
    Amber2 = Color3.fromRGB(255, 170, 0),
    Amber3 = Color3.fromRGB(255, 170, 0),
    Green = Color3.fromRGB(40, 220, 70),
    Red = Color3.fromRGB(230, 30, 30),
}

local function part(
    parent: Instance,
    name: string,
    size: Vector3,
    frame: CFrame,
    color: Color3,
    solid: boolean?
): BasePart
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.CanCollide = solid == true
    p.CanQuery = solid == true
    p.CanTouch = false
    p.CastShadow = false
    p.Material = Enum.Material.SmoothPlastic
    p.Color = color
    p.Size = size
    p.CFrame = frame
    p.Parent = parent
    return p
end

-- Altitude du sol (studs) sous un point en mètres : carte du monde ouvert ou zone d'essai.
local function groundAt(x: number, z: number, fallback: number, ignore: { Instance }): number
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore
    local hit = Workspace:Raycast(Vector3.new(x * S, 2500, z * S), Vector3.new(0, -5000, 0), params)
    return if hit then hit.Position.Y else fallback
end

-- Repère au sol orienté selon un cap (rad, 0 = nord).
local function flatFrame(x: number, z: number, y: number, heading: number): CFrame
    return CFrame.new(x * S, y + 0.06, z * S) * CFrame.Angles(0, -heading, 0)
end

local function line(folder: Instance, name: string, frame: RaceCourse.Frame, widthM: number, y: number, color: Color3)
    part(folder, name, Vector3.new(widthM * S, 0.1, 1.2), flatFrame(frame.X, frame.Z, y, frame.Heading), color)
end

local function arch(folder: Instance, name: string, frame: RaceCourse.Frame, widthM: number, y: number, label: string)
    local base = flatFrame(frame.X, frame.Z, y, frame.Heading)
    local half = widthM * S / 2 + 2
    for _, side in { -1, 1 } do
        part(
            folder,
            name .. "Poteau",
            Vector3.new(1.5, 22, 1.5),
            base * CFrame.new(side * half, 11, 0),
            Color3.fromRGB(60, 60, 70),
            true
        )
    end
    local banner = part(
        folder,
        name .. "Bandeau",
        Vector3.new(half * 2 + 1.5, 4, 0.6),
        base * CFrame.new(0, 21, 0),
        Color3.fromRGB(30, 34, 46)
    )
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Back
    gui.PixelsPerStud = 20
    gui.Parent = banner
    local text = Instance.new("TextLabel")
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.TextScaled = true
    text.Font = Enum.Font.GothamBold
    text.TextColor3 = Color3.fromRGB(255, 220, 120)
    text.Text = label
    text.Parent = gui
end

function RaceInstallations.build(
    courses: { [string]: RaceCourse.Built },
    parent: Instance,
    flat: boolean
): { [string]: Installation }
    local root = Instance.new("Folder")
    root.Name = "Courses"
    root.Parent = parent
    local ignore: { Instance } = { root }
    local installations: { [string]: Installation } = {}
    local ids: { string } = {}
    for id in courses do
        table.insert(ids, id)
    end
    table.sort(ids)
    for _, id in ids do
        local built = courses[id]
        local course = built.Course
        local folder = Instance.new("Folder")
        folder.Name = id
        folder.Parent = root
        local function y(x: number, z: number): number
            return if flat then 0 else groundAt(x, z, 0, ignore)
        end
        local width = built.RoadHalfWidthM * 2
        local white = Color3.fromRGB(240, 240, 240)
        local start = built.Start
        local startY = y(start.X, start.Z)
        -- Départ / arrivée.
        if built.Discipline ~= "Drift" then
            line(folder, "LigneDepart", start, width, startY, white)
            arch(folder, "PortiqueDepart", start, width, startY, course.Name)
            if not built.Closed then
                local finish = built.Finish
                local finishY = y(finish.X, finish.Z)
                line(folder, "LigneArrivee", finish, width, finishY, Color3.fromRGB(255, 80, 80))
                arch(folder, "PortiqueArrivee", finish, width, finishY, "ARRIVÉE")
            end
        end
        -- Places de grille ou de couloir ; box de départ individuel.
        if built.Discipline == "Sprint" or built.Discipline == "Circuit" or built.Discipline == "Drag" then
            for index, slot in built.Grid do
                local slotY = y(slot.X, slot.Z)
                part(
                    folder,
                    "Place" .. index,
                    Vector3.new(2.4 * S, 0.08, 4.8 * S),
                    flatFrame(slot.X, slot.Z, slotY, slot.Heading),
                    Color3.fromRGB(255, 200, 60)
                )
            end
        elseif built.Discipline == "TimeTrial" or built.Discipline == "Rally" then
            part(
                folder,
                "BoxDepart",
                Vector3.new(3 * S, 0.08, 6 * S),
                flatFrame(start.X, start.Z, startY, start.Heading),
                Color3.fromRGB(80, 200, 255)
            )
        end
        local lights: { [string]: BasePart }? = nil
        if built.Discipline == "Drag" then
            -- Arbre de départ en BORD de chaussée (lot 0.9) : au centre, son mât solide
            -- barrait la ligne droite d'essai (bancs du lot 0.2 bloqués, risque de choc).
            local side = width * S / 2 + 3
            local base = flatFrame(start.X, start.Z, startY, start.Heading) * CFrame.new(side, 0, 0)
            part(
                folder,
                "ArbreMat",
                Vector3.new(0.8, 14, 0.8),
                base * CFrame.new(0, 7, -2),
                Color3.fromRGB(50, 50, 55),
                true
            )
            local set: { [string]: BasePart } = {}
            for index, name in { "Red", "Amber1", "Amber2", "Amber3", "Green" } do
                local light = part(
                    folder,
                    "Feu" .. name,
                    Vector3.new(1.6, 1.6, 0.6),
                    base * CFrame.new(0, 14 - index * 2, -1.4),
                    LIGHT_OFF
                )
                light.Material = Enum.Material.Neon
                set[name] = light
            end
            lights = set
        end
        if built.Discipline == "Drift" and built.DriftCenter then
            local center = built.DriftCenter :: { X: number, Z: number }
            local radius = built.DriftRadiusM or 0
            for k = 0, 23 do
                local a = k / 24 * 2 * math.pi
                local x, z = center.X + math.cos(a) * radius, center.Z + math.sin(a) * radius
                part(
                    folder,
                    "BorneZone",
                    Vector3.new(1.2, 3, 1.2),
                    CFrame.new(x * S, y(x, z) + 1.5, z * S),
                    Color3.fromRGB(255, 120, 30)
                )
            end
        end
        -- Point d'inscription (hors chaussée).
        local reg = built.Registration
        local regY = y(reg.X, reg.Z)
        part(
            folder,
            "Inscription",
            Vector3.new(10 * S, 0.12, 10 * S),
            flatFrame(reg.X, reg.Z, regY, reg.Heading),
            Color3.fromRGB(120, 60, 200)
        )
        local anchor = part(
            folder,
            "InscriptionInvite",
            Vector3.new(2, 2, 2),
            CFrame.new(reg.X * S, regY + 4, reg.Z * S),
            Color3.fromRGB(120, 60, 200)
        )
        anchor.Transparency = 1
        installations[id] = { CourseId = id, Pad = anchor, Lights = lights }
    end
    return installations
end

-- Arbre de départ du drag : feux selon l'instant serveur (orange, vert, rouge).
function RaceInstallations.setLights(installation: Installation, state: { [string]: boolean })
    local lights = installation.Lights
    if lights == nil then
        return
    end
    for name, light in lights do
        light.Color = if state[name] then LIGHT_COLORS[name] else LIGHT_OFF
    end
end

return table.freeze(RaceInstallations)
