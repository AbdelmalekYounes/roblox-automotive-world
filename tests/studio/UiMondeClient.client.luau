-- Essais CLIENT du lot 0.9.1 (session « ui_monde », place MONDE OUVERT, 1 joueur).
-- Campagne de CAPTURES à inspecter : décor et bâtiments des sept zones, concessions et
-- garages, carrosseries, tableau de bord et caméras (touche V réelle), carte (touche M
-- réelle), téléphone en main (touche T réelle), mode photo (touche O réelle), nuit
-- (éclairage public, feux), pluie de jour et de nuit.
-- Chaque capture est reliée à sa position, son contexte et la version (rapport).
-- Instrumenté (signalé) : le personnage est déplacé d'un point de vue à l'autre par le
-- serveur de test (aucune conduite : ce n'est pas un trajet) ; la caméra est placée par
-- script (mode « Scriptable ») pour cadrer bâtiments et carrosseries ; l'heure et la
-- météo sont forcées par le serveur de test.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local sessionStart = os.clock()
while ReplicatedStorage:GetAttribute("AWTestSession") == nil and os.clock() - sessionStart < 15 do
    task.wait()
end
if ReplicatedStorage:GetAttribute("AWTestSession") ~= "ui_monde" then
    return
end

local steps = {}
local measures = {}
local function record(name: string, ok: boolean, detail: any)
    table.insert(steps, { name = name, ok = ok, detail = if detail ~= nil then tostring(detail) else nil })
end
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
local function trace(message: string)
    print(string.format("[AW_Test] ui_monde %.1f s : %s", os.clock() - sessionStart, message))
end

local S = 1 / 0.28
local reportEvent = ReplicatedStorage:WaitForChild("AWTestReport", 30) :: RemoteEvent
local signalEvent = ReplicatedStorage:WaitForChild("AWTestSignal", 30) :: RemoteEvent
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldLayout = require(Shared:WaitForChild("World"):WaitForChild("WorldLayout")) :: any
local Gui = require(ReplicatedStorage:WaitForChild("AW_TestGui", 30)) :: any
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local function character(): Model
    return player.Character or player.CharacterAdded:Wait()
end
local function rootPart(): BasePart
    return character():WaitForChild("HumanoidRootPart", 10) :: BasePart
end
local function ask(name: string, timeout: number?): boolean
    ReplicatedStorage:SetAttribute("AWUI_Done", nil)
    signalEvent:FireServer(name)
    return waitFor(function()
        return ReplicatedStorage:GetAttribute("AWUI_Done") == name
    end, timeout or 20)
end

local camera = Workspace.CurrentCamera :: Camera
local function frame(eye: Vector3, at: Vector3)
    camera.CameraType = Enum.CameraType.Scriptable
    camera.CFrame = CFrame.lookAt(eye, at)
end
local function release()
    camera.CameraType = Enum.CameraType.Custom
end

local layout = WorldLayout.get()
local version = tostring(ReplicatedStorage:GetAttribute("AutomotiveWorldVersion") or "?")

-- Point de vue sur une zone : milieu du plus long tronçon de route ouverte de la zone.
local function zoneView(zone: string): (any, any)
    local best, bestLength, bestTangent = nil, 0, nil
    for _, edge in layout.Edges do
        if edge.Zone == zone and edge.Class ~= "Autoroute" and edge.LengthM > bestLength then
            local mid, tangent = WorldLayout.sampleAt(edge.Polyline, 0.5)
            best, bestLength, bestTangent = mid, edge.LengthM, tangent
        end
    end
    return best, bestTangent
end

local function viewpoint(label: string, point: any, facing: any, distanceM: number, heightM: number)
    if
        not ask(string.format("AWUI:Goto:%.1f,%.1f", point.X + facing.X * distanceM, point.Z + facing.Z * distanceM))
    then
        record("ui_monde.vue_" .. label, false, "déplacement non confirmé")
        return
    end
    task.wait(4) -- streaming et habillage
    local ground = rootPart().Position.Y - 4
    local target = Vector3.new(point.X * S, ground + 2 * S, point.Z * S)
    local eye =
        Vector3.new((point.X + facing.X * distanceM) * S, ground + heightM * S, (point.Z + facing.Z * distanceM) * S)
    frame(eye, target)
    task.wait(1.5)
    Gui.shot("monde_" .. label, {
        zone = WorldLayout.zoneOf(point.X, point.Z),
        x = math.floor(point.X),
        z = math.floor(point.Z),
        heure = math.floor(game:GetService("Lighting").ClockTime * 10) / 10,
        version = version,
    })
    release()
    record("ui_monde.vue_" .. label, true, string.format("(%.0f, %.0f) m", point.X, point.Z))
end

local function main()
    waitFor(function()
        return ReplicatedStorage:GetAttribute("AutomotiveWorldMode") == "OpenWorld"
    end, 30)
    character():WaitForChild("HumanoidRootPart", 20)
    task.wait(6)
    local calibrated = Gui.calibrate(3)
    record("ui_monde.entrees_reelles", calibrated)
    Gui.calibrateKeys()
    -- Fenêtre d'arrivée (profil neuf) : « Passer l'introduction » par un vrai clic, pour
    -- dégager les vues (tâche 20261103-220054 : fenêtre restée devant le décor).
    local onboarding = playerGui:FindFirstChild("AWOnboarding")
    local skip = nil
    waitFor(function()
        skip = Gui.findButton(onboarding, "Passer l'introduction")
        return skip ~= nil
    end, 15)
    if skip then
        local ok = Gui.click(skip, "Passer l'introduction")
        record("ui_monde.arrivee_passee_par_clic", ok)
        task.wait(1.5)
        -- Étape suivante (choix du véhicule) : fenêtre refermée par la touche P puis P.
        Gui.key("P")
        task.wait(0.8)
        Gui.key("P")
        task.wait(0.8)
    end
    ask("AWUI:Time:12")
    task.wait(2)

    -- 1. Décor des sept zones, puis concessions, garages, stations.
    for _, zone in { "Metropole", "Banlieues", "Docks", "Littoral", "Campagne", "Montagnes", "Motorsport" } do
        local point, tangent = zoneView(zone)
        if point then
            local side = { X = -tangent.Z, Z = tangent.X }
            viewpoint(
                "zone_" .. zone,
                point,
                { X = side.X * 0.6 - tangent.X * 0.8, Z = side.Z * 0.6 - tangent.Z * 0.8 },
                40,
                14
            )
        end
    end
    local kinds = { Dealership = 0, PublicGarage = 0, FuelStation = 0, ChargingHub = 0 }
    for _, placement in layout.Placements do
        local count = kinds[placement.Kind]
        if count ~= nil and count < 2 then
            kinds[placement.Kind] = count + 1
            viewpoint(string.lower(placement.Kind) .. "_" .. placement.Id, placement.Center, placement.Facing, 30, 10)
        end
    end

    -- 2. Carrosserie, tableau de bord, caméras (touche V), mini-carte, carte (touche M).
    signalEvent:FireServer("AWUI:PlaceStart")
    local placed = waitFor(function()
        return type(ReplicatedStorage:GetAttribute("AWUI_StartVehicle")) == "string"
    end, 30)
    local fleet = Workspace:WaitForChild("VehiculesEssai", 20)
    local model = placed
        and fleet
        and fleet:FindFirstChild(ReplicatedStorage:GetAttribute("AWUI_StartVehicle")) :: Model?
    if model and model.PrimaryPart then
        task.wait(3)
        local body = (model :: Model).PrimaryPart :: BasePart
        for index, offset in
            { Vector3.new(14, 5, -16), Vector3.new(-14, 5, 16), Vector3.new(18, 3, 0), Vector3.new(0, 30, 2) }
        do
            frame((body.CFrame * CFrame.new(offset)).Position, body.Position)
            task.wait(1)
            Gui.shot("carrosserie_" .. index, { vehicle = (model :: Model).Name, version = version })
        end
        release()
        local door = body:FindFirstChild("DriverDoor") :: Attachment?
        local prompt = door and door:FindFirstChild("EnterPrompt") :: ProximityPrompt?
        if door and prompt then
            for _ = 1, 3 do
                rootPart().CFrame = CFrame.new(door.WorldPosition + Vector3.new(0, 2, 0))
                task.wait(1)
                Gui.key("E", 800)
                if
                    waitFor(function()
                        return (model :: Model):GetAttribute("DriverUserId") == player.UserId
                    end, 4)
                then
                    break
                end
            end
        end
        local seated = (model :: Model):GetAttribute("DriverUserId") == player.UserId
        record("ui_monde.embarquement_touche_E", seated)
        if seated then
            task.wait(2)
            Gui.shot("tableau_de_bord_camera_1", { version = version })
            for mode = 2, 4 do
                Gui.key("V")
                task.wait(1.2)
                Gui.shot("tableau_de_bord_camera_" .. mode, { version = version })
            end
            Gui.key("M")
            local map = playerGui:FindFirstChild("AWMap") :: ScreenGui?
            local opened = waitFor(function()
                map = playerGui:FindFirstChild("AWMap") :: ScreenGui?
                return map ~= nil and (map :: ScreenGui).Enabled
            end, 4)
            record("ui_monde.carte_touche_M", opened)
            task.wait(2)
            Gui.shot("carte_monde", { version = version })
            Gui.click(Gui.findButton(map, "Zoom +"), "Zoom +")
            task.wait(1)
            Gui.shot("carte_monde_zoom", { version = version })
            Gui.key("M")
            task.wait(1)
            -- 3. Nuit : éclairage public et feux du véhicule.
            ask("AWUI:Time:22")
            task.wait(6)
            Gui.shot("nuit_tableau_de_bord", { heure = 22, version = version })
            frame((body.CFrame * CFrame.new(Vector3.new(10, 4, -22))).Position, body.Position)
            task.wait(2)
            Gui.shot("nuit_feux_vehicule", { heure = 22, version = version })
            release()
            ask("AWUI:Rain")
            task.wait(6)
            Gui.shot("nuit_pluie_conduite", { heure = 22, meteo = "pluie", version = version })
            Gui.key("F", 400)
            task.wait(2)
        end
    else
        record("ui_monde.vehicule_place", false)
    end
    local spawnPoint, spawnTangent = zoneView("Metropole")
    if spawnPoint then
        viewpoint("nuit_pluie_metropole", spawnPoint, { X = -spawnTangent.Z, Z = spawnTangent.X }, 35, 12)
        ask("AWUI:Clear")
        task.wait(4)
        viewpoint("nuit_metropole", spawnPoint, { X = spawnTangent.X, Z = spawnTangent.Z }, 35, 10)
        ask("AWUI:Time:12")
        ask("AWUI:Rain")
        task.wait(6)
        viewpoint("jour_pluie_metropole", spawnPoint, { X = spawnTangent.X, Z = spawnTangent.Z }, 35, 10)
        ask("AWUI:Clear")
    end

    -- 4. Téléphone en main (touche T), vu de face ; mode photo (touche O).
    task.wait(2)
    -- Diagnostic du bras levé (InterfaceService : épaule tournée de 60°) : angle relevé
    -- côté client avant et après l'ouverture.
    local function shoulderC0(): CFrame?
        local upper = character():FindFirstChild("RightUpperArm")
        local motor = upper and upper:FindFirstChild("RightShoulder")
        if motor == nil then
            local torso = character():FindFirstChild("Torso")
            motor = torso and torso:FindFirstChild("Right Shoulder")
        end
        return if motor and motor:IsA("Motor6D") then motor.C0 else nil
    end
    -- Lot 0.9.2 (QA-A10) : nature des articulations de l'avatar (Motor6D ou contraintes
    -- d'animation du nouveau squelette R15) ; seule la première épaule droite est détaillée.
    local joints = {}
    for _, item in character():GetDescendants() do
        if item:IsA("Motor6D") or item:IsA("AnimationConstraint") or item:IsA("BallSocketConstraint") then
            if string.find(item.Name, "Shoulder", 1, true) or #joints < 3 then
                table.insert(
                    joints,
                    item.ClassName .. ":" .. item.Name .. "@" .. tostring(item.Parent and item.Parent.Name)
                )
            end
        end
    end
    record("ui_monde.info_articulations_avatar", true, table.concat(joints, ", "))
    local before = shoulderC0()
    Gui.key("T")
    local phone = waitFor(function()
        local gui = playerGui:FindFirstChild("AWPhone") :: ScreenGui?
        return gui ~= nil and gui.Enabled
    end, 4)
    record("ui_monde.telephone_touche_T", phone)
    task.wait(1.5)
    local after = shoulderC0()
    local raised = if before and after
        then math.deg(math.acos(math.clamp(before.LookVector:Dot(after.LookVector), -1, 1)))
        else -1
    record(
        "ui_monde.info_bras_leve_angle_epaule",
        true,
        string.format("rotation de l'épaule vue par le client : %.0f° (attendu ≈ 60°)", raised)
    )
    local root = rootPart()
    frame((root.CFrame * CFrame.new(1.5, 1.5, -7)).Position, root.Position + Vector3.new(0, 1, 0))
    task.wait(1)
    Gui.shot("telephone_en_main_face", { version = version })
    release()
    Gui.key("T")
    task.wait(1)
    -- La touche O n'atteint pas le jeu dans Studio (limite établie par la session « ui ») :
    -- ouverture par l'application Photo du téléphone, en vrais clics.
    local function photoOpen(): boolean
        local gui = playerGui:FindFirstChild("AWPhoto") :: ScreenGui?
        return gui ~= nil and gui.Enabled
    end
    Gui.key("T")
    local photo = false
    if
        waitFor(function()
            local gui = playerGui:FindFirstChild("AWPhone") :: ScreenGui?
            return gui ~= nil and gui.Enabled
        end, 4)
    then
        local phoneGui = playerGui:FindFirstChild("AWPhone")
        Gui.click(Gui.findButton(phoneGui, "Photo"), "Photo")
        task.wait(0.8)
        Gui.click(Gui.findButton(phoneGui, "Ouvrir le mode photo"), "Ouvrir le mode photo")
        photo = waitFor(photoOpen, 4)
    end
    record("ui_monde.mode_photo_par_le_telephone", photo, if photo then "ouvert" else "non ouvert")
    if photo then
        task.wait(1)
        Gui.shot("mode_photo", { version = version })
        local gui = playerGui:FindFirstChild("AWPhoto") :: ScreenGui
        local filter = gui:FindFirstChild("photo.filter", true)
        Gui.click(if filter and filter:IsA("GuiButton") then filter else nil, "photo.filter")
        task.wait(1)
        Gui.shot("mode_photo_filtre", { version = version })
        local exit = gui:FindFirstChild("photo.exit", true)
        Gui.click(if exit and exit:IsA("GuiButton") then exit else nil, "photo.exit")
    end
    trace("captures terminées")
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
    record("ui_monde.execution", false, err)
end
release()
for _, shot in Gui.report().shots do
    record(
        "ui_monde.capture." .. shot.name,
        true,
        string.format("(%d, %d, %d) st, %s", shot.x, shot.y, shot.z, tostring(shot.context))
    )
end
measures.captures = #Gui.report().shots
reportEvent:FireServer({ vehicle = "ui_monde", steps = steps, measures = measures, gui = Gui.report() })
