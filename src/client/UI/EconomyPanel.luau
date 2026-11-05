--!strict
--[[
    Interface PROVISOIRE de l'économie (lot 0.5) : portefeuille et historique,
    réputation, métiers et mission en cours, concession, marché, immobilier,
    services (pièces, entretien, énergie). Le smartphone définitif arrive au
    lot 0.7 : présentation sobre, navigable au clavier/souris et à la manette.

    Toute opération financière suit le même parcours : DEVIS (calcul serveur,
    rien n'est modifié) → CONFIRMATION explicite → état RÉEL renvoyé par le
    serveur (confirmée, en attente / récupérable, refusée). Aucune réussite
    n'est affichée avant la réponse. Confirmations bloquées en mouvement, sans
    jamais freiner la voiture. Touche : J (manette : clic du stick droit).
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyProtocol = require(Shared:WaitForChild("Economy"):WaitForChild("EconomyProtocol"))
local Jobs = require(Shared:WaitForChild("Economy"):WaitForChild("Jobs"))
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))

local Text = require(script.Parent.ProgressionMessages)

local EconomyPanel = {}

local player = Players.LocalPlayer
local S = 1 / Constants.MetersPerStud
local TABS = { "Portefeuille", "Métiers", "Concession", "Marché", "Immobilier", "Services" }

local request: RemoteFunction
local panel: Frame
local body: ScrollingFrame
local footer: TextLabel
local missionLabel: TextLabel
local tabButtons: { [string]: TextButton } = {}
local state: any = nil
local tab = "Portefeuille"
local busy = false
local pending: any = nil -- opération en attente de confirmation (devis affiché)
local beacon: BasePart? = nil
local beaconTag: BillboardGui? = nil
local guideFrame: Frame
local guideArrow: TextLabel
local guideText: TextLabel
local missionPoint: { X: number, Z: number }? = nil -- étape en cours, en mètres
local groundCheckAt = 0
local listPrice = 20_000

local function make(className: string, props: { [string]: any }, parent: Instance?): any
    local item = Instance.new(className)
    for key, value in props do
        (item :: any)[key] = value
    end
    item.Parent = parent
    return item
end

local function credits(amount: number?): string
    if amount == nil then
        return "—"
    end
    local text = tostring(math.floor(amount))
    local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1 ")))
    return (string.gsub(formatted, "^%s+", "")) .. " cr"
end

local render: () -> ()

local function seatedAndMoving(): boolean
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local seat = humanoid and humanoid.SeatPart
    return seat ~= nil and seat.AssemblyLinearVelocity.Magnitude * Constants.MetersPerStud > 1
end

local function invoke(action: string, payload: any?): any
    local ok, response = pcall(function()
        return request:InvokeServer(action, payload or {})
    end)
    if not ok or type(response) ~= "table" then
        return { Status = "Error", Error = "ServerUnreachable" }
    end
    if response.Snapshot then
        state = response.Snapshot
    end
    return response
end

local STATUS_TEXT = {
    Confirmed = "Confirmée (écriture durable).",
    Pending = "En attente de confirmation — l'opération est suivie et récupérable.",
    Duplicate = "Déjà effectuée (demande répétée ignorée).",
    Ok = "Fait.",
}

local function describe(response: any): string
    if response.Status == "Rejected" or response.Status == "Unavailable" or response.Status == "Error" then
        return "Refusée : " .. Text.text(response.Error)
    end
    return STATUS_TEXT[response.Status] or tostring(response.Status)
end

-- Exécute une opération sensible (identifiant de demande unique).
local function execute(action: string, payload: any)
    if busy then
        return
    end
    if seatedAndMoving() then
        footer.Text = Text.text("MenuWhileMoving")
        return
    end
    busy = true
    payload.RequestId = HttpService:GenerateGUID(false)
    footer.Text = "Demande envoyée…"
    local response = invoke(action, payload)
    busy = false
    pending = nil
    footer.Text = describe(response)
    render()
end

-- Devis puis confirmation.
local function quote(label: string, action: string, payload: any, quoteArgs: any)
    if busy then
        return
    end
    busy = true
    local response = invoke("Quote", { Operation = action, Args = quoteArgs or payload })
    busy = false
    if response.Status ~= "Ok" then
        footer.Text = describe(response)
        return
    end
    pending = { Label = label, Action = action, Payload = payload, Quote = response.Result }
    render()
end

local function simple(action: string, payload: any?)
    if busy then
        return
    end
    busy = true
    local response = invoke(action, payload)
    busy = false
    footer.Text = describe(response)
    render()
end

-- ======================== Éléments ========================

local order = 0
local function line(text: string, bold: boolean?)
    order += 1
    make("TextLabel", {
        Size = UDim2.new(1, -8, 0, if bold then 26 else 22),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(230, 236, 244),
        Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham,
        TextSize = if bold then 17 else 15,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = text,
        LayoutOrder = order,
    }, body)
end

local function row(): Frame
    order += 1
    local frame =
        make("Frame", { Size = UDim2.new(1, -8, 0, 32), BackgroundTransparency = 1, LayoutOrder = order }, body)
    make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, frame)
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

local function label(parent: Instance, text: string, width: number)
    make("TextLabel", {
        Size = UDim2.new(0, width, 1, 0),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(215, 222, 232),
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = text,
    }, parent)
end

-- ======================== Onglets ========================

local function renderWallet()
    local wallet = state.Wallet
    line(string.format("Solde : %s  •  réservé : %s", credits(wallet.Balance), credits(wallet.Reserved)), true)
    line(string.format("Total gagné %s  •  total dépensé %s", credits(wallet.Earned), credits(wallet.Spent)))
    local rep = state.Reputation
    line(
        string.format(
            "Réputation : %s (niveau %d/5) — %d points, %d %% vers le niveau suivant",
            rep.Name,
            rep.Level,
            rep.Points,
            math.floor(rep.Progress * 100)
        )
    )
    if (state.PendingTransfers or 0) > 0 then
        line(
            string.format(
                "%d achat(s) sur le marché en cours de finalisation (fonds réservés, récupérables).",
                state.PendingTransfers
            )
        )
    end
    line("Historique récent", true)
    for _, entry in state.Ledger or {} do
        line(
            string.format(
                "%s  %s%s  (%s)  solde %s",
                os.date("%H:%M", entry.At),
                if entry.Amount >= 0 then "+" else "",
                credits(entry.Amount),
                entry.Kind,
                credits(entry.Balance)
            )
        )
    end
end

-- Nom affiché d'un métier (le serveur envoie l'identifiant technique).
local function jobLabel(id: any): string
    local job = if type(id) == "string" then Jobs.get(id) else nil
    return if job then job.Label else tostring(id)
end

local function renderJobs()
    local mission = state.Mission
    if mission then
        line(
            string.format(
                "Mission en cours : %s — étape %d/%d : %s",
                jobLabel(mission.Job),
                mission.StepIndex,
                mission.Steps,
                mission.Label
            ),
            true
        )
        line(
            string.format(
                "Temps restant %d s%s%s",
                math.floor(mission.TimeLeft),
                if mission.Premium then " • premium" else "",
                if mission.Professional then " • véhicule professionnel prêté" else ""
            )
        )
        local actions = row()
        button(actions, "Abandonner (sans paiement)", 260, function()
            simple("AbandonMission")
        end)
        return
    end
    line("Choisissez un métier : la mission est générée par le serveur.", true)
    for _, job in state.Jobs or {} do
        local item = row()
        button(item, job.Label, 260, function()
            simple("StartMission", { Job = job.Id })
        end)
        label(
            item,
            string.format(
                "%s • %d réussie(s) • %s",
                if job.Vehicle == "Own"
                    then "votre véhicule"
                    elseif job.Vehicle == "Provided" then "véhicule fourni"
                    else "véhicule pro si besoin",
                job.Completed,
                job.Description
            ),
            560
        )
    end
end

local function renderDealer()
    local context = state.Context or {}
    line(
        if context.Kind == "Dealership"
            then "Concession : " .. context.Label
            else "Rendez-vous dans une concession pour acheter ou faire reprendre un véhicule.",
        true
    )
    line("Catalogue de travail (modèles PROVISOIRES) — 18 emplacements", true)
    for _, entry in state.Catalog or {} do
        local item = row()
        label(
            item,
            string.format(
                "%s (%s) — %s%s",
                entry.Name,
                entry.Category,
                credits(entry.Price),
                if entry.Availability == "Reserved"
                    then " • emplacement réservé"
                    elseif not entry.Purchasable then " • non achetable ici"
                    else ""
            ),
            520
        )
        button(item, "Devis d'achat", 160, function()
            quote("Achat de " .. entry.Name, "BuyVehicle", { CatalogId = entry.Id })
        end, entry.Purchasable and context.Kind == "Dealership")
    end
    line("Reprise de vos véhicules (≈ 60 % du prix neuf, selon l'état)", true)
    for _, vehicle in state.Vehicles or {} do
        local item = row()
        label(
            item,
            string.format(
                "%s — %s",
                vehicle.Name,
                if vehicle.TradeIn then credits(vehicle.TradeIn) else Text.text(vehicle.TradeInBlocked)
            ),
            520
        )
        button(item, "Devis de reprise", 160, function()
            quote("Reprise de " .. vehicle.Name, "TradeIn", { VehicleId = vehicle.Id })
        end, vehicle.TradeIn ~= nil and context.Kind == "Dealership")
    end
end

local function renderMarket()
    line("Annonces (commission de 5 % à la charge du vendeur)", true)
    for _, listing in state.Listings or {} do
        local item = row()
        label(
            item,
            string.format(
                "%s — %s • %.0f km • état %d %%%s",
                listing.Model,
                credits(listing.Price),
                listing.OdometerKm,
                math.floor(listing.Condition * 100),
                if listing.Mine then " • votre annonce" else ""
            ),
            520
        )
        if listing.Mine then
            button(item, "Retirer l'annonce", 160, function()
                simple("CancelListing", { ListingId = listing.Id })
            end)
        else
            button(item, "Devis d'achat", 160, function()
                quote("Achat d'occasion : " .. listing.Model, "BuyListing", { ListingId = listing.Id })
            end)
        end
    end
    line("Mettre en vente (exemplaire cessible, non sorti)", true)
    local priceRow = row()
    button(priceRow, "− 1 000", 90, function()
        listPrice = math.max(500, listPrice - 1000)
        render()
    end)
    label(priceRow, "Prix demandé : " .. credits(listPrice), 220)
    button(priceRow, "+ 1 000", 90, function()
        listPrice += 1000
        render()
    end)
    for _, vehicle in state.Vehicles or {} do
        local item = row()
        label(item, vehicle.Name .. (if vehicle.Listed then " • en vente" else ""), 520)
        button(item, "Devis de mise en vente", 200, function()
            quote("Mise en vente de " .. vehicle.Name, "ListVehicle", { VehicleId = vehicle.Id, Price = listPrice })
        end, not vehicle.Listed and vehicle.TradeIn ~= nil)
    end
end

local function renderRealEstate()
    line("Vos propriétés (revente : 70 % du prix payé, 40 % des agrandissements, 60 % des modules)", true)
    for _, property in state.Properties or {} do
        local item = row()
        label(
            item,
            string.format(
                "%s (%s) • niveau %d/%d",
                property.Label,
                property.Category,
                property.GarageLevel,
                property.MaxLevel
            ),
            380
        )
        button(item, "Agrandir", 110, function()
            quote("Agrandissement : " .. property.Label, "UpgradeGarage", { PropertyId = property.Id })
        end, property.GarageLevel < property.MaxLevel)
        button(item, "Revendre", 110, function()
            quote("Revente : " .. property.Label, "SellProperty", { PropertyId = property.Id })
        end, property.Sellable)
        local modules = row()
        for _, module in state.Modules or {} do
            if property.Modules[module.Id] == nil then
                button(modules, module.Label .. " " .. credits(module.Price), 210, function()
                    quote("Module " .. module.Label, "BuyModule", { PropertyId = property.Id, ModuleId = module.Id })
                end)
            end
        end
    end
    line("Biens en vente (achat sur place, à l'entrée du bien ; prix provisoires)", true)
    for _, offer in state.Offers or {} do
        local item = row()
        label(item, string.format("%s (%s) — %s", offer.Label, offer.Category, credits(offer.Price)), 520)
        button(item, "Devis d'achat", 160, function()
            quote("Achat : " .. offer.Label, "BuyProperty", { OfferId = offer.Id })
        end)
    end
end

local function renderServices()
    local context = state.Context or {}
    line("Lieu : " .. (context.Label or "aucun service à proximité"), true)
    local actions = row()
    button(actions, "Faire le plein / recharger", 220, function()
        execute("StartEnergy", {})
    end, context.Kind == "Service" and state.Energy == nil)
    button(actions, "Arrêter et payer", 160, function()
        simple("StopEnergy")
    end, state.Energy ~= nil)
    button(actions, "Devis de lavage", 160, function()
        quote("Lavage", "Wash", {})
    end, context.Kind == "Service")
    button(actions, "Devis de réparation", 180, function()
        quote("Réparation", "Repair", {})
    end, context.Kind == "PublicGarage")
    if state.Energy then
        line(
            string.format(
                "Livraison en cours : %.1f / %.1f unités (paiement au réel à la fin)",
                state.Energy.Delivered,
                state.Energy.MaxUnits
            )
        )
    end
    line("Pièces (garage public) — revente à 75 % du prix payé", true)
    for _, part in state.Parts or {} do
        local item = row()
        label(item, part.Label .. " — " .. credits(part.Price), 420)
        button(item, "Devis d'achat", 160, function()
            quote("Achat : " .. part.Label, "BuyPart", { PartId = part.Id })
        end, context.Kind == "PublicGarage")
    end
    for _, owned in state.OwnedParts or {} do
        if not owned.Installed and owned.Resale > 0 then
            local item = row()
            label(item, owned.PartId .. " (détachée) — reprise " .. credits(owned.Resale), 420)
            button(item, "Devis de revente", 160, function()
                quote("Revente : " .. owned.PartId, "SellPart", { PartItemId = owned.Id })
            end, context.Kind == "PublicGarage")
        end
    end
end

local function renderConfirmation()
    local q = pending.Quote or {}
    line("Confirmation : " .. pending.Label, true)
    if q.Debit then
        line("Montant débité : " .. credits(q.Debit))
    end
    if q.Credit then
        line("Montant crédité : " .. credits(q.Credit))
    end
    if q.Fee then
        line(string.format("Prix %s • commission %s • net %s", credits(q.Price), credits(q.Fee), credits(q.Net)))
    end
    local actions = row()
    button(actions, "Confirmer", 160, function()
        execute(pending.Action, table.clone(pending.Payload))
    end, not seatedAndMoving())
    button(actions, "Annuler", 120, function()
        pending = nil
        render()
    end)
end

function render()
    if not panel then
        return
    end
    for name, item in tabButtons do
        item.BackgroundColor3 = if name == tab then Color3.fromRGB(80, 130, 210) else Color3.fromRGB(44, 52, 66)
    end
    for _, child in body:GetChildren() do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
    order = 0
    if state == nil or state.Wallet == nil then
        line(Text.text((state and state.State) or "Loading"))
        return
    end
    if pending then
        renderConfirmation()
        return
    end
    if tab == "Portefeuille" then
        renderWallet()
    elseif tab == "Métiers" then
        renderJobs()
    elseif tab == "Concession" then
        renderDealer()
    elseif tab == "Marché" then
        renderMarket()
    elseif tab == "Immobilier" then
        renderRealEstate()
    else
        renderServices()
    end
end

-- Repère local de l'étape en cours (visible seulement par ce joueur) : une
-- colonne lumineuse posée au sol et une étiquette toujours visible, même à
-- plusieurs kilomètres (la colonne seule devient invisible au-delà d'environ
-- 1 km). Hauteur en studs ; le sol est retrouvé par lancer de rayon.
local BEACON_HEIGHT = 400

local function distanceText(meters: number): string
    if meters < 1000 then
        return string.format("%d m", math.floor(meters / 10 + 0.5) * 10)
    end
    return (string.gsub(string.format("%.1f km", meters / 1000), "%.", ","))
end

-- Altitude du sol sous le point (studs). Sans réponse (zone pas encore
-- chargée), 0 : on réessaie régulièrement.
local function groundY(x: number, z: number): number
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignored: { Instance } = { Workspace.CurrentCamera :: Instance }
    if player.Character then
        table.insert(ignored, player.Character)
    end
    params.FilterDescendantsInstances = ignored
    local hit = Workspace:Raycast(Vector3.new(x, 3000, z), Vector3.new(0, -6000, 0), params)
    return if hit then hit.Position.Y else 0
end

local function placeBeacon(point: { X: number, Z: number })
    if beacon == nil then
        local part = Instance.new("Part")
        part.Name = "RepereMission"
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.CastShadow = false
        part.Material = Enum.Material.Neon
        part.Color = Color3.fromRGB(255, 200, 40)
        part.Transparency = 0.35
        part.Shape = Enum.PartType.Cylinder
        part.Size = Vector3.new(BEACON_HEIGHT, 8, 8)
        part.Parent = Workspace.CurrentCamera
        beacon = part
        beaconTag = make("BillboardGui", {
            Name = "RepereMissionEtiquette",
            Adornee = part,
            AlwaysOnTop = true,
            LightInfluence = 0,
            Size = UDim2.fromOffset(150, 34),
            StudsOffsetWorldSpace = Vector3.new(0, BEACON_HEIGHT / 2 + 8, 0),
            ResetOnSpawn = false,
        }, player:WaitForChild("PlayerGui"))
        make("TextLabel", {
            Name = "Distance",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.fromRGB(40, 32, 12),
            BackgroundTransparency = 0.2,
            TextColor3 = Color3.fromRGB(255, 220, 120),
            Font = Enum.Font.GothamBold,
            TextSize = 16,
            Text = "",
        }, beaconTag)
    end
    local x, z = point.X * S, point.Z * S
    local y = groundY(x, z)
    groundCheckAt = os.clock()
    -- Le cylindre est couché sur X : rotation d'un quart de tour pour le dresser.
    local part = beacon :: BasePart
    part.CFrame = CFrame.new(x, y + BEACON_HEIGHT / 2, z) * CFrame.Angles(0, 0, math.pi / 2)
end

local function removeBeacon()
    if beacon then
        beacon:Destroy()
        beacon = nil
    end
    if beaconTag then
        beaconTag:Destroy()
        beaconTag = nil
    end
end

local function updateMission()
    local mission = state and state.Mission
    if mission then
        missionLabel.Visible = true
        missionLabel.Text = string.format(
            "%s — %s (%d/%d) • %d s",
            jobLabel(mission.Job),
            mission.Label,
            mission.StepIndex,
            mission.Steps,
            math.floor(mission.TimeLeft)
        )
    else
        missionLabel.Visible = false
    end
    local point = mission and mission.Point
    local changed = point == nil
        or missionPoint == nil
        or point.X ~= (missionPoint :: any).X
        or point.Z ~= (missionPoint :: any).Z
    missionPoint = point
    if point then
        if changed or beacon == nil then
            placeBeacon(point)
        end
    else
        removeBeacon()
        guideFrame.Visible = false
    end
end

-- Guidage à chaque image : distance à vol d'oiseau et flèche orientée par
-- rapport à la caméra (vers le haut = devant soi).
local function updateGuide()
    local point = missionPoint
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
    local camera = Workspace.CurrentCamera
    if point == nil or root == nil or camera == nil then
        guideFrame.Visible = false
        return
    end
    local here = root.Position
    local dx, dz = point.X * S - here.X, point.Z * S - here.Z
    local meters = math.sqrt(dx * dx + dz * dz) * Constants.MetersPerStud
    local look, right = camera.CFrame.LookVector, camera.CFrame.RightVector
    local angle = math.atan2(dx * right.X + dz * right.Z, dx * look.X + dz * look.Z)
    guideFrame.Visible = true
    guideArrow.Rotation = math.deg(angle)
    guideText.Text = "Objectif à " .. distanceText(meters)
    if beaconTag then
        (beaconTag:FindFirstChild("Distance") :: TextLabel).Text = distanceText(meters)
    end
    -- Le sol d'une zone lointaine peut n'être chargé qu'en s'approchant.
    if os.clock() - groundCheckAt > 2 then
        placeBeacon(point)
    end
end

local function toggle()
    if panel.Visible then
        panel.Visible = false
        GuiService.SelectedObject = nil
        return
    end
    panel.Visible = true
    simple("Snapshot")
    GuiService.SelectedObject = tabButtons[tab]
end

function EconomyPanel.start()
    local folder = ReplicatedStorage:WaitForChild(EconomyProtocol.FolderName)
    request = folder:WaitForChild(EconomyProtocol.Request) :: RemoteFunction
    local pushEvent = folder:WaitForChild(EconomyProtocol.Push) :: RemoteEvent
    local gui = make("ScreenGui", { Name = "AWEconomy", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))
    missionLabel = make("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 64),
        Size = UDim2.fromOffset(620, 28),
        BackgroundColor3 = Color3.fromRGB(40, 32, 12),
        BackgroundTransparency = 0.15,
        TextColor3 = Color3.fromRGB(255, 220, 120),
        Font = Enum.Font.GothamMedium,
        TextSize = 15,
        Visible = false,
        Text = "",
    }, gui)
    guideFrame = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 96),
        Size = UDim2.fromOffset(240, 34),
        BackgroundColor3 = Color3.fromRGB(40, 32, 12),
        BackgroundTransparency = 0.15,
        Visible = false,
    }, gui)
    guideArrow = make("TextLabel", {
        Size = UDim2.fromOffset(34, 34),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(255, 200, 40),
        Font = Enum.Font.GothamBold,
        TextSize = 24,
        Text = "▲",
    }, guideFrame)
    guideText = make("TextLabel", {
        Position = UDim2.fromOffset(38, 0),
        Size = UDim2.new(1, -44, 1, 0),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(255, 220, 120),
        Font = Enum.Font.GothamMedium,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "",
    }, guideFrame)
    RunService.RenderStepped:Connect(updateGuide)
    panel = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.52),
        Size = UDim2.fromOffset(940, 540),
        BackgroundColor3 = Color3.fromRGB(24, 30, 40),
        Visible = false,
    }, gui)
    make("UICorner", { CornerRadius = UDim.new(0, 10) }, panel)
    local tabsProps = { Size = UDim2.new(1, -16, 0, 36), Position = UDim2.fromOffset(8, 8), BackgroundTransparency = 1 }
    local tabs = make("Frame", tabsProps, panel)
    local layoutProps = {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }
    make("UIListLayout", layoutProps, tabs)
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
        item.Activated:Connect(function()
            tab = name
            pending = nil
            render()
        end)
        tabButtons[name] = item
    end
    local close = make("TextButton", {
        Size = UDim2.fromOffset(70, 32),
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

    pushEvent.OnClientEvent:Connect(function(kind: any, data: any)
        if kind == "Snapshot" and type(data) == "table" then
            state = data
            updateMission()
            if panel.Visible then
                render()
            end
        elseif kind == "MissionEnded" and type(data) == "table" then
            footer.Text = if data.Completed
                then string.format(
                    "Mission réussie : %s, +%d réputation (%s).",
                    credits(data.Credits),
                    data.Reputation,
                    STATUS_TEXT[data.Status] or data.Status
                )
                else "Mission échouée ou abandonnée : " .. Text.text(data.Reason)
        elseif kind == "Open" and type(data) == "table" then
            if not panel.Visible then
                toggle()
            end
            if type(data.Tab) == "string" then
                tab = data.Tab
                render()
            end
        elseif kind == "EnergyEnded" and type(data) == "table" then
            footer.Text = string.format(
                "Énergie livrée : %.1f unités, payé %s (%s).",
                data.Delivered,
                credits(data.Cost),
                STATUS_TEXT[data.Status] or data.Status
            )
        end
    end)
    -- Rafraîchissement léger de la mission en cours (temps restant).
    task.spawn(function()
        while true do
            task.wait(2)
            if state and state.Mission then
                invoke("Snapshot")
                updateMission()
            end
        end
    end)
    ContextActionService:BindAction("AWEconomyMenu", function(_, inputState)
        if inputState == Enum.UserInputState.Begin then
            toggle()
        end
        return Enum.ContextActionResult.Sink
    end, false, Enum.KeyCode.J, Enum.KeyCode.ButtonR3)
end

return table.freeze(EconomyPanel)
