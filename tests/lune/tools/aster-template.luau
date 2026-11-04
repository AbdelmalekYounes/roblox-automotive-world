--!strict
-- Export du gabarit technique de l'Aster (phase 1) : cotes en JSON, maquette en blocs et
-- témoins d'étalonnage (cube de 10 st, roue) en OBJ, unité = 1 stud, avant vers −Z.
-- Lecture seule du jeu ; les fichiers vont dans le dépôt d'art (vehicles/wk_aster/ref-sheets).
-- Usage : lune run tests/lune/tools/aster-template.luau build/AutomotiveWorld.rbxlx <dossier> [params.json]
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Harness = require("../Harness")
Harness.loadPlace(process.args[1] or "build/AutomotiveWorld.rbxlx")
local Definitions = Harness.require("ReplicatedStorage.Shared.Vehicles.VehicleDefinitions")
local Dynamics = Harness.require("ReplicatedStorage.Shared.Vehicles.Physics.VehicleDynamics")
local Constants = Harness.require("ReplicatedStorage.Shared.Vehicles.VehicleConstants")
local AsterTemplate = require("../../studio/AsterTemplate")

local out = process.args[2] or "build/aster-template"
local params = if process.args[3] then serde.decode("json", fs.readFile(process.args[3])) else nil
local definition = Definitions.get("wk_aster")
local template = AsterTemplate.build(definition, Dynamics.wheelLayout(definition), Constants.MetersPerStud, params)

local lines: { string } = { "# Gabarit de l'Aster (wk_aster), unité 1 stud = 0,28 m, avant vers -Z", "" }
local vertexCount = 0
local function emit(name: string, vertices: { { number } }, faces: { { number } })
    table.insert(lines, "o " .. name)
    for _, v in vertices do
        table.insert(lines, string.format("v %.4f %.4f %.4f", v[1], v[2], v[3]))
    end
    for _, f in faces do
        local idx = {}
        for _, i in f do
            table.insert(idx, tostring(i + vertexCount))
        end
        table.insert(lines, "f " .. table.concat(idx, " "))
    end
    vertexCount += #vertices
end

local function cuboid(name: string, c: { number }, s: { number })
    local hx, hy, hz = s[1] / 2, s[2] / 2, s[3] / 2
    local v = {}
    for _, dx in { -1, 1 } do
        for _, dy in { -1, 1 } do
            for _, dz in { -1, 1 } do
                table.insert(v, { c[1] + dx * hx, c[2] + dy * hy, c[3] + dz * hz })
            end
        end
    end
    emit(name, v, { { 1, 2, 4, 3 }, { 5, 7, 8, 6 }, { 1, 5, 6, 2 }, { 3, 4, 8, 7 }, { 1, 3, 7, 5 }, { 2, 6, 8, 4 } })
end

-- Cylindre d'axe X (16 côtés).
local function cylinder(name: string, c: { number }, s: { number })
    local n, r, hx = 16, s[2] / 2, s[1] / 2
    local v = {}
    for _, dx in { -hx, hx } do
        for i = 0, n - 1 do
            local a = i / n * 2 * math.pi
            table.insert(v, { c[1] + dx, c[2] + r * math.cos(a), c[3] + r * math.sin(a) })
        end
    end
    local faces = {}
    for i = 1, n do
        local j = i % n + 1
        table.insert(faces, { i, j, n + j, n + i })
    end
    local capA, capB = {}, {}
    for i = 1, n do
        table.insert(capA, n + 1 - i)
        table.insert(capB, n + i)
    end
    table.insert(faces, capA)
    table.insert(faces, capB)
    emit(name, v, faces)
end

for _, item in template.Boxes do
    if item.Cylinder then
        cylinder(item.Name, item.Center, item.Size)
    else
        cuboid(item.Name, item.Center, item.Size)
    end
end

if not fs.isDir(out) then
    fs.writeDir(out)
end
fs.writeFile(out .. "/wk_aster_gabarit.obj", table.concat(lines, "\n") .. "\n")
fs.writeFile(out .. "/wk_aster_gabarit.json", serde.encode("json", template, true))
-- Témoins d'étalonnage de l'échelle d'export (PIPELINE_BLENDER_ROBLOX.md §4).
lines, vertexCount = { "# Témoins d'étalonnage : cube de 10 studs, roue de l'Aster (rayon et largeur du jeu)", "" }, 0
cuboid("CubeTemoin10st", { 0, 5, 0 }, { 10, 10, 10 })
local tire = definition.Tires
cylinder("RoueTemoin", { 14, tire.RadiusM / Constants.MetersPerStud, 0 }, {
    tire.WidthM / Constants.MetersPerStud,
    tire.RadiusM * 2 / Constants.MetersPerStud,
    tire.RadiusM * 2 / Constants.MetersPerStud,
})
fs.writeFile(out .. "/temoins_etalonnage.obj", table.concat(lines, "\n") .. "\n")
print(
    string.format(
        "gabarit écrit dans %s : %d blocs ; assise %.2f st, pavillon %.2f st, hauteur hors tout %.2f m",
        out,
        #template.Boxes,
        template.SeatTop,
        template.RoofUnder,
        template.HeightAboveGroundM
    )
)
