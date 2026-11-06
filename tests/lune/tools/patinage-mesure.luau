--!strict
-- Outil en lecture seule (proposition patinage, docs/PROPOSITION_PATINAGE.md, 2026-11-06) : banc planaire hors
-- Roblox ; les options sont essayées sur des COPIES des définitions, rien n'est modifié dans le jeu. Les valeurs sont
-- des sorties du modèle, pas des mesures dans Roblox.
-- Usage : lune run tests/lune/tools/patinage-mesure.luau build/AutomotiveWorld.rbxlx
local process = require("@lune/process")
local Harness = require("../Harness")
local PlanarSim = require("../PlanarSim")
Harness.loadPlace(process.args[1])
local Definitions = Harness.require("ReplicatedStorage.Shared.Vehicles.VehicleDefinitions")
local Dynamics = Harness.require("ReplicatedStorage.Shared.Vehicles.Physics.VehicleDynamics")

local function clone(t: any): any
    if type(t) ~= "table" then
        return t
    end
    local out = {}
    for k, v in t do
        out[k] = clone(v)
    end
    return out
end

type Config = { Label: string, Tc: boolean, RiseS: number, Edit: ((any) -> ())? }

-- Départ arrêté pied au plancher (rampe d'accélérateur `RiseS`) : temps 0–100, temps passé en patinage franc
-- (essieu moteur, roue la moins glissante > 3 × le pic), vitesse de lacet max (stabilité en ligne droite).
local function launch(def: any, cfg: Config)
    local peak = def.Tires.PeakSlipRatio
    local t100, spinT, yawMax = nil :: number?, 0, 0
    PlanarSim.run(Dynamics, def, {
        Dt = 1 / 240,
        Duration = 20,
        Prepare = function(state: any)
            state.Aids.TractionControl = cfg.Tc
        end,
        Input = function(t: number, snap: any, state: any)
            local front = def.Powertrain.Drivetrain.FrontTorqueShare > 0.5
            local a, b = if front then 1 else 3, if front then 2 else 4
            local axle = math.min(state.Wheels[a].SlipRatio, state.Wheels[b].SlipRatio)
            if axle > 3 * peak then
                spinT += 1 / 240
            end
            yawMax = math.max(yawMax, math.abs(snap.YawRate))
            if t100 == nil and snap.Forward >= 100 / 3.6 then
                t100 = t
            end
            return { Throttle = math.clamp(t / cfg.RiseS, 0, 1), Brake = 0, Steer = 0, Handbrake = false, Clutch = 0 }
        end,
        Stop = function(snap: any)
            return snap.Forward >= 100 / 3.6 + 0.5
        end,
    })
    return t100, spinT, yawMax
end

-- Virage braqué à fond, accélérateur à fond (rampe), départ lancé à `kmh` : patinage de la roue intérieure motrice
-- (temps > 3 × pic), patinage de l'essieu, dérive max de la caisse (tête-à-queue si > 30°).
local function corner(def: any, cfg: Config, kmh: number)
    local peak = def.Tires.PeakSlipRatio
    local innerT, axleT, betaMax, heading = 0, 0, 0, 0
    local snaps = PlanarSim.run(Dynamics, def, {
        Dt = 1 / 240,
        Duration = 3,
        InitialForward = kmh / 3.6,
        Prepare = function(state: any)
            state.Aids.TractionControl = cfg.Tc
        end,
        Input = function(t: number, snap: any, state: any)
            local front = def.Powertrain.Drivetrain.FrontTorqueShare > 0.5
            local a, b = if front then 1 else 3, if front then 2 else 4
            local sa, sb = state.Wheels[a].SlipRatio, state.Wheels[b].SlipRatio
            if math.max(sa, sb) > 3 * peak then
                innerT += 1 / 240
            end
            if math.min(sa, sb) > 3 * peak then
                axleT += 1 / 240
            end
            if snap.Forward > 1 then
                betaMax = math.max(betaMax, math.abs(math.deg(math.atan2(snap.Lateral, snap.Forward))))
            end
            return { Throttle = math.clamp(t / cfg.RiseS, 0, 1), Brake = 0, Steer = 1, Handbrake = false, Clutch = 0 }
        end,
    })
    heading = math.deg(snaps[#snaps].Heading)
    return innerT, axleT, betaMax, heading
end

local CONFIGS: { [string]: { Config } } = {
    wk_comete = {
        { Label = "actuel (aides coupées, rampe 0,2 s)", Tc = false, RiseS = 0.2 },
        { Label = "antipatinage actif", Tc = true, RiseS = 0.2 },
        { Label = "rampe clavier 1,0 s", Tc = false, RiseS = 1.0 },
        {
            Label = "autobloquant arrière renforcé (0,6/40)",
            Tc = false,
            RiseS = 0.2,
            Edit = function(d)
                d.Powertrain.Drivetrain.RearDifferential.PowerLockRatio = 0.6
            end,
        },
    },
    wk_brio = {
        { Label = "actuel (aides coupées, rampe 0,2 s)", Tc = false, RiseS = 0.2 },
        { Label = "antipatinage actif", Tc = true, RiseS = 0.2 },
        { Label = "rampe clavier 1,0 s", Tc = false, RiseS = 1.0 },
        {
            Label = "autobloquant avant (0,3/20)",
            Tc = false,
            RiseS = 0.2,
            Edit = function(d)
                local f = d.Powertrain.Drivetrain.FrontDifferential
                f.Kind, f.PowerLockRatio, f.CoastLockRatio, f.PreloadNm = "LimitedSlip", 0.3, 0.1, 20
            end,
        },
    },
}

for _, id in { "wk_comete", "wk_brio" } do
    for _, cfg in CONFIGS[id] do
        local def = clone(Definitions.get(id))
        if cfg.Edit then
            (cfg.Edit :: any)(def)
        end
        local t100, spinT, yaw = launch(def, cfg)
        local line = string.format(
            "%-9s %-40s 0-100 %s s, patinage franc %.2f s, lacet max %.2f rad/s",
            id,
            cfg.Label,
            if t100 then string.format("%.2f", t100) else "—",
            spinT,
            yaw
        )
        for _, kmh in { 20, 40 } do
            local innerT, axleT, beta, heading = corner(def, cfg, kmh)
            line ..= string.format(
                " | virage %d : roue int. %.2f s, essieu %.2f s, dérive caisse %.0f°, cap %.0f°",
                kmh,
                innerT,
                axleT,
                beta,
                heading
            )
        end
        print(line)
    end
end
