--!strict
-- Générateur de scénarios de recherche de valeurs non finies (QA-A08, lot 0.9.2), partagé
-- par l'outil tests/lune/tools/nan-hunt.luau et le test de régression Lot092Stabilization.
-- Scénarios pseudo-aléatoires REPRODUCTIBLES (graine) proches de l'incident VM : véhicule
-- endommagé, souvent plaqué contre un obstacle, marches avant et arrière alternées, pas de
-- temps réels du simulateur (1 ms à 1/20 s), à-coups de collision, calages, passages.

local NanHunt = {}

-- Générateur congruentiel (2^31) : Lune n'a pas la classe Random de Roblox.
function NanHunt.rng(seed: number)
    local value = seed % 2147483647
    if value <= 0 then
        value += 2147483646
    end
    local rng = {}
    function rng:NextNumber(): number
        value = (value * 48271) % 2147483647
        return value / 2147483647
    end
    function rng:NextInteger(a: number, b: number): number
        return a + math.floor(self:NextNumber() * (b - a + 1))
    end
    return rng
end

local function finite(x: any): boolean
    return type(x) ~= "number" or (x == x and x > -math.huge and x < math.huge)
end

-- Premier champ non fini d'une table (profondeur limitée), sous forme de chemin.
function NanHunt.firstBad(value: any, path: string, depth: number): string?
    if type(value) == "number" then
        return if finite(value) then nil else path .. " = " .. tostring(value)
    elseif type(value) == "table" and depth > 0 then
        for key, child in value do
            local bad = NanHunt.firstBad(child, path .. "." .. tostring(key), depth - 1)
            if bad then
                return bad
            end
        end
    end
    return nil
end

--[[
    Joue un scénario. `definitions` : modèles parmi lesquels le tirage choisit (un seul pour
    cibler un modèle). Renvoie nil si tout reste fini, sinon un résumé : premier champ non
    fini, pas, phase, historique des six pas précédents.
]]
function NanHunt.scenario(Dynamics: any, DamageModel: any, definitions: { any }, seed: number): any?
    local rng = NanHunt.rng(seed)
    local definition = definitions[rng:NextInteger(1, #definitions)]
    local state = Dynamics.createState(definition)
    Dynamics.startEngine(state, definition)
    -- Dégâts : de intact à très endommagé (trains avant d'abord, comme dans l'incident).
    local damage = DamageModel.new()
    local severity = rng:NextNumber()
    damage.Engine = 1 - severity * rng:NextNumber()
    damage.Steering = 1 - severity * rng:NextNumber()
    damage.SteeringPullSide = if rng:NextNumber() < 0.5 then -1 else 1
    for corner = 1, 4 do
        damage.Suspension[corner] = if corner <= 2 then 1 - severity else 1 - severity * rng:NextNumber() * 0.5
    end
    state.Condition = DamageModel.condition(damage)
    local pinned = rng:NextNumber() < 0.7 -- véhicule contre un obstacle (vitesse de contact ≈ 0)
    local phase, phaseLeft = "forward", 0
    local history: { string } = {}
    local forward = 0
    for step = 1, 900 do
        if phaseLeft <= 0 then
            local r = rng:NextNumber()
            phase = if r < 0.3
                then "forward"
                elseif r < 0.6 then "reverse"
                elseif r < 0.72 then "idle"
                elseif r < 0.84 then "handbrake"
                else "both"
            phaseLeft = rng:NextInteger(10, 240)
        end
        phaseLeft -= 1
        local input = {
            Throttle = if phase == "forward" or phase == "both" then rng:NextNumber() * 0.5 + 0.5 else 0,
            Brake = if phase == "reverse" or phase == "both" then 1 else 0,
            Steer = math.clamp(rng:NextNumber() * 2 - 1, -1, 1),
            Handbrake = phase == "handbrake" or (phase == "idle" and rng:NextNumber() < 0.2),
            Clutch = 0,
        }
        local r = rng:NextNumber()
        -- Pas réels du simulateur : bornés à [1 ms ; 1/20 s] (VehicleSimulator.MAX_STEP_S).
        local dt = if r < 0.8 then 1 / 60 elseif r < 0.9 then 1 / 1000 else 0.001 + rng:NextNumber() * 0.049
        if not pinned then
            -- Mouvement libre grossier, piloté par la vitesse des roues (ordre de grandeur).
            local omega = (state.Wheels[3].AngularVelocity + state.Wheels[4].AngularVelocity) / 2
            forward = forward + (omega * definition.Tires.RadiusM - forward) * math.min(1, dt * 3)
        else
            forward = (rng:NextNumber() - 0.5) * 0.05
        end
        -- Événements : passage demandé, calage / redémarrage, panne d'énergie, à-coup de
        -- collision (vitesses de contact très élevées sur un pas, cas d'un choc ou d'une
        -- correction de position).
        local e = rng:NextNumber()
        local event = ""
        if e < 0.01 then
            event = "passage"
        elseif e < 0.012 then
            event = "calage"
        elseif e < 0.016 then
            event = "démarrage"
        elseif e < 0.018 then
            event = "énergie"
        end
        if e < 0.01 then
            pcall(Dynamics.requestShift, state, definition, if rng:NextNumber() < 0.5 then 1 else -1, forward)
        elseif e < 0.012 then
            Dynamics.stopEngine(state)
        elseif e < 0.016 then
            Dynamics.startEngine(state, definition)
        elseif e < 0.018 then
            state.EnergyAvailable = not state.EnergyAvailable
        end
        local spike = if pinned and rng:NextNumber() < 0.03 then (rng:NextNumber() - 0.5) * 80 else 0
        local contacts = {}
        for i = 1, 4 do
            local axle = if i <= 2 then definition.Suspension.Front else definition.Suspension.Rear
            local grounded = rng:NextNumber() > (if pinned then 0.05 else 0.02)
            contacts[i] = {
                Grounded = grounded,
                Compression = if grounded then rng:NextNumber() * axle.TravelM * 1.2 else 0,
                CompressionVelocity = if grounded
                    then (rng:NextNumber() - 0.5) * (if pinned then 6 else 1) + spike * 0.5
                    else 0,
                LongitudinalVelocity = if grounded then forward + spike + (rng:NextNumber() - 0.5) * 0.1 else 0,
                LateralVelocity = if grounded then (rng:NextNumber() - 0.5) * (if pinned then 2 else 0.5) else 0,
                SurfaceFriction = 0.5 + rng:NextNumber() * 0.7,
                Wet = rng:NextNumber() < 0.1,
                Wetness = rng:NextNumber() * 0.3,
            }
        end
        local motion =
            { Forward = forward, Lateral = (rng:NextNumber() - 0.5) * 0.5, YawRate = (rng:NextNumber() - 0.5) * 0.4 }
        Dynamics.updateSteering(state, definition, input.Steer, forward, dt)
        local before = string.format(
            "pas %d %s%s dt %.4f pointe %.1f | rapport %d moteur %.3g en marche %s | roues %.3g %.3g %.3g %.3g",
            step,
            phase,
            if event ~= "" then " [" .. event .. "]" else "",
            dt,
            spike,
            state.Gear,
            state.EngineOmega,
            tostring(state.EngineRunning),
            state.Wheels[1].AngularVelocity,
            state.Wheels[2].AngularVelocity,
            state.Wheels[3].AngularVelocity,
            state.Wheels[4].AngularVelocity
        )
        table.insert(history, before)
        if #history > 6 then
            table.remove(history, 1)
        end
        local ok, forces = pcall(Dynamics.step, state, definition, input, contacts, motion, dt)
        local bad = if ok
            then (NanHunt.firstBad(state, "state", 4) or NanHunt.firstBad(forces, "forces", 3))
            else "erreur : " .. tostring(forces)
        if bad then
            return {
                Definition = definition.Id,
                Bad = bad,
                Step = step,
                Phase = phase,
                Dt = dt,
                Pinned = pinned,
                Severity = severity,
                History = history,
                State = state,
            }
        end
    end
    return nil
end

return NanHunt
