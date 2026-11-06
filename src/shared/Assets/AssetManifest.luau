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
        Low = "Maillages complets (10 322 triangles depuis ANIM-02, portières) ; détails masqués au loin",
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
        -- Lot ANIM-01 (2026-11-06) : volant séparé de l'habitacle, importé et envoyé sur Roblox par le propriétaire
        -- (aw-vm-exchange/comete_volant.rbxm) : COMETE_Habitacle_interior sans volant (77774849215644, remplace
        -- 106049474235075) et COMETE_Volant (90303387073911). Texture de l'habitacle d'origine reprise.
        -- Lot ANIM-02 (2026-11-06) : portières séparées, importées et envoyées sur Roblox par le propriétaire
        -- (aw-vm-exchange/anim02_comete_portes.rbxm) : 5 pièces fixes retouchées (caisse body, carbon_fibre,
        -- black_metallic, habitacle, vitrage) et 16 pièces de portes ; anciens rétroviseurs retirés. Textures
        -- d'origine reprises (aucune nouvelle texture).
        71646288492754,
        72070150876445,
        73457381515552,
        75102548803545,
        75254387978417,
        79005674751505,
        81144738448567,
        82291169931257,
        85421020854464,
        87224242574848,
        89081965660812,
        89363770429394,
        90303387073911,
        92270039932160,
        93486246899499,
        95185700118311,
        100299226492980,
        103640134917186,
        104318596933935,
        104886086089628,
        105904130882526,
        109618700529273,
        109864477581029,
        115446736871757,
        116405074821636,
        118010695887646,
        119126686214798,
        119217702550973,
        119335927911511,
        120469497106417,
        120490569759204,
        122480999372220,
        124647274463924,
        125682253717634,
        127843908922685,
        129663850009537,
        130478903885996,
        134800284008231,
        135244511879645,
        135265193095708,
        137148103400804,
        137753391393791,
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
        Low = "Maillages complets (18 661 triangles depuis ANIM-02, portières) ; habitacle, suspension et garnitures "
            .. "masqués au loin",
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
        -- Lot ANIM-02 (2026-11-06) : portières séparées (aw-vm-exchange/anim02_brio_portes.rbxm) : caisse,
        -- habitacle et soubassement retouchés, 6 pièces de portes. Textures d'origine reprises.
        71187915817689,
        71344605284183,
        71449144421405,
        73826286061139,
        77489935120802,
        78233288738454,
        83220939253261,
        84934317204711,
        86912421664584,
        93978342506603,
        95590929903188,
        95927816868970,
        99282151811659,
        100233007228538,
        101904833865320,
        102070349929771,
        102220743644062,
        103898878648858,
        105155625934631,
        111588426158913,
        113794880026414,
        116798611842126,
        117249973043570,
        119492697275975,
        126732967392834,
        128273499442836,
        128503426060333,
        130551788936349,
        131656366452283,
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
-- crédit exigé (registre docs/audio/SONS_TIERS.md). Fichiers produits par tools/audio/engine_loops.py (variante
-- « moteur », validée à l'écoute par le propriétaire le 2026-11-05).
local ENGINE_LOOPS = "tools/audio/engine_loops.py"
-- Identifiants des sons ENVOYÉS SUR ROBLOX PAR LE PROPRIÉTAIRE (importation groupée de Studio, 2026-11-06), relevés
-- par Lune dans son fichier aw-vm-exchange/brio_sound.rbxm (19 objets Sound, propriété AudioContent) : seuls
-- identifiants audio déclarés au manifeste ; aucun n'est inventé (contrôle pytest : table exacte).
local BRIO_ENGINE_SOUND_IDS: { [string]: number } = {
    ["on.1000"] = 100316175913759,
    ["on.1300"] = 71805665589957,
    ["on.1700"] = 113780474099124,
    ["on.2200"] = 88489584332634,
    ["on.2900"] = 139847748681292,
    ["on.3800"] = 132071504297109,
    ["on.4900"] = 132995478418521,
    ["on.6300"] = 133027765625226,
    ["off.1000"] = 126024686217376,
    ["off.1300"] = 90633302806466,
    ["off.1700"] = 106378654172632,
    ["off.2200"] = 72650990038478,
    ["off.2900"] = 85091116230984,
    ["off.3800"] = 108314634619106,
    ["off.4900"] = 132177207806274,
    ["off.6300"] = 118288604588883,
    ["start"] = 119200249015180,
    ["stop"] = 119630608706700,
    ["stall"] = 118745681759489,
}
AssetManifest.BrioEngineSoundIds = table.freeze(BRIO_ENGINE_SOUND_IDS)
local function recordedEngine(vehicle: string, name: string, note: string)
    add({
        Id = "audio.engine." .. vehicle .. "." .. name,
        Category = "Audio",
        Version = "1.0.0",
        Status = "ReadyForReview",
        Variants = { Low = "2 couches", Medium = "3 couches", High = "Toutes les couches" },
        Lod = "Atténuation par distance (RollOff) ; aucune lecture sans RobloxAssetId",
        Provenance = "Tiers : pack « The Dyno Sessions: 190E » de Chippy569 (Freesound), CC0, transformé ("
            .. note
            .. ") ; docs/audio/SONS_TIERS.md",
        Licence = "CC0 1.0 (domaine public) — aucun crédit exigé",
        Source = { Kind = "File", Path = ENGINE_LOOPS },
        Output = "build/audio/engines/" .. vehicle .. "/moteur/" .. name .. ".wav",
        RobloxAssetId = if vehicle == "brio" then BRIO_ENGINE_SOUND_IDS[name] else nil,
    })
end
for _, rpm in { 1000, 1300, 1700, 2200, 2900, 3800, 4900, 6300 } do
    recordedEngine("brio", "on." .. rpm, "boucle en charge à " .. rpm .. " tr/min")
    recordedEngine("brio", "off." .. rpm, "boucle en décharge à " .. rpm .. " tr/min")
end
recordedEngine("brio", "start", "démarrage")
recordedEngine("brio", "stop", "arrêt")
recordedEngine("brio", "stall", "calage")

-- ======================== Audio enregistré (lot AUDIO-03 : pneus) ========================
-- Boucles des pneus (TireAudioModel), tirées d'enregistrements libres de Freesound (CC0) relevés au registre
-- docs/audio/SONS_TIERS.md (§ pneus) et transformées par tools/audio/tire_loops.py. Catégorie « Effets » (préfixe
-- audio.effect.). Validées à l'écoute par le propriétaire le 2026-11-06.
local TIRE_LOOPS = "tools/audio/tire_loops.py"
-- Identifiants des sons ENVOYÉS SUR ROBLOX PAR LE PROPRIÉTAIRE (importation groupée de Studio, 2026-11-06), relevés
-- par Lune dans son fichier aw-vm-exchange/audio03_pneus.rbxm (6 objets Sound « tire_<nom> », propriété AudioContent) ;
-- aucun n'est inventé (contrôle pytest : table exacte).
local TIRE_SOUND_IDS: { [string]: number } = {
    ["roll.dry"] = 90291890857090,
    ["roll.loose"] = 79688428452888,
    ["roll.wet"] = 109725784350976,
    ["squeal"] = 108267751330014,
    ["scrub"] = 79292953985747,
    ["slide.loose"] = 112587939989359,
}
AssetManifest.TireSoundIds = table.freeze(TIRE_SOUND_IDS)
local function recordedTire(name: string, note: string)
    add({
        Id = "audio.effect.tire." .. name,
        Category = "Audio",
        Version = "1.0.0",
        Status = "ReadyForReview",
        Variants = { Low = "2 couches", Medium = "4 couches", High = "Toutes les couches" },
        Lod = "Atténuation par distance (RollOff) ; aucune lecture sans RobloxAssetId",
        Provenance = "Tiers : enregistrements CC0 de Freesound, transformés ("
            .. note
            .. ") ; docs/audio/SONS_TIERS.md",
        Licence = "CC0 1.0 (domaine public) — aucun crédit exigé",
        Source = { Kind = "File", Path = TIRE_LOOPS },
        Output = "build/audio/tires/" .. name .. ".wav",
        RobloxAssetId = TIRE_SOUND_IDS[name],
    })
end
recordedTire("roll.dry", "roulement sur revêtement dur")
recordedTire("roll.loose", "roulement sur gravier et terre")
recordedTire("roll.wet", "chuintement sur chaussée mouillée")
recordedTire("squeal", "crissement de glissement")
recordedTire("scrub", "frottement de glissade franche")
recordedTire("slide.loose", "glissade sur gravier")

-- ======================== Audio enregistré (lot AUDIO-04 : collisions) ========================
-- Chocs, bris d'optique et raclement (CollisionAudioModel), tirés d'enregistrements libres de Freesound (CC0) relevés
-- au registre docs/audio/SONS_TIERS.md (§ collisions) et transformés par tools/audio/collision_sounds.py. Catégorie
-- « Effets » (préfixe audio.effect.). Validés à l'écoute par le propriétaire le 2026-11-06.
local COLLISION_SOUNDS = "tools/audio/collision_sounds.py"
-- Identifiants des sons ENVOYÉS SUR ROBLOX PAR LE PROPRIÉTAIRE (importation groupée de Studio, 2026-11-06), relevés
-- par Lune dans son fichier aw-vm-exchange/audio04_collisions.rbxm (7 objets Sound « collision_<nom> », propriété
-- AudioContent) ; aucun n'est inventé (contrôle pytest : table exacte).
local COLLISION_SOUND_IDS: { [string]: number } = {
    ["hard.light"] = 119936631540140,
    ["hard.heavy"] = 84821488985222,
    ["object"] = 107111383496078,
    ["vehicle.light"] = 73753197716718,
    ["vehicle.heavy"] = 103306869584523,
    ["glass"] = 73806268842632,
    ["scrape"] = 126532496130819,
}
AssetManifest.CollisionSoundIds = table.freeze(COLLISION_SOUND_IDS)
local function recordedCollision(name: string, note: string)
    add({
        Id = "audio.effect.collision." .. name,
        Category = "Audio",
        Version = "1.0.0",
        Status = "ReadyForReview",
        Variants = { Low = "Identique", Medium = "Identique", High = "Identique" },
        Lod = "Atténuation par distance (RollOff) ; aucune lecture sans RobloxAssetId",
        Provenance = "Tiers : enregistrements CC0 de Freesound, transformés ("
            .. note
            .. ") ; docs/audio/SONS_TIERS.md",
        Licence = "CC0 1.0 (domaine public) — aucun crédit exigé",
        Source = { Kind = "File", Path = COLLISION_SOUNDS },
        Output = "build/audio/collisions/" .. name .. ".wav",
        RobloxAssetId = COLLISION_SOUND_IDS[name],
    })
end
recordedCollision("hard.light", "petit choc contre le décor")
recordedCollision("hard.heavy", "choc violent contre le décor")
recordedCollision("object", "choc contre un objet léger")
recordedCollision("vehicle.light", "petit choc entre véhicules")
recordedCollision("vehicle.heavy", "choc violent entre véhicules")
recordedCollision("glass", "bris d'optique")
recordedCollision("scrape", "raclement de carrosserie, boucle")

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

-- Lot PNJ-01 : carrosseries des 10 voitures PNJ. Identifiants relevés dans le gabarit importé et envoyé sur Roblox par
-- le propriétaire (aw-vm-exchange/pnj01_kits.rbxm, 2026-11-06), mis au format du contrat par
-- tests/lune/tools/pnj01-kits.luau ; aucune texture (matériaux unis, couleurs réappliquées par le jeu).
table.insert(list, {
    Id = "world.pnj.cars",
    Category = "VehicleBody",
    Version = "1.0.0",
    Status = "ReadyForReview",
    Variants = {
        Low = "10 voitures d'environ 2 000 triangles, sans texture",
        Medium = "Identique",
        High = "Identique",
    },
    Lod = "LOD0 seul ; RenderFidelity automatique ; voitures matérialisées seulement près des joueurs (TrafficService)",
    Provenance = "Tiers : « Generic passenger car pack » de Comrade1280 (Sketchfab), CC BY 4.0, modifié (textures "
        .. "retirées, matériaux unis classés, réduction, pièces renommées) ; dépôt d'art vehicles/pnj/README.md",
    Licence = "CC BY 4.0 — crédit obligatoire (docs/CREDITS_ACTIFS.md)",
    Source = { Kind = "File", Path = "src/server/World/TrafficBodies.luau" },
    Output = "assets/pnjkits/AutomotiveWorldPnjKits.rbxm",
    RobloxAssetId = nil,
    RobloxAssetIds = {
        71004563601515,
        71243450157029,
        71533556919824,
        72509758990757,
        72729237716704,
        73257430804095,
        73335972430803,
        73390960753457,
        73512924854308,
        73779158984979,
        74410479410600,
        75260459975310,
        75797572278868,
        75963593717178,
        76168888055928,
        76608396779159,
        76724765326126,
        76736023827009,
        76965245998885,
        77338514126090,
        77787415687503,
        77919751210066,
        78120955242349,
        78122885879997,
        78205975790551,
        78324532940261,
        79244184985272,
        79325780409305,
        79965290653372,
        80336072403658,
        80496546139238,
        81415495090910,
        82172762530973,
        83334806513809,
        83414522122881,
        83867093384836,
        84198094737188,
        85133854343618,
        85354009515178,
        85447242049661,
        85735853703416,
        86463405876030,
        86777172324079,
        87352804357369,
        88933346008350,
        89221550031221,
        89266652326351,
        89540238408311,
        89677812903136,
        89761714223614,
        90012496925138,
        90022972228017,
        91028951154114,
        91227515388069,
        92228034792770,
        92346989168593,
        92399441809339,
        92592591339692,
        92854729993747,
        92936928961024,
        93028483146373,
        93331936949605,
        93840191572217,
        94192611674791,
        94269762886541,
        94288551916204,
        94910440424186,
        95249694382027,
        95336973765388,
        95493318337212,
        95517326677098,
        95586287526318,
        95683684329744,
        95816111565972,
        95910120654042,
        96294659800308,
        96307234835115,
        96338030545580,
        96555115444785,
        96562365334583,
        97112721199674,
        97822937444679,
        97866487607246,
        97931396530352,
        98367104007360,
        98499894432170,
        98823614632078,
        99281779769708,
        99302747046560,
        99690260463818,
        101047267364741,
        101471898296829,
        102235491654859,
        102838192528040,
        103442264757390,
        103450115439716,
        103560974450987,
        103617594614489,
        103747135611163,
        104097250128805,
        104355075032806,
        105436882982653,
        105573610440517,
        105902165666219,
        106013171679013,
        106846713244002,
        107057847211144,
        107124753468579,
        107127989343473,
        107669624436925,
        107840336783702,
        108793701599835,
        109705785372605,
        109839448041668,
        110215143827868,
        110354389686140,
        110446602288305,
        110471698313410,
        111642662239450,
        111886839604345,
        112323638278326,
        112363858026694,
        112418574750570,
        112911559848048,
        113545745882612,
        113575546887235,
        113610114848011,
        113682823433923,
        114178267669671,
        114246279329099,
        114620001385005,
        114815311594334,
        115298764847473,
        115300275413821,
        115952552009293,
        116056801976326,
        116828187359532,
        117350341762396,
        117796699763811,
        117830934788286,
        117843835392932,
        117911897242280,
        118066072011801,
        118244561941514,
        118381824373930,
        118500414588904,
        118883100420775,
        120124988744194,
        120283824681889,
        120327100937922,
        120363133605339,
        120599078201036,
        120776829149314,
        121079314655518,
        122113913241312,
        122378169820854,
        123176647330258,
        123265370020076,
        124528208354259,
        125127698894854,
        125776014475260,
        125776885708727,
        125885024060900,
        125976547367143,
        126188348569054,
        126550134366299,
        127256101164199,
        127400413145395,
        127659583338706,
        127662371048345,
        127725810475810,
        128053497232807,
        128134172885858,
        128208306907748,
        128432834937253,
        128848623053431,
        129417785071701,
        129664400874255,
        129756763956945,
        130023539190972,
        130254710062831,
        130927417646119,
        131062805289872,
        132060444868189,
        132070676233846,
        132087372980119,
        132088370437697,
        132644759461694,
        132784542167856,
        132863471142632,
        133663667246846,
        135420124994526,
        135838376169110,
        136360729292017,
        136500872288671,
        136558933885191,
        136808968458107,
        137341121404419,
        137987907405324,
        138541525098329,
        139070994941969,
        139705702847396,
        139877214702904,
        140235182436871,
        140566857729916,
    },
})

-- Lot PNJ-01 : piétons (18 personnages découpés en 11 pièces) et 12 plaques porteuses des palettes de couleurs.
-- Identifiants relevés dans le gabarit importé et envoyé sur Roblox par le propriétaire
-- (aw-vm-exchange/pnj_pietons.rbxm, 2026-11-06) par tests/lune/tools/pnj01-kits.luau.
table.insert(list, {
    Id = "world.pnj.pedestrians",
    Category = "WorldDecor",
    Version = "1.0.0",
    Status = "ReadyForReview",
    Variants = {
        Low = "18 personnages d'environ 1 150 triangles, palette 64 px (12 variantes de couleurs)",
        Medium = "Identique",
        High = "Identique",
    },
    Lod = "LOD0 seul ; piétons rendus par chaque client près de la caméra seulement (World/Pedestrians)",
    Provenance = "Tiers : « Low Poly People » de David Jalbert (itch.io), CC BY 4.0, modifié (pose, découpage en "
        .. "pièces, variantes de couleurs) ; dépôt d'art vehicles/pnj/README.md",
    Licence = "CC BY 4.0 — crédit obligatoire (docs/CREDITS_ACTIFS.md)",
    Source = { Kind = "File", Path = "src/client/World/Pedestrians.luau" },
    Output = "assets/pnjkits/AutomotiveWorldPnjKits.rbxm",
    RobloxAssetId = nil,
    RobloxAssetIds = {
        70395108996552,
        70990060899801,
        72194988607191,
        73002219136025,
        73014140050643,
        73939401475523,
        74125641824727,
        74227465860627,
        74399959027881,
        75063750163986,
        76214837810096,
        76332500701900,
        76506304065242,
        77270030737170,
        77579453392172,
        77886274559909,
        77886637288701,
        78022713599108,
        78119211311735,
        78244935766084,
        78271834414686,
        78793679705439,
        79746667756286,
        80239178460985,
        80973220319133,
        81567806178456,
        82053241137256,
        82610335940125,
        82671548720506,
        82796297769527,
        82844959426280,
        82885054144577,
        82955491567726,
        82979619052052,
        83152087165459,
        83195720200817,
        83423978638280,
        83852571958179,
        84116165940827,
        84606694788305,
        84902525044469,
        85130404055674,
        85276435110792,
        85422027377708,
        86042598341970,
        86234334374442,
        87042777130411,
        87122512330918,
        87247608108860,
        87265434091203,
        87406004401156,
        87434420765643,
        87587266837504,
        88107729899801,
        88334060099058,
        88375545161702,
        88813760100251,
        89779184060062,
        89977876337582,
        90665368012669,
        91556194933525,
        91593777183947,
        91644840679452,
        91719232491529,
        91794593852247,
        91944244302276,
        92488738021041,
        92654605887649,
        93318510755144,
        93831814856702,
        94873360017395,
        95440838319211,
        95686038206523,
        95706969625472,
        96230103822159,
        96323950608030,
        96404654833276,
        96892640990310,
        97231955464150,
        97250911970747,
        97432161195680,
        97783043122974,
        98347392762761,
        98533866466383,
        98634511902839,
        98960825342755,
        99010634454772,
        99416009376191,
        99790683407651,
        100169467806468,
        100451106033442,
        100656268226072,
        100733703975697,
        102152699160521,
        102283635963918,
        102713009768888,
        102940719345518,
        102983420551602,
        103017264461282,
        103667621349627,
        103930106059755,
        104950619559621,
        105042339763655,
        105075063040802,
        105188451000429,
        105898692858228,
        106136760555512,
        106423903635890,
        107014009346115,
        107273884312451,
        107728851471578,
        107749826518416,
        108869787082783,
        108882410353932,
        109951378410964,
        110752107797694,
        111175646013903,
        111252941487073,
        111363789537674,
        111530626598653,
        111962683570611,
        112454546285452,
        112524074178219,
        112758893974822,
        113063624377373,
        113616871145897,
        113821198864758,
        113849367176339,
        113937952858288,
        114203216512344,
        114287628918553,
        114660917363147,
        114846258820866,
        115358340414495,
        115415790801563,
        115438315829661,
        115664945268779,
        116384356541423,
        118020446664964,
        118246552112608,
        118483479163847,
        118532151652296,
        119452882430856,
        119483853289968,
        119654416107186,
        119770196510045,
        119932324059743,
        120245652497607,
        120374178912672,
        120667892472482,
        120812922179418,
        121319189663609,
        121628610927044,
        121746941204632,
        121883371902980,
        122670488143251,
        122795462839489,
        124146956908865,
        124243760364578,
        124391299244397,
        124432682124160,
        124522536113448,
        125281722612985,
        125812128681777,
        125882930681710,
        125933929460019,
        126668047203011,
        127024638449146,
        127105527781558,
        127359818662442,
        128440261894318,
        128870958631919,
        129848165802540,
        129878205945908,
        130098604003553,
        130343445983608,
        130447638726972,
        130592883153712,
        130624955659028,
        130950427977043,
        131158880507804,
        131286147669360,
        132268342363245,
        132510374057630,
        132785910589325,
        132963989352483,
        132987040036211,
        133380645741735,
        133408212951894,
        133926369309521,
        134488882519627,
        134742267217162,
        135716960733583,
        135990744382425,
        136141320430338,
        136413172637353,
        136443951998522,
        136532728332273,
        136570058824238,
        136920699919529,
        137750886851172,
        138711546461223,
        138745253170150,
        139130829824334,
        139577691785746,
        139851652073209,
        140016538332407,
        140242764939509,
        140530534376607,
        140616631114566,
    },
    -- Palettes : 12 plaques porteuses + la copie de la palette d'origine de chaque personnage (une par import).
    RobloxTextureIds = {
        73967069037648,
        77127869203059,
        78337169551936,
        82083169082046,
        83752232878288,
        84502275780666,
        89793892477913,
        94478743314845,
        98222531658635,
        100085862626709,
        101868818609140,
        103565007694265,
        106364943987045,
        109845017608815,
        112218929469465,
        115112791719514,
        116494909856282,
        116905482351308,
        119995092452890,
        120486216845842,
        120708600675239,
        124289753332336,
        126658178616589,
        132401698716712,
        132549877177003,
        138158865512752,
        139170242981056,
        139642051078655,
        139646184726119,
        139823845463339,
    },
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
