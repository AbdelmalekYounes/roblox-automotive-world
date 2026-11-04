-- Essais SERVEUR du lot AVATAR-01 (place de développement), injectés par le pilote dans
-- le Studio de test uniquement.
--   « avatar »  (1 joueur, vraies entrées dans la VM) : réglage R15 constaté, morphologies
--               R15 (échelles de la HumanoidDescription + accessoires d'essai fabriqués par
--               le test), assise conducteur et passager dans un échantillon de véhicules
--               puis dans les 18 modèles, sortie, tenues (restauration, identifiants
--               invalides, refus assis, demandes du client).
--   « avatar2 » (2 joueurs) : bras levé et téléphone du joueur 1 vus par le joueur 2.
-- Instrumenté (signalé) : morphologies appliquées par le serveur de test ; véhicules
-- temporaires protégés (même chemin que les essais des métiers : aucune écriture durable) ;
-- personnage assis par `Seat:Sit` (comme l'invite) ; le joueur est reposé sur la bande
-- d'essai entre deux véhicules. Accessoires d'essai : pièces simples créées par le test
-- (aucun actif Roblox). Profils en MÉMOIRE : aucun DataStore.
-- Mesures géométriques dans le repère du véhicule (studs) ; journal machine
-- « @@AWAVATAR@@ {json} » pour les tableaux du rapport.

local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local StudioTestService = game:GetService("StudioTestService")
local Workspace = game:GetService("Workspace")

local args = StudioTestService:GetTestArgs()
local session = if type(args) == "table" and type(args.Session) == "string" then args.Session else ""
if session ~= "avatar" and session ~= "avatar2" then
    return
end

local steps = {}
local function record(name: string, ok: boolean, detail: any)
    table.insert(steps, { name = name, ok = ok, detail = if detail ~= nil then tostring(detail) else nil })
end
local sessionStart = os.clock()
local function trace(message: string)
    print(string.format("[AW_Test] %s %.1f s : %s", session, os.clock() - sessionStart, message))
end
local function emitData(kind: string, data: { [string]: any })
    data.kind = kind
    print("@@AWAVATAR@@ " .. HttpService:JSONEncode(data))
end

local errors, robloxErrors, validation, warnings = {}, {}, {}, {}
LogService.MessageOut:Connect(function(message, messageType)
    if messageType == Enum.MessageType.MessageError then
        local ours = string.find(message, "AutomotiveWorld", 1, true)
            or string.find(message, "ReplicatedStorage.Shared", 1, true)
            or string.find(message, "AW_Test", 1, true)
        table.insert(if ours then errors else robloxErrors, message)
    elseif messageType == Enum.MessageType.MessageWarning and string.find(message, "AutomotiveWorld", 1, true) then
        table.insert(warnings, message)
    elseif string.find(message, "[Validation]", 1, true) then
        table.insert(validation, message)
    end
end)

local reportEvent = Instance.new("RemoteEvent")
reportEvent.Name = "AWTestReport"
reportEvent.Parent = ReplicatedStorage
local signalEvent = Instance.new("RemoteEvent")
signalEvent.Name = "AWTestSignal"
signalEvent.Parent = ReplicatedStorage
-- Serveur → client : demande de capture (nom, cadrage, contexte) ou d'essai client.
local askEvent = Instance.new("RemoteEvent")
askEvent.Name = "AWAvatarAsk"
askEvent.Parent = ReplicatedStorage
ReplicatedStorage:SetAttribute("AWTestSession", session)
ReplicatedStorage:SetAttribute("AWTestPlayers", if session == "avatar2" then 2 else 1)

local Server = ServerScriptService:WaitForChild("AutomotiveWorldServer")
local MissionService = require(Server:WaitForChild("Economy"):WaitForChild("MissionService"))
local VehicleService = require(Server:WaitForChild("Vehicles"):WaitForChild("VehicleService"))
local AvatarService = require(Server:WaitForChild("Avatar"):WaitForChild("AvatarService"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local OutfitRules = require(Shared:WaitForChild("Cosmetics"):WaitForChild("OutfitRules")) :: any
local WorkingCatalog =
    require(Shared:WaitForChild("Vehicles"):WaitForChild("Definitions"):WaitForChild("WorkingCatalog")) :: any

local reports = {}
local acks: { [string]: boolean } = {}
reportEvent.OnServerEvent:Connect(function(player, payload)
    reports[tostring(player.UserId)] = payload
end)
signalEvent.OnServerEvent:Connect(function(_player, message)
    if type(message) == "string" and string.sub(message, 1, 5) == "AWAV:" then
        acks[string.sub(message, 6)] = true
    end
end)

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

-- Demande au client et attend son accusé (« AWAV:<id> »).
local function ask(player: Player, id: string, data: { [string]: any }, timeout: number): boolean
    acks[id] = nil
    askEvent:FireClient(player, id, data)
    return waitFor(function()
        return acks[id] == true
    end, timeout)
end

local S = 1 / 0.28 -- studs par mètre

-- ======================== Morphologies ========================

type Prop = { Name: string, Size: Vector3, Attachment: string, Offset: Vector3 }
type Morph = {
    Id: string,
    Label: string,
    Height: number,
    Width: number,
    Depth: number,
    Head: number,
    BodyType: number,
    Proportion: number,
    Props: { Prop },
}

-- Accessoires d'essai (pièces simples, sans actif) : volumes extrêmes plausibles.
local TALL_HAT: Prop = {
    Name = "EssaiChapeauHaut",
    Size = Vector3.new(1.3, 2.6, 1.3),
    Attachment = "HatAttachment",
    Offset = Vector3.new(0, -1.25, 0),
}
local BULKY: { Prop } = {
    {
        Name = "EssaiAiles",
        Size = Vector3.new(3.4, 2.4, 0.5),
        Attachment = "BodyBackAttachment",
        Offset = Vector3.new(0, 0, -0.35),
    },
    {
        Name = "EssaiEpauletteG",
        Size = Vector3.new(1.1, 0.6, 1.1),
        Attachment = "LeftShoulderAttachment",
        Offset = Vector3.new(0, -0.2, 0),
    },
    {
        Name = "EssaiEpauletteD",
        Size = Vector3.new(1.1, 0.6, 1.1),
        Attachment = "RightShoulderAttachment",
        Offset = Vector3.new(0, -0.2, 0),
    },
    {
        Name = "EssaiCeinture",
        Size = Vector3.new(2.2, 0.8, 1.6),
        Attachment = "WaistCenterAttachment",
        Offset = Vector3.zero,
    },
}

local MORPHS: { Morph } = {
    {
        Id = "M1",
        Label = "référence (échelles 1)",
        Height = 1,
        Width = 1,
        Depth = 1,
        Head = 1,
        BodyType = 0,
        Proportion = 0,
        Props = {},
    },
    {
        Id = "M2",
        Label = "petit et mince",
        Height = 0.9,
        Width = 0.7,
        Depth = 0.7,
        Head = 0.95,
        BodyType = 0,
        Proportion = 0,
        Props = {},
    },
    {
        Id = "M3",
        Label = "grand classique",
        Height = 1.05,
        Width = 1,
        Depth = 1,
        Head = 1,
        BodyType = 0,
        Proportion = 0,
        Props = {},
    },
    {
        Id = "M4",
        Label = "grand, type de corps maximal",
        Height = 1.05,
        Width = 1,
        Depth = 1,
        Head = 1,
        BodyType = 1,
        Proportion = 0,
        Props = {},
    },
    {
        Id = "M5",
        Label = "grand élancé (proportions maximales)",
        Height = 1.05,
        Width = 0.7,
        Depth = 0.7,
        Head = 1,
        BodyType = 1,
        Proportion = 1,
        Props = {},
    },
    {
        Id = "M6",
        Label = "petit et large",
        Height = 0.9,
        Width = 1,
        Depth = 1,
        Head = 1,
        BodyType = 0,
        Proportion = 0,
        Props = {},
    },
    {
        Id = "M7",
        Label = "M4 + chapeau haut (2,6 st)",
        Height = 1.05,
        Width = 1,
        Depth = 1,
        Head = 1,
        BodyType = 1,
        Proportion = 0,
        Props = { TALL_HAT },
    },
    {
        Id = "M8",
        Label = "référence + accessoires volumineux (dos, épaules, taille)",
        Height = 1,
        Width = 1,
        Depth = 1,
        Head = 1,
        BodyType = 0,
        Proportion = 0,
        Props = BULKY,
    },
}
local EXTREMES = { M2 = true, M4 = true, M5 = true, M7 = true, M8 = true }

local function characterOf(player: Player): Model?
    return player.Character
end
local function humanoidOf(player: Player): Humanoid?
    local character = characterOf(player)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function clearProps(character: Model)
    for _, item in character:GetChildren() do
        if item:IsA("Accessory") and item:GetAttribute("AWTestProp") then
            item:Destroy()
        end
    end
end

local function addProp(humanoid: Humanoid, prop: Prop)
    local accessory = Instance.new("Accessory")
    accessory.Name = prop.Name
    accessory:SetAttribute("AWTestProp", true)
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = prop.Size
    handle.CanCollide = false
    handle.CanQuery = false
    handle.CanTouch = false
    handle.Massless = true
    handle.Color = Color3.fromRGB(200, 60, 160)
    local attachment = Instance.new("Attachment")
    attachment.Name = prop.Attachment
    attachment.Position = prop.Offset
    attachment.Parent = handle
    handle.Parent = accessory
    humanoid:AddAccessory(accessory)
end

local function applyMorph(player: Player, morph: Morph): (boolean, string)
    local humanoid = humanoidOf(player)
    local character = characterOf(player)
    if humanoid == nil or character == nil then
        return false, "personnage absent"
    end
    clearProps(character)
    local description = humanoid:GetAppliedDescription()
    description.HeightScale = morph.Height
    description.WidthScale = morph.Width
    description.DepthScale = morph.Depth
    description.HeadScale = morph.Head
    description.BodyTypeScale = morph.BodyType
    description.ProportionScale = morph.Proportion
    local ok, err = pcall(function()
        humanoid:ApplyDescriptionAsync(description)
    end)
    if not ok then
        return false, tostring(err)
    end
    for _, prop in morph.Props do
        addProp(humanoid, prop)
    end
    -- Pose stabilisée avant la mesure (reconstruction du personnage, animation d'attente).
    task.wait(1.6)
    local applied = humanoid:GetAppliedDescription()
    -- Hauteur du corps (pieds → sommet de la tête, sans accessoire) et hors tout.
    local bodyTop, bodyBottom, allTop = -math.huge, math.huge, -math.huge
    for _, part in character:GetDescendants() do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local top = part.Position.Y + part.Size.Y / 2
            allTop = math.max(allTop, top)
            if part:FindFirstAncestorOfClass("Accessory") == nil then
                bodyTop = math.max(bodyTop, top)
                bodyBottom = math.min(bodyBottom, part.Position.Y - part.Size.Y / 2)
            end
        end
    end
    return true,
        string.format(
            "échelles lues H %.2f L %.2f P %.2f T %.2f corps %.2f prop. %.2f ; corps %.2f st, hors tout %.2f st, HipHeight %.2f",
            applied.HeightScale,
            applied.WidthScale,
            applied.DepthScale,
            applied.HeadScale,
            applied.BodyTypeScale,
            applied.ProportionScale,
            bodyTop - bodyBottom,
            allTop - bodyBottom,
            humanoid.HipHeight
        )
end

-- ======================== Géométrie (repère du véhicule) ========================

local function localBounds(part: BasePart, frame: CFrame): (Vector3, Vector3)
    local half = part.Size / 2
    local minV, maxV = Vector3.one * math.huge, -Vector3.one * math.huge
    for _, sx in { -1, 1 } do
        for _, sy in { -1, 1 } do
            for _, sz in { -1, 1 } do
                local corner =
                    frame:PointToObjectSpace((part.CFrame * CFrame.new(half * Vector3.new(sx, sy, sz))).Position)
                minV = minV:Min(corner)
                maxV = maxV:Max(corner)
            end
        end
    end
    return minV, maxV
end

local function partsNamed(model: Model, names: { [string]: boolean }): { BasePart }
    local list = {}
    for _, item in model:GetDescendants() do
        if item:IsA("BasePart") and names[item.Name] then
            table.insert(list, item)
        end
    end
    return list
end

-- Profondeur de recouvrement de deux boîtes alignées (0 si disjointes).
local function overlapDepth(aMin: Vector3, aMax: Vector3, bMin: Vector3, bMax: Vector3): number
    local dx = math.min(aMax.X, bMax.X) - math.max(aMin.X, bMin.X)
    local dy = math.min(aMax.Y, bMax.Y) - math.max(aMin.Y, bMin.Y)
    local dz = math.min(aMax.Z, bMax.Z) - math.max(aMin.Z, bMin.Z)
    if dx <= 0 or dy <= 0 or dz <= 0 then
        return 0
    end
    return math.min(dx, dy, dz)
end

local LEGS = {
    LeftUpperLeg = true,
    LeftLowerLeg = true,
    LeftFoot = true,
    RightUpperLeg = true,
    RightLowerLeg = true,
    RightFoot = true,
}
local INTERIOR = { PlancheDeBord = true, Console = true, Combine = true, Volant = true }

type Seated = { [string]: any }

local function measureSeated(model: Model, seat: Seat, character: Model): Seated
    local root = model.PrimaryPart :: BasePart
    local frame = root.CFrame
    local result: Seated = {}
    local top, bodyTop, sideMax = -math.huge, -math.huge, 0
    local feetMin = math.huge
    local legs: { { Name: string, Min: Vector3, Max: Vector3 } } = {}
    local charMass = 0
    for _, part in character:GetDescendants() do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local minV, maxV = localBounds(part, frame)
            top = math.max(top, maxV.Y)
            local accessory = part:FindFirstAncestorOfClass("Accessory")
            if accessory == nil then
                bodyTop = math.max(bodyTop, maxV.Y) -- tête sans cheveux ni chapeau
            end
            if accessory == nil or accessory:GetAttribute("AWTestProp") == nil then
                -- Côtés : corps et accessoires du joueur (les accessoires d'essai géants
                -- du dos dépassent par construction ; mesurés à part).
                sideMax = math.max(sideMax, math.abs(minV.X), math.abs(maxV.X))
            end
            if part.Name == "LeftFoot" or part.Name == "RightFoot" then
                feetMin = math.min(feetMin, minV.Y)
            end
            if LEGS[part.Name] then
                table.insert(legs, { Name = part.Name, Min = minV, Max = maxV })
            end
            if not part.Massless then
                charMass += part:GetMass()
            end
        end
    end
    result.TopY = top
    result.BodyTopY = bodyTop
    result.CharacterMass = charMass
    -- Pavillon, coque, intérieur.
    -- Pavillon réel seulement (le roadster porte un repère « Toit » de 0,1 st à la ceinture).
    local roofs = {}
    for _, part in partsNamed(model, { Toit = true }) do
        if part.Size.X > 1 and part.Size.Z > 1 then
            table.insert(roofs, part)
        end
    end
    if #roofs > 0 then
        local roofMin, roofMax = math.huge, -math.huge
        for _, part in roofs do
            local minV, maxV = localBounds(part, frame)
            roofMin = math.min(roofMin, minV.Y)
            roofMax = math.max(roofMax, maxV.Y)
        end
        result.RoofMargin = roofMin - top -- > 0 : dégagement sous le pavillon (accessoires compris)
        result.RoofMarginBody = roofMin - bodyTop -- même mesure, tête seule
        result.ThroughRoof = top > roofMax
    end
    -- Enveloppe de la carrosserie (rétroviseurs exclus) : flancs et dessous de caisse.
    local body = model:FindFirstChild("Carrosserie")
    if body then
        local half, bottom = 0, math.huge
        for _, part in body:GetDescendants() do
            if part:IsA("BasePart") and part.Transparency < 1 and part.Name ~= "Retroviseur" then
                local minV, maxV = localBounds(part, frame)
                half = math.max(half, math.abs(minV.X), math.abs(maxV.X))
                bottom = math.min(bottom, minV.Y)
            end
        end
        result.SideMargin = half - sideMax -- > 0 : rien ne dépasse des flancs
        result.FloorMargin = feetMin - bottom -- > 0 : pieds au-dessus du dessous de caisse
    end
    local seatTop = frame:PointToObjectSpace((seat.CFrame * CFrame.new(0, seat.Size.Y / 2, 0)).Position).Y
    local lower = character:FindFirstChild("LowerTorso")
    if lower and lower:IsA("BasePart") then
        local minV = localBounds(lower, frame)
        result.SeatPenetration = seatTop - minV.Y -- enfoncement du bassin dans l'assise
    end
    local worst, worstPair = 0, ""
    for _, part in partsNamed(model, INTERIOR) do
        local bMin, bMax = localBounds(part, frame)
        for _, leg in legs do
            local depth = overlapDepth(leg.Min, leg.Max, bMin, bMax)
            if depth > worst then
                worst, worstPair = depth, leg.Name .. "/" .. part.Name
            end
        end
    end
    result.InteriorOverlap = worst
    result.InteriorPair = worstPair
    local wheel = partsNamed(model, { Volant = true })[1]
    local left, right = character:FindFirstChild("LeftHand"), character:FindFirstChild("RightHand")
    if wheel and left and right and left:IsA("BasePart") and right:IsA("BasePart") then
        result.HandsToWheel =
            math.max((left.Position - wheel.Position).Magnitude, (right.Position - wheel.Position).Magnitude)
    end
    local eye = root:FindFirstChild("CameraCockpit")
    local head = character:FindFirstChild("Head")
    if eye and eye:IsA("Attachment") and head and head:IsA("BasePart") then
        local delta = frame:VectorToObjectSpace(head.Position - eye.WorldPosition)
        result.HeadVsEye = string.format("%.2f/%.2f/%.2f", delta.X, delta.Y, delta.Z)
    end
    result.AssemblyMass = root.AssemblyMass
    return result
end

-- ======================== Véhicules ========================

local strip = CFrame.lookAt(Vector3.new(0, 4, -6 * S), Vector3.new(0, 4, -60 * S))
local current: Model? = nil

local function despawn()
    if current and current.Parent then
        VehicleService.despawnPersonal(current)
    end
    current = nil
end

local function spawnVehicle(player: Player, modelId: string): Model?
    despawn()
    local character = characterOf(player)
    if character == nil then
        return nil
    end
    character:PivotTo(strip)
    task.wait(0.6)
    current = MissionService.spawnBeside(player, modelId, "AVATAR-" .. modelId)
    if current then
        task.wait(1.5) -- pose et immobilisation
    end
    return current
end

local function sit(player: Player, model: Model, seatName: string): Seat?
    local seat = model:FindFirstChild(seatName)
    local humanoid = humanoidOf(player)
    if seat == nil or not seat:IsA("Seat") or humanoid == nil then
        return nil
    end
    seat:Sit(humanoid)
    local seated = waitFor(function()
        return seat.Occupant == humanoid
    end, 3)
    if not seated then
        return nil
    end
    task.wait(1.2) -- animation d'assise
    return seat
end

local function standUp(player: Player)
    local humanoid = humanoidOf(player)
    if humanoid and humanoid.SeatPart then
        local seat = humanoid.SeatPart
        local weld = seat:FindFirstChild("SeatWeld")
        if weld then
            weld:Destroy()
        end
        humanoid.Sit = false
        task.wait(0.5)
    end
end

-- Sortie constatée : personnage debout, droit, posé au sol, hors du véhicule.
local function measureExit(player: Player, model: Model): (boolean, string)
    task.wait(1.2)
    local character = characterOf(player)
    local humanoid = humanoidOf(player)
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if humanoid == nil or rootPart == nil or not rootPart:IsA("BasePart") then
        return false, "personnage absent"
    end
    local seated = humanoid.SeatPart ~= nil or humanoid.Sit
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character :: Model }
    local hit = Workspace:Raycast(rootPart.Position, Vector3.new(0, -50, 0), params)
    local onVehicle = hit ~= nil and hit.Instance:IsDescendantOf(model)
    local height = if hit then rootPart.Position.Y - hit.Position.Y else 99
    local expected = humanoid.HipHeight + rootPart.Size.Y / 2
    local overlap = OverlapParams.new()
    overlap.FilterType = Enum.RaycastFilterType.Include
    overlap.FilterDescendantsInstances = { model }
    overlap.RespectCanCollide = true
    local extents = (character :: Model):GetExtentsSize()
    local blocking = Workspace:GetPartBoundsInBox((character :: Model):GetPivot(), extents * 0.9, overlap)
    local upright = rootPart.CFrame.UpVector.Y
    local root = model.PrimaryPart :: BasePart
    local distance = (Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z) - Vector3.new(
        root.Position.X,
        0,
        root.Position.Z
    )).Magnitude
    local ok = not seated and upright > 0.9 and not onVehicle and math.abs(height - expected) < 1.5 and #blocking == 0
    return ok,
        string.format(
            "assis %s, droit %.2f, sur le véhicule %s, hauteur %.2f st (attendu %.2f), recouvrements %d, à %.1f st du centre",
            tostring(seated),
            upright,
            tostring(onVehicle),
            height,
            expected,
            #blocking,
            distance
        )
end

-- Cadrage latéral d'un siège (côté du siège), légèrement en hauteur.
local function sideView(model: Model, seat: Seat, side: number): CFrame
    local root = model.PrimaryPart :: BasePart
    local frame = root.CFrame
    local target = seat.Position + Vector3.new(0, 1.5, 0)
    local eye = target + frame.RightVector * side * 11 + frame.LookVector * 3 + Vector3.new(0, 3, 0)
    return CFrame.lookAt(eye, target)
end

local function shot(player: Player, name: string, view: CFrame, context: { [string]: any })
    context.cadrage = { view:GetComponents() }
    ask(player, "shot:" .. name, { Name = name, Context = context }, 8)
end

-- ======================== Session « avatar2 » ========================

if session == "avatar2" then
    local joined = waitFor(function()
        return #Players:GetPlayers() >= 2
    end, 90)
    record("avatar2.serveur.joueurs_connectes", joined, #Players:GetPlayers())
    local gotReports = waitFor(function()
        local count = 0
        for _ in reports do
            count += 1
        end
        return count >= 2
    end, 400)
    record("avatar2.serveur.rapports_clients", gotReports)
    record("avatar2.serveur.aucune_erreur_execution", #errors == 0, table.concat(errors, " || "))
    record(
        "avatar2.serveur.info_erreurs_internes_roblox",
        true,
        #robloxErrors .. " : " .. table.concat(robloxErrors, " || ")
    )
    StudioTestService:EndTest({ session = session, players = #Players:GetPlayers(), server = steps, clients = reports })
    return
end

-- ======================== Session « avatar » ========================

local joined = waitFor(function()
    return #Players:GetPlayers() >= 1
end, 60)
record("avatar.serveur.joueur_connecte", joined, #Players:GetPlayers())
local player = Players:GetPlayers()[1]
local character = player and (player.Character or player.CharacterAdded:Wait())
waitFor(function()
    return player:HasAppearanceLoaded()
end, 20)
local humanoid = character and character:WaitForChild("Humanoid", 10) :: Humanoid?

-- 0. Réglage et apparence du compte de test (Studio de la VM).
-- Propriétés éventuellement non lisibles par script : lecture protégée.
local function readSetting(name: string): any
    local ok, value = pcall(function()
        return (StarterPlayer :: any)[name]
    end)
    return if ok then value else "illisible"
end
-- Tâche 20261104-104818 : GameSettingsAvatar n'est pas lisible par script ; le réglage est
-- contrôlé dans la place construite (Lune) et par le squelette constaté ci-dessous.
record(
    "avatar.reglage.info_place",
    true,
    string.format(
        "GameSettingsAvatar %s, LoadCharacterAppearance %s, AvatarJointUpgrade %s",
        tostring(readSetting("GameSettingsAvatar")),
        tostring(readSetting("LoadCharacterAppearance")),
        tostring(readSetting("AvatarJointUpgrade"))
    )
)
if humanoid == nil or character == nil then
    record("avatar.personnage_present", false)
    StudioTestService:EndTest({ session = session, players = 1, server = steps, clients = reports })
    return
end
local motors, constraints, layered, accessories = 0, 0, 0, 0
for _, item in character:GetDescendants() do
    if item:IsA("Motor6D") then
        motors += 1
    elseif item:IsA("AnimationConstraint") then
        constraints += 1
    elseif item:IsA("WrapLayer") then
        layered += 1
    elseif item:IsA("Accessory") then
        accessories += 1
    end
end
record("avatar.compte.squelette_r15", humanoid.RigType == Enum.HumanoidRigType.R15, humanoid.RigType.Name)
record(
    "avatar.compte.attribut_rig",
    character:GetAttribute("AWAvatarRig") == "R15",
    tostring(character:GetAttribute("AWAvatarRig"))
)
record("avatar.compte.aucun_personnage_non_r15", AvatarService.nonR15Count() == 0, AvatarService.nonR15Count())
local initialDescription = humanoid:GetAppliedDescription()
record(
    "avatar.compte.info_apparence",
    true,
    string.format(
        "articulations : %d Motor6D, %d AnimationConstraint ; %d accessoire(s) dont %d vêtement(s) 3D superposé(s) ; Shirt %d, Pants %d, T-shirt %d ; échelles H %.2f L %.2f T %.2f corps %.2f ; hauteur %.2f st",
        motors,
        constraints,
        accessories,
        layered,
        initialDescription.Shirt,
        initialDescription.Pants,
        initialDescription.GraphicTShirt,
        initialDescription.HeightScale,
        initialDescription.WidthScale,
        initialDescription.HeadScale,
        initialDescription.BodyTypeScale,
        character:GetExtentsSize().Y
    )
)
local initialLook = AvatarService.initialLook(player)
record("avatar.tenue.apparence_initiale_memorisee", initialLook ~= nil)

-- Essais du client (étalonnage des vraies entrées).
local calibrated = ask(player, "calibrate", {}, 40)
record("avatar.serveur.client_pret", calibrated)

-- 1. Tenues : demandes du client, identifiant invalide, essayage, restauration.
local clientOutfit = ask(player, "outfits", {}, 30)
record("avatar.tenue.demandes_client_traitees", clientOutfit)
local before = AvatarService.currentLook(player)
local invalid = AvatarService.wearOutfit(player, {
    Id = "essai.invalide",
    Category = "Mechanic",
    Status = "Available",
    LabelKey = "x",
    -- Identifiant bien formé mais délibérément inexistant (valeur de test signalée, jamais
    -- au catalogue) : le moteur doit le refuser et l'apparence rester intacte.
    Items = { Hat = 2 ^ 53 - 1 },
}, false)
local after = AvatarService.currentLook(player)
record(
    "avatar.tenue.identifiant_inexistant_refuse",
    invalid.Status == "Rejected" and invalid.Reason == "OutfitAssetInvalid",
    tostring(invalid.Status) .. " / " .. tostring(invalid.Reason)
)
record(
    "avatar.tenue.apparence_intacte_apres_refus",
    before ~= nil and after ~= nil and OutfitRules.equal(before, after),
    if before and after then string.format("%d → %d accessoire(s)", #before.Accessories, #after.Accessories) else "?"
)
local restored = AvatarService.restore(player)
local afterRestore = AvatarService.currentLook(player)
record(
    "avatar.tenue.restauration_apparence_initiale",
    restored.Status == "Ok"
        and initialLook ~= nil
        and afterRestore ~= nil
        and OutfitRules.equal(initialLook, afterRestore),
    tostring(restored.Status) .. " / " .. tostring(restored.Reason)
)

-- 2. Morphologies debout : marche, téléphone (client), puis assise dans les véhicules.
local SAMPLE = { "proto_p01", "wk_pixel", "wk_comete", "wk_brise", "wk_dune" }
local results: { [string]: { [string]: { [string]: Seated } } } = {} -- véhicule → siège → morphologie
local exits: { [string]: { string } } = {}

local function seatAndMeasure(model: Model, modelId: string, morph: Morph, seatName: string, capture: boolean)
    local seat = sit(player, model, seatName)
    local key = if seatName == "DriverSeat" then "conducteur" else "passager"
    results[modelId] = results[modelId] or {}
    results[modelId][key] = results[modelId][key] or {}
    if seat == nil then
        results[modelId][key][morph.Id] = { Seated = false }
        emitData("seat", { vehicle = modelId, seat = key, morph = morph.Id, seated = false })
        return nil
    end
    local data = measureSeated(model, seat, characterOf(player) :: Model)
    data.Seated = true
    results[modelId][key][morph.Id] = data
    local json = table.clone(data)
    json.vehicle, json.seat, json.morph = modelId, key, morph.Id
    emitData("seat", json)
    if capture then
        shot(
            player,
            string.format("%s_%s_%s", modelId, key, morph.Id),
            sideView(model, seat, if key == "conducteur" then -1 else 1),
            {
                vehicule = modelId,
                siege = key,
                morphologie = morph.Label,
            }
        )
    end
    return seat
end

for _, morph in MORPHS do
    standUp(player)
    despawn()
    local character0 = characterOf(player)
    if character0 then
        character0:PivotTo(strip)
    end
    task.wait(0.5)
    local applied, detail = applyMorph(player, morph)
    record("avatar.morphologie." .. morph.Id .. ".appliquee", applied, morph.Label .. " — " .. detail)
    emitData("morph", { morph = morph.Id, label = morph.Label, applied = applied, detail = detail })
    if applied then
        -- Marche (vraie touche W), téléphone (vraie touche T), capture debout : client.
        ask(player, "standing:" .. morph.Id, { Morph = morph.Id, Label = morph.Label }, 40)
        for _, modelId in SAMPLE do
            local model = spawnVehicle(player, modelId)
            if model == nil then
                record("avatar." .. modelId .. ".vehicule_pose", false, morph.Id)
                continue
            end
            local massBefore = (model.PrimaryPart :: BasePart).AssemblyMass
            local seat = seatAndMeasure(model, modelId, morph, "DriverSeat", true)
            if seat then
                local data = results[modelId].conducteur[morph.Id]
                data.MassBefore = massBefore
                if morph.Id == "M1" or morph.Id == "M7" then
                    -- Vue cockpit : personnage (accessoires compris) masqué localement.
                    ask(player, "cockpit:" .. modelId .. ":" .. morph.Id, { Vehicle = modelId, Morph = morph.Id }, 25)
                end
                -- Sortie par la vraie touche F (chemin du jeu : placement par le serveur).
                local exited = ask(player, "exit:" .. modelId .. ":" .. morph.Id, { Key = "F" }, 12)
                local ok, exitDetail = measureExit(player, model)
                exits[modelId .. ".conducteur"] = exits[modelId .. ".conducteur"] or {}
                table.insert(
                    exits[modelId .. ".conducteur"],
                    string.format(
                        "%s %s%s",
                        morph.Id,
                        if ok then "OK" else "ÉCHEC",
                        if exited then "" else " (touche non reçue)"
                    )
                )
                emitData("exit", {
                    vehicle = modelId,
                    seat = "conducteur",
                    morph = morph.Id,
                    ok = ok,
                    key = exited,
                    detail = exitDetail,
                })
                if not ok then
                    record(string.format("avatar.%s.conducteur.sortie_%s", modelId, morph.Id), false, exitDetail)
                end
                standUp(player)
            end
            local passengerSeat = seatAndMeasure(
                model,
                modelId,
                morph,
                "PassengerSeat",
                morph.Id == "M4" or morph.Id == "M7" or morph.Id == "M1"
            )
            if passengerSeat then
                if morph.Id == "M1" or morph.Id == "M4" then
                    -- Téléphone tenu en place passager (vraie touche T).
                    ask(
                        player,
                        "seatedphone:" .. modelId .. ":" .. morph.Id,
                        { Vehicle = modelId, Morph = morph.Id },
                        20
                    )
                end
                -- Sortie passager : saut (vraie touche Espace), comportement du moteur.
                local exited = ask(player, "exit:" .. modelId .. ":" .. morph.Id .. ":p", { Key = "Space" }, 12)
                local ok, exitDetail = measureExit(player, model)
                exits[modelId .. ".passager"] = exits[modelId .. ".passager"] or {}
                table.insert(
                    exits[modelId .. ".passager"],
                    string.format(
                        "%s %s%s",
                        morph.Id,
                        if ok then "OK" else "ÉCHEC",
                        if exited then "" else " (touche non reçue)"
                    )
                )
                emitData("exit", {
                    vehicle = modelId,
                    seat = "passager",
                    morph = morph.Id,
                    ok = ok,
                    key = exited,
                    detail = exitDetail,
                })
                if not ok then
                    record(string.format("avatar.%s.passager.sortie_%s", modelId, morph.Id), false, exitDetail)
                end
                standUp(player)
            end
        end
    end
end

-- 3. Les 18 modèles avec les morphologies extrêmes (assise seulement, une capture M7).
for _, spec in WorkingCatalog.Specs do
    local modelId = spec.Id
    if table.find(SAMPLE, modelId) then
        continue
    end
    for _, morph in MORPHS do
        if not EXTREMES[morph.Id] then
            continue
        end
        standUp(player)
        despawn()
        local character0 = characterOf(player)
        if character0 then
            character0:PivotTo(strip)
        end
        task.wait(0.4)
        local applied = applyMorph(player, morph)
        if not applied then
            continue
        end
        local model = spawnVehicle(player, modelId)
        if model == nil then
            record("avatar." .. modelId .. ".vehicule_pose", false, morph.Id)
            continue
        end
        local massBefore = (model.PrimaryPart :: BasePart).AssemblyMass
        if seatAndMeasure(model, modelId, morph, "DriverSeat", morph.Id == "M7") then
            results[modelId].conducteur[morph.Id].MassBefore = massBefore
            standUp(player)
        end
        if seatAndMeasure(model, modelId, morph, "PassengerSeat", false) then
            standUp(player)
        end
    end
end
standUp(player)
despawn()

-- 4. Bilan par véhicule et par siège (critères dans le repère du véhicule, studs). Détail
-- COMPACT (morphologies en échec seulement) : la sortie de Studio tronque une ligne de
-- résultat au-delà de 100 000 caractères (tâche 20261104-104818) ; les valeurs complètes
-- sont dans le journal « @@AWAVATAR@@ ».
local SEAT_MAX = 0.6 -- enfoncement du bassin dans l'assise au plus (≈ 17 cm)
local INTERIOR_MAX = 0.5 -- recouvrement jambes / planche de bord au plus (≈ 14 cm)
local function fmt(value: number?): string
    return if value == nil then "—" else string.format("%.2f", value)
end
local vehicles = {}
for modelId in results do
    table.insert(vehicles, modelId)
end
table.sort(vehicles)
local seatedTotal, seatedOk = 0, 0
type Criterion = { Key: string, Field: string, Bad: (number) -> boolean }
local CRITERIA: { Criterion } = {
    {
        Key = "tete_sous_le_pavillon",
        Field = "RoofMarginBody",
        Bad = function(v: number): boolean
            return v < 0
        end,
    },
    {
        Key = "accessoires_sous_le_pavillon",
        Field = "RoofMargin",
        Bad = function(v: number): boolean
            return v < 0
        end,
    },
    {
        Key = "assise_sans_enfoncement_excessif",
        Field = "SeatPenetration",
        Bad = function(v: number): boolean
            return v > SEAT_MAX
        end,
    },
    {
        Key = "rien_ne_traverse_les_flancs",
        Field = "SideMargin",
        Bad = function(v: number): boolean
            return v < 0
        end,
    },
    {
        Key = "pieds_dans_l_habitacle",
        Field = "FloorMargin",
        Bad = function(v: number): boolean
            return v < 0
        end,
    },
    {
        Key = "jambes_et_planche_de_bord",
        Field = "InteriorOverlap",
        Bad = function(v: number): boolean
            return v > INTERIOR_MAX
        end,
    },
}
for _, modelId in vehicles do
    for _, key in { "conducteur", "passager" } do
        local byMorph = results[modelId][key]
        if byMorph == nil then
            continue
        end
        local ids = {}
        for id in byMorph do
            table.insert(ids, id)
        end
        table.sort(ids)
        local prefix = string.format("avatar.%s.%s.", modelId, key)
        local notSeated = {}
        for _, id in ids do
            seatedTotal += 1
            if byMorph[id].Seated then
                seatedOk += 1
            else
                table.insert(notSeated, id)
            end
        end
        record(prefix .. "assise", #notSeated == 0, #ids .. " morph. ; non assis : " .. table.concat(notSeated, ","))
        for _, criterion in CRITERIA do
            local failing, measured = {}, 0
            for _, id in ids do
                local value = byMorph[id][criterion.Field]
                if byMorph[id].Seated and type(value) == "number" then
                    measured += 1
                    if criterion.Bad(value) then
                        table.insert(failing, id .. " " .. fmt(value))
                    end
                end
            end
            if measured > 0 then
                record(prefix .. criterion.Key, #failing == 0, table.concat(failing, " / "))
            end
        end
    end
end
for key, list in exits do
    local failing = {}
    for _, entry in list do
        if string.find(entry, "ÉCHEC", 1, true) then
            table.insert(failing, (string.gsub(entry, " ÉCHEC", "")))
        end
    end
    record(
        "avatar." .. key .. ".sorties",
        #failing == 0,
        #list .. " essai(s) ; échecs : " .. table.concat(failing, ",")
    )
end
record("avatar.bilan.assises", seatedOk == seatedTotal, string.format("%d / %d", seatedOk, seatedTotal))
-- Masse du personnage assis comptée dans l'ensemble du véhicule (forces rapportées à cette
-- masse par le simulateur : information, aucune correction physique dans ce lot).
local massNotes = {}
for _, modelId in SAMPLE do
    local byMorph = results[modelId] and results[modelId].conducteur
    for _, id in { "M2", "M4" } do
        local data = byMorph and byMorph[id]
        if data and data.Seated and data.MassBefore then
            table.insert(massNotes, string.format("%s %s %.0f→%.0f", modelId, id, data.MassBefore, data.AssemblyMass))
        end
    end
end
record("avatar.info_masse_du_personnage_assis", true, table.concat(massNotes, " / "))

-- 5. Tenue refusée assis, réapparition : R15 et apparence initiale relue.
local model = spawnVehicle(player, "proto_p01")
if model and sit(player, model, "DriverSeat") then
    local seatedRestore = AvatarService.restore(player)
    record(
        "avatar.tenue.refus_dans_un_vehicule",
        seatedRestore.Reason == "OutfitNotWhileSeated",
        tostring(seatedRestore.Reason)
    )
    standUp(player)
end
despawn()
player:LoadCharacter()
local respawned = waitFor(function()
    local c = player.Character
    return c ~= nil
        and c ~= character
        and c:GetAttribute("AWAvatarRig") ~= nil
        and AvatarService.initialLook(player) ~= nil
end, 25)
local again = player.Character
record(
    "avatar.reapparition.r15",
    respawned and again ~= nil and again:GetAttribute("AWAvatarRig") == "R15",
    again and tostring(again:GetAttribute("AWAvatarRig"))
)

ask(player, "finish", {}, 10)
waitFor(function()
    return next(reports) ~= nil
end, 60)
record("avatar.serveur.rapport_client", next(reports) ~= nil)
record("avatar.serveur.info_avertissements_du_jeu", true, #warnings .. " : " .. table.concat(warnings, " || "))
record("avatar.serveur.info_journal_validation", true, #validation .. " : " .. table.concat(validation, " || "))
record("avatar.serveur.aucune_erreur_execution", #errors == 0, table.concat(errors, " || "))
record(
    "avatar.serveur.info_erreurs_internes_roblox",
    true,
    #robloxErrors .. " : " .. table.concat(robloxErrors, " || ")
)
trace("fin")
StudioTestService:EndTest({ session = session, players = 1, server = steps, clients = reports })
