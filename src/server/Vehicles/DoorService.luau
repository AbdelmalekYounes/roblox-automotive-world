--!strict
--[[
    Portières et séquences d'entrée et de sortie (lot ANIM-02), côté serveur (autorité).

    Le serveur décide seul : quelle porte s'ouvre, quand le personnage s'assoit, quand il est libéré et déposé. Il
    publie l'état des portes (attribut texte du modèle) et le glissé du personnage (attribut texte du personnage) ;
    chaque client en déduit l'image (`Vehicles/DoorVisuals`). Les règles de montée (siège libre, conducteur autorisé,
    passager admis, distance) restent celles de `VehicleService`, qui les fournit en rappel et les fait revalider au
    moment de s'asseoir.

    Décisions du propriétaire du 2026-11-06 : `Shared.Vehicles.Doors` (en-tête). Interruption : véhicule qui part ou qui
    est poussé, ou nouveau choc compté par les dégâts (attribut `DmgImpacts`, lu seulement : `DamageService` n'est pas
    modifié).
    - Pendant la marche jusqu'à la porte : le personnage est assis aussitôt si la montée reste valide, sinon la montée
      est annulée ; la porte se referme vite.
    - Pendant le glissé d'entrée : le personnage est déjà assis (le conducteur peut rouler) ; le glissé s'arrête net
      et la porte se referme vite.
    - Pendant la sortie : libéré aussitôt si la vitesse permet encore de sortir, sinon la sortie est annulée (il reste
      assis) ; la porte se referme vite.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Doors = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Vehicles"):WaitForChild("Doors"))

local DoorService = {}

-- Nombre de chocs comptés par les dégâts (attribut publié par DamageService, lu seulement).
local IMPACTS_ATTRIBUTE = "DmgImpacts"
-- Glissé de sortie gardé après la libération, le temps que le personnage soit déposé (les clients ne l'appliquent
-- qu'aux personnages assis).
local GLIDE_CLEAR_AFTER_S = 1
local REQUEST_COOLDOWN_S = 0.5

type DoorEntry = { Holders: number, State: Doors.State? }
type Sequence = { Kind: Doors.GlideKind, Model: Model, SeatRole: Doors.Role, DoorRole: Doors.Role }

local doorsByModel: { [Model]: { [string]: DoorEntry } } = {}
local active: { [Model]: Sequence } = {} -- par personnage
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
        end)
    end
    local entry = byRole[role]
    if entry == nil then
        entry = { Holders = 0, State = nil }
        byRole[role] = entry
    end
    return entry
end

local function move(model: Model, role: Doors.Role, to: number, duration: number)
    local entry = entryOf(model, role)
    local state = Doors.transition(entry.State, serverNow(), to, duration)
    entry.State = state
    model:SetAttribute(Doors.DoorAttribute[role], Doors.encode(state))
end

-- Le véhicule a-t-il cette porte articulée (kit complet, `MeshKits`) ?
function DoorService.hasDoor(model: Model, role: Doors.Role): boolean
    return model:FindFirstChild(Doors.HingeName[role], true) ~= nil
end

-- Ouvre la porte pour une séquence (plusieurs séquences peuvent la tenir ouverte).
local function hold(model: Model, role: Doors.Role)
    local entry = entryOf(model, role)
    entry.Holders += 1
    if entry.Holders == 1 then
        move(model, role, 1, Doors.OpenS)
    end
end

-- Rend la porte ; fermée quand plus aucune séquence ne la tient (portes toujours fermées à l'arrêt).
local function letGo(model: Model, role: Doors.Role, fast: boolean)
    local entry = entryOf(model, role)
    entry.Holders = math.max(entry.Holders - 1, 0)
    if entry.Holders == 0 and model.Parent ~= nil then
        move(model, role, 0, if fast then Doors.FastCloseS else Doors.CloseS)
    end
end

-- Occupant sorti sans séquence (saut du moteur, éjection) : porte entrouverte puis refermée.
function DoorService.flash(model: Model, role: Doors.Role)
    if not DoorService.hasDoor(model, role) or entryOf(model, role).Holders > 0 then
        return
    end
    move(model, role, 1, Doors.OpenS)
    task.delay(Doors.FlashOpenS, function()
        if model.Parent ~= nil and entryOf(model, role).Holders == 0 then
            move(model, role, 0, Doors.CloseS)
        end
    end)
end

-- Personnage engagé dans une séquence (montée ou descente en cours).
function DoorService.busy(character: Model): boolean
    return active[character] ~= nil
end

-- Place réservée par une montée en cours (marche jusqu'à la porte) : personne d'autre ne peut la prendre.
function DoorService.reserved(model: Model, seatRole: Doors.Role): boolean
    for _, sequence in active do
        if sequence.Model == model and sequence.SeatRole == seatRole and sequence.Kind == "In" then
            return true
        end
    end
    return false
end

local function impacts(model: Model): number?
    local value = model:GetAttribute(IMPACTS_ATTRIBUTE)
    return if type(value) == "number" then value else nil
end

local function interrupted(root: BasePart, model: Model, impactsAtStart: number?): boolean
    return Doors.shouldInterrupt(root.AssemblyLinearVelocity.Magnitude, impactsAtStart, impacts(model))
end

export type BoardArgs = {
    Model: Model,
    Root: BasePart,
    Role: Doors.Role,
    Character: Model,
    Humanoid: Humanoid,
    Stand: Vector3, -- point de la porte, repère du châssis
    Valid: () -> boolean, -- montée toujours permise (siège libre, droits, distance, personnage vivant)
    Sit: () -> (),
}

--[[
    Montée : la porte s'ouvre pendant que le client du joueur marche jusqu'à elle (attribut `ApproachAttribute`) ; le
    personnage est assis quand il est arrivé (ou au bout de `WalkMaxS`) et la porte ouverte ; son corps glisse alors de
    la porte au siège, puis la porte se referme. Rend false si une séquence est déjà en cours pour ce personnage.
]]
function DoorService.board(args: BoardArgs): boolean
    local character, model, root = args.Character, args.Model, args.Root
    if active[character] then
        return false
    end
    active[character] = { Kind = "In", Model = model, SeatRole = args.Role, DoorRole = args.Role }
    local impactsAtStart = impacts(model)
    hold(model, args.Role)
    character:SetAttribute(Doors.ApproachAttribute, root.CFrame:PointToWorldSpace(args.Stand))
    task.spawn(function()
        local start = os.clock()
        local sat, glided = false, false
        while character.Parent ~= nil and model.Parent ~= nil and args.Humanoid.Health > 0 do
            if not args.Valid() then
                break
            end
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if not (hrp and hrp:IsA("BasePart")) then
                break
            end
            if interrupted(root, model, impactsAtStart) then
                -- Le véhicule part (ou est heurté) : assis tout de suite, sans glissé.
                args.Sit()
                sat = true
                break
            end
            local elapsed = os.clock() - start
            local flat = (hrp.Position - root.CFrame:PointToWorldSpace(args.Stand)) * Vector3.new(1, 0, 1)
            if elapsed >= Doors.OpenS and (flat.Magnitude <= Doors.StandReach or elapsed >= Doors.WalkMaxS) then
                local glide: Doors.Glide = {
                    Kind = "In",
                    Role = args.Role,
                    T = serverNow(),
                    Point = root.CFrame:PointToObjectSpace(hrp.Position),
                }
                character:SetAttribute(Doors.GlideAttribute, Doors.encodeGlide(glide))
                args.Sit()
                sat, glided = true, true
                break
            end
            RunService.Heartbeat:Wait()
        end
        character:SetAttribute(Doors.ApproachAttribute, nil)
        local fast = not glided
        if glided then
            local glideStart = os.clock()
            while os.clock() - glideStart < Doors.GlideInS and character.Parent ~= nil do
                if interrupted(root, model, impactsAtStart) then
                    fast = true
                    break
                end
                RunService.Heartbeat:Wait()
            end
        end
        if character.Parent ~= nil then
            character:SetAttribute(Doors.GlideAttribute, nil)
        end
        letGo(model, args.Role, fast or not sat)
        active[character] = nil
    end)
    return true
end

export type AlightArgs = {
    Model: Model,
    Root: BasePart,
    SeatRole: Doors.Role,
    DoorRole: Doors.Role,
    Character: Model,
    Humanoid: Humanoid,
    Destination: Vector3, -- position du HumanoidRootPart déposé, repère du châssis
    StillSeated: () -> boolean,
    MayRelease: () -> boolean, -- sortie encore permise (vitesse), en cas d'interruption
    Release: () -> (), -- libère le siège et dépose le personnage (placement vérifié de VehicleService)
}

--[[
    Descente : la porte s'ouvre, le corps glisse du siège jusqu'au point de dépôt, puis le siège est libéré et le
    personnage déposé à ce point ; la porte se referme. Rend false si une séquence est déjà en cours.
]]
function DoorService.alight(args: AlightArgs): boolean
    local character, model, root = args.Character, args.Model, args.Root
    if active[character] then
        return false
    end
    active[character] = { Kind = "Out", Model = model, SeatRole = args.SeatRole, DoorRole = args.DoorRole }
    local impactsAtStart = impacts(model)
    local plan = Doors.exitPlan()
    hold(model, args.DoorRole)
    task.spawn(function()
        local start = os.clock()
        local outcome = "Release"
        local glideSet = false
        while os.clock() - start < plan.ReleaseAt do
            if character.Parent == nil or not args.StillSeated() then
                outcome = "Gone"
                break
            end
            if interrupted(root, model, impactsAtStart) then
                outcome = if args.MayRelease() then "Release" else "Cancel"
                break
            end
            if not glideSet and os.clock() - start >= plan.GlideAt then
                glideSet = true
                local glide: Doors.Glide =
                    { Kind = "Out", Role = args.SeatRole, T = serverNow(), Point = args.Destination }
                character:SetAttribute(Doors.GlideAttribute, Doors.encodeGlide(glide))
            end
            RunService.Heartbeat:Wait()
        end
        if outcome == "Cancel" then
            character:SetAttribute(Doors.GlideAttribute, nil)
            letGo(model, args.DoorRole, true)
            active[character] = nil
            return
        end
        if outcome == "Release" then
            args.Release()
        end
        letGo(model, args.DoorRole, false)
        active[character] = nil
        task.delay(GLIDE_CLEAR_AFTER_S, function()
            if character.Parent ~= nil and active[character] == nil then
                character:SetAttribute(Doors.GlideAttribute, nil)
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
