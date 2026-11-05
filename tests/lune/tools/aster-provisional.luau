--!strict
-- Relevé (lecture seule) de la carrosserie PROVISOIRE de l'Aster : pièces de collision (mêmes noms que les zones de
-- dégâts), repères du kit et points de caméra CameraHood / CameraBumper selon la règle de VehicleFactory. Sert au
-- modèle 3D (ASTER-02, passe HF4) pour reprendre les mêmes noms et la même logique ; aucune modification du jeu.
-- Usage : lune run tests/lune/tools/aster-provisional.luau build/AutomotiveWorld.rbxlx <sortie.json>
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

local definition = Definitions.get("wk_aster")
local chassis, tire = definition.Chassis, definition.Tires
local layout = Dynamics.wheelLayout(definition)
local groundY = -studs(chassis.CgHeightM)
local frontZ = -studs(layout[1].Longitudinal)
local collisions = {}
local kit = BodyKits.build(
    definition.Appearance.BodyStyle,
    {
        GroundY = groundY,
        HubY = groundY + studs(tire.RadiusM),
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
            local p = props.Offset.Position
            table.insert(collisions, {
                Name = props.Name,
                Center = { round(p.X), round(p.Y), round(p.Z) },
                Size = { round(props.Size.X), round(props.Size.Y), round(props.Size.Z) },
            })
        end
        return nil
    end
)
-- Règle de VehicleFactory (branche des kits) : CameraHood à HoodY + 0,8, 0,45 m en avant de l'essieu avant ;
-- CameraBumper à FloorY + 0,2, 0,65 st devant l'avant de la caisse.
local result = {
    Vehicle = "wk_aster",
    Style = definition.Appearance.BodyStyle,
    Ground = round(groundY),
    Kit = {
        HoodY = round(kit.HoodY),
        FloorY = round(kit.FloorY),
        FrontEnd = round(kit.FrontEnd),
        RoofY = if kit.RoofY then round(kit.RoofY) else nil,
    },
    Collisions = collisions,
    Cameras = {
        CameraHood = { 0, round(kit.HoodY + 0.8), round(frontZ + studs(0.45)) },
        CameraBumper = { 0, round(kit.FloorY + 0.2), round(kit.FrontEnd - 0.65) },
    },
}
local out = process.args[2] or "build/aster-provisional.json"
fs.writeFile(out, serde.encode("json", result, true))
print("AW_PROVISOIRE", #collisions, "collisions", out)
