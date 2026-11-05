--!strict
--[[
    File ordonnée des applications d'apparence (clôture de la phase 1 de l'Aster, 2026-11-04).

    Problème corrigé (audit d'`AvatarService`) : `ApplyDescriptionAsync` peut ne jamais rendre
    la main (tâche VM 20261104-151955). Le délai d'attente libérait l'appelant, mais l'appel du
    moteur continuait : terminé plus tard, il pouvait appliquer une ANCIENNE apparence par-dessus
    un choix plus récent du joueur, ou se chevaucher avec une autre application.

    Garanties, par clé (un personnage) :
    - une seule opération à la fois, dans l'ordre des demandes (ticket) ;
    - une opération qui dépasse `TimeoutS` libère son appelant (« Timeout ») mais GARDE son tour :
      la suivante ne commence qu'à sa fin réelle. Une opération construite au moment de son tour
      (depuis l'apparence appliquée et l'état voulu) applique donc toujours l'état le plus récent ;
    - au-delà de `AbandonS`, l'opération est déclarée abandonnée et la suite reprend ; si elle se
      termine malgré tout, `OnStale` est appelé pour rétablir l'état voulu (réconciliation).
    Une opération en erreur rend « Failed » et libère son tour.

    Module sans dépendance au moteur (`task` injectable, `os.clock`) : testé hors Studio (Lune,
    `tests/lune/specs/AsterPhase1Closure.luau`), opérations lentes simulées.
]]

local ApplyQueue = {}
ApplyQueue.__index = ApplyQueue

export type Outcome = "Ok" | "Failed" | "Timeout"

export type Options = {
    TimeoutS: number, -- attente maximale de l'appelant
    AbandonS: number, -- au-delà, l'opération en cours est abandonnée (la file reprend)
    OnStale: ((key: any, ticket: number) -> ())?, -- opération abandonnée terminée après coup
    PollS: number?, -- pas d'attente (défaut 0,02 s)
    Scheduler: Scheduler?, -- défaut : bibliothèque `task` du moteur (injectée par les tests Lune)
}

export type Scheduler = { spawn: (any, ...any) -> any, wait: (number?) -> any }

type Slot = {
    Issued: number, -- dernier ticket distribué
    Turn: number, -- ticket en cours (ou prochain à servir)
    StartedAt: number?, -- début de l'opération du ticket `Turn`
    Abandoned: { [number]: boolean },
}

export type Queue = typeof(setmetatable({} :: { Options: Options, Slots: { [any]: Slot }, Stale: number }, ApplyQueue))

function ApplyQueue.new(options: Options): Queue
    assert(options.TimeoutS > 0 and options.AbandonS >= options.TimeoutS, "délais incohérents")
    return setmetatable({ Options = options, Slots = {}, Stale = 0 }, ApplyQueue)
end

local function scheduler(self: Queue): Scheduler
    return self.Options.Scheduler or (task :: any)
end

local function slotOf(self: Queue, key: any): Slot
    local slot = self.Slots[key]
    if slot == nil then
        slot = { Issued = 0, Turn = 1, StartedAt = nil, Abandoned = {} }
        self.Slots[key] = slot
    end
    return slot :: Slot
end

-- Passe au ticket suivant (fin réelle ou abandon du ticket courant) ; libère la clé inactive.
local function advance(self: Queue, key: any, slot: Slot, ticket: number)
    if slot.Turn == ticket then
        slot.Turn += 1
        slot.StartedAt = nil
    end
    -- La clé peut déjà porter une file plus récente : ne supprimer que celle-ci.
    if slot.Turn > slot.Issued and next(slot.Abandoned) == nil and self.Slots[key] == slot then
        self.Slots[key] = nil
    end
end

-- Exécute `operation` à son tour. Rend l'issue, le message d'erreur éventuel et le ticket.
function ApplyQueue.run(self: Queue, key: any, operation: () -> ()): (Outcome, string, number)
    local options = self.Options
    local poll = options.PollS or 0.02
    local sched = scheduler(self)
    local slot = slotOf(self, key)
    slot.Issued += 1
    local ticket = slot.Issued
    -- Attente du tour ; une opération en cours trop longue est abandonnée.
    while slot.Turn ~= ticket do
        local started = slot.StartedAt
        if started ~= nil and os.clock() - started > options.AbandonS then
            slot.Abandoned[slot.Turn] = true
            advance(self, key, slot, slot.Turn)
        else
            sched.wait(poll)
        end
    end
    slot.StartedAt = os.clock()
    local done, ok, message = false, false, ""
    sched.spawn(function()
        local success, err = pcall(operation :: () -> any)
        done, ok, message = true, success, if success then "" else tostring(err)
        if slot.Abandoned[ticket] then
            -- Terminée après abandon : l'état voulu doit être rétabli par l'appelant.
            slot.Abandoned[ticket] = nil
            self.Stale += 1
            if options.OnStale then
                sched.spawn(options.OnStale, key, ticket)
            end
            advance(self, key, slot, -1)
        else
            advance(self, key, slot, ticket)
        end
    end)
    local deadline = os.clock() + options.TimeoutS
    while not done and os.clock() < deadline do
        sched.wait(poll)
    end
    if not done then
        return "Timeout", "délai dépassé", ticket
    end
    return if ok then "Ok" else "Failed", message, ticket
end

-- Nombre d'opérations en attente ou en cours pour la clé (0 : inactive).
function ApplyQueue.pending(self: Queue, key: any): number
    local slot = self.Slots[key]
    if slot == nil then
        return 0
    end
    return math.max(0, slot.Issued - slot.Turn + 1)
end

return ApplyQueue
