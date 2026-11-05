--!strict
--[[
    Attributions des œuvres de tiers affichées dans le jeu (lot VEH3D-01, licence CC BY 4.0). Module PUR : lu par
    l'écran « Crédits et licences » du téléphone et vérifié par Lune contre le manifeste (toute entrée « CC BY » du
    manifeste doit avoir son attribution).

    CC BY 4.0 (§3.a) : nom de l'auteur, mention de la licence (avec son adresse dans la mesure du raisonnable), lien
    vers l'œuvre dans la mesure du raisonnable, indication des modifications. Le titre de l'œuvre et son lien
    contiennent un nom de marque, et un lien externe affiché dans une expérience Roblox est encadré par les règles de la
    plateforme : leur affichage en jeu (`ShowTitle`, `ShowUrl`) est une DÉCISION DU PROPRIÉTAIRE, faux tant qu'elle
    n'est pas prise (docs/vehicle-3d/VEH3D_01_FINALISATION.md). Le texte complet reste dans docs/CREDITS_ACTIFS.md.
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
} :: { Attribution })

-- Attribution d'une entrée du manifeste, ou nil.
function Attributions.forManifest(manifestId: string): Attribution?
    for _, entry in Attributions.List do
        if entry.ManifestId == manifestId then
            return entry
        end
    end
    return nil
end

return table.freeze(Attributions)
