--!strict
--[[
    Chorégraphie de l'entrée et de la sortie du véhicule (lot ANIM-03). Module PUR (aucun service), testé par Lune ;
    utilisé par le serveur (calendrier : `Vehicles/DoorService`) et par chaque client (corps, membres, mains et portes :
    `Vehicles/BoardingAnimator`, `Vehicles/DoorVisuals`, `Vehicles/BoardingLock`).

    Retour du propriétaire sur ANIM-02 (2026-11-06) : « on dirait que le personnage se fait aspirer par la voiture
    […] il faut animer tous les mouvements comme dans la vraie vie ». Le glissé linéaire du lot ANIM-02 est remplacé par
    une suite de gestes, à déplacement continu :
    - entrée : main tendue vers la poignée, porte tirée (la porte suit la main, puis continue de s'ouvrir), recul, demi-
      tour dos à l'habitacle, tête et buste baissés sous le pavillon, première jambe dans l'habitacle, assise, seconde
      jambe rentrée, main sur la poignée intérieure et porte tirée jusqu'à la fermeture, puis mains au volant (raccord
      avec la pose assise des lots ANIM-01 et BRIO-02, `SeatPoseController`) ;
    - sortie : main sur la poignée intérieure, porte poussée, pivot vers la porte, un pied puis l'autre au sol, buste
      penché pour se relever, sortie debout, main sur la poignée extérieure et porte refermée.

    Décisions du propriétaire (2026-11-06) : entrée ≈ 2,5 s (marche jusqu'à la porte non comprise), sortie un peu
    plus courte (2,2 s) ; aucune touche pour passer l'animation ; caméra à la 3e personne qui suit le personnage ;
    départ du véhicule bloqué tant qu'un passager monte ou descend.

    Principe (aucune téléportation) : pendant toute la séquence, le personnage est assis (son HumanoidRootPart soudé au
    siège, physique stable) et son CORPS VISIBLE est placé par l'articulation `Root` le long d'un trajet continu (courbe
    de Hermite par des positions clés, vitesse continue) ; les autres articulations suivent des poses clés adoucies ; les
    mains visent les poignées par cinématique inverse (`ArmIk`). Au départ de l'entrée, le trajet part de la position
    réelle du personnage debout ; à la fin de la sortie, il arrive au point où le serveur le dépose.

    Repère : celui du châssis (studs, avant vers −Z, haut +Y, droite +X). Angle de cap `yaw` : celui de
    `CFrame.Angles(0, yaw, 0)` (0 = regard vers l'avant du véhicule).
    Temps : secondes depuis le début de la séquence (`T`, temps du serveur `GetServerTimeNow`).
]]

local Doors = require(script.Parent.Doors)

local BoardingMotion = {}

export type Kind = "In" | "Out"

-- Séquence publiée par le serveur (attribut texte du personnage) : tout client en déduit chaque image.
export type Sequence = {
    Kind: Kind,
    Seat: Doors.Role, -- place occupée (conducteur, passager)
    Door: Doors.Role, -- porte utilisée (celle de la place, ou l'autre si le côté est bloqué)
    T: number, -- début (temps du serveur)
    -- Entrée : position du HumanoidRootPart debout au départ ; sortie : position de dépôt (repère du châssis).
    Point: Vector3,
    Yaw: number, -- entrée : cap du personnage au départ ; sortie : cap à l'arrivée
}

BoardingMotion.Attribute = "AWEmbarquement" -- sur le personnage
-- Sur le modèle : départ bloqué (un passager monte ou descend), décision du propriétaire.
BoardingMotion.DepartureAttribute = "AWDepartBloque"

-- Calendriers (secondes). Entrée ≈ 2,5 s (décision du propriétaire), sortie 2,2 s.
BoardingMotion.Entry = table.freeze({
    Total = 2.5,
    Reach = 0.35, -- main sur la poignée extérieure
    OpenStart = 0.35,
    OpenEnd = 0.8, -- porte ouverte
    HandleRelease = 0.6, -- la main lâche la poignée, la porte finit de s'ouvrir seule
    Turn = 1.3, -- demi-tour dos à l'habitacle, tête baissée
    LegIn = 1.75, -- première jambe dans l'habitacle, bassin au-dessus du seuil
    Sit = 2.05, -- assis, seconde jambe encore dehors
    SecondLeg = 2.3, -- seconde jambe rentrée
    InnerReach = 1.95, -- main vers la poignée intérieure
    CloseStart = 2.15,
    CloseEnd = 2.5,
})
BoardingMotion.Exit = table.freeze({
    Total = 2.2,
    InnerReach = 0.25,
    OpenStart = 0.25,
    OpenEnd = 0.7,
    InnerRelease = 0.6,
    FirstFoot = 0.95, -- premier pied au sol
    SecondFoot = 1.15, -- second pied au sol, buste penché
    Rise = 1.45, -- à moitié levé
    Stand = 1.7, -- debout, hors de l'habitacle
    OuterReach = 1.55, -- main vers la poignée extérieure
    CloseStart = 1.8,
    CloseEnd = 2.2,
})
-- Raccord avec la pose assise (`SeatPoseController`) : fondu à la fin de l'entrée et au début de la sortie.
BoardingMotion.BlendS = 0.3
-- Marche jusqu'à la porte (avant la séquence), au plus ; point atteint à `StandReach` studs près.
BoardingMotion.WalkMaxS = 1.0
BoardingMotion.StandReach = 2.0
-- Point d'arrivée à la porte : à l'extérieur de la caisse, un peu en arrière de la poignée.
BoardingMotion.StandOut = 1.4
BoardingMotion.StandBehind = 0.4
-- Point de dépôt à la sortie : en arrière de la porte ouverte (hors de son balayage).
BoardingMotion.ExitOut = 2.2
BoardingMotion.ExitBehind = 0.8

local function plan(kind: Kind): any
    return if kind == "In" then BoardingMotion.Entry else BoardingMotion.Exit
end

function BoardingMotion.total(kind: Kind): number
    return plan(kind).Total
end

-- ===================================== Codage =====================================

function BoardingMotion.encode(sequence: Sequence): string
    local p = sequence.Point
    return string.format(
        "%s;%s;%s;%.3f;%.3f;%.3f;%.3f;%.4f",
        sequence.Kind,
        sequence.Seat,
        sequence.Door,
        sequence.T,
        p.X,
        p.Y,
        p.Z,
        sequence.Yaw
    )
end

local function role(text: string?): Doors.Role?
    if text == "Driver" then
        return "Driver"
    elseif text == "Passenger" then
        return "Passenger"
    end
    return nil
end

function BoardingMotion.decode(value: any): Sequence?
    if type(value) ~= "string" then
        return nil
    end
    local fields = string.split(value, ";")
    if #fields ~= 8 then
        return nil
    end
    local kind: Kind? = if fields[1] == "In" then "In" elseif fields[1] == "Out" then "Out" else nil
    local seat, door = role(fields[2]), role(fields[3])
    local numbers: { number } = {}
    for i = 4, 8 do
        local n = tonumber(fields[i])
        if n == nil or n ~= n or math.abs(n) == math.huge then
            return nil
        end
        table.insert(numbers, n)
    end
    if kind == nil or seat == nil or door == nil then
        return nil
    end
    -- Rôles relus en type singleton (le module des portes, gelé, les élargirait en `string`).
    local seatRole: Doors.Role = if seat == "Driver" then "Driver" else "Passenger"
    local doorRole: Doors.Role = if door == "Driver" then "Driver" else "Passenger"
    return {
        Kind = kind,
        Seat = seatRole,
        Door = doorRole,
        T = numbers[1],
        Point = Vector3.new(numbers[2], numbers[3], numbers[4]),
        Yaw = numbers[5],
    }
end

-- ===================================== Outils =====================================

local function eased(f: number): number
    local t = math.clamp(f, 0, 1)
    return t * t * (3 - 2 * t)
end

-- Rampe adoucie de 0 (avant `a`) à 1 (après `b`).
local function ramp(t: number, a: number, b: number): number
    if b <= a then
        return if t >= b then 1 else 0
    end
    return eased((t - a) / (b - a))
end

-- Cap (`CFrame.Angles(0, yaw, 0)`) qui regarde dans la direction horizontale `d`.
function BoardingMotion.yawOf(d: Vector3): number
    return math.atan2(-d.X, -d.Z)
end

local function wrap(angle: number): number
    local a = (angle + math.pi) % (2 * math.pi)
    return a - math.pi
end

-- ===================================== Porte =====================================

-- Fraction d'ouverture de la porte utilisée par la séquence (0 fermée, 1 ouverte), à `t` secondes du début.
function BoardingMotion.doorFraction(kind: Kind, t: number): number
    local p = plan(kind)
    if t < p.CloseStart then
        return ramp(t, p.OpenStart, p.OpenEnd)
    end
    return 1 - ramp(t, p.CloseStart, p.CloseEnd)
end

-- ===================================== Durées utiles =====================================

-- Commandes de conduite bloquées (conducteur) : pendant toute la séquence.
function BoardingMotion.locked(sequence: Sequence, now: number): boolean
    return now >= sequence.T and now < sequence.T + BoardingMotion.total(sequence.Kind)
end

-- Caméra à la 3e personne (décision du propriétaire) : toute l'entrée ; à la sortie, dès l'ouverture de la porte.
function BoardingMotion.cameraHeld(sequence: Sequence, now: number): boolean
    local t = now - sequence.T
    if sequence.Kind == "In" then
        return t >= 0 and t < BoardingMotion.Entry.Total
    end
    return t >= BoardingMotion.Exit.OpenStart
end

-- Poids de la chorégraphie sur la pose assise : 1 pendant l'entrée puis fondu ; fondu au début de la sortie puis 1
-- jusqu'à la libération du siège.
function BoardingMotion.weight(sequence: Sequence, now: number): number
    local t = now - sequence.T
    if t < 0 then
        return 0
    end
    if sequence.Kind == "In" then
        return 1 - ramp(t, BoardingMotion.Entry.Total, BoardingMotion.Entry.Total + BoardingMotion.BlendS)
    end
    return ramp(t, 0, BoardingMotion.BlendS)
end

-- Séquence terminée (fondu compris) : l'attribut peut être retiré.
function BoardingMotion.finished(sequence: Sequence, now: number): boolean
    return now >= sequence.T + BoardingMotion.total(sequence.Kind) + BoardingMotion.BlendS
end

-- ===================================== Points de départ et d'arrivée =====================================

-- Point où le personnage va se placer avant d'ouvrir (repère du châssis, hauteur indifférente : marche).
function BoardingMotion.standPoint(spec: Doors.Spec, sideHalf: number): Vector3
    return Vector3.new(
        spec.Side * (sideHalf + BoardingMotion.StandOut),
        spec.Handle.Y,
        spec.Handle.Z + BoardingMotion.StandBehind
    )
end

-- Point de dépôt préféré à la sortie (hors du balayage de la porte ouverte) ; hauteur à fixer sur le sol.
function BoardingMotion.exitPoint(side: number, sideHalf: number, seatZ: number): Vector3
    return Vector3.new(side * (sideHalf + BoardingMotion.ExitOut), 0, seatZ + BoardingMotion.ExitBehind)
end

-- Cap du personnage déposé : face à l'avant du véhicule (comme le placement du serveur).
BoardingMotion.ExitYaw = 0

-- ===================================== Trajet du corps =====================================

export type Key = { Time: number, Position: Vector3, Yaw: number }

--[[
    Positions et caps clés du HumanoidRootPart « visible » (repère du châssis).
    `seated` : position réelle du HumanoidRootPart assis (repère du châssis), lue à chaque image ; `side` : côté de la
    porte (−1 gauche, +1 droite) ; `sideHalf` : demi-largeur de la caisse.
]]
function BoardingMotion.keys(sequence: Sequence, spec: Doors.Spec, seated: Vector3, sideHalf: number): { Key }
    local s = spec.Side
    local yawOf = BoardingMotion.yawOf
    if sequence.Kind == "In" then
        local e = BoardingMotion.Entry
        local o = sequence.Point
        local sill = s * (sideHalf - 0.25)
        return {
            { Time = 0, Position = o, Yaw = sequence.Yaw },
            -- Recul pendant que la porte s'ouvre vers lui ; regard vers l'ouverture (vers l'avant) : le demi-tour qui
            -- suit ne fait plus qu'environ 100° (180° en 0,5 s dépassait 500°/s).
            {
                Time = e.OpenEnd,
                Position = o + Vector3.new(s * spec.StepBack, 0, 0.2),
                Yaw = yawOf(Vector3.new(-s * 0.6, 0, -0.8)),
            },
            -- Demi-tour : dos à l'habitacle, devant l'ouverture, légèrement fléchi.
            {
                Time = e.Turn,
                Position = Vector3.new(s * (sideHalf + 0.35), o.Y - 0.1, seated.Z + 0.45),
                Yaw = yawOf(Vector3.new(s, 0, -0.5)),
            },
            -- Première jambe dans l'habitacle, bassin au-dessus du seuil.
            {
                Time = e.LegIn,
                Position = Vector3.new(sill, o.Y + (seated.Y - o.Y) * 0.55, seated.Z + 0.2),
                Yaw = yawOf(Vector3.new(s * 0.7, 0, -1)),
            },
            -- Assis, encore tourné vers la porte (seconde jambe dehors).
            {
                Time = e.Sit,
                Position = seated + Vector3.new(s * 0.1, 0, 0),
                Yaw = yawOf(Vector3.new(s * 0.35, 0, -1)),
            },
            { Time = e.SecondLeg, Position = seated, Yaw = 0 },
            { Time = e.Total, Position = seated, Yaw = 0 },
        }
    end
    local x = BoardingMotion.Exit
    local d = sequence.Point
    local sill = s * (sideHalf - 0.1)
    return {
        { Time = 0, Position = seated, Yaw = 0 },
        { Time = x.OpenEnd, Position = seated, Yaw = 0 },
        -- Pivot vers la porte, premier pied au sol.
        {
            Time = x.FirstFoot,
            Position = seated + Vector3.new(s * 0.1, 0, 0),
            Yaw = yawOf(Vector3.new(s * 0.4, 0, -1)),
        },
        {
            Time = x.SecondFoot,
            Position = seated + Vector3.new(s * 0.3, 0.05, 0.05),
            Yaw = yawOf(Vector3.new(s * 0.8, 0, -1)),
        },
        -- Se relève, buste penché, au-dessus du seuil.
        {
            Time = x.Rise,
            Position = Vector3.new(sill, seated.Y + (d.Y - seated.Y) * 0.6, seated.Z + 0.15),
            Yaw = yawOf(Vector3.new(s, 0, -0.6)),
        },
        -- Debout, hors de l'habitacle, en chemin vers le point de dépôt.
        {
            Time = x.Stand,
            Position = Vector3.new(sill + (d.X - sill) * 0.5, d.Y, seated.Z + (d.Z - seated.Z) * 0.6),
            Yaw = yawOf(Vector3.new(s, 0, -0.3)),
        },
        { Time = x.CloseStart + 0.2, Position = d, Yaw = sequence.Yaw },
        { Time = x.Total, Position = d, Yaw = sequence.Yaw },
    }
end

-- Position (courbe de Hermite, tangentes de Catmull-Rom : vitesse continue, nulle aux extrémités) et cap (adouci par
-- segment, plus court chemin) à `t` secondes.
function BoardingMotion.bodyAt(keys: { Key }, t: number): (Vector3, number)
    local n = #keys
    if t <= keys[1].Time then
        return keys[1].Position, keys[1].Yaw
    end
    if t >= keys[n].Time then
        return keys[n].Position, keys[n].Yaw
    end
    local i = 1
    while i < n - 1 and t > keys[i + 1].Time do
        i += 1
    end
    local a, b = keys[i], keys[i + 1]
    local h = b.Time - a.Time
    local u = if h > 0 then (t - a.Time) / h else 1
    local function tangent(k: number): Vector3
        if k <= 1 or k >= n then
            return Vector3.zero
        end
        local prev, next = keys[k - 1], keys[k + 1]
        local span = next.Time - prev.Time
        return if span > 0 then (next.Position - prev.Position) / span else Vector3.zero
    end
    local m0, m1 = tangent(i) * h, tangent(i + 1) * h
    local u2, u3 = u * u, u * u * u
    local position = a.Position * (2 * u3 - 3 * u2 + 1)
        + m0 * (u3 - 2 * u2 + u)
        + b.Position * (-2 * u3 + 3 * u2)
        + m1 * (u3 - u2)
    local yaw = a.Yaw + wrap(b.Yaw - a.Yaw) * eased(u)
    return position, yaw
end

-- ===================================== Poses des membres =====================================

-- Angles (degrés) de tangage, lacet et roulis dans `Transform` de l'articulation, depuis la pose debout (R15 au repos).
-- Conventions (comme `SeatPose`) : hanche positive = cuisse vers l'avant ; genou négatif = jambe pliée ; buste et cou
-- négatifs = penchés vers l'avant.
-- Jambes : `First` = première jambe engagée (entrée : jambe côté habitacle ; sortie : jambe côté porte).
export type Pose = { [string]: { number } }
export type PoseKey = { Time: number, Pose: Pose }

local SEATED_HIP, SEATED_KNEE = 88, -88

function BoardingMotion.poseKeys(kind: Kind, duck: number): { PoseKey }
    if kind == "In" then
        local e = BoardingMotion.Entry
        return {
            { Time = 0, Pose = {} },
            { Time = e.Reach, Pose = { Waist = { -5, 0, 0 } } },
            { Time = e.OpenEnd, Pose = { Waist = { -5, 0, 0 }, FirstKnee = { -5, 0, 0 } } },
            {
                Time = e.Turn,
                Pose = {
                    Waist = { -duck * 0.6, 0, 0 },
                    Neck = { -15, 0, 0 },
                    FirstHip = { 15, 0, 0 },
                    SecondHip = { 15, 0, 0 },
                    FirstKnee = { -20, 0, 0 },
                    SecondKnee = { -20, 0, 0 },
                },
            },
            {
                Time = e.LegIn,
                Pose = {
                    Waist = { -duck, 0, 0 },
                    Neck = { -20, 0, 0 },
                    FirstHip = { 80, 0, 0 },
                    FirstKnee = { -75, 0, 0 },
                    SecondHip = { 35, 0, 0 },
                    SecondKnee = { -45, 0, 0 },
                },
            },
            {
                Time = e.Sit,
                Pose = {
                    Waist = { -duck * 0.4, 0, 0 },
                    Neck = { -8, 0, 0 },
                    FirstHip = { SEATED_HIP, 0, 0 },
                    FirstKnee = { SEATED_KNEE, 0, 0 },
                    SecondHip = { 70, 0, 0 },
                    SecondKnee = { -75, 0, 0 },
                },
            },
            {
                Time = e.SecondLeg,
                Pose = {
                    FirstHip = { SEATED_HIP, 0, 0 },
                    FirstKnee = { SEATED_KNEE, 0, 0 },
                    SecondHip = { SEATED_HIP, 0, 0 },
                    SecondKnee = { SEATED_KNEE, 0, 0 },
                },
            },
            {
                Time = e.Total,
                Pose = {
                    FirstHip = { SEATED_HIP, 0, 0 },
                    FirstKnee = { SEATED_KNEE, 0, 0 },
                    SecondHip = { SEATED_HIP, 0, 0 },
                    SecondKnee = { SEATED_KNEE, 0, 0 },
                },
            },
        }
    end
    local x = BoardingMotion.Exit
    local seatedPose: Pose = {
        FirstHip = { SEATED_HIP, 0, 0 },
        FirstKnee = { SEATED_KNEE, 0, 0 },
        SecondHip = { SEATED_HIP, 0, 0 },
        SecondKnee = { SEATED_KNEE, 0, 0 },
    }
    return {
        { Time = 0, Pose = seatedPose },
        { Time = x.OpenEnd, Pose = seatedPose },
        {
            Time = x.FirstFoot,
            Pose = {
                Waist = { -5, 0, 0 },
                FirstHip = { 70, 0, 0 },
                FirstKnee = { -80, 0, 0 },
                SecondHip = { SEATED_HIP, 0, 0 },
                SecondKnee = { SEATED_KNEE, 0, 0 },
            },
        },
        {
            Time = x.SecondFoot,
            Pose = {
                Waist = { -duck * 0.8, 0, 0 },
                Neck = { -20, 0, 0 },
                FirstHip = { 70, 0, 0 },
                FirstKnee = { -80, 0, 0 },
                SecondHip = { 70, 0, 0 },
                SecondKnee = { -80, 0, 0 },
            },
        },
        {
            Time = x.Rise,
            Pose = {
                Waist = { -duck, 0, 0 },
                Neck = { -15, 0, 0 },
                FirstHip = { 40, 0, 0 },
                FirstKnee = { -45, 0, 0 },
                SecondHip = { 40, 0, 0 },
                SecondKnee = { -45, 0, 0 },
            },
        },
        { Time = x.Stand, Pose = { Waist = { -3, 0, 0 } } },
        { Time = x.Total, Pose = {} },
    }
end

-- Pose (radians, par nom générique) à `t` secondes : interpolation adoucie entre les deux poses clés voisines (une
-- articulation absente d'une pose est au repos).
function BoardingMotion.poseAt(keys: { PoseKey }, t: number): { [string]: Vector3 }
    local n = #keys
    local i = 1
    while i < n and t > keys[i + 1].Time do
        i += 1
    end
    local a = keys[i]
    local b = keys[math.min(i + 1, n)]
    local u = if b.Time > a.Time then eased((t - a.Time) / (b.Time - a.Time)) else 1
    if t <= keys[1].Time then
        u = 0
    end
    local result: { [string]: Vector3 } = {}
    local names: { [string]: boolean } = {}
    for name in a.Pose do
        names[name] = true
    end
    for name in b.Pose do
        names[name] = true
    end
    for name in names do
        local va = a.Pose[name] or { 0, 0, 0 }
        local vb = b.Pose[name] or { 0, 0, 0 }
        result[name] = Vector3.new(
            math.rad(va[1] + (vb[1] - va[1]) * u),
            math.rad(va[2] + (vb[2] - va[2]) * u),
            math.rad(va[3] + (vb[3] - va[3]) * u)
        )
    end
    return result
end

-- Articulation R15 d'un nom générique, pour une porte du côté `side`. Entrée : première jambe = côté habitacle
-- (porte gauche : jambe droite). Sortie : première jambe = côté porte (porte gauche : jambe gauche).
function BoardingMotion.jointName(generic: string, kind: Kind, side: number): string?
    local inner = if side < 0 then "Right" else "Left" -- côté habitacle (personnage assis face à l'avant)
    local outer = if side < 0 then "Left" else "Right" -- côté porte
    local first = if kind == "In" then inner else outer
    local second = if kind == "In" then outer else inner
    if generic == "Waist" or generic == "Neck" then
        return generic
    elseif generic == "FirstHip" then
        return first .. "Hip"
    elseif generic == "FirstKnee" then
        return first .. "Knee"
    elseif generic == "SecondHip" then
        return second .. "Hip"
    elseif generic == "SecondKnee" then
        return second .. "Knee"
    end
    return nil
end

-- ===================================== Mains =====================================

export type Grip = {
    Arm: string, -- "Left" | "Right"
    Inner: boolean, -- poignée intérieure (sinon extérieure)
    Weight: number, -- 0 à 1 : part de la cinématique inverse sur la pose du bras
}

--[[
    Mains sur les poignées à `t` secondes (au plus une). Entrée : main côté arrière de la porte sur la poignée
    extérieure, puis main côté porte sur la poignée intérieure. Sortie : l'inverse. Face à la caisse (porte gauche), la
    poignée, à l'arrière de la porte, est à droite du personnage ; assis, la porte est à sa gauche.
]]
function BoardingMotion.grip(kind: Kind, side: number, t: number): Grip?
    local facing = if side < 0 then "Right" else "Left" -- debout face à la caisse, ou dos à l'avant porte à côté
    local doorArm = if side < 0 then "Left" else "Right" -- assis face à l'avant
    if kind == "In" then
        local e = BoardingMotion.Entry
        if t < e.Turn then
            local w = ramp(t, 0, e.Reach) * (1 - ramp(t, e.HandleRelease, e.HandleRelease + 0.3))
            return if w > 0 then { Arm = facing, Inner = false, Weight = w } else nil
        end
        local w = ramp(t, e.InnerReach, e.CloseStart)
        return if w > 0 then { Arm = doorArm, Inner = true, Weight = w } else nil
    end
    local x = BoardingMotion.Exit
    if t < x.FirstFoot then
        local w = ramp(t, 0, x.InnerReach) * (1 - ramp(t, x.InnerRelease, x.InnerRelease + 0.3))
        return if w > 0 then { Arm = doorArm, Inner = true, Weight = w } else nil
    end
    local w = ramp(t, x.OuterReach, x.CloseStart)
    return if w > 0 then { Arm = facing, Inner = false, Weight = w } else nil
end

-- Poignée (repère du châssis) sur la porte à la fraction d'ouverture donnée : la main suit la porte.
function BoardingMotion.handlePoint(spec: Doors.Spec, inner: boolean, fraction: number): Vector3
    local point = if inner then spec.InnerHandle else spec.Handle
    return Doors.rotatePoint(spec, point, Doors.angle(spec, fraction))
end

return table.freeze(BoardingMotion)
