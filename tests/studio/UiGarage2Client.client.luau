-- Essais CLIENT du garage V1.2 recomposé (lot UI-03, session « ui_garage2 ») : six onglets, cartes de la collection,
-- fiche du véhicule, brouillon de préparation, configurations, confirmations, retour d'un niveau, réponses du serveur.
-- Le serveur d'essai place le joueur dans le garage public d'essai (préparation et configurations permises).
-- Vraies touches et vrais clics dans la VM (GuiDriver). Seul le nouveau garage est testé (consigne du propriétaire).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local started = os.clock()
while ReplicatedStorage:GetAttribute("AWTestSession") == nil and os.clock() - started < 15 do
    task.wait()
end
if ReplicatedStorage:GetAttribute("AWTestSession") ~= "ui_garage2" then
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

record("ui_garage2.client.entrees_reelles", (Gui.calibrate(3)))
record("ui_garage2.client.clavier_etalonne", (Gui.calibrateKeys(3)))
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
waitFor(function()
    return ReplicatedStorage:GetAttribute("AWTestAtGarage") == true
end, 20)
task.wait(1.5)

local gui = playerGui:WaitForChild("AWProgression", 20) :: ScreenGui
local panel = gui:WaitForChild("Garage", 10) :: Frame
local function attr(name: string): any
    return panel:GetAttribute(name)
end
local view = (Workspace.CurrentCamera :: Camera).ViewportSize
record(
    "ui_garage2.resolution",
    true,
    string.format("vue %.0f × %.0f, compacte %s", view.X, view.Y, tostring(view.X < 1400))
)

-- 1. Ouverture (P), lieu « Garage public », collection en cartes.
Gui.key("P")
record(
    "ui_garage2.ouverture_touche_P",
    waitFor(function()
        return panel.Visible and attr("AWTab") == "Collection"
    end, 6)
)
local place = panel:FindFirstChild("Lieu", true) :: TextLabel?
record(
    "ui_garage2.lieu_garage_public",
    waitFor(function()
        return place ~= nil and place.Text == "Garage public"
    end, 6),
    if place then place.Text else "absent"
)
local collection = panel:FindFirstChild("Collection", true) :: ScrollingFrame
local grid = collection:WaitForChild("Grille", 10) :: Frame?
local cards = {}
if grid then
    for _, item in grid:GetChildren() do
        if item:IsA("TextButton") and string.sub(item.Name, 1, 6) == "Carte_" then
            table.insert(cards, item)
        end
    end
end
local thumbs = waitFor(function()
    local count = 0
    for _, item in cards do
        local thumb = item:FindFirstChild("Vignette3D", true)
        if thumb and thumb:GetAttribute("AWThumbModel") ~= nil then
            count += 1
        end
    end
    return #cards > 0 and count == #cards
end, 25)
local inside = true
for _, item in cards do
    if
        item.AbsolutePosition.X + item.AbsoluteSize.X
        > collection.AbsolutePosition.X + collection.AbsoluteSize.X + 1
    then
        inside = false
    end
end
record(
    "ui_garage2.collection_cartes",
    #cards >= 3 and thumbs and inside,
    string.format(
        "%d cartes, vignettes 3D %s, colonnes %s, dans la largeur %s",
        #cards,
        tostring(thumbs),
        tostring(grid and grid:GetAttribute("AWColumns")),
        tostring(inside)
    )
)
-- Boutons du véhicule de départ : aucun ne déborde (défaut constaté en disposition compacte, VM 20261105-114328).
local overflow, starters = 0, 0
for _, item in collection:GetDescendants() do
    if item:IsA("TextButton") and string.sub(item.Name, 1, 7) == "Depart_" then
        starters += 1
        if
            item.AbsolutePosition.X + item.AbsoluteSize.X
            > collection.AbsolutePosition.X + collection.AbsoluteSize.X
        then
            overflow += 1
        end
    end
end
record(
    "ui_garage2.depart_sans_debordement",
    overflow == 0,
    string.format("%d bouton(s) de départ, %d débordant", starters, overflow)
)
task.wait(1)
Gui.shot("ui_garage2_collection", { lot = "UI-03" })

-- 2. Carte P-02 (vrai clic) : onglet Véhicule, zone 3D, fiche technique, barre d'actions.
-- Le nom est imbriqué dans la carte (Infos > Nom) : findButton ne lit que les libellés enfants directs.
local cardP02: GuiButton? = nil
for _, item in cards do
    local label = item:FindFirstChild("Nom", true) :: TextLabel?
    if label and label.Text == "Prototype d'essai P-02" then
        cardP02 = item
    end
end
local okCard = Gui.click(cardP02, "carte P-02")
local onVehicle = waitFor(function()
    return attr("AWTab") == "Véhicule"
end, 5)
local name = panel:FindFirstChild("NomVehicule", true) :: TextLabel?
local sheet = panel:FindFirstChild("FicheTechnique", true)
local rows = 0
if sheet then
    for _, item in sheet:GetChildren() do
        if item.Name == "Fiche" then
            rows += 1
        end
    end
end
local bar = panel:FindFirstChild("Actions", true) :: Frame?
local barButtons = 0
if bar then
    for _, item in bar:GetChildren() do
        if item:IsA("TextButton") then
            barButtons += 1
        end
    end
end
record(
    "ui_garage2.fiche_vehicule",
    okCard and onVehicle and name ~= nil and name.Text == "Prototype d'essai P-02" and rows >= 7 and barButtons == 4,
    string.format("nom %s, %d lignes de fiche, %d actions", tostring(name and name.Text), rows, barButtons)
)
task.wait(1.5)
Gui.shot("ui_garage2_vehicule", { lot = "UI-03" })

-- 3. Vue « Profil » puis « Réinitialiser » (vrais clics) : libellé de la caméra.
local camLabel = panel:FindFirstChild("Libelle", true) :: TextLabel?
Gui.click(Gui.findButton(panel, "Profil"), "Profil")
task.wait(0.5)
local profil = camLabel and string.find(camLabel.Text, "90°", 1, true) ~= nil
Gui.click(Gui.findButton(panel, "Réinitialiser"), "Réinitialiser")
task.wait(0.5)
record("ui_garage2.vues_camera", profil == true, if camLabel then camLabel.Text else "libellé absent")

-- 4. Préparer (vrai clic) : réglage + (vrai clic), brouillon signalé, valeur en ambre.
Gui.click(Gui.findButton(bar, "Préparer"), "Préparer")
local onPrep = waitFor(function()
    return attr("AWTab") == "Préparation" and attr("AWPrepSub") == "Réglages"
end, 5)
task.wait(0.6)
local firstRow: Instance? = nil
local body = panel:FindFirstChild("Corps", true) :: ScrollingFrame
local bestOrder = math.huge
for _, item in body:GetChildren() do
    if string.sub(item.Name, 1, 8) == "Reglage_" and (item :: any).LayoutOrder < bestOrder then
        firstRow, bestOrder = item, (item :: any).LayoutOrder
    end
end
local plus = firstRow and firstRow:FindFirstChild("Plus") :: GuiButton?
local before = firstRow and firstRow:GetAttribute("AWValue")
local okPlus = Gui.click(plus, "Plus")
task.wait(0.5)
local after = firstRow and firstRow:GetAttribute("AWValue")
local badge = panel:FindFirstChild("Brouillon", true) :: TextLabel?
record(
    "ui_garage2.brouillon_reglage",
    onPrep and okPlus and after ~= before and attr("AWDraft") == true and badge ~= nil and badge.Visible,
    string.format(
        "%s : %s → %s, brouillon %s",
        tostring(firstRow and firstRow.Name),
        tostring(before),
        tostring(after),
        tostring(attr("AWDraft"))
    )
)
Gui.shot("ui_garage2_reglages", { lot = "UI-03" })

-- 5. Appliquer le brouillon (vrai clic) : état affiché seulement après la réponse réelle du serveur.
local apply = panel:FindFirstChild("AppliquerBrouillon", true) :: GuiButton?
Gui.click(apply, "Appliquer le brouillon")
local answered = waitFor(function()
    local kind = attr("AWStatusKind")
    return attr("AWBusy") ~= true and (kind == "Pending" or kind == "Confirmed" or kind == "Rejected")
end, 10)
local message = panel:FindFirstChild("Message", true) :: TextLabel?
local firstKind = attr("AWStatusKind")
local confirmed = waitFor(function()
    return attr("AWStatusKind") == "Confirmed"
end, 12)
record(
    "ui_garage2.reponse_serveur_reglages",
    answered and firstKind ~= "Offline",
    string.format(
        "réponse %s, puis confirmé %s, message « %s », brouillon %s",
        tostring(firstKind),
        tostring(confirmed),
        tostring(message and message.Text),
        tostring(attr("AWDraft"))
    )
)
Gui.shot("ui_garage2_etat_serveur", { lot = "UI-03" })

-- 6. Esthétique : teinte bleue (vrai clic) appliquée en direct à l'aperçu 3D, puis brouillon annulé.
Gui.click(Gui.findButton(panel, "Esthétique"), "Esthétique")
task.wait(0.6)
local swatch = panel:FindFirstChild("Teinte_BodyColor_Bleu", true) :: GuiButton?
Gui.click(swatch, "Bleu nuit")
task.wait(1.2)
local viewport = panel:FindFirstChild("Apercu3D", true) :: ViewportFrame?
local painted = 0
local model = viewport and viewport:FindFirstChildOfClass("Model")
if model then
    for _, item in model:GetDescendants() do
        if item:IsA("BasePart") and item:GetAttribute("AWPaintRole") == "Body" then
            local c = item.Color
            if math.abs(c.R * 255 - 28) < 2 and math.abs(c.G * 255 - 58) < 2 and math.abs(c.B * 255 - 120) < 2 then
                painted += 1
            end
        end
    end
end
record(
    "ui_garage2.esthetique_apercu_direct",
    attr("AWDraft") == true and painted > 0,
    string.format(
        "%d pièce(s) de caisse en bleu nuit dans l'aperçu, brouillon %s",
        painted,
        tostring(attr("AWDraft"))
    )
)
Gui.shot("ui_garage2_esthetique", { lot = "UI-03" })
Gui.click(panel:FindFirstChild("AnnulerBrouillon", true) :: GuiButton?, "Annuler le brouillon")
task.wait(0.6)
record("ui_garage2.brouillon_annule", attr("AWDraft") == false, tostring(attr("AWDraft")))

-- 7. Onglet suivant au clavier (vraie touche PageDown) : Configurations.
-- Diagnostic : touches réellement reçues par le jeu pendant l'appui.
local received = {}
local listen = game:GetService("UserInputService").InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Keyboard then
        table.insert(received, input.KeyCode.Name)
    end
end)
Gui.key("PageDown")
local onConfigs = waitFor(function()
    return attr("AWTab") == "Configurations"
end, 3)
listen:Disconnect()
if onConfigs or table.find(received, "PageDown") then
    record("ui_garage2.onglet_suivant_pagedown", onConfigs, "reçu : " .. table.concat(received, ", "))
else
    -- Le pont d'entrées de la VM n'envoie pas l'indicateur « touche étendue » : PageDown arrive sous un autre code.
    table.insert(steps, {
        name = "ui_garage2.onglet_suivant_pagedown",
        ok = false,
        detail = "onglet " .. tostring(attr("AWTab")),
        known = "touche PageDown non reçue par le jeu (reçu : " .. (if #received > 0
            then table.concat(received, ", ")
            else "rien") .. ") ; à vérifier par un essai humain",
    })
end
if not onConfigs then
    Gui.click(Gui.findButton(panel:FindFirstChild("Onglets", true), "Configurations"), "Configurations")
    waitFor(function()
        return attr("AWTab") == "Configurations"
    end, 3)
end
task.wait(0.6)

-- 8. Enregistrer la configuration 1 (nom saisi au clavier), puis la supprimer avec confirmation.
local nameBox = panel:FindFirstChild("NomConfiguration", true) :: TextBox?
Gui.click(nameBox, "nom de configuration")
task.wait(0.3)
Gui.type("Essai VM")
task.wait(0.3)
Gui.key("Return")
task.wait(0.4)
local slot1 = panel:FindFirstChild("Configuration1", true)
Gui.click(slot1 and Gui.findButton(slot1, "Enregistrer ici"), "Enregistrer ici")
waitFor(function()
    return attr("AWBusy") ~= true and attr("AWStatusKind") ~= nil and attr("AWStatusKind") ~= "Info"
end, 10)
task.wait(1)
slot1 = panel:FindFirstChild("Configuration1", true)
local saved = false
if slot1 then
    for _, item in slot1:GetDescendants() do
        if item:IsA("TextLabel") and string.find(item.Text, "Essai VM", 1, true) then
            saved = true
        end
    end
end
record(
    "ui_garage2.configuration_enregistree",
    saved,
    string.format("état %s, nom saisi %s", tostring(attr("AWStatusKind")), tostring(nameBox and nameBox.Text))
)
Gui.shot("ui_garage2_configurations", { lot = "UI-03" })
Gui.click(slot1 and Gui.findButton(slot1, "Supprimer"), "Supprimer")
local veil = gui:WaitForChild("VoileConfirmation", 4)
local armed = veil
    and waitFor(function()
        local box = veil:FindFirstChild("ConfirmationProtegee", true)
        return box ~= nil and box:GetAttribute("AWConfirmArmed") == true
    end, 3)
Gui.shot("ui_garage2_confirmation", { lot = "UI-03" })
record("ui_garage2.confirmation_suppression", veil ~= nil and armed == true)
if veil then
    Gui.click(Gui.findButton(veil, "Confirmer"), "Confirmer")
end
waitFor(function()
    return gui:FindFirstChild("VoileConfirmation") == nil and attr("AWBusy") ~= true
end, 8)
task.wait(1.5)
slot1 = panel:FindFirstChild("Configuration1", true)
local emptied = false
if slot1 then
    for _, item in slot1:GetDescendants() do
        if item:IsA("TextLabel") and string.find(item.Text, "(vide)", 1, true) then
            emptied = true
        end
    end
end
record("ui_garage2.configuration_supprimee", emptied, tostring(attr("AWStatusKind")))

-- 9. Retour d'un niveau (vraie touche Retour arrière) : Configurations → Véhicule → Collection → fermé.
local trail = {}
for _ = 1, 3 do
    Gui.key("Backspace")
    task.wait(0.7)
    table.insert(trail, if panel.Visible then tostring(attr("AWTab")) else "fermé")
end
record(
    "ui_garage2.retour_un_niveau",
    trail[1] == "Véhicule" and trail[2] == "Collection" and trail[3] == "fermé",
    table.concat(trail, " → ")
)

local shots = Gui.report().shots
record("ui_garage2.captures", #shots > 0, #shots)
reportEvent:FireServer({ vehicle = "ui_garage2", steps = steps, measures = { captures = #shots } })
