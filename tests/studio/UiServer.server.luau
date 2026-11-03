-- Essais SERVEUR du lot 0.9.1 (sessions à un joueur : « ui », « ui_monde », « metiers »,
-- « gps », « drift »), injectés
-- par le pilote dans le Studio de test uniquement.
-- Rôle : recueillir le rapport du client, offrir une LECTURE de l'état autoritaire
-- (AWTestQuery, test seulement) pour vérifier côté serveur le résultat d'un parcours
-- d'interface réalisé par de vrais clics, puis contrôler la cohérence des profils.
-- Le client ne peut rien MODIFIER par ces points d'accès : ils lisent, ou posent le
-- décor d'un essai (signal « AWUI:… »), ce qui est signalé dans le rapport.
-- Profils en MÉMOIRE (environnement Dev) : aucun DataStore n'est touché.

local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StudioTestService = game:GetService("StudioTestService")

local args = StudioTestService:GetTestArgs()
local session = if type(args) == "table" and type(args.Session) == "string" then args.Session else ""
-- Sessions à un joueur du lot 0.9.1 (interfaces, métiers, trajets, drift).
local SESSIONS = { ui = true, ui_monde = true, metiers = true, gps = true, drift = true }
if not SESSIONS[session] then
    return
end

local steps = {}
local function record(name: string, ok: boolean, detail: any)
    table.insert(steps, { name = name, ok = ok, detail = if detail ~= nil then tostring(detail) else nil })
end

local errors, robloxErrors, validation = {}, {}, {}
LogService.MessageOut:Connect(function(message, messageType)
    if messageType == Enum.MessageType.MessageError then
        local ours = string.find(message, "AutomotiveWorld", 1, true)
            or string.find(message, "ReplicatedStorage.Shared", 1, true)
            or string.find(message, "AW_Test", 1, true)
        table.insert(if ours then errors else robloxErrors, message)
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
local query = Instance.new("RemoteFunction")
query.Name = "AWTestQuery"
query.Parent = ReplicatedStorage
ReplicatedStorage:SetAttribute("AWTestSession", session)
ReplicatedStorage:SetAttribute("AWTestPlayers", 1)

local Server = ServerScriptService:WaitForChild("AutomotiveWorldServer")
local ProfileService = require(Server:WaitForChild("Persistence"):WaitForChild("ProfileService"))
local ProfileSchema = require(Server.Persistence.ProfileSchema)

local reports = {}
reportEvent.OnServerEvent:Connect(function(player, payload)
    reports[tostring(player.UserId)] = payload
end)

-- Décor d'essai (signalé) : « AWUI:Seat » assoit le joueur au volant d'un prototype libre
-- du parc (comme le ferait l'invite, quand l'activation scriptée de l'invite échoue).
local S = 1 / 0.28
-- « AWUI:PlaceStart » (session gps) : un prototype libre du parc est posé UNE fois, au
-- départ, sur une rue proche du point d'apparition, dans le sens de la rue.
local function placeStart(player: Player)
    local Shared = ReplicatedStorage:WaitForChild("Shared")
    local WorldLayout = require(Shared:WaitForChild("World"):WaitForChild("WorldLayout")) :: any
    local layout = WorldLayout.get()
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
    local fleet = workspace:FindFirstChild("VehiculesEssai")
    local model = fleet and fleet:FindFirstChild("VehiculeEssai_1") :: Model?
    if root == nil or model == nil then
        return
    end
    local px, pz = root.Position.X / S, root.Position.Z / S
    local best, bestD, bestDir = nil, math.huge, nil
    for _, edge in layout.Edges do
        if (edge.Class == "Rue" or edge.Class == "Avenue") and edge.LengthM > 60 then
            local mid, tangent = WorldLayout.sampleAt(edge.Polyline, 0.5)
            local d = (mid.X - px) ^ 2 + (mid.Z - pz) ^ 2
            if d < bestD then
                best, bestD, bestDir = mid, d, tangent
            end
        end
    end
    if best == nil then
        return
    end
    local direction = Vector3.new(bestDir.X, 0, bestDir.Z).Unit
    local right = Vector3.new(-direction.Z, 0, direction.X)
    local position = (Vector3.new(best.X, best.Y, best.Z) + right * 2) * S
    pcall(function()
        player:RequestStreamAroundAsync(position, 10)
    end)
    local pivot = CFrame.lookAt(
        position + Vector3.new(0, 0.5 * S + 1.5, 0),
        position + Vector3.new(0, 0.5 * S + 1.5, 0) + direction
    )
    model:PivotTo(pivot)
    local body = model.PrimaryPart :: BasePart
    body.AssemblyLinearVelocity = Vector3.zero
    body.AssemblyAngularVelocity = Vector3.zero
    root.CFrame = CFrame.new(position + right * 4 * S + Vector3.new(0, 4, 0))
    ReplicatedStorage:SetAttribute("AWUI_StartVehicle", model.Name)
    record(
        "ui.serveur.info_placement_depart",
        true,
        string.format("%s posé en (%.0f, %.0f) m, à %.0f m du joueur", model.Name, best.X, best.Z, math.sqrt(bestD))
    )
end

signalEvent.OnServerEvent:Connect(function(player, name)
    if type(name) ~= "string" or string.sub(name, 1, 5) ~= "AWUI:" then
        return
    end
    if name == "AWUI:PlaceStart" and (session == "gps" or session == "ui_monde") then
        placeStart(player)
        return
    end
    -- Session ui_monde (captures) : heure, météo, point de vue (placement signalé).
    if session == "ui_monde" then
        local WorldFolder = ServerScriptService.AutomotiveWorldServer:WaitForChild("World")
        local hour = string.match(name, "^AWUI:Time:(%d+)$")
        if hour then
            local WeatherModel =
                require(ReplicatedStorage.Shared:WaitForChild("World"):WaitForChild("WeatherModel")) :: any
            local now = workspace:GetServerTimeNow()
            workspace:SetAttribute(
                "AWClockEpoch",
                now - ((tonumber(hour) :: number - WeatherModel.StartHour) % 24) / 24 * WeatherModel.DayLengthS
            )
            ReplicatedStorage:SetAttribute("AWUI_Done", name)
            return
        elseif name == "AWUI:Rain" or name == "AWUI:Clear" then
            local WeatherService = require(WorldFolder:WaitForChild("WeatherService")) :: any
            WeatherService.force(if name == "AWUI:Rain" then "Rain" else "Clear", if name == "AWUI:Rain" then 1 else 0)
            ReplicatedStorage:SetAttribute("AWUI_Done", name)
            return
        end
        local gx, gz = string.match(name, "^AWUI:Goto:(-?[%d%.]+),(-?[%d%.]+)$")
        if gx and gz then
            local position = Vector3.new(tonumber(gx) :: number * S, 0, tonumber(gz) :: number * S)
            pcall(function()
                player:RequestStreamAroundAsync(position, 15)
            end)
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = if player.Character then { player.Character } else {}
            local hit = workspace:Raycast(position + Vector3.new(0, 2000, 0), Vector3.new(0, -4000, 0), params)
            local y = if hit then hit.Position.Y + 4 else 20
            local character = player.Character
            if character then
                character:PivotTo(CFrame.new(position.X, y, position.Z))
            end
            ReplicatedStorage:SetAttribute("AWUI_Done", name)
            return
        end
    end
    ReplicatedStorage:SetAttribute("AWUI_" .. string.sub(name, 6), true)
    record("ui.serveur.info_decor", true, name .. " (" .. player.Name .. ")")
end)

-- Résumé LISIBLE de l'état autoritaire (lecture seule, aucune donnée d'un autre joueur).
local function count(list: any): number
    local n = 0
    if type(list) == "table" then
        for _ in list do
            n += 1
        end
    end
    return n
end
query.OnServerInvoke = function(player)
    local profileSession = ProfileService.get(player)
    local data = profileSession and profileSession.Data
    if data == nil then
        return { Ready = false }
    end
    local vehicles = {}
    for id, vehicle in data.Vehicles do
        table.insert(vehicles, {
            Id = id,
            Model = vehicle.ModelId or vehicle.Model,
            Kind = vehicle.Kind,
            Reserved = vehicle.Reservation ~= nil,
            Custom = vehicle.Customization,
        })
    end
    return {
        Ready = true,
        Balance = data.Wallet.Balance,
        Reserved = data.Wallet.Reserved,
        Earned = data.Wallet.Earned,
        Spent = data.Wallet.Spent,
        Vehicles = vehicles,
        VehicleCount = count(data.Vehicles),
        Properties = count(data.Properties),
        Parts = count(data.Parts),
        Invitations = count(data.Invitations),
        Transactions = count(data.Transactions),
        Jobs = data.Jobs,
        Starter = data.Starter,
        Onboarding = data.Onboarding,
        Preferences = data.Preferences,
        RacingActive = data.Racing.Active ~= nil,
        RacingStats = data.Racing.Stats,
        Reputation = data.Reputation.Points,
    }
end

local function waitFor(predicate: () -> boolean, timeout: number): boolean
    local start = os.clock()
    while os.clock() - start < timeout do
        if predicate() then
            return true
        end
        task.wait(0.2)
    end
    return predicate()
end

local joined = waitFor(function()
    return #Players:GetPlayers() >= 1
end, 60)
record("ui.serveur.joueur_connecte", joined, #Players:GetPlayers())
local gotReport = waitFor(function()
    return next(reports) ~= nil
end, 1700)
record("ui.serveur.rapport_client", gotReport)

for _, player in Players:GetPlayers() do
    local profileSession = ProfileService.get(player)
    local data = profileSession and profileSession.Data
    if data then
        local wallet = data.Wallet
        record(
            "ui.serveur.portefeuille_coherent",
            wallet.Balance >= 0 and wallet.Reserved >= 0,
            string.format("solde %d, réservé %d", wallet.Balance, wallet.Reserved)
        )
        local valid, problems = ProfileSchema.validate(data)
        record("ui.serveur.profil_coherent", valid, table.concat(problems, " ; "))
    end
end
record("ui.serveur.info_journal_validation", true, #validation .. " : " .. table.concat(validation, " || "))
record("ui.serveur.aucune_erreur_execution", #errors == 0, table.concat(errors, " || "))
record("ui.serveur.info_erreurs_internes_roblox", true, #robloxErrors .. " : " .. table.concat(robloxErrors, " || "))

StudioTestService:EndTest({
    session = session,
    players = #Players:GetPlayers(),
    server = steps,
    clients = reports,
})
