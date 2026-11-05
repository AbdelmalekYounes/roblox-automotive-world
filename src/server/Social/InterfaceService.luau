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
    - Téléphone : modèle provisoire original (pièces simples) dans la main du
      personnage, bras levé par un réglage du Motor6D (aucune animation
      externe) ; l'écran visible des autres reste GÉNÉRIQUE (heure) : le
      contenu des applications n'est affiché que chez son utilisateur.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Preferences = require(Shared:WaitForChild("UI"):WaitForChild("Preferences"))
local InputMap = require(Shared.UI.InputMap)
local WorldLayout = require(Shared:WaitForChild("World"):WaitForChild("WorldLayout"))
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))
local PropertyCatalog = require(Shared:WaitForChild("Garage"):WaitForChild("PropertyCatalog"))

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
local phones: { [Player]: { Model: Model, Shoulder: Motor6D?, Rest: CFrame? } } = {}

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

local function makePhone(): Model
    local model = Instance.new("Model")
    model.Name = "TelephoneAW"
    local body = Instance.new("Part")
    body.Name = "Boitier"
    body.Size = Vector3.new(0.26, 0.52, 0.04) -- ≈ 7 × 15 cm (studs : 0,28 m)
    body.Color = Color3.fromRGB(28, 30, 36)
    body.Material = Enum.Material.SmoothPlastic
    body.CanCollide = false
    body.CanQuery = false
    body.CanTouch = false
    body.Massless = true
    body.Parent = model
    local screen = Instance.new("Part")
    screen.Name = "Ecran"
    screen.Size = Vector3.new(0.23, 0.46, 0.005)
    screen.Color = Color3.fromRGB(40, 80, 140)
    screen.Material = Enum.Material.Neon
    screen.CanCollide = false
    screen.CanQuery = false
    screen.CanTouch = false
    screen.Massless = true
    screen.CFrame = body.CFrame * CFrame.new(0, 0, -0.023)
    screen.Parent = model
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = body
    weld.Part1 = screen
    weld.Parent = body
    -- Écran générique (heure seulement) : le contenu reste privé.
    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.PixelsPerStud = 400
    gui.Parent = screen
    local clock = Instance.new("TextLabel")
    clock.Name = "Heure"
    clock.Size = UDim2.fromScale(1, 0.3)
    clock.Position = UDim2.fromScale(0, 0.1)
    clock.BackgroundTransparency = 1
    clock.TextScaled = true
    clock.Font = Enum.Font.GothamBold
    clock.TextColor3 = Color3.fromRGB(240, 244, 250)
    clock.Text = os.date("!%H:%M") :: string
    clock.Parent = gui
    model.PrimaryPart = body
    return model
end

local function putAway(player: Player)
    local phone = phones[player]
    if phone == nil then
        return
    end
    phones[player] = nil
    if phone.Shoulder and phone.Rest and phone.Shoulder.Parent then
        TweenService:Create(phone.Shoulder, TweenInfo.new(0.2), { C0 = phone.Rest }):Play()
    end
    phone.Model:Destroy()
end

local function takeOut(player: Player): boolean
    if phones[player] then
        return true
    end
    local character = player.Character
    local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
    if hand == nil or not hand:IsA("BasePart") then
        return false
    end
    local model = makePhone()
    local body = model.PrimaryPart :: BasePart
    body.CFrame = hand.CFrame * CFrame.new(0, -0.15, -0.25) * CFrame.Angles(math.rad(-70), 0, 0)
    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") and part ~= body then
            part.CFrame = body.CFrame * CFrame.new(0, 0, -0.023)
        end
    end
    local owner = character :: Model
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = hand
    weld.Part1 = body
    weld.Parent = body
    model.Parent = owner
    -- Bras levé : rotation de l'épaule (R15 ou R6), revenue au rangement.
    local shoulder: Motor6D? = nil
    local upper = owner:FindFirstChild("RightUpperArm")
    local candidate = if upper then upper:FindFirstChild("RightShoulder") else nil
    if candidate == nil then
        local torso = owner:FindFirstChild("Torso")
        candidate = if torso then torso:FindFirstChild("Right Shoulder") else nil
    end
    if candidate and candidate:IsA("Motor6D") then
        shoulder = candidate
    end
    local rest = if shoulder then shoulder.C0 else nil
    if shoulder and rest then
        TweenService:Create(shoulder, TweenInfo.new(0.25), { C0 = rest * CFrame.Angles(math.rad(60), 0, 0) }):Play()
    end
    phones[player] = { Model = model, Shoulder = shoulder, Rest = rest }
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
