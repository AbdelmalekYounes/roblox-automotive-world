--!strict
-- Lot 0.2 — architectures motrices, différentiels, pneus (sec/mouillé, frottement
-- statique, relaxation). Banc planaire hors Roblox : sorties du modèle, pas des
-- mesures en jeu. Pour isoler l'effet de l'architecture, les variantes FWD/AWD
-- sont construites sur le châssis du P-01 (seule la transmission change).

local PlanarSim = require("../PlanarSim")

local DT = 1 / 60

local function input(throttle: number, brake: number, steer: number, handbrake: boolean?)
    return { Throttle = throttle, Brake = brake, Steer = steer, Handbrake = handbrake == true, Clutch = 0 }
end

local function deepCopy(value: any): any
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, child in value do
        copy[key] = deepCopy(child)
    end
    return copy
end

local OPEN = { Kind = "Open", PreloadNm = 0, PowerLockRatio = 0, CoastLockRatio = 0 }

return function(T: any, H: any)
    local Dynamics = H.require("ReplicatedStorage.Shared.Vehicles.Physics.VehicleDynamics")
    local TireModel = H.require("ReplicatedStorage.Shared.Vehicles.Physics.TireModel")
    local Driveline = H.require("ReplicatedStorage.Shared.Vehicles.Physics.Driveline")
    local Definitions = H.require("ReplicatedStorage.Shared.Vehicles.VehicleDefinitions")
    local P01 = Definitions.get("proto_p01")
    local P02 = Definitions.get("proto_p02")

    local function layoutVariant(layout: string, share: number, center: any?, rear: any?): any
        local copy = deepCopy(P01)
        copy.Id = "essai_" .. layout
        copy.Powertrain.Drivetrain.Layout = layout
        copy.Powertrain.Drivetrain.FrontTorqueShare = share
        copy.Powertrain.Drivetrain.CenterDifferential = center
        if rear then
            copy.Powertrain.Drivetrain.RearDifferential = rear
        end
        local ok, errors = Definitions.validate(copy)
        assert(ok, table.concat(errors, " ; "))
        return copy
    end

    local RWD = P01
    local FWD = layoutVariant("FWD", 1, nil)
    local AWD =
        layoutVariant("AWD", 0.4, { Kind = "LimitedSlip", PreloadNm = 50, PowerLockRatio = 0.3, CoastLockRatio = 0.2 })
    local RWD_LSD = layoutVariant(
        "RWD",
        0,
        nil,
        { Kind = "LimitedSlip", PreloadNm = 60, PowerLockRatio = 0.5, CoastLockRatio = 0.3 }
    )

    local function timeTo(definition: any, kmh: number, surface: any, wet: boolean?): (number?, { any }, any)
        local reached: number? = nil
        local snaps, state = PlanarSim.run(Dynamics, definition, {
            Dt = DT,
            Duration = 25,
            Surface = surface,
            Wet = wet,
            Input = function()
                return input(1, 0, 0)
            end,
            Stop = function(s)
                if s.Forward * 3.6 >= kmh then
                    reached = s.Time
                    return true
                end
                return false
            end,
        })
        return reached, snaps, state
    end

    T.suite("Lot 0.2 — architectures motrices et différentiels")

    T.test("répartition : traction, propulsion, intégrale", function()
        local fwd = Driveline.wheelDriveShares(FWD.Powertrain.Drivetrain)
        T.equal(fwd[1] + fwd[2], 1)
        T.equal(fwd[3] + fwd[4], 0)
        local awd = Driveline.wheelDriveShares(AWD.Powertrain.Drivetrain)
        T.near(awd[1] + awd[2], 0.4, 1e-12)
        T.near(awd[3] + awd[4], 0.6, 1e-12)
    end)

    T.test("différentiel ouvert : couples égaux ; autobloquant : transfert borné vers la roue lente", function()
        local out = { 0, 0, 0, 0 }
        local inertias = { 1.2, 1.2, 1.2, 1.2 }
        Driveline.distribute(P01.Powertrain.Drivetrain, 1000, { 0, 0, 80, 20 }, inertias, DT / 4, out)
        T.near(out[3], 500, 1e-9, "ouvert : moitié à gauche")
        T.near(out[4], 500, 1e-9, "ouvert : moitié à droite")
        Driveline.distribute(RWD_LSD.Powertrain.Drivetrain, 1000, { 0, 0, 80, 20 }, inertias, DT / 4, out)
        local capacity = 60 + 0.5 * 1000
        T.near(out[4] - out[3], capacity, 1e-6, "roue lente (droite) favorisée de la capacité de blocage")
        T.near(out[3] + out[4], 1000, 1e-9, "couple total conservé")
    end)

    T.test("faible adhérence (μ 0,35) : l'intégrale accélère nettement mieux", function()
        local tRwd = timeTo(RWD, 50, 0.35)
        local tFwd = timeTo(FWD, 50, 0.35)
        local tAwd = timeTo(AWD, 50, 0.35)
        T.truthy(tRwd and tFwd and tAwd, "50 km/h atteints")
        T.truthy((tAwd :: number) < 0.85 * math.min(tRwd :: number, tFwd :: number), "AWD plus rapide")
        T.note(
            string.format(
                "0–50 km/h sur μ 0,35 (châssis P-01) : RWD %.2f s, FWD %.2f s, AWD %.2f s",
                tRwd :: number,
                tFwd :: number,
                tAwd :: number
            )
        )
    end)

    T.test("perte de motricité (adhérence dissymétrique) : l'autobloquant limite le patinage", function()
        local split = { 1, 1, 0.15, 1 } -- roue arrière gauche sur une plaque glissante
        local tOpen, _, openState = timeTo(RWD, 40, split)
        local tLsd, _, lsdState = timeTo(RWD_LSD, 40, split)
        T.truthy(tOpen and tLsd, "40 km/h atteints")
        T.truthy(
            (tLsd :: number) < 0.85 * (tOpen :: number),
            string.format("%.2f s < %.2f s", tLsd :: number, tOpen :: number)
        )
        local _ = openState
        local _2 = lsdState
        T.note(
            string.format(
                "0–40 km/h, roue AR gauche sur μ 0,15 : ouvert %.2f s, autobloquant %.2f s",
                tOpen :: number,
                tLsd :: number
            )
        )
    end)

    T.test("virage sous charge : la propulsion survire, la traction sous-vire", function()
        local function powerOn(definition: any): number
            local yawBefore, yawAfter = 0, 0
            PlanarSim.run(Dynamics, definition, {
                Dt = DT,
                Duration = 6,
                InitialForward = 40 / 3.6,
                Surface = 0.6,
                Prepare = function(state)
                    state.Gear = 2
                end,
                Input = function(t, s)
                    -- Virage stabilisé à charge légère, puis pleine charge.
                    if t < 3.5 then
                        yawBefore = s.YawRate
                        return input(0.2, 0, 0.25)
                    end
                    yawAfter = s.YawRate
                    return input(1, 0, 0.25)
                end,
            })
            return yawAfter / math.max(yawBefore, 1e-3)
        end
        local rwd, fwd = powerOn(RWD), powerOn(FWD)
        T.truthy(rwd > 1.15 and fwd < 1.0, string.format("lacet après/avant : RWD %.2f, FWD %.2f", rwd, fwd))
        T.note(
            string.format(
                "Pleine charge en virage (μ 0,6) — rapport de lacet après/avant : RWD %.2f, FWD %.2f",
                rwd,
                fwd
            )
        )
    end)

    T.suite("Lot 0.2 — pneus et adhérence")

    local function brakingDistance(definition: any, wet: boolean): number
        local snaps = PlanarSim.run(Dynamics, definition, {
            Dt = DT,
            Duration = 15,
            InitialForward = 80 / 3.6,
            Wet = wet,
            Input = function()
                return input(0, 1, 0)
            end,
            Stop = function(s)
                return s.Forward < 0.2
            end,
        })
        return snaps[#snaps].Distance
    end

    T.test("mouillé : freinage plus long et virage moins rapide qu'au sec", function()
        local dry, wet = brakingDistance(P02, false), brakingDistance(P02, true)
        T.truthy(wet > dry * 1.15, string.format("%.1f m > 1,15 × %.1f m", wet, dry))
        local function maxLateral(isWet: boolean): number
            local peak = 0
            PlanarSim.run(Dynamics, P01, {
                Dt = DT,
                Duration = 6,
                InitialForward = 70 / 3.6,
                Wet = isWet,
                Prepare = function(state)
                    state.Gear = 3
                end,
                Input = function(_, s)
                    peak = math.max(peak, math.abs(s.LatAccel))
                    return input(0.3, 0, 0.7)
                end,
            })
            return peak
        end
        local latDry, latWet = maxLateral(false), maxLateral(true)
        T.truthy(latWet < latDry * 0.85, string.format("%.2f < 0,85 × %.2f m/s²", latWet, latDry))
        T.note(
            string.format(
                "P-02 80–0 km/h : sec %.1f m, mouillé %.1f m ; P-01 accélération latérale max : sec %.2f, mouillé %.2f m/s²",
                dry,
                wet,
                latDry,
                latWet
            )
        )
    end)

    -- Boîte manuelle au neutre : avec la boîte automatique, maintenir « freiner »
    -- à l'arrêt engage la marche arrière (arbitrage A3, conservé) ; en pente le
    -- P-01 recule donc si l'on garde le frein : comportement documenté (ECARTS).
    T.test("frottement statique : véhicule freiné immobile en pente à 10 % (glissement < 1 cm en 10 s)", function()
        local snaps = PlanarSim.run(Dynamics, P02, {
            Dt = DT,
            Duration = 10,
            Grade = 0.1,
            Input = function()
                return input(0, 0.35, 0)
            end,
        })
        T.truthy(math.abs(snaps[#snaps].Distance) < 0.01, string.format("%.4f m", snaps[#snaps].Distance))
        T.truthy(math.abs(snaps[#snaps].Forward) < 1e-3, "vitesse nulle")
    end)

    T.test("frein à main seul en pente à 15 % : tient", function()
        local snaps = PlanarSim.run(Dynamics, P02, {
            Dt = DT,
            Duration = 10,
            Grade = 0.15,
            Input = function()
                return input(0, 0, 0, true)
            end,
        })
        T.truthy(snaps[#snaps].Distance < 0.01, string.format("%.4f m", snaps[#snaps].Distance))
    end)

    T.test("sans frein ni rapport, le véhicule descend la pente (pas de collage artificiel)", function()
        local snaps = PlanarSim.run(Dynamics, P01, {
            Dt = DT,
            Duration = 5,
            Grade = 0.1,
            EngineOff = true,
            Input = function()
                return input(0, 0, 0)
            end,
        })
        T.truthy(snaps[#snaps].Forward < -1, string.format("recule à %.2f m/s", snaps[#snaps].Forward))
    end)

    T.test("frottement statique : décroche au-delà de l'adhérence", function()
        local force, x = TireModel.stiction(0.019, 0.1, 1000, 300, DT)
        T.equal(force, nil)
        T.equal(x, 0)
        local held, y = TireModel.stiction(0, 0.01, 1000, 300, DT)
        T.truthy(held ~= nil and (held :: number) < 0, "force opposée au mouvement")
        T.truthy(y > 0)
    end)

    T.test("relaxation : force latérale établie progressivement, sans effet à basse vitesse", function()
        T.near(TireModel.relax(0, 1000, 5, 0.35, DT), 1000 * 5 * DT / 0.35, 1e-9)
        T.equal(TireModel.relax(0, 1000, 1, 0.35, DT), 1000, "basse vitesse : immédiat")
        T.equal(TireModel.relax(0, 1000, 30, 0.35, DT), 1000, "haute vitesse : établie en une image")
        T.equal(TireModel.relax(0, 1000, 10, 0, DT), 1000, "longueur nulle : désactivée")
    end)
end
