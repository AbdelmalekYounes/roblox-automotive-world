-- Essais CLIENT du lot 0.4 (session « lot04 », 2 joueurs), injectés par le
-- pilote dans le Studio de test uniquement. Chaque client passe par le VRAI
-- canal de progression (RemoteFunction AWProgression.Request) comme le panneau
-- du joueur : le serveur revalide tout. Le joueur 1 déroule le parcours
-- propriétaire ; le joueur 2 joue l'invité (refus de conduite, visite,
-- révocation). Les déplacements à pied sont des repositionnements du
-- personnage par le client de test (il possède son personnage).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local sessionStart = os.clock()
while ReplicatedStorage:GetAttribute("AWTestSession") == nil and os.clock() - sessionStart < 15 do
    task.wait()
end
if ReplicatedStorage:GetAttribute("AWTestSession") ~= "lot04" then
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
local folder = ReplicatedStorage:WaitForChild("AWProgression", 30)
local request = folder:WaitForChild("Request", 10) :: RemoteFunction

local index = 0
waitFor(function()
    index = player:GetAttribute("AWTestIndex") or 0
    return index > 0
end, 30)
local prefix = "lot04.j" .. index .. "."

local function signal(name: string)
    signalEvent:FireServer("AW04:" .. name)
end
local function waitSignal(name: string, timeout: number): boolean
    return waitFor(function()
        return ReplicatedStorage:GetAttribute("AW04_" .. name) == true
    end, timeout)
end

local SENSITIVE = {
    Display = true,
    Store = true,
    TakeOut = true,
    Return = true,
    SetTuning = true,
    SetCosmetics = true,
    SetPart = true,
    SaveConfig = true,
    DeleteConfig = true,
    ApplyConfig = true,
    Invite = true,
    RevokeInvite = true,
}

local snapshot: any = nil
local function call(action: string, payload: any?, requestId: string?): any
    local data = payload or {}
    if SENSITIVE[action] and data.RequestId == nil then
        data.RequestId = requestId or HttpService:GenerateGUID(false)
    end
    -- Rythme d'un joueur : le limiteur du serveur (3 demandes/s) n'est pas visé ici.
    task.wait(0.4)
    local ok, response = pcall(function()
        return request:InvokeServer(action, data)
    end)
    if not ok or type(response) ~= "table" then
        return { Status = "Error", Error = tostring(response) }
    end
    if response.Snapshot then
        snapshot = response.Snapshot
    end
    return response
end

local function accepted(response: any): boolean
    return response.Status == "Confirmed" or response.Status == "Pending"
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
local function inside(): boolean
    local part = root()
    return part ~= nil and part.Position.X > 30000
end

local zone = Workspace:WaitForChild("AutomotiveTestZone", 20)
local entrancePart = zone and zone:WaitForChild("EntreeProprieteEssai", 10) :: BasePart
local garagePart = zone and zone:WaitForChild("GaragePublicEssai", 10) :: BasePart

-- Instantané initial : profil actif, propriété gratuite + synthétique.
waitFor(function()
    local response = call("Snapshot")
    return response.Snapshot ~= nil and response.Snapshot.State == "Active" and response.Snapshot.Vehicles ~= nil
end, 40)
record(prefix .. "instantane_profil_actif", snapshot ~= nil and snapshot.State == "Active", snapshot and snapshot.State)
local free, synthetic = nil, nil
for _, property in (snapshot and snapshot.Properties) or {} do
    if property.Origin == "FreeStarter" then
        free = property
    else
        synthetic = property
    end
end
record(
    prefix .. "propriete_gratuite_invendable",
    free ~= nil and free.Sellable == false and free.Capacity == 1 and free.Category == "Small",
    free and string.format("%s, %s, %d place(s)", free.Label, free.Category, free.Capacity)
)
record(
    prefix .. "donnees_synthetiques_dev",
    synthetic ~= nil and #(snapshot.Vehicles or {}) == 3,
    #((snapshot and snapshot.Vehicles) or {}) .. " véhicule(s)"
)
record(
    prefix .. "starter_indisponible_affiche",
    snapshot ~= nil and snapshot.Starter.State == "Pending" and snapshot.Starter.Available == false
)

local function otherPlayer(): Player?
    for _, other in Players:GetPlayers() do
        if other ~= player then
            return other
        end
    end
    return nil
end

if index == 1 then
    signal("OwnerReady")
    local vehicles = snapshot.Vehicles
    local a, b = vehicles[1], vehicles[2]

    local starter = call("ChooseStarter", { ModelId = "proto_p01" })
    record(prefix .. "starter_refuse_liste_vide", starter.Error == "StarterCatalogUnavailable", describe(starter))
    local outside = call("SetTuning", { VehicleId = a.Id, Tuning = {} })
    record(prefix .. "preparation_refusee_hors_garage", outside.Error == "NotInGarage", describe(outside))
    local farEnter = call("Enter", { OwnerUserId = player.UserId, PropertyId = free.Id })
    record(prefix .. "entree_refusee_loin", farEnter.Error == "EnterNotAtEntrance", describe(farEnter))

    -- Entrée dans la propriété gratuite depuis son entrée physique.
    walkTo(entrancePart.Position)
    local enter = call("Enter", { OwnerUserId = player.UserId, PropertyId = free.Id })
    local wentIn = enter.Status == "Ok" and waitFor(inside, 5)
    record(prefix .. "entree_propriete", wentIn, describe(enter))

    local display = call("Display", { VehicleId = a.Id, PropertyId = free.Id, Slot = 1 })
    record(prefix .. "exposition_place_1", accepted(display), describe(display))
    local occupied = call("Display", { VehicleId = b.Id, PropertyId = free.Id, Slot = 1 })
    record(prefix .. "place_occupee_refusee", occupied.Error == "SlotOccupied", describe(occupied))
    local beyond = call("Display", { VehicleId = b.Id, PropertyId = free.Id, Slot = 2 })
    record(prefix .. "place_hors_capacite_refusee", beyond.Error == "SlotOutOfRange", describe(beyond))
    task.wait(1)
    local showcase = false
    for _, interior in (Workspace:FindFirstChild("InterieursPrives") or Instance.new("Folder")):GetChildren() do
        for _, child in interior:GetChildren() do
            if child:GetAttribute("ShowcaseVehicleId") == a.Id then
                showcase = true
            end
        end
    end
    record(prefix .. "maquette_exposee_visible", showcase)
    local privateTuning = call("SetTuning", { VehicleId = a.Id, Tuning = { SpringFront = 1.1 } })
    record(
        prefix .. "reglages_refuses_garage_prive",
        privateTuning.Error == "CapabilityMissing:EditTuning",
        describe(privateTuning)
    )
    local save = call("SaveConfig", { VehicleId = a.Id, Index = 1, Name = "Serie" })
    record(prefix .. "configuration_enregistree", accepted(save), describe(save))

    -- Sortie : une seule, idempotente, énergie restaurée.
    local requestId = HttpService:GenerateGUID(false)
    local out = call("TakeOut", { VehicleId = a.Id }, requestId)
    record(prefix .. "sortie_vehicule", accepted(out), describe(out))
    local again = call("TakeOut", { VehicleId = a.Id }, requestId)
    -- Répétition : réponse d'origine (« Duplicate », ou « Pending » tant que la
    -- sauvegarde n'est pas confirmée), et jamais un second véhicule.
    task.wait(1)
    local copies = 0
    local personalFolder = Workspace:FindFirstChild("VehiculesPersonnels")
    for _, child in (personalFolder and personalFolder:GetChildren()) or {} do
        if child:GetAttribute("PersonalVehicleId") == a.Id then
            copies += 1
        end
    end
    record(
        prefix .. "sortie_double_clic_sans_doublon",
        (again.Status == "Duplicate" or again.Status == "Pending") and copies == 1,
        describe(again) .. ", " .. copies .. " exemplaire(s) dans le monde"
    )
    local second = call("TakeOut", { VehicleId = b.Id })
    record(prefix .. "seconde_sortie_refusee", second.Error == "AnotherVehicleOut", describe(second))
    record(prefix .. "sorti_hors_interieur", not inside())
    local model: Model? = nil
    waitFor(function()
        local personal = Workspace:FindFirstChild("VehiculesPersonnels")
        if personal then
            for _, child in personal:GetChildren() do
                if child:GetAttribute("PersonalVehicleId") == a.Id then
                    model = child :: Model
                end
            end
        end
        return model ~= nil
    end, 10)
    record(prefix .. "vehicule_personnel_materialise", model ~= nil)
    if model then
        local energy = model:GetAttribute("EnergyLevel")
        local expected = a.Energy * 50
        record(
            prefix .. "energie_restauree",
            type(energy) == "number" and math.abs(energy - expected) < 0.05,
            string.format("%s L (attendu %.2f)", tostring(energy), expected)
        )
        record(prefix .. "proprietaire_publie", model:GetAttribute("OwnerUserId") == player.UserId)
    end

    -- L'invité tente d'embarquer dans le véhicule personnel.
    signal("P1Out")
    waitSignal("P2BoardTried", 60)
    if model then
        local guest = otherPlayer()
        record(
            prefix .. "invite_non_conducteur",
            guest ~= nil and model:GetAttribute("DriverUserId") ~= guest.UserId,
            model:GetAttribute("DriverUserId")
        )
        -- Le propriétaire embarque, lui.
        local seatPart = model:FindFirstChild("DriverSeat") :: BasePart?
        if seatPart then
            walkTo(seatPart.Position + Vector3.new(-6, 0, 0))
        end
        local root_ = model.PrimaryPart
        local door = root_ and root_:FindFirstChild("DriverDoor")
        local prompt = door and door:FindFirstChild("EnterPrompt") :: ProximityPrompt?
        if prompt then
            prompt:InputHoldBegin()
            task.wait(prompt.HoldDuration + 0.3)
            prompt:InputHoldEnd()
        end
        local boarded = waitFor(function()
            return model:GetAttribute("DriverUserId") == player.UserId
        end, 8)
        record(prefix .. "proprietaire_conduit", boarded, model:GetAttribute("DriverUserId"))
        local humanoid = (player.Character :: Model):FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.SeatPart then
            humanoid.Sit = false
            humanoid.Jump = true
        end
        waitFor(function()
            return model:GetAttribute("DriverUserId") == 0
        end, 8)
    end

    -- Invitation de visite puis révocation pendant la visite.
    local guest = otherPlayer()
    local invite = call("Invite", {
        PropertyId = free.Id,
        GuestUserId = if guest then guest.UserId else 0,
        Visit = true,
        Drive = false,
        DurationS = 600,
    })
    record(prefix .. "invitation_visite", accepted(invite), describe(invite))
    signal("P1Invited")
    local guestInside = waitSignal("P2Inside", 60)
    record(prefix .. "invite_entre", guestInside)
    local invitationId = invite.Result and invite.Result.InvitationId
    local revoke = call("RevokeInvite", { InvitationId = invitationId })
    record(prefix .. "revocation", accepted(revoke), describe(revoke))
    signal("P1Revoked")
    waitSignal("P2Checked", 30)

    -- Retour du véhicule à l'entrée (immobile).
    if model then
        walkTo((model :: Model):GetPivot().Position + Vector3.new(-8, 0, 0))
    end
    local back = call("Return", {})
    record(prefix .. "retour_vehicule", accepted(back), describe(back))
    task.wait(1)
    local returned = nil
    for _, vehicle in (snapshot and snapshot.Vehicles) or {} do
        if vehicle.Id == a.Id then
            returned = vehicle
        end
    end
    record(
        prefix .. "retour_place_exposition",
        returned ~= nil and returned.Storage.State == "Displayed" and returned.Storage.Slot == 1,
        returned and returned.Storage.State
    )

    -- Garage public : réglages, pièce, esthétique, configurations.
    walkTo(garagePart.Position)
    local tuning = call("SetTuning", { VehicleId = a.Id, Tuning = { SpringFront = 1.1 } })
    record(prefix .. "garage_public_reglages", accepted(tuning), describe(tuning))
    local part = call("SetPart", { VehicleId = a.Id, Slot = "Tires", PartId = "TIRE-SPORT" })
    record(prefix .. "garage_public_piece_posee", accepted(part), describe(part))
    local look = table.clone(a.Cosmetics)
    look.BodyColor = "Rouge"
    local cosmetics = call("SetCosmetics", { VehicleId = a.Id, Cosmetics = look })
    record(prefix .. "garage_public_esthetique", accepted(cosmetics), describe(cosmetics))
    local unreal = call("SetTuning", { VehicleId = a.Id, Tuning = { SpringFront = 5 } })
    record(prefix .. "reglage_hors_plage_refuse", unreal.Error == "TuningOutOfRange:SpringFront", describe(unreal))
    local sport = call("SaveConfig", { VehicleId = a.Id, Index = 2, Name = "Sport" })
    record(prefix .. "configuration_sport", accepted(sport), describe(sport))
    local apply = call("ApplyConfig", { VehicleId = a.Id, Index = 1 })
    local tires = nil
    for _, vehicle in (snapshot and snapshot.Vehicles) or {} do
        if vehicle.Id == a.Id then
            tires = vehicle.Parts.Tires
        end
    end
    record(prefix .. "configuration_serie_reappliquee", accepted(apply) and tires == nil, describe(apply))
    local detached = snapshot and snapshot.Parts and snapshot.Parts["TIRE-SPORT"]
    record(
        prefix .. "piece_redevenue_detachee_sans_doublon",
        detached ~= nil and detached.Detached == 1 and detached.Installed == 0,
        detached and string.format("%d détachée(s), %d installée(s)", detached.Detached, detached.Installed)
    )

    -- Demandes invalides.
    local badId = call("Store", { VehicleId = a.Id, RequestId = "court" })
    record(prefix .. "identifiant_demande_invalide", badId.Error == "RequestIdInvalid", describe(badId))
    local unknown = call("Teleport", {})
    record(prefix .. "action_inconnue", unknown.Error == "ActionUnknown", describe(unknown))
    -- Lot 0.5 : les achats passent par le canal économique (AWEconomy), plus par celui-ci.
    local buy = call("BuyProperty", { OfferId = "RES-METRO-PARC" })
    record(prefix .. "achat_hors_canal_economique_refuse", buy.Error == "ActionUnknown", describe(buy))

    -- Toutes les opérations finissent confirmées.
    local allConfirmed = waitFor(function()
        call("Snapshot")
        return snapshot ~= nil and snapshot.Pending == 0
    end, 30)
    record(prefix .. "operations_confirmees", allConfirmed, snapshot and snapshot.Pending)
    signal("P1Done")
else
    -- Joueur 2 : invité.
    signal("GuestReady")
    waitSignal("P1Out", 180)
    local owner = otherPlayer()
    local model: Model? = nil
    local personal = Workspace:FindFirstChild("VehiculesPersonnels")
    if personal then
        model = personal:FindFirstChildWhichIsA("Model")
    end
    if model and owner then
        local seatPart = model:FindFirstChild("DriverSeat") :: BasePart?
        if seatPart then
            walkTo(seatPart.Position + Vector3.new(-6, 0, 0))
        end
        local door = model.PrimaryPart and model.PrimaryPart:FindFirstChild("DriverDoor")
        local prompt = door and door:FindFirstChild("EnterPrompt") :: ProximityPrompt?
        if prompt then
            prompt:InputHoldBegin()
            task.wait(prompt.HoldDuration + 0.3)
            prompt:InputHoldEnd()
        end
        task.wait(3)
        record(
            prefix .. "conduite_refusee_sans_droit",
            model:GetAttribute("DriverUserId") ~= player.UserId,
            model:GetAttribute("DriverUserId")
        )
    else
        record(prefix .. "conduite_refusee_sans_droit", false, "véhicule personnel non reçu")
    end
    walkTo(Vector3.new(0, 1, 60))
    signal("P2BoardTried")

    -- Visite sur invitation, puis révocation.
    waitSignal("P1Invited", 180)
    walkTo(entrancePart.Position)
    -- L'invité ne connaît pas l'identifiant de la propriété : il le reçoit par
    -- l'invite d'entrée (propositions calculées par le serveur).
    local push = folder:WaitForChild("Push", 10) :: RemoteEvent
    local offer: any = nil
    local connection = push.OnClientEvent:Connect(function(kind, data)
        if kind == "EntranceOffer" then
            offer = data
        end
    end)
    local prompt = entrancePart:FindFirstChild("AWProgressionPrompt") :: ProximityPrompt?
    if prompt then
        prompt:InputHoldBegin()
        task.wait(prompt.HoldDuration + 0.3)
        prompt:InputHoldEnd()
    end
    waitFor(function()
        return offer ~= nil
    end, 8)
    connection:Disconnect()
    -- À cette entrée, l'invité voit aussi sa propre propriété : on retient celle du propriétaire.
    local option = nil
    for _, candidate in (offer and offer.Options) or {} do
        if candidate.OwnerUserId ~= player.UserId then
            option = candidate
        end
    end
    record(prefix .. "proposition_entree_invite", option ~= nil, offer and #offer.Options .. " proposition(s)")
    if option then
        local ownerProperty = option.PropertyId
        local enter = call("Enter", { OwnerUserId = option.OwnerUserId, PropertyId = ownerProperty })
        local wentIn = enter.Status == "Ok" and waitFor(inside, 5)
        record(prefix .. "visite_sur_invitation", wentIn, describe(enter))
        local tamper = call("Display", { VehicleId = "V-0-0", PropertyId = ownerProperty, Slot = 1 })
        record(prefix .. "visiteur_sans_droit_modification", tamper.Status == "Rejected", describe(tamper))
    end
    signal("P2Inside")
    waitSignal("P1Revoked", 60)
    local evicted = waitFor(function()
        return not inside()
    end, 6)
    record(prefix .. "revocation_reconduit_a_l_entree", evicted)
    if option then
        local denied = call("Enter", { OwnerUserId = option.OwnerUserId, PropertyId = option.PropertyId })
        record(prefix .. "entree_refusee_apres_revocation", denied.Error == "EnterNotAllowed", describe(denied))
    end
    walkTo(Vector3.new(30, 1, 60))
    signal("P2Checked")
    waitSignal("P1Done", 240)
end

reportEvent:FireServer({ vehicle = "lot04-j" .. index, steps = steps, measures = measures })
