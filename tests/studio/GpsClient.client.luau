-- Essais CLIENT du lot 0.9.1 (session « gps », place MONDE OUVERT, 1 joueur).
-- Conduite réelle (aucune téléportation pendant les trajets) à travers les sept zones,
-- guidée par le VRAI GPS du jeu (GPSController) : le pilote automatique suit les points
-- de l'itinéraire que le GPS a calculé, vérifie le guidage (manœuvre suivante, distance
-- restante), sort volontairement de l'itinéraire pour provoquer un recalcul, et attend
-- l'arrivée constatée par le GPS.
-- Ce qui est instrumenté (signalé) : la lecture clavier/manette est remplacée par le
-- pilote (fournisseur d'entrées de test) ; la destination est posée par la fonction du
-- GPS (le choix par vrais clics sur la carte est vérifié par la session « ui ») ; le
-- véhicule est posé une seule fois, au départ, sur une rue proche du point d'apparition.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local sessionStart = os.clock()
while ReplicatedStorage:GetAttribute("AWTestSession") == nil and os.clock() - sessionStart < 15 do
    task.wait()
end
if ReplicatedStorage:GetAttribute("AWTestSession") ~= "gps" then
    return
end

local steps = {}
local measures = {}
local function record(name: string, ok: boolean, detail: any)
    table.insert(steps, { name = name, ok = ok, detail = if detail ~= nil then tostring(detail) else nil })
end
local function waitFor(predicate: () -> boolean, timeout: number): boolean
    local start = os.clock()
    while os.clock() - start < timeout do
        if predicate() then
            return true
        end
        task.wait(0.1)
    end
    return predicate()
end
local function trace(message: string)
    print(string.format("[AW_Test] gps %.1f s : %s", os.clock() - sessionStart, message))
end

local S = 1 / 0.28
local reportEvent = ReplicatedStorage:WaitForChild("AWTestReport", 30) :: RemoteEvent
local signalEvent = ReplicatedStorage:WaitForChild("AWTestSignal", 30) :: RemoteEvent
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldLayout = require(Shared:WaitForChild("World"):WaitForChild("WorldLayout")) :: any
local RouteGuide = require(Shared:WaitForChild("Navigation"):WaitForChild("RouteGuide")) :: any
local client = player:WaitForChild("PlayerScripts"):WaitForChild("AutomotiveWorldClient")
local VehicleController = require(client:WaitForChild("Vehicles"):WaitForChild("VehicleController", 10)) :: any
local GPSController = require(client:WaitForChild("UI"):WaitForChild("GPSController")) :: any
local Gui = require(ReplicatedStorage:WaitForChild("AW_TestGui", 30)) :: any

local function character(): Model
    return player.Character or player.CharacterAdded:Wait()
end
local function rootPart(): BasePart
    return character():WaitForChild("HumanoidRootPart", 10) :: BasePart
end

-- ======================== Pilote : suivi d'itinéraire ========================

local driving: { Model: Model?, Target: Vector3?, SpeedKmh: number, Hold: boolean, Reverse: boolean? } =
    { Model = nil, Target = nil, SpeedKmh = 0, Hold = true, Reverse = nil }

local function speedKmh(): number
    local body = driving.Model and (driving.Model :: Model).PrimaryPart
    return if body then body.AssemblyLinearVelocity.Magnitude / S * 3.6 else 0
end

-- Obstacle devant (trafic, véhicule arrêté, mobilier) : le pilote ralentit ou s'arrête
-- derrière ; un blocage prolongé déclenche le dégagement (boucle de trajet).
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function obstacleAhead(body: BasePart, lengthM: number): number?
    local look = Vector3.new(body.CFrame.LookVector.X, 0, body.CFrame.LookVector.Z).Unit
    local origin = body.Position + Vector3.new(0, 0.6 * S, 0) + look * 2 * S
    local hit = Workspace:Raycast(origin, look * lengthM * S, rayParams)
    if hit and hit.Instance.CanCollide and hit.Normal.Y < 0.6 then
        return hit.Distance / S
    end
    return nil
end

local function autopilot(): any
    local model = driving.Model
    local body = model and model.PrimaryPart
    if body == nil or driving.Hold or driving.Target == nil then
        local moving = speedKmh() > 3
        return { Throttle = 0, Brake = if moving then 1 else 0, Steer = 0, Handbrake = not moving, Clutch = 0 }
    end
    if driving.Reverse then
        -- Dégagement : frein maintenu à l'arrêt = marche arrière (boîte automatique, A3).
        return { Throttle = 0, Brake = 1, Steer = 0.6, Handbrake = false, Clutch = 0 }
    end
    local target = driving.Target :: Vector3
    local forward = Vector3.new(body.CFrame.LookVector.X, 0, body.CFrame.LookVector.Z).Unit
    local offset = Vector3.new(target.X - body.Position.X, 0, target.Z - body.Position.Z)
    if offset.Magnitude < 1 then
        return { Throttle = 0, Brake = 0, Steer = 0, Handbrake = false, Clutch = 0 }
    end
    local direction = offset.Unit
    local cross = forward:Cross(direction).Y
    local angle = math.acos(math.clamp(forward:Dot(direction), -1, 1))
    local v = speedKmh()
    local steer = math.clamp(-math.sign(cross) * angle / 0.5 / (1 + v / 60), -1, 1)
    local wanted = driving.SpeedKmh * math.clamp(1 - angle / math.pi * 1.8, 0.25, 1)
    rayParams.FilterDescendantsInstances = { model :: Model, character() }
    local ahead = obstacleAhead(body, math.clamp(v * 0.45, 10, 35))
    if ahead then
        wanted = math.min(wanted, math.max(0, (ahead - 5) * 2.2))
    end
    local throttle = math.clamp((wanted - v) / 10, 0, 1)
    local brake = if v > wanted + 6 then math.clamp((v - wanted) / 25, 0.3, 1) else 0
    return { Throttle = throttle, Brake = brake, Steer = steer, Handbrake = false, Clutch = 0 }
end

-- Point de l'itinéraire à la distance « along » (m) depuis son départ.
local function pointAt(plan: any, along: number): (number, number)
    local points, alongs = plan.Points, plan.Along
    if along <= 0 then
        return points[1].X, points[1].Z
    end
    for i = 2, #points do
        if alongs[i] >= along then
            local span = alongs[i] - alongs[i - 1]
            local t = if span > 0 then (along - alongs[i - 1]) / span else 0
            return points[i - 1].X + (points[i].X - points[i - 1].X) * t,
                points[i - 1].Z + (points[i].Z - points[i - 1].Z) * t
        end
    end
    return points[#points].X, points[#points].Z
end

-- Vitesse de référence de l'itinéraire autour d'un point (temps prévu par le GPS).
local function plannedSpeedKmh(plan: any, along: number): number
    for i = 2, #plan.Points do
        if plan.Along[i] >= along then
            local dt = plan.Time[i] - plan.Time[i - 1]
            local ds = plan.Along[i] - plan.Along[i - 1]
            return if dt > 0 then ds / dt * 3.6 else 50
        end
    end
    return 50
end

-- Changement de cap maximal (degrés) sur la portion [along, along + span].
local function turnAhead(plan: any, along: number, span: number): number
    local function headingAt(a: number): number
        local x1, z1 = pointAt(plan, a)
        local x2, z2 = pointAt(plan, a + 6)
        return math.atan2(x2 - x1, -(z2 - z1))
    end
    local first = headingAt(along)
    local worst = 0
    for a = along + 8, along + span, 8 do
        local d = math.deg(((headingAt(a) - first + math.pi) % (2 * math.pi)) - math.pi)
        worst = math.max(worst, math.abs(d))
    end
    return worst
end

local function board(model: Model): boolean
    local body = model.PrimaryPart
    local door = body and body:FindFirstChild("DriverDoor")
    local prompt = door and door:FindFirstChild("EnterPrompt") :: ProximityPrompt?
    if prompt == nil then
        return false
    end
    for attempt = 1, 4 do
        rootPart().CFrame = CFrame.new((door :: Attachment).WorldPosition + Vector3.new(0, 2, 0))
        task.wait(if attempt == 1 then 0.8 else 1.5)
        prompt:InputHoldBegin()
        task.wait(prompt.HoldDuration + 0.3)
        prompt:InputHoldEnd()
        if
            waitFor(function()
                return model:GetAttribute("DriverUserId") == player.UserId
            end, 5)
        then
            driving.Model = model
            VehicleController.setTestInputProvider(autopilot)
            return true
        end
    end
    return false
end

-- ======================== Destinations : une par zone ========================

local layout = WorldLayout.get()
local ZONES = { "Metropole", "Banlieues", "Docks", "Littoral", "Campagne", "Montagnes", "Motorsport" }
local function zoneTarget(zone: string): { X: number, Z: number }?
    -- Nœud de route ouverte (profil « Road ») le plus proche du centre des tronçons de la zone.
    local sumX, sumZ, n = 0, 0, 0
    local nodes = {}
    for _, edge in layout.Edges do
        if edge.Zone == zone and RouteGuide.allowsClass("Road", edge.Class) and edge.Class ~= "Autoroute" then
            local mid = WorldLayout.sampleAt(edge.Polyline, 0.5)
            sumX += mid.X
            sumZ += mid.Z
            n += 1
            table.insert(nodes, mid)
        end
    end
    if n == 0 then
        return nil
    end
    local cx, cz = sumX / n, sumZ / n
    local best, bestD = nil, math.huge
    for _, p in nodes do
        local d = (p.X - cx) ^ 2 + (p.Z - cz) ^ 2
        if d < bestD then
            best, bestD = p, d
        end
    end
    return if best then { X = best.X, Z = best.Z } else nil
end

local zonesSeen: { [string]: number } = {}
local maxSpeed = 0
local function sampleZone()
    local body = driving.Model and (driving.Model :: Model).PrimaryPart
    if body then
        local zone = WorldLayout.zoneOf(body.Position.X / S, body.Position.Z / S)
        zonesSeen[zone] = (zonesSeen[zone] or 0) + 1
        maxSpeed = math.max(maxSpeed, speedKmh())
    end
end

-- Un trajet jusqu'à l'arrivée constatée par le GPS. `detour` : sortie volontaire.
local function leg(index: number, zone: string, target: { X: number, Z: number }, detour: boolean): boolean
    local name = string.format("gps.trajet_%d_%s", index, zone)
    GPSController.setDestination(target.X, target.Z, "Essai " .. zone, "Player")
    local planned = waitFor(function()
        return GPSController.state().Status == "Guiding" and GPSController.state().Plan ~= nil
    end, 20)
    local plan = GPSController.state().Plan
    if not planned or plan == nil then
        record(name .. ".itineraire", false, GPSController.state().Status)
        return false
    end
    local fast = 0
    for i = 2, #plan.Points do
        local dt = plan.Time[i] - plan.Time[i - 1]
        if dt > 0 and (plan.Along[i] - plan.Along[i - 1]) / dt >= 25 then
            fast += plan.Along[i] - plan.Along[i - 1]
        end
    end
    record(
        name .. ".itineraire",
        true,
        string.format(
            "%.0f m, %.0f s prévues, %d manœuvre(s), %.0f m à ≥ 90 km/h",
            plan.LengthM,
            plan.TimeS,
            #plan.Maneuvers,
            fast
        )
    )
    measures[name .. "_voie_rapide_m"] = math.floor(fast)
    if index == 1 then
        Gui.shot("gps_itineraire_" .. zone, { zone = zone })
    end
    local started = os.clock()
    local deadline = started + plan.TimeS * 3 + 120
    local hint = nil
    local detourDone = not detour
    local recalcSeen = false
    local planBefore = nil
    local stuckSince = nil
    local nextChecked = false
    local lastSample = 0
    local lastShot = 0
    while os.clock() < deadline do
        local state = GPSController.state()
        if state.Status == "Arrived" then
            break
        end
        local current = state.Plan
        local body = (driving.Model :: Model).PrimaryPart :: BasePart
        local x, z = body.Position.X / S, body.Position.Z / S
        if current == nil then
            driving.Hold = true
            task.wait(0.2)
            continue
        end
        if current ~= plan then
            plan = current
            hint = nil
            if planBefore then
                recalcSeen = true
            end
        end
        local progress = RouteGuide.track(plan, x, z, hint)
        hint = progress.Hint
        if not nextChecked and state.Progress and state.Progress.Next then
            nextChecked = true
            record(
                name .. ".guidage_manoeuvre",
                true,
                string.format(
                    "%s dans %.0f m (%s), reste %.0f m",
                    tostring(state.Progress.Next.Kind),
                    state.Progress.ToNextM,
                    tostring(state.Progress.Next.Road),
                    state.Progress.RemainingM
                )
            )
        end
        -- Sortie volontaire : à 40 % du trajet, cap perpendiculaire pendant ≈ 8 s.
        if not detourDone and progress.AlongM > plan.LengthM * 0.4 then
            detourDone = true
            planBefore = plan
            local look = body.CFrame.LookVector
            local side = Vector3.new(-look.Z, 0, look.X).Unit
            driving.Target = body.Position + side * 120 * S + look * 40 * S
            driving.SpeedKmh = 35
            driving.Hold = false
            local off = os.clock()
            local maxOff = 0
            while os.clock() - off < 12 do
                local p = RouteGuide.track(planBefore, body.Position.X / S, body.Position.Z / S, nil)
                maxOff = math.max(maxOff, p.OffRouteM)
                if maxOff > RouteGuide.OffRouteM + 10 and os.clock() - off > 6 then
                    break
                end
                task.wait(0.1)
            end
            local recomputed = waitFor(function()
                return GPSController.state().Plan ~= nil and GPSController.state().Plan ~= planBefore
            end, 12)
            record(
                name .. ".recalcul_apres_sortie",
                recomputed,
                string.format(
                    "écart maximal %.0f m (seuil %d m pendant %d s)",
                    maxOff,
                    RouteGuide.OffRouteM,
                    RouteGuide.OffRouteHoldS
                )
            )
            Gui.shot("gps_recalcul_" .. zone, { zone = zone, ecart = math.floor(maxOff) })
            continue
        end
        local v = speedKmh()
        local look = math.clamp(v * 0.3, 10, 32)
        local tx, tz = pointAt(plan, progress.AlongM + look)
        local turn = turnAhead(plan, progress.AlongM, math.clamp(v * 0.9, 30, 90))
        local cap = math.min(plannedSpeedKmh(plan, progress.AlongM) * 0.85, 110)
        if turn > 60 then
            cap = math.min(cap, 22)
        elseif turn > 35 then
            cap = math.min(cap, 32)
        elseif turn > 18 then
            cap = math.min(cap, 50)
        end
        if progress.OffRouteM > 12 then
            cap = math.min(cap, 25)
        end
        driving.Target = Vector3.new(tx * S, body.Position.Y, tz * S)
        driving.SpeedKmh = cap
        driving.Hold = false
        -- Blocage (obstacle, trafic) : marche arrière 2,5 s puis reprise.
        if v < 2 then
            stuckSince = stuckSince or os.clock()
            if os.clock() - (stuckSince :: number) > 6 then
                trace(string.format("%s : blocage en (%.0f, %.0f), dégagement", name, x, z))
                measures[name .. "_degagements"] = (measures[name .. "_degagements"] or 0) + 1
                if body.CFrame.UpVector.Y < 0.5 then
                    VehicleController.invokeActionForTest("AWVehicleUnflip")
                    task.wait(2)
                end
                driving.Reverse = true
                task.wait(2.5)
                driving.Reverse = nil
                stuckSince = nil
            end
        else
            stuckSince = nil
        end
        if os.clock() - lastSample > 1 then
            lastSample = os.clock()
            sampleZone()
        end
        if os.clock() - lastShot > 45 then
            lastShot = os.clock()
            Gui.shot(string.format("gps_%d_%s_%ds", index, zone, math.floor(os.clock() - started)), {
                zone = WorldLayout.zoneOf(x, z),
                kmh = math.floor(v),
                restant = math.floor(progress.RemainingM),
            })
        end
        task.wait(0.1)
    end
    driving.Hold = true
    local arrived = GPSController.state().Status == "Arrived"
    local body = (driving.Model :: Model).PrimaryPart :: BasePart
    local gap = math.sqrt((body.Position.X / S - target.X) ^ 2 + (body.Position.Z / S - target.Z) ^ 2)
    record(
        name .. ".arrivee_constatee_par_le_gps",
        arrived,
        string.format(
            "%.0f s, écart final %.0f m, zone d'arrivée %s, recalcul %s",
            os.clock() - started,
            gap,
            WorldLayout.zoneOf(body.Position.X / S, body.Position.Z / S),
            if detour then tostring(recalcSeen) else "—"
        )
    )
    measures[name .. "_s"] = math.floor(os.clock() - started)
    Gui.shot("gps_arrivee_" .. zone, { zone = zone, ecart = math.floor(gap) })
    return arrived
end

local function main()
    waitFor(function()
        return ReplicatedStorage:GetAttribute("AutomotiveWorldMode") == "OpenWorld"
    end, 30)
    character():WaitForChild("HumanoidRootPart", 20)
    task.wait(4)
    local mouseOk = Gui.calibrate(2)
    record("gps.info_etalonnage_captures", true, "étalonnage " .. tostring(mouseOk) .. " (captures recadrées)")
    signalEvent:FireServer("AWUI:PlaceStart")
    local placed = waitFor(function()
        return type(ReplicatedStorage:GetAttribute("AWUI_StartVehicle")) == "string"
    end, 30)
    local fleet = Workspace:WaitForChild("VehiculesEssai", 20)
    local model = placed
        and fleet
        and fleet:FindFirstChild(ReplicatedStorage:GetAttribute("AWUI_StartVehicle")) :: Model?
    record("gps.placement_initial_vehicule", model ~= nil, "véhicule posé une fois au départ (instrumenté)")
    if model == nil then
        return
    end
    task.wait(3)
    if not board(model :: Model) then
        record("gps.embarquement", false)
        return
    end
    record("gps.embarquement", true, model.Name)
    -- Ordre : plus proche voisin depuis la position de départ.
    local targets = {}
    for _, zone in ZONES do
        local target = zoneTarget(zone)
        record(
            "gps.destination_" .. zone,
            target ~= nil,
            if target then string.format("(%.0f, %.0f) m", target.X, target.Z) else "aucune route ouverte"
        )
        if target then
            table.insert(targets, { Zone = zone, Target = target })
        end
    end
    local ordered = {}
    local body = (model :: Model).PrimaryPart :: BasePart
    local cx, cz = body.Position.X / S, body.Position.Z / S
    while #targets > 0 do
        local bestIndex, bestD = 1, math.huge
        for i, item in targets do
            local d = (item.Target.X - cx) ^ 2 + (item.Target.Z - cz) ^ 2
            if d < bestD then
                bestIndex, bestD = i, d
            end
        end
        local item = table.remove(targets, bestIndex) :: any
        table.insert(ordered, item)
        cx, cz = item.Target.X, item.Target.Z
    end
    local arrivals = 0
    for index, item in ordered do
        -- Sorties volontaires sur les trajets 2 et 5 (zones ouvertes de préférence).
        if leg(index, item.Zone, item.Target, index == 2 or index == 5) then
            arrivals += 1
        end
        task.wait(1)
    end
    local seen = {}
    for zone, count in zonesSeen do
        table.insert(seen, string.format("%s %d s", zone, count))
    end
    table.sort(seen)
    local all = true
    for _, zone in ZONES do
        if zonesSeen[zone] == nil then
            all = false
        end
    end
    record("gps.sept_zones_traversees", all, table.concat(seen, ", "))
    record("gps.arrivees", arrivals == #ordered, arrivals .. " / " .. #ordered)
    measures.vitesse_max_kmh = math.floor(maxSpeed)
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
    record("gps.execution", false, err)
end
VehicleController.setTestInputProvider(nil)
for _, shot in Gui.report().shots do
    record(
        "gps.capture." .. shot.name,
        true,
        string.format("(%d, %d, %d) st, %s", shot.x, shot.y, shot.z, tostring(shot.context))
    )
end
reportEvent:FireServer({ vehicle = "gps", steps = steps, measures = measures })
