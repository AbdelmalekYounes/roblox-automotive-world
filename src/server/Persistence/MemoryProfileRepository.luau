--!strict
--[[
    Adaptateur de stockage EN MÉMOIRE (tests et environnement de
    développement). Aucune donnée ne quitte le serveur ; tout est perdu à son
    arrêt. Les valeurs sont copiées à l'écriture et à la lecture, comme une
    sérialisation réelle (aucun partage de références).

    Pannes simulables, dans l'ordre où elles sont programmées :
    - "Failed"           : échec certain, rien n'est écrit ;
    - "UncertainLost"    : réponse incertaine, rien n'a été écrit ;
    - "UncertainApplied" : réponse incertaine, l'écriture A été appliquée.
    Le stockage peut aussi être déclaré indisponible (AUD-DATA-01).
]]

local ProfileRepository = require(script.Parent.ProfileRepository)

local MemoryProfileRepository = {}
MemoryProfileRepository.__index = MemoryProfileRepository

export type Fault = "Failed" | "UncertainLost" | "UncertainApplied"

type Fields = {
    Name: string,
    Store: { [string]: any },
    Faults: { Fault },
    Unavailable: boolean,
    Writes: number,
    Reads: number,
}

export type Repository = typeof(setmetatable({} :: Fields, MemoryProfileRepository))

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

function MemoryProfileRepository.new(name: string?): Repository
    return setmetatable({
        Name = name or "Memory",
        Store = {},
        Faults = {},
        Unavailable = false,
        Writes = 0,
        Reads = 0,
    }, MemoryProfileRepository)
end

function MemoryProfileRepository.inject(self: Repository, fault: Fault)
    table.insert(self.Faults, fault)
end

function MemoryProfileRepository.update(
    self: Repository,
    key: string,
    transform: (any) -> any?
): ProfileRepository.UpdateResult
    if self.Unavailable then
        return { Status = "Failed", Error = "Unavailable" }
    end
    local fault = table.remove(self.Faults, 1)
    if fault == "Failed" then
        return { Status = "Failed", Error = "Injected" }
    end
    local new = transform(deepCopy(self.Store[key]))
    if new == nil then
        return { Status = "Cancelled" }
    end
    if fault == "UncertainLost" then
        return { Status = "Uncertain", Error = "Injected" }
    end
    self.Store[key] = deepCopy(new)
    self.Writes += 1
    if fault == "UncertainApplied" then
        return { Status = "Uncertain", Error = "Injected" }
    end
    return { Status = "Ok", Value = deepCopy(new) }
end

function MemoryProfileRepository.read(self: Repository, key: string): ProfileRepository.ReadResult
    if self.Unavailable then
        return { Ok = false, Error = "Unavailable" }
    end
    self.Reads += 1
    return { Ok = true, Value = deepCopy(self.Store[key]) }
end

return MemoryProfileRepository
