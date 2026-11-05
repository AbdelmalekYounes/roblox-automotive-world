--!strict
--[[
    Portefeuille PUR (lot 0.5) : crédits entiers, jamais négatifs, mouvements
    tracés dans un historique borné.

    Ces fonctions ne sont qu'une partie d'une MUTATION de profil : elles ne
    rendent rien durable par elles-mêmes. Elles sont toujours appelées dans une
    transaction identifiée (ProfileSession.commit), qui garantit
    l'idempotence et la confirmation par écriture durable.

    - credit : gain légitime (mission, vente) ;
    - debit : paiement immédiat (achat dans une seule transaction) ;
    - reserve / release / consume : fonds engagés dans une opération en
      plusieurs temps (transfert entre joueurs, service progressif) ; les fonds
      réservés ne sont ni dépensables ni perdus en cas d'interruption.
]]

local Persistence = script.Parent.Parent.Persistence
local ProfileSchema = require(Persistence.ProfileSchema)

local Wallet = {}

-- Bornes : aucun montant négatif, infini, NaN, fractionnaire ou démesuré.
Wallet.MaxAmount = 10_000_000
Wallet.MaxBalance = 2_000_000_000

function Wallet.validAmount(amount: any): boolean
    return type(amount) == "number"
        and amount == amount
        and amount == math.floor(amount)
        and amount > 0
        and amount <= Wallet.MaxAmount
end

local function log(profile: ProfileSchema.Profile, kind: string, amount: number, ref: string, now: number)
    table.insert(profile.Ledger, {
        At = now,
        Kind = kind,
        Amount = amount,
        Balance = profile.Wallet.Balance,
        Ref = string.sub(ref, 1, 64),
    })
    while #profile.Ledger > ProfileSchema.MaxLedger do
        table.remove(profile.Ledger, 1)
    end
end

function Wallet.credit(
    profile: ProfileSchema.Profile,
    amount: number,
    kind: string,
    ref: string,
    now: number
): (boolean, string?)
    if not Wallet.validAmount(amount) then
        return false, "AmountInvalid"
    end
    local wallet = profile.Wallet
    if wallet.Balance + amount > Wallet.MaxBalance then
        return false, "BalanceLimit"
    end
    wallet.Balance += amount
    wallet.Earned += amount
    log(profile, kind, amount, ref, now)
    return true, nil
end

function Wallet.debit(
    profile: ProfileSchema.Profile,
    amount: number,
    kind: string,
    ref: string,
    now: number
): (boolean, string?)
    if not Wallet.validAmount(amount) then
        return false, "AmountInvalid"
    end
    local wallet = profile.Wallet
    if wallet.Balance < amount then
        return false, "InsufficientFunds"
    end
    wallet.Balance -= amount
    wallet.Spent += amount
    log(profile, kind, -amount, ref, now)
    return true, nil
end

-- Engage des fonds (disponible → réservé).
function Wallet.reserve(
    profile: ProfileSchema.Profile,
    amount: number,
    kind: string,
    ref: string,
    now: number
): (boolean, string?)
    if not Wallet.validAmount(amount) then
        return false, "AmountInvalid"
    end
    local wallet = profile.Wallet
    if wallet.Balance < amount then
        return false, "InsufficientFunds"
    end
    wallet.Balance -= amount
    wallet.Reserved += amount
    log(profile, kind, -amount, ref, now)
    return true, nil
end

-- Restitue des fonds réservés (réservé → disponible).
function Wallet.release(
    profile: ProfileSchema.Profile,
    amount: number,
    kind: string,
    ref: string,
    now: number
): (boolean, string?)
    if amount == 0 then
        return true, nil
    end
    if not Wallet.validAmount(amount) or profile.Wallet.Reserved < amount then
        return false, "ReservedInvalid"
    end
    profile.Wallet.Reserved -= amount
    profile.Wallet.Balance += amount
    log(profile, kind, amount, ref, now)
    return true, nil
end

-- Dépense des fonds réservés (réservé → dépensé).
function Wallet.consume(
    profile: ProfileSchema.Profile,
    amount: number,
    kind: string,
    ref: string,
    now: number
): (boolean, string?)
    if amount == 0 then
        return true, nil
    end
    if not Wallet.validAmount(amount) or profile.Wallet.Reserved < amount then
        return false, "ReservedInvalid"
    end
    profile.Wallet.Reserved -= amount
    profile.Wallet.Spent += amount
    log(profile, kind, 0, ref, now)
    return true, nil
end

return table.freeze(Wallet)
