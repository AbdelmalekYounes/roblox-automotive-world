--!strict
--[[
    Séparation STRICTE des environnements de stockage (AUD-ENV-01, §8.5).

    - Dev  : stockage EN MÉMOIRE uniquement (rien n'est persisté). C'est le cas
      par défaut, notamment dans Studio et dans toute expérience inconnue.
    - Test : DataStore de l'expérience de TEST isolée (identifiant listé dans
      EnvironmentConfig.TestGameIds), nom de magasin « AW_TEST_… ».
    - Prod : DataStore de l'expérience de PRODUCTION (EnvironmentConfig.ProdGameIds),
      nom « AW_PROD_… », JAMAIS depuis Studio : une session Studio ouverte sur
      l'expérience de production retombe en mémoire (et ne demande jamais
      l'accès aux API).
    Les listes sont vides tant que les expériences n'existent pas : aucun
    DataStore n'est donc utilisé aujourd'hui, quel que soit le lieu d'exécution.
]]

local Environment = {}

export type Name = "Dev" | "Test" | "Prod"

export type Resolved = {
    Name: Name,
    Store: "Memory" | "DataStore",
    StoreName: string, -- nom du DataStore (ou de l'espace mémoire)
    Reason: string,
}

export type Config = {
    TestGameIds: { number },
    ProdGameIds: { number },
    SchemaTag: string, -- suffixe du nom de magasin (changement de format majeur)
}

function Environment.resolve(gameId: number, isStudio: boolean, config: Config): Resolved
    if table.find(config.ProdGameIds, gameId) then
        if isStudio then
            return {
                Name = "Dev",
                Store = "Memory",
                StoreName = "AW_DEV_Profiles_" .. config.SchemaTag,
                Reason = "StudioOnProduction",
            }
        end
        return {
            Name = "Prod",
            Store = "DataStore",
            StoreName = "AW_PROD_Profiles_" .. config.SchemaTag,
            Reason = "ProdGame",
        }
    end
    if table.find(config.TestGameIds, gameId) then
        return {
            Name = "Test",
            Store = "DataStore",
            StoreName = "AW_TEST_Profiles_" .. config.SchemaTag,
            Reason = "TestGame",
        }
    end
    return { Name = "Dev", Store = "Memory", StoreName = "AW_DEV_Profiles_" .. config.SchemaTag, Reason = "UnknownGame" }
end

-- Données synthétiques de développement autorisées seulement en Dev.
function Environment.allowsSynthetic(resolved: Resolved): boolean
    return resolved.Name == "Dev" and resolved.Store == "Memory"
end

return table.freeze(Environment)
