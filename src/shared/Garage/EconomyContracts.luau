--!strict
--[[
    Contrats des opérations économiques FUTURES (lot 0.5). Ce module ne crée
    AUCUNE monnaie et ne déclenche aucune acquisition : il fixe les ratios
    approuvés par le cahier des charges et calcule des DEVIS indicatifs à
    partir d'un prix fourni. Toutes les opérations sont déclarées
    indisponibles tant que le portefeuille et les transactions multiprofils
    (AUD-TX-01) ne sont pas implémentés.
]]

local EconomyContracts = {}

-- Ratios approuvés (§4.1, §5.3).
EconomyContracts.Ratios = table.freeze({
    DealerTradeIn = 0.6, -- reprise concession ≈ 60 % du prix neuf, ajustée à l'état
    DetachedPartResale = 0.75, -- pièces détachées éligibles
    PropertyResale = 0.7, -- propriétés payantes
    ExtensionResale = 0.4, -- agrandissements
    ModuleResale = 0.6, -- modules de garage
    PlayerMarketCommission = 0.05, -- ventes entre joueurs
})

export type Operation =
    "BuyVehicle"
    | "SellVehicleToDealer"
    | "PlayerMarketSale"
    | "BuyProperty"
    | "SellProperty"
    | "BuyPart"
    | "SellPart"
    | "InstallGarageModule"
    | "UpgradeGarage"
    | "Repair"
    | "PaidModification"

local OPERATIONS: { Operation } = {
    "BuyVehicle",
    "SellVehicleToDealer",
    "PlayerMarketSale",
    "BuyProperty",
    "SellProperty",
    "BuyPart",
    "SellPart",
    "InstallGarageModule",
    "UpgradeGarage",
    "Repair",
    "PaidModification",
}
EconomyContracts.Operations = table.freeze(OPERATIONS)

-- Aucune opération payante n'est disponible avant le lot 0.5.
function EconomyContracts.available(_operation: Operation): boolean
    return false
end

--[[
    Devis de reprise concession : base 60 % du prix neuf, ajustée à l'état
    (0 = épave, 1 = parfait). Les pièces installées ne donnent lieu à aucun
    paiement séparé (SCN-06). L'ajustement exact sera calibré au lot 0.5 ;
    ici : linéaire entre 50 % et 100 % de la base.
]]
function EconomyContracts.dealerTradeIn(newPrice: number, condition: number): number
    local base = newPrice * EconomyContracts.Ratios.DealerTradeIn
    return math.floor(base * (0.5 + 0.5 * math.clamp(condition, 0, 1)))
end

function EconomyContracts.detachedPartResale(paidPrice: number, eligible: boolean): number
    return if eligible then math.floor(paidPrice * EconomyContracts.Ratios.DetachedPartResale) else 0
end

-- Revente immobilière : seuls les montants réellement payés sont éligibles.
function EconomyContracts.propertyResale(paidPrice: number, paidExtensions: number, paidModules: number): number
    local ratios = EconomyContracts.Ratios
    return math.floor(
        paidPrice * ratios.PropertyResale + paidExtensions * ratios.ExtensionResale + paidModules * ratios.ModuleResale
    )
end

-- Montant net perçu par le vendeur sur le marché entre joueurs.
function EconomyContracts.playerSaleNet(price: number): number
    return math.floor(price * (1 - EconomyContracts.Ratios.PlayerMarketCommission))
end

return table.freeze(EconomyContracts)
