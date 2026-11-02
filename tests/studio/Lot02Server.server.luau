-- Essais SERVEUR du lot 0.2 (session « lot02 »), injectés par le pilote dans le
-- Studio de test uniquement. Ce script place les véhicules entre les étapes
-- (ce n'est jamais le jeu qui le fait), lit les états serveur (énergie, dégâts,
-- coûts) par les points d'accès réservés à Studio (ServerStorage.AWTestHooks) et
-- transmet ses contrôles à ServerSuite (dossier ServerStorage.AWTestScenario).
-- Chaque étape : placement → attributs AW02Stage/AW02Vehicle → le client
-- embarque, roule, mesure, sort → signal « AW02Done:<étape> ».

local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StudioTestService = game:GetService("StudioTestService")
local Workspace = game:GetService("Workspace")

local args = StudioTestService:GetTestArgs()
local session = if type(args) == "table" and type(args.Session) == "string" then args.Session else ""
if session ~= "lot02" then
    return
end

local channel = Instance.new("Folder")
channel.Name = "AWTestScenario"
channel:SetAttribute("Done", false)
channel.Parent = ServerStorage
ReplicatedStorage:SetAttribute("AWTestMovesVehicles", true)
ReplicatedStorage:SetAttribute("AWTestClientTimeout", 1500)

local steps = {}
local function record(name: string, ok: boolean, detail: any, knownLimitation: string?)
    table.insert(steps, {
        name = name,
        ok = ok,
        detail = if detail ~= nil then tostring(detail) else nil,
        known = if not ok then knownLimitation else nil,
    })
end

-- Journal serveur : chocs confirmés, réserves vides, corrections (aucune attendue).
local impactsLog, emptyLog, corrections = {}, {}, {}
LogService.MessageOut:Connect(function(message, messageType)
    if string.find(message, "[Dégâts] Choc confirmé", 1, true) then
        table.insert(impactsLog, message)
    elseif string.find(message, "[Énergie] Réserve vide", 1, true) then
        table.insert(emptyLog, message)
    elseif messageType == Enum.MessageType.MessageWarning and string.find(message, "Mouvement impossible", 1, true) then
        table.insert(corrections, message)
    end
end)

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

local folder = Workspace:WaitForChild("VehiculesEssai", 20)
local signal = ReplicatedStorage:WaitForChild("AWTestSignal", 20)
local hooks = ServerStorage:WaitForChild("AWTestHooks", 20) :: BindableFunction
local done = {}
signal.OnServerEvent:Connect(function(_, name)
    if type(name) == "string" and string.sub(name, 1, 9) == "AW02Done:" then
        done[string.sub(name, 10)] = true
    end
end)

local function vehicle(index: number): Model
    return folder:WaitForChild("VehiculeEssai_" .. index, 10) :: Model
end

local homes = {}
for index = 1, 9 do
    local model = vehicle(index)
    homes[model] = model:GetPivot()
end

local function place(model: Model, pivot: CFrame)
    model:PivotTo(pivot)
    local root = model.PrimaryPart :: BasePart
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end

local function restHeight(model: Model): number
    local definitionId = model:GetAttribute("DefinitionId")
    local cg = if definitionId == "proto_p03" then 0.47 elseif definitionId == "proto_p02" then 0.55 else 0.5
    return cg / 0.28 + 0.4
end

-- Pivot posé au sol (y = 0) en (x, z), cap en degrés (0 = nord, -Z).
local function ground(model: Model, x: number, z: number, headingDeg: number?): CFrame
    return CFrame.new(x, restHeight(model), z) * CFrame.Angles(0, math.rad(-(headingDeg or 0)), 0)
end

local function energy(model: Model): any
    return hooks:Invoke("GetEnergy", model)
end

local function runStage(stage: string, model: Model, pivot: CFrame?, timeout: number?): boolean
    waitFor(function()
        return model:GetAttribute("DriverUserId") == 0
    end, 15)
    if pivot then
        place(model, pivot)
    end
    task.wait(1.5)
    ReplicatedStorage:SetAttribute("AW02Vehicle", model.Name)
    ReplicatedStorage:SetAttribute("AW02Stage", stage)
    local ok = waitFor(function()
        return done[stage] == true
    end, timeout or 120)
    record("lot02.etape_" .. stage .. "_terminee", ok)
    -- Le véhicule revient à son plot (voie libre pour l'étape suivante).
    waitFor(function()
        return model:GetAttribute("DriverUserId") == 0
    end, 10)
    task.wait(0.5)
    place(model, homes[model])
    return ok
end

-- Après le contrôle « véhicules posés » de ServerSuite (4 s).
task.wait(6)

-- P0 : parc, attributs initiaux (aides désactivées, énergie publiée).
local Definitions = require(ReplicatedStorage.Shared.Vehicles.VehicleDefinitions)
local fleetOk, fleetDetail = true, {}
for index, id in Definitions.TestFleet do
    local model = vehicle(index)
    local level = model:GetAttribute("EnergyLevel")
    local definition = Definitions.get(id)
    local expected = definition.Powertrain.Energy.Capacity * definition.Powertrain.Energy.InitialFraction
    local ok = model:GetAttribute("DefinitionId") == id
        and type(level) == "number"
        and math.abs(level - expected) < 1e-6
        and model:GetAttribute("EnergyEmpty") == false
        and model:GetAttribute("AidAbs") ~= true
        and model:GetAttribute("DmgImpacts") == 0
    fleetOk = fleetOk and ok
    table.insert(
        fleetDetail,
        string.format("%d=%s %.1f", index, tostring(model:GetAttribute("DefinitionId")), level or -1)
    )
end
record("lot02.parc_et_etats_initiaux", fleetOk, table.concat(fleetDetail, " | "))

-- P1 : six boîtes sur la ligne droite (départ x = 0, z = 0, cap nord).
local gearboxVehicles = { 1, 5, 6, 7, 8, 9 }
for _, index in gearboxVehicles do
    local model = vehicle(index)
    local before = energy(model)
    runStage("boite_" .. tostring(model:GetAttribute("DefinitionId")), model, ground(model, 0, 0), 150)
    local after = energy(model)
    local withdrawn = after.TotalWithdrawn - before.TotalWithdrawn
    record(
        "lot02.energie_debitee_par_le_serveur_" .. tostring(model:GetAttribute("DefinitionId")),
        withdrawn > 0 and after.Level < before.Level and after.FloorUsed > 0,
        string.format(
            "retiré %.4f (plancher %.4f, déclaré accepté %.4f), récupéré %.4f, niveau %.3f → %.3f",
            withdrawn,
            after.FloorUsed,
            after.ClientAccepted,
            after.TotalRecovered - before.TotalRecovered,
            before.Level,
            after.Level
        )
    )
    if model:GetAttribute("DefinitionId") == "proto_p03" then
        record(
            "lot02.recuperation_validee_serveur_p03",
            after.TotalRecovered > before.TotalRecovered,
            string.format("%.4f kWh", after.TotalRecovered - before.TotalRecovered)
        )
    end
end

-- P2 : aides (état, activation, aide absente, effets) — zone mouillée au sud-ouest.
local p01, p01b, p01c, p01d = vehicle(1), vehicle(2), vehicle(3), vehicle(4)
local p02, p03 = vehicle(5), vehicle(6)
runStage("aides_etat", p03, ground(p03, -560, 280), 90)
runStage("aide_absente", p01, ground(p01, 0, 0), 60)
record(
    "lot02.aide_absente_non_activee_serveur",
    p01:GetAttribute("AidAbs") ~= true,
    tostring(p01:GetAttribute("AidAbs"))
)
runStage("abs_off", p03, ground(p03, -470, 280), 90)
runStage("abs_on", p03, ground(p03, -470, 280), 90)
runStage("tc_off", p02, ground(p02, -470, 80), 90)
runStage("tc_on", p02, ground(p02, -470, 80), 90)
runStage("esc_off", p03, ground(p03, -500, 95), 90)
runStage("esc_on", p03, ground(p03, -500, 95), 90)
runStage("freinage_sec", p03, ground(p03, 0, 0), 90)

-- P3 : maintien en pente (rampe à 10 %, milieu de la montée, cap nord).
local slope = math.atan(6 / 60)
local function onRamp(model: Model): CFrame
    return CFrame.new(300, 3, -350) * CFrame.Angles(slope, 0, 0) * CFrame.new(0, restHeight(model) - 0.2, 0)
end
runStage("pente_p01_frein_a_main", p01b, onRamp(p01b), 90)
runStage("pente_p02_frein", p02, onRamp(p02), 90)

-- P4 : bordures et bosses, sonde rayon puis sphère (même véhicule, même trajet).
p01c:SetAttribute("AWTestProbe", "Ray")
runStage("bordures_rayon", p01c, ground(p01c, 480, -10), 90)
p01c:SetAttribute("AWTestProbe", "Sphere")
runStage("bordures_sphere", p01c, ground(p01c, 480, -10), 90)
p01c:SetAttribute("AWTestProbe", nil)

-- P5 : dégâts — mur de choc à 15 puis 35 km/h, puis deux véhicules.
local function zones(model: Model): string
    return string.format(
        "AV %.2f AR %.2f G %.2f D %.2f moteur %.2f direction %.2f chocs %d",
        model:GetAttribute("DmgZoneFront") or -1,
        model:GetAttribute("DmgZoneRear") or -1,
        model:GetAttribute("DmgZoneLeft") or -1,
        model:GetAttribute("DmgZoneRight") or -1,
        model:GetAttribute("DmgEngine") or -1,
        model:GetAttribute("DmgSteering") or -1,
        model:GetAttribute("DmgImpacts") or -1
    )
end
local function visuals(model: Model): number
    local damageFolder = model:FindFirstChild("Degats")
    return if damageFolder then #damageFolder:GetChildren() else 0
end
local energyBeforeCrash = energy(p01d).Level
runStage("degats_mur_15", p01d, ground(p01d, -250, 150, 180), 90)
local afterLight = p01d:GetAttribute("DmgZoneFront") or 0
record(
    "lot02.degats_choc_modere_confirme",
    (p01d:GetAttribute("DmgImpacts") or 0) >= 1 and afterLight > 0,
    zones(p01d) .. string.format(" ; éléments visuels %d", visuals(p01d))
)
runStage("degats_mur_35", p01d, ground(p01d, -250, 130, 180), 90)
record(
    "lot02.degats_importants_et_mecaniques",
    (p01d:GetAttribute("DmgZoneFront") or 0) > afterLight and (p01d:GetAttribute("DmgEngine") or 1) < 1,
    zones(p01d) .. string.format(" ; éléments visuels %d", visuals(p01d))
)
record(
    "lot02.degats_niveau_visuel",
    visuals(p01d) >= 3,
    string.format("%d élément(s) dans le dossier Degats", visuals(p01d))
)
record("lot02.energie_inchangee_par_les_degats", math.abs(energy(p01d).Level - energyBeforeCrash) < 0.2, "niveau suivi")
local impactsBeforePair = #impactsLog
local pairTarget = p01b
place(pairTarget, ground(pairTarget, -150, 0, 90))
runStage("degats_deux_vehicules", p01c, ground(p01c, -150, 90), 90)
local pairLines = {}
for i = impactsBeforePair + 1, #impactsLog do
    table.insert(pairLines, impactsLog[i])
end
local strikerImpacts = p01c:GetAttribute("DmgImpacts") or 0
local targetImpacts = pairTarget:GetAttribute("DmgImpacts") or 0
record(
    "lot02.degats_entre_vehicules_confirmes_des_deux_cotes",
    strikerImpacts >= 1 and targetImpacts >= 1,
    string.format("percuteur %s ; percuté %s", zones(p01c), zones(pairTarget))
)
record(
    "lot02.degats_paire_sans_double_comptage",
    #pairLines <= 2,
    #pairLines .. " choc(s) journalisé(s) : " .. table.concat(pairLines, " || ")
)
place(pairTarget, homes[pairTarget])

-- P6 : panne d'énergie (réserve presque vide fixée par le point d'accès de test).
hooks:Invoke("SetEnergy", p01, 0.03)
runStage("panne_seche_p01", p01, ground(p01, 0, 0), 120)
local p01Energy = energy(p01)
record(
    "lot02.panne_seche_verrouillee_serveur",
    p01Energy.Empty and p01Energy.Level == 0 and p01:GetAttribute("EnergyEmpty") == true,
    string.format("niveau %.4f, vide %s", p01Energy.Level, tostring(p01Energy.Empty))
)
hooks:Invoke("SetEnergy", p03, 0.02)
runStage("batterie_vide_p03", p03, ground(p03, 0, 0), 120)
local p03Energy = energy(p03)
record(
    "lot02.batterie_vide_sans_recharge",
    p03Energy.Empty and p03Energy.Level == 0,
    string.format("niveau %.4f, récupéré au total %.4f", p03Energy.Level, p03Energy.TotalRecovered)
)
record("lot02.journal_reserves_vides", #emptyLog >= 2, #emptyLog .. " : " .. table.concat(emptyLog, " || "))

-- P7 : caméras pendant la conduite (configuration CVT, ligne droite).
local cvt = vehicle(9)
runStage("cameras", cvt, ground(cvt, 0, 0), 120)
ReplicatedStorage:SetAttribute("AW02Finished", true)

-- P8 : plusieurs véhicules simultanés — coût serveur avant / pendant un banc de 16 véhicules.
hooks:Invoke("ResetPerf")
task.wait(15)
local idle = hooks:Invoke("ServerPerf")
hooks:Invoke("ResetPerf")
local spawned = hooks:Invoke("SpawnBench", nil, 16)
task.wait(20)
local loaded = hooks:Invoke("ServerPerf")
local function ms(value: number): string
    return string.format("%.3f", value * 1000)
end
record(
    "lot02.info_cout_serveur_parc_au_repos",
    true,
    string.format(
        "battement médiane %s ms, P95 %s, P99 %s (n=%d) ; pas véhicule médiane %s ms (n=%d) ; dégâts médiane %s ms",
        ms(idle.Heartbeat.Median),
        ms(idle.Heartbeat.P95),
        ms(idle.Heartbeat.P99),
        idle.Heartbeat.Count,
        ms(idle.VehicleStep.Median),
        idle.VehicleStep.Count,
        ms(idle.Damage.Median)
    )
)
record(
    "lot02.info_cout_serveur_banc_16_vehicules",
    spawned == 16,
    string.format(
        "%d véhicules au total ; battement médiane %s ms, P95 %s, P99 %s (n=%d) ; pas véhicule médiane %s ms, P95 %s, P99 %s (n=%d) ; dégâts médiane %s ms, P99 %s",
        loaded.Vehicles,
        ms(loaded.Heartbeat.Median),
        ms(loaded.Heartbeat.P95),
        ms(loaded.Heartbeat.P99),
        loaded.Heartbeat.Count,
        ms(loaded.VehicleStep.Median),
        ms(loaded.VehicleStep.P95),
        ms(loaded.VehicleStep.P99),
        loaded.VehicleStep.Count,
        ms(loaded.Damage.Median),
        ms(loaded.Damage.P99)
    )
)
local benchUpright, benchMoving = 0, 0
for i = 1, 16 do
    local bench = folder:FindFirstChild("Banc_" .. i)
    local root = bench and bench.PrimaryPart
    if root then
        if root.CFrame.UpVector.Y > 0.9 then
            benchUpright += 1
        end
        if root.AssemblyLinearVelocity.Magnitude > 1 then
            benchMoving += 1
        end
    end
end
record(
    "lot02.banc_vehicules_stables",
    benchUpright == 16 and benchMoving >= 14,
    string.format("%d droits, %d en mouvement sur 16", benchUpright, benchMoving)
)

local impacts = hooks:Invoke("Impacts")
record(
    "lot02.info_chocs_serveur",
    true,
    string.format(
        "%d choc(s) confirmés, %d variation(s) sans obstacle (non retenues), %d requête(s) de volume",
        #impacts.Impacts,
        impacts.Unconfirmed,
        impacts.Queries
    )
)
record("lot02.aucune_correction_serveur", #corrections == 0, #corrections .. " : " .. table.concat(corrections, " || "))

channel:SetAttribute("Steps", HttpService:JSONEncode(steps))
channel:SetAttribute("Done", true)
