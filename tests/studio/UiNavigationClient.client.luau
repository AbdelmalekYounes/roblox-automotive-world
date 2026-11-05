-- Essais CLIENT de navigation et de sécurité de l'interface V1.2 (session « ui_navigation ») : focus manette
-- (tout bouton actif est sélectionnable, tout bouton inactif ne l'est pas), anti double envoi (double clic réel),
-- états du serveur RÉELS : en attente / confirmé (garage), refusé (inscription de course hors point d'inscription),
-- hors ligne (canal de l'économie retiré côté client). Le serveur d'essai place le joueur au garage public.
-- Non couvert : manette physique (le pont d'entrées de la VM n'envoie ni stick ni bouton de manette).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local started = os.clock()
while ReplicatedStorage:GetAttribute("AWTestSession") == nil and os.clock() - started < 15 do
    task.wait()
end
if ReplicatedStorage:GetAttribute("AWTestSession") ~= "ui_navigation" then
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

record("ui_navigation.client.entrees_reelles", (Gui.calibrate(3)))
record("ui_navigation.client.clavier_etalonne", (Gui.calibrateKeys(3)))
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
waitFor(function()
    return ReplicatedStorage:GetAttribute("AWTestAtGarage") == true
end, 20)
task.wait(1.5)

-- Focus manette : boutons actifs affichés sélectionnables ; boutons inactifs non sélectionnables.
local function focusAudit(root: Instance): (number, number, number)
    local active, unreachable, wrongDisabled = 0, 0, 0
    for _, item in root:GetDescendants() do
        if item:IsA("GuiButton") and Gui.shown(item) then
            if item:GetAttribute("AWDisabled") then
                if item.Selectable then
                    wrongDisabled += 1
                end
            elseif item.Active and not item:GetAttribute("AWPointerOnly") then
                active += 1
                if not item.Selectable then
                    unreachable += 1
                end
            end
        end
    end
    return active, unreachable, wrongDisabled
end

local garageGui = playerGui:WaitForChild("AWProgression", 20)
local garage = garageGui:WaitForChild("Garage", 10) :: Frame
Gui.key("P")
waitFor(function()
    return garage.Visible
end, 5)
task.wait(1.5)
for _, tab in { "Collection", "Véhicule", "Préparation", "Configurations", "Propriétés", "Invitations" } do
    local tabsBar = garage:FindFirstChild("Onglets", true)
    Gui.click(tabsBar and Gui.findButton(tabsBar, tab), tab)
    task.wait(1)
    local active, unreachable, wrong = focusAudit(garage)
    record(
        "ui_navigation.focus_garage_" .. tab,
        unreachable == 0 and wrong == 0 and active > 0,
        string.format(
            "%d bouton(s) actif(s), %d non sélectionnable(s), %d inactif(s) sélectionnable(s)",
            active,
            unreachable,
            wrong
        )
    )
end

-- Anti double envoi : double clic réel sur « Enregistrer ici » (configuration 1) → une seule demande envoyée.
do
    local tabsBar = garage:FindFirstChild("Onglets", true)
    Gui.click(tabsBar and Gui.findButton(tabsBar, "Configurations"), "Configurations")
    task.wait(1)
end
local body = garage:FindFirstChild("Corps", true)
local slot1 = body and body:FindFirstChild("Configuration1", true)
local save = slot1 and Gui.findButton(slot1, "Enregistrer ici")
local before = garage:GetAttribute("AWSent") or 0
if save then
    Gui.click(save, "Enregistrer ici (1)")
    Gui.click(save, "Enregistrer ici (2)")
end
waitFor(function()
    return garage:GetAttribute("AWBusy") ~= true
end, 10)
task.wait(1.5)
local sent = (garage:GetAttribute("AWSent") or 0) - before
local saved = false
slot1 = body and body:FindFirstChild("Configuration1", true)
if slot1 then
    for _, item in slot1:GetDescendants() do
        if item:IsA("TextLabel") and string.find(item.Text, "Configuration 1", 1, true) then
            saved = true
        end
    end
end
record(
    "ui_navigation.double_clic_une_demande",
    save ~= nil and sent >= 1 and sent <= 2 and saved,
    string.format(
        "demandes envoyées : %d (le second clic est arrivé %s la réponse) ; état %s",
        sent,
        if sent == 1 then "pendant" else "après",
        tostring(garage:GetAttribute("AWStatusKind"))
    )
)
-- Une seule configuration créée malgré deux clics : l'emplacement 2 reste vide si une seule demande est passée.
local slot2 = body and body:FindFirstChild("Configuration2", true)
local second = false
if slot2 then
    for _, item in slot2:GetDescendants() do
        if item:IsA("TextLabel") and string.find(item.Text, "Configuration 2", 1, true) then
            second = true
        end
    end
end
record("ui_navigation.pas_de_doublon", not second, if second then "configuration 2 créée" else "emplacement 2 vide")
-- Nettoyage : suppression avec confirmation protégée.
if slot1 then
    Gui.click(Gui.findButton(slot1, "Supprimer"), "Supprimer")
    local veil = garageGui:WaitForChild("VoileConfirmation", 4)
    if veil then
        waitFor(function()
            local box = veil:FindFirstChild("ConfirmationProtegee", true)
            return box ~= nil and box:GetAttribute("AWConfirmArmed") == true
        end, 3)
        Gui.click(Gui.findButton(veil, "Confirmer"), "Confirmer")
        task.wait(1.5)
    end
end
Gui.click(garage:FindFirstChild("Fermer", true) :: GuiButton?, "Fermer")
task.wait(0.8)

-- État REFUSÉ réel : inscription à une épreuve officielle loin du point d'inscription (refus du serveur).
Gui.key("K")
local raceGui = playerGui:WaitForChild("AWRacing", 10)
local races = raceGui:WaitForChild("Courses", 10) :: Frame
waitFor(function()
    return races.Visible
end, 5)
task.wait(1)
local active, unreachable, wrong = focusAudit(races)
record(
    "ui_navigation.focus_courses",
    unreachable == 0 and wrong == 0 and active > 0,
    string.format(
        "%d actif(s), %d non sélectionnable(s), %d inactif(s) sélectionnable(s)",
        active,
        unreachable,
        wrong
    )
)
local details = Gui.findButton(races, "Détails")
Gui.click(details, "Détails")
task.wait(1)
local official = Gui.findButton(races, "Officielle")
Gui.click(official, "Officielle")
local refused = waitFor(function()
    return races:GetAttribute("AWStatusKind") == "Rejected" or races:GetAttribute("AWStatusKind") == "Info"
end, 8)
local message = races:FindFirstChild("Message", true) :: TextLabel?
record(
    "ui_navigation.etat_refuse_reel",
    refused and races:GetAttribute("AWStatusKind") == "Rejected",
    string.format(
        "état %s, « %s »",
        tostring(races:GetAttribute("AWStatusKind")),
        tostring(message and message.Text)
    )
)
Gui.shot("ui_navigation_refuse", { lot = "UI V1.2" })
-- Si l'inscription a réussi malgré tout, désinscription (aucune épreuve laissée ouverte).
if races:GetAttribute("AWStatusKind") ~= "Rejected" then
    local tabsBar = races:FindFirstChild("Onglets", true)
    Gui.click(tabsBar and Gui.findButton(tabsBar, "Mon épreuve"), "Mon épreuve")
    task.wait(1)
    Gui.click(Gui.findButton(races, "Se désinscrire"), "Se désinscrire")
    task.wait(1)
end
Gui.click(races:FindFirstChild("Fermer", true) :: GuiButton?, "Fermer")
task.wait(0.8)

-- État HORS LIGNE réel côté client : canal de l'économie retiré (copie locale détruite), puis réouverture (J) :
-- la lecture échoue, l'écran l'affiche « hors ligne » et rien n'est confirmé.
local economyGui = playerGui:WaitForChild("AWEconomy", 10)
local economy = economyGui:WaitForChild("Economie", 10) :: Frame
Gui.key("J")
waitFor(function()
    return economy.Visible
end, 5)
task.wait(1)
active, unreachable, wrong = focusAudit(economy)
record(
    "ui_navigation.focus_economie",
    unreachable == 0 and wrong == 0 and active > 0,
    string.format(
        "%d actif(s), %d non sélectionnable(s), %d inactif(s) sélectionnable(s)",
        active,
        unreachable,
        wrong
    )
)
Gui.click(economy:FindFirstChild("Fermer", true) :: GuiButton?, "Fermer")
task.wait(0.8)
local folder = ReplicatedStorage:FindFirstChild("AWEconomy")
local remote = folder and folder:FindFirstChild("Request")
if remote then
    remote:Destroy()
end
Gui.key("J")
waitFor(function()
    return economy.Visible
end, 5)
-- Délai d'expiration de 12 s (PanelKit.InvokeTimeoutS) : l'état « hors ligne » doit apparaître ensuite.
local offline = waitFor(function()
    return economy:GetAttribute("AWStatusKind") == "Offline"
end, 18)
message = economy:FindFirstChild("Message", true) :: TextLabel?
record(
    "ui_navigation.etat_hors_ligne_reel",
    offline,
    string.format(
        "état %s, « %s »",
        tostring(economy:GetAttribute("AWStatusKind")),
        tostring(message and message.Text)
    )
)
Gui.shot("ui_navigation_hors_ligne", { lot = "UI V1.2" })
Gui.click(economy:FindFirstChild("Fermer", true) :: GuiButton?, "Fermer")
task.wait(0.6)

-- Téléphone : focus des tuiles (manette) et retour par Retour arrière.
Gui.key("T")
local phoneGui = playerGui:WaitForChild("AWPhone", 10) :: ScreenGui
waitFor(function()
    return phoneGui.Enabled
end, 5)
task.wait(0.8)
active, unreachable, wrong = focusAudit(phoneGui)
record(
    "ui_navigation.focus_telephone",
    unreachable == 0 and wrong == 0 and active >= 12,
    string.format(
        "%d actif(s), %d non sélectionnable(s), %d inactif(s) sélectionnable(s)",
        active,
        unreachable,
        wrong
    )
)
Gui.key("Backspace")
record(
    "ui_navigation.telephone_retour_ferme",
    waitFor(function()
        return not phoneGui.Enabled
    end, 3)
)

local shots = Gui.report().shots
record("ui_navigation.captures", #shots > 0, #shots)
reportEvent:FireServer({ vehicle = "ui_navigation", steps = steps, measures = { captures = #shots } })
