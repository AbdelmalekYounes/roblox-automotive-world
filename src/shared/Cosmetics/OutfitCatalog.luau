--!strict
--[[
    Catalogue des tenues de personnage (lot AVATAR-01) : fondation, INDÉPENDANTE du
    catalogue des cosmétiques automobiles (`Shared.Vehicles`, `Shared.Garage`).

    - Emplacements : vêtements classiques (Shirt / Pants / T-shirt graphique), vêtements
      3D superposés (layered clothing, `Enum.AccessoryType`), accessoires rigides.
    - Collection future : cinq catégories préparées (pilote circuit premium, pilote
      street racing, mécanicien, assistance routière, chauffeur VTC). Ce sont des
      EMPLACEMENTS de catalogue : aucune ressource produite, aucun identifiant Roblox
      (jamais d'identifiant inventé ; les fichiers artistiques validés viendront après).
    - Aucune boutique, aucun prix, aucune monétisation.

    Le client ne choisit qu'un identifiant de tenue de ce catalogue : il n'envoie jamais
    d'identifiant d'actif (règle d'autorité du serveur). Textes : clés de localisation.
    Module pur, gelé.
]]

local OutfitCatalog = {}

export type SlotGroup = "Classic" | "Layered" | "Rigid"

export type Slot = {
    Id: string,
    Group: SlotGroup,
    -- Classique : champ de `HumanoidDescription` ; superposé et rigide : `Enum.AccessoryType`.
    Field: string?,
    AccessoryType: string?,
    -- Superposé : ordre de superposition proposé (plus grand = au-dessus) ; à confirmer
    -- avec les fichiers artistiques.
    Order: number?,
    LabelKey: string,
}

export type Status = "Placeholder" | "Available"

export type Outfit = {
    Id: string,
    Category: string,
    Status: Status,
    LabelKey: string,
    -- Emplacement → identifiant d'actif Roblox. Vide tant que les fichiers artistiques
    -- ne sont pas validés et publiés par le propriétaire.
    Items: { [string]: number },
}

export type Category = { Id: string, LabelKey: string }

local function slot(entry: Slot): Slot
    return table.freeze(entry)
end

OutfitCatalog.Slots = table.freeze({
    -- Vêtements classiques (textures 2D sur le corps).
    slot({ Id = "ClassicShirt", Group = "Classic", Field = "Shirt", LabelKey = "outfit.slot.ClassicShirt" }),
    slot({ Id = "ClassicPants", Group = "Classic", Field = "Pants", LabelKey = "outfit.slot.ClassicPants" }),
    slot({ Id = "ClassicTShirt", Group = "Classic", Field = "GraphicTShirt", LabelKey = "outfit.slot.ClassicTShirt" }),
    -- Vêtements 3D superposés.
    slot({
        Id = "LayeredLeftShoe",
        Group = "Layered",
        AccessoryType = "LeftShoe",
        Order = 1,
        LabelKey = "outfit.slot.LayeredLeftShoe",
    }),
    slot({
        Id = "LayeredRightShoe",
        Group = "Layered",
        AccessoryType = "RightShoe",
        Order = 1,
        LabelKey = "outfit.slot.LayeredRightShoe",
    }),
    slot({
        Id = "LayeredPants",
        Group = "Layered",
        AccessoryType = "Pants",
        Order = 2,
        LabelKey = "outfit.slot.LayeredPants",
    }),
    slot({
        Id = "LayeredShorts",
        Group = "Layered",
        AccessoryType = "Shorts",
        Order = 2,
        LabelKey = "outfit.slot.LayeredShorts",
    }),
    slot({
        Id = "LayeredDressSkirt",
        Group = "Layered",
        AccessoryType = "DressSkirt",
        Order = 3,
        LabelKey = "outfit.slot.LayeredDressSkirt",
    }),
    slot({
        Id = "LayeredTShirt",
        Group = "Layered",
        AccessoryType = "TShirt",
        Order = 4,
        LabelKey = "outfit.slot.LayeredTShirt",
    }),
    slot({
        Id = "LayeredShirt",
        Group = "Layered",
        AccessoryType = "Shirt",
        Order = 5,
        LabelKey = "outfit.slot.LayeredShirt",
    }),
    slot({
        Id = "LayeredSweater",
        Group = "Layered",
        AccessoryType = "Sweater",
        Order = 6,
        LabelKey = "outfit.slot.LayeredSweater",
    }),
    slot({
        Id = "LayeredJacket",
        Group = "Layered",
        AccessoryType = "Jacket",
        Order = 7,
        LabelKey = "outfit.slot.LayeredJacket",
    }),
    -- Accessoires rigides additionnels.
    slot({ Id = "Hat", Group = "Rigid", AccessoryType = "Hat", LabelKey = "outfit.slot.Hat" }),
    slot({ Id = "Hair", Group = "Rigid", AccessoryType = "Hair", LabelKey = "outfit.slot.Hair" }),
    slot({ Id = "Face", Group = "Rigid", AccessoryType = "Face", LabelKey = "outfit.slot.Face" }),
    slot({ Id = "Neck", Group = "Rigid", AccessoryType = "Neck", LabelKey = "outfit.slot.Neck" }),
    slot({ Id = "Shoulder", Group = "Rigid", AccessoryType = "Shoulder", LabelKey = "outfit.slot.Shoulder" }),
    slot({ Id = "Front", Group = "Rigid", AccessoryType = "Front", LabelKey = "outfit.slot.Front" }),
    slot({ Id = "Back", Group = "Rigid", AccessoryType = "Back", LabelKey = "outfit.slot.Back" }),
    slot({ Id = "Waist", Group = "Rigid", AccessoryType = "Waist", LabelKey = "outfit.slot.Waist" }),
} :: { Slot })

local slotById: { [string]: Slot } = {}
local slotByAccessoryType: { [string]: Slot } = {}
for _, entry in OutfitCatalog.Slots do
    slotById[entry.Id] = entry
    if entry.AccessoryType then
        -- Un type d'accessoire n'appartient qu'à un seul emplacement.
        assert(slotByAccessoryType[entry.AccessoryType] == nil, "type d'accessoire en double")
        slotByAccessoryType[entry.AccessoryType :: string] = entry
    end
end

-- Cinq catégories de la collection future (ordre d'affichage).
OutfitCatalog.Categories = table.freeze({
    table.freeze({ Id = "CircuitPremium", LabelKey = "outfit.category.CircuitPremium" }),
    table.freeze({ Id = "StreetRacing", LabelKey = "outfit.category.StreetRacing" }),
    table.freeze({ Id = "Mechanic", LabelKey = "outfit.category.Mechanic" }),
    table.freeze({ Id = "RoadsideAssistance", LabelKey = "outfit.category.RoadsideAssistance" }),
    table.freeze({ Id = "RideHailDriver", LabelKey = "outfit.category.RideHailDriver" }),
} :: { Category })

-- Un emplacement de tenue par catégorie, sans ressource (statut « Placeholder »).
local outfits: { Outfit } = {}
for _, category in OutfitCatalog.Categories do
    table.insert(
        outfits,
        table.freeze({
            Id = category.Id .. ".1",
            Category = category.Id,
            Status = "Placeholder" :: Status,
            LabelKey = "outfit.item." .. category.Id .. ".1",
            Items = table.freeze({}),
        })
    )
end
OutfitCatalog.Outfits = table.freeze(outfits)

function OutfitCatalog.slot(id: string): Slot?
    return slotById[id]
end

function OutfitCatalog.slotForAccessoryType(accessoryType: string): Slot?
    return slotByAccessoryType[accessoryType]
end

function OutfitCatalog.outfit(id: string): Outfit?
    for _, outfit in OutfitCatalog.Outfits do
        if outfit.Id == id then
            return outfit
        end
    end
    return nil
end

return table.freeze(OutfitCatalog)
