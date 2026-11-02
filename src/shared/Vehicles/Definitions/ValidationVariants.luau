--!strict
-- Configurations de VALIDATION du lot 0.2 : la carrosserie et le châssis du
-- P-01, avec une autre boîte (double embrayage, séquentielle, CVT). Elles
-- servent à tester chaque type de boîte dans le jeu sans créer une carrosserie
-- par transmission. Ce ne sont pas des modèles du catalogue.

local Types = require(script.Parent.Parent.VehicleTypes)
local PrototypeP01 = require(script.Parent.PrototypeP01)

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

local function variant(
    id: string,
    displayName: string,
    label: string,
    accent: { number },
    transmission: Types.TransmissionDefinition
): Types.VehicleDefinition
    local definition = deepCopy(PrototypeP01) :: Types.VehicleDefinition
    definition.Id = id
    definition.DisplayName = displayName
    definition.Powertrain.Transmission = transmission
    definition.Appearance.Label = label
    definition.Appearance.AccentRgb = accent
    return definition
end

return {
    variant("proto_p01_dct", "P-01 · double embrayage (validation)", "P-01 DCT", { 90, 170, 255 }, {
        Kind = "DualClutch",
        ForwardRatios = { 3.5, 2.3, 1.65, 1.28, 1.02, 0.84, 0.7 },
        ReverseRatio = 3.3,
        FinalDrive = 3.9,
        Efficiency = 0.92,
        ShiftUpRpm = 6800,
        ShiftDownRpm = 3000,
        ShiftDurationS = 0.08,
        LaunchRpm = 3200,
        Clutch = { MaxTorqueNm = 320 },
    }),
    variant("proto_p01_seq", "P-01 · séquentielle (validation)", "P-01 SEQ", { 230, 60, 90 }, {
        Kind = "Sequential",
        ForwardRatios = { 3.2, 2.2, 1.65, 1.3, 1.08, 0.92 },
        ReverseRatio = 3.3,
        FinalDrive = 4.1,
        Efficiency = 0.93,
        ShiftUpRpm = 6900,
        ShiftDownRpm = 3500,
        ShiftDurationS = 0.06,
        LaunchRpm = 3500,
        Clutch = { MaxTorqueNm = 340 },
    }),
    variant("proto_p01_cvt", "P-01 · variateur CVT (validation)", "P-01 CVT", { 140, 220, 80 }, {
        Kind = "CVT",
        ForwardRatios = { 2.6, 0.45 },
        ReverseRatio = 2.6,
        FinalDrive = 5.2,
        Efficiency = 0.86,
        ShiftUpRpm = 0,
        ShiftDownRpm = 0,
        ShiftDurationS = 0,
        LaunchRpm = 3000,
        Clutch = { MaxTorqueNm = 320 },
        Cvt = {
            CruiseRpm = 1800,
            PowerRpm = 5800,
            RatioRatePerS = 1.6,
        },
    }),
} :: { Types.VehicleDefinition }
