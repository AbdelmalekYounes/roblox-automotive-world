--!strict
--[[
    Personnalisation esthétique PURE et MODULAIRE (lot 0.4).

    Les choix esthétiques d'un exemplaire sont de simples identifiants de ce
    catalogue, séparés de la géométrie : la fabrique de véhicules applique une
    apparence dérivée (couleurs, finition, jantes, éléments) sans dupliquer la
    voiture. Éléments visuels TEMPORAIRES pour les prototypes ; la finition
    premium relève des lots artistiques. Les cosmétiques premium liés au compte
    (Robux, §5.5) ne sont pas traités ici et ne seraient jamais transférés.
]]

local CosmeticCatalog = {}

export type Cosmetics = {
    BodyColor: string,
    AccentColor: string,
    Finish: string,
    Wheels: string,
    BodyKit: { [string]: string }, -- emplacement → élément
    Accessories: { string },
    ShowLabel: boolean, -- paramètre visuel propre au modèle (inscription latérale)
}

export type Swatch = { Id: string, Label: string, Rgb: { number } }
export type Option = { Id: string, Label: string }

local function swatch(id: string, label: string, r: number, g: number, b: number): Swatch
    return table.freeze({ Id = id, Label = label, Rgb = table.freeze({ r, g, b }) })
end

local COLORS: { Swatch } = {
    swatch("Graphite", "Graphite", 74, 80, 89),
    swatch("Blanc", "Blanc nacré", 236, 236, 232),
    swatch("Noir", "Noir profond", 22, 23, 26),
    swatch("Rouge", "Rouge vif", 176, 28, 34),
    swatch("Bleu", "Bleu nuit", 28, 58, 120),
    swatch("Vert", "Vert anglais", 26, 82, 56),
    swatch("Orange", "Orange signal", 255, 122, 26),
    swatch("Jaune", "Jaune soleil", 240, 196, 32),
    swatch("Argent", "Argent", 170, 174, 180),
    swatch("Sable", "Sable", 196, 176, 140),
}
CosmeticCatalog.Colors = table.freeze(COLORS)

-- Finitions : matériau Roblox et brillance (temporaires).
CosmeticCatalog.Finishes = table.freeze({
    Gloss = table.freeze({ Label = "Brillant", Material = "SmoothPlastic", Reflectance = 0.08 }),
    Metallic = table.freeze({ Label = "Métallisé", Material = "Metal", Reflectance = 0.12 }),
    Matte = table.freeze({ Label = "Mat", Material = "Plastic", Reflectance = 0 }),
    Pearl = table.freeze({ Label = "Nacré", Material = "Glass", Reflectance = 0.18 }),
})

CosmeticCatalog.Wheels = table.freeze({
    Stock = "Jantes d'origine",
    Sport = "Jantes sport",
    Classic = "Jantes classiques",
    Aero = "Jantes aérodynamiques",
})

-- Éléments de carrosserie par emplacement (aucune incidence physique).
CosmeticCatalog.BodyKitSlots = table.freeze({
    Front = table.freeze({ "Stock", "Lip" }),
    Rear = table.freeze({ "Stock", "Spoiler", "Wing" }),
    Sides = table.freeze({ "Stock", "Skirts" }),
})

CosmeticCatalog.Accessories = table.freeze({
    RoofRack = "Barres de toit",
    LightBar = "Rampe lumineuse",
    Stripes = "Bandes décoratives",
})
CosmeticCatalog.MaxAccessories = 2

local colorById: { [string]: Swatch } = {}
for _, item in COLORS do
    colorById[item.Id] = item
end

function CosmeticCatalog.color(id: string): Swatch?
    return colorById[id]
end

-- Apparence par défaut d'un modèle : couleurs d'origine les plus proches.
function CosmeticCatalog.defaults(_definition: any): Cosmetics
    return {
        BodyColor = "Graphite",
        AccentColor = "Orange",
        Finish = "Gloss",
        Wheels = "Stock",
        BodyKit = { Front = "Stock", Rear = "Stock", Sides = "Stock" },
        Accessories = {},
        ShowLabel = true,
    }
end

function CosmeticCatalog.validate(cosmetics: any): (boolean, { string })
    local errors: { string } = {}
    if type(cosmetics) ~= "table" then
        return false, { "CosmeticsInvalid" }
    end
    if type(cosmetics.BodyColor) ~= "string" or colorById[cosmetics.BodyColor] == nil then
        table.insert(errors, "CosmeticColor")
    end
    if type(cosmetics.AccentColor) ~= "string" or colorById[cosmetics.AccentColor] == nil then
        table.insert(errors, "CosmeticAccent")
    end
    if type(cosmetics.Finish) ~= "string" or (CosmeticCatalog.Finishes :: any)[cosmetics.Finish] == nil then
        table.insert(errors, "CosmeticFinish")
    end
    if type(cosmetics.Wheels) ~= "string" or (CosmeticCatalog.Wheels :: any)[cosmetics.Wheels] == nil then
        table.insert(errors, "CosmeticWheels")
    end
    if type(cosmetics.ShowLabel) ~= "boolean" then
        table.insert(errors, "CosmeticLabel")
    end
    local kit = cosmetics.BodyKit
    if type(kit) ~= "table" then
        table.insert(errors, "CosmeticBodyKit")
    else
        for slot, choice in kit do
            local options = (CosmeticCatalog.BodyKitSlots :: any)[slot]
            if options == nil or table.find(options, choice) == nil then
                table.insert(errors, "CosmeticBodyKit:" .. tostring(slot))
            end
        end
    end
    local accessories = cosmetics.Accessories
    if type(accessories) ~= "table" or #accessories > CosmeticCatalog.MaxAccessories then
        table.insert(errors, "CosmeticAccessories")
    else
        local seen = {}
        for _, id in accessories do
            if (CosmeticCatalog.Accessories :: any)[id] == nil or seen[id] then
                table.insert(errors, "CosmeticAccessory:" .. tostring(id))
            end
            seen[id] = true
        end
    end
    return #errors == 0, errors
end

-- Apparence dérivée (format VehicleAppearance du lot 0.2) pour la fabrique.
function CosmeticCatalog.appearance(base: any, cosmetics: Cosmetics): any
    local body = colorById[cosmetics.BodyColor]
    local accent = colorById[cosmetics.AccentColor]
    return {
        BodyRgb = if body then { body.Rgb[1], body.Rgb[2], body.Rgb[3] } else base.BodyRgb,
        AccentRgb = if accent then { accent.Rgb[1], accent.Rgb[2], accent.Rgb[3] } else base.AccentRgb,
        TrimRgb = base.TrimRgb,
        Label = if cosmetics.ShowLabel then base.Label else "",
    }
end

return table.freeze(CosmeticCatalog)
