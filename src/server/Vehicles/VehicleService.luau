--!strict
-- Service serveur des véhicules d'essai (autorité sur les états critiques).
--
-- Responsabilités :
-- - créer le parc de véhicules d'essai sur les plots (aucune possession) ;
-- - embarquement/sortie validés serveur, un conducteur par véhicule ;
-- - propriété réseau : conducteur pendant la conduite, serveur sinon ;
-- - simulation des véhicules stationnés (propriété serveur) ;
-- - contrôle de plausibilité des mouvements avec tolérance réseau ;
-- - remise sur roues limitée, retour au plot des véhicules abandonnés.
-- Aucun crédit, achat, récompense ni DataStore n'est manipulé ici.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local VehiclesShared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Vehicles")
local Types = require(VehiclesShared:WaitForChild("VehicleTypes"))
local Constants = require(VehiclesShared:WaitForChild("VehicleConstants"))
local VehicleDefinitions = require(VehiclesShared:WaitForChild("VehicleDefinitions"))
local VehicleSimulator = require(VehiclesShared:WaitForChild("VehicleSimulator"))
local InputCodec = require(VehiclesShared:WaitForChild("InputCodec"))

local VehicleFactory = require(script.Parent.VehicleFactory)
local TestZoneBuilder = require(script.Parent.Parent.World.TestZoneBuilder)
local MovementRules = require(script.Parent.Parent.Security.MovementRules)
local RateLimiter = require(script.Parent.Parent.Security.RateLimiter)

local METERS_PER_STUD = Constants.MetersPerStud
local VALIDATION_INTERVAL_S = 0.2
local CORRECTION_HOLD_S = 1.0
local UNFLIP_COOLDOWN_S = 8
local UNFLIP_MAX_SPEED_MS = 3
local MAINTENANCE_INTERVAL_S = 1
local RETURN_TO_PAD_AFTER_S = 90
local RETURN_DISTANCE_STUDS = 40
local NEARBY_PLAYER_STUDS = 25
local KILL_HEIGHT = -60
local BOARDING_DISTANCE_STUDS = 16
local SUSPICION_REVIEW_THRESHOLD = 10

type VehicleRecord = {
    Model: Model,
    Root: BasePart,
    Seat: Seat,
    Prompt: ProximityPrompt,
    Definition: Types.VehicleDefinition,
    HomePivot: CFrame,
    Driver: Player?,
    ServerOwned: boolean,
    Simulator: VehicleSimulator.VehicleSimulator,
    Asleep: boolean,
    CalmTimer: number,
    AwayTimer: number,
    LastSample: MovementRules.Sample?,
    LastValidPivot: CFrame,
    CorrectionUntil: number,
    UnflipReadyAt: number,
    SuspicionCount: number,
    LastSuspicionLog: number,
    LastSteer: number,
}

type Limiters = {
    Input: RateLimiter.Bucket,
    Action: RateLimiter.Bucket,
}

type Remotes = {
    Action: RemoteEvent,
    Input: UnreliableRemoteEvent,
    Notice: RemoteEvent,
}

local VehicleService = {}

local records: { VehicleRecord } = {}
local recordByDriver: { [Player]: VehicleRecord } = {}
local limiters: { [Player]: Limiters } = {}
local remotes: Remotes? = nil
local started = false

-- Messages envoyés au client par CLÉ (traduction côté client, FR/EN à venir).
local function notify(player: Player, key: string, value: number?)
    if remotes then
        remotes.Notice:FireClient(player, key, value)
    end
end

local function playerFromHumanoid(humanoid: Humanoid?): Player?
    if humanoid == nil then
        return nil
    end
    local character = humanoid.Parent
    if character == nil then
        return nil
    end
    return Players:GetPlayerFromCharacter(character)
end

local function limitersFor(player: Player): Limiters
    local existing = limiters[player]
    if existing then
        return existing
    end
    local now = os.clock()
    local created: Limiters = {
        -- Le client envoie ~15 messages/s ; on tolère des rafales (latence).
        Input = RateLimiter.new(40, 30, now),
        Action = RateLimiter.new(5, 2, now),
    }
    limiters[player] = created
    return created
end

local function sampleOf(record: VehicleRecord, now: number): MovementRules.Sample
    local position = record.Root.Position * METERS_PER_STUD
    return {
        Time = now,
        X = position.X,
        Y = position.Y,
        Z = position.Z,
        SpeedMs = record.Root.AssemblyLinearVelocity.Magnitude * METERS_PER_STUD,
    }
end

local function setOwner(record: VehicleRecord, player: Player?)
    local ok, err = pcall(function()
        record.Root:SetNetworkOwner(player)
    end)
    if not ok then
        warn("[AutomotiveWorld] Échec d'attribution de la propriété réseau : " .. tostring(err))
    end
    record.ServerOwned = player == nil
    if record.ServerOwned then
        -- Le serveur reprend la simulation avec un état neuf (frein à main serré).
        record.Simulator = VehicleSimulator.new(record.Model, record.Definition, { ReplicationFriendly = true })
        record.Asleep = false
        record.CalmTimer = 0
    end
end

-- Replace le véhicule sous contrôle serveur pendant un court instant, puis
-- rend la main au conducteur s'il est toujours à bord.
local function placeUnderServer(record: VehicleRecord, pivot: CFrame)
    local driver = record.Driver
    setOwner(record, nil)
    record.Model:PivotTo(pivot)
    record.Root.AssemblyLinearVelocity = Vector3.zero
    record.Root.AssemblyAngularVelocity = Vector3.zero
    record.CorrectionUntil = os.clock() + CORRECTION_HOLD_S
    record.LastSample = nil
    if driver then
        task.delay(CORRECTION_HOLD_S, function()
            if record.Driver == driver then
                setOwner(record, driver)
                record.LastSample = sampleOf(record, os.clock())
                record.LastValidPivot = record.Root.CFrame
            end
        end)
    end
end

local function uprightPivot(position: Vector3, look: Vector3): CFrame
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 0.1 then
        flat = Vector3.new(0, 0, -1)
    end
    return CFrame.lookAt(position, position + flat.Unit)
end

local function unseat(humanoid: Humanoid, seat: Seat)
    local weld = seat:FindFirstChild("SeatWeld")
    if weld then
        weld:Destroy()
    end
    humanoid.Sit = false
end

local function assignDriver(record: VehicleRecord, player: Player)
    record.Driver = player
    recordByDriver[player] = record
    record.Model:SetAttribute(Constants.Attributes.DriverUserId, player.UserId)
    record.Prompt.Enabled = false
    record.SuspicionCount = 0
    record.LastValidPivot = record.Root.CFrame
    setOwner(record, player)
    record.LastSample = sampleOf(record, os.clock())
end

local function releaseDriver(record: VehicleRecord)
    local driver = record.Driver
    if driver and recordByDriver[driver] == record then
        recordByDriver[driver] = nil
    end
    record.Driver = nil
    record.LastSample = nil
    record.LastSteer = 0
    record.AwayTimer = 0
    record.Model:SetAttribute(Constants.Attributes.DriverUserId, 0)
    record.Model:SetAttribute(Constants.Attributes.VisualSteer, 0)
    record.Prompt.Enabled = true
    setOwner(record, nil)
end

local function onOccupantChanged(record: VehicleRecord)
    local occupant = record.Seat.Occupant
    if occupant == nil then
        if record.Driver then
            releaseDriver(record)
        end
        return
    end
    local player = playerFromHumanoid(occupant)
    local alreadyDriving = if player then recordByDriver[player] else nil
    local unauthorized = player == nil
        or (record.Driver ~= nil and record.Driver ~= player)
        or (alreadyDriving ~= nil and alreadyDriving ~= record)
    if unauthorized then
        -- Occupation non validée par le serveur : le siège est libéré.
        unseat(occupant, record.Seat)
        return
    end
    if record.Driver == nil and player then
        assignDriver(record, player)
    end
end

local function onPromptTriggered(record: VehicleRecord, player: Player)
    if record.Driver ~= nil or record.Seat.Occupant ~= nil then
        notify(player, "VehicleBusy")
        return
    end
    if recordByDriver[player] ~= nil or os.clock() < record.CorrectionUntil then
        return
    end
    local character = player.Character
    if character == nil then
        return
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if humanoid == nil or humanoid.Health <= 0 or humanoid.SeatPart ~= nil then
        return
    end
    if not (rootPart and rootPart:IsA("BasePart")) then
        return
    end
    -- Revalidation de la distance (le client ne décide pas seul).
    if (rootPart.Position - record.Root.Position).Magnitude > BOARDING_DISTANCE_STUDS then
        return
    end
    record.Seat:Sit(humanoid)
end

-- Cherche un emplacement libre à côté du véhicule pour déposer le personnage.
local function findExitPivot(record: VehicleRecord, character: Model): CFrame?
    local root = record.Root
    local cframe = root.CFrame
    local halfWidth = record.Definition.Chassis.WidthM / METERS_PER_STUD / 2
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { record.Model, character }
    params.RespectCanCollide = true
    local flatRight = Vector3.new(cframe.RightVector.X, 0, cframe.RightVector.Z)
    if flatRight.Magnitude < 0.1 then
        flatRight = Vector3.xAxis
    end
    flatRight = flatRight.Unit
    local base = root.Position + Vector3.new(0, 1.5, 0)
    local candidates = {
        base - flatRight * (halfWidth + 3), -- côté conducteur (gauche)
        base + flatRight * (halfWidth + 3),
        base + Vector3.new(0, 7, 0),
    }
    for _, position in candidates do
        local pivot = uprightPivot(position, cframe.LookVector)
        local blocking = Workspace:GetPartBoundsInBox(pivot, Vector3.new(2.5, 5, 2.5), params)
        if #blocking == 0 then
            return pivot
        end
    end
    return nil
end

local function handleExit(record: VehicleRecord, player: Player)
    local seat = record.Seat
    local humanoid = seat.Occupant
    if humanoid == nil or playerFromHumanoid(humanoid) ~= player then
        return
    end
    local speedKmh = record.Root.AssemblyLinearVelocity.Magnitude * METERS_PER_STUD * 3.6
    local limit = record.Definition.Limits.ExitMaxSpeedKmh
    if speedKmh > limit then
        notify(player, "ExitTooFast", limit)
        return
    end
    local character = humanoid.Parent
    local exitPivot = if character and character:IsA("Model") then findExitPivot(record, character) else nil
    unseat(humanoid, seat)
    if exitPivot and character and character:IsA("Model") then
        task.defer(function()
            if character.Parent then
                character:PivotTo(exitPivot)
            end
        end)
    end
end

local function handleUnflip(record: VehicleRecord, player: Player)
    if record.Driver ~= player then
        return
    end
    local now = os.clock()
    if now < record.UnflipReadyAt then
        notify(player, "UnflipCooldown", math.ceil(record.UnflipReadyAt - now))
        return
    end
    local root = record.Root
    if root.AssemblyLinearVelocity.Magnitude * METERS_PER_STUD > UNFLIP_MAX_SPEED_MS then
        notify(player, "UnflipMoving")
        return
    end
    if root.CFrame.UpVector.Y > 0.5 then
        notify(player, "UnflipNotNeeded")
        return
    end
    -- Remise sur roues gratuite et limitée (cahier des charges §3.5) :
    -- position seulement, sans aucun autre effet (pas de réparation ni d'énergie).
    record.UnflipReadyAt = now + UNFLIP_COOLDOWN_S
    placeUnderServer(record, uprightPivot(root.Position + Vector3.new(0, 4, 0), root.CFrame.LookVector))
    notify(player, "UnflipDone")
end

local function correctMovement(record: VehicleRecord, reason: string)
    local driver = record.Driver
    warn(
        string.format(
            "[AutomotiveWorld][Validation] Mouvement impossible (%s) sur %s, conducteur %s : position corrigée, aucune sanction.",
            reason,
            tostring(record.Model:GetAttribute(Constants.Attributes.VehicleId)),
            if driver then tostring(driver.UserId) else "aucun"
        )
    )
    placeUnderServer(record, record.LastValidPivot)
    if driver then
        notify(driver, "MovementCorrected")
    end
end

local function validateMovements(now: number)
    for _, record in records do
        if record.Driver == nil or record.ServerOwned or now < record.CorrectionUntil then
            continue
        end
        local current = sampleOf(record, now)
        local previous = record.LastSample
        record.LastSample = current
        if previous == nil then
            continue
        end
        local maxSpeedMs = record.Definition.Limits.MaxPlausibleSpeedKmh / 3.6
        local verdict, reason = MovementRules.evaluate(previous, current, maxSpeedMs)
        if verdict == "Impossible" then
            correctMovement(record, reason or "Inconnu")
        elseif verdict == "Suspicious" then
            record.SuspicionCount += 1
            if now - record.LastSuspicionLog > 5 then
                record.LastSuspicionLog = now
                warn(
                    string.format(
                        "[AutomotiveWorld][Validation] Mouvement inhabituel (%s), toléré. Occurrences : %d",
                        reason or "?",
                        record.SuspicionCount
                    )
                )
            end
            if record.SuspicionCount == SUSPICION_REVIEW_THRESHOLD then
                warn(
                    "[AutomotiveWorld][Validation] Seuil d'examen atteint : à vérifier manuellement (aucune sanction automatique)."
                )
            end
        else
            record.LastValidPivot = record.Root.CFrame
        end
    end
end

-- Simulation serveur d'un véhicule stationné. Une fois immobile, le véhicule
-- « s'endort » : les forces restent constantes et ne sont plus réécrites
-- (pas de réplication inutile) jusqu'à la prochaine perturbation.
local function stepServerVehicle(record: VehicleRecord, dt: number)
    local root = record.Root
    local linear = root.AssemblyLinearVelocity.Magnitude
    local angular = root.AssemblyAngularVelocity.Magnitude
    if record.Asleep then
        if linear > 0.6 or angular > 0.2 then
            record.Asleep = false
            record.CalmTimer = 0
        else
            return
        end
    end
    record.Simulator:step(InputCodec.Parked, dt)
    if linear < 0.15 and angular < 0.05 then
        record.CalmTimer += dt
        if record.CalmTimer > 2 then
            record.Asleep = true
        end
    else
        record.CalmTimer = 0
    end
end

local function anyPlayerNear(position: Vector3, radius: number): boolean
    for _, player in Players:GetPlayers() do
        local character = player.Character
        local pivot = if character then character:GetPivot() else nil
        if pivot and (pivot.Position - position).Magnitude < radius then
            return true
        end
    end
    return false
end

local function maintainParkedVehicles()
    for _, record in records do
        if record.Driver ~= nil then
            record.AwayTimer = 0
            continue
        end
        local position = record.Root.Position
        if position.Y < KILL_HEIGHT then
            placeUnderServer(record, record.HomePivot)
            continue
        end
        if (position - record.HomePivot.Position).Magnitude > RETURN_DISTANCE_STUDS then
            record.AwayTimer += MAINTENANCE_INTERVAL_S
            if record.AwayTimer >= RETURN_TO_PAD_AFTER_S and not anyPlayerNear(position, NEARBY_PLAYER_STUDS) then
                record.AwayTimer = 0
                placeUnderServer(record, record.HomePivot)
            end
        else
            record.AwayTimer = 0
        end
    end
end

local function createRemotes(): Remotes
    local existing = ReplicatedStorage:FindFirstChild(Constants.RemotesFolderName)
    if existing then
        existing:Destroy()
    end
    local folder = Instance.new("Folder")
    folder.Name = Constants.RemotesFolderName
    local action = Instance.new("RemoteEvent")
    action.Name = Constants.Remotes.Action
    action.Parent = folder
    local input = Instance.new("UnreliableRemoteEvent")
    input.Name = Constants.Remotes.Input
    input.Parent = folder
    local notice = Instance.new("RemoteEvent")
    notice.Name = Constants.Remotes.Notice
    notice.Parent = folder
    folder.Parent = ReplicatedStorage
    return { Action = action, Input = input, Notice = notice }
end

local function onInput(player: Player, payload: any)
    if not RateLimiter.consume(limitersFor(player).Input, os.clock()) then
        return
    end
    local record = recordByDriver[player]
    if record == nil then
        return
    end
    local input = InputCodec.decode(payload)
    if input == nil then
        return
    end
    -- Le serveur ne simule pas le véhicule piloté : la commande ne sert qu'à
    -- l'affichage du braquage chez les autres joueurs (valeur bornée).
    local steer = math.round(input.Steer * 20) / 20
    if steer ~= record.LastSteer then
        record.LastSteer = steer
        record.Model:SetAttribute(Constants.Attributes.VisualSteer, steer)
    end
end

local function onAction(player: Player, action: any)
    if not RateLimiter.consume(limitersFor(player).Action, os.clock()) then
        return
    end
    if type(action) ~= "string" then
        return
    end
    local record = recordByDriver[player]
    if record == nil then
        return
    end
    if action == Constants.Actions.Exit then
        handleExit(record, player)
    elseif action == Constants.Actions.Unflip then
        handleUnflip(record, player)
    end
end

function VehicleService.start(zone: TestZoneBuilder.TestZone)
    assert(not started, "VehicleService déjà démarré")
    started = true

    local createdRemotes = createRemotes()
    remotes = createdRemotes
    createdRemotes.Input.OnServerEvent:Connect(onInput)
    createdRemotes.Action.OnServerEvent:Connect(onAction)

    local definition = VehicleDefinitions.get(VehicleDefinitions.DefaultTestVehicleId)
    assert(definition, "Définition du véhicule d'essai introuvable")

    local folder = Instance.new("Folder")
    folder.Name = "VehiculesEssai"
    folder.Parent = Workspace

    for index, pad in zone.Pads do
        local pivot = VehicleFactory.spawnPivotForPad(definition, pad)
        local model = VehicleFactory.create(definition, pivot, index)
        model.Parent = folder
        local root = model.PrimaryPart :: BasePart
        local seat = model:FindFirstChild("DriverSeat") :: Seat
        local door = root:FindFirstChild("DriverDoor") :: Attachment
        local prompt = door:FindFirstChild("EnterPrompt") :: ProximityPrompt

        local record: VehicleRecord = {
            Model = model,
            Root = root,
            Seat = seat,
            Prompt = prompt,
            Definition = definition,
            HomePivot = pivot,
            Driver = nil,
            ServerOwned = true,
            Simulator = VehicleSimulator.new(model, definition, { ReplicationFriendly = true }),
            Asleep = false,
            CalmTimer = 0,
            AwayTimer = 0,
            LastSample = nil,
            LastValidPivot = pivot,
            CorrectionUntil = 0,
            UnflipReadyAt = 0,
            SuspicionCount = 0,
            LastSuspicionLog = 0,
            LastSteer = 0,
        }
        table.insert(records, record)
        setOwner(record, nil)

        seat:GetPropertyChangedSignal("Occupant"):Connect(function()
            onOccupantChanged(record)
        end)
        prompt.Triggered:Connect(function(player)
            onPromptTriggered(record, player)
        end)
    end

    RunService.PreSimulation:Connect(function(dt)
        for _, record in records do
            if record.ServerOwned then
                stepServerVehicle(record, dt)
            end
        end
    end)

    local validationTimer, maintenanceTimer = 0, 0
    RunService.Heartbeat:Connect(function(dt)
        validationTimer += dt
        maintenanceTimer += dt
        if validationTimer >= VALIDATION_INTERVAL_S then
            validationTimer = 0
            validateMovements(os.clock())
        end
        if maintenanceTimer >= MAINTENANCE_INTERVAL_S then
            maintenanceTimer = 0
            maintainParkedVehicles()
        end
    end)

    Players.PlayerRemoving:Connect(function(player)
        local record = recordByDriver[player]
        if record then
            releaseDriver(record)
        end
        limiters[player] = nil
    end)

    print(string.format("[AutomotiveWorld] %d véhicules d'essai « %s » prêts", #records, definition.DisplayName))
end

return VehicleService
