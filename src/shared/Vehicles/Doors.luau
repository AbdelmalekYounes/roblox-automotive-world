--!strict
--[[
    Portières articulées et séquences d'entrée et de sortie (lot ANIM-02). Module PUR (aucun service), testé par Lune ;
    utilisé par le serveur (articulations : `Vehicles/MeshKits` ; séquences : `Vehicles/DoorService`) et par chaque
    client (rotation des portes et glissé des personnages : `Vehicles/DoorVisuals`, `Vehicles/SeatPoseController`).

    Décisions du propriétaire (2026-11-06, posées en une fois au début du lot) :
    - animation SIMPLIFIÉE : le personnage marche jusqu'à la porte (1 s au plus), la porte s'ouvre d'elle-même, le corps
      glisse jusqu'au siège, la porte se referme ; sortie dans l'ordre inverse ; pas de main sur la poignée ;
    - durée ≈ 1 s à l'entrée (porte 0,35 s, glissé 0,5 s, fermeture 0,35 s qui ne bloque pas la conduite), ≈ 0,8 s à la
      sortie ;
    - passager : même séquence, par sa porte ; portes TOUJOURS fermées à l'arrêt ; sortie par l'autre porte si le côté
      est bloqué (tout bloqué : sortie par le dessus, sans animation) ;
    - portes purement VISUELLES (sans masse ni collision) : les boîtes `Collisions` du kit et `DamageService` sont
      inchangées.

    Repère : celui du châssis (studs, avant vers −Z, haut +Y, droite +X). Rôles : `Driver` (porte gauche, conducteur) et
    `Passenger` (porte droite). L'axe d'une charnière est orienté pour qu'un angle POSITIF ouvre la porte (la porte
    s'écarte de la caisse) ; la porte droite est le miroir de la gauche.

    Réplication : l'état d'une porte est un attribut texte du modèle (« de;vers;début;durée », temps du serveur
    `Workspace:GetServerTimeNow`), écrit par le serveur seul ; le glissé d'un personnage est un attribut texte du
    personnage. Chaque client en déduit l'angle et le glissé à chaque image : tout le monde voit la même chose, sans
    réplication par image.
]]

local Doors = {}

export type Role = "Driver" | "Passenger"

export type Spec = {
    Parts: { string }, -- pièces du gabarit qui suivent la porte (peau, panneau intérieur, vitre, rétroviseur…)
    Hinge: Vector3, -- point de l'axe de la charnière (repère du châssis)
    Axis: Vector3, -- axe unitaire, orienté pour qu'un angle positif ouvre la porte
    OpenAngle: number, -- ouverture complète (degrés)
    Side: number, -- −1 gauche, +1 droite
}

export type Pair = { Driver: Spec, Passenger: Spec }

-- Données d'une porte gauche (conducteur) et liste des pièces de la porte droite, miroir de la gauche.
export type LeftSpec = {
    Parts: { string },
    PassengerParts: { string },
    Hinge: Vector3,
    Axis: Vector3,
    OpenAngle: number,
}

local DRIVER: Role = "Driver"
local PASSENGER: Role = "Passenger"
local ROLES: { Role } = { DRIVER, PASSENGER }
Doors.Roles = table.freeze(ROLES)

-- Durées (secondes), décision « ≈ 1 s / 0,8 s ».
Doors.OpenS = 0.35
Doors.CloseS = 0.35
Doors.FastCloseS = 0.2 -- fermeture après interruption
Doors.GlideInS = 0.5
Doors.GlideOutS = 0.45
Doors.WalkMaxS = 1.0 -- marche jusqu'à la porte, au plus
Doors.FlashOpenS = 0.25 -- porte entrouverte puis refermée quand un occupant sort sans séquence (saut du moteur)

-- Point d'arrivée à la porte : à `StandOut` studs à l'extérieur de la caisse, au droit du siège ; atteint à
-- `StandReach` studs près (distance horizontale).
Doors.StandOut = 1.6
Doors.StandReach = 2.5
-- Interruption : véhicule qui part ou qui est poussé (vitesse au-delà, studs par seconde ≈ 4 km/h).
Doors.InterruptSpeed = 4
-- Garde-fou du glissé : au-delà, aucun glissé (point aberrant, téléportation).
Doors.MaxGlide = 14

-- Noms des instances et des attributs.
Doors.JointName = "AWPortiere" -- Motor6D de la charnière (enfant de la pièce de charnière)
Doors.HingeName = table.freeze({ Driver = "AWCharniereConducteur", Passenger = "AWCharnierePassager" })
Doors.DoorAttribute = table.freeze({ Driver = "AWPorteConducteur", Passenger = "AWPortePassager" })
Doors.GlideAttribute = "AWPortiereGlisse" -- sur le personnage : glissé en cours
Doors.ApproachAttribute = "AWPortiereApproche" -- sur le personnage : point de la porte (monde), marche du client
Doors.RemoteName = "AWPortieres" -- RemoteEvent client → serveur : demande de sortie du passager
Doors.ExitRequest = "Descendre"

-- Porte droite : miroir de la gauche par le plan x = 0. Pour une symétrie S, une rotation d'angle θ autour de a
-- devient une rotation d'angle −θ autour de S·a, soit +θ autour de −S·a = (a.x, −a.y, −a.z).
function Doors.mirror(spec: Spec, parts: { string }): Spec
    local a = spec.Axis
    return table.freeze({
        Parts = table.freeze(table.clone(parts)),
        Hinge = Vector3.new(-spec.Hinge.X, spec.Hinge.Y, spec.Hinge.Z),
        Axis = Vector3.new(a.X, -a.Y, -a.Z),
        OpenAngle = spec.OpenAngle,
        Side = -spec.Side,
    })
end

function Doors.pair(left: LeftSpec): Pair
    local driver: Spec = table.freeze({
        Parts = table.freeze(table.clone(left.Parts)),
        Hinge = left.Hinge,
        Axis = left.Axis.Unit,
        OpenAngle = left.OpenAngle,
        Side = -1,
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

-- ===================================== Glissé du personnage =====================================

--[[
    Glissé : pendant que le personnage est assis (son HumanoidRootPart soudé au siège), chaque client décale son corps
    (articulation `Root`) :
    - `In` (entrée) : depuis `Point` (position du HumanoidRootPart debout à la porte, repère du châssis) jusqu'au siège,
      en `GlideInS` à partir de `T` ;
    - `Out` (sortie) : du siège jusqu'à `Point` (position de sortie à côté du véhicule), en `GlideOutS` à partir de `T`,
      puis maintenu jusqu'à ce que le serveur libère le siège et dépose le personnage à ce point.
]]
export type GlideKind = "In" | "Out"
export type Glide = { Kind: GlideKind, Role: Role, T: number, Point: Vector3 }

function Doors.encodeGlide(glide: Glide): string
    local p = glide.Point
    return string.format("%s;%s;%.3f;%.3f;%.3f;%.3f", glide.Kind, glide.Role, glide.T, p.X, p.Y, p.Z)
end

function Doors.decodeGlide(value: any): Glide?
    if type(value) ~= "string" then
        return nil
    end
    local kind, role, t, x, y, z = string.match(value, "^(%a+);(%a+);([%-%d%.]+);([%-%d%.]+);([%-%d%.]+);([%-%d%.]+)$")
    if (kind ~= "In" and kind ~= "Out") or (role ~= "Driver" and role ~= "Passenger") then
        return nil
    end
    local tn, xn, yn, zn = tonumber(t), tonumber(x), tonumber(y), tonumber(z)
    if tn == nil or xn == nil or yn == nil or zn == nil then
        return nil
    end
    return { Kind = kind :: GlideKind, Role = role :: Role, T = tn, Point = Vector3.new(xn, yn, zn) }
end

-- Part du décalage vers `Point` (1 : corps au point, 0 : corps au siège).
function Doors.glideWeight(glide: Glide, now: number): number
    if glide.Kind == "In" then
        return 1 - Doors.eased((now - glide.T) / Doors.GlideInS)
    end
    return Doors.eased((now - glide.T) / Doors.GlideOutS)
end

-- Décalage du corps (monde) : du HumanoidRootPart assis (`seated`) vers le point, pondéré ; nil si nul ou aberrant.
function Doors.glideOffset(glide: Glide, now: number, chassis: CFrame, seated: Vector3): Vector3?
    local weight = Doors.glideWeight(glide, now)
    if weight <= 0 then
        return nil
    end
    local delta = chassis:PointToWorldSpace(glide.Point) - seated
    if delta.Magnitude > Doors.MaxGlide then
        return nil
    end
    return delta * weight
end

-- ===================================== Séquences =====================================

-- Point d'arrivée à la porte (repère du châssis) : à l'extérieur de la caisse, au droit du siège.
function Doors.standPoint(side: number, sideHalf: number, seat: Vector3): Vector3
    return Vector3.new(side * (sideHalf + Doors.StandOut), seat.Y, seat.Z)
end

-- Calendrier d'une entrée (secondes depuis l'acceptation) : la porte s'ouvre pendant la marche ; le personnage s'assoit
-- quand il est arrivé ET la porte ouverte ; la porte se referme à la fin du glissé.
function Doors.entryPlan(walkS: number): { SitAt: number, CloseAt: number, DoneAt: number }
    local sitAt = math.max(math.clamp(walkS, 0, Doors.WalkMaxS), Doors.OpenS)
    local closeAt = sitAt + Doors.GlideInS
    return { SitAt = sitAt, CloseAt = closeAt, DoneAt = closeAt + Doors.CloseS }
end

-- Calendrier d'une sortie : porte ouverte, puis glissé vers l'extérieur, puis libération du siège et fermeture.
function Doors.exitPlan(): { GlideAt: number, ReleaseAt: number, DoneAt: number }
    local releaseAt = Doors.OpenS + Doors.GlideOutS
    return { GlideAt = Doors.OpenS, ReleaseAt = releaseAt, DoneAt = releaseAt + Doors.CloseS }
end

-- Interruption (véhicule qui part, choc) : vitesse au-delà du seuil, ou nouveau choc compté par les dégâts.
function Doors.shouldInterrupt(speed: number, impactsAtStart: number?, impactsNow: number?): boolean
    if speed > Doors.InterruptSpeed then
        return true
    end
    return impactsAtStart ~= nil and impactsNow ~= nil and impactsNow > impactsAtStart
end

-- Porte (rôle) correspondant à un point de sortie : celle du côté où il se trouve ; nil au-dessus du véhicule (tout
-- bloqué : sortie sans animation).
function Doors.roleForExit(localPoint: Vector3, sideHalf: number): Role?
    if math.abs(localPoint.X) < sideHalf then
        return nil
    end
    return if localPoint.X < 0 then DRIVER else PASSENGER
end

return table.freeze(Doors)
