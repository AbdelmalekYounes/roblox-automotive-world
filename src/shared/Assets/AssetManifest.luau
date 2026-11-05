--!strict
--[[
    Manifeste des ressources (lot 0.8, §7, direction artistique).

    Chaque ressource a un identifiant STABLE, une catégorie, une version, des
    variantes de qualité, un niveau de détail (LOD), sa provenance, sa licence
    et un statut : Provisional (provisoire), ReadyForReview (prêt à valider) ou
    Validated (validé — réservé au propriétaire ; aucune entrée ne l'est ici).

    Toutes les ressources sont ORIGINALES : géométrie construite par code
    (générateur de carte), sons synthétisés par un script du dépôt.
    Aucun actif Marketplace, aucun emprunt à un autre projet. SEULE EXCEPTION, accordée par le propriétaire
    (lot VEH3D-01, 2026-11-04) : le modèle 3D tiers de la Comète (CC BY 4.0, crédité ; registre
    docs/vehicle-3d/MODELES_TIERS.md), dont les maillages ont été envoyés sur Roblox par le propriétaire.

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
    -- Kit de maillages (VEH3D-01) : identifiants RÉELS des maillages et des textures envoyés par le propriétaire,
    -- relevés dans le gabarit .rbxm (test Lune : la liste est exactement celle du gabarit, rien n'est inventé).
    RobloxAssetIds: { number }?,
    RobloxTextureIds: { number }?,
}

local ORIGINAL = "Original — conçu pour Automotive World"
local LICENCE = "Propriété du projet Automotive World (aucun tiers)"
local WORLD_GENERATOR = "tools/world/build-world.luau"
local AUDIO_GENERATOR = "tools/audio/synth.py"

local list: { Asset } = {}

local function add(asset: Asset)
    table.insert(list, asset)
end

add({
    Id = "vehicle.body.prototype",
    Category = "VehicleBody",
    Version = "0.1.0",
    Status = "Provisional",
    Variants = { Low = "Identique", Medium = "Identique", High = "Identique" },
    Lod = "Aucun (coque de repli si le kit de maillages d'un modèle manque ; lot BASE-01)",
    Provenance = ORIGINAL .. " : coque de prototype des lots 0.1–0.2, générée par code",
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
    Provenance = ORIGINAL .. " : pilotage des optiques (pièces AWLight des kits de maillages) par VehicleLights",
    Licence = LICENCE,
    Source = { Kind = "File", Path = "src/client/World/VehicleLights.luau" },
    Output = nil,
    RobloxAssetId = nil,
})

-- ======================== Carrosserie 3D tierce (lot VEH3D-01) ========================
add({
    Id = "veh.wk_comete.mesh720s",
    Category = "VehicleBody",
    Version = "1.0.0",
    Status = "ReadyForReview",
    Variants = {
        Low = "Maillages complets (6 907 triangles) ; détails masqués au loin",
        Medium = "Identique, détails visibles plus loin",
        High = "Identique",
    },
    Lod = "LOD0 seul ; RenderFidelity automatique ; habitacle, freins et essuie-glaces dans Carrosserie/Details",
    Provenance = "Tiers : « 2017 Mclaren 720s » de _Sheep19 (Sketchfab), CC BY 4.0, modifié (logos retirés, échelle, "
        .. "roues séparées) ; exception du propriétaire, docs/vehicle-3d/MODELES_TIERS.md",
    Licence = "CC BY 4.0 — crédit obligatoire (docs/CREDITS_ACTIFS.md)",
    Source = { Kind = "File", Path = "src/server/Vehicles/MeshKits.luau" },
    Output = "assets/meshkits/Comete720s.rbxm",
    RobloxAssetId = nil,
    RobloxAssetIds = {
        72070150876445,
        73457381515552,
        79005674751505,
        81144738448567,
        81797127978233,
        82291169931257,
        85421020854464,
        87224242574848,
        89081965660812,
        92270039932160,
        93486246899499,
        95185700118311,
        102224824061605,
        102573121267361,
        103640134917186,
        104886086089628,
        106049474235075,
        115446736871757,
        117440140283283,
        118010695887646,
        118695232875609,
        120490569759204,
        124647274463924,
        134599392040709,
        134800284008231,
        135006162692878,
        135244511879645,
        137148103400804,
    },
    RobloxTextureIds = { 76606382409640, 127066032742162, 129807559388443, 130107105284511, 139339087025487 },
})

-- Lot VEH3D-02 : carrosserie de la Brio. Identifiants relevés dans le gabarit importé et envoyé sur Roblox par le
-- propriétaire (assets/meshkits/Brio.rbxm, 2026-11-05) : 27 maillages, 3 textures (pneus, dessous, intérieur).
add({
    Id = "veh.wk_brio.meshmilano95",
    Category = "VehicleBody",
    Version = "1.0.0",
    Status = "ReadyForReview",
    Variants = {
        Low = "Maillages complets (17 865 triangles) ; habitacle, suspension et garnitures masqués au loin",
        Medium = "Identique, détails visibles plus loin",
        High = "Identique",
    },
    Lod = "LOD0 seul ; RenderFidelity automatique ; LOD1 et LOD2 préparés dans le dépôt d'art (non exportés)",
    Provenance = "Tiers : « Milano '95 - Low poly model » de Daniel Zhabotinsky (Sketchfab), CC BY 4.0, modifié "
        .. "(insignes et plaques retirés, optiques et peinture unies, échelle, roues séparées) ; "
        .. "docs/vehicle-3d/MODELES_TIERS.md",
    Licence = "CC BY 4.0 — crédit obligatoire (docs/CREDITS_ACTIFS.md)",
    Source = { Kind = "File", Path = "src/server/Vehicles/MeshKits.luau" },
    Output = "assets/meshkits/Brio.rbxm",
    RobloxAssetId = nil,
    RobloxAssetIds = {
        71187915817689,
        71449144421405,
        73826286061139,
        77052823926801,
        78233288738454,
        80144700231925,
        83220939253261,
        84934317204711,
        95590929903188,
        95927816868970,
        99282151811659,
        100233007228538,
        101904833865320,
        102220743644062,
        103898878648858,
        111588426158913,
        113794880026414,
        119492697275975,
        126732967392834,
        128273499442836,
        128503426060333,
        130551788936349,
        134931851726367,
        135577186490843,
        137134736949346,
        139240039171084,
        139725972931129,
    },
    RobloxTextureIds = { 78670891483304, 93571790330180, 112726640798829 },
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

-- ======================== Audio enregistré (lot AUDIO-01) ========================
-- Brio : boucles tirées du pack « The Dyno Sessions: 190E » (Chippy569, Freesound), CC0 1.0 : domaine public, aucun
-- crédit exigé (registre docs/audio/SONS_TIERS.md). Fichiers produits par tools/audio/engine_loops.py, à écouter
-- puis envoyer sur Roblox par le propriétaire ; aucun identifiant tant que l'envoi n'est pas fait.
local ENGINE_LOOPS = "tools/audio/engine_loops.py"
local function recordedEngine(vehicle: string, name: string, note: string)
    add({
        Id = "audio.engine." .. vehicle .. "." .. name,
        Category = "Audio",
        Version = "1.0.0",
        Status = "Provisional",
        Variants = { Low = "2 couches", Medium = "3 couches", High = "Toutes les couches" },
        Lod = "Atténuation par distance (RollOff) ; aucune lecture sans RobloxAssetId",
        Provenance = "Tiers : pack « The Dyno Sessions: 190E » de Chippy569 (Freesound), CC0, transformé ("
            .. note
            .. ") ; docs/audio/SONS_TIERS.md",
        Licence = "CC0 1.0 (domaine public) — aucun crédit exigé",
        Source = { Kind = "File", Path = ENGINE_LOOPS },
        Output = "build/audio/engines/" .. vehicle .. "/" .. name .. ".wav",
        RobloxAssetId = nil,
    })
end
for _, rpm in { 1000, 1300, 1700, 2200, 2900, 3800, 4900, 6300 } do
    recordedEngine("brio", "on." .. rpm, "boucle en charge à " .. rpm .. " tr/min")
    recordedEngine("brio", "off." .. rpm, "boucle en décharge à " .. rpm .. " tr/min")
end
recordedEngine("brio", "start", "démarrage")
recordedEngine("brio", "stop", "arrêt")
recordedEngine("brio", "stall", "calage")

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

-- Lot UI-02 : 12 icônes du téléphone (une entrée par icône). Identifiants d'IMAGE réels (type 1), envoyés par le
-- propriétaire le 2026-11-05 (décalques importés sur create.roblox.com, convertis en images par la barre de
-- commande de Studio) ; type, nom (« <App>_128 ») et créateur vérifiés sur l'API publique economy.roblox.com.
local PHONE_ICON_IDS: { [string]: number } = {
    Map = 139759611688719,
    Vehicles = 75819885655066,
    Properties = 86911212052819,
    Missions = 123109347713390,
    Races = 135512154723543,
    Market = 79661493327089,
    Social = 104529493537486,
    Radio = 97090714931696,
    Photo = 124133194296037,
    Guide = 78344066959818,
    Settings = 117473178109905,
    Notifications = 77842663800346,
}
AssetManifest.PhoneIconIds = table.freeze(PHONE_ICON_IDS)

for _, appName in
    {
        "Map",
        "Vehicles",
        "Properties",
        "Missions",
        "Races",
        "Market",
        "Social",
        "Radio",
        "Photo",
        "Guide",
        "Settings",
        "Notifications",
    }
do
    add({
        Id = "ui.icon.phone." .. string.lower(appName), -- identifiants stables : minuscules
        Category = "Interface",
        Version = "1.2.0",
        Status = "ReadyForReview",
        Variants = { Low = "PNG 64 px", Medium = "PNG 64 px", High = "PNG 128 px" },
        Lod = "Aucun",
        Provenance = ORIGINAL
            .. " : icône de la maquette V1.2 du propriétaire (tracé SVG de Smartphone.dc.html), rastérisée en PNG "
            .. "blanc teinté dans le jeu (script de Source) ; envoyée sur Roblox par le propriétaire (version 128 px)",
        Licence = LICENCE,
        Source = { Kind = "File", Path = "tools/ui/make_phone_icons.py" },
        Output = "assets/ui/icons/" .. appName .. "_128.png",
        RobloxAssetId = PHONE_ICON_IDS[appName],
    })
end

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
