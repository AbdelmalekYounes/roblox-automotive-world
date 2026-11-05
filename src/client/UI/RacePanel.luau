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
local UITheme = require(script.Parent.UITheme)
local Tokens =
    require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("DesignTokens"))
local InputRouter = require(script.Parent.InputRouter)
local PanelKit = require(script.Parent.PanelKit)

local RacePanel = {}

-- Texte joueur : le français sert de clé, l'anglais vient de PanelTexts.
local tr = Localization.tr

local player = Players.LocalPlayer
local S = 1 / Constants.MetersPerStud
-- Identifiants d'onglet (français) : affichés via tr(), jamais traduits ici.
local TABS = { "Épreuves", "Mon épreuve", "Classements", "Résultats" }

local request: RemoteFunction
local shell: PanelKit.Shell
local panel: Frame
local body: ScrollingFrame
local hud: Frame
local hudTitle: TextLabel
local hudMain: TextLabel
local hudInfo: TextLabel
local toast: TextLabel
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
    -- Lot UI-04 : repères Gotham convertis en Titillium Web (système de conception V1.2), même graisse.
    if props.Font and (item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox")) then
        UITheme.applyFont(item :: any, props.Font)
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
    local ok, response = PanelKit.invoke(request, action, payload or {})
    if not ok or type(response) ~= "table" then
        return { Status = "Error", Error = "ServerUnreachable" }
    end
    return response
end

local render: () -> ()

local function describe(response: any): string
    -- Hors ligne : ni « refusé » ni « fait » (le serveur n'a pas répondu).
    if response.Status == "Error" then
        return tr("Serveur injoignable : rien n'est confirmé.")
    end
    if response.Status == "Ok" or response.Status == "Confirmed" or response.Status == "Pending" then
        return tr("Fait.")
    end
    return tr("Refusé : %s", Text.text(response.Error))
end

local function kindOf(response: any): string
    if response.Status == "Confirmed" then
        return "Confirmed"
    elseif response.Status == "Pending" then
        return "Pending"
    elseif response.Status == "Error" then
        return "Offline"
    elseif response.Status == "Ok" then
        return "Info"
    end
    return "Rejected"
end

local function send(action: string, payload: any?)
    if busy then
        return
    end
    -- Lot 0.7 : engagement d'un véhicule seulement d'une pression neuve.
    if RaceProtocol.Sensitive[action] and not InputRouter.confirmAllowed() then
        shell:setStatus("Info", Text.text("ui.confirmAgain"))
        return
    end
    busy = true
    panel:SetAttribute("AWBusy", true)
    local data = payload or {}
    if RaceProtocol.Sensitive[action] then
        data.RequestId = HttpService:GenerateGUID(false)
    end
    shell:setStatus("Pending", tr("Demande envoyée…"))
    PanelKit.countSent(panel)
    local response = invoke(action, data)
    busy = false
    panel:SetAttribute("AWBusy", false)
    shell:setStatus(kindOf(response), describe(response))
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
        text(body, tr("Chargement…"), "Body", "TextMuted")
        return
    end
    local actions = row()
    button(actions, tr("Mode : %s", tr(MODE_LABEL[mode])), "Secondary", function()
        mode = if mode == "Protected" then "Realistic" else "Protected"
        render()
    end, nil, nil, "Mode")
    button(actions, tr("Actualiser"), "Secondary", function()
        refresh()
        render()
    end, nil, nil, "Actualiser")
    local course = courseById(selected)
    if course then
        local box = card("Parcours_" .. tostring(course.Id), "RaceRed")
        PanelKit.cardTitle(shell, box, course.Name, km(course.LengthM), "Text")
        text(box, string.format("%s · %s", tr(course.DisciplineLabel), tr(course.Zone)), "Body", "TextMuted")
        PanelKit.keyValue(shell, box, tr("Tours"), tostring(course.Laps))
        PanelKit.keyValue(shell, box, tr("Difficulté"), string.format("%d / 3", course.Difficulty))
        PanelKit.keyValue(
            shell,
            box,
            tr("Circulation"),
            if course.Traffic then tr("route ouverte (circulation)") else tr("parcours fermé")
        )
        PanelKit.keyValue(
            shell,
            box,
            tr("Records"),
            if course.RecordEligible then tr("records éligibles (conditions normalisées)") else tr("pas de record")
        )
        PanelKit.keyValue(shell, box, tr("Point d'inscription"), km(course.DistanceM))
        text(
            box,
            tr("Présentez-vous au point d'inscription arrêté, au volant de votre voiture."),
            "Body",
            "TextMuted"
        )
        local kinds = row(box)
        if table.find(course.Kinds, "Official") then
            button(kinds, tr("Officielle"), "Primary", function()
                send("Join", { CourseId = course.Id, Kind = "Official", Mode = mode })
            end, nil, nil, "Officielle")
        end
        if table.find(course.Kinds, "Ranked") then
            button(kinds, tr("File classée"), "Secondary", function()
                send("Queue", { Discipline = course.Discipline, Mode = mode })
            end, nil, nil, "FileClassee")
        end
        if table.find(course.Kinds, "Private") then
            button(kinds, tr("Salon privé (%d t.)", privateLaps), "Secondary", function()
                send("CreatePrivate", { CourseId = course.Id, Kind = "Private", Mode = mode, Laps = privateLaps })
            end, nil, nil, "SalonPrive")
            button(kinds, tr("Tours ±"), "Secondary", function()
                privateLaps = privateLaps % 10 + 1
                render()
            end, nil, nil, "Tours")
        end
        if table.find(course.Kinds, "Training") then
            button(kinds, tr("Entraînement"), "Secondary", function()
                send("CreatePrivate", { CourseId = course.Id, Kind = "Training", Laps = privateLaps })
            end, nil, nil, "Entrainement")
        end
        if #course.Open > 0 then
            heading(tr("Épreuves ouvertes"))
        end
        for _, open in course.Open do
            local item = card("Ouverte_" .. tostring(open.SessionId), "Amber")
            PanelKit.cardTitle(
                shell,
                item,
                tr(KIND_LABEL[open.Kind] or open.Kind),
                string.format("%d / %d", open.Count, open.Max),
                "AmberSoftText"
            )
            local join = row(item)
            button(join, tr("Rejoindre"), "Primary", function()
                send("Join", { SessionId = open.SessionId, Mode = mode })
            end, nil, nil, "Rejoindre")
        end
        local back = row()
        button(back, tr("Tous les parcours"), "Secondary", function()
            selected = nil
            render()
        end, nil, nil, "TousParcours")
        button(back, tr("Records du parcours"), "Secondary", function()
            local response = invoke("Leaderboard", { CourseId = course.Id })
            leaderboard = if response.Status == "Ok" then response.Result else nil
            tab = "Classements"
            render()
        end, nil, nil, "Records")
        return
    end
    heading(tr("Parcours (du plus proche au plus lointain)"))
    for _, item in catalog.Courses do
        local box = card("Parcours_" .. tostring(item.Id), if #item.Open > 0 then "RaceRed" else nil)
        PanelKit.cardTitle(shell, box, item.Name, tr("à %s", km(item.DistanceM)), "TextMuted")
        text(
            box,
            string.format("%s · %s · %s", tr(item.DisciplineLabel), tr(item.Zone), km(item.LengthM)),
            "Body",
            "TextMuted"
        )
        local tags = row(box)
        if #item.Open > 0 then
            PanelKit.tag(shell, tags, tr("épreuve ouverte"), "DangerText")
        end
        button(tags, tr("Détails"), "Secondary", function()
            selected = item.Id
            render()
        end, nil, nil, "Details")
    end
end

local function renderCurrent()
    if current == nil or current.None then
        PanelKit.notice(
            shell,
            body,
            "Neutral",
            tr("Aucune épreuve en cours. Rendez-vous à un point d'inscription (dalle violette).")
        )
        if proposal then
            local box = card("MatchPropose", "Amber")
            PanelKit.cardTitle(
                shell,
                box,
                tr("Match classé trouvé (%s, %d joueurs).", proposal.Discipline, proposal.Players)
            )
            local r = row(box)
            button(r, tr("Confirmer"), "Primary", function()
                send("ConfirmMatch", { MatchId = proposal.MatchId })
                proposal = nil
            end, nil, nil, "ConfirmerMatch")
        end
        if rejoinOffer then
            local box = card("Reprise", "Amber")
            PanelKit.cardTitle(shell, box, tr("Reprise possible : %s.", rejoinOffer.Name))
            local r = row(box)
            button(r, tr("Reprendre la course"), "Primary", function()
                send("Rejoin", {})
                rejoinOffer = nil
            end, nil, nil, "Reprendre")
        end
        if catalog and catalog.Queue then
            local box = card("File", "GpsCyan")
            PanelKit.cardTitle(shell, box, tr("File classée : %s", tostring(catalog.Queue.State)))
            local r = row(box)
            button(r, tr("Quitter la file"), "Revoke", function()
                send("Unqueue", {})
            end, nil, nil, "QuitterFile")
        end
        return
    end
    local box = card("MonEpreuve", "RaceRed")
    PanelKit.cardTitle(shell, box, current.Name, tr(current.KindLabel), "DangerText")
    text(box, tr(current.DisciplineLabel), "Body", "TextMuted")
    local me = current.Me
    local cells = {
        { tr("État"), tostring(current.State) },
        { tr("Participants"), string.format("%d / %d (min %d)", current.Count, current.Max, current.Min) },
        {
            tr("Conditions"),
            if current.Normalized then tr("%s (normalisées)", tr(current.Conditions)) else tr("météo du monde"),
        },
    }
    if me then
        table.insert(
            cells,
            { tr("Votre mode"), string.format("%s · %d", tr(MODE_LABEL[me.Mode] or me.Mode), me.Slot) }
        )
    end
    PanelKit.cells(shell, body, cells, "EtatEpreuve")
    heading(tr("Participants"))
    local list = card("Participants")
    for _, participant in current.Participants do
        PanelKit.keyValue(
            shell,
            list,
            participant.Name,
            string.format(
                "%s%s",
                tostring(participant.Status),
                if current.State == "Open"
                    then (if participant.Ready then tr(" (prêt)") else tr(" (pas prêt)"))
                    else ""
            ),
            if participant.Ready then "Ok" else "Text"
        )
    end
    local actions = row()
    if current.State == "Open" then
        local ready = me and me.Ready
        button(actions, if ready then tr("Pas prêt") else tr("Je suis prêt"), "Primary", function()
            send("Ready", { Ready = not ready })
        end, nil, nil, "Pret")
        button(actions, tr("Se désinscrire"), "Revoke", function()
            send("Leave", {})
            current = nil
        end, nil, nil, "Desinscrire")
    elseif current.State == "Countdown" or current.State == "Running" then
        button(actions, tr("Abandonner"), "Revoke", function()
            PanelKit.confirm(shell.Gui, tr("Abandonner l'épreuve en cours ?"), function()
                send("Abandon", {})
            end)
        end, nil, nil, "Abandonner")
    end
end

local function renderRanking()
    local profile = catalog and catalog.Profile
    if catalog then
        local days = math.max(0, math.floor((catalog.Season.EndsAt - os.time()) / 86400))
        local season = card("Saison", "Amber")
        PanelKit.cardTitle(
            shell,
            season,
            tr("Saison %d", catalog.Season.Index),
            tr("fin dans %d jour(s)", days),
            "AmberSoftText"
        )
        text(
            season,
            tr(
                "Saisons de 8 semaines. Rang de compétition (Bronze → Diamant) indépendant de la réputation générale."
            ),
            "Body",
            "TextMuted"
        )
    end
    if profile then
        local ladders = {}
        for _, name in { "Race", "Drift" } do
            local ladder = profile.Ladders[name]
            table.insert(ladders, {
                if name == "Race" then tr("Sprint et circuit") else tr("Drift"),
                string.format("%s · %d pts", tr(ladder.Rank), ladder.Points),
                "AmberSoftText",
            })
            table.insert(ladders, {
                tr("Classées / victoires"),
                string.format("%d / %d", ladder.Played, ladder.Wins),
            })
        end
        PanelKit.cells(shell, body, ladders, "Rangs")
        if #(profile.History or {}) > 0 then
            heading(tr("Saisons précédentes"))
            local history = card("HistoriqueSaisons")
            for _, entry in profile.History do
                PanelKit.keyValue(
                    shell,
                    history,
                    tr("Saison %d · %s", entry.Season, entry.Ladder),
                    string.format("%s · %d pts", tr(entry.Rank), entry.Points)
                )
            end
        end
    end
    local boards = row()
    for _, name in { "Race", "Drift" } do
        button(
            boards,
            if name == "Race" then tr("Tableau sprint/circuit") else tr("Tableau drift"),
            "Secondary",
            function()
                local response = invoke("Leaderboard", { Board = name })
                leaderboard = if response.Status == "Ok" then response.Result else nil
                render()
            end,
            nil,
            nil,
            "Tableau" .. name
        )
    end
    if leaderboard then
        heading(tostring(leaderboard.Board))
        local board = card("Tableau")
        for index, item in leaderboard.Entries do
            PanelKit.keyValue(
                shell,
                board,
                string.format("%d. %s", index, item.Name),
                tostring(item.Value),
                if index == 1 then "AmberSoftText" else "Text"
            )
        end
        if #leaderboard.Entries == 0 then
            text(board, tr("  (vide)"), "Body", "TextMuted")
        end
    end
end

local function renderResults()
    if lastResults then
        local mine = lastResults.Mine
        heading(tr("%s — résultats (%s)", lastResults.Name, tr(lastResults.Conditions)))
        local cells = {
            { tr("Résultat"), tr(OUTCOME_LABEL[mine.Outcome] or mine.Outcome), "AmberSoftText" },
            { tr("Crédits"), string.format("%d cr", mine.Credits or 0) },
            { tr("État"), tostring(mine.Status) },
        }
        if mine.RankedDelta then
            table.insert(cells, { tr("Classement"), string.format("%+d · %s", mine.RankedDelta, tr(mine.Rank)) })
        end
        PanelKit.cells(shell, body, cells, "MonResultat")
        if mine.Record then
            PanelKit.notice(shell, body, "Warn", tr("Record personnel"))
        end
        local list = card("Classement", "RaceRed")
        for _, entry in lastResults.Entries do
            PanelKit.keyValue(
                shell,
                list,
                string.format("%s %s", if entry.Position then tostring(entry.Position) .. "." else "–", entry.Name),
                string.format(
                    "%s%s%s",
                    tr(OUTCOME_LABEL[entry.Outcome] or entry.Outcome),
                    if lastResults.Ranking == "Score" and entry.Score
                        then tr(" • %d pts", entry.Score)
                        elseif entry.OfficialS then " • " .. chrono(entry.OfficialS)
                        else "",
                    if (entry.PenaltyS or 0) > 0 then tr(" (dont %.1f s de pénalité)", entry.PenaltyS) else ""
                ),
                if entry.Position == 1 then "AmberSoftText" else "Text"
            )
        end
    end
    local profile = catalog and catalog.Profile
    if profile then
        heading(tr("Historique personnel"))
        local history = card("HistoriquePersonnel")
        if #(profile.Results or {}) == 0 then
            text(history, tr("  (vide)"), "Body", "TextMuted")
        end
        for _, item in profile.Results or {} do
            local result = item.Result
            PanelKit.keyValue(
                shell,
                history,
                string.format("%s %s", tostring(result.Discipline), tostring(result.CourseId)),
                string.format(
                    "%s%s · %d cr",
                    tr(OUTCOME_LABEL[result.Outcome] or result.Outcome),
                    if result.Position then string.format(" (%d/%d)", result.Position, result.Field) else "",
                    result.Credits
                )
            )
        end
    end
    if lastResults == nil and profile == nil then
        PanelKit.notice(shell, body, "Neutral", tr("Aucun résultat pour l'instant."))
    end
end

render = function()
    if (panel :: any) == nil or not panel.Visible then
        return
    end
    InputRouter.armConfirm()
    local keep = body.CanvasPosition
    shell:clear()
    shell:selectTab(tab)
    shell.Context.Text = if current and not current.None
        then tr("Épreuve : %s", tostring(current.Name))
        else tr("Aucune épreuve en cours")
    if tab == "Épreuves" then
        renderCatalog()
    elseif tab == "Mon épreuve" then
        renderCurrent()
    elseif tab == "Classements" then
        renderRanking()
    else
        renderResults()
    end
    task.defer(function()
        body.CanvasPosition = keep
    end)
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
            Color = if index == 1 then UITheme.color("Gps") else UITheme.color("Line"),
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

local function showToast(message: string, seconds: number?)
    toast.Text = message
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
    -- Écran plein : au-dessus du HUD (la mini-carte recouvrait le panneau, VM 20261105-125026), comme le garage.
    local gui = make(
        "ScreenGui",
        { Name = "AWRacing", ResetOnSpawn = false, DisplayOrder = 20 },
        player:WaitForChild("PlayerGui")
    )

    -- Affichage de course compact (haut à droite) : carte V1.2 à filet rouge (réservé à la course et au chrono),
    -- valeur principale en Roboto Mono gras italique (style « Race »), informations en Roboto Mono.
    hud = make("Frame", {
        Name = "AffichageCourse",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -16, 0, 120),
        Size = UDim2.fromOffset(340, 96),
        BackgroundColor3 = Tokens.color("BgBase"),
        BackgroundTransparency = 0.12,
        Visible = false,
    }, gui)
    make("UICorner", { CornerRadius = UDim.new(0, Tokens.Radius.Card) }, hud)
    make("UIStroke", { Color = Tokens.color("Line"), Thickness = 1 }, hud)
    make("Frame", {
        Name = "Filet",
        BackgroundColor3 = Tokens.color("RaceRed"),
        BorderSizePixel = 0,
        Size = UDim2.new(0, Tokens.StatusRail, 1, 0),
    }, hud)
    hudTitle = make("TextLabel", {
        Position = UDim2.fromOffset(14, 6),
        Size = UDim2.new(1, -24, 0, 18),
        BackgroundTransparency = 1,
        TextColor3 = Tokens.color("TextMuted"),
        Text = "",
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, hud)
    hudTitle.FontFace = UITheme.face("Label")
    hudTitle.TextSize = UITheme.text(12)
    hudMain = make("TextLabel", {
        Position = UDim2.fromOffset(14, 24),
        Size = UDim2.new(1, -24, 0, 36),
        BackgroundTransparency = 1,
        TextColor3 = Tokens.color("Text"),
        Text = "",
        TextXAlignment = Enum.TextXAlignment.Left,
        TextScaled = false,
    }, hud)
    hudMain.FontFace = UITheme.face("Race")
    hudMain.TextSize = UITheme.text(Tokens.Type.Race.Size)
    hudInfo = make("TextLabel", {
        Position = UDim2.fromOffset(14, 62),
        Size = UDim2.new(1, -24, 0, 30),
        BackgroundTransparency = 1,
        TextColor3 = Tokens.color("Text"),
        Text = "",
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, hud)
    hudInfo.FontFace = UITheme.face("Value")
    hudInfo.TextSize = UITheme.text(12)
    toast = make("TextLabel", {
        Name = "AnnonceCourse",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 140),
        Size = UDim2.fromOffset(440, 40),
        BackgroundColor3 = Tokens.color("DangerBg"),
        BackgroundTransparency = 0.08,
        TextColor3 = Tokens.color("DangerText"),
        Visible = false,
        Text = "",
    }, gui)
    toast.FontFace = UITheme.face("Button")
    toast.TextSize = UITheme.text(18)
    make("UICorner", { CornerRadius = UDim.new(0, Tokens.Radius.Button) }, toast)
    make("UIStroke", { Color = Tokens.color("RaceRed"), Thickness = 1 }, toast)

    -- Panneau plein écran V1.2 (PanelKit) : barre haute, onglets à filet, contenu, état du serveur, barre d'aide.
    shell = PanelKit.shell(gui, "Courses", tr("Courses"), TABS, tr, function(id: string)
        tab = id
        render()
    end, toggle)
    panel = shell.Panel
    body = shell.Body
    local function hints()
        shell:hints(
            if PanelKit.isGamepad()
                then { { "LB / RB", tr("Onglets") }, { "A", tr("Valider") }, { "B", tr("Retour") } }
                else { { "K", tr("Fermer") }, { tr("Retour arrière"), tr("Retour") } }
        )
    end
    hints()
    game:GetService("UserInputService").LastInputTypeChanged:Connect(hints)
    game:GetService("UserInputService").InputBegan:Connect(function(input: InputObject)
        if not panel.Visible or gui:FindFirstChild("VoileConfirmation") then
            return
        end
        local index = table.find(TABS, tab) or 1
        if input.KeyCode == Enum.KeyCode.ButtonR1 or input.KeyCode == Enum.KeyCode.PageDown then
            tab = TABS[index % #TABS + 1]
            render()
        elseif input.KeyCode == Enum.KeyCode.ButtonL1 or input.KeyCode == Enum.KeyCode.PageUp then
            tab = TABS[(index - 2) % #TABS + 1]
            render()
        end
    end)

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
            local message = EVENT_TEXT[data]
            if message then
                showToast(tr(message))
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
        for name, item in shell.Tabs do
            item.Text = tr(name)
        end
        shell.Close.Text = tr("Fermer")
        shell.Title.Text = Tokens.upper(tr("Courses"))
        hints()
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
            local veil = gui:FindFirstChild("VoileConfirmation")
            if veil then
                veil:Destroy()
            end
        end,
        Focus = function()
            return shell.Tabs[tab]
        end,
    })
end

return table.freeze(RacePanel)
