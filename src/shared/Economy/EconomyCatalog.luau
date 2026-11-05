--!strict
--[[
    Barème PROVISOIRE de l'économie (lot 0.5) : prix des propriétés, des
    agrandissements, des modules, des pièces, de la main-d'œuvre et des
    services. Toutes les valeurs sont des HYPOTHÈSES de travail paramétrables
    (le cahier des charges ne fixe qu'une fourchette illustrative de 25 000 à
    60 000 crédits pour les propriétés) ; elles ne constituent pas un
    équilibrage final. Le serveur seul les applique ; le client ne les reçoit
    que pour afficher les devis.
]]

local EconomyCatalog = {}

EconomyCatalog.Version = "0.5.0-travail"

-- Propriétés : prix selon la catégorie de l'offre ; agrandissement par niveau.
EconomyCatalog.PropertyPrice = table.freeze({ Small = 25_000, Medium = 40_000, Prestige = 60_000 })
EconomyCatalog.GarageLevelPrice = table.freeze({ Small = 6_000, Medium = 9_000, Prestige = 12_000 })

-- Modules privés (catégories PROPOSÉES au lot 0.4, à arbitrer).
EconomyCatalog.ModulePrice = table.freeze({
    Workshop = 15_000,
    PaintBooth = 12_000,
    Lift = 8_000,
    PartsStorage = 5_000,
    Charging = 10_000,
    WashBay = 6_000,
    Showroom = 7_000,
    Lounge = 9_000,
})

-- Pièces détachées (prix neuf).
EconomyCatalog.PartPrice = table.freeze({
    ["TIRE-SPORT"] = 1_800,
    ["TIRE-RAIN"] = 1_500,
    ["BRAKE-SPORT"] = 2_400,
    ["SUSP-COILOVER"] = 3_200,
    ["DIFF-LSD-REAR"] = 2_800,
    ["DIFF-LSD-FRONT"] = 2_600,
    ["ECU-SPORT"] = 2_200,
})

-- Main-d'œuvre des garages publics (aucune dans un garage privé équipé).
EconomyCatalog.Labor = table.freeze({
    PartInstall = 250,
    PartRemove = 150,
    Cosmetics = 400,
    Tuning = 100,
})

-- Énergie : prix par unité réellement délivrée ; débits de livraison.
-- Plein d'une berline (≈ 50 L) ≈ 600 crédits ≈ 4 minutes de mission : coût lisible,
-- sans impasse (AUD-ECO-01 : une mission ordinaire reste accessible sans crédit).
EconomyCatalog.EnergyPrice = table.freeze({ Petrol = 12, Diesel = 11, Electric = 8 }) -- crédits par L ou kWh
EconomyCatalog.DeliveryRate = table.freeze({ Petrol = 2, Diesel = 2, Electric = 0.5 }) -- L/s ou kWh/s (accéléré)

-- Lavage et réparation.
EconomyCatalog.WashPrice = 120
EconomyCatalog.Repair = table.freeze({
    BaseFee = 150,
    ZoneFull = 1_800, -- carrosserie : une zone entièrement abîmée
    EngineFull = 3_000,
    SteeringFull = 1_500,
    SuspensionFull = 800, -- par roue
})

-- Marché entre joueurs.
EconomyCatalog.Market = table.freeze({
    MinPrice = 500,
    MaxPrice = 5_000_000,
    ListingDurationS = 72 * 3600,
    MaxActiveListingsPerSeller = 5,
})

-- Devis de réparation d'un état de dégâts (format DamageModel), en crédits.
function EconomyCatalog.repairQuote(damage: any): number
    local repair = EconomyCatalog.Repair
    local total = 0
    for _, wear in damage.Zones or {} do
        total += math.clamp(wear, 0, 1) * repair.ZoneFull
    end
    total += (1 - math.clamp(damage.Engine or 1, 0, 1)) * repair.EngineFull
    total += (1 - math.clamp(damage.Steering or 1, 0, 1)) * repair.SteeringFull
    for _, health in damage.Suspension or {} do
        total += (1 - math.clamp(health, 0, 1)) * repair.SuspensionFull
    end
    if total <= 0 then
        return 0
    end
    return math.floor(total + repair.BaseFee + 0.5)
end

return table.freeze(EconomyCatalog)
