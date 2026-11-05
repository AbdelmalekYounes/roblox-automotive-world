-- Essais CLIENT du lot UI-02 (session « ui_phone ») : le téléphone V1.2 SEUL (demande du propriétaire : tester
-- uniquement ce qui est nouveau). Vraies touches et vrais clics dans la VM (GuiDriver).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local started = os.clock()
while ReplicatedStorage:GetAttribute("AWTestSession") == nil and os.clock() - started < 15 do
    task.wait()
end
if ReplicatedStorage:GetAttribute("AWTestSession") ~= "ui_phone" then
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
local UIState = require(
    player
        :WaitForChild("PlayerScripts")
        :WaitForChild("AutomotiveWorldClient")
        :WaitForChild("UI")
        :WaitForChild("UIState")
) :: any

record("ui_phone.client.entrees_reelles", (Gui.calibrate(3)))
local keys = Gui.calibrateKeys(3)
record("ui_phone.client.clavier_etalonne", keys)
-- Fenêtres d'un profil neuf (comportement du jeu) : arrivée passée, silhouette choisie, modales fermées.
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

local phone = playerGui:WaitForChild("AWPhone", 20) :: ScreenGui
local function phoneButton(pattern: string): GuiButton?
    return Gui.findButton(phone, pattern)
end

-- 1. Ouverture par la vraie touche T ; téléphone entier dans la vue.
Gui.key("T")
local opened = waitFor(function()
    return phone.Enabled
end, 5)
record("ui_phone.ouverture_touche_T", opened)
task.wait(0.8)
local device = phone:FindFirstChild("Coque") :: Frame?
local inset = GuiService:GetGuiInset()
local view = (Workspace.CurrentCamera :: Camera).ViewportSize
local inside = device ~= nil
    and device.AbsolutePosition.Y >= -1
    and device.AbsolutePosition.Y + device.AbsoluteSize.Y <= view.Y - inset.Y + 1
    and device.AbsolutePosition.X + device.AbsoluteSize.X <= view.X + 1
record(
    "ui_phone.entier_dans_la_vue",
    inside,
    if device
        then string.format(
            "coque %.0f×%.0f en (%.0f, %.0f), vue %.0f×%.0f, taille %s",
            device.AbsoluteSize.X,
            device.AbsoluteSize.Y,
            device.AbsolutePosition.X,
            device.AbsolutePosition.Y,
            view.X,
            view.Y,
            tostring(phone:GetAttribute("AWPhoneSize"))
        )
        else "coque absente"
)

-- 2. Accueil : 12 tuiles nommées, emplacement d'icône (images pas encore envoyées), aucune icône en caractère.
local tiles, slots = 0, 0
for _, item in phone:GetDescendants() do
    if item:IsA("TextButton") and string.sub(item.Name, 1, 3) == "App" then
        tiles += 1
        if item:FindFirstChild("IconeAEnvoyer", true) or item:FindFirstChild("Icone", true) then
            slots += 1
        end
    end
end
record(
    "ui_phone.accueil_douze_tuiles",
    tiles == 12 and slots == 12,
    string.format("%d tuiles, %d icônes", tiles, slots)
)
Gui.shot("ui_phone_accueil", { lot = "UI-02" })

-- 3. Applications : vrai clic sur la tuile, titre de l'en-tête, retour par l'en-tête.
local title = phone:FindFirstChild("Titre", true) :: TextLabel?
for _, app in { "Carte", "Véhicules", "Notifications", "Paramètres" } do
    local ok = Gui.click(phoneButton(app), app)
    task.wait(0.6)
    local shown = title ~= nil and title.Text == app
    record("ui_phone.app_" .. app, ok and shown, if title then "titre « " .. title.Text .. " »" else "titre absent")
    if app ~= "Paramètres" then
        Gui.shot("ui_phone_" .. app, { lot = "UI-02" })
        local back = phoneButton("Retour")
        local okBack = Gui.click(back, "Retour")
        task.wait(0.5)
        record("ui_phone.retour_" .. app, okBack and title ~= nil and title.Text == "Accueil")
    end
end

-- 4. Paramètres › Crédits et licences : attribution de la Comète (auteur, licence).
-- Recherche directe : hors de la vue, le bouton n'est pas « affiché » pour findButton.
local credits: GuiButton? = nil
for _, item in phone:GetDescendants() do
    if item:IsA("TextButton") and string.find(item.Text, "Crédits et licences", 1, true) then
        credits = item
    end
end
-- Septième entrée des paramètres : défilement de la liste (molette réelle) jusqu'au bouton, comme un joueur.
if credits then
    Gui.reveal(credits, 12)
end
local okCredits = Gui.click(credits, "Crédits et licences")
task.wait(0.8)
local creditText = ""
for _, item in phone:GetDescendants() do
    if item:IsA("TextLabel") and string.find(item.Text, "_Sheep19", 1, true) then
        creditText = item.Text
    end
end
record(
    "ui_phone.credits_attribution",
    okCredits and string.find(creditText, "CC BY 4.0", 1, true) ~= nil,
    if creditText ~= "" then creditText else "attribution absente"
)
Gui.shot("ui_phone_credits", { lot = "UI-02" })
Gui.click(phoneButton("Retour"), "Retour")
task.wait(0.5)

-- 5. Agrandir (vrai clic) : taille changée, toujours dans la vue.
local before = phone:GetAttribute("AWPhoneSize")
Gui.click(phone:FindFirstChild("Agrandir", true) :: GuiButton?, "Agrandir")
task.wait(0.8)
local after = phone:GetAttribute("AWPhoneSize")
record("ui_phone.agrandir", after ~= nil and after ~= before, tostring(before) .. " → " .. tostring(after))
Gui.shot("ui_phone_agrandi", { lot = "UI-02" })

-- 6. Fermer (vrai clic).
Gui.click(phone:FindFirstChild("Fermer", true) :: GuiButton?, "Fermer")
record(
    "ui_phone.fermer",
    waitFor(function()
        return not phone.Enabled
    end, 3)
)

local shots = Gui.report().shots
record("ui_phone.captures", #shots > 0, #shots)
reportEvent:FireServer({ vehicle = "ui_phone", steps = steps, measures = { captures = #shots } })
