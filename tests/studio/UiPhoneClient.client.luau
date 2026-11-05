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
-- La fenêtre de silhouette d'un profil neuf apparaît quelques secondes après l'arrivée : on l'attend (sans cela elle
-- restait ouverte par-dessus les écrans testés, VM 20261105-123345).
local masculin = nil
waitFor(function()
    masculin = Gui.findButton(playerGui:FindFirstChild("AWBodyChoice"), "Masculin")
    return masculin ~= nil
end, 10)
-- Un clic pendant le chargement de l'apparence est refusé par le serveur (« apparence en chargement ») et la
-- fenêtre reste ouverte : on reclique, comme un joueur, jusqu'à sa fermeture.
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

-- 2. Accueil : 12 tuiles nommées, chacune avec son image envoyée par le propriétaire (plus aucun cadre vide).
local tiles, images, empty = 0, {}, 0
for _, item in phone:GetDescendants() do
    if item:IsA("TextButton") and string.sub(item.Name, 1, 3) == "App" then
        tiles += 1
        local icon = item:FindFirstChild("Icone", true)
        if icon and icon:IsA("ImageLabel") then
            table.insert(images, icon)
        end
        if item:FindFirstChild("IconeAEnvoyer", true) then
            empty += 1
        end
    end
end
record(
    "ui_phone.accueil_douze_tuiles",
    tiles == 12 and #images == 12 and empty == 0,
    string.format("%d tuiles, %d images, %d cadres vides", tiles, #images, empty)
)
-- Chargement réel des 12 images depuis Roblox (IsLoaded), teinte de la planche : cyan pour la carte, ambre sinon.
local loaded = waitFor(function()
    for _, icon in images do
        if not icon.IsLoaded then
            return false
        end
    end
    return #images == 12
end, 20)
local missing = {}
local tintOk = true
for _, icon in images do
    local app = string.sub((icon:FindFirstAncestorWhichIsA("TextButton") :: Instance).Name, 4)
    if not icon.IsLoaded then
        table.insert(missing, app)
    end
    local c = icon.ImageColor3
    local expected = if app == "Map" then Color3.fromRGB(92, 200, 214) else Color3.fromRGB(232, 163, 61)
    if math.abs(c.R - expected.R) + math.abs(c.G - expected.G) + math.abs(c.B - expected.B) > 0.02 then
        tintOk = false
    end
end
record(
    "ui_phone.icones_chargees",
    loaded,
    if #missing == 0 then "12 / 12 chargées" else "non chargées : " .. table.concat(missing, ", ")
)
record("ui_phone.icones_teinte", tintOk, "carte cyan 92,200,214 ; autres ambre 232,163,61")
Gui.shot("ui_phone_accueil", { lot = "UI-02" })

-- 3. Les 12 applications (vrai clic sur la tuile, titre, retour par l'en-tête) ; structure de la maquette : titres de
-- section, cartes à filet, boutons à valeur ; aucun texte ne dépasse la largeur de l'écran du téléphone.
local title = phone:FindFirstChild("Titre", true) :: TextLabel?
local screenBody = phone:FindFirstChild("Contenu", true)
local function census(): (number, number, number, number)
    local cards, valued, overflow, texts = 0, 0, 0, 0
    if screenBody == nil then
        return 0, 0, 0, 0
    end
    local right = (screenBody :: GuiObject).AbsolutePosition.X + (screenBody :: GuiObject).AbsoluteSize.X + 1
    for _, item in screenBody:GetDescendants() do
        if item:IsA("Frame") and item:FindFirstChild("Filet") and item:FindFirstChild("Titre", true) then
            cards += 1
        elseif item:IsA("TextLabel") and item.Name == "Valeur" and item.Parent and item.Parent:IsA("TextButton") then
            valued += 1
        end
        if (item:IsA("TextLabel") or item:IsA("TextButton")) and item.Visible and item.Text ~= "" then
            texts += 1
            if item.AbsolutePosition.X + item.AbsoluteSize.X > right then
                overflow += 1
            end
        end
    end
    return cards, valued, overflow, texts
end
local APPS = {
    "Carte",
    "Véhicules",
    "Propriétés",
    "Missions",
    "Courses",
    "Marché",
    "Social",
    "Radio",
    "Photo",
    "Guide",
    "Notifications",
    "Paramètres",
}
for _, app in APPS do
    local ok = Gui.click(phoneButton(app), app)
    task.wait(1.2)
    local shown = title ~= nil and title.Text == app
    local cards, valued, overflow, texts = census()
    record(
        "ui_phone.app_" .. app,
        ok and shown and overflow == 0 and texts > 0,
        string.format(
            "titre « %s », %d carte(s), %d bouton(s) à valeur, %d texte(s), %d débordant(s)",
            if title then title.Text else "absent",
            cards,
            valued,
            texts,
            overflow
        )
    )
    Gui.shot("ui_phone_" .. app, { lot = "UI-02" })
    if app == "Véhicules" then
        local garageButton = phone:FindFirstChild("OuvrirGarage", true) :: TextButton?
        local vehicleCards = 0
        for _, item in phone:GetDescendants() do
            if item:IsA("Frame") and string.sub(item.Name, 1, 9) == "Vehicule_" and item:FindFirstChild("Filet") then
                vehicleCards += 1
            end
        end
        record(
            "ui_phone.vehicules_cartes",
            vehicleCards >= 3 and garageButton ~= nil and garageButton:FindFirstChild("Valeur") ~= nil,
            string.format(
                "%d carte(s) de véhicule ; bouton du garage %s",
                vehicleCards,
                if garageButton then "présent (valeur P)" else "absent"
            )
        )
    end
    if app ~= "Paramètres" then
        local back = phoneButton("Retour")
        local okBack = Gui.click(back, "Retour")
        task.wait(0.5)
        record("ui_phone.retour_" .. app, okBack and title ~= nil and title.Text == "Accueil")
    end
end
-- Paramètres : réglages présentés « libellé | valeur » (maquette).
do
    local pairs, total = 0, 0
    for _, item in phone:GetDescendants() do
        if item:IsA("TextButton") and item.Name == "Reglage" then
            total += 1
            if item:FindFirstChild("Valeur") then
                pairs += 1
            end
        end
    end
    record(
        "ui_phone.parametres_valeurs",
        total > 0 and pairs == total,
        string.format("%d réglage(s), %d avec valeur à droite", total, pairs)
    )
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

-- 7. Mode rapide EN CONDUITE (demande du propriétaire) : montée réelle (E) dans le prototype P-01 (boîte automatique),
-- accélérateur maintenu (W), puis T : écran rapide (étiquette « mode rapide », aucune grille d'applications, aucun
-- bouton sélectionnable), garage refusé (P) ; à l'arrêt, le téléphone revient à l'écran complet.
local client = player:WaitForChild("PlayerScripts"):WaitForChild("AutomotiveWorldClient")
local VehicleController = require(client:WaitForChild("Vehicles"):WaitForChild("VehicleController", 10)) :: any
local function speed(): number
    local ok, snapshot = pcall(VehicleController.getTestSnapshot)
    return if ok and type(snapshot) == "table" then snapshot.SpeedKmh or 0 else 0
end
local function seated(): boolean
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.SeatPart ~= nil and humanoid.SeatPart.Name == "DriverSeat"
end
local fleet = Workspace:FindFirstChild("VehiculesEssai")
local car: Model? = nil
if fleet then
    for _, item in fleet:GetChildren() do
        if
            item:IsA("Model")
            and item:GetAttribute("DriverUserId") == 0
            and item:GetAttribute("DefinitionId") == "proto_p01"
            and item:FindFirstChild("DriverSeat", true)
        then
            car = item
            break
        end
    end
end
if car then
    local door = car:FindFirstChild("DriverDoor", true) :: Attachment?
    local target = if door then door.WorldPosition else car:GetPivot().Position
    for _ = 1, 3 do
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
        if root then
            local from = target + Vector3.new(3, 3, 0)
            root.CFrame = CFrame.lookAt(from, Vector3.new(target.X, from.Y, target.Z))
            root.AssemblyLinearVelocity = Vector3.zero
        end
        task.wait(1.2)
        Gui.key("E", 800)
        if waitFor(seated, 4) then
            break
        end
    end
end
record("ui_phone.conduite.embarquement_touche_E", seated(), if car then car.Name else "aucun P-01 libre")
if seated() then
    task.wait(1.5)
    Gui.keyDown("W")
    local moving = waitFor(function()
        return speed() > 15
    end, 8)
    record("ui_phone.conduite.accelerateur_W", moving, string.format("%.1f km/h", speed()))
    if moving then
        Gui.key("T")
        local quickOpened = waitFor(function()
            return phone.Enabled
        end, 3)
        task.wait(0.4)
        local tag = phone:FindFirstChild("ModeRapide", true) :: GuiObject?
        local grid = phone:FindFirstChild("Grille", true)
        local selectable = 0
        for _, item in phone:GetDescendants() do
            if
                item:IsA("GuiButton")
                and item.Selectable
                and Gui.shown(item)
                and item:IsDescendantOf(screenBody :: Instance)
            then
                selectable += 1
            end
        end
        local warnBox = phone:FindFirstChild("Avertissement", true)
        -- Étiquette « mode rapide » et titre contenus dans la coque (débordement constaté, VM 20261105-123345).
        local shell = phone:FindFirstChild("Coque") :: GuiObject?
        local inDevice = shell ~= nil
            and tag ~= nil
            and tag.AbsolutePosition.X >= shell.AbsolutePosition.X
            and tag.AbsolutePosition.X + tag.AbsoluteSize.X <= shell.AbsolutePosition.X + shell.AbsoluteSize.X
        record(
            "ui_phone.conduite.mode_rapide",
            quickOpened
                and inDevice
                and tag ~= nil
                and tag.Visible
                and grid == nil
                and selectable == 0
                and warnBox ~= nil,
            string.format(
                "%.1f km/h, étiquette %s, grille %s, %d bouton(s) sélectionnable(s) dans l'écran, avertissement %s",
                speed(),
                tostring(tag and tag.Visible),
                tostring(grid ~= nil),
                selectable,
                tostring(warnBox ~= nil)
            )
        )
        Gui.shot("ui_phone_mode_rapide_conduite", { lot = "UI-02", kmh = speed() })
        Gui.key("P")
        task.wait(1)
        local garage = playerGui:FindFirstChild("AWProgression")
        local garagePanel = garage and garage:FindFirstChild("Garage") :: GuiObject?
        record(
            "ui_phone.conduite.garage_refuse",
            garagePanel == nil or not garagePanel.Visible,
            string.format("%.1f km/h", speed())
        )
    end
    Gui.keyUp("W")
    Gui.keyDown("S")
    waitFor(function()
        return speed() < 2
    end, 12)
    Gui.keyUp("S")
    Gui.key("Space", 1200)
    task.wait(1.5)
    local tag = phone:FindFirstChild("ModeRapide", true) :: GuiObject?
    local fullAgain = phone.Enabled and (tag == nil or not tag.Visible)
    record(
        "ui_phone.conduite.retour_ecran_complet_arret",
        fullAgain,
        string.format("%.1f km/h, téléphone ouvert %s", speed(), tostring(phone.Enabled))
    )
    Gui.shot("ui_phone_arret_ecran_complet", { lot = "UI-02" })
    if phone.Enabled then
        Gui.key("T")
    end
end

local shots = Gui.report().shots
record("ui_phone.captures", #shots > 0, #shots)
reportEvent:FireServer({ vehicle = "ui_phone", steps = steps, measures = { captures = #shots } })
