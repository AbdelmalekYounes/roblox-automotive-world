--!strict
--[[
    Smartphone virtuel (lot 0.7, §7.2, AUD-UI-01). Touche T (manette : X).

    - Tenu physiquement : le serveur place un modèle provisoire original dans
      la main du personnage (écran générique vu des autres) ; l'interface des
      applications s'affiche chez le joueur, en taille normale ou agrandie.
    - Applications : accueil, carte, véhicules, propriétés, missions, courses,
      marché, social, paramètres, notifications. Elles LISENT les services
      existants (progression, économie, courses, groupes) et ouvrent leurs
      panneaux pour agir : aucune seconde logique d'achat, de vente ou de
      récompense ; chaque action sensible reste validée par son service
      (lieu, vitesse, propriété).
    - En roulant : mode rapide seulement (itinéraire, prochaine direction,
      réglages rapides, alertes en lecture), sans sélection manette ; l'écran
      complet revient à l'arrêt avec son contenu. Jamais de freinage ni de
      pause.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared:WaitForChild("UI"):WaitForChild("Localization"))
local InputMap = require(Shared.UI.InputMap)
local Attributions = require(Shared:WaitForChild("Assets"):WaitForChild("Attributions"))
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))

local UIState = require(script.Parent.UIState)
local UITheme = require(script.Parent.UITheme)
local Components = require(script.Parent.Components)
local Tokens = require(Shared:WaitForChild("UI"):WaitForChild("DesignTokens"))
local PhoneIcons = require(Shared:WaitForChild("UI"):WaitForChild("PhoneIcons"))
local UIManager = require(script.Parent.UIManager)
local GPSController = require(script.Parent.GPSController)
local NotificationService = require(script.Parent.NotificationService)
local SocialController = require(script.Parent.SocialController)
local SettingsController = require(script.Parent.SettingsController)
local MapController = require(script.Parent.MapController)
local OnboardingController = require(script.Parent.OnboardingController)
local PhotoMode = require(script.Parent.PhotoMode)
local BodyChoice = require(script.Parent.BodyChoice)
local RadioController = require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("RadioController"))

local PhoneController = {}

local APPS = {
    "Map",
    "Vehicles",
    "Properties",
    "Missions",
    "Races",
    "Market",
    "Social",
    "Radio",
    "Photo",
    "Guide",
    "Settings",
    "Notifications",
}
local gui: ScreenGui
local device: Frame
local header: TextLabel
local body: ScrollingFrame
local quickBar: Frame
local backButton: TextButton
local quickTag: TextLabel
local clockLabel: TextLabel
local app = "Home"
local enlarged = false
local quick = false
local order = 0
local cache: { [string]: any } = {}
local settingsPage = "Interface"
local rebinding: string? = nil
local isOpen = false

local function remote(folder: string): RemoteFunction?
    local f = ReplicatedStorage:FindFirstChild(folder)
    local r = f and f:FindFirstChild("Request")
    return if r and r:IsA("RemoteFunction") then r else nil
end

local function ask(folder: string, action: string, payload: any?): any
    local r = remote(folder)
    if r == nil then
        return nil
    end
    local ok, response = pcall(function()
        return (r :: RemoteFunction):InvokeServer(action, payload or {})
    end)
    return if ok and type(response) == "table" then response else nil
end

local render: () -> ()

-- ======================== Éléments ========================

local function clear()
    for _, child in body:GetChildren() do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
    order = 0
end

-- Lignes de la maquette (§ téléphone) : titre en capitales (libellé), ligne de texte, note discrète.
local function line(text: string, bold: boolean?, dim: boolean?)
    order += 1
    local style = if bold then "Label" else "Body"
    Components.text(body, text, style, {
        Size = UDim2.new(1, -8, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = if bold or dim then UITheme.color("TextDim") else UITheme.color("Text"),
        LayoutOrder = order,
    })
end

-- Bouton de ligne (44 px) ; inactif : opacité 0,45, aucune action (la raison est donnée par la ligne qui suit).
local function button(text: string, fn: () -> (), enabled: boolean?)
    order += 1
    local b = UITheme.button(text, {
        Size = UDim2.new(1, -8, 0, Tokens.PrimaryButtonHeight),
        LayoutOrder = order,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, body, if enabled == false then nil else fn)
    UITheme.make(
        "UIPadding",
        { PaddingLeft = UDim.new(0, Tokens.Space[3]), PaddingRight = UDim.new(0, Tokens.Space[3]) },
        b
    )
    if enabled == false then
        b.Active = false
        b.Selectable = false
        b.BackgroundTransparency = Tokens.DisabledTransparency
        b.TextTransparency = Tokens.DisabledTransparency
    end
end

local function onoff(value: boolean): string
    return Localization.t(if value then "ui.on" else "ui.off")
end

local function openPanel(name: string)
    UIManager.close("Phone")
    UIManager.open(name)
end

local function goTo(x: number, z: number, label: string, source: string?)
    GPSController.setDestination(x, z, label, source or "Poi")
    NotificationService.notify("gps.computing", "Info", nil, "gps")
end

local function poiById(id: string): any?
    for _, point in MapController.points() do
        if point.Id == id then
            return point
        end
    end
    return nil
end

-- ======================== Applications ========================

local function appTile(parent: Instance, name: string, index: number)
    local tile = UITheme.make("TextButton", {
        Name = "App" .. name,
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        Size = UDim2.fromOffset(76, 88),
        LayoutOrder = index,
        Selectable = true,
    }, parent) :: TextButton
    local square = UITheme.make("Frame", {
        BackgroundColor3 = Tokens.color("AppTile"),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromScale(0.5, 0),
        Size = UDim2.fromOffset(Tokens.Phone.AppTile, Tokens.Phone.AppTile),
    }, tile)
    UITheme.make("UICorner", { CornerRadius = UDim.new(0, Tokens.Radius.AppTile) }, square)
    local stroke = UITheme.make("UIStroke", { Color = UITheme.color("Line"), Thickness = 1 }, square)
    local image = PhoneIcons.image(name)
    if image then
        UITheme.make("ImageLabel", {
            Name = "Icone",
            BackgroundTransparency = 1,
            Image = image,
            ImageColor3 = Tokens.color(PhoneIcons.tint(name)),
            ScaleType = Enum.ScaleType.Fit, -- planche « Icônes du téléphone » : version 128 px affichée en 28 px
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(Tokens.Phone.AppIcon, Tokens.Phone.AppIcon),
        }, square)
    else
        -- Image pas encore envoyée sur Roblox : cadre vide à la place (aucun caractère de remplacement).
        local slot = UITheme.make("Frame", {
            Name = "IconeAEnvoyer",
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(Tokens.Phone.AppIcon, Tokens.Phone.AppIcon),
        }, square)
        UITheme.make("UICorner", { CornerRadius = UDim.new(0, 6) }, slot)
        UITheme.make(
            "UIStroke",
            { Color = Tokens.color(PhoneIcons.tint(name)), Thickness = 1.5, Transparency = 0.3 },
            slot
        )
    end
    -- Nom de l'application en casse normale, 12 px (maquette).
    local caption = Components.text(tile, Localization.t("phone.app." .. name), "Body", {
        Name = "Nom",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.fromScale(0.5, 1),
        Size = UDim2.new(1, 0, 0, 16),
        AutomaticSize = Enum.AutomaticSize.None,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextColor3 = UITheme.color("Text"),
    })
    caption.TextSize = UITheme.text(12)
    local unread = if name == "Notifications" then NotificationService.unread() else 0
    if unread > 0 then
        local badge = UITheme.make("TextLabel", {
            Name = "Pastille",
            BackgroundColor3 = UITheme.color("Accent"),
            Text = tostring(unread),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, Tokens.Phone.AppTile / 2 - 2, 0, 4),
            Size = UDim2.fromOffset(18, 18), -- pastille ambre de 18 px, chiffres Roboto Mono (planche des icônes)
        }, tile) :: TextLabel
        badge.FontFace = UITheme.face("Value")
        badge.TextSize = UITheme.text(12)
        badge.TextColor3 = UITheme.color("OnAccent")
        UITheme.make("UICorner", { CornerRadius = UDim.new(1, 0) }, badge)
    end
    tile.SelectionGained:Connect(function()
        stroke.Color = UITheme.color("Focus")
        stroke.Thickness = Tokens.FocusStroke
    end)
    tile.SelectionLost:Connect(function()
        stroke.Color = UITheme.color("Line")
        stroke.Thickness = 1
    end)
    tile.Activated:Connect(function()
        app = name
        render()
    end)
end

local function renderHome()
    local unread = NotificationService.unread()
    if unread > 0 then
        order += 1
        Components.card(body, Localization.t("phone.unread", { count = unread }), nil, "Pending").LayoutOrder = order
    end
    order += 1
    local grid = UITheme.make("Frame", {
        Name = "Grille",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -8, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = order,
    }, body)
    -- 4 colonnes calculées sur la largeur disponible : les 12 applications tiennent en 3 rangées, sans défilement,
    -- même dans la taille compacte (4e rangée cachée dans une petite fenêtre : VM 20261105-034325).
    local columnWidth = math.max(60, math.floor((body.AbsoluteSize.X - 8 - 3 * 6) / 4))
    UITheme.make("UIGridLayout", {
        CellSize = UDim2.fromOffset(columnWidth, 88),
        CellPadding = UDim2.fromOffset(6, Tokens.Space[3]),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, grid)
    for index, name in APPS do
        appTile(grid, name, index)
    end
end

local function renderMap()
    button(Localization.t("ui.panel.map"), function()
        UIManager.close("Phone")
        UIManager.open("Map")
    end)
    local gps = GPSController.state()
    if gps.Destination then
        line(gps.Destination.Label, true)
        button(Localization.t("gps.clear"), function()
            GPSController.clear()
            render()
        end)
    end
    line(Localization.t("map.search"), true)
    local character = Players.LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local x, z = 0, 0
    if root and root:IsA("BasePart") then
        x, z = root.Position.X * Constants.MetersPerStud, root.Position.Z * Constants.MetersPerStud
    end
    local list = table.clone(MapController.markers())
    table.sort(list, function(a, b)
        return (a.X - x) ^ 2 + (a.Z - z) ^ 2 < (b.X - x) ^ 2 + (b.Z - z) ^ 2
    end)
    for index, marker in list do
        if index > 25 then
            break
        end
        local d = math.sqrt((marker.X - x) ^ 2 + (marker.Z - z) ^ 2)
        button(
            string.format(
                "%s — %s (%s)",
                Localization.t("poi." .. marker.Kind),
                marker.Name or "",
                Localization.distance(d)
            ),
            function()
                goTo(marker.X, marker.Z, marker.Name or "")
            end
        )
    end
end

local function progressionSnapshot(): any
    local response = ask("AWProgression", "Snapshot")
    return if response and response.Status ~= "Rejected"
        then (response.Snapshot or response.Result or response)
        else nil
end

local function renderVehicles()
    local snap = cache.Progression
    if snap == nil or snap.Vehicles == nil then
        line(Localization.t("ui.loading"))
        return
    end
    for _, vehicle in snap.Vehicles do
        local storage = vehicle.Storage and vehicle.Storage.State or "Stored"
        line(
            Localization.t("phone.vehicle.state", {
                model = vehicle.DisplayName,
                state = Localization.t("phone.vehicle." .. storage),
                energy = math.floor((vehicle.Energy or 0) * 100 + 0.5),
            }),
            true
        )
        line(Localization.t("phone.vehicle.configs", { count = #(vehicle.Configurations or {}) }), false, true)
        if storage == "Displayed" and vehicle.Storage.PropertyId then
            local point = poiById("P:" .. vehicle.Storage.PropertyId)
            if point then
                button(Localization.t("phone.property.navigate"), function()
                    goTo(point.X, point.Z, point.Name)
                end)
            end
        end
    end
    button(Localization.t("ui.panel.garage"), function()
        openPanel("Garage")
    end)
end

-- Lot 0.8 : radio (AUD-RADIO-01). Le conducteur choisit ; chacun règle ou coupe son écoute.
local function renderRadio()
    local seat = RadioController.seat()
    local current = RadioController.current()
    line(Localization.t("radio.seat." .. seat), true)
    line(Localization.t("radio.current", { station = Localization.t("radio.station." .. current) }))
    for _, station in RadioController.stations() do
        local label = Localization.t("radio.station." .. station.Id)
        if not station.Available then
            line(Localization.t("radio.unavailable", { station = label }))
        elseif seat == "Driver" then
            button(label, function()
                RadioController.setStation(station.Id)
                render()
            end)
        else
            line(label)
        end
    end
    if seat == "Driver" and current ~= "Off" then
        button(Localization.t("radio.station.Off"), function()
            RadioController.setStation("Off")
            render()
        end)
    end
    local audio = UIState.prefs().Audio
    button(Localization.t("radio.mute", { state = onoff(audio.RadioMuted) }), function()
        SettingsController.update(function(p)
            p.Audio.RadioMuted = not p.Audio.RadioMuted
        end)
        render()
    end)
    button(
        Localization.t("settings.volume", { category = Localization.t("settings.volume.Radio"), value = audio.Radio }),
        function()
            SettingsController.update(function(p)
                p.Audio.Radio = if p.Audio.Radio >= 100 then 0 else p.Audio.Radio + 10
            end)
            render()
        end
    )
    line(Localization.t("radio.note"))
end

-- Lot 0.8 : introduction consultable à tout moment et exercices de formation.
local function renderGuide()
    for _, step in { "Welcome", "World", "Controls", "Phone" } do
        line(Localization.t("onb.title." .. step), true)
        line(Localization.t("onb.text." .. step))
    end
    button(Localization.t("onb.training"), function()
        UIManager.close("Phone")
        OnboardingController.openTraining()
    end)
end

local function renderProperties()
    local snap = cache.Progression
    if snap == nil or snap.Properties == nil then
        line(Localization.t("ui.loading"))
        return
    end
    for _, property in snap.Properties do
        line(Localization.t("phone.property.line", { name = property.Label, level = property.GarageLevel }), true)
        local point = poiById("P:" .. property.Id)
        if point then
            button(Localization.t("phone.property.navigate"), function()
                goTo(point.X, point.Z, point.Name)
            end)
        end
    end
    if snap.Invitations and #snap.Invitations > 0 then
        line(Localization.t("social.invite"), true)
        for _, invitation in snap.Invitations do
            line(
                string.format(
                    "%s — %s%s",
                    invitation.GuestName or tostring(invitation.GuestUserId),
                    if invitation.Visit then Localization.t("social.tag.visit") else "",
                    if invitation.Drive then " · " .. Localization.t("social.tag.drive") else ""
                ),
                false,
                true
            )
        end
    end
    line(Localization.t("social.privacy"), false, true)
    button(Localization.t("ui.panel.garage"), function()
        openPanel("Garage")
    end)
end

local function renderMissions()
    local snap = cache.Economy
    if snap == nil or snap.Jobs == nil then
        line(Localization.t("ui.loading"))
        return
    end
    if snap.Mission then
        line(Localization.t("phone.mission.active", { job = snap.Mission.Job }), true)
        line(snap.Mission.Label or "")
        if snap.Mission.Point then
            button(Localization.t("phone.property.navigate"), function()
                GPSController.missionTarget(snap.Mission.Point, snap.Mission.Label)
            end)
        end
    end
    for _, job in snap.Jobs do
        line(Localization.t("phone.mission.line", { job = job.Label, completed = job.Completed }))
        button(Localization.t("phone.mission.start"), function()
            local response = ask("AWEconomy", "StartMission", { Job = job.Id })
            if response and response.Status ~= "Ok" then
                NotificationService.notify(response.Error or "ServerError", "Warning")
            end
        end, snap.Mission == nil)
    end
    button(Localization.t("ui.panel.economy"), function()
        openPanel("Economy")
    end)
end

local function renderRaces()
    local catalog = cache.Races
    if catalog == nil then
        line(Localization.t("ui.loading"))
        return
    end
    line(Localization.t("phone.race.season", { index = catalog.Season.Index }), true)
    local profile = catalog.Profile
    if profile then
        for _, ladder in { "Race", "Drift" } do
            local data = profile.Ladders[ladder]
            line(Localization.t("phone.race.rank", { ladder = ladder, rank = data.Rank, points = data.Points }))
        end
    end
    for index, course in catalog.Courses do
        if index > 10 then
            break
        end
        line(Localization.t("phone.race.line", {
            name = course.Name,
            discipline = course.DisciplineLabel,
            distance = Localization.distance(course.DistanceM),
        }))
        button(Localization.t("phone.property.navigate"), function()
            goTo(course.Registration.X, course.Registration.Z, course.Name, "Race")
        end)
        if SocialController.view() and SocialController.view().Group and SocialController.view().Group.IsLeader then
            button(Localization.t("social.suggestRace"), function()
                SocialController.send("SuggestRace", { CourseId = course.Id })
            end)
        end
    end
    button(Localization.t("ui.panel.races"), function()
        openPanel("Races")
    end)
end

local function renderMarket()
    local snap = cache.Economy
    if snap == nil then
        line(Localization.t("ui.loading"))
        return
    end
    local mine = 0
    for _, listing in snap.Listings or {} do
        if listing.Mine then
            mine += 1
        end
        line(Localization.t("phone.market.line", {
            model = listing.Model,
            price = Localization.t("phone.credits", { amount = Localization.amount(listing.Price) }),
        }))
    end
    line(Localization.t("phone.market.mine", { count = mine }), true)
    button(Localization.t("ui.panel.economy"), function()
        openPanel("Economy")
    end)
end

local function renderSocial()
    local view = SocialController.view()
    if view == nil then
        line(Localization.t("ui.loading"))
        SocialController.send("Snapshot")
        return
    end
    for _, invite in view.Incoming or {} do
        line(Localization.t("social.invited", { name = invite.From.Name }), true)
        button(Localization.t("social.accept"), function()
            SocialController.send("Accept", { InviteId = invite.Id })
        end)
        button(Localization.t("social.decline"), function()
            SocialController.send("Decline", { InviteId = invite.Id })
        end)
    end
    local group = view.Group
    if group then
        line(Localization.t("social.members", { count = #group.Members }), true)
        for _, member in group.Members do
            line(
                string.format(
                    "%s%s%s%s",
                    member.Name,
                    if member.Leader then " — " .. Localization.t("social.leader") else "",
                    if member.Online then "" else " (" .. Localization.t("social.offline") .. ")",
                    if member.Sharing then " · " .. Localization.t("social.tag.sharing") else ""
                )
            )
            if group.IsLeader and member.UserId ~= Players.LocalPlayer.UserId then
                button(Localization.t("social.promote") .. " : " .. member.Name, function()
                    SocialController.send("Promote", { UserId = member.UserId })
                end)
                button(Localization.t("social.kick") .. " : " .. member.Name, function()
                    SocialController.send("Kick", { UserId = member.UserId })
                end)
            end
        end
        button(Localization.t("social.shareLocation") .. " : " .. onoff(group.Sharing), function()
            SocialController.send("SetSharing", { On = not group.Sharing })
        end)
        local prefs = UIState.prefs()
        button(Localization.t("social.showMembers") .. " : " .. onoff(prefs.Social.ShowSharedMembers), function()
            SettingsController.update(function(p)
                p.Social.ShowSharedMembers = not p.Social.ShowSharedMembers
            end)
            render()
        end)
        button(Localization.t("social.leave"), function()
            SocialController.send("Leave")
        end)
        if group.IsLeader then
            button(Localization.t("social.dissolve"), function()
                SocialController.send("Dissolve")
            end)
        end
    else
        line(Localization.t("social.noGroup"))
        button(Localization.t("social.create"), function()
            SocialController.send("CreateGroup")
        end)
    end
    line(Localization.t("social.players"), true)
    for _, other in view.Players or {} do
        line(
            string.format("%s%s", other.Name, if other.Friend then " — " .. Localization.t("social.friend") else ""),
            false,
            other.InGroup
        )
        if not other.InGroup and (group == nil or group.IsLeader) then
            button(Localization.t("social.invite") .. " : " .. other.Name, function()
                local response = SocialController.send("Invite", { UserId = other.UserId })
                if response.Status == "Ok" then
                    NotificationService.notify("social.inviteSent", "Info", { name = other.Name })
                end
            end)
        end
    end
    line(Localization.t("social.channels"), true)
    local channels = view.Channels or {}
    line(Localization.t("social.channel.Group") .. " : " .. onoff(channels.Group == true), false, true)
    line(Localization.t("social.channel.Proximity") .. " : " .. onoff(channels.Proximity == true), false, true)
    line(Localization.t("social.channel.Voice"), false, true)
    if not channels.Chat then
        line(Localization.t("social.channel.restricted"), false, true)
    end
    line(Localization.t("social.privacy"), false, true)
end

local function cycle(list: { any }, value: any): any
    local index = table.find(list, value) or 0
    return list[index % #list + 1]
end

local function step(value: number, delta: number, low: number, high: number): number
    local nextValue = value + delta
    if nextValue > high then
        return low
    end
    return nextValue
end

local function renderSettings()
    local prefs = UIState.prefs()
    for _, page in { "Interface", "Controls", "Accessibility", "Notifications", "Audio", "Graphics", "Credits" } do
        button(Localization.t("settings." .. string.lower(string.sub(page, 1, 1)) .. string.sub(page, 2)), function()
            settingsPage = page
            render()
        end)
    end
    line(
        Localization.t("settings." .. string.lower(string.sub(settingsPage, 1, 1)) .. string.sub(settingsPage, 2)),
        true
    )
    local function set(text: string, mutate: (any) -> ())
        button(text, function()
            SettingsController.update(mutate)
            render()
        end)
    end
    if settingsPage == "Interface" then
        set(
            Localization.t("settings.language", { language = Localization.t("settings.language." .. prefs.Language) }),
            function(p)
                p.Language = cycle({ "fr", "en" }, p.Language)
            end
        )
        set(
            Localization.t("settings.hudLevel", { level = Localization.t("hud.level." .. prefs.Hud.Level) }),
            function(p)
                p.Hud.Level = cycle({ "Minimal", "Standard", "Full" }, p.Hud.Level)
            end
        )
        set(Localization.t("settings.hudScale", { value = prefs.Hud.Scale }), function(p)
            p.Hud.Scale = step(p.Hud.Scale, 10, 70, 140)
        end)
        set(
            Localization.t("settings.hudCorner", { value = Localization.t("settings.corner." .. prefs.Hud.Corner) }),
            function(p)
                p.Hud.Corner = cycle({ "BottomRight", "BottomLeft" }, p.Hud.Corner)
            end
        )
        set(Localization.t("settings.minimap", { state = onoff(prefs.Hud.ShowMinimap) }), function(p)
            p.Hud.ShowMinimap = not p.Hud.ShowMinimap
        end)
        set(Localization.t("settings.minimapZoom", { value = prefs.Hud.MinimapZoom }), function(p)
            p.Hud.MinimapZoom = step(p.Hud.MinimapZoom, 1, 1, 4)
        end)
        set(Localization.t("settings.minimapRotate", { state = onoff(prefs.Hud.MinimapRotate) }), function(p)
            p.Hud.MinimapRotate = not p.Hud.MinimapRotate
        end)
        set(Localization.t("settings.drivingInfo", { state = onoff(prefs.Hud.DrivingInfo) }), function(p)
            p.Hud.DrivingInfo = not p.Hud.DrivingInfo
        end)
        set(Localization.t("settings.devHud", { state = onoff(prefs.Hud.DevHud) }), function(p)
            p.Hud.DevHud = not p.Hud.DevHud
        end)
        -- Silhouette (avatars humains) : état tenu par le serveur, pas une préférence.
        local worn = BodyChoice.current()
        button(
            Localization.t(
                "settings.avatarBody",
                { body = if worn then Localization.t("avatar.body." .. worn) else "…" }
            ),
            function()
                task.spawn(function()
                    BodyChoice.choose(BodyChoice.next())
                    render()
                end)
            end
        )
    elseif settingsPage == "Credits" then
        -- Lot VEH3D-01 : attributions CC BY 4.0 (titre et lien affichés seulement sur décision du propriétaire).
        line(Localization.t("credits.intro"))
        for _, entry in Attributions.List do
            line(Localization.t("credits.entry", {
                usage = Localization.t(entry.UsageKey),
                creator = entry.Creator,
                source = entry.Source,
                licence = entry.Licence,
                changes = Localization.t(entry.ChangesKey),
            }))
            if entry.ShowTitle then
                line(Localization.t("credits.title", { title = entry.Title }))
            end
            if entry.ShowUrl then
                line(Localization.t("credits.url", { url = entry.Url }))
            end
            line(Localization.t("credits.licence", { licence = entry.Licence, url = entry.LicenceUrl }))
        end
    elseif settingsPage == "Controls" then
        for _, binding in InputMap.Defaults do
            if binding.Rebindable then
                local key = InputMap.keyFor(binding.Action, prefs.Bindings) or "—"
                button(
                    Localization.t(
                        "settings.rebind",
                        { action = Localization.t("action." .. binding.Action), key = key }
                    ),
                    function()
                        rebinding = binding.Action
                        NotificationService.notify("settings.rebindPrompt", "Info", nil, "rebind")
                    end
                )
            end
        end
        set(Localization.t("settings.reset"), function(p)
            p.Bindings = {}
        end)
    elseif settingsPage == "Accessibility" then
        local a = prefs.Access
        set(Localization.t("settings.textScale", { value = a.TextScale }), function(p)
            p.Access.TextScale = step(p.Access.TextScale, 10, 80, 150)
        end)
        set(Localization.t("settings.contrast", { state = onoff(a.HighContrast) }), function(p)
            p.Access.HighContrast = not p.Access.HighContrast
        end)
        set(Localization.t("settings.reduceMotion", { state = onoff(a.ReduceMotion) }), function(p)
            p.Access.ReduceMotion = not p.Access.ReduceMotion
        end)
        set(Localization.t("settings.panelOpacity", { value = a.PanelOpacity }), function(p)
            p.Access.PanelOpacity = step(p.Access.PanelOpacity, 10, 50, 100)
        end)
        set(Localization.t("settings.navSensitivity", { value = a.NavSensitivity }), function(p)
            p.Access.NavSensitivity = step(p.Access.NavSensitivity, 1, 1, 5)
        end)
        set(Localization.t("settings.visualAlerts", { state = onoff(a.VisualAlerts) }), function(p)
            p.Access.VisualAlerts = not p.Access.VisualAlerts
        end)
    elseif settingsPage == "Notifications" then
        set(Localization.t("settings.reduceSecondary", { state = onoff(prefs.Access.ReduceSecondary) }), function(p)
            p.Access.ReduceSecondary = not p.Access.ReduceSecondary
        end)
        set(Localization.t("notif.level.Info") .. " : " .. onoff(prefs.Notifications.Info), function(p)
            p.Notifications.Info = not p.Notifications.Info
        end)
        set(Localization.t("notif.level.Warning") .. " : " .. onoff(prefs.Notifications.Warning), function(p)
            p.Notifications.Warning = not p.Notifications.Warning
        end)
        line(Localization.t("notif.level.Critical") .. " : " .. Localization.t("ui.on"), false, true)
    elseif settingsPage == "Graphics" then
        -- Lot 0.8 : qualité (habillage, détails, lumières, effets ; ArtDirection.Profiles).
        set(
            Localization.t("settings.quality", { value = Localization.t("quality." .. prefs.Graphics.Quality) }),
            function(p)
                local qualities = { "Low", "Medium", "High" }
                p.Graphics.Quality = qualities[(table.find(qualities, p.Graphics.Quality) or 2) % 3 + 1]
            end
        )
        line(Localization.t("settings.quality.note"))
    else
        set(Localization.t("radio.mute", { state = onoff(prefs.Audio.RadioMuted) }), function(p)
            p.Audio.RadioMuted = not p.Audio.RadioMuted
        end)
        for _, category in { "Master", "Engine", "Environment", "Interface", "Effects", "Radio", "Voice" } do
            set(
                Localization.t("settings.volume", {
                    category = Localization.t("settings.volume." .. category),
                    value = (prefs.Audio :: any)[category],
                }),
                function(p)
                    (p.Audio :: any)[category] = step((p.Audio :: any)[category], 10, 0, 100)
                end
            )
        end
    end
end

local function renderNotifications()
    button(Localization.t("notif.clear"), function()
        NotificationService.clear()
        render()
    end)
    for _, item in NotificationService.history(30) do
        line(
            string.format("%s — %s", Localization.t("notif.level." .. item.Level), NotificationService.text(item)),
            item.Level == "Critical"
        )
    end
    NotificationService.markRead()
end

-- Mode rapide (conduite) : lecture et réglages rapides, aucune saisie.
local function renderQuick()
    line(Localization.t("phone.quickMode"), true)
    local gps = GPSController.state()
    if gps.Destination then
        line(gps.Destination.Label)
        local progress = gps.Progress
        if progress then
            line(Localization.t("gps.remaining", {
                distance = Localization.distance(progress.RemainingM),
                minutes = math.max(1, math.ceil(progress.RemainingS / 60)),
            }))
        end
    else
        line(Localization.t("gps.noDestination"), false, true)
    end
    for _, item in NotificationService.history(3) do
        line(NotificationService.text(item), false, true)
    end
    line(Localization.t("phone.fullOnlyStopped"), false, true)
end

render = function()
    if not isOpen then
        return
    end
    clear()
    header.Text = if quick
        then Localization.t("ui.panel.phone")
        else Localization.t(if app == "Home" then "phone.home" else "phone.app." .. app)
    clockLabel.Text = os.date("%H:%M") :: string
    quickBar.Visible = quick
    quickTag.Visible = quick
    backButton.Visible = not quick and app ~= "Home"
    if quick then
        renderQuick()
        return
    end
    if app == "Home" then
        renderHome()
    elseif app == "Map" then
        renderMap()
    elseif app == "Vehicles" then
        renderVehicles()
    elseif app == "Properties" then
        renderProperties()
    elseif app == "Missions" then
        renderMissions()
    elseif app == "Races" then
        renderRaces()
    elseif app == "Market" then
        renderMarket()
    elseif app == "Social" then
        renderSocial()
    elseif app == "Guide" then
        renderGuide()
    elseif app == "Radio" then
        renderRadio()
    elseif app == "Photo" then
        line(Localization.t("photo.rules"))
        button(Localization.t("photo.open"), function()
            UIManager.close("Phone")
            PhotoMode.request()
        end)
    elseif app == "Settings" then
        renderSettings()
    else
        renderNotifications()
    end
end

-- Données des applications (lecture seule), chargées à l'ouverture.
local function load()
    task.spawn(function()
        cache.Progression = progressionSnapshot()
        local economy = ask("AWEconomy", "Snapshot")
        cache.Economy = if economy then (economy.Snapshot or economy.Result) else nil
        local races = ask("AWRacing", "Catalog")
        cache.Races = if races then races.Result else nil
        render()
    end)
end

local function layout()
    local camera = workspace.CurrentCamera :: Camera
    local compact = Tokens.layout(camera.ViewportSize.X, camera.ViewportSize.Y).Compact
    local big = enlarged and not quick
    local phone = Tokens.Phone
    local size = if compact
        then (if big then phone.CompactEnlarged else phone.CompactNormal)
        else (if big then phone.Enlarged else phone.Normal)
    local margin = if compact then phone.MarginCompact else phone.Margin
    -- Jamais plus haut que la vue (barre de Roblox comprise) : le haut du téléphone restait coupé dans une petite
    -- fenêtre (VM 1250 × 593, tâche 20261105-033732).
    local inset = game:GetService("GuiService"):GetGuiInset().Y
    local height = math.min(size.Y, camera.ViewportSize.Y - inset - 2 * margin)
    device.AnchorPoint = Vector2.new(1, 1)
    device.Position = UDim2.new(1, -margin, 1, -margin)
    UITheme.motion(device, { Size = UDim2.fromOffset(size.X, height) }, "PhoneResize")
    gui:SetAttribute("AWPhoneSize", string.format("%dx%d", size.X, height))
end

local function build()
    gui = UITheme.make("ScreenGui", {
        Name = "AWPhone",
        ResetOnSpawn = false,
        DisplayOrder = 12,
        Enabled = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, Players.LocalPlayer:WaitForChild("PlayerGui"))
    -- Coque (rayon 34) et écran (rayon 26) de la maquette.
    device = UITheme.make("Frame", {
        Name = "Coque",
        BackgroundColor3 = UITheme.color("PanelChrome"),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(Tokens.Phone.Normal.X, Tokens.Phone.Normal.Y),
    }, gui) :: Frame
    UITheme.make("UICorner", { CornerRadius = UDim.new(0, Tokens.Radius.PhoneFrame) }, device)
    UITheme.make("UIStroke", { Color = UITheme.color("Line"), Thickness = 2 }, device)
    local screen = UITheme.make("Frame", {
        Name = "Ecran",
        BackgroundColor3 = UITheme.color("Panel"),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, 10),
        Size = UDim2.new(1, -20, 1, -20),
    }, device)
    UITheme.make("UICorner", { CornerRadius = UDim.new(0, Tokens.Radius.PhoneScreen) }, screen)
    -- Barre d'état : heure.
    clockLabel = Components.text(screen, "", "Value", {
        Name = "Heure",
        Position = UDim2.fromOffset(18, 8),
        TextColor3 = UITheme.color("TextDim"),
    })
    -- En-tête : retour, titre, étiquette « mode rapide », agrandir et fermer.
    backButton = UITheme.button(
        Localization.t("ui.back"),
        {
            Name = "Retour",
            Position = UDim2.fromOffset(12, 34),
            Size = UDim2.fromOffset(0, Tokens.MinTarget),
            AutomaticSize = Enum.AutomaticSize.X,
        },
        screen,
        function()
            app = "Home"
            render()
        end
    )
    UITheme.make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, backButton)
    header = Components.text(screen, "", "H1", {
        Name = "Titre",
        Position = UDim2.fromOffset(16, 72),
        Size = UDim2.new(1, -32, 0, 34),
        AutomaticSize = Enum.AutomaticSize.None,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    quickTag = Components.text(screen, Localization.t("phone.quickMode"), "Label", {
        Name = "ModeRapide",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -16, 0, 80),
        TextColor3 = UITheme.color("AccentSoftText"),
        Visible = false,
    })
    -- Lot 0.9.1 (QA-F14) : signes latins, toujours rendus par la police.
    UITheme.button(
        "+",
        {
            Name = "Agrandir",
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -56, 0, 34),
            Size = UDim2.fromOffset(Tokens.MinTarget, Tokens.MinTarget),
        },
        screen,
        function()
            enlarged = not enlarged
            layout()
        end
    )
    UITheme.button(
        "×",
        {
            Name = "Fermer",
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -16, 0, 34),
            Size = UDim2.fromOffset(Tokens.MinTarget, Tokens.MinTarget),
        },
        screen,
        function()
            UIManager.close("Phone")
        end
    )
    body = UITheme.make("ScrollingFrame", {
        Name = "Contenu",
        Position = UDim2.fromOffset(12, 114),
        Size = UDim2.new(1, -24, 1, -176),
        BackgroundTransparency = 1,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = UITheme.color("Line"),
    }, screen)
    UITheme.make(
        "UIListLayout",
        { Padding = UDim.new(0, Tokens.Space[2]), SortOrder = Enum.SortOrder.LayoutOrder },
        body
    )
    -- Réglages rapides autorisés en roulant (souris ou raccourcis, jamais une sélection manette).
    quickBar = UITheme.make(
        "Frame",
        { Position = UDim2.new(0, 12, 1, -54), Size = UDim2.new(1, -24, 0, 44), BackgroundTransparency = 1 },
        screen
    )
    UITheme.make(
        "UIListLayout",
        { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, Tokens.Space[2]) },
        quickBar
    )
    local function quickButton(text: string, fn: () -> ())
        local b = UITheme.button(
            text,
            { Size = UDim2.fromOffset(0, Tokens.PrimaryButtonHeight), AutomaticSize = Enum.AutomaticSize.X },
            quickBar,
            fn
        )
        UITheme.make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, b)
        b.Selectable = false
    end
    quickButton("HUD", function()
        SettingsController.update(function(p)
            p.Hud.Level = cycle({ "Minimal", "Standard", "Full" }, p.Hud.Level)
        end)
    end)
    quickButton(Localization.t("phone.quick.zoom"), function()
        SettingsController.update(function(p)
            p.Hud.MinimapZoom = step(p.Hud.MinimapZoom, 1, 1, 4)
        end)
    end)
    quickButton(Localization.t("phone.quick.clearGps"), function()
        GPSController.clear()
        render()
    end)
    layout()
end

-- Saisie d'une nouvelle touche (paramètres des commandes).
local function captureRebind(input: InputObject)
    local action = rebinding
    if action == nil or input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end
    rebinding = nil
    if input.KeyCode == Enum.KeyCode.Escape then
        return
    end
    local key = input.KeyCode.Name
    local custom = table.clone(UIState.prefs().Bindings)
    local ok, err = InputMap.validate(custom, action, key)
    if not ok then
        local conflict = if err then string.match(err, "^Conflict:(.+)$") else nil
        if conflict then
            NotificationService.notify(
                "settings.rebindConflict",
                "Warning",
                { action = Localization.t("action." .. conflict) }
            )
        else
            NotificationService.notify("settings.rebindReserved", "Warning")
        end
        return
    end
    SettingsController.update(function(p)
        p.Bindings[action] = key
    end)
    NotificationService.notify("settings.saved", "Info")
    render()
end

-- ======================== Bras levé (squelette à contraintes) ========================

-- Lot 0.9.2 (QA-A10) : sur le squelette R15 à contraintes d'animation, l'épaule n'a plus de
-- Motor6D (C0 en lecture seule, attaches à ne pas modifier). Le serveur publie l'attribut
-- `AWPhoneRaised` du personnage (InterfaceService) ; chaque client multiplie la rotation de
-- l'épaule dans Transform après l'animation (PreSimulation), méthode indiquée par Roblox :
-- les animations de marche continuent de s'appliquer. Même angle que le Motor6D (60°).
local PHONE_RAISED_ATTRIBUTE = "AWPhoneRaised"
local RAISE_DEG = 60
local RAISE_DURATION_S = 0.25
-- Par épaule : avancement du geste (0 à 1), dernier Transform écrit et décalage appliqué.
type RaisedArm = { Alpha: number, Written: CFrame, Offset: CFrame }
local raised: { [AnimationConstraint]: RaisedArm } = {}

local function sameFrame(a: CFrame, b: CFrame): boolean
    return (a.Position - b.Position).Magnitude < 1e-5
        and a.LookVector:Dot(b.LookVector) > 1 - 1e-7
        and a.UpVector:Dot(b.UpVector) > 1 - 1e-7
end

local function updateRaisedArms(dt: number)
    for _, other in Players:GetPlayers() do
        local character = other.Character
        local upper = character and character:FindFirstChild("RightUpperArm")
        local joint = upper and upper:FindFirstChild("RightShoulder")
        if joint == nil or not joint:IsA("AnimationConstraint") then
            continue
        end
        local shoulder = joint :: AnimationConstraint
        local wanted = (character :: Model):GetAttribute(PHONE_RAISED_ATTRIBUTE) == true
        local entry = raised[shoulder]
        if entry == nil and not wanted then
            continue
        end
        local current: RaisedArm = entry or { Alpha = 0, Written = shoulder.Transform, Offset = CFrame.identity }
        -- Animation non réévaluée ce pas-ci (Transform inchangé depuis notre écriture) :
        -- retirer l'ancien décalage avant d'appliquer le nouveau, sans cumul.
        local base = shoulder.Transform
        if entry and sameFrame(base, entry.Written) then
            base = entry.Offset:Inverse() * base
        end
        current.Alpha = math.clamp(current.Alpha + (if wanted then dt else -dt) / RAISE_DURATION_S, 0, 1)
        current.Offset = CFrame.Angles(math.rad(RAISE_DEG * current.Alpha), 0, 0)
        current.Written = current.Offset * base
        shoulder.Transform = current.Written
        if current.Alpha > 0 or wanted then
            raised[shoulder] = current
        else
            raised[shoulder] = nil
        end
    end
    for shoulder in raised do
        if shoulder.Parent == nil then
            raised[shoulder] = nil
        end
    end
end

function PhoneController.start()
    build()
    RunService.PreSimulation:Connect(updateRaisedArms)
    UIManager.register({
        Name = "Phone",
        Kind = "Modal",
        Full = true,
        Open = function()
            isOpen = true
            gui.Enabled = true
            local r = remote("AWInterface")
            if r then
                task.spawn(function()
                    pcall(function()
                        (r :: RemoteFunction):InvokeServer("Phone", { Out = true })
                    end)
                end)
            end
            load()
            render()
        end,
        Close = function()
            isOpen = false
            gui.Enabled = false
            rebinding = nil
            local r = remote("AWInterface")
            if r then
                task.spawn(function()
                    pcall(function()
                        (r :: RemoteFunction):InvokeServer("Phone", { Out = false })
                    end)
                end)
            end
        end,
        Quick = function(on: boolean)
            quick = on
            layout() -- pas de téléphone agrandi en mode rapide
            render()
        end,
        Focus = function()
            -- Tuiles de l'accueil comprises (dans la grille) : recherche dans toute la descendance.
            return body:FindFirstChildWhichIsA("GuiButton", true)
        end,
    })
    UIState.onPrefs(function()
        render()
    end)
    Localization.changed(function()
        render()
    end)
    SocialController.onChanged(function()
        if isOpen and app == "Social" then
            render()
        end
    end)
    game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
        if not processed then
            captureRebind(input)
        end
    end)
end

return PhoneController
