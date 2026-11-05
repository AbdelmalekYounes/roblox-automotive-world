--!strict
-- Service serveur des véhicules d'essai (autorité sur les états critiques).
--
-- Responsabilités :
-- - créer le parc de véhicules d'essai sur les plots (aucune possession) ;
-- - embarquement/sortie validés serveur, un conducteur par véhicule ;
-- - propriété réseau : conducteur pendant la conduite, serveur sinon ;
-- - simulation des véhicules stationnés (propriété serveur) ;
-- - contrôle de plausibilité des mouvements avec tolérance réseau ;
-- - remise sur roues limitée, retour au plot des véhicules abandonnés ;
-- - lot 0.2 : énergie de session (plancher physique serveur, voir EnergyModel),
--   état des aides et de la récupération (validés selon l'équipement du modèle),
--   dégâts confirmés serveur (DamageService), mesures de coût.
-- Aucun crédit, achat, récompense ni DataStore n'est manipulé ici : l'énergie et
-- les dégâts n'existent que pendant la session technique (persistance : lot 0.4).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local VehiclesShared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Vehicles")
local Types = require(VehiclesShared:WaitForChild("VehicleTypes"))
local Constants = require(VehiclesShared:WaitForChild("VehicleConstants"))
local PassengerRules = require(VehiclesShared:WaitForChild("PassengerRules"))
local VehicleDefinitions = require(VehiclesShared:WaitForChild("VehicleDefinitions"))
local VehicleSimulator = require(VehiclesShared:WaitForChild("VehicleSimulator"))
local InputCodec = require(VehiclesShared:WaitForChild("InputCodec"))
local PerfStats = require(VehiclesShared:WaitForChild("PerfStats"))
local EnergyModel = require(VehiclesShared:WaitForChild("Physics"):WaitForChild("EnergyModel"))

local VehicleFactory = require(script.Parent.VehicleFactory)
local NetworkOwnership = require(script.Parent.NetworkOwnership)
local CollisionMediator = require(script.Parent.CollisionMediator)
local DamageService = require(script.Parent.DamageService)
local CollisionExchange = require(VehiclesShared:WaitForChild("Physics"):WaitForChild("CollisionExchange"))
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
local NEARBY_VEHICLE_STUDS = 40
local KILL_HEIGHT = -60
local BOARDING_DISTANCE_STUDS = 16
local EXIT_PLACEMENT_ATTEMPTS = 3
local EXIT_PLACEMENT_CHECK_S = 0.3
local EJECT_ATTEMPTS = 3
local EJECT_CHECK_S = 1.2
local SUSPICION_REVIEW_THRESHOLD = 10
-- Écart minimal (unités de réserve) avant de republier le niveau d'énergie.
local ENERGY_PUBLISH_STEP = 0.002
-- Repositionnement serveur : délai sans détection de choc.
local DAMAGE_SUSPEND_S = 1.5

-- Exemplaire PERSONNEL d'un joueur (lot 0.4), matérialisé par ProgressionService.
type PersonalInfo = {
    OwnerUserId: number,
    VehicleId: string,
    -- Session protégée (essai, lots futurs) : rien n'est réécrit dans le profil.
    Protected: boolean,
    -- Droit de conduire, vérifié à chaque embarquement (propriétaire, invités).
    MayDrive: (Player) -> boolean,
    -- Distance mesurée par le serveur depuis la dernière lecture (m).
    DistanceM: number,
    LastPosition: Vector3?,
    Since: number,
}

type VehicleRecord = {
    Model: Model,
    Root: BasePart,
    Seat: Seat,
    Prompt: ProximityPrompt,
    -- Lot 0.8 : place passager (absente sur les prototypes sans habitacle).
    Passenger: Seat?,
    -- Lot VEH3D-01 : occupant actuel de la place passager (placement à sa sortie).
    PassengerHumanoid: Humanoid?,
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
    OwnershipFailures: number,
    LastServerSpeed: number,
    LastEjectionLog: number,
    -- Énergie de session (autorité serveur).
    Energy: EnergyModel.Account,
    -- Dernier cumul déclaré par le conducteur (simple déclaration, voir EnergyModel).
    ClientEnergy: number?,
    EnergySample: { Time: number, SpeedMs: number, Y: number }?,
    PublishedEnergy: number,
    -- Véhicule de banc d'essai de charge (Studio uniquement) : commande scriptée.
    BenchInput: Types.DriverInput?,
    -- Collisions entre joueurs : participant du médiateur (absent pour un banc).
    Participant: CollisionMediator.Participant?,
    Personal: PersonalInfo?,
    -- Lot 0.5 : corrections de mouvement subies (une mission en cours est annulée).
    Corrections: number?,
}

type Limiters = {
    Input: RateLimiter.Bucket,
    Action: RateLimiter.Bucket,
}

type Remotes = {
    Action: RemoteEvent,
    Input: UnreliableRemoteEvent,
    Notice: RemoteEvent,
    Impulse: RemoteEvent,
}

local VehicleService = {}

local records: { VehicleRecord } = {}
local recordByDriver: { [Player]: VehicleRecord } = {}
local damage = DamageService.new()
-- Coût mesuré côté serveur (secondes) : simulation des véhicules qu'il possède
-- (par véhicule et par pas) et battement complet (médiation, dégâts, validation).
local serverVehicleStep = PerfStats.new(4000)
local serverHeartbeat = PerfStats.new(1200)
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

--[[
    Sorties (lot VEH3D-01, accord du propriétaire du 2026-11-05 : « Corrige les sorties »). Un occupant assis se trouve
    DANS le volume de collision de l'habitacle (boîte `Habitacle` d'un kit de maillages, parois d'une carrosserie
    provisoire) : soudé au siège, il fait partie de l'assemblage du véhicule ; libéré, le moteur physique l'expulsait
    de ce volume (conducteur projeté et couché, passager sur le toit : QA-A15, A16, A18 ; Comète : 16 sorties sur 16
    en échec, tâche 20261105-015804). L'occupant passe donc dans le groupe `Exiting`, sans collision avec les
    véhicules, dès qu'il s'assied et jusqu'à son placement à côté du véhicule ; son groupe d'origine est ensuite rendu.
]]
local EXIT_RESTORE_S = 0.6 -- après le placement vérifié : le personnage est hors du volume du véhicule
local EXIT_ORPHAN_S = 3 -- debout sans placement (sortie par un autre chemin) : groupe rendu après ce délai
type ExitState = { Groups: { [BasePart]: string }, Added: RBXScriptConnection, Placing: boolean }
local exiting: { [Model]: ExitState } = {}

local function endExiting(character: Model)
    local state = exiting[character]
    if state == nil then
        return
    end
    exiting[character] = nil
    state.Added:Disconnect()
    for part, group in state.Groups do
        if part.Parent and part.CollisionGroup == Constants.CollisionGroups.Exiting then
            -- La protection d'arrivée (OnboardingService) prend fin en montant en voiture : jamais rendue ici.
            part.CollisionGroup = if group == Constants.CollisionGroups.Protected then "Default" else group
        end
    end
end

local function setExiting(character: Model)
    if exiting[character] then
        return
    end
    local groups: { [BasePart]: string } = {}
    local function shield(item: Instance)
        if item:IsA("BasePart") and groups[item] == nil then
            groups[item] = item.CollisionGroup
            item.CollisionGroup = Constants.CollisionGroups.Exiting
        end
    end
    for _, item in character:GetDescendants() do
        shield(item)
    end
    local state: ExitState = { Groups = groups, Added = character.DescendantAdded:Connect(shield), Placing = false }
    exiting[character] = state
    character.Destroying:Once(function()
        if exiting[character] == state then
            exiting[character] = nil
            state.Added:Disconnect()
        end
    end)
    -- Garde-fou : jamais de personnage durablement sans collision avec les véhicules.
    task.spawn(function()
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local standing = 0
        while exiting[character] == state do
            task.wait(0.5)
            local free = humanoid == nil or humanoid.SeatPart == nil
            standing = if free and not state.Placing then standing + 0.5 else 0
            if standing >= EXIT_ORPHAN_S then
                endExiting(character)
            end
        end
    end)
end

local function unseatHumanoid(humanoid: Humanoid, seat: Seat)
    local weld = seat:FindFirstChild("SeatWeld")
    if weld then
        weld:Destroy()
    end
    humanoid.Sit = false
end

-- Défini plus bas (a besoin du placement de sortie) : sort un occupant refusé
-- ou qui ne peut plus conduire.
local ejectOccupant: (record: VehicleRecord, humanoid: Humanoid) -> ()

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

local function ownershipPort(record: VehicleRecord): NetworkOwnership.Port<Player>
    return {
        set = function(owner: Player?)
            record.Root:SetNetworkOwner(owner)
        end,
        get = function(): Player?
            return record.Root:GetNetworkOwner()
        end,
    }
end

-- Désigne QUI simule le véhicule : le serveur (owner = nil) ou le conducteur.
-- Jamais les deux : le serveur ne simule que si ServerOwned, et le client ne
-- simule que si l'attribut SimulationOwnerUserId porte son UserId.
local function applySimulationOwner(record: VehicleRecord, owner: Player?)
    local becomesServerOwned = owner == nil and not record.ServerOwned
    record.ServerOwned = owner == nil
    if becomesServerOwned then
        -- Vitesse horizontale au moment de la reprise (sortie en roulant, ≤ 20 km/h) :
        -- référence de la borne d'éjection, pour ne pas freiner un véhicule qui roule.
        local velocity = record.Root.AssemblyLinearVelocity * METERS_PER_STUD
        record.LastServerSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
    end
    if record.ServerOwned then
        -- Le serveur reprend la simulation avec un état neuf (frein à main serré).
        record.Simulator = VehicleSimulator.new(record.Model, record.Definition, { ReplicationFriendly = true })
        record.Asleep = false
        record.CalmTimer = 0
    end
    if owner then
        record.Model:SetAttribute(Constants.Attributes.SimulationPivot, record.Root.CFrame)
    end
    record.Model:SetAttribute(Constants.Attributes.SimulationOwnerUserId, if owner then owner.UserId else 0)
end

-- Change la propriété réseau et ne met à jour l'état interne qu'une fois
-- l'attribution CONFIRMÉE par le moteur. En cas de refus, le serveur garde
-- (ou reprend) la simulation et la fonction renvoie false : à l'appelant de
-- traiter le conducteur (voir recoverDriver).
local function setOwner(record: VehicleRecord, player: Player?): boolean
    local port = ownershipPort(record)
    local outcome, detail = NetworkOwnership.transfer(port, player)
    if outcome == "Applied" then
        applySimulationOwner(record, player)
        return true
    end
    warn(
        string.format(
            "[AutomotiveWorld] Propriété réseau non appliquée sur %s (demandée : %s) : %s — %s",
            tostring(record.Model:GetAttribute(Constants.Attributes.VehicleId)),
            if player then tostring(player.UserId) else "serveur",
            outcome,
            detail or "?"
        )
    )
    if player ~= nil then
        -- Récupération sûre : retour explicite au serveur (si le moteur l'accepte).
        NetworkOwnership.transfer(port, nil)
    end
    applySimulationOwner(record, nil)
    return false
end

-- Le conducteur ne peut pas (ou plus) simuler le véhicule : il est sorti du
-- siège, sans sanction ; le véhicule reste simulé par le serveur.
local function recoverDriver(record: VehicleRecord)
    local occupant = record.Seat.Occupant
    local driver = record.Driver
    if occupant then
        ejectOccupant(record, occupant)
    end
    if driver then
        notify(driver, "VehicleUnavailable")
    end
end

-- Replace le véhicule sous contrôle serveur pendant un court instant, puis
-- rend la main au conducteur s'il est toujours à bord.
local function placeUnderServer(record: VehicleRecord, pivot: CFrame)
    local driver = record.Driver
    setOwner(record, nil)
    damage:suspend(record.Model, DAMAGE_SUSPEND_S + CORRECTION_HOLD_S)
    record.EnergySample = nil
    record.Model:PivotTo(pivot)
    record.Root.AssemblyLinearVelocity = Vector3.zero
    record.Root.AssemblyAngularVelocity = Vector3.zero
    record.CorrectionUntil = os.clock() + CORRECTION_HOLD_S
    record.LastSample = nil
    if driver then
        task.delay(CORRECTION_HOLD_S, function()
            if record.Driver ~= driver then
                return
            end
            if setOwner(record, driver) then
                record.LastSample = sampleOf(record, os.clock())
                record.LastValidPivot = record.Root.CFrame
            else
                recoverDriver(record)
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

-- Renvoie true si la propriété réseau a été confirmée ; sinon rien n'est
-- attribué et le serveur garde la simulation.
local function assignDriver(record: VehicleRecord, player: Player): boolean
    if not setOwner(record, player) then
        return false
    end
    record.Driver = player
    recordByDriver[player] = record
    -- Nouvelle session de conduite : toutes les aides présentes repartent
    -- DÉSACTIVÉES et la récupération à son niveau par défaut (§1.2).
    for _, aid in Constants.AidNames do
        record.Model:SetAttribute((Constants.Attributes :: any)["Aid" .. aid], false)
    end
    record.Model:SetAttribute(Constants.Attributes.RegenLevel, 1)
    EnergyModel.beginDriving(record.Energy)
    record.ClientEnergy = nil
    record.EnergySample = nil
    record.Model:SetAttribute(Constants.Attributes.DriverUserId, player.UserId)
    record.Prompt.Enabled = false
    record.SuspicionCount = 0
    record.OwnershipFailures = 0
    record.LastValidPivot = record.Root.CFrame
    record.LastSample = sampleOf(record, os.clock())
    return true
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
    record.Model:SetAttribute(Constants.Attributes.VisualBrake, false)
    -- Plus de conducteur : plus de son de moteur publié (le véhicule garé est silencieux chez les autres).
    record.Model:SetAttribute(Constants.Attributes.AudioRpm, nil)
    record.Model:SetAttribute(Constants.Attributes.AudioLoad, nil)
    -- Lot AUDIO-03 : plus de glissement publié (le roulement reste déduit de la vitesse).
    record.Model:SetAttribute(Constants.Attributes.AudioTireSlip, nil)
    record.Model:SetAttribute(Constants.Attributes.AudioTireSurface, nil)
    record.Prompt.Enabled = true
    setOwner(record, nil)
end

local function onOccupantChanged(record: VehicleRecord)
    local occupant = record.Seat.Occupant
    local seatedCharacter = occupant and occupant.Parent
    if seatedCharacter and seatedCharacter:IsA("Model") then
        setExiting(seatedCharacter)
    end
    if occupant == nil then
        if record.Driver then
            releaseDriver(record)
        end
        return
    end
    local player = playerFromHumanoid(occupant)
    local alreadyDriving = if player then recordByDriver[player] else nil
    local personal = record.Personal
    local refusedPersonal = false
    if personal and player then
        refusedPersonal = not personal.MayDrive(player)
    end
    local unauthorized = player == nil
        or (record.Driver ~= nil and record.Driver ~= player)
        or (alreadyDriving ~= nil and alreadyDriving ~= record)
        or refusedPersonal
    if unauthorized then
        -- Occupation non validée par le serveur : le siège est libéré.
        ejectOccupant(record, occupant)
        return
    end
    if record.Driver == nil and player and not assignDriver(record, player) then
        -- Propriété réseau refusée : pas de conduite possible, siège libéré.
        ejectOccupant(record, occupant)
        notify(player, "VehicleUnavailable")
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
    -- Exemplaire personnel : seuls le propriétaire et ses invités autorisés à conduire.
    if record.Personal and not record.Personal.MayDrive(player) then
        notify(player, "VehicleNotYours")
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

-- Groupes (lot 0.7) : branchés au démarrage, sans dépendance de ce module vers Social.
local sameGroup: (number, number) -> boolean = function(_a: number, _b: number): boolean
    return false
end

local function passengerContext(record: VehicleRecord, player: Player): PassengerRules.Context
    return {
        OwnerUserId = if record.Personal then record.Personal.OwnerUserId else nil,
        DriverUserId = if record.Driver then record.Driver.UserId else nil,
        RiderUserId = player.UserId,
    }
end

-- Place passager : mêmes revalidations que pour conduire, règle PassengerRules.
local function onPassengerPrompt(record: VehicleRecord, player: Player)
    local passenger = record.Passenger
    if passenger == nil or passenger.Occupant ~= nil then
        notify(player, "VehicleBusy")
        return
    end
    local allowed, reason = PassengerRules.mayRide(passengerContext(record, player), sameGroup)
    if not allowed then
        notify(player, reason or "PassengerNotAllowed")
        return
    end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if humanoid == nil or humanoid.Health <= 0 or humanoid.SeatPart ~= nil then
        return
    end
    if not (rootPart and rootPart:IsA("BasePart")) then
        return
    end
    if (rootPart.Position - record.Root.Position).Magnitude > BOARDING_DISTANCE_STUDS then
        return
    end
    passenger:Sit(humanoid)
end

-- Occupation passager non validée (siège pris autrement) : libérée aussitôt.
local placeBeside: (record: VehicleRecord, humanoid: Humanoid, character: Model, side: number) -> ()

local function onPassengerChanged(record: VehicleRecord)
    local passenger = record.Passenger
    local occupant = if passenger then passenger.Occupant else nil
    if passenger == nil then
        return
    end
    if occupant == nil then
        -- Sortie du passager (saut du moteur, vraie touche Espace) : placé côté passager (QA-A15).
        local previous = record.PassengerHumanoid
        record.PassengerHumanoid = nil
        local character = previous and previous.Parent
        if previous and character and character:IsA("Model") then
            placeBeside(record, previous, character, 1)
        end
        return
    end
    record.PassengerHumanoid = occupant
    local seatedCharacter = occupant.Parent
    if seatedCharacter and seatedCharacter:IsA("Model") then
        setExiting(seatedCharacter)
    end
    local player = playerFromHumanoid(occupant)
    if
        player == nil
        or recordByDriver[player] ~= nil
        or not PassengerRules.mayRide(passengerContext(record, player), sameGroup)
    then
        unseatHumanoid(occupant, passenger)
    end
end

-- Cherche un emplacement libre à côté du véhicule pour déposer le personnage.
local function findExitPivot(record: VehicleRecord, character: Model, side: number?): CFrame?
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
    local left, right = base - flatRight * (halfWidth + 3), base + flatRight * (halfWidth + 3)
    -- Côté de la place d'abord (conducteur à gauche, passager à droite), puis l'autre, puis au-dessus.
    local candidates: { Vector3 } = if side == 1
        then { right, left, base + Vector3.new(0, 7, 0) }
        else { left, right, base + Vector3.new(0, 7, 0) }
    for _, position in candidates do
        local pivot = uprightPivot(position, cframe.LookVector)
        local blocking = Workspace:GetPartBoundsInBox(pivot, Vector3.new(2.5, 5, 2.5), params)
        if #blocking == 0 then
            return pivot
        end
    end
    return nil
end

local releaseCharacter: (record: VehicleRecord, humanoid: Humanoid) -> ()

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
    releaseCharacter(record, humanoid)
end

-- Dépose le personnage libéré à côté du véhicule (côté `side` : −1 gauche, 1 droite), vérifié, puis lui rend son
-- groupe de collision. Le personnage appartient (réseau) à son joueur : un déplacement imposé par le serveur pendant
-- que le client reprend la main peut être écrasé par la position envoyée par ce client (constaté en essai à deux
-- joueurs). On attend donc la libération effective du siège, on place, on vérifie et on recommence si nécessaire.
function placeBeside(record: VehicleRecord, humanoid: Humanoid, character: Model, side: number)
    local exitPivot = findExitPivot(record, character, side)
    local state = exiting[character]
    if state then
        state.Placing = true
    end
    task.spawn(function()
        local deadline = os.clock() + 1
        while humanoid.SeatPart ~= nil and os.clock() < deadline do
            task.wait()
        end
        if exitPivot then
            for _ = 1, EXIT_PLACEMENT_ATTEMPTS do
                if character.Parent == nil then
                    break
                end
                character:PivotTo(exitPivot)
                task.wait(EXIT_PLACEMENT_CHECK_S)
                if (character:GetPivot().Position - exitPivot.Position).Magnitude < 3 then
                    break
                end
            end
        end
        task.wait(EXIT_RESTORE_S)
        -- Rassis entre-temps (autre place, même véhicule) : il garde le groupe de sortie.
        if state then
            state.Placing = false
        end
        if humanoid.SeatPart == nil then
            endExiting(character)
        end
    end)
end

-- Libère le siège conducteur puis dépose le personnage à côté du véhicule.
function releaseCharacter(record: VehicleRecord, humanoid: Humanoid)
    local seat = record.Seat
    local character = humanoid.Parent
    unseatHumanoid(humanoid, seat)
    if character and character:IsA("Model") then
        placeBeside(record, humanoid, character, -1)
    end
end

-- Différé puis vérifié : mesuré dans Studio, une sortie demandée pendant le
-- changement d'occupant (avant que la soudure du siège n'existe) laissait le
-- personnage assis. Le siège fait foi (`Seat.Occupant`), pas l'état du personnage.
function ejectOccupant(record: VehicleRecord, humanoid: Humanoid)
    task.defer(function()
        for _ = 1, EJECT_ATTEMPTS do
            if humanoid.Parent == nil or (record.Seat.Occupant ~= humanoid and humanoid.SeatPart == nil) then
                return
            end
            releaseCharacter(record, humanoid)
            task.wait(EJECT_CHECK_S)
        end
    end)
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
    -- position seulement, sans aucun autre effet : ni réparation des dégâts, ni
    -- énergie (vérifié par les essais du lot 0.2).
    record.UnflipReadyAt = now + UNFLIP_COOLDOWN_S
    placeUnderServer(record, uprightPivot(root.Position + Vector3.new(0, 4, 0), root.CFrame.LookVector))
    notify(player, "UnflipDone")
end

local function correctMovement(record: VehicleRecord, reason: string)
    local driver = record.Driver
    record.Corrections = (record.Corrections or 0) + 1
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

local function publishEnergy(record: VehicleRecord, force: boolean?)
    local account = record.Energy
    local model = record.Model
    if force or math.abs(account.Level - record.PublishedEnergy) >= ENERGY_PUBLISH_STEP or account.Empty then
        record.PublishedEnergy = account.Level
        model:SetAttribute(Constants.Attributes.EnergyLevel, account.Level)
    end
    if model:GetAttribute(Constants.Attributes.EnergyEmpty) ~= account.Empty then
        model:SetAttribute(Constants.Attributes.EnergyEmpty, account.Empty)
        if account.Empty then
            warn(
                string.format(
                    "[AutomotiveWorld][Énergie] Réserve vide sur %s : plus de propulsion, aucune recharge gratuite.",
                    tostring(model:GetAttribute(Constants.Attributes.VehicleId))
                )
            )
        end
    end
end

--[[
    Règlement de l'énergie d'un véhicule conduit, à partir de ce que le serveur
    observe (vitesse et altitude répliquées) : plancher physique + déclaration
    bornée du client (EnergyModel.settle). Rien pendant une correction.
]]
local function settleEnergy(record: VehicleRecord, now: number)
    if record.Driver == nil or record.ServerOwned or now < record.CorrectionUntil then
        record.EnergySample = nil
        return
    end
    local speed = record.Root.AssemblyLinearVelocity.Magnitude * METERS_PER_STUD
    local y = record.Root.Position.Y * METERS_PER_STUD
    local previous = record.EnergySample
    record.EnergySample = { Time = now, SpeedMs = speed, Y = y }
    if previous == nil then
        return
    end
    local dt = now - previous.Time
    if dt <= 0 then
        return
    end
    local used, recovered =
        EnergyModel.physicsFloor(record.Definition, previous.SpeedMs, speed, (y - previous.Y) / dt, dt)
    EnergyModel.settle(record.Energy, record.Definition, used, recovered, record.ClientEnergy, dt)
    publishEnergy(record)
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

-- Borne physique de la vitesse d'un véhicule simulé par le serveur (m/s) :
-- jamais plus de 2 fois la vitesse du véhicule le plus rapide à proximité (choc
-- élastique), ni une accélération démesurée d'un pas à l'autre. Neutralise les
-- éjections numériques (mesurées : 79 et 250 st) quand la copie répliquée d'un
-- véhicule piloté pénètre un véhicule garé. Aucune téléportation : seule la
-- vitesse est ramenée à la borne, et l'événement est journalisé.
local function limitImplausibleSpeed(record: VehicleRecord)
    local root = record.Root
    local velocity = root.AssemblyLinearVelocity * METERS_PER_STUD
    local nearbyMax = 0
    for _, other in records do
        if other ~= record and (other.Root.Position - root.Position).Magnitude < NEARBY_VEHICLE_STUDS then
            nearbyMax = math.max(nearbyMax, other.Root.AssemblyLinearVelocity.Magnitude * METERS_PER_STUD)
        end
    end
    local vx, vy, vz, limited =
        CollisionExchange.limitServerVelocity(velocity.X, velocity.Y, velocity.Z, record.LastServerSpeed, nearbyMax)
    if limited then
        local bounded = Vector3.new(vx, vy, vz)
        local scale = bounded.Magnitude / math.max(velocity.Magnitude, 1e-6)
        root.AssemblyLinearVelocity = bounded / METERS_PER_STUD
        root.AssemblyAngularVelocity *= scale
        local now = os.clock()
        if now - record.LastEjectionLog > 1 then
            record.LastEjectionLog = now
            warn(
                string.format(
                    "[AutomotiveWorld][Validation] Éjection physiquement impossible limitée sur %s (%.1f → %.1f m/s), sans téléportation.",
                    tostring(record.Model:GetAttribute(Constants.Attributes.VehicleId)),
                    velocity.Magnitude,
                    bounded.Magnitude
                )
            )
        end
    end
    record.LastServerSpeed = math.sqrt(vx * vx + vz * vz)
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
    local stepStarted = os.clock()
    record.Simulator:step(record.BenchInput or InputCodec.Parked, dt)
    PerfStats.add(serverVehicleStep, os.clock() - stepStarted)
    if record.BenchInput then
        return
    end
    if linear < 0.15 and angular < 0.05 then
        record.CalmTimer += dt
        if record.CalmTimer > 2 then
            record.Asleep = true
        end
    else
        record.CalmTimer = 0
    end
end

-- Vérifie que le propriétaire réseau effectif est bien celui attendu ; sinon
-- le réattribue, et sort le conducteur si le moteur refuse (aucune sanction).
local function verifyOwnership(record: VehicleRecord)
    if os.clock() < record.CorrectionUntil then
        return
    end
    local expected = if record.ServerOwned then nil else record.Driver
    local readable, actual = NetworkOwnership.read(ownershipPort(record))
    if not readable or actual == expected then
        record.OwnershipFailures = 0
        return
    end
    record.OwnershipFailures += 1
    warn(
        string.format(
            "[AutomotiveWorld] Propriété réseau inattendue sur %s : réattribution (%d)",
            tostring(record.Model:GetAttribute(Constants.Attributes.VehicleId)),
            record.OwnershipFailures
        )
    )
    if not setOwner(record, expected) and record.Driver ~= nil then
        recoverDriver(record)
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

-- Kilométrage d'un exemplaire personnel : positions vues par le serveur, sauts
-- invraisemblables (correction, repositionnement) exclus.
local function measureDistance(record: VehicleRecord)
    local personal = record.Personal
    if personal == nil then
        return
    end
    local position = record.Root.Position
    local last = personal.LastPosition
    personal.LastPosition = position
    if last == nil or record.Driver == nil or os.clock() < record.CorrectionUntil then
        return
    end
    local meters = (position - last).Magnitude * METERS_PER_STUD
    local plausible = record.Definition.Limits.MaxPlausibleSpeedKmh / 3.6 * VALIDATION_INTERVAL_S * 1.5
    if meters <= plausible then
        personal.DistanceM += meters
    end
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
        if record.Personal then
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
    local impulse = Instance.new("RemoteEvent")
    impulse.Name = Constants.Remotes.Impulse
    impulse.Parent = folder
    folder.Parent = ReplicatedStorage
    return { Action = action, Input = input, Notice = notice, Impulse = impulse }
end

local function onInput(player: Player, payload: any)
    if not RateLimiter.consume(limitersFor(player).Input, os.clock()) then
        return
    end
    local record = recordByDriver[player]
    if record == nil then
        return
    end
    local input, energy, rpm, tireSlip, tireSurface = InputCodec.decode(payload)
    if input == nil then
        return
    end
    -- Simple déclaration : le serveur ne l'accepte qu'au-dessus de son plancher,
    -- à un débit plausible (EnergyModel.settle).
    if energy then
        record.ClientEnergy = energy
    end
    -- Le serveur ne simule pas le véhicule piloté : la commande ne sert qu'à
    -- l'affichage du braquage chez les autres joueurs (valeur bornée).
    local steer = math.round(input.Steer * 20) / 20
    if steer ~= record.LastSteer then
        record.LastSteer = steer
        record.Model:SetAttribute(Constants.Attributes.VisualSteer, steer)
    end
    -- Feux stop (lot VEH3D-01) : même usage, affichage seulement (aucun effet physique ni économique).
    local braking = input.Brake > 0.1
    if braking ~= (record.Model:GetAttribute(Constants.Attributes.VisualBrake) == true) then
        record.Model:SetAttribute(Constants.Attributes.VisualBrake, braking)
    end
    -- Son du moteur chez les autres joueurs (lot AUDIO-01) : régime déclaré, borné par le rupteur du modèle (+5 %),
    -- et charge = accélérateur. Purement sonore : aucune conséquence physique, économique ni de classement.
    if rpm then
        local engine = record.Definition.Powertrain.Engine
        local ceiling = if engine then engine.LimiterRpm * 1.05 else 0
        local audioRpm = math.clamp(rpm, 0, ceiling)
        if audioRpm ~= record.Model:GetAttribute(Constants.Attributes.AudioRpm) then
            record.Model:SetAttribute(Constants.Attributes.AudioRpm, audioRpm)
        end
    end
    local load = math.round(input.Throttle * 10) / 10
    if load ~= record.Model:GetAttribute(Constants.Attributes.AudioLoad) then
        record.Model:SetAttribute(Constants.Attributes.AudioLoad, load)
    end
    -- Sons des pneus chez les autres joueurs (lot AUDIO-03) : glissement déclaré, borné à 0–1 par pas de 0,1, et
    -- famille de revêtement. Contrôle de contexte : un véhicule à l'arrêt (vitesse vue par le serveur) sans
    -- accélérateur ne peut pas crisser (pas de patinage sans couple, pas de glissade sans vitesse). Purement sonore.
    if tireSlip then
        local root = record.Model.PrimaryPart
        local speedMs = if root then root.AssemblyLinearVelocity.Magnitude * Constants.MetersPerStud else 0
        local slip = math.round(tireSlip * 10) / 10
        if speedMs < 1 and input.Throttle < 0.1 then
            slip = 0
        end
        if slip ~= record.Model:GetAttribute(Constants.Attributes.AudioTireSlip) then
            record.Model:SetAttribute(Constants.Attributes.AudioTireSlip, slip)
        end
    end
    if tireSurface and tireSurface ~= record.Model:GetAttribute(Constants.Attributes.AudioTireSurface) then
        record.Model:SetAttribute(Constants.Attributes.AudioTireSurface, tireSurface)
    end
end

-- Active ou désactive une aide : seulement si le modèle en est équipé.
local function handleToggleAid(record: VehicleRecord, player: Player, aid: any)
    if type(aid) ~= "string" or table.find(Constants.AidNames, aid) == nil then
        return
    end
    if (record.Definition.Aids :: any)[aid] ~= true then
        notify(player, "AidAbsent")
        return
    end
    local attribute = (Constants.Attributes :: any)["Aid" .. aid]
    record.Model:SetAttribute(attribute, record.Model:GetAttribute(attribute) ~= true)
end

local function handleCycleRegen(record: VehicleRecord, player: Player)
    local motor = record.Definition.Powertrain.Motor
    if motor == nil then
        notify(player, "RegenAbsent")
        return
    end
    local current = record.Model:GetAttribute(Constants.Attributes.RegenLevel)
    local index = if type(current) == "number" then math.floor(current) else 1
    record.Model:SetAttribute(Constants.Attributes.RegenLevel, index % #motor.RegenLevels + 1)
end

local function onAction(player: Player, action: any, argument: any)
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
    elseif action == Constants.Actions.ToggleAid then
        handleToggleAid(record, player, argument)
    elseif action == Constants.Actions.CycleRegen then
        handleCycleRegen(record, player)
    end
end

-- Crée l'enregistrement d'un véhicule matérialisé (parc d'essai ou exemplaire personnel).
local function createRecord(definition: Types.VehicleDefinition, pivot: CFrame, model: Model): VehicleRecord
    local root = model.PrimaryPart :: BasePart
    local seat = model:FindFirstChild("DriverSeat") :: Seat
    local door = root:FindFirstChild("DriverDoor") :: Attachment
    local prompt = door:FindFirstChild("EnterPrompt") :: ProximityPrompt

    local record: VehicleRecord = {
        Model = model,
        Root = root,
        Seat = seat,
        Prompt = prompt,
        Passenger = model:FindFirstChild("PassengerSeat") :: Seat?,
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
        OwnershipFailures = 0,
        LastServerSpeed = 0,
        LastEjectionLog = 0,
        Energy = EnergyModel.newAccount(definition),
        ClientEnergy = nil,
        EnergySample = nil,
        PublishedEnergy = -1,
        BenchInput = nil,
        Participant = nil,
        Personal = nil,
    }
    record.Participant = {
        Model = model,
        Root = root,
        MassKg = definition.Chassis.MassKg,
        Driver = nil,
        ClientSimulated = false,
    }
    table.insert(records, record)
    setOwner(record, nil)
    publishEnergy(record, true)
    damage:register(model, definition)

    -- Ancrer puis désancrer une pièce rend la propriété réseau à l'attribution
    -- automatique de Roblox : on réaffirme aussitôt le propriétaire attendu.
    root:GetPropertyChangedSignal("Anchored"):Connect(function()
        if root.Anchored then
            return
        end
        task.defer(function()
            local expected = if record.ServerOwned then nil else record.Driver
            if not setOwner(record, expected) and record.Driver ~= nil then
                recoverDriver(record)
            end
        end)
    end)
    seat:GetPropertyChangedSignal("Occupant"):Connect(function()
        onOccupantChanged(record)
    end)
    prompt.Triggered:Connect(function(player)
        onPromptTriggered(record, player)
    end)
    local passenger = record.Passenger
    local passengerDoor = root:FindFirstChild("PassengerDoor")
    local passengerPrompt = passengerDoor and passengerDoor:FindFirstChild("PassengerPrompt")
    if passenger and passengerPrompt and passengerPrompt:IsA("ProximityPrompt") then
        passenger:GetPropertyChangedSignal("Occupant"):Connect(function()
            onPassengerChanged(record)
        end)
        passengerPrompt.Triggered:Connect(function(player)
            onPassengerPrompt(record, player)
        end)
    end
    return record
end

-- Plots de la zone d'essai et du parc du monde ouvert (lot 0.3). Lot BASE-01 : le parc d'essai est supprimé
-- (décision du propriétaire du 2026-11-05) ; les plots restent dans la carte, sans véhicule.
export type SpawnSet = {
    Pads: { BasePart },
}

-- Lot 0.8 : appartenance à un même groupe (fournie par SocialService), pour la place passager.
function VehicleService.setGroupCheck(check: (number, number) -> boolean)
    sameGroup = check
end

function VehicleService.start(zone: SpawnSet)
    assert(not started, "VehicleService déjà démarré")
    started = true

    local createdRemotes = createRemotes()
    remotes = createdRemotes
    createdRemotes.Input.OnServerEvent:Connect(onInput)
    createdRemotes.Action.OnServerEvent:Connect(onAction)

    local folder = Instance.new("Folder")
    folder.Name = "VehiculesEssai"
    folder.Parent = Workspace

    -- Dossier conservé (bancs de mesure de Studio, nettoyage de ProgressionService) ; aucun véhicule de parc.
    local _ = zone

    RunService.PreSimulation:Connect(function(dt)
        for _, record in records do
            if record.ServerOwned then
                -- Borne d'éjection (lot 0.1) : pas pour les véhicules de banc, propulsés
                -- légitimement par le serveur (mesuré : elle bridait leur accélération).
                if record.BenchInput == nil then
                    limitImplausibleSpeed(record)
                end
                stepServerVehicle(record, dt)
            else
                record.LastServerSpeed = 0
            end
        end
    end)

    -- Collisions entre véhicules de deux joueurs : complément d'impulsion confirmé serveur.
    local mediator = CollisionMediator.new(function(driver, model, normal, deltaV, point)
        createdRemotes.Impulse:FireClient(driver, model, normal, deltaV, point)
    end)
    local function correcting(model: Model): boolean
        -- Lot ADMIN-01 : véhicule rendu invulnérable par le menu d'administration (aucun dégât compté).
        if model:GetAttribute("AWAdminInvulnerable") == true then
            return true
        end
        for _, record in records do
            if record.Model == model then
                return os.clock() < record.CorrectionUntil
            end
        end
        return false
    end

    local validationTimer, maintenanceTimer = 0, 0
    RunService.Heartbeat:Connect(function(dt)
        local beat = os.clock()
        local now = os.clock()
        local participants: { CollisionMediator.Participant } = {}
        for _, record in records do
            -- Les véhicules de banc (Studio) n'ont pas de participant : ils sont
            -- simulés par le serveur, dont le moteur résout leurs contacts.
            local participant = record.Participant
            if participant == nil then
                continue
            end
            table.insert(participants, participant)
            participant.Driver = record.Driver
            participant.ClientSimulated = record.Driver ~= nil
                and not record.ServerOwned
                and now >= record.CorrectionUntil
        end
        mediator:step(participants, now)
        damage:step(now, correcting)

        validationTimer += dt
        maintenanceTimer += dt
        if validationTimer >= VALIDATION_INTERVAL_S then
            validationTimer = 0
            for _, record in records do
                verifyOwnership(record)
                settleEnergy(record, os.clock())
                measureDistance(record)
            end
            validateMovements(os.clock())
        end
        if maintenanceTimer >= MAINTENANCE_INTERVAL_S then
            maintenanceTimer = 0
            maintainParkedVehicles()
        end
        PerfStats.add(serverHeartbeat, os.clock() - beat)
    end)

    if RunService:IsStudio() then
        VehicleService.installTestHooks(folder, mediator)
    end

    Players.PlayerRemoving:Connect(function(player)
        local record = recordByDriver[player]
        if record then
            releaseDriver(record)
        end
        limiters[player] = nil
    end)

    print(string.format("[AutomotiveWorld] %d véhicules d'essai prêts (parc du lot 0.2)", #records))
end

export type PersonalSpawn = {
    Definition: Types.VehicleDefinition, -- définition dérivée (réglages, pièces, apparence)
    Pivot: CFrame,
    OwnerUserId: number,
    VehicleId: string,
    Protected: boolean,
    MayDrive: (Player) -> boolean,
    EnergyFraction: number,
    Damage: any, -- état de dégâts durable (format DamageModel)
    TuningSpec: string, -- réglages et pièces (JSON) recalculés à l'identique par le client
}

local personalFolder: Folder? = nil

--[[
    Matérialise un exemplaire personnel (lot 0.4). L'énergie et les dégâts
    durables sont restaurés ; le client recalcule la même définition dérivée
    à partir de TuningSpec. Renvoie le modèle.
]]
function VehicleService.spawnPersonal(spawn: PersonalSpawn): Model
    assert(started, "VehicleService non démarré")
    local folder = personalFolder
    if folder == nil then
        local created = Instance.new("Folder")
        created.Name = "VehiculesPersonnels"
        created.Parent = Workspace
        personalFolder = created
        folder = created
    end
    local definition = spawn.Definition
    local model = VehicleFactory.create(definition, spawn.Pivot, 0)
    model.Name = "Perso_" .. spawn.VehicleId
    model:SetAttribute("OwnerUserId", spawn.OwnerUserId)
    model:SetAttribute("PersonalVehicleId", spawn.VehicleId)
    model:SetAttribute("TuningSpec", spawn.TuningSpec)
    model.Parent = folder
    local record = createRecord(definition, spawn.Pivot, model)
    record.Personal = {
        OwnerUserId = spawn.OwnerUserId,
        VehicleId = spawn.VehicleId,
        Protected = spawn.Protected,
        MayDrive = spawn.MayDrive,
        DistanceM = 0,
        LastPosition = nil,
        Since = os.clock(),
    }
    local store = definition.Powertrain.Energy
    record.Energy = EnergyModel.newAccount(definition, math.clamp(spawn.EnergyFraction, 0, 1) * store.Capacity)
    publishEnergy(record, true)
    if spawn.Damage then
        damage:restore(model, spawn.Damage)
    end
    return model
end

local function personalRecord(model: Model): VehicleRecord?
    for _, record in records do
        if record.Model == model and record.Personal then
            return record
        end
    end
    return nil
end

export type PersonalState = {
    EnergyFraction: number,
    Damage: any,
    DistanceKm: number,
    ElapsedS: number,
    MaxSpeedKmh: number,
    Protected: boolean,
}

-- État mesuré par le serveur depuis la dernière lecture (remet la distance à zéro).
function VehicleService.readPersonal(model: Model): PersonalState?
    local record = personalRecord(model)
    if record == nil then
        return nil
    end
    local personal = record.Personal :: PersonalInfo
    local now = os.clock()
    local state: PersonalState = {
        EnergyFraction = record.Energy.Level / math.max(record.Energy.Capacity, 1e-9),
        Damage = damage:getState(model),
        DistanceKm = personal.DistanceM / 1000,
        ElapsedS = now - personal.Since,
        MaxSpeedKmh = record.Definition.Limits.MaxPlausibleSpeedKmh,
        Protected = personal.Protected,
    }
    personal.DistanceM = 0
    personal.Since = now
    return state
end

-- Conducteur actuel d'un exemplaire personnel et sa vitesse (m/s).
function VehicleService.personalDriver(model: Model): (Player?, number)
    local record = personalRecord(model)
    if record == nil then
        return nil, 0
    end
    return record.Driver, record.Root.AssemblyLinearVelocity.Magnitude * METERS_PER_STUD
end

-- Fait descendre le conducteur (arrêt sûr décidé par l'appelant).
-- Lot 0.5 : énergie RÉELLEMENT livrée par une station (unités du modèle),
-- bornée par la capacité ; renvoie la quantité ajoutée.
function VehicleService.addEnergy(model: Model, amount: number): number
    local record = personalRecord(model)
    if record == nil or amount <= 0 then
        return 0
    end
    local account = record.Energy
    local added = math.min(amount, account.Capacity - account.Level)
    if added <= 0 then
        return 0
    end
    account.Level += added
    account.Empty = account.Level <= 0
    publishEnergy(record, true)
    return added
end

-- Énergie actuelle et capacité d'un exemplaire personnel matérialisé.
function VehicleService.personalEnergy(model: Model): (number, number)
    local record = personalRecord(model)
    if record == nil then
        return 0, 0
    end
    return record.Energy.Level, record.Energy.Capacity
end

-- Lot 0.5 : réparation payée appliquée au véhicule matérialisé.
function VehicleService.restorePersonalDamage(model: Model, state: any)
    if personalRecord(model) then
        damage:restore(model, state)
    end
end

--[[
    Lot 0.6 (courses) : session PROTÉGÉE (aucune écriture durable : dégâts et
    consommation de course isolés), droit de conduire restreint au
    propriétaire pendant l'engagement, énergie restaurée exactement à la
    sortie d'une course protégée.
]]
function VehicleService.setPersonalProtected(model: Model, protected: boolean)
    local record = personalRecord(model)
    if record then
        (record.Personal :: PersonalInfo).Protected = protected
    end
end

function VehicleService.setPersonalMayDrive(model: Model, rule: (Player) -> boolean)
    local record = personalRecord(model)
    if record then
        (record.Personal :: PersonalInfo).MayDrive = rule
    end
end

function VehicleService.personalMayDrive(model: Model): ((Player) -> boolean)?
    local record = personalRecord(model)
    return if record then (record.Personal :: PersonalInfo).MayDrive else nil
end

function VehicleService.setPersonalEnergy(model: Model, fraction: number)
    local record = personalRecord(model)
    if record == nil then
        return
    end
    local account = record.Energy
    account.Level = math.clamp(fraction, 0, 1) * account.Capacity
    account.Empty = account.Level <= 0
    publishEnergy(record, true)
end

-- État mesuré sans remise à zéro de la distance (conservé pour une reprise).
function VehicleService.peekPersonal(model: Model): (number?, any?)
    local record = personalRecord(model)
    if record == nil then
        return nil, nil
    end
    return record.Energy.Level / math.max(record.Energy.Capacity, 1e-9), damage:getState(model)
end

--[[
    Lot 0.5 (missions) : usure cumulée et corrections subies par N'IMPORTE quel
    véhicule suivi (parc, exemplaire personnel, véhicule professionnel), lues
    par le serveur seul.
]]
function VehicleService.vehicleState(model: Model): (number, number)
    for _, record in records do
        if record.Model == model then
            local state = damage:getState(model)
            local wear = 0
            if state then
                for _, value in state.Zones do
                    wear += value
                end
                wear += (1 - state.Engine) + (1 - state.Steering)
            end
            return wear, record.Corrections or 0
        end
    end
    return 0, 0
end

function VehicleService.ejectPersonalDriver(model: Model)
    local record = personalRecord(model)
    if record and record.Seat.Occupant then
        ejectOccupant(record, record.Seat.Occupant)
    end
end

-- Retire un exemplaire personnel du monde (rangement, départ du joueur).
local function findRecord(model: any): VehicleRecord?
    for _, record in records do
        if record.Model == model then
            return record
        end
    end
    return nil
end

-- ======================== Menu d'administration (lot ADMIN-01) ========================
-- Appelés par Server/Admin/AdminService SEULEMENT, après la vérification des droits.

-- Véhicule conduit par le joueur (nil s'il n'est pas au volant).
function VehicleService.drivenBy(player: Player): Model?
    local record = recordByDriver[player]
    return if record then record.Model else nil
end

-- Réparation complète ; énergie remise au plein si demandé. Renvoie false si le véhicule n'est pas suivi.
function VehicleService.adminRepair(model: Model, refill: boolean): boolean
    local record = findRecord(model)
    if record == nil or not damage:repair(model) then
        return false
    end
    if refill then
        local account = record.Energy
        account.Level = account.Capacity
        account.Empty = false
        publishEnergy(record, true)
    end
    return true
end

-- Remise sur roues immédiate (sans délai ni condition de vitesse, contrairement à l'action des joueurs).
function VehicleService.adminFlip(model: Model): boolean
    local record = findRecord(model)
    if record == nil then
        return false
    end
    local root = record.Root
    placeUnderServer(record, uprightPivot(root.Position + Vector3.new(0, 4, 0), root.CFrame.LookVector))
    return true
end

function VehicleService.despawnPersonal(model: Model)
    local record = personalRecord(model)
    if record == nil then
        return
    end
    local occupant = record.Seat.Occupant
    if occupant then
        releaseCharacter(record, occupant)
    end
    if record.Driver then
        releaseDriver(record)
    end
    damage:unregister(model)
    local index = table.find(records, record)
    if index then
        table.remove(records, index)
    end
    model:Destroy()
end

--[[
    Points d'accès RÉSERVÉS aux essais automatisés dans Roblox Studio : une
    BindableFunction dans ServerStorage (jamais visible des clients), créée
    seulement si RunService:IsStudio(). Elle permet de lire les états serveur,
    de placer une réserve presque vide (essai de panne) et de lancer un banc de
    charge. Rien de tout cela n'existe hors de Studio.
]]
function VehicleService.installTestHooks(folder: Folder, _mediator: any)
    assert(RunService:IsStudio(), "Réservé aux essais dans Studio")
    local hooks = Instance.new("BindableFunction")
    hooks.Name = "AWTestHooks"
    hooks.OnInvoke = function(command: string, model: any, value: any): any
        local record = findRecord(model)
        if command == "GetEnergy" and record then
            local account = record.Energy
            return {
                Level = account.Level,
                Empty = account.Empty,
                Capacity = account.Capacity,
                TotalWithdrawn = account.TotalWithdrawn,
                TotalRecovered = account.TotalRecovered,
                FloorUsed = account.FloorUsed,
                ClientAccepted = account.ClientAccepted,
            }
        elseif command == "SetEnergy" and record and type(value) == "number" then
            record.Energy.Level = math.clamp(value, 0, record.Energy.Capacity)
            record.Energy.Empty = record.Energy.Level <= 0
            publishEnergy(record, true)
            return true
        elseif command == "GetDamage" and model then
            local state = damage:getState(model)
            return if state then table.clone(state.Zones) else nil
        elseif command == "Impacts" then
            return { Impacts = damage.Impacts, Unconfirmed = damage.Unconfirmed, Queries = damage.Queries }
        elseif command == "ServerPerf" then
            return {
                VehicleStep = PerfStats.summary(serverVehicleStep),
                Heartbeat = PerfStats.summary(serverHeartbeat),
                Damage = damage:perf(),
                Vehicles = #records,
            }
        elseif command == "ResetPerf" then
            PerfStats.reset(serverVehicleStep)
            PerfStats.reset(serverHeartbeat)
            return true
        elseif command == "SpawnBench" and type(value) == "number" then
            -- Banc de charge : véhicules simulés par le serveur, en cercle, loin du parc.
            local definition = VehicleDefinitions.get(VehicleDefinitions.DefaultTestVehicleId) :: any
            local created = 0
            for i = 1, math.clamp(math.floor(value), 0, 40) do
                local x = -560 + ((i - 1) % 8) * 40
                local z = -980 + math.floor((i - 1) / 8) * 45
                local pivot = CFrame.new(x, definition.Chassis.CgHeightM / Constants.MetersPerStud + 0.3, z)
                local benchModel = VehicleFactory.create(definition, pivot, 100 + i)
                benchModel.Name = "Banc_" .. i
                benchModel.Parent = folder
                local root = benchModel.PrimaryPart :: BasePart
                local bench: any = {
                    Model = benchModel,
                    Root = root,
                    Seat = benchModel:FindFirstChild("DriverSeat"),
                    Prompt = (root:FindFirstChild("DriverDoor") :: Attachment):FindFirstChild("EnterPrompt"),
                    Definition = definition,
                    HomePivot = pivot,
                    Driver = nil,
                    ServerOwned = true,
                    Simulator = VehicleSimulator.new(benchModel, definition, { ReplicationFriendly = true }),
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
                    OwnershipFailures = 0,
                    LastServerSpeed = 0,
                    LastEjectionLog = 0,
                    Energy = EnergyModel.newAccount(definition),
                    ClientEnergy = nil,
                    EnergySample = nil,
                    PublishedEnergy = -1,
                    BenchInput = { Throttle = 0.35, Brake = 0, Steer = 0.6, Handbrake = false, Clutch = 0 },
                }
                bench.Prompt.Enabled = false
                bench.Simulator:startEngine()
                table.insert(records, bench)
                root:SetNetworkOwner(nil)
                damage:register(benchModel, definition)
                created += 1
            end
            return created
        end
        return nil
    end
    hooks.Parent = ServerStorage
end

return VehicleService
