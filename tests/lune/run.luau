--!strict
-- Point d'entrée des tests Lune (hors Roblox Studio).
-- Usage : lune run tests/lune/run.luau <chemin vers la place .rbxlx construite par Rojo>

local process = require("@lune/process")

local Harness = require("./Harness")
local TestKit = require("./TestKit")

local placePath = process.args[1]
if placePath == nil then
    print("Usage : lune run tests/lune/run.luau <place.rbxlx>")
    process.exit(2)
end

Harness.loadPlace(placePath :: string)

for _, spec in
    {
        require("./specs/PlaceStructure"),
        require("./specs/Definitions"),
        require("./specs/PhysicsUnit"),
        require("./specs/NetworkSecurity"),
        require("./specs/NetworkOwnershipSpec"),
        require("./specs/InputArbiterSpec"),
        require("./specs/CollisionExchangeSpec"),
        require("./specs/TelemetrySpec"),
        require("./specs/DrivingScenarios"),
        require("./specs/Lot02Powertrain"),
        require("./specs/Lot02Chassis"),
        require("./specs/Lot02Systems"),
        require("./specs/Lot03World"),
        require("./specs/Lot03Systems"),
        require("./specs/Lot04Persistence"),
        require("./specs/Lot04Progression"),
        require("./specs/Lot05Economy"),
    }
do
    spec(TestKit, Harness)
end

process.exit(if TestKit.run() then 0 else 1)
