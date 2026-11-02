-- Mise en place SERVEUR des scénarios étendus (sessions « scenarios » et « collision »).
-- Injecté par le pilote uniquement dans le Studio de test. Ce script place les
-- véhicules entre les étapes (ce n'est jamais le jeu qui le fait), mesure ce que
-- seul le serveur voit (cônes renversés, retour au plot, corrections) et transmet
-- ses contrôles à ServerSuite via le dossier ServerStorage.AWTestScenario (attributs).

local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StudioTestService = game:GetService("StudioTestService")
local Workspace = game:GetService("Workspace")

local args = StudioTestService:GetTestArgs()
local session = if type(args) == "table" and type(args.Session) == "string" then args.Session else ""
if session ~= "scenarios" and session ~= "collision" then
    return
end

-- Canal vers ServerSuite : contrôles en JSON dans un attribut, puis « Done ».
local channel = Instance.new("Folder")
channel.Name = "AWTestScenario"
channel:SetAttribute("Done", false)
channel.Parent = ServerStorage
local scenarioSteps = {}
local function record(name: string, ok: boolean, detail: any)
    table.insert(scenarioSteps, { name = name, ok = ok, detail = if detail ~= nil then tostring(detail) else nil })
end
ReplicatedStorage:SetAttribute("AWTestMovesVehicles", true)

-- Corrections serveur pendant les scénarios : aucune n'est attendue ici
-- (pas de téléportation volontaire), donc toute correction est un faux positif.
local corrections = {}
LogService.MessageOut:Connect(function(message, messageType)
    if messageType == Enum.MessageType.MessageWarning and string.find(message, "Mouvement impossible", 1, true) then
        table.insert(corrections, message)
    end
end)

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

local folder = Workspace:WaitForChild("VehiculesEssai", 20)
local zone = Workspace:WaitForChild("AutomotiveTestZone", 20)
local signal = ReplicatedStorage:WaitForChild("AWTestSignal", 20)
local REST_HEIGHT = 2.2 -- hauteur du centre de gravité posé (+ marge de chute)

local stagesDone = {}
signal.OnServerEvent:Connect(function(_, name)
    if type(name) ~= "string" then
        return
    end
    stagesDone[name] = true
    if name == "CollisionReady" then
        ReplicatedStorage:SetAttribute("AWCollisionReady", true)
    elseif name == "collision" then
        ReplicatedStorage:SetAttribute("AWCollisionDone", true)
    end
end)

local function vehicle(index: number): Model
    return folder:WaitForChild("VehiculeEssai_" .. index, 10) :: Model
end

local function place(model: Model, pivot: CFrame)
    model:PivotTo(pivot)
    local root = model.PrimaryPart :: BasePart
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end

local function waitParked(model: Model, timeout: number): boolean
    return waitFor(function()
        return model:GetAttribute("DriverUserId") == 0
    end, timeout)
end

local function startStage(name: string)
    ReplicatedStorage:SetAttribute("AWScenarioStage", name)
end

-- Après le contrôle « véhicules posés » de ServerSuite (4 s).
task.wait(6)

if session == "scenarios" then
    local car = vehicle(1)
    local abandoned = vehicle(3)

    -- Retour automatique au plot : véhicule libre déposé loin de tout joueur.
    -- Le délai réel du jeu (90 s) est mesuré en parallèle des autres scénarios.
    local home = abandoned:GetPivot()
    place(abandoned, CFrame.new(-500, REST_HEIGHT, -900))
    local movedAt = os.clock()
    local returnedAfter: number? = nil
    task.spawn(function()
        while returnedAfter == nil and os.clock() - movedAt < 160 do
            local root = abandoned.PrimaryPart
            if root and (root.Position - home.Position).Magnitude < 5 then
                returnedAfter = os.clock() - movedAt
            end
            task.wait(0.5)
        end
    end)

    -- Bosse à 10 % : départ au sud de la rampe, cap au nord.
    place(car, CFrame.new(300, REST_HEIGHT, -240))
    task.wait(1.5)
    startStage("bosse")
    record(
        "scenario.bosse_terminee_par_le_client",
        waitFor(function()
            return stagesDone.bosse == true
        end, 120)
    )

    -- Slalom : huit cônes légers espacés de 60 st.
    waitParked(car, 10)
    local cones = {}
    local slalom = zone:FindFirstChild("Slalom")
    for _, cone in (if slalom then slalom:GetChildren() else {}) do
        if cone:IsA("BasePart") then
            cones[cone] = cone.Position
        end
    end
    place(car, CFrame.new(131, REST_HEIGHT, -10))
    task.wait(1.5)
    startStage("slalom")
    record(
        "scenario.slalom_termine_par_le_client",
        waitFor(function()
            return stagesDone.slalom == true
        end, 150)
    )
    local knocked, total = 0, 0
    for cone, start in cones do
        total += 1
        if (cone.Position - start).Magnitude > 1 then
            knocked += 1
        end
    end
    record(
        "scenario.slalom_cones_touches",
        total == 8 and knocked <= 1,
        string.format("%d cône(s) déplacé(s) sur %d", knocked, total)
    )

    -- Véhicule renversé (sur le toit), immobile.
    waitParked(car, 10)
    place(car, CFrame.new(60, 6, -150) * CFrame.Angles(0, 0, math.pi))
    task.wait(3)
    local up = (car.PrimaryPart :: BasePart).CFrame.UpVector.Y
    record("scenario.vehicule_renverse_prepare", up < -0.5, string.format("UpVector.Y = %.2f", up))
    startStage("renverse")
    record(
        "scenario.renverse_termine_par_le_client",
        waitFor(function()
            return stagesDone.renverse == true
        end, 90)
    )

    -- Collision contre un véhicule garé (propriété réseau du serveur) : même mise
    -- en place que la session « collision », pour comparer le transfert d'impulsion.
    waitParked(car, 10)
    local parked = vehicle(2)
    place(car, CFrame.new(0, REST_HEIGHT, -150))
    place(parked, CFrame.new(0, REST_HEIGHT, -230) * CFrame.Angles(0, -math.pi / 2, 0))
    task.wait(2)
    local parkedStart = parked:GetPivot().Position
    local parkedMax = 0
    task.spawn(function()
        while not stagesDone.collision_parque do
            parkedMax = math.max(parkedMax, (parked:GetPivot().Position - parkedStart).Magnitude)
            task.wait(0.05)
        end
    end)
    startStage("collision_parque")
    record(
        "scenario.collision_parque_terminee_par_le_client",
        waitFor(function()
            return stagesDone.collision_parque == true
        end, 90)
    )
    record(
        "scenario.collision_vehicule_gare_deplace",
        parkedMax > 0.3,
        string.format("déplacement max du véhicule garé %.2f st (mesure serveur)", parkedMax)
    )

    -- Fin du retour au plot (au plus tard 120 s après le dépôt).
    waitFor(function()
        return returnedAfter ~= nil
    end, math.max(0, movedAt + 120 - os.clock()))
    local after = returnedAfter
    record(
        "scenario.retour_automatique_au_plot",
        after ~= nil and after >= 85 and after <= 100,
        if after then string.format("revenu après %.0f s (délai du jeu : 90 s)", after) else "non revenu après 120 s"
    )
elseif session == "collision" then
    -- Véhicule 1 au sud, cap au nord ; véhicule 4 en travers 80 st plus loin.
    place(vehicle(1), CFrame.new(0, REST_HEIGHT, -150))
    place(vehicle(4), CFrame.new(0, REST_HEIGHT, -230) * CFrame.Angles(0, -math.pi / 2, 0))
    task.wait(1.5)
    startStage("collision")
    record(
        "scenario.collision_terminee_par_le_client",
        waitFor(function()
            return stagesDone.collision == true
        end, 150)
    )
end

record(
    "scenario.aucune_correction_intempestive",
    #corrections == 0,
    #corrections .. " correction(s) : " .. table.concat(corrections, " || ")
)
channel:SetAttribute("Steps", HttpService:JSONEncode(scenarioSteps))
channel:SetAttribute("Done", true)
