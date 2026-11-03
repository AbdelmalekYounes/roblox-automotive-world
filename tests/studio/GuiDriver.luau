--!strict
-- Pilote d'interface du lot 0.9.1 (module de test, Studio de la VM uniquement).
--
-- Pourquoi : parcourir les écrans du jeu par de VRAIS clics et de VRAIES touches, et non
-- en appelant leurs fonctions ni leurs RemoteEvents. Le module imprime des commandes
-- « @@AWIN@@ <n> <op> <arguments> » ; l'outil aw-capture de la VM (tools/vm/ScreenCapture.cs)
-- les lit dans le journal de Studio et les exécute par SendInput, comme une souris et un
-- clavier physiques, dans la session Windows de la VM (jamais sur le poste principal).
--
-- Preuve d'efficacité : chaque clic sur un bouton attend son événement « Activated »
-- (déclenché par le moteur, seulement si le clic réel l'a atteint). Un clic non reçu
-- est rapporté comme tel ; aucune fonction de l'interface n'est appelée à sa place.
-- Coordonnées : pixels de la vue du jeu (AbsolutePosition, plus la bande supérieure
-- réservée quand le ScreenGui ne l'ignore pas). L'étalonnage les relie à l'écran.

local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Gui = {}

-- Codes virtuels Windows ; les lettres et chiffres valent leur code ASCII majuscule.
local VK: { [string]: number } = {
    Return = 0x0D,
    Escape = 0x1B,
    Space = 0x20,
    Tab = 0x09,
    Backspace = 0x08,
    Left = 0x25,
    Up = 0x26,
    Right = 0x27,
    Down = 0x28,
    Backslash = 0xDC,
    Shift = 0x10,
}

-- Codes de balayage (position physique, clavier américain) : utilisés si le moteur lit
-- la position de la touche et non le caractère (disposition AZERTY de la VM).
local SCAN: { [string]: number } = {
    Return = 0x1C,
    Escape = 0x01,
    Space = 0x39,
    Tab = 0x0F,
    Backspace = 0x0E,
    Left = 0x4B,
    Up = 0x48,
    Right = 0x4D,
    Down = 0x50,
    Backslash = 0x2B,
    Shift = 0x2A,
}
do
    local rows = { { "QWERTYUIOP", 0x10 }, { "ASDFGHJKL", 0x1E }, { "ZXCVBNM", 0x2C }, { "1234567890", 0x02 } }
    for _, row in rows do
        local letters, first = row[1] :: string, row[2] :: number
        for index = 1, #letters do
            SCAN[string.sub(letters, index, index)] = first + index - 1
        end
    end
end
-- « vk » (code virtuel, dépend de la disposition) ou « scan » ; choisi par calibrateKeys.
local keyMode = "vk"

local sequence = 0
local actions: { { [string]: any } } = {}
local calibrated = false
local latencies: { number } = {}

local function send(op: string, ...: any): number
    sequence += 1
    local parts = { ... }
    for index, value in parts do
        parts[index] = if type(value) == "number" then string.format("%.1f", value) else tostring(value)
    end
    print(string.format("@@AWIN@@ %d %s %s", sequence, op, table.concat(parts, " ")))
    return sequence
end

local function note(kind: string, data: { [string]: any })
    data.kind = kind
    data.t = math.floor(os.clock() * 100) / 100
    table.insert(actions, data)
end

local function vkOf(key: string): number
    local code = VK[key]
    if code then
        return code
    end
    assert(#key == 1, "touche inconnue : " .. key)
    return string.byte(string.upper(key))
end

local function playerGui(): PlayerGui
    return (Players.LocalPlayer :: Player):WaitForChild("PlayerGui") :: PlayerGui
end

function Gui.waitFor(predicate: () -> boolean, timeout: number): boolean
    local start = os.clock()
    while os.clock() - start < timeout do
        if predicate() then
            return true
        end
        task.wait(0.05)
    end
    return predicate()
end

local function frames(count: number)
    for _ = 1, count do
        RunService.RenderStepped:Wait()
    end
end

-- Point de la vue du jeu au centre d'un élément (bande supérieure comprise si besoin).
function Gui.center(item: GuiObject): Vector2
    local screen = item:FindFirstAncestorWhichIsA("ScreenGui")
    local offset = if screen and not screen.IgnoreGuiInset then GuiService:GetGuiInset() else Vector2.zero
    return item.AbsolutePosition + item.AbsoluteSize / 2 + offset
end

-- Premier ancêtre qui rogne l'élément (cadre défilant ou ClipsDescendants) et le cache
-- au point visé : le clic réel tomberait ailleurs. Renvoie cet ancêtre, ou nil.
function Gui.clippedBy(item: GuiObject): GuiObject?
    local point = item.AbsolutePosition + item.AbsoluteSize / 2
    local node = item.Parent
    while node and node:IsA("GuiObject") do
        if node:IsA("ScrollingFrame") or node.ClipsDescendants then
            local min = node.AbsolutePosition
            local max = min + node.AbsoluteSize
            if point.X < min.X or point.Y < min.Y or point.X > max.X or point.Y > max.Y then
                return node
            end
        end
        node = node.Parent
    end
    return nil
end

-- Élément réellement affiché : visible, ancêtres visibles, ScreenGui actif, dans la vue,
-- non rogné par un cadre défilant.
function Gui.shown(item: Instance?): boolean
    if item == nil or not item:IsA("GuiObject") or not item:IsDescendantOf(playerGui()) then
        return false
    end
    local node: Instance? = item
    while node and not node:IsA("LayerCollector") do
        if node:IsA("GuiObject") and not node.Visible then
            return false
        end
        node = node.Parent
    end
    if node == nil or not (node :: LayerCollector).Enabled then
        return false
    end
    local camera = Workspace.CurrentCamera
    local point = Gui.center(item :: GuiObject)
    local size = if camera then camera.ViewportSize else Vector2.new(1e6, 1e6)
    return point.X >= 0
        and point.Y >= 0
        and point.X <= size.X
        and point.Y <= size.Y
        and Gui.clippedBy(item :: GuiObject) == nil
end

-- Affiché, ancêtres compris, sans tenir compte du rognage (élément à faire défiler).
local function present(item: GuiObject): boolean
    local node: Instance? = item
    while node and not node:IsA("LayerCollector") do
        if node:IsA("GuiObject") and not node.Visible then
            return false
        end
        node = node.Parent
    end
    return node ~= nil and (node :: LayerCollector).Enabled
end
Gui.present = present

local function textOf(item: Instance): string
    if item:IsA("TextButton") or item:IsA("TextLabel") or item:IsA("TextBox") then
        return item.Text
    end
    return ""
end

-- Bouton affiché dont le texte (ou celui d'un libellé enfant) contient « pattern »
-- (recherche littérale, sans tenir compte de la casse).
function Gui.findButton(root: Instance?, pattern: string): GuiButton?
    local scope: Instance = root or playerGui()
    local wanted = string.lower(pattern)
    for _, item in scope:GetDescendants() do
        if item:IsA("GuiButton") and Gui.shown(item) then
            local text = string.lower(textOf(item))
            if not string.find(text, wanted, 1, true) then
                for _, child in item:GetChildren() do
                    if child:IsA("TextLabel") and string.find(string.lower(child.Text), wanted, 1, true) then
                        text = wanted
                    end
                end
            end
            if string.find(text, wanted, 1, true) then
                return item
            end
        end
    end
    return nil
end

function Gui.findText(root: Instance?, pattern: string): GuiObject?
    local scope: Instance = root or playerGui()
    local wanted = string.lower(pattern)
    for _, item in scope:GetDescendants() do
        if item:IsA("GuiObject") and Gui.shown(item) and string.find(string.lower(textOf(item)), wanted, 1, true) then
            return item
        end
    end
    return nil
end

-- Fait défiler par la VRAIE molette jusqu'à rendre l'élément visible (comme un joueur).
-- Renvoie (visible, crans utilisés).
function Gui.reveal(item: GuiObject?, maxNotches: number?): (boolean, number)
    if item == nil or not present(item) then
        return false, 0
    end
    local used = 0
    for _ = 1, maxNotches or 15 do
        local frame = Gui.clippedBy(item)
        if frame == nil then
            return true, used
        end
        local below = item.AbsolutePosition.Y > frame.AbsolutePosition.Y + frame.AbsoluteSize.Y / 2
        Gui.wheel(frame, if below then -1 else 1)
        used += 1
        task.wait(0.35)
    end
    return Gui.clippedBy(item) == nil, used
end

-- Étalonnage souris : deux carrés magenta, l'outil les repère sur l'écran, puis clique
-- le premier (un bouton) ; l'événement Activated prouve que le clic réel est arrivé.
-- Un second bouton, dans un ScreenGui qui respecte la bande supérieure, vérifie la
-- conversion des coordonnées des interfaces du jeu.
function Gui.calibrate(attempts: number?): (boolean, string)
    local camera = Workspace.CurrentCamera :: Camera
    local tries = attempts or 3
    for attempt = 1, tries do
        local size = camera.ViewportSize
        local holder = Instance.new("ScreenGui")
        holder.Name = "AW_TestCalibration"
        holder.IgnoreGuiInset = true
        holder.ResetOnSpawn = false
        holder.DisplayOrder = 100000
        local markerA = Instance.new("TextButton")
        markerA.Name = "RepereA"
        markerA.Text = ""
        markerA.AutoButtonColor = false
        markerA.BorderSizePixel = 0
        markerA.BackgroundColor3 = Color3.fromRGB(255, 0, 255)
        -- Repères à l'intérieur de la vue : les coins sont couverts par la barre de Roblox
        -- (au-dessus des interfaces du jeu) et par le filigrane de Windows dans la VM.
        local ax, ay = math.floor(size.X * 0.22), math.floor(size.Y * 0.3)
        local bx, by = math.floor(size.X * 0.78), math.floor(size.Y * 0.72)
        markerA.Position = UDim2.fromOffset(ax, ay)
        markerA.Size = UDim2.fromOffset(30, 30)
        markerA.Parent = holder
        local markerB = markerA:Clone()
        markerB.Name = "RepereB"
        markerB.Position = UDim2.fromOffset(bx - 30, by - 30)
        markerB.Parent = holder
        local insetHolder = Instance.new("ScreenGui")
        insetHolder.Name = "AW_TestCalibrationInset"
        insetHolder.IgnoreGuiInset = false
        insetHolder.ResetOnSpawn = false
        insetHolder.DisplayOrder = 100000
        local insetButton = Instance.new("TextButton")
        insetButton.Name = "ControleBande"
        insetButton.Text = "AW"
        insetButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        insetButton.Position = UDim2.new(0.5, -40, 0.45, 0)
        insetButton.Size = UDim2.fromOffset(80, 40)
        insetButton.Parent = insetHolder
        holder.Parent = playerGui()
        insetHolder.Parent = playerGui()

        local hitA, hitInset = false, false
        local connA = markerA.Activated:Connect(function()
            hitA = true
        end)
        local connInset = insetButton.Activated:Connect(function()
            hitInset = true
        end)
        frames(5)
        task.wait(0.4)
        send("calib", ax, ay, bx, by, size.X, size.Y)
        task.wait(1.2)
        local sentAt = os.clock()
        send("click", ax + 15, ay + 15)
        Gui.waitFor(function()
            return hitA
        end, 8)
        local latency = os.clock() - sentAt
        if hitA then
            local point = Gui.center(insetButton)
            send("click", point.X, point.Y)
            Gui.waitFor(function()
                return hitInset
            end, 8)
        end
        connA:Disconnect()
        connInset:Disconnect()
        holder:Destroy()
        insetHolder:Destroy()
        if hitA and hitInset then
            calibrated = true
            table.insert(latencies, latency)
            local detail = string.format(
                "tentative %d, vue %d × %d, délai clic → Activated %.2f s, bande supérieure %s",
                attempt,
                size.X,
                size.Y,
                latency,
                tostring(GuiService:GetGuiInset())
            )
            note("calib", { ok = true, detail = detail })
            return true, detail
        end
        note("calib", { ok = false, attempt = attempt, hitA = hitA, hitInset = hitInset })
        task.wait(1)
    end
    return false, "aucun clic réel reçu après " .. tries .. " étalonnage(s)"
end

function Gui.isCalibrated(): boolean
    return calibrated
end

-- Clic réel au centre d'un élément. Pour un bouton, attend son Activated (preuve).
-- Renvoie (reçu, détail).
function Gui.click(item: GuiObject?, label: string, timeout: number?): (boolean, string)
    if item == nil then
        note("click", { label = label, ok = false, why = "introuvable" })
        return false, "élément introuvable : " .. label
    end
    if not Gui.shown(item) then
        note("click", { label = label, ok = false, why = "non affiché" })
        return false, "élément non affiché : " .. label
    end
    local point = Gui.center(item)
    local received = false
    local connection: RBXScriptConnection? = nil
    if item:IsA("GuiButton") then
        connection = item.Activated:Connect(function()
            received = true
        end)
    end
    local sentAt = os.clock()
    local id = send("click", point.X, point.Y)
    local ok = true
    if connection then
        ok = Gui.waitFor(function()
            return received
        end, timeout or 8)
        connection:Disconnect()
        if ok then
            table.insert(latencies, os.clock() - sentAt)
        end
    else
        task.wait(1.2)
    end
    note("click", {
        id = id,
        label = label,
        ok = ok,
        x = math.floor(point.X),
        y = math.floor(point.Y),
        path = item:GetFullName(),
    })
    return ok, string.format("%s (%d, %d) %s", label, point.X, point.Y, if ok then "reçu" else "NON reçu")
end

-- Appui réel sur une touche ; « hold » en millisecondes. Ne prouve rien par lui-même :
-- l'appelant vérifie l'effet (écran ouvert, état changé).
local function scanOf(key: string): number
    local code = SCAN[key] or SCAN[string.upper(key)]
    assert(code, "touche sans code de balayage : " .. key)
    return code
end

function Gui.key(key: string, holdMs: number?)
    local id = if keyMode == "scan"
        then send("skey", scanOf(key), holdMs or 60)
        else send("key", vkOf(key), holdMs or 60)
    note("key", { id = id, key = key, hold = holdMs or 60, mode = keyMode })
end

function Gui.keyDown(key: string)
    local id = if keyMode == "scan" then send("sdown", scanOf(key)) else send("down", vkOf(key))
    note("down", { id = id, key = key, mode = keyMode })
end

function Gui.keyUp(key: string)
    local id = if keyMode == "scan" then send("sup", scanOf(key)) else send("up", vkOf(key))
    note("up", { id = id, key = key, mode = keyMode })
end

-- Étalonnage clavier : touches sans action dans le jeu (Q, Z, Y), envoyées par code
-- virtuel puis par code de balayage ; on garde le mode dont les KeyCode reçus sont
-- les bons. Renvoie (réussi, détail).
function Gui.calibrateKeys(): (boolean, string)
    local probe = { "Q", "Z", "Y" }
    local results = {}
    for _, mode in { "vk", "scan" } do
        local stop = Gui.recordKeys()
        for _, key in probe do
            if mode == "scan" then
                send("skey", scanOf(key), 60)
            else
                send("key", vkOf(key), 60)
            end
            task.wait(0.25)
        end
        task.wait(1.5)
        local seen = stop()
        results[mode] = table.concat(seen, ",")
        if results[mode] == table.concat(probe, ",") then
            keyMode = mode
            local detail = string.format(
                "mode %s retenu (vk : %s ; scan : %s)",
                mode,
                results.vk or "?",
                results.scan or "non essayé"
            )
            note("calibKeys", { ok = true, detail = detail })
            return true, detail
        end
    end
    local detail = string.format("aucun mode exact (vk : %s ; scan : %s)", results.vk or "", results.scan or "")
    note("calibKeys", { ok = false, detail = detail })
    return false, detail
end

-- Saisie réelle de texte (caractères Unicode) dans le champ qui a le focus.
function Gui.type(text: string)
    local hex = string.gsub(text, ".", function(char)
        return string.format("%02x", string.byte(char))
    end)
    local id = send("type", hex)
    note("type", { id = id, length = #text })
end

function Gui.wheel(item: GuiObject, notches: number)
    local point = Gui.center(item)
    local id = send("wheel", point.X, point.Y, notches)
    note("wheel", { id = id, notches = notches })
end

-- Capture nommée de la vue du jeu, reliée à sa position et à son contexte.
local shots: { { [string]: any } } = {}
function Gui.shot(name: string, context: { [string]: any }?)
    -- Nom d'un seul mot (l'outil sépare les arguments aux espaces).
    name = string.gsub(name, "%s+", "_")
    local id = send("shot", name)
    local character = (Players.LocalPlayer :: Player).Character
    local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
    local position = if root then root.Position else Vector3.zero
    local entry = {
        id = id,
        name = name,
        x = math.floor(position.X),
        y = math.floor(position.Y),
        z = math.floor(position.Z),
        context = if context then HttpService:JSONEncode(context) else nil,
    }
    table.insert(shots, entry)
    task.wait(0.6)
end

-- Pointeur posé hors des interfaces (bas de la vue) pour ne pas laisser de survol.
function Gui.park()
    local camera = Workspace.CurrentCamera :: Camera
    send("move", camera.ViewportSize.X / 2, camera.ViewportSize.Y - 5)
end

-- Touches reçues par le moteur (relevé pendant un essai clavier).
function Gui.recordKeys(): () -> { string }
    local seen: { string } = {}
    local connection = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Keyboard then
            table.insert(seen, input.KeyCode.Name)
        end
    end)
    return function()
        connection:Disconnect()
        return seen
    end
end

function Gui.report(): { [string]: any }
    local total = 0
    for _, value in latencies do
        total += value
    end
    return {
        actions = actions,
        shots = shots,
        clickLatencyMean = if #latencies > 0 then total / #latencies else nil,
        commands = sequence,
    }
end

return Gui
