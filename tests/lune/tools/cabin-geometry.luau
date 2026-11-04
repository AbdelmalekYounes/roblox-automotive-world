--!strict
-- Relevé (lecture seule) de la géométrie des habitacles PROVISOIRES des 18 modèles : hauteur
-- du siège, du plancher et du pavillon, largeur d'habitacle, en studs et en mètres. Sert de
-- point de départ chiffré à la spécification des futurs modèles 3D (docs/vehicle-3d) ;
-- aucune modification du jeu. Mêmes entrées que VehicleFactory.create.
-- Usage : lune run tests/lune/tools/cabin-geometry.luau build/AutomotiveWorld.rbxlx
local process = require("@lune/process")
local roblox = require("@lune/roblox")
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

print(
    "modèle;silhouette;sol_st;plancher_st;assise_st;pavillon_st;assise_au_pavillon_st;assise_au_pavillon_m;assise_au_sol_m;largeur_habitacle_st"
)
for _, definition in Definitions.all() do
    local style = definition.Appearance and definition.Appearance.BodyStyle
    if style and BodyKits.has(style) then
        local chassis, tire = definition.Chassis, definition.Tires
        local layout = Dynamics.wheelLayout(definition)
        local groundY = -studs(chassis.CgHeightM)
        local hubY = groundY + studs(tire.RadiusM)
        local cabinWidth = 0
        local kit = BodyKits.build(
            style,
            {
                GroundY = groundY,
                HubY = hubY,
                FrontAxleZ = -studs(layout[1].Longitudinal),
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
                if props.Name == "PlancheDeBord" then
                    cabinWidth = props.Size.X + 0.3
                end
                return nil
            end
        )
        local seatTop = kit.SeatOffset.Position.Y + 0.2 -- assise de 0,4 st d'épaisseur
        local roof = kit.RoofY
        print(
            string.format(
                "%s;%s;%.2f;%.2f;%.2f;%s;%s;%s;%.2f;%.2f",
                definition.Id,
                style,
                groundY,
                kit.FloorY,
                seatTop,
                if roof then string.format("%.2f", roof) else "ouvert",
                if roof then string.format("%.2f", roof - seatTop) else "—",
                if roof then string.format("%.2f", (roof - seatTop) * M) else "—",
                (seatTop - groundY) * M,
                cabinWidth
            )
        )
    end
end
