-- Essais CLIENT du lot UI-01 (session « ui_design ») : page de démonstration du système de conception V1.2.
-- Vrais clics dans la VM (GuiDriver) ; focus manette posé par script (instrumenté : aucune manette dans la VM).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local started = os.clock()
while ReplicatedStorage:GetAttribute("AWTestSession") == nil and os.clock() - started < 15 do
    task.wait()
end
if ReplicatedStorage:GetAttribute("AWTestSession") ~= "ui_design" then
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

record("ui_design.client.entrees_reelles", (Gui.calibrate(3)))

local demo = playerGui:WaitForChild("AWDesignDemo", 30) :: ScreenGui?
record("ui_design.client.page_de_demonstration", demo ~= nil)
if demo == nil then
    reportEvent:FireServer({ vehicle = "ui_design", steps = steps, measures = {} })
    return
end
task.wait(2.5) -- polices chargées, mise en page

local function find(name: string): Instance?
    return (demo :: ScreenGui):FindFirstChild(name, true)
end

-- 1. Polices : familles demandées et texte effectivement mis en page (largeur non nulle).
local fontRows, fontsOk = {}, true
for _, spec in
    {
        { "Display", "TitilliumWeb" },
        { "H1", "TitilliumWeb" },
        { "Corps", "TitilliumWeb" },
        { "Vitesse", "RobotoMono" },
    }
do
    local label = find(spec[1]) :: TextLabel?
    local family = if label then tostring(label.FontFace.Family) else "absent"
    local ok = label ~= nil and string.find(family, spec[2], 1, true) ~= nil and label.TextBounds.X > 0
    fontsOk = fontsOk and ok
    table.insert(
        fontRows,
        string.format(
            "%s %s %s %.0f px",
            spec[1],
            family,
            if label then label.FontFace.Weight.Name else "?",
            if label then label.TextBounds.X else 0
        )
    )
end
record("ui_design.client.polices_titillium_et_roboto_mono", fontsOk, table.concat(fontRows, " / "))

-- 2. Échelle de l'écran (maquette §3) comparée à la règle des jetons.
local camera = Workspace.CurrentCamera :: Camera
local expected = Tokens.layout(camera.ViewportSize.X, camera.ViewportSize.Y)
record(
    "ui_design.client.echelle_ecran",
    math.abs(((demo :: ScreenGui):GetAttribute("AWScale") or 0) - expected.Scale) < 0.001
        and (demo :: ScreenGui):GetAttribute("AWCompact") == expected.Compact,
    string.format(
        "vue %.0f×%.0f : échelle %s, compacte %s",
        camera.ViewportSize.X,
        camera.ViewportSize.Y,
        tostring((demo :: ScreenGui):GetAttribute("AWScale")),
        tostring((demo :: ScreenGui):GetAttribute("AWCompact"))
    )
)
Gui.shot("ui_design_page_complete", { lot = "UI-01" })

-- 3. Bouton principal : vrai clic reçu ; bouton désactivé : aucun effet, raison affichée.
local primary = find("BoutonPrincipal") :: TextButton?
local okPrimary, detailPrimary = Gui.click(primary, "Appliquer les réglages")
record(
    "ui_design.client.bouton_principal_vrai_clic",
    okPrimary and (demo :: ScreenGui):GetAttribute("AWPrimaryClicks") == 1,
    detailPrimary
)
local disabled = find("BoutonDesactive") :: TextButton?
Gui.click(disabled, "Sortir (désactivé)", 2)
task.wait(0.5)
local reasonShown = false
if disabled and disabled.Parent then
    for _, child in disabled.Parent:GetChildren() do
        if child:IsA("TextLabel") and string.find(child.Text, "arrêt", 1, true) then
            reasonShown = true
        end
    end
end
record(
    "ui_design.client.bouton_desactive_sans_effet_raison_affichee",
    (demo :: ScreenGui):GetAttribute("AWDisabledClicks") == nil
        and disabled ~= nil
        and not disabled.Active
        and reasonShown,
    string.format(
        "clics reçus %s ; raison affichée %s",
        tostring((demo :: ScreenGui):GetAttribute("AWDisabledClicks") or 0),
        tostring(reasonShown)
    )
)

-- 4. Ligne de réglage : « + » borné à la plage fournie, « - » d'un pas, valeur modifiée en ambre.
local row = find("LigneReglage") :: Frame?
local plus = row and row:FindFirstChild("Plus", true) :: TextButton?
local minus = row and row:FindFirstChild("Moins", true) :: TextButton?
Gui.click(plus, "Réglage +")
local atMax = row and row:GetAttribute("AWValue")
Gui.click(minus, "Réglage -")
local afterMinus = row and row:GetAttribute("AWValue")
record(
    "ui_design.client.reglage_borne_et_pas",
    atMax ~= nil and math.abs(atMax - 1.08) < 1e-6 and afterMinus ~= nil and math.abs(afterMinus - 1.07) < 1e-6,
    string.format("après + : %s ; après - : %s (plage 0,92 à 1,08, pas 0,01)", tostring(atMax), tostring(afterMinus))
)

-- 5. Confirmation protégée : armée après 0,25 s ; vrai clic sur « Confirmer » accepté.
-- Fenêtre modale centrée ouverte à la demande : la garde part de son affichage réel.
local demoGui = demo :: ScreenGui
demoGui:SetAttribute("AWShowConfirm", true)
local confirm: Frame? = nil
waitFor(function()
    confirm = find("ConfirmationProtegee") :: Frame?
    return confirm ~= nil
end, 5)
local blockedAtFirst = confirm ~= nil and confirm:GetAttribute("AWConfirmArmed") ~= true
Gui.shot("ui_design_confirmation_protegee", { lot = "UI-01" })
local armed = waitFor(function()
    return confirm ~= nil and confirm:GetAttribute("AWConfirmArmed") == true
end, 3)
local okButton = confirm and Gui.findButton(confirm, "Confirmer")
local okConfirm = Gui.click(okButton, "Confirmer")
record(
    "ui_design.client.confirmation_protegee",
    blockedAtFirst and armed and okConfirm and (demo :: ScreenGui):GetAttribute("AWConfirmations") == 1,
    string.format(
        "inactive à l'affichage %s ; armée ensuite %s ; clic %s ; confirmations %s",
        tostring(blockedAtFirst),
        tostring(armed),
        tostring(okConfirm),
        tostring((demo :: ScreenGui):GetAttribute("AWConfirmations") or 0)
    )
)

-- 6. Focus manette (instrumenté : sélection posée par script) : contour ambre de 2 px.
GuiService.SelectedObject = primary
task.wait(0.4)
local stroke = primary and primary:FindFirstChildOfClass("UIStroke")
local amber = Tokens.Colors.Amber
record(
    "ui_design.client.focus_contour_ambre_2px",
    stroke ~= nil and stroke.Thickness == Tokens.FocusStroke and (stroke.Color.R - amber.R) ^ 2 < 1e-4,
    if stroke then string.format("épaisseur %s", tostring(stroke.Thickness)) else "contour absent"
)
Gui.shot("ui_design_focus_manette", { lot = "UI-01" })
GuiService.SelectedObject = nil

-- 7. États de sauvegarde : six badges, « Confirmé » en vert, refus et hors ligne en rouge.
local seen = {}
for _, item in (demo :: ScreenGui):GetDescendants() do
    local state = item:GetAttribute("AWState")
    if state then
        seen[state] = true
    end
end
local missing = {}
for _, state in Tokens.SaveStates do
    if not seen[state] then
        table.insert(missing, state)
    end
end
record("ui_design.client.six_etats_de_sauvegarde", #missing == 0, "absents : " .. table.concat(missing, ","))

-- 8. Mise en page : cartes et cellules de taille normale (pas d'étirement), filets à la taille du contenu,
-- ordre d'affichage par parent (fenêtre au-dessus du voile), fenêtre entière dans la vue.
local layoutRows, layoutOk = {}, true
for _, item in demoGui:GetDescendants() do
    if item:IsA("Frame") and item:GetAttribute("AWStatus") then
        local rail = item:FindFirstChild("Filet") :: Frame?
        local h = item.AbsoluteSize.Y
        local ok = h >= 36 and h <= 160 and rail ~= nil and math.abs(rail.AbsoluteSize.Y - h) <= 1
        layoutOk = layoutOk and ok
        table.insert(
            layoutRows,
            string.format(
                "carte %s %.0f px (filet %.0f)",
                tostring(item:GetAttribute("AWStatus")),
                h,
                if rail then rail.AbsoluteSize.Y else -1
            )
        )
    end
end
local view = (Workspace.CurrentCamera :: Camera).ViewportSize
local panel = find("ConfirmationProtegee") :: Frame?
local inside = panel ~= nil
    and panel.AbsolutePosition.X >= 0
    and panel.AbsolutePosition.Y >= 0
    and panel.AbsolutePosition.X + panel.AbsoluteSize.X <= view.X
    and panel.AbsolutePosition.Y + panel.AbsoluteSize.Y <= view.Y
layoutOk = layoutOk and inside and demoGui.ZIndexBehavior == Enum.ZIndexBehavior.Sibling
table.insert(
    layoutRows,
    string.format("fenêtre dans la vue %s ; ordre %s", tostring(inside), demoGui.ZIndexBehavior.Name)
)
record("ui_design.client.mise_en_page_sans_etirement", layoutOk, table.concat(layoutRows, " / "))

local shots = Gui.report().shots
record("ui_design.client.captures", #shots > 0, #shots)
reportEvent:FireServer({ vehicle = "ui_design", steps = steps, measures = { captures = #shots } })
