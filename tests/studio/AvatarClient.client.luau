-- Essais CLIENT du lot AVATAR-01 (place de développement).
--   « avatar »  : répond aux demandes du serveur de test (AWAvatarAsk) : étalonnage des
--                 vraies entrées, demandes de tenue par le canal du jeu, marche (vraie
--                 touche W) et téléphone (vraie touche T) pour chaque morphologie, captures
--                 cadrées par le serveur, vue cockpit (vraie touche V : personnage et
--                 accessoires masqués localement), sorties (vraies touches F et Espace).
--   « avatar2 » : deux clients ; le joueur 1 sort son téléphone (canal du jeu, instrumenté),
--                 le joueur 2 mesure le bras levé et le téléphone du joueur 1 tels qu'il
--                 les voit (QA-A10 vue par un autre joueur).
-- Instrumenté (signalé) : caméra placée par script pour les captures ; morphologies et
-- placements décidés par le serveur de test.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local sessionStart = os.clock()
while ReplicatedStorage:GetAttribute("AWTestSession") == nil and os.clock() - sessionStart < 15 do
    task.wait()
end
local session = ReplicatedStorage:GetAttribute("AWTestSession")
if session ~= "avatar" and session ~= "avatar2" then
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
    print(string.format("[AW_Test] %s client %.1f s : %s", tostring(session), os.clock() - sessionStart, message))
end

local reportEvent = ReplicatedStorage:WaitForChild("AWTestReport", 30) :: RemoteEvent
local signalEvent = ReplicatedStorage:WaitForChild("AWTestSignal", 30) :: RemoteEvent
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared:WaitForChild("UI"):WaitForChild("Localization")) :: any
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local camera = Workspace.CurrentCamera :: Camera

local function character(): Model
    return player.Character or player.CharacterAdded:Wait()
end

-- Bras droit par rapport au tronc (0° : le long du corps), d'un personnage quelconque.
local function armAngle(model: Model): number?
    local upper = model:FindFirstChild("RightUpperArm")
    local root = model:FindFirstChild("HumanoidRootPart")
    if upper == nil or root == nil or not upper:IsA("BasePart") or not root:IsA("BasePart") then
        return nil
    end
    local down = -upper.CFrame.UpVector
    local bodyDown = -root.CFrame.UpVector
    return math.deg(math.acos(math.clamp(down:Dot(bodyDown), -1, 1)))
end

-- Téléphone : distance à la main et position devant (+) / derrière (−) le personnage.
local function phonePlacement(model: Model): (number?, number?)
    local phone = model:FindFirstChild("TelephoneAW")
    local body = phone and (phone :: Model).PrimaryPart
    local hand = model:FindFirstChild("RightHand")
    local root = model:FindFirstChild("HumanoidRootPart")
    if body == nil or hand == nil or root == nil or not hand:IsA("BasePart") or not root:IsA("BasePart") then
        return nil, nil
    end
    local front = -root.CFrame:PointToObjectSpace(body.Position).Z
    return (body.Position - hand.Position).Magnitude, front
end

local function phoneShown(): boolean
    local gui = playerGui:FindFirstChild("AWPhone") :: ScreenGui?
    return gui ~= nil and gui.Enabled
end

-- ======================== Session « avatar2 » ========================

if session == "avatar2" then
    waitFor(function()
        return #Players:GetPlayers() >= 2
    end, 60)
    task.wait(6)
    local others = {}
    for _, other in Players:GetPlayers() do
        if other ~= player then
            table.insert(others, other)
        end
    end
    -- Rôles : le plus petit identifiant sort son téléphone, l'autre observe.
    local all = Players:GetPlayers()
    table.sort(all, function(a, b)
        return a.UserId < b.UserId
    end)
    local holder = all[1]
    if holder == player then
        local folder = ReplicatedStorage:WaitForChild("AWInterface", 20)
        local request = folder and folder:WaitForChild("Request", 10) :: RemoteFunction?
        local reply = if request then request:InvokeServer("Phone", { Out = true }) else nil
        record(
            "avatar2.porteur.telephone_sorti",
            type(reply) == "table" and reply.Status == "Ok",
            reply and reply.Status
        )
        task.wait(25) -- laisse l'observateur mesurer
        if request then
            request:InvokeServer("Phone", { Out = false })
        end
    else
        local other = holder
        local model = other.Character
        local seen = waitFor(function()
            return model ~= nil and model:FindFirstChild("TelephoneAW") ~= nil
        end, 20)
        record("avatar2.observateur.telephone_du_porteur_visible", seen)
        task.wait(1.5) -- montée progressive du bras (0,25 s) et animation
        local angle = if model then armAngle(model) else nil
        local toHand, front = nil, nil
        if model then
            toHand, front = phonePlacement(model)
        end
        record(
            "avatar2.observateur.bras_du_porteur_leve",
            angle ~= nil and (angle :: number) >= 30,
            string.format("bras à %.0f° du tronc (vu par l'autre joueur)", angle or -1)
        )
        record(
            "avatar2.observateur.telephone_dans_la_main_du_porteur",
            toHand ~= nil and (toHand :: number) < 1.5 and (front or -1) > 0.3,
            string.format("à %.2f st de la main, %.2f st devant", toHand or -1, front or -1)
        )
        measures.observateur_angle_bras = angle
    end
    reportEvent:FireServer({ vehicle = "avatar2", steps = steps, measures = measures })
    return
end

-- ======================== Session « avatar » ========================

local signal = function(id: string)
    signalEvent:FireServer("AWAV:" .. id)
end
local Gui = require(ReplicatedStorage:WaitForChild("AW_TestGui", 30)) :: any
local askEvent = ReplicatedStorage:WaitForChild("AWAvatarAsk", 30) :: RemoteEvent

-- Caméra imposée pour une capture. Au volant, le contrôleur du véhicule replace la caméra
-- à chaque image (`PreRender`, tâche 20261104-104818 : captures extérieures restées en vue
-- capot) : cadrage réimposé à chaque étape de rendu et à chaque changement.
local function withView(view: CFrame, fn: () -> ())
    RunService:BindToRenderStep("AWAvatarShot", Enum.RenderPriority.Last.Value + 10, function()
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
    task.wait(0.5)
    fn()
    changed:Disconnect()
    preRender:Disconnect()
    RunService:UnbindFromRenderStep("AWAvatarShot")
end

local function visibleParts(model: Model): (number, { string })
    local visible, names = 0, {}
    for _, item in model:GetDescendants() do
        if (item:IsA("BasePart") or item:IsA("Decal")) and (item :: any).Transparency < 1 then
            if (item :: any).LocalTransparencyModifier < 1 then
                visible += 1
                if #names < 4 then
                    table.insert(names, item.Name)
                end
            end
        end
    end
    return visible, names
end

local handlers: { [string]: (string, any) -> () } = {}

handlers.calibrate = function()
    local calibrated = Gui.calibrate(3)
    record("avatar.client.entrees_reelles", calibrated)
    local keys = Gui.calibrateKeys()
    record("avatar.client.clavier_etalonne", keys)
    -- Fenêtre d'arrivée (profil neuf) : « Passer l'introduction » par un vrai clic.
    local onboarding = playerGui:FindFirstChild("AWOnboarding")
    local skip = nil
    waitFor(function()
        skip = Gui.findButton(onboarding, "Passer l'introduction")
        return skip ~= nil
    end, 10)
    if skip then
        record("avatar.client.arrivee_passee_par_clic", (Gui.click(skip, "Passer l'introduction")))
        task.wait(1.5)
        Gui.key("P")
        task.wait(0.8)
        Gui.key("P")
        task.wait(0.8)
    end
end

-- Demandes de tenue par le canal du jeu (le client ne peut désigner qu'une tenue du catalogue).
handlers.outfits = function()
    local folder = ReplicatedStorage:WaitForChild("AWAvatar", 10)
    local request = folder and folder:WaitForChild("Request", 10) :: RemoteFunction?
    if request == nil then
        record("avatar.client.tenue_canal_present", false)
        return
    end
    local function invoke(action: string, payload: any): any
        local ok, reply = pcall(function()
            return request:InvokeServer(action, payload)
        end)
        task.wait(0.3)
        return if ok then reply else { Status = "Erreur", Reason = tostring(reply) }
    end
    local catalog = invoke("OutfitCatalog", nil)
    local outfits = if type(catalog) == "table" and type(catalog.Outfits) == "table" then catalog.Outfits else {}
    local placeholders = 0
    for _, outfit in outfits do
        if outfit.Status == "Placeholder" then
            placeholders += 1
        end
    end
    record(
        "avatar.client.tenue_catalogue_cinq_emplacements",
        #outfits == 5 and placeholders == 5,
        #outfits .. " / " .. placeholders
    )
    local notReady = invoke("OutfitEquip", { Id = "Mechanic.1" })
    record(
        "avatar.client.tenue_emplacement_non_disponible",
        notReady.Reason == "OutfitNotAvailable",
        tostring(notReady.Reason)
    )
    local unknown = invoke("OutfitPreview", { Id = "inexistante" })
    record("avatar.client.tenue_inconnue_refusee", unknown.Reason == "OutfitUnknown", tostring(unknown.Reason))
    local raw = invoke("OutfitEquip", { AssetId = 1 })
    record("avatar.client.identifiant_d_actif_du_client_ignore", raw.Reason == "OutfitUnknown", tostring(raw.Reason))
    task.wait(4) -- seau de demandes rempli
    local removed = invoke("OutfitRemove", { Slot = "Hat" })
    record(
        "avatar.client.retrait_emplacement",
        removed.Status == "Ok",
        tostring(removed.Status) .. " / " .. tostring(removed.Reason)
    )
    task.wait(4)
    local limited = false
    for _ = 1, 8 do
        local ok, reply = pcall(function()
            return request:InvokeServer("OutfitCatalog")
        end)
        if ok and type(reply) == "table" and reply.Reason == "RateLimited" then
            limited = true
        end
    end
    record("avatar.client.tenue_demandes_limitees", limited)
    local texts = {}
    local missing = 0
    for _, reason in { "OutfitNotAvailable", "OutfitUnknown", "OutfitAssetInvalid", "OutfitNotWhileSeated" } do
        for _, language in { "fr", "en" } do
            local text = Localization.t(reason, nil, language)
            if text == reason then
                missing += 1
            end
        end
        table.insert(texts, Localization.t(reason, nil, "en"))
    end
    record("avatar.client.tenue_messages_fr_en", missing == 0, table.concat(texts, " | "))
end

-- Morphologie appliquée, debout : marche (vraie touche W) et téléphone (vraie touche T).
handlers.standing = function(_id, data)
    local morph = tostring(data.Morph)
    local model = character()
    local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid?
    local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
    if humanoid == nil or root == nil then
        record("avatar.client." .. morph .. ".personnage", false)
        return
    end
    task.wait(1) -- personnage reconstruit et posé
    local start = root.Position
    Gui.keyDown("W")
    task.wait(0.9)
    local tracks = {}
    local animator = humanoid:FindFirstChildOfClass("Animator")
    for _, track in if animator then animator:GetPlayingAnimationTracks() else {} do
        table.insert(tracks, track.Name)
    end
    task.wait(0.6)
    Gui.keyUp("W")
    task.wait(0.6)
    local walked = (root.Position - start).Magnitude
    local animated = false
    for _, name in tracks do
        if string.find(string.lower(name), "walk", 1, true) or string.find(string.lower(name), "run", 1, true) then
            animated = true
        end
    end
    record("avatar.client." .. morph .. ".marche", walked > 3, string.format("%.1f st en 1,5 s", walked))
    record("avatar.client." .. morph .. ".animation_de_marche", animated, table.concat(tracks, ", "))
    local before = armAngle(model)
    Gui.key("T")
    local shown = waitFor(phoneShown, 4)
    task.wait(1.4)
    local after = armAngle(model)
    local toHand, front = phonePlacement(model)
    record(
        "avatar.client." .. morph .. ".telephone_bras_leve",
        shown and after ~= nil and before ~= nil and (after :: number) - (before :: number) >= 30,
        string.format("bras %.0f° → %.0f°", before or -1, after or -1)
    )
    record(
        "avatar.client." .. morph .. ".telephone_dans_la_main",
        toHand ~= nil and (toHand :: number) < 1.5 and (front or -1) > 0.3,
        string.format("à %.2f st de la main, %.2f st devant", toHand or -1, front or -1)
    )
    local view = CFrame.lookAt((root.CFrame * CFrame.new(3, 1.5, -7)).Position, root.Position + Vector3.new(0, 1, 0))
    withView(view, function()
        Gui.shot("debout_" .. morph .. "_telephone", { morphologie = data.Label })
    end)
    Gui.key("T")
    waitFor(function()
        return not phoneShown()
    end, 3)
    task.wait(0.5)
end

handlers.shot = function(_id, data)
    local context = table.clone(data.Context or {})
    local components = context.cadrage
    context.cadrage = nil
    if type(components) == "table" and #components == 12 then
        withView(CFrame.new(table.unpack(components)), function()
            Gui.shot(tostring(data.Name), context)
        end)
    end
end

-- Vue cockpit (vraie touche V jusqu'au point de vue du conducteur).
handlers.cockpit = function(_id, data)
    local model = character()
    local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid?
    local seat = humanoid and humanoid.SeatPart
    local vehicle = seat and seat.Parent
    local root = vehicle and (vehicle :: Model).PrimaryPart
    local eye = root and root:FindFirstChild("CameraCockpit") :: Attachment?
    local label = tostring(data.Vehicle) .. "_" .. tostring(data.Morph)
    if eye == nil then
        record("avatar.client.cockpit_" .. label, false, "point de vue absent")
        return
    end
    local reached = false
    for _ = 1, 5 do
        if (camera.CFrame.Position - (eye :: Attachment).WorldPosition).Magnitude < 1 then
            reached = true
            break
        end
        Gui.key("V")
        task.wait(0.8)
    end
    if not reached then
        record("avatar.client.cockpit_" .. label .. ".vue_atteinte", false, "touche V")
        return
    end
    task.wait(0.4)
    local visible, names = visibleParts(model)
    record(
        "avatar.client.cockpit_" .. label .. ".personnage_masque",
        visible == 0,
        string.format("%d pièce(s) visible(s) %s", visible, table.concat(names, ","))
    )
    Gui.shot("cockpit_" .. label, { vehicule = data.Vehicle, morphologie = data.Morph })
    -- Retour à la vue extérieure (le mode de caméra peut rester choisi d'un véhicule à l'autre).
    for _ = 1, 5 do
        if (camera.CFrame.Position - (eye :: Attachment).WorldPosition).Magnitude > 3 then
            break
        end
        Gui.key("V")
        task.wait(0.8)
    end
end

-- Téléphone en place passager (vraie touche T).
handlers.seatedphone = function(_id, data)
    local model = character()
    Gui.key("T")
    local shown = waitFor(phoneShown, 4)
    task.wait(1.4)
    local toHand = phonePlacement(model)
    record(
        string.format(
            "avatar.client.passager_%s_%s.telephone_dans_la_main",
            tostring(data.Vehicle),
            tostring(data.Morph)
        ),
        shown and toHand ~= nil and (toHand :: number) < 1.5,
        string.format("ouvert %s, à %.2f st de la main", tostring(shown), toHand or -1)
    )
    Gui.key("T")
    waitFor(function()
        return not phoneShown()
    end, 3)
end

-- Sortie par vraie touche (F : conducteur ; Espace : passager).
handlers.exit = function(_id, data)
    local humanoid = character():FindFirstChildOfClass("Humanoid") :: Humanoid?
    Gui.key(tostring(data.Key))
    waitFor(function()
        return humanoid == nil or humanoid.SeatPart == nil
    end, 4)
end

local finished = false
handlers.finish = function()
    finished = true
end

-- File des demandes du serveur, traitées dans l'ordre.
local queue: { { any } } = {}
askEvent.OnClientEvent:Connect(function(id, data)
    table.insert(queue, { id, data })
end)
while not finished and os.clock() - sessionStart < 3300 do
    local item = table.remove(queue, 1)
    if item == nil then
        task.wait(0.1)
        continue
    end
    local id = item[1] :: string
    local kind = string.match(id, "^([^:]+)") or id
    local handler = handlers[kind]
    if handler then
        local ok, err = pcall(handler, id, item[2] or {})
        if not ok then
            record("avatar.client.execution_" .. kind, false, err)
            trace("erreur " .. kind .. " : " .. tostring(err))
        end
    end
    signal(id)
end

-- Rapport compact (ligne de résultat tronquée par Studio au-delà de 100 000 caractères) :
-- captures comptées ; noms et contextes dans le dossier des captures.
local shots = Gui.report().shots
record("avatar.client.captures", #shots > 0, #shots)
measures.captures = #shots
reportEvent:FireServer({ vehicle = "avatar", steps = steps, measures = measures })
