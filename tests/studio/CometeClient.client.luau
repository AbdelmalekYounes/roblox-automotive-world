-- Essais CLIENT du lot VEH3D-01 (session « comete », place de développement, 1 joueur) : répond aux demandes
-- du serveur de test (AWCometeAsk).
--   preload  : chargement réel des maillages et textures du kit par ce client (ContentProvider), QA-K02 ;
--   pose     : tête, mains et pieds dans le repère du véhicule, pose du jeu appliquée (QA-K04) ;
--   cameras  : vraie touche V jusqu'aux vues cockpit, capot et bouclier (QA-K05) ;
--   drive    : braquage (vraie touche A), passage de la 1re (vraie touche Maj, boîte séquentielle au neutre),
--              accélération (vraie touche W) vers le mur de choc ; rotation des jantes du modèle (QA-K03, K06) ;
--   exit     : sortie par vraie touche (F conducteur, Espace passager) ;
--   night    : sources de lumière allumées et vitrage vus par ce client (QA-K07) ;
--   frames   : temps d'image pendant 8 s, cadrage fixe (QA-K08).
-- Instrumenté (signalé) : caméra placée par script pour les captures et la mesure des temps d'image.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local sessionStart = os.clock()
while ReplicatedStorage:GetAttribute("AWTestSession") == nil and os.clock() - sessionStart < 15 do
    task.wait()
end
local cometeSession = ReplicatedStorage:GetAttribute("AWTestSession")
if
    cometeSession ~= "comete"
    and cometeSession ~= "comete_vitres"
    and cometeSession ~= "comete_perf"
    and cometeSession ~= "comete2"
then
    return
end

local steps = {}
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
    print(string.format("[AW_Test] comete client %.1f s : %s", os.clock() - sessionStart, message))
end

local reportEvent = ReplicatedStorage:WaitForChild("AWTestReport", 30) :: RemoteEvent
local signalEvent = ReplicatedStorage:WaitForChild("AWTestSignal", 30) :: RemoteEvent
local askEvent = ReplicatedStorage:WaitForChild("AWCometeAsk", 30) :: RemoteEvent
local Gui = require(ReplicatedStorage:WaitForChild("AW_TestGui", 30)) :: any
local VehiclesShared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Vehicles")
local KIT = (require(VehiclesShared:WaitForChild("MeshKitData")) :: any).Kits.wk_comete
local Constants = require(VehiclesShared:WaitForChild("VehicleConstants")) :: any
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local camera = Workspace.CurrentCamera :: Camera

local UIState = require(
    player
        :WaitForChild("PlayerScripts")
        :WaitForChild("AutomotiveWorldClient")
        :WaitForChild("UI")
        :WaitForChild("UIState")
) :: any
local VehicleController = require(
    player
        :WaitForChild("PlayerScripts")
        :WaitForChild("AutomotiveWorldClient")
        :WaitForChild("Vehicles")
        :WaitForChild("VehicleController")
) :: any
local M = Constants.MetersPerStud

local function character(): Model
    return player.Character or player.CharacterAdded:Wait()
end
local function humanoid(): Humanoid?
    return character():FindFirstChildOfClass("Humanoid")
end
local function seatedVehicle(): (Model?, BasePart?)
    local h = humanoid()
    local seat = h and h.SeatPart
    local model = seat and seat.Parent
    if model and model:IsA("Model") and model.PrimaryPart then
        return model, model.PrimaryPart
    end
    return nil, nil
end

-- Caméra imposée pour une capture : le contrôleur du véhicule replace la caméra à chaque image
-- (lot AVATAR-01, tâche 20261104-104818) ; cadrage réimposé à chaque étape de rendu.
local function withView(view: CFrame, fn: () -> ())
    RunService:BindToRenderStep("AWCometeShot", Enum.RenderPriority.Last.Value + 10, function()
        camera.CFrame = view
    end)
    local preRender = RunService.PreRender:Connect(function()
        camera.CFrame = view
    end)
    local changed = camera:GetPropertyChangedSignal("CFrame"):Connect(function()
        if camera.CFrame ~= view then
            camera.CFrame = view
        end
    end)
    task.wait(0.6)
    fn()
    changed:Disconnect()
    preRender:Disconnect()
    RunService:UnbindFromRenderStep("AWCometeShot")
end

local handlers: { [string]: (string, any) -> any } = {}

-- Fenêtre modale ouverte (parcours d'arrivée…) : la conduite est capturée par l'interface (lot 0.7,
-- `UIState.capturesDriving`), comportement voulu du jeu. Fermeture par la vraie touche Retour.
local function closeModals(label: string)
    local presses = 0
    while UIState.capturesDriving() and presses < 5 do
        Gui.key("Backspace")
        presses += 1
        task.wait(0.8)
    end
    record(
        "comete.client.fenetres_fermees_" .. label,
        not UIState.capturesDriving(),
        string.format("%d appui(s) sur Retour", presses)
    )
end

handlers.calibrate = function()
    record("comete.client.entrees_reelles", (Gui.calibrate(3)))
    local keys, detail = Gui.calibrateKeys(3)
    record("comete.client.clavier_etalonne", keys, detail)
    -- Fenêtre d'arrivée (profil neuf) : « Passer l'introduction » par un vrai clic.
    local onboarding = playerGui:FindFirstChild("AWOnboarding")
    local skip = nil
    waitFor(function()
        skip = Gui.findButton(onboarding, "Passer l'introduction")
        return skip ~= nil
    end, 10)
    if skip then
        record("comete.client.arrivee_passee_par_clic", (Gui.click(skip, "Passer l'introduction")))
        task.wait(1.5)
    end
    -- Choix de silhouette (lot Aster, profil neuf) : fenêtre modale fermée par un vrai clic.
    local silhouette = nil
    waitFor(function()
        silhouette = Gui.findButton(playerGui, "Masculin")
        return silhouette ~= nil and Gui.shown(silhouette)
    end, 8)
    if silhouette and Gui.shown(silhouette) then
        record("comete.client.silhouette_choisie_par_clic", (Gui.click(silhouette, "Masculin")))
        task.wait(2)
    end
    closeModals("apres_l_arrivee")
    return true
end

-- QA-K02 : ce client télécharge-t-il les maillages et textures envoyés par le propriétaire ?
handlers.preload = function(_id, data)
    local model = data.Model
    if typeof(model) ~= "Instance" then
        record("comete.k02.maillages_charges", false, "véhicule non répliqué")
        return { Detail = "véhicule absent" }
    end
    local list = {}
    for _, item in model:GetDescendants() do
        if item:IsA("MeshPart") or item:IsA("SurfaceAppearance") then
            table.insert(list, item)
        end
    end
    local byStatus: { [string]: number } = {}
    local failed: { string } = {}
    local started = os.clock()
    local ok, err = pcall(function()
        ContentProvider:PreloadAsync(list, function(contentId: string, status: Enum.AssetFetchStatus)
            byStatus[status.Name] = (byStatus[status.Name] or 0) + 1
            if status ~= Enum.AssetFetchStatus.Success and #failed < 6 then
                table.insert(failed, contentId .. "=" .. status.Name)
            end
        end)
    end)
    local parts = {}
    for name, count in byStatus do
        table.insert(parts, name .. " " .. count)
    end
    table.sort(parts)
    local success = byStatus.Success or 0
    local detail = string.format(
        "%d objet(s) ; %s ; %.1f s%s%s",
        #list,
        table.concat(parts, ", "),
        os.clock() - started,
        if #failed > 0 then " ; échecs : " .. table.concat(failed, ", ") else "",
        if ok then "" else " ; erreur " .. tostring(err)
    )
    record("comete.k02.maillages_charges", ok and success >= 28 and #failed == 0, detail)
    return { Detail = detail }
end

handlers.shot = function(_id, data)
    local c = data.Cadrage
    if type(c) == "table" and #c == 12 then
        withView(CFrame.new(table.unpack(c)), function()
            Gui.shot(tostring(data.Name), { vehicule = "wk_comete" })
        end)
    end
    return true
end

-- QA-K04 : pose du jeu (appliquée par ce client) mesurée dans le repère du véhicule.
handlers.pose = function(id, _data)
    local label = string.match(id, ":(.+)$") or "?"
    task.wait(1.5)
    local model, root = seatedVehicle()
    local me = character()
    if model == nil or root == nil then
        record("comete.k04.pose_" .. label, false, "non assis")
        return { Detail = "non assis" }
    end
    local frame = (root :: BasePart).CFrame
    local function localOf(name: string): Vector3?
        local part = me:FindFirstChild(name)
        return if part and part:IsA("BasePart") then frame:PointToObjectSpace(part.Position) else nil
    end
    local roof = KIT.RoofUnderside
    local head = me:FindFirstChild("Head") :: BasePart?
    local headTop = if head then frame:PointToObjectSpace(head.Position).Y + head.Size.Y / 2 else nil
    local handL, handR = localOf("LeftHand"), localOf("RightHand")
    -- Pieds : dessous de la pièce (centre − demi-hauteur) comparé au plancher MESURÉ sous le pédalier.
    local function footBottom(name: string): (number?, number?)
        local part = me:FindFirstChild(name)
        if part == nil or not part:IsA("BasePart") then
            return nil, nil
        end
        local p = frame:PointToObjectSpace(part.Position)
        return p.Y - part.Size.Y / 2, p.Z
    end
    local lY, lZ = footBottom("LeftFoot")
    local rY, rZ = footBottom("RightFoot")
    local sideMax = math.max(math.abs(handL and handL.X or 0), math.abs(handR and handR.X or 0))
    local feetLow = math.min(lY or math.huge, rY or math.huge)
    local feetFront = math.min(lZ or math.huge, rZ or math.huge)
    local feetRear = math.max(lZ or -math.huge, rZ or -math.huge)
    local well = KIT.Footwell
    local headOk = headTop ~= nil and headTop < roof
    local handsOk = sideMax < KIT.SideHalf
    -- Pieds POSÉS sur le plancher (ni dessous, ni en l'air à hauteur de planche de bord).
    local feetOk = feetLow >= well.FloorY - 0.05
        and feetLow <= well.FloorY + 0.6
        and feetFront >= well.FrontZ - 0.3
        and feetRear <= well.RearZ + 0.6
    local detail = string.format(
        "haut de la tête %.2f (pavillon %.2f) ; mains |x| %.2f (flanc %.2f) ; dessous des pieds y %.2f (plancher %.2f), z %.2f à %.2f (pédalier %.2f à %.2f)",
        headTop or -99,
        roof,
        sideMax,
        KIT.SideHalf,
        feetLow,
        well.FloorY,
        feetFront,
        feetRear,
        well.FrontZ,
        well.RearZ
    )
    record("comete.k04.pose_" .. label .. "_dans_l_habitacle", headOk and handsOk and feetOk, detail)
    return { Detail = detail }
end

-- QA-K05 : vraie touche V jusqu'à chaque vue du kit ; capture à la première arrivée.
handlers.cameras = function()
    local model, root = seatedVehicle()
    if root == nil or model == nil then
        record("comete.k05.vues", false, "non assis")
        return true
    end
    local reached: { [string]: boolean } = {}
    local names = { "CameraCockpit", "CameraHood", "CameraBumper" }
    for _ = 1, 7 do
        Gui.key("V")
        task.wait(0.9)
        for _, name in names do
            local attachment = (root :: BasePart):FindFirstChild(name) :: Attachment?
            if
                attachment
                and not reached[name]
                and (camera.CFrame.Position - attachment.WorldPosition).Magnitude < 1
            then
                reached[name] = true
                Gui.shot("comete_vue_" .. string.lower(string.sub(name, 7)), { vue = name })
            end
        end
    end
    local list = {}
    for _, name in names do
        table.insert(list, name .. (if reached[name] then " atteinte" else " NON atteinte"))
    end
    record(
        "comete.k05.vues_cockpit_capot_bouclier",
        reached.CameraCockpit and reached.CameraHood and reached.CameraBumper,
        table.concat(list, ", ")
    )
    -- Retour à la vue extérieure.
    for _ = 1, 6 do
        local near = false
        for _, name in names do
            local attachment = (root :: BasePart):FindFirstChild(name) :: Attachment?
            if attachment and (camera.CFrame.Position - attachment.WorldPosition).Magnitude < 3 then
                near = true
            end
        end
        if not near then
            break
        end
        Gui.key("V")
        task.wait(0.9)
    end
    return true
end

-- QA-K03 / K06 : braquage, rotation des jantes du modèle, choc avant contre le mur.
handlers.drive = function()
    local model, root = seatedVehicle()
    if model == nil or root == nil then
        record("comete.k03.conduite", false, "non assis")
        return { Detail = "non assis" }
    end
    closeModals("avant_conduite")
    local body = root :: BasePart
    local wheelFL = model:FindFirstChild("WheelFL")
    local tyre = wheelFL and wheelFL:FindFirstChild(KIT.Wheels.FL[1]) :: BasePart?
    local rim = wheelFL and wheelFL:FindFirstChild(KIT.Wheels.FL[2]) :: BasePart?
    if tyre == nil or rim == nil then
        record("comete.k03.pieces_de_roue_vues_par_le_client", false, "pneu ou jante absents de WheelFL")
        return { Detail = "pièces de roue absentes" }
    end
    local function yawOf(part: BasePart): number
        local right = body.CFrame:VectorToObjectSpace(part.CFrame.RightVector)
        return math.deg(math.atan2(-right.Z, right.X))
    end
    -- Braquage à l'arrêt (vraie touche A) : l'axe du pneu tourne par rapport à la caisse.
    local yaw0 = yawOf(tyre)
    Gui.keyDown("A")
    task.wait(0.9)
    local steer = math.abs(yawOf(tyre) - yaw0)
    Gui.keyUp("A")
    task.wait(0.9)
    record("comete.k03.braquage_du_pneu_du_modele", steer > 5, string.format("%.1f° (touche A)", steer))

    -- Rotation cumulée de la jante (repère de la caisse) et vitesse, à chaque image.
    local spin, maxKmh = 0, 0
    local previous = body.CFrame:VectorToObjectSpace(rim.CFrame.UpVector)
    local connection = RunService.Heartbeat:Connect(function()
        local now = body.CFrame:VectorToObjectSpace(rim.CFrame.UpVector)
        spin += math.deg(math.acos(math.clamp(previous:Dot(now), -1, 1)))
        previous = now
        maxKmh = math.max(maxKmh, body.AssemblyLinearVelocity.Magnitude * M * 3.6)
    end)
    local startZ = body.Position.Z
    local function speed(): number
        return body.AssemblyLinearVelocity.Magnitude * M * 3.6
    end
    -- Boîte séquentielle au neutre : passage de la 1re par la vraie touche Maj, puis W.
    local attempts = 0
    -- Décision du propriétaire (2026-11-05) : W seul engage le 1er au neutre et à l'arrêt ; Maj en repli au 2e essai.
    local gearBefore = VehicleController.getTestSnapshot().Gear
    repeat
        attempts += 1
        if attempts > 1 then
            Gui.key("Shift")
            task.wait(0.5)
        end
        Gui.keyDown("W")
        waitFor(function()
            return speed() >= 30
        end, 7)
        Gui.keyUp("W")
    until speed() >= 3 or attempts >= 2
    record(
        "comete.k03.premier_engage_par_l_accelerateur",
        gearBefore == 0 and attempts == 1 and maxKmh >= 15,
        string.format("rapport avant %s ; essais %d ; vitesse max %.1f km/h", tostring(gearBefore), attempts, maxKmh)
    )
    local releaseKmh = speed()
    -- Roue libre jusqu'au mur ou à l'arrêt.
    local stopped = waitFor(function()
        return speed() < 1.5
    end, 10)
    task.wait(0.5)
    connection:Disconnect()
    local detail = string.format(
        "vitesse au lâcher %.1f km/h, max %.1f km/h ; %.1f st parcourus ; rotation de la jante %.0f° ; arrêt %s ; essais %d",
        releaseKmh,
        maxKmh,
        body.Position.Z - startZ,
        spin,
        tostring(stopped),
        attempts
    )
    record("comete.k03.vehicule_conduit", maxKmh >= 15, detail)
    record("comete.k03.jante_du_modele_tourne", spin > 360, string.format("%.0f°", spin))
    return { Detail = detail }
end

-- QA-K06 : choc arrière en marche arrière. Boîte séquentielle : R s'atteint en descendant depuis le neutre,
-- véhicule arrêté (vraie touche Ctrl) ; puis accélérateur (vraie touche W).
handlers.reverse = function()
    local _model, root = seatedVehicle()
    if root == nil then
        record("comete.k06.marche_arriere", false, "non assis")
        return { Detail = "non assis" }
    end
    closeModals("avant_marche_arriere")
    local body = root :: BasePart
    local function speed(): number
        return body.AssemblyLinearVelocity.Magnitude * M * 3.6
    end
    local function state(): string
        local snap = VehicleController.getTestSnapshot()
        return string.format(
            "rapport %s, moteur %s, calé %s, %.0f tr/min",
            tostring(snap.Gear),
            tostring(snap.EngineRunning),
            tostring(snap.EngineStalled),
            snap.EngineRpm or 0
        )
    end
    local before = state()
    -- Moteur calé par le choc avant : le démarreur tourne accélérateur relâché (règle QA-A12, lot 0.9.2).
    waitFor(function()
        return VehicleController.getTestSnapshot().EngineRunning == true
    end, 4)
    local presses = 0
    local stopKeys = Gui.recordKeys()
    while VehicleController.getTestSnapshot().Gear ~= -1 and presses < 5 do
        Gui.key("Control")
        presses += 1
        task.wait(0.5)
    end
    local received = stopKeys()
    record(
        "comete.k06.ctrl_recu_par_le_jeu",
        VehicleController.getTestSnapshot().Gear == -1,
        "touches reçues : " .. (if #received > 0 then table.concat(received, ",") else "aucune")
    )
    -- Repli INSTRUMENTÉ (signalé) si la vraie touche n'arrive pas : même gestionnaire que la touche liée.
    local instrumented = 0
    while VehicleController.getTestSnapshot().Gear ~= -1 and instrumented < 3 do
        VehicleController.invokeActionForTest("AWVehicleShiftDown")
        instrumented += 1
        task.wait(0.5)
    end
    local engaged = state()
        .. (if instrumented > 0 then string.format(" (rétrogradage instrumenté ×%d)", instrumented) else "")
    local start = body.CFrame
    local maxKmh = 0
    local connection = RunService.Heartbeat:Connect(function()
        maxKmh = math.max(maxKmh, speed())
    end)
    Gui.keyDown("W")
    waitFor(function()
        return speed() >= 18
    end, 7)
    Gui.keyUp("W")
    local releaseKmh = speed()
    waitFor(function()
        return speed() < 1.5
    end, 10)
    task.wait(0.5)
    connection:Disconnect()
    -- Déplacement le long de l'avant du véhicule : négatif en marche arrière.
    local moved = start:PointToObjectSpace(body.Position)
    local detail = string.format(
        "avant : %s ; après %d appui(s) sur Ctrl : %s ; vitesse au lâcher %.1f km/h, max %.1f km/h ; déplacement %.1f st vers l'arrière",
        before,
        presses,
        engaged,
        releaseKmh,
        maxKmh,
        moved.Z
    )
    record("comete.k06.marche_arriere", maxKmh >= 10 and moved.Z > 3, detail)
    return { Detail = detail }
end

-- QA-K04 : montée par la vraie touche E maintenue sur l'invite la plus proche (porte conducteur).
handlers.board = function(_id, data)
    local h = humanoid()
    local hold = 0
    local shown = waitFor(function()
        local me = character():FindFirstChild("HumanoidRootPart") :: BasePart?
        for _, item in Workspace:GetDescendants() do
            if item:IsA("ProximityPrompt") and item.Name == "EnterPrompt" and item.Enabled then
                local parent = item.Parent
                local at = if parent and parent:IsA("Attachment")
                    then parent.WorldPosition
                    elseif parent and parent:IsA("BasePart") then parent.Position
                    else nil
                if me and at and (at - me.Position).Magnitude < item.MaxActivationDistance + 2 then
                    hold = item.HoldDuration
                    return true
                end
            end
        end
        return false
    end, 6)
    Gui.keyDown("E")
    local seated = waitFor(function()
        return h ~= nil and h.SeatPart ~= nil and h.SeatPart.Name == tostring(data.Seat)
    end, hold + 3)
    Gui.keyUp("E")
    task.wait(1)
    local detail = string.format(
        "invite %s (maintien %.1f s) ; assis %s",
        if shown then "visible" else "absente",
        hold,
        tostring(seated)
    )
    record("comete.client.embarquement_touche_e", seated, detail)
    return { Detail = detail }
end

-- QA-K04 : téléphone au volant (vraie touche T), capture, fermeture.
handlers.phone = function()
    local function shownPhone(): boolean
        local gui = playerGui:FindFirstChild("AWPhone") :: ScreenGui?
        return gui ~= nil and gui.Enabled
    end
    Gui.key("T")
    local opened = waitFor(shownPhone, 4)
    task.wait(1.2)
    Gui.shot("comete_telephone_au_volant", { vue = "jeu" })
    Gui.key("T")
    local closed = waitFor(function()
        return not shownPhone()
    end, 4)
    local detail = string.format("ouvert %s ; refermé %s", tostring(opened), tostring(closed))
    record("comete.k04.telephone_au_volant", opened and closed, detail)
    return { Detail = detail }
end

-- QA-K07 : feux stop. Élan (W) puis freinage (vraie touche S) : attribut publié par le serveur, sources arrière
-- renforcées ; capture de l'arrière pendant le freinage.
handlers.brake = function()
    local model, root = seatedVehicle()
    if model == nil or root == nil then
        record("comete.k07.feux_stop", false, "non assis")
        return { Detail = "non assis" }
    end
    closeModals("avant_freinage")
    local body = root :: BasePart
    local function speed(): number
        return body.AssemblyLinearVelocity.Magnitude * M * 3.6
    end
    if VehicleController.getTestSnapshot().Gear == 0 then
        Gui.key("Shift")
        task.wait(0.5)
    end
    local brakingBefore = model:GetAttribute(Constants.Attributes.VisualBrake) == true
    Gui.keyDown("W")
    waitFor(function()
        return speed() >= 25
    end, 6)
    Gui.keyUp("W")
    local kmh = speed()
    Gui.keyDown("S")
    local published = waitFor(function()
        return model:GetAttribute(Constants.Attributes.VisualBrake) == true
    end, 2)
    task.wait(0.6) -- passage de VehicleLights (0,5 s)
    local brighter, lit, tails = 0, 0, 0
    for _, item in model:GetDescendants() do
        if item:IsA("BasePart") and item:GetAttribute("AWLight") == "Tail" then
            local light = item:FindFirstChild("Lumiere")
            if light and light:IsA("Light") then
                tails += 1
                lit += if light.Enabled then 1 else 0
                brighter += if light.Brightness >= 2.5 then 1 else 0
            end
        end
    end
    local view =
        CFrame.lookAt((body.CFrame * CFrame.new(6, 3.5, 22)).Position, (body.CFrame * CFrame.new(0, 0.8, 6)).Position)
    withView(view, function()
        Gui.shot("comete_feux_stop", { vitesse = math.floor(kmh) })
    end)
    Gui.keyUp("S")
    -- Arrêt par le frein à main (Espace) : le frein maintenu à l'arrêt enclenche la marche arrière (A3).
    Gui.keyDown("Space")
    waitFor(function()
        return speed() < 1
    end, 4)
    Gui.keyUp("Space")
    task.wait(0.8)
    local released = model:GetAttribute(Constants.Attributes.VisualBrake) ~= true
    local detail = string.format(
        "élan %.0f km/h ; freinage publié %s (avant %s, relâché %s) ; feux arrière allumés %d / %d, renforcés %d",
        kmh,
        tostring(published),
        tostring(brakingBefore),
        tostring(released),
        lit,
        tails,
        brighter
    )
    record("comete.k07.feux_stop", published and tails > 0 and lit == tails and brighter == tails, detail)
    return { Detail = detail }
end

-- Session « comete2 », joueur 1 : braquage, élan, freinage par le point d'accès de test (instrumenté).
handlers.demo = function()
    local model, root = seatedVehicle()
    if model == nil or root == nil then
        record("comete2.conducteur.assis", false)
        return { Detail = "non assis" }
    end
    local phase = { Throttle = 0, Brake = 0, Steer = 0, Handbrake = false, Clutch = 0 }
    VehicleController.setTestInputProvider(function()
        return table.clone(phase) :: any
    end)
    VehicleController.invokeActionForTest("AWVehicleShiftUp") -- boîte séquentielle au neutre
    phase.Steer = 1
    task.wait(1.5)
    phase.Steer, phase.Throttle = 0, 0.6
    task.wait(2.5)
    phase.Throttle, phase.Brake = 0, 1
    task.wait(1.5)
    phase.Brake, phase.Handbrake = 0, true
    task.wait(1.5)
    VehicleController.setTestInputProvider(nil)
    local detail = string.format(
        "rapport %s ; position z %.1f",
        tostring(VehicleController.getTestSnapshot().Gear),
        (root :: BasePart).Position.Z
    )
    record("comete2.conducteur.demonstration", true, detail)
    return { Detail = detail }
end

-- Session « comete2 », joueur 2 : ce que ce client reçoit du véhicule du joueur 1.
handlers.observe = function(_id, data)
    local model, driver = data.Model, data.Driver
    if typeof(model) ~= "Instance" or typeof(driver) ~= "Instance" then
        record("comete2.observateur.vehicule_recu", false)
        return { Detail = "véhicule absent" }
    end
    local car = model :: Model
    local root = car.PrimaryPart :: BasePart
    local meshes = 0
    for _, item in car:GetDescendants() do
        if item:IsA("MeshPart") then
            meshes += 1
        end
    end
    local wheel = car:FindFirstChild("WheelFL")
    local rim = wheel and wheel:FindFirstChild(KIT.Wheels.FL[2]) :: BasePart?
    local tyre = wheel and wheel:FindFirstChild(KIT.Wheels.FL[1]) :: BasePart?
    local spin, maxSteer, maxYaw, braked, moved = 0, 0, 0, false, 0
    local start = root.Position
    local previous = if rim then root.CFrame:VectorToObjectSpace(rim.CFrame.UpVector) else nil
    local yaw0 = if tyre then root.CFrame:VectorToObjectSpace(tyre.CFrame.RightVector) else nil
    local connection = RunService.Heartbeat:Connect(function()
        if rim and previous then
            local now = root.CFrame:VectorToObjectSpace(rim.CFrame.UpVector)
            spin += math.deg(math.acos(math.clamp(previous:Dot(now), -1, 1)))
            previous = now
        end
        if tyre and yaw0 then
            local right = root.CFrame:VectorToObjectSpace(tyre.CFrame.RightVector)
            maxYaw = math.max(maxYaw, math.deg(math.acos(math.clamp(right:Dot(yaw0), -1, 1))))
        end
        maxSteer = math.max(maxSteer, math.abs(tonumber(car:GetAttribute(Constants.Attributes.VisualSteer)) or 0))
        braked = braked or car:GetAttribute(Constants.Attributes.VisualBrake) == true
        moved = math.max(moved, (root.Position - start).Magnitude)
    end)
    task.wait(tonumber(data.Seconds) or 9)
    connection:Disconnect()
    local other = (driver :: Player).Character
    local head = other and other:FindFirstChild("Head") :: BasePart?
    local headVisible = head ~= nil and head.Transparency < 1 and head.LocalTransparencyModifier < 1
    local view = CFrame.lookAt(
        (root.CFrame * CFrame.new(-9, 2.4, -1.4)).Position,
        (root.CFrame * CFrame.new(-1.2, 0.8, -1.45)).Position
    )
    withView(view, function()
        Gui.shot("comete2_vu_par_le_joueur_2", { joueur = 2 })
    end)
    record("comete2.observateur.maillages_recus", meshes == 28, meshes .. " / 28")
    record("comete2.observateur.jante_tourne", spin > 180, string.format("%.0f°", spin))
    record(
        "comete2.observateur.braquage_recu",
        maxSteer >= 0.5 and maxYaw > 5,
        string.format("attribut %.2f, pneu %.1f°", maxSteer, maxYaw)
    )
    record("comete2.observateur.feux_stop_recus", braked)
    record(
        "comete2.observateur.conducteur_visible",
        headVisible,
        if head
            then string.format("tête %.2f / %.2f", head.Transparency, head.LocalTransparencyModifier)
            else "tête absente"
    )
    local detail = string.format(
        "maillages %d ; jante %.0f° ; braquage %.2f (pneu %.1f°) ; stop %s ; déplacement %.1f st ; tête visible %s",
        meshes,
        spin,
        maxSteer,
        maxYaw,
        tostring(braked),
        moved,
        tostring(headVisible)
    )
    return { Detail = detail }
end

handlers.exit = function(_id, data)
    local h = humanoid()
    Gui.key(tostring(data.Key))
    local out = waitFor(function()
        return h == nil or h.SeatPart == nil
    end, 5)
    record("comete.client.sortie_" .. tostring(data.Key), out)
    task.wait(1)
    return true
end

-- QA-K07 : nuit imposée par le serveur ; sources allumées et vitrage vus par ce client.
handlers.night = function(_id, data)
    local model = data.Model
    if typeof(model) ~= "Instance" then
        return { Detail = "véhicule absent" }
    end
    task.wait(1.5) -- passage de VehicleLights (0,5 s)
    local sources, enabled, glassOk, glass, brokenLit = 0, 0, 0, 0, 0
    for _, item in model:GetDescendants() do
        if item:IsA("BasePart") and item:GetAttribute("AWLight") ~= nil then
            local light = item:FindFirstChild("Lumiere")
            if light and light:IsA("Light") then
                sources += 1
                enabled += if light.Enabled then 1 else 0
                if item:GetAttribute("AWLightBroken") == true and light.Enabled then
                    brokenLit += 1
                end
            end
        elseif item:IsA("MeshPart") and string.find(string.lower(item.Name), KIT.GlassPattern, 1, true) then
            glass += 1
            glassOk += if item.Transparency >= 0.3 then 1 else 0
        end
    end
    local detail = string.format(
        "sources allumées %d / %d (cassées allumées %d) ; vitrage transparent %d / %d",
        enabled,
        sources,
        brokenLit,
        glassOk,
        glass
    )
    record("comete.k07.vitrage_transparent_client", glass >= 1 and glassOk == glass, detail)
    return { Detail = detail, Sources = sources, Enabled = enabled, BrokenLit = brokenLit }
end

-- QA-K08 : temps d'image (RenderStepped) pendant `Seconds`, cadrage fixe.
handlers.frames = function(_id, data)
    local c = data.Cadrage
    local frames: { number } = {}
    local cpu, gpu, draws, tris, samples = 0, 0, 0, 0, 0
    local Stats = game:GetService("Stats")
    local function measure()
        local connection = RunService.RenderStepped:Connect(function(dt)
            table.insert(frames, dt * 1000)
            -- Temps de rendu propres à l'image (indépendants du plafond de 60 images/s), lecture protégée.
            pcall(function()
                cpu += Stats.RenderCPUFrameTime
                gpu += Stats.RenderGPUFrameTime
                draws += Stats.SceneDrawcallCount
                tris += Stats.SceneTriangleCount
                samples += 1
            end)
        end)
        task.wait(tonumber(data.Seconds) or 8)
        connection:Disconnect()
    end
    if type(c) == "table" and #c == 12 then
        withView(CFrame.new(table.unpack(c)), measure)
    else
        measure()
    end
    table.sort(frames)
    local total = 0
    for _, v in frames do
        total += v
    end
    local mean = if #frames > 0 then total / #frames else nil
    local p95 = frames[math.max(1, math.ceil(#frames * 0.95))]
    return {
        Mean = if mean then math.floor(mean * 100) / 100 else nil,
        P95 = if p95 then math.floor(p95 * 100) / 100 else nil,
        Frames = #frames,
        Cpu = if samples > 0 then math.floor(cpu / samples * 1000) / 1000 else nil,
        Gpu = if samples > 0 then math.floor(gpu / samples * 1000) / 1000 else nil,
        Draws = if samples > 0 then math.floor(draws / samples) else nil,
        Tris = if samples > 0 then math.floor(tris / samples) else nil,
    }
end

local finished = false
handlers.finish = function()
    finished = true
    return true
end

-- File des demandes du serveur, traitées dans l'ordre ; accusé avec les mesures du traitement.
local queue: { { any } } = {}
askEvent.OnClientEvent:Connect(function(id, data)
    table.insert(queue, { id, data })
end)
while not finished and os.clock() - sessionStart < 1500 do
    local item = table.remove(queue, 1)
    if item == nil then
        task.wait(0.1)
        continue
    end
    local id = item[1] :: string
    local kind = string.match(id, "^([^:]+)") or id
    local handler = handlers[kind]
    local result: any = true
    if handler then
        local ok, value = pcall(handler, id, item[2] or {})
        if ok then
            result = if value == nil then true else value
        else
            record("comete.client.execution_" .. kind, false, value)
            trace("erreur " .. kind .. " : " .. tostring(value))
        end
    end
    signalEvent:FireServer("AWCO:" .. id, result)
end

local shots = Gui.report().shots
-- Session perf : aucune capture ; session à 2 joueurs : seul l'observateur capture.
if cometeSession ~= "comete_perf" and (cometeSession ~= "comete2" or #shots > 0) then
    record("comete.client.captures", #shots > 0, #shots)
end
reportEvent:FireServer({ vehicle = "comete", steps = steps, measures = { captures = #shots } })
