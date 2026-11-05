--!strict
local Fixtures = require("../fixtures/Fixtures")
-- Scénarios de conduite sur banc planaire hors Roblox.
-- Objectif : vérifier le comportement QUALITATIF de la dynamique (progressivité,
-- bornes physiques, signes, stabilité numérique). Les chiffres imprimés sont
-- des sorties du modèle, PAS des mesures réalisées dans Roblox.

local PlanarSim = require("../PlanarSim")

local GRAVITY = 9.81

local function hasNonFinite(snapshots: { any }): boolean
    for _, s in snapshots do
        for _, value in { s.Forward, s.Lateral, s.YawRate, s.LongAccel, s.LatAccel, s.Rpm } do
            if value ~= value or value == math.huge or value == -math.huge then
                return true
            end
        end
    end
    return false
end

local function input(throttle: number, brake: number, steer: number, handbrake: boolean?)
    return { Throttle = throttle, Brake = brake, Steer = steer, Handbrake = handbrake == true }
end

return function(T: any, H: any)
    local Dynamics = H.require("ReplicatedStorage.Shared.Vehicles.Physics.VehicleDynamics")
    local P01 = Fixtures.get("proto_p01")
    local muMax = math.max(P01.Tires.PeakFrictionLongitudinal, P01.Tires.PeakFrictionLateral)

    T.suite("Scénarios de conduite (banc planaire)")

    T.test("immobile, frein à main serré, sans commande : reste immobile", function()
        local snaps = PlanarSim.run(Dynamics, P01, {
            Dt = 1 / 60,
            Duration = 5,
            Input = function()
                return input(0, 0, 0, true)
            end,
        })
        local last = snaps[#snaps]
        T.near(last.Forward, 0, 1e-6)
        T.near(last.Distance, 0, 1e-6)
        T.equal(last.Gear, 0, "reste au neutre")
    end)

    T.test("accélération progressive, bornée par l'adhérence, rapports montants", function()
        local launch: number? = nil
        local maxAccel = 0
        local speedAt01, speedAt1 = 0, 0
        local maxGear = 0
        local snaps = PlanarSim.run(Dynamics, P01, {
            Dt = 1 / 60,
            Duration = 30,
            Input = function()
                return input(1, 0, 0)
            end,
            Stop = function(s)
                maxAccel = math.max(maxAccel, s.LongAccel)
                maxGear = math.max(maxGear, s.Gear)
                if s.Time <= 0.1 + 1e-9 then
                    speedAt01 = s.Forward
                end
                if s.Time <= 1 + 1e-9 then
                    speedAt1 = s.Forward
                end
                if launch == nil and s.Forward * 3.6 >= 100 then
                    launch = s.Time
                    return true
                end
                return false
            end,
        })
        T.truthy(not hasNonFinite(snaps), "valeurs finies")
        T.truthy(launch ~= nil, "100 km/h atteints en moins de 30 s")
        local launchTime = launch :: number
        T.between(speedAt01 * 3.6, 0, 5, "vitesse à 0,1 s (pas de vitesse instantanée)")
        T.between(speedAt1 * 3.6, 5, 45, "vitesse à 1 s")
        T.truthy(
            maxAccel <= muMax * GRAVITY * 1.15,
            string.format("accélération max %.2f m/s² > adhérence", maxAccel)
        )
        T.truthy(maxGear >= 3, "au moins 3 rapports utilisés avant 100 km/h")
        T.between(launchTime, 4, 15, "0–100 du modèle")
        T.note(
            string.format(
                "0–100 km/h (modèle, dt 1/60) : %.2f s ; accélération max %.2f m/s²",
                launchTime,
                maxAccel
            )
        )
    end)

    T.test("freinage à fond depuis 100 km/h : décélération bornée, arrêt", function()
        local maxDecel = 0
        local snaps = PlanarSim.run(Dynamics, P01, {
            Dt = 1 / 60,
            Duration = 15,
            InitialForward = 100 / 3.6,
            Input = function()
                return input(0, 1, 0)
            end,
            Stop = function(s)
                maxDecel = math.max(maxDecel, -s.LongAccel)
                return s.Forward <= 0.05
            end,
        })
        local last = snaps[#snaps]
        T.truthy(not hasNonFinite(snaps), "valeurs finies")
        T.truthy(last.Forward <= 0.05, "véhicule arrêté")
        T.truthy(maxDecel <= muMax * GRAVITY * 1.15, string.format("décélération max %.2f m/s²", maxDecel))
        T.between(last.Distance, 25, 80, "distance 100–0 du modèle")
        T.note(
            string.format(
                "100–0 km/h (modèle, sans ABS) : %.1f m, décélération max %.2f m/s²",
                last.Distance,
                maxDecel
            )
        )
    end)

    T.test("roue libre : décélération lente sans inversion du sens", function()
        local snaps = PlanarSim.run(Dynamics, P01, {
            Dt = 1 / 60,
            Duration = 10,
            InitialForward = 100 / 3.6,
            Input = function()
                return input(0, 0, 0)
            end,
        })
        local last = snaps[#snaps]
        T.between(last.Forward * 3.6, 40, 99, "vitesse après 10 s de roue libre")
    end)

    T.test("marche arrière : maintien de « freiner » à l'arrêt puis recul limité", function()
        local snaps = PlanarSim.run(Dynamics, P01, {
            Dt = 1 / 60,
            Duration = 4,
            Input = function()
                return input(0, 1, 0)
            end,
        })
        local last = snaps[#snaps]
        T.equal(last.Gear, -1, "marche arrière engagée")
        T.truthy(last.Forward < -1, "le véhicule recule")
        T.truthy(last.Forward * 3.6 > -45, "recul à vitesse modérée après 4 s")
    end)

    T.test("virage à droite : lacet vers la droite, accélération latérale bornée", function()
        local maxLat = 0
        local snaps = PlanarSim.run(Dynamics, P01, {
            Dt = 1 / 60,
            Duration = 4,
            InitialForward = 60 / 3.6,
            Input = function(t)
                return input(0.25, 0, if t > 0.5 then 0.6 else 0)
            end,
            Stop = function(s)
                maxLat = math.max(maxLat, math.abs(s.LatAccel))
                return false
            end,
        })
        local last = snaps[#snaps]
        T.truthy(not hasNonFinite(snaps), "valeurs finies")
        T.truthy(last.YawRate > 0, "lacet positif = virage à droite")
        T.truthy(last.Heading > 0.5, "cap modifié vers la droite")
        T.truthy(maxLat <= muMax * GRAVITY * 1.2, string.format("accélération latérale max %.2f m/s²", maxLat))
        T.note(string.format("Virage à 60 km/h, braquage 60 %% : accélération latérale max %.2f m/s²", maxLat))
    end)

    T.test("virage à gauche symétrique", function()
        local snaps = PlanarSim.run(Dynamics, P01, {
            Dt = 1 / 60,
            Duration = 3,
            InitialForward = 60 / 3.6,
            Input = function()
                return input(0.25, 0, -0.6)
            end,
        })
        T.truthy(snaps[#snaps].YawRate < 0, "lacet négatif = virage à gauche")
    end)

    T.test("vitesse de pointe finie et sous la limite plausible serveur", function()
        local snaps = PlanarSim.run(Dynamics, P01, {
            Dt = 1 / 30,
            Duration = 150,
            Input = function()
                return input(1, 0, 0)
            end,
        })
        local top = 0
        for _, s in snaps do
            top = math.max(top, s.Forward * 3.6)
        end
        T.truthy(not hasNonFinite(snaps), "valeurs finies")
        T.between(top, 150, P01.Limits.MaxPlausibleSpeedKmh, "vitesse de pointe du modèle")
        T.note(
            string.format(
                "Vitesse de pointe du modèle (traînée Cx·S %.2f m²) : %.0f km/h",
                P01.Chassis.DragAreaM2,
                top
            )
        )
    end)

    for _, dt in { 1 / 30, 1 / 240 } do
        T.test(
            string.format(
                "stabilité numérique à dt = 1/%d (accélération + virage + frein à main)",
                math.round(1 / dt)
            ),
            function()
                local snaps = PlanarSim.run(Dynamics, P01, {
                    Dt = dt,
                    Duration = 8,
                    Input = function(t)
                        if t < 4 then
                            return input(1, 0, 0)
                        end
                        return input(0.3, 0, 1, t > 6)
                    end,
                })
                T.truthy(not hasNonFinite(snaps), "valeurs finies")
                local last = snaps[#snaps]
                T.truthy(math.abs(last.Forward) < 100, "vitesse bornée")
                T.truthy(math.abs(last.YawRate) < 10, "lacet borné")
            end
        )
    end
end
