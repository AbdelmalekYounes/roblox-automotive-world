--!strict
--[[
    Points d'intérêt de la carte et du GPS (lot 0.7), PURS.

    AUCUN catalogue de positions indépendant : chaque point provient d'un
    registre existant et garde son identifiant d'origine :
    - lieux de la progression et de l'économie (Locations : garages publics,
      concessions, stations, bornes, lavages, entrées des propriétés) ;
    - points d'inscription des parcours de course (RaceCourse, lot 0.6) ;
    - lieux sociaux et points d'arrivée de la carte (WorldLayout : SocialSpot,
      PlayerSpawn) ;
    - par joueur : SES propriétés (jamais celles des autres) et l'objectif
      de SA mission (données du serveur des missions).
    validate() vérifie identifiants uniques, sources connues, coordonnées
    finies dans la carte.
]]

local PointsOfInterest = {}

PointsOfInterest.HalfExtentM = 6000

export type Point = {
    Id: string, -- identifiant d'origine (préfixé par la source)
    Kind: string,
    Name: string,
    X: number,
    Z: number,
    Source: string, -- "Locations" | "RaceCourse" | "WorldLayout" | "Profile" | "Mission"
}

local PLACE_KINDS: { [string]: string } = {
    PublicGarage = "PublicGarage",
    Dealership = "Dealership",
    FuelStation = "FuelStation",
    ChargingHub = "ChargingHub",
    CarWash = "CarWash",
    Entrance = "PropertyOffer",
}

export type PlaceInput = { Id: string, Kind: string, Label: string, X: number, Z: number }
export type RaceInput = { Id: string, Name: string, X: number, Z: number }
export type PlacementInput = { Id: string, Kind: string, Name: string, X: number, Z: number }

-- Points publics (identiques pour tous les joueurs).
function PointsOfInterest.public(
    places: { PlaceInput },
    races: { RaceInput },
    placements: { PlacementInput }
): { Point }
    local list: { Point } = {}
    for _, place in places do
        local kind = PLACE_KINDS[place.Kind]
        if kind then
            table.insert(list, {
                Id = "L:" .. place.Id,
                Kind = kind,
                Name = place.Label,
                X = place.X,
                Z = place.Z,
                Source = "Locations",
            })
        end
    end
    for _, race in races do
        table.insert(list, {
            Id = "R:" .. race.Id,
            Kind = "RaceStart",
            Name = race.Name,
            X = race.X,
            Z = race.Z,
            Source = "RaceCourse",
        })
    end
    for _, placement in placements do
        if placement.Kind == "SocialSpot" or placement.Kind == "PlayerSpawn" then
            table.insert(list, {
                Id = "W:" .. placement.Id,
                Kind = placement.Kind :: any,
                Name = placement.Name,
                X = placement.X,
                Z = placement.Z,
                Source = "WorldLayout",
            })
        end
    end
    table.sort(list, function(a, b)
        return a.Id < b.Id
    end)
    return list
end

--[[
    Points propres à UN joueur : ses propriétés (entrée de l'offre possédée)
    et l'objectif de sa mission. `entranceOf(offerId)` résout l'entrée.
]]
function PointsOfInterest.personal(
    properties: { { Id: string, OfferId: string, Name: string } },
    entranceOf: (string) -> PlaceInput?,
    mission: { Label: string, X: number, Z: number }?
): { Point }
    local list: { Point } = {}
    for _, property in properties do
        local entrance = entranceOf(property.OfferId)
        if entrance then
            table.insert(list, {
                Id = "P:" .. property.Id,
                Kind = "Property",
                Name = property.Name,
                X = entrance.X,
                Z = entrance.Z,
                Source = "Profile",
            })
        end
    end
    if mission then
        table.insert(list, {
            Id = "M:active",
            Kind = "MissionTarget",
            Name = mission.Label,
            X = mission.X,
            Z = mission.Z,
            Source = "Mission",
        })
    end
    return list
end

-- Contrôle : identifiants uniques, préfixe = source, coordonnées valides.
function PointsOfInterest.validate(points: { Point }): { string }
    local errors: { string } = {}
    local seen: { [string]: boolean } = {}
    local prefix = { Locations = "L:", RaceCourse = "R:", WorldLayout = "W:", Profile = "P:", Mission = "M:" }
    for _, point in points do
        if seen[point.Id] then
            table.insert(errors, "Duplicate:" .. point.Id)
        end
        seen[point.Id] = true
        local expected = (prefix :: any)[point.Source]
        if expected == nil or string.sub(point.Id, 1, 2) ~= expected then
            table.insert(errors, "Source:" .. point.Id)
        end
        if
            point.X ~= point.X
            or point.Z ~= point.Z
            or math.abs(point.X) > PointsOfInterest.HalfExtentM
            or math.abs(point.Z) > PointsOfInterest.HalfExtentM
        then
            table.insert(errors, "Position:" .. point.Id)
        end
        if type(point.Name) ~= "string" or point.Name == "" then
            table.insert(errors, "Name:" .. point.Id)
        end
    end
    return errors
end

return table.freeze(PointsOfInterest)
