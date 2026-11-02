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
local isCollisionSession = session == "collision" or session == "collision_latence"
if session ~= "scenarios" and not isCollisionSession then
    return
end

-- Canal vers ServerSuite : contrôles en JSON dans un attribut, puis « Done ».
local channel = Instance.new("Folder")
channel.Name = "AWTestScenario"
channel:SetAttribute("Done", false)
channel.Parent = ServerStorage
local scenarioSteps = {}
local function record(name: string, ok: boolean, detail: any, knownLimitation: string?)
    table.insert(scenarioSteps, {
        name = name,
        ok = ok,
        detail = if detail ~= nil then tostring(detail) else nil,
        -- Limite connue et documentée : affichée ⚠️, jamais comptée comme réussie.
        known = if not ok then knownLimitation else nil,
    })
end
ReplicatedStorage:SetAttribute("AWTestMovesVehicles", true)

-- Corrections serveur pendant les scénarios : aucune n'est attendue ici
-- (pas de téléportation volontaire), donc toute correction est un faux positif.
local corrections, unconfirmedImpulses, ownershipWarnings = {}, {}, {}
local exchangesByTrial: { [number]: number } = {}
local currentTrial = 0
LogService.MessageOut:Connect(function(message, messageType)
    if messageType == Enum.MessageType.MessageWarning then
        if string.find(message, "Mouvement impossible", 1, true) then
            table.insert(corrections, message)
        elseif string.find(message, "Impulsion de collision non constatée", 1, true) then
            table.insert(unconfirmedImpulses, message)
        elseif string.find(message, "Propriété réseau", 1, true) then
            table.insert(ownershipWarnings, message)
        end
    elseif string.find(message, "[Collision] Contact confirmé", 1, true) then
        exchangesByTrial[currentTrial] = (exchangesByTrial[currentTrial] or 0) + 1
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

    -- Propriété réseau refusée par le moteur : véhicule ancré (SetNetworkOwner échoue).
    waitParked(car, 10)
    local locked = vehicle(4)
    local lockedRoot = locked.PrimaryPart :: BasePart
    place(locked, CFrame.new(-40, REST_HEIGHT, -60))
    task.wait(2)
    lockedRoot.Anchored = true
    startStage("propriete_refusee")
    record(
        "scenario.propriete_refusee_terminee_par_le_client",
        waitFor(function()
            return stagesDone.propriete_refusee == true
        end, 40)
    )
    local lockedPrompt = (lockedRoot:FindFirstChild("DriverDoor") :: Attachment):FindFirstChild(
            "EnterPrompt"
        ) :: ProximityPrompt
    record(
        "scenario.propriete_refusee_etat_serveur_coherent",
        locked:GetAttribute("DriverUserId") == 0
            and locked:GetAttribute("SimulationOwnerUserId") == 0
            and lockedPrompt.Enabled
            and #ownershipWarnings > 0,
        string.format(
            "DriverUserId=%s SimulationOwnerUserId=%s invite=%s occupant=%s ; journal : %s",
            tostring(locked:GetAttribute("DriverUserId")),
            tostring(locked:GetAttribute("SimulationOwnerUserId")),
            tostring(lockedPrompt.Enabled),
            tostring((locked:FindFirstChild("DriverSeat") :: Seat).Occupant),
            table.concat(ownershipWarnings, " || ")
        )
    )
    lockedRoot.Anchored = false
    -- Personnage remis à neuf (réapparition) : le rétablissement est testé
    -- indépendamment de l'état « assis » laissé côté client par le cas ancré.
    for _, testPlayer in game:GetService("Players"):GetPlayers() do
        testPlayer:LoadCharacter()
    end
    task.wait(2)
    startStage("propriete_retablie")
    local ownerDetail = "aucun conducteur"
    local ownerOk = waitFor(function()
        local driverId = locked:GetAttribute("DriverUserId")
        if type(driverId) ~= "number" or driverId == 0 then
            return false
        end
        local owner = lockedRoot:GetNetworkOwner()
        ownerDetail = string.format(
            "propriétaire=%s attribut=%s",
            if owner then tostring(owner.UserId) else "serveur",
            tostring(locked:GetAttribute("SimulationOwnerUserId"))
        )
        return owner ~= nil and owner.UserId == driverId and locked:GetAttribute("SimulationOwnerUserId") == driverId
    end, 30)
    record("scenario.propriete_retablie_confirmee", ownerOk, ownerDetail)
    waitFor(function()
        return stagesDone.propriete_retablie == true
    end, 40)

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
elseif isCollisionSession then
    -- M4 : expérience de collision. Essais alternés, même mise en place :
    -- « pilote » : le véhicule percuté est conduit par le joueur 2 (frein à main) ;
    -- « gare »   : le véhicule percuté est stationné (simulé par le serveur).
    -- Le joueur 1 percute toujours le flanc à ~20 km/h. Le serveur mesure le
    -- déplacement du véhicule percuté et note les propriétaires réseau au contact.
    local TRIALS = { "pilote", "gare", "pilote", "gare", "pilote", "gare" }
    ReplicatedStorage:SetAttribute("AWTrialCount", #TRIALS)
    local striker, drivenTarget, parkedTarget = vehicle(1), vehicle(4), vehicle(2)
    local finals = { pilote = {}, gare = {} }
    local noContactTrials = 0
    local exchanges = { pilote = {}, gare = {} }
    local function ownerName(part: BasePart): string
        local ok, owner = pcall(function()
            return part:GetNetworkOwner()
        end)
        if not ok then
            return "erreur"
        end
        return if owner then "joueur" .. tostring((owner :: Player):GetAttribute("AWTestIndex")) else "serveur"
    end
    for i, kind in TRIALS do
        waitParked(striker, 20)
        waitParked(drivenTarget, 20)
        task.wait(1)
        local target = if kind == "pilote" then drivenTarget else parkedTarget
        local spare = if kind == "pilote" then parkedTarget else drivenTarget
        place(spare, CFrame.new(-90, REST_HEIGHT, -230) * CFrame.Angles(0, -math.pi / 2, 0))
        place(striker, CFrame.new(0, REST_HEIGHT, -150))
        place(target, CFrame.new(0, REST_HEIGHT, -230) * CFrame.Angles(0, -math.pi / 2, 0))
        task.wait(2)
        ReplicatedStorage:SetAttribute("AWTrialKind", kind)
        currentTrial = i
        startStage("essai_" .. i)
        if kind == "pilote" then
            waitFor(function()
                return stagesDone["pret_" .. i] == true
            end, 40)
        end
        local targetRoot = target.PrimaryPart :: BasePart
        local strikerRoot = striker.PrimaryPart :: BasePart
        local start = target:GetPivot().Position
        local maxDisplacement, peakSpeed = 0, 0
        local owners = "pas de rapprochement"
        local startOwner = ownerName(strikerRoot)
        ReplicatedStorage:SetAttribute("AWTrialGo", i)
        waitFor(function()
            maxDisplacement = math.max(maxDisplacement, (target:GetPivot().Position - start).Magnitude)
            peakSpeed = math.max(peakSpeed, targetRoot.AssemblyLinearVelocity.Magnitude)
            if owners == "pas de rapprochement" and math.abs(strikerRoot.Position.Z - targetRoot.Position.Z) < 14 then
                owners = ownerName(strikerRoot) .. " percute " .. ownerName(targetRoot)
            end
            return stagesDone["essai_" .. i] == true
        end, 60)
        task.wait(1)
        local final = (target:GetPivot().Position - start).Magnitude
        local contact = owners ~= "pas de rapprochement"
        if contact then
            table.insert(finals[kind], final)
        else
            noContactTrials += 1
        end
        ReplicatedStorage:SetAttribute("AWTrialDone", i)
        if kind == "pilote" then
            waitFor(function()
                return stagesDone["p2_" .. i] == true
            end, 30)
        end
        record(
            string.format("scenario.essai_%d_%s", i, kind),
            true,
            string.format(
                "percuteur simulé par %s au départ ; %s ; véhicule percuté (vue serveur) : déplacement max %.2f st, final %.2f st, vitesse max %.1f st/s ; échanges d'impulsion confirmés : %d",
                startOwner,
                owners,
                maxDisplacement,
                final,
                peakSpeed,
                exchangesByTrial[i] or 0
            )
        )
        if not contact then
            -- Essai sans contact : exclu des critères de poussée (compté à part).
            continue
        elseif kind == "pilote" then
            table.insert(exchanges.pilote, exchangesByTrial[i] or 0)
        else
            table.insert(exchanges.gare, exchangesByTrial[i] or 0)
        end
    end
    -- Critère : un véhicule conduit percuté doit recevoir une poussée du même
    -- ordre qu'un véhicule garé : entre la moitié et 2,5 fois la médiane « garé ».
    local function median(values: { number }): number
        local sorted = table.clone(values)
        table.sort(sorted)
        if #sorted == 0 then
            return 0
        end
        return sorted[math.ceil(#sorted / 2)]
    end
    local parkedMedian = median(finals.gare)
    local consistent = #finals.pilote > 0 and parkedMedian > 0.5
    for _, value in finals.pilote do
        consistent = consistent and value >= 0.5 * parkedMedian and value <= 2.5 * parkedMedian
    end
    local function list(values: { number }): string
        local parts = {}
        for _, value in values do
            table.insert(parts, string.format("%.2f", value))
        end
        return table.concat(parts, " / ")
    end
    record(
        "scenario.collision_poussee_pilote_comparable_au_gare",
        consistent,
        string.format(
            "déplacements finals (vue serveur) — conduit : %s st ; garé : %s st (médiane %.2f)",
            list(finals.pilote),
            list(finals.gare),
            parkedMedian
        )
    )
    local pilotExchanges, parkedExchanges = 0, 0
    local everyPilotTrial = #exchanges.pilote > 0
    for _, count in exchanges.pilote do
        pilotExchanges += count
        everyPilotTrial = everyPilotTrial and count >= 1
    end
    for _, count in exchanges.gare do
        parkedExchanges += count
    end
    record(
        "scenario.collision_echange_confirme_serveur",
        everyPilotTrial and parkedExchanges == 0,
        string.format(
            "%d échange(s) sur les essais « conduit », %d sur les essais « garé » (aucun attendu : le moteur résout ce contact sur le serveur)",
            pilotExchanges,
            parkedExchanges
        )
    )
    record(
        "scenario.collision_tous_les_essais_avec_contact",
        noContactTrials == 0,
        string.format("%d essai(s) sans contact sur %d", noContactTrials, #TRIALS),
        "véhicule du joueur 1 immobile chez lui après un réembarquement suivant un repositionnement par le "
            .. "serveur de test, puis corrigé (Teleport) ; cause non établie ; voir RAPPORT_VALIDATION.md §5"
    )
    record(
        "scenario.collision_impulsions_constatees",
        #unconfirmedImpulses == 0,
        #unconfirmedImpulses .. " impulsion(s) non constatée(s) : " .. table.concat(unconfirmedImpulses, " || ")
    )
end

if isCollisionSession then
    record(
        "scenario.propriete_reseau_sans_anomalie",
        #ownershipWarnings == 0,
        #ownershipWarnings .. " avertissement(s) : " .. table.concat(ownershipWarnings, " || ")
    )
end
record(
    "scenario.aucune_correction_intempestive",
    #corrections == 0,
    #corrections .. " correction(s) : " .. table.concat(corrections, " || ")
)
channel:SetAttribute("Steps", HttpService:JSONEncode(scenarioSteps))
channel:SetAttribute("Done", true)
