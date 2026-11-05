--!strict
-- Relevé (lecture seule) de la géométrie d'un véhicule du jeu pour caler un modèle 3D : centres de roues, sol,
-- dimensions de la définition, et repères de la carrosserie provisoire (sièges, collisions, caméras CameraHood et
-- CameraBumper selon la règle de VehicleFactory). Repère du châssis, en studs, avant vers −Z. Aucune modification du jeu.
-- Usage : lune run tests/lune/tools/vehicle-geometry.luau build/AutomotiveWorld.rbxlx <id> <sortie.json>
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Harness = require("../Harness")
Harness.loadPlace(process.args[1] or "build/AutomotiveWorld.rbxlx")
local Definitions = Harness.require("ReplicatedStorage.Shared.Vehicles.VehicleDefinitions")
local Dynamics = Harness.require("ReplicatedStorage.Shared.Vehicles.Physics.VehicleDynamics")
local Constants = Harness.require("ReplicatedStorage.Shared.Vehicles.VehicleConstants")

local M = Constants.MetersPerStud
local function studs(meters: number): number
    return meters / M
end
local function round(v: number): number
    return math.floor(v * 1000 + 0.5) / 1000
end

local id = process.args[2] or "wk_comete"
local definition = Definitions.get(id)
assert(definition, "véhicule inconnu : " .. id)
local chassis, tire = definition.Chassis, definition.Tires
local layout = Dynamics.wheelLayout(definition)
local groundY = -studs(chassis.CgHeightM)
local hubY = groundY + studs(tire.RadiusM)
local wheels = {}
for index, name in Constants.WheelNames do
    local place = layout[index]
    table.insert(
        wheels,
        { Name = name, Center = { round(studs(place.Lateral)), round(hubY), round(-studs(place.Longitudinal)) } }
    )
end
local result: any = {
    Vehicle = id,
    MetersPerStud = M,
    Ground = round(groundY),
    LengthSt = round(studs(chassis.LengthM)),
    WidthSt = round(studs(chassis.WidthM)),
    HeightSt = round(studs(chassis.HeightM)),
    TireRadiusSt = round(studs(tire.RadiusM)),
    TireWidthSt = round(studs(tire.WidthM)),
    Wheels = wheels,
}
-- Lot BASE-01 : carrosseries provisoires (BodyKits) supprimées ; l'outil ne donne plus que roues et dimensions.
local out = process.args[3] or ("build/" .. id .. "-geometry.json")
fs.writeFile(out, serde.encode("json", result, true))
print("AW_GEOMETRIE", id, #wheels, "roues", out)
