--!strict
-- Mesures élémentaires PURES, calculées localement pendant la conduite :
-- - temps 0 → 100 km/h (départ arrêté, sans freiner ni reculer) ;
-- - distance de freinage 100 → 0 km/h (freinage ≥ 90 % sans accélérer).
-- Ce sont des mesures indicatives prises par le client à la cadence d'image,
-- destinées aux essais en Studio. Elles n'ont aucune valeur officielle et ne
-- sont jamais envoyées au serveur.

local Telemetry = {}

export type MeasureState = {
    LaunchPhase: "Idle" | "Armed" | "Running",
    LaunchElapsed: number,
    LastLaunchSeconds: number?,
    BestLaunchSeconds: number?,
    BrakeReady: boolean,
    BrakeMeasuring: boolean,
    BrakeStartX: number,
    BrakeStartZ: number,
    LastBrakeDistanceM: number?,
}

function Telemetry.new(): MeasureState
    return {
        LaunchPhase = "Idle",
        LaunchElapsed = 0,
        LastLaunchSeconds = nil,
        BestLaunchSeconds = nil,
        BrakeReady = false,
        BrakeMeasuring = false,
        BrakeStartX = 0,
        BrakeStartZ = 0,
        LastBrakeDistanceM = nil,
    }
end

--[[
    `speedKmh` : vitesse absolue ; `gear` : rapport (-1 = marche arrière) ;
    `throttle` / `brakePedal` : pédales effectives ; `x`, `z` : position
    horizontale en mètres.
]]
function Telemetry.update(
    state: MeasureState,
    speedKmh: number,
    throttle: number,
    brakePedal: number,
    gear: number,
    x: number,
    z: number,
    dt: number
)
    -- 0 → 100 km/h
    if state.LaunchPhase == "Idle" then
        if speedKmh < 1 then
            state.LaunchPhase = "Armed"
        end
    elseif state.LaunchPhase == "Armed" then
        if speedKmh >= 1 and gear >= 1 then
            state.LaunchPhase = "Running"
            state.LaunchElapsed = 0
        end
    else
        state.LaunchElapsed += dt
        if brakePedal > 0.1 or gear < 0 then
            state.LaunchPhase = "Idle"
        elseif speedKmh >= 100 then
            local elapsed = state.LaunchElapsed
            state.LastLaunchSeconds = elapsed
            local best = state.BestLaunchSeconds
            if best == nil or elapsed < best then
                state.BestLaunchSeconds = elapsed
            end
            state.LaunchPhase = "Idle"
        elseif speedKmh < 0.5 then
            state.LaunchPhase = "Armed"
        end
    end

    -- 100 → 0 km/h
    if speedKmh >= 100 then
        state.BrakeReady = true
        state.BrakeMeasuring = false
    elseif state.BrakeReady and not state.BrakeMeasuring then
        if brakePedal >= 0.9 and throttle < 0.05 then
            state.BrakeMeasuring = true
            state.BrakeStartX = x
            state.BrakeStartZ = z
        else
            state.BrakeReady = false
        end
    elseif state.BrakeMeasuring then
        if throttle >= 0.05 or brakePedal < 0.5 then
            state.BrakeMeasuring = false
            state.BrakeReady = false
        elseif speedKmh < 1 then
            local dx = x - state.BrakeStartX
            local dz = z - state.BrakeStartZ
            state.LastBrakeDistanceM = math.sqrt(dx * dx + dz * dz)
            state.BrakeMeasuring = false
            state.BrakeReady = false
        end
    end
end

return table.freeze(Telemetry)
