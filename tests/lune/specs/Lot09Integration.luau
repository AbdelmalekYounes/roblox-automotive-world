--!strict
-- Lot 0.9 — intégration et validation globale : contrôles de non-régression des
-- défauts corrigés pendant le lot et des lacunes comblées (règles PURES et
-- vérifications statiques du code construit). Les essais dans le moteur sont
-- dans les sessions VM (docs/lot-0.9/RAPPORT_VALIDATION_GLOBALE.md).

local SERVER = "ServerScriptService.AutomotiveWorldServer."

return function(T: any, H: any)
    local StationRules = H.require(SERVER .. "Economy.StationRules")
    local Localization = H.require("ReplicatedStorage.Shared.UI.Localization")
    local MissionCargo = H.require(SERVER .. "Economy.MissionCargo")

    local function source(path: string): string
        local node = H.game()
        for segment in string.gmatch(path, "[^%.]+") do
            node = node:FindFirstChild(segment)
        end
        return node.Source
    end

    T.suite("Lot 0.9 — non-régression et lacunes comblées")

    T.test("stations : une session par pompe ou borne, refus au-delà, capacité par défaut", function()
        local station = { Id = "S1", Pumps = 2, Chargers = 1 }
        local sessions = {}
        T.truthy((StationRules.canStart(sessions, station, false)), "première pompe")
        table.insert(sessions, { PlaceId = "S1", Electric = false })
        T.truthy((StationRules.canStart(sessions, station, false)), "seconde pompe")
        table.insert(sessions, { PlaceId = "S1", Electric = false })
        T.equal(select(2, StationRules.canStart(sessions, station, false)), "StationFull", "troisième refusée")
        T.truthy((StationRules.canStart(sessions, station, true)), "la borne reste libre")
        table.insert(sessions, { PlaceId = "S1", Electric = true })
        T.equal(select(2, StationRules.canStart(sessions, station, true)), "StationFull")
        T.truthy((StationRules.canStart(sessions, { Id = "S2", Pumps = 1 }, false)), "autre lieu indépendant")
        T.equal(StationRules.capacity({ Id = "DEV" }, false), StationRules.DefaultSlots, "zone d'essai : défaut")
        T.equal(select(2, StationRules.canStart({}, { Id = "S3", Chargers = 0 }, true)), "NoCharger")
        T.truthy(Localization.has("StationFull"), "refus traduit")
    end)

    T.test("missions : colis, passager et pièce visibles seulement pendant le transport", function()
        T.equal(MissionCargo.load("Delivery", 4, 1), nil, "avant le chargement")
        T.equal(MissionCargo.load("Delivery", 4, 2).Count, 3, "trois livraisons restantes")
        T.equal(MissionCargo.load("Delivery", 4, 4).Count, 1, "dernière livraison")
        T.equal(MissionCargo.load("Delivery", 4, 5), nil, "mission terminée")
        T.equal(MissionCargo.load("Taxi", 2, 2).Kind, "Passenger")
        T.equal(MissionCargo.load("Taxi", 2, 1), nil, "passager pas encore pris")
        T.equal(MissionCargo.load("SpecialParts", 2, 2).Kind, "Part")
        T.equal(MissionCargo.load("Exploration", 5, 3), nil, "aucun chargement pour les autres métiers")
        T.equal(MissionCargo.key(nil), "")
        T.truthy(
            MissionCargo.key(MissionCargo.load("Delivery", 4, 2))
                ~= MissionCargo.key(MissionCargo.load("Delivery", 4, 3))
        )
    end)

    T.test("courses : l'arbre de départ du drag n'est plus au centre de la chaussée", function()
        local code = source(SERVER .. "Racing.RaceInstallations")
        T.truthy(
            string.find(code, "flatFrame(start.X, start.Z, startY, start.Heading) * CFrame.new(side, 0, 0)", 1, true)
                ~= nil,
            "mât décalé en bord de chaussée (défaut de la campagne VM 20261103-151033)"
        )
    end)
end
