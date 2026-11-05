--!strict
-- Reproduction déterministe de QA-A08 (lot 0.9.2) : véhicule à convertisseur plaqué, roues
-- motrices encore lancées en marche arrière, marche avant demandée (pilote qui alterne).
-- Affiche la vitesse des roues motrices et du moteur pas à pas.
local process = require("@lune/process")
local Harness = require("../Harness")
Harness.loadPlace(process.args[1] or "build/AutomotiveWorld.rbxlx")
local SHARED = "ReplicatedStorage.Shared."
local Dynamics = Harness.require(SHARED .. "Vehicles.Physics.VehicleDynamics")
local Definitions = Harness.require(SHARED .. "Vehicles.VehicleDefinitions")
local id = process.args[2] or "proto_p01"
local definition = Definitions.get(id)
local state = Dynamics.createState(definition)
Dynamics.startEngine(state, definition)
local function contacts()
    local list = {}
    for i = 1, 4 do
        local axle = if i <= 2 then definition.Suspension.Front else definition.Suspension.Rear
        list[i] = {
            Grounded = true,
            Compression = Dynamics.staticCompression(definition, i <= 2),
            CompressionVelocity = 0,
            LongitudinalVelocity = 0, -- plaqué contre un obstacle
            LateralVelocity = 0,
            SurfaceFriction = 1,
            Wet = false,
            Wetness = 0,
        }
        local _ = axle
    end
    return list
end
local motion = { Forward = 0, Lateral = 0, YawRate = 0 }
-- 1. Marche arrière plaquée, pleins gaz arrière (frein maintenu à l'arrêt = marche arrière, A3).
for _ = 1, 150 do
    Dynamics.step(
        state,
        definition,
        { Throttle = 0, Brake = 1, Steer = 0, Handbrake = false, Clutch = 0 },
        contacts(),
        motion,
        1 / 60
    )
end
print(
    string.format(
        "après marche arrière : rapport %d, roues AR %.1f / %.1f rad/s, moteur %.1f rad/s",
        state.Gear,
        state.Wheels[3].AngularVelocity,
        state.Wheels[4].AngularVelocity,
        state.EngineOmega
    )
)
-- 2. Le moteur s'arrête (calage, panne d'énergie) alors que les roues motrices tournent encore.
local mode = process.args[3] or "calage"
if mode == "calage" then
    Dynamics.stopEngine(state)
elseif mode == "lance" then
    -- État relevé par nan-hunt (graine 8, scénario 83) : roues motrices lancées à −133 rad/s,
    -- moteur à 542 rad/s, véhicule plaqué, marche arrière.
    state.EngineOmega = 542
    state.Wheels[3].AngularVelocity = -133
    state.Wheels[4].AngularVelocity = -133
elseif mode == "arret" then
    -- État relevé par nan-hunt juste avant la divergence : moteur arrêté à 0 rad/s,
    -- roues motrices encore lancées.
    Dynamics.stopEngine(state)
    state.EngineOmega = 0
end
for step = 1, 12 do
    local input = if mode == "calage"
            or mode == "arret"
            or mode == "lance"
        then { Throttle = 0, Brake = 1, Steer = 0, Handbrake = false, Clutch = 0 }
        else { Throttle = 1, Brake = 0, Steer = 0, Handbrake = false, Clutch = 0 }
    local ok, err = pcall(Dynamics.step, state, definition, input, contacts(), motion, 1 / 60)
    print(
        string.format(
            "pas %2d : rapport %d, roues AR %.4g / %.4g rad/s, moteur %.4g rad/s, en marche %s%s",
            step,
            state.Gear,
            state.Wheels[3].AngularVelocity,
            state.Wheels[4].AngularVelocity,
            state.EngineOmega,
            tostring(state.EngineRunning),
            if ok then "" else " ERREUR " .. tostring(err)
        )
    )
end
print("neutralisations : " .. Dynamics.numericResets())
