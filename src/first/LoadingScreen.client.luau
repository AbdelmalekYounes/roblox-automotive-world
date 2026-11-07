--!strict
--[[
    Écran de chargement du jeu (lot BRAND-01). LocalScript de ReplicatedFirst : il s'exécute avant la réplication du
    reste du jeu, retire l'écran de chargement par défaut de Roblox et affiche le logo (ou le titre en texte), la
    phrase d'accueil, une barre de progression RÉELLE et l'étape en cours, sur le fond anthracite animé de la charte.

    Règles :
      - progression fondée sur des attentes observées (LoadingProgress) : aucune fausse barre minutée ;
      - délai maximal (LoadingProgress.Defaults.MaxSeconds) puis filet de sécurité indépendant : l'écran se retire
        quoi qu'il arrive ; toute erreur le retire immédiatement (le jeu n'est jamais bloqué) ;
      - aucun élément interactif : rien ne capte la souris, le tactile ni la manette ; tailles relatives à l'écran
        (téléphone, tablette, PC, télévision) et textes jamais sous 11 px ;
      - « réduire les animations » du système (GuiService.ReducedMotionEnabled) : fond figé, sortie sans fondu ;
      - textes par clé (LoadingTexts), français ou anglais selon la langue du compte Roblox.
    Compatibilité : l'écran passe au-dessus des écrans du jeu (DisplayOrder 10000 ; parcours d'arrivée 15, téléphone
    12, page de démonstration 9000) et sous le calque d'étalonnage des essais (100000). Ces écrans continuent de se
    construire dessous et apparaissent au fondu.
]]

local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Retire tout de suite l'écran par défaut de Roblox : le nôtre le remplace dès la première image.
ReplicatedFirst:RemoveDefaultLoadingScreen()

local Brand = require(script.Parent:WaitForChild("Brand"))
local LoadingTexts = require(script.Parent:WaitForChild("LoadingTexts"))
local LoadingProgress = require(script.Parent:WaitForChild("LoadingProgress"))

local player = Players.LocalPlayer
local language: LoadingTexts.Language = LoadingTexts.languageFor(player.LocaleId)
local colors = Brand.Colors

local function readReducedMotion(): boolean
    local ok, value = pcall(function()
        return (GuiService :: any).ReducedMotionEnabled
    end)
    return ok and value == true
end
local reduceMotion = readReducedMotion()

local screenGui: ScreenGui? = nil
local renderConnection: RBXScriptConnection? = nil
local finished = false

-- Retrait définitif (sans fondu) : appelé en fin de fondu, en cas d'erreur et par le filet de sécurité.
local function destroyNow()
    finished = true
    if renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end
    if screenGui then
        screenGui:Destroy()
        screenGui = nil
    end
end

-- Filet de sécurité indépendant de la boucle : même si elle échoue sans erreur visible, l'écran disparaît.
task.delay(LoadingProgress.Defaults.MaxSeconds + 5, destroyNow)

local function font(weight: Enum.FontWeight): Font
    return Font.fromName(Brand.FontFamily, weight)
end

-- Libellé à taille relative : `TextScaled`, borné entre 11 px (minimum de la charte) et `maxSize`.
local function label(props: { [string]: any }, maxSize: number): TextLabel
    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.TextScaled = true
    text.TextWrapped = true
    for key, value in props do
        (text :: any)[key] = value
    end
    local limit = Instance.new("UITextSizeConstraint")
    limit.MinTextSize = 11
    limit.MaxTextSize = maxSize
    limit.Parent = text
    return text
end

type Ui = {
    Gui: ScreenGui,
    Fill: Frame,
    Phase: TextLabel,
    Title: TextLabel,
    TitleBar: Frame,
    Logo: ImageLabel?,
    Dashes: { { Frame: Frame, Index: number, Count: number, Speed: number } },
}

local function build(): Ui
    local gui = Instance.new("ScreenGui")
    gui.Name = "AWLoadingScreen"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true -- couvre la barre supérieure
    gui.ScreenInsets = Enum.ScreenInsets.None -- couvre aussi l'encoche des téléphones (fond seulement)
    gui.DisplayOrder = 10000
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local background = Instance.new("Frame")
    background.Name = "Fond"
    background.Size = UDim2.fromScale(1, 1)
    background.BorderSizePixel = 0
    background.BackgroundColor3 = colors.BgBase
    background.Active = false
    background.Parent = gui
    -- Dégradé vertical léger : un peu plus clair au centre (comme la zone 3D de la charte).
    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 90
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, colors.BgBase),
        ColorSequenceKeypoint.new(0.45, colors.BgChrome),
        ColorSequenceKeypoint.new(1, colors.BgBase),
    })
    gradient.Parent = background

    -- Lignes de route ambre qui défilent lentement dans le bas de l'écran : plus proches = plus épaisses, plus
    -- rapides et plus visibles (perspective).
    local dashes = {}
    local rows = {
        { Y = 0.80, Thickness = 2, Transparency = 0.9, Speed = 0.02, Count = 8 },
        { Y = 0.87, Thickness = 3, Transparency = 0.85, Speed = 0.035, Count = 7 },
        { Y = 0.95, Thickness = 4, Transparency = 0.8, Speed = 0.05, Count = 6 },
    }
    for _, row in rows do
        for index = 1, row.Count do
            local dash = Instance.new("Frame")
            dash.Name = "Tiret"
            dash.BorderSizePixel = 0
            dash.BackgroundColor3 = colors.Amber
            dash.BackgroundTransparency = row.Transparency
            dash.AnchorPoint = Vector2.new(0, 0.5)
            dash.Size = UDim2.new(0.06, 0, 0, row.Thickness)
            dash.Position = UDim2.fromScale(LoadingProgress.dashX(index, row.Count, 0, row.Speed), row.Y)
            dash.Parent = background
            table.insert(dashes, { Frame = dash, Index = index, Count = row.Count, Speed = row.Speed })
        end
    end

    -- Bloc central : logo (ou titre en texte), au format du logo exporté (4 : 1), 62 % de la largeur au plus.
    local logoBox = Instance.new("Frame")
    logoBox.Name = "Logo"
    logoBox.BackgroundTransparency = 1
    logoBox.AnchorPoint = Vector2.new(0.5, 0.5)
    logoBox.Position = UDim2.fromScale(0.5, 0.4)
    logoBox.Size = UDim2.fromScale(0.62, 0.22)
    logoBox.Parent = background
    local ratio = Instance.new("UIAspectRatioConstraint")
    ratio.AspectRatio = Brand.LogoAspect
    ratio.Parent = logoBox

    -- Repli : le nom en Titillium Web gras, souligné d'un filet ambre (visible tant que l'image n'est pas chargée).
    local title = label({
        Name = "Titre",
        Text = string.upper(Brand.Name),
        FontFace = font(Enum.FontWeight.Bold),
        TextColor3 = colors.Text,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.45),
        Size = UDim2.fromScale(0.9, 0.6),
    }, 140)
    title.Parent = logoBox
    local titleBar = Instance.new("Frame")
    titleBar.Name = "Filet"
    titleBar.BorderSizePixel = 0
    titleBar.BackgroundColor3 = colors.Amber
    titleBar.AnchorPoint = Vector2.new(0.5, 0)
    titleBar.Position = UDim2.fromScale(0.5, 0.82)
    titleBar.Size = UDim2.new(0.32, 0, 0, 4)
    titleBar.Parent = logoBox

    local logo: ImageLabel? = nil
    local content = Brand.logoContent()
    if content then
        local image = Instance.new("ImageLabel")
        image.Name = "Image"
        image.BackgroundTransparency = 1
        image.Size = UDim2.fromScale(1, 1)
        image.ScaleType = Enum.ScaleType.Fit
        image.Image = content
        image.ImageTransparency = 1 -- montrée seulement une fois chargée (jamais de cadre vide)
        image.Parent = logoBox
        logo = image
    end

    local welcome = label({
        Name = "Accueil",
        Text = LoadingTexts.t("loading.welcome", language),
        FontFace = font(Enum.FontWeight.SemiBold),
        TextColor3 = colors.Text,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromScale(0.5, 0.56),
        Size = UDim2.fromScale(0.8, 0.05),
    }, 30)
    welcome.Parent = background

    -- Barre de progression : rail anthracite, remplissage ambre (largeur = fraction réelle lissée).
    local track = Instance.new("Frame")
    track.Name = "Progression"
    track.BorderSizePixel = 0
    track.BackgroundColor3 = colors.Surface2
    track.AnchorPoint = Vector2.new(0.5, 0)
    track.Position = UDim2.fromScale(0.5, 0.66)
    track.Size = UDim2.new(0.36, 0, 0, 6)
    track.Parent = background
    local trackLimit = Instance.new("UISizeConstraint")
    trackLimit.MinSize = Vector2.new(180, 6)
    trackLimit.MaxSize = Vector2.new(640, 6)
    trackLimit.Parent = track
    local fill = Instance.new("Frame")
    fill.Name = "Remplissage"
    fill.BorderSizePixel = 0
    fill.BackgroundColor3 = colors.Amber
    fill.Size = UDim2.fromScale(0, 1)
    fill.Parent = track

    local phase = label({
        Name = "Etape",
        Text = LoadingTexts.t("loading.phase.connect", language),
        FontFace = font(Enum.FontWeight.Regular),
        TextColor3 = colors.TextMuted,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromScale(0.5, 0.69),
        Size = UDim2.fromScale(0.8, 0.035),
    }, 18)
    phase.Parent = background

    gui.Parent = player:WaitForChild("PlayerGui")
    return {
        Gui = gui,
        Fill = fill,
        Phase = phase,
        Title = title,
        TitleBar = titleBar,
        Logo = logo,
        Dashes = dashes,
    }
end

-- Chargement de l'image du logo : bascule du titre texte vers l'image seulement si elle est réellement chargée.
local function loadLogo(ui: Ui)
    local image = ui.Logo
    if image == nil then
        return -- repli : aucune image envoyée, le titre reste en texte
    end
    local state: Brand.ImageState = "Pending"
    local function apply()
        if finished then
            return
        end
        local showImage = Brand.titleMode(state) == "Image"
        image.ImageTransparency = if showImage then 0 else 1
        ui.Title.Visible = not showImage
        ui.TitleBar.Visible = not showImage
    end
    task.spawn(function()
        local ok = pcall(function()
            ContentProvider:PreloadAsync({ image }, function(_, status)
                if state == "Pending" then
                    state = if status == Enum.AssetFetchStatus.Success then "Loaded" else "Failed"
                end
            end)
        end)
        if state == "Pending" then
            state = if ok and image.IsLoaded then "Loaded" else "Failed"
        end
        apply()
    end)
    task.delay(Brand.LogoWaitSeconds, function()
        if state == "Pending" then
            state = "Failed"
            apply()
        end
    end)
end

-- Fondu de sortie de tous les éléments, puis retrait.
local function fadeOut(ui: Ui)
    local seconds = LoadingProgress.fadeSeconds(reduceMotion)
    if seconds <= 0 then
        destroyNow()
        return
    end
    local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    for _, item in ui.Gui:GetDescendants() do
        local goal: { [string]: number } = {}
        if item:IsA("GuiObject") then
            goal.BackgroundTransparency = 1
        end
        if item:IsA("TextLabel") then
            goal.TextTransparency = 1
        elseif item:IsA("ImageLabel") then
            goal.ImageTransparency = 1
        end
        if next(goal) ~= nil then
            TweenService:Create(item, info, goal):Play()
        end
    end
    task.delay(seconds, destroyNow)
end

-- Observations réelles du moment (voir LoadingProgress pour la signification de chaque attente).
local function observe(): LoadingProgress.Signals
    local character = player.Character
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    return {
        GameLoaded = game:IsLoaded(),
        ServerReady = ReplicatedStorage:GetAttribute("AutomotiveWorldReady") == true,
        ClientReady = playerGui ~= nil and playerGui:FindFirstChild("AWHud") ~= nil,
        CharacterReady = character ~= nil and character:FindFirstChild("HumanoidRootPart") ~= nil,
        QueueSize = ContentProvider.RequestQueueSize,
    }
end

local function run()
    local ui = build()
    screenGui = ui.Gui
    loadLogo(ui)
    local state = LoadingProgress.new()
    local clock = 0
    local lastPhase = ""
    renderConnection = RunService.RenderStepped:Connect(function(dt: number)
        local ok, err = pcall(function()
            clock += dt
            LoadingProgress.step(state, observe(), dt)
            ui.Fill.Size = UDim2.fromScale(state.Shown, 1)
            if state.Phase ~= lastPhase then
                lastPhase = state.Phase
                ui.Phase.Text = LoadingTexts.t(state.Phase, language)
            end
            if not reduceMotion then
                for _, dash in ui.Dashes do
                    local y = dash.Frame.Position.Y.Scale
                    dash.Frame.Position =
                        UDim2.fromScale(LoadingProgress.dashX(dash.Index, dash.Count, clock, dash.Speed), y)
                end
            end
            if state.Done then
                if renderConnection then
                    renderConnection:Disconnect()
                    renderConnection = nil
                end
                fadeOut(ui)
            end
        end)
        if not ok then
            warn("[AWLoadingScreen] écran retiré après une erreur : " .. tostring(err))
            destroyNow()
        end
    end)
end

xpcall(run, function(err: any)
    warn("[AWLoadingScreen] écran non affiché après une erreur : " .. tostring(err))
    destroyNow()
end)
