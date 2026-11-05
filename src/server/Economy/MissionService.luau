--!strict
--[[
    Missions en jeu (lot 0.5) : génération serveur, véhicule professionnel ou
    fourni temporaire, suivi par échantillons SERVEUR (5 Hz), paiement unique.

    Véhicule professionnel / fourni (AUD-ECO-01) : matérialisé pour la mission,
    au nom du joueur mais ABSENT de son profil (ni possédé, ni vendable, ni
    transférable, ni rangeable) ; session protégée (aucune écriture durable) ;
    retiré à la fin, à l'abandon ou au départ du joueur. Aucune avance de
    crédits : la rémunération est la rémunération normale de la mission.

    Paiement : transaction « Mission:<id> » (RewardModel.payout) ; réussite
    seulement si la mission est terminée ET vraisemblable ; correction de
    mouvement ou délai dépassé = échec sans paiement.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleConstants"))
local VehicleDefinitions = require(Shared:WaitForChild("Vehicles"):WaitForChild("VehicleDefinitions"))
local Jobs = require(Shared:WaitForChild("Economy"):WaitForChild("Jobs"))
local Reputation = require(Shared.Economy.Reputation)

local Persistence = script.Parent.Parent.Persistence
local ProfileService = require(Persistence.ProfileService)
local VehicleService = require(script.Parent.Parent.Vehicles.VehicleService)
local ProgressionService = require(script.Parent.Parent.Progression.ProgressionService)
local MissionEngine = require(script.Parent.MissionEngine)
local MissionGenerator = require(script.Parent.MissionGenerator)
local MissionPlaces = require(script.Parent.MissionPlaces)
local RewardModel = require(script.Parent.RewardModel)

local MissionService = {}

local S = 1 / Constants.MetersPerStud
local SAMPLE_S = 0.2
local START_COOLDOWN_S = 10

type Active = {
    Mission: any,
    State: any,
    Vehicle: Model?, -- véhicule professionnel / fourni
    Props: { Instance },
    LastCorrections: number,
    Finishing: boolean,
}

local active: { [Player]: Active } = {}
local lastStart: { [Player]: number } = {}
local places: MissionPlaces.Places
local folder: Folder
local notify: (Player, string, any) -> () = function(_player: Player, _kind: string, _data: any) end

local function rootOf(player: Player): BasePart?
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return if root and root:IsA("BasePart") then root else nil
end

-- Modèle de véhicule conduit par le joueur (siège conducteur occupé).
local function drivenModel(player: Player): Model?
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local seat = humanoid and humanoid.SeatPart
    if seat then
        return seat:FindFirstAncestorWhichIsA("Model")
    end
    return nil
end

local function vehicleIdOf(model: Model?): string?
    if model == nil then
        return nil
    end
    local personal = model:GetAttribute("PersonalVehicleId")
    if type(personal) == "string" then
        return personal
    end
    return model.Name
end

-- Emplacement libre à côté du joueur pour un véhicule temporaire.
local function spawnBeside(player: Player, modelId: string, vehicleId: string): Model?
    local root = rootOf(player)
    local definition = VehicleDefinitions.get(modelId)
    if root == nil or definition == nil then
        return nil
    end
    local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
    if look.Magnitude < 1e-3 then
        look = Vector3.new(0, 0, -1)
    end
    local right = Vector3.new(-look.Unit.Z, 0, look.Unit.X)
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = if player.Character then { player.Character } else {}
    for _, offset in { 10, -10, 18, -18 } do
        local position = root.Position + right * offset
        local frame = CFrame.lookAt(position, position + look.Unit)
        local size = Vector3.new(definition.Chassis.WidthM * S + 3, 7, definition.Chassis.LengthM * S + 3)
        local blocking = Workspace:GetPartBoundsInBox(frame * CFrame.new(0, size.Y / 2 + 1, 0), size, params)
        local solid = 0
        for _, part in blocking do
            if part.CanCollide and part.Transparency < 1 then
                solid += 1
            end
        end
        if solid == 0 then
            local userId = player.UserId
            return VehicleService.spawnPersonal({
                Definition = definition,
                Pivot = frame * CFrame.new(0, definition.Chassis.CgHeightM * S + 1, 0),
                OwnerUserId = userId,
                VehicleId = vehicleId,
                Protected = true, -- aucune écriture durable : véhicule de mission
                MayDrive = function(candidate: Player): boolean
                    return candidate.UserId == userId
                end,
                EnergyFraction = 1,
                Damage = nil,
                TuningSpec = HttpService:JSONEncode({ Tuning = {}, Parts = {} }),
            })
        end
    end
    return nil
end

-- Véhicule immobilisé (assistance) : maquette ancrée au bord de la route.
local function breakdownProp(point: MissionPlaces.Point): Model
    local model = Instance.new("Model")
    model.Name = "VehiculeEnPanne"
    local body = Instance.new("Part")
    body.Name = "Caisse"
    body.Anchored = true
    body.Size = Vector3.new(1.9, 1.1, 4.4) * S
    body.Color = Color3.fromRGB(120, 120, 128)
    local position = Vector3.new(point.X * S, 0, point.Z * S)
    local hit = Workspace:Raycast(position + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0))
    local ground = if hit then hit.Position.Y else 0
    body.CFrame = CFrame.new(position.X, ground + body.Size.Y / 2 + 1, position.Z)
    body.Parent = model
    local light = Instance.new("Part")
    light.Name = "Feux"
    light.Anchored = true
    light.CanCollide = false
    light.Material = Enum.Material.Neon
    light.Color = Color3.fromRGB(255, 160, 30)
    light.Size = Vector3.new(1, 0.4, 0.4)
    light.CFrame = body.CFrame * CFrame.new(0, body.Size.Y / 2 + 0.3, 0)
    light.Parent = model
    model.PrimaryPart = body
    model.Parent = folder
    return model
end

local function cleanup(player: Player)
    local entry = active[player]
    if entry == nil then
        return
    end
    if entry.Vehicle then
        VehicleService.despawnPersonal(entry.Vehicle :: Model)
    end
    for _, prop in entry.Props do
        prop:Destroy()
    end
    active[player] = nil
end

-- Clôture : versement (ou échec) dans une transaction unique, puis nettoyage.
local function finish(player: Player, entry: Active)
    local mission, state = entry.Mission, entry.State
    local completed = state.Status == "Completed" and MissionEngine.plausible(state, mission)
    local quality = if completed then MissionEngine.quality(state, mission) else 0
    local session = ProfileService.get(player)
    local result: any = nil
    if session then
        result = session:commit("Mission:" .. mission.Id, "Mission", function(profile)
            return RewardModel.payout(profile, mission, completed, quality, os.time())
        end)
    end
    cleanup(player)
    notify(player, "MissionEnded", {
        Job = mission.Job,
        Completed = completed,
        Reason = state.FailReason,
        Quality = quality,
        Status = if result then result.Status else "Unavailable",
        Credits = if result and result.Result then result.Result.Credits else 0,
        Reputation = if result and result.Result then result.Result.Reputation else 0,
    })
end

function MissionService.start(player: Player, jobId: any): (string, any)
    if type(jobId) ~= "string" or Jobs.get(jobId) == nil then
        return "Rejected", "JobUnknown"
    end
    if active[player] then
        return "Rejected", "MissionAlreadyActive"
    end
    local now = os.clock()
    if lastStart[player] and now - (lastStart[player] :: number) < START_COOLDOWN_S then
        return "Rejected", "RateLimited"
    end
    local session = ProfileService.get(player)
    if session == nil or session.State ~= "Active" then
        return "Unavailable", "ProfileUnavailable"
    end
    local root = rootOf(player)
    if root == nil then
        return "Rejected", "NoCharacter"
    end
    local job = Jobs.get(jobId) :: Jobs.Job
    local level = Reputation.level((session.Data :: any).Reputation.Points).Index
    local id = HttpService:GenerateGUID(false)
    local random = Random.new()
    local mission, err = MissionGenerator.generate(
        jobId,
        id,
        player.UserId,
        { X = root.Position.X / S, Z = root.Position.Z / S },
        places,
        level,
        function()
            return random:NextNumber()
        end,
        os.time()
    )
    if mission == nil then
        return "Rejected", err
    end
    local vehicle: Model? = nil
    local ownModel = ProgressionService.outVehicle(player)
    local needsProvided = job.Vehicle == "Provided" or (job.Vehicle == "Professional" and ownModel == nil)
    if needsProvided then
        if drivenModel(player) ~= nil then
            return "Rejected", "LeaveVehicleFirst"
        end
        local providedId = "PRO-" .. id
        vehicle = spawnBeside(player, job.ProfessionalModel or "proto_p02", providedId)
        if vehicle == nil then
            return "Rejected", "NoSpaceForVehicle"
        end
        mission.ProvidedVehicleId = providedId
    end
    lastStart[player] = now
    local props: { Instance } = {}
    if jobId == "Assistance" then
        local point = mission.Steps[1].Point
        table.insert(props, breakdownProp(point))
    end
    local corrections = 0
    if vehicle then
        local _, count = VehicleService.vehicleState(vehicle :: Model)
        corrections = count
    end
    active[player] = {
        Mission = mission,
        State = MissionEngine.start(mission, Workspace:GetServerTimeNow()),
        Vehicle = vehicle,
        Props = props,
        LastCorrections = corrections,
        Finishing = false,
    }
    return "Ok", { MissionId = id, Professional = vehicle ~= nil }
end

function MissionService.abandon(player: Player): (string, any)
    local entry = active[player]
    if entry == nil then
        return "Rejected", "NoMission"
    end
    if entry.Finishing then
        return "Rejected", "MissionEnding"
    end
    entry.Finishing = true
    entry.State.Status = "Failed"
    entry.State.FailReason = "Abandoned"
    finish(player, entry)
    return "Ok", nil
end

-- Mission en cours, pour l'interface (étape, point à rejoindre, temps restant).
-- Lot 0.8 : véhicule temporaire protégé à côté du joueur (essais du parcours d'arrivée).
function MissionService.spawnBeside(player: Player, modelId: string, vehicleId: string): Model?
    return spawnBeside(player, modelId, vehicleId)
end

function MissionService.snapshot(player: Player): any
    local entry = active[player]
    if entry == nil then
        return nil
    end
    local mission, state = entry.Mission, entry.State
    local step = mission.Steps[state.StepIndex]
    return {
        Id = mission.Id,
        Job = mission.Job,
        Difficulty = mission.Difficulty,
        Premium = mission.Premium,
        StepIndex = state.StepIndex,
        Steps = #mission.Steps,
        Label = if step then step.Label else "",
        Point = if step and step.Point then step.Point else nil,
        Hazards = mission.Hazards,
        TimeLeft = math.max(0, mission.TimeLimitS - (Workspace:GetServerTimeNow() - state.StartedAt)),
        EstimatedS = mission.EstimatedS,
        Professional = entry.Vehicle ~= nil,
    }
end

local function sample(player: Player, entry: Active)
    local root = rootOf(player)
    if root == nil then
        return
    end
    local model = drivenModel(player)
    local body: BasePart = root
    local primary = if model then model.PrimaryPart else nil
    -- Lot 0.8 : un véhicule d'essai (parcours d'arrivée) ne fait jamais progresser une mission.
    local inVehicle = primary ~= nil and not (model and model:GetAttribute("AWTestDrive") == true)
    if primary then
        body = primary
    end
    local position = body.Position
    local velocity = body.AssemblyLinearVelocity
    local look = body.CFrame.LookVector
    local wear, corrections = 0, 0
    if model then
        wear, corrections = VehicleService.vehicleState(model)
    end
    local corrected = false
    if entry.Vehicle and model == entry.Vehicle then
        corrected = corrections > entry.LastCorrections
        entry.LastCorrections = corrections
    end
    MissionEngine.observe(entry.State, entry.Mission, {
        T = Workspace:GetServerTimeNow(),
        X = position.X / S,
        Z = position.Z / S,
        Heading = MissionPlaces.heading(look.X, look.Z),
        SpeedMs = velocity.Magnitude * Constants.MetersPerStud,
        InVehicle = inVehicle,
        VehicleId = vehicleIdOf(model),
        Damage = wear,
        Corrected = corrected,
    })
end

function MissionService.start_(openWorld: boolean, notifier: (Player, string, any) -> ())
    places = if openWorld then MissionPlaces.openWorld() else MissionPlaces.dev()
    notify = notifier
    folder = Instance.new("Folder")
    folder.Name = "Missions"
    folder.Parent = Workspace
    local accumulator = 0
    RunService.Heartbeat:Connect(function(dt)
        accumulator += dt
        if accumulator < SAMPLE_S then
            return
        end
        accumulator = 0
        for player, entry in active do
            if entry.Finishing then
                continue
            end
            sample(player, entry)
            if entry.State.Status ~= "Active" then
                -- Une seule clôture (le versement peut céder la main).
                entry.Finishing = true
                task.spawn(finish, player, entry)
            end
        end
    end)
    -- Départ du joueur : mission abandonnée sans paiement, véhicule retiré.
    Players.PlayerRemoving:Connect(function(player)
        cleanup(player)
        lastStart[player] = nil
    end)
end

return MissionService
