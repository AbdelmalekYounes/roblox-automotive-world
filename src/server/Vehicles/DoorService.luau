--!strict
--[[
    Portières et séquences d'entrée et de sortie, côté serveur (autorité). Lot ANIM-02, refait au lot ANIM-03
    (gestes complets, `Shared.Vehicles.BoardingMotion`).

    Le serveur décide seul : quand le personnage commence la séquence, quand il s'assoit, quand il est libéré et
    déposé, quelle porte est utilisée. Il publie :
    - la séquence (attribut texte `AWEmbarquement` du personnage : genre, place, porte, début, point, cap) ; chaque
      client en déduit chaque image (corps, membres, mains, porte), sans réplication par image ;
    - l'état des portes (attribut texte du modèle, `Shared.Vehicles.Doors`), aux mêmes instants que la séquence ;
    - le départ bloqué (`AWDepartBloque` du modèle) tant qu'un passager monte ou descend (décision du propriétaire du
      2026-11-06) : le client du conducteur neutralise alors ses commandes (`Vehicles/BoardingLock`).
    Les règles de montée (siège libre, conducteur autorisé, passager admis, distance) restent celles de
    `VehicleService`, qui les fournit en rappel et les fait revalider au moment de s'asseoir.

    Entrée : marche jusqu'à la porte (le client du joueur marche, 1 s au plus), puis le personnage est assis AU DÉBUT de
    la séquence (HumanoidRootPart soudé au siège, physique stable) : tout le mouvement visible est chorégraphié par les
    clients. Sortie : le personnage reste assis pendant toute la séquence, puis il est libéré et déposé au point où son
    corps est arrivé.

    Interruptions (consigne du lot) : véhicule détruit, joueur parti (personnage retiré), personnage mort, ou personnage
    sorti du siège par un autre chemin (éjection) : la séquence s'arrête, la porte se referme, les attributs sont
    retirés. Aucune interruption par la vitesse : pendant la séquence, le conducteur ne peut pas rouler.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local VehiclesShared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Vehicles")
local Doors = require(VehiclesShared:WaitForChild("Doors"))
local BoardingMotion = require(VehiclesShared:WaitForChild("BoardingMotion"))

local DoorService = {}

local REQUEST_COOLDOWN_S = 0.5

type DoorEntry = { Holders: number, State: Doors.State? }
type Sequence = { Kind: BoardingMotion.Kind, Model: Model, SeatRole: Doors.Role, DoorRole: Doors.Role }

local doorsByModel: { [Model]: { [string]: DoorEntry } } = {}
local active: { [Model]: Sequence } = {} -- par personnage
local departureHolds: { [Model]: number } = {}
local lastRequest: { [Player]: number } = {}
local exitHandler: ((Player) -> ())? = nil

local function serverNow(): number
    return Workspace:GetServerTimeNow()
end

local function entryOf(model: Model, role: Doors.Role): DoorEntry
    local byRole = doorsByModel[model]
    if byRole == nil then
        byRole = {}
        doorsByModel[model] = byRole
        model.Destroying:Once(function()
            doorsByModel[model] = nil
            departureHolds[model] = nil
        end)
    end
    local entry = byRole[role]
    if entry == nil then
        entry = { Holders = 0, State = nil }
        byRole[role] = entry
    end
    return entry
end

-- Mouvement de porte de `at` (temps du serveur, éventuellement futur) à `at + duration`, depuis sa position à `at`.
local function move(model: Model, role: Doors.Role, to: number, at: number, duration: number)
    if model.Parent == nil then
        return
    end
    local entry = entryOf(model, role)
    local state = Doors.transition(entry.State, at, to, duration)
    entry.State = state
    model:SetAttribute(Doors.DoorAttribute[role], Doors.encode(state))
end

-- Le véhicule a-t-il cette porte articulée (kit complet, `MeshKits`) ?
function DoorService.hasDoor(model: Model, role: Doors.Role): boolean
    return model:FindFirstChild(Doors.HingeName[role], true) ~= nil
end

-- Porte refermée dès maintenant (fin anticipée), si plus aucune séquence ne la tient et qu'elle n'est pas déjà fermée
-- ou en train de se fermer.
local function closeIfFree(model: Model, role: Doors.Role)
    local entry = entryOf(model, role)
    local state = entry.State
    if entry.Holders > 0 or (state and state.To == 0) then
        return
    end
    move(model, role, 0, serverNow(), Doors.CloseS)
end

-- Occupant sorti sans séquence (saut du moteur, éjection) : porte entrouverte puis refermée.
function DoorService.flash(model: Model, role: Doors.Role)
    if not DoorService.hasDoor(model, role) or entryOf(model, role).Holders > 0 then
        return
    end
    move(model, role, 1, serverNow(), Doors.CloseS)
    task.delay(Doors.FlashOpenS, function()
        if model.Parent ~= nil then
            closeIfFree(model, role)
        end
    end)
end

-- Personnage engagé dans une séquence (montée ou descente en cours).
function DoorService.busy(character: Model): boolean
    return active[character] ~= nil
end

-- Place réservée par une montée en cours : personne d'autre ne peut la prendre.
function DoorService.reserved(model: Model, seatRole: Doors.Role): boolean
    for _, sequence in active do
        if sequence.Model == model and sequence.SeatRole == seatRole and sequence.Kind == "In" then
            return true
        end
    end
    return false
end

-- Départ bloqué tant qu'un passager monte ou descend (compteur : plusieurs séquences possibles).
local function holdDeparture(model: Model, delta: number)
    local count = math.max((departureHolds[model] or 0) + delta, 0)
    if count > 0 then
        departureHolds[model] = count
    else
        departureHolds[model] = nil
    end
    if model.Parent ~= nil then
        model:SetAttribute(BoardingMotion.DepartureAttribute, if count > 0 then true else nil)
    end
end

-- Porte tenue par une séquence : ouverture et fermeture aux instants du calendrier (temps du serveur `t0`).
local function scheduleDoor(model: Model, role: Doors.Role, kind: BoardingMotion.Kind, t0: number)
    local plan: any = if kind == "In" then BoardingMotion.Entry else BoardingMotion.Exit
    local entry = entryOf(model, role)
    entry.Holders += 1
    move(model, role, 1, t0 + plan.OpenStart, plan.OpenEnd - plan.OpenStart)
    task.delay(math.max(t0 + plan.CloseStart - serverNow(), 0), function()
        -- Une autre séquence tient encore la porte : elle reste ouverte.
        if model.Parent ~= nil and entry.Holders == 1 then
            move(model, role, 0, t0 + plan.CloseStart, plan.CloseEnd - plan.CloseStart)
        end
    end)
end

local function releaseDoor(model: Model, role: Doors.Role)
    local entry = entryOf(model, role)
    entry.Holders = math.max(entry.Holders - 1, 0)
    if model.Parent ~= nil then
        closeIfFree(model, role)
    end
end

-- Séquence encore possible : véhicule et personnage présents, personnage vivant.
local function alive(model: Model, character: Model, humanoid: Humanoid): boolean
    return model.Parent ~= nil and character.Parent ~= nil and humanoid.Health > 0
end

local function finish(character: Model, sequence: Sequence)
    if active[character] == sequence then
        active[character] = nil
    end
    if sequence.SeatRole == "Passenger" then
        holdDeparture(sequence.Model, -1)
    end
end

export type BoardArgs = {
    Model: Model,
    Root: BasePart,
    Seat: Doors.Role,
    Door: Doors.Spec,
    DoorRole: Doors.Role,
    SideHalf: number,
    Character: Model,
    Humanoid: Humanoid,
    Valid: () -> boolean, -- montée toujours permise (siège libre, droits, distance, personnage vivant)
    Sit: () -> (),
}

--[[
    Montée : le client du joueur marche jusqu'au point de la porte (attribut `ApproachAttribute`) ; arrivé (ou au bout
    de `WalkMaxS`), toutes les règles sont revalidées, la séquence est publiée et le personnage est assis ; la porte
    s'ouvre puis se referme aux instants du calendrier. Rend false si une séquence est déjà en cours.
]]
function DoorService.board(args: BoardArgs): boolean
    local character, model, root, humanoid = args.Character, args.Model, args.Root, args.Humanoid
    if active[character] then
        return false
    end
    local sequence: Sequence = { Kind = "In", Model = model, SeatRole = args.Seat, DoorRole = args.DoorRole }
    active[character] = sequence
    if args.Seat == "Passenger" then
        holdDeparture(model, 1)
    end
    local stand = BoardingMotion.standPoint(args.Door, args.SideHalf)
    character:SetAttribute(Doors.ApproachAttribute, root.CFrame:PointToWorldSpace(stand))
    task.spawn(function()
        local start = os.clock()
        local t0: number? = nil
        while alive(model, character, humanoid) and args.Valid() do
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if not (hrp and hrp:IsA("BasePart")) then
                break
            end
            local flat = (hrp.Position - root.CFrame:PointToWorldSpace(stand)) * Vector3.new(1, 0, 1)
            if flat.Magnitude <= BoardingMotion.StandReach or os.clock() - start >= BoardingMotion.WalkMaxS then
                local now = serverNow()
                local look = root.CFrame:VectorToObjectSpace(hrp.CFrame.LookVector)
                character:SetAttribute(
                    BoardingMotion.Attribute,
                    BoardingMotion.encode({
                        Kind = "In",
                        Seat = args.Seat,
                        Door = args.DoorRole,
                        T = now,
                        Point = root.CFrame:PointToObjectSpace(hrp.Position),
                        Yaw = BoardingMotion.yawOf(look),
                    })
                )
                args.Sit()
                scheduleDoor(model, args.DoorRole, "In", now)
                t0 = now
                break
            end
            RunService.Heartbeat:Wait()
        end
        if character.Parent ~= nil then
            character:SetAttribute(Doors.ApproachAttribute, nil)
        end
        if t0 == nil then
            finish(character, sequence) -- montée devenue impossible pendant la marche
            return
        end
        local startT = t0 :: number
        local endT = startT + BoardingMotion.Entry.Total + BoardingMotion.BlendS
        -- Le siège peut mettre une image à se remplir : l'éjection n'est vérifiée qu'après un court délai.
        local seatedCheckAfter = os.clock() + 0.3
        while serverNow() < endT do
            if not alive(model, character, humanoid) then
                break
            end
            if os.clock() > seatedCheckAfter and humanoid.SeatPart == nil then
                break -- sorti du siège par un autre chemin
            end
            RunService.Heartbeat:Wait()
        end
        if character.Parent ~= nil then
            character:SetAttribute(BoardingMotion.Attribute, nil)
        end
        releaseDoor(model, args.DoorRole)
        finish(character, sequence)
    end)
    return true
end

export type AlightArgs = {
    Model: Model,
    Root: BasePart,
    Seat: Doors.Role,
    DoorRole: Doors.Role,
    Character: Model,
    Humanoid: Humanoid,
    Destination: Vector3, -- position du HumanoidRootPart déposé, repère du châssis (pieds au sol)
    StillSeated: () -> boolean,
    Release: () -> (), -- libère le siège et dépose le personnage au point de dépôt
}

--[[
    Descente : séquence publiée (le personnage reste assis), porte ouverte puis refermée aux instants du calendrier ;
    à la fin, siège libéré et personnage déposé au point où son corps est arrivé. Rend false si une séquence est déjà
    en cours.
]]
function DoorService.alight(args: AlightArgs): boolean
    local character, model, humanoid = args.Character, args.Model, args.Humanoid
    if active[character] then
        return false
    end
    local sequence: Sequence = { Kind = "Out", Model = model, SeatRole = args.Seat, DoorRole = args.DoorRole }
    active[character] = sequence
    if args.Seat == "Passenger" then
        holdDeparture(model, 1)
    end
    local t0 = serverNow()
    character:SetAttribute(
        BoardingMotion.Attribute,
        BoardingMotion.encode({
            Kind = "Out",
            Seat = args.Seat,
            Door = args.DoorRole,
            T = t0,
            Point = args.Destination,
            Yaw = BoardingMotion.ExitYaw,
        })
    )
    scheduleDoor(model, args.DoorRole, "Out", t0)
    task.spawn(function()
        local released = false
        while alive(model, character, humanoid) and args.StillSeated() do
            if serverNow() >= t0 + BoardingMotion.Exit.Total then
                args.Release()
                released = true
                break
            end
            RunService.Heartbeat:Wait()
        end
        releaseDoor(model, args.DoorRole)
        finish(character, sequence)
        -- Séquence gardée un instant après la libération : chaque client tient le corps au point de dépôt jusqu'à ce
        -- qu'il voie le personnage debout (les clients ne l'appliquent qu'aux personnages assis).
        task.delay(if released then BoardingMotion.BlendS + 0.5 else 0, function()
            if character.Parent ~= nil and active[character] == nil then
                character:SetAttribute(BoardingMotion.Attribute, nil)
            end
        end)
    end)
    return true
end

-- Demande de sortie d'un passager (touche de saut interceptée par son client) : traitée par VehicleService.
function DoorService.setExitHandler(handler: (Player) -> ())
    exitHandler = handler
end

function DoorService.start(remotesFolder: Instance)
    if remotesFolder:FindFirstChild(Doors.RemoteName) then
        return
    end
    local remote = Instance.new("RemoteEvent")
    remote.Name = Doors.RemoteName
    remote.Parent = remotesFolder
    remote.OnServerEvent:Connect(function(player: Player, request: any)
        if request ~= Doors.ExitRequest then
            return
        end
        local now = os.clock()
        if now - (lastRequest[player] or -math.huge) < REQUEST_COOLDOWN_S then
            return
        end
        lastRequest[player] = now
        local handler = exitHandler
        if handler then
            handler(player)
        end
    end)
    Players.PlayerRemoving:Connect(function(player)
        lastRequest[player] = nil
    end)
end

return DoorService
