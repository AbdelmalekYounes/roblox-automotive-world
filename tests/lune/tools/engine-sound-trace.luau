--!strict
-- Outil en lecture seule (lot AUDIO-01) : fait rouler un véhicule avec la VRAIE dynamique du jeu (banc planaire hors
-- Roblox, tests/lune/PlanarSim) et relève, pas à pas, ce que le son du jeu utilise : régime, rapport et charge réelle
-- du moteur (0 pendant un passage de rapport, sinon accélérateur effectif ; VehicleController.EngineLoad).
-- Le relevé sert à la démo d'écoute « conduite » de tools/audio/engine_loops.py : montées ET descentes de rapports
-- telles que la boîte du jeu les fait. Les valeurs ne sont pas des performances mesurées dans Roblox.
--
-- Scénario : ralenti 1,5 s ; pied au plancher jusqu'à 95 km/h ; lever de pied et frein léger jusqu'à 40 km/h
-- (rétrogradages en décélération) ; pied au plancher 3 s (rétrogradage forcé, kickdown) ; freinage jusqu'à l'arrêt ;
-- ralenti 2 s.
-- Usage : lune run tests/lune/tools/engine-sound-trace.luau build/AutomotiveWorld.rbxlx wk_brio <sortie.csv>
local fs = require("@lune/fs")
local process = require("@lune/process")
local Harness = require("../Harness")
local PlanarSim = require("../PlanarSim")

Harness.loadPlace(process.args[1])
local Definitions = Harness.require("ReplicatedStorage.Shared.Vehicles.VehicleDefinitions")
local Dynamics = Harness.require("ReplicatedStorage.Shared.Vehicles.Physics.VehicleDynamics")
local definition = Definitions.get(process.args[2])
assert(definition, "définition inconnue : " .. tostring(process.args[2]))

local DT = 1 / 240
local phase, phaseStart = "ralenti", 0
local rows = { "temps_s,regime,rapport,charge,vitesse_kmh,phase" }

local function input(throttle: number, brake: number): any
    return { Throttle = throttle, Brake = brake, Steer = 0, Handbrake = false, Clutch = 0 }
end

local function enter(name: string, t: number)
    phase, phaseStart = name, t
end

local snaps = PlanarSim.run(Dynamics, definition, {
    Dt = DT,
    -- Lot AUDIO-02 : antipatinage actif s'il équipe le modèle, comme au début d'une session en jeu (amendement A-02).
    Prepare = function(state: any)
        state.Aids.TractionControl = definition.Aids.TractionControl == true
    end,
    Duration = 60,
    Input = function(t: number, snapshot: any, state: any)
        local kmh = snapshot.Forward * 3.6
        if phase == "ralenti" and t >= 1.5 then
            enter("acceleration", t)
        elseif phase == "acceleration" and kmh >= 95 then
            enter("decelération", t)
        elseif phase == "decelération" and kmh <= 40 then
            enter("kickdown", t)
        elseif phase == "kickdown" and t - phaseStart >= 3 then
            enter("freinage", t)
        elseif phase == "freinage" and kmh <= 0.5 then
            enter("arret", t)
        end
        local load = if state.ShiftTimer > 0 then 0 else state.DriveThrottle
        table.insert(rows, string.format("%.5f,%.1f,%d,%.4f,%.2f,%s", t, state.EngineRpm, state.Gear, load, kmh, phase))
        if phase == "acceleration" or phase == "kickdown" then
            return input(1, 0)
        elseif phase == "decelération" then
            return input(0, 0.15)
        elseif phase == "freinage" then
            return input(0, 0.6)
        end
        return input(0, 0)
    end,
    Stop = function(snapshot: any)
        return phase == "arret" and snapshot.Time - phaseStart >= 2
    end,
})

fs.writeFile(process.args[3], table.concat(rows, "\n") .. "\n")
print(string.format("relevé : %d pas, %.1f s -> %s", #rows - 1, snaps[#snaps].Time, process.args[3]))
