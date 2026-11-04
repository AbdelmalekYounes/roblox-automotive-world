--!strict
--[[
    Règles pures des tenues de personnage (lot AVATAR-01) : validation des identifiants
    d'actifs et des tenues, et calcul de l'apparence résultante (essayage, équipement,
    retrait d'un emplacement, restauration de l'apparence initiale).

    « Look » : représentation PURE de la partie vestimentaire d'une `HumanoidDescription`
    (le serveur la lit et l'écrit, `OutfitService`) :
    - `Shirt`, `Pants`, `GraphicTShirt` : identifiants d'actifs classiques (0 = aucun) ;
    - `Accessories` : accessoires rigides et vêtements superposés du personnage.
    Le corps, le visage, les couleurs et les échelles ne sont jamais touchés ici :
    l'apparence du joueur est conservée hors des emplacements portés par la tenue.
]]

local OutfitCatalog = require(script.Parent.OutfitCatalog)

local OutfitRules = {}

export type AccessoryItem = {
    AssetId: number,
    AccessoryType: string,
    IsLayered: boolean,
    Order: number?,
}

export type Look = {
    Shirt: number,
    Pants: number,
    GraphicTShirt: number,
    Accessories: { AccessoryItem },
}

-- Plus grand entier exactement représentable (identifiants d'actifs : entiers positifs).
local MAX_ASSET_ID = 2 ^ 53

-- Identifiant d'actif bien formé : nombre entier fini, strictement positif. La
-- validation ne prouve pas que l'actif existe : le moteur le vérifie à l'application
-- (`OutfitService`, refus « OutfitAssetInvalid » et apparence précédente rétablie).
function OutfitRules.validAssetId(value: any): boolean
    return type(value) == "number"
        and value == value
        and value > 0
        and value <= MAX_ASSET_ID
        and math.floor(value) == value
end

-- Tenue cohérente : emplacements connus, identifiants bien formés ; un emplacement
-- (« Placeholder ») n'a aucun actif, une tenue disponible en a au moins un.
function OutfitRules.validateOutfit(outfit: any): (boolean, { string })
    local errors: { string } = {}
    if type(outfit) ~= "table" or type(outfit.Id) ~= "string" or type(outfit.Items) ~= "table" then
        return false, { "OutfitMalformed" }
    end
    if outfit.Status ~= "Placeholder" and outfit.Status ~= "Available" then
        table.insert(errors, "OutfitStatusUnknown")
    end
    local count = 0
    for slotId, assetId in outfit.Items do
        count += 1
        if type(slotId) ~= "string" or OutfitCatalog.slot(slotId) == nil then
            table.insert(errors, "OutfitSlotUnknown:" .. tostring(slotId))
        elseif not OutfitRules.validAssetId(assetId) then
            table.insert(errors, "OutfitAssetInvalid:" .. slotId)
        end
    end
    if outfit.Status == "Placeholder" and count > 0 then
        table.insert(errors, "OutfitPlaceholderHasAssets")
    elseif outfit.Status == "Available" and count == 0 then
        table.insert(errors, "OutfitEmpty")
    end
    table.sort(errors)
    return #errors == 0, errors
end

local function copyItem(item: AccessoryItem): AccessoryItem
    return { AssetId = item.AssetId, AccessoryType = item.AccessoryType, IsLayered = item.IsLayered, Order = item.Order }
end

function OutfitRules.copy(look: Look): Look
    local accessories = table.create(#look.Accessories)
    for _, item in look.Accessories do
        table.insert(accessories, copyItem(item))
    end
    return { Shirt = look.Shirt, Pants = look.Pants, GraphicTShirt = look.GraphicTShirt, Accessories = accessories }
end

-- Retire de `look` (sur place) les accessoires de l'emplacement donné.
local function clearSlot(look: Look, slot: OutfitCatalog.Slot)
    if slot.Group == "Classic" then
        (look :: any)[slot.Field :: string] = 0
        return
    end
    local kept: { AccessoryItem } = {}
    for _, item in look.Accessories do
        if item.AccessoryType ~= slot.AccessoryType then
            table.insert(kept, item)
        end
    end
    look.Accessories = kept
end

-- Apparence portant la tenue : chaque emplacement de la tenue remplace celui du joueur ;
-- les autres emplacements (cheveux, accessoires personnels…) sont conservés.
function OutfitRules.wear(look: Look, outfit: OutfitCatalog.Outfit): Look
    local result = OutfitRules.copy(look)
    local slotIds: { string } = {}
    for slotId in outfit.Items do
        table.insert(slotIds, slotId)
    end
    table.sort(slotIds) -- ordre déterministe
    for _, slotId in slotIds do
        local slot = OutfitCatalog.slot(slotId)
        local assetId = outfit.Items[slotId]
        if slot and OutfitRules.validAssetId(assetId) then
            clearSlot(result, slot)
            if slot.Group == "Classic" then
                (result :: any)[slot.Field :: string] = assetId
            else
                table.insert(result.Accessories, {
                    AssetId = assetId,
                    AccessoryType = slot.AccessoryType :: string,
                    IsLayered = slot.Group == "Layered",
                    Order = slot.Order,
                })
            end
        end
    end
    return result
end

-- Retrait d'un emplacement : il reprend ce que portait l'apparence initiale du joueur.
function OutfitRules.removeSlot(look: Look, initial: Look, slotId: string): (Look?, string?)
    local slot = OutfitCatalog.slot(slotId)
    if slot == nil then
        return nil, "OutfitSlotUnknown"
    end
    local result = OutfitRules.copy(look)
    clearSlot(result, slot)
    if slot.Group == "Classic" then
        (result :: any)[slot.Field :: string] = (initial :: any)[slot.Field :: string]
    else
        for _, item in initial.Accessories do
            if item.AccessoryType == slot.AccessoryType then
                table.insert(result.Accessories, copyItem(item))
            end
        end
    end
    return result, nil
end

-- Comparaison indépendante de l'ordre des accessoires.
local function key(item: AccessoryItem): string
    return string.format(
        "%s:%d:%s:%s",
        item.AccessoryType,
        item.AssetId,
        tostring(item.IsLayered),
        tostring(item.Order)
    )
end

function OutfitRules.equal(a: Look, b: Look): boolean
    if a.Shirt ~= b.Shirt or a.Pants ~= b.Pants or a.GraphicTShirt ~= b.GraphicTShirt then
        return false
    end
    if #a.Accessories ~= #b.Accessories then
        return false
    end
    local keysA, keysB = {}, {}
    for _, item in a.Accessories do
        table.insert(keysA, key(item))
    end
    for _, item in b.Accessories do
        table.insert(keysB, key(item))
    end
    table.sort(keysA)
    table.sort(keysB)
    for index, value in keysA do
        if keysB[index] ~= value then
            return false
        end
    end
    return true
end

-- Actifs de `wanted` absents de `applied` (le moteur a ignoré un identifiant invalide).
function OutfitRules.missing(wanted: Look, applied: Look): { string }
    local present: { [string]: boolean } = {}
    for _, item in applied.Accessories do
        present[item.AccessoryType .. ":" .. item.AssetId] = true
    end
    local missing: { string } = {}
    for _, field in { "Shirt", "Pants", "GraphicTShirt" } do
        local value = (wanted :: any)[field]
        if value ~= 0 and (applied :: any)[field] ~= value then
            table.insert(missing, field)
        end
    end
    for _, item in wanted.Accessories do
        if not present[item.AccessoryType .. ":" .. item.AssetId] then
            table.insert(missing, item.AccessoryType)
        end
    end
    table.sort(missing)
    return missing
end

return table.freeze(OutfitRules)
