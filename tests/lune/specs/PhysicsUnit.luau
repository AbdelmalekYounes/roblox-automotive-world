--!strict
-- Tests unitaires des briques physiques pures (pneu, suspension, groupe motopropulseur).

return function(T: any, H: any)
    local TireModel = H.require("ReplicatedStorage.Shared.Vehicles.Physics.TireModel")
    local Suspension = H.require("ReplicatedStorage.Shared.Vehicles.Physics.Suspension")
    local Powertrain = H.require("ReplicatedStorage.Shared.Vehicles.Physics.Powertrain")
    local SurfaceFriction = H.require("ReplicatedStorage.Shared.Vehicles.Physics.SurfaceFriction")
    local P01 = H.require("ReplicatedStorage.Shared.Vehicles.VehicleDefinitions").get("proto_p01")

    T.suite("Pneumatique")

    T.test("courbe nulle à l'origine, 1 au pic, croissante avant le pic", function()
        T.near(TireModel.curve(0, 0.8), 0, 1e-12)
        T.near(TireModel.curve(1, 0.8), 1, 1e-12)
        local previous = 0
        for i = 1, 10 do
            local value = TireModel.curve(i / 10, 0.8)
            T.truthy(value > previous, "courbe non croissante à " .. i / 10)
            previous = value
        end
    end)

    T.test("courbe décroît vers le glissement franc et s'y stabilise", function()
        T.truthy(TireModel.curve(2, 0.8) < 1)
        T.near(TireModel.curve(3, 0.8), 0.8, 1e-12)
        T.near(TireModel.curve(10, 0.8), 0.8, 1e-12)
        T.near(TireModel.curve(-3, 0.8), 0.8, 1e-12, "symétrie")
    end)

    T.test("ellipse de friction bornée", function()
        local fx, fy = TireModel.combine(5000, 5000, 4000, 3000)
        T.near((fx / 4000) ^ 2 + (fy / 3000) ^ 2, 1, 1e-9)
        local gx, gy = TireModel.combine(100, -50, 4000, 3000)
        T.equal(gx, 100)
        T.equal(gy, -50)
    end)

    T.test("limite anti-dépassement", function()
        T.near(TireModel.stopClamp(10000, 300, 0.01, 1 / 60), 300 * 0.01 * 60, 1e-9)
        T.equal(TireModel.stopClamp(-50, 300, 5, 1 / 60), -50)
    end)

    T.test("roue freinée à fond sur véhicule lancé : blocage, force opposée au mouvement", function()
        local omega, fx = 20 / 0.32, 0
        for _ = 1, 60 do
            omega, fx = TireModel.integrateWheel(omega, 0, 5000, 1.2, 0.32, 20, 3500, 0.1, 0.8, 1 / 60, 4)
        end
        T.equal(omega, 0, "roue bloquée")
        T.truthy(fx < 0, "force de freinage négative")
        T.near(fx, -3500 * 0.8, 1, "glissement franc")
    end)

    T.test("roue libre roulant à la vitesse du véhicule : force quasi nulle", function()
        local omega, fx = TireModel.integrateWheel(25 / 0.32, 0, 0, 1.2, 0.32, 25, 3500, 0.1, 0.8, 1 / 60, 4)
        T.near(omega * 0.32, 25, 0.05)
        T.near(fx, 0, 20)
    end)

    T.test("régime établi sous la limite d'adhérence : force transmise = couple / rayon", function()
        -- Régression : le couple moteur ne doit pas « disparaître » entre la
        -- roue et le châssis (force du pneu cohérente avec l'équilibre de la roue).
        local omega, fx = 10 / 0.32, 0
        for _ = 1, 240 do
            omega, fx = TireModel.integrateWheel(omega, 500, 0, 14, 0.32, 10, 3500, 0.1, 0.8, 1 / 60, 4)
        end
        T.near(fx, 500 / 0.32, 500 / 0.32 * 0.01)
    end)

    T.test("couple supérieur à l'adhérence : patinage (pas de force infinie)", function()
        local omega, fx = 10 / 0.32, 0
        for _ = 1, 120 do
            omega, fx = TireModel.integrateWheel(omega, 2000, 0, 14, 0.32, 10, 3500, 0.1, 0.8, 1 / 60, 4)
        end
        T.truthy(omega * 0.32 > 11, "la roue patine")
        T.truthy(fx <= 3500 + 1e-6, "force bornée par l'adhérence")
    end)

    T.test("roue immobile freinée à l'arrêt : reste immobile sans force", function()
        local omega, fx = TireModel.integrateWheel(0, 0, 500, 1.2, 0.32, 0, 3500, 0.1, 0.8, 1 / 60, 4)
        T.equal(omega, 0)
        T.equal(fx, 0)
    end)

    T.test("force latérale opposée à la dérive", function()
        T.truthy(TireModel.lateralForce(1, 20, 3000, math.rad(7), 0.8) < 0)
        T.truthy(TireModel.lateralForce(-1, 20, 3000, math.rad(7), 0.8) > 0)
        T.equal(TireModel.lateralForce(0, 20, 3000, math.rad(7), 0.8), 0)
    end)

    T.suite("Suspension")

    T.test("ressort + amortisseur, jamais de traction", function()
        local axle = P01.Suspension.Front
        local base = {
            Grounded = true,
            Compression = 0.1,
            CompressionVelocity = 0,
            LongitudinalVelocity = 0,
            LateralVelocity = 0,
            SurfaceFriction = 1,
        }
        T.near(Suspension.normalForce(axle, base), axle.SpringRateNpm * 0.1, 1e-6)
        local rebound = table.clone(base)
        rebound.Compression = 0.001
        rebound.CompressionVelocity = -5
        T.equal(Suspension.normalForce(axle, rebound), 0, "pas de force négative")
        local air = table.clone(base)
        air.Grounded = false
        T.equal(Suspension.normalForce(axle, air), 0)
    end)

    T.test("butée de fin de course progressive", function()
        local axle = P01.Suspension.Front
        local contact = {
            Grounded = true,
            Compression = axle.TravelM,
            CompressionVelocity = 0,
            LongitudinalVelocity = 0,
            LateralVelocity = 0,
            SurfaceFriction = 1,
        }
        T.truthy(Suspension.normalForce(axle, contact) > axle.SpringRateNpm * axle.TravelM)
    end)

    T.suite("Groupe motopropulseur")

    T.test("interpolation de la courbe de couple bornée", function()
        local curve = P01.Powertrain.Engine.TorqueCurve
        T.near(Powertrain.sampleTorque(curve, 500), 120, 1e-9)
        T.near(Powertrain.sampleTorque(curve, 1500), 142.5, 1e-9)
        T.near(Powertrain.sampleTorque(curve, 9000), 160, 1e-9)
    end)

    T.test("rapports signés et neutre", function()
        local transmission = P01.Powertrain.Transmission
        T.equal(Powertrain.gearRatio(transmission, 0), 0)
        T.equal(Powertrain.gearRatio(transmission, 1), 3.4)
        T.equal(Powertrain.gearRatio(transmission, -1), -3.3)
    end)

    T.test("propulsion : seules les roues arrière reçoivent du couple", function()
        local shares = Powertrain.wheelDriveShares(P01.Powertrain.Drivetrain)
        T.equal(shares[1], 0)
        T.equal(shares[2], 0)
        T.equal(shares[3], 0.5)
        T.equal(shares[4], 0.5)
    end)

    T.test("répartitions traction et intégrale calculées (non exercées en jeu)", function()
        local fwd = Powertrain.wheelDriveShares({ Layout = "FWD", FrontTorqueShare = 1 })
        T.equal(fwd[1] + fwd[2], 1)
        local awd = Powertrain.wheelDriveShares({ Layout = "AWD", FrontTorqueShare = 0.4 })
        T.near(awd[1] + awd[2], 0.4, 1e-12)
        T.near(awd[3] + awd[4], 0.6, 1e-12)
    end)

    T.test("marche arrière uniquement après maintien de « freiner » à l'arrêt", function()
        local Dynamics = H.require("ReplicatedStorage.Shared.Vehicles.Physics.VehicleDynamics")
        local state = Dynamics.createState(P01)
        state.Gear = 1
        local brakeHeld = { Throttle = 0, Brake = 1, Steer = 0, Handbrake = false }
        -- En mouvement : pas de marche arrière.
        for _ = 1, 60 do
            Powertrain.updateAutomatic(state, P01.Powertrain, brakeHeld, 10, 1 / 60)
        end
        T.equal(state.Gear, 1, "aucune marche arrière en roulant")
        -- À l'arrêt : 0,3 s de maintien.
        for _ = 1, 10 do
            Powertrain.updateAutomatic(state, P01.Powertrain, brakeHeld, 0, 1 / 60)
        end
        T.equal(state.Gear, 1, "pas encore")
        for _ = 1, 12 do
            Powertrain.updateAutomatic(state, P01.Powertrain, brakeHeld, 0, 1 / 60)
        end
        T.equal(state.Gear, -1, "marche arrière enclenchée")
        local throttle, brake = Powertrain.updateAutomatic(state, P01.Powertrain, brakeHeld, 0, 1 / 60)
        T.equal(throttle, 1, "en marche arrière, « freiner » accélère")
        T.equal(brake, 0)
    end)

    T.suite("Revêtements")

    T.test("asphalte de référence, glace très glissante, inconnu par défaut", function()
        T.equal(SurfaceFriction.forMaterialName("Asphalt"), 1)
        T.truthy(SurfaceFriction.forMaterialName("Ice") < 0.2)
        T.equal(SurfaceFriction.forMaterialName("MatiereInconnue"), SurfaceFriction.Default)
    end)
end
