--!strict
--[[
    Gabarit technique de l'Aster (`wk_aster`), phase 1 (docs/vehicle-3d/ASTER_DESIGN_BRIEF.md).

    Module PUR (aucun service Roblox) : utilisé par la session VM « aster » (maquette en
    blocs dans Studio) et par l'outil Lune `tests/lune/tools/aster-template.luau` (export
    JSON et OBJ vers le dépôt d'art). Toutes les cotes en studs, repère du véhicule du jeu :
    origine au centre du châssis, avant vers −Z, haut +Y, sol à −CgHeightM.

    Décisions appliquées (propriétaire, 2026-11-04) : habitacle « échelle Roblox + assise
    basse » (D1 : assise abaissée, ≥ 4,30 st de l'assise au pavillon), pose assise du jeu
    (D3 : volant et pédalier placés d'après la pose, cotes mesurées en VM), direction A
    « Trait » (ligne de caisse haute, vitrage latéral fin). Les dimensions physiques de la
    définition ne sont jamais modifiées.
]]

local AsterTemplate = {}

export type Box = {
    Name: string,
    Role: string, -- "caisse", "vitrage", "habitacle", "siege", "roue", "repere"
    Center: { number },
    Size: { number },
    Cylinder: boolean?, -- cylindre d'axe X (roues, volant)
    Rotation: { number }?, -- degrés (X, Y, Z) appliqués au centre (volant tourné vers le conducteur)
    Seat: string?, -- "Conduite" ou "Passager" (siège réel du jeu, attribut AWSeatPose)
}

export type Params = {
    SeatDropSt: number, -- abaissement de l'assise par rapport à la carrosserie provisoire
    HeadroomSt: number, -- assise → dessous du pavillon
    SeatX: number, -- demi-écart des sièges
    Wheel: { Center: { number }, Radius: number, TiltDeg: number }?, -- volant (mesuré en VM)
    PedalZ: number?, -- pédalier (mesuré en VM)
    DashZ: number?, -- planche de bord (centre), devant le volant
}

AsterTemplate.Defaults = table.freeze({
    SeatDropSt = 0.4,
    HeadroomSt = 4.30,
    SeatX = 1.4,
} :: Params)

-- Assise provisoire actuelle de l'Aster (relevé `cabin-geometry.luau`, 2026-11-04) : dessus à
-- 0,36 st dans le repère du véhicule, siège à z = 2,42 st.
local PROVISIONAL_SEAT_TOP = 0.36
local PROVISIONAL_SEAT_Z = 2.42

local function box(name: string, role: string, center: { number }, size: { number }): Box
    return { Name = name, Role = role, Center = center, Size = size }
end

-- `definition` : définition du jeu ; `layout` : `VehicleDynamics.wheelLayout(definition)` ;
-- `metersPerStud` : `VehicleConstants.MetersPerStud`.
function AsterTemplate.build(
    definition: any,
    layout: { any },
    metersPerStud: number,
    params: Params?
): { [string]: any }
    local p = params or AsterTemplate.Defaults
    local S = 1 / metersPerStud
    local chassis, tires = definition.Chassis, definition.Tires
    local ground = -chassis.CgHeightM * S
    local L, W = chassis.LengthM * S, chassis.WidthM * S
    local front, rear = -L / 2, L / 2
    local seatTop = PROVISIONAL_SEAT_TOP - p.SeatDropSt
    local seatZ = PROVISIONAL_SEAT_Z
    local roofUnder = seatTop + p.HeadroomSt
    local floor = seatTop - 0.25
    local belt = seatTop + 1.6 -- ligne de caisse haute (direction « Trait »)
    local shieldZ = front + L * 0.40 -- haut du pare-brise
    local roofEndZ = front + L * 0.84 -- fin du pavillon (hayon presque vertical)
    local hoodZ = front + L * 0.24
    local radius = tires.RadiusM * S
    local boxes: { Box } = {}
    local function add(item: Box)
        table.insert(boxes, item)
    end
    -- Caisse : bas de caisse, flancs (portières) et coque avant/arrière.
    local sill = ground + 0.16 * S + 0.4
    add(box("Plancher", "habitacle", { 0, floor - 0.1, seatZ - 0.5 }, { W - 0.6, 0.2, roofEndZ - hoodZ }))
    add(
        box(
            "CaisseAvant",
            "caisse",
            { 0, (sill + belt - 0.3) / 2, (front + hoodZ) / 2 },
            { W, belt - 0.3 - sill, hoodZ - front }
        )
    )
    add(
        box(
            "CaisseArriere",
            "caisse",
            { 0, (sill + belt) / 2, (roofEndZ + rear) / 2 },
            { W, belt - sill, rear - roofEndZ }
        )
    )
    for _, side in { -1, 1 } do
        local name = if side < 0 then "PortiereGauche" else "PortiereDroite"
        add(
            box(
                name,
                "caisse",
                { side * (W / 2 - 0.125), (sill + belt) / 2, (hoodZ + roofEndZ) / 2 },
                { 0.25, belt - sill, roofEndZ - hoodZ }
            )
        )
        add(
            box(
                "Vitre" .. (if side < 0 then "Gauche" else "Droite"),
                "vitrage",
                { side * (W / 2 - 0.2), (belt + roofUnder) / 2, (shieldZ + roofEndZ) / 2 },
                { 0.1, roofUnder - belt, roofEndZ - shieldZ }
            )
        )
    end
    add(box("Toit", "caisse", { 0, roofUnder + 0.1, (shieldZ + roofEndZ) / 2 }, { W - 0.4, 0.2, roofEndZ - shieldZ }))
    add(
        box(
            "PareBrise",
            "vitrage",
            { 0, (belt + roofUnder) / 2, (hoodZ + shieldZ) / 2 },
            { W - 0.5, roofUnder - belt, 0.1 }
        )
    )
    add(box("Hayon", "vitrage", { 0, (belt + roofUnder) / 2, roofEndZ }, { W - 0.5, roofUnder - belt, 0.1 }))
    -- Habitacle : planche de bord au droit des genoux, sièges.
    local dashZ = p.DashZ or (if p.PedalZ then p.PedalZ + 1.1 else seatZ - 3.4)
    add(box("PlancheDeBord", "habitacle", { 0, belt - 0.35, dashZ }, { W - 0.6, 0.7, 1.0 }))
    for _, side in { -1, 1 } do
        local seatName = if side < 0 then "SiegeConducteur" else "SiegePassager"
        local seat = box(seatName, "siege", { side * p.SeatX, seatTop - 0.2, seatZ }, { 1.8, 0.4, 1.8 })
        seat.Seat = if side < 0 then "Conduite" else "Passager"
        add(seat)
        add(
            box(
                "Dossier" .. (if side < 0 then "Conducteur" else "Passager"),
                "habitacle",
                { side * p.SeatX, seatTop + 1.2, seatZ + 1.05 },
                { 1.6, 2.4, 0.35 }
            )
        )
    end
    if p.Wheel then
        -- Disque face au conducteur : axe du cylindre (X) tourné vers l'arrière (Z), puis incliné
        -- autour de l'axe latéral (haut du volant vers le conducteur). Composition des rotations :
        -- `AsterTemplate.rotate`.
        local wheel = box("Volant", "habitacle", p.Wheel.Center, { 0.15, p.Wheel.Radius * 2, p.Wheel.Radius * 2 })
        wheel.Cylinder = true
        wheel.Rotation = { -p.Wheel.TiltDeg, 90, 0 }
        add(wheel)
    end
    if p.PedalZ then
        add(box("Pedalier", "habitacle", { -p.SeatX, floor + 0.15, p.PedalZ :: number }, { 1.2, 0.3, 0.3 }))
    end
    -- Roues aux centres de la définition (avant vers −Z).
    for index, place in layout do
        local wheel = box(
            "Roue" .. index,
            "roue",
            { place.Lateral * S, ground + radius, -place.Longitudinal * S },
            { tires.WidthM * S, radius * 2, radius * 2 }
        )
        wheel.Cylinder = true
        add(wheel)
    end
    -- Repères : yeux de la vue cockpit (à placer d'après la pose), sorties.
    add(box("ExitLeft", "repere", { -(W / 2 + 1.5), ground + 0.1, seatZ }, { 0.2, 0.2, 0.2 }))
    add(box("ExitRight", "repere", { W / 2 + 1.5, ground + 0.1, seatZ }, { 0.2, 0.2, 0.2 }))
    return {
        Vehicle = definition.Id,
        MetersPerStud = metersPerStud,
        Ground = ground,
        SeatTop = seatTop,
        SeatZ = seatZ,
        RoofUnder = roofUnder,
        Belt = belt,
        Floor = floor,
        DoorInner = W / 2 - 0.25,
        DashZ = dashZ,
        HeightAboveGroundM = (roofUnder + 0.2 - ground) * metersPerStud,
        Boxes = boxes,
    }
end

-- Rotation d'un bloc (degrés X, Y, Z) appliquée à un vecteur de son repère local : même
-- composition que la maquette VM, `CFrame.Angles(x, 0, z) * CFrame.Angles(0, y, 0)`, soit
-- v' = Rx(Rz(Ry(v))). Sert à l'export OBJ (sommets tournés comme dans Studio).
function AsterTemplate.rotate(rotation: { number }, v: { number }): { number }
    local rx, ry, rz = math.rad(rotation[1]), math.rad(rotation[2]), math.rad(rotation[3])
    local x, y, z = v[1], v[2], v[3]
    -- Ry
    x, z = x * math.cos(ry) + z * math.sin(ry), -x * math.sin(ry) + z * math.cos(ry)
    -- Rz
    x, y = x * math.cos(rz) - y * math.sin(rz), x * math.sin(rz) + y * math.cos(rz)
    -- Rx
    y, z = y * math.cos(rx) - z * math.sin(rx), y * math.sin(rx) + z * math.cos(rx)
    return { x, y, z }
end

return AsterTemplate
