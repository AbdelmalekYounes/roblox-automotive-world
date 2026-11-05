--!strict
-- Lot 0.9.2 (QA-A08) : la borne de stabilité du convertisseur agit-elle en conduite normale ?
-- Pour chaque modèle à convertisseur : départ plein gaz, freinage jusqu'à l'arrêt, marche
-- arrière, retour en marche avant (banc planaire). Affiche le nombre de sous-pas limités.
-- Usage : lune run tests/lune/tools/converter-nominal.luau build/AutomotiveWorld.rbxlx
local process = require("@lune/process")
local Harness = require("../Harness")
-- Lot BASE-01 : prototypes et variantes retirés du jeu, conservés comme jeux d'essai.
local Fixtures = require("../fixtures/Fixtures")
local function withFixtures(list: { any }): { any }
    for _, fixture in Fixtures.all() do
        table.insert(list, fixture)
    end
    return list
end
local PlanarSim = require("../PlanarSim")
Harness.loadPlace(process.args[1] or "build/AutomotiveWorld.rbxlx")
local Dynamics = Harness.require("ReplicatedStorage.Shared.Vehicles.Physics.VehicleDynamics")
local Definitions = Harness.require("ReplicatedStorage.Shared.Vehicles.VehicleDefinitions")
local total = 0
for _, definition in withFixtures(Definitions.all()) do
    if definition.Powertrain.Transmission.Converter then
        local before = Dynamics.converterLimits()
        local snaps = PlanarSim.run(Dynamics, definition, {
            Dt = 1 / 60,
            Duration = 40,
            Input = function(t: number)
                local throttle, brake = 0, 0
                if t < 15 then
                    throttle = 1
                elseif t < 25 then
                    brake = 1 -- freinage puis marche arrière (frein maintenu à l'arrêt, A3)
                elseif t < 30 then
                    throttle = 1 -- « accélérer » freine la marche arrière puis repart en avant
                end
                return { Throttle = throttle, Brake = brake, Steer = 0, Handbrake = false, Clutch = 0 }
            end,
        })
        local limited = Dynamics.converterLimits() - before
        total += limited
        local maxKmh = 0
        for _, snap in snaps do
            maxKmh = math.max(maxKmh, snap.Forward * 3.6)
        end
        print(string.format("%-14s %5d sous-pas limités, vitesse max %.0f km/h", definition.Id, limited, maxKmh))
    end
end
print("total : " .. total)
