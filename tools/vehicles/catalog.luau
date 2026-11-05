--!strict
--[[
    Contrôle de la gamme proposée de 18 modèles (lot 0.8), hors Roblox.
    Usage : lune run tools/vehicles/catalog.luau build/AutomotiveWorld.rbxlx

    Les définitions sont validées à l'enregistrement (VehicleDefinitions). Pour
    chaque modèle, le banc planaire PUR des tests (tests/lune/PlanarSim, sol sec,
    conducteur simulé : rapports passés au régime de puissance, embrayage
    progressif pour la manuelle) estime le 0–100 km/h et la vitesse atteinte en
    60 s. Valeurs de modèle, PAS des mesures en jeu.
]]

local process = require("@lune/process")
local Harness = require("../../tests/lune/Harness")
local PlanarSim = require("../../tests/lune/PlanarSim")

Harness.loadPlace(process.args[1] or "build/AutomotiveWorld.rbxlx")
local Definitions = Harness.require("ReplicatedStorage.Shared.Vehicles.VehicleDefinitions")
local Dynamics = Harness.require("ReplicatedStorage.Shared.Vehicles.Physics.VehicleDynamics")
local WorkingCatalog = Harness.require("ReplicatedStorage.Shared.Vehicles.Definitions.WorkingCatalog")

local DT = 1 / 60

local function performance(definition: any): (number?, number)
    local transmission = definition.Powertrain.Transmission
    local kind = transmission.Kind
    local top = #transmission.ForwardRatios
    local upRpm = if definition.Powertrain.Engine then definition.Powertrain.Engine.RedlineRpm - 300 else math.huge
    local clutch, pending = 0, false
    local reached: number? = nil
    local snaps = PlanarSim.run(Dynamics, definition, {
        Dt = DT,
        Duration = 60,
        Input = function(_, s, state)
            local wantUp = state.Gear == 0 or (state.EngineRpm > upRpm and state.Gear < top)
            if kind == "Sequential" and wantUp then
                Dynamics.requestShift(state, definition, 1, s.Forward)
            elseif kind == "Manual" then
                if wantUp and clutch <= 0 and not pending then
                    clutch = 0.01
                end
                if clutch > 0 and not pending and state.ClutchPedal >= 0.8 then
                    Dynamics.requestShift(state, definition, 1, s.Forward)
                    pending = true
                end
                if pending then
                    clutch = math.max(0, clutch - DT / 0.6)
                    if clutch <= 0 then
                        pending = false
                    end
                elseif clutch > 0 then
                    clutch = math.min(1, clutch + DT / 0.1)
                end
            end
            return { Throttle = 1, Brake = 0, Steer = 0, Handbrake = false, Clutch = clutch }
        end,
        Stop = function(s)
            if reached == nil and s.Forward * 3.6 >= 100 then
                reached = s.Time
            end
            return false
        end,
    })
    local vmax = 0
    for _, s in snaps do
        vmax = math.max(vmax, s.Forward * 3.6)
    end
    return reached, vmax
end

print(
    string.format(
        "%-9s %-9s %-11s %-4s %6s %5s %8s %8s",
        "Modèle",
        "Énergie",
        "Boîte",
        "Arch",
        "kg",
        "kW",
        "0-100 s",
        "v60 km/h"
    )
)
for _, spec in WorkingCatalog.Specs do
    local definition = Definitions.get(spec.Id)
    local zeroToHundred, vmax = performance(definition)
    print(
        string.format(
            "%-9s %-9s %-11s %-4s %6d %5d %8s %8.0f",
            spec.Name,
            spec.Base,
            spec.Gearbox,
            spec.Layout,
            spec.MassKg,
            spec.PowerKw,
            if zeroToHundred then string.format("%.1f", zeroToHundred) else "—",
            vmax
        )
    )
end
