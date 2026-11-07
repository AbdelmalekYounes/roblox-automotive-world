--!strict
--[[
    Piétons PURS et DÉTERMINISTES (cahier des charges §2.4, zones animées).

    La position de chaque piéton ne dépend que du tronçon, de son numéro et de
    l'heure du serveur : chaque client calcule les mêmes passants sans aucun
    échange réseau, et seulement autour de sa caméra (coût borné).
    Les piétons marchent sur les trottoirs des classes de route qui en ont
    (WorldConfig.RoadClasses[*].Pedestrians), en aller-retour, avec une densité
    propre à la zone (WorldConfig.ZoneDensity).

    Limite de ce lot : ce sont des figurants visuels NON SOLIDES (pas de
    collision, pas de lancer de rayon) ; ils restent sur les trottoirs, à
    l'écart des plateformes de carrefour, et ne traversent pas la chaussée.
]]

local Geometry = require(script.Parent.Geometry)
local WorldConfig = require(script.Parent.WorldConfig)
local TrafficModel = require(script.Parent.TrafficModel)

local PedestrianModel = {}

-- Un piéton tous les SPACING_M mètres de trottoir à densité 1.
PedestrianModel.SpacingM = 30
PedestrianModel.SpeedRangeMs = table.freeze({ 1.0, 1.6 })
-- Hauteur du trottoir au-dessus du tracé (bordure du générateur).
PedestrianModel.CurbM = 0.2
-- Marge laissée libre à chaque bout du trottoir (plateforme des carrefours).
PedestrianModel.JunctionMarginM = 15

export type Walker = {
    Key: string, -- identifiant stable "<tronçon>|<côté>|<n>"
    Position: Geometry.Point3,
    Heading: Geometry.Point,
    -- Lot PNJ-01 : vitesse (m/s) et distance parcourue (m, phase de l'allure animée, World/PedestrianGait).
    Speed: number,
    Travel: number,
}

export type Sidewalk = {
    EdgeId: string,
    Side: number,
    Path: TrafficModel.Path,
    Count: number,
    Seed: number,
}

local function hash(text: string): number
    local h = 2166136261
    for i = 1, #text do
        h = bit32.bxor(h, string.byte(text, i))
        h = (h * 16777619) % 4294967296
    end
    return h
end

-- Tirage déterministe dans [0 ; 1[ à partir d'une graine entière et d'un index.
local function unit(seed: number, index: number): number
    local h = hash(tostring(seed) .. ":" .. tostring(index))
    return (h % 1000003) / 1000003
end

--[[
    Trottoirs d'un tronçon (`edge` : WorldLayout.EdgeLayout), côtés -1 et 1.
    Vide si la classe n'a pas de piétons ou si la zone n'en a pas.
]]
function PedestrianModel.sidewalks(edge: any): { Sidewalk }
    local roadClass = WorldConfig.RoadClasses[edge.Class]
    local density = (WorldConfig.ZoneDensity :: any)[edge.Zone]
    local result: { Sidewalk } = {}
    if not roadClass.Pedestrians or roadClass.SidewalkM <= 0 or density == nil or density.Pedestrians <= 0 then
        return result
    end
    local offset = WorldConfig.carriagewayWidthM(roadClass) / 2 + roadClass.SidewalkM / 2
    local source = edge.Polyline
    local count = #source
    for _, side in { -1, 1 } do
        local points: { Geometry.Point3 } = {}
        for i = 1, count do
            local a, b = source[math.max(i - 1, 1)], source[math.min(i + 1, count)]
            local dx, dz = b.X - a.X, b.Z - a.Z
            local length = math.sqrt(dx * dx + dz * dz)
            if length < 1e-6 then
                dx, dz, length = 0, -1, 1
            end
            local p = source[i]
            table.insert(points, {
                X = p.X - dz / length * offset * side,
                Z = p.Z + dx / length * offset * side,
                Y = p.Y + PedestrianModel.CurbM,
            })
        end
        local path = TrafficModel.path(points)
        local usable = path.Length - 2 * PedestrianModel.JunctionMarginM
        local walkers = math.floor(math.max(usable, 0) / PedestrianModel.SpacingM * density.Pedestrians)
        if walkers > 0 then
            table.insert(result, {
                EdgeId = edge.Id,
                Side = side,
                Path = path,
                Count = walkers,
                Seed = hash(edge.Id .. "|" .. side),
            })
        end
    end
    return result
end

--[[
    Piéton n° `k` d'un trottoir à l'instant `serverTime` (aller-retour le long du trottoir), ou nil si le trottoir
    est trop court. Lot PNJ-01 : calcul isolé pour que le client anime à chaque image les seuls piétons visibles.
]]
function PedestrianModel.walker(sidewalk: Sidewalk, k: number, serverTime: number): Walker?
    local margin = PedestrianModel.JunctionMarginM
    local length = sidewalk.Path.Length - 2 * margin
    if length < 5 then
        return nil
    end
    local range = PedestrianModel.SpeedRangeMs
    local phase = unit(sidewalk.Seed, k * 2)
    local speed = range[1] + (range[2] - range[1]) * unit(sidewalk.Seed, k * 2 + 1)
    -- Parcours replié : 0 → L à l'aller, L → 0 au retour.
    local distance = phase * 2 * length + speed * serverTime
    local travel = distance % (2 * length)
    local returning = travel > length
    local s = margin + (if returning then 2 * length - travel else travel)
    local position, direction = TrafficModel.sample(sidewalk.Path, s)
    local heading = if returning then { X = -direction.X, Z = -direction.Z } else direction
    return {
        Key = sidewalk.EdgeId .. "|" .. sidewalk.Side .. "|" .. k,
        Position = position,
        Heading = heading,
        Speed = speed,
        Travel = distance,
    }
end

-- Piétons d'un trottoir à l'instant `serverTime`.
function PedestrianModel.walkers(sidewalk: Sidewalk, serverTime: number): { Walker }
    local result: { Walker } = {}
    for k = 1, sidewalk.Count do
        local walker = PedestrianModel.walker(sidewalk, k, serverTime)
        if walker == nil then
            break
        end
        table.insert(result, walker)
    end
    return result
end

return table.freeze(PedestrianModel)
