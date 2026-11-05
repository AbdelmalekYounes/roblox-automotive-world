--!strict
--[[
    Règles PURES du menu d'administration (lot ADMIN-01, décisions du propriétaire du 2026-11-05).

    Le serveur décide de tout : ce module ne fait que DÉCRIRE les actions et VALIDER leurs paramètres (types, bornes,
    longueurs). Il est testé hors Studio (Lune). Les droits d'administrateur sont lus côté serveur
    (Server/Admin/AdminConfig) ; un client ne peut jamais s'en attribuer.

    Décisions : menu actif pour les administrateurs dans TOUS les environnements (A1) ; véhicules apparus
    TEMPORAIRES (A3) ; au plus 100 000 crédits par action (A4) ; toutes les actions proposées (A5).
]]

local AdminRules = {}

AdminRules.MaxCreditGrant = 100_000 -- crédits par action (A4)
AdminRules.LogSize = 50 -- entrées gardées dans le journal du serveur
AdminRules.WalkSpeed = table.freeze({ Min = 4, Max = 120, Default = 16 }) -- studs/s
AdminRules.NoclipSpeed = table.freeze({ Min = 10, Max = 300, Default = 60 }) -- studs/s
AdminRules.ClockSpeed = table.freeze({ Min = 0, Max = 60 }) -- multiplicateur du cycle (0 = heure figée)
AdminRules.ReputationMax = 100_000 -- points
AdminRules.ReasonMax = 120 -- caractères (motif d'expulsion)
AdminRules.IdMax = 80 -- caractères (identifiants de lieu ou de modèle)
AdminRules.Weathers = table.freeze({ "Clear", "Rain", "Fog", "Storm" })

-- Liste FERMÉE des actions ; toute autre demande est refusée (« AdminActionUnknown »).
AdminRules.Actions = table.freeze({
    "Snapshot",
    "SetClock",
    "SetClockSpeed",
    "SetWeather",
    "SpawnVehicle",
    "RemoveSpawned",
    "RepairVehicle",
    "FlipVehicle",
    "SetInvulnerable",
    "SetNoclip",
    "Teleport",
    "TeleportToPlayer",
    "BringPlayer",
    "Respawn",
    "SetWalkSpeed",
    "SetInvisible",
    "GrantCredits",
    "SetReputation",
    "AbandonMission",
    "ResetProfile",
    "ForceRaceStart",
    "Kick",
})

-- Actions qui demandent une confirmation dans l'interface (effet durable ou sur un autre joueur).
AdminRules.Confirm = table.freeze({
    ["GrantCredits"] = true,
    SetReputation = true,
    ResetProfile = true,
    Kick = true,
    BringPlayer = true,
})

-- Actions consignées au journal (la lecture de l'état ne l'est pas).
function AdminRules.logged(action: string): boolean
    return action ~= "Snapshot"
end

function AdminRules.isAdmin(userId: number, admins: { number }): boolean
    return type(userId) == "number" and table.find(admins, userId) ~= nil
end

local function finite(value: any): boolean
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function integer(value: any): boolean
    return finite(value) and math.floor(value) == value
end

local function shortString(value: any, max: number): boolean
    return type(value) == "string" and #value > 0 and #value <= max
end

local function trim(value: string): string
    return (string.gsub(value, "^%s+", ""):gsub("%s+$", ""))
end

type Payload = { [string]: any }

-- Validation : renvoie (true, paramètres nettoyés) ou (false, clé d'erreur). Ne fait AUCUN accès au jeu.
function AdminRules.validate(action: any, payload: any): (boolean, any)
    if type(action) ~= "string" or table.find(AdminRules.Actions, action) == nil then
        return false, "AdminActionUnknown"
    end
    local p: Payload = if type(payload) == "table" then payload else {}
    if action == "SetClock" then
        if not finite(p.Hour) or p.Hour < 0 or p.Hour >= 24 then
            return false, "AdminHourInvalid"
        end
        return true, { Hour = p.Hour }
    elseif action == "SetClockSpeed" then
        local range = AdminRules.ClockSpeed
        if not finite(p.Speed) or p.Speed < range.Min or p.Speed > range.Max then
            return false, "AdminSpeedInvalid"
        end
        return true, { Speed = p.Speed }
    elseif action == "SetWeather" then
        if type(p.State) ~= "string" or table.find(AdminRules.Weathers, p.State) == nil then
            return false, "AdminWeatherInvalid"
        end
        return true, { State = p.State }
    elseif action == "SpawnVehicle" then
        if not shortString(p.ModelId, AdminRules.IdMax) then
            return false, "AdminModelInvalid"
        end
        return true, { ModelId = p.ModelId }
    elseif action == "RepairVehicle" then
        return true, { RefillEnergy = p.RefillEnergy == true }
    elseif action == "SetInvulnerable" or action == "SetInvisible" then
        if type(p.On) ~= "boolean" then
            return false, "AdminFlagInvalid"
        end
        return true, { On = p.On }
    elseif action == "SetNoclip" then
        if type(p.On) ~= "boolean" then
            return false, "AdminFlagInvalid"
        end
        local range = AdminRules.NoclipSpeed
        local speed = if p.Speed == nil then range.Default else p.Speed
        if not finite(speed) or speed < range.Min or speed > range.Max then
            return false, "AdminSpeedInvalid"
        end
        return true, { On = p.On, Speed = speed }
    elseif action == "Teleport" then
        if not shortString(p.PointId, AdminRules.IdMax) then
            return false, "AdminPointInvalid"
        end
        return true, { PointId = p.PointId }
    elseif action == "TeleportToPlayer" or action == "BringPlayer" then
        if not integer(p.UserId) or p.UserId <= 0 then
            return false, "AdminPlayerInvalid"
        end
        return true, { UserId = p.UserId }
    elseif action == "SetWalkSpeed" then
        local range = AdminRules.WalkSpeed
        if not finite(p.Value) or p.Value < range.Min or p.Value > range.Max then
            return false, "AdminSpeedInvalid"
        end
        return true, { Value = p.Value }
    elseif action == "GrantCredits" then
        if not integer(p.UserId) or p.UserId <= 0 then
            return false, "AdminPlayerInvalid"
        end
        if not integer(p.Amount) or p.Amount < 1 or p.Amount > AdminRules.MaxCreditGrant then
            return false, "AdminAmountInvalid"
        end
        return true, { UserId = p.UserId, Amount = p.Amount }
    elseif action == "SetReputation" then
        if not integer(p.Points) or p.Points < 0 or p.Points > AdminRules.ReputationMax then
            return false, "AdminAmountInvalid"
        end
        return true, { Points = p.Points }
    elseif action == "Kick" then
        if not integer(p.UserId) or p.UserId <= 0 then
            return false, "AdminPlayerInvalid"
        end
        local reason = if type(p.Reason) == "string" then trim(p.Reason) else ""
        if #reason == 0 or #reason > AdminRules.ReasonMax then
            return false, "AdminReasonInvalid"
        end
        return true, { UserId = p.UserId, Reason = reason }
    end
    -- Snapshot, RemoveSpawned, FlipVehicle, Respawn, AbandonMission, ResetProfile, ForceRaceStart : sans paramètre.
    return true, {}
end

export type LogEntry = {
    At: number,
    AdminId: number,
    AdminName: string,
    Action: string,
    Target: number?,
    Detail: string,
    Result: string,
}

-- Journal circulaire : la plus récente en tête, au plus LogSize entrées.
function AdminRules.logPush(log: { LogEntry }, entry: LogEntry)
    table.insert(log, 1, entry)
    while #log > AdminRules.LogSize do
        table.remove(log)
    end
end

return table.freeze(AdminRules)
