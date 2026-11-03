--!strict
--[[
    Notifications hiérarchisées (lot 0.7, §7.1, AUD-ACCESS-01), PURES.

    Trois niveaux : Info, Warning, Critical.
    - En conduite : Info DIFFÉRÉE (historique, résumé à l'arrêt), Warning
      affichée en COMPACT, Critical toujours affichée et MULTIMODALE (texte,
      icône, signal visuel renforcé, son si disponible).
    - « Réduire les notifications secondaires » : Info jamais affichée
      (historique seulement).
    - Niveau désactivé par le joueur : historique seulement (Critical ne se
      désactive pas).
    - Répétition d'une même alerte (clé de regroupement) pendant son délai :
      pas de nouvel affichage, compteur augmenté.
    - Historique borné, consultable depuis le téléphone, compte des non-lues.
]]

local NotificationQueue = {}

NotificationQueue.MaxHistory = 50
NotificationQueue.Cooldown = table.freeze({ Info = 10, Warning = 20, Critical = 5 })

export type Level = "Info" | "Warning" | "Critical"
export type Display = "Show" | "Compact" | "Defer" | "HistoryOnly" | "Repeat"

export type Item = {
    Id: number,
    Key: string,
    Params: { [string]: any }?,
    Level: Level,
    At: number,
    Group: string,
    Count: number,
    Read: boolean,
    Multimodal: boolean,
}

export type Queue = {
    History: { Item },
    Deferred: { Item },
    LastShown: { [string]: number },
    Counter: number,
}

export type Context = {
    Driving: boolean,
    ReduceSecondary: boolean,
    Enabled: { Info: boolean, Warning: boolean },
}

function NotificationQueue.new(): Queue
    return { History = {}, Deferred = {}, LastShown = {}, Counter = 0 }
end

local RANK: { [Level]: number } = { Info = 1, Warning = 2, Critical = 3 }

function NotificationQueue.rank(level: Level): number
    return RANK[level]
end

--[[
    Ajoute une notification. Renvoie (élément, mode d'affichage).
]]
function NotificationQueue.push(
    queue: Queue,
    key: string,
    level: Level,
    now: number,
    context: Context,
    params: { [string]: any }?,
    group: string?
): (Item, Display)
    local groupKey = group or key
    local last = queue.LastShown[groupKey]
    -- Répétition : on regroupe dans l'historique.
    if last and now - last < NotificationQueue.Cooldown[level] then
        for index = #queue.History, 1, -1 do
            local item = queue.History[index]
            if item.Group == groupKey then
                item.Count += 1
                item.At = now
                item.Read = false
                return item, "Repeat"
            end
        end
    end
    queue.Counter += 1
    local item: Item = {
        Id = queue.Counter,
        Key = key,
        Params = params,
        Level = level,
        At = now,
        Group = groupKey,
        Count = 1,
        Read = false,
        Multimodal = level == "Critical",
    }
    table.insert(queue.History, item)
    while #queue.History > NotificationQueue.MaxHistory do
        table.remove(queue.History, 1)
    end
    -- Critique : toujours affichée ; sinon selon le niveau, le réglage et la conduite.
    local display: Display = "Show"
    local muted = level ~= "Critical"
        and (not (context.Enabled :: any)[level] or (level == "Info" and context.ReduceSecondary))
    if muted then
        display = "HistoryOnly"
    elseif level == "Warning" and context.Driving then
        display = "Compact"
    elseif level == "Info" and context.Driving then
        display = "Defer"
        table.insert(queue.Deferred, item)
    end
    if display == "Show" or display == "Compact" then
        queue.LastShown[groupKey] = now
    end
    return item, display
end

-- À l'arrêt : notifications différées à résumer (puis vidées).
function NotificationQueue.flushDeferred(queue: Queue): { Item }
    local items = queue.Deferred
    queue.Deferred = {}
    return items
end

function NotificationQueue.unread(queue: Queue): number
    local count = 0
    for _, item in queue.History do
        if not item.Read then
            count += 1
        end
    end
    return count
end

function NotificationQueue.markAllRead(queue: Queue)
    for _, item in queue.History do
        item.Read = true
    end
end

function NotificationQueue.clear(queue: Queue)
    queue.History = {}
    queue.Deferred = {}
end

-- Historique du plus récent au plus ancien.
function NotificationQueue.recent(queue: Queue, count: number): { Item }
    local list: { Item } = {}
    for index = #queue.History, math.max(1, #queue.History - count + 1), -1 do
        table.insert(list, queue.History[index])
    end
    return list
end

return table.freeze(NotificationQueue)
