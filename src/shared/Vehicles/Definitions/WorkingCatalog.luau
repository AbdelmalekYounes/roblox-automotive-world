--!strict
--[[
    Modèles de TRAVAIL du catalogue commercial (lot 0.5), PROVISOIRES.

    Le cahier des charges prévoit dix-huit modèles originaux dont la liste
    officielle n'est pas encore validée. Ces six modèles fictifs permettent de
    faire fonctionner les concessions et le marché : ce ne sont PAS des modèles
    officiels, leurs visuels sont temporaires (carrosserie des prototypes,
    inscription « PROVISOIRE ») et ils ne sont achetables qu'en environnement de
    développement (VehicleCatalog). Les prototypes P-01/P-02/P-03 restent des
    véhicules techniques : les modèles ci-dessous en dérivent seulement pour la
    mécanique, avec masse, puissance et transmission propres.

    Masse modifiée → raideurs, amortissements, antiroulis et freins mis à
    l'échelle de la masse (mêmes fréquences propres que la base).
]]

local Types = require(script.Parent.Parent.VehicleTypes)
local PrototypeP01 = require(script.Parent.PrototypeP01)
local PrototypeP02 = require(script.Parent.PrototypeP02)
local PrototypeP03 = require(script.Parent.PrototypeP03)
local ValidationVariants = require(script.Parent.ValidationVariants)

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

type Spec = {
    Id: string,
    Name: string,
    Label: string,
    Body: { number },
    Accent: { number },
    MassKg: number,
    TorqueFactor: number,
    Capacity: number?,
    Drivetrain: any?,
    Transmission: any?,
    MotorPowerKw: number?,
}

local function model(base: Types.VehicleDefinition, spec: Spec): Types.VehicleDefinition
    local definition = deepCopy(base) :: any
    local massFactor = spec.MassKg / base.Chassis.MassKg
    definition.Id = spec.Id
    definition.DisplayName = spec.Name .. " (provisoire)"
    definition.IsTestPrototype = false
    definition.Chassis.MassKg = spec.MassKg
    for _, axle in { definition.Suspension.Front, definition.Suspension.Rear } do
        axle.SpringRateNpm *= massFactor
        axle.BumpDampingNsPm *= massFactor
        axle.ReboundDampingNsPm *= massFactor
        axle.AntiRollNpm *= massFactor
    end
    definition.Brakes.MaxTorqueFrontNm *= massFactor
    definition.Brakes.MaxTorqueRearNm *= massFactor
    local powertrain = definition.Powertrain
    if powertrain.Engine then
        for _, point in powertrain.Engine.TorqueCurve do
            point.TorqueNm *= spec.TorqueFactor
        end
    end
    if powertrain.Motor then
        powertrain.Motor.MaxTorqueNm *= spec.TorqueFactor
        if spec.MotorPowerKw then
            powertrain.Motor.MaxPowerKw = spec.MotorPowerKw
        end
    end
    if spec.Capacity then
        powertrain.Energy.Capacity = spec.Capacity
    end
    if spec.Drivetrain then
        powertrain.Drivetrain = spec.Drivetrain
    end
    if spec.Transmission then
        powertrain.Transmission = deepCopy(spec.Transmission)
    end
    -- Embrayage dimensionné pour le couple du modèle (marge du lot 0.2 conservée).
    local clutch = powertrain.Transmission.Clutch
    if clutch and spec.TorqueFactor > 1 then
        clutch.MaxTorqueNm *= spec.TorqueFactor
    end
    definition.Appearance.BodyRgb = spec.Body
    definition.Appearance.AccentRgb = spec.Accent
    definition.Appearance.Label = spec.Label .. " PROVISOIRE"
    return definition :: Types.VehicleDefinition
end

local dct = (ValidationVariants[1] :: any).Powertrain.Transmission

return {
    model(PrototypeP02, {
        Id = "wk_aster",
        Name = "Aster",
        Label = "ASTER",
        Body = { 210, 214, 220 },
        Accent = { 40, 120, 200 },
        MassKg = 1080,
        TorqueFactor = 0.85,
        Capacity = 42,
    }),
    model(PrototypeP01, {
        Id = "wk_brio",
        Name = "Brio",
        Label = "BRIO",
        Body = { 176, 28, 34 },
        Accent = { 240, 240, 240 },
        MassKg = 1180,
        TorqueFactor = 0.9,
        Capacity = 45,
    }),
    model(PrototypeP01, {
        Id = "wk_cadence",
        Name = "Cadence",
        Label = "CADENCE",
        Body = { 28, 58, 120 },
        Accent = { 200, 200, 205 },
        MassKg = 1420,
        TorqueFactor = 1.15,
        Capacity = 58,
    }),
    model(PrototypeP02, {
        Id = "wk_dune",
        Name = "Dune",
        Label = "DUNE",
        Body = { 196, 176, 140 },
        Accent = { 60, 60, 64 },
        MassKg = 1780,
        TorqueFactor = 1.35,
        Capacity = 65,
        Drivetrain = {
            Layout = "AWD",
            FrontTorqueShare = 0.4,
            FrontDifferential = { Kind = "Open", PreloadNm = 0, PowerLockRatio = 0, CoastLockRatio = 0 },
            RearDifferential = { Kind = "Open", PreloadNm = 0, PowerLockRatio = 0, CoastLockRatio = 0 },
            CenterDifferential = { Kind = "LimitedSlip", PreloadNm = 50, PowerLockRatio = 0.3, CoastLockRatio = 0.2 },
        },
    }),
    model(PrototypeP01, {
        Id = "wk_eclat",
        Name = "Éclat",
        Label = "ECLAT",
        Body = { 240, 196, 32 },
        Accent = { 22, 23, 26 },
        MassKg = 1300,
        TorqueFactor = 1.4,
        Capacity = 60,
        Transmission = dct,
    }),
    model(PrototypeP03, {
        Id = "wk_fil",
        Name = "Fil",
        Label = "FIL",
        Body = { 26, 82, 56 },
        Accent = { 236, 236, 232 },
        MassKg = 1560,
        TorqueFactor = 0.75,
        Capacity = 48,
        MotorPowerKw = 140,
    }),
}
