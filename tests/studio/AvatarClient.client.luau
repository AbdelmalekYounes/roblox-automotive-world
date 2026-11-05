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
if
    session ~= "avatar"
    and session ~= "avatar2"
    and session ~= "aster"
    and session ~= "silhouette"
    and session ~= "silhouette2"
then
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

-- ======================== Session « silhouette2 » ========================
-- Le client du joueur 2 mesure les pièces du corps du joueur 1 à chaque changement et les compare
-- aux tailles vues par le serveur (attribut `AWSil2Sizes`) : réplication du corps et de la tête.

if session == "silhouette2" then
    waitFor(function()
        return #Players:GetPlayers() >= 2
    end, 90)
    local all = Players:GetPlayers()
    table.sort(all, function(a, b)
        return a.UserId < b.UserId
    end)
    local holder = all[1]
    if holder == player then
        record("silhouette2.porteur.role", true, "joueur 1 (changements appelés par le serveur de test)")
        waitFor(function()
            return ReplicatedStorage:GetAttribute("AWSil2Phase") == "fin"
        end, 400)
        reportEvent:FireServer({ vehicle = "silhouette2", steps = steps, measures = measures })
        return
    end
    local PARTS = { "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftUpperLeg" }
    local function parse(text: string): { [string]: Vector3 }
        local out = {}
        for name, x, y, z in string.gmatch(text, "(%w+)=([%d%.]+),([%d%.]+),([%d%.]+)") do
            out[name] = Vector3.new(tonumber(x) :: number, tonumber(y) :: number, tonumber(z) :: number)
        end
        return out
    end
    local seen: { [string]: boolean } = {}
    local previous: { [string]: Vector3 }? = nil
    local deadline = os.clock() + 400
    while os.clock() < deadline do
        local phase = ReplicatedStorage:GetAttribute("AWSil2Phase")
        if phase == "fin" then
            break
        end
        if type(phase) == "string" and not seen[phase] then
            seen[phase] = true
            task.wait(2) -- réplication
            local expected = parse(tostring(ReplicatedStorage:GetAttribute("AWSil2Sizes")))
            local model = holder.Character
            local worst, missing = 0, 0
            local mine: { [string]: Vector3 } = {}
            for _, name in PARTS do
                local part = model and model:FindFirstChild(name)
                local want = expected[name]
                if part and part:IsA("BasePart") and want then
                    mine[name] = part.Size
                    worst = math.max(worst, (part.Size - want).Magnitude)
                else
                    missing += 1
                end
            end
            local changed = "—"
            if previous then
                local delta = 0
                for name, size in mine do
                    local old = (previous :: { [string]: Vector3 })[name]
                    if old then
                        delta = math.max(delta, (size - old).Magnitude)
                    end
                end
                changed = string.format("%.3f st", delta)
            end
            previous = mine
            record(
                "silhouette2.observateur." .. phase .. "_corps_vu_comme_le_serveur",
                missing == 0 and worst < 0.02,
                string.format(
                    "corps %s ; écart max %.3f st ; pièces absentes %d ; variation depuis la phase précédente %s",
                    tostring(ReplicatedStorage:GetAttribute("AWSil2Body")),
                    worst,
                    missing,
                    changed
                )
            )
        end
        task.wait(0.2)
    end
    reportEvent:FireServer({ vehicle = "silhouette2", steps = steps, measures = measures })
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
    -- Diagnostic (passages 20261104-162124 et -164354 : touches de l'étalonnage jamais reçues
    -- depuis le remplacement des têtes classiques) : focus, sélection, état du personnage.
    local function focusInfo(): string
        local UserInputService = game:GetService("UserInputService")
        local GuiService = game:GetService("GuiService")
        local box = UserInputService:GetFocusedTextBox()
        local selected = GuiService.SelectedObject
        local me = Players.LocalPlayer.Character
        local humanoid = me and me:FindFirstChildOfClass("Humanoid")
        local root = me and me:FindFirstChild("HumanoidRootPart")
        local guis = {}
        for _, item in playerGui:GetChildren() do
            if item:IsA("ScreenGui") and item.Enabled then
                table.insert(guis, item.Name)
            end
        end
        return string.format(
            "champ %s ; sélection %s ; souris %s ; humanoïde %s (vitesse %s, assis %s, état %s) ; racine ancrée %s ; interfaces %s",
            if box then box:GetFullName() else "aucun",
            if selected then selected:GetFullName() else "aucune",
            UserInputService.MouseBehavior.Name,
            if humanoid then "présent" else "absent",
            if humanoid then tostring(humanoid.WalkSpeed) else "?",
            if humanoid then tostring(humanoid.Sit) else "?",
            if humanoid then humanoid:GetState().Name else "?",
            if root and root:IsA("BasePart") then tostring(root.Anchored) else "?",
            table.concat(guis, ",")
        )
    end
    record("avatar.client.info_focus_avant_clavier", true, focusInfo())
    local keys, keysDetail = Gui.calibrateKeys(3)
    record("avatar.client.clavier_etalonne", keys, keysDetail)
    if not keys then
        record("avatar.client.info_focus_apres_echec", true, focusInfo())
    end
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
    -- QA-A20 (clôture de la phase 1) : angle de départ relevé deux fois. (1) Comme avant, 0,6 s
    -- après la marche, avec les pistes d'animation en cours ; (2) personnage arrêté, sans piste de
    -- marche ni de course. Le contrôle utilise (2) ; (1) sert à établir la cause des échecs.
    local function movingTracks(): { string }
        local names = {}
        for _, track in if animator then animator:GetPlayingAnimationTracks() else {} do
            local lower = string.lower(track.Name)
            if string.find(lower, "walk", 1, true) or string.find(lower, "run", 1, true) then
                table.insert(names, string.format("%s %.2f", track.Name, track.WeightCurrent))
            end
        end
        return names
    end
    local function allTracks(): string
        local names = {}
        for _, track in if animator then animator:GetPlayingAnimationTracks() else {} do
            local animation = track.Animation
            local id = if animation then string.match(animation.AnimationId, "%d+$") or "?" else "?"
            table.insert(names, string.format("%s#%s %.2f", track.Name, id, track.WeightCurrent))
        end
        return if #names == 0 then "aucune" else table.concat(names, ", ")
    end
    local early = armAngle(model)
    local earlyTracks = allTracks()
    local earlySpeed = root.AssemblyLinearVelocity.Magnitude
    local raisedAttr = tostring(model:GetAttribute("AWPhoneRaised"))
    local settleStart = os.clock()
    local settled = waitFor(function()
        return root.AssemblyLinearVelocity.Magnitude < 0.3 and #movingTracks() == 0
    end, 4)
    -- Bras revenu au repos (< 15°) : une variante de l'animation d'attente peut le déplacer.
    local rested = waitFor(function()
        local angle = armAngle(model)
        return angle ~= nil and angle < 15
    end, 4)
    task.wait(0.3)
    local before = armAngle(model)
    record(
        "avatar.client." .. morph .. ".info_bras_depart",
        true,
        string.format(
            "0,6 s après la marche : %.0f° (vitesse %.2f st/s ; AWPhoneRaised %s ; pistes : %s) ; arrêté %s, repos %s après %.1f s : %.0f°",
            early or -1,
            earlySpeed,
            raisedAttr,
            earlyTracks,
            if settled then "oui" else "non",
            if rested then "oui" else "non",
            os.clock() - settleStart,
            before or -1
        )
    )
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

-- ======================== Session « aster » : mesures côté client ========================
-- La pose du jeu est appliquée par ce client (Transform) : seules ses propres mesures la voient.

local asterRows: { { [string]: any } } = {}
local asterExpected = 0 -- morphologies annoncées par le serveur

local function corners(part: BasePart, frame: CFrame): (Vector3, Vector3)
    local half = part.Size / 2
    local minV, maxV = Vector3.one * math.huge, -Vector3.one * math.huge
    for _, sx in { -1, 1 } do
        for _, sy in { -1, 1 } do
            for _, sz in { -1, 1 } do
                local c = frame:PointToObjectSpace((part.CFrame * CFrame.new(half * Vector3.new(sx, sy, sz))).Position)
                minV = minV:Min(c)
                maxV = maxV:Max(c)
            end
        end
    end
    return minV, maxV
end

local function overlap(aMin: Vector3, aMax: Vector3, bMin: Vector3, bMax: Vector3): number
    local d = Vector3.new(
        math.min(aMax.X, bMax.X) - math.max(aMin.X, bMin.X),
        math.min(aMax.Y, bMax.Y) - math.max(aMin.Y, bMin.Y),
        math.min(aMax.Z, bMax.Z) - math.max(aMin.Z, bMin.Z)
    )
    if d.X <= 0 or d.Y <= 0 or d.Z <= 0 then
        return 0
    end
    return math.min(d.X, d.Y, d.Z)
end

local LEG_PARTS = {
    LeftUpperLeg = true,
    LeftLowerLeg = true,
    LeftFoot = true,
    RightUpperLeg = true,
    RightLowerLeg = true,
    RightFoot = true,
}

handlers.astermeasure = function(_id, data)
    if type(data.Morphs) == "number" then
        asterExpected = data.Morphs
    end
    local model = Workspace:FindFirstChild("MaquetteAster") :: Model?
    local me = character()
    if model == nil then
        record("aster.client.maquette_presente", false)
        return
    end
    task.wait(0.3)
    -- Repère du gabarit (attribut du serveur), pas le pivot : celui-ci suit le plancher.
    local origin = model:GetAttribute("AWAsterOrigin")
    local frame = if typeof(origin) == "CFrame" then origin else model:GetPivot()
    local seat = model:FindFirstChild(tostring(data.Seat)) :: BasePart
    local seatTop = frame:PointToObjectSpace((seat.CFrame * CFrame.new(0, seat.Size.Y / 2, 0)).Position).Y
    local seatX = frame:PointToObjectSpace(seat.Position).X
    local row: { [string]: any } = { Morph = data.Morph, Pose = data.Pose, Seat = data.Seat, SeatTop = seatTop }
    local bodyTop, allTop, sideMax = -math.huge, -math.huge, 0
    local legs = {}
    for _, part in me:GetDescendants() do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local minV, maxV = corners(part, frame)
            allTop = math.max(allTop, maxV.Y)
            local accessory = part:FindFirstAncestorOfClass("Accessory")
            if accessory == nil then
                bodyTop = math.max(bodyTop, maxV.Y)
            end
            if accessory == nil or accessory:GetAttribute("AWTestProp") == nil then
                -- Écart latéral mesuré depuis l'axe du siège occupé, vers la portière.
                sideMax = math.max(sideMax, math.abs(minV.X - seatX), math.abs(maxV.X - seatX))
            end
            if LEG_PARTS[part.Name] then
                table.insert(legs, { minV, maxV, part.Name })
            end
            if part.Name == "LeftFoot" or part.Name == "RightFoot" then
                row[part.Name .. "MinZ"] = minV.Z
                row[part.Name .. "MinY"] = minV.Y
            elseif part.Name == "LeftHand" or part.Name == "RightHand" or part.Name == "Head" then
                local center = frame:PointToObjectSpace(part.Position)
                row[part.Name] = { center.X, center.Y, center.Z }
            elseif part.Name == "LowerTorso" then
                row.PelvisBottom = minV.Y
            elseif part.Name == "LeftLowerLeg" then
                row.KneeTop = maxV.Y
            end
        end
    end
    local roof = model:FindFirstChild("Toit") :: BasePart
    local roofMin = corners(roof, frame)
    local door =
        model:FindFirstChild(if data.Seat == "SiegeConducteur" then "PortiereGauche" else "PortiereDroite") :: BasePart
    local dMin, dMax = corners(door, frame)
    local doorInner = if data.Seat == "SiegeConducteur" then dMax.X else dMin.X
    row.HeadAboveSeat = bodyTop - seatTop
    row.HairAboveSeat = allTop - seatTop
    row.RoofMarginBody = roofMin.Y - bodyTop
    row.RoofMargin = roofMin.Y - allTop
    row.DoorRoom = math.abs(doorInner - seatX)
    row.SideReach = sideMax
    row.SideMargin = row.DoorRoom - sideMax
    local worst, pair = 0, ""
    for _, name in { "PlancheDeBord", "Volant", "Pedalier" } do
        local item = model:FindFirstChild(name) :: BasePart?
        if item then
            local bMin, bMax = corners(item, frame)
            for _, leg in legs do
                local depth = overlap(leg[1], leg[2], bMin, bMax)
                if depth > worst then
                    worst, pair = depth, leg[3] .. "/" .. name
                end
            end
        end
    end
    row.InteriorOverlap = worst
    row.InteriorPair = pair
    -- Clôture de la phase 1 : pieds au-dessus du dessus du plancher (absent du contrôle des jambes).
    local floorPart = model:FindFirstChild("Plancher") :: BasePart?
    if floorPart then
        local _, floorMax = corners(floorPart, frame)
        local lowest = math.min(row.LeftFootMinY or math.huge, row.RightFootMinY or math.huge)
        row.FeetAboveFloor = lowest - floorMax.Y
    end
    local wheel = model:FindFirstChild("Volant") :: BasePart?
    if wheel and row.LeftHand and row.RightHand then
        local radius = wheel.Size.Y / 2
        local axis = wheel.CFrame.RightVector -- axe du cylindre (X de la pièce)
        local function rim(hand: { number }): number
            local world = frame:PointToWorldSpace(Vector3.new(hand[1], hand[2], hand[3]))
            local d = world - wheel.Position
            local axial = d:Dot(axis)
            local radial = (d - axis * axial).Magnitude
            return math.sqrt(axial ^ 2 + (radial - radius) ^ 2)
        end
        row.HandsToRim = math.max(rim(row.LeftHand), rim(row.RightHand))
        -- Vue dégagée : yeux (centre de la tête + 0,15 st) au-dessus du haut du volant.
        local _, wheelMax = corners(wheel, frame)
        if row.Head then
            row.EyeAboveWheel = row.Head[2] + 0.15 - wheelMax.Y
        end
    end
    table.insert(asterRows, row)
    print("@@AWASTER@@ " .. game:GetService("HttpService"):JSONEncode(row))
end

-- Vue du conducteur depuis sa tête (pose du jeu), vers l'avant de la maquette.
handlers.asterpov = function(_id, data)
    local model = Workspace:FindFirstChild("MaquetteAster") :: Model?
    local head = character():FindFirstChild("Head") :: BasePart?
    if model == nil or head == nil then
        return
    end
    -- Repère du gabarit (attribut du serveur), pas le pivot : celui-ci suit le plancher.
    local origin = model:GetAttribute("AWAsterOrigin")
    local frame = if typeof(origin) == "CFrame" then origin else model:GetPivot()
    local eye = head.Position + Vector3.new(0, 0.15, 0)
    withView(CFrame.lookAt(eye, eye + frame.LookVector * 10 - Vector3.new(0, 1.2, 0)), function()
        Gui.shot(tostring(data.Name), { pose = "jeu" })
    end)
end

-- Session « silhouette » : vrais clics dans le panneau d'apparition et dans le téléphone.
handlers.silpanel = function(_id, data)
    local key = tostring(data.Key)
    local panel: Instance? = nil
    local shown = waitFor(function()
        panel = playerGui:FindFirstChild("AWBodyChoice")
        return panel ~= nil
    end, 15)
    record("silhouette.client.panneau_affiche_a_l_apparition", shown)
    local button = Gui.findButton(panel, tostring(data.Label))
    local ok, detail = Gui.click(button, "Silhouette " .. tostring(data.Label))
    record("silhouette.client.clic_" .. key, ok, detail)
    local closed = waitFor(function()
        return playerGui:FindFirstChild("AWBodyChoice") == nil
    end, 20)
    record("silhouette.client.panneau_ferme_apres_choix", closed)
end

handlers.silphone = function(_id, data)
    local expect = tostring(data.Expect)
    Gui.key("T")
    local opened = waitFor(phoneShown, 5)
    record("silhouette.client.telephone_ouvert", opened)
    local phone = playerGui:FindFirstChild("AWPhone")
    -- Bouton cherché aussi hors de la zone visible (liste défilante du téléphone), amené dans la
    -- vue par la molette, puis cliqué. Le téléphone redessine la page au clic (bouton détruit) :
    -- l'accusé « Activated » peut manquer ; l'EFFET du clic est contrôlé par l'étape suivante.
    local function find(label: string): GuiButton?
        local wanted = string.lower(label)
        for _, item in (phone or playerGui):GetDescendants() do
            if item:IsA("TextButton") and string.find(string.lower(item.Text), wanted, 1, true) then
                return item
            end
        end
        return nil
    end
    local function press(label: string)
        local button: GuiButton? = nil
        waitFor(function()
            button = find(label)
            return button ~= nil
        end, 5)
        local revealed = Gui.reveal(button, 15)
        local ok, detail = Gui.click(button, label)
        record(
            "silhouette.client.info_telephone_clic_" .. string.lower((string.gsub(label, "%W", ""))),
            true,
            string.format("%s ; dans la vue : %s ; accusé : %s", detail, tostring(revealed), tostring(ok))
        )
        task.wait(0.8)
    end
    press("Paramètres")
    record("silhouette.client.telephone_page_parametres", find("Interface") ~= nil)
    press("Interface")
    record("silhouette.client.telephone_bouton_silhouette_present", find("Silhouette") ~= nil)
    press("Silhouette")
    local applied = waitFor(function()
        return player:GetAttribute("AWAvatarBody") == expect
    end, 25)
    task.wait(1)
    local button = find("Silhouette")
    local text = if button then (button :: any).Text else "?"
    record("silhouette.client.telephone_silhouette_" .. string.lower(expect), applied, "bouton : " .. tostring(text))
    Gui.key("T")
    waitFor(function()
        return not phoneShown()
    end, 4)
    task.wait(0.5)
end

handlers.silcheck = function(_id, data)
    task.wait(2)
    record(
        "silhouette.client.panneau_absent_" .. tostring(data.Key),
        playerGui:FindFirstChild("AWBodyChoice") == nil,
        "choix déjà fait dans la session"
    )
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
record(tostring(session) .. ".client.captures", #shots > 0, #shots)
if session == "aster" then
    -- Synthèse compacte : pose du jeu contre pose standard, par place (détail dans @@AWASTER@@).
    for _, pose in { "standard", "jeu" } do
        for _, seatName in { "SiegeConducteur", "SiegePassager" } do
            local roofFail, sideFail, legFail, rimFail, viewFail, floorFail, n = {}, {}, {}, {}, {}, {}, 0
            for _, row in asterRows do
                if row.Pose == pose and row.Seat == seatName then
                    n += 1
                    if row.RoofMarginBody < 0 then
                        table.insert(roofFail, string.format("%s %.2f", row.Morph, row.RoofMarginBody))
                    end
                    if row.SideMargin < 0 then
                        table.insert(sideFail, string.format("%s %.2f", row.Morph, row.SideMargin))
                    end
                    if row.InteriorOverlap > 0.1 then
                        table.insert(legFail, string.format("%s %.2f", row.Morph, row.InteriorOverlap))
                    end
                    if row.HandsToRim and row.HandsToRim > 0.35 then
                        table.insert(rimFail, string.format("%s %.2f", row.Morph, row.HandsToRim))
                    end
                    if row.FeetAboveFloor and row.FeetAboveFloor < -0.05 then
                        table.insert(floorFail, string.format("%s %.2f", row.Morph, row.FeetAboveFloor))
                    end
                    if row.EyeAboveWheel and row.EyeAboveWheel < 0 then
                        table.insert(viewFail, string.format("%s %.2f", row.Morph, row.EyeAboveWheel))
                    end
                end
            end
            local prefix = string.format("aster.%s.%s.", pose, seatName)
            record(
                prefix .. "mesures",
                n > 0 and n == asterExpected,
                string.format("%d / %d morphologie(s)", n, asterExpected)
            )
            record(prefix .. "tete_sous_le_pavillon", #roofFail == 0, table.concat(roofFail, " / "))
            record(prefix .. "bras_dans_l_habitacle", #sideFail == 0, table.concat(sideFail, " / "))
            record(prefix .. "jambes_libres", #legFail == 0, table.concat(legFail, " / "))
            record(prefix .. "pieds_au_dessus_du_plancher", #floorFail == 0, table.concat(floorFail, " / "))
            if pose == "jeu" and seatName == "SiegeConducteur" then
                record(prefix .. "mains_sur_la_jante", #rimFail == 0, table.concat(rimFail, " / "))
                -- Décision du propriétaire (2026-11-04) : critère informatif (la vue de conduite passe par
                -- `CameraCockpit`, point fixe du véhicule, avatar masqué ; règle des 10° vérifiée en Lune).
                record(
                    prefix .. "info_yeux_de_l_avatar_au_dessus_du_volant",
                    true,
                    if #viewFail == 0 then "toutes les morphologies" else table.concat(viewFail, " / ")
                )
            end
        end
    end
end
measures.captures = #shots
reportEvent:FireServer({ vehicle = "avatar", steps = steps, measures = measures })
