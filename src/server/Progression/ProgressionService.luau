--!strict
--[[
    Service de progression (lot 0.4) : point d'entrée UNIQUE des demandes des
    joueurs sur leur collection, leurs propriétés, garages, préparations,
    configurations et invitations.

    Chaque demande est revalidée côté serveur : identité (le joueur qui
    appelle), état du profil (Active), lieu réel du personnage (intérieur,
    entrée, garage public), capacités du lieu, droits, et blocage des menus
    en mouvement (AUD-UI-01). Le client n'envoie que des intentions et des
    identifiants ; aucune valeur sensible n'est reprise de lui.

    Réponses : « Confirmed » après écriture durable confirmée, « Pending » si
    l'écriture est en attente (l'interface l'affiche), « Duplicate » pour une
    répétition, « Rejected » avec une clé d'erreur, « Unavailable » si le
    profil ne peut pas être modifié (stockage indisponible, lecture seule).
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GarageShared = Shared:WaitForChild("Garage")
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))
local VehicleDefinitions = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleDefinitions"))
local ProgressionProtocol = require(GarageShared:WaitForChild("ProgressionProtocol"))
local PropertyCatalog = require(GarageShared:WaitForChild("PropertyCatalog"))
local GarageModules = require(GarageShared:WaitForChild("GarageModules"))
local StarterCatalog = require(GarageShared:WaitForChild("StarterCatalog"))
local TuningRules = require(GarageShared:WaitForChild("TuningRules"))
local CosmeticCatalog = require(GarageShared:WaitForChild("CosmeticCatalog"))
local PartCatalog = require(GarageShared:WaitForChild("PartCatalog"))
local EconomyCatalog = require(Shared:WaitForChild("Economy"):WaitForChild("EconomyCatalog"))

local Persistence = script.Parent.Parent.Persistence
local ProfileService = require(Persistence.ProfileService)
local TransactionService = require(Persistence.TransactionService)
local ProfileSchema = require(Persistence.ProfileSchema)
local RateLimiter = require(script.Parent.Parent.Security.RateLimiter)
local VehicleService = require(script.Parent.Parent.Vehicles.VehicleService)

local VehicleOwnership = require(script.Parent.VehicleOwnership)
local StarterSelection = require(script.Parent.StarterSelection)
local PropertyRules = require(script.Parent.PropertyRules)
local GarageRules = require(script.Parent.GarageRules)
local Customization = require(script.Parent.Customization)
local InvitationRules = require(script.Parent.InvitationRules)
local DurableState = require(script.Parent.DurableState)
local Locations = require(script.Parent.Locations)
local Commerce = require(script.Parent.Parent.Economy.Commerce)
local PropertyInteriors = require(script.Parent.PropertyInteriors)

local ProgressionService = {}

local S = 1 / Constants.MetersPerStud
local MENU_MAX_SPEED_MS = 1
local RETURN_MAX_SPEED_MS = 1.5
local DRIVE_REVOKE_STOP_MS = 2
local DURABLE_SYNC_S = 30
local INTERIOR_COLLECT_S = 10

type Response = {
    Status: string,
    Error: string?,
    Result: any?,
    Snapshot: any?,
}

type Context = {
    Kind: "Property" | "Visit" | "PublicGarage" | "Entrance" | "None",
    PlaceId: string?,
    PropertyId: string?,
    OwnerUserId: number?,
    Capabilities: { [string]: boolean },
}

local started = false
local push: RemoteEvent
local limiters: { [Player]: RateLimiter.Bucket } = {}
-- Exemplaire personnel matérialisé par joueur (au plus un, GarageRules.MaxOut).
local outVehicles: { [Player]: { Model: Model, VehicleId: string } } = {}
local revokeNotified: { [Model]: boolean } = {}

local function now(): number
    return os.time()
end

local function rootOf(player: Player): BasePart?
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        return root
    end
    return nil
end

local function humanoidOf(player: Player): Humanoid?
    local character = player.Character
    return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

-- Menus complets bloqués dès la mise en mouvement (AUD-UI-01).
local function moving(player: Player): boolean
    local humanoid = humanoidOf(player)
    local seat = humanoid and humanoid.SeatPart
    return seat ~= nil and seat.AssemblyLinearVelocity.Magnitude * Constants.MetersPerStud > MENU_MAX_SPEED_MS
end

local function ownedProperty(profile: ProfileSchema.Profile, propertyId: string?): ProfileSchema.Property?
    if propertyId == nil then
        return nil
    end
    return profile.Properties[propertyId]
end

local function contextOf(player: Player, profile: ProfileSchema.Profile?): Context
    local interior = PropertyInteriors.of(player)
    if interior then
        if interior.OwnerUserId == player.UserId and profile then
            local property = ownedProperty(profile, interior.PropertyId)
            return {
                Kind = "Property",
                PropertyId = interior.PropertyId,
                OwnerUserId = player.UserId,
                Capabilities = if property then GarageModules.privateCapabilities(property.Modules) else {},
            }
        end
        return {
            Kind = "Visit",
            PropertyId = interior.PropertyId,
            OwnerUserId = interior.OwnerUserId,
            Capabilities = {},
        }
    end
    local root = rootOf(player)
    if root then
        local garage = Locations.near(root.Position, "PublicGarage")
        if garage then
            return { Kind = "PublicGarage", PlaceId = garage.Id, Capabilities = GarageModules.publicCapabilities() }
        end
        local entrance = Locations.near(root.Position, "Entrance")
        if entrance then
            return { Kind = "Entrance", PlaceId = entrance.Id, Capabilities = {} }
        end
    end
    return { Kind = "None", Capabilities = {} }
end

-- Entrée (lieu effectif) d'une propriété possédée.
local function entranceOf(property: ProfileSchema.Property): Locations.Place?
    local offer = PropertyCatalog.offer(property.OfferId)
    return if offer then Locations.get(offer.Entrance) else nil
end

local function catalogParts(profile: ProfileSchema.Profile, vehicle: ProfileSchema.Vehicle): { [string]: string }
    return Customization.catalogParts(profile, vehicle)
end

-- ======================== Instantané (profil du joueur seulement) ========================

local function damageLevel(damage: ProfileSchema.Damage): number
    local worst = 0
    for _, wear in damage.Zones do
        worst = math.max(worst, wear)
    end
    return worst
end

local function vehicleSummary(profile: ProfileSchema.Profile, vehicle: ProfileSchema.Vehicle, time: number): any
    local definition = VehicleDefinitions.get(vehicle.ModelId)
    local configurations = {}
    for index, configuration in vehicle.Configurations do
        configurations[index] = {
            Name = configuration.Name,
            UpdatedAt = configuration.UpdatedAt,
            Realizable = VehicleOwnership.realizable(profile, vehicle, configuration),
        }
    end
    return {
        Id = vehicle.Id,
        ModelId = vehicle.ModelId,
        DisplayName = if definition then definition.DisplayName else vehicle.ModelId,
        Origin = vehicle.Origin,
        Untransferable = vehicle.Untransferable,
        Synthetic = vehicle.Synthetic,
        OdometerKm = vehicle.OdometerKm,
        Energy = vehicle.Energy,
        DamageLevel = damageLevel(vehicle.Damage),
        Engine = vehicle.Damage.Engine,
        Storage = vehicle.Storage,
        Reserved = VehicleOwnership.reserved(vehicle, time),
        Parts = catalogParts(profile, vehicle),
        Tuning = vehicle.Tuning,
        Cosmetics = vehicle.Cosmetics,
        Configurations = configurations,
    }
end

local function snapshot(player: Player, page: number?): any
    local session = ProfileService.get(player)
    local state = if session then session.State else "Loading"
    local result: any = {
        State = state,
        Environment = ProfileService.environment().Name,
        Pending = 0,
    }
    if session == nil or session.Data == nil or (state ~= "Active" and state ~= "ReadOnly") then
        return result
    end
    local profile = session.Data :: ProfileSchema.Profile
    local time = now()
    for _ in session.Pending do
        result.Pending += 1
    end
    local context = contextOf(player, profile)
    result.Context = {
        Kind = context.Kind,
        PlaceId = context.PlaceId,
        PropertyId = context.PropertyId,
        Capabilities = context.Capabilities,
    }
    result.Starter = {
        State = profile.Starter.State,
        ModelId = profile.Starter.ModelId,
        Available = StarterCatalog.available(),
        Candidates = StarterCatalog.Candidates,
    }
    local vehicles, pages = VehicleOwnership.page(profile, page or 1, ProgressionProtocol.PageSize)
    result.Vehicles = {}
    for _, vehicle in vehicles do
        table.insert(result.Vehicles, vehicleSummary(profile, vehicle, time))
    end
    result.Page = math.clamp(page or 1, 1, pages)
    result.Pages = pages
    local total = 0
    for _ in profile.Vehicles do
        total += 1
    end
    result.TotalVehicles = total
    result.Properties = {}
    for _, property in profile.Properties do
        local offer = PropertyCatalog.offer(property.OfferId)
        local entrance = entranceOf(property)
        local slots = {}
        for id, vehicle in profile.Vehicles do
            if vehicle.Storage.State == "Displayed" and vehicle.Storage.PropertyId == property.Id then
                slots[tostring(vehicle.Storage.Slot)] = id
            end
        end
        local modules = {}
        for id in property.Modules do
            table.insert(modules, id)
        end
        table.insert(result.Properties, {
            Id = property.Id,
            OfferId = property.OfferId,
            Label = if offer then offer.Label else property.OfferId,
            Category = property.Category,
            Capacity = PropertyRules.capacity(property),
            GarageLevel = property.GarageLevel,
            MaxLevel = PropertyCatalog.maxGarageLevel(property.Category :: any),
            Entrance = if offer then offer.Entrance else "",
            EntranceLabel = if entrance then entrance.Label else "",
            Zone = if entrance then entrance.Zone else "",
            Sellable = property.Sellable,
            Origin = property.Origin,
            Synthetic = property.Synthetic,
            Modules = modules,
            Slots = slots,
        })
    end
    table.sort(result.Properties, function(a, b)
        return a.Id < b.Id
    end)
    local parts: { [string]: { Detached: number, Installed: number } } = {}
    for _, item in profile.Parts do
        local entry = parts[item.PartId] or { Detached = 0, Installed = 0 }
        if item.InstalledOn then
            entry.Installed += 1
        else
            entry.Detached += 1
        end
        parts[item.PartId] = entry
    end
    result.Parts = parts
    result.Invitations = {}
    for _, invitation in profile.Invitations do
        local guest = Players:GetPlayerByUserId(invitation.GuestUserId)
        table.insert(result.Invitations, {
            Id = invitation.Id,
            PropertyId = invitation.PropertyId,
            GuestUserId = invitation.GuestUserId,
            GuestName = if guest then guest.DisplayName else nil,
            Visit = invitation.Visit,
            Drive = invitation.Drive,
            ExpiresAt = invitation.ExpiresAt,
            Active = InvitationRules.active(invitation, time),
        })
    end
    local out = outVehicles[player]
    result.OutVehicle = if out then out.VehicleId else nil
    result.Now = time
    return result
end

-- ======================== Exemplaires personnels dans le monde ========================

local function derivedDefinition(profile: ProfileSchema.Profile, vehicle: ProfileSchema.Vehicle): (any?, string)
    local base = VehicleDefinitions.get(vehicle.ModelId)
    if base == nil then
        return nil, ""
    end
    local parts = catalogParts(profile, vehicle)
    local derived = TuningRules.apply(base, vehicle.Tuning, parts)
    derived.Appearance = CosmeticCatalog.appearance(base.Appearance, vehicle.Cosmetics :: any)
    -- Lot 0.5 : salissure visible (teinte assombrie), effacée par le lavage.
    local dirt = math.clamp(vehicle.Dirt or 0, 0, 1)
    for index, channel in derived.Appearance.BodyRgb do
        derived.Appearance.BodyRgb[index] = math.floor(channel * (1 - 0.35 * dirt))
    end
    local valid, errors = VehicleDefinitions.validate(derived)
    if not valid then
        -- Ne devrait jamais arriver (réglages validés à l'enregistrement) :
        -- on retombe sur la définition d'origine plutôt que de simuler l'invalide.
        ProfileService.Log:write("Error", "DerivedDefinitionInvalid", { Vehicle = vehicle.Id, First = errors[1] })
        local fallback = TuningRules.deepCopy(base)
        fallback.Appearance = derived.Appearance
        return fallback, HttpService:JSONEncode({ Tuning = {}, Parts = {} })
    end
    return derived, HttpService:JSONEncode({ Tuning = vehicle.Tuning, Parts = parts })
end

-- Emplacement de sortie libre près d'un lieu (aucun véhicule ni personnage).
local function freeExit(place: Locations.Place, definition: any): CFrame?
    local size = Vector3.new(definition.Chassis.WidthM * S + 4, 8, definition.Chassis.LengthM * S + 4)
    local blockers: { Instance } = {}
    for _, name in { "VehiculesEssai", "VehiculesPersonnels", "TraficPNJ" } do
        local folder = Workspace:FindFirstChild(name)
        if folder then
            table.insert(blockers, folder)
        end
    end
    for _, other in Players:GetPlayers() do
        if other.Character then
            table.insert(blockers, other.Character)
        end
    end
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = blockers
    for _, offset in { 0, 1, -1, 2, -2 } do
        local frame = place.ExitFrame * CFrame.new(offset * (definition.Chassis.WidthM * S + 6), 0, 0)
        local probe = frame * CFrame.new(0, size.Y / 2 + 0.5, 0)
        if #Workspace:GetPartBoundsInBox(probe, size, params) == 0 then
            return frame
        end
    end
    return nil
end

local function mayDrive(ownerUserId: number): (Player) -> boolean
    return function(player: Player): boolean
        if player.UserId == ownerUserId then
            return true
        end
        local _, session = ProfileService.byUserId(ownerUserId)
        if session == nil or session.Data == nil then
            return false
        end
        return InvitationRules.allows(session.Data :: ProfileSchema.Profile, nil, player.UserId, "Drive", now())
    end
end

-- Réconcilie l'état durable mesuré par le serveur (mutation non sensible).
local function syncDurable(player: Player)
    local out = outVehicles[player]
    local session = ProfileService.get(player)
    if out == nil or session == nil then
        return
    end
    local state = VehicleService.readPersonal(out.Model)
    if state == nil then
        return
    end
    session:mutate(function(profile)
        local vehicle = profile.Vehicles[out.VehicleId]
        if vehicle == nil then
            return false
        end
        return DurableState.reconcile(vehicle, {
            EnergyFraction = state.EnergyFraction,
            Damage = state.Damage,
            DistanceKm = state.DistanceKm,
            ElapsedS = state.ElapsedS,
            MaxSpeedKmh = state.MaxSpeedKmh,
            Protected = state.Protected,
        }, now())
    end)
end

-- ======================== Intérieurs ========================

local exitInterior: (Player) -> ()

local function displayedOf(profile: ProfileSchema.Profile, propertyId: string): { [number]: any }
    local displayed: { [number]: any } = {}
    for _, vehicle in profile.Vehicles do
        local storage = vehicle.Storage
        if storage.State == "Displayed" and storage.PropertyId == propertyId and storage.Slot then
            displayed[storage.Slot :: number] = vehicle
        end
    end
    return displayed
end

local function refreshInterior(ownerUserId: number, propertyId: string)
    local _, session = ProfileService.byUserId(ownerUserId)
    if session == nil or session.Data == nil then
        return
    end
    local profile = session.Data :: ProfileSchema.Profile
    local property = profile.Properties[propertyId]
    if property then
        PropertyInteriors.refresh(
            ownerUserId,
            propertyId,
            PropertyRules.capacity(property),
            displayedOf(profile, propertyId),
            exitInterior
        )
    end
end

-- Place le personnage à un repère (flux de la zone d'arrivée demandé d'abord).
local function moveCharacter(player: Player, frame: CFrame)
    local character = player.Character
    if character == nil then
        return
    end
    if Workspace.StreamingEnabled then
        pcall(function()
            player:RequestStreamAroundAsync(frame.Position, 5)
        end)
    end
    character:PivotTo(frame)
end

function exitInterior(player: Player)
    local interior = PropertyInteriors.of(player)
    if interior == nil then
        return
    end
    PropertyInteriors.leave(interior, player, now())
    local _, session = ProfileService.byUserId(interior.OwnerUserId)
    local property = if session and session.Data
        then (session.Data :: ProfileSchema.Profile).Properties[interior.PropertyId]
        else nil
    local place = if property then entranceOf(property) else nil
    if place then
        moveCharacter(player, place.ExitFrame * CFrame.new(0, 4, 0))
    else
        -- Propriété disparue (cession, départ du propriétaire) : point d'apparition.
        player:LoadCharacter()
    end
end

-- ======================== Actions ========================

type Handler = (player: Player, payload: any, txId: string?) -> Response

local function reply(result: any, player: Player): Response
    local response: Response = {
        Status = result.Status,
        Error = result.Error,
        Result = result.Result,
        Snapshot = snapshot(player),
    }
    if result.Status == "Confirmed" or result.Status == "Pending" or result.Status == "Duplicate" then
        ProfileService.markDirty(player)
    end
    return response
end

local function rejected(key: string): Response
    return { Status = "Rejected", Error = key }
end

local function activeSession(player: Player): any
    local session = ProfileService.get(player)
    if session == nil or session.State ~= "Active" or session.Data == nil then
        return nil
    end
    return session
end

local handlers: { [string]: Handler } = {}

handlers.Snapshot = function(player)
    return { Status = "Ok", Snapshot = snapshot(player) }
end

handlers.CollectionPage = function(player, payload)
    local page = if type(payload) == "table" and type(payload.Page) == "number" then math.floor(payload.Page) else 1
    return { Status = "Ok", Snapshot = snapshot(player, page) }
end

handlers.ChooseStarter = function(player, payload)
    local session = activeSession(player)
    if session == nil then
        return { Status = "Unavailable", Error = "ProfileUnavailable" }
    end
    local modelId = if type(payload) == "table" then payload.ModelId else nil
    -- Identifiant FIXE : un double clic ou une reprise ne crée jamais de doublon.
    local result = session:commit(StarterSelection.TxId, "Starter", function(profile)
        return StarterSelection.choose(profile, modelId, StarterCatalog.Candidates, now(), function(id)
            local definition = VehicleDefinitions.get(id)
            if definition == nil then
                return nil, nil
            end
            return definition.Powertrain.Energy.InitialFraction, CosmeticCatalog.defaults(definition)
        end)
    end)
    return reply(result, player)
end

-- Opérations de garage privé : le joueur doit être DANS sa propriété.
local function inOwnProperty(player: Player, profile: ProfileSchema.Profile): (Context?, string?)
    local context = contextOf(player, profile)
    if context.Kind ~= "Property" then
        return nil, "NotInOwnProperty"
    end
    return context, nil
end

handlers.Display = function(player, payload, txId)
    local session = activeSession(player)
    if session == nil then
        return { Status = "Unavailable", Error = "ProfileUnavailable" }
    end
    local context, problem = inOwnProperty(player, session.Data)
    if context == nil then
        return rejected(problem :: string)
    end
    if type(payload) ~= "table" or payload.PropertyId ~= context.PropertyId then
        return rejected("DisplayOtherProperty")
    end
    local result = session:commit(txId :: string, "Display", function(profile)
        return GarageRules.display(profile, payload.VehicleId, payload.PropertyId, payload.Slot, now())
    end)
    if result.Status == "Confirmed" or result.Status == "Pending" then
        refreshInterior(player.UserId, context.PropertyId :: string)
    end
    return reply(result, player)
end

handlers.Store = function(player, payload, txId)
    local session = activeSession(player)
    if session == nil then
        return { Status = "Unavailable", Error = "ProfileUnavailable" }
    end
    local context, problem = inOwnProperty(player, session.Data)
    if context == nil then
        return rejected(problem :: string)
    end
    local vehicleId = if type(payload) == "table" then payload.VehicleId else nil
    local result = session:commit(txId :: string, "Store", function(profile)
        return GarageRules.store(profile, vehicleId, now())
    end)
    if result.Status == "Confirmed" or result.Status == "Pending" then
        refreshInterior(player.UserId, context.PropertyId :: string)
    end
    return reply(result, player)
end

handlers.TakeOut = function(player, payload, txId)
    local session = activeSession(player)
    if session == nil then
        return { Status = "Unavailable", Error = "ProfileUnavailable" }
    end
    local profile = session.Data :: ProfileSchema.Profile
    local vehicleId = if type(payload) == "table" then payload.VehicleId else nil
    local vehicle = VehicleOwnership.get(profile, vehicleId)
    if vehicle == nil then
        return rejected("VehicleNotOwned")
    end
    -- Un exemplaire déjà matérialisé : jamais de second exemplaire physique.
    if outVehicles[player] ~= nil then
        local again = TransactionService.previous(profile, txId :: string)
        if again then
            return reply(
                { Status = if session:isPending(txId :: string) then "Pending" else "Duplicate", Result = again.Result },
                player
            )
        end
        return rejected("AnotherVehicleOut")
    end
    -- Sortie depuis l'intérieur d'une propriété possédée, ou à son entrée.
    local context = contextOf(player, profile)
    local place: Locations.Place? = nil
    if context.Kind == "Property" then
        local property = ownedProperty(profile, context.PropertyId)
        place = if property then entranceOf(property) else nil
    elseif context.Kind == "Entrance" then
        for _, property in profile.Properties do
            local entrance = entranceOf(property)
            if entrance and entrance.Id == Locations.resolve(context.PlaceId :: string) then
                place = entrance
            end
        end
    end
    if place == nil then
        return rejected("TakeOutNotHere")
    end
    local definition, spec = derivedDefinition(profile, vehicle)
    if definition == nil then
        return rejected("VehicleModelMissing")
    end
    local exitFrame = freeExit(place, definition)
    if exitFrame == nil then
        return rejected("ExitBlocked")
    end
    local session_ = session
    local result = session_:commit(txId :: string, "TakeOut", function(data)
        return GarageRules.takeOut(data, vehicleId, session_.Options.Session, now())
    end)
    if (result.Status ~= "Confirmed" and result.Status ~= "Pending") or result.Replayed then
        return reply(result, player)
    end
    -- L'état « Out » est appliqué (confirmé ou en attente) : matérialisation.
    local fresh = (session.Data :: ProfileSchema.Profile).Vehicles[vehicleId]
    local model = VehicleService.spawnPersonal({
        Definition = definition,
        Pivot = exitFrame * CFrame.new(0, definition.Chassis.CgHeightM * S + 0.3, 0),
        OwnerUserId = player.UserId,
        VehicleId = fresh.Id,
        Protected = false,
        MayDrive = mayDrive(player.UserId),
        EnergyFraction = fresh.Energy,
        Damage = fresh.Damage,
        TuningSpec = spec,
    })
    outVehicles[player] = { Model = model, VehicleId = fresh.Id }
    local inside = PropertyInteriors.of(player)
    if inside then
        PropertyInteriors.leave(inside, player, now())
    end
    moveCharacter(player, exitFrame * CFrame.new(-(definition.Chassis.WidthM * S / 2 + 4), 4, 0))
    if context.Kind == "Property" then
        refreshInterior(player.UserId, context.PropertyId :: string)
    end
    return reply(result, player)
end

handlers.Return = function(player, _payload, txId)
    local session = activeSession(player)
    if session == nil then
        return { Status = "Unavailable", Error = "ProfileUnavailable" }
    end
    local out = outVehicles[player]
    if out == nil then
        return rejected("VehicleNotOut")
    end
    local profile = session.Data :: ProfileSchema.Profile
    local position = out.Model:GetPivot().Position
    -- Le véhicule doit être physiquement ramené à une de ses entrées ou à un garage public.
    local allowed = Locations.near(position, "PublicGarage") ~= nil
    for _, property in profile.Properties do
        local entrance = entranceOf(property)
        if entrance and Locations.within(entrance, position) then
            allowed = true
        end
    end
    if not allowed then
        return rejected("ReturnNotHere")
    end
    local _, speed = VehicleService.personalDriver(out.Model)
    if speed > RETURN_MAX_SPEED_MS then
        return rejected("ReturnMoving")
    end
    syncDurable(player)
    local result = session:commit(txId :: string, "Return", function(data)
        return GarageRules.bringBack(data, out.VehicleId, now())
    end)
    if result.Status == "Confirmed" or result.Status == "Pending" then
        VehicleService.despawnPersonal(out.Model)
        outVehicles[player] = nil
        revokeNotified[out.Model] = nil
    end
    return reply(result, player)
end

-- Préparation : capacités du lieu (garage public, ou propriété et modules).
-- Main-d'œuvre d'une intervention en garage public (barème provisoire).
local function laborFee(kind: string, payload: any, result: any): number
    local labor = EconomyCatalog.Labor
    if kind == "SetPart" then
        return if payload.PartId ~= nil then labor.PartInstall else labor.PartRemove
    elseif kind == "SetCosmetics" then
        return labor.Cosmetics
    elseif kind == "SetTuning" then
        return labor.Tuning
    elseif kind == "ApplyConfig" and type(result) == "table" and result.Swapped then
        return labor.PartInstall
    end
    return 0
end

local function prepare(
    player: Player,
    payload: any,
    txId: string?,
    kind: string,
    mutate: (any, any, { [string]: boolean }) -> (boolean, any)
): Response
    local session = activeSession(player)
    if session == nil then
        return { Status = "Unavailable", Error = "ProfileUnavailable" }
    end
    if type(payload) ~= "table" then
        return rejected("PayloadInvalid")
    end
    local context = contextOf(player, session.Data)
    if context.Kind ~= "Property" and context.Kind ~= "PublicGarage" then
        return rejected("NotInGarage")
    end
    local vehicle = VehicleOwnership.get(session.Data, payload.VehicleId)
    local definition = if vehicle then VehicleDefinitions.get(vehicle.ModelId) else nil
    if vehicle == nil or definition == nil then
        return rejected("VehicleNotOwned")
    end
    local result = session:commit(txId :: string, kind, function(profile)
        local ok, value = mutate(profile, definition, context.Capabilities)
        if not ok then
            return false, value
        end
        -- Lot 0.5 : main-d'œuvre du garage public facturée DANS la même
        -- mutation (tout ou rien) ; aucune dans un garage privé équipé.
        if context.Kind == "PublicGarage" then
            local fee = laborFee(kind, payload, value)
            if fee > 0 then
                local paid, err = Commerce.chargeLabor(profile, fee, "Labor:" .. kind, payload.VehicleId, now())
                if not paid then
                    return false, err
                end
                if type(value) == "table" then
                    value.Labor = fee
                end
            end
        end
        return true, value
    end)
    return reply(result, player)
end

handlers.SetTuning = function(player, payload, txId)
    return prepare(player, payload, txId, "SetTuning", function(profile, definition, capabilities)
        return Customization.setTuning(profile, payload.VehicleId, payload.Tuning, definition, capabilities, now())
    end)
end

handlers.SetCosmetics = function(player, payload, txId)
    return prepare(player, payload, txId, "SetCosmetics", function(profile, _definition, capabilities)
        return Customization.setCosmetics(profile, payload.VehicleId, payload.Cosmetics, capabilities, now())
    end)
end

handlers.SetPart = function(player, payload, txId)
    return prepare(player, payload, txId, "SetPart", function(profile, definition, capabilities)
        return Customization.setPart(
            profile,
            payload.VehicleId,
            payload.Slot,
            payload.PartId,
            definition,
            capabilities,
            now()
        )
    end)
end

handlers.SaveConfig = function(player, payload, txId)
    return prepare(player, payload, txId, "SaveConfig", function(profile, _definition, _capabilities)
        return Customization.saveConfiguration(profile, payload.VehicleId, payload.Index, payload.Name, now())
    end)
end

handlers.DeleteConfig = function(player, payload, txId)
    return prepare(player, payload, txId, "DeleteConfig", function(profile, _definition, _capabilities)
        return Customization.deleteConfiguration(profile, payload.VehicleId, payload.Index)
    end)
end

handlers.ApplyConfig = function(player, payload, txId)
    return prepare(player, payload, txId, "ApplyConfig", function(profile, definition, capabilities)
        return Customization.applyConfiguration(
            profile,
            payload.VehicleId,
            payload.Index,
            definition,
            capabilities,
            now()
        )
    end)
end

handlers.Invite = function(player, payload, txId)
    local session = activeSession(player)
    if session == nil then
        return { Status = "Unavailable", Error = "ProfileUnavailable" }
    end
    if type(payload) ~= "table" then
        return rejected("PayloadInvalid")
    end
    -- Identité vérifiée : l'invité doit être un joueur présent sur ce serveur.
    local guest = if type(payload.GuestUserId) == "number" then Players:GetPlayerByUserId(payload.GuestUserId) else nil
    if guest == nil then
        return rejected("InviteGuestNotPresent")
    end
    local result = session:commit(txId :: string, "Invite", function(profile)
        return InvitationRules.create(
            profile,
            payload.PropertyId,
            guest.UserId,
            payload.Visit == true,
            payload.Drive == true,
            payload.DurationS,
            now()
        )
    end)
    return reply(result, player)
end

handlers.RevokeInvite = function(player, payload, txId)
    local session = activeSession(player)
    if session == nil then
        return { Status = "Unavailable", Error = "ProfileUnavailable" }
    end
    local invitationId = if type(payload) == "table" then payload.InvitationId else nil
    local result = session:commit(txId :: string, "RevokeInvite", function(profile)
        return InvitationRules.revoke(profile, invitationId)
    end)
    -- L'application aux usages en cours est faite par la surveillance (battement).
    return reply(result, player)
end

handlers.Enter = function(player, payload)
    if type(payload) ~= "table" or type(payload.OwnerUserId) ~= "number" or type(payload.PropertyId) ~= "string" then
        return rejected("PayloadInvalid")
    end
    local root = rootOf(player)
    local humanoid = humanoidOf(player)
    if root == nil or humanoid == nil or humanoid.SeatPart ~= nil then
        return rejected("EnterOnFoot")
    end
    if PropertyInteriors.of(player) then
        return rejected("AlreadyInside")
    end
    local _, ownerSession = ProfileService.byUserId(payload.OwnerUserId)
    if ownerSession == nil or ownerSession.Data == nil then
        return rejected("OwnerNotPresent")
    end
    local owner = ownerSession.Data :: ProfileSchema.Profile
    local property = owner.Properties[payload.PropertyId]
    if property == nil then
        return rejected("PropertyUnknown")
    end
    local place = entranceOf(property)
    if place == nil or not Locations.within(place, root.Position) then
        return rejected("EnterNotAtEntrance")
    end
    if not InvitationRules.allows(owner, property.Id, player.UserId, "Visit", now()) then
        return rejected("EnterNotAllowed")
    end
    local interior = PropertyInteriors.open(
        owner.UserId,
        property.Id,
        PropertyRules.capacity(property),
        displayedOf(owner, property.Id),
        exitInterior
    )
    PropertyInteriors.occupy(interior, player)
    moveCharacter(player, PropertyInteriors.arrival(interior))
    return { Status = "Ok", Snapshot = snapshot(player) }
end

handlers.Exit = function(player)
    if PropertyInteriors.of(player) == nil then
        return rejected("NotInside")
    end
    exitInterior(player)
    return { Status = "Ok", Snapshot = snapshot(player) }
end

-- Lot 0.5 : les opérations payantes sont traitées par EconomyService (canal AWEconomy).

local function handle(player: Player, action: any, payload: any): Response
    if type(action) ~= "string" or handlers[action] == nil then
        return rejected("ActionUnknown")
    end
    local bucket = limiters[player]
    if bucket == nil then
        bucket = RateLimiter.new(8, 3, os.clock())
        limiters[player] = bucket
    end
    if not RateLimiter.consume(bucket, os.clock()) then
        return rejected("RateLimited")
    end
    if action ~= "Snapshot" and action ~= "CollectionPage" and moving(player) then
        return rejected("MenuWhileMoving")
    end
    local txId: string? = nil
    if ProgressionProtocol.Sensitive[action] and action ~= "ChooseStarter" then
        txId = TransactionService.clientTxId(if type(payload) == "table" then payload.RequestId else nil)
        if txId == nil then
            return rejected("RequestIdInvalid")
        end
    end
    local ok, response = pcall(handlers[action], player, payload, txId)
    if not ok then
        ProfileService.Log:write("Error", "HandlerFailed", { Action = action, Error = tostring(response) })
        return rejected("ServerError")
    end
    return response
end

-- ======================== Surveillance périodique ========================

local function watch()
    local time = now()
    -- Visites : droit retiré ou propriétaire parti → retour à l'entrée.
    for _, interior in PropertyInteriors.all() do
        local _, session = ProfileService.byUserId(interior.OwnerUserId)
        local owner = if session then session.Data else nil
        for occupant in interior.Occupants do
            if occupant.UserId ~= interior.OwnerUserId then
                if
                    owner == nil
                    or not InvitationRules.allows(
                        owner :: ProfileSchema.Profile,
                        interior.PropertyId,
                        occupant.UserId,
                        "Visit",
                        time
                    )
                then
                    exitInterior(occupant)
                    push:FireClient(occupant, "Notice", "VisitEnded")
                end
            end
        end
    end
    PropertyInteriors.collect(time, INTERIOR_COLLECT_S)
    -- Conduite prêtée retirée : arrêt en état sûr (descente une fois immobilisé).
    for owner, out in outVehicles do
        local driver, speed = VehicleService.personalDriver(out.Model)
        if driver and driver ~= owner and not mayDrive(owner.UserId)(driver) then
            if speed <= DRIVE_REVOKE_STOP_MS then
                VehicleService.ejectPersonalDriver(out.Model)
                revokeNotified[out.Model] = nil
            elseif not revokeNotified[out.Model] then
                revokeNotified[out.Model] = true
                push:FireClient(driver, "Notice", "DriveRevokedStop")
            end
        end
    end
end

-- Départ d'un joueur : véhicule rangé (état durable réconcilié), visites terminées.
local function onReleasing(player: Player, session: any)
    local out = outVehicles[player]
    if out then
        syncDurable(player)
        session:mutate(function(profile)
            return (GarageRules.bringBack(profile, out.VehicleId, now()))
        end)
        VehicleService.despawnPersonal(out.Model)
        outVehicles[player] = nil
    end
    local interior = PropertyInteriors.of(player)
    if interior then
        PropertyInteriors.leave(interior, player, now())
    end
    for _, other in PropertyInteriors.all() do
        if other.OwnerUserId == player.UserId then
            for occupant in other.Occupants do
                if occupant ~= player then
                    exitInterior(occupant)
                end
            end
        end
    end
    limiters[player] = nil
end

-- Invites d'entrée : chaque entrée de la carte (ou d'essai) reçoit une invite.
local function installPrompts(openWorld: Instance?, devZone: any)
    local function attach(part: BasePart, placeId: string, kind: string)
        local prompt = Instance.new("ProximityPrompt")
        prompt.Name = "AWProgressionPrompt"
        prompt.ActionText = if kind == "Entrance" then "Entrer" else "Préparer"
        prompt.ObjectText = if kind == "Entrance" then "Propriété" else "Garage public"
        prompt.HoldDuration = 0.3
        prompt.MaxActivationDistance = 20
        prompt.RequiresLineOfSight = false
        prompt.Parent = part
        prompt.Triggered:Connect(function(player)
            if kind ~= "Entrance" then
                push:FireClient(player, "Open", { Tab = "Garage", Place = placeId })
                return
            end
            -- Propriétés accessibles à cette entrée : les siennes et celles où l'on est invité.
            local options = {}
            local resolved = Locations.resolve(placeId)
            for _, owner in Players:GetPlayers() do
                local session = ProfileService.get(owner)
                local profile = if session then session.Data else nil
                if profile then
                    for _, property in (profile :: ProfileSchema.Profile).Properties do
                        local entrance = entranceOf(property)
                        if
                            entrance
                            and entrance.Id == resolved
                            and InvitationRules.allows(
                                profile :: ProfileSchema.Profile,
                                property.Id,
                                player.UserId,
                                "Visit",
                                now()
                            )
                        then
                            local offer = PropertyCatalog.offer(property.OfferId)
                            table.insert(options, {
                                OwnerUserId = owner.UserId,
                                OwnerName = owner.DisplayName,
                                PropertyId = property.Id,
                                Label = if offer then offer.Label else property.OfferId,
                            })
                        end
                    end
                end
            end
            push:FireClient(player, "EntranceOffer", { Place = placeId, Options = options })
        end)
    end
    if devZone then
        attach(devZone.Entrance, "DEV-ENTREE", "Entrance")
        attach(devZone.PublicGarage, "DEV-GARAGE", "PublicGarage")
        return
    end
    if openWorld == nil then
        return
    end
    for _, place in Locations.all() do
        -- Seuls les lieux de la progression (entrées, garages publics) ; les
        -- lieux économiques ont leur propre invite (EconomyService).
        if place.Kind ~= "Entrance" and place.Kind ~= "PublicGarage" then
            continue
        end
        local model = openWorld:FindFirstChild(place.Id, true)
        local slab = if model and model:IsA("Model") then model.PrimaryPart else nil
        if slab then
            attach(slab, place.Id, place.Kind)
        end
    end
end

--[[
    Démarrage. `openWorld` : modèle de la carte (place monde ouvert) ;
    `devZone` : zone d'essai (place de développement), qui fournit une entrée
    et un garage public d'essai.
]]
function ProgressionService.start(openWorld: Instance?, devZone: any)
    assert(not started, "ProgressionService déjà démarré")
    started = true
    if devZone then
        Locations.loadDev(devZone.Entrance, devZone.PublicGarage, devZone.Dealer, devZone.Station)
    else
        Locations.loadOpenWorld()
    end

    local existing = ReplicatedStorage:FindFirstChild(ProgressionProtocol.FolderName)
    if existing then
        existing:Destroy()
    end
    local folder = Instance.new("Folder")
    folder.Name = ProgressionProtocol.FolderName
    local request = Instance.new("RemoteFunction")
    request.Name = ProgressionProtocol.Request
    request.Parent = folder
    push = Instance.new("RemoteEvent")
    push.Name = ProgressionProtocol.Push
    push.Parent = folder
    folder.Parent = ReplicatedStorage

    request.OnServerInvoke = function(player: Player, action: any, payload: any): any
        return handle(player, action, payload)
    end

    installPrompts(openWorld, devZone)
    ProfileService.onReleasing(onReleasing)
    ProfileService.onLoaded(function(player)
        push:FireClient(player, "Snapshot", snapshot(player))
    end)
    ProfileService.onConfirmed(function(player, txIds)
        push:FireClient(player, "Confirmed", { Transactions = txIds, Snapshot = snapshot(player) })
    end)
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function()
            local interior = PropertyInteriors.of(player)
            if interior then
                PropertyInteriors.leave(interior, player, now())
            end
        end)
    end)

    local watchTimer, syncTimer = 0, 0
    RunService.Heartbeat:Connect(function(dt)
        watchTimer += dt
        syncTimer += dt
        if watchTimer >= 1 then
            watchTimer = 0
            watch()
        end
        if syncTimer >= DURABLE_SYNC_S then
            syncTimer = 0
            for player in outVehicles do
                syncDurable(player)
            end
        end
    end)
end

-- Pièces du catalogue (pour référence des emplacements dans l'interface).
ProgressionService.PartSlots = PartCatalog.Slots

-- Lot 0.5 : exemplaire personnel matérialisé d'un joueur (services, missions).
function ProgressionService.outVehicle(player: Player): (Model?, string?)
    local out = outVehicles[player]
    if out then
        return out.Model, out.VehicleId
    end
    return nil, nil
end

-- Lot 0.5 : réconciliation immédiate de l'état durable (avant un service payé).
function ProgressionService.syncDurable(player: Player)
    syncDurable(player)
end

-- Lot 0.5 : contexte de lieu (pour les services économiques).
function ProgressionService.context(player: Player): any
    local session = ProfileService.get(player)
    return contextOf(player, if session then session.Data else nil)
end

ProgressionService.snapshot = function(player: Player): any
    return snapshot(player)
end

return table.freeze(ProgressionService)
