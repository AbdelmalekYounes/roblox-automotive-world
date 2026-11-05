-- Essais CLIENT de l'aperçu 3D du garage (lot UI-03, session « ui_garage3d ») : le ViewportFrame SEUL (consigne du
-- propriétaire : tester uniquement le nouveau). Vraies touches et vrais clics dans la VM (GuiDriver).
-- Non couvert ici : glisser à la souris (le pont d'entrées de la VM n'envoie pas de glisser), stick de manette.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local started = os.clock()
while ReplicatedStorage:GetAttribute("AWTestSession") == nil and os.clock() - started < 15 do
    task.wait()
end
if ReplicatedStorage:GetAttribute("AWTestSession") ~= "ui_garage3d" then
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
local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehicleDefinitions = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleDefinitions")) :: any
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
local ui = player:WaitForChild("PlayerScripts"):WaitForChild("AutomotiveWorldClient"):WaitForChild("UI")
local UIState = require(ui:WaitForChild("UIState")) :: any
local VehiclePreview = require(ui:WaitForChild("VehiclePreview")) :: any

record("ui_garage3d.client.entrees_reelles", (Gui.calibrate(3)))
record("ui_garage3d.client.clavier_etalonne", (Gui.calibrateKeys(3)))
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

local gui = playerGui:WaitForChild("AWProgression", 20) :: ScreenGui
local panel = gui:WaitForChild("Garage", 10) :: Frame
local viewport = panel:FindFirstChild("Apercu3D", true) :: ViewportFrame?
record("ui_garage3d.viewportframe_present", viewport ~= nil and viewport:IsA("ViewportFrame"))

-- 1. Ouverture (vraie touche P) : premier véhicule de la collection affiché dans la zone 3D.
Gui.key("P")
record(
    "ui_garage3d.ouverture_touche_P",
    waitFor(function()
        return panel.Visible
    end, 5)
)
local function previewOf(modelId: string?, timeout: number): boolean
    return waitFor(function()
        return viewport ~= nil
            and (modelId == nil or viewport:GetAttribute("AWPreviewModel") == modelId)
            and viewport:GetAttribute("AWPreviewModel") ~= nil
            and (viewport:GetAttribute("AWPreviewParts") or 0) > 0
    end, timeout)
end
local firstOk = previewOf(nil, 15)
local firstId = if viewport then viewport:GetAttribute("AWPreviewModel") else nil
record(
    "ui_garage3d.premier_vehicule_affiche",
    firstOk,
    string.format(
        "modèle %s, %s pièces",
        tostring(firstId),
        tostring(viewport and viewport:GetAttribute("AWPreviewParts"))
    )
)
-- Véhicule cadré : la sphère englobante du modèle reste dans le champ de la caméra (centre visé, distance > rayon).
local framed = false
if viewport and viewport.CurrentCamera then
    local model = viewport:FindFirstChildOfClass("Model")
    if model then
        local box, size = model:GetBoundingBox()
        local cam = viewport.CurrentCamera :: Camera
        local toCenter = box.Position - cam.CFrame.Position
        framed = toCenter.Magnitude > size.Magnitude / 2 and cam.CFrame.LookVector:Dot(toCenter.Unit) > 0.999
    end
end
record("ui_garage3d.cadrage", framed)
task.wait(1)
Gui.shot("ui_garage3d_premier", { lot = "UI-03" })

-- 2. Copie inerte côté serveur : pas un véhicule pour le jeu (aucune étiquette), pièces ancrées et sans collision.
local folder = ReplicatedStorage:FindFirstChild("AWVehiclePreview")
local source = folder and folder:FindFirstChild("Modeles") and folder.Modeles:FindFirstChild(tostring(firstId))
local inert = source ~= nil and not CollectionService:HasTag(source, "AWVehicle")
local loose = 0
if source then
    for _, item in source:GetDescendants() do
        if item:IsA("BasePart") and (not item.Anchored or item.CanCollide or item.CanQuery) then
            loose += 1
        end
        if item:IsA("ProximityPrompt") or item:IsA("JointInstance") or item:IsA("VectorForce") then
            loose += 1
        end
    end
end
local strays = 0
for _, tagged in CollectionService:GetTagged("AWVehicle") do
    if tagged:GetAttribute("AWPreviewOf") ~= nil then
        strays += 1
    end
end
record(
    "ui_garage3d.copie_inerte",
    inert and loose == 0 and strays == 0,
    string.format(
        "copie %s, %d élément(s) actif(s), %d copie(s) étiquetée(s)",
        tostring(source ~= nil),
        loose,
        strays
    )
)

-- 3. Rotation automatique.
local a0 = VehiclePreview.angle()
task.wait(1.5)
local a1 = VehiclePreview.angle()
record("ui_garage3d.rotation_auto", math.abs(a1 - a0) > 5, string.format("%.1f° → %.1f°", a0, a1))

-- 4. Choix d'un autre véhicule par vrai clic dans la collection : la zone 3D suit.
local secondId: string? = nil
local secondButton: GuiButton? = nil
for _, modelId in { "proto_p02", "proto_p03", "proto_p01" } do
    local definition = VehicleDefinitions.get(modelId)
    if modelId ~= firstId and definition then
        -- Collection en cartes (UI-03) : le nom est imbriqué dans la carte (Infos > Nom).
        for _, item in panel:GetDescendants() do
            if item:IsA("TextButton") and string.sub(item.Name, 1, 6) == "Carte_" then
                local label = item:FindFirstChild("Nom", true) :: TextLabel?
                if label and label.Text == definition.DisplayName then
                    secondButton = item
                end
            end
        end
        if secondButton then
            secondId = modelId
            break
        end
    end
end
local okClick = Gui.click(secondButton, tostring(secondId))
local followed = secondId ~= nil and previewOf(secondId, 15)
record(
    "ui_garage3d.selection_suivie",
    okClick and followed,
    string.format(
        "clic sur %s → aperçu %s",
        tostring(secondId),
        tostring(viewport and viewport:GetAttribute("AWPreviewModel"))
    )
)
task.wait(1)
Gui.shot("ui_garage3d_selection", { lot = "UI-03" })

-- 5. Comète (kit de maillages 3D) : affichée par le module de l'aperçu (la collection du profil d'essai ne la contient
-- pas) ; maillages présents dans la copie.
VehiclePreview.show("wk_comete", nil)
local cometeOk = previewOf("wk_comete", 20)
local meshes = 0
local model = viewport and viewport:FindFirstChildOfClass("Model")
if model then
    for _, item in model:GetDescendants() do
        if item:IsA("MeshPart") then
            meshes += 1
        end
    end
end
record(
    "ui_garage3d.comete_maillages",
    cometeOk and meshes > 0,
    string.format("%d MeshPart, %s pièces", meshes, tostring(viewport and viewport:GetAttribute("AWPreviewParts")))
)
task.wait(4) -- chargement des maillages et textures avant la capture
Gui.shot("ui_garage3d_comete", { lot = "UI-03" })

-- 6. Demandes refusées par le serveur : modèle inconnu, identifiant mal formé.
local request = folder and folder:FindFirstChild("Request") :: RemoteFunction?
local refused = 0
for _, bad in { "modele_inexistant", "../x" } do
    task.wait(0.3)
    local ok, result = pcall(function()
        return (request :: RemoteFunction):InvokeServer(bad)
    end)
    if ok and result == nil then
        refused += 1
    end
end
record("ui_garage3d.demandes_refusees", request ~= nil and refused == 2, string.format("%d / 2 refusées", refused))

-- 7. Fermeture (vrai clic) : rotation arrêtée (aucun calcul par image garage fermé).
Gui.click(panel:FindFirstChild("Fermer", true) :: GuiButton?, "Fermer")
local closed = waitFor(function()
    return not panel.Visible
end, 3)
task.wait(0.3)
local b0 = VehiclePreview.angle()
task.wait(1)
record(
    "ui_garage3d.fermer_rotation_arretee",
    closed and VehiclePreview.angle() == b0,
    string.format("fermé %s, angle %.1f° → %.1f°", tostring(closed), b0, VehiclePreview.angle())
)

local shots = Gui.report().shots
record("ui_garage3d.captures", #shots > 0, #shots)
reportEvent:FireServer({ vehicle = "ui_garage3d", steps = steps, measures = { captures = #shots } })
