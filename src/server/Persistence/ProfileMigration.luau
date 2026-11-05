--!strict
--[[
    Migrations VERSIONNÉES des profils (AUD-MIG-01, §8.5).

    - Chaque migration fait passer de la version n à n + 1, sur une COPIE ;
      elle ne supprime jamais une donnée : un champ abandonné est déplacé dans
      `Legacy` (conservé, lisible par une restauration ciblée).
    - Une donnée d'une version PLUS RÉCENTE que le code (serveur ancien pendant
      un déploiement progressif) n'est ni migrée ni réécrite : le profil passe
      en lecture seule pour ce serveur (aucun retour arrière destructeur).
    - La liste des migrations est injectable (tests).
]]

local ProfileSchema = require(script.Parent.ProfileSchema)

local ProfileMigration = {}

export type Migration = {
    From: number,
    Describe: string,
    Apply: (data: any) -> any, -- reçoit une copie, renvoie la donnée migrée
}

export type Result = {
    Status: "Current" | "Migrated" | "Newer" | "Invalid",
    Data: any,
    Steps: { string },
}

local function deepCopy(value: any): any
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, child in value do
        copy[key] = deepCopy(child)
    end
    return copy
end
ProfileMigration.deepCopy = deepCopy

--[[
    Migrations officielles. La version 1 est la première version publiée ;
    aucune donnée de version 0 n'existe (aucun profil avant le lot 0.4). Les
    futures migrations s'ajoutent ici, dans l'ordre.
]]
local MIGRATIONS: { Migration } = {}
ProfileMigration.Official = table.freeze(MIGRATIONS)

function ProfileMigration.migrate(raw: any, targetVersion: number?, migrations: { Migration }?): Result
    local target = targetVersion or ProfileSchema.Version
    local list = migrations or MIGRATIONS
    if type(raw) ~= "table" or type(raw.SchemaVersion) ~= "number" then
        return { Status = "Invalid", Data = raw, Steps = {} }
    end
    if raw.SchemaVersion > target then
        return { Status = "Newer", Data = raw, Steps = {} }
    end
    if raw.SchemaVersion == target then
        return { Status = "Current", Data = raw, Steps = {} }
    end
    local data = deepCopy(raw)
    local steps: { string } = {}
    while data.SchemaVersion < target do
        local step: Migration? = nil
        for _, migration in list do
            if migration.From == data.SchemaVersion then
                step = migration
                break
            end
        end
        if step == nil then
            return { Status = "Invalid", Data = raw, Steps = steps }
        end
        local from = data.SchemaVersion
        data = step.Apply(data)
        if type(data) ~= "table" or data.SchemaVersion ~= from + 1 then
            return { Status = "Invalid", Data = raw, Steps = steps }
        end
        table.insert(steps, string.format("%d→%d %s", from, from + 1, step.Describe))
    end
    return { Status = "Migrated", Data = data, Steps = steps }
end

-- Déplace un champ abandonné dans `Legacy` au lieu de le supprimer.
function ProfileMigration.retire(data: any, key: string)
    if data[key] ~= nil then
        data.Legacy = data.Legacy or {}
        data.Legacy[key] = data[key]
        data[key] = nil
    end
end

return table.freeze(ProfileMigration)
