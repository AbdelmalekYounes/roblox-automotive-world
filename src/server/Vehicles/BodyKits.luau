--!strict
--[[
    Carrosseries par SILHOUETTE (lot 0.8), construites par code à partir de
    pièces et de coins (aucun maillage ni actif externe) : chaque modèle de la
    gamme a des proportions propres (longueur, largeur, hauteur, empattement,
    garde au sol, capot, pare-brise, pavillon, poupe) tirées de sa définition
    et de son style. Assemblage provisoire « semi-réaliste » en attendant les
    maillages définitifs (statut dans Shared/Assets/AssetManifest).

    Pièces sans masse soudées au châssis : la dynamique reste celle du bloc
    châssis (inerties, contacts). Noms conservés pour les systèmes existants :
    Carrosserie/Coque, BouclierAvant, BouclierArriere, Phare*, Feu* (dégâts),
    Habitacle (vitrage collisionnable), Toit, PlancheDeBord, Volant.
    Détails fins dans Carrosserie/Details (masqués au loin par le client).
]]

local BodyKits = {}

export type Geometry = {
    GroundY: number,
    HubY: number,
    FrontAxleZ: number,
    RearAxleZ: number,
    TireRadius: number, -- studs
    TireWidth: number,
    Width: number,
    Length: number,
    Height: number,
}

export type Result = {
    SeatOffset: CFrame, -- siège conducteur
    PassengerOffset: CFrame,
    CabinZ: number,
    DashZ: number,
    DashY: number,
    HoodY: number,
    FrontEnd: number,
    RearEnd: number,
    BodyWidth: number,
    FloorY: number,
    RoofY: number?, -- dessous du pavillon (nil : sans toit), lot 0.9.1
}

-- Proportions des silhouettes (fractions de la longueur depuis l'avant, hauteurs en m).
type Style = {
    Hood: number, -- fin du capot / pied de pare-brise
    Shield: number, -- haut du pare-brise (début du pavillon)
    RoofEnd: number, -- fin du pavillon
    Tail: number, -- fin de la lunette ou du hayon
    BeltM: number, -- hauteur de la ceinture de caisse
    ClearanceM: number, -- garde au sol visuelle (bas des boucliers)
    Open: boolean?, -- sans toit (roadster)
    Bed: boolean?, -- benne (pick-up)
    Spare: boolean?, -- roue de secours (tout-terrain)
    Wing: boolean?, -- aileron
}

local STYLES: { [string]: Style } = {
    Micro = { Hood = 0.13, Shield = 0.32, RoofEnd = 0.86, Tail = 0.97, BeltM = 0.86, ClearanceM = 0.17 },
    Hatch = { Hood = 0.26, Shield = 0.42, RoofEnd = 0.82, Tail = 0.97, BeltM = 0.84, ClearanceM = 0.16 },
    Sedan = { Hood = 0.28, Shield = 0.44, RoofEnd = 0.7, Tail = 0.82, BeltM = 0.82, ClearanceM = 0.15 },
    Wagon = { Hood = 0.26, Shield = 0.41, RoofEnd = 0.93, Tail = 0.99, BeltM = 0.84, ClearanceM = 0.16 },
    Coupe = { Hood = 0.33, Shield = 0.52, RoofEnd = 0.68, Tail = 0.92, BeltM = 0.76, ClearanceM = 0.13 },
    Roadster = { Hood = 0.36, Shield = 0.5, RoofEnd = 0.62, Tail = 0.7, BeltM = 0.72, ClearanceM = 0.13, Open = true },
    Supercar = { Hood = 0.24, Shield = 0.44, RoofEnd = 0.6, Tail = 0.94, BeltM = 0.62, ClearanceM = 0.1, Wing = true },
    SUV = { Hood = 0.24, Shield = 0.37, RoofEnd = 0.93, Tail = 0.99, BeltM = 1.0, ClearanceM = 0.24 },
    OffRoad = { Hood = 0.22, Shield = 0.31, RoofEnd = 0.96, Tail = 0.99, BeltM = 1.0, ClearanceM = 0.3, Spare = true },
    Pickup = { Hood = 0.22, Shield = 0.33, RoofEnd = 0.53, Tail = 0.55, BeltM = 1.02, ClearanceM = 0.27, Bed = true },
}
BodyKits.Styles = STYLES

function BodyKits.has(style: string?): boolean
    return style ~= nil and STYLES[style :: string] ~= nil
end

export type AddVisual = (props: { [string]: any }) -> BasePart

local function wedge(
    add: AddVisual,
    name: string,
    x: number,
    width: number,
    z1: number,
    z2: number,
    y1: number,
    y2: number,
    color: Color3,
    material: Enum.Material?,
    transparency: number?
): BasePart
    -- Coin montant de (z1, y1) vers (z2, y2), « l'avant » du coin vers -Z.
    local dz, dy = z2 - z1, y2 - y1
    local lengthZ = math.abs(dz)
    local part = add({
        Name = name,
        Size = Vector3.new(width, math.abs(dy), lengthZ),
        Offset = CFrame.new(x, (y1 + y2) / 2, (z1 + z2) / 2)
            * (if (dy > 0) == (dz > 0) then CFrame.identity else CFrame.Angles(0, math.pi, 0)),
        Color = color,
        Material = material,
        Transparency = transparency,
        Shape = "Wedge",
    })
    return part
end

--[[
    Construit la carrosserie. `add(props)` crée une pièce visuelle soudée au
    châssis (VehicleFactory) ; props.Detail = vrai la range dans Details.
]]
function BodyKits.build(
    styleName: string,
    g: Geometry,
    colors: { Body: Color3, Accent: Color3, Trim: Color3 },
    studs: (number) -> number,
    add: AddVisual
): Result
    local style = STYLES[styleName]
    local L = g.Length
    local frontEnd = -L / 2
    local function z(fraction: number): number
        return frontEnd + L * fraction
    end
    local width = g.Width - 0.2
    local clearance = g.GroundY + studs(style.ClearanceM)
    local belt = g.GroundY + studs(style.BeltM)
    local roof = g.GroundY + g.Height
    -- Bas de caisse au-dessus du haut des roues (les roues restent visibles dessous).
    local bodyBottom = math.min(belt - 0.6, math.max(clearance + 0.4, g.HubY + g.TireRadius * 0.55))
    local glass = Color3.fromRGB(120, 150, 170)

    -- Caisse principale (collisionnable) et boucliers.
    add({
        Name = "Coque",
        Size = Vector3.new(width, belt - bodyBottom, L - 1.2),
        Offset = CFrame.new(0, (belt + bodyBottom) / 2, 0),
        Color = colors.Body,
        CanCollide = true,
    })
    local bumpers: { { Name: string, Z: number } } = {
        { Name = "BouclierAvant", Z = frontEnd + 0.35 },
        { Name = "BouclierArriere", Z = -frontEnd - 0.35 },
    }
    for _, bumper in bumpers do
        add({
            Name = bumper.Name,
            Size = Vector3.new(width - 0.1, bodyBottom - clearance + 0.5, 0.7),
            Offset = CFrame.new(0, (bodyBottom + clearance + 0.5) / 2, bumper.Z),
            Color = colors.Trim,
            CanCollide = true,
        })
    end
    -- Bas de caisse latéraux entre les roues.
    local gapStart = g.FrontAxleZ + g.TireRadius + 0.3
    local gapEnd = g.RearAxleZ - g.TireRadius - 0.3
    if gapEnd > gapStart then
        for _, side in { -1, 1 } do
            add({
                Name = "BasDeCaisse",
                Size = Vector3.new(0.25, bodyBottom - clearance, gapEnd - gapStart),
                Offset = CFrame.new(side * (width / 2 - 0.12), (bodyBottom + clearance) / 2, (gapStart + gapEnd) / 2),
                Color = colors.Trim,
            })
        end
    end
    -- Passages de roues (arches sombres au-dessus de chaque roue).
    for index, axleZ in { g.FrontAxleZ, g.FrontAxleZ, g.RearAxleZ, g.RearAxleZ } do
        local side = if index % 2 == 1 then -1 else 1
        add({
            Name = "Aile",
            Size = Vector3.new(0.12, 0.35, g.TireRadius * 2.3),
            Offset = CFrame.new(side * (width / 2 + 0.02), bodyBottom + 0.1, axleZ),
            Color = colors.Trim,
        })
    end

    -- Calandre, phares, feux.
    add({
        Name = "Calandre",
        Size = Vector3.new(width * 0.5, 0.45, 0.1),
        Offset = CFrame.new(0, bodyBottom + 0.45, frontEnd + 0.62),
        Color = Color3.fromRGB(20, 20, 22),
        Detail = true,
    })
    for _, side in { -1, 1 } do
        local suffix = if side < 0 then "Gauche" else "Droit"
        add({
            Name = "Phare" .. suffix,
            Size = Vector3.new(width * 0.2, 0.35, 0.12),
            Offset = CFrame.new(side * width * 0.32, belt - 0.4, frontEnd + 0.6),
            Color = Color3.fromRGB(255, 250, 225),
            Material = Enum.Material.Neon,
            Light = "Head",
        })
        add({
            Name = "Feu" .. suffix,
            Size = Vector3.new(width * 0.2, 0.3, 0.12),
            Offset = CFrame.new(side * width * 0.32, belt - 0.35, -frontEnd - 0.6),
            Color = Color3.fromRGB(190, 20, 20),
            Material = Enum.Material.Neon,
            Light = "Tail",
        })
        -- Rétroviseurs (détails).
        add({
            Name = "Retroviseur",
            Size = Vector3.new(0.5, 0.3, 0.2),
            Offset = CFrame.new(side * (width / 2 + 0.25), belt + 0.4, z(style.Hood) + 0.6),
            Color = colors.Body,
            Detail = true,
        })
    end
    -- Bande de couleur d'accent le long de la ceinture.
    add({
        Name = "Filet",
        Size = Vector3.new(width + 0.03, 0.12, L - 2),
        Offset = CFrame.new(0, belt - 0.15, 0),
        Color = colors.Accent,
        Detail = true,
    })

    -- Superstructure : pare-brise, pavillon vitré, lunette ou hayon.
    local hoodZ, shieldZ, roofEndZ, tailZ = z(style.Hood), z(style.Shield), z(style.RoofEnd), z(style.Tail)
    local cabinWidth = width - 0.5
    local cabinTop = if style.Open then belt + (roof - belt) * 0.55 else roof
    wedge(add, "PareBrise", 0, cabinWidth, hoodZ, shieldZ, belt, cabinTop, glass, Enum.Material.Glass, 0.35)
    if not style.Open then
        add({
            Name = "Habitacle",
            Size = Vector3.new(cabinWidth, roof - belt, roofEndZ - shieldZ),
            Offset = CFrame.new(0, (roof + belt) / 2, (shieldZ + roofEndZ) / 2),
            Color = glass,
            Material = Enum.Material.Glass,
            Transparency = 0.5,
            CanCollide = true,
        })
        add({
            Name = "Toit",
            Size = Vector3.new(cabinWidth + 0.1, 0.2, roofEndZ - shieldZ + 0.1),
            Offset = CFrame.new(0, roof + 0.1, (shieldZ + roofEndZ) / 2),
            Color = colors.Body,
        })
        -- Montants (lisibilité de la silhouette).
        for _, side in { -1, 1 } do
            for _, pz in { shieldZ + 0.15, roofEndZ - 0.15 } do
                add({
                    Name = "Montant",
                    Size = Vector3.new(0.18, roof - belt, 0.3),
                    Offset = CFrame.new(side * (cabinWidth / 2 - 0.05), (roof + belt) / 2, pz),
                    Color = colors.Body,
                    Detail = true,
                })
            end
        end
        if tailZ > roofEndZ + 0.2 then
            wedge(add, "Lunette", 0, cabinWidth, tailZ, roofEndZ, belt, roof, glass, Enum.Material.Glass, 0.35)
        end
    else
        -- Roadster : arceaux derrière les sièges, habitacle ouvert (vitrage bas collisionnable).
        add({
            Name = "Habitacle",
            Size = Vector3.new(cabinWidth, 0.3, roofEndZ - shieldZ),
            Offset = CFrame.new(0, belt + 0.15, (shieldZ + roofEndZ) / 2),
            Color = colors.Trim,
            CanCollide = true,
        })
        for _, side in { -1, 1 } do
            add({
                Name = "Arceau",
                Size = Vector3.new(0.3, roof - belt - 0.4, 0.3),
                Offset = CFrame.new(side * cabinWidth * 0.25, (roof + belt - 0.4) / 2, roofEndZ),
                Color = colors.Trim,
            })
        end
        add({
            Name = "Toit",
            Size = Vector3.new(0.1, 0.1, 0.1),
            Offset = CFrame.new(0, belt, roofEndZ),
            Color = colors.Trim,
            Detail = true,
        })
    end
    if style.Bed then
        -- Benne : ridelles latérales et hayon.
        for _, side in { -1, 1 } do
            add({
                Name = "Ridelle",
                Size = Vector3.new(0.2, 1.1, -frontEnd * 2 * (1 - style.Tail) - 0.6),
                Offset = CFrame.new(side * (width / 2 - 0.1), belt + 0.55, (tailZ - frontEnd) / 2 + 0.3),
                Color = colors.Body,
            })
        end
        add({
            Name = "Hayon",
            Size = Vector3.new(width - 0.2, 1.1, 0.2),
            Offset = CFrame.new(0, belt + 0.55, -frontEnd - 0.75),
            Color = colors.Body,
        })
    end
    if style.Spare then
        add({
            Name = "RoueSecours",
            Size = Vector3.new(g.TireWidth, g.TireRadius * 1.9, g.TireRadius * 1.9),
            Offset = CFrame.new(0, (belt + bodyBottom) / 2 + 0.3, -frontEnd + 0.15) * CFrame.Angles(0, math.pi / 2, 0),
            Color = Color3.fromRGB(25, 25, 27),
            Material = Enum.Material.Rubber,
            Shape = "Cylinder",
            Detail = true,
        })
    end
    if style.Wing then
        add({
            Name = "Aileron",
            Size = Vector3.new(width - 0.4, 0.15, 0.9),
            Offset = CFrame.new(0, belt + 0.9, -frontEnd - 0.9),
            Color = colors.Accent,
        })
        for _, side in { -1, 1 } do
            add({
                Name = "PiedAileron",
                Size = Vector3.new(0.15, 0.8, 0.3),
                Offset = CFrame.new(side * (width / 2 - 0.8), belt + 0.45, -frontEnd - 0.9),
                Color = colors.Trim,
                Detail = true,
            })
        end
    end

    -- Habitacle : planche de bord, combiné, console, sièges.
    local floor = bodyBottom + 0.2
    local cabinZ = (shieldZ + roofEndZ) / 2
    local dashZ = shieldZ + 0.35
    local dashY = belt - 0.05
    add({
        Name = "PlancheDeBord",
        Size = Vector3.new(cabinWidth - 0.3, 0.55, 0.8),
        Offset = CFrame.new(0, dashY, dashZ),
        Color = colors.Trim,
    })
    add({
        Name = "Combine",
        Size = Vector3.new(0.9, 0.35, 0.08),
        Offset = CFrame.new(-cabinWidth / 4, dashY + 0.3, dashZ + 0.25),
        Color = Color3.fromRGB(30, 60, 90),
        Material = Enum.Material.Neon,
        Detail = true,
    })
    add({
        Name = "Console",
        Size = Vector3.new(0.5, 0.5, 1.6),
        Offset = CFrame.new(0, floor + 0.25, dashZ + 1.1),
        Color = colors.Trim,
        Detail = true,
    })
    -- Hauteur d'assise : sous le pavillon, au-dessus du plancher (avatar assis ≈ 4,5 studs).
    local seatY = math.max(floor, roof - 4.5)
    local seatZ = math.min(cabinZ + 0.6, roofEndZ - 1.6)
    for _, side in { -1, 1 } do
        add({
            Name = "Dossier",
            Size = Vector3.new(1.5, 1.8, 0.4),
            Offset = CFrame.new(side * cabinWidth / 4, seatY + 1, seatZ + 0.9) * CFrame.Angles(math.rad(-12), 0, 0),
            Color = colors.Trim,
            Detail = true,
        })
    end
    return {
        SeatOffset = CFrame.new(-cabinWidth / 4, seatY, seatZ),
        PassengerOffset = CFrame.new(cabinWidth / 4, seatY, seatZ),
        CabinZ = cabinZ,
        DashZ = dashZ,
        DashY = dashY,
        HoodY = belt,
        FrontEnd = frontEnd,
        RearEnd = -frontEnd,
        BodyWidth = width,
        FloorY = floor,
        RoofY = if style.Open then nil else roof,
    }
end

return table.freeze(BodyKits)
