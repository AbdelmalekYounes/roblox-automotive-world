--!strict
-- Contrôleur client de la conduite.
--
-- Cycle de vie : lorsque le serveur a assis le joueur sur un siège conducteur
-- ET lui a attribué le véhicule (attribut DriverUserId), une session de
-- conduite démarre : commandes, simulation locale, caméra, HUD. Elle s'arrête
-- dès que l'une de ces conditions n'est plus vraie (sortie, mort, correction).
-- Le client n'envoie au serveur que des commandes bornées, des demandes
-- d'action et un cumul d'énergie déclaratif ; il ne décide jamais seul d'un
-- état critique (aides activées, récupération, dégâts, niveau d'énergie : lus
-- dans les attributs écrits par le serveur).

local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local VehiclesShared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Vehicles")
local Types = require(VehiclesShared:WaitForChild("VehicleTypes"))
local Constants = require(VehiclesShared:WaitForChild("VehicleConstants"))
local VehicleDefinitions = require(VehiclesShared:WaitForChild("VehicleDefinitions"))
local VehicleSimulator = require(VehiclesShared:WaitForChild("VehicleSimulator"))
local TuningRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Garage"):WaitForChild("TuningRules"))
local InputCodec = require(VehiclesShared:WaitForChild("InputCodec"))
local Telemetry = require(VehiclesShared:WaitForChild("Telemetry"))
local PhysicsFolder = VehiclesShared:WaitForChild("Physics")
local CollisionExchange = require(PhysicsFolder:WaitForChild("CollisionExchange"))
local DamageModel = require(PhysicsFolder:WaitForChild("DamageModel"))
local EnergyModel = require(PhysicsFolder:WaitForChild("EnergyModel"))
local SpinNotice = require(VehiclesShared:WaitForChild("SpinNotice"))

local DriverInput = require(script.Parent.DriverInput)
local VehicleCamera = require(script.Parent.VehicleCamera)
local WheelVisuals = require(script.Parent.WheelVisuals)
-- Lot ANIM-01 : volant du véhicule piloté (rotation et mains appliquées par SeatPoseController).
local SteeringWheelVisuals = require(script.Parent.SteeringWheelVisuals)
local DevHud = require(script.Parent.Parent.UI.DevHud)
local TireAudioModel = require(ReplicatedStorage.Shared:WaitForChild("Audio"):WaitForChild("TireAudioModel"))

local VehicleController = {}

local player = Players.LocalPlayer
local METERS_PER_STUD = Constants.MetersPerStud
local SEND_INTERVAL_S = 1 / Constants.InputSendRateHz
local KEEPALIVE_S = 0.5
local ACTION_DEBOUNCE_S = 0.4
local SHIFT_DEBOUNCE_S = 0.12
local ACTION_PRIORITY = Enum.ContextActionPriority.High.Value + 10
local VELOCITY_HISTORY_S = 1.5
-- Borne défensive d'un complément d'impulsion reçu (studs/s, ≈ 60 km/h).
local IMPULSE_MAX_DELTA_V = 60
local IMPULSE_MIN_DELTA_V = 0.3
-- Écart (studs) au-delà duquel la copie locale est recalée sur la position serveur.
local RESYNC_DISTANCE = 3
-- Durée pendant laquelle le personnage est relevé après un refus de prise en main.
local STAND_UP_WINDOW_S = 3
local HUD_SLOW_REFRESH_S = 0.25

local AID_LABELS: { [string]: string } = {
    Abs = "ABS",
    TractionControl = "Antipatinage",
    StabilityControl = "ESP",
}
local AID_KEYS: { [string]: Enum.KeyCode } = {
    Abs = Enum.KeyCode.One,
    TractionControl = Enum.KeyCode.Two,
    StabilityControl = Enum.KeyCode.Three,
}
local ENERGY_NAMES: { [string]: string } = {
    Petrol = "Essence",
    Diesel = "Diesel",
    Electric = "Électrique",
}
local TRANSMISSION_NAMES: { [string]: string } = {
    Automatic = "boîte automatique",
    Manual = "boîte manuelle",
    DualClutch = "double embrayage",
    Sequential = "boîte séquentielle",
    CVT = "variateur CVT",
    SingleSpeed = "rapport unique",
}
local LAYOUT_NAMES: { [string]: string } = {
    FWD = "traction",
    RWD = "propulsion",
    AWD = "intégrale",
}
local ZONE_NAMES: { [string]: string } = { Front = "AV", Rear = "AR", Left = "G", Right = "D" }
local LEVEL_NAMES = { "rayures", "localisés", "importants" }

type Session = {
    Model: Model,
    Seat: Seat,
    Definition: Types.VehicleDefinition,
    Simulator: VehicleSimulator.VehicleSimulator,
    -- Vrai seulement quand le serveur a CONFIRMÉ la propriété réseau à ce
    -- joueur (attribut SimulationOwnerUserId) : jamais de double simulation.
    Simulating: boolean,
    -- Vitesses récentes du véhicule (studs/s), pour le complément d'impulsion.
    VelocityHistory: { { Time: number, Velocity: Vector3 } },
    LastImpulse: number?,
    Resyncs: number,
    LastInput: Types.DriverInput,
    SendTimer: number,
    KeepaliveTimer: number,
    LastSent: { number }?,
    -- Énergie : consommation des simulateurs précédents de cette session, et
    -- prédiction locale entre deux publications du serveur.
    EnergyBase: number,
    ServerLevel: number,
    UsedAtServerLevel: number,
    EnergyAvailable: boolean,
    ConsumptionRate: number, -- unités de réserve par seconde, lissé
    LastEnergyUsed: number,
    -- Changements à signaler (aides, récupération, calage, dégâts).
    LastAids: { [string]: boolean },
    LastRegen: number,
    LastStalled: boolean,
    LastImpacts: number,
    -- Manette : réglage sélectionné à la croix gauche.
    Selection: number,
    SlowTimer: number,
    DamageText: string,
    LastShift: number,
    -- Avis « antipatinage désactivé » (docs/PROPOSITION_PATINAGE.md, option E) : minuterie de patinage franc et avis
    -- déjà montré pendant cette session.
    SpinTimer: number,
    SpinNoticeShown: boolean,
}

type Remotes = {
    Action: RemoteEvent,
    Input: UnreliableRemoteEvent,
    Notice: RemoteEvent,
    Impulse: RemoteEvent,
}

local session: Session? = nil
local remotes: Remotes? = nil
local input = DriverInput.new()
local camera = VehicleCamera.new()
local measures = Telemetry.new()
local lastActionTime = 0
-- Fournisseur de commandes réservé aux tests automatisés dans Studio (voir
-- `setTestInputProvider`) ; toujours nil en jeu publié.
local testInputProvider: (() -> Types.DriverInput)? = nil

-- Les contrôles par défaut (déplacement, saut) sont désactivés pendant la
-- conduite pour éviter toute action involontaire (ex. sortir en sautant).
local function setDefaultControls(enabled: boolean)
    local scripts = player:FindFirstChild("PlayerScripts")
    local module = if scripts then scripts:FindFirstChild("PlayerModule") else nil
    if module == nil or not module:IsA("ModuleScript") then
        return
    end
    local ok, playerModule = pcall(require, module)
    if not ok then
        return
    end
    local controls = (playerModule :: any):GetControls()
    if enabled then
        controls:Enable()
    else
        controls:Disable()
    end
end

local function sendAction(action: string, argument: string?)
    local now = os.clock()
    if now - lastActionTime < ACTION_DEBOUNCE_S or remotes == nil then
        return
    end
    lastActionTime = now
    remotes.Action:FireServer(action, argument)
end

-- Réglages modifiables à la manette (croix gauche / droite) : aides présentes
-- puis récupération si le modèle est électrique.
local function settingsOf(definition: Types.VehicleDefinition): { string }
    local list = {}
    for _, aid in Constants.AidNames do
        if (definition.Aids :: any)[aid] then
            table.insert(list, aid)
        end
    end
    if definition.Powertrain.Motor then
        table.insert(list, "Regen")
    end
    return list
end

local function applySetting(name: string)
    if name == "Regen" then
        sendAction(Constants.Actions.CycleRegen)
    else
        sendAction(Constants.Actions.ToggleAid, name)
    end
end

-- Une touche du clavier ne déclenche aucune action pendant une saisie de
-- texte (chat, champ de saisie) : protection explicite, en plus de celle du moteur.
local function keyboardBlocked(inputObject: InputObject?): boolean
    return inputObject ~= nil and inputObject.UserInputType == Enum.UserInputType.Keyboard and DriverInput.isTyping()
end

local function shift(direction: number)
    local current = session
    if current == nil or not current.Simulating then
        return
    end
    local now = os.clock()
    if now - current.LastShift < SHIFT_DEBOUNCE_S then
        return
    end
    current.LastShift = now
    local result = current.Simulator:requestShift(direction)
    if result ~= "Ok" then
        DevHud.showNotice("Shift" .. result)
    end
end

-- Gestionnaires des actions ponctuelles, par nom de liaison.
local handlers: { [string]: () -> () } = {
    AWVehicleExit = function()
        sendAction(Constants.Actions.Exit)
    end,
    AWVehicleUnflip = function()
        sendAction(Constants.Actions.Unflip)
    end,
    AWVehicleCamera = function()
        DevHud.showNotice("CameraPreset", camera:togglePreset())
    end,
    AWVehicleShiftUp = function()
        shift(1)
    end,
    AWVehicleShiftDown = function()
        shift(-1)
    end,
    AWVehicleAidAbs = function()
        sendAction(Constants.Actions.ToggleAid, "Abs")
    end,
    AWVehicleAidTractionControl = function()
        sendAction(Constants.Actions.ToggleAid, "TractionControl")
    end,
    AWVehicleAidStabilityControl = function()
        sendAction(Constants.Actions.ToggleAid, "StabilityControl")
    end,
    AWVehicleRegen = function()
        sendAction(Constants.Actions.CycleRegen)
    end,
    AWVehicleSelectSetting = function()
        local current = session
        if current == nil then
            return
        end
        local list = settingsOf(current.Definition)
        if #list == 0 then
            DevHud.showNotice("AidAbsent")
            return
        end
        current.Selection = current.Selection % #list + 1
    end,
    AWVehicleApplySetting = function()
        local current = session
        if current == nil then
            return
        end
        local list = settingsOf(current.Definition)
        local name = list[math.clamp(current.Selection, 1, math.max(#list, 1))]
        if name then
            applySetting(name)
        else
            DevHud.showNotice("AidAbsent")
        end
    end,
}

local function onBoundAction(
    name: string,
    state: Enum.UserInputState,
    inputObject: InputObject?
): Enum.ContextActionResult
    if keyboardBlocked(inputObject) then
        return Enum.ContextActionResult.Pass
    end
    if state == Enum.UserInputState.Begin then
        local handler = handlers[name]
        if handler then
            handler()
        end
    end
    return Enum.ContextActionResult.Sink
end

-- Absorbe les touches de conduite pour qu'aucune autre action ne s'y greffe
-- (saut, verrouillage de la souris, menus).
local function sinkAction(): Enum.ContextActionResult
    return Enum.ContextActionResult.Sink
end

local BINDINGS: { { Name: string, Keys: { Enum.KeyCode } } } = {
    { Name = "AWVehicleExit", Keys = { Enum.KeyCode.F, Enum.KeyCode.ButtonY } },
    { Name = "AWVehicleUnflip", Keys = { Enum.KeyCode.R, Enum.KeyCode.DPadDown } },
    { Name = "AWVehicleCamera", Keys = { Enum.KeyCode.V, Enum.KeyCode.DPadUp } },
    { Name = "AWVehicleShiftUp", Keys = { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonR1 } },
    { Name = "AWVehicleShiftDown", Keys = { Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonL1 } },
    { Name = "AWVehicleAidAbs", Keys = { AID_KEYS.Abs } },
    { Name = "AWVehicleAidTractionControl", Keys = { AID_KEYS.TractionControl } },
    { Name = "AWVehicleAidStabilityControl", Keys = { AID_KEYS.StabilityControl } },
    { Name = "AWVehicleRegen", Keys = { Enum.KeyCode.G } },
    { Name = "AWVehicleSelectSetting", Keys = { Enum.KeyCode.DPadLeft } },
    { Name = "AWVehicleApplySetting", Keys = { Enum.KeyCode.DPadRight } },
}

local function bindActions()
    for _, binding in BINDINGS do
        ContextActionService:BindActionAtPriority(
            binding.Name,
            onBoundAction,
            false,
            ACTION_PRIORITY,
            table.unpack(binding.Keys)
        )
    end
    ContextActionService:BindActionAtPriority(
        "AWVehicleSink",
        sinkAction,
        false,
        ACTION_PRIORITY,
        Enum.KeyCode.Space,
        Enum.KeyCode.ButtonA,
        Enum.KeyCode.C,
        Enum.KeyCode.ButtonB
    )
end

local function unbindActions()
    for _, binding in BINDINGS do
        ContextActionService:UnbindAction(binding.Name)
    end
    ContextActionService:UnbindAction("AWVehicleSink")
end

-- Description permanente du modèle : énergie, boîte, architecture et filtre de
-- braquage A1 (affiché : rien de ce qui modifie la commande n'est caché).
local function vehicleDescription(definition: Types.VehicleDefinition): string
    local powertrain = definition.Powertrain
    local steering = definition.Steering
    return string.format(
        "%s · %s · %s · braquage %d° → %d° à %d km/h",
        ENERGY_NAMES[powertrain.Energy.Kind] or powertrain.Energy.Kind,
        TRANSMISSION_NAMES[powertrain.Transmission.Kind] or powertrain.Transmission.Kind,
        LAYOUT_NAMES[powertrain.Drivetrain.Layout] or powertrain.Drivetrain.Layout,
        steering.MaxAngleDeg,
        steering.HighSpeedAngleDeg,
        steering.HighSpeedReferenceKmh
    )
end

local function currentHumanoid(): Humanoid?
    local character = player.Character
    return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function sessionEnergyUsed(current: Session): number
    return current.EnergyBase + current.Simulator.State.EnergyUsed
end

local function readServerLevel(model: Model, definition: Types.VehicleDefinition): number
    local level = model:GetAttribute(Constants.Attributes.EnergyLevel)
    if type(level) == "number" and level == level then
        return level
    end
    return definition.Powertrain.Energy.Capacity * definition.Powertrain.Energy.InitialFraction
end

-- Prédiction locale prudente : niveau serveur moins ce que ce client a consommé
-- depuis sa dernière publication. La réserve est vide dès que l'un des deux le dit.
local function updateEnergyAvailability(current: Session)
    local used = sessionEnergyUsed(current)
    local serverLevel = readServerLevel(current.Model, current.Definition)
    if serverLevel ~= current.ServerLevel then
        current.ServerLevel = serverLevel
        current.UsedAtServerLevel = used
    end
    local predicted = EnergyModel.predictLevel(serverLevel, used - current.UsedAtServerLevel)
    local empty = current.Model:GetAttribute(Constants.Attributes.EnergyEmpty) == true
    local available = not empty and predicted > 0
    if current.EnergyAvailable and not available then
        DevHud.showNotice("EnergyEmpty")
    end
    current.EnergyAvailable = available
    current.Simulator.State.EnergyAvailable = available
end

local function newSimulator(current: Session): VehicleSimulator.VehicleSimulator
    local simulator = VehicleSimulator.new(current.Model, current.Definition)
    simulator.State.EnergyAvailable = current.EnergyAvailable
    simulator:startEngine()
    return simulator
end

-- Lot AUDIO-03 : dernier résumé sonore des pneus du véhicule conduit (voir tireSummary).
local lastTireSummary: TireAudioModel.Summary? = nil

local function endSession()
    local current = session
    if current == nil then
        return
    end
    session = nil
    lastTireSummary = nil
    current.Simulator:release()
    input:reset()
    unbindActions()
    camera:stop(currentHumanoid())
    setDefaultControls(true)
    DevHud.hide()
    measures = Telemetry.new()
end

-- Exemplaire personnel (lot 0.4) : même définition dérivée que le serveur
-- (réglages et pièces publiés par lui), sinon la définition d'origine.
local function personalDefinition(model: Model, base: Types.VehicleDefinition): Types.VehicleDefinition
    local spec = model:GetAttribute("TuningSpec")
    if type(spec) ~= "string" then
        return base
    end
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(spec)
    end)
    if not ok or type(decoded) ~= "table" then
        return base
    end
    local derived = TuningRules.apply(base, decoded.Tuning or {}, decoded.Parts or {})
    if not VehicleDefinitions.validate(derived) then
        return base
    end
    return derived
end

local function beginSession(model: Model, seat: Seat)
    local definitionId = model:GetAttribute(Constants.Attributes.DefinitionId)
    local base = if type(definitionId) == "string" then VehicleDefinitions.get(definitionId) else nil
    local definition = if base then personalDefinition(model, base) else nil
    if definition == nil or model.PrimaryPart == nil then
        return
    end
    local level = readServerLevel(model, definition)
    local current: Session = {
        Model = model,
        Seat = seat,
        Definition = definition,
        Simulator = VehicleSimulator.new(model, definition),
        Simulating = false,
        VelocityHistory = {},
        LastImpulse = nil,
        Resyncs = 0,
        LastInput = InputCodec.Parked,
        SendTimer = 0,
        KeepaliveTimer = 0,
        LastSent = nil,
        EnergyBase = 0,
        ServerLevel = level,
        UsedAtServerLevel = 0,
        EnergyAvailable = level > 0 and model:GetAttribute(Constants.Attributes.EnergyEmpty) ~= true,
        ConsumptionRate = 0,
        LastEnergyUsed = 0,
        LastAids = {},
        LastRegen = 1,
        LastStalled = false,
        LastImpacts = 0,
        Selection = 1,
        SlowTimer = math.huge,
        DamageText = "aucun",
        LastShift = 0,
        SpinTimer = 0,
        SpinNoticeShown = false,
    }
    local impacts = model:GetAttribute("DmgImpacts")
    current.LastImpacts = if type(impacts) == "number" then impacts else 0
    session = current
    input:reset()
    measures = Telemetry.new()
    setDefaultControls(false)
    bindActions()
    camera:start(model, player.Character)
    DevHud.show(definition.DisplayName, vehicleDescription(definition))
    if not current.EnergyAvailable then
        DevHud.showNotice("EnergyEmpty")
    end
end

-- Détermine si le joueur doit être en session de conduite, et sur quel véhicule.
local function evaluateSession()
    local humanoid = currentHumanoid()
    local seatPart = if humanoid then humanoid.SeatPart else nil
    local model = if seatPart then seatPart.Parent else nil
    local eligible = seatPart ~= nil
        and seatPart.Name == "DriverSeat"
        and seatPart:IsA("Seat")
        and model ~= nil
        and model:IsA("Model")
        and model:HasTag(Constants.VehicleTag)
        and model:GetAttribute(Constants.Attributes.DriverUserId) == player.UserId

    local current = session
    if current and (not eligible or current.Model ~= model) then
        endSession()
        current = nil
    end
    if eligible and current == nil and model and seatPart then
        beginSession(model :: Model, seatPart :: Seat)
    end
end

-- ======================== Lot AUDIO-03 : sons des pneus ========================
-- Résumé sonore des quatre roues du véhicule simulé ici (glissements de la dynamique, revêtement, humidité), recalculé
-- à chaque image ; nil si ce client ne simule pas le véhicule. Le dernier résumé (lastTireSummary, déclaré avant
-- endSession) sert aussi à la déclaration envoyée au serveur pour le son des autres joueurs.
local function tireSummary(current: Session): TireAudioModel.Summary?
    if not current.Simulating then
        return nil
    end
    local simulator = current.Simulator
    local tires = current.Definition.Tires
    local samples: { TireAudioModel.WheelSample } = table.create(4)
    for index, wheel in simulator.State.Wheels do
        local contact = simulator.Contacts[index]
        table.insert(samples, {
            Grounded = contact.Grounded,
            SlipRatio = wheel.SlipRatio,
            SlipAngle = wheel.SlipAngle,
            ContactVx = contact.LongitudinalVelocity,
            ContactVy = contact.LateralVelocity,
            RollingSpeed = wheel.AngularVelocity * tires.RadiusM,
            Surface = TireAudioModel.surfaceOf(contact.Material),
            Wetness = math.max(if contact.Wet then 1 else 0, contact.Wetness or 0),
        })
    end
    return TireAudioModel.summarize(
        samples,
        tires.PeakSlipRatio,
        math.rad(tires.PeakSlipAngleDeg),
        simulator.State.AidActivity.Abs
    )
end

local function sendInput(current: Session, driverInput: Types.DriverInput, dt: number)
    local activeRemotes = remotes
    if activeRemotes == nil then
        return
    end
    current.SendTimer += dt
    current.KeepaliveTimer += dt
    if current.SendTimer < SEND_INTERVAL_S then
        return
    end
    current.SendTimer = 0
    -- Régime déclaré pour le son des autres joueurs (lot AUDIO-01) : 0 si moteur arrêté, calé ou non simulé ici.
    local telemetry = if current.Simulating then current.Simulator.Telemetry else nil
    local rpm = if telemetry and telemetry.EngineRunning and not telemetry.EngineStalled then telemetry.EngineRpm else 0
    local encoded = InputCodec.encode(driverInput, sessionEnergyUsed(current), rpm)
    -- Lot AUDIO-03 : glissement sonore des pneus et revêtement déclarés (0 si le véhicule n'est pas simulé ici).
    local tires = if current.Simulating then lastTireSummary else nil
    InputCodec.appendTire(
        encoded,
        if tires then tires.Squeal else 0,
        TireAudioModel.surfaceCode(if tires then tires.Surface else "Hard")
    )
    local previous = current.LastSent
    local changed = previous == nil
    if previous then
        for i = 1, #encoded do
            if encoded[i] ~= previous[i] then
                changed = true
                break
            end
        end
    end
    if changed or current.KeepaliveTimer >= KEEPALIVE_S then
        current.KeepaliveTimer = 0
        current.LastSent = encoded
        activeRemotes.Input:FireServer(encoded)
    end
end

local function ownsSimulation(model: Model): boolean
    return model:GetAttribute(Constants.Attributes.SimulationOwnerUserId) == player.UserId
end

local function onPreSimulation(dt: number)
    evaluateSession()
    local current = session
    if current == nil then
        return
    end
    local provider = testInputProvider
    local driverInput = if provider then provider() else input:poll(dt)
    if driverInput.Clutch == nil then
        driverInput.Clutch = 0
    end
    current.LastInput = driverInput
    -- Pendant une correction serveur (ou si la propriété réseau n'a pas été
    -- confirmée), c'est le serveur qui simule : le client suspend sa simulation
    -- et repart d'un état neuf à la reprise (pas d'état figé ni de double calcul).
    local owns = ownsSimulation(current.Model)
    if owns ~= current.Simulating then
        if owns then
            -- Mesuré dans Studio : la copie locale d'un véhicule peut être périmée au
            -- moment où le serveur en confie la simulation ; simuler depuis cette
            -- position ferait « sauter » le véhicule (correction serveur). On repart
            -- donc de la position que le serveur a publiée lors de l'attribution.
            local pivot = current.Model:GetAttribute(Constants.Attributes.SimulationPivot)
            local root = current.Model.PrimaryPart
            if typeof(pivot) == "CFrame" and root and (root.Position - pivot.Position).Magnitude > RESYNC_DISTANCE then
                current.Model:PivotTo(pivot * root.CFrame:ToObjectSpace(current.Model:GetPivot()))
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                current.Resyncs += 1
            end
            -- La consommation du simulateur précédent reste comptée dans la session.
            current.EnergyBase += current.Simulator.State.EnergyUsed
            current.Simulator = newSimulator(current)
        else
            current.Simulator:release()
        end
        current.Simulating = owns
    end
    updateEnergyAvailability(current)
    if owns then
        current.Simulator:step(driverInput, dt)
        local root = current.Model.PrimaryPart
        if root then
            local now = os.clock()
            local history = current.VelocityHistory
            table.insert(history, { Time = now, Velocity = root.AssemblyLinearVelocity })
            while #history > 0 and now - history[1].Time > VELOCITY_HISTORY_S do
                table.remove(history, 1)
            end
        end
    else
        table.clear(current.VelocityHistory)
    end
    sendInput(current, driverInput, dt)
end

-- Complément d'impulsion demandé par le serveur après une collision confirmée
-- avec le véhicule d'un autre joueur (voir Physics/CollisionExchange). Seule la
-- part que notre propre simulation n'a pas déjà produite est appliquée.
local function onImpulse(model: any, normal: any, deltaV: any, point: any)
    local current = session
    if current == nil or not current.Simulating or model ~= current.Model then
        return
    end
    if typeof(normal) ~= "Vector3" or typeof(point) ~= "Vector3" or type(deltaV) ~= "number" then
        return
    end
    if deltaV ~= deltaV or deltaV <= 0 or deltaV > IMPULSE_MAX_DELTA_V then
        return
    end
    local root = current.Model.PrimaryPart
    local flat = Vector3.new(normal.X, 0, normal.Z)
    if root == nil or flat.Magnitude < 0.5 then
        return
    end
    local direction = flat.Unit
    local history = {}
    for _, sample in current.VelocityHistory do
        table.insert(history, sample.Velocity:Dot(direction))
    end
    local already = CollisionExchange.alreadyReceived(history, root.AssemblyLinearVelocity:Dot(direction))
    local missing = CollisionExchange.complement(deltaV, already)
    current.LastImpulse = missing
    if missing < IMPULSE_MIN_DELTA_V then
        return
    end
    local at = Vector3.new(point.X, root.Position.Y, point.Z)
    root:ApplyImpulseAtPosition(direction * (missing * root.AssemblyMass), at)
end

local function gearLabel(definition: Types.VehicleDefinition, gear: number): string
    if gear < 0 then
        return "R"
    elseif gear == 0 then
        return "N"
    end
    local kind = definition.Powertrain.Transmission.Kind
    if kind == "CVT" or kind == "SingleSpeed" then
        return "D"
    elseif kind == "Automatic" or kind == "DualClutch" then
        return "D" .. gear
    end
    return tostring(gear)
end

local function damageSummary(model: Model): (string, number)
    local state = DamageModel.fromAttributes(function(name)
        return model:GetAttribute(name)
    end)
    local parts = {}
    for _, zone in DamageModel.Zones do
        local level = DamageModel.visualLevel(state.Zones[zone])
        if level > 0 then
            table.insert(parts, ZONE_NAMES[zone] .. " " .. LEVEL_NAMES[level])
        end
    end
    local condition = DamageModel.condition(state)
    if condition.EnginePower < 0.999 then
        table.insert(parts, string.format("moteur %d %%", math.floor(condition.EnginePower * 100 + 0.5)))
    end
    if state.Steering < 0.999 then
        table.insert(parts, "direction faussée")
    end
    for corner, health in state.Suspension do
        if health < 0.999 then
            table.insert(parts, string.format("train %s", Constants.WheelNames[corner]))
        end
    end
    return if #parts == 0 then "aucun" else table.concat(parts, ", "), state.Impacts
end

local function regenText(definition: Types.VehicleDefinition, level: number): string?
    local motor = definition.Powertrain.Motor
    if motor == nil then
        return nil
    end
    local fraction = motor.RegenLevels[math.clamp(level, 1, #motor.RegenLevels)]
    return string.format("%d %%", math.floor(fraction * 100 + 0.5))
end

-- Signale les changements d'état décidés par le serveur ou la mécanique.
local function reportChanges(current: Session)
    local state = current.Simulator.State
    for _, aid in Constants.AidNames do
        local enabled = (state.Aids :: any)[aid] == true
        if current.LastAids[aid] ~= nil and current.LastAids[aid] ~= enabled then
            DevHud.showNotice("AidChanged", AID_LABELS[aid] .. " : " .. (if enabled then "activé" else "désactivé"))
        end
        current.LastAids[aid] = enabled
    end
    if state.RegenLevel ~= current.LastRegen then
        current.LastRegen = state.RegenLevel
        local text = regenText(current.Definition, state.RegenLevel)
        if text then
            DevHud.showNotice("RegenChanged", text)
        end
    end
    if state.EngineStalled and not current.LastStalled then
        DevHud.showNotice("EngineStalled")
    end
    current.LastStalled = state.EngineStalled
end

local function onPreRender(dt: number)
    local current = session
    local cam = Workspace.CurrentCamera
    if current then
        camera:update(dt)
        local simulator = current.Simulator
        local telemetry = simulator:getTelemetry()
        local state = simulator.State
        local definition = current.Definition
        local root = current.Model.PrimaryPart
        if root then
            local position = root.Position * METERS_PER_STUD
            Telemetry.update(
                measures,
                telemetry.SpeedKmh,
                telemetry.DriveThrottle,
                telemetry.BrakePedal,
                telemetry.Gear,
                position.X,
                position.Z,
                dt
            )
        end
        reportChanges(current)
        -- Option E de la proposition patinage : une roue motrice patine franchement, antipatinage équipé mais coupé →
        -- avis une fois par session (information seulement, aucune commande modifiée).
        if current.Simulating and not current.SpinNoticeShown then
            local timer, notify = SpinNotice.step(current.SpinTimer, state, definition, dt)
            current.SpinTimer = timer
            if notify then
                current.SpinNoticeShown = true
                DevHud.showNotice("TractionSpinAidOff")
            end
        end

        -- Consommation instantanée lissée (unités par seconde).
        local used = sessionEnergyUsed(current)
        if dt > 0 then
            local rate = math.max(used - current.LastEnergyUsed, 0) / dt
            current.ConsumptionRate += (rate - current.ConsumptionRate) * math.min(1, dt * 2)
        end
        current.LastEnergyUsed = used

        current.SlowTimer += dt
        if current.SlowTimer >= HUD_SLOW_REFRESH_S then
            current.SlowTimer = 0
            local text, impacts = damageSummary(current.Model)
            current.DamageText = text
            if impacts > current.LastImpacts then
                local condition = state.Condition
                if condition.EnginePower < 0.999 or condition.SteeringRange < 0.999 then
                    DevHud.showNotice("DamageMechanical")
                end
            end
            current.LastImpacts = impacts
        end

        local powertrain = definition.Powertrain
        local store = powertrain.Energy
        local predicted =
            EnergyModel.predictLevel(current.ServerLevel, sessionEnergyUsed(current) - current.UsedAtServerLevel)
        local unit = EnergyModel.unit(definition)
        local perHundred = if telemetry.SpeedKmh > 5
            then current.ConsumptionRate * 3600 / telemetry.SpeedKmh * 100
            else nil
        local energyText = string.format(
            "%s %.1f %s (%d %%)%s",
            if store.Kind == "Electric" then "Batterie" else "Réservoir",
            math.max(predicted, 0),
            unit,
            math.floor(math.max(predicted, 0) / store.Capacity * 100 + 0.5),
            if perHundred
                then string.format(" · %.1f %s/100 km", perHundred, unit)
                else string.format(" · %.2f %s/h", current.ConsumptionRate * 3600, unit)
        )
        local engineText = if powertrain.Engine
            then string.format(
                "Moteur %s",
                if state.EngineRunning then "en marche" elseif state.EngineStalled then "CALÉ" else "arrêté"
            )
            else string.format(
                "Moteur électrique %s · %d kW",
                if state.EngineRunning then "prêt" else "coupé",
                math.floor(state.PowerKw + 0.5)
            )

        local aids: { DevHud.AidLine } = {}
        local settings = settingsOf(definition)
        local selected = settings[math.clamp(current.Selection, 1, math.max(#settings, 1))]
        for _, aid in Constants.AidNames do
            local present = (definition.Aids :: any)[aid] == true
            local enabled = (state.Aids :: any)[aid] == true
            local acting = (state.AidActivity :: any)[aid] == true
            table.insert(aids, {
                Label = AID_LABELS[aid],
                Status = if not present
                    then "Absente"
                    elseif not enabled then "Off"
                    elseif acting then "Active"
                    else "On",
                Selected = selected == aid,
            })
        end
        local regen = regenText(definition, state.RegenLevel)
        local redline = if powertrain.Engine
            then powertrain.Engine.RedlineRpm
            else (powertrain.Motor :: Types.ElectricMotorDefinition).MaxRpm

        lastTireSummary = tireSummary(current)
        DevHud.update({
            SpeedKmh = telemetry.SpeedKmh,
            Gear = telemetry.Gear,
            GearLabel = gearLabel(definition, telemetry.Gear),
            EngineRpm = telemetry.EngineRpm,
            RedlineRpm = redline,
            Throttle = current.LastInput.Throttle,
            Brake = current.LastInput.Brake,
            Clutch = telemetry.ClutchPedal,
            ShowClutch = powertrain.Transmission.Kind == "Manual",
            Steer = telemetry.SteerPosition,
            EnergyFraction = math.max(predicted, 0) / store.Capacity,
            EnergyText = energyText,
            Aids = aids,
            RegenText = if regen
                then string.format(
                    "%sRécupération au lâcher : %s",
                    if selected == "Regen" then "▶ " else "",
                    regen
                )
                else nil,
            EngineText = engineText,
            DamageText = current.DamageText,
            CameraName = camera:presetName(),
            LastLaunchSeconds = measures.LastLaunchSeconds,
            BestLaunchSeconds = measures.BestLaunchSeconds,
            LastBrakeDistanceM = measures.LastBrakeDistanceM,
            TransmissionKind = powertrain.Transmission.Kind,
            Electric = powertrain.Engine == nil,
            Stalled = state.EngineStalled,
            EngineRunning = telemetry.EngineRunning,
            -- Charge RÉELLE du moteur pour le son (lot AUDIO-01) : nulle pendant un passage de rapport (couple coupé par
            -- la boîte, VehicleDynamics), sinon accélérateur effectif après les aides.
            EngineLoad = if state.ShiftTimer > 0 then 0 else telemetry.DriveThrottle,
            TireAudio = lastTireSummary,
            Model = current.Model,
        })
    end
    -- Lot ANIM-01 : état de simulation du véhicule piloté, relu par le volant affiché (référence vivante).
    SteeringWheelVisuals.setLocal(
        if current then current.Model else nil,
        if current then current.Simulator.State else nil
    )
    if cam then
        WheelVisuals.update(
            dt,
            cam.CFrame.Position,
            if current then current.Model else nil,
            if current then current.Simulator.State else nil
        )
    end
end

local function isGamepadInput(inputType: Enum.UserInputType): boolean
    return inputType.Name:sub(1, 7) == "Gamepad"
end

function VehicleController.start()
    local folder = ReplicatedStorage:WaitForChild(Constants.RemotesFolderName)
    remotes = {
        Action = folder:WaitForChild(Constants.Remotes.Action) :: RemoteEvent,
        Input = folder:WaitForChild(Constants.Remotes.Input) :: UnreliableRemoteEvent,
        Notice = folder:WaitForChild(Constants.Remotes.Notice) :: RemoteEvent,
        Impulse = folder:WaitForChild(Constants.Remotes.Impulse) :: RemoteEvent,
    }
    local activeRemotes = remotes :: Remotes
    activeRemotes.Impulse.OnClientEvent:Connect(onImpulse)
    activeRemotes.Notice.OnClientEvent:Connect(function(key: any, value: any)
        if type(key) ~= "string" then
            return
        end
        DevHud.showNotice(key, value)
        if key == "VehicleUnavailable" then
            -- Le serveur libère le siège (après un court délai) ; l'état « assis » du
            -- personnage est tenu par ce client : on le relève tant qu'il reste assis
            -- sur un siège conducteur sans conduire (mesuré dans Studio : sinon il
            -- reste assis sur un véhicule qu'il ne peut pas conduire).
            task.spawn(function()
                local deadline = os.clock() + STAND_UP_WINDOW_S
                while os.clock() < deadline do
                    local humanoid = currentHumanoid()
                    local seatPart = if humanoid then humanoid.SeatPart else nil
                    if humanoid and seatPart and seatPart.Name == "DriverSeat" and session == nil then
                        humanoid.Sit = false
                        humanoid.Jump = true
                    end
                    task.wait(0.3)
                end
            end)
        end
    end)

    DevHud.setInputMode(isGamepadInput(UserInputService:GetLastInputType()))
    UserInputService.LastInputTypeChanged:Connect(function(inputType)
        DevHud.setInputMode(isGamepadInput(inputType))
    end)

    input:setEventHandler(function(event)
        if session ~= nil then
            DevHud.showNotice(event)
        end
    end)

    player.CharacterRemoving:Connect(function()
        endSession()
    end)

    RunService.PreSimulation:Connect(onPreSimulation)
    RunService.PreRender:Connect(onPreRender)
end

--[[
    Points d'accès RÉSERVÉS aux tests automatisés exécutés dans Roblox Studio
    (tests/studio). Ils refusent de fonctionner hors de Studio.
    - `setTestInputProvider` remplace UNIQUEMENT la lecture clavier/manette :
      simulation, forces, réseau, caméra et HUD restent le vrai chemin du jeu.
    - `invokeActionForTest` appelle le MÊME gestionnaire que la touche ou le
      bouton lié (rapports, aides, caméra…) : la lecture réelle des touches
      reste un essai humain.
    - `getTestSnapshot` expose une copie en lecture seule de l'état de conduite.
]]
function VehicleController.setTestInputProvider(provider: (() -> Types.DriverInput)?)
    assert(RunService:IsStudio(), "Réservé aux tests automatisés dans Studio")
    testInputProvider = provider
end

function VehicleController.invokeActionForTest(name: string): boolean
    assert(RunService:IsStudio(), "Réservé aux tests automatisés dans Studio")
    local handler = handlers[name]
    if handler == nil then
        return false
    end
    -- Contourne seulement l'anti-rebond (les essais enchaînent les commandes).
    lastActionTime = 0
    if session then
        (session :: Session).LastShift = 0
    end
    handler()
    return true
end

-- Liaisons déclarées (vérifiées par les essais : chaque action a une touche ET un bouton).
function VehicleController.bindingsForTest(): { [string]: { string } }
    assert(RunService:IsStudio(), "Réservé aux tests automatisés dans Studio")
    local result = {}
    for _, binding in BINDINGS do
        local names = {}
        for _, key in binding.Keys do
            table.insert(names, key.Name)
        end
        result[binding.Name] = names
    end
    return result
end

export type TestSnapshot = {
    Driving: boolean,
    SimulationActive: boolean,
    ActiveDevice: string?,
    Typing: boolean,
    -- Dernier complément d'impulsion appliqué (studs/s), nil si aucun.
    LastImpulse: number?,
    -- Recalages de la copie locale sur la position serveur (session en cours).
    Resyncs: number,
    -- Âge des dernières données physiques reçues pour le véhicule (0 quand ce
    -- client le simule réellement) : diagnostic de la propriété réseau.
    ReceiveAge: number,
    VehicleName: string?,
    DefinitionId: string?,
    SpeedKmh: number,
    ForwardSpeedMs: number,
    Gear: number,
    EngineRpm: number,
    GroundedWheels: number,
    LastLaunchSeconds: number?,
    LastBrakeDistanceM: number?,
    -- Lot 0.2
    EngineRunning: boolean,
    EngineStalled: boolean,
    ClutchPedal: number,
    Coupled: boolean,
    CvtRatio: number,
    YawRate: number,
    WetWheels: number,
    EnergyUsed: number,
    EnergyRecovered: number,
    ServerEnergyLevel: number,
    EnergyAvailable: boolean,
    Aids: { [string]: boolean },
    AidActivity: { [string]: boolean },
    RegenLevel: number,
    EnginePower: number,
    SteeringPullRad: number,
    CameraName: string,
    HudSystems: string,
    Perf: VehicleSimulator.PerfReport?,
    WheelSlip: { number },
    BrakeTorque: { number },
}

function VehicleController.getTestSnapshot(): TestSnapshot
    assert(RunService:IsStudio(), "Réservé aux tests automatisés dans Studio")
    local current = session
    if current == nil then
        return {
            Driving = false,
            SimulationActive = false,
            ActiveDevice = input.Arbiter.Active,
            Typing = DriverInput.isTyping(),
            LastImpulse = nil,
            Resyncs = 0,
            ReceiveAge = 0,
            VehicleName = nil,
            DefinitionId = nil,
            SpeedKmh = 0,
            ForwardSpeedMs = 0,
            Gear = 0,
            EngineRpm = 0,
            GroundedWheels = 0,
            LastLaunchSeconds = measures.LastLaunchSeconds,
            LastBrakeDistanceM = measures.LastBrakeDistanceM,
            EngineRunning = false,
            EngineStalled = false,
            ClutchPedal = 0,
            Coupled = false,
            CvtRatio = 0,
            YawRate = 0,
            WetWheels = 0,
            EnergyUsed = 0,
            EnergyRecovered = 0,
            ServerEnergyLevel = 0,
            EnergyAvailable = false,
            Aids = {},
            AidActivity = {},
            RegenLevel = 1,
            EnginePower = 1,
            SteeringPullRad = 0,
            CameraName = camera:presetName(),
            HudSystems = DevHud.systemsText(),
            Perf = nil,
            WheelSlip = {},
            BrakeTorque = {},
        }
    end
    local simulator = current.Simulator
    local telemetry = simulator:getTelemetry()
    local state = simulator.State
    local slips, brakes = {}, {}
    for index, wheel in state.Wheels do
        slips[index] = wheel.SlipRatio
        brakes[index] = wheel.BrakeTorque
    end
    return {
        Driving = true,
        SimulationActive = current.Simulating,
        ActiveDevice = input.Arbiter.Active,
        Typing = DriverInput.isTyping(),
        LastImpulse = current.LastImpulse,
        Resyncs = current.Resyncs,
        ReceiveAge = if current.Model.PrimaryPart then current.Model.PrimaryPart.ReceiveAge else 0,
        VehicleName = current.Model.Name,
        DefinitionId = current.Definition.Id,
        SpeedKmh = telemetry.SpeedKmh,
        ForwardSpeedMs = telemetry.ForwardSpeedMs,
        Gear = telemetry.Gear,
        EngineRpm = telemetry.EngineRpm,
        GroundedWheels = telemetry.GroundedWheels,
        LastLaunchSeconds = measures.LastLaunchSeconds,
        LastBrakeDistanceM = measures.LastBrakeDistanceM,
        EngineRunning = state.EngineRunning,
        EngineStalled = state.EngineStalled,
        ClutchPedal = state.ClutchPedal,
        Coupled = state.Coupled,
        CvtRatio = state.CvtRatio,
        YawRate = telemetry.YawRate,
        WetWheels = telemetry.WetWheels,
        EnergyUsed = sessionEnergyUsed(current),
        EnergyRecovered = state.EnergyRecovered,
        ServerEnergyLevel = current.ServerLevel,
        EnergyAvailable = current.EnergyAvailable,
        Aids = table.clone(state.Aids) :: any,
        AidActivity = table.clone(state.AidActivity) :: any,
        RegenLevel = state.RegenLevel,
        EnginePower = state.Condition.EnginePower,
        SteeringPullRad = state.Condition.SteeringPullRad,
        CameraName = camera:presetName(),
        HudSystems = DevHud.systemsText(),
        Perf = simulator:getPerf(),
        WheelSlip = slips,
        BrakeTorque = brakes,
    }
end

-- Lot CAMERA-01 : caméra du véhicule piloté, pour les lots de la 2e vague
-- (visée imposée, bras visibles en cockpit ; voir VehicleCamera). Instance
-- unique, valable entre deux sessions de conduite.
function VehicleController.getCamera(): VehicleCamera.VehicleCamera
    return camera
end

-- Lot PHONE-01 : vrai pendant une session de conduite (la caméra du véhicule est alors active ; le zoom du
-- téléphone passe par sa visée imposée, sinon par la caméra par défaut).
function VehicleController.isDriving(): boolean
    return session ~= nil
end

-- Bascule de caméra par le même code que la touche V (tests Studio uniquement).
function VehicleController.toggleCameraForTest(): string
    assert(RunService:IsStudio(), "Réservé aux tests automatisés dans Studio")
    return camera:togglePreset()
end

-- Remise à zéro des mesures de coût de la simulation locale (tests Studio).
function VehicleController.resetPerfForTest()
    assert(RunService:IsStudio(), "Réservé aux tests automatisés dans Studio")
    local current = session
    if current then
        current.Simulator:resetPerf()
    end
end

return VehicleController
