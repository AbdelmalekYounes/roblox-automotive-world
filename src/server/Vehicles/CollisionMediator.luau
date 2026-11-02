--!strict
-- Médiation des collisions entre véhicules conduits par DEUX joueurs différents
-- (AUD-COLL-01, AUD-PHYS-01). Voir Physics/CollisionExchange pour la cause
-- mesurée et le principe.
--
-- À chaque battement serveur :
-- 1. échantillonne les positions répliquées des véhicules simulés par un client ;
-- 2. pour chaque couple (percuteur, percuté) de propriétaires différents en
--    contact (boîtes englobantes, marge 1 st), confirme le choc à partir de ces
--    seules observations serveur : percuteur en approche, rapprochement réel ET
--    décélération du percuteur ;
-- 3. suit le choc pendant sa durée (la décélération du percuteur se poursuit sur
--    plusieurs images) et envoie au propriétaire du véhicule percuté la variation
--    de vitesse TOTALE attendue chaque fois qu'elle augmente ; le client
--    n'applique que ce qui lui manque, donc les envois successifs ne se cumulent pas ;
-- 4. vérifie après coup que le véhicule percuté a bien réagi.
-- Aucune téléportation, aucune sanction : un écart est seulement journalisé.
-- Les véhicules stationnés (simulés par le serveur) ne sont pas concernés : le
-- moteur résout ce contact dans la simulation serveur.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehiclesShared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Vehicles")
local Constants = require(VehiclesShared:WaitForChild("VehicleConstants"))
local CollisionExchange = require(VehiclesShared:WaitForChild("Physics"):WaitForChild("CollisionExchange"))

local METERS_PER_STUD = Constants.MetersPerStud
local HISTORY_S = 2.0
local EVENT_DURATION_S = 0.7 -- suivi d'un choc après sa confirmation
local PAIR_COOLDOWN_S = 0.5 -- après la fin d'un choc
local UPDATE_STEP_MS = 0.3 -- hausse minimale de la cible avant un nouvel envoi
local CONTACT_MARGIN_STUDS = 1
local VERIFY_AFTER_S = 1.5
local VERIFY_MIN_FRACTION = 0.3

export type Participant = {
    Model: Model,
    Root: BasePart,
    MassKg: number,
    Driver: Player?,
    -- Vrai si le véhicule est simulé par son conducteur (hors correction serveur).
    ClientSimulated: boolean,
}

-- Envoi au propriétaire du véhicule percuté (normale horizontale unitaire,
-- Δv TOTAL attendu en studs/s, point d'application).
export type Sender = (driver: Player, model: Model, normal: Vector3, deltaVStuds: number, point: Vector3) -> ()

type ContactEvent = {
    Start: number,
    Normal: Vector3,
    SentMs: number,
}

type Pending = {
    Model: Model,
    Normal: Vector3,
    TargetMs: number,
    At: number,
}

type MediatorFields = {
    Send: Sender,
    Samples: { [Model]: { CollisionExchange.Sample } },
    Events: { [Model]: { [Model]: ContactEvent } },
    Cooldowns: { [Model]: { [Model]: number } },
    Pending: { Pending },
    Confirmed: number,
}

local CollisionMediator = {}
CollisionMediator.__index = CollisionMediator

export type Mediator = typeof(setmetatable({} :: MediatorFields, CollisionMediator))

function CollisionMediator.new(send: Sender): Mediator
    return setmetatable(
        {
            Send = send,
            Samples = {},
            Events = {},
            Cooldowns = {},
            Pending = {},
            Confirmed = 0,
        } :: MediatorFields,
        CollisionMediator
    )
end

local function vehicleId(model: Model): string
    return tostring(model:GetAttribute(Constants.Attributes.VehicleId) or model.Name)
end

local function record(self: Mediator, participant: Participant, now: number)
    local list = self.Samples[participant.Model]
    if list == nil then
        list = {}
        self.Samples[participant.Model] = list
    end
    local position = participant.Root.Position * METERS_PER_STUD
    table.insert(list, { Time = now, X = position.X, Z = position.Z })
    while #list > 0 and now - list[1].Time > HISTORY_S do
        table.remove(list, 1)
    end
end

local function touching(striker: Participant, struck: Participant): boolean
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { struck.Model }
    local margin = Vector3.one * (2 * CONTACT_MARGIN_STUDS)
    return #Workspace:GetPartBoundsInBox(striker.Root.CFrame, striker.Root.Size + margin, params) > 0
end

-- Point du véhicule percuté le plus proche du centre du percuteur, à la hauteur
-- du centre de gravité (pas de couple de roulis artificiel).
local function contactPoint(striker: Participant, struck: Participant): Vector3
    local cframe = struck.Root.CFrame
    local half = struck.Root.Size / 2
    local localPoint = cframe:PointToObjectSpace(striker.Root.Position)
    local clamped = Vector3.new(math.clamp(localPoint.X, -half.X, half.X), 0, math.clamp(localPoint.Z, -half.Z, half.Z))
    return cframe:PointToWorldSpace(clamped)
end

local function pairValue<T>(map: { [Model]: { [Model]: T } }, a: Model, b: Model): T?
    local inner = map[a]
    return if inner then inner[b] else nil
end

local function setPairValue<T>(map: { [Model]: { [Model]: T } }, a: Model, b: Model, value: T?)
    local inner = map[a]
    if inner == nil then
        if value == nil then
            return
        end
        inner = {}
        map[a] = inner
    end
    (inner :: any)[b] = value
end

-- Contrôle a posteriori : le véhicule percuté a-t-il réellement réagi ?
local function verifyPending(self: Mediator, now: number)
    for index = #self.Pending, 1, -1 do
        local pending = self.Pending[index]
        if now - pending.At < VERIFY_AFTER_S then
            continue
        end
        table.remove(self.Pending, index)
        local samples = self.Samples[pending.Model] or {}
        local params = table.clone(CollisionExchange.DefaultParams)
        params.WindowS = VERIFY_AFTER_S + EVENT_DURATION_S
        local speeds = CollisionExchange.normalSpeeds(samples, pending.Normal.X, pending.Normal.Z, now, params)
        local history = {}
        for _, s in speeds do
            table.insert(history, s.V)
        end
        local received = if #history > 0 then CollisionExchange.alreadyReceived(history, history[#history]) else 0
        if received < VERIFY_MIN_FRACTION * pending.TargetMs then
            warn(
                string.format(
                    "[AutomotiveWorld][Validation] Impulsion de collision non constatée sur %s (%.2f m/s observés pour %.2f m/s demandés) : tolérée, aucune sanction.",
                    vehicleId(pending.Model),
                    received,
                    pending.TargetMs
                )
            )
        end
    end
end

-- Évalue un couple et envoie la cible si elle a augmenté. Renvoie l'évaluation.
local function evaluate(
    self: Mediator,
    striker: Participant,
    struck: Participant,
    event: ContactEvent,
    now: number
): CollisionExchange.Assessment?
    -- Fenêtre ancrée au début du choc : la vitesse d'approche reste observée.
    local params = table.clone(CollisionExchange.DefaultParams)
    params.WindowS = now - event.Start + CollisionExchange.DefaultParams.WindowS
    local assessment = CollisionExchange.assess(
        self.Samples[striker.Model],
        striker.MassKg,
        self.Samples[struck.Model],
        struck.MassKg,
        event.Normal.X,
        event.Normal.Z,
        now,
        params
    )
    if assessment and assessment.TargetDeltaVMs >= event.SentMs + UPDATE_STEP_MS then
        event.SentMs = assessment.TargetDeltaVMs
        self.Send(
            struck.Driver :: Player,
            struck.Model,
            event.Normal,
            assessment.TargetDeltaVMs / METERS_PER_STUD,
            contactPoint(striker, struck)
        )
    end
    return assessment
end

function CollisionMediator.step(self: Mediator, participants: { Participant }, now: number)
    local active = {}
    for _, participant in participants do
        if participant.ClientSimulated and participant.Driver ~= nil then
            record(self, participant, now)
            table.insert(active, participant)
        else
            self.Samples[participant.Model] = nil
            self.Events[participant.Model] = nil
        end
    end
    for _, striker in active do
        for _, struck in active do
            if striker == struck or striker.Driver == struck.Driver then
                continue
            end
            local event = pairValue(self.Events, striker.Model, struck.Model)
            if event then
                if now - event.Start <= EVENT_DURATION_S then
                    evaluate(self, striker, struck, event, now)
                    continue
                end
                -- Fin du choc : contrôle a posteriori, puis délai avant un nouveau choc.
                setPairValue(self.Events, striker.Model, struck.Model, nil)
                setPairValue(self.Cooldowns, striker.Model, struck.Model, now + PAIR_COOLDOWN_S)
                table.insert(self.Pending, {
                    Model = struck.Model,
                    Normal = event.Normal,
                    TargetMs = event.SentMs,
                    At = now,
                })
                print(
                    string.format(
                        "[AutomotiveWorld][Collision] Choc terminé %s → %s : Δv total demandé %.2f m/s",
                        vehicleId(striker.Model),
                        vehicleId(struck.Model),
                        event.SentMs
                    )
                )
                continue
            end
            if (pairValue(self.Cooldowns, striker.Model, struck.Model) or 0) > now then
                continue
            end
            local offset = struck.Root.Position - striker.Root.Position
            local flat = Vector3.new(offset.X, 0, offset.Z)
            local reach = (striker.Root.Size.Magnitude + struck.Root.Size.Magnitude) / 2 + 4
            if flat.Magnitude > reach or flat.Magnitude < 1e-3 or not touching(striker, struck) then
                continue
            end
            local candidate: ContactEvent = { Start = now, Normal = flat.Unit, SentMs = 0 }
            local assessment = evaluate(self, striker, struck, candidate, now)
            if assessment == nil then
                continue
            end
            setPairValue(self.Events, striker.Model, struck.Model, candidate)
            self.Confirmed += 1
            print(
                string.format(
                    "[AutomotiveWorld][Collision] Contact confirmé %s → %s : perte %.2f m/s, rapprochement %.2f m/s, Δv demandé %.2f m/s",
                    vehicleId(striker.Model),
                    vehicleId(struck.Model),
                    assessment.LossMs,
                    assessment.ClosingMs,
                    assessment.TargetDeltaVMs
                )
            )
        end
    end
    verifyPending(self, now)
end

return CollisionMediator
