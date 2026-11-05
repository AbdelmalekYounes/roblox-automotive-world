--!strict
--[[
    Résultats durables et tableaux de classement (lot 0.6).

    - Enregistrement de course Race_<id> (même stockage que les profils,
      clé hors profil) : contexte de paiement de CHAQUE participant, écrit
      par le serveur de course à la fin de l'épreuve, avant toute
      application aux profils. Un résultat déjà écrit n'est jamais remplacé
      (UpdateAsync conditionnel) : le serveur qui détient un profil peut
      ainsi appliquer plus tard un résultat confirmé (RaceRecovery), une fois.
    - Tableaux de classement : par saison et échelle, et records par
      parcours / version / conditions normalisées. Adaptateur MÉMOIRE (place
      de développement, tests) ; l'adaptateur OrderedDataStore d'une
      expérience de test isolée ou de production déclarée est dans
      Racing/CrossServerAdapter — aucune n'est déclarée : jamais utilisé
      aujourd'hui (NON TESTÉ).
]]

local RacePersistence = {}

RacePersistence.RecordVersion = 1

function RacePersistence.raceKey(raceId: string): string
    return "Race_" .. raceId
end

--[[
    Publie les contextes de paiement d'une course (fusion : jamais
    d'écrasement d'un résultat déjà publié). `results` : { [UserId texte] = contexte }.
]]
function RacePersistence.publish(repository: any, raceId: string, summary: any, results: { [string]: any }): string
    local outcome = repository:update(RacePersistence.raceKey(raceId), function(old: any): any
        local record = if type(old) == "table"
            then old
            else { Version = RacePersistence.RecordVersion, RaceId = raceId, Results = {} }
        record.Summary = record.Summary or summary
        for userId, context in results do
            if record.Results[userId] == nil then
                record.Results[userId] = context
            end
        end
        return record
    end)
    return outcome.Status
end

function RacePersistence.read(repository: any, raceId: string): any?
    local result = repository:read(RacePersistence.raceKey(raceId))
    if result.Ok then
        return result.Value
    end
    return nil
end

-- ======================== Tableaux de classement ========================

-- Lower : meilleur = plus petit (temps, record conservé) ; Higher : plus grand
-- (score, record conservé) ; Latest : dernière valeur (points de saison).
export type Better = "Lower" | "Higher" | "Latest"

export type Board = {
    submit: (self: any, board: string, userId: number, value: number, better: Better) -> boolean,
    top: (self: any, board: string, count: number, better: Better) -> { { UserId: number, Value: number } },
}

local MemoryBoard = {}
MemoryBoard.__index = MemoryBoard

function RacePersistence.memoryBoard(): any
    return setmetatable({ Boards = {} }, MemoryBoard)
end

-- Conserve la MEILLEURE valeur de chaque joueur (record) ou la dernière (points).
function MemoryBoard.submit(self: any, board: string, userId: number, value: number, better: Better): boolean
    local entries = self.Boards[board]
    if entries == nil then
        entries = {}
        self.Boards[board] = entries
    end
    local current = entries[userId]
    if
        better == "Latest"
        or current == nil
        or (better == "Lower" and value < current)
        or (better == "Higher" and value > current)
    then
        entries[userId] = value
        return true
    end
    return false
end

function MemoryBoard.top(self: any, board: string, count: number, better: Better): { { UserId: number, Value: number } }
    local list: { { UserId: number, Value: number } } = {}
    for userId, value in self.Boards[board] or {} do
        table.insert(list, { UserId = userId, Value = value })
    end
    table.sort(list, function(a, b)
        if a.Value ~= b.Value then
            return if better == "Lower" then a.Value < b.Value else a.Value > b.Value
        end
        return a.UserId < b.UserId
    end)
    while #list > count do
        table.remove(list)
    end
    return list
end

-- Noms des tableaux.
function RacePersistence.seasonBoard(season: number, ladder: string): string
    return string.format("S%d:%s", season, ladder)
end

function RacePersistence.recordBoard(recordKey: string): string
    return "Rec:" .. recordKey
end

return table.freeze(RacePersistence)
