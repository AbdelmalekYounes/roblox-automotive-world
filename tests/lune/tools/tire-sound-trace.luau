--!strict
-- Outil en lecture seule (lot AUDIO-03) : fait rouler un véhicule avec la VRAIE dynamique du jeu (banc planaire hors
-- Roblox, tests/lune/PlanarSim) et relève, pas à pas, le résumé sonore des pneus calculé par
-- Shared/Audio/TireAudioModel.summarize, comme le fait VehicleController en jeu. Le relevé sert aux démos d'écoute de
-- tools/audio/tire_loops.py. Les valeurs ne sont pas des performances mesurées dans Roblox.
--
-- Scénario enchaîné (chaque phase repart de la vitesse de la précédente) :
--   1. départ arrêté pied au plancher, antipatinage coupé (patinage) jusqu'à 90 km/h ;
--   2. croisière à 90 km/h ; 3. freinage fort avec ABS jusqu'à 30 km/h ; 4. virage serré à la limite ;
--   5. freinage fort sans ABS jusqu'à l'arrêt (roues bloquées) ; 6. gravier : départ, 50 km/h, freinage ;
--   7. chaussée mouillée : 70 km/h puis freinage avec ABS.
-- Usage : lune run tests/lune/tools/tire-sound-trace.luau build/AutomotiveWorld.rbxlx wk_brio <sortie.csv>
local fs = require("@lune/fs")
local process = require("@lune/process")
local Harness = require("../Harness")
local PlanarSim = require("../PlanarSim")

Harness.loadPlace(process.args[1])
local Definitions = Harness.require("ReplicatedStorage.Shared.Vehicles.VehicleDefinitions")
local Dynamics = Harness.require("ReplicatedStorage.Shared.Vehicles.Physics.VehicleDynamics")
local Model = Harness.require("ReplicatedStorage.Shared.Audio.TireAudioModel")
local definition = Definitions.get(process.args[2])
assert(definition, "définition inconnue : " .. tostring(process.args[2]))
local tires = definition.Tires

local DT = 1 / 240
local ROW_EVERY = 4 -- une ligne tous les 4 pas (1/60 s), comme une image
local rows = { "temps_s,vitesse_ms,au_sol,crissement,glissade,vitesse_glissement,revetement,humidite,abs,phase" }
local clock = 0
local speed = 0

type Phase = {
    Name: string,
    Duration: number,
    Surface: string, -- famille sonore (TireAudioModel.Surfaces)
    Friction: number, -- multiplicateur d'adhérence du banc
    Wetness: number,
    Abs: boolean,
    Traction: boolean,
    Input: (t: number, kmh: number) -> any,
    Stop: ((kmh: number) -> boolean)?,
}

local function input(throttle: number, brake: number, steer: number): any
    return { Throttle = throttle, Brake = brake, Steer = steer, Handbrake = false, Clutch = 0 }
end

local function run(phase: Phase)
    local step = 0
    local snaps = PlanarSim.run(Dynamics, definition, {
        Dt = DT,
        Duration = phase.Duration,
        InitialForward = speed,
        Surface = phase.Friction,
        Wetness = phase.Wetness,
        Prepare = function(state: any)
            state.Aids.Abs = phase.Abs
            state.Aids.TractionControl = phase.Traction
            state.Aids.StabilityControl = false
        end,
        Input = function(t: number, snapshot: any, state: any)
            step += 1
            -- Les 0,1 premières secondes de chaque phase sont écartées : transitoire du départ lancé du banc (roues
            -- remises à la vitesse du châssis), sans équivalent en jeu ; la démo interpole par-dessus.
            if step % ROW_EVERY == 0 and t >= 0.1 then
                local samples = {}
                for _, w in state.Wheels do
                    table.insert(samples, {
                        Grounded = true,
                        SlipRatio = w.SlipRatio,
                        SlipAngle = w.SlipAngle,
                        ContactVx = snapshot.Forward,
                        ContactVy = snapshot.Lateral,
                        RollingSpeed = w.AngularVelocity * tires.RadiusM,
                        Surface = phase.Surface,
                        Wetness = phase.Wetness,
                    })
                end
                local s = Model.summarize(
                    samples,
                    tires.PeakSlipRatio,
                    math.rad(tires.PeakSlipAngleDeg),
                    state.AidActivity.Abs
                )
                table.insert(
                    rows,
                    string.format(
                        "%.4f,%.3f,%.2f,%.3f,%.3f,%.3f,%s,%.2f,%d,%s",
                        clock + t,
                        s.Speed,
                        s.Grounded,
                        s.Squeal,
                        s.Scrub,
                        s.SlipSpeed,
                        s.Surface,
                        s.Wetness,
                        if s.Abs then 1 else 0,
                        phase.Name
                    )
                )
            end
            return phase.Input(t, snapshot.Forward * 3.6)
        end,
        Stop = if phase.Stop
            then function(snapshot: any)
                return (phase.Stop :: (number) -> boolean)(snapshot.Forward * 3.6)
            end
            else nil,
    })
    local last = snaps[#snaps]
    clock += last.Time
    speed = math.max(last.Forward, 0)
end

local DRY = { Surface = "Hard", Friction = 1, Wetness = 0 }

local function phase(name: string, base: any, extra: { [string]: any }): Phase
    local p: any = { Name = name, Abs = true, Traction = true }
    for k, v in base do
        p[k] = v
    end
    for k, v in extra do
        p[k] = v
    end
    return p
end

local function cruise(target: number): (number, number) -> any
    return function(_t: number, kmh: number)
        return input(math.clamp((target - kmh) * 0.15 + 0.25, 0, 1), 0, 0)
    end
end

run(phase("depart_patinage", DRY, {
    Duration = 14,
    Traction = false,
    Input = function()
        return input(1, 0, 0)
    end,
    Stop = function(kmh)
        return kmh >= 90
    end,
}))
run(phase("croisiere", DRY, { Duration = 3, Input = cruise(90) }))
run(phase("freinage_abs", DRY, {
    Duration = 6,
    Input = function()
        return input(0, 1, 0)
    end,
    Stop = function(kmh)
        return kmh <= 30
    end,
}))
run(phase("relance", DRY, {
    Duration = 6,
    Input = cruise(60),
    Stop = function(kmh)
        return kmh >= 58
    end,
}))
run(phase("virage_limite", DRY, {
    Duration = 3,
    Input = function(t)
        return input(0.5, 0, math.clamp(t / 0.4, 0, 1))
    end,
}))
run(phase("ligne_droite", DRY, { Duration = 2, Input = cruise(70) }))
run(phase("freinage_bloque", DRY, {
    Duration = 8,
    Abs = false,
    Input = function()
        return input(0, 1, 0)
    end,
    Stop = function(kmh)
        return kmh <= 0.5
    end,
}))
local GRAVEL = { Surface = "Loose", Friction = 0.6, Wetness = 0 }
run(phase("gravier_depart", GRAVEL, {
    Duration = 8,
    Input = cruise(55),
    Stop = function(kmh)
        return kmh >= 50
    end,
}))
run(phase("gravier_freinage", GRAVEL, {
    Duration = 6,
    Abs = false,
    Input = function()
        return input(0, 1, 0)
    end,
    Stop = function(kmh)
        return kmh <= 0.5
    end,
}))
local WET = { Surface = "Hard", Friction = 1, Wetness = 1 }
run(phase("mouille_relance", WET, {
    Duration = 10,
    Input = cruise(75),
    Stop = function(kmh)
        return kmh >= 70
    end,
}))
run(phase("mouille_croisiere", WET, { Duration = 2, Input = cruise(70) }))
run(phase("mouille_freinage_abs", WET, {
    Duration = 6,
    Input = function()
        return input(0, 1, 0)
    end,
    Stop = function(kmh)
        return kmh <= 0.5
    end,
}))

fs.writeFile(process.args[3], table.concat(rows, "\n") .. "\n")
print(string.format("%d lignes, %.1f s relevées dans %s", #rows - 1, clock, process.args[3]))
