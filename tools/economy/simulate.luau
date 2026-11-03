--!strict
--[[
    Simulation des revenus par métier (lot 0.5), hors Roblox.
    Usage : lune run tools/economy/simulate.luau build/AutomotiveWorld.rbxlx [missions par métier] [qualité]

    Génère des missions réelles avec le générateur du serveur sur la carte du
    monde ouvert, puis estime pour chaque métier :
    - crédits par heure BRUTS (rémunération / durée estimée) ;
    - crédits par heure NETS : moins le carburant consommé avec un véhicule
      personnel (hypothèse : 8 L/100 km à 4 crédits/L ; aucun coût avec un
      véhicule professionnel ou fourni) et l'usure (réparations, hypothèse
      provisoire de 0,5 crédit par km).
    Sert à comparer les métiers entre eux ; ce n'est PAS un équilibrage final.
]]

local process = require("@lune/process")
local Harness = require("../../tests/lune/Harness")

local placePath = process.args[1] or "build/AutomotiveWorld.rbxlx"
local count = tonumber(process.args[2]) or 200
local quality = tonumber(process.args[3]) or 0.85

Harness.loadPlace(placePath)
local SERVER = "ServerScriptService.AutomotiveWorldServer."
local MissionGenerator = Harness.require(SERVER .. "Economy.MissionGenerator")
local MissionPlaces = Harness.require(SERVER .. "Economy.MissionPlaces")
local RewardModel = Harness.require(SERVER .. "Economy.RewardModel")
local ProfileSchema = Harness.require(SERVER .. "Persistence.ProfileSchema")
local Jobs = Harness.require("ReplicatedStorage.Shared.Economy.Jobs")
local EconomyCatalog = Harness.require("ReplicatedStorage.Shared.Economy.EconomyCatalog")

local FUEL_L_PER_KM = 0.08
local WEAR_PER_KM = 0.5

local places = MissionPlaces.openWorld()
local seed = 4242
local function roll(): number
    seed = (seed * 16807) % 2147483647
    return seed / 2147483647
end

print(string.format("Simulation : %d missions par métier, qualité %.2f, difficulté tirée", count, quality))
print(string.format("%-14s %10s %10s %10s %10s", "Métier", "min/miss.", "brut/h", "net/h", "km/miss."))
local rows = {}
for _, job in Jobs.List do
    local credits, seconds, km = 0, 0, 0
    local generated = 0
    for i = 1, count do
        local origin = places.Road[(i * 13) % #places.Road + 1]
        local mission = MissionGenerator.generate(job.Id, "S" .. i, 1, origin, places, 2, roll, 0)
        if mission then
            generated += 1
            local quote = RewardModel.quote(ProfileSchema.new(1, 0, "Dev"), mission, quality, 0)
            credits += quote.Credits
            seconds += mission.EstimatedS
            km += mission.DistanceM * MissionGenerator.RouteFactor / 1000
        end
    end
    local hours = seconds / 3600
    local ownCost = if job.Vehicle == "Own"
        then km * (FUEL_L_PER_KM * EconomyCatalog.EnergyPrice.Petrol + WEAR_PER_KM)
        else 0
    local gross = credits / hours
    local net = (credits - ownCost) / hours
    table.insert(rows, { job.Id, seconds / generated / 60, gross, net, km / generated })
end
local low, high = math.huge, 0
for _, r in rows do
    print(string.format("%-14s %10.1f %10.0f %10.0f %10.2f", r[1], r[2], r[3], r[4], r[5]))
    low = math.min(low, r[4])
    high = math.max(high, r[4])
end
print(string.format("Écart net max/min : %.2f", high / low))
