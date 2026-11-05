--!strict
--[[
    Mode photo (lot 0.8, §9.3, AUD-PHOTO-01, SCN-20), règles PURES.

    - Contextes : à pied, ou conducteur À L'ARRÊT. Passager en mouvement :
      support « conditionnel » du cahier des charges, NON retenu ici (refusé).
      Jamais pendant une épreuve (participant à une course) : pas de caméra
      libre en compétition.
    - Caméra BORNÉE : rayon maximal autour du sujet, hauteur minimale au-dessus
      du sujet, et jamais au-delà d'un obstacle entre le sujet et la caméra
      (le client tronque au premier impact) : on ne traverse pas un mur pour
      voir l'intérieur d'une propriété privée.
    - Réglages locaux : zoom (champ de vision), exposition, profondeur de
      champ, filtres. Rien de global : aucune pause, aucune météo modifiée.
]]

local PhotoRules = {}

export type Context = {
    OnFoot: boolean,
    Seat: string, -- "Driver" | "Passenger" | "None"
    SpeedKmh: number,
    Racing: boolean,
}

PhotoRules.StoppedKmh = 2
PhotoRules.MaxRadiusM = 15
PhotoRules.MinHeightM = -1.5 -- sous le sujet (m), bornée pour ne pas passer sous le sol
PhotoRules.Fov = table.freeze({ Min = 20, Max = 90, Default = 70, Step = 5 })
PhotoRules.Exposure = table.freeze({ Min = -1, Max = 1, Step = 0.1 })
PhotoRules.Focus = table.freeze({ Min = 2, Max = 60, Step = 2 })

PhotoRules.Filters = table.freeze({ "None", "Warm", "Cool", "Mono", "Vintage", "Vivid" })

export type FilterGrade = { Tint: { number }, Saturation: number, Contrast: number }

local FILTERS: { [string]: FilterGrade } = {
    None = { Tint = { 255, 255, 255 }, Saturation = 0, Contrast = 0 },
    Warm = { Tint = { 255, 236, 212 }, Saturation = 0.1, Contrast = 0.05 },
    Cool = { Tint = { 214, 230, 255 }, Saturation = 0, Contrast = 0.05 },
    Mono = { Tint = { 255, 255, 255 }, Saturation = -1, Contrast = 0.15 },
    Vintage = { Tint = { 255, 230, 190 }, Saturation = -0.35, Contrast = -0.05 },
    Vivid = { Tint = { 255, 255, 255 }, Saturation = 0.35, Contrast = 0.12 },
}

function PhotoRules.filter(name: any): FilterGrade
    return FILTERS[if type(name) == "string" then name else "None"] or FILTERS.None
end

-- Le mode photo peut-il s'ouvrir (ou rester ouvert) ? Renvoie (autorisé, raison).
function PhotoRules.allowed(context: Context): (boolean, string?)
    if context.Racing then
        return false, "PhotoRacing"
    end
    if context.OnFoot then
        return true, nil
    end
    if context.Seat == "Driver" then
        if context.SpeedKmh > PhotoRules.StoppedKmh then
            return false, "PhotoDriverMoving"
        end
        return true, nil
    end
    if context.Seat == "Passenger" then
        if context.SpeedKmh > PhotoRules.StoppedKmh then
            return false, "PhotoPassengerMoving"
        end
        return true, nil
    end
    return false, "PhotoUnavailable"
end

export type Vec = { X: number, Y: number, Z: number }

--[[
    Position de caméra bornée (mètres) : à moins de MaxRadiusM du sujet et
    pas plus bas que MinHeightM sous lui. `obstacleM` : distance du premier
    obstacle entre le sujet et la caméra voulue (nil : aucun) ; la caméra
    s'arrête juste avant.
]]
function PhotoRules.clamp(subject: Vec, desired: Vec, obstacleM: number?): Vec
    local dx, dy, dz = desired.X - subject.X, desired.Y - subject.Y, desired.Z - subject.Z
    dy = math.max(dy, PhotoRules.MinHeightM)
    local length = math.sqrt(dx * dx + dy * dy + dz * dz)
    local limit = PhotoRules.MaxRadiusM
    if obstacleM ~= nil then
        limit = math.min(limit, math.max(0, obstacleM - 0.3))
    end
    if length > limit and length > 0 then
        local k = limit / length
        dx, dy, dz = dx * k, dy * k, dz * k
    end
    return { X = subject.X + dx, Y = subject.Y + dy, Z = subject.Z + dz }
end

function PhotoRules.step(value: number, delta: number, range: { Min: number, Max: number }): number
    return math.clamp(value + delta, range.Min, range.Max)
end

return table.freeze(PhotoRules)
