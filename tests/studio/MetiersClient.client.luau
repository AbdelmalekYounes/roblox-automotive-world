-- Essais CLIENT du lot 0.9.1 (session « metiers », place de développement, 1 joueur).
-- Les HUIT métiers joués de bout en bout par un pilote automatique : la mission est
-- générée par le VRAI service, chaque étape est validée par le serveur à partir de ses
-- propres échantillons (position, vitesse, véhicule), le versement est le sien.
-- Rien n'est forcé : aucune étape sautée, aucune fin déclarée par le client.
-- Ce qui est remplacé (signalé) : la lecture clavier/manette (fournisseur d'entrées de
-- test : le pilote calcule accélérateur, frein, direction) ; le personnage est posé
-- près de la portière pour embarquer, comme lors des campagnes précédentes. La
-- simulation du véhicule, les collisions et la validation serveur sont réelles.
-- Le métier se lance par la demande normale de l'interface (StartMission) : le
-- parcours par vrais clics est vérifié par la session « ui ».

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local sessionStart = os.clock()
while ReplicatedStorage:GetAttribute("AWTestSession") == nil and os.clock() - sessionStart < 15 do
    task.wait()
end
if ReplicatedStorage:GetAttribute("AWTestSession") ~= "metiers" then
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
    print(string.format("[AW_Test] metiers %.1f s : %s", os.clock() - sessionStart, message))
end

local S = 1 / 0.28
local reportEvent = ReplicatedStorage:WaitForChild("AWTestReport", 30) :: RemoteEvent
local economyFolder = ReplicatedStorage:WaitForChild("AWEconomy", 30) :: Instance
local economy = economyFolder:WaitForChild("Request", 10) :: RemoteFunction
local economyPush = economyFolder:WaitForChild("Push", 10) :: RemoteEvent
local progression = (ReplicatedStorage:WaitForChild("AWProgression", 30) :: Instance):WaitForChild(
        "Request",
        10
    ) :: RemoteFunction
local client = player:WaitForChild("PlayerScripts"):WaitForChild("AutomotiveWorldClient")
local VehicleController = require(client:WaitForChild("Vehicles"):WaitForChild("VehicleController", 10)) :: any
local Gui = require(ReplicatedStorage:WaitForChild("AW_TestGui", 30)) :: any
local interventions = { Unflip = 0, Reboard = 0, Diagnostics = 0 }

local function call(remote: RemoteFunction, action: string, payload: any?, noRequestId: boolean?): any
    local data = payload or {}
    if not noRequestId and data.RequestId == nil then
        data.RequestId = HttpService:GenerateGUID(false)
    end
    task.wait(0.55) -- rythme d'un joueur (limiteur : 6 demandes, 2/s)
    local ok, response = pcall(function()
        return remote:InvokeServer(action, data)
    end)
    if not ok or type(response) ~= "table" then
        return { Status = "Error", Error = tostring(response) }
    end
    return response
end
local function describe(response: any): string
    return tostring(response.Status) .. (if response.Error then " / " .. tostring(response.Error) else "")
end
local function snapshot(): any
    return call(economy, "Snapshot", {}, true).Snapshot or {}
end
local function character(): Model
    return player.Character or player.CharacterAdded:Wait()
end
local function rootPart(): BasePart
    return character():WaitForChild("HumanoidRootPart", 10) :: BasePart
end
local function humanoid(): Humanoid
    return character():WaitForChild("Humanoid", 10) :: Humanoid
end

-- Fin de mission publiée par le serveur (versement, qualité, raison d'échec).
local ended: any = nil
economyPush.OnClientEvent:Connect(function(kind, data)
    if kind == "MissionEnded" then
        ended = data
        trace("fin de mission : " .. HttpService:JSONEncode(data))
    end
end)

-- ======================== Pilote automatique ========================
-- Même pilote que la campagne des courses (lot 0.9) : cap vers la cible, vitesse
-- visée, frein relâché sous 3 km/h puis frein à main (sinon marche arrière, A3).

local driving: { Model: Model?, Target: Vector3?, SpeedKmh: number, Hold: boolean, Launch: boolean? } =
    { Model = nil, Target = nil, SpeedKmh = 0, Hold = true, Launch = nil }

local function speedKmh(model: Model?): number
    local body = model and model.PrimaryPart
    return if body then body.AssemblyLinearVelocity.Magnitude / S * 3.6 else 0
end

-- Lot 0.9.1 : détection d'obstacle par lancers de rayons (mâts des portiques de course,
-- bâtiments, véhicules garés) et dégagement en marche arrière si le véhicule reste bloqué.
-- C'est le PILOTE qui évite les obstacles ; la physique du véhicule n'est pas touchée.
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local avoid = { Side = 0, Until = 0, Reverse = 0, StuckSince = nil :: number? }
-- Trois rayons par direction (centre et coins avant, à 0,25 m et 0,8 m du sol) : les
-- obstacles bas et étroits (bordures, poteaux) passaient sous un rayon unique
-- (tâche 20261103-213328 : chocs répétés, trains avant endommagés).
local function obstacle(body: BasePart, angleDeg: number, lengthM: number): number?
    local look = Vector3.new(body.CFrame.LookVector.X, 0, body.CFrame.LookVector.Z).Unit
    local right = Vector3.new(-look.Z, 0, look.X)
    local dir = CFrame.Angles(0, -math.rad(angleDeg), 0):VectorToWorldSpace(look)
    local nearest: number? = nil
    for _, lateral in { 0, -0.9, 0.9 } do
        for _, height in { -0.25, 0.3 } do
            local origin = body.Position + Vector3.new(0, height * S, 0) + look * 2 * S + right * lateral * S
            local hit = Workspace:Raycast(origin, dir * lengthM * S, rayParams)
            if hit and hit.Instance.CanCollide and hit.Normal.Y < 0.6 then
                local d = hit.Distance / S
                nearest = if nearest then math.min(nearest, d) else d
            end
        end
    end
    return nearest
end

local function autopilot(): any
    local model = driving.Model
    local body = model and model.PrimaryPart
    if body == nil or driving.Hold or driving.Target == nil then
        local moving = model ~= nil and speedKmh(model) > 3
        avoid.StuckSince = nil
        return { Throttle = 0, Brake = if moving then 1 else 0, Steer = 0, Handbrake = not moving, Clutch = 0 }
    end
    local now = os.clock()
    rayParams.FilterDescendantsInstances = { model :: Model, character() }
    -- Bloqué (vitesse nulle 3 s alors qu'on avance) : 2 s de marche arrière braquée.
    if now < avoid.Reverse then
        return { Throttle = 0, Brake = 1, Steer = -avoid.Side, Handbrake = false, Clutch = 0 }
    end
    if not driving.Launch and speedKmh(model) < 1.5 then
        avoid.StuckSince = avoid.StuckSince or now
        if now - (avoid.StuckSince :: number) > 3 then
            avoid.StuckSince = nil
            avoid.Side = if avoid.Side == 0 then 1 else avoid.Side
            avoid.Reverse = now + 2
            avoid.Until = now + 4
            trace("pilote : blocage, dégagement en marche arrière")
        end
    else
        avoid.StuckSince = nil
    end
    local target = driving.Target :: Vector3
    local forward = Vector3.new(body.CFrame.LookVector.X, 0, body.CFrame.LookVector.Z).Unit
    local offset = Vector3.new(target.X - body.Position.X, 0, target.Z - body.Position.Z)
    if offset.Magnitude < 1 then
        return { Throttle = 0, Brake = 0, Steer = 0, Handbrake = true, Clutch = 0 }
    end
    local direction = offset.Unit
    local cross = forward:Cross(direction).Y
    local angle = math.acos(math.clamp(forward:Dot(direction), -1, 1))
    local v = speedKmh(model)
    local steer = math.clamp(-math.sign(cross) * angle / 0.6 / (1 + v / 45), -1, 1)
    local wanted = driving.SpeedKmh * math.clamp(1 - angle / math.pi * 1.6, 0.35, 1)
    local distanceM = offset.Magnitude / S
    if not driving.Launch and distanceM < 25 then
        wanted = math.min(wanted, math.max(6, distanceM * 1.2))
    end
    if driving.Launch then
        return { Throttle = 1, Brake = 0, Steer = steer, Handbrake = false, Clutch = 0 }
    end
    -- Obstacle devant (moins de 14 m, et plus près que la cible) : contournement du côté libre.
    local ahead = obstacle(body, 0, 14)
    if ahead and ahead < distanceM then
        local left, right = obstacle(body, -35, 12), obstacle(body, 35, 12)
        local side = if left == nil and right ~= nil
            then -1
            elseif right == nil and left ~= nil then 1
            elseif avoid.Side ~= 0 then avoid.Side
            else (if cross < 0 then 1 else -1)
        avoid.Side = side
        avoid.Until = now + 1.2
        steer = side
        wanted = math.min(wanted, 12)
    elseif now < avoid.Until then
        steer = math.clamp(steer + avoid.Side * 0.6, -1, 1)
    else
        avoid.Side = 0
    end
    local throttle = math.clamp((wanted - v) / 12, 0, 1)
    local brake = if v > wanted + 8 then 0.6 else 0
    return { Throttle = throttle, Brake = brake, Steer = steer, Handbrake = false, Clutch = 0 }
end

local function meters(point: any): Vector3
    return Vector3.new(point.X * S, 0, point.Z * S)
end
local function flatDistanceM(point: any): number
    local body = driving.Model and (driving.Model :: Model).PrimaryPart
    if body == nil then
        return math.huge
    end
    return Vector3.new(body.Position.X / S - point.X, 0, body.Position.Z / S - point.Z).Magnitude
end

local function stopHere()
    driving.Launch = nil
    driving.Hold = true
    waitFor(function()
        return speedKmh(driving.Model) < 1
    end, 12)
end

local board: (Model) -> boolean

-- Véhicule immobile malgré les commandes : relevé de diagnostic (une fois), puis les
-- gestes d'un joueur, comptés dans le rapport : remise sur roues (R), puis descendre et
-- remonter (relance la simulation locale du conducteur).
local function unstick(stuckS: number, state: { [string]: boolean })
    local model = driving.Model :: Model
    local body = model.PrimaryPart :: BasePart
    if stuckS > 12 and not state.Diag then
        state.Diag = true
        interventions.Diagnostics += 1
        local ok, controller = pcall(VehicleController.getTestSnapshot)
        local below = Workspace:Raycast(body.Position, Vector3.new(0, -12, 0), rayParams)
        trace("diagnostic d'immobilisation : " .. HttpService:JSONEncode({
            Snapshot = if ok then controller else tostring(controller),
            Anchored = body.Anchored,
            Up = body.CFrame.UpVector.Y,
            Position = { body.Position.X / S, body.Position.Y / S, body.Position.Z / S },
            Below = if below then below.Instance:GetFullName() else "rien",
            Cargo = model:FindFirstChild("ChargementMission") ~= nil,
        }))
        Gui.shot("metiers_immobilise_" .. math.floor(body.Position.X / S) .. "_" .. math.floor(body.Position.Z / S), {})
    end
    if stuckS > 22 and not state.Unflip then
        state.Unflip = true
        interventions.Unflip += 1
        VehicleController.invokeActionForTest("AWVehicleUnflip")
    end
    if stuckS > 35 and not state.Reboard then
        state.Reboard = true
        interventions.Reboard += 1
        local target, kmh = driving.Target, driving.SpeedKmh
        VehicleController.setTestInputProvider(nil)
        VehicleController.invokeActionForTest("AWVehicleExit")
        waitFor(function()
            return humanoid().SeatPart == nil
        end, 5)
        task.wait(1)
        board(model)
        driving.Target, driving.SpeedKmh, driving.Hold = target, kmh, false
    end
end

-- Conduit jusqu'à un point (m) puis s'arrête. Vrai si atteint dans le délai.
-- `acceptM` : distance suffisante si le véhicule est bloqué (rayon réel de l'étape).
local function driveTo(
    point: any,
    kmh: number,
    radiusM: number,
    timeout: number,
    keepRolling: boolean?,
    acceptM: number?
): boolean
    if driving.Model == nil then
        return false
    end
    driving.Target = meters(point)
    driving.SpeedKmh = kmh
    driving.Hold = false
    local lastTrace = os.clock()
    local stillSince: number? = nil
    local unstickState = {}
    local reached = waitFor(function()
        if speedKmh(driving.Model) < 2 then
            stillSince = stillSince or os.clock()
            local still = os.clock() - (stillSince :: number)
            -- Bloqué dans le rayon de l'étape : on s'arrête là, comme un joueur.
            if acceptM and flatDistanceM(point) < acceptM and still > 2 then
                return true
            end
            unstick(still, unstickState)
        else
            stillSince = nil
        end
        if os.clock() - lastTrace > 5 then
            lastTrace = os.clock()
            local body = (driving.Model :: Model).PrimaryPart
            if body then
                trace(
                    string.format(
                        "vers (%.0f, %.0f) : position (%.0f, %.0f), %.0f km/h, reste %.0f m",
                        point.X,
                        point.Z,
                        body.Position.X / S,
                        body.Position.Z / S,
                        speedKmh(driving.Model),
                        flatDistanceM(point)
                    )
                )
            end
        end
        return flatDistanceM(point) < radiusM
    end, timeout)
    if not keepRolling then
        stopHere()
    end
    return reached
end

local function seatedIn(model: Model): boolean
    local seat = humanoid().SeatPart
    return seat ~= nil and seat.Name == "DriverSeat" and seat:IsDescendantOf(model)
end

-- Embarquement par l'invite (activée par script, comme lors des campagnes 0.9).
function board(model: Model): boolean
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
        if waitFor(function()
            return seatedIn(model)
        end, 5) then
            driving.Model = model
            driving.Hold = true
            VehicleController.setTestInputProvider(autopilot)
            return true
        end
    end
    return false
end

local function leave(): boolean
    stopHere()
    VehicleController.setTestInputProvider(nil)
    VehicleController.invokeActionForTest("AWVehicleExit")
    local out = waitFor(function()
        return humanoid().SeatPart == nil
    end, 5)
    driving.Model = nil
    task.wait(0.8)
    return out
end

local function findVehicle(vehicleId: string): Model?
    for _, item in Workspace:GetDescendants() do
        if item:IsA("Model") and item:GetAttribute("PersonalVehicleId") == vehicleId then
            return item
        end
    end
    return nil
end

-- ======================== Étapes de mission ========================

-- Nature d'une étape d'après son libellé (celui que voit le joueur) : rayon et
-- maintien sont ceux du générateur (MissionGenerator, place de développement).
local function stepKind(label: string): (string, number, number, number?)
    if label == "Intervenir à pied" then
        return "OnFoot", 8, 6, nil
    elseif label == "0 à 100 km/h" then
        return "Accel", 0, 0, nil
    elseif label == "Freinage depuis 90 km/h" then
        return "Brake", 0, 0, nil
    elseif string.sub(label, 1, 5) == "Porte" then
        return "Pass", 4, 0, nil
    elseif label == "Entrée du secteur" or string.sub(label, 1, 18) == "Point d'exploratio" then
        return "Pass", 12, 0, nil
    elseif label == "Stationnement final" then
        return "Park", 1.5, 2, 0
    elseif label == "Garer le véhicule confié" then
        return "Park", 4, 3, nil
    elseif label == "Rejoindre le véhicule en panne" then
        return "Stop", 18, 2, nil
    elseif label == "Se placer au départ" then
        return "Stop", 8, 2, nil
    end
    return "Stop", 10, 3, nil
end

-- Lecture refusée (limiteur) : dernier état connu, jamais « mission terminée ».
local lastMission: any = nil
local function mission(): any
    local response = call(economy, "Snapshot", {}, true)
    if response.Snapshot == nil then
        return lastMission
    end
    lastMission = response.Snapshot.Mission
    return lastMission
end

local function stepChanged(index: number, timeout: number): boolean
    return waitFor(function()
        local m = mission()
        return m == nil or m.StepIndex ~= index or ended ~= nil
    end, timeout)
end

-- Exécute l'étape en cours ; renvoie une description de ce qui a été fait.
local function runStep(m: any, job: string): string
    local kind, radius, hold, heading = stepKind(m.Label)
    local point = m.Point
    local index = m.StepIndex
    trace(string.format("%s étape %d/%d « %s » (%s)", job, index, m.Steps, m.Label, kind))
    if kind == "Stop" then
        -- Panne : arrêt à distance de la maquette (ancrée sur le point).
        local within = if m.Label == "Rejoindre le véhicule en panne" then 9 else radius * 0.45
        driveTo(point, 45, within, 150, nil, radius * 0.9)
        stepChanged(index, hold + 6)
    elseif kind == "Pass" then
        local slow = job == "Precision"
        driveTo(point, if slow then 18 else 40, radius * 0.45, 150, true)
        stepChanged(index, 4)
        if slow then
            driving.Hold = true
        end
    elseif kind == "Park" then
        if heading then
            -- Approche alignée sur le cap demandé (0 = nord, -z) depuis 18 m en arrière.
            local back = { X = point.X - math.sin(heading) * 18, Z = point.Z + math.cos(heading) * 18 }
            driveTo(back, 18, 2.5, 120)
        end
        if not heading and flatDistanceM(point) > 15 then
            -- Approche rapide jusqu'à 12 m, puis manœuvre lente (délai de la mission).
            driveTo(point, 40, 12, 120, true)
        end
        for attempt = 1, 3 do
            driveTo(point, 8, radius * 0.4, 60)
            if stepChanged(index, hold + 4) then
                break
            end
            trace(string.format("stationnement : essai %d, écart %.1f m", attempt, flatDistanceM(point)))
            if heading then
                local back = { X = point.X - math.sin(heading) * 18, Z = point.Z + math.cos(heading) * 18 }
                driveTo(back, 12, 2.5, 60)
            end
        end
    elseif kind == "OnFoot" then
        local model = driving.Model :: Model
        leave()
        local hum = humanoid()
        hum:MoveTo(meters(point) + Vector3.new(6, 0, 0))
        hum.MoveToFinished:Wait()
        stepChanged(index, hold + 8)
        board(model)
    elseif kind == "Accel" then
        stopHere()
        local body = (driving.Model :: Model).PrimaryPart :: BasePart
        local look = Vector3.new(body.CFrame.LookVector.X, 0, body.CFrame.LookVector.Z).Unit
        driving.Target = body.Position + look * 1000 * S
        driving.Hold = false
        driving.Launch = true
        waitFor(function()
            return speedKmh(driving.Model) >= 101
        end, 25)
        stepChanged(index, 3)
    elseif kind == "Brake" then
        driving.Launch = true
        driving.Hold = false
        waitFor(function()
            return speedKmh(driving.Model) >= 92
        end, 15)
        stopHere()
        stepChanged(index, 4)
    end
    return kind
end

-- ======================== Déroulé ========================

local function main()
    waitFor(function()
        local snap = snapshot()
        return snap.State == "Active" and snap.Wallet ~= nil
    end, 40)
    character():WaitForChild("HumanoidRootPart", 20)
    task.wait(2)
    local zone = Workspace:WaitForChild("AutomotiveTestZone", 20) :: Instance
    local entrance = zone:WaitForChild("EntreeProprieteEssai", 10) :: BasePart

    -- Véhicule personnel sorti de la propriété (demandes normales du garage).
    local snap = snapshot()
    local ownId: string? = nil
    for _, vehicle in snap.Vehicles or {} do
        if vehicle.Name == "Prototype d'essai P-01" then
            ownId = vehicle.Id
        end
    end
    local propertyId = nil
    for _, property in snap.Properties or {} do
        propertyId = propertyId or property.Id
    end
    rootPart().CFrame = CFrame.new(entrance.Position + Vector3.new(0, 3, 0))
    task.wait(1.2)
    local enter = call(progression, "Enter", { OwnerUserId = player.UserId, PropertyId = propertyId })
    local out = call(progression, "TakeOut", { VehicleId = ownId })
    record(
        "metiers.vehicule_personnel_sorti",
        out.Status == "Confirmed" or out.Status == "Pending",
        describe(enter) .. " / " .. describe(out) .. " " .. tostring(ownId)
    )
    local own: Model? = nil
    waitFor(function()
        own = if ownId then findVehicle(ownId) else nil
        return own ~= nil
    end, 10)
    if own == nil then
        record("metiers.vehicule_personnel_present", false, tostring(ownId))
        return
    end
    -- Sortie de la propriété si l'entrée y a placé le joueur.
    call(progression, "Exit", {})
    task.wait(1)

    local jobs = {
        { Id = "Delivery", Rule = "Professional" },
        { Id = "Taxi", Rule = "Professional" },
        { Id = "SpecialParts", Rule = "Own" },
        { Id = "Assistance", Rule = "Own" },
        { Id = "Precision", Rule = "Own" },
        { Id = "Exploration", Rule = "Own" },
        { Id = "Convoy", Rule = "Provided" },
        { Id = "Testing", Rule = "Provided" },
    }
    local completed = 0
    for _, job in jobs do
        local started = os.clock()
        ended = nil
        local before = snapshot().Wallet.Balance
        local vehicleUsed = "?"
        if job.Rule == "Provided" then
            if humanoid().SeatPart then
                leave()
            end
            -- Assez loin du véhicule personnel pour laisser la place au véhicule fourni.
            rootPart().CFrame = CFrame.new(entrance.Position + Vector3.new(60, 3, 60))
            task.wait(1.2)
        elseif not (own and seatedIn(own :: Model)) then
            board(own :: Model)
        end
        local start = call(economy, "StartMission", { Job = job.Id })
        if start.Status ~= "Ok" and start.Status ~= "Confirmed" then
            record("metiers." .. job.Id .. ".demarrage", false, describe(start))
            task.wait(11)
            continue
        end
        local result = start.Result or start
        trace(job.Id .. " démarré : " .. HttpService:JSONEncode(result))
        if job.Rule == "Provided" then
            local provided: Model? = nil
            waitFor(function()
                provided = findVehicle("PRO-" .. tostring(result.MissionId))
                return provided ~= nil
            end, 8)
            if provided == nil or not board(provided :: Model) then
                record("metiers." .. job.Id .. ".vehicule_fourni", false, tostring(result.MissionId))
                call(economy, "AbandonMission", {})
                task.wait(11)
                continue
            end
            vehicleUsed = "fourni " .. (provided :: Model).Name
        else
            vehicleUsed = "personnel " .. (own :: Model).Name
        end
        local first = mission()
        local kinds = {}
        local deadline = os.clock() + (if first then first.TimeLeft + 20 else 60)
        while ended == nil and os.clock() < deadline do
            local m = mission()
            if m == nil then
                waitFor(function()
                    return ended ~= nil
                end, 6)
                break
            end
            table.insert(kinds, runStep(m, job.Id))
        end
        waitFor(function()
            return ended ~= nil
        end, 10)
        local data = ended or {}
        local after = snapshot().Wallet.Balance
        local ok = data.Completed == true and (data.Credits or 0) > 0 and after - before == data.Credits
        if ok then
            completed += 1
        end
        record(
            "metiers." .. job.Id .. ".termine_valide_par_le_serveur",
            ok,
            string.format(
                "terminé %s, raison %s, qualité %.2f, crédits %s (solde %+d), réputation %s, %s, %.0f s, étapes %s",
                tostring(data.Completed),
                tostring(data.Reason),
                data.Quality or 0,
                tostring(data.Credits),
                after - before,
                tostring(data.Reputation),
                vehicleUsed,
                os.clock() - started,
                table.concat(kinds, ",")
            )
        )
        measures["duree_" .. job.Id .. "_s"] = math.floor(os.clock() - started)
        if job.Rule == "Provided" then
            leave()
        end
        -- Délai entre deux démarrages (START_COOLDOWN_S = 10 s).
        task.wait(11)
    end
    record("metiers.bilan_huit_metiers", completed == 8, completed .. " / 8 terminés et payés")
    record("metiers.info_interventions_du_pilote", true, HttpService:JSONEncode(interventions))
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
    record("metiers.execution", false, err)
end
VehicleController.setTestInputProvider(nil)
reportEvent:FireServer({ vehicle = "metiers", steps = steps, measures = measures })
