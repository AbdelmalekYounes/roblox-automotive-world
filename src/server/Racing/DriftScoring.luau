--!strict
--[[
    Score de drift (lot 0.6), PUR, calculé sur des échantillons SERVEUR
    (position, vitesse, cap de la caisse, usure confirmée, corrections).

    Mesures physiques utilisées :
    - angle de dérive : écart entre le cap de la caisse et la direction de la
      vitesse (et non la rotation de la voiture) ;
    - vitesse : aucun point sous 30 km/h (une voiture qui tourne sur elle-même
      à l'arrêt ne marque rien) ;
    - distance parcourue en dérive ;
    - continuité : une figure (combo) se poursuit tant que la dérive reprend
      en moins de 1,2 s ; elle n'est ACQUISE qu'à sa fin propre ;
    - enchaînement : chaque changement de sens de dérive dans la même figure
      augmente le multiplicateur (jusqu'à × 4) ;
    - maîtrise : un angle qui oscille brutalement (correction désordonnée) ou
      une sur-rotation réduit les points ;
    - zone : hors de la zone, la figure en cours est PERDUE.
    Rupture (figure perdue) : collision notable (usure confirmée en hausse),
    sortie de zone, tête-à-queue (angle > 110° plus de 0,6 s), comportement
    invalide (correction de mouvement par le serveur, vitesse invraisemblable).
    Les seuils sont des hypothèses réglables.
]]

local DriftScoring = {}

DriftScoring.Params = table.freeze({
    MinSpeedMs = 30 / 3.6,
    MinAngleDeg = 12,
    PeakAngleDeg = 35, -- plein rendement de 35° à 55°
    PeakEndDeg = 55,
    MaxAngleDeg = 80, -- au-delà : sur-rotation, aucun point
    SpinAngleDeg = 110,
    SpinHoldS = 0.6,
    GapS = 1.2,
    PointsPerS = 100,
    SpeedRefMs = 20, -- 72 km/h : facteur de vitesse 1
    MaxSpeedFactor = 1.5,
    TransitionStep = 0.25,
    MaxMultiplier = 4,
    JitterDegPerS = 140, -- variation d'angle au-delà : manque de maîtrise
    CollisionWear = 0.03, -- hausse d'usure en un échantillon = choc notable
    MaxPlausibleMs = 90,
})

export type Sample = {
    T: number,
    X: number,
    Z: number,
    VX: number, -- vitesse (m/s) dans le plan
    VZ: number,
    Heading: number, -- cap de la caisse (rad, 0 = nord)
    Wear: number, -- usure cumulée confirmée par le serveur
    Corrected: boolean,
}

export type State = {
    Total: number,
    DriftDistanceM: number,
    BestCombo: number,
    Combos: number,
    Breaks: { [string]: number },
    -- Figure en cours.
    ComboPoints: number,
    Multiplier: number,
    ComboActive: boolean,
    LastDriftT: number,
    LastSide: number,
    SpinSince: number?,
    Last: Sample?,
    LastAngle: number?,
}

function DriftScoring.new(): State
    return {
        Total = 0,
        DriftDistanceM = 0,
        BestCombo = 0,
        Combos = 0,
        Breaks = {},
        ComboPoints = 0,
        Multiplier = 1,
        ComboActive = false,
        LastDriftT = -math.huge,
        LastSide = 0,
        SpinSince = nil,
        Last = nil,
        LastAngle = nil,
    }
end

-- Angle de dérive signé (degrés) : direction de la vitesse par rapport à la caisse.
function DriftScoring.slipAngle(heading: number, vx: number, vz: number): number
    local velocityHeading = math.atan2(vx, -vz)
    local delta = velocityHeading - heading
    delta = (delta + math.pi) % (2 * math.pi) - math.pi
    return math.deg(delta)
end

-- Rendement selon l'angle (0..1).
local function angleFactor(angle: number): number
    local p = DriftScoring.Params
    if angle < p.MinAngleDeg or angle > p.MaxAngleDeg then
        return 0
    elseif angle < p.PeakAngleDeg then
        return (angle - p.MinAngleDeg) / (p.PeakAngleDeg - p.MinAngleDeg)
    elseif angle <= p.PeakEndDeg then
        return 1
    end
    return 1 - 0.5 * (angle - p.PeakEndDeg) / (p.MaxAngleDeg - p.PeakEndDeg)
end

local function bank(state: State)
    if state.ComboActive and state.ComboPoints > 0 then
        local banked = math.floor(state.ComboPoints * state.Multiplier)
        state.Total += banked
        state.BestCombo = math.max(state.BestCombo, banked)
        state.Combos += 1
    end
    state.ComboActive = false
    state.ComboPoints = 0
    state.Multiplier = 1
    state.LastSide = 0
end

-- Rupture : la figure en cours est perdue (rien n'est acquis).
local function breakCombo(state: State, reason: string)
    if state.ComboActive then
        state.Breaks[reason] = (state.Breaks[reason] or 0) + 1
    end
    state.ComboActive = false
    state.ComboPoints = 0
    state.Multiplier = 1
    state.LastSide = 0
end

--[[
    Intègre un échantillon. `inZone` : position dans la zone de drift.
    Renvoie un événement éventuel ("Banked", "Broken:<raison>") pour l'affichage.
]]
function DriftScoring.observe(state: State, sample: Sample, inZone: boolean): string?
    local p = DriftScoring.Params
    local last = state.Last
    state.Last = sample
    if last == nil then
        return nil
    end
    local dt = sample.T - last.T
    if dt <= 0 or dt > 1 then
        -- Trou de données : on ne crédite rien sur l'intervalle (prudence).
        state.LastAngle = nil
        return nil
    end
    local speed = math.sqrt(sample.VX * sample.VX + sample.VZ * sample.VZ)
    if sample.Corrected or speed > p.MaxPlausibleMs then
        breakCombo(state, "Invalid")
        return "Broken:Invalid"
    end
    if sample.Wear - last.Wear >= p.CollisionWear then
        breakCombo(state, "Collision")
        return "Broken:Collision"
    end
    if not inZone then
        local had = state.ComboActive
        breakCombo(state, "OutOfZone")
        return if had then "Broken:OutOfZone" else nil
    end
    local signed = DriftScoring.slipAngle(sample.Heading, sample.VX, sample.VZ)
    local angle = math.abs(signed)
    -- Tête-à-queue : sur-rotation prolongée.
    if angle > p.SpinAngleDeg and speed > 2 then
        state.SpinSince = state.SpinSince or sample.T
        if sample.T - (state.SpinSince :: number) >= p.SpinHoldS then
            local had = state.ComboActive
            breakCombo(state, "Spin")
            return if had then "Broken:Spin" else nil
        end
    else
        state.SpinSince = nil
    end
    local drifting = speed >= p.MinSpeedMs and angle >= p.MinAngleDeg and angle <= p.MaxAngleDeg
    local event: string? = nil
    if drifting then
        local side = if signed > 0 then 1 else -1
        if not state.ComboActive then
            state.ComboActive = true
            state.ComboPoints = 0
            state.Multiplier = 1
        elseif state.LastSide ~= 0 and side ~= state.LastSide then
            -- Enchaînement : changement de sens dans la même figure.
            state.Multiplier = math.min(p.MaxMultiplier, state.Multiplier + p.TransitionStep)
        end
        state.LastSide = side
        local speedFactor = math.min(speed / p.SpeedRefMs, p.MaxSpeedFactor)
        local control = 1
        if state.LastAngle ~= nil then
            local rate = math.abs(angle - (state.LastAngle :: number)) / dt
            if rate > p.JitterDegPerS then
                control = 0.5
            end
        end
        state.ComboPoints += p.PointsPerS * dt * speedFactor * angleFactor(angle) * control
        state.DriftDistanceM += speed * dt
        state.LastDriftT = sample.T
    elseif state.ComboActive and sample.T - state.LastDriftT > p.GapS then
        -- Fin propre de la figure : acquise.
        bank(state)
        event = "Banked"
    end
    state.LastAngle = if drifting then angle else nil
    return event
end

-- Fin de session : la figure en cours, si elle est propre, est acquise.
function DriftScoring.finish(state: State): number
    bank(state)
    return state.Total
end

-- Score affiché en cours (acquis + figure en cours × multiplicateur).
function DriftScoring.live(state: State): (number, number, number)
    return state.Total, math.floor(state.ComboPoints * state.Multiplier), state.Multiplier
end

return table.freeze(DriftScoring)
