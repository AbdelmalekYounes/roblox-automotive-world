--!strict
-- Phase 1 de l'Aster : pose assise du jeu (activable, sans effet sur les carrosseries
-- provisoires) et gabarit technique (décisions D1, D3 du propriétaire, 2026-11-04).
-- Les mesures avec avatars R15 sont faites dans la VM (session « aster »).

local AsterTemplate = require("../../studio/AsterTemplate")

local SHARED = "ReplicatedStorage.Shared."

return function(T: any, H: any)
    local SeatPose = H.require(SHARED .. "Vehicles.SeatPose")
    local Definitions = H.require(SHARED .. "Vehicles.VehicleDefinitions")
    local Dynamics = H.require(SHARED .. "Vehicles.Physics.VehicleDynamics")
    local Constants = H.require(SHARED .. "Vehicles.VehicleConstants")

    local function source(path: string): string
        local node = H.game()
        for segment in string.gmatch(path, "[^%.]+") do
            node = node:FindFirstChild(segment)
        end
        return node.Source
    end

    T.suite("Phase 1 de l'Aster — pose assise et gabarit")

    T.test("Pose du jeu : conducteur et passager, bras seulement au volant, progression bornée", function()
        local drive = SeatPose.poseFor("Conduite")
        local ride = SeatPose.poseFor("Passager")
        T.truthy(drive ~= nil and ride ~= nil, "deux poses")
        T.truthy(drive.LeftShoulder ~= nil and drive.RightElbow ~= nil, "bras vers le volant au conducteur")
        T.truthy(ride.LeftShoulder == nil and ride.RightElbow == nil, "bras libres au passager")
        T.truthy(drive.Root.Down > 0 and drive.Waist.Pitch > 0, "bassin abaissé, buste incliné")
        T.equal(SeatPose.poseFor(nil), nil, "aucune pose sans attribut")
        T.equal(SeatPose.poseFor("Inconnue"), nil, "valeur inconnue ignorée")
        local pitch, _, down = SeatPose.offset(drive.Root, 2)
        T.near(down, drive.Root.Down, 1e-9, "progression bornée à 1")
        local zero, _, none = SeatPose.offset(drive.Waist, -1)
        T.equal(zero, 0)
        T.equal(none, 0)
        local _, yawLeft = SeatPose.offset(drive.LeftShoulder, 1)
        local _, yawRight = SeatPose.offset(drive.RightShoulder, 1)
        T.truthy(yawLeft < 0 and yawRight > 0, "bras rentrés vers le volant (symétriques)")
        T.near(pitch, 0, 1e-9, "aucune rotation du bassin")
        for name in SeatPose.ArmJoints do
            T.truthy(ride[name] == nil, name .. " : jamais au passager")
        end
    end)

    T.test("Pose du jeu : sans effet sur les carrosseries provisoires, client démarré", function()
        local factory = source("ServerScriptService.AutomotiveWorldServer.Vehicles.VehicleFactory")
        local kits = source("ServerScriptService.AutomotiveWorldServer.Vehicles.BodyKits")
        T.truthy(string.find(factory, "AWSeatPose", 1, true) == nil, "aucun siège du jeu n'est marqué")
        T.truthy(string.find(kits, "AWSeatPose", 1, true) == nil, "aucune carrosserie provisoire n'est marquée")
        local bootstrap = source("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.Bootstrap")
        T.truthy(string.find(bootstrap, "SeatPoseController", 1, true) ~= nil, "contrôleur démarré")
        local controller =
            source("StarterPlayer.StarterPlayerScripts.AutomotiveWorldClient.Vehicles.SeatPoseController")
        T.truthy(string.find(controller, "PreSimulation", 1, true) ~= nil, "appliquée après l'animation")
        T.truthy(string.find(controller, '"AWPhoneRaised"', 1, true) ~= nil, "bras laissés au téléphone (QA-A10)")
    end)

    T.test("Gabarit de l'Aster : cotes D1, roues de la définition, physique inchangée", function()
        local definition = Definitions.get("wk_aster")
        local layout = Dynamics.wheelLayout(definition)
        local template = AsterTemplate.build(definition, layout, Constants.MetersPerStud, nil)
        local S = 1 / Constants.MetersPerStud
        T.near(template.RoofUnder - template.SeatTop, 4.30, 1e-6, "assise → pavillon : 4,30 st")
        T.near(template.SeatTop, 0.36 - 0.4, 1e-6, "assise abaissée de 0,4 st")
        T.truthy(template.Belt > template.SeatTop + 1.5, "ligne de caisse haute")
        local wheels = 0
        for _, item in template.Boxes do
            if string.sub(item.Name, 1, 4) == "Roue" then
                wheels += 1
                local place = layout[tonumber(string.sub(item.Name, 5)) :: number]
                T.near(item.Center[1], place.Lateral * S, 1e-6, item.Name .. " : voie")
                T.near(item.Center[3], -place.Longitudinal * S, 1e-6, item.Name .. " : empattement")
            end
        end
        T.equal(wheels, 4, "quatre roues")
        T.near(definition.Chassis.HeightM, 1.47, 1e-9, "hauteur physique de la définition inchangée")
        T.near(definition.Chassis.LengthM, 4.25, 1e-9, "longueur inchangée")
        local seats = 0
        for _, item in template.Boxes do
            if item.Seat then
                seats += 1
                T.truthy(SeatPose.poseFor(item.Seat) ~= nil, item.Name .. " : pose du jeu")
            end
        end
        T.equal(seats, 2, "deux sièges marqués")
    end)
end
