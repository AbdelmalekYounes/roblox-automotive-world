--!strict
--[[
    Menu d'administration — service AUTORITAIRE (lot ADMIN-01, décisions du propriétaire du 2026-11-05).

    - Droits lus côté serveur (AdminConfig) ; le joueur administrateur reçoit l'attribut AWAdmin (affichage du menu
      seulement : le serveur revérifie chaque demande). Actif dans tous les environnements (A1).
    - Un seul point d'entrée (ReplicatedStorage.AWAdmin.Request) : liste FERMÉE d'actions (AdminRules), paramètres
      validés, limite de débit ; un non-administrateur est refusé et consigné.
    - Journal : chaque action (qui, quoi, sur qui, résultat) dans un journal circulaire et dans la sortie du serveur.
    - Crédits et réputation : transactions identifiées du profil (motif « AdminGrant »), jamais une écriture directe ;
      100 000 crédits au plus par action (A4).
    - Véhicules apparus : TEMPORAIRES (A3), retirés à la demande ou au départ de l'administrateur.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AdminRules = require(Shared:WaitForChild("Admin"):WaitForChild("AdminRules"))
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))
local VehicleDefinitions = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleDefinitions"))

local Server = script.Parent.Parent
local AdminConfig = require(script.Parent.AdminConfig)
local ProfileService = require(Server.Persistence.ProfileService)
local ProfileSchema = require(Server.Persistence.ProfileSchema)
local Wallet = require(Server.Economy.Wallet)
local EconomyService = require(Server.Economy.EconomyService)
local MissionService = require(Server.Economy.MissionService)
local RaceService = require(Server.Racing.RaceService)
local VehicleService = require(Server.Vehicles.VehicleService)
local WeatherService = require(Server.World.WeatherService)
local InterfaceService = require(Server.Social.InterfaceService)
local RateLimiter = require(Server.Security.RateLimiter)

local AdminService = {}

local FOLDER = "AWAdmin"
local METERS_PER_STUD = Constants.MetersPerStud

local started = false
local push: RemoteEvent
local journal: { AdminRules.LogEntry } = {}
local limiters: { [Player]: RateLimiter.Bucket } = {}
local spawned: { [Player]: { Model } } = {}
local walkSpeeds: { [Player]: number } = {}
local invisible: { [Player]: boolean } = {}

local function isAdmin(player: Player): boolean
    return AdminRules.isAdmin(player.UserId, AdminConfig.AdminUserIds)
end

local function ok(result: any?): any
    return { Status = "Ok", Result = result }
end

local function rejected(key: string): any
    return { Status = "Rejected", Error = key }
end

local function record(admin: Player, action: string, target: number?, detail: string, result: string)
    local entry: AdminRules.LogEntry = {
        At = os.time(),
        AdminId = admin.UserId,
        AdminName = admin.Name,
        Action = action,
        Target = target,
        Detail = detail,
        Result = result,
    }
    AdminRules.logPush(journal, entry)
    print(
        string.format(
            "[AutomotiveWorld][Admin] %s (%d) : %s%s%s → %s",
            admin.Name,
            admin.UserId,
            action,
            if target then " sur " .. tostring(target) else "",
            if detail ~= "" then " (" .. detail .. ")" else "",
            result
        )
    )
end

local function characterOf(player: Player): (Model?, Humanoid?, BasePart?)
    local character = player.Character
    if character == nil then
        return nil, nil, nil
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    return character, humanoid, if root and root:IsA("BasePart") then root else nil
end

-- Sol sous un point (rayon vertical), personnages exclus. Repli : hauteur de sécurité.
local function groundAt(x: number, z: number): Vector3
    local params = RaycastParams.new()
    local exclude: { Instance } = {}
    for _, other in Players:GetPlayers() do
        if other.Character then
            table.insert(exclude, other.Character)
        end
    end
    params.FilterDescendantsInstances = exclude
    params.FilterType = Enum.RaycastFilterType.Exclude
    local hit = Workspace:Raycast(Vector3.new(x, 2000, z), Vector3.new(0, -4000, 0), params)
    return if hit then hit.Position + Vector3.new(0, 5, 0) else Vector3.new(x, 60, z)
end

-- Déplace le personnage d'un joueur (refusé s'il est assis : le véhicule ne suit pas).
local function moveCharacter(player: Player, position: Vector3): string?
    local character, humanoid = characterOf(player)
    if character == nil or humanoid == nil then
        return "AdminNoCharacter"
    end
    if humanoid.SeatPart ~= nil then
        return "LeaveVehicleFirst"
    end
    character:PivotTo(CFrame.new(position))
    return nil
end

local function applyInvisible(player: Player, on: boolean)
    local character = player.Character
    if character == nil then
        return
    end
    for _, item in character:GetDescendants() do
        if item:IsA("BasePart") or item:IsA("Decal") then
            local saved = item:GetAttribute("AWAdminTransparency")
            if on then
                if saved == nil then
                    item:SetAttribute("AWAdminTransparency", (item :: any).Transparency)
                end
                (item :: any).Transparency = 1
            elseif type(saved) == "number" then
                (item :: any).Transparency = saved
                item:SetAttribute("AWAdminTransparency", nil)
            end
        end
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.DisplayDistanceType = if on
            then Enum.HumanoidDisplayDistanceType.None
            else Enum.HumanoidDisplayDistanceType.Viewer
    end
end

local function removeSpawned(player: Player): number
    local list = spawned[player]
    spawned[player] = nil
    local count = 0
    for _, model in (list or {}) :: { Model } do
        if model.Parent then
            VehicleService.despawnPersonal(model)
            count += 1
        end
    end
    return count
end

-- État affiché par le menu (lecture seule).
local function snapshot(player: Player): any
    local environment = ProfileService.environment()
    local session = ProfileService.get(player)
    local profile = if session then session.Data else nil
    local hour, speed = WeatherService.clock()
    local players = {}
    for _, other in Players:GetPlayers() do
        table.insert(players, { UserId = other.UserId, Name = other.Name, Display = other.DisplayName })
    end
    local points = {}
    for _, point in InterfaceService.publicPoints() do
        table.insert(points, { Id = point.Id, Name = point.Name, Kind = point.Kind })
    end
    local models = {}
    for _, definition in VehicleDefinitions.all() do
        table.insert(models, { Id = definition.Id, Name = definition.DisplayName })
    end
    local driven = VehicleService.drivenBy(player)
    return {
        Environment = { Name = environment.Name, Store = environment.Store, Reason = environment.Reason },
        Profile = if session
            then {
                State = session.State,
                Dirty = session:dirty(),
                SchemaVersion = if profile then profile.SchemaVersion else nil,
                Balance = if profile then profile.Wallet.Balance else nil,
                Reputation = if profile then profile.Reputation.Points else nil,
                Vehicles = if profile
                    then (function()
                        local n = 0
                        for _ in profile.Vehicles do
                            n += 1
                        end
                        return n
                    end)()
                    else 0,
            }
            else nil,
        Clock = { Hour = hour, Speed = speed },
        Weather = WeatherService.state(),
        Players = players,
        Points = points,
        Models = models,
        Spawned = #(spawned[player] or {}),
        Me = {
            Driving = driven ~= nil,
            Invulnerable = driven ~= nil and driven:GetAttribute("AWAdminInvulnerable") == true,
            Noclip = player:GetAttribute("AWAdminNoclip") == true,
            NoclipSpeed = player:GetAttribute("AWAdminNoclipSpeed"),
            Invisible = invisible[player] == true,
            WalkSpeed = walkSpeeds[player] or AdminRules.WalkSpeed.Default,
            Mission = MissionService.snapshot(player) ~= nil,
        },
        Limits = {
            MaxCredits = AdminRules.MaxCreditGrant,
            ReputationMax = AdminRules.ReputationMax,
            WalkSpeed = AdminRules.WalkSpeed,
            NoclipSpeed = AdminRules.NoclipSpeed,
            ClockSpeed = AdminRules.ClockSpeed,
        },
        Journal = journal,
    }
end

local handlers: { [string]: (Player, any) -> (any, number?, string?) } = {}

handlers.Snapshot = function(player, _p)
    return ok(snapshot(player))
end

handlers.SetClock = function(_player, p)
    WeatherService.setClock(p.Hour, nil)
    return ok(), nil, string.format("%.2f h", p.Hour)
end

handlers.SetClockSpeed = function(_player, p)
    WeatherService.setClock(nil, p.Speed)
    return ok(), nil, string.format("× %g", p.Speed)
end

handlers.SetWeather = function(_player, p)
    WeatherService.force(p.State :: any, if p.State == "Rain" or p.State == "Storm" then 0.8 else 0)
    return ok(), nil, p.State
end

handlers.SpawnVehicle = function(player, p)
    if VehicleDefinitions.get(p.ModelId) == nil then
        return rejected("AdminModelUnknown")
    end
    local _, humanoid = characterOf(player)
    if humanoid and humanoid.SeatPart ~= nil then
        return rejected("LeaveVehicleFirst")
    end
    local model =
        MissionService.spawnBeside(player, p.ModelId, "ADMIN-" .. string.sub(HttpService:GenerateGUID(false), 1, 8))
    if model == nil then
        return rejected("NoSpaceForVehicle")
    end
    model:SetAttribute("AWAdminSpawned", true)
    local list = spawned[player] or {}
    table.insert(list, model)
    spawned[player] = list
    return ok({ Name = model.Name }), nil, p.ModelId
end

handlers.RemoveSpawned = function(player, _p)
    local count = removeSpawned(player)
    return ok({ Count = count }), nil, tostring(count)
end

handlers.RepairVehicle = function(player, p)
    local model = VehicleService.drivenBy(player)
    if model == nil then
        return rejected("AdminNotDriving")
    end
    if not VehicleService.adminRepair(model, p.RefillEnergy) then
        return rejected("AdminVehicleUnknown")
    end
    return ok(), nil, if p.RefillEnergy then "plein compris" else ""
end

handlers.FlipVehicle = function(player, _p)
    local model = VehicleService.drivenBy(player)
    if model == nil then
        return rejected("AdminNotDriving")
    end
    if not VehicleService.adminFlip(model) then
        return rejected("AdminVehicleUnknown")
    end
    return ok()
end

handlers.SetInvulnerable = function(player, p)
    local model = VehicleService.drivenBy(player)
    if model == nil then
        return rejected("AdminNotDriving")
    end
    model:SetAttribute("AWAdminInvulnerable", if p.On then true else nil)
    return ok(), nil, tostring(p.On)
end

handlers.SetNoclip = function(player, p)
    local _, humanoid = characterOf(player)
    if p.On and humanoid and humanoid.SeatPart ~= nil then
        return rejected("LeaveVehicleFirst")
    end
    -- Le client du joueur applique le déplacement libre (personnage sous sa propriété réseau) ; le serveur
    -- l'autorise par ces attributs et le consigne.
    player:SetAttribute("AWAdminNoclip", if p.On then true else nil)
    player:SetAttribute("AWAdminNoclipSpeed", p.Speed)
    return ok(), nil, string.format("%s, %g st/s", tostring(p.On), p.Speed)
end

handlers.Teleport = function(player, p)
    for _, point in InterfaceService.publicPoints() do
        if point.Id == p.PointId then
            local err = moveCharacter(player, groundAt(point.X / METERS_PER_STUD, point.Z / METERS_PER_STUD))
            if err then
                return rejected(err)
            end
            return ok(), nil, point.Name
        end
    end
    return rejected("AdminPointUnknown")
end

handlers.TeleportToPlayer = function(player, p)
    local target = Players:GetPlayerByUserId(p.UserId)
    local root: BasePart? = nil
    if target then
        local _, _, found = characterOf(target)
        root = found
    end
    if root == nil then
        return rejected("AdminPlayerAbsent")
    end
    local err = moveCharacter(player, (root :: BasePart).Position + Vector3.new(4, 2, 0))
    if err then
        return rejected(err)
    end
    return ok(), p.UserId
end

handlers.BringPlayer = function(player, p)
    local target = Players:GetPlayerByUserId(p.UserId)
    local _, _, root = characterOf(player)
    if target == nil or root == nil then
        return rejected("AdminPlayerAbsent")
    end
    local err = moveCharacter(target, (root :: BasePart).Position + Vector3.new(4, 2, 0))
    if err then
        return rejected(err)
    end
    return ok(), p.UserId
end

handlers.Respawn = function(player, _p)
    player:LoadCharacter()
    return ok()
end

handlers.SetWalkSpeed = function(player, p)
    local _, humanoid = characterOf(player)
    if humanoid == nil then
        return rejected("AdminNoCharacter")
    end
    walkSpeeds[player] = p.Value
    humanoid.WalkSpeed = p.Value
    return ok(), nil, string.format("%g st/s", p.Value)
end

handlers.SetInvisible = function(player, p)
    if p.On then
        invisible[player] = true
    else
        invisible[player] = nil
    end
    applyInvisible(player, p.On)
    return ok(), nil, tostring(p.On)
end

handlers.GrantCredits = function(player, p)
    local target, session = ProfileService.byUserId(p.UserId)
    if target == nil or session == nil then
        return rejected("AdminPlayerAbsent")
    end
    local txId = "Admin:Credit:" .. HttpService:GenerateGUID(false)
    local result = session:commit(txId, "AdminGrant", function(profile)
        return Wallet.credit(profile, p.Amount, "AdminGrant", "admin:" .. tostring(player.UserId), os.time())
    end)
    if result.Status ~= "Confirmed" and result.Status ~= "Pending" then
        return rejected(result.Error or "AdminGrantFailed")
    end
    EconomyService.refresh(target)
    return ok({ Status = result.Status }), p.UserId, string.format("%d crédits (%s)", p.Amount, result.Status)
end

handlers.SetReputation = function(player, p)
    local session = ProfileService.get(player)
    if session == nil then
        return rejected("AdminNoProfile")
    end
    local txId = "Admin:Reputation:" .. HttpService:GenerateGUID(false)
    local result = session:commit(txId, "AdminReputation", function(profile)
        profile.Reputation.Points = p.Points
        return true, { Points = p.Points }
    end)
    if result.Status ~= "Confirmed" and result.Status ~= "Pending" then
        return rejected(result.Error or "AdminReputationFailed")
    end
    EconomyService.refresh(player)
    return ok(), nil, string.format("%d points (%s)", p.Points, result.Status)
end

handlers.AbandonMission = function(player, _p)
    local status, err = MissionService.abandon(player)
    if status ~= "Ok" then
        return rejected(tostring(err))
    end
    return ok()
end

handlers.ResetProfile = function(player, _p)
    -- Repartir comme un nouveau joueur : jamais sur les données de production.
    local environment = ProfileService.environment()
    if environment.Name ~= "Dev" and environment.Name ~= "Test" then
        return rejected("AdminResetRefusedProd")
    end
    local session = ProfileService.get(player)
    if session == nil then
        return rejected("AdminNoProfile")
    end
    local txId = "Admin:Reset:" .. HttpService:GenerateGUID(false)
    local result = session:commit(txId, "AdminReset", function(profile)
        local fresh = ProfileSchema.new(player.UserId, os.time(), environment.Name) :: any
        local target = profile :: any
        for key in table.clone(target) do
            target[key] = nil
        end
        for key, value in fresh do
            target[key] = value
        end
        return true, nil
    end)
    if result.Status ~= "Confirmed" and result.Status ~= "Pending" then
        return rejected(result.Error or "AdminResetFailed")
    end
    -- Reconnexion nécessaire : garages, véhicules sortis et parcours d'arrivée sont relus au chargement.
    task.delay(1, function()
        if player.Parent then
            player:Kick("Profil réinitialisé par le menu d'administration : reconnectez-vous.")
        end
    end)
    return ok(), nil, environment.Name
end

handlers.ForceRaceStart = function(player, _p)
    local done, err = RaceService.adminForceStart(player.UserId)
    if not done then
        return rejected(err or "AdminNoRace")
    end
    return ok()
end

handlers.Kick = function(player, p)
    if p.UserId == player.UserId then
        return rejected("AdminSelf")
    end
    local target = Players:GetPlayerByUserId(p.UserId)
    if target == nil then
        return rejected("AdminPlayerAbsent")
    end
    target:Kick("Expulsé par un administrateur : " .. p.Reason)
    return ok(), p.UserId, p.Reason
end

local function handle(player: Player, action: any, payload: any): any
    if not isAdmin(player) then
        warn(
            string.format(
                "[AutomotiveWorld][Admin] Demande refusée : %s (%d) n'est pas administrateur (%s).",
                player.Name,
                player.UserId,
                tostring(action)
            )
        )
        return rejected("AdminNotAllowed")
    end
    local bucket = limiters[player]
    if bucket == nil then
        bucket = RateLimiter.new(10, 4, os.clock())
        limiters[player] = bucket
    end
    if not RateLimiter.consume(bucket, os.clock()) then
        return rejected("RateLimited")
    end
    local valid, clean = AdminRules.validate(action, payload)
    if not valid then
        return rejected(clean)
    end
    local done, response, target, detail = pcall(handlers[action], player, clean)
    if not done then
        warn("[AutomotiveWorld][Admin] Erreur de l'action " .. tostring(action) .. " : " .. tostring(response))
        response = rejected("ServerError")
    end
    if AdminRules.logged(action) then
        record(
            player,
            action,
            target,
            detail or "",
            if response.Status == "Ok" then "OK" else ("refus : " .. tostring(response.Error))
        )
        push:FireClient(player, "Journal", journal)
    end
    return response
end

local function onCharacter(player: Player, character: Model)
    local humanoid = character:WaitForChild("Humanoid", 10)
    if humanoid and humanoid:IsA("Humanoid") and walkSpeeds[player] then
        humanoid.WalkSpeed = walkSpeeds[player]
    end
    if invisible[player] then
        task.defer(applyInvisible, player, true)
    end
end

local function onPlayer(player: Player)
    if isAdmin(player) then
        player:SetAttribute("AWAdmin", true)
    end
    player.CharacterAdded:Connect(function(character)
        onCharacter(player, character)
    end)
end

function AdminService.start()
    assert(not started, "AdminService déjà démarré")
    started = true
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
    for _, player in Players:GetPlayers() do
        onPlayer(player)
    end
    Players.PlayerAdded:Connect(onPlayer)
    Players.PlayerRemoving:Connect(function(player)
        removeSpawned(player)
        limiters[player] = nil
        walkSpeeds[player] = nil
        invisible[player] = nil
    end)
end

-- Journal (essais).
function AdminService.journal(): { AdminRules.LogEntry }
    return journal
end

return table.freeze(AdminService)
