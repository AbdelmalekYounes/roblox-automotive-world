--!strict
--[[
    Adaptateur de stockage Roblox DataStore (lot 0.4).

    N'est instancié QUE pour les environnements Test et Prod (Environment),
    c'est-à-dire jamais aujourd'hui : les identifiants d'expériences ne sont
    pas déclarés. Sa validation par de vraies écritures se fera uniquement
    dans une expérience de test isolée (docs/QA_BACKLOG.md, NON TESTÉ).

    - UpdateAsync seulement (écritures conditionnelles, jamais SetAsync).
    - Budget : attente bornée tant que GetRequestBudgetForRequestType est nul.
    - Échecs : quelques tentatives avec attente croissante pour les erreurs
      certaines AVANT écriture ; une erreur pendant l'appel (réponse perdue,
      délai) est rapportée « Uncertain » : l'appelant relit et réconcilie,
      il ne rejoue pas à l'aveugle.
]]

local DataStoreService = game:GetService("DataStoreService")

local ProfileRepository = require(script.Parent.ProfileRepository)

local DataStoreProfileRepository = {}
DataStoreProfileRepository.__index = DataStoreProfileRepository

local MAX_BUDGET_WAIT_S = 10
local READ_ATTEMPTS = 3

type Fields = {
    Name: string,
    Store: DataStore,
}

export type Repository = typeof(setmetatable({} :: Fields, DataStoreProfileRepository))

function DataStoreProfileRepository.new(storeName: string): Repository
    return setmetatable({
        Name = storeName,
        Store = DataStoreService:GetDataStore(storeName),
    }, DataStoreProfileRepository)
end

local function waitForBudget(requestType: Enum.DataStoreRequestType): boolean
    local waited = 0
    while DataStoreService:GetRequestBudgetForRequestType(requestType) < 1 do
        if waited >= MAX_BUDGET_WAIT_S then
            return false
        end
        task.wait(0.5)
        waited += 0.5
    end
    return true
end

function DataStoreProfileRepository.update(
    self: Repository,
    key: string,
    transform: (any) -> any?
): ProfileRepository.UpdateResult
    if not waitForBudget(Enum.DataStoreRequestType.UpdateAsync) then
        return { Status = "Failed", Error = "Budget" }
    end
    local cancelled = false
    local ok, result = pcall(function()
        return self.Store:UpdateAsync(key, function(old: any)
            local new = transform(old)
            if new == nil then
                cancelled = true
            end
            return new
        end)
    end)
    if not ok then
        -- L'appel a pu atteindre le serveur de données : résultat inconnu.
        return { Status = "Uncertain", Error = tostring(result) }
    end
    if cancelled then
        return { Status = "Cancelled" }
    end
    return { Status = "Ok", Value = result }
end

function DataStoreProfileRepository.read(self: Repository, key: string): ProfileRepository.ReadResult
    local lastError = ""
    for attempt = 1, READ_ATTEMPTS do
        if waitForBudget(Enum.DataStoreRequestType.GetAsync) then
            local ok, value = pcall(function()
                -- Lecture fraîche (sans cache) : sert à réconcilier une écriture incertaine.
                local options = Instance.new("DataStoreGetOptions")
                options.UseCache = false
                return self.Store:GetAsync(key, options)
            end)
            if ok then
                return { Ok = true, Value = value }
            end
            lastError = tostring(value)
        else
            lastError = "Budget"
        end
        task.wait(attempt)
    end
    return { Ok = false, Error = lastError }
end

return DataStoreProfileRepository
