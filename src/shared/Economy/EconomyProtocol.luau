--!strict
--[[
    Protocole client ↔ serveur de l'économie (lot 0.5). Même principe que la
    progression : le client demande, le serveur revalide (lieu, mouvement,
    droits, montants) et répond par l'état RÉEL : « Confirmed » (écriture
    durable confirmée), « Pending » (appliqué ou transfert en cours,
    récupérable), « Duplicate », « Rejected » (raison), « Unavailable ».
    « Quote » renvoie un devis sans rien modifier.
]]

local EconomyProtocol = {}

EconomyProtocol.FolderName = "AWEconomy"
EconomyProtocol.Request = "Request"
EconomyProtocol.Push = "Push"

EconomyProtocol.Actions = table.freeze({
    "Snapshot",
    "Quote",
    "BuyVehicle",
    "TradeIn",
    "BuyProperty",
    "SellProperty",
    "UpgradeGarage",
    "BuyModule",
    "BuyPart",
    "SellPart",
    "Repair",
    "Wash",
    "StartEnergy",
    "StopEnergy",
    "ListVehicle",
    "CancelListing",
    "BuyListing",
    "StartMission",
    "AbandonMission",
})

-- Opérations financières : identifiant de demande obligatoire, jamais en mouvement.
EconomyProtocol.Sensitive = table.freeze({
    BuyVehicle = true,
    TradeIn = true,
    BuyProperty = true,
    SellProperty = true,
    UpgradeGarage = true,
    BuyModule = true,
    BuyPart = true,
    SellPart = true,
    Repair = true,
    Wash = true,
    StartEnergy = true,
    ListVehicle = true,
    CancelListing = true,
    BuyListing = true,
})

return table.freeze(EconomyProtocol)
