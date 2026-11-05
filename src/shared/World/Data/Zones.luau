--!strict
-- Données VERSIONNÉES des sept zones (cahier des charges §2.1) et du relief.
-- Mètres ; x vers l'est, z vers le sud. Une position appartient à la première
-- zone (dans l'ordre de `Lookup`) dont le polygone la contient ; les Banlieues
-- servent de zone par défaut (couronne autour de la métropole).

type Point = { X: number, Z: number }

local function p(x: number, z: number): Point
    return { X = x, Z = z }
end

local function circle(radius: number, steps: number): { Point }
    local points = {}
    for i = 0, steps - 1 do
        local b = math.rad(i * 360 / steps)
        table.insert(points, p(radius * math.sin(b), -radius * math.cos(b)))
    end
    return points
end

local zones = {
    Metropole = {
        Name = "Métropole de Valcourt",
        Polygon = circle(1580, 48),
    },
    Motorsport = {
        Name = "Complexe motorsport du Val d'Ouest",
        Polygon = { p(-5000, -1450), p(-3650, -1450), p(-3650, 450), p(-5000, 450) },
    },
    Docks = {
        Name = "Docks et zone industrielle du Levant",
        Polygon = { p(2250, -950), p(4600, -950), p(4600, 1900), p(2250, 1900) },
    },
    Littoral = {
        Name = "Côte des Embruns",
        Polygon = {
            p(-5000, 2900),
            p(-1400, 3110),
            p(1200, 3120),
            p(2250, 2600),
            p(2250, 1950),
            p(5000, 1950),
            p(5000, 5000),
            p(-5000, 5000),
        },
    },
    Montagnes = {
        Name = "Massif du Grand Ravin",
        Polygon = { p(1200, -5000), p(5000, -5000), p(5000, -950), p(2250, -950), p(2250, -1500), p(1300, -2300) },
    },
    Campagne = {
        Name = "Plaine des Peupliers",
        Polygon = {
            p(-5000, -5000),
            p(1200, -5000),
            p(1300, -2300),
            p(600, -1750),
            p(-1300, -1850),
            p(-3100, -1700),
            p(-3650, -1450),
            p(-5000, -1450),
        },
    },
    Banlieues = {
        Name = "Couronne des Banlieues",
        Polygon = { p(-5000, -5000), p(5000, -5000), p(5000, 5000), p(-5000, 5000) },
    },
}

return table.freeze({
    Zones = zones,
    -- Ordre de recherche (la dernière zone couvre toute la carte).
    Lookup = { "Metropole", "Motorsport", "Docks", "Littoral", "Montagnes", "Campagne", "Banlieues" },
    -- Mer : polygone au sud et à l'est (sous les falaises et le long des quais).
    Sea = {
        p(-5000, 3500),
        p(-3400, 3430),
        p(-2500, 3560),
        p(-1000, 3620),
        p(0, 3600),
        p(1500, 3570),
        p(2200, 3620),
        p(3000, 3430),
        p(3700, 3060),
        p(3960, 2400),
        p(4060, 1900),
        p(3960, 1650),
        p(3960, 300),
        p(3960, -700),
        p(4100, -1500),
        p(4400, -2200),
        p(5000, -2600),
        p(5000, 5000),
        p(-5000, 5000),
    },
    -- Reliefs (sommets coniques : x, z, hauteur m, rayon m). Le générateur ne
    -- pose jamais de relief sur une route ; il épaule les routes en altitude.
    Peaks = {
        { 3800, -3300, 230, 600 },
        { 4300, -3800, 300, 700 },
        { 2700, -3600, 200, 450 },
        { 1700, -3900, 180, 500 },
        { 3600, -4700, 260, 450 },
        { 2300, -4800, 240, 350 },
        { 4500, -2600, 160, 500 },
        { 1600, -2800, 120, 400 },
        -- Falaises du littoral est.
        { 2600, 3500, 30, 160 },
        { 3300, 3200, 40, 220 },
        { 3750, 2700, 25, 180 },
        -- Collines de la campagne.
        { -1500, -3300, 25, 400 },
        { -3500, -3700, 35, 500 },
        { -600, -4700, 20, 300 },
    },
})
