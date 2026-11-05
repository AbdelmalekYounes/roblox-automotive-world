--!strict
-- Statistiques PURES d'échantillons de durée (temps de simulation, temps
-- d'image) : fenêtre glissante bornée, médiane, P95, P99, moyenne, maximum.
-- Les valeurs ne disent rien de plus que ce qui a été échantillonné : elles
-- sont rapportées avec le nombre d'échantillons et le contexte de mesure.

local PerfStats = {}

export type Window = {
    Samples: { number },
    Capacity: number,
    Next: number,
    Count: number,
    Total: number, -- nombre total d'échantillons reçus
}

export type Summary = {
    Count: number,
    Mean: number,
    Median: number,
    P95: number,
    P99: number,
    Max: number,
}

function PerfStats.new(capacity: number): Window
    return { Samples = table.create(capacity, 0), Capacity = capacity, Next = 1, Count = 0, Total = 0 }
end

function PerfStats.add(window: Window, value: number)
    window.Samples[window.Next] = value
    window.Next = window.Next % window.Capacity + 1
    window.Count = math.min(window.Count + 1, window.Capacity)
    window.Total += 1
end

function PerfStats.reset(window: Window)
    window.Next = 1
    window.Count = 0
    window.Total = 0
end

-- Percentile par rang le plus proche sur une liste triée (p dans [0 ; 1]).
local function percentile(sorted: { number }, p: number): number
    local n = #sorted
    if n == 0 then
        return 0
    end
    local rank = math.clamp(math.ceil(p * n), 1, n)
    return sorted[rank]
end
PerfStats.percentile = percentile

function PerfStats.summary(window: Window): Summary
    local values = table.create(window.Count, 0)
    local sum, maximum = 0, 0
    for i = 1, window.Count do
        local value = window.Samples[i]
        values[i] = value
        sum += value
        maximum = math.max(maximum, value)
    end
    table.sort(values)
    return {
        Count = window.Count,
        Mean = if window.Count > 0 then sum / window.Count else 0,
        Median = percentile(values, 0.5),
        P95 = percentile(values, 0.95),
        P99 = percentile(values, 0.99),
        Max = maximum,
    }
end

return table.freeze(PerfStats)
