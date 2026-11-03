--!strict
--[[
    Interface PROVISOIRE de la progression (lot 0.4) : collection, véhicule,
    propriétés, préparation, configurations, invitations, état de sauvegarde.
    Ce n'est ni le HUD ni le smartphone définitifs (lot 0.7) : présentation
    volontairement sobre, navigable au clavier/souris et à la manette.

    Règles :
    - aucune réussite affichée avant la réponse du serveur ; « en attente »
      affiché tant que la sauvegarde n'est pas confirmée ;
    - chaque demande sensible porte un identifiant unique (anti double clic) ;
    - menu inutilisable en mouvement (le serveur refuse aussi, AUD-UI-01).
    Touche : P (clavier) ou Select / Vue (manette).
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GarageShared = Shared:WaitForChild("Garage")
local ProgressionProtocol = require(GarageShared:WaitForChild("ProgressionProtocol"))
local TuningRules = require(GarageShared:WaitForChild("TuningRules"))
local CosmeticCatalog = require(GarageShared:WaitForChild("CosmeticCatalog"))
local PartCatalog = require(GarageShared:WaitForChild("PartCatalog"))
local PropertyCatalog = require(GarageShared:WaitForChild("PropertyCatalog"))
local VehicleDefinitions = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleDefinitions"))

local Text = require(script.Parent.ProgressionMessages)
local UIManager = require(script.Parent.UIManager)

local GaragePanel = {}

local player = Players.LocalPlayer
local TABS = { "Collection", "Véhicule", "Propriétés", "Préparation", "Configurations", "Invitations" }
local STORAGE_LABELS = { Stored = "Rangé", Displayed = "Exposé", Out = "Sorti" }
local SLOT_LABELS = {
    Tires = "Pneus",
    Brakes = "Freins",
    Suspension = "Suspension",
    RearDifferential = "Différentiel AR",
    FrontDifferential = "Différentiel AV",
    EngineMap = "Cartographie",
}

local request: RemoteFunction
local gui: ScreenGui
local panel: Frame
local body: ScrollingFrame
local footer: TextLabel
local badge: TextLabel
local tabButtons: { [string]: TextButton } = {}
local state: any = nil -- dernier instantané reçu du serveur
local tab = "Collection"
local selected: string? = nil -- exemplaire sélectionné
local draftTuning: { [string]: number } = {}
local draftCosmetics: any = nil
local entranceOffer: any = nil
local busy = false

local function make(className: string, props: { [string]: any }, parent: Instance?): any
    local item = Instance.new(className)
    for key, value in props do
        (item :: any)[key] = value
    end
    item.Parent = parent
    return item
end

local function setFooter(text: string)
    footer.Text = text
end

local function percent(value: number): string
    return string.format("%d %%", math.floor(value * 100 + 0.5))
end

local function vehicleById(id: string?): any
    if state == nil or id == nil then
        return nil
    end
    for _, vehicle in state.Vehicles or {} do
        if vehicle.Id == id then
            return vehicle
        end
    end
    return nil
end

local function propertyById(id: string?): any
    for _, property in (state and state.Properties) or {} do
        if property.Id == id then
            return property
        end
    end
    return nil
end

local render: () -> ()

-- Envoie une demande ; affiche le statut RÉEL renvoyé par le serveur.
local function send(action: string, payload: any?)
    if busy then
        return
    end
    busy = true
    local data = payload or {}
    if ProgressionProtocol.Sensitive[action] then
        data.RequestId = HttpService:GenerateGUID(false)
    end
    setFooter("Demande envoyée…")
    local ok, response = pcall(function()
        return request:InvokeServer(action, data)
    end)
    busy = false
    if not ok or type(response) ~= "table" then
        setFooter("Serveur injoignable : rien n'est confirmé.")
        return
    end
    if response.Snapshot then
        state = response.Snapshot
    end
    if response.Status == "Rejected" then
        setFooter(Text.text(response.Error))
    else
        setFooter(Text.text(response.Status))
    end
    if action == "SetTuning" or action == "ApplyConfig" then
        draftTuning = {}
    end
    if action == "SetCosmetics" or action == "ApplyConfig" then
        draftCosmetics = nil
    end
    render()
end

-- ======================== Éléments ========================

local function clear()
    for _, child in body:GetChildren() do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end
end

local order = 0
local function nextOrder(): number
    order += 1
    return order
end

local function line(text: string, size: number?): TextLabel
    return make("TextLabel", {
        Size = UDim2.new(1, -8, 0, size or 22),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(230, 236, 244),
        Font = Enum.Font.Gotham,
        TextSize = 15,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = text,
        LayoutOrder = nextOrder(),
    }, body)
end

local function heading(text: string)
    local label = line(text, 26)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 17
end

local function row(): Frame
    local frame = make("Frame", {
        Size = UDim2.new(1, -8, 0, 32),
        BackgroundTransparency = 1,
        LayoutOrder = nextOrder(),
    }, body)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, frame)
    return frame
end

local function button(parent: Instance, text: string, width: number, callback: () -> (), enabled: boolean?): TextButton
    local active = enabled ~= false
    local item = make("TextButton", {
        Size = UDim2.new(0, width, 0, 30),
        BackgroundColor3 = if active then Color3.fromRGB(52, 92, 160) else Color3.fromRGB(60, 64, 72),
        TextColor3 = if active then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(150, 155, 165),
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        Text = text,
        AutoButtonColor = active,
        Selectable = active,
    }, parent)
    make("UICorner", { CornerRadius = UDim.new(0, 6) }, item)
    if active then
        item.Activated:Connect(callback)
    end
    return item
end

-- ======================== Onglets ========================

local function capabilities(): { [string]: boolean }
    return (state and state.Context and state.Context.Capabilities) or {}
end

local function renderCollection()
    heading("Véhicule de départ")
    local starter = state.Starter or {}
    if starter.State == "Chosen" then
        line("Choisi : " .. tostring(starter.ModelId) .. " (exemplaire incessible).")
    elseif starter.Available then
        line("Choix DÉFINITIF : un seul exemplaire gratuit, incessible.")
        local choices = row()
        for _, modelId in starter.Candidates do
            local definition = VehicleDefinitions.get(modelId)
            button(choices, if definition then definition.DisplayName else modelId, 200, function()
                send("ChooseStarter", { ModelId = modelId })
            end)
        end
    else
        line(Text.text("StarterCatalogUnavailable"))
    end
    heading(string.format("Collection (%d véhicule(s))", state.TotalVehicles or 0))
    for _, vehicle in state.Vehicles or {} do
        local storage = vehicle.Storage or {}
        local where = STORAGE_LABELS[storage.State] or "?"
        if storage.State == "Displayed" then
            local property = propertyById(storage.PropertyId)
            where ..= string.format(" (%s, place %s)", if property then property.Label else "?", tostring(storage.Slot))
        end
        local tags = {}
        if vehicle.Untransferable then
            table.insert(tags, "incessible")
        end
        if vehicle.Synthetic then
            table.insert(tags, "essai synthétique")
        end
        if vehicle.Reserved then
            table.insert(tags, "réservé")
        end
        local item = row()
        button(item, vehicle.DisplayName, 220, function()
            selected = vehicle.Id
            tab = "Véhicule"
            render()
        end)
        make("TextLabel", {
            Size = UDim2.new(1, -230, 1, 0),
            BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(210, 216, 226),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = string.format(
                "%s • énergie %s • %.1f km • usure %s%s",
                where,
                percent(vehicle.Energy),
                vehicle.OdometerKm,
                percent(vehicle.DamageLevel),
                if #tags > 0 then " • " .. table.concat(tags, ", ") else ""
            ),
        }, item)
    end
    if (state.Pages or 1) > 1 then
        local pages = row()
        button(pages, "◀ Page précédente", 160, function()
            send("CollectionPage", { Page = (state.Page or 1) - 1 })
        end, (state.Page or 1) > 1)
        button(pages, "Page suivante ▶", 160, function()
            send("CollectionPage", { Page = (state.Page or 1) + 1 })
        end, (state.Page or 1) < state.Pages)
        line(string.format("Page %d / %d", state.Page or 1, state.Pages))
    end
end

local function renderVehicle()
    local vehicle = vehicleById(selected)
    if vehicle == nil then
        line("Sélectionnez un véhicule dans la collection.")
        return
    end
    heading(vehicle.DisplayName .. "  (" .. vehicle.Id .. ")")
    line(
        string.format(
            "Origine : %s%s%s",
            vehicle.Origin,
            if vehicle.Untransferable then " • incessible" else "",
            if vehicle.Synthetic then " • donnée synthétique de développement" else ""
        )
    )
    line(
        string.format(
            "Kilométrage : %.1f km • énergie : %s • usure carrosserie : %s • moteur : %s",
            vehicle.OdometerKm,
            percent(vehicle.Energy),
            percent(vehicle.DamageLevel),
            percent(vehicle.Engine)
        )
    )
    local parts = {}
    for slot, partId in vehicle.Parts or {} do
        local part = PartCatalog.get(partId)
        table.insert(parts, (SLOT_LABELS[slot] or slot) .. " : " .. (if part then part.Label else partId))
    end
    line("Pièces installées : " .. (if #parts > 0 then table.concat(parts, ", ") else "série"))
    local storage = vehicle.Storage or {}
    line("État : " .. (STORAGE_LABELS[storage.State] or "?"))
    local actions = row()
    if storage.State == "Out" then
        button(actions, "Ranger (à une entrée / garage)", 260, function()
            send("Return", {})
        end)
    else
        button(actions, "Sortir le véhicule", 180, function()
            send("TakeOut", { VehicleId = vehicle.Id })
        end, state.OutVehicle == nil)
        local context = state.Context or {}
        if context.Kind == "Property" then
            button(actions, "Ranger", 110, function()
                send("Store", { VehicleId = vehicle.Id })
            end, storage.State == "Displayed")
            local property = propertyById(context.PropertyId)
            if property then
                local slots = row()
                for slot = 1, property.Capacity do
                    local occupant = property.Slots[tostring(slot)]
                    button(slots, "Exposer place " .. slot, 140, function()
                        send("Display", { VehicleId = vehicle.Id, PropertyId = property.Id, Slot = slot })
                    end, occupant == nil)
                end
            end
        end
    end
end

local function renderProperties()
    heading(string.format("Propriétés (%d / %d)", #(state.Properties or {}), PropertyCatalog.MaxOwned))
    for _, property in state.Properties or {} do
        local used = 0
        for _ in property.Slots do
            used += 1
        end
        line(
            string.format(
                "%s — %s • %d/%d place(s) exposée(s) • entrée : %s (%s)%s%s",
                property.Label,
                PropertyCatalog.Categories[property.Category].Label,
                used,
                property.Capacity,
                property.EntranceLabel,
                property.Zone,
                if property.Sellable then "" else " • invendable",
                if property.Synthetic then " • synthétique" else ""
            )
        )
        local actions = row()
        button(actions, "Agrandir (lot 0.5)", 170, function()
            send("UpgradeGarage", { PropertyId = property.Id })
        end)
        button(actions, "Revendre (lot 0.5)", 170, function()
            send("SellProperty", { PropertyId = property.Id })
        end, property.Sellable)
    end
    local context = state.Context or {}
    if context.Kind == "Property" or context.Kind == "Visit" then
        local exit = row()
        button(exit, "Quitter la propriété", 200, function()
            send("Exit", {})
        end)
    end
    if entranceOffer then
        heading("Entrée : propriétés accessibles ici")
        if #entranceOffer.Options == 0 then
            line("Aucune propriété accessible à cette entrée.")
        end
        for _, option in entranceOffer.Options do
            local item = row()
            button(item, string.format("Entrer : %s (%s)", option.Label, option.OwnerName), 420, function()
                send("Enter", { OwnerUserId = option.OwnerUserId, PropertyId = option.PropertyId })
                entranceOffer = nil
            end)
        end
    end
end

local function stepValue(range: any, value: number, direction: number): number
    local step = (range.Max - range.Min) / 10
    return math.clamp(value + direction * step, range.Min, range.Max)
end

local function cycle(list: { string }, current: string): string
    local index = table.find(list, current) or 0
    return list[index % #list + 1]
end

local function renderPreparation()
    local vehicle = vehicleById(selected)
    local caps = capabilities()
    local context = state.Context or {}
    line(
        string.format(
            "Lieu : %s",
            if context.Kind == "PublicGarage"
                then "garage public (préparation complète)"
                elseif context.Kind == "Property" then "votre propriété (garage privé)"
                else "hors garage"
        )
    )
    if vehicle == nil then
        line("Sélectionnez un véhicule dans la collection.")
        return
    end
    local base = VehicleDefinitions.get(vehicle.ModelId)
    if base == nil then
        return
    end
    heading("Réglages mécaniques — " .. vehicle.DisplayName)
    local ranges = TuningRules.ranges(base, vehicle.Parts or {})
    local keys = {}
    for key in ranges do
        table.insert(keys, key)
    end
    table.sort(keys)
    for _, key in keys do
        local range = ranges[key]
        local current = draftTuning[key] or (vehicle.Tuning or {})[key] or range.Default
        local item = row()
        button(item, "−", 36, function()
            draftTuning[key] = stepValue(range, current, -1)
            render()
        end, caps.EditTuning == true)
        button(item, "+", 36, function()
            draftTuning[key] = stepValue(range, current, 1)
            render()
        end, caps.EditTuning == true)
        make("TextLabel", {
            Size = UDim2.new(1, -90, 1, 0),
            BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(220, 226, 236),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = string.format(
                "%s : %.3g %s  [%.3g – %.3g]",
                range.Label,
                current,
                range.Unit,
                range.Min,
                range.Max
            ),
        }, item)
    end
    local apply = row()
    button(apply, "Appliquer les réglages", 220, function()
        local tuning = table.clone(vehicle.Tuning or {})
        for key, value in draftTuning do
            tuning[key] = value
        end
        send("SetTuning", { VehicleId = vehicle.Id, Tuning = tuning })
    end, caps.EditTuning == true)

    heading("Esthétique")
    local cosmetics = draftCosmetics or table.clone(vehicle.Cosmetics or CosmeticCatalog.defaults(base))
    draftCosmetics = cosmetics
    local colors = {}
    for _, swatch in CosmeticCatalog.Colors do
        table.insert(colors, swatch.Id)
    end
    local finishes: { string }, wheels: { string } = {}, {}
    for id in CosmeticCatalog.Finishes :: { [string]: any } do
        table.insert(finishes, id)
    end
    for id in CosmeticCatalog.Wheels :: { [string]: any } do
        table.insert(wheels, id)
    end
    table.sort(finishes)
    table.sort(wheels)
    local look = row()
    button(look, "Couleur : " .. cosmetics.BodyColor, 170, function()
        cosmetics.BodyColor = cycle(colors, cosmetics.BodyColor)
        render()
    end, caps.EditCosmetics == true)
    button(look, "Accent : " .. cosmetics.AccentColor, 160, function()
        cosmetics.AccentColor = cycle(colors, cosmetics.AccentColor)
        render()
    end, caps.EditCosmetics == true)
    button(look, "Finition : " .. cosmetics.Finish, 160, function()
        cosmetics.Finish = cycle(finishes, cosmetics.Finish)
        render()
    end, caps.EditCosmetics == true)
    button(look, "Jantes : " .. cosmetics.Wheels, 150, function()
        cosmetics.Wheels = cycle(wheels, cosmetics.Wheels)
        render()
    end, caps.EditCosmetics == true)
    local kit = row()
    for slot, options in CosmeticCatalog.BodyKitSlots do
        local current = (cosmetics.BodyKit or {})[slot] or "Stock"
        button(kit, slot .. " : " .. current, 150, function()
            cosmetics.BodyKit = cosmetics.BodyKit or {}
            cosmetics.BodyKit[slot] = cycle(options :: any, current)
            render()
        end, caps.EditCosmetics == true)
    end
    button(kit, if cosmetics.ShowLabel then "Inscription : oui" else "Inscription : non", 150, function()
        cosmetics.ShowLabel = not cosmetics.ShowLabel
        render()
    end, caps.EditCosmetics == true)
    local apply2 = row()
    button(apply2, "Appliquer l'esthétique", 220, function()
        send("SetCosmetics", { VehicleId = vehicle.Id, Cosmetics = cosmetics })
    end, caps.EditCosmetics == true)

    heading("Pièces (garage public)")
    for _, slot in PartCatalog.Slots do
        local item = row()
        local installed = (vehicle.Parts or {})[slot]
        make("TextLabel", {
            Size = UDim2.new(0, 220, 1, 0),
            BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(220, 226, 236),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = (SLOT_LABELS[slot] or slot) .. " : " .. (if installed
                then (PartCatalog.get(installed) :: any).Label
                else "série"),
        }, item)
        button(item, "Série", 80, function()
            send("SetPart", { VehicleId = vehicle.Id, Slot = slot, PartId = nil })
        end, caps.SwapParts == true and installed ~= nil)
        for _, part in PartCatalog.Parts do
            local owned = (state.Parts or {})[part.Id]
            if part.Slot == slot and PartCatalog.compatible(part, base) then
                button(item, string.format("%s (%d)", part.Label, if owned then owned.Detached else 0), 210, function()
                    send("SetPart", { VehicleId = vehicle.Id, Slot = slot, PartId = part.Id })
                end, caps.SwapParts == true and owned ~= nil and owned.Detached > 0)
            end
        end
    end
end

local nameBox: TextBox? = nil

local function renderConfigurations()
    local vehicle = vehicleById(selected)
    if vehicle == nil then
        line("Sélectionnez un véhicule dans la collection.")
        return
    end
    local caps = capabilities()
    local inGarage = state.Context and (state.Context.Kind == "Property" or state.Context.Kind == "PublicGarage")
    heading("Configurations — " .. vehicle.DisplayName .. " (5 au plus)")
    line("Une configuration est un jeu de réglages : elle ne crée aucune pièce.")
    local input = row()
    nameBox = make("TextBox", {
        Size = UDim2.new(0, 240, 0, 30),
        BackgroundColor3 = Color3.fromRGB(40, 44, 52),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        PlaceholderText = "Nom de la configuration",
        Text = "",
        Font = Enum.Font.Gotham,
        TextSize = 14,
        ClearTextOnFocus = false,
    }, input)
    local configurations = vehicle.Configurations or {}
    for index = 1, 5 do
        local configuration = configurations[index]
        local item = row()
        make("TextLabel", {
            Size = UDim2.new(0, 300, 1, 0),
            BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(220, 226, 236),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = if configuration
                then string.format(
                    "%d. %s%s",
                    index,
                    configuration.Name,
                    if configuration.Realizable then "" else " (pièces à échanger)"
                )
                else string.format("%d. (vide)", index),
        }, item)
        button(item, "Enregistrer ici", 130, function()
            local name = if nameBox and nameBox.Text ~= "" then nameBox.Text else "Configuration " .. index
            send("SaveConfig", { VehicleId = vehicle.Id, Index = index, Name = string.sub(name, 1, 24) })
        end, inGarage == true and index <= #configurations + 1)
        button(item, "Appliquer", 100, function()
            send("ApplyConfig", { VehicleId = vehicle.Id, Index = index })
        end, configuration ~= nil and caps.ApplyConfiguration == true)
        button(item, "Supprimer", 100, function()
            send("DeleteConfig", { VehicleId = vehicle.Id, Index = index })
        end, configuration ~= nil and inGarage == true)
    end
end

local function renderInvitations()
    local properties = state.Properties or {}
    heading("Inviter un joueur présent sur ce serveur")
    local target = properties[1]
    if target == nil then
        line("Aucune propriété.")
        return
    end
    line("Propriété : " .. target.Label .. " • durée : 1 h • aucune modification permise aux visiteurs")
    for _, other in Players:GetPlayers() do
        if other ~= player then
            local item = row()
            local function invite(drive: boolean)
                local payload = { PropertyId = target.Id, GuestUserId = other.UserId, Visit = true }
                payload.Drive = drive
                payload.DurationS = 3600
                send("Invite", payload)
            end
            button(item, other.DisplayName .. " : visite", 220, function()
                invite(false)
            end)
            button(item, "visite + conduite", 180, function()
                invite(true)
            end)
        end
    end
    heading("Invitations")
    for _, invitation in state.Invitations or {} do
        local item = row()
        make("TextLabel", {
            Size = UDim2.new(0, 420, 1, 0),
            BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(220, 226, 236),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = string.format(
                "%s • %s%s • %s",
                invitation.GuestName or ("joueur " .. invitation.GuestUserId),
                if invitation.Visit then "visite" else "",
                if invitation.Drive then " + conduite" else "",
                if invitation.Active
                    then string.format(
                        "expire dans %d min",
                        math.max(0, (invitation.ExpiresAt - (state.Now or 0)) // 60)
                    )
                    else "inactive"
            ),
        }, item)
        button(item, "Révoquer", 110, function()
            send("RevokeInvite", { InvitationId = invitation.Id })
        end, invitation.Active)
    end
end

function render()
    if not panel then
        return
    end
    for name, item in tabButtons do
        item.BackgroundColor3 = if name == tab then Color3.fromRGB(80, 130, 210) else Color3.fromRGB(44, 52, 66)
    end
    clear()
    order = 0
    if state == nil or state.Vehicles == nil then
        line(Text.text((state and state.State) or "Loading"))
        return
    end
    if tab == "Collection" then
        renderCollection()
    elseif tab == "Véhicule" then
        renderVehicle()
    elseif tab == "Propriétés" then
        renderProperties()
    elseif tab == "Préparation" then
        renderPreparation()
    elseif tab == "Configurations" then
        renderConfigurations()
    else
        renderInvitations()
    end
    if (state.Pending or 0) > 0 then
        line(string.format("%d opération(s) en attente de confirmation de sauvegarde.", state.Pending))
    end
end

-- Lot 0.7 : ouverture, fermeture et focus par le gestionnaire commun (UIManager).
local function show()
    panel.Visible = true
    send("Snapshot")
end

local function hide()
    panel.Visible = false
end

local function open(which: string?)
    if which then
        tab = which
    end
    if UIManager.isOpen("Garage") then
        render()
    else
        UIManager.open("Garage")
    end
end

local function toggle()
    UIManager.toggle("Garage")
end

local function updateBadge()
    local value = player:GetAttribute("AWProfileState")
    badge.Text = Text.text(if type(value) == "string" then value else "Loading")
end

function GaragePanel.start()
    local folder = ReplicatedStorage:WaitForChild(ProgressionProtocol.FolderName)
    request = folder:WaitForChild(ProgressionProtocol.Request) :: RemoteFunction
    local pushEvent = folder:WaitForChild(ProgressionProtocol.Push) :: RemoteEvent

    gui = make(
        "ScreenGui",
        { Name = "AWProgression", ResetOnSpawn = false, IgnoreGuiInset = false },
        player:WaitForChild("PlayerGui")
    )
    badge = make("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 64),
        Size = UDim2.fromOffset(360, 26),
        BackgroundColor3 = Color3.fromRGB(18, 24, 33),
        BackgroundTransparency = 0.2,
        TextColor3 = Color3.fromRGB(235, 242, 249),
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        Text = "",
    }, gui)
    panel = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.52),
        Size = UDim2.fromOffset(900, 520),
        BackgroundColor3 = Color3.fromRGB(24, 30, 40),
        BackgroundTransparency = 0.05,
        Visible = false,
    }, gui)
    make("UICorner", { CornerRadius = UDim.new(0, 10) }, panel)
    local tabs = make(
        "Frame",
        { Size = UDim2.new(1, -16, 0, 36), Position = UDim2.fromOffset(8, 8), BackgroundTransparency = 1 },
        panel
    )
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, tabs)
    for index, name in TABS do
        local item = make("TextButton", {
            Size = UDim2.fromOffset(130, 32),
            BackgroundColor3 = Color3.fromRGB(44, 52, 66),
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Font = Enum.Font.GothamMedium,
            TextSize = 14,
            Text = name,
            LayoutOrder = index,
        }, tabs)
        make("UICorner", { CornerRadius = UDim.new(0, 6) }, item)
        item.Activated:Connect(function()
            tab = name
            render()
        end)
        tabButtons[name] = item
    end
    local close = make("TextButton", {
        Size = UDim2.fromOffset(60, 32),
        BackgroundColor3 = Color3.fromRGB(120, 50, 50),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        Text = "Fermer",
        LayoutOrder = 99,
    }, tabs)
    close.Activated:Connect(toggle)
    body = make("ScrollingFrame", {
        Position = UDim2.fromOffset(8, 52),
        Size = UDim2.new(1, -16, 1, -96),
        BackgroundTransparency = 1,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 8,
    }, panel)
    make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, body)
    footer = make("TextLabel", {
        Position = UDim2.new(0, 12, 1, -38),
        Size = UDim2.new(1, -24, 0, 30),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(255, 214, 120),
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "",
    }, panel)

    player:GetAttributeChangedSignal("AWProfileState"):Connect(updateBadge)
    updateBadge()

    pushEvent.OnClientEvent:Connect(function(kind: any, data: any)
        if kind == "Snapshot" and type(data) == "table" then
            state = data
            render()
        elseif kind == "Confirmed" and type(data) == "table" then
            state = data.Snapshot or state
            setFooter(Text.text("Confirmed"))
            render()
        elseif kind == "EntranceOffer" and type(data) == "table" then
            entranceOffer = data
            open("Propriétés")
        elseif kind == "Open" and type(data) == "table" then
            open(if data.Tab == "Garage" then "Préparation" else nil)
        elseif kind == "Notice" and type(data) == "string" then
            setFooter(Text.text(data))
            badge.Text = Text.text(data)
        end
    end)

    -- Raccourci P (manette : Select) : InputRouter, lot 0.7.
    UIManager.register({
        Name = "Garage",
        Kind = "Modal",
        Full = true,
        Open = show,
        Close = hide,
        Focus = function()
            return tabButtons[tab]
        end,
    })
end

return table.freeze(GaragePanel)
