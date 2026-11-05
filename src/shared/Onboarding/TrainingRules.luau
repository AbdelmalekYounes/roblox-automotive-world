--!strict
--[[
    Exercices de formation des nouveaux joueurs (lot 0.8), PURS : chaque
    exercice suit des OBSERVATIONS (vitesse, cap, rapport, position,
    destination GPS, lieu atteint, mission, panneau des courses) et dit s'il
    est réussi. Facultatifs, rejouables, ils ne rapportent rien : leur seul
    effet durable est d'être notés « faits » (OnboardingRules.exercise).
]]

local TrainingRules = {}

export type Observation = {
    T: number,
    SpeedKmh: number,
    Heading: number, -- rad
    Gear: number,
    X: number,
    Z: number,
    InVehicle: boolean,
    GpsActive: boolean?,
    NearGarage: boolean?,
    MissionActive: boolean?,
    RacesOpened: boolean?,
}

export type Progress = {
    Id: string,
    Done: boolean,
    Phase: number,
    Since: number?,
    StartHeading: number?,
    StartGear: number?,
    Target: { X: number, Z: number }?,
}

TrainingRules.Params = table.freeze({
    AccelerateKmh = 50,
    StopKmh = 2,
    TurnDeg = 90,
    TurnMinKmh = 12,
    ParkRadiusM = 5,
    ParkHoldS = 2,
    ParkDistanceM = 30,
})

function TrainingRules.start(id: string, first: Observation?): Progress
    local progress: Progress =
        { Id = id, Done = false, Phase = 1, Since = nil, StartHeading = nil, StartGear = nil, Target = nil }
    if first then
        progress.StartHeading = first.Heading
        progress.StartGear = first.Gear
        if id == "Park" then
            -- Place à 30 m devant le joueur.
            progress.Target = {
                X = first.X + math.sin(first.Heading) * TrainingRules.Params.ParkDistanceM,
                Z = first.Z - math.cos(first.Heading) * TrainingRules.Params.ParkDistanceM,
            }
        end
    end
    return progress
end

local function angleDeg(a: number, b: number): number
    return math.abs(math.deg(((b - a + math.pi) % (2 * math.pi)) - math.pi))
end

-- Intègre une observation ; renvoie vrai quand l'exercice vient d'être réussi.
function TrainingRules.observe(progress: Progress, o: Observation): boolean
    if progress.Done then
        return false
    end
    local p = TrainingRules.Params
    local id = progress.Id
    if id == "AccelerateBrake" then
        if progress.Phase == 1 and o.InVehicle and o.SpeedKmh >= p.AccelerateKmh then
            progress.Phase = 2
        elseif progress.Phase == 2 and o.SpeedKmh <= p.StopKmh then
            progress.Done = true
        end
    elseif id == "Turn" then
        progress.StartHeading = progress.StartHeading or o.Heading
        if
            o.InVehicle
            and o.SpeedKmh >= p.TurnMinKmh
            and angleDeg(progress.StartHeading :: number, o.Heading) >= p.TurnDeg
        then
            progress.Done = true
        end
    elseif id == "Shift" then
        progress.StartGear = progress.StartGear or o.Gear
        if o.InVehicle and o.Gear >= 2 and o.Gear ~= progress.StartGear then
            progress.Done = true
        end
    elseif id == "Park" then
        local target = progress.Target
        if target == nil then
            progress.Target = {
                X = o.X + math.sin(o.Heading) * p.ParkDistanceM,
                Z = o.Z - math.cos(o.Heading) * p.ParkDistanceM,
            }
            return false
        end
        local d = math.sqrt((o.X - target.X) ^ 2 + (o.Z - target.Z) ^ 2)
        if o.InVehicle and d <= p.ParkRadiusM and o.SpeedKmh <= p.StopKmh then
            progress.Since = progress.Since or o.T
            if o.T - (progress.Since :: number) >= p.ParkHoldS then
                progress.Done = true
            end
        else
            progress.Since = nil
        end
    elseif id == "UseGps" then
        progress.Done = o.GpsActive == true
    elseif id == "ReachGarage" then
        progress.Done = o.NearGarage == true
    elseif id == "AcceptMission" then
        progress.Done = o.MissionActive == true
    elseif id == "DiscoverRaces" then
        progress.Done = o.RacesOpened == true
    end
    return progress.Done
end

return table.freeze(TrainingRules)
