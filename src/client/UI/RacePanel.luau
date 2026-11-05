--!strict
--[[
    Interface PROVISOIRE des courses (lot 0.6) ; l'interface définitive sera
    retravaillée au lot 0.7. Navigable au clavier/souris et à la manette.
    Touche : K (manette : clic du stick gauche).

    - Panneau : épreuves (parcours triés par distance, détails, rejoindre une
      épreuve officielle, créer un salon privé ou un entraînement, file
      classée), mon épreuve (participants, prêt, désinscription, abandon),
      classements (rang et saison, tableaux), résultats.
    - Affichage de course compact (haut à droite) : compte à rebours,
      chronomètre, position, tour, point de contrôle, temps au tour, score de
      drift, faux départ et pénalités ; repères locaux des prochains points.
    Tous les temps affichés sont calculés à partir de l'horloge SERVEUR
    répliquée ; les résultats officiels viennent seulement du serveur.
    Ouvrir ce panneau ne freine jamais la voiture.
    Lot 0.8 : libellés traduits à l'affichage (Localization.tr, dictionnaire
    PanelTexts), y compris les libellés français reçus du serveur (discipline,
    type d'épreuve, zone, conditions, rang) ; identifiants d'onglet inchangés
    (français) ; redessin au changement de langue.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RacingShared = Shared:WaitForChild("Racing")
local RaceProtocol = require(RacingShared:WaitForChild("RaceProtocol"))
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))
local Localization = require(Shared:WaitForChild("UI"):WaitForChild("Localization"))

local Text = require(script.Parent.ProgressionMessages)
local UIManager = require(script.Parent.UIManager)
local InputRouter = require(script.Parent.InputRouter)

local RacePanel = {}

-- Texte joueur : le français sert de clé, l'anglais vient de PanelTexts.
local tr = Localization.tr

local player = Players.LocalPlayer
local S = 1 / Constants.MetersPerStud
-- Identifiants d'onglet (français) : affichés via tr(), jamais traduits ici.
local TABS = { "Épreuves", "Mon épreuve", "Classements", "Résultats" }

local request: RemoteFunction
local panel: Frame
local body: ScrollingFrame
local footer: TextLabel
local hud: Frame
local hudTitle: TextLabel
local hudMain: TextLabel
local hudInfo: TextLabel
local toast: TextLabel
local tabButtons: { [string]: TextButton } = {}
local closeButton: TextButton? = nil
local tab = "Épreuves"
local busy = false
local catalog: any = nil
local current: any = nil -- instantané de mon épreuve
local lastResults: any = nil
local selected: string? = nil
local mode = "Protected"
local privateLaps = 3
local proposal: any = nil
local rejoinOffer: any = nil
local leaderboard: any = nil
local beacons: { BasePart } = {}
local toastUntil = 0

local function make(className: string, props: { [string]: any }, parent: Instance?): any
    local item = Instance.new(className)
    for key, value in props do
        (item :: any)[key] = value
    end
    item.Parent = parent
    return item
end

local function now(): number
    return Workspace:GetServerTimeNow()
end

local function chrono(seconds: number?): string
    if seconds == nil then
        return "—"
    end
    local value = math.max(seconds, 0)
    local minutes = math.floor(value / 60)
    return string.format("%d:%06.3f", minutes, value - minutes * 60)
end

-- Longueur exacte au mètre (pas d'arrondi : 402 m reste 402 m) ; virgule
-- décimale en français seulement.
local function km(meters: number): string
    if meters < 1000 then
        return string.format("%d m", meters)
    end
    local text = string.format("%.1f km", meters / 1000)
    return if Localization.language() == "fr" then (string.gsub(text, "%.", ",")) else text
end

local function invoke(action: string, payload: any?): any
    local ok, response = pcall(function()
        return request:InvokeServer(action, payload or {})
    end)
    if not ok or type(response) ~= "table" then
        return { Status = "Error", Error = "ServerUnreachable" }
    end
    return response
end

local render: () -> ()

local function describe(response: any): string
    if response.Status == "Ok" or response.Status == "Confirmed" or response.Status == "Pending" then
        return tr("Fait.")
    end
    return tr("Refusé : %s", Text.text(response.Error))
end

local function send(action: string, payload: any?)
    if busy then
        return
    end
    -- Lot 0.7 : engagement d'un véhicule seulement d'une pression neuve.
    if RaceProtocol.Sensitive[action] and not InputRouter.confirmAllowed() then
        footer.Text = Text.text("ui.confirmAgain")
        return
    end
    busy = true
    local data = payload or {}
    if RaceProtocol.Sensitive[action] then
        data.RequestId = HttpService:GenerateGUID(false)
    end
    footer.Text = tr("Demande envoyée…")
    local response = invoke(action, data)
    busy = false
    footer.Text = describe(response)
    if response.Status == "Ok" and type(response.Result) == "table" and response.Result.SessionId then
        current = response.Result
    end
    render()
end

local function refresh()
    local response = invoke("Catalog")
    if response.Status == "Ok" then
        catalog = response.Result
        if catalog.Current then
            current = catalog.Current
        end
    end
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
        BackgroundColor3 = if active then Color3.fromRGB(150, 60, 60) else Color3.fromRGB(60, 64, 72),
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

-- Libellés français, traduits au moment de l'affichage (tables évaluées une fois).
local KIND_LABEL = { Official = "Officielle", Ranked = "Classée", Private = "Privée", Training = "Entraînement" }
local MODE_LABEL = { Protected = "Protégé", Realistic = "Réaliste" }
local OUTCOME_LABEL = {
    Finished = "Arrivé",
    Unconfirmed = "Non confirmé (à réconcilier)",
    Abandoned = "Abandon",
    Disconnected = "Déconnecté",
    Disqualified = "Disqualifié",
    TimedOut = "Hors délai",
    DidNotStart = "Non partant",
    Interrupted = "Interrompu",
}

-- ======================== Onglets ========================

local function courseById(id: string?): any
    if catalog == nil or id == nil then
        return nil
    end
    for _, course in catalog.Courses do
        if course.Id == id then
            return course
        end
    end
    return nil
end

local function renderCatalog()
    if catalog == nil then
        line(tr("Chargement…"))
        return
    end
    local actions = row()
    button(actions, tr("Mode : %s", tr(MODE_LABEL[mode])), 170, function()
        mode = if mode == "Protected" then "Realistic" else "Protected"
        render()
    end)
    button(actions, tr("Actualiser"), 110, function()
        refresh()
        render()
    end)
    local course = courseById(selected)
    if course then
        line(string.format("%s — %s (%s)", course.Name, tr(course.DisciplineLabel), tr(course.Zone)), true)
        line(
            tr(
                "%s%s • difficulté %d/3 • %s • %s",
                km(course.LengthM),
                if course.Laps > 1 then tr(" (%d tours)", course.Laps) else "",
                course.Difficulty,
                if course.Traffic then tr("route ouverte (circulation)") else tr("parcours fermé"),
                if course.RecordEligible
                    then tr("records éligibles (conditions normalisées)")
                    else tr("pas de record")
            )
        )
        line(
            tr(
                "Point d'inscription à %s. Présentez-vous-y arrêté, au volant de votre voiture.",
                km(course.DistanceM)
            )
        )
        local kinds = row()
        if table.find(course.Kinds, "Official") then
            button(kinds, tr("Officielle"), 120, function()
                send("Join", { CourseId = course.Id, Kind = "Official", Mode = mode })
            end)
        end
        if table.find(course.Kinds, "Ranked") then
            button(kinds, tr("File classée"), 130, function()
                send("Queue", { Discipline = course.Discipline, Mode = mode })
            end)
        end
        if table.find(course.Kinds, "Private") then
            button(kinds, tr("Salon privé (%d t.)", privateLaps), 170, function()
                send("CreatePrivate", { CourseId = course.Id, Kind = "Private", Mode = mode, Laps = privateLaps })
            end)
            button(kinds, tr("Tours ±"), 80, function()
                privateLaps = privateLaps % 10 + 1
                render()
            end)
        end
        if table.find(course.Kinds, "Training") then
            button(kinds, tr("Entraînement"), 130, function()
                send("CreatePrivate", { CourseId = course.Id, Kind = "Training", Laps = privateLaps })
            end)
        end
        for _, open in course.Open do
            local item = row()
            button(
                item,
                tr("Rejoindre (%s, %d/%d)", tr(KIND_LABEL[open.Kind] or open.Kind), open.Count, open.Max),
                260,
                function()
                    send("Join", { SessionId = open.SessionId, Mode = mode })
                end
            )
        end
        local back = row()
        button(back, tr("Tous les parcours"), 160, function()
            selected = nil
            render()
        end)
        button(back, tr("Records du parcours"), 180, function()
            local response = invoke("Leaderboard", { CourseId = course.Id })
            leaderboard = if response.Status == "Ok" then response.Result else nil
            tab = "Classements"
            render()
        end)
        return
    end
    line(tr("Parcours (du plus proche au plus lointain)"), true)
    for _, item in catalog.Courses do
        local r = row()
        button(r, item.Name, 300, function()
            selected = item.Id
            render()
        end)
        make("TextLabel", {
            Size = UDim2.new(0, 520, 1, 0),
            BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(215, 222, 232),
            Font = Enum.Font.Gotham,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = tr(
                "%s • %s • %s • à %s%s",
                tr(item.DisciplineLabel),
                tr(item.Zone),
                km(item.LengthM),
                km(item.DistanceM),
                if #item.Open > 0 then tr(" • épreuve ouverte") else ""
            ),
        }, r)
    end
end

local function renderCurrent()
    if current == nil or current.None then
        line(tr("Aucune épreuve en cours. Rendez-vous à un point d'inscription (dalle violette)."))
        if proposal then
            line(tr("Match classé trouvé (%s, %d joueurs).", proposal.Discipline, proposal.Players), true)
            local r = row()
            button(r, tr("Confirmer"), 140, function()
                send("ConfirmMatch", { MatchId = proposal.MatchId })
                proposal = nil
            end)
        end
        if rejoinOffer then
            line(tr("Reprise possible : %s.", rejoinOffer.Name), true)
            local r = row()
            button(r, tr("Reprendre la course"), 200, function()
                send("Rejoin", {})
                rejoinOffer = nil
            end)
        end
        if catalog and catalog.Queue then
            line(tr("File classée : %s", tostring(catalog.Queue.State)))
            local r = row()
            button(r, tr("Quitter la file"), 150, function()
                send("Unqueue", {})
            end)
        end
        return
    end
    line(string.format("%s — %s (%s)", current.Name, tr(current.DisciplineLabel), tr(current.KindLabel)), true)
    line(
        tr(
            "État : %s • %d/%d participants (minimum %d) • conditions : %s",
            current.State,
            current.Count,
            current.Max,
            current.Min,
            if current.Normalized then tr("%s (normalisées)", tr(current.Conditions)) else tr("météo du monde")
        )
    )
    local me = current.Me
    if me then
        line(tr("Votre mode : %s • place %d", tr(MODE_LABEL[me.Mode] or me.Mode), me.Slot))
    end
    for _, participant in current.Participants do
        line(
            string.format(
                "  %s — %s%s",
                participant.Name,
                participant.Status,
                if current.State == "Open"
                    then (if participant.Ready then tr(" (prêt)") else tr(" (pas prêt)"))
                    else ""
            )
        )
    end
    local actions = row()
    if current.State == "Open" then
        local ready = me and me.Ready
        button(actions, if ready then tr("Pas prêt") else tr("Je suis prêt"), 140, function()
            send("Ready", { Ready = not ready })
        end)
        button(actions, tr("Se désinscrire"), 150, function()
            send("Leave", {})
            current = nil
        end)
    elseif current.State == "Countdown" or current.State == "Running" then
        button(actions, tr("Abandonner"), 140, function()
            send("Abandon", {})
        end)
    end
end

local function renderRanking()
    local profile = catalog and catalog.Profile
    if catalog then
        local days = math.max(0, math.floor((catalog.Season.EndsAt - os.time()) / 86400))
        line(tr("Saison %d — fin dans %d jour(s) (saisons de 8 semaines)", catalog.Season.Index, days), true)
    end
    if profile then
        for _, name in { "Race", "Drift" } do
            local ladder = profile.Ladders[name]
            line(
                tr(
                    "%s : %s — %d points • %d épreuve(s) classée(s), %d victoire(s)",
                    if name == "Race" then tr("Sprint et circuit") else tr("Drift"),
                    tr(ladder.Rank),
                    ladder.Points,
                    ladder.Played,
                    ladder.Wins
                )
            )
        end
        line(tr("Rang de compétition (Bronze → Diamant) indépendant de la réputation générale."))
        for _, entry in profile.History or {} do
            line(tr("  Saison %d — %s : %s (%d pts)", entry.Season, entry.Ladder, tr(entry.Rank), entry.Points))
        end
    end
    local boards = row()
    for _, name in { "Race", "Drift" } do
        button(boards, if name == "Race" then tr("Tableau sprint/circuit") else tr("Tableau drift"), 200, function()
            local response = invoke("Leaderboard", { Board = name })
            leaderboard = if response.Status == "Ok" then response.Result else nil
            render()
        end)
    end
    if leaderboard then
        line(leaderboard.Board, true)
        for index, item in leaderboard.Entries do
            line(string.format("  %d. %s — %s", index, item.Name, tostring(item.Value)))
        end
        if #leaderboard.Entries == 0 then
            line(tr("  (vide)"))
        end
    end
end

local function renderResults()
    if lastResults then
        line(tr("%s — résultats (%s)", lastResults.Name, tr(lastResults.Conditions)), true)
        for _, entry in lastResults.Entries do
            line(
                string.format(
                    "  %s %s — %s%s%s",
                    if entry.Position then tostring(entry.Position) .. "." else "–",
                    entry.Name,
                    tr(OUTCOME_LABEL[entry.Outcome] or entry.Outcome),
                    if lastResults.Ranking == "Score" and entry.Score
                        then tr(" • %d pts", entry.Score)
                        elseif entry.OfficialS then " • " .. chrono(entry.OfficialS)
                        else "",
                    if (entry.PenaltyS or 0) > 0 then tr(" (dont %.1f s de pénalité)", entry.PenaltyS) else ""
                )
            )
        end
        local mine = lastResults.Mine
        line(
            tr(
                "Vous : %s • %d crédits%s%s • état : %s",
                tr(OUTCOME_LABEL[mine.Outcome] or mine.Outcome),
                mine.Credits or 0,
                if mine.RankedDelta then tr(" • classement %+d (%s)", mine.RankedDelta, tr(mine.Rank)) else "",
                if mine.Record then tr(" • record personnel") else "",
                tostring(mine.Status)
            ),
            true
        )
    end
    local profile = catalog and catalog.Profile
    if profile then
        line(tr("Historique personnel"), true)
        for _, item in profile.Results do
            local result = item.Result
            line(
                string.format(
                    "  %s %s — %s%s • %d cr",
                    result.Discipline,
                    result.CourseId,
                    tr(OUTCOME_LABEL[result.Outcome] or result.Outcome),
                    if result.Position then string.format(" (%d/%d)", result.Position, result.Field) else "",
                    result.Credits
                )
            )
        end
    end
end

render = function()
    if (panel :: any) == nil or not panel.Visible then
        return
    end
    InputRouter.armConfirm()
    for _, child in body:GetChildren() do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
    order = 0
    for name, item in tabButtons do
        item.BackgroundColor3 = if name == tab then Color3.fromRGB(150, 60, 60) else Color3.fromRGB(44, 52, 66)
    end
    if tab == "Épreuves" then
        renderCatalog()
    elseif tab == "Mon épreuve" then
        renderCurrent()
    elseif tab == "Classements" then
        renderRanking()
    else
        renderResults()
    end
end

-- ======================== Affichage de course ========================

local function clearBeacons()
    for _, beacon in beacons do
        beacon:Destroy()
    end
    table.clear(beacons)
end

local function groundY(x: number, z: number): number
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignored: { Instance } = { Workspace.CurrentCamera :: Instance }
    if player.Character then
        table.insert(ignored, player.Character)
    end
    params.FilterDescendantsInstances = ignored
    local hit = Workspace:Raycast(Vector3.new(x * S, 3000, z * S), Vector3.new(0, -6000, 0), params)
    return if hit then hit.Position.Y else 0
end

-- Repères locaux : prochains points de contrôle et place de départ.
local function updateBeacons()
    clearBeacons()
    local me = current and current.Me
    if me == nil or current.State == "Finished" then
        return
    end
    local points = {}
    if me.Status == "Waiting" and me.SlotPoint then
        table.insert(
            points,
            { X = me.SlotPoint.X, Z = me.SlotPoint.Z, Color = Color3.fromRGB(255, 200, 60), Height = 20 }
        )
    end
    for index, cp in me.Checkpoints or {} do
        table.insert(points, {
            X = cp.X,
            Z = cp.Z,
            Color = if index == 1 then Color3.fromRGB(80, 220, 255) else Color3.fromRGB(80, 120, 160),
            Height = if index == 1 then 60 else 30,
        })
    end
    for _, point in points do
        local part = make("Part", {
            Name = "RepereCourse",
            Anchored = true,
            CanCollide = false,
            CanQuery = false,
            CanTouch = false,
            CastShadow = false,
            Material = Enum.Material.Neon,
            Color = point.Color,
            Transparency = 0.45,
            Shape = Enum.PartType.Cylinder,
            Size = Vector3.new(point.Height, 2, 2),
            CFrame = CFrame.new(point.X * S, groundY(point.X, point.Z) + point.Height / 2, point.Z * S)
                * CFrame.Angles(0, 0, math.pi / 2),
        }, Workspace.CurrentCamera)
        table.insert(beacons, part)
    end
end

-- Libellés français, traduits au moment de l'affichage.
local EVENT_TEXT = {
    Locked = "Inscriptions fermées : rejoignez votre place.",
    Started = "Départ !",
    Checkpoint = "Point de contrôle",
    Lap = "Tour bouclé",
    Finished = "Arrivée — validation par le serveur…",
    Penalty = "Pénalité",
    MissedCheckpoint = "Point de contrôle manqué : revenez-y",
    FalseStart = "FAUX DÉPART",
    Disqualified = "Manche invalidée",
    ["Drift:Banked"] = "Figure acquise",
    ["Drift:Broken:Collision"] = "Figure perdue : choc",
    ["Drift:Broken:OutOfZone"] = "Figure perdue : hors zone",
    ["Drift:Broken:Spin"] = "Figure perdue : tête-à-queue",
    ["Drift:Broken:Invalid"] = "Figure perdue",
}

local function showToast(text: string, seconds: number?)
    toast.Text = text
    toast.Visible = true
    toastUntil = os.clock() + (seconds or 2.5)
end

local function updateHud()
    if toast.Visible and os.clock() > toastUntil then
        toast.Visible = false
    end
    local me = current and current.Me
    if current == nil or current.None or me == nil then
        hud.Visible = false
        return
    end
    hud.Visible = true
    hudTitle.Text = string.format("%s — %s", tr(current.DisciplineLabel), current.Name)
    local t = now()
    local main = ""
    local info = {}
    if current.State == "Open" then
        main = if me.Ready then tr("Prêt — en attente") else tr("Inscrit — confirmez « prêt » (K)")
        table.insert(info, tr("%d/%d participants", current.Count, current.Max))
    elseif me.Status == "Waiting" and me.StartT then
        local remaining = me.StartT - t
        if remaining > 5 then
            main = tr("Rejoignez votre place (%d) — %d s", me.Slot or 0, math.ceil(remaining))
        else
            main = tr("DÉPART DANS %d", math.ceil(remaining))
        end
    elseif me.Status == "Racing" and me.StartT then
        if current.Discipline == "Drift" and me.Drift then
            main = string.format("%d pts  (+%d × %.2f)", me.Drift.Total, me.Drift.Combo, me.Drift.Multiplier)
            table.insert(info, tr("Reste %d s", math.max(0, math.ceil(me.StartT + 90 - t))))
        else
            main = chrono(t - me.StartT)
        end
    elseif me.Status == "Finished" then
        main = if me.OfficialS then tr("Arrivée %s", chrono(me.OfficialS)) else tr("Terminé")
    else
        main = tr(OUTCOME_LABEL[me.Status] or me.Status)
    end
    if current.Discipline ~= "Drift" and current.State ~= "Open" then
        if me.Position and (current.Discipline == "Sprint" or current.Discipline == "Circuit") then
            table.insert(info, tr("Position %d/%d", me.Position, current.Count))
        end
        if current.Laps > 1 then
            table.insert(info, tr("Tour %d/%d", math.min(me.Lap, current.Laps), current.Laps))
        end
        table.insert(info, tr("Point %d/%d", math.min(me.Next, current.CheckpointsTotal), current.CheckpointsTotal))
        local laps = me.LapTimes or {}
        if #laps > 0 then
            table.insert(info, tr("Dernier tour %s", chrono(laps[#laps])))
            table.insert(info, tr("Meilleur %s", chrono(me.BestLapS)))
        end
        if me.ReactionS then
            table.insert(info, tr("Réaction %.3f s", me.ReactionS))
        end
    end
    if me.FalseStart then
        table.insert(info, tr("FAUX DÉPART"))
    end
    if (me.PenaltyS or 0) > 0 then
        table.insert(info, tr("Pénalités +%.1f s", me.PenaltyS))
    end
    hudMain.Text = main
    hudInfo.Text = table.concat(info, "  •  ")
end

-- ======================== Démarrage ========================

-- Lot 0.7 : ouverture et fermeture par le gestionnaire commun (UIManager).
local function toggle()
    UIManager.toggle("Races")
end

-- Épreuve en cours (le HUD de conduite cède la place à l'affichage de course).
function RacePanel.racing(): boolean
    return current ~= nil and not current.None and (current.State == "Countdown" or current.State == "Running")
end

function RacePanel.start()
    local folder = ReplicatedStorage:WaitForChild(RaceProtocol.FolderName)
    request = folder:WaitForChild(RaceProtocol.Request) :: RemoteFunction
    local pushEvent = folder:WaitForChild(RaceProtocol.Push) :: RemoteEvent
    local gui = make("ScreenGui", { Name = "AWRacing", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))

    hud = make("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -16, 0, 120),
        Size = UDim2.fromOffset(340, 92),
        BackgroundColor3 = Color3.fromRGB(20, 24, 32),
        BackgroundTransparency = 0.25,
        Visible = false,
    }, gui)
    make("UICorner", { CornerRadius = UDim.new(0, 8) }, hud)
    hudTitle = make("TextLabel", {
        Position = UDim2.fromOffset(10, 4),
        Size = UDim2.new(1, -20, 0, 18),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(255, 200, 120),
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "",
    }, hud)
    hudMain = make("TextLabel", {
        Position = UDim2.fromOffset(10, 22),
        Size = UDim2.new(1, -20, 0, 34),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 26,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "",
    }, hud)
    hudInfo = make("TextLabel", {
        Position = UDim2.fromOffset(10, 58),
        Size = UDim2.new(1, -20, 0, 30),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(215, 222, 232),
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "",
    }, hud)
    toast = make("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 140),
        Size = UDim2.fromOffset(420, 34),
        BackgroundColor3 = Color3.fromRGB(60, 24, 24),
        BackgroundTransparency = 0.15,
        TextColor3 = Color3.fromRGB(255, 230, 200),
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        Visible = false,
        Text = "",
    }, gui)

    panel = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.52),
        Size = UDim2.fromOffset(900, 520),
        BackgroundColor3 = Color3.fromRGB(26, 26, 34),
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
            Size = UDim2.fromOffset(150, 32),
            BackgroundColor3 = Color3.fromRGB(44, 52, 66),
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Font = Enum.Font.GothamMedium,
            TextSize = 14,
            Text = tr(name),
            LayoutOrder = index,
        }, tabs)
        item.Activated:Connect(function()
            tab = name
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
        Text = tr("Fermer"),
        LayoutOrder = 99,
    }, tabs)
    close.Activated:Connect(toggle)
    closeButton = close
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
        if kind == "Snapshot" then
            local before = current and current.Me and current.Me.Next
            current = if type(data) == "table" and not data.None then data else nil
            local after = current and current.Me and current.Me.Next
            if before ~= after or (current and current.Me and current.Me.Status == "Waiting") then
                updateBeacons()
            end
            if current == nil then
                clearBeacons()
            end
            if panel.Visible and tab == "Mon épreuve" then
                render()
            end
        elseif kind == "Event" and type(data) == "string" then
            local text = EVENT_TEXT[data]
            if text then
                showToast(tr(text))
            end
        elseif kind == "Results" and type(data) == "table" then
            lastResults = data
            current = nil
            clearBeacons()
            showToast(
                tr(
                    "Résultat : %s — %d crédits",
                    tr(OUTCOME_LABEL[data.Mine.Outcome] or data.Mine.Outcome),
                    data.Mine.Credits or 0
                ),
                5
            )
            tab = "Résultats"
            refresh()
            render()
        elseif kind == "Notice" and type(data) == "string" then
            showToast(Text.text(data), 4)
        elseif kind == "MatchProposed" and type(data) == "table" then
            proposal = data
            showToast(tr("Match classé trouvé : confirmez (K)"), 6)
        elseif kind == "MatchReady" and type(data) == "table" then
            selected = data.CourseId
            showToast(tr("Match prêt : rejoignez « %s »", tostring(data.Name)), 8)
        elseif kind == "Rejoin" and type(data) == "table" then
            rejoinOffer = data
            showToast(tr("Reprise de course possible (K)"), 8)
        elseif kind == "Open" and type(data) == "table" then
            selected = data.CourseId
            tab = "Épreuves"
            if UIManager.isOpen("Races") then
                refresh()
                render()
            else
                UIManager.open("Races")
            end
        end
    end)
    RunService.RenderStepped:Connect(updateHud)
    -- Changement de langue à chaud : onglets et contenu (l'affichage de course
    -- se met à jour à chaque image).
    Localization.changed(function()
        for name, item in tabButtons do
            item.Text = tr(name)
        end
        if closeButton then
            closeButton.Text = tr("Fermer")
        end
        render()
    end)
    -- Raccourci K (manette : stick gauche) : InputRouter, lot 0.7.
    UIManager.register({
        Name = "Races",
        Kind = "Modal",
        Full = true,
        Open = function()
            panel.Visible = true
            refresh()
            render()
        end,
        Close = function()
            panel.Visible = false
        end,
        Focus = function()
            return tabButtons[tab]
        end,
    })
end

return table.freeze(RacePanel)
