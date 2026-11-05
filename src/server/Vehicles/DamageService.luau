--!strict
-- Dégâts en session, confirmés côté serveur (AUD-COLL-01, AUD-PHYS-01).
--
-- Un choc n'est retenu que si le SERVEUR l'observe lui-même :
-- 1. variation de vitesse horizontale qu'aucun pneu ne peut produire (au-delà
--    de la décélération maximale d'un freinage, avec marge) sur une courte
--    fenêtre, à partir des positions/vitesses répliquées ou simulées ;
-- 2. obstacle réellement au contact : une pièce collisionnable dans la boîte
--    englobante élargie du véhicule, au-dessus des roues (le sol et les
--    bordures basses ne comptent pas), dans le sens du choc.
-- Aucune valeur envoyée par un client n'intervient. Pour deux véhicules, le Δv
-- infligé à l'autre est borné par un vrai choc de carrosseries à la vitesse de
-- rapprochement observée (prudence sans immunité : un client ne peut pas
-- « fabriquer » des dégâts chez un autre joueur sans le percuter réellement).
-- Les corrections et repositionnements du serveur suspendent la détection.
--
-- Effets : état `DamageModel` publié en attributs (lus par la simulation du
-- propriétaire), et éléments visuels temporaires originaux (primitives), sans
-- toucher à la géométrie de collision. Aucune persistance (lot 0.4).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local VehiclesShared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Vehicles")
local Types = require(VehiclesShared:WaitForChild("VehicleTypes"))
local Constants = require(VehiclesShared:WaitForChild("VehicleConstants"))
local DamageModel = require(VehiclesShared:WaitForChild("Physics"):WaitForChild("DamageModel"))
local PerfStats = require(VehiclesShared:WaitForChild("PerfStats"))

local METERS_PER_STUD = Constants.MetersPerStud
local STUDS_PER_METER = 1 / METERS_PER_STUD
local HISTORY_S = 0.35
-- Décélération maximale qu'un pneu peut produire (m/s²), marge comprise, et
-- tolérance fixe (bruit de réplication).
local TIRE_LIMIT_MS2 = 1.3 * 1.25 * 9.81
local TOLERANCE_MS = 0.8
local CONTACT_MARGIN_STUDS = 1.2
local VEHICLE_COOLDOWN_S = 0.4
-- Durée de suivi d'un choc : la variation de vitesse TOTALE est mesurée sur cette
-- durée, puis appliquée une seule fois (mesuré dans Studio : sans suivi, un choc à
-- 35 km/h était découpé en petits chocs de ~2 m/s par l'arrivée des données répliquées).
local EVENT_S = 0.4
local PAIR_COOLDOWN_S = 1.2
local RESTITUTION = 0.3

type ImpactEvent = {
    Start: number,
    Before: Vector3,
    Push: Vector3,
    PeakExcess: number,
    Obstacle: string,
    Other: any?,
    OtherBefore: Vector3,
}

export type Entry = {
    Model: Model,
    Root: BasePart,
    Definition: Types.VehicleDefinition,
    State: DamageModel.DamageState,
    History: { { Time: number, Velocity: Vector3 } },
    CooldownUntil: number,
    SuspendedUntil: number,
    Event: ImpactEvent?,
    Visual: { [string]: number }, -- niveau visuel appliqué par zone
    Smoke: boolean,
}

export type ImpactRecord = {
    Vehicle: string,
    Zone: string,
    DeltaV: number,
    Level: number,
    Obstacle: string,
    Mechanical: boolean,
}

type ServiceFields = {
    Entries: { Entry },
    ByModel: { [Model]: Entry },
    PairCooldowns: { [string]: number },
    Overlap: OverlapParams,
    Impacts: { ImpactRecord },
    Unconfirmed: number,
    StepTimes: PerfStats.Window,
    Queries: number,
}

local DamageService = {}
DamageService.__index = DamageService

export type Service = typeof(setmetatable({} :: ServiceFields, DamageService))

function DamageService.new(): Service
    local overlap = OverlapParams.new()
    overlap.FilterType = Enum.RaycastFilterType.Exclude
    overlap.RespectCanCollide = true
    return setmetatable(
        {
            Entries = {},
            ByModel = {},
            PairCooldowns = {},
            Overlap = overlap,
            Impacts = {},
            Unconfirmed = 0,
            StepTimes = PerfStats.new(1200),
            Queries = 0,
        } :: ServiceFields,
        DamageService
    )
end

local function publish(entry: Entry)
    for name, value in DamageModel.toAttributes(entry.State) do
        entry.Model:SetAttribute(name, value)
    end
end

function DamageService.register(self: Service, model: Model, definition: Types.VehicleDefinition): Entry
    local entry: Entry = {
        Model = model,
        Root = model.PrimaryPart :: BasePart,
        Definition = definition,
        State = DamageModel.new(),
        History = {},
        CooldownUntil = 0,
        SuspendedUntil = 0,
        Event = nil,
        Visual = { Front = 0, Rear = 0, Left = 0, Right = 0 },
        Smoke = false,
    }
    table.insert(self.Entries, entry)
    self.ByModel[model] = entry
    publish(entry)
    return entry
end

-- Repositionnement par le serveur (correction, retour au plot, remise sur
-- roues) : la discontinuité de vitesse n'est pas un choc.
function DamageService.suspend(self: Service, model: Model, seconds: number)
    local entry = self.ByModel[model]
    if entry then
        entry.SuspendedUntil = math.max(entry.SuspendedUntil, os.clock() + seconds)
        table.clear(entry.History)
    end
end

function DamageService.getState(self: Service, model: Model): DamageModel.DamageState?
    local entry = self.ByModel[model]
    return if entry then entry.State else nil
end

local function horizontal(v: Vector3): Vector3
    return Vector3.new(v.X, 0, v.Z)
end

local function pairKey(a: Model, b: Model): string
    local x, y = a:GetFullName(), b:GetFullName()
    return if x < y then x .. "|" .. y else y .. "|" .. x
end

-- ÉLÉMENTS VISUELS TEMPORAIRES (primitives originales, sans masse ni collision).

local function damageFolder(model: Model): Folder
    local existing = model:FindFirstChild("Degats")
    if existing and existing:IsA("Folder") then
        return existing
    end
    local folder = Instance.new("Folder")
    folder.Name = "Degats"
    folder.Parent = model
    return folder
end

local function addDecor(
    entry: Entry,
    name: string,
    size: Vector3,
    offset: CFrame,
    color: Color3,
    material: Enum.Material?
)
    local root = entry.Root
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.CFrame = root.CFrame * offset
    part.Color = color
    part.Material = material or Enum.Material.SmoothPlastic
    part.Massless = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = root
    weld.Part1 = part
    weld.Parent = part
    part.Parent = damageFolder(entry.Model)
end

-- Repère local d'une pièce de carrosserie (nil si absente).
local function bodyPart(entry: Entry, name: string): BasePart?
    local body = entry.Model:FindFirstChild("Carrosserie")
    local part = if body then body:FindFirstChild(name) else nil
    return if part and part:IsA("BasePart") then part else nil
end

local function breakLight(entry: Entry, name: string)
    local light = bodyPart(entry, name)
    if light and light.Material == Enum.Material.Neon then
        light.Material = Enum.Material.Glass
        light.Color = Color3.fromRGB(60, 60, 64)
    end
end

-- Panneau déformé : l'original (collisionnable) devient invisible, une copie
-- visuelle inclinée et enfoncée prend sa place. La collision ne change pas.
local function deformPanel(entry: Entry, name: string, angle: number, inset: number, drop: number)
    local panel = bodyPart(entry, name)
    if panel == nil then
        return
    end
    local localCFrame = entry.Root.CFrame:ToObjectSpace(panel.CFrame)
    local direction = if localCFrame.Position.Z < 0 then 1 else -1
    panel.Transparency = 1
    local folder = damageFolder(entry.Model)
    local previous = folder:FindFirstChild(name .. "Deforme")
    if previous then
        previous:Destroy()
    end
    addDecor(
        entry,
        name .. "Deforme",
        panel.Size,
        localCFrame * CFrame.new(0, -drop, inset * direction) * CFrame.Angles(math.rad(angle), 0, math.rad(angle * 0.4)),
        panel.Color,
        panel.Material
    )
end

local ZONE_PANEL: { [string]: string } = {
    Front = "BouclierAvant",
    Rear = "BouclierArriere",
}

local function applyVisuals(entry: Entry)
    local chassis = entry.Definition.Chassis
    local halfWidth = chassis.WidthM * STUDS_PER_METER / 2
    local halfLength = chassis.LengthM * STUDS_PER_METER / 2
    local scratch = Color3.fromRGB(70, 70, 74)
    local dent = Color3.fromRGB(45, 45, 48)
    for _, zone in DamageModel.Zones do
        local level = DamageModel.visualLevel(entry.State.Zones[zone])
        local applied = entry.Visual[zone]
        if level <= applied then
            continue
        end
        entry.Visual[zone] = level
        local side = if zone == "Left" then -1 elseif zone == "Right" then 1 else 0
        local ends = if zone == "Front" then -1 elseif zone == "Rear" then 1 else 0
        if level >= 1 and applied < 1 then
            -- Rayures : fines traînées sur la zone touchée.
            for i = -1, 1 do
                if side ~= 0 then
                    addDecor(
                        entry,
                        "Rayure" .. zone,
                        Vector3.new(0.05, 0.06, 2.2),
                        CFrame.new(side * (halfWidth - 0.55), 0.15 * i - 0.2, i * 1.6)
                            * CFrame.Angles(math.rad(8 * i), 0, 0),
                        scratch
                    )
                else
                    addDecor(
                        entry,
                        "Rayure" .. zone,
                        Vector3.new(2, 0.06, 0.05),
                        CFrame.new(i * 1.2, -0.6 + 0.12 * i, ends * (halfLength - 0.1))
                            * CFrame.Angles(0, 0, math.rad(6 * i)),
                        scratch
                    )
                end
            end
        end
        if level >= 2 and applied < 2 then
            -- Dégâts localisés : bouclier enfoncé, optiques cassées, flanc creusé.
            local panel = ZONE_PANEL[zone]
            if panel then
                deformPanel(entry, panel, 6, 0.25, 0.05)
                local prefix = if zone == "Front" then "Phare" else "Feu"
                breakLight(entry, prefix .. "Gauche")
                breakLight(entry, prefix .. "Droit")
            else
                addDecor(
                    entry,
                    "Enfoncement" .. zone,
                    Vector3.new(0.12, 0.9, 3),
                    CFrame.new(side * (halfWidth - 0.6), -0.3, 0),
                    dent
                )
            end
        end
        if level >= 3 and applied < 3 then
            -- Dégâts importants : bouclier pendant, flanc déformé sur toute la longueur.
            local panel = ZONE_PANEL[zone]
            if panel then
                deformPanel(entry, panel, 18, 0.45, 0.4)
            else
                addDecor(
                    entry,
                    "Deformation" .. zone,
                    Vector3.new(0.18, 1.2, halfLength * 1.3),
                    CFrame.new(side * (halfWidth - 0.7), -0.2, 0) * CFrame.Angles(0, math.rad(4 * side), 0),
                    dent
                )
            end
        end
    end
    -- Moteur très touché : fumée (effet intégré du moteur Roblox, aucun actif externe).
    if entry.State.Engine < 0.5 and not entry.Smoke then
        entry.Smoke = true
        local attachment = Instance.new("Attachment")
        attachment.Name = "FumeeMoteur"
        attachment.Position = Vector3.new(0, 1.5, -halfLength * 0.6)
        attachment.Parent = entry.Root
        local smoke = Instance.new("Smoke")
        smoke.Name = "Fumee"
        smoke.Color = Color3.fromRGB(90, 90, 95)
        smoke.Opacity = 0.25
        smoke.RiseVelocity = 3
        smoke.Size = 1.5
        smoke.Parent = attachment
    end
end

-- Applique un choc confirmé à un véhicule et journalise.
local function inflict(self: Service, entry: Entry, direction: Vector3, deltaV: number, obstacle: string)
    local localDirection = entry.Root.CFrame:VectorToObjectSpace(direction)
    local chassis = entry.Definition.Chassis
    local zone, corner = DamageModel.locate(localDirection.X, localDirection.Z, chassis.WidthM / 2, chassis.LengthM / 2)
    local result = DamageModel.applyImpact(entry.State, zone, corner, deltaV)
    if result == nil then
        return
    end
    publish(entry)
    applyVisuals(entry)
    local vehicleId = tostring(entry.Model:GetAttribute(Constants.Attributes.VehicleId))
    table.insert(self.Impacts, {
        Vehicle = entry.Model.Name,
        Zone = zone,
        DeltaV = deltaV,
        Level = result.Level,
        Obstacle = obstacle,
        Mechanical = result.Mechanical,
    })
    print(
        string.format(
            "[AutomotiveWorld][Dégâts] Choc confirmé sur %s (%s) : zone %s, Δv %.1f m/s, niveau %d, mécanique %s, obstacle %s",
            entry.Model.Name,
            vehicleId,
            zone,
            deltaV,
            result.Level,
            tostring(result.Mechanical),
            obstacle
        )
    )
end

-- Cherche un obstacle collisionnable au contact, au-dessus des roues.
local function findObstacle(self: Service, entry: Entry, pushDirection: Vector3): BasePart?
    local root = entry.Root
    local chassis = entry.Definition.Chassis
    local cgHeight = chassis.CgHeightM * STUDS_PER_METER
    local height = chassis.HeightM * STUDS_PER_METER
    -- Bas de la boîte : 0,5 st sous le centre de gravité (au-dessus des bordures).
    local bottom = -0.5
    local top = height - cgHeight
    local size = Vector3.new(
        chassis.WidthM * STUDS_PER_METER + 2 * CONTACT_MARGIN_STUDS,
        top - bottom,
        chassis.LengthM * STUDS_PER_METER + 2 * CONTACT_MARGIN_STUDS
    )
    local center = root.CFrame * CFrame.new(0, (top + bottom) / 2, 0)
    local excluded: { Instance } = { entry.Model }
    for _, player in Players:GetPlayers() do
        if player.Character then
            table.insert(excluded, player.Character)
        end
    end
    self.Overlap.FilterDescendantsInstances = excluded
    self.Queries += 1
    local best: BasePart? = nil
    local bestScore = -math.huge
    for _, part in Workspace:GetPartBoundsInBox(center, size, self.Overlap) do
        -- L'obstacle doit se trouver du côté opposé à la poussée reçue.
        local offset = horizontal(part.Position - root.Position)
        local score = if offset.Magnitude > 1e-3 then offset.Unit:Dot(-pushDirection) else 0
        if score > bestScore then
            bestScore = score
            best = part
        end
    end
    if best and bestScore > -0.2 then
        return best
    end
    return nil
end

local function vehicleOf(part: BasePart): Model?
    local model = part:FindFirstAncestorOfClass("Model")
    while model do
        if CollectionService:HasTag(model, Constants.VehicleTag) then
            return model
        end
        model = model:FindFirstAncestorOfClass("Model")
    end
    return nil
end

local function velocityAt(entry: Entry, time: number): Vector3
    local best, bestGap = entry.Root.AssemblyLinearVelocity * METERS_PER_STUD, math.huge
    for _, sample in entry.History do
        local gap = math.abs(sample.Time - time)
        if gap < bestGap then
            bestGap = gap
            best = sample.Velocity
        end
    end
    return best
end

--[[
    Un battement : échantillonne chaque véhicule et confirme les chocs.
    `skip(model)` : vrai si le serveur corrige ce véhicule (pas de détection).
]]
-- Fin de suivi d'un choc : application unique, bornée physiquement pour une paire.
local function finalize(self: Service, entry: Entry, event: ImpactEvent, now: number)
    local other = event.Other :: Entry?
    if other then
        local massA = entry.Definition.Chassis.MassKg
        local massB = other.Definition.Chassis.MassKg
        local closing = math.max(0, horizontal(event.Before - event.OtherBefore):Dot(-event.Push))
        local own = math.min(event.PeakExcess, (1 + RESTITUTION) * massB / (massA + massB) * closing + TOLERANCE_MS)
        local theirs = math.min(event.PeakExcess * massA / massB, (1 + RESTITUTION) * massA / (massA + massB) * closing)
        inflict(self, entry, -event.Push, own, other.Model.Name)
        inflict(self, other, event.Push, theirs, entry.Model.Name)
        other.CooldownUntil = now + VEHICLE_COOLDOWN_S
    else
        inflict(self, entry, -event.Push, event.PeakExcess, event.Obstacle)
    end
end

--[[
    Un battement : échantillonne chaque véhicule, ouvre un suivi de choc quand
    une variation de vitesse impossible pour les pneus coïncide avec un obstacle
    au contact, et applique le choc à la fin du suivi.
    `skip(model)` : vrai si le serveur corrige ce véhicule (pas de détection).
]]
function DamageService.step(self: Service, now: number, skip: (Model) -> boolean)
    local started = os.clock()
    for _, entry in self.Entries do
        local root = entry.Root
        if root.Parent == nil or root.Anchored or skip(entry.Model) or now < entry.SuspendedUntil then
            table.clear(entry.History)
            entry.Event = nil
            continue
        end
        local velocity = root.AssemblyLinearVelocity * METERS_PER_STUD
        local history = entry.History
        local event = entry.Event
        if event then
            -- Variation totale depuis la vitesse d'avant le choc.
            local delta = horizontal(velocity - event.Before)
            local excess = delta.Magnitude - (TIRE_LIMIT_MS2 * (now - event.Start) + TOLERANCE_MS)
            if excess > event.PeakExcess and delta.Magnitude > 1e-3 then
                event.PeakExcess = excess
                event.Push = delta.Unit
            end
            if now - event.Start >= EVENT_S then
                entry.Event = nil
                entry.CooldownUntil = now + VEHICLE_COOLDOWN_S
                table.clear(history)
                finalize(self, entry, event, now)
            end
            continue
        end
        local worstExcess, worstDelta, worstTime = 0, Vector3.zero, now
        for _, sample in history do
            local delta = horizontal(velocity - sample.Velocity)
            local excess = delta.Magnitude - (TIRE_LIMIT_MS2 * (now - sample.Time) + TOLERANCE_MS)
            if excess > worstExcess then
                worstExcess = excess
                worstDelta = delta
                worstTime = sample.Time
            end
        end
        table.insert(history, { Time = now, Velocity = velocity })
        while #history > 0 and now - history[1].Time > HISTORY_S do
            table.remove(history, 1)
        end
        if worstExcess < DamageModel.MinImpact or now < entry.CooldownUntil then
            continue
        end
        local push = worstDelta.Unit
        local obstacle = findObstacle(self, entry, push)
        if obstacle == nil then
            -- Variation de vitesse sans obstacle au contact : pas de dégâts (réplication).
            self.Unconfirmed += 1
            continue
        end
        local otherModel = vehicleOf(obstacle)
        local other = if otherModel then self.ByModel[otherModel] else nil
        local otherBefore = Vector3.zero
        if other then
            -- Un seul suivi par paire : celui du premier véhicule qui détecte le choc.
            local key = pairKey(entry.Model, other.Model)
            if now < (self.PairCooldowns[key] or 0) or other.Event ~= nil then
                continue
            end
            self.PairCooldowns[key] = now + PAIR_COOLDOWN_S
            otherBefore = velocityAt(other, worstTime)
        end
        entry.Event = {
            Start = worstTime,
            Before = velocityAt(entry, worstTime),
            Push = push,
            PeakExcess = worstExcess,
            Obstacle = obstacle.Name,
            Other = other,
            OtherBefore = otherBefore,
        }
    end
    PerfStats.add(self.StepTimes, os.clock() - started)
end

function DamageService.perf(self: Service): PerfStats.Summary
    return PerfStats.summary(self.StepTimes)
end

return DamageService
