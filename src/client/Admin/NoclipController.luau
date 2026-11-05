--!strict
--[[
    Déplacement libre « no clip » du menu d'administration (lot ADMIN-01).

    Actif seulement quand le SERVEUR a posé l'attribut AWAdminNoclip sur le joueur (après vérification des droits ;
    vitesse dans AWAdminNoclipSpeed, studs/s). Le personnage est sous la propriété réseau de son joueur : le client
    applique le déplacement (collisions coupées, vitesse imposée à chaque image, gravité compensée), qui se réplique.
    Commandes : déplacement de la caméra (ZQSD ou WASD), Espace pour monter, Maj gauche pour descendre.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local NoclipController = {}

local player = Players.LocalPlayer
local restore: { [BasePart]: boolean } = {}
local active = false

local function parts(character: Model): { BasePart }
    local list = {}
    for _, item in character:GetDescendants() do
        if item:IsA("BasePart") then
            table.insert(list, item)
        end
    end
    return list
end

local function stop(character: Model?)
    active = false
    for part, collide in restore do
        if part.Parent then
            part.CanCollide = collide
        end
    end
    table.clear(restore)
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.PlatformStand = false
    end
end

local function step()
    local character = player.Character
    local enabled = player:GetAttribute("AWAdminNoclip") == true
    if character == nil then
        return
    end
    if not enabled then
        if active then
            stop(character)
        end
        return
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if humanoid == nil or root == nil or not root:IsA("BasePart") or humanoid.SeatPart ~= nil then
        return
    end
    active = true
    humanoid.PlatformStand = true
    for _, part in parts(character) do
        if restore[part] == nil then
            restore[part] = part.CanCollide
        end
        part.CanCollide = false
    end
    local speed = player:GetAttribute("AWAdminNoclipSpeed")
    local rate = if type(speed) == "number" then speed else 60
    local camera = Workspace.CurrentCamera
    local direction = humanoid.MoveDirection
    if camera and direction.Magnitude > 0 then
        -- Direction de marche (horizontale, relative à la caméra) inclinée selon la caméra : on vole où l'on regarde.
        local look = camera.CFrame.LookVector
        local flat = Vector3.new(look.X, 0, look.Z)
        local forwardShare = if flat.Magnitude > 0 then direction:Dot(flat.Unit) else 0
        direction = direction + Vector3.new(0, look.Y * forwardShare, 0)
    end
    local vertical = 0
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        vertical += 1
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
        vertical -= 1
    end
    local velocity = direction + Vector3.new(0, vertical, 0)
    if velocity.Magnitude > 1 then
        velocity = velocity.Unit
    end
    root.AssemblyLinearVelocity = velocity * rate
    root.AssemblyAngularVelocity = Vector3.zero
end

function NoclipController.start()
    RunService.Stepped:Connect(step)
    player.CharacterAdded:Connect(function()
        table.clear(restore)
        active = false
    end)
end

return table.freeze(NoclipController)
