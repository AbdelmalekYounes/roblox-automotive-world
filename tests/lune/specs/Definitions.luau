--!strict
local Fixtures = require("../fixtures/Fixtures")
-- Tests de la validation des définitions : rien d'incohérent ne doit passer.

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
    local P01 = Fixtures.get("proto_p01")

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

    rejects("moteur électrique sur un véhicule essence", function(d)
        d.Powertrain.Motor = {
            MaxTorqueNm = 300,
            MaxPowerKw = 150,
            MaxRpm = 15000,
            InertiaKgM2 = 0.05,
            TopSpeedKmh = 180,
            DriveEfficiency = 0.9,
            RegenMaxPowerKw = 60,
            RegenMaxTorqueNm = 200,
            RegenEfficiency = 0.85,
            RegenLevels = { 0.3 },
            AuxPowerKw = 1,
        }
    end)
    rejects("électrique sans moteur électrique", function(d)
        d.Powertrain.Energy.Kind = "Electric"
    end)
    rejects("boîte manuelle sans embrayage", function(d)
        d.Powertrain.Transmission.Kind = "Manual"
    end)
    rejects("automatique sans convertisseur", function(d)
        d.Powertrain.Transmission.Converter = nil
    end)
    rejects("embrayage plus faible que le moteur", function(d)
        d.Powertrain.Transmission.Kind = "Sequential"
        d.Powertrain.Transmission.Clutch = { MaxTorqueNm = 150 }
    end)
    rejects("rapport unique sur moteur thermique", function(d)
        d.Powertrain.Transmission.Kind = "SingleSpeed"
        d.Powertrain.Transmission.ForwardRatios = { 3 }
    end)
    rejects("autobloquant sur l'essieu non moteur", function(d)
        d.Powertrain.Drivetrain.FrontDifferential =
            { Kind = "LimitedSlip", PreloadNm = 50, PowerLockRatio = 0.3, CoastLockRatio = 0.2 }
    end)
    rejects("aide déclarée par une valeur non booléenne", function(d)
        d.Aids.Abs = "oui"
    end)
    rejects("adhérence mouillée supérieure au sec", function(d)
        d.Tires.WetGripRatio = 1.2
    end)
    rejects("sonde de contact inconnue", function(d)
        d.Suspension.ContactProbe = "Cube"
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

    rejects("AWD sans différentiel central", function(d)
        d.Powertrain.Drivetrain.Layout = "AWD"
        d.Powertrain.Drivetrain.FrontTorqueShare = 0.4
    end)

    T.test("jeu : la Comète seule, valide et gelée ; jeux d'essai valides (lot BASE-01)", function()
        local ids = {}
        for _, definition in VehicleDefinitions.all() do
            local ok, errors = VehicleDefinitions.validate(definition)
            T.truthy(ok, definition.Id .. " : " .. table.concat(errors, " ; "))
            T.truthy(table.isfrozen(definition.Powertrain.Transmission), definition.Id .. " gelé")
            T.truthy(definition.IsTestPrototype == false, definition.Id .. " : modèle du jeu, pas un prototype")
            table.insert(ids, definition.Id)
        end
        T.equal(table.concat(ids, ","), "wk_comete", "registre du jeu")
        -- Prototypes et variantes : retirés du jeu, conservés comme jeux d'essai, toujours valides.
        for _, definition in Fixtures.all() do
            local ok, errors = VehicleDefinitions.validate(definition)
            T.truthy(ok, definition.Id .. " (jeu d'essai) : " .. table.concat(errors, " ; "))
            T.truthy(VehicleDefinitions.get(definition.Id) == nil, definition.Id .. " absent du jeu")
        end
        T.note("Définitions du jeu : " .. table.concat(ids, ", "))
    end)

    T.test("P-02 et P-03 conformes à la demande du lot 0.2", function()
        local p02 = Fixtures.get("proto_p02")
        local p03 = Fixtures.get("proto_p03")
        T.equal(p02.Powertrain.Drivetrain.Layout, "FWD")
        T.equal(p02.Powertrain.Energy.Kind, "Diesel")
        T.equal(p02.Powertrain.Transmission.Kind, "Manual")
        T.truthy(p02.Chassis.MassKg ~= P01.Chassis.MassKg, "masse distincte du P-01")
        T.equal(p03.Powertrain.Drivetrain.Layout, "AWD")
        T.equal(p03.Powertrain.Energy.Kind, "Electric")
        T.equal(p03.Powertrain.Transmission.Kind, "SingleSpeed")
        T.truthy(p03.Powertrain.Motor.RegenMaxPowerKw > 0, "freinage régénératif")
        T.truthy(#p03.Powertrain.Motor.RegenLevels >= 2, "récupération réglable")
    end)

    T.test("chaque type de boîte reste couvert (jeu et jeux d'essai)", function()
        local kinds = {}
        for _, definition in VehicleDefinitions.all() do
            kinds[definition.Powertrain.Transmission.Kind] = true
        end
        for _, definition in Fixtures.all() do
            kinds[definition.Powertrain.Transmission.Kind] = true
        end
        for _, kind in { "Automatic", "Manual", "DualClutch", "Sequential", "CVT", "SingleSpeed" } do
            T.truthy(kinds[kind], kind)
        end
    end)

    T.test("parc d'essai supprimé (lot BASE-01) ; marche arrière par boîte", function()
        T.truthy((VehicleDefinitions :: any).TestFleet == nil, "plus de parc d'essai")
        T.equal(VehicleDefinitions.DefaultTestVehicleId, "wk_comete", "bancs de Studio : la Comète")
    end)

    T.test("vitesse limitée par la boîte cohérente", function()
        local top = VehicleDefinitions.gearLimitedTopSpeedKmh(P01)
        T.between(top, 280, 300, "vitesse cinématique au rupteur")
        T.note(
            string.format("P-01 : vitesse cinématique au rupteur en 6e = %.0f km/h (borne, pas une performance)", top)
        )
    end)

    T.test("A1 : braquage max fonction de la seule vitesse, décroissant, bornes du modèle", function()
        local VehicleDynamics = H.require("ReplicatedStorage.Shared.Vehicles.Physics.VehicleDynamics")
        local steering = P01.Steering
        T.near(math.deg(VehicleDynamics.maxSteerAngle(P01, 0)), steering.MaxAngleDeg, 1e-9, "à l'arrêt")
        local reference = steering.HighSpeedReferenceKmh / 3.6
        T.near(math.deg(VehicleDynamics.maxSteerAngle(P01, reference)), steering.HighSpeedAngleDeg, 1e-9)
        T.near(
            math.deg(VehicleDynamics.maxSteerAngle(P01, reference * 2)),
            steering.HighSpeedAngleDeg,
            1e-9,
            "plafond au-delà de la vitesse de référence"
        )
        T.near(
            VehicleDynamics.maxSteerAngle(P01, -10),
            VehicleDynamics.maxSteerAngle(P01, 10),
            1e-12,
            "symétrique en marche arrière"
        )
        local previous = math.huge
        for kmh = 0, 160, 10 do
            local angle = VehicleDynamics.maxSteerAngle(P01, kmh / 3.6)
            T.truthy(angle <= previous, "décroissant à " .. kmh .. " km/h")
            previous = angle
        end
    end)

    T.test("A3 : marche arrière par maintien du frein réservée aux boîtes sans sélecteur", function()
        T.equal(VehicleDefinitions.reverseEngagement("Automatic"), "HoldBrakeAtStop")
        T.equal(VehicleDefinitions.reverseEngagement("Manual"), "Selector")
        T.equal(VehicleDefinitions.reverseEngagement("DualClutch"), "Selector")
        T.equal(VehicleDefinitions.reverseEngagement("Sequential"), "Selector")
        T.equal(VehicleDefinitions.reverseEngagement("CVT"), "HoldBrakeAtStop")
        T.equal(VehicleDefinitions.reverseEngagement("SingleSpeed"), "HoldBrakeAtStop")
        T.equal(VehicleDefinitions.reverseEngagement(P01.Powertrain.Transmission.Kind), "HoldBrakeAtStop")
    end)

    T.test("A4 : seuil de sortie provisoire = 20 km/h (jeu et jeux d'essai)", function()
        local all = VehicleDefinitions.all()
        for _, definition in Fixtures.all() do
            table.insert(all, definition)
        end
        for _, definition in all do
            T.equal(definition.Limits.ExitMaxSpeedKmh, 20, definition.Id)
        end
    end)
end
