--!strict
--[[
    Panneau plein écran V1.2 commun (lots UI-04 : économie, courses), même grammaire que le garage recomposé
    (maquette « Garage.dc.html ») : barre haute 56 (titre en capitales, lieu), onglets 48 à filet ambre, contenu
    centré (largeur de lecture bornée), bandeau d'état du serveur, barre d'aide 40 (touches, Fermer).

    Pas de maquette dédiée pour l'économie et les courses : proposition cohérente avec les jetons et composants du
    système de conception, à valider par le propriétaire (signalé dans le rapport).

    Éléments : texte, titre de section, carte (filet d'état facultatif), encadré (avertissement, refus, neutre),
    rangée qui passe à la ligne, boutons (principal, secondaire, révoquer ; désactivé avec raison), puce, ligne
    clé / valeur, cellules de valeurs, barre de progression, confirmation protégée (fenêtre modale).
    États du serveur : en attente (ambre), confirmé (vert), refusé et hors ligne (rouge), information (neutre).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tokens = require(Shared:WaitForChild("UI"):WaitForChild("DesignTokens"))
local Localization = require(Shared:WaitForChild("UI"):WaitForChild("Localization"))
local GarageView = require(Shared:WaitForChild("UI"):WaitForChild("GarageView"))
local UITheme = require(script.Parent.UITheme)
local UIState = require(script.Parent.UIState)
local Components = require(script.Parent.Components)

local PanelKit = {}

local STATE_KEYS = {
    Pending = "ui.state.pending",
    Confirmed = "ui.state.confirmed",
    Rejected = "ui.state.rejected",
    Offline = "ui.state.offline",
}

-- Largeur de lecture maximale du contenu (px) : au-delà (1440 p, ultralarge), le contenu reste centré.
PanelKit.MaxContentWidth = 1240

function PanelKit.color(name: string): Color3
    return Tokens.color(name, UIState.prefs().Access.HighContrast)
end
local color = PanelKit.color

local function make(className: string, props: { [string]: any }, parent: Instance?): any
    local item = Instance.new(className)
    for key, value in props do
        (item :: any)[key] = value
    end
    item.Parent = parent
    return item
end
PanelKit.make = make

local function corner(frame: Instance, radius: number)
    make("UICorner", { CornerRadius = UDim.new(0, radius) }, frame)
end

local function stroke(frame: Instance, tokenName: string?)
    make("UIStroke", {
        Color = color(tokenName or "Line"),
        Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, frame)
end

local function padding(frame: Instance, x: number, y: number)
    make("UIPadding", {
        PaddingLeft = UDim.new(0, x),
        PaddingRight = UDim.new(0, x),
        PaddingTop = UDim.new(0, y),
        PaddingBottom = UDim.new(0, y),
    }, frame)
end

local function vlist(frame: Instance, gap: number)
    make("UIListLayout", { Padding = UDim.new(0, gap), SortOrder = Enum.SortOrder.LayoutOrder }, frame)
end

export type Shell = {
    Gui: ScreenGui,
    Panel: Frame,
    Title: TextLabel,
    Context: TextLabel,
    Body: ScrollingFrame,
    Tabs: { [string]: TextButton },
    Close: TextButton,
    Status: { Kind: string?, Text: string },
    order: number,
    next: (Shell) -> number,
    setStatus: (Shell, string?, string) -> (),
    selectTab: (Shell, string) -> (),
    clear: (Shell) -> (),
    hints: (Shell, { { string } }) -> (),
}

-- Construit le panneau dans `gui` : titre, onglets (identifiants français traduits par `label`), rappel de fermeture.
function PanelKit.shell(
    gui: ScreenGui,
    name: string,
    title: string,
    tabs: { string },
    label: (string) -> string,
    onTab: (string) -> (),
    onClose: () -> ()
): Shell
    local panel = make("Frame", {
        Name = name,
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = color("BgBase"),
        BorderSizePixel = 0,
        Visible = false,
    }, gui)
    -- Racine logique (1440 p : disposition 1080 p à l'échelle 1,333 ; compacte sous 1400 px logiques).
    local logical = Components.logicalRoot(panel)
    local top = make("Frame", {
        Name = "BarreHaute",
        Size = UDim2.new(1, 0, 0, Tokens.Garage.TopBar),
        BackgroundColor3 = color("BgChrome"),
        BorderSizePixel = 0,
    }, logical)
    make("UIPadding", { PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20) }, top)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 14),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, top)
    local titleLabel = Components.text(top, Tokens.upper(title), "H1", { Name = "Titre", LayoutOrder = 1 })
    titleLabel.TextSize = UITheme.text(22)
    local contextLabel = Components.text(top, "", "Body", {
        Name = "Lieu",
        LayoutOrder = 2,
        TextColor3 = color("TextMuted"),
    })
    contextLabel.TextSize = UITheme.text(13)
    make("Frame", {
        Name = "FiletBarreHaute",
        BackgroundColor3 = color("Line"),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, Tokens.Garage.TopBar - 1),
        Size = UDim2.new(1, 0, 0, 1),
        ZIndex = 2,
    }, logical)
    local tabsBar = make("Frame", {
        Name = "Onglets",
        Position = UDim2.fromOffset(0, Tokens.Garage.TopBar),
        Size = UDim2.new(1, 0, 0, Tokens.Garage.Tabs),
        BackgroundColor3 = color("BgBase"),
        BorderSizePixel = 0,
    }, logical)
    make("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, tabsBar)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, tabsBar)
    local tabButtons: { [string]: TextButton } = {}
    for index, id in tabs do
        local item = make("TextButton", {
            Name = "Onglet" .. index,
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Text = label(id),
            LayoutOrder = index,
        }, tabsBar)
        make("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, item)
        item.FontFace = UITheme.face("Button")
        item.TextSize = UITheme.text(15)
        item.TextColor3 = color("TextMuted")
        make("Frame", {
            Name = "Filet",
            BackgroundColor3 = color("Amber"),
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, -16, 1, 0),
            Size = UDim2.new(1, 32, 0, Tokens.StatusRail),
            Visible = false,
        }, item)
        item.Activated:Connect(function()
            onTab(id)
        end)
        tabButtons[id] = item
    end
    local content = make("Frame", {
        Name = "Contenu",
        Position = UDim2.fromOffset(0, Tokens.Garage.TopBar + Tokens.Garage.Tabs),
        Size = UDim2.new(1, 0, 1, -(Tokens.Garage.TopBar + Tokens.Garage.Tabs + Tokens.Garage.HelpBar)),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
    }, logical)
    make("Frame", {
        BackgroundColor3 = color("Line"),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 1),
        ZIndex = 5,
    }, content)
    local body = make("ScrollingFrame", {
        Name = "Corps",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = color("Line"),
    }, content)
    local bodyPadding = make("UIPadding", {
        PaddingTop = UDim.new(0, 24),
        PaddingBottom = UDim.new(0, 24),
    }, body)
    vlist(body, 12)
    -- Contenu centré, largeur de lecture bornée ; marges de 28 px au minimum.
    local function center()
        local width = Components.logicalSize(body).X
        local side = math.max(28, math.floor((width - PanelKit.MaxContentWidth) / 2))
        bodyPadding.PaddingLeft = UDim.new(0, side)
        bodyPadding.PaddingRight = UDim.new(0, side)
    end
    body:GetPropertyChangedSignal("AbsoluteSize"):Connect(center)
    center()
    local statusBox = make("Frame", {
        Name = "EtatServeur",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = color("Surface1"),
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 6,
    }, content)
    padding(statusBox, 20, 10)
    vlist(statusBox, 2)
    local statusCode = Components.text(statusBox, "", "Value", { Name = "Code", LayoutOrder = 1, ZIndex = 7 })
    statusCode.TextSize = UITheme.text(11)
    local statusText = Components.text(statusBox, "", "Body", {
        Name = "Message",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 2,
        ZIndex = 7,
    })
    statusText.TextSize = UITheme.text(13)
    local function fit()
        body.Size = UDim2.new(1, 0, 1, -(if statusBox.Visible then statusBox.AbsoluteSize.Y else 0))
    end
    statusBox:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
    statusBox:GetPropertyChangedSignal("Visible"):Connect(fit)
    local help = make("Frame", {
        Name = "BarreAide",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, Tokens.Garage.HelpBar),
        BackgroundColor3 = color("BgChrome"),
        BorderSizePixel = 0,
    }, logical)
    make("Frame", { BackgroundColor3 = color("Line"), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1) }, help)
    local hintsRow = make("Frame", {
        Name = "Touches",
        Position = UDim2.fromOffset(20, 0),
        Size = UDim2.new(1, -200, 1, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
    }, help)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 18),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, hintsRow)
    local close = UITheme.button(Localization.tr("Fermer"), {
        Name = "Fermer",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -Tokens.PanelPadding, 0.5, 0),
        Size = UDim2.fromOffset(0, Tokens.MinTarget),
        AutomaticSize = Enum.AutomaticSize.X,
    }, help)
    make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, close)
    close.Activated:Connect(onClose)

    local shell: Shell
    shell = {
        Gui = gui,
        Panel = panel,
        Title = titleLabel,
        Context = contextLabel,
        Body = body,
        Tabs = tabButtons,
        Close = close,
        Status = { Kind = nil, Text = "" },
        order = 0,
        next = function(self: Shell): number
            self.order += 1
            return self.order
        end,
        setStatus = function(self: Shell, kind: string?, text: string)
            local entry = { Kind = kind, Text = text }
            self.Status = entry
            statusBox.Visible = text ~= ""
            local bg, fg = GarageView.statusTokens((kind or "Info") :: any)
            statusBox.BackgroundColor3 = color(bg)
            statusText.TextColor3 = color(fg)
            statusCode.TextColor3 = color(fg)
            statusCode.Text = if kind and STATE_KEYS[kind] then Tokens.upper(Localization.t(STATE_KEYS[kind])) else ""
            statusText.Text = text
            panel:SetAttribute("AWStatusKind", kind)
            fit()
            if kind == "Confirmed" or kind == "Info" then
                task.delay(6, function()
                    if self.Status == entry then
                        self:setStatus(nil, "")
                    end
                end)
            end
        end,
        selectTab = function(_self: Shell, id: string)
            for key, item in tabButtons do
                local on = key == id
                item.TextColor3 = if on then color("Text") else color("TextMuted")
                local rail = item:FindFirstChild("Filet") :: Frame?
                if rail then
                    rail.Visible = on
                end
            end
            panel:SetAttribute("AWTab", id)
        end,
        clear = function(self: Shell)
            for _, child in body:GetChildren() do
                if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
                    child:Destroy()
                end
            end
            self.order = 0
        end,
        hints = function(_self: Shell, list: { { string } })
            for _, child in hintsRow:GetChildren() do
                if not child:IsA("UIListLayout") then
                    child:Destroy()
                end
            end
            for index, hint in list do
                local holder = make("Frame", {
                    Name = "Touche" .. index,
                    BackgroundTransparency = 1,
                    AutomaticSize = Enum.AutomaticSize.XY,
                    LayoutOrder = index,
                }, hintsRow)
                make("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    Padding = UDim.new(0, 6),
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }, holder)
                local key = Components.text(holder, hint[1], "Value", { Name = "Touche", LayoutOrder = 1 })
                key.TextSize = UITheme.text(11)
                make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, key)
                corner(key, 3)
                stroke(key)
                Components.text(holder, hint[2], "Body", {
                    Name = "Action",
                    LayoutOrder = 2,
                    TextColor3 = color("TextMuted"),
                }).TextSize =
                    UITheme.text(13)
            end
        end,
    }
    return shell
end

-- Appel au serveur BORNÉ dans le temps : sans réponse au bout de `timeout` secondes (serveur injoignable, canal
-- perdu), renvoie (false, "Timeout") au lieu d'attendre indéfiniment ; l'écran affiche alors « hors ligne » et rien
-- n'est confirmé. Une réponse tardive est ignorée (le serveur reste l'autorité, l'instantané suivant la reflète).
PanelKit.InvokeTimeoutS = 12
function PanelKit.invoke(remote: RemoteFunction, ...: any): (boolean, any)
    local args = table.pack(...)
    local finished, ok, response = false, false, nil :: any
    task.spawn(function()
        local a, b = pcall(function()
            return remote:InvokeServer(table.unpack(args, 1, args.n))
        end)
        if not finished then
            finished, ok, response = true, a, b
        end
    end)
    local start = os.clock()
    while not finished and os.clock() - start < PanelKit.InvokeTimeoutS do
        task.wait(0.05)
    end
    if not finished then
        finished = true
        return false, "Timeout"
    end
    return ok, response
end

-- Compteur des demandes réellement envoyées (attribut lu par les essais : un double clic n'en envoie qu'une).
function PanelKit.countSent(panel: Instance)
    local count = panel:GetAttribute("AWSent")
    panel:SetAttribute("AWSent", (if type(count) == "number" then count else 0) + 1)
end

-- Touches de la barre d'aide selon le dernier périphérique utilisé.
function PanelKit.isGamepad(): boolean
    return string.sub(UserInputService:GetLastInputType().Name, 1, 7) == "Gamepad"
end

-- ======================== Éléments ========================

function PanelKit.text(shell: Shell, parent: Instance, text: string, style: string?, tokenName: string?): TextLabel
    return Components.text(parent, text, style or "Body", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = color(tokenName or "Text"),
        LayoutOrder = shell:next(),
    })
end

-- Titre de section (capitales, discret, 12 px).
function PanelKit.heading(shell: Shell, parent: Instance, text: string): TextLabel
    local label = PanelKit.text(shell, parent, Tokens.upper(text), "Label", "TextMuted")
    label.Name = "TitreSection"
    return label
end

-- Carte : surface 1, filet, coins 4 px ; filet gauche d'état facultatif (posé hors de la liste du contenu).
function PanelKit.card(shell: Shell, parent: Instance, name: string?, accent: string?): Frame
    local frame = make("Frame", {
        Name = name or "Carte",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = color("Surface1"),
        BorderSizePixel = 0,
        LayoutOrder = shell:next(),
        ClipsDescendants = true,
    }, parent)
    corner(frame, Tokens.Radius.Button)
    stroke(frame)
    if accent then
        make("Frame", {
            Name = "Filet",
            BackgroundColor3 = color(accent),
            BorderSizePixel = 0,
            Size = UDim2.new(0, Tokens.StatusRail, 1, 0),
        }, frame)
    end
    local inner = make("Frame", {
        Name = "CarteCorps",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, frame)
    make("UIPadding", {
        PaddingLeft = UDim.new(0, 14 + (if accent then Tokens.StatusRail else 0)),
        PaddingRight = UDim.new(0, 14),
        PaddingTop = UDim.new(0, 12),
        PaddingBottom = UDim.new(0, 12),
    }, inner)
    vlist(inner, 6)
    return inner
end

-- Titre de carte (15 px demi-gras) et valeur à droite facultative (Roboto Mono).
function PanelKit.cardTitle(shell: Shell, inner: Instance, title: string, value: string?, valueToken: string?)
    local row = make("Frame", {
        Name = "Entete",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = shell:next(),
    }, inner)
    local label = Components.text(row, title, "Body", {
        Name = "Titre",
        Size = UDim2.new(if value then 0.62 else 1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    label.FontFace = UITheme.face("Button")
    label.TextSize = UITheme.text(17)
    if value then
        local v = Components.text(row, value, "Value", {
            Name = "Valeur",
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.fromScale(1, 0),
            Size = UDim2.new(0.38, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextColor3 = color(valueToken or "Text"),
        })
        v.TextSize = UITheme.text(16)
    end
end

-- Encadré : « Warn » (ambre sombre), « Danger » (rouge sombre), « Neutral » (neutre).
function PanelKit.notice(shell: Shell, parent: Instance, kind: string, text: string): Frame
    local bg, line, fg = "WarnBg", "WarnLine", "WarnText"
    if kind == "Danger" then
        bg, line, fg = "DangerBg", "RaceRed", "DangerText"
    elseif kind == "Neutral" then
        bg, line, fg = "BgBase", "Line", "TextMuted"
    end
    local frame = make("Frame", {
        Name = "Encadre" .. kind,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = color(bg),
        BorderSizePixel = 0,
        LayoutOrder = shell:next(),
    }, parent)
    corner(frame, Tokens.Radius.Button)
    stroke(frame, line)
    padding(frame, 12, 10)
    Components.text(frame, text, "Body", {
        Name = "Texte",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = color(fg),
    })
    return frame
end

-- Rangée qui passe à la ligne : rien ne déborde en disposition compacte.
function PanelKit.row(shell: Shell, parent: Instance, gap: number?): Frame
    local frame = make("Frame", {
        Name = "Rangee",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = shell:next(),
    }, parent)
    local layout = make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, gap or 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
    }, frame);
    (layout :: any).Wraps = true
    return frame
end

export type ButtonKind = "Primary" | "Secondary" | "Revoke" | "Chip"

-- Bouton : principal ambre, secondaire, révoquer (rouge) ; désactivé : opacité 0,45, raison dans AWReason.
function PanelKit.button(
    shell: Shell,
    parent: Instance,
    text: string,
    kind: ButtonKind,
    callback: (() -> ())?,
    enabled: boolean?,
    reason: string?,
    name: string?,
    height: number?
): TextButton
    local active = enabled ~= false
    local item = UITheme.button(text, {
        Name = name or "Bouton",
        Size = UDim2.fromOffset(0, height or Tokens.MinTargetPartChip),
        AutomaticSize = Enum.AutomaticSize.X,
        LayoutOrder = shell:next(),
    }, parent)
    make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, item)
    local edge = item:FindFirstChildOfClass("UIStroke") :: UIStroke
    item.FontFace = UITheme.face("Button")
    if kind == "Primary" then
        item.BackgroundColor3 = color("Amber")
        item.TextColor3 = color("TextOnAmber")
        edge.Color = color("Amber")
        item.FontFace = Font.new(UITheme.face("Button").Family, Enum.FontWeight.Bold)
    elseif kind == "Revoke" then
        item.BackgroundTransparency = 1
        item.TextColor3 = color("DangerText")
        edge.Color = color("RaceRed")
    end
    item.TextSize = UITheme.text(if (height or 36) >= 44 then 15 else 14)
    if active then
        if callback then
            item.Activated:Connect(callback)
        end
    else
        item.Active = false
        item.Selectable = false
        item.BackgroundTransparency = if kind == "Revoke" then 1 else Tokens.DisabledTransparency
        item.TextTransparency = Tokens.DisabledTransparency
        edge.Transparency = Tokens.DisabledTransparency
        item:SetAttribute("AWDisabled", true)
        if reason then
            item:SetAttribute("AWReason", reason)
        end
    end
    return item
end

-- Pastille d'étiquette (capitales, 11 px).
function PanelKit.tag(shell: Shell, parent: Instance, text: string, tokenName: string?)
    local label = Components.text(parent, Tokens.upper(text), "Label", {
        Name = "Etiquette",
        BackgroundTransparency = 0,
        TextColor3 = color(tokenName or "Text"),
        LayoutOrder = shell:next(),
    })
    label.BackgroundColor3 = Color3.fromRGB(34, 37, 42)
    label.TextSize = UITheme.text(11)
    corner(label, 2)
    make("UIPadding", {
        PaddingLeft = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 6),
        PaddingTop = UDim.new(0, 2),
        PaddingBottom = UDim.new(0, 2),
    }, label)
end

-- Ligne clé / valeur (valeur en Roboto Mono, filet bas).
function PanelKit.keyValue(shell: Shell, parent: Instance, key: string, value: string, valueToken: string?)
    local frame = make("Frame", {
        Name = "CleValeur",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = shell:next(),
    }, parent)
    make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, frame)
    Components.text(frame, key, "Body", {
        Size = UDim2.new(0.55, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = color("TextMuted"),
    })
    Components.text(frame, value, "Value", {
        Name = "Valeur",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0.45, -8, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextColor3 = color(valueToken or "Text"),
    }).TextSize =
        UITheme.text(14)
    make("Frame", {
        BackgroundColor3 = Color3.fromRGB(31, 34, 38),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 6),
        Size = UDim2.new(1, 0, 0, 1),
    }, frame)
end

-- Cellules de valeurs (clé en capitales, valeur Roboto Mono 20 px), sur 2 à 4 colonnes selon la largeur.
function PanelKit.cells(shell: Shell, parent: Instance, cells: { { string } }, name: string?)
    local width = if parent:IsA("GuiObject") then Components.logicalSize(parent).X else 800
    local columns = if width >= 900 then 4 elseif width >= 520 then 3 else 2
    columns = math.min(columns, #cells)
    local rows = math.ceil(#cells / math.max(columns, 1))
    local grid = make("Frame", {
        Name = name or "Cellules",
        Size = UDim2.new(1, 0, 0, rows * 66 + (rows - 1) * 8),
        BackgroundTransparency = 1,
        LayoutOrder = shell:next(),
    }, parent)
    make("UIGridLayout", {
        CellSize = UDim2.new(1 / math.max(columns, 1), -8 * (columns - 1) / math.max(columns, 1), 0, 66),
        CellPadding = UDim2.fromOffset(8, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, grid)
    for index, cell in cells do
        local frame = make("Frame", {
            Name = "Cellule",
            BackgroundColor3 = color("Surface1"),
            BorderSizePixel = 0,
            LayoutOrder = index,
        }, grid)
        corner(frame, Tokens.Radius.Button)
        stroke(frame)
        padding(frame, 12, 8)
        vlist(frame, 2)
        Components.text(frame, Tokens.upper(cell[1]), "Label", { TextColor3 = color("TextMuted"), LayoutOrder = 1 })
        local value = Components.text(frame, cell[2], "Value", {
            Name = "Valeur",
            LayoutOrder = 2,
            TextColor3 = color(cell[3] or "Text"),
        })
        value.TextSize = UITheme.text(20)
    end
end

-- Barre de progression (0 à 1) : piste discrète, remplissage d'un jeton (ambre par défaut).
function PanelKit.progress(shell: Shell, parent: Instance, ratio: number, tokenName: string?): Frame
    local track = make("Frame", {
        Name = "Progression",
        Size = UDim2.new(1, 0, 0, 6),
        BackgroundColor3 = Color3.fromRGB(34, 37, 42),
        BorderSizePixel = 0,
        LayoutOrder = shell:next(),
    }, parent)
    corner(track, 3)
    local fill = make("Frame", {
        Name = "Remplissage",
        Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1),
        BackgroundColor3 = color(tokenName or "Amber"),
        BorderSizePixel = 0,
    }, track)
    corner(fill, 3)
    track:SetAttribute("AWRatio", math.clamp(ratio, 0, 1))
    return track
end

-- Confirmation protégée (fenêtre modale) : refusée tant que la garde l'interdit (InputMap, Components.confirm).
function PanelKit.confirm(gui: ScreenGui, question: string, onConfirm: () -> (), onCancel: (() -> ())?): Frame
    local existing = gui:FindFirstChild("VoileConfirmation")
    if existing then
        existing:Destroy()
    end
    local veil = make("Frame", {
        Name = "VoileConfirmation",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = color("BgBase"),
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        ZIndex = 50,
        Active = true,
    }, gui)
    local box = Components.confirm(veil, {
        Question = question,
        Width = math.min(520, (Workspace.CurrentCamera :: Camera).ViewportSize.X - 40),
        OnConfirm = function()
            veil:Destroy()
            onConfirm()
        end,
        OnCancel = function()
            veil:Destroy()
            if onCancel then
                onCancel()
            end
        end,
    })
    if box then
        box.AnchorPoint = Vector2.new(0.5, 0.5)
        box.Position = UDim2.fromScale(0.5, 0.5)
    end
    return veil
end

-- Chevron dessiné (aucun caractère Unicode en guise d'icône) : deux traits de 2 px, pointe vers le haut.
function PanelKit.chevronUp(parent: Instance, size: number, tokenName: string?): Frame
    local holder = make("Frame", {
        Name = "Chevron",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(size, size),
    }, parent)
    for _, sign in { -1, 1 } do
        make("Frame", {
            BackgroundColor3 = color(tokenName or "AmberSoftText"),
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, sign * size * 0.2, 0.5, 0),
            Size = UDim2.fromOffset(3, math.floor(size * 0.6)),
            Rotation = -sign * 45,
        }, holder)
    end
    return holder
end

return table.freeze(PanelKit)
