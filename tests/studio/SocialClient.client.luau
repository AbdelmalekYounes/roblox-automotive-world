-- Essais CLIENT du lot 0.9.1 (session « social », place de développement, 2 joueurs).
-- Joueur 1 (propriétaire, chef de groupe) et joueur 2 (invité). Parcours : invitation de
-- groupe annulée puis acceptée, partage de position activé puis coupé (et absent sans
-- consentement), invitation de propriété « visite » sans droit de conduite, puis « visite
-- + conduite », conduite réelle du véhicule prêté, retrait du droit pendant la conduite,
-- départ du groupe et dissolution.
-- Les demandes passent par les remotes du jeu, exactement celles qu'envoient les
-- boutons du téléphone et du garage (INSTRUMENTÉ : pas de vrais clics ici — le pont
-- d'entrées ne sait viser qu'une fenêtre, et les deux clients de Studio en ouvrent deux).
-- Le joueur 2 consigne TOUT ce qu'il reçoit (messages des remotes, attributs répliqués du
-- joueur 1) ; le serveur y cherche les données privées du joueur 1 (SocialServer).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local sessionStart = os.clock()
while ReplicatedStorage:GetAttribute("AWTestSession") == nil and os.clock() - sessionStart < 15 do
    task.wait()
end
if ReplicatedStorage:GetAttribute("AWTestSession") ~= "social" then
    return
end

local steps = {}
local measures = {}
local observed: { string } = {}
local observedBytes = 0
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

local index = 0
waitFor(function()
    index = player:GetAttribute("AWTestIndex") or 0
    return index > 0
end, 30)
local prefix = "social.j" .. index .. "."
local function trace(message: string)
    print(string.format("[AW_Test] social j%d %.1f s : %s", index, os.clock() - sessionStart, message))
end

local S = 1 / 0.28
local reportEvent = ReplicatedStorage:WaitForChild("AWTestReport", 30) :: RemoteEvent
local signalEvent = ReplicatedStorage:WaitForChild("AWTestSignal", 30) :: RemoteEvent
local socialFolder = ReplicatedStorage:WaitForChild("AWSocial", 30) :: Instance
local social = socialFolder:WaitForChild("Request", 10) :: RemoteFunction
local socialPush = socialFolder:WaitForChild("Push", 10) :: RemoteEvent
local progression = (ReplicatedStorage:WaitForChild("AWProgression", 30) :: Instance):WaitForChild(
        "Request",
        10
    ) :: RemoteFunction
local economy = (ReplicatedStorage:WaitForChild("AWEconomy", 30) :: Instance):WaitForChild(
        "Request",
        10
    ) :: RemoteFunction
local client = player:WaitForChild("PlayerScripts"):WaitForChild("AutomotiveWorldClient")
local VehicleController = require(client:WaitForChild("Vehicles"):WaitForChild("VehicleController", 10)) :: any

-- Journal de tout ce qui est reçu (joueur 2) : remotes du jeu et attributs répliqués.
local function observe(source: string, ...: any)
    if index ~= 2 or observedBytes > 400000 then
        return
    end
    local packed = { ... }
    local ok, text = pcall(function()
        return HttpService:JSONEncode(packed)
    end)
    local line = source .. " " .. (if ok then text else "?")
    observedBytes += #line
    table.insert(observed, line)
end
-- Tous les RemoteEvent du jeu (hors canaux du test lui-même).
for _, item in ReplicatedStorage:GetDescendants() do
    if item:IsA("RemoteEvent") and item.Name ~= "AWTestSignal" and item.Name ~= "AWTestReport" then
        item.OnClientEvent:Connect(function(...)
            observe(item:GetFullName(), ...)
        end)
    end
end

local positions: { any } = {}
local view: any = nil
local inviteId: string? = nil
socialPush.OnClientEvent:Connect(function(kind, data)
    if kind == "Positions" then
        positions = data or {}
    elseif kind == "View" then
        view = data
    elseif kind == "Invite" then
        inviteId = data and data.Id
    end
end)

local function call(remote: RemoteFunction, action: string, payload: any?): any
    local data = payload or {}
    data.RequestId = data.RequestId or HttpService:GenerateGUID(false)
    task.wait(0.55)
    local ok, response = pcall(function()
        return remote:InvokeServer(action, data)
    end)
    if not ok or type(response) ~= "table" then
        return { Status = "Error", Error = tostring(response) }
    end
    trace(action .. " → " .. tostring(response.Status) .. " " .. tostring(response.Error))
    return response
end
local function describe(response: any): string
    return tostring(response.Status) .. (if response.Error then " / " .. tostring(response.Error) else "")
end
local function accepted(response: any): boolean
    return response.Status == "Ok" or response.Status == "Confirmed" or response.Status == "Pending"
end
local function signal(name: string)
    signalEvent:FireServer("AWSO:" .. name)
end
local function share(key: string, value: string)
    signalEvent:FireServer("AWSOD:" .. key .. "=" .. value)
end
local function waitSignal(name: string, timeout: number): boolean
    trace("attente du signal " .. name)
    return waitFor(function()
        return ReplicatedStorage:GetAttribute("AWSO_" .. name) == true
    end, timeout)
end
local function character(): Model
    return player.Character or player.CharacterAdded:Wait()
end
local function rootPart(): BasePart
    return character():WaitForChild("HumanoidRootPart", 10) :: BasePart
end
local function otherPlayer(): Player?
    for _, other in Players:GetPlayers() do
        if other ~= player then
            return other
        end
    end
    return nil
end
local function seatedIn(model: Model): boolean
    local humanoid = character():FindFirstChildOfClass("Humanoid")
    local seat = humanoid and humanoid.SeatPart
    return seat ~= nil and seat.Name == "DriverSeat" and seat:IsDescendantOf(model)
end
local function tryBoard(model: Model): boolean
    local body = model.PrimaryPart
    local door = body and body:FindFirstChild("DriverDoor")
    local prompt = door and door:FindFirstChild("EnterPrompt") :: ProximityPrompt?
    if prompt == nil then
        return false
    end
    for attempt = 1, 3 do
        rootPart().CFrame = CFrame.new((door :: Attachment).WorldPosition + Vector3.new(0, 2, 0))
        task.wait(if attempt == 1 then 0.8 else 1.5)
        prompt:InputHoldBegin()
        task.wait(prompt.HoldDuration + 0.3)
        prompt:InputHoldEnd()
        if waitFor(function()
            return seatedIn(model)
        end, 4) then
            return true
        end
    end
    return false
end
local function findVehicle(vehicleId: string): Model?
    for _, item in Workspace:GetDescendants() do
        if item:IsA("Model") and item:GetAttribute("PersonalVehicleId") == vehicleId then
            return item
        end
    end
    return nil
end
local function snapshot(): any
    local response = call(economy, "Snapshot", {})
    return response.Snapshot or {}
end

local function owner()
    local guest = otherPlayer() :: Player
    local zone = Workspace:WaitForChild("AutomotiveTestZone", 20) :: Instance
    local garage = zone:WaitForChild("GaragePublicEssai", 10) :: BasePart
    local entrance = zone:WaitForChild("EntreeProprieteEssai", 10) :: BasePart
    -- Solde rendu unique (achat d'une pièce) : sert de référence au contrôle de confidentialité.
    rootPart().CFrame = CFrame.new(garage.Position + Vector3.new(0, 3, 0))
    task.wait(1.2)
    local part = call(economy, "BuyPart", { PartId = "TIRE-SPORT" })
    record(prefix .. "solde_rendu_unique", accepted(part), describe(part))

    -- 1. Invitation de groupe retirée avant réponse, puis nouvelle invitation acceptée.
    local created = call(social, "CreateGroup", {})
    record(prefix .. "groupe_cree", created.Status == "Ok", describe(created))
    local first = call(social, "Invite", { UserId = guest.UserId })
    record(prefix .. "invitation_groupe", first.Status == "Ok", describe(first))
    signal("Invited1")
    waitFor(function()
        return type(ReplicatedStorage:GetAttribute("AWSOD_Invite1")) == "string"
    end, 20)
    local revoke = call(social, "RevokeInvite", { InviteId = ReplicatedStorage:GetAttribute("AWSOD_Invite1") })
    record(prefix .. "invitation_groupe_retiree", revoke.Status == "Ok", describe(revoke))
    signal("Revoked1")
    waitSignal("TriedOld", 30)
    local second = call(social, "Invite", { UserId = guest.UserId })
    record(prefix .. "invitation_groupe_2", second.Status == "Ok", describe(second))
    signal("Invited2")
    waitSignal("Joined", 30)
    local grouped = waitFor(function()
        return view ~= nil and view.Group ~= nil and #(view.Group.Members or {}) == 2
    end, 10)
    record(prefix .. "groupe_a_deux", grouped, view and view.Group and HttpService:JSONEncode(view.Group.Members))

    -- 2. Partage de position : activé, reçu par le joueur 2, puis coupé.
    local on = call(social, "SetSharing", { On = true })
    record(prefix .. "partage_active", on.Status == "Ok", describe(on))
    local root = rootPart()
    share("OwnerPos", string.format("%.1f,%.1f", root.Position.X / S, root.Position.Z / S))
    signal("SharingOn")
    waitSignal("SeenPosition", 30)
    -- Sans consentement du joueur 2, sa position ne doit jamais arriver ici.
    local sawGuest = false
    for _, entry in positions do
        if entry.UserId == guest.UserId then
            sawGuest = true
        end
    end
    record(prefix .. "position_de_l_autre_absente_sans_partage", not sawGuest, #positions .. " position(s) reçue(s)")
    local off = call(social, "SetSharing", { On = false })
    record(prefix .. "partage_coupe", off.Status == "Ok", describe(off))
    signal("SharingOff")
    waitSignal("SawStop", 30)

    -- 3. Invitation de propriété : visite seule, puis visite + conduite, retrait en route.
    local snap = snapshot()
    local ownId, propertyId = nil, nil
    for _, vehicle in snap.Vehicles or {} do
        if vehicle.Name == "Prototype d'essai P-01" then
            ownId = vehicle.Id
        end
    end
    for _, property in snap.Properties or {} do
        propertyId = propertyId or property.Id
    end
    rootPart().CFrame = CFrame.new(entrance.Position + Vector3.new(0, 3, 0))
    task.wait(1.2)
    call(progression, "Enter", { OwnerUserId = player.UserId, PropertyId = propertyId })
    local out = call(progression, "TakeOut", { VehicleId = ownId })
    call(progression, "Exit", {})
    record(prefix .. "vehicule_sorti", accepted(out), describe(out))
    local model: Model? = nil
    waitFor(function()
        model = if ownId then findVehicle(ownId) else nil
        return model ~= nil
    end, 10)
    if model then
        share("Vehicle", (model :: Model):GetFullName())
    end
    -- Le propriétaire s'écarte (le véhicule reste libre à l'entrée).
    rootPart().CFrame = CFrame.new(entrance.Position + Vector3.new(30, 3, 0))
    local visit = call(progression, "Invite", {
        PropertyId = propertyId,
        GuestUserId = guest.UserId,
        Visit = true,
        Drive = false,
        DurationS = 600,
    })
    record(prefix .. "invitation_visite_seule", accepted(visit), describe(visit))
    signal("VisitOnly")
    waitSignal("TriedDrive", 60)
    local visitId = visit.Result and visit.Result.InvitationId
    call(progression, "RevokeInvite", { InvitationId = visitId })
    local drive = call(progression, "Invite", {
        PropertyId = propertyId,
        GuestUserId = guest.UserId,
        Visit = true,
        Drive = true,
        DurationS = 600,
    })
    record(prefix .. "invitation_visite_et_conduite", accepted(drive), describe(drive))
    signal("DriveGranted")
    waitSignal("Driving", 60)
    task.wait(3)
    local driveId = drive.Result and drive.Result.InvitationId
    local revokeDrive = call(progression, "RevokeInvite", { InvitationId = driveId })
    record(prefix .. "droit_de_conduite_retire_en_route", accepted(revokeDrive), describe(revokeDrive))
    signal("DriveRevoked")
    waitSignal("Ejected", 60)

    -- 4. Départ du joueur 2 puis dissolution.
    signal("PleaseLeave")
    waitSignal("Left", 30)
    local alone = waitFor(function()
        return view ~= nil and (view.Group == nil or #(view.Group.Members or {}) == 1)
    end, 10)
    record(prefix .. "groupe_apres_depart", alone, view and view.Group and #(view.Group.Members or {}))
    local dissolve = call(social, "Dissolve", {})
    record(prefix .. "groupe_dissous", dissolve.Status == "Ok" or dissolve.Error == "GroupNone", describe(dissolve))
    signal("OwnerDone")
end

local function guestFlow()
    local host = otherPlayer() :: Player
    -- Attributs répliqués du joueur 1, relevés au début et à la fin.
    local function hostAttributes(): string
        return HttpService:JSONEncode(host:GetAttributes())
    end
    observe("attributs_joueur1_debut", hostAttributes())
    waitSignal("Invited1", 60)
    waitFor(function()
        return inviteId ~= nil
    end, 10)
    local oldId = inviteId
    share("Invite1", tostring(oldId))
    record(prefix .. "invitation_recue", oldId ~= nil, tostring(oldId))
    waitSignal("Revoked1", 30)
    local stale = call(social, "Accept", { InviteId = oldId })
    record(prefix .. "invitation_retiree_inutilisable", stale.Status ~= "Ok", describe(stale))
    inviteId = nil
    signal("TriedOld")
    waitSignal("Invited2", 30)
    waitFor(function()
        return inviteId ~= nil
    end, 10)
    local accept = call(social, "Accept", { InviteId = inviteId })
    record(prefix .. "invitation_acceptee", accept.Status == "Ok", describe(accept))
    signal("Joined")

    waitSignal("SharingOn", 30)
    local seen = waitFor(function()
        for _, entry in positions do
            if entry.UserId == host.UserId then
                return true
            end
        end
        return false
    end, 10)
    local gap = -1
    local reference = ReplicatedStorage:GetAttribute("AWSOD_OwnerPos")
    for _, entry in positions do
        if entry.UserId == host.UserId and type(reference) == "string" then
            local x, z = string.match(reference, "^(-?[%d%.]+),(-?[%d%.]+)$")
            gap = math.sqrt((entry.X - tonumber(x)) ^ 2 + (entry.Z - tonumber(z)) ^ 2)
        end
    end
    record(prefix .. "position_partagee_recue", seen and gap >= 0 and gap < 8, string.format("écart %.1f m", gap))
    signal("SeenPosition")
    waitSignal("SharingOff", 30)
    local stopped = waitFor(function()
        for _, entry in positions do
            if entry.UserId == host.UserId then
                return false
            end
        end
        return true
    end, 10)
    record(prefix .. "position_plus_recue_apres_arret", stopped, #positions .. " position(s)")
    signal("SawStop")

    -- Visite seule : la conduite doit être refusée.
    waitSignal("VisitOnly", 60)
    waitFor(function()
        return type(ReplicatedStorage:GetAttribute("AWSOD_Vehicle")) == "string"
    end, 10)
    local model: Model? = nil
    for _, item in Workspace:GetDescendants() do
        if item:IsA("Model") and item:GetFullName() == ReplicatedStorage:GetAttribute("AWSOD_Vehicle") then
            model = item
        end
    end
    record(prefix .. "vehicule_du_proprietaire_visible", model ~= nil)
    if model == nil then
        signal("TriedDrive")
        signal("Driving")
        signal("Ejected")
        return
    end
    local refused = not tryBoard(model :: Model)
    record(
        prefix .. "conduite_refusee_avec_visite_seule",
        refused,
        tostring((model :: Model):GetAttribute("DriverUserId"))
    )
    if not refused then
        local humanoid = character():FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.Sit = false
            humanoid.Jump = true
        end
        task.wait(1.5)
    end
    signal("TriedDrive")
    waitSignal("DriveGranted", 60)
    task.wait(2)
    local boarded = tryBoard(model :: Model)
    record(prefix .. "conduite_acceptee_avec_droit", boarded, tostring((model :: Model):GetAttribute("DriverUserId")))
    if boarded then
        -- Conduite réelle (pilote : accélérateur et direction), ligne droite courte.
        VehicleController.setTestInputProvider(function()
            return { Throttle = 0.5, Brake = 0, Steer = 0, Handbrake = false, Clutch = 0 }
        end)
        local body = (model :: Model).PrimaryPart :: BasePart
        local moved = waitFor(function()
            return body.AssemblyLinearVelocity.Magnitude / S * 3.6 > 12
        end, 8)
        record(
            prefix .. "vehicule_prete_roule",
            moved,
            string.format("%.0f km/h", body.AssemblyLinearVelocity.Magnitude / S * 3.6)
        )
    end
    signal("Driving")
    waitSignal("DriveRevoked", 30)
    -- Retrait du droit en roulant : arrêt sûr demandé, descente une fois immobilisé.
    VehicleController.setTestInputProvider(function()
        local body = (model :: Model).PrimaryPart
        local moving = body ~= nil and body.AssemblyLinearVelocity.Magnitude / S * 3.6 > 3
        return { Throttle = 0, Brake = if moving then 1 else 0, Steer = 0, Handbrake = not moving, Clutch = 0 }
    end)
    local ejected = waitFor(function()
        return not seatedIn(model :: Model)
    end, 30)
    VehicleController.setTestInputProvider(nil)
    record(
        prefix .. "descente_apres_retrait_du_droit",
        ejected,
        tostring((model :: Model):GetAttribute("DriverUserId"))
    )
    local again = tryBoard(model :: Model)
    record(prefix .. "conduite_refusee_apres_retrait", not again)
    signal("Ejected")

    waitSignal("PleaseLeave", 60)
    local leave = call(social, "Leave", {})
    record(prefix .. "groupe_quitte", leave.Status == "Ok", describe(leave))
    signal("Left")
    waitSignal("OwnerDone", 60)
    observe("attributs_joueur1_fin", hostAttributes())
    measures.observations = #observed
    measures.observationsOctets = observedBytes
end

local function main()
    waitFor(function()
        local snap = snapshot()
        return snap.State == "Active" and snap.Wallet ~= nil
    end, 40)
    waitFor(function()
        return #Players:GetPlayers() >= 2
    end, 60)
    character():WaitForChild("HumanoidRootPart", 20)
    task.wait(2)
    if index == 1 then
        owner()
    else
        guestFlow()
    end
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
    record(prefix .. "execution", false, err)
end
VehicleController.setTestInputProvider(nil)
reportEvent:FireServer({
    vehicle = "social" .. index,
    steps = steps,
    measures = measures,
    observed = if index == 2 then observed else nil,
})
