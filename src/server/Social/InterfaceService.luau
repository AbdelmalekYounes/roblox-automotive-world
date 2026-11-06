--!strict
--[[
    Service d'interface (lot 0.7) : préférences sauvegardées, annuaire des
    points d'intérêt du GPS et téléphone tenu en main (canal AWInterface).

    - Préférences : nettoyées par le serveur (Shared/UI/Preferences), au plus
      un envoi accepté toutes les 5 s ; une modification marque seulement le
      profil « à sauvegarder » (mutation non sensible) : l'écriture suit la
      sauvegarde périodique et les verrous existants, jamais une écriture par
      changement visuel.
    - Annuaire : points publics issus des registres existants (lieux,
      parcours, carte) et points PERSONNELS du demandeur seulement (ses
      propriétés, l'objectif de sa mission). Jamais ceux d'un autre joueur.
    - Téléphone (lot PHONE-01) : modèle original en pièces simples soudé à la
      main droite (prise en main de Shared/UI/PhoneHold), attribut
      `AWPhoneRaised` du personnage : chaque client lève le bras (épaule et
      coude, PhoneHoldController) sans animation externe. L'écran visible des
      autres reste GÉNÉRIQUE (fond et heure) : le contenu des applications
      n'est affiché que chez son utilisateur, sur l'écran tenu en main.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Preferences = require(Shared:WaitForChild("UI"):WaitForChild("Preferences"))
local InputMap = require(Shared.UI.InputMap)
local WorldLayout = require(Shared:WaitForChild("World"):WaitForChild("WorldLayout"))
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))
local PropertyCatalog = require(Shared:WaitForChild("Garage"):WaitForChild("PropertyCatalog"))
local PhoneHold = require(Shared:WaitForChild("UI"):WaitForChild("PhoneHold"))

local Persistence = script.Parent.Parent.Persistence
local ProfileService = require(Persistence.ProfileService)
local RateLimiter = require(script.Parent.Parent.Security.RateLimiter)
local Locations = require(script.Parent.Parent.Progression.Locations)
local MissionService = require(script.Parent.Parent.Economy.MissionService)
local RaceService = require(script.Parent.Parent.Racing.RaceService)
local PointsOfInterest = require(script.Parent.PointsOfInterest)

local InterfaceService = {}

local S = 1 / Constants.MetersPerStud
local FOLDER = "AWInterface"

local started = false
local push: RemoteEvent
local limiters: { [Player]: RateLimiter.Bucket } = {}
local lastSave: { [Player]: number } = {}
local publicPoints: { PointsOfInterest.Point } = {}
-- Téléphone sorti par joueur (lot PHONE-01 : modèle et prise en main de Shared/UI/PhoneHold).
local phones: { [Player]: Model } = {}

local function rejected(key: string): any
    return { Status = "Rejected", Error = key }
end

local function placeInput(place: Locations.Place): PointsOfInterest.PlaceInput
    local p = place.Frame.Position
    return { Id = place.Id, Kind = place.Kind, Label = place.Label, X = p.X / S, Z = p.Z / S }
end

local function buildPublic(openWorld: boolean)
    local places = {}
    for _, place in Locations.all() do
        table.insert(places, placeInput(place))
    end
    local races = {}
    for id, built in RaceService.state().Courses do
        table.insert(races, { Id = id, Name = built.Course.Name, X = built.Registration.X, Z = built.Registration.Z })
    end
    local placements = {}
    if openWorld then
        for _, placement in WorldLayout.get().Placements do
            table.insert(placements, {
                Id = placement.Id,
                Kind = placement.Kind,
                Name = placement.Name,
                X = placement.Center.X,
                Z = placement.Center.Z,
            })
        end
    end
    publicPoints = PointsOfInterest.public(places, races, placements)
    local errors = PointsOfInterest.validate(publicPoints)
    if #errors > 0 then
        warn("[AutomotiveWorld] Points d'intérêt incohérents : " .. table.concat(errors, " ; "))
    end
end

local function personalPoints(player: Player): { PointsOfInterest.Point }
    local session = ProfileService.get(player)
    local profile = if session then session.Data else nil
    local properties = {}
    if profile then
        for id, property in profile.Properties do
            local offer = PropertyCatalog.offer(property.OfferId)
            table.insert(properties, { Id = id, OfferId = property.OfferId, Name = if offer then offer.Label else id })
        end
    end
    local mission = MissionService.snapshot(player)
    local target = if mission and mission.Point
        then { Label = mission.Label, X = mission.Point.X, Z = mission.Point.Z }
        else nil
    return PointsOfInterest.personal(properties, function(offerId: string): PointsOfInterest.PlaceInput?
        local offer = PropertyCatalog.offer(offerId)
        local place = if offer then Locations.get(Locations.resolve(offer.Entrance)) else nil
        return if place then placeInput(place) else nil
    end, target)
end

-- ======================== Téléphone ========================

-- Lot PHONE-01 : modèle original en pièces simples (aucun actif importé, aucune marque) aux cotes de
-- Shared/UI/PhoneHold : boîtier aux coins arrondis (deux pavés et quatre cylindres), vitre noire, dalle
-- avec un écran GÉNÉRIQUE (fond et heure, le contenu des applications n'est jamais affiché ici), bloc
-- photo au dos et touches latérales. Pièces sans masse, sans collision ni ombre.
local GRAPHITE = Color3.fromRGB(58, 62, 69)
local GLASS = Color3.fromRGB(6, 7, 8)

local function phonePart(model: Model, name: string, size: Vector3, offset: CFrame, color: Color3): Part
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.CFrame = offset
    part.Color = color
    part.Material = Enum.Material.SmoothPlastic
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Massless = true
    part.Parent = model
    return part
end

-- Cylindre dont l'axe suit Z (épaisseur du téléphone) : l'axe d'un cylindre Roblox est X.
local function alongZ(x: number, y: number, z: number): CFrame
    return CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(90), 0)
end

local function genericScreen(screen: BasePart)
    local gui = Instance.new("SurfaceGui")
    gui.Name = "EcranGenerique"
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 400
    gui.LightInfluence = 0
    gui.Parent = screen
    local wallpaper = Instance.new("Frame")
    wallpaper.Name = "Fond"
    wallpaper.Size = UDim2.fromScale(1, 1)
    wallpaper.BorderSizePixel = 0
    wallpaper.BackgroundColor3 = Color3.new(1, 1, 1)
    wallpaper.Parent = gui
    -- Même fond que l'écran d'accueil de l'interface (dégradé bleu nuit, lueur ambre en bas).
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 37, 49)),
        ColorSequenceKeypoint.new(0.7, Color3.fromRGB(14, 15, 18)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(34, 26, 16)),
    })
    gradient.Rotation = 90
    gradient.Parent = wallpaper
    local clock = Instance.new("TextLabel")
    clock.Name = "Heure"
    clock.Size = UDim2.fromScale(1, 0.12)
    clock.Position = UDim2.fromScale(0, 0.12)
    clock.BackgroundTransparency = 1
    clock.TextScaled = true
    clock.Font = Enum.Font.GothamBold
    clock.TextColor3 = Color3.fromRGB(240, 244, 250)
    clock.Text = os.date("!%H:%M") :: string
    clock.Parent = wallpaper
end

local function makePhone(): Model
    local model = Instance.new("Model")
    model.Name = PhoneHold.ModelName
    local b = PhoneHold.Body
    local sc = PhoneHold.Screen
    local r = b.Corner
    -- Construit autour de l'origine (boîtier centré, écran vers −Z), puis soudé à la main.
    local body = phonePart(
        model,
        PhoneHold.BodyName,
        Vector3.new(b.Width - 2 * r, b.Height, b.Thickness),
        CFrame.identity,
        GRAPHITE
    )
    body.Material = Enum.Material.Metal
    local pieces: { BasePart } = {}
    local side =
        phonePart(model, "Flanc", Vector3.new(b.Width, b.Height - 2 * r, b.Thickness), CFrame.identity, GRAPHITE)
    side.Material = Enum.Material.Metal
    table.insert(pieces, side)
    for _, corner in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
        local cylinder = phonePart(
            model,
            "Coin",
            Vector3.new(b.Thickness, 2 * r, 2 * r),
            alongZ(corner[1] * (b.Width / 2 - r), corner[2] * (b.Height / 2 - r), 0),
            GRAPHITE
        )
        cylinder.Shape = Enum.PartType.Cylinder
        cylinder.Material = Enum.Material.Metal
        table.insert(pieces, cylinder)
    end
    -- Vitre noire à 6 mm du bord, coins arrondis comme le boîtier (deux pavés et quatre disques), puis
    -- dalle de l'écran posée dessus.
    local front = -b.Thickness / 2
    local edge = 0.006
    local glassRadius = r - edge
    for _, size in
        {
            Vector3.new(b.Width - 2 * edge, b.Height - 2 * r, 0.002),
            Vector3.new(b.Width - 2 * r, b.Height - 2 * edge, 0.002),
        }
    do
        table.insert(pieces, phonePart(model, "Vitre", size, CFrame.new(0, 0, front - 0.001), GLASS))
    end
    for _, corner in { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } } do
        local disc = phonePart(
            model,
            "Vitre",
            Vector3.new(0.002, 2 * glassRadius, 2 * glassRadius),
            alongZ(corner[1] * (b.Width / 2 - r), corner[2] * (b.Height / 2 - r), front - 0.001),
            GLASS
        )
        disc.Shape = Enum.PartType.Cylinder
        table.insert(pieces, disc)
    end
    local screen = phonePart(
        model,
        PhoneHold.ScreenName,
        Vector3.new(sc.Width, sc.Height, sc.Depth),
        CFrame.new(0, 0, front - 0.002 - sc.Depth / 2),
        Color3.fromRGB(14, 15, 18)
    )
    table.insert(pieces, screen)
    genericScreen(screen)
    -- Bloc photo au dos (coin supérieur, côté gauche vu de dos) et son objectif.
    local back = b.Thickness / 2
    local corner = Vector2.new(b.Width / 2 - 0.06, b.Height / 2 - 0.06)
    table.insert(
        pieces,
        phonePart(
            model,
            "BlocPhoto",
            Vector3.new(0.075, 0.075, 0.008),
            CFrame.new(corner.X, corner.Y, back + 0.004),
            Color3.fromRGB(44, 47, 53)
        )
    )
    local lens =
        phonePart(model, "Objectif", Vector3.new(0.006, 0.034, 0.034), alongZ(corner.X, corner.Y, back + 0.011), GLASS)
    lens.Shape = Enum.PartType.Cylinder
    table.insert(pieces, lens)
    -- Touches latérales : marche d'un côté, volume de l'autre.
    for _, key in { { 1, 0.1, 0.07 }, { -1, 0.12, 0.1 } } do
        table.insert(
            pieces,
            phonePart(
                model,
                "Touche",
                Vector3.new(0.006, key[3], 0.012),
                CFrame.new(key[1] * (b.Width / 2 + 0.002), key[2], 0),
                GRAPHITE
            )
        )
    end
    for _, piece in pieces do
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = body
        weld.Part1 = piece
        weld.Parent = piece
    end
    model.PrimaryPart = body
    return model
end

local function putAway(player: Player)
    local phone: Model? = phones[player]
    if phone == nil then
        return
    end
    phones[player] = nil
    local character = phone.Parent
    if character then
        character:SetAttribute(PhoneHold.Attribute, nil)
    end
    phone:Destroy()
end

local function takeOut(player: Player): boolean
    if phones[player] then
        return true
    end
    local character = player.Character
    local hand = character and character:FindFirstChild("RightHand")
    if hand == nil or not hand:IsA("BasePart") then
        return false
    end
    local owner = character :: Model
    local model = makePhone()
    local body = model.PrimaryPart :: BasePart
    -- Posé d'abord dans la main (le modèle est construit à l'origine du monde) : aucune image où il serait loin.
    model:PivotTo(hand.CFrame * PhoneHold.gripCFrame())
    -- Prise en main (PhoneHold.Grip) : soudure à décalage fixe ; le modèle suit la main sur chaque client.
    local weld = Instance.new("Weld")
    weld.Name = "PriseEnMain"
    weld.Part0 = hand
    weld.Part1 = body
    weld.C0 = PhoneHold.gripCFrame()
    weld.Parent = body
    model.Parent = owner
    -- Bras levé : attribut lu par chaque client (PhoneHoldController : épaule et coude dans `Transform` après
    -- l'animation, Motor6D comme AnimationConstraint, QA-A10) ; la pose assise laisse alors les bras.
    -- L'ancien réglage C0 du Motor6D (lot 0.7) est retiré : il se serait ajouté à la pose du client.
    owner:SetAttribute(PhoneHold.Attribute, true)
    phones[player] = model
    return true
end

-- ======================== Requêtes ========================

local handlers: { [string]: (Player, any) -> any } = {}

handlers.Preferences = function(player)
    local session = ProfileService.get(player)
    local prefs = if session and session.Data then session.Data.Preferences else Preferences.defaults()
    return { Status = "Ok", Result = Preferences.sanitize(prefs, InputMap.actions()) }
end

handlers.SavePreferences = function(player, payload)
    local session = ProfileService.get(player)
    if session == nil or session.State ~= "Active" then
        return { Status = "Unavailable", Error = "ProfileUnavailable" }
    end
    local now = os.clock()
    if lastSave[player] and now - (lastSave[player] :: number) < Preferences.SendIntervalS - 0.5 then
        return rejected("RateLimited")
    end
    lastSave[player] = now
    local clean = Preferences.sanitize(if type(payload) == "table" then payload.Prefs else nil, InputMap.actions())
    for action, key in clean.Bindings do
        local ok = InputMap.validate(clean.Bindings, action, key)
        if not ok then
            clean.Bindings[action] = nil
        end
    end
    local changed = session:mutate(function(profile)
        if Preferences.equal(profile.Preferences, clean) then
            return false
        end
        profile.Preferences = clean
        return true
    end)
    return { Status = "Ok", Result = { Changed = changed } }
end

handlers.Directory = function(player)
    local list = table.clone(publicPoints)
    for _, point in personalPoints(player) do
        table.insert(list, point)
    end
    return { Status = "Ok", Result = list }
end

handlers.Phone = function(player, payload)
    local out = type(payload) == "table" and payload.Out == true
    if out then
        return { Status = if takeOut(player) then "Ok" else "Rejected" }
    end
    putAway(player)
    return { Status = "Ok" }
end

local function handle(player: Player, action: any, payload: any): any
    if type(action) ~= "string" or handlers[action] == nil then
        return rejected("ActionUnknown")
    end
    local bucket = limiters[player]
    if bucket == nil then
        bucket = RateLimiter.new(8, 3, os.clock())
        limiters[player] = bucket
    end
    if not RateLimiter.consume(bucket, os.clock()) then
        return rejected("RateLimited")
    end
    local ok, response = pcall(handlers[action], player, payload)
    if not ok then
        ProfileService.Log:write("Error", "InterfaceHandlerFailed", { Action = action, Error = tostring(response) })
        return rejected("ServerError")
    end
    return response
end

function InterfaceService.start(openWorld: boolean)
    assert(not started, "InterfaceService déjà démarré")
    started = true
    buildPublic(openWorld)
    local existing = ReplicatedStorage:FindFirstChild(FOLDER)
    if existing then
        existing:Destroy()
    end
    local folder = Instance.new("Folder")
    folder.Name = FOLDER
    local request = Instance.new("RemoteFunction")
    request.Name = "Request"
    request.Parent = folder
    push = Instance.new("RemoteEvent")
    push.Name = "Push"
    push.Parent = folder
    folder.Parent = ReplicatedStorage
    request.OnServerInvoke = function(player: Player, action: any, payload: any): any
        return handle(player, action, payload)
    end
    -- Préférences poussées dès le chargement (langue, HUD) : aucune réouverture de session.
    ProfileService.onLoaded(function(player, session)
        local prefs = if session.Data then session.Data.Preferences else nil
        push:FireClient(player, "Preferences", Preferences.sanitize(prefs, InputMap.actions()))
        -- Critique : session perdue ou lecture seule (opérations sensibles concernées).
    end)
    Players.PlayerRemoving:Connect(function(player)
        putAway(player)
        limiters[player] = nil
        lastSave[player] = nil
    end)
    Players.PlayerAdded:Connect(function(player)
        player.CharacterRemoving:Connect(function()
            phones[player] = nil
        end)
    end)
end

-- Points publics (essais Studio).
function InterfaceService.publicPoints(): { PointsOfInterest.Point }
    return publicPoints
end

return table.freeze(InterfaceService)
