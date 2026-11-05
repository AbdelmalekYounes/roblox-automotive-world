--!strict
-- Construit par code la zone d'essai isolée du lot 0.1.
-- Toute la géométrie est créée ici, de façon lisible et inspectable :
-- aucun modèle, maillage ni actif externe (Marketplace ou autre projet).
-- Ce n'est PAS une des sept zones du jeu, seulement un terrain d'essai.

local Workspace = game:GetService("Workspace")

local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Vehicles.VehicleConstants)

local TestZoneBuilder = {}

local STUDS_PER_METER = 1 / Constants.MetersPerStud

export type TestZone = {
    Folder: Folder,
    Pads: { BasePart },
}

type PartProps = {
    Name: string,
    Size: Vector3,
    CFrame: CFrame,
    Color: Color3,
    Material: Enum.Material?,
    CanCollide: boolean?,
    Transparency: number?,
}

local function makePart(parent: Instance, props: PartProps): BasePart
    local part = Instance.new("Part")
    part.Name = props.Name
    part.Anchored = true
    part.Size = props.Size
    part.CFrame = props.CFrame
    part.Color = props.Color
    part.Material = props.Material or Enum.Material.SmoothPlastic
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    local collide = props.CanCollide ~= false
    part.CanCollide = collide
    -- Les marquages au sol ne doivent ni bloquer ni être détectés par les rayons.
    part.CanQuery = collide
    part.CanTouch = false
    part.Transparency = props.Transparency or 0
    part.Parent = parent
    return part
end

-- Marquage plat (non collisionnable) posé sur le sol.
local function paint(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3)
    makePart(parent, {
        Name = name,
        Size = Vector3.new(size.X, 0.05, size.Z),
        CFrame = CFrame.new(position.X, 0.03, position.Z),
        Color = color,
        CanCollide = false,
    })
end

local function addSign(parent: Instance, text: string, position: Vector3)
    local post = makePart(parent, {
        Name = "Panneau_" .. text,
        Size = Vector3.new(6, 3, 0.4),
        CFrame = CFrame.new(position + Vector3.new(0, 4, 0)),
        Color = Color3.fromRGB(240, 240, 240),
        CanCollide = false,
    })
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Back
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 40
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.fromRGB(20, 20, 20)
    label.Parent = gui
    gui.Parent = post
end

function TestZoneBuilder.build(): TestZone
    local existing = Workspace:FindFirstChild("AutomotiveTestZone")
    if existing then
        existing:Destroy()
    end

    local folder = Instance.new("Folder")
    folder.Name = "AutomotiveTestZone"

    local asphalt = Color3.fromRGB(52, 54, 58)
    local white = Color3.fromRGB(235, 235, 230)
    local orange = Color3.fromRGB(255, 122, 26)

    -- Sol principal : 1400 × 1400 studs (≈ 390 m de côté), dessus à Y = 0.
    makePart(folder, {
        Name = "Sol",
        Size = Vector3.new(1400, 4, 1400),
        CFrame = CFrame.new(0, -2, -400),
        Color = asphalt,
        Material = Enum.Material.Asphalt,
    })

    -- Murets périphériques : la zone reste fermée et isolée.
    local wallColor = Color3.fromRGB(200, 60, 50)
    makePart(folder, {
        Name = "MuretNord",
        Size = Vector3.new(1400, 4, 2),
        CFrame = CFrame.new(0, 2, -1099),
        Color = wallColor,
        Material = Enum.Material.Concrete,
    })
    makePart(folder, {
        Name = "MuretSud",
        Size = Vector3.new(1400, 4, 2),
        CFrame = CFrame.new(0, 2, 299),
        Color = wallColor,
        Material = Enum.Material.Concrete,
    })
    makePart(folder, {
        Name = "MuretOuest",
        Size = Vector3.new(2, 4, 1400),
        CFrame = CFrame.new(-699, 2, -400),
        Color = wallColor,
        Material = Enum.Material.Concrete,
    })
    makePart(folder, {
        Name = "MuretEst",
        Size = Vector3.new(2, 4, 1400),
        CFrame = CFrame.new(699, 2, -400),
        Color = wallColor,
        Material = Enum.Material.Concrete,
    })

    -- Point d'apparition des joueurs, à l'écart des trajectoires de conduite.
    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "ApparitionEssai"
    spawn.Anchored = true
    spawn.Size = Vector3.new(12, 1, 12)
    spawn.CFrame = CFrame.new(0, 0.5, 70)
    spawn.Neutral = true
    spawn.Duration = 0
    spawn.Color = Color3.fromRGB(70, 130, 180)
    spawn.Material = Enum.Material.SmoothPlastic
    spawn.Parent = folder

    -- Plots de stationnement des véhicules d'essai (face au nord, -Z).
    local pads: { BasePart } = {}
    for index, x in { -36, -12, 12, 36 } do
        local pad = makePart(folder, {
            Name = "Plot" .. index,
            Size = Vector3.new(10, 0.05, 20),
            CFrame = CFrame.new(x, 0.03, 20),
            Color = Color3.fromRGB(90, 150, 90),
            CanCollide = false,
        })
        table.insert(pads, pad)
    end

    -- Ligne droite d'essai (accélération / freinage) : couloir de 24 studs,
    -- ligne de départ en Z = -10, repères tous les 10 m, panneaux tous les 50 m.
    local lane = Instance.new("Folder")
    lane.Name = "LigneDroite"
    lane.Parent = folder
    local startZ = -10
    paint(lane, "LigneDepart", Vector3.new(24, 0, 1.5), Vector3.new(0, 0, startZ), white)
    paint(lane, "BordGauche", Vector3.new(0.6, 0, 900), Vector3.new(-12, 0, startZ - 450), white)
    paint(lane, "BordDroit", Vector3.new(0.6, 0, 900), Vector3.new(12, 0, startZ - 450), white)
    for meters = 10, 250, 10 do
        local z = startZ - meters * STUDS_PER_METER
        local isMajor = meters % 50 == 0
        paint(
            lane,
            "Repere" .. meters .. "m",
            Vector3.new(if isMajor then 24 else 6, 0, 0.5),
            Vector3.new(0, 0, z),
            if isMajor then orange else white
        )
        if isMajor then
            addSign(lane, meters .. " m", Vector3.new(-16, 0, z))
        end
    end

    -- Slalom : plots légers non ancrés (cônes) espacés d'environ 17 m.
    local slalom = Instance.new("Folder")
    slalom.Name = "Slalom"
    slalom.Parent = folder
    for i = 0, 7 do
        local cone = makePart(slalom, {
            Name = "Cone" .. (i + 1),
            Size = Vector3.new(1.2, 2.4, 1.2),
            CFrame = CFrame.new(140, 1.2, -80 - i * 60),
            Color = orange,
        })
        cone.Anchored = false
        cone.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.6, 0.2)
    end

    -- Cercle de stabilisation (skidpad) peint, rayon 30 m.
    local skidpad = Instance.new("Folder")
    skidpad.Name = "CercleRayon30m"
    skidpad.Parent = folder
    local center = Vector3.new(-300, 0, -450)
    local radius = 30 * STUDS_PER_METER
    for i = 0, 47 do
        local angle = i / 48 * 2 * math.pi
        local position = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
        makePart(skidpad, {
            Name = "Segment" .. (i + 1),
            Size = Vector3.new(0.6, 0.05, 6),
            CFrame = CFrame.lookAt(position, center) * CFrame.Angles(0, math.pi / 2, 0) + Vector3.new(0, 0.03, 0),
            Color = white,
            CanCollide = false,
        })
    end

    -- Bosse à 10 % : rampe montante, plateau, rampe descendante.
    local hill = Instance.new("Folder")
    hill.Name = "Bosse10pc"
    hill.Parent = folder
    local hillX, hillZ, rise, rampLength, plateau = 300, -400, 6, 60, 40
    local concrete = Color3.fromRGB(110, 110, 115)
    makePart(hill, {
        Name = "Plateau",
        Size = Vector3.new(30, rise, plateau),
        CFrame = CFrame.new(hillX, rise / 2, hillZ),
        Color = concrete,
        Material = Enum.Material.Concrete,
    })
    -- Rampes en blocs inclinés (orientation sans ambiguïté) : une rotation
    -- positive autour de X abaisse l'extrémité +Z et relève l'extrémité -Z.
    local slope = math.atan(rise / rampLength)
    local slopeLength = math.sqrt(rampLength * rampLength + rise * rise)
    local thickness = 2
    for _, ramp in
        {
            { Name = "RampeMontee", Z = hillZ + plateau / 2 + rampLength / 2, Angle = slope },
            { Name = "RampeDescente", Z = hillZ - plateau / 2 - rampLength / 2, Angle = -slope },
        }
    do
        local rotation = CFrame.Angles(ramp.Angle, 0, 0)
        local topCenter = Vector3.new(hillX, rise / 2, ramp.Z)
        local rampCenter = topCenter - rotation.UpVector * (thickness / 2)
        makePart(hill, {
            Name = ramp.Name,
            Size = Vector3.new(30, thickness, slopeLength),
            CFrame = CFrame.new(rampCenter) * rotation,
            Color = concrete,
            Material = Enum.Material.Concrete,
        })
    end

    folder.Parent = Workspace
    return { Folder = folder, Pads = pads }
end

return TestZoneBuilder
