--!strict
--[[
    Portières articulées (lot ANIM-02, repris au lot ANIM-03). Module PUR (aucun service), testé par Lune ; utilisé par
    le serveur (articulations : `Vehicles/MeshKits` ; séquences : `Vehicles/DoorService`) et par chaque client
    (rotation des portes : `Vehicles/DoorVisuals`). La chorégraphie d'entrée et de sortie (lot ANIM-03) est dans
    `Shared.Vehicles.BoardingMotion`.

    Portes purement VISUELLES (sans masse ni collision) : les boîtes `Collisions` du kit et `DamageService` sont
    inchangées (décision du propriétaire du 2026-11-06, lot ANIM-02).

    Repère : celui du châssis (studs, avant vers −Z, haut +Y, droite +X). Rôles : `Driver` (porte gauche, conducteur) et
    `Passenger` (porte droite). L'axe d'une charnière est orienté pour qu'un angle POSITIF ouvre la porte (la porte
    s'écarte de la caisse) ; la porte droite est le miroir de la gauche.

    Réplication : l'état d'une porte est un attribut texte du modèle (« de;vers;début;durée », temps du serveur
    `Workspace:GetServerTimeNow`), écrit par le serveur seul. Pendant une séquence d'entrée ou de sortie, chaque client
    calcule l'angle de la porte à partir de la séquence elle-même (même horloge que la main sur la poignée).
]]

local Doors = {}

export type Role = "Driver" | "Passenger"

export type Spec = {
    Parts: { string }, -- pièces du gabarit qui suivent la porte (peau, panneau intérieur, vitre, rétroviseur…)
    Hinge: Vector3, -- point de l'axe de la charnière (repère du châssis)
    Axis: Vector3, -- axe unitaire, orienté pour qu'un angle positif ouvre la porte
    OpenAngle: number, -- ouverture complète (degrés)
    Side: number, -- −1 gauche, +1 droite
    -- Lot ANIM-03 : poignées (porte fermée, repère du châssis) visées par la main, et réglages du geste.
    Handle: Vector3, -- poignée extérieure
    InnerHandle: Vector3, -- poignée intérieure (tirer la porte en entrant, la pousser en sortant)
    StepBack: number, -- recul du personnage pendant l'ouverture (studs ; porte qui s'ouvre vers lui)
    Duck: number, -- inclinaison du buste vers l'avant pour passer sous le pavillon (degrés)
}

export type Pair = { Driver: Spec, Passenger: Spec }

-- Données d'une porte gauche (conducteur) et liste des pièces de la porte droite, miroir de la gauche.
export type LeftSpec = {
    Parts: { string },
    PassengerParts: { string },
    Hinge: Vector3,
    Axis: Vector3,
    OpenAngle: number,
    Handle: Vector3,
    InnerHandle: Vector3,
    StepBack: number,
    Duck: number,
}

local DRIVER: Role = "Driver"
local PASSENGER: Role = "Passenger"
local ROLES: { Role } = { DRIVER, PASSENGER }
Doors.Roles = table.freeze(ROLES)

Doors.CloseS = 0.35 -- fermeture d'une porte tenue ouverte (aucune séquence en cours)
Doors.FlashOpenS = 0.25 -- porte entrouverte puis refermée quand un occupant sort sans séquence (saut du moteur)

-- Noms des instances et des attributs.
Doors.JointName = "AWPortiere" -- Motor6D de la charnière (enfant de la pièce de charnière)
Doors.HingeName = table.freeze({ Driver = "AWCharniereConducteur", Passenger = "AWCharnierePassager" })
Doors.DoorAttribute = table.freeze({ Driver = "AWPorteConducteur", Passenger = "AWPortePassager" })
Doors.ApproachAttribute = "AWPortiereApproche" -- sur le personnage : point de la porte (monde), marche du client
Doors.RemoteName = "AWPortieres" -- RemoteEvent client → serveur : demande de sortie du passager
Doors.ExitRequest = "Descendre"

local function mirrorPoint(p: Vector3): Vector3
    return Vector3.new(-p.X, p.Y, p.Z)
end

-- Porte droite : miroir de la gauche par le plan x = 0. Pour une symétrie S, une rotation d'angle θ autour de a
-- devient une rotation d'angle −θ autour de S·a, soit +θ autour de −S·a = (a.x, −a.y, −a.z).
function Doors.mirror(spec: Spec, parts: { string }): Spec
    local a = spec.Axis
    return table.freeze({
        Parts = table.freeze(table.clone(parts)),
        Hinge = mirrorPoint(spec.Hinge),
        Axis = Vector3.new(a.X, -a.Y, -a.Z),
        OpenAngle = spec.OpenAngle,
        Side = -spec.Side,
        Handle = mirrorPoint(spec.Handle),
        InnerHandle = mirrorPoint(spec.InnerHandle),
        StepBack = spec.StepBack,
        Duck = spec.Duck,
    })
end

function Doors.pair(left: LeftSpec): Pair
    local driver: Spec = table.freeze({
        Parts = table.freeze(table.clone(left.Parts)),
        Hinge = left.Hinge,
        Axis = left.Axis.Unit,
        OpenAngle = left.OpenAngle,
        Side = -1,
        Handle = left.Handle,
        InnerHandle = left.InnerHandle,
        StepBack = left.StepBack,
        Duck = left.Duck,
    })
    return table.freeze({ Driver = driver, Passenger = Doors.mirror(driver, left.PassengerParts) })
end

-- Repère de l'articulation dans le châssis : origine sur l'axe de la charnière, Z le long de l'axe. Une rotation
-- `CFrame.fromAxisAngle(Z, angle)` de ce repère ouvre la porte de `angle`.
function Doors.jointFrame(spec: Spec): CFrame
    local z = spec.Axis.Unit
    local ref = if math.abs(z.X) < 0.9 then Vector3.xAxis else Vector3.zAxis
    local x = (ref - z * ref:Dot(z)).Unit
    local y = z:Cross(x)
    return CFrame.fromMatrix(spec.Hinge, x, y, z)
end

function Doors.jointTransform(angle: number): CFrame
    return CFrame.fromAxisAngle(Vector3.zAxis, angle)
end

-- Déplacement d'un point de la porte (repère du châssis) pour un angle d'ouverture (radians).
function Doors.rotatePoint(spec: Spec, point: Vector3, angle: number): Vector3
    local frame = Doors.jointFrame(spec)
    return (frame * Doors.jointTransform(angle) * frame:Inverse()) * point
end

-- Ouverture adoucie (départ et arrivée en douceur).
function Doors.eased(f: number): number
    local t = math.clamp(f, 0, 1)
    return t * t * (3 - 2 * t)
end

function Doors.angle(spec: Spec, fraction: number): number
    return math.rad(spec.OpenAngle) * Doors.eased(fraction)
end

-- ===================================== État d'une porte (répliqué) =====================================

-- Fraction d'ouverture qui va de `From` à `To` (0 fermée, 1 ouverte) entre `T` et `T + Duration`.
export type State = { From: number, To: number, T: number, Duration: number }

function Doors.fraction(state: State?, now: number): number
    if state == nil then
        return 0
    end
    local p = if state.Duration <= 0 then 1 else math.clamp((now - state.T) / state.Duration, 0, 1)
    return state.From + (state.To - state.From) * p
end

-- Nouvel état vers `to`, en partant de la fraction actuelle (une porte qui se referme en cours d'ouverture repart d'où
-- elle est). La durée est proportionnelle au chemin restant.
function Doors.transition(current: State?, now: number, to: number, fullDuration: number): State
    local from = Doors.fraction(current, now)
    return { From = from, To = to, T = now, Duration = fullDuration * math.abs(to - from) }
end

function Doors.encode(state: State): string
    return string.format("%.3f;%.3f;%.3f;%.3f", state.From, state.To, state.T, state.Duration)
end

function Doors.decode(value: any): State?
    if type(value) ~= "string" then
        return nil
    end
    local a, b, c, d = string.match(value, "^([%-%d%.]+);([%-%d%.]+);([%-%d%.]+);([%-%d%.]+)$")
    local from, to, t, duration = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
    if from == nil or to == nil or t == nil or duration == nil then
        return nil
    end
    return {
        From = math.clamp(from, 0, 1),
        To = math.clamp(to, 0, 1),
        T = t,
        Duration = math.max(duration, 0),
    }
end

-- ===================================== Sortie =====================================

-- Porte (rôle) correspondant à un point de sortie : celle du côté où il se trouve ; nil au-dessus du véhicule (tout
-- bloqué : sortie sans animation).
function Doors.roleForExit(localPoint: Vector3, sideHalf: number): Role?
    if math.abs(localPoint.X) < sideHalf then
        return nil
    end
    return if localPoint.X < 0 then DRIVER else PASSENGER
end

return table.freeze(Doors)
