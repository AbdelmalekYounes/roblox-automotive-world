-- Essais CLIENT des lots UI-03 et UI-04, une session par lot (demande du propriétaire : tester uniquement ce qui est
-- nouveau) :
--   « ui_garage » : garage V1.2 seul (touche P, disposition de la maquette, panneau latéral par onglet) ;
--   « ui_panels » : panneaux économie (J) et courses (K) seuls (police, onglet actif, fermeture).
-- Vraies touches et vrais clics dans la VM (GuiDriver).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local started = os.clock()
while ReplicatedStorage:GetAttribute("AWTestSession") == nil and os.clock() - started < 15 do
    task.wait()
end
local session = ReplicatedStorage:GetAttribute("AWTestSession")
if session ~= "ui_garage" and session ~= "ui_panels" then
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
local Tokens = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("DesignTokens")) :: any
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local UIState = require(
    player
        :WaitForChild("PlayerScripts")
        :WaitForChild("AutomotiveWorldClient")
        :WaitForChild("UI")
        :WaitForChild("UIState")
) :: any

record(session .. ".client.entrees_reelles", (Gui.calibrate(3)))
record(session .. ".client.clavier_etalonne", (Gui.calibrateKeys(3)))
local skip = nil
waitFor(function()
    skip = Gui.findButton(playerGui:FindFirstChild("AWOnboarding"), "Passer l'introduction")
    return skip ~= nil
end, 10)
if skip then
    Gui.click(skip, "Passer l'introduction")
    task.wait(1.5)
end
local masculin = Gui.findButton(playerGui, "Masculin")
if masculin and Gui.shown(masculin) then
    Gui.click(masculin, "Masculin")
    task.wait(2)
end
for _ = 1, 4 do
    if not UIState.capturesDriving() then
        break
    end
    Gui.key("Backspace")
    task.wait(0.8)
end

-- Police : toutes les zones de texte visibles d'un écran en Titillium Web (aucun Gotham restant).
local function fontAudit(root: Instance): (boolean, string)
    local total, gotham, examples = 0, 0, {}
    for _, item in root:GetDescendants() do
        if (item:IsA("TextLabel") or item:IsA("TextButton")) and Gui.shown(item) and item.Text ~= "" then
            total += 1
            local family = tostring(item.FontFace.Family)
            if not string.find(family, "TitilliumWeb", 1, true) and not string.find(family, "RobotoMono", 1, true) then
                gotham += 1
                if #examples < 3 then
                    table.insert(examples, item:GetFullName() .. " « " .. string.sub(item.Text, 1, 30) .. " »")
                end
            end
        end
    end
    return total > 0 and gotham == 0,
        string.format("%d textes, %d hors police V1.2 %s", total, gotham, table.concat(examples, ", "))
end

if session == "ui_garage" then
    local gui = playerGui:WaitForChild("AWProgression", 20) :: ScreenGui
    local panel = gui:WaitForChild("Garage", 10) :: Frame
    Gui.key("P")
    local opened = waitFor(function()
        return panel.Visible
    end, 5)
    record("ui_garage.ouverture_touche_P", opened)
    task.wait(1.5)
    local view = (Workspace.CurrentCamera :: Camera).ViewportSize
    local compact = Tokens.layout(view.X, view.Y).Compact
    local top = panel:FindFirstChild("BarreHaute") :: Frame?
    local tabsBar = panel:FindFirstChild("Onglets") :: Frame?
    local help = panel:FindFirstChild("BarreAide") :: Frame?
    record(
        "ui_garage.disposition_maquette",
        top ~= nil
            and tabsBar ~= nil
            and help ~= nil
            and math.abs(top.AbsoluteSize.Y - Tokens.Garage.TopBar) <= 1
            and math.abs(tabsBar.AbsoluteSize.Y - Tokens.Garage.Tabs) <= 1
            and math.abs(help.AbsoluteSize.Y - Tokens.Garage.HelpBar) <= 1,
        string.format(
            "barre haute %s, onglets %s, aide %s",
            tostring(top and top.AbsoluteSize.Y),
            tostring(tabsBar and tabsBar.AbsoluteSize.Y),
            tostring(help and help.AbsoluteSize.Y)
        )
    )
    Gui.shot("ui_garage_collection", { lot = "UI-03" })
    -- Onglets (vrais clics) : filet ambre sur l'onglet actif, panneau latéral à la largeur de la maquette.
    local sizes = Tokens.Garage.SidePanel
    for _, spec in
        {
            { "Véhicule", sizes.Vehicle },
            { "Préparation", sizes.Preparation },
            { "Configurations", sizes.Other },
        }
    do
        local tab = Gui.findButton(tabsBar, spec[1])
        local ok = Gui.click(tab, spec[1])
        task.wait(0.6)
        local expected = if compact then spec[2][2] else spec[2][1]
        local rail = tab and tab:FindFirstChild("Filet") :: Frame?
        record(
            "ui_garage.onglet_" .. spec[1],
            ok and rail ~= nil and rail.Visible and panel:GetAttribute("AWSidePanelWidth") == expected,
            string.format(
                "panneau %s (attendu %d) ; filet %s",
                tostring(panel:GetAttribute("AWSidePanelWidth")),
                expected,
                tostring(rail and rail.Visible)
            )
        )
        Gui.shot("ui_garage_" .. spec[1], { lot = "UI-03" })
    end
    local fontsOk, fontsDetail = fontAudit(panel)
    record("ui_garage.police_v12", fontsOk, fontsDetail)
    local close = panel:FindFirstChild("Fermer", true) :: GuiButton?
    Gui.click(close, "Fermer")
    record(
        "ui_garage.fermer",
        waitFor(function()
            return not panel.Visible
        end, 3)
    )
else
    -- Économie (J) puis courses (K) : ouverture, police, onglet actif, fermeture (touche Retour).
    for _, spec in { { "J", "AWEconomy", "Economy" }, { "K", "AWRacing", "Races" } } do
        local before = {}
        for _, item in playerGui:GetChildren() do
            before[item] = true
        end
        Gui.key(spec[1])
        task.wait(1.5)
        local shown: ScreenGui? = nil
        for _, item in playerGui:GetChildren() do
            if item:IsA("ScreenGui") and item.Enabled then
                for _, frame in item:GetChildren() do
                    if
                        frame:IsA("Frame")
                        and frame.Visible
                        and frame.AbsoluteSize.X > 500
                        and (string.find(item.Name, spec[2], 1, true) or string.find(item.Name, spec[3], 1, true))
                    then
                        shown = item
                    end
                end
            end
        end
        record("ui_panels.ouverture_" .. spec[3], shown ~= nil, if shown then shown.Name else "aucun panneau visible")
        if shown then
            local fontsOk, fontsDetail = fontAudit(shown)
            record("ui_panels.police_v12_" .. spec[3], fontsOk, fontsDetail)
            local soft = Tokens.Colors.AmberSoft
            local active = false
            for _, item in shown:GetDescendants() do
                if
                    item:IsA("TextButton")
                    and Gui.shown(item)
                    and (item.BackgroundColor3.R - soft.R) ^ 2 + (item.BackgroundColor3.G - soft.G) ^ 2 < 1e-4
                then
                    active = true
                end
            end
            record("ui_panels.onglet_actif_ambre_" .. spec[3], active)
            Gui.shot("ui_panels_" .. spec[3], { lot = "UI-04" })
        end
        Gui.key("Backspace")
        task.wait(1)
        Gui.key(spec[1])
        task.wait(1)
    end
end

local shots = Gui.report().shots
record(session .. ".captures", #shots > 0, #shots)
reportEvent:FireServer({ vehicle = session, steps = steps, measures = { captures = #shots } })
