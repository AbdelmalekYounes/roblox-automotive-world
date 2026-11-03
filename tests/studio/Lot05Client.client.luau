-- Essais CLIENT du lot 0.5 (session « lot05 », 2 joueurs), écrits au lot 0.9 et
-- injectés par le pilote dans le Studio de test uniquement. Chaque client passe
-- par les VRAIS canaux (AWEconomy.Request, AWProgression.Request) comme les
-- panneaux du joueur, et envoie aussi des demandes FALSIFIÉES : le serveur doit
-- tout revalider. Joueur 1 : achats, refus, débit abusif, mise en vente, pièces,
-- carburant, lavage, mission. Joueur 2 : achat concurrent de l'annonce (deux
-- demandes simultanées), vérification du transfert, accès aux biens d'autrui.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local sessionStart = os.clock()
while ReplicatedStorage:GetAttribute("AWTestSession") == nil and os.clock() - sessionStart < 15 do
    task.wait()
end
if ReplicatedStorage:GetAttribute("AWTestSession") ~= "lot05" then
    return
end

local steps = {}
local measures = {}
local function record(name: string, ok: boolean, detail: any)
    table.insert(steps, { name = name, ok = ok, detail = if detail ~= nil then tostring(detail) else nil })
end
local function waitFor(predicate: () -> boolean, timeout: number): boolean
    local start = os.clock()
    while os.clock() - start < timeout do
        if predicate() then
            return true
        end
        task.wait(0.1)
    end
    return predicate()
end

local reportEvent = ReplicatedStorage:WaitForChild("AWTestReport", 30)
local signalEvent = ReplicatedStorage:WaitForChild("AWTestSignal", 30)
local economy = (ReplicatedStorage:WaitForChild("AWEconomy", 30) :: Instance):WaitForChild(
        "Request",
        10
    ) :: RemoteFunction
local progression = (ReplicatedStorage:WaitForChild("AWProgression", 30) :: Instance):WaitForChild(
        "Request",
        10
    ) :: RemoteFunction

local index = 0
waitFor(function()
    index = player:GetAttribute("AWTestIndex") or 0
    return index > 0
end, 30)
local prefix = "lot05.j" .. index .. "."

local function trace(message: string)
    print(string.format("[AW_Test] lot05 j%d %.1f s : %s", index, os.clock() - sessionStart, message))
end
local function signal(name: string)
    signalEvent:FireServer("AW05:" .. name)
end
local function share(key: string, value: string)
    signalEvent:FireServer("AW05D:" .. key .. "=" .. value)
end
local function waitSignal(name: string, timeout: number): boolean
    trace("attente du signal " .. name)
    return waitFor(function()
        return ReplicatedStorage:GetAttribute("AW05_" .. name) == true
    end, timeout)
end

-- Demande économique (identifiant de demande unique ajouté si absent, sauf refus voulu).
local function eco(action: string, payload: any?, noRequestId: boolean?): any
    local data = payload or {}
    if not noRequestId and data.RequestId == nil then
        data.RequestId = HttpService:GenerateGUID(false)
    end
    task.wait(0.55) -- rythme d'un joueur (limiteur : 6 demandes, 2/s)
    local ok, response = pcall(function()
        return economy:InvokeServer(action, data)
    end)
    if not ok or type(response) ~= "table" then
        return { Status = "Error", Error = tostring(response) }
    end
    trace(action .. " → " .. tostring(response.Status) .. " " .. tostring(response.Error))
    return response
end
local function prog(action: string, payload: any?): any
    local data = payload or {}
    data.RequestId = data.RequestId or HttpService:GenerateGUID(false)
    task.wait(0.45)
    local ok, response = pcall(function()
        return progression:InvokeServer(action, data)
    end)
    if not ok or type(response) ~= "table" then
        return { Status = "Error", Error = tostring(response) }
    end
    return response
end
local function snapshot(): any
    local response = eco("Snapshot", {}, true)
    return response.Snapshot or {}
end
local function balance(): number
    local wallet = snapshot().Wallet
    return if wallet then wallet.Balance else -1
end
local function accepted(response: any): boolean
    return response.Status == "Confirmed" or response.Status == "Pending" or response.Status == "Ok"
end
local function describe(response: any): string
    return tostring(response.Status) .. (if response.Error then " / " .. tostring(response.Error) else "")
end
local function root(): BasePart?
    local character = player.Character or player.CharacterAdded:Wait()
    return character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
end
local function walkTo(position: Vector3)
    local part = root()
    if part then
        part.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
        part.AssemblyLinearVelocity = Vector3.zero
    end
    task.wait(1.2) -- réplication de la position au serveur
end
local function countVehicles(snap: any): number
    return #(snap.Vehicles or {})
end

local zone = Workspace:WaitForChild("AutomotiveTestZone", 20) :: Instance
local dealer = zone:WaitForChild("ConcessionEssai", 10) :: BasePart
local station = zone:WaitForChild("StationEssai", 10) :: BasePart
local garage = zone:WaitForChild("GaragePublicEssai", 10) :: BasePart
local entrance = zone:WaitForChild("EntreeProprieteEssai", 10) :: BasePart

local function main()
    waitFor(function()
        local snap = snapshot()
        return snap.State == "Active" and snap.Wallet ~= nil
    end, 40)
    local start = snapshot()
    record(prefix .. "instantane_economie", start.Wallet ~= nil, start.Wallet and start.Wallet.Balance)
    measures["solde_initial_j" .. index] = start.Wallet and start.Wallet.Balance or -1

    if index == 1 then
        -- ===== Demandes falsifiées ou mal formées =====
        local unknown = eco("GiveCredits", { Amount = 1000000 })
        record(prefix .. "action_inconnue_refusee", unknown.Error == "ActionUnknown", describe(unknown))
        local noId = eco("BuyVehicle", { CatalogId = "brio" }, true)
        record(prefix .. "sans_identifiant_refuse", noId.Error == "RequestIdInvalid", describe(noId))
        local shortId = eco("BuyVehicle", { CatalogId = "brio", RequestId = "abc" })
        record(prefix .. "identifiant_court_refuse", shortId.Error == "RequestIdInvalid", describe(shortId))
        local far = eco("BuyVehicle", { CatalogId = "brio" })
        record(prefix .. "achat_a_distance_refuse", far.Error == "NotAtDealer", describe(far))

        -- ===== Achat à la concession, prix forgé ignoré, rejeu sans double débit =====
        walkTo(dealer.Position)
        local before = balance()
        local requestId = HttpService:GenerateGUID(false)
        local buy = eco("BuyVehicle", { CatalogId = "brio", RequestId = requestId, Price = 1 })
        local afterBuy = balance()
        record(
            prefix .. "achat_prix_du_catalogue",
            accepted(buy) and before - afterBuy == 16500,
            describe(buy) .. string.format(", débit %d (catalogue 16 500, prix forgé 1)", before - afterBuy)
        )
        local vehiclesAfterBuy = countVehicles(snapshot())
        local replay = eco("BuyVehicle", { CatalogId = "brio", RequestId = requestId })
        local afterReplay = balance()
        record(
            prefix .. "rejeu_sans_double_debit",
            afterReplay == afterBuy and countVehicles(snapshot()) == vehiclesAfterBuy,
            describe(replay) .. string.format(", solde %d → %d", afterBuy, afterReplay)
        )
        local unknownModel = eco("BuyVehicle", { CatalogId = "supercar-gratuite" })
        record(prefix .. "modele_inconnu_refuse", unknownModel.Error == "CatalogUnknown", describe(unknownModel))
        local tooExpensive = eco("BuyVehicle", { CatalogId = "zenith" })
        record(
            prefix .. "solde_insuffisant_refuse",
            tooExpensive.Status == "Rejected" and balance() == afterReplay,
            describe(tooExpensive)
        )
        local pixel = eco("BuyVehicle", { CatalogId = "pixel" })
        record(prefix .. "second_achat", accepted(pixel), describe(pixel))

        -- ===== Débit abusif : rafale de demandes =====
        local limited = 0
        local results = {}
        for i = 1, 14 do
            task.spawn(function()
                local ok, response = pcall(function()
                    return economy:InvokeServer("Snapshot", {})
                end)
                results[i] = if ok and type(response) == "table" then response.Error else "erreur"
            end)
        end
        waitFor(function()
            return #results >= 14
        end, 10)
        for _, err in results do
            if err == "RateLimited" then
                limited += 1
            end
        end
        record(prefix .. "debit_abusif_limite", limited > 0, limited .. " demande(s) sur 14 refusée(s)")
        task.wait(4) -- recharge du limiteur

        -- ===== Mise en vente : prix invalides, bien d'autrui, puis annonce valide =====
        local snap = snapshot()
        local pixelId, brioId = nil, nil
        for _, vehicle in snap.Vehicles or {} do
            if vehicle.Name == "Pixel" then
                pixelId = vehicle.Id
            elseif vehicle.Name == "Brio" then
                brioId = vehicle.Id
            end
        end
        record(
            prefix .. "vehicules_achetes_presents",
            pixelId ~= nil and brioId ~= nil,
            tostring(pixelId) .. ", " .. tostring(brioId)
        )
        local negative = eco("ListVehicle", { VehicleId = pixelId, Price = -5 })
        record(prefix .. "prix_negatif_refuse", negative.Error == "PriceInvalid", describe(negative))
        local huge = eco("ListVehicle", { VehicleId = pixelId, Price = 1e12 })
        record(prefix .. "prix_demesure_refuse", huge.Error == "PriceInvalid", describe(huge))
        local nan = eco("ListVehicle", { VehicleId = pixelId, Price = 0 / 0 })
        record(prefix .. "prix_nan_refuse", nan.Status == "Rejected", describe(nan))
        local other = ReplicatedStorage:GetAttribute("AW05D_GuestVehicle")
        waitFor(function()
            other = ReplicatedStorage:GetAttribute("AW05D_GuestVehicle")
            return other ~= nil
        end, 60)
        local foreign = eco("ListVehicle", { VehicleId = other, Price = 10000 })
        record(prefix .. "vente_bien_d_autrui_refusee", foreign.Status == "Rejected", describe(foreign))
        local synthetic = snap.Vehicles and snap.Vehicles[1]
        for _, vehicle in snap.Vehicles or {} do
            if vehicle.Id ~= pixelId and vehicle.Id ~= brioId then
                synthetic = vehicle
            end
        end
        local syntheticSale = eco("ListVehicle", { VehicleId = synthetic and synthetic.Id, Price = 10000 })
        record(
            prefix .. "exemplaire_synthetique_invendable",
            syntheticSale.Status == "Rejected",
            describe(syntheticSale)
        )
        local list = eco("ListVehicle", { VehicleId = pixelId, Price = 20000 })
        record(prefix .. "annonce_creee", accepted(list), describe(list))
        local listingId = nil
        waitFor(function()
            for _, listing in snapshot().Listings or {} do
                if listing.Mine then
                    listingId = listing.Id
                end
            end
            return listingId ~= nil
        end, 15)
        local ownBuy = eco("BuyListing", { ListingId = listingId })
        record(
            prefix .. "achat_de_sa_propre_annonce_refuse",
            ownBuy.Status ~= "Completed" and not accepted(ownBuy),
            describe(ownBuy)
        )
        local sellerBefore = balance()
        measures.vendeur_solde_avant_vente = sellerBefore
        share("Listing", tostring(listingId))
        signal("Listed")

        -- ===== Pièces au garage public =====
        walkTo(garage.Position)
        local partBefore = balance()
        local part = eco("BuyPart", { PartId = "TIRE-SPORT" })
        local partAfter = balance()
        record(
            prefix .. "piece_achetee",
            accepted(part) and partAfter < partBefore,
            describe(part) .. string.format(", débit %d", partBefore - partAfter)
        )
        local itemId = nil
        for _, owned in snapshot().OwnedParts or {} do
            if owned.PartId == "TIRE-SPORT" and not owned.Installed and (owned.Resale or 0) > 0 then
                itemId = owned.Id
            end
        end
        local resale = eco("SellPart", { PartItemId = itemId })
        local resaleAfter = balance()
        record(
            prefix .. "piece_revendue_moins_cher",
            accepted(resale) and resaleAfter > partAfter and resaleAfter < partBefore,
            describe(resale) .. string.format(", crédit %d", resaleAfter - partAfter)
        )
        local resaleAgain = eco("SellPart", { PartItemId = itemId })
        record(prefix .. "piece_revendue_une_seule_fois", resaleAgain.Status == "Rejected", describe(resaleAgain))

        -- ===== Carburant et lavage à la station (véhicule personnel sorti) =====
        walkTo(entrance.Position)
        local enter = prog("Enter", {
            OwnerUserId = player.UserId,
            PropertyId = (function()
                for _, property in snap.Properties or {} do
                    if property.Sellable == false then
                        return property.Id
                    end
                end
                return snap.Properties and snap.Properties[1] and snap.Properties[1].Id
            end)(),
        })
        local out = prog("TakeOut", { VehicleId = brioId })
        record(
            prefix .. "sortie_brio",
            out.Status == "Confirmed" or out.Status == "Pending",
            describe(enter) .. " / " .. describe(out)
        )
        task.wait(2)
        signal("MoveToStation")
        local placed = waitSignal("AtStation", 15)
        walkTo(station.Position + Vector3.new(6, 0, 0))
        local fuelBefore = balance()
        local fuel = eco("StartEnergy", {})
        record(prefix .. "plein_demarre", placed and accepted(fuel), describe(fuel))
        waitFor(function()
            return snapshot().Energy == nil
        end, 40)
        local fuelAfter = balance()
        record(prefix .. "plein_facture", fuelAfter < fuelBefore, string.format("débit %d", fuelBefore - fuelAfter))
        local again = eco("StartEnergy", {})
        record(prefix .. "plein_inutile_refuse", again.Status == "Rejected", describe(again))
        local washBefore = balance()
        local wash = eco("Wash", {})
        record(
            prefix .. "lavage",
            accepted(wash) or wash.Status == "Rejected",
            describe(wash) .. string.format(", débit %d", washBefore - balance())
        )
        local repair = eco("Repair", {})
        record(prefix .. "reparation_sans_degat", repair.Status == "Rejected" or accepted(repair), describe(repair))

        -- ===== Mission : démarrage, aucune fin falsifiable, abandon sans paiement =====
        local missionBefore = balance()
        local mission = eco("StartMission", { Job = "Delivery" })
        record(prefix .. "mission_demarree", accepted(mission), describe(mission))
        local fake = eco("CompleteMission", { Reward = 999999 })
        record(prefix .. "fin_de_mission_falsifiee_refusee", fake.Error == "ActionUnknown", describe(fake))
        local abandon = eco("AbandonMission", {})
        record(
            prefix .. "abandon_sans_paiement",
            balance() <= missionBefore,
            describe(abandon) .. string.format(", solde %d → %d", missionBefore, balance())
        )

        -- ===== Vente conclue (joueur 2) : crédit du vendeur moins la commission =====
        local sold = waitSignal("Bought", 300)
        local sellerAfter = 0
        local credited = waitFor(function()
            sellerAfter = balance()
            return sellerAfter > fuelAfter
        end, 30)
        record(
            prefix .. "vendeur_credite",
            sold and credited,
            string.format("solde %d (après le plein : %d), vente signalée %s", sellerAfter, fuelAfter, tostring(sold))
        )
        local stillMine = false
        for _, vehicle in snapshot().Vehicles or {} do
            if vehicle.Id == pixelId then
                stillMine = true
            end
        end
        record(prefix .. "vehicule_vendu_retire", not stillMine)
        signal("SellerDone")
    else
        -- ===== Joueur 2 : identifiant d'un bien à lui, puis achat concurrent =====
        local mine = snapshot()
        local vehicle = mine.Vehicles and mine.Vehicles[1]
        share("GuestVehicle", if vehicle then vehicle.Id else "aucun")
        waitSignal("Listed", 240)
        local listingId = ReplicatedStorage:GetAttribute("AW05D_Listing")
        local before = balance()
        local count = countVehicles(snapshot())
        -- Deux demandes d'achat simultanées (identifiants différents) : une seule doit aboutir.
        local outcomes = {}
        for i = 1, 2 do
            task.spawn(function()
                local ok, response = pcall(function()
                    return economy:InvokeServer(
                        "BuyListing",
                        { ListingId = listingId, RequestId = HttpService:GenerateGUID(false) }
                    )
                end)
                outcomes[i] = if ok and type(response) == "table" then describe(response) else "erreur"
            end)
        end
        waitFor(function()
            return outcomes[1] ~= nil and outcomes[2] ~= nil
        end, 30)
        local owned = count
        local transferred = waitFor(function()
            local snap = snapshot()
            owned = countVehicles(snap)
            return owned == count + 1 and (snap.PendingTransfers or 0) == 0
        end, 60)
        task.wait(3)
        local final = snapshot()
        record(
            prefix .. "achat_concurrent_une_seule_fois",
            transferred and countVehicles(final) == count + 1 and before - final.Wallet.Balance == 20000,
            string.format(
                "%s | %s ; débit %d, %d → %d véhicule(s)",
                tostring(outcomes[1]),
                tostring(outcomes[2]),
                before - (final.Wallet and final.Wallet.Balance or before),
                count,
                countVehicles(final)
            )
        )
        local gone = true
        for _, listing in final.Listings or {} do
            if listing.Id == listingId then
                gone = false
            end
        end
        record(prefix .. "annonce_retiree_apres_vente", gone)
        local again = eco("BuyListing", { ListingId = listingId })
        record(
            prefix .. "annonce_vendue_non_rachetable",
            not accepted(again) or again.Status == "Rejected",
            describe(again)
        )
        signal("Bought")
        waitSignal("SellerDone", 180)
    end
end

trace("début du test")
local ran, failure = xpcall(main, debug.traceback)
if not ran then
    record(prefix .. "script_sans_plantage", false, failure)
end
trace(if ran then "fin du test" else "plantage : " .. tostring(failure))
reportEvent:FireServer({ vehicle = "lot05-j" .. index, steps = steps, measures = measures })
