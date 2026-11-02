--!strict
-- Tests de la validation des définitions : rien de non implémenté ne doit passer.

local function deepCopy(value: any): any
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, child in value do
        copy[key] = deepCopy(child)
    end
    return copy
end

return function(T: any, H: any)
    local VehicleDefinitions = H.require("ReplicatedStorage.Shared.Vehicles.VehicleDefinitions")
    local P01 = VehicleDefinitions.get("proto_p01")

    T.suite("Définitions de véhicules")

    T.test("le prototype P-01 est enregistré, valide et gelé", function()
        T.truthy(P01 ~= nil)
        local ok, errors = VehicleDefinitions.validate(P01)
        T.truthy(ok, table.concat(errors, " ; "))
        T.truthy(table.isfrozen(P01), "définition gelée")
        T.truthy(table.isfrozen(P01.Powertrain.Engine), "gel récursif")
        T.truthy(P01.IsTestPrototype, "marqué prototype d'essai")
    end)

    T.test("identifiant inconnu → nil", function()
        T.equal(VehicleDefinitions.get("inexistant"), nil)
    end)

    local function rejects(label: string, mutate: (any) -> ())
        T.test("refus : " .. label, function()
            local copy = deepCopy(P01)
            mutate(copy)
            local ok = VehicleDefinitions.validate(copy)
            T.equal(ok, false, label)
        end)
    end

    rejects("motorisation électrique (non implémentée)", function(d)
        d.Powertrain.Kind = "Electric"
    end)
    rejects("boîte manuelle (non implémentée)", function(d)
        d.Powertrain.Transmission.Kind = "Manual"
    end)
    rejects("ABS déclaré (aide non implémentée)", function(d)
        d.Aids.Abs = true
    end)
    rejects("antipatinage déclaré", function(d)
        d.Aids.TractionControl = true
    end)
    rejects("RWD avec couple avant", function(d)
        d.Powertrain.Drivetrain.FrontTorqueShare = 0.3
    end)
    rejects("AWD avec répartition 100 % arrière", function(d)
        d.Powertrain.Drivetrain.Layout = "AWD"
        d.Powertrain.Drivetrain.FrontTorqueShare = 0
    end)
    rejects("rapports non décroissants", function(d)
        d.Powertrain.Transmission.ForwardRatios = { 3.4, 3.5 }
    end)
    rejects("seuils de boîte provoquant un pompage", function(d)
        d.Powertrain.Transmission.ShiftDownRpm = 5000
    end)
    rejects("masse nulle", function(d)
        d.Chassis.MassKg = 0
    end)
    rejects("masse NaN", function(d)
        d.Chassis.MassKg = 0 / 0
    end)
    rejects("ressort trop souple", function(d)
        d.Suspension.Rear.SpringRateNpm = 5000
    end)

    T.test("AWD cohérent accepté par la validation (architecture prête, non testé en jeu)", function()
        local copy = deepCopy(P01)
        copy.Powertrain.Drivetrain.Layout = "AWD"
        copy.Powertrain.Drivetrain.FrontTorqueShare = 0.4
        local ok, errors = VehicleDefinitions.validate(copy)
        T.truthy(ok, table.concat(errors, " ; "))
    end)

    T.test("vitesse limitée par la boîte cohérente", function()
        local top = VehicleDefinitions.gearLimitedTopSpeedKmh(P01)
        T.between(top, 280, 300, "vitesse cinématique au rupteur")
        T.note(
            string.format("P-01 : vitesse cinématique au rupteur en 6e = %.0f km/h (borne, pas une performance)", top)
        )
    end)
end
