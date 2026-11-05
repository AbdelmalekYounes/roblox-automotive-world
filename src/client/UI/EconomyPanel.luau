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
    Lot 0.8 : libellés traduits à l'affichage (Localization.tr, dictionnaire
    PanelTexts), montants et distances au format de la langue ; identifiants
    d'onglet inchangés (français) ; redessin au changement de langue.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyProtocol = require(Shared:WaitForChild("Economy"):WaitForChild("EconomyProtocol"))
local Jobs = require(Shared:WaitForChild("Economy"):WaitForChild("Jobs"))
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))
local Localization = require(Shared:WaitForChild("UI"):WaitForChild("Localization"))

local Text = require(script.Parent.ProgressionMessages)
local UIManager = require(script.Parent.UIManager)
local UITheme = require(script.Parent.UITheme)
local Tokens =
    require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("DesignTokens"))
local InputRouter = require(script.Parent.InputRouter)
local GPSController = require(script.Parent.GPSController)
local PanelKit = require(script.Parent.PanelKit)

local EconomyPanel = {}

-- Texte joueur : le français sert de clé, l'anglais vient de PanelTexts.
local tr = Localization.tr

local player = Players.LocalPlayer
local S = 1 / Constants.MetersPerStud
-- Identifiants d'onglet (français, aussi envoyés par le serveur) : affichés via tr().
local TABS = { "Portefeuille", "Métiers", "Concession", "Marché", "Immobilier", "Services" }

local request: RemoteFunction
local shell: PanelKit.Shell
local panel: Frame
local body: ScrollingFrame
local missionLabel: TextLabel
local state: any = nil
local tab = "Portefeuille"
local busy = false
local pending: any = nil -- opération en attente de confirmation (devis affiché)
local beacon: BasePart? = nil
local beaconTag: BillboardGui? = nil
local guideFrame: Frame
local guideArrow: Frame
local guideText: TextLabel
local missionPoint: { X: number, Z: number }? = nil -- étape en cours, en mètres
local groundCheckAt = 0
local listPrice = 20_000

local function make(className: string, props: { [string]: any }, parent: Instance?): any
    local item = Instance.new(className)
    for key, value in props do
        (item :: any)[key] = value
    end
    -- Lot UI-04 : repères Gotham convertis en Titillium Web (système de conception V1.2), même graisse.
    if props.Font and (item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox")) then
        UITheme.applyFont(item :: any, props.Font)
    end
    item.Parent = parent
    return item
end

local function credits(amount: number?): string
    if amount == nil then
        return "—"
    end
    -- Séparateur de milliers selon la langue (espace en français, virgule en
    -- anglais) ; le signe est traité à part pour ne jamais produire « -,500 ».
    local value = math.floor(amount)
    local sign = if value < 0 then "-" else ""
    return sign .. Localization.amount(math.abs(value)) .. " cr"
end

local render: () -> ()

local function seatedAndMoving(): boolean
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local seat = humanoid and humanoid.SeatPart
    return seat ~= nil and seat.AssemblyLinearVelocity.Magnitude * Constants.MetersPerStud > 1
end

local function invoke(action: string, payload: any?): any
    local ok, response = PanelKit.invoke(request, action, payload or {})
    if not ok or type(response) ~= "table" then
        return { Status = "Error", Error = "ServerUnreachable" }
    end
    if response.Snapshot then
        state = response.Snapshot
    end
    return response
end

-- Libellés français, traduits au moment de l'affichage (table évaluée une fois).
local STATUS_TEXT = {
    Confirmed = "Confirmée (écriture durable).",
    Pending = "En attente de confirmation — l'opération est suivie et récupérable.",
    Duplicate = "Déjà effectuée (demande répétée ignorée).",
    Ok = "Fait.",
}

local function describe(response: any): string
    -- Hors ligne : ni « refusée » ni « confirmée » (le serveur n'a pas répondu).
    if response.Status == "Error" then
        return tr("Serveur injoignable : rien n'est confirmé.")
    end
    if response.Status == "Rejected" or response.Status == "Unavailable" then
        return tr("Refusée : %s", Text.text(response.Error))
    end
    return tr(STATUS_TEXT[response.Status] or tostring(response.Status))
end

-- État affiché d'une réponse : confirmée (vert), en attente et récupérable (ambre), refusée (rouge), serveur
-- injoignable (hors ligne), information (répétée ignorée, lecture).
local function kindOf(response: any): string
    local status = response.Status
    if status == "Confirmed" then
        return "Confirmed"
    elseif status == "Pending" then
        return "Pending"
    elseif status == "Error" then
        return "Offline"
    elseif status == "Rejected" or status == "Unavailable" then
        return "Rejected"
    end
    return "Info"
end

local function report(response: any)
    shell:setStatus(kindOf(response), describe(response))
end

-- Exécute une opération sensible (identifiant de demande unique).
local function execute(action: string, payload: any)
    if busy then
        return
    end
    -- Lot 0.7 : confirmation seulement d'une pression neuve (jamais par un
    -- changement de périphérique ou une touche restée enfoncée).
    if not InputRouter.confirmAllowed() then
        shell:setStatus("Info", Text.text("ui.confirmAgain"))
        return
    end
    if seatedAndMoving() then
        shell:setStatus("Rejected", Text.text("MenuWhileMoving"))
        return
    end
    busy = true
    panel:SetAttribute("AWBusy", true)
    payload.RequestId = HttpService:GenerateGUID(false)
    shell:setStatus("Pending", tr("Demande envoyée…"))
    PanelKit.countSent(panel)
    local response = invoke(action, payload)
    busy = false
    panel:SetAttribute("AWBusy", false)
    pending = nil
    report(response)
    render()
end

local function askConfirmation()
    local q = pending.Quote or {}
    local lines = { tr("Confirmation : %s", pending.Label) }
    if q.Debit then
        table.insert(lines, tr("Montant débité : %s", credits(q.Debit)))
    end
    if q.Credit then
        table.insert(lines, tr("Montant crédité : %s", credits(q.Credit)))
    end
    if q.Fee then
        table.insert(
            lines,
            tr("Prix %s • commission %s • net %s", credits(q.Price), credits(q.Fee), credits(q.Net))
        )
    end
    local current = pending
    PanelKit.confirm(shell.Gui, table.concat(lines, "\n"), function()
        if pending == current then
            execute(current.Action, table.clone(current.Payload))
        end
    end, function()
        pending = nil
        render()
    end)
end

-- Devis puis confirmation (fenêtre modale protégée, montants calculés par le serveur).
local function quote(label: string, action: string, payload: any, quoteArgs: any)
    if busy then
        return
    end
    busy = true
    local response = invoke("Quote", { Operation = action, Args = quoteArgs or payload })
    busy = false
    if response.Status ~= "Ok" then
        report(response)
        return
    end
    pending = { Label = label, Action = action, Payload = payload, Quote = response.Result }
    InputRouter.armConfirm()
    -- Lot 0.9.1 (QA-F13, même cause) : le « Fait. » de la demande précédente laissait
    -- croire l'opération déjà faite pendant la confirmation.
    shell:setStatus(nil, "")
    askConfirmation()
end

local function simple(action: string, payload: any?, quiet: boolean?)
    if busy then
        return
    end
    busy = true
    -- Lot 0.9.1 (QA-F16) : une opération sensible (retrait d'annonce) envoyée sans
    -- identifiant de demande était toujours refusée (RequestIdInvalid) : « Retirer
    -- l'annonce » ne fonctionnait jamais. Identifiant ajouté pour toute opération sensible.
    local data: any = payload
    if EconomyProtocol.Sensitive[action] then
        local copy: { [string]: any } = if type(payload) == "table" then table.clone(payload) else {}
        copy.RequestId = HttpService:GenerateGUID(false)
        data = copy
    end
    PanelKit.countSent(panel)
    local response = invoke(action, data)
    busy = false
    if not quiet or kindOf(response) ~= "Info" then
        report(response)
    end
    render()
end

-- ======================== Éléments ========================

local function text(parent: Instance, value: string, style: string?, token: string?): TextLabel
    return PanelKit.text(shell, parent, value, style, token)
end

local function heading(value: string)
    PanelKit.heading(shell, body, value)
end

local function card(name: string?, accent: string?): Frame
    return PanelKit.card(shell, body, name, accent)
end

local function row(parent: Instance?): Frame
    return PanelKit.row(shell, parent or body)
end

local function button(
    parent: Instance,
    value: string,
    kind: PanelKit.ButtonKind,
    callback: () -> (),
    enabled: boolean?,
    reason: string?,
    name: string?
): TextButton
    return PanelKit.button(shell, parent, value, kind, callback, enabled, reason, name)
end

-- Grille de cartes (catalogue, annonces, biens) : 1 à 3 colonnes selon la largeur, hauteur automatique.
local function grid(name: string): Frame
    local width = require(script.Parent.Components).logicalSize(body).X - 56
    local columns = if width >= 1000 then 3 elseif width >= 640 then 2 else 1
    local frame = PanelKit.make("Frame", {
        Name = name,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = shell:next(),
    }, body)
    local layout = PanelKit.make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 12),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, frame);
    (layout :: any).Wraps = true
    frame:SetAttribute("AWColumns", columns)
    return frame
end

-- Carte de grille : largeur d'une colonne (la rangée passe à la ligne).
local function cell(parent: Frame, name: string, accent: string?): Frame
    local attribute = parent:GetAttribute("AWColumns")
    local columns: number = if type(attribute) == "number" then attribute else 1
    local inner = PanelKit.card(shell, parent, name, accent)
    local outer = inner.Parent :: Frame
    outer.Size = UDim2.new(1 / columns, -12 * (columns - 1) / columns, 0, 0)
    return inner
end

local function inService(context: any): boolean
    return context.Kind == "Service" or context.Kind == "PublicGarage" or context.Kind == "Dealership"
end

-- ======================== Onglets ========================

local function renderWallet()
    local wallet = state.Wallet
    PanelKit.cells(shell, body, {
        { tr("Solde"), credits(wallet.Balance), "AmberSoftText" },
        { tr("Réservé"), credits(wallet.Reserved) },
        { tr("Total gagné"), credits(wallet.Earned), "Ok" },
        { tr("Total dépensé"), credits(wallet.Spent) },
    }, "Portefeuille")
    local rep = state.Reputation
    local repCard = card("Reputation", "Amber")
    PanelKit.cardTitle(shell, repCard, tr("Réputation : %s", tr(rep.Name)), tr("niveau %d / 5", rep.Level))
    PanelKit.progress(shell, repCard, rep.Progress or 0)
    text(
        repCard,
        tr("%d points · %d %% vers le niveau suivant", rep.Points, math.floor((rep.Progress or 0) * 100)),
        "Body",
        "TextMuted"
    )
    if (state.PendingTransfers or 0) > 0 then
        PanelKit.notice(
            shell,
            body,
            "Warn",
            tr(
                "%d achat(s) sur le marché en cours de finalisation (fonds réservés, récupérables).",
                state.PendingTransfers
            )
        )
    end
    heading(tr("Historique récent"))
    local history = card("Historique")
    if #(state.Ledger or {}) == 0 then
        text(history, tr("Aucune opération."), "Body", "TextMuted")
    end
    for _, entry in state.Ledger or {} do
        PanelKit.keyValue(
            shell,
            history,
            string.format("%s · %s", os.date("%H:%M", entry.At) :: string, tostring(entry.Kind)),
            string.format(
                "%s%s · %s",
                if entry.Amount >= 0 then "+" else "",
                credits(entry.Amount),
                tr("solde %s", credits(entry.Balance))
            ),
            if entry.Amount >= 0 then "Ok" else "Text"
        )
    end
end

-- Nom affiché d'un métier (le serveur envoie l'identifiant technique).
local function jobLabel(id: any): string
    local job = if type(id) == "string" then Jobs.get(id) else nil
    return if job then tr(job.Label) else tostring(id)
end

-- Libellé d'étape de mission (texte français du serveur, parfois suivi d'un numéro).
local function stepLabel(value: any): string
    if type(value) ~= "string" then
        return tostring(value)
    end
    local prefix, number = string.match(value, "^(.-) (%d+)$")
    if prefix == "Livraison" then
        return tr("Livraison %s", number)
    elseif prefix == "Porte" then
        return tr("Porte %s", number)
    elseif prefix == "Point d'exploration" then
        return tr("Point d'exploration %s", number)
    end
    return tr(value)
end

local function renderJobs()
    local mission = state.Mission
    if mission then
        heading(tr("Mission en cours"))
        local box = card("MissionEnCours", "GpsCyan")
        PanelKit.cardTitle(
            shell,
            box,
            jobLabel(mission.Job),
            tr("étape %d / %d", mission.StepIndex, mission.Steps),
            "GpsCyan"
        )
        PanelKit.progress(shell, box, (mission.StepIndex - 1) / math.max(mission.Steps, 1), "GpsCyan")
        text(box, stepLabel(mission.Label), "Body")
        text(box, tr("Temps restant %d s", math.floor(mission.TimeLeft)), "Value", "TextMuted")
        local tags = row(box)
        if mission.Premium then
            PanelKit.tag(shell, tags, tr("premium"), "AmberSoftText")
        end
        if mission.Professional then
            PanelKit.tag(shell, tags, tr("véhicule professionnel prêté"))
        end
        local actions = row(box)
        button(actions, tr("Abandonner (sans paiement)"), "Revoke", function()
            PanelKit.confirm(shell.Gui, tr("Abandonner la mission ? Aucun paiement ne sera versé."), function()
                simple("AbandonMission")
            end)
        end, nil, nil, "Abandonner")
        return
    end
    heading(tr("Métiers"))
    text(body, tr("Choisissez un métier : la mission est générée par le serveur."), "Body", "TextMuted")
    local list = grid("Metiers")
    for _, job in state.Jobs or {} do
        local box = cell(list, "Metier_" .. tostring(job.Id))
        PanelKit.cardTitle(shell, box, tr(job.Label), tr("%d réussie(s)", job.Completed), "TextMuted")
        local tags = row(box)
        PanelKit.tag(
            shell,
            tags,
            if job.Vehicle == "Own"
                then tr("votre véhicule")
                elseif job.Vehicle == "Provided" then tr("véhicule fourni")
                else tr("véhicule pro si besoin")
        )
        text(box, tr(job.Description), "Body", "TextMuted")
        local actions = row(box)
        button(actions, tr("Démarrer"), "Primary", function()
            simple("StartMission", { Job = job.Id })
        end, nil, nil, "Demarrer")
    end
end

local function renderDealer()
    local context = state.Context or {}
    local here = context.Kind == "Dealership"
    if not here then
        PanelKit.notice(
            shell,
            body,
            "Warn",
            tr("Rendez-vous dans une concession pour acheter ou faire reprendre un véhicule.")
        )
    end
    heading(tr("Catalogue de travail (modèles PROVISOIRES) — 18 emplacements"))
    local list = grid("Catalogue")
    for _, entry in state.Catalog or {} do
        local reserved = entry.Availability == "Reserved"
        local box = cell(list, "Modele_" .. tostring(entry.Id), if reserved then nil else "Amber")
        PanelKit.cardTitle(shell, box, entry.Name, credits(entry.Price), "AmberSoftText")
        text(box, tr(entry.Category), "Body", "TextMuted")
        local tags = row(box)
        if reserved then
            PanelKit.tag(shell, tags, tr("emplacement réservé"))
        elseif not entry.Purchasable then
            PanelKit.tag(shell, tags, tr("non achetable ici"))
        else
            PanelKit.tag(shell, tags, tr("gamme proposée"), "AmberSoftText")
        end
        local actions = row(box)
        button(
            actions,
            tr("Devis d'achat"),
            "Secondary",
            function()
                quote(tr("Achat de %s", entry.Name), "BuyVehicle", { CatalogId = entry.Id })
            end,
            entry.Purchasable and here,
            if not here
                then tr("Exige d'être dans une concession")
                elseif not entry.Purchasable then tr("Non achetable ici")
                else nil,
            "DevisAchat"
        )
    end
    heading(tr("Reprise de vos véhicules (≈ 60 % du prix neuf, selon l'état)"))
    local trade = grid("Reprises")
    for _, vehicle in state.Vehicles or {} do
        local box = cell(trade, "Reprise_" .. tostring(vehicle.Id))
        PanelKit.cardTitle(
            shell,
            box,
            vehicle.Name,
            if vehicle.TradeIn then credits(vehicle.TradeIn) else nil,
            "AmberSoftText"
        )
        if not vehicle.TradeIn then
            text(box, Text.text(vehicle.TradeInBlocked), "Body", "TextMuted")
        end
        local actions = row(box)
        button(
            actions,
            tr("Devis de reprise"),
            "Secondary",
            function()
                quote(tr("Reprise de %s", vehicle.Name), "TradeIn", { VehicleId = vehicle.Id })
            end,
            vehicle.TradeIn ~= nil and here,
            if not here then tr("Exige d'être dans une concession") else nil,
            "DevisReprise"
        )
    end
end

local function renderMarket()
    heading(tr("Annonces (commission de 5 % à la charge du vendeur)"))
    local list = grid("Annonces")
    if #(state.Listings or {}) == 0 then
        PanelKit.notice(shell, body, "Neutral", tr("Aucune annonce."))
    end
    for _, listing in state.Listings or {} do
        local box = cell(list, "Annonce_" .. tostring(listing.Id), if listing.Mine then "Amber" else nil)
        PanelKit.cardTitle(shell, box, listing.Model, credits(listing.Price), "AmberSoftText")
        text(
            box,
            tr("%.0f km · état %d %%", listing.OdometerKm, math.floor(listing.Condition * 100)),
            "Value",
            "TextMuted"
        )
        local actions = row(box)
        if listing.Mine then
            PanelKit.tag(shell, actions, tr("votre annonce"), "AmberSoftText")
            button(actions, tr("Retirer l'annonce"), "Revoke", function()
                simple("CancelListing", { ListingId = listing.Id })
            end, nil, nil, "Retirer")
        else
            button(actions, tr("Devis d'achat"), "Secondary", function()
                quote(tr("Achat d'occasion : %s", listing.Model), "BuyListing", { ListingId = listing.Id })
            end, nil, nil, "DevisAchat")
        end
    end
    heading(tr("Mettre en vente (exemplaire cessible, non sorti)"))
    local sell = card("MiseEnVente")
    local priceRow = row(sell)
    button(priceRow, "- 1 000", "Secondary", function()
        listPrice = math.max(500, listPrice - 1000)
        render()
    end, nil, nil, "Moins")
    local priceLabel = PanelKit.make("TextLabel", {
        Name = "Prix",
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundTransparency = 1,
        Text = tr("Prix demandé : %s", credits(listPrice)),
        LayoutOrder = shell:next(),
    }, priceRow)
    priceLabel.FontFace = UITheme.face("Value")
    priceLabel.TextSize = UITheme.text(16)
    priceLabel.TextColor3 = PanelKit.color("AmberSoftText")
    button(priceRow, "+ 1 000", "Secondary", function()
        listPrice += 1000
        render()
    end, nil, nil, "Plus")
    for _, vehicle in state.Vehicles or {} do
        local line = PanelKit.make("Frame", {
            Name = "Vente_" .. tostring(vehicle.Id),
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = shell:next(),
        }, sell)
        PanelKit.make("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 10),
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, line)
        local nameLabel =
            PanelKit.text(shell, line, vehicle.Name .. (if vehicle.Listed then tr(" • en vente") else ""))
        nameLabel.Size = UDim2.new(0.5, 0, 0, 0)
        button(
            line,
            tr("Devis de mise en vente"),
            "Secondary",
            function()
                quote(
                    tr("Mise en vente de %s", vehicle.Name),
                    "ListVehicle",
                    { VehicleId = vehicle.Id, Price = listPrice }
                )
            end,
            not vehicle.Listed and vehicle.TradeIn ~= nil,
            if vehicle.Listed
                then tr("Déjà en vente")
                elseif vehicle.TradeIn == nil then tr("Exemplaire non cessible ou sorti")
                else nil,
            "DevisVente"
        )
    end
end

local function renderRealEstate()
    heading(tr("Vos propriétés (revente : 70 % du prix payé, 40 % des agrandissements, 60 % des modules)"))
    if #(state.Properties or {}) == 0 then
        PanelKit.notice(shell, body, "Neutral", tr("Aucune propriété."))
    end
    for _, property in state.Properties or {} do
        local box = card("Propriete_" .. tostring(property.Id), "Amber")
        PanelKit.cardTitle(
            shell,
            box,
            property.Label,
            tr("niveau %d / %d", property.GarageLevel, property.MaxLevel),
            "AmberSoftText"
        )
        text(box, tr(property.Category), "Body", "TextMuted")
        PanelKit.progress(shell, box, property.GarageLevel / math.max(property.MaxLevel, 1))
        local actions = row(box)
        button(actions, tr("Agrandir"), "Secondary", function()
            quote(tr("Agrandissement : %s", property.Label), "UpgradeGarage", { PropertyId = property.Id })
        end, property.GarageLevel < property.MaxLevel, tr("Niveau maximal atteint"), "Agrandir")
        button(actions, tr("Revendre"), "Revoke", function()
            quote(tr("Revente : %s", property.Label), "SellProperty", { PropertyId = property.Id })
        end, property.Sellable, tr("Propriété invendable"), "Revendre")
        local modules = row(box)
        for _, module in state.Modules or {} do
            if property.Modules[module.Id] == nil then
                button(modules, tr(module.Label) .. " · " .. credits(module.Price), "Secondary", function()
                    quote(
                        tr("Module %s", tr(module.Label)),
                        "BuyModule",
                        { PropertyId = property.Id, ModuleId = module.Id }
                    )
                end, nil, nil, "Module")
            end
        end
    end
    heading(tr("Biens en vente (achat sur place, à l'entrée du bien ; prix provisoires)"))
    local list = grid("Biens")
    for _, offer in state.Offers or {} do
        local box = cell(list, "Bien_" .. tostring(offer.Id))
        PanelKit.cardTitle(shell, box, offer.Label, credits(offer.Price), "AmberSoftText")
        text(box, tr(offer.Category), "Body", "TextMuted")
        local actions = row(box)
        button(actions, tr("Devis d'achat"), "Secondary", function()
            quote(tr("Achat : %s", offer.Label), "BuyProperty", { OfferId = offer.Id })
        end, nil, nil, "DevisAchat")
    end
end

local function renderServices()
    local context = state.Context or {}
    if not inService(context) then
        PanelKit.notice(
            shell,
            body,
            "Warn",
            tr("Aucun service à proximité : rendez-vous à une station, un lavage ou un garage public.")
        )
    end
    local box = card("Services", if inService(context) then "GpsCyan" else nil)
    PanelKit.cardTitle(shell, box, tr("Lieu : %s", context.Label or tr("aucun service à proximité")))
    local actions = row(box)
    button(
        actions,
        tr("Faire le plein / recharger"),
        "Primary",
        function()
            execute("StartEnergy", {})
        end,
        context.Kind == "Service" and state.Energy == nil,
        if context.Kind ~= "Service"
            then tr("Exige une station")
            elseif state.Energy then tr("Livraison déjà en cours")
            else nil,
        "Plein"
    )
    button(actions, tr("Arrêter et payer"), "Secondary", function()
        simple("StopEnergy")
    end, state.Energy ~= nil, tr("Aucune livraison en cours"), "Arreter")
    button(actions, tr("Devis de lavage"), "Secondary", function()
        quote(tr("Lavage"), "Wash", {})
    end, context.Kind == "Service", tr("Exige une station"), "Lavage")
    button(actions, tr("Devis de réparation"), "Secondary", function()
        quote(tr("Réparation"), "Repair", {})
    end, context.Kind == "PublicGarage", tr("Exige un garage public"), "Reparation")
    if state.Energy then
        local energy = card("Livraison", "Amber")
        PanelKit.cardTitle(
            shell,
            energy,
            tr("Livraison en cours"),
            string.format("%.1f / %.1f", state.Energy.Delivered, state.Energy.MaxUnits),
            "AmberSoftText"
        )
        PanelKit.progress(shell, energy, state.Energy.Delivered / math.max(state.Energy.MaxUnits, 0.001))
        text(energy, tr("Paiement au réel à la fin."), "Body", "TextMuted")
    end
    heading(tr("Pièces (garage public) — revente à 75 % du prix payé"))
    local list = grid("Pieces")
    for _, part in state.Parts or {} do
        local item = cell(list, "Piece_" .. tostring(part.Id))
        PanelKit.cardTitle(shell, item, tr(part.Label), credits(part.Price), "AmberSoftText")
        local partActions = row(item)
        button(partActions, tr("Devis d'achat"), "Secondary", function()
            quote(tr("Achat : %s", tr(part.Label)), "BuyPart", { PartId = part.Id })
        end, context.Kind == "PublicGarage", tr("Exige un garage public"), "DevisAchat")
    end
    for _, owned in state.OwnedParts or {} do
        if not owned.Installed and owned.Resale > 0 then
            local item = cell(list, "PieceDetachee_" .. tostring(owned.Id))
            PanelKit.cardTitle(shell, item, tr("%s (détachée)", owned.PartId), credits(owned.Resale), "Ok")
            local partActions = row(item)
            button(partActions, tr("Devis de revente"), "Secondary", function()
                quote(tr("Revente : %s", owned.PartId), "SellPart", { PartItemId = owned.Id })
            end, context.Kind == "PublicGarage", tr("Exige un garage public"), "DevisRevente")
        end
    end
end

local function contextText(context: any): string
    if context.Kind == "Dealership" or context.Kind == "Service" or context.Kind == "PublicGarage" then
        return tostring(context.Label or "")
    end
    return tr("Hors service · consultation")
end

function render()
    if not panel then
        return
    end
    shell:selectTab(tab)
    local keep = body.CanvasPosition
    shell:clear()
    if state == nil or state.Wallet == nil then
        text(body, Text.text((state and state.State) or "Loading"), "Body", "TextMuted")
        return
    end
    shell.Context.Text = contextText(state.Context or {})
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
    task.defer(function()
        body.CanvasPosition = keep
    end)
end

-- Repère local de l'étape en cours (visible seulement par ce joueur) : une
-- colonne lumineuse posée au sol et une étiquette toujours visible, même à
-- plusieurs kilomètres (la colonne seule devient invisible au-delà d'environ
-- 1 km). Hauteur en studs ; le sol est retrouvé par lancer de rayon.
local BEACON_HEIGHT = 400

-- Distance arrondie à 10 m ; virgule décimale en français seulement (Localization.distance).
local function distanceText(meters: number): string
    return Localization.distance(meters)
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
        part.Color = UITheme.color("Accent")
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
            BackgroundColor3 = Tokens.color("WarnBg"),
            BackgroundTransparency = 0.2,
            TextColor3 = UITheme.color("AccentSoftText"),
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
            stepLabel(mission.Label),
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
    -- Lot 0.7 : l'objectif de mission est suivi par le GPS.
    GPSController.missionTarget(point, if mission then stepLabel(mission.Label) else nil)
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
    guideText.Text = tr("Objectif à %s", distanceText(meters))
    if beaconTag then
        (beaconTag:FindFirstChild("Distance") :: TextLabel).Text = distanceText(meters)
    end
    -- Le sol d'une zone lointaine peut n'être chargé qu'en s'approchant.
    if os.clock() - groundCheckAt > 2 then
        placeBeacon(point)
    end
end

-- Lot 0.7 : ouverture et fermeture par le gestionnaire commun (UIManager).
local function toggle()
    UIManager.toggle("Economy")
end

function EconomyPanel.start()
    local folder = ReplicatedStorage:WaitForChild(EconomyProtocol.FolderName)
    request = folder:WaitForChild(EconomyProtocol.Request) :: RemoteFunction
    local pushEvent = folder:WaitForChild(EconomyProtocol.Push) :: RemoteEvent
    -- Écran plein : au-dessus du HUD (la mini-carte recouvrait le panneau, VM 20261105-125026), comme le garage.
    local gui = make(
        "ScreenGui",
        { Name = "AWEconomy", ResetOnSpawn = false, DisplayOrder = 20 },
        player:WaitForChild("PlayerGui")
    )
    -- Bandeau de mission (haut, centré) : carte à filet cyan (GPS), texte en Titillium Web.
    missionLabel = make("TextLabel", {
        Name = "BandeauMission",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 64),
        Size = UDim2.fromOffset(620, 30),
        BackgroundColor3 = Tokens.color("Surface1"),
        BackgroundTransparency = 0.08,
        TextColor3 = Tokens.color("Text"),
        Font = Enum.Font.GothamMedium,
        TextSize = 15,
        Visible = false,
        Text = "",
    }, gui)
    make("UICorner", { CornerRadius = UDim.new(0, Tokens.Radius.Button) }, missionLabel)
    make("UIStroke", { Color = Tokens.color("Line"), Thickness = 1 }, missionLabel)
    make("Frame", {
        Name = "Filet",
        BackgroundColor3 = Tokens.color("GpsCyan"),
        BorderSizePixel = 0,
        Size = UDim2.new(0, Tokens.StatusRail, 1, 0),
    }, missionLabel)
    guideFrame = make("Frame", {
        Name = "Guidage",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 100),
        Size = UDim2.fromOffset(240, 34),
        BackgroundColor3 = Tokens.color("Surface1"),
        BackgroundTransparency = 0.08,
        Visible = false,
    }, gui)
    make("UICorner", { CornerRadius = UDim.new(0, Tokens.Radius.Button) }, guideFrame)
    make("UIStroke", { Color = Tokens.color("Line"), Thickness = 1 }, guideFrame)
    -- Flèche de direction dessinée (chevron), tournée vers l'objectif ; aucun caractère Unicode.
    guideArrow = make("Frame", {
        Name = "Fleche",
        Size = UDim2.fromOffset(34, 34),
        BackgroundTransparency = 1,
    }, guideFrame)
    local chevron = PanelKit.chevronUp(guideArrow, 18, "GpsCyan")
    chevron.AnchorPoint = Vector2.new(0.5, 0.5)
    chevron.Position = UDim2.fromScale(0.5, 0.5)
    guideText = make("TextLabel", {
        Position = UDim2.fromOffset(38, 0),
        Size = UDim2.new(1, -44, 1, 0),
        BackgroundTransparency = 1,
        TextColor3 = Tokens.color("Text"),
        Font = Enum.Font.GothamMedium,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "",
    }, guideFrame)
    RunService.RenderStepped:Connect(updateGuide)
    -- Panneau plein écran V1.2 (PanelKit) : barre haute, onglets à filet, contenu, état du serveur, barre d'aide.
    shell = PanelKit.shell(gui, "Economie", tr("Économie"), TABS, tr, function(id: string)
        tab = id
        pending = nil
        render()
    end, toggle)
    panel = shell.Panel
    body = shell.Body
    local function hints()
        shell:hints(
            if PanelKit.isGamepad()
                then { { "LB / RB", tr("Onglets") }, { "A", tr("Valider") }, { "B", tr("Retour") } }
                else { { "J", tr("Fermer") }, { tr("Retour arrière"), tr("Retour") } }
        )
    end
    hints()
    game:GetService("UserInputService").LastInputTypeChanged:Connect(hints)
    -- Onglets à la manette (LB / RB) et au clavier (PageUp / PageDown).
    game:GetService("UserInputService").InputBegan:Connect(function(input: InputObject)
        if not panel.Visible or gui:FindFirstChild("VoileConfirmation") then
            return
        end
        local index = table.find(TABS, tab) or 1
        if input.KeyCode == Enum.KeyCode.ButtonR1 or input.KeyCode == Enum.KeyCode.PageDown then
            tab = TABS[index % #TABS + 1]
            pending = nil
            render()
        elseif input.KeyCode == Enum.KeyCode.ButtonL1 or input.KeyCode == Enum.KeyCode.PageUp then
            tab = TABS[(index - 2) % #TABS + 1]
            pending = nil
            render()
        end
    end)

    pushEvent.OnClientEvent:Connect(function(kind: any, data: any)
        if kind == "Snapshot" and type(data) == "table" then
            state = data
            updateMission()
            if panel.Visible then
                render()
            end
        elseif kind == "MissionEnded" and type(data) == "table" then
            shell:setStatus(
                if data.Completed then kindOf(data) else "Rejected",
                if data.Completed
                    then tr(
                        "Mission réussie : %s, +%d réputation (%s).",
                        credits(data.Credits),
                        data.Reputation,
                        tr(STATUS_TEXT[data.Status] or tostring(data.Status))
                    )
                    else tr("Mission échouée ou abandonnée : %s", Text.text(data.Reason))
            )
        elseif kind == "Open" and type(data) == "table" then
            if type(data.Tab) == "string" then
                tab = data.Tab
            end
            if UIManager.isOpen("Economy") then
                render()
            else
                UIManager.open("Economy")
            end
        elseif kind == "EnergyEnded" and type(data) == "table" then
            shell:setStatus(
                kindOf(data),
                tr(
                    "Énergie livrée : %.1f unités, payé %s (%s).",
                    data.Delivered,
                    credits(data.Cost),
                    tr(STATUS_TEXT[data.Status] or tostring(data.Status))
                )
            )
        end
    end)
    -- Changement de langue à chaud : onglets, bandeau de mission et contenu redessinés.
    Localization.changed(function()
        for name, item in shell.Tabs do
            item.Text = tr(name)
        end
        shell.Close.Text = tr("Fermer")
        shell.Title.Text = Tokens.upper(tr("Économie"))
        hints()
        updateMission()
        render()
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
    -- Raccourci J (manette : stick droit) : InputRouter, lot 0.7.
    UIManager.register({
        Name = "Economy",
        Kind = "Modal",
        Full = true,
        Open = function()
            panel.Visible = true
            simple("Snapshot", nil, true)
        end,
        Close = function()
            panel.Visible = false
            local veil = gui:FindFirstChild("VoileConfirmation")
            if veil then
                veil:Destroy()
                pending = nil
            end
        end,
        Focus = function()
            return shell.Tabs[tab]
        end,
    })
end

return table.freeze(EconomyPanel)
