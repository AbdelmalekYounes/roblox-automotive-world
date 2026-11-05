--!strict
--[[
    Dessin de carte SIMPLIFIÉ (lot 0.7), commun à la mini-carte et à la carte
    complète : segments routiers (index MapIndex, niveau de détail selon le
    zoom), itinéraire, points d'intérêt, membres du groupe qui partagent leur
    position, joueur.
    - Réserve d'éléments réutilisés : aucun objet créé à chaque image ; les
      éléments en trop sont masqués.
    - Plafond de segments par dessin : jamais des milliers de routes à la fois.
    - Les positions viennent des données de la carte (pas des pièces chargées),
      donc compatibles avec le streaming des secteurs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapProjection = require(Shared:WaitForChild("Navigation"):WaitForChild("MapProjection"))
local MapIndex = require(Shared.Navigation.MapIndex)

local UITheme = require(script.Parent.UITheme)
local Tokens = require(Shared:WaitForChild("UI"):WaitForChild("DesignTokens"))

local MapRenderer = {}
MapRenderer.__index = MapRenderer

export type Marker = { X: number, Z: number, Kind: string, Name: string?, Id: string? }

-- Lot UI-04 (système de conception V1.2 : aucun caractère Unicode ni émoji en guise d'icône) : services en lettres
-- latines (Roboto Mono gras), autres repères en formes DESSINÉES (carré, losange, cercle, anneau, damier).
local ICON: { [string]: string } = {
    Dealership = "$",
    PublicGarage = "G",
    FuelStation = "F",
    ChargingHub = "E",
    CarWash = "W",
}
MapRenderer.Icons = ICON
-- Forme dessinée par type de repère (sans lettre) et jeton de couleur.
local SHAPE: { [string]: { Shape: string, Token: string } } = {
    Property = { Shape = "Square", Token = "Amber" },
    PropertyOffer = { Shape = "Diamond", Token = "AmberSoftText" },
    RaceStart = { Shape = "Checker", Token = "Text" },
    MissionTarget = { Shape = "DiamondFilled", Token = "Amber" },
    SocialSpot = { Shape = "Dot", Token = "TextMuted" },
    PlayerSpawn = { Shape = "Ring", Token = "TextMuted" },
    GroupMember = { Shape = "Dot", Token = "Ok" },
    Destination = { Shape = "Target", Token = "GpsCyan" },
}
MapRenderer.Shapes = SHAPE

type Fields = {
    Root: Frame,
    Lines: { Frame },
    Icons: { TextButton },
    MaxLines: number,
    OnMarker: ((Marker) -> ())?,
    Arrow: Frame,
    Clip: string?,
}

export type Renderer = typeof(setmetatable({} :: Fields, MapRenderer))

-- Flèche de navigation, en pixels autour de son centre (y vers le bas) : pointe, coin droit, échancrure, coin gauche.
local ARROW_SHAPE: { { number } } = { { 0, -9 }, { 7, 8 }, { 0, 3.5 }, { -7, 8 } }
local ARROW_OUTLINE = 1.75 -- épaisseur du contour sombre (px)

-- Polygone agrandi de `d` pixels : chaque sommet glisse le long de la bissectrice (onglet), la pointe reste aiguë.
local function inflatePolygon(points: { { number } }, d: number): { { number } }
    local count = #points
    local area = 0
    for i = 1, count do
        local a, b = points[i], points[i % count + 1]
        area += a[1] * b[2] - b[1] * a[2]
    end
    -- Sens de parcours : il fixe le côté « extérieur » des normales.
    local sign = if area > 0 then 1 else -1
    local function normal(a: { number }, b: { number }): (number, number)
        local dx, dy = b[1] - a[1], b[2] - a[2]
        local length = math.sqrt(dx * dx + dy * dy)
        return sign * dy / length, -sign * dx / length
    end
    local result: { { number } } = {}
    for i = 1, count do
        local previous, current, following = points[(i - 2) % count + 1], points[i], points[i % count + 1]
        local n1x, n1y = normal(previous, current)
        local n2x, n2y = normal(current, following)
        local k = d / (1 + n1x * n2x + n1y * n2y)
        result[i] = { current[1] + (n1x + n2x) * k, current[2] + (n1y + n2y) * k }
    end
    return result
end

-- Remplissage d'un polygone (même concave) par balayage : une bande horizontale de 1 px par ligne, haute de 1,5 px
-- pour que les bandes se chevauchent (aucune couture visible une fois la flèche tournée). Moins de 40 cadres.
local function fillPolygon(parent: Frame, points: { { number } }, color: Color3, z: number)
    local top, bottom = math.huge, -math.huge
    for _, point in points do
        top = math.min(top, point[2])
        bottom = math.max(bottom, point[2])
    end
    local y = math.floor(top)
    while y < bottom do
        local middle = y + 0.5
        local crossings: { number } = {}
        for i = 1, #points do
            local a, b = points[i], points[i % #points + 1]
            if (a[2] <= middle) ~= (b[2] <= middle) then
                table.insert(crossings, a[1] + (middle - a[2]) / (b[2] - a[2]) * (b[1] - a[1]))
            end
        end
        table.sort(crossings)
        for k = 1, #crossings - 1, 2 do
            local left, right = crossings[k], crossings[k + 1]
            if right - left > 0.3 then
                UITheme.make("Frame", {
                    BackgroundColor3 = color,
                    BorderSizePixel = 0,
                    Position = UDim2.new(0.5, left, 0.5, y),
                    Size = UDim2.fromOffset(right - left, 1.5),
                    ZIndex = z,
                }, parent)
            end
        end
        y += 1
    end
end

function MapRenderer.new(root: Frame, maxLines: number, onMarker: ((Marker) -> ())?): Renderer
    root.ClipsDescendants = true
    -- Flèche du joueur : flèche de navigation BLANCHE (pointe, base échancrée) à contour sombre, tournée au cap.
    -- Retour du propriétaire (2026-11-05) : l'ancienne version en bandes de 2 px ressemblait à un « A ».
    local arrow = UITheme.make("Frame", {
        Name = "FlecheJoueur",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(24, 28),
        BackgroundTransparency = 1,
        ZIndex = 7,
    }, root)
    fillPolygon(arrow, inflatePolygon(ARROW_SHAPE, ARROW_OUTLINE), Color3.fromRGB(14, 15, 17), 7) -- contour
    fillPolygon(arrow, ARROW_SHAPE, Color3.fromRGB(255, 255, 255), 8) -- flèche blanche
    return setmetatable(
        { Root = root, Lines = {}, Icons = {}, MaxLines = maxLines, OnMarker = onMarker, Arrow = arrow },
        MapRenderer
    )
end

local styleMarker: (TextButton, string) -> ()

local function line(self: Renderer, index: number): Frame
    local item: Frame? = self.Lines[index]
    if item == nil then
        item =
            UITheme.make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, ZIndex = 2 }, self.Root)
        self.Lines[index] = item :: Frame
    end
    return item :: Frame
end

local function icon(self: Renderer, index: number): TextButton
    local item: TextButton? = self.Icons[index]
    if item == nil then
        item = UITheme.make("TextButton", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(20, 20),
            BackgroundTransparency = 0.2,
            AutoButtonColor = true,
            ZIndex = 4,
            Font = UITheme.FontBold,
            TextSize = 13,
        }, self.Root)
        local created = item :: TextButton
        created.FontFace = UITheme.face("Value")
        created.FontFace = Font.new(created.FontFace.Family, Enum.FontWeight.Bold)
        created.TextSize = 12
        UITheme.make("UICorner", { CornerRadius = UDim.new(1, 0) }, created)
        local edge = UITheme.make("UIStroke", {
            Name = "Contour",
            Color = Tokens.color("Line"),
            Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, created)
        edge.Enabled = true
        -- Forme dessinée (carré, losange, cercle, anneau, cible, damier) : configurée à chaque dessin.
        local shape = UITheme.make("Frame", {
            Name = "Forme",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(10, 10),
            BorderSizePixel = 0,
            ZIndex = 5,
            Visible = false,
        }, created)
        UITheme.make("UICorner", { Name = "Coins", CornerRadius = UDim.new(0, 0) }, shape)
        UITheme.make("UIStroke", { Name = "Trait", Thickness = 2, Enabled = false }, shape)
        for cell = 1, 4 do
            UITheme.make("Frame", {
                Name = "Case" .. cell,
                BorderSizePixel = 0,
                Size = UDim2.fromScale(0.5, 0.5),
                Position = UDim2.fromScale(((cell - 1) % 2) * 0.5, math.floor((cell - 1) / 2) * 0.5),
                ZIndex = 6,
                Visible = false,
            }, shape)
        end
        created.Activated:Connect(function()
            local marker = created:GetAttribute("MarkerIndex")
            local data = (self :: any).CurrentMarkers and (self :: any).CurrentMarkers[marker]
            if data and self.OnMarker then
                (self.OnMarker :: (Marker) -> ())(data)
            end
        end)
        self.Icons[index] = item :: TextButton
    end
    return item :: TextButton
end

local function drawSegment(
    self: Renderer,
    view: MapProjection.View,
    n: number,
    ax: number,
    az: number,
    bx: number,
    bz: number,
    color: Color3,
    thickness: number,
    z: number?
): number
    local a1, b1 = MapProjection.toMap(view, ax, az)
    local a2, b2 = MapProjection.toMap(view, bx, bz)
    local u1, v1, u2, v2
    if self.Clip == "Circle" then
        u1, v1, u2, v2 = MapProjection.clipCircle(view, a1, b1, a2, b2, math.min(view.Width, view.Height) / 2 - 2)
    else
        u1, v1, u2, v2 = MapProjection.clipRect(view, a1, b1, a2, b2, 0)
    end
    if u1 == nil or v1 == nil or u2 == nil or v2 == nil then
        return n
    end
    local du, dv = u2 - u1, v2 - v1
    local length = math.sqrt(du * du + dv * dv)
    if length < 1 then
        return n
    end
    n += 1
    local item = line(self, n)
    item.Visible = true
    item.BackgroundColor3 = color
    item.Position = UDim2.fromOffset((u1 + u2) / 2, (v1 + v2) / 2)
    item.Size = UDim2.fromOffset(length, thickness)
    item.Rotation = math.deg(math.atan2(dv, du))
    item.ZIndex = z or (if thickness > 3 then 3 else 2)
    return n
end

-- Habillage d'un repère : lettre (services) ou forme dessinée ; fond sombre, contour discret.
function styleMarker(item: TextButton, kind: string)
    local letter = ICON[kind]
    local spec = SHAPE[kind]
    local shape = item:FindFirstChild("Forme") :: Frame
    local coins = shape:FindFirstChild("Coins") :: UICorner
    local trait = shape:FindFirstChild("Trait") :: UIStroke
    item.BackgroundColor3 = Tokens.color("BgBase")
    item.BackgroundTransparency = 0.15
    item.TextColor3 = Tokens.color("Text")
    item.Text = letter or ""
    shape.Visible = spec ~= nil
    for index = 1, 4 do
        (shape:FindFirstChild("Case" .. index) :: Frame).Visible = false
    end
    if spec == nil then
        if letter == nil then
            -- Type inconnu : simple point discret.
            shape.Visible = true
            shape.Size = UDim2.fromOffset(6, 6)
            shape.Rotation = 0
            shape.BackgroundTransparency = 0
            shape.BackgroundColor3 = Tokens.color("TextMuted")
            coins.CornerRadius = UDim.new(1, 0)
            trait.Enabled = false
        end
        return
    end
    local color = Tokens.color(spec.Token)
    shape.Rotation = 0
    shape.BackgroundColor3 = color
    shape.BackgroundTransparency = 0
    trait.Enabled = false
    trait.Color = color
    coins.CornerRadius = UDim.new(0, 0)
    if spec.Shape == "Square" then
        shape.Size = UDim2.fromOffset(9, 9)
        shape.BackgroundTransparency = 1
        trait.Enabled = true
    elseif spec.Shape == "Diamond" then
        shape.Size = UDim2.fromOffset(8, 8)
        shape.Rotation = 45
        shape.BackgroundTransparency = 1
        trait.Enabled = true
    elseif spec.Shape == "DiamondFilled" then
        shape.Size = UDim2.fromOffset(9, 9)
        shape.Rotation = 45
    elseif spec.Shape == "Dot" then
        shape.Size = UDim2.fromOffset(9, 9)
        coins.CornerRadius = UDim.new(1, 0)
    elseif spec.Shape == "Ring" then
        shape.Size = UDim2.fromOffset(9, 9)
        shape.BackgroundTransparency = 1
        coins.CornerRadius = UDim.new(1, 0)
        trait.Enabled = true
    elseif spec.Shape == "Target" then
        shape.Size = UDim2.fromOffset(11, 11)
        shape.BackgroundTransparency = 0.6
        coins.CornerRadius = UDim.new(1, 0)
        trait.Enabled = true
    elseif spec.Shape == "Checker" then
        -- Damier de départ de course (2 × 2 cases claires et sombres).
        shape.Size = UDim2.fromOffset(10, 10)
        shape.BackgroundTransparency = 1
        for index = 1, 4 do
            local case = shape:FindFirstChild("Case" .. index) :: Frame
            case.Visible = true
            case.BackgroundColor3 = if index == 1 or index == 4 then Tokens.color("Text") else Tokens.color("BgBase")
        end
    end
end

export type Scene = {
    View: MapProjection.View,
    Index: MapIndex.Index?,
    Route: { { X: number, Z: number } }?,
    Markers: { Marker },
    PlayerHeading: number,
    PlayerX: number,
    PlayerZ: number,
    ClampMarkers: boolean, -- objectifs hors vue ramenés au bord (mini-carte)
    Clip: string?, -- « Circle » (mini-carte ronde) ou « Rect » (par défaut)
    ShowNorth: boolean?, -- repère « N » sur le bord (mini-carte)
}

function MapRenderer.draw(self: Renderer, scene: Scene)
    local view = scene.View
    self.Clip = scene.Clip or "Rect"
    local n = 0
    local index = scene.Index
    if index then
        local minX, minZ, maxX, maxZ = MapProjection.bounds(view)
        local span = math.max(maxX - minX, maxZ - minZ)
        local segments =
            MapIndex.query(index :: MapIndex.Index, minX, minZ, maxX, maxZ, MapIndex.minImportanceFor(span))
        -- Hiérarchie lisible : routes principales plus claires et plus larges, secondaires discrètes.
        local road, major = Color3.fromRGB(58, 62, 69), Color3.fromRGB(104, 109, 117)
        for _, segment in segments do
            if n >= self.MaxLines then
                break
            end
            local thick = if segment.Importance >= 5 then 4 elseif segment.Importance >= 3 then 2.5 else 1.5
            n = drawSegment(
                self,
                view,
                n,
                segment.AX,
                segment.AZ,
                segment.BX,
                segment.BZ,
                if segment.Importance >= 5 then major else road,
                thick
            )
        end
    end
    local route = scene.Route
    if route then
        -- Itinéraire cyan bordé de sombre (lisible sur les routes claires).
        local color = Tokens.color("GpsCyan")
        local casing = Color3.fromRGB(14, 15, 17)
        local step = math.max(1, math.floor(#route / 300))
        local i = 1
        while i < #route and n < self.MaxLines + 600 do
            local j = math.min(i + step, #route)
            n = drawSegment(self, view, n, route[i].X, route[i].Z, route[j].X, route[j].Z, casing, 7, 3)
            n = drawSegment(self, view, n, route[i].X, route[i].Z, route[j].X, route[j].Z, color, 4, 4)
            i = j
        end
    end
    for k = n + 1, #self.Lines do
        self.Lines[k].Visible = false
    end
    -- Marqueurs.
    local count = 0;
    (self :: any).CurrentMarkers = scene.Markers
    for markerIndex, marker in scene.Markers do
        local u, v = MapProjection.toMap(view, marker.X, marker.Z)
        local inside = MapProjection.inside(view, u, v, -6)
        if inside and self.Clip == "Circle" then
            local cx, cy = view.Width / 2, view.Height / 2
            inside = (u - cx) ^ 2 + (v - cy) ^ 2 <= (math.min(cx, cy) - 8) ^ 2
        end
        if not inside then
            if
                scene.ClampMarkers
                and (marker.Kind == "MissionTarget" or marker.Kind == "Destination" or marker.Kind == "GroupMember")
            then
                if self.Clip == "Circle" then
                    u, v = MapProjection.clampToCircle(view, u, v, 12)
                else
                    u, v = MapProjection.clampToEdge(view, u, v, 12)
                end
            else
                continue
            end
        end
        count += 1
        local item = icon(self, count)
        item.Visible = true
        item:SetAttribute("MarkerIndex", markerIndex)
        item.Position = UDim2.fromOffset(u, v)
        styleMarker(item, marker.Kind)
        item.Selectable = self.OnMarker ~= nil
    end
    for k = count + 1, #self.Icons do
        self.Icons[k].Visible = false
    end
    if scene.ShowNorth then
        local north = (self :: any).North :: TextLabel?
        if north == nil then
            local created = UITheme.make("TextLabel", {
                Name = "Nord",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Size = UDim2.fromOffset(16, 16),
                BackgroundColor3 = Color3.fromRGB(14, 15, 17),
                BackgroundTransparency = 0,
                Text = "N",
                TextColor3 = Tokens.color("Text"),
                ZIndex = 9,
            }, self.Root)
            created.FontFace = Font.new(UITheme.face("Value").Family, Enum.FontWeight.Bold)
            created.TextSize = 11
            UITheme.make("UICorner", { CornerRadius = UDim.new(1, 0) }, created);
            (self :: any).North = created
            north = created
        end
        local cx, cy = view.Width / 2, view.Height / 2
        local radius = math.min(cx, cy) - 10
        -- Nord du monde (−Z) vu dans la vue tournée de -Rotation.
        local angle = -view.Rotation;
        (north :: TextLabel).Position = UDim2.fromOffset(cx + math.sin(angle) * radius, cy - math.cos(angle) * radius)
    end
    -- Joueur : flèche au centre (mini-carte tournante) ou à sa position.
    local pu, pv = MapProjection.toMap(view, scene.PlayerX, scene.PlayerZ)
    self.Arrow.Position = UDim2.fromOffset(pu, pv)
    self.Arrow.Rotation = math.deg(scene.PlayerHeading - view.Rotation)
    self.Arrow.Visible = MapProjection.inside(view, pu, pv, 0)
end

-- Échantillon fixe d'un repère (légende) : même dessin que sur la carte, sans action.
function MapRenderer.sample(parent: Instance, kind: string): TextButton
    local fake = setmetatable(
        { Root = parent, Lines = {}, Icons = {}, MaxLines = 0, OnMarker = nil, Arrow = nil :: any },
        MapRenderer
    ) :: any
    local item = icon(fake, 1)
    styleMarker(item, kind)
    item.Active = false
    item.Selectable = false
    item.AnchorPoint = Vector2.zero
    item.Position = UDim2.new()
    return item
end

return MapRenderer
