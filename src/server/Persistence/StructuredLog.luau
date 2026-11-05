--!strict
--[[
    Journal STRUCTURÉ et BORNÉ des opérations de persistance (§8.5).

    - Taille fixe (anneau) : jamais de croissance sans limite.
    - Champs filtrés : nombres, booléens et chaînes courtes seulement (pas de
      tables, pas de texte libre long) ; aucune donnée confidentielle (pas de
      nom d'affichage, pas de contenu de profil).
    - Une sortie optionnelle (print/warn côté serveur) reçoit chaque entrée.
]]

local StructuredLog = {}
StructuredLog.__index = StructuredLog

export type Level = "Info" | "Warn" | "Error"
export type Entry = { At: number, Level: Level, Event: string, Fields: { [string]: any } }

type Fields = {
    Capacity: number,
    Entries: { Entry },
    Next: number,
    Count: number,
    Sink: ((Entry) -> ())?,
    Clock: () -> number,
}

export type Log = typeof(setmetatable({} :: Fields, StructuredLog))

local MAX_STRING = 64

function StructuredLog.new(capacity: number, clock: () -> number, sink: ((Entry) -> ())?): Log
    return setmetatable({
        Capacity = capacity,
        Entries = {},
        Next = 1,
        Count = 0,
        Sink = sink,
        Clock = clock,
    }, StructuredLog)
end

local function sanitize(fields: { [string]: any }?): { [string]: any }
    local clean: { [string]: any } = {}
    local source: { [string]: any } = fields or {}
    for key, value in source do
        local kind = type(value)
        if kind == "number" or kind == "boolean" then
            clean[key] = value
        elseif kind == "string" then
            clean[key] = string.sub(value, 1, MAX_STRING)
        end
    end
    return clean
end

function StructuredLog.write(self: Log, level: Level, event: string, fields: { [string]: any }?)
    local entry: Entry =
        { At = self.Clock(), Level = level, Event = string.sub(event, 1, MAX_STRING), Fields = sanitize(fields) }
    self.Entries[self.Next] = entry
    self.Next = self.Next % self.Capacity + 1
    self.Count = math.min(self.Count + 1, self.Capacity)
    if self.Sink then
        self.Sink(entry)
    end
end

-- Entrées dans l'ordre chronologique.
function StructuredLog.list(self: Log): { Entry }
    local result: { Entry } = {}
    local start = if self.Count < self.Capacity then 1 else self.Next
    for i = 0, self.Count - 1 do
        table.insert(result, self.Entries[(start + i - 1) % self.Capacity + 1])
    end
    return result
end

function StructuredLog.format(entry: Entry): string
    local parts: { string } = {}
    for key, value in entry.Fields do
        table.insert(parts, key .. "=" .. tostring(value))
    end
    table.sort(parts)
    return string.format("[AW][Profil][%s] %s %s", entry.Level, entry.Event, table.concat(parts, " "))
end

return StructuredLog
