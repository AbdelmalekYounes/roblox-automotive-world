--!strict
--[[
    Composants de base du système de conception UI PREMIUM V1.2 (lot UI-01). Maquette du propriétaire « Design System
    V1.2 » §4 (composants), §6 (états), §8 (accessibilité). Construits par `UITheme` et les jetons
    (`Shared.UI.DesignTokens`) ; aucune logique de service : un composant AFFICHE l'état que lui donne l'écran.

    Règles retenues de la maquette :
    - désactivé : opacité 0,45, `Active = false`, raison affichée à côté (jamais un bouton muet) ;
    - focus manette et clavier : contour ambre de 2 px ;
    - « Confirmé » n'est jamais affiché par un composant de lui-même : l'état « Confirmed » est posé par l'écran à la
      réception de l'évènement du serveur ;
    - confirmation protégée : bouton inactif tant que `InputMap.accepts` est faux (0,25 s après l'affichage, 0,4 s
      après un changement de périphérique), jamais proposée en mode rapide ;
    - plages et pas des réglages, couleurs du nuancier : fournis par l'appelant (TuningRules, CosmeticCatalog),
      jamais codés ici.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local SharedUI = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI")
local Tokens = require(SharedUI:WaitForChild("DesignTokens"))
local InputMap = require(SharedUI:WaitForChild("InputMap"))
local Localization = require(SharedUI:WaitForChild("Localization"))
local UITheme = require(script.Parent.UITheme)
local UIState = require(script.Parent.UIState)

local Components = {}

local function corner(radius: number, parent: Instance)
    UITheme.make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function styleText(item: TextLabel | TextButton, style: string, color: Color3)
    local target = item :: any
    target.FontFace = UITheme.face(style)
    target.TextSize = UITheme.text(Tokens.Type[style].Size)
    target.TextColor3 = color
end

local function caps(text: string, style: string): string
    return if Tokens.Type[style].Caps then Tokens.upper(text) else text
end

-- Texte simple au style de la maquette (Display, H1, H2, Button, Body, Label, Speed, Race, Value).
function Components.text(parent: Instance, text: string, style: string, props: { [string]: any }?): TextLabel
    local label = UITheme.make("TextLabel", props or {}, parent) :: TextLabel
    label.BackgroundTransparency = 1
    label.Text = caps(text, style)
    styleText(label, style, (props and props.TextColor3) or UITheme.color("Text"))
    if not (props and props.Size) then
        label.AutomaticSize = Enum.AutomaticSize.XY
    end
    return label
end

export type ButtonKind = "Primary" | "Secondary" | "Revoke"
export type ButtonOptions = {
    Disabled: boolean?,
    Reason: string?, -- raison affichée quand le bouton est désactivé
    OnActivated: (() -> ())?,
    Width: number?,
    LayoutOrder: number?,
}

-- Bouton (§4) : principal ambre, secondaire, révoquer ; état désactivé expliqué.
function Components.button(parent: Instance, text: string, kind: ButtonKind, options: ButtonOptions?): TextButton
    local opts: ButtonOptions = options or ({} :: ButtonOptions)
    local holder = UITheme.make("Frame", {
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.XY,
        LayoutOrder = opts.LayoutOrder or 0,
    }, parent)
    UITheme.make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, Tokens.Space[2]),
    }, holder)
    local button = UITheme.button(text, {
        Size = UDim2.fromOffset(opts.Width or 0, Tokens.PrimaryButtonHeight),
        AutomaticSize = if opts.Width then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
    }, holder)
    UITheme.make("UIPadding", {
        PaddingLeft = UDim.new(0, Tokens.Space[4]),
        PaddingRight = UDim.new(0, Tokens.Space[4]),
    }, button)
    local stroke = button:FindFirstChildOfClass("UIStroke") :: UIStroke
    if kind == "Primary" then
        button.BackgroundColor3 = UITheme.color("Accent")
        button.TextColor3 = UITheme.color("OnAccent")
        stroke.Color = UITheme.color("Accent")
    elseif kind == "Revoke" then
        button.BackgroundColor3 = UITheme.color("PanelRaised")
        button.TextColor3 = UITheme.color("Danger")
        stroke.Color = UITheme.color("Danger")
    end
    button.FontFace = UITheme.face("Button")
    button:SetAttribute("AWKind", kind)
    if opts.Disabled then
        button.Active = false
        button.Selectable = false
        button.BackgroundTransparency = Tokens.DisabledTransparency
        button.TextTransparency = Tokens.DisabledTransparency
        stroke.Transparency = Tokens.DisabledTransparency
        button:SetAttribute("AWDisabled", true)
        if opts.Reason then
            Components.text(holder, opts.Reason, "Body", { TextColor3 = UITheme.color("TextDim"), LayoutOrder = 2 })
        end
    elseif opts.OnActivated then
        button.Activated:Connect(opts.OnActivated)
    end
    return button
end

-- Onglets (§4) : onglet actif souligné d'un filet ambre de 3 px ; largeur automatique (textes anglais +35 %).
function Components.tabs(parent: Instance, items: { string }, active: number, onSelect: ((number) -> ())?): Frame
    local bar = UITheme.make("Frame", {
        BackgroundColor3 = UITheme.color("PanelChrome"),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, Tokens.Garage.Tabs),
    }, parent) :: Frame
    UITheme.make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, Tokens.Space[6]),
    }, bar)
    for index, label in items do
        local tab = UITheme.make("TextButton", {
            Name = "Onglet" .. index,
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            Text = label,
            LayoutOrder = index,
        }, bar) :: TextButton
        styleText(tab, "Button", if index == active then UITheme.color("Text") else UITheme.color("TextDim"))
        if index == active then
            UITheme.make("Frame", {
                Name = "Filet",
                BackgroundColor3 = UITheme.color("Accent"),
                BorderSizePixel = 0,
                AnchorPoint = Vector2.new(0, 1),
                Position = UDim2.fromScale(0, 1),
                Size = UDim2.new(1, 0, 0, Tokens.StatusRail),
            }, tab)
        end
        if onSelect then
            tab.Activated:Connect(function()
                onSelect(index)
            end)
        end
    end
    return bar
end

-- Choix segmenté (§4, vues de caméra) : segment actif plein ambre.
function Components.segmented(parent: Instance, items: { string }, active: number, onSelect: ((number) -> ())?): Frame
    local row = UITheme.make("Frame", {
        BackgroundColor3 = UITheme.color("PanelRaised"),
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, Tokens.MinTarget),
    }, parent) :: Frame
    corner(Tokens.Radius.Button, row)
    UITheme.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal }, row)
    for index, label in items do
        local on = index == active
        local segment = UITheme.make("TextButton", {
            Name = "Segment" .. index,
            BackgroundColor3 = UITheme.color("Accent"),
            BackgroundTransparency = if on then 0 else 1,
            AutoButtonColor = false,
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            Text = label,
            LayoutOrder = index,
        }, row) :: TextButton
        corner(Tokens.Radius.Button, segment)
        UITheme.make("UIPadding", {
            PaddingLeft = UDim.new(0, Tokens.Space[3]),
            PaddingRight = UDim.new(0, Tokens.Space[3]),
        }, segment)
        styleText(segment, "Button", if on then UITheme.color("OnAccent") else UITheme.color("TextDim"))
        if onSelect then
            segment.Activated:Connect(function()
                onSelect(index)
            end)
        end
    end
    return row
end

export type TuningSpec = {
    Label: string,
    Value: number,
    Origin: number, -- valeur d'origine (affichée « origine »)
    Min: number, -- plage fournie par TuningRules, jamais codée dans l'interface
    Max: number,
    Step: number,
    Format: string, -- ex. "%.2f×"
    OnChange: ((number) -> ())?,
}

-- Ligne de réglage (§4) : valeur modifiée en ambre, origine rappelée, pas et plage de l'appelant.
function Components.tuningRow(parent: Instance, spec: TuningSpec): Frame
    local row = UITheme.make("Frame", {
        BackgroundColor3 = UITheme.color("Surface"),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, Tokens.PrimaryButtonHeight + Tokens.Space[3]),
    }, parent) :: Frame
    corner(Tokens.Radius.Card, row)
    UITheme.make("UIPadding", {
        PaddingLeft = UDim.new(0, Tokens.Space[3]),
        PaddingRight = UDim.new(0, Tokens.Space[3]),
    }, row)
    Components.text(row, spec.Label, "Body", { Position = UDim2.fromOffset(0, 6) })
    local value = spec.Value
    local display = Components.text(row, "", "Value", {
        Name = "Valeur",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -2 * Tokens.MinTarget - Tokens.Space[3], 0, 6),
    })
    local origin = Components.text(row, "", "Label", {
        Name = "Origine",
        TextColor3 = UITheme.color("TextDim"),
        Position = UDim2.fromOffset(0, 30),
    })
    local function refresh()
        display.Text = string.format(spec.Format, value)
        display.TextColor3 = if math.abs(value - spec.Origin) > 1e-9
            then UITheme.color("Accent")
            else UITheme.color("Text")
        origin.Text =
            Tokens.upper(Localization.t("ui.tuning.origin", { value = string.format(spec.Format, spec.Origin) }))
        row:SetAttribute("AWValue", value)
    end
    local function nudge(steps: number)
        local nextValue = math.clamp(value + steps * spec.Step, spec.Min, spec.Max)
        value = math.floor(nextValue / spec.Step + 0.5) * spec.Step
        refresh()
        if spec.OnChange then
            spec.OnChange(value)
        end
    end
    for index, delta in { -1, 1 } do
        local arrow = UITheme.button(if delta < 0 then "-" else "+", {
            Name = if delta < 0 then "Moins" else "Plus",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -(2 - index) * (Tokens.MinTarget + 4), 0.5, 0),
            Size = UDim2.fromOffset(Tokens.MinTarget, Tokens.MinTarget),
        }, row)
        arrow.Activated:Connect(function()
            nudge(delta)
        end)
    end
    refresh()
    return row
end

-- Puce de pièce (§4) : sélectionnée en ambre ; incompatible à 0,4 d'opacité avec sa raison (PartCatalog).
function Components.chip(parent: Instance, text: string, selected: boolean, reason: string?): TextButton
    local chip = UITheme.make("TextButton", {
        BackgroundColor3 = if selected then UITheme.color("AccentSoft") else UITheme.color("PanelRaised"),
        AutoButtonColor = false,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, Tokens.MinTargetPartChip),
        Text = text,
    }, parent) :: TextButton
    corner(Tokens.Radius.Chip, chip)
    UITheme.make("UIPadding", {
        PaddingLeft = UDim.new(0, Tokens.Space[3]),
        PaddingRight = UDim.new(0, Tokens.Space[3]),
    }, chip)
    UITheme.make("UIStroke", {
        Color = if selected then UITheme.color("Accent") else UITheme.color("Line"),
        Thickness = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, chip)
    styleText(chip, "Body", if selected then UITheme.color("AccentSoftText") else UITheme.color("Text"))
    if reason then
        chip.Active = false
        chip.TextTransparency = 0.6
        chip.BackgroundTransparency = 0.6
        chip:SetAttribute("AWReason", reason)
    end
    return chip
end

-- Pastille du nuancier : couleur fournie par CosmeticCatalog.Colors, jamais redéfinie ici.
function Components.swatch(parent: Instance, color: Color3, selected: boolean): TextButton
    local swatch = UITheme.make("TextButton", {
        BackgroundColor3 = color,
        AutoButtonColor = false,
        Text = "",
        Size = UDim2.fromOffset(Tokens.MinTargetPartChip, Tokens.MinTargetPartChip),
    }, parent) :: TextButton
    corner(Tokens.Radius.Button, swatch)
    UITheme.make("UIStroke", {
        Color = if selected then UITheme.color("Accent") else UITheme.color("Line"),
        Thickness = if selected then Tokens.FocusStroke else 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, swatch)
    return swatch
end

-- Carte (§4) avec filet gauche de statut : "Gps" cyan, "Pending" ambre, "Done" vert ; nil sans filet.
function Components.card(parent: Instance, title: string, subtitle: string?, status: string?): Frame
    local card = UITheme.make("Frame", {
        BackgroundColor3 = UITheme.color("Surface"),
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0),
    }, parent) :: Frame
    corner(Tokens.Radius.Card, card)
    -- Contenu dans son propre cadre (liste et marges) ; le filet reste hors de la liste, à hauteur fixe recopiée du
    -- contenu (une hauteur relative dans un cadre à taille automatique bouclait : carte étirée, VM 20261105-032212).
    local content = UITheme.make("Frame", {
        Name = "Contenu",
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0),
    }, card) :: Frame
    UITheme.make("UIPadding", {
        PaddingLeft = UDim.new(0, Tokens.Space[4]),
        PaddingRight = UDim.new(0, Tokens.Space[3]),
        PaddingTop = UDim.new(0, Tokens.Space[3]),
        PaddingBottom = UDim.new(0, Tokens.Space[3]),
    }, content)
    UITheme.make(
        "UIListLayout",
        { Padding = UDim.new(0, Tokens.Space[1]), SortOrder = Enum.SortOrder.LayoutOrder },
        content
    )
    Components.text(content, title, "Button", { LayoutOrder = 1 })
    if subtitle then
        Components.text(content, subtitle, "Body", { TextColor3 = UITheme.color("TextDim"), LayoutOrder = 2 })
    end
    local token = status and Tokens.StatusRailColor[status]
    if token then
        local rail = UITheme.make("Frame", {
            Name = "Filet",
            BackgroundColor3 = Tokens.color(token),
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(Tokens.StatusRail, 0),
        }, card) :: Frame
        local function fit()
            rail.Size = UDim2.fromOffset(Tokens.StatusRail, content.AbsoluteSize.Y)
        end
        content:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
        fit()
        card:SetAttribute("AWStatus", status)
    end
    return card
end

-- Avertissement (§1, fonds d'état) : "Warn", "Danger", "Ok".
function Components.notice(parent: Instance, kind: string, text: string): Frame
    local palette = {
        Warn = { "WarnBg", "WarnLine", "WarnText" },
        Danger = { "DangerBg", "RaceRed", "DangerText" },
        Ok = { "OkBg", "Ok", "OkText" },
    }
    local p = palette[kind] or palette.Warn
    local box = UITheme.make("Frame", {
        BackgroundColor3 = Tokens.color(p[1]),
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0),
    }, parent) :: Frame
    corner(Tokens.Radius.Card, box)
    UITheme.make("UIStroke", { Color = Tokens.color(p[2]), Thickness = 1 }, box)
    UITheme.make("UIPadding", {
        PaddingLeft = UDim.new(0, Tokens.Space[3]),
        PaddingRight = UDim.new(0, Tokens.Space[3]),
        PaddingTop = UDim.new(0, Tokens.Space[2]),
        PaddingBottom = UDim.new(0, Tokens.Space[2]),
    }, box)
    Components.text(box, text, "Body", {
        TextColor3 = Tokens.color(p[3]),
        TextWrapped = true,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    return box
end

-- Cellule de course (§4) : filet supérieur coloré, chiffres mono gras italiques.
function Components.raceCell(parent: Instance, label: string, value: string, railToken: string?): Frame
    local cell = UITheme.make("Frame", {
        BackgroundColor3 = UITheme.color("Panel"),
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.XY,
    }, parent) :: Frame
    local content = UITheme.make("Frame", {
        Name = "Contenu",
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.XY,
    }, cell) :: Frame
    UITheme.make("UIPadding", {
        PaddingLeft = UDim.new(0, Tokens.Space[3]),
        PaddingRight = UDim.new(0, Tokens.Space[3]),
        PaddingTop = UDim.new(0, Tokens.Space[2] + Tokens.StatusRail),
        PaddingBottom = UDim.new(0, Tokens.Space[2]),
    }, content)
    UITheme.make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, content)
    Components.text(content, label, "Label", { TextColor3 = UITheme.color("TextDim"), LayoutOrder = 1 })
    Components.text(content, value, "Race", { LayoutOrder = 2 })
    -- Filet supérieur hors de la liste, largeur recopiée du contenu (même raison que la carte).
    local rail = UITheme.make("Frame", {
        Name = "Filet",
        BackgroundColor3 = Tokens.color(railToken or "RaceRed"),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(0, Tokens.StatusRail),
    }, cell) :: Frame
    local function fit()
        rail.Size = UDim2.fromOffset(content.AbsoluteSize.X, Tokens.StatusRail)
    end
    content:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
    fit()
    return cell
end

-- Badge d'état de chargement ou de sauvegarde (§6). `detail` : texte d'erreur déjà traduit (Rejected).
function Components.stateBadge(parent: Instance, state: string, detail: string?): Frame
    assert(table.find(Tokens.SaveStates, state) ~= nil, "État inconnu : " .. state)
    local kind = if state == "Confirmed"
        then "Ok"
        elseif state == "Rejected" or state == "Offline" then "Danger"
        else "Warn"
    local text = Localization.t("ui.state." .. string.lower(state))
    if detail then
        text ..= " — " .. detail
    end
    local box = Components.notice(parent, kind, text)
    box:SetAttribute("AWState", state)
    if state == "Loading" then
        -- Squelette : surface.1, aucun chiffre inventé.
        box.BackgroundColor3 = UITheme.color("Surface")
    end
    return box
end

-- Zone 3D du véhicule (§4) : dégradé #2A2E34 → #0E0F11 ; rien ne couvre le centre. Rendu du véhicule par ViewportFrame
-- (choix du propriétaire, 2026-11-05 : VehiclePreview), posé au-dessus de ce dégradé.
function Components.stage(parent: Instance): Frame
    local stage = UITheme.make("Frame", {
        Name = "Zone3D",
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
    }, parent) :: Frame
    UITheme.make("UIGradient", {
        Color = ColorSequence.new(Tokens.Colors.Stage3D, Tokens.Colors.BgBase),
        Rotation = 90,
    }, stage)
    return stage
end

export type ConfirmOptions = {
    Question: string,
    OnConfirm: () -> (),
    OnCancel: (() -> ())?,
    Quick: boolean?,
    Width: number?, -- largeur du panneau (420 px par défaut)
}

-- Confirmation protégée (§4) : refusée en mode rapide ; « Confirmer » inactif tant que la garde l'interdit.
function Components.confirm(parent: Instance, options: ConfirmOptions): Frame?
    if options.Quick then
        return nil
    end
    local panel = UITheme.panel({
        Name = "ConfirmationProtegee",
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.fromOffset(options.Width or 420, 0),
    }, parent)
    UITheme.make("UIPadding", {
        PaddingLeft = UDim.new(0, Tokens.PanelPadding),
        PaddingRight = UDim.new(0, Tokens.PanelPadding),
        PaddingTop = UDim.new(0, Tokens.PanelPadding),
        PaddingBottom = UDim.new(0, Tokens.PanelPadding),
    }, panel)
    UITheme.make(
        "UIListLayout",
        { Padding = UDim.new(0, Tokens.Space[4]), SortOrder = Enum.SortOrder.LayoutOrder },
        panel
    )
    Components.text(panel, options.Question, "H1", {
        TextWrapped = true,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 1,
    })
    local actions = UITheme.make("Frame", {
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.XY,
        LayoutOrder = 2,
    }, panel)
    UITheme.make(
        "UIListLayout",
        { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, Tokens.Space[3]) },
        actions
    )
    local guard = InputMap.newGuard(Workspace:GetServerTimeNow())
    local cancel = Components.button(actions, Localization.t("ui.cancel"), "Secondary", { LayoutOrder = 1 })
    local ok = Components.button(actions, Localization.t("ui.confirm"), "Primary", { LayoutOrder = 2 })
    ok.Active = false
    ok.BackgroundTransparency = Tokens.DisabledTransparency
    local function device(input: InputObject): string
        local kind = input.UserInputType.Name
        return if string.sub(kind, 1, 7) == "Gamepad"
            then "Gamepad"
            elseif kind == "Touch" then "Touch"
            else "KeyboardMouse"
    end
    local pressBegan = -math.huge
    local connections: { RBXScriptConnection } = {}
    table.insert(
        connections,
        UserInputService.InputBegan:Connect(function(input)
            InputMap.deviceChanged(guard, device(input), Workspace:GetServerTimeNow())
            pressBegan = Workspace:GetServerTimeNow()
        end)
    )
    -- Activation visible dès que la garde l'accepte (rafraîchie à chaque image tant que le panneau existe).
    table.insert(
        connections,
        game:GetService("RunService").Heartbeat:Connect(function()
            local allowed = InputMap.accepts(guard, Workspace:GetServerTimeNow())
            ok.Active = allowed
            ok.BackgroundTransparency = if allowed then 0 else Tokens.DisabledTransparency
            panel:SetAttribute("AWConfirmArmed", allowed)
        end)
    )
    ok.Activated:Connect(function()
        if InputMap.accepts(guard, pressBegan) then
            options.OnConfirm()
        end
    end)
    cancel.Activated:Connect(function()
        if options.OnCancel then
            options.OnCancel()
        end
    end)
    panel.Destroying:Connect(function()
        for _, connection in connections do
            connection:Disconnect()
        end
    end)
    return panel
end

-- Taille d'un élément en pixels LOGIQUES : AbsoluteSize (pixels d'écran) divisée par le produit des UIScale de ses
-- ancêtres et du sien. Indispensable pour calculer des cotes en « offset » dans une racine mise à l'échelle.
function Components.logicalSize(item: GuiObject): Vector2
    local factor = 1
    local node: Instance? = item
    while node ~= nil and not node:IsA("LayerCollector") do
        local scale = node:FindFirstChildOfClass("UIScale")
        if scale then
            factor *= scale.Scale
        end
        node = node.Parent
    end
    return item.AbsoluteSize / math.max(factor, 1e-3)
end

-- Racine logique d'un écran plein (§3) : le contenu est disposé en pixels logiques (taille de la vue divisée par
-- l'échelle), puis agrandi par un UIScale (1440 p : 1,333) ; il remplit exactement son parent sans déborder. Suit
-- les changements de taille de la vue.
function Components.logicalRoot(parent: GuiObject, name: string?): Frame
    local root = UITheme.make("Frame", {
        Name = name or "Logique",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
    }, parent) :: Frame
    local scale = UITheme.make("UIScale", {}, root) :: UIScale
    local function update()
        local layout = UIState.layout()
        scale.Scale = layout.Scale
        root.Size = UDim2.fromScale(1 / layout.Scale, 1 / layout.Scale)
        root:SetAttribute("AWScale", layout.Scale)
        root:SetAttribute("AWCompact", layout.Compact)
    end
    update()
    UIState.onViewport(update)
    return root
end

-- Échelle de l'écran (§3) : 1440 p = disposition 1080 p à l'échelle 1,333 ; compacte sous 1400 px logiques. Pose un
-- UIScale et l'attribut AWCompact ; suit les changements de taille de la fenêtre.
function Components.applyLayout(gui: LayerCollector): () -> ()
    local camera = Workspace.CurrentCamera :: Camera
    local scale = gui:FindFirstChildOfClass("UIScale") or UITheme.make("UIScale", {}, gui)
    local function update()
        local layout = Tokens.layout(camera.ViewportSize.X, camera.ViewportSize.Y)
        scale.Scale = layout.Scale
        gui:SetAttribute("AWCompact", layout.Compact)
        gui:SetAttribute("AWScale", layout.Scale)
    end
    update()
    local connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
    return function()
        connection:Disconnect()
    end
end

return table.freeze(Components)
