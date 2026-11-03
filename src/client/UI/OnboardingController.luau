--!strict
--[[
    Parcours de première connexion (lot 0.8) côté client : écrans courts et
    PASSABLES (accueil, univers, commandes, téléphone/carte/GPS, véhicules de
    départ avec comparatif et essai facultatif, choix CONFIRMÉ explicitement,
    propriété gratuite, accès au monde), puis exercices de formation
    facultatifs. Toute décision est prise par le serveur (AWOnboarding) ; le
    choix passe par la transaction unique du véhicule de départ.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared:WaitForChild("UI"):WaitForChild("Localization"))
local TrainingRules = require(Shared:WaitForChild("Onboarding"):WaitForChild("TrainingRules"))
local OnboardingRules = require(Shared.Onboarding.OnboardingRules)
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))

local UITheme = require(script.Parent.UITheme)
local UIManager = require(script.Parent.UIManager)
local InputRouter = require(script.Parent.InputRouter)
local NotificationService = require(script.Parent.NotificationService)
local DevHud = require(script.Parent.DevHud)
local GPSController = require(script.Parent.GPSController)
local MapController = require(script.Parent.MapController)

local OnboardingController = {}

local S = 1 / Constants.MetersPerStud

local request: RemoteFunction
local gui: ScreenGui
local window: Frame
local title: TextLabel
local body: ScrollingFrame
local footer: TextLabel
local status: any = nil
local confirming: string? = nil
local page = "Flow"
local active: TrainingRules.Progress? = nil
local missionActive = false
local order = 0

local function ask(action: string, payload: any?): any
    local ok, response = pcall(function()
        return request:InvokeServer(action, payload or {})
    end)
    if not ok or type(response) ~= "table" then
        return { Status = "Error", Error = "ServerUnreachable" }
    end
    if type(response.Result) == "table" and response.Result.State then
        status = response.Result
    end
    return response
end

local render: () -> ()

local function clear()
    for _, child in body:GetChildren() do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
    order = 0
end

local function line(text: string, size: number?, bold: boolean?)
    order += 1
    UITheme.label(text, size or 16, {
        Size = UDim2.new(1, -8, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = if bold then UITheme.FontBold else UITheme.Font,
        LayoutOrder = order,
    }, body)
end

local function button(text: string, fn: () -> ())
    order += 1
    UITheme.button(text, { Size = UDim2.new(1, -8, 0, 36), LayoutOrder = order }, body, fn)
end

local function report(response: any)
    footer.Text = if response.Status == "Ok"
            or response.Status == "Confirmed"
            or response.Status == "Pending"
        then Localization.t("ui.done")
        else Localization.t("ui.refused", { reason = Localization.t(response.Error) })
end

local function step(name: string)
    report(ask("Advance", { Step = name }))
    render()
end

local function candidateLine(c: any): string
    return Localization.t("onb.candidate", {
        name = c.Name,
        category = Localization.t("vehicle." .. c.Id .. ".category"),
        energy = Localization.t("energy." .. c.Energy),
        gearbox = Localization.t("hud.transmission." .. c.Gearbox),
        layout = Localization.t("layout." .. c.Layout),
        power = c.PowerKw,
        mass = c.MassKg,
        price = Localization.amount(c.Price),
    })
end

local function renderFlow()
    local state = status and status.State
    if state == nil then
        line(Localization.t("ui.loading"))
        return
    end
    local current = state.Step
    title.Text = Localization.t("onb.title." .. current)
    if current == "Welcome" or current == "World" or current == "Controls" or current == "Phone" then
        line(Localization.t("onb.text." .. current))
        button(Localization.t("onb.next"), function()
            step(current)
        end)
        button(Localization.t("onb.skip"), function()
            report(ask("Skip"))
            render()
        end)
    elseif current == "Starters" or current == "Choose" then
        if status.Synthetic then
            line(Localization.t("onb.devCandidates"), 14)
        end
        if #status.Candidates == 0 then
            line(Localization.t("StarterCatalogUnavailable"))
        end
        for _, candidate in status.Candidates do
            line(candidateLine(candidate), 15, true)
            line(Localization.t("vehicle." .. candidate.Id .. ".desc"), 14)
            button(Localization.t("onb.testDrive", { name = candidate.Name }), function()
                report(ask("TestDrive", { ModelId = candidate.Id }))
                UIManager.close("Onboarding")
            end)
            button(Localization.t("onb.choose", { name = candidate.Name }), function()
                confirming = candidate.Id
                InputRouter.armConfirm()
                render()
            end)
        end
        if status.TestDriveActive then
            button(Localization.t("onb.endTestDrive"), function()
                report(ask("EndTestDrive"))
                render()
            end)
        end
        if current == "Starters" then
            button(Localization.t("onb.next"), function()
                step("Starters")
            end)
        end
        if confirming then
            local chosen: any = nil
            for _, candidate in status.Candidates do
                if candidate.Id == confirming then
                    chosen = candidate
                end
            end
            line(Localization.t("onb.confirmChoice", { name = if chosen then chosen.Name else "" }), 16, true)
            button(Localization.t("ui.confirm"), function()
                -- Confirmation explicite, d'une pression neuve (changement de périphérique : refus).
                if not InputRouter.confirmAllowed() then
                    footer.Text = Localization.t("ui.confirmAgain")
                    return
                end
                local id = confirming
                confirming = nil
                report(ask("Choose", { ModelId = id }))
                render()
            end)
            button(Localization.t("ui.cancel"), function()
                confirming = nil
                render()
            end)
        end
    elseif current == "Property" then
        line(Localization.t(if status.PropertyGranted then "onb.text.Property" else "onb.propertyPending"))
        button(Localization.t("phone.property.navigate"), function()
            for _, point in MapController.points() do
                if point.Kind == "Property" then
                    GPSController.setDestination(point.X, point.Z, point.Name, "Poi")
                    break
                end
            end
        end)
        button(Localization.t("onb.next"), function()
            step("Property")
        end)
    else
        line(Localization.t("onb.text.Done"))
        button(Localization.t("onb.training"), function()
            page = "Training"
            render()
        end)
        button(Localization.t("onb.enterWorld"), function()
            UIManager.close("Onboarding")
        end)
    end
end

local function renderTraining()
    title.Text = Localization.t("onb.training")
    line(Localization.t("onb.trainingText"), 14)
    local done = if status and status.State then status.State.Exercises else {}
    for _, id in OnboardingRules.Exercises do
        local finished = done[id] ~= nil
        button(string.format("%s %s", if finished then "✓" else "○", Localization.t("exercise." .. id)), function()
            local character = Players.LocalPlayer.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local first = nil
            if root and root:IsA("BasePart") then
                local look = root.CFrame.LookVector
                first = {
                    T = os.clock(),
                    SpeedKmh = 0,
                    Heading = math.atan2(look.X, -look.Z),
                    Gear = 0,
                    X = root.Position.X / S,
                    Z = root.Position.Z / S,
                    InVehicle = false,
                }
            end
            active = TrainingRules.start(id, first)
            NotificationService.notify("exercise." .. id .. ".hint", "Info", nil, "exercise")
            UIManager.close("Onboarding")
        end)
    end
    button(Localization.t("ui.back"), function()
        page = "Flow"
        render()
    end)
end

render = function()
    if not gui.Enabled then
        return
    end
    clear()
    if page == "Training" then
        renderTraining()
    else
        renderFlow()
    end
end

-- Suivi de l'exercice en cours (observations locales ; seul le résultat « fait » est envoyé).
local function trackExercise()
    local progress = active
    if progress == nil then
        return
    end
    local character = Players.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root == nil or not root:IsA("BasePart") then
        return
    end
    local data = DevHud.latest()
    local look = root.CFrame.LookVector
    local x, z = root.Position.X / S, root.Position.Z / S
    local nearGarage = false
    for _, point in MapController.points() do
        if point.Kind == "PublicGarage" and math.sqrt((point.X - x) ^ 2 + (point.Z - z) ^ 2) < 40 then
            nearGarage = true
        end
    end
    local finished = TrainingRules.observe(progress, {
        T = os.clock(),
        SpeedKmh = if data then data.SpeedKmh else 0,
        Heading = math.atan2(look.X, -look.Z),
        Gear = if data then data.Gear else 0,
        X = x,
        Z = z,
        InVehicle = data ~= nil,
        GpsActive = GPSController.state().Destination ~= nil,
        NearGarage = nearGarage,
        MissionActive = missionActive,
        RacesOpened = UIManager.isOpen("Races"),
    })
    if finished then
        active = nil
        ask("Exercise", { Id = progress.Id })
        NotificationService.notify("exercise.done", "Info", { name = Localization.t("exercise." .. progress.Id) })
    end
end

function OnboardingController.openTraining()
    page = "Training"
    UIManager.open("Onboarding")
end

function OnboardingController.start()
    local folder = ReplicatedStorage:WaitForChild("AWOnboarding")
    request = folder:WaitForChild("Request") :: RemoteFunction
    local push = folder:WaitForChild("Push") :: RemoteEvent
    gui = UITheme.make(
        "ScreenGui",
        { Name = "AWOnboarding", ResetOnSpawn = false, DisplayOrder = 15, Enabled = false },
        Players.LocalPlayer:WaitForChild("PlayerGui")
    )
    window = UITheme.panel({
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(640, 560),
    }, gui)
    title = UITheme.label("", 22, {
        Position = UDim2.fromOffset(20, 14),
        Size = UDim2.new(1, -40, 0, 32),
        Font = UITheme.FontBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = UITheme.color("Accent"),
    }, window)
    body = UITheme.make("ScrollingFrame", {
        Position = UDim2.fromOffset(16, 54),
        Size = UDim2.new(1, -32, 1, -100),
        BackgroundTransparency = 1,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 6,
    }, window)
    UITheme.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, body)
    footer = UITheme.label("", 14, {
        Position = UDim2.new(0, 20, 1, -40),
        Size = UDim2.new(1, -40, 0, 30),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = UITheme.color("Warn"),
    }, window)
    UIManager.register({
        Name = "Onboarding",
        Kind = "Modal",
        Full = true,
        Open = function()
            gui.Enabled = true
            ask("Status")
            render()
        end,
        Close = function()
            gui.Enabled = false
        end,
        Focus = function()
            return body:FindFirstChildWhichIsA("GuiButton")
        end,
    })
    Localization.changed(function()
        render()
    end)
    push.OnClientEvent:Connect(function(kind: any, data: any)
        if kind == "Status" and type(data) == "table" then
            status = data
            -- Première connexion : le parcours s'ouvre de lui-même (passable).
            if data.State and not OnboardingRules.completed(data.State) and not UIManager.isOpen("Onboarding") then
                page = "Flow"
                UIManager.open("Onboarding")
            end
            render()
        end
    end)
    local economy = ReplicatedStorage:FindFirstChild("AWEconomy")
    local economyPush = economy and economy:FindFirstChild("Push")
    if economyPush and economyPush:IsA("RemoteEvent") then
        economyPush.OnClientEvent:Connect(function(kind: any, data: any)
            if kind == "Snapshot" and type(data) == "table" then
                missionActive = data.Mission ~= nil
            end
        end)
    end
    local timer = 0
    RunService.Heartbeat:Connect(function(dt)
        timer += dt
        if timer >= 0.2 then
            timer = 0
            trackExercise()
        end
    end)
end

return OnboardingController
