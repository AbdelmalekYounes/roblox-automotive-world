--!strict
--[[
    Simulation d'équilibrage des courses (lot 0.6), hors Roblox.
    Usage : lune run tools/economy/simulate-races.luau build/AutomotiveWorld.rbxlx [performance] [participants]

    Pour chaque parcours du monde ouvert, avec le modèle de récompense du
    serveur (RaceRewards) :
    - crédits par heure de COURSE (temps de référence du parcours) en mode
      protégé et en mode réaliste (brut, puis net des coûts estimés : énergie
      et usure probable) ;
    - même calcul en comptant le temps hors course (inscription, grille,
      résultats : 75 s par épreuve, hypothèse) ;
    - comparaison avec les huit métiers (générateur et barème du lot 0.5).
    Hypothèses provisoires : ce n'est PAS un équilibrage final ni une mesure
    en jeu (QA-R07).
]]

local process = require("@lune/process")
local Harness = require("../../tests/lune/Harness")

local placePath = process.args[1] or "build/AutomotiveWorld.rbxlx"
local performanceTarget = tonumber(process.args[2]) or 0.8
local field = tonumber(process.args[3]) or 4
local OVERHEAD_S = 75

Harness.loadPlace(placePath)
local SERVER = "ServerScriptService.AutomotiveWorldServer."
local RaceCourse = Harness.require(SERVER .. "Racing.RaceCourse")
local RaceRewards = Harness.require(SERVER .. "Racing.RaceRewards")
local ProfileSchema = Harness.require(SERVER .. "Persistence.ProfileSchema")
local MissionGenerator = Harness.require(SERVER .. "Economy.MissionGenerator")
local MissionPlaces = Harness.require(SERVER .. "Economy.MissionPlaces")
local RewardModel = Harness.require(SERVER .. "Economy.RewardModel")
local RaceCourses = Harness.require("ReplicatedStorage.Shared.Racing.RaceCourses")
local RaceDefinitions = Harness.require("ReplicatedStorage.Shared.Racing.RaceDefinitions")
local Jobs = Harness.require("ReplicatedStorage.Shared.Economy.Jobs")

-- Métiers : moyenne des crédits par heure estimée (même méthode que simulate.luau).
local places = MissionPlaces.openWorld()
local seed = 4242
local function roll(): number
    seed = (seed * 16807) % 2147483647
    return seed / 2147483647
end
local jobTotal, jobCount = 0, 0
for _, job in Jobs.List do
    local credits, seconds = 0, 0
    for i = 1, 60 do
        local origin = places.Road[(i * 13) % #places.Road + 1]
        local mission = MissionGenerator.generate(job.Id, "S" .. i, 1, origin, places, 2, roll, 0)
        if mission then
            credits += RewardModel.quote(ProfileSchema.new(1, 0, "Dev"), mission, 0.85, 0).Credits
            seconds += mission.EstimatedS
        end
    end
    if seconds > 0 then
        jobTotal += credits / (seconds / 3600)
        jobCount += 1
    end
end
local jobsPerHour = jobTotal / jobCount

print(
    string.format(
        "Courses : performance %.2f, %d participants, %d s hors course par épreuve ; métiers (moyenne) %.0f cr/h",
        performanceTarget,
        field,
        OVERHEAD_S,
        jobsPerHour
    )
)
print(
    string.format(
        "%-14s %-9s %7s %9s %9s %9s %9s %7s",
        "Parcours",
        "Discipl.",
        "réf. s",
        "prot./h",
        "réal.br/h",
        "réal.net/h",
        "+hors/h",
        "/métiers"
    )
)

local low, high = math.huge, 0
for _, course in RaceCourses.forPlace("OpenWorld") do
    local built = RaceCourse.build(course)
    if built == nil then
        continue
    end
    local discipline = RaceDefinitions.Disciplines[course.Discipline]
    -- Résultat type à la performance visée : temps = référence / performance,
    -- place médiane (épreuve à grille), score = référence × performance (drift).
    local official = built.ParTimeS / performanceTarget
    local position = math.ceil(field / 2)
    local ctx = {
        ResultId = "sim",
        EntryId = nil,
        RaceId = "sim",
        CourseId = course.Id,
        Discipline = course.Discipline,
        Kind = "Official",
        Mode = "Protected",
        Outcome = "Finished",
        Position = position,
        Field = if discipline.Start == "Grid" then field else 1,
        OfficialS = official,
        Score = if built.ParScore then built.ParScore * performanceTarget else nil,
        ParTimeS = built.ParTimeS,
        ParScore = built.ParScore,
        TotalKm = built.TotalM / 1000,
        Difficulty = course.Difficulty,
        RewardEligible = true,
        Conditions = "Sec-v1",
        RecordEligible = false,
        RecordKey = "",
        Ranked = nil,
    }
    local profile = ProfileSchema.new(1, 0, "Dev")
    local protected = RaceRewards.quote(profile, ctx, 0).Credits
    ctx.Mode = "Realistic"
    local realistic = RaceRewards.quote(profile, ctx, 0).Credits
    local cost = (RaceDefinitions.EnergyCostPerKm + discipline.WearCostPerKm) * built.TotalM / 1000
    local raceS = if discipline.Start == "Zone" then built.ParTimeS else official
    local perHour = 3600 / raceS
    local withOverhead = 3600 / (raceS + OVERHEAD_S)
    local net = (realistic - cost) * perHour
    low = math.min(low, protected * perHour)
    high = math.max(high, protected * perHour)
    print(
        string.format(
            "%-14s %-9s %7.0f %9.0f %9.0f %9.0f %9.0f %7.2f",
            course.Id,
            course.Discipline,
            built.ParTimeS,
            protected * perHour,
            realistic * perHour,
            net,
            protected * withOverhead,
            protected * perHour / jobsPerHour
        )
    )
end
print(string.format("Écart protégé max/min entre parcours : %.2f", high / low))
