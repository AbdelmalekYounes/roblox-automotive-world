--!strict
-- Lot 0.9.2 (QA-A09) : position des poteaux des portiques d'arrivée des parcours de la place
-- de développement (comme RaceInstallations : ± (demi-largeur + 2 studs) de part et d'autre).
local process = require("@lune/process")
local Harness = require("../Harness")
Harness.loadPlace(process.args[1] or "build/AutomotiveWorld.rbxlx")
local RaceCourse = Harness.require("ServerScriptService.AutomotiveWorldServer.Racing.RaceCourse")
local S = 1 / 0.28
local built = RaceCourse.buildPlace("Dev")
for id, course in built do
    if not course.Closed then
        local f = course.Finish
        -- RaceInstallations.arch : demi-écart (studs) = largeur × S / 2 + 2, largeur = 2 × demi-largeur.
        local half = course.RoadHalfWidthM + 2 / S -- en mètres
        local h = f.Heading
        -- Axe latéral (droite) d'un cap h (0 = nord, -z) : (cos h, sin h) en (x, z).
        local rx, rz = math.cos(h), math.sin(h)
        print(
            string.format(
                "%-12s demi-largeur %.1f m, arrivée (%.1f, %.1f) m, cap %.0f° ; poteaux (%.1f, %.1f) et (%.1f, %.1f) m = x %.1f / %.1f studs",
                id,
                course.RoadHalfWidthM,
                f.X,
                f.Z,
                math.deg(h),
                f.X - rx * half,
                f.Z - rz * half,
                f.X + rx * half,
                f.Z + rz * half,
                (f.X - rx * half) * S,
                (f.X + rx * half) * S
            )
        )
    end
end
