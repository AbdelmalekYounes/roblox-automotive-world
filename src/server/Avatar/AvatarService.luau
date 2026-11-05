--!strict
--[[
    Personnages des joueurs (lot AVATAR-01) : contrôle R15, apparence initiale et
    tenues (essayage, équipement, retrait, restauration).

    R15 : imposé par le réglage de la place (`StarterPlayer.GameSettingsAvatar`, voir
    `Shared.Avatar.AvatarPolicy`). Un personnage d'un autre squelette est SIGNALÉ
    (journal, attribut `AWAvatarRig`) et jamais converti en silence : une conversion
    manuelle perdrait les scripts d'animation fournis par le moteur.

    Apparence initiale : lue au chargement de l'apparence de chaque nouveau personnage
    (avant toute tenue), conservée pour la restauration. Une tenue équipée est réappliquée
    après une réapparition. Rien n'est sauvegardé (aucune persistance dans ce lot).

    Corps (décision du propriétaire, 2026-11-04) : avatars humains uniquement ; chaque
    joueur porte l'un des deux corps retenus (`AvatarPolicy.Bodies`), à son choix
    (action « BodyChoose », session seulement), sinon le corps par défaut. La tête et le
    visage du joueur sont conservés, sauf une tête classique « bloc » (forme mesurée),
    remplacée par la tête du corps choisi.

    Tenues : le client ne désigne qu'une tenue du catalogue (`Shared.Cosmetics`), jamais
    un identifiant d'actif. Changement refusé assis dans un véhicule (le moteur
    reconstruit des pièces du personnage : effets possibles sur l'ensemble du véhicule).
    Un identifiant refusé par le moteur rétablit l'apparence précédente
    (« OutfitAssetInvalid »).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AvatarPolicy = require(Shared:WaitForChild("Avatar"):WaitForChild("AvatarPolicy"))
local CosmeticsFolder = Shared:WaitForChild("Cosmetics")
local OutfitCatalog = require(CosmeticsFolder:WaitForChild("OutfitCatalog"))
local OutfitRules = require(CosmeticsFolder:WaitForChild("OutfitRules"))
local RateLimiter = require(script.Parent.Parent.Security.RateLimiter)
local ApplyQueue = require(script.Parent.ApplyQueue)
local RunService = game:GetService("RunService")

local AvatarService = {}

local FOLDER = "AWAvatar"
local RIG_ATTRIBUTE = "AWAvatarRig"
local PREVIEW_ATTRIBUTE = "AWOutfitPreview"
local PREVIEW_S = 30 -- durée d'un essayage, puis retour automatique
local BODY_ATTRIBUTE = "AWAvatarBody" -- corps porté (joueur ; répliqué, lu par le client)
local BODY_CHOSEN_ATTRIBUTE = "AWAvatarBodyChosen" -- vrai après un choix explicite (session)

export type Result = { Status: string, Reason: string? }

type State = {
    Initial: OutfitRules.Look?,
    Equipped: OutfitCatalog.Outfit?, -- tenue équipée (réappliquée après réapparition)
    PreviewToken: number,
    Busy: boolean,
    Body: string?, -- corps choisi par le joueur pendant la session (nil : corps par défaut)
    SpawnToken: number, -- préparation du personnage en cours (corps et tenue à l'apparition)
    PlayerHead: number, -- tête de l'apparence Roblox du joueur (relevée à chaque apparition)
    HeadClassic: boolean, -- tête du joueur classique « bloc » : remplacée par celle du corps
}

local states: { [Player]: State } = {}
local limiters: { [Player]: RateLimiter.Bucket } = {}
local nonR15 = 0
local enforceHuman: (Player, Humanoid) -> ()
local started = false

local function stateOf(player: Player): State
    local state = states[player]
    if state == nil then
        state = {
            Initial = nil,
            Equipped = nil,
            PreviewToken = 0,
            Busy = false,
            Body = nil,
            SpawnToken = 0,
            PlayerHead = 0,
            HeadClassic = true,
        }
        states[player] = state
    end
    return state :: State
end

local function humanoidOf(player: Player): Humanoid?
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid == nil or humanoid.Health <= 0 then
        return nil
    end
    return humanoid
end

-- ======================== HumanoidDescription ↔ Look ========================

local function lookOf(description: HumanoidDescription): OutfitRules.Look
    local accessories: { OutfitRules.AccessoryItem } = {}
    for _, entry in description:GetAccessories(true) do
        local accessoryType = entry.AccessoryType
        table.insert(accessories, {
            AssetId = entry.AssetId,
            AccessoryType = if typeof(accessoryType) == "EnumItem" then accessoryType.Name else tostring(accessoryType),
            IsLayered = entry.IsLayered == true,
            Order = if entry.IsLayered then entry.Order else nil,
        })
    end
    return {
        Shirt = description.Shirt,
        Pants = description.Pants,
        GraphicTShirt = description.GraphicTShirt,
        Accessories = accessories,
    }
end

-- Liste d'accessoires pour `SetAccessories` : les entrées déjà portées gardent leurs
-- réglages d'origine (gonflement des vêtements superposés, etc.).
local function accessoryList(look: OutfitRules.Look, current: HumanoidDescription): { any }
    local previous: { [string]: any } = {}
    for _, entry in current:GetAccessories(true) do
        local name = if typeof(entry.AccessoryType) == "EnumItem" then entry.AccessoryType.Name else ""
        previous[name .. ":" .. tostring(entry.AssetId)] = entry
    end
    local list = {}
    for _, item in look.Accessories do
        local kept = previous[item.AccessoryType .. ":" .. tostring(item.AssetId)]
        if kept then
            table.insert(list, kept)
        else
            local entry: { [string]: any } = {
                AssetId = item.AssetId,
                AccessoryType = (Enum.AccessoryType :: any)[item.AccessoryType],
                IsLayered = item.IsLayered,
            }
            if item.IsLayered then
                entry.Order = item.Order or 1
                entry.Puffiness = 1
            end
            table.insert(list, entry)
        end
    end
    return list
end

-- Toutes les écritures de l'apparence passent par une file par personnage (`ApplyQueue`) :
-- une application à la fois, dans l'ordre ; une application expirée garde son tour jusqu'à sa fin
-- réelle, si bien qu'elle ne peut plus écraser un choix plus récent. Abandon au-delà de 30 s, avec
-- réconciliation si elle se termine après coup (`reconcile`, défini plus bas).
local APPLY_TIMEOUT_S = 10 -- attente maximale d'un appelant
local APPLY_ABANDON_S = 30 -- au-delà, l'application en cours est abandonnée
local reconcile: (key: any, ticket: number) -> ()
local applyQueue = ApplyQueue.new({
    TimeoutS = APPLY_TIMEOUT_S,
    AbandonS = APPLY_ABANDON_S,
    OnStale = function(key: any, ticket: number)
        reconcile(key, ticket)
    end,
})

-- Applique une apparence ; en cas d'échec du moteur ou d'actif ignoré, l'apparence
-- précédente est rétablie. L'apparence de départ est lue à son tour dans la file (état le plus
-- récent), jamais avant.
local function applyLook(humanoid: Humanoid, look: OutfitRules.Look): Result
    local before: HumanoidDescription? = nil
    local listOk = true
    local outcome = applyQueue:run(humanoid, function()
        local current = humanoid:GetAppliedDescription()
        before = current
        local wanted = current:Clone()
        wanted.Shirt = look.Shirt
        wanted.Pants = look.Pants
        wanted.GraphicTShirt = look.GraphicTShirt
        listOk = pcall(function()
            wanted:SetAccessories(accessoryList(look, current), true)
        end)
        if listOk then
            humanoid:ApplyDescriptionAsync(wanted)
        end
    end)
    if not listOk then
        return { Status = "Rejected", Reason = "OutfitAssetInvalid" }
    end
    if outcome == "Timeout" then
        return { Status = "Rejected", Reason = "AppearanceTimeout" }
    end
    local missing = if outcome == "Ok"
        then OutfitRules.missing(look, lookOf(humanoid:GetAppliedDescription()))
        else { "?" }
    if outcome == "Ok" and #missing == 0 then
        return { Status = "Ok" }
    end
    -- Rétablissement de l'apparence précédente (meilleur effort, journalisé), lui aussi dans la file.
    local previous = before
    local restored = previous ~= nil
        and applyQueue:run(humanoid, function()
                humanoid:ApplyDescriptionAsync(previous :: HumanoidDescription)
            end)
            == "Ok"
    warn(
        string.format(
            "[AutomotiveWorld] Tenue refusée par le moteur (%s) ; apparence précédente %s",
            table.concat(missing, ", "),
            if restored then "rétablie" else "NON rétablie"
        )
    )
    return { Status = "Rejected", Reason = "OutfitAssetInvalid" }
end

-- ======================== Opérations ========================

local function guard(player: Player): (Humanoid?, State?, Result?)
    local humanoid = humanoidOf(player)
    if humanoid == nil then
        return nil, nil, { Status = "Rejected", Reason = "OutfitNoCharacter" }
    end
    if humanoid.SeatPart ~= nil then
        return nil, nil, { Status = "Rejected", Reason = "OutfitNotWhileSeated" }
    end
    local state = stateOf(player)
    if state.Initial == nil then
        return nil, nil, { Status = "Rejected", Reason = "OutfitAppearanceLoading" }
    end
    if state.Busy then
        return nil, nil, { Status = "Rejected", Reason = "OutfitBusy" }
    end
    return humanoid, state, nil
end

local function outfitFor(id: any): (OutfitCatalog.Outfit?, string?)
    if type(id) ~= "string" then
        return nil, "OutfitUnknown"
    end
    local outfit = OutfitCatalog.outfit(id)
    if outfit == nil then
        return nil, "OutfitUnknown"
    end
    if outfit.Status ~= "Available" then
        return nil, "OutfitNotAvailable"
    end
    return outfit, nil
end

-- Porte une tenue (validée) sur l'apparence initiale ; `preview` : essayage temporaire.
function AvatarService.wearOutfit(player: Player, outfit: OutfitCatalog.Outfit, preview: boolean): Result
    local valid, errors = OutfitRules.validateOutfit(outfit)
    if not valid then
        return { Status = "Rejected", Reason = errors[1] }
    end
    local humanoid, state, refusal = guard(player)
    if refusal then
        return refusal
    end
    local h, s = humanoid :: Humanoid, state :: State
    s.Busy = true
    local result = applyLook(h, OutfitRules.wear(s.Initial :: OutfitRules.Look, outfit))
    s.Busy = false
    if result.Status ~= "Ok" then
        return result
    end
    s.PreviewToken += 1
    if preview then
        local token = s.PreviewToken
        player:SetAttribute(PREVIEW_ATTRIBUTE, outfit.Id)
        task.delay(PREVIEW_S, function()
            if s.PreviewToken == token and player.Parent then
                AvatarService.cancelPreview(player)
            end
        end)
    else
        s.Equipped = outfit
        player:SetAttribute(PREVIEW_ATTRIBUTE, nil)
    end
    return result
end

-- Fin d'essayage : retour à la tenue équipée, ou à l'apparence initiale.
function AvatarService.cancelPreview(player: Player): Result
    local humanoid, state, refusal = guard(player)
    if refusal then
        return refusal
    end
    local h, s = humanoid :: Humanoid, state :: State
    s.PreviewToken += 1
    player:SetAttribute(PREVIEW_ATTRIBUTE, nil)
    local target = if s.Equipped
        then OutfitRules.wear(s.Initial :: OutfitRules.Look, s.Equipped :: OutfitCatalog.Outfit)
        else s.Initial :: OutfitRules.Look
    s.Busy = true
    local result = applyLook(h, target)
    s.Busy = false
    return result
end

-- Retrait d'un emplacement : il reprend l'apparence initiale du joueur.
function AvatarService.removeSlot(player: Player, slotId: any): Result
    local humanoid, state, refusal = guard(player)
    if refusal then
        return refusal
    end
    if type(slotId) ~= "string" then
        return { Status = "Rejected", Reason = "OutfitSlotUnknown" }
    end
    local h, s = humanoid :: Humanoid, state :: State
    local look, reason =
        OutfitRules.removeSlot(lookOf(h:GetAppliedDescription()), s.Initial :: OutfitRules.Look, slotId)
    if look == nil then
        return { Status = "Rejected", Reason = reason }
    end
    s.Busy = true
    local result = applyLook(h, look :: OutfitRules.Look)
    s.Busy = false
    if result.Status == "Ok" then
        -- La tenue n'est plus portée telle quelle : elle ne sera pas réappliquée.
        s.Equipped = nil
    end
    return result
end

-- Restauration complète de l'apparence initiale du joueur.
function AvatarService.restore(player: Player): Result
    local humanoid, state, refusal = guard(player)
    if refusal then
        return refusal
    end
    local h, s = humanoid :: Humanoid, state :: State
    s.PreviewToken += 1
    s.Equipped = nil
    player:SetAttribute(PREVIEW_ATTRIBUTE, nil)
    s.Busy = true
    local result = applyLook(h, s.Initial :: OutfitRules.Look)
    s.Busy = false
    return result
end

-- Apparence initiale connue (copie), pour les essais et la restauration.
function AvatarService.initialLook(player: Player): OutfitRules.Look?
    local initial = stateOf(player).Initial
    return if initial then OutfitRules.copy(initial) else nil
end

function AvatarService.currentLook(player: Player): OutfitRules.Look?
    local humanoid = humanoidOf(player)
    return if humanoid then lookOf(humanoid:GetAppliedDescription()) else nil
end

function AvatarService.nonR15Count(): number
    return nonR15
end

-- ======================== Requêtes des clients ========================

local function catalogView(): { any }
    local list = {}
    for _, outfit in OutfitCatalog.Outfits do
        table.insert(list, {
            Id = outfit.Id,
            Category = outfit.Category,
            Status = outfit.Status,
            LabelKey = outfit.LabelKey,
        })
    end
    return list
end

local function handle(player: Player, action: any, payload: any): any
    local bucket = limiters[player]
    if bucket == nil then
        bucket = RateLimiter.new(4, 1, os.clock())
        limiters[player] = bucket
    end
    if not RateLimiter.consume(bucket :: RateLimiter.Bucket, os.clock()) then
        return { Status = "Rejected", Reason = "RateLimited" }
    end
    local data = if type(payload) == "table" then payload else {}
    if action == "OutfitCatalog" then
        return { Status = "Ok", Outfits = catalogView() }
    elseif action == "OutfitPreview" or action == "OutfitEquip" then
        local outfit, reason = outfitFor(data.Id)
        if outfit == nil then
            return { Status = "Rejected", Reason = reason }
        end
        return AvatarService.wearOutfit(player, outfit :: OutfitCatalog.Outfit, action == "OutfitPreview")
    elseif action == "OutfitCancelPreview" then
        return AvatarService.cancelPreview(player)
    elseif action == "OutfitRemove" then
        return AvatarService.removeSlot(player, data.Slot)
    elseif action == "OutfitRestore" then
        return AvatarService.restore(player)
    elseif action == "BodyChoose" then
        return AvatarService.chooseBody(player, data.Body)
    end
    return { Status = "Rejected", Reason = "ActionUnknown" }
end

-- ======================== Cycle de vie ========================

-- Avatars humains uniquement (décision du propriétaire, 2026-11-04) : type de corps ramené aux
-- proportions humaines et parties du corps remplacées par l'un des deux corps retenus
-- (`AvatarPolicy.Bodies`, choix du joueur, sinon corps par défaut), pour TOUS les joueurs.
-- Tête, visage, peau, vêtements et accessoires du joueur sont conservés. Un échec du moteur
-- laisse l'apparence d'origine (journalisé). L'attribut `AWAvatarBody` indique le corps porté.
local humanized = 0
local APPLY_ATTEMPTS = 3
local function humanDescription(description: HumanoidDescription, bodyId: string, head: number): boolean
    local changed = false
    local scales: { [string]: string } = {
        BodyType = "BodyTypeScale",
        Height = "HeightScale",
        Width = "WidthScale",
        Head = "HeadScale",
        Proportion = "ProportionScale",
    }
    for name, field in scales do
        local value = (description :: any)[field]
        local clamped = AvatarPolicy.clampScale(name, value)
        if clamped ~= value then
            (description :: any)[field] = clamped
            changed = true
        end
    end
    local body = AvatarPolicy.Bodies[bodyId]
    for _, field in AvatarPolicy.ReplacedParts do
        local assetId = body.Parts[field]
        if (description :: any)[field] ~= assetId then
            (description :: any)[field] = assetId
            changed = true
        end
    end
    if description.Head ~= head then
        description.Head = head
        changed = true
    end
    if AvatarPolicy.UnifySkinOnHead then
        for field, color in AvatarPolicy.unifiedColors(description.HeadColor) do
            if (description :: any)[field] ~= color then
                (description :: any)[field] = color
                changed = true
            end
        end
    end
    return changed
end

-- Forme des têtes déjà mesurées (identifiant → classique ?), pour ne mesurer qu'une fois.
local classicHeads: { [number]: boolean } = { [0] = true }

-- Relève la tête de l'apparence Roblox du joueur à l'apparition (avant tout remplacement) et sa
-- forme, mesurée sur la pièce `Head` chargée par le moteur (critère `AvatarPolicy`).
local function readPlayerHead(player: Player, humanoid: Humanoid)
    local state = stateOf(player)
    local headId = humanoid:GetAppliedDescription().Head
    state.PlayerHead = headId
    local known = classicHeads[headId]
    if known ~= nil then
        state.HeadClassic = known
        return
    end
    local character = humanoid.Parent
    local head = character and character:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        local classic = AvatarPolicy.isClassicHeadShape(head.Size.X, head.Size.Y, head.Size.Z)
        classicHeads[headId] = classic
        state.HeadClassic = classic
    else
        -- Pièce absente : tête conservée (aucun remplacement sur une forme non mesurée).
        state.HeadClassic = false
    end
end

local function partsOf(description: HumanoidDescription): { [string]: number }
    local parts: { [string]: number } = {}
    for _, field in AvatarPolicy.ReplacedParts do
        parts[field] = (description :: any)[field]
    end
    return parts
end

function enforceHuman(player: Player, humanoid: Humanoid)
    if not AvatarPolicy.HumanOnly then
        return
    end
    local state = stateOf(player)
    -- À l'apparition, le moteur peut refuser l'application tant que le personnage n'est pas
    -- installé (« DataModel was not available », VM 2026-11-04, tâche 20261104-145632) :
    -- attente de l'entrée dans Workspace, puis jusqu'à 3 essais espacés de 0,5 s.
    local deadline = os.clock() + 5
    while not humanoid:IsDescendantOf(workspace) and os.clock() < deadline do
        task.wait(0.1)
    end
    for attempt = 1, APPLY_ATTEMPTS do
        -- Corps et tête lus À SON TOUR dans la file : toujours le dernier choix du joueur.
        local attemptStart = os.clock()
        local changed = false
        local outcome, err = applyQueue:run(humanoid, function()
            local bodyNow = state.Body or AvatarPolicy.DefaultBody
            local headNow = AvatarPolicy.headFor(bodyNow, state.PlayerHead, state.HeadClassic)
            local description = humanoid:GetAppliedDescription()
            changed = humanDescription(description, bodyNow, headNow)
            if changed then
                humanoid:ApplyDescriptionAsync(description)
            end
            -- Attribut tenu à jour à la fin RÉELLE de chaque application (même expirée pour
            -- l'appelant) : il décrit toujours la dernière apparence appliquée.
            local applied = humanoid:GetAppliedDescription()
            local worn = AvatarPolicy.wearsBody(partsOf(applied), bodyNow) and applied.Head == headNow
            player:SetAttribute(BODY_ATTRIBUTE, if worn then bodyNow else nil)
        end)
        if outcome == "Ok" and not changed then
            break
        end
        if outcome == "Ok" then
            humanized += 1
            if attempt > 1 then
                print(
                    string.format(
                        "[AutomotiveWorld] Avatar humain appliqué à %s à l'essai %d (%.1f s)",
                        player.Name,
                        attempt,
                        os.clock() - attemptStart
                    )
                )
            end
            break
        end
        warn(
            string.format(
                "[AutomotiveWorld] Avatar humain : essai %d/%d refusé pour %s (%.1f s) : %s",
                attempt,
                APPLY_ATTEMPTS,
                player.Name,
                os.clock() - attemptStart,
                err
            )
        )
        if humanoid.Parent == nil then
            break
        end
        task.wait(0.5)
    end
    local bodyId = state.Body or AvatarPolicy.DefaultBody
    local head = AvatarPolicy.headFor(bodyId, state.PlayerHead, state.HeadClassic)
    local applied = humanoid:GetAppliedDescription()
    local worn = AvatarPolicy.wearsBody(partsOf(applied), bodyId) and applied.Head == head
    player:SetAttribute(BODY_ATTRIBUTE, if worn then bodyId else nil)
end

-- Choix du corps par le joueur (session seulement : aucune persistance avant le lot prévu).
-- Mêmes refus qu'un changement de tenue (assis, apparence en chargement, opération en cours).
function AvatarService.chooseBody(player: Player, id: any): Result
    local body = AvatarPolicy.body(id)
    if body == nil then
        return { Status = "Rejected", Reason = "AvatarBodyUnknown" }
    end
    local humanoid, state, refusal = guard(player)
    if refusal then
        return refusal
    end
    local h, s = humanoid :: Humanoid, state :: State
    local previous = s.Body
    s.Body = body.Id
    s.Busy = true
    enforceHuman(player, h)
    s.Busy = false
    if s.Body ~= body.Id then
        -- Un choix plus récent a pris la place (file ordonnée) : rien à signaler au joueur.
        return { Status = "Ok", Superseded = true } :: any
    end
    if player:GetAttribute(BODY_ATTRIBUTE) ~= body.Id then
        s.Body = previous
        return { Status = "Rejected", Reason = "AvatarBodyInvalid" }
    end
    player:SetAttribute(BODY_CHOSEN_ATTRIBUTE, true)
    return { Status = "Ok" }
end

-- Application abandonnée terminée après coup : l'état voulu (corps, tête, tenue) est rétabli
-- dans la file, depuis l'état le plus récent du joueur.
function reconcile(key: any, _ticket: number)
    if typeof(key) ~= "Instance" or not key:IsA("Humanoid") then
        return
    end
    local humanoid = key :: Humanoid
    local player = Players:GetPlayerFromCharacter(humanoid.Parent)
    if player == nil or humanoid.Parent == nil or humanoid.Health <= 0 then
        return
    end
    warn(string.format("[AutomotiveWorld] Application d'apparence tardive pour %s : réconciliation", player.Name))
    enforceHuman(player, humanoid)
    local state = stateOf(player)
    if state.Initial then
        local target = if state.Equipped
            then OutfitRules.wear(state.Initial :: OutfitRules.Look, state.Equipped :: OutfitCatalog.Outfit)
            else state.Initial :: OutfitRules.Look
        applyLook(humanoid, target)
    end
end

-- Essais en Studio seulement : délais réduits pour provoquer de vraies expirations.
function AvatarService.setApplyTimeoutsForTests(timeoutS: number, abandonS: number)
    assert(RunService:IsStudio(), "réservé aux essais en Studio")
    applyQueue.Options.TimeoutS = timeoutS
    applyQueue.Options.AbandonS = abandonS
end

-- Applications terminées après abandon (réconciliées) et opérations en file (essais).
function AvatarService.applyStats(player: Player): (number, number)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return applyQueue.Stale, if humanoid then applyQueue:pending(humanoid) else 0
end

-- Tête du joueur relevée à l'apparition et forme mesurée (essais).
function AvatarService.headInfo(player: Player): (number, boolean)
    local state = stateOf(player)
    return state.PlayerHead, state.HeadClassic
end

function AvatarService.humanizedCount(): number
    return humanized
end

local function onCharacter(player: Player, character: Model)
    local humanoid = character:WaitForChild("Humanoid", 10)
    if humanoid == nil or not humanoid:IsA("Humanoid") then
        return
    end
    local rig = humanoid.RigType.Name
    character:SetAttribute(RIG_ATTRIBUTE, rig)
    if not AvatarPolicy.isAllowedRig(rig) then
        nonR15 += 1
        warn(
            string.format(
                "[AutomotiveWorld] Personnage %s non R15 (%s) : réglage d'avatar à vérifier",
                player.Name,
                rig
            )
        )
    end
    if not player:HasAppearanceLoaded() then
        player.CharacterAppearanceLoaded:Wait()
    end
    if player.Character ~= character or humanoid.Parent == nil then
        return
    end
    -- Apparence initiale (vêtements et accessoires, que le corps ne change pas) mémorisée
    -- AVANT le corps humain : la préparation du personnage n'attend pas le moteur. Corps puis
    -- tenue équipée appliqués ensuite dans un fil séparé, demandes du joueur refusées entre-temps
    -- (« OutfitBusy »).
    local state = stateOf(player)
    readPlayerHead(player, humanoid)
    state.Initial = lookOf(humanoid:GetAppliedDescription())
    state.PreviewToken += 1
    player:SetAttribute(PREVIEW_ATTRIBUTE, nil)
    state.Busy = true
    state.SpawnToken += 1
    local token = state.SpawnToken
    task.spawn(function()
        enforceHuman(player, humanoid)
        if state.Equipped and player.Character == character then
            applyLook(
                humanoid,
                OutfitRules.wear(state.Initial :: OutfitRules.Look, state.Equipped :: OutfitCatalog.Outfit)
            )
        end
        if state.SpawnToken == token then
            state.Busy = false
        end
    end)
end

function AvatarService.start()
    assert(not started, "AvatarService déjà démarré")
    started = true
    local existing = ReplicatedStorage:FindFirstChild(FOLDER)
    if existing then
        existing:Destroy()
    end
    local folder = Instance.new("Folder")
    folder.Name = FOLDER
    local request = Instance.new("RemoteFunction")
    request.Name = "Request"
    request.Parent = folder
    folder.Parent = ReplicatedStorage
    request.OnServerInvoke = function(player: Player, action: any, payload: any): any
        return handle(player, action, payload)
    end
    local function watch(player: Player)
        player.CharacterAdded:Connect(function(character)
            onCharacter(player, character)
        end)
        if player.Character then
            task.spawn(onCharacter, player, player.Character)
        end
    end
    Players.PlayerAdded:Connect(watch)
    for _, player in Players:GetPlayers() do
        watch(player)
    end
    Players.PlayerRemoving:Connect(function(player)
        states[player] = nil
        limiters[player] = nil
    end)
end

return AvatarService
