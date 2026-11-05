-- Essais CLIENT des panneaux Économie (J) et Courses (K) recomposés en V1.2 (lot UI-04, session « ui_panels2 ») :
-- panneau plein écran, onglets à filet ambre, cartes, raisons des boutons inactifs, bandeau d'état du serveur,
-- confirmation protégée, aucun débordement. Vraies touches et vrais clics dans la VM (GuiDriver).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local started = os.clock()
while ReplicatedStorage:GetAttribute("AWTestSession") == nil and os.clock() - started < 15 do
    task.wait()
end
if ReplicatedStorage:GetAttribute("AWTestSession") ~= "ui_panels2" then
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

local reportEvent = ReplicatedStorage:WaitForChild("AWTestReport", 30) :: RemoteEvent
local Gui = require(ReplicatedStorage:WaitForChild("AW_TestGui", 30)) :: any
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local ui = player:WaitForChild("PlayerScripts"):WaitForChild("AutomotiveWorldClient"):WaitForChild("UI")
local UIState = require(ui:WaitForChild("UIState")) :: any

record("ui_panels2.client.entrees_reelles", (Gui.calibrate(3)))
record("ui_panels2.client.clavier_etalonne", (Gui.calibrateKeys(3)))
local skip = nil
waitFor(function()
    skip = Gui.findButton(playerGui:FindFirstChild("AWOnboarding"), "Passer l'introduction")
    return skip ~= nil
end, 10)
if skip then
    Gui.click(skip, "Passer l'introduction")
    task.wait(1.5)
end
local masculin = nil
waitFor(function()
    masculin = Gui.findButton(playerGui:FindFirstChild("AWBodyChoice"), "Masculin")
    return masculin ~= nil
end, 10)
for _ = 1, 4 do
    local dialog = playerGui:FindFirstChild("AWBodyChoice")
    if dialog == nil then
        break
    end
    masculin = Gui.findButton(dialog, "Masculin")
    if masculin == nil or not Gui.shown(masculin) then
        break
    end
    Gui.click(masculin, "Masculin")
    task.wait(2.5)
end
for _ = 1, 4 do
    if not UIState.capturesDriving() then
        break
    end
    Gui.key("Backspace")
    task.wait(0.8)
end
local view = (Workspace.CurrentCamera :: Camera).ViewportSize
record("ui_panels2.resolution", true, string.format("vue %.0f × %.0f", view.X, view.Y))

-- Contrôles communs d'un panneau : plein écran, onglet actif à filet ambre, cartes, aucun texte hors du corps.
local function audit(panel: Frame, label: string)
    local body = panel:FindFirstChild("Corps", true) :: ScrollingFrame?
    local cards, overflow, disabledWithReason, disabled = 0, 0, 0, 0
    if body then
        local right = body.AbsolutePosition.X + body.AbsoluteSize.X + 1
        for _, item in body:GetDescendants() do
            if item:IsA("Frame") and item.Name == "CarteCorps" then
                cards += 1
            end
            if (item:IsA("TextLabel") or item:IsA("TextButton")) and Gui.shown(item) and item.Text ~= "" then
                if item.AbsolutePosition.X + item.AbsoluteSize.X > right then
                    overflow += 1
                end
            end
            if item:IsA("TextButton") and item:GetAttribute("AWDisabled") then
                disabled += 1
                if item:GetAttribute("AWReason") then
                    disabledWithReason += 1
                end
            end
        end
    end
    return cards, overflow, disabled, disabledWithReason
end

local function panelOf(guiName: string, frameName: string): Frame?
    local gui = playerGui:FindFirstChild(guiName)
    return gui and gui:FindFirstChild(frameName) :: Frame?
end

for _, spec in
    {
        {
            Key = "J",
            Gui = "AWEconomy",
            Frame = "Economie",
            Name = "economie",
            Tabs = { "Portefeuille", "Métiers", "Concession", "Marché", "Immobilier", "Services" },
        },
        {
            Key = "K",
            Gui = "AWRacing",
            Frame = "Courses",
            Name = "courses",
            Tabs = { "Épreuves", "Mon épreuve", "Classements", "Résultats" },
        },
    }
do
    Gui.key(spec.Key)
    local panel: Frame? = nil
    local opened = waitFor(function()
        panel = panelOf(spec.Gui, spec.Frame)
        return panel ~= nil and panel.Visible
    end, 5)
    local full = panel ~= nil and panel.AbsoluteSize.X >= view.X - 2 and panel.AbsoluteSize.Y >= view.Y - 80
    record(
        "ui_panels2." .. spec.Name .. ".ouverture_plein_ecran",
        opened and full,
        string.format(
            "touche %s, %s",
            spec.Key,
            if panel then string.format("%.0f × %.0f", panel.AbsoluteSize.X, panel.AbsoluteSize.Y) else "absent"
        )
    )
    if panel then
        local tabsBar = panel:FindFirstChild("Onglets", true) :: Frame
        for index, tab in spec.Tabs do
            local button = tabsBar and tabsBar:FindFirstChild("Onglet" .. index) :: TextButton?
            local ok = Gui.click(button, tab)
            local selected = waitFor(function()
                return panel:GetAttribute("AWTab") == tab
            end, 3)
            task.wait(1)
            local rail = button and button:FindFirstChild("Filet") :: Frame?
            local cards, overflow, disabled, reasons = audit(panel, tab)
            record(
                "ui_panels2." .. spec.Name .. ".onglet_" .. tab,
                ok and selected and rail ~= nil and rail.Visible and overflow == 0 and disabled == reasons,
                string.format(
                    "filet %s, %d carte(s), %d débordant(s), %d inactif(s) dont %d avec raison",
                    tostring(rail and rail.Visible),
                    cards,
                    overflow,
                    disabled,
                    reasons
                )
            )
            Gui.shot("ui_panels2_" .. spec.Name .. "_" .. index, { lot = "UI-04", tab = tab })
        end
        -- Économie, onglet Métiers : démarrer une mission (vrai clic) → état du serveur affiché (jamais simulé) ;
        -- puis abandon avec confirmation protégée si la mission a démarré.
        if spec.Name == "economie" then
            Gui.click(tabsBar:FindFirstChild("Onglet2") :: TextButton?, "Métiers")
            task.wait(1)
            local start = Gui.findButton(panel, "Démarrer")
            if start then
                Gui.click(start, "Démarrer")
                local answered = waitFor(function()
                    local kind = panel:GetAttribute("AWStatusKind")
                    return kind ~= nil
                end, 8)
                local message = panel:FindFirstChild("Message", true) :: TextLabel?
                record(
                    "ui_panels2.economie.etat_serveur_mission",
                    answered and panel:GetAttribute("AWStatusKind") ~= "Offline",
                    string.format(
                        "état %s, « %s »",
                        tostring(panel:GetAttribute("AWStatusKind")),
                        tostring(message and message.Text)
                    )
                )
                task.wait(1.5)
                Gui.shot("ui_panels2_economie_etat", { lot = "UI-04" })
                local abandon = Gui.findButton(panel, "Abandonner")
                if abandon then
                    Gui.click(abandon, "Abandonner")
                    local gui = playerGui:FindFirstChild(spec.Gui) :: ScreenGui
                    local veil = gui:WaitForChild("VoileConfirmation", 4)
                    local armed = veil
                        and waitFor(function()
                            local box = veil:FindFirstChild("ConfirmationProtegee", true)
                            return box ~= nil and box:GetAttribute("AWConfirmArmed") == true
                        end, 3)
                    record("ui_panels2.economie.confirmation_abandon", veil ~= nil and armed == true)
                    Gui.shot("ui_panels2_economie_confirmation", { lot = "UI-04" })
                    if veil then
                        Gui.click(Gui.findButton(veil, "Confirmer"), "Confirmer")
                        task.wait(2)
                    end
                end
            else
                record("ui_panels2.economie.etat_serveur_mission", false, "bouton Démarrer introuvable")
            end
        else
            -- Courses : détails d'un parcours (vrai clic) puis retour à la liste.
            Gui.click(tabsBar:FindFirstChild("Onglet1") :: TextButton?, "Épreuves")
            task.wait(1)
            local details = Gui.findButton(panel, "Détails")
            local okDetails = Gui.click(details, "Détails")
            task.wait(1)
            local back = Gui.findButton(panel, "Tous les parcours")
            record("ui_panels2.courses.details_parcours", okDetails and back ~= nil)
            Gui.shot("ui_panels2_courses_details", { lot = "UI-04" })
            if back then
                Gui.click(back, "Tous les parcours")
                task.wait(0.8)
            end
        end
        -- Fermeture par le bouton de la barre d'aide (vrai clic).
        Gui.click(panel:FindFirstChild("Fermer", true) :: GuiButton?, "Fermer")
        record(
            "ui_panels2." .. spec.Name .. ".fermer",
            waitFor(function()
                return not panel.Visible
            end, 3)
        )
    end
end

local shots = Gui.report().shots
record("ui_panels2.captures", #shots > 0, #shots)
reportEvent:FireServer({ vehicle = "ui_panels2", steps = steps, measures = { captures = #shots } })
