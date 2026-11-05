--!strict
--[[
    Menu d'administration (lot ADMIN-01, décisions du propriétaire du 2026-11-05).

    Affiché SEULEMENT pour un joueur portant l'attribut AWAdmin (posé par le serveur) ; le serveur revérifie chaque
    demande (Server/Admin/AdminService). Touche F8 (clavier ; aucune touche manette). Style V1.2 (PanelKit).

    Onglets : Monde (heure, cycle, météo), Véhicule (apparition temporaire, réparation, remise sur roues,
    invulnérabilité), Personnage (no clip, vitesse, invisibilité, réapparition, téléportation), Joueurs (aller à,
    amener, crédits, expulsion), Profil (crédits, réputation, mission, course, réinitialisation), Diagnostic (surcouche
    FPS, ping, position, environnement), Journal (50 dernières actions). Confirmation pour les actions sensibles
    (AdminRules.Confirm). Textes traduits par Localization.tr (PanelTexts).
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AdminRules = require(Shared:WaitForChild("Admin"):WaitForChild("AdminRules"))
local Localization = require(Shared:WaitForChild("UI"):WaitForChild("Localization"))
local Tokens = require(Shared:WaitForChild("UI"):WaitForChild("DesignTokens"))

local UIManager = require(script.Parent.UIManager)
local UITheme = require(script.Parent.UITheme)
local PanelKit = require(script.Parent.PanelKit)

local AdminPanel = {}

local tr = Localization.tr
local player = Players.LocalPlayer

local TABS = { "Monde", "Véhicule", "Personnage", "Joueurs", "Profil", "Diagnostic", "Journal" }
local WEATHER_LABEL: { [string]: string } = { Clear = "Sec", Rain = "Pluie", Fog = "Brouillard", Storm = "Orage" }
local KIND_LABEL: { [string]: string } = {
    PublicGarage = "Garages publics",
    Dealership = "Concessions",
    FuelStation = "Stations",
    ChargingHub = "Recharge",
    CarWash = "Lavages",
    PropertyOffer = "Propriétés",
    RaceStart = "Courses",
}

-- Réglages rapides de l'heure et du cycle (libellés traduits par tr).
type Preset = { Label: string, Value: number }
local HOURS: { Preset } = {
    { Label = "Matin", Value = 8 },
    { Label = "Midi", Value = 12 },
    { Label = "Soir", Value = 19 },
    { Label = "Nuit", Value = 0 },
}
local CYCLES: { Preset } = {
    { Label = "Figer", Value = 0 },
    { Label = "Normal", Value = 1 },
    { Label = "× 10", Value = 10 },
    { Label = "× 60", Value = 60 },
}

local request: RemoteFunction
local gui: ScreenGui
local shell: PanelKit.Shell
local tab = TABS[1]
local state: any = nil
local busy = false
local amountText = "10000"
local reasonText = ""
local pointFilter: string? = nil
local overlay: TextLabel
local overlayOn = false
local built = false

local function make(className: string, props: { [string]: any }, parent: Instance?): any
    local item = Instance.new(className)
    for key, value in props do
        (item :: any)[key] = value
    end
    if parent then
        item.Parent = parent
    end
    return item
end

local render: () -> ()

local function refresh()
    local done, response = PanelKit.invoke(request, "Snapshot")
    if done and type(response) == "table" and response.Status == "Ok" then
        state = response.Result
    end
end

-- Envoi d'une action ; état du serveur affiché dans le bandeau ; journal et état relus ensuite.
local function send(action: string, payload: any?, label: string)
    if busy then
        return
    end
    local function go()
        busy = true
        shell:setStatus("Pending", tr("Demande envoyée…"))
        local done, response = PanelKit.invoke(request, action, payload)
        busy = false
        if not done or type(response) ~= "table" then
            shell:setStatus("Offline", tr("Serveur injoignable : rien n'est confirmé."))
        elseif response.Status == "Ok" then
            shell:setStatus("Confirmed", tr("%s : fait.", label))
        else
            local key = tostring(response.Error)
            shell:setStatus("Rejected", tr("Refusé : %s", if Localization.has(key) then Localization.t(key) else key))
        end
        refresh()
        render()
    end
    if AdminRules.Confirm[action] then
        PanelKit.confirm(gui, tr("Confirmer : %s ?", label), go)
    else
        go()
    end
end

local function body(): ScrollingFrame
    return shell.Body
end

local function heading(text: string)
    PanelKit.heading(shell, body(), text)
end

local function card(title: string, value: string?): Frame
    local inner = PanelKit.card(shell, body(), nil, "Amber")
    PanelKit.cardTitle(shell, inner, title, value)
    return inner
end

local function button(parent: Instance, text: string, callback: () -> (), enabled: boolean?, reason: string?)
    PanelKit.button(shell, parent, text, "Secondary", callback, enabled, reason)
end

local function line(parent: Instance, text: string)
    PanelKit.text(shell, parent, text, "Body", "TextMuted")
end

local function field(parent: Instance, name: string, placeholder: string, value: string, onChange: (string) -> ())
    local box = make("TextBox", {
        Name = name,
        Size = UDim2.new(1, 0, 0, Tokens.PrimaryButtonHeight),
        BackgroundColor3 = PanelKit.color("Surface2"),
        TextColor3 = PanelKit.color("Text"),
        PlaceholderText = placeholder,
        PlaceholderColor3 = PanelKit.color("TextMuted"),
        Text = value,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = shell:next(),
    }, parent)
    box.FontFace = UITheme.face("Body")
    box.TextSize = UITheme.text(15)
    make("UICorner", { CornerRadius = UDim.new(0, Tokens.Radius.Button) }, box)
    make("UIStroke", { Color = PanelKit.color("Line"), Thickness = 1 }, box)
    make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, box)
    box:GetPropertyChangedSignal("Text"):Connect(function()
        onChange(box.Text)
    end)
end

local function hourText(hour: number): string
    local h = math.floor(hour)
    return string.format("%02d:%02d", h, math.floor((hour - h) * 60))
end

local function renderWorld()
    local clock = state.Clock
    local inner = card(tr("Heure du monde"), hourText(clock.Hour))
    line(inner, tr("Cycle × %s (0 = heure figée)", tostring(clock.Speed)))
    local hours = PanelKit.row(shell, inner)
    for _, spec in HOURS do
        button(hours, tr(spec.Label), function()
            send("SetClock", { Hour = spec.Value }, tr("Heure : %s", tr(spec.Label)))
        end)
    end
    local speeds = PanelKit.row(shell, inner)
    for _, spec in CYCLES do
        button(speeds, tr(spec.Label), function()
            send("SetClockSpeed", { Speed = spec.Value }, tr("Cycle : %s", tr(spec.Label)))
        end)
    end
    local weather = card(tr("Météo"), tr(WEATHER_LABEL[state.Weather] or state.Weather))
    local row = PanelKit.row(shell, weather)
    for _, name in AdminRules.Weathers do
        button(row, tr(WEATHER_LABEL[name]), function()
            send("SetWeather", { State = name }, tr("Météo : %s", tr(WEATHER_LABEL[name])))
        end)
    end
end

local function renderVehicle()
    local me = state.Me
    local spawn = card(tr("Faire apparaître (véhicule temporaire)"), nil)
    line(
        spawn,
        tr("Le véhicule apparaît à côté de vous ; il n'est jamais possédé et disparaît à votre départ.")
    )
    local row = PanelKit.row(shell, spawn)
    for _, model in state.Models do
        button(row, model.Name, function()
            send("SpawnVehicle", { ModelId = model.Id }, tr("Apparition : %s", model.Name))
        end)
    end
    button(spawn, tr("Retirer mes véhicules apparus (%d)", state.Spawned), function()
        send("RemoveSpawned", nil, tr("Véhicules apparus retirés"))
    end, state.Spawned > 0, tr("Aucun véhicule apparu"))
    local driven = card(tr("Véhicule conduit"), if me.Driving then tr("au volant") else tr("à pied"))
    local reason = tr("Montez au volant d'un véhicule")
    local actions = PanelKit.row(shell, driven)
    button(actions, tr("Réparer"), function()
        send("RepairVehicle", { RefillEnergy = false }, tr("Réparation"))
    end, me.Driving, reason)
    button(actions, tr("Réparer et faire le plein"), function()
        send("RepairVehicle", { RefillEnergy = true }, tr("Réparation et plein"))
    end, me.Driving, reason)
    button(actions, tr("Remettre sur roues"), function()
        send("FlipVehicle", nil, tr("Remise sur roues"))
    end, me.Driving, reason)
    button(actions, if me.Invulnerable then tr("Invulnérable : oui") else tr("Invulnérable : non"), function()
        send("SetInvulnerable", { On = not me.Invulnerable }, tr("Invulnérabilité"))
    end, me.Driving, reason)
end

local function renderCharacter()
    local me = state.Me
    local moves = card(tr("Déplacement"), nil)
    local noclip = PanelKit.row(shell, moves)
    button(noclip, if me.Noclip then tr("No clip : actif") else tr("No clip : inactif"), function()
        send("SetNoclip", { On = not me.Noclip, Speed = me.NoclipSpeed }, tr("No clip"))
    end)
    for _, speed in { 30, 60, 150 } do
        button(noclip, tr("No clip %d st/s", speed), function()
            send("SetNoclip", { On = true, Speed = speed }, tr("No clip %d st/s", speed))
        end)
    end
    line(moves, tr("No clip : ZQSD ou WASD selon la caméra, Espace pour monter, Maj gauche pour descendre."))
    local walk = PanelKit.row(shell, moves)
    for _, value in { 16, 32, 64, 100 } do
        button(walk, tr("Marche %d", value), function()
            send("SetWalkSpeed", { Value = value }, tr("Vitesse de marche %d", value))
        end)
    end
    local others = PanelKit.row(shell, moves)
    button(others, if me.Invisible then tr("Invisible : oui") else tr("Invisible : non"), function()
        send("SetInvisible", { On = not me.Invisible }, tr("Invisibilité"))
    end)
    button(others, tr("Réapparaître"), function()
        send("Respawn", nil, tr("Réapparition"))
    end)
    -- Téléportation : lieux publics de la carte, filtrés par catégorie.
    local places = card(tr("Téléportation"), tostring(#state.Points))
    local chips = PanelKit.row(shell, places)
    local kinds: { [string]: boolean } = {}
    for _, point in state.Points do
        kinds[point.Kind] = true
    end
    for kind in kinds do
        button(chips, tr(KIND_LABEL[kind] or kind), function()
            pointFilter = if pointFilter == kind then nil else kind
            render()
        end)
    end
    if pointFilter == nil then
        line(places, tr("Choisissez une catégorie de lieux."))
        return
    end
    local list = PanelKit.row(shell, places)
    for _, point in state.Points do
        if point.Kind == pointFilter then
            button(list, point.Name, function()
                send("Teleport", { PointId = point.Id }, tr("Téléportation : %s", point.Name))
            end)
        end
    end
end

local function amount(): number?
    local value = tonumber(amountText)
    if value and value == math.floor(value) and value >= 1 and value <= AdminRules.MaxCreditGrant then
        return value
    end
    return nil
end

local function renderPlayers()
    local tools = card(tr("Paramètres des actions"), nil)
    field(tools, "MontantCredits", tr("Montant (1 à 100 000)"), amountText, function(text)
        amountText = text
    end)
    field(tools, "MotifExpulsion", tr("Motif d'expulsion (120 caractères)"), reasonText, function(text)
        reasonText = string.sub(text, 1, AdminRules.ReasonMax)
    end)
    heading(tr("Joueurs présents (%d)", #state.Players))
    for _, other in state.Players do
        local inner = card(other.Display, "@" .. other.Name)
        local row = PanelKit.row(shell, inner)
        local isMe = other.UserId == player.UserId
        button(row, tr("Aller à"), function()
            send("TeleportToPlayer", { UserId = other.UserId }, tr("Aller à %s", other.Name))
        end, not isMe, tr("C'est vous"))
        button(row, tr("Amener"), function()
            send("BringPlayer", { UserId = other.UserId }, tr("Amener %s", other.Name))
        end, not isMe, tr("C'est vous"))
        local value = amount()
        button(row, tr("Donner des crédits"), function()
            send(
                "GrantCredits",
                { UserId = other.UserId, Amount = value },
                tr("%d crédits à %s", value or 0, other.Name)
            )
        end, value ~= nil, tr("Montant invalide (1 à 100 000)"))
        button(row, tr("Expulser"), function()
            send("Kick", { UserId = other.UserId, Reason = reasonText }, tr("Expulser %s", other.Name))
        end, not isMe and #reasonText > 0, if isMe then tr("C'est vous") else tr("Indiquez un motif"))
    end
end

local function renderProfile()
    local environment = state.Environment
    local profile = state.Profile
    local env = card(tr("Environnement"), environment.Name)
    line(env, tr("Stockage : %s (%s)", environment.Store, environment.Reason))
    if profile == nil then
        line(env, tr("Profil non chargé."))
        return
    end
    line(
        env,
        tr(
            "Profil : %s, schéma v%s, %s",
            profile.State,
            tostring(profile.SchemaVersion),
            if profile.Dirty then tr("modifications à sauvegarder") else tr("sauvegardé")
        )
    )
    local walletCard = card(tr("Crédits"), tostring(profile.Balance))
    local row = PanelKit.row(shell, walletCard)
    for _, value in { 1000, 10000, 100000 } do
        button(row, tr("+ %d", value), function()
            send("GrantCredits", { UserId = player.UserId, Amount = value }, tr("%d crédits pour moi", value))
        end)
    end
    local reputation = card(tr("Réputation"), tostring(profile.Reputation))
    local levels = PanelKit.row(shell, reputation)
    for _, value in { 0, 500, 2500, 8000, 20000 } do
        button(levels, tostring(value), function()
            send("SetReputation", { Points = value }, tr("Réputation à %d", value))
        end)
    end
    local activity = card(tr("Activités"), nil)
    local actions = PanelKit.row(shell, activity)
    button(actions, tr("Abandonner la mission"), function()
        send("AbandonMission", nil, tr("Abandon de la mission"))
    end, state.Me.Mission, tr("Aucune mission en cours"))
    button(actions, tr("Lancer ma course sans attendre"), function()
        send("ForceRaceStart", nil, tr("Départ forcé"))
    end)
    local reset = card(tr("Réinitialiser mon profil"), nil)
    local allowed = environment.Name == "Dev" or environment.Name == "Test"
    line(reset, tr("Repartir comme un nouveau joueur (développement et test seulement) ; reconnexion nécessaire."))
    PanelKit.button(shell, reset, tr("Réinitialiser mon profil"), "Revoke", function()
        send("ResetProfile", nil, tr("Réinitialisation du profil"))
    end, allowed, tr("Interdit en production"))
end

local function renderDiagnostic()
    local inner = card(tr("Surcouche de diagnostic"), if overlayOn then tr("affichée") else tr("masquée"))
    line(inner, tr("FPS, ping, position, environnement et état du profil, en haut à gauche de l'écran."))
    button(inner, if overlayOn then tr("Masquer la surcouche") else tr("Afficher la surcouche"), function()
        overlayOn = not overlayOn
        overlay.Visible = overlayOn
        render()
    end)
end

local function renderJournal()
    local entries = state.Journal or {}
    heading(tr("Dernières actions (%d)", #entries))
    if #entries == 0 then
        line(body(), tr("Aucune action consignée."))
    end
    for _, entry in entries do
        local inner = card(entry.Action, os.date("%H:%M:%S", entry.At) :: string)
        line(
            inner,
            string.format(
                "%s%s%s → %s",
                entry.AdminName,
                if entry.Target then " · " .. tostring(entry.Target) else "",
                if entry.Detail ~= "" then " · " .. entry.Detail else "",
                entry.Result
            )
        )
    end
end

function render()
    if shell == nil then
        return
    end
    shell:clear()
    shell:selectTab(tab)
    if state == nil then
        line(body(), tr("Chargement…"))
        return
    end
    if tab == "Monde" then
        renderWorld()
    elseif tab == "Véhicule" then
        renderVehicle()
    elseif tab == "Personnage" then
        renderCharacter()
    elseif tab == "Joueurs" then
        renderPlayers()
    elseif tab == "Profil" then
        renderProfile()
    elseif tab == "Diagnostic" then
        renderDiagnostic()
    else
        renderJournal()
    end
end

local function updateOverlay()
    if not overlayOn then
        return
    end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local position = if root and root:IsA("BasePart") then root.Position else Vector3.zero
    local fps = math.floor(1 / math.max(RunService.RenderStepped:Wait(), 1e-3) + 0.5)
    local ping = math.floor(player:GetNetworkPing() * 1000 + 0.5)
    local environment = if state then state.Environment.Name else "?"
    local profile = if state and state.Profile then state.Profile.State else "?"
    overlay.Text = string.format(
        "FPS %d · ping %d ms · %.0f %.0f %.0f · %s · %s · mémoire %.0f Mo",
        fps,
        ping,
        position.X,
        position.Y,
        position.Z,
        environment,
        profile,
        Stats:GetTotalMemoryUsageMb()
    )
end

local function build()
    built = true
    gui = make(
        "ScreenGui",
        { Name = "AWAdmin", ResetOnSpawn = false, DisplayOrder = 25 },
        player:WaitForChild("PlayerGui")
    )
    shell = PanelKit.shell(gui, "MenuAdmin", tr("Administration"), TABS, tr, function(id: string)
        tab = id
        render()
    end, function()
        UIManager.close("Admin")
    end)
    shell:hints({ { "F8", tr("Fermer") } })
    overlay = make("TextLabel", {
        Name = "SurcoucheDiagnostic",
        Position = UDim2.fromOffset(12, 12),
        Size = UDim2.fromOffset(0, 26),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = PanelKit.color("Surface1"),
        BackgroundTransparency = 0.15,
        TextColor3 = PanelKit.color("Text"),
        Visible = false,
        Text = "",
    }, gui)
    overlay.FontFace = UITheme.face("Value")
    overlay.TextSize = UITheme.text(13)
    make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, overlay)
    make("UICorner", { CornerRadius = UDim.new(0, Tokens.Radius.Button) }, overlay)
    task.spawn(function()
        while gui.Parent do
            if overlayOn then
                updateOverlay()
            end
            task.wait(0.5)
        end
    end)
    local pushEvent = request.Parent and request.Parent:FindFirstChild("Push")
    if pushEvent and pushEvent:IsA("RemoteEvent") then
        pushEvent.OnClientEvent:Connect(function(kind: any, data: any)
            if kind == "Journal" and type(data) == "table" and state then
                state.Journal = data
                if tab == "Journal" and shell.Panel.Visible then
                    render()
                end
            end
        end)
    end
    UIManager.register({
        Name = "Admin",
        Kind = "Modal",
        Full = true,
        Open = function()
            shell.Panel.Visible = true
            render()
            task.spawn(function()
                refresh()
                render()
            end)
        end,
        Close = function()
            shell.Panel.Visible = false
            local veil = gui:FindFirstChild("VoileConfirmation")
            if veil then
                veil:Destroy()
            end
        end,
        Focus = function()
            return shell.Tabs[tab]
        end,
    })
    -- F8 (client Roblox) et F2 (Studio intercepte F8 pendant le jeu) : clavier, administrateurs seulement.
    -- Accès sans clavier : Téléphone › Paramètres › Administration.
    ContextActionService:BindAction("AWAdminMenu", function(_, inputState)
        if inputState == Enum.UserInputState.Begin then
            UIManager.toggle("Admin")
        end
        return Enum.ContextActionResult.Sink
    end, false, Enum.KeyCode.F8, Enum.KeyCode.F2)
    print("[AutomotiveWorld][Admin] Menu d'administration disponible : F8 ou F2, ou Téléphone › Paramètres.")
    Localization.changed(function()
        for name, item in shell.Tabs do
            item.Text = tr(name)
        end
        shell.Title.Text = Tokens.upper(tr("Administration"))
        render()
    end)
end

-- Démarré pour tous ; construit seulement si le serveur a marqué le joueur administrateur.
function AdminPanel.start()
    task.spawn(function()
        local folder = ReplicatedStorage:WaitForChild("AWAdmin", 30)
        if folder == nil then
            return
        end
        request = folder:WaitForChild("Request") :: RemoteFunction
        local function check()
            if player:GetAttribute("AWAdmin") == true and not built then
                build()
            end
        end
        player:GetAttributeChangedSignal("AWAdmin"):Connect(check)
        check()
        -- Diagnostic : compte non reconnu comme administrateur (UserId à comparer à Server/Admin/AdminConfig).
        task.delay(10, function()
            if not built then
                print(
                    string.format(
                        "[AutomotiveWorld][Admin] Menu indisponible : le compte %s (UserId %d) n'est pas administrateur.",
                        player.Name,
                        player.UserId
                    )
                )
            end
        end)
    end)
end

return table.freeze(AdminPanel)
