--!strict
-- Modèle de dégâts PUR, en session (aucune persistance avant le lot 0.4, mais
-- un état simple, versionné et sérialisable en attributs).
--
-- Entrée : un choc CONFIRMÉ par le serveur (zone touchée, roue la plus proche,
-- variation de vitesse due au choc en m/s, hors freinage). Sortie :
-- 1. usure de carrosserie par zone (avant, arrière, gauche, droite), qui donne
--    trois niveaux visuels : rayures, dégâts localisés, dégâts importants ;
-- 2. santé de composants (moteur, direction, suspension de chaque roue), qui
--    n'est entamée qu'à partir d'un choc « localisé » et se dégrade
--    graduellement ;
-- 3. conséquences mécaniques (`condition`) : puissance réduite, braquage
--    réduit et direction qui tire, adhérence et parallélisme d'une roue faussés.
-- Ordre des roues : 1 avant gauche, 2 avant droite, 3 arrière gauche, 4 arrière droite.

local Types = require(script.Parent.Parent.VehicleTypes)

local DamageModel = {}

DamageModel.Version = 1
-- Seuils de variation de vitesse (m/s) : en dessous de MinImpact, rien.
DamageModel.MinImpact = 1.5
DamageModel.LocalImpact = 4.0
DamageModel.MajorImpact = 8.0
-- Seuils d'usure de zone pour les niveaux visuels 1, 2, 3.
DamageModel.LevelThresholds = table.freeze({ 0.05, 0.3, 0.65 })

export type Zone = "Front" | "Rear" | "Left" | "Right"

export type DamageState = {
    Version: number,
    Zones: { [string]: number }, -- usure 0..1 par zone (voir Zone)
    Engine: number, -- santé 1..0
    Steering: number,
    -- Côté vers lequel la direction tire après un choc (-1 gauche, +1 droite).
    SteeringPullSide: number,
    Suspension: { number }, -- santé par roue
    Impacts: number,
}

export type ImpactResult = {
    Zone: string,
    Corner: number,
    DeltaV: number,
    Level: number, -- niveau visuel atteint par la zone après ce choc
    Mechanical: boolean, -- vrai si un composant a été entamé
}

local ZONES: { string } = { "Front", "Rear", "Left", "Right" }
DamageModel.Zones = table.freeze(ZONES)

function DamageModel.new(): DamageState
    return {
        Version = DamageModel.Version,
        Zones = { Front = 0, Rear = 0, Left = 0, Right = 0 },
        Engine = 1,
        Steering = 1,
        SteeringPullSide = 0,
        Suspension = { 1, 1, 1, 1 },
        Impacts = 0,
    }
end

-- Niveau visuel (0 à 3) d'une usure de zone.
function DamageModel.visualLevel(wear: number): number
    local level = 0
    for index, threshold in DamageModel.LevelThresholds do
        if wear >= threshold then
            level = index
        end
    end
    return level
end

--[[
    Zone touchée et roue la plus proche d'après la direction du point de
    contact dans le repère du véhicule (x à droite, z vers l'ARRIÈRE, comme
    Roblox ; l'avant est en -z) et les demi-dimensions du véhicule.
]]
function DamageModel.locate(localX: number, localZ: number, halfWidth: number, halfLength: number): (string, number)
    local nx = localX / math.max(halfWidth, 1e-3)
    local nz = localZ / math.max(halfLength, 1e-3)
    local zone: string
    if math.abs(nz) >= math.abs(nx) then
        zone = if nz < 0 then "Front" else "Rear"
    else
        zone = if nx < 0 then "Left" else "Right"
    end
    local front = localZ < 0
    local left = localX < 0
    local corner = if front then (if left then 1 else 2) else (if left then 3 else 4)
    return zone, corner
end

local function hurt(value: number, amount: number): number
    return math.clamp(value - math.max(amount, 0), 0, 1)
end

--[[
    Applique un choc confirmé. `deltaV` en m/s (composante due au choc).
    Retourne le résultat, ou nil sous le seuil minimal.
]]
function DamageModel.applyImpact(state: DamageState, zone: string, corner: number, deltaV: number): ImpactResult?
    if not (deltaV >= DamageModel.MinImpact) or deltaV ~= deltaV then
        return nil
    end
    state.Impacts += 1
    state.Zones[zone] = math.clamp(state.Zones[zone] + (deltaV - 1.2) / 9, 0, 1)

    local mechanical = false
    if deltaV >= DamageModel.LocalImpact then
        mechanical = true
        local excess = deltaV - DamageModel.LocalImpact
        local frontCorner = corner == 1 or corner == 2
        local side = if corner == 1 or corner == 3 then -1 else 1
        if zone == "Front" then
            -- Radiateur, admission, support moteur.
            state.Engine = hurt(state.Engine, excess / 14 + 0.04)
            state.Steering = hurt(state.Steering, excess / 30)
            state.Suspension[corner] = hurt(state.Suspension[corner], excess / 24)
        elseif zone == "Rear" then
            state.Suspension[corner] = hurt(state.Suspension[corner], excess / 18 + 0.03)
        else
            -- Choc latéral : la roue la plus proche encaisse (triangle, biellette).
            state.Suspension[corner] = hurt(state.Suspension[corner], excess / 10 + 0.06)
            if frontCorner then
                state.Steering = hurt(state.Steering, excess / 22 + 0.03)
            end
        end
        if frontCorner and state.Steering < 1 then
            state.SteeringPullSide = side
        end
    end

    return {
        Zone = zone,
        Corner = corner,
        DeltaV = deltaV,
        Level = DamageModel.visualLevel(state.Zones[zone]),
        Mechanical = mechanical,
    }
end

-- Conséquences mécaniques pour la dynamique (1 = intact).
function DamageModel.condition(state: DamageState): Types.VehicleCondition
    local grip, toe = {}, {}
    for corner = 1, 4 do
        local health = state.Suspension[corner]
        -- Géométrie faussée : moins d'adhérence et roue qui pince vers l'extérieur.
        grip[corner] = 0.85 + 0.15 * health
        local side = if corner == 1 or corner == 3 then -1 else 1
        toe[corner] = (1 - health) * math.rad(1.2) * side
    end
    return {
        EnginePower = 0.35 + 0.65 * state.Engine,
        SteeringRange = 0.8 + 0.2 * state.Steering,
        SteeringPullRad = (1 - state.Steering) * math.rad(2.5) * state.SteeringPullSide,
        CornerGrip = grip,
        CornerToeRad = toe,
    }
end

-- Sérialisation en attributs (préfixe « Dmg ») : lisible par tous les clients,
-- et forme prête pour une sauvegarde ultérieure.
local CORNER_NAMES = { "FL", "FR", "RL", "RR" }

function DamageModel.toAttributes(state: DamageState): { [string]: number }
    local attributes: { [string]: number } = {
        DmgVersion = state.Version,
        DmgEngine = state.Engine,
        DmgSteering = state.Steering,
        DmgSteeringPull = state.SteeringPullSide,
        DmgImpacts = state.Impacts,
    }
    for _, zone in DamageModel.Zones do
        attributes["DmgZone" .. zone] = state.Zones[zone]
    end
    for corner, name in CORNER_NAMES do
        attributes["DmgSusp" .. name] = state.Suspension[corner]
    end
    return attributes
end

-- Relecture défensive (valeurs absentes ou invalides → intact).
function DamageModel.fromAttributes(get: (string) -> any): DamageState
    local state = DamageModel.new()
    local function read(name: string, default: number): number
        local value = get(name)
        if type(value) ~= "number" or value ~= value then
            return default
        end
        return math.clamp(value, -1, 1)
    end
    state.Engine = math.clamp(read("DmgEngine", 1), 0, 1)
    state.Steering = math.clamp(read("DmgSteering", 1), 0, 1)
    state.SteeringPullSide = math.sign(read("DmgSteeringPull", 0))
    for _, zone in DamageModel.Zones do
        state.Zones[zone] = math.clamp(read("DmgZone" .. zone, 0), 0, 1)
    end
    for corner, name in CORNER_NAMES do
        state.Suspension[corner] = math.clamp(read("DmgSusp" .. name, 1), 0, 1)
    end
    local impacts = get("DmgImpacts")
    state.Impacts = if type(impacts) == "number" and impacts >= 0 then math.floor(impacts) else 0
    return state
end

return table.freeze(DamageModel)
