--!strict
--[[
    Moteur PUR des missions (lot 0.5) : une mission est une suite d'étapes
    OBSERVABLES, évaluées uniquement à partir d'échantillons mesurés par le
    serveur (position et vitesse répliquées du personnage ou du véhicule,
    dégâts confirmés, corrections de mouvement). Le client ne déclare rien :
    ni distance, ni réussite, ni score.

    Étapes :
    - Stop    : s'arrêter (< 1,5 m/s) dans le rayon, en véhicule, Hold secondes ;
    - Pass    : passer dans le rayon (portes, points d'exploration) ;
    - OnFoot  : rester à pied dans le rayon Hold secondes (intervention) ;
    - Park    : s'arrêter dans le rayon, cap aligné à ±Tolerance degrés ;
    - Accel   : départ arrêté → 100 km/h, temps mesuré ;
    - Brake   : depuis ≥ 90 km/h jusqu'à l'arrêt, distance mesurée.
    Plots (Hazards) : chaque passage trop près est une faute.
    Échec : délai dépassé, correction de mouvement par le serveur (téléportation
    ou mouvement impossible : la mission est annulée sans paiement).
]]

local MissionEngine = {}

MissionEngine.StopSpeedMs = 1.5
MissionEngine.HardDecelMs2 = 6 -- freinage brusque (cargaison fragile)

export type Point = { X: number, Z: number }

export type Step = {
    Kind: "Stop" | "Pass" | "OnFoot" | "Park" | "Accel" | "Brake",
    Point: Point?,
    Radius: number?,
    Hold: number?,
    Heading: number?, -- rad (Park)
    Tolerance: number?, -- degrés (Park)
    Label: string,
}

export type Mission = {
    Id: string,
    Job: string,
    UserId: number,
    Difficulty: number, -- 1 à 3
    Premium: boolean,
    Steps: { Step },
    Hazards: { { Point: Point, Radius: number } },
    TimeLimitS: number,
    EstimatedS: number,
    DistanceM: number,
    RouteKey: string, -- clé anti-répétition (itinéraire, parcours)
    Fragile: boolean,
    VehicleRule: string,
    ProvidedVehicleId: string?, -- véhicule fourni / professionnel exigé
    Targets: { [string]: number }?, -- références des essais (s, m)
    CreatedAt: number,
}

export type Sample = {
    T: number,
    X: number,
    Z: number,
    Heading: number, -- rad
    SpeedMs: number,
    InVehicle: boolean,
    VehicleId: string?,
    Damage: number, -- usure cumulée du véhicule utilisé (0..)
    Corrected: boolean, -- correction de mouvement depuis le dernier échantillon
}

export type State = {
    Status: "Active" | "Completed" | "Failed",
    FailReason: string?,
    StepIndex: number,
    StartedAt: number,
    Timer: number,
    LastSample: Sample?,
    TravelledM: number,
    DamageStart: number?,
    DamageEnd: number,
    HardDecels: number,
    HazardHits: number,
    HazardInside: { [number]: boolean },
    Measures: { [string]: number },
    AccelStart: number?,
    BrakeStart: Point?,
    ParkError: number?,
    FinishedAt: number?,
}

function MissionEngine.start(_mission: Mission, now: number): State
    return {
        Status = "Active",
        StepIndex = 1,
        StartedAt = now,
        Timer = 0,
        TravelledM = 0,
        DamageEnd = 0,
        HardDecels = 0,
        HazardHits = 0,
        HazardInside = {},
        Measures = {},
    }
end

local function distance(a: Point, x: number, z: number): number
    return math.sqrt((a.X - x) ^ 2 + (a.Z - z) ^ 2)
end

local function angleGap(a: number, b: number): number
    local d = (a - b) % (2 * math.pi)
    if d > math.pi then
        d = 2 * math.pi - d
    end
    return math.deg(d)
end

-- Le bon véhicule est-il utilisé (véhicule fourni exigé) ?
local function rightVehicle(mission: Mission, sample: Sample): boolean
    if mission.ProvidedVehicleId == nil then
        return sample.InVehicle
    end
    return sample.InVehicle and sample.VehicleId == mission.ProvidedVehicleId
end

local function advance(state: State, mission: Mission, now: number)
    state.StepIndex += 1
    state.Timer = 0
    if state.StepIndex > #mission.Steps then
        state.Status = "Completed"
        state.FinishedAt = now
    end
end

-- Intègre un échantillon serveur ; renvoie l'état (modifié en place).
function MissionEngine.observe(state: State, mission: Mission, sample: Sample): State
    if state.Status ~= "Active" then
        return state
    end
    if sample.Corrected then
        state.Status = "Failed"
        state.FailReason = "MovementCorrected"
        return state
    end
    if sample.T - state.StartedAt > mission.TimeLimitS then
        state.Status = "Failed"
        state.FailReason = "Timeout"
        return state
    end
    local previous = state.LastSample
    state.LastSample = sample
    local dt = if previous then math.max(sample.T - previous.T, 0) else 0
    if previous and rightVehicle(mission, sample) and rightVehicle(mission, previous) then
        state.TravelledM += math.sqrt((sample.X - previous.X) ^ 2 + (sample.Z - previous.Z) ^ 2)
        if dt > 0 and (previous.SpeedMs - sample.SpeedMs) / dt > MissionEngine.HardDecelMs2 then
            state.HardDecels += 1
        end
    end
    if rightVehicle(mission, sample) then
        state.DamageStart = state.DamageStart or sample.Damage
        state.DamageEnd = sample.Damage
    end
    for index, hazard in mission.Hazards do
        local inside = distance(hazard.Point, sample.X, sample.Z) < hazard.Radius
        if inside and not state.HazardInside[index] then
            state.HazardHits += 1
        end
        state.HazardInside[index] = inside
    end

    local step = mission.Steps[state.StepIndex]
    local point = step.Point
    local within = point == nil or distance(point, sample.X, sample.Z) <= (step.Radius or 10)
    if step.Kind == "Pass" then
        if within and rightVehicle(mission, sample) then
            advance(state, mission, sample.T)
        end
    elseif step.Kind == "Stop" or step.Kind == "Park" then
        local aligned = true
        if step.Kind == "Park" and step.Heading then
            aligned = angleGap(sample.Heading, step.Heading) <= (step.Tolerance or 12)
        end
        if within and aligned and rightVehicle(mission, sample) and sample.SpeedMs < MissionEngine.StopSpeedMs then
            state.Timer += dt
            if state.Timer >= (step.Hold or 2) then
                if step.Kind == "Park" and point then
                    state.ParkError = distance(point, sample.X, sample.Z)
                end
                advance(state, mission, sample.T)
            end
        else
            state.Timer = 0
        end
    elseif step.Kind == "OnFoot" then
        if within and not sample.InVehicle then
            state.Timer += dt
            if state.Timer >= (step.Hold or 5) then
                advance(state, mission, sample.T)
            end
        else
            state.Timer = 0
        end
    elseif step.Kind == "Accel" then
        if rightVehicle(mission, sample) then
            if sample.SpeedMs < 0.3 then
                state.AccelStart = sample.T
            elseif state.AccelStart and sample.SpeedMs >= 100 / 3.6 then
                state.Measures.Accel0100 = sample.T - state.AccelStart
                advance(state, mission, sample.T)
            end
        end
    elseif step.Kind == "Brake" then
        if rightVehicle(mission, sample) then
            if sample.SpeedMs >= 90 / 3.6 then
                state.BrakeStart = { X = sample.X, Z = sample.Z }
            elseif state.BrakeStart and sample.SpeedMs < 0.5 then
                state.Measures.Brake = distance(state.BrakeStart :: Point, sample.X, sample.Z)
                advance(state, mission, sample.T)
            end
        end
    end
    return state
end

--[[
    Qualité de réalisation 0..1, à partir des seules mesures du serveur :
    temps, dégâts subis, freinages brusques (fragile), plots touchés,
    précision du stationnement, résultats des essais.
]]
function MissionEngine.quality(state: State, mission: Mission): number
    local elapsed = math.max((state.FinishedAt or state.StartedAt) - state.StartedAt, 1)
    local quality = math.clamp(mission.EstimatedS * 1.2 / elapsed, 0.5, 1)
    local damage = math.max(state.DamageEnd - (state.DamageStart or state.DamageEnd), 0)
    quality *= math.clamp(1 - damage * 2, 0, 1)
    if mission.Fragile then
        quality *= math.max(0, 1 - 0.12 * state.HardDecels)
    end
    quality *= math.max(0, 1 - 0.2 * state.HazardHits)
    if state.ParkError then
        quality *= math.clamp(1 - (state.ParkError :: number) / 3, 0.3, 1)
    end
    local targets = mission.Targets
    if targets then
        local accel = state.Measures.Accel0100
        if accel and targets.Accel0100 then
            quality *= math.clamp(targets.Accel0100 / accel, 0.5, 1)
        end
        local brake = state.Measures.Brake
        if brake and targets.Brake then
            quality *= math.clamp(targets.Brake / brake, 0.5, 1)
        end
    end
    return math.clamp(quality, 0, 1)
end

--[[
    Vraisemblance : un parcours accompli plus vite que physiquement possible
    (vitesse moyenne > 70 m/s ≈ 250 km/h en ligne droite) est rejeté.
]]
function MissionEngine.plausible(state: State, mission: Mission): boolean
    local elapsed = (state.FinishedAt or state.StartedAt) - state.StartedAt
    return elapsed >= mission.DistanceM / 70
end

return table.freeze(MissionEngine)
