--!strict
--[[
    Adaptateur INTER-SERVEURS des courses (lot 0.6) — NON TESTÉ.

    Seul module autorisé à utiliser MemoryStoreService (file de matchmaking
    partagée), TeleportService (serveur de course réservé, transition
    explicite) et les OrderedDataStore (tableaux de classement durables).
    Il n'est INSTANCIÉ que si l'environnement résolu est « Test » (expérience
    de test isolée) ou « Prod » (production), déclarés par le propriétaire
    dans Persistence/EnvironmentConfig — aucun ne l'est : en développement,
    tout passe par le repli local (MatchmakingService, tableaux mémoire).
    Rien dans ce lot n'affirme que ce code fonctionne : il n'a jamais été
    exécuté dans une expérience Roblox (QA_BACKLOG : QA-R01, QA-R02, QA-R04).

    Transition vers un serveur de course : réservation d'un serveur
    (ReserveServer), puis téléportation des participants CONFIRMÉS avec des
    données de téléportation non sensibles (identifiant de match, parcours) ;
    le serveur d'arrivée revalide tout (profil, propriété, réservation) et
    ne fait jamais confiance à ces données pour une récompense.
]]

local CrossServerAdapter = {}

export type Adapter = {
    -- File partagée : publication et lecture des tickets des autres serveurs.
    publish: (self: Adapter, ticket: any) -> boolean,
    withdraw: (self: Adapter, userId: number) -> (),
    candidates: (self: Adapter, discipline: string, kind: string) -> { any },
    -- Transition explicite vers un serveur de course réservé.
    reserveAndTeleport: (self: Adapter, players: { Player }, data: any) -> (boolean, string?),
    -- Tableaux de classement durables.
    submit: (self: Adapter, board: string, userId: number, value: number, better: string) -> boolean,
    top: (self: Adapter, board: string, count: number, better: string) -> { { UserId: number, Value: number } },
}

CrossServerAdapter.TicketTtlS = 120

function CrossServerAdapter.available(environmentName: string): boolean
    return environmentName == "Test" or environmentName == "Prod"
end

function CrossServerAdapter.new(environmentName: string, placeId: number): Adapter?
    if not CrossServerAdapter.available(environmentName) then
        return nil
    end
    local MemoryStoreService = game:GetService("MemoryStoreService")
    local TeleportService = game:GetService("TeleportService")
    local DataStoreService = game:GetService("DataStoreService")
    local prefix = "AW_" .. environmentName .. "_"
    local queue = MemoryStoreService:GetSortedMap(prefix .. "RaceQueue")
    local adapter = {}

    function adapter.publish(_self: Adapter, ticket: any): boolean
        local ok = pcall(function()
            queue:SetAsync(tostring(ticket.UserId), ticket, CrossServerAdapter.TicketTtlS)
        end)
        return ok
    end

    function adapter.withdraw(_self: Adapter, userId: number)
        pcall(function()
            queue:RemoveAsync(tostring(userId))
        end)
    end

    function adapter.candidates(_self: Adapter, discipline: string, kind: string): { any }
        local list = {}
        local ok, items = pcall(function()
            return queue:GetRangeAsync(Enum.SortDirection.Ascending, 100)
        end)
        if ok and type(items) == "table" then
            for _, item in items do
                local value = item.value
                if type(value) == "table" and value.Discipline == discipline and value.Kind == kind then
                    table.insert(list, value)
                end
            end
        end
        return list
    end

    function adapter.reserveAndTeleport(_self: Adapter, players: { Player }, data: any): (boolean, string?)
        local ok, code = pcall(function()
            return TeleportService:ReserveServer(placeId)
        end)
        if not ok or type(code) ~= "string" then
            return false, "ReserveServerFailed"
        end
        local options = Instance.new("TeleportOptions")
        options.ReservedServerAccessCode = code
        options:SetTeleportData({ MatchId = data.MatchId, CourseId = data.CourseId })
        local sent = pcall(function()
            TeleportService:TeleportAsync(placeId, players, options)
        end)
        return sent, if sent then nil else "TeleportFailed"
    end

    function adapter.submit(_self: Adapter, board: string, userId: number, value: number, better: string): boolean
        local store = DataStoreService:GetOrderedDataStore(prefix .. board)
        local stored = math.floor(value * (if better == "Lower" then 1000 else 1) + 0.5)
        local ok = pcall(function()
            store:UpdateAsync(tostring(userId), function(old: any): any
                if
                    type(old) == "number"
                    and ((better == "Lower" and old <= stored) or (better == "Higher" and old >= stored))
                then
                    return nil
                end
                return stored
            end)
        end)
        return ok
    end

    function adapter.top(
        _self: Adapter,
        board: string,
        count: number,
        better: string
    ): { { UserId: number, Value: number } }
        local store = DataStoreService:GetOrderedDataStore(prefix .. board)
        local list: { { UserId: number, Value: number } } = {}
        local ok, pages = pcall(function()
            return store:GetSortedAsync(better == "Lower", count)
        end)
        if ok and pages then
            for _, item in pages:GetCurrentPage() do
                local value = if better == "Lower" then item.value / 1000 else item.value
                table.insert(list, { UserId = tonumber(item.key) or 0, Value = value })
            end
        end
        return list
    end

    return adapter :: any
end

return table.freeze(CrossServerAdapter)
