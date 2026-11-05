--!strict
-- Diagnostic (lot 0.9.2, course GPS « Moteur calé ») : un véhicule à boîte automatique lancé
-- percute un obstacle (vitesse de contact annulée d'un pas à l'autre). Le moteur cale-t-il, et
-- la borne de stabilité du convertisseur (QA-A08) y est-elle pour quelque chose ? Chaque essai
-- est rejoué avec la borne (facteur 1,8) et sans borne (facteur démesuré), à l'identique.
-- Outil de diagnostic : aucune modification du jeu.
-- Usage : lune run tests/lune/tools/stall-impact.luau build/AutomotiveWorld.rbxlx [modèle]
local process = require("@lune/process")
local Harness = require("../Harness")
-- Lot BASE-01 : prototypes et variantes retirés du jeu, conservés comme jeux d'essai.
local Fixtures = require("../fixtures/Fixtures")
local function withFixtures(list: { any }): { any }
    for _, fixture in Fixtures.all() do
        table.insert(list, fixture)
    end
    return list
end
Harness.loadPlace(process.args[1] or "build/AutomotiveWorld.rbxlx")
local SHARED = "ReplicatedStorage.Shared."
local Dynamics = Harness.require(SHARED .. "Vehicles.Physics.VehicleDynamics")
-- Copie du module SANS borne (module gelé : facteur réécrit dans la source de la copie).
local original = Harness.game().ReplicatedStorage.Shared.Vehicles.Physics.VehicleDynamics
local unbounded = original:Clone()
unbounded.Name = "VehicleDynamicsSansBorne"
unbounded.Source = string.gsub(original.Source, "ConverterStabilityFactor = 1%.8", "ConverterStabilityFactor = 1e12")
unbounded.Parent = original.Parent
local DynamicsUnbounded = Harness.require(SHARED .. "Vehicles.Physics.VehicleDynamicsSansBorne")
assert(DynamicsUnbounded.ConverterStabilityFactor == 1e12, "copie sans borne")
local DamageModel = Harness.require(SHARED .. "Vehicles.Physics.DamageModel")
local Definitions = Harness.require(SHARED .. "Vehicles.VehicleDefinitions")

local function contacts(definition: any, forward: number)
    local list = {}
    for i = 1, 4 do
        list[i] = {
            Grounded = true,
            Compression = Dynamics.staticCompression(definition, i <= 2),
            CompressionVelocity = 0,
            LongitudinalVelocity = forward,
            LateralVelocity = 0,
            SurfaceFriction = 1,
            Wet = false,
            Wetness = 0,
        }
    end
    return list
end

-- Essai : départ, roulage `cruiseS` secondes à `throttle`, choc (avec rebond éventuel), puis
-- 5 s plaqué avec le pilote qui accélère puis tente de reculer (comme le pilote GPS), enfin 1 s
-- pédales relâchées. Retourne le compte rendu.
local function trial(
    definition: any,
    throttle: number,
    cruiseS: number,
    engineHealth: number,
    bounded: boolean,
    brakeAtImpact: boolean,
    reboundMs: number
)
    local Dynamics = if bounded then Dynamics else DynamicsUnbounded
    local state = Dynamics.createState(definition)
    Dynamics.startEngine(state, definition)
    local damage = DamageModel.new()
    damage.Engine = engineHealth
    state.Condition = DamageModel.condition(damage)
    local dt = 1 / 60
    local forward = 0
    local limitsBefore = Dynamics.converterLimits()
    local impactSpeed, impactGear, impactCoupled = 0, 0, false
    local stalledAt: number? = nil
    local steps = math.floor((cruiseS + 6) / dt)
    for step = 1, steps do
        local t = step * dt
        local afterImpact = t > cruiseS
        local input = {
            -- Choc : le pilote freine (si `brakeAtImpact`) pendant 0,5 s, accélère, puis recule.
            Throttle = if not afterImpact
                then throttle
                elseif t < cruiseS + 0.5 and brakeAtImpact then 0
                elseif t < cruiseS + 2.5 then 0.6
                else 0,
            Brake = if afterImpact
                    and ((t >= cruiseS + 2.5 and t < cruiseS + 5) or (brakeAtImpact and t < cruiseS + 0.5))
                then 1
                else 0,
            Steer = 0,
            Handbrake = false,
            Clutch = 0,
        }
        if not afterImpact then
            -- Vitesse des roues motrices (moyenne pondérée par leur part de couple).
            local omega, share = 0, 0
            for _, wheel in state.Wheels do
                omega += wheel.AngularVelocity * wheel.DriveShare
                share += wheel.DriveShare
            end
            omega /= math.max(share, 1e-6)
            forward = forward + (omega * definition.Tires.RadiusM - forward) * math.min(1, dt * 3)
        else
            if impactSpeed == 0 then
                impactSpeed, impactGear, impactCoupled = forward * 3.6, state.Gear, state.Coupled
            end
            -- Rebond (Δv du choc supérieur à la vitesse d'arrivée) pendant 0,25 s, puis plaqué.
            forward = if t < cruiseS + 0.25 then -reboundMs else 0
        end
        Dynamics.updateSteering(state, definition, 0, forward, dt)
        Dynamics.step(
            state,
            definition,
            input,
            contacts(definition, forward),
            { Forward = forward, Lateral = 0, YawRate = 0 },
            dt
        )
        if stalledAt == nil and state.EngineStalled then
            stalledAt = t - cruiseS
        end
    end
    return {
        ImpactKmh = impactSpeed,
        Gear = impactGear,
        Coupled = impactCoupled,
        StalledAt = stalledAt,
        -- Dernière seconde : pédales relâchées (relance attendue sans pédale d'embrayage).
        StillStalled = state.EngineStalled,
        FinalGear = state.Gear,
        Limits = Dynamics.converterLimits() - limitsBefore,
    }
end

local ids = {}
if process.args[2] then
    ids = { process.args[2] }
else
    for _, definition in withFixtures(Definitions.all()) do
        if definition.Powertrain.Transmission.Converter then
            table.insert(ids, definition.Id)
        end
    end
end
local differences, trials, stalls = 0, 0, 0
for _, id in ids do
    local definition = (Definitions.get(id) or Fixtures.get(id))
    for _, throttle in { 0.4, 0.8 } do
        for _, cruise in { 4, 10 } do
            for _, health in { 1, 0.4 } do
                for case = 0, 3 do
                    local brakeAtImpact, rebound = case % 2 == 1, if case >= 2 then 5 else 0
                    local with = trial(definition, throttle, cruise, health, true, brakeAtImpact, rebound)
                    local without = trial(definition, throttle, cruise, health, false, brakeAtImpact, rebound)
                    local same = (with.StalledAt ~= nil) == (without.StalledAt ~= nil)
                    trials += 1
                    if not same then
                        differences += 1
                    end
                    if with.StalledAt then
                        stalls += 1
                    end
                    if with.StalledAt or without.StalledAt then
                        print(
                            string.format(
                                "%-12s gaz %.1f %2ds moteur %.1f frein %-5s rebond %d m/s | choc %5.1f km/h rapport %d ponté %-5s | calé : borne %s (limitations %d) / sans borne %s | calé après pédales relâchées %s, rapport final %d%s",
                                id,
                                throttle,
                                cruise,
                                health,
                                tostring(brakeAtImpact),
                                rebound,
                                with.ImpactKmh,
                                with.Gear,
                                tostring(with.Coupled),
                                if with.StalledAt then string.format("%.2f s", with.StalledAt) else "non",
                                with.Limits,
                                if without.StalledAt then string.format("%.2f s", without.StalledAt) else "non",
                                tostring(with.StillStalled),
                                with.FinalGear,
                                if same then "" else "  <-- DIFFÉRENCE"
                            )
                        )
                    end
                end
            end
        end
    end
end
print(
    string.format(
        "%d essai(s), %d calage(s) avec la borne, %d différence(s) entre « avec borne » et « sans borne »",
        trials,
        stalls,
        differences
    )
)
