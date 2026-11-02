--!strict
-- Banc d'essai PLANAIRE hors Roblox pour la dynamique pure.
--
-- Il remplace le moteur physique Roblox par un modèle simple de châssis
-- rigide en 2D (avance, dérive, lacet) sur sol plat, avec transferts de
-- charge quasi statiques. Il sert à détecter des erreurs de signe, des
-- divergences numériques et des comportements absurdes ; les valeurs
-- produites NE SONT PAS des performances mesurées dans le jeu.

local PlanarSim = {}

export type Snapshot = {
    Time: number,
    Forward: number, -- m/s
    Lateral: number, -- m/s (droite positive)
    YawRate: number, -- rad/s (droite positive)
    Heading: number, -- rad
    Distance: number, -- m parcourus
    LongAccel: number, -- m/s²
    LatAccel: number, -- m/s²
    Gear: number,
    Rpm: number,
}

export type Options = {
    Dt: number,
    Duration: number,
    InitialForward: number?,
    Input: (t: number, snapshot: Snapshot, state: any) -> any,
    Stop: ((snapshot: Snapshot) -> boolean)?,
    -- Revêtement : multiplicateur d'adhérence (par roue possible) et mouillé.
    Surface: (number | { number })?,
    Wet: boolean?,
    -- Préparation de l'état avant le départ (aides, rapport, réserve…).
    Prepare: ((state: any) -> ())?,
    -- Moteur arrêté au départ (par défaut : démarré, comme un conducteur à bord).
    EngineOff: boolean?,
    -- Pente : sinus de l'angle, positif quand le véhicule est tourné vers la montée.
    Grade: number?,
}

function PlanarSim.run(Dynamics: any, definition: any, options: Options): ({ Snapshot }, any)
    local state = Dynamics.createState(definition)
    local layout = Dynamics.wheelLayout(definition)
    local chassis = definition.Chassis
    local mass = chassis.MassKg
    local yawInertia = mass * (chassis.LengthM ^ 2 + chassis.WidthM ^ 2) / 12
    local dt = options.Dt

    local u = options.InitialForward or 0
    local w, r, heading, distance = 0, 0, 0, 0
    local ax, ay = 0, 0

    if not options.EngineOff then
        Dynamics.startEngine(state, definition)
    end
    -- Roues déjà en rotation si le véhicule part lancé.
    for _, wheel in state.Wheels do
        wheel.AngularVelocity = u / definition.Tires.RadiusM
    end
    if u > 0 then
        state.Gear = 1
    end
    if options.Prepare then
        options.Prepare(state)
    end

    local snapshots: { Snapshot } = {}
    local t = 0
    local snapshot: Snapshot = {
        Time = 0,
        Forward = u,
        Lateral = 0,
        YawRate = 0,
        Heading = 0,
        Distance = 0,
        LongAccel = 0,
        LatAccel = 0,
        Gear = state.Gear,
        Rpm = state.EngineRpm,
    }

    while t < options.Duration do
        local input = options.Input(t, snapshot, state)
        if input.Clutch == nil then
            input.Clutch = 0
        end
        Dynamics.updateSteering(state, definition, input.Steer, u, dt)

        local contacts = {}
        for index, place in layout do
            local wheel = state.Wheels[index]
            local axle = if place.IsFront then definition.Suspension.Front else definition.Suspension.Rear
            local track = if place.IsFront then chassis.TrackFrontM else chassis.TrackRearM
            -- Charge : statique + transfert longitudinal + transfert latéral.
            local load = Dynamics.nominalCornerLoad(definition, place.IsFront)
            local longTransfer = mass * ax * chassis.CgHeightM / chassis.WheelbaseM / 2
            load += if place.IsFront then -longTransfer else longTransfer
            local latTransfer = mass
                * ay
                * chassis.CgHeightM
                / track
                / 2
                * (if place.IsFront then chassis.FrontWeightFraction else 1 - chassis.FrontWeightFraction)
            load += if place.Side < 0 then latTransfer else -latTransfer
            load = math.max(load, 0)

            -- Vitesse du point de contact dans le repère châssis puis roue.
            local vLong = u - r * place.Lateral
            local vLat = w + r * place.Longitudinal
            local steer = wheel.SteerAngle
            local c, s = math.cos(steer), math.sin(steer)
            local surface = options.Surface or 1
            contacts[index] = {
                Grounded = load > 0,
                Compression = load / axle.SpringRateNpm,
                CompressionVelocity = 0,
                LongitudinalVelocity = vLong * c + vLat * s,
                LateralVelocity = -vLong * s + vLat * c,
                SurfaceFriction = if type(surface) == "table" then surface[index] else surface,
                Wet = options.Wet == true,
            }
        end

        local forces = Dynamics.step(state, definition, input, contacts, { Forward = u, Lateral = w, YawRate = r }, dt)

        local forceForward, forceSide, moment = 0, 0, 0
        for index, place in layout do
            local wheel = state.Wheels[index]
            local f = forces[index]
            local c, s = math.cos(wheel.SteerAngle), math.sin(wheel.SteerAngle)
            local ff = f.Longitudinal * c - f.Lateral * s
            local fs = f.Longitudinal * s + f.Lateral * c
            forceForward += ff
            forceSide += fs
            moment += place.Longitudinal * fs - place.Lateral * ff
        end
        local speed = math.sqrt(u * u + w * w)
        local dragFactor = 0.5 * 1.225 * chassis.DragAreaM2 * speed
        forceForward -= dragFactor * u
        forceForward -= mass * 9.81 * (options.Grade or 0)
        forceSide -= dragFactor * w

        ax = forceForward / mass
        ay = forceSide / mass
        -- Repère tournant : u̇ = Ff/m + w·r ; ẇ = Fs/m − u·r ; ṙ = M/Iz.
        u += (ax + w * r) * dt
        w += (ay - u * r) * dt
        r += moment / yawInertia * dt
        heading += r * dt
        distance += math.sqrt(u * u + w * w) * dt
        t += dt

        snapshot = {
            Time = t,
            Forward = u,
            Lateral = w,
            YawRate = r,
            Heading = heading,
            Distance = distance,
            LongAccel = ax,
            LatAccel = ay,
            Gear = state.Gear,
            Rpm = state.EngineRpm,
        }
        table.insert(snapshots, snapshot)
        if options.Stop and options.Stop(snapshot) then
            break
        end
    end

    return snapshots, state
end

return PlanarSim
