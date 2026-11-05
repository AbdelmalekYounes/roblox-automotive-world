-- Essais SERVEUR du lot 0.8 (session « lot08 », place de développement, 1 joueur),
-- écrits au lot 0.9 et injectés par le pilote dans le Studio de test uniquement.
-- Il vérifie la protection d'apparition (champ de force, groupe de collision), la
-- structure des carrosseries de la gamme, matérialise sur demande du client un
-- exemplaire TEMPORAIRE protégé de chacun des 18 modèles proposés (même chemin que
-- les essais du parcours d'arrivée : aucune écriture durable) et le retire ensuite,
-- puis contrôle le profil (un seul véhicule de départ, propriété gratuite unique).

local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StudioTestService = game:GetService("StudioTestService")

local args = StudioTestService:GetTestArgs()
local session = if type(args) == "table" and type(args.Session) == "string" then args.Session else ""
if session ~= "lot08" then
    return
end

local steps = {}
local function record(name: string, ok: boolean, detail: any)
    table.insert(steps, { name = name, ok = ok, detail = if detail ~= nil then tostring(detail) else nil })
end

local errors, robloxErrors, validation = {}, {}, {}
LogService.MessageOut:Connect(function(message, messageType)
    if messageType == Enum.MessageType.MessageError then
        local ours = string.find(message, "AutomotiveWorld", 1, true)
            or string.find(message, "ReplicatedStorage.Shared", 1, true)
            or string.find(message, "AW_Test", 1, true)
        table.insert(if ours then errors else robloxErrors, message)
    elseif string.find(message, "[Validation]", 1, true) then
        table.insert(validation, message)
    end
end)

local reportEvent = Instance.new("RemoteEvent")
reportEvent.Name = "AWTestReport"
reportEvent.Parent = ReplicatedStorage
local signalEvent = Instance.new("RemoteEvent")
signalEvent.Name = "AWTestSignal"
signalEvent.Parent = ReplicatedStorage
ReplicatedStorage:SetAttribute("AWTestSession", session)
ReplicatedStorage:SetAttribute("AWTestPlayers", 1)

local function waitFor(predicate: () -> boolean, timeout: number): boolean
    local start = os.clock()
    while os.clock() - start < timeout do
        if predicate() then
            return true
        end
        task.wait(0.2)
    end
    return predicate()
end

local Server = ServerScriptService:WaitForChild("AutomotiveWorldServer")
local ProfileService = require(Server:WaitForChild("Persistence"):WaitForChild("ProfileService"))
local ProfileSchema = require(Server.Persistence.ProfileSchema)
local MissionService = require(Server:WaitForChild("Economy"):WaitForChild("MissionService"))
local VehicleService = require(Server:WaitForChild("Vehicles"):WaitForChild("VehicleService"))

local reports = {}
reportEvent.OnServerEvent:Connect(function(player, payload)
    reports[tostring(player.UserId)] = payload
end)

-- Demandes du client : « AW08:Spawn:<modèle> » (exemplaire temporaire) et « AW08:Despawn ».
local current: Model? = nil
local structure = {}
signalEvent.OnServerEvent:Connect(function(player, message)
    if type(message) ~= "string" or string.sub(message, 1, 5) ~= "AW08:" then
        return
    end
    local command = string.sub(message, 6)
    if string.sub(command, 1, 6) == "Spawn:" then
        local modelId = string.sub(command, 7)
        if current and current.Parent then
            VehicleService.despawnPersonal(current)
        end
        current = MissionService.spawnBeside(player, modelId, "BANC-" .. modelId)
        if current then
            local body = current:FindFirstChild("Carrosserie")
            local passenger = current:FindFirstChild("PassengerSeat")
            local lights = 0
            for _, item in (body and body:GetDescendants()) or {} do
                if item:IsA("BasePart") and item:GetAttribute("AWLight") ~= nil then
                    lights += 1
                end
            end
            table.insert(
                structure,
                string.format(
                    "%s:%s/%s/%d",
                    modelId,
                    if body and body:FindFirstChild("BouclierAvant") then "boucliers" else "SANS-BOUCLIER",
                    if passenger then "passager" else "SANS-PASSAGER",
                    lights
                )
            )
            ReplicatedStorage:SetAttribute("AW08_Spawned", current.Name)
        else
            ReplicatedStorage:SetAttribute("AW08_Spawned", "ECHEC:" .. modelId)
        end
    elseif command == "Despawn" then
        if current and current.Parent then
            VehicleService.despawnPersonal(current)
        end
        current = nil
        ReplicatedStorage:SetAttribute("AW08_Spawned", "")
    else
        ReplicatedStorage:SetAttribute("AW08_" .. command, true)
    end
end)

local joined = waitFor(function()
    return #Players:GetPlayers() >= 1
end, 60)
record("lot08.serveur.joueur_connecte", joined)
local player = Players:GetPlayers()[1]
waitFor(function()
    local profileSession = player and ProfileService.get(player)
    return profileSession ~= nil and profileSession.State == "Active"
end, 40)

-- Protection d'apparition : champ de force et groupe « AWArrivee » tant que le parcours n'est pas fini.
local character = player and (player.Character or player.CharacterAdded:Wait())
local shielded = waitFor(function()
    return character ~= nil and character:FindFirstChild("ProtectionArrivee") ~= nil
end, 20)
local grouped = 0
for _, item in (character and character:GetDescendants()) or {} do
    if item:IsA("BasePart") and item.CollisionGroup == "AWArrivee" then
        grouped += 1
    end
end
record("lot08.serveur.protection_apparition", shielded and grouped > 0, grouped .. " pièce(s) dans AWArrivee")
ReplicatedStorage:SetAttribute("AW08_ServerReady", true)

local gotReport = waitFor(function()
    return next(reports) ~= nil
end, 1100)
record("lot08.serveur.rapport_client", gotReport)
record("lot08.serveur.info_carrosseries", #structure > 0, table.concat(structure, " "))
local missing = 0
for _, line in structure do
    if string.find(line, "SANS-", 1, true) then
        missing += 1
    end
end
record(
    "lot08.serveur.carrosseries_completes",
    #structure >= 18 and missing == 0,
    #structure .. " modèle(s), " .. missing .. " incomplet(s)"
)

local profileSession = player and ProfileService.get(player)
local data = profileSession and profileSession.Data
if data then
    local starters, free = 0, 0
    for _, vehicle in data.Vehicles do
        if vehicle.Origin == "Starter" then
            starters += 1
        end
    end
    for _, property in data.Properties do
        if property.Origin == "FreeStarter" then
            free += 1
        end
    end
    record(
        "lot08.serveur.un_seul_vehicule_de_depart",
        starters == 1 and data.Starter.State == "Chosen",
        string.format(
            "%d exemplaire(s) de départ, état %s, modèle %s",
            starters,
            data.Starter.State,
            tostring(data.Starter.ModelId)
        )
    )
    record("lot08.serveur.propriete_gratuite_unique", free == 1, free)
    record("lot08.serveur.parcours_termine", data.Onboarding.Step == "Done", data.Onboarding.Step)
    local valid, problems = ProfileSchema.validate(data)
    record("lot08.serveur.profil_coherent", valid, table.concat(problems, " ; "))
end
record("lot08.serveur.info_journal_validation", true, #validation .. " : " .. table.concat(validation, " || "))
record("lot08.serveur.aucune_erreur_execution", #errors == 0, table.concat(errors, " || "))
record("lot08.serveur.info_erreurs_internes_roblox", true, #robloxErrors .. " : " .. table.concat(robloxErrors, " || "))

StudioTestService:EndTest({
    session = session,
    players = #Players:GetPlayers(),
    server = steps,
    clients = reports,
})
