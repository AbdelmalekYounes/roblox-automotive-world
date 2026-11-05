--!strict
-- Relevé (lecture seule) de la géométrie d'un véhicule du jeu pour caler un modèle 3D : centres de roues, sol,
-- dimensions de la définition, et repères de la carrosserie provisoire (sièges, collisions, caméras CameraHood et
-- CameraBumper selon la règle de VehicleFactory). Repère du châssis, en studs, avant vers −Z. Aucune modification du jeu.
-- Usage : lune run tests/lune/tools/vehicle-geometry.luau build/AutomotiveWorld.rbxlx <id> <sortie.json>
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Color3 = roblox.Color3
local Harness = require("../Harness")
Harness.loadPlace(process.args[1] or "build/AutomotiveWorld.rbxlx")
local Definitions = Harness.require("ReplicatedStorage.Shared.Vehicles.VehicleDefinitions")
local Dynamics = Harness.require("ReplicatedStorage.Shared.Vehicles.Physics.VehicleDynamics")
local Constants = Harness.require("ReplicatedStorage.Shared.Vehicles.VehicleConstants")
local BodyKits = Harness.require("ServerScriptService.AutomotiveWorldServer.Vehicles.BodyKits")

local M = Constants.MetersPerStud
local function studs(meters: number): number
    return meters / M
end
local function round(v: number): number
    return math.floor(v * 1000 + 0.5) / 1000
end
local function vec(v: any): { number }
    return { round(v.X), round(v.Y), round(v.Z) }
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
local style = definition.Appearance and definition.Appearance.BodyStyle
if style and BodyKits.has(style) then
    local collisions = {}
    local frontZ = -studs(layout[1].Longitudinal)
    local kit = BodyKits.build(
        style,
        {
            GroundY = groundY,
            HubY = hubY,
            FrontAxleZ = frontZ,
            RearAxleZ = -studs(layout[3].Longitudinal),
            TireRadius = studs(tire.RadiusM),
            TireWidth = studs(tire.WidthM),
            Width = studs(chassis.WidthM),
            Length = studs(chassis.LengthM),
            Height = studs(chassis.HeightM),
        },
        { Body = Color3.new(), Accent = Color3.new(), Trim = Color3.new() },
        studs,
        function(props: any): any
            if props.CanCollide then
                table.insert(
                    collisions,
                    { Name = props.Name, Center = vec(props.Offset.Position), Size = vec(props.Size) }
                )
            end
            return nil
        end
    )
    result.Style = style
    result.ProvisionalBody = {
        SeatDriver = vec(kit.SeatOffset.Position),
        SeatPassenger = if kit.PassengerOffset then vec((kit.PassengerOffset :: any).Position) else nil,
        FloorY = round(kit.FloorY),
        RoofY = if kit.RoofY then round(kit.RoofY) else nil,
        FrontEnd = round(kit.FrontEnd),
        Collisions = collisions,
        CameraHood = { 0, round(kit.HoodY + 0.8), round(frontZ + studs(0.45)) },
        CameraBumper = { 0, round(kit.FloorY + 0.2), round(kit.FrontEnd - 0.65) },
    }
end
local out = process.args[3] or ("build/" .. id .. "-geometry.json")
fs.writeFile(out, serde.encode("json", result, true))
print("AW_GEOMETRIE", id, #wheels, "roues", out)
