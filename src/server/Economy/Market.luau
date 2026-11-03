--!strict
--[[
    Marché d'occasion entre joueurs et protocole de transfert MULTIPROFIL
    (lot 0.5, AUD-TX-01, AUD-ECO-02, SCN-05). Logique PURE : stockage (clés
    « Listing_ », « Tx_ », « Inbox_ », index), accès aux profils
    (ProfileAccess) et horloge sont injectés.

    Deux écritures sur deux clés ne sont JAMAIS atomiques ensemble. Le transfert
    est donc un enregistrement de transaction DURABLE et distinct, qui avance
    par étapes idempotentes, chacune rendue durable avant la suivante :

      Prepared ──verrou annonce──▶ Locked ──fonds réservés (acheteur)──▶ Reserved
      Reserved ──véhicule retiré, vendeur payé (prix − 5 %)──▶ SellerApplied
      SellerApplied ──véhicule remis, réservation consommée (acheteur)──▶ Committed
      Locked ──fonds insuffisants──▶ Aborted (annonce déverrouillée)
      Reserved ──vente impossible (véhicule absent, non réservé)──▶ Compensating
      Compensating ──fonds restitués (acheteur)──▶ Compensated

    - Le véhicule quitte le vendeur AVANT d'apparaître chez l'acheteur ; entre
      les deux, sa copie est dans l'enregistrement de transaction (séquestre).
    - Conservation : l'acheteur engage P ; le vendeur reçoit P − commission ; la
      commission (5 %) est la seule destruction de crédits, explicite.
    - Chaque étape est rejouable (identifiant « T:<tx>:<étape> » dans le
      profil, doublé de Profile.Applied / Profile.Transfers) : une reprise après
      interruption ne double jamais un paiement ni un véhicule.
    - Profil verrouillé ailleurs → étape différée, transaction inscrite dans la
      boîte de réception du joueur ; tout serveur peut reprendre (`resume`).
    - Une transaction bloquée trop longtemps est marquée NeedsRecovery (elle
      reste reprenable) ; son enregistrement n'est jamais supprimé.
]]

local Persistence = script.Parent.Parent.Persistence
local ProfileSchema = require(Persistence.ProfileSchema)
local ProfileMigration = require(Persistence.ProfileMigration)
local Progression = script.Parent.Parent.Progression
local VehicleOwnership = require(Progression.VehicleOwnership)
local Wallet = require(script.Parent.Wallet)
local Commerce = require(script.Parent.Commerce)

local Shared = script.Parent.Parent.Parent.Parent.ReplicatedStorage.Shared
local EconomyCatalog = require(Shared.Economy.EconomyCatalog)
local EconomyContracts = require(Shared.Garage.EconomyContracts)

local Market = {}

Market.FinalStates = table.freeze({ Committed = true, Aborted = true, Compensated = true })
Market.RecoveryAfterS = 600 -- au-delà, transaction bloquée signalée NeedsRecovery
Market.MaxIndex = 500

export type Context = {
    Repository: any, -- interface ProfileRepository (clés hors profils)
    Profiles: any, -- ProfileAccess
    Clock: () -> number,
    Log: any?,
}

local function log(ctx: Context, level: string, event: string, fields: { [string]: any })
    if ctx.Log then
        ctx.Log:write(level, event, fields)
    end
end

local function read(ctx: Context, key: string): (boolean, any)
    local result = ctx.Repository:read(key)
    return result.Ok, result.Value
end

-- Liste bornée d'identifiants sous une clé (index du marché, boîtes, ouvertes).
local function listAdd(ctx: Context, key: string, id: string)
    ctx.Repository:update(key, function(old: any): any
        local list = if type(old) == "table" then old else {}
        if table.find(list, id) then
            return nil
        end
        table.insert(list, id)
        while #list > Market.MaxIndex do
            table.remove(list, 1)
        end
        return list
    end)
end

local function listRemove(ctx: Context, key: string, id: string)
    ctx.Repository:update(key, function(old: any): any
        if type(old) ~= "table" then
            return nil
        end
        local index = table.find(old, id)
        if index == nil then
            return nil
        end
        table.remove(old, index)
        return old
    end)
end

-- Copie TRANSFÉRABLE d'un véhicule réservé pour cette annonce (vendeur).
local function escrowCopy(profile: ProfileSchema.Profile, vehicle: ProfileSchema.Vehicle): any
    local copy = ProfileMigration.deepCopy(vehicle)
    copy.Configurations = {}
    for _, configuration in vehicle.Configurations do
        if VehicleOwnership.realizable(profile, vehicle, configuration) then
            table.insert(copy.Configurations, ProfileMigration.deepCopy(configuration))
        end
    end
    local parts = {}
    for slot, partId in vehicle.InstalledParts do
        parts[slot] = ProfileMigration.deepCopy(profile.Parts[partId])
    end
    copy.Reservation = nil
    copy.Storage = { State = "Stored" }
    return { Vehicle = copy, Parts = parts }
end

-- ============================== Annonces ==============================

function Market.listingKey(listingId: string): string
    return "Listing_" .. listingId
end

function Market.txKey(txId: string): string
    return "Tx_" .. txId
end

function Market.inboxKey(userId: number): string
    return "Inbox_" .. tostring(userId)
end

--[[
    Mise en vente : 1) réservation durable du véhicule dans le profil du vendeur
    (une seule annonce par exemplaire, véhicule bloqué pour toute opération
    incompatible) ; 2) création de l'annonce. Rejouable.
]]
function Market.createListing(
    ctx: Context,
    sellerUserId: number,
    vehicleId: any,
    price: any,
    requestId: string
): (string, any)
    local market = EconomyCatalog.Market
    if not Wallet.validAmount(price) or price < market.MinPrice or price > market.MaxPrice then
        return "Rejected", "PriceInvalid"
    end
    local now = ctx.Clock()
    local listingId = "L-" .. tostring(sellerUserId) .. "-" .. requestId
    local summary: any = nil
    local outcome = ctx.Profiles:apply(
        sellerUserId,
        "L:" .. listingId .. ":reserve",
        "ListVehicle",
        function(profile): (boolean, any)
            local vehicle = VehicleOwnership.get(profile, vehicleId)
            if vehicle == nil then
                return false, "VehicleNotOwned"
            end
            local problem = Commerce.transferable(vehicle, now)
            if problem then
                return false, problem
            end
            local active = 0
            for _, other in profile.Vehicles do
                if other.Reservation and other.Reservation.Kind == "Listing" and other.Reservation.ExpiresAt > now then
                    active += 1
                end
            end
            if active >= market.MaxActiveListingsPerSeller then
                return false, "ListingLimit"
            end
            if vehicle.Storage.State == "Displayed" then
                vehicle.Storage = { State = "Stored" }
            end
            vehicle.Reservation = {
                Kind = "Listing",
                TxId = listingId,
                Since = now,
                ExpiresAt = now + market.ListingDurationS,
            }
            local parts = {}
            for slot, partId in vehicle.InstalledParts do
                parts[slot] = profile.Parts[partId].PartId
            end
            return true,
                {
                    ModelId = vehicle.ModelId,
                    OdometerKm = vehicle.OdometerKm,
                    Condition = Commerce.condition(vehicle),
                    Parts = parts,
                    Configurations = #vehicle.Configurations,
                    ExpiresAt = now + market.ListingDurationS,
                }
        end
    )
    -- « Pending » : réservation APPLIQUÉE au profil, écriture différée (budget par clé).
    -- L'annonce doit alors exister aussi (lot 0.9 : sinon l'exemplaire restait réservé
    -- pour une annonce introuvable jusqu'à l'échéance). L'achat revérifie la réservation
    -- du vendeur à chaque étape (SaleNotReserved, compensation).
    if outcome.Status ~= "Confirmed" and outcome.Status ~= "Duplicate" and outcome.Status ~= "Pending" then
        return outcome.Status, outcome.Error
    end
    summary = outcome.Result
    ctx.Repository:update(Market.listingKey(listingId), function(old: any): any
        if old ~= nil then
            return nil
        end
        return {
            Id = listingId,
            Seller = sellerUserId,
            VehicleId = vehicleId,
            Price = price,
            Status = "Active",
            TxId = nil,
            CreatedAt = now,
            ExpiresAt = summary.ExpiresAt,
            Summary = summary,
        }
    end)
    listAdd(ctx, "Market_Index", listingId)
    log(ctx, "Info", "ListingCreated", { Listing = listingId, Price = price })
    return "Confirmed", { ListingId = listingId }
end

-- Annulation par le vendeur (refusée si un achat est en cours).
function Market.cancelListing(ctx: Context, sellerUserId: number, listingId: string): (string, any)
    local refused: string? = nil
    local result = ctx.Repository:update(Market.listingKey(listingId), function(old: any): any
        if type(old) ~= "table" or old.Seller ~= sellerUserId then
            refused = "ListingUnknown"
            return nil
        end
        if old.Status == "Locked" then
            refused = "ListingLocked"
            return nil
        end
        if old.Status ~= "Active" then
            refused = "ListingClosed"
            return nil
        end
        old.Status = "Cancelled"
        return old
    end)
    if refused then
        return "Rejected", refused
    end
    if result.Status ~= "Ok" then
        return "Unavailable", "StorageUnavailable"
    end
    local outcome = ctx.Profiles:apply(
        sellerUserId,
        "L:" .. listingId .. ":cancel",
        "CancelListing",
        function(profile): (boolean, any)
            for _, vehicle in profile.Vehicles do
                if vehicle.Reservation and vehicle.Reservation.TxId == listingId then
                    vehicle.Reservation = nil
                end
            end
            return true, { ListingId = listingId }
        end
    )
    listRemove(ctx, "Market_Index", listingId)
    return outcome.Status, outcome.Result
end

-- Annonces actives (lecture seule, bornée).
function Market.search(ctx: Context, limit: number?): { any }
    local ok, index = read(ctx, "Market_Index")
    local listings = {}
    if not ok or type(index) ~= "table" then
        return listings
    end
    local now = ctx.Clock()
    for i = #index, 1, -1 do
        local found, listing = read(ctx, Market.listingKey(index[i]))
        if found and type(listing) == "table" and listing.Status == "Active" and listing.ExpiresAt > now then
            table.insert(listings, listing)
            if #listings >= (limit or 50) then
                break
            end
        end
    end
    return listings
end

-- ============================== Transfert ==============================

local function setTx(ctx: Context, txId: string, mutate: (any) -> boolean): (boolean, any)
    local value: any = nil
    local result = ctx.Repository:update(Market.txKey(txId), function(old: any): any
        if type(old) ~= "table" then
            return nil
        end
        if not mutate(old) then
            return nil
        end
        old.UpdatedAt = ctx.Clock()
        value = old
        return old
    end)
    return result.Status == "Ok", value
end

local function transition(ctx: Context, tx: any, state: string, note: string?, extra: ((any) -> ())?): boolean
    local ok = setTx(ctx, tx.Id, function(record)
        if record.State ~= tx.State then
            return false -- un autre serveur a déjà avancé : relire
        end
        record.State = state
        record.NeedsRecovery = nil
        table.insert(record.Log, { At = ctx.Clock(), State = state, Note = note })
        if extra then
            extra(record)
        end
        return true
    end)
    if ok then
        log(ctx, "Info", "TxState", { Tx = tx.Id, State = state, Note = note or "" })
        if Market.FinalStates[state] then
            listRemove(ctx, "Tx_Open", tx.Id)
        end
    end
    return ok
end

local function blocked(ctx: Context, tx: any, userId: number, reason: string)
    -- Profil indisponible ou verrouillé ailleurs : boîte de réception du joueur.
    listAdd(ctx, Market.inboxKey(userId), tx.Id)
    local now = ctx.Clock()
    if now - tx.CreatedAt > Market.RecoveryAfterS and not tx.NeedsRecovery then
        setTx(ctx, tx.Id, function(record)
            record.NeedsRecovery = true
            return true
        end)
        log(ctx, "Warn", "TxNeedsRecovery", { Tx = tx.Id, State = tx.State, Reason = reason })
    end
end

local function durable(outcome: any): boolean
    return outcome.Status == "Confirmed" or outcome.Status == "Duplicate"
end

-- Une étape du protocole ; renvoie l'état atteint ou « Blocked ».
function Market.step(ctx: Context, txId: string): string
    local ok, tx = read(ctx, Market.txKey(txId))
    if not ok or type(tx) ~= "table" then
        return "Unknown"
    end
    local state = tx.State
    if Market.FinalStates[state] then
        return state
    end
    local now = ctx.Clock()

    if state == "Prepared" then
        local refused: string? = nil
        local result = ctx.Repository:update(Market.listingKey(tx.ListingId), function(old: any): any
            if type(old) ~= "table" then
                refused = "ListingUnknown"
                return nil
            end
            if old.Status == "Locked" and old.TxId == tx.Id then
                return nil -- déjà verrouillée par cette transaction
            end
            if old.Status ~= "Active" or old.ExpiresAt <= now then
                refused = "ListingUnavailable"
                return nil
            end
            if old.Seller == tx.Buyer then
                refused = "ListingOwnVehicle"
                return nil
            end
            old.Status = "Locked"
            old.TxId = tx.Id
            return old
        end)
        if refused then
            transition(ctx, tx, "Aborted", refused)
            return "Aborted"
        end
        if result.Status ~= "Ok" and result.Status ~= "Cancelled" then
            return "Blocked"
        end
        transition(ctx, tx, "Locked")
        return "Locked"
    elseif state == "Locked" then
        local outcome = ctx.Profiles:apply(
            tx.Buyer,
            "T:" .. tx.Id .. ":reserve",
            "MarketReserve",
            function(profile): (boolean, any)
                if profile.Transfers[tx.Id] then
                    return true, "AlreadyReserved"
                end
                local reserved, err = Wallet.reserve(profile, tx.Price, "MarketReserve", tx.Id, now)
                if not reserved then
                    return false, err :: any
                end
                profile.Transfers[tx.Id] =
                    { Role = "Buyer", State = "Reserved", Amount = tx.Price, At = now, Ref = tx.ListingId }
                return true, "Reserved"
            end
        )
        if durable(outcome) then
            transition(ctx, tx, "Reserved")
            return "Reserved"
        elseif outcome.Status == "Rejected" then
            ctx.Repository:update(Market.listingKey(tx.ListingId), function(old: any): any
                if type(old) == "table" and old.TxId == tx.Id and old.Status == "Locked" then
                    old.Status = "Active"
                    old.TxId = nil
                    return old
                end
                return nil
            end)
            transition(ctx, tx, "Aborted", outcome.Error)
            return "Aborted"
        end
        blocked(ctx, tx, tx.Buyer, outcome.Status)
        return "Blocked"
    elseif state == "Reserved" then
        local outcome = ctx.Profiles:apply(
            tx.Seller,
            "T:" .. tx.Id .. ":sell",
            "MarketSell",
            function(profile): (boolean, any)
                local applied = profile.Transfers[tx.Id]
                if applied and applied.Role == "Seller" then
                    return true, (applied :: any).Payload
                end
                local vehicle = profile.Vehicles[tx.VehicleId]
                if vehicle == nil then
                    return false, "SaleVehicleMissing"
                end
                local reservation = vehicle.Reservation
                if reservation == nil or reservation.Kind ~= "Listing" or reservation.TxId ~= tx.ListingId then
                    return false, "SaleNotReserved"
                end
                if vehicle.Untransferable or vehicle.Synthetic or vehicle.Storage.State == "Out" then
                    return false, "SaleNotTransferable"
                end
                local payload = escrowCopy(profile, vehicle)
                Commerce.removeVehicle(profile, vehicle)
                local net = tx.Price - tx.Fee
                if net > 0 then
                    local credited, err = Wallet.credit(profile, net, "MarketSale", tx.Id, now)
                    if not credited then
                        return false, err
                    end
                end
                profile.Applied[tx.Id] = now
                local entry: any = { Role = "Seller", State = "Applied", Amount = net, At = now, Ref = tx.ListingId }
                entry.Payload = payload
                profile.Transfers[tx.Id] = entry
                return true, payload
            end
        )
        if durable(outcome) then
            transition(ctx, tx, "SellerApplied", nil, function(record)
                record.Payload = outcome.Result
            end)
            return "SellerApplied"
        elseif outcome.Status == "Rejected" then
            transition(ctx, tx, "Compensating", outcome.Error)
            return "Compensating"
        end
        blocked(ctx, tx, tx.Seller, outcome.Status)
        return "Blocked"
    elseif state == "SellerApplied" then
        local payload = tx.Payload
        local outcome = ctx.Profiles:apply(
            tx.Buyer,
            "T:" .. tx.Id .. ":receive",
            "MarketReceive",
            function(profile): (boolean, any)
                local entry = profile.Transfers[tx.Id]
                if entry and entry.State == "Done" then
                    return true, tx.VehicleId
                end
                if entry == nil or entry.State ~= "Reserved" then
                    return false, "TransferStateInvalid"
                end
                local consumed, err = Wallet.consume(profile, tx.Price, "MarketPurchase", tx.Id, now)
                if not consumed then
                    return false, err
                end
                local vehicle = ProfileMigration.deepCopy(payload.Vehicle)
                vehicle.OwnerUserId = profile.UserId
                vehicle.Origin = "Transfer"
                vehicle.AcquiredAt = now
                vehicle.PaidPrice = tx.Price
                vehicle.Storage = { State = "Stored" }
                vehicle.Reservation = nil
                for _, part in payload.Parts do
                    profile.Parts[part.Id] = ProfileMigration.deepCopy(part)
                end
                profile.Vehicles[vehicle.Id] = vehicle
                entry.State = "Done"
                profile.Applied[tx.Id] = now
                return true, vehicle.Id
            end
        )
        if durable(outcome) then
            transition(ctx, tx, "Committed")
            ctx.Repository:update(Market.listingKey(tx.ListingId), function(old: any): any
                if type(old) == "table" then
                    old.Status = "Sold"
                    return old
                end
                return nil
            end)
            listRemove(ctx, "Market_Index", tx.ListingId)
            -- Nettoyage du séquestre chez le vendeur (sans effet sur l'argent).
            ctx.Profiles:apply(
                tx.Seller,
                "T:" .. tx.Id .. ":cleanup",
                "MarketCleanup",
                function(profile): (boolean, any)
                    local entry = profile.Transfers[tx.Id]
                    if entry then
                        profile.Transfers[tx.Id] = nil
                    end
                    return true, nil
                end
            )
            return "Committed"
        elseif outcome.Status == "Rejected" then
            -- Ne devrait pas arriver : l'acheteur a des fonds réservés. Le
            -- véhicule reste dans le séquestre ; reprise manuelle requise.
            setTx(ctx, tx.Id, function(record)
                record.NeedsRecovery = true
                return true
            end)
            log(ctx, "Error", "TxBuyerRejected", { Tx = tx.Id, Error = outcome.Error or "" })
            return "Blocked"
        end
        blocked(ctx, tx, tx.Buyer, outcome.Status)
        return "Blocked"
    elseif state == "Compensating" then
        local outcome = ctx.Profiles:apply(
            tx.Buyer,
            "T:" .. tx.Id .. ":refund",
            "MarketRefund",
            function(profile): (boolean, any)
                local entry = profile.Transfers[tx.Id]
                if entry == nil or entry.State == "Refunded" then
                    return true, "NothingToRefund"
                end
                local released, err = Wallet.release(profile, entry.Amount, "MarketRefund", tx.Id, now)
                if not released then
                    return false, err :: any
                end
                entry.State = "Refunded"
                return true, "Refunded"
            end
        )
        if durable(outcome) then
            ctx.Repository:update(Market.listingKey(tx.ListingId), function(old: any): any
                if type(old) == "table" then
                    old.Status = "Cancelled"
                    return old
                end
                return nil
            end)
            listRemove(ctx, "Market_Index", tx.ListingId)
            transition(ctx, tx, "Compensated")
            return "Compensated"
        end
        blocked(ctx, tx, tx.Buyer, outcome.Status)
        return "Blocked"
    end
    return "Blocked"
end

-- Avance autant que possible (jusqu'à un état final ou un blocage).
function Market.resume(ctx: Context, txId: string): string
    local state = "Unknown"
    for _ = 1, 8 do
        state = Market.step(ctx, txId)
        if Market.FinalStates[state] or state == "Blocked" or state == "Unknown" then
            break
        end
    end
    return state
end

--[[
    Achat d'une annonce. Identifiant de transaction dérivé de la demande de
    l'acheteur : un double clic ou une reprise retrouvent la MÊME transaction.
]]
function Market.purchase(ctx: Context, buyerUserId: number, listingId: any, requestId: string): (string, any)
    if type(listingId) ~= "string" then
        return "Rejected", "ListingUnknown"
    end
    local okListing, listing = read(ctx, Market.listingKey(listingId))
    if not okListing then
        return "Unavailable", "StorageUnavailable"
    end
    if type(listing) ~= "table" then
        return "Rejected", "ListingUnknown"
    end
    local txId = "MS-" .. tostring(buyerUserId) .. "-" .. requestId
    local now = ctx.Clock()
    local fee = math.floor(listing.Price * EconomyContracts.Ratios.PlayerMarketCommission + 0.5)
    local created = ctx.Repository:update(Market.txKey(txId), function(old: any): any
        if old ~= nil then
            return nil -- transaction déjà créée : on la reprend
        end
        return {
            Id = txId,
            Kind = "MarketSale",
            State = "Prepared",
            ListingId = listingId,
            Buyer = buyerUserId,
            Seller = listing.Seller,
            VehicleId = listing.VehicleId,
            Price = listing.Price,
            Fee = fee,
            CreatedAt = now,
            UpdatedAt = now,
            Log = { { At = now, State = "Prepared" } },
        }
    end)
    if created.Status == "Failed" or created.Status == "Uncertain" then
        -- Création peut-être perdue : la relecture de `resume` tranchera.
        log(ctx, "Warn", "TxCreateUncertain", { Tx = txId })
    end
    listAdd(ctx, "Tx_Open", txId)
    local state = Market.resume(ctx, txId)
    return state, { TxId = txId }
end

--[[
    Bornage du profil (au chargement) : identifiants de transferts appliqués et
    entrées terminées plus anciens que la rétention (30 jours) retirés. Une
    entrée encore en cours (fonds réservés, séquestre) n'est jamais retirée.
]]
function Market.prune(profile: ProfileSchema.Profile, now: number): boolean
    local changed = false
    local retention = ProfileSchema.AppliedRetentionS
    for txId, at in profile.Applied do
        if now - at > retention then
            profile.Applied[txId] = nil
            changed = true
        end
    end
    for txId, entry in profile.Transfers do
        local finished = entry.State == "Done" or entry.State == "Refunded"
        if finished and now - entry.At > retention then
            profile.Transfers[txId] = nil
            changed = true
        end
    end
    return changed
end

-- Transactions en attente pour un joueur (boîte de réception), à reprendre.
function Market.processInbox(ctx: Context, userId: number): { [string]: string }
    local ok, inbox = read(ctx, Market.inboxKey(userId))
    local results = {}
    if not ok or type(inbox) ~= "table" then
        return results
    end
    for _, txId in inbox do
        local state = Market.resume(ctx, txId)
        results[txId] = state
        if Market.FinalStates[state] or state == "Unknown" then
            listRemove(ctx, Market.inboxKey(userId), txId)
        end
    end
    return results
end

-- Balayage des transactions ouvertes (tout serveur, périodiquement).
function Market.sweep(ctx: Context, limit: number): { [string]: string }
    local ok, open = read(ctx, "Tx_Open")
    local results = {}
    if not ok or type(open) ~= "table" then
        return results
    end
    for i = 1, math.min(#open, limit) do
        results[open[i]] = Market.resume(ctx, open[i])
    end
    return results
end

return table.freeze(Market)
