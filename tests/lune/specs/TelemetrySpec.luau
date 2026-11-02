--!strict
-- Tests de la logique de mesure 0–100 km/h et 100–0 km/h (sans Roblox).

return function(T: any, H: any)
    local Telemetry = H.require("ReplicatedStorage.Shared.Vehicles.Telemetry")

    T.suite("Mesures locales")

    T.test("0–100 km/h mesuré depuis l'arrêt", function()
        local state = Telemetry.new()
        local dt = 0.01
        Telemetry.update(state, 0, 0, 0, 1, 0, 0, dt)
        local speed = 0
        for _ = 1, 1000 do
            speed += 10 * 3.6 * dt -- 10 m/s² constants
            Telemetry.update(state, speed, 1, 0, 1, 0, 0, dt)
            if state.LastLaunchSeconds then
                break
            end
        end
        T.truthy(state.LastLaunchSeconds, "mesure produite")
        T.near(state.LastLaunchSeconds, 2.78, 0.05)
        T.equal(state.BestLaunchSeconds, state.LastLaunchSeconds)
    end)

    T.test("0–100 annulé si l'on freine", function()
        local state = Telemetry.new()
        Telemetry.update(state, 0, 0, 0, 1, 0, 0, 0.1)
        Telemetry.update(state, 10, 1, 0, 1, 0, 0, 0.1)
        Telemetry.update(state, 20, 0, 1, 1, 0, 0, 0.1)
        T.equal(state.LaunchPhase, "Idle")
        T.equal(state.LastLaunchSeconds, nil)
    end)

    T.test("100–0 km/h : distance horizontale mesurée", function()
        local state = Telemetry.new()
        Telemetry.update(state, 105, 0, 0, 4, 0, 0, 0.1)
        local speed, z = 99, 0
        while speed >= 1 do
            Telemetry.update(state, speed, 0, 1, 3, 0, z, 0.05)
            speed -= 5
            z -= 1.2
        end
        Telemetry.update(state, 0, 0, 1, 1, 0, z, 0.05)
        T.truthy(state.LastBrakeDistanceM, "mesure produite")
        T.near(state.LastBrakeDistanceM, 24, 1.3)
    end)

    T.test("100–0 non mesuré si le freinage n'est pas franc", function()
        local state = Telemetry.new()
        Telemetry.update(state, 105, 0, 0, 4, 0, 0, 0.1)
        Telemetry.update(state, 95, 0, 0.3, 4, 0, -5, 0.1)
        Telemetry.update(state, 0, 0, 0.3, 4, 0, -50, 0.1)
        T.equal(state.LastBrakeDistanceM, nil)
    end)
end
