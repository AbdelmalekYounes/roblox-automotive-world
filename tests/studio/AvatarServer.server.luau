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
if session ~= "avatar" and session ~= "avatar2" and session ~= "aster" then
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
local AvatarPolicy = require(Shared:WaitForChild("Avatar"):WaitForChild("AvatarPolicy")) :: any
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
    Body: string?, -- corps imposé (AvatarPolicy.Bodies) ; nil : corps par défaut
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
    local body = AvatarPolicy.Bodies[morph.Body or AvatarPolicy.DefaultBody]
    for _, field in AvatarPolicy.ReplacedParts do
        (description :: any)[field] = body.Parts[field]
    end
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

-- ======================== Session « aster » (phase 1 de l'Aster) ========================
-- Maquette en blocs de l'Aster construite d'après le gabarit (`AW_TestAsterTemplate`, module
-- pur partagé avec l'outil d'export), ancrée, posée au sol de la zone d'essai. Pour chaque
-- morphologie : pose standard du moteur puis pose du jeu (attribut AWSeatPose), places
-- conducteur et passager. La pose du jeu étant appliquée par chaque CLIENT (Transform), les
-- mesures sont faites par le client (journal « @@AWASTER@@ »).

-- Volant et pédalier : nil au premier passage (mesure de la pose), puis cotes relevées.
-- Second passage (2026-11-04) : volant au droit de l'axe du siège, à la hauteur et à la
-- distance visées pour la pose v2 ; pédalier au bout des pieds de la référence (tâche
-- 20261104-134156 : pieds à z = −1,79 st, mains de la pose v1 à z ≈ 0).
-- Troisième passage (avatars humains uniquement, décision du propriétaire du 2026-11-04) :
-- mains des corps humains mesurées (tâche 20261104-134756, pose v2) à ±1,05 st de l'axe,
-- y 2,5 à 3,1 st, z −0,7 à −0,9 st → volant de 0,8 st de rayon centré entre les corps
-- humains grand et élancé ; planche de bord avancée ; pavillon à 4,60 st de l'assise.
local ASTER_PARAMS: { [string]: any }? = {
    HeadroomSt = 4.60,
    -- Passage 4 : volant ajusté aux mains mesurées dans le repère du gabarit (passage 3,
    -- tâche 20261104-135355, pose du jeu, 7 morphologies : écart max. 0,26 st à la jante),
    -- pédalier devant les pointes de pied (−0,90 à −0,21 st), planche de bord devant le volant.
    -- Passage 5 : volant ajusté aux mains des deux corps retenus (passage 4, tâche
    -- 20261104-145632, repère du gabarit corrigé : mains de y 1,21 à 2,20 st, yeux du plus petit
    -- à 2,08 st) : meilleur compromis jante (≤ 0,34 st) et vue au-dessus du volant (≥ 0).
    Wheel = { Center = { -1.4, 1.52, 1.1 }, Radius = 0.55, TiltDeg = 15 },
    PedalZ = -1.4, -- pointes de pied de −1,21 à 0,34 st (F1 la plus en avant)
    DashZ = 0.0,
}

-- Morphologies HUMAINES (type de corps imposé à 1) : la session « aster » ne mesure plus les
-- corps aux proportions « en blocs », exclus par la décision du propriétaire.
local HUMAN_MORPHS: { Morph } = {
    {
        Id = "H1",
        Label = "humain grand",
        Height = 1.05,
        Width = 1,
        Depth = 1,
        Head = 1,
        BodyType = 1,
        Proportion = 0,
        Props = {},
    },
    {
        Id = "H2",
        Label = "humain petit et mince",
        Height = 0.9,
        Width = 0.7,
        Depth = 0.7,
        Head = 0.95,
        BodyType = 1,
        Proportion = 0,
        Props = {},
    },
    {
        Id = "H3",
        Label = "humain moyen",
        Height = 1,
        Width = 0.85,
        Depth = 0.85,
        Head = 1,
        BodyType = 1,
        Proportion = 0.5,
        Props = {},
    },
    {
        Id = "H4",
        Label = "humain grand élancé",
        Height = 1.05,
        Width = 0.7,
        Depth = 0.7,
        Head = 1,
        BodyType = 1,
        Proportion = 1,
        Props = {},
    },
    {
        Id = "H5",
        Label = "humain petit et large",
        Height = 0.9,
        Width = 1,
        Depth = 1,
        Head = 1,
        BodyType = 1,
        Proportion = 1,
        Props = {},
    },
    {
        Id = "H6",
        Label = "humain grand + chapeau haut d'essai",
        Height = 1.05,
        Width = 1,
        Depth = 1,
        Head = 1,
        BodyType = 1,
        Proportion = 0,
        Props = { TALL_HAT },
    },
    {
        Id = "H7",
        Label = "humain moyen + accessoires volumineux d'essai",
        Height = 1,
        Width = 0.85,
        Depth = 0.85,
        Head = 1,
        BodyType = 1,
        Proportion = 0.5,
        Props = BULKY,
    },
}
-- Corps féminin (994 Jordan) : extrêmes de taille et de largeur (copies de H1, H2, H4).
for _, source in { "H1", "H2", "H4" } do
    for _, morph in table.clone(HUMAN_MORPHS) do
        if morph.Id == source then
            local copy = table.clone(morph)
            copy.Id = "F" .. string.sub(source, 2)
            copy.Label = morph.Label .. " (corps féminin)"
            copy.Body = "Feminin"
            table.insert(HUMAN_MORPHS, copy)
        end
    end
end

if session == "aster" then
    local joined = waitFor(function()
        return #Players:GetPlayers() >= 1
    end, 60)
    record("aster.serveur.joueur_connecte", joined, #Players:GetPlayers())
    local player = Players:GetPlayers()[1]
    if player and not player.Character then
        player.CharacterAdded:Wait()
    end
    waitFor(function()
        return player ~= nil and player:HasAppearanceLoaded()
    end, 20)
    local Template = require(ReplicatedStorage:WaitForChild("AW_TestAsterTemplate", 20)) :: any
    local Vehicles = Shared:WaitForChild("Vehicles")
    local Definitions = require(Vehicles:WaitForChild("VehicleDefinitions")) :: any
    local Dynamics = require(Vehicles:WaitForChild("Physics"):WaitForChild("VehicleDynamics")) :: any
    local Constants = require(Vehicles:WaitForChild("VehicleConstants")) :: any
    local SeatPose = require(Vehicles:WaitForChild("SeatPose")) :: any
    local definition = Definitions.get("wk_aster")
    local params = if ASTER_PARAMS
        then (function()
            local merged = table.clone(Template.Defaults)
            for key, value in ASTER_PARAMS :: any do
                merged[key] = value
            end
            return merged
        end)()
        else nil
    local template = Template.build(definition, Dynamics.wheelLayout(definition), Constants.MetersPerStud, params)
    local model = Instance.new("Model")
    model.Name = "MaquetteAster"
    local COLORS = {
        caisse = Color3.fromRGB(205, 210, 218),
        vitrage = Color3.fromRGB(150, 190, 220),
        habitacle = Color3.fromRGB(45, 48, 54),
        siege = Color3.fromRGB(80, 40, 40),
        roue = Color3.fromRGB(25, 25, 28),
        repere = Color3.fromRGB(255, 200, 0),
    }
    for _, item in template.Boxes do
        local part: BasePart = if item.Seat then Instance.new("Seat") else Instance.new("Part")
        part.Name = item.Name
        part.Anchored = true
        part.Size = Vector3.new(item.Size[1], item.Size[2], item.Size[3])
        part.CFrame = CFrame.new(item.Center[1], item.Center[2], item.Center[3])
        if item.Rotation then
            part.CFrame = part.CFrame
                * CFrame.Angles(math.rad(item.Rotation[1]), 0, math.rad(item.Rotation[3]))
                * CFrame.Angles(0, math.rad(item.Rotation[2]), 0)
        end
        if item.Cylinder then
            (part :: Part).Shape = Enum.PartType.Cylinder
        end
        part.Color = COLORS[item.Role] or Color3.new(1, 1, 1)
        part.Material = if item.Role == "vitrage" then Enum.Material.Glass else Enum.Material.SmoothPlastic
        part.Transparency = if item.Role == "vitrage" then 0.6 elseif item.Role == "repere" then 0.5 else 0
        part.CanCollide = item.Role == "caisse" or item.Role == "habitacle" and item.Name ~= "Volant"
        part.CanTouch = false
        if item.Seat then
            part:SetAttribute("AWAsterSeat", item.Seat)
        end
        part.Parent = model
        if item.Name == "Plancher" then
            model.PrimaryPart = part
        end
    end
    -- Sol de la maquette au sol de la zone d'essai (y = 0), à l'écart du parc.
    local origin = CFrame.new(40, -template.Ground, -30)
    for _, part in model:GetChildren() do
        if part:IsA("BasePart") then
            part.CFrame = origin * part.CFrame
        end
    end
    -- Repère du gabarit transmis tel quel : le pivot d'un modèle à PrimaryPart suit le plancher
    -- côté client (mesures des passages 1 à 3 du 2026-11-04 dans le repère du plancher, décalé
    -- de 0 ; −0,39 ; +1,92 st), d'où un volant placé 2 st trop en avant.
    model:SetAttribute("AWAsterOrigin", origin)
    model.WorldPivot = origin
    model.Parent = Workspace
    record(
        "aster.serveur.maquette",
        true,
        string.format(
            "%d blocs ; assise %.2f st, dessous du pavillon %.2f st (%.2f st au-dessus de l'assise), hauteur hors tout %.2f m%s",
            #template.Boxes,
            template.SeatTop,
            template.RoofUnder,
            template.RoofUnder - template.SeatTop,
            template.HeightAboveGroundM,
            if ASTER_PARAMS then " ; volant et pédalier placés" else " ; sans volant ni pédalier (mesure de la pose)"
        )
    )
    local calibrated = ask(player, "calibrate", {}, 40)
    record("aster.serveur.client_pret", calibrated)
    local strip0 = CFrame.new(40, 4, 0)
    local measured, expected = 0, 0
    for _, morph in HUMAN_MORPHS do
        standUp(player)
        local character0 = characterOf(player)
        if character0 then
            character0:PivotTo(strip0)
        end
        task.wait(0.4)
        local applied = applyMorph(player, morph)
        if not applied then
            record("aster.morphologie." .. morph.Id, false, "non appliquée")
            continue
        end
        for _, pose in { "standard", "jeu" } do
            for _, seatName in { "SiegeConducteur", "SiegePassager" } do
                expected += 1
                local seatPart = model:FindFirstChild(seatName) :: Seat
                seatPart:SetAttribute(
                    SeatPose.Attribute,
                    if pose == "jeu" then seatPart:GetAttribute("AWAsterSeat") else nil
                )
                local seat = sit(player, model, seatName)
                if seat == nil then
                    continue
                end
                task.wait(0.8) -- mise en place de la pose (0,3 s) et stabilisation
                local key = string.format("%s:%s:%s", morph.Id, pose, seatName)
                if
                    ask(
                        player,
                        "astermeasure:" .. key,
                        { Morph = morph.Id, Pose = pose, Seat = seatName, Morphs = #HUMAN_MORPHS },
                        10
                    )
                then
                    measured += 1
                end
                if
                    (morph.Id == "H1" or morph.Id == "H4" or morph.Id == "H6" or morph.Id == "F4")
                    and seatName == "SiegeConducteur"
                then
                    shot(player, string.format("aster_%s_%s_profil", morph.Id, pose), sideView(model, seat, -1), {
                        morphologie = morph.Label,
                        pose = pose,
                    })
                    if pose == "jeu" then
                        ask(
                            player,
                            "asterpov:" .. key,
                            { Name = string.format("aster_%s_vue_conducteur", morph.Id) },
                            10
                        )
                    end
                end
                standUp(player)
                seatPart:SetAttribute(SeatPose.Attribute, nil)
            end
        end
    end
    standUp(player)
    record("aster.serveur.mesures", measured == expected, string.format("%d / %d", measured, expected))
    ask(player, "finish", {}, 10)
    waitFor(function()
        return next(reports) ~= nil
    end, 60)
    record("aster.serveur.rapport_client", next(reports) ~= nil)
    record("aster.serveur.aucune_erreur_execution", #errors == 0, table.concat(errors, " || "))
    record(
        "aster.serveur.info_erreurs_internes_roblox",
        true,
        #robloxErrors .. " : " .. table.concat(robloxErrors, " || ")
    )
    StudioTestService:EndTest({ session = session, players = 1, server = steps, clients = reports })
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

-- 0 bis. Corps humains (décision du propriétaire, 2026-11-04) : corps par défaut appliqué à
-- tous, choix du joueur, tête et vêtements conservés, corps inconnu refusé.
local function partsNow(): { [string]: number }
    local d = humanoid:GetAppliedDescription()
    local parts = {}
    for _, field in AvatarPolicy.ReplacedParts do
        parts[field] = (d :: any)[field]
    end
    return parts
end
-- Corps appliqué dans un fil séparé après l'apparition : attente de la confirmation.
waitFor(function()
    return player:GetAttribute("AWAvatarBody") ~= nil
end, 30)
task.wait(0.5) -- fin de la préparation du personnage (tenue équipée éventuelle)
record(
    "avatar.corps.defaut_applique",
    player:GetAttribute("AWAvatarBody") == AvatarPolicy.DefaultBody
        and AvatarPolicy.wearsBody(partsNow(), AvatarPolicy.DefaultBody),
    string.format("attribut %s ; Torso %d", tostring(player:GetAttribute("AWAvatarBody")), partsNow().Torso or 0)
)
local headBefore, shirtBefore, pantsBefore = initialDescription.Head, initialDescription.Shirt, initialDescription.Pants
local chosen = AvatarService.chooseBody(player, "Feminin")
local afterChoice = humanoid:GetAppliedDescription()
record(
    "avatar.corps.choix_feminin_applique",
    chosen.Status == "Ok" and AvatarPolicy.wearsBody(partsNow(), "Feminin"),
    string.format("%s / %s ; Torso %d", chosen.Status, tostring(chosen.Reason), partsNow().Torso or 0)
)
record(
    "avatar.corps.tete_et_vetements_conserves",
    afterChoice.Head == headBefore and afterChoice.Shirt == shirtBefore and afterChoice.Pants == pantsBefore,
    string.format("Head %d → %d ; Shirt %d → %d", headBefore, afterChoice.Head, shirtBefore, afterChoice.Shirt)
)
record(
    "avatar.corps.choix_memorise_session",
    player:GetAttribute("AWAvatarBodyChosen") == true and player:GetAttribute("AWAvatarBody") == "Feminin"
)
local unknown = AvatarService.chooseBody(player, "Robot")
record(
    "avatar.corps.corps_inconnu_refuse",
    unknown.Status == "Rejected" and unknown.Reason == "AvatarBodyUnknown",
    tostring(unknown.Reason)
)
local back = AvatarService.chooseBody(player, "Masculin")
record(
    "avatar.corps.retour_masculin",
    back.Status == "Ok" and AvatarPolicy.wearsBody(partsNow(), "Masculin"),
    tostring(back.Status)
)

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
    -- Modèle sans cette place (P-01 : aucune place passager) : rien à mesurer (tâche
    -- 20261104-111326 : comptée à tort « non assis »).
    if model:FindFirstChild(seatName) == nil then
        return nil
    end
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
