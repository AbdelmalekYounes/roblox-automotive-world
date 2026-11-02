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

type Session = {
    Model: Model,
    Seat: Seat,
    Definition: Types.VehicleDefinition,
    Simulator: VehicleSimulator.VehicleSimulator,
    LastInput: Types.DriverInput,
    SendTimer: number,
    KeepaliveTimer: number,
    LastSent: { number }?,
}

type Remotes = {
    Action: RemoteEvent,
    Input: UnreliableRemoteEvent,
    Notice: RemoteEvent,
}

local session: Session? = nil
local remotes: Remotes? = nil
local input = DriverInput.new()
local camera = VehicleCamera.new()
local measures = Telemetry.new()
local lastActionTime = 0

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

local function onExitAction(_: string, state: Enum.UserInputState): Enum.ContextActionResult
    if state == Enum.UserInputState.Begin then
        sendAction(Constants.Actions.Exit)
    end
    return Enum.ContextActionResult.Sink
end

local function onUnflipAction(_: string, state: Enum.UserInputState): Enum.ContextActionResult
    if state == Enum.UserInputState.Begin then
        sendAction(Constants.Actions.Unflip)
    end
    return Enum.ContextActionResult.Sink
end

local function onCameraAction(_: string, state: Enum.UserInputState): Enum.ContextActionResult
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

local function aidsDescription(definition: Types.VehicleDefinition): string
    local aids = definition.Aids
    if not (aids.Abs or aids.TractionControl or aids.StabilityControl) then
        return "Aides : aucune (ABS, antipatinage et ESP absents de ce modèle)"
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

local function onPreSimulation(dt: number)
    evaluateSession()
    local current = session
    if current == nil then
        return
    end
    local driverInput = input:poll(dt)
    current.LastInput = driverInput
    current.Simulator:step(driverInput, dt)
    sendInput(current, driverInput, dt)
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
    }
    local activeRemotes = remotes :: Remotes
    activeRemotes.Notice.OnClientEvent:Connect(function(key: any, value: any)
        if type(key) == "string" then
            DevHud.showNotice(key, value)
        end
    end)

    DevHud.setInputMode(isGamepadInput(UserInputService:GetLastInputType()))
    UserInputService.LastInputTypeChanged:Connect(function(inputType)
        DevHud.setInputMode(isGamepadInput(inputType))
    end)

    player.CharacterRemoving:Connect(function()
        endSession()
    end)

    RunService.PreSimulation:Connect(onPreSimulation)
    RunService.PreRender:Connect(onPreRender)
end

return VehicleController
