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

local MapRenderer = {}
MapRenderer.__index = MapRenderer

export type Marker = { X: number, Z: number, Kind: string, Name: string?, Id: string? }

local ICON: { [string]: string } = {
    Dealership = "$",
    PublicGarage = "G",
    FuelStation = "F",
    ChargingHub = "⚡",
    CarWash = "W",
    Property = "⌂",
    PropertyOffer = "◇",
    RaceStart = "🏁",
    MissionTarget = "★",
    SocialSpot = "●",
    PlayerSpawn = "○",
    GroupMember = "▲",
    Destination = "✚",
}
MapRenderer.Icons = ICON

type Fields = {
    Root: Frame,
    Lines: { Frame },
    Icons: { TextButton },
    MaxLines: number,
    OnMarker: ((Marker) -> ())?,
    Arrow: TextLabel,
}

export type Renderer = typeof(setmetatable({} :: Fields, MapRenderer))

function MapRenderer.new(root: Frame, maxLines: number, onMarker: ((Marker) -> ())?): Renderer
    root.ClipsDescendants = true
    local arrow = UITheme.label("▲", 20, {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(22, 22),
        ZIndex = 5,
        Font = UITheme.FontBold,
        TextColor3 = UITheme.color("Accent"),
    }, root)
    return setmetatable(
        { Root = root, Lines = {}, Icons = {}, MaxLines = maxLines, OnMarker = onMarker, Arrow = arrow },
        MapRenderer
    )
end

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
        UITheme.make("UICorner", { CornerRadius = UDim.new(1, 0) }, created)
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
    thickness: number
): number
    local u1, v1 = MapProjection.toMap(view, ax, az)
    local u2, v2 = MapProjection.toMap(view, bx, bz)
    if not MapProjection.inside(view, u1, v1, 40) and not MapProjection.inside(view, u2, v2, 40) then
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
    item.Size = UDim2.fromOffset(length + thickness * 0.6, thickness)
    item.Rotation = math.deg(math.atan2(dv, du))
    item.ZIndex = if thickness > 3 then 3 else 2
    return n
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
}

function MapRenderer.draw(self: Renderer, scene: Scene)
    local view = scene.View
    local n = 0
    local index = scene.Index
    if index then
        local minX, minZ, maxX, maxZ = MapProjection.bounds(view)
        local span = math.max(maxX - minX, maxZ - minZ)
        local segments =
            MapIndex.query(index :: MapIndex.Index, minX, minZ, maxX, maxZ, MapIndex.minImportanceFor(span))
        local road, major = UITheme.color("Road"), UITheme.color("RoadMajor")
        for _, segment in segments do
            if n >= self.MaxLines then
                break
            end
            local thick = if segment.Importance >= 5 then 3 elseif segment.Importance >= 3 then 2 else 1.5
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
        local color = UITheme.color("Route")
        local step = math.max(1, math.floor(#route / 400))
        local i = 1
        while i < #route and n < self.MaxLines + 400 do
            local j = math.min(i + step, #route)
            n = drawSegment(self, view, n, route[i].X, route[i].Z, route[j].X, route[j].Z, color, 4)
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
        if not inside then
            if
                scene.ClampMarkers
                and (marker.Kind == "MissionTarget" or marker.Kind == "Destination" or marker.Kind == "GroupMember")
            then
                u, v = MapProjection.clampToEdge(view, u, v, 12)
            else
                continue
            end
        end
        count += 1
        local item = icon(self, count)
        item.Visible = true
        item:SetAttribute("MarkerIndex", markerIndex)
        item.Position = UDim2.fromOffset(u, v)
        item.Text = ICON[marker.Kind] or "•"
        item.BackgroundColor3 = if marker.Kind == "MissionTarget" or marker.Kind == "Destination"
            then UITheme.color("Accent")
            elseif marker.Kind == "GroupMember" then UITheme.color("Good")
            else UITheme.color("PanelRaised")
        item.TextColor3 = UITheme.color("Text")
        item.Selectable = self.OnMarker ~= nil
    end
    for k = count + 1, #self.Icons do
        self.Icons[k].Visible = false
    end
    -- Joueur : flèche au centre (mini-carte tournante) ou à sa position.
    local pu, pv = MapProjection.toMap(view, scene.PlayerX, scene.PlayerZ)
    self.Arrow.Position = UDim2.fromOffset(pu, pv)
    self.Arrow.Rotation = math.deg(scene.PlayerHeading - view.Rotation)
    self.Arrow.Visible = MapProjection.inside(view, pu, pv, 0)
end

return MapRenderer
