--!strict
--[[
    Manifeste des ressources (lot 0.8, §7, direction artistique).

    Chaque ressource a un identifiant STABLE, une catégorie, une version, des
    variantes de qualité, un niveau de détail (LOD), sa provenance, sa licence
    et un statut : Provisional (provisoire), ReadyForReview (prêt à valider) ou
    Validated (validé — réservé au propriétaire ; aucune entrée ne l'est ici).

    Toutes les ressources sont ORIGINALES : géométrie construite par code
    (BodyKits, générateur de carte), sons synthétisés par un script du dépôt.
    Aucun actif Marketplace, aucun emprunt à un autre projet.

    RobloxAssetId : identifiant Roblox RÉEL après téléversement par le
    propriétaire. Il est nil partout : rien n'a été téléversé, aucun
    identifiant n'est inventé. Tant qu'il est nil, la ressource n'est pas
    jouée en jeu (les contrôleurs audio restent muets, la radio indisponible).

    Source : fichier du dépôt qui produit la ressource (module de construction,
    générateur hors ligne ou script de synthèse) ; les tests (pytest) vérifient
    son existence.
]]

local AssetManifest = {}

AssetManifest.Version = "0.8.0"

export type Status = "Provisional" | "ReadyForReview" | "Validated"
export type Category = "VehicleBody" | "VehicleLight" | "WorldGeometry" | "WorldDecor" | "Lighting" | "Audio" | "Interface"

export type Asset = {
    Id: string,
    Category: Category,
    Version: string,
    Status: Status,
    -- Variantes de qualité graphique ou sonore : Low / Medium / High.
    Variants: { [string]: string },
    Lod: string,
    Provenance: string,
    Licence: string,
    Source: { Kind: "File", Path: string },
    -- Fichier produit par la source (son à téléverser), relatif au dépôt.
    Output: string?,
    RobloxAssetId: number?,
}

local ORIGINAL = "Original — conçu pour Automotive World"
local LICENCE = "Propriété du projet Automotive World (aucun tiers)"
local BODY_MODULE = "src/server/Vehicles/BodyKits.luau"
local WORLD_GENERATOR = "tools/world/build-world.luau"
local AUDIO_GENERATOR = "tools/audio/synth.py"

local list: { Asset } = {}

local function add(asset: Asset)
    table.insert(list, asset)
end

-- ======================== Carrosseries (10 silhouettes) ========================
for _, style in { "Micro", "Hatch", "Sedan", "Wagon", "Coupe", "Roadster", "Supercar", "SUV", "OffRoad", "Pickup" } do
    add({
        Id = "vehicle.body." .. string.lower(style),
        Category = "VehicleBody",
        Version = "0.8.0",
        Status = "Provisional",
        Variants = {
            Low = "Coque, vitrages et roues ; détails masqués",
            Medium = "Détails visibles jusqu'à 120 m",
            High = "Détails visibles jusqu'à 250 m",
        },
        Lod = "Dossier Carrosserie/Details masqué au-delà de la distance de la variante (client)",
        Provenance = ORIGINAL .. " : pièces Roblox de base assemblées par code (silhouette " .. style .. ")",
        Licence = LICENCE,
        Source = { Kind = "File", Path = BODY_MODULE },
        Output = nil,
        RobloxAssetId = nil,
    })
end

add({
    Id = "vehicle.body.prototype",
    Category = "VehicleBody",
    Version = "0.1.0",
    Status = "Provisional",
    Variants = { Low = "Identique", Medium = "Identique", High = "Identique" },
    Lod = "Aucun (prototypes de développement P-01 à P-03)",
    Provenance = ORIGINAL .. " : carrosserie de prototype des lots 0.1–0.2",
    Licence = LICENCE,
    Source = { Kind = "File", Path = "src/server/Vehicles/VehicleFactory.luau" },
    Output = nil,
    RobloxAssetId = nil,
})

add({
    Id = "vehicle.lights",
    Category = "VehicleLight",
    Version = "0.8.0",
    Status = "Provisional",
    Variants = {
        Low = "Pièces lumineuses (Neon) sans source de lumière",
        Medium = "Sources limitées aux 4 véhicules les plus proches",
        High = "Sources limitées aux 8 véhicules les plus proches",
    },
    Lod = "Sources de lumière (Lumiere) activées la nuit, par proximité et selon la qualité",
    Provenance = ORIGINAL .. " : phares et feux arrière de BodyKits, pilotés par VehicleLights",
    Licence = LICENCE,
    Source = { Kind = "File", Path = "src/client/World/VehicleLights.luau" },
    Output = nil,
    RobloxAssetId = nil,
})

-- ======================== Monde ========================
add({
    Id = "world.geometry",
    Category = "WorldGeometry",
    Version = "0.3.0",
    Status = "Provisional",
    Variants = { Low = "Identique", Medium = "Identique", High = "Identique" },
    Lod = "Streaming Roblox de la place (la carte est générée hors ligne)",
    Provenance = ORIGINAL .. " : relief, routes et bâtiments générés de façon déterministe",
    Licence = LICENCE,
    Source = { Kind = "File", Path = WORLD_GENERATOR },
    Output = nil,
    RobloxAssetId = nil,
})

for _, zone in { "Metropole", "Banlieues", "Docks", "Montagnes", "Campagne", "Motorsport", "Littoral" } do
    add({
        Id = "world.decor." .. string.lower(zone),
        Category = "WorldDecor",
        Version = "0.8.0",
        Status = "Provisional",
        Variants = {
            Low = "Décor masqué (seuls relief, routes et bâtiments)",
            Medium = "Décor visible jusqu'à 180 m",
            High = "Décor visible jusqu'à 350 m",
        },
        Lod = "Dossier Decor par zone : visibilité réglée côté client par distance et qualité",
        Provenance = ORIGINAL
            .. " : habillage de la zone "
            .. zone
            .. " généré hors ligne (aucune construction au démarrage)",
        Licence = LICENCE,
        Source = { Kind = "File", Path = WORLD_GENERATOR },
        Output = nil,
        RobloxAssetId = nil,
    })
end

add({
    Id = "world.lighting",
    Category = "Lighting",
    Version = "0.8.0",
    Status = "Provisional",
    Variants = {
        Low = "Ombres globales seules, sans effets",
        Medium = "Atmosphère, bloom léger",
        High = "Atmosphère, bloom, rayons du soleil, correction colorimétrique",
    },
    Lod = "Effets d'éclairage par qualité (client)",
    Provenance = ORIGINAL .. " : réglages Lighting et effets de post-traitement de base",
    Licence = LICENCE,
    Source = { Kind = "File", Path = "src/shared/Art/ArtDirection.luau" },
    Output = nil,
    RobloxAssetId = nil,
})

-- ======================== Audio (synthétisé, à téléverser) ========================
local function sound(id: string, file: string, note: string, variants: { [string]: string }?)
    add({
        Id = "audio." .. id,
        Category = "Audio",
        Version = "0.8.0",
        Status = "Provisional",
        Variants = variants or { Low = "Identique", Medium = "Identique", High = "Identique" },
        Lod = "Atténuation par distance (RollOff) ; aucune lecture sans RobloxAssetId",
        Provenance = ORIGINAL .. " : synthèse procédurale (" .. note .. ")",
        Licence = LICENCE,
        Source = { Kind = "File", Path = AUDIO_GENERATOR },
        Output = "build/audio/" .. file,
        RobloxAssetId = nil,
    })
end

local LAYERS = { Low = "2 couches", Medium = "3 couches", High = "Toutes les couches" }
for _, layer in { "idle", "low", "mid", "high" } do
    sound("engine.petrol." .. layer, "engine_petrol_" .. layer .. ".wav", "moteur essence, couche " .. layer, LAYERS)
    sound("engine.diesel." .. layer, "engine_diesel_" .. layer .. ".wav", "moteur diesel, couche " .. layer, LAYERS)
end
for _, layer in { "hum", "whine", "inverter" } do
    sound(
        "engine.electric." .. layer,
        "engine_electric_" .. layer .. ".wav",
        "moteur électrique, couche " .. layer,
        LAYERS
    )
end
for _, effect in { "skid", "wind", "impact", "shift" } do
    sound("effect." .. effect, "effect_" .. effect .. ".wav", "effet " .. effect)
end
for _, ambience in { "city", "suburb", "harbour", "mountain", "countryside", "circuit", "coast", "rain" } do
    sound("ambience." .. ambience, "ambience_" .. ambience .. ".wav", "ambiance " .. ambience)
end
for _, ui in { "info", "warning", "critical", "click" } do
    sound("ui." .. ui, "ui_" .. ui .. ".wav", "signal d'interface " .. ui)
end
for _, station in { "ville", "route", "nuit" } do
    sound("radio." .. station, "radio_" .. station .. ".wav", "boucle musicale originale, station " .. station)
end

-- ======================== Interface ========================
add({
    Id = "ui.theme",
    Category = "Interface",
    Version = "0.7.0",
    Status = "ReadyForReview",
    Variants = { Low = "Identique", Medium = "Identique", High = "Identique" },
    Lod = "Aucun",
    Provenance = ORIGINAL .. " : thème, couleurs et composants dessinés par code (aucune texture)",
    Licence = LICENCE,
    Source = { Kind = "File", Path = "src/client/UI/UITheme.luau" },
    Output = nil,
    RobloxAssetId = nil,
})

AssetManifest.Assets = table.freeze(list)

local byId: { [string]: Asset } = {}
for _, asset in list do
    byId[asset.Id] = asset
end

function AssetManifest.get(id: string): Asset?
    return byId[id]
end

-- Une ressource n'est utilisable en jeu que si elle a un identifiant Roblox réel.
function AssetManifest.playable(id: string): boolean
    local asset = byId[id]
    return asset ~= nil and asset.RobloxAssetId ~= nil
end

-- URL de contenu d'une ressource téléversée ; nil tant qu'aucun identifiant réel n'est déclaré.
function AssetManifest.contentId(id: string): string?
    local asset = byId[id]
    local ref = if asset then asset.RobloxAssetId else nil
    if ref == nil then
        return nil
    end
    return "rbxassetid://" .. string.format("%d", ref)
end

local STATUSES = { Provisional = true, ReadyForReview = true, Validated = true }

-- Contrôle de cohérence (tests) : renvoie la liste des erreurs.
function AssetManifest.validate(assets: { Asset }?): { string }
    local errors = {}
    local seen: { [string]: boolean } = {}
    for _, asset in assets or list do
        if seen[asset.Id] then
            table.insert(errors, "Identifiant en double : " .. asset.Id)
        end
        seen[asset.Id] = true
        if not string.match(asset.Id, "^[a-z]+%.[a-z0-9%._]+$") then
            table.insert(errors, "Identifiant non stable : " .. asset.Id)
        end
        if not STATUSES[asset.Status] then
            table.insert(errors, "Statut inconnu : " .. asset.Id)
        end
        if asset.Status == "Validated" then
            table.insert(errors, "Validation réservée au propriétaire : " .. asset.Id)
        end
        for _, quality in { "Low", "Medium", "High" } do
            if asset.Variants[quality] == nil then
                table.insert(errors, "Variante " .. quality .. " absente : " .. asset.Id)
            end
        end
        if asset.Provenance == "" or asset.Licence == "" or asset.Lod == "" then
            table.insert(errors, "Provenance, licence ou LOD manquant : " .. asset.Id)
        end
        local ref = asset.RobloxAssetId
        if ref ~= nil and (ref <= 0 or ref ~= math.floor(ref)) then
            table.insert(errors, "Identifiant Roblox invalide : " .. asset.Id)
        end
    end
    return errors
end

return table.freeze(AssetManifest)
