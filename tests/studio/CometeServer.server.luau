-- Essais SERVEUR du lot VEH3D-01 (place de développement), injectés par le pilote dans le Studio de test
-- uniquement. Session « comete » (1 joueur, vraies entrées dans la VM) : essais QA-K01 à QA-K08 de
-- docs/QA_BACKLOG.md §3 septies (carrosserie 3D de la Comète, kit de maillages).
--   K01 apparition (carrosserie soudée, sans masse, posée sur ses roues ; P-01 inchangé)
--   K02 maillages chargés par le client de la VM (mesuré par le client : ContentProvider)
--   K03 roues (pièces du modèle soudées aux roues du jeu ; rotation et braquage mesurés par le client)
--   K04 embarquement et pose (invites présentes ; AWSeatPose ; tête, mains, pieds mesurés par le client)
--   K05 caméras (vraie touche V ; repères du kit)
--   K06 collisions et dégâts (choc avant conduit au clavier ; chocs arrière et latéral lancés par le serveur)
--   K07 vitrage et feux (nuit imposée par le serveur ; sources de lumière relevées par le client)
--   K08 performances (24 Comète contre 24 P-01 immobiles, jour et nuit, temps d'image du client)
-- Instrumenté (signalé) : véhicules temporaires protégés (MissionService.spawnBeside, aucune écriture
-- durable) ; placement des véhicules par `PivotTo` ; personnage assis par `Seat:Sit` (comme l'invite) ;
-- heure imposée (Lighting.ClockTime) ; chocs arrière et latéral par une vitesse donnée au véhicule vide ;
-- parc de mesure D5 construit par la fabrique et ancré. Profils en MÉMOIRE : aucun DataStore.
-- Journal machine « @@AWCOMETE@@ {json} ».

local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StudioTestService = game:GetService("StudioTestService")
local Workspace = game:GetService("Workspace")

local args = StudioTestService:GetTestArgs()
local session = if type(args) == "table" and type(args.Session) == "string" then args.Session else ""
-- « comete_vitres » : même début, puis comparatif de réglages du vitrage (captures), sans conduite.
if session ~= "comete" and session ~= "comete_vitres" and session ~= "comete_perf" and session ~= "comete2" then
    return
end

local steps = {}
local function record(name: string, ok: boolean, detail: any)
    table.insert(steps, { name = name, ok = ok, detail = if detail ~= nil then tostring(detail) else nil })
end
local sessionStart = os.clock()
local function trace(message: string)
    print(string.format("[AW_Test] comete %.1f s : %s", os.clock() - sessionStart, message))
end
local function emitData(kind: string, data: { [string]: any })
    data.kind = kind
    print("@@AWCOMETE@@ " .. HttpService:JSONEncode(data))
end

local errors, robloxErrors, warnings, impacts = {}, {}, {}, {}
LogService.MessageOut:Connect(function(message, messageType)
    if messageType == Enum.MessageType.MessageError then
        local ours = string.find(message, "AutomotiveWorld", 1, true)
            or string.find(message, "ReplicatedStorage.Shared", 1, true)
            or string.find(message, "AW_Test", 1, true)
        table.insert(if ours then errors else robloxErrors, message)
    elseif messageType == Enum.MessageType.MessageWarning and string.find(message, "AutomotiveWorld", 1, true) then
        table.insert(warnings, message)
    elseif string.find(message, "[Dégâts] Choc confirmé", 1, true) then
        table.insert(impacts, message)
    end
end)

local reportEvent = Instance.new("RemoteEvent")
reportEvent.Name = "AWTestReport"
reportEvent.Parent = ReplicatedStorage
local signalEvent = Instance.new("RemoteEvent")
signalEvent.Name = "AWTestSignal"
signalEvent.Parent = ReplicatedStorage
-- Serveur → client : demande d'essai ou de capture (identifiant, données).
local askEvent = Instance.new("RemoteEvent")
askEvent.Name = "AWCometeAsk"
askEvent.Parent = ReplicatedStorage
ReplicatedStorage:SetAttribute("AWTestSession", session)
ReplicatedStorage:SetAttribute("AWTestPlayers", if session == "comete2" then 2 else 1)

local Server = ServerScriptService:WaitForChild("AutomotiveWorldServer")
local Vehicles = Server:WaitForChild("Vehicles")
local MissionService = require(Server:WaitForChild("Economy"):WaitForChild("MissionService"))
local VehicleService = require(Vehicles:WaitForChild("VehicleService"))
local VehicleFactory = require(Vehicles:WaitForChild("VehicleFactory")) :: any
local MeshKits = require(Vehicles:WaitForChild("MeshKits")) :: any
local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehiclesShared = Shared:WaitForChild("Vehicles")
local Definitions = require(VehiclesShared:WaitForChild("VehicleDefinitions")) :: any
local Constants = require(VehiclesShared:WaitForChild("VehicleConstants")) :: any
local SeatPose = require(VehiclesShared:WaitForChild("SeatPose")) :: any

local reports = {}
local acks: { [string]: any } = {}
reportEvent.OnServerEvent:Connect(function(player, payload)
    reports[tostring(player.UserId)] = payload
end)
signalEvent.OnServerEvent:Connect(function(_player, message, data)
    if type(message) == "string" and string.sub(message, 1, 5) == "AWCO:" then
        acks[string.sub(message, 6)] = if data ~= nil then data else true
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

-- Demande au client et attend son accusé (« AWCO:<id> », avec ses éventuelles mesures).
local function ask(player: Player, id: string, data: { [string]: any }, timeout: number): any
    acks[id] = nil
    askEvent:FireClient(player, id, data)
    waitFor(function()
        return acks[id] ~= nil
    end, timeout)
    return acks[id]
end

local KIT = MeshKits.Kits.wk_comete
local COMETE = Definitions.get("wk_comete")
local M = Constants.MetersPerStud
local REST_Y = COMETE.Chassis.CgHeightM / M + 0.4 -- pivot posé au sol de la zone d'essai (y = 0)

local function f3(v: Vector3): string
    return string.format("%.2f/%.2f/%.2f", v.X, v.Y, v.Z)
end

-- Cadrage d'une capture dans le repère du véhicule (studs) : 12 composantes de CFrame.
local function view(model: Model, from: Vector3, to: Vector3): { number }
    local frame = (model.PrimaryPart :: BasePart).CFrame
    return { CFrame.lookAt(frame * from, frame * to):GetComponents() }
end
local function shot(player: Player, model: Model, name: string, from: Vector3, to: Vector3)
    ask(player, "shot:" .. name, { Name = name, Cadrage = view(model, from, to) }, 15)
end

-- Pivot posé au sol en (x, z), avant du véhicule tourné vers `faceDeg` (0 : −Z, 180 : +Z).
local function ground(x: number, z: number, faceDeg: number): CFrame
    return CFrame.new(x, REST_Y, z) * CFrame.Angles(0, math.rad(-faceDeg), 0)
end
local function place(model: Model, pivot: CFrame)
    model:PivotTo(pivot)
    local root = model.PrimaryPart :: BasePart
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end

local function humanoidOf(player: Player): Humanoid?
    local character = player.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function sit(player: Player, model: Model, seatName: string): boolean
    local seat = model:FindFirstChild(seatName)
    local humanoid = humanoidOf(player)
    if seat == nil or not seat:IsA("Seat") or humanoid == nil then
        return false
    end
    seat:Sit(humanoid)
    local seated = waitFor(function()
        return seat.Occupant == humanoid
    end, 4)
    task.wait(1.5) -- animation d'assise, propriété réseau
    return seated
end

local function zones(model: Model): string
    return string.format(
        "AV %.2f AR %.2f G %.2f D %.2f moteur %.2f chocs %d",
        model:GetAttribute("DmgZoneFront") or -1,
        model:GetAttribute("DmgZoneRear") or -1,
        model:GetAttribute("DmgZoneLeft") or -1,
        model:GetAttribute("DmgZoneRight") or -1,
        model:GetAttribute("DmgEngine") or -1,
        model:GetAttribute("DmgImpacts") or -1
    )
end

-- Éléments opaques du dossier Degats qui recouvriraient le modèle 3D (copie d'une boîte de collision).
local function opaqueBoxes(model: Model): (number, number, { string })
    local folder = model:FindFirstChild("Degats")
    local total, bad, names = 0, 0, {}
    for _, item in if folder then folder:GetChildren() else {} do
        if item:IsA("BasePart") then
            total += 1
            if string.find(item.Name, "Deforme", 1, true) and item.Transparency < 1 then
                bad += 1
                table.insert(names, item.Name .. " " .. f3(item.Size))
            end
        end
    end
    return total, bad, names
end

-- ======================== Démarrage ========================

local joined = waitFor(function()
    return #Players:GetPlayers() >= 1
end, 60)
record("comete.serveur.joueur_connecte", joined, #Players:GetPlayers())
local player = Players:GetPlayers()[1]
local character = player and (player.Character or player.CharacterAdded:Wait())
character:WaitForChild("Humanoid", 10)
task.wait(2)

local calibrated = ask(player, "calibrate", {}, 60)
record("comete.serveur.client_pret", calibrated ~= nil)

-- ======================== Réplication à 2 joueurs (session « comete2 ») ========================
-- Joueur 1 (plus petit identifiant) au volant ; joueur 2 observe ce que son client reçoit : maillages, roues du
-- modèle qui tournent, braquage (VisualSteer), feux stop (VisualBrake), conducteur visible. Commandes du joueur 1
-- par le point d'accès de test du contrôleur (INSTRUMENTÉ, signalé) : les vraies touches de la VM ne visent pas une
-- fenêtre de Studio précise quand deux clients sont ouverts.
if session == "comete2" then
    local both = waitFor(function()
        return #Players:GetPlayers() >= 2
    end, 90)
    record("comete2.serveur.deux_joueurs", both, #Players:GetPlayers())
    local all = Players:GetPlayers()
    table.sort(all, function(a, b)
        return a.UserId < b.UserId
    end)
    local driver, observer = all[1], all[2]
    if not both or observer == nil then
        StudioTestService:EndTest({ session = session, players = 2, server = steps, clients = reports })
        return
    end
    for _, who in { driver, observer } do
        local c = who.Character or who.CharacterAdded:Wait()
        c:WaitForChild("Humanoid", 10)
    end
    task.wait(3);
    (driver.Character :: Model):PivotTo(CFrame.new(-262, 4, 110));
    (observer.Character :: Model):PivotTo(CFrame.new(-275, 4, 135))
    task.wait(0.8)
    local car = MissionService.spawnBeside(driver, "wk_comete", "COMETE-K2")
    record("comete2.serveur.apparition", car ~= nil)
    if car == nil then
        StudioTestService:EndTest({ session = session, players = 2, server = steps, clients = reports })
        return
    end
    task.wait(1.5)
    place(car, ground(-250, 120, 180))
    task.wait(2.5)
    record("comete2.serveur.conducteur_assis", sit(driver, car, "DriverSeat"))
    -- Observation lancée d'abord, puis la démonstration du conducteur (même durée).
    acks["observe"] = nil
    askEvent:FireClient(observer, "observe", { Model = car, Driver = driver, Seconds = 9 })
    task.wait(0.5)
    local demo = ask(driver, "demo", {}, 30)
    record(
        "comete2.conducteur.demonstration",
        type(demo) == "table",
        if type(demo) == "table" then demo.Detail else "sans réponse"
    )
    waitFor(function()
        return acks["observe"] ~= nil
    end, 30)
    local seen = acks["observe"]
    record(
        "comete2.observateur.rapport",
        type(seen) == "table",
        if type(seen) == "table" then seen.Detail else "sans réponse"
    )
    for _, who in { driver, observer } do
        ask(who, "finish", {}, 10)
    end
    waitFor(function()
        local n = 0
        for _ in reports do
            n += 1
        end
        return n >= 2
    end, 60)
    record("comete2.serveur.aucune_erreur_execution", #errors == 0, table.concat(errors, " || "))
    StudioTestService:EndTest({ session = session, players = 2, server = steps, clients = reports })
    return
end

-- ======================== K08 : performances (session « comete_perf ») ========================
-- Parcs immobiles de 1, 8, 16 et 24 véhicules (fabrique, ancrés), P-01 (référence) puis Comète, jour et nuit, même
-- cadrage. Mesure du CLIENT par `Stats` : temps de rendu processeur et carte graphique, appels de dessin, triangles.
-- Ces temps ne dépendent pas du plafond de 60 images/s du Studio de la VM (le temps d'image, lui, y reste collé).
-- Critère D5 : Comète ≤ P-01 + 2 ms à nombre égal. Rendu de la VM (carte graphique virtuelle) : un poste réel reste à mesurer.
if session == "comete_perf" then
    local COUNTS = { 1, 8, 16, 24 }
    local function fleet(definition: any, label: string, count: number): Folder
        local folder = Instance.new("Folder")
        folder.Name = "AWTestParc_" .. label .. "_" .. count
        folder.Parent = Workspace
        for i = 1, count do
            local x = -560 + ((i - 1) % 6) * 22
            local z = -980 + math.floor((i - 1) / 6) * 26
            local pivot = CFrame.new(x, definition.Chassis.CgHeightM / M + 0.3, z)
            local vehicle = VehicleFactory.create(definition, pivot, 200 + i)
            vehicle.Name = label .. "_" .. i
            vehicle.Parent = folder;
            (vehicle.PrimaryPart :: BasePart).Anchored = true
        end
        return folder
    end
    character:PivotTo(CFrame.new(-505, 4, -1060))
    task.wait(1)
    local clock = Lighting.ClockTime
    local cadrage = { CFrame.lookAt(Vector3.new(-505, 30, -1030), Vector3.new(-505, 0, -915)):GetComponents() }
    local results: { [string]: any } = {}
    -- Scène vide (référence de la mesure elle-même).
    for _, phase in { "jour", "nuit" } do
        Lighting.ClockTime = if phase == "jour" then 14 else 0
        task.wait(2)
        results["vide_0_" .. phase] = ask(player, "frames:vide_0_" .. phase, { Seconds = 6, Cadrage = cadrage }, 30)
    end
    for _, count in COUNTS do
        for _, entry in { { "p01", Definitions.get("proto_p01") }, { "comete", COMETE } } do
            local label, definition = entry[1], entry[2]
            local folder = fleet(definition, label, count)
            task.wait(3)
            for _, phase in { "jour", "nuit" } do
                Lighting.ClockTime = if phase == "jour" then 14 else 0
                task.wait(2)
                local key = string.format("%s_%d_%s", label, count, phase)
                results[key] = ask(player, "frames:" .. key, { Seconds = 6, Cadrage = cadrage }, 30)
            end
            folder:Destroy()
            task.wait(1.5)
        end
    end
    Lighting.ClockTime = clock
    local function v(key: string, field: string): number?
        local data = results[key]
        return if type(data) == "table" then data[field] else nil
    end
    local function f(x: number?): string
        return if x then string.format("%.2f", x) else "—"
    end
    for _, count in COUNTS do
        for _, phase in { "jour", "nuit" } do
            local refCpu, cpu =
                v(("p01_%d_%s"):format(count, phase), "Cpu"), v(("comete_%d_%s"):format(count, phase), "Cpu")
            local refGpu, gpu =
                v(("p01_%d_%s"):format(count, phase), "Gpu"), v(("comete_%d_%s"):format(count, phase), "Gpu")
            -- Temps de rendu à 0 : mesure indisponible dans ce Studio (constaté le 2026-11-05, tâche 20261105-013629).
            -- Jamais compté comme une réussite : contrôle informatif, verdict D5 laissé « non concluant ».
            local measurable = (refCpu or 0) > 0 or (cpu or 0) > 0 or (refGpu or 0) > 0 or (gpu or 0) > 0
            local ok = measurable
                and refCpu ~= nil
                and cpu ~= nil
                and refGpu ~= nil
                and gpu ~= nil
                and (cpu :: number) <= (refCpu :: number) + 2
                and (gpu :: number) <= (refGpu :: number) + 2
            record(
                string.format(
                    "comete.k08.%s_%02d_vehicules_%s",
                    if measurable then "rendu" else "info_rendu_non_mesurable",
                    count,
                    phase
                ),
                ok or not measurable,
                string.format(
                    "processeur P-01 %s / Comète %s ms ; carte graphique %s / %s ms ; appels de dessin %s / %s ; triangles %s / %s ; images %s / %s ms",
                    f(refCpu),
                    f(cpu),
                    f(refGpu),
                    f(gpu),
                    f(v(("p01_%d_%s"):format(count, phase), "Draws")),
                    f(v(("comete_%d_%s"):format(count, phase), "Draws")),
                    f(v(("p01_%d_%s"):format(count, phase), "Tris")),
                    f(v(("comete_%d_%s"):format(count, phase), "Tris")),
                    f(v(("p01_%d_%s"):format(count, phase), "Mean")),
                    f(v(("comete_%d_%s"):format(count, phase), "Mean"))
                )
            )
        end
    end
    -- Budget de triangles par véhicule (hypothèse LOD0 de 25 000, ASTER_02_HAUTE_FIDELITE.md, PR #15) : mesuré à 24.
    local tris24 = v("comete_24_jour", "Tris")
    local trisRef = v("p01_24_jour", "Tris")
    record(
        "comete.k08.triangles_par_comete_24",
        tris24 ~= nil and trisRef ~= nil and ((tris24 :: number) - (v("vide_0_jour", "Tris") or 0)) / 24 <= 25000,
        string.format(
            "%s triangles pour 24 Comète, %s pour 24 P-01, %s scène vide",
            f(tris24),
            f(trisRef),
            f(v("vide_0_jour", "Tris"))
        )
    )
    record(
        "comete.k08.info_scene_vide",
        true,
        string.format(
            "processeur %s ms, carte graphique %s ms (jour)",
            f(v("vide_0_jour", "Cpu")),
            f(v("vide_0_jour", "Gpu"))
        )
    )
    emitData("perf", results)
    ask(player, "finish", {}, 10)
    waitFor(function()
        return next(reports) ~= nil
    end, 60)
    record("comete.serveur.rapport_client", next(reports) ~= nil)
    record("comete.serveur.aucune_erreur_execution", #errors == 0, table.concat(errors, " || "))
    StudioTestService:EndTest({ session = session, players = 1, server = steps, clients = reports })
    return
end

-- ======================== K01 : gabarit et apparition ========================

local kit, template, reason = MeshKits.template("wk_comete")
record("comete.k01.gabarit_utilisable", kit ~= nil and template ~= nil, tostring(reason or "ok"))

character:PivotTo(CFrame.new(-262, 4, 110))
task.wait(0.6)
local model = MissionService.spawnBeside(player, "wk_comete", "COMETE-K01")
record("comete.k01.apparition", model ~= nil, if model then model:GetFullName() else "nil")
if model == nil then
    StudioTestService:EndTest({ session = session, players = 1, server = steps, clients = reports })
    return
end
task.wait(1.5)
place(model, ground(-250, 120, 180))
task.wait(2.5) -- posé, immobile
local root = model.PrimaryPart :: BasePart
local body = model:FindFirstChild("Carrosserie")

-- Pièces du modèle : sans masse, sans collision ni requête, soudées au châssis (ou à une roue).
local meshes, unsafe, unwelded, glass, glassBad = 0, {}, {}, 0, {}
for _, item in model:GetDescendants() do
    if item:IsA("MeshPart") then
        meshes += 1
        if item.Anchored or not item.Massless or item.CanCollide or item.CanQuery or item.CanTouch then
            table.insert(unsafe, item.Name)
        end
        local weld = item:FindFirstChildOfClass("WeldConstraint")
        if weld == nil or weld.Part0 == nil or weld.Part1 ~= item then
            table.insert(unwelded, item.Name)
        end
        if string.find(string.lower(item.Name), KIT.GlassPattern, 1, true) then
            glass += 1
            if item.Transparency < 0.3 or item.Material ~= Enum.Material.Glass then
                table.insert(glassBad, string.format("%s %.2f %s", item.Name, item.Transparency, item.Material.Name))
            end
        end
    end
end
record("comete.k01.maillages_poses", meshes == 28, meshes .. " / 28")
record("comete.k01.maillages_visuels_seulement", #unsafe == 0, table.concat(unsafe, ","))
record("comete.k01.maillages_soudes", #unwelded == 0, table.concat(unwelded, ","))
record(
    "comete.k07.vitrage_transparent_serveur",
    glass >= 1 and #glassBad == 0,
    glass .. " pièce(s) ; " .. table.concat(glassBad, ",")
)

-- Boîtes de collision (zones de dégâts) et sources de lumière.
local boxes = {}
for name, spec in KIT.Collisions do
    local part = body and body:FindFirstChild(name)
    local ok = part ~= nil
        and part:IsA("BasePart")
        and part.CanCollide
        and part.Transparency == 1
        and part:GetAttribute("AWCollisionOnly") == true
        and (part.Size - spec.Size).Magnitude < 0.01
    table.insert(boxes, name .. (if ok then " ok" else " ÉCHEC"))
end
table.sort(boxes)
record(
    "comete.k06.boites_de_collision",
    not string.find(table.concat(boxes), "ÉCHEC", 1, true),
    table.concat(boxes, ", ")
)
local lights = 0
for _, item in (body or model):GetDescendants() do
    if item:IsA("BasePart") and item:GetAttribute("AWLight") ~= nil and item:FindFirstChild("Lumiere") then
        lights += 1
    end
end
record("comete.k07.sources_de_lumiere", lights == 4, lights .. " / 4")

-- Posée sur ses roues : assiette, hauteur du centre de gravité, immobile.
local up = root.CFrame.UpVector.Y
local height = root.Position.Y -- dessus du sol de la zone d'essai à y = 0
record(
    "comete.k01.posee_sur_ses_roues",
    up > 0.99 and math.abs(height - COMETE.Chassis.CgHeightM / M) < 0.5 and root.AssemblyLinearVelocity.Magnitude < 0.5,
    string.format(
        "assiette %.3f ; CG à %.2f st du sol (définition %.2f) ; vitesse %.2f st/s",
        up,
        height,
        COMETE.Chassis.CgHeightM / M,
        root.AssemblyLinearVelocity.Magnitude
    )
)
record("comete.k01.info_masse_de_l_ensemble", true, string.format("%.1f", root.AssemblyMass))

-- K03 : roues du jeu invisibles, pièces du modèle soudées à elles.
local wheelRows = {}
local wheelsOk = true
for _, name in Constants.WheelNames do
    local wheel = model:FindFirstChild("Wheel" .. name)
    local parts = {}
    for _, child in if wheel then wheel:GetChildren() else {} do
        if child:IsA("MeshPart") then
            local weld = child:FindFirstChildOfClass("WeldConstraint")
            if weld and weld.Part0 == wheel then
                table.insert(parts, child.Name)
            end
        end
    end
    local ok = wheel ~= nil and (wheel :: BasePart).Transparency == 1 and #parts == #KIT.Wheels[name]
    wheelsOk = wheelsOk and ok
    table.insert(wheelRows, name .. " " .. table.concat(parts, "+"))
end
record("comete.k03.pieces_de_roues_soudees", wheelsOk, table.concat(wheelRows, " / "))

-- K04 / K05 : sièges et repères.
local seatRows, seatsOk = {}, true
for seatName, pose in { DriverSeat = KIT.SeatPoses.Driver, PassengerSeat = KIT.SeatPoses.Passenger } do
    local seat = model:FindFirstChild(seatName)
    local value = seat and seat:GetAttribute(SeatPose.Attribute)
    seatsOk = seatsOk and value == pose
    table.insert(seatRows, seatName .. " " .. tostring(value))
end
record("comete.k04.sieges_aw_seat_pose", seatsOk, table.concat(seatRows, " / "))
local prompts = {}
for _, item in model:GetDescendants() do
    if item:IsA("ProximityPrompt") then
        table.insert(prompts, item.Name .. "=" .. item.ActionText)
    end
end
record("comete.k04.invites_presentes", #prompts >= 2, table.concat(prompts, ", "))
local camRows, camsOk = {}, true
for _, name in { "CameraCockpit", "CameraHood", "CameraBumper" } do
    local attachment = root:FindFirstChild(name)
    local expected = (KIT :: any)[name] :: Vector3
    local ok = attachment ~= nil and ((attachment :: Attachment).Position - expected).Magnitude < 0.01
    camsOk = camsOk and ok
    table.insert(camRows, name .. " " .. (if attachment then f3((attachment :: Attachment).Position) else "absent"))
end
record("comete.k05.reperes_des_cameras", camsOk, table.concat(camRows, " / "))

-- K02 : chargement des maillages et textures par le client de la VM.
local loaded = ask(player, "preload", { Model = model }, 90)
record(
    "comete.k02.rapport_client",
    type(loaded) == "table",
    if type(loaded) == "table" then loaded.Detail else "sans réponse"
)

-- Captures de jour, véhicule vide.
shot(player, model, "comete_trois_quarts_avant", Vector3.new(-15, 5, -21), Vector3.new(0, 0.3, -1))
shot(player, model, "comete_trois_quarts_arriere", Vector3.new(15, 5, 21), Vector3.new(0, 0.3, 1))
shot(player, model, "comete_profil_gauche", Vector3.new(-26, 2.5, 0), Vector3.new(0, 0.3, 0))
shot(player, model, "comete_dessus", Vector3.new(0, 30, 7), Vector3.new(0, 0, 0))
shot(player, model, "comete_roue_avant_gauche", Vector3.new(-9.5, 0.6, -7.5), Vector3.new(-3.1, -0.3, -5.6))

-- ======================== Comparatif du vitrage (session « comete_vitres ») ========================
-- Vitres latérales vues noires de l'extérieur (tâche 20261105-002227) alors qu'elles sont bien des pièces de verre :
-- réglages comparés, conducteur assis, mêmes cadrages. Réglage appliqué par le test (instrumenté) ; le jeu garde le sien.
if session == "comete_vitres" then
    local glassParts: { MeshPart } = {}
    local appearances = {}
    for _, item in model:GetDescendants() do
        if item:IsA("MeshPart") and string.find(string.lower(item.Name), KIT.GlassPattern, 1, true) then
            table.insert(glassParts, item)
            local appearance = item:FindFirstChildOfClass("SurfaceAppearance")
            table.insert(
                appearances,
                item.Name
                    .. (
                        if appearance
                            then " avec SurfaceAppearance (" .. appearance.AlphaMode.Name .. ")"
                            else " sans SurfaceAppearance"
                    )
            )
        end
    end
    record("comete.vitres.pieces", #glassParts >= 1, table.concat(appearances, " ; "))
    record("comete.vitres.conducteur_assis", sit(player, model, "DriverSeat"))
    type Variant = { Name: string, Material: Enum.Material, Color: Color3, Transparency: number }
    local VARIANTS: { Variant } = {
        {
            Name = "A_actuel_verre_sombre_045",
            Material = Enum.Material.Glass,
            Color = Color3.fromRGB(28, 32, 38),
            Transparency = 0.45,
        },
        {
            Name = "B_verre_sombre_070",
            Material = Enum.Material.Glass,
            Color = Color3.fromRGB(28, 32, 38),
            Transparency = 0.7,
        },
        {
            Name = "C_verre_clair_060",
            Material = Enum.Material.Glass,
            Color = Color3.fromRGB(120, 135, 145),
            Transparency = 0.6,
        },
        {
            Name = "D_lisse_clair_060",
            Material = Enum.Material.SmoothPlastic,
            Color = Color3.fromRGB(120, 135, 145),
            Transparency = 0.6,
        },
        {
            Name = "E_lisse_fume_075",
            Material = Enum.Material.SmoothPlastic,
            Color = Color3.fromRGB(60, 70, 80),
            Transparency = 0.75,
        },
    }
    for _, variant in VARIANTS do
        for _, part in glassParts do
            part.Material = variant.Material
            part.Color = variant.Color
            part.Transparency = variant.Transparency
        end
        task.wait(0.8)
        shot(
            player,
            model,
            "vitres_" .. variant.Name .. "_profil",
            Vector3.new(-9, 2.4, -1.4),
            Vector3.new(-1.2, 0.8, -1.45)
        )
        shot(
            player,
            model,
            "vitres_" .. variant.Name .. "_trois_quarts",
            Vector3.new(-11, 3.2, -12),
            Vector3.new(-1, 0.9, -1.5)
        )
    end
    record("comete.vitres.variantes_capturees", true, #VARIANTS .. " réglages, 2 cadrages chacun")
    ask(player, "finish", {}, 10)
    waitFor(function()
        return next(reports) ~= nil
    end, 60)
    record("comete.serveur.rapport_client", next(reports) ~= nil)
    record("comete.serveur.aucune_erreur_execution", #errors == 0, table.concat(errors, " || "))
    StudioTestService:EndTest({ session = session, players = 1, server = steps, clients = reports })
    return
end

-- ======================== K04, K05, K03, K06 : conduite ========================

local driverSeated = sit(player, model, "DriverSeat")
record("comete.k04.conducteur_assis", driverSeated)
if driverSeated then
    local owner = root:GetNetworkOwner()
    record("comete.k04.info_proprietaire_reseau", true, if owner then owner.Name else "serveur")
    ask(player, "pose:conducteur", { Seat = "DriverSeat" }, 20)
    shot(player, model, "comete_conducteur_par_la_vitre", Vector3.new(-9, 2.4, -1.4), Vector3.new(-1.2, 0.8, -1.45))
    ask(player, "cameras", {}, 60)
    -- Braquage à l'arrêt puis départ vers le mur de choc (−250, 3, 200), choc avant.
    local frontBefore = model:GetAttribute("DmgZoneFront") or 0
    local impactsBefore = model:GetAttribute("DmgImpacts") or 0
    local hooks = game:GetService("ServerStorage"):FindFirstChild("AWTestHooks") :: BindableFunction?
    local statsBefore = if hooks then hooks:Invoke("Impacts") else nil
    local drive = ask(player, "drive", { WallZ = 198 }, 60)
    record(
        "comete.k03.rapport_conduite",
        type(drive) == "table",
        if type(drive) == "table" then drive.Detail else "sans réponse"
    )
    task.wait(2)
    local total, bad, names = opaqueBoxes(model)
    local statsAfter = if hooks then hooks:Invoke("Impacts") else nil
    record(
        "comete.k06.info_chocs_non_confirmes_pendant_la_conduite",
        true,
        if type(statsBefore) == "table" and type(statsAfter) == "table"
            then string.format(
                "sans obstacle au contact : %d ; requêtes : %d",
                statsAfter.Unconfirmed - statsBefore.Unconfirmed,
                statsAfter.Queries - statsBefore.Queries
            )
            else "accès de test absent"
    )
    record(
        "comete.k06.choc_avant_confirme",
        (model:GetAttribute("DmgImpacts") or 0) > impactsBefore
            and (model:GetAttribute("DmgZoneFront") or 0) > frontBefore,
        zones(model)
    )
    record(
        "comete.k06.aucun_bloc_opaque_apres_choc",
        bad == 0,
        string.format(
            "%d élément(s) dans Degats ; opaques recouvrant le modèle : %d %s",
            total,
            bad,
            table.concat(names, ",")
        )
    )
    shot(player, model, "comete_apres_choc_avant", Vector3.new(-13, 4.5, -19), Vector3.new(0, 0.3, -1))
    -- Sortie conducteur (vraie touche F).
    ask(player, "exit", { Key = "F" }, 15)
    local humanoid = humanoidOf(player)
    record("comete.k04.sortie_conducteur", humanoid ~= nil and humanoid.SeatPart == nil)
end

-- Passager : pose et sortie (vraie touche Espace).
task.wait(1)
place(model, ground(-250, 120, 180))
task.wait(1.5)
if sit(player, model, "PassengerSeat") then
    record("comete.k04.passager_assis", true)
    ask(player, "pose:passager", { Seat = "PassengerSeat" }, 20)
    ask(player, "exit", { Key = "Space" }, 15)
    local humanoid = humanoidOf(player)
    record("comete.k04.sortie_passager", humanoid ~= nil and humanoid.SeatPart == nil)
else
    record("comete.k04.passager_assis", false)
end

-- ======================== K04 / K07 : embarquement réel, téléphone, feux stop ========================
-- Personnage posé près de la porte conducteur (instrumenté) ; montée par la VRAIE touche E maintenue (invite
-- « Conduire »), téléphone par la vraie touche T, freinage par la vraie touche S après un élan (W).
place(model, ground(-250, 120, 180))
task.wait(1.5)
character:PivotTo(root.CFrame * CFrame.new(-KIT.SideHalf - 2.5, 1.5, -1.4) * CFrame.Angles(0, math.rad(-90), 0))
task.wait(1)
local boarded = ask(player, "board", { Seat = "DriverSeat" }, 30)
local seatedNow = humanoidOf(player) ~= nil
    and (humanoidOf(player) :: Humanoid).SeatPart == model:FindFirstChild("DriverSeat")
record(
    "comete.k04.embarquement_reel_touche_e",
    seatedNow,
    if type(boarded) == "table" then boarded.Detail else "sans réponse"
)
if not seatedNow then
    sit(player, model, "DriverSeat") -- repli instrumenté (signalé) pour la suite
end
local phone = ask(player, "phone", {}, 20)
record(
    "comete.k04.rapport_telephone",
    type(phone) == "table",
    if type(phone) == "table" then phone.Detail else "sans réponse"
)
local brake = ask(player, "brake", {}, 40)
record(
    "comete.k07.rapport_feux_stop",
    type(brake) == "table",
    if type(brake) == "table" then brake.Detail else "sans réponse"
)
ask(player, "exit", { Key = "F" }, 15)

-- Choc arrière : véhicule vide replacé (serveur, sans conducteur), arrière à 14 st du mur, puis marche arrière
-- conduite au clavier. Choc latéral : non couvert (un véhicule vide lancé par le serveur est plafonné par la
-- validation anti-éjection, 3 m/s ; constaté le 2026-11-05, tâche 20261105-000811).
character:PivotTo(CFrame.new(-262, 4, 150))
task.wait(1)
local half = COMETE.Chassis.LengthM / M / 2
place(model, ground(-250, 198 - half - 14, 0)) -- avant vers −Z : l'arrière fait face au mur
task.wait(2)
if sit(player, model, "DriverSeat") then
    local rearBefore = model:GetAttribute("DmgZoneRear") or 0
    local impactsBefore = model:GetAttribute("DmgImpacts") or 0
    local reverse = ask(player, "reverse", {}, 60)
    record(
        "comete.k06.rapport_marche_arriere",
        type(reverse) == "table",
        if type(reverse) == "table" then reverse.Detail else "sans réponse"
    )
    task.wait(2)
    record(
        "comete.k06.choc_arriere_confirme",
        (model:GetAttribute("DmgImpacts") or 0) > impactsBefore
            and (model:GetAttribute("DmgZoneRear") or 0) > rearBefore,
        zones(model)
    )
    ask(player, "exit", { Key = "F" }, 15)
else
    record("comete.k06.choc_arriere_confirme", false, "conducteur non assis")
end
record("comete.k06.info_choc_lateral", true, "non couvert par cette session (voir commentaire)")
local total, bad, names = opaqueBoxes(model)
record(
    "comete.k06.aucun_bloc_opaque_apres_chocs",
    bad == 0,
    string.format("%d élément(s) dans Degats ; opaques : %d %s", total, bad, table.concat(names, ","))
)
place(model, ground(-250, 120, 180))
task.wait(1.5)
shot(player, model, "comete_apres_chocs_arriere", Vector3.new(14, 4.5, 20), Vector3.new(0, 0.3, 1))
-- Marques de dégâts du kit (posées sur la surface mesurée) : nombre par type, gros plans.
local markCount: { [string]: number } = {}
local degats = model:FindFirstChild("Degats")
for _, item in if degats then degats:GetChildren() else {} do
    local kind = string.match(item.Name, "^(%a-)[A-Z][a-z]+$") or item.Name
    markCount[kind] = (markCount[kind] or 0) + 1
end
local markRows = {}
for kind, count in markCount do
    table.insert(markRows, kind .. " " .. count)
end
table.sort(markRows)
record("comete.k06.marques_de_degats", #markRows > 0, table.concat(markRows, ", "))
shot(player, model, "comete_degats_avant_gros_plan", Vector3.new(-3, 1.6, -16), Vector3.new(0, -0.2, -9.2))
shot(player, model, "comete_degats_arriere_gros_plan", Vector3.new(3, 1.8, 13.5), Vector3.new(0, 0.1, 6.8))
record(
    "comete.k01.info_peinture",
    true,
    "mode " .. tostring((model:FindFirstChild("Carrosserie") :: Instance):GetAttribute("AWPaint"))
)

-- ======================== K07 : nuit ========================

local clock = Lighting.ClockTime
Lighting.ClockTime = 0
character:PivotTo(root.CFrame * CFrame.new(-8, 3, -14))
task.wait(2)
-- Véhicule accidenté : les optiques cassées restent éteintes la nuit.
local brokenNight = ask(player, "night", { Model = model }, 30)
local brokenCount = 0
for _, item in model:GetDescendants() do
    if item:IsA("BasePart") and item:GetAttribute("AWLightBroken") == true then
        brokenCount += 1
    end
end
record(
    "comete.k06.optiques_cassees_eteintes_la_nuit",
    type(brokenNight) == "table" and brokenCount > 0 and brokenNight.BrokenLit == 0,
    string.format(
        "%d optique(s) cassée(s) ; %s",
        brokenCount,
        if type(brokenNight) == "table" then brokenNight.Detail else "sans réponse"
    )
)
shot(player, model, "comete_nuit_apres_chocs", Vector3.new(-6, 3.5, -30), Vector3.new(0, 0.3, 0))
-- Comète neuve (remplace la précédente) : 4 sources allumées, captures de nuit.
local fresh = MissionService.spawnBeside(player, "wk_comete", "COMETE-NUIT")
if fresh then
    model = fresh
    root = fresh.PrimaryPart :: BasePart
    task.wait(1.5)
    place(fresh, ground(-250, 120, 180))
    task.wait(2.5)
    local night = ask(player, "night", { Model = fresh }, 30)
    record(
        "comete.k07.feux_allumes_la_nuit",
        type(night) == "table" and night.Enabled == 4 and night.Sources == 4,
        if type(night) == "table" then night.Detail else "sans réponse"
    )
    shot(player, fresh, "comete_nuit_avant", Vector3.new(-6, 3.5, -30), Vector3.new(0, 0.3, 0))
    shot(player, fresh, "comete_nuit_arriere", Vector3.new(6, 3.5, 28), Vector3.new(0, 0.3, 0))
else
    record("comete.k07.feux_allumes_la_nuit", false, "Comète neuve non apparue")
end
Lighting.ClockTime = clock

-- ======================== K01 : un autre véhicule garde sa carrosserie provisoire ========================

local p01 = MissionService.spawnBeside(player, "proto_p01", "COMETE-K01-P01")
if p01 then
    task.wait(1.5)
    local kitParts, parts = 0, 0
    for _, item in p01:GetDescendants() do
        if item:IsA("MeshPart") or string.find(item.Name, "COMETE_", 1, true) then
            kitParts += 1
        elseif item:IsA("BasePart") then
            parts += 1
        end
    end
    record(
        "comete.k01.autre_vehicule_inchange",
        kitParts == 0 and parts > 10,
        string.format("P-01 : %d pièce(s) primitive(s), %d pièce(s) du kit", parts, kitParts)
    )
    place(p01, ground(-250, 120, 180))
    task.wait(1.5)
    shot(player, p01, "p01_carrosserie_provisoire", Vector3.new(-15, 5, -21), Vector3.new(0, 0.3, -1))
    VehicleService.despawnPersonal(p01)
else
    record("comete.k01.autre_vehicule_inchange", false, "P-01 non apparu")
end
if model.Parent then
    VehicleService.despawnPersonal(model)
end

-- Accès de revue du propriétaire (Studio) : même appel que la fiche VEH3D_01_REVUE.md.
local review = game:GetService("ServerStorage"):FindFirstChild("AWRevue")
local reviewReply = if review and review:IsA("BindableFunction") then review:Invoke("wk_comete") else "absent"
record("comete.revue.acces_studio", string.sub(tostring(reviewReply), 1, 6) == "Apparu", tostring(reviewReply))

-- ======================== Fin ========================

ask(player, "finish", {}, 10)
waitFor(function()
    return next(reports) ~= nil
end, 60)
record("comete.serveur.rapport_client", next(reports) ~= nil)
record("comete.serveur.info_chocs_journalises", true, #impacts .. " : " .. table.concat(impacts, " || "))
record("comete.serveur.info_avertissements_du_jeu", true, #warnings .. " : " .. table.concat(warnings, " || "))
record("comete.serveur.aucune_erreur_execution", #errors == 0, table.concat(errors, " || "))
record(
    "comete.serveur.info_erreurs_internes_roblox",
    true,
    #robloxErrors .. " : " .. table.concat(robloxErrors, " || ")
)
trace("fin")
StudioTestService:EndTest({ session = session, players = 1, server = steps, clients = reports })
