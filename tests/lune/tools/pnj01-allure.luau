--!strict
-- Outil en lecture seule (lot PNJ-01) : positions des articulations des piétons sur un cycle (marche, course), en
-- JSON, pour tracer une vue de profil hors Roblox. Sorties du modèle, pas des mesures en jeu.
-- Usage : lune run tests/lune/tools/pnj01-allure.luau build/AutomotiveWorld.rbxlx > allure.json
local process = require("@lune/process")
local serde = require("@lune/serde")
local Harness = require("../Harness")
Harness.loadPlace(process.args[1])
local Gait = Harness.require("ReplicatedStorage.Shared.World.PedestrianGait")
local PnjKits = Harness.require("ReplicatedStorage.Shared.World.PnjKits")
local roblox = require("@lune/roblox")
local CFrame = roblox.CFrame

local out = {}
for _, case in { { Kind = "Walk", Speed = 1.4 }, { Kind = "Run", Speed = 3.2 } } do
    local frames = {}
    for i = 0, 7 do
        local joints = Gait.jointFrames(Gait.pose(case.Kind, i / 8, case.Speed, 0), 1)
        local points = {}
        for _, joint in PnjKits.Joints do
            local p = joints[joint.Name].Position
            points[joint.Name] = { p.X, p.Y, p.Z }
        end
        for _, side in { "G", "D" } do
            local a = (joints["Genou" .. side] * CFrame.new(0, -0.47, 0)).Position
            points["Cheville" .. side] = { a.X, a.Y, a.Z }
            local h = (joints["Coude" .. side] * CFrame.new(0, -0.3, 0)).Position
            points["Main" .. side] = { h.X, h.Y, h.Z }
        end
        local head = (joints.Cou * CFrame.new(0, 0.15, 0)).Position
        points.Tete = { head.X, head.Y, head.Z }
        table.insert(frames, points)
    end
    out[case.Kind] = frames
end
print(serde.encode("json", out))
