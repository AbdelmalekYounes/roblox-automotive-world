--!strict
-- Contrôleur client de la conduite.
--
-- Cycle de vie : lorsque le serveur a assis le joueur sur un siège conducteur
-- ET lui a attribué le véhicule (attribut DriverUserId), une session de
-- conduite démarre : commandes, simulation locale, caméra, HUD. Elle s'arrête
-- dès que l'une de ces conditions n'est plus vraie (sortie, mort, correction).
-- Le client n'envoie au serveur que des commandes bornées et des demandes
-- d'action ; il ne décide jamais seul d'un état critique.

local ContextActionService = game:GetService("ContextActionService")
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
local InputCodec = require(VehiclesShared:WaitForChild("InputCodec"))
local Telemetry = require(VehiclesShared:WaitForChild("Telemetry"))
local CollisionExchange = require(VehiclesShared:WaitForChild("Physics"):WaitForChild("CollisionExchange"))

local DriverInput = require(script.Parent.DriverInput)
local VehicleCamera = require(script.Parent.VehicleCamera)
local WheelVisuals = require(script.Parent.WheelVisuals)
local DevHud = require(script.Parent.Parent.UI.DevHud)

local VehicleController = {}

local player = Players.LocalPlayer
local METERS_PER_STUD = Constants.MetersPerStud
local SEND_INTERVAL_S = 1 / Constants.InputSendRateHz
local KEEPALIVE_S = 0.5
local ACTION_DEBOUNCE_S = 0.4
local ACTION_PRIORITY = Enum.ContextActionPriority.High.Value + 10
local VELOCITY_HISTORY_S = 1.5
-- Borne défensive d'un complément d'impulsion reçu (studs/s, ≈ 60 km/h).
local IMPULSE_MAX_DELTA_V = 60
local IMPULSE_MIN_DELTA_V = 0.3
-- Écart (studs) au-delà duquel la copie locale est recalée sur la position serveur.
local RESYNC_DISTANCE = 3
-- Durée pendant laquelle le personnage est relevé après un refus de prise en main.
local STAND_UP_WINDOW_S = 3

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

local function sendAction(action: string)
    local now = os.clock()
    if now - lastActionTime < ACTION_DEBOUNCE_S or remotes == nil then
        return
    end
    lastActionTime = now
    remotes.Action:FireServer(action)
end

-- Une touche du clavier ne déclenche aucune action pendant une saisie de
-- texte (chat, champ de saisie) : protection explicite, en plus de celle du moteur.
local function keyboardBlocked(inputObject: InputObject?): boolean
    return inputObject ~= nil and inputObject.UserInputType == Enum.UserInputType.Keyboard and DriverInput.isTyping()
end

local function onExitAction(_: string, state: Enum.UserInputState, inputObject: InputObject?): Enum.ContextActionResult
    if keyboardBlocked(inputObject) then
        return Enum.ContextActionResult.Pass
    end
    if state == Enum.UserInputState.Begin then
        sendAction(Constants.Actions.Exit)
    end
    return Enum.ContextActionResult.Sink
end

local function onUnflipAction(
    _: string,
    state: Enum.UserInputState,
    inputObject: InputObject?
): Enum.ContextActionResult
    if keyboardBlocked(inputObject) then
        return Enum.ContextActionResult.Pass
    end
    if state == Enum.UserInputState.Begin then
        sendAction(Constants.Actions.Unflip)
    end
    return Enum.ContextActionResult.Sink
end

local function onCameraAction(
    _: string,
    state: Enum.UserInputState,
    inputObject: InputObject?
): Enum.ContextActionResult
    if keyboardBlocked(inputObject) then
        return Enum.ContextActionResult.Pass
    end
    if state == Enum.UserInputState.Begin then
        DevHud.showNotice("CameraPreset", camera:togglePreset())
    end
    return Enum.ContextActionResult.Sink
end

-- Absorbe les touches de conduite pour qu'aucune autre action ne s'y greffe.
local function sinkAction(): Enum.ContextActionResult
    return Enum.ContextActionResult.Sink
end

local function bindActions()
    ContextActionService:BindActionAtPriority(
        "AWVehicleExit",
        onExitAction,
        false,
        ACTION_PRIORITY,
        Enum.KeyCode.F,
        Enum.KeyCode.ButtonY
    )
    ContextActionService:BindActionAtPriority(
        "AWVehicleUnflip",
        onUnflipAction,
        false,
        ACTION_PRIORITY,
        Enum.KeyCode.R,
        Enum.KeyCode.DPadDown
    )
    ContextActionService:BindActionAtPriority(
        "AWVehicleCamera",
        onCameraAction,
        false,
        ACTION_PRIORITY,
        Enum.KeyCode.V,
        Enum.KeyCode.DPadUp
    )
    ContextActionService:BindActionAtPriority(
        "AWVehicleSink",
        sinkAction,
        false,
        ACTION_PRIORITY,
        Enum.KeyCode.Space,
        Enum.KeyCode.ButtonA
    )
end

local function unbindActions()
    for _, name in { "AWVehicleExit", "AWVehicleUnflip", "AWVehicleCamera", "AWVehicleSink" } do
        ContextActionService:UnbindAction(name)
    end
end

-- Affiche les aides ET la réduction de braquage avec la vitesse (A1) : rien
-- de ce qui modifie la commande du joueur n'est caché.
local function aidsDescription(definition: Types.VehicleDefinition): string
    local aids = definition.Aids
    local steering = definition.Steering
    local steeringText = string.format(
        "braquage %d° → %d° à %d km/h",
        steering.MaxAngleDeg,
        steering.HighSpeedAngleDeg,
        steering.HighSpeedReferenceKmh
    )
    if not (aids.Abs or aids.TractionControl or aids.StabilityControl) then
        return "Aides : aucune · " .. steeringText
    end
    return "Aides : configuration non prise en charge dans le lot 0.1"
end

local function currentHumanoid(): Humanoid?
    local character = player.Character
    return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function endSession()
    local current = session
    if current == nil then
        return
    end
    session = nil
    current.Simulator:release()
    input:reset()
    unbindActions()
    camera:stop(currentHumanoid())
    setDefaultControls(true)
    DevHud.hide()
    measures = Telemetry.new()
end

local function beginSession(model: Model, seat: Seat)
    local definitionId = model:GetAttribute(Constants.Attributes.DefinitionId)
    local definition = if type(definitionId) == "string" then VehicleDefinitions.get(definitionId) else nil
    if definition == nil or model.PrimaryPart == nil then
        return
    end
    session = {
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
    }
    input:reset()
    measures = Telemetry.new()
    setDefaultControls(false)
    bindActions()
    camera:start(model, player.Character)
    DevHud.show(definition.DisplayName, aidsDescription(definition))
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
    local encoded = InputCodec.encode(driverInput)
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
            current.Simulator = VehicleSimulator.new(current.Model, current.Definition)
        else
            current.Simulator:release()
        end
        current.Simulating = owns
    end
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

local function onPreRender(dt: number)
    local current = session
    local cam = Workspace.CurrentCamera
    if current then
        camera:update(dt)
        local telemetry = current.Simulator:getTelemetry()
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
        DevHud.update({
            SpeedKmh = telemetry.SpeedKmh,
            Gear = telemetry.Gear,
            EngineRpm = telemetry.EngineRpm,
            RedlineRpm = current.Definition.Powertrain.Engine.RedlineRpm,
            Throttle = current.LastInput.Throttle,
            Brake = current.LastInput.Brake,
            Steer = telemetry.SteerPosition,
            LastLaunchSeconds = measures.LastLaunchSeconds,
            BestLaunchSeconds = measures.BestLaunchSeconds,
            LastBrakeDistanceM = measures.LastBrakeDistanceM,
        })
    end
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
    - `getTestSnapshot` expose une copie en lecture seule de l'état de conduite.
]]
function VehicleController.setTestInputProvider(provider: (() -> Types.DriverInput)?)
    assert(RunService:IsStudio(), "Réservé aux tests automatisés dans Studio")
    testInputProvider = provider
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
    SpeedKmh: number,
    ForwardSpeedMs: number,
    Gear: number,
    EngineRpm: number,
    GroundedWheels: number,
    LastLaunchSeconds: number?,
    LastBrakeDistanceM: number?,
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
            SpeedKmh = 0,
            ForwardSpeedMs = 0,
            Gear = 0,
            EngineRpm = 0,
            GroundedWheels = 0,
            LastLaunchSeconds = measures.LastLaunchSeconds,
            LastBrakeDistanceM = measures.LastBrakeDistanceM,
        }
    end
    local telemetry = current.Simulator:getTelemetry()
    return {
        Driving = true,
        SimulationActive = current.Simulating,
        ActiveDevice = input.Arbiter.Active,
        Typing = DriverInput.isTyping(),
        LastImpulse = current.LastImpulse,
        Resyncs = current.Resyncs,
        ReceiveAge = if current.Model.PrimaryPart then current.Model.PrimaryPart.ReceiveAge else 0,
        VehicleName = current.Model.Name,
        SpeedKmh = telemetry.SpeedKmh,
        ForwardSpeedMs = telemetry.ForwardSpeedMs,
        Gear = telemetry.Gear,
        EngineRpm = telemetry.EngineRpm,
        GroundedWheels = telemetry.GroundedWheels,
        LastLaunchSeconds = measures.LastLaunchSeconds,
        LastBrakeDistanceM = measures.LastBrakeDistanceM,
    }
end

-- Bascule de caméra par le même code que la touche V (tests Studio uniquement).
function VehicleController.toggleCameraForTest(): string
    assert(RunService:IsStudio(), "Réservé aux tests automatisés dans Studio")
    return camera:togglePreset()
end

return VehicleController
