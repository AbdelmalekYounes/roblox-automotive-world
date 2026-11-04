--!strict
--[[
    Choix de la silhouette (avatars humains, décision du propriétaire du 2026-11-04) :
    « Masculin » ou « Féminin ». Seul le corps change ; la tête, le visage, la peau et les
    vêtements du joueur sont conservés (`Shared.Avatar.AvatarPolicy`).

    - Petit panneau à la première apparition de la session, tant que le joueur n'a pas
      choisi (attribut serveur `AWAvatarBodyChosen`) ; d'ici là, le serveur applique le corps
      par défaut. Le panneau ne bloque ni le déplacement ni les autres interfaces.
    - Modifiable ensuite dans Téléphone › Paramètres › Interface (`BodyChoice.choose`).
    Le serveur décide (AvatarService, action « BodyChoose ») : refus assis dans un véhicule,
    pendant le chargement de l'apparence ou une autre opération. Rien n'est sauvegardé.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Localization = require(Shared:WaitForChild("UI"):WaitForChild("Localization"))
local AvatarPolicy = require(Shared:WaitForChild("Avatar"):WaitForChild("AvatarPolicy"))

local UITheme = require(script.Parent.UITheme)
local NotificationService = require(script.Parent.NotificationService)

local BodyChoice = {}

local BODY_ATTRIBUTE = "AWAvatarBody"
local CHOSEN_ATTRIBUTE = "AWAvatarBodyChosen"

local player = Players.LocalPlayer
local gui: ScreenGui? = nil
local busy = false

local function request(): RemoteFunction?
    local folder = ReplicatedStorage:FindFirstChild("AWAvatar")
    local remote = folder and folder:FindFirstChild("Request")
    return if remote and remote:IsA("RemoteFunction") then remote else nil
end

-- Corps porté (nil tant que le serveur ne l'a pas confirmé).
function BodyChoice.current(): string?
    local value = player:GetAttribute(BODY_ATTRIBUTE)
    return if type(value) == "string" then value else nil
end

-- Demande le corps `id` au serveur ; refus signalé par une notification (clé du serveur).
function BodyChoice.choose(id: string): boolean
    local remote = request()
    if busy or remote == nil then
        return false
    end
    busy = true
    local ok, response = pcall(function()
        return (remote :: RemoteFunction):InvokeServer("BodyChoose", { Body = id })
    end)
    busy = false
    if ok and type(response) == "table" and response.Status == "Ok" then
        return true
    end
    local reason = if ok
            and type(response) == "table"
            and type(response.Reason) == "string"
        then response.Reason
        else "AvatarBodyInvalid"
    NotificationService.notify(reason, "Warning")
    return false
end

-- Corps suivant dans l'ordre d'affichage (paramètres du téléphone).
function BodyChoice.next(): string
    local order = AvatarPolicy.BodyOrder
    local index = table.find(order, BodyChoice.current() or AvatarPolicy.DefaultBody) or 1
    return order[index % #order + 1]
end

local function close()
    if gui then
        gui:Destroy()
        gui = nil
    end
end

local function open()
    if gui ~= nil then
        return
    end
    local screen = UITheme.make(
        "ScreenGui",
        { Name = "AWBodyChoice", ResetOnSpawn = false, DisplayOrder = 14, IgnoreGuiInset = false },
        player:WaitForChild("PlayerGui")
    )
    gui = screen
    -- En haut, sous le bandeau d'information : ne masque ni le centre de l'écran ni le HUD.
    local panel = UITheme.panel({
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 96),
        Size = UDim2.fromOffset(380, 150),
    }, screen)
    UITheme.label(Localization.t("avatar.body.title"), 17, {
        Position = UDim2.fromOffset(14, 10),
        Size = UDim2.new(1, -28, 0, 24),
        Font = UITheme.FontBold,
    }, panel)
    UITheme.label(Localization.t("avatar.body.hint"), 13, {
        Position = UDim2.fromOffset(14, 36),
        Size = UDim2.new(1, -28, 0, 48),
        TextWrapped = true,
        TextColor3 = UITheme.color("TextDim"),
    }, panel)
    for index, id in AvatarPolicy.BodyOrder do
        UITheme.button(
            Localization.t("avatar.body." .. id),
            {
                Name = "Body" .. id,
                Position = UDim2.new((index - 1) * 0.5, 14 - (index - 1) * 7, 1, -52),
                Size = UDim2.new(0.5, -21, 0, 38),
            },
            panel,
            function()
                if BodyChoice.choose(id) then
                    close()
                end
            end
        )
    end
end

function BodyChoice.start()
    player:GetAttributeChangedSignal(CHOSEN_ATTRIBUTE):Connect(function()
        if player:GetAttribute(CHOSEN_ATTRIBUTE) == true then
            close()
        end
    end)
    -- Le dossier distant n'existe que si AvatarService tourne (places de développement).
    task.spawn(function()
        if ReplicatedStorage:WaitForChild("AWAvatar", 30) == nil then
            return
        end
        if player:GetAttribute(CHOSEN_ATTRIBUTE) ~= true then
            open()
        end
    end)
end

return BodyChoice
