--!strict
-- Jeux d'essai des tests (lot BASE-01) : définitions retirées du jeu, gelées, par identifiant.
local Fixtures = {}

local function deepFreeze(value: any): any
    if type(value) == "table" and not table.isfrozen(value) then
        for _, child in value do
            deepFreeze(child)
        end
        table.freeze(value)
    end
    return value
end

local byId: { [string]: any } = {
    proto_p01 = deepFreeze(require("./PrototypeP01")),
    proto_p02 = deepFreeze(require("./PrototypeP02")),
    proto_p03 = deepFreeze(require("./PrototypeP03")),
    proto_p01_dct = deepFreeze(require("./VariantDct")),
    proto_p01_seq = deepFreeze(require("./VariantSeq")),
    proto_p01_cvt = deepFreeze(require("./VariantCvt")),
}

-- Ordre historique du registre (P-01, P-02, P-03, puis les variantes de validation).
Fixtures.Order =
    table.freeze({ "proto_p01", "proto_p02", "proto_p03", "proto_p01_dct", "proto_p01_seq", "proto_p01_cvt" })

function Fixtures.get(id: string): any
    return byId[id]
end

function Fixtures.all(): { any }
    local list = {}
    for _, id in Fixtures.Order do
        table.insert(list, byId[id])
    end
    return list
end

return table.freeze(Fixtures)
