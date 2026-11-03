--!strict
--[[
    Contrôle des parcours de course (lot 0.6), hors Roblox.
    Usage : lune run tools/racing/courses.luau build/AutomotiveWorld.rbxlx

    Construit chaque parcours versionné sur les données de la carte et affiche
    sa longueur mesurée, ses points de contrôle, sa zone, ses revêtements, la
    présence de circulation et les erreurs de validation éventuelles.
]]

local process = require("@lune/process")
local Harness = require("../../tests/lune/Harness")

Harness.loadPlace(process.args[1] or "build/AutomotiveWorld.rbxlx")
local RaceCourse = Harness.require("ServerScriptService.AutomotiveWorldServer.Racing.RaceCourse")
local RaceCourses = Harness.require("ReplicatedStorage.Shared.Racing.RaceCourses")
local WorldLayout = Harness.require("ReplicatedStorage.Shared.World.WorldLayout")

local failures = 0
for _, course in RaceCourses.All do
    local errors = RaceCourse.validate(course)
    local built = RaceCourse.build(course)
    local zone = if built and course.Place == "OpenWorld" then WorldLayout.zoneOf(built.Start.X, built.Start.Z) else "-"
    print(
        string.format(
            "%-14s %-9s tracé %6.0f m (déclaré %5d) total %6.0f m  %2d CP  zone %-10s surf %-14s circ %-5s réf %4.0f s  %s",
            course.Id,
            course.Discipline,
            if built then (if course.Closed then built.LengthM else built.LengthM) else 0,
            course.LengthM,
            if built then built.TotalM else 0,
            if built then #built.Checkpoints else 0,
            zone,
            if built then table.concat(built.Surfaces, ",") else "-",
            if built then tostring(built.Traffic) else "-",
            if built then built.ParTimeS else 0,
            if #errors == 0 then "OK" else table.concat(errors, " ; ")
        )
    )
    if #errors > 0 then
        failures += 1
    end
end
process.exit(if failures == 0 then 0 else 1)
