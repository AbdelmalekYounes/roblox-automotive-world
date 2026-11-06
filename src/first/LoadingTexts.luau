--!strict
--[[
    Textes de l'écran de chargement (lot BRAND-01), module PUR : testé par Lune.

    Même principe que `Shared.UI.Localization` (une CLÉ, une entrée { fr, en }, langues alignées), mais dans
    ReplicatedFirst : ces textes doivent être lisibles avant la réplication de ReplicatedStorage, donc avant que la
    localisation centrale et les préférences du joueur (langue choisie) soient disponibles. La langue est déduite de
    la langue du compte Roblox (`Player.LocaleId`) : français si elle commence par « fr », anglais sinon.
    Un test Lune vérifie qu'aucune de ces clés n'existe déjà dans la localisation centrale (pas de doublon divergent).

    Phrase d'accueil fixe (choix du propriétaire, 2026-11-06) : pas de conseils tournants.
]]

local LoadingTexts = {}

export type Language = "fr" | "en"

local E: { [string]: { string } } = {
    ["loading.welcome"] = { "Bienvenue à Valcourt", "Welcome to Valcourt" },
    -- Étape en cours, sous la barre de progression (une par attente réelle, voir LoadingProgress.Steps).
    ["loading.phase.connect"] = { "Connexion au serveur…", "Connecting to the server…" },
    ["loading.phase.server"] = { "Préparation du monde…", "Preparing the world…" },
    ["loading.phase.client"] = { "Préparation de l'interface…", "Preparing the interface…" },
    ["loading.phase.character"] = { "Arrivée de votre personnage…", "Your character is on the way…" },
    ["loading.phase.assets"] = { "Chargement des images et des sons…", "Loading images and sounds…" },
    ["loading.phase.ready"] = { "C'est parti !", "Let's go!" },
    -- Délai maximal atteint : le jeu démarre quand même (rien n'est bloqué).
    ["loading.phase.timeout"] = {
        "Chargement plus long que prévu : le jeu démarre.",
        "Loading is taking longer than expected: starting the game.",
    },
}

LoadingTexts.Entries = table.freeze(E)

-- Langue d'affichage d'après l'identifiant de langue Roblox (« fr-fr », « fr-ca », « en-us »…).
function LoadingTexts.languageFor(localeId: string?): Language
    if type(localeId) == "string" and string.sub(string.lower(localeId), 1, 2) == "fr" then
        return "fr"
    end
    return "en"
end

-- Texte d'une clé ; une clé inconnue renvoie la clé elle-même (visible, jamais une erreur bloquante).
function LoadingTexts.t(key: string, language: Language): string
    local entry = E[key]
    if entry == nil then
        return key
    end
    return entry[if language == "fr" then 1 else 2]
end

return table.freeze(LoadingTexts)
