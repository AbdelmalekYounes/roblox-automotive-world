--!strict
--[[
    Identité du jeu (lot BRAND-01), module PUR : testé par Lune.

    Nom choisi par le propriétaire le 2026-11-06 : « Amberline ». « Automotive World » reste le nom TECHNIQUE du code
    (dossiers, projets Rojo, attributs) : il n'est pas renommé sans accord du propriétaire.

    Ce module vit dans ReplicatedFirst (dossier `src/first`) : l'écran de chargement s'affiche AVANT que
    ReplicatedStorage soit répliqué, il ne peut donc pas lire `Shared.UI.DesignTokens` ni `Shared.Assets.AssetManifest`.
    Les quelques valeurs nécessaires sont recopiées ici ; un test Lune vérifie qu'elles restent ÉGALES à la charte et
    au manifeste (aucune divergence silencieuse).

    Logo : piste « Virage » (route ambre en S vue du dessus + mot en Titillium Web Bold), sources dans le dépôt d'art
    privé (brands/amberline/virage). Tant que le propriétaire n'a pas envoyé l'image sur Roblox, son identifiant vaut
    nil et l'écran affiche le titre en texte seul (repli).
]]

local Brand = {}

-- Nom affiché du jeu (nom propre : identique en français et en anglais, non traduit).
Brand.Name = "Amberline"

-- Identifiants d'image RÉELS envoyés par le propriétaire (aucun n'est inventé). Table exacte contrôlée par pytest
-- (tests/test_brand01.py) et égale à l'entrée `ui.brand.logo` du manifeste (test Lune).
local BRAND_IMAGE_IDS: { [string]: number } = {
    -- Logo « Virage » 1024 × 256, envoyé par le propriétaire le 2026-11-06 (Gestionnaire des contenus de Studio,
    -- type Image, créateur Akroniik), relevé sur sa capture d'écran.
    logo = 100100722438691,
}

-- Proportions du logo exporté (1024 × 256 px) : largeur / hauteur.
Brand.LogoAspect = 4

-- Couleurs de la charte UI V1.2 utilisées par l'écran de chargement (copie de DesignTokens.Colors, vérifiée).
Brand.Colors = table.freeze({
    BgBase = Color3.fromRGB(14, 15, 17),
    BgChrome = Color3.fromRGB(18, 20, 22),
    Surface2 = Color3.fromRGB(30, 33, 37),
    Text = Color3.fromRGB(236, 234, 230),
    TextMuted = Color3.fromRGB(163, 162, 156),
    Amber = Color3.fromRGB(232, 163, 61),
} :: { [string]: Color3 })

-- Famille de la charte (Titillium Web, SIL OFL 1.1, livrée avec Roblox).
Brand.FontFamily = "TitilliumWeb"

-- Identifiant Roblox du logo, ou nil s'il n'est pas encore envoyé.
function Brand.logoImageId(): number?
    return BRAND_IMAGE_IDS.logo
end

-- Contenu d'image du logo (« rbxassetid://… »), ou nil.
function Brand.logoContent(): string?
    local id = Brand.logoImageId()
    if id == nil then
        return nil
    end
    return "rbxassetid://" .. string.format("%d", id)
end

-- Copie de la table (tests) : on ne rend jamais la table interne modifiable.
function Brand.imageIds(): { [string]: number }
    return table.clone(BRAND_IMAGE_IDS)
end

--[[
    Choix du titre affiché. `imageState` : état du chargement de l'image du logo.
      - "None"    : aucun identifiant (image pas encore envoyée) ;
      - "Pending" : chargement en cours ;
      - "Loaded"  : image chargée ;
      - "Failed"  : échec ou délai dépassé (identifiant refusé, image modérée, réseau).
    Renvoie "Image" seulement quand l'image est réellement chargée : jamais de cadre vide à l'écran ; en attente ou
    en échec, le titre est écrit en texte.
]]
export type ImageState = "None" | "Pending" | "Loaded" | "Failed"
function Brand.titleMode(imageState: ImageState): "Image" | "Text"
    return if imageState == "Loaded" then "Image" else "Text"
end

-- Délai maximal d'attente de l'image du logo (s) avant de garder le titre en texte.
Brand.LogoWaitSeconds = 4

return table.freeze(Brand)
