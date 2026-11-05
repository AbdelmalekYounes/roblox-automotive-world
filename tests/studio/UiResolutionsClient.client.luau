-- Essais CLIENT des résolutions (lot UI V1.2, session « ui_resolutions ») : 1280 × 720, 1920 × 1080, 2560 × 1440 et
-- ultralarge 3440 × 1440.
--
-- Méthode (la fenêtre de jeu de la VM est fixe, 812 × 635) : la taille de vue des mises en page est surchargée
-- (attribut AWTestViewport, Studio seulement : UIState.viewport) et la racine de chaque écran est placée dans un
-- « écran virtuel » à la taille exacte de la résolution, réduit par un UIScale pour tenir dans la fenêtre. Les
-- mesures se font en proportions de cet écran virtuel. Limite : ce n'est pas un vrai changement de résolution de
-- Roblox (rendu des polices à l'échelle réduite pour la capture) ; un essai humain reste à faire sur écran réel.
-- Contrôles : écran plein ajusté, échelle et disposition compacte attendues, aucun élément hors de l'écran (sauf
-- contenu défilant), textes coupés (TextFits faux), boutons actifs hors d'atteinte, texte sous 11 px logiques.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local started = os.clock()
while ReplicatedStorage:GetAttribute("AWTestSession") == nil and os.clock() - started < 15 do
    task.wait()
end
if ReplicatedStorage:GetAttribute("AWTestSession") ~= "ui_resolutions" then
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
local ui = player:WaitForChild("PlayerScripts"):WaitForChild("AutomotiveWorldClient"):WaitForChild("UI")
local UIState = require(ui:WaitForChild("UIState")) :: any

record("ui_resolutions.client.entrees_reelles", (Gui.calibrate(3)))
record("ui_resolutions.client.clavier_etalonne", (Gui.calibrateKeys(3)))
local skip = nil
waitFor(function()
    skip = Gui.findButton(playerGui:FindFirstChild("AWOnboarding"), "Passer l'introduction")
    return skip ~= nil
end, 10)
if skip then
    Gui.click(skip, "Passer l'introduction")
    task.wait(1.5)
end
waitFor(function()
    return Gui.findButton(playerGui:FindFirstChild("AWBodyChoice"), "Masculin") ~= nil
end, 10)
for _ = 1, 4 do
    local dialog = playerGui:FindFirstChild("AWBodyChoice")
    local masculin = dialog and Gui.findButton(dialog, "Masculin")
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

local RESOLUTIONS = {
    { Name = "1280x720", Size = Vector2.new(1280, 720), Scale = 1, Compact = true },
    { Name = "1920x1080", Size = Vector2.new(1920, 1080), Scale = 1, Compact = false },
    { Name = "2560x1440", Size = Vector2.new(2560, 1440), Scale = 1.333, Compact = false },
    { Name = "3440x1440", Size = Vector2.new(3440, 1440), Scale = 1.333, Compact = false },
}

-- Écran virtuel : cadre à la taille de la résolution, réduit pour tenir dans la fenêtre, centré.
local virtualGui = Instance.new("ScreenGui")
virtualGui.Name = "AWEcranVirtuel"
virtualGui.IgnoreGuiInset = true
virtualGui.DisplayOrder = 100
virtualGui.ResetOnSpawn = false
virtualGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
virtualGui.Parent = playerGui
local screen = Instance.new("Frame")
screen.Name = "Ecran"
screen.AnchorPoint = Vector2.new(0.5, 0.5)
screen.Position = UDim2.fromScale(0.5, 0.5)
screen.BackgroundColor3 = Color3.fromRGB(8, 9, 10)
screen.BorderSizePixel = 0
screen.Parent = virtualGui
local fit = Instance.new("UIScale")
fit.Parent = screen

local function within(item: GuiObject, frame: GuiObject, tolerance: number): boolean
    local a, s = item.AbsolutePosition, item.AbsoluteSize
    local b, t = frame.AbsolutePosition, frame.AbsoluteSize
    return a.X >= b.X - tolerance
        and a.Y >= b.Y - tolerance
        and a.X + s.X <= b.X + t.X + tolerance
        and a.Y + s.Y <= b.Y + t.Y + tolerance
end

local function scroller(item: Instance): ScrollingFrame?
    local node = item.Parent
    while node and node ~= screen do
        if node:IsA("ScrollingFrame") then
            return node
        end
        node = node.Parent
    end
    return nil
end

local function shown(item: GuiObject): boolean
    local node: Instance? = item
    while node and node ~= screen do
        if node:IsA("GuiObject") and not node.Visible then
            return false
        end
        node = node.Parent
    end
    return true
end

-- Mesures d'une racine placée dans l'écran virtuel.
local function audit(root: GuiObject)
    local outside, cut, ellipsis, unreachable, small = 0, 0, 0, 0, 0
    local examples = {}
    local px = fit.Scale -- pixels d'écran par pixel virtuel
    for _, item in root:GetDescendants() do
        if item:IsA("GuiObject") and shown(item) and item.AbsoluteSize.X > 0 then
            local list = scroller(item)
            local text = (item:IsA("TextLabel") or item:IsA("TextButton")) and (item :: any).Text ~= ""
            if list then
                -- Contenu défilant : seule la largeur compte (le défilement vertical donne accès au reste).
                local a, s = item.AbsolutePosition, item.AbsoluteSize
                local b, t = list.AbsolutePosition, list.AbsoluteSize
                if text and a.X + s.X > b.X + t.X + 2 then
                    outside += 1
                    if #examples < 3 then
                        table.insert(examples, item.Name)
                    end
                end
            elseif (text or item:IsA("GuiButton")) and not within(item, screen, 2) then
                outside += 1
                if #examples < 3 then
                    table.insert(examples, item.Name)
                end
            end
            if text then
                local label = item :: any
                -- Largeur automatique (la boîte suit le texte) : TextFits peut être faux par simple arrondi du rendu
                -- réduit de l'écran virtuel (boutons « Fil », « Aster » entiers sur la capture 20261105-131324).
                local autoWidth = label.AutomaticSize == Enum.AutomaticSize.X
                    or label.AutomaticSize == Enum.AutomaticSize.XY
                if not label.TextFits and not autoWidth then
                    if label.TextTruncate == Enum.TextTruncate.AtEnd then
                        ellipsis += 1
                    elseif not label.TextWrapped and not label.TextScaled then
                        cut += 1
                        if #examples < 3 then
                            table.insert(examples, "coupé:" .. item.Name)
                        end
                    end
                end
                -- Taille logique du texte : taille rendue (pixels d'écran) / (réduction de l'écran virtuel × échelle).
                local logical = label.TextBounds.Y / math.max(px, 1e-3)
                if label.TextSize < Tokens.MinTextSize and logical > 0 then
                    small += 1
                end
            end
            if item:IsA("GuiButton") and item.Active and list == nil and not within(item, screen, 2) then
                unreachable += 1
            end
        end
    end
    return outside, cut, ellipsis, unreachable, small, table.concat(examples, ", ")
end

local function scaleOf(root: Instance): (any, any)
    local logical = root:FindFirstChild("Logique", true)
    if logical then
        return logical:GetAttribute("AWScale"), logical:GetAttribute("AWCompact")
    end
    local deviceScale = root:FindFirstChildOfClass("UIScale")
    return if deviceScale then math.floor(deviceScale.Scale * 1000 + 0.5) / 1000 else nil, nil
end

-- Place la racine dans l'écran virtuel pour chaque résolution, mesure, capture, puis la remet en place.
local function sweep(label: string, root: GuiObject, full: boolean, prepare: (() -> ())?)
    local home = root.Parent
    for _, resolution in RESOLUTIONS do
        ReplicatedStorage:SetAttribute("AWTestViewport", resolution.Size)
        screen.Size = UDim2.fromOffset(resolution.Size.X, resolution.Size.Y)
        local window = (Workspace.CurrentCamera :: Camera).ViewportSize
        fit.Scale = math.min(window.X / resolution.Size.X, window.Y / resolution.Size.Y)
        root.Parent = screen
        if prepare then
            prepare()
        end
        task.wait(1.2)
        local outside, cut, ellipsis, unreachable, small, examples = audit(root)
        local scale, compact = scaleOf(root)
        local fills = not full
            or (
                math.abs(root.AbsoluteSize.X - screen.AbsoluteSize.X) <= 2
                and math.abs(root.AbsoluteSize.Y - screen.AbsoluteSize.Y) <= 2
            )
        local scaleOk = scale == nil or math.abs((scale :: number) - resolution.Scale) < 0.01
        local compactOk = compact == nil or compact == resolution.Compact
        record(
            string.format("ui_resolutions.%s.%s", label, resolution.Name),
            fills and scaleOk and compactOk and outside == 0 and cut == 0 and unreachable == 0 and small == 0,
            string.format(
                "échelle %s, compacte %s ; plein %s ; hors écran %d, coupés %d, tronqués « … » %d, inaccessibles %d, sous 11 px %d %s",
                tostring(scale),
                tostring(compact),
                tostring(fills),
                outside,
                cut,
                ellipsis,
                unreachable,
                small,
                examples
            )
        )
        Gui.shot(string.format("ui_resolutions_%s_%s", label, resolution.Name), { lot = "UI V1.2" })
    end
    root.Parent = home
    ReplicatedStorage:SetAttribute("AWTestViewport", nil)
    task.wait(0.5)
end

-- 1. Garage (P) : collection puis préparation (panneau latéral le plus large).
Gui.key("P")
local garageGui = playerGui:WaitForChild("AWProgression", 10)
local garage = garageGui and garageGui:WaitForChild("Garage", 10) :: Frame?
if garage and waitFor(function()
    return garage.Visible
end, 5) then
    task.wait(1.5)
    sweep("garage_collection", garage, true)
    local tabsBar = garage:FindFirstChild("Onglets", true)
    Gui.click(tabsBar and Gui.findButton(tabsBar, "Préparation"), "Préparation")
    task.wait(1)
    sweep("garage_preparation", garage, true)
    Gui.click(garage:FindFirstChild("Fermer", true) :: GuiButton?, "Fermer")
    task.wait(0.8)
else
    record("ui_resolutions.garage_ouverture", false, "garage non ouvert")
end

-- 2. Économie (J) : onglet Concession (grille de cartes).
Gui.key("J")
local economyGui = playerGui:WaitForChild("AWEconomy", 10)
local economy = economyGui and economyGui:WaitForChild("Economie", 10) :: Frame?
if economy and waitFor(function()
    return economy.Visible
end, 5) then
    task.wait(1)
    local tabsBar = economy:FindFirstChild("Onglets", true)
    Gui.click(tabsBar and Gui.findButton(tabsBar, "Concession"), "Concession")
    task.wait(1)
    sweep("economie_concession", economy, true)
    Gui.click(economy:FindFirstChild("Fermer", true) :: GuiButton?, "Fermer")
    task.wait(0.8)
else
    record("ui_resolutions.economie_ouverture", false, "économie non ouverte")
end

-- 3. Courses (K) : épreuves.
Gui.key("K")
local raceGui = playerGui:WaitForChild("AWRacing", 10)
local races = raceGui and raceGui:WaitForChild("Courses", 10) :: Frame?
if races and waitFor(function()
    return races.Visible
end, 5) then
    task.wait(1)
    sweep("courses_epreuves", races, true)
    Gui.click(races:FindFirstChild("Fermer", true) :: GuiButton?, "Fermer")
    task.wait(0.8)
else
    record("ui_resolutions.courses_ouverture", false, "courses non ouvertes")
end

-- 4. Téléphone (T) : accueil (coque à l'échelle, grille des 12 applications).
Gui.key("T")
local phoneGui = playerGui:WaitForChild("AWPhone", 10) :: ScreenGui
if waitFor(function()
    return phoneGui.Enabled
end, 5) then
    task.wait(1)
    local device = phoneGui:FindFirstChild("Coque") :: Frame?
    if device then
        sweep("telephone_accueil", device, false)
    end
    Gui.key("T")
    task.wait(0.6)
else
    record("ui_resolutions.telephone_ouverture", false, "téléphone non ouvert")
end

virtualGui:Destroy()
local shots = Gui.report().shots
record("ui_resolutions.captures", #shots > 0, #shots)
reportEvent:FireServer({ vehicle = "ui_resolutions", steps = steps, measures = { captures = #shots } })
