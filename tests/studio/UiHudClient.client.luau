-- Essais CLIENT du HUD, de la carte et des notifications en V1.2 (lot UI-04, session « ui_hud ») : notifications en
-- cartes à filet de niveau (sans pictogramme), carte complète (titre, liste des lieux avec distance, repères sans
-- caractère Unicode, destination), HUD de conduite (vitesse et unité séparées, mini-carte ronde, guidage en carte
-- cyan) en conduite réelle. Vraies touches et vrais clics dans la VM (GuiDriver).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local started = os.clock()
while ReplicatedStorage:GetAttribute("AWTestSession") == nil and os.clock() - started < 15 do
    task.wait()
end
if ReplicatedStorage:GetAttribute("AWTestSession") ~= "ui_hud" then
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
-- Pictogrammes interdits en guise d'icône : flèches, symboles et formes Unicode (2190–2BFF), émojis (1F000+).
-- La ponctuation typographique (« … », « · », « — ») reste permise.
local function ascii(text: string): boolean
    for _, code in utf8.codes(text) do
        if (code >= 0x2190 and code <= 0x2BFF) or code >= 0x1F000 then
            return false
        end
    end
    return true
end

local reportEvent = ReplicatedStorage:WaitForChild("AWTestReport", 30) :: RemoteEvent
local Gui = require(ReplicatedStorage:WaitForChild("AW_TestGui", 30)) :: any
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local client = player:WaitForChild("PlayerScripts"):WaitForChild("AutomotiveWorldClient")
local ui = client:WaitForChild("UI")
local UIState = require(ui:WaitForChild("UIState")) :: any
local NotificationService = require(ui:WaitForChild("NotificationService")) :: any
local GPSController = require(ui:WaitForChild("GPSController")) :: any
local VehicleController = require(client:WaitForChild("Vehicles"):WaitForChild("VehicleController", 10)) :: any

record("ui_hud.client.entrees_reelles", (Gui.calibrate(3)))
record("ui_hud.client.clavier_etalonne", (Gui.calibrateKeys(3)))
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

-- 1. Notifications : cartes à filet de couleur du niveau, libellé du niveau, aucun pictogramme.
NotificationService.notify("gps.computing", "Info", nil, "essai_info")
NotificationService.notify("notif.heavyDamage", "Warning", nil, "essai_avertissement")
task.wait(0.8)
local notifGui = playerGui:FindFirstChild("AWNotifications")
local cards, withRail, glyphs = 0, 0, 0
if notifGui then
    for _, item in notifGui:GetDescendants() do
        if item:IsA("Frame") and item.Name == "Notification" then
            cards += 1
            if item:FindFirstChild("Filet") and item:FindFirstChild("Niveau") then
                withRail += 1
            end
        end
        if item:IsA("TextLabel") and not ascii(item.Text) then
            glyphs += 1
        end
    end
end
record(
    "ui_hud.notifications_cartes",
    cards >= 2 and withRail == cards and glyphs == 0,
    string.format("%d carte(s), %d avec filet et niveau, %d texte(s) avec pictogramme", cards, withRail, glyphs)
)
Gui.shot("ui_hud_notifications", { lot = "UI-04" })

-- 2. Carte complète (vraie touche M) : titre, liste des lieux avec distance, repères sans caractère Unicode.
Gui.key("M")
local mapGui = playerGui:WaitForChild("AWMap", 10) :: ScreenGui
local mapOpen = waitFor(function()
    return mapGui.Enabled
end, 4)
task.wait(1.5)
local title = mapGui:FindFirstChild("Titre", true) :: TextLabel?
local places, valued = 0, 0
local markerGlyphs, markers = 0, 0
for _, item in mapGui:GetDescendants() do
    if item:IsA("TextButton") and item.Name == "Lieu" then
        places += 1
        if item:FindFirstChild("Valeur") then
            valued += 1
        end
    end
    if item:IsA("TextButton") and item.Parent and item.Parent.Name == "Carte" and item.Visible then
        markers += 1
        if not ascii(item.Text) then
            markerGlyphs += 1
        end
    end
end
record(
    "ui_hud.carte_complete",
    mapOpen and title ~= nil and title.Text == "CARTE" and places > 0 and valued == places and markerGlyphs == 0,
    string.format(
        "titre « %s », %d lieu(x) dont %d avec distance, %d repère(s) affiché(s), %d avec caractère Unicode",
        tostring(title and title.Text),
        places,
        valued,
        markers,
        markerGlyphs
    )
)
-- Destination par vrai clic sur le premier lieu de la liste.
local first: GuiButton? = nil
local list = mapGui:FindFirstChild("Lieux", true)
if list then
    -- Lieu le plus lointain de la liste (le plus proche peut être déjà atteint : arrivée immédiate).
    local best = -math.huge
    for _, item in list:GetChildren() do
        if item:IsA("TextButton") and item.LayoutOrder > best then
            first, best = item, item.LayoutOrder
        end
    end
end
-- Le dernier lieu peut être hors de la vue de la liste : défilement réel (molette) jusqu'à lui.
if first then
    Gui.reveal(first, 12)
end
Gui.click(first, "lieu le plus lointain")
local destination = waitFor(function()
    return GPSController.state().Destination ~= nil
end, 4)
task.wait(1)
local status = mapGui:FindFirstChild("Destination", true) :: TextLabel?
record(
    "ui_hud.carte_destination",
    destination and status ~= nil and status.Text ~= "" and status.Text ~= "Aucune destination.",
    if status then status.Text else "absent"
)
Gui.shot("ui_hud_carte", { lot = "UI-04" })
Gui.key("M")
waitFor(function()
    return not mapGui.Enabled
end, 3)
if mapGui.Enabled then
    Gui.key("Backspace")
end

-- 3. HUD en conduite réelle (P-01, boîte automatique) : vitesse et unité séparées, mini-carte ronde, guidage cyan.
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
record("ui_hud.embarquement_touche_E", seated(), if car then car.Name else "aucun P-01 libre")
if seated() then
    task.wait(1)
    Gui.keyDown("W")
    local moving = waitFor(function()
        return speed() > 12
    end, 8)
    task.wait(0.6)
    local hud = playerGui:FindFirstChild("AWHud")
    local speedLabel = hud and hud:FindFirstChild("Vitesse", true) :: TextLabel?
    local unit = hud and hud:FindFirstChild("Unite", true) :: TextLabel?
    local mask = hud and hud:FindFirstChild("MiniCarteMasque", true)
    local guidance = hud and hud:FindFirstChild("Guidage", true) :: Frame?
    local numeric = speedLabel ~= nil and string.match(speedLabel.Text, "^%d+$") ~= nil
    local round = mask ~= nil and mask:IsA("CanvasGroup") and mask:FindFirstChildOfClass("UICorner") ~= nil
    record(
        "ui_hud.tableau_conduite",
        moving and numeric and unit ~= nil and unit.Text == "KM/H" and round,
        string.format(
            "%.1f km/h ; vitesse « %s », unité « %s », mini-carte ronde %s",
            speed(),
            tostring(speedLabel and speedLabel.Text),
            tostring(unit and unit.Text),
            tostring(round)
        )
    )
    record(
        "ui_hud.guidage_carte_cyan",
        guidance ~= nil and guidance.Visible and guidance:FindFirstChild("Filet") ~= nil,
        if guidance
            then tostring(
                guidance:FindFirstChild("Consigne") :: TextLabel?
                    and (guidance:FindFirstChild("Consigne") :: TextLabel).Text
            )
            else "absent"
    )
    Gui.shot("ui_hud_conduite", { lot = "UI-04", kmh = speed() })
    Gui.keyUp("W")
    Gui.keyDown("S")
    waitFor(function()
        return speed() < 2
    end, 12)
    Gui.keyUp("S")
end
GPSController.clear()

local shots = Gui.report().shots
record("ui_hud.captures", #shots > 0, #shots)
reportEvent:FireServer({ vehicle = "ui_hud", steps = steps, measures = { captures = #shots } })
