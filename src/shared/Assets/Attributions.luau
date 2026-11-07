--!strict
--[[
    Attributions des œuvres de tiers affichées dans le jeu (lot VEH3D-01, licence CC BY 4.0). Module PUR : lu par
    l'écran « Crédits et licences » du téléphone et vérifié par Lune contre le manifeste (toute entrée « CC BY » du
    manifeste doit avoir son attribution).

    CC BY 4.0 (§3.a) : nom de l'auteur, mention de la licence (avec son adresse dans la mesure du raisonnable), lien
    vers l'œuvre dans la mesure du raisonnable, indication des modifications. Le titre de l'œuvre et son lien
    contiennent un nom de marque, et un lien externe affiché dans une expérience Roblox est encadré par les règles de la
    plateforme : leur affichage en jeu (`ShowTitle`, `ShowUrl`) est une DÉCISION DU PROPRIÉTAIRE, reportée (« plus
    tard », masqués d'ici là : docs/vehicle-3d/VEH3D_01_REVUE.md, VEH3D_01_CLOTURE.md §3.F). Le texte complet reste dans docs/CREDITS_ACTIFS.md.
    Textes affichés par clé de localisation (FR, EN).
]]

export type Attribution = {
    ManifestId: string, -- entrée de `Shared.Assets.AssetManifest`
    UsageKey: string, -- clé : à quoi sert l'œuvre dans le jeu
    ChangesKey: string, -- clé : modifications apportées
    Creator: string, -- nom de l'auteur tel que publié
    Source: string, -- plateforme d'origine
    Licence: string, -- nom court de la licence
    LicenceUrl: string,
    Title: string, -- titre publié par l'auteur
    Url: string, -- page de l'œuvre
    ShowTitle: boolean,
    ShowUrl: boolean,
    -- Lot AUDIO-02 : préfixe des entrées du manifeste couvertes par cette attribution (une œuvre, plusieurs sons :
    -- boucles du moteur de la Comète). `ManifestId` reste une entrée réelle du préfixe.
    ManifestPrefix: string?,
}

local Attributions = {}

Attributions.List = table.freeze({
    table.freeze({
        ManifestId = "veh.wk_comete.mesh720s",
        UsageKey = "credits.usage.comete",
        ChangesKey = "credits.changes.comete",
        Creator = "_Sheep19",
        Source = "Sketchfab",
        Licence = "CC BY 4.0",
        LicenceUrl = "creativecommons.org/licenses/by/4.0",
        Title = "2017 Mclaren 720s",
        Url = "https://sketchfab.com/3d-models/2017-mclaren-720s-f7bece69400f4640a4a3be746b44998b",
        ShowTitle = false,
        ShowUrl = false,
    } :: Attribution),
    -- Lot VEH3D-02 : carrosserie de la Brio (licence.txt du modèle, 2026-11-05).
    table.freeze({
        ManifestId = "veh.wk_brio.meshmilano95",
        UsageKey = "credits.usage.brio",
        ChangesKey = "credits.changes.brio",
        Creator = "Daniel Zhabotinsky",
        Source = "Sketchfab",
        Licence = "CC BY 4.0",
        LicenceUrl = "creativecommons.org/licenses/by/4.0",
        Title = "Milano '95 - Low poly model",
        Url = "https://sketchfab.com/3d-models/milano-95-low-poly-model-122a22d210234596ad23623588d0d166",
        ShowTitle = false,
        ShowUrl = false,
    } :: Attribution),
    -- Lot AUDIO-02 : moteur de la Comète, pack « V8 Lotus » (Freesound, CC BY 4.0, licence relevée sur la page de chaque
    -- son le 2026-11-06). Le titre contient un nom de marque : masqué comme les précédents (décision reportée).
    table.freeze({
        ManifestId = "audio.engine.comete.on.900",
        ManifestPrefix = "audio.engine.comete.",
        UsageKey = "credits.usage.comete_moteur",
        ChangesKey = "credits.changes.comete_moteur",
        Creator = "wikusv",
        Source = "Freesound",
        Licence = "CC BY 4.0",
        LicenceUrl = "creativecommons.org/licenses/by/4.0",
        Title = "V8 Lotus (Idle, Idle and Rev - Engine, Rev and Pull)",
        Url = "https://freesound.org/people/wikusv/sounds/232272/",
        ShowTitle = false,
        ShowUrl = false,
    } :: Attribution),
    -- Lot PNJ-01 : voitures PNJ (licence.txt du pack, 2026-11-06).
    table.freeze({
        ManifestId = "world.pnj.cars",
        UsageKey = "credits.usage.pnj_cars",
        ChangesKey = "credits.changes.pnj_cars",
        Creator = "Comrade1280",
        Source = "Sketchfab",
        Licence = "CC BY 4.0",
        LicenceUrl = "creativecommons.org/licenses/by/4.0",
        Title = "Generic passenger car pack",
        Url = "https://sketchfab.com/3d-models/generic-passenger-car-pack-20f9af9b8a404d5cb022ac6fe87f21f5",
        ShowTitle = false,
        ShowUrl = false,
    } :: Attribution),
    -- Lot PNJ-01 : piétons (page itch.io du pack, licence CC BY 4.0, 2026-11-06).
    table.freeze({
        ManifestId = "world.pnj.pedestrians",
        UsageKey = "credits.usage.pnj_pedestrians",
        ChangesKey = "credits.changes.pnj_pedestrians",
        Creator = "David Jalbert",
        Source = "itch.io",
        Licence = "CC BY 4.0",
        LicenceUrl = "creativecommons.org/licenses/by/4.0",
        Title = "Low Poly People",
        Url = "https://davidjalbert.itch.io/low-poly-people",
        ShowTitle = false,
        ShowUrl = false,
    } :: Attribution),
} :: { Attribution })

-- Attribution d'une entrée du manifeste, ou nil.
function Attributions.forManifest(manifestId: string): Attribution?
    for _, entry in Attributions.List do
        if entry.ManifestId == manifestId then
            return entry
        end
        local prefix = entry.ManifestPrefix
        if prefix and string.sub(manifestId, 1, #prefix) == prefix then
            return entry
        end
    end
    return nil
end

return table.freeze(Attributions)
