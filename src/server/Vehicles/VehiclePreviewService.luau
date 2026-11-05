--!strict
--[[
    Copies VISUELLES des véhicules pour l'aperçu 3D du garage (lot UI-03 ; ViewportFrame choisi par le propriétaire
    le 2026-11-05).

    Pourquoi côté serveur : les gabarits 3D (kits de maillages, ServerStorage) et la fabrique ne sont pas visibles du
    client. Le serveur construit donc, à la première demande, une copie du modèle par la fabrique habituelle, puis la
    rend inerte avant de la placer dans ReplicatedStorage (une copie par modèle du catalogue, partagée par tous).

    Garanties :
    - lecture seule : aucune possession, aucune donnée de profil, aucune écriture ; seul l'identifiant de modèle est
      lu dans la demande, validé (forme, puis existence dans le catalogue) ;
    - la copie n'est PAS un véhicule : étiquette et attributs d'identité retirés (aucun système du jeu ne la prend
      pour un véhicule), pièces ancrées, sans collision ni requête, joints, forces, invites et lumières supprimés ;
    - au plus une copie par modèle du catalogue (18 au lancement) ; délai minimal entre deux demandes d'un joueur.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehiclesShared = Shared:WaitForChild("Vehicles")
local Constants = require(VehiclesShared:WaitForChild("VehicleConstants"))
local VehicleDefinitions = require(VehiclesShared:WaitForChild("VehicleDefinitions"))
local PreviewFraming = require(Shared:WaitForChild("UI"):WaitForChild("PreviewFraming"))
local VehicleFactory = require(script.Parent.VehicleFactory)

local VehiclePreviewService = {}

VehiclePreviewService.FolderName = "AWVehiclePreview"

local models: Folder
local lastRequest: { [Player]: number } = {}
local started = false

local function rgb(values: { number }): Color3
    return Color3.fromRGB(values[1], values[2], values[3])
end

-- Rend la copie inerte et marque les pièces repeintes par le client selon la teinte choisie au garage.
local function makeInert(model: Model, definition: any)
    CollectionService:RemoveTag(model, Constants.VehicleTag)
    for name in model:GetAttributes() do
        model:SetAttribute(name, nil)
    end
    model:SetAttribute("AWPreviewOf", definition.Id)
    local appearance = definition.Appearance
    local roles = {
        [rgb(appearance.BodyRgb):ToHex()] = "Body",
        [rgb(appearance.AccentRgb):ToHex()] = "Accent",
    }
    -- Peinture des kits de maillages : teinte de la SurfaceAppearance seulement en mode « Teinte » (MeshKits).
    local body = model:FindFirstChild("Carrosserie")
    local tinted = body ~= nil and body:GetAttribute("AWPaint") == "Teinte"
    for _, item in model:GetDescendants() do
        if
            item:IsA("JointInstance")
            or item:IsA("WeldConstraint")
            or item:IsA("Constraint")
            or item:IsA("VectorForce")
            or item:IsA("ProximityPrompt")
            or item:IsA("Light")
            or item:IsA("BaseScript")
        then
            item:Destroy()
        end
    end
    for _, item in model:GetDescendants() do
        if item:IsA("BasePart") then
            if item:GetAttribute("AWCollisionOnly") then
                item:Destroy()
                continue
            end
            item.Anchored = true
            item.CanCollide = false
            item.CanQuery = false
            item.CanTouch = false
            item.CastShadow = false
            local appearanceItem = item:FindFirstChildOfClass("SurfaceAppearance")
            if appearanceItem then
                if tinted and roles[appearanceItem.Color:ToHex()] == "Body" then
                    item:SetAttribute("AWPaintRole", "Body")
                end
            else
                local role = roles[item.Color:ToHex()]
                if role then
                    item:SetAttribute("AWPaintRole", role)
                end
            end
        end
    end
end

-- Construit (une seule fois) la copie d'un modèle ; renvoie son nom dans le dossier, ou nil si refusé.
function VehiclePreviewService.ensure(modelId: string): string?
    local existing = models:FindFirstChild(modelId)
    if existing then
        return modelId
    end
    local definition = VehicleDefinitions.get(modelId)
    if definition == nil then
        return nil
    end
    -- La fabrique ne cède pas la main : deux demandes simultanées ne construisent jamais deux copies.
    local ok, result = pcall(VehicleFactory.create, definition, CFrame.new(), 0)
    if not ok or typeof(result) ~= "Instance" then
        warn("[AutomotiveWorld] Aperçu impossible pour " .. modelId .. " : " .. tostring(result))
        return nil
    end
    local model = result :: Model
    makeInert(model, definition)
    model.Name = modelId
    model.Parent = models
    return modelId
end

function VehiclePreviewService.start()
    if started then
        return
    end
    started = true
    local folder = Instance.new("Folder")
    folder.Name = VehiclePreviewService.FolderName
    models = Instance.new("Folder")
    models.Name = "Modeles"
    models.Parent = folder
    local request = Instance.new("RemoteFunction")
    request.Name = "Request"
    request.OnServerInvoke = function(player: Player, modelId: any): string?
        if not PreviewFraming.validModelId(modelId) then
            return nil
        end
        local now = os.clock()
        if now - (lastRequest[player] or -math.huge) < PreviewFraming.RequestInterval then
            return nil
        end
        lastRequest[player] = now
        return VehiclePreviewService.ensure(modelId)
    end
    request.Parent = folder
    folder.Parent = ReplicatedStorage
    Players.PlayerRemoving:Connect(function(player)
        lastRequest[player] = nil
    end)
end

return table.freeze(VehiclePreviewService)
